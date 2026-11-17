/** @module Interface who:smart-trust/vhl@0.1.0 **/
/**
 * Every rule of the payload format; with `now`, an expired link too.
 * [STT-VHL-001, STT-VHL-009]
 */
export function validate(p: VhlPayload, now: NumericDate | undefined): Array<ValidationIssue>;
/**
 * [STT-VHL-003]
 */
export function toVhlink(p: VhlPayload): string;
export function fromVhlink(text: string): VhlPayload;
/**
 * A new key from the platform's secure random generator. [STT-VHL-004]
 */
export function newKey(): string;
/**
 * [STT-VHL-005]
 */
export function buildManifestRequest(p: VhlPayload, recipient: string, passcode: string | undefined, embeddedLengthMax: number | undefined): ManifestRequest;
/**
 * The ITI-YY5 searchset Bundle. [STT-VHL-006]
 */
export function parseManifest(bundleJson: string): Array<ManifestDocument>;
/**
 * JWE Compact, dir / A256GCM, the payload key. [STT-VHL-007]
 */
export function encrypt(content: Uint8Array, contentType: string, key: string): string;
export function decrypt(jwe: string, key: string): Decrypted;
/**
 * [STT-VHL-008]
 */
export function buildSignatureBase(r: SignatureRequest): SignatureBase;
/**
 * The Signature header value. An ecdsa-p256-sha256 DER signature is
 * converted to r||s.
 */
export function signatureHeader(signature: Uint8Array, alg: string): string;
export type ValidationIssue = import('./who-smart-trust-types.js').ValidationIssue;
export type NumericDate = import('./who-smart-trust-types.js').NumericDate;
/**
 * The SMART Health Links payload format that IHE VHL reuses. At HCERT
 * claim -260 key 5 it is a CBOR map with these text keys
 * (fhir-base-url is extension.fhirBaseUrl). [STT-VHL-001, STT-VHL-002]
 */
export interface VhlPayload {
  /**
   * Manifest URL: a FHIR List search with _id, code, status and
   * patient.identifier.
   */
  url: string,
  /**
   * 32 random bytes, 43 base64url characters.
   */
  key: string,
  /**
   * Expiry, epoch seconds.
   */
  exp?: bigint,
  /**
   * L and/or P, in alphabetical order.
   */
  flag?: string,
  /**
   * At most 80 characters.
   */
  label?: string,
  /**
   * Protocol version; 1 when absent.
   */
  v?: number,
  /**
   * extension.fhirBaseUrl, for the OAuth with SSRAA option.
   */
  fhirBaseUrl?: string,
}
export type VhlError = VhlErrorInvalid | VhlErrorNotAVhlink | VhlErrorManifest | VhlErrorDecryptFailed | VhlErrorUnsupported;
export interface VhlErrorInvalid {
  tag: 'invalid',
  val: Array<ValidationIssue>,
}
/**
 * Not of the form vhlink:/<base64url JSON>.
 */
export interface VhlErrorNotAVhlink {
  tag: 'not-a-vhlink',
  val: string,
}
export interface VhlErrorManifest {
  tag: 'manifest',
  val: string,
}
/**
 * Wrong key, a bad tag, or a malformed JWE.
 */
export interface VhlErrorDecryptFailed {
  tag: 'decrypt-failed',
  val: string,
}
/**
 * A JWE alg or enc other than dir / A256GCM. [STT-VHL-007]
 */
export interface VhlErrorUnsupported {
  tag: 'unsupported',
  val: string,
}
/**
 * The ITI-YY5 Retrieve Manifest request for the host to POST.
 */
export interface ManifestRequest {
  /**
   * <base>/List/_search
   */
  url: string,
  /**
   * application/x-www-form-urlencoded
   */
  contentType: string,
  body: string,
}
/**
 * One document listed by the manifest.
 */
export interface ManifestDocument {
  /**
   * DocumentReference.content.attachment.url, when the DocumentReference
   * was included; the host GETs it (ITI-68).
   */
  url?: string,
  /**
   * List.entry.item.reference, when it was not; the host reads it first.
   */
  reference?: string,
  /**
   * The decrypted content type (attachment.contentType).
   */
  contentType?: string,
  title?: string,
}
export interface Decrypted {
  /**
   * The JWE cty header, when present.
   */
  contentType?: string,
  content: Uint8Array,
}
/**
 * What the receiver signs for the HTTP Message Signatures option.
 */
export interface SignatureRequest {
  method: string,
  authority: string,
  path: string,
  contentType?: string,
  body?: Uint8Array,
  keyid: string,
  /**
   * e.g. ecdsa-p256-sha256
   */
  alg: string,
  created: NumericDate,
}
export interface SignatureBase {
  /**
   * RFC 9530 Content-Digest header value, when there is a body.
   */
  contentDigest?: string,
  /**
   * Signature-Input header value.
   */
  signatureInput: string,
  /**
   * The RFC 9421 signature base: the bytes the host signs.
   */
  base: Uint8Array,
}
