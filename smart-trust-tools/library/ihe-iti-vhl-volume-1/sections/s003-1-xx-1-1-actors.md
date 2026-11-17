---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s003-1-xx-1-1-actors
section_title: "1:XX.1.1 Actors"
file: "input/pagecontent/volume-1.md"
lines: 107-117
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.1.1 Actors
The actors in this profile are described in more detail in the sections below.

{% assign canonicals = site.data.canonicals | where: 'type' , 'ActorDefinition' %}
{% for canonical in canonicals %}
   {% assign stub = canonical.type | append: "-" | append: canonical.id %}
   {% assign actordefinition = site.data[stub] %}
   {% include actordefinition-short-summary.liquid actordefinition=actordefinition site=site %}
{% endfor %}
