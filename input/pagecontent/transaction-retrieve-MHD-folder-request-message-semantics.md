

##### Message Semantics Request
- The message semantics for retrieve VHL folder docs request shall be a POST request as specified by [SMART Health Link Manifest Request](https://build.fhir.org/ig/HL7/smart-health-cards-and-links/links-specification.html#smart-health-link-manifest-request), along with the passcode provided in the body of the request.


##### Message Semantics Response
- The message semantics shall follow a <b>modified</b> version of the [ITI-67](https://profiles.ihe.net/ITI/MHD/ITI-67.html#2367422-message-semantics) Find Document References response message and for a successful queries return a FHIR bundle that includes all documentReference available in the VHL folder for the pilgrim.  The modification of the ITI-67 transaction is that the Origin Country HIE shall respect the <em>_include</em> search parameter with value <em>List:item</em> as the URL generated in the VHL Payload is of  of the format:
> {host}/List?_id={folder_id}&_include=List:item"


##### Authentication of the Host Country EMR
The retrieve VHL folder docs request corresponds to the IHE Verifiable Health Link (VHL) Retrieve Manifest transaction [ITI-YY5]. VHL is cited here at version [1.0.0-comment](https://profiles.ihe.net/ITI/VHL/1.0.0-comment/), which is a **public-comment ballot**, not a final or trial-implementation publication; its text and section numbers may change. The sections cited below were read from the IHE/ITI.VHL source (commit `48201473`), not from the published ballot pages.

VHL [ITI-YY5] names three options by which the VHL Receiver (here, the Host Country EMR) authenticates to the VHL Sharer (here, the Origin Country HIE):
- **HTTP Message Signatures** (RFC 9421), ITI-YY5 §2:3.YY5.4.1.3;
- **OAuth with SSRAA Option**, using the [HL7 Security for Scalable Registration, Authentication, and Authorization (SSRAA)](http://hl7.org/fhir/us/udap-security/) implementation guide, the HL7 FHIR profile of UDAP, ITI-YY5 §2:3.YY5.4.1.4;
- **Verifiable Credential Option**, ITI-YY5 §2:3.YY5.4.1.5.

This guide currently shows the Host Country EMR authenticating to the Origin Country HIE with mTLS node authentication ([ITI-19]) (see the unplanned care encounter sequence diagram). **mTLS node authentication is not one of the three VHL authentication options.** VHL still requires secure transport: ITI-YY5 §2:3.YY5.5.1 requires compliance with the IHE ATNA Profile for transport security, and VHL Volume 1 §1:XX.3 requires the VHL Receiver and the VHL Sharer to be grouped with an ATNA Secure Node or Secure Application. A TLS channel is therefore still expected, but on its own it does not satisfy any of the VHL authentication options.

It is **recommended** that the Host Country EMR authenticate with the **OAuth with SSRAA Option**. Like the current mTLS approach it is based on X.509 certificates: the Host Country EMR's certificate chains to an anchor accepted in the `ips-pilgrimage` trust domain, so the Origin Country HIE identifies the receiver by that trust, not by looking up a separate agreement. Under that option, SSRAA discovery and registration are completed before an access token is requested (ITI-YY5 §2:3.YY5.4.1.4). How the Host Country EMR's certificate or key is published in the `ips-pilgrimage` trust domain is not yet specified by this guide.
