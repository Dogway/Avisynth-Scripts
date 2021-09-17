###########################################################
###                                                      ##
###                                                      ##
###           ExTools v5.7     (17-09-2021)              ##
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
### *Convolutions are slower than in masktools2/removegrain (SSSE3 vs AVX2)
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
### fulls: Defines the scale of HBD values.
###        ConvertBits() defaults to false for YUV, same in ExTools.
###
### Dependencies: AviSynth+ 3.5 and over (https://forum.doom9.org/showthread.php?t=181351)
###
### Credits: Thanks to wonkey_monkey (David Horman) for Expr optimization tips
###
####################################


function ex_lut(clip a, string "str", string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc ? 3 : 1)
    fs   = Default(fulls,       rgb)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    ystr =              ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = isc ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  =              ex_dlut(ystr, bi, fs)
    cstr = rgb ? str  : ex_dlut(cstr, bi, fs)

    isy     ?  Expr(a, str,       scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a, str, "",   scale_inputs=si, clamp_float=cf) : \
               Expr(a, str, cstr, scale_inputs=si, clamp_float=cf) }


function ex_lutxy(clip a, clip b, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc ? 3 : 1)
    fs   = Default(fulls,       rgb)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    ystr =              ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = isc ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  =              ex_dlut(ystr, bi, fs)
    cstr = rgb ? str  : ex_dlut(cstr, bi, fs)

    isy     ?  Expr(a, b, str,       scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a, b, str, "",   scale_inputs=si, clamp_float=cf) : \
               Expr(a, b, str, cstr, scale_inputs=si, clamp_float=cf) }


function ex_lutxyz(clip a, clip b, clip c, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc ? 3 : 1)
    fs   = Default(fulls,       rgb)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    ystr =              ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = isc ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  =              ex_dlut(ystr, bi, fs)
    cstr = rgb ? str  : ex_dlut(cstr, bi, fs)

    isy     ?  Expr(a, b, c, str,       scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
    UV == 1 ?  Expr(a, b, c, str, "",   scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
               Expr(a, b, c, str, cstr, scale_inputs=si, clamp_float=cf, optSingleMode=true) }


function ex_lutxyza(clip a, clip b, clip c, clip d, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc ? 3 : 1)
    fs   = Default(fulls,       rgb)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    ystr =              ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = isc ? cstr : ex_UVexpr(str, UV, bi, rgb, fs)
    str  =              ex_dlut(ystr, bi, fs)
    cstr = rgb ? str  : ex_dlut(cstr, bi, fs)

    isy     ?  Expr(a, b, c, d, str,       scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
    UV == 1 ?  Expr(a, b, c, d, str, "",   scale_inputs=si, clamp_float=cf, optSingleMode=true) : \
               Expr(a, b, c, d, str, cstr, scale_inputs=si, clamp_float=cf, optSingleMode=true) }


# mt_makediff() is 5% slower
function ex_makediff(clip a, clip b, bool "dif", val "aug", bool "tv_range", int "Y", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    aug = Defined(aug) ? isBool(aug) ? aug ? 50 : 1 : aug : 1
    Y   = Default(Y,         3)
    UV  = Default(UV,  rgb ? 3 : aug > 1 ? 128 : 1)
    dif = Default(dif,       true)
    tv  = Default(tv_range, false)   # Enable to mimic Subtract(), "ygrey" centered instead of "range_half"
    fs  = Default(fulls,     rgb)

    gr  =             tv ? "ygrey" : "range_half"
    str = Format(aug > 1 ? "x y - abs {aug} *"    : \
                 dif     ? "x y - "+gr+" +"       : \
                           "x y -")

    ystr = ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)
    str  = dif ? ex_dlut(ystr, bi, fs) : str
    cstr = dif ? ex_dlut(cstr, bi, fs) : cstr

    isy     ? Expr(a, b, str                                    ) : \
    UV == 1 ? Expr(a, b, str, ""                                ) : \
              Expr(a, b, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }


# mt_adddiff() is 5% slower
function ex_adddiff(clip a, clip b, int "Y", int "UV", bool "dif", bool "tv_range", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    Y   = Default(Y,         3)
    UV  = Default(UV,  rgb ? 3 : 1)
    dif = Default(dif,       true)
    tv  = Default(tv_range, false)
    fs  = Default(fulls,   rgb)

    gr  = tv  ? "ygrey" : "range_half"
    str = dif ? "x y + "+gr+" -"      : \
                "x y +"

    ystr = ex_Yexpr (str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs)
    str  = dif ? ex_dlut(ystr, bi, fs) : str
    cstr = dif ? ex_dlut(cstr, bi, fs) : cstr

    isy     ? Expr(a, b, str                                    ) : \
    UV == 1 ? Expr(a, b, str, ""                                ) : \
              Expr(a, b, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }


function ex_makeadddiff(clip a, clip b, clip "c", int "Y", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    isc = Defined(c)
    bi  = BitsPerComponent(a)

    Y   = Default(Y,           3)
    UV  = Default(UV,    rgb ? 3 : 1)
    fs  = Default(fulls, rgb)

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
function ex_logic(clip a, clip b, string "mode", int "thx", int "thy", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "and")
    th1  = Default(thx,     0 )       # threshold for clip x in modes 'min' or 'max'
    th2  = Default(thy,     0 )       # threshold for clip y in modes 'min' or 'max'
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    th1 = th1 != 0 ? string(ex_bs(th1, 8, bi, fulls=fs))+" + " : ""
    th2 = th2 != 0 ? string(ex_bs(th2, 8, bi, fulls=fs))+" + " : ""

    str =                                                     \
        mode == "and"   ? "x y * range_max /"               : \
        mode == "or"    ? "x y + range_min range_max clip"  : \
        mode == "xor"   ? "x y - abs"                       : \
        mode == "andn"  ? "range_max x - y * range_max /"   : \
        mode == "min"   ? "x "+th1+" y "+th2+" min"         : \
        mode == "max"   ? "x "+th1+" y "+th2+" max"         : \
                          Assert (false, "Unsupported logic mode.")

    str  = ex_dlut(str, bi, fs)

    isy     ? Expr(a, b, str                                                               ) : \
    UV == 1 ? Expr(a, b, str, ""                                                           ) : \
              Expr(a, b, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }


# mt_merge() is 5% slower on                  Y clips / masks
#               8% faster on luma=true  for YUV clips / masks
#               9% faster on luma=true  for YUV clips Y masks
#               9% faster on luma=false for YUV clips Y masks
function ex_merge(clip a, clip b, clip msk, bool "luma", int "Y", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isya = isy(a)
    isyb = isy(b)
    isym = isy(msk)
    bi   = BitsPerComponent(a)

    lm  = Default(luma,    isym && rgb)
    Y   = Default(Y,                 3)
    UV  = Default(UV,    rgb || lm ? 3 : isya ? 1 : 2)
    fs  = Default(fulls, rgb)

    isRGB(msk) ? Assert (!lm, "'luma=true' unsupported for RGB masks.") : nop()

    b =  isya && !isyb ? b.ExtractY()                          : \
        !isya &&  isyb ? mskY_to_YYY(a, b, false, rgb, UV, bi, fs) : b

    msk = isya ? isym ? msk           : \
                        ExtractY(msk) : \
          lm  || isym ||                \
          width (msk)!=width (a) ||     \
          height(msk)!=height(a)      ? \
          mskY_to_YYY(a, msk, lm, rgb, UV, bi, fs) : msk

     str = "x dup y - z 1 range_max / * * -"

     str = ex_dlut  ( str,     bi,      fs)
    ystr = ex_Yexpr ( str,  Y, bi, rgb, fs)
    cstr = ex_UVexpr( str, UV, bi, rgb, fs)

    isya    ? Expr(a, b, msk, ystr,                                     optSingleMode=false) : \
    UV == 1 ? Expr(a, b, msk, ystr, "",                                 optSingleMode=false) : \
              Expr(a, b, msk, ystr, cstr, scale_inputs=ex_UVf(rgb, bi), optSingleMode=false) }


# mt_clamp() is 6% slower
function ex_clamp(clip a, clip hi, clip lo, int "overshoot", int "undershoot", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    os = Default(overshoot,  0)
    us = Default(undershoot, 0)
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    os = ex_bs(os, 8, bi, fulls=fs)
    us = ex_bs(us, 8, bi, fulls=fs)

    str = (os == 0) && (us == 0) ?        "x y min z max"              : \
                                   Format("x y {os} + min z {us} - max")

    isy     ? Expr(a, hi, lo, str,                                                                optSingleMode=false) : \
    UV == 1 ? Expr(a, hi, lo, str, "",                                                            optSingleMode=false) : \
              Expr(a, hi, lo, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi), optSingleMode=false) }


# mt_binarize() is 12% slower than ex_binarize()
# mt_binarize() is 17% faster than ex_binarize(smooth=true)
# lo=-1 | hi=-1 replaces lo|hi with source "x"
#
# Dependencies:
#               GRunT          ('dynamic' and 'otsu' modes)
#               ResizersPack   ('dynamic' and 'otsu' modes)
#               TransformsPack (for RGB inputs)
#
# modes:
# simple  - fixed static threshold
# dynamic - temporal stable dynamic threshold. A cheap alternative to Otsu's method
# otsu    - simplified Otsu's method with 10 histogram bins
#
function ex_binarize(clip a, float "thres", bool "invert", bool "smooth", string "mode", int "lo", int "hi", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    th = Default(thres, 115)
    lo = Default(lo,      0)
    hi = Default(hi,    255)
    in = Default(invert, false)
    sm = Default(smooth, false)
    md = Default(mode, "simple")      # 'simple', 'dynamic' or 'otsu'
    UV = Default(UV,      1)          # Currently this is noop as chroma thresholding makes no sense
    fs = Default(fulls, rgb)

    th  = ex_bs(th,  8, bi, fulls=fs)
    lox = lo < 0   hix = hi < 0
    lox && hix ? Assert (false, "'lo' or 'hi': At least one bound should be binarized.") : nop()

    bs  = rgb ?  a.ConvertBits(8,dither=-1,fulls=fs).DotClip([0.298967,0.586421,0.114612]) : a.ConvertBits(8,dither=-1,fulls=fs)
    a   = rgb ? bs.ConvertBits(bi,fulls=fs) : a
    br  = bs.width() > 720 ? bs.RatioResize(720., "adjust2w", kernel="bilinear") : bs
    isy = rgb || isy

    if (md=="otsu") {

        # Assumes TV range for YUV
        bnth = (rgb ? 255 : 219) / 10.
        off  =  rgb ?   0 :  16

        ScriptClip(a,"""
        thr1 =br.ex_binarize(bnth+off,true,UV=UV,fulls=fs)
        bin1 =thr1.AverageLuma()
        thr2 =bnth * 2 + off
        thr2 =Expr(thr1,br,Format("range_max x - y {thr2} < range_max 0 ? * range_max /"), isy ? Undefined() : "")
        bin2 =thr2.AverageLuma()
        thr3 =bnth * 3 + off
        thr3 =Expr(thr2,br,Format("range_max x - y {thr3} < range_max 0 ? * range_max /"), isy ? Undefined() : "")
        bin3 =thr3.AverageLuma()
        thr4 =bnth * 4 + off
        thr4 =Expr(thr3,br,Format("range_max x - y {thr4} < range_max 0 ? * range_max /"), isy ? Undefined() : "")
        bin4 =thr4.AverageLuma()
        thr5 =bnth * 5 + off
        thr5 =Expr(thr4,br,Format("range_max x - y {thr5} < range_max 0 ? * range_max /"), isy ? Undefined() : "")
        bin5 =thr5.AverageLuma()
        thr6 =bnth * 6 + off
        thr6 =Expr(thr5,br,Format("range_max x - y {thr6} < range_max 0 ? * range_max /"), isy ? Undefined() : "")
        bin6 =thr6.AverageLuma()
        thr7 =bnth * 7 + off
        thr7 =Expr(thr6,br,Format("range_max x - y {thr7} < range_max 0 ? * range_max /"), isy ? Undefined() : "")
        bin7 =thr7.AverageLuma()
        thr8 =bnth * 8 + off
        thr8 =Expr(thr7,br,Format("range_max x - y {thr8} < range_max 0 ? * range_max /"), isy ? Undefined() : "")
        bin8 =thr8.AverageLuma()
        thr9 =bnth * 9 + off
        thr10=br.Expr(Format("x {thr9} > range_max 0 ?"), isy ? Undefined() : "")
        thr9 =Expr(thr8,thr10,"range_max x - range_max y - * range_max /", isy ? Undefined() : "")
        bin9 =thr9.AverageLuma()
        bin10=thr10.AverageLuma()

        hist = [bin1, bin2, bin3, bin4, bin5, bin6, bin7, bin8, bin9, bin10]

        for (t = 0, 9, 1) {

            B = 0  F = 0  Mb = 0 Mf = 0
            for (i = 0, t, 1) {
                B  = B  + hist[i]
                Mb = Mb + hist[i] * i
            }
                Mb = B != 0 ? Mb / B : 0

            for (i = t+1, 9, 1) {
                F  = F  + hist[i]
                Mf = Mf + hist[i] * i
            }
                Mf = F != 0 ? Mf / F : 0

            Wb = B / (B + F)
            Wf = F / (B + F)

            # Between class variance for each 't'
            Eval(Format("th{t} = Wb * Wf * pow(Mb - Mf, 2) "))
        }

        th = max(max(max(max(max(max(max(max(max(th0,th1),th2),th3),th4),th5),th6),th7),th8),th9)
        th = th == th0 ? 1 : th == th1 ? 2 : th == th2 ? 3 : th == th3 ? 4 : th == th4 ? 5 : th == th5 ? 6 : th == th6 ? 7 : th == th7 ? 8 : th == th8 ? 9 : 10
        th = (th*bnth+off)-bnth/2

        ex_binarize(a,th,in,sm,"simple",lo,hi,isy ? 1 : UV,fs)

        """,args="a,br,bnth,off,in,sm,lo,hi,UV,bi,fs,isy",local=true)

        rgb ? CombinePlanes(last, last, last, planes="RGB") : last

    } else if (md=="dynamic") {

        ScriptClip(a,"""

        th = (AverageLuma(br,-2)+AverageLuma(br,0)+AverageLuma(br,2))*0.333333333
        ex_binarize(a,th,in,sm,"simple",lo,hi,isy ? 1 : UV,fs)

        """,args="a,br,in,sm,lo,hi,UV,fs,isy",local=true)

        rgb ? CombinePlanes(last, last, last, planes="RGB") : last

    } else {

        if (sm) {

            # same output than smoothstep but faster
            mx  = ex_bs(255, 8, bi, fulls=fs)
            thl = round(th * 0.9)
            thh = round(th * 1.1)
            thm = 1./(thh - thl)

            sub = Format(lox ? in ? "dup {thl} < swap2 swap1       ?" : \
                                    "dup {thh} > swap2 swap1 swap1 ?" : \
                         hix ? in ? "dup {thl} < swap2 swap1 swap1 ?" : \
                                    "dup {thh} > swap2 swap1       ?" : \
                                    ""                                )
            dp  = lox || hix ? "dup" : ""
            lo  = lox ? 0  : ex_bs(lo, 8, bi, fulls=fs)
            hi  = hix ? mx : ex_bs(hi, 8, bi, fulls=fs)
            olo = lo == 0  ? ""  :      "0 max"
            ohi = hi == mx ? "*" : in ? "dup swap2 0 max * swap1 max" : "dup swap2 * swap1 min"


            str = Format(in ? "x "+dp+" {thl} - "+olo+" {thm} * {lo} {hi} - "+ohi+" {hi} + "        : \
                              "x "+dp+" {thl} - "+olo+" {thm} * {hi} {lo} - "+ohi+" {lo} + " ) + sub

        } else {

            lo = lox ? "x" : string(ex_bs(lo, 8, bi, fulls=fs))
            hi = hix ? "x" : string(ex_bs(hi, 8, bi, fulls=fs))

            str = Format(in ? "x {th} < "+hi+" "+lo+" ?" : \
                              "x {th} > "+hi+" "+lo+" ?")
        }


    isy     ?  Expr(a, str                                                               ) : \
    UV == 1 ?  Expr(a, str, ""                                                           ) : \
               Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi))

    sm      ? ex_boxblur(0.3, mode="weighted", UV=1, fulls=fulls) : last } }


# Adaptive Threshold
#
# Useful for binary feature extraction under luminosity changes (ie. fonts in page scans)
# If you are not getting satisfactory results, try to upscale by 2
#
# modes:
# mean     - Normally the default in most solutions, good for fonts or geometric shapes.
# gaussian - Cleaner output. Uses a gaussian approximation so it's faster than 'mean' (Default)

function ex_athres(clip a, float "th", float "sigma", bool "invert", string "mode", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    th  = Default(th,        40)
    sg  = Default(sigma,      6)          # sigma=6 is default for 1080p inputs
    in  = Default(invert, false)
    md  = Default(mode,    "gaussian")    # 'mean' or 'gaussian'
    UV  = Default(UV,    rgb ? 3 : 128)
    fs  = Default(fulls, rgb)

    sg = max(sg,0)
    th = 1 - (th / 1000.)

    # INTEGRAL
    str = "x[-2,-2] x[-1,-2] x[0,-2] x[1,-2]     + + + A@  x[2,-2] +         B^
           x[-2,-1] x[-1,-1] x[0,-1] x[1,-1] A + + + + C@  x[2,-1] B + + A - D^
           x[-2,0]  x[-1,0]  x[0,0]  x[1,0]  C + + + + E@  x[2,0]  D + + C - F^
           x[-2,1]  x[-1,1]  x[0,1]  x[1,1]  E + + + + G@  x[2,1]  F + + E - H^
           x[-2,2]  x[-1,2]  x[0,2]  x[1,2]  + + + dup     x[2,2]  H dup G dup

           + + + + + + 0.012345679 *"

    isy     ?  Expr(a, str                                                               ) : \
    UV == 1 ?  Expr(a, str, ""                                                           ) : \
               Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi))

    integral = last

    # BLUR
    if (md=="gaussian") {
        sg  >= 2 ? ex_gaussianblur(sg,UV=uv)    : \
                   ex_blur(sg,bifit=false,UV=uv)
    } else {
                   ex_boxblur(ceil(sg*2),mode="mean",UV=uv)
    }

    # THRESHOLD
    str  = Format("y x {th} * "+(in ? ">" : "<")+" 0 range_max ?")

    isy     ? Expr(last, integral, str                                                        ) : \
    UV == 1 ? Expr(last, integral, str,  ""                                                   ) : \
              Expr(last, integral, str,  ex_UVexpr(cstr, UV, bi, rgb, fs), scale_inputs="none") }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, bool "tv_range", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    tv  = Default(tv_range, false)    # enable for non-scalar TV range clips
    UV  = Default(UV,    rgb ? 3 : 1)
    fs  = Default(fulls, rgb)

    if (tv) {

        rmax = ex_bs(255, 8, bi, fulls=fs)
        rdif = ex_bs(  4, 8, bi, fulls=fs)
        rdifc= ex_bs(  1, 8, bi, fulls=fs)
        tvr  = rmax - rdif
        tvcr = rmax + rdifc

        str  = Format("{tvr}  x -")
        cstr = Format("{tvcr} x -")
        cstr = ex_UVexpr(cstr, UV, bi, rgb, fs)

    } else {

        str  = "range_max x -"
        str  = ex_dlut  (str,     bi,      fs)
        cstr = ex_UVexpr(str, UV, bi, rgb, fs)
    }

    isy     ?  Expr(a, str                                    ) : \
    UV == 1 ?  Expr(a, str, ""                                ) : \
               Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }


# mt_lutspa() is same speed (instant when spatial)
function ex_lutspa(clip a, string "mode", string "expr", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "absolute")
    str  = Default(expr, "x")
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    tem = FindStr(str, "frameno")  > 0 || FindStr(str, "time") > 0

    str = mode=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," sy " ), " x ", " sx " )  : \
          mode=="relative" ? ReplaceStr(ReplaceStr(" "+str+" "," y "," syr "), " x ", " sxr ")  : \
                             Assert (false, "Unsupported lutspa mode.")

    cstr = ex_dlut( ex_UVexpr(str, UV, bi, rgb, fs), bi, fs)
    str  = ex_dlut(str, bi, fs)

    isy     ?  Expr(a, str                                    ) : \
    UV == 1 ?  Expr(a, str, ""                                ) : \
               Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi))
    tem     ?  last : trim(last,0,-1).Loop(FrameCount(a))     }








######################
##   CONVOLUTIONS   ##
######################

# Convolutions in AviSynth+ perform better with Prefetch(physical cores) than with threads. Also for RGTools and other plugins.

# EQUIVALENCES:
# blur(0.5)                                       ~> ex_boxblur(0.5,mode="weighted")
# removegrain(12) / blur(1.0)                     -> ex_boxblur(1,mode="weighted")
# removegrain(20) / blur(1.58)                    -> ex_boxblur(1,mode="mean")
# removegrain(19)                                 -> ex_boxblur(1,mode="rg19")
# removegrain(12).removegrain(20)                 ~> ex_blur(2.25)
# removegrain(12).removegrain(20).removegrain(20) ~> ex_blur(4)
# removegrain(20).removegrain(20)                 ~> ex_blur(2.75) -> ex_boxblur(3,mode="weighted") -> ex_boxblur(1,mode="mean").ex_boxblur(1,mode="mean")
# ex_blur(n)                                      -> ex_blur(0.7*n-1).ex_blur(0.7*n-1) (slower though)



# Variable Box Blur
#
# Benchmark:
# 100% removegrain(20,-1) (485fps)
#  91% ex_boxblur(1,mode="mean",UV=1)
#  90% MiniDeen(radiusY=1, thrY=255, u=1,v=1) # crumbles from rad=3 onwards
#  69% blur(1.58)
#  67% generalconvolution(matrix="1 1 1 1 1 1 1 1 1",chroma=false)
#  65% Dither_box_filter16(2,U=1,V=1)   # with ConverttoStacked() and ConvertfromStacked()
#  44% mt_convolution("1 1 1","1 1 1",U=1,V=1)
#   5% mt_luts(last, "avg", mt_square(1), "y",chroma="-1")
#
# modes:
# mean     average: mean average of a square kernel with equal weight per component (also known as moving/local mean/average)
# tent        blur: two   pass mean average (same as ex_blur(3.5)) *Not included as mode, call twice manually
# quadratic   blur: three pass mean average                        *Not included as mode, call thrice manually
# bokeh    average: mean average of a ring   kernel with equal weight per component (also known as lens blur) ( ex_expand(n,mode="ring") also works fine)
# rg19     average: mean average of a square kernel with equal weight per component except central pixel (weight = 0) -matches removegrain(19)-
# weighted average: mean average of a square kernel with custom local weights per component (commonly used for a Gaussian approximations; blur(1), removegrain(12), etc)
# trimmed  average: mean average of a square kernel with equal weight per component limited by its local median
#
# ex_boxblur(2,mode="weighted") same to ex_blur(2.5) and ex_boxblur(1,mode="mean").ex_boxblur(1,mode="mean"), and Dither_box_filter16(1,U=1,V=1).Dither_box_filter16(1,U=1,V=1), Dither_ about same speed
#
function ex_boxblur(clip a, float "radius", float "radiusV", string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # integers from 0 to inf ('weighted' also allows 0.15, 0.3, 0.5 and integers up to 14 -single float AVSValue limit-)
    rv = Default(radiusV, rd)           # integers from 0 to inf ('weighted' also allows 0.15, 0.3, 0.5 and integers up to 14 -single float AVSValue limit-)

    fbox  = rd == 1    && rv == 1
    fbox2 = rd == 0.5  && rv == 0.5
    fbox3 = rd == 0.3  && rv == 0.3
    fbox4 = rd == 0.15 && rv == 0.15

    UV = Default(UV,    rgb  ? 3 : 1)
    md = Default(mode,  "mean")
    fs = Default(fulls, rgb)
    rd = max(rd>1?round(rd):rd, 0)
    rv = max(rv>1?round(rv):rv, 0)

    isf = (rv > 0 && rv < 1) || (rd > 0 && rd < 1)
    isf              ? Assert (md == "weighted", "float radius requires 'weighted' mode")         : nop()
    md == "trimmed"  ? Assert (fbox, "'Trimmed' mode only supports radius=1 for both dimensions") : nop()
    md == "bokeh"    ? Assert (rd == rv, "'Bokeh' mode only supports isotropic radii")            : nop()
    md == "weighted" ? Assert (rd < 15 || rv < 15, "Maximum radius reached for 'weighted' mode")  : nop()

    krnlsz = ceil(2 * rd)
    krnlrd = krnlsz/2

    krnh = ""  krnv = ""  plsh = ""  plsv = ""  divx=0  divy=0  divw=0
    if (md == "bokeh") {

        for (px = -krnlrd, krnlrd, 1) {
                for (py = -krnlrd, krnlrd, 1) {
                    skipo = (px*px + py*py) > pow(krnlrd+0.3,   2)
                    skipi = (px*px + py*py) > pow(krnlrd+0.3-1, 2)
                    krnv  = skipo || !skipi ? krnv : Format(krnv + "x[{px},{py}] ")
                    plsv  = skipo || !skipi ? plsv : plsv + "+ "
                    divy  = skipo || !skipi ? divy : divy + 1
           }
      }
                    plsv = LeftStr(plsv, StrLen(plsv)-2)

    } else if (!fbox || !(rd<1 || rv<1)) {

            wgc  = md == "weighted" ?  binom_coeffs(krnlsz, krnlrd)                  : nop()

        for (px = -krnlrd, krnlrd, 1) {
            wg   = md == "weighted" ?  binom_coeffs(krnlsz, krnlsz-(abs(px)+krnlrd)) : nop()
            krnh = md == "rg19"     && px == 0 ? krnh                                                                 : \
                   md == "weighted" && px  > 0 ? px == krnlrd ? Format(krnh + "x[{px},0] x[-{px},0] x[0,0] {wgc} * ") : \
                                                                Format(krnh + "x[{px},0] x[-{px},0] + {wg} * ")       : \
                   md != "weighted"                           ? Format(krnh + "x[{px},0] ") : ""
            plsh = px ==  -krnlrd || (md == "rg19" && px == 0) || md == "weighted" && px < 0 ? plsh : plsh + "+ "
            divw = md == "weighted" ?       wg + divw  : nop()
            divx = md == "rg19"     && px == 0 ? divx  : \
                   md == "weighted"            ? divw  : divx + 1
           }


        krnlsz = ceil(2 * rv)
        krnlrv = krnlsz/2       divw=0

            wgc  = md == "weighted" ?  binom_coeffs(krnlsz, krnlrv)                  : nop()

        for (py = -krnlrv, krnlrv, 1) {
            wg   = md == "weighted" ?  binom_coeffs(krnlsz, krnlsz-(abs(py)+krnlrv)) : nop()
            krnv = md == "rg19"     && py == 0 ? krnv                                                                 : \
                   md == "weighted" && py  > 0 ? py == krnlrv ? Format(krnv + "x[0,{py}] x[0,-{py}] x[0,0] {wgc} * ") : \
                                                                Format(krnv + "x[0,{py}] x[0,-{py}] + {wg} * ")       : \
                   md != "weighted"                           ? Format(krnv + "x[0,{py}] ") : ""
            plsv = py ==  -krnlrv || (md == "rg19" && py == 0) || md == "weighted" && py < 0 ? plsv : plsv + "+ "
            divw = md == "weighted" ?       wg + divw  : nop()
            divy = md == "rg19"     && py == 0 ? divy  : \
                   md == "weighted"            ? divw  : divy + 1
           }
   }

    strv =       md == "weighted" ?                                                                                                                                  \
                 fbox             ? "x[-1,1] x[1,1] x[-1,-1] x[1,-1] + + + 0.500001 * x[0,1] x[-1,0] x[1,0] x[0,-1] x[0,0] 2 * + + + + + 0.125001 *"               : \
                 fbox2            ? "x[0,1] x[-1,0] x[0,0] 3  * x[1,0] x[0,-1] + + + + 0.142857143 *"                                                              : \
                 fbox3            ? "x[0,1] x[-1,0] x[0,0] 6  * x[1,0] x[0,-1] + + + + 0.100001    *"                                                              : \
                 fbox4            ? "x[0,1] x[-1,0] x[0,0] 12 * x[1,0] x[0,-1] + + + + 0.062501    *"                                                              : \
                 rv == 0.5        ? "x[0,1]  x[0,0] 5  * x[0,-1] + + 0.142857143 *"                                                                                : \
                 rv == 0.3        ? "x[0,1]  x[0,0] 8  * x[0,-1] + + 0.100001    *"                                                                                : \
                 rv == 0.15       ? "x[0,1]  x[0,0] 16 * x[0,-1] + + 0.055555555 *"                                                                                : \
                                    krnv + plsv + (rv > 7 ? string(divy)+" /" : string(1./divy)+" *") : ""

    strh =       md == "weighted" ?                                                                                                                                  \
                 rd == 0.5        ? "x[-1,0] x[0,0] 5  * x[1,0]  + + 0.142857143 *"                                                                                : \
                 rd == 0.3        ? "x[-1,0] x[0,0] 8  * x[1,0]  + + 0.100001    *"                                                                                : \
                 rd == 0.15       ? "x[-1,0] x[0,0] 16 * x[1,0]  + + 0.055555555 *"                                                                                : \
                                    krnh + plsh + (rd > 7 ? string(divx)+" /" : string(1./divx)+" *") : ""


    str = fbox ? md == "rg19"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + 0.125001 *"                                        : \
                 md == "bokeh"    ?"x[0,1] x[-1,0] x[1,0] x[0,-1] + + + 0.250001 *"                                                                                : \
                 md == "mean"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[0,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 0.111111111 *"                            : \
                 md == "trimmed"  ?"x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[0,0] E@ x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ + + + + + + + + 0.111111111 * * X^ " \
                                  +"F I  dup1 dup1 min F^ max I^ "                                                                                                   \
                                  +"H B  dup1 dup1 min B^ max H^ "                                                                                                   \
                                  +"D G  dup1 dup1 min D^ max G^ "                                                                                                   \
                                  +"A E  dup1 dup1 min A^ max E^ "                                                                                                   \
                                  +"B I  dup1 dup1 min B^ max I^ "                                                                                                   \
                                  +"E G  dup1 dup1 min E^ max G^ "                                                                                                   \
                                  +"A F  dup1 dup1 min A^ max F^ "                                                                                                   \
                                  +"C D  dup1 dup1 min C^ max D^ "                                                                                                   \
                                  +"G I            min G^        "                                                                                                   \
                                  +"F H  dup1 dup1 min F^ max H^ "                                                                                                   \
                                  +"D E  dup1 dup1 min D^ max E^ "                                                                                                   \
                                  +"A B  dup1 dup1 min A^ max B^ "                                                                                                   \
                                  +"E H            min E^        "                                                                                                   \
                                  +"C F  dup1 dup1 min C^ max F^ "                                                                                                   \
                                  +"B D  dup1 dup1 min B^ max D^ "                                                                                                   \
                                  +"E G  dup1 dup1 min E^ max G^ "                                                                                                   \
                                  +"D F  dup1 dup1 min D^ max F^ "                                                                                                   \
                                  +"A C                   max C^ "                                                                                                   \
                                  +"F G            min F^        "                                                                                                   \
                                  +"D E  dup1 dup1 min D^ max E^ "                                                                                                   \
                                  +"B C                   max C^ "                                                                                                   \
                                  +"E F                   max    "                                                                                                   \
                                  +"C D                   max    "                                                                                                   \
                                  +"X swap2 clip" : "" : krnv + plsv + string(1./divy) + " *"


    strv =          md == "weighted" ? strv : \
           fbox  || md == "bokeh"    ? str  : \
           krnv + plsv + string(1./divy) + " *"

    strh =          md == "weighted" ? strh : \
           krnh + plsh + string(1./divx) + " *"

    rv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 || fbox || fbox2 || fbox3 || fbox4 || md=="bokeh"  ? last                 : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }


function binom_coeffs(n, k) {
    k > n   ? Assert(false,"k > n error")    : \
    k == 0  ? 1                              : \
    k > n/2 ? binom_coeffs(n,n-k)            : \
              n * binom_coeffs(n-1,k-1) / k  }



# Variable Gaussian Blur
#
# Benchmark:
# 100% removegrain(12,-1) (486fps)        # technically a binomial weighted mean of [1 2 1]
#  97% GBlur2(1/2.*sqrt(2),chroma=2)      # only in 8-bit. weighted mean of [1 2 1]
#  90% ex_boxblur(1,mode="weighted",UV=1) # binomial weighted mean
#  88% ablur(1, 1, chroma=1)              # against ex_boxblur(2,mode="weighted",UV=1)
#  85% BinomialBlur(0.5*sqrt(2),U=1,V=1)  # only in 8-bit
#  81% vsTCanny(0.5*sqrt(2),sigma_vY=0.5*sqrt(2),mode=-1,u=1,v=1) # true gaussian blur (fastest for mid size sigma)
#  70% ex_blur(1,UV=1)                    # true gaussian blur
#  68% blur(1.00)                         # weighted mean of [1 2 1]
#  65% generalconvolution(matrix="1 2 1 2 4 2 1 2 1",chroma=false)
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#  23% GBlur(rad=1,sd=0.9,u=false,v=false)
#  11% FastBlur(0.5*sqrt(2),gamma=false)
#  11% GaussianBlur(0.53,U=1,V=1)         # only in 8-bit
#
# ex_blur() is the reference blur function, with correct gaussian coefficients and chroma subsampling adapted sigma.
# Also includes a gamma aware option for more correct defocus on non-scalar clips.
function ex_blur(clip a, float "radius", float "radiusV", bool "bifit", string "gamma", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rm = Default(radius,   1)
    rv = Default(radiusv, rm)
    bf = Default(bifit, true)           # false: true gaussian distribution  true: binomial distribution fit (like blur() or ex_boxblur(mode="weighted") )
    gm = Default(gamma, "none")         # Set matrix for gamma encoded clips (ie. 601, 709, 2020...) Requires TransformsPack
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    # Binomial Fit
    rm = max(rm,0)
    rv = max(rv,0)
    sm = min(1 + rm * 0.25, rm)  # min() to accommodate rad=1
    sv = min(1 + rv * 0.25, rv)  # min() to accommodate rad=1
    sm = bf ? sm / 2. * sqrt(2) : rm
    sv = bf ? sv / 2. * sqrt(2) : rv

    # LUMA
    strv = gauss_constructor(sv,true)
    strh = gauss_constructor(sm,false)

    # CHROMA
    p_4 = is444(a) || rgb  p_1 = isYV411(a)
    p_2 = is422(a)         p_0 = is420(a)

    sv = sv/(!p_0 ? 1 : 2)
    sm = sm/( p_4 ? 1 : p_1 ? 4 : 2)

    cstrv = gauss_constructor(sv,true)
    cstrh = gauss_constructor(sm,false)

    if (gm != "none") {
        matrix = Matrix_fuzzy_search (gm)
        s_gam  = moncurve_coef(matrix)
        a      = moncurve_f(a, s_gam[0], s_gam[1], !rgb, false, UV, fs)
    }

    sv == 0 ?      a                                                                   : \
    isy     ? Expr(a,    strv                                                        ) : \
    UV == 1 ? Expr(a,    strv, ""                                                    ) : \
              Expr(a,    strv, ex_UVexpr(cstrv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ?      last                                                                : \
    isy     ? Expr(last, strh                                                        ) : \
    UV == 1 ? Expr(last, strh, ""                                                    ) : \
              Expr(last, strh, ex_UVexpr(cstrh, UV, bi, rgb, fs), scale_inputs="none")

    gm != "none" ? moncurve_r(last, s_gam[0], s_gam[1], false, !rgb, UV, fs) : last  }


function gauss_constructor(float rad, bool vert) {

    str = "" pls="" di=0
    krnlsz = 2*ceil(3*rad)
    krnlrd = krnlsz/2

    for (i=0, krnlsz, 1) {
        wgc  = exp(-(pow(i-krnlrd,2))/(2*rad*rad))
        di   = wgc < 0.001 ? di : di + wgc
       }

    for (i=0, krnlrd, 1) {

        ga    = exp(-(pow(i-krnlrd,2))/(2*rad*rad))
        wg    = ga/di
        px    = abs(i-krnlrd)
        str   = ga < 0.001 ? str : Format( str + (i == krnlrd ? "x[0,0] {wg} * " : \
                vert ? "x[0,{px}] x[0,-{px}] + {wg} * " : "x[{px},0] x[-{px},0] + {wg} * "))
        pls   = i == krnlrd || ga < 0.001 ? pls : pls + "+ "
       }

    str + pls }


# 100% Dither_bilateral16(radius=2,thr=10,flat=1.0,u=1,v=1) (216fps) # Output is dirtier though
#  59% vsTBilateral(diameterY=3, sdevY=4, idevY=4.0, u=1, v=1)
#  53% ex_bilateral(1,dejaggie=false)
#  43% TBilateral(3,3,chroma=false)                                  # only supports 8-bits
#
function ex_bilateral(clip a, float "radius", float "radiusV", float "ithres", float "sthres", bool "dejaggie", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    sm = Default(radius,   1)           # from 0 to 6
    sv = Default(radiusv, sm)           # from 0 to 6
    it = Default(ithres,   4)           # 0.1 to 10. Intensity standard deviation target used to compute coefficients for the intensity Gaussian filter. Keep low for more edge preservation.
    st = Default(sthres,   4)           # 0.1 to 10. Spatial standard deviation target used to compute coefficients for the spatial Gaussian filter. Higher values spread the weights further away.
    dj = Default(dejaggie, true)
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    sm > 6 || sv > 6 ? Assert (false, "Radius should be 6 or below") : nop()
    sm = max(min(sm * 0.30,2.0),0)
    sv = max(min(sv * 0.30,2.0),0)

    krnlsz = 2*ceil(3*sv)
    krnlrv = krnlsz/2

    vars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    Vc   = MidStr(vars,krnlrv+1,1)
    dj   = dj ? Vc+" 0.3 * min" : ""
    it   = 1./ ex_bs(it, 8, bi, fulls=fs)

    krnv2 = "" krnv3 = ""  Vv = "" krnh2 = "" krnh3 = "" Vh = ""

    for (i=0, krnlsz, 1) {

        V     = MidStr(vars,i+1,1)
        py    = i - krnlrv
        krnv1 = Format("x[0,{py}] ")

        Vv    = Vv + " " + V
        wg    = exp(pow(sqrt(pow(py,2))/st,2))
        krnv2 = i != krnlrv ? Format(krnv2 + krnv1 + V + "@ "+Vc+" - "+dj+" {it} * dup * 0.500001 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnv2
        krnv3 = i == krnlrv ? Format(                V + "  "+Vc+" - "+dj+" {it} * dup * 0.500001 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnv3
        plsv  = i == 0 ? "" : plsv + " + " }


    krnlszh = 2*ceil(3*sm)
    krnlrd  = krnlszh/2
    Vc      = MidStr(vars,krnlrd+1,1)

    for (i=0, krnlszh, 1) {

        V     = MidStr(vars,i+1,1)
        px    = i - krnlrd
        krnh1 = Format("x[{px},0] ")

        Vh    = Vh + " " + V
        wg    = exp(pow(sqrt(pow(px,2))/st,2))
        krnh2 = i != krnlrd ? Format(krnh2 + krnh1 + V + "@ "+Vc+" - "+dj+" {it} * dup * 0.500001 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnh2
        krnh3 = i == krnlrd ? Format(                V + "  "+Vc+" - "+dj+" {it} * dup * 0.500001 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnh3
        plsh  = i == 0 ? "" : plsh + " + " }

    strv = "x[0,0] " + Vc + "^ " + krnv2 + krnv3 + plsv + Vv + plsv + "1 swap / *"
    strh = "x[0,0] " + Vc + "^ " + krnh2 + krnh3 + plsh + Vh + plsh + "1 swap / *"

    sv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ?      last                                                               : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }



# Like ex_bilateral(), a less gentle blurring but more performant
# Similar to SurfaceBlur() by Didée: http://forum.doom9.org/showthread.php?p=1586287#post1586287
# SurfaceBlur(3,5) is 22% slower than ex_smartblur(3,thres=20)
function ex_smartblur(clip a, float "radius", float "radiusV", float "thres", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    sm = Default(radius,   1)           # from 0 to 6
    sv = Default(radiusv, sm)           # from 0 to 6
    th = Default(thres,   15)
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)
    th = ex_bs(th, 8, bi, fulls=fs)

    sm > 6 || sv > 6 ? Assert (false, "Radius should be 6 or below") : nop()

    krnlsz = 2*ceil(3*max(min(sv * 0.30,2.0),0))

    vars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    Vc   = MidStr(vars,krnlsz/2+1,1)

    krnv2 = "" krnv3 = ""  Vv = "" krnh2 = "" krnh3 = "" Vh = ""  divx=0  divy=0

    for (i=0, krnlsz, 1) {

        V     = MidStr(vars,i+1,1)
        Vv    = Vv + " " + V
        py    = i - krnlsz/2
        krnv2 = Format(krnv2 + "x[0,{py}] " + V + "^ ")
        krnv3 = Vc != V ? Format(krnv3      + V + " " + Vc + " - abs ") : krnv3
        plsv  = i == 0 ? "" : Vc == V ? plsv : plsv + " + "
        divy  = divy + 1  }


    krnlszh = 2*ceil(3*max(min(sm * 0.30,2.0),0))
    Vc      = MidStr(vars,krnlszh/2+1,1)

    for (i=0, krnlszh, 1) {

        V     = MidStr(vars,i+1,1)
        Vh    = Vh + " " + V
        px    = i - krnlszh/2
        krnh2 = Format(krnh2 + "x[{px},0] " + V + "^ ")
        krnh3 = Vc != V ? Format(krnh3      + V + " " + Vc + " - abs ") : krnh3
        plsh  = i == 0 ? "" : Vc == V ? plsh : plsh + " + "
        divx = divx + 1   }

    strv = krnv2 + krnv3 + plsv + string(th*sv) + " < " + Vv + plsv + " + " + string(1./divy) + " * x ?"
    strh = krnh2 + krnh3 + plsh + string(th*sm) + " < " + Vh + plsh + " + " + string(1./divx) + " * x ?"

    sv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ?      last                                                               : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }


# modes:
# SG  - Savitzky-Golay (S-G) smoothing filter (similar to Gaussian blur)
# SNN - Symmetrical Nearest Neighbour based pair average
function ex_smooth(clip a, int "radius", int "radiusV", bool "sharp", string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to 3
    rv = Default(radiusV, rd)           # from 0 to 3
    sh = Default(sharp, false)          # Sharp version of S-G mode
    md = Default(mode,  "SG")
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)
    rd = max(rd, 0)
    rv = max(rv, 0)

    rd == 3 || rv == 3 ? Assert (!sh, "S-G Sharp mode only supports radius < 3")                    : nop()
    md == "SNN"        ? Assert (rd == rv && rd < 2 && rv < 2, "SNN mode only supports radius < 2") : nop()

    if (!sh) {

    # Quadratic/Cubic (2nd and 3rd degree polynomials)
    strv = rv == 1 ? "x[0,1] x[0,-1] + 4 * x[0,0] 5.666666666 * + x[0,-2] x[0,2] + - 0.085714286 *"                                                                 : \
           rv == 2 ? "x[0,1] x[0,-1] + 2 * x[0,0] 2.333333333 * x[0,-2] x[0,2] + + + x[0,-3] x[0,3] + 0.666666666 * - 0.142857143 *"                                : \
           rv == 3 ? "x[0,3] x[0,-3] + 4.666666666 * x[0,2] x[0,-2] + 13 * x[0,1] x[0,-1] + 18 * x[0,0] 19.666666666 * + + + x[0,-4] x[0,4] + 7 * - 0.012987013 *"  : ""

    strh = rd == 1 ? "x[-1,0] x[1,0] + 4 * x[0,0] 5.666666666 * + x[2,0] x[-2,0] + - 0.085714286 *"                                                                 : \
           rd == 2 ? "x[-1,0] x[1,0] + 2 * x[0,0] 2.333333333 * x[2,0] x[-2,0] + + + x[3,0] x[-3,0] + 0.666666666 * - 0.142857143 *"                                : \
           rd == 3 ? "x[3,0] x[-3,0] + 4.666666666 * x[2,0] x[-2,0] + 13 * x[1,0] x[-1,0] + 18 * x[0,0] 19.666666666 * + + + x[-4,0] x[4,0] + 7 * - 0.012987013 *"  : ""

    } else {

    # Quartic/Quintic (4th and 5th degree polynomials) (sharper)
    strv = rv == 1 ? "x[0,1] x[0,-1] + 15 * x[0,0] 26.2 * x[0,3] x[0,-3] + + + x[0,-2] x[0,2] + 6 * - 0.021645022 *"                                                : \
           rv == 2 ? "x[0,2] x[0,-2] + 2 * x[0,1] x[0,-1] + 9 * x[0,0] 11.933333333 * x[0,4] x[0,-4] + + + + x[0,-3] x[0,3] + 3.666666666 * - 0.034965035 *"        : ""

    strh = rd == 1 ? "x[1,0] x[-1,0] + 15 * x[0,0] 26.2 * x[3,0] x[-3,0] + + + x[-2,0] x[2,0] + 6 * - 0.021645022 *"                                                : \
           rd == 2 ? "x[2,0] x[-2,0] + 2 * x[1,0] x[-1,0] + 9 * x[0,0] 11.933333333 * x[4,0] x[-4,0] + + + + x[-3,0] x[3,0] + 3.666666666 * - 0.034965035 *"        : ""

    }

    strv = md == "SNN" ? "x[0,0] X@  x[-1,1] A@ - abs X x[1,-1]  H@ - abs + M@
                          X          x[0,1]  B@ - abs X x[0,-1]  G@ - abs + N@ min
                          X          x[1,1]  C@ - abs X x[-1,-1] F@ - abs + O@ min
                          X          x[-1,0] D@ - abs X x[1,0]   E@ - abs +    min W^
                          W M == A H + W N == B G + W O == C F + D E + ? ? ? 0.500001 *" : strv

    rv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 || md == "SNN" ? last                                                     : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }



# Kawase blur multipass kernel for optimized Gaussian blur approximation with high sigma (don't use for binarized masks)
#
# Benchmark:
# 100% ex_kawase(1,"lin",UV=1)  (442fps)
#  77% ex_boxblur(2,mode="weighted",UV=1)
#  76% FastGaussBlur(1)                      # but scales up better than kawase for ex_kawase() > 2
#  75% removegrain(12,-1).removegrain(12,-1)
#  75% FRC_GaussianBlur42(1)                 # but scales up better than kawase for ex_kawase() > 2
#  72% ex_blur(2,UV=1)                       # ex_kawase(2,"lin") equals to ex_blur(8,UV=1)
#
# modes:
# lin  - linear     multipass: 1,2,3,4,5...
# log  - log2       multipass: 1,2,2,3,3,3...
# fib  - fibonacci  multipass: 1,1,2,3,5,8...
# trib - tribonacci multipass: 1,1,2,4,7,13...
#
function ex_kawase(clip a, int "radius", string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to ~10 (hard limit)
    md = Default(mode, "log")
    UV = Default(UV,    rgb ? 3 : 2)
    fs = Default(fulls, rgb)

    str = ""
    for (i = 1, rd, 1) {
        c   = i  == 1      ? "a," : ""
        dot = i  == rd     ? ""   : "."
        px  = md == "log"  ? Eval(LeftStr(String(log(i)/log(2)+1,"%0.1f"),1))      : \
              md == "fib"  ? floor(pow((1+sqrt(5))/2,i)/sqrt(5)+0.5)               : \
              md == "trib" ? floor(0.618033988749895*pow(1.839286755214161,i)+0.5) : \
                             i
        krn =                         Format("x[-{px},{px}] x[{px},{px}] x[-{px},-{px}] x[{px},-{px}]         x[0,0] + + + + 0.200001 *")
        pxc = max(0, px - 1)
        krc = is444(a) || rgb ? krn : Format("x[-{pxc},{pxc}] x[{pxc},{pxc}] x[-{pxc},-{pxc}] x[{pxc},-{pxc}] x[0,0] + + + + 0.200001 *")
        str = str + Format(isy     ?   "Expr(  "+c+"     "+Chr(34)+krn+Chr(34)+"                                                                                        )"   : \
                           UV == 1 ?   "Expr(  "+c+"     "+Chr(34)+krn+Chr(34)+",               "+Chr(34)+" "+Chr(34)+"                                                 )"   : \
                                     """Expr("""+c+""" """+Chr(34)+krn+Chr(34)+""", ex_UVexpr("""+Chr(34)+krc+Chr(34)+""", {UV}, {bi}, {rgb}, {fs}), scale_inputs="none")""")+dot
           }

    rd != 0 ? Eval(str) : a }



#######################################################################
##
## ex_GaussianBlur() by Dogway (06-09-2021)
## Large-sigma optimized gaussian blur filter
##
## Heavy mod from FRC_GaussianBlur42()
## https://forum.doom9.org/showthread.php?p=1807156#post1807156
##
## It was profiled against ex_blur(bifit=false) so ex_blur(10,bifit=false) ~ ex_GaussianBlur(10)
##
## version 2013-10-23 raffriff42
## version 2014-05-31 discrete hor. and vert. args
## version 2017-05-21 bugfix: blockiness
## version 2021-09-05 Optimized (~38% gain) and profiled against ex_blur(), also Y+UV args
##
##
## 100% ex_gaussianblur(6)  (483fps)                    (gaussian approximation, fastest for large sigma)
##  40% vsTCanny(sigmaY=6, sigma_vY=6, mode=-1,u=1,v=1) (true gaussian, fastest for mid sigma)
##  17% ex_blur(rad,bifit=false,UV=1)                   (true gaussian, best for low sigma)

function ex_GaussianBlur(clip C, float "sigma", float "sigmaV", int "Y", int "UV") {

    rgb = isRGB(C)
    isy = isy(C)

    rad  = Default(sigma,    10)
    radv = Default(sigmaV,  rad)
    Y    = Default(Y,         3)
    UV   = Default(UV,        3)   # Beware, chroma can't be disabled, just copied back, hence UV=1 will be slower (ExtractY()/CombinePlanes() was slower)


    rad  = 1.221428*rad  + 0.136   # Parametrized to gaussian like standard deviation
    radv = 1.221428*radv + 0.136   # Parametrized to gaussian like standard deviation

    w0 = C.Width()
    h0 = C.Height()
    w1 = Round(w0/rad )/4
    h1 = Round(h0/radv)/4

    B = C.BicubicResize(
    \         Min(Max(4, w1 * 4), w0),
    \         Min(Max(4, h1 * 4), h0))

           (rad<0.01 && radv<0.01)       ? C
    \    : (B.Width()>8 && B.Height()>8) ? B.GaussResize  (w0, h0, p=15)
    \                                    : B.BicubicResize(w0, h0, 1, 0) # SoftCubic100

    Y  < 3 ? !isy ? mergechroma(C,last) : last : last
    UV < 3 ? !isy ? mergeluma  (C,last) : last : last }



##############################
##
## Median Blur
##
## Replaces removegrain medians, adaptivemedian, verticalcleaner, clense, degrainmedian, medianblur, medianblurtemporal, DeSaltPepper/SaltPepper and UnDot plugins, and adds new modes.
## Sorting Networks perform better with Prefetch(logical_cores*0.75) in multi-threading CPUs.
##
## Requires AviSynth+ 3.7.1 test12 or above
## https://forum.doom9.org/showthread.php?t=181351
##
## 100% removegrain(1,-1)
##  91% ex_median(mode="undot",UV=1) # same as DeSaltPepper or SaltPepper from manyplus, or UnDot by Tom Barry.
##
## 100% removegrain(2,-1)
##  75% ex_median(mode="undot2",UV=1)
##
##  100% removegrain(4,-1)   (480fps)
##   78% ex_median(mode="median",UV=1)  # same as "undot4"
##   60% Dither_median16(rx=1, ry=1, rt=0, y=3, u=1, v=1)
##  1.2% MedianBlur(1,0,0)
## 0.06% mt_luts(last, "med", mt_square(1), "y",chroma="-1")
##
## 100% quantile(rank=13,radius_u=0,radius_v=0)      # 155fps (only 8-bits)
##  84% removegrainHD(rank=13,radius_u=0,radius_v=0) # (only 8-bits)
##  67% ex_median(mode="median5",UV=1)
##  10% Dither_median16(rx=2, ry=2, rt=0, y=3, u=1, v=1)
## 3.3% MedianBlur(2,0,0) # 5fps with or without chroma (unstable filter)
##
##  100% Clense(grey=true)
##   92% ex_median(mode="medianT",UV=1)
##   91% MedianBlurTemporal(0,0,0)
##
## 100% ex_median(mode="medianST",UV=1)
##   81% MedianBlurTemporal(1,1,1) # 2fps without chroma (unstable filter)
##
## Recommended: EMF, smart, CAM, edgeCL, cartoon, DGM1, ML3D and STWM
#
# 43 modes:
# undot     - Also called "conservative", removes one pixel salt'n'pepper noise                    -removegrain(1)-
# undot2    - Same as undot but clip up to the second closest minimum values                       -removegrain(2)-
# undot3    - Same as undot but clip up to the third  closest minimum values                       -removegrain(3)-
# undot4    - Same as undot but clip up to the fourth closest minimum values                       -removegrain(4)-  *Same as 'median'
# median    - True median. Replace with kernel middle value (3x3 kernel)                           -removegrain(4)-  *Same as 'undot4'
# median5   - True median. Replace with kernel middle value (5x5 kernel)
# median7   - True median. Replace with kernel middle value (7x7 kernel)  (580 CE for BB and CC)
# median7o  - Circle kernel median of radius 3 (7x7)               (own algo)
# smart     - Smart Median Filter. Threshold against variance      (own algo). Similar in concept to ex_smartblur() and somewhat to MinVar() (old DeNoise plugin)
# EMF       - Extended Median Filter. 3x3 kernel median thresholded against center pixel
# CWM       - Center Weighted Median
# CWM2      - Center -stronger- Weighted Median. Similar output to edgeCL but a bit slower
# WMF       - Gauss Weighted Median
# AWM       - Mean Average Weighted Median                         (own algo)
# PWM       - 50% weighted Percentile Weighted Median              (own algo)
# RMF       - Recursive Median Filter. Computes the new median from previous pixel medians. *Proof of concept, actually runs faster with 2 passes of "median"
# AMF       - Adaptive Median. Similar to undot but better at salt'n'pepper noise.                 -From VC Mohan AdaptiveMedian-
# CAM       - Cross kernel Adaptive Median                         (own algo)
# SNN       - Symmetric Nearest Neighbour Mean. Average of 4 closest pixels in opposing pairs.
# kuwahara  - Nagao Kuwahara. (Simplified) Mean average of the least variance quadrant in a 5x5 kernel window. (oil paint look/filter)
# edgeW     - Edge sensitive. Line pairs are used.                                    Weak denoise -removegrain(18)-
# edgeS     - Edge sensitive. Same as 'median' but better edge   protection.        Strong denoise -removegrain(17)-
# edgeC     - Edge sensitive. Same as 'edgeS'  but better corner protection.        Strong denoise -removegrain(26)-
# edgeCL    - Edge sensitive. Same as 'edgeC'  but better line   protection.        Strong denoise -removegrain(27)-
# cartoon   - Clipping is done with respect to averages of neighbours.           Best for cartoons -removegrain(22)-
# vertical  - Vertical median. Port of VerticalCleaner mode=1
# verticalS - Vertical median. Port of VerticalCleaner mode=2 (edge sensitive)
# GaussT5   - Temporal Gauss Blur of 5 frames with very primitive thresholding    (Temporal)
# medianT   - Temporal median of 3 frames                                         (Temporal) (like Clense())
# medianT5  - Temporal median of 5 frames                                         (Temporal)
# medianST  - 3x3x3 Cubic Spatio-Temporal                                         (Spatio-Temporal)
# SixNN     - 1x3x1 Six Nearest-Neighbours                                        (Spatio-Temporal, Motion Protected)
# STWM      - 1x2xWMFx2x1 Spatio-Temporal Gaussian Weighted Median (own algo)     (Spatio-Temporal, Motion Protected)
# PML       - Planar Multi-Level Median Filter                                    (Spatio-Temporal, Motion Protected)
# ML3D      - Multi-Level Median Filter                                           (Spatio-Temporal, Motion Protected)
# ML3Dex    - Extended Multi-Level Median Filter                                  (Spatio-Temporal)
# BDM       - Arce Bi-directional Multi-Level Median Filter                       (Spatio-Temporal, Motion Protected)
# MMF       - Multistage Median Filter                                            (Spatio-Temporal, Motion Protected) (like a 3D undot)
# DGM0      - Mode=0 of DeGrainMedian (similar    to spatial only RemoveGrain(9)) (Spatio-Temporal, Motion Protected) (based itself on STMedianFilter)
# DGM1      - Mode=1 of DeGrainMedian (stronger than spatial only RemoveGrain(8)) (Spatio-Temporal, Motion Protected) (Default in DGM)
# DGM2      - Mode=2 of DeGrainMedian (similar    to spatial only RemoveGrain(8)) (Spatio-Temporal, Motion Protected)
# DGM3      - Mode=3 of DeGrainMedian (similar    to spatial only RemoveGrain(7)) (Spatio-Temporal, Motion Protected)
# DGM4      - Mode=4 of DeGrainMedian (similar    to spatial only RemoveGrain(6)) (Spatio-Temporal, Motion Protected)
# DGM5      - Mode=5 of DeGrainMedian (similar    to spatial only RemoveGrain(5)) (Spatio-Temporal, Motion Protected)



# SNN (Symmetric Nearest Neighbour Median) is not implemented due to low edge integrity protection. -removegrain(9)-
# *SmartMedian and SmartMedian2 from RemoveGrainHD are not included. With radius=1 output is blotchy and jagged lines, with radius=2 it's like strong undot, it protects lines to some degree

function ex_median(clip a, string "mode", float "thres", bool "recursion", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    mode = Default(mode,     "median")
    rc   = Default(recursion,   false)               # Use recursion for temporal modes. Performance penalty for little improvement though
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)
    thr  = Default(thres, mode=="EMF"       ?   9 : \
                          mode=="smart"     ?  50 : \
                          mode=="GaussT5"   ? 255 : \
                          mode=="SNN"       ?  20 : 4)    # Absolute Error threshold. Only for EMF, smart, SNN and DeGrainMedian modes

    # Beware 'smart' mode threshold doesn't hold up between 8-bit and HBD
    th = mode=="smart" && bi > 8 ? bi == 32     ? \
         ex_bs(          thr-5, 8, bi, fulls=fs) : \
         ex_bs(pow(2,bi-8)*thr, 8, bi, fulls=fs) : \
         ex_bs(            thr, 8, bi, fulls=fs)

    TGth = mode=="GaussT5" && thr != 255 ? Format("dup x - abs {th} < swap x ?") : ""

    Assert(IsVersionOrGreater(3,7,1), "Update AviSynth+ version to 3.7.1+")

    str =                                                                                                                                                                       \
        mode == "median5"? "x[-2,-2] x[-2,-1]     dup1 dup1 min D^ max X^
                            x[-2,0]  x[-2,1]      dup1 dup1 min L^ max W^
                            x[-2,2]  x[-1,-2]     dup1 dup1 min H^ max V^
                            x[-1,-1] x[-1,0]      dup1 dup1 min A^ max U^
                            x[-1,1]  x[-1,2]      dup1 dup1 min R^ max T^
                            x[0,-2]  x[0,-1]      dup1 dup1 min N^ max S^
                            x[0,1]   x[0,2]       dup1 dup1 min C^ max Q^
                            x[1,-2]  x[1,-1]      dup1 dup1 min J^ max P^
                            x[1,0]   x[1,1]       dup1 dup1 min I^ max O^
                            x[1,2]   x[2,-2]      dup1 dup1 min B^ max M^
                            x[2,-1]  x[2,0]       dup1 dup1 min F^ max K^
                            x[2,1]   x[2,2]       dup1 dup1 min E^ max G^
                            U X                   dup1 dup1 min U^ max X^
                            M W                   dup1 dup1 min M^ max W^
                            Q V                   dup1 dup1 min Q^ max V^
                            G T                   dup1 dup1 min G^ max T^
                            K S                   dup1 dup1 min K^ max S^
                            E R                   dup1 dup1 min E^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            B L                   dup1 dup1 min B^ max L^
                            I J                   dup1 dup1 min I^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            A D                   dup1 dup1 min A^ max D^
                            W X                   dup1 dup1 min W^ max X^
                            T V                   dup1 dup1 min T^ max V^
                            L U                   dup1 dup1 min L^ max U^
                            P S                   dup1 dup1 min P^ max S^
                            O R                   dup1 dup1 min O^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            S V                             min S^
                            P T                   dup1 dup1 min P^ max T^
                            M R                   dup1 dup1 min M^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            G L                   dup1 dup1 min G^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            C F                                    max F^
                            P W                   dup1 dup1 min P^ max W^
                            J U                   dup1 dup1 min J^ max U^
                            Q T                   dup1 dup1 min Q^ max T^
                            D O                   dup1 dup1 min D^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            B I                   dup1 dup1 min B^ max I^
                            E H                   dup1 dup1 min E^ max H^
                            Q X                             min Q^
                            S W                   dup1 dup1 min S^ max W^
                            T U                             min T^
                            M R                   dup1 dup1 min M^ max R^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            K N                   dup1 dup1 min K^ max N^
                            G L                   dup1 dup1 min G^ max L^
                            A H                                    max H^
                            B F                   dup1 dup1 min B^ max F^
                            D E                                    max E^
                            R W                             min R^
                            Q T                   dup1 dup1 min Q^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            I K                   dup1 dup1 min I^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            B G                                    max G^
                            S T                   dup1 dup1 min S^ max T^
                            P R                             min P^
                            O Q                   dup1 dup1 min O^ max Q^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            G I                                    max I^
                            E F                   dup1 dup1 min E^ max F^
                            N T                             min N^
                            P Q                             min P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            E K                                    max K^
                            H I                                    max I^
                            N S                             min N^
                            O P                             min O^
                            F K                                    max K^
                            I J                                    max J^
                            L N                             min L^
                            K M                                    max M^
                            L O                             min L^
                            J M                                    max M^
                            L M                   dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                                     : \
                                                                                                                                                                                \
        mode == "median7"? "x[-3,-3] x[-2,-3]     dup1 dup1 min A^  max B^
                            x[-1,-3] x[0,-3]      dup1 dup1 min C^  max D^
                            A C                   dup1 dup1 min A^  max C^
                            B D                   dup1 dup1 min B^  max D^
                            B C                   dup1 dup1 min B^  max C^
                            x[1,-3] x[2,-3]       dup1 dup1 min E^  max F^
                            x[3,-3] x[-3,-2]      dup1 dup1 min G^  max H^
                            E G                   dup1 dup1 min E^  max G^
                            F H                   dup1 dup1 min F^  max H^
                            F G                   dup1 dup1 min F^  max G^
                            A E                   dup1 dup1 min A^  max E^
                            C G                   dup1 dup1 min C^  max G^
                            C E                   dup1 dup1 min C^  max E^
                            B F                   dup1 dup1 min B^  max F^
                            D H                   dup1 dup1 min D^  max H^
                            D F                   dup1 dup1 min D^  max F^
                            B C                   dup1 dup1 min B^  max C^
                            D E                   dup1 dup1 min D^  max E^
                            F G                   dup1 dup1 min F^  max G^
                            x[-2,-2] x[-1,-2]     dup1 dup1 min I^  max J^
                            x[0,-2]  x[1,-2]      dup1 dup1 min K^  max L^
                            I K                   dup1 dup1 min I^  max K^
                            J L                   dup1 dup1 min J^  max L^
                            J K                   dup1 dup1 min J^  max K^
                            x[2,-2]  x[3,-2]      dup1 dup1 min M^  max N^
                            x[-3,-1] x[-2,-1]     dup1 dup1 min O^  max P^
                            M O                   dup1 dup1 min M^  max O^
                            N P                   dup1 dup1 min N^  max P^
                            N O                   dup1 dup1 min N^  max O^
                            I M                   dup1 dup1 min I^  max M^
                            K O                   dup1 dup1 min K^  max O^
                            K M                   dup1 dup1 min K^  max M^
                            J N                   dup1 dup1 min J^  max N^
                            L P                   dup1 dup1 min L^  max P^
                            L N                   dup1 dup1 min L^  max N^
                            J K                   dup1 dup1 min J^  max K^
                            L M                   dup1 dup1 min L^  max M^
                            N O                   dup1 dup1 min N^  max O^
                            A I                   dup1 dup1 min A^  max I^
                            E M                   dup1 dup1 min E^  max M^
                            E I                   dup1 dup1 min E^  max I^
                            C K                   dup1 dup1 min C^  max K^
                            G O                   dup1 dup1 min G^  max O^
                            G K                   dup1 dup1 min G^  max K^
                            C E                   dup1 dup1 min C^  max E^
                            G I                   dup1 dup1 min G^  max I^
                            K M                   dup1 dup1 min K^  max M^
                            B J                   dup1 dup1 min B^  max J^
                            F N                   dup1 dup1 min F^  max N^
                            F J                   dup1 dup1 min F^  max J^
                            D L                   dup1 dup1 min D^  max L^
                            H P                   dup1 dup1 min H^  max P^
                            H L                   dup1 dup1 min H^  max L^
                            D F                   dup1 dup1 min D^  max F^
                            H J                   dup1 dup1 min H^  max J^
                            L N                   dup1 dup1 min L^  max N^
                            B C                   dup1 dup1 min B^  max C^
                            D E                   dup1 dup1 min D^  max E^
                            F G                   dup1 dup1 min F^  max G^
                            H I                   dup1 dup1 min H^  max I^
                            J K                   dup1 dup1 min J^  max K^
                            L M                   dup1 dup1 min L^  max M^
                            N O                   dup1 dup1 min N^  max O^
                            x[-1,-1] x[0,-1]      dup1 dup1 min Q^  max R^
                            x[1,-1]  x[2,-1]      dup1 dup1 min S^  max U^
                            Q S                   dup1 dup1 min Q^  max S^
                            R U                   dup1 dup1 min R^  max U^
                            R S                   dup1 dup1 min R^  max S^
                            x[3,-1] x[-3,0]       dup1 dup1 min V^  max W^
                            x[-2,0] x[-1,0]       dup1 dup1 min Y^  max Z^
                            V Y                   dup1 dup1 min V^  max Y^
                            W Z                   dup1 dup1 min W^  max Z^
                            W Y                   dup1 dup1 min W^  max Y^
                            Q V                   dup1 dup1 min Q^  max V^
                            S Y                   dup1 dup1 min S^  max Y^
                            S V                   dup1 dup1 min S^  max V^
                            R W                   dup1 dup1 min R^  max W^
                            U Z                   dup1 dup1 min U^  max Z^
                            U W                   dup1 dup1 min U^  max W^
                            R S                   dup1 dup1 min R^  max S^
                            U V                   dup1 dup1 min U^  max V^
                            W Y                   dup1 dup1 min W^  max Y^
                            x[1,0] x[2,0]         dup1 dup1 min AA^ max BB^
                            x[3,0] x[-3,1]        dup1 dup1 min CC^ max DD^
                            AA CC                 dup1 dup1 min AA^ max CC^
                            BB DD                 dup1 dup1 min BB^ max DD^
                            BB CC                 dup1 dup1 min BB^ max CC^
                            x[-2,1] x[-1,1]       dup1 dup1 min EE^ max FF^
                            x[0,1]  x[1,1]        dup1 dup1 min GG^ max HH^
                            EE GG                 dup1 dup1 min EE^ max GG^
                            FF HH                 dup1 dup1 min FF^ max HH^
                            FF GG                 dup1 dup1 min FF^ max GG^
                            AA EE                 dup1 dup1 min AA^ max EE^
                            CC GG                 dup1 dup1 min CC^ max GG^
                            CC EE                 dup1 dup1 min CC^ max EE^
                            BB FF                 dup1 dup1 min BB^ max FF^
                            DD HH                 dup1 dup1 min DD^ max HH^
                            DD FF                 dup1 dup1 min DD^ max FF^
                            BB CC                 dup1 dup1 min BB^ max CC^
                            DD EE                 dup1 dup1 min DD^ max EE^
                            FF GG                 dup1 dup1 min FF^ max GG^
                            Q AA                  dup1 dup1 min Q^  max AA^
                            V EE                  dup1 dup1 min V^  max EE^
                            V AA                  dup1 dup1 min V^  max AA^
                            S CC                  dup1 dup1 min S^  max CC^
                            Y GG                  dup1 dup1 min Y^  max GG^
                            Y CC                  dup1 dup1 min Y^  max CC^
                            S V                   dup1 dup1 min S^  max V^
                            Y AA                  dup1 dup1 min Y^  max AA^
                            CC EE                 dup1 dup1 min CC^ max EE^
                            R BB                  dup1 dup1 min R^  max BB^
                            W FF                  dup1 dup1 min W^  max FF^
                            W BB                  dup1 dup1 min W^  max BB^
                            U DD                  dup1 dup1 min U^  max DD^
                            Z HH                  dup1 dup1 min Z^  max HH^
                            Z DD                  dup1 dup1 min Z^  max DD^
                            U W                   dup1 dup1 min U^  max W^
                            Z BB                  dup1 dup1 min Z^  max BB^
                            DD FF                 dup1 dup1 min DD^ max FF^
                            R S                   dup1 dup1 min R^  max S^
                            U V                   dup1 dup1 min U^  max V^
                            W Y                   dup1 dup1 min W^  max Y^
                            Z AA                  dup1 dup1 min Z^  max AA^
                            BB CC                 dup1 dup1 min BB^ max CC^
                            DD EE                 dup1 dup1 min DD^ max EE^
                            FF GG                 dup1 dup1 min FF^ max GG^
                            A Q                   dup1 dup1 min A^  max Q^
                            I AA                  dup1 dup1 min I^  max AA^
                            I Q                   dup1 dup1 min I^  max Q^
                            E V                   dup1 dup1 min E^  max V^
                            M EE                  dup1 dup1 min M^  max EE^
                            M V                   dup1 dup1 min M^  max V^
                            E I                   dup1 dup1 min E^  max I^
                            M Q                   dup1 dup1 min M^  max Q^
                            V AA                  dup1 dup1 min V^  max AA^
                            C S                   dup1 dup1 min C^  max S^
                            K CC                  dup1 dup1 min K^  max CC^
                            K S                   dup1 dup1 min K^  max S^
                            G Y                   dup1 dup1 min G^  max Y^
                            O GG                            min O^
                            O Y                   dup1 dup1 min O^  max Y^
                            G K                   dup1 dup1 min G^  max K^
                            O S                   dup1 dup1 min O^  max S^
                            Y CC                  dup1 dup1 min Y^  max CC^
                            C E                   dup1 dup1 min C^  max E^
                            G I                   dup1 dup1 min G^  max I^
                            K M                   dup1 dup1 min K^  max M^
                            O Q                   dup1 dup1 min O^  max Q^
                            S V                   dup1 dup1 min S^  max V^
                            Y AA                  dup1 dup1 min Y^  max AA^
                            CC EE                 dup1 dup1 min CC^ max EE^
                            B R                   dup1 dup1 min B^  max R^
                            J BB                  dup1 dup1 min J^  max BB^
                            J R                   dup1 dup1 min J^  max R^
                            F W                   dup1 dup1 min F^  max W^
                            N FF                  dup1 dup1 min N^  max FF^
                            N W                   dup1 dup1 min N^  max W^
                            F J                   dup1 dup1 min F^  max J^
                            N R                   dup1 dup1 min N^  max R^
                            W BB                  dup1 dup1 min W^  max BB^
                            D U                   dup1 dup1 min D^  max U^
                            L DD                  dup1 dup1 min L^  max DD^
                            L U                   dup1 dup1 min L^  max U^
                            H Z                   dup1 dup1 min H^  max Z^
                            P HH                            min P^
                            P Z                   dup1 dup1 min P^  max Z^
                            H L                   dup1 dup1 min H^  max L^
                            P U                   dup1 dup1 min P^  max U^
                            Z DD                  dup1 dup1 min Z^  max DD^
                            D F                   dup1 dup1 min D^  max F^
                            H J                   dup1 dup1 min H^  max J^
                            L N                   dup1 dup1 min L^  max N^
                            P R                   dup1 dup1 min P^  max R^
                            U W                   dup1 dup1 min U^  max W^
                            Z BB                  dup1 dup1 min Z^  max BB^
                            DD FF                           min DD^
                            B C                   dup1 dup1 min B^  max C^
                            D E                   dup1 dup1 min D^  max E^
                            F G                   dup1 dup1 min F^  max G^
                            H I                   dup1 dup1 min H^  max I^
                            J K                   dup1 dup1 min J^  max K^
                            L M                   dup1 dup1 min L^  max M^
                            N O                   dup1 dup1 min N^  max O^
                            P Q                   dup1 dup1 min P^  max Q^
                            R S                   dup1 dup1 min R^  max S^
                            U V                   dup1 dup1 min U^  max V^
                            W Y                   dup1 dup1 min W^  max Y^
                            Z AA                  dup1 dup1 min Z^  max AA^
                            BB CC                 dup1 dup1 min BB^ max CC^
                            DD EE                           min DD^
                            x[2,1] x[3,1]         dup1 dup1 min II^ max JJ^
                            x[-3,2] x[-2,2]       dup1 dup1 min KK^ max LL^
                            II KK                 dup1 dup1 min II^ max KK^
                            JJ LL                 dup1 dup1 min JJ^ max LL^
                            JJ KK                 dup1 dup1 min JJ^ max KK^
                            x[-1,2] x[0,2]        dup1 dup1 min MM^ max NN^
                            x[1,2]  x[2,2]        dup1 dup1 min OO^ max PP^
                            MM OO                 dup1 dup1 min MM^ max OO^
                            NN PP                 dup1 dup1 min NN^ max PP^
                            NN OO                 dup1 dup1 min NN^ max OO^
                            II MM                 dup1 dup1 min II^ max MM^
                            KK OO                 dup1 dup1 min KK^ max OO^
                            KK MM                 dup1 dup1 min KK^ max MM^
                            JJ NN                 dup1 dup1 min JJ^ max NN^
                            LL PP                 dup1 dup1 min LL^ max PP^
                            LL NN                 dup1 dup1 min LL^ max NN^
                            JJ KK                 dup1 dup1 min JJ^ max KK^
                            LL MM                 dup1 dup1 min LL^ max MM^
                            NN OO                 dup1 dup1 min NN^ max OO^
                            x[3,2]  x[-3,3]       dup1 dup1 min QQ^ max RR^
                            x[-2,3] x[-1,3]       dup1 dup1 min SS^ max TT^
                            QQ SS                 dup1 dup1 min QQ^ max SS^
                            RR TT                 dup1 dup1 min RR^ max TT^
                            RR SS                 dup1 dup1 min RR^ max SS^
                            x[0,3] x[1,3]         dup1 dup1 min VV^ max WW^
                            x[2,3] x[3,3]         dup1 dup1 min YY^ max ZZ^
                            VV YY                 dup1 dup1 min VV^ max YY^
                            WW ZZ                 dup1 dup1 min WW^ max ZZ^
                            WW YY                 dup1 dup1 min WW^ max YY^
                            QQ VV                 dup1 dup1 min QQ^ max VV^
                            SS YY                 dup1 dup1 min SS^ max YY^
                            SS VV                 dup1 dup1 min SS^ max VV^
                            RR WW                 dup1 dup1 min RR^ max WW^
                            TT ZZ                 dup1 dup1 min TT^ max ZZ^
                            TT WW                 dup1 dup1 min TT^ max WW^
                            RR SS                 dup1 dup1 min RR^ max SS^
                            TT VV                 dup1 dup1 min TT^ max VV^
                            WW YY                 dup1 dup1 min WW^ max YY^
                            II QQ                 dup1 dup1 min II^ max QQ^
                            MM VV                 dup1 dup1 min MM^ max VV^
                            MM QQ                 dup1 dup1 min MM^ max QQ^
                            KK SS                 dup1 dup1 min KK^ max SS^
                            OO YY                 dup1 dup1 min OO^ max YY^
                            OO SS                 dup1 dup1 min OO^ max SS^
                            KK MM                 dup1 dup1 min KK^ max MM^
                            OO QQ                 dup1 dup1 min OO^ max QQ^
                            SS VV                 dup1 dup1 min SS^ max VV^
                            JJ RR                 dup1 dup1 min JJ^ max RR^
                            NN WW                 dup1 dup1 min NN^ max WW^
                            NN RR                 dup1 dup1 min NN^ max RR^
                            LL TT                 dup1 dup1 min LL^ max TT^
                            PP ZZ                 dup1 dup1 min PP^ max ZZ^
                            PP TT                 dup1 dup1 min PP^ max TT^
                            LL NN                 dup1 dup1 min LL^ max NN^
                            PP RR                 dup1 dup1 min PP^ max RR^
                            TT WW                 dup1 dup1 min TT^ max WW^
                            JJ KK                 dup1 dup1 min JJ^ max KK^
                            LL MM                 dup1 dup1 min LL^ max MM^
                            NN OO                 dup1 dup1 min NN^ max OO^
                            PP QQ                 dup1 dup1 min PP^ max QQ^
                            RR SS                 dup1 dup1 min RR^ max SS^
                            TT VV                 dup1 dup1 min TT^ max VV^
                            WW YY                 dup1 dup1 min WW^ max YY^
                            MM QQ                 dup1 dup1 min MM^ max QQ^
                            OO SS                 dup1 dup1 min OO^ max SS^
                            KK MM                 dup1 dup1 min KK^ max MM^
                            OO QQ                 dup1 dup1 min OO^ max QQ^
                            SS VV                 dup1 dup1 min SS^ max VV^
                            NN RR                 dup1 dup1 min NN^ max RR^
                            PP TT                 dup1 dup1 min PP^ max TT^
                            LL NN                 dup1 dup1 min LL^ max NN^
                            PP RR                 dup1 dup1 min PP^ max RR^
                            TT WW                 dup1 dup1 min TT^ max WW^
                            JJ KK                 dup1 dup1 min JJ^ max KK^
                            LL MM                 dup1 dup1 min LL^ max MM^
                            NN OO                 dup1 dup1 min NN^ max OO^
                            PP QQ                 dup1 dup1 min PP^ max QQ^
                            RR SS                 dup1 dup1 min RR^ max SS^
                            TT VV                 dup1 dup1 min TT^ max VV^
                            WW YY                 dup1 dup1 min WW^ max YY^
                            A II                                    max II^
                            Q II                                    max II^
                            I QQ                                    max QQ^
                            AA QQ                           min AA^
                            AA II                           min AA^
                            E MM                                    max MM^
                            V MM                            min V^
                            M VV                            min M^
                            M V                                     max V^
                            V AA                                    max AA^
                            C KK                                    max KK^
                            S KK                                    max KK^
                            K SS                                    max SS^
                            CC SS                           min CC^
                            CC KK                           min CC^
                            G OO                                    max OO^
                            Y OO                            min Y^
                            O YY                            min O^
                            O Y                                     max Y^
                            Y CC                            min Y^
                            Y AA                                    max AA^
                            B JJ                                    max JJ^
                            R JJ                                    max JJ^
                            J RR                                    max RR^
                            BB RR                           min BB^
                            BB JJ                           min BB^
                            F NN                                    max NN^
                            W NN                            min W^
                            N WW                            min N^
                            N W                                     max W^
                            W BB                                    max BB^
                            D LL                                    max LL^
                            U LL                                    max LL^
                            L TT                                    max TT^
                            DD TT                           min DD^
                            DD LL                           min DD^
                            H PP                                    max PP^
                            Z PP                            min Z^
                            P ZZ                            min P^
                            P Z                                     max Z^
                            Z DD                            min Z^
                            Z BB                            min Z^
                            Z AA                  dup1 dup1 max swap2 min

                            x swap2 clip"                                                                                                                                     : \
                                                                                                                                                                                \
        mode == "median7o"?"x[-3,0]  x[-2,-2]     dup1 dup1 min AA^ max AB^
                            x[-2,-1] x[-2,0]      dup1 dup1 min Y^ max Z^
                            x[-2,1]  x[-2,2]      dup1 dup1 min W^ max X^
                            x[-1,-2] x[-1,-1]     dup1 dup1 min U^ max V^
                            x[-1,0]  x[-1,1]      dup1 dup1 min S^ max T^
                            x[-1,2]  x[0,-3]      dup1 dup1 min Q^ max R^
                            x[0,-2]  x[0,-1]      dup1 dup1 min O^ max P^
                            x[0,1]   x[0,2]       dup1 dup1 min M^ max N^
                            x[0,3]   x[1,-2]      dup1 dup1 min K^ max L^
                            x[1,-1]  x[1,0]       dup1 dup1 min I^ max J^
                            x[1,1]   x[1,2]       dup1 dup1 min G^ max H^
                            x[2,-2]  x[2,-1]      dup1 dup1 min E^ max F^
                            x[2,0]   x[2,1]       dup1 dup1 min C^ max D^
                            x[2,2]   x[3,0]       dup1 dup1 min A^ max B^
                            B AB                  dup1 dup1 min B^ max AB^
                            A AA                  dup1 dup1 min A^ max AA^
                            D Z                   dup1 dup1 min D^ max Z^
                            C Y                   dup1 dup1 min C^ max Y^
                            F X                   dup1 dup1 min F^ max X^
                            E W                   dup1 dup1 min E^ max W^
                            H V                   dup1 dup1 min H^ max V^
                            G U                   dup1 dup1 min G^ max U^
                            J T                   dup1 dup1 min J^ max T^
                            I S                   dup1 dup1 min I^ max S^
                            L R                   dup1 dup1 min L^ max R^
                            K Q                   dup1 dup1 min K^ max Q^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            V AB                  dup1 dup1 min V^ max AB^
                            H AA                  dup1 dup1 min H^ max AA^
                            X Z                   dup1 dup1 min X^ max Z^
                            W Y                   dup1 dup1 min W^ max Y^
                            B U                   dup1 dup1 min B^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            L O                   dup1 dup1 min L^ max O^
                            K M                   dup1 dup1 min K^ max M^
                            A G                   dup1 dup1 min A^ max G^
                            D F                   dup1 dup1 min D^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            J AA                  dup1 dup1 min J^ max AA^
                            R Z                   dup1 dup1 min R^ max Z^
                            F X                   dup1 dup1 min F^ max X^
                            E W                   dup1 dup1 min E^ max W^
                            T V                   dup1 dup1 min T^ max V^
                            B S                   dup1 dup1 min B^ max S^
                            O P                   dup1 dup1 min O^ max P^
                            M N                   dup1 dup1 min M^ max N^
                            C K                   dup1 dup1 min C^ max K^
                            G I                   dup1 dup1 min G^ max I^
                            V AB                  dup1 dup1 min V^ max AB^
                            F Y                   dup1 dup1 min F^ max Y^
                            P X                   dup1 dup1 min P^ max X^
                            D W                   dup1 dup1 min D^ max W^
                            S U                   dup1 dup1 min S^ max U^
                            O Q                   dup1 dup1 min O^ max Q^
                            L N                   dup1 dup1 min L^ max N^
                            E M                   dup1 dup1 min E^ max M^
                            H J                   dup1 dup1 min H^ max J^
                            A G                   dup1 dup1 min A^ max G^
                            Z AB                            min Z^
                            X AA                            min X^
                            Q Y                   dup1 dup1 min Q^ max Y^
                            O W                   dup1 dup1 min O^ max W^
                            R V                             min R^
                            T U                   dup1 dup1 min T^ max U^
                            F N                   dup1 dup1 min F^ max N^
                            D L                   dup1 dup1 min D^ max L^
                            G K                                    max K^
                            H I                   dup1 dup1 min H^ max I^
                            B E                                    max E^
                            A C                                    max C^
                            U Y                             min U^
                            Q X                   dup1 dup1 min Q^ max X^
                            R W                   dup1 dup1 min R^ max W^
                            M T                   dup1 dup1 min M^ max T^
                            N S                   dup1 dup1 min N^ max S^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            E L                   dup1 dup1 min E^ max L^
                            F K                   dup1 dup1 min F^ max K^
                            D H                                    max H^
                            S Z                             min S^
                            T X                             min T^
                            O W                             min O^
                            K U                   dup1 dup1 min K^ max U^
                            H R                   dup1 dup1 min H^ max R^
                            M Q                   dup1 dup1 min M^ max Q^
                            L P                   dup1 dup1 min L^ max P^
                            F N                                    max N^
                            C J                                    max J^
                            E I                                    max I^
                            P U                             min P^
                            Q T                   dup1 dup1 min Q^ max T^
                            O R                   dup1 dup1 min O^ max R^
                            K N                   dup1 dup1 min K^ max N^
                            H M                                    max M^
                            I L                   dup1 dup1 min I^ max L^
                            R T                             min R^
                            P S                             min P^
                            N Q                   dup1 dup1 min N^ max Q^
                            L O                   dup1 dup1 min L^ max O^
                            J M                                    max M^
                            I K                                    max K^
                            P R                             min P^
                            O Q                             min O^
                            L N                                    max N^
                            K M                                    max M^
                            O P                   dup1 dup1 min O^ max P^
                            M N                   dup1 dup1 min M^ max N^
                            N P                             min N^
                            M O                                    max O^
                            N O                   dup1 dup1 max swap2 min

                            x swap2 clip"                                                                                                                                     : \
                                                                                                                                                                                \
        mode == "CAM"    ? "x[0,2] A^ x[0,-2] G^ x[-2,0] C^ x[2,0] E^ x[-1,0] D@ x[1,0] F@ x[0,1] B@ x[0,-1] H@ x[0,0] X@ + + + + 0.200001 * M^
                            A B                   dup1 dup1 min swap2 max
                            C D                   dup1 dup1 min swap2 max
                            E F                   dup1 dup1 min swap2 max
                            G H                   dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            X swap2 clip S^

                            B D                   dup1 dup1 min swap2 max
                            F H                   dup1 dup1 min swap2 max
                            swap1  swap2                    min
                            swap2                                     max
                                                  dup1 dup1 max swap2 min
                            X swap2 clip T^
                            S M - abs T M - abs > T S ?"                                                                                                                      : \
                                                                                                                                                                                \
        mode == "SNN"    ? Format("
                            x[0,0] X@ x[-1,1] A@ - abs X x[1,-1]  H@ - abs M@ min L^
                            X         x[0,1]  B@ - abs X x[0,-1]  G@ - abs N@ min W^
                            X         x[1,1]  C@ - abs X x[-1,-1] F@ - abs O@ min Y^
                            X         x[-1,0] D@ - abs X x[1,0]   E@ - abs P@ min Z^

                            L {th} < L M == H A ? X ? W {th} < W N == G B ? X ? Y {th} < Y O == F C ? X ? Z {th} < Z P == E D ? X ? + + + 0.250001 *")              : \
                                                                                                                                                                      \
        mode == "kuwahara"?"x[-2,2] A@ x[-1,2] B@ x[0,2] C@ x[-2,1] F@ x[-1,1] G@ x[0,1] H@ x[-2,0] K@ x[-1,0] L@ x[0,0] M@ + + + + + + + + 0.111111111 * W^
                            C x[1,2] D@ x[2,2] E@ H x[1,1] I@ x[2,1] J@ M x[1,0] N@ x[2,0] O@                               + + + + + + + + 0.111111111 * WW^
                            K L M x[-2,-1] P@ x[-1,-1] Q@ x[0,-1] R@ x[-2,-2] U@ x[-1,-2] V@ x[0,-2] X@                     + + + + + + + + 0.111111111 * WWW^
                            A W   - dup * B W   - dup * C W   - dup * F W   - dup * G W   - dup * H W   - dup * K W   - dup * L W   - dup * M W   - dup * + + + + + + + + AA^
                            C WW  - dup * D WW  - dup * E WW  - dup * H WW  - dup * I WW  - dup * J WW  - dup * M WW  - dup * N WW  - dup * O WW  - dup * + + + + + + + + BB^
                            K WWW - dup * L WWW - dup * M WWW - dup * P WWW - dup * Q WWW - dup * R WWW - dup * U WWW - dup * V WWW - dup * X WWW - dup * + + + + + + + + CC^
                            AA BB min CC min EE@ AA == W EE BB == WW EE CC == WWW M N O R x[1,-1] x[2,-1] X x[1,-2] x[2,-2] + + + + + + + + 0.111111111 * ? ? ?" : \
                                                                                                                                                                      \
        mode == "PWM"    ? "x[-1,1]  x[0,1]       dup1 dup1 min swap2 max
                            x[1,1]   x[-1,0]      dup1 dup1 min swap2 max
                            x[0,0]   x[1,0]       dup1 dup1 min swap2 max
                            x[-1,-1] x[0,-1]      dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  x[1,-1]        dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap8   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap8  swap1  swap3   dup1 dup1 min swap2 max
                            swap7  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap8   dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap8  swap1  swap2   dup1 dup1 min swap2 max
                            swap6  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap8  swap1  swap4   dup1 dup1 min swap2 max
                            swap5  swap8  swap6  swap7  swap5  swap6  swap1  swap5  swap1  swap4  swap3  swap2  swap1
                            A^ B^ C^ D^ E^ F^ G^ H^ I^
                            A B C + + R@ dup D E F G H I + + + + + + 0.500001 * W@ - abs Z^
                            R     D  +                                                  W  - abs Y^ R D E + + W - abs X^ R D E F + + + W - abs V^
                            Z Y < B C + Y X < C D + X V < D E + E F + ? ? ? 0.500001 *"                                                                             : \
                                                                                                                                                                      \
        mode == "AWM"  ?   "x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[0,0] x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ + + + + + + + + 0.111111111 * W^
                            F I                   dup1 dup1 min F^ max I^
                            B H                   dup1 dup1 min B^ max H^
                            D G                   dup1 dup1 min D^ max G^
                            A C                   dup1 dup1 min A^ max E^
                            B I                   dup1 dup1 min B^ max I^
                            E G                   dup1 dup1 min E^ max G^
                            A F                   dup1 dup1 min A^ max F^
                            D W                   dup1 dup1 min C^ max D^
                            G I                             min G^
                            F H                   dup1 dup1 min F^ max H^
                            D E                   dup1 dup1 min D^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            E H                             min E^
                            C F                   dup1 dup1 min C^ max F^
                            B D                   dup1 dup1 min B^ max D^
                            E G                   dup1 dup1 min E^ max G^
                            D F                   dup1 dup1 min D^ max F^
                            A C                                    max C^
                            F G                             min F^
                            D E                   dup1 dup1 min D^ max E^
                            B C                                    max C^
                            E F                                    max
                            C D                                    max

                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "AMF"  ?   "x[-1,1]  G@ x[0,1]  H@ dup1 dup1 min swap2 max
                            x[1,1]   I@ x[-1,0] L@ dup1 dup1 min swap2 max
                            x[1,-1]  S@ x[1,0]  N@ dup1 dup1 min swap2 max
                            x[-1,-1] Q@ x[0,-1] R@ dup1 dup1 min swap2 max
                            swap2  swap1  swap6    dup1 dup1 min swap2 max
                            swap2  swap1  swap4    dup1 dup1 min swap2 max
                            swap3  swap1  swap7    dup1 dup1 min swap2 max
                            swap6  swap1  swap5    dup1 dup1 min swap2 max
                            swap3  swap1  swap2    dup1 dup1 min swap2 max
                            swap3  swap1  swap6    dup1 dup1 min swap2 max
                            swap7  swap1  swap4    dup1 dup1 min swap2 max
                            swap2  swap1  swap5    dup1 dup1 min swap2 max
                            swap2  swap1  swap7              min
                            swap4  swap1  swap3                        max
                            swap3  swap1  swap4              min
                            swap2                                      max
                                                   dup1 dup1 min swap2 max
                            swap2  swap3
                            ZA^ ZO^ ZP^ ZZ^
                            x ZO ZP clip MT^

                            L H                   dup1 dup1 min D^ max X^
                            R S                   dup1 dup1 min L^ max W^
                            I N                   dup1 dup1 min H^ max V^
                            Q G                   dup1 dup1 min A^ max U^
                            x[-2,-2] x[-2,-1]     dup1 dup1 min R^ max T^
                            x[-2,0]  x[-2,1]      dup1 dup1 min N^ max S^
                            x[-2,2]  x[-1,-2]     dup1 dup1 min C^ max Q^
                            x[-1,2]  x[0,-2]      dup1 dup1 min J^ max P^
                            x[0,2]   x[1,-2]      dup1 dup1 min I^ max O^
                            x[1,2]   x[2,-2]      dup1 dup1 min B^ max M^
                            x[2,-1]  x[2,0]       dup1 dup1 min F^ max K^
                            x[2,1]   x[2,2]       dup1 dup1 min E^ max G^
                            U X                   dup1 dup1 min U^ max X^
                            M W                   dup1 dup1 min M^ max W^
                            Q V                   dup1 dup1 min Q^ max V^
                            G T                   dup1 dup1 min G^ max T^
                            K S                   dup1 dup1 min K^ max S^
                            E R                   dup1 dup1 min E^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            B L                   dup1 dup1 min B^ max L^
                            I J                   dup1 dup1 min I^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            A D                   dup1 dup1 min A^ max D^
                            W X                   dup1 dup1 min W^ max X^
                            T V                   dup1 dup1 min T^ max V^
                            L U                   dup1 dup1 min L^ max U^
                            P S                   dup1 dup1 min P^ max S^
                            O R                   dup1 dup1 min O^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            S V                   dup1 dup1 min S^ max V^
                            P T                   dup1 dup1 min P^ max T^
                            M R                   dup1 dup1 min M^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            G L                   dup1 dup1 min G^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            C F                   dup1 dup1 min C^ max F^
                            P W                   dup1 dup1 min P^ max W^
                            J U                   dup1 dup1 min J^ max U^
                            Q T                   dup1 dup1 min Q^ max T^
                            D O                   dup1 dup1 min D^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            B I                   dup1 dup1 min B^ max I^
                            E H                   dup1 dup1 min E^ max H^
                            Q X                   dup1 dup1 min Q^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            T U                             min T^
                            M R                   dup1 dup1 min M^ max R^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            K N                   dup1 dup1 min K^ max N^
                            G L                   dup1 dup1 min G^ max L^
                            A H                   dup1 dup1 min A^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            D E                                    max E^
                            V X                                    max X^
                            R W                             min R^
                            Q T                   dup1 dup1 min Q^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            I K                   dup1 dup1 min I^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            B G                                    max G^
                            A C                             min A^
                            S T                   dup1 dup1 min S^ max T^
                            P R                             min P^
                            O Q                   dup1 dup1 min O^ max Q^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            G I                                    max I^
                            E F                   dup1 dup1 min E^ max F^
                            N T                             min N^
                            P Q                             min P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            E K                                    max K^
                            H I                                    max I^
                            N S                             min N^
                            O P                             min O^
                            F K                                    max K^
                            I J                                    max J^
                            L N                             min L^
                            K M                                    max M^
                            L O                             min L^
                            J M                                    max M^
                            L M                   dup1 dup1 max swap2 min

                            x swap2 clip F^
                            MT ZA > MT ZZ < & x ZA > x ZZ < & x MT ? F A > F X < & x A > x X < & x F ? x ? ?"                                                       : \
                                                                                                                                                                      \
        mode == "undot"  ? "x[-1,1] A@ x[0,1] B@ max x[1,1] C@ max x[-1,0] D@ max x[1,0] E@ max x[-1,-1] F@ max x[0,-1] G@ max x[1,-1] H@ max
                            A B min C min D min E min F min G min H min x swap2 clip"                                                                               : \
                                                                                                                                                                      \
        mode == "undot2" ? "x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap5  swap1  swap3             min
                            swap2  swap1  swap3                       max
                            swap2                           min
                            swap2                                     max
                            x swap2 swap1 clip"                                                                                                                     : \
                                                                                                                                                                      \
        mode == "undot3" ? "x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap5  swap1  swap3             min
                            swap2  swap1  swap3                       max
                            swap2                                     max
                            swap2                           min
                            x swap2 swap1 clip"                                                                                                                     : \
                                                                                                                                                                      \
        mode == "undot4" ||                                                                                                                                           \
        mode == "median" ? "x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "RMF"    ? "x[-2,-2]   x[-1,-2] A@ dup1 dup1 min swap2 max
                            x[0,-2] B@ x[-2,-1] C@ dup1 dup1 min swap2 max
                            x[0,0]  X@ x[0,-1]  D@ dup1 dup1 min swap2 max
                            x[-2,0] E@ x[-1,0]  F@ dup1 dup1 min swap2 max
                            swap7  swap1  swap3    dup1 dup1 min swap2 max
                            swap5  swap1  swap3    dup1 dup1 min swap2 max
                            swap6  swap1  swap2    dup1 dup1 min swap2 max
                            swap4  swap1  swap7    dup1 dup1 min swap2 max
                            swap3  swap1  swap2                        max
                            swap6                  dup1 dup1 min swap2 max
                            swap4  swap1  swap5    dup1 dup1 min swap2 max
                            swap3  swap1  swap2              min
                            swap4                                      max
                            swap2                            min
                            swap3                                      max
                            swap2                            min
                                                   dup1 dup1 max swap2 min

                            x[-1,-1] H@ swap2 clip TL^

                            A                  B   dup1 dup1 min swap2 max
                            x[1,-2] G@         H   dup1 dup1 min swap2 max
                            X          x[1,-1] I@  dup1 dup1 min swap2 max
                            F          x[1,0]  J@  dup1 dup1 min swap2 max
                            swap7  swap1  swap3    dup1 dup1 min swap2 max
                            swap5  swap1  swap3    dup1 dup1 min swap2 max
                            swap6  swap1  swap2    dup1 dup1 min swap2 max
                            swap4  swap1  swap7    dup1 dup1 min swap2 max
                            swap3  swap1  swap2                        max
                            swap6                  dup1 dup1 min swap2 max
                            swap4  swap1  swap5    dup1 dup1 min swap2 max
                            swap3  swap1  swap2              min
                            swap4                                      max
                            swap2                            min
                            swap3                                      max
                            swap2                            min
                                                   dup1 dup1 max swap2 min
                            D swap2 clip TC^

                            B       G             dup1 dup1 min swap2 max
                            x[2,-2] D             dup1 dup1 min swap2 max
                            X       x[2,-1]       dup1 dup1 min swap2 max
                            J       x[2,0]        dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            I swap2 clip TR^

                            C                  H  dup1 dup1 min swap2 max
                            D                  E  dup1 dup1 min swap2 max
                            X          x[-2,1]    dup1 dup1 min swap2 max
                            x[-1,1] K@ x[0,1]  L@ dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            F swap2 clip CL^

                            TL TC                 dup1 dup1 min swap2 max
                            TR CL                 dup1 dup1 min swap2 max
                            J  K                  dup1 dup1 min swap2 max
                            L x[1,1]              dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "cartoon"? "x[-1,1] A@ x[1,-1] H@ + x[0,1] B@ x[0,-1] G@ + max x[1,1] C@ x[-1,-1] F@ + max x[-1,0] D@ x[1,0] E@ + max 0.500001 * "                    \
                          +"A H +                          B G + min                  C F +            min         D E +          min 0.500001 * x swap2 clip"      : \
                                                                                                                                                                      \
        mode == "edgeS"  ? "x[-1,1] x[1,-1]  dup1 dup1 min swap2 max
                            x[0,1]  x[0,-1]  dup1 dup1 min swap2 max
                            x[1,1]  x[-1,-1] dup1 dup1 min swap2 max
                            x[-1,0] x[1,0]   dup1 dup1 min swap2 max
                            swap3                      max swap2 min
                            swap3 swap1 swap5          max swap3 min
                                                       min swap2 max
                                             dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
        mode == "edgeW"  ? "                                             x[0,0] I@ x[0,1]  B@ - abs I x[0,-1] G@ - abs max BB@
                            I x[1,1]  C@ - abs I x[-1,-1] F@ - abs max CC@ min  I  x[-1,0] D@ - abs I x[1,0]  E@ - abs max DD@ min
                            I x[-1,1] A@ - abs I x[1,-1] H@ - abs max      min
                            X@ DD == I D E dup1 dup1 min swap2 max clip X BB == I B G dup1 dup1 min swap2 max clip
                            X  CC == I C F dup1 dup1 min swap2 max clip         I A H dup1 dup1 min swap2 max clip ? ? ?"                                          : \
                                                                                                                                                                     \
        mode == "edgeC"  ? "x[-1,1]   A@ x[0,1] B@  dup1 dup1 min swap2 max
                            B x[1,1]  C@            dup1 dup1 min swap2 max
                            C x[1,0]  E@            dup1 dup1 min swap2 max
                            E x[1,-1] H@            dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO^
                            swap1 swap2 min min min                         HI^

                            x[0,-1]  G@ H dup1 dup1 min swap2 max
                            x[-1,-1] F@ G dup1 dup1 min swap2 max
                            x[-1,0]  D@ F dup1 dup1 min swap2 max
                            A D           dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO max LO^
                            swap1 swap2 min min min                         HI min HI@ LO

                            x swap2 min LO HI max clip"                                                                                                            : \
                                                                                                                                                                     \
        mode == "edgeCL" ? "x[-1,1] A@ x[1,-1] H@   dup1 dup1 min swap2 max
                            A          x[0,1]  B@   dup1 dup1 min swap2 max
                            x[0,-1] G@         H    dup1 dup1 min swap2 max
                            B                  G    dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO^
                            swap1 swap2 min min min                         HI^

                            x[1,1]   C@ B dup1 dup1 min swap2 max
                            x[-1,-1] F@ G dup1 dup1 min swap2 max
                                     C  F dup1 dup1 min swap2 max
                            x[1,0]   E@ C dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO max LO^
                            swap1 swap2 min min min                         HI min HI^

                            x[-1,0]  D@ F dup1 dup1 min swap2 max
                                     D  E dup1 dup1 min swap2 max
                                     E  H dup1 dup1 min swap2 max
                                     D  A dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO max LO^
                            swap1 swap2 min min min                         HI min LO

                            dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "EMF" ?    Format("
                            x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min

                            x swap2 clip M@ x swap - abs {th} <= M x ?")                                                                                            : \
                                                                                                                                                                      \
        mode == "smart" ?   Format("
                            x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[1,0] E@ x[-1,-1] F@ x[0,-1] G@ x[1,-1] H@ + + + + + + + 0.125001 * W^
                            A B                   dup1 dup1 min swap2 max
                            C D                   dup1 dup1 min swap2 max
                            E F                   dup1 dup1 min swap2 max
                            G H                   dup1 dup1 min swap2 max
                            swap2  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7   dup1 dup1 min swap2 max
                            swap6  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap3  swap1  swap6   dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap2  swap1  swap7             min
                            swap4  swap1  swap3                       max
                            swap3  swap1  swap4             min
                            swap2                                     max
                                                  dup1 dup1 min swap2 max
                            E^ D^ H^
                              W - dup * H W - dup * + 0.790001 *
                              x - abs {th} <= x D E clip x ?")                                                                                                      : \
                                                                                                                                                                      \
        mode == "CWM" ?    "x[-1,1] x[0,1]        dup1 dup1 min I^ max J^
                            x[1,1]  x[-1,0]       dup1 dup1 min E^ max H^
                            x[1,0]  x[-1,-1]      dup1 dup1 min D^ max G^
                            x[0,-1] x[1,-1]       dup1 dup1 min C^ max F^
                            x[0,0]  dup                         A^     B^
                            D J                   dup1 dup1 min D^ max J^
                            B I                   dup1 dup1 min B^ max I^
                            F H                   dup1 dup1 min F^ max H^
                            A G                   dup1 dup1 min A^ max G^
                            C E                   dup1 dup1 min C^ max E^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            E F                   dup1 dup1 min E^ max F^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            I J                             min I^
                            C H                   dup1 dup1 min C^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            D F                   dup1 dup1 min D^ max F^
                            A B                                    max B^
                            H I                             min H^
                            F G                             min F^
                            D E                                    max E^
                            B C                                    max C^
                            F H                             min F^
                            C E                                    max E^
                            E F                   dup1 dup1 max swap2 min

                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "CWM2" ?   "x[-1,1] x[0,1]        dup1 dup1 min D^ max L^
                            x[1,1]  x[-1,0]       dup1 dup1 min E^ max K^
                            x[1,0]  x[-1,-1]      dup1 dup1 min F^ max J^
                            x[0,-1] x[1,-1]       dup1 dup1 min A^ max I^
                            x[0,0]  dup dup dup                 B^     H^
                                                                C^     G^
                            J L                   dup1 dup1 min J^ max L^
                            H K                   dup1 dup1 min H^ max K^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            B E                   dup1 dup1 min B^ max E^
                            A C                   dup1 dup1 min A^ max C^
                            K L                             min K^
                            C J                   dup1 dup1 min C^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            F G                   dup1 dup1 min F^ max G^
                            A B                                    max B^
                            I K                             min I^
                            E J                   dup1 dup1 min E^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            B D                                    max D^
                            I J                             min I^
                            G H                             min G^
                            E F                                    max F^
                            C D                                    max D^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            F I                             min F^
                            D G                                    max G^
                            F G                   dup1 dup1 max swap2 min

                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "WMF"  ?   "x[-1,1]  x[1,1]       dup1 dup1 min K^ max P^
                            x[-1,-1] x[1,-1]      dup1 dup1 min L^ max O^
                            x[0,1]   dup                        D^     N^
                            x[-1,0]  dup                        C^     M^
                            x[0,-1]  dup                        I^     J^
                            x[1,0]   dup                        G^     H^
                            x[0,0]   dup dup dup                A^     F^
                                                                B^     E^
                            N P                   dup1 dup1 min N^ max P^
                            F O                   dup1 dup1 min F^ max O^
                            J M                   dup1 dup1 min J^ max M^
                            I L                   dup1 dup1 min I^ max L^
                            B K                   dup1 dup1 min B^ max K^
                            E H                   dup1 dup1 min E^ max H^
                            D G                   dup1 dup1 min D^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            H P                   dup1 dup1 min H^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            E N                   dup1 dup1 min E^ max N^
                            C L                   dup1 dup1 min C^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            A I                   dup1 dup1 min A^ max I^
                            B D                   dup1 dup1 min B^ max D^
                            O P                             min O^
                            L N                   dup1 dup1 min L^ max N^
                            H M                   dup1 dup1 min H^ max M^
                            J K                   dup1 dup1 min J^ max K^
                            D I                   dup1 dup1 min D^ max I^
                            F G                   dup1 dup1 min F^ max G^
                            C E                   dup1 dup1 min C^ max E^
                            A B                                    max B^
                            M O                             min M^
                            K N                             min K^
                            H L                   dup1 dup1 min H^ max L^
                            G J                   dup1 dup1 min G^ max J^
                            E I                   dup1 dup1 min E^ max I^
                            C F                                    max F^
                            B D                                    max D^
                            K M                             min K^
                            E L                   dup1 dup1 min E^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            D F                                    max F^
                            K L                             min K^
                            I J                             min I^
                            G H                                    max H^
                            E F                                    max F^
                            I K                             min I^
                            F H                                    max H^
                            H I                   dup1 dup1 max swap2 min

                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "STWM"   ? "x[-1,1]  x[1,1]       dup1 dup1 min U^ max V^
                            x[-1,-1] x[1,-1]      dup1 dup1 min S^ max T^
                            x[0,1]   dup                        Q^     R^
                            x[-1,0]  dup                        O^     P^
                            x[0,-1]  dup                        M^     N^
                            x[1,0]   dup                        K^     L^
                            x[0,0]   dup dup dup                I^     J^
                                                                G^     H^
                            y b                   dup1 dup1 min E^ max F^
                            a dup                               C^     D^
                            z dup                               A^     B^
                            J V                   dup1 dup1 min J^ max V^
                            I U                   dup1 dup1 min I^ max U^
                            P T                   dup1 dup1 min P^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            L R                   dup1 dup1 min L^ max R^
                            B N                   dup1 dup1 min B^ max N^
                            A M                   dup1 dup1 min A^ max M^
                            E K                   dup1 dup1 min E^ max K^
                            D H                   dup1 dup1 min D^ max H^
                            C G                   dup1 dup1 min C^ max G^
                            T V                   dup1 dup1 min T^ max V^
                            P U                   dup1 dup1 min P^ max U^
                            J S                   dup1 dup1 min J^ max S^
                            F R                   dup1 dup1 min F^ max R^
                            E Q                   dup1 dup1 min E^ max Q^
                            I O                   dup1 dup1 min I^ max O^
                            H N                   dup1 dup1 min H^ max N^
                            D M                   dup1 dup1 min D^ max M^
                            B G                   dup1 dup1 min B^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            N V                   dup1 dup1 min N^ max V^
                            G U                   dup1 dup1 min G^ max U^
                            H T                   dup1 dup1 min H^ max T^
                            M S                   dup1 dup1 min M^ max S^
                            K Q                   dup1 dup1 min K^ max Q^
                            B P                   dup1 dup1 min B^ max P^
                            C O                   dup1 dup1 min C^ max O^
                            F L                   dup1 dup1 min F^ max L^
                            D J                   dup1 dup1 min D^ max J^
                            A I                   dup1 dup1 min A^ max I^
                            R V                             min R^
                            L U                   dup1 dup1 min L^ max U^
                            N S                   dup1 dup1 min N^ max S^
                            M Q                   dup1 dup1 min M^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            B K                   dup1 dup1 min B^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            D I                   dup1 dup1 min D^ max I^
                            A E                                    max E^
                            S U                             min S^
                            Q T                             min Q^
                            N R                             min N^
                            M P                   dup1 dup1 min M^ max P^
                            L O                   dup1 dup1 min L^ max O^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            E I                                    max I^
                            C F                                    max F^
                            B D                                    max D^
                            J S                             min J^
                            N Q                   dup1 dup1 min N^ max Q^
                            K P                   dup1 dup1 min K^ max P^
                            D M                                    max M^
                            G L                   dup1 dup1 min G^ max L^
                            F I                   dup1 dup1 min F^ max I^
                            O Q                             min O^
                            J P                             min J^
                            K N                   dup1 dup1 min K^ max N^
                            G M                                    max M^
                            I L                   dup1 dup1 min I^ max L^
                            F H                                    max H^
                            J O                             min J^
                            L N                             min L^
                            H M                                    max M^
                            I K                                    max K^
                            K M                   dup1 dup1 min K^ max M^
                            J L                   dup1 dup1 min J^ max L^
                            L M                             min L^
                            J K                                    max K^
                            K L                   dup1 dup1 max swap2 min

                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode == "Vertical" ?"x[0,1] x[0,-1] dup1 dup1 max swap2 min
                             x swap2 clip"                                                                                                                          : \
                                                                                                                                                                      \
        mode == "verticalS"? ex_dlut("
                             x[0,-2] B2^ x[0,-1] B1^ x[0,1] T1^ x[0,2] T2^
                             B1 B2    - 0 range_max clip B1 + 0 range_max clip    T1 T2 - 0 range_max clip T1 + 0 range_max clip min B1 max T1 max
                             B1 B2 B1 - 0 range_max clip -    0 range_max clip T1 T2 T1 - 0 range_max clip    - 0 range_max clip max B1 T1 min min
                             x swap2 clip", bi, fs)                                                                                                                 : \
                                                                                                                                                                      \
        mode == "DGM0"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - AM@
                            D C - AA@ min
                            F E - AB@ min
                            H G - AC@ min
                            J I - AD@ min
                            L K - AE@ min
                            N M - AF@ min
                            P O - AG@ min
                            R Q - AH@ min
                            T S - AI@ min
                            V U - AJ@ min
                            X W - AK@ min
                            Z Y - AL@ min BB@

                               AL == x Y Z clip BB AJ == x U V clip BB AK == x W X clip BB AI == x S T clip BB AG == x O P clip BB AH == x Q R clip
                            BB AF == x M N clip BB AD == x I J clip BB AE == x K L clip BB AC == x G H clip BB AA == x C D clip BB AB == x E F clip x A B clip ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                         : \
                                                                                                                                                                     \
        mode == "DGM1"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - 4 * x dup A B clip A@ - abs + AM@
                            D C - 4 * x dup C D clip B@ - abs + AA@ min
                            F E - 4 * x dup E F clip C@ - abs + AB@ min
                            H G - 4 * x dup G H clip D@ - abs + AC@ min
                            J I - 4 * x dup I J clip E@ - abs + AD@ min
                            L K - 4 * x dup K L clip F@ - abs + AE@ min
                            N M - 4 * x dup M N clip G@ - abs + AF@ min
                            P O - 4 * x dup O P clip H@ - abs + AG@ min
                            R Q - 4 * x dup Q R clip I@ - abs + AH@ min
                            T S - 4 * x dup S T clip J@ - abs + AI@ min
                            V U - 4 * x dup U V clip K@ - abs + AJ@ min
                            X W - 4 * x dup W X clip L@ - abs + AK@ min
                            Z Y - 4 * x dup Y Z clip M@ - abs + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM2"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - 2 * x dup A B clip A@ - abs + AM@
                            D C - 2 * x dup C D clip B@ - abs + AA@ min
                            F E - 2 * x dup E F clip C@ - abs + AB@ min
                            H G - 2 * x dup G H clip D@ - abs + AC@ min
                            J I - 2 * x dup I J clip E@ - abs + AD@ min
                            L K - 2 * x dup K L clip F@ - abs + AE@ min
                            N M - 2 * x dup M N clip G@ - abs + AF@ min
                            P O - 2 * x dup O P clip H@ - abs + AG@ min
                            R Q - 2 * x dup Q R clip I@ - abs + AH@ min
                            T S - 2 * x dup S T clip J@ - abs + AI@ min
                            V U - 2 * x dup U V clip K@ - abs + AJ@ min
                            X W - 2 * x dup W X clip L@ - abs + AK@ min
                            Z Y - 2 * x dup Y Z clip M@ - abs + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM3"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - x dup A B clip A@ - abs + AM@
                            D C - x dup C D clip B@ - abs + AA@ min
                            F E - x dup E F clip C@ - abs + AB@ min
                            H G - x dup G H clip D@ - abs + AC@ min
                            J I - x dup I J clip E@ - abs + AD@ min
                            L K - x dup K L clip F@ - abs + AE@ min
                            N M - x dup M N clip G@ - abs + AF@ min
                            P O - x dup O P clip H@ - abs + AG@ min
                            R Q - x dup Q R clip I@ - abs + AH@ min
                            T S - x dup S T clip J@ - abs + AI@ min
                            V U - x dup U V clip K@ - abs + AJ@ min
                            X W - x dup W X clip L@ - abs + AK@ min
                            Z Y - x dup Y Z clip M@ - abs + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM4"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - x dup A B clip A@ - abs 2 * + AM@
                            D C - x dup C D clip B@ - abs 2 * + AA@ min
                            F E - x dup E F clip C@ - abs 2 * + AB@ min
                            H G - x dup G H clip D@ - abs 2 * + AC@ min
                            J I - x dup I J clip E@ - abs 2 * + AD@ min
                            L K - x dup K L clip F@ - abs 2 * + AE@ min
                            N M - x dup M N clip G@ - abs 2 * + AF@ min
                            P O - x dup O P clip H@ - abs 2 * + AG@ min
                            R Q - x dup Q R clip I@ - abs 2 * + AH@ min
                            T S - x dup S T clip J@ - abs 2 * + AI@ min
                            V U - x dup U V clip K@ - abs 2 * + AJ@ min
                            X W - x dup W X clip L@ - abs 2 * + AK@ min
                            Z Y - x dup Y Z clip M@ - abs 2 * + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM5"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            x dup A B clip A@ - abs AM@
                            x dup C D clip B@ - abs AA@ min
                            x dup E F clip C@ - abs AB@ min
                            x dup G H clip D@ - abs AC@ min
                            x dup I J clip E@ - abs AD@ min
                            x dup K L clip F@ - abs AE@ min
                            x dup M N clip G@ - abs AF@ min
                            x dup O P clip H@ - abs AG@ min
                            x dup Q R clip I@ - abs AH@ min
                            x dup S T clip J@ - abs AI@ min
                            x dup U V clip K@ - abs AJ@ min
                            x dup W X clip L@ - abs AK@ min
                            x dup Y Z clip M@ - abs AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                         : \
                                                                                                                                                                     \
        mode == "GaussT5" ? "z a + 4 * y b x 6 * + + + 0.062501 * "+TGth                                                                                           : \
                                                                                                                                                                     \
        mode == "medianT" ? "y z dup1 dup1 min swap2 max swap1 x max min"                                                                                          : \
                                                                                                                                                                     \
        mode == "medianT5"? "x y                   dup1 dup1 min swap2 max
                             z a                   dup1 dup1 min swap2 max
                             swap3  b              dup1 dup1 min swap2 max
                             swap2  swap1  swap3   dup1 dup1 min swap2 max
                             swap3                                     max
                             swap3                 dup1 dup1 min swap2 max
                             swap3                                     max
                             swap2                           min
                                                             min"                                                                                                  : \
                                                                                                                                                                     \
        mode == "medianST"?"x[-1,1] x[0,1]        dup1 dup1 min M^ max Z^
                            x[1,1]  x[-1,0]       dup1 dup1 min T^ max Y^
                            x[1,0]  x[-1,-1]      dup1 dup1 min R^ max X^
                            x[0,-1] x[1,-1]       dup1 dup1 min F^ max W^
                            y[-1,1] y[0,1]        dup1 dup1 min S^ max V^
                            y[1,1]  y[-1,0]       dup1 dup1 min D^ max U^
                            y[1,0]  y[-1,-1]      dup1 dup1 min J^ max Q^
                            y[0,-1] y[1,-1]       dup1 dup1 min K^ max P^
                            z[-1,1] z[0,1]        dup1 dup1 min L^ max O^
                            z[1,1]  z[-1,0]       dup1 dup1 min A^ max N^
                            z[1,0]  z[-1,-1]      dup1 dup1 min C^ max I^
                            z[0,-1] z[1,-1]       dup1 dup1 min E^ max H^
                            z[0,0]  y[0,0]        dup1 dup1 min B^ max G^
                            W Z                   dup1 dup1 min W^ max Z^
                            G Y                   dup1 dup1 min G^ max Y^
                            H V                   dup1 dup1 min H^ max V^
                            N U                   dup1 dup1 min N^ max U^
                            B T                   dup1 dup1 min B^ max T^
                            E S                   dup1 dup1 min E^ max S^
                            J R                   dup1 dup1 min J^ max R^
                            I Q                   dup1 dup1 min I^ max Q^
                            O P                   dup1 dup1 min O^ max P^
                            F M                   dup1 dup1 min F^ max M^
                            K L                   dup1 dup1 min K^ max L^
                            A D                   dup1 dup1 min A^ max D^
                            P Z                   dup1 dup1 min P^ max Z^
                            U Y                   dup1 dup1 min U^ max Y^
                            I X                   dup1 dup1 min I^ max X^
                            N W                   dup1 dup1 min N^ max W^
                            O T                   dup1 dup1 min O^ max T^
                            J S                   dup1 dup1 min J^ max S^
                            C R                   dup1 dup1 min C^ max R^
                            H Q                   dup1 dup1 min H^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            G L                   dup1 dup1 min G^ max L^
                            A K                   dup1 dup1 min A^ max K^
                            B F                   dup1 dup1 min B^ max F^
                            Y Z                   dup1 dup1 min Y^ max Z^
                            Q X                   dup1 dup1 min Q^ max X^
                            L W                   dup1 dup1 min L^ max W^
                            R V                   dup1 dup1 min R^ max V^
                            P U                   dup1 dup1 min P^ max U^
                            M T                   dup1 dup1 min M^ max T^
                            H S                   dup1 dup1 min H^ max S^
                            D O                   dup1 dup1 min D^ max O^
                            G N                   dup1 dup1 min G^ max N^
                            F K                   dup1 dup1 min F^ max K^
                            C J                   dup1 dup1 min C^ max J^
                            E I                   dup1 dup1 min E^ max I^
                            A B                   dup1 dup1 min A^ max B^
                            U Y                   dup1 dup1 min U^ max Y^
                            V X                   dup1 dup1 min V^ max X^
                            T W                   dup1 dup1 min T^ max W^
                            Q S                   dup1 dup1 min Q^ max S^
                            I R                   dup1 dup1 min I^ max R^
                            K P                   dup1 dup1 min K^ max P^
                            L O                   dup1 dup1 min L^ max O^
                            M N                   dup1 dup1 min M^ max N^
                            H J                   dup1 dup1 min H^ max J^
                            D G                   dup1 dup1 min D^ max G^
                            B F                   dup1 dup1 min B^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            X Z                             min X^
                            W Y                   dup1 dup1 min W^ max Y^
                            S V                   dup1 dup1 min S^ max V^
                            T U                   dup1 dup1 min T^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            N O                   dup1 dup1 min N^ max O^
                            L M                   dup1 dup1 min L^ max M^
                            I K                   dup1 dup1 min I^ max K^
                            E H                   dup1 dup1 min E^ max H^
                            F G                   dup1 dup1 min F^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                                    max C^
                            X Y                   dup1 dup1 min X^ max Y^
                            V W                             min V^
                            H T                   dup1 dup1 min H^ max T^
                            G S                   dup1 dup1 min G^ max S^
                            O R                             min O^
                            N Q                   dup1 dup1 min N^ max Q^
                            K P                   dup1 dup1 min K^ max P^
                            J M                   dup1 dup1 min J^ max M^
                            I L                                    max L^
                            D E                                    max E^
                            B C                   dup1 dup1 min B^ max C^
                            Q Y                             min Q^
                            O X                             min O^
                            T V                             min T^
                            S U                             min S^
                            N P                   dup1 dup1 min N^ max P^
                            K M                   dup1 dup1 min K^ max M^
                            C L                                    max L^
                            B J                                    max J^
                            F H                                    max H^
                            E G                                    max G^
                            L T                   dup1 dup1 min L^ max T^
                            M S                             min M^
                            P Q                             min P^
                            G O                   dup1 dup1 min G^ max O^
                            H N                                    max N^
                            J K                                    max K^
                            P T                             min P^
                            M O                             min M^
                            L N                                    max N^
                            G K                                    max K^
                            N P                   dup1 dup1 min N^ max P^
                            K M                   dup1 dup1 min K^ max M^
                            M P                             min M^
                            K N                                    max N^
                            M N                   dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
        mode == "SixNN" ? "x       x[0,1]        dup1 dup1 min swap2 max
                           x[0,-1] y             dup1 dup1 min swap2 max
                           swap3   z             dup1 dup1 min swap2 max
                           swap2  swap1  swap3   dup1 dup1 min swap2 max
                           swap3                                     max
                           swap3                 dup1 dup1 min swap2 max
                           swap3                                     max
                           swap2                           min
                                                           min"                                                                                                    : \
                                                                                                                                                                     \
        mode == "ML3D" ? "x[1,1]    x[-1,-1]    dup1 dup1 min swap2 max
                          x[-1,1]   x[1,-1]     dup1 dup1 min swap2 max
                          x[0,0] X@ y[0,0] Y@   dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min A^

                          x[1,0]  x[0,-1]       dup1 dup1 min swap2 max
                          x[-1,0] x[0,1]        dup1 dup1 min swap2 max
                          X  Y                  dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min A

                          dup1 dup1 min swap2 max swap1 X max min"                                                                                                 : \
                                                                                                                                                                     \
        mode == "ML3Dex"? "x[1,1]   x[-1,-1]    dup1 dup1 min swap2 max
                          x[-1,1]   x[1,-1]     dup1 dup1 min swap2 max
                          x[0,0] X@ y[0,0] Y@   dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min A^

                          x[1,0]  x[0,-1]       dup1 dup1 min swap2 max
                          x[-1,0] x[0,1]        dup1 dup1 min swap2 max
                          X       Y             dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min  B^

                          y[1,1]  y[-1,-1]      dup1 dup1 min swap2 max
                          y[-1,1] y[1,-1]       dup1 dup1 min swap2 max
                          Y       X             dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min C^

                          y[1,0]  y[0,-1]       dup1 dup1 min swap2 max
                          y[-1,0] y[0,1]        dup1 dup1 min swap2 max
                          Y       X             dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min D^

                          X Y dup1 dup1 min swap2 max swap1 Z max min

                            A                   dup1 dup1 min swap2 max
                          B C                   dup1 dup1 min swap2 max
                          swap3  D              dup1 dup1 min swap2 max
                          swap2  swap1  swap3   dup1 dup1 min swap2 max
                          swap3                                     max
                          swap3                 dup1 dup1 min swap2 max
                          swap3                                     max
                          swap2                           min
                                                          min"                                                                                                     : \
                                                                                                                                                                     \
        mode == "BDM" ? "x[1,1]    x[-1,-1]    dup1 dup1 min swap2 max
                         x[-1,1]   x[1,-1]     dup1 dup1 min swap2 max
                         x[0,0] X@ y[0,0] Y@   dup1 dup1 min swap2 max
                         swap5  swap1  swap3   dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap2  swap1  swap5                       max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap4  swap1  swap2   dup1 dup1 min swap2 max
                         swap3  swap1  swap2                       max
                         swap2  swap1  swap4             min
                         swap3                                     max
                         swap2                           min
                                                         min T^

                         y[1,1]  y[-1,-1]      dup1 dup1 min B^ max K^
                         y[-1,1] y[1,-1]       dup1 dup1 min E^ max J^
                         z[1,1]  z[-1,-1]      dup1 dup1 min G^ max I^
                         z[-1,1] z[1,-1]       dup1 dup1 min D^ max H^
                         Y       Z             dup1 dup1 min C^ max F^
                         J K                   dup1 dup1 min J^ max K^
                         F H                   dup1 dup1 min F^ max H^
                         G       X             dup1 dup1 min A^ max G^
                         B E                   dup1 dup1 min B^ max E^
                         C D                   dup1 dup1 min C^ max D^
                         H J                   dup1 dup1 min H^ max J^
                         F I                   dup1 dup1 min F^ max I^
                         D G                   dup1 dup1 min D^ max G^
                         A C                                    max C^
                         G K                             min G^
                         I J                             min I^
                         D H                   dup1 dup1 min D^ max H^
                         B F                                    max F^
                         C E                   dup1 dup1 min C^ max E^
                         E I                   dup1 dup1 min E^ max I^
                         F G                   dup1 dup1 min F^ max G^
                         C D                                    max D^
                         G I                             min G^
                         E H                   dup1 dup1 min E^ max H^
                         D F                                    max F^
                         G H                             min G^
                         E F                                    max
                           G                             min U^

                         y[1,0]  y[0,-1]       dup1 dup1 min B^ max K^
                         y[-1,0] y[0,1]        dup1 dup1 min E^ max J^
                         z[1,0]  z[0,-1]       dup1 dup1 min G^ max I^
                         z[-1,0] z[0,1]        dup1 dup1 min D^ max H^
                         Y       Z             dup1 dup1 min C^ max F^
                         J K                   dup1 dup1 min J^ max K^
                         F H                   dup1 dup1 min F^ max H^
                         G       X             dup1 dup1 min A^ max G^
                         B E                   dup1 dup1 min B^ max E^
                         C D                   dup1 dup1 min C^ max D^
                         H J                   dup1 dup1 min H^ max J^
                         F I                   dup1 dup1 min F^ max I^
                         D G                   dup1 dup1 min D^ max G^
                         A C                                    max C^
                         G K                             min G^
                         I J                             min I^
                         D H                   dup1 dup1 min D^ max H^
                         B F                                    max F^
                         C E                   dup1 dup1 min C^ max E^
                         E I                   dup1 dup1 min E^ max I^
                         F G                   dup1 dup1 min F^ max G^
                         C D                                    max D^
                         G I                             min G^
                         E H                   dup1 dup1 min E^ max H^
                         D F                                    max F^
                         G H                             min G^
                         E F                                    max
                           G                             min V^

                         X Y dup1 dup1 min swap2 max swap1 Z max min

                         dup T min U min V min swap1 T max U max V max

                         dup1 dup1 min swap2 max swap1 X max min"                                                                                                  : \
                                                                                                                                                                     \
        mode == "MMF" ? "x[0,0]  X@ x[0,1] A@  dup1 dup1 min swap2 max
                         x[0,-1] B@ y[0,0] Y@  dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min J^

                         X x[1,0] D@           dup1 dup1 min swap2 max
                         x[-1,0]  E@ Y         dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min K^

                         x[1,1]   F@ X         dup1 dup1 min swap2 max
                         x[-1,-1] G@ Y         dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min L^

                         x[-1,1] H@ X          dup1 dup1 min swap2 max
                         x[1,-1] I@ Y          dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min M^

                         Y Z dup1 dup1 min swap2 max swap1 X max min N^
                         F G dup1 dup1 min swap2 max swap1 X max min O^
                         H I dup1 dup1 min swap2 max swap1 X max min P^
                         A B dup1 dup1 min swap2 max swap1 X max min Q^
                         D E dup1 dup1 min swap2 max swap1 X max min R^

                         J K max L max M max N max O max P max Q max R max
                         J K min L min M min N min O min P min Q min R min
                         dup1 dup1 min swap2 max swap1 X max min"                                                                                                  : \
                                                                                                                                                                     \
        mode == "PML" ? "x[0,0]  X@ x[0,1] A@  dup1 dup1 min swap2 max
                         x[0,-1] B@ y[0,0] Y@  dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min J^

                         x[1,0]  C@ X          dup1 dup1 min swap2 max
                         x[-1,0] D@ Y          dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min K^

                         A B                   dup1 dup1 min swap2 max
                         C D                   dup1 dup1 min swap2 max
                         swap3  X              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min

                         J dup1 dup1 min swap2 max swap1 K max min"                                                                                                : \
                                                                                                                                                                     \
                         Assert (false, mode+": Unsupported median mode.")


    temp5 = mode == "medianT5" || mode == "STWM" || mode == "GaussT5"
    temp  = mode == "medianT" || mode == "medianST" || mode == "ML3D" || mode == "ML3Dex" || mode == "BDM" || mode == "MMF" || mode == "SixNN" || mode == "PML" ||  temp5 || \
            mode == "DGM0"  || mode == "DGM1" || mode == "DGM2"  || mode == "DGM3" || mode == "DGM4"  || mode == "DGM5"

    if (temp) {

        b  =         rc ? a.selectevery(1,-1).ex_median(mode,thr,false,UV,fs) : a.selectevery(1,-1)
        f  =                                                                    a.selectevery(1,+1)
        b2 = temp5 ? rc ? b.selectevery(1,-1) :                                 a.selectevery(1,-2) : nop()
        f2 = temp5 ?                                                            a.selectevery(1,+2) : nop()

       !temp5                                                                                                             ? \
        isy     ? Expr(a, b,     f,     str,                                  optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, b,     f,     str, "",                              optSingleMode = false                     ) : \
                  Expr(a, b,     f,     str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = false, scale_inputs="none") : \
        isy     ? Expr(a, b2, b, f, f2, str,                                  optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, b2, b, f, f2, str, "",                              optSingleMode = false                     ) : \
                  Expr(a, b2, b, f, f2, str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = false, scale_inputs="none")

    } else {

        isy     ? Expr(a, str,                                  optSingleMode = mode == "PWM"                           ) : \
        UV == 1 ? Expr(a, str, "",                              optSingleMode = mode == "PWM"                           ) : \
                  Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = mode == "PWM",       scale_inputs="none") } }




##############################
##
## Repair
##
## Replaces Repair() (only listed modes) and TemporalRepair() (which plugin seems broken)
##
## Requires AviSynth+ 3.7.1 test12 or above
## https://forum.doom9.org/showthread.php?t=181351
##
## median    - repair(4)
## medianc   - repair(14)
## undot     - repair(1)
## undot2    - repair(2)
## undot3    - repair(3)
## undot4    - repair(4)
## undot4c   - repair(14)
## edgeSP    - repair(16). Edge sensitive with line pairs. Fair edge repair. (analogue to removegrain(6))
## edgeS     - repair(17)
## edgeW     - repair(18)
## cartoon   - repair(22)
## cartoonc  - repair(19)
## temp0     - TemporalRepair mode=0
## temp1     - TemporalRepair mode=1
## temp2     - TemporalRepair mode=2
## temp3     - TemporalRepair mode=3
## temp4     - TemporalRepair mode=4

function ex_repair(clip a, clip b, string "mode", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    mode = Default(mode,  "undot2")
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    str =                                                                                                                                                            \
                                                                                                                                                                     \
        mode == "median5"? "y[-2,-2] y[-2,-1]     dup1 dup1 min W^ max Y^
                            y[-2,0]  y[-2,1]      dup1 dup1 min Q^ max X^
                            y[-2,2]  y[-1,-2]     dup1 dup1 min G^ max V^
                            y[-1,-1] y[-1,0]      dup1 dup1 min H^ max U^
                            y[-1,1]  y[-1,2]      dup1 dup1 min E^ max T^
                            y[0,-2]  y[0,-1]      dup1 dup1 min F^ max S^
                            y[0,0]   y[0,1]       dup1 dup1 min P^ max R^
                            y[0,2]   y[1,-2]      dup1 dup1 min N^ max O^
                            y[1,-1]  y[1,0]       dup1 dup1 min L^ max M^
                            y[1,1]   y[1,2]       dup1 dup1 min I^ max K^
                            y[2,-2]  y[2,-1]      dup1 dup1 min C^ max J^
                            y[2,0]   y[2,1]       dup1 dup1 min B^ max D^
                            V Y                   dup1 dup1 min V^ max Y^
                            J X                   dup1 dup1 min J^ max X^
                            G W                   dup1 dup1 min G^ max W^
                            M U                   dup1 dup1 min M^ max U^
                            D T                   dup1 dup1 min D^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            K R                   dup1 dup1 min K^ max R^
                            C Q                   dup1 dup1 min C^ max Q^
                            I P                   dup1 dup1 min I^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            H L                   dup1 dup1 min H^ max L^
                            B E                   dup1 dup1 min B^ max E^
                            U Y                   dup1 dup1 min U^ max Y^
                            R X                   dup1 dup1 min R^ max X^
                            L W                   dup1 dup1 min L^ max W^
                            M V                   dup1 dup1 min M^ max V^
                            S T                   dup1 dup1 min S^ max T^
                            K Q                   dup1 dup1 min K^ max Q^
                            J P                   dup1 dup1 min J^ max P^
                            D O                   dup1 dup1 min D^ max O^
                            E N                   dup1 dup1 min E^ max N^
                            C I                   dup1 dup1 min C^ max I^
                            G H                   dup1 dup1 min G^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            T Y                             min T^
                            N W                   dup1 dup1 min N^ max W^
                            S V                   dup1 dup1 min S^ max V^
                            O U                   dup1 dup1 min O^ max U^
                            I R                   dup1 dup1 min I^ max R^
                            P Q                   dup1 dup1 min P^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            F L                   dup1 dup1 min F^ max L^
                            J K                   dup1 dup1 min J^ max K^
                            E H                   dup1 dup1 min E^ max H^
                            B G                   dup1 dup1 min B^ max G^
                            R W                   dup1 dup1 min R^ max W^
                            P S                   dup1 dup1 min P^ max S^
                            N Q                   dup1 dup1 min N^ max Q^
                            K y[2,2]              dup1 dup1 min A^ max K^
                            D G                   dup1 dup1 min D^ max G^
                            Q V                             min Q^
                            O R                   dup1 dup1 min O^ max R^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            D J                   dup1 dup1 min D^ max J^
                            E G                   dup1 dup1 min E^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            L U                   dup1 dup1 min L^ max U^
                            I O                   dup1 dup1 min I^ max O^
                            J N                   dup1 dup1 min J^ max N^
                            A G                   dup1 dup1 min A^ max G^
                            C F                   dup1 dup1 min C^ max F^
                            U X                             min U^
                            N Q                   dup1 dup1 min N^ max Q^
                            F P                   dup1 dup1 min F^ max P^
                            H L                   dup1 dup1 min H^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            E I                   dup1 dup1 min E^ max I^
                            A B                                    max B^
                            T U                             min T^
                            L S                   dup1 dup1 min L^ max S^
                            K P                   dup1 dup1 min K^ max P^
                            H O                   dup1 dup1 min H^ max O^
                            I M                   dup1 dup1 min I^ max M^
                            F G                   dup1 dup1 min F^ max G^
                            D E                                    max E^
                            B C                                    max C^
                            S W                             min S^
                            L T                   dup1 dup1 min L^ max T^
                            P R                   dup1 dup1 min P^ max R^
                            G M                   dup1 dup1 min G^ max M^
                            H J                   dup1 dup1 min H^ max J^
                            F I                                    max I^
                            C E                                    max E^
                            Q T                             min Q^
                            R S                             min R^
                            O P                   dup1 dup1 min O^ max P^
                            L N                   dup1 dup1 min L^ max N^
                            J K                   dup1 dup1 min J^ max K^
                            E H                                    max H^
                            N R                             min N^
                            P Q                             min P^
                            L O                   dup1 dup1 min L^ max O^
                            K M                   dup1 dup1 min K^ max M^
                            I J                                    max J^
                            G H                                    max H^
                            M P                             min M^
                            N O                             min N^
                            K L                                    max L^
                            H J                                    max J^
                            M N                             min M^
                            J L                                    max L^
                            L M                   dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
        mode == "undot" ?  "y[-1,1] A@ y[0,1] B@ max y[1,1] C@ y[-1,0] D@ max max y[1,0] F@ y[-1,-1] G@ max y[0,-1] H@ y[1,-1] I@ max max max
                            A B min C D min min F G min H I min min min x swap2 clip"                                                                              : \
                                                                                                                                                                     \
        mode == "undot2" ? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  y[0,0]         dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap8   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap8  swap1  swap3   dup1 dup1 min swap2 max
                            swap7  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap5                       max
                            swap5  swap1  swap6             min
                            swap3                           min
                            swap5                           min
                            swap4                           min
                            swap3  swap1  swap2                       max
                            swap2                           min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
        mode == "undot3" ? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  y[0,0]         dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap8   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap8  swap1  swap3   dup1 dup1 min swap2 max
                            swap7  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap5                       max
                            swap5  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7             min
                            swap3  swap1  swap6             min
                            swap5                                     max
                            swap3                           min
                            swap3                                     max
                            swap2                                     max
                            x swap2 swap1 clip"                                                                                                                    : \
                                                                                                                                                                     \
        mode == "undot4" ||                                                                                                                                          \
        mode == "median" ? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  y[0,0]         dup1 dup1 min swap2 max
                            swap5  swap1  swap8                       max
                            swap5                 dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap2                       max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap3   dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap5   dup1 dup1 min swap2 max
                            swap2  swap1  swap6             min
                            swap4  swap1  swap5                       max
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap3                           min
                            swap2                           min
                            x swap2 swap1 clip"                                                                                                                    : \
                                                                                                                                                                     \
        mode == "undot4c" ||                                                                                                                                         \
        mode == "medianc"? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap5  swap1  swap3             min
                            swap2  swap1  swap3                       max
                            swap2                           min
                            swap2                                     max
                            y max swap y min
                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
        mode=="edgeSP"   ? ex_dlut("
                            y[1,-1] y[-1,1]  dup1 dup1 min A^ max B^
                            y[1,1]  y[-1,-1] dup1 dup1 min C^ max D^
                            y[0,1]  y[0,-1]  dup1 dup1 min E^ max F^
                            y[1,0]  y[-1,0]  dup1 dup1 min G^ max H^

                            y dup A B clip A@ - abs 2 * B A - + 0 range_max clip
                            y dup C D clip B@ - abs 2 * D C - + 0 range_max clip AA@ min
                            y dup E F clip C@ - abs 2 * F E - + 0 range_max clip AB@ min
                            y dup G H clip D@ - abs 2 * H G - + 0 range_max clip AC@ min BB@

                               AC == x y G min y H max clip
                            BB AA == x y C min y D max clip
                            BB AB == x y E min y F max clip
                                     x y A min y B max clip ? ? ?", bi, fs)                                                                                         : \
                                                                                                                                                                      \
        mode == "edgeS"  ? "y[-1,0] y[1,0]   dup1 dup1 min swap2 max
                            y[1,1]  y[-1,-1] dup1 dup1 min swap2 max
                            y[0,1]  y[0,-1]  dup1 dup1 min swap2 max
                            y[-1,1] y[1,-1]  dup1 dup1 min swap2 max
                            swap3             max swap2 min
                            swap3 swap1 swap5 max swap3 min
                                              min swap2 max
                                    dup1 dup1 min swap2 max
                            y max swap y min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
        mode == "edgeW"  ? "                                              y[0,0] I@ y[0,1]  B@ - abs I y[0,-1] G@ - abs max BB@
                            I y[1,1]  C@ - abs I y[-1,-1] F@ - abs max CC@ min   I  y[-1,0] D@ - abs I y[1,0]  E@ - abs max DD@ min
                            I y[-1,1] A@ - abs I y[1,-1] H@ - abs max      min
                            S@ DD == x D E dup1 dup1 min I min swap2 max I max clip  S BB == x B G dup1 dup1 min I min swap2 max I max clip
                            S  CC == x C F dup1 dup1 min I min swap2 max I max clip          x A H dup1 dup1 min I min swap2 max I max clip ? ? ?"                 : \
                                                                                                                                                                     \
        mode == "cartoonc"? ex_dlut("y[0,0] Y@ y[1,1] - abs Y y[1,0] - abs min Y y[1,-1] - abs min Y y[-1,1] - abs min Y y[-1,0] - abs min Y y[-1,-1] - abs min Y y[0,1] - abs min Y y[0,-1] - abs min
                                     DI@ Y + range_max min Y DI - 0 max x swap2 clip", bi, fs)                                                                     : \
                                                                                                                                                                     \
        mode == "cartoon" ? ex_dlut("x[0,0] X@ y[1,1] - abs X y[1,0] - abs min X y[1,-1] - abs min X y[-1,1] - abs min X y[-1,0] - abs min X y[-1,-1] - abs min X y[0,1] - abs min X y[0,-1] - abs min
                                     DI@ X + range_max min X DI - 0 max y swap2 clip", bi, fs)                                                                     : \
                                                                                                                                                                     \
        mode == "temp0"  ? "y z max a max y z min a min x swap2 clip"                                                                                              : \
                                                                                                                                                                     \
        mode == "temp1"  ? "y[-1,-1] z[-1,-1]      dup1 dup1 min swap2 max
                            x[-1,-1] dup swap3 - swap2 -
                            y[-1,0]  z[-1,0]       dup1 dup1 min swap2 max
                            x[-1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[-1,1]  z[-1,1]       dup1 dup1 min swap2 max
                            x[-1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,-1]  z[1,-1]       dup1 dup1 min swap2 max
                            x[1,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,0]  z[1,0]         dup1 dup1 min swap2 max
                            x[1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,1]  z[1,1]         dup1 dup1 min swap2 max
                            x[1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,-1]  z[0,-1]       dup1 dup1 min swap2 max
                            x[0,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,1]  z[0,1]         dup1 dup1 min swap2 max
                            x[0,1] dup swap3 - swap2 -
                            swap3 max swap2 max

                            x[0,0] + y[0,0] Y@ max z[0,0] Z@ max
                            swap x[0,0] swap - Y min Z min
                            a swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
        mode == "temp2"  ? "y[-1,-1] z[-1,-1]      dup1 dup1 min swap2 max
                            x[-1,-1] dup swap3 - swap2 -
                            y[-1,0]  z[-1,0]       dup1 dup1 min swap2 max
                            x[-1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[-1,1]  z[-1,1]       dup1 dup1 min swap2 max
                            x[-1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,-1]  z[1,-1]       dup1 dup1 min swap2 max
                            x[1,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,0]  z[1,0]         dup1 dup1 min swap2 max
                            x[1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,1]  z[1,1]         dup1 dup1 min swap2 max
                            x[1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,-1]  z[0,-1]       dup1 dup1 min swap2 max
                            x[0,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,1]  z[0,1]         dup1 dup1 min swap2 max
                            x[0,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,0]  z[0,0]         dup1 dup1 min swap2 max
                            x[0,0] X@ dup swap3 - swap2 -
                            swap3 max swap2 max max
                            dup X + swap X swap - a swap2 clip"                                                                                                    : \
                                                                                                                                                                     \
        mode == "temp3"  ? "x[-1,-1] A@   y[-1,-1] - abs
                            x[-1,0]  B@   y[-1,0]  - abs max
                            A             z[-1,-1] - abs
                            B             z[-1,0]  - abs max
                            x[-1,1] dup   y[-1,1]  - abs
                            swap          z[-1,1]  - abs
                            swap3 max swap2 max
                            x[1,-1] dup   y[1,-1]  - abs
                            swap          z[1,-1]  - abs
                            swap3 max swap2 max
                            x[1,0] dup    y[1,0]   - abs
                            swap          z[1,0]   - abs
                            swap3 max swap2 max
                            x[1,1] dup    y[1,1]   - abs
                            swap          z[1,1]   - abs
                            swap3 max swap2 max
                            x[0,-1] dup   y[0,-1]  - abs
                            swap          z[0,-1]  - abs
                            swap3 max swap2 max
                            x[0,1] dup    y[0,1]   - abs
                            swap          z[0,1]   - abs
                            swap3 max swap2 max
                            x[0,0] X@ dup y[0,0]   - abs
                            swap          z[0,0]   - abs
                            swap3 max swap2 max min
                            dup X + swap X swap - a swap2 clip"                                                                                                    : \
                                                                                                                                                                     \
        mode == "temp4"  ? "a y z min N@ - 0 max dup + N + y z max M@ min O^
                            M dup a - 0 max dup + - N max P@
                              M == N O == or a x P O clip ?"                                                                                                       : \
                                                                                                                                                                     \
                            Assert (false, mode+"Unsupported repair mode.")


    if (FindStr(mode, "emp")>0) {

        c  = a.selectevery(1,-1)
        d  = a.selectevery(1,+1)

        isy     ? Expr(a, c, d, b, str,                                  optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, c, d, b, str, "",                              optSingleMode = false                     ) : \
                  Expr(a, c, d, b, str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = false, scale_inputs="none")

    } else {

        isy     ? Expr(a, b,       str                                                                             ) : \
        UV == 1 ? Expr(a, b,       str, ""                                                                         ) : \
                  Expr(a, b,       str, ex_UVexpr(str, UV, bi, rgb, fs),                        scale_inputs="none") } }



##################
## MORPHOLOGICAL #
##################
##
## Opening: To clean small blotches
##   ex_inpand(n).ex_expand(n)
##
## Closing: To close gaps
##   ex_expand(n).ex_inpand(n)
##
## Smooth: Opening & Closing, effectively cleaning binary images
##   ex_inpand(n).ex_expand(n+n).ex_inpand(n)
##
## Outline: To reveal the outer edge of a shape
##   ex_makediff(ex_expand(n), a, dif=false)
##   or
##   ex_luts(mode="range+",pixels=ex_shape(n)) # faster
##   or
##   ex_hitormiss(mode="outline")              # binary only
##
## Inline: To reveal the inner edge of a shape
##   ex_makediff(a, ex_inpand(n), dif=false)
##   or
##   ex_luts(mode="range-",pixels=ex_shape(n)) # faster
##   or
##   ex_hitormiss(mode="inline")               # binary only
##
## Gradient Magnitude: To reveal the boundary of elements in a binary image
##   ex_makediff(ex_expand(n), ex_inpand(n), dif=false)
##   or
##   ex_edge("min/max")                        # faster
##   or
##   ex_luts(mode="range",pixels=ex_shape(n))  # faster for higher radii
##   or
##   ex_hitormiss(mode="boundary")             # binary only
##
## Top Hat:   (a - opening) To reveal bright elements (use kernel wisely) over dark backgrounds on a greyscale image
##   ex_makediff(a, ex_inpand(n).ex_expand(n), dif=false)
##
## Black Hat: (closing - a) To reveal dark elements (use kernel wisely) over bright backgrounds on a greyscale image
##   ex_makediff(ex_expand(n).ex_inpand(n), a, dif=false)
##
## Pseudomedian: (opening + closing)/2  Approximation to a simple median filter with morphological structuring elements
##   Merge(ex_inpand(n).ex_expand(n), ex_expand(n).ex_inpand(n))
##
## Contrast Enhancement: (a + Top Hat - Black Hat)  Contrast enhancement similar to an unsharp mask
##   ex_makeadddiff( ex_makediff(a, ex_inpand(n).ex_expand(n),    dif=false), \
##                   ex_makediff(   ex_expand(n).ex_inpand(n), a, dif=false), \
##                                                             a)
##   or
##   ex_lutxyz(a, ex_inpand(n).ex_expand(n), ex_expand(n).ex_inpand(n), "x y -  z x -  -  x +") # faster
##


# mt_expand() is 6% faster (6% slower when radius = 2)
# modes: square, circle, disk, ring, diamond, plus, cross, vertical, horizontal
# 'circle' + radius=2 is like calling mode="plus" twice but faster
function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    th = ex_bs(thr, 8, bi, fulls=fs)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    strh = ""    krn  = ""
    if (mode != "square" && mode != "vertical" && mode != "horizontal") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                skip = mode == "plus"    ?  px != 0 && py != 0                                        : \
                       mode == "circle"  ? (px*px + py*py) > krnlrd*krnlrd                            : \
                       mode == "disk"    ? (px*px + py*py) > (krnlrd+0.3)*(krnlrd+0.3)                : \
                       mode == "diamond" ? (abs(px) != 0 && abs(py) != 0) &&                            \
                                           (abs(px) > krnlrd - abs(py) || abs(py) > krnlrd - abs(px)) : \
                       mode == "cross"   ? (px + py != 0) && (abs(px) != abs(py))                     : \
                       mode == "ring"    ? (px*px + py*py) > pow(krnlrd+0.3,   2) ||                    \
                                         !((px*px + py*py) > pow(krnlrd+0.3-1, 2))                    : \
                                            false
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
# modes: square, circle, disk, ring, diamond, plus, cross, vertical, horizontal
function ex_inpand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    th  = ex_bs(thr, 8, bi, fulls=fs)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    strh = ""    krn  = ""
    if (mode != "square" && mode != "vertical" && mode != "horizontal") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                skip = mode == "plus"    ?  px != 0 && py != 0                                        : \
                       mode == "circle"  ? (px*px + py*py) > krnlrd*krnlrd                            : \
                       mode == "disk"    ? (px*px + py*py) > (krnlrd+0.3)*(krnlrd+0.3)                : \
                       mode == "diamond" ? (abs(px) != 0 && abs(py) != 0) &&                            \
                                           (abs(px) > krnlrd - abs(py) || abs(py) > krnlrd - abs(px)) : \
                       mode == "cross"   ? (px + py != 0) && (abs(px) != abs(py))                     : \
                       mode == "ring"    ? (px*px + py*py) > pow(krnlrd+0.3,   2) ||                    \
                                         !((px*px + py*py) > pow(krnlrd+0.3-1, 2))                    : \
                                            false
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
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""    pls = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = Format(krn + "x[{px},{py}] ")
            pls = py < -krnlrd+2 && px == -krnlrd ? pls + "" : pls + "+ "
           }
       }

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(1./(krnlsz*krnlsz-1)) + " * x min"

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# mt_inflate() is 14% faster (lower gap with bigger radius)
function ex_inflate(clip a, int "radius", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd = Default(radius, 1)
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""    pls = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = Format(krn + "x[{px},{py}] ")
            pls = py < -krnlrd+2 && px == -krnlrd ? pls + "" : pls + "+ "
           }
       }

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(1./(krnlsz*krnlsz-1)) + " * x max"

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# Hit-or-Miss morphological transform (HMT)
#                  to use with binary masks
#
# Requires AviSynth+ 3.7.1 (for string line carriage)
# https://forum.doom9.org/showthread.php?t=181351
#
# modes:
# thin         - Like erode (inpand) but one pixel at a time without complete removal (leads to 'skeleton')
# thicken      - Like dilate (expand) but one pixel at a time without element merging (leads to 'SKIZ')
# prune        - To remove thin branches from the main binary element bodies
# pruneS       - Prune strong
# boundary     - Get the boundary edge of the element bodies
# outline      - Get the outline  edge of the element bodies
# inline       - Get the inline   edge of the element bodies
# convexhull   - Minimal geometry representation of the element body (fills concave contours)
# convexhull45 - 45º convex hull approximation
# corner       - Detects right angle pixel corners (ie. jaggies) (WIP)
# cornerS      - Corner strong
# skeleton     - Minimal 1 pixel representation of element bodies in binary image                            (iterate 'thin' until stable -no more changes-)
# SKIZ         - Skeleton by zone of influence. Also known as background skeletonization or Voronoi diagram. (iterate 'thicken' or 'convexhull' until stable)
# end          - Extracts end pixels      (to be used after skeleton)
# junction     - Extracts junction pixels (to be used after skeleton). Also known as branched points
# 4-connected  - Extracts connected components by shared edges
# 8-connected  - Extracts connected components by a Chebyshev distance of 1
# fill         - (Boundary) fill element bodies (not implemented)
#
function ex_hitormiss(clip a, int "radius", string "mode", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd = Default(radius, 1)
    md = Default(mode, "thin")
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    !(md == "thin" || md == "thicken" || md == "prune" || md == "pruneS" || md == "convexhull" || md == "convexhull45") ? \
    Assert(rd == 1, md+" mode only supports radius=1") : nop()

    if (rd > 1) {

        ex_hitormiss(a,   rd-1,  md, UV, fs)
        ex_hitormiss(last,   1,  md, UV, fs)

    } else {

        # 'thin', 'thicken', 'prune' and 'end'
        krn1 = "range_max x[-1,-1] A@ - O^ range_max  x[0,-1] B@ - P^ range_max x[1,-1] C@ - Q^
                range_max x[-1,0]  D@ - R^            x[0,0]  E^      range_max x[1,0]  F@ - T^
                range_max x[-1,1]  G@ - U^ range_max  x[0,1]  H@ - V^ range_max x[1,1]  I@ - W^ "

        # 'pruneS' and 'convexhull'
        krn2 = "range_max x[-1,-1] - O^ range_max  x[0,-1] - P^ range_max x[1,-1] - Q^
                range_max x[-1,0]  - R^            x[0,0]    E^ range_max x[1,0]  - T^
                range_max x[-1,1]  - U^ range_max  x[0,1]  - V^ range_max x[1,1]  - W^ "

        # 'inline', 'outline', 'boundary', 'junction', '4-connected' and '8-connected'
        krn3 = "x[-1,-1] A^ x[0,-1] B^ x[1,-1] C^
                x[-1,0]  D^ x[0,0]  E^ x[1,0]  F^
                x[-1,1]  G^ x[0,1]  H^ x[1,1]  I^ "

        # 'convexhull45'
        krn4 = "range_max x[-1,-1] A@ - O^ range_max  x[0,-1] - P^ range_max x[1,-1] C@ - Q^
                range_max x[-1,0]     - R^            x[0,0]    E^ range_max x[1,0]     - T^
                range_max x[-1,1]  G@ - U^ range_max  x[0,1]  - V^ range_max x[1,1]  I@ - W^ "

        # 'corner' and 'cornerS'
        krn5 = "range_max x[-1,-1]    - O^ range_max  x[0,-1] B@ - P^ range_max x[1,-1]   - Q^
                range_max x[-1,0]  D@ - R^            x[0,0]  E^      range_max x[1,0] F@ - T^
                range_max x[-1,1]     - U^ range_max  x[0,1]  H@ - V^ range_max x[1,1]    - W^ "

    # Structuring Elements
    str = md == "thin"       ?  krn1+                                                                               \
                               "O P min Q min E min G min H min I min
                                P Q min T min D min E min G min H min max
                                Q T min W min A min D min G min E min max
                                T V min W min A min D min B min E min max
                                U V min W min A min B min C min E min max
                                R U min V min B min E min C min F min max
                                O R min U min C min F min I min E min max
                                O P min R min E min H min F min I min max range_max swap - x *"                   : \
                                                                                                                    \
          md == "thicken"    ?  krn1+                                                                               \
                               "O P max Q max E max G max H max I max
                                P Q max T max D max E max G max H max min
                                Q T max W max A max D max G max E max min
                                T V max W max A max D max B max E max min
                                U V max W max A max B max C max E max min
                                R U max V max B max E max C max F max min
                                O R max U max C max F max I max E max min
                                O P max R max E max H max F max I max min range_max x - * range_max swap -"      : \
                                                                                                                   \
          md == "prune"      ?  krn1+                                                                              \
                               "P Q min T min W min V min D min E min
                                R U min V min W min T min B min E min max
                                O P min R min U min V min F min E min max
                                O R min P min Q min T min H min E min max
                                P Q min T min W min V min U min R min A min E min max
                                P O min T min W min V min U min R min C min E min max
                                P Q min T min O min V min U min R min I min E min max
                                P Q min T min W min V min O min R min G min E min max range_max swap - x *"      : \
                                                                                                                   \
          md == "pruneS"     ?  krn2+                                                                              \
                               "Q T min W min V min U min R min E min
                                O P min W min V min U min R min E min max
                                O P min Q min T min U min R min E min max
                                O P min Q min T min W min V min E min max
                                T W min V min U min R min O min E min max
                                P Q min V min U min R min O min E min max
                                P Q min W min T min R min O min E min max
                                P Q min W min T min U min V min E min max range_max swap - x *"                  : \
                                                                                                                   \
          md == "inline"     ?  krn3+"A B min C min D min E min F min G min H min I min range_max swap - x *"    : \
                                                                                                                   \
          md == "outline"    ?  krn2+"O P min Q min R min range_max E - min T min U min V min W min range_max swap - range_max x - *" : \
                                                                                                                   \
          md == "boundary"   ?  krn3+                                                                              \
                                "A B max C max D max E max F max G max H max I max
                                 A B min C min D min E min F min G min H min I min - "                           : \
                                                                                                                   \
          md == "convexhull" ?  krn2+                                                                              \
                               "O R max U max E max
                                O P max Q max E max min
                                Q T max W max E max min
                                U V max W max E max min range_max x - * range_max swap -"                        : \
                                                                                                                   \
          md =="convexhull45"?  krn4+                                                                              \
                               "O R max U max P max E max I max
                                O P max Q max T max E max G max min
                                Q T max W max V max E max A max min
                                W V max U max R max E max C max min
                                P Q max T max W max E max G max min
                                U V max W max T max E max A max min
                                O R max U max V max E max C max min
                                O R max P max Q max E max I max min range_max x - * range_max swap -"            : \
                                                                                                                   \
          md == "junction"   ?  krn3+                                                                              \
                               "A C min E min H min
                                B E min F min G min max
                                D E min C min I min max
                                A E min F min H min max
                                B E min G min I min max
                                D E min H min C min max
                                A E min G min F min max
                                D E min B min I min max
                                A E min I min G min max
                                A E min C min G min max
                                A E min C min I min max
                                G E min C min I min max"                                                         : \
                                                                                                                   \
          md == "4-connected"?  krn3+                                                                              \
                               "B E min
                                D E min max
                                F E min max
                                H E min max"                                                                     : \
                                                                                                                   \
          md == "8-connected"?  krn3+                                                                              \
                               "B E min
                                D E min max
                                F E min max
                                H E min max
                                A E min max
                                C E min max
                                G E min max
                                I E min max"                                                                     : \
                                                                                                                   \
          md == "end"        ?  krn1+                                                                              \
                               "Q T min P min O min R min E min H min
                                Q T min W min V min P min E min D min max
                                U T min W min V min R min E min B min max
                                U P min O min V min R min E min F min max
                                O P min Q min U min R min E min I min max
                                O P min Q min W min T min E min G min max
                                Q T min W min V min U min E min A min max
                                O R min U min V min W min E min C min max"                                       : \
                                                                                                                   \
          md == "corner"     ?  krn5+                                                                              \
                               "V R min U min E min B min F min
                                T W min V min E min B min D min max
                                P Q min T min E min D min H min max
                                O P min R min E min F min H min max"                                             : \
                                                                                                                   \
          md == "cornerS"    ?  krn5+                                                                              \
                               "V R min U min B min F min
                                T W min V min B min D min max
                                P Q min T min D min H min max
                                O P min R min F min H min max" : ""

    str = ex_dlut(str, bi, fs)

    rd < 1  ?      a                                                             : \
    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") } }



# mt_edge() is 14% faster (varies with kernel)
# "canny" is a bit too complex (requires mt_hysteresis) so that's better used in a plugin (ie. vsTCanny)

# Recommended: prewitt, scharr, frei-chen, and FDoG (slow)
#
# 21 modes:
# prewitt   - (8d) Technically, a discrete differentiation operator, an approximation of the gradient magnitude in 45º increments
# hprewitt  - (4d) Half Prewitt
# qprewitt  - (2d) Quarter Prewitt
# sobel     - (2d) The famous Sobel-Feldman operator for weighted derivatives of an image
# mtsobel   - (2d) masktools2 simplified version of the sobel operator
# scharr    - (2d) Refined sobel operator to more accurately calculate 1st derivatives for a 3x3 kernel
# frei-chen - (2d) Isotropic version of the frei-chen operator. Better than Scharr for noisy sources
# roberts   - (2d) Roberts Cross edge detector
# kayyali   - (2d) Sobel modification for a perfect rotational symmetry
# robinson  - (8d) Robinson compass mask
# FDoG      - (2d) Flow-based Difference of Gaussians
# DoG       - zero-cross (of the 2nd derivative) of a Difference of Gaussians
# DoB       - zero-cross (of the 2nd derivative) of a Difference of Boxes
# LoG       - zero-cross (of the 2nd derivative) of a Laplacian of Gaussian
# Std       - Standard Deviation
# laplace   - Laplace
# cartoon   - (1d) like 'roberts', but takes only negative edges into account
# TEdge     - Port of TEdgeMask plugin's kernel
# min/max   - Gradient magnitude. zero-cross (of the 2nd derivative) of: (dilation - erosion)
# max       - MAE (Maximum Absolute Error)
# SG        - Smooth Gradient(?)
# kirsch    - (8d) or Kirsch compass kernel is a non-linear edge detector that finds the maximum edge strength in 45º increments


function ex_edge(clip a, string "mode", int "lo", int "hi", bool "invert", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "mtsobel")
    in   = Default(invert,  false)
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    th   = mode=="prewitt"   ?  [10, 100] : \
           mode=="qprewitt"  ?  [10, 100] : \
           mode=="hprewitt"  ?  [10, 100] : \
           mode=="mtsobel"   ?  [ 5,  25] : \
           mode=="sobel"     ?  [20,  60] : \
           mode=="scharr"    ?  [30,  75] : \
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

    lo = ex_bs(Defined(lo) ? lo : th[0], 8, bi, fulls=fs)
    hi = ex_bs(Defined(hi) ? hi : th[1], 8, bi, fulls=fs)

    th  = (lo == 0) && (hi == ex_bs(255, 8, bi, fulls=fs)) ? "" : ex_dlut(Format(" {lo} - range_max {hi} {lo} - / *"), bi, fs)
    th  = in ? th + " range_max swap -" : th

    str =                                                                                                                                                                                                \
          mode=="prewitt"   ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ "                                                                                   \
                             +"A B C + + D - E - F - A G D + + C - H - F - max F E D + + C - B - A - F H C + + D - G - A - max max "                                                                     \
                             +"G A B + + F - H - E - D G E + + C - H - B - max E H F + + B - A - G - B H C + + E - G - D - max max max "+th+""                                                         : \
                                                                                                                                                                                                         \
          mode=="qprewitt"   ? "x[-1,-1] A^ x[0,-1] B^ x[1,-1] C^ x[-1,0] D^ x[1,0] E^ x[-1,1] F^ x[0,1] G^ x[1,1] H^ "                                                                                  \
                             +"A D F + + C - E - H -  A B C + + F - G - H - max "+th+""                                                                                                                : \
                                                                                                                                                                                                         \
          mode=="hprewitt"  ? "x[1,1] A^ x[1,0] 2 * B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] 2 * E^ x[-1,-1] F^ x[0,1] 2 * G^ x[0,-1] 2 * H^ "                                                                   \
                             +"A B C + + D - E - F - A G D + + C - H - F - max F E D + + C - B - A - F H C + + D - G - A - max max "+th+""                                                             : \
                                                                                                                                                                                                         \
          mode=="mtsobel"   ? "x[1,0] A^ x[0,1] B^ x[-1,0] C^ x[0,-1] D^ A B + C - D - C D + A - B - max 0.500001 * "+th+""                                                                            : \
                                                                                                                                                                                                         \
          mode=="sobel"     ? "x[1,-1] C@ x[1,1] I@ + x[-1,-1] A@ - x[-1,1] G@ - x[1,0] x[-1,0] - 2 * + dup * G I + A - C - x[0,1] x[0,-1] - 2 * + dup * + sqrt "+th+""                                : \
                                                                                                                                                                                                         \
          mode=="scharr"    ? "x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[1,0] x[-1,0] - 3.465414176 * + x[-1,-1] F@ - dup * F H + C - A - x[0,-1] x[0,1] - 3.465414176 * + dup * + sqrt "+th+""            : \
                                                                                                                                                                                                         \
          mode=="frei-chen" ? "x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[1,0] x[-1,0] - 1.414213562 * + x[-1,-1] F@ - dup * F H + C - A - x[0,-1] x[0,1] - 1.414213562 * + dup * + sqrt "+th+""            : \
                                                                                                                                                                                                         \
          mode=="roberts"   ? "x[0,0] A^ x[1,0] 0.500001 * B^ x[0,1] 0.500001 * C^ A B - C - B A - C + max "+th+""                                                                                     : \
                                                                                                                                                                                                         \
          mode=="kayyali"   ? "x[1,1] 3 * A^ x[-1,1] 3 * B^ x[-1,-1] 3 * C^ x[1,-1] 3 * D^ B A - C + D - A B - C - D + max "+th+""                                                                     : \
                                                                                                                                                                                                         \
          mode=="robinson"  ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                                                   \
                             +"C A - D 2 * - E 2 * + F - H +     B C 2 * + D - E + F 2 * - G - max     A B 2 * + C + F - G 2 * - H - max     A 2 * B + D + E - G - H 2 * - max "                         \
                             +"A C - D 2 * + E 2 * - F + H - 0 B - C 2 * - D + E - F 2 * + G + max 0 A - B 2 * - C - F + G 2 * + H + max 0 A 2 * - B - D - E + G + H 2 * + max max "+th+""             : \
                                                                                                                                                                                                         \
          mode=="FDoG"      ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] 2 * G^ x[0,1] H^ x[1,1] 2 * I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                                   \
                             +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] 2 * Q^ x[0,-1] R^ x[1,-1] 2 * S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] W^ x[1,-2] X^ x[2,-2] Y^ "                           \
                             +"A B Q U V G + + + + + D E I S X Y + + + + + - F P + J T + - 2 * + K L + N O + - 3 * + 0.500001 * dup * "                                                                  \
                             +"Y P Q U S T + + + + + F G I J A E + + + + + - X V + B D + - 2 * + R W + H C + - 3 * + 0.500001 * dup * + sqrt "+th+""                                                   : \
                                                                                                                                                                                                         \
          mode=="DoG"       ? "x[0,0] A^ x[0,1] B^ x[-1,0] C^ x[1,0] D^ x[0,-1] E^ x[0,2] F^ x[0,-2] G^ x[2,0] H^ x[-2,0] I^ x[-1,1] J^ x[-1,-1] K^ x[1,1] L^ x[1,-1] M^ "                               \
                             +"F G H I J K L M A 4 * + + + + + + + + B C D E + + + Z@ 2 * + 0.050001 * A 2 * Z + 0.166666666 * - 25 * "+th+""                                                          : \
                                                                                                                                                                                                         \
          mode=="DoB"       ? "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + Z@ "                                                                                 \
                             +"x[-2,2] x[-1,2] x[0,2] x[1,2] x[2,2] x[-2,1] x[2,1] x[-2,0] x[2,0] x[-2,-1] x[2,-1] x[-2,-2] x[-1,-2] x[0,-2] x[1,-2] x[2,-2] + + + + + + + + + + + + + + + + 0.040001 * "\
                             +"Z 0.111111111 * - 25 * "+th+""                                                                                                                                          : \
                                                                                                                                                                                                         \
          mode=="LoG"       ? "x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] + + + + + + + + + + + x[0,0] 16 * - "+th+""                 : \
                                                                                                                                                                                                         \
          mode=="laplace"   ? "x[-1,1] B@ x[0,1] C@ x[1,1] D@ x[-1,0] E@ x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ "                                                                                   \
                             +"+ + + + + + + x[0,0] 8 * A@ - A B C D E F G H I + + + + + + + - max 0.125001 * "+th+""                                                                                  : \
                                                                                                                                                                                                         \
          mode=="cartoon"   ? "x[1,-1] x[0,-1] 2 * - x[0,0] + "+th+""                                                                                                                                  : \
                                                                                                                                                                                                         \
          mode=="TEdge"     ? "x[-2,0] x[1,0] x[-1,0] - 6.166666666 * + x[2,0] - 2 * dup * x[0,-2] x[0,1] x[0,-1] - 6.166666666 * + x[0,2] - 2 * dup * + sqrt "+th+""                                  : \
                                                                                                                                                                                                         \
          mode=="min/max"   ? "x[1,1] A@ x[1,0] B@ max x[1,-1] C@ max x[-1,1] D@ max x[-1,0] E@ max x[-1,-1] F@ max x[0,1] G@ max x[0,-1] H@ max x[0,0] O@ max "                                         \
                             +"A B min C min G min O min H min D min E min F min - "+th+""                                                                                                             : \
                                                                                                                                                                                                         \
          mode=="max"       ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ x[0,0] O^ "                                                                         \
                             +"O A - abs O B - abs max O C - abs max O D - abs max O E - abs max O F - abs max O G - abs max O H - abs max "+th+""                                                     : \
                                                                                                                                                                                                         \
          mode=="kirsch"    ? "x[-1,1] A@ 1.666666666 * R^ x[0,1] B@ 1.666666666 * S^ x[1,1] C@ 1.666666666 * T^ x[-1,0] D@ 1.666666666 * U^ "                                                           \
                             +"x[1,0] E@ 1.666666666 * V^ x[-1,-1] F@ 1.666666666 * X^ x[0,-1] G@ 1.666666666 * Y^ x[1,-1] H@ 1.666666666 * Z^ "                                                         \
                             +"R S T + + D - E - F - G - H -     R S + C - U + E - F - G - H - max R B - C - U + E - X + G - H - max U A - B - C - E - X + Y + H - max "                                 \
                             +"X Y Z + + A - B - C - D - E - max V Y Z + + A - B - C - D - F - max T V Z + + A - B - D - F - G - max S T V + + A - D - F - G - H - max "+th+""                         : \
                                                                                                                                                                                                         \
          mode=="SG"        ? "x[-2,2] 2 * A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] 2 * E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                                   \
                             +"x[1,0] M^ x[2,0] N^ x[-2,-1] O^ x[-1,-1] P^ x[0,-1] Q^ x[1,-1] R^ x[2,-1] S^ x[-2,-2] 2 * T^ x[-1,-2] U^ x[0,-2] V^ x[1,-2] X^ x[2,-2] 2 * Y^ "                           \
                             +"F K O + + 2 * A T B G L P U + + + + + + + D - I - M - R - X - E - Y - J N S + + 2 * - "                                                                                   \
                             +"B C D + + 2 * A E F G H I J + + + + + + + O - P - Q - R - S - T - Y - U V X + + 2 * - max "                                                                               \
                             +"J N S + + 2 * D I M R X E Y + + + + + + + A - T - B - G - L - P - U - F K O + + 2 * - "                                                                                   \
                             +"U V X + + 2 * O P Q R S T Y + + + + + + + A - E - F - G - H - I - J - B C D + + 2 * - max max 0.200001 * "+th+""                                                        : \
                                                                                                                                                                                                         \
          mode=="Std"       ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ A B C D E F G H + + + + + + + 0.125001 * J^ "                                       \
                             +"A J - dup * B J - dup * C J - dup * D J - dup * E J - dup * F J - dup * G J - dup * H J - dup * + + + + + + + 0.125001 * sqrt 8 * "+th+""                               : \
                                                                                                                                                                                                         \
                             ex_dlut(mode+th, bi, fs)

    isy     ? Expr(a, str                                                               ) : \
    UV == 1 ? Expr(a, str, ""                                                           ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }



# Performs declared expression with 'mode' mode from clip 'a' to neighbour pixels defined in 'pixels' of clip 'b' (or 'a' if 'b' is undefined)
# !! Beware, don't write variables in the expressions with capital letters (ie. A@), use instead lower case preceded with underscore (ie. _var@)
function ex_luts(clip a, clip "b", string "expr", string "exprc", string "exprf", string "mode", string "pixels", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    isb  = Defined(b)
    isc  = Defined(exprc)
    bi   = BitsPerComponent(a)

    str  = Default(expr,     " y ")
    exprf= Default(exprf,     "")
    px   = Default(pixels,ex_shape())
    md   = Default(mode,     "avg")
    Y    = Default(Y,            3)
    UV   = Default(UV,     rgb ? 3 : isc ? 3 : 1)
    fs   = Default(fulls,  rgb)
    cf   = Default(clamp_float, false)
    si   = Defined(scale_inputs) ? \
           scale_inputs : ex_UVf(rgb, bi)

    md = md == "average"   ? "avg"          : \
         md == "maximum"   ? "max"          : \
         md == "minimum"   ? "min"          : \
         md == "range"     ? "rng"          : \
         md == "range-"    ? "rngmin"       : \
         md == "range+"    ? "rngmax"       : \
         md == "min/max"   ? "rng"          : \
         md == "inline"    ? "rngmin"       : \
         md == "outline"   ? "rngmax"       : \
         md == "standard deviation" ? "std" : \
         md == "median"    ? "med"          : md

    op = md == "avg"   ? " + "              : \
         md == "max"   ? " max "            : \
         md == "min"   ? " min "            : \
         md == "rng"   ? " max "            : \
         md == "rngmin"? " min "            : \
         md == "rngmax"? " max "            : \
         md == "std"   ? " XX - abs dup * " : \
         md == "med"   ? ""                 : ""

    px  = FindStr(px,"[") != 0 ? px : pixel_parser(px)
    px0 = FindStr(px,"x[0,0]") == 0

    in  = FindStrInstance(px, "^")
    med = md == "med" ? sel_med(in) : ""
    med = isb ? ReplaceStr(med,  "X swap2", "Y swap2") : px0 ? ReplaceStr(med,  "X swap2", "x swap2") : med


    vars = "A B C D E F G H I J K L M N O P Q R S T U V W Z " \
          +"AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWYYZZ"

    px  = isb  ? ReplaceStr(" "+px+" ",  " x[", " y[")       : px
    px  = isb  ? ReplaceStr(    px,  " y[0,0] ", " x[0,0] ") : px
    px  = isb  ?       px + " y[0,0] Y^ "                    : px
    px  = isb && px0 ? px + " x[0,0] X^ "                    : px
    nex = ReplaceStr(str,  " ", "") == "y"
    str = px0  ? str : ReplaceStr(LCase(" "+str+" "),  " x ", " X ")

    V = "" expr="" exprS="X"
    len = px0 ? in : in-1
    for (i = 0, len-1, 1) {

        V     = ReplaceStr(MidStr(vars,i==0 ? 1 : i*2+1,2), " ", "")
        exprS = md == "std" ? exprS + " " + V + " " + " + " : " "
        expr  = expr + ReplaceStr(" "+str+" ",  " y ", " "+V+" ") + (md == "med" ? V+"^ " : \
                                                                     md == "std" ? i==0 ? op : op+" + " : i==0 ? " " : op)

    }
        exprY = isb  ? ReplaceStr(" "+str+" ",  " y ",     " Y ") + (md == "med" ? "Y^ "          : \
                                                                     md == "std" ? op+" + " : op) : " "
        exprX = !px0 ? ReplaceStr(" "+str+" ",  " y ",     " X ") + (md == "med" ? "X^ "          : \
                                                                     md == "std" ? op+" + " : op) : " "

        exprS = exprS + string(1./in) + " * XX^ " + expr + exprY + exprX
        exprM = nex ? " "                         : expr + exprY + exprX

    expr = md == "rng"    ? px + expr + exprY + exprX + ReplaceStr(expr,  "max", "min") + " - " + exprf : \
           md == "rngmin" ? px + expr + exprY + exprX + " X swap - "                            + exprf : \
           md == "rngmax" ? px + expr + exprY + exprX + " X  - "                                + exprf : \
           md == "avg"    ? px + expr + exprY + exprX + string(1./in) + " * "                   + exprf : \
           md == "std"    ? px + exprS                + string(1./in) + " * sqrt "              + exprf : \
           md == "med"    ? px + exprM                + med                                     + exprf : \
                            px + expr + exprY + exprX                                           + exprf

    expr = ReplaceStr(expr, "  ", " ")

    ystr =               ex_Yexpr (expr,  Y, bi, rgb, fs)
    cstr = isc ? exprc : ex_UVexpr(expr, UV, bi, rgb, fs)
    str  =               ex_dlut(ystr, bi, fs)
    cstr = rgb ?   str : ex_dlut(cstr, bi, fs)

    isb     ?                                                                                 \
    isy     ?  Expr(a, b, str,      optSingleMode = false, scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a, b, str, "",  optSingleMode = false, scale_inputs=si, clamp_float=cf) : \
               Expr(a, b, str, cstr,optSingleMode = false, scale_inputs=si, clamp_float=cf) : \
    isy     ?  Expr(a,    str,      optSingleMode = false, scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a,    str, "",  optSingleMode = false, scale_inputs=si, clamp_float=cf) : \
               Expr(a,    str, cstr,optSingleMode = false, scale_inputs=si, clamp_float=cf) }




# Outputs a string with the kernel shape in 'shape'
# 'disk' is an antialiased 'circle', slower but looks better. Inspired by ImageMagick morphology shapes.
function ex_shape(int "rad", int "radV", string "mode", bool "center") {

    rd = Default(rad,   1)           # integers from 0 to 8 (depends on mode)
    rv = Default(radV, rd)           # integers from 0 to 8 (depends on mode)
    md = Default(mode,  "square")
    cn = Default(center, md!="ring" )

    # Soft limit
    lim = md == "plus"       ? rd + rv > 16 : \
          md == "cross"      ? rd + rv > 16 : \
          md == "horizontal" ? rd>8 || rv>8 : \
          md == "vertical"   ? rd>8 || rv>8 : false

          Assert (!lim, string(max(rd,rv))+": Maximum radius length reached for '"+md+"' mode.")

    krnlsz = ceil(2 * rd) + 1
    krnlsv = ceil(2 * rv) + 1
    krnlrd = krnlsz/2
    krnlrv = krnlsv/2

    # 49 vars
    vars = "A B C D E F G H I J K L M N O P Q R S T U V W Z " \
          +"AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWYYZZ"


    mode = md == "square"  ? """
                            skip  =  false """                                       : \
           md == "diamond" ? """
                            skip  = (abs(px) != 0 && abs(py) != 0) && \
                                    (abs(pxr) > rtm - abs(pyr) ||     \
                                     abs(pyr) > rtm - abs(pxr)) """                  : \
           md == "circle"  ? """
                            skip  = (pxr*pxr + pyr*pyr) > rtm*rtm """                : \
           md == "disk"   ? """
                            skip  = (pxr*pxr + pyr*pyr) > pow(rtm+0.3,   2) """      : \
           md == "ring"   ? """
                            skipo = (pxr*pxr + pyr*pyr) > pow(rtm+0.3,   2)
                            skipi = (pxr*pxr + pyr*pyr) > pow(rtm+0.3-1, 2)
                            skip  = skipo || !skipi """                              : \
           md == "plus"   ? """
                            skip  =  px != 0 && py != 0 """                          : \
           md == "cross"  ? """
                            skipo = round(abs(pxr))/(round(abs(pyr))+0.001)
                            skipi = round(abs(pyr))/(round(abs(pxr))+0.001)
                            skip  = skipo != skipi  """                              : \
           md == "horizontal" ? """
                            skip  =  py != 0 """                                     : \
           md == "vertical" ?  """
                            skip  =  px != 0 """                                     : ""

    rtm = min(krnlrd,krnlrv)
    rt  = float(rtm)/max(krnlrd,krnlrv)
    rty = krnlrd > krnlrv ? 1 : rt
    rtx = krnlrv > krnlrd ? 1 : rt

    # x[0,0] is always "X^"
    krn = "" V = "" pos=1
    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrv, krnlrv, 1) {
                pxr   = px * rtx
                pyr   = py * rty
                Eval(mode)
                cnt  = abs(px) + abs(py) == 0
                skip = skip || (!cn ? cnt : false)
                pos  = skip ? pos : cnt ? max(pos,0) : pos+2
                V    = cnt ? "X " : MidStr(vars,max(pos-2,1),2)
                krn  = skip ? krn : Format(krn + "x[{px},{py}] " + V + "^ ")
       }      }

    krn = md == "ring" && cn ? krn+" x[0,0] X^ " : krn

    # Hard limit
    pxc = FindStrInstance(krn, "^")
          Assert( pxc < 51, string(pxc)+": Maximum pixel fetching count reached for '"+md+"' mode.")

    return ReplaceStr(krn,  " ^", "^") }







######### HELPER FUNCTIONS #########


function FindStrInstance(string haystack, string needle) {

    pos = 1 in = 0
    while (pos > 0) {
        pos      = FindStr(haystack, needle)
        haystack = RightStr(haystack, StrLen(haystack)-pos)
        in       = pos != 0 ? in + 1 : in
    }
    return in }


# Parses a string of pixel pairs in masktools2/mt_luts() format to Expr Pixel Addressing format
# ie: " 1 -1  1  0 0 0 -2 0 " -> "x[1,-1] A^ x[1,0] B^ x[-2,0] C^ x[0,0] X^ "
function pixel_parser(string str) {

    # Cleanup
    str = ReplaceStr(str, ",", "")
    str = ReplaceStr(str, " ", "")
    len = StrLen(str)

    vars = "A B C D E F G H I J K L M N O P Q R S T U V W Z " \
          +"AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWYYZZ"

    # Extract X
    for (i = 1, len, 2) {

        sgn1 = MidStr(str,i,1) == "-"
        sgn2 = (sgn1 ? MidStr(str,i+2,1) : MidStr(str,i+1,1)) == "-"

        pos  = sgn1 ? i+1 : i
        cpx  = MidStr(str,pos,2) == "00"
        i = cpx ? len : sgn2 ? pos+1 : pos
    }

    str = cpx ? LeftStr(str, pos-1)+RightStr(str, len-pos-1) : str
    len = cpx ? len-2 : len

    # Parse
    px = ""  u = 1
    for (i = 1, len, 2) {

        sap1 =        MidStr(str,i,1)
        sgn1 = sap1 == "-"
        sap2 = sgn1 ? MidStr(str,min(len,i+2),1) : MidStr(str,min(len,i+1),1)
        sgn2 = sap2 == "-"
        val1 = sgn1 ? MidStr(str,i,2) : sap1
        val2 = sgn2 ? sgn1 ? MidStr(str,min(len,i+2),2) : MidStr(str,min(len,i+1),2) : sap2
        px   = px + " x["+val1+","+val2+"] " + MidStr(vars,min(max(1,u),len),2) + "^ "
        i    = sgn1 ? sgn2 ? i+2 : i+1 : sgn2 ? i+1 : i+0
        u    = u + 2
    }

    px = ReplaceStr(px,  " ^",  "^")
    px = cpx ? px + " x[0,0] X^ " : px

    return px }


function ex_UVexpr(string "str", int "UV", int "bits", bool "rgb", bool "fulls") {

    str = Default(str, "")
    UV  = Default(UV,   1)
    bi  = Default(bits, 8)
    rgb = Default(rgb,   false)
    fs  = Default(fulls, rgb)

    bd  = bi == 32 && !rgb ? 0.5 : 0

    str = rgb ? str : ReplaceStr(str, "ymax",  "cmax")
    str = rgb ? str : ReplaceStr(str, "ygrey", "range_half")

    # "" is the same as "copy first"
    str = UV == 1   ? ""          : \
          UV == 2   ? ""          : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 128 ? "range_half": \
          UV == 0   ? "0"         : \
          UV == 255 ? "range_max" : \
          string(ex_bs(UV, 8, bi, fulls=fs)+bd)

    str = UV == 128 || UV == 255 ? ex_dlut(str, bi, fs) : str

    return str }


function ex_Yexpr(string "str", int "Y", int "bits", bool "rgb", bool "fulls") {

    str = Default(str, "")
    Y   = Default(Y,    3)
    bi  = Default(bits, 8)
    rgb = Default(rgb,   false)
    fs  = Default(fulls, rgb)

    str = Y == 1   ? ""          : \
          Y == 2   ? ""          : \
          Y == 3   ? str         : \
          Y == 4   ? "y"         : \
          Y == 128 ? "range_half": \
          Y == 0   ? "0"         : \
          Y == 255 ? "range_max" : \
          string(ex_bs(Y, 8, bi, fulls=fs))

    str = Y == 128 || Y == 255 ? ex_dlut(str, bi, fs) : str

    return str }


function ex_UVf(bool rgb, int bits) {

    bits == 32 && !rgb ? "floatUV" : "none" }


# Pixel Value Converter (unsigned)
# Convert values from one bitdepth to another or/and from one scale to another or/and from one (luma) range to another
function ex_bs(float var, int "ibits", int "obits", bool "ifulls", bool "fulls", bool "tv_in", bool "tv_out") {

    ibi = Default(ibits,    8)
    obi = Default(obits,   16)
    fs  = Default(ifulls,  false)
    fso = Default(fulls,   fs)
    tvi = Default(tv_in,   false)
    tvo = Default(tv_out,  false)

    ib32 = ibi == 32   ob32 = obi == 32
    ib8  = ibi == 8    ob8  = obi == 8

    fs  = (ib8 || ib32) ? false : fs
    fso = (ob8 || ob32) ? false : fso

    v   = float(var)*pow(2, obi-ibi)

    fsc = fs && !fso ? -v/257.  : \
         !fs &&  fso ?  v/256.  : 0

    vif = ib32 ? ob8 ? var*255. :     var*( 255*pow(2, obi-8)+(fso ? 255*pow(2, obi-8)/256. : 0) )     : nop()
    vof = ob32 ? ib8 ? var/255. : min(var/( 255*pow(2, ibi-8)+(fs  ? 255*pow(2, ibi-8)/256. : 0) ),1.) : nop()


    out = ob32 ? ib32 ? var : vof : ib32 ? vif : v+fsc

    tv  = tvi != tvo ? tvi ? Eval(ex_dlut(Format("(({out} - ymin) / (ymax - ymin)) * range_max"), obi, fso)) : \
                             Eval(ex_dlut(Format("( {out} * (ymax - ymin)) / range_max + ymin"),  obi, fso)) : out

    ob32 ? tv : round(Eval(ex_dlut(Format("min(range_max,max(0,{tv}))"), obi, fso))) }



# HBD constants 3D look up table
#
# * YUV and RGB mid-grey is 127.5 (rounded to 128) for PC range levels,
#   this translates to a value of 125.5 in TV range levels. Chroma is always centered, so 128 regardless.

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
\   :  Assert (false, string(bits)+": Unsupported bit depth.")


    #                           8-bit UINT      10-bit UINT          12-bit UINT          14-bit UINT            16-bit UINT         24-bit UINT               32-bit Ufloat
    range_min   = Select (bitd,  [  0.,  0.],    [   0.,   0.   ],    [   0.,   0.   ],    [    0.,    0.   ],    [    0.,    0.],    [       0.,       0.],    [       0.,       0.])
    ymin        = Select (bitd,  [ 16., 16.],    [  64.,  64.   ],    [ 256., 257.   ],    [ 1024., 1028.   ],    [ 4096., 4112.],    [ 1048576., 1052672.],    [  16/255.,  16/255.])
    cmin        = Select (bitd,  [ 16., 16.],    [  64.,  64.   ],    [ 256., 257.   ],    [ 1024., 1028.   ],    [ 4096., 4112.],    [ 1048576., 1052672.],    [  16/255.,  16/255.])
    ygrey       = Select (bitd,  [126.,126.],    [ 502., 504.   ],    [2008.,2016.   ],    [ 8032., 8063.   ],    [32128.,32254.],    [ 8224768., 8256896.],    [ 125.5/255.,125.5/255.])
    range_half  = Select (bitd,  [128.,128.],    [ 512., 514.   ],    [2048.,2056.   ],    [ 8192., 8224.   ],    [32768.,32896.],    [ 8388608., 8421376.],    [ 128/255., 128/255.])
    yrange      = Select (bitd,  [219.,219.],    [ 876., 879.   ],    [3504.,3517.688],    [14016.,14070.750],    [56064.,56283.],    [14352384.,14408448.],    [ 219/255., 219/255.])
    crange      = Select (bitd,  [224.,224.],    [ 896., 899.500],    [3584.,3598.   ],    [14336.,14392.   ],    [57344.,57568.],    [14680064.,14737408.],    [ 224/255., 224/255.])
    ymax        = Select (bitd,  [235.,235.],    [ 940., 943.672],    [3760.,3774.688],    [15040.,15098.750],    [60160.,60395.],    [15400960.,15461120.],    [ 235/255., 235/255.])
    cmax        = Select (bitd,  [240.,240.],    [ 960., 963.750],    [3840.,3855.   ],    [15360.,15420.   ],    [61440.,61680.],    [15728640.,15790080.],    [ 240/255., 240/255.])
    range_max   = Select (bitd,  [255.,255.],    [1020.,1023.984],    [4080.,4095.938],    [16320.,16383.750],    [65280.,65535.],    [16711680.,16776960.],    [       1.,       1.])
    range_size  = Select (bitd,  [256.,256.],    [1024.,1024.   ],    [4096.,4096.   ],    [16384.,16384.   ],    [65536.,65536.],    [16777216.,16777216.],    [       1.,       1.])

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

    str = ReplaceStr(str, "ygrey",                   string(ygrey[fs]))
    str = ReplaceStr(str, "ymax",                    string(ymax[fs]))
    str = ReplaceStr(str, "cmax",                    string(cmax[fs]))
    str = ReplaceStr(str, "ymin",                    string(ymin[fs]))
    str = ReplaceStr(str, "cmin",                    string(cmin[fs]))
    str = ReplaceStr(str, "range_min",               string(range_min[fs]))
    str = ReplaceStr(str, "range_half",              string(range_half[fs]))
    str = ReplaceStr(str, "range_max",               string(range_max[fs]))
    str = ReplaceStr(str, "range_size",              string(range_size[fs]))

    return str }


function mskY_to_YYY(clip a, clip msk, bool "luma", bool "rgb", int "UV", int "bits", bool "fulls") {

    w  = width (a)
    h  = height(a)
    wm = width (msk)
    hm = height(msk)
    wh = wm!=w || hm!=h
    p_float = bits == 32
    bstr    = p_float ? "S" : string(bits)

    mskYs   =  isy(msk)               ? msk          : msk.ExtractY()
    mskYr   =  !wh                    ? mskYs        : mskYs.ConvertBits(8,dither=-1,fulls=fulls).BilinearResize(w, h).ConvertBits(bits,fulls=fulls)

    w       =  isYV411(a)             ? round(w/4.0) : round(w/2.0)
    h       =  isYV411(a) || is422(a) ?            h : round(h/2.0)

    mskC    = (is444  (a) || rgb)     ? mskYr : \
                                        mskYs.ConvertBits(8,dither=-1, fulls=fulls).BilinearResize(w+w%2,h+h%2)

    mskC    = luma ? p_float ? Expr(mskC, "x range_half -").ConvertBits(32,fulls=fulls) : \
                               mskC.ConvertBits(bits,fulls=fulls)                       : \
                     BlankClip(a,length=1,width=w+w%2,height=h+h%2,pixel_type="Y"+bstr,color_yuv=$000000)

    msk     = CombinePlanes(mskYr, mskC, mskC, planes=rgb ? "RGB" : "YUV", pixel_type=PixelType(a))

    return msk }


# From 35 -included- onwards not optimized enough
function sel_med(int n) {

    even = n%2 == 0
    n    = even ? n+1 : n

    med =                                                      \
                                                               \
    n == 3  ?  "A B                   dup1 dup1 max swap2 min
                X swap2 clip "                               : \
                                                               \
    n == 5  ?  "A B                   dup1 dup1 min swap2 max
                C D                   dup1 dup1 min swap2 max
                swap1  swap2                    min
                swap2                                     max
                                      dup1 dup1 max swap2 min
                X swap2 clip "                               : \
                                                               \
    n == 7  ?  "A B                   dup1 dup1 min swap2 max
                C D                   dup1 dup1 min swap2 max
                E F                   dup1 dup1 min swap2 max
                swap1  swap2          dup1 dup1 min swap2 max
                swap2  swap1  swap3   dup1 dup1 min swap2 max
                swap1  swap4          dup1 dup1 min swap2 max
                swap5  swap1  swap3   dup1 dup1 min swap2 max
                swap2  swap1  swap5             min
                swap2                 dup1 dup1 min swap2 max
                swap4  swap1  swap3                       max
                swap3                           min
                swap2                                     max
                X swap2 clip "                               : \
                                                               \
    n == 9  ?  "A B                   dup1 dup1 min swap2 max
                C D                   dup1 dup1 min swap2 max
                E F                   dup1 dup1 min swap2 max
                G H                   dup1 dup1 min swap2 max
                swap2  swap1  swap6   dup1 dup1 min swap2 max
                swap2  swap1  swap4   dup1 dup1 min swap2 max
                swap3  swap1  swap7   dup1 dup1 min swap2 max
                swap6  swap1  swap5   dup1 dup1 min swap2 max
                swap3  swap1  swap2             min
                swap2  swap1  swap5   dup1 dup1 min swap2 max
                swap6  swap1  swap3   dup1 dup1 min swap2 max
                swap5  swap1  swap4                       max
                swap4  swap1  swap5             min
                swap2                                     max
                swap3                           min
                swap2                                     max
                                      dup1 dup1 max swap2 min
                X swap2 clip "                               : \
                                                               \
    n == 11  ? "B J                   dup1 dup1 min B^ max J^
                A I                   dup1 dup1 min A^ max I^
                C H                   dup1 dup1 min C^ max H^
                E G                   dup1 dup1 min E^ max G^
                D F                   dup1 dup1 min D^ max F^
                H J                   dup1 dup1 min H^ max J^
                F I                   dup1 dup1 min F^ max I^
                B E                   dup1 dup1 min B^ max E^
                A C                   dup1 dup1 min A^ max C^
                G J                   dup1 dup1 min G^ max J^
                F H                   dup1 dup1 min F^ max H^
                C E                   dup1 dup1 min C^ max E^
                A D                   dup1 dup1 min A^ max D^
                I J                             min I^
                D G                   dup1 dup1 min D^ max G^
                A B                                    max B^
                E I                   dup1 dup1 min E^ max I^
                G H                   dup1 dup1 min G^ max H^
                B F                   dup1 dup1 min B^ max F^
                C D                   dup1 dup1 min C^ max D^
                H I                             min H^
                E G                   dup1 dup1 min E^ max G^
                D F                   dup1 dup1 min D^ max F^
                B C                                    max C^
                G H                             min G^
                E F                   dup1 dup1 min E^ max F^
                C D                                    max D^
                D E                                    max
                F G                             min

                X swap2 clip "                                : \
                                                                \
    n == 13  ? "D L                   dup1 dup1 min D^ max L^
                E K                   dup1 dup1 min E^ max K^
                F J                   dup1 dup1 min F^ max J^
                A I                   dup1 dup1 min A^ max I^
                B H                   dup1 dup1 min B^ max H^
                C G                   dup1 dup1 min C^ max G^
                J L                   dup1 dup1 min J^ max L^
                H K                   dup1 dup1 min H^ max K^
                G I                   dup1 dup1 min G^ max I^
                D F                   dup1 dup1 min D^ max F^
                B E                   dup1 dup1 min B^ max E^
                A C                   dup1 dup1 min A^ max C^
                K L                             min K^
                C J                   dup1 dup1 min C^ max J^
                E H                   dup1 dup1 min E^ max H^
                F G                   dup1 dup1 min F^ max G^
                A B                                    max B^
                I K                             min I^
                E J                   dup1 dup1 min E^ max J^
                C H                   dup1 dup1 min C^ max H^
                B D                                    max D^
                I J                             min I^
                G H                             min G^
                E F                                    max F^
                C D                                    max D^
                G I                   dup1 dup1 min G^ max I^
                D F                   dup1 dup1 min D^ max F^
                F I                             min F^
                D G                                    max G^
                F G                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 15  ? "K N                   dup1 dup1 min K^ max N^
                E M                   dup1 dup1 min E^ max M^
                H L                   dup1 dup1 min H^ max L^
                B J                   dup1 dup1 min B^ max J^
                D I                   dup1 dup1 min D^ max I^
                C G                   dup1 dup1 min C^ max G^
                A F                   dup1 dup1 min A^ max F^
                L N                   dup1 dup1 min L^ max N^
                B K                   dup1 dup1 min B^ max K^
                I J                   dup1 dup1 min I^ max J^
                D H                   dup1 dup1 min D^ max H^
                F G                   dup1 dup1 min F^ max G^
                A C                   dup1 dup1 min A^ max C^
                M N                   dup1 dup1 min M^ max N^
                C L                   dup1 dup1 min C^ max L^
                H K                   dup1 dup1 min H^ max K^
                G J                   dup1 dup1 min G^ max J^
                E I                   dup1 dup1 min E^ max I^
                B D                   dup1 dup1 min B^ max D^
                J N                             min J^
                G M                   dup1 dup1 min G^ max M^
                I L                   dup1 dup1 min I^ max L^
                F K                   dup1 dup1 min F^ max K^
                A H                   dup1 dup1 min A^ max H^
                C E                   dup1 dup1 min C^ max E^
                L M                             min L^
                J K                             min J^
                G I                   dup1 dup1 min G^ max I^
                E H                   dup1 dup1 min E^ max H^
                D F                   dup1 dup1 min D^ max F^
                A B                                    max B^
                J L                             min J^
                E I                   dup1 dup1 min E^ max I^
                D H                   dup1 dup1 min D^ max H^
                F G                   dup1 dup1 min F^ max G^
                B C                                    max C^
                I J                   dup1 dup1 min I^ max J^
                G H                   dup1 dup1 min G^ max H^
                C F                                    max F^
                D E                                    max E^
                H J                             min H^
                G I                   dup1 dup1 min G^ max I^
                E F                                    max F^
                F G                                    max
                H I                             min

                X swap2 clip "                                : \
                                                                \
    n == 17  ? "K P                   dup1 dup1 min K^ max P^
                L O                   dup1 dup1 min L^ max O^
                D N                   dup1 dup1 min D^ max N^
                C M                   dup1 dup1 min C^ max M^
                I J                   dup1 dup1 min I^ max J^
                G H                   dup1 dup1 min G^ max H^
                A F                   dup1 dup1 min A^ max F^
                B E                   dup1 dup1 min B^ max E^
                N P                   dup1 dup1 min N^ max P^
                F O                   dup1 dup1 min F^ max O^
                J M                   dup1 dup1 min J^ max M^
                I L                   dup1 dup1 min I^ max L^
                B K                   dup1 dup1 min B^ max K^
                E H                   dup1 dup1 min E^ max H^
                D G                   dup1 dup1 min D^ max G^
                A C                   dup1 dup1 min A^ max C^
                H P                   dup1 dup1 min H^ max P^
                M O                   dup1 dup1 min M^ max O^
                E N                   dup1 dup1 min E^ max N^
                C L                   dup1 dup1 min C^ max L^
                G K                   dup1 dup1 min G^ max K^
                F J                   dup1 dup1 min F^ max J^
                A I                   dup1 dup1 min A^ max I^
                B D                   dup1 dup1 min B^ max D^
                O P                             min O^
                L N                   dup1 dup1 min L^ max N^
                H M                   dup1 dup1 min H^ max M^
                J K                   dup1 dup1 min J^ max K^
                D I                   dup1 dup1 min D^ max I^
                F G                   dup1 dup1 min F^ max G^
                C E                   dup1 dup1 min C^ max E^
                A B                                    max B^
                M O                             min M^
                K N                             min K^
                H L                   dup1 dup1 min H^ max L^
                G J                   dup1 dup1 min G^ max J^
                E I                   dup1 dup1 min E^ max I^
                C F                                    max F^
                B D                                    max D^
                K M                             min K^
                E L                   dup1 dup1 min E^ max L^
                H J                   dup1 dup1 min H^ max J^
                G I                   dup1 dup1 min G^ max I^
                D F                                    max F^
                K L                             min K^
                I J                             min I^
                G H                                    max H^
                E F                                    max F^
                I K                             min I^
                F H                                    max H^
                H I                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 19  ? "L R                   dup1 dup1 min L^ max R^
                H Q                   dup1 dup1 min H^ max Q^
                C P                   dup1 dup1 min C^ max P^
                M O                   dup1 dup1 min M^ max O^
                I N                   dup1 dup1 min I^ max N^
                B K                   dup1 dup1 min B^ max K^
                E J                   dup1 dup1 min E^ max J^
                A G                   dup1 dup1 min A^ max G^
                D F                   dup1 dup1 min D^ max F^
                F R                   dup1 dup1 min F^ max R^
                N Q                   dup1 dup1 min N^ max Q^
                G O                   dup1 dup1 min G^ max O^
                A M                   dup1 dup1 min A^ max M^
                D L                   dup1 dup1 min D^ max L^
                J K                   dup1 dup1 min J^ max K^
                H I                   dup1 dup1 min H^ max I^
                B E                   dup1 dup1 min B^ max E^
                E Q                   dup1 dup1 min E^ max Q^
                K P                   dup1 dup1 min K^ max P^
                B N                   dup1 dup1 min B^ max N^
                I L                   dup1 dup1 min I^ max L^
                G J                   dup1 dup1 min G^ max J^
                C H                   dup1 dup1 min C^ max H^
                Q R                   dup1 dup1 min Q^ max R^
                O P                   dup1 dup1 min O^ max P^
                F N                   dup1 dup1 min F^ max N^
                E M                   dup1 dup1 min E^ max M^
                I K                   dup1 dup1 min I^ max K^
                H J                   dup1 dup1 min H^ max J^
                C D                   dup1 dup1 min C^ max D^
                A B                   dup1 dup1 min A^ max B^
                P R                             min P^
                G Q                   dup1 dup1 min G^ max Q^
                N O                   dup1 dup1 min N^ max O^
                K M                   dup1 dup1 min K^ max M^
                B L                   dup1 dup1 min B^ max L^
                F H                   dup1 dup1 min F^ max H^
                D E                   dup1 dup1 min D^ max E^
                A C                                    max C^
                J Q                   dup1 dup1 min J^ max Q^
                H N                   dup1 dup1 min H^ max N^
                L M                   dup1 dup1 min L^ max M^
                E K                   dup1 dup1 min E^ max K^
                B I                   dup1 dup1 min B^ max I^
                F G                   dup1 dup1 min F^ max G^
                O Q                             min O^
                M P                             min M^
                K N                   dup1 dup1 min K^ max N^
                J L                   dup1 dup1 min J^ max L^
                G I                   dup1 dup1 min G^ max I^
                E H                   dup1 dup1 min E^ max H^
                C F                                    max F^
                B D                                    max D^
                M O                             min M^
                L N                             min L^
                I K                   dup1 dup1 min I^ max K^
                H J                   dup1 dup1 min H^ max J^
                E G                                    max G^
                D F                                    max F^
                J M                             min J^
                K L                             min K^
                F I                                    max I^
                G H                                    max H^
                J K                             min J^
                H I                                    max I^
                I J                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 21  ? "H T                   dup1 dup1 min H^ max T^
                G S                   dup1 dup1 min G^ max S^
                F R                   dup1 dup1 min F^ max R^
                E Q                   dup1 dup1 min E^ max Q^
                D P                   dup1 dup1 min D^ max P^
                C O                   dup1 dup1 min C^ max O^
                B N                   dup1 dup1 min B^ max N^
                A M                   dup1 dup1 min A^ max M^
                J L                   dup1 dup1 min J^ max L^
                I K                   dup1 dup1 min I^ max K^
                R T                   dup1 dup1 min R^ max T^
                Q S                   dup1 dup1 min Q^ max S^
                N P                   dup1 dup1 min N^ max P^
                M O                   dup1 dup1 min M^ max O^
                K L                   dup1 dup1 min K^ max L^
                I J                   dup1 dup1 min I^ max J^
                F H                   dup1 dup1 min F^ max H^
                E G                   dup1 dup1 min E^ max G^
                B D                   dup1 dup1 min B^ max D^
                A C                   dup1 dup1 min A^ max C^
                S T                   dup1 dup1 min S^ max T^
                Q R                   dup1 dup1 min Q^ max R^
                O P                   dup1 dup1 min O^ max P^
                M N                   dup1 dup1 min M^ max N^
                G H                   dup1 dup1 min G^ max H^
                E F                   dup1 dup1 min E^ max F^
                C D                   dup1 dup1 min C^ max D^
                A B                   dup1 dup1 min A^ max B^
                P T                             min P^
                H S                   dup1 dup1 min H^ max S^
                D R                   dup1 dup1 min D^ max R^
                C Q                   dup1 dup1 min C^ max Q^
                L O                   dup1 dup1 min L^ max O^
                K N                   dup1 dup1 min K^ max N^
                B M                   dup1 dup1 min B^ max M^
                G J                   dup1 dup1 min G^ max J^
                F I                   dup1 dup1 min F^ max I^
                A E                                    max E^
                N S                             min N^
                J Q                   dup1 dup1 min J^ max Q^
                O P                             min O^
                I M                   dup1 dup1 min I^ max M^
                H L                   dup1 dup1 min H^ max L^
                D K                   dup1 dup1 min D^ max K^
                B G                                    max G^
                E F                                    max F^
                L R                             min L^
                K Q                   dup1 dup1 min K^ max Q^
                M N                   dup1 dup1 min M^ max N^
                D J                   dup1 dup1 min D^ max J^
                C I                                    max I^
                G H                   dup1 dup1 min G^ max H^
                N Q                             min N^
                L O                             min L^
                J M                   dup1 dup1 min J^ max M^
                H K                   dup1 dup1 min H^ max K^
                F I                                    max I^
                D G                                    max G^
                L N                             min L^
                K M                             min K^
                H J                                    max J^
                G I                                    max I^
                J L                   dup1 dup1 min J^ max L^
                I K                   dup1 dup1 min I^ max K^
                K L                             min K^
                I J                                    max J^
                J K                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 23  ? "U V                   dup1 dup1 min U^ max V^
                S T                   dup1 dup1 min S^ max T^
                Q R                   dup1 dup1 min Q^ max R^
                O P                   dup1 dup1 min O^ max P^
                M N                   dup1 dup1 min M^ max N^
                K L                   dup1 dup1 min K^ max L^
                I J                   dup1 dup1 min I^ max J^
                G H                   dup1 dup1 min G^ max H^
                E F                   dup1 dup1 min E^ max F^
                C D                   dup1 dup1 min C^ max D^
                A B                   dup1 dup1 min A^ max B^
                J V                   dup1 dup1 min J^ max V^
                I U                   dup1 dup1 min I^ max U^
                P T                   dup1 dup1 min P^ max T^
                O S                   dup1 dup1 min O^ max S^
                L R                   dup1 dup1 min L^ max R^
                B N                   dup1 dup1 min B^ max N^
                A M                   dup1 dup1 min A^ max M^
                E K                   dup1 dup1 min E^ max K^
                D H                   dup1 dup1 min D^ max H^
                C G                   dup1 dup1 min C^ max G^
                T V                   dup1 dup1 min T^ max V^
                P U                   dup1 dup1 min P^ max U^
                J S                   dup1 dup1 min J^ max S^
                F R                   dup1 dup1 min F^ max R^
                E Q                   dup1 dup1 min E^ max Q^
                I O                   dup1 dup1 min I^ max O^
                H N                   dup1 dup1 min H^ max N^
                D M                   dup1 dup1 min D^ max M^
                B G                   dup1 dup1 min B^ max G^
                A C                   dup1 dup1 min A^ max C^
                N V                   dup1 dup1 min N^ max V^
                G U                   dup1 dup1 min G^ max U^
                H T                   dup1 dup1 min H^ max T^
                M S                   dup1 dup1 min M^ max S^
                K Q                   dup1 dup1 min K^ max Q^
                B P                   dup1 dup1 min B^ max P^
                C O                   dup1 dup1 min C^ max O^
                F L                   dup1 dup1 min F^ max L^
                D J                   dup1 dup1 min D^ max J^
                A I                   dup1 dup1 min A^ max I^
                R V                             min R^
                L U                   dup1 dup1 min L^ max U^
                N S                   dup1 dup1 min N^ max S^
                M Q                   dup1 dup1 min M^ max Q^
                H O                   dup1 dup1 min H^ max O^
                B K                   dup1 dup1 min B^ max K^
                F J                   dup1 dup1 min F^ max J^
                D I                   dup1 dup1 min D^ max I^
                A E                                    max E^
                S U                             min S^
                Q T                             min Q^
                N R                             min N^
                M P                   dup1 dup1 min M^ max P^
                L O                   dup1 dup1 min L^ max O^
                H K                   dup1 dup1 min H^ max K^
                G J                   dup1 dup1 min G^ max J^
                E I                                    max I^
                C F                                    max F^
                B D                                    max D^
                J S                             min J^
                N Q                   dup1 dup1 min N^ max Q^
                K P                   dup1 dup1 min K^ max P^
                D M                                    max M^
                G L                   dup1 dup1 min G^ max L^
                F I                   dup1 dup1 min F^ max I^
                O Q                             min O^
                J P                             min J^
                K N                   dup1 dup1 min K^ max N^
                G M                                    max M^
                I L                   dup1 dup1 min I^ max L^
                F H                                    max H^
                J O                             min J^
                L N                             min L^
                H M                                    max M^
                I K                                    max K^
                K M                   dup1 dup1 min K^ max M^
                J L                   dup1 dup1 min J^ max L^
                L M                             min L^
                J K                                    max K^
                K L                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 25  ? "D Z                   dup1 dup1 min D^ max Z^
                L W                   dup1 dup1 min L^ max W^
                H V                   dup1 dup1 min H^ max V^
                A U                   dup1 dup1 min A^ max U^
                R T                   dup1 dup1 min R^ max T^
                N S                   dup1 dup1 min N^ max S^
                C Q                   dup1 dup1 min C^ max Q^
                J P                   dup1 dup1 min J^ max P^
                I O                   dup1 dup1 min I^ max O^
                B M                   dup1 dup1 min B^ max M^
                F K                   dup1 dup1 min F^ max K^
                E G                   dup1 dup1 min E^ max G^
                U Z                   dup1 dup1 min U^ max Z^
                M W                   dup1 dup1 min M^ max W^
                Q V                   dup1 dup1 min Q^ max V^
                G T                   dup1 dup1 min G^ max T^
                K S                   dup1 dup1 min K^ max S^
                E R                   dup1 dup1 min E^ max R^
                O P                   dup1 dup1 min O^ max P^
                F N                   dup1 dup1 min F^ max N^
                B L                   dup1 dup1 min B^ max L^
                I J                   dup1 dup1 min I^ max J^
                C H                   dup1 dup1 min C^ max H^
                A D                   dup1 dup1 min A^ max D^
                W Z                   dup1 dup1 min W^ max Z^
                T V                   dup1 dup1 min T^ max V^
                L U                   dup1 dup1 min L^ max U^
                P S                   dup1 dup1 min P^ max S^
                O R                   dup1 dup1 min O^ max R^
                N Q                   dup1 dup1 min N^ max Q^
                D M                   dup1 dup1 min D^ max M^
                H K                   dup1 dup1 min H^ max K^
                G J                   dup1 dup1 min G^ max J^
                F I                   dup1 dup1 min F^ max I^
                C E                   dup1 dup1 min C^ max E^
                A B                   dup1 dup1 min A^ max B^
                S V                             min S^
                P T                   dup1 dup1 min P^ max T^
                M R                   dup1 dup1 min M^ max R^
                J Q                   dup1 dup1 min J^ max Q^
                H O                   dup1 dup1 min H^ max O^
                G L                   dup1 dup1 min G^ max L^
                E I                   dup1 dup1 min E^ max I^
                C F                                    max F^
                P W                   dup1 dup1 min P^ max W^
                J U                   dup1 dup1 min J^ max U^
                Q T                   dup1 dup1 min Q^ max T^
                D O                   dup1 dup1 min D^ max O^
                L N                   dup1 dup1 min L^ max N^
                K M                   dup1 dup1 min K^ max M^
                B I                   dup1 dup1 min B^ max I^
                E H                   dup1 dup1 min E^ max H^
                Q Z                             min Q^
                S W                   dup1 dup1 min S^ max W^
                T U                             min T^
                M R                   dup1 dup1 min M^ max R^
                I P                   dup1 dup1 min I^ max P^
                J O                   dup1 dup1 min J^ max O^
                K N                   dup1 dup1 min K^ max N^
                G L                   dup1 dup1 min G^ max L^
                A H                                    max H^
                B F                   dup1 dup1 min B^ max F^
                D E                                    max E^
                R W                             min R^
                Q T                   dup1 dup1 min Q^ max T^
                O S                   dup1 dup1 min O^ max S^
                N P                   dup1 dup1 min N^ max P^
                I K                   dup1 dup1 min I^ max K^
                F J                   dup1 dup1 min F^ max J^
                E H                   dup1 dup1 min E^ max H^
                B G                                    max G^
                S T                   dup1 dup1 min S^ max T^
                P R                             min P^
                O Q                   dup1 dup1 min O^ max Q^
                M N                   dup1 dup1 min M^ max N^
                K L                   dup1 dup1 min K^ max L^
                H J                   dup1 dup1 min H^ max J^
                G I                                    max I^
                E F                   dup1 dup1 min E^ max F^
                N T                             min N^
                P Q                             min P^
                M O                   dup1 dup1 min M^ max O^
                J L                   dup1 dup1 min J^ max L^
                E K                                    max K^
                H I                                    max I^
                N S                             min N^
                O P                             min O^
                F K                                    max K^
                I J                                    max J^
                L N                             min L^
                K M                                    max M^
                L O                             min L^
                J M                                    max M^
                L M                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 27  ? "M BB                  dup1 dup1 min M^ max BB^
                T AA                  dup1 dup1 min T^ max AA^
                R Z                   dup1 dup1 min R^ max Z^
                F W                   dup1 dup1 min F^ max W^
                S V                   dup1 dup1 min S^ max V^
                D U                   dup1 dup1 min D^ max U^
                J Q                   dup1 dup1 min J^ max Q^
                K P                   dup1 dup1 min K^ max P^
                L O                   dup1 dup1 min L^ max O^
                A N                   dup1 dup1 min A^ max N^
                C I                   dup1 dup1 min C^ max I^
                E H                   dup1 dup1 min E^ max H^
                B G                   dup1 dup1 min B^ max G^
                W BB                  dup1 dup1 min W^ max BB^
                G AA                  dup1 dup1 min G^ max AA^
                H V                   dup1 dup1 min H^ max V^
                N U                   dup1 dup1 min N^ max U^
                B T                   dup1 dup1 min B^ max T^
                E S                   dup1 dup1 min E^ max S^
                J R                   dup1 dup1 min J^ max R^
                I Q                   dup1 dup1 min I^ max Q^
                O P                   dup1 dup1 min O^ max P^
                F M                   dup1 dup1 min F^ max M^
                K L                   dup1 dup1 min K^ max L^
                A D                   dup1 dup1 min A^ max D^
                P BB                  dup1 dup1 min P^ max BB^
                U AA                  dup1 dup1 min U^ max AA^
                I Z                   dup1 dup1 min I^ max Z^
                N W                   dup1 dup1 min N^ max W^
                O T                   dup1 dup1 min O^ max T^
                J S                   dup1 dup1 min J^ max S^
                C R                   dup1 dup1 min C^ max R^
                H Q                   dup1 dup1 min H^ max Q^
                D M                   dup1 dup1 min D^ max M^
                G L                   dup1 dup1 min G^ max L^
                A K                   dup1 dup1 min A^ max K^
                B F                   dup1 dup1 min B^ max F^
                AA BB                 dup1 dup1 min AA^ max BB^
                Q Z                   dup1 dup1 min Q^ max Z^
                L W                   dup1 dup1 min L^ max W^
                R V                   dup1 dup1 min R^ max V^
                P U                   dup1 dup1 min P^ max U^
                M T                   dup1 dup1 min M^ max T^
                H S                   dup1 dup1 min H^ max S^
                D O                   dup1 dup1 min D^ max O^
                G N                   dup1 dup1 min G^ max N^
                F K                   dup1 dup1 min F^ max K^
                C J                   dup1 dup1 min C^ max J^
                E I                   dup1 dup1 min E^ max I^
                A B                   dup1 dup1 min A^ max B^
                U AA                  dup1 dup1 min U^ max AA^
                V Z                   dup1 dup1 min V^ max Z^
                T W                   dup1 dup1 min T^ max W^
                Q S                   dup1 dup1 min Q^ max S^
                I R                   dup1 dup1 min I^ max R^
                K P                   dup1 dup1 min K^ max P^
                L O                   dup1 dup1 min L^ max O^
                M N                   dup1 dup1 min M^ max N^
                H J                   dup1 dup1 min H^ max J^
                D G                   dup1 dup1 min D^ max G^
                B F                   dup1 dup1 min B^ max F^
                C E                   dup1 dup1 min C^ max E^
                Z BB                            min Z^
                W AA                  dup1 dup1 min W^ max AA^
                S V                   dup1 dup1 min S^ max V^
                T U                   dup1 dup1 min T^ max U^
                P R                   dup1 dup1 min P^ max R^
                J Q                   dup1 dup1 min J^ max Q^
                N O                   dup1 dup1 min N^ max O^
                L M                   dup1 dup1 min L^ max M^
                I K                   dup1 dup1 min I^ max K^
                E H                   dup1 dup1 min E^ max H^
                F G                   dup1 dup1 min F^ max G^
                B D                   dup1 dup1 min B^ max D^
                A C                                    max C^
                Z AA                  dup1 dup1 min Z^ max AA^
                V W                             min V^
                H T                   dup1 dup1 min H^ max T^
                G S                   dup1 dup1 min G^ max S^
                O R                             min O^
                N Q                   dup1 dup1 min N^ max Q^
                K P                   dup1 dup1 min K^ max P^
                J M                   dup1 dup1 min J^ max M^
                I L                                    max L^
                D E                                    max E^
                B C                   dup1 dup1 min B^ max C^
                Q AA                            min Q^
                O Z                             min O^
                T V                             min T^
                S U                             min S^
                N P                   dup1 dup1 min N^ max P^
                K M                   dup1 dup1 min K^ max M^
                C L                                    max L^
                B J                                    max J^
                F H                                    max H^
                E G                                    max G^
                L T                   dup1 dup1 min L^ max T^
                M S                             min M^
                P Q                             min P^
                G O                   dup1 dup1 min G^ max O^
                H N                                    max N^
                J K                                    max K^
                P T                             min P^
                M O                             min M^
                L N                                    max N^
                G K                                    max K^
                N P                   dup1 dup1 min N^ max P^
                K M                   dup1 dup1 min K^ max M^
                M P                             min M^
                K N                                    max N^
                M N                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 29  ? "CC DD                 dup1 dup1 min CC^ max DD^
                AA BB                 dup1 dup1 min AA^ max BB^
                W Z                   dup1 dup1 min W^  max Z^
                U V                   dup1 dup1 min U^  max V^
                S T                   dup1 dup1 min S^  max T^
                Q R                   dup1 dup1 min Q^  max R^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                K L                   dup1 dup1 min K^  max L^
                I J                   dup1 dup1 min I^  max J^
                G H                   dup1 dup1 min G^  max H^
                E F                   dup1 dup1 min E^  max F^
                C D                   dup1 dup1 min C^  max D^
                A B                   dup1 dup1 min A^  max B^
                B DD                  dup1 dup1 min B^  max DD^
                A CC                  dup1 dup1 min A^  max CC^
                D BB                  dup1 dup1 min D^  max BB^
                C AA                  dup1 dup1 min C^  max AA^
                F Z                   dup1 dup1 min F^  max Z^
                E W                   dup1 dup1 min E^  max W^
                H V                   dup1 dup1 min H^  max V^
                G U                   dup1 dup1 min G^  max U^
                J T                   dup1 dup1 min J^  max T^
                I S                   dup1 dup1 min I^  max S^
                L R                   dup1 dup1 min L^  max R^
                K Q                   dup1 dup1 min K^  max Q^
                N P                   dup1 dup1 min N^  max P^
                M O                   dup1 dup1 min M^  max O^
                V DD                  dup1 dup1 min V^  max DD^
                H CC                  dup1 dup1 min H^  max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                W AA                  dup1 dup1 min W^  max AA^
                B U                   dup1 dup1 min B^  max U^
                P R                   dup1 dup1 min P^  max R^
                N Q                   dup1 dup1 min N^  max Q^
                L O                   dup1 dup1 min L^  max O^
                K M                   dup1 dup1 min K^  max M^
                A G                   dup1 dup1 min A^  max G^
                D F                   dup1 dup1 min D^  max F^
                C E                   dup1 dup1 min C^  max E^
                J CC                  dup1 dup1 min J^  max CC^
                R BB                  dup1 dup1 min R^  max BB^
                F Z                   dup1 dup1 min F^  max Z^
                E W                   dup1 dup1 min E^  max W^
                T V                   dup1 dup1 min T^  max V^
                B S                   dup1 dup1 min B^  max S^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                C K                   dup1 dup1 min C^  max K^
                G I                   dup1 dup1 min G^  max I^
                V DD                  dup1 dup1 min V^  max DD^
                F AA                  dup1 dup1 min F^  max AA^
                P Z                   dup1 dup1 min P^  max Z^
                D W                   dup1 dup1 min D^  max W^
                S U                   dup1 dup1 min S^  max U^
                O Q                   dup1 dup1 min O^  max Q^
                L N                   dup1 dup1 min L^  max N^
                E M                   dup1 dup1 min E^  max M^
                H J                   dup1 dup1 min H^  max J^
                A G                   dup1 dup1 min A^  max G^
                BB DD                           min BB^
                Z CC                            min Z^
                Q AA                  dup1 dup1 min Q^  max AA^
                O W                   dup1 dup1 min O^  max W^
                R V                             min R^
                T U                   dup1 dup1 min T^  max U^
                F N                   dup1 dup1 min F^  max N^
                D L                   dup1 dup1 min D^  max L^
                G K                                     max K^
                H I                   dup1 dup1 min H^  max I^
                B E                                     max E^
                A C                                     max C^
                U AA                            min U^
                Q Z                   dup1 dup1 min Q^  max Z^
                R W                   dup1 dup1 min R^  max W^
                M T                   dup1 dup1 min M^  max T^
                N S                   dup1 dup1 min N^  max S^
                I P                   dup1 dup1 min I^  max P^
                J O                   dup1 dup1 min J^  max O^
                E L                   dup1 dup1 min E^  max L^
                F K                   dup1 dup1 min F^  max K^
                D H                                     max H^
                S BB                            min S^
                T Z                             min T^
                O W                             min O^
                K U                   dup1 dup1 min K^  max U^
                H R                   dup1 dup1 min H^  max R^
                M Q                   dup1 dup1 min M^  max Q^
                L P                   dup1 dup1 min L^  max P^
                F N                                     max N^
                C J                                     max J^
                E I                                     max I^
                P U                             min P^
                Q T                   dup1 dup1 min Q^  max T^
                O R                   dup1 dup1 min O^  max R^
                K N                   dup1 dup1 min K^  max N^
                H M                                     max M^
                I L                   dup1 dup1 min I^  max L^
                R T                             min R^
                P S                             min P^
                N Q                   dup1 dup1 min N^  max Q^
                L O                   dup1 dup1 min L^  max O^
                J M                                     max M^
                I K                                     max K^
                P R                             min P^
                O Q                             min O^
                L N                                     max N^
                K M                                     max M^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                N P                             min N^
                M O                                     max O^
                N O                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 31  ? "EE FF                 dup1 dup1 min EE^ max FF^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA BB                 dup1 dup1 min AA^ max BB^
                W Z                   dup1 dup1 min W^  max Z^
                U V                   dup1 dup1 min U^  max V^
                S T                   dup1 dup1 min S^  max T^
                Q R                   dup1 dup1 min Q^  max R^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                K L                   dup1 dup1 min K^  max L^
                I J                   dup1 dup1 min I^  max J^
                G H                   dup1 dup1 min G^  max H^
                E F                   dup1 dup1 min E^  max F^
                C D                   dup1 dup1 min C^  max D^
                A B                   dup1 dup1 min A^  max B^
                DD FF                 dup1 dup1 min DD^ max FF^
                CC EE                 dup1 dup1 min CC^ max EE^
                Z BB                  dup1 dup1 min Z^  max BB^
                W AA                  dup1 dup1 min W^  max AA^
                T V                   dup1 dup1 min T^  max V^
                S U                   dup1 dup1 min S^  max U^
                P R                   dup1 dup1 min P^  max R^
                O Q                   dup1 dup1 min O^  max Q^
                L N                   dup1 dup1 min L^  max N^
                K M                   dup1 dup1 min K^  max M^
                H J                   dup1 dup1 min H^  max J^
                G I                   dup1 dup1 min G^  max I^
                D F                   dup1 dup1 min D^  max F^
                C E                   dup1 dup1 min C^  max E^
                BB FF                 dup1 dup1 min BB^ max FF^
                AA EE                 dup1 dup1 min AA^ max EE^
                Z DD                  dup1 dup1 min Z^  max DD^
                W CC                  dup1 dup1 min W^  max CC^
                R V                   dup1 dup1 min R^  max V^
                Q U                   dup1 dup1 min Q^  max U^
                P T                   dup1 dup1 min P^  max T^
                O S                   dup1 dup1 min O^  max S^
                J N                   dup1 dup1 min J^  max N^
                I M                   dup1 dup1 min I^  max M^
                H L                   dup1 dup1 min H^  max L^
                G K                   dup1 dup1 min G^  max K^
                B F                   dup1 dup1 min B^  max F^
                A E                   dup1 dup1 min A^  max E^
                V FF                  dup1 dup1 min V^  max FF^
                U EE                  dup1 dup1 min U^  max EE^
                T DD                  dup1 dup1 min T^  max DD^
                S CC                  dup1 dup1 min S^  max CC^
                R BB                  dup1 dup1 min R^  max BB^
                Q AA                  dup1 dup1 min Q^  max AA^
                P Z                   dup1 dup1 min P^  max Z^
                O W                   dup1 dup1 min O^  max W^
                F N                   dup1 dup1 min F^  max N^
                E M                   dup1 dup1 min E^  max M^
                D L                   dup1 dup1 min D^  max L^
                C K                   dup1 dup1 min C^  max K^
                B J                   dup1 dup1 min B^  max J^
                A I                   dup1 dup1 min A^  max I^
                N FF                            min N^
                V EE                  dup1 dup1 min V^  max EE^
                BB DD                 dup1 dup1 min BB^ max DD^
                R CC                  dup1 dup1 min R^  max CC^
                T AA                  dup1 dup1 min T^  max AA^
                U Z                   dup1 dup1 min U^  max Z^
                P W                   dup1 dup1 min P^  max W^
                Q S                   dup1 dup1 min Q^  max S^
                F M                   dup1 dup1 min F^  max M^
                J L                   dup1 dup1 min J^  max L^
                B K                   dup1 dup1 min B^  max K^
                D I                   dup1 dup1 min D^  max I^
                E H                   dup1 dup1 min E^  max H^
                A C                   dup1 dup1 min A^  max C^
                DD EE                 dup1 dup1 min DD^ max EE^
                AA CC                 dup1 dup1 min AA^ max CC^
                V BB                  dup1 dup1 min V^  max BB^
                H Z                   dup1 dup1 min H^  max Z^
                S W                   dup1 dup1 min S^  max W^
                E U                   dup1 dup1 min E^  max U^
                R T                   dup1 dup1 min R^  max T^
                P Q                   dup1 dup1 min P^  max Q^
                L M                   dup1 dup1 min L^  max M^
                I K                   dup1 dup1 min I^  max K^
                F J                   dup1 dup1 min F^  max J^
                C G                   dup1 dup1 min C^  max G^
                B D                   dup1 dup1 min B^  max D^
                M EE                            min M^
                L DD                            min L^
                K CC                  dup1 dup1 min K^  max CC^
                J BB                  dup1 dup1 min J^  max BB^
                T AA                  dup1 dup1 min T^  max AA^
                G W                   dup1 dup1 min G^  max W^
                F V                   dup1 dup1 min F^  max V^
                C S                   dup1 dup1 min C^  max S^
                B R                   dup1 dup1 min B^  max R^
                A Q                                     max Q^
                D I                   dup1 dup1 min D^  max I^
                M CC                            min M^
                N BB                            min N^
                I AA                  dup1 dup1 min I^  max AA^
                L Z                             min L^
                U W                   dup1 dup1 min U^  max W^
                J V                             min J^
                D T                   dup1 dup1 min D^  max T^
                G S                                     max S^
                E Q                                     max Q^
                B P                                     max P^
                C O                                     max O^
                F H                   dup1 dup1 min F^  max H^
                N AA                            min N^
                M W                             min M^
                I U                   dup1 dup1 min I^  max U^
                H T                   dup1 dup1 min H^  max T^
                K S                   dup1 dup1 min K^  max S^
                J R                   dup1 dup1 min J^  max R^
                F P                                     max P^
                D O                                     max O^
                L U                   dup1 dup1 min L^  max U^
                M S                   dup1 dup1 min M^  max S^
                N R                             min N^
                H Q                   dup1 dup1 min H^  max Q^
                J P                   dup1 dup1 min J^  max P^
                K O                                     max O^
                N U                             min N^
                S T                             min S^
                M Q                   dup1 dup1 min M^  max Q^
                L P                   dup1 dup1 min L^  max P^
                H O                                     max O^
                I J                                     max J^
                Q S                   dup1 dup1 min Q^  max S^
                N P                   dup1 dup1 min N^  max P^
                M O                                     max O^
                J L                                     max L^
                P S                             min P^
                N Q                   dup1 dup1 min N^  max Q^
                L O                                     max O^
                N O                                     max
                P Q                             min

                X swap2 clip "                                : \
                                                                \
    n == 33  ? "GG HH                 dup1 dup1 min GG^ max HH^
                EE FF                 dup1 dup1 min EE^ max FF^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA BB                 dup1 dup1 min AA^ max BB^
                W Z                   dup1 dup1 min W^  max Z^
                U V                   dup1 dup1 min U^  max V^
                S T                   dup1 dup1 min S^  max T^
                Q R                   dup1 dup1 min Q^  max R^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                K L                   dup1 dup1 min K^  max L^
                I J                   dup1 dup1 min I^  max J^
                G H                   dup1 dup1 min G^  max H^
                E F                   dup1 dup1 min E^  max F^
                C D                   dup1 dup1 min C^  max D^
                A B                   dup1 dup1 min A^  max B^
                FF HH                 dup1 dup1 min FF^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                V Z                   dup1 dup1 min V^  max Z^
                U W                   dup1 dup1 min U^  max W^
                R T                   dup1 dup1 min R^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                N P                   dup1 dup1 min N^  max P^
                M O                   dup1 dup1 min M^  max O^
                J L                   dup1 dup1 min J^  max L^
                I K                   dup1 dup1 min I^  max K^
                F H                   dup1 dup1 min F^  max H^
                E G                   dup1 dup1 min E^  max G^
                B D                   dup1 dup1 min B^  max D^
                A C                   dup1 dup1 min A^  max C^
                DD HH                 dup1 dup1 min DD^ max HH^
                CC GG                 dup1 dup1 min CC^ max GG^
                BB FF                 dup1 dup1 min BB^ max FF^
                AA EE                 dup1 dup1 min AA^ max EE^
                T Z                   dup1 dup1 min T^  max Z^
                S W                   dup1 dup1 min S^  max W^
                R V                   dup1 dup1 min R^  max V^
                Q U                   dup1 dup1 min Q^  max U^
                L P                   dup1 dup1 min L^  max P^
                K O                   dup1 dup1 min K^  max O^
                J N                   dup1 dup1 min J^  max N^
                I M                   dup1 dup1 min I^  max M^
                D H                   dup1 dup1 min D^  max H^
                C G                   dup1 dup1 min C^  max G^
                B F                   dup1 dup1 min B^  max F^
                A E                   dup1 dup1 min A^  max E^
                Z HH                  dup1 dup1 min Z^  max HH^
                W GG                  dup1 dup1 min W^  max GG^
                V FF                  dup1 dup1 min V^  max FF^
                U EE                  dup1 dup1 min U^  max EE^
                T DD                  dup1 dup1 min T^  max DD^
                S CC                  dup1 dup1 min S^  max CC^
                R BB                  dup1 dup1 min R^  max BB^
                Q AA                  dup1 dup1 min Q^  max AA^
                H P                   dup1 dup1 min H^  max P^
                G O                   dup1 dup1 min G^  max O^
                F N                   dup1 dup1 min F^  max N^
                E M                   dup1 dup1 min E^  max M^
                D L                   dup1 dup1 min D^  max L^
                C K                   dup1 dup1 min C^  max K^
                B J                   dup1 dup1 min B^  max J^
                A I                   dup1 dup1 min A^  max I^
                P HH                            min P^
                Z GG                  dup1 dup1 min Z^  max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                T EE                  dup1 dup1 min T^  max EE^
                V CC                  dup1 dup1 min V^  max CC^
                W BB                  dup1 dup1 min W^  max BB^
                R AA                  dup1 dup1 min R^  max AA^
                S U                   dup1 dup1 min S^  max U^
                A Q                                     max Q^
                H O                   dup1 dup1 min H^  max O^
                L N                   dup1 dup1 min L^  max N^
                D M                   dup1 dup1 min D^  max M^
                F K                   dup1 dup1 min F^  max K^
                G J                   dup1 dup1 min G^  max J^
                B I                   dup1 dup1 min B^  max I^
                C E                   dup1 dup1 min C^  max E^
                FF GG                 dup1 dup1 min FF^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                Z DD                  dup1 dup1 min Z^  max DD^
                J BB                  dup1 dup1 min J^  max BB^
                U AA                  dup1 dup1 min U^  max AA^
                G W                   dup1 dup1 min G^  max W^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                N O                   dup1 dup1 min N^  max O^
                K M                   dup1 dup1 min K^  max M^
                H L                   dup1 dup1 min H^  max L^
                E I                   dup1 dup1 min E^  max I^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                O GG                            min O^
                N FF                            min N^
                M EE                  dup1 dup1 min M^  max EE^
                L DD                  dup1 dup1 min L^  max DD^
                V CC                  dup1 dup1 min V^  max CC^
                I AA                  dup1 dup1 min I^  max AA^
                H Z                   dup1 dup1 min H^  max Z^
                E U                   dup1 dup1 min E^  max U^
                D T                   dup1 dup1 min D^  max T^
                C S                                     max S^
                B R                                     max R^
                F K                   dup1 dup1 min F^  max K^
                O EE                            min O^
                P DD                            min P^
                K CC                  dup1 dup1 min K^  max CC^
                N BB                            min N^
                W AA                  dup1 dup1 min W^  max AA^
                L Z                             min L^
                F V                   dup1 dup1 min F^  max V^
                I U                                     max U^
                G S                                     max S^
                D R                                     max R^
                E Q                                     max Q^
                H J                   dup1 dup1 min H^  max J^
                P CC                            min P^
                O AA                            min O^
                K W                   dup1 dup1 min K^  max W^
                J V                   dup1 dup1 min J^  max V^
                M U                   dup1 dup1 min M^  max U^
                L T                   dup1 dup1 min L^  max T^
                H R                                     max R^
                F Q                                     max Q^
                N W                   dup1 dup1 min N^  max W^
                O U                   dup1 dup1 min O^  max U^
                P T                             min P^
                J S                   dup1 dup1 min J^  max S^
                L R                   dup1 dup1 min L^  max R^
                M Q                                     max Q^
                P W                             min P^
                U V                             min U^
                O S                   dup1 dup1 min O^  max S^
                N R                   dup1 dup1 min N^  max R^
                J Q                                     max Q^
                K L                                     max L^
                S U                             min S^
                P R                             min P^
                O Q                                     max Q^
                L N                                     max N^
                P S                             min P^
                N Q                                     max Q^
                P Q                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 35  ? "JJ A                  dup1 dup1 min JJ^ max A^
                B C                   dup1 dup1 min B^  max C^
                JJ B                  dup1 dup1 min JJ^ max B^
                A C                   dup1 dup1 min A^  max C^
                A B                   dup1 dup1 min A^  max B^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                D F                   dup1 dup1 min D^  max F^
                E G                   dup1 dup1 min E^  max G^
                E F                   dup1 dup1 min E^  max F^
                JJ D                  dup1 dup1 min JJ^ max D^
                B F                   dup1 dup1 min B^  max F^
                B D                   dup1 dup1 min B^  max D^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                H J                   dup1 dup1 min H^  max J^
                I K                   dup1 dup1 min I^  max K^
                I J                   dup1 dup1 min I^  max J^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                L N                   dup1 dup1 min L^  max N^
                M O                   dup1 dup1 min M^  max O^
                M N                   dup1 dup1 min M^  max N^
                H L                   dup1 dup1 min H^  max L^
                J N                   dup1 dup1 min J^  max N^
                J L                   dup1 dup1 min J^  max L^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                JJ H                  dup1 dup1 min JJ^ max H^
                D L                   dup1 dup1 min D^  max L^
                D H                   dup1 dup1 min D^  max H^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                P R                   dup1 dup1 min P^  max R^
                Q S                   dup1 dup1 min Q^  max S^
                Q R                   dup1 dup1 min Q^  max R^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                T V                   dup1 dup1 min T^  max V^
                U W                   dup1 dup1 min U^  max W^
                U V                   dup1 dup1 min U^  max V^
                P T                   dup1 dup1 min P^  max T^
                R V                   dup1 dup1 min R^  max V^
                R T                   dup1 dup1 min R^  max T^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                AA CC                 dup1 dup1 min AA^ max CC^
                AA BB                 dup1 dup1 min AA^ max BB^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                EE GG                 dup1 dup1 min EE^ max GG^
                EE FF                 dup1 dup1 min EE^ max FF^
                Z DD                  dup1 dup1 min Z^  max DD^
                BB FF                 dup1 dup1 min BB^ max FF^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                P Z                   dup1 dup1 min P^  max Z^
                T DD                  dup1 dup1 min T^  max DD^
                T Z                   dup1 dup1 min T^  max Z^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                 dup1 dup1 min BB^ max DD^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                JJ P                  dup1 dup1 min JJ^ max P^
                H Z                   dup1 dup1 min H^  max Z^
                H P                   dup1 dup1 min H^  max P^
                D T                   dup1 dup1 min D^  max T^
                L DD                            min L^
                L T                   dup1 dup1 min L^  max T^
                D H                   dup1 dup1 min D^  max H^
                L P                   dup1 dup1 min L^  max P^
                T Z                   dup1 dup1 min T^  max Z^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                            min V^
                B D                             min B^
                F H                                     max H^
                J L                   dup1 dup1 min J^  max L^
                N P                   dup1 dup1 min N^  max P^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                            min M^
                M U                   dup1 dup1 min M^  max U^
                E I                                     max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                                     max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                            min W^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                            min W^
                A B                             min A^
                G H                                     max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                HH II                 dup1 dup1 min HH^ max II^
                JJ HH                                   max HH^
                P HH                  dup1 dup1 min P^  max HH^
                H P                                     max P^
                Z HH                            min Z^
                L T                   dup1 dup1 min L^  max T^
                L P                                     max P^
                T Z                             min T^
                J R                                     max R^
                N V                             min N^
                N R                   dup1 dup1 min N^  max R^
                N P                                     max P^
                R T                             min R^
                A II                                    max II^
                Q II                            min Q^
                I Q                                     max Q^
                M U                             min M^
                M Q                                     max Q^
                K S                                     max S^
                O W                             min O^
                O S                             min O^
                O Q                   dup1 dup1 min O^  max Q^
                Q R                             min
                O P                                     max

                X swap2 clip "                                : \
                                                                \
    n == 37  ? "LL A                  dup1 dup1 min LL^ max A^
                B C                   dup1 dup1 min B^  max C^
                LL B                  dup1 dup1 min LL^ max B^
                A C                   dup1 dup1 min A^  max C^
                A B                   dup1 dup1 min A^  max B^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                D F                   dup1 dup1 min D^  max F^
                E G                   dup1 dup1 min E^  max G^
                E F                   dup1 dup1 min E^  max F^
                LL D                  dup1 dup1 min LL^ max D^
                B F                   dup1 dup1 min B^  max F^
                B D                   dup1 dup1 min B^  max D^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                H J                   dup1 dup1 min H^  max J^
                I K                   dup1 dup1 min I^  max K^
                I J                   dup1 dup1 min I^  max J^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                L N                   dup1 dup1 min L^  max N^
                M O                   dup1 dup1 min M^  max O^
                M N                   dup1 dup1 min M^  max N^
                H L                   dup1 dup1 min H^  max L^
                J N                   dup1 dup1 min J^  max N^
                J L                   dup1 dup1 min J^  max L^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                LL H                  dup1 dup1 min LL^ max H^
                D L                   dup1 dup1 min D^  max L^
                D H                   dup1 dup1 min D^  max H^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                P R                   dup1 dup1 min P^  max R^
                Q S                   dup1 dup1 min Q^  max S^
                Q R                   dup1 dup1 min Q^  max R^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                T V                   dup1 dup1 min T^  max V^
                U W                   dup1 dup1 min U^  max W^
                U V                   dup1 dup1 min U^  max V^
                P T                   dup1 dup1 min P^  max T^
                R V                   dup1 dup1 min R^  max V^
                R T                   dup1 dup1 min R^  max T^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                AA CC                 dup1 dup1 min AA^ max CC^
                AA BB                 dup1 dup1 min AA^ max BB^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                EE GG                 dup1 dup1 min EE^ max GG^
                EE FF                 dup1 dup1 min EE^ max FF^
                Z DD                  dup1 dup1 min Z^  max DD^
                BB FF                 dup1 dup1 min BB^ max FF^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                P Z                   dup1 dup1 min P^  max Z^
                T DD                  dup1 dup1 min T^  max DD^
                T Z                   dup1 dup1 min T^  max Z^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                 dup1 dup1 min BB^ max DD^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                LL P                  dup1 dup1 min LL^ max P^
                H Z                   dup1 dup1 min H^  max Z^
                H P                   dup1 dup1 min H^  max P^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                D H                             min D^
                L P                   dup1 dup1 min L^  max P^
                T Z                   dup1 dup1 min T^  max Z^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                                     max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                B D                   dup1 dup1 min B^  max D^
                J L                   dup1 dup1 min J^  max L^
                N P                   dup1 dup1 min N^  max P^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                           min BB^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                            min M^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                            min W^
                C E                             min C^
                G I                                     max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                A B                   dup1 dup1 min A^  max B^
                C D                             min C^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                           min AA^
                HH II                 dup1 dup1 min HH^ max II^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                HH JJ                 dup1 dup1 min HH^ max JJ^
                II KK                 dup1 dup1 min II^ max KK^
                II JJ                 dup1 dup1 min II^ max JJ^
                LL HH                                   max HH^
                P HH                                    max HH^
                Z HH                            min Z^
                L T                                     max T^
                T Z                             min T^
                B JJ                                    max JJ^
                R JJ                            min R^
                J R                                     max R^
                N V                             min N^
                N R                                     max R^
                R T                   dup1 dup1 min R^  max T^
                A II                                    max II^
                Q II                  dup1 dup1 min Q^  max II^
                I Q                                     max Q^
                AA II                           min AA^
                M U                   dup1 dup1 min M^  max U^
                M Q                             min M^
                U AA                            min U^
                C KK                                    max KK^
                S KK                            min S^
                K S                                     max S^
                O W                             min O^
                O S                   dup1 dup1 min O^  max S^
                O Q                                     max Q^
                S U                             min S^
                S T                             min
                Q R                                     max

                X swap2 clip "                                : \
                                                                \
    n == 39  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                             min G^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                           min CC^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                            min Z^
                D F                   dup1 dup1 min D^  max F^
                H J                                     max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                             min F^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                           min BB^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                II MM                 dup1 dup1 min II^ max MM^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                KK MM                 dup1 dup1 min KK^ max MM^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                KK MM                 dup1 dup1 min KK^ max MM^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                A II                                    max II^
                Q II                                    max II^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                  dup1 dup1 min U^  max MM^
                M U                                     max U^
                U AA                            min U^
                C KK                                    max KK^
                S KK                            min S^
                K S                                     max S^
                O W                             min O^
                O S                                     max S^
                S U                   dup1 dup1 min S^  max U^
                B JJ                                    max JJ^
                R JJ                  dup1 dup1 min R^  max JJ^
                J R                                     max R^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N V                   dup1 dup1 min N^  max V^
                N R                                     max R^
                V BB                            min V^
                D LL                                    max LL^
                T LL                  dup1 dup1 min T^  max LL^
                L T                                     max T^
                P Z                             min P^
                P T                   dup1 dup1 min P^  max T^
                P R                                     max R^
                T V                             min T^
                T U                             min
                R S                                     max

                X swap2 clip "                                : \
                                                                \
    n == 41  ? "PP A                  dup1 dup1 min PP^ max A^
                B C                   dup1 dup1 min B^  max C^
                PP B                  dup1 dup1 min PP^ max B^
                A C                   dup1 dup1 min A^  max C^
                A B                   dup1 dup1 min A^  max B^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                D F                   dup1 dup1 min D^  max F^
                E G                   dup1 dup1 min E^  max G^
                E F                   dup1 dup1 min E^  max F^
                PP D                  dup1 dup1 min PP^ max D^
                B F                   dup1 dup1 min B^  max F^
                B D                   dup1 dup1 min B^  max D^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                H J                   dup1 dup1 min H^  max J^
                I K                   dup1 dup1 min I^  max K^
                I J                   dup1 dup1 min I^  max J^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                L N                   dup1 dup1 min L^  max N^
                M O                   dup1 dup1 min M^  max O^
                M N                   dup1 dup1 min M^  max N^
                H L                   dup1 dup1 min H^  max L^
                J N                   dup1 dup1 min J^  max N^
                J L                   dup1 dup1 min J^  max L^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                PP H                  dup1 dup1 min PP^ max H^
                D L                   dup1 dup1 min D^  max L^
                D H                   dup1 dup1 min D^  max H^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                P R                   dup1 dup1 min P^  max R^
                Q S                   dup1 dup1 min Q^  max S^
                Q R                   dup1 dup1 min Q^  max R^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                T V                   dup1 dup1 min T^  max V^
                U W                   dup1 dup1 min U^  max W^
                U V                   dup1 dup1 min U^  max V^
                P T                   dup1 dup1 min P^  max T^
                R V                   dup1 dup1 min R^  max V^
                R T                   dup1 dup1 min R^  max T^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                AA CC                 dup1 dup1 min AA^ max CC^
                AA BB                 dup1 dup1 min AA^ max BB^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                EE GG                 dup1 dup1 min EE^ max GG^
                EE FF                 dup1 dup1 min EE^ max FF^
                Z DD                  dup1 dup1 min Z^  max DD^
                BB FF                 dup1 dup1 min BB^ max FF^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                P Z                   dup1 dup1 min P^  max Z^
                T DD                  dup1 dup1 min T^  max DD^
                T Z                   dup1 dup1 min T^  max Z^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                 dup1 dup1 min BB^ max DD^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                PP P                  dup1 dup1 min PP^ max P^
                H Z                   dup1 dup1 min H^  max Z^
                H P                   dup1 dup1 min H^  max P^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                D H                   dup1 dup1 min D^  max H^
                L P                   dup1 dup1 min L^  max P^
                T Z                   dup1 dup1 min T^  max Z^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                N P                   dup1 dup1 min N^  max P^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                           min BB^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                            min M^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                            min W^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                             min G^
                I J                                     max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                           min AA^
                HH II                 dup1 dup1 min HH^ max II^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                HH JJ                 dup1 dup1 min HH^ max JJ^
                II KK                 dup1 dup1 min II^ max KK^
                II JJ                 dup1 dup1 min II^ max JJ^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                LL NN                 dup1 dup1 min LL^ max NN^
                MM OO                 dup1 dup1 min MM^ max OO^
                MM NN                 dup1 dup1 min MM^ max NN^
                HH LL                 dup1 dup1 min HH^ max LL^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                MM NN                 dup1 dup1 min MM^ max NN^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                KK MM                 dup1 dup1 min KK^ max MM^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                MM NN                 dup1 dup1 min MM^ max NN^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                KK MM                 dup1 dup1 min KK^ max MM^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                MM NN                 dup1 dup1 min MM^ max NN^
                PP HH                                   max HH^
                P HH                                    max HH^
                Z HH                            min Z^
                D LL                                    max LL^
                T LL                            min T^
                L T                                     max T^
                T Z                             min T^
                B JJ                                    max JJ^
                R JJ                            min R^
                J R                                     max R^
                F NN                                    max NN^
                V NN                            min V^
                N V                             min N^
                N R                                     max R^
                R T                                     max T^
                A II                                    max II^
                Q II                                    max II^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M U                                     max U^
                U AA                            min U^
                C KK                                    max KK^
                S KK                            min S^
                K S                                     max S^
                G OO                                    max OO^
                W OO                            min W^
                O W                             min O^
                O S                                     max S^
                S U                             min S^
                S T                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 43  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                  dup1 dup1 min O^  max GG^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                           min CC^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                            min Z^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M U                                     max U^
                U AA                  dup1 dup1 min U^  max AA^
                C KK                                    max KK^
                S KK                  dup1 dup1 min S^  max KK^
                K S                                     max S^
                CC KK                           min CC^
                G OO                                    max OO^
                W OO                            min W^
                O W                   dup1 dup1 min O^  max W^
                O S                                     max S^
                W CC                            min W^
                S U                                     max U^
                W AA                            min W^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N V                                     max V^
                V BB                            min V^
                D LL                                    max LL^
                T LL                            min T^
                L T                                     max T^
                H PP                                    max PP^
                Z PP                            min Z^
                P Z                             min P^
                P T                                     max T^
                T V                   dup1 dup1 min T^  max V^
                V W                             min
                T U                                     max

                X swap2 clip "                                : \
                                                                \
    n == 45  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                           min CC^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                            min Z^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                SS TT                 dup1 dup1 min SS^ max TT^
                QQ SS                 dup1 dup1 min QQ^ max SS^
                RR TT                 dup1 dup1 min RR^ max TT^
                RR SS                 dup1 dup1 min RR^ max SS^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK SS                 dup1 dup1 min KK^ max SS^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL TT                 dup1 dup1 min LL^ max TT^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                NN RR                 dup1 dup1 min NN^ max RR^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M U                                     max U^
                U AA                                    max AA^
                C KK                                    max KK^
                S KK                                    max KK^
                K SS                                    max SS^
                CC SS                           min CC^
                CC KK                           min CC^
                G OO                                    max OO^
                W OO                            min W^
                O W                                     max W^
                W CC                            min W^
                W AA                            min W^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N V                                     max V^
                V BB                            min V^
                D LL                                    max LL^
                T LL                            min T^
                L TT                            min L^
                L T                                     max T^
                H PP                                    max PP^
                Z PP                            min Z^
                P Z                             min P^
                P T                                     max T^
                T V                                     max V^
                V W                 dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 47  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                  dup1 dup1 min N^  max FF^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                  dup1 dup1 min Z^  max DD^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                           min DD^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                           min DD^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                SS TT                 dup1 dup1 min SS^ max TT^
                QQ SS                 dup1 dup1 min QQ^ max SS^
                RR TT                 dup1 dup1 min RR^ max TT^
                RR SS                 dup1 dup1 min RR^ max SS^
                UU VV                 dup1 dup1 min UU^ max VV^
                QQ UU                 dup1 dup1 min QQ^ max UU^
                SS UU                 dup1 dup1 min SS^ max UU^
                RR VV                 dup1 dup1 min RR^ max VV^
                TT VV                 dup1 dup1 min TT^ max VV^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM UU                 dup1 dup1 min MM^ max UU^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK SS                 dup1 dup1 min KK^ max SS^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN VV                 dup1 dup1 min NN^ max VV^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL TT                 dup1 dup1 min LL^ max TT^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                NN RR                 dup1 dup1 min NN^ max RR^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M UU                            min M^
                M U                                     max U^
                U AA                                    max AA^
                C KK                                    max KK^
                S KK                                    max KK^
                K SS                                    max SS^
                CC SS                           min CC^
                CC KK                 dup1 dup1 min CC^ max KK^
                G OO                                    max OO^
                W OO                            min W^
                O W                                     max W^
                W CC                            min W^
                W AA                  dup1 dup1 min W^  max AA^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N VV                            min N^
                N V                                     max V^
                V BB                  dup1 dup1 min V^  max BB^
                D LL                                    max LL^
                T LL                  dup1 dup1 min T^  max LL^
                L TT                  dup1 dup1 min L^  max TT^
                DD TT                           min DD^
                L T                                     max T^
                DD LL                           min DD^
                H PP                                    max PP^
                Z PP                            min Z^
                P Z                   dup1 dup1 min P^  max Z^
                P T                                     max T^
                Z DD                            min Z^
                T V                                     max V^
                Z BB                            min Z^
                Z AA                            min
                V W                                     max

                X swap2 clip "                                : \
                                                                \
    n == 49  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                  dup1 dup1 min N^  max FF^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                  dup1 dup1 min Z^  max DD^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                           min DD^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                           min DD^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                SS TT                 dup1 dup1 min SS^ max TT^
                QQ SS                 dup1 dup1 min QQ^ max SS^
                RR TT                 dup1 dup1 min RR^ max TT^
                RR SS                 dup1 dup1 min RR^ max SS^
                UU VV                 dup1 dup1 min UU^ max VV^
                WW YY                 dup1 dup1 min WW^ max YY^
                UU WW                 dup1 dup1 min UU^ max WW^
                VV YY                 dup1 dup1 min VV^ max YY^
                VV WW                 dup1 dup1 min VV^ max WW^
                QQ UU                 dup1 dup1 min QQ^ max UU^
                SS WW                 dup1 dup1 min SS^ max WW^
                SS UU                 dup1 dup1 min SS^ max UU^
                RR VV                 dup1 dup1 min RR^ max VV^
                TT YY                 dup1 dup1 min TT^ max YY^
                TT VV                 dup1 dup1 min TT^ max VV^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                VV WW                 dup1 dup1 min VV^ max WW^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM UU                 dup1 dup1 min MM^ max UU^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK SS                 dup1 dup1 min KK^ max SS^
                OO WW                 dup1 dup1 min OO^ max WW^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN VV                 dup1 dup1 min NN^ max VV^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL TT                 dup1 dup1 min LL^ max TT^
                PP YY                 dup1 dup1 min PP^ max YY^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                VV WW                 dup1 dup1 min VV^ max WW^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                NN RR                 dup1 dup1 min NN^ max RR^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                VV WW                 dup1 dup1 min VV^ max WW^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M UU                            min M^
                M U                                     max U^
                U AA                                    max AA^
                C KK                                    max KK^
                S KK                                    max KK^
                K SS                                    max SS^
                CC SS                           min CC^
                CC KK                           min CC^
                G OO                                    max OO^
                W OO                            min W^
                O WW                            min O^
                O W                                     max W^
                W CC                            min W^
                W AA                                    max AA^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N VV                            min N^
                N V                                     max V^
                V BB                                    max BB^
                D LL                                    max LL^
                T LL                                    max LL^
                L TT                                    max TT^
                DD TT                           min DD^
                DD LL                           min DD^
                H PP                                    max PP^
                Z PP                            min Z^
                P YY                            min P^
                P Z                                     max Z^
                Z DD                            min Z^
                Z BB                            min Z^
                Z AA                  dup1 dup1 max swap2 min

                X swap2 clip "                               : \
                                                               \
                Assert (false, string(n)+": Max input number reached.")

    return med }
