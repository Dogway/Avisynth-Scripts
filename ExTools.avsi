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

    UV = Default(UV, isy(a) ? 0 : 1)

    str = "x y - range_half +"

    UV == 0 ? Expr(a, b, str)                            : \ 
              Expr(a, b, str, ex_UVchannel(a, str, UV)) }


function ex_adddiff(clip a, clip b, int "UV") {

    UV = Default(UV, isy(a) ? 0 : 1)

    str = "x y + range_half -"

    UV == 0 ? Expr(a, b, str)                            : \ 
              Expr(a, b, str, ex_UVchannel(a, str, UV)) }


function ex_merge(clip a, clip b, clip msk, int "UV") {

    UV = Default(UV, isy(a) ? 0 : 1)

    str = "x range_max z - * y z * + range_max /"

    UV == 0 ? Expr(a, b, msk, str)                            : \ 
              Expr(a, b, msk, str, ex_UVchannel(a, str, UV)) }


# Add undershoot and overshoot
function ex_clamp(clip a, clip lo, clip hi, int "UV") {

    UV = Default(UV, isy(a) ? 0 : 1)

    str = Format(" x z < z x y > y x ? ?")

    UV == 0 ? Expr(a, lo, hi, str)                            : \ 
              Expr(a, lo, hi, str, ex_UVchannel(a, str, UV)) }


function ex_binarize(clip a, int "thres", int "UV") {

    UV = Default(UV, isy(a) ? 0 : 1)
    th = Default(thres, 128)

    str = Format("x {th} scaleb > range_max range_min ?")

    UV == 0 ? Expr(a, str)                            : \ 
              Expr(a, str, ex_UVchannel(a, str, UV)) }


function ex_invert(clip a, int "UV") {

    UV = Default(UV, isy(a) ? 0 : 1)

    str = "range_max x -"

    UV == 0 ? Expr(a, str)                            : \ 
              Expr(a, str, ex_UVchannel(a, str, UV)) }


# mt_lutspa() is x5 times faster
function ex_lutspa(clip a, string "mode", string "str", int "UV") {

    UV   = Default(UV, 0)
    mode = Default(mode, "absolute")
    str  = Default(str, "x")

    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported Mode.")

    UV == 0 ? Expr(a, str)                            : \ 
              Expr(a, str, ex_UVchannel(a, str, UV)) }



# Need to fix the TV range, PC range thing
function ex_blend(clip a, clip b, string "mode", float "opacity", int "UV", bool "tv_range") {

    mode  = Default(mode, "blend")
    op    = Default(opacity, 1.0)
    UV    = Default(UV, 0)
    range = Default(tv_range, true)  # TV or PC. Luma range of your source


    rangePC  = range ? "ymin - ymax ymin - /" : "range_max /"
    rangeTV  = range ? "ymax ymin - * ymin +" : "range_max *"

    str = Format(                                                                                                          \
        mode == "blend"        ? "x "+rangePC+" 1 {op} / ^ "+rangeTV+""                                                  : \
        mode == "multiply"     ? "x ymin - A@ y ymin - * ymax ymin - / {op} * A 1 {op} - * + ymin + "                    : \
        mode == "screen"       ? "1 1 x "+rangePC+" - - 1 y "+rangePC+" - * "+rangeTV+""                                  : \
        mode == "linear dodge" ? "x "+rangePC+" {op} * y "+rangePC+" 1 {op} - * + "+rangeTV+""                            : \
        mode == "add"          ? "x "+rangePC+" {op} * y "+rangePC+" 1 {op} - * + "+rangeTV+""                            : \
        mode == "softlight"    ? "1 2 y "+rangePC+" A@ * - x "+rangePC+" B@ 2 ^ * 2 B A * * + "+rangeTV+""                : \
                                 Assert (false, "Unsupported Blend Mode.") )

    UV == 0 ? Expr(a, b, str)                            : \ 
              Expr(a, b, str, ex_UVchannel(a, str, UV)) }




## Convolutions
# Convolutions kernels have 3 aspects; kernel size, kernel shape, and weight. Only kernel size is fixed in for the moment until I code a string recursion function.
# * Note: radius isn't making the kernel bigger, but further apart, test results before using rad > 1

# Similar but faster than: removegrain(19), blur(1.58) or mt_convolution("1 1 1","1 1 1")
function ex_boxblur(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, isy(a) ? 0 : 1)

    str = Format("x[0,-{rd}] x[0,0] x[0,{rd}] + + 3 /")

    UV == 0 ? Expr(a, str)                               : \ 
              Expr(a, str, ex_UVchannel(a, str, UV))

    str = Format("x[-{rd},0] x[0,0] x[{rd},0] + + 3 /")

    UV == 0 ? Expr(last, str)                            : \ 
              Expr(last, str, ex_UVchannel(a, str, UV)) }



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

    UV == 0 ? Expr(a, str)                            : \ 
              Expr(a, str, ex_UVchannel(a, str, UV)) }



function ex_inpand(clip a, string "mode", int "thres", int "UV") {

    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV, 0)

    str = mode == "cross"  ? Format("x[0,0] x[0,-1] min x[0,1] min x[-1,0] min x[1,0] min A@ x[0,0] - abs {thr} scaleb > x[0,0] {thr} scaleb - A ?") : \
          mode == "square" ? Format("x[0,0] x[-1,1] min x[0,1] min x[1,1] min x[-1,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min"             \
                                 +" A@ x[0,0] - abs {thr} scaleb > x[0,0] {thr} scaleb - A ?")                                                       : \
                                 Assert (false, "Unsupported Mode.")

    UV == 0 ? Expr(a, str)                            : \ 
              Expr(a, str, ex_UVchannel(a, str, UV)) }



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

    UV == 0 ? Expr(a, str)                            : \ 
              Expr(a, str, ex_UVchannel(a, str, UV)) }
    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }


# Use removegrain(1) as it's faster
function ex_undot(clip a, int "radius", int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, isy(a) ? 0 : 1)

    str = Format("x x[-{rd},{rd}] x[0,{rd}] min x[{rd},{rd}] x[-{rd},0] min min x[{rd},0] x[-{rd},-{rd}] min x[0,-{rd}] x[{rd},-{rd}] min min min " \
                  +"x[-{rd},{rd}] x[0,{rd}] max x[{rd},{rd}] x[-{rd},0] max max x[{rd},0] x[-{rd},-{rd}] max x[0,-{rd}] x[{rd},-{rd}] max max max clip")
    ch = ex_UVchannel(a, str, UV)

    UV == 0 ? Expr(a, str)     : \
              Expr(a, str, ch) }




# HELPER Chroma Function

function ex_UVchannel(clip a, string str, int "UV") {

    UV = Default(UV, 0)

    bdpth = BitsPerComponent(a) == 32
    bd    = bdpth ? 0.5 : 0

    str = bdpth ? ReplaceStr(ReplaceStr(ReplaceStr(ReplaceStr(" "+str+" ", "ymax", "cmax 0.5 +"), " x", " x 0.5 +"), " y", " y 0.5 +"), " z", " z 0.5 +") : \
                             ReplaceStr(    str, "ymax", "cmax")

    # Undefined "0" is the same as "" (when not single planed)
    str = UV == 0   ? ""          : \
          UV == 1   ? ""          : \
          UV == 2   ? "x"         : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 128 ? "range_half": \
          string(UV+bd)+" scaleb"

    return str }