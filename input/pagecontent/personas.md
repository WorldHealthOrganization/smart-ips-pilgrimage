This page lists and describes the human users and digital services that interact with the system, derived from the business requirements defined at the operational level (L2). 

Integrating the Healthcare Enterprise (IHE) maintains a [repository with common actors](https://profiles.ihe.net/GeneralIntro/ch-A.html) used in IHE profiles.

### Key generic personas interacting with the system  
In the clinical flows, generic personas are represented using profiles of the various entity resources in HL7 FHIR, such as [Patient](http://hl7.org/fhir/patient), [Practitioner](http://hl7.org/fhir/practitioner), [PractitionerRole](http://hl7.org/fhir/practitionerrole), and [RelatedPerson](http://hl7.org/fhir/relatedperson).


<table class="list">
  <thead>
    <tr>
      <th>Role</th>
      <th>Description</th>
      <th>Different Names</th>
      <th>ISCO Code (if applicable)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Pilgrim</td>
      <td>Person undergoing a pilgrimage to a pilgrimage host country. During an unplanned care encounter they would provide explicit consent to access a patient summary information to a Host Country Health Worker. In case of emergency, they may have provided consent during a "break the glass" scenario.</td>
      <td>Patient, client, health system user</td>
      <td></td>
    </tr>
    <tr>
      <td>Counsellor</td>
      <td>Health worker or practitioner empanelled by the origin country National Pilgrimage Authority to conduct health assessments for pilgrims planning to go to a pilgrimage.</td>
      <td>Health worker, Practitioner, Nurse</td>
      <td></td>
    </tr>
    <tr>
      <td>Accompanying Clinician from Origin Country</td>
      <td>Clinician from Origin Country accompanying pilgrims to a pilgrimage host country.  During an unplanned care encounter they would provide explicit consent to access a patient summary information to a Host Country Health Worker, only if the pilgrim themselves is unable to do so.</td>
      <td>Clinician, Doctor</td>
      <td></td>
    </tr>
    <tr>
      <td>Host Country Health Worker</td>
      <td>Health worker in the Host Country of a pilgrimage event that is providing care to and/or performing registration and intake of a Pilgrim during a clinical encounter.</td>
      <td>Clinician, Provider, Doctor, Nurse, Receptionist</td>
      <td></td>
    </tr>
    <tr>
      <td>National Pilgrimage Authority</td>
      <td>Organization that manages the application of a Pilgrim as they apply to make pilgrim to a pilgrimage host country. Responsible for providing a Pilgrim with a Pilgrimage Registration Number and assessing health status of Pilgrim before approval is granted by the Pilgrimage Host Country. Optionally responsible for ensuring consent in case of "break the glass" scenario when a Pilgrim is not able to provide explicit consent in an emergency care setting due to, for example, unconsciousness. In this case, the National Pilgrimage Authority should collect consent from the Pilgrim for potential future "break the glass scenario", associate a Pilgrimage Registration Number to a patient summary document, and provide access means to the Host Country HIE to the patient summary document by association to the Pilgrimage Registration Number</td> 
      <td>Pilgrimage Authority</td>
      <td></td>
    </tr>
  </tbody>
</table>



### Digital Services  
  
  

<table class="list">
  <thead>
    <tr>
      <th>Service</th>
      <th>Description</th>
      <th>Different Names</th>
      <th>Service Code (if applicable)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>National Health Information Exchange</td>
      <td>Health information exchange of origin country of a Pilgrim. Responsible for providing standardized patient summary information for a Pilgrim and making that accessible to the Pilgrim as part of a patient-mediated exchange data exchange and consent approach.</td>
      <td>HIE</td>
      <td></td>
    </tr>
    <tr>
      <td>National Health Wallet App</td>
      <td>Health Wallet App linked to the National HIE that manages access to patient summary information of a Pilgrim, particularly the IPS. The wallet app should manage consent profiles including time-bound access to an IPS, selective disclosure of content that is shared within the patient summary, and opt-out/opt-in on usage of the patient summary in a "break the glass" scenario.</td>
      <td>HIE</td>
      <td></td>
    </tr>
    <tr>
      <td>WHO GDHCN</td>
      <td>WHO Global Digital Health Certification Network for management of public keys provided through National HIEs for verification of digital signatures</td>
      <td>GDHCN, Trust Network Gateway, TNG, Public Key Directory, PKD</td>
      <td></td>
    </tr>
    <tr>
      <td>WHO Terminology Service</td>
      <td>WHO hosted Terminology Service used for handling codesystems and valuesets used by National Systems</td>
      <td>WHO TS, TS</td>
      <td></td>
    </tr>
    <tr>
      <td>Host Country EMR</td>
      <td>EMR used in Host Country of the pilgrimage by the Host Country Health Worker for accessing and managing health records. Serves as the interface utilized to view and/or ingest patient summary documents from Pilgrims. The Host Country EMR should, at a minimum, save a rendered version (e.g. PDF) of the Pilgrim's patient summary document for audit and liability purposes. The Host Country EMR may optionally ingest the patient summary document and transmit or otherwise make it available to the Host Country HIE for continued patient care.
      In the optional scenario of a "break the glass" scenario, the Host Country EMR should retrieve the patient summary of the Pilgrim from the Host Country HIE via the association of that document to the Pilgrim Registration Number.</td>
      <td>Host EMR, EMR, Electronic Medical Records System</td>
      <td></td>
    </tr>
    <tr>
      <td>Host Country HIE</td>
      <td>Health Information Exchange of the Host Country which contains ingested patient summary information during a Pilgrim's care encounter or manages access to their patient summary during a "break the glass" scenario.</td>
      <td>Host HIE</td>
      <td></td>
    </tr>
  </tbody>
</table>



### External Hardware and Devices

<table class="list">
  <thead>
    <tr>
      <th>Service</th>
      <th>Description</th>
      <th>Different Names</th>
      <th>Service Code (if applicable)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Bar code scanner</td>
      <td>Handheld scanner capable of scanning QR Codes, linked to host country EMR.</td>
      <td>QR code scanner</td>
      <td></td>
    </tr>
    <tr>
      <td>Pilgrim card</td>
      <td>Physical card for pilgrims to carry that has the QR code printed on it.</td>
      <td></td>
      <td></td>
    </tr>
  </tbody>
</table>