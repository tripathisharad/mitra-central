/* PSC: xxdoaproc.p - DOA Rule Application Engine						*/
/*                                                                      */
/* CREATED: 25 May 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/			

{us/bbi/mfdeclre.i}

DEFINE INPUT 		PARAMETER ipc_ruletype 				AS CHARACTER 	NO-UNDO.
DEFINE INPUT 		PARAMETER ipc_businessLine   		AS CHARACTER 	NO-UNDO.
DEFINE INPUT 		PARAMETER ipc_site  				AS CHARACTER 	NO-UNDO.
DEFINE INPUT 		PARAMETER ipr_recid    				AS RECID     	NO-UNDO.
DEFINE INPUT 		PARAMETER ipc_currentapprovercode	AS CHARACTER 	NO-UNDO.
DEFINE INPUT-OUTPUT PARAMETER iopc_rulecode				AS CHARACTER	NO-UNDO.
DEFINE OUTPUT 		PARAMETER opc_nextapproverCode		AS CHARACTER	NO-UNDO.
DEFINE OUTPUT 		PARAMETER opc_nextapprover	 		AS CHARACTER	NO-UNDO.
DEFINE OUTPUT 		PARAMETER opc_notifyto 	 			AS CHARACTER	NO-UNDO.
DEFINE OUTPUT 		PARAMETER opl_isfinalapproved 		AS LOGICAL      NO-UNDO.
DEFINE OUTPUT 		PARAMETER opc_errorMsg 				AS CHARACTER	NO-UNDO.

DEFINE VARIABLE 			  lvi_count 				AS INTEGER 		NO-UNDO.
DEFINE VARIABLE 			  lvc_businessline			AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvc_site	  				AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvc_rule  				AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvc_tablename  			AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvc_notifyto  			AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvc_nextapprover			AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvc_doaapprovercodeList	AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvc_rulecondition    		AS CHARACTER 	NO-UNDO.
DEFINE VARIABLE 			  lvl_ruleavail 			AS LOGICAL 		NO-UNDO.
DEFINE VARIABLE 			  htable 					AS HANDLE		NO-UNDO.   
DEFINE VARIABLE 			  qh 						AS HANDLE		NO-UNDO.

FIND FIRST code_mstr
	 WHERE code_domain 	EQ global_domain 	AND
		   code_fldname EQ "DOA_RULE_TYPE" 	AND
		   code_value   EQ ipc_ruletype 	AND
		   code_cmmt    NE ""
NO-LOCK NO-ERROR.
IF NOT AVAILABLE code_mstr 
THEN DO:
	/* DOA RULE TYPE NOT MAINTAINED IN GCM */
	ASSIGN opc_errorMsg = "Rule Type not maintained in GCM. FieldName - DOA_RULE_TYPE".
	RETURN.
END.
/* IF AVAILABLE code_mstr THEN GET DB TABLE NAME ASSOCIATED WITH RULE TYPE */
ASSIGN lvc_tablename = TRIM(code_mstr.code_cmmt).
/*
IF ipc_businessLine NE "" AND
   NOT CAN-FIND(FIRST code_mstr NO-LOCK
				WHERE code_domain 	EQ global_domain    AND
					  code_fldname 	EQ "pt_drwg_loc" 	AND
					  code_value    EQ ipc_businessLine)
THEN DO:
	/* DOA BUSINESS LINE NOT MAINTAINED IN GCM */
	ASSIGN opc_errorMsg = "Business Line not maintained in GCM. FieldName - DOA_BUSINESS_LINE".
	RETURN.
END.
*/
/* GET APPROVER CODE LIST FROM GCM */
ASSIGN lvc_doaapprovercodeList = "".
FOR EACH code_mstr
	WHERE code_domain 	EQ global_domain		AND
		  code_fldname 	EQ "DOA_APPROVER_CODES" AND
		  code_value   	NE ""
	NO-LOCK:
	IF lvc_doaapprovercodeList = "" 
	THEN
		ASSIGN lvc_doaapprovercodeList = code_value.
	ELSE
		ASSIGN lvc_doaapprovercodeList = lvc_doaapprovercodeList + "," + code_value.
END. /* FOR EACH code_mstr */

IF lvc_doaapprovercodeList EQ "" 
THEN DO:
	/* DOA APPROVER CODES NOT MAINTAINED IN GCM */
	ASSIGN opc_errorMsg = "DOA Approver Codes not maintained in GCM. FieldName - DOA_APPROVER_CODES".
	RETURN.
END.

ASSIGN 
	lvl_ruleavail 	 = NO
	lvc_nextapprover = ""
	lvc_notifyto     = "".

CREATE BUFFER htable FOR TABLE lvc_tablename.
CREATE QUERY qh.
qh:SET-BUFFERS(htable:HANDLE).

IF iopc_rulecode NE "" AND 
   CAN-FIND(FIRST xxdoarule_mstr
			WHERE xxdoarule_domain 	EQ global_domain AND
				  xxdoarule_code	EQ iopc_rulecode AND
				  xxdoarule_active  EQ YES)
THEN DO:
	FOR FIRST xxdoarule_mstr
		WHERE xxdoarule_domain 	EQ global_domain AND
			  xxdoarule_code	EQ iopc_rulecode
		NO-LOCK:
		ASSIGN lvl_ruleavail = YES.
		
		DO lvi_count = 1 TO 10:
			IF xxdoarule_approvers[lvi_count] NE ""
			THEN DO:
				IF ipc_currentapprovercode EQ xxdoarule_approvers[lvi_count]
				THEN 
					LEAVE.
			END.
		END. /* DO lvi_count = 1 TO 10 */

		DO lvi_count = (lvi_count + 1) TO 10:
			IF xxdoarule_approvers[lvi_count] NE ""
			THEN DO:
				ASSIGN 
					opc_nextapproverCode = xxdoarule_approvers[lvi_count]
					lvc_nextapprover 	 = xxdoarule_approvers[lvi_count].
				LEAVE.
			END.
		END. /* DO lvi_count = 1 TO 10 */
		
		DO lvi_count = 1 TO 10:
			IF xxdoarule_notifyto[lvi_count] NE ""
			THEN DO:
				IF lvc_notifyto = "" 
				THEN
					ASSIGN lvc_notifyto = xxdoarule_notifyto[lvi_count].
				ELSE 
					ASSIGN lvc_notifyto = lvc_notifyto + "," + xxdoarule_notifyto[lvi_count].
			END. /* IF xxdoarule_notifyto[lvi_count] NE "" */
		END.  /* DO lvi_count = 1 TO 10 */
	END. /* FOR FIRST xxdoarule_mstr */
END. /* IF iopc_rulecode NE ""  */
ELSE DO:
	IF CAN-FIND(FIRST xxdoarule_mstr
				WHERE xxdoarule_domain 		  EQ global_domain 		AND
					  xxdoarule_type   		  EQ ipc_ruletype  	 	AND
					  xxdoarule_businessline  EQ ipc_businessLine 	AND
					  xxdoarule_site 		  EQ ipc_site			AND
					  xxdoarule_active        EQ YES) 
	THEN
		ASSIGN 
			lvc_businessline = ipc_businessLine
			lvc_site       	 = ipc_site.
			
	ELSE
	IF CAN-FIND(FIRST xxdoarule_mstr
				WHERE xxdoarule_domain 		  EQ global_domain 	AND
					  xxdoarule_type   		  EQ ipc_ruletype  	AND
					  xxdoarule_businessline  EQ "" 			AND
					  xxdoarule_site 		  EQ ipc_site		AND
					  xxdoarule_active        EQ YES)	 
	THEN
		ASSIGN 
			lvc_businessline = ""
			lvc_site       	 = ipc_site.
	ELSE
	IF CAN-FIND(FIRST xxdoarule_mstr
				WHERE xxdoarule_domain 		  EQ global_domain 		AND
					  xxdoarule_type   		  EQ ipc_ruletype  		AND
					  xxdoarule_businessline  EQ ipc_businessLine 	AND
					  xxdoarule_site 		  EQ ""					AND
					  xxdoarule_active        EQ YES) 
	THEN
		ASSIGN 
			lvc_businessline = ipc_businessLine
			lvc_site       	 = "".
	ELSE
	IF CAN-FIND(FIRST xxdoarule_mstr
				WHERE xxdoarule_domain 		  EQ global_domain 	AND
					  xxdoarule_type   		  EQ ipc_ruletype  	AND
					  xxdoarule_businessline  EQ "" 			AND
					  xxdoarule_site 		  EQ ""				AND
					  xxdoarule_active        EQ YES) 
	THEN
		ASSIGN 
			lvc_businessline = ""
			lvc_site       	 = "".

	RuleLoop:
	FOR EACH xxdoarule_mstr
		WHERE xxdoarule_domain 		  EQ global_domain 		AND
			  xxdoarule_type   		  EQ ipc_ruletype  	 	AND
			  xxdoarule_businessline  EQ lvc_businessline 	AND
			  xxdoarule_site 		  EQ lvc_site			AND
			  xxdoarule_active        EQ YES
		NO-LOCK:
		ASSIGN 
			lvc_rule 		  = ""
			lvc_rulecondition = "".
		
		DO lvi_count = 1 TO 15:                
			IF xxdoarule_rule[lvi_count] NE ""
			THEN DO:
				ASSIGN lvc_rulecondition = REPLACE(xxdoarule_rule[lvi_count],"|"," ").
				
				IF ENTRY(2,xxdoarule_rule[lvi_count],"|") EQ "=" AND
				   NUM-ENTRIES(ENTRY(3,xxdoarule_rule[lvi_count],"|"),",") GT 1 
				THEN
					ASSIGN lvc_rulecondition = "LOOKUP(" + ENTRY(1,xxdoarule_rule[lvi_count],"|") + "," + ENTRY(3,xxdoarule_rule[lvi_count],"|") + ",',') GT 0".

				IF lvc_rule = ""
				THEN
					ASSIGN lvc_rule = lvc_rulecondition.
				ELSE 
					ASSIGN lvc_rule = lvc_rule + " AND " + lvc_rulecondition.
			END. /* IF xxdoarule_rule[lvi_count] NE "" */
		END. /* DO lvi_count = 1 TO 15 */
		
		IF lvc_rule NE "" 
		THEN DO:
			qh:QUERY-PREPARE('FOR EACH ' + lvc_tablename + ' NO-LOCK WHERE RECID(' + lvc_tablename + ') = ' + STRING(ipr_recid) + ' AND ' + lvc_rule).
			qh:QUERY-OPEN.
			qh:GET-FIRST().
			
			IF htable:AVAILABLE
			THEN DO:
				ASSIGN 
					lvl_ruleavail = YES
					iopc_rulecode = xxdoarule_mstr.xxdoarule_code.
				
				DO lvi_count = 1 TO 10:
					IF xxdoarule_approvers[lvi_count] NE ""
					THEN DO:
						ASSIGN 
							opc_nextapproverCode = xxdoarule_approvers[lvi_count]
							lvc_nextapprover 	 = xxdoarule_approvers[lvi_count].
						LEAVE.
					END. /* IF xxdoarule_approvers[lvi_count] NE "" */
				END. /* DO lvi_count = 1 TO 10 */

				DO lvi_count = 1 TO 10:
					IF xxdoarule_notifyto[lvi_count] NE ""
					THEN DO:
						IF lvc_notifyto = "" 
						THEN
							ASSIGN lvc_notifyto = xxdoarule_notifyto[lvi_count].
						ELSE 
							ASSIGN lvc_notifyto = lvc_notifyto + "," + xxdoarule_notifyto[lvi_count].
					END. /* IF xxdoarule_notifyto[lvi_count] NE "" */
				END.  /* DO lvi_count = 1 TO 10 */
				
				qh:QUERY-CLOSE().
				LEAVE RuleLoop.
			END. /* IF htable:AVAILABLE */
		END. /* IF lvc_rule NE "" */
		
		qh:QUERY-CLOSE().
	END. /* RuleLoop */
END. /* ELSE DO - IF iopc_rulecode NE "" */

IF lvl_ruleavail = NO
THEN DO:
	/* RETURN ERROR - RULE NOT AVAILEBLE */
	ASSIGN opc_errorMsg = "Appropriate rule not found in DOA Rule Maintenance for this data".
	RETURN.
END.

/* IF lvc_nextapprover = "" / "SELF" THEN NO FURTHER APPROVALS NEEDED */
IF lvc_nextapprover = "" OR lvc_nextapprover = "SELF"
THEN
	ASSIGN opl_isfinalapproved = YES.
	
FIND FIRST usr_mstr WHERE usr_mstr.usr_userid EQ global_userid NO-LOCK NO-ERROR.
IF AVAILABLE usr_mstr 
THEN
	ASSIGN lvc_nextapprover = REPLACE(lvc_nextapprover,"SELF",usr_mstr.usr_mail_address).
    		
/* GET ACTUAL APPROVERS BASED ON APPROVER CODES */
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ipc_ruletype  	AND
		   xxdoaappr_businessline  	EQ ipc_businessLine	AND
		   xxdoaappr_site 		  	EQ ipc_site
NO-LOCK NO-ERROR.

IF NOT AVAILABLE xxdoaappr_mstr THEN
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ""  				AND
		   xxdoaappr_businessline  	EQ ipc_businessLine	AND
		   xxdoaappr_site 		  	EQ ipc_site
NO-LOCK NO-ERROR.

IF NOT AVAILABLE xxdoaappr_mstr THEN
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ipc_ruletype  	AND
		   xxdoaappr_businessline  	EQ ""				AND
		   xxdoaappr_site 		  	EQ ipc_site
NO-LOCK NO-ERROR.

IF NOT AVAILABLE xxdoaappr_mstr THEN
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ""  				AND
		   xxdoaappr_businessline  	EQ ""				AND
		   xxdoaappr_site 		  	EQ ipc_site
NO-LOCK NO-ERROR.

IF NOT AVAILABLE xxdoaappr_mstr THEN
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ipc_ruletype  	AND
		   xxdoaappr_businessline  	EQ ipc_businessLine	AND
		   xxdoaappr_site 		  	EQ ""
NO-LOCK NO-ERROR.

IF NOT AVAILABLE xxdoaappr_mstr THEN
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ""  				AND
		   xxdoaappr_businessline  	EQ ipc_businessLine	AND
		   xxdoaappr_site 		  	EQ ""
NO-LOCK NO-ERROR.

IF NOT AVAILABLE xxdoaappr_mstr THEN
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ipc_ruletype  	AND
		   xxdoaappr_businessline  	EQ ""				AND
		   xxdoaappr_site 		  	EQ ""
NO-LOCK NO-ERROR.

IF NOT AVAILABLE xxdoaappr_mstr THEN
FIND FIRST xxdoaappr_mstr
	 WHERE xxdoaappr_domain 		EQ global_domain	AND
		   xxdoaappr_type   		EQ ""  				AND
		   xxdoaappr_businessline  	EQ ""				AND
		   xxdoaappr_site 		  	EQ ""
NO-LOCK NO-ERROR.

IF AVAILABLE xxdoaappr_mstr 
THEN DO:    
	DO lvi_count = 1 TO 15:
		IF xxdoaappr_approvers[lvi_count] NE ""
		THEN DO:
			IF lvc_nextapprover NE "" AND LOOKUP(lvc_nextapprover,lvc_doaapprovercodeList,",") GT 0
			THEN
				ASSIGN lvc_nextapprover = REPLACE(lvc_nextapprover,ENTRY(1,xxdoaappr_approvers[lvi_count],"|"),ENTRY(2,xxdoaappr_approvers[lvi_count],"|")).
			
			IF lvc_notifyto NE "" AND LOOKUP(lvc_notifyto,lvc_doaapprovercodeList,",") GT 0
			THEN
				ASSIGN lvc_notifyto = REPLACE(lvc_notifyto,ENTRY(1,xxdoaappr_approvers[lvi_count],"|"),ENTRY(2,xxdoaappr_approvers[lvi_count],"|")).
		END. /* IF xxdoaappr_approvers[lvi_count] NE "" */
	END. /* DO lvi_count = 1 TO 15 */
END. /* IF AVAILABLE xxdoaappr_mstr */

IF LOOKUP(lvc_nextapprover,lvc_doaapprovercodeList,",") GT 0
THEN DO:
	RUN getApproversFromGCM(INPUT-OUTPUT lvc_nextapprover, INPUT-OUTPUT lvc_notifyto).
END.

IF LOOKUP(lvc_nextapprover,lvc_doaapprovercodeList,",") GT 0
THEN DO:
	/* APPROVER DETAILS NOT DEFINED */
	ASSIGN opc_errorMsg = lvc_nextapprover + " approver email not defined for Rule Type - " + ipc_ruletype + ", Business Line - " + ipc_businessLine + ", Site - " + ipc_site.
	RETURN.
END.

ASSIGN 
	opc_nextapprover = lvc_nextapprover
	opc_notifyto 	 = lvc_notifyto.

DELETE OBJECT qh.
DELETE OBJECT htable.


/* PROCEDURE TO GET CCO AND CEO APPROVER DETAILS FROM GCM */
PROCEDURE getApproversFromGCM:
	DEFINE INPUT-OUTPUT PARAMETER 	iopc_nextapprover 	AS CHARACTER NO-UNDO.
	DEFINE INPUT-OUTPUT PARAMETER 	iopc_notifyto 		AS CHARACTER NO-UNDO.
	
	DEFINE BUFFER 					buff_code_mstr 		FOR code_mstr.
	
	FOR EACH buff_code_mstr
		WHERE buff_code_mstr.code_domain 	EQ global_domain 	AND
			  buff_code_mstr.code_fldname 	EQ "DOA_APPROVERS" 	AND
			  buff_code_mstr.code_value   	NE ""
		NO-LOCK:
		IF iopc_nextapprover NE "" AND LOOKUP(iopc_nextapprover,lvc_doaapprovercodeList,",") GT 0
		THEN
			ASSIGN iopc_nextapprover = REPLACE(iopc_nextapprover,TRIM(buff_code_mstr.code_value),TRIM(buff_code_mstr.code_cmmt)).
		
		IF iopc_notifyto NE "" AND LOOKUP(iopc_notifyto,lvc_doaapprovercodeList,",") GT 0
		THEN
			ASSIGN iopc_notifyto = REPLACE(iopc_notifyto,TRIM(buff_code_mstr.code_value),TRIM(buff_code_mstr.code_cmmt)).
	END. /* FOR EACH buff_code_mstr */
END. /* getGCMData */
