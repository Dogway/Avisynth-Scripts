###########################################################
###                                                      ##
###                                                      ##
###           ExTools v4.8.1    (12-08-2021)             ##
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
### Dependencies: AviSynth+ 3.5 and over
###
### Credits: Thanks to wonkey_monkey (David Horman) for Expr optimization tips
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
    fs   = Default(fulls,       rgb)
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
    fs   = Default(fulls,       rgb)
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
    fs   = Default(fulls,       rgb)
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
    fs  = Default(fulls,   rgb)

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
    fs  = Default(fulls,   rgb)

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
function ex_logic(clip a, clip b, string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "and")
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

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

    rgb  = isRGB(a)
    isya = isy(a)
    isym = isy(msk)
    bi   = BitsPerComponent(a)

    lm  = Default(luma,    isym && rgb)
    Y   = Default(Y,                 3)
    UV  = Default(UV,    rgb || lm ? 3 : isya ? 1 : 2)
    fs  = Default(fulls, rgb)

    isRGB(msk) ? Assert (!lm, "'luma=true' unsupported for RGB masks.") : nop()

    msk = isya ? isym ? msk           : \
                        ExtractY(msk) : \
          lm  || isym ||                \
          width (msk)!=width (a) ||     \
          height(msk)!=height(a)      ? \
          mskY_to_YYY(a, msk, lm, rgb, UV, bi) : msk

     str = "x x y - z 1 range_max / * * -"

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

    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ? Expr(a, hi, lo, str,                                     optSingleMode=false) : \
    UV == 1 ? Expr(a, hi, lo, str, "",                                 optSingleMode=false) : \
              Expr(a, hi, lo, str, cstr, scale_inputs=ex_UVf(rgb, bi), optSingleMode=false) }


# mt_binarize() is 12% slower than ex_binarize()
# mt_binarize() is 17% faster than ex_binarize(smooth=true)
# lo=-1 | hi=-1 replaces lo|hi with source "x"
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
    md = Default(mode, "simple")      # 'simple' or 'dynamic'
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    th  = ex_bs(th,  8, bi, fulls=fs)
    mx  = ex_bs(255, 8, bi, fulls=fs)
    thr = mx/255.
    lox = lo < 0   hix = hi < 0
    lox && hix ? Assert (false, "'lo' or 'hi': At least one bound should be binarized.") : nop()

    if (md=="otsu") {

        # Assumes TV range for YUV
        bnth = (rgb ? 255 : 219) / 10.
        off  =  rgb ?   0 :  16
        bs   =  rgb ? a.ConvertBits(8,dither=-1,fulls=fs).DotClip([0.298967,0.586421,0.114612]) : a.ConvertBits(8,dither=-1,fulls=fs)
        a    =  rgb ? bs.ConvertBits(bi,fulls=fs) : a
        br   = bs.width() > 720 ? bs.RatioResize(720., "adjust2w", kernel="bilinear") : bs
        isy  = rgb || isy

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

        """,args="a,br,bnth,off,in,sm,lo,hi,UV,bi,fs,rgb,isy",local=true)

        rgb ? CombinePlanes(last, last, last, planes="RGB") : last

    } else if (md=="dynamic") {

        ScriptClip(a,"""

        thm = round((AverageLuma(a,-2)+AverageLuma(a,0)+AverageLuma(a,2))/(3.*thr))
        ex_binarize(a,thm,in,sm,"simple",lo,hi,UV,fs)

        """,args="a,thr,in,sm,lo,hi,UV,fs",local=true)

    } else {

        if (sm) {

            # same output than smoothstep but faster
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

    cstr = ex_UVexpr(str, UV, bi, rgb, fs)

    isy     ?  Expr(a, str                                    ) : \
    UV == 1 ?  Expr(a, str, ""                                ) : \
               Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi))

    sm ? ex_boxblur(0.3,mode="weighted", UV=UV, fulls=fulls) : last } }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    UV  = Default(UV,    rgb ? 3 : 1)
    fs  = Default(fulls, rgb)

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
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

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



# Vinverse: a small, but effective Function against (residual) combing, by Didée
#           Ported to EX mod from real.finder's HBD mod. by Dogway (19-07-2021)

function ex_vinverse (clip clp, float "sstr", int "amnt", int "UV", clip "custem", bool "fulls") {

    UV   = Default(UV, 3)
    dcus = Defined(custem)
    sstr = Default(sstr, 2.7)       # strength of contra sharpening
    amnt = Default(amnt, 255)       # change no pixel by more than this (Default=255: unrestricted)
    fs   = Default(fulls, false)
    uv2  = (uv==2) ? 1 : uv
    bi   = BitsPerComponent(clp)
    amnt = ex_bs(amnt, 8, bi, fulls=fs)

    vblur  = clp.ex_boxblur(0, 1, "weighted", UV=uv)
    vblurD = ex_makediff(clp, vblur, UV=uv2, fulls=fs)
    Vshrp  = dcus ? clp : ex_lutxy(vblur, vblur.ex_boxblur(0, 2, "weighted", UV=uv2), Format("x x y - {sstr} * +"), UV=uv2, fulls=fs)
    VshrpD = ex_makediff(Vshrp, dcus ? custem : vblur, UV=uv2, fulls=fs)
    VlimD  = ex_lutxy(VshrpD, VblurD, "x range_half - A@ y range_half - B@ * 0 < A abs B abs < x y ? C@ range_half - 0.25 * range_half + C ?", UV=uv2, fulls=fs)

    ex_adddiff(dcus ? custem : Vblur, VlimD, UV=uv, fulls=fs)

    (amnt>254) ? last : \
    (amnt==0)  ? clp  : \
    ex_lutxy(clp, last, Format("x {amnt} + A@ y < A x {amnt} - B@ y > B y ? ?"), UV=uv, fulls=fs) }






######################
##   CONVOLUTIONS   ##
######################

# Convolutions in AviSynth+ work better with Prefetch(physical cores) than with threads. Also for RGTools and other plugins.

# EQUIVALENCES:
# blur(0.5)                                       ~> ex_boxblur(0.5,mode="weighted")
# removegrain(12) / blur(1.0)                     -> ex_boxblur(1,mode="weighted")
# removegrain(20) / blur(1.58)                    -> ex_boxblur(1,mode="mean")
# removegrain(19)                                 -> ex_boxblur(1,mode="rg19")
# removegrain(12).removegrain(20)                 ~> ex_blur(3)
# removegrain(12).removegrain(20).removegrain(20) ~> ex_blur(4.4)
# removegrain(20).removegrain(20)                 ~> ex_blur(3.5) -> ex_boxblur(3,mode="weighted") -> ex_boxblur(1,mode="mean").ex_boxblur(1,mode="mean")



# Variable Box Blur
#
# Benchmark:
# 100% removegrain(20,-1) (485fps)
#  91% ex_boxblur(1,mode="mean",UV=1)
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
# bokeh    average: mean average of a ring   kernel with equal weight per component (also known as lens blur)
# rg19     average: mean average of a square kernel with equal weight per component except central pixel (weight = 0) -matches removegrain(19)-
# weighted average: mean average of a square kernel with custom local weights per component (commonly used for a Gaussian approximations; blur(1), removegrain(12), etc)
# trimmed  average: mean average of a square kernel with equal weight per component limited by its local median
#
# *'weighted' allows 0.15, 0.3, 0.5 and 1, 2, 3...

# ex_boxblur(2,mode="weighted") same to ex_blur(2.5) and ex_boxblur(1,mode="mean").ex_boxblur(1,mode="mean"), and Dither_box_filter16(1,U=1,V=1).Dither_box_filter16(1,U=1,V=1), Dither_ about same speed
function ex_boxblur(clip a, float "radius", float "radiusV", string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to inf
    rv = Default(radiusV, rd)           # from 0 to inf

    fbox  = rd == 1    && rv == 1
    fbox2 = rd == 0.5  && rv == 0.5
    fbox3 = rd == 0.3  && rv == 0.3
    fbox4 = rd == 0.15 && rv == 0.15

    UV = Default(UV,    rgb  ? 3 : 1)
    md = Default(mode,  "mean")
    fs = Default(fulls, rgb)
    rd = max(rd>1?round(rd):rd, 0)
    rv = max(rv>1?round(rv):rv, 0)

    rv<1 || rd<1    ? Assert (md == "weighted", "<1 radius requires 'weighted' mode")            : nop()
    md == "trimmed" ? Assert (fbox, "'Trimmed' mode only supports radius=1 for both dimensions") : nop()
    md == "bokeh"   ? Assert (rd == rv, "'Bokeh' mode only supports isotropic radii")            : nop()

    krnlsz = ceil(2 * rd) + 1
    krnlrd = krnlsz/2

    krnh = ""  krnv = ""  plsh = ""  plsv = ""  divx=0  divy=0  divw=0
    if (md == "bokeh") {

        for (px = -krnlrd, krnlrd, 1) {
                for (py = -krnlrd, krnlrd, 1) {
                    rad   = cos(2.0 * atan(abs(py)/(abs(px)+sqrt(px*px + py*py))))
                    skipo =  px != 0 &&                       abs(px) >  krnlrd   *rad
                    skipi = (px != 0 || abs(py) == krnlrd) && abs(px) > (krnlrd-1)*rad
                    krnv  = skipo || !skipi                  ? krnv : Format(krnv + "x[{px},{py}] ")
                    plsv  = skipo || !skipi || py == -krnlrd ? plsv : plsv + "+ "
                    divy  = skipo || !skipi                  ? divy : divy + 1
           }      }

    } else if (!fbox || !(rd<1 || rv<1)) {

        for (px = -krnlrd, krnlrd, 1) {
            wg   = md == "weighted" ? factorial(krnlsz-1)/(factorial(px+krnlrd)*factorial(krnlsz-1-(px+krnlrd))) : nop()
            krnh = md == "rg19"    && px == 0 ? krnh                            : \
                   md == "weighted"        ? Format(krnh + "x[{px},0] {wg} * ") : \
                                             Format(krnh + "x[{px},0] ")
            plsh = px ==  -krnlrd || (md == "rg19" && px == 0) ? plsh : plsh + "+ "
            divw = md == "weighted" ? divw + wg : nop()
            divx = md == "rg19" &&    px == 0 ? divx  : \
                   md == "weighted"           ? divw  : divx + 1
           }

        krnlsz = ceil(2 * rv) + 1
        krnlrv = krnlsz/2
        divw=0
        for (py = -krnlrv, krnlrv, 1) {
            wg   = md == "weighted" ? factorial(krnlsz-1)/(factorial(py+krnlrv)*factorial(krnlsz-1-(py+krnlrv))) : nop()
            krnv = md == "rg19"    && py == 0 ? krnv                            : \
                   md == "weighted"        ? Format(krnv + "x[0,{py}] {wg} * ") : \
                                             Format(krnv + "x[0,{py}] ")
            plsv = py ==  -krnlrv || (md == "rg19" && py == 0) ? plsv : plsv + "+ "
            divw = md == "weighted" ? divw + wg : nop()
            divy = md == "rg19" &&    py == 0 ? divy  : \
                   md == "weighted"           ? divw  : divy + 1
           }
   }

    strv = md == "weighted" ?                                                                                                                              \
           fbox             ? "x[-1,1] 0.5 * x[0,1] x[1,1] 0.5 * x[0,0] 2 * x[-1,0] x[1,0] x[-1,-1] 0.5 * x[0,-1] x[1,-1] 0.5 * + + + + + + + + 1 8 / *" : \
           fbox2            ? "x[0,1] x[-1,0] x[0,0] 3  * x[1,0] x[0,-1] + + + + 1  7 / *"                                                               : \
           fbox3            ? "x[0,1] x[-1,0] x[0,0] 6  * x[1,0] x[0,-1] + + + + 1 10 / *"                                                               : \
           fbox4            ? "x[0,1] x[-1,0] x[0,0] 12 * x[1,0] x[0,-1] + + + + 1 16 / *"                                                               : \
           rv == 0.5        ? "x[0,1]  x[0,0] 5  * x[0,-1] + + 1  7 / *"                                                                                 : \
           rv == 0.3        ? "x[0,1]  x[0,0] 8  * x[0,-1] + + 1 10 / *"                                                                                 : \
           rv == 0.15       ? "x[0,1]  x[0,0] 16 * x[0,-1] + + 1 18 / *"                                                                                 : \
                              krnv + plsv + string(divy) + " 1 swap / *" : ""

    strh = md == "weighted" ?                                                                                                                              \
           rd == 0.5        ? "x[-1,0] x[0,0] 5  * x[1,0]  + + 1  7 / *"                                                                                 : \
           rd == 0.3        ? "x[-1,0] x[0,0] 8  * x[1,0]  + + 1 10 / *"                                                                                 : \
           rd == 0.15       ? "x[-1,0] x[0,0] 16 * x[1,0]  + + 1 18 / *"                                                                                 : \
                              krnh + plsh + string(divx) + " 1 swap / *" : ""


    str = fbox ? md == "rg19"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + 1 8 / *"                                           : \
                 md == "bokeh"    ?"x[0,1] x[-1,0] x[1,0] x[0,-1] + + + 1 4 / *"                                                                                   : \
                 md == "mean"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[0,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 1 9 / *"                                  : \
                 md == "trimmed"  ?"x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[0,0] E@ x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ + + + + + + + + 1 9 / * X^ "     \
                                  +"A D dup1 dup1 min A^ max D^ B H dup1 dup1 min B^ max H^ C F dup1 dup1 min C^ max F^ E I dup1 dup1 min E^ max I^ "                \
                                  +"A H dup1 dup1 min A^ max H^ C E dup1 dup1 min C^ max E^ D I dup1 dup1 min D^ max I^ F G dup1 dup1 min F^ max G^ "                \
                                  +"A C                  max C^ B D dup1 dup1 min B^ max D^ E F dup1 dup1 min E^ max F^ H I           min H^ "                       \
                                  +"B E                  max E^ D G           min D^        F H           min F^ "                                                   \
                                  +"C E dup1 dup1 min C^ max E^ D F dup1 dup1 min D^ max F^ "                                                                        \
                                  +"C D                  max D^ E F max D E min "                                                                                    \
                                  +"X swap2 clip" : "" : krnv + plsv + string(divy) + " 1 swap / *"


    strv =          md == "weighted" ? strv : \
           fbox  || md == "bokeh"    ? str  : \
           krnv + plsv + string(divy) + " 1 swap / *"

    strh =          md == "weighted" ? strh : \
           krnh + plsh + string(divx) + " 1 swap / *"

    rv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 || fbox || fbox2 || fbox3 || fbox4 || md=="bokeh"  ? last                 : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }

function factorial(int n) {
    n<2?1:factorial(n-1)*n }



# Variable Gaussian Blur
#
# Benchmark:
# 100% removegrain(12,-1) (486fps)        # technically a binomial weighted mean of [1 2 1]
#  97% GBlur2(0.75,chroma=2)              # only in 8-bit. weighted mean of [1 2 1]
#  88% ex_boxblur(1,mode="weighted",UV=1) # binomial weighted mean
#  88% ablur(1, 1, chroma=1)
#  85% BinomialBlur(0.75,U=1,V=1)         # only in 8-bit
#  68% ex_blur(1,UV=1)                    # true gaussian blur (output differs -more precise-)
#  68% blur(1.00)                         # weighted mean of [1 2 1]
#  64% generalconvolution(matrix="0 1 0 1 2 1 0 1 0",6,chroma=false) # doesn't match output tho
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#  23% GBlur(rad=1,sd=0.9,u=false,v=false)
#  11% FastBlur(0.75,gamma=false)
#  11% GaussianBlur(0.53,U=1,V=1)         # only in 8-bit
#
function ex_blur(clip a, float "radius", float "radiusV", string "gamma", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    sm = Default(radius,   1)
    sv = Default(radiusv, sm)
    gm = Default(gamma, "none")         # Set matrix for gamma encoded clips (ie. 601, 709, 2020...) Requires TransformsPack
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)
    sm = max(sm,0) / 5. + 0.5
    sv = max(sv,0) / 5. + 0.5

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
    sm == 0 ? last                                                                     : \
    isy     ? Expr(last, strh                                                        ) : \
    UV == 1 ? Expr(last, strh, ""                                                    ) : \
              Expr(last, strh, ex_UVexpr(cstrh, UV, bi, rgb, fs), scale_inputs="none")

    gm != "none" ? moncurve_r(last, s_gam[0], s_gam[1], false, !rgb, UV, fs) : last  }


function gauss_constructor(float rad, bool vert) {

    str = "" pls="" di=0
    krnlsz = 2*ceil(3*rad)

    for (i=0, krnlsz, 1) {
        wgc  = exp(-(pow(i-(krnlsz)/2.,2))/(2*rad*rad))
        di   = wgc < 0.001 ? di : di + wgc
       }

    for (i=0, krnlsz, 1) {

        ga    = exp(-(pow(i-(krnlsz)/2,2))/(2*rad*rad))
        wg    = ga/di
        px    = i - krnlsz/2
        str   = ga < 0.001 ? str : Format(str + (vert ? "x[0,{px}] {wg} * " : "x[{px},0] {wg} * "))
        pls   = i == krnlsz/2 || ga < 0.001 ? pls : pls + "+ "
       }

    str + pls }



# Dither_bilateral16(radius=2,thr=10,flat=1.0,u=1,v=1) is 232% faster than ex_bilateral(1,dejaggie=false) ('exp' is the culprit) # Dither_ output is dirtier though
# TBilateral(3,3,chroma=false) is same speed than ex_bilateral(1,dejaggie=false) but only supports 8-bits
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
    sm = max(min(sm * 0.30,2.0),0)
    sv = max(min(sv * 0.30,2.0),0)

    krnlsz = 2*ceil(3*sv)
    n_f    = factorial(krnlsz)

    vars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    Vc   = MidStr(vars,krnlsz/2+1,1)
    dj   = dj ? Vc+" 0.3 * min" : ""
    it   = 1./ ex_bs(it, 8, bi, fulls=fs)


    krnv2 = "" krnv3 = ""  Vv = "" krnh2 = "" krnh3 = "" Vh = ""

    for (i=0, krnlsz, 1) {

        V     = MidStr(vars,i+1,1)
        py    = i - krnlsz/2
        krnv1 = Format("x[0,{py}] ")

        Vv    = Vv + " " + V
        k_f   = factorial(i)*factorial(krnlsz-i)
        wg    = exp(pow(2, 1./ ((n_f/k_f)/pow(2,krnlsz) * ex_bs(st, 8, bi, fulls=fs)) ) / 2.)
        krnv2 = i != krnlsz/2 ? Format(krnv2 + krnv1 + V + "@ "+Vc+" - "+dj+" {it} * dup * 0.5 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnv2
        krnv3 = i == krnlsz/2 ? Format(                V + "  "+Vc+" - "+dj+" {it} * dup * 0.5 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnv3
        plsv  = i == 0 ? "" : plsv + " + "
       }


    krnlszh = 2*ceil(3*sm)
    n_f     = factorial(krnlszh)

    for (i=0, krnlszh, 1) {

        V     = MidStr(vars,i+1,1)
        px    = i - krnlszh/2
        krnh1 = Format("x[{px},0] ")

        Vh    = Vh + " " + V
        k_f   = factorial(i)*factorial(krnlszh-i)
        wg    = exp(pow(2, 1./ ((n_f/k_f)/pow(2,krnlszh) * ex_bs(st, 8, bi, fulls=fs)) ) / 2.)
        krnh2 = i != krnlsz/2 ? Format(krnh2 + krnh1 + V + "@ "+Vc+" - "+dj+" {it} * dup * 0.5 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnh2
        krnh3 = i == krnlsz/2 ? Format(                V + "  "+Vc+" - "+dj+" {it} * dup * 0.5 * exp {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnh3
        plsh  = i == 0 ? "" : plsh + " + "
       }

    strv = "x[0,0] " + Vc + "^ " + krnv2 + krnv3 + plsv + Vv + plsv + "1 swap / *"
    strh = "x[0,0] " + Vc + "^ " + krnh2 + krnh3 + plsh + Vh + plsh + "1 swap / *"

    sv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ? last                                                                    : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }



# Like ex_bilateral, a less gentle blurring but more performant
# Similar to SurfaceBlur by Didée: http://forum.doom9.org/showthread.php?p=1586287#post1586287
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
        divy  = divy + 1
       }

    krnlszh = 2*ceil(3*max(min(sm * 0.30,2.0),0))

    for (i=0, krnlszh, 1) {

        V     = MidStr(vars,i+1,1)
        Vh    = Vh + " " + V
        px    = i - krnlszh/2
        krnh2 = Format(krnh2 + "x[{px},0] " + V + "^ ")
        krnh3 = Vc != V ? Format(krnh3      + V + " " + Vc + " - abs ") : krnh3
        plsh  = i == 0 ? "" : Vc == V ? plsh : plsh + " + "
        divx = divx + 1
       }

    strv = krnv2 + krnv3 + plsv + string(th*sv) + " < " + Vv + plsv + " + " + string(divy) + " 1 swap / * x ?"
    strh = krnh2 + krnh3 + plsh + string(th*sm) + " < " + Vh + plsh + " + " + string(divx) + " 1 swap / * x ?"

    sv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ? last                                                                    : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }



# Savitzky-Golay (S-G) smoothing filter (similar to Gaussian blur)
function ex_smooth(clip a, int "radius", int "radiusV", bool "sharp", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to 3
    rv = Default(radiusV, rd)           # from 0 to 3
    sh = Default(sharp, false)
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)
    rd = max(rd, 0)
    rv = max(rv, 0)

    rd == 3 || rv == 3 ? Assert (!sh, "Sharp mode only for radius < 3") : nop()

    if (!sh) {

    # Quadratic/Cubic (2nd and 3rd degree polynomials)
    strv = rv == 1 ? "x[0,1] 4 * x[0,0] 5.666666666 * x[0,-1] 4 * + + x[0,-2] - x[0,2] - 3 35 / *"                                                                                        : \
           rv == 2 ? "x[0,2] x[0,1] 2 * x[0,0] 2.333333333 * x[0,-1] 2 * x[0,-2] + + + + x[0,-3] 0.666666666 * - x[0,3] 0.666666666 * - 1 7 / *"                                          : \
           rv == 3 ? "x[0,3] 4.666666666 * x[0,2] 13 * x[0,1] 18 * x[0,0] 19.666666666 * x[0,-1] 18 * x[0,-2] 13 * x[0,-3] 4.666666666 * + + + + + + x[0,-4] 7 * - x[0,4] 7 * - 1 77 / *" : \
                     "x"

    strh = rd == 1 ? "x[-1,0] 4 * x[0,0] 5.666666666 * x[1,0] 4 * + + x[2,0] - x[-2,0] - 3 35 / *"                                                                                        : \
           rd == 2 ? "x[-2,0] x[-1,0] 2 * x[0,0] 2.333333333 * x[1,0] 2 * x[2,0] + + + + x[3,0] 0.666666666 * - x[-3,0] 0.666666666 * - 1 7 / *"                                          : \
           rd == 3 ? "x[-3,0] 4.666666666 * x[-2,0] 13 * x[-1,0] 18 * x[0,0] 19.666666666 * x[1,0] 18 * x[2,0] 13 * x[3,0] 4.666666666 * + + + + + + x[4,0] 7 * - x[-4,0] 7 * - 1 77 / *" : \
                     "x"
    } else {

    # Quartic/Quintic (4th and 5th degree polynomials) (sharper)
    strv = rv == 1 ? "x[0,3] x[0,-3] x[0,1] 15 * x[0,0] 26.2 * x[0,-1] 15 * + + + + x[0,-2] 6 * - x[0,2] 6 * - 1 46.2 / *"                                                                : \
           rv == 2 ? "x[0,4] x[0,-4] x[0,2] 2 * x[0,1] 9 * x[0,0] 11.933333333 * x[0,-1] 9 * x[0,-2] 2 * + + + + + + x[0,-3] 3.666666666 * - x[0,3] 3.666666666 * - 1 28.6 / *"           : \
                     "x"

    strh = rd == 1 ? "x[-3,0] x[3,0] x[-1,0] 15 * x[0,0] 26.2 * x[1,0] 15 * + + + + x[2,0] 6 * - x[-2,0] 6 * - 1 46.2 / *"                                                                : \
           rd == 2 ? "x[-4,0] x[4,0] x[-2,0] 2 * x[-1,0] 9 * x[0,0] 11.933333333 * x[1,0] 9 * x[2,0] 2 * + + + + + + x[3,0] 3.666666666 * - x[-3,0] 3.666666666 * - 1 28.6 / *"           : \
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



# Kawase blur multipass kernel for optimized Gaussian blur approximation with high sigma (don't use for binarized masks)
#
# Benchmark:
# 100% ex_kawase(1,"lin",UV=1)  (442fps)
#  75% ex_boxblur(2,mode="weighted",UV=1)
#  75% removegrain(12,-1).removegrain(12,-1)
#  75% FRC_GaussianBlur42(1) # but scales up better than kawase for ex_kawase > 2
#  71% ex_blur(2,UV=1)       # ex_kawase(2,"lin") equals to ex_blur(8,UV=1)
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

    rd = Default(radius,  1)            # from 0 to ~10 (Expr hard limit)
    md = Default(mode, "log")
    UV = Default(UV,    rgb ? 3 : 2)
    fs = Default(fulls, rgb)

    str = ""
    for (i = 1, rd, 1) {
        c   = i == 1  ? "a," : ""
        dot = i == rd ? ""   : "."
        px  = md == "log"  ? Eval(LeftStr(String(log(i)/log(2)+1,"%0.1f"),1))      : \
              md == "fib"  ? floor(pow((1+sqrt(5))/2,i)/sqrt(5)+0.5)               : \
              md == "trib" ? floor(0.618033988749895*pow(1.839286755214161,i)+0.5) : \
                             i
        krn =                         Format("x[-{px},{px}] x[{px},{px}] x[-{px},-{px}] x[{px},-{px}]         x[0,0] + + + + 0.2 *")
        pxc = max(0, px - 1)
        krc = is444(a) || rgb ? krn : Format("x[-{pxc},{pxc}] x[{pxc},{pxc}] x[-{pxc},-{pxc}] x[{pxc},-{pxc}] x[0,0] + + + + 0.2 *")
        str = str + Format(isy     ?   "Expr(  "+c+"     "+Chr(34)+krn+Chr(34)+"                                                                                        )"   : \
                           UV == 1 ?   "Expr(  "+c+"     "+Chr(34)+krn+Chr(34)+",               "+Chr(34)+" "+Chr(34)+"                                                 )"   : \
                                     """Expr("""+c+""" """+Chr(34)+krn+Chr(34)+""", ex_UVexpr("""+Chr(34)+krc+Chr(34)+""", {UV}, {bi}, {rgb}, {fs}), scale_inputs="none")""")+dot
           }

    rd != 0 ? Eval(str) : a }





##############################
##
## Median Blur
##
## Replaces removegrain median modes, adaptivemedian, verticalcleaner, clense, degrainmedian, medianblur and medianblurtemporal, and adds new modes.
##
## Requires AviSynth+ 3.7.1
##
## 100% removegrain(1,-1)
##  91% ex_median(mode="undot",UV=1) # same as DeSaltPepper or SaltPepper from manyplus, or UnDot by Tom Barry.
##
## 100% removegrain(2,-1)
##  75% ex_median(mode="undot2",UV=1)
##
##  100% removegrain(4,-1)
##   75% ex_median(mode="median",UV=1)  # same as "undot4"
##   60% Dither_median16(rx=1, ry=1, rt=0, y=3, u=1, v=1)
##  1.2% MedianBlur(1,0,0)
## 0.06% mt_luts(last, "med", mt_square(1), "y",chroma="-1")
##
## 100% quantile(rank=13,radius_u=0,radius_v=0)      # 155fps (only 8-bits)
##  84% removegrainHD(rank=13,radius_u=0,radius_v=0) # (only 8-bits)
##  66% ex_median(mode="median5",UV=1)
##  10% Dither_median16(rx=2, ry=2, rt=0, y=3, u=1, v=1)
## 3.3% MedianBlur(2,0,0) (unstable filter)
##
##  100% Clense(grey=true)
##   92% ex_median(mode="medianT",UV=1)
##   91% MedianBlurTemporal(0,0,0)
##
## 100% ex_median(mode="medianST",UV=1)
##   81% MedianBlurTemporal(1,1,1) # re-assess without chroma (unstable filter)
#
# 34 modes:
# median    - True median. Replace with kernel middle value *Same as "undot4"   -removegrain(4)-
# median5   - True median. Replace with kernel middle value (5x5 kernel)
# EMF       - Extended Median Filter
# undot     - Also called "conservative", removes one pixel salt'n'pepper noise -removegrain(1)-
# undot2    - Same as undot but clip up to the second closest minimum values    -removegrain(2)-
# undot3    - Same as undot but clip up to the third  closest minimum values    -removegrain(3)-
# undot4    - Same as undot but clip up to the fourth closest minimum values*   -removegrain(4)-  *Same as "median"
# adaptive  - Similar to undot but better at salt'n'pepper noise.               -From VC Mohan AdaptiveMedian-
# SNN       - Symmetric Nearest Neighbour. Clip to closest opposing pair from center value
# kuwahara  - Mean average of the least variance quadrant in a 5x5 kernel window. (oil paint look/filter)
# pseudo    - Pseudo median. Replace with the average of the maximum of the minima and the minimum of the maxima of the sliding window
# weightedp - 50% weighted percentile weighted median
# weightedm - Mean average weighted median
# edgeS     - Edge sensitive. Same as 'median' but better edge protection. Strong denoise  -removegrain(17)-
# edgeW     - Edge sensitive. Only line pairs are used.                      Weak denoise  -removegrain(18)-
# edgeC     - Edge sensitive. Same as edgeS but better corner protection.   Strong denoise -removegrain(26)-
# edgeCL    - Edge sensitive. Same as edgeC but better line   protection.   Strong denoise -removegrain(27)-
# cartoon   - Clipping is done with respect to averages of neighbours.   Best for cartoons -removegrain(22)-
# vertical  - Vertical median. Port of VerticalCleaner mode=1
# verticalS - Vertical median. Port of VerticalCleaner mode=2 (edge sensitive)
# medianT   - Temporal median of 3 frames                                         (Temporal)
# medianT5  - Temporal median of 5 frames                                         (Temporal)
# medianST  - 3x3x3 Cubic Spatio-Temporal                                         (Spatio-Temporal)
# SixNN     - 1x3x1 Six Nearest-Neighbours                                        (Spatio-Temporal, Motion Protected)
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


#*SmartMedian and SmartMedian2 from RemoveGrainHD are not included. With radius=1 output is blotchy and jagged lines, with radius=2 it's like strong undot, it protects lines to some degree

function ex_median(clip a, string "mode", int "UV", bool "fulls", int "thres") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    mode = Default(mode, "median")
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)
    th   = Default(thres, mode=="EMF" ? 9 : 4)    # Only for EMF and DeGrainMedian modes
    th   = ex_bs(th, 8, bi, fulls=fs)

    Assert(IsVersionOrGreater(3,7,1), "Update AviSynth+ version to 3.7.1+")

    str =                                                                                                                                                                       \
        mode == "median5"? "x[-2,-2] x[-2,-1]     dup1 dup1 min D^ max X^
                            x[-2,0] x[-2,1]       dup1 dup1 min L^ max W^
                            x[-2,2] x[-1,-2]      dup1 dup1 min H^ max V^
                            x[-1,-1] x[-1,0]      dup1 dup1 min A^ max U^
                            x[-1,1] x[-1,2]       dup1 dup1 min R^ max T^
                            x[0,-2] x[0,-1]       dup1 dup1 min N^ max S^
                            x[0,1] x[0,2]         dup1 dup1 min C^ max Q^
                            x[1,-2] x[1,-1]       dup1 dup1 min J^ max P^
                            x[1,0] x[1,1]         dup1 dup1 min I^ max O^
                            x[1,2] x[2,-2]        dup1 dup1 min B^ max M^
                            x[2,-1] x[2,0]        dup1 dup1 min F^ max K^
                            x[2,1] x[2,2]         dup1 dup1 min E^ max G^
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
        mode == "pseudo" ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ x[0,0] M^ "           \
                          +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] Q^ x[0,-1] R^ x[1,-1] S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] X^ x[1,-2] Y^ x[2,-2] Z^ "             \
                          +"A B min C min F min G min H min K min L min M min C D min E min H min I min J min M min N min O min max "                                           \
                          +"K L min M min P min Q min R min U min V min X min M N min O min R min S min T min X min Y min Z min max max "                                       \
                          +"A B max C max F max G max H max K max L max M max C D max E max H max I max J max M max N max O max min "                                           \
                          +"K L max M max P max Q max R max U max V max X max M N max O max R max S max T max X max Y max Z max min min + 0.5 *"                              : \
                                                                                                                                                                                \
        mode == "SNN"    ? "x[-1,1] A@ x[0,0] J@ - abs x[1,-1] H@ J - abs + x[0,1] B@ J - abs x[0,-1] G@ J - abs + < A R@ H S@ + B R@ G S@ + ? Z^ "                             \
                          +"x[1,1] C@ J - abs x[-1,-1] F@ J - abs + x[-1,0] D@ J - abs x[1,0] E@ J - abs         + < C T@ F U@ + D T@ E U@ + ? Z^ "                             \
                          +"R J - abs S J - abs +                                    T J - abs U J - abs         + < R R@ S S@ + T R@ U S@ + ? Z^ "                             \
                          +"J R S dup1 dup1 min swap2 max clip"                                                                                                               : \
                                                                                                                                                                                \
        mode == "kuwahara"?"x[-2,2] A@ x[-1,2] B@ x[0,2] C@ x[-2,1] F@ x[-1,1] G@ x[0,1] H@ x[-2,0] K@ x[-1,0] L@ x[0,0] M@ + + + + + + + + 1 9 / * W^    "                     \
                          +"C x[1,2] D@ x[2,2] E@ H x[1,1] I@ x[2,1] J@ M x[1,0] N@ x[2,0] O@                               + + + + + + + + 1 9 / * WW^ "                       \
                          +"K L M x[-2,-1] P@ x[-1,-1] Q@ x[0,-1] R@ x[-2,-2] U@ x[-1,-2] V@ x[0,-2] X@                     + + + + + + + + 1 9 / * WWW^ "                      \
                          +"A W   - dup * B W   - dup * C W   - dup * F W   - dup * G W   - dup * H W   - dup * K W   - dup * L W   - dup * M W   - dup * + + + + + + + + AA^ " \
                          +"C WW  - dup * D WW  - dup * E WW  - dup * H WW  - dup * I WW  - dup * J WW  - dup * M WW  - dup * N WW  - dup * O WW  - dup * + + + + + + + + BB^ " \
                          +"K WWW - dup * L WWW - dup * M WWW - dup * P WWW - dup * Q WWW - dup * R WWW - dup * U WWW - dup * V WWW - dup * X WWW - dup * + + + + + + + + CC^ " \
                          +"AA BB min CC min EE^ EE AA == W EE BB == WW EE CC == WWW M N O R x[1,-1] x[2,-1] X x[1,-2] x[2,-2] + + + + + + + + 1 9 / * ? ? ?"                 : \
                                                                                                                                                                                \
        mode == "weightedp"?"x[-1,1]  x[0,1]       dup1 dup1 min swap2 max
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
                             A B C + + R@ dup D E F G H I + + + + + + 0.5 * W@ - abs Z^
                             R     D  +                                                  W  - abs Y^ R D E + + W - abs X^ R D E F + + + W - abs V^
                             Z Y < C Y X < D X V < E F ? ? ?"                                                                                                       : \
                                                                                                                                                                      \
        mode == "weightedm"?"x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[0,0] E@ x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ + + + + + + + + 1 9 / * W@ "             \
                           +"A swap - abs B W - abs < A B ? Z@ W - abs C W - abs < Z C ? Y@ W - abs D W - abs < Y D ? X@ W - abs E W - abs < X E ? "                  \
                           +"V@   W - abs F W - abs < V F ? U@ W - abs G W - abs < U G ? T@ W - abs H W - abs < T H ? S@ W - abs I W - abs < S I ? "                : \
                                                                                                                                                                      \
        mode == "adaptive"?"x[-1,1]  G@ x[0,1]  H@ dup1 dup1 min swap2 max
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
                            L M                   dup1 dup1 min L^ max M^

                            x L M clip F^
                            MT ZA > MT ZZ < & x ZA > x ZZ < & x MT ? F A > F X < & x A > x X < & x F ? x ? ?"                                                       : \
                                                                                                                                                                      \
        mode == "undot"  ? "x[-1,1] A@ x[0,1] B@ max x[1,1] C@ max x[-1,0] D@ max x[1,0] E@ max x[-1,-1] F@ max x[0,-1] G@ max x[1,-1] H@ max "                       \
                          +"A B min C min D min E min F min G min H min x swap2 clip"                                                                               : \
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
        mode == "Vertical" ?"x[0,1] x[0,-1] dup1 dup1 max swap2 min
                             x swap2 clip"                                                                                                                          : \
                                                                                                                                                                      \
        mode == "verticalS"? ex_dlut("
                             x[0,-2] B2^ x[0,-1] B1^ x[0,1] T1^ x[0,2] T2^
                             B1 B2    - 0 range_max clip B1 + 0 range_max clip    T1 T2 - 0 range_max clip T1 + 0 range_max clip min B1 max T1 max
                             B1 B2 B1 - 0 range_max clip -    0 range_max clip T1 T2 T1 - 0 range_max clip    - 0 range_max clip max B1 T1 min min
                             x swap2 clip", bi, fs)                                                                                                                 : \
                                                                                                                                                                      \
        mode == "cartoon"? "x[-1,1] A@ x[1,-1] H@ + x[0,1] B@ x[0,-1] G@ + max x[1,1] C@ x[-1,-1] F@ + max x[-1,0] D@ x[1,0] E@ + max 0.5 * "                         \
                          +"A H +                          B G + min                  C F +            min         D E +          min 0.5 * x swap2 clip"           : \
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
                            B A - AM^
                            D C - AA^
                            F E - AB^
                            H G - AC^
                            J I - AD^
                            L K - AE^
                            N M - AF^
                            P O - AG^
                            R Q - AH^
                            T S - AI^
                            V U - AJ^
                            X W - AK^
                            Z Y - AL^
                            AM
                            AA min
                            AB min
                            AC min
                            AD min
                            AE min
                            AF min
                            AG min
                            AH min
                            AI min
                            AJ min
                            AK min
                            AL min BB^

                            BB AL == x Y Z clip BB AJ == x U V clip BB AK == x W X clip BB AI == x S T clip BB AG == x O P clip BB AH == x Q R clip
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

                            B A - 4 * x dup A B clip A@ - abs + AM^
                            D C - 4 * x dup C D clip B@ - abs + AA^
                            F E - 4 * x dup E F clip C@ - abs + AB^
                            H G - 4 * x dup G H clip D@ - abs + AC^
                            J I - 4 * x dup I J clip E@ - abs + AD^
                            L K - 4 * x dup K L clip F@ - abs + AE^
                            N M - 4 * x dup M N clip G@ - abs + AF^
                            P O - 4 * x dup O P clip H@ - abs + AG^
                            R Q - 4 * x dup Q R clip I@ - abs + AH^
                            T S - 4 * x dup S T clip J@ - abs + AI^
                            V U - 4 * x dup U V clip K@ - abs + AJ^
                            X W - 4 * x dup W X clip L@ - abs + AK^
                            Z Y - 4 * x dup Y Z clip M@ - abs + AL^
                            AM
                            AA min
                            AB min
                            AC min
                            AD min
                            AE min
                            AF min
                            AG min
                            AH min
                            AI min
                            AJ min
                            AK min
                            AL min BB^

                            BB AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
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

                            B A - 2 * x dup A B clip A@ - abs + AM^
                            D C - 2 * x dup C D clip B@ - abs + AA^
                            F E - 2 * x dup E F clip C@ - abs + AB^
                            H G - 2 * x dup G H clip D@ - abs + AC^
                            J I - 2 * x dup I J clip E@ - abs + AD^
                            L K - 2 * x dup K L clip F@ - abs + AE^
                            N M - 2 * x dup M N clip G@ - abs + AF^
                            P O - 2 * x dup O P clip H@ - abs + AG^
                            R Q - 2 * x dup Q R clip I@ - abs + AH^
                            T S - 2 * x dup S T clip J@ - abs + AI^
                            V U - 2 * x dup U V clip K@ - abs + AJ^
                            X W - 2 * x dup W X clip L@ - abs + AK^
                            Z Y - 2 * x dup Y Z clip M@ - abs + AL^
                            AM
                            AA min
                            AB min
                            AC min
                            AD min
                            AE min
                            AF min
                            AG min
                            AH min
                            AI min
                            AJ min
                            AK min
                            AL min BB^

                            BB AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
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

                            B A - x dup A B clip A@ - abs + AM^
                            D C - x dup C D clip B@ - abs + AA^
                            F E - x dup E F clip C@ - abs + AB^
                            H G - x dup G H clip D@ - abs + AC^
                            J I - x dup I J clip E@ - abs + AD^
                            L K - x dup K L clip F@ - abs + AE^
                            N M - x dup M N clip G@ - abs + AF^
                            P O - x dup O P clip H@ - abs + AG^
                            R Q - x dup Q R clip I@ - abs + AH^
                            T S - x dup S T clip J@ - abs + AI^
                            V U - x dup U V clip K@ - abs + AJ^
                            X W - x dup W X clip L@ - abs + AK^
                            Z Y - x dup Y Z clip M@ - abs + AL^
                            AM
                            AA min
                            AB min
                            AC min
                            AD min
                            AE min
                            AF min
                            AG min
                            AH min
                            AI min
                            AJ min
                            AK min
                            AL min BB^

                            BB AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
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

                            B A - x dup A B clip A@ - abs 2 * + AM^
                            D C - x dup C D clip B@ - abs 2 * + AA^
                            F E - x dup E F clip C@ - abs 2 * + AB^
                            H G - x dup G H clip D@ - abs 2 * + AC^
                            J I - x dup I J clip E@ - abs 2 * + AD^
                            L K - x dup K L clip F@ - abs 2 * + AE^
                            N M - x dup M N clip G@ - abs 2 * + AF^
                            P O - x dup O P clip H@ - abs 2 * + AG^
                            R Q - x dup Q R clip I@ - abs 2 * + AH^
                            T S - x dup S T clip J@ - abs 2 * + AI^
                            V U - x dup U V clip K@ - abs 2 * + AJ^
                            X W - x dup W X clip L@ - abs 2 * + AK^
                            Z Y - x dup Y Z clip M@ - abs 2 * + AL^
                            AM
                            AA min
                            AB min
                            AC min
                            AD min
                            AE min
                            AF min
                            AG min
                            AH min
                            AI min
                            AJ min
                            AK min
                            AL min BB^

                            BB AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
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

                            x dup A B clip A@ - abs AM^
                            x dup C D clip B@ - abs AA^
                            x dup E F clip C@ - abs AB^
                            x dup G H clip D@ - abs AC^
                            x dup I J clip E@ - abs AD^
                            x dup K L clip F@ - abs AE^
                            x dup M N clip G@ - abs AF^
                            x dup O P clip H@ - abs AG^
                            x dup Q R clip I@ - abs AH^
                            x dup S T clip J@ - abs AI^
                            x dup U V clip K@ - abs AJ^
                            x dup W X clip L@ - abs AK^
                            x dup Y Z clip M@ - abs AL^
                            AM
                            AA min
                            AB min
                            AC min
                            AD min
                            AE min
                            AF min
                            AG min
                            AH min
                            AI min
                            AJ min
                            AK min
                            AL min BB^

                            BB AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "edgeS"  ? "x[-1,1] x[1,-1]  dup1 dup1 min swap2 max
                            x[0,1]  x[0,-1]  dup1 dup1 min swap2 max
                            x[1,1]  x[-1,-1] dup1 dup1 min swap2 max
                            x[-1,0] x[1,0]   dup1 dup1 min swap2 max
                            swap3             max swap2 min
                            swap3 swap1 swap5 max swap3 min
                                              min swap2 max
                                    dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
        mode == "edgeW"  ? "                                              x[0,0] I@ x[0,1]  B@ - abs I x[0,-1] G@ - abs max BB^ "                                    \
                          +"I x[1,1] C@ - abs I x[-1,-1] F@ - abs max CC^        I  x[-1,0] D@ - abs I x[1,0]  E@ - abs max DD^ "                                    \
                          +"I x[-1,1] A@ - abs I x[1,-1] H@ - abs max BB min CC min DD min "                                                                         \
                          +"X@ DD == I D E dup1 dup1 min swap2 max clip X BB == I B G dup1 dup1 min swap2 max clip "                                                 \
                          +"X  CC == I C F dup1 dup1 min swap2 max clip         I A H dup1 dup1 min swap2 max clip ? ? ?"                                          : \
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
                            swap1 swap2 min min min                         HI min HI^

                            x LO HI min LO HI max clip"                                                                                                            : \
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
                            swap1 swap2 min min min                         HI min HI^

                            x LO HI min LO HI max clip"                                                                                                            : \
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
        mode == "SixNN" ? "x[0,0] x[0,1]         dup1 dup1 min swap2 max
                           x[0,-1] y[0,0]        dup1 dup1 min swap2 max
                           swap3  z[0,0]         dup1 dup1 min swap2 max
                           swap2  swap1  swap3   dup1 dup1 min swap2 max
                           swap3                                     max
                           swap3                 dup1 dup1 min swap2 max
                           swap3                                     max
                           swap2                           min
                                                           min"                                                                                                    : \
                                                                                                                                                                     \
        mode == "ML3D" ? "x[1,1] x[-1,-1]       dup1 dup1 min swap2 max
                          x[-1,1] x[1,-1]       dup1 dup1 min swap2 max
                          x[0,0] X@  y[0,0] Y@  dup1 dup1 min swap2 max
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

                          x[1,0] x[0,-1]        dup1 dup1 min swap2 max
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
        mode == "ML3Dex"? "x[1,1] x[-1,-1]       dup1 dup1 min swap2 max
                          x[-1,1] x[1,-1]       dup1 dup1 min swap2 max
                          x[0,0] X@  y[0,0] Y@  dup1 dup1 min swap2 max
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

                          x[1,0] x[0,-1]        dup1 dup1 min swap2 max
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
                                                          min  B^

                          y[1,1] y[-1,-1]       dup1 dup1 min swap2 max
                          y[-1,1] y[1,-1]       dup1 dup1 min swap2 max
                          Y  X                  dup1 dup1 min swap2 max
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

                          y[1,0] y[0,-1]        dup1 dup1 min swap2 max
                          y[-1,0] y[0,1]        dup1 dup1 min swap2 max
                          Y  X                  dup1 dup1 min swap2 max
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
        mode == "BDM" ? "x[1,1] x[-1,-1]       dup1 dup1 min swap2 max
                         x[-1,1] x[1,-1]       dup1 dup1 min swap2 max
                         x[0,0] X@  y[0,0] Y@  dup1 dup1 min swap2 max
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

                         y[1,1] y[-1,-1]       dup1 dup1 min swap2 max
                         y[-1,1] y[1,-1]       dup1 dup1 min swap2 max
                         z[1,1]  z[-1,-1]      dup1 dup1 min swap2 max
                         z[-1,1] z[1,-1]       dup1 dup1 min swap2 max
                         Y Z                   dup1 dup1 min swap2 max
                         swap9  swap1  swap7   dup1 dup1 min swap2 max
                         swap3  swap1  swap7   dup1 dup1 min swap2 max
                         swap4  X              dup1 dup1 min swap2 max
                         swap7  swap1  swap9   dup1 dup1 min swap2 max
                         swap3  swap1  swap10  dup1 dup1 min swap2 max
                         swap4  swap1  swap2   dup1 dup1 min swap2 max
                         swap6  swap1  swap5   dup1 dup1 min swap2 max
                         swap9  swap1  swap2   dup1 dup1 min swap2 max
                         swap4  swap1  swap7             min
                         swap7  swap1  swap6                       max
                         swap3  swap1  swap5                       max
                         swap3                 dup1 dup1 min swap2 max
                         swap6  swap1  swap4             min
                         swap6  swap1  swap4   dup1 dup1 min swap2 max
                         swap2                 dup1 dup1 min swap2 max
                         swap4  swap1  swap6   dup1 dup1 min swap2 max
                         swap5  swap1  swap2             min
                         swap5                                     max
                         swap2                 dup1 dup1 min swap2 max
                         swap3  swap1  swap4             min
                         swap3                                     max
                         swap2                           min
                                                                   max B^

                         y[1,0] y[0,-1]        dup1 dup1 min swap2 max
                         y[-1,0] y[0,1]        dup1 dup1 min swap2 max
                         z[1,0] z[0,-1]        dup1 dup1 min swap2 max
                         z[-1,0] z[0,1]        dup1 dup1 min swap2 max
                         Y Z                   dup1 dup1 min swap2 max
                         swap9  swap1  swap7   dup1 dup1 min swap2 max
                         swap3  swap1  swap7   dup1 dup1 min swap2 max
                         swap4  X              dup1 dup1 min swap2 max
                         swap7  swap1  swap9   dup1 dup1 min swap2 max
                         swap3  swap1  swap10  dup1 dup1 min swap2 max
                         swap4  swap1  swap2   dup1 dup1 min swap2 max
                         swap6  swap1  swap5   dup1 dup1 min swap2 max
                         swap9  swap1  swap2   dup1 dup1 min swap2 max
                         swap4  swap1  swap7             min
                         swap7  swap1  swap6                       max
                         swap3  swap1  swap5                       max
                         swap3                 dup1 dup1 min swap2 max
                         swap6  swap1  swap4             min
                         swap6  swap1  swap4   dup1 dup1 min swap2 max
                         swap2                 dup1 dup1 min swap2 max
                         swap4  swap1  swap6   dup1 dup1 min swap2 max
                         swap5  swap1  swap2             min
                         swap5                                     max
                         swap2                 dup1 dup1 min swap2 max
                         swap3  swap1  swap4             min
                         swap3                                     max
                         swap2                           min
                                                                   max C^

                         X Y dup1 dup1 min swap2 max swap1 Z max min

                         dup A min B min C min swap1 A max B max C max

                         dup1 dup1 min swap2 max swap1 X max min"                                                                                                  : \
                                                                                                                                                                     \
        mode == "MMF" ? "x[0,0] X@ x[0,1] A@   dup1 dup1 min swap2 max
                         x[0,-1] B@ y[0,0] Y@  dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min J^

                         X x[1,0] D@           dup1 dup1 min swap2 max
                         x[-1,0] E@ Y          dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min K^

                         X x[1,1] F@           dup1 dup1 min swap2 max
                         x[-1,-1] G@ Y         dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min L^

                         X x[-1,1] H@          dup1 dup1 min swap2 max
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
        mode == "PML" ? "x[0,0] X@ x[0,1] A@   dup1 dup1 min swap2 max
                         x[0,-1] B@ y[0,0] Y@  dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min J^

                         X x[1,0] C@           dup1 dup1 min swap2 max
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
                         Assert (false, "Unsupported median mode.")


    temp5 = mode == "medianT5"
    temp  = mode == "medianT" || mode == "medianST" || mode == "ML3D" || mode == "ML3Dex" || mode == "BDM" || mode == "MMF" || mode == "SixNN" || mode == "PML" ||  temp5 || \
            mode == "DGM0"  || mode == "DGM1" || mode == "DGM2"  || mode == "DGM3" || mode == "DGM4"  || mode == "DGM5"

    if (temp) {

        b  = a.selectevery(1,-1)
        f  = a.selectevery(1,+1)
        b2 = temp5 ? a.selectevery(1,-2) : nop()
        f2 = temp5 ? a.selectevery(1,+2) : nop()

       !temp5                                                                                                             ? \
        isy     ? Expr(a, b,     f,     str,                                  optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, b,     f,     str, "",                              optSingleMode = false                     ) : \
                  Expr(a, b,     f,     str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = false, scale_inputs="none") : \
        isy     ? Expr(a, b2, b, f, f2, str,                                  optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, b2, b, f, f2, str, "",                              optSingleMode = false                     ) : \
                  Expr(a, b2, b, f, f2, str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = false, scale_inputs="none")

    } else {

    isy     ? Expr(a, str,                                  optSingleMode = mode == "weightedp"                     ) : \
    UV == 1 ? Expr(a, str, "",                              optSingleMode = mode == "weightedp"                     ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = mode == "weightedp", scale_inputs="none") } }



# Replaces Repair() and TemporalRepair() (which plugin seems broken)
# median    - repair(4)
# medianc   - repair(14)
# undot     - repair(1)
# undot2    - repair(2)
# undot3    - repair(3)
# undot4    - repair(4)
# undot4c   - repair(14)
# edgeSP    - repair(16). Edge sensitive with line pairs. Fair edge repair. (analogue to removegrain(6))
# edgeS     - repair(17)
# edgeW     - repair(18)
# cartoon   - repair(22)
# cartoonc  - repair(19)
# temp0     - TemporalRepair mode=0
# temp1     - TemporalRepair mode=1
# temp2     - TemporalRepair mode=2
# temp3     - TemporalRepair mode=3
# temp4     - TemporalRepair mode=4

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
                            y[-2,0] y[-2,1]       dup1 dup1 min Q^ max X^
                            y[-2,2] y[-1,-2]      dup1 dup1 min G^ max V^
                            y[-1,-1] y[-1,0]      dup1 dup1 min H^ max U^
                            y[-1,1] y[-1,2]       dup1 dup1 min E^ max T^
                            y[0,-2] y[0,-1]       dup1 dup1 min F^ max S^
                            y[0,0] y[0,1]         dup1 dup1 min P^ max R^
                            y[0,2] y[1,-2]        dup1 dup1 min N^ max O^
                            y[1,-1] y[1,0]        dup1 dup1 min L^ max M^
                            y[1,1] y[1,2]         dup1 dup1 min I^ max K^
                            y[2,-2] y[2,-1]       dup1 dup1 min C^ max J^
                            y[2,0] y[2,1]         dup1 dup1 min B^ max D^
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
        mode == "undot" ? "y[-1,1] A@ y[0,1] B@ max y[1,1] C@ y[-1,0] D@ max max y[1,0] F@ y[-1,-1] G@ max y[0,-1] H@ y[1,-1] I@ max max max "                       \
                         +"A B min C D min min F G min H I min min min x swap2 clip"                                                                               : \
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
        mode=="edgeSP"   ? ex_dlut("y[1,-1] y[-1,1] dup1 dup1 min A^ max B^
                            y[1,1] y[-1,-1] dup1 dup1 min C^ max D^
                            y[0,1] y[0,-1]  dup1 dup1 min E^ max F^
                            y[1,0] y[-1,0]  dup1 dup1 min G^ max H^

                            y dup A B clip A@ - abs 2 * B A - + 0 range_max clip AM^
                            y dup C D clip B@ - abs 2 * D C - + 0 range_max clip AA^
                            y dup E F clip C@ - abs 2 * F E - + 0 range_max clip AB^
                            y dup G H clip D@ - abs 2 * H G - + 0 range_max clip AC^

                            AM AA min AB min AC min BB^

                            BB AC == x y G min y H max clip
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
        mode == "edgeW"  ? "                                              y[0,0] I@ y[0,1]  B@ - abs I y[0,-1] G@ - abs max BB^ "                                    \
                          +"I y[1,1] C@ - abs I y[-1,-1] F@ - abs max CC^        I  y[-1,0] D@ - abs I y[1,0]  E@ - abs max DD^ "                                    \
                          +"I y[-1,1] A@ - abs I y[1,-1] H@ - abs max BB min CC min DD min "                                                                         \
                          +"S@ DD == x D E dup1 dup1 min I min swap2 max I max clip S BB == x B G dup1 dup1 min I min swap2 max I max clip "                         \
                          +"S  CC == x C F dup1 dup1 min I min swap2 max I max clip          x A H dup1 dup1 min I min swap2 max I max clip ? ? ?"                 : \
                                                                                                                                                                     \
        mode == "cartoonc"? ex_dlut("y[0,0] Y@ y[1,1] - abs Y y[1,0] - abs min Y y[1,-1] - abs min Y y[-1,1] - abs min Y y[-1,0] - abs min Y y[-1,-1] - abs min Y y[0,1] - abs min Y y[0,-1] - abs min DI^ " \
                                   +"Y DI + 0 range_max clip Y DI - 0 range_max clip x swap2 clip", bi, fs)                                                        : \
                                                                                                                                                                     \
        mode == "cartoon"? ex_dlut("x[0,0] X@ y[1,1] - abs X y[1,0] - abs min X y[1,-1] - abs min X y[-1,1] - abs min X y[-1,0] - abs min X y[-1,-1] - abs min X y[0,1] - abs min X y[0,-1] - abs min DI^ " \
                                  +"X DI + 0 range_max clip X DI - 0 range_max clip y swap2 clip", bi, fs)                                                         : \
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
                            M M a - 0 max dup + - N max P^
                            N O == M P == or a x P O clip ?"                                                                                                       : \
                                                                                                                                                                     \
                          Assert (false, "Unsupported repair mode.")


    if (FindStr(mode, "emp")>0) {

        c  = a.selectevery(1,-1)
        d  = a.selectevery(1,+1)

        isy     ? Expr(a, c, d, b,    str,                                  optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, c, d, b,    str, "",                              optSingleMode = false                     ) : \
                  Expr(a, c, d, b,    str, ex_UVexpr(str, UV, bi, rgb, fs), optSingleMode = false, scale_inputs="none")

    } else {

    isy     ? Expr(a, b, str                                                      ) : \
    UV == 1 ? Expr(a, b, str, ""                                                  ) : \
              Expr(a, b, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") } }



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
## Smooth: Opening + Closing, effectively cleaning binary images
##   ex_inpand(n).ex_expand(n+n).ex_inpand(n)
##
## Outline: To reveal the outer edge of a line
##   ex_makediff(ex_expand(n), a, dif=false)
##
## Inline: To reveal the inner edge of a line
##   ex_makediff(a, ex_inpand(n), dif=false)
##
## Gradient: To reveal the boundary of elements in a binary image
##   ex_makediff(ex_expand(n), ex_inpand(n), dif=false)
##   or
##   ex_hitormiss(mode="boundary") # thinner
##
## Top Hat:   (a - opening) To reveal bright elements over dark backgrounds on a greyscale image
##   ex_makediff(a, ex_inpand(n).ex_expand(n), dif=false)
##
## Black Hat: (closing - a) To reveal dark elements over bright backgrounds on a greyscale image
##   ex_makediff(ex_expand(n).ex_inpand(n), a, dif=false)
##


# mt_expand() is 6% faster (6% slower when radius = 2)
# modes: square, circle, vertical, horizontal, both
# "circle" + radius=2 is like calling mode="both" twice but faster
function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    !(mode == "square" || mode == "circle" || mode == "vertical"  || mode == "horizontal" || mode == "both") ? \
    Assert(false, "Unsupported mode.") : nop()

    th = ex_bs(thr, 8, bi, fulls=fs)

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
# modes: square, circle, vertical, horizontal, both
function ex_inpand(clip a, int "radius", string "mode", int "thres", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    !(mode == "square" || mode == "circle" || mode == "vertical"  || mode == "horizontal" || mode == "both") ? \
    Assert(false, "Unsupported mode.") : nop()

    th  = ex_bs(thr, 8, bi, fulls=fs)

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

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(krnlsz*krnlsz-1) + " 1 swap / * x[0,0] min"

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

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(krnlsz*krnlsz-1) + " 1 swap / * x[0,0] max"

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") }


# Hit-or-Miss morphological transform (HMT)
#
# Requires AviSynth+ 3.7.1 (for string line carriage)
#
# modes:
# thin         - Like erode (inpand) but one pixel at a time without complete removal (leads to 'skeleton')
# thicken      - Like dilate (expand) but one pixel at a time without element merging (leads to 'SKIZ')
# prune        - To remove thin branches from the main binary element bodies
# pruneS       - Prune strong
# boundary     - Get the boundary edge of the element bodies
# convexhull   - Minimal geometry representation of the element body (fills concave contours)
# convexhull45 - 45º convex hull approximation
# corner       - Detects right angle pixel corners (ie. jaggies) (WIP)
# cornerS      - Corner strong
# skeleton     - Minimal 1 pixel representation of element bodies in binary image                            (iterate 'thin' until stable -no more changes-)
# SKIZ         - Skeleton by zone of influence. Also known as background skeletonization or Voronoi diagram. (iterate 'thicken' or 'convehull' until stable)
# end          - Extracts end pixels      (to be used after skeleton)
# junction     - Extracts junction pixels (to be used after skeleton). Also known as branched points
# connected    - Extracts connected components (not implemented)
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

    md == "boundary" || md == "end" || md == "junction" || md == "corner" || md == "cornerS" ? \
    Assert(rd == 1, md+" mode only supports radius=1") : nop()

    if (rd > 1) {

        ex_hitormiss(a,   rd-1,  md, UV, fs)
        ex_hitormiss(last,   1,  md, UV, fs)

    } else {

    krn = "range_max x[-1,-1] A@ - O^ range_max  x[0,-1] B@ - P^ range_max x[1,-1] C@ - Q^
           range_max x[-1,0]  D@ - R^            x[0,0]  E^      range_max x[1,0]  F@ - T^
           range_max x[-1,1]  G@ - U^ range_max  x[0,1]  H@ - V^ range_max x[1,1]  I@ - W^ "

    # Structuring Elements
    str = md == "thin"       ? "O P min Q min E min G min H min I min
                                P Q min T min D min E min G min H min max
                                Q T min W min A min D min G min E min max
                                T V min W min A min D min B min E min max
                                U V min W min A min B min C min E min max
                                R U min V min B min E min C min F min max
                                O R min U min C min F min I min E min max
                                O P min R min E min H min F min I min max range_max swap - x *"                   : \
                                                                                                                    \
          md == "thicken"    ? "O P max Q max E max G max H max I max
                                P Q max T max D max E max G max H max min
                                Q T max W max A max D max G max E max min
                                T V max W max A max D max B max E max min
                                U V max W max A max B max C max E max min
                                R U max V max B max E max C max F max min
                                O R max U max C max F max I max E max min
                                O P max R max E max H max F max I max min range_max x - * range_max swap -"      : \
                                                                                                                   \
          md == "prune"      ? "P Q min T min W min V min D min E min
                                R U min V min W min T min B min E min max
                                O P min R min U min V min F min E min max
                                O R min P min Q min T min H min E min max
                                P Q min T min W min V min U min R min A min E min max
                                P O min T min W min V min U min R min C min E min max
                                P Q min T min O min V min U min R min I min E min max
                                P Q min T min W min V min O min R min G min E min max range_max swap - x *"      : \
                                                                                                                   \
          md == "pruneS"     ? "Q T min W min V min U min R min E min
                                O P min W min V min U min R min E min max
                                O P min Q min T min U min R min E min max
                                O P min Q min T min W min V min E min max
                                T W min V min U min R min O min E min max
                                P Q min V min U min R min O min E min max
                                P Q min W min T min R min O min E min max
                                P Q min W min T min U min V min E min max range_max swap - x *"                  : \
                                                                                                                   \
          md == "boundary"   ? "A B min C min D min E min F min G min H min I min range_max swap - x *"          : \
                                                                                                                   \
          md == "convexhull" ? "O R max U max E max
                                O P max Q max E max min
                                Q T max W max E max min
                                U V max W max E max min range_max x - * range_max swap -"                        : \
                                                                                                                   \
          md =="convexhull45"? "O R max U max P max E max I max
                                O P max Q max T max E max G max min
                                Q T max W max V max E max A max min
                                W V max U max R max E max C max min
                                P Q max T max W max E max G max min
                                U V max W max T max E max A max min
                                O R max U max V max E max C max min
                                O R max P max Q max E max I max min range_max x - * range_max swap -"            : \
                                                                                                                   \
          md == "junction"   ? "A C min E min H min
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
          md == "end"        ? "Q T min P min O min R min E min H min
                                Q T min W min V min P min E min D min max
                                U T min W min V min R min E min B min max
                                U P min O min V min R min E min F min max
                                O P min Q min U min R min E min I min max
                                O P min Q min W min T min E min G min max
                                Q T min W min V min U min E min A min max
                                O R min U min V min W min E min C min max"                                       : \
                                                                                                                   \
          md == "corner"     ? "V R min U min E min B min F min
                                T W min V min E min B min D min max
                                P Q min T min E min D min H min max
                                O P min R min E min F min H min max"                                             : \
                                                                                                                   \
          md == "cornerS"    ? "V R min U min B min F min
                                T W min V min B min D min max
                                P Q min T min D min H min max
                                O P min R min F min H min max" : ""

    str = ex_dlut(krn + str, bi, fs)

    rd < 1  ? a                                                                  : \
    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs="none") } }



# mt_edge() is 14% faster (varies with kernel)
# "canny" is a bit too complex so that's better used in a plugin
function ex_edge(clip a, string "mode", int "lo", int "hi", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode, "sobel")
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

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

    lo = ex_bs(Defined(lo) ? lo : th[0], 8, bi, fulls=fs)
    hi = ex_bs(Defined(hi) ? hi : th[1], 8, bi, fulls=fs)

    th  = (lo == 0) && (hi == ex_bs(255, 8, bi, fulls=fs)) ? "" : ex_dlut(Format("{lo} - range_max {hi} {lo} - / *"), bi, fs)
    str =                                                                                                                                                                                                \
          mode=="prewitt"   ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ "                                                                                   \
                             +"A B C + + D - E - F - A G D + + C - H - F - max F E D + + C - B - A - F H C + + D - G - A - max max "                                                                     \
                             +"G A B + + F - H - E - D G E + + C - H - B - max E H F + + B - A - G - B H C + + E - G - D - max max max "+th+""                                                         : \
                                                                                                                                                                                                         \
          mode=="hprewitt"  ? "x[1,1] A^ x[1,0] 2 * B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] 2 * E^ x[-1,-1] F^ x[0,1] 2 * G^ x[0,-1] 2 * H^ "                                                                   \
                             +"A B C + + D - E - F - A G D + + C - H - F - max F E D + + C - B - A - F H C + + D - G - A - max max "+th+""                                                             : \
                                                                                                                                                                                                         \
          mode=="sobel"     ? "x[1,0] A^ x[0,1] B^ x[-1,0] C^ x[0,-1] D^ A B + C - D - C D + A - B - max 1 2 / * "+th+""                                                                               : \
                                                                                                                                                                                                         \
          mode=="SG"        ? "x[-2,2] 2 * A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] 2 * E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                                   \
                             +"x[1,0] M^ x[2,0] N^ x[-2,-1] O^ x[-1,-1] P^ x[0,-1] Q^ x[1,-1] R^ x[2,-1] S^ x[-2,-2] 2 * T^ x[-1,-2] U^ x[0,-2] V^ x[1,-2] X^ x[2,-2] 2 * Y^ "                           \
                             +"F K O + + 2 * A T B G L P U + + + + + + + D - I - M - R - X - E - Y - J 2 * - N 2 * - S 2 * - "                                                                           \
                             +"B C D + + 2 * A E F G H I J + + + + + + + O - P - Q - R - S - T - Y - U 2 * - V 2 * - X 2 * - max "                                                                       \
                             +"J N S + + 2 * D I M R X E Y + + + + + + + A - T - B - G - L - P - U - F 2 * - K 2 * - O 2 * - "                                                                           \
                             +"U V X + + 2 * O P Q R S T Y + + + + + + + A - E - F - G - H - I - J - B 2 * - C 2 * - D 2 * - max max 1 5 / * "+th+""                                                   : \
                                                                                                                                                                                                         \
          mode=="scharr"    ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^  x[1,-1] H^ "                                                                                  \
                             +"C A - D 3.333333333 * - E 3.333333333 * + F - H + dup * F G 3.333333333 * H + + C - B 3.333333333 * - A - dup * + sqrt "+th+""                                          : \
                                                                                                                                                                                                         \
          mode=="frei-chen" ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                                                   \
                             +"C A - D 1.428571428 * - E 1.428571428 * + F - H + dup * F G 1.428571428 * H + + C - B 1.428571428 * - A - dup * + sqrt "+th+""                                          : \
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
                             +"A B + D - E - F 2 * + G + I - J 2 * - K 3 * + L 3 * + N 3 * - O 3 * - P 2 * Q U V + + + + S - T 2 * - X - Y - 0.5 * dup * "                                               \
                             +"U V 2 * W 3 * X 2 * Y P Q R 3 * S T + + + + + + + + + F - G - H 3 * - I - J - A - B 2 * - C 3 * - D 2 * - E - 0.5 * dup * + sqrt "+th+""                                : \
                                                                                                                                                                                                         \
          mode=="DoG"       ? "x[0,0] A^ x[0,1] B^ x[-1,0] C^ x[1,0] D^ x[0,-1] E^ x[0,2] F^ x[0,-2] G^ x[2,0] H^ x[-2,0] I^ x[-1,1] J^ x[-1,-1] K^ x[1,1] L^ x[1,-1] M^ "                               \
                             +"F G H I B 2 * E 2 * D 2 * C 2 * J K L M A 4 * + + + + + + + + + + + + 1 20 / * A 2 * B C D E + + + + 1 6 / * - 25 * "+th+""                                             : \
                                                                                                                                                                                                         \
          mode=="DoB"       ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ x[0,0] M^ "                                 \
                             +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] Q^ x[0,-1] R^ x[1,-1] S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] W^ x[1,-2] X^ x[2,-2] Y^ "                                   \
                             +"A B C D E F G H I J K L M N O P Q R S T U V W X Y + + + + + + + + + + + + + + + + + + + + + + + + 1 25 / * G H I L M N Q R S + + + + + + + + 1 9 / * - 25 * "+th+"" : \
                                                                                                                                                                                                         \
          mode=="LoG"       ? "x[0,2] x[0,-2] x[2,0] x[-2,0] x[0,1] 2 * x[0,-1] 2 * x[1,0] 2 * x[-1,0] 2 * x[-1,1] x[-1,-1] x[1,1] x[1,-1] + + + + + + + + + + + x[0,0] 16 * - "+th+""                 : \
                                                                                                                                                                                                         \
          mode=="laplace"   ? "x[-1,1] B@ x[0,1] C@ x[1,1] D@ x[-1,0] E@ x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ "                                                                                   \
                             +"+ + + + + + + x[0,0] 8 * A@ - A B - C - D - E - F - G - H - I - max 1 8 / * "+th+""                                                                                     : \
                                                                                                                                                                                                         \
          mode=="cartoon"   ? "x[1,-1] x[0,-1] 2 * - x[0,0] + "+th+""                                                                                                                                  : \
                                                                                                                                                                                                         \
          mode=="TEdge"     ? "x[-2,0] x[-1,0] 6.166666666 * - x[1,0] 6.166666666 * + x[2,0] - 2 * dup * x[0,-2] x[0,-1] 6.166666666 * - x[0,1] 6.166666666 * + x[0,2] - 2 * dup * + sqrt "+th+""      : \
                                                                                                                                                                                                         \
          mode=="min/max"   ? "x[1,1] A@ x[1,0] B@ max x[1,-1] C@ max x[-1,1] D@ max x[-1,0] E@ max x[-1,-1] F@ max x[0,1] G@ max x[0,-1] H@ max x[0,0] O@ max "                                         \
                             +"A B min C min G min O min H min D min E min F min - "+th+""                                                                                                             : \
                                                                                                                                                                                                         \
          mode=="max"       ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ x[0,0] O^ "                                                                         \
                             +"O A - abs O B - abs max O C - abs max O D - abs max O E - abs max O F - abs max O G - abs max O H - abs max "+th+""                                                     : \
                                                                                                                                                                                                         \
          mode=="kirsch"    ? "x[-1,1] A@ 1.666666 * R^ x[0,1] B@ 1.666666 * S^ x[1,1] C@ 1.666666 * T^ x[-1,0] D@ 1.666666 * U^ "                                                                       \
                             +"x[1,0] E@ 1.666666 * V^ x[-1,-1] F@ 1.666666 * X^ x[0,-1] G@ 1.666666 * Y^ x[1,-1] H@ 1.666666 * Z^ "                                                                     \
                             +"R S T + + D - E - F - G - H -     R S + C - U + E - F - G - H - max R B - C - U + E - X + G - H - max U A - B - C - E - X + Y + H - max "                                 \
                             +"X Y Z + + A - B - C - D - E - max V Y Z + + A - B - C - D - F - max T V Z + + A - B - D - F - G - max S T V + + A - D - F - G - H - max "+th+""                         : \
                                                                                                                                                                                                         \
          mode=="Std"       ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ A B C D E F G H + + + + + + + 1 8 / * J^ "                                          \
                             +"A J - dup * B J - dup * C J - dup * D J - dup * E J - dup * F J - dup * G J - dup * H J - dup * + + + + + + + 1 8 / * sqrt 8 * "+th+""                                  : \
                                                                                                                                                                                                         \
                             ex_dlut(mode, bi, fs)

    isy     ? Expr(a, str                                                               ) : \
    UV == 1 ? Expr(a, str, ""                                                           ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }







######### HELPER FUNCTIONS #########

function ex_UVexpr(string "str", int "UV", int "bits", bool "rgb", bool "fulls") {

    str = Default(str, "")
    UV  = Default(UV, 1)
    bi  = Default(bits, 8)
    rgb = Default(rgb,   false)
    fs  = Default(fulls, rgb)

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
          string(ex_bs(UV, 8, bi, fulls=fs)+bd)

    str = UV == 128 || UV == 255 ? ex_dlut(str, bi, fs) : str

    return str }


function ex_Yexpr(string "str", int "Y", int "bits", bool "rgb", bool "fulls") {

    str = Default(str, "")
    Y   = Default(Y, 3)
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


# Scales values from one bitdepth to another
function ex_bs(float var, int "ibits", int "obits", bool "ifulls", bool "fulls") {

    ibi = Default(ibits, 8)
    obi = Default(obits, 16)
    fs  = Default(ifulls,  false)
    fso = Default(fulls, fs)

    fs  = (ibi == 8 || ibi == 32) ? false : fs
    fso = (obi == 8 || obi == 32) ? false : fso

    v   = float(var)*pow(2, obi-ibi)

    fsc = fs && !fso ? -v/257. : \
         !fs &&  fso ?  v/256. : 0

    vif = ibi == 32 ? obi == 8 ? round(var*255.) :     var*ex_bs(255,8,obi,false,fso)     : nop()
    vof = obi == 32 ? ibi == 8 ? var/255.        : min(var/ex_bs(255,8,ibi,false,fso),1.) : nop()

    obi == 32 ? vof : ibi == 32 ? vif              : \
    obi == 8  ? ibi == 8 ? round(v) : round(v+fsc) : v+fsc }



# HBD constants 3D look up table
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


function mskY_to_YYY(clip a, clip msk, bool "luma", bool "rgb", int "UV", int "bits") {

    w  = width (a)
    h  = height(a)
    wm = width (msk)
    hm = height(msk)
    wh = wm!=w || hm!=h
    p_float = bits == 32
    bstr    = p_float ? "S" : string(bits)

    mskYs   =  isy(msk)               ? msk          : msk.ExtractY()
    mskYr   =  !wh                    ? mskYs        : mskYs.ConvertBits(8,dither=-1).BilinearResize(w, h).ConvertBits(bits)
    w       =  isYV411(a)             ? round(w/4.0) : round(w/2.0)
    h       =  isYV411(a) || is422(a) ?            h : round(h/2.0)
    mskC    = (is444  (a) || rgb)     ?                               mskYr : mskYs.ConvertBits(8,dither=-1).BilinearResize(      w+w%2,       h+h%2)
    mskC    = luma ? p_float ? Expr(mskC, "x range_half -").ConvertBits(32) : mskC.ConvertBits(bits) : BlankClip(a,length=1,width=w+w%2,height=h+h%2,pixel_type="Y"+bstr,color_yuv=$000000)
    msk     = CombinePlanes(mskYr, mskC, mskC, planes=rgb ? "RGB" : "YUV", pixel_type=PixelType(a))
    msk }