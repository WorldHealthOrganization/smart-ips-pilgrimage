Profile: HajjIPS
Parent: BundleUvIps
Title: "Bundle - IPS for Hajj"
Description: "This profile represents the constraints applied to the Bundle resource by the International Patient Summary (IPS) FHIR Implementation Guide for the Hajj Pilgrimage."
* entry MS
* entry ^slicing.discriminator[0].type = #type
* entry ^slicing.discriminator[=].path = "resource"
* entry ^slicing.discriminator[+].type = #profile
* entry ^slicing.discriminator[=].path = "resource"
* entry ^slicing.rules = #open
* entry ^short = "Entry resource in the patient summary bundle"
* entry ^definition = "An entry resource included in the patient summary document bundle resource."
* entry ^comment = "Must contain the IPS Composition as the first entry (only a single Composition resource instance may be included) and a Patient resource.  Additional constraints are specified in the IPS Composition profile."
* entry.fullUrl 1.. MS
* entry.search ..0
* entry.request ..0
* entry.response ..0
* entry contains
    consent 1..*

* entry[consent].resource only HajjConsent


Profile: HajjIPSComposition
Parent: CompositionUvIps
Title: "Composition (IPS) for Hajj"
Description: "Clinical document used to represent the International Patient Summary (IPS) data set for Hajj Pilgrimage" 

* section[sectionAdvanceDirectives] 1..1
* section[sectionAdvanceDirectives].entry only Reference(HajjConsent)

