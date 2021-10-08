# ok_winexp_common.tcl - common utilities for TWAPI based automation

package require twapi;  #  TODO: check errors


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR "ok_utils" "common.tcl"]

namespace eval ::ok_winexp:: {

  variable SRC_PID 0;  # pid of the source-directory instance of WinExplorer
  variable DST_PID 0;  # pid of the destination-directory instance of WinExplorer
  variable SRC_HWND "";     # TOP-LEVEL window handle of SRCDIR WinExplorer
  variable DST_HWND "";     # TOP-LEVEL window handle of DSTDIR WinExplorer
  
  variable WINEXP_APP_NAME
  variable SRC_WND_TITLE
  variable DST_WND_TITLE
  
  # pseudo response telling to wait for disappearance, then abort
  variable ok_winexp__WAIT_ABORT_ON_THIS_POPUP "ok_winexp__WAIT_ABORT_ON_THIS_POPUP"

  variable ok_winexp__APPLICATION_RELATED_WINDOW_TITLES [list]
  
  namespace export  \
    # (DO NOT EXPORT:)  start_rc  
}

namespace import ::ok_utils::*;


# Starts WinExplorer  ('exePath') in directory 'srcDirPath'.
# Example:  ::ok_winexp::start_src {C:/Windows/explorer.exe} {d:\tmp} "Windows-Explorer" {TMP}
proc ::ok_winexp::start_src {exePath srcDirPath appName srcWndTitle}  {
  variable SRC_PID
  variable SRC_HWND
  variable WINEXP_APP_NAME
  variable SRC_WND_TITLE

  set WINEXP_APP_NAME $appName
  set SRC_WND_TITLE $srcWndTitle
  set wndsBefore [twapi::find_windows -text "$SRC_WND_TITLE" \
                                      -toplevel 1 -visible 1]
  puts "-D- Found [llength $wndsBefore] window(s) with matching title ($SRC_WND_TITLE)"
                              
  set execDescr "invoking $WINEXP_APP_NAME in directory '$srcDirPath'"
  if { 0 < [set SRC_PID [exec $exePath [file nativename $srcDirPath] &]] }  {
    puts "-I- Success $execDescr" } else {
    puts "-E- Failed $execDescr";  return  0
  }
  set wndDescr "locating window of $WINEXP_APP_NAME in directory '$srcDirPath'"
  # treat case of multiple matches
  for {set attemptsLeft 20} {$attemptsLeft > 0} {incr attemptsLeft -1}  {
    after 500
    set wndsAfter [twapi::find_windows -text "$SRC_WND_TITLE" \
                                        -toplevel 1 -visible 1]
    if { [llength $wndsAfter] > 0 }  {
      set wndsNew [ok_subtract_list_from_list $wndsAfter $wndsBefore]
      if { [llength $wndsNew] == 1 }  {
        set SRC_HWND [lindex $wndsNew 0]
        puts "-I- Success $wndDescr"
        return  $SRC_HWND
      }
    } else {
      set wndsNew [list]
    }
  }
  puts "-E- Failed $wndDescr ([llength $wndsNew] candidate(s))"
  return  0
}


# Locates (WinExplorer) window with title 'dstWndTitle'.
# Example:  ::ok_winexp::locate_dst "Windows-Explorer" {TMP}
proc ::ok_winexp::locate_dst {appName dstWndTitle}  {
  variable DST_HWND
  variable DST_WND_TITLE

  set DST_WND_TITLE $dstWndTitle
  set wndDescr "locating window of $appName with title '$DST_WND_TITLE'"
  
  for {set attemptsLeft 20} {$attemptsLeft > 0} {incr attemptsLeft -1}  {
    after 500
    set wnds [twapi::find_windows -text "$DST_WND_TITLE" \
                                      -toplevel 1 -visible 1]
    if { [llength $wnds] == 1 }  {
      set DST_HWND [lindex $wnds 0]
      puts "-I- Success $wndDescr"
      return  $DST_HWND
    }
  }
  puts "-E- Failed $wndDescr ([llength $wnds] candidate(s))"
  return  0
}
