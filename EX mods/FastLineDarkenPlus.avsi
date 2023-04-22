#################################
###     FastLineDarkenPlus     ##
#################################
###
###
### Written by Vectrangle    (https://forum.doom9.org/showthread.php?t=82125)
### Didée: - Speed Boost, Updated:             11-May-2007
### Dogway - added protection option.          12-May-2011
### Dogway - 2.0ex to 2.3ex Updated to ExTools 05-Mar-2022
### Dogway - Plus  Optimizations.              23-Apr-2023
###
###
### Parameters:
###  strength (integer)  - Line darkening amount, 0-256. Default 48. Represents the _maximum_ amount
###                        that the luma will be reduced by, weaker lines will be reduced by
###                        proportionately less.
###  prot     (integer)  - Prevents the darkest lines from being darkened. Protection acts as a threshold.
###                        Values range from 0 (no prot) to ~50 (protect everything)
###  luma_cap (integer)  - value from 0 (black) to 255 (white), used to stop the darkening
###                        determination from being 'blinded' by bright pixels, and to stop grey
###                        lines on white backgrounds being darkened. Any pixels brighter than
###                        luma_cap are treated as only being as bright as luma_cap. Lowering
###                        luma_cap tends to reduce line darkening. 255 disables capping. Default 191.
###  threshold (integer) - any pixels that were going to be darkened by an amount less than
###                        threshold will not be touched. setting this to 0 will disable it, setting
###                        it to 4 (default) is recommended, since often a lot of random pixels are
###                        marked for very slight darkening and a threshold of about 4 should fix
###                        them. Note if you set threshold too high, some lines will not be darkened
###  thinning (integer)  - optional line thinning amount, 0-256. Setting this to 0 will disable it,
###                        which is gives a _big_ speed increase. Note that thinning the lines will
###                        inherently darken the remaining pixels in each line a little. Default 0.
###
###
### Function Definition:
###     (
###     clip,
###     int "strength"=48 (0 to 255),
###     int "prot"=5 (0 to 20),
###     int "luma_cap"=191 (0 to 255),
###     int "threshold"=4 (0 to 128),
###     int "thinning"=24 (0 to 128)
###     )
###
###
function FastLineDarkenPlus( clip c, int "strength", int "prot", int "luma_cap", int "threshold", int "thinning") {

    rgb  = isRGB(c)
    bi   = BitsPerComponent(c)
    fs   = propNumElements (c,"_ColorRange")  > 0 ? \
           propGetInt      (c,"_ColorRange") == 0 : rgb

    str        = Default(strength,  50) / 128.
    lum        = Default(luma_cap, 191)
    protection = Default(prot,       5)
    thr        = Default(threshold,  4)
    thinning   = Default(thinning,   0)
    UV         = rgb ? 3 : 1

    Assert(IsVersionOrGreater(3,7,3), "FastLineDarkenPlus: Update AviSynth+ version")

    thr = ex_bs(thr, 8, bi, fulls=fs)
    lum = ex_bs(lum, 8, bi, fulls=fs)
    thn = thinning / 16.

    close  = ex_expand (c,thres=255/(protection+1),UV=uv).ex_inpand(UV=uv)

    if (thinning<1) {

             ex_lutxy  (c, close,  Format("y {lum} min A@ x {thr} + > x A - {str} * x + x ?"),           UV=uv, fulls=fs)

    } else {

        DF = ex_lutxy  (c, close,  Format("y {lum} min A@ x {thr} + > x A - range_half + range_half ?"), UV=uv, fulls=fs)
        LM = ex_lut    (       DF, Format("              x[-1,1] x[0,1] min x[1,1] min x[-1,0] min x[0,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min range_half - {thn} * range_max + "),                        UV=uv, fulls=fs).ex_boxblur(1,mode="mean",UV=uv)
             ex_lutxyz (c, LM, DF, Format("z range_half -    dup
                                             {str} 1 + * x[-1,1] x[0,1] max x[1,1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,-1] max x[0,-1] max x[1,-1] max +
                                                             dup      swap2 {str} * x +
                                           - y range_max / * -"), UV=uv)
    } }


### Changelog:
###  Plus - Merge 'thin', 'thick' and 'merge' into one call for +13% performance increase (+39% in HBD). Some logic refactor and RGB support.
###  2.3  - Minor expr optimizations
###  2.2  - Updated to latest ExTools v6.9
###  2.1  - Updated to latest ExTools v5.5
###  2.0  - Converted all MaskTools2 calls to internal Expr(). Supports HBD.
###  1.4  - added protection option. Prevents darkest lines to be over darkened thus creating artifacts (i.e. aliasing, clipping...)
###       - Optmized the code as suggested by Didée for possible faster processing. It also deals with the green screen bug.
###  1.3  - added ability to thin lines, now runs much slower unless thinning=0. Changed the defaults (again)
###  1.2  - huge speed increase using yv12lutxy =)
###       - weird darkening issues gone (they were caused by yv12layer)
###       - show option no longer available due to optimizations. Use subtract() instead
###  1.1  - added luma_cap option
###  1.0  - initial release