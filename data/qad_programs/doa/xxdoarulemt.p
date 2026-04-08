/* PSC: xxdoarulemt.p - DOA Rule Maintenance                            */
/*                                                                      */
/* CREATED: 22 May 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

{us/mf/mfdtitle.i}
{us/gp/gpnbrgen.i}

&GLOBAL-DEFINE OPERATOREQ   	=
&GLOBAL-DEFINE OPERATORGT   	>
&GLOBAL-DEFINE OPERATORLT   	<
&GLOBAL-DEFINE OPERATORGE   	>=
&GLOBAL-DEFINE OPERATORLE   	<=
&GLOBAL-DEFINE OPERATORNE   	<>
&GLOBAL-DEFINE OPERATORMATCHES  MATCHES
&GLOBAL-DEFINE OPERATORBEGINS   BEGINS

DEFINE VARIABLE lvc_rulecode          AS CHARACTER 	FORMAT "x(40)" 	NO-UNDO.
DEFINE VARIABLE lvc_ruletype          AS CHARACTER 	FORMAT "x(40)" 	NO-UNDO.
DEFINE VARIABLE lvc_rulebusinessline  AS CHARACTER 	FORMAT "x(40)" 	NO-UNDO.
DEFINE VARIABLE lvc_businesslinecmmt  AS CHARACTER 	FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvc_rulesite          AS CHARACTER 	FORMAT "x(30)" 	NO-UNDO.
DEFINE VARIABLE lvc_sitecmmt          AS CHARACTER 	FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvc_ruleactive        AS LOGICAL 					NO-UNDO.
DEFINE VARIABLE lvc_rule              AS CHARACTER 	FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvc_approvers         AS CHARACTER 	FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvc_notifyto          AS CHARACTER 	FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvi_count             AS INTEGER 					NO-UNDO.
DEFINE VARIABLE del-yn                AS LOGICAL 					NO-UNDO.
DEFINE VARIABLE lvc_RuleValue   	  AS CHARACTER 			 		NO-UNDO.
DEFINE VARIABLE lvc_tablename   	  AS CHARACTER 			 		NO-UNDO.
DEFINE VARIABLE lvc_errorMsg    	  AS CHARACTER 			 		NO-UNDO.
DEFINE VARIABLE lvl_iserror           AS LOGICAL 					NO-UNDO.
DEFINE VARIABLE lvi_errorNum          AS INTEGER 					NO-UNDO.
DEFINE VARIABLE htable 			 	  AS HANDLE						NO-UNDO.   

DEFINE TEMP-TABLE ttRule
       FIELD      ttRuleSeq      	AS CHARACTER FORMAT "x(3)"
       FIELD      ttRuleTableField  AS CHARACTER FORMAT "x(40)"   VIEW-AS FILL-IN SIZE 20 BY 1
       FIELD      ttRuleOperator    AS CHARACTER FORMAT "x(8)"    VIEW-AS COMBO-BOX  LIST-ITEMS "{&OPERATOREQ}", "{&OPERATORGT}", "{&OPERATORLT}", "{&OPERATORGE}", "{&OPERATORLE}", "{&OPERATORNE}", "{&OPERATORMATCHES}", "{&OPERATORBEGINS}"
       FIELD      ttRuleValue       AS CHARACTER FORMAT "x(5000)" VIEW-AS FILL-IN SIZE 40 BY 1.
       
DEFINE TEMP-TABLE ttApprover
       FIELD      ttApproverSeq     AS CHARACTER FORMAT "x(3)"
       FIELD      ttApproverCode    AS CHARACTER FORMAT "x(100)" VIEW-AS FILL-IN SIZE 20 BY 1.
       
DEFINE TEMP-TABLE ttNotify
       FIELD      ttNotifySeq       AS CHARACTER FORMAT "x(3)"
       FIELD      ttNotifyValue     AS CHARACTER FORMAT "x(100)" VIEW-AS FILL-IN SIZE 20 BY 1.
              
FORM
   lvc_rulecode           COLON 25 LABEL "Rule Code"
   lvc_ruletype           COLON 25 LABEL "Rule Type"
   lvc_rulebusinessline   COLON 25 LABEL "Business Line"
   lvc_businesslinecmmt   COLON 27 NO-LABEL
   lvc_rulesite           COLON 25 LABEL "Site"
   lvc_sitecmmt           COLON 27 NO-LABEL
   lvc_ruleactive         COLON 25 LABEL "Active"
   lvc_rule               COLON 25 LABEL "DOA Rule"
   lvc_approvers          COLON 25 LABEL "Approvers"
   lvc_notifyto           COLON 25 LABEL "Notify To"
   WITH FRAME a
   SIDE-LABELS
   WIDTH 200.

setFrameLabels(FRAME a:HANDLE).

FORM
   ttRule.ttRuleSeq         COLUMN-LABEL "Seq"
   ttRule.ttRuleTableField  COLUMN-LABEL "Rule Field"   
   ttRule.ttRuleOperator    COLUMN-LABEL "Operator"
   ttRule.ttRuleValue       COLUMN-LABEL "Value" 
   WITH FRAME frm_rule
   TITLE getFrameTitle("DOA_RULE",30)
   WIDTH 200.
   
setFrameLabels(FRAME frm_rule:HANDLE).

FORM
   ttApprover.ttApproverSeq   COLUMN-LABEL "Seq"
   ttApprover.ttApproverCode  COLUMN-LABEL "Approver Code"   
   WITH FRAME frm_appr
   TITLE getFrameTitle("DOA_APPROVERS",30)
   WIDTH 100.
   
setFrameLabels(FRAME frm_appr:HANDLE).

FORM
   ttNotify.ttNotifySeq   COLUMN-LABEL "Seq"
   ttNotify.ttNotifyValue COLUMN-LABEL "Notify To"   
   WITH FRAME frm_noti
   TITLE getFrameTitle("DOA_NOTIFY_TO",30)
   WIDTH 100.
   
setFrameLabels(FRAME frm_noti:HANDLE).

mainloop:
REPEAT:
	ASSIGN
		lvc_businesslinecmmt = "(Leave Business Line field BLANK to apply the rule to all Business Lines)"
		lvc_sitecmmt         = "(Leave Site field BLANK to apply the rule to all Sites)".
		
	DISPLAY 
		lvc_businesslinecmmt
		lvc_sitecmmt
	WITH FRAME a.
		
    HIDE FRAME frm_rule.
    HIDE FRAME frm_appr.
    HIDE FRAME frm_noti.
    
    EMPTY TEMP-TABLE ttRule     NO-ERROR.
    EMPTY TEMP-TABLE ttApprover NO-ERROR.
    EMPTY TEMP-TABLE ttNotify   NO-ERROR.
    
    UPDATE
        lvc_rulecode
    WITH FRAME a
    EDITING:
        /* FIND NEXT/PREVIOUS RECORD */
        {us/mf/mfnp05.i xxdoarule_mstr
                 xxdoarule_domcode
                 " xxdoarule_domain = global_domain "
                 xxdoarule_code
                 " INPUT lvc_rulecode"}

        IF recno NE ?
        THEN DO:
            ASSIGN 
                lvc_rulecode          = xxdoarule_code
                lvc_ruletype          = xxdoarule_type
                lvc_rulebusinessline  = xxdoarule_businessline
                lvc_rulesite          = xxdoarule_site
                lvc_ruleactive        = xxdoarule_active
                lvc_rule              = ""
                lvc_approvers         = ""
                lvc_notifyto          = "".
                
            DO lvi_count = 1 TO 15:                
                IF xxdoarule_rule[lvi_count] NE ""
                THEN DO:
                    IF lvc_rule = "" 
                    THEN
                        ASSIGN lvc_rule = REPLACE(xxdoarule_rule[lvi_count],"|"," ").
                    ELSE 
                        ASSIGN lvc_rule = lvc_rule + " and " + REPLACE(xxdoarule_rule[lvi_count],"|"," ").
                END.
            END.
            
            DO lvi_count = 1 TO 10:
                IF xxdoarule_approvers[lvi_count] NE ""
                THEN DO:
                    IF lvc_approvers = "" 
                    THEN
                        ASSIGN lvc_approvers = xxdoarule_approvers[lvi_count].
                    ELSE 
                        ASSIGN lvc_approvers = lvc_approvers + " --> " + xxdoarule_approvers[lvi_count].
                END.
            END.
            
            DO lvi_count = 1 TO 10:
                IF xxdoarule_notifyto[lvi_count] NE ""
                THEN DO:
                    IF lvc_notifyto = "" 
                    THEN
                        ASSIGN lvc_notifyto = xxdoarule_notifyto[lvi_count].
                    ELSE 
                        ASSIGN lvc_notifyto = lvc_notifyto + ", " + xxdoarule_notifyto[lvi_count].
                END.
            END.                      
                
            DISPLAY
                lvc_rulecode
                lvc_ruletype
                lvc_rulebusinessline
                lvc_rulesite
                lvc_ruleactive
                lvc_rule
                lvc_approvers
                lvc_notifyto
            WITH FRAME a.
        END. /* IF recno NE ? */
    END. /* EDITING */
    
    IF lvc_rulecode EQ ""
    THEN DO:
        FIND FIRST code_mstr 
             WHERE code_domain  EQ global_domain  AND
                   code_fldname EQ "DOA_RULE"     AND
                   code_value   EQ "SEQUENCE_ID"
        NO-LOCK NO-ERROR.
        IF NOT AVAILABLE code_mstr 
        THEN DO:
            ASSIGN lvc_errorMsg = "Please Maintain Rule Sequence in GCM.".
            {us/bbi/pxmsg.i &MSGNUM=2685 &ERRORLEVEL=3 &MSGARG1=lvc_errorMsg}
            UNDO mainloop, RETRY mainloop.
        END.
        ELSE DO:
            RUN getnbr
                (INPUT  TRIM(code_cmmt),
                 INPUT  TODAY,
                 OUTPUT lvc_rulecode,
                 OUTPUT lvl_iserror,
                 OUTPUT lvi_errorNum).
            
            IF lvl_iserror 
            THEN DO:
                {us/bbi/pxmsg.i &MSGNUM=lvi_errorNum &ERRORLEVEL=3}
                UNDO mainloop, RETRY mainloop.
            END.
            
            DISPLAY 
                lvc_rulecode
            WITH FRAME a.
        END.
    END. /* IF lvc_rulecode EQ "" */
    
    FIND FIRST xxdoarule_mstr
         WHERE xxdoarule_mstr.xxdoarule_domain = global_domain AND
               xxdoarule_mstr.xxdoarule_code   = lvc_rulecode
    EXCLUSIVE-LOCK NO-ERROR.
         
    IF NOT AVAILABLE xxdoarule_mstr 
    THEN DO:    
		/* ADDING NEW RECORD */
		{us/bbi/pxmsg.i &MSGNUM=1 &ERRORLEVEL=1}
		
        CREATE xxdoarule_mstr.
        ASSIGN  
            xxdoarule_domain = global_domain
            xxdoarule_code   = lvc_rulecode.
            
        ASSIGN 
            lvc_ruletype          = ""
            lvc_rulebusinessline  = ""
            lvc_rulesite          = ""
            lvc_ruleactive        = NO
            lvc_rule              = ""
            lvc_approvers         = ""
            lvc_notifyto          = "".
            
        DO lvi_count = 1 TO 15:
            CREATE ttRule.
            ASSIGN ttRule.ttRuleSeq = STRING(lvi_count).
        END.
        
        DO lvi_count = 1 TO 10:
            CREATE ttApprover.
            ASSIGN ttApprover.ttApproverSeq = STRING(lvi_count).
        END.
        
        DO lvi_count = 1 TO 10:
            CREATE ttNotify.
            ASSIGN ttNotify.ttNotifySeq = STRING(lvi_count).
        END.
    END. /* IF NOT AVAILABLE xxdoarule_mstr */
    ELSE DO:
		/* MODIFYING EXISTING RECORD */
		{us/bbi/pxmsg.i &MSGNUM=10 &ERRORLEVEL=1}
		
        ASSIGN 
            lvc_ruletype          = xxdoarule_type
            lvc_rulebusinessline  = xxdoarule_businessline
            lvc_rulesite          = xxdoarule_site
            lvc_ruleactive        = xxdoarule_active
            lvc_rule              = ""
            lvc_approvers         = ""
            lvc_notifyto          = "".
        
        /* FILL TEMP-TABLES WITH INFORMATION IF xxdoarule_mstr RECORD EXISTS */
        DO lvi_count = 1 TO 15:
            CREATE ttRule.
            ASSIGN ttRule.ttRuleSeq = STRING(lvi_count).
            
            IF xxdoarule_rule[lvi_count] NE ""
            THEN DO:
                ASSIGN 
                    ttRule.ttRuleTableField   = ENTRY(1,xxdoarule_rule[lvi_count],"|")
                    ttRule.ttRuleOperator     = ENTRY(2,xxdoarule_rule[lvi_count],"|")
                    ttRule.ttRuleValue        = ENTRY(3,xxdoarule_rule[lvi_count],"|").
                    
                IF lvc_rule = "" 
                THEN
                    ASSIGN lvc_rule = REPLACE(xxdoarule_rule[lvi_count],"|"," ").
                ELSE 
                    ASSIGN lvc_rule = lvc_rule + " and " + REPLACE(xxdoarule_rule[lvi_count],"|"," ").
            END. /* IF xxdoarule_rule[lvi_count] NE "" */
        END. /* DO lvi_count = 1 TO 15 */
        
        DO lvi_count = 1 TO 10:
            CREATE ttApprover.
            ASSIGN ttApprover.ttApproverSeq = STRING(lvi_count).
            
            IF xxdoarule_approvers[lvi_count] NE ""
            THEN DO:
                ASSIGN ttApprover.ttApproverCode = TRIM(xxdoarule_approvers[lvi_count]).
                
                IF lvc_approvers = "" 
                THEN
                    ASSIGN lvc_approvers = xxdoarule_approvers[lvi_count].
                ELSE 
                    ASSIGN lvc_approvers = lvc_approvers + " --> " + xxdoarule_approvers[lvi_count].
            END.
        END. /* DO lvi_count = 1 TO 10 */
        
        DO lvi_count = 1 TO 10:
            CREATE ttNotify.
            ASSIGN ttNotify.ttNotifySeq = STRING(lvi_count).
            
            IF xxdoarule_notifyto[lvi_count] NE ""
            THEN DO:
                ASSIGN ttNotify.ttNotifyValue = TRIM(xxdoarule_notifyto[lvi_count]).
                
                IF lvc_notifyto = "" 
                THEN
                    ASSIGN lvc_notifyto = xxdoarule_notifyto[lvi_count].
                ELSE 
                    ASSIGN lvc_notifyto = lvc_notifyto + ", " + xxdoarule_notifyto[lvi_count].
            END.
        END.  /* DO lvi_count = 1 TO 10 */  
    END.
    
    DISPLAY
        lvc_ruletype
        lvc_rulebusinessline
        lvc_rulesite
        lvc_ruleactive
        lvc_rule
        lvc_approvers
        lvc_notifyto
    WITH FRAME a.    
    
    ASSIGN ststatus = stline[2].
    STATUS INPUT ststatus.
	
	{us/gp/gpbrparm.i &browse=gplu806.p &parm=c-brparm1 &val=""DOA_RULE_TYPE""}
      
    UPDATE 
        lvc_ruletype
        lvc_rulebusinessline
        lvc_rulesite
        lvc_ruleactive
    GO-ON(F5 CTRL-D)
    WITH FRAME a.
    
    IF LASTKEY EQ KEYCODE("F5")  OR
       LASTKEY EQ KEYCODE("CTRL-D")
    THEN DO:
        ASSIGN del-yn = YES.

        /* PLEASE CONFIRM DELETE */
        {us/bbi/pxmsg.i &MSGNUM=11 &ERRORLEVEL=1 &CONFIRM=del-yn}

        IF del-yn
        THEN DO:
            DELETE xxdoarule_mstr.
            RELEASE xxdoarule_mstr NO-ERROR.
			
			ASSIGN 
				lvc_rulecode          	= ""
				lvc_ruletype          	= ""
				lvc_rulebusinessline  	= ""
				lvc_rulesite          	= ""
				lvc_ruleactive        	= NO
				lvc_rule              	= ""
				lvc_approvers         	= ""
				lvc_notifyto          	= "".
				
			DISPLAY 
				lvc_rulecode
				lvc_ruletype
				lvc_rulebusinessline
				lvc_rulesite
				lvc_ruleactive
				lvc_rule
				lvc_approvers
				lvc_notifyto
			WITH FRAME a.
        END.
        
        NEXT mainloop.
    END. /* IF LASTKEY EQ KEYCODE("F5") */

    IF lvc_ruletype EQ ""
    THEN DO:
        {us/bbi/pxmsg.i &MSGNUM=40 &ERRORLEVEL=3}
        NEXT-PROMPT lvc_ruletype WITH FRAME a.
        UNDO mainloop, RETRY mainloop.
    END.
	
	FIND FIRST code_mstr
		 WHERE code_domain 	EQ global_domain 	AND
			   code_fldname EQ "DOA_RULE_TYPE" 	AND
			   code_value   EQ lvc_ruletype 	AND
			   code_cmmt    NE ""
	NO-LOCK NO-ERROR.
	IF NOT AVAILABLE code_mstr 
	THEN DO:
		/* DOA RULE TYPE NOT MAINTAINED IN GCM */
		ASSIGN lvc_errorMsg = "Rule Type not maintained in GCM. FieldName - DOA_RULE_TYPE".
		{us/bbi/pxmsg.i &MSGNUM=2685 &ERRORLEVEL=3 &MSGARG1=lvc_errorMsg}
		UNDO mainloop, RETRY mainloop.
	END.
	/* IF AVAILABLE code_mstr THEN GET DB TABLE NAME ASSOCIATED WITH RULE TYPE */
	ASSIGN lvc_tablename = TRIM(code_mstr.code_cmmt).
	
	CREATE BUFFER htable FOR TABLE lvc_tablename.
	
	ASSIGN
		xxdoarule_type 				= lvc_ruletype
		xxdoarule_businessline 		= lvc_rulebusinessline
		xxdoarule_site 				= lvc_rulesite
		xxdoarule_active 			= lvc_ruleactive
        xxdoarule_LastModifiedDate  = TODAY
        xxdoarule_LastModifiedTime  = TIME
        xxdoarule_LastModifiedUser  = global_userid.
		
	ASSIGN ststatus = stline[1].
    STATUS INPUT ststatus.
  
	RUN updateRules(RECID(xxdoarule_mstr)).
	
	HIDE FRAME frm_rule.
	
	RUN updateApprovers(RECID(xxdoarule_mstr)).
	
    HIDE FRAME frm_appr.
	
	RUN updateNotifyTo(RECID(xxdoarule_mstr)).
    
    RELEASE xxdoarule_mstr NO-ERROR.
	
	DELETE OBJECT htable.
END. /* mainloop */


PROCEDURE updateRules:
	DEFINE INPUT PARAMETER 	ip_recid 	AS RECID 		NO-UNDO.
	
	DEFINE VARIABLE 		rRecordID  	AS RECID 		NO-UNDO.
	DEFINE BUFFER buff_xxdoarule_mstr 	FOR xxdoarule_mstr.
	
	ASSIGN lvc_rule = "".
	
	{us/gp/gpbrparm.i &browse=xxlu716.p &parm=c-brparm1 &val=lvc_tablename}
	
    ruleloop:
	REPEAT:
        {us/sw/swselect.i
			  &record-id	= rRecordID
			  &scroll-field = ttRule.ttRuleSeq
              &detfile      = ttRule
              &display1     = ttRule.ttRuleSeq
              &display2     = ttRule.ttRuleTableField
              &display3     = ttRule.ttRuleOperator
              &display4     = ttRule.ttRuleValue
              &sel_on       = "ttRule.ttRuleSeq"
              &sel_off      = "ttRule.ttRuleSeq"
              &exit-flag    = TRUE
              &exitlabel    = ruleloop
              &framename    = "frm_rule"
              &framesize    = 15
			  &include1     = "{us/xx/xxruleupd.i}"}

        /* END-ERROR DURING ENTRY */
        IF KEYFUNCTION(LASTKEY) EQ "END-ERROR"
        THEN DO:
			FIND FIRST buff_xxdoarule_mstr 
				 WHERE RECID(buff_xxdoarule_mstr) = ip_recid 
			EXCLUSIVE-LOCK NO-ERROR.
			IF AVAILABLE buff_xxdoarule_mstr 
			THEN DO:
				ASSIGN buff_xxdoarule_mstr.xxdoarule_rule = "".
				
				FOR EACH ttRule
					WHERE ttRule.ttRuleTableField NE "":  
					
					ASSIGN lvc_RuleValue = ttRule.ttRuleValue.
					/*
					CASE htable:BUFFER-FIELD(ttRule.ttRuleTableField):DATA-TYPE:
						WHEN "CHARACTER" THEN ASSIGN lvc_RuleValue = QUOTER(ttRule.ttRuleValue).
					END CASE.
				    */
					ASSIGN
						buff_xxdoarule_mstr.xxdoarule_rule[INT(ttRule.ttRuleSeq)] = ttRule.ttRuleTableField + "|" + ttRule.ttRuleOperator + "|" + lvc_RuleValue.

					IF lvc_rule = "" 
					THEN
						ASSIGN lvc_rule = REPLACE(buff_xxdoarule_mstr.xxdoarule_rule[INT(ttRule.ttRuleSeq)],"|"," ").
					ELSE 
						ASSIGN lvc_rule = lvc_rule + " and " + REPLACE(buff_xxdoarule_mstr.xxdoarule_rule[INT(ttRule.ttRuleSeq)],"|"," ").
				END. /* FOR EACH ttRule */
			END.
			
			LEAVE ruleloop.
        END. /* IF KEYFUNCTION(LASTKEY) EQ "END-ERROR" */
    END. /* ruleloop */

	DISPLAY 
        lvc_rule
    WITH FRAME a.
	
	PAUSE(0).
END. /* updateRules */


PROCEDURE updateApprovers:
	DEFINE INPUT PARAMETER 	ip_recid 	AS RECID NO-UNDO.
	DEFINE VARIABLE 		rRecordID  	AS RECID NO-UNDO.
	
	DEFINE BUFFER buff_xxdoarule_mstr FOR xxdoarule_mstr.
		
    ASSIGN lvc_approvers = "".
	
	{us/gp/gpbrparm.i &browse=gplu806.p &parm=c-brparm1 &val=""DOA_APPROVER_CODES""}
	
    approverloop:
	REPEAT:
		{us/sw/swselect.i
			  &record-id	= rRecordID
			  &scroll-field = ttApprover.ttApproverSeq
			  &detfile      = ttApprover
			  &display1     = ttApprover.ttApproverSeq
			  &display2     = ttApprover.ttApproverCode
			  &sel_on       = "ttApprover.ttApproverSeq"
			  &sel_off      = "ttApprover.ttApproverSeq"
			  &exit-flag    = TRUE
			  &exitlabel    = approverloop
			  &framename    = "frm_appr"
			  &framesize    = 10
			  &include1     = "{us/xx/xxapprupd.i}"}

        /* END-ERROR DURING ENTRY */
        IF KEYFUNCTION(LASTKEY) EQ "END-ERROR"
        THEN DO:
			FIND FIRST buff_xxdoarule_mstr 
				 WHERE RECID(buff_xxdoarule_mstr) = ip_recid 
			EXCLUSIVE-LOCK NO-ERROR.
			IF AVAILABLE buff_xxdoarule_mstr 
			THEN DO:
				ASSIGN buff_xxdoarule_mstr.xxdoarule_approvers = "".
				
				FOR EACH ttApprover
					WHERE ttApprover.ttApproverCode NE "":  
					ASSIGN
						buff_xxdoarule_mstr.xxdoarule_approvers[INT(ttApprover.ttApproverSeq)] = ttApprover.ttApproverCode.
					  
					IF lvc_approvers = "" 
					THEN
						ASSIGN lvc_approvers = buff_xxdoarule_mstr.xxdoarule_approvers[INT(ttApprover.ttApproverSeq)].
					ELSE 
						ASSIGN lvc_approvers = lvc_approvers + " --> " + buff_xxdoarule_mstr.xxdoarule_approvers[INT(ttApprover.ttApproverSeq)].
				END. /* FOR EACH ttApprover */
			END.
			
			LEAVE approverloop.
        END. /* IF KEYFUNCTION(LASTKEY) EQ "END-ERROR" */
    END. /* approverloop */   
    
    DISPLAY 
        lvc_approvers
    WITH FRAME a.
	
	PAUSE(0).
END. /* updateApprovers */

PROCEDURE updateNotifyTo:
	DEFINE INPUT PARAMETER 	ip_recid 	AS RECID NO-UNDO.
	DEFINE VARIABLE 		rRecordID  	AS RECID NO-UNDO.
	
	DEFINE BUFFER buff_xxdoarule_mstr FOR xxdoarule_mstr.
		
    ASSIGN lvc_notifyto = "".
	
	{us/gp/gpbrparm.i &browse=gplu806.p &parm=c-brparm1 &val=""DOA_APPROVER_CODES""}
	
    notifyloop:
	REPEAT:
		{us/sw/swselect.i
			  &record-id	= rRecordID
			  &scroll-field = ttNotify.ttNotifySeq
			  &detfile      = ttNotify
			  &display1     = ttNotify.ttNotifySeq
			  &display2     = ttNotify.ttNotifyValue
			  &sel_on       = "ttNotify.ttNotifySeq"
			  &sel_off      = "ttNotify.ttNotifySeq"
			  &exit-flag    = TRUE
			  &exitlabel    = notifyloop
			  &framename    = "frm_noti"
			  &framesize    = 10
			  &include1     = "{us/xx/xxnotifyupd.i}"}

        /* END-ERROR DURING ENTRY */
        IF KEYFUNCTION(LASTKEY) EQ "END-ERROR"
        THEN DO:
			FIND FIRST buff_xxdoarule_mstr 
				 WHERE RECID(buff_xxdoarule_mstr) = ip_recid 
			EXCLUSIVE-LOCK NO-ERROR.
			IF AVAILABLE buff_xxdoarule_mstr 
			THEN DO:
				ASSIGN buff_xxdoarule_mstr.xxdoarule_notifyto = "".
				
				FOR EACH ttNotify
					WHERE ttNotify.ttNotifyValue NE "":  
					ASSIGN
						buff_xxdoarule_mstr.xxdoarule_notifyto[INT(ttNotify.ttNotifySeq)] = ttNotify.ttNotifyValue.
					  
					IF lvc_notifyto = "" 
					THEN
						ASSIGN lvc_notifyto = buff_xxdoarule_mstr.xxdoarule_notifyto[INT(ttNotify.ttNotifySeq)].
					ELSE 
						ASSIGN lvc_notifyto = lvc_notifyto + ", " + buff_xxdoarule_mstr.xxdoarule_notifyto[INT(ttNotify.ttNotifySeq)].
				END. /* FOR EACH ttNotify */
			END.
			
			LEAVE notifyloop.
        END. /* IF KEYFUNCTION(LASTKEY) EQ "END-ERROR" */
    END. /* notifyloop */  
	
	DISPLAY 
        lvc_notifyto
    WITH FRAME a.
	
END. /* updateNotifyTo */