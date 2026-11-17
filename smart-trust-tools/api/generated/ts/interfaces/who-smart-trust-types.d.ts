/** @module Interface who:smart-trust/types@0.1.0 **/
/**
 * COSE algorithm. es256 = -7 (primary), ps256 = -37 (secondary).
 * Both MUST be implemented. [STT-COS-002]
 * # Variants
 * 
 * ## `"es256"`
 * 
 * ## `"ps256"`
 */
export type CoseAlgorithm = 'es256' | 'ps256';
/**
 * 8-byte key identifier: first 8 bytes of SHA-256 over the DER DSC.
 * [STT-KID-001]
 */
export type Kid = Uint8Array;
/**
 * CWT NumericDate: integer seconds since the Unix epoch. [STT-CWT-002]
 */
export type NumericDate = bigint;
/**
 * Encoded CBOR data item.
 */
export type CborBytes = Uint8Array;
/**
 * An hcert subclaim number and what it carries. Negative numbers are
 * the development range. [STT-SEL-001, STT-SEL-003]
 */
export interface Subclaim {
  key: number,
  title: string,
  /**
   * Canonical URL of the FHIR logical model, when there is one.
   */
  logicalModel?: string,
}
/**
 * Bounds applied while decoding untrusted input. [STT-CBR-003,
 * STT-ZIP-002]
 */
export interface DecodeLimits {
  maxInputChars: number,
  maxInflatedBytes: number,
  maxDepth: number,
  maxItems: number,
  maxStringBytes: number,
}
/**
 * # Variants
 * 
 * ## `"blocking"`
 * 
 * ## `"warning"`
 * 
 * ## `"information"`
 */
export type Severity = 'blocking' | 'warning' | 'information';
/**
 * One payload validation finding. `path` names the element.
 */
export interface ValidationIssue {
  path: string,
  code: string,
  message: string,
  severity: Severity,
}
/**
 * Verification steps, in the order they run. [STT-VER-001]
 * # Variants
 * 
 * ## `"prefix"`
 * 
 * ## `"base45"`
 * 
 * ## `"inflate"`
 * 
 * ## `"cose"`
 * 
 * ## `"header"`
 * 
 * ## `"trust-lookup"`
 * 
 * ## `"signature"`
 * 
 * ## `"key-usage"`
 * 
 * ## `"cwt"`
 * 
 * ## `"time"`
 * 
 * ## `"hcert"`
 * 
 * ## `"payload"`
 */
export type Step = 'prefix' | 'base45' | 'inflate' | 'cose' | 'header' | 'trust-lookup' | 'signature' | 'key-usage' | 'cwt' | 'time' | 'hcert' | 'payload';
/**
 * Why verification stopped. [STT-VER-008]
 * # Variants
 * 
 * ## `"bad-prefix"`
 * 
 * ## `"unsupported-context-version"`
 * 
 * ## `"base45-invalid"`
 * 
 * ## `"inflate-failed"`
 * 
 * ## `"limit-exceeded"`
 * 
 * ## `"cose-malformed"`
 * 
 * ## `"header-invalid"`
 * 
 * ## `"unsupported-algorithm"`
 * 
 * ## `"kid-not-found"`
 * 
 * ## `"signature-invalid"`
 * 
 * ## `"key-usage-mismatch"`
 * 
 * ## `"expired"`
 * 
 * ## `"not-yet-valid"`
 * 
 * ## `"hcert-missing"`
 * 
 * ## `"multiple-subclaims"`
 * 
 * ## `"payload-invalid"`
 */
export type FailureReason = 'bad-prefix' | 'unsupported-context-version' | 'base45-invalid' | 'inflate-failed' | 'limit-exceeded' | 'cose-malformed' | 'header-invalid' | 'unsupported-algorithm' | 'kid-not-found' | 'signature-invalid' | 'key-usage-mismatch' | 'expired' | 'not-yet-valid' | 'hcert-missing' | 'multiple-subclaims' | 'payload-invalid';
/**
 * A non-fatal observation made while verifying.
 */
export interface Diagnostic {
  step: Step,
  severity: Severity,
  message: string,
}
