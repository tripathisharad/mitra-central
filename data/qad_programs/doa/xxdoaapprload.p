/* PSC: xxdoaapprload.p - DOA Approvers Upload Utility                  */
/*                                                                      */
/* CREATED: 20 Aug 2024   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

{us/mf/mfdtitle.i}

DEFINE VARIABLE lvc_inpFile 			AS CHARACTER 	NO-UNDO VIEW-AS FILL-IN SIZE 40 BY 1 FORMAT "x(300)".
DEFINE VARIABLE lvc_outFile				AS CHARACTER 	NO-UNDO INITIAL "DOA_ApproversUpload_Result.csv".
DEFINE VARIABLE lvc_msgfilename         AS CHARACTER	NO-UNDO INITIAL "MailBody.txt".
DEFINE VARIABLE lvl_iserror     		AS LOGICAL 		NO-UNDO.
DEFINE VARIABLE lvi_errorNum    		AS INTEGER 		NO-UNDO.
DEFINE VARIABLE lvc_rulecode    		AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_firstLine			AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_oscommand 			AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_EmailID				AS CHARACTER	NO-UNDO FORMAT "x(200)" VIEW-AS FILL-IN SIZE 40 BY 1.
DEFINE VARIABLE lvl_firstLine			AS LOGICAL 		NO-UNDO.
DEFINE VARIABLE lvl_dataAvailable       AS LOGICAL 		NO-UNDO.
DEFINE VARIABLE lvh_ApproversImport		AS HANDLE       NO-UNDO.
DEFINE VARIABLE lvi_count 				AS INTEGER      NO-UNDO.

DEFINE TEMP-TABLE ttApproversImport
       FIELD      ttRuleType  			AS CHARACTER 
       FIELD      ttRuleBusinessLine    AS CHARACTER 
       FIELD      ttRuleSite       		AS CHARACTER 
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
	   FIELD      ttApprover11	    	AS CHARACTER
	   FIELD      ttApprover12	    	AS CHARACTER
	   FIELD      ttApprover13	    	AS CHARACTER
	   FIELD      ttApprover14	    	AS CHARACTER
	   FIELD      ttApprover15	    	AS CHARACTER
	   FIELD      ttProcess 			AS LOGICAL
	   FIELD      ttError				AS CHARACTER
	   .
	   
ASSIGN lvh_ApproversImport = BUFFER ttApproversImport:HANDLE.
	   
FORM
   lvc_inpFile COLON 30 LABEL "Approvers Import File(CSV)"
   lvc_EmailID COLON 30 LABEL "Email"
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
	
	EMPTY TEMP-TABLE ttApproversImport.
	
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
	
	ASSIGN lvl_firstLine = YES.
	
	INPUT FROM VALUE(lvc_inpFile).
	REPEAT:
		IF lvl_firstLine = YES 
		THEN DO:
			IMPORT UNFORMATTED lvc_firstLine.
			ASSIGN lvl_firstLine = NO.
		END.
		ELSE DO:
			CREATE ttApproversImport.
			IMPORT DELIMITER "," ttApproversImport EXCEPT ttProcess ttError.
		
			ASSIGN ttProcess = YES.
		END.
	END.
	INPUT CLOSE.
	
	FOR EACH ttApproversImport:
		ASSIGN lvl_dataAvailable = NO.
		
		doloop1:
		DO lvi_count = 1 TO lvh_ApproversImport:NUM-FIELDS:
			IF lvh_ApproversImport:BUFFER-FIELD(lvi_count):NAME <> "ttProcess"
			THEN DO:
				IF lvh_ApproversImport:BUFFER-FIELD(lvi_count):BUFFER-VALUE <> "" 
				THEN DO:
					ASSIGN lvl_dataAvailable = YES.
					LEAVE doloop1.
				END.
			END.
		END. /*doloop1*/
		
		IF lvl_dataAvailable = NO 
		THEN
			DELETE ttApproversImport.
	END. /*FOR EACH ttApproversImport*/
	
	IF NOT CAN-FIND(FIRST ttApproversImport) 
	THEN DO:
		{us/bbi/pxmsg.i &MSGTEXT='"No data to import"' &ERRORLEVEL=3}
		UNDO mainloop, RETRY mainloop.
	END.
	
	/*VALIDATE THE FILE DATA*/
	FOR EACH ttApproversImport:
		IF ttRuleType <> "" 
		THEN DO:
			IF NOT CAN-FIND(FIRST code_mstr
							WHERE code_domain 	EQ global_domain 	AND
								  code_fldname 	EQ "DOA_RULE_TYPE" 	AND
								  code_value   	EQ ttRuleType)
			THEN DO:
				ASSIGN 
					ttProcess = NO
					ttError   = "Rule Type not maintained in GCM. FieldName - DOA_RULE_TYPE".
			END.
		END. /*IF ttRuleType <> ""*/
		
		IF ttApprover1 		= "" AND 
		   ttApprover2 		= "" AND 
		   ttApprover3 		= "" AND 
		   ttApprover4 		= "" AND 
		   ttApprover5 		= "" AND 
		   ttApprover6 		= "" AND 
		   ttApprover7 		= "" AND 
		   ttApprover8 		= "" AND 
		   ttApprover9 		= "" AND 
		   ttApprover10 	= "" AND
		   ttApprover11		= "" AND 
		   ttApprover12		= "" AND 
		   ttApprover13		= "" AND 
		   ttApprover14		= "" AND 
		   ttApprover15		= ""
		THEN DO:
			ASSIGN ttProcess = NO.
			
			IF ttError = "" 
			THEN
				ASSIGN ttError = "Approvers not defined".
			ELSE
				ASSIGN ttError = ttError + ", Approvers not defined".
		END.
		
		IF (ttApprover1 	<> ""  	AND INDEX(ttApprover1,"|") 	= 0) OR 
		   (ttApprover2 	<> ""  	AND INDEX(ttApprover2,"|") 	= 0) OR 
		   (ttApprover3 	<> ""  	AND INDEX(ttApprover3,"|") 	= 0) OR 
		   (ttApprover4 	<> ""  	AND INDEX(ttApprover4,"|") 	= 0) OR 
		   (ttApprover5 	<> ""  	AND INDEX(ttApprover5,"|") 	= 0) OR 
		   (ttApprover6 	<> ""  	AND INDEX(ttApprover6,"|") 	= 0) OR 
		   (ttApprover7 	<> ""  	AND INDEX(ttApprover7,"|") 	= 0) OR 
		   (ttApprover8 	<> ""  	AND INDEX(ttApprover8,"|") 	= 0) OR 
		   (ttApprover9 	<> ""  	AND INDEX(ttApprover9,"|") 	= 0) OR 
		   (ttApprover10 	<> ""  	AND INDEX(ttApprover10,"|") = 0) OR 
		   (ttApprover11 	<> ""  	AND INDEX(ttApprover11,"|") = 0) OR 
		   (ttApprover12 	<> ""  	AND INDEX(ttApprover12,"|") = 0) OR 
		   (ttApprover13 	<> ""  	AND INDEX(ttApprover13,"|") = 0) OR 
		   (ttApprover14 	<> ""  	AND INDEX(ttApprover14,"|") = 0) OR 
		   (ttApprover15 	<> ""  	AND INDEX(ttApprover15,"|")	= 0)
		THEN DO:
			ASSIGN ttProcess = NO.
			
			IF ttError = "" 
			THEN
				ASSIGN ttError = "Approver details not defined correctly".
			ELSE
				ASSIGN ttError = ttError + ", Approver details not defined correctly".
		END.
	END. /*FOR EACH ttApproversImport*/
	
	FOR EACH ttApproversImport
		WHERE ttProcess = YES:
		FIND FIRST xxdoaappr_mstr
			 WHERE xxdoaappr_domain 		= global_domain 			AND
				   xxdoaappr_type   		= TRIM(ttRuleType)			AND
				   xxdoaappr_businessline 	= TRIM(ttRuleBusinessLine) 	AND
				   xxdoaappr_site   		= TRIM(ttRuleSite)						   
		EXCLUSIVE-LOCK NO-ERROR.
		IF NOT AVAILABLE xxdoaappr_mstr 
		THEN DO:
			CREATE xxdoaappr_mstr.
			ASSIGN 
				xxdoaappr_domain 		= global_domain 
				xxdoaappr_type   		= TRIM(ttRuleType)
				xxdoaappr_businessline 	= TRIM(ttRuleBusinessLine)
				xxdoaappr_site 			= TRIM(ttRuleSite)
				.
		END. /*IF NOT AVAILABLE xxdoaappr_mstr*/
			
		ASSIGN 
			xxdoaappr_approvers[1]		= REPLACE(ttApprover1," ","")		
			xxdoaappr_approvers[2]		= REPLACE(ttApprover2," ","")	
			xxdoaappr_approvers[3]		= REPLACE(ttApprover3," ","")	
			xxdoaappr_approvers[4]		= REPLACE(ttApprover4," ","")	
			xxdoaappr_approvers[5]		= REPLACE(ttApprover5," ","")	
			xxdoaappr_approvers[6]		= REPLACE(ttApprover6," ","")	
			xxdoaappr_approvers[7]		= REPLACE(ttApprover7," ","")	
			xxdoaappr_approvers[8]		= REPLACE(ttApprover8," ","")	
			xxdoaappr_approvers[9]		= REPLACE(ttApprover9," ","")	
			xxdoaappr_approvers[10]		= REPLACE(ttApprover10," ","")	
			xxdoaappr_approvers[11]		= REPLACE(ttApprover11," ","")	
			xxdoaappr_approvers[12]		= REPLACE(ttApprover12," ","")	
			xxdoaappr_approvers[13]		= REPLACE(ttApprover13," ","")	
			xxdoaappr_approvers[14]		= REPLACE(ttApprover14," ","")	
			xxdoaappr_approvers[15]		= REPLACE(ttApprover15," ","")	
			xxdoaappr_LastModifiedDate  = TODAY
			xxdoaappr_LastModifiedTime  = TIME
			xxdoaappr_LastModifiedUser  = global_userid
			.
	END. /*FOR EACH ttApproversImport*/
	
	OUTPUT TO VALUE(lvc_outFile).
	EXPORT DELIMITER ","
		"Rule Type"
		"Business Line"
		"Site"
		"Approver 1"
		"Approver 2"
		"Approver 3"
		"Approver 4"
		"Approver 5"
		"Approver 6"
		"Approver 7"
		"Approver 8"
		"Approver 9"
		"Approver 10"
		"Approver 11"
		"Approver 12"
		"Approver 13"
		"Approver 14"
		"Approver 15"
		"Processed"
		"Error Message"
		.
		
	FOR EACH ttApproversImport:
		EXPORT DELIMITER ","
             ttRuleType  			 
             ttRuleBusinessLine     
             ttRuleSite       		     	 		
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
			 ttApprover11	    	
			 ttApprover12	    	
			 ttApprover13	    	
			 ttApprover14	    	
			 ttApprover15	    	
	         ttProcess 
	         ttError
			 .
	END. /*FOR EACH ttApproversImport*/
	OUTPUT CLOSE.
	
	OUTPUT TO VALUE(lvc_msgfilename).
	PUT UNFORMATTED "Please find attached result of DOA Approvers Upload Utilty run.".
	OUTPUT CLOSE.
	
	IF SEARCH(lvc_outFile) <> ? AND lvc_EmailID <> ""
	THEN DO:
		ASSIGN lvc_oscommand = "mailx -s 'DOA Approvers Upload Result' -a " + lvc_outFile + " " + lvc_EmailID + " < " + lvc_msgfilename.
		OS-COMMAND SILENT VALUE(lvc_oscommand).	
		{us/bbi/pxmsg.i &MSGTEXT='"Processing completed. Result is sent on email."' &ERRORLEVEL=1}
	END.
	
	OS-DELETE VALUE(lvc_inpFile).
	OS-DELETE VALUE(lvc_outFile).
	OS-DELETE VALUE(lvc_msgfilename).
	
END. /*mainloop*/
	   