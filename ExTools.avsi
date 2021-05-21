###########################################################
###                                                      ##
###                                                      ##
###           ExTools v1.0b9  (21-05-2021)               ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###      https://forum.doom9.org/showthread.php?t=182881 ##
###                                                      ##
###########################################################
###
### Pack of masktools2 replacement functions with internal Expr()
### Generally works faster in HBD, but slower in 8-bit.
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



function ex_makediff(clip a, clip b, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "x y - range_half +"

    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                          : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


function ex_adddiff(clip a, clip b, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "x y + range_half -"

    UV == 1 ? isy(a) ? Expr(a, b, str) : Expr(a, b, str, "")                          : \
                       Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


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
                          Assert (false, "Unsupported Blend Mode.") )

    UV == 0 ? Expr(a, b, str)                                                : \
              Expr(a, b, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


#fix ex_merge with luma=true in 32bit
function ex_merge(clip a, clip b, clip msk, bool "luma", int "UV") {

    isRGBa = isRGB(a)
    isYm = isy(msk)

    lm = Default(luma, false)
    UV = Default(UV, isRGBa ? 3 : 1)

    str = "x range_max z - * y z * + range_max /"

    luma  = lm && !isRGBa ? isYm ? msk : msk.ExtractY() : nop()
    lmmsk = lm && isYm && !isRGBa ? MatchColorFormat(CombinePlanes(luma, luma, luma, planes="YUV"),a) : msk

    UV == 1 ? isy(a) ? Expr(a, b,   msk, str) : Expr(a, b, lmmsk, str, "")                   : \
                       Expr(a, b, lmmsk, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# Add undershoot and overshoot
function ex_clamp(clip a, clip lo, clip hi, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = Format(" x z < z x y > y x ? ?")

    UV == 1 ? isy(a) ? Expr(a, lo, hi, str) : Expr(a, lo, hi, str, "")                     : \
                       Expr(a, lo, hi, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


function ex_binarize(clip a, int "thres", int "UV") {

    th = Default(thres, 128)
    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = Format("x {th} scaleb > range_max range_min ?")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


function ex_invert(clip a, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    str = "range_max x -"

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# mt_lutspa() is x5 times faster
function ex_lutspa(clip a, string "mode", string "str", int "UV") {

    mode = Default(mode, "absolute")
    str  = Default(str, "x")
    UV   = Default(UV, isRGB(a) ? 3 : 1)


    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }


# todo: process chroma (preconvert to RGB?)
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

# Convolutions kernels have 3 aspects; kernel size, kernel shape, and weight. Only kernel size is fixed in* for the moment until I code a string recursion function.
# * Note: radius isn't making the kernel bigger, but further apart, test results before using rad > 1



# Similar but faster than: removegrain(19), blur(1.58) or mt_convolution("1 1 1","1 1 1")
function ex_boxblur(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, isRGB(a) ? 3 : 1)


    str = Format("x[0,-{rd}] x[0,0] x[0,{rd}] + + 3 /")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                                : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a))

    str = Format("x[-{rd},0] x[0,0] x[{rd},0] + + 3 /")

    UV == 1 ? isy(a) ? Expr(last, str) : Expr(last, str, "")                          : \
                       Expr(last, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }



function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)


    str = Format( \
                  mode == "both"              ? "x[0,0] x[0,-{rd}] max x[0,{rd}] max x[-{rd},0] max x[{rd},0] max A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                         : \
                  mode == "square"            ? "x[0,0] x[-{rd},{rd}] max x[0,{rd}] max x[{rd},{rd}] max x[-{rd},0] max x[{rd},0] max x[-{rd},-{rd}] max x[0,-{rd}] max x[{rd},-{rd}] max"                        \
                                              +" A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                                                                                          : \
                  mode == "circle" && rd == 1 ? "x[0,0] x[0,1] max x[-1,0] max x[1,0] max x[0,-1] max A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                                     : \
                  mode == "circle" && rd == 2 ? "x[0,0] x[-1,-1] max x[0,-1] max x[1,-1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,1] max x[0,1] max x[1,1] max x[-2,0] max x[0,2] max x[2,0] max x[0,-2] max"   \
                                              +" A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                                                                                          : \
                                              Assert (false, "Unsupported Mode.") )

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }



function ex_inpand(clip a, string "mode", int "thres", int "UV") {

    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)


    str = mode == "both"   ? Format("x[0,0] x[0,-1] min x[0,1] min x[-1,0] min x[1,0] min A@ x[0,0] - abs {thr} scaleb > x[0,0] {thr} scaleb - A ?") : \
          mode == "square" ? Format("x[0,0] x[-1,1] min x[0,1] min x[1,1] min x[-1,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min"             \
                                 +" A@ x[0,0] - abs {thr} scaleb > x[0,0] {thr} scaleb - A ?")                                                       : \
                                 Assert (false, "Unsupported Mode.")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }



function ex_inflate(clip a, int "radius", int "thres", int "UV") {

    rd   = Default(radius, 1)
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    str = Format("x[-{rd},-{rd}] x[0,-{rd}] x[{rd},-{rd}] x[-{rd},0] x[0,0] x[{rd},0] x[-{rd},{rd}] x[0,{rd}] x[{rd},{rd}] + + + + + + + + 9 / A@ x[0,0] > A x[0,0] ?")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }



function ex_deflate(clip a, int "radius", int "thres", int "UV") {

    rd   = Default(radius, 1)
    thr  = Default(thres, 255)
    UV   = Default(UV, isRGB(a) ? 3 : 1)

    str = Format("x[-{rd},-{rd}] x[0,-{rd}] x[{rd},-{rd}] x[-{rd},0] x[0,0] x[{rd},0] x[-{rd},{rd}] x[0,{rd}] x[{rd},{rd}] + + + + + + + + 9 / A@ x[0,0] < A x[0,0] ?")

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
function ex_undot(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, isRGB(a) ? 3 : 1)


    str = Format("x x[-{rd},{rd}] x[0,{rd}] min x[{rd},{rd}] x[-{rd},0] min min x[{rd},0] x[-{rd},-{rd}] min x[0,-{rd}] x[{rd},-{rd}] min min min " \
                  +"x[-{rd},{rd}] x[0,{rd}] max x[{rd},{rd}] x[-{rd},0] max max x[{rd},0] x[-{rd},-{rd}] max x[0,-{rd}] x[{rd},-{rd}] max max max clip")

    UV == 1 ? isy(a) ? Expr(a, str) : Expr(a, str, "")                             : \
                       Expr(a, str, ex_UVexpr(a, str, UV), scale_inputs=ex_UVf(a)) }




######### HELPER FUNCTIONS #########

function ex_UVexpr(clip a, string str, int "UV") {

    UV = Default(UV, isRGB(a) ? 3 : 1)

    bd = BitsPerComponent(a) == 32 ? 0.5 : 0

    str = ReplaceStr(str, "ymax", "cmax")

    # Undefined "0" is the same as "" (when not single planed)
    str = UV == 1   ? ""          : \
          UV == 2   ? "x"         : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 128 ? "range_half": \
          string(UV+bd)+" scaleb"

    return str }


function ex_UVf(clip a) {

    BitsPerComponent(a) == 32 ? "floatUV" : "none" }