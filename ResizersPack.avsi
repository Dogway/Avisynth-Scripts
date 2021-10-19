###                                                 ##
###                                                 ##
###                           1.0    (17-11-2011)   ##
###                           4.5    (21-09-2015)   ##
###                           4.6    (06-03-2019)   ##
###                           4.7.1  (01-04-2021)   ## -> Finally fixed PadResize() (for real), added nnedi3 to RatioResize, added automatic dynamic cropping function: MatteCrop()
###                           4.8.3  (20-05-2021)   ## -> Updated MatteCrop(), Ratioresize() and PadResize() and Overall improvements
###                           5.0    (20-07-2021)   ## -> Removed legacy functions SpliceResize, Dither_addborders8 and LinearResize (superseeded by ConvertFormat)
###                           5.1    (09-09-2021)   ## -> Maintenance update
###   Resizers Functions Pack 6.1    (18-10-2021)   ## -> mmod() and nmod() functions. Replace PadMirror() with PadBorders(). Optimize MatteCrop()
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

    Vmod= nmod(v,mod)

    op = (mode=="DAR")
    \ || (mode=="DARconform")
    \ || (mode=="PAR")        ? "Vmod,h"
    \  : (mode=="%")          ? "Vmod,nmod(h1,mod)"
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
### depending on source dimensions by adding black borders, mirroring borders or extending them depending on 'mode'.
###
### bias:  From -100 to +100, to slide the frame within the resolution (ie. an asymmetrical matte)
###
### *Color mode has two ways for inputs, the classical PC range based hexadecimal (see link below) or an alternative more intuitive way
###  by using an int array as string. For example for YUV TV Black you can input "$108080" or "[16,128,128]". Both modes are valid.
###
function PadResize(clip c, int "width_dst", int "height_dst", int "mod", string "mode", float "biasW", float "biasH") {

    c
    rgb = isRGB()
    w   = width()
    h   = height()

    width_dst  = Default(width_dst, w)
    height_dst = Default(height_dst, h)
    bw     = Default(biasW, 0.)
    bh     = Default(biasH, 0.)
    md     = Default(mode, rgb?"$000000":"$108080") # 'Dilate', 'Mirror' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)
    mod    = Default(mod, 2)
	md     = LeftStr(md,1)=="[" ? ColortoHex(md) : md

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

    LeftStr(md,1)!="$" ? PadBorders(hsl+bw1,vst+bh1,hsr+bw2,vsb+bh2,md)     : \
                         AddBorders(hsl+bw1,vst+bh1,hsr+bw2,vsb+bh2,color_yuv = Eval(md))

    hsl = sign(x)>0 ? 0 : fullchr && mod == 1 ? fh1 : fh1-fh1%mod
    vst = sign(y)>0 ? 0 : fullchr && mod == 1 ? fv1 : fv1+fv1%mod
    hsr = sign(x)>0 ? 0 : fullchr && mod == 1 ? fh2 : fh2+fh2%mod
    vsb = sign(y)>0 ? 0 : fullchr && mod == 1 ? fv2 : fv2-fv2%mod

    Crop(hsl+bw2,vst+bh2,-hsr-bw1,-vsb-bh1,true) }



##############################
###
### PadBorders()
###
### Superseeds Addborders(), old PadMirror() and Didée's Padding() (21-10-2012) (https://forum.doom9.org/showthread.php?p=1596804#post1596804)
### in one single filter.
### In other words, with "mode" option you can dilate (extend), mirror, or add colored borders (http://avisynth.nl/index.php/Color_presets).
###
### 'Dilate' is slightly faster than 'Mirror' (and probably filter friendlier)
###  Old PadMirror() itself was inspired by Didée's BorderMirror() (30-06-2004) (http://forum.doom9.org/showthread.php?p=518131#post518131)
###
### *Color mode has two ways for inputs, the classical PC range based hexadecimal (see link above) or an alternative more intuitive way
###  by using an int array as string. For example for YUV TV Black you can input "$108080" or "[16,128,128]". Both modes are valid.
###
function PadBorders(clip src, int "left", int "top", int "right", int "bottom", string "mode") {

    rgb = isRGB(src)
    isy = isy(src)

    l  = Default( abs(left),   0 )
    t  = Default( abs(top),    0 )
    r  = Default( abs(right),  0 )
    b  = Default( abs(bottom), 0 )
    md = Default( mode, "Dilate" )  # 'Dilate', 'Mirror' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)


	md = LeftStr(md,1)=="[" ? ColortoHex(md) : md

    l  = !rgb && !isy ? nmod(l,2) : l
    t  = !rgb && !isy ? nmod(t,2) : t
    r  = !rgb && !isy ? nmod(r,2) : r
    b  = !rgb && !isy ? nmod(b,2) : b

    src

    if (md=="mirror") {

        top=(t  > 0) ? crop(0,0,0,-height()+t,true).flipvertical()  : last
            (t  > 0) ? stackvertical( top,src )                : last
        bot=(b  > 0) ? crop(0,height()-b,0,0,true).flipvertical()   : last
            (b  > 0) ? stackvertical( last,bot )               : last
        lft=(l  > 0) ? crop(0,0,-width()+l,0,true).fliphorizontal() : last
            (l  > 0) ? stackhorizontal(lft,last)               : last
        rgh=(r  > 0) ? crop(width()-r,0,0,0,true).fliphorizontal()  : last
            (r  > 0) ? stackhorizontal(last,rgh)               : last

    } else if (md=="dilate") {

        w   = width()
        h   = height()
        PointResize(w+l+r, h+t+b, -l, -t, w+l+r, h+t+b+0.0001)

    } else if (LeftStr(md,1)=="$") {

        rgb ? AddBorders(l,t,r,b, Eval(md))           : \
              AddBorders(l,t,r,b, color_yuv = Eval(md))

    } else {

        Assert(false, "Wrong Pad mode")

    } }




##############################
### Adjust source to mod(n) size by adding or cropping borders. by Gavino
### From this thread: http://forum.doom9.org/showthread.php?p=1453641#post1453641
function mmod(clip c, int "modH", int "modV", string "mode", string "color")
{
    modH = Default(modH,        16)
    modV = Default(modV,      modH)
    mode = Default(mode,    "crop")      # "crop" or "add"
    clr  = Default(color,"$108080")
    bh = modH - ((c.Width() -1)%modH + 1)
    bv = modV - ((c.Height()-1)%modV + 1)

	clr = LeftStr(clr,1)=="[" ? ColortoHex(clr) : clr

    l = bh/2
       l = c.IsYUV() && l%2 != 0 ? l-1 : l
    r = bh - l
    t = bv/2
       t = c.IsYV12() && t%2 != 0 ? t-1 : t
    b = bv - t
    (mode=="Add")  ? c.AddBorders(l,t,r,b,color_yuv=Eval(clr)) : \
    (mode=="Crop") ? c.Crop      (l,t,-r,-b)         : \
                     Assert(false, "Wrong mode")     }


###
#
#  nmod() - Rounding numbers by Dogway (18-10-2021)
#
#  Description from SmoothD2c:
#
# "mod-4"   see "Crop restrictions" in http://avisynth.org/mediawiki/Crop
#           nmod(n,4) is used in many scripts that do resizing.
# "mod-8"   is used so that cropping will occur on luma block (8x8) boundaries
#           and that resizing will produce an integer number of luma blocks.
# "mod-16"  is used so that cropping will occur on YV12 chroma block (16x16) boundaries
#           and that resizing will produce an integer number of chroma blocks.
# "mod-m32" is used so that the zw1 mask can be resized to the size of the u and v planes.

function  nmod(float n, int "mod", int "min", bool "bankers") {

    mod = Default(mod, 2)
    bnk = Default(bankers, false)    # Use bankers' rounding. Requires SimilarityMetrics
    dm  = Defined(min)               # Set 'min' to 16 for at-least n=16
    un  = Undefined()

    return ( dm && nmod(n,mod,un,bnk) < max(mod,min) ? max(mod,min)                  : \
              bnk && mod!=1                          ? RoundHalfToEven_mod(n, mod)   : \
                                                       round( float(n) / mod ) * mod ) }



# Converts a "stringed" color array into an hexadecimal string
# "[16,128,128]" -> "$108080"
function ColortoHex(string color) {
    cl = Eval(Color)
    Return "$"+string(Hex(cl[0],2))+string(Hex(cl[1],2))+string(Hex(cl[2],2)) }




##############################
###
### MatteCrop() - by Dogway (15-10-2021)
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
###   ClipBoard          (http://avisynth.nl/index.php/ClipBoard)
###   SCSelect_HBD v0.02 (https://github.com/Dogway/Avisynth-Scripts/tree/master/EX%20mods)
###   MasksPack          (https://github.com/Dogway/Avisynth-Scripts)
###   EdgeFixer          (http://avisynth.nl/index.php/EdgeFixer)
###
###
### i.e.
### MatteCrop(1920,1080,thr=16.0,cropmore=true,ScanW=90,ScanH=0,mode=2)
###
###############################################################################

function MatteCrop(clip s, int "width", int "height", float "thr", bool "CropMore", bool "Moving", int "ScanW", int "ScanH", int "mode", float "SC_thr", string "kernel", float "b", float "c", float "p", bool "fulls") {

    s
    w      = width()
    h      = height()

    isy     = isy()
    fullchr = !isy ? ExtractU().width() == w : true

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
    fs     = Default(fulls, false)
    bi     = BitsPerComponent(s)

    addw==0 ? Assert( addh>0, "You need to scan borders for at least one of the dimension") : nop()
    addh==0 ? Assert( addw>0, "You need to scan borders for at least one of the dimension") : nop()

    thr    = ex_bs(thr, 8, bi, fulls=fs)
    addwz  = addw > 0
    addhz  = addh > 0

    avgY = !isy ? ExtractY().ConvertBits(8,dither=-1,fulls=fs) : ConvertBits(8,dither=-1,fulls=fs)
    avg  = avgY.RatioResize(320.0,  "adjust2w",kernel="bilinear")
    avg  = avg.TemporalSoften(10,255,255,10,2)
    avg  = avg.TemporalSoften(10,255,255,10,2)
    avg  = avg.RatioResize(float(w),"adjust2w",kernel="bicubic")

    avgc = ex_merge(avgY, avg, BoxMask(s,addw,w-addw,addh,h-addh,show=true)).ConvertBits(bi,dither=-1,fulls=fs)

    SC   = SCSelect_HBD(avg,dfactor=SC_thr,mindif=1.0)

    # Add detection of credits and bumpers
    ScriptClip(s, function [s,SC,avgc,addw,addh,addwz,addhz,w,h,thr,CM,Mot,fullchr,kernel,b,c,p,mode] () {

        step  = Mot ? 1 : 2

        mode==3 ? Eval("
        LBox = YPlaneMax(crop( addhz ? width()-16 : 0,0,0, addwz ? -height()+16 : 0, true)) <= float(thr)
        CM   = LBox
        ") : nop()

    if (propGetInt(SC,"_SceneChangePrev") == 1) {

        x1=0 x2=0
        y1=0 y2=0

        trim(avgc, current_frame+10, -1)

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

        ClipBoard_PutText(String(Format("x1={x1}  x2={x2}  y1={y1}  y2={y2}  ")))
        }


        cbs = ClipBoard_GetText()
        x1  = Eval(MidStr(cbs,FindStr(cbs,"x1=")+3,3))
        x2  = Eval(MidStr(cbs,FindStr(cbs,"x2=")+3,3))
        y1  = Eval(MidStr(cbs,FindStr(cbs,"y1=")+3,3))
        y2  = Eval(MidStr(cbs,FindStr(cbs,"y2=")+3,3))

        MotW = Mot ? round(w-x1-x2) : nop()
        MotH = Mot ? round(h-y1-y2) : nop()
        Mot ? spline36resize(s,fullchr?MotW:nmod(MotW,2),fullchr?MotH:nmod(MotH,2),src_left=x1,src_width=-x2,src_top=y1,src_height=-y2) : \
              crop(s,x1,y1,-x2,-y2,true)

        mode == 0 ? PadResize(w,h) : \
        mode == 1 ? PadResize(w,h) : \
        mode == 2 ? RatioResize(float(w),"adjust2w", kernel=kernel, b=b, c=c, p=p).PadResize(w,h) : \
                    LBox ? \
                    RatioResize(float(w),"adjust2w", kernel=kernel, b=b, c=c, p=p).PadResize(w,h) : PadResize(w,h)
    } )

    mode == 0 ? PadResize(nw,nh) : \
    mode == 1 ? PadResize(nw,nh) : \
                kernel == "nnedi3" ? Eval( "nnedi3_resize16(" + String(nw) + "," + String(nh) + ")")     : \
                kernel == "gauss"  ? Eval(     "GaussResize(" + String(nw) + "," + String(nh) + ",p=p)") : \
                kernel == "bicubic"? Eval(   "BicubicResize(" + String(nw) + "," + String(nh) + ",b,c)") : \
                                     Eval( kernel + "Resize(" + String(nw) + "," + String(nh) + ")")


    (!CM || Mot) && mode>1 ? ContinuityFixer(left=addwz?2:0, top=addhz?2:0, right=addwz?2:0, bottom=addhz?2:0, radius=CM && w>720?0:1) : last }
