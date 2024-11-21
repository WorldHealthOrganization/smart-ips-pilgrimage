Instance: keys-put
InstanceOf: $SGTransactionDef
* title = "Publish Verification Keys"
* description = "Publish Verification Keys"
* name = "keys-put"

* link[+].extension[triggerEvents].valueMarkdown = """ """
* link[=].extension[messageSemantics].valueMarkdown = """
The OCHIE SHALL use one of the following transactions:
- [Publish Verification Keys - API](https://smart.who.int/trust/transactions.html#put_keys_api)
"""
* link[=].extension[expectedActions].valueMarkdown = """ """
* link[=].extension[code].valueCoding = $IPSHajjTrans#keys-put
* link[=].sourceId = "keys-put-source"
* link[=].targetId = "keys-put-target"

* node[+].nodeId = "keys-put-source"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor     
* node[=].extension[actor].valueReference = Reference(OCHIE)

* node[+].nodeId = "keys-put-target"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor  
* node[=].extension[actor].valueReference = Reference($GDHCN)


* status = #active
* experimental = false
