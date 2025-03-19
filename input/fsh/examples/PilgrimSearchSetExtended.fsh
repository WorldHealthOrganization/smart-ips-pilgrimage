Instance: PilgrimFolderSearchSetExtended
InstanceOf: Bundle
Title: "Example Folder for Pilgrim (Extended)"
Description: "Example Hajj Pilgrimage Minimal Folder Search Set"     
Usage: #example
* type = #searchset
* link.relation = "self"
* link.url = "http://example.org/fhir/List?_id=PilgrimFolder&_include=List:item"
* entry[0].fullUrl = Canonical(IPSPDFDocumentReference)
* entry[=].resource = IPSPDFDocumentReference
* entry[+].fullUrl = Canonical(FHIRIPSDocumentReference)
* entry[=].resource = FHIRIPSDocumentReference
* entry[+].fullUrl = Canonical(IPSSignedPDFDocumentReference)
* entry[=].resource = IPSSignedPDFDocumentReference
* entry[+].fullUrl = Canonical(FHIRIPSSignedDocumentReference)
* entry[=].resource = FHIRIPSSignedDocumentReference




