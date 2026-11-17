ValueSet:     IPS.HAJJ.ACTOR.SYSTEM
Title:        "IPS.HAJJ.ACTOR.SYSTEM ValueSet of actor"
Description:  "ValueSet of codes for system actors for the pilgrimage"

* ^status = #active
* ^experimental = true
* ^name = "IPS_HAJJ_ACTOR_SYSTEM"
* include codes from system $IPSHajjActor
* exclude $IPSHajjActor#pilgrim "Pilgrim"
* exclude $IPSHajjActor#qrcode "QR Code"
