/* PSC: xxdoaapprmt.p - DOA Approver Maintenance                        */
/*                                                                      */
/* CREATED: 22 May 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

{us/mf/mfdtitle.i}

DEFINE VARIABLE lvc_ruletype          AS CHARACTER  FORMAT "x(40)" 	NO-UNDO.
DEFINE VARIABLE lvc_ruletypecmmt      AS CHARACTER  FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvc_rulebusinessline  AS CHARACTER  FORMAT "x(40)"  NO-UNDO.
DEFINE VARIABLE lvc_businesslinecmmt  AS CHARACTER  FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvc_rulesite          AS CHARACTER  FORMAT "x(30)"  NO-UNDO.
DEFINE VARIABLE lvc_sitecmmt          AS CHARACTER  FORMAT "x(100)" NO-UNDO.
DEFINE VARIABLE lvc_approvers         AS CHARACTER  FORMAT "x(200)" NO-UNDO VIEW-AS FILL-IN SIZE 60 BY 1.
DEFINE VARIABLE lvi_count             AS INTEGER    				NO-UNDO.
DEFINE VARIABLE del-yn                AS LOGICAL    				NO-UNDO. 
DEFINE VARIABLE rRecordID 			  AS RECID      				NO-UNDO.

DEFINE BUFFER buff_xxdoaappr_mstr FOR xxdoaappr_mstr.

DEFINE TEMP-TABLE ttApprovers
       FIELD      ttApproversSeq      AS CHARACTER  FORMAT "x(3)"
       FIELD      ttApproversCode     AS CHARACTER  FORMAT "x(20)"
       FIELD      ttApproversValue    AS CHARACTER  FORMAT "x(100)" VIEW-AS FILL-IN SIZE 20 BY 1
       FIELD      ttApproversAltValue AS CHARACTER  FORMAT "x(100)" VIEW-AS FILL-IN SIZE 20 BY 1.
              
FORM
    lvc_ruletype            COLON 25 LABEL "Rule Type"
    lvc_ruletypecmmt        COLON 27 NO-LABEL
    lvc_rulebusinessline    COLON 25 LABEL "Business Line"
    lvc_businesslinecmmt    COLON 27 NO-LABEL
    lvc_rulesite            COLON 25 LABEL "Site"
    lvc_sitecmmt            COLON 27 NO-LABEL
    lvc_approvers           COLON 25 LABEL "Approvers"
    WITH FRAME a
    SIDE-LABELS
    WIDTH 200.

setFrameLabels(FRAME a:HANDLE).

FORM
   ttApprovers.ttApproversSeq       COLUMN-LABEL "Seq"
   ttApprovers.ttApproversCode      COLUMN-LABEL "Approver Code"   
   ttApprovers.ttApproversValue     COLUMN-LABEL "Approver Email"
   ttApprovers.ttApproversAltValue  COLUMN-LABEL "Alternate Approver Email" 
   WITH FRAME frm_appr
   TITLE getFrameTitle("DOA_APPROVERS",30)
   WIDTH 200.
   
setFrameLabels(FRAME frm_appr:HANDLE).

mainloop:
REPEAT:

    HIDE FRAME frm_appr.
    EMPTY TEMP-TABLE ttApprovers  NO-ERROR.
    
    ASSIGN 
        lvc_ruletypecmmt     = "(Leave Rule Type field BLANK to set approvers irrespective of Rule Types)"
        lvc_businesslinecmmt = "(Leave Business Line field BLANK to set approvers irrespective of Business Lines)"
        lvc_sitecmmt         = "(Leave Site field BLANK to set approvers irrespective of Sites)".
		
	DISPLAY 
        lvc_ruletypecmmt
        lvc_businesslinecmmt
        lvc_sitecmmt
	WITH FRAME a.
	
	{us/gp/gpbrparm.i &browse=gplu806.p &parm=c-brparm1 &val=""DOA_RULE_TYPE""}

    UPDATE
        lvc_ruletype
        lvc_rulebusinessline
        lvc_rulesite
    WITH FRAME a
    EDITING:
        IF FRAME-FIELD = "lvc_ruletype"
        THEN DO:
            /* FIND NEXT/PREVIOUS RECORD */
            {us/mf/mfnp05.i xxdoaappr_mstr
                            xxdoaappr_domtypebussite
                            " xxdoaappr_domain = global_domain "
                            xxdoaappr_type
                            "INPUT lvc_ruletype"}
        END.
        ELSE IF FRAME-FIELD = "lvc_rulebusinessline" 
        THEN DO:
            /* FIND NEXT/PREVIOUS RECORD */
            {us/mf/mfnp05.i xxdoaappr_mstr
                            xxdoaappr_domtypebussite
                            " xxdoaappr_domain = global_domain and xxdoaappr_type = INPUT lvc_ruletype"
                            xxdoaappr_businessline
                            "INPUT lvc_rulebusinessline"}            
        END.
        ELSE IF FRAME-FIELD = "lvc_rulesite" 
        THEN DO:
            /* FIND NEXT/PREVIOUS RECORD */
            {us/mf/mfnp05.i xxdoaappr_mstr
                            xxdoaappr_domtypebussite
                            " xxdoaappr_domain = global_domain and xxdoaappr_type = INPUT lvc_ruletype and xxdoaappr_businessline = INPUT lvc_rulebusinessline"
                            xxdoaappr_site
                            "INPUT lvc_rulesite"}            
        END.
        
        IF recno NE ?
        THEN DO:
            ASSIGN 
                lvc_ruletype          = xxdoaappr_type
                lvc_rulebusinessline  = xxdoaappr_businessline
                lvc_rulesite          = xxdoaappr_site
                lvc_approvers         = "".
                
            DO lvi_count = 1 TO 15:                
                IF xxdoaappr_approvers[lvi_count] NE ""
                THEN DO:
                    IF lvc_approvers = "" 
                    THEN
                        ASSIGN lvc_approvers = REPLACE(xxdoaappr_approvers[lvi_count],"|"," - ").
                    ELSE 
                        ASSIGN lvc_approvers = lvc_approvers + " | " + REPLACE(xxdoaappr_approvers[lvi_count],"|"," - ").
                END.
            END.
                
            DISPLAY
                lvc_ruletype
                lvc_rulebusinessline
                lvc_rulesite
                lvc_approvers
            WITH FRAME a.
        END. /* IF recno NE ? */
    END. /* EDITING */
    
    FIND FIRST xxdoaappr_mstr
         WHERE xxdoaappr_mstr.xxdoaappr_domain        = global_domain         AND
               xxdoaappr_mstr.xxdoaappr_type          = lvc_ruletype          AND
               xxdoaappr_mstr.xxdoaappr_businessline  = lvc_rulebusinessline  AND
               xxdoaappr_mstr.xxdoaappr_site          = lvc_rulesite
    EXCLUSIVE-LOCK NO-ERROR.
         
    IF NOT AVAILABLE xxdoaappr_mstr 
    THEN DO:    
		/* ADDING NEW RECORD */
		{us/bbi/pxmsg.i &MSGNUM=1 &ERRORLEVEL=1}
		
        CREATE xxdoaappr_mstr.
        ASSIGN  
            xxdoaappr_domain        = global_domain
            xxdoaappr_type          = lvc_ruletype
            xxdoaappr_businessline  = lvc_rulebusinessline
            xxdoaappr_site          = lvc_rulesite.
            
        ASSIGN lvc_approvers = "".
            
        DO lvi_count = 1 TO 15:
            CREATE ttApprovers.
            ASSIGN ttApprovers.ttApproversSeq = STRING(lvi_count).
        END.
    END.
    ELSE DO:
		/* MODIFYING EXISTING RECORD */
		{us/bbi/pxmsg.i &MSGNUM=10 &ERRORLEVEL=1}
		
        ASSIGN lvc_approvers = "".
        
        /* FILL TEMP-TABLES WITH INFORMATION IF xxdoaappr_mstr RECORD EXISTS */
        DO lvi_count = 1 TO 15:
            CREATE ttApprovers.
            ASSIGN ttApprovers.ttApproversSeq = STRING(lvi_count).
            
            IF xxdoaappr_approvers[lvi_count] NE ""
            THEN DO:
                ASSIGN ttApprovers.ttApproversCode = ENTRY(1,xxdoaappr_approvers[lvi_count],"|").
					
				IF NUM-ENTRIES(ENTRY(2,xxdoaappr_approvers[lvi_count],"|"),",") EQ 1 
				THEN
					ASSIGN ttApprovers.ttApproversValue = ENTRY(1,ENTRY(2,xxdoaappr_approvers[lvi_count],"|"),",").
				
				IF NUM-ENTRIES(ENTRY(2,xxdoaappr_approvers[lvi_count],"|"),",") EQ 2 
				THEN
					ASSIGN 
						ttApprovers.ttApproversValue 	= ENTRY(1,ENTRY(2,xxdoaappr_approvers[lvi_count],"|"),",")
						ttApprovers.ttApproversAltValue = ENTRY(2,ENTRY(2,xxdoaappr_approvers[lvi_count],"|"),",").
                    
                IF lvc_approvers = "" 
                THEN
                    ASSIGN lvc_approvers = REPLACE(xxdoaappr_approvers[lvi_count],"|"," - ").
                ELSE 
                    ASSIGN lvc_approvers = lvc_approvers + " | " + REPLACE(xxdoaappr_approvers[lvi_count],"|"," - ").
            END. /* IF xxdoaappr_approvers[lvi_count] NE "" */
        END. /* DO lvi_count = 1 TO 15 */
    END.   
              
    DISPLAY
        lvc_approvers
    WITH FRAME a.    
    
    ASSIGN ststatus = stline[2].
    STATUS INPUT ststatus.
      
    UPDATE 
        lvc_approvers
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
            DELETE xxdoaappr_mstr.
            RELEASE xxdoaappr_mstr NO-ERROR.
			
			ASSIGN 
				lvc_ruletype          = ""
				lvc_rulebusinessline  = ""
				lvc_rulesite          = ""
				lvc_approvers         = "".
				
			DISPLAY 
				lvc_ruletype
				lvc_rulebusinessline
				lvc_rulesite
				lvc_approvers
			WITH FRAME a.
        END. /* IF del-yn */
        
        NEXT mainloop.
    END.
	
	ASSIGN ststatus = stline[1].
    STATUS INPUT ststatus.
  
    ASSIGN lvc_approvers = "".
	
	{us/gp/gpbrparm.i &browse=gplu806.p &parm=c-brparm1 &val=""DOA_APPROVER_CODES""}
	
    approversloop:
	REPEAT:
		{us/sw/swselect.i
			&record-id	  = rRecordID
			&scroll-field = ttApprovers.ttApproversSeq
			&detfile      = ttApprovers
			&display1     = ttApprovers.ttApproversSeq
			&display2     = ttApprovers.ttApproversCode
			&display3     = ttApprovers.ttApproversValue
			&display4     = ttApprovers.ttApproversAltValue
			&sel_on       = "ttApprovers.ttApproversSeq"
			&sel_off      = "ttApprovers.ttApproversSeq"
			&exit-flag    = TRUE
			&exitlabel    = approversloop
			&framename    = "frm_appr"
			&framesize    = 15
			&include1     = "{us/xx/xxapprvalupd.i}"}
			  
        /* END-ERROR DURING ENTRY */
        IF KEYFUNCTION(LASTKEY) EQ "END-ERROR"
        THEN DO:
			ASSIGN xxdoaappr_approvers = "".
			
			FOR EACH ttApprovers
				WHERE ttApprovers.ttApproversCode NE "":  
				ASSIGN
					xxdoaappr_approvers[INT(ttApprovers.ttApproversSeq)] = ttApprovers.ttApproversCode + "|" + ttApprovers.ttApproversValue + IF TRIM(ttApprovers.ttApproversAltValue) NE "" THEN "," + ttApprovers.ttApproversAltValue ELSE "".

				IF lvc_approvers = "" 
				THEN
					ASSIGN lvc_approvers = REPLACE(xxdoaappr_approvers[INT(ttApprovers.ttApproversSeq)],"|"," - ").
				ELSE 
					ASSIGN lvc_approvers = lvc_approvers + " | " + REPLACE(xxdoaappr_approvers[INT(ttApprovers.ttApproversSeq)],"|"," - ").
			END. /* FOR EACH ttApprovers */
			
			LEAVE approversloop.
        END. /* IF KEYFUNCTION(LASTKEY) EQ "END-ERROR" */
    END. /* approversloop */  
	
    DISPLAY 
        lvc_approvers
    WITH FRAME a.
	
	PAUSE(0).
    
    ASSIGN 
        xxdoaappr_LastModifiedDate  = TODAY
        xxdoaappr_LastModifiedTime  = TIME
        xxdoaappr_LastModifiedUser  = global_userid.
    
    RELEASE xxdoaappr_mstr NO-ERROR.
	
END. /* mainloop */