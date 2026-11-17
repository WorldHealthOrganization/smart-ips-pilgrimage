/** @module Interface who:smart-trust/codec@0.1.0 **/
/**
 * RFC 9285 Base45. [STT-B45-001]
 */
export function base45Encode(data: Uint8Array): string;
export function base45Decode(text: string): Uint8Array;
/**
 * ZLIB (RFC 1950) wrapping DEFLATE (RFC 1951). [STT-ZIP-001]
 */
export function zlibCompress(data: Uint8Array, level: number): Uint8Array;
export function zlibInflate(data: Uint8Array, maxOut: number): Uint8Array;
/**
 * Returns the context identifier version character (e.g. "1") and
 * the remainder after the colon. [STT-HC1-001]
 */
export function detectContext(text: string): [string, string];
/**
 * Steps 6 to 8: COSE bytes to "HC1:..." string. The result uses only
 * QR Alphanumeric characters. [STT-QR-001]
 */
export function toHc1(cose: Uint8Array): string;
/**
 * Steps 8 to 6 reversed: "HC1:..." string to COSE bytes.
 */
export function fromHc1(text: string, limits: DecodeLimits): Uint8Array;
/**
 * Re-encode CBOR using RFC 8949 core deterministic encoding.
 * [STT-CBR-001]
 */
export function cborDeterministic(cbor: CborBytes, limits: DecodeLimits): CborBytes;
export type DecodeLimits = import('./who-smart-trust-types.js').DecodeLimits;
export type CborBytes = import('./who-smart-trust-types.js').CborBytes;
export type CodecError = CodecErrorBase45Invalid | CodecErrorInflateFailed | CodecErrorLimitExceeded | CodecErrorCborMalformed | CodecErrorBadPrefix | CodecErrorUnsupportedContextVersion;
/**
 * Character outside the alphabet, dangling character or overflow.
 * [STT-B45-002]
 */
export interface CodecErrorBase45Invalid {
  tag: 'base45-invalid',
  val: string,
}
export interface CodecErrorInflateFailed {
  tag: 'inflate-failed',
  val: string,
}
/**
 * A decode-limits bound was hit. [STT-CBR-003, STT-ZIP-002]
 */
export interface CodecErrorLimitExceeded {
  tag: 'limit-exceeded',
  val: string,
}
export interface CodecErrorCborMalformed {
  tag: 'cbor-malformed',
  val: string,
}
/**
 * No `HC[1-9A-Z]:` context identifier. [STT-HC1-001]
 */
export interface CodecErrorBadPrefix {
  tag: 'bad-prefix',
}
/**
 * A well-formed context identifier other than HC1, e.g. "HC2".
 */
export interface CodecErrorUnsupportedContextVersion {
  tag: 'unsupported-context-version',
  val: string,
}
