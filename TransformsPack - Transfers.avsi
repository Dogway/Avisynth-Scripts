###########################################################
###                                                      ##
###                                                      ##
###   Transforms Pack - Transfers v1.0 RC55 (05-08-2022) ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182825    ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
### TRANSFERS:                                           ##
###     moncurve_f   /  moncurve_r                       ##
###     ACEScct_f    /  ACEScct_r                        ##
###     OETF_2084    /  EOTF_2084                        ##
###     OOTF                                             ##
###     SMPTE_legal                                      ##
###     Full_scale                                       ##
###     SoftLimiter                                      ##
###                                                      ##
###########################################################


##########################################
###                                     ##
###         TRANSFER FUNCTIONS          ##
###                                     ##
##########################################


# OETF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_f (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(c,rgb) ? 0 : 1

    gamma  = Default(gamma, 1/0.45)       # gamma
    alpha  = Default(alpha,   0.0 )       # extension in x coords of the linear part
    tv_in  = Default(tv_range_in,    !fs)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )    # Chroma planes TV<->PC conversion or not
    si     = ex_UVf(rgb, bi)

    scl = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    beta   = (( gamma - 1.0) / alpha) * pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = alpha / ( gamma - 1.0)
    aplus  = 1 / (1. + alpha)
    eps    = 8 < bi < 32 ? "0.001 -" : ""

    str    = alpha > 0.0 ? Format("range_min x "+rangePC+" max A@ {phi} > A {alpha} + {aplus} * {gamma} ^ A {beta} * ? "+rangeTV) : \
                           Format("range_min x "+rangePC+" "+eps+" max {gamma} ^ "+rangeTV+"")

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    gamma <= 1.0 ? last                                      : \
    isy          ? Expr(str                       , lut=lut) : \
    UV == 1      ? Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0)        : last }


# EOTF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_r (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(c,rgb) ? 0 : 1

    gamma  = Default(gamma, 1/0.45)       # gamma
    alpha  = Default(alpha,   0.0 )       # extension in x coords of the linear part
    tv_in  = Default(tv_range_in,    !fs)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )    # Chroma planes TV<->PC conversion or not
    si     = ex_UVf(rgb, bi)

    scl = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    beta   = pow( alpha * gamma  /  (  (  gamma - 1.0) *      ( 1.0 + alpha)), gamma)
    phi    = pow( ( gamma - 1.0) / alpha, gamma - 1.0) * pow( ( 1.0 + alpha) / gamma, gamma)
    igam   = 1. / gamma
    aplus  = 1. + alpha

    str    = alpha > 0.0 ? Format("range_min x "+rangePC+" max A@ {beta} > {aplus} A {igam} ^ * {alpha} - A {phi} * ? "+rangeTV) : \
                           Format("range_min x "+rangePC+" max {igam} ^ "+rangeTV+"")

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    gamma <= 1.0 ? last                                      : \
    isy          ? Expr(str                       , lut=lut) : \
    UV == 1      ? Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0)        : last }


# Linear to ACEScct: https://github.com/ampas/aces-dev
function ACEScct_f (clip c, bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(c,rgb) ? 0 : 1

    tv_in  = Default(tv_range_in,     !fs)
    tv_out = Default(tv_range_out,  tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )
    si     = ex_UVf(rgb, bi)

    scl    = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    X_BRK  = 0.0078125
    coeffA = 10.5402377416545
    coeffB = 0.0729055341958355
    lb     = 1. / log(2)
    coeffC = 1. / 17.52

    str    = Format("x "+rangePC+" A@ {X_BRK} <= A {coeffA} * {coeffB} + A log {lb} * 9.72 + {coeffC} * ? "+rangeTV)

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    isy     ?      Expr(str                       , lut=lut) : \
    UV == 1 ?      Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0)        : last }


# ACEScct to Linear: https://github.com/ampas/aces-dev
function ACEScct_r (clip c, bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(c,rgb) ? 0 : 1

    tv_in  = Default(tv_range_in,    !fs)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )
    si     = ex_UVf(rgb, bi)

    scl    = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    Y_BRK  = 0.155251141552511
    coeffA = 1 / 10.5402377416545
    coeffB = 0.0729055341958355

    str    = Format("x "+rangePC+" A@ {Y_BRK} > 2 A 17.52 * 9.72 - ^ A {coeffB} - {coeffA} * ? "+rangeTV)

    str    = ex_dlut( str, bi,!tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    isy     ?      Expr(str                       , lut=lut) : \
    UV == 1 ?      Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0)        : last }



# Requires RGB input
function OETF_2084 (clip c, int "MasterLevel", bool "tv_range") {
    c
    fs        = propNumElements("_ColorRange")  > 0 ? \
                propGetInt     ("_ColorRange") == 0 : isRGB()
    PL        = Default (MasterLevel, 10000) # Max Mastering Level in Nits -cd/m2- (1000 - 10000)
    tv_in     = Default (tv_range, !fs)
    SI        = tv_in ? "int" : "intf"
    PL        = PL / 10000. # 10000 is assumed for 1.0

    N1 = 2610./4096 * 0.25
    M1 = 2523./4096 * 128
    C1 = 3424./4096         # or 1 + c3 - c2
    C2 = 2413./4096 * 32
    C3 = 2392./4096 * 32

    # From BT.2124-0 Annex 2 Conversion 3
    rangePC = tv_in ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_in ? "ymax ymin - * ymin +"   : "range_max *"

    ConvertToPlanarRGB()
    ex_lut(Format(""+rangePC+" 1 {M1} / ^ A@ {C1} - 0 max   {C2} {C3} A * - /    1 {N1} / ^ {PL} * "+rangeTV+"")) }


function EOTF_2084 (clip c, int "MasterLevel", bool "tv_range") {
    c
    fs        = propNumElements("_ColorRange")  > 0 ? \
                propGetInt     ("_ColorRange") == 0 : isRGB()
    PL        = Default (MasterLevel, 10000) # Max Mastering Level in Nits -cd/m2- (1000 - 10000)
    tv_in     = Default (tv_range, !fs)
    SI        = tv_in ? "int" : "intf"
    PL        = PL / 10000. # 10000 is assumed for 1.0

    N1 = 2610./4096 * 0.25
    M1 = 2523./4096 * 128
    C1 = 3424./4096         # or 1 + c3 - c2
    C2 = 2413./4096 * 32
    C3 = 2392./4096 * 32

    rangePC = tv_in ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_in ? "ymax ymin - * ymin +"   : "range_max *"

    ConvertToPlanarRGB()
    ex_lut(Format(""+rangePC+" B@ {N1} ^ A^ B range_min > {C1} {C2} A * + {PL} {C3} A * + / {M1} ^ range_min ? "+rangeTV+"")) }



# Surround adaptation, or Display-to-Display transfer conversion (also for fast inverse OETF conversion when in linear space to retrieve scene-referred)
# Typical values:
#    Dim to Dark:    1/0.9811
#    Neutral to Dim: 1.2

function OOTF (clip a, float "OOTF", val "OETF", val "EOTF", bool "show") {

    rgb   = isRGB(a)
    bi    = BitsPerComponent(a)
    fs    = propNumElements (a,"_ColorRange")  > 0 ? \
            propGetInt      (a,"_ColorRange") == 0 : rgb

    OOTFd     = Defined (OOTF) ?          OOTF  : 0
    OETF      = Defined (OETF) ? isString(OETF) ? color_Fuzzy_Search(OETF) : OETF : ["","",""]
    EOTF      = Defined (EOTF) ? isString(EOTF) ? color_Fuzzy_Search(EOTF) : EOTF : ["","",""]
    sh        = Default (show, false)

    s_gam     = isFloat(OETF) ? [OETF,0] : moncurve_coef(OETF[2]) # still need to work on OOTF for transfers with alpha (maybe do a power law fit?)
    d_gam     = isFloat(EOTF) ? [EOTF,0] : moncurve_coef(EOTF[2])

    if (s_gam[1]>0) {

        # moncurve_f
        gamma = s_gam[0]      alpha  = s_gam[1]
        aplus = 1.0 + alpha   gmins  = gamma - 1.0
        beta  = (gmins / alpha) * pow( alpha * gamma / ( gmins * aplus), gamma)
        phi   =  alpha / gmins
        aplus =  1 / aplus

        # Minimize sum of squares
        m1 = [100,0]
        i = max(1,ceil(alpha*100))

        for (p=150, 600, 1) {
            po = p/300.
            b = 0
            for (n=i, 70, 1) {
                x1 = n/100.
                y1 = ( x1 > phi) ? pow( ( x1 + alpha) * aplus, gamma) : x1 * beta
                b  = pow(pow(x1,po)-y1,2)+b  # SSQ sum of squares
                }
                m1 = b < m1[0] ? [b,po] : m1
    }
    m1 = m1[1]
    } else { m1 = s_gam[0] }

    if (d_gam[1]>0) {

        # moncurve_f
        gamma = d_gam[0]      alpha  = d_gam[1]
        aplus = 1.0 + alpha   gmins  = gamma - 1.0
        beta  = (gmins / alpha) * pow( alpha * gamma / ( gmins * aplus), gamma)
        phi   =  alpha / gmins
        aplus =  1 / aplus

        # Minimize sum of squares
        m2 = [100,0]
        i = max(1,ceil(alpha*100))

        for (p=150, 600, 1) {
            po = p/300.
            b = 0
            for (n=i, 70, 1) {
                x1 = n/100.
                y1 = ( x1 > phi) ? pow( ( x1 + alpha) * aplus, gamma) : x1 * beta
                b  = pow(pow(x1,po)-y1,2)+b  # SSQ sum of squares
                }
                m2 = b < m2[0] ? [b,po] : m2
    }
    m2 = m2[1]
    } else { m2 = d_gam[0] }

    OOTF = OOTFd==0 ? m1/m2 : OOTFd
    ex_lut(a, Format("f32 x 0 < x range_min x max {OOTF} ^ ?"))

    if (sh) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=fs) : last
        w   = a.width()
        h   = a.height()
        sw  = nmod(w/5.)   sh = min(h,sw)
        plt = GradientLinear(last,zoom=1, precision=2, positive=true, smooth=true, tv_range=false)
        plt = ex_lut(plt, Format("x {OOTF} ^"))
        plt = HistoCurve(plt,size=2,gradient=false).BicubicResize(sw,sh,-0.5,0.25)
        plt = rgb ? plt.ConvertToPlanarRGB() : plt
        plt = Merge(PadBorders(plt.subtitle(Format(OOTFd!=0?"":"{m1}/{m2}=")+string(OOTF)),w-sw,0,0,h-sh))
        ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
    } }




# Other names:  Studio Swing, Broadcast Safe, Limited/Legal/SMPTE/Standard/Narrow/Video/Head/TV range.
# For opposite: Full Swing, Full/Data/CG/RGB/PC range.
# Other:        SMPTE+, Camera Range or Extended Range (Ocassional case in broadcast, camera recordings or in HLG for 10-bit [64-1019] narrow blacks + super-whites)
#
# Full Range also needs to abide to Video Data range but only for broadcast with SDI interfaces,
# ...that is 1-254 for 8-bits, 4-1019 for 10-bits and so on... For these cases set broadcast=true (see "EBU R 103 v3.0" page 7 for details)

function SMPTE_legal (clip a, bool "forward", int "Y", int "UV", bool "fulls", bool "fulld", bool "broadcast") {

    rgb = isRGB(a)
    yuv = isYUV(a) # as in !isy && !rgb
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(a,rgb) ? 0 : 1

    fw  = Default(forward,  fs)     # forward converts to SMPTE legal, otherwise converts to Full Range.
    Y   = Default(Y,            3 )
    UV  = Default(UV, isy ? 1 : 3 )
    fi  = Defined(fulls) || Defined(fulld)
    fs  = Default(fulls,    fs)
    fd  = Default(fulld,   !fw)
    brd = Default(broadcast, false) # enable if you need to author broadcast safe Full Range (within Video Data range). Reverse conversion not implemented (broadcast full to legal).
    si  = ex_UVf(rgb, bi)

    if (fi && fs!=fd || brd) {
        scl  = fs!=fd && ( 8 < bi < 32) ? string(fd ? 257/256. : 256/257.)+" *" : ""

        LO   = ex_bs(  1,  8, bi, fulls=false)
        MX   = ex_bs(255,  8, bi, fulls=true, flt=true)
        LIM  = (MX - LO * 2) / MX
        vd   = brd ? Format("{LIM} * {LO} +") : ""

        str  = fw ? "x ymax ymin - range_max / * ymin  + "+scl : \
                    "x ymin - range_max ymax ymin - / *  "+vd

        cstr = fw ? "x cmax cmin - range_max / * cmin  + "+scl : \
                    "x cmin - range_max cmax cmin - / *  "+vd

        str  =        ex_Yexpr(  str,  Y, bi, rgb, fs)
        cstr = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, fs, si) : str

        isy     ? Expr(a, str                       , lut=lut) : \
        UV == 1 ? Expr(a, str, ""                   , lut=lut) : \
                  Expr(a, str, cstr, scale_inputs=si, lut=lut)
                  propSet("_ColorRange", fw?1:0)
    } else {
        ConvertBits(a, bi, fulls=fw, fulld=!fw)
        Y == 3 && UV != 3 && yuv ? mergechroma(a) : \
        Y != 3 && UV == 3 && yuv ? mergeluma  (a) : \
        Y != 3 && UV != 3        ?             a  : last } } # faster than CombinePlanes()


# For fixing purposes. To convert from bitshift scale to full range scale (saturated range) and reverse (no typical range conversion, as in TV to PC levels)
function Full_scale (clip a, bool "forward", int "Y", int "UV", bool "broadcast") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fsd = propNumElements (a,"_ColorRange")  > 0
    fs  = fsd                                    ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(a,rgb) ? 0 : 1

    fw  = Default(forward,     !fs) # forward converts to full scale, otherwise converts to bitshift scale
    Y   = Default(Y,            3 )
    UV  = Default(UV, isy ? 1 : 3 )
    brd = Default(broadcast, false) # enable if you need to author broadcast safe Full Range (within Video Data range). Reverse conversion not implemented (broadcast full to legal).
    si  = ex_UVf(rgb, bi)

    scl = fw ? 257/256. : 256/257.

    LO   = ex_bs(  1,  8, bi, fulls=false)
    MX   = ex_bs(255,  8, bi, fulls=true, flt=true)
    LIM  = (MX - LO * 2) / MX
    str  = Format(brd ? "x {scl} {LIM} * * {LO} +" : "x {scl} *")

    cstr = !rgb ? ex_UVexpr( str, UV, bi, rgb, fs, si) : ex_dlut(str, bi, fs)
    str  =        ex_Yexpr(  str,  Y, bi, rgb, fs)

    !(8 < bi < 32) ?      a                                       : \
    isy            ? Expr(a, str                       , lut=lut) : \
    UV == 1        ? Expr(a, str, ""                   , lut=lut) : \
                     Expr(a, str, cstr, scale_inputs=si, lut=lut)
    !fsd           ? propSet("_ColorRange", !fw?1:0)              : last }


# SoftLimiter (25-05-2022)
#
# SoftLimiter is an inclusive limiter, it brings sources with under or overshoot values to in-range legal broadcast values
# It does so in a gentle manner by rolling off the values into range without altering the source levels, then clipping leftovers.
# RGB is not yet supported.
#
# Disclaimer1: This is not a range conversion filter! Input is assumed to be "legal/tv range"
# Disclaimer2: For static mode, first find the under and overshoot values by inspecting the clip with show=true
#
# Dependencies: ExTools
#               RgTools      (for dyn>0)
#               ScenesPack   (for dyn=1)
#               ResizersPack (for show)
#
# Examples:
#   SoftLimiter(16,235)              # no rolloff (straight clamp), assumes input IS legal (within 16,235, actually 14-238 with default EBU R 103 'tolerance=1.25')
#   SoftLimiter(12,240,12,245)       # Bring specified values to legal range with rolloff
#   SoftLimiter(dyn=2)               # Bring           values to legal range with rolloff (values defined by dynamic stats)
#   SoftLimiter(dyn=1)               # Bring           values to legal range with rolloff (values defined by scene   stats)
#
# modes:
# dyn = 0  -> static mode, set values after manual inspection (Default)
# dyn = 1  -> accumulative scene  dynamic mode. Medium,         will bring some values into range (requires '_SceneRange' frameprops)
# dyn = 2  ->              loose  dynamic mode. Medium,         will bring some values into range (recommended)
# dyn = 3  ->              strict dynamic mode. Very sensitive, will bring many values into range
#
#
# * Tolerance: Tolerance defines the legal range target, by default 1.25% for an EBU R 103 (v1.1) compliant range of 14-238.
#              This contrasts with the lo/hi limit arguments, which directly defines the strength of the rolloff to the aforementioned target.
#              EBU R 103 (v3.0) accepts a tolerance of 5% (5-246) but that certainly looks a bit of a stretch for a legal range, specially on averaged stats.
# Example:
#   SoftLimiter(10,245,tol=1.25)     # Bring values of 10 and 245 to 14 and 238 respectively
#
#
# Function Definition:
#    (
#    clip,
#    float lo=16.0 (0.0 to 16.0),
#    float hi=235.0 (235.0 to 255.0),
#    [float "lo_c"=16.0 (0.0 to 16.0)],
#    [float "hi_c"=240.0 (235.0 to 255.0)],
#    [float "tolerance"=1.25 (0.00 to 35.00 by 0.05)],
#    [int "dyn"=0 (0 to 3)],
#    [bool "show"=false]
#    )
#
function SoftLimiter (clip a, float "lo", float "hi", float "lo_c", float "hi_c", float "tolerance", int "dyn", bool "show", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    w   = Width(a)
    h   = Height(a)
    bi  = BitsPerComponent(a)
    st  = propNumElements (a,"_SceneStats")  > 0
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = isRunTime(a,rgb) || bi == 32 ? 0 : 1

    lo  = Default(lo,      16)   # Low  limit
    hi  = Default(hi,     235)   # High limit
    loc = Default(lo_c,    lo)   # Low  limit (Chroma)
    hic = Default(hi_c,  hi+5)   # High limit (Chroma)
    tol = Default(tolerance,1.25)# 0-100 Percentage of allowed under/overshoots (~1.25% is an accepted range -14-238-, range 238-242 is for superwhites)
    dyn = Default(dyn,      0)   # 0: static  1: per-scene accumulated loose (min/max 0.454% ignored)  2: medium (min/max 0.2% ignored)  3: strict (min/max 0.1% ignored)
    sh  = Default(show, false)
    UV  = Default(UV, isy ? 1 : 3 )
    si  = ex_UVf(rgb, bi)

    lo  = clamp(lo,0,16)      loc  = clamp(loc,0,16)
    hi  = clamp(hi,235,255)   hic  = clamp(hic,240,255)

   # WIP
   # if (tol > 0) {
   # tol = tol/100.
   # lu  = 220. * tol
   # ch  = 225. * tol
   # lo  = lo + lu    loc  = loc + ch
   # hi  = hi - lu    hic  = hic - ch
   # lo  = max(0,   lo)   loc  = max(0,   loc)
   # hi  = min(255, hi)   hic  = min(255, hic)
   # }

    # Store for 'show' when dyn=0
    if (sh && dyn==0) {
        slo  = lo
        shi  = hi
        sloc = loc
        shic = hic
        sdyn = dyn
    }


    lo0 = lo == 16                loc0 = loc == 16
    hi0 = hi == 235               hic0 = hic == 240


    if (sh) {

        a.ConvertBits(8, dither=bi==32?-1:1, fulls=fs)
        w4   = nmod(w/4.)
        h2   = nmod(h/2.)
        w2   = w4*2
        n4   = min(w4,h2)
        padw = (w4-n4)/2
        padh = (h2-n4)/2
        lo   = ex_bs(lo,  8, bi, fs)
        loc  = ex_bs(loc, 8, bi, fs)
        loc  = bi > 16 ? loc - 0.5 : loc
        hi   = ex_bs(hi,  8, bi, fs)
        hic  = ex_bs(hic, 8, bi, fs)
        hic  = bi > 16 ? hic - 0.5 : hic

        b = StackHorizontal( \
            Histogram("levels").blackmanresize(w4,h2,w,0,256,256), \
            Histogram("color2").blackmanresize(n4,n4,w,0,256,256).AddBorders(padw+padw%2, padh+padh%2, padw-padw%2, padh-padh%2) )

        c = StackVertical( \
            a.Limiter(lo, hi, loc, hic, "luma_grey"  ).Subtitle("Luma Spill"  , align=7, size=30), \
            a.Limiter(lo, hi, loc, hic, "chroma_grey").Subtitle("Chroma Spill", align=7, size=30) ).BicubicResize(w2,h2*2,-0.5,0.25).ConvertBits(8, dither=1, fulls=fs)

        d = TurnRight().Histogram(mode="classic").BilinearResize(h2,w2,src_left=h2*2,src_width=-0).TurnLeft()

        s = StackHorizontal(StackVertical(d, b), c).PadResize(w, h ).ConvertBits(bi, fulls=fs)
    }

    if (dyn == 1) {

        Assert(propNumElements(a,"_SceneRange")>0, "SoftLimiter: dyn=1 requires '_SceneRange' frame properties.")
        !st ? SceneStats(a,"Stats",dClip=removegrain(a,12,UV==3?12:-1),th=0.454,UV=uv==3) : a

        ScriptClip(function [tol,bi,fs,uv,sh] () {

            uv3  = uv == 3
            stY  =       propGetAsArray("_SceneStats")
            stU  = uv3 ? propGetAsArray("_SceneStatsU") : nop()
            stV  = uv3 ? propGetAsArray("_SceneStatsV") : nop()
            Yn   = stY[2]
            Ym   = stY[3]
            UVn  = uv3 ? min(stU[0],stV[0]) : 16
            UVm  = uv3 ? max(stU[1],stV[1]) : 240

            SoftLimiter(Yn, Ym, UVn, UVm, tol, 0, false, uv)
            fl = "%0.2f"  gp="     "
            sh ? Subtitle("YMin: " +string(ex_bs(Yn,  bi, 8, fs, flt=true), fl)+gp+ \
                          "YMax: " +string(ex_bs(Ym,  bi, 8, fs, flt=true), fl)+gp+ \
                          "UVMin: "+string(ex_bs(UVn, bi, 8, fs, flt=true), fl)+gp+ \
                          "UVMax: "+string(ex_bs(UVm, bi, 8, fs, flt=true), fl), align=1) : last }, after_frame=true )

    } else if (dyn > 1) {
        a
        ab = removegrain(12,UV==3?12:-1) # clearing over/undershoots (EBU recommends ex_boxblur(5,1,mode="weighted"))
        th = dyn > 2 ? 0.1 : 0.2
        PS = "Y  = PlaneMinMaxStats(ab, th, 0, 0, false)
              U  = PlaneMinMaxStats(ab, th, 0, 1, false)
              V  = PlaneMinMaxStats(ab, th, 0, 2, false)
              Y1 = ex_bs(Y[2], bi, 8, fs, flt=true)     Y2 = ex_bs(Y[3], bi, 8, fs, flt=true)
              U1 = ex_bs(U[2], bi, 8, fs, flt=true)     U2 = ex_bs(U[3], bi, 8, fs, flt=true)
              V1 = ex_bs(V[2], bi, 8, fs, flt=true)     V2 = ex_bs(V[3], bi, 8, fs, flt=true)"

            ScriptClip( function [ab,bi,fs,th,PS,tol,uv,sh] () {
            Eval(PS)
            UVn = min(U1,V1)
            UVm = max(U2,V2)
            fl = "%0.2f"  gp="     "
            SoftLimiter(             Y1,Y2,UVn,UVm, tol, 0, false, uv)
            sh ? propSet("_MinMaxStats", [Y1,Y2,UVn,UVm]) : last
            sh ? Subtitle("YMin: "+string(Y1, fl)+gp+"YMax: "+string(Y2, fl)+gp+"UVMin: "+string(UVn, fl)+gp+"UVMax: "+string(UVm, fl), align=1) : last }, after_frame=true )

    } else {

        lol  = ex_bs(lo,  8, bi, fs, flt=true)
        hil  = ex_bs(hi,  8, bi, fs, flt=true)
        hicl = ex_bs(hic, 8, bi, fs, flt=true)

    if (lo0 && loc0 && hi0 && hic0 && !(w == h == 256)) {

        limiter(a, round(lol),round(hil),round(bi>16?lol-0.5:lol),round(bi>16?hicl-0.5:hicl))

    } else {

        b = spline(hi,  236,-0.44, 237,-0.815, 238,-1.131, 239,-1.396, 240,-1.617, 241,-1.8, 242,-1.951, 243,-2.073, 244,-2.17, 245,-2.247, 246,-2.305, 247,-2.348, 248,-2.378, 249,-2.397, 250,-2.4065, 251,-2.408, 252,-2.408, 253,-2.408, 254,-2.4078, 255,-2.4077)
        c = spline(hic, 236,-0.44, 237,-0.815, 238,-1.131, 239,-1.396, 240,-1.617, 241,-1.8, 242,-1.951, 243,-2.073, 244,-2.17, 245,-2.247, 246,-2.305, 247,-2.348, 248,-2.378, 249,-2.397, 250,-2.4065, 251,-2.408, 252,-2.408, 253,-2.408, 254,-2.4078, 255,-2.4077)
        d = spline(lo,  0,-1.871, 1,-1.861, 2,-1.845, 3,-1.8215, 4,-1.7905, 5,-1.7495, 6,-1.697, 7,-1.6325, 8,-1.552, 9,-1.454, 10,-1.3365, 11,-1.195, 12,-1.028, 13,-0.829, 14,-0.595, 15,-0.321)
        e = spline(loc, 0,-1.871, 1,-1.861, 2,-1.845, 3,-1.8215, 4,-1.7905, 5,-1.7495, 6,-1.697, 7,-1.6325, 8,-1.552, 9,-1.454, 10,-1.3365, 11,-1.195, 12,-1.028, 13,-0.829, 14,-0.595, 15,-0.321)

        phi = 20
        phr = 1./phi
        bi32m = bi == 32 ? "" : " range_max *"
        bi32d = bi == 32 ? "" : " range_max /"

        hi  = Format("    x "+bi32d+"   dup log {phi} * exp 1 + log {phr} {b} * * "+expT(1)+" *  ")
        lo  = Format("1 1 x "+bi32d+" - dup log {phi} * exp 1 + log {phr} {d} * * "+expT(1)+" * -")
        hic = Format("    x "+bi32d+"   dup log {phi} * exp 1 + log {phr} {c} * * "+expT(1)+" *  ")
        loc = Format("1 1 x "+bi32d+" - dup log {phi} * exp 1 + log {phr} {e} * * "+expT(1)+" * -")

        clp = w == h == 256 # for plot purposes
        str  = (lo0  && hi0  ? "x " :  (lo0  && !hi0  ? hi  : !lo0  && hi0  ? lo  : "x range_half > "+hi +" "+lo +" ?") + bi32m) + ( clp ? "" : Format(" {lol} {hil}  clip")) # still need to account for 'tolerance'
        cstr =  loc0 && hic0 ? "x " : ((loc0 && !hic0 ? hic : !loc0 && hic0 ? loc : "x range_half > "+hic+" "+loc+" ?") + bi32m  + ( clp ? "" : Format(" {lol} {hicl} clip")))


        str  =        ex_dlut  ( str,     bi,      fs)
        cstr = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, fs, si) : str

        isy     ? Expr(a, str                       , lut=lut) : \
        UV == 1 ? Expr(a, str, ""                   , lut=lut) : \
                  Expr(a, str, cstr, scale_inputs=si, lut=lut) } }

    if (sh) {
        sts = propNumElements("_MinMaxStats") > 0
        st4 = propNumElements("_SceneStats")  > 0
        sw  = nmod(w/5.)   sh = sw
        plt = GradientLinear(last, zoom=1, positive=true, precision=dyn!=0?1:2, smooth=true, tv_range=false)
        plt = sts || st4 ? ScriptClip(blankclip(last,width=256,height=256,channels=0), function[last,plt,st4,bi,fs,uv] () {
                        sts = st4          ? propGetAsArray("_SceneStats")  : propGetAsArray("_MinMaxStats")
                        stu = st4 && uv==3 ? propGetAsArray("_SceneStatsU") : [16,240]
                        SoftLimiter(plt, st4 ? ex_bs(sts[2], bi, 8, fs, flt=true) : sts[0], \
                                         st4 ? ex_bs(sts[3], bi, 8, fs, flt=true) : sts[1], \
                                         st4 ? ex_bs(stu[0], bi, 8, fs, flt=true) : sts[2], \
                                         st4 ? ex_bs(stu[1], bi, 8, fs, flt=true) : sts[3],0,0)
                        HistoCurve(size=1,gradient=false) } ) : \
                    plt.SoftLimiter (slo,shi,sloc,shic,0,0)
        plt = sts || st4 ? plt : plt.HistoCurve(size=2,gradient=false)
        plt = plt.BicubicResize(sw,sh,-0.5,0.25)
        plt = PadBorders(plt,w-sw,0,0,h-sh)
        plt = Merge(plt)
        plt = ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
        StackVertical(plt, s) } }
