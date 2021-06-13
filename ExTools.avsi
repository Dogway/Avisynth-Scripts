###########################################################
###                                                      ##
###                                                      ##
###           ExTools v1.6     (13-06-2021)              ##
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
### *Convolutions are slower because in masktools2 they run with AVX2
###  while Expr() uses SSSE3 max for "pixel addressing".
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

# ex_lut family with automatic plane handling alike masktools2
function ex_lut(clip a, string str, string "cstr", int "Y", int "UV") {

    cstr = Default(cstr, str)
    Y    = Default(Y,             3)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    str  =                         ex_Yexpr(a, str,  Y)
    cstr = Defined(cstr) ? cstr : ex_UVexpr(a, str, UV, bi)

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a,  str, "")              : \
                       Expr(a, str, cstr, scale_inputs=ex_UVf(a,bi)) }


function ex_lutxy(clip a, clip b, string str, string "cstr", int "Y", int "UV") {

    cstr = Default(cstr, str)
    Y    = Default(Y,             3)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    str   =                         ex_Yexpr(a, str,  Y)
    cstr  = Defined(cstr) ? cstr : ex_UVexpr(a, str, UV, bi)

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, str) :  Expr(a, b, str, "")            : \
                       Expr(a, b, str, cstr, scale_inputs=ex_UVf(a, bi)) }


function ex_lutxyz(clip a, clip b, clip c, string str, string "cstr", int "Y", int "UV") {

    cstr = Default(cstr, str)
    Y    = Default(Y,             3)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    str   =                         ex_Yexpr(a, str,  Y)
    cstr  = Defined(cstr) ? cstr : ex_UVexpr(a, str, UV, bi)

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, c, str) : Expr(a, b, c, str, "")          : \
                       Expr(a, b, c, str, cstr, scale_inputs=ex_UVf(a, bi)) }


# mt_makediff() is 5% slower
function ex_makediff(clip a, clip b, int "UV", bool "dif", bool "aug") {

    UV  = Default(UV, isRGB(a) ? 3 : 1)
    dif = Default(dif, true)
    aug = Default(aug, false)

    str = dif ? "x y - range_half +" : \
          aug ? "x y - 50 *"         : \
                "x y -"

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                                  : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# mt_adddiff() is 5% slower
function ex_adddiff(clip a, clip b, int "UV", bool "dif") {

    UV  = Default(UV, isRGB(a) ? 3 : 1)
    dif = Default(dif, true)

    str = dif ? "x y + range_half -" : \
                "x y +"

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                                  : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# mt_logic(mode="and") is 6% slower
function ex_logic(clip a, clip b, string "mode", int "UV") {

    mode = Default(mode, "and")
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    str = Format(                                            \
        mode == "and"   ? "x y * range_max /"              : \
        mode == "or"    ? "x y + range_min range_max clip" : \
        mode == "xor"   ? "x y - abs"                      : \
        mode == "andn"  ? "range_max x - y * range_max /"  : \
        mode == "min"   ? "x y min"                        : \
        mode == "max"   ? "x y max"                        : \
                          Assert (false, "Unsupported mode.") )

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                                  : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# mt_merge() is 10% slower
function ex_merge(clip a, clip b, clip msk, bool "luma", int "UV") {

    lm = Default(luma, false)
    UV = Default(UV, isRGB(a) || lm ? 3 : isy(a) ? 1 : 2)
    bi = BitsPerComponent(a)

    msk = UV != 1 ? mskY_to_YUV(a, msk, lm, UV, bi) : msk
    str = "x range_max z - * y z * + range_max /"

    UV == 1 ? isy(a) ? Expr(a, b, msk, str) : Expr(a, b, msk, str, "")                             : \
                       Expr(a, b, msk, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# mt_clamp() is 6% slower
function ex_clamp(clip a, clip hi, clip lo, int "overshoot", int "undershoot", int "UV") {

    os = Default(overshoot, 0)
    us = Default(undershoot, 0)
    UV = Default(UV, isRGB(a) ? 3 : 1)
    os = min(max(os,0),255)
    us = min(max(us,0),255)

    str = (os == 0) && (us == 0) ? Format("x y min z max")                             : \
                                   Format("x y {os} scaleb + min z {us} scaleb - max")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, hi, lo, str) : Expr(a, hi, lo, str, "")                             : \
                       Expr(a, hi, lo, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# mt_binarize() is 37% slower
function ex_binarize(clip a, int "thres", bool "invert", int "UV") {

    th = Default(thres, 128)
    in = Default(invert, false)
    UV = Default(UV, isRGB(a) ? 3 : 1)
    th = min(max(th,0),255)

    str = in ? Format("x {th} scaleb < range_max range_min ?") : \
               Format("x {th} scaleb > range_max range_min ?")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                     : \
                       Expr(a, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "range_max x -"

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                     : \
                       Expr(a, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# mt_lutspa() is same speed (instant when spatial)
function ex_lutspa(clip a, string "mode", string "str", int "UV") {

    mode = Default(mode, "absolute")
    str  = Default(str, "x")
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    tem = FindStr(str, "frameno")  > 0 || FindStr(str, "time") > 0

    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                   : \
                       Expr(a, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi))
    tem     ? last :   trim(last,0,-1).Loop(FrameCount(a))                               }


# Overlay(mode="multiply") is 56% slower (AVS+ 3.7.0)
# TODO: process chroma for YUV (preconvert to RGB?)
function ex_blend(clip a, clip b, string "mode", float "opacity", int "UV", bool "tv_range") {

    isRGBa = isRGB(a)

    mode  = Default(mode, "blend")
    op    = Default(opacity, 1.0)
    UV    = Default(UV, isRGBa ? 3 : 1)
    range = Default(tv_range, !isRGBa)  # TV or PC. Luma range of your source
    op  = min(max(op,0.),1.)
    opr = 1 - op

    rngmax = range ? "ymax ymin -" : "range_max"
    srcmax = range ? "ymin -"      : ""
    pdstl  = range ? "ymin +"      : ""

    str = Format(                                                                                                                                                   \
        mode == "blend"        ? "x {opr} * y {op} * +"                                                                                                           : \
        mode == "screen"       ? ""+rngmax+" A@ A x "+srcmax+" - A y "+srcmax+" - * A / - {op} * x "+srcmax+" {opr} * + "+pdstl+""                                : \
        mode == "multiply"     ? "x "+srcmax+" A@ y "+srcmax+" * "+rngmax+" / {op} * A {opr} * + "+pdstl+""                                                       : \
        mode == "lighten"      ? "x {opr} * x y max {op} * + "                                                                                                    : \
        mode == "linear dodge" ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
        mode == "add"          ? "x "+srcmax+" A@ {opr} * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
        mode == "softlight"    ? "x "+srcmax+" B@ {opr} * "+rngmax+" A@ B - B y "+srcmax+" * A / * B A A B - A y "+srcmax+" - * A / - * + A / {op} * + "+pdstl+"" : \
                                 Assert (false, "Unsupported Blend Mode.") )

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                                  : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }






######################
##   CONVOLUTIONS   ##
######################


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
# TODO: Circular shape for bokeh. Chroma with half radius for 420 format
# TODO: gamma awareness?
function ex_boxblur(clip a, int "radius", int "radiusH", int "UV") {

    rd = Default(radius,  1)            # from 0 to inf
    rh = Default(radiusH, rd)           # from 0 to inf
    UV = Default(UV, isRGB(a) ? 3 : 1)
    rd = max(rd, 1)
    rh = max(rh, 1)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krnv = ""
    for (py = -krnlrd, krnlrd, 1) {
        krnv = py == -krnlrd ? Format("x[0,{py}] ") : Format(krnv + "x[0,{py}] + ")
       }

    krnlsz = 2 * rh + 1
    krnlrh = krnlsz/2

    krnh = ""
    for (px = -krnlrh, krnlrh, 1) {
        krnh = px == -krnlrh ? Format("x[{px},0] ") : Format(krnh + "x[{px},0] + ")
       }

    str  = "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 9 /"
    fbox = rd == 1 && rh == 1
    strv = fbox ? str : krnv + string(krnlrd*2+1) + " /"
    strh =              krnh + string(krnlrh*2+1) + " /"

    bi = BitsPerComponent(a)
    rd == 0 ?     a                                                                      : \
    UV == 1 ? isy(a) ? Expr(a,    strv) :    Expr(a, strv, "")                           : \
                       Expr(a,    strv, ex_UVexpr(a, strv, UV, bi), scale_inputs="none")
    rh == 0 || fbox  ? last                                                              : \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                           : \
                       Expr(last, strh, ex_UVexpr(a, strh, UV, bi), scale_inputs="none") }


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
# TODO: make radius work over 6 (Expr() limit?, consider DFT)
function ex_blur(clip a, int "radius", int "radiusH", string "gamma", int "UV") {

    isRGBa = isRGB(a)

    sm = Default(radius,   1)           # from 0 to 6
    sh = Default(radiusH, sm)           # from 0 to 6
    UV = Default(UV, isRGBa ? 3 : 1)
    gm = Default(gamma, "none")         # Set matrix for gamma encoded clips
    sm = max(min(sm * 0.30,2.0),0)
    sh = max(min(sh * 0.30,2.0),0)

    fkern  = sm==0.3 && sh==0.3
    krnlsz = 2*ceil(3*sm)
    n_f    = factorial(krnlsz)

    krnv = ""
    for (i= 0, krnlsz, 1) {

        k_f = factorial(i)*factorial(krnlsz-i)
        wg = (n_f/k_f)/pow(2,krnlsz)
        py = i - krnlsz/2
        krnv = i == 0 ? Format("x[0,{py}] {wg} * ") : Format(krnv + "x[0,{py}] {wg} * + ")
       }

    krnlszh = 2*ceil(3*sh)
    n_f     = factorial(krnlszh)

    krnh = ""
    for (i= 0, krnlszh, 1) {

        k_f = factorial(i)*factorial(krnlszh-i)
        wg = (n_f/k_f)/pow(2,krnlszh)
        px = i - krnlszh/2
        krnh = i == 0 ? Format("x[{px},0] {wg} * ") : Format(krnh + "x[{px},0] {wg} * + ")
       }

    strv = fkern   ?   "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 10 /" : \
           sm==0.3 ?   "x[0,1]  x[0,0] 2 * x[0,-1] + + 4 /" : \
           sm==0.0 ?   "x"                                  : \
                       krnv
    strh = sh==0.3 ?   "x[-1,0] x[0,0] 2 * x[1,0]  + + 4 /" : \
           sh==0.0 ?   "x"                                  : \
                       krnh

    bi      = BitsPerComponent(a)
    p_type  = PixelType(a)
    p_4 = FindStr(p_type, "44")>0
    p_2 = FindStr(p_type, "22")>0
    p_1 = FindStr(p_type, "41")>0
    p_0 = FindStr(p_type, "20")>0
    cstrv = ""
    cstrh = ""
    if (!p_4 && (sm>0.6 || sh>0.6)) {

        krnlsz = krnlsz/(!p_0 ? 1 : 2)
        n_f     = factorial(krnlsz)

        for (i= 0, krnlsz, 1) {

            k_f = factorial(i)*factorial(krnlsz-i)
            wg = (n_f/k_f)/pow(2,krnlsz)
            py = i - krnlsz/2
            cstrv = i == 0 ? Format("x[0,{py}] {wg} * ") : Format(cstrv + "x[0,{py}] {wg} * + ")
           }

        krnlszh = krnlszh/(p_1 ? 4 : 2)
        n_f     = factorial(krnlszh)

        for (i= 0, krnlszh, 1) {

            k_f = factorial(i)*factorial(krnlszh-i)
            wg = (n_f/k_f)/pow(2,krnlszh)
            px = i - krnlszh/2
            cstrh = i == 0 ? Format("x[{px},0] {wg} * ") : Format(cstrh + "x[{px},0] {wg} * + ")
           }
       }

        cstrv = !p_0                        ? strv                                                                                            : \
                sm==0.6 && sh == 0.6        ? "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 10 /" : \
                fkern                       ? "x[-1,1] 0.05 * x[0,1] 0.05 * x[1,1] 0.05 * x[-1,0] 0.05 * x[0,0] 0.6 * "                         \
                                            + "x[1,0]  0.05 * x[-1,-1] 0.05 * x[0,-1] 0.05 * x[1,-1] 0.05 * + + + + + + + +"                  : \
                sm==0.6                     ? "x[0,1] x[0,0] 2 * x[0,-1] + + 4 /"                                                             : \
                sm==0.3                     ? "x[0,1] 0.12 * x[0,0] 0.76 * x[0,-1] 0.12 * + +"                                                : \
                sm==0.0                     ? "x"                                                                                             : \
                                              cstrv

        cstrh = p_4                         ? strh                                                                                            : \
                sh==0.0                     ? "x"                                                                                             : \
                sh==0.6 && !p_1             ? "x[-1,0] x[0,0] 2 * x[1,0]  + + 4 /"                                                            : \
                sh==0.3 || (sh==0.3 && p_1) ? "x[-1,0] 0.12 * x[0,0] 0.76 * x[1,0] 0.12 * + +"                                                : \
                                              cstrh

    if (gm != "none") {
        matrix = Matrix_fuzzy_search (gm)
        s_gam  = moncurve_coef(matrix)
        a      = moncurve_f(a, s_gam[0], s_gam[1], !isRGBa, false)
    }

    sm == 0 ?     a                                                                      : \
    UV == 1 ? isy(a) ? Expr(a,    strv) :    Expr(a, strv, "")                           : \
                       Expr(a,    strv, ex_UVexpr(a, cstrv, UV, bi), scale_inputs="none")

    sh == 0 || fkern ? last                                                              : \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                           : \
                       Expr(last, strh, ex_UVexpr(a, cstrh, UV, bi), scale_inputs="none")
    gm != "none"     ? moncurve_r(last, s_gam[0], s_gam[1], false, !isRGBa) : last }


function factorial(int n) {
    n<2?1:factorial(n-1)*n }


# mt_expand() is 6% faster (6% slower when radius = 2)
# "circle" + radius=2 is like calling mode="both" twice but faster
function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)
    thr  = min(max(thr, 0), 255)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    if (mode != "square") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                rad = 2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py)))
                skip = mode == "both"   ? px != 0 && py != 0                         : \
                       mode == "circle" ? px != 0 && abs(px) > krnlrd*cos(rad)       : \
                       Assert (false, "Unsupported Mode.")
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
    strh = Format("x[0,0] " + ReplaceStr(krnh, "x[0,0] max ", "") + (thr != 255 ? "A^ x[0,0] {thr} scaleb + A min" : ""))
    }

    fbox = mode == "square" && rd == 1
    str  = Format("x[0,0] " + ReplaceStr(krn,  "x[0,0] max ", ""))
    str  = !fbox ? str : Format("x[-1,1] x[0,1] max x[1,1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,-1] max x[0,-1] max x[1,-1] max ")
    str  = str + (thr != 255 ? "A^ x[0,0] {thr} scaleb + A min" : "")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a,    str)  :    Expr(a, str,  "")                           :      \
                       Expr(a,    str,  ex_UVexpr(a, str,  UV, bi), scale_inputs="none")
    mode == "square" ? fbox ?     last  :                                                       \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                           :      \
                       Expr(last, strh, ex_UVexpr(a, strh, UV, bi), scale_inputs="none") : last }


# mt_inpand() is 5% faster (4% slower when radius = 2)
function ex_inpand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)
    thr  = min(max(thr, 0), 255)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    if (mode != "square") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                rad = 2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py)))
                skip = mode == "both"   ? px != 0 && py != 0                         : \
                       mode == "circle" ? px != 0 && abs(px) > krnlrd*cos(rad)       : \
                       Assert (false, "Unsupported Mode.")
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
    strh = Format("x[0,0] " + ReplaceStr(krnh, "x[0,0] min ", "") + (thr != 255 ? "A^ x[0,0] {thr} scaleb - A max" : ""))
    }

    fbox = mode == "square" && rd == 1
    str  = Format("x[0,0] " + ReplaceStr(krn,  "x[0,0] min ", ""))
    str  = !fbox ? str : Format("x[-1,1] x[0,1] min x[1,1] min x[-1,0] min x[0,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min ")
    str  = str + (thr != 255 ? "A^ x[0,0] {thr} scaleb - A max" : "")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a,    str)  :    Expr(a, str,  "")                           :      \
                       Expr(a,    str,  ex_UVexpr(a, str,  UV, bi), scale_inputs="none")
    mode == "square" ? fbox ?     last  :                                                       \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                           :      \
                       Expr(last, strh, ex_UVexpr(a, strh, UV, bi), scale_inputs="none") : last }


# mt_deflate() is 18% faster (lower gap with bigger radius)
function ex_deflate(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, isRGB(a) ? 3 : 1)

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
    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                         : \
                       Expr(a, str, ex_UVexpr(a, str, UV, bi), scale_inputs="none") }


# mt_inflate() is 17% faster (lower gap with bigger radius)
function ex_inflate(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, isRGB(a) ? 3 : 1)

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
    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                           : \
                       Expr(a, str, ex_UVexpr(a, str, UV, bi), scale_inputs="none") }


# mt_edge() is 18% faster (varies with kernel)
function ex_edge(clip a, string "mode", int "lo", int "hi", int "UV") {

    mode = Default(mode, "sobel")
    lo   = Default(lo, 10)
    hi   = Default(hi, 10)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    th  = (lo == 0) && (hi == 255) ? "" : "T@ {lo} scaleb < range_min T {hi} scaleb > range_max T ? ?"
    str = Format(                                                                                                                               \
          mode=="prewitt" ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ "                            \
                             +"A B + C + D - E - F - A G + D + C - H - F - max F E + D + C - B - A - F H + C + D - G - A - max max "            \
                             +"G A + B + F - H - E - D G + E + C - H - B - max E H + F + B - A - G - B H + C + E - G - D - max max max "+th+"": \
          mode=="hprewitt"? "x[1,1] A^ x[1,0] 2 * B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] 2 * E^ F F^ x[0,1] 2 * G^ x[0,-1] 2 * H^ "                   \
                             +"A B + C + D - E - F - A G + D + C - H - F - max F E + D + C - B - A - F H + C + D - G - A - max max "+th+""    : \
          mode=="sobel"   ? "x[1,0] A^ x[0,1] B^ x[-1,0] C^ x[0,-1] D^ A B + C - D - C D + A - B - max 2 / "+th+""                            : \
          mode=="roberts" ? "x[0,0] 2 * A^ x[1,0] B^ x[0,1] C^ A B - C - B A - C + max 2 / "+th+""                                            : \
          mode=="laplace" ? "x[0,0] 8 * A^ x[-1,1] B^ x[0,1] C^ x[1,1] D^ x[-1,0] E^ x[1,0] F^ x[-1,-1] G^ x[0,-1] H^ x[1,-1] I^ "              \
                            +"A B - C - D - E - F - G - H - I - B C + D + E + F + G + H + I + A - max 8 / "+th+""                             : \
          mode=="cartoon" ? "x[1,-1] x[0,-1] 2 * - x[0,0] + "+th+""                                                                           : \
          mode=="min/max" ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ x[0,0] O^ "                  \
                            +"A B max C max G max O max H max D max E max F max A B min C min G min O min H min D min E min F min - "+th+""   : \
                             mode )

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                                  : \
                       Expr(a, str, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


# removegrain(1,-1) is 21% faster
function ex_undot(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)            # beware; not real radius -bigger kernel-, but further apart
    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = Format("x[-{rd},{rd}] A^ x[0,{rd}] B^ x[{rd},{rd}] C^ x[-{rd},0] D^ x[{rd},0] F^ x[-{rd},-{rd}] G^ x[0,-{rd}] H^ x[{rd},-{rd}] I^ "  \
                +"x[0,0] A B min C D min min F G min H I min min min A B max C D max max F G max H I max max max clip")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                           : \
                       Expr(a, str, ex_UVexpr(a, str, UV, bi), scale_inputs="none") }


# This is repair(mode=1)
function ex_repair(clip a, clip b, int "radius", int "UV") {

    rd = Default(radius, 1)            # beware; not real radius -bigger kernel-, but further apart
    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = Format("y[-{rd},{rd}] A^ y[0,{rd}] B^ y[{rd},{rd}] C^ y[-{rd},0] D^ y[{rd},0] F^ y[-{rd},-{rd}] G^ y[0,-{rd}] H^ y[{rd},-{rd}] I^ "  \
                +"x[0,0] A B min C D min min F G min H I min min min A B max C D max max F G max H I max max max clip")

    bi = BitsPerComponent(a)
    UV == 1 ? isy(a) ? Expr(a, b, str) :    Expr(a, b, str, "")                           : \
                       Expr(a, b, str, ex_UVexpr(a,    str, UV, bi), scale_inputs="none") }


######### UV HELPER FUNCTIONS #########

function ex_UVexpr(clip a, string "str", int "UV", int "bits") {

    UV   = Default(UV, 1)
    str  = Default(str, "")
    bits = Default(bits, 8)

    bd = bits == 32 ? 0.5 : 0

    str = isRGB(a) ? str : ReplaceStr(str, "ymax", "cmax")

    # Undefined "0" is the same as "" (when not single planed)
    str = UV == 1   ? ""          : \
          UV == 2   ? "x"         : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 128 ? "range_half": \
          UV == 0   ? "range_min" : \
          UV == 255 ? "range_max" : \
          string(UV+bd)+" scaleb"

    return str }

function ex_Yexpr(clip a, string "str", int "Y") {

    Y   = Default(Y, 3)
    str = Default(str, "")

    str = Y == 1   ? ""          : \
          Y == 2   ? "x"         : \
          Y == 3   ? str         : \
          Y == 4   ? "y"         : \
          Y == 128 ? "range_half": \
          Y == 0   ? "range_min" : \
          Y == 255 ? "range_max" : \
          string(Y) + " scaleb"

    return str }


function ex_UVf(clip a, int bits) {

    bits == 32 ? "floatUV" : "none" }


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