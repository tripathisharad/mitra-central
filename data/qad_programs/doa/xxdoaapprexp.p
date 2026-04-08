/* PSC: xxdoaapprexp.p - DOA Approvers Export Utility 	                */
/*                                                                      */
/* CREATED: 20 Aug 2024   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

{us/mf/mfdtitle.i}

DEFINE VARIABLE lvc_outFile				AS CHARACTER 	NO-UNDO INITIAL "DOA_Approvers_Export.csv".
DEFINE VARIABLE lvc_msgfilename         AS CHARACTER	NO-UNDO INITIAL "MailBody.txt".
DEFINE VARIABLE lvc_ruletype			AS CHARACTER 	FORMAT "x(40)"  NO-UNDO.
DEFINE VARIABLE lvc_rulebusinessline  	AS CHARACTER 	FORMAT "x(40)" 	NO-UNDO.
DEFINE VARIABLE lvc_rulesite          	AS CHARACTER 	FORMAT "x(30)" 	NO-UNDO.
DEFINE VARIABLE lvc_oscommand 			AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_EmailID				AS CHARACTER	NO-UNDO FORMAT "x(200)" VIEW-AS FILL-IN SIZE 50 BY 1.
	   
FORM
   lvc_ruletype           COLON 15 LABEL "Rule Type"
   lvc_rulebusinessline   COLON 15 LABEL "Business Line"
   lvc_rulesite           COLON 15 LABEL "Site"
   lvc_EmailID 			  COLON 15 LABEL "Email"
   WITH FRAME a
   SIDE-LABELS
   WIDTH 80.
   
setFrameLabels(FRAME a:HANDLE).
	   
mainloop:	   
REPEAT:
	FIND FIRST usr_mstr WHERE usr_userid = global_userid NO-LOCK NO-ERROR.
	IF AVAILABLE usr_mstr AND usr_mail_address <> "" 
	THEN
		ASSIGN lvc_EmailID = usr_mail_address.
	
	ASSIGN 
		lvc_ruletype 			= ""
		lvc_rulebusinessline 	= ""
		lvc_rulesite 			= "".
		
	UPDATE 
		lvc_ruletype
		lvc_rulebusinessline
		lvc_rulesite
		lvc_EmailID
	WITH FRAME a.

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
		"Rule Type"
		"Business Line"
		"Site"
		"Approver Designation-Email 1"
		"Approver Designation-Email 2"
		"Approver Designation-Email 3"
		"Approver Designation-Email 4"
		"Approver Designation-Email 5"
		"Approver Designation-Email 6"
		"Approver Designation-Email 7"
		"Approver Designation-Email 8"
		"Approver Designation-Email 9"
		"Approver Designation-Email 10"
		"Approver Designation-Email 11"
		"Approver Designation-Email 12"
		"Approver Designation-Email 13"
		"Approver Designation-Email 14"
		"Approver Designation-Email 15"
		.
	
	FOR EACH xxdoaappr_mstr
		WHERE xxdoaappr_domain 		= global_domain 										AND
			  (lvc_ruletype    		= "" OR xxdoaappr_type  		= lvc_ruletype) 		AND
			  (lvc_rulebusinessline = "" OR xxdoaappr_businessline 	= lvc_rulebusinessline) AND
			  (lvc_rulesite 		= "" OR xxdoaappr_site 			= lvc_rulesite)
		NO-LOCK:
		EXPORT DELIMITER ","
             xxdoaappr_type  			 
             xxdoaappr_businessline     
             xxdoaappr_site       		     	 		
	         xxdoaappr_approvers[1]	    	
	         xxdoaappr_approvers[2]	   
	         xxdoaappr_approvers[3]	     	
	         xxdoaappr_approvers[4]	   	
	         xxdoaappr_approvers[5]	    	
	         xxdoaappr_approvers[6]	    	
	         xxdoaappr_approvers[7]	       	
	         xxdoaappr_approvers[8]	      	
	         xxdoaappr_approvers[9]	     	
	         xxdoaappr_approvers[10]	   	
			 xxdoaappr_approvers[11]	    	
			 xxdoaappr_approvers[12]	      	
			 xxdoaappr_approvers[13]	     	
			 xxdoaappr_approvers[14]	   
			 xxdoaappr_approvers[15]	   
			 .
	END. /*FOR EACH xxdoaappr_mstr*/
	OUTPUT CLOSE.
	
	OUTPUT TO VALUE(lvc_msgfilename).
	PUT UNFORMATTED "Please find attached DOA Approvers Export.".
	OUTPUT CLOSE.
	
	IF SEARCH(lvc_outFile) <> ? AND lvc_EmailID <> ""
	THEN DO:
		ASSIGN lvc_oscommand = "mailx -s 'DOA Approvers Export' -a " + lvc_outFile + " " + lvc_EmailID + " < " + lvc_msgfilename.
		OS-COMMAND SILENT VALUE(lvc_oscommand).	
		{us/bbi/pxmsg.i &MSGTEXT='"Processing completed. Data export file is sent on email."' &ERRORLEVEL=1}
	END.
	
	OS-DELETE VALUE(lvc_outFile).
	OS-DELETE VALUE(lvc_msgfilename).
	
END. /*mainloop*/
	   