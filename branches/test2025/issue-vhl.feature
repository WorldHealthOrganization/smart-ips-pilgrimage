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
