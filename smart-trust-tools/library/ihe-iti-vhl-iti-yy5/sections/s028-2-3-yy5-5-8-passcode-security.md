---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s028-2-3-yy5-5-8-passcode-security
section_title: "2:3.YY5.5.8 Passcode Security"
file: "input/pagecontent/ITI-YY5.md"
lines: 872-878
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.8 Passcode Security
When VHL is passcode-protected (P flag):
- Passcode SHALL be validated using constant-time comparison
- Failed passcode attempts SHOULD be rate limited
- Passcode SHOULD NOT be logged in audit trails
- Consider lockout after repeated failed attempts
