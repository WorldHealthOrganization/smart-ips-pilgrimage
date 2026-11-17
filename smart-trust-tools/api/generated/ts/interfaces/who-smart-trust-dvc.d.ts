/** @module Interface who:smart-trust/dvc@0.1.0 **/
/**
 * Cardinality, invariant (must-have-issuer-or-clinician-name) and nt
 * checks. [STT-PAY-004, STT-PAY-007]
 */
export function validate(p: DvcMin): Array<ValidationIssue>;
export function toCbor(p: DvcMin): CborBytes;
export function fromCbor(cbor: CborBytes, limits: DecodeLimits): DvcMin;
export type ValidationIssue = import('./who-smart-trust-types.js').ValidationIssue;
export type CborBytes = import('./who-smart-trust-types.js').CborBytes;
export type DecodeLimits = import('./who-smart-trust-types.js').DecodeLimits;
/**
 * DVCMinVaccineDetails. [STT-PAY-002]
 */
export interface DvcMinVaccineDetails {
  /**
   * Vaccine product identifier.
   */
  vp: string,
  /**
   * Date of vaccination (FHIR date).
   */
  dv: string,
  /**
   * Supervising clinician.
   */
  cn?: string,
  /**
   * Issuing organization identifier.
   */
  is?: string,
  /**
   * Batch or lot number.
   */
  bo: string,
}
/**
 * DVCMin. vx is 1..1: one immunization event per certificate.
 * [STT-PAY-001, STT-PAY-003, STT-PAY-005]
 */
export interface DvcMin {
  n: string,
  dob: string,
  s: string,
  /**
   * ISO 3166-1 alpha-3. [STT-PAY-007]
   */
  nt: string,
  id?: string,
  dt?: string,
  gn?: string,
  vx: DvcMinVaccineDetails,
  v: string,
  /**
   * Elements this version does not know, kept as CBOR map entries
   * (key, encoded value). [STT-PAY-008]
   */
  extensions: Array<[string, CborBytes]>,
}
