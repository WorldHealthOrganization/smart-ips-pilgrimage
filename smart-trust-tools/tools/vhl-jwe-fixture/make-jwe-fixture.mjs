// Makes jwe-dir-a256gcm.json with node:crypto alone, independently of the
// library, so the library's JWE decryption is checked against another
// implementation of RFC 7516 dir / A256GCM, and writes it to vectors/ihe-vhl/.
//   node tools/vhl-jwe-fixture/make-jwe-fixture.mjs
import { createCipheriv, randomBytes } from "node:crypto";
import { deflateRawSync } from "node:zlib";
import { writeFileSync } from "node:fs";

const b64u = (b) => Buffer.from(b).toString("base64url");
const key = randomBytes(32);
const plaintext = JSON.stringify({ resourceType: "Bundle", type: "document", id: "ips-test-only" });
function jwe(header, body) {
  const h = b64u(JSON.stringify(header));
  const iv = randomBytes(12);
  const c = createCipheriv("aes-256-gcm", key, iv, { authTagLength: 16 });
  c.setAAD(Buffer.from(h, "ascii"));
  const ct = Buffer.concat([c.update(body), c.final()]);
  return `${h}..${b64u(iv)}.${b64u(ct)}.${b64u(c.getAuthTag())}`;
}
writeFileSync(new URL("../../vectors/ihe-vhl/jwe-dir-a256gcm.json", import.meta.url), JSON.stringify({
  note: "TEST ONLY. Made by make-jwe-fixture.mjs with node:crypto, not with the library.",
  key: b64u(key),
  plaintext,
  contentType: "application/fhir+json",
  jwe: jwe({ alg: "dir", enc: "A256GCM", cty: "application/fhir+json" }, Buffer.from(plaintext)),
  jweZipDef: jwe({ alg: "dir", enc: "A256GCM", cty: "application/fhir+json", zip: "DEF" }, deflateRawSync(Buffer.from(plaintext))),
}, null, 2) + "\n");
