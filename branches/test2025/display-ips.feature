Feature: Retrieve IPS JSON

Scenario: Retrieve IPS JSON request is sent
GIVEN VHL Manifest is obtained
WHEN the Host Country EMR sends a GET request for the IPS JSON
THEN the server responds with the IPS as a JSON

Scenario: Retrieve IPS PDF request is sent
GIVEN VHL Manifest is obtained
WHEN the Host Country EMR sends a GET request for the IPS PDF
THEN the server responds with the IPS as a PDF