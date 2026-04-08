/* PSC: xxapprupd.i 	DOA Approver Code Update 						*/
/*                                                                      */
/* CREATED: 31 May 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

approvercodeloop:
REPEAT ON ERROR UNDO,LEAVE ON ENDKEY UNDO,LEAVE:
	UPDATE
		ttApprover.ttApproverCode
	WITH FRAME frm_appr.
	
	IF ttApprover.ttApproverCode        NE ''                   AND
       NOT(ttApprover.ttApproverCode    MATCHES '*@*com')       AND
	   NOT CAN-FIND(FIRST code_mstr		NO-LOCK
					WHERE code_domain 	EQ global_domain 		AND
						  code_fldname 	EQ 'DOA_APPROVER_CODES' AND
						  code_value    EQ ttApprover.ttApproverCode) 
	THEN DO:
		RUN us/xx/xxdispmsg.p (2685,3,'Approver Code not defined in GCM. Fieldname - DOA_APPROVER_CODES').
		UNDO approvercodeloop, RETRY approvercodeloop.
	END.
	
	LEAVE.
END.