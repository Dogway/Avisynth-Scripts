###########################################################
###                                                      ##
###                                                      ##
###           ExTools v2.2     (23-06-2021)              ##
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
###               Utils-r41 (for ex_merge)
###
###
####################################

# ex_lut family with automatic plane handling
function ex_lut(clip a, string "str", string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    str  = Default(str, "")
    cstr = Default(cstr, str)
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls, false)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(bi)

    str  =                        ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = Defined(cstr) ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  = ex_dlut( str, bi, fs)
    cstr = ex_dlut(cstr, bi, fs)

    UV == 1 ? isy ? Expr(a, str,       scale_inputs=si, clamp_float=cf) : \
                    Expr(a, str, "",   scale_inputs=si, clamp_float=cf) : \
                    Expr(a, str, cstr, scale_inputs=si, clamp_float=cf) }


function ex_lutxy(clip a, clip b, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    str  = Default(str, "")
    cstr = Default(cstr, str)
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls, false)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(bi)

    str  =                        ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = Defined(cstr) ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  = ex_dlut( str, bi, fs)
    cstr = ex_dlut(cstr, bi, fs)

    UV == 1 ? isy ? Expr(a, b, str,       scale_inputs=si, clamp_float=cf) : \
                    Expr(a, b, str, "",   scale_inputs=si, clamp_float=cf) : \
                    Expr(a, b, str, cstr, scale_inputs=si, clamp_float=cf) }


function ex_lutxyz(clip a, clip b, clip c, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    cstr = Default(cstr, str)
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls, false)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(bi)

    str  =                        ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = Defined(cstr) ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  = ex_dlut( str, bi, fs)
    cstr = ex_dlut(cstr, bi, fs)

    UV == 1 ? isy ? Expr(a, b, c, str,       scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
                    Expr(a, b, c, str, "",   scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
                    Expr(a, b, c, str, cstr, scale_inputs=si, clamp_float=cf, optSingleMode=true) }


# mt_makediff() is 5% slower
function ex_makediff(clip a, clip b, int "UV", bool "dif", bool "aug", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    dif = Default(dif, true)
    aug = Default(aug, false)
    UV  = Default(UV,  rgb ? 3 : aug ? 128 : 1)
    fs  = Default(fulls, false)

    str = aug ? "x y - abs 50 *"     : \
          dif ? "x y - range_half +" : \
                "x y -"

    str  = dif && fs ? ex_dlut(str, bi, fs) : str
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    UV == 1 ? isy ? Expr(a, b, str) : Expr(a, b, str, "")          : \
                    Expr(a, b, str, cstr, scale_inputs=ex_UVf(bi)) }


# mt_adddiff() is 5% slower
function ex_adddiff(clip a, clip b, int "UV", bool "dif", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    dif = Default(dif, true)
    UV  = Default(UV,  rgb ? 3 : 1)
    fs  = Default(fulls, false)

    str = dif ? "x y + range_half -" : \
                "x y +"

    str  = dif && fs ? ex_dlut(str, bi, fs) : str
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    UV == 1 ? isy ? Expr(a, b, str) : Expr(a, b, str, "")          : \
                    Expr(a, b, str, cstr, scale_inputs=ex_UVf(bi)) }


# mt_logic(mode="and") is 6% slower ("min", "max" modes are faster)
function ex_logic(clip a, clip b, string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "and")
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls, false)

    str = Format(                                            \
        mode == "and"   ? "x y * range_max /"              : \
        mode == "or"    ? "x y + range_min range_max clip" : \
        mode == "xor"   ? "x y - abs"                      : \
        mode == "andn"  ? "range_max x - y * range_max /"  : \
        mode == "min"   ? "x y min"                        : \
        mode == "max"   ? "x y max"                        : \
                          Assert (false, "Unsupported mode.") )

    str  = ex_dlut(str, bi, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    UV == 1 ? isy ? Expr(a, b, str) : Expr(a, b, str, "")          : \
                    Expr(a, b, str, cstr, scale_inputs=ex_UVf(bi)) }


# mt_merge() is 10% slower
function ex_merge(clip a, clip b, clip msk, bool "luma", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    lm  = Default(luma, false)
    UV  = Default(UV,  rgb || lm ? 3 : isy ? 1 : 2)
    fs  = Default(fulls, false)

    msk = UV != 1 ? mskY_to_YUV(a, msk, lm, UV, bi) : msk
    str = "x range_max z - * y z * + range_max /"

    str  = ex_dlut(str, bi, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    UV == 1 ? isy ? Expr(a, b, msk, str,                                optSingleMode=true) : \
                    Expr(a, b, msk, str, "",                            optSingleMode=true) : \
                    Expr(a, b, msk, str, cstr, scale_inputs=ex_UVf(bi), optSingleMode=true) }


# mt_clamp() is 6% slower
function ex_clamp(clip a, clip hi, clip lo, int "overshoot", int "undershoot", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    os = Default(overshoot, 0)
    us = Default(undershoot, 0)
    UV = Default(UV,  rgb ? 3 : 1)
    fs = Default(fulls, false)

    os = ex_bs(os, bi, fs)
    us = ex_bs(us, bi, fs)

    str = (os == 0) && (us == 0) ? Format("x y min z max")               : \
                                   Format("x y {os} + min z {us} - max")

    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    UV == 1 ? isy ? Expr(a, hi, lo, str,                                optSingleMode=true) : \
                    Expr(a, hi, lo, str, "",                            optSingleMode=true) : \
                    Expr(a, hi, lo, str, cstr, scale_inputs=ex_UVf(bi), optSingleMode=true) }


# mt_binarize() is 37% slower
function ex_binarize(clip a, int "thres", bool "invert", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    th = Default(thres, 128)
    in = Default(invert, false)
    UV = Default(UV,  rgb ? 3 : 1)
    fs = Default(fulls, false)

    th = ex_bs(th, bi, fs)

    str = in ? Format("x {th} < range_max range_min ?") : \
               Format("x {th} > range_max range_min ?")

    str  = ex_dlut(str, bi, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    UV == 1 ? isy ? Expr(a, str) : Expr(a, str, "")             : \
                    Expr(a, str, cstr, scale_inputs=ex_UVf(bi)) }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    UV  = Default(UV,  rgb ? 3 : 1)
    fs  = Default(fulls, false)

    str = "range_max x -"

    str  = ex_dlut(str, bi, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    UV == 1 ? isy ? Expr(a, str) : Expr(a, str, "")             : \
                    Expr(a, str, cstr, scale_inputs=ex_UVf(bi)) }


# mt_lutspa() is same speed (instant when spatial)
function ex_lutspa(clip a, string "mode", string "str", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "absolute")
    str  = Default(str, "x")
    UV   = Default(UV,  rgb ? 3 : 1)
    fs   = Default(fulls, false)

    tem = FindStr(str, "frameno")  > 0 || FindStr(str, "time") > 0

    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    str  = ex_dlut(str, bi, fs)
    cstr = ex_dlut( ex_UVexpr(str, UV, bi, rgb, fs), bi, fs)

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")            : \
                       Expr(a, str, cstr, scale_inputs=ex_UVf(bi))
    tem     ? last :   trim(last,0,-1).Loop(FrameCount(a)) }


# Overlay(mode="multiply") is 56% slower (AVS+ 3.7.0)
function ex_blend(clip a, clip b, string "mode", float "opacity", int "UV", bool "tv_range", bool "fulls") {

    rgb  = isRGB(a)
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

    str = Format(                                                                                                                                                   \
        mode == "blend"        ? "x {opr} * y {op} * +"                                                                                                           : \
        mode == "screen"       ? ""+rngmax+" A@ A x "+srcmax+" - A y "+srcmax+" - * A / - {op} * x "+srcmax+" {opr} * + "+pdstl+""                                : \
        mode == "add"          ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
        mode == "linear dodge" ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
        mode == "lighten"      ? "x {opr} * x y max {op} * + "                                                                                                    : \
        mode == "multiply"     ? "x "+srcmax+" A@ y "+srcmax+" * "+rngmax+" / {op} * A {opr} * + "+pdstl+""                                                       : \
        mode == "subtract"     ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * - "+pdstl+""                                                                    : \
        mode == "darken"       ? "x {opr} * x y min {op} * + "                                                                                                    : \
                               \
        mode == "softlight"    ? "x "+srcmax+" B@ {opr} * "+rngmax+" A@ B - B y "+srcmax+" * A / * B A A B - A y "+srcmax+" - * A / - * + A / {op} * + "+pdstl+"" : \
                               \
        mode == "difference"   ? "x "+srcmax+" A@ {opr} * A y "+srcmax+"                +                {op} * - abs "+pdstl+""                                  : \
        mode == "exclusion"    ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" B@ + 2 A * B * +                {op} * + "+rngmax+" / "+pdstl+""                         : \
        mode == "extremity"    ? "x "+srcmax+" A@ {opr} * "+rngmax+"            A - y "+srcmax+" - abs   {op} * + "+pdstl+""                                      : \
        mode == "negation"     ? "x "+srcmax+" A@ {opr} * "+rngmax+" "+rngmax+" A - y "+srcmax+" - abs - {op} * + "+pdstl+""                                      : \
                                 Assert (false, "Unsupported Blend Mode.") )

    cstr = ex_dlut( ex_UVexpr(str, UV, bi, rgb, fs), bi, fs)
    str  = ex_dlut(str, bi, fs)

    UV == 1 ? isy(a) ? Expr(a, b, str,                                optSingleMode=true) : \
                       Expr(a, b, str, "",                            optSingleMode=true) : \
                       Expr(a, b, str, cstr, scale_inputs=ex_UVf(bi), optSingleMode=true) }





######################
##   CONVOLUTIONS   ##
######################

# Convolutions in AviSynth+ work better with Prefetch(physical cores) than with threads. Also for RGTools and other plugins.

# Variable Box Blur
#
# Benchmark:
# 100% removegrain(19,-1)
#  87% Dither_box_filter16(2,U=1,V=1) scales up better than ex_boxblur()
#  85% ex_boxblur(1)
#  66% blur(1.58)
#  64% generalconvolution(matrix="1 1 1 1 1 1 1 1 1",chroma=false)
#  43% mt_convolution("1 1 1","1 1 1",U=1,V=1)
#
function ex_boxblur(clip a, int "radius", int "radiusV", int "UV", bool "fulls") {

    rgb  = isRGB(a)

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
        krnh = px == -krnlrd ? Format("x[{px},0] ") : Format(krnh + "x[{px},0] + ")
       }

    krnlsz = 2 * rv + 1
    krnlrv = krnlsz/2

    krnv = ""
    for (py = -krnlrv, krnlrv, 1) {
        krnv = py == -krnlrv ? Format("x[0,{py}] ") : Format(krnv + "x[0,{py}] + ")
       }

    str  = "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 9 /"
    fbox = rd == 1 && rv == 1
    strv = fbox ? str : krnv + string(krnlrv*2+1) + " /"
    strh =              krnh + string(krnlrd*2+1) + " /"

    bi = BitsPerComponent(a)
    rv == 0 ?     a                                                                          : \
    UV == 1 ? isy(a) ? Expr(a,    strv) : Expr(a, strv, "")                                  : \
                       Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 || fbox  ? last                                                                  : \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                               : \
                       Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }


# Variable Gaussian Blur
#
# Benchmark:
# 100% removegrain(12,-1)
#  94% BinomialBlur(0.75,U=1,V=1) only in 8-bit
#  84% ex_blur(1)
#  84% ablur(1, 1) against ex_blur(2) but scales up better
#  70% blur(1.00)
#  66% generalconvolution(matrix="0 1 0 1 2 1 0 1 0",6,chroma=false) doesn't match output tho
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#  21% GBlur(rad=1,sd=1.0,u=false,v=false)
#  15% FastBlur(0.75,gamma=false)
#  10% GaussianBlur(0.75,U=1,V=1) only in 8-bit
#
# ex_blur(4) same to FRC_GaussianBlur42(1.3) and similar to ex_boxblur(2)
# ex_blur(3) same to ex_boxblur(1).ex_boxblur(1), and Dither_box_filter16(1,U=1,V=1).Dither_box_filter16(1,U=1,V=1), Dither_ about same speed
function ex_blur(clip a, int "radius", int "radiusV", string "gamma", int "UV", bool "fulls") {

    rgb  = isRGB(a)

    sm = Default(radius,   1)           # from 0 to 6
    sv = Default(radiusv, sm)           # from 0 to 6
    UV = Default(UV, rgb ? 3 : 1)
    gm = Default(gamma, "none")         # Set matrix for gamma encoded clips
    fs = Default(fulls, false)
    sm = max(min(sm * 0.30,2.0),0)
    sv = max(min(sv * 0.30,2.0),0)

    fkern  = sm==0.3 && sv==0.3
    krnlsz = 2*ceil(3*sv)
    n_f    = factorial(krnlsz)

    krnv = ""
    for (i=0, krnlsz, 1) {

        k_f = factorial(i)*factorial(krnlsz-i)
        wg  = (n_f/k_f)/pow(2,krnlsz)
        py  = i - krnlsz/2
        krnv = i == 0 ? Format("x[0,{py}] {wg} * ") : Format(krnv + "x[0,{py}] {wg} * + ")
       }

    krnlszh = 2*ceil(3*sm)
    n_f     = factorial(krnlszh)

    krnh = ""
    for (i=0, krnlszh, 1) {

        k_f = factorial(i)*factorial(krnlszh-i)
        wg  = (n_f/k_f)/pow(2,krnlszh)
        px  = i - krnlszh/2
        krnh = i == 0 ? Format("x[{px},0] {wg} * ") : Format(krnh + "x[{px},0] {wg} * + ")
       }

    strv = fkern   ?   "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 10 /" : \
           sv==0.3 ?   "x[0,1]  x[0,0] 2 * x[0,-1] + + 4 /" : \
           sv==0.0 ?   "x"                                  : \
                       krnv
    strh = sm==0.3 ?   "x[-1,0] x[0,0] 2 * x[1,0]  + + 4 /" : \
           sm==0.0 ?   "x"                                  : \
                       krnh

    bi     = BitsPerComponent(a)
    p_type = PixelType(a)
    p_4 = FindStr(p_type, "44")>0
    p_2 = FindStr(p_type, "22")>0
    p_1 = FindStr(p_type, "41")>0
    p_0 = FindStr(p_type, "20")>0
    cstrv = ""
    cstrh = ""
    if (!p_4 && (sm>0.6 || sv>0.6)) {

        krnlsz = krnlsz/(!p_0 ? 1 : 2)
        n_f    = factorial(krnlsz)

        for (i=0, krnlsz, 1) {

            k_f = factorial(i)*factorial(krnlsz-i)
            wg  = (n_f/k_f)/pow(2,krnlsz)
            py  = i - krnlsz/2
            cstrv = i == 0 ? Format("x[0,{py}] {wg} * ") : Format(cstrv + "x[0,{py}] {wg} * + ")
           }

        krnlszh = krnlszh/(p_1 ? 4 : 2)
        n_f     = factorial(krnlszh)

        for (i=0, krnlszh, 1) {

            k_f = factorial(i)*factorial(krnlszh-i)
            wg  = (n_f/k_f)/pow(2,krnlszh)
            px  = i - krnlszh/2
            cstrh = i == 0 ? Format("x[{px},0] {wg} * ") : Format(cstrh + "x[{px},0] {wg} * + ")
           }
       }

        cstrv = !p_0                        ? strv                                                                                            : \
                sm==0.6 && sv == 0.6        ? "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 10 /" : \
                fkern                       ? "x[-1,1] 0.05 * x[0,1] 0.05 * x[1,1] 0.05 * x[-1,0] 0.05 * x[0,0] 0.6 * "                         \
                                            + "x[1,0]  0.05 * x[-1,-1] 0.05 * x[0,-1] 0.05 * x[1,-1] 0.05 * + + + + + + + +"                  : \
                sv==0.6                     ? "x[0,1] x[0,0] 2 * x[0,-1] + + 4 /"                                                             : \
                sv==0.3                     ? "x[0,1] 0.12 * x[0,0] 0.76 * x[0,-1] 0.12 * + +"                                                : \
                sv==0.0                     ? "x"                                                                                             : \
                                              cstrv

        cstrh = p_4                         ? strh                                                                                            : \
                sm==0.0                     ? "x"                                                                                             : \
                sm==0.6 && !p_1             ? "x[-1,0] x[0,0] 2 * x[1,0]  + + 4 /"                                                            : \
                sm==0.3 || (sm==0.3 && p_1) ? "x[-1,0] 0.12 * x[0,0] 0.76 * x[1,0] 0.12 * + +"                                                : \
                                              cstrh

    if (gm != "none") {
        matrix = Matrix_fuzzy_search (gm)
        s_gam  = moncurve_coef(matrix)
        a      = moncurve_f(a, s_gam[0], s_gam[1], !rgb, false, fs)
    }

    sv == 0 ?     a                                                                           : \
    UV == 1 ? isy(a) ? Expr(a,    strv) :   Expr(a, strv, "")                                 : \
                       Expr(a,    strv, ex_UVexpr(cstrv, UV, bi, rgb, fs), scale_inputs="none")

    sm == 0 || fkern ? last                                                                   : \
    UV == 1 ? isy(a) ? Expr(last, strh) :   Expr(last, strh, "")                              : \
                       Expr(last, strh, ex_UVexpr(cstrh, UV, bi, rgb, fs), scale_inputs="none")
    gm != "none"     ? moncurve_r(last, s_gam[0], s_gam[1], false, !rgb, fs) : last }


function factorial(int n) {
    n<2?1:factorial(n-1)*n }


# mt_expand() is 6% faster (6% slower when radius = 2)
# "circle" + radius=2 is like calling mode="both" twice but faster
# modes: square, circle, both, vertical, horizontal
function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
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
    strh = Format("x[0,0] " + ReplaceStr(krnh, "x[0,0] max ", "") + (thr != 255 ? "A^ x[0,0] {th} + A min" : ""))
    }

    fbox = mode == "square" && rd == 1
    str  = Format("x[0,0] " + ReplaceStr(krn,  "x[0,0] max ", ""))
    str  = !fbox ? str : Format("x[-1,1] x[0,1] max x[1,1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,-1] max x[0,-1] max x[1,-1] max ")
    str  = str + (thr != 255 ? "A^ x[0,0] {th} + A min" : "")


    UV == 1 ? isy(a) ? Expr(a, str)  : Expr(a, str,  "")                                 : \
                       Expr(a, str,  ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none")

    v =    mode == "horizontal" ? a : last

    UV == 1 ? isy(a) ? Expr(v, strh) : Expr(v, strh, "")                                  : \
                       Expr(v, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none")

    fbox || mode == "vertical" || mode == "circle" || mode == "both" ? v : last           }


# mt_inpand() is 5% faster (4% slower when radius = 2)
# modes: square, circle, both, vertical, horizontal
function ex_inpand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
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
    strh = Format("x[0,0] " + ReplaceStr(krnh, "x[0,0] min ", "") + (thr != 255 ? "A^ x[0,0] {th} - A max" : ""))
    }

    fbox = mode == "square" && rd == 1
    str  = Format("x[0,0] " + ReplaceStr(krn,  "x[0,0] min ", ""))
    str  = !fbox ? str : Format("x[-1,1] x[0,1] min x[1,1] min x[-1,0] min x[0,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min ")
    str  = str + (thr != 255 ? "A^ x[0,0] {th} - A max" : "")

    UV == 1 ? isy(a) ? Expr(a, str)  : Expr(a, str,  "")                                 : \
                       Expr(a, str,  ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none")

    v =    mode == "horizontal" ? a : last

    UV == 1 ? isy(a) ? Expr(v, strh) : Expr(v, strh, "")                                  : \
                       Expr(v, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none")

    fbox || mode == "vertical" || mode == "circle" || mode == "both" ? v : last           }


# mt_deflate() is 18% faster (lower gap with bigger radius)
function ex_deflate(clip a, int "radius", int "UV", bool "fulls") {

    rgb  = isRGB(a)

    rd = Default(radius, 1)
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = py == -krnlrd && px == -krnlrd ? Format("x[{px},{py}] ") : Format(krn + "x[{px},{py}] + ")
           }
       }

    str = ReplaceStr(krn, "x[0,0] + ", "") + string(krnlsz*krnlsz-1) + " / x[0,0] min"

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                    : \
                       Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# mt_inflate() is 17% faster (lower gap with bigger radius)
function ex_inflate(clip a, int "radius", int "UV", bool "fulls") {

    rgb  = isRGB(a)

    rd = Default(radius, 1)
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = py == -krnlrd && px == -krnlrd ? Format("x[{px},{py}] ") : Format(krn + "x[{px},{py}] + ")
           }
       }

    str = ReplaceStr(krn, "x[0,0] + ", "") + string(krnlsz*krnlsz-1) + " / x[0,0] max"

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                    : \
                       Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# mt_edge() is 18% faster (varies with kernel)
function ex_edge(clip a, string "mode", int "lo", int "hi", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "sobel")
    lo   = Default(lo, 10)
    hi   = Default(hi, 10)
    UV   = Default(UV, rgb ? 3 : 1)
    fs   = Default(fulls, false)

    th = (lo == 0) && (hi == 255)
    lo = ex_bs(lo, bi, fs)
    hi = ex_bs(hi, bi, fs)

    th  = th ? "" : ex_dlut(Format("T@ {lo} < range_min T {hi} > range_max T ? ?"), bi, fs)
    str = Format(                                                                                                                                                                           \
          mode=="prewitt"   ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ "                                                                      \
                             +"A B + C + D - E - F - A G + D + C - H - F - max F E + D + C - B - A - F H + C + D - G - A - max max "                                                        \
                             +"G A + B + F - H - E - D G + E + C - H - B - max E H + F + B - A - G - B H + C + E - G - D - max max max "+th+""                                            : \
          mode=="hprewitt"  ? "x[1,1] A^ x[1,0] 2 * B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] 2 * E^ F F^ x[0,1] 2 * G^ x[0,-1] 2 * H^ "                                                             \
                             +"A B + C + D - E - F - A G + D + C - H - F - max F E + D + C - B - A - F H + C + D - G - A - max max "+th+""                                                : \
          mode=="sobel"     ? "x[1,0] A^ x[0,1] B^ x[-1,0] C^ x[0,-1] D^ A B + C - D - C D + A - B - max 2 / "+th+""                                                                      : \
          mode=="scharr"    ? "x[-1,1] 3 * A^ x[0,1] B^  x[1,1] 3 * C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] 3 * F^ x[0,-1] G^  x[1,-1] 3 * H^ "                                                    \
                             +"C A - D 10 * - E 10 * + F - H + 3 / U@ U * H G 10 * + F + C - B 10 * - A - 3 / V@ V * + sqrt "+th+""                                                       : \
          mode=="frei-chen" ? "x[-1,1] 7 * A^ x[0,1] B^  x[1,1] 7 * C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] 7 * F^ x[0,-1] G^  x[1,-1] 7 * H^ "                                                    \
                             +"C A - D 10 * - E 10 * + F - H + 7 / U@ U * H G 10 * + F + C - B 10 * - A - 7 / V@ V * + sqrt "+th+""                                                       : \
          mode=="roberts"   ? "x[0,0] 2 * A^ x[1,0] B^ x[0,1] C^ A B - C - B A - C + max 2 / "+th+""                                                                                      : \
          mode=="kayyali"   ? "x[1,1] 6 * A^ x[-1,1] 6 * B^ x[-1,-1] 6 * C^ x[1,-1] 6 * D^ B A - C + D - A B - C - D + max 2 / "+th+""                                                    : \
          mode=="robinson"  ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                                      \
                             +"C A - D 2 * - E 2 * + F - H +     B C 2 * + D - E + F 2 * - G - max     A B 2 * + C + F - G 2 * - H - max     A 2 * B + D + E - G - H 2 * - max "            \
                             +"A C - D 2 * + E 2 * - F + H - 0 B - C 2 * - D + E - F 2 * + G + max 0 A - B 2 * - C - F + G 2 * + H + max 0 A 2 * - B - D - E + G + H 2 * + max max "+th+"": \
          mode=="FDoG"      ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] 2 * G^ x[0,1] H^ x[1,1] 2 * I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                      \
                             +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] 2 * Q^ x[0,-1] R^ x[1,-1] 2 * S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] W^ x[1,-2] X^ x[2,-2] Y^ "              \
                             +"A B + D - E - F 2 * + G + I - J 2 * - K 3 * + L 3 * + N 3 * - O 3 * - P 2 * + Q + S - T 2 * - U + V + X - Y - 2 / M@ M * "                                   \
                             +"U V 2 * + W 3 * + X 2 * + Y + P + Q + R 3 * + S + T + F - G - H 3 * - I - J - A - B 2 * - C 3 * - D 2 * - E - 2 / N@ N * + sqrt "+th+""                    : \
          mode=="DoG"       ? "x[0,0] A^ x[0,1] B^ x[-1,0] C^ x[1,0] D^ x[0,-1] E^ x[0,2] F^ x[0,-2] G^ x[2,0] H^ x[-2,0] I^ x[-1,1] J^ x[-1,-1] K^ x[1,1] L^ x[1,-1] M^ "                  \
                             +"A 2 * B C D E + + + + 6 / N@ F G H I B 2 * E 2 * D 2 * C 2 * J K L M A 4 * + + + + + + + + + + + + 20 / O@ - abs 0.25 scaleb > N O - 2.0 * N ? "+th+""     : \
          mode=="LoG"       ? "x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] + + + + + + + + + + + x[0,0] 16 * - "+th+""    : \
          mode=="laplace"   ? "x[0,0] 8 * A^ x[-1,1] B^ x[0,1] C^ x[1,1] D^ x[-1,0] E^ x[1,0] F^ x[-1,-1] G^ x[0,-1] H^ x[1,-1] I^ "                                                        \
                             +"A B - C - D - E - F - G - H - I - B C + D + E + F + G + H + I + A - max 8 / "+th+""                                                                        : \
          mode=="cartoon"   ? "x[1,-1] x[0,-1] 2 * - x[0,0] + "+th+""                                                                                                                     : \
          mode=="TEdge"     ? "x[-2,0] 12 * x[-1,0] 74 * - x[1,0] 74 * + x[2,0] 12 * - 6 / A@ A * x[0,-2] 12 * x[0,-1] 74 * - x[0,1] 74 * + x[0,2] 12 * - 6 / B@ B * + sqrt "+th+""       : \
          mode=="min/max"   ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ x[0,0] O^ "                                                            \
                             +"A B max C max G max O max H max D max E max F max A B min C min G min O min H min D min E min F min - "+th+""                                              : \
                             ex_dlut(mode, bi, fs) )

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                        : \
                       Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(bi)) }


# removegrain(1,-1) is 21% faster
function ex_undot(clip a, int "radius", int "UV", bool "fulls") {

    rgb  = isRGB(a)

    rd = Default(radius, 1)            # beware; not real radius -bigger kernel-, but further apart
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    str = Format("x[-{rd},{rd}] A^ x[0,{rd}] B^ x[{rd},{rd}] C^ x[-{rd},0] D^ x[{rd},0] F^ x[-{rd},-{rd}] G^ x[0,-{rd}] H^ x[{rd},-{rd}] I^ "  \
                +"x[0,0] A B min C D min min F G min H I min min min A B max C D max max F G max H I max max max clip")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                    : \
                       Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# This is repair(mode=1)
function ex_repair(clip a, clip b, int "radius", int "UV", bool "fulls") {

    rgb  = isRGB(a)

    rd = Default(radius, 1)            # beware; not real radius -bigger kernel-, but further apart
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls, false)

    str = Format("y[-{rd},{rd}] A^ y[0,{rd}] B^ y[{rd},{rd}] C^ y[-{rd},0] D^ y[{rd},0] F^ y[-{rd},-{rd}] G^ y[0,-{rd}] H^ y[{rd},-{rd}] I^ "  \
                +"x[0,0] A B min C D min min F G min H I min min min A B max C D max max F G max H I max max max clip")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                                 : \
                       Expr(a, b, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


######### UV HELPER FUNCTIONS #########

function ex_UVexpr(string "str", int "UV", int "bits", bool "rgb", bool "fulls") {

    str  = Default(str, "")
    UV   = Default(UV, 1)
    bi   = Default(bits, 8)
    rgb  = Default(rgb, false)
    fs   = Default(fulls, false)

    bd = bi == 32 ? 0.5 : 0

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
    rgb = Default(rgb, false)
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


function ex_UVf(int bits) {

    bits == 32 ? "floatUV" : "none" }


# Scales 8-bit values to bitdepth counterpart
function ex_bs(val var, int "bits", bool "fulls") {

    bi = Default(bits, 16)
    fs = Default(fulls, false)
    var = min(max(var,0.),256.)

    Assert(IsFloat(var) || IsInt(var),"'ex_bs()' only accepts integers or floats")

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
        str = ReplaceStr(str, "ymax",                    string(ymax[fs]))
        str = ReplaceStr(str, "cmax",                    string(cmax[fs]))
        str = ReplaceStr(str, "ymin",                    string(ymin[fs]))
        str = ReplaceStr(str, "cmin",                    string(cmin[fs]))
        str = ReplaceStr(str, "range_min",               string(range_min[fs]))
        str = ReplaceStr(str, "range_half",              string(range_half[fs]))
        str = ReplaceStr(str, "range_max",               string(range_max[fs]))
        str = ReplaceStr(str, "range_size",              string(range_size[fs]))
    }

    return str }


function mskY_to_YUV(clip a, clip msk, bool "luma", int "UV", int "bits") {

    if (!isRGB(a) && !(!luma && !isy(msk))) {

        p_float = bits == 32
        p_type  = a.PixelType()
        p_type4 = FindStr(p_type, "44")>0
        p_type2 = FindStr(p_type, "22")>0
        p_type1 = FindStr(p_type, "11")>0
        p_type0 = FindStr(p_type, "20")>0

        mskY    = isy(msk) ? msk : msk.ExtractY()
        w       = p_type1 ?  round(width(a)/4.0) : round(width(a)/2.0)
        h       = p_type1 || p_type2 ? height(a) : round(height(a)/2.0)
        mskC    = p_type4 ? mskY : mskY.bilinearresize(w+w%2,h+h%2,src_left=-0.50)
        mskC    = luma ? p_float ? Expr(mskC, "x 0.5 -") : mskC : \
                  BlankClip(a,1,w+w%2,h+h%2,pixel_type="Y"+string(bits),color_yuv=$000000).killaudio()
        lmmsk   = CombinePlanes(mskY, mskC, mskC, planes="YUV", pixel_type=p_type)
    } else {
        lmmsk   = msk
    }
    return lmmsk }