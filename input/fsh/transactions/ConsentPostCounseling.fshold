
Instance: consent-post-counseling
InstanceOf: $SGTransactionDef
* title = "Record Consent - Post-Counseling"
* description = "Record Consent - Post-Counseling. Intended in bulk"
* name  = "consent-post-counseling"

* link[+].extension[triggerEvents].valueMarkdown = """Consent can be recorded based on a post counseling based on a blanket jurisdictional policy for Pilgrims as part of their permission to go on Hajj against a list of Pilgrim IDs of those that went through the health assessment check."""
* link[=].extension[messageSemantics].valueMarkdown = """The OCHIE shall support create and update per the  [IHE PCF Consent Recorder Capability Statement](https://profiles.ihe.net/ITI/PCF/CapabilityStatement-IHE.PCF.consentRecorder.html). """
* link[=].extension[expectedActions].valueMarkdown = """The OCHIE SHALL act as  [IHE PCF Consent Recorder](https://profiles.ihe.net/ITI/PCF/volume-1.html#153111-consent-recorder) """
* link[=].extension[code].valueCoding = $IPSHajjTrans#consent-post-counseling
* link[=].sourceId = "consent-post-counseling-source"
* link[=].targetId = "consent-post-counseling-target"

* node[+].nodeId = "consent-post-counseling-source"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor    
* node[=].extension[actor].valueReference = Reference(OCHIE)

* node[+].nodeId = "consent-post-counseling-target"
* node[=].type = #ActorDefinition
* node[=].profile = $SGActor    
* node[=].extension[actor].valueReference = Reference(OCHIE)


* experimental = false
* status = #active
