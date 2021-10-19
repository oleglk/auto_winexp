# ok_winexp_common.tcl - common utilities for TWAPI based automation

package require twapi;  #  TODO: check errors
package require twapi_clipboard


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
  
  variable SRC_DIR_PATH "";   # full path of the source directory
  
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
  variable SRC_DIR_PATH

  set WINEXP_APP_NAME $appName
  set SRC_WND_TITLE $srcWndTitle
  set execDescr "invoking $WINEXP_APP_NAME in directory '$srcDirPath'"

  if { ![file isdirectory $srcDirPath] }  {
    puts "-E- Failed $execDescr - inexistent input directory";  return  0
  }
  set SRC_DIR_PATH $srcDirPath
  set wndsBefore [twapi::find_windows -text "$SRC_WND_TITLE" \
                                      -toplevel 1 -visible 1]
  puts "-D- Found [llength $wndsBefore] window(s) with matching title ($SRC_WND_TITLE)"
                              
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
    set wnds [twapi::find_windows -text "$DST_WND_TITLE" -match string \
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
  set descr "create subfolder '$dstLeafDirName'"
  if { $DST_HWND == "" }  {
    puts "-E- Destination window not located; cannot $descr"
    return  ""
  }
  puts "-I- Begin to $descr on destination"
  
  # deselect subfolder(s) then create new one
  if { ("" == [set h [  \
            focus_window_and_send_cmd_keys "{MENU}hsn{MENU}hn" $descr $DST_HWND]]) }  {
    return  "";  # error already printed
  }
  #~ if { 0 == [focus_window "focus for $descr" $DST_HWND] }  {
      #~ return  "";  # error already printed
  #~ }
  #~ foreach keyStr [list {{MENU}} {s} {n} {{MENU}} {h} {n}]  {
    #~ after 3000;  # 1sec insufficient on Yogabook C930
    #~ twapi::send_keys $keyStr
  #~ }
  #~ # The below fails on Android too. TODO: need to deselect subfolder(s) if any "checked"
  #~ after 1000;   twapi::send_keys {{MENU}}
  #~ after 1000;   twapi::send_keys {s}
  #~ after 1000;   twapi::send_keys {n}
  #~ after 1000;   twapi::send_keys {{MENU}}
  #~ after 1000;   twapi::send_keys {h}
  #~ after 4000;   twapi::send_keys {n}  
  
  after 1000;  # without delay once saw 2 leading characters lost
  twapi::send_input_text $dstLeafDirName
  after 1000;  # 
  twapi::send_keys {{ENTER}}
  # check for popup upon name conflict - on Android unsupported
  after 3000
  set currWnd [twapi::get_foreground_window]
  if { $currWnd != $DST_HWND }  {
    if { $currWnd == "" }   {
      puts "-E- Unexpected error in $descr";  return  ""
    }
    set currWndText [twapi::get_window_text $currWnd]
    if { $currWndText == "Confirm Folder Replace" }   {
      twapi::send_keys {y}
      after 3000;   # TODO: wait_for_window_title_to_raise
      puts "-I- Assuming folder-replace-confirmation popup closed"
    } else {
      puts "-E- Unexpected window focused in $descr";  return  ""
    }
  }
  # now enter the new directory
  set newDirPath [change_path_to_subfolder_in_current_window $dstLeafDirName ""]
  if { $newDirPath == "" }  {
    return  "";   # error already printed
  }
  puts "-I- Success to $descr; new folder path is '$newDirPath'"
  return  $newDirPath
}


proc ::ok_winexp::read_native_folder_path_in_current_window {}  {
  # type Alt-d, then copy the path into clipboard
  twapi::send_keys {%d};  # focus path entry; dir-path should become selected
  after 1000; # 3000 did work
  twapi::send_keys {^c};  # filename-entry (should be selected) => clipboard
  after 1000; # 3000 did work
  set dirPath [::twapi::read_clipboard_text -raw FALSE]
  return  $dirPath
}


proc ::ok_winexp::change_path_to_subfolder_in_current_window {folderLeafName \
                                                      {expectedNewLeafName ""}}  {
  # type Alt-d, then append to the path
  twapi::send_keys {%d};  # focus path entry; dir-path should become selected
  after 3000
  twapi::send_keys {{END}};  # filename-entry should be selected => jump to end
  after 1000
  twapi::send_input_text "\\$folderLeafName"
  after 1000
  twapi::send_keys {{ENTER}}
  after 1000
  set newNativePath [read_native_folder_path_in_current_window]
  set newDirPath [file normalize $newNativePath]
  set newLeafDirName [file tail $newDirPath]
  if { ($expectedNewLeafName == "") && ($folderLeafName != "..") }  {
    set expectedNewLeafName $folderLeafName
  }
  if { ![string equal -nocase $newLeafDirName $expectedNewLeafName] }  {
    puts "-E- Aborting - failed entering subfolder '$folderLeafName'; brought into '$newDirPath' instead"
    return  ""
  }
  return  $newDirPath
}


proc ::ok_winexp::focus_src_and_jump_to_top {}  {
  variable SRC_HWND
  if { $SRC_HWND == "" }  {
    puts "-E- Missing source window - cannot jump to its top"
    return  ""
  }
  return  [focus_window_and_jump_to_top $SRC_HWND]
}


# Safe jump to 1st item: select-all, down, home
proc ::ok_winexp::focus_window_and_jump_to_top {targetHwnd}  {
  if { ("" == [set h [  \
            focus_window_and_send_cmd_keys "{MENU}hsa{DOWN}{HOME}" \
                                           "jump to top" $targetHwnd]]) }  {
    return  "";  # error already printed
  }
  return  $h
}


# Safe jump to 1st item: select-all, down, home
proc ::ok_winexp::focus_window_and_copy_first {targetHwnd}  {
  if { ("" == [set h [  \
            focus_window_and_send_cmd_keys "{MENU}hsa{DOWN}{HOME}{MENU}hco" \
                                           "copy first file" $targetHwnd]]) }  {
    return  "";  # error already printed
  }
  return  $h
}


# Safe jump to 1st item: select-all, down-n-times, home
proc ::ok_winexp::focus_window_and_copy_n {targetHwnd n}  {
  if { $n == 1 }  {
    return  [focus_window_and_copy_first $targetHwnd]
  }
  set nm1 [expr $n-1]
  set keySeq "{MENU}hsa{DOWN}{HOME}[string repeat {{DOWN}} $nm1]{MENU}hco"
  if { ("" == [set h [  \
            focus_window_and_send_cmd_keys $keySeq \
                                           "copy file #$n" $targetHwnd]]) }  {
    return  "";  # error already printed
  }
  return  $h
}


# 
proc ::ok_winexp::focus_window_and_paste {targetHwnd}  {
  if { ("" == [set h [  \
            focus_window_and_send_cmd_keys "{MENU}hv" \
                                           "paste" $targetHwnd]]) }  {
    return  "";  # error already printed
  }
  return  $h
}


#~ # Intended for OS directories, not Android!
#~ proc ::ok_winexp::focus_src_window_and_change_folder {targetHwnd newDirPath}  {
  #~ # TODO: check if all defined
  #~ if { ![file isdirectory $newDirPath] }  {
    #~ puts "-E- Aborting change-folder - inexistent input folder '$newDirPath'"
    #~ return  ""
  #~ }

  #~ if { ("" == [set h [  \
            #~ focus_window_and_send_cmd_keys "%d" \
                              #~ "change folder path in window" $targetHwnd]]) }  {
    #~ return  "";  # error already printed
  #~ }
  #~ send_input
  #~ return  $h
#~ }


# Copies all the files from the current folder of source window
# into the current folder of destination window.
# Returns number of files copied on success, or -1 on error.
proc ::ok_winexp::copy_all_from_src_to_dst {}  {
  variable SRC_HWND
  variable DST_HWND
  variable SRC_DIR_PATH
  variable DST_WND_TITLE
  # TODO: check if all defined
  set srcFiles [glob -nocomplain -directory $SRC_DIR_PATH {*}]
  set nFiles [llength $srcFiles]
  if { $nFiles == 0 }  {
    puts "-W- No files to copy from '$SRC_DIR_PATH'";   return 0
  }
  
  puts "-I- Begin copying $nFiles file(s) from '$SRC_DIR_PATH' to '$DST_WND_TITLE'"
  for {set i 1}  {$i <= $nFiles}  {incr i 1}  {
    set descr "copy file #$i out of $nFiles from '$SRC_DIR_PATH'"
    puts "-D- Going to $descr"
    if { "" == [focus_window_and_copy_n $SRC_HWND $i] }  {
      puts "-E- Aborting upon failure to $descr (at source)";       return  -1
    }
    after 2000
    if { "" == [focus_window_and_paste $DST_HWND] }  {
      puts "-E- Aborting upon failure to $descr (at destination)";  return  -1
    }
    #TODO: now there could be a popup - either progress or confirmation request
    ##### (on Android: error instead of confirmation request)
    #TODO: track focus moved to popup then back; do restrict max-wait-time
    # !!! no console print while tracking the popup !!!
    after 2000;  # OK_TMP
    #ok_pause_console "-- CR to continue --"
    puts "-D- Finished to $descr"
  }
  puts "-I- Done copying $nFiles file(s) from '$SRC_DIR_PATH' to '$DST_WND_TITLE'"
  return  $nFiles
}


# Copies all the files from the current folder of source window
# into the current folder of destination window.
# Returns number of files copied on success, or -1 on error.
proc ::ok_winexp::copy_subfolder_from_src_to_dst {leafDirName}  {
  variable SRC_HWND
  variable DST_HWND
  variable SRC_DIR_PATH
  variable DST_WND_TITLE
  # TODO: check if all defined

  set descr "copy subfolder '$leafDirName'"
  puts "-I- Begin $descr from '$SRC_DIR_PATH' to '$DST_WND_TITLE'"

  # verify the subfolder existence on the source
  set ultimateSrcDirPath [file normalize [file join $SRC_DIR_PATH $leafDirName]]
  if { ![file isdirectory $ultimateSrcDirPath] }  {
    puts "-E- Aborting - inexistent input directory '$ultimateSrcDirPath'"
    return  -1
  }
  
  # titles reflect original leaf directories to verify return after copy
  # (not needed) set oldSrcTitle [twapi::get_window_text $SRC_HWND]
  set oldDstTitle [twapi::get_window_text $DST_HWND]
  #(not here) set oldDstPath  [read_native_folder_path_in_current_window]
  
  if { "" == [set dstDirPath [make_dst_subfolder $leafDirName]] }  {
    puts "-E- Aborting upon failure to create destination subfolder '$leafDirName'"
    return  -1
  }
  set oldDstLeafName  [file tail [file dirname [file normalize $dstDirPath]]]
  
  # focus the source and enter requested subfolder on it
  if { 0 == [focus_window "focus for $descr" $SRC_HWND 0] }  {
      return  -1;  # error already printed
  }
  set oldSrcLeafName  [file tail [file normalize \
                                  [read_native_folder_path_in_current_window]]]
  set newDirPath [change_path_to_subfolder_in_current_window $leafDirName ""]
  if { $newDirPath == "" }  {
    return  -1;   # error already printed
  }
  after 1000

  # perform the actual copy
  if { "" == [set copyRC [copy_all_from_src_to_dst]] }  {
    return  -1;  # error already printed
  }
  
  after 1000
  # focus the DESTINATION and return to the parent directory on it
  if { 0 == [focus_window "focus dst to return after $descr" $DST_HWND 0] }  {
    return  -1;  # error already printed
  }
  set oldDirPathNorm [change_path_to_subfolder_in_current_window ".." $oldDstLeafName]
  if { $oldDirPathNorm == "" }  {
    return  -1;   # error already printed
  }
  #~ # the safe way to go back is to select-all, then go-back
  #~ set dstRetDescr "focus dst to return after $descr"
  #~ if { "" == [focus_window_and_send_cmd_keys  {{MENU}hsa}  \
                                              #~ $dstRetDescr $DST_HWND 0]   }  {
    #~ return  -1;  # error already printed
  #~ }
  #~ after 2000;  # 500 msec wasn't enough
  #~ twapi::send_keys {{BACKSPACE}} ;  # {%{LEFT}} didn't work
  #~ #TODO: appending "\.." to path works too!
  #~ # TODO: verify return through title - move to a new proc
  #~ after 1000;  # without any delay it read subfolder subtitle
  #~ set newDstTitle [twapi::get_window_text $DST_HWND]
  #~ if { ![string equal -nocase $newDstTitle $oldDstTitle] }  {
    #~ puts "-E- Aborting - failed returning to subfolder '$oldDstTitle' on the destination; brought into '$newDstTitle' instead"
    #~ return  -1
  #~ }
  #ok_pause_console;  # OK_TMP
  
  
  # focus the SOURCE and return to the parent directory on it
  if { 0 == [focus_window "focus src to return after $descr" $SRC_HWND 0] }  {
    return  -1;  # error already printed
  }
  set oldDirPathNorm [change_path_to_subfolder_in_current_window ".." $oldSrcLeafName]
  if { $oldDirPathNorm == "" }  {
    return  -1;   # error already printed
  }

  puts "-I- Done $descr from '$SRC_DIR_PATH' to '$DST_WND_TITLE'"
  return  $copyRC
}

################ Utility procedures ############################################

# If 'targetHwnd' given, focuses it; otherwise focuses the latest SPM window
proc ::ok_winexp::focus_window {context targetHwnd {reportSuccess 0}}  {
  variable WINEXP_APP_NAME
  set descr [expr {($context != "")? $context : \
                                "giving focus to $WINEXP_APP_NAME instance"}]
  if { ![check_window_existence $targetHwnd] }  {
    return  0;  # warning already printed
  }

  puts "-D- Going to focus window {$targetHwnd} for $context"
  # try raising the window during 8 seconds
  for {set i 1}  {$i <= 20}  {incr i 1}  { ;  
    twapi::set_foreground_window $targetHwnd
    after 200
    twapi::set_focus $targetHwnd
    after 200
    if { $targetHwnd == [set currWnd [twapi::get_foreground_window]] }  {
      if { $reportSuccess }  { puts "-I- Success $descr" }
      return  1
    }
    if { $i > 5 }  {; # if window still "stuck" after 2sec minimize-restore
      twapi::minimize_window $targetHwnd -sync
      twapi::restore_window  $targetHwnd -sync
    }
  }
  set currWndText [expr {($currWnd != "")? \
            "'[twapi::get_window_text $currWnd]' ($currWnd)" : "UNKNOWN"}]
  puts "-E- Focused window $currWndText instead of '[twapi::get_window_text $targetHwnd]' ($targetHwnd)"
  puts "-E- Failed $descr"
  return  0
}


# Sends given keys while taking care of occurences of {MENU}.
# If 'targetHwnd' given, first focuses this window
# Returns handle of resulting window or "" on error.
# TODO: The sequence of {press-Alt, release-Alt, press-Cmd-Key} is not universal
proc ::ok_winexp::focus_window_and_send_cmd_keys {keySeqStr descr targetHwnd \
                                                  {reportSuccess 1}} {
  set descr "sending key-sequence {$keySeqStr} for '$descr'"
  set subSeqList [_split_key_seq_at_alt $keySeqStr]
  if { 1 == [focus_window "focus for $descr" $targetHwnd 0] }  {
    set wndBefore [expr {($targetHwnd == 0)? [twapi::get_foreground_window] : \
                                        $targetHwnd}];   # to detect focus loss
    after 1000
    if { [complain_if_focus_moved $wndBefore $descr 1] }  { return  "" }
    if { 0 == [llength $subSeqList] }   {
      twapi::send_keys $keySeqStr
     } else {
      set beforeFirst 1;  # provide for delay between subsequences
      foreach subSeq $subSeqList  {
set ::TMP_LAST__subSeq $subSeq
        if { !$beforeFirst }  { after 1000;  set beforeFirst 0 }
        twapi::send_keys {{MENU}}
        after 2000;  # wait A LOT after ALT
        twapi::send_keys $subSeq
      }
     }
    after 500; # avoid an access denied error
    if { $reportSuccess }  { puts "-I- Success $descr" }
    return  [twapi::get_foreground_window]
  }
  puts "-E- Failed $descr";         return  ""
}


#~ # Waits with active polling
#~ # Returns handle of resulting window or "" on error.
#~ proc ::ok_winexp::wait_for_window_title_to_raise {titleStr matchType}  {
  #~ return  [wait_for_window_title_to_raise__configurable $titleStr $matchType 500 20000]
#~ }


#~ # Waits with active polling - configurable
#~ # Returns handle of resulting window or "" on error.
#~ proc ::ok_winexp::wait_for_window_title_to_raise__configurable { \
                                        #~ titleStr matchType pollPeriodMsec maxWaitMsec}  {
  #~ if { $titleStr == "" }  {
    #~ puts "-E- No title provided for [lindex [info level 0] 0]";   return  ""
  #~ }
  #~ set nAttempts [expr {int( ceil(1.0 * $maxWaitMsec / $pollPeriodMsec) )}]
  #~ if { $nAttempts == 0 }  { set nAttempts 1 }
  #~ ### after 2000 ;  # unfortunetly need to wait
  #~ for {set i 1} {$i <= $nAttempts} {incr i 1}   {
    #~ if { 1 == [verify_current_window_by_title $titleStr $matchType 0] }  {
      #~ set h [twapi::get_foreground_window]
      #~ if { ($h != "") && (1 == [twapi::window_visible $h]) }  {
        #~ puts "-I- Window '$titleStr' did appear after [expr {$i * $pollPeriodMsec}] msec"
        #~ return  $h
      #~ }
    #~ }
    #~ puts "-D- still waiting for window '$titleStr' - attempt $i of $nAttempts"
    #~ after $pollPeriodMsec
  #~ }
  #~ puts "-E- Window '$titleStr' did not appear after [expr {$nAttempts * $pollPeriodMsec}] msec"
  #~ set h [twapi::get_foreground_window]
  #~ set currTitle [expr {($h != "")? [twapi::get_window_text $h]  :  "NONE"}]
  #~ puts "-E- (The foreground window is '$currTitle')"
  #~ return  ""
#~ }


#~ proc ::ok_winexp::verify_current_window_by_title {titleOrPattern matchType {loud 1}}  {
  #~ set h  [twapi::get_foreground_window]
  #~ set isMatch [check_window_title $h $titleOrPattern $matchType $loud]
  #~ if { $isMatch == 0 } {
    #~ if { $loud }  {
      #~ set txt [twapi::get_window_text $h]
      #~ puts "-W- Unexpected foreground window '$txt' - doesn't match '$titleOrPattern'"
      #~ #puts "[_ok_callstack]"; ::ok_utils::pause; # OK_TMP
      #~ #ok_twapi::abort_if_key_pressed "q"
    #~ }
    #~ return  0
  #~ }
  #~ return  1
#~ }


#~ proc ::ok_winexp::check_window_title {hwnd titleOrPattern matchType {loud 1}}  {
  #~ set tclExecResult [catch { ;  # catch exceptions to skip invalid handles
    #~ set txt [expr {($hwnd != "")? [twapi::get_window_text $hwnd] \
                              #~ : "NO-WINDOW-HANDLE"}]
  #~ }  evalExecResult]
  #~ if { $tclExecResult != 0 } {
    #~ if { $loud }  {  puts "-I- Window '$hwnd' doesn't exist"  }
    #~ return  0
  #~ }
  #~ set isMatch [switch $matchType  {
    #~ {exact}   { expr {$txt == $titleOrPattern} }
    #~ {nocase}  { string equal -nocase $titleOrPattern $txt }
    #~ {glob}    { string match $titleOrPattern $txt }
    #~ {regexp}  { regexp -nocase -- $titleOrPattern $txt }
    #~ default   { puts "-E- Unsupported matchType '$matchType'";  expr 0  }
  #~ }]
  #~ return  $isMatch
#~ }


# Returns list of subsequences that follow occurences of {MENU}/{ALT}
# In the case of no occurences of {MENU}/{ALT}, returns empty list
proc ::ok_winexp::_split_key_seq_at_alt {keySeqStr} {
  # the idea:  set list [split [string map [list $substring $splitchar] $string] $splitchar]
  set tmp [string map {\{MENU\} \uFFFF  \{ALT\} \uFFFF} $keySeqStr]
  if { [string equal $tmp $keySeqStr] }   {
    return  [list];   # no occurences of {MENU}/{ALT}
  }
  set tmpList [split $tmp \uFFFF];  # may have empty elements
  set subSeqList [list]
  foreach el $tmpList {
    if { $el != "" }  { lappend subSeqList $el }
  }
  return  $subSeqList
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


proc ::ok_winexp::find_descendent_by_title {hwnd txtPattern}  {
  set children [::twapi::get_descendent_windows $hwnd]
  set tclExecResult [catch { ;  # catch exceptions to skip invalid handles  
    foreach w $children {
      set txt [::twapi::get_window_text $w]
      puts "-I- Check '$txt' "
      if { 1 == [regexp -- $txtPattern $txt] }  {
        return  $w
      }
    }
  }  evalExecResult]
  return  ""; # not found
}


################################################################################
# source c:/Oleg/Work/DualCam/Auto/auto_winexp/winexp_tcl/ok_winexp_common.tcl
# ::ok_winexp::start_src {C:/Windows/explorer.exe} {g:\tmp\WinExp\INP1} "Windows-Explorer" {INP1}
# ::ok_winexp::locate_dst "Windows-Explorer" {OUT1}
# ::ok_winexp::focus_window_and_copy_first $::ok_winexp::SRC_HWND
# ::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
#### ::ok_winexp::focus_window_and_copy_next $::ok_winexp::SRC_HWND
# ::ok_winexp::focus_window_and_copy_n $::ok_winexp::SRC_HWND 2
# ::ok_winexp::focus_window_and_paste $::ok_winexp::DST_HWND
################################################################################


#~ proc ::ok_winexp::????TODO_raise_wnd_and_send_menu_cmd_keys {targetHwnd keySeq} {
  #~ set descr "raising window {$targetHwnd} and sending menu-command keys {$keySeq}"
  #~ twapi::set_foreground_window $targetHwnd
  #~ after 200
  #~ twapi::set_focus $targetHwnd
  #~ after 200
  #~ if { $targetHwnd == [twapi::get_foreground_window] }  {
    #~ #twapi::send_keys $keySeq
    #~ if { ("" = [set h [send_cmd_keys $keySeq $descr $targetHwnd]]) }  {
      #~ #puts "-E- Failed $descr"
      #~ return  "";  # error already printed
    #~ }
    #~ puts "-I- Success $descr";  return  $h
  #~ }
  #~ puts "-E- Failed $descr";     return  ""
#~ }


#~ proc ::ok_winexp::raise_wnd_and_send_keys {targetHwnd keySeq} {
  #~ set descr "raising window {$targetHwnd} and sending keys {$keySeq}"
  #~ twapi::set_foreground_window $targetHwnd
  #~ after 200
  #~ twapi::set_focus $targetHwnd
  #~ after 200
  #~ if { $targetHwnd == [twapi::get_foreground_window] }  {
    #~ twapi::send_keys $keySeq
    #~ puts "-I- Success $descr";  return  1
  #~ }
  #~ puts "-E- Failed $descr";     return  0
#~ }
