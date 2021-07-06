###########################################################
###                                                      ##
###                                                      ##
###           ExTools v3.1     (06-07-2021)              ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###      https://forum.doom9.org/showthread.php?t=182881 ##
###                                                      ##
###########################################################
###
### Pack of masktools2 replacement functions with internal Expr().
### Generally works faster in HBD, but slower in 8-bit.
### See performance notes (benchmarks on 16-bit).
###
### *Convolutions are slower than in masktools2 (SSSE3 vs AVX2)
###
### UV setting works similarly as in masktools2:
###
### 1:   garbage
### 2:   copy first
### 3:   process
### 4:   copy second
### 128: range_half
### x:   custom value in 8-bit (bitdepth autoscaled)
###
###
### Dependencies: AviSynth+ 3.5 and over
###
###
####################################

# ex_lut family with automatic plane handling
function ex_lut(clip a, string "str", string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls,       false)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    ystr =                        ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = Defined(cstr) ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  =             ex_dlut(ystr, bi, fs)
    cstr = rgb ? str : ex_dlut(cstr, bi, fs)

    isy     ?  Expr(a, str,       scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a, str, "",   scale_inputs=si, clamp_float=cf) : \
               Expr(a, str, cstr, scale_inputs=si, clamp_float=cf) }


function ex_lutxy(clip a, clip b, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls,       false)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    ystr =                        ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = Defined(cstr) ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  =             ex_dlut(ystr, bi, fs)
    cstr = rgb ? str : ex_dlut(cstr, bi, fs)

    isy     ?  Expr(a, b, str,       scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a, b, str, "",   scale_inputs=si, clamp_float=cf) : \
               Expr(a, b, str, cstr, scale_inputs=si, clamp_float=cf) }


function ex_lutxyz(clip a, clip b, clip c, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls,       false)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    ystr =                        ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = Defined(cstr) ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  =             ex_dlut(ystr, bi, fs)
    cstr = rgb ? str : ex_dlut(cstr, bi, fs)

    isy     ?  Expr(a, b, c, str,       scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
    UV == 1 ?  Expr(a, b, c, str, "",   scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
               Expr(a, b, c, str, cstr, scale_inputs=si, clamp_float=cf, optSingleMode=true) }


# mt_makediff() is 5% slower
function ex_makediff(clip a, clip b, int "Y", int "UV", bool "dif", bool "aug", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    aug = Default(aug,   false)
    Y   = Default(Y,         3)
    UV  = Default(UV,  rgb ? 3 : aug ? 128 : 1)
    dif = Default(dif,    true)
    fs  = Default(fulls, false)

    str = aug ? "x y - abs 50 *"     : \
          dif ? "x y - range_half +" : \
                "x y -"

    str  = dif && fs ? ex_dlut(str, bi, fs) : str
    ystr = ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ? Expr(a, b, ystr                                    ) : \
    UV == 1 ? Expr(a, b, ystr, ""                                ) : \
              Expr(a, b, ystr, cstr, scale_inputs=ex_UVf(rgb, bi)) }


# mt_adddiff() is 5% slower
function ex_adddiff(clip a, clip b, int "Y", int "UV", bool "dif", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    Y   = Default(Y,         3)
    UV  = Default(UV,  rgb ? 3 : 1)
    dif = Default(dif,    true)
    fs  = Default(fulls, false)

    str = dif ? "x y + range_half -" : \
                "x y +"

    str  = dif && fs ? ex_dlut(str, bi, fs) : str
    ystr = ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ? Expr(a, b, ystr                                    ) : \
    UV == 1 ? Expr(a, b, ystr, ""                                ) : \
              Expr(a, b, ystr, cstr, scale_inputs=ex_UVf(rgb, bi)) }


function ex_makeadddiff(clip a, clip b, clip c, int "Y", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    Y   = Default(Y,         3)
    UV  = Default(UV,  rgb ? 3 : 1)
    dif = Default(dif,    true)
    fs  = Default(fulls, false)

    str = "x y - z +"

    ystr = ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ? Expr(a, b, c, ystr                                    ) : \
    UV == 1 ? Expr(a, b, c, ystr, ""                                ) : \
              Expr(a, b, c, ystr, cstr, scale_inputs=ex_UVf(rgb, bi)) }


# mt_logic(mode="and") is 6% slower
function ex_logic(clip a, clip b, string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "and")
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls, false)

    str =                                                     \
        mode == "and"   ? "x y * range_max /"               : \
        mode == "or"    ? "x y + range_min range_max clip"  : \
        mode == "xor"   ? "x y - abs"                       : \
        mode == "andn"  ? "range_max x - y * range_max /"   : \
        mode == "min"   ? "x y min"                         : \
        mode == "max"   ? "x y max"                         : \
                          Assert (false, "Unsupported mode.")

    str  = ex_dlut  (str,     bi,      fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ? Expr(a, b, str                                    ) : \
    UV == 1 ? Expr(a, b, str, ""                                ) : \
              Expr(a, b, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }


# mt_merge() is 5% slower on                  Y clips / masks
#               8% faster on luma=true  for YUV clips / masks
#               9% faster on luma=true  for YUV clips Y masks
#               9% faster on luma=false for YUV clips Y masks
function ex_merge(clip a, clip b, clip msk, bool "luma", int "Y", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    lm  = Default(luma,  false)
    Y   = Default(Y,              3)
    UV  = Default(UV, rgb || lm ? 3 : isy ? 1 : 2)
    fs  = Default(fulls, false)

    msk = isy != isy(msk) || (lm && !isy) ? mskY_to_YUV(a, msk, lm, UV, bi) : msk

    str  = Format("x x y - z 1 range_max / * * -")

     str = ex_dlut  ( str,     bi,      fs)
    ystr = ex_Yexpr ( str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr( str, UV, bi, rgb, fs)

    isy     ? Expr(a, b, msk, ystr,                                     optSingleMode=true) : \
    UV == 1 ? Expr(a, b, msk, ystr, "",                                 optSingleMode=true) : \
              Expr(a, b, msk, ystr, cstr, scale_inputs=ex_UVf(rgb, bi), optSingleMode=true) }


# mt_clamp() is 6% slower
function ex_clamp(clip a, clip hi, clip lo, int "overshoot", int "undershoot", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    os = Default(overshoot,  0)
    us = Default(undershoot, 0)
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    os = ex_bs(os, bi, fs)
    us = ex_bs(us, bi, fs)

    str = (os == 0) && (us == 0) ?        "x y min z max"              : \
                                   Format("x y {os} + min z {us} - max")

    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ? Expr(a, hi, lo, str,                                     optSingleMode=true) : \
    UV == 1 ? Expr(a, hi, lo, str, "",                                 optSingleMode=true) : \
              Expr(a, hi, lo, str, cstr, scale_inputs=ex_UVf(rgb, bi), optSingleMode=true) }


# mt_binarize() is 37% slower
# lo=-1 | hi=-1 replaces lo|hi with source "x"
function ex_binarize(clip a, int "thres", bool "invert", int "lo", int "hi", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    th = Default(thres, 128)
    lo = Default(lo,   0)
    hi = Default(hi, 255)
    in = Default(invert, false)
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls,  false)

    th = ex_bs(th, bi, fs)
    lo = lo < 0 ? "x" : string(ex_bs(lo, bi, fs))
    hi = hi < 0 ? "x" : string(ex_bs(hi, bi, fs))

    str = in ? Format("x {th} < "+hi+" "+lo+" ?") : \
               Format("x {th} > "+hi+" "+lo+" ?")

    str  = ex_dlut  (str,     bi,      fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ?  Expr(a, str                                    ) : \
    UV == 1 ?  Expr(a, str, ""                                ) : \
               Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    UV  = Default(UV, rgb ? 3 : 1)
    fs  = Default(fulls, false)

    str = "range_max x -"

    str  = ex_dlut  (str,     bi,      fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ?  Expr(a, str                                    ) : \
    UV == 1 ?  Expr(a, str, ""                                ) : \
               Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }


# mt_lutspa() is same speed (instant when spatial)
function ex_lutspa(clip a, string "mode", string "str", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "absolute")
    str  = Default(str, "x")
    UV   = Default(UV, rgb ? 3 : 1)
    fs   = Default(fulls, false)

    tem = FindStr(str, "frameno")  > 0 || FindStr(str, "time") > 0

    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    str  = ex_dlut(str, bi, fs)
    cstr = ex_dlut( ex_UVexpr(str, UV, bi, rgb, fs), bi, fs)

    isy     ?  Expr(a, str                                    ) : \
    UV == 1 ?  Expr(a, str, ""                                ) : \
               Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi))
    tem     ? last :   trim(last,0,-1).Loop(FrameCount(a)) }


# Overlay(mode="multiply")        is 56% slower (AVS+ 3.7.0)
# Overlay_MTools(mode="multiply") is 13% slower
function ex_blend(clip a, clip b, string "mode", float "opacity", int "UV", bool "tv_range", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "blend")
    op   = Default(opacity, 1.0)
    UV   = Default(UV, rgb ? 3 : 1)
    tv   = Default(tv_range, !rgb)  # TV or PC. Luma range of your source
    fs   = Default(fulls, false)

    op  = min(max(op,0.),1.)
    opr = 1 - op

    rngmax = tv ? "ymax ymin -" : "range_max"
    srcmax = tv ? "ymin -"      : ""
    pdstl  = tv ? "ymin +"      : ""

    # "softlight" uses Pegtop's improved formula
    if (op == 1.0) {

        str =                                                                                                                                          \
            mode == "blend"        ? "y"                                                                                                             : \
            mode == "screen"       ? ""+rngmax+" A@ A x "+srcmax+" - A y "+srcmax+" - * A / - "+pdstl+""                                             : \
            mode == "add"          ? "x "+srcmax+" y "+srcmax+" + "+pdstl+""                                                                         : \
            mode == "linear dodge" ? "x "+srcmax+" y "+srcmax+" + "+pdstl+""                                                                         : \
            mode == "lighten"      ? "x y max"                                                                                                       : \
            mode == "multiply"     ? "x "+srcmax+" y "+srcmax+" * "+rngmax+" / "+pdstl+""                                                            : \
            mode == "subtract"     ? "x "+srcmax+" y "+srcmax+" - "+pdstl+""                                                                         : \
            mode == "darken"       ? "x y min"                                                                                                       : \
                                   \
            mode == "softlight"    ? ""+rngmax+" A@ x "+srcmax+" B@ - B y "+srcmax+" * A / * B A A B - A y "+srcmax+" - * A / - * + A / "+pdstl+""   : \
                                   \
            mode == "difference"   ? "x "+srcmax+" y "+srcmax+"                         + abs   "+pdstl+""                                           : \
            mode == "exclusion"    ? "x "+srcmax+" A@ A y "+srcmax+" B@ + 2 A * B * + + "+rngmax+" / "+pdstl+""                                      : \
            mode == "extremity"    ? ""+rngmax+"            x "+srcmax+" - y "+srcmax+" - abs   "+pdstl+""                                           : \
            mode == "negation"     ? ""+rngmax+" "+rngmax+" x "+srcmax+" - y "+srcmax+" - abs - "+pdstl+""                                           : \
                                     Assert (false, "Unsupported Blend Mode.")
        } else {

        str = Format(                                                                                                                                                   \
            mode == "blend"        ? "x {opr} * y {op} * +"                                                                                                           : \
            mode == "screen"       ? ""+rngmax+" A@ A x "+srcmax+" - A y "+srcmax+" - * A / - {op} * x "+srcmax+" {opr} * + "+pdstl+""                                : \
            mode == "add"          ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
            mode == "linear dodge" ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
            mode == "lighten"      ? "x {opr} * x y max {op} * +"                                                                                                     : \
            mode == "multiply"     ? "x "+srcmax+" A@ y "+srcmax+" * "+rngmax+" / {op} * A {opr} * + "+pdstl+""                                                       : \
            mode == "subtract"     ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * - "+pdstl+""                                                                    : \
            mode == "darken"       ? "x {opr} * x y min {op} * +"                                                                                                     : \
                                   \
            mode == "softlight"    ? "x "+srcmax+" B@ {opr} * "+rngmax+" A@ B - B y "+srcmax+" * A / * B A A B - A y "+srcmax+" - * A / - * + A / {op} * + "+pdstl+"" : \
                                   \
            mode == "difference"   ? "x "+srcmax+" A@ {opr} * A y "+srcmax+"                +                {op} * - abs "+pdstl+""                                  : \
            mode == "exclusion"    ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" B@ + 2 A * B * +                {op} * + "+rngmax+" / "+pdstl+""                         : \
            mode == "extremity"    ? "x "+srcmax+" A@ {opr} * "+rngmax+"            A - y "+srcmax+" - abs   {op} * + "+pdstl+""                                      : \
            mode == "negation"     ? "x "+srcmax+" A@ {opr} * "+rngmax+" "+rngmax+" A - y "+srcmax+" - abs - {op} * + "+pdstl+""                                      : \
                                     Assert (false, "Unsupported Blend Mode.") )
        }


    cstr = ex_dlut( ex_UVexpr(str, UV, bi, rgb, fs), bi, fs)
    str  = ex_dlut( str, bi, fs)

    isy     ? Expr(a, b, str,                                     optSingleMode=true) : \
    UV == 1 ? Expr(a, b, str, "",                                 optSingleMode=true) : \
              Expr(a, b, str, cstr, scale_inputs=ex_UVf(rgb, bi), optSingleMode=true) }





######################
##   CONVOLUTIONS   ##
######################

# Convolutions in AviSynth+ work better with Prefetch(physical cores) than with threads. Also for RGTools and other plugins.

# Variable Box Blur
#
# Benchmark:
# 100% removegrain(19,-1)
#  97% ex_boxblur(1,UV=1)
#  87% Dither_box_filter16(2,U=1,V=1)
#  66% blur(1.58)
#  64% generalconvolution(matrix="1 1 1 1 1 1 1 1 1",chroma=false)
#  43% mt_convolution("1 1 1","1 1 1",U=1,V=1)
#   6% mt_luts(last, "avg", mt_square(1), "y",chroma="-1")
#
function ex_boxblur(clip a, int "radius", int "radiusV", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to inf
    rv = Default(radiusV, rd)           # from 0 to inf
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)
    rd = max(rd, 1)
    rv = max(rv, 1)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krnh = ""
    for (px = -krnlrd, krnlrd, 1) {
        krnh = Format(krnh + "x[{px},0] ")
        plsh = px == -krnlrd ? "" : plsh + "+ "
       }

    krnlsz = 2 * rv + 1
    krnlrv = krnlsz/2

    krnv = ""
    for (py = -krnlrv, krnlrv, 1) {
        krnv = Format(krnv + "x[0,{py}] ")
        plsv = py == -krnlrv ? "" : plsv + "+ "
       }

    # Special case to match RemoveGrain(19) -no center pixel-. Iterator includes it though.
    str  = "x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + 0.125 *"

    fbox = rd == 1 && rv == 1
    strv = fbox ? str : krnv + plsv + string(1. / (krnlrv*2+1)) + " *"
    strh =              krnh + plsh + string(1. / (krnlrd*2+1)) + " *"

    rv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 || fbox  ? last                                                           : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }


# Variable Gaussian Blur
#
# Benchmark:
# 100% removegrain(12,-1)
#  96% ex_blur(1,UV=1)
#  94% BinomialBlur(0.75,U=1,V=1) only in 8-bit
#  84% ablur(1, 1) against ex_blur(2)
#  70% blur(1.00)
#  66% generalconvolution(matrix="0 1 0 1 2 1 0 1 0",6,chroma=false) doesn't match output tho
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#  21% GBlur(rad=1,sd=1.0,u=false,v=false)
#  15% FastBlur(0.75,gamma=false)
#  10% GaussianBlur(0.75,U=1,V=1) only in 8-bit
#
# ex_blur(4) same to FRC_GaussianBlur42(1.3) and similar to ex_boxblur(2)
# ex_blur(3) same to ex_boxblur(1).ex_boxblur(1), and Dither_box_filter16(1,U=1,V=1).Dither_box_filter16(1,U=1,V=1), Dither_ about same speed
function ex_blur(clip a, float "radius", float "radiusV", string "gamma", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    sm = Default(radius,   1)           # from 0 to 6 (integers except for 0.5)
    sv = Default(radiusv, sm)           # from 0 to 6 (integers except for 0.5)
    UV = Default(UV, rgb ? 3 : 1)
    gm = Default(gamma, "none")         # Set matrix for gamma encoded clips
    fs = Default(fulls, false)
    sm = max(min(sm * 0.30,2.0),0)
    sv = max(min(sv * 0.30,2.0),0)

    fkern  = sm==0.30 && sv==0.30
    fkern2 = sm==0.15 && sv==0.15
    krnlsz = 2*ceil(3*sv)
    n_f    = factorial(krnlsz)

    krnv = ""
    for (i=0, krnlsz, 1) {

        k_f = factorial(i)*factorial(krnlsz-i)
        wg  = (n_f/k_f)/pow(2,krnlsz)
        py  = i - krnlsz/2
        krnv = Format(krnv + "x[0,{py}] {wg} * ")
        plsv = i == 0 ? "" : plsv + "+ "
       }

    krnlszh = 2*ceil(3*sm)
    n_f     = factorial(krnlszh)

    krnh = ""
    for (i=0, krnlszh, 1) {

        k_f = factorial(i)*factorial(krnlszh-i)
        wg  = (n_f/k_f)/pow(2,krnlszh)
        px  = i - krnlszh/2
        krnh = Format(krnh + "x[{px},0] {wg} * ")
        plsh = i == 0 ? "" : plsh + "+ "
       }

    strv = fkern    ?   "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 0.1 *" : \
           fkern2   ?   "x[0,1] x[-1,0] x[0,0] 3 * x[1,0] x[0,-1] + + + + 0.142857143 *"                                 : \
           sv==0.3  ?   "x[0,1]  x[0,0] 2 * x[0,-1] + + 0.25 *" : \
           sv==0.15 ?   "x[0,1]  x[0,0] 3 * x[0,-1] + + 0.20 *" : \
           sv==0.0  ?   "x"                                     : \
                       krnv + plsv
    strh = sm==0.3  ?   "x[-1,0] x[0,0] 2 * x[1,0]  + + 0.25 *" : \
           sm==0.15 ?   "x[-1,0] x[0,0] 3 * x[1,0]  + + 0.20 *" : \
           sm==0.0  ?   "x"                                     : \
                       krnh + plsh


    p_4 = is444(a)    p_1 = isYV411(a)
    p_2 = is422(a)    p_0 = is420(a)

    cstrv = ""
    cstrh = ""
    if (!p_4 && (sm>0.6 || sv>0.6)) {

        krnlsz = krnlsz/(!p_0 ? 1 : 2)
        n_f    = factorial(krnlsz)

        for (i=0, krnlsz, 1) {

            k_f = factorial(i)*factorial(krnlsz-i)
            wg  = (n_f/k_f)/pow(2,krnlsz)
            py  = i - krnlsz/2
            cstrv = Format(cstrv + "x[0,{py}] {wg} * ")
            plsv = i == 0 ? "" : plsv + "+ "
           }

        krnlszh = krnlszh/(p_1 ? 4 : 2)
        n_f     = factorial(krnlszh)

        for (i=0, krnlszh, 1) {

            k_f = factorial(i)*factorial(krnlszh-i)
            wg  = (n_f/k_f)/pow(2,krnlszh)
            px  = i - krnlszh/2
            cstrh = Format(cstrh + "x[{px},0] {wg} * ")
            plsh = i == 0 ? "" : plsh + "+ "
           }
       }

        cstrv = !p_0                        ? strv                                                                                                : \
                sm==0.6 && sv == 0.6        ? "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 *  x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 0.1 *"   : \
                fkern                       ? "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 12 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 0.05 *"  : \
                fkern2                      ? "x"                                                                                                 : \
                sv==0.6                     ? "x[0,1] x[0,0] 2 * x[0,-1] + + 0.25 *"                                                              : \
                sv==0.3                     ? "x[0,1] x[0,0] 3 * x[0,-1] + + 0.20 *"                                                              : \
                sv==0.0                     ? "x"                                                                                                 : \
                                              cstrv + plsv

        cstrh = p_4                         ? strh                                                                                                : \
                sm==0.0                     ? "x"                                                                                                 : \
                sm==0.6 && !p_1             ? "x[-1,0] x[0,0] 2 * x[1,0] + + 0.25 *"                                                              : \
                sm==0.3 || (sm==0.3 && p_1) ? "x[-1,0] x[0,0] 3 * x[1,0] + + 0.20 *"                                                              : \
                                              cstrh + plsh

    if (gm != "none") {
        matrix = Matrix_fuzzy_search (gm)
        s_gam  = moncurve_coef(matrix)
        a      = moncurve_f(a, s_gam[0], s_gam[1], !rgb, false, UV, fs)
    }

    sv == 0 ?      a                                                                   : \
    isy     ? Expr(a,    strv                                                        ) : \
    UV == 1 ? Expr(a,    strv, ""                                                    ) : \
              Expr(a,    strv, ex_UVexpr(cstrv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 || fkern || fkern2 ? last                                                  : \
    isy     ? Expr(last, strh                                                        ) : \
    UV == 1 ? Expr(last, strh, ""                                                    ) : \
              Expr(last, strh, ex_UVexpr(cstrh, UV, bi, rgb, fs), scale_inputs="none")

    gm != "none" ? moncurve_r(last, s_gam[0], s_gam[1], false, !rgb, UV, fs) : last  }


function factorial(int n) {
    n<2?1:factorial(n-1)*n }



# mt_expand() is 6% faster (6% slower when radius = 2)
# modes: square, circle, both, vertical, horizontal
# "circle" + radius=2 is like calling mode="both" twice but faster
function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, rgb ? 3 : 1)
    fs   = Default(fulls, false)

    th = ex_bs(thr, bi, fs)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    strh = ""
    krn  = ""
    if (mode == "both" || mode == "circle") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                rad = 2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py)))
                skip = mode == "both"   ? px != 0 && py != 0                 : \
                                          px != 0 && abs(px) > krnlrd*cos(rad)
                krn = skip ? krn : Format(krn + "x[{px},{py}] max ")
       }      }
       } else {

            for (py  = -krnlrd, krnlrd, 1) {
                krn  = Format(krn  + "x[0,{py}] max ")
            }
            krnh = ""
            for (px  = -krnlrd, krnlrd, 1) {
                krnh = Format(krnh + "x[{px},0] max ")
            }
    strh = "x[0,0] " + ReplaceStr(krnh, "x[0,0] max ", "") + (thr != 255 ? Format("x[0,0] {th} + min") : "")
    }

    fbox = mode == "square" && rd == 1
    str  = "x[0,0] " + ReplaceStr(krn,  "x[0,0] max ", "")
    str  = !fbox ? str : "x[-1,1] x[0,1] max x[1,1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,-1] max x[0,-1] max x[1,-1] max "
    str  = str + (thr != 255 ? Format("x[0,0] {th} + min") : "")


    isy     ? Expr(a, str                                                        ) : \
    UV == 1 ? Expr(a, str, ""                                                    ) : \
              Expr(a, str,  ex_UVexpr(str,  UV, bi, rgb, fs), scale_inputs="none")

    v =       mode == "horizontal" ? a : last

    isy     ? Expr(v, strh                                                       ) : \
    UV == 1 ? Expr(v, strh, ""                                                   ) : \
              Expr(v, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none")

    !fbox && (mode == "horizontal" || mode == "square") ? last : v               }


# mt_inpand() is 5% faster (4% slower when radius = 2)
# modes: square, circle, both, vertical, horizontal
function ex_inpand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, rgb ? 3 : 1)
    fs   = Default(fulls, false)

    th  = ex_bs(thr, bi, fs)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    strh = ""
    krn  = ""
    if (mode == "both" || mode == "circle") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                rad = 2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py)))
                skip = mode == "both"   ? px != 0 && py != 0                 : \
                                          px != 0 && abs(px) > krnlrd*cos(rad)
                krn = skip ? krn : Format(krn + "x[{px},{py}] min ")
       }      }
       } else {

            for (py  = -krnlrd, krnlrd, 1) {
                krn  = Format(krn  + "x[0,{py}] min ")
            }
            krnh = ""
            for (px = -krnlrd, krnlrd, 1) {
                krnh = Format(krnh + "x[{px},0] min ")
            }
    strh = "x[0,0] " + ReplaceStr(krnh, "x[0,0] min ", "") + (thr != 255 ? Format("x[0,0] {th} - max") : "")
    }

    fbox = mode == "square" && rd == 1
    str  = "x[0,0] " + ReplaceStr(krn,  "x[0,0] min ", "")
    str  = !fbox ? str : "x[-1,1] x[0,1] min x[1,1] min x[-1,0] min x[0,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min "
    str  = str + (thr != 255 ? Format("x[0,0] {th} - max") : "")

    isy     ? Expr(a, str                                                        ) : \
    UV == 1 ? Expr(a, str, ""                                                    ) : \
              Expr(a, str,  ex_UVexpr(str,  UV, bi, rgb, fs), scale_inputs="none")

    v =       mode == "horizontal" ? a : last

    isy     ? Expr(v, strh                                                       ) : \
    UV == 1 ? Expr(v, strh, ""                                                   ) : \
              Expr(v, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none")

    !fbox && (mode == "horizontal" || mode == "square") ? last : v               }


# mt_deflate() is 14% faster (lower gap with bigger radius)
function ex_deflate(clip a, int "radius", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd = Default(radius, 1)
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    pls = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = Format(krn + "x[{px},{py}] ")
            pls = py < -krnlrd+2 && px == -krnlrd ? pls + "" : pls + "+ "
           }
       }

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(1. / (krnlsz*krnlsz-1)) + " * x[0,0] min"

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# mt_inflate() is 14% faster (lower gap with bigger radius)
function ex_inflate(clip a, int "radius", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd = Default(radius, 1)
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    pls = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = Format(krn + "x[{px},{py}] ")
            pls = py < -krnlrd+2 && px == -krnlrd ? pls + "" : pls + "+ "
           }
       }

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(1. / (krnlsz*krnlsz-1)) + " * x[0,0] max"

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# mt_edge() is 14% faster (varies with kernel)
# "canny" is a bit too complex so that's better used in a plugin
function ex_edge(clip a, string "mode", int "lo", int "hi", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "sobel")
    UV   = Default(UV, rgb ? 3 : 1)
    fs   = Default(fulls, false)

    th   = mode=="prewitt"   ?  [10, 100] : \
           mode=="hprewitt"  ?  [10, 100] : \
           mode=="sobel"     ?  [ 5,  25] : \
           mode=="scharr"    ?  [30,  70] : \
           mode=="frei-chen" ?  [20,  50] : \
           mode=="roberts"   ?  [ 5,  15] : \
           mode=="kayyali"   ?  [20, 100] : \
           mode=="robinson"  ?  [20,  50] : \
           mode=="FDoG"      ?  [20, 150] : \
           mode=="DoG"       ?  [10, 100] : \
           mode=="DoB"       ?  [10, 155] : \
           mode=="LoG"       ?  [70, 125] : \
           mode=="Std"       ?  [50, 255] : \
           mode=="laplace"   ?  [ 5,   6] : \
           mode=="cartoon"   ?  [10,  20] : \
           mode=="TEdge"     ?  [90, 255] : \
           mode=="min/max"   ?  [10,  25] : \
           mode=="max"       ?  [ 5,  45] : \
           mode=="kirsch"    ?  [20, 100] : \
                                [10,  50]

    lo = ex_bs(Defined(lo) ? lo : th[0], bi, fs)
    hi = ex_bs(Defined(hi) ? hi : th[1], bi, fs)

    th  = (lo == 0) && (hi == ex_bs(255, bi, fs)) ? "" : ex_dlut(Format("T@ {lo} - range_max {hi} {lo} - / * "), bi, fs)
    str =                                                                                                                                                                                                \
          mode=="prewitt"   ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ "                                                                                   \
                             +"A B C + + D - E - F - A G D + + C - H - F - max F E D + + C - B - A - F H C + + D - G - A - max max "                                                                     \
                             +"G A B + + F - H - E - D G E + + C - H - B - max E H F + + B - A - G - B H C + + E - G - D - max max max "+th+""                                                         : \
                                                                                                                                                                                                         \
          mode=="hprewitt"  ? "x[1,1] A^ x[1,0] 2 * B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] 2 * E^ x[-1,-1] F^ x[0,1] 2 * G^ x[0,-1] 2 * H^ "                                                                   \
                             +"A B C + + D - E - F - A G D + + C - H - F - max F E D + + C - B - A - F H C + + D - G - A - max max "+th+""                                                             : \
                                                                                                                                                                                                         \
          mode=="sobel"     ? "x[1,0] A^ x[0,1] B^ x[-1,0] C^ x[0,-1] D^ A B + C - D - C D + A - B - max 0.5 * "+th+""                                                                                 : \
                                                                                                                                                                                                         \
          mode=="scharr"    ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^  x[1,-1] H^ "                                                                                  \
                             +"C A - D 3.333333333 * - E 3.333333333 * + F - H + U@ U * F G 3.333333333 * H + + C - B 3.333333333 * - A - V@ V * + sqrt "+th+""                                        : \
                                                                                                                                                                                                         \
          mode=="frei-chen" ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                                                   \
                             +"C A - D 1.428571428 * - E 1.428571428 * + F - H + U@ U * F G 1.428571428 * H + + C - B 1.428571428 * - A - V@ V * + sqrt "+th+""                                        : \
                                                                                                                                                                                                         \
          mode=="roberts"   ? "x[0,0] A^ x[1,0] 0.5 * B^ x[0,1] 0.5 * C^ A B - C - B A - C + max "+th+""                                                                                               : \
                                                                                                                                                                                                         \
          mode=="kayyali"   ? "x[1,1] 3 * A^ x[-1,1] 3 * B^ x[-1,-1] 3 * C^ x[1,-1] 3 * D^ B A - C + D - A B - C - D + max "+th+""                                                                     : \
                                                                                                                                                                                                         \
          mode=="robinson"  ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                                                   \
                             +"C A - D 2 * - E 2 * + F - H +     B C 2 * + D - E + F 2 * - G - max     A B 2 * + C + F - G 2 * - H - max     A 2 * B + D + E - G - H 2 * - max "                         \
                             +"A C - D 2 * + E 2 * - F + H - 0 B - C 2 * - D + E - F 2 * + G + max 0 A - B 2 * - C - F + G 2 * + H + max 0 A 2 * - B - D - E + G + H 2 * + max max "+th+""             : \
                                                                                                                                                                                                         \
          mode=="FDoG"      ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] 2 * G^ x[0,1] H^ x[1,1] 2 * I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                                   \
                             +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] 2 * Q^ x[0,-1] R^ x[1,-1] 2 * S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] W^ x[1,-2] X^ x[2,-2] Y^ "                           \
                             +"A B + D - E - F 2 * + G + I - J 2 * - K 3 * + L 3 * + N 3 * - O 3 * - P 2 * Q U V + + + + S - T 2 * - X - Y - 0.5 * M@ M * "                                              \
                             +"U V 2 * W 3 * X 2 * Y P Q R 3 * S T + + + + + + + + + F - G - H 3 * - I - J - A - B 2 * - C 3 * - D 2 * - E - 0.5 * N@ N * + sqrt "+th+""                               : \
                                                                                                                                                                                                         \
          mode=="DoG"       ? "x[0,0] A^ x[0,1] B^ x[-1,0] C^ x[1,0] D^ x[0,-1] E^ x[0,2] F^ x[0,-2] G^ x[2,0] H^ x[-2,0] I^ x[-1,1] J^ x[-1,-1] K^ x[1,1] L^ x[1,-1] M^ "                               \
                             +"F G H I B 2 * E 2 * D 2 * C 2 * J K L M A 4 * + + + + + + + + + + + + 0.05 * A 2 * B C D E + + + + 0.166666666 * - 25 * "+th+""                                         : \
                                                                                                                                                                                                         \
          mode=="DoB"       ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ x[0,0] M^ "                                 \
                             +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] Q^ x[0,-1] R^ x[1,-1] S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] W^ x[1,-2] X^ x[2,-2] Y^ "                                   \
                             +"A B C D E F G H I J K L M N O P Q R S T U V W X Y + + + + + + + + + + + + + + + + + + + + + + + + 0.04 * G H I L M N Q R S + + + + + + + + 0.111111111 * - 25 * "+th+"" : \
                                                                                                                                                                                                         \
          mode=="LoG"       ? "x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] + + + + + + + + + + + x[0,0] 16 * - "+th+""                 : \
                                                                                                                                                                                                         \
          mode=="laplace"   ? "x[0,0] 8 * A^ x[-1,1] B^ x[0,1] C^ x[1,1] D^ x[-1,0] E^ x[1,0] F^ x[-1,-1] G^ x[0,-1] H^ x[1,-1] I^ "                                                                     \
                             +"A B - C - D - E - F - G - H - I - B C D E F G H I + + + + + + + A - max 0.125 * "+th+""                                                                                 : \
                                                                                                                                                                                                         \
          mode=="cartoon"   ? "x[1,-1] x[0,-1] 2 * - x[0,0] + "+th+""                                                                                                                                  : \
                                                                                                                                                                                                         \
          mode=="TEdge"     ? "x[-2,0] x[-1,0] 6.166666666 * - x[1,0] 6.166666666 * + x[2,0] - 2 * A@ A * x[0,-2] x[0,-1] 6.166666666 * - x[0,1] 6.166666666 * + x[0,2] - 2 * B@ B * + sqrt "+th+""    : \
                                                                                                                                                                                                         \
          mode=="min/max"   ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ x[0,0] O^ "                                                                         \
                             +"A B max C max G max O max H max D max E max F max A B min C min G min O min H min D min E min F min - "+th+""                                                           : \
                                                                                                                                                                                                         \
          mode=="max"       ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ x[0,0] O^ "                                                                         \
                             +"O A - abs O B - abs max O C - abs max O D - abs max O E - abs max O F - abs max O G - abs max O H - abs max "+th+""                                                     : \
                                                                                                                                                                                                         \
          mode=="kirsch"    ? "x[-1,1] A@ 1.666666 * R^ x[0,1] B@ 1.666666 * S^ x[1,1] C@ 1.666666 * T^ x[-1,0] D@ 1.666666 * U^ "                                                                       \
                             +"x[1,0] E@ 1.666666 * V^ x[-1,-1] F@ 1.666666 * X^ x[0,-1] G@ 1.666666 * Y^ x[1,-1] H@ 1.666666 * Z^ "                                                                     \
                             +"R S T + + D - E - F - G - H -     R S + C - U + E - F - G - H - max R B - C - U + E - X + G - H - max U A - B - C - E - X + Y + H - max "                                 \
                             +"X Y Z + + A - B - C - D - E - max V Y Z + + A - B - C - D - F - max T V Z + + A - B - D - F - G - max S T V + + A - D - F - G - H - max "+th+""                         : \
                                                                                                                                                                                                         \
          mode=="Std"       ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ A B C D E F G H + + + + + + + 0.125 * J^ "                                          \
                             +"A J - dup * B J - dup * C J - dup * D J - dup * E J - dup * F J - dup * G J - dup * H J - dup * + + + + + + + 0.125 * sqrt 8 * "+th+""                                  : \
                                                                                                                                                                                                         \
                             ex_dlut(mode, bi, fs)

    isy     ? Expr(a, str                                                               ) : \
    UV == 1 ? Expr(a, str, ""                                                           ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }



# removegrain(1,-1) is 21% faster
function ex_undot(clip a, int "radius", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd = Default(radius, 1)            # beware; not real radius -as bigger kernel-, but further apart
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    str = Format("x[-{rd},{rd}] A^ x[0,{rd}] B^ x[{rd},{rd}] C^ x[-{rd},0] D^ x[{rd},0] F^ x[-{rd},-{rd}] G^ x[0,-{rd}] H^ x[{rd},-{rd}] I^ " \
                +"x[0,0] A B min C D min min F G min H I min min min A B max C D max max F G max H I max max max clip")

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# This is repair(mode=1)
function ex_repair(clip a, clip b, int "radius", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd = Default(radius, 1)            # beware; not real radius -as bigger kernel-, but further apart
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    str = Format("y[-{rd},{rd}] A^ y[0,{rd}] B^ y[{rd},{rd}] C^ y[-{rd},0] D^ y[{rd},0] F^ y[-{rd},-{rd}] G^ y[0,-{rd}] H^ y[{rd},-{rd}] I^ " \
                +"x[0,0] A B min C D min min F G min H I min min min A B max C D max max F G max H I max max max clip")

    isy     ? Expr(a, b, str                                                      ) : \
    UV == 1 ? Expr(a, b, str, ""                                                  ) : \
              Expr(a, b, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }



######### HELPER FUNCTIONS #########

function ex_UVexpr(string "str", int "UV", int "bits", bool "rgb", bool "fulls") {

    str = Default(str, "")
    UV  = Default(UV, 1)
    bi  = Default(bits, 8)
    rgb = Default(rgb,   false)
    fs  = Default(fulls, false)

    bd  = bi == 32 && !rgb ? 0.5 : 0

    str = rgb ? str : ReplaceStr(str, "ymax", "cmax")

    # "" is the same as "copy first"
    str = UV == 1   ? ""          : \
          UV == 2   ? ""          : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 128 ? "range_half": \
          UV == 0   ? "0"         : \
          UV == 255 ? "range_max" : \
          string(ex_bs(UV, bi, fs)+bd)

    str = UV == 128 || UV == 255 ? ex_dlut(str, bi, fs) : str

    return str }


function ex_Yexpr(string "str", int "Y", int "bits", bool "rgb", bool "fulls") {

    str = Default(str, "")
    Y   = Default(Y, 3)
    bi  = Default(bits, 8)
    rgb = Default(rgb,   false)
    fs  = Default(fulls, false)

    str = Y == 1   ? ""          : \
          Y == 2   ? ""          : \
          Y == 3   ? str         : \
          Y == 4   ? "y"         : \
          Y == 128 ? "range_half": \
          Y == 0   ? "0"         : \
          Y == 255 ? "range_max" : \
          string(ex_bs(Y, bi, fs))

    str = Y == 128 || Y == 255 ? ex_dlut(str, bi, fs) : str

    return str }


function ex_UVf(bool rgb, int bits) {

    bits == 32 && !rgb ? "floatUV" : "none" }


# Scales 8-bit values to bitdepth counterpart
function ex_bs(float var, int "bits", bool "fulls") {

    bi  = Default(bits, 16)
    fs  = Default(fulls, false)
    var = min(max(var,0.),256.)

    v = var*pow(2, bi-8)
    bi == 32 ? var/255. : bi != 8 ? fs ? v+v/256. : v : var }



# HBD constants look up table
function ex_dlut(string "str", int "bits", bool "fulls") {

    str  = Default(str, "")
    bits = Default(bits, 8)
    fs   = Default(fulls, false)

    bitd =
\     (bits ==  8         ) ? 0
\   : (bits == 10         ) ? 1
\   : (bits == 12         ) ? 2
\   : (bits == 14         ) ? 3
\   : (bits == 16         ) ? 4
\   : (bits == 24         ) ? 5
\   : (bits == 32         ) ? 6
\   :  Assert (false, "Unsupported bit depth.")


    #                           8-bit UINT      10-bit UINT          12-bit UINT          14-bit UINT            16-bit UINT         24-bit UINT               32-bit Ufloat
    range_min  = Select (bitd,  [  0.,  0.],    [   0.,   0.   ],    [   0.,   0.   ],    [    0.,    0.   ],    [    0.,    0.],    [       0.,       0.],    [       0.,       0.])
    ymin       = Select (bitd,  [ 16., 16.],    [  64.,  64.   ],    [ 256., 257.   ],    [ 1024., 1028.   ],    [ 4096., 4112.],    [ 1048576., 1052672.],    [  16/255.,  16/255.])
    cmin       = Select (bitd,  [ 16., 16.],    [  64.,  64.   ],    [ 256., 257.   ],    [ 1024., 1028.   ],    [ 4096., 4112.],    [ 1048576., 1052672.],    [  16/255.,  16/255.])
    range_half = Select (bitd,  [128.,128.],    [ 512., 514.   ],    [2048.,2056.   ],    [ 8192., 8224.   ],    [32768.,32896.],    [ 8388608., 8421376.],    [ 128/255., 128/255.])
    yrange     = Select (bitd,  [219.,219.],    [ 876., 879.   ],    [3504.,3517.688],    [14016.,14070.750],    [56064.,56283.],    [14352384.,14408448.],    [ 219/255., 219/255.])
    crange     = Select (bitd,  [224.,224.],    [ 896., 899.500],    [3584.,3598.   ],    [14336.,14392.   ],    [57344.,57568.],    [14680064.,14737408.],    [ 224/255., 224/255.])
    ymax       = Select (bitd,  [235.,235.],    [ 940., 943.672],    [3760.,3774.688],    [15040.,15098.750],    [60160.,60395.],    [15400960.,15461120.],    [ 235/255., 235/255.])
    cmax       = Select (bitd,  [240.,240.],    [ 960., 963.750],    [3840.,3855.   ],    [15360.,15420.   ],    [61440.,61680.],    [15728640.,15790080.],    [ 240/255., 240/255.])
    range_max  = Select (bitd,  [255.,255.],    [1020.,1023.984],    [4080.,4095.938],    [16320.,16383.750],    [65280.,65535.],    [16711680.,16776960.],    [       1.,       1.])
    range_size = Select (bitd,  [256.,256.],    [1024.,1024.   ],    [4096.,4096.   ],    [16384.,16384.   ],    [65536.,65536.],    [16777216.,16777216.],    [       1.,       1.])

    fs  = fs ? 1 : 0
    str = ReplaceStr(str, "ymax ymin - range_max /", string(yrange[fs]/range_max[fs]))
    str = ReplaceStr(str, "cmax cmin - range_max /", string(crange[fs]/range_max[fs]))
    str = ReplaceStr(str, "cmax ymin - range_max /", string(crange[fs]/range_max[fs]))
    str = ReplaceStr(str, "range_max ymax ymin - /", string(range_max[fs]/yrange[fs]))
    str = ReplaceStr(str, "range_max cmax cmin - /", string(range_max[fs]/crange[fs]))
    str = ReplaceStr(str, "range_max cmax ymin - /", string(range_max[fs]/crange[fs]))
    str = ReplaceStr(str, "ymax ymin -",             string(yrange[fs]))
    str = ReplaceStr(str, "cmax ymin -",             string(crange[fs]))
    str = ReplaceStr(str, "cmax cmin -",             string(crange[fs]))

    if (bits != 8 && bits != 32) {
        str = ReplaceStr(str, "ymax",                string(ymax[fs]))
        str = ReplaceStr(str, "cmax",                string(cmax[fs]))
        str = ReplaceStr(str, "ymin",                string(ymin[fs]))
        str = ReplaceStr(str, "cmin",                string(cmin[fs]))
        str = ReplaceStr(str, "range_min",           string(range_min[fs]))
        str = ReplaceStr(str, "range_half",          string(range_half[fs]))
        str = ReplaceStr(str, "range_max",           string(range_max[fs]))
        str = ReplaceStr(str, "range_size",          string(range_size[fs]))
    }

    return str }


function mskY_to_YUV(clip a, clip msk, bool "luma", int "UV", int "bits") {

    isy = isy(msk)

    if (!isRGB(a) && !(!luma && !isy)) {

        w = width (a)
        h = height(a)
        p_float = bits == 32
        bstr    = p_float ? "S" : string(bits)

        mskY    = isy ? msk : msk.ExtractY()
        w       = isYV411(a)             ? round(w/4.0) : round(w/2.0)
        h       = isYV411(a) || is422(a) ?            h : round(h/2.0)
        mskC    = is444  (a)             ?                                        mskY : mskY.ConvertBits(8,dither=-1).BilinearResize(w+w%2,       h+h%2)
        mskC    = luma ? p_float ? Expr(mskC, "x range_half -").ConvertBits(32) : mskC.ConvertBits(bits) : BlankClip(a,length=1,width=w+w%2,height=h+h%2,pixel_type="Y"+bstr,color_yuv=$000000)
        lmmsk   = CombinePlanes(mskY, mskC, mskC, planes="YUV", pixel_type=PixelType(a))
    } else {
        lmmsk   = msk
    }
    return lmmsk }