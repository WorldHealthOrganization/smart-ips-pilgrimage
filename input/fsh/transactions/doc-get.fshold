Instance: doc-get
InstanceOf: $SGTransactionDef
* title = "Get IPS or other Document"
* description = "Get IPS"
* name = "doc-get"

* link[+].extension[triggerEvents].valueMarkdown = """SHL Manifest was retrieved and refers to IPS or other document"""
* link[=].extension[messageSemantics].valueMarkdown = """Same for retrieving a FHIR Document Bundle such as IPS using GET"""
* link[=].extension[expectedActions].valueMarkdown = """ Return the requested bundle assuming access controls and jurisidictional policies are met"""
* link[=].extension[code].valueCoding = $IPSHajjTrans#doc-get
* link[=].sourceId = "doc-get-source"
* link[=].targetId = "doc-get-target"

* node[+].nodeId = "doc-get-source"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor
* node[=].extension[actor].valueReference = Reference(HCEMR)

* node[+].nodeId = "doc-get-target"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor
* node[=].extension[actor].valueReference = Reference(OCHIE)


* status = #active
* experimental = false

