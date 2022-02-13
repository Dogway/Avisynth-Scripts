################################################################################################
###                                                                                          ###
###                                Simple MDegrain Mod - SMDegrain()                         ###
###                                                                                          ###
###                       Mod by Dogway - Original idea by Didée and Caroliano               ###
###                                                                                          ###
###          Special Thanks: Sagekilla, Didée, cretindesalpes, Gavino and MVtools people     ###
###                                                                                          ###
###                       v0.2.0       by Caroliano - 24 Jan  2010                           ###
###                       v0.4.0d      by Dogway    - 03 Sep  2011                           ###
###                       v3.1.2d      by Dogway    - 21 July 2015                           ###
###                       v3.1.2.111s  by A.SONY.   - 09 Febr 2021                           ###
###                       v3.4.7d      by Dogway    - 11 Feb  2022                           ###
###                                                                                          ###
################################################################################################
###
### Based on Caroliano's concept: https://forum.doom9.org/showthread.php?t=152326
### Also  on Didée's     concept: https://forum.doom9.org/showthread.php?p=1076491#post1076491
###
### General purpose simple degrain function. Pure temporal denoiser. Basically a wrapper(function)/frontend of mvtools2+mdegrain
### with some added common related options. Goal is accessibility and quality but not targeted to any specific kind of source.
### The reason behind is to keep it simple so for basic usage you will only need ExTools and MVTools2.
###
### Check documentation for deep explanation on settings and defaults.
### https://forum.doom9.org/showthread.php?t=182881
###
### UHD: Use as input (or at least as prefilter) the decoded (and tonemapped) PQ clip (ie. DGHDRtoSDR(mode="pq",white=100))
###
###
### Dependencies:
###              MVTools2
###              ExTools
###              LSFmod/SharpenersPack  (for Contrasharp or LFR)
###                 ResizersPack        (for Contrasharp
###                                      or  Str=0.1 to 1.0 ~ex_retinex()~)
###              GradePack              (for Str=0.1 to 1.0 ~ex_retinex()~)
###              RgTools                (for Contrasharp
###                                      or  prefilter=0~3)
###              DFTTest                (for prefilter=4)
###              KNLMeansCL             (for prefilter=5)
###              BM3D                   (for prefilter=6) # Buggy when used along ffvideosource() or cropping in DGSource()
###              DGDecNV                (for prefilter=7)
###                 TransformsPack      (for prefilter=6 or prefilter=7)
###              neo_tmedian            (for mode="medianT")
###              nnedi3                 (for subpixel=4)
###                 SysInfo             (for subpixel=4)
###              Average                (for mfilter + (Contrasharp or mode!=MDegrain) )
###
###
### Function Definition:
###   (
###   clip,
###   int tr=1 (1 to 9 by 1),
###   int thSAD=300 (100 to 1000 by 1),
###   [int "blksize"=16 (4 to 64 by 4)],
###   [int "overlap"=8 (2 to 32 by 4)],
###   string "mode"="MDegrain" ("MDegrain" / "MedianT" / "MedianST" / "MedianSTS" / "TemporalSoften" / "FluxSmoothT" / "ML3DEx" / "Hybrid" / "TL3D" / "STWM" / "IQMT" / "GaussT5" / "GaussST5" / "--" / "rMDegrain" / "rMedianST" / "rMedianSTS" / "rML3DEx" / "rHybrid" / "rTL3D" / "rSTWM" / "rIQMT" /"rGaussT5" / "rGaussST5"),
###   int "prefilter"=-1 (-1 to 7 by 1),
###   bool "ContraSharp"=false,
###   bool "RefineMotion"=false,
###   float "Str"=5.0 (0.0 to 6.0 by 0.1),
###   float "Amp"=0.0312 (0.0 to 1.0 by 0.01),
###   int "plane"=4 (1 to 4 by 1),
###   bool "chroma"=true,
###   int "LFR"=300 (50 to 1920 by 1),
###   bool "DCTFlicker"=false,
###   bool "TrueMotion"=false,
###   bool "show"=false,
###   )
###
################################################################################################

function SMDegrain (clip input   , int "tr"      , int "thSAD"    , int  "thSADC" , bool "RefineMotion",  val  "contrasharp", clip  "CClip"     , string "mode"     , bool "interlaced" , int   "plane"  , int   "Globals"   , bool "tv_range" ,  \
                     int "pel"   , int "subpixel", val "prefilter", clip "mfilter", int  "blksize"     , int   "overlap"    , int   "limit"     , float "limitC"    , bool "limitS"     , val   "LFR"    , bool  "DCTFlicker", int "thSCD1"   , int "thSCD2",  \
                    bool "chroma", int "hpad"    , int "vpad"     , val  "Show"   , float "Str"        , float "Amp"        , int   "DCT"       , int "searchparam" , int "pelsearch"   , int   "search" , bool "truemotion" ,  \
                  int "device_id", int  "rfilter", bool "UHDhalf"     ) {

    bi     = BitsPerComponent(input)
    w      = input.width ()
    h      = input.height()
    isy    = input.isy()
    p_type = input.PixelType()
    rgb    = FindStr(p_type, "RGB") > 0

    fscale = propNumElements(input, "_ColorRange")  > 0 ? \
             propGetInt     (input, "_ColorRange") == 0 : rgb

    md           = Default( mode, "MDegrain")
    md           = ReplaceStr(LCase(md)," ","")
    tr           = Default( tr,       2 )
    tri          = tr                                          # Storing for DCTFlicker
    rc           = LeftStr(md, 1) == "r"                       # recursion won't work on 'TemporalSoften', 'FluxSmoothT' or 'MedianT' (only when tr > 2)
    md           = rc ? MidStr(md, 2) : md

    md           = FindStr(md, "mediant") > 0 ? rc && tr==1 ? "MedianT" : rc && tr==2 ? "MedianT5" : "medianTn" : md
    T3           = md == "MedianT"    || md == "MedianST" || md == "ML3DEx"  || md == "Hybrid"   || md == "TL3D"
    T5           = md == "MedianT5"   || md == "STWM"     || md == "GaussT5" || md == "GaussST5" || md == "MedianSTS" || md == "IQMT"
    T7           = FindStr(md, "fluxsmooth") > 0
    TS           = md == "TemporalSoften"

    tr           = T3 ? 1 : T5 ? 2 : T7 ? min(3,tr) : TS ? min(7,tr) : tr


    UHDhalf      = Default( UHDhalf,  true)
    isMult       = tr > 6                                      # MDegrainN is slower, so avoid >6 at possible
    isHD         = (w > 1099 || h >  599)
      UHD        = (w > 2599 || h > 1499)
    isUHD        = UHD && !UHDhalf
    UHDhalf      = UHD &&  UHDhalf

    cplaceCMD = is420  (input) ? "420" : is422(input) ? "422" : "444"

    scaleCSAD = is420  (input) ? isHD ? 2 :  0 : \
                is422  (input) ? isHD ? 2 :  0 : \
                is444  (input) ? isHD ? 2 :  1 : \
                isYV411(input) ? isHD ? 0 : -1 : \
                                 isHD ? 2 :  0

    thSAD        = Default( thSAD,  300 )
        thSADR   =                  round(exp(-101./(thSAD*0.83)) * 360) # Directly proportional up to critical thSAD, then -not included- inversely proportional (-1.9x+682)
        thSADRC  =                  round(thSADR * 0.755 * (0.25*exp(scaleCSAD*0.693)))   # Currently not supported by MRecalculate()
    thSADC       = Default( thSADC, round(thSAD  * 0.755 * (0.25*exp(scaleCSAD*0.693))))
    RefineMotion = Default( RefineMotion, false)


    Globals      = Default( Globals,  0 )
    GlobalR      = Globals == 1
    GlobalO      = Globals == 3

    isCClip      = Defined( CClip )
    Contrasharp  = Default( Contrasharp, !GlobalO && isCClip)
    SLimit       = Default( limitS,      true )                # Limit type for the contrasharpening   True: Spatial  False: Temporal
    isCntr       = IsBool (   Contrasharp )
    isShrp       = !isCntr ? (Contrasharp > 0.0) : Contrasharp
    isInter      = Default( Interlaced,  false)
    InterPar     = isInter ? GetParity(input) : nop()


    preclip      = IsClip ( prefilter )
    prefilter    = Default( prefilter, -1 )
    pel          = Default( pel, isHD ? 1 : 2 )
    subpixel     = Default( subpixel,   3)
    rfilter      = Default( rfilter,    3)
    MFilterB     = Defined( mfilter )
    pelclip      = pel>1 && subpixel > 2

    LFR          = Default( LFR,        false)                 # Cutoff frequency for Low Frequency Restore -LFR-, useful when using truemotion, high 'tr' or 'thSAD'. Default is 300, use higher for lower cutoff frequency restoration.
    LFRB         = isBool ( LFR ) ? LFR : LFR > 0
    DCTF         = Default( DCTFlicker, false)                 # Tries to temporally calm the recovered Low Frequency details with LFR

    if (!isBool(LFR)) {

             LFR = max(LFR,50)
             Fs  = max(w,h) * 2                                # Frequency sample rate is resolution * 2 (for Nyquist)
             k   = sqrt(log(2)/2) * LFR                        # Constant for -3dB
             LFR = Fs / ( k * 2 * pi )                         # Frequency Cutoff for Gaussian Sigma
    } else { LFR = 3.46*(w/1920.) }                            # (Default: -3dB -log(2)- at 300Hz)

    blksize      = Default( blksize,  isHD ? 16 : 8 )
        blk2     = blksize / 2
        ovl2     = max(2,blk2 / 2)
    overlap      = Default( overlap, blk2 )
    search       = Default( search,     4 )
    searchparam  = Default( searchparam, isUHD ? 1 : 2 )
    pelsearch    = Default( pelsearch,   pel )                 # searchRange at finest level. Higher has a high performance hit
    truemotion   = Default( truemotion, TS || T7 || !isHD)
    DCT          = Default( DCT,   0 )                         # Change to 5 (slower) if you get artifacts due to luminosity changes (fades, flashes, etc)
    thSCD1       = Default( thSCD1,  round(pow((blksize*2.5),2)))
    thSCD2       = Default( thSCD2,  130 )

    plane        = Default( plane,    isy ? 0 : 4 )
    plane0       = plane!=0
    chroma       = Default( chroma, !(isy || !plane0)  )
    Chr          = chroma ? 3 : 1
    U            = plane0 && plane!=2 ? 3 : 2
    V            = plane0 && plane!=1 ? 3 : 2

    Str          = Default( Str, 5.0 )                         # 0: Automatic Range Conversion (with FrameProps)  0.0-1.0: Multi-Scale Retinex  >1.0: ex_luma_rebuild(Str)   (from 0.0 to 1.0 indicates ex_retinex() black level clipping value)
    Amp          = Default( Amp, 1./32 )
    DefTV        = Defined( tv_range)
    tv           = Default( tv_range, !fscale)

    hpad         = Default( hpad, isHD ? 0   : blksize)
        hpadU    = isUHD ? hpad/2+(hpad/2)%2 : hpad
    vpad         = Default( vpad, isHD ? 0   : hpad)
        vpadU    = isUHD ? vpad/2+(vpad/2)%2 : vpad
    limit        = Default( limit, md!="MDegrain" ? 255 : isUHD ? 2 : 255 )  # auto-scaled
    limitc       = Default( limitc,limit)

    sShow        = IsString( Show)
    Show         = Default ( Show,  false)



    # Error Report
                           Assert(IsVersionOrGreater(3,7,1),    "SMDegrain: Update AviSynth+ version")
                           Assert(blksize==4 || blksize==8 || blksize==16 || blksize==24 || blksize==32 || blksize==48 || blksize==64,"SMDegrain: MAnalyse: Block's size must be 4x4, 8x8, 16x16, 24x24, 32x32, 48x48 or 64x64")
                           Assert(overlap <= blk2,              "SMDegrain: Overlap must be at least half blksize or less")
                           Assert(overlap == overlap-overlap%2, "SMDegrain: MAnalyse: overlap must be an even figure")
                           Assert(IsBool(Show) || sShow,        "SMDegrain: 'Show' only accepts bool inputs (true,false), or string modes ('Speed','Memory',Quality')")
                           Assert(preclip || IsInt(prefilter),  "SMDegrain: 'prefilter' only accepts integers and clip inputs")
                           Assert(isCntr  || IsInt(Contrasharp),"SMDegrain: 'Contrasharp' only accepts integers and bool inputs")
    MFilterB             ? Assert(IsClip(mfilter),              "SMDegrain: 'mfilter' only accepts clip inputs")                     : nop()
    isInter              ? Assert(h%4==0,                       "SMDegrain: Interlaced sources require mod 4 height sizes")          : nop()
    RefineMotion         ? Assert(blksize > 7,                  "SMDegrain: For RefineMotion you need a blksize of at least 8")      : nop()
    rc && md!="MDegrain" ? Assert(T3 || T5 || md=="medianTn",   "SMDegrain: Unsupported 'mode' for recursion")                       : nop()
    rc && md!="MDegrain" ? Assert(tr < 3,                       "SMDegrain: Recursion doesn't work with radius over than 3")         : nop()



    # RefineMotion Variables

    halfblksize  = blk2     # MRecalculate works with half block size
    halfoverlap  = ovl2     # Halve the overlap to suit the halved block size
    halfthSAD    = thSADR
    halfthSADC   = thSADC/2 # For MDegrainN()




    # Input preparation for: Interlacing, Motion Filter and MSuper optimization when pel=2

    inputP  = !isInter ? (pel == 2 ? input.AssumeFrameBased()           : input)                             : \
                         (InterPar ? input.AssumeTFF().SeparateFields() : input.AssumeBFF().SeparateFields())

    Mfilter = MFilterB ? MFilter : inputP

    # Prefilter

    nw      = round(w/2.0)
    nh      = round(h/2.0)
    pref8   = preclip ? prefilter                                                                                                                                                                            : inputP
    pref8   = bi > 8  ? pref8.ConvertBits(8, dither=-1, fulls=!tv, fulld=!tv)                                                                                                                                : pref8
    pref8   = UHDhalf ? pref8.BicubicResize(nw+nw%2, nh+nh%2,-0.6,0.4)                                                                                                                                       : pref8
    pref    = UHDhalf ? !(isy(input) || rgb || cplaceCMD=="444") && chroma ? Eval("""pref8.ConvertToYUV"""+cplaceCMD+"""(isInter,"","MPEG1","spline16","top_left")""").ConvertBits(bi, fulls=!tv, fulld=!tv) : pref8 : inputP # Assumes UHD is top_left aligned

    Lthres  = ex_bs(75, 8, bi, tv_in=true, tv_out=tv)

    pref    = !GlobalR ? preclip ? UHDhalf        ?  pref : prefilter                                                                                                                                              : \
                                  (prefilter==-1) ?  pref                                                                                                                                                          : \
                                  (prefilter== 0) ?  pref.ex_MinBlur(0,Chr)                                                                                                                                        : \
                                  (prefilter== 1) ?  pref.ex_MinBlur(1,Chr)                                                                                                                                        : \
                                  (prefilter== 2) ?  pref.ex_MinBlur(2,Chr)                                                                                                                                        : \
                                  (prefilter== 3) ?  pref.ex_FluxSmoothST(2,2,255,0,false,UV=Chr)                                                                                                                  : \
                                  (prefilter== 4) ?  ex_merge(dfttest(pref,sstring="0.0:4.0 0.2:9.0 1.0:15.0",tbsize=1,U=chroma,V=chroma,dither=1,threads=1,sbsize=12,sosize=6,swin=2),pref,                         \
                                                     pref.ex_lut(Format("range_max range_max {Lthres} ymin - / x ymin - * -"),UV=1,clamp_float=true), luma=chroma, UV=Chr)                                         : \
                                  (prefilter== 5) ?  pref.ex_KNLMeansCL(a=2,s=2,d=1,h=7.0,wmode=1,chroma=chroma,device_type="GPU",device_id=device_id,LFR=600*(w/1920.)).ex_boxblur(0.5, mode="weighted", UV=Chr)  : \
                                  (prefilter== 6) ?  pref.ex_BM3D(sigma=10,radius=1,CUDA=true,UV=Chr,tv_range=tv)                                                                                                  : \
                                  (prefilter== 7) ?  pref.ex_DGDenoise(str=0.10,LFR=w/2.,UV=Chr).ex_boxblur(0.5, mode="weighted", UV=Chr)                                                                          : \
                                                     Assert(false, "SMDegrain: Prefilter must be between -1~7: "+string(prefilter))                                                                                : \
                                  pref


    # Default Auto-Prefilter - Luma expansion TV->PC (up to 16% more values for motion estimation)

    pref8  = DefTV && tv || Str > 1.0 ? pref.ex_Luma_Rebuild(S0=Str,c=Amp,     UV=Chr,tv_range=tv)    .ConvertBits(8, dither=-1, fulls=true) : \
             DefTV && tv || Str > 0.0 ? pref.ex_retinex(lo=Str==1?40:(Str)*100,UV=Chr,tv_range=tv)    .ConvertBits(8, dither=-1, fulls=true) : \
                      tv              ? pref.ConvertBits(8, dither=-1, fulls=false, fulld=true) : pref.ConvertBits(8, dither=-1, fulls=true)

    pref8  = LFRB ? pref8.ex_unsharp(thSAD/1800., w/8., 0.0) : pref8     # Low Frequency expansion (higher SAD -> more protection)

    If (sShow ? false : !Show) {

        # Subpixel 3 and 4
        inputP8 = inputP.ConvertBits(8, dither=-1, fulls=!tv, fulld=!tv) # nnedi3 is too slow in HBD
        threads = pelclip && subpixel==4 ? SI_LogicalCores()  : nop()
        cores   = pelclip && subpixel==4 ? SI_PhysicalCores() : nop()
        pclip   = pelclip                ? subpixel==4 && prefilter==-1 ? pref8.  nnedi3_rpow2(rfactor=pel,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=tv?2:1) :  \
                                                                          Undefined()                                                                                                  : nop() # Wiener filter is good enough for MAnalyse
        pclip2  = pelclip && !GlobalR    ? subpixel==4 ?                  inputP8.nnedi3_rpow2(rfactor=pel,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=tv?2:1).ConvertBits(bi, fulls=!tv, fulld=!tv) : \
                                                                          inputP .blackmanresize(w*pel,h*pel,taps=8, src_left=0.25, src_top=0.25)                                      : nop() # from the docs "src_left=0.25, src_top=0.25" for Luma and "src_left = 0.5 for YUY2 and additionally src_top = 0.5" for chroma to match MVTools internal interpolation (for 'MPEG2' chroma placement assumed)


        # Motion vectors search (mt=true requires avstp.dll in plugin path, otherwise ignored)

        super_search = !GlobalR ?                  pelclip ? MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU,          pelclip=pclip, rfilter=rfilter, mt=true) : \
                                                             MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU                        , rfilter=rfilter, mt=true) : nop()
        super_render =                            (pelclip ? MSuper(inputP, pel=pel,                        chroma=plane0, hpad=hpad,  vpad=vpad, levels=1, pelclip=pclip2                , mt=true) : \
                                                             MSuper(inputP, pel=pel, sharp=min(subpixel,2), chroma=plane0, hpad=hpad,  vpad=vpad, levels=1                                , mt=true))
        Recalculate  = !GlobalR && RefineMotion ? (pelclip ? MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU,levels=1, pelclip=pclip                 , mt=true) : \
                                                             MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU,levels=1                                , mt=true)): nop()
            If (!isMult) {
                t2 = isInter ? tr > 1 ? tr*2 : tr : tr
                bv12 =   isInter && (tr > 5)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta =12,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv12) : nop()
                bv12 =   isInter && (tr > 5) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,bv12,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv12
                bv10 =   isInter && (tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta =10,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv10) : nop()
                bv10 =   isInter && (tr > 4) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,bv10,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv10
                bv8  =   isInter && (tr > 3)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 8,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv8)  : nop()
                bv8  =   isInter && (tr > 3) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv8,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv8
                bv6  =               t2 > 5                   ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 6,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv6)  : nop()
                bv6  =               t2 > 5  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv6,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv6
                bv5  =  !isInter ? ((tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 5,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv5)  : nop()) : nop()
                bv5  =  !isInter ? ((tr > 4  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv5,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv5)  : nop()
                bv4  =               t2 > 3                   ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 4,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv4)  : nop()
                bv4  =               t2 > 3  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv4,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv4
                bv3  =  !isInter ? ((tr > 2)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 3,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv3)  : nop()) : nop()
                bv3  =  !isInter ? ((tr > 2  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv3,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv3)  : nop()
                bv2  =  (isInter ||  tr > 1)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 2,  overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv2)  : nop()
                bv2  = ((isInter ||  tr > 1) && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv2,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv2
                bv1  =  !isInter ?                              (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 1,  overlap=    overlap,blksize=   blksize,  search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : bv1)  : nop()
                bv1  =  !isInter ?            ( RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv1,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              bv1)  : nop()

                fv1  =  !isInter ?                              (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 1, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv1)  : nop()
                fv1  =  !isInter ?            ( RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv1,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv1)  : nop()
                fv2  =  (isInter ||  tr > 1)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 2, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv2)  : nop()
                fv2  = ((isInter ||  tr > 1) && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv2,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv2
                fv3  =  !isInter ? ((tr > 2)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 3, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv3)  : nop()) : nop()
                fv3  =  !isInter ? ((tr > 2  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv3,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv3)  : nop()
                fv4  =               t2 > 3                   ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 4, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv4)  : nop()
                fv4  =               t2 > 3  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv4,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv4
                fv5  =  !isInter ? ((tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 5, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv5)  : nop()) : nop()
                fv5  =  !isInter ? ((tr > 4  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv5,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv5)  : nop()
                fv6  =               t2 > 5                   ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 6, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv6)  : nop()
                fv6  =               t2 > 5  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv6,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv6
                fv8  =   isInter && (tr > 3)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 8, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv8)  : nop()
                fv8  =   isInter && (tr > 3) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv8,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv8
                fv10 =   isInter && (tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta =10, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv10) : nop()
                fv10 =   isInter && (tr > 4) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,fv10,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv10
                fv12 =   isInter && (tr > 5)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta =12, overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : fv12) : nop()
                fv12 =   isInter && (tr > 5) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,fv12,   overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion, dct=dct, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                              fv12

                # Scaling vectors for UHD

                if (UHDhalf) {

                bv1  = !isInter             ? !GlobalR ?  bv1.MScaleVect() :  bv1 : nop()             fv1  = !isInter             ? !GlobalR ?  fv1.MScaleVect() :  fv1 : nop()
                bv2  = (isInter ||  tr > 1) ? !GlobalR ?  bv2.MScaleVect() :  bv2 : nop()             fv2  = (isInter ||  tr > 1) ? !GlobalR ?  fv2.MScaleVect() :  fv2 : nop()
                bv3  = !isInter && (tr > 2) ? !GlobalR ?  bv3.MScaleVect() :  bv3 : nop()             fv3  = !isInter && (tr > 2) ? !GlobalR ?  fv3.MScaleVect() :  fv3 : nop()
                bv4  =              t2 > 3  ? !GlobalR ?  bv4.MScaleVect() :  bv4 : nop()             fv4  =              t2 > 3  ? !GlobalR ?  fv4.MScaleVect() :  fv4 : nop()
                bv5  = !isInter && (tr > 4) ? !GlobalR ?  bv5.MScaleVect() :  bv5 : nop()             fv5  = !isInter && (tr > 4) ? !GlobalR ?  fv5.MScaleVect() :  fv5 : nop()
                bv6  =              t2 > 5  ? !GlobalR ?  bv6.MScaleVect() :  bv6 : nop()             fv6  =              t2 > 5  ? !GlobalR ?  fv6.MScaleVect() :  fv6 : nop()
                bv8  =  isInter && (tr > 3) ? !GlobalR ?  bv8.MScaleVect() :  bv8 : nop()             fv8  =  isInter && (tr > 3) ? !GlobalR ?  fv8.MScaleVect() :  fv8 : nop()
                bv10 =  isInter && (tr > 4) ? !GlobalR ? bv10.MScaleVect() : bv10 : nop()             fv10 =  isInter && (tr > 4) ? !GlobalR ? fv10.MScaleVect() : fv10 : nop()
                bv12 =  isInter && (tr > 5) ? !GlobalR ? bv12.MScaleVect() : bv12 : nop()             fv12 =  isInter && (tr > 5) ? !GlobalR ? fv12.MScaleVect() : fv12 : nop()

                            }

                          } else {

                tr2    = tr*2
                vmulti =                   !GlobalR ? super_search.MAnalyse( multi=true,overlap=    overlap,blksize=    blksize, search=search, chroma=chroma, truemotion=truemotion, delta = isInter ? tr2 : tr, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, scaleCSAD=scaleCSAD, mt=true) : vmulti
                vmulti = RefineMotion   ? (!GlobalR ? MRecalculate (Recalculate, vmulti,overlap=halfoverlap,blksize=halfblksize, search=search, chroma=chroma, truemotion=truemotion,    tr = isInter ? tr2 : tr, dct=dct, thSAD=halfthSAD,                                          scaleCSAD=scaleCSAD, mt=true) : vmulti) : vmulti
                vmulti =                   !GlobalR ? (isInter ? vmulti.SelectEvery (4, 2, 3) : vmulti) : vmulti.SelectRangeEvery (Rtr*2, tr2, 0, false)
                vmulti =                   !GlobalR && UHDhalf ? vmulti.MScaleVect()          : vmulti
                                 }


        if (!GlobalO) {

            # Masking when 'mfilter' or 'DCTflicker' is used

            if (MFilterB && (isShrp || (md != "MDegrain"))) {

                               MMin   = plane0 ? mfilter : mfilter.ExtractY()
                               MMsk   = ""
                for (i = 1, tr, 1) {
                    Eval(      Format(  "Mb{i}c = isMult ? nop() : MMask(MMin, bv{i}, ml=50, gamma=2.222, kind=1, Ysc=255, thSCD1=thSCD1, thSCD2=thSCD2)"))
                    Eval(      Format(  "Mf{i}c = isMult ? nop() : MMask(MMin, fv{i}, ml=50, gamma=2.222, kind=1, Ysc=255, thSCD1=thSCD1, thSCD2=thSCD2)"))
                    Eval(      Format("""MMsk   = MMsk + ({i}!=1 ? "," : "") + string(Format("Mb{i}c, 1./(tr*2), Mf{i}c, 1./(tr*2)"))"""))
                }

                Mavg   = !isMult ? Eval("Average("+MMsk+")") : MMask(MMin, vmulti, ml=50, gamma=2.222, kind=1, Ysc=255, thSCD1=thSCD1, thSCD2=thSCD2) }

            if (md != "MDegrain") {


                for (i = 1, tr, 1) {

                    gcv = i==1 && isShrp && isCntr && !SLimit ? "global " : ""

                    Eval(      Format(        "b{i}c = !isMult ? inputP.MCompensate(super_render, bv{i}, thSAD=thSAD, thSAD2=thSAD/2, thSCD1=thSCD1, thSCD2=thSCD2, mt=true) : nop()"))
                    Eval(      Format(        "f{i}c = !isMult ? inputP.MCompensate(super_render, fv{i}, thSAD=thSAD, thSAD2=thSAD/2, thSCD1=thSCD1, thSCD2=thSCD2, mt=true) : nop()"))
                    Eval(gcv + Format(TS||T7? "b{i}c = b{i}c" : """b{i}c = ex_repair(b{i}c, inputP, "undot3", UV=U!=2||V!=2 ? 3 : 1)"""))
                    Eval(gcv + Format(TS||T7? "f{i}c = f{i}c" : """f{i}c = ex_repair(f{i}c, inputP, "undot3", UV=U!=2||V!=2 ? 3 : 1)"""))

                }


                inter =  isMult ? inputP.MCompensate(super_render, vmulti, thSAD=thSAD, thSCD1=thSCD1, thSCD2=thSCD2, mt=true, center=true, tr=tr)
                \ :     (tr==6) ? interleave( f6c, f5c, f4c, f3c, f2c, f1c, inputP, b1c, b2c, b3c, b4c, b5c, b6c )
                \ :     (tr==5) ? interleave(      f5c, f4c, f3c, f2c, f1c, inputP, b1c, b2c, b3c, b4c, b5c      )
                \ :     (tr==4) ? interleave(           f4c, f3c, f2c, f1c, inputP, b1c, b2c, b3c, b4c           )
                \ :     (tr==3) ? interleave(                f3c, f2c, f1c, inputP, b1c, b2c, b3c                )
                \ :     (tr==2) ? interleave(                     f2c, f1c, inputP, b1c, b2c                     )
                \ :               interleave(                          f1c, inputP, b1c                          )


                output = TS               ? inter.TemporalSoften(tr,limit,!plane0?0:limitc,15,2)                             : \
                         md == "medianTn" ? inter.neo_tmedian(radius=tr,Y=plane!=3?3:2, U=U, V=V)                            : \
                         T7               ? inter.ex_FluxSmoothT(tr,limit,UV=plane0?3:1)                                     : \
                                            inter.ex_median(mode=md, thres=limit, recursion=rc, Y=plane!=3?3:1, UV=plane0?3:1)


                output = isMult || TS || T7 || (md == "medianTn") ? output.selectevery(tr*2+1, tr) : output.SelectEvery((T5?2:1)*2+1,T5?2:1)

                if (LFRB) {

                    mfilterLP = inputP.ex_gaussianblur(LFR)
                    DCTF_pass = DCTF ? inputP.smdegrain(tr=ceil(tri/3.),thSAD=thSAD/2,blksize=blksize,prefilter=mfilterLP,pel=1,rfilter=0,str=0,tv_range=false,plane=0,truemotion=false) : nop()  # Calming -Luma- Low Frequency Flicker (aka removing DCT flicker: https://forum.doom9.org/showthread.php?p=1073349#post1073349)
                    mfilterLP = DCTF ? ex_repair(mfilterLP, DCTF_pass.ex_gaussianblur(LFR),"temp4") : mfilterLP
                    outputLP  = output.ex_gaussianblur(LFR)
                    output    = ex_makeadddiff(output, outputLP, mfilterLP, UV=2)
                }

                output = mfilterB ? ex_merge(output, mfilter, Mavg, luma=true, UV=plane0?3:1) : output


            } else {

            # Finally, MDegrain

            MDe= "output  = isInter ?
                \                 ( isMult  ? mfilter.MDegrainN(super_render, vmulti, tr, thSAD2=thSAD/2, thSADC2=halfthSADC,                 thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 6) ? mfilter.MDegrain6(super_render, bv2, fv2, bv4, fv4, bv6, fv6, bv8, fv8, bv10, fv10, bv12, fv12, thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 5) ? mfilter.MDegrain5(super_render, bv2, fv2, bv4, fv4, bv6, fv6, bv8, fv8, bv10, fv10,             thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 4) ? mfilter.MDegrain4(super_render, bv2, fv2, bv4, fv4, bv6, fv6, bv8, fv8,                         thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 3) ? mfilter.MDegrain3(super_render, bv2, fv2, bv4, fv4, bv6, fv6,                                   thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 2) ? mfilter.MDegrain2(super_render, bv2, fv2, bv4, fv4,                                             thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                             mfilter.MDegrain1(super_render, bv2, fv2,                                                       thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true)):
                \                 ( isMult  ? mfilter.MDegrainN(super_render, vmulti, tr, thSAD2=thSAD/2, thSADC2=halfthSADC,                 thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 6) ? mfilter.MDegrain6(super_render, bv1, fv1, bv2, fv2, bv3, fv3, bv4, fv4, bv5, fv5, bv6, fv6,     thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 5) ? mfilter.MDegrain5(super_render, bv1, fv1, bv2, fv2, bv3, fv3, bv4, fv4, bv5, fv5,               thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 4) ? mfilter.MDegrain4(super_render, bv1, fv1, bv2, fv2, bv3, fv3, bv4, fv4,                         thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 3) ? mfilter.MDegrain3(super_render, bv1, fv1, bv2, fv2, bv3, fv3,                                   thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                 (tr == 2) ? mfilter.MDegrain2(super_render, bv1, fv1, bv2, fv2,                                             thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                             mfilter.MDegrain1(super_render, bv1, fv1,                                                       thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true))"

            Eval(MDe)
            rc ? Eval(ReplaceStr(MDe, "mfilter", "output")) : last

            if (LFRB) {

                mfilterLP = mfilter.ex_gaussianblur(LFR)
                DCTF_pass = DCTF ? mfilter.smdegrain(tr=ceil(tri/3.),thSAD=thSAD/2,blksize=blksize,prefilter=mfilterLP,pel=1,rfilter=0,str=0,tv_range=false,plane=0,chroma=false,truemotion=false) : nop()  # Calming -Luma- Low Frequency Flicker (aka removing DCT flicker: https://forum.doom9.org/showthread.php?p=1073349#post1073349)
                mfilterLP = DCTF ? ex_repair(mfilterLP, DCTF_pass.ex_gaussianblur(LFR),"temp4") : mfilterLP
                outputLP  =  output.ex_gaussianblur(LFR)
                output    = ex_makeadddiff(output, outputLP, mfilterLP, UV=2)


            } } }


        # Contrasharp (only sharpens luma)

        if (!GlobalO && isShrp) {

            !SLimit && (!isCntr || (isCntr && md == "MDegrain")) ? Eval("""

                global Super           = super_render
                global cb1             = !isMult ? (isInter ? bv2 : bv1) : vmulti.SelectEvery (tr2, 0)
                global cf1             = !isMult ? (isInter ? fv2 : fv1) : vmulti.SelectEvery (tr2, 1)""") : nop()

                CClip = isCClip  ? (isInter ? (InterPar ? CClip.AssumeTFF().SeparateFields() : CClip.AssumeBFF().SeparateFields()) : CClip) : inputP
                CClip = mfilterB && SLimit  ?  ex_merge(  CClip, mfilter, Mavg, luma=true, UV=plane0?3:1)                          : CClip

        }


        # Globals Output

        GlobalO || Globals == 2  ? (!isMult ? Eval("
        global Super           = super_render # But not required for SMDegrain(Globals=1)
        global bv12            = bv12
        global bv10            = bv10
        global bv8             = bv8
        global bv6             = bv6
        global bv5             = bv5
        global bv4             = bv4
        global bv3             = bv3
        global bv2             = bv2
        global bv1             = bv1

        global fv1             = fv1
        global fv2             = fv2
        global fv3             = fv3
        global fv4             = fv4
        global fv5             = fv5
        global fv6             = fv6
        global fv8             = fv8
        global fv10            = fv10
        global fv12            = fv12
        ") : Eval("
        global bv1             =                                          vmulti.SelectEvery (tr2,  0)
        global bv2             = isInter ? bv1                          : vmulti.SelectEvery (tr2,  2)
        global bv3             =                                          vmulti.SelectEvery (tr2,  4)
        global bv4             = isInter ? vmulti.SelectEvery (tr2,  2) : vmulti.SelectEvery (tr2,  6)
        global bv5             =                                          vmulti.SelectEvery (tr2,  8)
        global bv6             = isInter ? bv3                          : vmulti.SelectEvery (tr2, 10)
        global bv8             = isInter ? vmulti.SelectEvery (tr2,  6) : nop()
        global bv10            = isInter ? bv5                          : nop()
        global bv12            = isInter ? vmulti.SelectEvery (tr2, 10) : nop()

        global fv1             =                                          vmulti.SelectEvery (tr2,  1)
        global fv2             = isInter ? fv1                          : vmulti.SelectEvery (tr2,  3)
        global fv3             =                                          vmulti.SelectEvery (tr2,  5)
        global fv4             = isInter ? vmulti.SelectEvery (tr2,  3) : vmulti.SelectEvery (tr2,  7)
        global fv5             =                                          vmulti.SelectEvery (tr2,  9)
        global fv6             = isInter ? fv3                          : vmulti.SelectEvery (tr2, 11)
        global fv8             = isInter ? vmulti.SelectEvery (tr2,  7) : nop()
        global fv10            = isInter ? fv5                          : nop()
        global fv12            = isInter ? vmulti.SelectEvery (tr2, 11) : nop()
        global Super           = super_render
        global vmulti          = vmulti
        global Rtr             = tr
        ")) : nop()



        output = !GlobalO && isShrp ? isCntr ? ex_ContraSharpening(output, CClip, MC=!SLimit, HD=isHD, overshoot=TS?100:0)                                                             : \
                                      SLimit ? LSFmod(output,source=CClip,preset="LSF",strength=Contrasharp,Smode=isHD?4:5,Lmode=0,edgemode=0,soothe=false,overshoot=0,soft=-2,keep=0) : \
                                               LSFmod(output,             preset="LSF",strength=Contrasharp,Smode=isHD?4:5,Lmode=6,edgemode=0,soothe=false,overshoot=0,soft=-2,keep=0) : output

                 !GlobalO ? (isInter ? output.weave() : output) : input




    } ELSE {



    ##############
    # SHOW PANEL #
    ##############

          # Common Variables

        w2    = float(w)
        h2    = float(h)
        hi    = isInter ? round(h/2.0) : h
        AR    = w2/h2
        lsp   = isInter ? 15 : 30
        lsp   = AR < 1.9 ? lsp : floor(AR < 1.9 ? lsp : ((AR>2.4) ? 0 : lsp-((AR-1.9)*(lsp/(2.4-1.9)))))
        ys    = round(isInter?h2/15:h2/6)
        s     = floor(((isInter?w2/1.6:w2)/720.0)*16.0)

        Wadd  = w2/40
        Wadd2 = Wadd/2
        w1    = round(w2+Wadd+Wadd2)
        w3    = (w2/3)+Wadd/2.1
        w4    = round(w1+w3)
        w3    = round(w1+(w3+Wadd2)*1.96)
        w3sq  = round(w3*1.01)

          # Panel Separator

        if (DefTV && tv || Str > 1.0) {

            sw  = nmod(w2/5.)   sh = sw
            plt = pref8.GradientLinear(zoom=1, positive=true, smooth=true, tv_range=tv)
            plt = plt.ex_Luma_Rebuild(S0=Str,c=Amp,tv_range=tv)
            plt = plt.HistoCurve(size=1,gradient=false)
            plt = plt.BicubicResize(sw,sh,-0.5,0.25)
            plt = PadBorders(plt,w-sw,0,0,h-sh)
            plt = Merge(pref8,rgb?plt.ConverttoPlanarRGB():plt)
            pref8 = ex_merge(pref8,plt,BoxMask(pref8,w-sw,w,0,sh),UV=3)
        }

        pref   = pref8.ConvertBits(min(bi,16), fulls=true)
        pref   = Str == 1 && !chroma ? CombinePlanes(pref, inputP, planes=rgb?"RGB":"YUV", pixel_type=PixelType(input)) : pref
        blkclp = BlankClip(isInter?assumeframebased(pref):pref,length=1,pixel_type=p_type,color=$161616,channels=0)
                 \.crop(0,isInter?h/2%8:h%8,0,0,true).separatefields().assumeframebased().separatefields()

        Interleave(selecteven(blkclp).addborders(2,0,0,0,color=$7f7f7f).crop(0,0,-2,0,true),selectodd(blkclp))

        bi == 32 ? ConvertBits(16, dither=-1, fulls=!tv, fulld=!tv) : last
        WOut=weave().assumefieldbased().weave()
        sep=(hi-height(WOut))/2

        StackHorizontal(pref,WOut.addborders(0,sep-sep%2,0,hi-(height(WOut)+(sep-sep%2)),color=$161616))


          # Color Guide Squares

        a=h*(isInter?0.37:0.74)       aa=h*(isInter?0.3835:0.767)
        b=h*(isInter?0.40:0.80)       bb=h*(isInter?0.4135:0.827)
        c=h*(isInter?0.43:0.86)       cc=h*(isInter?0.4435:0.887)

        ex_merge(Expr("127 scalef" ,"183 scalef" ,"47  scalef") ,ex_lutspa(Format("x {w3} >= x {w3sq} <= & y {a} >= y {aa} <= & & range_max 0 ?")),luma=true)
        ex_merge(Expr("81  scalef" ,"91  scalef" ,"240 scalef") ,ex_lutspa(Format("x {w3} >= x {w3sq} <= & y {b} >= y {bb} <= & & range_max 0 ?")),luma=true)
        ex_merge(Expr("210 scalef" ,"16  scalef" ,"146 scalef") ,ex_lutspa(Format("x {w3} >= x {w3sq} <= & y {c} >= y {cc} <= & & range_max 0 ?")),luma=true)


          # Parameters List

        blue   = sShow && (show=="Speed"  )
        red    = sShow && (show=="Memory" )
        yellow = sShow && (show=="Quality")

        Color  = sShow ? (blue   ? $00aef0 : \
                          red    ? $ff0000 : \
                          yellow ? $ffff00 : \
                          Assert(false,    "SMDegrain: Revise typo for possible color guide modes: 'Speed','Memory','Quality'")) : nop()


        varn = "\n\n\n\n\n"
        sp   = !GlobalR && str==1.0 ? "  " : ""

        Subtitle("SMDegrain Mod v3.4.7",text_color=red||blue||yellow?Color:$7f7f7f,halo_color=$000000,font="VERDANA",size=s*2,x=w1,y=isInter?h/50:h/20)

        Subtitle("BASIC"   ,lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(            "\n\ntr           = " + string(tr)                                                                              + \
                 varn+varn+      "chroma       = " + string(chroma)                                                                          ,lsp=lsp,text_color=red||blue               ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(          "\n\n\nthSAD(C)     = " + string( GlobalO?"bypass":string(thSAD)     + "(" + string(plane0?thSADC:"bypass") + ")")+ \
                 varn+           "CClip        = " + string( GlobalO?"bypass":(Defined(CClip)?"defined":"Undefined"))                        + \
                             "\n\nInterlaced   = " + string(isInter)                                                                         ,lsp=lsp,text_color=                               $ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+           "RefineMotion = " + string( GlobalO?"bypass":RefineMotion)                                                  ,lsp=lsp,text_color=yellow                  ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+       "\n\nContrasharp  = " + string( GlobalO?"bypass":contrasharp)                                                   ,lsp=lsp,text_color=yellow&&!GlobalO        ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+varn+    "\nplane        = " + string( GlobalO?"bypass":(plane==0?"0 (Luma)":plane==1?"1 (U plane)":plane==2?"2 (V plane)":plane==3?"3 (Chroma)":"4(Luma+Chroma)")),lsp=lsp,text_color=(red||blue)&&!GlobalO?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle("<-- "+string(IsClip(prefilter)||prefilter!=-1?"Prefiltered clip converted\n    to PC levels":"Clip converted to PC levels\n   ")+" for the motion search", lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1-10,y=(isInter?h/2:h)-round(ys/1.5))

        Subtitle("ADVANCED",lsp=lsp,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(              "\n\npel        = " + string(pel)                                                                             ,lsp=lsp,text_color=red                     ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(            "\n\n\nsubpixel   = " + string( pel==1 ?"bypass":subpixel)                                                      ,lsp=lsp,text_color=(yellow||blue)&&pel!=1  ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+varn+  "\n\n\ntruemotion = " + string( GlobalR?"bypass":truemotion)                                                    ,lsp=lsp,text_color=(yellow||blue)&&!GlobalR?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+             "mfilter    = " + string( GlobalR?"bypass":MFilterB?"Clip"+sp+" Variable":"OFF")                          ,lsp=lsp,text_color=                               $7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+         "\n\nStr        = " + (GlobalR?string("bypass"):string(Str,"%1.2f"))+sp+" Brightness"                         + \
                 varn+             "search     = " + string( GlobalR?"bypass":search)                                                        ,lsp=lsp,text_color=yellow&&!GlobalR        ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+varn+        "blksize    = " + string( GlobalR?"bypass":blksize)                                                       + \
                                 "\noverlap    = " + string( GlobalR?"bypass":overlap)                                                       ,lsp=lsp,text_color=(red||blue)&&!GlobalR   ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+           "\nprefilter  = " + (GlobalR?string("bypass"):(preclip?"Clip"+sp+" Variable":(prefilter==0?"0"+sp+"    MinBlur(0)":prefilter==1?"1"+sp+"    MinBlur(1)":prefilter==2?"2"+sp+"    MinBlur(2)":prefilter==3?"3"+sp+"    FluxSmoothST":prefilter==4?"4"+sp+"    DFTTest":prefilter==5?"5"+sp+"    KNLmeans":prefilter==6?"6"+sp+"    BM3D":prefilter==7?"7"+sp+"    DGDenoise":"OFF"+sp+"    (-1)"))) + \
                               "\n\nAmp        = " + (GlobalR||str==1.0?string("bypass"):string(Amp,"%1.2f"))+" Amplitude"                   + \
                 varn+           "\nlimit(C)   = " + (GlobalO?string("bypass"):string(limit)     + "(" + string(limitc) + ")")               ,lsp=lsp,text_color=                               $7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)

        Subtitle("OTHERS"  ,lsp=lsp,text_color=$494949,font="COURIER NEW",size=s,x=w3,y=ys)
        Subtitle(             "\n\n\nthSCD1(2) = " + (GlobalO?string("bypass"):string(thSCD1) + "(" + string(thSCD2) + ")")                  + \
                           varn+"\n\nGlobals   = " + string(Globals==0 ? "0 (OFF)" : Globals==1 ? "1 (Import)" : Globals==2 ? "2 (Export)" : "3 (E.Only)"),lsp=lsp,text_color=                  $494949,font="COURIER NEW",size=s,x=w3,y=ys)
        Subtitle(               "\n\nhpad(v)   = " + string(hpad)   + "(" + string(vpad)   + ")"                                             ,lsp=lsp,text_color=red||blue               ?Color:$494949,font="COURIER NEW",size=s,x=w3,y=ys)
        Subtitle(varn+              "bitdepth  = " + string(bi)                                                                              ,lsp=lsp,text_color=yellow||blue            ?Color:$494949,font="COURIER NEW",size=s,x=w3,y=ys)

        Subtitle("   Speed"   ,lsp=isInter?15:30,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(a-1))
        Subtitle("   Memory"  ,lsp=isInter?17:34,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(b-1))
        Subtitle("   Quality" ,lsp=isInter?19:38,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(c-1))
        } }





########################################################
#                                                      #
#       HELPER FUNCTIONS: Prefilters                   #
#                                                      #
########################################################


########################################
## Didée's functions:
##
## MinBlur   by Didée (24-10-2006)
## Minimum Blur - Nifty Gauss/Median combination (spatial version of FluxSmoothT)
## (https://forum.doom9.org/showthread.php?p=1018488#post1018488)
##
## kgrabs: "Pixelwise median and blur admixture. If the differences are homologous to the input,
##          the weaker result of the two are taken, else the source pixel is passed"
##
## Didée: Edges are meant to be "calmed". Quote: "you'll end up with pretty big SADs wherever there's an edge.
##        Means, little to nothing will happen on edges. Which is quite counterproductive when the goal is to calm (the effect of) a sharpener"
##
## Optimized (~58% speed gain for r=1), updated and ported to ExTools by Dogway (25-08-2021)
## Output is slightly different by default, medians have been replaced with edge retaining versions...
## and a following blur to "calm" edges (read Didée's quote above). Enable 'old' for old output.
##
## Function Definition:
##    (
##    clip,
##    int r=1 (0 to 3 by 1),
##    string "mode"="median" ("median" / "blur" / "blur_horizontal" / "blur_vertical"),
##    [int thres=20 (0 to 255 by 1)],
##    bool "sharp"=false,
##    bool "old"=false,
##    )
##
function ex_MinBlur(clip clp, int "r", int "UV", string "mode", bool "sharp", int "thres", bool "old", int "Y") {

    rgb     = isrgb(clp)
    bi      = BitsPerComponent(clp)
    fs      = propNumElements (clp,"_ColorRange")  > 0 ? \
              propGetInt      (clp,"_ColorRange") == 0 : rgb

    r       = Default(r,  1)
    Y       = Default(Y,  3)
    UV      = Default(UV, rgb ? 3 : 1)
    mode    = Default(mode, "median")
    th      = Default(thres, Undefined())   # Spatial threshold (only for rad >= 2 and old=false)
    sh      = Default(sharp,   false)       # Recover edges (in old method) or remove blur (for new method)
    old     = Default(old,     false)       # Enable to use the old method with classic "dumb" medians

    rg4   = (uv==3) ? 4  : -1
    rg12  = (uv==3) ? 12 : -1
    rg20  = (uv==3) ? 20 : -1
    rg27  = (uv==3) ? 27 : -1
    rg4y  = (y ==3) ? 4  : -1
    rg12y = (y ==3) ? 12 : -1
    rg20y = (y ==3) ? 20 : -1
    rg27y = (y ==3) ? 27 : -1
    med   = mode=="median"
    rg4v  = med && (r<=1)
    bi32  = bi == 32 ? "" : "range_half -"

    blurstr = mode == "median"          ? """ex_median("smart"+string(r), th, UV=uv)""" : \
              mode == "blur"            ? """ex_boxblur(r*2, r*2, "weighted", UV=uv)""" : \
              mode == "blur_horizontal" ? """ex_boxblur(r*2,   0, "weighted", UV=uv)""" : \
              mode == "blur_vertical"   ? """ex_boxblur(0,   r*2, "weighted", UV=uv)""" : \
              mode

    rg12D = (r==0) ? ex_makediff(clp,clp.ex_sbr(Y=y,UV=uv),      Y=y,UV=uv,fulls=fs)                                               : \
            (r==1) ? ex_makediff(clp,clp.removegrain(rg12y,rg12),Y=y,UV=uv,fulls=fs)                                               : \
            (r==2) ? ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20),Y=Y,UV=UV,fulls=fs)                       : \
                     ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20).removegrain(rg20y,rg20),Y=y,UV=uv,fulls=fs)

    RG4D  =  old               ? (rg4v) ? clp.removegrain(rg4y,rg4)   : med ? clp.ex_median(r==2?"median5":"median7",UV=uv)  : Eval("clp."+blurstr+"") :\
                                 (rg4v) ? clp.removegrain(rg27y,rg27)                                                        : Eval("clp."+blurstr+"")
    RG4D  = !old && !sh && med ? (r<=1) ? RG4D.ex_boxblur(r==0?0.3:0.5,mode="weighted",UV=uv) : RG4D.removegrain(rg12y,rg12) : RG4D

    ex_lutxyz(clp, rg12D, RG4D,"y "+bi32+" A@ x z - B@ * 0 < x A abs B abs < x A - z ? ?",Y=y,UV=uv,fulls=fs)

    (!old && !med || old) && sh ? Repair(clp.removegrain(y!=3 ? 0 : 17,uv==3 ? 0 : -1),y!=3 ? 0 : 9, 0) : last }


## sbr()   by Didée (25-03-2009)
## Sharp Blur Repair - Make a highpass on a blur's difference (well, kind of that)
## (https://forum.doom9.org/showthread.php?p=1265491#post1265491)
##
## kgrabs: "Takes a blur's difference and performs a blurring of the difference.
##          If both differences are homologous to the input, the weaker result is taken, else the source pixel is passed"
##
## Highpass of spatial r=1 Gaussian (like blur(1.0))

function ex_sbr(clip c, int "r", int "Y", int "UV") {

    rgb    = isrgb(c)
    bi     = BitsPerComponent(c)
    fs     = propNumElements (c,"_ColorRange")  > 0 ? \
             propGetInt      (c,"_ColorRange") == 0 : rgb

    r      = Default(r,  1)
    Y      = Default(Y,  3)
    UV     = Default(UV, rgb ? 3 : 1)
    Y31    = (Y==3)  ?  3 :  1
    UV31   = (UV==3) ?  3 :  1
    Y12    = (Y==3)  ? 12 : -1
    Y20    = (Y==3)  ? 20 : -1
    UV12   = (UV==3) ? 12 : -1
    UV20   = (UV==3) ? 20 : -1
    bi32m  = bi == 32 ? "" : "range_half -"

    rg12   = (r<=1) ?     c.removegrain(Y12, UV12)                                             : \
             (r==2) ?     c.removegrain(Y12, UV12).removegrain(Y20, UV20)                      : \
                          c.removegrain(Y12, UV12).removegrain(Y20, UV20).removegrain(Y20, UV20)

    rg12D  = ex_makediff(c, rg12, UV=UV31, fulls=fs)

    RG12DS = (r<=1) ? rg12D.removegrain(Y12, UV12)                                             : \
             (r==2) ? rg12D.removegrain(Y12, UV12).removegrain(Y20, UV20)                      : \
                      rg12D.removegrain(Y12, UV12).removegrain(Y20, UV20).removegrain(Y20, UV20)

    ex_lutxyz(c, RG12D, RG12DS, "y z - A@ y "+bi32m+" B@ * 0 < x A abs B abs < A B ? x swap - ?", Y=Y31, UV=UV31, fulls=fs) }


## Dither_Luma_Rebuild()  by cretindesalpes (02-01-2012)
## https://forum.doom9.org/showthread.php?p=1548318
## Converts luma (and chroma) to PC levels, and optionally allows tweaking for pumping up the darks. (for the clip to be fed to motion search only)
##
## Function Definition:
##    (
##    clip,
##    float S0=1.0 (1.0 to 9.0 by 0.1),
##    float c=0.0625 (0.0 to 1.0 by 0.01),
##    bool "show"=false,
##    )
##
function ex_Luma_Rebuild (clip src, float "s0", float "c", int "Y", int "UV", bool "tv_range", bool "show") {

    rgb   = isrgb(src)
    bi    = BitsPerComponent(src)
    fs    = propNumElements (src,"_ColorRange")  > 0 ? \
            propGetInt      (src,"_ColorRange") == 0 : rgb

    Y     = Default(Y,       3)
    UV    = Default(UV,      3)
    s0    = Default(s0,    3.0)
    c     = Default(c,  1.0/16)
    tv    = Default(tv_range, !fs)
    sh    = Default(show,   false)
    bi32  = bi == 32
    si    = tv ? bi32 && UV==3 ? "floatUV" : "none" : "intf"

    s0= max(s0,1.0)
    k = (s0 - 1) * c
    l = 1 - k
    d = 1 + c
    f = d * c
    t = tv ? "ymin - 0 max ymax ymin - /" : ""
    e = S0 > 1.0 ? Format("f32 {k} {d} {f} x "+t+" A@ {c} + / - * A {l} * +") + (tv && !bi32 ? " range_max *" : "") : \
        tv       ?        "x ymin - 0 max range_max ymax ymin - / * "                                               : \
                          ""

    ec = tv ? "x cmin - range_max cmax cmin - / *" : ""

    ex_lut(src, e, rgb ? e : ec, Y=y, UV=uv, fulls=!tv, scale_inputs=si, clamp_float=bi32)
    !tv && S0 <= 1.0 ? src : PropSet("_ColorRange", 0)

    if (sh) {

        bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
        w   = src.width()
        h   = src.height()
        sw  = nmod(w/5.)   sh = sw
        plt = GradientLinear(last, zoom=1, positive=true, smooth=true, tv_range=tv)
        plt = ex_Luma_Rebuild(plt,s0,c,tv_range=tv)
        plt = HistoCurve(plt,size=1,gradient=false).BicubicResize(sw,sh,-0.5,0.25)
        plt = PadBorders(plt,w-sw,0,0,h-sh)
        plt = Merge(last,rgb ? plt.ConverttoPlanarRGB() : plt)
        ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
    } }




## ex_retinex()   by Dogway (03-11-2021)
##
## Multi-Scale Retinex
## Optimized MSR for only Luma channel, akin to MSRCP but without going through RGB.
## Output is PC range.  Performance is by default 50% of ex_Luma_Rebuild() although still fast and quality isn't comparable.
## lvl=2 uses auto-levels so performance drops to 25% of ex_Luma_Rebuild(), and prone to some smooth flicker.
## Gamma aware + PC levels blurring didn't yield better results, actually worse. RGB isn't supported yet despite code reference.
##
## "Contrast enhancement is a classic image restoration technique that traditionally has been performed using forms of histogram equalization.
## While effective these techniques often introduce unrealistic tonal rendition in real-world scenes. This paper explores the use of Retinex theory to perform
## contrast enhancement of real-world scenes. We propose an improvement to the Multi-Scale Retinex algorithm which enhances its ability to perform
## dynamic range compression while not introducing halo artifacts and greying."
##
## [2] P. Robinson, Y. Roodt and A. Nel. "Adaptive Multi-Scale Retinex algorithm for contrast enhancement of real world scenes".
##     In the Proceedings of Twenty - Third Annual Symposium of the Pattern Recognition Association of South Africa, Pretoria, South Africa,
##     Edited by Alta de Waal, November 29 - 30, 2012.
##
## Dependencies:
##               ExTools
##               GradePack
##               ResizersPack
##               TransformsPack (for RGB)
##
##
## Function Definition:
##    (
##    clip,
##    int lvl=1 (0 to 2 by 1),
##    float lo=40.0 (0.0 to 128.0 by 1.0),
##    float hi=242.0 (128.0 to 255.0 by 1.0),
##    float sigma=1.0 (1.0 to 5.0 by 0.1),
##    )
##
function ex_retinex(clip clp, int "lvl", float "lo", float "hi", float "sigma", bool "tv_range", int "UV") {

    rgb  = isRGB(clp)
    bi   = BitsPerComponent(clp)
    fs   = propNumElements (clp,"_ColorRange")  > 0 ? \
           propGetInt      (clp,"_ColorRange") == 0 : rgb

    lvl  = Default(lvl,          1)         # 0: MSR output   1: Fixed levels output  2: auto-levels
    lo   = Default(lo, lvl==1?40:4)         # value in PC levels of low  level for normalization in lvl=1. For lvl=2 the divisor for the low level percentile (Reminder: crop black borders)
    hi   = Default(hi,   255-lo/3.)         # value in PC levels of high level for normalization in lvl=1.
    r    = Default(sigma,        1)         # Multiplier. 1 to 5 roughly (leave it at 1 for the most time)
    tv   = Default(tv_range,   !fs)         # Range of input clip
    UV   = Default(UV, rgb ? 3 : 1)         # Set to 3 to convert Chroma to PC range
    bi32 = bi==32
    si   = tv ? bi32 && UV==3 ? "floatUV" : "none" : "intf"

    w    = max(clp.Width(),clp.Height())

    a    = !rgb ? clp.ExtractY() : clp.DotClip([0.298903,0.586620,0.114477])
    y    = a.ConvertBits(8, dither=-1, fulls=!tv, fulld=!tv)
    b    = y.ex_GaussianBlur(w*0.015 * r,pad=false).ConvertBits(bi, fulls=!tv, fulld=!tv)
    c    = y.ex_GaussianBlur(w*0.05  * r,pad=false).ConvertBits(bi, fulls=!tv, fulld=!tv)
    d    = y.ScriptClip(function [] () { ex_lut(string(AverageLuma(last))) } ).ConvertBits(bi, fulls=!tv, fulld=!tv)

    rangePC =                        tv ? "ymin - ymax ymin - /" : ""
    str     = Format("f32 x "+rangePC+" 0.002 max A@ log y 0.2 * z 0.1 * a 0.7 * + + "+rangePC+" A * log / 1 swap -") + (tv && !bi32 ? " range_max *" : "")
    cstr    = rgb ? str : UV == 3 && tv ? "x cmin - range_max cmax cmin - / *" : ""

    MSR     = ex_lutxyza(a,b,c,d, str, cstr, UV=uv, fulls=!tv, scale_inputs=si, clamp_float=bi32)


    if        (lvl==0) {

        MSR

    } else if (lvl==1) {

        MSR.ex_levels(lo, 1.0, hi, 0, 255,false,rgb?3:1)

    } else {

        RR  = MSR.ConvertBits(8, dither=-1, fulls=false).RatioResize(0.20,"%",kernel="Bilinear")

        b2  = RR.selectevery(1,-2)
        b   = RR.selectevery(1,-1)
        f   = RR.selectevery(1,+1)
        f2  = RR.selectevery(1,+2)

        TS  = Expr(RR,b2,b,f,f2,"x y z a b + + + + 0.2 *")

        b2  = TS.selectevery(1,-2)
        b   = TS.selectevery(1,-1)
        f   = TS.selectevery(1,+1)
        f2  = TS.selectevery(1,+2)

        TS  = Expr(TS,b2,b,f,f2,"x y z a b + + + + 0.2 *")

        ScriptClip(MSR, function [MSR,TS,rgb,lo] () {

            sts  = PlaneMinMaxStats(TS, 1./lo, 0, 0, false)
            pmin = sts[2]
            pmax = sts[1]

            pmin > 0 || pmax < 255 ? MSR.ex_levels(pmin,1.0,pmax,0,255,false,rgb?3:1) : MSR
        } )
    }

    UV == 3 ? CombinePlanes(last, clp, planes=rgb?"RGB":"YUV", pixel_type=PixelType(clp)).propCopy(clp) : last
              PropSet("_ColorRange", 0) }



# Wrapper for BM3D CUDA by WolframRhodium for AviSynth+
# Requires TransformsPack for OPP=true, RGB clips or processing chroma
#
# Disclaimer: ffvideosource() causes issues with BM3D for UV=1 or r>3
#             BM3D() causes issues when CUDA=true and you crop with DGSource()
#             BM3D() causes issues when CUDA=true and a high combination of radius + sigma unless you fine tune 'block_step' argument
#
#   # Some of the following arguments aren't available on the BM3D AVS+ port but included here for reference (namely group_size, block_size, bm_step and ps_step)
#
#   "fast" - Fast Profile (default)
#   "lc"   - Low Complexity Profile
#   "np"   - Normal Profile
#   "high" - High Profile
#   "vn"   - Very Noisy Profile
#
#   bm3d.Basic / bm3d.Final / bm3d.VBasic / bm3d.VFinal
#   ----------------------------------------------------------------------------
#   | profile || block_size | block_step | group_size  | bm_range    | bm_step |
#   ----------------------------------------------------------------------------
#   | "fast"  || 8/8/8/8    | 8/7/8/7    | 8/8/8/8     | 9/9/7/7     | 1/1/1/1 |
#   | "lc"    || 8/8/8/8    | 6/5/6/5    | 16/16/8/8   | 9/9/9/9     | 1/1/1/1 |
#   | "np"    || 8/8/8/8    | 4/3/4/3    | 16/32/8/8   | 16/16/12/12 | 1/1/1/1 |
#   | "high"  || 8/8/8/8    | 3/2/3/2    | 16/32/8/8   | 16/16/16/16 | 1/1/1/1 |
#   | "vn"    || 8/11/8/11  | 4/6/4/6    | 32/32/16/16 | 16/16/12/12 | 1/1/1/1 |
#   ----------------------------------------------------------------------------

#   bm3d.VBasic / bm3d.VFinal
#   ---------------------------------------------------
#   | profile || radius | ps_num | ps_range | ps_step |
#   ---------------------------------------------------
#   | "fast"  || 1/1    | 2/2    | 4/5      | 1/1/1/1 |
#   | "lc"    || 2/2    | 2/2    | 4/5      | 1/1/1/1 |
#   | "np"    || 3/3    | 2/2    | 5/6      | 1/1/1/1 |
#   | "high"  || 4/4    | 2/2    | 7/8      | 1/1/1/1 |
#   | "vn"    || 4/4    | 2/2    | 5/6      | 1/1/1/1 |
#   ---------------------------------------------------
#
# Function Definition:
#    (
#    clip,
#    float sigma=3.0 (1.0 to 10.0 by 0.5),
#    int radius=1 (1 to 5 by 1),
#    string preset="Low" ("Fast" / "Low" / "Normal" / "High" / "Noisy"),
#    bool CUDA=false,
#    bool OPP=true,
#    )
#
function ex_BM3D(clip a, float "sigma", int "radius", bool "CUDA", string "preset", bool "OPP", int "UV", bool "tv_range") {

    rgb = isRGB(a)
    isy = isy  (a)
    bi  = BitsPerComponent(a)
    pID = color_propGet   (a)

    s   = Default(sigma,    3)    # Denoising strength
    cd  = Default(CUDA,    true)
    md  = Default(preset, "Low")  # Fast, Low, Normal, High, Noisy
    OPP = Default(OPP,   rgb)
    UV  = Default(UV,    rgb ? 3 : 1)
    tv  = Default(tv_range, pID[6])
    pri = pID[2]
    mat = (!tv?"PC":"Rec")+pri

    pr = md == "Fast"   ? 0 : \
         md == "Low"    ? 1 : \
         md == "Normal" ? 2 : \
         md == "High"   ? 3 : \
         md == "Noisy"  ? 4 : \
             Assert(false, "ex_BM3D: Wrong 'preset' mode")

#                                             fast      lc          np            high           vn
    r          = Default( radius, Select(pr,  1,         2,         3,             4,             4          ) ) # temporal radius
    block_step =                  Select(pr, [8,7,8,7], [6,5,6,5], [4,3,4,3],     [3,2,3,2],     [4,6,4,6]     )
    bm_range   =                  Select(pr, [9,9,7,7], [9,9,9,9], [16,16,12,12], [16,16,16,16], [16,16,12,12] )
    ps_range   =                  Select(pr, [4,5] ,    [4,5] ,    [5,6],         [7,8],         [5,6]         )

    r          = cd ? min(r,3) : r # Buggy when r > 3
    block_step = cd && (pr==0 || pr==2) ? ArrayOp(block_step,1,"-") : block_step

    a
    ch = !(isy || UV!=3)
    ch && !rgb && !OPP ? ConverttoYUV444   (matrix=mat,chromaresample="spline16") : last
          !rgb &&  OPP ? ConvertToPlanarRGB(matrix=mat,chromaresample="spline16") : last
           rgb ||  OPP ? RGB_to_OPP().ConvertBits(32, fulls=true, fulld=true)     : ConvertBits(32, fulls=!tv, fulld=!tv)

    cs = rgb || OPP ? s : ch ? s/2 : 0

    cd ? BM3D_CUDA(sigma=[s,cs,cs], radius=r, chroma=ch, block_step=block_step, bm_range=bm_range, ps_range=ps_range, fast=true, extractor_exp=6) : \
         BM3D_CPU (sigma=[s,cs,cs], radius=r, chroma=ch, block_step=block_step, bm_range=bm_range, ps_range=ps_range)
         BM3D_VAggregate(radius=r)

    if (rgb || OPP) {
        bi != 32 ? ConvertBits(bi, dither=1, fulls=true, fulld=true) : last
        OPP_to_RGB()
        !rgb && OPP ? MatchClip(a,matrix=pri) : last
    } else if (ch) {
        MatchClip(a,matrix=pri)
    } else {
        bi != 32 ? ConvertBits(bi, dither=1, fulls=!tv, fulld=!tv) : last
        MergeChroma(a) } }




## ex_DGDenoise() - DGDenoise GPU denoiser wrapper
##
## Output is soft, similar to Photoshop's Surface Blur, so works well as prefilter, specially for anime.
## Supports YUV format in any bitdepth
##
## Function Definition:
##    (
##    clip,
##    float str=0.15 (0.0 to 1.0 by 0.01),
##    float strc=0.15 (0.0 to 1.0 by 0.01),
##    float bl=0.0 (0.0 to 1.0 by 0.01),
##    float blc=0.0 (0.0 to 1.0 by 0.01),
##    int "searchw"=9 (5 to 9 by 2),
##    int "UV"=3 (1 to 3 by 1),
##    )
##
function ex_DGDenoise(clip a, float "str", float "strc", float "blend", float "blendc", int "searchw", float "LFR", bool "DCT", int "UV") {

    w   = width (a)
    h   = height(a)
    is42= is420 (a)
    bi  = BitsPerComponent(a)
    pID = color_propGet   (a)

    str  = Default(str,      0.10)
    strc = Default(strc,   str/2.)
    bl   = Default(blend,       0)
    blc  = Default(blendc,      0)
    srch = Default(searchw,  min(9,max(5,round(w/1.51>h?0.375*w+1.8:0.667*h+1.8))))
    LFR  = Default(LFR,         0)
    DCT  = Default(DCT,     false)
    UV   = Default(UV,          1)
    strc = UV==3 ? strc : 0
    tv   = pID[6]
    pri  = pID[2]
    mat  = (!tv?"PC":"Rec")+pri

    a
    !is42 ? ConverttoYUV420(matrix=mat,chromaresample=UV==3?"spline16":"point") : last
    bi>8 && bi!= 16 ? ConvertBits(16, fulls=!tv, fulld=!tv)                     : last

    DGDenoise(str,strc,bl,blc,srch)

    ConvertBits(bi, dither=bi==32?-1:1, fulls=!tv, fulld=!tv)
    LFR > 0 ? ex_LFR(a,LFR,DCT,UV=UV)  : last
    !is42   ? MatchClip(a,matrix=pri)  : last }



## ex_KNLMeansCL() - KNLMeansCL wrapper by Dogway (08-02-2022)
##
##
## Function Definition:
##    (
##    clip,
##    float h=7.0 (1.0 to 15.0 by 0.5),
##    int d=0 (0 to 6 by 1),
##    int a=1 (1 to 6 by 1),
##    int s=2 (1 to 6 by 1),
##    int wmode=0 (0 to 2 by 1),
##    [int "LFR"=1920 (50 to 1920 by 1),]
##    bool "chroma"=true,
##    )
##
function ex_KNLMeansCL (clip c, float "h", int "d", int "a", int "s", int "wmode", clip "rclip", float "LFR", bool "chroma", string "device_type", int "device_id", float "wref", string "knlm_params") {


    w2           = c.width()
    h2           = c.height()

    h            = Default( h, 7.0)         # Sigma
    d            = Default( d, 0)           # Temporal radius
    a            = Default( a, 1)           # Spatial  radius
    s            = min(Default( s, a*2),8)  # Spatial  radius of the similarity neighborhood
    wmode        = Default( wmode, 0)
    wref         = Default( wref, 1.0)
    deviceid     = Default( device_id, 0)
    chroma       = Default( chroma, true)
    LFR          = Default( LFR, wmode < 1 || d > 0 ? min(2,d+1)*300*(w2/1920.) : 0) # Restore low frequency details, specially on wmode=0, and more specially with d > 0 (motion estimation is very bad in KNLMeansCL). Set to 0 to disable.
    knlm_params  = Defined( knlm_params) ? ","+knlm_params : ""

    isy     = c.isy()
    rgb     = c.isrgb()
    fullchr = c.is444()
    chr420  = c.is420()

    stacked = chroma && !fullchr && !isy
    UV      = stacked ? "Y" : rgb ? "auto" : !isy && chroma ? "YUV" : "Y"
    UVb     = chroma ? 3 : 2
    dwclip  = Defined( rclip )
    wclip   = dwclip ? rclip : Undefined()

    # Beware chroma placement, revise
    If (stacked && !rgb) {

        Uclip   =          ExtractU(c)
        Uwclip  = dwclip ? ExtractU(wclip) : nop()
        Vclip   =          ExtractV(c)
        Vwclip  = dwclip ? ExtractV(wclip) : nop()
        UVstack = chr420 ? StackVertical  (Uclip, Vclip)              : \
                           StackHorizontal(Uclip, Vclip) # otherwise 422 horizontal stack
        UVwstack= dwclip ? (chr420 ? StackVertical  (Uwclip, Vwclip)  : \
                                     StackHorizontal(Uwclip, Vwclip)) : nop()

        nlc     =          StackHorizontal(ExtractY(c),    UVstack )
        nlrc    = dwclip ? StackHorizontal(ExtractY(wclip),UVwstack) : Undefined()

        nlckl   = Eval("  nlc.KNLMeansCL(D=d, A=a, h=h, s=s, device_type=device_type, device_id=deviceid, rclip=nlrc,  wmode=wmode, wref=wref, channels=UV" + knlm_params + ")")
        nlc     = LFR > 50 ? ex_LFR(nlckl,nlc,LFR,false,UV=UVb) : nlckl

        uvw     = Uclip.width ()
        uvh     = Uclip.height()

        nly     =          nlc.crop(0,0,chr420 ? -uvw : -(uvw+uvw),0, true)

        nlu     = chr420 ? nlc.crop(w2,0,0,-uvh,  true) : \
                           nlc.crop(w2,0,-uvw,0,  true)
        nlv     = chr420 ? nlc.crop(w2,uvh,   0,0,true) : \
                           nlc.crop(w2+uvw,0,0,0 ,true)

                  CombinePlanes(nly, nlu, nlv, planes="YUV", pixel_type=PixelType(c))

        } else {

                out = Eval("c.KNLMeansCL(D=d, A=a, h=h, s=s, device_type=device_type, device_id=deviceid, rclip=wclip, wmode=wmode, wref=wref, channels=UV" + knlm_params + ")")
                out = LFR > 50 ? ex_LFR(out,c,LFR,false,UV=UVb) : out
                out

        } }
