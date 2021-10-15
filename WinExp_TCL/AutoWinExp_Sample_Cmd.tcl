# AutoWinExp_Sample_Cmd.tcl

package require twapi;  #  TODO: check errors
package require twapi_clipboard


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "common.tcl"]
source [file join $SCRIPT_DIR "ok_winexp_common.tcl"]




proc ::ok_winexp::AutoWinExp_Sample_Commands__Yoga2Pro {}  {
source c:/Oleg/Work/DualCam/Auto/auto_winexp/winexp_tcl/ok_winexp_common.tcl

::ok_winexp::start_src {C:/Windows/explorer.exe} {g:\tmp\WinExp\INP1} "Windows-Explorer" {INP1}
::ok_winexp::locate_dst "Windows-Explorer" {OUT1}

::ok_winexp::focus_window_and_copy_first $::ok_winexp::SRC_HWND
::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
::ok_winexp::focus_window_and_copy_n $::ok_winexp::SRC_HWND 2
::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
}


proc ::ok_winexp::AutoWinExp_Sample_Commands__MIIX320 {}  {
source c:/Work/code/Auto/auto_winexp/winexp_tcl/ok_winexp_common.tcl

::ok_winexp::start_src {C:/Windows/explorer.exe} {d:\TMP\WinExp\INP1} "Windows-Explorer" {INP1}
::ok_winexp::locate_dst "Windows-Explorer" {OUT1}

::ok_winexp::focus_window_and_copy_first $::ok_winexp::SRC_HWND
::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
::ok_winexp::focus_window_and_copy_n $::ok_winexp::SRC_HWND 2
::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
}


proc ::ok_winexp::AutoWinExp_CmdSeq_Copy1st {inpPath}  {
  set rc [::ok_winexp::start_src {C:/Windows/explorer.exe} $inpPath "Windows-Explorer" [file tail $inpPath]]
  if { $rc == 0 }   { return  $rc }
  set rc [::ok_winexp::locate_dst "Windows-Explorer" {OUT1}]
  if { $rc == 0 }   { return  $rc }

  set rc [::ok_winexp::focus_window_and_copy_first $::ok_winexp::SRC_HWND]
  if { $rc == 0 }   { return  $rc }
  set rc [::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND]
  return  $rc
}


proc ::ok_winexp::AutoWinExp_CmdSeq_Copy2nd {inpPath}  {
::ok_winexp::start_src {C:/Windows/explorer.exe} $inpPath "Windows-Explorer" [file tail $inpPath]
::ok_winexp::locate_dst "Windows-Explorer" {OUT1}

::ok_winexp::focus_window_and_copy_first $::ok_winexp::SRC_HWND
::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
::ok_winexp::focus_window_and_copy_n $::ok_winexp::SRC_HWND 2
::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
}
