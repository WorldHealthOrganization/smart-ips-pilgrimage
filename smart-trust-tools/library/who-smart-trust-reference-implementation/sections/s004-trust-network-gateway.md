---
doc_id: who-smart-trust-reference-implementation
doc_title: "Reference Implementations"
section_id: s004-trust-network-gateway
section_title: "Trust Network Gateway"
file: "input/pagecontent/reference_implementation.md"
lines: 21-38
source_sha256: a7a07cd4378e7d2c
granularity: heading
---
### Trust Network Gateway

The Trust Network Gateway is an open source implementation of a centralized trust network solution available to potential implementers intending to create a local or regional network. This implementation is derived from the [European Union Digital COVID Certificate Gateway (EUDCCG)](https://github.com/ehn-dcc-development/eu-dcc-overview), which has been deployed in an operational setting within the European Union.

In addition to the core functionality of the EUDCCG, the Trust Network Gateway implementation also supports:
-	Federation and peer exchange of information between gateways
-	Access to metadata content (e.g. value sets/codings, business rules) with explicit adherence to the HL7 FHIR specification
-	Explicit means for revocation of digital COVID certificates
-	Optional support of online verification and validation workflows

The role of the Trust Network Gateway is to enable the creation of trust networks by additional
organizations beyond the EU Member States participating in the EUDCCG,
expanding the network of operators and trusted parties to form a federated and
documented network of trust gateways, supporting all major health credential certificates.

-	[Trust Network Gateway public repository](https://github.com/WorldHealthOrganization/ddcc-gateway)
-	[Architecture](./trust_network_gateway_architecture.html)
-	[Swagger API](openapi)
