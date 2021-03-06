##############################
# FastLineDarken 2.0 MOD ex  #
##############################
#
# Written by Vectrangle    (http://forum.doom9.org/showthread.php?t=82125)
# Did�e: - Speed Boost, Updated: 11th May 2007
# Dogway - added protection option. 12-May-2011
# Dogway - 2.0ex Updated to internal Expr(). 27-May-2021
#
#  * requires mt_masktools v2
#  * requires yv12 input
#
# Usage is FastLineDarkenMOD(strength, prot, luma_cap, threshold, thinning),
#   named parameters are supported eg FastLineDarken(thinning=0)
#
# Note that you must import this avs into your script using import("...\FastLineDarken.avs")
#
# Parameters are:
#  strength (integer)  - Line darkening amount, 0-256. Default 48. Represents the _maximum_ amount
#                        that the luma will be reduced by, weaker lines will be reduced by
#                        proportionately less.
#  prot     (integer)  - Prevents the darkest lines from being darkened. Protection acts as a threshold.
#                        Values range from 0 (no prot) to ~50 (protect everything)
#  luma_cap (integer)  - value from 0 (black) to 255 (white), used to stop the darkening
#                        determination from being 'blinded' by bright pixels, and to stop grey
#                        lines on white backgrounds being darkened. Any pixels brighter than
#                        luma_cap are treated as only being as bright as luma_cap. Lowering
#                        luma_cap tends to reduce line darkening. 255 disables capping. Default 191.
#  threshold (integer) - any pixels that were going to be darkened by an amount less than
#                        threshold will not be touched. setting this to 0 will disable it, setting
#                        it to 4 (default) is recommended, since often a lot of random pixels are
#                        marked for very slight darkening and a threshold of about 4 should fix
#                        them. Note if you set threshold too high, some lines will not be darkened
#  thinning (integer)  - optional line thinning amount, 0-256. Setting this to 0 will disable it,
#                        which is gives a _big_ speed increase. Note that thinning the lines will
#                        inherently darken the remaining pixels in each line a little. Default 0.
#
# Changelog:
#  2.0  - Converted all masktools2 calls to internal Expr(). Supports HBD.
#  1.4  - added protection option. Prevents darkest lines to be over darkened thus creating artifacts (i.e. aliasing, clipping...)
#       - Optmized the code as suggested by Did�e for possible faster processing. It also deals with the green screen bug.
#  1.3  - added ability to thin lines, now runs much slower unless thinning=0. Changed the defaults (again)
#  1.2  - huge speed increase using yv12lutxy =)
#       - weird darkening issues gone (they were caused by yv12layer)
#       - show option no longer available due to optimizations. Use subtract() instead
#  1.1  - added luma_cap option
#  1.0  - initial release
#


function FastLineDarkenMOD( clip c, int "strength", int "prot", int "luma_cap", int "threshold", int "thinning")
{
## parameters ##
str        = Default(strength, 50) / 128.
lum 	   = Default(luma_cap, 191)
protection = Default(prot,5)
thr 	   = Default(threshold, 4)
thinning   = Default(thinning,0)
thn 	   = thinning /16.

Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

## filtering ##
exin	= c.ex_expand(thres=255/(protection+1)).ex_inpand()
diff 	= Expr(c,exin,Format("y {lum} < y {lum} ? x {thr} + > x y {lum} < y {lum} ? - 0 ? range_half +"), "x", scale_inputs="allf")
linemask= Expr(diff.ex_inpand(),Format("x range_half - {thn} * range_max +"), scale_inputs="allf").ex_boxblur(1,UV=1)
thick 	= Expr(c, exin, Format("y {lum} < y {lum} ? x {thr} + > x y {lum} < y {lum} ? - 0 ? {str} * x +"), "x", scale_inputs="allf")
thin 	= Expr(c.ex_expand(),diff,Format("x y range_half - {str} 1 + * +"), scale_inputs="allf")

(thinning == 0) ? thick : ex_merge(thin,thick,linemask,UV=2)
return mergechroma(c)}