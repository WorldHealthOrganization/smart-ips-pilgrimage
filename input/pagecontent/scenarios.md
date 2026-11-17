**The scenarios below, told as one pilgrim's story:** [the home page](index.html) follows a fictional Onesan pilgrim through every step of the key process flows, with the question each step raises.
{:.stu-note}

The user scenarios are only illustrative and are intended to give an idea of a typical workflow.

**How to interpret user scenarios**

User scenarios can be helpful tools not only to better understand the context in which a digital tool would operate, but also for some insights into what key data elements would need to be recorded and accounted for in the database. Additionally, the context in which the tool would operate, illuminated by the user scenarios, provides insight into some functional and non-functional requirements that the system would also need.

As examples, the scenarios identify: key data elements that need to be recorded and/or calculated; decision-support logic that can be automated in the system; key functional and non-functional requirements that should be included in the system, and adolescent-specific considerations that should be accounted for.

### Publication of National Public Keys for Verification
**Services**
- National HIE
- WHO GDHCN

Described in the [SMART Trust](https://smart.who.int/smart-trust) framework of the GDHCN where by a GDHCN Participant provides public keys to the WHO GDHCN Trust Network Gateway that can be used for signing health documents, in particular the [International Patient Summary (IPS)](https://build.fhir.org/ig/HL7/fhir-ips/).  The Trust Domain that will be used for this set of scenarios is <b>ips-pilgrimage</b>

This process is a both a pre-condition for the user scenario 3.0, 4.0, and 5.0 as well as a routine process at any point relevant encryption key material is updated.

### Publication of National Terminologies
This process for sharing National Code Systems and Value Sets that are utilized in a National HIE's profile of the IPS.  Standardized code systems should be utilized wherever possible but this recognizes that National Code Systems may be necessary, particularly for coding of medication terminologies.  The primary goal, at least in the first phases of sharing the terminologies is not semantic interoperability between a National HIE and Host Country EMR, rather it is  to support the Host Country Health Worker to review the IPS.


These terminologies should be shared from the National HIE to the WHO Terminology Service.
 * IHE profile [Sharing Value Sets and Concept Maps (SVCM)](https://profiles.ihe.net/ITI/SVCM/) (Recommended)
 * Sharing of tabular data  

Once shared to the WHO Terminology Service, these terminologies should be retrievable from the Host Country EMR via the IHE SCVM profile.

This process is a both a pre-condition for the user scenario 3.0, 4.0 and 5.0 as well as a routine process at any point relevant terminologies are updated.

### Issuance of Health Document at Origin Country
This is a "Phase 1" scenario in which the Origin Country conducts a health assessment for the Pilgrim, obtains consent for eligible pilgrims and issues QR Codes (Smart Health Link) that embeds their patient summary as a IPS. The QR code might be issues on a national health wallet or printed QR code.


### Clinical Encounter for Unplanned Care

This is a "Phase 1" scenario in which a Pilgrim in a Host Country has need to seek care from a Host Country Health Worker. 
The pilgrim mediates exchange by showing the QR code issued by their Origin Country.  The Host Country EMR uses the QR code to access the National IHE to retrieve the patient summary (IPS).

### Break The Glass Clinical Encounter

This is a "Phase 2" scenario in which a Pilgrim in a Host Country is not conscious and must receive emergency care.  The Host Country Health Worker accesses the patient summary via the Pilgrimage Registration Number.   Prior to this emergency care encounter, the Pilgrim would have registered their consent to provide access to their record either through the National Health Wallet App or through the National Pilgrimage Authority.