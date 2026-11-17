//! Verifiable Health Links as IHE ITI VHL specifies them, with the SMART
//! Health Links payload format. No I/O: the host sends what this builds and
//! hands back what it receives (STT-VHL-001 to STT-VHL-010). A port of the
//! Kotlin library's HcertVhl, against the same fixtures.

use crate::cbor::Item;
use crate::cose::{base64_decode, base64_encode};
use crate::json::{self, quote, Json};
use crate::types::{NumericDate, Severity, ValidationIssue};

const PREFIX: &str = "vhlink:/";
const FORM: &str = "application/x-www-form-urlencoded";
/// Upper bound on an inflated (zip DEF) document.
const MAX_DOCUMENT_BYTES: usize = 64 * 1024 * 1024;

#[derive(Clone, Debug, PartialEq, Eq, Default)]
pub struct VhlPayload {
    pub url: String,
    pub key: String,
    pub exp: Option<i64>,
    pub flag: Option<String>,
    pub label: Option<String>,
    pub v: Option<i32>,
    pub fhir_base_url: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum VhlError {
    Invalid(Vec<ValidationIssue>),
    NotAVhlink(String),
    Manifest(String),
    DecryptFailed(String),
    Unsupported(String),
}

impl std::fmt::Display for VhlError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            VhlError::Invalid(v) => write!(f, "invalid: {}", v.iter().map(|i| format!("{}: {}", i.path, i.message)).collect::<Vec<_>>().join("; ")),
            VhlError::NotAVhlink(m) | VhlError::Manifest(m) | VhlError::DecryptFailed(m) | VhlError::Unsupported(m) => f.write_str(m),
        }
    }
}
impl std::error::Error for VhlError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ManifestRequest {
    pub url: String,
    pub content_type: String,
    pub body: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Default)]
pub struct ManifestDocument {
    pub url: Option<String>,
    pub reference: Option<String>,
    pub content_type: Option<String>,
    pub title: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Decrypted {
    pub content_type: Option<String>,
    pub content: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SignatureRequest {
    pub method: String,
    pub authority: String,
    pub path: String,
    pub content_type: Option<String>,
    pub body: Option<Vec<u8>>,
    pub keyid: String,
    pub alg: String,
    pub created: NumericDate,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SignatureBase {
    pub content_digest: Option<String>,
    pub signature_input: String,
    pub base: Vec<u8>,
}

fn issue(path: &str, code: &str, message: &str) -> ValidationIssue {
    ValidationIssue { path: path.into(), code: code.into(), message: message.into(), severity: Severity::Blocking }
}

fn is_base64url_43(s: &str) -> bool {
    s.len() == 43 && s.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_')
}

fn key_bytes(key: &str) -> Option<Vec<u8>> {
    if !is_base64url_43(key) {
        return None;
    }
    base64_decode(key).ok().filter(|k| k.len() == 32)
}

fn bad_key() -> VhlError {
    VhlError::Invalid(vec![issue("key", "bad-key", "key must be 43 base64url characters encoding 32 bytes")])
}

fn b64url(data: &[u8]) -> String {
    base64_encode(data, true).trim_end_matches('=').to_string()
}

/// Every rule of the payload format; with `now`, an expired link too
/// (STT-VHL-001, STT-VHL-009).
pub fn validate(p: &VhlPayload, now: Option<NumericDate>) -> Vec<ValidationIssue> {
    let mut out = Vec::new();
    if !p.url.starts_with("https://") {
        out.push(issue("url", "not-https", "url must be an https URL"));
    }
    if key_bytes(&p.key).is_none() {
        out.push(issue("key", "bad-key", "key must be 43 base64url characters encoding 32 bytes"));
    }
    if let Some(f) = &p.flag {
        if f.contains('U') {
            out.push(issue("flag", "unsupported-flag-U", "the single-file U flag is not supported"));
        }
        let letters: Vec<char> = f.chars().filter(|c| *c != 'U').collect();
        let mut sorted = letters.clone();
        sorted.sort();
        sorted.dedup();
        if letters.iter().any(|c| !"LP".contains(*c)) || sorted != letters {
            out.push(issue("flag", "bad-flag", "flag must be L and/or P, each once, in alphabetical order"));
        }
    }
    if p.label.as_ref().is_some_and(|l| l.chars().count() > 80) {
        out.push(issue("label", "label-too-long", "label must be at most 80 characters"));
    }
    if p.v.is_some_and(|v| v < 1) {
        out.push(issue("v", "bad-version", "v must be a positive integer"));
    }
    if p.fhir_base_url.as_ref().is_some_and(|u| !u.starts_with("https://")) {
        out.push(issue("extension.fhirBaseUrl", "not-https", "fhirBaseUrl must be an https URL"));
    }
    if let (Some(now), Some(exp)) = (now, p.exp) {
        if now > exp {
            out.push(issue("exp", "expired", "the link has expired"));
        }
    }
    out
}

fn to_json(p: &VhlPayload) -> String {
    let mut s = format!("{{\"url\":{},\"key\":{}", quote(&p.url), quote(&p.key));
    if let Some(e) = p.exp {
        s += &format!(",\"exp\":{e}");
    }
    if let Some(f) = &p.flag {
        s += &format!(",\"flag\":{}", quote(f));
    }
    if let Some(l) = &p.label {
        s += &format!(",\"label\":{}", quote(l));
    }
    if let Some(v) = p.v {
        s += &format!(",\"v\":{v}");
    }
    if let Some(u) = &p.fhir_base_url {
        s += &format!(",\"extension\":{{\"fhirBaseUrl\":{}}}", quote(u));
    }
    s + "}"
}

/// The vhlink:/ form (STT-VHL-003).
pub fn to_vhlink(p: &VhlPayload) -> String {
    format!("{PREFIX}{}", b64url(to_json(p).as_bytes()))
}

/// A field of the payload, from JSON or from CBOR.
enum Field {
    Text(String),
    Int(i64),
    Other,
    Map(Vec<(String, Field)>),
}

fn from_fields(f: Vec<(String, Field)>) -> Result<VhlPayload, VhlError> {
    let mut issues = Vec::new();
    let get = |k: &str| f.iter().find(|(n, _)| n == k).map(|(_, v)| v);
    let text = |k: &str, required: bool, issues: &mut Vec<ValidationIssue>| match get(k) {
        None => {
            if required {
                issues.push(issue(k, "required", &format!("{k} is required")));
            }
            None
        }
        Some(Field::Text(s)) => Some(s.clone()),
        Some(_) => {
            issues.push(issue(k, "not-text", &format!("{k} must be a string")));
            None
        }
    };
    let url = text("url", true, &mut issues);
    let key = text("key", true, &mut issues);
    let flag = text("flag", false, &mut issues);
    let label = text("label", false, &mut issues);
    let integer = |k: &str, issues: &mut Vec<ValidationIssue>| match get(k) {
        None => None,
        Some(Field::Int(i)) => Some(*i),
        Some(_) => {
            issues.push(issue(k, "not-integer", &format!("{k} must be an integer")));
            None
        }
    };
    let exp = integer("exp", &mut issues);
    let v = integer("v", &mut issues).map(|v| v.clamp(i32::MIN as i64, i32::MAX as i64) as i32);
    let fhir_base_url = match get("extension") {
        Some(Field::Map(m)) => m.iter().find(|(n, _)| n == "fhirBaseUrl").and_then(|(_, v)| if let Field::Text(s) = v { Some(s.clone()) } else { None }),
        _ => None,
    };
    if issues.is_empty() {
        Ok(VhlPayload { url: url.unwrap_or_default(), key: key.unwrap_or_default(), exp, flag, label, v, fhir_base_url })
    } else {
        Err(VhlError::Invalid(issues))
    }
}

fn json_field(j: &Json) -> Field {
    match j {
        Json::Str(s) => Field::Text(s.clone()),
        Json::Num(n) if n.fract() == 0.0 && n.abs() < 9.007_199_254_740_992e15 => Field::Int(*n as i64),
        Json::Obj(m) => Field::Map(m.iter().map(|(k, v)| (k.clone(), json_field(v))).collect()),
        _ => Field::Other,
    }
}

fn cbor_field(i: &Item) -> Field {
    match i {
        Item::Text(s) => Field::Text(s.clone()),
        Item::Int(n) => Field::Int(*n),
        Item::Map(m) => Field::Map(m.iter().filter_map(|(k, v)| k.as_text().map(|k| (k.to_string(), cbor_field(v)))).collect()),
        _ => Field::Other,
    }
}

pub fn from_vhlink(text: &str) -> Result<VhlPayload, VhlError> {
    let rest = text.strip_prefix(PREFIX).ok_or_else(|| VhlError::NotAVhlink("no vhlink:/ prefix".into()))?;
    let bad = || VhlError::NotAVhlink("the text after vhlink:/ is not base64url JSON".into());
    let bytes = base64_decode(rest).map_err(|_| bad())?;
    let j = json::parse(std::str::from_utf8(&bytes).map_err(|_| bad())?).map_err(|_| bad())?;
    match json_field(&j) {
        Field::Map(m) => from_fields(m),
        _ => Err(VhlError::NotAVhlink("the payload is not a JSON object".into())),
    }
}

/// The CBOR map written at HCERT key 5 (STT-VHL-002).
pub fn to_item(p: &VhlPayload) -> Item {
    let t = |k: &str, v: Item| (Item::Text(k.into()), v);
    let mut m = vec![t("url", Item::Text(p.url.clone())), t("key", Item::Text(p.key.clone()))];
    if let Some(e) = p.exp {
        m.push(t("exp", Item::Int(e)));
    }
    if let Some(f) = &p.flag {
        m.push(t("flag", Item::Text(f.clone())));
    }
    if let Some(l) = &p.label {
        m.push(t("label", Item::Text(l.clone())));
    }
    if let Some(v) = p.v {
        m.push(t("v", Item::Int(v as i64)));
    }
    if let Some(u) = &p.fhir_base_url {
        m.push(t("extension", Item::Map(vec![t("fhirBaseUrl", Item::Text(u.clone()))])));
    }
    Item::Map(m)
}

/// Key 5 as the CBOR map, or as a vhlink:/ text string (IHE ITI-YY3).
pub fn from_item(item: &Item) -> Result<VhlPayload, VhlError> {
    match item {
        Item::Text(t) => from_vhlink(t),
        Item::Map(_) => match cbor_field(item) {
            Field::Map(m) => from_fields(m),
            _ => unreachable!(),
        },
        _ => Err(VhlError::Invalid(vec![issue("", "not-a-map", "key 5 is neither a CBOR map nor a vhlink:/ string")])),
    }
}

/// A new key from the platform's secure random generator (STT-VHL-004).
pub fn new_key() -> Result<String, String> {
    Ok(b64url(&crate::entropy::random_bytes(32)?))
}

fn form_encode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'*' | b'-' | b'.' | b'_' => out.push(b as char),
            b' ' => out.push('+'),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn percent_decode(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::new();
    let mut i = 0;
    while i < b.len() {
        let hex = (b[i] == b'%' && i + 3 <= b.len()).then(|| std::str::from_utf8(&b[i + 1..i + 3]).ok().and_then(|h| u8::from_str_radix(h, 16).ok())).flatten();
        match hex {
            Some(h) => {
                out.push(h);
                i += 3;
            }
            None => {
                out.push(b[i]);
                i += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// The ITI-YY5 Retrieve Manifest request for the host to POST (STT-VHL-005).
pub fn build_manifest_request(p: &VhlPayload, recipient: &str, passcode: Option<&str>, embedded_length_max: Option<u32>) -> Result<ManifestRequest, VhlError> {
    let blocking: Vec<_> = validate(p, None).into_iter().filter(|i| i.severity == Severity::Blocking).collect();
    if !blocking.is_empty() {
        return Err(VhlError::Invalid(blocking));
    }
    if recipient.trim().is_empty() {
        return Err(VhlError::Manifest("recipient is required".into()));
    }
    let needs_passcode = p.flag.as_ref().is_some_and(|f| f.contains('P'));
    if needs_passcode && passcode.is_none_or(str::is_empty) {
        return Err(VhlError::Manifest("the link has the P flag: a passcode is required".into()));
    }
    if !needs_passcode && passcode.is_some() {
        return Err(VhlError::Manifest("the link has no P flag: no passcode is sent".into()));
    }
    let path = p.url.split('?').next().unwrap_or_default().trim_end_matches('/');
    let base = if let Some(b) = path.strip_suffix("/List/_search") {
        b
    } else if let Some(b) = path.strip_suffix("/List") {
        b
    } else {
        return Err(VhlError::Manifest("the manifest URL is not a List search".into()));
    };
    let query = p.url.split_once('?').map(|(_, q)| q).unwrap_or("");
    let params: Vec<(String, String)> = query
        .split('&')
        .filter(|s| !s.is_empty())
        .map(|kv| {
            let (k, v) = kv.split_once('=').unwrap_or((kv, ""));
            (percent_decode(&k.replace('+', " ")), percent_decode(&v.replace('+', " ")))
        })
        .collect();
    for r in ["_id", "code", "status", "patient.identifier"] {
        if params.iter().filter(|(k, _)| k == r).count() != 1 {
            return Err(VhlError::Manifest(format!("the manifest URL needs exactly one {r}")));
        }
    }
    if let Some((_, v)) = params.iter().find(|(k, _)| k == "_include") {
        if v != "List:item" {
            return Err(VhlError::Manifest("_include must be List:item".into()));
        }
    }
    let mut all = params.clone();
    all.push(("recipient".into(), recipient.into()));
    if let Some(pc) = passcode {
        all.push(("passcode".into(), pc.into()));
    }
    if let Some(m) = embedded_length_max {
        all.push(("embeddedLengthMax".into(), m.to_string()));
    }
    let body = all.iter().map(|(k, v)| format!("{}={}", form_encode(k), form_encode(v))).collect::<Vec<_>>().join("&");
    Ok(ManifestRequest { url: format!("{base}/List/_search"), content_type: FORM.into(), body })
}

/// The ITI-YY5 searchset Bundle (STT-VHL-006).
pub fn parse_manifest(bundle_json: &str) -> Result<Vec<ManifestDocument>, VhlError> {
    let bundle = json::parse(bundle_json).map_err(VhlError::Manifest)?;
    if !matches!(bundle, Json::Obj(_)) {
        return Err(VhlError::Manifest("not a JSON object".into()));
    }
    let s = |j: &Json, k: &str| j.get(k).and_then(Json::as_str).map(str::to_owned);
    if s(&bundle, "resourceType").as_deref() != Some("Bundle") || s(&bundle, "type").as_deref() != Some("searchset") {
        return Err(VhlError::Manifest("not a searchset Bundle".into()));
    }
    let entries: Vec<&Json> = bundle.get("entry").and_then(Json::as_arr).unwrap_or_default().iter().filter(|e| matches!(e, Json::Obj(_))).collect();
    let mode = |e: &Json| e.get("search").and_then(|x| x.get("mode")).and_then(Json::as_str).map(str::to_owned);
    let rtype = |e: &Json| e.get("resource").and_then(|r| r.get("resourceType")).and_then(Json::as_str).map(str::to_owned);
    let lists: Vec<&&Json> = entries.iter().filter(|e| rtype(e).as_deref() == Some("List") && mode(e).as_deref() != Some("include")).collect();
    if lists.is_empty() {
        return Err(VhlError::Manifest("the Bundle holds no matching List".into()));
    }
    let mut included: Vec<(String, &Json)> = Vec::new();
    for e in &entries {
        let Some(r) = e.get("resource") else { continue };
        if rtype(e).as_deref() != Some("DocumentReference") {
            continue;
        }
        if let Some(u) = s(e, "fullUrl") {
            included.push((u, r));
        }
        if let Some(id) = s(r, "id") {
            included.push((format!("DocumentReference/{id}"), r));
        }
    }
    let mut docs = Vec::new();
    for l in lists {
        let list = l.get("resource").unwrap();
        for item in list.get("entry").and_then(Json::as_arr).unwrap_or_default() {
            let Some(reference) = item.get("item").and_then(|i| i.get("reference")).and_then(Json::as_str) else { continue };
            let dr = included.iter().find(|(k, _)| k == reference).or_else(|| included.iter().find(|(k, _)| reference.ends_with(&format!("/{k}")) || k.ends_with(&format!("/{reference}")))).map(|(_, v)| *v);
            let Some(dr) = dr else {
                docs.push(ManifestDocument { reference: Some(reference.into()), ..Default::default() });
                continue;
            };
            let contents = dr.get("content").and_then(Json::as_arr).unwrap_or_default();
            if !contents.iter().any(|c| c.get("attachment").and_then(|a| a.get("url")).is_some()) {
                docs.push(ManifestDocument { reference: Some(reference.into()), ..Default::default() });
                continue;
            }
            for c in contents {
                let Some(a) = c.get("attachment") else { continue };
                docs.push(ManifestDocument { url: s(a, "url"), reference: None, content_type: s(a, "contentType"), title: s(a, "title").or_else(|| s(dr, "description")) });
            }
        }
    }
    Ok(docs)
}

fn nonce(iv: &[u8]) -> aes_gcm::Nonce<aes_gcm::aead::consts::U12> {
    let a: [u8; 12] = iv.try_into().expect("a 96-bit IV");
    a.into()
}

/// JWE Compact, dir / A256GCM, the payload key (STT-VHL-007).
pub fn encrypt(content: &[u8], content_type: &str, key: &str) -> Result<String, VhlError> {
    use aes_gcm::aead::{Aead, KeyInit, Payload};
    let k = key_bytes(key).ok_or_else(bad_key)?;
    let header = format!("{{\"alg\":\"dir\",\"enc\":\"A256GCM\",\"cty\":{}}}", quote(content_type));
    let h = b64url(header.as_bytes());
    let iv = crate::entropy::random_bytes(12).map_err(VhlError::Unsupported)?;
    let cipher = aes_gcm::Aes256Gcm::new_from_slice(&k).map_err(|_| bad_key())?;
    let sealed = cipher.encrypt(&nonce(&iv), Payload { msg: content, aad: h.as_bytes() }).map_err(|_| VhlError::DecryptFailed("AES-GCM encryption failed".into()))?;
    let (ct, tag) = sealed.split_at(sealed.len() - 16);
    Ok(format!("{h}..{}.{}.{}", b64url(&iv), b64url(ct), b64url(tag)))
}

pub fn decrypt(jwe: &str, key: &str) -> Result<Decrypted, VhlError> {
    use aes_gcm::aead::{Aead, KeyInit, Payload};
    let k = key_bytes(key).ok_or_else(bad_key)?;
    let parts: Vec<&str> = jwe.trim().split('.').collect();
    if parts.len() != 5 {
        return Err(VhlError::DecryptFailed(format!("JWE Compact has 5 parts, found {}", parts.len())));
    }
    if !parts[1].is_empty() {
        return Err(VhlError::Unsupported("an encrypted key is present: alg is not dir".into()));
    }
    let header = base64_decode(parts[0]).ok().and_then(|b| String::from_utf8(b).ok()).and_then(|t| json::parse(&t).ok()).filter(|j| matches!(j, Json::Obj(_)));
    let Some(header) = header else { return Err(VhlError::DecryptFailed("the protected header is not base64url JSON".into())) };
    let hs = |k: &str| header.get(k).and_then(Json::as_str).map(str::to_owned);
    if hs("alg").as_deref() != Some("dir") || hs("enc").as_deref() != Some("A256GCM") {
        return Err(VhlError::Unsupported(format!("alg {} / enc {}; only dir / A256GCM", hs("alg").unwrap_or_default(), hs("enc").unwrap_or_default())));
    }
    let zip = header.get("zip");
    if zip.is_some() && zip.and_then(Json::as_str) != Some("DEF") {
        return Err(VhlError::Unsupported("zip is not DEF".into()));
    }
    let part = |i: usize| base64_decode(parts[i]).map_err(|_| VhlError::DecryptFailed("a JWE part is not base64url".into()));
    let (iv, ct, tag) = (part(2)?, part(3)?, part(4)?);
    if iv.len() != 12 || tag.len() != 16 {
        return Err(VhlError::DecryptFailed("A256GCM needs a 96-bit IV and a 128-bit tag".into()));
    }
    let cipher = aes_gcm::Aes256Gcm::new_from_slice(&k).map_err(|_| bad_key())?;
    let sealed = [ct, tag].concat();
    let plain = cipher
        .decrypt(&nonce(&iv), Payload { msg: &sealed, aad: parts[0].as_bytes() })
        .map_err(|_| VhlError::DecryptFailed("the tag does not verify: wrong key or altered content".into()))?;
    let content = if zip.is_some() {
        crate::codec::inflate_raw(&plain, MAX_DOCUMENT_BYTES).map_err(|e| VhlError::DecryptFailed(format!("zip DEF content does not inflate: {e}")))?
    } else {
        plain
    };
    Ok(Decrypted { content_type: hs("cty"), content })
}

/// The RFC 9421 signature base, with an RFC 9530 Content-Digest when there
/// is a body (STT-VHL-008).
pub fn build_signature_base(r: &SignatureRequest) -> SignatureBase {
    let digest = r.body.as_ref().map(|b| format!("sha-256=:{}:", base64_encode(&crate::x509::sha256(b), false)));
    let mut components: Vec<(&str, String)> = vec![("@method", r.method.to_uppercase()), ("@path", r.path.clone()), ("@authority", r.authority.to_lowercase())];
    if let Some(ct) = &r.content_type {
        components.push(("content-type", ct.trim().to_string()));
    }
    if let Some(d) = &digest {
        components.push(("content-digest", d.clone()));
    }
    let names = components.iter().map(|(n, _)| format!("\"{n}\"")).collect::<Vec<_>>().join(" ");
    let params = format!("({names});created={};keyid=\"{}\";alg=\"{}\"", r.created, r.keyid, r.alg);
    let mut lines: Vec<String> = components.iter().map(|(n, v)| format!("\"{n}\": {v}")).collect();
    lines.push(format!("\"@signature-params\": {params}"));
    SignatureBase { content_digest: digest, signature_input: format!("sig1={params}"), base: lines.join("\n").into_bytes() }
}

/// The Signature header value; an ecdsa-p256-sha256 DER signature becomes r||s.
pub fn signature_header(signature: &[u8], alg: &str) -> Result<String, VhlError> {
    let sig = if alg == "ecdsa-p256-sha256" && signature.len() != 64 {
        crate::cose::ecdsa_der_to_raw(signature).map_err(|_| VhlError::Unsupported("ecdsa-p256-sha256 signature is neither r||s nor DER".into()))?.to_vec()
    } else {
        signature.to_vec()
    };
    Ok(format!("sig1=:{}:", base64_encode(&sig, false)))
}
