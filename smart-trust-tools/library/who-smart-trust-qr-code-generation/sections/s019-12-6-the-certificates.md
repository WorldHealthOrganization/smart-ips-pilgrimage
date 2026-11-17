---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s019-12-6-the-certificates
section_title: "12.6 The certificates"
file: "input/pagecontent/qr_code_generation.md"
lines: 306-340
source_sha256: 03253100cd38b5c6
granularity: heading
---
##### 12.6 The certificates

Hepatitis B birth dose:

<div style="display:block">
  <img src="dvc-qr-example-hepb1-XXR.png" alt="DVC QR code, Hepatitis B birth dose, GDHCN DEV participant XXR" width="300" />
</div>

```
HC1:NCFOXN%TSMAHN-HHPC*8W$BM70GZW8WI47X5JU9V21HJI.OR.6J:X90$TZIPAN9I6TSQLMN2SRPOK62YU%E6SOEGW2Z0W/TO+4W3R3ZP3XQ7KUHMQQTOE2QERM2ZGA2:UG%UBPISWUO FFPEUCAQZ4K%I7YV4SVO*I1R5LK90DQK7E$BESW6846OVQICMKR6PK96M53A5/41B$P6 0JIIO*LM4UJH2/JT0DJ$JAGU09VCRCKCWC.XI5TBC+J$ZIMOBKEALOB3YIX1JM7JZIJXUK0HIQVBPEB:CJZTAI8A+BDWZD$BCTD0D4OZFJ3JKJMOZD5+B9$/G547Z2ETZVJFD-ST53VMK9E/AUJ6R9KFAQB+RL7JYX69$1K-PF:E+7AYCTGARL6KGND1K6CPFT*P-8AHFSA16U9FS34:TG/0E  6$TP*705SS44
```

BCG, the second certificate from the same visit:

<div style="display:block">
  <img src="dvc-qr-example-bcg-XXR.png" alt="DVC QR code, BCG birth dose, GDHCN DEV participant XXR" width="300" />
</div>

```
HC1:NCFOXN%TSMAHN-HHPC*8W$BM70GZW8WI4%%5JU9V21HJI.OR.6J:X90$TZIPAN9I6TSQLMN2SRPOK62YU%E6SOEGW2Z0W/TO+4W3R3ZP3XQ7KUHMQQTOE2QERM2ZGA2:UG%UBPISWUO FFPEUCAQZ4K%I7YV4SVO*I1R5LK99AQ7LED9RNF66J6QW6:9631A*2QYDEUGAEHP8X9HSRH8KE62.13%USNCTZXIK/IL-A9AD.PD0DJGDBAB4X3C+1MRCA0ZKI8AZ3CYIJ*ZJFDJ0UJM2C8BI/NI6SI1-ACYI0+TKQ3200M:C IJM5Q52IHJP7NVQ794S8E41F.520NRYE2.JDAOSZFZNM*SJ7ONT5DE*VMKL$ASR%514QW*PA4DOQF%MV9CUYMDO:0VWKY4M.QPYI4I$U*.885E L1JJBHA5T B961BC0/:E
```

Both certificates carry the key identifier `kW/6VnwPRKI=`
(hex `916ffa567c0f44a2`).

To verify them, resolve that `kid` against the GDHCN trust list rather than
against any copy of the certificate shipped beside the QR code. The DID trust
list endpoints for the development, user-acceptance testing and production
environments are listed under
[Trustlist Distribution Endpoints](endpoints.html#trustlist-distribution-endpoints);
this example is issued in **DEV**, so its Document Signing Certificate is on the
DEV trust list. Fetching the signing certificate from the trust list is the
verification path the specification defines, and the only one that tells a
verifier the key is still trusted — a certificate distributed alongside the
certificate it signed proves nothing about that.
