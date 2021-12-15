###                                                            ##
###                                                            ##
###           MasksPack 4.2 By Dogway  (15-12-2021)            ##
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

    x1      = min(max(x1,0),w)
    x2      = min(max(x2,0),w)
    y1      = min(max(y1,0),h)
    y2      = min(max(y2,0),h)

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
### FlatMask() (15-12-2021)
###
###
### This is a dual purpose filter for 2D cartoons to create either high quality edge masks or flat masks.
### One is the opposite of the other so you only have to tune the radius and hyst setting to define to
### what extent the edge mask is applied.
### If you only want the edge mask output set show=false (with 'filt' argument undefined)
###
### Dependencies:
###     ExTools
###     ResizersPack
###     SMDegrain (for ex_retinex)
###         GradePack
###
### Example:
###     filt = YourFilter()
###     flatmask(1,filt=filt) # to merge with filtered clip
###
###########################

function FlatMask(clip a, int "rad", clip "filt", int "hyst", int "lo", bool "show") {

    a
    rgb   = isRGB()
    isy   = isy()
    bi    = BitsPerComponent()
    w     = width ()
    h     = height()
    fs    = propNumElements ("_ColorRange")  > 0 ? \
            propGetInt      ("_ColorRange") == 0 : rgb

    isHD  = (w > 1099 ||  h >  599)
    isUHD = (w > 2599 ||  h > 1499)
    fil   = Defined(filt)

    rd    = Default(rad,      1)
    lo    = Default(lo,      40)   # low level for ex_retinex normalization
    hy    = Default(hyst,     1)   # hysteresis radius
    sh    = Default(show, false)   # false to show mask, true to show mask in split view

    !isy ? ExtractY() : last
    ConvertBits(8,dither=-1,fulls=fs)
    # 3x3 is too broad for SD so upscale
    !isHD  ? ex_median("IQM").blackmanresize(w*2,h*2)         : last
    # UHD size is too big for good performance
     isUHD ? bicubicresize(nmod(w/2,2),nmod(h/2,2),-0.5,0.25) : last

    ex_retinex(lvl=1,lo=lo,tv_range=!fs)
    # prefilter

    isHD ? ex_median("IQM5") : last
    # edge mask
    ex_luts(last,mode="range",pixels=ex_shape(rd,mode="disk"),exprf=" dup * 0.5 *")

    if (hy>0) {

        # hysteresis
        ex_luts(last,mode="avg",  pixels=ex_shape(hy+1, mode="ring"),exprf=" x - abs range_half > range_max x ?",fulls=true)

        # edge mask clean up
        ex = ex_expand()
        in = ex.ex_inpand()
        ex_lutxyz(ex,in,"y z == x y + range_max y clip x ?")
        ex_deflate()
        }

    !isHD  ? bicubicresize(w,h,-0.5,0.25) : last
     isUHD ? bicubicresize(w,h,1/3.,1/3.) : last

    msk8 = last

    ConvertBits(bi,fulls=true)

    if (fil) {
        # Merge with filtered through the edge mask
        ex_merge(filt,a,last,luma=true)
        # Artifact Repair
        ex_luts(a,last,mode="clamp",pixels=ex_shape(rd+1,mode="disk")) }

    if (sh) {
        src = fil ? last : a
        msk = mskY_to_YYY(src, msk8, false, false, 128, bi)
        stackhorizontal(padresize(src,w/2,h,biasW=w/4),padresize(msk,w/2,h,biasW=-w/4)) } }




#####################################################################
###                                                                 #
### LumaMask() (11-12-2021)                                         #
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

function LumaMask(clip a, int "b", int "w", bool "invert", int "UV") {

    rgb    = isRGB(a)
    isy    = isy(a)
    bi     = BitsPerComponent(a)
    fs     = propNumElements (a,"_ColorRange")  > 0 ? \
             propGetInt      (a,"_ColorRange") == 0 : rgb
    lut    = bi == 32 ? 0 : 1

    LO     = Default(b, 24)
    HI     = Default(w, 48)
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
