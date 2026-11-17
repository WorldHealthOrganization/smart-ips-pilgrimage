---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s017-12-4-the-payload
section_title: "12.4 The payload"
file: "input/pagecontent/qr_code_generation.md"
lines: 250-288
source_sha256: 03253100cd38b5c6
granularity: heading
---
##### 12.4 The payload

Hepatitis B birth dose, `hcert` subclaim `-6`, shown in JSON notation. `vp`
carries the PreQual product identifier of the product actually administered:

```json
{
  "n":   "Chanthala SOUVANNALATH",
  "dob": "2026-10-21",
  "s":   "female",
  "nt":  "LAO",
  "gn":  "Mali SOUVANNALATH",
  "vx": {
    "vp": "a3K3X000006MiiXUAS",
    "dv": "2026-10-21",
    "cn": "Dr Pimchanok WATTANA",
    "is": "org-xxr-provincial-hospital",
    "bo": "HEPB-2026-0914"
  },
  "v": "1.0.0"
}
```

`a3K3X000006MiiXUAS` is *Hepatitis B Vaccine (rDNA) (Paediatric)* (FVP-P-132) in
the [WHO PreQual product identifiers](http://smart.who.int/pcmt-vaxprequal/CodeSystem-PreQualProductIds.html).
The BCG certificate is identical but for `vp`, which carries
`a3K3X000006MiiCUAS`, *BCG Vaccine* (FVP-P-73), and its batch number.

Wrapped in the CWT claim set:

```json
{
  "1":    "XR",
  "6":    1792657800,
  "4":    1824193800,
  "-260": { "-6": { "...": "the payload above" } }
}
```
