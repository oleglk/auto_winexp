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


proc ::ok_winexp::make_dst_subfolder {dstLeafDirName}  {
  variable DST_HWND
  if { $DST_HWND == "" }  {
    puts "-E- Destination window not located; cannot create folder ('$dstLeafDirName')"
    return  0
  }
  if { 0 == [raise_wnd_and_send_keys $DST_HWND keySeq} {}
  if { ("" == [set h [send_cmd_keys "{MENU}hn" $descr 0]]) }  {
    return  "";  # error already printed
  }

}


# If 'targetHwnd' given, focuses it; otherwise focuses the latest SPM window
proc ::ok_winexp::focus_window {context targetHwnd}  {
  variable WINEXP_APP_NAME
  set descr [expr {($context != "")? $context : \
                                "giving focus to $WINEXP_APP_NAME instance"}]
  if { !check_window_existence $targetHwnd] }  {
    return  0;  # warning already printed
  }

  # TODO: make it in a cycle !!!
  twapi::set_foreground_window $targetHwnd
  after 200
  twapi::set_focus $targetHwnd
  after 200
  set currWnd [twapi::get_foreground_window]

  if { ($currWnd == $targetHwnd }  {
    puts "-I- Success $descr";    return  1
  } else {
    set currWndText [expr {($currWnd != "")? \
              "'[twapi::get_window_text $currWnd]' ($currWnd)" : "UNKNOWN"}]
    puts "-E- Focused window $currWndText instead of '[twapi::get_window_text $targetHwnd]' ($targetHwnd)"
    puts "-E- Failed $descr";     return  0
  }
}


# Sends given keys while taking care of occurences of {MENU}.
# If 'targetHwnd' given, first focuses this window
# Returns handle of resulting window or "" on error.
# TODO: The sequence of {press-Alt, release-Alt, press-Cmd-Key} is not universal
proc ::ok_winexp::????TODO_send_cmd_keys {keySeqStr descr targetHwnd} {
  set descr "sending key-sequence {$keySeqStr} for '$descr'"
  set subSeqList [_split_key_seq_at_alt $keySeqStr]
  if { 1 == [focus_singleton "focus for $descr" $targetHwnd] }  {
    set wndBefore [expr {($targetHwnd == 0)? [twapi::get_foreground_window] : \
                                        $targetHwnd}];   # to detect focus loss
    after 1000
    if { [complain_if_focus_moved $wndBefore $descr 1] }  { return  "" }
    if { 0 == [llength $subSeqList] }   {
      twapi::send_keys $keySeqStr
     } else {
      foreach subSeq $subSeqList  {
        twapi::send_keys {{MENU}}
        after 1000;  # wait A LOT after ALT
        twapi::send_keys $subSeq
      }
     }
    after 500; # avoid an access denied error
    puts "-I- Success $descr";      return  [twapi::get_foreground_window]
  }
  puts "-E- Cannot $descr";         return  ""
}


proc ::ok_winexp::complain_if_focus_moved {wndBefore context mustExist}  {
  set wndNow [twapi::get_foreground_window]
  if { $wndBefore == $wndNow }  { return  0 } ;   # OK - didn't move
  if { !$mustExist && ![twapi::window_exists $wndBefore] }  {
    puts "-W- Focus moved from deleted window while $context"
    return  0
  }
  puts "-E- Focus moved while $context - from '[twapi::get_window_text $wndBefore]' to '[twapi::get_window_text $wndNow]'"
  return  1
}


proc ::ok_winexp::check_window_existence {hwnd {loud 1}}  {
  if { $hwnd == "" }  {
    puts "-E- check_window_existence got no handle";  return  0
  }
  set tclExecResult [catch { ;  # exceptions to detect invalid handles
    set txt [twapi::get_window_text $hwnd]
  }  evalExecResult]
  if { $tclExecResult != 0 } {
    if { $loud }  {  puts "-I- Window '$hwnd' doesn't exist"  }
    return  0
  }
  return  1
}


proc ::ok_winexp::????TODO_raise_wnd_and_send_menu_cmd_keys {targetHwnd keySeq} {
  set descr "raising window {$targetHwnd} and sending menu-command keys {$keySeq}"
  twapi::set_foreground_window $targetHwnd
  after 200
  twapi::set_focus $targetHwnd
  after 200
  if { $targetHwnd == [twapi::get_foreground_window] }  {
    #twapi::send_keys $keySeq
    if { ("" = [set h [send_cmd_keys $keySeq $descr $targetHwnd]]) }  {
      #puts "-E- Failed $descr"
      return  "";  # error already printed
    }
    puts "-I- Success $descr";  return  $h
  }
  puts "-E- Failed $descr";     return  ""
}


proc ::ok_winexp::raise_wnd_and_send_keys {targetHwnd keySeq} {
  set descr "raising window {$targetHwnd} and sending keys {$keySeq}"
  twapi::set_foreground_window $targetHwnd
  after 200
  twapi::set_focus $targetHwnd
  after 200
  if { $targetHwnd == [twapi::get_foreground_window] }  {
    twapi::send_keys $keySeq
    puts "-I- Success $descr";  return  1
  }
  puts "-E- Failed $descr";     return  0
}
