###                                                 ##
###                                                 ##
###                           4.5    (21-09-2015)   ##
###                           4.6    (06-03-2019)   ##
###                           4.7.1  (01-04-2021)   ## -> Finally fixed PadResize() (for real), added nnedi3 to RatioResize, added automatic dynamic cropping function: MatteCrop()
###   Resizers Functions Pack 4.8.3  (20-05-2021)   ## -> Updated MatteCrop(), Ratioresize() and PadResize() and Overall improvements
###   Resizers Functions Pack 5.0    (20-07-2021)   ## -> Removed legacy functions SpliceResize, Dither_addborders8 and LinearResize (superseeded by ConvertFormat)
###   Resizers Functions Pack 5.1    (09-09-2021)   ## -> Maintenance update
###                                                 ##
###                      by Dogway (Jose Linares)   ##
###                                                 ##
### https://forum.doom9.org/showthread.php?t=182881 ##
###                                                 ##
######################################################



##############################
###
### RatioResize()
###
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


function RatioResize(clip s, float "ratio", string "mode", int "PreW", int "PreH", int "mod", string "kernel", float "b", float "c", float "p") {

    r     = Default(ratio,      0.5)
    mode  = Default(mode,       "%")
    mod   = Default(mod,      isrgb(s) ? 1 : 2)
    w     = Default(PreW,  s.width ())
    h     = Default(PreH,  s.height())
    kernel= Default(kernel,"spline36")

    r = float(r)

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
    \ || (mode=="PAR")        ? "Vmod,h"
    \  : (mode=="%")          ? "Vmod,round(h1/mod)*mod"
    \  : (mode=="adjust2w")   ? "round(r),Vmod"
    \  : (mode=="adjust2h")   ? "Vmod,round(r)"
    \  :  Assert(false, "Wrong Ratio mode")


    kernel == "nnedi3" ? Eval("nnedi3_resize16(s," + String(op) + ")"    ) : \
    kernel == "gauss"  ? Eval(    "GaussResize(s," + String(op) + ",p=p)") : \
    kernel == "bicubic"? Eval(  "BicubicResize(s," + String(op) + ",b,c)") : \
                         Eval(kernel + "Resize(s," + String(op) + ")"    )
}

##############################
###
### PadResize()
###
### Write target size and image will crop or pad...
### depending on source dimensions by adding black borders or a mirror border.
###
### bias:  From -100 to +100, to slide the frame within the resolution (ie. an asymmetrical matte)
###

function PadResize(clip c, int "width_dst", int "height_dst", float "biasW", float "biasH", bool "mirror", int "mod", int "color") {

    c
    w = width()
    h = height()

    width_dst  = Default(width_dst, w)
    height_dst = Default(height_dst, h)
    bw     = Default(biasW, 0.)
    bh     = Default(biasH, 0.)
    color  = Default(color, $000000)
    mirror = Default(mirror, false)
    mod    = Default(mod, 2)

    fullchr = isy() ? true : isRGB(c) || ExtractU().width() == w

    X = width_dst-w
    Y = height_dst-h

    bw = bw>0 ? min(bw,100.) : max(bw,-100.)
    bh = bh>0 ? min(bh,100.) : max(bh,-100.)
    bw = (bw+100.)/200.
    bh = (bh+100.)/200.

    bw1 = int(round(w*bw))  bw2 = int(round(w*(1.-bw)))
    bh1 = int(round(h*bh))  bh2 = int(round(h*(1.-bh)))

    bw1 = fullchr ? bw1 : bw1+bw1%2  bw2 = fullchr ? bw2 : bw2-bw2%2
    bh1 = fullchr ? bh1 : bh1+bh1%2  bh2 = fullchr ? bh2 : bh2-bh2%2


    fh = abs(x/2.0)         fv = abs(y/2.0)

    fh1 = int(floor(fh))    fh2 = int(ceil(fh))
    fv1 = int(floor(fv))    fv2 = int(ceil(fv))

    hsl = sign(x)>0 ? fullchr && mod == 1 ? fh1 : fh1-fh1%mod : 0
    vst = sign(y)>0 ? fullchr && mod == 1 ? fv1 : fv1+fv1%mod : 0
    hsr = sign(x)>0 ? fullchr && mod == 1 ? fh2 : fh2+fh2%mod : 0
    vsb = sign(y)>0 ? fullchr && mod == 1 ? fv2 : fv2-fv2%mod : 0

    mirror ? PadMirror (hsl+bw1,vst+bh1,hsr+bw2,vsb+bh2)  :  \
             addborders(hsl+bw1,vst+bh1,hsr+bw2,vsb+bh2,color)

    hsl = sign(x)>0 ? 0 : fullchr && mod == 1 ? fh1 : fh1-fh1%mod
    vst = sign(y)>0 ? 0 : fullchr && mod == 1 ? fv1 : fv1+fv1%mod
    hsr = sign(x)>0 ? 0 : fullchr && mod == 1 ? fh2 : fh2+fh2%mod
    vsb = sign(y)>0 ? 0 : fullchr && mod == 1 ? fv2 : fv2-fv2%mod

    crop(hsl+bw2,vst+bh2,-hsr-bw1,-vsb-bh1,true) }



##############################
###
### PadMirror()
###
### Similar to addborders() but instead of a fixed color
### the clip borders are extended in a mirror way.
###
### Not exactly the same but nonetheless inspired
### by Didée's BorderMirror() (http://forum.doom9.org/showthread.php?p=518131#post518131)
###
###

# Padding() by Didée (https://forum.doom9.org/showthread.php?p=1596804#post1596804)
# ... is slightly faster although it doesn't mirror but extend the borders.
function PadMirror(clip clp, int "left", int "top", int "right", int "bottom") {

l = Default( abs(left),   0 )
t = Default( abs(top),    0 )
r = Default( abs(right),  0 )
b = Default( abs(bottom), 0 )

clp

top=(t  > 0) ? crop(0,0,0,-height()+t,true).flipvertical()  : last
    (t  > 0) ? stackvertical( top,clp )                : last
bot=(b  > 0) ? crop(0,height()-b,0,0,true).flipvertical()   : last
    (b  > 0) ? stackvertical( last,bot )               : last
lft=(l  > 0) ? crop(0,0,-width()+l,0,true).fliphorizontal() : last
    (l  > 0) ? stackhorizontal(lft,last)               : last
rgh=(r  > 0) ? crop(width()-r,0,0,0,true).fliphorizontal()  : last
    (r  > 0) ? stackhorizontal(last,rgh)               : last }



##############################
###
### MatteCrop()
###
### https://forum.doom9.org/showthread.php?t=182678
###
### Automatic cropping and/or centering function.
### It works more like a recentering function when borders are asymmetrical or varying between shots.
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
###                                          3: hybrid, automatic method between method 0 and 2
### "Kernel"           Kernel to use for resizing
###
###
### Dependencies:
### ------------
###   ExTools
###   EdgeFixer      (http://avisynth.nl/index.php/EdgeFixer)
###   SCSelect_HBD   (https://forum.doom9.org/showthread.php?t=182392)
###   MasksPack      (https://github.com/Dogway/Avisynth-Scripts)
###   Utils-r41      (http://avisynth.nl/images/Utils-r41.avsi)
###
###
### i.e.
### MatteCrop(1920,1080,thr=16.0,cropmore=true,ScanW=90,ScanH=0,mode=2)
###
###############################################################################

function MatteCrop(clip s, int "width", int "height", float "thr", bool "CropMore", bool "Moving", int "ScanW", int "ScanH", int "mode", float "SC_thr", string "kernel", float "b", float "c", float "p") {

s
w      = width()
h      = height()

contoy  = !isy()
fullchr = contoy ? ExtractU().width() == w : true

nw     = Default(width, w)
nh     = Default(height,h)
addw   = Default(ScanW,round((w/8.)))
addh   = Default(ScanH,round((h/4.)))
Mot    = Default(Moving, False)                # If the matte is moving (sliding) this enables pixel level accuracy.
CM     = Default(CropMore, Mot || fullchr)     # In case of odd cropping, either crop 1 pixel out or leave 1 pixel of the border
thr    = Default(thr, Mot ? 16.3 : 16.0)       # Threshold, pixel values same or below this will be considered borders
mode   = Default(mode, 2)                      # 0: center+pad 1: crop to minimum (WIP) 2: resize to maximum 3: hybrid 0-2 (auto)
SC_thr = Default(SC_thr, 3.5)                  # Scene Change detection threshold
kernel = Default(kernel, "bicubic")            # Kernel to use when resizing (mode=2)
b      = Default(b, 0.0)
c      = Default(c, 0.75)                      # Precise Bicubic by default (fast and HQ)
p      = Default(p, 100.0)

addw==0 ? Assert( addh>0, "You need to scan borders for at least one of the dimension") : nop()
addh==0 ? Assert( addw>0, "You need to scan borders for at least one of the dimension") : nop()

thr    = ex_bs(thr, 8, bi, fulls=fs)
addwz  = addw > 0
addhz  = addh > 0

avgY = contoy ? ExtractY() : last
avg  = avgY.RatioResize(320.0,  "adjust2w",kernel="bilinear")
avg  = avg.TemporalSoften(10,255,255,10,2)
avg  = avg.TemporalSoften(10,255,255,10,2)
avg  = avg.RatioResize(float(w),"adjust2w",kernel="bicubic")

avgc = ex_merge(avgY, avg, BoxMask(s,addw,w-addw,addh,h-addh,show=true))

blk_b  = s.blankclip(width=16,height=16,pixel_type="Y8",fps=framerate(s),color=$000000).killaudio()
blk_w  = s.blankclip(width=16,height=16,pixel_type="Y8",fps=framerate(s),color=$FFFFFF).killaudio()
SC     = SCSelect_HBD(avg,blk_w,blk_b,blk_b,dfactor=SC_thr,mindif=1.0)

# Add detection of credits and bumpers
ScriptClip("""

step  = Mot ? 1 : 2
LBF   = current_frame
x1=0 x2=0
y1=0 y2=0

# 1440 frames -1 min on 24fps- lookback
YPlaneMax(SC)<128 ? Eval("
for (LB=0, 1440, 1) {
  if (YPlaneMax(trim(SC,current_frame-LB,-1))>128 || LB==1440) {
    LBF=current_frame-LB
    LB=1440
   }
}") : nop()


trim(avgc,LBF+10,-1)


mode==3 ? Eval("
LBox = YPlaneMax(crop( addhz ? width()-16 : 0,0,0, addwz ? -height()+16 : 0, true)) <= float(thr)
CM   = LBox
") : nop()

addwz ? Eval("
for (li=step, addw, step) {
  if (AverageLuma(crop(li-step,0,-w+li,0,true))>thr) {
    x1= CM ? li : li-step
    li=addw
   }
}

for (ri=step, addw, step) {
  if (AverageLuma(crop(w-ri,0,-ri+step,0,true))>thr) {
    x2= CM ? ri : ri-step
    ri=addw
  }
}") : nop()


addhz ? Eval("
for (ti=step, addh, step) {
  if (AverageLuma(crop(0,ti-step,0,-h+ti,true))>thr) {
    y1= CM ? ti : ti-step
    ti=addh
  }
}

for (bi=step, addh, step) {
  if (AverageLuma(crop(0,h-bi,0 ,-bi+step,true))>thr) {
    y2= CM ? bi : bi-step
    bi=addh
  }
}") : nop()


MotW = Mot ? round(w-x1-x2) : nop()
MotH = Mot ? round(h-y1-y2) : nop()
Mot ? spline36resize(s,fullchr?MotW:MotW+MotW%2,fullchr?MotH:MotH+MotH%2,src_left=x1,src_width=-x2,src_top=y1,src_height=-y2) : \
      crop(s,x1,y1,-x2,-y2,true)

mode == 0 ? PadResize(w,h) : \
mode == 1 ? PadResize(w,h) : \
mode == 2 ? RatioResize(float(w),"adjust2w", kernel=kernel, b=b, c=c, p=p).PadResize(w,h,mirror=false) : \
            LBox ? \
            RatioResize(float(w),"adjust2w", kernel=kernel, b=b, c=c, p=p).PadResize(w,h,mirror=false) : PadResize(w,h)


""",args="s,SC,avgc,addw,addh,addwz,addhz,w,h,thr,CM,Mot,fullchr,kernel,b,c,p,mode",local=true)


mode == 0 ? PadResize(nw,nh) : \
mode == 1 ? PadResize(nw,nh) : \
            kernel == "nnedi3" ? Eval( "nnedi3_resize16(" + String(nw) + "," + String(nh) + ")")     : \
            kernel == "gauss"  ? Eval(     "GaussResize(" + String(nw) + "," + String(nh) + ",p=p)") : \
            kernel == "bicubic"? Eval(   "BicubicResize(" + String(nw) + "," + String(nh) + ",b,c)") : \
                                 Eval( kernel + "Resize(" + String(nw) + "," + String(nh) + ")")


(!CM || Mot) && mode>1 ? ContinuityFixer(left=addwz?2:0, top=addhz?2:0, right=addwz?2:0, bottom=addhz?2:0, radius=CM && w>720?0:1) : last }
