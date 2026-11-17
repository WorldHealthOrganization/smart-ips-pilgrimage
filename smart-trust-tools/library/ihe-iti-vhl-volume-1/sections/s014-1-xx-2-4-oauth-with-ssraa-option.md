---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s014-1-xx-2-4-oauth-with-ssraa-option
section_title: "1:XX.2.4 OAuth with SSRAA Option"
file: "input/pagecontent/volume-1.md"
lines: 291-299
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.2.4 OAuth with SSRAA Option

The OAuth with SSRAA Option enables the {{ linkvhlr }} and {{ linkvhls }} to use OAuth 2.0 access tokens for authentication during the ITI-YY5 Retrieve Manifest transaction, as an alternative to HTTP Message Signatures. This option provides interoperability with systems implementing the [HL7 Security for Scalable Registration, Authentication, and Authorization IG](http://hl7.org/fhir/us/udap-security/) (SSRAA).


**Complementary Option:** Both the {{ linkvhlr }} and {{ linkvhls }} SHALL support this option for OAuth-based authentication to be used. If only one actor supports this option, HTTP Message Signatures or other authentication mechanisms defined in ITI-YY5 SHALL be used instead.

See ITI-YY5 Section 2:3.YY5.4.1.4 for detailed OAuth flow and examples.
