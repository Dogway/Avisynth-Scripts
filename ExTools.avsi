###########################################################
###                                                      ##
###                                                      ##
###           ExTools v1.0b13  (24-05-2021)              ##
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
                          Assert (false, "Unsupported Mode.") )

    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                          : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_merge() is 12% faster
# Consider chroma shift in msk
function ex_merge(clip a, clip b, clip msk, bool "luma", int "UV") {

    isRGBa = isRGB(a)

    lm = Default(luma, false)
    UV = Default(UV, isRGBa ? 3 : 1)

    if (!isRGBa) {
        lumaC = isy(msk) && lm && BitsPerComponent(a) == 32 ? Expr(msk, "x 0.5 -")                       : msk
        lmmsk = isy(msk) && !isy(a) ? MatchColorFormat(CombinePlanes(msk, lumaC, lumaC, planes="YUV"),a) : msk
    } else {
        lmmsk = msk
    }

    str = "x range_max z - * y z * + range_max /"

    UV == 1 ? isy(a) ? Expr(a, b,   msk, str) : Expr(a, b, lmmsk, str, "")                   : \
                       Expr(a, b, lmmsk, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# Add undershoot and overshoot
function ex_clamp(clip a, clip lo, clip hi, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = Format("x z < z x y > y x ? ?")

    UV == 1 ? isy(a) ? Expr(a, lo, hi, str) : Expr(a, lo, hi, str, "")                     : \
                       Expr(a, lo, hi, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_binarize() is 37% slower
function ex_binarize(clip a, int "thres", bool "invert", int "UV") {

    th = Default(thres, 128)
    in = Default(invert, false)
    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = in ? Format("x {th} scaleb < range_max range_min ?") : \
               Format("x {th} scaleb > range_max range_min ?")
#    str = Format("x x {th} scaleb - x {th} scaleb + clip") # slower than ternary
#    str = Format("x x {th} scaleb - * ")                   # slower than ternary

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "range_max x -"

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_lutspa() is 740% faster but is only spatial
# TODO: make 1 frame and copy for clip length if there's no frameno
function ex_lutspa(clip a, string "mode", string "str", int "UV") {

    mode = Default(mode, "absolute")
    str  = Default(str, "x")
    UV   = Default(UV, isRGB(a) ? 3 : 1)


    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# Overlay(mode="multiply") is 44% slower
# TODO: process chroma (preconvert to RGB?)
function ex_blend(clip a, clip b, string "mode", float "opacity", int "UV", bool "tv_range") {

    isRGBa = isRGB(a)

    mode  = Default(mode, "blend")
    op    = Default(opacity, 1.0)
    UV    = Default(UV, isRGBa ? 3 : 1)
    range = Default(tv_range, !isRGBa)  # TV or PC. Luma range of your source

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

# Benchmark:
# 100% removegrain(19,-1)
#  71% ex_boxblur(1)
#  66% blur(1.58)
#  64% generalconvolution(matrix="1 1 1 1 1 1 1 1 1",chroma=false)
#  43% mt_convolution("1 1 1","1 1 1",U=1,V=1)
function ex_boxblur(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)            # from 1 to inf
    UV = Default(UV, isRGB(a) ? 3 : 1)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krnv = ""
    for (py = -krnlrd, krnlrd, 1) {
        krnv = py == -krnlrd ? Format("x[0,{py}] ") : Format(krnv + "x[0,{py}] + ")
       }

    krnh = ""
    for (px = -krnlrd, krnlrd, 1) {
        krnh = px == -krnlrd ? Format("x[{px},0] ") : Format(krnh + "x[{px},0] + ")
       }

    strv = krnv + string(krnlrd*2+1) + " /"
    strh = krnh + string(krnlrd*2+1) + " /"

    UV == 1 ? isy(a) ? Expr(a,    strv) :    Expr(a, strv, "")                          : \
                       Expr(a,    strv, ex_UVexpr(a, strv, UV), scale_inputs=ex_UVf(a))

    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                          : \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs=ex_UVf(a)) }


# Variable Gaussian Blur
#
# Benchmark:
# 100% removegrain(12,-1)
#  72% ex_blur(1)
#  70% blur(1.00)
#  66% generalconvolution(matrix="0 1 0 1 2 1 0 1 0",6,chroma=false) doesn't match output tho
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#
# ex_blur(4) same to FRC_GaussianBlur42(1.3) and similar to ex_boxblur(2)
# TODO: make radius work over 6, optimize with linear sampled gaussian
function ex_blur(clip a, int "radius", int "UV") {

    sm = Default(radius, 1)           # from 1 to 6
    UV = Default(UV, isRGB(a) ? 3 : 1)

    sm     = min(sm * 0.30,2.0)
    krnlsz = 2*ceil(3*sm)
    n_f    = factorial(krnlsz)

    krnv = ""
    for (i= 0, krnlsz, 1) {

        k_f = factorial(i)*factorial(krnlsz-i)
        wg = n_f/k_f
        py = i - krnlsz/2
        krnv = i == 0 ? Format("x[0,{py}] {wg} * ") : Format(krnv + "x[0,{py}] {wg} * + ")
       }

    krnh = ""
    for (i= 0, krnlsz, 1) {

        k_f = factorial(i)*factorial(krnlsz-i)
        wg = n_f/k_f
        px = i - krnlsz/2
        krnh = i == 0 ? Format("x[{px},0] {wg} * ") : Format(krnh + "x[{px},0] {wg} * + ")
       }

    strv = krnv + string(pow(2,krnlsz)) + " /"
    strh = krnh + string(pow(2,krnlsz)) + " /"

    UV == 1 ? isy(a) ? Expr(a,    strv) :    Expr(a, strv, "")                          : \
                       Expr(a,    strv, ex_UVexpr(a, strv, UV), scale_inputs=ex_UVf(a))

    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                          : \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs=ex_UVf(a)) }


function factorial(int n) {
    n<2?1:factorial(n-1)*n }


# mt_expand() is 33% faster (lower gap with bigger radius)
# "circle" rad=2 is like "both" twice but faster
# TODO: Need to work out shape for "circle" && rad>1
# TODO: Implement thres
function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    if (mode != "square") {

    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            skip = mode == "both"   ? py != 0 && px != 0                                       : \
                   mode == "circle" ? (abs(py) == rd || abs(px) == rd) && (py != 0 && px != 0) : \
                   Assert (false, "Unsupported Mode.")
            krn = skip ? krn : Format(krn + "x[{px},{py}] max ")
           }
       }

    } else {

    for (py  = -krnlrd, krnlrd, 1) {
        krn  = Format(krn  + "x[0,{py}] max ")
       }

    krnh = ""
    for (px  = -krnlrd, krnlrd, 1) {
        krnh = Format(krnh + "x[{px},0] max ")
       }

    strh = ReplaceStr(krnh, "x[0,0] max ", "")
    strh = Format("x[0,0] " + strh + "A^ x[0,0] {thr} scaleb + A min")
    }

    str  = ReplaceStr(krn, "x[0,0] max ", "")
    str  = Format("x[0,0] " + str  + "A^ x[0,0] {thr} scaleb + A min")

    UV == 1 ? isy(a) ? Expr(a,    str)  :    Expr(a, str,  "")                          :      \
                       Expr(a,    str,  ex_UVexpr(a, str,  UV), scale_inputs=ex_UVf(a))
    mode == "square" ?                                                                         \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                          :      \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs=ex_UVf(a)) : last }


# mt_inpand() is 33% faster (lower gap with bigger radius)
# TODO: Implement thres
function ex_inpand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""
    if (mode != "square") {

    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            skip = mode == "both"   ? py != 0 && px != 0                                       : \
                   mode == "circle" ? (abs(py) == rd || abs(px) == rd) && (py != 0 && px != 0) : \
                   Assert (false, "Unsupported Mode.")
            krn = skip ? krn : Format(krn + "x[{px},{py}] min ")
           }
       }

    } else {

    for (py  = -krnlrd, krnlrd, 1) {
        krn  = Format(krn  + "x[0,{py}] min ")
       }

    krnh = ""
    for (px  = -krnlrd, krnlrd, 1) {
        krnh = Format(krnh + "x[{px},0] min ")
       }

    strh = ReplaceStr(krnh, "x[0,0] min ", "")
    strh = Format("x[0,0] " + strh + "A^ x[0,0] {thr} scaleb - A max")
    }

    str  = ReplaceStr(krn, "x[0,0] min ", "")
    str  = Format("x[0,0] " + str  + "A^ x[0,0] {thr} scaleb - A max")

    UV == 1 ? isy(a) ? Expr(a,    str)  :    Expr(a, str,  "")                          :      \
                       Expr(a,    str,  ex_UVexpr(a, str,  UV), scale_inputs=ex_UVf(a))
    mode == "square" ?                                                                         \
    UV == 1 ? isy(a) ? Expr(last, strh) : Expr(last, strh, "")                          :      \
                       Expr(last, strh, ex_UVexpr(a, strh, UV), scale_inputs=ex_UVf(a)) : last }


# mt_deflate() is 18% faster (lower gap with bigger radius)
# Slower for kernel 3x3 if separated (Min() x2)
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

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


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

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# WIP: implement separable mats, thresholding and sharpen mode
function ex_edge(clip a, string "kernel", string "mode", int "str", int "thres", int "UV") {

    kernel = Default(kernel, "sobel")
    mode   = Default(mode,    "edge")    # "edge": for edge detection, or "sharpen": for sharpening
    str    = Default(str, 2)
    thres  = Default(thres, 0.25)
    UV     = Default(UV, isRGB(a) ? 3 : 1)

    str = Format(                                                                                                                                                                                                \
          kernel=="prewitt" ? "x[-1,0] x[-1,1] + x[1,1] - x[1,0] - x[1,-1] - x[-1,-1] + 2 ^ "                                                                                                                    \
                             +"x[-1,1] x[0,1] + x[1,1] + x[1,-1] - x[0,-1] - x[-1,-1] - 2 ^ * sqrt"                                                                                                            : \
          kernel=="sobel"   ? "x[-1,0] 2 * x[-1,1] + x[1,1] - x[1,0] 2 * - x[1,-1] - x[-1,-1] + 2 ^ "                                                                                                            \
                             +"x[-1,0] x[-1,1] + x[0,1] 2 * + x[1,1] + x[1,-1] - x[0,-1] 2 * - x[-1,-1] - 2 ^ * sqrt"                                                                                          : \
          kernel=="LoG"     ? "x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] + + + + + + + + + + + x[0,0] 16 * -"                                : \
          kernel=="DoG"     ? "x[0,0] 2 * x[0,1] x[-1,0] x[1,0] x[0,-1] + + + + 6 / A@ x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] x[0,0] 4 * "  \
                             +"+ + + + + + + + + + + + 20 / B@ - abs {thres} scaleb > A B - {str} * A ?"                                                                                                       : \
          kernel=="Roberts" ? "x[0,0] x[1,-1] - 2 ^ x[1,0] x[0,-1] - 2 ^ + sqrt {str} *"                                                                                                                       : \
          kernel=="Laplace" ? "x[0,0] 8 * x[-1,1] - x[0,1] - x[1,1] - x[-1,0] - x[1,0] - x[-1,-1] - x[0,-1] - x[1,-1] - {str} *"                                                                               : \
                             Assert (false, "Unsupported Kernel.") )

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# Use removegrain(1) as it's faster
# TODO: make separable
function ex_undot(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, isRGB(a) ? 3 : 1)


    str = Format("x x[-{rd},{rd}] x[0,{rd}] min x[{rd},{rd}] x[-{rd},0] min min x[{rd},0] x[-{rd},-{rd}] min x[0,-{rd}] x[{rd},-{rd}] min min min "    \
                  +"x[-{rd},{rd}] x[0,{rd}] max x[{rd},{rd}] x[-{rd},0] max max x[{rd},0] x[-{rd},-{rd}] max x[0,-{rd}] x[{rd},-{rd}] max max max clip")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }



######### HELPER FUNCTIONS #########

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