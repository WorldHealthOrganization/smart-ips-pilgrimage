//! The JSON surface the WebAssembly build exports: one call per pipeline
//! step, plus verify and the test DSC builder, so a page can run and show
//! each step on its own (STT-GEN-002). Input and output are JSON objects;
//! bytes travel as lower-case hex. Every result has `"ok": true` or
//! `"ok": false` with an `"error"`.

use crate::cbor;
use crate::codec;
use crate::cose;
use crate::issuer::{self, IssueRequest, PendingSignature};
use crate::json::{self, quote, Json};
use crate::payload::{self, DvcMin, Payload, Registry, VaccineDetails};
use crate::testdsc::{self, TestDscRequest};
use crate::trust::TrustStore;
use crate::types::*;
use crate::verifier::{self, VerifierOptions};

/// A JSON object under construction; values are already JSON.
#[derive(Default)]
struct Obj(Vec<(String, String)>);

impl Obj {
    fn ok() -> Self {
        let mut o = Obj::default();
        o.raw("ok", "true");
        o
    }
    fn raw(&mut self, k: &str, v: impl Into<String>) -> &mut Self {
        self.0.push((k.into(), v.into()));
        self
    }
    fn str(&mut self, k: &str, v: &str) -> &mut Self {
        self.raw(k, quote(v))
    }
    fn hex(&mut self, k: &str, v: &[u8]) -> &mut Self {
        self.str(k, &to_hex(v))
    }
    fn num(&mut self, k: &str, v: i64) -> &mut Self {
        self.raw(k, v.to_string())
    }
    fn opt_str(&mut self, k: &str, v: Option<&str>) -> &mut Self {
        self.raw(k, v.map(quote).unwrap_or_else(|| "null".into()))
    }
    fn done(&self) -> String {
        format!("{{{}}}", self.0.iter().map(|(k, v)| format!("{}:{v}", quote(k))).collect::<Vec<_>>().join(","))
    }
}

fn error(message: &str) -> String {
    format!("{{\"ok\":false,\"error\":{}}}", quote(message))
}

type R = Result<String, String>;

fn s<'a>(a: &'a Json, k: &str) -> Result<&'a str, String> {
    a.get(k).and_then(Json::as_str).ok_or_else(|| format!("{k} is required"))
}
fn i(a: &Json, k: &str) -> Result<i64, String> {
    a.get(k).and_then(Json::as_f64).map(|f| f as i64).ok_or_else(|| format!("{k} is required"))
}
fn hex(a: &Json, k: &str) -> Result<Vec<u8>, String> {
    from_hex(s(a, k)?).ok_or_else(|| format!("{k} is not hex"))
}
fn alg(a: &Json) -> Result<CoseAlgorithm, String> {
    match s(a, "alg")? {
        "ES256" => Ok(CoseAlgorithm::Es256),
        "PS256" => Ok(CoseAlgorithm::Ps256),
        other => Err(format!("alg {other} is not ES256 or PS256")),
    }
}

fn dvc_from(j: &Json) -> Result<DvcMin, String> {
    let o = |k: &str| j.get(k).and_then(Json::as_str).map(str::to_owned);
    let r = |k: &str| o(k).ok_or_else(|| format!("{k} is required"));
    let vx = j.get("vx").ok_or("vx is required")?;
    let vo = |k: &str| vx.get(k).and_then(Json::as_str).map(str::to_owned);
    let vr = |k: &str| vo(k).ok_or_else(|| format!("vx.{k} is required"));
    Ok(DvcMin {
        n: r("n")?,
        dob: r("dob")?,
        s: r("s")?,
        nt: r("nt")?,
        id: o("id"),
        dt: o("dt"),
        gn: o("gn"),
        vx: VaccineDetails { vp: vr("vp")?, dv: vr("dv")?, cn: vo("cn"), is: vo("is"), bo: vr("bo")? },
        v: r("v")?,
        extensions: Vec::new(),
    })
}

fn dvc_json(p: &DvcMin) -> String {
    let mut vx = Obj::default();
    vx.str("vp", &p.vx.vp).str("dv", &p.vx.dv).opt_str("cn", p.vx.cn.as_deref()).opt_str("is", p.vx.is.as_deref()).str("bo", &p.vx.bo);
    let mut o = Obj::default();
    o.str("n", &p.n).str("dob", &p.dob).str("s", &p.s).str("nt", &p.nt).opt_str("id", p.id.as_deref()).opt_str("dt", p.dt.as_deref()).opt_str("gn", p.gn.as_deref());
    o.raw("vx", vx.done()).str("v", &p.v);
    o.done()
}

fn issues_json(issues: &[ValidationIssue]) -> String {
    let items: Vec<String> = issues
        .iter()
        .map(|x| {
            let mut o = Obj::default();
            o.str("path", &x.path).str("code", &x.code).str("message", &x.message).str("severity", if x.severity == Severity::Blocking { "blocking" } else { "warning" });
            o.done()
        })
        .collect();
    format!("[{}]", items.join(","))
}

fn diag_of(bytes: &[u8]) -> String {
    cbor::decode(bytes, &DEFAULT_LIMITS).map(|i| cbor::diagnostic(&i)).unwrap_or_else(|e| format!("(not CBOR: {})", e.message))
}

/// Runs one operation; `request` is a JSON object with an "op" member.
pub fn call(request: &str) -> String {
    let run = || -> R {
        let a = json::parse(request)?;
        let reg = Registry::default();
        match s(&a, "op")? {
            "subclaims" => {
                let items: Vec<String> = reg
                    .all()
                    .iter()
                    .map(|x| {
                        let mut o = Obj::default();
                        o.num("key", x.key).str("name", &x.name).opt_str("profile", x.profile.as_deref());
                        o.done()
                    })
                    .collect();
                Ok(Obj::ok().raw("subclaims", format!("[{}]", items.join(","))).done())
            }
            // Steps 1 and 2: select and assemble the payload
            "assemblePayload" => {
                let p = dvc_from(a.get("dvc").ok_or("dvc is required")?)?;
                let issues = payload::validate(&p);
                let bytes = payload::to_cbor(&p)?;
                Ok(Obj::ok().num("subclaim", reg.subclaim_for(payload::PayloadKind::DvcMin)).hex("cbor", &bytes).str("diagnostic", &diag_of(&bytes)).raw("issues", issues_json(&issues)).done())
            }
            // Step 3: the CWT claim set
            "buildCwt" => {
                let body = cbor::decode(&hex(&a, "payload")?, &DEFAULT_LIMITS).map_err(|e| e.message)?;
                let iss = a.get("iss").and_then(Json::as_str);
                let bytes = issuer::build_cwt(iss, i(&a, "iat")?, i(&a, "exp")?, vec![(i(&a, "subclaim")?, body)]).map_err(|e| e.to_string())?;
                Ok(Obj::ok().hex("cwt", &bytes).str("diagnostic", &diag_of(&bytes)).done())
            }
            // Step 4: deterministic CBOR
            "cborDeterministic" => {
                let bytes = codec::cbor_deterministic(&hex(&a, "cbor")?, &DEFAULT_LIMITS).map_err(|e| e.to_string())?;
                Ok(Obj::ok().hex("cbor", &bytes).str("diagnostic", &diag_of(&bytes)).done())
            }
            "cborDiagnostic" => Ok(Obj::ok().str("diagnostic", &diag_of(&hex(&a, "cbor")?)).done()),
            // Step 5, first half: what the key holder signs
            "prepare" => {
                let dvc = dvc_from(a.get("dvc").ok_or("dvc is required")?)?;
                let req = IssueRequest {
                    payloads: vec![Payload::DvcMin(dvc)],
                    iss: a.get("iss").and_then(Json::as_str).map(str::to_owned),
                    iat: i(&a, "iat")?,
                    exp: i(&a, "exp")?,
                    alg: alg(&a)?,
                    dsc_der: hex(&a, "dsc")?,
                    allow_development_subclaims: true,
                };
                let p = issuer::prepare(&req, &reg).map_err(|e| e.to_string())?;
                Ok(Obj::ok()
                    .hex("protected", &p.protected)
                    .str("protectedDiagnostic", &diag_of(&p.protected))
                    .hex("cwt", &p.payload)
                    .str("cwtDiagnostic", &diag_of(&p.payload))
                    .hex("toBeSigned", &p.to_be_signed)
                    .str("toBeSignedDiagnostic", &diag_of(&p.to_be_signed))
                    .hex("kid", &p.kid)
                    .str("kidBase64", &cose::base64_encode(&p.kid, false))
                    .done())
            }
            // Step 5, second half: the COSE_Sign1
            "finish" => {
                let protected = hex(&a, "protected")?;
                let payload_bytes = hex(&a, "cwt")?;
                let alg = alg(&a)?;
                let dsc_der = hex(&a, "dsc")?;
                let to_be_signed = cose::sig_structure(&protected, &payload_bytes);
                let kid = cose::kid_from_dsc(&dsc_der);
                let p = PendingSignature { protected, payload: payload_bytes, alg, kid, dsc_der, to_be_signed };
                let issued = issuer::finish(&p, &hex(&a, "signature")?).map_err(|e| e.to_string())?;
                Ok(Obj::ok().hex("cose", &issued.cose).str("coseDiagnostic", &diag_of(&issued.cose)).str("hc1", &issued.hc1).done())
            }
            // Step 6: ZLIB
            "compress" => {
                let input = hex(&a, "data")?;
                let z = codec::zlib_compress(&input, a.get("level").and_then(Json::as_f64).unwrap_or(9.0) as u8);
                Ok(Obj::ok().hex("data", &z).num("inputBytes", input.len() as i64).num("outputBytes", z.len() as i64).done())
            }
            "inflate" => {
                let out = codec::zlib_inflate(&hex(&a, "data")?, DEFAULT_LIMITS.max_inflated_bytes).map_err(|e| e.to_string())?;
                Ok(Obj::ok().hex("data", &out).done())
            }
            // Step 7: Base45
            "base45Encode" => Ok(Obj::ok().str("text", &codec::base45_encode(&hex(&a, "data")?)).done()),
            "base45Decode" => Ok(Obj::ok().hex("data", &codec::base45_decode(s(&a, "text")?).map_err(|e| e.to_string())?).done()),
            // Step 8: the context identifier
            "prefix" => Ok(Obj::ok().str("hc1", &format!("HC1:{}", s(&a, "text")?)).done()),
            // The verifier's view of each layer, nothing checked
            "decodeLayers" => {
                let hc1 = s(&a, "hc1")?;
                let mut o = Obj::ok();
                let (version, rest) = codec::detect_context(hc1).map_err(|e| e.to_string())?;
                o.str("context", &format!("HC{version}"));
                let deflated = codec::base45_decode(rest).map_err(|e| e.to_string())?;
                o.hex("deflated", &deflated);
                let cose_bytes = codec::zlib_inflate(&deflated, DEFAULT_LIMITS.max_inflated_bytes).map_err(|e| e.to_string())?;
                o.hex("cose", &cose_bytes).str("coseDiagnostic", &diag_of(&cose_bytes));
                if let Ok(s1) = cose::parse_sign1(&cose_bytes, &DEFAULT_LIMITS) {
                    o.str("protectedDiagnostic", &diag_of(&s1.protected)).str("cwtDiagnostic", &diag_of(&s1.payload)).str("alg", if s1.alg == CoseAlgorithm::Es256 { "ES256" } else { "PS256" });
                    if let Some(k) = s1.kid {
                        o.hex("kid", &k).str("kidBase64", &cose::base64_encode(&k, false));
                    }
                }
                Ok(o.done())
            }
            // Section 11
            "verify" => {
                let mut store = TrustStore::new();
                if let Some(pem) = a.get("trustPem").and_then(Json::as_str).filter(|p| !p.trim().is_empty()) {
                    store.add_pem(pem).map_err(|e| e.to_string())?;
                }
                // A trust-list DID document, as the GDHCN trust list serves it (STT-TRU-001).
                // With `trustDidSigner`, the did:web document of the proof's
                // verificationMethod, its keys are trusted only once its proof
                // verifies; a failed proof is an error and nothing is verified (STT-TRU-006).
                let did = a.get("trustDid").and_then(Json::as_str).filter(|d| !d.trim().is_empty());
                let signer = a.get("trustDidSigner").and_then(Json::as_str).filter(|d| !d.trim().is_empty());
                match (did, signer) {
                    (Some(did), Some(signer)) => store.add_verified_did_document(did, signer).map(|_| ()),
                    (Some(did), None) => store.add_did_document(did).map(|_| ()),
                    (None, Some(_)) => return Err("trustDidSigner needs trustDid".into()),
                    (None, None) => Ok(()),
                }
                .map_err(|e| e.to_string())?;
                let options = VerifierOptions {
                    clock_skew_seconds: a.get("clockSkewSeconds").and_then(Json::as_f64).unwrap_or(300.0) as i64,
                    max_payloads: a.get("maxPayloads").and_then(Json::as_f64).map(|m| m as u32),
                    ..Default::default()
                };
                let now = i(&a, "now")?;
                let r = match a.get("coseHex").and_then(Json::as_str) {
                    Some(h) => verifier::verify_cose(&from_hex(h).ok_or("coseHex is not hex")?, &store, &reg, now, &options),
                    None => verifier::verify(s(&a, "hc1")?, &store, &reg, now, &options),
                };
                let mut o = Obj::ok();
                o.raw("trustDidProofVerified", (did.is_some() && signer.is_some()).to_string());
                match r {
                    Ok(v) => {
                        o.str("status", "verified").opt_str("iss", v.iss.as_deref()).num("iat", v.iat).num("exp", v.exp).hex("kid", &v.dsc.kid);
                        o.opt_str("dscCountry", v.dsc.country.as_deref()).num("dscNotBefore", v.dsc.not_before).num("dscNotAfter", v.dsc.not_after);
                        // Every valid hcert entry, in wire order (STT-SEL-004).
                        let entries: Vec<String> = v
                            .entries
                            .iter()
                            .map(|e| {
                                let mut x = Obj::default();
                                x.num("subclaim", e.subclaim).raw("keyUsageAuthorised", e.key_usage_authorised.to_string());
                                match &e.payload {
                                    Payload::DvcMin(p) => x.str("payloadKind", "DVCMin").raw("payload", dvc_json(p)),
                                    Payload::Vhl(p) => x.str("payloadKind", "VHL").str("payloadVhlink", &crate::vhl::to_vhlink(p)),
                                    Payload::Raw { cbor: c, .. } => x.str("payloadKind", "raw").str("payloadDiagnostic", &diag_of(c)),
                                };
                                x.done()
                            })
                            .collect();
                        o.raw("entries", format!("[{}]", entries.join(",")));
                        let d: Vec<String> = v.diagnostics.iter().map(|d| quote(&format!("{}: {}", d.step.wire_name(), d.message))).collect();
                        o.raw("diagnostics", format!("[{}]", d.join(",")));
                    }
                    Err(f) => {
                        o.str("status", "failed").str("step", f.step.wire_name()).str("reason", f.reason.wire_name()).str("detail", &f.detail);
                    }
                }
                Ok(o.done())
            }
            // TEST ONLY: a self-signed DSC around the page's own key
            "testDscTbs" => {
                let ekus = a.get("extendedKeyUsages").and_then(Json::as_arr).unwrap_or_default().iter().filter_map(Json::as_str).map(str::to_owned).collect();
                let tbs = testdsc::tbs_certificate(&TestDscRequest {
                    spki_der: hex(&a, "spki")?,
                    alg: alg(&a)?,
                    country: a.get("country").and_then(Json::as_str).unwrap_or("XX").into(),
                    common_name: a.get("commonName").and_then(Json::as_str).unwrap_or("TEST ONLY demo DSC").into(),
                    not_before: i(&a, "notBefore")?,
                    not_after: i(&a, "notAfter")?,
                    serial: a.get("serial").and_then(Json::as_f64).unwrap_or(1.0) as u64,
                    extended_key_usages: ekus,
                })?;
                Ok(Obj::ok().hex("tbs", &tbs).done())
            }
            "testDscCertificate" => {
                let der = testdsc::certificate(&hex(&a, "tbs")?, alg(&a)?, &hex(&a, "signature")?)?;
                let b64 = cose::base64_encode(&der, false);
                let pem = format!("-----BEGIN CERTIFICATE-----\n{}\n-----END CERTIFICATE-----\n", b64.as_bytes().chunks(64).map(|c| std::str::from_utf8(c).unwrap()).collect::<Vec<_>>().join("\n"));
                let kid = cose::kid_from_dsc(&der);
                Ok(Obj::ok().hex("der", &der).str("pem", &pem).hex("kid", &kid).str("kidBase64", &cose::base64_encode(&kid, false)).done())
            }
            // Step 9, for the demos only (feature `qr`): the HC1 string as a
            // QR symbol, error correction Q. Base45 and the HC1: prefix are all
            // in the Alphanumeric set, so the encoder's segmenter picks that mode.
            #[cfg(feature = "qr")]
            "qrSvg" => {
                use qrcode::{render::svg, EcLevel, QrCode, Version};
                let text = s(&a, "text")?;
                let code = QrCode::with_error_correction_level(text.as_bytes(), EcLevel::Q).map_err(|e| format!("cannot encode: {e:?}"))?;
                let version = match code.version() {
                    Version::Normal(v) => v as i64,
                    Version::Micro(v) => -(v as i64),
                };
                let svg = code.render::<svg::Color>().min_dimensions(240, 240).quiet_zone(true).build();
                Ok(Obj::ok().num("version", version).str("errorCorrection", "Q").num("modules", code.width() as i64).str("svg", &svg).done())
            }
            other => Err(format!("unknown op {other}")),
        }
    };
    run().unwrap_or_else(|e| error(&e))
}
