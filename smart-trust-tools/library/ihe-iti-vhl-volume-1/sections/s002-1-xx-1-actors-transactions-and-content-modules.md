---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s002-1-xx-1-actors-transactions-and-content-modules
section_title: "1:XX.1 Actors, Transactions, and Content Modules"
file: "input/pagecontent/volume-1.md"
lines: 40-106
source_sha256: 1227bd54486fad1f
granularity: heading
---
## 1:XX.1 Actors, Transactions, and Content Modules

This section defines the actors, transactions, and/or content modules in this profile. Further information about actor and transaction definitions can be found in the IHE Technical Frameworks General Introduction [Appendix A: Actors](https://profiles.ihe.net/GeneralIntro/ch-A.html) and [Appendix B: Transactions](https://profiles.ihe.net/GeneralIntro/ch-B.html).

<ul>
  <li>
    Actors
	{% include actordefinition-list.liquid site=site %}
  </li>
  <li>
    Transactions
    <ul>
		<li> {{ linksubmitpki }}</li>
		<li> {{ linkretrievepki }}</li>
		<li> {{ linkgeneratevhl }} </li>
		<li> {{ linkprovidevhl }}</li>
		<li> {{ linkretrievemanifest }}</li>
	</ul>
  </li>
</ul>

As a pre-condition to transactions ITI-YY4 and ITI-YY5, the {{ linkvhlr }} and {{ linkvhls }} SHALL have established trust relationships enabling mutual authentication and VHL signature verification.

This trust MAY be established through:
- Implementation of the optional Submit PKI Material with DID [ITI-YY1] and Retrieve Trust List with DID [ITI-YY2] transactions, OR
- Alternative jurisdiction-specific PKI exchange mechanisms (out of scope for this profile)

This is illustrated in Figure 1:XX.1-1.

<figure >
  <div style="width:35em; max-width:100%;">
  {%include trust_interaction.svg%}
  </div>
  <p id="f1:XX.1-1" class="figureTitle">Figure 1:XX.1-1
  : Trust Network PKI Exchange</p>
</figure>

The process of a VHL Holder requesting a VHL for a set of health documents from a {{ linkvhls }} and subsequently sharing them to a {{ linkvhlr }} is illustrated in Figure X.X.X.X-2.

<figure >
  <div style="width:18em; max-width:100%;">
  {%include vhl_interaction.svg%}
  </div>
  <p id="f1:XX.1-2" class="figureTitle" >Figure 1:XX.1-2: VHL Generation, Provision, and Document Retrieval Flow</p>
</figure>

<br clear="all">

<p id ="tXX.1-1" class="tableTitle">Table XX.1-1: VHL Profile - Actors and Transactions</p>

| Actors         | Transactions                 | Initiator or Responder | Optionality| Reference                 |
|----------------|------------------------------|------------------------|------------|---------------------------|
| {{ linkta }}   | {{ linksubmitpki }}          | Responder              | R          | ITI TF-2: 3.YY1 |
|                | {{ linkretrievepki }}        | Responder              | R          | ITI TF-2: 3.YY2 |
| {{ linkvhlh }} | {{ linkgeneratevhl }}        | Initiator              | R          | ITI TF-2: 3.YY3 |
|                | {{ linkprovidevhl }}         | Initiator              | R          | ITI TF-2: 3.YY4 |
| {{ linkvhlr }} | {{ linksubmitpki }}          | Initiator              | O          | ITI TF-2: 3.YY1 |
|                | {{ linkretrievepki }}        | Initiator              | O          | ITI TF-2: 3.YY2 |
|                | {{ linkprovidevhl }}         | Responder              | R          | ITI TF-2: 3.YY4 |
|                | {{ linkretrievemanifest }}   | Initiator              | R          | ITI TF-2: 3.YY5 |
| {{ linkvhls }} | {{ linksubmitpki }}          | Initiator              | O          | ITI TF-2: 3.YY1 |
|                | {{ linkretrievepki }}        | Initiator              | O          | ITI TF-2: 3.YY2 |
|                | {{ linkgeneratevhl }}        | Responder              | R          | ITI TF-2: 3.YY3 |
|                | {{ linkretrievemanifest }}   | Responder              | R          | ITI TF-2: 3.YY5 |
{: .grid}
