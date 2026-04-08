/* PSC: xxnotifyupd.i 	DOA Notification User Codes Update				*/
/*                                                                      */
/* CREATED: 31 May 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/

DO ON ERROR UNDO,LEAVE ON ENDKEY UNDO,LEAVE :
	UPDATE    
		ttNotify.ttNotifyValue
	WITH FRAME frm_noti.
END.  