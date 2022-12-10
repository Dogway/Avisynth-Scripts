###########################################################
###                                                      ##
###                                                      ##
###   Transforms Pack - Transfers v1.1    (10-12-2022)   ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182825    ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
### TRANSFERS:                                           ##
###     CCTF                                             ##
###     moncurve_f   /   moncurve_r                      ##
###     ACEScct_f    /   ACEScct_r                       ##
###     EOTF_1886a   /   EOTFi_1886a                     ##
###     EOTF_Apple   /   EOTFi_Apple                     ##
###     EOTF_Chrome  /   EOTFi_Chrome                    ##
###     EOTF_2084    /   EOTFi_2084                      ##
### LOOKS:                                               ##
###     LMT_EMoR     /   LMTi_EMoR                       ##
###     LMT_DCP      /   LMTi_DCP                        ##
###     Display_Sim                                      ##
###     OOTF                                             ##
### TONEMAPPERS:                                         ##
###     TM_2446C                                         ##
### RANGE:                                               ##
###     SMPTE_legal                                      ##
###     Full_scale                                       ##
###     SoftLimiter                                      ##
###                                                      ##
###########################################################
###
###
###
##########################################
###                                     ##
###         TRANSFER FUNCTIONS          ##
###                                     ##
##########################################
###
### Known by many names;
###                      Gamma
###                      Conversion Function -CF-
###                      Tone Response Curve -TRC-
###                      Tone Response Functions -TRF-
###                      Transfer Function -TF-
###                      Color Component Transfer Function -CCTF-
###                      Tone Scale (like the Single-Stage Tone Scale -SSTS-)

# -linear
# -470BG
# -470M
# -170M / 709-Camera
# -240M
# -sRGB
# -1886
# -1886a
# -AdobeRGB
# -DCI-P3/XYZ
# -Chrome
# -CIELab
# -AppleRGB
#  xvYCC
# -PQ (2084)
#  HLG
#  ACESCC
# -ACESCCt
#  Arri LogC
#  BMDFilm
#  Bolex Log
#  CanonLog
#  CanonLog2
#  CanonLog3
#  Cineon
#  DJI D-Log
#  Fuji F-Log
#  GoPro ProTune Flat
#  JPLog
#  Nikon N-Log
#  Panasonic V-Log
#  Phantom Log 1 Normalized
#  Phantom Log 2 Normalized
#  RED Log3G10
#  RED Log3G12
#  RED LogFilm
#  Log100
#  Log316
#  Sony S-Log
#  Sony S-Log2
#  Sony S-Log3
#  logc2
#  logc3
#  ZLog2
#  OpenDRT
#  JzDT
#  AgX


### CCTF() or Color Component Transfer Function, comprehends EOTF/OETFi (forward=true) and OETF/EOTFi (forward=false).
### Use this function as the main transfer function to use for different CCTFs that matches 'transfer' string.
###
### Function Definitions:
###     (
###     clip,
###     string "transfer"="sRGB" ("linear"/ "1886a"/ "1886"/ "470M"/ "470BG"/ "240M"/ "170M"/ "709-Camera"/ "sRGB"/ "AdobeRGB"/ "CIELab"/ "Apple"/ "Chrome"/ "xvYCC"/ "PhotoCD"/ "2020NCL"/ "2020CL"/ "DCIXYZ"/ "PQ"/ "HLG"/ "HLG NHK"/ "ACESCCt"/ "log100"/ "log316"/ "1361"),
###     [bool "fw"=true],
###     [bool "tv_in"=false],
###     [bool "tv_out"=false],
###     [bool "show"=false]
###     )
###
function CCTF (clip c, string "transfer", bool "fw", bool "tv_in", bool "tv_out", bool "show") {

    c
    rgb = isRGB()
    fs  = propNumElements ("_ColorRange")  > 0 ? \
          propGetInt      ("_ColorRange") == 0 : rgb

    trans  = Default(transfer, "sRGB")
    fw     = Default(fw,        true ) # forward; true (to linear), false (from linear)
    tv_in  = Default(tv_in,       !fs)
    tv_out = Default(tv_out,    tv_in)
    sh     = Default(show,      false)

    TRC    = color_Fuzzy_Search(trans)
    trans  = TRC[2]
    s_gam  = moncurve_coef(trans)

     (trans == "1886a"      ) ? fw ? EOTF_1886a (tv_in=tv_in,tv_out=tv_out)  :  EOTFi_1886a (tv_in=tv_in,tv_out=tv_out)
\  : (trans == "AppleRGB"   ) ? fw ? EOTF_Apple (tv_in=tv_in,tv_out=tv_out)  :  EOTFi_Apple (tv_in=tv_in,tv_out=tv_out)
\  : (trans == "Chrome"     ) ? fw ? EOTF_Chrome(tv_in=tv_in,tv_out=tv_out)  :  EOTFi_Chrome(tv_in=tv_in,tv_out=tv_out)
\  : (trans == "PQ"         ) ? fw ? EOTF_2084  (tv_in=tv_in,tv_out=tv_out)  :  EOTFi_2084  (tv_in=tv_in,tv_out=tv_out)
\  : (trans == "HLG"        ) ? fw ? EOTF_HLG   (tv_in=tv_in,tv_out=tv_out)  :  EOTFi_HLG   (tv_in=tv_in,tv_out=tv_out)
\  : (trans == "ACESCCt"    ) ? fw ? ACEScct_f  (tv_in,tv_out,3)             :  ACEScct_r   (tv_in,tv_out,3)
\  :                            fw ? moncurve_f(s_gam[0],s_gam[1],tv_in,tv_out,3) : \
                                     moncurve_r(s_gam[0],s_gam[1],tv_in,tv_out,3)
#\ : (trans == "xvYCC"      ) ? fw ? EOTF_xvYCC  (tv_in=tv_in,tv_out=tv_out) :  EOTFi_xvYCC  (tv_in=tv_in,tv_out=tv_out)
#\ : (trans == "PhotoCD"    ) ? fw ? EOTF_PhotoCD(tv_in=tv_in,tv_out=tv_out) :  EOTFi_PhotoCD(tv_in=tv_in,tv_out=tv_out)

    trans != "linear" ? propSet("_Transfer",   fw ? 8 : TRC[6] ) : last
                        propSet("_ColorRange", tv_out ? 1 : 0  )

    if (sh) {
        BitsPerComponent(c) > 8 ? ConvertBits(8,dither=1,fulls=!tv_out) : last
        w   = c.width()
        h   = c.height()
        sw  = nmod(w/5.)   sh = min(h,sw)
        plt = GradientLinear(last,zoom=1, precision=2, positive=true, smooth=true, tv_range=false)
        plt = CCTF(plt, trans, in, false, false)
        plt = HistoCurve(plt,size=2,gradient=false).BicubicResize(sw,sh,-0.5,0.25)
        plt = rgb ? plt.ConvertToPlanarRGB() : plt
        plt = Merge(PadBorders(plt.subtitle(string(trans)),w-sw,0,0,h-sh))
        ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
    } }




# EOTF/OETFi. Monitor Curve Functions: https://github.com/ampas/aces-dev
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

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    beta   = (( gamma - 1.0) / alpha) * pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = alpha / ( gamma - 1.0)
    aplus  = 1 / (1. + alpha)
    eps    = 8 < bi < 32 ? "0.001 -" : ""

    str    = alpha > 0 ? Format("range_min x "+rangePC+" max A@ {phi} > A {alpha} + {aplus} * {gamma} ^ A {beta} * ? "+rangeTV) : \
                         Format("range_min x "+rangePC+" "+eps+" max {gamma} ^ "+rangeTV+"")

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = rgb ? str : UVRange_construct(tv_in,tv_out,bi,UV)

    gamma <= 1.0 ? tv_in!=tv_out ? SMPTE_legal()  : last     : \
    isy          ? Expr(str                       , lut=lut) : \
    UV == 1      ? Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    gamma >  1.0 ? tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0) : last : last }


# OETF/EOTFi. Monitor Curve Functions: https://github.com/ampas/aces-dev
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

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    beta   = pow( alpha * gamma  /  (  (  gamma - 1.0) *      ( 1.0 + alpha)), gamma)
    phi    = pow( ( gamma - 1.0) / alpha, gamma - 1.0) * pow( ( 1.0 + alpha) / gamma, gamma)
    igam   = 1. / gamma
    aplus  = 1. + alpha

    str    = alpha > 0 ? Format("range_min x "+rangePC+" max A@ {beta} > {aplus} A {igam} ^ * {alpha} - A {phi} * ? "+rangeTV) : \
                         Format("range_min x "+rangePC+" max {igam} ^ "+rangeTV+"")

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = rgb ? str : UVRange_construct(tv_in,tv_out,bi,UV)

    gamma <= 1.0 ? tv_in!=tv_out ? SMPTE_legal()  : last     : \
    isy          ? Expr(str                       , lut=lut) : \
    UV == 1      ? Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    gamma >  1.0 ? tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0) : last : last }



# ACEScct to Linear: https://github.com/ampas/aces-dev
function ACEScct_f (clip c, bool "tv_range_in", bool "tv_range_out", int "UV") {
    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements ("_ColorRange")  > 0 ? \
          propGetInt      ("_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(c,rgb) ? 0 : 1

    tv_in   = Default(tv_range_in,    !fs)
    tv_out  = Default(tv_range_out, tv_in)
    UV      = Default(UV, rgb ? 3 : 1 )
    si      = ex_UVf(rgb, bi)

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    Y_BRK   = 0.155251141552511
    coeffA  = 1 / 10.5402377416545
    coeffB  = 0.0729055341958355

    str     = Format("x "+rangePC+" A@ {Y_BRK} > 2 A 17.52 * 9.72 - ^ A {coeffB} - {coeffA} * ? "+rangeTV)
    str     = ex_dlut( str, bi,!tv_in)
    cstr    = rgb ? str : UVRange_construct(tv_in,tv_out,bi,UV)

    isy     ?      Expr(str                       , lut=lut) : \
    UV == 1 ?      Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0)        : last }


# Linear to ACEScct: https://github.com/ampas/aces-dev
function ACEScct_r (clip c, bool "tv_range_in", bool "tv_range_out", int "UV") {
    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements ("_ColorRange")  > 0 ? \
          propGetInt      ("_ColorRange") == 0 : rgb
    lut = bi == 32 || isRunTime(c,rgb) ? 0 : 1

    tv_in   = Default(tv_range_in,     !fs)
    tv_out  = Default(tv_range_out,  tv_in)
    UV      = Default(UV, rgb ? 3 : 1 )
    si      = ex_UVf(rgb, bi)

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    X_BRK   = 0.0078125
    coeffA  = 10.5402377416545
    coeffB  = 0.0729055341958355
    lb      = 1. / log(2)
    coeffC  = 1. / 17.52

    str     = Format("x "+rangePC+" A@ {X_BRK} <= A {coeffA} * {coeffB} + A log {lb} * 9.72 + {coeffC} * ? "+rangeTV)
    str     = ex_dlut( str, bi, !tv_in)
    cstr    = rgb ? str : UVRange_construct(tv_in,tv_out,bi,UV)

    isy     ?      Expr(str                       , lut=lut) : \
    UV == 1 ?      Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? propSet("_ColorRange", tv_out?1:0)        : last }





# 1886a (Alternative 1886). A better match for CRT TRF. Uses gamma 3.0 up to offset 0.35, then gamma 2.6.
# Best match with 2.6133333 power gamma (at default BlackLevel=0)

/*The EOTF specified for 1886 is considered to be a satisfactory, but not exact, match to the
  characteristic of an actual CRT. When it is desired to match a CRT, the Lw and Lb parameters of the
  EOTF can be set to the corresponding values of the CRT that are being matched. For moderate
  black level settings, e.g. 0.1 cd/m 2 , setting the Lb of the EOTF to 0.1 will give a satisfactory match
  to the CRT. In the event the CRT is operated at a lower black level, e.g. 0.01 cd/m 2 , the EOTF will
  provide a better match with Lb set to a lower value such as 0.0 cd/m 2 . When it is necessary to more
  precisely match a flat panel display characteristic to a CRT, the alternative 1886a EOTF formulation
  may provide a solution. */

function EOTF_1886a (clip c, float "BlackLevel", bool "tv_in", bool "tv_out") {
    c
    rgb     = IsRGB()
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : rgb
    bl      = Default (BlackLevel, 0.0) # Black level in nits (cd/m2)
    tv_in   = Default (tv_in,    !fs)
    tv_out  = Default (tv_out, tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "range_max *"

    Lw = 1       # White level
    Lb = bl/100. # Black level
    a1 = 2.6     # Shoulder gamma
    a2 = 3.0     # Knee gamma
    Vc = 0.35    # Offset
    k  = Lw /pow(1  + Lb, a1)
    sl = k * pow(Vc + Lb, a1-a2) # Slope for knee gamma

    cstr = rgb ? Undefined() : UVRange_construct(tv_in,tv_out,bi,3)

    ex_lut(Format(""+rangePC+" 0 max dup {Vc} >= swap {Lb} + XP@ {a1} ^ {k} * XP {a2} ^ {sl} * ? "+rangeTV+""),cstr)
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }


function EOTFi_1886a (clip c, float "BlackLevel", bool "tv_in", bool "tv_out") {
    c
    rgb     = IsRGB()
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : rgb
    bl      = Default (BlackLevel, 0.0) # Black level in nits (cd/m2)
    tv_in   = Default (tv_in,    !fs)
    tv_out  = Default (tv_out, tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "range_max *"

    Lw   = 1                  # White level
    Lb   = bl/100.            # Black level
    a1   = 2.6  a1i = 1 / a1  # Shoulder gamma
    a2   = 3.0  a2i = 1 / a2  # Knee gamma
    Vc   = 0.35               # Offset
    k    = 1 / (Lw /pow(1  + Lb, a1))
    sl   = k * pow(Vc - Lb, a2-a1)
    beta =     pow(Vc - Lb, a1)

    cstr = rgb ? Undefined() : UVRange_construct(tv_in,tv_out,bi,3)

    ex_lut(Format(""+rangePC+" 0 max X@ dup {beta} >= swap {k} * {a1i} ^ {Lb} - X {sl} * {a2i} ^ {Lb} - ? 0 max "+rangeTV+""),cstr)
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }



# Apple piecewise gamma used for AppleRGB, ProPhotoRGB or ColorMatchRGB.
# Mainly for 1.8 gamma (best match with 1.786666 power gamma)
function EOTF_Apple (clip c, float "gamma", float "BlackLevel", bool "tv_in", bool "tv_out") {
    c
    rgb     = IsRGB()
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : rgb
    gm      = Default (gamma,      461/256.)      # Set to ~1.800781255, an hexadecimal rounded value of the ideal 1.8 power gamma
    bl      = Default (BlackLevel,   0.3473)/100. # Black level in nits (cd/m2)
    tv_in   = Default (tv_in,    !fs)
    tv_out  = Default (tv_out, tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "range_max *"

    cstr = rgb ? Undefined() : UVRange_construct(tv_in,tv_out,bi,3)

    ex_lut(Format(""+rangePC+" X@ 0.03125 < X 0.0622829 * X {gm} ^ 0.996527 * ? {bl} + "+rangeTV+""),cstr)
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }


function EOTFi_Apple (clip c, float "gamma", float "BlackLevel", bool "tv_in", bool "tv_out") {
    c
    rgb     = IsRGB()
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : rgb
    gm      = 1./Default (gamma,      461/256.)
    bl      =    Default (BlackLevel,   0.3473)/100. # Black level in nits (cd/m2)
    tv_in   =    Default (tv_in,    !fs)
    tv_out  =    Default (tv_out, tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "range_max *"

    cstr = rgb ? Undefined() : UVRange_construct(tv_in,tv_out,bi,3)

    ex_lut(Format(""+rangePC+" X@ 0.03125 < X {bl} - 0 max {gm} ^ X2@ X2 0.996527 * ? {bl} + "+rangeTV+""),cstr)
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }



# TRC for ChromeSpace100 Color Space
function EOTF_Chrome (clip c, bool "tv_in", bool "tv_out") {
    c
    rgb     = IsRGB()
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : rgb
    tv_in   = Default (tv_in,    !fs)
    tv_out  = Default (tv_out, tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "range_max *"

    cstr = rgb ? Undefined() : UVRange_construct(tv_in,tv_out,bi,3)

    ex_lut(Format(""+rangePC+" X@ 0.08458 < 0 X 0.24126 < X 1.84    ^ 0.519421 * X 0.0652292 * -
                                                          X 3.18399 ^ 11482.5  * X 3.18408 ^ 11481.5 * - 0.00454195 - ? ? "+rangeTV+""),cstr)
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }


function EOTFi_Chrome (clip c, bool "tv_in", bool "tv_out") {
    c
    rgb     = IsRGB()
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : rgb
    tv_in   = Default (tv_in,    !fs)
    tv_out  = Default (tv_out, tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "range_max *"

    cstr = rgb ? Undefined() : UVRange_construct(tv_in,tv_out,bi,3)

    ex_lut(Format(""+rangePC+" 0 max X@ 0.32413793 ^ 0.808642 * X 0.19582 * + 0.00349985 - "+rangeTV+""),cstr)
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }



# SMPTE ST 2084 (PQ to display-referred linear HDR)
# Requires planar RGB input (output is always 32-bit float)
function EOTF_2084 (clip c, int "MasterLevel", bool "tv_in", bool "tv_out") {
    c
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : true
    PL      = Default (MasterLevel, 10000) # Max Mastering Level in Nits -cd/m2- (1000 to 10000)
    tv_in   = Default (tv_in,    !fs)
    tv_out  = Default (tv_out, tv_in)
    PL      = PL / 203. # (Mastering Level) / (Reference White) -> 10000 is imaginary Display assumed peak white

    Assert(isPlanarRGB(), "EOTF_2084: Requires Planar RGB.")

    N1 = (2610./4096) * 0.25
    M1 = (2523./4096) * 128
    C1 = (3424./4096)         # or 1 + c3 - c2
    C2 = (2413./4096) * 32
    C3 = (2392./4096) * 32

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : bi==32 ? "x" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : ""

    # From BT.2124-0 Annex 2 Conversion 3
    str     = Format(""+rangePC+" 1 {M1} / ^ A@ {C1} - 0 max   {C2} {C3} A * - /    1 {N1} / ^ {PL} * "+rangeTV+"")

    Expr(ex_dlut(str, bi, !tv_in), format=isy() ? "Y32" : "RGBPS")
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }


# PQ (SMPTE ST 2084) transfer function (display-referred linear HDR to PQ)
# PQ is basically a curve-fit to the Barten model over HDR luminance...
# ...optimized for bit allocation but not human visual system
# Requires 32-bit float planar RGB input
function EOTFi_2084 (clip c, int "MasterLevel", bool "tv_in", bool "tv_out") {
    c
    bi      = BitsPerComponent()
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : true
    PL      = Default (MasterLevel, 10000) # Max Mastering Level in Nits -cd/m2- (1000 to 10000)
    tv_in   = Default (tv_in,    !fs)
    tv_out  = Default (tv_out, tv_in)
    PL      = 203. / PL # (Reference White) / (Mastering Level) -> 10000 is imaginary Display assumed peak white

    Assert(isPlanarRGB() && bi==32, "EOTFi_2084: Requires 32-bit float Planar RGB.")

    N1 = (2610./4096) * 0.25
    M1 = (2523./4096) * 128
    C1 = (3424./4096)         # or 1 + c3 - c2
    C2 = (2413./4096) * 32
    C3 = (2392./4096) * 32

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : ""

    ex_lut(Format(""+rangePC+" {PL} * {N1} ^ X@ {C2} * {C1} + X {C3} * 1 + / {M1} ^ "+rangeTV+""))
    tv_in!=tv_out ? propSet("_ColorRange", tv_out?1:0) : last }






##########################################
###                                     ##
###           LOOK FUNCTIONS            ##
###                                     ##
##########################################



###
### LMT_DCP()
###
### DCP Tone Curve - Adobe Lightroom Camera Raw's default fallback film curve when none is embedded.
###
####################################

function LMT_DCP  (clip c, bool "tv_range", int "UV", bool "show") {
    ex_contrast(c, 0.786,pivot=83, tv_range, UV, show)
    }

function LMTi_DCP (clip c, bool "tv_range", int "UV", bool "show") {
    ex_contrast(c,-0.786,pivot=83, tv_range, UV, show)
    }



###
###
### LMT_EMoR()
###
### Camera Response Function, modeled with monotonic EMoR (low-parameter empirical model of response)
### and fitted with polynomial regression. This is an OETF with camera look, therefore an OETF+OOTF combination.
### Encodes and decodes the typical camera response curve from an average of an assortment of consumer and professional devices
### and mediums like CCD or CMOS sensors, positive and negative films in color and black and white, etc, up until the mid 2000s.
###
###
### Abstract:
###    Many vision applications require precise measurement of scene radiance. The function relating scene radiance to image
###    intensity of animaging system is called the camera response. We analyze the properties that all camera responses share.This allows us
###    to find the constraints that any response function must satisfy. These constraints determine the theoretical space of all possible camera
###    responses. We have collected a diverse database of 175 real-world camera response functions (DoRF). Using this database, we show that
###    real-world responses occupy a small part of the theoretical space of all possible responses. We combine the constraints from our
###    theoretical space with the data from DoRF to create a low-parameter empirical model of response (EMoR). This response model allows
###    us to accurately interpolate the complete response function of a camera from a small number of measurements obtained using a
###    standard chart. We also show that the model can be used to accuratelyestimate the camera response from images of an arbitrary scene
###    taken using different exposures. The DoRF database and the EMoR model can be downloaded at http://www.cs.columbia.edu/CAVE.
###
### Ref:
###    "Modeling the Space of Camera Response Functions,"
###    M.D. Grossberg and S.K. Nayar,
###    IEEE Transactions on Pattern Analysis and Machine Intelligence,
###    Vol. 26, No. 10, pp. 1272-1282, Oct. 2004
###
####################################

function LMT_EMoR (clip c, bool "tv_range") {

    c
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : isRGB()
    tv_in   = Default (tv_range, !fs)

    rangePC = tv_in ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_in ? "ymax ymin - * ymin +"   : "range_max *"

    ex_lut(""+rangePC+" 0 max X@ 4.09462 ^ 0.441167 * X 26.0736 ^ 0.112893 * + X 0.445936 * + "+rangeTV+"")
    }


function LMTi_EMoR (clip c, bool "tv_range") {

    c
    fs      = propNumElements("_ColorRange")  > 0 ? \
              propGetInt     ("_ColorRange") == 0 : isRGB()
    tv_in   = Default (tv_range, !fs)

    rangePC = tv_in ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_in ? "ymax ymin - * ymin +"   : "range_max *"

    ex_lut(""+rangePC+" X@ 0.19 <= X 3.45456 ^ -8.02077  * X 1.00235   ^ 2.26165 * +
                                   X 2.78529 ^ -0.129485 * X 0.1230425 ^ 13914.67 * - X 0.12307 ^ 13915.8 * + ? "+rangeTV+"")
    }



# Display Simulation function in accordance to display white and black levels, reflectance, and view surround.
# Based on GOG: Gain-Gamma-Offset function by Rafal Mantiuk

# Examples (from Ubuntu's pfstmo docs):
#        lcd_office (100, 0.8, 1, 400, "sRGB" )
#               lcd set to "office" mode seen in bright environment
#        lcd        (200, 0.8, 1, 60, "sRGB"  )
#               typical lcd seen in dim environment (default)
#        lcd_bright (500, 0.5, 1, 10, "DCIXYZ")
#               newer LCD TV seen in dark environment
#        crt        (80,  1,   2, 60, "sRGB"  )
#               CRT monitor seen in dim environment

function Display_Sim(clip a, float "Lw", float "Lb", float "k", float "surround", string "transfer", string "EOTF") {
    a
    fs = propNumElements("_ColorRange")  > 0 ? \
         propGetInt     ("_ColorRange") == 0 : isRGB()

    Lw = Default(Lw,     100.0)    # Display peak white  given in nits, lux or cd/m2 (they are all same)
    Lb = Default(Lb,       0.3)    # Display black level given in nits, lux or cd/m2
    k  = Default(k,          1)    # Panel reflectivity given in %
    s  = Default(Surround,  50)    # Surround viewing conditions given in nits, lux or cd/m2 (50 for dim, 400 for bright office, 32000 sunny outdoors)
    tr = Default(transfer, "sRGB") # Simulated EOTF
    tro= Default(EOTF,     "1886") # Viewing display EOTF

    Lrfl = ((k*0.01)/pi)*s

    CCTF(   tr, true, !fs, false)

    ex_lut(Format("{Lw} {Lb} - x * {Lb} {Lrfl} + + 0.01 *"))

    CCTF( tro, false, false, !fs)  } # Gamma encode back for display purposes




###
### OOTF (Opto-Optical Transfer Function)
###
### Changes the rendering intent for a non-linear output for example for a Surround adaptation or Display-to-Display transfer conversion.
### Also works for fast inverse OETFi conversion when in linear space to retrieve scene-referred space.
### For piecewise transfer functions, a best-fit curve algorithm is used to find the power gamma match.
### When OOTF values are below 1.0 it is considered to be an 'inverse OOTF'.
###
### Typical values:
###    Dim to Dark:    1/0.9811
###    Neutral to Dim: 1.2
###
### Examples:
###
###    OOTF(OOTF=1/0.9811) # A dim to dark adaptation
###    or
###    OOTF(OETFi="1886",EOTF="sRGB",show=true) # for a certain OETFi to EOTF adaptation
###
###

function OOTF (clip a, float "OOTF", val "OETFi", val "EOTF", bool "show") {

    rgb   = isRGB(a)
    bi    = BitsPerComponent(a)
    fs    = propNumElements (a,"_ColorRange")  > 0 ? \
            propGetInt      (a,"_ColorRange") == 0 : rgb

    OOTFd     = Defined (OOTF)  ?          OOTF   : 0
    OETF      = Defined (OETFi) ? isString(OETFi) ? color_Fuzzy_Search(OETFi) : OETFi : ["","",""]
    EOTF      = Defined (EOTF ) ? isString(EOTF ) ? color_Fuzzy_Search(EOTF ) : EOTF  : ["","",""]
    sh        = Default (show, false)

    s_gam     = isFloat (OETF) ? [OETF,0] : OETF[2]=="1886a" ? [2.6133333,0] : OETF[2]=="Chrome" ? [2.4,0] : OETF[2]=="AppleRGB" ? [1.783333,0] : moncurve_coef(OETF[2])
    d_gam     = isFloat (EOTF) ? [EOTF,0] : EOTF[2]=="1886a" ? [2.6133333,0] : EOTF[2]=="Chrome" ? [2.4,0] : EOTF[2]=="AppleRGB" ? [1.783333,0] : moncurve_coef(EOTF[2])

    if (s_gam[1]>0) {

        # moncurve_f
        gamma = s_gam[0]      alpha  = s_gam[1]
        aplus = 1.0 + alpha   gmins  = gamma - 1.0
        beta  = (gmins / alpha) * pow( alpha * gamma / ( gmins * aplus), gamma)
        phi   =  alpha / gmins
        aplus =  1 / aplus

        # Minimize sum of squares
        m1 = [100,0]
        i = min(60,ceil(alpha*300))

        for (p=150, 900, 1) {
            po = p/300.
            b = 0
            for (n=i, 70, 1) {
                x1 = n/100.
                y1 = x1 > phi ? pow( (x1 + alpha) * aplus, gamma) : x1 * beta
                b  = pow(abs(pow(x1,po)-y1),4.8)+b  # SSQ sum of squares (loss is non-linearly vision adapted to 2.4 power gamma -2*2.4-)
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
        i = min(60,ceil(alpha*300))

        for (p=150, 900, 1) {
            po = p/300.
            b = 0
            for (n=i, 70, 1) {
                x1 = n/100.
                y1 = x1 > phi ? pow( (x1 + alpha) * aplus, gamma) : x1 * beta
                b  = pow(abs(pow(x1,po)-y1),4.8)+b  # SSQ sum of squares (loss is non-linearly vision adapted to 2.4 power gamma -2*2.4-)
                }
                m2 = b < m2[0] ? [b,po] : m2
    }
    m2 = m2[1]
    } else { m2 = d_gam[0] }

    OOTF = OOTFd==0 ? m2/m1 : OOTFd
    ex_lut(a, Format("f32 x 0 < x range_min x max {OOTF} ^ ?"),scale_inputs=fs?"intf":"int")

    if (sh) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=fs) : last
        w   = a.width()
        h   = a.height()
        sw  = nmod(w/5.)   sh = min(h,sw)
        plt = GradientLinear(last,zoom=1, precision=2, positive=true, smooth=true, tv_range=false)
        plt = ex_lut(plt, Format("x {OOTF} ^"))
        plt = HistoCurve(plt,size=2,gradient=false).BicubicResize(sw,sh,-0.5,0.25)
        plt = rgb ? plt.ConvertToPlanarRGB() : plt
        plt = Merge(PadBorders(plt.subtitle(Format(OOTFd!=0?"":"{m2}/{m1}=")+string(OOTF)),w-sw,0,0,h-sh))
        ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
    } }





##########################################
###                                     ##
###       TONEMAPPER FUNCTIONS          ##
###                                     ##
##########################################
###
###    Expanded summary of: https://github.com/tizian/tonemapper
###
###    Linear:              Linearly stretches the entire reference gamut to (a linear multiple of) the display.
###    Gamma:               Fits a logarithmic transfer between the tone curves.
###    Logarithmic:
###    Tumblin Rushmeier:   From "Tone Reproduction for Realistic Images" by by Tumblin and Rushmeier 1993
###    Schlick:             From "Quantization Techniques for Visualization of High Dynamic Range Pictures" by Schlick 1994
###    Ward:                From "A contrast-based scalefactor for luminance display" by Ward 1994
###    Ferwerda:            From "A Model of Visual Adaptation for Realistic Image Synthesis" by Ferwerda et al. 1996
###    Durand Dorsey:       From "Interactive Tone Mapping" by Durand and Dorsey 2000
###    Reinhard:            From "Photographic Tone Reproduction For Digital Images" by Reinhard et al. 2002
###    Reinhard (Extended): From "Photographic Tone Reproduction For Digital Images" by Reinhard et al. 2002
###    Möbius:              Generalization of Reinhard to a Möbius transform with linear section. Smoothly maps out-of-range values while retaining contrast and colors for in-range material as much as possible. Use this when you care about color accuracy more than detail preservation. This is somewhere in between clip and reinhard.
###    Ashikhmin:           From "A Tone Mapping Algorithm for High Contrast Images" by M. Ashikhmin 2002
###    Drago:               From "Adaptive Logarithmic Mapping For Displaying High Contrast Scenes" by Drago et al. 2003
###    Reinhard Devlin:     From "Dynamic Range Reduction Inspired by Photoreceptor Physiology" by Reinhard and Devlin 2005
###    KimKautz:            From "Consistent Tone Reproduction" by Min H. Kim and Jan Kautz 2008
###    Mantiuk:             From "Display Adaptive Tone Mapping" 2008 (only for still images)
###
###    Hejl Burgess-Dawson Filmic: By Jim Hejl and Richard Burgess-Dawson presented in the "Filmic Tonemapping for Real-time Rendering" SIGGRAPH 2010 course by Haarm-Pieter Duiker
###    Aldridge Filmic:            From the "Approximating Film with Tonemapping" blog post by Graham Aldridge
###    Hable Filmic:               By John Hable presented in the "Filmic Tonemapping for Real-time Rendering" SIGGRAPH 2010 course by Haarm-Pieter Duiker
###    Hable (Updated) Filmic:     From the "Filmic Tonemapping with Piecewise Power Curves" blog post by John Hable.
###                                Add three flavours presets Thomas Mansecal x2 and MJP.
###    Lottes Filmic:   From the "Advanced Techniques and Optimization of HDR Color Pipelines" GDC talk by Timothy Lottes
###    Day Filmic:      From the "An efficient and user-friendly tone mapping operator" document by Mike Day
###    Uchimura Filmic: From the "HDR Theory and Practice" CEDEC talk by Hajime Uchimura
###
###    Hill ACES:       ACES curve fit by Stephen Hill
###    Narkowicz ACES:  ACES curve fit by Krzysztof Narkowicz
###    Hill ACES:       ACES curve fit by Romain Guy
###    iCAM06:
###    Insomniac:
###    EETF:              From "ITU-R BT.2390-8" 2020. Perceptual tone mapping curve
###    BT.2446 Method A:  From "ITU-R BT.2446-0" 2019
###    BT.2446 Method B:  From "ITU-R BT.2446-0" 2019
###   -BT.2446 Method C:  From "ITU-R BT.2446-0" 2019
###    RRT:
###    ZCAM:
###    JzDT:
###    AgX:
###    OpenDRT:
###    Sensitometric:  From Substance Painter YEBIS2 post-processor by Silicon Studio





# BT.2446 "Method C" tonemapper. Typically used for broadcast streams in HLG, although PQ is also allowed.
# Input must be HDR PC range (or set 'tv_in') linear RGB, output is SDR gamma encoded RGB ('EOTFi' gamma encoded)
# Achromatic highlights algorithm hasn't been implemented
# * Keep in mind that peak luminance in nits (or cd/m^2) relates to float pixel values 100:1. ie. pixel value of 1.0 is 100 nits, 10.0 is 1000 nits and so on.
function TM_2446C (clip c, string "cs_in", string "cs_out", string "EOTFi", float "k1", float "k3", bool "tv_in", bool "tv_out", bool "show") {
    c
    isy    = isy()
    bi     = BitsPerComponent()
    fs     = propNumElements("_ColorRange")  > 0 ? \
             propGetInt     ("_ColorRange") == 0 : true
    props  = color_propGet()
    cs_in  = Default (cs_in, props[2])
    cs_out = Default (cs_out,   cs_in)
    EOTF   = Default (EOTFi, "linear")
    tv_in  = Default (tv_in,      !fs)
    tv_out = Default (tv_out,   tv_in)
    sh     = Default (show,     false)
    k1     = Default (k1,    1) # SDR white level to HDR reference white (diffuse white) ratio. Details on BT.2408 Annex 4
    k3     = Default (k3, 0.52) # How much bright detail you want to keep in

    cs_out = color_Fuzzy_Search (cs_out)[0]
    EOTF   = color_Fuzzy_Search (EOTF)[2]

    # De-saturation coefficient to avoid hue shifts
    a    = 0.04  # Should be between 0.01 and 0.33
    Cross= [ 1-2*a,  a,  a, \
             a,  1-2*a,  a, \
             a,  a,  1-2*a]
    c
    if (!isy) {
    XYZ = RGB_to_XYZ(cs_in, list=true)
    MatrixClip(MatrixDot(Cross, XYZ))
    XYZ_to_Yxy()
    }

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x"
    cstr    = EOTF=="linear" ? UVRange_construct(tv_in,tv_out,bi,3) : ""

    k1  = k1
    ip  = (58.5 / k1)  / 100.  # Inflection point of the tonemapper, usually just above skin tones (80% SDR which maps to 58.5 nits over 100 nits SDR reference display)
    ipr = 1.    / ip
    k3  = min(0.99,k3)
    k2  = k1 * ip *         (1 - k3)
    k4  = k1 * ip - k2 * log(1 - k3)

    # From BT.2446-0 Section 5 (Method C)
    ex_lut(Format(rangePC+" {ip} < x {k1} *  x {ipr} * {k3} - log {k2} * {k4} + ?"),cstr)

    if (!isy) {
    Yxy_to_XYZ()
    RGB = XYZ_to_RGB(cs_out, list=true)
    MatrixClip(MatrixDot(RGB, MatrixInvert(Cross)))
    }

    EOTF!="linear" ? CCTF(EOTF, false, false, tv_out)     : \
    tv_in!=tv_out  ? propSet("_ColorRange",   tv_out?1:0) : last

    if (sh) {
        w   = c.width()
        h   = c.height()
        sw  = nmod(w/5.)   sh = min(h,sw)
        plt = GradientLinear(last,zoom=1, precision=4, positive=true, smooth=true, tv_range=false)
        plt = plt.ExtractY().TM_2446C(k1=k1,k3=k3,EOTFi=EOTF)
        plt = HistoCurve(plt,size=2,gradient=false).BicubicResize(sw,sh,0.262015,0.368993)
        plt = plt.ConvertToPlanarRGB()
        plt = Merge(PadBorders(plt,w-sw,0,0,h-sh))
        ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
    } }



##########################################
###                                     ##
###           RANGE FUNCTIONS           ##
###                                     ##
##########################################


###
### SMPTE_legal()
###
### Other names:  Studio Swing, Broadcast Safe, Limited/Legal/SMPTE/Standard/Narrow/Video/Head/TV range.
### For opposite: Full Swing, Full/Data/CG/RGB/PC range.
### Other:        SMPTE+, Camera Range or Extended Range (Ocassional case in broadcast, camera recordings or in HLG for 10-bit [64-1019] narrow blacks + super-whites)
###
### Full Range also needs to abide to Video Data range but only for broadcast with SDI interfaces,
### ...that is 1-254 for 8-bits, 4-1019 for 10-bits and so on... For these cases set broadcast=true (see "EBU R 103 v3.0" page 7 for details)
###
function SMPTE_legal (clip a, bool "forward", int "Y", int "UV", bool "fulls", bool "fulld", bool "broadcast") {

    rgb = isRGB(a)
    isy = isy(a)
    yuv = !isy && !rgb
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
    UVy = isy && Y!=3 && UV==3

    if (fi  && fs!=fd || brd || UVy) {
        scl  = fs!=fd && ( 8 < bi < 32) ? string(fd ? 257/256. : 256/257.)+" *" : ""

        LO   = ex_bs(  1,  8, bi, fulls=false)
        MX   = ex_bs(255,  8, bi, fulls=true, flt=true)
        LIM  = (MX - LO * 2) / MX
        vd   = brd ? Format("{LIM} * {LO} +") : ""

        str  = fw ? "x ymax ymin - range_max / * ymin  + "+scl : \
                    "x ymin - range_max ymax ymin - / *  "+vd

        cstr = fw ? "x cmax cmin - range_max / * cmin  + "+scl : \
                    "x cmin - range_max cmax cmin - / *  "+vd

        str  = UVy  ? ex_UVexpr(cstr,  3, bi, rgb, fs, si) : ex_Yexpr(  str,  Y, bi, rgb, fs)
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


# Helper to construct chroma range conversion string
function UVRange_construct (clip a, bool "tv_in", bool "tv_out", int "bi", int "UV") {

    si   = ex_UVf(false, bi)
    scl  = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""
    cstr = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
          !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    ex_UVexpr(cstr, UV, bi, false, !tv_in, si) }

