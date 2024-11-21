Instance: shl-sign
InstanceOf: $SGTransactionDef
* title = "Sign Smart Health Link"
* description = "Sign Smart Health Link"
* name = "shl-sign"

* link[+].extension[triggerEvents].valueMarkdown = """Once a Smart Health Link has been generated, it SHALL be signed."""
* link[=].extension[messageSemantics].valueMarkdown = """Use the  [Sign Health Certificate Claim](https://smart.who.int/trust/transactions.html#sign_claim) transaction."""
* link[=].extension[expectedActions].valueMarkdown = """One the Smart Health Link has been signed, it is a Verifiable Smart Health Link which should be provided to the Pilgrim."""
* link[=].extension[code].valueCoding = $IPSHajjTrans#shl-sign
* link[=].sourceId = "shl-sign-source"
* link[=].targetId = "shl-sign-target"

* node[+].nodeId = "shl-sign-source"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor
* node[=].extension[actor].valueReference = Reference(OCHIE)

* node[+].nodeId = "shl-sign-target"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor
* node[=].extension[actor].valueReference = Reference(OCHIE)


* status = #active
* experimental = false
