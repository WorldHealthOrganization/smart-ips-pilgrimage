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