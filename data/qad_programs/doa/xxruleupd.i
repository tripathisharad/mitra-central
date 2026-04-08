/* PSC: xxapprupd.i 	DOA Rule Update									*/
/*                                                                      */
/* CREATED: 31 May 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

DEFINE VARIABLE hFieldHandle AS HANDLE NO-UNDO.

ruleloop:
REPEAT ON ERROR UNDO,LEAVE ON ENDKEY UNDO,LEAVE:
	ASSIGN
		ttRule.ttRuleOperator = INPUT ttRule.ttRuleOperator.

	UPDATE
		ttRule.ttRuleTableField
		ttRule.ttRuleOperator
		ttRule.ttRuleValue
	WITH FRAME frm_rule.
	/*
	IF ttRule.ttRuleTableField NE '' 
	THEN DO:
		ASSIGN hFieldHandle = htable:BUFFER-FIELD(ttRule.ttRuleTableField) NO-ERROR.
		
		IF VALID-HANDLE(htable) 
		THEN DO: 
			IF NOT VALID-HANDLE(hFieldHandle) 
			THEN DO:
				RUN us/xx/xxdispmsg.p (2685,3,'Invalid Rule Field').
				UNDO ruleloop, RETRY ruleloop.
			END.
		END.
	END. /* IF ttRule.ttRuleTableField NE '' */
	*/
	LEAVE.
END.