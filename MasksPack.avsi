###                                                            ##
###                                                            ##
###           MasksPack 6.7 by Dogway  (12-07-2023)            ##
###                    Masks + Limiters                        ##
###                                                            ##
###      https://forum.doom9.org/showthread.php?t=182881       ##
###                                                            ##
###                                                            ##
### Functions:                                                 ##
###      BoxMask                                               ##
###      FlatMask                                              ##
###      LumaMask                                              ##
###      CornerMask                                            ##
###      MotionMask                                            ##
###      ex_limitdif                                           ##
###      ex_limitchange                                        ##
###      Soothe                                                ##
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
###    int x1=0 (0 to 1920),
###    int x2=100 (0 to 1920),
###    int y1=0 (0 to 1080),
###    int y2=100 (0 to 1080),
###    [bool "invert"=false],
###    [bool "show"=false],
###    [bool "tv_out"=false],
###    [int "UV"=3 (1 to 128)]
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

           Assert(IsVersionOrGreater(3,7,2), "BoxMask: Update AviSynth+ version")
    show ? Assert(UV!=1,                     "BoxMask: 'show' requires UV=2 or 3") : nop()

    x1      =     clamp(x1,0,w)
    x2      = max(clamp(x2,0,w),x1)
    y1      =     clamp(y1,0,h)
    y2      = max(clamp(y2,0,h),y1)

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

    prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
    propCopy(clp, props=UV<4?prop:ArrayAdd(prop,"_ChromaLocation"), exclude=true)
    propSet("_ColorRange", tv?1:0)

    !show ? last : ex_blend(clp,last,"softlight",0.5,tv_range=tv) }



##################
###
### FlatMask() (28-06-2022)
###
###
### This is a dual purpose filter for 2D cartoons to create either flat masks or high-quality single line (Ridge Filter) edge masks.
### One is the opposite of the other so you only have to tune the radius and scale settings to define
### to what extent the edge mask is applied.
### If 'filt' clip argument is not defined by default the output is the edge mask.
###
### Dependencies:
###     ExTools
###     ResizersPack
###     GradePack
###     vsTCanny
###     SMDegrain (for ex_retinex)
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
###    [float "scale"=5.0 (1.0 to 10.0 by 0.5)],
###    [int "lo"=4 (0 to 32)],
###    [int "MSR"=40 (0 to 128)],
###    [bool "invert"=false],
###    [bool "show"=false]
###    )
###
###########################

function FlatMask(clip a, float "rad", float "scale", int "lo", int "MSR", clip "filt", bool "invert", bool "show") {

    a
    rgb   = isRGB()
    isy   = isy()
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

    Assert(IsVersionOrGreater(3,7,2), "FlatMask: Update AviSynth+ version")

    !isy ? ExtractY() : last
    ConvertBits(8,dither=-1,fulls=fs)
    # 3x3 is too broad for SD so upscale
    !isHD  ? BlackmanResize(w*2,h*2,taps=6)                : last
    # UHD size is too big for good performance
     isUHD ? BicubicResize(nmod(w/2),nmod(h/2),-0.99,0.06) : last

    ex_retinex(lvl=1,lo=lvl,tv_in=!fs,tv_out=false) # some issues here on flat areas (quantization) (Apply SmoothGrad?)
    MSR=ex_median("IQM")                            # pre for full 'qprewitt'

    # Prefilter (scale space)
    vsTCanny(sqrt(rd)/2.*sqrt(2),mode=-1,u=2,v=2)

    # Second Derivatives Edge Mask
    xx1=    ex_lut(Format("x[-1,-1] x[1,1]   -"))
    yy1=    ex_lut(Format("x[-1,1]  x[1,-1]  -"))
    xx2=    ex_lut(Format("x[1,1]   x[-1,-1] -"))
    yy2=    ex_lut(Format("x[1,-1]  x[-1,1]  -"))
    yy2=yy2.ex_lutxyza(xx1,yy1,xx2,            \
                   Format("y[-1,-1] y[1,1] - 0 max dup *   z[-1,1] z[1,-1] - 0 max dup * +
                           a[1,1] a[-1,-1] - 0 max dup * + x[1,-1] x[-1,1] - 0 max dup * +
                           sqrt {scl} * dup {lo} {scl} * > swap 0 ?"+(in && rd==1 ? " range_max swap -" : "")))

    # Pre for 'Fill holes'
    ex_contrast(scl>9?yy2.ex_median("median"):yy2,1,pivot=80,tv_range=false)
    # Fill holes
    ex_expand(1, mode="disk") # Basically a 'plus'
    ex_inpand(1, mode="disk")
    # Expand
    rd > 2                             ? \
    ex_expand(round(rd-2),mode="disk") : last
    # Merge 'last' with basic qprewitt (over 'MSR') for robustness and faint lines
    ex_lutxy(MSR,last,Format("x[-1,-1] A@ x[-1,0] x[-1,1] F@ + + x[1,-1] C@ - x[1,0] - x[1,1] H@ - dup *
                              A C x[0,-1] + + F - H - x[0,1] - dup * + sqrt {lo} 2.5 * - {rd} 3 / 1 + * y max" ))
    # Close gaps
    ex_luts(mode="avg", pixels=ex_shape(ceil(rd/2.), mode="ring"), exprf="dup dup x > swap 128 > & swap 1.15 * x ?"+(in ? " range_max swap -" : ""))

    rd  = round(rd)
    rd == 1 ? yy2                                  : \
    rd == 0 ? ex_edge(MSR,"qprewitt",invert=in)    : last                              # Maybe add back qprewitt on top for rd==1 ?

    !isHD   ? BicubicResize(w,h,0.0,0.5)           : ex_smooth(2,mode="SG",sharp=true) # Clean up result. No need when resizing down
     isUHD  ? BicubicResize(w,h,0.679623,0.160189) : last

    ConvertBits(bi,fulls=true)
    msk8 = last

    propDelete(["_Matrix","_Primaries","_Transfer","_PictType","_ChromaLocation"])

    if (fil) {
        # Merge with filtered through the edge mask
        ex_merge(filt,a,last,luma=true)
        # Artifact Repair (useful with big radius filters)
        ex_luts(a,last,mode="clamp",pixels=ex_shape(min(rd+1,3),mode="disk")) }

    if (sh) {
        src = fil ? last : a
        msk = isy ? msk8 : mskY_to_YYY(src, msk8, false, false, 128, bi)
        StackHorizontal(padresize(src,w/2,h,biasW=w/4),padresize(msk,w/2,h,biasW=-w/4)) } }




#####################################################################
###                                                                 #
### LumaMask() (05-03-2022)                                         #
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
### a hard threshold like ex_binarize(75)
###
###
### Function Definition:
###    (
###    clip,
###    int "lo"=24 (0 to 255),
###    int "hi"=48 (0 to 255),
###    [bool "invert"=false]
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
    UV     = Default(UV,  !isy ? 128 : 2) # Use 3 to copy luma mask to chroma planes
    UV2    = UV == 3 ? 1 : UV

    Assert(IsVersionOrGreater(3,7,2), "LumaMask: Update AviSynth+ version")

    bi32   = bi == 32 ? "0 1 clip" : ""
    LO     = ex_bs(LO,  8, bi, fulls=true)
    HI     = ex_bs(HI,  8, bi, fulls=true)
    MX     = ex_bs(255, 8, bi, fulls=true, flt=true)
    LIM    = MX / (inv ? HI - LO : LO - HI)

    code   = inv ? Format("range_max x {LO} - {LIM} * -   "+bi32) : \
                   Format("          x {LO} - {LIM} * neg "+bi32)

    str    = ex_dlut(code, bi, true)
    cstr   = ex_UVexpr("", UV2, bi, rgb, true)

    isy      ? Expr(a, str,       lut=lut) : \
    UV2 == 1 ? Expr(a, str, "",   lut=lut) : \
               Expr(a, str, cstr, lut=lut)

    UV  == 3 ? mskY_to_YYY(a, last, true, rgb, UV, bi) : last

               prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
               propDelete(UV2<4?prop:ArrayAdd(prop,"_ChromaLocation"))
               propSet("_ColorRange", 0)  }


# CornerMask()
# Pseudo-Harris corner detection
#
# Dependencies: vsTCanny
#               GradePack (for show=true)
#
#
# Function Definition:
#    (
#    clip,
#    float "th"=0.2 (0.1 to 0.9),
#    float "sigma"=1.0 (0.5 to 3.0),
#    [bool "show"=false]
#    )
#
function CornerMask(clip a, float "th", float "sigma", bool "show") {

    w    = width (a)
    h    = height(a)
    isHD = (w > 1099 || h > 599)

    th   = Default(th,    0.2) # From 0.2 to 0.5 for sigma=1
    rd   = Default(sigma, 1.0)
    sh   = Default(show,  false)
    th   = th / 100

    # Prefiltering
    vsTCanny(a,rd,mode=-1,y=3,u=1,v=1)

    # First derivatives
    x1 = ex_edge("x[0,-1] x[0,1] -")
    y1 = ex_edge("x[-1,0] x[1,0] -")
    x2 = ex_edge("x[0,-1] x[0,1] swap -")
    y2 = ex_edge("x[-1,0] x[1,0] swap -")

    # Second derivatives + Minor|Major Eigenvalues (from Covariance Matrix) + R
    ex_lutxyza(x1,x2,y1,y2,Format( \
               "f32 x[0,-1] x[0,1] - y[0,1] y[0,-1] - + X@
                    z[-1,0] z[1,0] - a[1,0] a[-1,0] - + Y@
                dup1 dup1 + S@ swap2 - 0.5 * dup * X dup * Y dup * + G@ + sqrt + 0.5 *
                X Y * G - S /
                dup1 dup1 * swap2 + dup * 0.05 * - {th} > range_max 0 ?"), scale_inputs="intf") # (major Eigenvalue = Ridge Filter)

    # Corner augment
    ex_expand(round(w/480.), mode="disk")
    # Temporal Stabilization
    or = last
    ex_median("medianT5")
    # Fix for Motion
    mm = MotionMask(a,lo=30,hi=255,dir=20,scale=2,edgebased=false) # for anime, dir=20 (radius 2) is a must
    ex_merge(or,mm,UV=1)
    # Smooth PP
    ex_deflate(UV=128)

    # Show
    sh ? ex_blend(a,last, "linearadd", 0.4, 1.0) : last }



# Motion (occlusion) mask with selective direction; previous, next, or both (default) with radius of 1 or 2.
# Own algorithm. Requires ExTools and ResizersPack.
#
# Similar to MVTools' MMask() but much faster.
#
# Function Definition:
#    (
#    clip,
#    int "lo"=24 (0 to 255),
#    int "hi"=48 (0 to 255),
#    int "dir"=20 (-2 / -1 / 0 / 1 / 2 / 20),
#    [float "scale"=2.0 (1.0 to 10.0)],
#    [int "sharpness"=0 (0 to 10)]
#    )
#
function MotionMask(clip a, int "lo", int "hi", float "scale", int "sharpness", int "dir", bool "edgebased", int "UV", bool "show") {

    rgb  = isRGB(a)
    isy  = isy(a)
    w    = width(a)
    h    = height(a)
    bi   = BitsPerComponent(a)

    eb   = Default(edgebased,  true) # True by default, delivers better motion vectors for live action. Disable for 2D animation.
    lo   = Default(lo,           30)
    hi   = Default(hi,          255)
    sh   = Default(sharpness,     0)
    sc   = Default(scale,eb ? 1 : 2)
    dr   = Default(dir,          20) # Direction of the motion mask, -2 for previous+before, -1 for previous, 0 for both, 1 for next, 2 for next+following, 20 for both radius=2
    UV   = Default(UV,  rgb ? 3 : 2)
    show = Default(show,      false) # Enable to visually adjust settings, motion mask will show as green "smoke"

    dr   = dr>2?20:dr
    sc   = max(1,sc)
    ad   = abs(dr)
    sc   = sc / (ad==1 ? 2. : ad==20 ? 5. : 4.)
    lob  =     ex_bs(lo, 8, bi, fulls=true)
    hib  = max(ex_bs(hi, 8, bi, fulls=true) / sc, lob)
    th   = (lo == 0) && (hi == 255) ? sc == 2 ? ""    : Format(" {sc} *") : \
           (lo == 0) ? Format(" range_max {hib} / *") : Format(" {lob} - range_max {hib} {lob} - / *")

    UV = UV!=3 ? 1 : UV
    UV==3 || isy ? a : a.ExtractY()

    ex_Luma_Rebuild(5.0, 0.03)
    eb ? ex_edge("kroon") : last

    # 20x20 macroblocks (at 1080p)
    RatioResize(96,"adjust2w",kernel="bicubic",b=-0.6,c=0.4)
    # Temporal Stabilization
    ex_FluxSmoothT(2,5,UV=uv)
    # Directional Derivative
    ad==1 ? ex_lutxy (selectevery(1,dr),                         "x y - abs               dup * "+th, UV=uv) : \
    ad==2 ? ex_lutxyz(selectevery(1,dr),selectevery(1,sign(dr)), "x y - abs x z - abs max dup * "+th, UV=uv) : \
    ad==0 ? ex_lutxyz(selectevery(1,-1),selectevery(1,       1), "x y - abs x z - abs max dup * "+th, UV=uv) : \
            Expr(last,selectevery(1,-1),selectevery(1,       1),                                               \
                      selectevery(1,-2),selectevery(1,       2), "x a - abs x b - abs max x y - abs max x z - abs max dup * "+th)
    # Mask Dilate
    ex_expand(1, "plus", UV=uv)
    # Blur
    GaussResize(w,h,p=round(w/213.33)+sh)
    propDelete(["_Matrix","_Primaries","_Transfer","_PictType"])
    propSet("_ColorRange", 0)

    msk = isy ? mskY_to_YYY(a, rgb=false, bits=bi, Jab="444") : a
    show ? ex_merge(a,Expr(msk,"range_half",ex_dlut("50",bi,true),ex_dlut("120",bi,true)),last,luma=true) : last
 }




### ex_limitdif() by Dogway (03-02-2022)
### Ported from slimit_dif() and HQDeringmod_limit_dif(). Description from Dither_limit_dif16
###
### Compare a filtered clip with its original version, and keeps the filtered pixels only if the difference between the filtered pixel and the reference pixel is below the given threshold.
### This is a building block of SmoothGrad, GradFun3plus and deep_resize().
###
### flt:   Filtered clip.
### src:   Original clip.
### ref:   Reference clip for the filter output comparison. Specify here the first original clip when you cascade several limited filters. When undefined, the src clip is taken as reference.
### thr:   Thershold between reference data and filtered data, on an 8-bit scale. > 0.
### elast: To avoid artifacts, the threshold has some kind of elasticity. Value differences falling over this thershold are gradually attenuated, up to thr * elast. > 1.
### brighten_thr: Threshold for filtering diff that brightens the image. Setting a value different from "thr" is useful to limit the overshoot/undershoot/blurring introduced in sharpening/de-ringing
###
function ex_limitdif(clip flt, clip src, clip "ref", float "thr", float "elast", float "brighten_thr", float "thrc", int "Y", int "UV", bool "smooth") {

    rgb = flt.isRGB()
    w   = flt.width()
    h   = flt.height()
    bi  = BitsPerComponent(flt)
    fs  = propNumElements (flt,"_ColorRange")  > 0 ? \
          propGetInt      (flt,"_ColorRange") == 0 : rgb

    dref   = Defined(ref)
    thr    = Default(thr,                  0.25)
    thrc   = Default(thrc,                  thr)  # 0-255 (normally up to 10)
    sm     = Default(smooth,               true)
    elast  = Default(elast, sm ? 3.0 : 255./thr)  # 1-255 (normally up to 10)
    elast  = max(elast, 1.001)
    bthr   = Default(brighten_thr,          thr)  # 0-255 (normally up to 10)
    Y      = Default( Y,       3 )
    UV     = Default( UV,      3 )

    sm     = elast == 1.0 ? false : sm

    thrc   = ex_bs(  thrc, 8, bi, true, flt=true)
    celast = elast * thrc
    thr    = ex_bs(  thr,  8, bi, true, flt=true)
    telast = elast * thr
    bthr   = ex_bs( bthr,  8, bi, true, flt=true)
    thelas = 1. / (telast - thr)
    thcela = 1. / (celast - thrc)

    Assert(IsVersionOrGreater(3,7,2), "ex_limitdif: Update AviSynth+ version")

    # LOGIC (from HQDeringmod_limit_dif()):
    #
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

    exprYref = bthr != thr ? Format("x z - abs DA@ x y - D2@    0 > {bthr} {thr} ? THR@ <= x DA THR {elast} * THRE@ >= y dup D2 THRE DA - * THRE THR - / + ? ?") : \
                             Format("x z - abs DA@     {thr} <= x DA {telast} >= y dup x y - {telast} DA - * {thelas} * + ? ?")
    exprY    = bthr != thr ? Format("x y - D1@ dup abs DA@ swap 0 > {bthr} {thr} ? THR@ <= x DA THR {elast} * THRE@ >= y dup D1 THRE DA - * THRE THR - / + ? ?") : \
                             Format("x y - D1@ abs DA@ {thr} <= x DA {telast} >= y dup D1    {telast} DA - * {thelas} * + ? ?")

    dref ? ex_lutxyz(flt,src,ref, exprYref, Format("x z -     abs D@  {thrc} <= x D  {celast} >= y dup x y - {celast} D  - * {thcela} * + ? ?"), Y=Y,UV=UV) : \
           ex_lutxy (flt,src,     exprY,    Format("x y - D1@ abs DA@ {thrc} <= x DA {celast} >= y dup D1    {celast} DA - * {thcela} * + ? ?"), Y=Y,UV=UV) }



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

    Assert(IsVersionOrGreater(3,7,2), "ex_limitchange: Update AviSynth+ version")

    LIM1  = ex_bs(limit >0 ? round(limit *(100.0/bias) -1.0) : round(100.0/bias),  8, bi, fulls=fs)
    LIM1c = ex_bs(limitC>0 ? round(limitC*(100.0/biasC)-1.0) : round(100.0/biasC), 8, bi, fulls=fs)
    LIM2  = ex_bs(limit <0 ? 1 : limit,  8, bi, fulls=fs, flt=true)
    LIM2c = ex_bs(limitC<0 ? 1 : limitC, 8, bi, fulls=fs, flt=true)
    BIA   = ex_bs(bias,                  8, bi, fulls=fs, flt=true)
    BIAc  = ex_bs(biasc,                 8, bi, fulls=fs, flt=true)
    CTH   = ex_bs(100,                   8, bi, fulls=fs)
    un    = ex_bs(1,                     8, bi, fulls=fs)

    expr  = Format(limit<0 ? "y x - A@ abs {LIM1} < y dup A sgn {un} * - ?"                                                          : \
                             "y x - abs 0 <= y dup {LIM1}  + x < y {LIM2}  + y {LIM1}  - x > y {LIM2}  - y {CTH} {BIA}  - * x {BIA}  * + 1 {CTH} / * ? ? ?" )

    exprC = Format(limit<0 ? "y x - A@ abs {LIM1c} < y dup A sgn {un} * - ?"                                                         : \
                             "y x - abs 0 <= y dup {LIM1c} + x < y {LIM2c} + y {LIM1c} - x > y {LIM2c} - y {CTH} {BIAc} - * y {BIAc} * + 1 {CTH} / * ? ? ?" )


    ex_lutxy( flt, src, expr, exprC, Y=y, UV=uv, fulls=fs) }




### Soothe()   by Didée (6th Sept 2005)
### Small helper function to temporal stabilize sharpening for less temporal jitter
### https://forum.doom9.org/showthread.php?t=99679
###
### MCSoothe() by Didée (14th July 2007)
### https://forum.doom9.org/showthread.php?p=1367334
###
### mod by Dogway (15-03-2022) - Merged Soothe(), SoothCL() and MCSoothe() plus optimizations.
###
###
### "This is a small postprocessor function for sharpening filters. The goal is temporal stabilization of clips that have been sharpened before. It is reasonably fast (contains 3 different lutxy operations and one TemporalSoften - that's about the cheapest possibility for what is done. Plugin coders are welcome ), and seems to work pretty well.
###
### The introduction of jitter on the temporal axis is a general problem of sharpening operations, since sharpening (usually) considers spatial aspects only. Therefore, Soothe() does a very simple job: get the difference between [source] and [sharpened source], apply a TemporalSoften on this difference BUT allow only changes towards 128 ("neutral"), and then apply this temporally calmed difference back to the original clip.
### Effectively, this will reduce the overall effect of sharpening - less in static areas, and more in moving areas.
###
### median=true uses a temporal median ( previously Clense() ) instead of temporal blur (TemporalSoften())"
###
### Advantages:
### - more steady appearance (less "nervous")
### - less bitrate required
### - somewhat positive effect on detail that is, due to the sharpening, prone to aliasing
### - smoother motion compared to plain-sharpening, since motion-blurred edges will be less sharpened
### - less artefacts in moving areas
### - LimitedSharpen can run faster, since one can get away with less supersampling
### - should only help, never harm
###
### Disadvantages:
### - overall sharpening effect is reduced, but this can be compensated by a little more initial sharpening
###
### Dependencies:
###         ExTools
###         MVTools
###         SMDegrain (for MC=true)
###
###
### Function Definition:
###     (
###     clip sharp,
###     clip orig,
###     int "keep"=24 (0 to 100)
###     [bool "median"=false],
###     [bool "MC"=false]
###     )
###
### Example:
###     Soothe(orig,blurry,keep=0) # You can also use it to recover sharpness from a blurry filter
###
function Soothe(clip sharp, clip orig, int "keep", bool "median", bool "MC", int "UV", bool "tv_range") {

    rgb  = sharp.isRGB()
    w    = sharp.width()
    h    = sharp.height()
    isHD = (w > 1099 || h >  599)
    isUHD= (w > 2599 || h > 1499)
    bi   = BitsPerComponent(sharp)
    fs   = propNumElements (sharp,"_ColorRange")  > 0 ? \
           propGetInt      (sharp,"_ColorRange") == 0 : false

    med  = Default(median,false)
    MC   = Default(MC,    false)
    keep = Default(keep,   MC ? 48 : 24)  # 0-100
    UV   = Default(UV,        1)
    tv   = Default(tv_range, !fs)
    UV3  = UV==3
    KP   = clamp(keep,0,100) / 100.

    Assert(IsVersionOrGreater(3,7,2),               "Soothe: Update AviSynth+ version")
    Assert(w == orig.width() && h == orig.height(), "Soothe: clip dimensions must match!")

    if (MC) {

        isc = VarExist("b1c") && VarExist("f1c")
        isv = VarExist("cb1") && VarExist("cf1")

        if (!isc) {

            blksize   = isUHD ? 32 : isHD ? 16 : 8

            pre       = orig.ex_minblur(isHD ? 2 : 1, sharp=false, UV=uv)
            DB        = ex_lutxyz(sharp,orig,pre,"x z - X@ y z - 1.49 * Y@ * 0 < z X abs Y abs < x Y z + ? ?",UV=uv,fulls=!tv)
            pre       = pre.ConvertBits(8, dither=-1, fulls=!tv)
            superfilt = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, sharp=2, rfilter=3, chroma=UV3, mt=true)
            super     = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, sharp=2, rfilter=3, chroma=UV3, mt=true, levels=1)

            cb  = superfilt.MAnalyse(isb = false,    chroma=UV3, blksize = blksize,   overlap=blksize/2, delta = 1, truemotion=true, mt=true, dct=0, search=4, pglobal=13, temporal=true, global=true, plevel=0)
            cf  = superfilt.MAnalyse(isb = true,     chroma=UV3, blksize = blksize,   overlap=blksize/2, delta = 1, truemotion=true, mt=true, dct=0, search=4, pglobal=13, temporal=true, global=true, plevel=0)
            cb1 = isv ? cb1 : super.Mrecalculate(cb, chroma=UV3, blksize = blksize/2, overlap=blksize/4, thSAD=190, truemotion=true, mt=true, dct=5, search=0)
            cf1 = isv ? cf1 : super.Mrecalculate(cf, chroma=UV3, blksize = blksize/2, overlap=blksize/4, thSAD=190, truemotion=true, mt=true, dct=5, search=0)
        }

        cb1   = ex_repair(isc ? b1c : sharp.MCompensate(super.ConvertBits(bi, fulls=!tv), cb1, thSCD1=round(6.25*8*8), thSCD2=round(2.03*8*8), mt=true), orig, "undot3", UV=1)
        cf1   = ex_repair(isc ? f1c : sharp.MCompensate(super.ConvertBits(bi, fulls=!tv), cf1, thSCD1=round(6.25*8*8), thSCD2=round(2.03*8*8), mt=true), orig, "undot3", UV=1)

        diff  = interleave(cb1,DB,cf1)

        diff2 = med ? diff.ex_median("medianT",UV=uv) : diff.temporalsoften(1,255,UV3?255:0,32,2)
        diff2 = diff2.selectevery(3,1)
        ex_lutxyz(sharp,DB,diff2,Format("z y - X@ x y - Y@ * 0 < Y {KP} * y + X abs Y abs < x z - {KP} * z + x ? ?"),UV=uv,fulls=!tv)


    } else {

        diff  = ex_makediff(orig,  sharp, UV=uv, fulls=!tv)
        diff2 = med ? diff.ex_median("medianT",UV=uv) : diff.temporalsoften(1,255,UV3?255:0,32,2)
        expr  = bi==32 ? Format("y z * 0 < y {KP} * y abs z abs > y z - {KP} * z + y ? ? x swap -")                                                         : \
                         Format("y range_half - Y@ z range_half - Z@ * 0 < Y {KP} * range_half + Y abs Z abs > y z - {KP} * z + y ? ? x swap - range_half +")
        ex_lutxyz(orig,diff,diff2,expr,UV=uv,fulls=!tv).propCopy(sharp)
    } }