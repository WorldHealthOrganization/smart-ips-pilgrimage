This page will include test cases developed for the test scenarios, transactions and actors included in this implementation guide. See [Testing](testing.html) for additional testing artifacts.

The testing artifacts in this implementation guide are not intended to be used to determine formal conformance, nor are they intended to be authoritative or comprehensive.


### IPS-Pilgrimage End to End Workflow

#### Issuance of verifiable health document (IPS)

##### Record Consent

{% include gherkin_file file="record-consent.feature"%}

##### Issue VHL

```
Feature: Issue VHL

Scenario: QR Code with HCERT containing VHL is generated
GIVEN an IPS is generated
AND consent is provided
AND a Passcode and time limit is set
WHEN the Origin Country Digital Health Wallet sends a issue-vhl-request to Origin Country HIE
THEN the Origin Country HIE constructs a VHL payload
AND embeds the VHL in HCERT
AND constructs COSE payload
AND signs the payload with Kid
AND builds CWT structure
AND serializes CWT and encodes to Base64
AND generates the QR Code

```

#### Unplanned Clinical Encounter at Hajj Health Facility

##### Verify Signature on CWT Payload using Kid

```

Feature: Verify QR Code signature

Scenario: Verify valid QR Code
GIVEN a QR code is shared
WHEN a scanner is used to read the QR code
THEN a base64 encoded CWT is obtained
AND COSE message is extracted
AND signature on CWT Payload is verified using Kid reference in CWT Header
AND signature verification is successful and the HCERT is obtained

Scenario: QR code provided is invalid
GIVEN a QR code is shared for which the signature has expired
WHEN a scanner is used to read the QR code
THEN a base64 encoded CWT is obtained
AND COSE message is extracted
AND signature on CWT Payload is verified using Kid reference in CWT Header
AND signature verification fails
AND Error message is sent

```

##### Retrieve VHL Manifest

```

Feature: Retrieve VHL Manifest

Scenario: VHL Manifest Request is valid
GIVEN a HCERT containing a SMART Health Link is obtained
WHEN the Host Country EMR decodes the VHL Payload and issues a VHL Manifest Request
AND a correct passcode is provided
AND the VHL has not expired
THEN the server returns the VHL Manifest as a JSON object

Scenario: VHL Manifest Request made with invalid passcode
GIVEN a HCERT containing a SMART Health Link is obtained
WHEN the Host Country EMR decodes the VHL Payload and issues a VHL Manifest Request
AND incorrect passcode is provided
THEN the server returns an error response using 401 HTTP status code and the response body is sent as a JSON payload with
remainingAttempts

Scenario: VHL Manifest Request but the VHL has expired
GIVEN a HCERT containing a SMART Health Link is obtained
WHEN the Host Country EMR decodes the VHL Payload and issues a VHL Manifest Request
AND the SMART Health Link has expired
THEN the server returns an error response using 404 HTTP status code

```

##### Retrieve IPS

```

Feature: Retrieve IPS JSON

Scenario: Retrieve IPS JSON request is sent
GIVEN VHL Manifest is obtained
WHEN the Host Country EMR sends a GET request for the IPS JSON
THEN the server responds with the IPS as a JSON

Scenario: Retrieve IPS PDF request is sent
GIVEN VHL Manifest is obtained
WHEN the Host Country EMR sends a GET request for the IPS PDF
THEN the server responds with the IPS as a PDF

```

##### Validate retrieved IPS content

```

Feature: Validate retrieved IPS content

Scenario: Retrieved IPS content is valid
GIVEN the Host Country EMR retrieved IPS Content as JSON
WHEN the EMR validates the IPS content
THEN IPS content validation is successful
AND IPS Content is displayed

Scenario: Retrieved IPS content is invalid
GIVEN the Host Country EMR retrieved IPS Content as JSON
WHEN the EMR validates the IPS content
THEN IPS content validation fails
AND error message is sent

```

##### View IPS content

```

Feature: View IPS content

Scenario: View IPS content
GIVEN retrieved IPS content validated successfully
THEN the IPS narrative is rendered using tags provided in the JSON

```
