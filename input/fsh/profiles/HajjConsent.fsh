Profile: HajjConsent
Parent: IntermediateConsent
Description: "A profile of the consent resource to track consent of a pilgrim to participate

FHIR R5 upgrade notes (need this implemented as a structure map):
 * make cardinality of decision 1.. and should stop using it in lieu of verification.verified
 * use verification.verifiedBy instead of Consent.organization
 * the period extenion should be replaced by Consent.period
 * the Consent.patient should be replaced by Consent.subject
 * Consent.verification.verifiedBy should be used instead of Consent.organization
"

// The pilgrim's consents are the policy: there is no separate agreement to look up.
// Which pilgrimage consent this is (CONSENT-KSA, CONSENT-MYS, ...) is carried in policyRule,
// with the version of the IPS.HAJJ.CONSENT CodeSystem whose text the pilgrim was shown.
// policyRule also satisfies R4 invariant ppc-1 (policy or policyRule), so no policy.uri is needed.
* policyRule 1..1 MS
* policyRule from IPS.HAJJ.CONSENT (required)
* policyRule ^short = "Which pilgrimage consent this is (IPS.HAJJ.CONSENT code, with the CodeSystem version)"
* policyRule.coding 1..1 MS
* policyRule.coding.system 1..1 MS
* policyRule.coding.version 1..1 MS
* policyRule.coding.version ^short = "Version of the IPS.HAJJ.CONSENT CodeSystem whose consent text the pilgrim was shown"
* policyRule.coding.code 1..1 MS

// An explicit consent (GDHCN Trust Network: Personal Health Wallet, PHWExplicitConsent):
// the evidence is the consent text the pilgrim was shown and their recorded act.
* source[x] MS
// The kind of consent: an HL7 v3 ActConsentDirective code in category (a pilgrimage consent is OPTIN).
* category MS
* category ^short = "Includes the kind of consent: HL7 v3 ActConsentDirective OPTIN for a pilgrimage consent"
* source[x] ^short = "Evidence of the pilgrim's explicit consent: the consent text shown, with their recorded act"

* organization only Reference(HajjOrganization)

* provision 1..1
// Who may receive the IPS: an Organization, identified by its business identifier.
// IHE PCF IntermediateConsent already fixes provision.actor.role to v3 ParticipationType IRCP (information recipient).
* provision.actor 1..* MS
* provision.actor.role MS
* provision.actor.reference only Reference(HajjOrganization)
* provision.actor.reference MS
* provision.actor.reference.identifier 1..1 MS
// For what: a purpose of use from HL7 v3 PurposeOfUse; the pilgrimage consents are for treatment (TREAT).
* provision.purpose 1..* MS
* provision.purpose from http://terminology.hl7.org/ValueSet/v3-PurposeOfUse (required)
* provision.purpose ^short = "Purpose of use (HL7 v3 PurposeOfUse); TREAT for the pilgrimage consents"
// When: the Hajj period, with any follow-up the consent text allows.
* provision.period 1..1 MS


// NOTE:
// in FHIR R5 should  make cardinality of decision 1..
// * decision 1..

// NOTE:
// in FHIR R5 should use verification.verifiedBy instead of Consent.organization

// NOTE:
// in FHIR R5 the period extenion should be replaced by Consent.period
// * period 1..
//* extension contains ConsentPeriod named period 1..* MS

// NOTE:
// in FHIR R5 the Consent.patient should be replaced by Consent.subject
// * subject 1..


//* verification 1..


// NOTE:
// in FHIR R5 Consent.verification.verifiedBy should be used instead of Consent.organization
// * verification.verifiedBy only Reference(HajjOrganization)
// * verification.verifiedBy 1..
/*
* verification.extension contains ConsentVerifiedBy named verifiedBy 1..* MS
* verification.verifiedWith 1..
* verification.verificationDate 1.. */
