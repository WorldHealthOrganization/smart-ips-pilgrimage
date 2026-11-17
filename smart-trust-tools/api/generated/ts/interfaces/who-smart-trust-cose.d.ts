/** @module Interface who:smart-trust/cose@0.1.0 **/
/**
 * First 8 bytes of SHA-256 over the DER-encoded DSC. [STT-KID-001]
 */
export function kidFromDsc(dscDer: Uint8Array): Kid;
/**
 * [STT-KID-003]
 */
export function kidToBase64(k: Kid, alphabet: Base64Alphabet): string;
export function kidFromBase64(text: string): Kid;
export function parseSign1(bytes: Uint8Array, limits: DecodeLimits): Sign1;
/**
 * CBOR of ["Signature1", protected, h'', payload].
 */
export function sigStructure(protected_: Uint8Array, payload: Uint8Array): Uint8Array;
/**
 * Verify a parsed COSE_Sign1 against one DSC. Low level: does not
 * check EKU, time or trust. [STT-COS-002]
 */
export function verifySign1(s: Sign1, dscDer: Uint8Array): void;
/**
 * ASN.1 DER ECDSA-Sig-Value <-> fixed-width r||s. [STT-COS-005]
 */
export function ecdsaDerToRaw(der: Uint8Array): Uint8Array;
export function ecdsaRawToDer(raw: Uint8Array): Uint8Array;
export type CoseAlgorithm = import('./who-smart-trust-types.js').CoseAlgorithm;
export type Kid = import('./who-smart-trust-types.js').Kid;
export type DecodeLimits = import('./who-smart-trust-types.js').DecodeLimits;
export type CoseError = CoseErrorMalformed | CoseErrorHeaderInvalid | CoseErrorUnsupportedAlgorithm | CoseErrorBadSignatureFormat | CoseErrorSignatureInvalid | CoseErrorBadCertificate;
export interface CoseErrorMalformed {
  tag: 'malformed',
  val: string,
}
/**
 * Protected header failed type/length checks. [STT-VER-003]
 */
export interface CoseErrorHeaderInvalid {
  tag: 'header-invalid',
  val: string,
}
export interface CoseErrorUnsupportedAlgorithm {
  tag: 'unsupported-algorithm',
  val: number,
}
/**
 * ES256 signature not exactly 64 bytes, or bad DER. [STT-COS-005]
 */
export interface CoseErrorBadSignatureFormat {
  tag: 'bad-signature-format',
  val: string,
}
export interface CoseErrorSignatureInvalid {
  tag: 'signature-invalid',
}
export interface CoseErrorBadCertificate {
  tag: 'bad-certificate',
  val: string,
}
/**
 * A parsed COSE_Sign1. `protected` is kept as received so the
 * Sig_structure is rebuilt from the original bytes. [STT-COS-004]
 */
export interface Sign1 {
  'protected': Uint8Array,
  payload: Uint8Array,
  signature: Uint8Array,
  alg?: CoseAlgorithm,
  /**
   * The protected kid if present, else the unprotected kid.
   * [STT-COS-003]
   */
  kid?: Kid,
  kidInProtected: boolean,
  /**
   * Whether the input carried CBOR tag 18. [STT-COS-001]
   */
  tagged: boolean,
}
/**
 * # Variants
 * 
 * ## `"standard"`
 * 
 * ## `"url-safe"`
 */
export type Base64Alphabet = 'standard' | 'url-safe';
