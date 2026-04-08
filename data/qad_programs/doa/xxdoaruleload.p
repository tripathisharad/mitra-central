/* PSC: xxdoaruleload.p - DOA Rule Upload Utility                       */
/*                                                                      */
/* CREATED: 19 Aug 2024   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

{us/mf/mfdtitle.i}
{us/gp/gpnbrgen.i}

DEFINE VARIABLE lvc_inpFile 			AS CHARACTER 	NO-UNDO VIEW-AS FILL-IN SIZE 40 BY 1 FORMAT "x(300)".
DEFINE VARIABLE lvc_outFile				AS CHARACTER 	NO-UNDO INITIAL "DOA_RuleUpload_Result.csv".
DEFINE VARIABLE lvc_msgfilename         AS CHARACTER	NO-UNDO INITIAL "MailBody.txt".
DEFINE VARIABLE lvl_iserror     		AS LOGICAL 		NO-UNDO.
DEFINE VARIABLE lvi_errorNum    		AS INTEGER 		NO-UNDO.
DEFINE VARIABLE lvc_rulecode    		AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_firstLine			AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_oscommand 			AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_EmailID				AS CHARACTER	NO-UNDO FORMAT "x(200)" VIEW-AS FILL-IN SIZE 40 BY 1.
DEFINE VARIABLE lvl_firstLine			AS LOGICAL 		NO-UNDO.
DEFINE VARIABLE lvl_dataAvailable       AS LOGICAL 		NO-UNDO.
DEFINE VARIABLE lvh_RuleImport			AS HANDLE       NO-UNDO.
DEFINE VARIABLE lvi_count 				AS INTEGER      NO-UNDO.

DEFINE TEMP-TABLE ttRuleImport
	   FIELD      ttRuleCode  			AS CHARACTER 
       FIELD      ttRuleType  			AS CHARACTER 
       FIELD      ttRuleBusinessLine    AS CHARACTER 
       FIELD      ttRuleSite       		AS CHARACTER 
	   FIELD      ttRuleActive       	AS CHARACTER 
	   FIELD      ttRuleCondition1     	AS CHARACTER
	   FIELD      ttRuleCondition2     	AS CHARACTER
	   FIELD      ttRuleCondition3     	AS CHARACTER
	   FIELD      ttRuleCondition4     	AS CHARACTER
	   FIELD      ttRuleCondition5     	AS CHARACTER
	   FIELD      ttRuleCondition6     	AS CHARACTER
	   FIELD      ttRuleCondition7     	AS CHARACTER
	   FIELD      ttRuleCondition8     	AS CHARACTER
	   FIELD      ttRuleCondition9     	AS CHARACTER
	   FIELD      ttRuleCondition10     AS CHARACTER
	   FIELD      ttRuleCondition11     AS CHARACTER
	   FIELD      ttRuleCondition12     AS CHARACTER
	   FIELD      ttRuleCondition13     AS CHARACTER
	   FIELD      ttRuleCondition14     AS CHARACTER
	   FIELD      ttRuleCondition15    	AS CHARACTER
	   FIELD      ttApprover1	    	AS CHARACTER
	   FIELD      ttApprover2	    	AS CHARACTER
	   FIELD      ttApprover3	    	AS CHARACTER
	   FIELD      ttApprover4	    	AS CHARACTER
	   FIELD      ttApprover5	    	AS CHARACTER
	   FIELD      ttApprover6	    	AS CHARACTER
	   FIELD      ttApprover7	    	AS CHARACTER
	   FIELD      ttApprover8	    	AS CHARACTER
	   FIELD      ttApprover9	    	AS CHARACTER
	   FIELD      ttApprover10	    	AS CHARACTER
	   FIELD      ttProcess 			AS LOGICAL
	   FIELD      ttError				AS CHARACTER
	   .
	   
ASSIGN lvh_RuleImport = BUFFER ttRuleImport:HANDLE.
	   
FUNCTION isRuleConditionValid RETURNS LOGICAL(INPUT lvc_RuleCondition AS CHARACTER):

	DEFINE VARIABLE lvc_operators AS CHARACTER NO-UNDO INITIAL "=,>,<,>=,<=,<>,MATCHES,BEGINS".
	DEFINE VARIABLE i 			  AS INTEGER   NO-UNDO.
	DEFINE VARIABLE lvl_valid     AS LOGICAL   NO-UNDO.

	ASSIGN lvl_valid = FALSE.
	
	loop1:
	DO i = 1 TO NUM-ENTRIES(lvc_operators,","):
		IF INDEX(lvc_RuleCondition,ENTRY(i,lvc_operators,",")) > 0 
		THEN DO:
			ASSIGN lvl_valid = TRUE.
			LEAVE loop1.
		END.
	END.
	
	RETURN lvl_valid.
	
END FUNCTION. /*isRuleConditionValid*/

FUNCTION getFormattedCondition RETURNS CHARACTER(INPUT lvc_RuleCondition AS CHARACTER):

	DEFINE VARIABLE lvc_operators 			AS CHARACTER 	NO-UNDO INITIAL ">=,<=,<>,=,>,<,MATCHES,BEGINS".
	DEFINE VARIABLE i 			  			AS INTEGER   	NO-UNDO.
	DEFINE VARIABLE lvc_FormattedCondition	AS CHARACTER	NO-UNDO.
	
	IF lvc_RuleCondition = "" 
	THEN DO:
		ASSIGN lvc_FormattedCondition = "".
	END.
	ELSE DO:
		loop1:
		DO i = 1 TO NUM-ENTRIES(lvc_operators,","):
			IF INDEX(lvc_RuleCondition,ENTRY(i,lvc_operators,",")) > 0 
			THEN DO:
				ASSIGN lvc_FormattedCondition = REPLACE(REPLACE(lvc_RuleCondition,ENTRY(i,lvc_operators,","),("|" + ENTRY(i,lvc_operators,",") + "|"))," ","").
				LEAVE loop1.
			END.
		END.
	END.
	
	RETURN lvc_FormattedCondition.
	
END FUNCTION. /*isRuleConditionValid*/
	   
FORM
   lvc_inpFile COLON 25 LABEL "Rule Import File(CSV)"
   lvc_EmailID COLON 25 LABEL "Email"
   WITH FRAME a
   SIDE-LABELS
   WIDTH 80.
   
setFrameLabels(FRAME a:HANDLE).

FIND FIRST usr_mstr WHERE usr_userid = global_userid NO-LOCK NO-ERROR.
IF AVAILABLE usr_mstr AND usr_mail_address <> "" 
THEN
	ASSIGN lvc_EmailID = usr_mail_address.
	   
mainloop:	   
REPEAT:
	ASSIGN lvc_inpFile = "".
	
	EMPTY TEMP-TABLE ttRuleImport.
	
	UPDATE 
		lvc_inpFile 
		lvc_EmailID
	WITH FRAME a.

	IF lvc_inpFile = "" 
	THEN DO:
		{us/bbi/pxmsg.i &MSGNUM=40 &ERRORLEVEL=3}
		UNDO mainloop, RETRY mainloop.
	END.
	
	IF SEARCH(lvc_inpFile) = ? 
	THEN DO:
		{us/bbi/pxmsg.i &MSGNUM=12007 &ERRORLEVEL=3}
		UNDO mainloop, RETRY mainloop.
	END.
	
	IF lvc_EmailID = "" 
	THEN DO:
		{us/bbi/pxmsg.i &MSGTEXT='"Email ID cannot be blank"' &ERRORLEVEL=3}
		UNDO mainloop, RETRY mainloop.
	END.
	
	FIND FIRST code_mstr 
		 WHERE code_domain  EQ global_domain  AND
			   code_fldname EQ "DOA_RULE"     AND
			   code_value   EQ "SEQUENCE_ID"
	NO-LOCK NO-ERROR.
	IF NOT AVAILABLE code_mstr 
	THEN DO:
		{us/bbi/pxmsg.i &MSGTEXT='"Please Maintain Rule Sequence in GCM"' &ERRORLEVEL=3}
		UNDO mainloop, RETRY mainloop.
	END.
	
	ASSIGN lvl_firstLine = YES.
	
	INPUT FROM VALUE(lvc_inpFile).
	REPEAT:
		IF lvl_firstLine = YES 
		THEN DO:
			IMPORT UNFORMATTED lvc_firstLine.
			ASSIGN lvl_firstLine = NO.
		END.
		ELSE DO:
			CREATE ttRuleImport.
			IMPORT DELIMITER "," ttRuleImport EXCEPT ttProcess ttError.
			
			ASSIGN ttProcess = YES.
		END.
	END.
	INPUT CLOSE.
	
	FOR EACH ttRuleImport:
		ASSIGN lvl_dataAvailable = NO.
		
		doloop1:
		DO lvi_count = 1 TO lvh_RuleImport:NUM-FIELDS:
			IF lvh_RuleImport:BUFFER-FIELD(lvi_count):NAME <> "ttProcess"
			THEN DO:
				IF lvh_RuleImport:BUFFER-FIELD(lvi_count):BUFFER-VALUE <> "" 
				THEN DO:
					ASSIGN lvl_dataAvailable = YES.
					LEAVE doloop1.
				END.
			END.
		END. /*doloop1*/
		
		IF lvl_dataAvailable = NO 
		THEN
			DELETE ttRuleImport.
	END. /*FOR EACH ttRuleImport*/
	
	IF NOT CAN-FIND(FIRST ttRuleImport) 
	THEN DO:
		{us/bbi/pxmsg.i &MSGTEXT='"No data to import"' &ERRORLEVEL=3}
		UNDO mainloop, RETRY mainloop.
	END.
	
	/*VALIDATE THE FILE DATA*/
	FOR EACH ttRuleImport:
		IF ttRuleCode <> "" 
		THEN DO:
			IF NOT CAN-FIND(FIRST xxdoarule_mstr
							WHERE xxdoarule_mstr.xxdoarule_domain = global_domain AND
								  xxdoarule_mstr.xxdoarule_code   = TRIM(ttRuleCode)) 
			THEN
				ASSIGN 
					ttProcess = NO
					ttError   = "DOA rule with rule code " + ttRuleCode + " not found".
		END.
		
		IF ttRuleType = "" 
		THEN DO:
			ASSIGN ttProcess = NO.
			
			IF ttError = "" 
			THEN
				ASSIGN ttError = "Rule Type cannot be blank".
			ELSE
				ASSIGN ttError = ttError + ", Rule Type cannot be blank".
		END.
		ELSE DO:
			IF NOT CAN-FIND(FIRST code_mstr
							WHERE code_domain 	EQ global_domain 	AND
								  code_fldname 	EQ "DOA_RULE_TYPE" 	AND
								  code_value   	EQ TRIM(ttRuleType))
			THEN DO:
				ASSIGN ttProcess = NO.
			
				IF ttError = "" 
				THEN
					ASSIGN ttError = "Rule Type not maintained in GCM. FieldName - DOA_RULE_TYPE".
				ELSE
					ASSIGN ttError = ttError + ", Rule Type not maintained in GCM. FieldName - DOA_RULE_TYPE".
			END.
		END.
		
		IF ttRuleCondition1 	= "" AND
		   ttRuleCondition2 	= "" AND
		   ttRuleCondition3 	= "" AND
		   ttRuleCondition4 	= "" AND
		   ttRuleCondition5 	= "" AND
		   ttRuleCondition6 	= "" AND
		   ttRuleCondition7 	= "" AND
		   ttRuleCondition8 	= "" AND
		   ttRuleCondition9 	= "" AND
		   ttRuleCondition10 	= "" AND
		   ttRuleCondition11 	= "" AND
		   ttRuleCondition12 	= "" AND
		   ttRuleCondition13 	= "" AND
		   ttRuleCondition14	= "" AND
		   ttRuleCondition15 	= ""
		THEN DO:
			ASSIGN ttProcess = NO.
			
			IF ttError = "" 
			THEN
				ASSIGN ttError = "Rule conditions not defined".
			ELSE
				ASSIGN ttError = ttError + ", Rule conditions not defined".
		END.
		
		IF (ttRuleCondition1 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition1)) 	OR
		   (ttRuleCondition2 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition2)) 	OR
		   (ttRuleCondition3 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition3)) 	OR
		   (ttRuleCondition4 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition4)) 	OR
		   (ttRuleCondition5 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition5)) 	OR
		   (ttRuleCondition6 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition6)) 	OR
		   (ttRuleCondition7 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition7)) 	OR
		   (ttRuleCondition8 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition8)) 	OR
		   (ttRuleCondition9 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition9)) 	OR
		   (ttRuleCondition10 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition10)) 	OR
		   (ttRuleCondition11 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition11)) 	OR
		   (ttRuleCondition12 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition12)) 	OR
		   (ttRuleCondition13 	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition13)) 	OR
		   (ttRuleCondition14	<> "" AND 	NOT isRuleConditionValid(ttRuleCondition14)) 	OR
		   (ttRuleCondition15 	<> "" AND  	NOT isRuleConditionValid(ttRuleCondition15))
		THEN DO:
			ASSIGN ttProcess = NO.
			
			IF ttError = "" 
			THEN
				ASSIGN ttError = "Rule conditions not defined correctly".
			ELSE
				ASSIGN ttError = ttError + ", Rule conditions not defined correctly".
		END.
		
		IF ttApprover1 		= "" AND 
		   ttApprover2 		= "" AND 
		   ttApprover3 		= "" AND 
		   ttApprover4 		= "" AND 
		   ttApprover5 		= "" AND 
		   ttApprover6 		= "" AND 
		   ttApprover7 		= "" AND 
		   ttApprover8 		= "" AND 
		   ttApprover9 		= "" AND 
		   ttApprover10 	= ""
		THEN DO:
			ASSIGN ttProcess = NO.
			
			IF ttError = "" 
			THEN
				ASSIGN ttError = "Rule approvers not defined".
			ELSE
				ASSIGN ttError = ttError + ", Rule approvers not defined".
		END.
	END.
	
	FOR EACH ttRuleImport
		WHERE ttProcess = YES:
		IF ttRuleCode <> "" 
		THEN DO:
			FOR EACH xxdoarule_mstr
				WHERE xxdoarule_domain = global_domain AND
					  xxdoarule_code   = TRIM(ttRuleCode)
				EXCLUSIVE-LOCK:
				ASSIGN 
					xxdoarule_type 				= TRIM(ttRuleType)
					xxdoarule_businessline 		= TRIM(ttRuleBusinessLine)
					xxdoarule_site 				= TRIM(ttRuleSite)
					xxdoarule_active 			= IF TRIM(ttRuleActive) = "Yes" OR TRIM(ttRuleActive) = "True" THEN YES ELSE NO
					xxdoarule_rule[1]			= getFormattedCondition(ttRuleCondition1)	
					xxdoarule_rule[2]			= getFormattedCondition(ttRuleCondition2)	
					xxdoarule_rule[3]			= getFormattedCondition(ttRuleCondition3)	
					xxdoarule_rule[4]			= getFormattedCondition(ttRuleCondition4)	
					xxdoarule_rule[5]			= getFormattedCondition(ttRuleCondition5)	
					xxdoarule_rule[6]			= getFormattedCondition(ttRuleCondition6)	
					xxdoarule_rule[7]			= getFormattedCondition(ttRuleCondition7)	
					xxdoarule_rule[8]			= getFormattedCondition(ttRuleCondition8)	
					xxdoarule_rule[9]			= getFormattedCondition(ttRuleCondition9)	
					xxdoarule_rule[10]			= getFormattedCondition(ttRuleCondition10)	
					xxdoarule_rule[11]			= getFormattedCondition(ttRuleCondition11)	
					xxdoarule_rule[12]			= getFormattedCondition(ttRuleCondition12)	
					xxdoarule_rule[13]			= getFormattedCondition(ttRuleCondition13)	
					xxdoarule_rule[14]			= getFormattedCondition(ttRuleCondition14)	
					xxdoarule_rule[15]			= getFormattedCondition(ttRuleCondition15)	
					xxdoarule_approvers[1]		= TRIM(ttApprover1)
					xxdoarule_approvers[2]		= TRIM(ttApprover2)
					xxdoarule_approvers[3]		= TRIM(ttApprover3)
					xxdoarule_approvers[4]		= TRIM(ttApprover4)
					xxdoarule_approvers[5]		= TRIM(ttApprover5)
					xxdoarule_approvers[6]		= TRIM(ttApprover6)
					xxdoarule_approvers[7]		= TRIM(ttApprover7)
					xxdoarule_approvers[8]		= TRIM(ttApprover8)
					xxdoarule_approvers[9]		= TRIM(ttApprover9)
					xxdoarule_approvers[10]		= TRIM(ttApprover10)
					xxdoarule_LastModifiedDate  = TODAY
					xxdoarule_LastModifiedTime  = TIME
					xxdoarule_LastModifiedUser  = global_userid.
			END. /*FOR EACH xxdoarule_mstr*/
		END. /*IF ttRuleCode <> ""*/
		ELSE DO:
			ASSIGN lvc_rulecode = "".
			
			RUN getnbr
				(INPUT  TRIM(code_mstr.code_cmmt),
				 INPUT  TODAY,
				 OUTPUT lvc_rulecode,
				 OUTPUT lvl_iserror,
				 OUTPUT lvi_errorNum).
			
			IF lvc_rulecode <> ""
			THEN DO:
				ASSIGN ttRuleCode = TRIM(lvc_rulecode).
				
				CREATE xxdoarule_mstr.
				ASSIGN 
					xxdoarule_domain 			= global_domain
					xxdoarule_code   			= TRIM(lvc_rulecode)
					xxdoarule_type 				= TRIM(ttRuleType)
					xxdoarule_businessline 		= TRIM(ttRuleBusinessLine)
					xxdoarule_site 				= TRIM(ttRuleSite)
					xxdoarule_active 			= IF TRIM(ttRuleActive) = "Yes" OR TRIM(ttRuleActive) = "True" THEN YES ELSE NO
					xxdoarule_rule[1]			= getFormattedCondition(ttRuleCondition1)	
					xxdoarule_rule[2]			= getFormattedCondition(ttRuleCondition2)	
					xxdoarule_rule[3]			= getFormattedCondition(ttRuleCondition3)	
					xxdoarule_rule[4]			= getFormattedCondition(ttRuleCondition4)	
					xxdoarule_rule[5]			= getFormattedCondition(ttRuleCondition5)	
					xxdoarule_rule[6]			= getFormattedCondition(ttRuleCondition6)	
					xxdoarule_rule[7]			= getFormattedCondition(ttRuleCondition7)	
					xxdoarule_rule[8]			= getFormattedCondition(ttRuleCondition8)	
					xxdoarule_rule[9]			= getFormattedCondition(ttRuleCondition9)	
					xxdoarule_rule[10]			= getFormattedCondition(ttRuleCondition10)	
					xxdoarule_rule[11]			= getFormattedCondition(ttRuleCondition11)	
					xxdoarule_rule[12]			= getFormattedCondition(ttRuleCondition12)	
					xxdoarule_rule[13]			= getFormattedCondition(ttRuleCondition13)	
					xxdoarule_rule[14]			= getFormattedCondition(ttRuleCondition14)	
					xxdoarule_rule[15]			= getFormattedCondition(ttRuleCondition15)	
					xxdoarule_approvers[1]		= TRIM(ttApprover1)		
					xxdoarule_approvers[2]		= TRIM(ttApprover2)
					xxdoarule_approvers[3]		= TRIM(ttApprover3)
					xxdoarule_approvers[4]		= TRIM(ttApprover4)
					xxdoarule_approvers[5]		= TRIM(ttApprover5)
					xxdoarule_approvers[6]		= TRIM(ttApprover6)
					xxdoarule_approvers[7]		= TRIM(ttApprover7)
					xxdoarule_approvers[8]		= TRIM(ttApprover8)
					xxdoarule_approvers[9]		= TRIM(ttApprover9)
					xxdoarule_approvers[10]		= TRIM(ttApprover10)
					xxdoarule_LastModifiedDate  = TODAY
					xxdoarule_LastModifiedTime  = TIME
					xxdoarule_LastModifiedUser  = global_userid.
			END. /*IF lvc_rulecode <> ""*/
			ELSE DO:
				ASSIGN 
					ttProcess	= NO
					ttError 	= "Unable to fetch rule code sequence. Sequence ID - " + TRIM(code_mstr.code_cmmt).
					
				IF lvl_iserror AND lvi_errorNum <> 0
				THEN DO:
					FIND FIRST msg_mstr WHERE msg_lang = "US" AND msg_nbr = lvi_errorNum NO-LOCK NO-ERROR.
					IF AVAILABLE msg_mstr 
					THEN 
						ASSIGN ttError 	= msg_desc.
				END.
			END.
		END. /*DO TRANSACTION*/
	END. /*FOR EACH ttRuleImport*/
	
	OUTPUT TO VALUE(lvc_outFile).
	EXPORT DELIMITER ","
		"Rule Code"
		"Rule Type"
		"Business Line"
		"Site"
		"Active"
		"Rule Condition 1"
		"Rule Condition 2"
		"Rule Condition 3"
		"Rule Condition 4"
		"Rule Condition 5"
		"Rule Condition 6"
		"Rule Condition 7"
		"Rule Condition 8"
		"Rule Condition 9"
		"Rule Condition 10"
		"Rule Condition 11"
		"Rule Condition 12"
		"Rule Condition 13"
		"Rule Condition 14"
		"Rule Condition 15"
		"Rule Approver 1"
		"Rule Approver 2"
		"Rule Approver 3"
		"Rule Approver 4"
		"Rule Approver 5"
		"Rule Approver 6"
		"Rule Approver 7"
		"Rule Approver 8"
		"Rule Approver 9"
		"Rule Approver 10"
		"Processed"
		"Error Message"
		.
		
	FOR EACH ttRuleImport:
		EXPORT DELIMITER ","
	         ttRuleCode
             ttRuleType  			 
             ttRuleBusinessLine     
             ttRuleSite       		 
	         ttRuleActive       	 
	         ttRuleCondition1     	
	         ttRuleCondition2     	
	         ttRuleCondition3     	
	         ttRuleCondition4     	
	         ttRuleCondition5     	
	         ttRuleCondition6     	
	         ttRuleCondition7     	
	         ttRuleCondition8     	
	         ttRuleCondition9     	
	         ttRuleCondition10     
	         ttRuleCondition11     
	         ttRuleCondition12     
	         ttRuleCondition13     
	         ttRuleCondition14     
	         ttRuleCondition15    	
	         ttApprover1	    	
	         ttApprover2	    	
	         ttApprover3	    	
	         ttApprover4	    	
	         ttApprover5	    	
	         ttApprover6	    	
	         ttApprover7	    	
	         ttApprover8	    	
	         ttApprover9	    	
	         ttApprover10	    	
	         ttProcess 
	         ttError
			 .
	END. /*FOR EACH ttRuleImport*/
	OUTPUT CLOSE.
	
	OUTPUT TO VALUE(lvc_msgfilename).
	PUT UNFORMATTED "Please find attached result of DOA Rule Upload Utilty run.".
	OUTPUT CLOSE.
	
	IF SEARCH(lvc_outFile) <> ? AND lvc_EmailID <> ""
	THEN DO:
		ASSIGN lvc_oscommand = "mailx -s 'DOA Rule Upload Result' -a " + lvc_outFile + " " + lvc_EmailID + " < " + lvc_msgfilename.
		OS-COMMAND SILENT VALUE(lvc_oscommand).	
		{us/bbi/pxmsg.i &MSGTEXT='"Processing completed. Result is sent on email."' &ERRORLEVEL=1}
	END.
	
	OS-DELETE VALUE(lvc_inpFile).
	OS-DELETE VALUE(lvc_outFile).
	OS-DELETE VALUE(lvc_msgfilename).
	
END. /*mainloop*/
	   