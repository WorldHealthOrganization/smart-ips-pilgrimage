This page will include test cases developed for the test scenarios, transactions and actors included in this implementation guide. See [Testing](testing.html) for additional testing artifacts.

The testing artifacts in this implementation guide are not intended to be used to determine formal conformance, nor are they intended to be authoritative or comprehensive.


### IPS-Pilgrimage End to End Workflow

#### Issuance of verifiable health document (IPS)

##### Record Consent

{% include gherkin_file file="record-consent.feature" %}

##### Issue VHL
{% include gherkin_file file="issue-vhl.feature" %}


#### Unplanned Clinical Encounter at Hajj Health Facility

##### Verify Signature on CWT Payload using Kid

{% include gherkin_file file="verify-qr.feature" %}



##### Retrieve VHL Manifest
{% include gherkin_file file="retrieve-vhl-manifest.feature" %}




##### Retrieve IPS

{% include gherkin_file file="retrieve-ips.feature" %}

##### Validate retrieved IPS content
{% include gherkin_file file="validate-ips.feature" %}



##### View IPS content

{% include gherkin_file file="display-ips.feature" %}

