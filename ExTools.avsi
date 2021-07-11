###########################################################
###                                                      ##
###                                                      ##
###           ExTools v3.5     (11-07-2021)              ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###      https://forum.doom9.org/showthread.php?t=182881 ##
###                                                      ##
###########################################################
###
### Pack of masktools2/removegrain replacement functions with...
### internal Expr() and some extra features.
### Generally works faster in HBD, but slower in 8-bit.
### See performance notes (benchmarks on 1080p@16-bit).
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


function ex_makeadddiff(clip a, clip b, clip "c", int "Y", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    isc = Defined(c)
    bi  = BitsPerComponent(a)

    Y   = Default(Y,         3)
    UV  = Default(UV,  rgb ? 3 : 1)
    fs  = Default(fulls, false)

    str = isc ? "x y - z +" : "x y - x +"

    ystr = ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isc     ?                                                           \
    isy     ? Expr(a, b, c, ystr                                    ) : \
    UV == 1 ? Expr(a, b, c, ystr, ""                                ) : \
              Expr(a, b, c, ystr, cstr, scale_inputs=ex_UVf(rgb, bi)) : \
    isy     ? Expr(a, b,    ystr                                    ) : \
    UV == 1 ? Expr(a, b,    ystr, ""                                ) : \
              Expr(a, b,    ystr, cstr, scale_inputs=ex_UVf(rgb, bi)) }


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
                          Assert (false, "Unsupported logic mode.")

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


# mt_binarize() is 12% slower than ex_binarize()
# mt_binarize() is 17% faster than ex_binarize(smooth=true)
# lo=-1 | hi=-1 replaces lo|hi with source "x"
function ex_binarize(clip a, int "thres", bool "invert", bool "smooth", int "lo", int "hi", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    th = Default(thres, 128)
    lo = Default(lo,   0)
    hi = Default(hi, 255)
    in = Default(invert, false)
    sm = Default(smooth, false)
    UV = Default(UV, rgb ? 3 : 1)
    fs = Default(fulls,  false)

    lo < 0 && hi < 0 ? Assert (false, "'lo' or 'hi': At least one bound should be binarized.") : nop()

    th = ex_bs(th, bi, fs)

    if (sm) {

        thl = round(th * 0.9)
        thh = round(th * 1.1)
        thm = 1. / (thh - thl)
        mx  = ex_bs(255, bi, fs)

        sub = Format(lo < 0 ? in ? "B@ {thl} < B x ?" : \
                                   "B@ {thh} > B x ?" : \
                     hi < 0 ? in ? "B@ {thl} < x B ?" : \
                                   "B@ {thh} > x B ?" : \
                                   ""                 )
        lo  = lo < 0 ? 0  : ex_bs(lo, bi, fs)
        hi  = hi < 0 ? mx : ex_bs(hi, bi, fs)
        olo = lo == 0  ? ""  :      "A@ * 0 max"
        ohi = hi == mx ? "*" : in ? "A@ * A max" : "A@ * A min"

        str = Format(in ? "x {thl} - "+olo+" {thm} * {lo} {hi} - "+ohi+" {hi} + "        : \
                          "x {thl} - "+olo+" {thm} * {hi} {lo} - "+ohi+" {lo} + " ) + sub

    } else {

        lo = lo < 0 ? "x" : string(ex_bs(lo, bi, fs))
        hi = hi < 0 ? "x" : string(ex_bs(hi, bi, fs))

        str = Format(in ? "x {th} < "+hi+" "+lo+" ?" : \
                          "x {th} > "+hi+" "+lo+" ?")
    }

    str  = ex_dlut  (str,     bi,      fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ?  Expr(a, str                                    ) : \
    UV == 1 ?  Expr(a, str, ""                                ) : \
               Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi))

    sm ? ex_blur(0.5, UV=UV, fulls=fulls) : last }


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
                             Assert (false, "Unsupported lutspa mode.")

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
                                     Assert (false, "Unsupported blend mode.")
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
                                     Assert (false, "Unsupported blend mode.") )
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
# modes:
# mean     average: mean average of a square kernel with equal weight per component
# bokeh    average: mean average of a ring   kernel with equal weight per component
# rg19     average: mean average of a square kernel with equal weight per component except central pixel (weight = 0) -matches removegrain(19)-
# weighted average: mean average of a square kernel with custom local weights per component (commonly used for a Gaussian approximations; blur(1), removegrain(12), etc)
# trimmed  average: mean average of a square kernel with equal weight per component limited by its closest median (undot4 algo)
#
function ex_boxblur(clip a, int "radius", int "radiusV", string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to inf
    rv = Default(radiusV, rd)           # from 0 to inf

    fbox = rd == 1 && rv == 1

    UV = Default(UV, rgb ? 3 : 1)
    md = Default(mode,  fbox ? "rg19" : "mean")
    fs = Default(fulls, false)
    rd = max(rd, 1)
    rv = max(rv, 1)

    md == "trimmed" ? Assert (fbox, "'Trimmed' mode only supports radius=1")           : nop()
    md == "bokeh"   ? Assert (rd == rv, "'Bokeh' mode only supports isotropic radius") : nop()

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krnh = ""  krnv = ""  plsh = ""  plsv = ""  divx=0  divy=0  divw=0
    if (md == "bokeh") {

        for (px = -krnlrd, krnlrd, 1) {
                for (py = -krnlrd, krnlrd, 1) {
                    rad   = cos(2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py))))
                    skipo =  px != 0 &&                       abs(px) >  krnlrd   *rad
                    skipi = (px != 0 || abs(py) == krnlrd) && abs(px) > (krnlrd-1)*rad
                    krnv = skipo || !skipi                  ? krnv : Format(krnv + "x[{px},{py}] ")
                    plsv = skipo || !skipi || py == -krnlrd ? plsv : plsv + "+ "
                    divy = skipo || !skipi                  ? divy : divy + 1
           }      }

    } else if (!fbox) {

        for (px = -krnlrd, krnlrd, 1) {
            wg   = md == "weighted" ? px == 0 ? krnlrd*2 : krnlrd / float(abs(px)) : nop()
            krnh = md == "rg19" && px == 0 ? krnh : \
                   md == "weighted"        ? Format(krnh + "x[{px},0] {wg} * ") : \
                                             Format(krnh + "x[{px},0] ")
            plsh = px == -krnlrd || (md == "rg19" && px == 0) ? plsh : plsh + "+ "
            divw = md == "weighted" ? divw + wg : nop()
            divx = md == "rg19" &&    px == 0 ? divx  : \
                   md == "weighted"           ? divw  : divx + 1
           }

        krnlsz = 2 * rv + 1
        krnlrv = krnlsz/2
        divw=0
        for (py = -krnlrv, krnlrv, 1) {
            wg   = md == "weighted" ? py == 0 ? krnlrv*2 : krnlrv / float(abs(py)) : nop()
            krnv = md == "rg19" && py == 0 ? krnv : \
                   md == "weighted"        ? Format(krnv + "x[0,{py}] {wg} * ") : \
                                             Format(krnv + "x[0,{py}] ")
            plsv = py == -krnlrv || (md == "rg19" && py == 0) ? plsv : plsv + "+ "
            divw = md == "weighted" ? divw + wg : nop()
            divy = md == "rg19" &&    py == 0 ? divy  : \
                   md == "weighted"           ? divw  : divy + 1
           }
   }

    str = fbox ? md == "rg19"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + 0.125 *"                                       : \
                 md == "bokeh"    ?"x[0,1] x[-1,0] x[1,0] x[0,-1] + + + 0.250 *"                                                                               : \
                 md == "mean"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[0,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 0.111111111 *"                        : \
                 md == "weighted" ?"x[-1,1] 0.5 * x[0,1] x[1,1] 0.5 * x[0,0] 2 * x[-1,0] x[1,0] x[-1,-1] 0.5 * x[0,-1] x[1,-1] 0.5 * + + + + + + + + 0.125 * " : \
                 md == "trimmed"  ?"x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[0,0] E@ x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ "                            \
                                  +"+ + + + + + + + 0.111111111 * X^ "                                                                                           \
                                  +"A D dup1 dup1 min AA^ max DD^ B H dup1 dup1 min BB^ max HH^ C F dup1 dup1 min CC^ max FF^ E I dup1 dup1 min EE^ max II^ "    \
                                  +"AA HH dup1 dup1 min A^ max H^ CC EE dup1 dup1 min C^ max E^ DD II dup1 dup1 min D^ max I^ FF G dup1 dup1 min F^ max GG^ "    \
                                  +"A C dup1 dup1 min AA^ max CC^ BB D dup1 dup1 min B^ max DD^ E F dup1 dup1 min EE^ max FF^ H I dup1 dup1 min HH^ max II^ "    \
                                  +"B EE dup1 dup1 min BB^ max E^ DD GG dup1 dup1 min D^ max G^ FF HH dup1 dup1 min F^ max H^ "                                  \
                                  +"AA BB dup1 dup1 min A^ max B^ CC E dup1 dup1 min C^ max EE^ D F dup1 dup1 min DD^ max FF^ G II dup1 dup1 min GG^ max I^ "    \
                                  +"C DD dup1 dup1 min CC^ max D^ EE FF dup1 dup1 min E^ max F^ D E dup1 dup1 min DD^ max EE^ "                                  \
                                  +"X DD F clip" : "" : krnv + plsv + string(1. / divy) + " *"


    strv = fbox || mode=="bokeh" ? str : krnv + plsv + string(1. / divy) + " *"
    strh =                               krnh + plsh + string(1. / divx) + " *"

    rv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 || fbox || mode=="bokeh"  ? last                                          : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }


# Variable Gaussian Blur
#
# Benchmark:
# 100% removegrain(12,-1)          # technically a weighted mean of [1 2 1]
#  96% ex_blur(1,UV=1)             # true gaussian blur
#  94% BinomialBlur(0.75,U=1,V=1)  # only in 8-bit
#  84% ablur(1, 1)                 # against ex_blur(2)
#  70% blur(1.00)                  # weighted mean of [1 2 1]
#  66% generalconvolution(matrix="0 1 0 1 2 1 0 1 0",6,chroma=false) doesn't match output tho
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#  21% GBlur(rad=1,sd=1.0,u=false,v=false)
#  15% FastBlur(0.75,gamma=false)
#  10% GaussianBlur(0.75,U=1,V=1)  # only in 8-bit
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

    krnv = ""    krnh = ""
    for (i=0, krnlsz, 1) {

        k_f = factorial(i)*factorial(krnlsz-i)
        wg  = (n_f/k_f)/pow(2,krnlsz)
        py  = i - krnlsz/2
        krnv = Format(krnv + "x[0,{py}] {wg} * ")
        plsv = i == 0 ? "" : plsv + "+ "
       }

    krnlszh = 2*ceil(3*sm)
    n_f     = factorial(krnlszh)

    for (i=0, krnlszh, 1) {

        k_f = factorial(i)*factorial(krnlszh-i)
        wg  = (n_f/k_f)/pow(2,krnlszh)
        px  = i - krnlszh/2
        krnh = Format(krnh + "x[{px},0] {wg} * ")
        plsh = i == 0 ? "" : plsh + "+ "
       }

    strv = fkern    ?   "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] 2 * x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 0.1 *" : \
           fkern2   ?   "x[0,1] x[-1,0] x[0,0] 3 * x[1,0] x[0,-1] + + + + 0.142857143 *"                                 : \
           sv==0.3  ?   "x[0,1]  x[0,0] 2 * x[0,-1] + + 0.25 *"                                                          : \
           sv==0.15 ?   "x[0,1]  x[0,0] 3 * x[0,-1] + + 0.20 *"                                                          : \
           sv==0.0  ?   "x"                                                                                              : \
                         krnv + plsv
    strh = sm==0.3  ?   "x[-1,0] x[0,0] 2 * x[1,0]  + + 0.25 *"                                                          : \
           sm==0.15 ?   "x[-1,0] x[0,0] 3 * x[1,0]  + + 0.20 *"                                                          : \
           sm==0.0  ?   "x"                                                                                              : \
                         krnh + plsh


    p_4 = is444(a)    p_1 = isYV411(a)
    p_2 = is422(a)    p_0 = is420(a)

    cstrv = ""    cstrh = ""
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



# Savitzky-Golay (S-G) smoothing filter (similar to Gaussian blur)
function ex_smooth(clip a, int "radius", int "radiusV", bool "sharp", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to 3
    rv = Default(radiusV, rd)           # from 0 to 3
    UV = Default(UV, rgb ? 3 : 1)
    sh = Default(sharp, false)
    fs = Default(fulls, false)
    rd = max(rd, 1)
    rv = max(rv, 1)

    rd == 3 || rv == 3 ? Assert (!sh, "Sharp mode only for radius < 3") : nop()

    if (!sh) {

    # Quadratic/Cubic (2nd and 3rd degree polynomials)
    strv = rv == 1 ? "x[0,1] 4 * x[0,0] 5.666666666 * x[0,-1] 4 * + + x[0,-2] - x[0,2] - 0.085714286 *"                                                                                        : \
           rv == 2 ? "x[0,2] x[0,1] 2 * x[0,0] 2.333333333 * x[0,-1] 2 * x[0,-2] + + + + x[0,-3] 0.666666666 * - x[0,3] 0.666666666 * - 0.142857143 *"                                         : \
           rv == 3 ? "x[0,3] 4.666666666 * x[0,2] 13 * x[0,1] 18 * x[0,0] 19.666666666 * x[0,-1] 18 * x[0,-2] 13 * x[0,-3] 4.666666666 * + + + + + + x[0,-4] 7 * - x[0,4] 7 * - 0.012987013 *" : \
                     "x"

    strh = rd == 1 ? "x[-1,0] 4 * x[0,0] 5.666666666 * x[1,0] 4 * + + x[2,0] - x[-2,0] - 0.085714286 *"                                                                                        : \
           rd == 2 ? "x[-2,0] x[-1,0] 2 * x[0,0] 2.333333333 * x[1,0] 2 * x[2,0] + + + + x[3,0] 0.666666666 * - x[-3,0] 0.666666666 * - 0.142857143 *"                                         : \
           rd == 3 ? "x[-3,0] 4.666666666 * x[-2,0] 13 * x[-1,0] 18 * x[0,0] 19.666666666 * x[1,0] 18 * x[2,0] 13 * x[3,0] 4.666666666 * + + + + + + x[4,0] 7 * - x[-4,0] 7 * - 0.012987013 *" : \
                     "x"
    } else {

    # Quartic/Quintic (4th and 5th degree polynomials) (sharper)
    strv = rv == 1 ? "x[0,3] x[0,-3] x[0,1] 15 * x[0,0] 26.2 * x[0,-1] 15 * + + + + x[0,-2] 6 * - x[0,2] 6 * - 0.021645022 *"                                                                  : \
           rv == 2 ? "x[0,4] x[0,-4] x[0,2] 2 * x[0,1] 9 * x[0,0] 11.933333333 * x[0,-1] 9 * x[0,-2] 2 * + + + + + + x[0,-3] 3.666666666 * - x[0,3] 3.666666666 * - 0.034965035 *"             : \
                     "x"

    strh = rd == 1 ? "x[-3,0] x[3,0] x[-1,0] 15 * x[0,0] 26.2 * x[1,0] 15 * + + + + x[2,0] 6 * - x[-2,0] 6 * - 0.021645022 *"                                                                  : \
           rd == 2 ? "x[-4,0] x[4,0] x[-2,0] 2 * x[-1,0] 9 * x[0,0] 11.933333333 * x[1,0] 9 * x[2,0] 2 * + + + + + + x[3,0] 3.666666666 * - x[-3,0] 3.666666666 * - 0.034965035 *"             : \
                     "x"
    }

    rv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 ? last                                                                    : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }



##############################
##
## Median Blur
##
## Requires AviSynth+ 3.7.1
##
## 100% removegrain(1,-1)
##  83% ex_median(mode="undot",UV=1)
##
## 100% removegrain(2,-1)
##  65% ex_median(mode="undot2",UV=1)
##
##  100% removegrain(4,-1)
##   64% ex_median(mode="undot4",UV=1)
##  1.2% MedianBlur(1,0,0)
## 0.06% mt_luts(last, "med", mt_square(1), "y",chroma="-1")
#
# modes:
# median    - True median. Replace with kernel middle value
# median5   - True median. Replace with kernel middle value (5x5 kernel) (very slow)
# undot     - Also called "conservative", removes one pixel salt'n'pepper noise -removegrain(1)-
# undot2    - Same as undot but clip up to the second closest minimum values -removegrain(2)-
# undot3    - Same as undot but clip up to the third  closest minimum values -removegrain(3)-
# undot4    - Same as undot but clip up to the fourth closest minimum values -removegrain(4)-
# SNN       - Symmetric Nearest Neighbour. Clip to closest opposing pair from center value
# kuwahara  - Mean average of the least variance quadrant in a 5x5 kernel window. (oil paint look)
# pseudo    - Pseudo median. Replace with the average of the maximum of the minima and the minimum of the maxima of the sliding window
# weightedp - 50% weighted percentile weighted median (commonly same than "median" but much slower)
# weightedm - mean average weighted median
# cartoon   - Clipping is done with respect to averages of neighbours. Best for cartoons -removegrain(22)-
# edgeS     - Edge sensitive. Same as mode 4 but better edge protection. Strong denoise  -removegrain(17)-
# edgeW     - Edge sensitive. Only line pairs are used.                    Weak denoise  -removegrain(18)-


function ex_median(clip a, string "mode", bool "pcorner", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    mode = Default(mode, "median")
    UV   = Default(UV, rgb ? 3 : 1)
    pc   = Default(pcorner, false)
    fs   = Default(fulls,   false)

    Assert(IsVersionOrGreater(3,7,1), "Update AviSynth+ version to 3.7.1+")

    str =                                                                                                                                                             \
        mode == "median" ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[0,0] E^ x[1,0] F^ x[-1,-1] G^ x[0,-1] H^ x[1,-1] I^ "                                         \
                          +"A D   dup1 dup1 min AA^ max DD^ "                                                                                                         \
                          +"B H   dup1 dup1 min BB^ max HH^ "                                                                                                         \
                          +"C F   dup1 dup1 min CC^ max FF^ "                                                                                                         \
                          +"E I   dup1 dup1 min EE^ max II^ "                                                                                                         \
                          +"AA HH dup1 dup1 min A^  max H^  "                                                                                                         \
                          +"CC EE dup1 dup1 min C^  max E^  "                                                                                                         \
                          +"DD II dup1 dup1 min D^  max I^  "                                                                                                         \
                          +"FF G  dup1 dup1 min F^  max GG^ "                                                                                                         \
                          +"A C   dup1 dup1 min AA^ max CC^ "                                                                                                         \
                          +"BB D  dup1 dup1 min B^  max DD^ "                                                                                                         \
                          +"E F   dup1 dup1 min EE^ max FF^ "                                                                                                         \
                          +"H I   dup1 dup1 min HH^ max II^ "                                                                                                         \
                          +"B EE  dup1 dup1 min BB^ max E^  "                                                                                                         \
                          +"DD GG dup1 dup1 min D^  max G^  "                                                                                                         \
                          +"FF HH dup1 dup1 min F^  max H^  "                                                                                                         \
                          +"AA BB dup1 dup1 min A^  max B^  "                                                                                                         \
                          +"CC E  dup1 dup1 min C^  max EE^ "                                                                                                         \
                          +"D F   dup1 dup1 min DD^ max FF^ "                                                                                                         \
                          +"G II  dup1 dup1 min GG^ max I^  "                                                                                                         \
                          +"C DD  dup1 dup1 min CC^ max D^  "                                                                                                         \
                          +"EE FF dup1 dup1 min E^  max F^  "                                                                                                         \
                          +"D E   dup1 dup1 min DD^ max EE^ "                                                                                                         \
                          +"EE"                                                                                                                                     : \
                                                                                                                                                                      \
        mode == "median5"? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ x[0,0] M^ " \
                          +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] Q^ x[0,-1] R^ x[1,-1] S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] X^ x[1,-2] Y^ x[2,-2] Z^ "   \
                          +"A C dup1 dup1 min AA^ max CC^ B I dup1 dup1 min BB^ max II^ D S dup1 dup1 min DD^ max SS^ E R dup1 dup1 min EE^ max RR^ F U dup1 dup1 min FF^ max UU^ G T dup1 dup1 min GG^ max TT^ H J dup1 dup1 min HH^ max JJ^ K L dup1 dup1 min KK^ max LL^ M N dup1 dup1 min MM^ max NN^ O Q dup1 dup1 min OO^ max QQ^ P X dup1 dup1 min PP^ max XX^ V Y dup1 dup1 min VV^ max YY^ " \
                          +"AA DD dup1 dup1 min A^ max D^ BB PP dup1 dup1 min B^ max P^ CC SS dup1 dup1 min C^ max S^ EE MM dup1 dup1 min E^ max M^ FF VV dup1 dup1 min F^ max V^ GG KK dup1 dup1 min G^ max K^ HH OO dup1 dup1 min H^ max O^ II XX dup1 dup1 min I^ max X^ JJ QQ dup1 dup1 min J^ max Q^ LL TT dup1 dup1 min L^ max T^ NN RR dup1 dup1 min N^ max R^ UU YY dup1 dup1 min U^ max Y^ " \
                          +"A E dup1 dup1 min AA^ max EE^ B H dup1 dup1 min BB^ max HH^ C N dup1 dup1 min CC^ max NN^ D M dup1 dup1 min DD^ max MM^ F G dup1 dup1 min FF^ max GG^ I O dup1 dup1 min II^ max OO^ J P dup1 dup1 min JJ^ max PP^ K V dup1 dup1 min KK^ max VV^ L U dup1 dup1 min LL^ max UU^ Q X dup1 dup1 min QQ^ max XX^ R S dup1 dup1 min RR^ max SS^ T Y dup1 dup1 min TT^ max YY^ " \
                          +"AA FF dup1 dup1 min A^ max F^ CC LL dup1 dup1 min C^ max L^ DD GG dup1 dup1 min D^ max G^ EE KK dup1 dup1 min E^ max K^ HH QQ dup1 dup1 min H^ max Q^ II JJ dup1 dup1 min I^ max J^ MM VV dup1 dup1 min M^ max V^ NN TT dup1 dup1 min N^ max T^ OO PP dup1 dup1 min O^ max P^ RR UU dup1 dup1 min R^ max U^ SS YY dup1 dup1 min S^ max Y^ " \
                          +"C H dup1 dup1 min CC^ max HH^ G J dup1 dup1 min GG^ max JJ^ I LL dup1 dup1 min II^ max L^ O Z dup1 dup1 min OO^ max ZZ^ S V dup1 dup1 min SS^ max VV^ "                                                                                                                         \
                          +"D II dup1 dup1 min DD^ max I^ HH K dup1 dup1 min H^ max KK^ LL M dup1 dup1 min L^ max MM^ N OO dup1 dup1 min NN^ max O^ P VV dup1 dup1 min PP^ max V^ SS U dup1 dup1 min S^ max UU^ X ZZ dup1 dup1 min XX^ max Z^ "                                                             \
                          +"E NN dup1 dup1 min EE^ max N^ KK Q dup1 dup1 min K^ max QQ^ L PP dup1 dup1 min LL^ max P^ S Z dup1 dup1 min SS^ max ZZ^ T XX dup1 dup1 min TT^ max X^ "                                                                                                                         \
                          +"BB EE dup1 dup1 min B^ max E^ I LL dup1 dup1 min II^ max L^ JJ TT dup1 dup1 min J^ max T^ N R dup1 dup1 min NN^ max RR^ O SS dup1 dup1 min OO^ max S^ QQ UU dup1 dup1 min Q^ max U^ Y ZZ dup1 dup1 min YY^ max Z^ "                                                             \
                          +"A B dup1 dup1 min AA^ max BB^ E F dup1 dup1 min EE^ max FF^ GG NN dup1 dup1 min G^ max N^ J OO dup1 dup1 min JJ^ max O^ K RR dup1 dup1 min KK^ max R^ MM Q dup1 dup1 min M^ max QQ^ S T dup1 dup1 min SS^ max TT^ U V dup1 dup1 min UU^ max VV^ X YY dup1 dup1 min XX^ max Y^ " \
                          +"CC G dup1 dup1 min C^ max GG^ DD EE dup1 dup1 min D^ max E^ FF N dup1 dup1 min F^ max NN^ H JJ dup1 dup1 min HH^ max J^ M SS dup1 dup1 min MM^ max S^ P R dup1 dup1 min PP^ max RR^ QQ TT dup1 dup1 min Q^ max T^ UU XX dup1 dup1 min U^ max X^ VV Y dup1 dup1 min V^ max YY^ " \
                          +"BB C dup1 dup1 min B^ max CC^ F II dup1 dup1 min FF^ max I^ GG HH dup1 dup1 min G^ max H^ J KK dup1 dup1 min JJ^ max K^ L NN dup1 dup1 min LL^ max N^ O PP dup1 dup1 min OO^ max P^ RR U dup1 dup1 min R^ max UU^ V X dup1 dup1 min VV^ max XX^ "                               \
                          +"B D dup1 dup1 min BB^ max DD^ CC E dup1 dup1 min C^ max EE^ FF G dup1 dup1 min F^ max GG^ H LL dup1 dup1 min HH^ max L^ I JJ dup1 dup1 min II^ max J^ K N dup1 dup1 min KK^ max NN^ MM OO dup1 dup1 min M^ max O^ P Q dup1 dup1 min PP^ max QQ^ R S dup1 dup1 min RR^ max SS^ T UU dup1 dup1 min TT^ max U^ " \
                          +"C DD dup1 dup1 min CC^ max D^ EE II dup1 dup1 min E^ max I^ GG HH dup1 dup1 min G^ max H^ J M dup1 dup1 min JJ^ max MM^ KK L dup1 dup1 min K^ max LL^ NN O dup1 dup1 min N^ max OO^ PP RR dup1 dup1 min P^ max R^ QQ SS dup1 dup1 min Q^ max S^ U VV dup1 dup1 min UU^ max V^ " \
                          +"D F dup1 dup1 min DD^ max FF^ E G dup1 dup1 min EE^ max GG^ H II dup1 dup1 min HH^ max I^ JJ K dup1 dup1 min J^ max KK^ LL MM dup1 dup1 min L^ max M^ N P dup1 dup1 min NN^ max PP^ M NN dup1 dup1 min MM^ max N^ "                                                             \
                          +"MM"                                                                                                                                     : \
                                                                                                                                                                      \
        mode == "pseudo" ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ x[0,0] M^ " \
                          +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] Q^ x[0,-1] R^ x[1,-1] S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] X^ x[1,-2] Y^ x[2,-2] Z^ "   \
                          +"A B min C min F min G min H min K min L min M min C D min E min H min I min J min M min N min O min max "                                 \
                          +"K L min M min P min Q min R min U min V min X min M N min O min R min S min T min X min Y min Z min max max "                             \
                          +"A B max C max F max G max H max K max L max M max C D max E max H max I max J max M max N max O max min "                                 \
                          +"K L max M max P max Q max R max U max V max X max M N max O max R max S max T max X max Y max Z max min min + 0.5 *"                    : \
                                                                                                                                                                      \
        mode == "SNN"    ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ x[0,0] J^ "                                         \
                          +"A J - abs H J - abs + B J - abs G J - abs + < A R@ H S@ + B R@ G S@ + ? Z^ "                                                              \
                          +"C J - abs F J - abs + D J - abs E J - abs + < C T@ F U@ + D T@ E U@ + ? Z^ "                                                              \
                          +"R J - abs S J - abs + T J - abs U J - abs + < R R@ S S@ + T R@ U S@ + ? Z^ "                                                              \
                          +"J R S min R S max clip"                                                                                                                 : \
                                                                                                                                                                      \
        mode == "kuwahara"?"x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ x[0,0] M^ " \
                          +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] Q^ x[0,-1] R^ x[1,-1] S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] X^ x[1,-2] Y^ x[2,-2] Z^ "   \
                          +"A B C F G H K L M + + + + + + + + 0.111111111 * W^   C D E H I J M N O + + + + + + + + 0.111111111 * WW^ "                                \
                          +"K L M P Q R U V X + + + + + + + + 0.111111111 * WWW^ M N O R S T X Y Z + + + + + + + + 0.111111111 * WWWW^ "                              \
                          +"A W - dup * B W - dup * C W - dup * F W - dup * G W - dup * H W - dup * K W - dup * L W - dup * M W - dup * + + + + + + + + AA^ "         \
                          +"C WW - dup * D WW - dup * E WW - dup * H WW - dup * I WW - dup * J WW - dup * M WW - dup * N WW - dup * O WW - dup * + + + + + + + + BB^ "\
                          +"K WWW - dup * L WWW - dup * M WWW - dup * P WWW - dup * Q WWW - dup * R WWW - dup * U WWW - dup * V WWW - dup * X WWW - dup * + + + + + + + + CC^ " \
                          +"M WWWW - dup * N WWWW - dup * O WWWW - dup * R WWWW - dup * S WWWW - dup * T WWWW - dup * X WWWW - dup * Y WWWW - dup * Z WWWW - dup * + + + + + + + + DD^ " \
                          +"AA BB min CC DD min min EE^ EE AA == W EE BB == WW EE CC == WWW WWWW ? ? ?"                                                             : \
                                                                                                                                                                      \
        mode == "weightedp"?"x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[0,0] E^ x[1,0] F^ x[-1,-1] G^ x[0,-1] H^ x[1,-1] I^ "                                        \
                           +"A D   dup1 dup1 min AA^ max DD^ "                                                                                                        \
                           +"B H   dup1 dup1 min BB^ max HH^ "                                                                                                        \
                           +"C F   dup1 dup1 min CC^ max FF^ "                                                                                                        \
                           +"E I   dup1 dup1 min EE^ max II^ "                                                                                                        \
                           +"AA HH dup1 dup1 min A^  max H^  "                                                                                                        \
                           +"CC EE dup1 dup1 min C^  max E^  "                                                                                                        \
                           +"DD II dup1 dup1 min D^  max I^  "                                                                                                        \
                           +"FF G  dup1 dup1 min F^  max GG^ "                                                                                                        \
                           +"A C   dup1 dup1 min AA^ max CC^ "                                                                                                        \
                           +"BB D  dup1 dup1 min B^  max DD^ "                                                                                                        \
                           +"E F   dup1 dup1 min EE^ max FF^ "                                                                                                        \
                           +"H I   dup1 dup1 min HH^ max II^ "                                                                                                        \
                           +"B EE  dup1 dup1 min BB^ max E^  "                                                                                                        \
                           +"DD GG dup1 dup1 min D^  max G^  "                                                                                                        \
                           +"FF HH dup1 dup1 min F^  max H^  "                                                                                                        \
                           +"AA BB dup1 dup1 min A^  max B^  "                                                                                                        \
                           +"CC E  dup1 dup1 min C^  max EE^ "                                                                                                        \
                           +"D F   dup1 dup1 min DD^ max FF^ "                                                                                                        \
                           +"G II  dup1 dup1 min GG^ max I^  "                                                                                                        \
                           +"C DD  dup1 dup1 min CC^ max D^  "                                                                                                        \
                           +"EE FF dup1 dup1 min E^  max F^  "                                                                                                        \
                           +"GG H  dup1 dup1 min G^  max HH^ "                                                                                                        \
                           +"B CC  dup1 dup1 min BB^ max C^  "                                                                                                        \
                           +"D E   dup1 dup1 min DD^ max EE^ "                                                                                                        \
                           +"F G   dup1 dup1 min FF^ max GG^ "                                                                                                        \
                           +"A BB C + + A B C D E F G H I + + + + + + + + 0.5 * W@ - abs Z^ A BB C DD + + + W - abs Y^ A BB C DD EE + + + + W - abs X^ "              \
                           +"A BB C DD EE FF + + + + + W - abs V^ Z Y < C Y X < DD X Z < EE FF ? ? ? "                                                              : \
                                                                                                                                                                      \
        mode == "weightedm"?"x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[0,0] E^ x[1,0] F^ x[-1,-1] G^ x[0,-1] H^ x[1,-1] I^ "                                        \
                           +"A B C D E F G H I + + + + + + + + 0.111111111 * W^ "                                                                                     \
                           +" A W - abs B W - abs < A B ? Z@ W - abs C W - abs < Z C ? Y@ W - abs D W - abs < Y D ? X@ W - abs E W - abs < X E ? "                    \
                           +"V@ W - abs F W - abs < V F ? U@ W - abs G W - abs < U G ? T@ W - abs H W - abs < T H ? S@ W - abs I W - abs < S I ? "                  : \
                                                                                                                                                                      \
        mode == "undot"  ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                   \
                          +"x[0,0] A B min C min D min E min F min G min H min A B max C max D max E max F max G max H max clip"                                    : \
                                                                                                                                                                      \
        mode == "undot2" ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                   \
                          +"A C   dup1 dup1 min AA^ max CC^ "                                                                                                         \
                          +"B D   dup1 dup1 min BB^ max DD^ "                                                                                                         \
                          +"E G   dup1 dup1 min EE^ max GG^ "                                                                                                         \
                          +"F H   dup1 dup1 min FF^ max HH^ "                                                                                                         \
                          +"AA EE dup1 dup1 min A^  max E^  "                                                                                                         \
                          +"BB FF dup1 dup1 min B^  max F^  "                                                                                                         \
                          +"CC GG dup1 dup1 min C^  max G^  "                                                                                                         \
                          +"DD HH dup1 dup1 min D^  max H^  "                                                                                                         \
                          +"A B   dup1 dup1 min AA^ max BB^ "                                                                                                         \
                          +"C D   dup1 dup1 min CC^ max DD^ "                                                                                                         \
                          +"E F   dup1 dup1 min EE^ max FF^ "                                                                                                         \
                          +"G H   dup1 dup1 min GG^ max HH^ "                                                                                                         \
                          +"CC EE dup1 dup1 min C^  max E^  "                                                                                                         \
                          +"DD FF dup1 dup1 min D^  max F^  "                                                                                                         \
                          +"BB E  dup1 dup1 min B^  max EE^ "                                                                                                         \
                          +"D GG  dup1 dup1 min DD^ max G^  "                                                                                                         \
                          +"B C   dup1 dup1 min BB^ max CC^ "                                                                                                         \
                          +"F G   dup1 dup1 min FF^ max GG^ "                                                                                                         \
                          +"x[0,0] BB GG clip"                                                                                                                      : \
                                                                                                                                                                      \
        mode == "undot3" ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                   \
                          +"A C   dup1 dup1 min AA^ max CC^ "                                                                                                         \
                          +"B D   dup1 dup1 min BB^ max DD^ "                                                                                                         \
                          +"E G   dup1 dup1 min EE^ max GG^ "                                                                                                         \
                          +"F H   dup1 dup1 min FF^ max HH^ "                                                                                                         \
                          +"AA EE dup1 dup1 min A^  max E^  "                                                                                                         \
                          +"BB FF dup1 dup1 min B^  max F^  "                                                                                                         \
                          +"CC GG dup1 dup1 min C^  max G^  "                                                                                                         \
                          +"DD HH dup1 dup1 min D^  max H^  "                                                                                                         \
                          +"A B   dup1 dup1 min AA^ max BB^ "                                                                                                         \
                          +"C D   dup1 dup1 min CC^ max DD^ "                                                                                                         \
                          +"E F   dup1 dup1 min EE^ max FF^ "                                                                                                         \
                          +"G H   dup1 dup1 min GG^ max HH^ "                                                                                                         \
                          +"CC EE dup1 dup1 min C^  max E^  "                                                                                                         \
                          +"DD FF dup1 dup1 min D^  max F^  "                                                                                                         \
                          +"BB E  dup1 dup1 min B^  max EE^ "                                                                                                         \
                          +"D GG  dup1 dup1 min DD^ max G^  "                                                                                                         \
                          +"B C   dup1 dup1 min BB^ max CC^ "                                                                                                         \
                          +"F G   dup1 dup1 min FF^ max GG^ "                                                                                                         \
                          +"x[0,0] CC FF clip"                                                                                                                      : \
                                                                                                                                                                      \
        mode == "undot4" ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                   \
                          +"A C   dup1 dup1 min AA^ max CC^ "                                                                                                         \
                          +"B D   dup1 dup1 min BB^ max DD^ "                                                                                                         \
                          +"E G   dup1 dup1 min EE^ max GG^ "                                                                                                         \
                          +"F H   dup1 dup1 min FF^ max HH^ "                                                                                                         \
                          +"AA EE dup1 dup1 min A^  max E^  "                                                                                                         \
                          +"BB FF dup1 dup1 min B^  max F^  "                                                                                                         \
                          +"CC GG dup1 dup1 min C^  max G^  "                                                                                                         \
                          +"DD HH dup1 dup1 min D^  max H^  "                                                                                                         \
                          +"A B   dup1 dup1 min AA^ max BB^ "                                                                                                         \
                          +"C D   dup1 dup1 min CC^ max DD^ "                                                                                                         \
                          +"E F   dup1 dup1 min EE^ max FF^ "                                                                                                         \
                          +"G H   dup1 dup1 min GG^ max HH^ "                                                                                                         \
                          +"CC EE dup1 dup1 min C^  max E^  "                                                                                                         \
                          +"DD FF dup1 dup1 min D^  max F^  "                                                                                                         \
                          +"BB E  dup1 dup1 min B^  max EE^ "                                                                                                         \
                          +"D GG  dup1 dup1 min DD^ max G^  "                                                                                                         \
                          +"DD EE dup1 dup1 min D^  max E^  "                                                                                                         \
                          +"x[0,0] D E clip"                                                                                                                        : \
                                                                                                                                                                      \
        mode == "cartoon"? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                   \
                          +"x[0,0] A H + B G + min C F + min D E + min 0.5 * A H + B G + max C F + max D E + max 0.5 * clip"                                        : \
                                                                                                                                                                      \
        mode == "edgeS"  ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                   \
                          +"A H min B G min max C F min D E min max max L^ A H max B G max min C F max D E max min min U^ "                                           \
                          +"x[0,0] L U min L U max clip"                                                                                                            : \
                                                                                                                                                                      \
        mode == "edgeW"  ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ x[0,0] I^ "                                         \
                          +"I A - abs I H - abs max AA^ I B - abs I G - abs max BB^ I C - abs I F - abs max CC^ I D - abs I E - abs max DD^ "                         \
                          +"AA BB min CC DD min min X^  "                                                                                                             \
                          +"X AA == I A H min A H max clip X BB == I B G min B G max clip X CC == I C F min C F max clip I D E min D E max clip ? ? ?"              : \
                                                                                                                                                                      \
                          Assert (false, "Unsupported median mode.")

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }



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

    strh = ""    krn  = ""
    if (mode == "both" || mode == "circle") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                rad  = mode == "circle" ? 2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py))) : nop()
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

    strh = ""    krn  = ""
    if (mode == "both" || mode == "circle") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                rad  = mode == "circle" ? 2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py))) : nop()
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

    krn = ""    pls = ""
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

    krn = ""    pls = ""
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
           mode=="SG"        ?  [ 0, 255] : \
           mode=="kirsch"    ?  [20, 100] : \
                                [10,  50]

    lo = ex_bs(Defined(lo) ? lo : th[0], bi, fs)
    hi = ex_bs(Defined(hi) ? hi : th[1], bi, fs)

    th  = (lo == 0) && (hi == ex_bs(255, bi, fs)) ? "" : ex_dlut(Format("{lo} - range_max {hi} {lo} - / *"), bi, fs)
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
          mode=="SG"        ? "x[-2,2] 2 * A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] 2 * E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                                   \
                             +"x[1,0] M^ x[2,0] N^ x[-2,-1] O^ x[-1,-1] P^ x[0,-1] Q^ x[1,-1] R^ x[2,-1] S^ x[-2,-2] 2 * T^ x[-1,-2] U^ x[0,-2] V^ x[1,-2] X^ x[2,-2] 2 * Y^ "                           \
                             +"F K O + + 2 * A T B G L P U + + + + + + + D - I - M - R - X - E - Y - J 2 * - N 2 * - S 2 * - "                                                                           \
                             +"B C D + + 2 * A E F G H I J + + + + + + + O - P - Q - R - S - T - Y - U 2 * - V 2 * - X 2 * - max "                                                                       \
                             +"J N S + + 2 * D I M R X E Y + + + + + + + A - T - B - G - L - P - U - F 2 * - K 2 * - O 2 * - "                                                                           \
                             +"U V X + + 2 * O P Q R S T Y + + + + + + + A - E - F - G - H - I - J - B 2 * - C 2 * - D 2 * - max max 0.200 * "+th+""                                                           : \
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