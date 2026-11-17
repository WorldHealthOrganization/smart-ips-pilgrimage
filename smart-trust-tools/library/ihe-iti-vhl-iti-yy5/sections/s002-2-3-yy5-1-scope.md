---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s002-2-3-yy5-1-scope
section_title: "2:3.YY5.1 Scope"
file: "input/pagecontent/ITI-YY5.md"
lines: 10-34
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
### 2:3.YY5.1 Scope

The Retrieve Manifest transaction enables a {{ linkvhlr }} to retrieve a manifest (searchset Bundle) of available health documents from a {{ linkvhls }} using a previously obtained and validated Verified Health Link (VHL). 

This transaction occurs after the {{ linkvhlr }} has received a VHL from a VHL Holder (via ITI-YY4 Provide VHL) and validated the VHL signature.

**FHIR Search Transaction:** This transaction uses a standard FHIR search on the List resource, following the same pattern as MHD ITI-66 Find Document Lists. The manifest URL from the VHL payload contains all necessary FHIR search parameters. No custom operation is required.

**Authentication:** Implementations SHALL support at least one of the following three authentication mechanisms. Participants MAY use **HTTP Message Signatures (RFC 9421)**, **OAuth with SSRAA**, or the **Verifiable Credential Option** depending on their deployment context. The VHL Sharer authenticates the requesting VHL Receiver before processing the request.

  1. **HTTP Message Signatures Option:** Implementations MAY support authentication via **HTTP Message Signatures (RFC 9421)**, in which the {{ linkvhlr }} signs selected components of the outgoing HTTP manifest request (e.g., `@method`, `@target-uri`, `content-digest`, `date`) using its trust-network key. The {{ linkvhls }} verifies the signature against the {{ linkvhlr }}'s public key from the trust network before processing the request. This option requires no additional token endpoint or credential exchange — authentication is carried entirely within the HTTP request itself.

  2. **OAuth with SSRAA Option:** Implementations MAY support the **OAuth with SSRAA Option**, which uses OAuth 2.0 tokens for authentication as defined in the [HL7 Security for Scalable Registration, Authentication, and Authorization IG](http://hl7.org/fhir/us/udap-security/) (SSRAA). When this option is supported, implementations use OAuth Backend Services with JWT client assertions for system-to-system authentication.

  3. **Verifiable Credential Option:** Implementations MAY support the **Verifiable Credential Option**, in which the {{ linkvhlr }} self-issues a JSON-LD Verifiable Credential (LDP-VC) whose subject is the manifest decoded from the VHL (received as a QR code or as a Verifiable Credential per [ITI-YY4](ITI-YY4.html)). The VC contains an embedded **DataIntegrityProof** signed with the {{ linkvhlr }}'s key from the trust network, and is sent directly as the HTTP POST body (`Content-Type: application/vc+ld+json`). No additional HTTP-level signing is needed; the embedded proof is sufficient.


**Include DocumentReference Option:** A {{ linkvhls }} that supports the **Include DocumentReference Option** SHALL process the `_include=List:item` parameter to retrieve both the List and the referenced DocumentReference resources in a single response. This optimization reduces the number of round trips required by the {{ linkvhlr }}. If a {{ linkvhls }} does not support this option, it SHALL ignore the `_include` parameter, and the {{ linkvhlr }} SHALL retrieve each DocumentReference individually using separate read requests.

Both the {{ linkvhlr }} and {{ linkvhls }} SHALL authenticate each other's participation in the trust network. The {{ linkvhls }} validates that the requesting {{ linkvhlr }} is authorized to access the documents before responding.

**Capability Statements:** 
- {{ linkvhlr }} capabilities are defined in [VHL Receiver Client Capability Statement](CapabilityStatement-VHLReceiverCapabilityStatement.html)
- {{ linkvhls }} capabilities are defined in [VHL Sharer Server Capability Statement](CapabilityStatement-VHLSharerCapabilityStatement.html)
