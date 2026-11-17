/** @module Interface who:smart-trust/issuer@0.1.0 **/
/**
 * Phase 1: validate, build CWT, CBOR and protected header.
 */
export function prepare(req: IssueRequest, reg: Registry): PendingSignature;
/**
 * Phase 2: attach the signature. ES256 accepts r||s or DER and always
 * emits r||s. [STT-COS-005]
 */
export function finish(pending: PendingSignature, signature: Uint8Array): IssuedHcert;
export type CoseAlgorithm = import('./who-smart-trust-types.js').CoseAlgorithm;
export type Kid = import('./who-smart-trust-types.js').Kid;
export type NumericDate = import('./who-smart-trust-types.js').NumericDate;
export type ValidationIssue = import('./who-smart-trust-types.js').ValidationIssue;
export type Payload = import('./who-smart-trust-payloads.js').Payload;
export type Registry = import('./who-smart-trust-subclaims.js').Registry;
export interface Validity {
  iat: NumericDate,
  /**
   * Mandatory: exp is the only revocation mechanism. [STT-CWT-003]
   */
  exp: NumericDate,
}
export interface IssueRequest {
  /**
   * One or more payloads, each under its own subclaim in the hcert
   * claim, in subclaim-key order on the wire. [STT-SEL-004]
   */
  payloads: Array<Payload>,
  /**
   * CWT iss, alpha-2. [STT-CWT-005]
   */
  iss?: string,
  validity: Validity,
  /**
   * DSC whose key will sign; kid is derived from it. [STT-KID-001]
   */
  dscDer: Uint8Array,
  alg: CoseAlgorithm,
  /**
   * Refuse negative subclaims unless true. [STT-SEL-003]
   */
  allowDevelopmentSubclaims: boolean,
}
export type IssueError = IssueErrorPayloadInvalid | IssueErrorNoPayload | IssueErrorDuplicateSubclaim | IssueErrorDevelopmentSubclaimNotAllowed | IssueErrorUnknownSubclaim | IssueErrorValidityOutsideDsc | IssueErrorBadCertificate | IssueErrorBadSignatureFormat;
export interface IssueErrorPayloadInvalid {
  tag: 'payload-invalid',
  val: Array<ValidationIssue>,
}
/**
 * The request carries no payload.
 */
export interface IssueErrorNoPayload {
  tag: 'no-payload',
}
/**
 * Two payloads map to the same subclaim. [STT-SEL-004]
 */
export interface IssueErrorDuplicateSubclaim {
  tag: 'duplicate-subclaim',
  val: number,
}
export interface IssueErrorDevelopmentSubclaimNotAllowed {
  tag: 'development-subclaim-not-allowed',
  val: number,
}
export interface IssueErrorUnknownSubclaim {
  tag: 'unknown-subclaim',
  val: number,
}
/**
 * iat before or exp after the DSC validity. [STT-CWT-004]
 */
export interface IssueErrorValidityOutsideDsc {
  tag: 'validity-outside-dsc',
}
export interface IssueErrorBadCertificate {
  tag: 'bad-certificate',
  val: string,
}
export interface IssueErrorBadSignatureFormat {
  tag: 'bad-signature-format',
  val: string,
}
export interface IssuedHcert {
  /**
   * QR-ready: QR Alphanumeric characters only. [STT-QR-001]
   */
  hc1: string,
  /**
   * Raw COSE_Sign1 for 8-bit-safe transports. [STT-GEN-009]
   */
  cose: Uint8Array,
}

export class PendingSignature implements Disposable {
  /**
   * This type does not have a public constructor.
   */
  private constructor();
  /**
  * Bytes to sign (CBOR Sig_structure). [STT-COS-004]
  */
  toBeSigned(): Uint8Array;
  algorithm(): CoseAlgorithm;
  kid(): Kid;
  [Symbol.dispose](): void;
}
