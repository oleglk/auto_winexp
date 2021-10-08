# Copyright (C) 2005-2006 by Oleg Kosyakovsky

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}

namespace eval ::ok_utils:: {

    namespace export \
  ok_msg_set_callback \
	ok_arr_to_string \
	pri_arr \
	ok_pri_list_as_list \
	ok_info_msg \
	ok_trace_msg \
	ok_err_msg \
	ok_warn_msg \
  ok_msg_get_errwarn_cnt \
	ok_assert \
  ok_pause_console \
  ok_finalize_diagnostics \
  ok_init_diagnostics     \
  ok_set_start_time                       \
  ok_pause_and_reset_start_time_if_needed \
  ok_reset_start_time_if_needed           \
	ok_set_loud \
	ok_loud_mode

    variable LOUD_MODE 0

    variable _CNT_ERR_WARN  0;  # counter of problems
    variable _MSG_CALLBACK  0;  # for  proc _cb {msg} {}

    variable DIAGNOSTICS_FILE_HANDLE 0 ;  # =0 means not yet open
    variable DIAGNOSTICS_FILE_PATH  ""
    
    variable _WORK_START_TIMESTAMP      -1;  # global timer start time (sec)
    variable _MAX_WORKTIME            3600;  # max time (sec) of continuous work
    variable _PAUSE_DURATION            60;  # time to RELAX (sec)
}


# this file is reread from multiple files; don't override LOUD_MODE
### ? is setting LOUD_MODE in the below way is needed when it's in a namespace ?
#if { 0 == [info exists ::ok_utils::LOUD_MODE] }  {  set ::ok_utils::LOUD_MODE 1 }



proc ::ok_utils::ok_msg_set_callback {cb}  {
  variable _MSG_CALLBACK
  set _MSG_CALLBACK $cb
}


proc ::ok_utils::ok_set_loud {toPriTraceMsgs} {
    variable LOUD_MODE
    set LOUD_MODE [expr ($toPriTraceMsgs == 0)? 0 : 1]
}
proc ::ok_utils::ok_loud_mode {} {
    variable LOUD_MODE
    return $LOUD_MODE
}

proc ::ok_utils::ok_arr_to_string {theArr} {
    upvar $theArr arrName
    set arrStr ""
    foreach {name value} [array get arrName] {
	append arrStr " $theArr\[\"$name\"\]=\"$value\""
    }
    return  $arrStr
}

proc ::ok_utils::pri_arr {theArr} {
    upvar $theArr arrName
    foreach {name value} [array get arrName] {
	puts "$theArr\[\"$name\"\] = \"$value\""
    }
}

proc ::ok_utils::ok_pri_list_as_list {theList} {
    set length [llength $theList]
    for {set i 0} {$i < $length} {incr i} {
	set elem [lindex $theList $i]
	puts -nonewline " ELEM\[$i\]='$elem'"
    }
    puts ""
}

###############################################################################
########## Messages/Errors/Warning ################################
proc ::ok_utils::ok_msg {text kind} {
  variable LOUD_MODE
  variable _CNT_ERR_WARN
  variable _MSG_CALLBACK
  set pref ""
  set tags ""
  switch [string toupper $kind] {
    "INFO" { set pref "-I-" }
    "TRACE" {
        set pref [expr {($LOUD_MODE == 1)? "\# [msg_caller_name]:" : "\#"}]
    }
    "ERROR" {
        #set pref [expr {($LOUD_MODE == 1)? "-E- [msg_caller_name]:":"-E-"}]
        set pref "-E-"
        #set tags "boldline"
        set tags "underline"
        incr _CNT_ERR_WARN 1
    }
    "WARNING" {
        set pref [expr {($LOUD_MODE == 1)? "-W- [msg_caller_name]:":"-W-"}]
        set pref "-W-"
        #set tags "italicline boldline"
        set tags "underline"
        incr _CNT_ERR_WARN 1
    }
  }
  puts "$pref $text"
  _ok_write_diagnostics "$pref $text"
  if { $_MSG_CALLBACK != 0 }  {
    set tclResult [catch { set res [$_MSG_CALLBACK "$pref $text" "$tags"] } \
                          execResult]
    if { $tclResult != 0 } {
      puts "$pref Failed message callback: $execResult!"; #DO NOT USE ok_err_msg
    }
  }
}


proc ::ok_utils::ok_info_msg {text} {
    ok_msg $text "INFO"
}
proc ::ok_utils::ok_trace_msg {text} {
    variable LOUD_MODE
    if { $LOUD_MODE == 1 } {
	ok_msg $text "TRACE"
    }
}
proc ::ok_utils::ok_err_msg {text} {
    ok_msg $text "ERROR"
}
proc ::ok_utils::ok_warn_msg {text} {
    ok_msg $text "WARNING"
}


proc ::ok_utils::ok_msg_get_errwarn_cnt {}  {
  variable _CNT_ERR_WARN
  return  $_CNT_ERR_WARN
}


proc ::ok_utils::msg_caller_name {} {
  #puts "level=[info level]"
  set callerLevel [expr { ([info level] > 3)? -3 : [expr -1*([info level]-1)] }]
    set callerAndArgs [info level $callerLevel]
    return  [lindex $callerAndArgs 0]
}


###############################################################################
########## Assertions ################################

proc ::ok_utils::ok_assert {condExpr {msgText ""}} {
#    ok_trace_msg "ok_assert '$condExpr'"
    if { ![uplevel expr $condExpr] } {
# 	set theMsg [expr ($msgText == "")? "condExpr" : $msgText]
 	set theMsg $msgText
 	ok_err_msg "Assertion failed: '$theMsg' at [info level -1]"
	for {set theLevel [info level]} {$theLevel >= 0} {incr theLevel -1} {
	     ok_err_msg "Stack $theLevel:\t[info level $theLevel]"
	}
	return -code error
    }
}


proc ::ok_utils::ok_pause_console {{message "Press Enter to continue ==> "}} {
  puts -nonewline $message
  flush stdout
  gets stdin
}



proc ::ok_utils::ok_finalize_diagnostics {}  {
  variable DIAGNOSTICS_FILE_HANDLE
  variable DIAGNOSTICS_FILE_PATH
  if { $DIAGNOSTICS_FILE_HANDLE != 0 }  {
    ok_info_msg "Closing old diagnostics file '$DIAGNOSTICS_FILE_PATH'"
    catch { close $DIAGNOSTICS_FILE_HANDLE;  set DIAGNOSTICS_FILE_HANDLE 0 }
  }
}


proc ::ok_utils::ok_init_diagnostics {outFilePath}  {
  variable DIAGNOSTICS_FILE_PATH
##   if { $outFilePath != $DIAGNOSTICS_FILE_PATH }  {
 #     ok_finalize_diagnostics;  # if old file was open, close it
 #   }
 ##
  set DIAGNOSTICS_FILE_PATH $outFilePath
  # file will be opened at 1st write
  _ok_write_diagnostics "Diagnostics log file set to '$DIAGNOSTICS_FILE_PATH'"
}


################################################################################
## The mechanism of "global timer" intended to allow the system to rest 
## after long periods of intensive computing/storage activity
################################################################################

# Sets global timer to the currrent time
proc ::ok_utils::ok_set_start_time {} {
  variable _WORK_START_TIMESTAMP
  set _WORK_START_TIMESTAMP [clock seconds]
}


# If time from the global-timer start exceeds '_MAX_WORKTIME',
# waits for '_PAUSE_DURATION' sec, then resets start time and resumes the work
proc ::ok_utils::ok_pause_and_reset_start_time_if_needed {} {
  variable _WORK_START_TIMESTAMP
  variable _MAX_WORKTIME
  variable _PAUSE_DURATION
  set elapsedSec [expr {[clock seconds] - $_WORK_START_TIMESTAMP}]
  if { $elapsedSec > $_MAX_WORKTIME } {
    ok_info_msg "Relaxing for $_PAUSE_DURATION sec after $elapsedSec sec of continuous work"
    after [expr 1000 * $_PAUSE_DURATION]
    ok_set_start_time
  }
}


# If time from the global-timer start exceeds '_MAX_WORKTIME' or is uninitialized,
# resets start time
proc ::ok_utils::ok_reset_start_time_if_needed {} {
  variable _WORK_START_TIMESTAMP
  variable _MAX_WORKTIME
  set elapsedSec [expr {[clock seconds] - $_WORK_START_TIMESTAMP}]
  if { ($_WORK_START_TIMESTAMP < 0) || ($elapsedSec > $_MAX_WORKTIME) } {
    ok_info_msg "Resetting global start time after $elapsedSec sec of continuous work"
    ok_set_start_time
  }
}
################################################################################


################################################################################
# Internal utilities
################################################################################
proc ::ok_utils::_ok_write_diagnostics {msg}  {
  variable DIAGNOSTICS_FILE_HANDLE
  set dPath [_ok_find_diagnostics_file]
  if { $dPath == "" }  { return  0 };  # not ready yet
  if { $DIAGNOSTICS_FILE_HANDLE == 0 }  {;  # first attempt to write; avoid recursion
    if { 1 == [file exists $dPath] }  { catch { file delete $dPath } }
    set tclExecResult [ catch { set DIAGNOSTICS_FILE_HANDLE [open $dPath a+] } ]
    if { $tclExecResult != 0 }  {
      return  0;  # there will be no log; anyway cannot complain
    }
  }
  set tclExecResult [ catch { puts $DIAGNOSTICS_FILE_HANDLE $msg } ]
  if { $tclExecResult != 0 }  {
    return  0;  # there will be no log; anyway cannot complain
  }
  return  1
}


proc ::ok_utils::_ok_find_diagnostics_file {}  {
  variable DIAGNOSTICS_FILE_PATH
  if { $DIAGNOSTICS_FILE_PATH == "" }  {
    return  "";  # not ready yet
  }
  return $DIAGNOSTICS_FILE_PATH
}