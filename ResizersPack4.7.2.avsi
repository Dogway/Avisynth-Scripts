###                                                        #
###                                                        #
### Resizers Functions Pack 4.5   by Dogway (21-09-2015)   #
### Resizers Functions Pack 4.6   by Dogway (06-03-2019)   #
### Resizers Functions Pack 4.7.1 by Dogway (01-04-2021)   # -> Finally fixed PadResize() (for real), added nnedi3 to RatioResize, added automatic dynamic cropping function: MatteCrop()
### Resizers Functions Pack 4.7.2 by Dogway (03-04-2021)   # -> Updated MatteCrop()
###                                                        #
##########################################################
###
### http://forum.videohelp.com/threads/369143
###
### High Quality Resizer based totally on the Dither tools by cretindesalpes.
###             (http://forum.doom9.org/showthread.php?p=1386559#post1386559)
###
### With these tools now is possible to resize and change matrix all in float point (thus almost zero rounding error)
### and use modern dithering methods for the back to 8 bits stage. You can pick your prefered kernel resizer and even make use
### of linear scaling. What is done in this function are handy automatizations for using it whether is yuv or rgb inputs,
### 16 or 8 bit input/output, and SD or HD with matrix conversion if necessary. Therefore there's no strict need of
### rgb/tvrange/matrix parameters for common (correct) inputs.
###
### Limitations (by nature of Dither):
###  - Input must be mod2 for yuv and rgb, and mod4 for yuv with matrix change when downscaling, otherwise input will be automatically cropped.
###  - Output is always mod 2 for yuv and rgb, and mod4 when matrix change when not downscaling (i.e. upscaling or not scaling)
###  - Also you can't change matrix in rgb mode.
###  - NoRing setting is limited up to around a 3x scale difference from source
###
### * Note about lsb_in, and lsb_out parameters:
### For yuv inputs it is straight forward (although you will have to deal with matrix conversions for yourself if needed).
### For RGB instead is mandatory to define rgb=true, input must be rgb48y or i.e. if both lsb parameters are on, the most common chain would become:
###
### Interleave(showred("yv12"),showgreen("yv12"),showblue("yv12"))
###   Dither_convert_8_to_16()
###       LinearResize(1400,700,lsb_in=true,lsb_out=true,rgb=true)
###   Ditherpost(ampn=0.5,mode=6,y=3,u=1,v=1)
### MergeRGB(SelectEvery(3,0),SelectEvery(3,1),SelectEvery(3,2))
###
##############################
###
### Default mode= for output is always 6 (error diffusion), this gives out the most quality, but for video encoding
### it is recommended to use 0 (ordered dither) or similar for better optimization on encoding quantization. An usual use would be:
###
### LinearResize(640,480,kernel="spline36",mode=0)
###
### Read Dither documentation for more information about this.
###
###############################################################################

function LinearResize(clip a, int "w", int "h", string "kernel", bool "linear", bool "TVrange", string "matrix", bool "lsb_in", bool "lsb_out", bool "NoRing", bool "interlaced", \
                      string "matrix_out", string "cplace_in", string "cplace_out", float "fh", float "fv", int "taps", float "a1", float "a2", float "a3", bool "rgb", int "mode", float "src_left", float "src_top", float "src_width", float "src_height"){


 lsb_in  = default ( lsb_in,  false)
 lsb_out = default ( lsb_out, false)

aw = a.Width()
ah = lsb_in ? a.Height()/2 : a.Height()

 w       = default ( w,        aw )
 h       = default ( h,        ah )
 rgba    = default ( rgb,  a.isrgb() ? true  : false)

!rgba ? eval("
iHD = ah>599 || aw>1279 ? true  : false
oHD =  h>599 ||  w>1279 ? true  : false
#SDHD = !iHD ? oHD ? true  : false
#HDSD =  iHD ? oHD ? false : true
") : nop()

 kernel  = default ( kernel, "spline36")
 linear  = default ( linear,      false)
 TV      = default ( TVrange,   rgba ? false : true )
 m1      = default ( matrix,    rgba || !iHD ? "601" : "709")
 m2      = default ( matrix_out, Defined(matrix) ? matrix : ( rgba || !oHD ? "601" : "709"))
 cp_in   = default ( cplace_in,   "mpeg2")
 cp_out  = default ( cplace_out,  "mpeg2")
 fh      = default ( fh, 1.0)         # Shrink (>1.0 Sharpen) or expand (<1.0 Blur) the Kernel
 fv      = default ( fv, fh)          # idem but vertically
 taps    = default ( taps,  4)        # For lanczos
 a1      = default ( a1,  kernel=="Gauss" || kernel=="Gaussian" ? 30 : 0.333)
 a2      = default ( a2,  0.333)      # a1 and a2 are the b and c parameters of cubic kernels. a1 is also the p parameter of Gauss kernel.
 a3      = default ( a3,  1.0)
 mode    = default ( mode, 6)
 NR      = default ( NoRing, false)
 inter   = default ( interlaced,  false)

mtrx  = m1!=m2                  ? true : false
rgba ? Assert(mtrx==false,   "You can't change matrix in RGB"): nop()
Cpl   = cp_in != cp_out         ? true : false
DOWN  = aw>=w || ah>=h          ? true : false
UP    = aw<w  || ah<h           ? true : false
NP    = (aw == w) && (ah == h)  ? true : false
mdown = (mtrx &&  DOWN) || Cpl  ? true : false
mup   = (mtrx &&    UP) || Cpl  ? true : false
mupm  = mup ? 4 : 2


rgba || mdown ? eval("
mod  = mtrx   ? 4 : 2
bw   = mod - (((aw) -1)%mod + 1)
bh   = mod - (((ah) -1)%mod + 1)
!lsb_in  ?  a.crop(bw/mod,bh/mod,-bw,-bh) : a") : a

!lsb_in  ? (rgba   ?        Interleave(showred("yv12"), showgreen("yv12"), showblue("yv12")).Dither_convert_8_to_16()              \
         :         (mdown ?                          Dither_convert_yuv_to_rgb(lsb_in=false,matrix=m1,cplace=cp_in,interlaced=inter,chromak=kernel,tv_range=tv,output="rgb48y") \
         :                  Dither_convert_8_to_16()))                                                                             \
         : (mdown  ?                                 Dither_convert_yuv_to_rgb(lsb_in=true, matrix=m1,cplace=cp_in,interlaced=inter,chromak=kernel,tv_range=tv,output="rgb48y")              : last)

mdown    ?                  Dither_convert_rgb_to_yuv(SelectEvery (3, 0),SelectEvery (3, 1),SelectEvery (3, 2),lsb=true,matrix=m2,cplace=cp_out,interlaced=inter,chromak=kernel,tv_range=tv) : last


linear     ?                  Dither_y_gamma_to_linear(tv_range_in=tv,tv_range_out=false,curve=rgba?"srgb":"601")                                : last
!NP ? (NR  ?                  Dither_resize16nr(round(float(w)/mupm)*mupm,round(float(h)/mupm)*mupm,kernel=kernel,fh=fh,fv=fv,taps=taps,a1=a1,a2=a2,a3=a3,u=rgba?1:3,v=rgba?1:3,src_left=src_left,src_top=src_top,src_width=src_width,src_height=src_height,noring=true) : \
                              Dither_resize16  (round(float(w)/mupm)*mupm,round(float(h)/mupm)*mupm,kernel=kernel,fh=fh,fv=fv,taps=taps,a1=a1,a2=a2,a3=a3,u=rgba?1:3,v=rgba?1:3,src_left=src_left,src_top=src_top,src_width=src_width,src_height=src_height)) : last
linear     ?                  Dither_y_linear_to_gamma(tv_range_in=false,tv_range_out=tv,curve=rgba?"srgb":"601")                                : last


!lsb_out && rgba   ?        Ditherpost(ampn=0.5,mode=6,u=1,v=1)                                                              : last
mup         ?               Dither_convert_yuv_to_rgb(lsb_in=true,matrix=m1,cplace=cp_in,interlaced=inter,chromak=kernel,tv_range=tv,output="rgb48y")      : last
r = mup || rgba    ?        SelectEvery (3, 0)                                                                               : nop()
g = mup || rgba    ?        SelectEvery (3, 1)                                                                               : nop()
b = mup || rgba    ?        SelectEvery (3, 2)                                                                               : nop()

!lsb_out ? (rgba   ?        Mergergb(r,g,b,pixel_type=isrgb24(a)?"rgb24":"rgb32")                                                 \
                   : (mup ? Dither_convert_rgb_to_yuv(r,g,b,lsb=false,matrix=m2,cplace=cp_out,interlaced=inter,chromak=kernel,tv_range=tv,mode=mode) :  Ditherpost(mode=mode))) \
         : (mup    ?        Dither_convert_rgb_to_yuv(r,g,b,lsb=true ,matrix=m2,cplace=cp_out,interlaced=inter,chromak=kernel,tv_range=tv)           :  last)}



##############################
### Resizer based on different ratios, like DAR, PAR, percentage, etc.
### More like a useful resize calculator than a resizer per se.
### The Mode parameter accepts the next ones (in quotes):
###
### "DAR"         Convert source to a target DAR (display aspect ratio).
### "DARConform"  You can also "conform" DAR:
###               i.e. resize it in such way that when your media player apply DAR of 4/3, 16/9, etc
###               to your video, image is geometry correct. Useful for anamorphic encodes.
### "%"           I added a percentage mode too, for example use 0.5 to resize to half.
###               You actually can read it as "how many times the original size"
### "PAR"         In the last update I added PAR. Find out what PAR your source is and input it here.
###               If you are thinking in crop + resize (anamorphic) and want to know what your PAR
###               changed to, then apply the formula below* and input it along your target dimensions (PreW,PreH)
### "adjust2w"    This new mode resizes height according to input width. So you input your target width size
###               as the ratio value, and target height will resize automatically according keeping image proportions.
### "adjust2h"    Same as above, but here you constrain to the target height instead.
###
### PreW,PreH  Substitutes resizing previously.
###
### Mod        Defines what mod you want to conform to for output (calculated values); mod2, mod4, mod8...  (input stays the same if defined)
###
### Kernel     Define the kernel (resizer algo) you want to use: nnedi3, spline36, spline64, bicubic, lanczos, etc
###
### b, c       These are the supplementary parameters for BicubicResize, so you can do Catmull-Rom, Robidoux, etc
###
### NOTE:      ALWAYS USE FLOAT VALUES 0.9, 1.33, 4/3.0, 16/9.0, etc
###
###
### *NOTE for "PAR":
###
### ((source.croppedRes)*(source.taggedPAR))/(target.Res)=new par
### i.e.
### ((706/478)*(4320/4739))/(720/480)=0.8975
###
###
### RatioResize(0.8975,"PAR",prew=720,preh=480)
###
###############################################################################

function RatioResize(clip s, float "ratio", string "mode", int "PreW", int "PreH", int "mod", string "kernel", float "b", float "c")
{
r     = default(ratio,      0.911)
mode  = default(mode,       "PAR")
mod   = default(mod,      isrgb(s) ? 1 : 2)
w     = default(PreW,  s.width ())
h     = default(PreH,  s.height())
kernel= default(kernel,"spline36")

Assert(isint(ratio)==false,   "'Ratio' must be a float number")
kernel!="bicubic" ? Assert(defined(b)==false,   "'b' and 'c' are BicubicResize only parameters") : nop()
kernel!="bicubic" ? Assert(defined(c)==false,   "'b' and 'c' are BicubicResize only parameters") : nop()

v  = (mode=="adjust2w")   ? h/(w/r)
\  : (mode=="adjust2h")   ? w/(h/r)
\  : (mode=="DAR")        ? w/(w/(h*r))
\  : (mode=="DARconform") ? w*(w/(h*r))
\  : (mode=="PAR"         \
   || mode=="%")          ? w*r : nop()
h1 = (mode=="%")          ? h*r : nop()

Vmod= round(v/mod)*mod

op = (mode=="DAR")
\ || (mode=="DARconform")
\ || (mode=="PAR")        ? kernel != "nnedi3" ? Apply(Kernel + "Resize",s,Vmod,h,b,c)                 : nnedi3_resize16(s,Vmod,h)
\  : (mode=="%")          ? kernel != "nnedi3" ? Apply(Kernel + "Resize",s,Vmod,round(h1/mod)*mod,b,c) : nnedi3_resize16(s,Vmod,round(h1/mod)*mod)
\  : (mode=="adjust2w")   ? kernel != "nnedi3" ? Apply(Kernel + "Resize",s,round(r),Vmod,b,c)          : nnedi3_resize16(s,round(r),Vmod)
\  : (mode=="adjust2h")   ? kernel != "nnedi3" ? Apply(Kernel + "Resize",s,Vmod,round(r),b,c)          : nnedi3_resize16(s,Vmod,round(r))
\  :  Assert(false, "Wrong Ratio mode")
return op}


##############################
### Write target size and image will crop or pad...
### depending on source dimensions by adding black borders.
###

function PadResize(clip c, int "width_dst", int "height_dst", bool "mirror", int "mod", int "color") {
    w = c.width()
    h = c.height()
    width_dst  = Default(width_dst, c.width())
    height_dst = Default(height_dst, c.height())
    color  = Default(color, $000000)
    mirror = Default(mirror, false)
    mod    = Default(mod, 2)
c

 X = width_dst-(width_dst%mod)-w
 Y = height_dst-(height_dst%mod)-h

 fh = abs(x/2.0)
 fv = abs(y/2.0)

 fh1 = frac(fh) == 0.0 ? int(fh) : int(floor(fh))
 fh2 = frac(fh) == 0.0 ? int(fh) : int(ceil(fh))
 fv1 = frac(fv) == 0.0 ? int(fv) : int(floor(fv))
 fv2 = frac(fv) == 0.0 ? int(fv) : int(ceil(fv))

 hsl = sign(x)>0 ? isRGB(c) ? fh1 : fh1-fh1%2 : 0
 vst = sign(y)>0 ? isRGB(c) ? fv1 : fv1+fv1%2 : 0
 hsr = sign(x)>0 ? isRGB(c) ? fh2 : fh2+fh2%2 : 0
 vsb = sign(y)>0 ? isRGB(c) ? fv2 : fv2-fv2%2 : 0

mirror ? PadMirror (hsl,vst,hsr,vsb)  :  \
         addborders(hsl,vst,hsr,vsb,color)

 hsl = sign(x)>0 ? 0 : isRGB(c) ? fh1 : fh1-fh1%2
 vst = sign(y)>0 ? 0 : isRGB(c) ? fv1 : fv1+fv1%2
 hsr = sign(x)>0 ? 0 : isRGB(c) ? fh2 : fh2+fh2%2
 vsb = sign(y)>0 ? 0 : isRGB(c) ? fv2 : fv2-fv2%2

crop(hsl,vst,-hsr,-vsb)
}



##############################
###
### Similar to addborders() but instead of a fixed color
### the clip borders are extended in a mirror way.
###
### Not exactly the same but nonetheless inspired
### by Didée's BorderMirror() (http://forum.doom9.org/showthread.php?p=518131#post518131)
###
###

function PadMirror(clip clp, int "left", int "top", int "right", int "bottom") {

l = default( abs(left),   0 )
t = default( abs(top),    0 )
r = default( abs(right),  0 )
b = default( abs(bottom), 0 )

clp

top=(t  > 0) ? crop(0,0,0,-height()+t).flipvertical()  : last
    (t  > 0) ? stackvertical( top,clp )                : last
bot=(b  > 0) ? crop(0,height()-b,0,0).flipvertical()   : last
    (b  > 0) ? stackvertical( last,bot )               : last
lft=(l  > 0) ? crop(0,0,-width()+l,0).fliphorizontal() : last
    (l  > 0) ? stackhorizontal(lft,last)               : last
rgh=(r  > 0) ? crop(width()-r,0,0,0).fliphorizontal()  : last
    (r  > 0) ? stackhorizontal(last,rgh)               : last }



##############################
### Automatic cropping and/or centering function.
### It works more like a recentering function when borders are asymmetrical or varying between shots.
### Which makes it easier to crop later after inspection (with width/height params) to the minimum or maximal found border.
###
###
### "Width/Height"     Destination width/height
### "thr"              Threshold, pixel values above this will be considered borders
### "CropMore"         In case of odd cropping, either crop 1 pixel out or leave 1 pixel of the border
### "ScanW/ScanH"      Range of pixels for scanning borders, set this to minimum to enhance performance
### "Moving"           If the matte is moving (sliding) it defaults to 1 pixel accuracy, among other settings (check defaults)
### "mode"             Mode of the function. 0: centers the frame within borders
###                                          1: crops to minimum found borders (Work in Progress)
###                                          2: resize bordered shots to destination width/height (Default)
### "Kernel"           Kernel to use for resizing
###
### i.e.
### MatteCrop(1920,1080,thr=16.0,cropmore=true,ScanW=90,ScanH=0,mode=2)
###
###############################################################################

function MatteCrop(clip c, int "width", int "height", float "thr", bool "CropMore", bool "Moving", int "ScanW", int "ScanH", int "mode", string "kernel") {

c
w      = width()
h      = height()

nw     = Default(width,w)
nh     = Default(height,h)
addw   = Default(ScanW,int(round((width()/5))))
addh   = Default(ScanH,int(round((height()/4))))
Mot    = Default(Moving, False)                 # If the matte is moving (sliding) this enables pixel level accuracy.
CM     = Default(CropMore, Mot ? True : False)  # In case of odd cropping, either crop 1 pixel out or leave 1 pixel of the border
thr    = Default(thr, Mot ? 16.3 : 16.0)        # Threshold, pixel values above this will be considered borders
mode   = Default(mode, 2)                       # 0: center+pad 1: crop to minimum (WIP) 2: resize to maximum
kernel = Default(kernel, "spline36")            # Kernel to use when resizing (mode=2)

sisphbd = AvsPlusVersionNumber > 2294
contoy = sisphbd ? !isy() : !isy8()

ScriptClip("""
contoy ? sisphbd ? converttoy() : converttoy8() : last

x1=0 x2=0
y1=0 y2=0

step = Mot ? 1 : 2

addw != 0 ? Eval("
for (li=step, addw, step) {
  if (AverageLuma(crop(li-step,0,-w+li,0))>thr) {
    x1= CM ? li : li-step
    li=addw
   }
}

for (ri=step, addw, step) {
  if (AverageLuma(crop(w-ri,0,-ri+step,0))>thr) {
    x2= CM ? ri : ri-step
    ri=addw
  }
}") : nop()


addh != 0 ? Eval("
for (ti=step, addh, step) {
  if (AverageLuma(crop(0,ti-step,0,-h+ti))>thr) {
    y1= CM ? ti : ti-step
    ti=addh
  }
}

for (bi=step, addh, step) {
  if (AverageLuma(crop(0,h-bi,0 ,-bi+step))>thr) {
    y2= CM ? bi : bi-step
    bi=addh
  }
}") : nop()


MotW = Mot ? round(w-x1-x2) : nop()
MotH = Mot ? round(h-y1-y2) : nop()

Mot ? spline36resize(c,MotW+MotW%2,MotH+MotH%2,src_left=x1,src_width=-x2,src_top=y1,src_height=-y2) : \
      crop(c,x1,y1,-x2,-y2)

mode == 0 ? padresize(w,h) : \
mode == 1 ? padresize(w,h) : \
            RatioResize(float(nw),"adjust2w", kernel=kernel).padresize(w,h)

""",args="c,nw,nh,addw,addh,w,h,thr,CM,sisphbd,contoy,mode,kernel,Mot",local=true)
padresize(nw,nh) }



##############################
### This is basically the same as Dither_addborders16() from the Dither tools package
### I only edited out a few lines to make it work on 8-bit inputs. All credit goes to cretindesalpes/firesledge
###
### Basically intact from original so I chose to keep the "Dither_" nomenclature
### yet wanted to give it some more repercussion and relevance, and more people
### that can make the most of it. It's a fantastic helper function for masking work.
###
### The main reason was to use the whole PC range colors, otherwise impossible with original addborders.
### for PC level black & white use $008080 and $ff8080 respectively

Function Dither_addborders8 (clip src, int "left", int "top",
\   int "right", int "bottom", int "color_yuv", int "color")
{
    left      = Default (left,            0)
    top       = Default (top,             0)
    right     = Default (right,           0)
    bottom    = Default (bottom,          0)

    Assert ((left >= 0 && top >= 0 && right >= 0 && bottom >= 0),
\       "Dither_addborders16: borders must be positive.")

    subspl_h = src.Dither_get_chroma_subspl_h ()
    subspl_v = src.Dither_get_chroma_subspl_v ()
    err_str  =   "Dither_addborders16: borders must be" + chr (10)
\          + "multiple of the chroma subsampling."
    Assert (((left   % subspl_h) == 0), err_str)
    Assert (((top    % subspl_v) == 0), err_str)
    Assert (((right  % subspl_h) == 0), err_str)
    Assert (((bottom % subspl_v) == 0), err_str)

    vers = VersionNumber ()
    p_t  =   (src.IsRGB24 ()) ? "RGB24"
\          : (src.IsRGB32 ()) ? "RGB32"
\          : (src.IsYUY2 ())  ? "YUY2"
\          : (vers < 2.60   ) ? "YV12"
\          :                    Dither_undef ()

    cx_yuv   = (src.IsRGB ()) ? Dither_undef () : Defined (color) ? Undefined() : Default (color_yuv, $008080)
    cx       = (src.IsRGB ()) ? Default (color, color_yuv) : Defined (color_yuv) ? Undefined() : Default (color, $000000)

    src
    (left   > 0) ? StackHorizontal (BlankClip (last, width=left, pixel_type=p_t, color_yuv=cx_yuv, color=cx), last)  : last
    (right  > 0) ? StackHorizontal (last, BlankClip (last, width=right, pixel_type=p_t, color_yuv=cx_yuv, color=cx)) : last
    (top    > 0) ? StackVertical (BlankClip (last, height=top, pixel_type=p_t, color_yuv=cx_yuv, color=cx), last)    : last
    (bottom > 0) ? StackVertical (last, BlankClip (last, height=bottom, pixel_type=p_t, color_yuv=cx_yuv, color=cx)) : last
}

########################
### Resizer which gets the best from 2 worlds: The "sharpness" of spline64 and the "ringing-free" catmull-rom
### biased by a threshold. Slightly mod from javlak's function http://forum.doom9.org/showthread.php?p=1504678#post1504678

function SpliceResize(clip v, int "w", int "h", int "threshold"){
    threshold = default (threshold, 8)
    w=default(w, width(v))
    h=default(h, height(v))
    mt_lutxy(BicubicResize(v, w, h,0.0,0.5),Spline64Resize(v, w, h),"x y - abs "+string(threshold)+" > y x ?")}