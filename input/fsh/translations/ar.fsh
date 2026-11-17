// Arabic (ar) CodeSystem supplements for this IG's own CodeSystems.
// Agent translation, UNOFFICIAL and unreviewed: no human sign-off. One file per locale;
// the CodeSystems themselves are not edited. Displays and definitions mirror translations/ar/.

CodeSystem: BrowserCsAr
Id: BrowserCs-ar
Title: "المتصفح"
Description: "ملحق باللغة العربية (ar) لنظام الرموز BrowserCs: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(BrowserCs)
* ^language = #ar
* ^caseSensitive = true
* #Firefox "Firefox"
  * ^designation[0].language = #ar
  * ^designation[0].value = "Firefox"
* #Chrome "Chrome"
  * ^designation[0].language = #ar
  * ^designation[0].value = "Chrome"
* #MicrosoftEdge "MicrosoftEdge"
  * ^designation[0].language = #ar
  * ^designation[0].value = "MicrosoftEdge"
* #InternetExplorer "InternetExplorer"
  * ^designation[0].language = #ar
  * ^designation[0].value = "InternetExplorer"
* #Safari "Safari"
  * ^designation[0].language = #ar
  * ^designation[0].value = "Safari"
* #Other "أخرى"
  * ^designation[0].language = #ar
  * ^designation[0].value = "أخرى"

CodeSystem: DistributionModelCsAr
Id: DistributionModelCs-ar
Title: "نموذج التوزيع"
Description: "ملحق باللغة العربية (ar) لنظام الرموز DistributionModelCs: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(DistributionModelCs)
* ^language = #ar
* ^caseSensitive = true
* #Cloud-based "قائم على السحابة"
  * ^designation[0].language = #ar
  * ^designation[0].value = "قائم على السحابة"
* #On-premise "محلي (داخل المؤسسة)"
  * ^designation[0].language = #ar
  * ^designation[0].value = "محلي (داخل المؤسسة)"
* #Hybrid "هجين"
  * ^designation[0].language = #ar
  * ^designation[0].value = "هجين"

CodeSystem: IPSHAJJACTORAr
Id: IPS.HAJJ.ACTOR-ar
Title: "نظام الرموز IPS.HAJJ.ACTOR"
Description: "ملحق باللغة العربية (ar) لنظام الرموز IPS.HAJJ.ACTOR: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(IPS.HAJJ.ACTOR)
* ^language = #ar
* ^caseSensitive = true
* #ochie "منصة تبادل المعلومات الصحية (HIE) في بلد المنشأ"
  * ^designation[0].language = #ar
  * ^designation[0].value = "منصة تبادل المعلومات الصحية (HIE) في بلد المنشأ"
* #ochw "المحفظة الصحية في بلد المنشأ"
  * ^designation[0].language = #ar
  * ^designation[0].value = "المحفظة الصحية في بلد المنشأ"
* #hcemr "السجل الطبي الإلكتروني (EMR) في البلد المضيف"
  * ^designation[0].language = #ar
  * ^designation[0].value = "السجل الطبي الإلكتروني (EMR) في البلد المضيف"
* #pilgrim "الحاج"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الحاج"
* #scanner "الماسح الضوئي"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الماسح الضوئي"
* #qrcode "رمز QR"
  * ^designation[0].language = #ar
  * ^designation[0].value = "رمز QR"

CodeSystem: IPSHAJJCONSENTAr
Id: IPS.HAJJ.CONSENT-ar
Title: "نظام الرموز IPS.HAJJ.CONSENT"
Description: "ملحق باللغة العربية (ar) لنظام الرموز IPS.HAJJ.CONSENT: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(IPS.HAJJ.CONSENT)
* ^language = #ar
* ^caseSensitive = true
* #CONSENT-KSA "الموافقة الخاصة بالمملكة العربية السعودية" "يوافق الحاج على مشاركة ملخص المريض الدولي (بيانات IPS) الخاص به/بها أثناء تقديم الرعاية السريرية في المرافق الصحية التابعة لوزارة الصحة في المملكة العربية السعودية في منطقة المشاعر المقدسة خلال موسم حج 1446/2025، وكذلك أي رعاية متابعة قد يحتاج إليها من أي ممارس صحي"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الموافقة الخاصة بالمملكة العربية السعودية"
* #CONSENT-IDN "الموافقة الخاصة بإندونيسيا" "<يُدرَج نص من إندونيسيا: مناقشة موافقة الحجاج على استخدام Satusehat لتمكين المملكة العربية السعودية (KSA) من الوصول إلى ملخص IPS الخاص بهم إذا احتاجوا إلى الرعاية خلال الحج>"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الموافقة الخاصة بإندونيسيا"
* #CONSENT-MYS "الموافقة الخاصة بماليزيا" "قدّم الحاج الماليزي موافقته على مشاركة ملخص المريض الدولي (IPS) المُنشأ من البيانات المسجَّلة أثناء الفحص الصحي لحجاج بيت الله، إضافةً إلى سجلات التطعيم المخزَّنة في MySejahtera، مع المملكة العربية السعودية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الموافقة الخاصة بماليزيا"
* #CONSENT-OMN "الموافقة الخاصة بسلطنة عُمان" "<يُدرَج نص من عُمان: مناقشة موافقة الحجاج على استخدام بوابة الصحة الإلكترونية في عُمان لتمكين المملكة العربية السعودية (KSA) من الوصول إلى ملخص IPS الخاص بهم إذا احتاجوا إلى الرعاية>"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الموافقة الخاصة بسلطنة عُمان"

CodeSystem: IPSHAJJTRANSACTIONAr
Id: IPS.HAJJ.TRANSACTION-ar
Title: "نظام الرموز IPS.HAJJ.TRANSACTION"
Description: "ملحق باللغة العربية (ar) لنظام الرموز IPS.HAJJ.TRANSACTION: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(IPS.HAJJ.TRANSACTION)
* ^language = #ar
* ^caseSensitive = true
* #keys-put "نشر مفاتيح التحقق"
  * ^designation[0].language = #ar
  * ^designation[0].value = "نشر مفاتيح التحقق"
* #keys-get "استرجاع مفاتيح التحقق"
  * ^designation[0].language = #ar
  * ^designation[0].value = "استرجاع مفاتيح التحقق"
* #doc-sign "توقيع ملخص IPS"
  * ^designation[0].language = #ar
  * ^designation[0].value = "توقيع ملخص IPS"
* #doc-get "استرجاع ملخص IPS"
  * ^designation[0].language = #ar
  * ^designation[0].value = "استرجاع ملخص IPS"
* #shl-sign "توقيع رابط SMART Health Link"
  * ^designation[0].language = #ar
  * ^designation[0].value = "توقيع رابط SMART Health Link"
* #shl-doc-view "الوصول إلى عارض مستندات SHL"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الوصول إلى عارض مستندات SHL"
* #shl-get-manifest "استرجاع بيان مستندات SHL"
  * ^designation[0].language = #ar
  * ^designation[0].value = "استرجاع بيان مستندات SHL"
* #consent-post-counseling "تسجيل الموافقة - بعد الإرشاد"
  * ^designation[0].language = #ar
  * ^designation[0].value = "تسجيل الموافقة - بعد الإرشاد"
* #consent-wallet "تسجيل الموافقة - المحفظة الصحية الرقمية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "تسجيل الموافقة - المحفظة الصحية الرقمية"

CodeSystem: LanguageCsAr
Id: LanguageCs-ar
Title: "اللغة"
Description: "ملحق باللغة العربية (ar) لنظام الرموز LanguageCs: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(LanguageCs)
* ^language = #ar
* ^caseSensitive = true
* #Arabic "العربية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "العربية"
* #Chinese "الصينية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الصينية"
* #English "الإنكليزية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الإنكليزية"
* #French "الفرنسية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الفرنسية"
* #Russian "الروسية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الروسية"
* #Spanish "الإسبانية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "الإسبانية"
* #Other "أخرى"
  * ^designation[0].language = #ar
  * ^designation[0].value = "أخرى"

CodeSystem: LicensingModelCsAr
Id: LicensingModelCs-ar
Title: "نموذج الترخيص"
Description: "ملحق باللغة العربية (ar) لنظام الرموز LicensingModelCs: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(LicensingModelCs)
* ^language = #ar
* ^caseSensitive = true
* #Proprietary "مسجّل الملكية"
  * ^designation[0].language = #ar
  * ^designation[0].value = "مسجّل الملكية"
* #Open-Source "مفتوح المصدر"
  * ^designation[0].language = #ar
  * ^designation[0].value = "مفتوح المصدر"

CodeSystem: OperatingSystemCsAr
Id: OperatingSystemCs-ar
Title: "نظام التشغيل"
Description: "ملحق باللغة العربية (ar) لنظام الرموز OperatingSystemCs: تسميات كل مفهوم. ترجمة غير رسمية أعدّها وكيل آلي، دون مراجعة بشرية."
* ^status = #draft
* ^experimental = true
* ^content = #supplement
* ^supplements = Canonical(OperatingSystemCs)
* ^language = #ar
* ^caseSensitive = true
* #Linux "Linux"
  * ^designation[0].language = #ar
  * ^designation[0].value = "Linux"
* #Unix "Unix"
  * ^designation[0].language = #ar
  * ^designation[0].value = "Unix"
* #Windows "Windows"
  * ^designation[0].language = #ar
  * ^designation[0].value = "Windows"
* #Mac "Mac"
  * ^designation[0].language = #ar
  * ^designation[0].value = "Mac"
* #Other "أخرى"
  * ^designation[0].language = #ar
  * ^designation[0].value = "أخرى"
