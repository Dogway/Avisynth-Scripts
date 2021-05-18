###########################################################
###                                                      ##
###                                                      ##
###           ExTools v1.0b2  (18-05-2021)               ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
###########################################################
###
### Pack of masktools2 replacement functions with internal Expr()
### Generally works faster in HBD, but slower in 8-bit.
###
### UV setting works similarly as in masktools2:
###
### 0:   Undefined
### 1:   garbage
### 2:   copy first
### 3:   process
### 4:   copy second
### 128: range_half
###
### * lumamask isn't needed (use UV=0 or UV=3) since now
###    ...Expr() needs clips with same number of planes.
###
### Dependencies: AviSynth+ r2724+
###
###
####################################



function ex_makediff(clip a, clip b, int "UV") {

    UV = Default(UV, 0)

    str = "x y - range_half +"
    ch = ex_UVchannel(a, str, UV)

    Expr(a, b, str, ch) }


function ex_adddiff(clip a, clip b, int "UV") {

    UV = Default(UV, 0)

    str = "x y + range_half -"
    ch = ex_UVchannel(a, str, UV)

    Expr(a, b, str, ch) }


function ex_merge(clip a, clip b, clip msk, int "UV") {

    UV = Default(UV, 0)

    str = "x range_max z - * y z * + range_max /"
    ch = ex_UVchannel(a, str, UV)

    Expr(a, b, msk, str, ch) }


function ex_clamp(clip a, clip lo, clip hi, int "UV") {

    UV = Default(UV, 0)

    str = Format(" x z < z x y > y x ? ?")
    ch = ex_UVchannel(a, str, UV)

    Expr(a, lo, hi, str, ch) }


function ex_binarize(clip a, int "thres", int "UV") {

    UV = Default(UV, 0)
    th = Default(thres, 128)

    str = Format("x {th} scaleb > range_max range_min ?")
    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }


# mt_lutspa() is x5 times faster
function ex_lutspa(clip a, string "mode", string "str", int "UV") {

    UV   = Default(UV, 0)
    mode = Default(mode, "absolute")
    str  = Default(str, "x")

    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }



# Need to fix the TV range, PC range thing
function ex_blend(clip a, clip b, string "mode", float "opacity", int "UV") {

    mode = Default(mode, "blend")
    op   = Default(opacity, 1.0)
    UV   = Default(UV, 0)

    str = Format(                                                                                                          \
        mode == "blend"        ? "ymax ymin - A^ x ymin - A / 1 {op} / ^ A * ymin + "                                    : \
        mode == "multiply"     ? "x ymin - y ymin - * ymax ymin - / {op} * x ymin - 1 {op} - * + ymin + "                : \
        mode == "screen"       ? "ymax ymin - A@ A x ymin - - A y ymin - - * A / - {op} * x ymin - 1 {op} - * + ymin + " : \
        mode == "linear dodge" ? "x y max {op} * x 1 {op} - * +"                                                         : \
        mode == "add"          ? "x y max {op} * x 1 {op} - * +"                                                         : \
        mode == "softlight"    ? "y range_max / A^ x range_max / B^ 1 2 A * - B 2 ^ * 2 B A * * + range_max *"           : \
                                 Assert (false, "Unsupported Blend Mode.") )
    ch = ex_UVchannel(a, str, UV)

    Expr(a, b, str, ch) }




## Convolutions
# Convolutions kernels have 3 aspects; kernel size, kernel shape, and weight. Only kernel size is fixed in for the moment until I code a string recursion function.
# * Note: radius isn't making the kernel bigger, but further apart, test results before using rad > 1

# Similar but faster than: removegrain(19), blur(1.58) or mt_convolution("1 1 1","1 1 1")
function ex_boxblur(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, 0)

    str = Format("x[0,-{rd}] x[0,0] x[0,{rd}] + + 3 /")
    ch = ex_UVchannel(a, str, UV)
    Expr(a, str, ch)

    str = Format("x[-{rd},0] x[0,0] x[{rd},0] + + 3 /")
    ch = ex_UVchannel(a, str, UV)
    Expr(last, str, ch)  }



function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, 0)

    str = Format( \
                  mode == "cross"             ? "x[0,0] x[0,-{rd}] max x[0,{rd}] max x[-{rd},0] max x[{rd},0] max A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                         : \
                  mode == "square"            ? "x[0,0] x[-{rd},{rd}] max x[0,{rd}] max x[{rd},{rd}] max x[-{rd},0] max x[{rd},0] max x[-{rd},-{rd}] max x[0,-{rd}] max x[{rd},-{rd}] max"                        \
                                              +" A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                                                                                          : \
                  mode == "circle" && rd == 1 ? "x[0,0] x[0,1] max x[-1,0] max x[1,0] max x[0,-1] max A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                                     : \
                  mode == "circle" && rd == 2 ? "x[0,0] x[-1,-1] max x[0,-1] max x[1,-1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,1] max x[0,1] max x[1,1] max x[-2,0] max x[0,2] max x[2,0] max x[0,-2] max"   \
                                              +" A@ x[0,0] - {thr} scaleb > x[0,0] {thr} scaleb + A ?"                                                                                                          : \
                                              Assert (false, "Unsupported Mode.") )
    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }



function ex_inpand(clip a, string "mode", int "thres", int "UV") {

    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, 0)

    str = mode == "cross"  ? Format("x[0,0] x[0,-1] min x[0,1] min x[-1,0] min x[1,0] min A@ x[0,0] - abs {thr} scaleb > x[0,0] {thr} scaleb - A ?") : \
          mode == "square" ? Format("x[0,0] x[-1,1] min x[0,1] min x[1,1] min x[-1,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min"             \
                                 +" A@ x[0,0] - abs {thr} scaleb > x[0,0] {thr} scaleb - A ?")                                                       : \
                                 Assert (false, "Unsupported Mode.")

    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }



# WIP implement thresholding and sharpen mode
function ex_edge(clip a, string "kernel", string "mode", int "str", int "thres", int "UV") {

    UV     = Default(UV, 0)
    kernel = Default(kernel, "sobel")
    mode   = Default(mode, "edge")    # "edge": for edge detection, or "sharpen": for sharpening
    str    = Default(str, 2)
    thres  = Default(thres, 0.25)

    str = Format(                                                                                                                                                                                                \
          kernel=="prewitt" ? "x[-1,0] x[-1,1] + x[1,1] - x[1,0] - x[1,-1] - x[-1,-1] + 2 ^ "                                                                                                                    \
                             +"x[-1,1] x[0,1] + x[1,1] + x[1,-1] - x[0,-1] - x[-1,-1] - 2 ^ * sqrt"                                                                                                            : \
          kernel=="sobel"   ? "x[-1,0] 2 * x[-1,1] x[1,1] x[1,0] 2 * x[1,-1] x[-1,-1] + - - - + 2 ^ "                                                                                                            \
                             +"x[-1,0] x[-1,1] x[0,1] 2 * x[1,1] x[1,-1] x[0,-1] 2 * x[-1,-1] + + + - - - 2 ^ * sqrt"                                                                                          : \
          kernel=="LoG"     ? "x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] + + + + + + + + + + + x[0,0] 16 * -"                                : \
          kernel=="DoG"     ? "x[0,0] 2 * x[0,1] x[-1,0] x[1,0] x[0,-1] + + + + 6 / A@ x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] x[0,0] 4 * "  \
                             +"+ + + + + + + + + + + + 20 / B@ - abs {thres} scaleb > A B - {str} * A ?"                                                                                                       : \
          kernel=="Roberts" ? "x[0,0] x[1,-1] - 2 ^ x[1,0] x[0,-1] - 2 ^ + sqrt {str} *"                                                                                                                       : \
          kernel=="Laplace" ? "x[0,0] 8 * x[-1,1] - x[0,1] - x[1,1] - x[-1,0] - x[1,0] - x[-1,-1] - x[0,-1] - x[1,-1] - {str} *"                                                                               : \
                             Assert (false, "Unsupported Kernel.") )

    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }


# Use removegrain(1) as it's faster
function ex_undot(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, 0)

    str = Format("x x[-{rd},{rd}] x[0,{rd}] min x[{rd},{rd}] x[-{rd},0] min min x[{rd},0] x[-{rd},-{rd}] min x[0,-{rd}] x[{rd},-{rd}] min min min " \
                  +"x[-{rd},{rd}] x[0,{rd}] max x[{rd},{rd}] x[-{rd},0] max max x[{rd},0] x[-{rd},-{rd}] max x[0,-{rd}] x[{rd},-{rd}] max max max clip")
    ch = ex_UVchannel(a, str, UV)
    Expr(a, str, ch) }




# HELPER Chroma Function

function ex_UVchannel(clip a, string str, int "UV") {

    UV = Default(UV, 0)

    str = ReplaceStr(str, "ymax", "cmax")

    str = UV == 0   ? Undefined   : \
          UV == 1   ? ""          : \
          UV == 2   ? "x"         : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 128 ? "range_half": \
          string(UV)+" scaleb"

    return str }