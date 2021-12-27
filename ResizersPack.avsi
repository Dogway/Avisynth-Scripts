######################################################
###                                                 ##
###                                                 ##
###   Resizers Functions Pack 7.1    (14-12-2021)   ##
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

    rgb   = isrgb(s)
    r     = Default(ratio,      0.5)
    mode  = Default(mode,       "%")
    mod   = Default(mod, rgb ? 1 : 2)
    w     = Default(PreW,  s.width ())
    h     = Default(PreH,  s.height())
    kernel= Default(kernel,"spline36")

    r  = float(r)

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
    \  :  Assert(false, "RatioResize: Wrong Ratio mode")


    kernel == "nnedi3" ? Eval("nnedi3_resize16(s," + String(op) + ")"    ) : \
    kernel == "gauss"  ? Eval(    "GaussResize(s," + String(op) + ",p=p)") : \
    kernel == "bicubic"? Eval(  "BicubicResize(s," + String(op) + ",b,c)") : \
                         Eval(kernel + "Resize(s," + String(op) + ")"    ) }



##############################
###
### PadResize()
###
### Write target size and image will crop or pad...
### depending on source dimensions by adding black borders, mirroring borders or extending them depending on 'mode'.
###
### bias:  From -width() to +width(), to slide the frame within the resolution (ie. an asymmetrical matte)
###
### *Color mode has two ways for inputs, the classical PC range based hexadecimal (see link below) or an alternative more intuitive way
###  by using an int array as string. For example for YUV TV Black you can input "$108080" or "[16,128,128]". Both modes are valid.
###
function PadResize(clip c, int "width", int "height", int "mod", string "mode", int "biasW", int "biasH") {

    c
    rgb = isRGB()
    w   = width()
    h   = height()
    fch = isy() || rgb || is444()

    wd     = Default(width,  w)
    hd     = Default(height, h)
    mod    = Default(mod,    fch ? 1 : 2)
    bw     = Default(biasW,  0)
    bh     = Default(biasH,  0)
    # mode: 'Dilate', 'Mirror' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)

    wm = nmod(wd,mod)
    hm = nmod(hd,mod)

    # Crop or Pad
    wc = wm > w
    hc = hm > h

    # Rounding
    wp = abs(w - wm)/2.  wi = round(wp)%2
    hp = abs(h - hm)/2.  hi = round(hp)%2
    wh = ceil (Frac(wp))+floor(wp)
    hh = ceil (Frac(hp))+floor(hp)
    wl = floor(Frac(wp))+floor(wp)
    hl = floor(Frac(hp))+floor(hp)

    # Zeroing null transforms
    wc1 = !wc ?  wh+wi : 0    wa1 =  wc ? wh+wi : 0
    wc2 = !wc ? -wl+wi : 0    wa2 =  wc ? wl-wi : 0
    hc1 = !hc ?  hh+hi : 0    ha1 =  hc ? hh+hi : 0
    hc2 = !hc ? -hl+hi : 0    ha2 =  hc ? hl-hi : 0

    bwa = abs (bw)
    bha = abs (bh)
    bw1 = sign(bw)<0 ? 0 : fch ? bwa : bwa+bwa%2
    bw2 = sign(bw)>0 ? 0 : fch ? bwa : bwa-bwa%2
    bh1 = sign(bh)<0 ? 0 : fch ? bha : bha+bha%2
    bh2 = sign(bh)>0 ? 0 : fch ? bha : bha-bha%2

    PadBorders(wa1+bw1,ha1+bh1,wa2+bw2,ha2+bh2,mode)
    Crop      (wc1+bw2,hc1+bh2,wc2-bw1,hc2-bh1,true) }



##############################
###
### PadBorders()
###
### Superseeds AddBorders(), old PadMirror() and Didée's Padding() (21-10-2012) (https://forum.doom9.org/showthread.php?p=1596804#post1596804)
### in one single filter.
### In other words, with "mode" option you can dilate (extend), mirror, or add colored borders (https://avisynth.nl/index.php/Color_presets).
###
### 'Dilate' is slightly faster than 'Mirror' (and probably filtering friendlier)
###  Old PadMirror() itself was inspired by Didée's BorderMirror() (30-06-2004) (https://forum.doom9.org/showthread.php?p=518131#post518131)
###
### *Color mode has two ways for inputs, the classical PC range based hexadecimal (see link above) or an alternative more intuitive way
###  by using an int array as string. For example for YUV TV Black you can input "$108080" or "[16,128,128]". Both modes are valid.
###
function PadBorders(clip src, int "left", int "top", int "right", int "bottom", string "mode") {

    src
    w   = width()
    h   = height()
    rgb = isRGB()
    isy = isy()
    fch = isy || rgb || is444()
    mod = fch ? 1 : 2
    fs  = propNumElements ("_ColorRange")  > 0 ? \
          propGetInt      ("_ColorRange") == 0 : rgb

    l  = Default( left,   0 )
    t  = Default( top,    0 )
    r  = Default( right,  0 )
    b  = Default( bottom, 0 )
    md = Default( mode, !rgb ? fs ? "$008080" : "$108080" : \
                               fs ? "$000000" : "$101010" )  # 'Dilate', 'Mirror' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)

    md = LeftStr(md,1)=="[" ? ColortoHex(md) : md

    l  = nmod(abs(l),mod)
    t  = nmod(abs(t),mod)
    r  = nmod(abs(r),mod)
    b  = nmod(abs(b),mod)

    if (md=="mirror") {

        top=(t  > 0) ? crop(0,0,0,-h+t,      true).flipvertical()   : last
            (t  > 0) ? stackvertical( top,src )                : last
        bot=(b  > 0) ? crop(0,height()-b,0,0,true).flipvertical()   : last
            (b  > 0) ? stackvertical( last,bot )               : last
        lft=(l  > 0) ? crop(0,0,-width()+l,0,true).fliphorizontal() : last
            (l  > 0) ? stackhorizontal(lft,last)               : last
        rgh=(r  > 0) ? crop(width()-r,0,0,0, true).fliphorizontal() : last
            (r  > 0) ? stackhorizontal(last,rgh)               : last

    } else if (md=="dilate") {

        PointResize(w+l+r, h+t+b, -l, -t, w+l+r, h+t+b+0.0001)

    } else if (LeftStr(md,1)=="$") {

        rgb ? AddBorders(l,t,r,b,             Eval(md)) : \
              AddBorders(l,t,r,b, color_yuv = Eval(md))

    } else {

        Assert(false, "PadBorders: Wrong Pad mode")

    } }




###
#
#  nmod() - Rounding numbers by Dogway (28-11-2021)
#
#  Description from SmoothD2c:
#
# "mod-4"   see "Crop restrictions" in https://avisynth.nl/index.php/Crop
#           nmod(n,4) is used in many scripts that do resizing.
# "mod-8"   is used so that cropping will occur on luma block (8x8) boundaries
#           and that resizing will produce an integer number of luma blocks.
# "mod-16"  is used so that cropping will occur on YV12 chroma block (16x16) boundaries
#           and that resizing will produce an integer number of chroma blocks.
# "mod-m32" is used so that the zw1 mask can be resized to the size of the u and v planes.
#
# mod:     Rounding to defined 'mod' value
# min:     Rounding never goes below the 'min' value. Usually you want to set this to mod*2
# dec:     Rounding to defined decimal number. Also works for mod > 1 (rounding is done prior to mod)
# bankers: By default 2.5 rounds to 3. With 'bankers' half float values round towards 0, so 2 in this case
#
# Examples:
#   nmod(3)                    -> 4
#   nmod(2,4)                  -> 4
#   nmod(2,4,    bankers=true) -> 0
#   nmod(2,4,1,  bankers=true) -> 4
#   nmod(2,4,4.1,bankers=true) -> 4.1
#   nmod(pi, dec=2)            -> 3.14
#
function nmod(val n, int "mod", val "min", int "dec", bool "bankers") {

    dm  = Defined(min)               # Set 'min' to 16 for at-least n=16
    dc  = Defined(dec)
    mod = Default(mod, dc ? 1 : 2)
    mod = max(mod, 1)
    bnk = Default(bankers, false)    # Use bankers' rounding. Requires SimilarityMetrics
    und = Undefined()
    dec = dc ? "%0."+string(dec)+"f"  : und
    n   = dc ? Eval(String(n,   dec)) : float(n)
    mnf = dc ? Eval(String(min, dec)) : min
    mnf = dm ? mnf : und

         Assert(isFloat(n),   "nmod: 'n' is not a number")
    dm ? Assert(isFloat(min), "nmod: 'min' is not a number") : nop()

    return (  dc && mod == 1                       ? Eval(String(dm ? max(min,n) : n, dec)) : \
             !dc && dm && nmod(n,mod,und,dec,bnk)  < max(mod,min)   ? max(mod,mnf)          : \
              bnk                                  ? RoundHalfToEven_mod(n, mod)            : \
                                                     round( n / mod ) * mod )               }



##############################
### Adjust source to mod(n) size by adding or cropping borders.
### It's a simpler, more straight-forward alternative of PadResize()
###
### modes:
###     "auto" - will crop or pad depending on minimal transform (Default)
###     "crop" - will force cropping to mod
###     "pad"  - will force padding  to mod
function mmod(clip c, int "modH", int "modV", string "mode", string "borders") {

    c
    rgb = isRGB()
    fch = rgb || isy() || is444()
    w   = width()
    h   = height()

    mdh    = Default(modH, fch ? 1 : 2)
    mdv    = Default(modV, mdh)
    md     = Default(mode, "auto")
    # borders: 'Dilate', 'Mirror' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)

    wm = nmod(w,mdh)
    hm = nmod(h,mdv)

    # Crop or Pad
    wc = md=="auto" ? wm < w : md=="crop"
    hc = md=="auto" ? hm < h : md=="crop"

    # Rounding
    wp = abs(w - wm)/2.  wi = round(wp)%2
    hp = abs(h - hm)/2.  hi = round(hp)%2
    wh = ceil (Frac(wp))+floor(wp)
    hh = ceil (Frac(hp))+floor(hp)
    wl = floor(Frac(wp))+floor(wp)
    hl = floor(Frac(hp))+floor(hp)

    # Zeroing null transforms
    wc1 = wc ?  wh+wi : 0    wa1 = !wc ? wh+wi : 0
    wc2 = wc ? -wl+wi : 0    wa2 = !wc ? wl-wi : 0
    hc1 = hc ?  hh+hi : 0    ha1 = !hc ? hh+hi : 0
    hc2 = hc ? -hl+hi : 0    ha2 = !hc ? hl-hi : 0

    PadBorders(wa1,ha1,wa2,ha2,borders)
    Crop      (wc1,hc1,wc2,hc2,   true) }



# Converts a 'string' type color array into an hexadecimal string
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
###   ClipBoard          (https://avisynth.nl/index.php/ClipBoard)
###   SCSelect_HBD v0.02 (https://github.com/Dogway/Avisynth-Scripts/tree/master/EX%20mods)
###   MasksPack          (https://github.com/Dogway/Avisynth-Scripts)
###   EdgeFixer          (https://avisynth.nl/index.php/EdgeFixer)
###
###
### i.e.
### MatteCrop(1920,1080,thr=16.0,cropmore=true,ScanW=90,ScanH=0,mode=2)
###
###############################################################################

function MatteCrop(clip s, int "width", int "height", float "thr", bool "CropMore", bool "Moving", int "ScanW", int "ScanH", int "mode", float "SC_thr", string "kernel", float "b", float "c", float "p") {

    s
    rgb    = isRGB()
    isy    = isy()
    fch    = isy || rgb || is444()
    bi     = BitsPerComponent(s)
    w      = width()
    h      = height()


    nw     = Default(width, w)
    nh     = Default(height,h)
    addw   = Default(ScanW,round((w/8.)))
    addh   = Default(ScanH,round((h/4.)))
    Mot    = Default(Moving, False)                # If the matte is moving (sliding) this enables pixel level accuracy.
    CM     = Default(CropMore, Mot || fch)         # In case of odd cropping, either crop 1 pixel out or leave 1 pixel of the border
    thr    = Default(thr, Mot ? 16.3 : 16.0)       # Threshold, pixel values same or below this will be considered borders
    mode   = Default(mode, 2)                      # 0: center+pad 1: crop to minimum (WIP) 2: resize to maximum 3: hybrid 0-2 (auto)
    SC_thr = Default(SC_thr, 3.5)                  # Scene Change detection threshold
    kernel = Default(kernel, "bicubic")            # Kernel to use when resizing (mode=2)
    b      = Default(b, 0.0)
    c      = Default(c, 0.75)                      # Precise Bicubic by default (fast and HQ)
    p      = Default(p, 100.0)
    fs     = rgb

    addw==0 ? Assert( addh>0, "MatteCrop: You need to scan borders for at least one of the dimension") : nop()
    addh==0 ? Assert( addw>0, "MatteCrop: You need to scan borders for at least one of the dimension") : nop()

    thr    = ex_bs(thr, 8, bi, fulls=fs)
    addwz  = addw > 0
    addhz  = addh > 0

    avgY = !isy ? ExtractY().ConvertBits(8,dither=-1,fulls=fs) : ConvertBits(8,dither=-1,fulls=fs)
    avg  = avgY.RatioResize(320.0,  "adjust2w",kernel="bilinear")
    avg  = avg.TemporalSoften(10,255,255,10,2)
    avg  = avg.TemporalSoften(10,255,255,10,2)
    avg  = avg.RatioResize(float(w),"adjust2w",kernel="bicubic")

    avgc = ex_merge(avgY, avg, BoxMask(s,addw,w-addw,addh,h-addh)).ConvertBits(bi,dither=-1,fulls=fs)

    SC   = SCSelect_HBD(avg,dfactor=SC_thr,mindif=1.0)

    # Add detection of credits and bumpers
    ScriptClip(s, function [s,SC,avgc,addw,addh,addwz,addhz,w,h,thr,CM,Mot,fch,kernel,b,c,p,mode] () {

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
        Mot ? spline36resize(s,fch?MotW:nmod(MotW,2),fch?MotH:nmod(MotH,2),src_left=x1,src_width=-x2,src_top=y1,src_height=-y2) : \
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
