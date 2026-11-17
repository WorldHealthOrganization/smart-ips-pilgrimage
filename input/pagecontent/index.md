{% lang-fragment journey-hero.html %}

This Implementation Guide is intended to support the utilization of verifiable International Patient Summary (IPS) documents during pilgrimage, leveraging [WHO Global Digital Health Certification Network (GDHCN)](https://www.who.int/initiatives/global-digital-health-certification-network) global public health infrastructure.

<div style="float: left;">
This implementation guide and set of artifacts are still undergoing development. 
</div>
{:.stu-note}

<br clear="all"/>
### Eight moments that matter

<div markdown="0">{% lang-fragment journey-cards.html %}</div>
<br clear="all"/>

The [user scenarios](scenarios.html) of this guide told as one pilgrim's story,
step by step along the [overview of key process flows](business-processes.html)
(the numbered steps 1–5 and A–B of the figure below). Click a picture to walk
through that moment in the [journeys viewer](en/smart-ips-pilgrimage/journeys/smart-ips-pilgrimage/the-pilgrims-hajj/),
which names who takes part, what in this guide specifies it, and the policy
question it raises.

<div class="stu-note" markdown="1">
**Every person in this story, and both countries, are fictional.** Kamal comes
from **Onesa** (code `XXK`) and goes on pilgrimage in **Taifafeki** (code `XXR`): two
fictional countries shared with the [SMART Trust demo](https://github.com/litlfred/smart-trust-demo/tree/main/scenarios/countries),
whose codes are ISO 3166-1 user-assigned codes, so they never name a real country.
The steps follow this guide's real
[Malaysian reference implementation](reference-implementations-malaysia.html),
Malaysia's Hajj Health Card, as a policy precedent.
</div>

<div style="width:100%" markdown="0">{% lang-fragment workflow-figure.html %}</div>

Each numbered flow in the figure names its moment above, and each moment has its own [ArchiMate view](en/smart-ips-pilgrimage/archimate/2.1.0/view/the-pilgrims-journey/).

### The people

| Person | Who they are | Generic persona |
|---|---|---|
| **Kamal** | 61, from Tanavu, Onesa, going on pilgrimage for the first time. Has type 2 diabetes and high blood pressure; takes insulin and two tablets a day; allergic to penicillin. Carries one phone. | [Pilgrim](personas.html) |
| **Salmah** | Kamal's wife, travelling with him. Speaks for him when he cannot. | Accompanying family member (not yet a persona here) |
| **Dr Aisyah** | General practitioner in Tanavu, empanelled by the national pilgrimage authority for pre-pilgrimage health examinations. | [Counsellor](personas.html) |
| **Dr Hafiz** | Doctor of the Onesan pilgrimage medical team, travelling with the pilgrims. | [Accompanying Clinician from Origin Country](personas.html) |
| **Nurse Reem** | Registration nurse at a pilgrimage health facility in Nalemi. | [Host Country Health Worker](personas.html) |
| **Dr Faisal** | Emergency physician at the same facility. | [Host Country Health Worker](personas.html) |

And the systems: Kamal's **national health wallet** ([Origin Country Wallet](system-actors.html#ochw)),
Onesa's **health information exchange** ([Origin Country HIE](system-actors.html#ochie)),
the facility's **EMR** ([Host Country EMR](system-actors.html#hcemr)), and **WHO GDHCN**,
the trust network both countries take part in.

### What the story shows the guide still needs

1. Business processes for P0 (keys and terminologies), P2 (assembling the IPS) and P6 (break the glass).
2. The two pilgrim forms named in P1, and a page for the pilgrim and counsellor actors: their actor files exist but no page includes them.
3. One passcode policy (P4), stated once.
4. An account of access back to the home country (P5, P7), and of language (P5).
5. Example patients that are pilgrims: today's examples are a resident of the Netherlands.
6. The data dictionary, decision logic, indicators and functional requirements, which are still placeholders.

### Summary 

This implementation guide includes a machine-readable representation of WHO guidelines for verifiable IPS during pilgrimage. It explicitly encodes computer-interoperable logic, including data models, terminologies, and logic expressions, in a computable language to support implementation of IPS during pilgrimage usage scenario.  This Implementation Guide leverages the <a href="https://www.who.int/initiatives/global-digital-health-certification-network">WHO Global Digital Health Certification Network (GDHCN)</a>.


The guide is part of the <a href="https://www.who.int/teams/digital-health-and-innovation/smart-guidelines">WHO SMART Guidelines approach</a> to support countries to integrate WHO global health and data recommendations into digital systems accurately and consistently. It defines a series of FHIR Resources, Profiles, Extensions, and Terminology.

Supporting guidance, recommendations, resources, and standards are included in the <a href="en/folio-assistant-core/bibliography/">Bibliography</a> and <a href="dependencies.html">Dependencies</a>.

Eligible Participants may request to join through the <a href ="Letter_of_Application_IPS_Pilgrimage_1.0.docx">The Letter of Application</a>
<br/>

### About this implementation guide

This implementation guide is broken into the following levels of [knowledge representation](https://hl7.org/fhir/uv/cpg/documentation-approach-06-01-levels-of-knowledge-representation.html):
- <a href="index.html">Home</a> - contains references to the guidance, guidelines, policies and recommendations underpinning this implementation guide.
- <a href="business-requirements.html">Business Requirements</a> - contains the requirements for this implementation guide including the definition of key concepts, use cases, and a data dictionary.       
- <a href="data-models-and-exchange.html">Data Models and Exchange</a> - contains the data models and data exchange protocols with actors and transactions defined.
- <a href="deployment.html">Deployment Guidance </a> - contains relevant technical specifications and guidance, testing resources, reference implementation materials, and supporting guidance for adaptation to local contexts.

This guide assumes use of the following resources: 
* [MHD Folder](https://profiles.ihe.net/ITI/MHD/StructureDefinition-IHE.MHD.Minimal.Folder.html)
* [IPS Patient](http://hl7.org/fhir/uv/ips/StructureDefinition/Patient-uv-ips)
* [IPS Immunization](http://hl7.org/fhir/uv/ips/StructureDefinition/Immunization-uv-ips)
* [CPG ActivityDefinitions](https://hl7.org/fhir/uv/cpg/artifacts.html#activitydefinition-index)

- For a complete listing of the artifacts defined in this implementation guide, refer to the [Artifact Index](artifacts.html).
- A complete offline copy of this implementation guide can be found on the [Downloads](downloads.html) page.
- This guide utilizes the [International Patient Summary(IPS)](https://hl7.org/fhir/uv/ips/) as a base for defining immunizations and expects that most data captured will be presented in conformance with the resources defined as part of that implementation guide. 
- This Implementation Guide makes use of [Clinical Quality Language](https://cql.hl7.org/) for the decision support artifacts including the PlanDefinitions and Measures. They are used to express how a calculation should occur and can be used with a CQL engine in order to process the decision or indicator directly from the applicable FHIR resources. Links to this specification, the FHIR Clinical Practice Guidelines Specification, and other helpful resources can be found in the Support dropdown.


<br/>
### Disclaimer
The specification herewith documented is a demo working specification and may not be used for any implementation purposes. This draft is provided without warranty of completeness or consistency and the official publication supersedes this draft. No liability can be inferred from the use or misuse of this specification or its consequences.

### IP statements
{% include ip-statements.xhtml %}

### Cross-version analysis
{% include cross-version-analysis.xhtml %}

### Dependencies
{% include dependency-table.xhtml %}

## Globals
{% include globals-table.xhtml %}