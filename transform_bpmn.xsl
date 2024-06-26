<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
		xmlns="http://hl7.org/fhir"
		xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
		xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"
		xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"
		xmlns:zeebe="http://camunda.org/schema/zeebe/1.0"
		xmlns:xalan="http://xml.apache.org/xslt"  
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:variable name="collab" select="/bpmn:definitions/bpmn:collaboration[1]"/>
  <xsl:variable name="ig-slug" select="$collab/bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-slug'][1]/@value"/>
  <xsl:variable name="ig-base-url" select="$collab/bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-base-url'][1]/@value"/>
  <xsl:variable name="ig-name" select="$collab/bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-name'][1]/@value"/>
  <xsl:variable name="ig-version" select="$collab/bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-version'][1]/@value"/>
  <xsl:variable name="ig-publisher" select="$collab/bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-publisher'][1]/@value"/>


  <xsl:variable
      name="processes"
      select="/bpmn:definitions/bpmn:process[bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value != ''] "
      />

  
  <xsl:variable
      name="actors"
      select="$processes//bpmn:lane[
	      bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value != ''
	      and bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-actor-type']/@value != ''
	      ]"/>

  <xsl:variable
      name="innerActors"
      select="$actors[not(child::bpmn:childLaneSet)]"/>  

  <xsl:key
      name="indexActorCode"
      match="bpmn:lane[not(child::bpmn:childLaneSet)]"
      use="bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value"/> 
  <xsl:variable
      name="uniqueActors"
      select="$innerActors[not(child::bpmn:childLaneSet)][ count(. | key('indexActorCode',bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)[1]) = 1]"/>  


  <xsl:variable
      name="arrows"
      select="/bpmn:definitions/bpmn:process/bpmn:sequenceFlow[bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value != '']"/>
  
  <xsl:key
      name="indexArrowCode"
      match="bpmn:sequenceFlow"
      use="bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value"/>
  <xsl:variable
      name="uniqueArrows"
      select="$arrows[ count(. | key('indexArrowCode',bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)[1]) = 1]"/>  



  <xsl:variable
      name="questionnaires"
      select="/bpmn:definitions/bpmn:process/bpmn:userTask[bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value != '']"/>
  
  <xsl:key
      name="indexQuestCode"
      match="bpmn:userTask"
      use="bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value"/>
  <xsl:variable
      name="uniqueQuestionnaires"
      select="$questionnaires[ count(. | key('indexArrowCode',bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)[1]) = 1]"/>  





  <xsl:variable name="ig-url" select="concat($ig-base-url,$ig-slug)"/>

  <xsl:variable name="trans-CS-id" select="'bp-transactions'"/>
  <xsl:variable name="actors-CS-id" select="'bp-actors'"/>
  <xsl:variable name="quest-CS-id" select="'bp-user-tasks'"/>
  <xsl:variable name="trans-CS-url" select="concat($ig-url,'/CodeSystem/',$trans-CS-id)"/>
  <xsl:variable name="actors-CS-url" select="concat($ig-url,'/CodeSystem/',$actors-CS-id)"/>
  <xsl:variable name="quest-CS-url" select="concat($ig-url,'/CodeSystem/',$quest-CS-id)"/>

  <xsl:variable name="trans-VS-id" select="'bp-transactions'"/>
  <xsl:variable name="actors-VS-id" select="'bp-actors'"/>
  <xsl:variable name="quest-VS-id" select="'bp-user-tasks'"/>
  <xsl:variable name="trans-VS-url" select="concat($ig-url,'/ValueSet/',$trans-VS-id)"/>
  <xsl:variable name="actors-VS-url" select="concat($ig-url,'/ValueSet/',$actors-VS-id)"/>
  <xsl:variable name="quest-VS-url" select="concat($ig-url,'/ValueSet/',$quest-VS-id)"/>
  


  
  <xsl:template match="/bpmn:definitions">
    <xsl:message>#!/bin/bash</xsl:message>
    
    <xsl:message>
#
# Bash script to create auto generated page content
#
# IG Slug: (<xsl:value-of select="$ig-slug"/>)
# IG Base URL: (<xsl:value-of select="$ig-base-url"/>)
# IG Publisher: (<xsl:value-of select="$ig-publisher"/>)
# IG Version: (<xsl:value-of select="$ig-version"/>)
#
#
#clean out the actor and transactions pages
cat &lt;&lt; EOF > input/pagecontent/transactions.md
These are the transactions for <b><xsl:value-of select="$ig-slug"/></b>
EOF

cat &lt;&lt; EOF > input/pagecontent/actors.md
These are the actors for <b><xsl:value-of select="$ig-slug"/></b>
EOF
      </xsl:message>    
      

    <xsl:message># Found Actors:</xsl:message>
    <xsl:for-each select="$actors"><xsl:message><xsl:value-of select="concat('#   actor code: ', bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)"/></xsl:message></xsl:for-each>

    <xsl:message># Found Inner Actors (no child lanes):</xsl:message>
    <xsl:for-each select="$innerActors"><xsl:message><xsl:value-of select="concat('#   actor code: ', bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)"/></xsl:message></xsl:for-each>

    <xsl:message># Found Unique Actors (no child lanes):</xsl:message>
    <xsl:for-each select="$uniqueActors"><xsl:message><xsl:value-of select="concat('#   actor code: ', bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)"/></xsl:message></xsl:for-each>



    <xsl:message># Found Transactions:</xsl:message>
    <xsl:for-each select="$arrows"><xsl:message><xsl:value-of select="concat('#   transaction code: ', bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)"/></xsl:message></xsl:for-each>

    <xsl:message># Found Unique Transactions:</xsl:message>
    <xsl:for-each select="$uniqueArrows"><xsl:message><xsl:value-of select="concat('#   transaction code: ', bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)"/></xsl:message></xsl:for-each>


    <xsl:message># Found User Tasks:</xsl:message>
    <xsl:for-each select="$questionnaires"><xsl:message><xsl:value-of select="concat('#   questionniare code: ', bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)"/></xsl:message></xsl:for-each>

    <xsl:message># Found Unique User Tasks:</xsl:message>
    <xsl:for-each select="$uniqueQuestionnaires"><xsl:message><xsl:value-of select="concat('#   questionniare code: ', bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value)"/></xsl:message></xsl:for-each>

    

    <!-- we will use xsl:message to generate a shell script to create page content -->
    <!-- just throwing everything in a bundle so we can validate easily. really each should ouput to own file under input/resources -->
    <Bundle>


    
      <xsl:message># Looking at actors</xsl:message>

      <entry>
	<resource>
	  <CodeSystem>
	    <id><xsl:value-of select="$actors-CS-id"/></id>
	    <url><xsl:value-of select="$actors-CS-url"/></url>
	    <version><xsl:value-of select="$ig-version"/></version>
	    <publisher><xsl:value-of select="$ig-publisher"/></publisher>
	    <description><xsl:attribute name="value">Actors for <xsl:value-of select="$ig-name"/></xsl:attribute></description>	    
	    <description value="Actors"/>
	    <xsl:for-each select="$uniqueActors">
	      <xsl:variable name="actorCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value[1]"/>
	      <xsl:variable name="actorName" select="@name"/>
	      <xsl:variable name="actorDescription" select="bpmn:documentation/text()"/>
	      <concept>
		<code><xsl:attribute name="value"><xsl:value-of select="$actorCode"/></xsl:attribute></code>
		<display><xsl:attribute name="value"><xsl:value-of select="$actorName"/></xsl:attribute></display>
		<definition><xsl:attribute name="value"><xsl:value-of select="$actorDescription"/></xsl:attribute></definition>
	      </concept>
	    </xsl:for-each>		
	  </CodeSystem>
	</resource>
      </entry>

      <entry>
	<resource>
	  <ValueSet>
	    <id><xsl:value-of select="$actors-CS-id"/></id>
	    <version><xsl:value-of select="$ig-version"/></version>
	    <publisher><xsl:value-of select="$ig-publisher"/></publisher>
	    <description><xsl:attribute name="value">Actors for <xsl:value-of select="$ig-name"/></xsl:attribute></description>
	    <compose>
	      <include>
		<system><xsl:attribute name="value"><xsl:value-of select="$actors-CS-url"/></xsl:attribute></system>
	      </include>
	    </compose>
	  </ValueSet>
	</resource>
      </entry>


      <entry>
	<resource>
	  <CodeSystem>
	    <id><xsl:value-of select="$trans-CS-id"/></id>
	    <url><xsl:value-of select="$trans-CS-url"/></url>
	    <version><xsl:value-of select="$ig-version"/></version>
	    <publisher><xsl:value-of select="$ig-publisher"/></publisher>
	    <description><xsl:attribute name="value">Transactions for <xsl:value-of select="$ig-name"/></xsl:attribute></description>
	    <xsl:for-each select="$uniqueArrows">
	      <xsl:variable name="transCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value[1]"/>
	      <xsl:variable name="transName" select="@name"/>
	      <xsl:variable name="transDescription" select="bpmn:documentation/text()"/>
	      <concept>
		<code><xsl:attribute name="value"><xsl:value-of select="$transCode"/></xsl:attribute></code>
		<display><xsl:attribute name="value"><xsl:value-of select="$transName"/></xsl:attribute></display>
		<definition><xsl:attribute name="value"><xsl:value-of select="$transDescription"/></xsl:attribute></definition>
	      </concept>
	    </xsl:for-each>		
	  </CodeSystem>
	</resource>
      </entry>

      <xsl:for-each select="$uniqueActors">
	<xsl:variable name="actor" select="."/>
	<xsl:variable name="actorCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name = 'ig-code']/@value[1]"/>
	<xsl:variable name="actorName" select="@name"/>
	<xsl:variable name="actorDescription" select="bpmn:documentation/text()"/>
	<xsl:variable name="actorType" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-actor-type'][1]/@value"/>
	<xsl:variable name="actor-page-slug">actor-<xsl:value-of select="$actorCode"/></xsl:variable>
	
	<xsl:message>
# Unique actor: <xsl:value-of select="$actorName"/>
#  Found actorType (<xsl:value-of select="$actorType"/>) for role (<xsl:value-of select="$actorName"/>) with code (<xsl:value-of select="$actorCode"/>) 

touch input/pagecontent/<xsl:value-of select="$actor-page-slug"/>.md 

cat &lt;&lt; EOF >> input/pagecontent/actors.md
###  <xsl:value-of select="$actorName"/> {#<xsl:value-of select="$actorCode"/>}
Type: (<xsl:value-of select="$actorType"/>)


Description: <xsl:value-of select="$actorDescription"/>
{% include <xsl:value-of select="$actor-page-slug"/>.md %}
	</xsl:message>


	<xsl:message>

The <xsl:value-of select="$actorName"/> actor participates in the following transactions as a source:</xsl:message>	    
	<xsl:for-each select="$collab/bpmn:participant">
	  <xsl:variable name="processId" select="@processRef"/>
	  <xsl:variable name="process"  select="$processes[@id = $processId]"/>
	  <xsl:for-each select="$actor/bpmn:flowNodeRef">  <!-- this is a task ID.  we want check it is under actor's lane-->
	    <xsl:variable name="arrowSrc" select="."/>
	    <xsl:for-each select="($process/bpmn:sendTask)[@id = $arrowSrc]">
	      <xsl:for-each select="$arrows[@sourceRef = $arrowSrc]">
		<xsl:variable name="trans-name" select="@name"/>
		<xsl:variable
		    name="trans-code"
		    select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
		<xsl:message>-  Transaction: &lt;a href="transaction-<xsl:value-of select="$trans-code"/>.hmtl"><xsl:value-of select="$trans-name"/> (<xsl:value-of select="$trans-code"/>)&lt;/a> </xsl:message>
	      </xsl:for-each>
	    </xsl:for-each>
	    <xsl:message/>
	  </xsl:for-each>
	</xsl:for-each>

	<xsl:message>

The <xsl:value-of select="$actorName"/> actor participates in the following transactions as a target:</xsl:message>

	<xsl:for-each select="$collab/bpmn:participant">
	  <xsl:variable name="processId" select="@processRef"/>
	  <xsl:variable name="process"  select="$processes[@id = $processId]"/>
	  <xsl:for-each select="$actor/bpmn:flowNodeRef">  <!-- this is a task ID.  we want check it is under actor's lane-->
	    <xsl:variable name="arrowSrc" select="."/>
	    <xsl:for-each select="($process/bpmn:receiveTask)[@id = $arrowSrc]">
	      <xsl:for-each select="$arrows[@sourceRef = $arrowSrc]">
		<xsl:variable name="trans-name" select="@name"/>
		<xsl:variable
		    name="trans-code"
		    select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
		<xsl:message>-  Transaction: &lt;a href="transaction-<xsl:value-of select="$trans-code"/>.html"><xsl:value-of select="$trans-name"/> (<xsl:value-of select="$trans-code"/>)&lt;/a> </xsl:message>
	      </xsl:for-each>
	    </xsl:for-each>
	    <xsl:message/>
	  </xsl:for-each>
	</xsl:for-each>
	

	<xsl:message>

The <xsl:value-of select="$actorName"/> actor participates in the following questionniares:</xsl:message>


	<xsl:for-each select="$collab/bpmn:participant">
	  <xsl:variable name="processId" select="@processRef"/>
	  <xsl:variable name="process"  select="$processes[@id = $processId]"/>
	  <xsl:for-each select="$actor/bpmn:flowNodeRef">  <!-- this is a task ID.  we want check it is under actor's lane-->
	    <xsl:variable name="arrowSrc" select="."/>


	    <xsl:for-each select="($process/bpmn:userTask)[@id = $arrowSrc]">
	      <xsl:variable
		  name="task-code"
		  select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
	      <xsl:variable name="task-name" select="@name"/>
	      <xsl:message>-  Questionnaire: &lt;a href="Questionnaire-<xsl:value-of select="$task-code"/>.html"><xsl:value-of select="$task-name"/> (<xsl:value-of select="$task-code"/>)&lt;/a> </xsl:message>
	      
	    </xsl:for-each>
	  </xsl:for-each>
	</xsl:for-each>
	<xsl:message>
EOF
	</xsl:message>

	  <entry>

	    
	    <resource>
	      <ActorDefinition >
		<id>
		  <xsl:attribute name="value"><xsl:value-of select="$actorCode"/></xsl:attribute> 
		</id>
		<version><xsl:value-of select="$ig-version"/></version>
		<publisher><xsl:value-of select="$ig-publisher"/></publisher>
		<meta>
		  <xsl:choose>
		    <xsl:when test="$actorType!= 'system'">
		      <profile value="http://smart.who.int/base/StructureDefinition/SGPersona"/>
		    </xsl:when>
		    <xsl:otherwise>
		      <profile value="http://smart.who.int/base/StructureDefinition/SGActor"/>
		    </xsl:otherwise>
		  </xsl:choose>
		</meta>
		<type><xsl:attribute name="value"><xsl:value-of select="$actorType"/></xsl:attribute></type>
		<extension url="http://smart.who.int/base/StructureDefinition/Sgcode">
		  <valueCoding>
		    <system><xsl:attribute name="value"><xsl:value-of select="$actors-CS-url"/></xsl:attribute></system>
		    <code><xsl:attribute name="value"><xsl:value-of select="$actorCode"/></xsl:attribute></code>
		  </valueCoding>
		</extension>
		<identifier>
		  <value><xsl:attribute name="value"><xsl:value-of select="$actorCode"/></xsl:attribute></value>
		</identifier>
		<name><xsl:attribute name="value"><xsl:value-of select="$actorName"/></xsl:attribute></name>
		<title><xsl:attribute name="value"><xsl:value-of select="$actorName"/></xsl:attribute></title>
		<status value="draft"/>
		<experimental value="false"/>
		<description><xsl:attribute name="value">
		  <xsl:value-of select="$actorDescription"/>
		  <p>
		    More details of this transaction may be found on the 
		    <a><xsl:attribute name="href">actors.html#<xsl:value-of select="$actorCode"/></xsl:attribute></a>
		    page.
		  </p>
		</xsl:attribute>
		</description>
	      </ActorDefinition>
	    </resource>
	  </entry>
	</xsl:for-each>

	
	<xsl:for-each select="$collab/bpmn:participant">
	  <!-- loop through all the process named in the collaboration and create a graph for each -->
	  <xsl:variable name="processId" select="@processRef"/>
	  <xsl:message># Processing collab process: <xsl:value-of select="$processId"/></xsl:message>




	  <xsl:for-each select="$processes[@id = $processId]">
	    <xsl:variable name="processName" select="@name"/>
	    <xsl:variable name="processCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
	    <xsl:variable name="processDesc" select="bpmn:documentation/text()"/>
	    <xsl:variable name="processActors" select=".//bpmn:lane"/>
	    <xsl:variable name="userTasks" select="bpmn:userTask[bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code']/@value != '']"/>
	    <xsl:variable name="rules" select="bpmn:businessRuleTask[bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code']/@value != '']"/>
	    <xsl:variable name="sendTasks" select="bpmn:sendTask[bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code']/@value != '']"/>
	    <xsl:variable name="receiveTasks" select="bpmn:receiveTask"/>
	    <xsl:variable name="processArrows" select="bpmn:sequenceFlow[bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code']/@value != '']"/>
	    
	    <xsl:message># Check process: (<xsl:value-of select="$processName"/>) - (<xsl:value-of select="$processId"/>)</xsl:message>
	    <!-- loop through the userTasks and stub out a SGQuestionnaire profile and associated activityDef'n (maybe) -->
	    <xsl:for-each select="$userTasks">
	      <xsl:variable name="taskId" select="@id"/>
	      <xsl:variable name="taskName" select="@name"/>
	      <xsl:variable name="taskCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
	      <xsl:variable name="formId" select="bpmn:extensionElements/zeebe:formDefinition/@formId"/>
	      <xsl:variable name="qId" select="concat('SGQuestionaire-',$taskCode)"/>
	      
	      <StructureDefinition>
		<id><xsl:attribute name="value"><xsl:value-of select="$taskCode"/></xsl:attribute></id>
		<version><xsl:value-of select="$ig-version"/></version>
		<publisher><xsl:value-of select="$ig-publisher"/></publisher>
		<extension url="http://hl7.org/fhir/StructureDefinition/structuredefinition-implements">
		  <valueUri value="http://hl7.org/fhir/StructureDefinition/CanonicalResource"/>
		</extension>
		<url><xsl:attribute name="value"><xsl:value-of select="concat($ig-url,'/StructureDefinition/',$qId)"/></xsl:attribute></url>
		<version><xsl:attribute name="value"><xsl:value-of select="$ig-version"/></xsl:attribute></version>
		<name><xsl:attribute name="value"><xsl:value-of select="$qId"/></xsl:attribute></name>
		<status value="draft"/>
		<publisher><xsl:attribute name="value"><xsl:value-of select="$ig-publisher"/></xsl:attribute></publisher>
		<name><xsl:value-of select="$taskName"/></name>
		<baseDefinition value="http://smart.who.int/base/StructureDefinition/SGGraphDefinition"/>
		<derivation value="constraint"/>
		<differential>
		  <element id="Questionnaire">
		    <path value="Questionnaire"/>
		  </element>
		  <element id="Questionnaire.name">
		    <path value="Questionnaire.name"/>
		    <patternCode><xsl:attribute name="value"><xsl:value-of select="$taskName"/></xsl:attribute></patternCode>
		  </element>
		  <element id="Questionnaire.code">
		    <path value="Questionnaire.code"/>
		    <patternCoding>
		      <xsl:attribute name="code"><xsl:value-of select="$taskCode"/></xsl:attribute>
		      <xsl:attribute name="system"><xsl:value-of select="$quest-CS-url"/></xsl:attribute>
		    </patternCoding>
		  </element>
		</differential>
	      </StructureDefinition>
	    </xsl:for-each>
	    

	    <!-- loop through arrows looking for sendTask receiveTask pairs to use for SGtransactions a-->
	    <xsl:for-each select="$processArrows">

	      <xsl:variable name="linkSrc" select="@sourceRef"/>
	      <xsl:variable name="linkTgt" select="@targetRef"/>
	      <xsl:variable name="linkId" select="@id"/>
	      <xsl:variable name="linkCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
	      <xsl:variable name="linkName" select="@name"/>
	      <xsl:variable name="linkDesc" select="bpmn:documentation/text()"/>
	      <!--
		  <xsl:variable name="linkTE" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='triggerEvents'][1]/@value"/>	    	 
		  <xsl:variable name="linkMS" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='messageSemantics'][1]/@value"/>
		  <xsl:variable name="linkEA" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='expectedActions'][1]/@value"/>
	      -->

              
              
	      <!--only want to create a transaction between bpmn:sendTask and bpmn:receiveTask sequenceFlows -->
	      <xsl:for-each  select="$sendTasks[@id=$linkSrc]">
		<xsl:variable name="sendTask" select="."/>
		<xsl:for-each select="$receiveTasks[@id=$linkTgt]">
		  <xsl:variable name="receiveTask" select="."/>
		  <xsl:message># Send/Receive task pairs: (<xsl:value-of select="$sendTask/@id"/>)->(<xsl:value-of select="$receiveTask/@id"/>) </xsl:message>
		  <xsl:message># Send/Receive task pairs: (<xsl:value-of select="$linkSrc"/>)->(<xsl:value-of select="$linkTgt"/>) </xsl:message>
		  <!-- now we know the source(send) and target(receive) tasks.  we now need to get the lane that they are in -->
		  <xsl:for-each  select="$innerActors">
		    <xsl:message># Checking if <xsl:value-of select="./bpmn:flowNodeRef"/> = <xsl:value-of select="$linkSrc"/></xsl:message>
		  </xsl:for-each>
		  <xsl:for-each  select="$innerActors[./bpmn:flowNodeRef = $linkSrc][1]">
		    <xsl:variable name="actorSrc" select="."/>
		    <xsl:variable name="actorSrcId" select="$actorSrc/@id"/>
		    <xsl:variable name="actorSrcCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
		    <xsl:variable name="actorSrcDesc" select="bpmn:documentation/text()"/>
		    
		    <xsl:message># Got source actor: <xsl:value-of select="$actorSrcId"/></xsl:message>
		    <xsl:for-each  select="$innerActors[./bpmn:flowNodeRef = $linkTgt][1]">
		      <xsl:variable name="actorTgt" select="."/>
		      <xsl:variable name="actorTgtId" select="$actorTgt/@id"/>
		      <xsl:variable name="actorTgtCode" select="bpmn:extensionElements/zeebe:properties/zeebe:property[@name='ig-code'][1]/@value"/>
		      <xsl:variable name="actorTgtDesc" select="bpmn:documentation/text()"/>
		      
		      <xsl:message># Got target actor: <xsl:value-of select="$actorTgtId"/></xsl:message>
		      <entry>

			<resource>
			  <GraphDefinition>
			    <id><xsl:attribute name="value"><xsl:value-of select="$linkCode"/></xsl:attribute></id>
			    <version><xsl:value-of select="$ig-version"/></version>
			    <publisher><xsl:value-of select="$ig-publisher"/></publisher>
			    
			    <meta>
	      		      <profile value="http://smart.who.int/base/StructureDefinition/SGTransaction"/>
			    </meta>
			    
			    <name><xsl:attribute name="value"><xsl:value-of select="$linkName"/></xsl:attribute></name>
			    <description>
			      <xsl:attribute name="value">
				<xsl:value-of select="$linkDesc"/>
				<p>
				  More details of this transaction may be found on the 
				  <a><xsl:attribute name="href">transactions.html#<xsl:value-of select="$linkCode"/></xsl:attribute></a>
				  page.
				</p>
			      </xsl:attribute>
			    </description>
			    <status value="active"/>

			    <xsl:variable name="link-page-slug">transaction-<xsl:value-of select="$linkCode"/></xsl:variable>
			    <xsl:message>
#
# Creating tranasaction page slugs for <xsl:value-of select="$linkCode"/>}
#
touch input/pagecontent/<xsl:value-of select="$link-page-slug"/>-preamble.md 
touch input/pagecontent/<xsl:value-of select="$link-page-slug"/>-trigger-events.md 
touch input/pagecontent/<xsl:value-of select="$link-page-slug"/>-message-semantics.md 
touch input/pagecontent/<xsl:value-of select="$link-page-slug"/>-expected-actions-semantics.md 

cat &lt;&lt; EOF >> input/pagecontent/transactions.md
###  <xsl:value-of select="$linkName"/> {#<xsl:value-of select="$linkCode"/>}

(<xsl:value-of select="$linkName"/>)
<xsl:value-of select="$linkDesc"/>

{% include <xsl:value-of select="$link-page-slug"/>-preamble.md %}
#### Trigger Events
{% include <xsl:value-of select="$link-page-slug"/>-trigger-events.md %}
#### Message Semantics
{% include <xsl:value-of select="$link-page-slug"/>-message-semantics.md %}
#### Expected Actions
{% include <xsl:value-of select="$link-page-slug"/>-expected-actions-semantics.md %}

EOF

			    </xsl:message>


			  
			    <experimental value="false"/>
			    <node>
			      <nodeId><xsl:value-of select="$actorSrcCode"/></nodeId>
			      <type>ActorDefinition</type>
			      <extension url="http://smart.who.int/base/StructureDefinition/Sgactor">
				<valueCoding>
				  <system><xsl:attribute name="value"><xsl:value-of select="$actors-CS-url"/></xsl:attribute></system>
				  <code><xsl:attribute name="value"><xsl:value-of select="$actorSrcCode"/></xsl:attribute></code>
				</valueCoding>
			      </extension>
			    </node>
			    <node>
			      <nodeId><xsl:value-of select="$actorTgtCode"/></nodeId>
			      <type>ActorDefinition</type>
			      <extension url="http://smart.who.int/base/StructureDefinition/Sgactor">
				<valueCoding>
				  <system><xsl:attribute name="value"><xsl:value-of select="$actors-CS-url"/></xsl:attribute></system>
				  <code><xsl:attribute name="value"><xsl:value-of select="$actorTgtCode"/></xsl:attribute></code>
				</valueCoding>
			      </extension>
			    </node>

			    <link>
			      <sourceId><xsl:value-of select="$actorSrcCode"/></sourceId>
			      <targetId><xsl:value-of select="$actorTgtCode"/></targetId>

			      <extension url="http://smart.who.int/base/StructureDefinition/Sgcode">
				<valueCoding>
				  <system><xsl:attribute name="value"><xsl:value-of select="$trans-CS-url"/></xsl:attribute></system>
				  <code><xsl:attribute name="value"><xsl:value-of select="$linkCode"/></xsl:attribute></code>
				</valueCoding>
			      </extension>
			      <!-- <extension url="http://smart.who.int/base/StructureDefinition/Markdown"> -->
			      <!--   <valueMarkdown><xsl:attribute name="value"><xsl:value-of select="$linkTE"/></xsl:attribute></valueMarkdown> -->
			      <!-- </extension> -->
			      <!-- <extension url="http://smart.who.int/base/StructureDefinition/Markdown"> -->
			      <!--   <valueMarkdown><xsl:attribute name="value"><xsl:value-of select="$linkMS"/></xsl:attribute></valueMarkdown> -->
			      <!-- </extension> -->
			      <!-- <extension url="http://smart.who.int/base/StructureDefinition/Markdown"> -->
			      <!--   <valueMarkdown><xsl:attribute name="value"><xsl:value-of select="$linkEA"/></xsl:attribute></valueMarkdown> -->
			      <!-- </extension>		   -->
			    </link>
			  </GraphDefinition>
			</resource>
		      </entry>
		    </xsl:for-each>
		  </xsl:for-each>
		</xsl:for-each>
	      </xsl:for-each>
	    </xsl:for-each>
	  </xsl:for-each>
	  <!-- <Html> -->
	  <!--   <body> -->
	  <!-- 	<h2>My CD Collection</h2> -->
	  <!-- 	<table border="1"> -->
	  <!-- 	  <tr bgcolor="#9acd32"> -->
	  <!--         <th>Title</th> -->
	  <!--         <th>Artist</th> -->
	  <!-- 	  </tr> -->
	  <!-- 	  <xsl:for-each select="catalog/cd"> -->
	  <!-- 	    <tr> -->
	  <!--           <td><xsl:value-of select="title" /></td> -->
	  <!--           <td><xsl:value-of select="artist" /></td> -->
	  <!-- 	    </tr> -->
	  <!-- 	  </xsl:for-each> -->
	  <!-- 	</table> -->
	  <!--   </body> -->
	  <!-- </html> -->
	</xsl:for-each>

    </Bundle>
    
  </xsl:template>

  
  <!-- pretty print output -->
  <xsl:output method="xml" encoding="UTF-8" indent="yes" xalan:indent-amount="2"/>
  <xsl:strip-space elements="*"/>
  
  <xsl:template match="*">
    <xsl:copy>
      <xsl:copy-of select="@*" />
      <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
