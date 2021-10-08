# ok_twapi_common.tcl - common utilities for TWAPI based automation

package require twapi;  #  TODO: check errors

namespace eval ::ok_twapi:: {

  variable SRC_PID 0;  # pid of the source-directory instance of WinExplorer
  variable DST_PID 0;  # pid of the destination-directory instance of WinExplorer
  variable SRC_HWND "";     # TOP-LEVEL window handle of SRCDIR WinExplorer
  variable DST_HWND "";     # TOP-LEVEL window handle of DSTDIR WinExplorer
  
  variable APP_NAME
  variable SRC_WND_TITLE
  variable DST_WND_TITLE
  
  # pseudo response telling to wait for disappearance, then abort
  variable OK_TWAPI__WAIT_ABORT_ON_THIS_POPUP "OK_TWAPI__WAIT_ABORT_ON_THIS_POPUP"

  variable OK_TWAPI__APPLICATION_RELATED_WINDOW_TITLES [list]
  
  namespace export  \
    # (DO NOT EXPORT:)  start_rc  
}


# Example:  ::ok_twapi::start_src {C:/Windows/explorer.exe} {d:\tmp} "Windows-Explorer" {TMP}
proc ::ok_twapi::start_src {exePath srcDirPath appName srcWndTitle}  {
  variable SRC_PID
  variable SRC_HWND
  
  variable APP_NAME
  variable SRC_WND_TITLE

  set APP_NAME $appName
  set SRC_WND_TITLE $srcWndTitle
  set execDescr "invoking $APP_NAME in directory '$srcDirPath'"
  if { 0 < [set SRC_PID [exec $exePath [file nativename $srcDirPath] &]] }  {
    puts "-I- Success $execDescr" } else {
    puts "-E- Failed $execDescr";  return  0
  }
  set wndDescr "locating the window of $APP_NAME"
  #TODO: treat case of multiple matches
  if { 0 < [set SRC_HWND [twapi::find_windows -text "$SRC_WND_TITLE" \
                              -toplevel 1 -visible 1 -single]]  }  {
    puts "-I- Success $wndDescr"
  } else {
    puts "-E- Failed $wndDescr";  return  0
  }

  return  $SRC_HWND
}
