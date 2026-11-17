Feature: View IPS content

# A person checks the rendered narrative against the IPS JSON; nothing automates it.
@manual
Scenario: View IPS content
GIVEN retrieved IPS content validated successfully
THEN the IPS narrative is rendered using tags provided in the JSON