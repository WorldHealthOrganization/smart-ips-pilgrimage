---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s023-2-3-yy5-5-3-oauth-with-ssraa-option
section_title: "2:3.YY5.5.3 OAuth with SSRAA Option"
file: "input/pagecontent/ITI-YY5.md"
lines: 824-834
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.3 OAuth with SSRAA Option 
Implementations that support OAuth with SSRAA Option SHALL:
- Use OAuth 2.0 Backend Services (client_credentials grant)
- Use JWT client assertions (private_key_jwt) for client authentication
- Include appropriate FHIR scopes in access token
- Validate token signature, expiration, and scope
- Limit token lifetime (recommended: 1 hour maximum)
- Check JWT `jti` claim to prevent replay attacks
- Obtain receiver's public key from trust list for JWT signature validation
- The authorization server SHALL validate the JWT client assertion signature and verify that the X.509 certificate carried in the `x5c` JWT header chains to a trust anchor in the trust community before issuing an access token
