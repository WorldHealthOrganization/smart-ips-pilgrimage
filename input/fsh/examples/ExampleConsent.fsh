// Two pilgrimage consents of one fictional pilgrim (Martha, the subject of ExampleComposition).
// All organization names, identifiers and URLs are fictional examples: the origin
// country is Onesa (XXK) and the host is Taifafeki (XXR), the fictional countries
// shared with smart-trust-demo. Their consent codes CONSENT-XXK and CONSENT-XXR are
// fictional examples, modelled on the real CONSENT-MYS and CONSENT-KSA.
// The IPS.HAJJ.CONSENT code that says which consent this is goes in policyRule, with the
// CodeSystem version whose consent text the pilgrim was shown. There is no separate
// agreement: these two Consents are the policy.

Alias: $v3-ActReason = http://terminology.hl7.org/CodeSystem/v3-ActReason
Alias: $v3-ParticipationType = http://terminology.hl7.org/CodeSystem/v3-ParticipationType
Alias: $LOINC = http://loinc.org

Instance: ExampleOriginHIE
InstanceOf: HajjOrganization
Title: "Origin country HIE (example): VHL Sharer and Consent Registry custodian"
Description: "Fictional health information exchange of the pilgrim's origin country (the fictional Onesa in this example). It holds the pilgrim's consents and releases the IPS."
Usage: #example
* identifier.system = "urn:ietf:rfc:3986"
* identifier.value = "https://hie.xxk.example.org/"
* active = true
* type = $organization-type#govt "Government"
* name = "Ministry of Health Onesa Health Information Exchange (example)"

Instance: ExampleHostMoH
InstanceOf: HajjOrganization
Title: "Host country Ministry of Health (example): VHL Receiver"
Description: "Fictional host-country Ministry of Health (the fictional Taifafeki in this example), the recipient the pilgrim's consents name."
Usage: #example
* identifier.system = "urn:ietf:rfc:3986"
* identifier.value = "https://moh.xxr.example.org/"
* active = true
* type = $organization-type#govt "Government"
* name = "Ministry of Health Taifafeki (example)"

Instance: ExampleConsent
InstanceOf: HajjConsent
Title: "Pilgrimage consent: the origin country may release the IPS (CONSENT-XXK)"
Description: "The first of the pilgrim's two pilgrimage consents. The pilgrim lets the origin country HIE release the IPS to the host Ministry of Health, as information recipient, for treatment, during the pilgrimage period. The origin HIE enforces this consent from its own Consent Registry."
Usage: #example
* id = "c7781f44-6df8-4a8b-9e06-0b34263a47c6"
* status = #active
* scope = $consentscope#patient-privacy
* category[0] = $LOINC#59284-0 "Patient Consent"
* category[+] = http://terminology.hl7.org/CodeSystem/v3-ActCode#OPTIN "opt-in"
* patient = Reference(Martha)
* dateTime = "2025-04-01T09:00:00+08:00"
* performer = Reference(Martha)
* organization = Reference(ExampleOriginHIE)
* sourceAttachment.contentType = #text/plain
* sourceAttachment.url = "https://hie.xxk.example.org/consents/hajj-1446/consent-xxk.txt"
* sourceAttachment.title = "Consent text shown to the pilgrim: CONSENT-XXK (example)"
* policyRule = $IPSHajjConsent|2.1.0#CONSENT-XXK "Consent for Onesa (fictional example)"
* provision.type = #permit
* provision.period.start = "2025-05-01"
* provision.period.end = "2025-08-31"
* provision.actor.role = $v3-ParticipationType#IRCP "information recipient"
* provision.actor.reference.identifier.system = "urn:ietf:rfc:3986"
* provision.actor.reference.identifier.value = "https://moh.xxr.example.org/"
* provision.actor.reference.display = "Ministry of Health Taifafeki (example)"
* provision.purpose = $v3-ActReason#TREAT "treatment"

Instance: ExampleConsentXXR
InstanceOf: HajjConsent
Title: "Pilgrimage consent: the host Ministry of Health may use the IPS (CONSENT-XXR)"
Description: "The second of the pilgrim's two pilgrimage consents. The pilgrim lets the host Ministry of Health use the IPS, for treatment, during the pilgrimage period and any follow-up care. This consent governs the host's use of the IPS after it is received."
Usage: #example
* id = "6ba64cfe-b224-4d40-87bf-4d8122e65e62"
* status = #active
* scope = $consentscope#patient-privacy
* category[0] = $LOINC#59284-0 "Patient Consent"
* category[+] = http://terminology.hl7.org/CodeSystem/v3-ActCode#OPTIN "opt-in"
* patient = Reference(Martha)
* dateTime = "2025-04-01T09:05:00+08:00"
* performer = Reference(Martha)
* organization = Reference(ExampleOriginHIE)
* sourceAttachment.contentType = #text/plain
* sourceAttachment.url = "https://hie.xxk.example.org/consents/hajj-1446/consent-xxr.txt"
* sourceAttachment.title = "Consent text shown to the pilgrim: CONSENT-XXR (example)"
* policyRule = $IPSHajjConsent|2.1.0#CONSENT-XXR "Consent for Taifafeki (fictional example)"
* provision.type = #permit
* provision.period.start = "2025-05-01"
* provision.period.end = "2025-08-31"
* provision.actor.role = $v3-ParticipationType#IRCP "information recipient"
* provision.actor.reference.identifier.system = "urn:ietf:rfc:3986"
* provision.actor.reference.identifier.value = "https://moh.xxr.example.org/"
* provision.actor.reference.display = "Ministry of Health Taifafeki (example)"
* provision.purpose = $v3-ActReason#TREAT "treatment"

Instance: ex-documentreference1
InstanceOf: DocumentReference
Title: "DocumentReference Consent Paperwork example"
Description: """
DocumentReference example of the paperwork of the Consent
This is showing an example of a document that is purely text.
"""
Usage: #example
* meta.security = http://terminology.hl7.org/CodeSystem/v3-ActReason#HTEST
* status = #current
* type = http://loinc.org#64292-6 "Release of information consent"
* subject = Reference(Patient/ex-patient)
* author = Reference(Organization/ex-organization)
* description = "The captured signed document"
* content.attachment.title = "Hello World"
* content.attachment.contentType = #text/plain
* content.attachment.data = "TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQsIGNvbnNlY3RldHVyIGFkaXBpc2NpbmcgZWxpdCwgc2VkIGRvIGVpdXNtb2QgdGVtcG9yIGluY2lkaWR1bnQgdXQgbGFib3JlIGV0IGRvbG9yZSBtYWduYSBhbGlxdWEuIFV0IGVuaW0gYWQgbWluaW0gdmVuaWFtLCBxdWlzIG5vc3RydWQgZXhlcmNpdGF0aW9uIHVsbGFtY28gbGFib3JpcyBuaXNpIHV0IGFsaXF1aXAgZXggZWEgY29tbW9kbyBjb25zZXF1YXQuIER1aXMgYXV0ZSBpcnVyZSBkb2xvciBpbiByZXByZWhlbmRlcml0IGluIHZvbHVwdGF0ZSB2ZWxpdCBlc3NlIGNpbGx1bSBkb2xvcmUgZXUgZnVnaWF0IG51bGxhIHBhcmlhdHVyLiBFeGNlcHRldXIgc2ludCBvY2NhZWNhdCBjdXBpZGF0YXQgbm9uIHByb2lkZW50LCBzdW50IGluIGN1bHBhIHF1aSBvZmZpY2lhIGRlc2VydW50IG1vbGxpdCBhbmltIGlkIGVzdCBsYWJvcnVtLg=="