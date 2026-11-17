- The recipient OCHIE checks if the VHL request is valid and responds with the documentReference as a FHIR bundle Json.
- The recipient OCHIE acts as a VHL Document Responder and must conform with the capability statement for [VHL Document Responder](CapabilityStatement-VHLDocumentResponder.html)

##### Deciding the request: the pilgrim's consents are the policy
For the pilgrimage there is no separate data sharing agreement to look up. The pilgrim's two [HajjConsent](StructureDefinition-HajjConsent.html) resources are the policy, and each one binds the party it names:
- The **origin-release consent** (for example `CONSENT-MYS`, or the fictional `CONSENT-XXK` of this guide's examples) lets the Origin Country HIE release the IPS to the recipient named in `Consent.provision.actor` (role `IRCP`, information recipient), for the purpose in `Consent.provision.purpose` (`TREAT`), during `Consent.provision.period`. The Origin Country HIE enforces this consent from **its own Consent Registry** (as recorded by the Record Consent transaction, [ITI-108]), not from the copy carried inside the IPS. The IPS copy is signed when the IPS is issued, so it cannot show a later withdrawal.
- The **host-use consent** (`CONSENT-KSA`, or the fictional `CONSENT-XXR` of this guide's examples) governs the Host Country Ministry of Health's use of the IPS **after it is received**: for treatment during the pilgrimage and any follow-up care, as its consent text states.

Which consent a `Consent` is, and the consent text the pilgrim was shown, are carried in `Consent.policyRule`: a code from the [IPS.HAJJ.CONSENT](CodeSystem-IPS.HAJJ.CONSENT.html) CodeSystem, with `coding.version` set to the CodeSystem version.

The Host Country EMR is identified by trust in the `ips-pilgrimage` trust domain (see the authentication note in the message semantics). The Origin Country HIE releases the documents only when the passcode is valid, the VHL has not expired, the origin-release consent is active in its registry, the verified receiver matches `Consent.provision.actor`, the purpose is treatment, and the request falls within `Consent.provision.period`. If any of these cannot be established, the request is not permitted.

##### Audit event
The Origin Country HIE records an audit event with Record Audit Event [ITI-20] for each request, whether documents are released or refused. VHL Volume 1 §1:XX.3 requires the VHL Sharer and the VHL Receiver to be grouped with an ATNA Secure Node or Secure Application, and ITI-YY5 §2:3.YY5.5.6 says both SHOULD log document access requests, the authentication method used, the receiver identity, the VHL folder ID and the authorization decision. In this guide the audit event recorded by the Origin Country HIE shall also cite:
- the governing policy: the pilgrim's consents, each by its `Consent.policyRule` code and CodeSystem version (for example `CONSENT-XXK` and `CONSENT-XXR` in this guide's examples, version 2.1.0);
- the `id` and `meta.versionId` of each Consent read from the Consent Registry for the decision;
- the receiver, as identified by the VHL authentication option used;
- the purpose of use (`TREAT`);
- the documents released (the DocumentReferences returned), or the refusal.

This guide uses no separate data sharing agreement for the pilgrimage, so the consents themselves are the policy the audit event cites. The Host Country EMR, as an ATNA Secure Node or Secure Application, should also audit what it receives.
