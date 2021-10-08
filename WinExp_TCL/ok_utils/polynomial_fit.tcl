# polynomial_fit.tcl - Find an approximating polynomial of known degree for a given data.
# ---------------------------------------------------------
# Example: For input data:
# x = {0,  1,  2,  3,  4,  5,  6,   7,   8,   9,   10};
# y = {1,  6,  17, 34, 57, 86, 121, 162, 209, 262, 321};
# The approximating polynomial is:  3*x^2 + 2*x + 1
# Here, the polynomial's coefficients are (3, 2, 1). 
# ---------------------------------------------------------
# https://rosettacode.org/wiki/Polynomial_regression
# https://rosettacode.org/wiki/Polynomial_regression#Tcl

################################################################################
## Install tcllib into ...auto_spm\SPM_TCL\tcllib\
################################################################################
##   (download from https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md)
## "C:\Program Files\TWAPI\tclkit-gui-8_6_9-twapi-4_3_7-x64-max.exe"  ./installer.tcl  -app-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -example-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -html-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -nroff-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib  -pkg-path C:\Oleg\Work\DualCam\Auto\auto_spm\SPM_TCL\tcllib
################################################################################

set UTIL_DIR [file dirname [info script]]
source [file join $UTIL_DIR "debug_utils.tcl"]

if { -1 == [lsearch -glob $auto_path  "*/tcllib"] } {
  lappend auto_path [file join $UTIL_DIR ".." "tcllib"]
}

namespace eval ::ok_utils:: {

  namespace export            \
    ok_fit_curve              \
    ok_describe_curve_fitting \
    ok_format_curve_fitting   \
}


package require math::linearalgebra
 
proc ::ok_utils::_build.matrix {xvec degree} {
    set sums [llength $xvec]
    for {set i 1} {$i <= 2*$degree} {incr i} {
        set sum 0
        foreach x $xvec {
            set sum [expr {$sum + pow($x,$i)}] 
        }
        lappend sums $sum
    }
 
    set order [expr {$degree + 1}]
    set A [math::linearalgebra::mkMatrix $order $order 0]
    for {set i 0} {$i <= $degree} {incr i} {
        set A [math::linearalgebra::setrow A $i [lrange $sums $i $i+$degree]]
    }
    return $A
}
 
proc ::ok_utils::_build.vector {xvec yvec degree} {
    set sums [list]
    for {set i 0} {$i <= $degree} {incr i} {
        set sum 0
        foreach x $xvec y $yvec {
            set sum [expr {$sum + $y * pow($x,$i)}] 
        }
        lappend sums $sum
    }
 
    set x [math::linearalgebra::mkVector [expr {$degree + 1}] 0]
    for {set i 0} {$i <= $degree} {incr i} {
        set x [math::linearalgebra::setelem x $i [lindex $sums $i]]
    }
    return $x
}


# Returns list of coefficients starting from the lowest; on error returns ERROR
## Example 1:
## set x {0   1   2   3   4   5   6   7   8   9  10};  set y {1   6  17  34  57  86 121 162 209 262 321}
## set xyDict [concat {*}[lmap a $x  b $y  {list $a $b}]]
## set coeffsLowToHigh [ok_utils::ok_fit_curve $xyDict 2]
## ok_utils::ok_describe_curve_fitting $xyDict $coeffsLowToHigh
## Example 2 (lower control point raised by 50%):
##   set xTOy {0 0  0.25 0.375  0.5 0.5  0.75 0.75  1 1};  set coeffs [ok_utils::ok_fit_curve $xTOy 4]
### Example of curve application:
### foreach f [glob -nocomplain {INP/*.JPG}]  {[string trim $IMCONVERT "{}"] $f -function Polynomial  -5.3333,12.0000,-8.6667,3.0000,0.0000 [file join LIGHTEN POLY_50 [file tail $f]]}
proc ::ok_utils::ok_fit_curve {xyDict {degree -1}}  {
  if { $degree == -1 }  { set degree [expr [dict size $xyDict] - 1] }
  if { [dict size $xyDict] < ($degree + 1) }  {
    puts "-E- Polynomial of degree=$degree needs [expr $degree+1] control points; got [dict size $xyDict]"
    return  ERROR
  }
  set xVals [dict keys $xyDict];  set yVals [dict values $xyDict]
  # build the system A.x=b
  set A [_build.matrix $xVals $degree]
  set b [_build.vector $xVals $yVals $degree]
  # solve it and obtain coefficients starting from the lowest order
  set coeffsLowToHigh [math::linearalgebra::solveGauss $A $b]
  # show results
  #puts "[ok_describe_curve_fitting $xyDict $coeffsLowToHigh]"
  return  $coeffsLowToHigh
}


## set xTOy {0 0  0.25 0.375  0.5 0.5  0.75 0.75  1 1};  set coeffs [ok_utils::ok_fit_curve $xTOy 4]
## ::ok_utils::ok_describe_curve_fitting $xTOy $coeffs 4
proc ::ok_utils::ok_describe_curve_fitting {xyDict coeffsLowToHigh {degree -1}}  {
  if { $degree == -1 }  { set degree [expr [llength $coeffsLowToHigh] - 1] }
  if { [llength $coeffsLowToHigh] < ($degree + 1) }  {
    puts "-E- Polynomial of degree=$degree needs [expr $degree+1] coefficients; got [llength $coeffsLowToHigh]"
    return  ERROR
  }
  set points ""
  dict for {x y} $xyDict  {
    if { $points != "" }   { append points ","  }
    append points "($x:$y)"
  }
  #set coeffsHighToLow [lreverse $coeffsLowToHigh]
  set expression ""
  for {set iDeg $degree}  {$iDeg >= 0}  {incr iDeg -1}  {
    set coeff [lindex $coeffsLowToHigh $iDeg]
    if { "" == [string trim $coeff] }  {
      error "-E- coeff='' at iDeg=$iDeg, expression-so-far='$expression'"
    }
    if { $expression != "" }  {
      append expression [expr {($coeff>=0)? " + "  :  " - "}]
    } elseif { $coeff < 0 }  {
      append expression "-"
    }
    append expression [format "%.4f%s" [expr abs($coeff)]                 \
                                       [expr {($iDeg>0)? "*x**$iDeg" : ""}]]
  }
  return  "{$points} => $expression"
}


# Returns string with coefficients from high to low, delimited by ","
## set xTOy {0 0  0.25 0.375  0.5 0.5  0.75 0.75  1 1};  set coeffs [ok_utils::ok_fit_curve $xTOy 4]
## ::ok_utils::ok_format_curve_fitting $xTOy $coeffs 4
proc ::ok_utils::ok_format_curve_fitting {xyDict coeffsLowToHigh {degree -1}}  {
  if { $degree == -1 }  { set degree [expr [llength $coeffsLowToHigh] - 1] }
  if { [llength $coeffsLowToHigh] < ($degree + 1) }  {
    puts "-E- Polynomial of degree=$degree needs [expr $degree+1] coefficients; got [llength $coeffsLowToHigh]"
    return  ERROR
  }
  set res ""
  for {set iDeg $degree}  {$iDeg >= 0}  {incr iDeg -1}  {
    set coeff [lindex $coeffsLowToHigh $iDeg]
    if { "" == [string trim $coeff] }  {
      error "-E- coeff='' at iDeg=$iDeg, string-so-far='$res'"
    }
    if { $res != "" }  {
      append res ","
    }
    append res [format "%.4f" $coeff]
  }
  return  $res
}


#~ # Now, to solve the example from the top of this page
#~ set x {0   1   2   3   4   5   6   7   8   9  10}
#~ set y {1   6  17  34  57  86 121 162 209 262 321}
 
#~ # build the system A.x=b
#~ set degree 2
#~ set A [::ok_utils::_build.matrix $x $degree]
#~ set b [::ok_utils::_build.vector $x $y $degree]
#~ # solve it
#~ set coeffs [math::linearalgebra::solveGauss $A $b]
#~ # show results
#~ puts $coeffs


################################################################################
## DXO lighten-shadows curve:
### ToneCurveMasterPoints = {0,0, 0.2625,0.3325, 0.4975,0.545, 0.75,0.7475, 1,1}
## set xTOy {0 0  0.2625 0.3325  0.4975 0.545  0.75 0.7475  1 1}
## set coeffs [ok_utils::ok_fit_curve $xTOy 4]
## ::ok_utils::ok_describe_curve_fitting $xTOy $coeffs 4
## ::ok_utils::ok_format_curve_fitting $xTOy $coeffs 4
#### ==> 0.1542,0.4587,-1.1460,1.5331,0.0000
### Example of DXO lighten-shadows curve application:
### foreach f [glob -nocomplain {INP/*.JPG}]  {[string trim $IMCONVERT "{}"] $f -function Polynomial   0.1542,0.4587,-1.1460,1.5331,0.0000 [file join LIGHTEN DXO_01 [file tail $f]]}
################################################################################


