/* PSC: xxdoahist.p - DOA History                						*/
/*                                                                      */
/* CREATED: 13 Jun 2023   BY: Deepak                                    */
/*                                                                      */
/*----------------------------------------------------------------------*/			

{us/bbi/mfdeclre.i}

define input parameter ipc_type   as character no-undo.
define input parameter ipc_action as character no-undo.
define input parameter ipc_number as character no-undo.
define input parameter ipc_cmmt   as character no-undo.
define input parameter ipc_cappr  as character no-undo.
define input parameter ipc_nappr  as character no-undo.

/* Create history record */
create xxdoah_hist.
assign 
   xxdoah_domain   = global_domain
   xxdoah_datetime = string(today) + " " + string(time,"HH:MM:SS")
   xxdoah_type     = ipc_type
   xxdoah_action   = ipc_action
   xxdoah_nbr      = ipc_number
   xxdoah_currappr = ipc_cappr
   xxdoah_nextappr = ipc_nappr
   xxdoah_Comment  = ipc_cmmt.
