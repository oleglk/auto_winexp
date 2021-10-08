# ok_inifile.tcl

set UTIL_DIR [file dirname [info script]]
source [file join $UTIL_DIR "common.tcl"]

namespace eval ::ok_utils:: {
  
  namespace export  \
    ini_list_to_ini_arr   \
    ini_arr_to_ini_list   \
    ini_file_to_ini_arr   \
    ini_arr_to_ini_file
}



# Converts 'iniList' into array representation in 'iniArrVarName'.
# 'iniList' format exactly matches the Irfanview INI file:
#    <section1>, <option11>=<val11>, <option12>=<val12>,
#    <section2>, <option21>=<val21>, ... ,
# array representation format:
#   (-<section1>__<option11>) ={<val11>}, (-<section1>__<option12>) ={<val12>},
#   (-<section2>__<option21>) ={<val21>}, ... ,
# Returns 1 on success, 0 on error.
# Example:
#   ::ok_utils::ini_list_to_ini_arr {{[sec1]} {opt11=val11} {opt12=val12} {[sec2]} {opt21=val21}} tryOptArr
proc ::ok_utils::ini_list_to_ini_arr {iniList iniArrVarName} {
  upvar $iniArrVarName iniArr
  set errCnt 0
  array unset iniArr
  if { 0 == [llength $iniList] } {	return  1    }; # no options is legal
  set section ""
  foreach elem $iniList {
    if { 1 == [regexp {\[.*\]} $elem] } { ; # it's a section name
      set section $elem
    } else { ; # it should be "option=val" or "option="
      set opt "";	    set val ""
      if { 0 == [regexp {([^=]+)=([^=]*)} $elem full opt val] } {
        puts "-E- Invalid record '$elem' in ini-file options list"
        incr errCnt;	continue
      }
      set key "-$section";   append key "__$opt";   set iniArr($key) $val
    }
  }
  return  [expr {$errCnt == 0}]
}


# Converts array 'iniArrVarName' into list representation in 'iniListVar'.
# array representation format:
#    (<section1>__<option11>) ={<val11>}, (<section1>__<option12>) ={<val12>},
#    (<section2>__<option21>) ={<val21>}, ... ,
# 'iniListVar' format exactly matches the Irfanview INI file:
#    <section1>, <option11>=<val11>, <option12>=<val12>,
#    <section2>, <option21>=<val21>, ... ,
# Returns 1 on success, 0 on error.
# Example:
#   array set tryOptArr {{[sec1]__opt12} val12 {[sec2]__opt21} val21 {[sec1]__opt11} val11};  ::ok_utils::ini_arr_to_ini_list tryOptArr tryOptList
proc ::ok_utils::ini_arr_to_ini_list {iniArrVarName iniListVar} {
  upvar $iniArrVarName iniArr
  upvar $iniListVar iniList
  if { ! [array exists iniArr] }  {
    puts "-E- Inexistent ini-settings array"
    return  0
  }
  set errCnt 0
  set iniList [list];    set section "";    set prevSect "";    set option ""
  set keys [lsort [array names iniArr]];    # guarantee groupping by sections
  foreach key $keys { ;	# key should be "<section>__<option>"
    if { 0 == [regexp {\-(.+)__(.+)} $key full section option] } {
      puts "-E- Invalid key '$key' in Irfanview option list"
      incr errCnt;	continue
    }
    if { 0 == [string equal $prevSect $section] } { ; #start of new section
      lappend iniList $section;    set prevSect $section
    }
    lappend iniList "$option=$iniArr($key)"
  }
  return  [expr {$errCnt == 0}]
}


proc ::ok_utils::ini_file_to_ini_arr {iniFile iniArrVarName} {
  upvar $iniArrVarName iniArr
  set errCnt 0
  array unset iniArr
  if { [file exists $iniFile] } {
    if { 0 == [ok_read_list_from_file iniList $iniFile] } {
      puts "-E- Failed reading ini-file '$iniFile'"
      return  0
    }
  } else {
    set iniList [list]
    puts "-W- Inexistent ini-file '$iniFile'"
  }
  # 'iniArr' <- pre-existing options
  if { 0 == [ini_list_to_ini_arr $iniList iniArr] } {
    puts "-E- Failed recognizing options read from '$iniFile'"
    return  0
  }
  # puts ">>> Options read from '$iniFile':";  pri_arr iniArr
  return  1
}


# Creates .ini file for Irfanview in directory 'iniDir'.
# 'optionsList' looks like:
#  -<section_name>__<option_name> <val>
#  ...
#  -<section_name>__<option_name> <val>
# The 'optionsList' is not necessarily sorted.
# Irfanview .ini file looks like: TODO
# Returns 1 on success, 0 on error.
# Example (irfanview):
#   array unset newArr;  array set newArr {{-[Copy-Move]__CopyDir1} e:/tcl/Work/Run/ {-[Copy-Move]__MoveDir1} e:/tcl/Work/Run/};   ok_utils::ini_arr_to_ini_file  newArr  D:/DC_TMP/TRY_AUTO/SPM_SETTINGS/try1.ini  1
proc ::ok_utils::ini_arr_to_ini_file {newOptArrVarName iniFile dropOld} {
  upvar $newOptArrVarName newOptArr
  if { [file exists $iniFile] && ![file writable $iniFile] }  {
    puts "-E- Cannot write into file '$iniFile'"
    return  0
  }
  set iniDir [file dirname $iniFile]
  if { ! ([file exists $iniDir] && [file writable $iniDir]) }  {
    puts "-E- Cannot write into directory '$iniDir'"
    return  0
  }
  if { ![file exists $iniDir] } {
    if { ![file writable [file dirname $iniDir]] }  {
      puts "-E- Parent directory of '$iniDir' is unwritable"
      return  0
    }
    if { 0 == [ok_mkdir $iniDir] } {
      puts "-E- Failed creating ini-file directory '$iniDir'"
      return  0
    }
  }
  # at this point we have existing writable directory 'iniDir'
  if { !$dropOld && ([file exists $iniFile]) } {
    if { 0 == [ok_read_list_from_file iniList $iniFile] } {
      puts "-E- Failed reading ini-file '$iniFile'"
      return  0
    }
  } else {	set iniList [list]    };  # no pre-existing options or commanded to drop
  # 'iniArr' <- pre-existing options; 'newOptArr' <- new options ('optionsList')
  array unset iniArr
  if { 0 == [ini_list_to_ini_arr $iniList iniArr] } {
    puts "-E- Failed recognizing options read from '$iniFile'"
    return  0
  }
  puts ">>> Options read from '$iniFile':";  pri_arr iniArr
  puts ">>> New options:";  pri_arr newOptArr
  # insert new options or override existing
  foreach optName [array names newOptArr] {
    set iniArr($optName) $newOptArr($optName)
  }
  # puts ">>> Resulting options:"; pri_arr iniArr
  if { 0 == [ini_arr_to_ini_list iniArr iniList] } {
    puts "-E- Failed formatting resulting INI options {[array get iniArr]}"
    return  0
  }
  if { [llength $iniList] <= 0 }  {
    puts "-E- No options assembled"
    return  0
  }
  puts "-D- Options to be written into '$iniFile': {$iniList}"
  if { 0 == [ok_write_list_into_file $iniList $iniFile] } {
    puts "-E- Failed writting ini-file '$iniFile'"
    return  0
  }
  puts "-I- ini-file written into '$iniFile'"
  return  1
}
