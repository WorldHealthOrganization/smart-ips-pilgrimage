//! Subclaims (QR Code Generation 2.1) and the DVCMin payload
//! (STT-SEL-001 to STT-SEL-003, STT-PAY-001 to STT-PAY-008).

use crate::cbor::{self, Item};
use crate::types::{DecodeLimits, Severity, ValidationIssue, DEFAULT_LIMITS};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Subclaim {
    pub key: i64,
    pub name: String,
    pub profile: Option<String>,
}

/// The subclaims QR Code Generation 2.1 lists (STT-SEL-001).
pub fn default_subclaims() -> Vec<Subclaim> {
    let s = |key, name: &str, profile: Option<&str>| Subclaim { key, name: name.into(), profile: profile.map(Into::into) };
    vec![
        s(1, "HCertDCC (EU DCC core data set)", None),
        s(3, "DDCCCoreDataSetVS", None),
        s(4, "DDCCCoreDataSetTR", None),
        s(5, "Verifiable Health Link", None),
        s(-6, "DVCMin", Some("http://smart.who.int/trust-phw/StructureDefinition/DVCMin")),
        s(-7, "MedicationTreatmentLineMin", None),
    ]
}

/// Payload kinds the library itself decodes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PayloadKind {
    DvcMin,
    Vhl,
}

/// Subclaims by key, and which key each payload kind uses (STT-SEL-002, STT-SEL-003).
#[derive(Clone, Debug)]
pub struct Registry {
    subclaims: Vec<Subclaim>,
    dvc_min: i64,
    vhl: i64,
}

impl Default for Registry {
    fn default() -> Self {
        Registry { subclaims: default_subclaims(), dvc_min: -6, vhl: 5 }
    }
}

impl Registry {
    pub fn lookup(&self, key: i64) -> Option<&Subclaim> {
        self.subclaims.iter().find(|s| s.key == key)
    }
    pub fn register(&mut self, s: Subclaim) {
        self.subclaims.retain(|x| x.key != s.key);
        self.subclaims.push(s);
    }
    pub fn all(&self) -> &[Subclaim] {
        &self.subclaims
    }
    pub fn subclaim_for(&self, kind: PayloadKind) -> i64 {
        match kind {
            PayloadKind::DvcMin => self.dvc_min,
            PayloadKind::Vhl => self.vhl,
        }
    }
    pub fn set_subclaim_for(&mut self, kind: PayloadKind, key: i64) {
        match kind {
            PayloadKind::DvcMin => self.dvc_min = key,
            PayloadKind::Vhl => self.vhl = key,
        }
    }
}

/// DVCMinVaccineDetails, smart-trust-phw.
#[derive(Clone, Debug, PartialEq, Eq, Default)]
pub struct VaccineDetails {
    pub vp: String,
    pub dv: String,
    pub cn: Option<String>,
    pub is: Option<String>,
    pub bo: String,
}

/// DVCMin, smart-trust-phw. Elements this version does not know are kept
/// as encoded CBOR in `extensions` (STT-PAY-008).
#[derive(Clone, Debug, PartialEq, Eq, Default)]
pub struct DvcMin {
    pub n: String,
    pub dob: String,
    pub s: String,
    pub nt: String,
    pub id: Option<String>,
    pub dt: Option<String>,
    pub gn: Option<String>,
    pub vx: VaccineDetails,
    pub v: String,
    pub extensions: Vec<(String, Vec<u8>)>,
}

/// A decoded hcert entry.
#[derive(Clone, Debug, PartialEq)]
pub enum Payload {
    DvcMin(DvcMin),
    /// A Verifiable Health Link (STT-VHL-002).
    Vhl(crate::vhl::VhlPayload),
    /// Any other subclaim, kept as its encoded CBOR.
    Raw { subclaim: i64, cbor: Vec<u8> },
}

const SUBJECT_KEYS: [&str; 9] = ["n", "dob", "s", "nt", "id", "dt", "gn", "vx", "v"];
const VX_KEYS: [&str; 5] = ["vp", "dv", "cn", "is", "bo"];

fn issue(path: &str, code: &str, message: String, severity: Severity) -> ValidationIssue {
    ValidationIssue { path: path.into(), code: code.into(), message, severity }
}

// FHIR R5 primitive patterns, as models/generated/trust-phw.cddl carries them,
// written as checks rather than regular expressions.
fn fhir_string(s: &str) -> bool {
    !s.is_empty()
}
fn fhir_code(s: &str) -> bool {
    !s.is_empty() && !s.starts_with(' ') && !s.ends_with(' ') && !s.contains("  ") && !s.chars().any(|c| c.is_whitespace() && c != ' ')
}
fn fhir_date(s: &str) -> bool {
    let b = s.as_bytes();
    let digits = |r: std::ops::Range<usize>| b.get(r).is_some_and(|x| x.iter().all(u8::is_ascii_digit));
    let num = |r: std::ops::Range<usize>| s[r].parse::<u32>().unwrap_or(0);
    match b.len() {
        4 => digits(0..4) && num(0..4) > 0,
        7 => digits(0..4) && num(0..4) > 0 && b[4] == b'-' && digits(5..7) && (1..=12).contains(&num(5..7)),
        10 => digits(0..4) && num(0..4) > 0 && b[4] == b'-' && digits(5..7) && (1..=12).contains(&num(5..7)) && b[7] == b'-' && digits(8..10) && (1..=31).contains(&num(8..10)),
        _ => false,
    }
}
fn fhir_id(s: &str) -> bool {
    (1..=64).contains(&s.len()) && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'.')
}

/// The logical model's rules (STT-PAY-002, STT-PAY-003, STT-PAY-007).
pub fn validate(p: &DvcMin) -> Vec<ValidationIssue> {
    let mut out = Vec::new();
    let mut check = |path: &str, value: Option<&str>, ok: fn(&str) -> bool, ty: &str| {
        if let Some(v) = value {
            if !ok(v) {
                out.push(issue(path, &format!("invalid-{ty}"), format!("{path} is not a valid FHIR {ty}"), Severity::Blocking));
            }
        }
    };
    check("n", Some(&p.n), fhir_string, "string");
    check("dob", Some(&p.dob), fhir_date, "date");
    check("s", Some(&p.s), fhir_code, "code");
    check("nt", Some(&p.nt), fhir_code, "code");
    check("id", p.id.as_deref(), fhir_string, "string");
    check("dt", p.dt.as_deref(), fhir_code, "code");
    check("gn", p.gn.as_deref(), fhir_string, "string");
    check("v", Some(&p.v), fhir_string, "string");
    check("vx.vp", Some(&p.vx.vp), fhir_code, "code");
    check("vx.dv", Some(&p.vx.dv), fhir_date, "date");
    check("vx.cn", p.vx.cn.as_deref(), fhir_string, "string");
    check("vx.is", p.vx.is.as_deref(), fhir_id, "id");
    check("vx.bo", Some(&p.vx.bo), fhir_string, "string");
    if fhir_code(&p.nt) && !(p.nt.len() == 3 && p.nt.bytes().all(|c| c.is_ascii_uppercase())) {
        out.push(issue("nt", "not-alpha3", "nt must be an ISO 3166-1 alpha-3 code".into(), Severity::Blocking));
    }
    if p.vx.cn.is_none() && p.vx.is.is_none() {
        out.push(issue("vx", "must-have-issuer-or-clinician-name", "vx needs is, cn or both".into(), Severity::Blocking));
    }
    out
}

/// The DVCMin as a CBOR item, in the logical model's element order (STT-PAY-001).
pub fn to_item(p: &DvcMin) -> Result<Item, String> {
    let t = |k: &str, v: &str| (Item::Text(k.into()), Item::Text(v.into()));
    let mut vx = vec![t("vp", &p.vx.vp), t("dv", &p.vx.dv)];
    if let Some(cn) = &p.vx.cn {
        vx.push(t("cn", cn));
    }
    if let Some(is) = &p.vx.is {
        vx.push(t("is", is));
    }
    vx.push(t("bo", &p.vx.bo));
    let mut m = vec![t("n", &p.n), t("dob", &p.dob), t("s", &p.s), t("nt", &p.nt)];
    for (k, v) in [("id", &p.id), ("dt", &p.dt), ("gn", &p.gn)] {
        if let Some(v) = v {
            m.push(t(k, v));
        }
    }
    m.push((Item::Text("vx".into()), Item::Map(vx)));
    m.push(t("v", &p.v));
    for (k, v) in &p.extensions {
        if SUBJECT_KEYS.contains(&k.as_str()) {
            return Err(format!("extension {k} collides with a DVCMin element"));
        }
        m.push((Item::Text(k.clone()), cbor::decode(v, &DEFAULT_LIMITS).map_err(|e| e.message)?));
    }
    Ok(Item::Map(m))
}

pub fn to_cbor(p: &DvcMin) -> Result<Vec<u8>, String> {
    cbor::encode(&to_item(p)?).map_err(|e| e.message)
}

pub fn from_cbor(bytes: &[u8], limits: &DecodeLimits) -> Result<DvcMin, Vec<ValidationIssue>> {
    let item = cbor::decode(bytes, limits).map_err(|e| vec![issue("", "cbor", e.message, Severity::Blocking)])?;
    from_item(&item)
}

pub fn from_item(root: &Item) -> Result<DvcMin, Vec<ValidationIssue>> {
    let mut issues = Vec::new();
    let Some(map) = root.entries() else {
        return Err(vec![issue("", "not-a-map", "DVCMin is not a CBOR map".into(), Severity::Blocking)]);
    };
    let texts = |m: &[(Item, Item)], prefix: &str, known: &[&str], issues: &mut Vec<ValidationIssue>| {
        let mut out: Vec<(String, String)> = Vec::new();
        for (k, v) in m {
            let Some(name) = k.as_text() else {
                issues.push(issue(prefix, "non-text-key", "element name is not a text string".into(), Severity::Blocking));
                continue;
            };
            if !known.contains(&name) || name == "vx" {
                continue;
            }
            match v.as_text() {
                Some(t) => out.push((name.into(), t.into())),
                None => issues.push(issue(&format!("{prefix}{name}"), "not-text", format!("{prefix}{name} is not a text string"), Severity::Blocking)),
            }
        }
        out
    };
    let s = texts(map, "", &SUBJECT_KEYS, &mut issues);
    let vx_item = root.get_text("vx").and_then(Item::entries);
    if vx_item.is_none() {
        issues.push(issue("vx", "required", "vx is required and must be a map".into(), Severity::Blocking));
    }
    let vx = vx_item.map(|m| texts(m, "vx.", &VX_KEYS, &mut issues)).unwrap_or_default();
    for (k, _) in vx_item.unwrap_or_default() {
        if let Some(name) = k.as_text() {
            if !VX_KEYS.contains(&name) {
                issues.push(issue(&format!("vx.{name}"), "unknown-element", format!("vx.{name} is not in this DVCMin version and is not kept"), Severity::Warning));
            }
        }
    }
    let get = |l: &[(String, String)], k: &str| l.iter().find(|(n, _)| n == k).map(|(_, v)| v.clone());
    for r in ["n", "dob", "s", "nt", "v"] {
        if get(&s, r).is_none() && !issues.iter().any(|i| i.path == r) {
            issues.push(issue(r, "required", format!("{r} is required"), Severity::Blocking));
        }
    }
    if vx_item.is_some() {
        for r in ["vp", "dv", "bo"] {
            let path = format!("vx.{r}");
            if get(&vx, r).is_none() && !issues.iter().any(|i| i.path == path) {
                issues.push(issue(&path, "required", format!("{path} is required"), Severity::Blocking));
            }
        }
    }
    if issues.iter().any(|i| i.severity == Severity::Blocking) {
        return Err(issues);
    }
    let mut extensions = Vec::new();
    for (k, v) in map {
        let name = k.as_text().unwrap_or_default();
        if !SUBJECT_KEYS.contains(&name) {
            extensions.push((name.to_string(), cbor::encode(v).map_err(|e| vec![issue(name, "cbor", e.message, Severity::Blocking)])?));
        }
    }
    let req = |l: &[(String, String)], k: &str| get(l, k).unwrap_or_default();
    Ok(DvcMin {
        n: req(&s, "n"),
        dob: req(&s, "dob"),
        s: req(&s, "s"),
        nt: req(&s, "nt"),
        id: get(&s, "id"),
        dt: get(&s, "dt"),
        gn: get(&s, "gn"),
        vx: VaccineDetails { vp: req(&vx, "vp"), dv: req(&vx, "dv"), cn: get(&vx, "cn"), is: get(&vx, "is"), bo: req(&vx, "bo") },
        v: req(&s, "v"),
        extensions,
    })
}
