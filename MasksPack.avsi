###                                                            ##
###                                                            ##
###           MasksPack 4.5 By Dogway  (22-12-2021)            ##
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
###########################

function BoxMask(clip clp, int "x1", int "x2", int "y1", int "y2", int "UV", bool "invert", bool "show") {

    clp
    rgb     = isRGB()
    w       = width ()
    h       = height()

    x1      = Default(x1,0)
    x2      = Default(x2,0)
    y1      = Default(y1,0)
    y2      = Default(y2,0)
    in      = Default(invert, false)
    show    = Default(show,   false)
    UV      = Default(UV,3)

           Assert(IsVersionOrGreater(3,7,1), "BoxMask: Update AviSynth+ version")
    show ? Assert(UV!=1,                     "BoxMask: 'show' requires UV=2 or 3") : nop()

    x1      =     min(max(x1,0),w)
    x2      = max(min(max(x2,0),w),x1)
    y1      =     min(max(y1,0),h)
    y2      = max(min(max(y2,0),h),y1)

    UV = UV!=3 && !rgb ? 128 : UV

    wh = !in ? "range_max" : "0"
    bl =  in ? "range_max" : "0"
    x  = is422() || is420() ? 2. : isYV411() ? 4. : 1
    y  = is420()            ? 2. :                  1

    x1c = nmod(x1/x,int(x))  x2c = nmod(x2/x,int(x))
    y1c = nmod(y1/y,int(y))  y2c = nmod(y2/y,int(y))

    Luma = Format("x {x1}  >= x {x2}  <= & y {y1}  >= y {y2}  <= & & "+wh+" "+bl+" ?")
    Chrm = Format("x {x1c} >= x {x2c} <= & y {y1c} >= y {y2c} <= & & "+wh+" "+bl+" ?")

    ex_lutspa(mode="absolute", expr=Luma, cexpr=Chrm, UV=UV)

    !show ? last : ex_blend(clp,last,"softlight",0.5) }



##################
###
### FlatMask() (22-12-2021)
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
###########################

function FlatMask(clip a, float "rad", float "scale", int "lo", int "MSR", clip "filt", bool "show") {

    a
    rgb   = isRGB()
    bi    = BitsPerComponent()
    w     = width ()
    h     = height()
    fs    = propNumElements ("_ColorRange")  > 0 ? \
            propGetInt      ("_ColorRange") == 0 : rgb

    isHD  = (w > 1099 ||  h >  599)
    isUHD = (w > 2599 ||  h > 1499)

    rd    = Default(rad, isHD?3:1)   # 1 or 2 for SD, 3 for HD and >=4 for 1080p or higher. 0 is a plain edge mask (ex_edge("qprewitt") )
    scl   = Default(scale,      5)   # Scale of the mask. Increase to convert edge mask to a flat mask
    lo    = Default(lo,         4)   # Clip pixels under this value
    lvl   = Default(MSR,       40)   # Low level for ex_retinex normalization
    sh    = Default(show,   false)   # True to show mask in split view
    fil   = Defined(filt)

    !isy() ? ExtractY() : last
    ConvertBits(8,dither=-1,fulls=fs)
    # 3x3 is too broad for SD so upscale
    !isHD  ? BlackmanResize(w*2,h*2)                 : last
    # UHD size is too big for good performance
     isUHD ? BilinearResize(nmod(w/2,2),nmod(h/2,2)) : last

    ex_retinex(lvl=1,lo=lvl,tv_range=!fs)  # some issues here on flat areas (quantization)
    MSR=ex_median("IQM")                   # pre for full 'qprewitt'

    # Prefilter (scale space)
    vsTCanny(sqrt(rd)/2.*sqrt(2),mode=-1,u=2,v=2)

    # Pseudo Ridge Filter
    xx1=    ex_lut(Format("x[-1,-1] x[1,1]  -"))
    xx1=xx1.ex_lut(Format("x[-1,-1] x[1,1]  -"))
    yy1=    ex_lut(Format("x[-1,1]  x[1,-1] -"))
    yy1=yy1.ex_lut(Format("x[-1,1]  x[1,-1] -"))

    xx2=    ex_lut(Format("x[1,1]  x[-1,-1] -"))
    xx2=xx2.ex_lut(Format("x[1,1]  x[-1,-1] -"))
    yy2=    ex_lut(Format("x[1,-1] x[-1,1]  -"))
    yy2=yy2.ex_lutxyza(xx1,yy1,xx2,            \
                   Format("x[1,-1] x[-1,1] - 0 max dup * y dup * z dup * a dup * + + + sqrt {scl} * dup {lo} {scl} * > swap 0 ?"))

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
    ex_luts(     mode="avg", pixels=ex_shape(ceil(rd/2.), mode="ring"), exprf="dup dup x > swap 128 > & swap 1.15 * x ?")

    rd  = round(rd)
    rd == 1 ? yy2                          : \
    rd == 0 ? ex_edge(MSR,"qprewitt")      : last                                # maybe add back qprewitt on top for rd==1

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

    Assert(IsVersionOrGreater(3,7,1), "LumaMask: Update AviSynth+ version.")

    bi32   = bi == 32 ? "0 1 clip" : ""
    LO     = ex_bs(LO, 8, bi, fulls=fs)
    HI     = ex_bs(HI, 8, bi, fulls=fs)

    code   = inv ? Format("range_max range_max {HI} {LO} - / x {LO} - * - "+bi32) : \
                   Format("0         range_max {LO} {HI} - / x {LO} - * - "+bi32)

    str    = ex_dlut(code, bi, true)
    cstr   = ex_UVexpr("", UV, bi, rgb, true)

    isy     ?  Expr(a, str,       lut=lut) : \
    UV == 1 ?  Expr(a, str, "",   lut=lut) : \
               Expr(a, str, cstr, lut=lut)
               PropSet("_ColorRange", 0)   }
