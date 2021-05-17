###########################################################
###                                                      ##
###                                                      ##
###           ExTools v1.0b  (17-05-2021)                ##
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


# Need to fix the TV range, PC range thing
function ex_blend(clip a, clip b, string mode, float "opacity", int "UV") {

    mode = Default(mode, 0)
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
    ch = ex_UVchannel(a, ReplaceStr(str,"ymax","cmax"), UV)
    Expr(a, b, str, ch) }




## Convolutions

function ex_boxblur(clip a, int radius, int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, 0)

    str = Format("x[0,-{rd}] x[0,0] x[0,{rd}] + + 3 /")
    ch = ex_UVchannel(a, str, UV)
    Expr(a, str, ch)

    str = Format("x[-{rd},0] x[0,0] x[{rd},0] + + 3 /")
    ch = ex_UVchannel(a, str, UV)
    Expr(last, str, ch)  }


function ex_expand(clip a, int radius, int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, 0)

    str = Format("x[0,0] x[0,-{rd}] x[0,{rd}] x[-{rd},0] x[{rd},0] + + + +")
    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }


function ex_inpand(clip a, int "UV") {

    UV = Default(UV, 0)

    str = "x[0,0] x[0,-1] x[0,1] x[-1,0] x[1,0] min min min min"
    ch = ex_UVchannel(a, str, UV)

    Expr(a, str, ch) }


function ex_undot(clip a, int radius, int "UV") {

    rd = Default(radius, 1)
    UV = Default(UV, 0)

    str = Format("x x[-{rd},{rd}] x[0,{rd}] min x[{rd},{rd}] x[-{rd},0] min min x[{rd},0] x[-{rd},-{rd}] min x[0,-{rd}] x[{rd},-{rd}] min min min " \
                  +"x[-{rd},{rd}] x[0,{rd}] max x[{rd},{rd}] x[-{rd},0] max max x[{rd},0] x[-{rd},-{rd}] max x[0,-{rd}] x[{rd},-{rd}] max max max clip")
    ch = ex_UVchannel(a, str, UV)
    Expr(a, str, ch) }



# HELPER Function

function ex_UVchannel(clip c, string str, int "UV") {

    UV = Default(UV, 0)

    str = UV == 0   ? Undefined   : \
          UV == 1   ? ""          : \
          UV == 2   ? "x"         : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 128 ? "range_half": \
          string(UV)+" scaleb"

    return str }