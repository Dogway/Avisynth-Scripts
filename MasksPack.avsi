###                                                            ##
###                                                            ##
###                     2.4            (15-04-2015)            ##
###                     2.8 By Dogway  (22-06-2021)            ## Updated BoxMask(), FlatMask() and LumaMask() to internal functions (faster and HBD support)
###                     2.9 By Dogway  (18-10-2021)            ##
### Mask functions Pack 3.0 By Dogway  (04-11-2021)            ##
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
###
###########################


function BoxMask(clip clp, int "x1", int "x2", int "y1", int "y2", bool "invert", bool "show", bool "matchformat", bool "fulls") {

    x1      = Default(x1,0)
    x2      = Default(x2,0)
    y1      = Default(y1,0)
    y2      = Default(y2,0)
    upper   = Default(invert, false)
    show    = Default(show, false)
    format  = Default(matchformat, true)
    fs      = Default(fulls, false)

    bdpth = BitsPerComponent(clp)

    LetterBox(BlankClip(clp,1,pixel_type="Y"+string(bdpth),color_yuv=upper?$000000:$ffffff,channels=0),y1,height(clp)-y2,x1,width(clp)-x2,color_yuv=upper?$ffffff:$000000)
    format ? MatchClip(clp) : last

    !show ? last : ex_blend(clp,last,"softlight",fulls=fs) }


##################
###
### FlatMask (MIX mod)
###
### 17-06-2021
### by cretindesalpes: (http://forum.doom9.org/showthread.php?p=1507257#post1507257)
### Ported back from real.finder's HBD mod
###
### Blends original with filtered (e.g. denoised) clip by masking out flat areas with weak, small or no detail.
### Useful for denoising cel animation while protecting detailed backgrounds.
### If you just want the mask itself use the 'show' parameter, it will be useable for masking operations as well.
###
### Use like this:
###
### raw=last
### YourFilter()
### flatmask(raw)
###
###
### Requires:
### Masktools2: http://forum.doom9.org/showthread.php?t=98985
### ExTools:    https://forum.doom9.org/showthread.php?t=182881
###
###########################


function FlatMask(clip filtered, clip raw, float "str",int "r",  bool "luma", float "Lth", bool "invert", bool "show", bool "notemp", bool "extend", bool "fulls") {

    bi    = BitsPerComponent(raw)

    raw   = Default(raw, filtered)

    exten = Default(extend, false)
    str   = Default(str, exten ? 10 : 6)         # Strength of the mask, the higher -> more detail protection
    r     = Default(r, exten ? 2 : 3)            # Mask blurriness

    luma  = Default(luma,true)                   # Enables dark zones to be masked out (for filtering) independent of detail
    th    = Default(Lth,75)                      # Start of penumbra for masking when luma=true

    upper = Default(invert, false)               # Inverts the mask
    show  = Default(show,  false)                # Shows the mask
    notem = Default(notemp, exten)
    fs    = Default(fulls, false)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version.")
    c4ma = exten ? filtered : raw

    e1 = c4ma.mt_edge (mode="prewitt", thY1=0, thY2=255)
    e2 = c4ma.mt_edge (mode="min/max", thY1=0, thY2=255)
    ex_makediff (e1, e2, dif=false, fulls=fs)
    ex_lut ("x 0 max range_max / 0.25 ^ range_max *", fulls=fs)
    mt_deflate().mt_deflate ()

    luma ? mt_logic(c4ma.ex_binarize(th,fulls=fs),"min") : last

    w = width ()
    h = height()

    BicubicResize (w / (r*2) * 2, h / (r*2) * 2, 1, 0)
    notem ? last : TemporalSoften (2, 20, 255)
    mt_expand ().mt_inpand ().mt_inpand (mode="both")
    BicubicResize (w, h, 1, 0)

    var  = show  ? 128 : 1
    up   = ex_bs(10, 8, bi, fulls=fs)
    code = Format(upper ? "range_max x {up} - {str} * -" : "x {up} - {str} *")
    msk  = ex_lut (code,UV=var,fulls=fs)
    msk  = exten ? !upper ? msk.ex_invert(fulls=fs).ex_expand(2).ex_invert(fulls=fs).ex_inpand(2) : msk.mt_expand() : msk
    show ? msk : mt_merge(filtered,raw,msk,luma=true, y=3, u=3, v=3) }




##############################################################
###                                                          #
### LumaMask() (11-06-2021)                                  #
###                                                          #
##############################################################
###
### Function by Didée, adapted by Dogway:
### http://forum.doom9.org/showpost.php?p=761786&postcount=3
###
###
### Mixes 2 versions of a source by a mask defined by luminosity (Luma Plane)
###
###
### filtered [default: last]
### -------------------
### By default the input of the function is assumed as filtered
###
###
### raw [default: filtered]
### -------------------
### Define where you want to create the mask from, and thus blend with the filtered clip.
###
###
### b [default: 24]
### -------------------
### Limit for 100% black in your mask. [0...255]
###
###
### W [default: 48]
### -------------------
### Limit for 100% white in your mask. [0...255]
###
###
### invert [default: false]
### -------------------
### Inverts the mask. By default filtered clip will be passed through the white parts of the mask.
###
###
### smooth [default: false]
### -------------------
### Denoises some nervious grain on the mask so it doesn't have a negative effect on the mask/blending.
###
###
### show [default: false]
### -------------------
### Shows the mask, which you can directly use with any masking operations on your own.
###_______________________
###                       |
### Example:              |
###  raw=last             |
###  YourFilter()         |
###  LumaMask(raw)        |
###_______________________|
###
###   This will pass the filtered version of the clip only in the brightest part of the image,
###   starting where luma pixel value is 24 bright and smoothed up to 100% bypass from 48 brightness value onwards.
###   Useful to protect dark/bright areas from certain filters.
###
##############################################################


function LumaMask(clip filtered, clip raw, int "b", int "w", bool "invert", bool "smooth", bool "show", int "UV", bool "fulls") {

    rgb    = isRGB(raw)
    isy    = isy(filtered)
    bi     = BitsPerComponent(raw)

    raw    = Default(raw, filtered)
    LO     = Default(b, 24)
    HI     = Default(w, 48)
    upper  = Default(invert, false)
    smooth = Default(smooth, false)
    show   = Default(show,   false)
    fs     = Default(fulls,  false)
    UV     = Default(UV,  !isy ? 128 : 1)

    w      = raw.width()
    h      = raw.height()
    bi32   = bi == 32 ? "0 1 clip" : ""
    sm     = (w  > 2599 ||  h  > 1499) ? 3 : \
             (w  > 1099 ||  h  > 599)  ? 2 : 1

    LO     = ex_bs(LO, 8, bi, fulls=fs)
    HI     = ex_bs(HI, 8, bi, fulls=fs)

    code   = upper ? Format("range_max range_max {HI} {LO} - / x {LO} - * - "+bi32) : \
                     Format("0         range_max {LO} {HI} - / x {LO} - * - "+bi32)

    str    = ex_dlut(code, bi, fs)
    cstr   = ex_UVexpr("", UV, bi, rgb, fs)

    msk    = Expr(raw, str, cstr, scale_inputs=ex_UVf(rgb, bi))
    msk    = smooth ? msk.ex_inpand(sm).ex_expand(sm+sm).ex_inpand(sm) : msk

    show  ?  msk : mt_merge(raw,filtered,msk,true) }
