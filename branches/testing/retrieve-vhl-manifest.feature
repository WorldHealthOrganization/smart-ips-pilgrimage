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