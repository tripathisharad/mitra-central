/* PSC: xxapprvalupd.i 	DOA Approver userid Update						*/
/*                                                                      */
/* CREATED: 31 May 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

approverdetailloop:
REPEAT ON ERROR UNDO,LEAVE ON ENDKEY UNDO,LEAVE:
	UPDATE    
		ttApprovers.ttApproversCode
		ttApprovers.ttApproversValue  
		ttApprovers.ttApproversAltValue
	WITH FRAME frm_appr.
	
	IF ttApprovers.ttApproversCode NE ''
	THEN DO:
		IF NOT CAN-FIND(FIRST code_mstr		NO-LOCK
					    WHERE code_domain 	EQ global_domain 		AND
						      code_fldname 	EQ 'DOA_APPROVER_CODES' AND
						      code_value    EQ ttApprovers.ttApproversCode) 
		THEN DO:
			RUN us/xx/xxdispmsg.p (2685,3,'Approver Code not defined in GCM. Fieldname - DOA_APPROVER_CODES').
			UNDO approverdetailloop, RETRY approverdetailloop.
		END.
		
		IF ttApprovers.ttApproversValue EQ '' 
		THEN DO:
			ASSIGN ttApprovers.ttApproversCode = ''.
			RUN us/xx/xxdispmsg.p (40,3,' - Approver Email').
			UNDO approverdetailloop, RETRY approverdetailloop.
		END.
	END. /* IF ttApprovers.ttApproversCode NE '' */
	
	LEAVE.
END.