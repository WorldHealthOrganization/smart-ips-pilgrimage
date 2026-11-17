/** @module Interface who:smart-trust/payloads@0.1.0 **/
export type CborBytes = import('./who-smart-trust-types.js').CborBytes;
export type DvcMin = import('./who-smart-trust-dvc.js').DvcMin;
export type VhlPayload = import('./who-smart-trust-vhl.js').VhlPayload;
export interface RawPayload {
  subclaim: number,
  cbor: CborBytes,
}
export type Payload = PayloadDvcMin | PayloadVhl | PayloadRaw;
export interface PayloadDvcMin {
  tag: 'dvc-min',
  val: DvcMin,
}
export interface PayloadVhl {
  tag: 'vhl',
  val: VhlPayload,
}
export interface PayloadRaw {
  tag: 'raw',
  val: RawPayload,
}
