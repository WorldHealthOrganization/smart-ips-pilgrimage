#!/bin/bash

#
# Bash script to create auto generated page content
#
# IG Slug: ()
# IG Base URL: (http://smart.who.int/)
# IG Publisher: (WHO)
# IG Version: (1.1.4)
#
#
#clean out the actor and transactions pages
cat << EOF > input/pagecontent/transactions.md
These are the transactions for 
EOF

cat << EOF > input/pagecontent/actors.md
These are the actors for 
EOF
      
# Found Actors:
#   actor code: counselor
#   actor code: pilgrim
#   actor code: ochw
#   actor code: ochie
#   actor code: counselor
#   actor code: pilgrim
#   actor code: ochw
#   actor code: ochie
#   actor code: counselor
#   actor code: pilgrim
#   actor code: ochw
# Found Inner Actors (no child lanes):
#   actor code: counselor
#   actor code: pilgrim
#   actor code: ochw
#   actor code: ochie
#   actor code: counselor
#   actor code: pilgrim
#   actor code: ochw
#   actor code: ochie
#   actor code: counselor
#   actor code: pilgrim
#   actor code: ochw
# Found Unique Actors (no child lanes):
#   actor code: counselor
#   actor code: pilgrim
#   actor code: ochw
#   actor code: ochie
# Found Transactions:
#   transaction code: issue-shl
#   transaction code: shl-request
#   transaction code: record-consent-response
#   transaction code: record-consent-request
#   transaction code: issue-shl
#   transaction code: shl-request
# Found Unique Transactions:
#   transaction code: issue-shl
#   transaction code: shl-request
#   transaction code: record-consent-response
#   transaction code: record-consent-request
# Found User Tasks:
#   questionniare code: shl-configure-privacy-settings
#   questionniare code: consent-wallet-questionnaire
#   questionniare code: shl-configure-privacy-settings
#   questionniare code: shl-configure-privacy-settings
# Found Unique User Tasks:
#   questionniare code: shl-configure-privacy-settings
#   questionniare code: consent-wallet-questionnaire
#   questionniare code: shl-configure-privacy-settings
#   questionniare code: shl-configure-privacy-settings
# Looking at actors
# Unique actor: Counselor
# Processing collab process: health-check-wallet-consent-and-shl-issuance-2
runtime error: file transform_bpmn.xsl line 243 element value-of
Variable 'sourceRef' has not been declared.
XPath error : Undefined variable
runtime error: file transform_bpmn.xsl line 243 element value-of
XPath evaluation returned no result.

#  Found actorType (person) for role (Counselor) with code (counselor) 

touch input/pagecontent/actor-counselor.md 

cat << EOF >> input/pagecontent/actors.md
###  Counselor {#counselor}
Type: (person)


Description: Counselor from origin country supporting pilgrim during inital health screening
{% include actor-counselor.md %}


This actor participates in the following transactions as a source (
no result for input/business-processes/Health Check and Issue SHL.bpmn
