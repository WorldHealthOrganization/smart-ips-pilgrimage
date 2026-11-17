//! SMART Trust HCERT: the QR Code Generation pipeline and the verifier.
//!
//! Each step is its own public function (STT-GEN-002): [`codec`] holds the
//! prefix, Base45, ZLIB and CBOR steps, [`cose`] the COSE_Sign1 step,
//! [`payload`] the subclaims and the DVC payload, [`trust`] the trust store, [`didproof`] trust list DID document proofs,
//! [`issuer`] two-phase issuance (the host signs) and [`verifier`] the
//! QR Code Generation section 11 checks. No I/O anywhere (STT-GEN-012).

pub mod api;
pub mod base45;
pub mod cbor;
pub mod codec;
pub mod cose;
pub mod didproof;
mod entropy;
pub mod issuer;
pub mod json;
pub mod payload;
pub mod testdsc;
pub mod trust;
pub mod types;
pub mod verifier;
pub mod vhl;
mod x509;

#[cfg(all(target_arch = "wasm32", not(feature = "component")))]
mod wasm;

#[cfg(feature = "component")]
mod component;

pub use types::*;

// The import-free module has no entropy: verification needs none, and
// signing is the host's. The component asks its host (wasi:random/random).
#[cfg(all(target_arch = "wasm32", not(feature = "component")))]
fn no_entropy(_: &mut [u8]) -> Result<(), getrandom::Error> {
    Err(getrandom::Error::UNSUPPORTED)
}
#[cfg(all(target_arch = "wasm32", not(feature = "component")))]
getrandom::register_custom_getrandom!(no_entropy);
