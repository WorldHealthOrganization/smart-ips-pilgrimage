//! A seeded mutation fuzzer over the decoders' entry points (STT-TST-006),
//! the same targets and seeds as the Kotlin FuzzTest. cargo-fuzz, which is
//! coverage-guided, needs a nightly toolchain and is run outside CI.
//! STT_FUZZ_ITERATIONS raises the count for a longer local run.

mod common;
use common::*;
use hcert::{codec, cose, types::*, verifier};
use std::time::{Duration, Instant};

struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n.max(1) as u64) as usize
    }
}

fn mutate(r: &mut Rng, seed: &[u8]) -> Vec<u8> {
    let mut b = seed.to_vec();
    for _ in 0..1 + r.below(4) {
        let n = b.len();
        match r.below(6) {
            0 if n > 0 => {
                let i = r.below(n);
                b[i] ^= 1 << r.below(8);
            }
            1 => b.insert(r.below(n + 1), r.next() as u8),
            2 if n > 0 => {
                b.remove(r.below(n));
            }
            3 if n > 0 => b.truncate(r.below(n)),
            4 if n > 0 => {
                let i = r.below(n);
                b[i] = [0x00, 0x7f, 0x80, 0xff, 0x9f, 0xbf, 0xd8, 0x1b][r.below(8)];
            }
            5 if n > 0 => {
                let i = r.below(n);
                let run = b[i..(i + 1 + r.below(16)).min(n)].to_vec();
                let at = r.below(b.len() + 1);
                b.splice(at..at, run);
            }
            _ => {}
        }
    }
    b
}

fn mutate_text(r: &mut Rng, seed: &str) -> String {
    let alphabet = hcert::base45::ALPHABET;
    let mut b = seed.as_bytes().to_vec();
    for _ in 0..1 + r.below(4) {
        let n = b.len();
        match r.below(4) {
            0 if n > 0 => {
                let i = r.below(n);
                b[i] = alphabet[r.below(45)];
            }
            1 => b.insert(r.below(n + 1), alphabet[r.below(45)]),
            2 if n > 0 => {
                b.remove(r.below(n));
            }
            3 if n > 0 => b.truncate(r.below(n)),
            _ => {}
        }
    }
    String::from_utf8(b).unwrap()
}

fn iterations() -> usize {
    std::env::var("STT_FUZZ_ITERATIONS").ok().and_then(|v| v.parse().ok()).unwrap_or(1500)
}

/// Runs `call` on mutated seeds: a panic fails the test, and no call may take a second.
fn fuzz<T, M: Fn(&mut Rng, &T) -> T, F: Fn(&T)>(target: &str, seeds: &[T], mutator: M, call: F) {
    let mut r = Rng(target.bytes().fold(0xcbf2_9ce4_8422_2325u64, |h, b| (h ^ b as u64).wrapping_mul(0x100_0000_01b3)));
    let mut slowest = Duration::ZERO;
    for n in 0..iterations() {
        let input = mutator(&mut r, &seeds[n % seeds.len()]);
        let start = Instant::now();
        call(&input);
        slowest = slowest.max(start.elapsed());
    }
    assert!(slowest < Duration::from_secs(1), "{target}: slowest call took {slowest:?}");
}

fn seeds() -> (Vec<String>, Vec<Vec<u8>>, Vec<Vec<u8>>, Vec<Vec<u8>>) {
    let hc1s: Vec<String> = ["hepb1", "bcg"].iter().map(|n| pr129_hc1(n)).collect();
    let coses: Vec<Vec<u8>> = hc1s.iter().map(|h| codec::from_hc1(h, &DEFAULT_LIMITS).unwrap()).collect();
    let payloads = coses.iter().map(|c| cose::parse_sign1(c, &DEFAULT_LIMITS).unwrap().payload).collect();
    let deflated = hc1s.iter().map(|h| codec::base45_decode(&h[4..]).unwrap()).collect();
    (hc1s, coses, payloads, deflated)
}

#[test]
fn stt_tst_006_fuzzed_base45_never_panics_and_never_decodes_more_than_its_input() {
    let b45: Vec<String> = seeds().0.iter().map(|h| h[4..].to_string()).collect();
    fuzz("base45Decode", &b45, |r, s| mutate_text(r, s), |s| {
        if let Ok(b) = codec::base45_decode(s) {
            assert!(b.len() <= s.len());
        }
    });
}

#[test]
fn stt_tst_006_fuzzed_zlib_never_panics_and_never_inflates_past_the_limit() {
    fuzz("zlibInflate", &seeds().3, |r, s| mutate(r, s), |s| {
        if let Ok(b) = codec::zlib_inflate(s, DEFAULT_LIMITS.max_inflated_bytes) {
            assert!(b.len() <= DEFAULT_LIMITS.max_inflated_bytes);
        }
    });
}

#[test]
fn stt_tst_006_fuzzed_cbor_never_panics_in_the_deterministic_re_encoder() {
    fuzz("cborDeterministic", &seeds().2, |r, s| mutate(r, s), |s| {
        let _ = codec::cbor_deterministic(s, &DEFAULT_LIMITS);
    });
}

#[test]
fn stt_tst_006_fuzzed_cose_never_panics_in_the_sign1_parser() {
    fuzz("parseSign1", &seeds().1, |r, s| mutate(r, s), |s| {
        let _ = cose::parse_sign1(s, &DEFAULT_LIMITS);
    });
}

#[test]
fn stt_tst_006_fuzzed_hc1_strings_never_panic_in_the_qr_layers_or_the_verifier() {
    let store = pr129_store();
    fuzz("verify", &seeds().0, |r, s| mutate_text(r, s), |s| {
        if let Ok(b) = codec::from_hc1(s, &DEFAULT_LIMITS) {
            assert!(b.len() <= DEFAULT_LIMITS.max_inflated_bytes);
        }
        let _ = verifier::verify(s, &store, &reg(), NOW, &options());
        let _ = verifier::read_unverified(s, &reg(), &DEFAULT_LIMITS);
    });
}

#[test]
fn stt_tst_006_fuzzed_cose_bytes_never_panic_in_the_verifier() {
    let store = pr129_store();
    fuzz("verifyCose", &seeds().1, |r, s| mutate(r, s), |s| {
        let _ = verifier::verify_cose(s, &store, &reg(), NOW, &options());
    });
}
