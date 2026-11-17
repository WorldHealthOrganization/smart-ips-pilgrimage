/** @module Interface who:smart-trust/subclaims@0.1.0 **/
export type Subclaim = import('./who-smart-trust-types.js').Subclaim;
/**
 * Payload kinds that have a typed codec. Others travel as raw CBOR.
 * # Variants
 * 
 * ## `"dvc-min"`
 * 
 * ## `"vhl"`
 */
export type PayloadKind = 'dvc-min' | 'vhl';

export class Registry implements Disposable {
  /**
  * Starts with the IG defaults: 1, 3, 4, 5, -6, -7; VHL is 5. [STT-SEL-001]
  */
  constructor()
  lookup(key: number): Subclaim | undefined;
  register(s: Subclaim): void;
  all(): Array<Subclaim>;
  /**
  * Which subclaim number carries the given payload kind.
  */
  subclaimFor(kind: PayloadKind): number | undefined;
  setSubclaimFor(kind: PayloadKind, key: number): void;
  [Symbol.dispose](): void;
}
