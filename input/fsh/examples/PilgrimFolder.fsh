Instance:   PilgrimFolder
InstanceOf: IHE.MHD.Minimal.Folder
Title: "My Hajj Pilgrimage Minimal Folder"
Description:      "Folder for Pilgrim"
Usage: #example
* meta.security = http://terminology.hl7.org/CodeSystem/v3-ActReason#HTEST
* identifier[entryUUID].system = "urn:ietf:rfc:3986"
* identifier[entryUUID].value = "urn:uuid:5e2d58a3-2286-4a0e-8637-86f51be2d184"
* identifier[entryUUID].use = #official
* identifier[uniqueId].system = "urn:ietf:rfc:3986"
* identifier[uniqueId].value = "urn:oid:1.2.840.113556.1.8000.2554.58783.21864.3474.19410.44358.58254.41281.46391"
* identifier[uniqueId].use = #usual
* status = #current
* mode = #working
* code = MHDlistTypes#folder
* entry[0].item = Reference(DocumentReference/FHIRIPSDocumentReference)
* entry[1].item = Reference(DocumentReference/IPSPDFDocumentReference)
* entry[2].item = Reference(DocumentReference/FHIRIPSSignedDocumentReference)
* entry[3].item = Reference(DocumentReference/IPSSignedPDFDocumentReference)


Instance:   FHIRIPSDocumentReference
InstanceOf: IHE.MHD.Minimal.DocumentReference
Title:      "FHIR IPS json reference"
Description: "Example of FHIR IPS JSON for pilgrimage, as a document reference."
Usage: #example
* meta.security = http://terminology.hl7.org/CodeSystem/v3-ActReason#HTEST
* masterIdentifier.system = "urn:ietf:rfc:3986"
* masterIdentifier.value = "urn:oid:1.2.840.113556.1.8000.2554.53432.348.12973.17740.34205.4355.50220.62002"
* identifier[entryUUID].system = "urn:ietf:rfc:3986"
* identifier[entryUUID].value = "urn:uuid:7d5bb8ac-68ee-4926-85e7-b8aac8e1f10e"
* identifier[entryUUID].use = #official
* status = #current
* type.coding.code = #60591-5
* type.coding.system = "http://loinc.org"
* type.coding.display = "Patient Summary Document"
* content.format.code = #http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips
* content.format.system = "urn:ietf:rfc:3986"
* content.attachment.contentType = #application/fhir+json
* content.attachment.url = "https://worldhealthorganization.github.io/smart-ips-pilgrimage/branches/2.0.0/Bundle-MyIPS.json"

Instance:   IPSPDFDocumentReference
InstanceOf: IHE.MHD.Minimal.DocumentReference
Title:      "IPS PDF reference"
Description: "Example of FHIR IPS PDF for pilgrimage, as a document reference."
Usage: #example
* meta.security = http://terminology.hl7.org/CodeSystem/v3-ActReason#HTEST
* masterIdentifier.system = "urn:ietf:rfc:3986"
* masterIdentifier.value = "urn:oid:1.2.840.113556.1.8000.2554.53432.348.12973.17740.34205.4355.50220.62003"
* identifier[entryUUID].system = "urn:ietf:rfc:3986"
* identifier[entryUUID].value = "urn:uuid:7d5bb8ac-68ee-4926-85e7-b8aac8e1f11e"
* identifier[entryUUID].use = #official
* status = #current
* type.coding.code = #60591-5
* type.coding.system = "http://loinc.org"
* type.coding.display = "Patient Summary Document"
* content.format.code = #urn:ihe:iti:xds:2017:mimeTypeSufficient
* content.format.system = "http://ihe.net/fhir/ihe.formatcode.fhir/CodeSystem/formatcode"
* content.attachment.contentType = #application/pdf
* content.attachment.url = "https://worldhealthorganization.github.io/smart-ips-pilgrimage/branches/2.0.0/MyIPS.pdf"


Instance:   FHIRIPSSignedDocumentReference
InstanceOf: IHE.MHD.Minimal.DocumentReference
Title:      "FHIR IPS JSON Signed"
Description: "Example of FHIR IPS Signed using DSGj for pilgrimage, as a document reference."
Usage: #example
* meta.security = http://terminology.hl7.org/CodeSystem/v3-ActReason#HTEST
* masterIdentifier.system = "urn:ietf:rfc:3986"
* masterIdentifier.value = "urn:oid:1.2.840.113556.1.8000.2554.53432.348.12973.17740.34205.4355.50220.62004"
* identifier[entryUUID].system = "urn:ietf:rfc:3986"
* identifier[entryUUID].value = "urn:uuid:7d5bb8ac-68ee-4926-85e7-b8aac8e1f12e"
* identifier[entryUUID].use = #official
* status = #current
* relatesTo[+].code = $DocRelationshipType#signs
* relatesTo[=].target = Reference(FHIRIPSDocumentReference)
* content.format.code = #urn:ihe:iti:dsg:detached:2014
* content.format.system = "http://ihe.net/fhir/ihe.formatcode.fhir/CodeSystem/formatcode"
* content.attachment.contentType = #application/json
* content.attachment.url = "https://worldhealthorganization.github.io/smart-ips-pilgrimage/branches/2.0.0/MySignedIPS.json"


Instance:   IPSSignedPDFDocumentReference
InstanceOf: IHE.MHD.Minimal.DocumentReference
Title:      "IPS PDF Signed"
Description: "Example of FHIR IPS Signed PDF JSON using DSGj for pilgrimage, as a document reference."
Usage: #example
* meta.security = http://terminology.hl7.org/CodeSystem/v3-ActReason#HTEST
* masterIdentifier.system = "urn:ietf:rfc:3986"
* masterIdentifier.value = "urn:oid:1.2.840.113556.1.8000.2554.53432.348.12973.17740.34205.4355.50220.62005"
* identifier[entryUUID].system = "urn:ietf:rfc:3986"
* identifier[entryUUID].value = "urn:uuid:7d5bb8ac-68ee-4926-85e7-b8aac8e1f13e"
* identifier[entryUUID].use = #official
* status = #current
* relatesTo[+].code = $DocRelationshipType#signs
* relatesTo[=].target = Reference(IPSPDFDocumentReference)
* content.format.code = #urn:ihe:iti:dsg:detached:2014
* content.format.system = "http://ihe.net/fhir/ihe.formatcode.fhir/CodeSystem/formatcode"
* content.attachment.contentType = #application/json
* content.attachment.url = "https://worldhealthorganization.github.io/smart-ips-pilgrimage/branches/2.0.0/MySignedIPSPDF.json"