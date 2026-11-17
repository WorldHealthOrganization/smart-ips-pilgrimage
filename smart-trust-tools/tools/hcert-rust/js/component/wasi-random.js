// wasi:random/random@0.2.6 for the transpiled component, in browsers and
// Node: the platform's crypto.getRandomValues, in chunks of 64 KiB (its
// per-call limit). It stands in for @bytecodealliance/preview2-shim, so the
// component needs no npm package at run time.
export const random = {
  getRandomBytes(len) {
    const n = Number(len);
    const out = new Uint8Array(n);
    for (let i = 0; i < n; i += 65536) crypto.getRandomValues(out.subarray(i, Math.min(n, i + 65536)));
    return out;
  },
  getRandomU64() {
    const b = new BigUint64Array(1);
    crypto.getRandomValues(b);
    return b[0];
  },
};
