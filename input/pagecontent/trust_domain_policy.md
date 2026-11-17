This Trust Domain enables data exchange mediated by the pilgrim, on the basis of the pilgrim's consent. The consents are recorded in the [IPS.HAJJ.CONSENT CodeSystem](CodeSystem-IPS.HAJJ.CONSENT.html), and each [pilgrimage consent](StructureDefinition-HajjConsent.html) in a pilgrim's IPS names one of them in `Consent.policyRule`.

#### Terms of use

The [IPS.HAJJ.CONSENT ValueSet](ValueSet-IPS.HAJJ.CONSENT.html) is this Trust Domain's terms of use: the policies a participant may say it acts under. It is recorded on the [IPS-PILGRIMAGE Trust Domain](http://smart.who.int/trust/Binary-TrustDomain-IPS-PILGRIMAGE.html) in the GDHCN Trust IG. The GDHCN Administrative and Operational Framework 1.2 has no annex for this Trust Domain yet, so that record is drafted from this IG.

#### Explicit and implied consent

This guide follows the consent model of the [GDHCN Trust Network: Personal Health Wallet](http://smart.who.int/trust-phw/consent.html) guide, which is built on IHE Privacy Consent on FHIR (PCF) 1.1.0:

* **Explicit consent.** The pilgrim agrees by their own act: on their wallet, or to the counsellor, who records it. Each [pilgrimage consent](StructureDefinition-HajjConsent.html) is an explicit consent, an opt-in: its `Consent.category` includes the HL7 v3 ActConsentDirective code `OPTIN`. It names its `IPS.HAJJ.CONSENT` code and the code system version in `Consent.policyRule`, and its `source[x]` is the evidence: the consent text the pilgrim was shown, with their recorded act. The Personal Health Wallet guide's process L ("Record Explicit Consent") describes the steps. Both the verbal consent and the consent on the wallet in this guide's business processes are explicit consents.
* **Implied consent.** The pilgrim does nothing, and the Trust Domain's default policy applies (HL7 ActConsentDirective `IMPLIED`). This Trust Domain is opt-in: its default is the IHE PCF implicit policy `Policy-deny`. With no pilgrimage consent, the IPS is not shared.

**Consent directives travel with the document.** The pilgrim's IPS ([HajjIPS](StructureDefinition-HajjIPS.html)) carries the pilgrimage consents it is shared under, as consent entries, and lists them in its Advance Directives section. The Personal Health Wallet guide's process M ("Add Consent Directives to a Shared or Issued Document") describes the steps. The copy in the IPS is evidence for the receiver. The origin HIE enforces the copy in its own Consent Registry, because a signed IPS cannot show a later withdrawal.

#### Naming the consent a VHL Receiver acts under

Under the Verifiable Credential Option of IHE ITI VHL (ITI-YY5), a VHL Receiver retrieves the manifest with a credential it issues itself. It can name the consent policy it acts under in that credential's W3C VC 2.0 `termsOfUse`, with one [Trust Domain policy](http://smart.who.int/trust/StructureDefinition-TrustDomainPolicy.html) entry per policy:

```json
{
  "@context": ["https://www.w3.org/ns/credentials/v2"],
  "type": ["VerifiableCredential", "VHLManifestCredential"],
  "issuer": "did:web:vhl-receiver.example.org",
  "validFrom": "2026-06-01T10:00:00Z",
  "validUntil": "2026-06-01T10:05:00Z",
  "credentialSubject": {
    "id": "https://vhl-sharer.example.org/List?_id=abc123def456",
    "manifest": { "url": "https://vhl-sharer.example.org/List?_id=abc123def456", "flag": "LP" },
    "recipient": "Ministry of Health, Taifafeki (fictional): pilgrimage facility"
  },
  "termsOfUse": [{
    "type": "http://smart.who.int/trust/StructureDefinition/TrustDomainPolicy",
    "id": "http://smart.who.int/ips-pilgrimage/CodeSystem/IPS.HAJJ.CONSENT#CONSENT-XXR"
  }],
  "proof": { "type": "DataIntegrityProof", "cryptosuite": "ecdsa-rdfc-2019", "proofPurpose": "assertionMethod", "verificationMethod": "did:web:vhl-receiver.example.org#key-1", "proofValue": "z…" }
}
```

The VHL Sharer then:

1. checks that each named policy is in this ValueSet;
2. matches it against the `Consent.policyRule` of the pilgrim's pilgrimage consents (system and code);
3. decides as the [GDHCN Trust Network: Personal Health Wallet](http://smart.who.int/trust-phw/business-processes.html) process I describes.

Naming a policy only narrows the consents that apply, and it never overrides a prohibition. A credential with no `termsOfUse` is decided on all the pilgrim's applicable consents.
