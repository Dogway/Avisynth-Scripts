###                                                            ##
###                                                            ##
###           MasksPack 5.2 By Dogway  (31-01-2022)            ##
###                    Masks + Limiters                        ##
###                                                            ##
###      https://forum.doom9.org/showthread.php?t=182881       ##
###                                                            ##
#################################################################


##################
###
### BoxMask
###
###
### Creates a rectangular mask so you can use it in merging operations or custom filtering in localized areas.
###
### Dependencies:
###         ExTools
###         ResizersPack
###         GradePack (for show=true)
###
### Function Definition:
###    (
###    clip,
###    int x1=0 (0 to 1920 by 1),
###    int x2=0 (0 to 1920 by 1),
###    int y1=0 (0 to 1080 by 1),
###    int y2=0 (0 to 1080 by 1),
###    bool "invert"=false,
###    bool "show"=false,
###    bool "tv_out"=false,
###    bool "UV"=3 (1 to 128 by 1),
###    )
###
###########################

function BoxMask(clip clp, int "x1", int "x2", int "y1", int "y2", int "UV", bool "invert", bool "show", bool "tv_out") {

    clp
    rgb     = isRGB()
    w       = width ()
    h       = height()

    x1      = Default(x1,0)
    x2      = Default(x2,0)
    y1      = Default(y1,0)
    y2      = Default(y2,0)
    in      = Default(invert, false)
    tv      = Default(tv_out, false)
    show    = Default(show,   false)
    UV      = Default(UV,3)

           Assert(IsVersionOrGreater(3,7,1), "BoxMask: Update AviSynth+ version")
    show ? Assert(UV!=1,                     "BoxMask: 'show' requires UV=2 or 3") : nop()

    x1      =     min(max(x1,0),w)
    x2      = max(min(max(x2,0),w),x1)
    y1      =     min(max(y1,0),h)
    y2      = max(min(max(y2,0),h),y1)

    UV = UV!=3 && !rgb ? 128 : UV

    wh = !in ? tv ? "ymax" : "range_max" : tv ? "ymin" : "0"
    bl =  in ? tv ? "ymax" : "range_max" : tv ? "ymin" : "0"
    x  = is422() || is420() ? 2. : isYV411() ? 4. : 1
    y  = is420()            ? 2. :                  1

    x1c = nmod(x1/x,int(x))  x2c = nmod(x2/x,int(x))
    y1c = nmod(y1/y,int(y))  y2c = nmod(y2/y,int(y))

    Luma = Format("x {x1}  >= x {x2}  <= & y {y1}  >= y {y2}  <= & & "+wh+" "+bl+" ?")
    Chrm = Format("x {x1c} >= x {x2c} <= & y {y1c} >= y {y2c} <= & & "+wh+" "+bl+" ?")

    ex_lutspa(mode="absolute", expr=Luma, cexpr=Chrm, UV=UV, fulld=!tv)

    !show ? last : ex_blend(clp,last,"softlight",0.5,tv_range=tv) }



##################
###
### FlatMask() (23-12-2021)
###
###
### This is a dual purpose filter for 2D cartoons to create either high quality edge/ridge masks or flat masks.
### One is the opposite of the other so you only have to tune the radius and scale settings to define
### to what extent the edge mask is applied.
### If 'filt' clip argument is not defined by default the output is the edge mask.
###
### Dependencies:
###     ExTools
###     ResizersPack
###     vsTCanny
###     SMDegrain (for ex_retinex)
###         GradePack
###
### Example:
###     filt = YourFilter()
###     flatmask(1,filt=filt) # to merge with filtered clip
###
###
### Function Definition:
###    (
###    clip,
###    float rad=3.0 (1.0 to 4.0 by 0.5),
###    float "scale"=5.0 (1.0 to 10.0 by 0.5),
###    int "lo"=4 (0 to 32 by 1),
###    int "MSR"=40 (0 to 128 by 1),
###    bool "invert"=false,
###    bool "show"=false,
###    )
###
###########################

function FlatMask(clip a, float "rad", float "scale", int "lo", int "MSR", clip "filt", bool "invert", bool "show") {

    a
    rgb   = isRGB()
    w     = width ()
    h     = height()
    bi    = BitsPerComponent()
    fs    = propNumElements("_ColorRange")  > 0 ? \
            propGetInt     ("_ColorRange") == 0 : rgb

    isHD  = (w > 1099 || h >  599)
    isUHD = (w > 2599 || h > 1499)

    rd    = Default(rad, isHD?3:1)   # 1 or 2 for SD, 3 for HD and >=4 for 1080p or higher. 0 is a plain edge mask (ex_edge("qprewitt") )
    scl   = Default(scale,      5)   # Scale of the mask. Increase to convert edge mask to a flat mask
    lo    = Default(lo,         4)   # Clip pixels under this value
    lvl   = Default(MSR,       40)   # Low level for ex_retinex normalization
    sh    = Default(show,   false)   # True to show mask in split view
    in    = Default(invert, false)
    fil   = Defined(filt)

    !isy() ? ExtractY() : last
    ConvertBits(8,dither=-1,fulls=fs)
    # 3x3 is too broad for SD so upscale
    !isHD  ? BlackmanResize(w*2,h*2)                         : last
    # UHD size is too big for good performance
     isUHD ? BicubicResize(nmod(w/2,2),nmod(h/2,2),-0.6,0.4) : last

    ex_retinex(lvl=1,lo=lvl,tv_range=!fs)  # some issues here on flat areas (quantization)
    MSR=ex_median("IQM")                   # pre for full 'qprewitt'

    # Prefilter (scale space)
    vsTCanny(sqrt(rd)/2.*sqrt(2),mode=-1,u=2,v=2)

    # Pseudo Ridge Filter
    xx1=    ex_lut(Format("x[-1,-1] x[1,1]  -"))
    xx1=xx1.ex_lut(Format("x[-1,-1] x[1,1]  -"))
    yy1=    ex_lut(Format("x[-1,1]  x[1,-1] -"))
    yy1=yy1.ex_lut(Format("x[-1,1]  x[1,-1] -"))

    xx2=    ex_lut(Format("x[-1,-1] x[1,1]  swap -"))
    xx2=xx2.ex_lut(Format("x[-1,-1] x[1,1]  swap -"))
    yy2=    ex_lut(Format("x[-1,1]  x[1,-1] swap -"))
    yy2=yy2.ex_lutxyza(xx1,yy1,xx2,            \
                   Format("x[-1,1]  x[1,-1] swap - 0 max dup * y dup * z dup * a dup * + + + sqrt {scl} * dup {lo} {scl} * > swap 0 ?"+(in && rd==1 ? " range_max swap -" : "")))

    # Pre for 'Fill holes'
    ex_contrast(scl>9?yy2.ex_median("median"):yy2,1,pivot=80,tv_range=false)
    # Fill holes
    ex_expand(1, mode="disk")
    ex_inpand(1, mode="disk")
    # Expand
    rd > 2                             ? \
    ex_expand(round(rd-2),mode="disk") : last
    # Merge with basic qprewitt for robustness and faint lines
    ex_lutxy(MSR,last,Format("x[-1,-1] A@ x[-1,0] x[-1,1] F@ + + x[1,-1] C@ - x[1,0] - x[1,1] H@ - dup *
                              A C x[0,-1] + + F - H - x[0,1] - dup * + sqrt {lo} 2.5 * - {rd} 3 / 1 + * y max" ))
    # Close gaps
    ex_luts(mode="avg", pixels=ex_shape(ceil(rd/2.), mode="ring"), exprf="dup dup x > swap 128 > & swap 1.15 * x ?"+(in ? " range_max swap -" : ""))

    rd  = round(rd)
    rd == 1 ? yy2                               : \
    rd == 0 ? ex_edge(MSR,"qprewitt",invert=in) : last                           # Maybe add back qprewitt on top for rd==1 ?

    !isHD   ? BicubicResize(w,h,-0.5,0.25) : ex_smooth(2, mode="SG", sharp=true) # Clean up result. No need when resizing down
     isUHD  ? BicubicResize(w,h,1/3.,1/3.) : last

    msk8 = last

    ConvertBits(bi,fulls=true)

    if (fil) {
        # Merge with filtered through the edge mask
        ex_merge(filt,a,last,luma=true)
        # Artifact Repair (useful with big radius filters)
        ex_luts(a,last,mode="clamp",pixels=ex_shape(min(rd+1,3),mode="disk")) }

    if (sh) {
        src = fil ? last : a
        msk = mskY_to_YYY(src, msk8, false, false, 128, bi)
        StackHorizontal(padresize(src,w/2,h,biasW=w/4),padresize(msk,w/2,h,biasW=-w/4)) } }




#####################################################################
###                                                                 #
### LumaMask() (22-12-2021)                                         #
###                                                                 #
### Two point remap of luma plane range for using as mask.
### Basically a lerp (linear interpolation) between 'b' (black point)
### and 'w' (white point), with option to invert the mask.
###
### UV=3 is noop, you can use UV=2 to copy chroma, or UV=128 for grey chroma.
###
###   LumaMask(50, 100)
###
### Remaps value 0 to 50 and 255 to 100, clipping above and below.
### Useful to protect dark/bright areas from certain filters without
### a hard threshold like ex_binarize()
###
###
### Function Definition:
###    (
###    clip,
###    int "lo"=24 (0 to 255 by 1),
###    int "hi"=48 (0 to 255 by 1),
###    bool "invert"=false,
###    )
###
##############################################################

function LumaMask(clip a, int "lo", int "hi", bool "invert", int "UV") {

    rgb    = isRGB(a)
    isy    = isy(a)
    bi     = BitsPerComponent(a)
    fs     = propNumElements (a,"_ColorRange")  > 0 ? \
             propGetInt      (a,"_ColorRange") == 0 : rgb
    lut    = bi == 32 ? 0 : 1

    LO     = Default(lo, 24)
    HI     = Default(hi, 48)
    inv    = Default(invert, false)
    UV     = Default(UV,  !isy ? 128 : 2)

    Assert(IsVersionOrGreater(3,7,1), "LumaMask: Update AviSynth+ version")

    bi32   = bi == 32 ? "0 1 clip" : ""
    LO     = ex_bs(LO, 8, bi, fulls=fs)
    HI     = ex_bs(HI, 8, bi, fulls=fs)

    code   = inv ? Format("range_max range_max {HI} {LO} - / x {LO} - * - "+bi32) : \
                   Format("0         range_max {LO} {HI} - / x {LO} - * - "+bi32)

    str    = ex_dlut(code, bi, true)
    cstr   = ex_UVexpr("", max(7,UV), bi, rgb, true)

    isy     ?  Expr(a, str,       lut=lut) : \
    UV == 1 ?  Expr(a, str, "",   lut=lut) : \
               Expr(a, str, cstr, lut=lut)
               PropSet("_ColorRange", 0)   }




### ex_limitdif() by Dogway (30-01-2022)
### Ported from slimit_dif() and HQDeringmod_limit_dif(). Description from Dither_limit_dif16
###
### Compare a filtered clip with its original version, and keeps the filtered pixels only if the difference between the filtered pixel and the reference pixel is below the given threshold.
### This is a building block of SmoothGrad, GradFun3, nnedi3_resize16() and deep_resize().
###
### flt:   Filtered clip.
### src:   Original clip.
### ref:   Reference clip for the filter output comparison. Specify here the first original clip when you cascade several limited filters. When undefined, the src clip is taken as reference.
### thr:   Thershold between reference data and filtered data, on an 8-bit scale. > 0.
### elast: To avoid artifacts, the threshold has some kind of elasticity. Value differences falling over this thershold are gradually attenuated, up to thr * elast. > 1.
###
function ex_limitdif(clip flt, clip src, clip "ref", float "thr", float "elast", float "brighten_thr", float "thrc", int "Y", int "UV", bool "smooth") {

    rgb = flt.isRGB()
    w   = flt.width()
    h   = flt.height()
    bi  = BitsPerComponent(flt)
    fs  = propNumElements (flt,"_ColorRange")  > 0 ? \
          propGetInt      (flt,"_ColorRange") == 0 : rgb

    dref   = Defined(ref)
    thr    = Default(thr,                 0.25)
    thrc   = Default(thrc,                 thr)  # 0-255 (normally up to 10)
    sm     = Default(smooth,              true)
    elast  = Default(elast, sm ? 3.0 : 255./thr) # 1-255 (normally up to 10)
    elast  = max(elast, 1.0)
    bthr   = Default(brighten_thr,         thr)  # 0-255 (normally up to 10)
    Y      = Default( Y,       3 )
    UV     = Default( UV,      3 )

    sm     = elast==1.0 ? False : sm

    celast = ex_bs(elast*thrc, 8, bi, true, flt=true)
    thr    = ex_bs(thr,        8, bi, true, flt=true)
    thrc   = ex_bs(thrc,       8, bi, true, flt=true)
    bthr   = ex_bs(bthr,       8, bi, true, flt=true)

    Assert(IsVersionOrGreater(3,7,1), "ex_limitdif: Update AviSynth+ version")

    # from HQDeringmod_limit_dif()
    # diff   = filtered - original
    # alpha  = 1 / (thr * (elast - 1))
    # beta   = elast * thr
    #
    # When smooth=True  :
    # output = diff <= thr  ? filtered : \
    #          diff >= beta ? original : \
    #                         original + alpha * diff * (beta - abs(diff))
    # When smooth=False :
    # output = diff <= thr  ? filtered : \
    #          diff >= beta ? original : \
    #                         original + thr * (diff / abs(diff))

    dref ? ex_lutxyz(flt,src,ref, Format("x z - abs D1@ x y - D2@ 0 > {bthr} {thr} ? D2T@ <= x D1 D2T {elast} * D3T@ >= y dup D2 D3T D1 - * D3T D2T - / + ? ?"), \
                                  Format("x z - abs D@ {thrc} <= x D {celast} >= y dup x y - {celast} D - * {celast} {thrc} - / + ? ?"),Y=Y,UV=UV) : \
           ex_lutxy (flt,src,     Format("x y - D1@ dup abs DA@ swap 0 > {bthr} {thr} ? D2T@  <= x DA D2T {elast} * D3T@ >= y dup D1 D3T DA - * D3T D2T - / + ? ?"), \
                                  Format("x y - D1@ abs DA@ {thrc} <= x DA {celast} >= y dup D1 {celast} DA - * {celast} {thrc} - / + ? ?"),Y=Y,UV=UV) }




# Didée's SPresso() internal limiter as a standalone function
# Not to confuse with Kassandro's LimitChange (either the StainlessS update or real.finder's HBD mod)
function ex_limitchange(clip flt, clip src, float "limit", float "bias", float "limitC", float "biasC", int "Y", int "UV") {

    rgb = flt.isRGB()
    w   = flt.width()
    h   = flt.height()
    bi  = BitsPerComponent(flt)
    fs  = propNumElements (flt,"_ColorRange")  > 0 ? \
          propGetInt      (flt,"_ColorRange") == 0 : rgb

    limit   = Default( limit,   2 )
    limitC  = Default( limitC,  rgb?limit:limit*2 )
    bias    = Default( bias,   25 )
    biasC   = Default( biasC,   rgb?bias : bias*2 )
    Y       = Default( Y,       3 )
    UV      = Default( UV,      rgb?3:2 )

    Assert(IsVersionOrGreater(3,7,1), "ex_limitchange: Update AviSynth+ version")

    LIM1  = ex_bs(limit >0 ? round(limit *(100.0/bias) -1.0) : round(100.0/bias),  8, bi, fulls=fs)
    LIM1c = ex_bs(limitC>0 ? round(limitC*(100.0/biasC)-1.0) : round(100.0/biasC), 8, bi, fulls=fs)
    LIM2  = ex_bs(limit <0 ? 1 : limit,  8, bi, fulls=fs)
    LIM2c = ex_bs(limitC<0 ? 1 : limitC, 8, bi, fulls=fs)
    BIA   = ex_bs(bias,                  8, bi, fulls=fs)
    BIAc  = ex_bs(biasc,                 8, bi, fulls=fs)
    CTH   = ex_bs(100,                   8, bi, fulls=fs)
    un    = ex_bs(1,                     8, bi, fulls=fs)

    expr  = Format(limit<0 ? "y x - A@ abs {LIM1} < y dup A sgn {un} * - ?"                                                          : \
                             "y x - abs 0 <= y dup {LIM1}  + x < y {LIM2}  + y {LIM1}  - x > y {LIM2}  - y {CTH} {BIA}  - * x {BIA}  * + 1 {CTH} / * ? ? ?" )

    exprC = Format(limit<0 ? "y x - A@ abs {LIM1c} < y dup A sgn {un} * - ?"                                                         : \
                             "y x - abs 0 <= y dup {LIM1c} + x < y {LIM2c} + y {LIM1c} - x > y {LIM2c} - y {CTH} {BIAc} - * y {BIAc} * + 1 {CTH} / * ? ? ?" )


    ex_lutxy( flt, src, expr, exprC, Y=y, UV=uv, fulls=fs) }