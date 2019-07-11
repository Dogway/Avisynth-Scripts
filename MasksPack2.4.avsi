###                                                            #
###                                                            #
### Mask functions Pack 2.4 By Dogway (15-04-2015)             #
###                                                            #
### (http://forum.videohelp.com/threads/369143?#post2364052)   #
###                                                            #
################################################################
###
### SatMask()
###           (incomplete, just remaining "Recover" in fast mode)
###
### 20-11-2011
### by Motenai Yoda:  (http://forum.doom9.org/showthread.php?t=162882)
### and Gavino's help
###
### Saturation Mask
### This function allows to recreate the effect on some programs called "Vibrance".
### That is to enhance saturation where it is low.
### There is another mode called "Dullness" which does the opposite, lowers saturation where is high.
### Finally a "Recover" mode, to enhance saturation where is lost (after filtering) when a Rc clip is given for reference.
###
### Use 'bias' to weight the internal mask and 'show' for visual feedback.
### You can use a (de)saturated clip as input for the "Sat" parameter as its replacement, or use a float number for around a 3x speed gain.
### The downside for using a number instead are less control compared to your preferred 'saturator', and chroma
### being dithered (down to 8 bit) once in the process when lsb=true.
### Input must be at least mod 4. Working values are assumed to be above 1.0. Values < 1.0 can create some artifacts.
###
### Use like this (recommended):
###
### sat=SmoothTweak(saturation=1.5)
### satmask(sat)   # Mandatory to write parameter "sat=" when using a clip
###
### or like this (more speed):
###
### satmask(1.5)
###
### Requires:
### Masktools2: http://forum.doom9.org/showthread.php?t=98985
### Dither:     http://forum.doom9.org/showthread.php?p=1386559#post1386559
###
###########################

function SatMask(clip c, val Sat, float "bias", string "mode", clip "Rc", bool "lsb", bool "show", int "U", int "V") {

 bias  = string(default(bias, 5))
 mode  = default(mode,  "Vibrance")
 lsb   = default(lsb,  false)
 show  = default(show, false)
 U     = default(U, 3)
 V     = default(V, 3)


VibMod = mode=="Vibrance"  ? true : false
DulMod = mode=="Dullness"  ? true : false
RecMod = mode=="Recover"   ? true : false
Recclp = Defined(Rc)       ? true : false
SatC   = isclip(Sat)       ? true : false
fON    = !SatC ? (Sat!=1.0 ? true : false) : false
SatB   =  SatC || fON      ? true : false
SatB  ? Assert   (SatC || isint(Sat) || isfloat(Sat),  "'Sat' only accepts float, integers or clip inputs")                                       : nop()
RecMod? Assert   (Recclp,                              "'Recover Mode' requires a clip defined in the 'Rc' parameter to recover saturation from") : nop()
fmode  = SatB  ? fON : false

c
w      =        width ()
h      = !lsb ? height() : height()/2
padX   = w%4 == 0 ? 0 : (4 - w%4)
padY   = h%4 == 0 ? 0 : (4 - h%4)
clp    = !lsb ? pointresize    (w+padX, h+padY, 0, 0, w+padX, h+padY)                                  : \
                Dither_resize16(w+padX, h+padY, 0, 0, w+padX, h+padY, kernel="point")

Recclp         ? eval("""
Rc
wRc    =        width ()
hRc    = !lsb ? height(): height()/2
padXRc = wRc%4 == 0 ? 0 : (4 - wRc%4)
padYRc = hRc%4 == 0 ? 0 : (4 - hRc%4)
Rc     = !lsb ? pointresize    (wRc+padXRc, hRc+padYRc, 0, 0, wRc+padXRc, hRc+padYRc)                  : \
                Dither_resize16(wRc+padXRc, hRc+padYRc, 0, 0, wRc+padXRc, hRc+padYRc,kernel="point").ditherpost(mode=6,y=1)

a      =  RecMod                    ? mt_lutxy(Vtoy(Rc),Utoy(Rc),"x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ 128 > 255 x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ "+bias+" * ?",u=1,v=1)                  : nop()"""  ) : nop()

lsb ? clp.ditherpost(mode=6,y=1) : clp

!fmode || show ? eval("""
b      =  DulMod || RecMod          ? mt_lutxy(Vtoy(),  Utoy(),  "x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ 128 > 255 x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ "+bias+" * ?",u=1,v=1)                  : nop()


msk    = (VibMod)                   ? mt_lutxy(Vtoy(),  Utoy(),  "x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ 128 > 0 128 x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ - 128 / "+bias+" ^ 255 * ? ",u=1,v=1) : \
         (DulMod)                   ? b                                                                : \
         (RecMod)                   ? mt_lutxy(a,b,"x y - abs 2 *",u=-128,v=-128)                      : \
          Assert(false, "Wrong Saturation Mode")
msk    =  !show                     ? YToUV(msk,msk).crop(0,0,-padX,-padY) : msk """)                  : nop()



show ? (lsb ? msk.Spline36Resize(w+padX, h+padY).crop(0,0,-padX,-padY).Dither_convert_8_to_16()        : \
              msk.Spline36Resize(w+padX, h+padY).crop(0,0,-padX,-padY))                                : \
(SatB                ?  \
((VibMod)            ?  \
       (lsb ? (fmode ? mergeluma(Dither_lutxy8(SwapUV(),"x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ 256 * 32768 > x 256 * "+
                                      \+" x 128 - 128 x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ - 128 / "+bias+" ^ "+string(sat-1)+
                                      \+" * 1 + * 128 + 256 * ?",           y=2,u=u,v=v),clp)          : \
                                      Dither_merge16_8(c,Sat,msk,           y=4,u=u,v=v))              : \
              (fmode ? mt_lutxy(SwapUV(),"x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ 128 > x "+
                                      \+" x 128 - 128 x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ - 128 / "+bias+" ^ "+string(sat-1)+
                                      \+" * 1 + * 128 + ?",                 y=2,u=u,v=v)               : \
                                      mt_merge(        c,Sat,msk,           y=4,u=u,v=v)))             : \
 (DulMod)            ?  \
       (lsb ? (fmode ? mergeluma(Dither_lutxy8(SwapUV(),"x 128 - 2 ^ y 128 - 2 ^ +  .5 ^  256 * 32768 > x 256 * "+
                                      \+" x 128 - x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ "+string(sat-1)+
                                      \+" * "+bias+" / 1 + / 128 + 256 * ?",y=2,u=u,v=v),clp)          : \
                                      Dither_merge16_8(c,Sat,msk,           y=4,u=u,v=v))              : \
              (fmode ? mt_lutxy(SwapUV(),"x 128 - 2 ^ y 128 - 2 ^ +  .5 ^  128 > x "+
                                      \+" x 128 - x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ "+string(sat-1)+
                                      \+" * "+bias+" / 1 + / 128 + ?",      y=2,u=u,v=v)               : \
                                      mt_merge(        c,Sat,msk,           y=4,u=u,v=v)))             : \
 (RecMod)            ?  \
       (lsb ? (fmode ? mergeluma(Dither_lutxy8(SwapUV(),"x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ 256 * 32768 > x 256 * "+
                                      \+" x 128 - 128 x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ - 128 / "+bias+" ^ "+string(sat-1)+
                                      \+" * 1 + * 128 + 256 * ?",           y=2,u=u,v=v),clp)          : \
                                      Dither_merge16_8(c,Sat,msk,           y=4,u=u,v=v))              : \
              (fmode ? mt_lutxy(SwapUV(),"x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ 128 > x "+
                                      \+" x 128 - 128 x 128 - 2 ^ y 128 - 2 ^ +  .5 ^ - 128 / "+bias+" ^ "+string(sat-1)+
                                      \+" * 1 + * 128 + ?",                 y=2,u=u,v=v)               : \
                                      mt_merge(        c,Sat,msk,           y=4,u=u,v=v))) : nop())    : c)
!show     &&   fmode ? (lsb ? Dither_crop16(0,0,-padX,-padY) : crop(0,0,-padX,-padY))                  : last}



##################
###
### BoxMask
###
###
### Creates a boxed mask so you can use it in mt_merge* for custom filtering in localized areas.
### *mt_merge has a (probably rounding) bug where bright areas would be dimmed in output (http://forum.videohelp.com/threads/371283#post2385326)
###
###
###########################

function BoxMask(clip clp, int "x1", int "x2", int "y1", int "y2", bool "upper", bool "show") {

w=clp.width()
h=clp.height()

x1	  = Default(x1,0)
x2	  = Default(x2,0)
y1	  = Default(y1,0)
y2	  = Default(y2,0)
upper = Default(upper, true)
show  = Default(show, false)
sbitsn=BitsPerComponent(clp)

Assert(y1 <= y2, "x1 out of Bounds")
Assert(x1 <= x2, "x1 out of Bounds")
Assert(x2 <= w, "Boxmask() out of bounds")
Assert(y2 <= w, "Boxmask() out of bounds")

 blankclip (clp,1,x2-x1,y2-y1,pixel_type="Y8",color=upper?$ffffff:$000000).killaudio()
 addborders(x1,y1,w-x2,h-y2,upper?$000000:$ffffff)
 ColorYUV(levels="TV->PC")
 ConvertToYV12(matrix="PC.601")
 ConvertBits(sbitsn)
 
!show ? last : overlay(clp,last,mask=last,mode="softlight",opacity=0.5) }



function BoxMaskf(clip clp, int "x1", int "x2", int "y1", int "y2", bool "upper", bool "show") {

w=clp.width()
h=clp.height()

x1	  = Default(x1,0)
x2	  = Default(x2,0)
y1	  = Default(y1,0)
y2	  = Default(y2,0)
upper = Default(upper, true)
show  = Default(show, false)
sbitsn=BitsPerComponent(clp)

Assert(y1 <= y2, "x1 out of Bounds")
Assert(x1 <= x2, "x1 out of Bounds")
Assert(x2 <= w, "Boxmask() out of bounds")
Assert(y2 <= w, "Boxmask() out of bounds")

 blankclip (clp,1,x2-x1,y2-y1,pixel_type="Y8",color=upper?$ffffff:$000000).killaudio()
 addborders(x1,y1,w-x2,h-y2,upper?$000000:$ffffff)
 ColorYUV(levels="TV->PC")
 ConvertToYV12(matrix="PC.601")
 ConvertBits(sbitsn)
 Y = ConvertToY8()
 U = Y.Spline36Resize(W/2,H/2, src_left=0.25 - (0.25/w))
 V = Y.Spline36Resize(W/2,H/2, src_left=0.25 - (0.25/w))
 YToUV(U, V, Y)

!show ? last : overlay(clp,last,mask=last,mode="softlight",opacity=0.5) }


expr_merge ( clip a, clip b, clip msk, string yexpr, string "uexpr", string "vexpr", string "scale_inputs", bool "luma") {

luma = Default(luma, true)
yexpr = Default(yexpr, "")
uexpr = Default(uexpr, "")
vexpr = Default(vexpr, "")
scale_inputs = Default(scale_inputs, "none")

uexpr = luma ? yexpr : uexpr
vexpr = luma ? yexpr : vexpr

Eval("
 msk
 w=Width()
 h=Height()
 Y = ConvertToY8()
 U = Y.Spline36Resize(W/2,H/2, src_left=0.25 - (0.25/w))
 V = Y.Spline36Resize(W/2,H/2, src_left=0.25 - (0.25/w))
 msk=YToUV(U, V, Y)" )


code="x z range_size - abs * y z * + range_max / "
expr(a,b,msk,code,code,code, scale_inputs=scale_inputs)

}


##################
###
### FlatMask
###
### 10-06-2011
### by cretindesalpes: (http://forum.doom9.org/showthread.php?p=1507257#post1507257)
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
###
###########################

function FlatMask(clip filtered, clip raw, int "str",int "r",  bool "luma", int "Lth", bool "upper", bool "show") {

 raw   = default(raw, filtered)

 str   = string(default(str, 6))     # Strength of the mask, the higher -> more detail protection
 r     = default(r, 3)               # Mask blurriness

 luma  = default(luma,true)          # Enables dark zones to be masked out (for filtering) independent of detail
 th    = default(Lth,75)             # Start of penumbra for masking when luma=true

 upper = default(upper, false)       # Inverts the mask
 show  = default(show,  false)       # Shows the mask


e1 = raw.mt_edge (mode="prewitt", thY1=0, thY2=255)
e2 = raw.mt_edge (mode="min/max", thY1=0, thY2=255)
mt_makediff (e1, e2)
mt_lut ("x 128 - 0 max 256 / 0.25 ^ 256 *")
mt_deflate ().mt_deflate ()

luma ? mt_logic(raw.mt_binarize(threshold=th),"min") : last

w = width ()
h = height ()

BicubicResize (w / (r*2) * 2, h / (r*2) * 2, 1, 0)
TemporalSoften (2, 20, 255)
mt_expand ().mt_inpand ().mt_inpand (mode="both")
BicubicResize (w, h, 1, 0)

var  = show  ? 128 : 1
code = upper ? "255 x 10 - "+str+" * -" : "x 10 - "+str+" *"
msk  = mt_lut (code,u=var,v=var)
show ? msk : mt_merge(filtered,raw,msk,luma=true, y=3, u=3, v=3)}



##############################################################
###                                                          #
### LumaMask() (11-01-2014)                                  #
###                                                          #
##############################################################
###
### Function by Didée, adapted by Dogway:
### http://forum.doom9.org/showpost.php?p=761786&postcount=3
### http://forum.doom9.org/showthread.php?t=158954
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
### upper [default: false]
### -------------------
### Inverts the mask. By default filtered clip will be passed through the white parts of the mask.
###
###
### lsb [default: false]
### -------------------
### The whole process is performed in high bitdepth
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
###   Requires:
###   Masktools2:		 http://forum.doom9.org/showthread.php?t=98985
###   Dither (for lsb):  http://forum.doom9.org/showthread.php?p=1386559#post1386559
###
##############################################################

# still have to process UV planes for the merge
function LumaMask(clip filtered, clip raw, int "b", int "w", bool "upper", bool "lsb", bool "smooth", bool "show") {

raw      = default(raw, filtered)

LO       = string(default(b, 24))
HI       = string(default(w, 48))
upper    = default(upper,  false)
lsb      = default(lsb,    false)
smooth   = default(smooth, false)
show     = default(show,   false)

code     = upper ? "x "+LO+" scalef < range_max x "+HI+" scalef > 0 range_max x "+LO+" scalef -   range_max "+HI+" scalef "+LO+" scalef - / * - ? ?" : \
                   "x "+LO+" scalef < 0         x "+HI+" scalef >   range_max 0 x "+LO+" scalef - range_max "+LO+" scalef "+HI+" scalef - / * - ? ?"

msk      = expr(raw,code,"range_half","range_half",scale_inputs="floatf")
msk      = smooth ? msk.removegrain(22,0) : msk
msk

show  ?  msk : expr(raw,filtered,msk,"x z range_size - abs * y z * + range_max / ","","",scale_inputs="none" )}