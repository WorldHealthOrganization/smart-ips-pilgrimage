Feature: Connectivity

Scenario: mTLS connection is successful
GIVEN Origin Country HIE has uploaded public keys to Trust Anchor
AND Host Country EMR has uploaded public keys to Trust Anchor
AND Host Country EMR has retrieved and cached all public keys
WHEN Host Country EMR identifies Origin Country certificate and initiate a connection
THEN the Origin Country EMR is able to identify the Host Country EMR
AND responds to the connection request
AND connection is successful