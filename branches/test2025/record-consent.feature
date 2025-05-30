Feature: Record Consent

Scenario: Consent is provided and saved successfully
GIVEN an IPS is generated
WHEN a new consent directive has been recorded by a Origin Country Health Wallet
THEN the Origin Country Health wallet initiates a record consent request as a PUT/POST request along with FHIR consent resource compliant with ITI-108 Create request
AND the Origin Country HIE stores the consent resource in the consent registry
AND sends a success response as indicated by http response code

Scenario: Consent is provided but fails to save
GIVEN an IPS is generated
WHEN a new consent directive has been recorded by a Origin Country Health Wallet
THEN the Origin Country Health wallet initiates a record consent request as a PUT/POST request along with FHIR consent resource compliant with ITI-108 Create request
AND the Origin Country HIE attempts to store the consent resource in the consent registry and fails
AND sends a failure response as indicated by http response code
