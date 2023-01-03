###                                                        #
###                                                        #
###                          2.1   by Dogway  (16-09-2015) #
###                      mod 2.533 by A.SONY  (29-11-2020) #
### Stabilization Tools Pack 3.3   by Dogway  (03-01-2023) #
###                                                        #
###   https://forum.doom9.org/showthread.php?t=182881      #
###                                                        #
### Functions:                                             #
###      FilmGateFix                                       #
###      FillBorder                                        #
###      FindBlackBorders                                  #
###      StabPlus                                          #
###                                                        #
############################################################
###
###
### Set of tools to work with common stabilization issues, mainly from telecine process.
### For aggressive handheld camera shaking I still recommend vdub's Deshaker.
###
### Required: AviSynth+ 3.7.2+
###           ExTools
###
###
##########################################################
###
### FilmGateFix()
###
### Function to fix frames ( by means of FreezeFrame() ) with film gate issues after a scene change.
### This is aimed at animation, for live footage frame interpolation should be desired.
###
### Rationale:
###   Film Gate is about non-linear vertical stretching, thus we compare
###   current and next frames in two blocks, a 1/5 block of top and bottom.
###   The difference in both should be very high for film gate artifacts
###   between the 2nd and 3rd frame after a Scene Change (also 1st and 2nd are compared).
###   We mask this through a Scene Detection filter, motion masks, etc.
###
### EXPERIMENTAL:
###   It still grabs too many false-positives, and leaves many positives-positives undone
###   a better approach would be to automatically bookmark every scene change and manually freezeframe them
###
###
### Dependencies:
###
### Required:
### ------------
###
###   MVTools       (v2.7.45 or higher)                 (https://avisynth.nl/index.php/MVTools)
###   MaskTools2    (v2.2.30 or higher)                 (https://avisynth.nl/index.php/MaskTools2)
###   Average       (v0.95 or higher)                   (https://avisynth.nl/index.php/Average)
###   ResizersPack
###
####################################

function FilmGateFix(clip c,  float "thr", int "window", int "thSCD1", int "thSCD2", bool "debug") {

    thr     = Default(thr,   1.2)   # Main tweak setting, use debug and tweak according 2nd frame after Scene Change
    window  = Default(window,  5)   # Enlarges/reduces detection area, "height()/window"
    thSCD1  = Default(thSCD1,500)   # Increase to reduce number of scenes detected
    thSCD2  = Default(thSCD2,145)   # Increase to reduce number of scenes detected
    Debug   = Default(Debug,false)  # Check what frames will be fixed and the difference value of frames for tweaking "thr"
    thr2    = 5.0                   # central part of frame must change less than this to consider static scene to fix.

    c
    w=width()
    h=height()

    # Change to SceneStats()
    # Codeblock for Scene Change detection and Motion Mask
    kind   = 0
    gam    = 1.2 # Could probably be exposed
    mvthr  = 30  # Threshold, heavily dependent on gamma value above
    super  = MSuper  (pel=1, sharp=0,vpad=0,hpad=0)
    b1v    = MAnalyse(super,isb=true, blksize=16,overlap=8,search=0)
    f1v    = MAnalyse(super,isb=false, blksize=16,overlap=8,search=0)
    SADbv1 = MMask   (b1v,kind=kind,gamma=gam,thSCD1=thSCD1,thSCD2=thSCD2)
    SADfv1 = MMask   (f1v,kind=kind,gamma=gam,thSCD1=thSCD1,thSCD2=thSCD2)

    SceneChange = MSCDetection (f1v,thSCD1=thSCD1,thSCD2=thSCD2)
    mvmask      = Merge(SADbv1,SADfv1)


    # Film Gate happens commonly between 2nd and 3rd frame after SC
    # 1st frame is commonly garbage
    add  = round(w/(window*1.0))
    T    = crop(0,0,0,nmod(-h+add,8),true)
    B    = crop(0,nmod(h-add,8),0,0, true)

    L    = crop(0,0,nmod(-w+add,8),0,true)
    R    = crop(nmod(w-add,8),0,0,0, true)

    CTB  = crop(0,nmod(add,8),0,-((add)/8)*8,true)
    CLR  = crop(nmod(add*1.5,8),0,-nmod(add*1.5,8),0,true)

    SC2  = ex_logic(SceneChange,selectevery(SceneChange,1,-1),"max",UV=3)

    d = Trim(2,0)

    # Here, if after SC top area changes more than "thr" compared to bottom area
    # then apply one FreezeFrame() for first SC frame, and another FreezeFrame() for the 2nd one,
    # they (1st and 2nd) compute individually. There is a motionmask on top to rule out false positives.
    ScriptClip( function[c,d,T,B,L,R,c,SC2,CTB,CLR,mvmask,thr,thr2,mvthr] () {

         curf = current_frame
         YPlaneMax(SC2)>254                                 &&                                     \
        (abs(YDifferenceToNext(T)-YDifferenceToNext(B))>thr && abs(YDifferenceToNext(CTB))<thr2 || \
         abs(YDifferenceToNext(L)-YDifferenceToNext(R))>thr && abs(YDifferenceToNext(CLR))<thr2) ? \
             YDifferenceFromPrevious(SC2)<=250 ?                                                   \
                AverageLuma(mvmask)<mvthr ?     FreezeFrame(curf,curf,curf+1) : c :                \
                AverageLuma(mvmask)<mvthr ?                                                        \
                    LumaDifference(c,d) < 3.7 ? FreezeFrame(curf,curf,curf+2) :                    \
                    YDifferenceToNext() < 8.0 ? FreezeFrame(curf,curf,curf+1) : c : c : c
                } )

    # Debug block
    debug ? +\
    Eval("""stackhorizontal(scriptclip("Subtitle(c,"+Chr(34)+" Top & Bottom:"+Chr(34)+"+String(YDifferenceToNext(T)-YDifferenceToNext(B))+
           \ "+Chr(34)+"\n Left & Right:  "+Chr(34)+"+String(YDifferenceToNext(L)-YDifferenceToNext(R))+
           \ "+Chr(34)+"\n Center Horiz:  "+Chr(34)+"+String(YDifferenceToNext(CTB))+
           \ "+Chr(34)+"\n Center Vert:    "+Chr(34)+"+String(YDifferenceToNext(CLR))+
           \ "+Chr(34)+"\n AvgLuma:    "+Chr(34)+"+String(LumaDifference(c,d)),
           \ align=7,size=30,lsp=10)",args="T,B,L,R,c,CTB,CLR,d=Trim(2,0)"),
           \ scriptclip("AverageLuma(mvmask)<"""+string(mvthr)+"""?((abs(YDifferenceToNext(T)-YDifferenceToNext(B))>"+string(thr)+
               \ " && abs(YDifferenceToNext(CTB))<"+string(thr2)+") || (abs(YDifferenceToNext(L)-YDifferenceToNext(R))>"+
               \ string(thr)+" && abs(YDifferenceToNext(CLR))<"+string(thr2)+") ? "+
               \ "(YplaneMax(SC2)>254?(LumaDifference(c,d)<3.7?ex_lut(c,"+Chr(34)+"255"+Chr(34)+",UV=128):(YDifferenceToNext()<8.0?ex_lut(c,"+Chr(34)+"255"+Chr(34)+",UV=128):ex_lut(c,"+Chr(34)+"0"+Chr(34)+
               \ ",UV=128))):ex_lut(c,"+Chr(34)+"0"+Chr(34)+",UV=128)):ex_lut(c,"+Chr(34)+"0"+Chr(34)+",UV=128)):ex_lut(c,"+Chr(34)+"0"+
               \ Chr(34)+",UV=128)",args="T,B,L,R,c,CTB,CLR,SC2,mvmask,d=Trim(2,0)"))
               \ crop(0,0,-nmod(w/1.1,2),0,true).Subtitle("Frame to Freeze",align=9,size=40)""") : last }





####################################
###
### FillBorder()
###
###
### Function to fill dark (use threshold) borders, in the vein of old FillMargins() function.
### But instead of mirroring or other approaches like resizing, this function fills/interpolates
### missing data from surrounding pixels.
### Useful to use as a clean pass after StabPlus() and crop(x1,y1,x2,y2)
### for the remaining thin black borders (up to 3px)
###
### For borders of 4px and more you can enable FixFalPos, there you supply a clip
### without black borders (ie. before StabPlus() ). It automatically replaces the offended frames.
### Some thick black borders aren't "0" black at all, they show garbage and the 3+1 pixel border
### may not average to 0, so a "thr2" setting is added as threshold, default 7 should be enough.
###
### Below you can still use the the FindBlackBorders() function for manual handling of thick black borders.
### Use ClipClop() for the StabPlus() results according to the statistics file of FindBlackBorders()
###
###
###  EXPERIMENTAL:
###  Some thick black borders aren't value 0 at all, sometimes they average to 16, so one would
###  need to set thr2 to >16 which will basically bypass the Stab'ed clip in a lot of dark scenes.
###  So probably you might still want to use this for only <4px borders and FindBlackBorders() to
###  manually find the most offending borders and problematic areas.
###
###
### Dependencies:
###
###   AVSInpaint    (v1.3 or higher)    (https://avisynth.nl/index.php/AvsInpaint)
###   ResizersPack
###
####################################

function FillBorder(clip c, int "thr", int "pad", bool "blur", bool "debug", clip "FixFalPos", clip "FillBordersc", int "thr2", bool "mirror", float "PAR", bool "subsample", bool "maskonly") {

    isy      = isy(c)
    bi       = BitsPerComponent(c)

    thr      = Default(thr, 1)       # Threshold, pixel values below this will be considered borders
    pad      = Default(pad, 0)       # Pixels, you can expand the replacement area adding more pixels
                                     # (to deal with dirty borders) (use "1" to deal with 1px b/w chroma, due to the chroma subsampling nature of video)
    mirror   = Default(mirror, false)
    blur     = Default(blur, false) # Blurs the masking for the replacement area. Currently not supported for InpaintLogo()
    debug    = Default(debug,false)  # Show the borders that are going to be filled
    FalPos   = Defined(FixFalPos)    # If you supply a reference clip borders with 4 or more
                                     # average thr2 pixels will be replaced with the clip's frame
    thr2     = Default(thr2, 7)      # Threshold for FalPos, FalPos frames sometimes have garbage borders so you need to increase threshold
    mskonly  = Default(maskonly, false) # Show the border mask
    subsampl = Default(subsample,false)
                                     # FillBordersc, replacement clip, even for 1 or 2 pixel borders

    !isy ? c.ExtractY() : c

    yclip=last
    w    = width()
    h    = height()

    # 4px or greater
    L4=FalPos ? crop(0,0,-w+4,0,true) : nop()
    R4=FalPos ? crop(w-4,0,0 ,0,true) : nop()
    T4=FalPos ? crop(0,0,0,-h+4,true) : nop()
    B4=FalPos ? crop(0,h-4,0 ,0,true) : nop()

    c
    Fill = ScriptClip( function[yclip,c,w,h,isy,thr,thr2,L4,R4,T4,B4,pad,blur,debug,FalPos,FixFalPos,mirror,subsampl,PAR,mskonly,FillBordersc] () {

        yclip
        pad = blur ? pad+2 : pad
        x1o=0 x2o=0
        y1o=0 y2o=0

        for (li=1, 3, 1) {
          if (AverageLuma(crop(li-1,0,-w+li,0,true))>thr) {
            x1o= li-1
            li=3
           }
        }

        for (ri=1, 3, 1) {
          if (AverageLuma(crop(w-ri,0,-ri+1,0,true))>thr) {
            x2o= ri-1
            ri=3
          }
        }

        for (ti=1, 3, 1) {
          if (AverageLuma(crop(0,ti-1,0,-h+ti,true))>thr) {
            y1o= ti-1
            ti=3
          }
        }

        for (bi=1, 3, 1) {
          if (AverageLuma(crop(0,h-bi,0 ,-bi+1,true))>thr) {
            y2o= bi-1
            bi=3
          }
        }

        x1=x1o+pad
        x2=x2o+pad
        y1=y1o+pad
        y2=y2o+pad


        FalPos = !mskonly && FalPos ? ((x1o > 2 || x2o > 2 || y1o > 2 || y2o > 2 )
                                  \ ? ((AverageLuma(L4) < thr2) || (AverageLuma(R4) < thr2) || (AverageLuma(T4) < thr2) || (AverageLuma(B4) < thr2))
                                  \ : false) : false


        cropnpad = (x1+y1+x2+y2>0)
        ter = !FalPos && cropnpad

        x1inp=cropnpad && subsampl ? nmod(x1o,2) : x1
        x2inp=cropnpad && subsampl ? nmod(x2o,2) : x2
        y1inp=cropnpad && subsampl ? nmod(y1o,2) : y1
        y2inp=cropnpad && subsampl ? nmod(y2o,2) : y2


        PaCl = mskonly ? nop() : mirror && !ter ? c.PadBorders(x1inp,y1inp,-x2inp,-y2inp,"Mirror") : c
		# change this to BoxMask
        msk  = LetterBox(BlankClip(last,1,pixel_type="Y8",color_yuv=$ffffff),y1,y2,x1,x2,color_yuv=$000000,channels=0)
        msk  = !mirror ?         msk.ex_lut("x range_half > range_max x ?")          : msk
        msk  = !mirror && blur ? msk.ex_boxblur(2,mode="mean")                       : msk
        msk  = isy             ? CombinePlanes(msk,c,planes="YUV",sample_clip=c)     : msk

        fill = mskonly ? msk : FalPos ? trim(c,0,current_frame-1)++trim(FixFalPos,current_frame,-1)++trim(c,current_frame+1,0)    : \
                               (ter   ? Defined(FillBordersc) ? mt_merge(c,FillBordersc,msk)                                      : \
                                                                InpaintLogo(c, radius=max(x1,y1,x2,y2)+max(2,pad), mask=msk,ChromaTensor=subsampl,PixelAspect=PAR,PreBlur=mirror && blur ? 2.5 : Undefined()) : \
                                         PaCl)

        debug ? ter ? subtitle(msk,"Bordered",align=3,size=round(h/20.0)) : msk : fill

        } )

    !debug ? Fill : \
    Eval("""
        box    = h/4.0
        m      = 2

        corner = crop(ex_lut("range_max"),nmod(w-box,m),nmod(h-box,m),0,0,true)
        corner = corner.PadBorders(0,0,nmod(w/2.0-box,m),nmod(box,m)).ex_lut("x range_max < 0 range_max ?")

        horiz  = stackhorizontal(corner,corner.fliphorizontal())
        verti  = stackvertical(horiz,horiz.flipvertical())
        ex_merge(c,Fill.PointResize(w,h),verti,luma=true)""") }




####################################
###
### FindBlackBorders()
###
###
### Script to find sources with black borders for example as a result of bad deshaking, run on analysis pass
### The output file is formatted to be imported to avspmod as bookmarks
### use ClipClop() afterwards on a scene by scene basis to fix this.
###
### "width" is border thickness for detection
### "thr" is threshold, pixel values below this will be considered borders
### "path" is the path to store the statistics file, with end backslash. Default is "C:"
### "filename" is the statistics file name. In case you don't want to overwrite old ones
###
####################################

function FindBlackBorders(clip c, int "width", int "thr", string "path", string "filename") {

    add      = Default(width,1)     # Width for detection, normally 1 should suffix to most situations
    thr      = Default(thr,  1)     # Threshold for detection, pixels lower than this value will be considered a border
    path     = Default(path, "C:")  # This is the path to store the statistics file
    filename = Default(filename, "FindBlackBorders - Statistics.log") # Filename of the statistics file

    c.ExtractY()

    w=width()
    h=height()

    L1=crop(0,0,-w+add,0,true)
    R1=crop(w-add,0,0 ,0,true)
    T1=crop(0,0,0,-h+add,true)
    B1=crop(0,h-add,0 ,0,true)

    ScriptClip( function[thr,L1,R1,T1,B1,path,filename] () {

        x1 = AverageLuma(L1) < thr
        x2 = AverageLuma(R1) < thr
        y1 = AverageLuma(T1) < thr
        y2 = AverageLuma(B1) < thr

        WriteFileIf(""+path+"\"+filename+"", " "+string(IsBorder(x1,y1,x2,y2))+" ", "CHAPTER00=",
                \ "stab_FFFormatTime(round((current_frame * 1000) / framerate()))", "", "")
    } )

    # Here I need to retrieve the clip passed through WriteFileIf, so it is evaluated (or use Echo() ?)
    return last }

function IsBorder(clip c, bool x1, bool x2, bool y1, bool y2) {return (x1||y1||x2||y2)}


####################################
###
### StabPlus() v4.0
###
###
### For completeness I'm going to list all the shortcomings of Depan plugin
### maybe a programmer realises the urge of an avisynth bug-free stabilizer:
### -Artifacts occasionally on frame borders (1px skew) --> crop out, check example
### -No advanced border fill --> addressed above ( FillBorder() )
### -Some false-positives when people clapping, trembling...
### -Requires mod 4 inputs?
### -No medium jitter fix
### -Some thick borders (false positives) aren't 0 black on the inner side
###
#######################################
###
### Implemented a FixPalPos to replace frames that present black borders of 3 or more pixels
###     with source frames, check output just in case, since some borders don't average to 0 black (rare).
### Also supplied a more contrasty clip version for more subtle global motion analysis
### Prefilter is for the prefilter clip, in case the clip is very grainy/noisy
### Finally a few more things were introduced by testing and checking other script versions.
###
###
### Required:
### ------------
###   Depan         (v2.13.1.6 or higher)               (https://avisynth.nl/index.php/DePan)
###   DePanEstimate (v2.10.0.4 or higher)               (https://avisynth.nl/index.php/DePanEstimate)
###   RgTools       (v1.2)                              (https://avisynth.nl/index.php/RgTools)
###   ResizersPack  (v10.7  or higher)
###   AVSInpaint*   (v1.3   or higher for fill=3)       (https://avisynth.nl/index.php/AvsInpaint)
###   SMDegrain     (v3.5.7 or higher for Luma_Exp=1)   (https://avisynth.nl/index.php/SMDegrain)
###   GradePack     (v8.1   or higher for Luma_Exp=2)   (https://avisynth.nl/index.php/SMDegrain)
###
### Example:
###
### StabPlus(dxmax=20, fill=3, FixFalPos=true)
###
####################################
# demote subpixel when UHD or even HD
# Add feedback.dll filling option (use fixed previous frame)
function StabPlus(clip clp, int "ts", int "range", int "dxmax", int "dymax", bool "FixFalPos", clip "FalPosclip", float "zoom", int "fill", float "PAR", clip "Prefilter", int "Luma_Exp") {

    ts        = Default(ts,    7)                      # frames to temporal average for better motion estimation (max. 7)
    range     = Default(range, 3)                      # frames before/after to estimate motion
    dxmax     = Default(dxmax, round(width(clp)/120.)) # maximum deviation in pixels
    dymax     = Default(dymax, dxmax)                  # x, and y should be the same
    zoom      = Default(zoom,  1)                      # maximum zoom factor (1 disabled)
    fill      = Default(fill,  2)                      # Border filling. -1: off  0: extend  1: mirror 2: copy from source 3: process with inpaint
    PAR       = Default(PAR, 1.0)                      # PAR of your source
    FixFalPos = Default(FixFalPos, true)               # Fixes borders of 3 or more pixels wide. Use along crop(2,2,-2,-2)...
                                                       # ...after StabPlus() to get rid of border issues entirely
    Lumae  = Default(Luma_Exp, 1)                      # Luma Expansion for better accuracy
                                                       # 0: disabled  1: TV to PC levels  2: Auto Contrast

    Source = Defined(Prefilter) ? Prefilter : clp
    Pref   = Source.isy() ? Source : Source.ExtractY()


    temp   =             Pref.TemporalSoften(ts,255,0,25,2)   # SC thr to 25 otherwise pans will stutter
    rep    = temp.Repair(Pref.TemporalSoften(1, 255,0,25,2))
    repc   = CombinePlanes(rep, Source, planes="YUV", source_planes="YUV", sample_clip=Source)
    inter  = Interleave(rep,Pref)

    # temporal stable auto-contrast (better subpixel detection)
    Luma_Expa = Lumae==2 ? ex_autolevels(th=0.13)                                  : \
                Lumae==1 ? inter.ex_Luma_Rebuild(S0=5, c=1.0/32, UV=2, tv_in=true) : \
                           inter

    mdata     = DePanEstimate(Luma_Expa,range=range,pixaspect=PAR,trust=0.0,dxmax=dxmax,dymax=dymax,zoommax=zoom)
                DePan(Interleave(repc,Source),data=mdata,offset=-1,mirror=fill==1?15:0,pixaspect=PAR,matchfields=false,subpixel=2)
                SelectEven()

    subsampl  = !(clp.is444() || clp.isy())

    abs(fill) != 1 ? FillBorder(pad=subsampl ? 1 : 0,subsample=subsampl,FixFalPos=Defined(FalPosclip) ? FalPosclip : FixFalPos ? clp : Undefined(), mirror=fill==0, FillBordersc=fill==2 ? clp : Undefined(), PAR=PAR) : last }


######### HELPER FUNCTIONS #########

# Helper function for FindBlackBorders() from FFMS2.avsi
function stab_FFFormatTime(int ms) {
    s  = ms / 1000
    ms = ms % 1000
    m  = s / 60
    s  = s % 60
    h  = m / 60
    m  = m % 60
    return string(h) + ":" + string(m,"%02.0f") + ":" + string(s,"%02.0f") + "." + string(ms,"%03.0f")}