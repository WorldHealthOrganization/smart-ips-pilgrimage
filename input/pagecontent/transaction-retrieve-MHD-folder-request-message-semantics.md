

##### Message Semantics Request
- The message semantics for retrieve VHL folder docs request shall be a POST request as specified by [SMART Health Link Manifest Request](https://build.fhir.org/ig/HL7/smart-health-cards-and-links/links-specification.html#smart-health-link-manifest-request), along with the passcode provided in the body of the request.


##### Message Semantics Response
- The message semantics shall follow a <b>modified</b> version of the [ITI-67](https://profiles.ihe.net/ITI/MHD/ITI-67.html#2367422-message-semantics) Find Document References response message and for a successful queries return a FHIR bundle that includes all documentReference available in the VHL folder for the pilgrim.  The modification of the ITI-67 transaction is that the Origin Country HIE shall respect the <em>_include</em> search parameter with value <em>List:item</em> as the URL generated in the VHL Payload is of  of the format:
> {host}/List?_id={folder_id}&_include=List:item"
