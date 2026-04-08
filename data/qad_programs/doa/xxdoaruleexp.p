/* PSC: xxdoaruleexp.p - DOA Rule Export Utility 	                    */
/*                                                                      */
/* CREATED: 20 Aug 2024   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

{us/mf/mfdtitle.i}

DEFINE VARIABLE lvc_outFile				AS CHARACTER 	NO-UNDO INITIAL "DOA_Rule_Export.csv".
DEFINE VARIABLE lvc_msgfilename         AS CHARACTER	NO-UNDO INITIAL "MailBody.txt".
DEFINE VARIABLE lvc_rulecode    		AS CHARACTER	NO-UNDO FORMAT "x(40)" VIEW-AS FILL-IN SIZE 20 BY 1.
DEFINE VARIABLE lvc_rulecodeTo			AS CHARACTER	NO-UNDO FORMAT "x(40)" VIEW-AS FILL-IN SIZE 20 BY 1.
DEFINE VARIABLE lvc_ruletype			AS CHARACTER	NO-UNDO FORMAT "x(40)".
DEFINE VARIABLE lvc_rulebusinessline  	AS CHARACTER 	FORMAT "x(40)" 	NO-UNDO.
DEFINE VARIABLE lvc_rulesite          	AS CHARACTER 	FORMAT "x(30)" 	NO-UNDO.
DEFINE VARIABLE lvc_oscommand 			AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_EmailID				AS CHARACTER	NO-UNDO FORMAT "x(200)" VIEW-AS FILL-IN SIZE 40 BY 1.
	   
FORM
   lvc_rulecode           COLON 15 LABEL "Rule Code"
   lvc_rulecodeTo         COLON 45 LABEL "To"
   lvc_ruletype           COLON 15 LABEL "Rule Type"
   lvc_rulebusinessline   COLON 15 LABEL "Business Line"
   lvc_rulesite           COLON 15 LABEL "Site"
   lvc_EmailID 			  COLON 15 LABEL "Email"
   WITH FRAME a
   SIDE-LABELS
   WIDTH 120.
   
setFrameLabels(FRAME a:HANDLE).

FIND FIRST usr_mstr WHERE usr_userid = global_userid NO-LOCK NO-ERROR.
IF AVAILABLE usr_mstr AND usr_mail_address <> "" 
THEN
	ASSIGN lvc_EmailID = usr_mail_address.
	   
mainloop:	   
REPEAT:	
	ASSIGN 
		lvc_rulecode 			= ""
		lvc_rulecodeTo 			= ""
		lvc_ruletype 			= ""
		lvc_rulebusinessline 	= ""
		lvc_rulesite 			= "".
		
	UPDATE 
		lvc_rulecode
		lvc_rulecodeTo
		lvc_ruletype
		lvc_rulebusinessline
		lvc_rulesite
		lvc_EmailID
	WITH FRAME a.
	
	IF lvc_rulecodeTo = "" THEN lvc_rulecodeTo = hi_char.

	IF lvc_EmailID = "" 
	THEN DO:
		{us/bbi/pxmsg.i &MSGTEXT='"Email ID cannot be blank"' &ERRORLEVEL=3}
		UNDO mainloop, RETRY mainloop.
	END.
	
	IF lvc_ruletype <> "" 
	THEN DO:
		IF NOT CAN-FIND(FIRST code_mstr
						WHERE code_domain 	EQ global_domain 	AND
							  code_fldname 	EQ "DOA_RULE_TYPE" 	AND
							  code_value   	EQ TRIM(lvc_ruletype))
		THEN DO:
			{us/bbi/pxmsg.i &MSGTEXT='"Rule Type not maintained in GCM. FieldName - DOA_RULE_TYPE"' &ERRORLEVEL=3}
			UNDO mainloop, RETRY mainloop.
		END.
	END. /*IF lvc_ruletype <> ""*/
	
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
		.
	
	FOR EACH xxdoarule_mstr
		WHERE xxdoarule_domain 		= 	global_domain 										AND
			  xxdoarule_code   		>= 	lvc_rulecode 										AND
			  xxdoarule_code   		<= 	lvc_rulecodeTo 										AND
			  (lvc_ruletype    		= "" OR xxdoarule_type  		= lvc_ruletype) 		AND
			  (lvc_rulebusinessline = "" OR xxdoarule_businessline 	= lvc_rulebusinessline) AND
			  (lvc_rulesite 		= "" OR xxdoarule_site 			= lvc_rulesite)
		NO-LOCK:
		EXPORT DELIMITER ","
	         xxdoarule_code
             xxdoarule_type  			 
             xxdoarule_businessline     
             xxdoarule_site       		 
	         STRING(xxdoarule_active)       	 
	         REPLACE(xxdoarule_rule[1],"|","")
	         REPLACE(xxdoarule_rule[2],"|","")
	         REPLACE(xxdoarule_rule[3],"|","")
	         REPLACE(xxdoarule_rule[4],"|","")
	         REPLACE(xxdoarule_rule[5],"|","")
	         REPLACE(xxdoarule_rule[6],"|","")
	         REPLACE(xxdoarule_rule[7],"|","")
	         REPLACE(xxdoarule_rule[8],"|","")
	         REPLACE(xxdoarule_rule[9],"|","")
	         REPLACE(xxdoarule_rule[10],"|","")
	         REPLACE(xxdoarule_rule[11],"|","")
	         REPLACE(xxdoarule_rule[12],"|","")
	         REPLACE(xxdoarule_rule[13],"|","")
	         REPLACE(xxdoarule_rule[14],"|","")
	         REPLACE(xxdoarule_rule[15],"|","")
	         xxdoarule_approvers[1]    	
	         xxdoarule_approvers[2]    		
	         xxdoarule_approvers[3]    	   	
	         xxdoarule_approvers[4]    	
	         xxdoarule_approvers[5]    		
	         xxdoarule_approvers[6]    		
	         xxdoarule_approvers[7]    		
	         xxdoarule_approvers[8]    		
	         xxdoarule_approvers[9]    		
	         xxdoarule_approvers[10]    	
			 .
	END. /*FOR EACH xxdoarule_mstr*/
	OUTPUT CLOSE.
	
	OUTPUT TO VALUE(lvc_msgfilename).
	PUT UNFORMATTED "Please find attached DOA Rule Export.".
	OUTPUT CLOSE.
	
	IF SEARCH(lvc_outFile) <> ? AND lvc_EmailID <> ""
	THEN DO:
		ASSIGN lvc_oscommand = "mailx -s 'DOA Rule Export' -a " + lvc_outFile + " " + lvc_EmailID + " < " + lvc_msgfilename.
		OS-COMMAND SILENT VALUE(lvc_oscommand).	
		{us/bbi/pxmsg.i &MSGTEXT='"Processing completed. Data export file is sent on email."' &ERRORLEVEL=1}
	END.
	
	OS-DELETE VALUE(lvc_outFile).
	OS-DELETE VALUE(lvc_msgfilename).
	
END. /*mainloop*/
	   