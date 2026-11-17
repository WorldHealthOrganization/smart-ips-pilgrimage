---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s001-input-pagecontent-volume-1-md
section_title: "input/pagecontent/volume-1.md"
file: "input/pagecontent/volume-1.md"
lines: 1-39
source_sha256: 1227bd54486fad1f
granularity: heading
---
{% assign linkta = '<a href="ActorDefinition-TrustAnchor.html">Trust Anchor</a>' %}
{% assign linkvhlh = '<a href="ActorDefinition-VHLHolder.html">VHL Holder</a>' %}
{% assign linkvhls = '<a href="ActorDefinition-VHLSharer.html">VHL Sharer</a>' %}
{% assign linkvhlr = '<a href="ActorDefinition-VHLReceiver.html">VHL Receiver</a>' %}
{% assign linksubmitpki = '<a href="ITI-YY1.html">Submit PKI Material with DID</a>' %}
{% assign linkretrievepki = '<a href="ITI-YY2.html">Retrieve Trust List with DID</a>' %}
{% assign linkgeneratevhl = '<a href="ITI-YY3.html">Generate VHL</a>' %}
{% assign linkprovidevhl = '<a href="ITI-YY4.html">Provide VHL</a>' %}
{% assign linkretrievemanifest = '<a href="ITI-YY5.html">Retrieve Manifest</a>' %}

As individuals move within or across jurisdictional boundaries, they may wish to provide access to clinical or other health-related documents to a defined set of trusted parties who are authorized to access their records. This access may be granted for a single document or for a set of related documents.

The **Verifiable Health Links (VHL)** profile defines a set of protocols and patterns that enable health documents to be shared in a verifiable and auditable manner—both within and across jurisdictions. Central to this profile is the concept of the **VHL**, a signed artifact that an individual (the **VHL Holder**) can use to authorize access to their health records from an issuer (the {{ linkvhls }}) to a third party (the {{ linkvhlr }}). The mechanisms by which the VHL is held by the Holder or transmitted to the {{ linkvhlr }} are out of scope for this profile.

VHL leverages **Public Key Infrastructure (PKI)** to establish trust among actors and to verify the authenticity and integrity of exchanged artifacts.

Within the VHL trust model, both the {{ linkvhlr }} and the {{ linkvhls }} are participants in a shared **[trust network](other.html#ihe-technical-frameworks-general-introduction-appendix-d-glossary)**. This network enables:
- Verification of the origin of a health document,
- Validation of any access mechanism (i.e., the VHL itself),
- Authentication of requests that seek to utilize these mechanisms.
    
The authority to participate in the trust network is governed by each actor's **jurisdiction**, which determines eligibility and onboarding criteria. Verification of this authorization is achieved through PKI, specifically through the validation of credentials issued or endorsed by a **Trust Anchor** ({{ linkta }}).

Jurisdictions may also impose specific regulatory requirements on the privacy and security of health data exchange. These may include mandatory **consent verification**, **audit logging**, or other compliance controls that impact how VHL-based exchanges are implemented.

As members of a trust network, both the {{ linkvhlr }} and the {{ linkvhls }} are expected to submit and retrieve PKI material—typically as signed **Trust Lists**—from the {{ linkta }}. The precise onboarding and credential issuance processes used to establish trust with the {{ linkta }} are implementation-specific and beyond the scope of this profile.

> **Relationship to SMART® Health Links (SHL):**
>
> A VHL **adopts the SMART Health Links payload format** — the `url`, `key`, `flag`, `label`, `exp`, `v`, and `extension` fields defined in the [SMART Health Links specification](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html) — and reuses the SHL-defined manifest-request parameters (`recipient`, `passcode`, `embeddedLengthMax`). The **fundamental difference is the trust model**: VHL assumes a **pre-established trust relationship** between the {{ linkvhls }} and the {{ linkvhlr }}, verified via PKI material exchanged through Trust Lists, whereas SHL assumes **no prior trust** and conveys trust at presentation time via keys controlled by the SHL Sharer. See [Appendix A](vhl_vs_shl.html) for a side-by-side comparison.
>
> **Terminology used in this IG:**
> - **VHL payload** — a concrete instance populated by the {{ linkvhls }} and carried by a VHL (inside an HCERT/CWT QR code, or inside a signed Verifiable Credential under the VC Enveloped VHL Option). Instance-level references in this IG say "VHL payload".
> - **SHL payload format** / **SHL payload structure** — the schema (field names and shapes) that the VHL payload conforms to. Where this IG refers to the inherited schema itself, it uses "SHL payload format".
> - **SHL-defined manifest parameters** — `recipient`, `passcode`, `embeddedLengthMax`, etc., as defined by the SHL specification and reused here.
> - Actors in this IG are always the {{ linkvhlh }}, {{ linkvhls }}, and {{ linkvhlr }} — never "SHL Receiver" or "SHL Sharer" (those terms only appear in the comparison at Appendix A).

<a name="actors-and-transactions"> </a>
