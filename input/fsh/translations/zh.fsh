// Simplified Chinese (zh) display designations for this IG's code systems,
// as FHIR CodeSystem supplements (content = supplement): FHIR's own
// translation mechanism, one file per locale, no edit to the base code systems.
// UNOFFICIAL: drafted by an agent; no human has signed it off.
// Codes, product names and acronyms are kept as written.

CodeSystem: BrowserCsZh
Id: BrowserCs-zh
Title: "BrowserCs — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the BrowserCs code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(BrowserCs)
* #Other
* #Other ^designation[+].language = #zh
* #Other ^designation[=].value = "其他"

CodeSystem: DistributionModelCsZh
Id: DistributionModelCs-zh
Title: "DistributionModelCs — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the DistributionModelCs code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(DistributionModelCs)
* #Cloud-based
* #Cloud-based ^designation[+].language = #zh
* #Cloud-based ^designation[=].value = "基于云"
* #On-premise
* #On-premise ^designation[+].language = #zh
* #On-premise ^designation[=].value = "本地部署"
* #Hybrid
* #Hybrid ^designation[+].language = #zh
* #Hybrid ^designation[=].value = "混合"

CodeSystem: IPSHAJJACTORZh
Id: IPS.HAJJ.ACTOR-zh
Title: "IPS.HAJJ.ACTOR — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the IPS.HAJJ.ACTOR code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(IPS.HAJJ.ACTOR)
* #ochie
* #ochie ^designation[+].language = #zh
* #ochie ^designation[=].value = "来源国健康信息交换（HIE）"
* #ochw
* #ochw ^designation[+].language = #zh
* #ochw ^designation[=].value = "来源国健康钱包"
* #hcemr
* #hcemr ^designation[+].language = #zh
* #hcemr ^designation[=].value = "东道国电子病历（EMR）"
* #pilgrim
* #pilgrim ^designation[+].language = #zh
* #pilgrim ^designation[=].value = "朝觐者"
* #scanner
* #scanner ^designation[+].language = #zh
* #scanner ^designation[=].value = "扫描器"
* #qrcode
* #qrcode ^designation[+].language = #zh
* #qrcode ^designation[=].value = "QR 码"

CodeSystem: IPSHAJJCONSENTZh
Id: IPS.HAJJ.CONSENT-zh
Title: "IPS.HAJJ.CONSENT — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the IPS.HAJJ.CONSENT code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(IPS.HAJJ.CONSENT)
* #CONSENT-KSA
* #CONSENT-KSA ^designation[+].language = #zh
* #CONSENT-KSA ^designation[=].value = "沙特阿拉伯王国的同意"
* #CONSENT-IDN
* #CONSENT-IDN ^designation[+].language = #zh
* #CONSENT-IDN ^designation[=].value = "印度尼西亚的同意"
* #CONSENT-MYS
* #CONSENT-MYS ^designation[+].language = #zh
* #CONSENT-MYS ^designation[=].value = "马来西亚的同意"
* #CONSENT-OMN
* #CONSENT-OMN ^designation[+].language = #zh
* #CONSENT-OMN ^designation[=].value = "阿曼的同意"

CodeSystem: IPSHAJJTRANSACTIONZh
Id: IPS.HAJJ.TRANSACTION-zh
Title: "IPS.HAJJ.TRANSACTION — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the IPS.HAJJ.TRANSACTION code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(IPS.HAJJ.TRANSACTION)
* #keys-put
* #keys-put ^designation[+].language = #zh
* #keys-put ^designation[=].value = "发布验证密钥"
* #keys-get
* #keys-get ^designation[+].language = #zh
* #keys-get ^designation[=].value = "获取验证密钥"
* #doc-sign
* #doc-sign ^designation[+].language = #zh
* #doc-sign ^designation[=].value = "签署 IPS"
* #doc-get
* #doc-get ^designation[+].language = #zh
* #doc-get ^designation[=].value = "获取 IPS"
* #shl-sign
* #shl-sign ^designation[+].language = #zh
* #shl-sign ^designation[=].value = "签署智能健康链接"
* #shl-doc-view
* #shl-doc-view ^designation[+].language = #zh
* #shl-doc-view ^designation[=].value = "访问 SHL 文档查看器"
* #shl-get-manifest
* #shl-get-manifest ^designation[+].language = #zh
* #shl-get-manifest ^designation[=].value = "获取 SHL 文档清单"
* #consent-post-counseling
* #consent-post-counseling ^designation[+].language = #zh
* #consent-post-counseling ^designation[=].value = "记录同意——咨询后"
* #consent-wallet
* #consent-wallet ^designation[+].language = #zh
* #consent-wallet ^designation[=].value = "记录同意——数字健康钱包"

CodeSystem: LanguageCsZh
Id: LanguageCs-zh
Title: "LanguageCs — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the LanguageCs code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(LanguageCs)
* #Arabic
* #Arabic ^designation[+].language = #zh
* #Arabic ^designation[=].value = "阿拉伯语"
* #Chinese
* #Chinese ^designation[+].language = #zh
* #Chinese ^designation[=].value = "中文"
* #English
* #English ^designation[+].language = #zh
* #English ^designation[=].value = "英语"
* #French
* #French ^designation[+].language = #zh
* #French ^designation[=].value = "法语"
* #Russian
* #Russian ^designation[+].language = #zh
* #Russian ^designation[=].value = "俄语"
* #Spanish
* #Spanish ^designation[+].language = #zh
* #Spanish ^designation[=].value = "西班牙语"
* #Other
* #Other ^designation[+].language = #zh
* #Other ^designation[=].value = "其他"

CodeSystem: LicensingModelCsZh
Id: LicensingModelCs-zh
Title: "LicensingModelCs — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the LicensingModelCs code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(LicensingModelCs)
* #Proprietary
* #Proprietary ^designation[+].language = #zh
* #Proprietary ^designation[=].value = "专有"
* #Open-Source
* #Open-Source ^designation[+].language = #zh
* #Open-Source ^designation[=].value = "开源"

CodeSystem: OperatingSystemCsZh
Id: OperatingSystemCs-zh
Title: "OperatingSystemCs — Chinese (zh) supplement"
Description: "Unofficial Simplified Chinese (zh) display designations for the OperatingSystemCs code system, drafted by an agent and not signed off by a human."
* ^experimental = true
* ^status = #draft
* ^language = #zh
* ^content = #supplement
* ^supplements = Canonical(OperatingSystemCs)
* #Other
* #Other ^designation[+].language = #zh
* #Other ^designation[=].value = "其他"
