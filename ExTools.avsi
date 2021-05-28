###########################################################
###                                                      ##
###                                                      ##
###           ExTools v1.0     (27-05-2021)              ##
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
### Dependencies: AviSynth+ 3.5+
###               Utils-r41 (for ex_merge)
###
###
####################################


# mt_makediff() is 5% slower
function ex_makediff(clip a, clip b, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "x y - range_half +"

    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                          : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_adddiff() is 5% slower
function ex_adddiff(clip a, clip b, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "x y + range_half -"

    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                          : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


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

    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                          : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_merge() is 10% slower
function ex_merge(clip a, clip b, clip msk, bool "luma", int "UV") {

    lm = Default(luma, false)
    UV = Default(UV, isRGB(a) || lm ? 3 : isy(a) ? 1 : 2)

    msk = UV != 1 ? mskY_to_YUV(a, msk, lm, UV) : msk
    str = "x range_max z - * y z * + range_max /"

    UV == 1 ? isy(a) ? Expr(a, b, msk, str) : Expr(a, b, msk, str, "")                     : \
                       Expr(a, b, msk, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_clamp() is 6% slower
function ex_clamp(clip a, clip hi, clip lo, int "overshoot", int "undershoot", int "UV") {

    os = Default(overshoot, 0)
    us = Default(undershoot, 0)
    UV = Default(UV, isRGB(a) ? 3 : 1)
    os = min(max(os,0),255)
    us = min(max(us,0),255)

    str = (os == 0) && (us == 0) ? Format("x y min z max")                                 : \
                                   Format("x y {os} scaleb + min z {us} scaleb - max")

    UV == 1 ? isy(a) ? Expr(a, hi, lo, str) : Expr(a, hi, lo, str, "")                     : \
                       Expr(a, hi, lo, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_binarize() is 37% slower
function ex_binarize(clip a, int "thres", bool "invert", int "UV") {

    th = Default(thres, 128)
    in = Default(invert, false)
    UV = Default(UV, isRGB(a) ? 3 : 1)
    th = min(max(th,0),255)

    str = in ? Format("x {th} scaleb < range_max range_min ?") : \
               Format("x {th} scaleb > range_max range_min ?")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "range_max x -"

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_lutspa() is same speed (instant when spatial)
function ex_lutspa(clip a, string "mode", string "str", int "UV") {

    mode = Default(mode, "absolute")
    str  = Default(str, "x")
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    tem = FindStr(str, "frameno")  > 0 || FindStr(str, "time") > 0

    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a))
    tem     ? last :   trim(last,0,-1).Loop(FrameCount(a))                         }


# Overlay(mode="multiply") is 56% slower
# TODO: process chroma for YUV (preconvert to RGB?)
function ex_blend(clip a, clip b, string "mode", float "opacity", int "UV", bool "tv_range") {

    isRGBa = isRGB(a)

    mode  = Default(mode, "blend")
    op    = Default(opacity, 1.0)
    UV    = Default(UV, isRGBa ? 3 : 1)
    range = Default(tv_range, !isRGBa)  # TV or PC. Luma range of your source
    op = min(max(op,0.),1.)

    rngmax = range ? "ymax ymin -" : "range_max"
    srcmax = range ? "ymin -"      : ""
    pdstl  = range ? "ymin +"      : ""

    str = Format(                                                                                                                                                      \
        mode == "blend"        ? "x 1 {op} - * y {op} * +"                                                                                                           : \
        mode == "multiply"     ? "x "+srcmax+" A@ y "+srcmax+" * "+rngmax+" / {op} * A 1 {op} - * + "+pdstl+""                                                       : \
        mode == "screen"       ? ""+rngmax+" A@ A x "+srcmax+" - A y "+srcmax+" - * A / - {op} * x "+srcmax+" 1 {op} - * + "+pdstl+""                                : \
        mode == "lighten"      ? "x 1 {op} - * x y max {op} * + "                                                                                                    : \
        mode == "linear dodge" ? "x "+srcmax+" A@ 1 {op} - * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
        mode == "add"          ? "x "+srcmax+" A@ 1 {op} - * A y "+srcmax+" + {op} * + "+pdstl+""                                                                    : \
        mode == "softlight"    ? "x "+srcmax+" B@ 1 {op} - * "+rngmax+" A@ B - B y "+srcmax+" * A / * B A A B - A y "+srcmax+" - * A / - * + A / {op} * + "+pdstl+"" : \
                                 Assert (false, "Unsupported Blend Mode.") )

    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                          : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }






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

    rd == 0 ?     a                                                                  : \
    UV == 1 ? isy(a) ? Expr(a,    strv) :    Expr(a, strv, "")                       : \
                       Expr(a,    strv, ex_UVexpr(a, strv, UV), scale_inputs="none")
    rh == 0 || fbox  ? last                                                          : \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                       : \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs="none") }


# Variable Gaussian Blur
#
# Benchmark:
# 100% removegrain(12,-1)
#  84% ex_blur(1)
#  70% blur(1.00)
#  66% generalconvolution(matrix="0 1 0 1 2 1 0 1 0",6,chroma=false) doesn't match output tho
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#
# ex_blur(4) same to FRC_GaussianBlur42(1.3) and similar to ex_boxblur(2)
# ex_blur(3) same to ex_boxblur(1).ex_boxblur(1), and Dither_box_filter16(1,U=1,V=1).Dither_box_filter16(1,U=1,V=1), Dither_ about same speed
# TODO: make radius work over 6 (Expr() limit?, consider DFT)
function ex_blur(clip a, int "radius", int "radiusH", int "UV") {

    sm = Default(radius,   1)           # from 0 to 6
    sh = Default(radiusH, sm)           # from 0 to 6
    UV = Default(UV, isRGB(a) ? 3 : 1)
    sm = max(min(sm * 0.30,2.0),0)
    sh = max(min(sh * 0.30,2.0),0)

    krnlsz = 2*ceil(3*sm)
    n_f    = factorial(krnlsz)

    krnv = ""
    for (i= 0, krnlsz, 1) {

        k_f = factorial(i)*factorial(krnlsz-i)
        wg = n_f/k_f
        py = i - krnlsz/2
        krnv = i == 0 ? Format("x[0,{py}] {wg} * ") : Format(krnv + "x[0,{py}] {wg} * + ")
       }

    krnlszh = 2*ceil(3*sh)
    n_f     = factorial(krnlszh)

    krnh = ""
    for (i= 0, krnlszh, 1) {

        k_f = factorial(i)*factorial(krnlszh-i)
        wg = n_f/k_f
        px = i - krnlszh/2
        krnh = i == 0 ? Format("x[{px},0] {wg} * ") : Format(krnh + "x[{px},0] {wg} * + ")
       }

    str  = "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 10 /"
    fbox = sm == 0.3 && sh == 0.3
    strv = fbox ? str : krnv + string(pow(2,krnlsz )) + " /"
    strh =              krnh + string(pow(2,krnlszh)) + " /"

    sm == 0 ?     a                                                                  : \
    UV == 1 ? isy(a) ? Expr(a,    strv) :    Expr(a, strv, "")                       : \
                       Expr(a,    strv, ex_UVexpr(a, strv, UV), scale_inputs="none")

    sh == 0 || fbox  ? last                                                          : \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                       : \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs="none") }


function factorial(int n) {
    n<2?1:factorial(n-1)*n }


# mt_expand() is 7% faster (lower gap with bigger radius)
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
    str  = Format("x[0,0] " + ReplaceStr(krn,  "x[0,0] max ", "") + (thr != 255 ? "A^ x[0,0] {thr} scaleb + A min" : ""))
    str  = !fbox ? str : Format("x[-1,1] x[0,1] max x[1,1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,-1] max x[0,-1] max x[1,-1] max A^ x[0,0] {thr} scaleb + A min")

    UV == 1 ? isy(a) ? Expr(a,    str)  :    Expr(a, str,  "")                       :      \
                       Expr(a,    str,  ex_UVexpr(a, str,  UV), scale_inputs="none")
    mode == "square" ? fbox ?     last  :                                                   \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                       :      \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs="none") : last }


# mt_inpand() is 7% faster (lower gap with bigger radius)
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
    str  = Format("x[0,0] " + ReplaceStr(krn,  "x[0,0] min ", "") + (thr != 255 ? "A^ x[0,0] {thr} scaleb - A max" : ""))
    str  = !fbox ? str : Format("x[-1,1] x[0,1] min x[1,1] min x[-1,0] min x[0,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min A^ x[0,0] {thr} scaleb - A max")

    UV == 1 ? isy(a) ? Expr(a,    str)  :    Expr(a, str,  "")                       :      \
                       Expr(a,    str,  ex_UVexpr(a, str,  UV), scale_inputs="none")
    mode == "square" ? fbox ?     last  :                                                   \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                       :      \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs="none") : last }


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

    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                       : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs="none") }


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

    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                       : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs="none") }


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

    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                          : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# removegrain(1,-1) is 21% faster
function ex_undot(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)            # beware; not real radius -bigger kernel-, but further apart
    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = Format("x[-{rd},{rd}] A^ x[0,{rd}] B^ x[{rd},{rd}] C^ x[-{rd},0] D^ x[{rd},0] F^ x[-{rd},-{rd}] G^ x[0,-{rd}] H^ x[{rd},-{rd}] I^ "  \
                +"x[0,0] A B min C D min min F G min H I min min min A B max C D max max F G max H I max max max clip")

    UV == 1 ? isy(a) ? Expr(a, str) :    Expr(a, str, "")                       : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs="none") }



######### UV HELPER FUNCTIONS #########

function ex_UVexpr(clip a, string "str", int "UV") {

    UV  = Default(UV, 1)
    str = Default(str, "")

    bd = BitsPerComponent(a) == 32 ? 0.5 : 0

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


function ex_UVf(clip a) {

    BitsPerComponent(a) == 32 ? "floatUV" : "none" }


function mskY_to_YUV(clip a, clip msk, bool "luma", int "UV") {

    if (!isRGB(a) && !(!luma && !isy(msk))) {

        p_depth = BitsPerComponent(a)
        p_float = p_depth == 32
        p_type  = a.PixelType()
        p_type4 = FindStr(p_type, "44")>0
        p_type2 = FindStr(p_type, "22")>0
        p_type1 = FindStr(p_type, "11")>0    # uses MPEG1?
        p_type0 = FindStr(p_type, "20")>0

        mskY    = isy(msk) ? msk : msk.ExtractY()
        w       = p_type1 ?  round(width(a)/4.0) : round(width(a)/2.0)
        h       = p_type1 || p_type2 ? height(a) : round(height(a)/2.0)
        mskC    = p_type4 ? mskY : mskY.bilinearresize(w+w%2,h+h%2,src_left=-0.50)
        mskC    = luma ? p_float ? Expr(mskC, "x 0.5 -") : mskC : \
                  BlankClip(a,1,w+w%2,h+h%2,pixel_type="Y"+string(p_depth),color_yuv=$000000).killaudio()
        lmmsk   = CombinePlanes(mskY, mskC, mskC, planes="YUV", pixel_type=p_type)
    } else {
        lmmsk   = msk
    }
    return lmmsk }