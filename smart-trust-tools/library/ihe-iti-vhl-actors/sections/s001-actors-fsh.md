---
doc_id: ihe-iti-vhl-actors
doc_title: "IHE ITI VHL ActorDefinitions (FSH)"
section_id: s001-actors-fsh
section_title: "actors.fsh"
file: "actors.fsh"
lines: 1-43
source_sha256: ded951945702fe28
granularity: file
---
```text
Instance: TrustAnchor
InstanceOf: ActorDefinition
Usage: #definition
* name = "TrustAnchor"
* title = "Trust Anchor"
* description = "An authorized organization in the trust framework that manages and distributes PKI material—such as public key certificates and revocation lists—to participants in the network. It ensures that this material is trustworthy and available, enabling VHL Sharers and VHL Receivers to verify digital signatures and authenticate the origin of shared data."
* status = $pubStatus#active
* publisher = "IHE"
* type = $actorType#system
* capabilities[+] = Canonical(IHE.VHL.TrustAnchor)

Instance: VHLHolder
InstanceOf: ActorDefinition
Usage: #definition
* name = "VHLHolder"
* title = "VHL Holder"
* description = "An individual—typically the patient or their delegate—who possesses a Verified Health Link (VHL), a signed data artifact that enables a VHL Receiver to verify its authenticity and access one or more health documents made available by a VHL Sharer.
"
* status = $pubStatus#active
* publisher = "IHE"
* type = $actorType#person

Instance: VHLReceiver
InstanceOf: ActorDefinition
Usage: #definition
* name = "VHLReceiver"
* title = "VHL Receiver"
* description = "A system or organization that receives a Verified Health Link (VHL) from a VHL Holder and uses it to retrieve health documents from a VHL Sharer, after verifying the authenticity and integrity of the VHL.
"
* status = $pubStatus#active
* publisher = "IHE"
* type = $actorType#system

Instance: VHLSharer
InstanceOf: ActorDefinition
Usage: #definition
* name = "VHLSharer"
* title = "VHL Sharer"
* description = "The VHL Sharer generates a VHL, provides the VHL to a VHL Holder, and responds to requests from a VHL Sharer to utilize the VHL."
* status = $pubStatus#active
* publisher = "IHE"
* type = $actorType#system
```
