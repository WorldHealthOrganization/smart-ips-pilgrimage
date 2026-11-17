---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s013-3-2-7-health-certificate-claim
section_title: "3.2.7 Health Certificate Claim"
file: "input/pagecontent/hcert_spec.md"
lines: 90-120
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
###### 3.2.7 Health Certificate Claim

The Health Certificate (`hcert`) claim is a JSON ([RFC 7159](https://tools.ietf.org/html/rfc7159)) object containing the health status information. The actual wire format of HCERT is content neutral. Several different types of health certificate MAY exist under the same claim, of which the European DCC is one.

Note here that the JSON is purely for schema purposes. The wire format is CBOR as defined in ([RFC 7049](https://tools.ietf.org/html/rfc7049)). Application developers may not actually ever decode or encode to and from the JSON format, but use the in-memory structure.

The Claim Key to be used to identify this claim is -260.

Strings in the JSON object SHOULD be NFC normalised according to the Unicode standard. Decoding applications SHOULD however be permissive and robust in these aspects, and acceptance of any reasonable type conversion is strongly encouraged. If non-normalised data is found during decoding, or in subsequent comparison functions, implementations SHOULD behave as if the input is normalised to NFC.

####### 3.2.7.1 Subclaims
- subclaims 0 and above are reserved by WHO to be assigned, a new sub claim can be requested for by requesting to create a new trust domain
- subclaims for negative integer values are for development purposes and are free to use
- While the [logical model](StructureDefinition-HCert.html) enlists assigned sub claims, the ones listed in this specification are considered authoritative

######## 3.2.7.1.1 EU Digital Covid Certificate (DCC)
[Data elements](http://smart.who.int/ddcc/StructureDefinition/HCertDCC) for the EU Digital COVID Certificate Core Data Set. Based on the official specification for COVID-19-related payloads https://health.ec.europa.eu/system/files/2021-06/covid-certificate_json_specification_en_0.pdf as of 2023-01-31, and Implementing Decision (EU) 2021/1073, Annex 1 https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32021D1073&from=EN#d1e34-35-1.

######## 3.2.7.1.3 Digital Documentation of Covid Certificate - Vaccination Status (DDCCVS)
The Digital Documentation of COVID-19 Certificates (DDCC) Trust Domain covers the utilization of COVID-19 Vaccine Certificates and Test Results. The Vaccination Status guidance is for the purposes of continuity of care and proof of vaccination. 
- [DDCC Vaccination Status (DDCC:VS)](https://www.who.int/publications/i/item/WHO-2019-nCoV-Digital_certificates-vaccination-2021.1) documents the use cases, data requirements, technical specifications and implementation guidance for vaccination certificates.
- [DDCC FHIR Implementation Guide](https://smart.who.int/ddcc/)

######## 3.2.7.1.4 Digital Documentation of Covid Certificate - Test Results (DDCCTR)
The Digital Documentation of COVID-19 Certificates (DDCC) Trust Domain covers the utilization of COVID-19 Vaccine Certificates and Test Results. The Test Results guidance is for test result certificates that attest to: (a) the fact that an individual has been tested for SARS-CoV-2, and (b) the result of that SARS-CoV-2 diagnostic test. 
- [DDCC Vaccination Status (DDCC:TR)](https://www.who.int/publications/i/item/WHO-2019-nCoV-Digital_certificates_diagnostic_test_results-2022.1) documents the use cases, data requirements, technical specifications and implementation guidance for vaccination certificates.
- [DDCC FHIR Implementation Guide](https://smart.who.int/ddcc/)

######## 3.2.7.1.5 Smart Health Link (SHL)
Smart Health Links covers the use cases of ability to share signed health data using links as digital connectors, using QR codes, facilitating tamper proof data exchange. Specification can be found [here](https://docs.smarthealthit.org/smart-health-links/spec)
