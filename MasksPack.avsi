###                                                            ##
###                                                            ##
###           MasksPack 4.0 By Dogway  (11-12-2021)            ##
###                                                            ##
### https://forum.doom9.org/showthread.php?t=182881            ##
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
###         GradePack      (for show=true)
###         TransformsPack (for HBD -fullscale bugfix- )
###             ExTools
###
###########################

function BoxMask(clip clp, int "x1", int "x2", int "y1", int "y2", int "UV", bool "invert", bool "show") {

    rgb     = isRGB(clp)
    w       = width(clp)
    h       = height(clp)
    px      = PixelType(clp)
    bi      = BitsPerComponent(clp)
    fs      = propNumElements (clp,"_ColorRange")  > 0 ? \
              propGetInt      (clp,"_ColorRange") == 0 : rgb

    x1      = Default(x1,0)
    x2      = Default(x2,0)
    y1      = Default(y1,0)
    y2      = Default(y2,0)
    inv     = Default(invert, false)
    show    = Default(show,   false)
    UV      = Default(UV,3)

           Assert(IsVersionOrGreater(3,7,1), "BoxMask: Update AviSynth+ version.")
    show ? Assert(UV!=1, "BoxMask: 'show' requires UV=2 or 3.") : nop()

    wh      = UV==2 ? $ff8080 : $ffffff
    bl      = UV==2 ? $008080 : $000000

    rgb ? LetterBox(BlankClip(clp,1,pixel_type=UV==1?"Y"+string(bi):px,color    =inv?bl:wh,channels=0),y1,h-y2,x1,w-x2,color    =inv?wh:bl) : \
          LetterBox(BlankClip(clp,1,pixel_type=UV==1?"Y"+string(bi):px,color_yuv=inv?bl:wh,channels=0),y1,h-y2,x1,w-x2,color_yuv=inv?wh:bl)

    bi!=8 && !rgb ? Full_scale() : last # if the mask is binary we can use ConvertBits(bi, fulls=false, fulld=true), which is a bit faster

    !show ? last : ex_blend(clp,last,"softlight",0.5) }




##################
###
### FlatMask (MIX mod)
###
### 11-12-2021
### by cretindesalpes: (https://forum.doom9.org/showthread.php?p=1507257#post1507257)
### Ported back from real.finder's HBD mod
###
### Blends original with filtered (e.g. denoised) clip by masking out flat areas with weak, small or no detail.
### Useful for denoising cel animation while protecting detailed backgrounds.
### If you just want the mask itself use the 'show' parameter, it will be useable for masking operations as well.
###
### Example:
###
### raw=last
### YourFilter()
### flatmask(raw)
###
###
### Dependencies:
###     MaskTools2: https://avisynth.nl/index.php/MaskTools2
###     ExTools:    https://forum.doom9.org/showthread.php?t=182881
###
###########################

function FlatMask(clip filtered, clip "raw", float "str",int "r",  bool "luma", float "Lth", bool "invert", bool "show", bool "notemp", bool "extend", bool "fulls") {

    rgb   = isRGB(filtered)
    bi    = BitsPerComponent(filtered)
    w     = width (filtered)
    h     = height(filtered)

    raw   = Default(raw, filtered)

    exten = Default(extend, false)
    str   = Default(str, exten ? 10 : 6)         # Strength of the mask, the higher -> more detail protection
    r     = Default(r, exten ? 2 : 3)            # Mask blurriness

    luma  = Default(luma,true)                   # Enables dark zones to be masked out (for filtering) independent of detail
    th    = Default(Lth,75)                      # Start of penumbra for masking when luma=true

    upper = Default(invert, false)               # Inverts the mask
    notem = Default(notemp, exten)
    fs    = Default(fulls,    rgb)

    Assert(IsVersionOrGreater(3,7,1), "FlatMask: Update AviSynth+ version.")
    c4ma = exten ? filtered : raw

    e1 = c4ma.mt_edge (mode="prewitt", thY1=0, thY2=255)
    e2 = c4ma.mt_edge (mode="min/max", thY1=0, thY2=255)
    ex_makediff (e1, e2, dif=false, fulls=fs)
    ex_lut ("x 0 max range_max / 0.25 ^ range_max *", fulls=fs)
    mt_deflate().mt_deflate ()

    luma ? ex_logic(c4ma.ex_binarize(th),"min") : last

    BicubicResize (w / (r*2) * 2, h / (r*2) * 2, 1, 0)
    notem ? last : TemporalSoften (2, 20, 255)
    ex_expand().ex_inpand(2,mode="disk")
    BicubicResize (w, h, 1, 0)

    up   = ex_bs(10, 8, bi, fulls=fs)
    code = Format(upper ? "range_max x {up} - {str} * -" : "x {up} - {str} *")
    msk  = ex_lut (code,UV=128,fulls=fs)
    exten ? !upper ? msk.ex_invert().ex_expand(2).ex_invert().ex_inpand(2) : \
                     msk.ex_expand()                                       : msk }




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
               Expr(a, str, cstr, lut=lut) }
