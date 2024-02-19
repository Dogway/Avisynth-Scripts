################################################################################################
###                                                                                          ###
###                                Simple MDegrain Mod - SMDegrain()                         ###
###                                                                                          ###
###                       Mod by Dogway - Original idea by Didée and Caroliano               ###
###                                                                                          ###
###           Special Thanks: Sagekilla, Didée, cretindesalpes, Gavino and MVtools devs      ###
###                                                                                          ###
###                       v0.2.0       by Caroliano - 24 Jan  2010                           ###
###                       v0.4.0d      by Dogway    - 03 Sep  2011                           ###
###                       v3.1.2d      by Dogway    - 21 Jul  2015                           ###
###                       v3.1.2.111s  by A.SONY.   - 09 Feb  2021                           ###
###                       v4.5.1d      by Dogway    - 19 Feb  2024                           ###
###                                                                                          ###
###                                                                                          ###
### Main:                                                                                    ###
###      SMDegrain                                                                           ###
### Prefilters:                                                                              ###
###      ex_MinBlur                                                                          ###
###      ex_sbr                                                                              ###
###      ex_Luma_Rebuild                                                                     ###
###      ex_retinex                                                                          ###
###      ex_BM3D                                                                             ###
###      ex_DGDenoise                                                                        ###
###      ex_KNLMeansCL                                                                       ###
###                                                                                          ###
################################################################################################
###
### SMDegrain() - Simple MDegrain Mod
###
### Support thread:               https://forum.doom9.org/showthread.php?t=182881
### Based on Caroliano's concept: https://forum.doom9.org/showthread.php?t=152326
### Also  on Didée's     concept: https://forum.doom9.org/showthread.php?p=1076491
###
### General purpose temporal denoise filter. Basically a wrapper/extension/frontend of MVTools2 + MDegrain
### with some additional features. Goal is accessibility and quality but not targeted to any specific kind of source.
### The reason behind is to keep it simple so for basic usage you will only need ExTools, ResizersPack and MVTools2.
###
### Supports all Y, YUV and YUY2 clips progressive or interlaced between 8-16 bits.
### For HDR use as input (or at least as prefilter) the decoded and tonemapped PQ clip.
### Example:
###    pre=DGHDRtoSDR(YUV420P16_Lim_PQsrc, mode="pq",gamma=1/2.4,tm=1.0,white=1500) # also try white=60, 100, 203 or default 400 depending on title
###
### Check documentation for full explanation on settings and defaults:
###    https://raw.githack.com/Dogway/Avisynth-Scripts/master/SMDegrain/SMDegrain.html
###
###
### Dependencies:
###              MVTools2
###              ExTools
###              ResizersPack
###              LSFplus/SharpenersPack (for Contrasharp or LFR)
###              GradePack              (for Str=0.1 to 1.0 ~ex_retinex()~ or show)
###              ScenesPack             (for Str=0.1 to 1.0 ~ex_retinex()~ if '_SceneRange' frameprops exist)
###              TransformsPack         (for subpixel=4, interlaced=true, prefilter=7 or prefilter=8)
###              MasksPack              (for show)
###              RgTools                (for Contrasharp
###                                      or  prefilter=0~3)
###              DFTTest                (for prefilter=5)
###              KNLMeansCL             (for prefilter=6)
###              DGDecNV                (for prefilter=7)
###              BM3D                   (for prefilter=8)
###                 TransformsPack      (for prefilter=7 or prefilter=8)
###              neo_tmedian            (for mode="medianT")  (crashes for interlaced clips, even when set '_FieldBased' to 0 and AssumeFrameBased() )
###              vsTTempSmooth          (for mode="TemporalSmooth")
###              NNEDI3/NNEDI3CL        (for subpixel=4)
###              Average                (for LFR or mfilter + (Contrasharp or mode!=MDegrain) )
###
###
### Function Definition:
###   (
###   clip input,
###   int tr=1 (1 to 9),
###   int thSAD=300 (100 to 1500),
###   [int "blksize"=16 (4 to 64 by 4)],
###   [int "overlap"=8 (2 to 32 by 4)],
###   string "mode"="MDegrain" ("MDegrain"/ "MedianT"/ "MedianST"/ "MedianSTS"/ "TemporalSoften"/ "TemporalSmooth"/ "TemporalGauss"/ "FluxSmoothT"/ "DFTTest"/ "ML3DEx"/ "Hybrid"/ "TL3D"/ "STWM"/ "IQMT"/ "GaussST5"/ "--"/ "rMDegrain"/ "rMedianT"/ "rMedianST"/ "rMedianSTS"/ "rTemporalGauss"/ "rFluxSmoothT"/ "rDFTTest"/ "rML3DEx"/ "rHybrid"/ "rTL3D"/ "rSTWM"/ "rIQMT"/ "rGaussST5"),
###   string "prefilter"="" (""/ "SBR"/ "MinBlur"/ "MinBlur2"/ "MinBlur3"/ "IQMST"/ "DFTTest"/ "KNLMeans"/ "DGDenoise"/ "BM3D"),
###   bool "ContraSharp"=false,
###   [clip "CClip"],
###   [clip "mfilter"],
###   bool "RefineMotion"=false,
###   [bool "interlaced"=false],
###   [float "Str"=5.0 (0.0 to 8.0)],
###   [float "Amp"=0.03 (0.00 to 1.00)],
###   [int "plane"=4 (1 to 4)],
###   [bool "chroma"=true],
###   int "LFR"=0 (0 to 1920),
###   bool "DCTFlicker"=false,
###   [bool "TrueMotion"=false],
###   [bool "show"=false]
###   )
###
################################################################################################

function SMDegrain (clip input   , int "tr"      , int "thSAD"    , int  "thSADC" , bool "RefineMotion",  val  "contrasharp", clip  "CClip"     , string "mode"     , bool "interlaced" , int   "plane"  , int   "Globals"   , bool "tv_range"  ,               \
                     int "pel"   , int "subpixel", val "prefilter", clip "mfilter", int  "blksize"     , int   "overlap"    , int   "limit"     , int  "limitC"     , bool "limitS"     , val   "LFR"    , bool  "DCTFlicker", int  "thSCD1"    , int "thSCD2", \
                    bool "chroma", bool    "luma", int "hpad"     , int "vpad"    , val  "Show"        , float "Str"        , float "Amp"       , int   "DCT"       , int "searchparam" , int "pelsearch", int   "search"    , bool "truemotion",               \
                     int "gpuid" , int  "rfilter", bool "UHDhalf" , int  "threads" ) {

    w            = input.width ()
    h            = input.height()
    isy          = input.isy()
    bi           = BitsPerComponent(input)
    isyuy        = isYUY2(input)
    is22         = is422 (input)
    is20         = is420 (input)
    fb           = GetParity      (input) ? 2 : 1
    InterPar     = propNumElements(input,"_FieldBased")  > 0 ? \
                   propGetInt     (input,"_FieldBased") : IsFrameBased(input) ? 0 : fb
    sr           = propNumElements(input,"_SceneRange")  > 0
    fscale       = propNumElements(input,"_ColorRange")  > 0 ? \
                   propGetInt     (input,"_ColorRange") == 0 : false
    isInter      = Default( Interlaced,  InterPar!=0  )

    input        = isyuy ? ConvertToYUV422(input,interlaced=isInter) : input


    md           = Default( mode,   "MDegrain")
    md           = ReplaceStr(md," ",       "")
    tr           = Default( tr,             2 )
    tr           = isInter ? ceil(tr/2.0) : tr
    rc           =     LeftStr(md, 1) == "r"
    md           = rc ? MidStr(md, 2) : md

    md           = FindStr(LCase(md), "mediant") > 0 ? rc && tr==1 ? "MedianT" : rc && tr==2 ? "MedianT5" : "MedianTn" : md
    T3           = md == "MedianT"  || md == "MedianST" || md == "ML3DEx"   || md == "Hybrid"    || md == "TL3D"
    T5           = md == "MedianT5" || md == "STWM"     || md == "GaussST5" || md == "MedianSTS" || md == "IQMT"
    T7           = FindStr(LCase(md), "fluxsmooth") > 0
    TG           = md == "TemporalGauss"
    TM           = md == "TemporalSmooth"
    TS           = md == "TemporalSoften" || TG || TM

    tr           = T3 ? 1 : T5 ? 2 : T7 ? min(3,tr) : TS ? min(7,tr) : tr
    tr2          = tr*2
    tri          = tr                                          # Storing for DCTFlicker


    UHDhalf      = Default( UHDhalf,  true)
    isMult       = tr > 6                                      # MDegrainN is slower, so avoid >6 at possible
    isHD         = (w > 1099 || h >  599)
      UHD        = (w > 2599 || h > 1499)
    isUHD        = UHD && !UHDhalf
    UHDhalf      = UHD &&  UHDhalf


    plane        = Default( plane,   isy ? 0 : 4 )
    plane0       = plane!=0
    U            = plane0 && plane!=2 ? 3 : 2
    V            = plane0 && plane!=1 ? 3 : 2
    ChP          = plane0 && plane!=4                          # No luma denoise case
    chroma       = Default( chroma, !isy && plane0  )          # Compute chroma MVs? (regardless of processed planes)
    Chr          = chroma ? 3 : 1
    Luma         = Default( luma,   !ChP            )          # Compute luma   MVs? (regardless of processed planes)
    Lum          = Luma   ? 3 : 1


    cplaceCMD = is20           ? "420" : is22 ? "422" : "444"
                                                               # You can't disable luma contribution to MVs at all, so we minimize it by doubling chroma weight vs luma
    scaleCSAD = !Luma          ?    2 : !chroma    ? -2 : \
                is20           ? isHD ? TS ? 1 : 2 :  0 : \
                is22           ? isHD ? TS ? 1 : 2 :  0 : \
                is444  (input) ? isHD ? TS ? 1 : 2 :  1 : \
                isYV411(input) ? isHD ?          0 : -1 : \
                                 isHD ? TS ? 1 : 2 :  0


    thSAD        = Default( thSAD,  TS ? 750 : 300 )
        thSADR   =                  round(exp(-101./(thSAD*0.83)) * 360)                 # Directly proportional up to critical thSAD, then -not included- inversely proportional (-1.9x+682)
        thSADRC  =                  round(thSADR * 0.755 * (0.25*exp(scaleCSAD*0.693)))  # Currently not supported by MRecalculate()
    thSADC       = Default( thSADC, round(thSAD  * 0.755 * (0.25*exp(scaleCSAD*0.693))))
    RefineMotion = Default( RefineMotion, false)


    Globals      = Default( Globals,  0 )
    GlobalR      = Globals == 1
    GlobalO      = Globals == 3

    isCClip      = Defined( CClip )
    Contrasharp  = Default( Contrasharp, !GlobalO && isCClip)
    SLimit       = Default( limitS,  true )                    # Limit type for the contrasharpening   True: Spatial  False: Temporal (ignores CClip)
    isCntr       = IsBool (   Contrasharp )
    isShrp       = !isCntr ? (Contrasharp > 0.0) : Contrasharp


    preclip      = IsClip ( prefilter    )
    prefilter    = Default( prefilter, -1)
    pel          = Default( pel, isHD ? 1 : 2 )
    subpixel     = Default( subpixel,   3)
    subpixel     = isInter ? 4 : subpixel                      # For interlaced inputs with pel>1 you need edge directed kernels
    rfilter      = Default( rfilter,    3)
    MFilterB     = Defined( mfilter )
    pelclip      = pel>1 && subpixel > 2
    prefilter    =  isString(prefilter)                                      ?      \
                    prefilter=="none"     || prefilter==""                   ? -1 : \
                    prefilter=="MinBlur0" || prefilter=="SBR"                ?  0 : \
                    prefilter=="MinBlur1" || prefilter=="MinBlur"            ?  1 : \
                    prefilter=="MinBlur2"                                    ?  2 : \
                    prefilter=="IQMST"                                       ?  4 : \
                    prefilter=="MinBlur3"||FindStr(LCase(prefilter),"iqm")>0 ?  3 : \
                    prefilter=="DFTTest"                                     ?  5 : \
                    FindStr(LCase(prefilter),"nlmeans")>0                    ?  6 : \
                    prefilter=="DGDenoise"                                   ?  7 : \
                    prefilter=="BM3D"                                        ?  8 : prefilter : prefilter



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
        blk2     = blksize    / 2
        ovl2     = max(2,blk2 / 2)
    overlap      = Default( overlap, blk2 )

    search       = Default( search, RefineMotion ? 4 : 2 )
    searchr      = 0
    pglobal      = 11
    truemotion   = Default( truemotion, TS || T7 || !isHD)

    searchparam  = Default( searchparam, RefineMotion && truemotion ? isUHD ? 2 : 5 : isUHD ? 1 : 2 )
    searchparamr = max(0,round(exp(0.69*searchparam-1.79)-0.67))
    pelsearch    = Default( pelsearch, max(0,searchparam*2-2)) # searchRange at finest level. Higher has a high performance hit

    DCT          = Default( DCT,   0 )                         # Change to 5 (slower) if you get artifacts due to luminosity changes (fades, flashes, etc)
    DCTR         =                         TS && RefineMotion ? 2 : 5

    thSCD2       = Default( thSCD2,  130 )                     # 130 or 51% of SAD change by default
    thSCD1       = Default( thSCD1, round(!TS || preclip || ChP ?           0.35*    thSAD        +260   : \
                                                 RefineMotion ? max(230,-1040000*pow(thSAD,-1.214)+950)  : \
                                                                max(300,-61275  *pow(thSAD,-0.655)+1508))) # Typically between 330 and 400 for !TS

    Str          = Default( Str, !Luma ? 1 : 5.0 )             # 0.0 or 1.0 does an Automatic Range Conversion (with FrameProps)  0<Str<1: Multi-Scale Retinex  >1.0: ex_luma_rebuild(Str) (from 0.1 to 0.9 indicates ex_retinex() black level clipping value)
    Amp          = Default( Amp, 1./32 )
    DefTV        = Defined( tv_range)
    tv           = Default( tv_range, !fscale)

    hpad         = Default( hpad, isHD ? 0 : blksize)
        hpadU    = isUHD ? nmod(hpad/2)    : hpad
    vpad         = Default( vpad, isHD ? 0 : hpad)
        vpadU    = isUHD ? nmod(vpad/2)    : vpad
    limit        = Default( limit,  255 )                      # bitdepth auto-scaled
    limitc       = Default( limitc,limit)

    gpuid        = Default ( gpuid,   0)                       # Choose the GPU device_id for NNEDI3, KNLMeancCL and BM3D, or -1 for CPU mode (NNEDI3 and BM3D)
    threads      = Default ( threads, 8)                       # CPU threads for NNEDI3 in CPU mode (gpuid=-1)
    sShow        = IsString( Show)
    Show         = Default ( Show,  false)



    # Error Report
                              Assert(IsVersionOrGreater(3,7,3),        "SMDegrain: Update AviSynth+ version")
                              Assert(blksize==4 || blksize==8 || blksize==16 || blksize==24 || blksize==32 || blksize==48 || blksize==64,"SMDegrain: MAnalyse: Block's size must be 4x4, 8x8, 16x16, 24x24, 32x32, 48x48 or 64x64")
                              Assert(overlap <= blk2,                  "SMDegrain: Overlap must be at least half blksize or less")
                              Assert(overlap == overlap-overlap%2,     "SMDegrain: MAnalyse: overlap must be an even figure")
                              Assert(IsBool(Show) || sShow,            "SMDegrain: 'Show' only accepts bool inputs (true,false), or string modes ('Speed','Memory',Quality')")
                              Assert(isCntr  || IsInt(Contrasharp),    "SMDegrain: 'Contrasharp' only accepts integers and bool inputs")
    MFilterB                ? Assert(IsClip(mfilter),                  "SMDegrain: 'mfilter' only accepts clip inputs")                     : nop()
    isInter                 ? Assert(h%4==0,                           "SMDegrain: Interlaced sources require mod 4 height sizes")          : nop()
    RefineMotion            ? Assert(blksize > 7,                      "SMDegrain: For RefineMotion you need a blksize of at least 8")      : nop()
    md=="medianTn"  && tr>2 ? Assert(!IsInter,                         "SMDegrain: neo_TMedian is broken for interlaced sources")           : nop()
    rc && TS                ? Assert(TG,                               "SMDegrain: Unsupported 'mode' for recursion")                       : nop()



    # RefineMotion + MDegrainN variables

    halfblksize  = blk2     # MRecalculate works with half block size
    halfoverlap  = ovl2     # Halve the overlap to suit the halved block size
    halfthSAD    = thSADR
    halfthSADC   = thSADC/2 # For MDegrainN()


    # Input clips preparation for: Interlacing, Motion Filter and MSuper optimization

    inputP  = !isInter ? (pel >= 2 ? input.AssumeFrameBased() : input) : SMD_UnfoldFieldsVertical(input,true,InterPar==2)
    inputP  =  inputP.propSet("_FieldBased", 0)

    if (MFilterB) {
    Mfilter = isYUY2(MFilter)   ? ConvertToYUV422(MFilter,  interlaced=isInter)      : MFilter
    MFilter = isInter           ? SMD_UnfoldFieldsVertical(MFilter,true,InterPar==2) : MFilter.propSet("_FieldBased", 0)
    MFilter = !isy ? !plane0    ? CombinePlanes(MFilter,InputP,planes="YUV")         : \
              ChP  ?  plane!=3  ? CombinePlanes(InputP,plane==1?MFilter:InputP,plane==1?InputP:MFilter,planes="YUV") : \
                                  CombinePlanes(InputP,MFilter,planes="YUV")         : MFilter                       : MFilter
    } else {
    MFilter = inputP
    }

    # Prefilter

    nw      =  UHDhalf ? nmod(w/2.0) : w
    nh      =  UHDhalf ? nmod(h/2.0) : h

    pref    =  preclip ? isYUY2(prefilter) ? ConvertToYUV422(prefilter,interlaced=isInter)      : prefilter                         : inputP
    pref    =  preclip ? isInter           ? SMD_UnfoldFieldsVertical(pref,   true,InterPar==2) : pref.   propSet("_FieldBased", 0) : inputP

    fsp     = !preclip ? !tv : propNumElements(pref, "_ColorRange")  > 0 ? \
                               propGetInt     (pref, "_ColorRange") == 0 : !tv

    pref8   = bi > 8   ? pref. ConvertBits(8, dither=-1, fulls=fsp, fulld=fsp)                                                                                                                               : pref
    prefh   = UHDhalf  ? pref8.BicubicResize(nw,nh,-0.99,0.06)                                                                                                                                               : pref
    pref    = UHDhalf  ? !(isy || cplaceCMD=="444") && chroma ? Eval("""prefh.ConvertToYUV"""+cplaceCMD+"""(false,"","MPEG1","bicubic","top_left",0.0,0.5)""").ConvertBits(bi, fulls=fsp, fulld=fsp) : prefh : pref # Assumes UHD is top_left aligned

    Lthres  = ex_bs(75, 8, bi, tv_in=true, tv_out=!fsp)

    pref    = !GlobalR ? preclip ?                  pref                                                                                                                                                     : \
                                  (prefilter==-1) ? pref                                                                                                                                                     : \
                                  (prefilter== 0) ? !isInter ? pref.ex_sbr(1, Y=Lum,UV=Chr) : pref.ex_boxblur(0.3,0,"weighted",Lum,Chr)                                                                      : \
                                  (prefilter== 1) ?            pref.ex_MinBlur(1,Chr,isInter ? """ex_Median(mode="horizontal" ,Y=Lum,UV=uv)""" : "median",Y=Lum)                                             : \
                                  (prefilter== 2) ?            pref.ex_MinBlur(2,Chr,isInter ? """ex_Median(mode="horizontalS",Y=Lum,UV=uv)""" : "median",Y=Lum)                                             : \
                                  (prefilter== 3) ? !isInter ? pref.ex_Median(mode="IQMV" ,Y=Lum,UV=Chr) : pref.ex_Median(mode="IQM",Y=Lum,UV=Chr)                                                           : \
                                  (prefilter== 4) ?            pref.ex_Median(mode="IQMST",Y=Lum,UV=Chr, thres=255).ex_sbr(3,Y=Lum,UV=Chr)                                                                   : \
                                  (prefilter== 5) ? ex_merge(DFTTest(pref,sstring="0.0:4.0 0.2:9.0 1.0:15.0",tbsize=1,Y=Lum==3,U=chroma,V=chroma,dither=1,threads=1,sbsize=12,sosize=6,swin=2),pref,           \
                                                               pref.ex_lut(Format("range_max range_max {Lthres} ymin - / x ymin - * -"),UV=1,clamp_float=true),         Y=Lum,UV=Chr,luma=chroma)            : \
                                  (prefilter== 6) ?            pref.ex_KNLMeansCL(a=2,s=2,d=1,h=7.0,wmode=1,chroma=chroma,gpuid=max(0,gpuid),LFR=600*(nw/1920.)).ex_sbr(Y=Lum,UV=Chr)                        : \
                                  (prefilter== 7) ?            pref.ex_DGDenoise(str=Luma?0.10:0,strc=chroma?0.05:0,LFR=nw/2.,UV=Chr).                           ex_sbr(Y=Lum,UV=Chr)                        : \
                                  (prefilter== 8) ?            pref.ex_BM3D(TS?max(10,thSAD/30.):10,1,TS&&thSAD>550?"noisy":"normal",UV=Chr,gpuid=gpuid,tv_range=!fsp)                                       : \
                                                    Assert(false, "SMDegrain: 'Prefilter' didn't find a matching preset: "+string(prefilter))                                                                : \
                                   pref


    # Default Auto-Prefilter - Luma expansion TV->PC (up to 16% more values for motion estimation) + Dynamic range expansion on darks

    pref8  =    Str > 1 ? pref.ex_Luma_Rebuild(S0=Str, c=Amp,      UV=Chr, Y=Lum, tv_in=!fsp, tv_out=false, bits=8)                               : \
            0 < Str < 1 ? pref.ex_retinex(lo=Str*100,lvl=sr?3:1,   UV=Chr,        tv_in=!fsp, tv_out=false).ConvertBits(8, dither=-1, fulls=true) : \
                   !fsp ? pref.ConvertBits(8, dither=-1, fulls=false, fulld=true) :                    pref.ConvertBits(8, dither=-1, fulls=true)

    pref8  = LFRB ? pref8.ex_unsharp(thSAD/1800., Fc=w/8., th=0.0, UV=Chr, Y=Lum) : pref8 # Low Frequency expansion (the higher SAD the more protection)

    If (sShow ? false : !Show) {

        # Subpixel 3 and 4
        inputP8 = inputP.      ConvertBits(8, dither=-1, fulls=!tv,   fulld=!tv)          # nnedi3 is slower with HBD
        pclip   = pelclip ? subpixel==4 ? pref8.  nnedi3wrap(pel,nns=pel/2,nsize=0,qual=pel/2,gpuid=gpuid,HBD=false,cshift=pel>1&&gpuid!=-1?"spline16":"none",threads=threads)               : \
                                          Undefined()                                                                                                                                        : nop() # Wiener filter is good enough for MAnalyse
        pclip2  = pelclip ? subpixel==4 ? inputP8.nnedi3wrap(pel,nns=pel/2,nsize=0,qual=pel/2,gpuid=gpuid,HBD=false,cshift="spline16",threads=threads).ConvertBits(bi, fulls=!tv, fulld=!tv) : \
                                          inputP. BlackmanResize(w*pel,h*pel, taps=6, src_left=(pel*0.5)*0.25, src_top=(pel*0.5)*0.25)                                                       : nop() # Center shift, from docs: "src_left=0.25, src_top=0.25" for Luma and "src_left = 0.5 for YUY2 and
                                                                                                                                                                                                     # additionally src_top = 0.5" for chroma to match MVTools internal interpolation (for 'MPEG2' chroma placement assumed).
                                                                                                                                                                                                     # nnedi3_rpow2() already behaves like this when "cshift=" is not declared.

        # Motion vectors search (mt=true requires avstp.dll in plugin path, otherwise ignored)

        super_search = !GlobalR ?                  pelclip ? MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU,           pelclip=pclip, rfilter=rfilter, mt=true)  : \
                                                             MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU                         , rfilter=rfilter, mt=true)  : nop()
        super_render =                            (pelclip ? MSuper(inputP, pel=pel,                        chroma=plane0, hpad=hpad,  vpad=vpad,  levels=1, pelclip=pclip2                , mt=true)  : \
                                                             MSuper(inputP, pel=pel, sharp=min(subpixel,2), chroma=plane0, hpad=hpad,  vpad=vpad,  levels=1                                , mt=true))
        Recalculate  = !GlobalR && RefineMotion ? (pelclip ? MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU, levels=1, pelclip=pclip                 , mt=true)  : \
                                                             MSuper(pref8,  pel=pel, sharp=min(subpixel,2), chroma=chroma, hpad=hpadU, vpad=vpadU, levels=1                                , mt=true)) : nop()
        If (!isMult) {

            for (i = -tr, tr, 1) {

                if (i!=0) {
                    ia  = abs(i)
                    vst = Format(i < 0 ? "bVec{ia}" : "fVec{ia}")
                    Eval(vst+Format(" = tr > {ia}-1 ?                 (!GlobalR ? super_search.MAnalyse    (delta = {ia}, isb = {i}<0, overlap=    overlap, blksize=    blksize, search=search,  chroma=chroma, truemotion=truemotion, dct=dct,  searchparam=searchparam,  temporal=TS,     scaleCSAD=scaleCSAD, mt=true, pelsearch=pelsearch, plevel=0, pglobal=pglobal) : "+vst+") : nop()
                       "+vst+"        = tr > {ia}-1 && RefineMotion && !GlobalR ?  Recalculate.MRecalculate("+vst+",                   overlap=halfoverlap, blksize=halfblksize, search=searchr, chroma=chroma, truemotion=truemotion, dct=dctr, searchparam=searchparamr, thSAD=halfthSAD, scaleCSAD=scaleCSAD, mt=true) :                                                 "+vst+""))
                    }
                }

                # Scaling vectors for UHD

                if (UHDhalf) {

                bVec1  =          !GlobalR ?  bVec1.MScaleVect() :  bVec1               fVec1  =          !GlobalR ?  fVec1.MScaleVect() :  fVec1
                bVec2  = tr > 1 ? !GlobalR ?  bVec2.MScaleVect() :  bVec2 : nop()       fVec2  = tr > 1 ? !GlobalR ?  fVec2.MScaleVect() :  fVec2 : nop()
                bVec3  = tr > 2 ? !GlobalR ?  bVec3.MScaleVect() :  bVec3 : nop()       fVec3  = tr > 2 ? !GlobalR ?  fVec3.MScaleVect() :  fVec3 : nop()
                bVec4  = tr > 3 ? !GlobalR ?  bVec4.MScaleVect() :  bVec4 : nop()       fVec4  = tr > 3 ? !GlobalR ?  fVec4.MScaleVect() :  fVec4 : nop()
                bVec5  = tr > 4 ? !GlobalR ?  bVec5.MScaleVect() :  bVec5 : nop()       fVec5  = tr > 4 ? !GlobalR ?  fVec5.MScaleVect() :  fVec5 : nop()
                bVec6  = tr > 5 ? !GlobalR ?  bVec6.MScaleVect() :  bVec6 : nop()       fVec6  = tr > 5 ? !GlobalR ?  fVec6.MScaleVect() :  fVec6 : nop()

                            }

                            } else {

                vmulti =                   !GlobalR ? super_search.MAnalyse( multi=true,overlap=    overlap,blksize=    blksize, search=search,  chroma=chroma, truemotion=truemotion, delta = tr, dct=dct,  scaleCSAD=scaleCSAD, mt=true, searchparam=searchparam, pelsearch=pelsearch, temporal=TS, plevel=0, pglobal=pglobal) : vmulti
                vmulti = RefineMotion   ? (!GlobalR ? MRecalculate (Recalculate, vmulti,overlap=halfoverlap,blksize=halfblksize, search=searchr, chroma=chroma, truemotion=truemotion,    tr = tr, dct=dctr, scaleCSAD=scaleCSAD, mt=true, searchparam=searchparamr, thSAD=halfthSAD                                           ) : vmulti) : vmulti
                vmulti =                   !GlobalR ?   vmulti : vmulti.SelectRangeEvery (Rtr*2, tr2, 0, false)
                vmulti =                   !GlobalR && UHDhalf ? vmulti.MScaleVect() : vmulti
                                   }


        if (!GlobalO) {

            VAR = LFRB || MFilterB && (isShrp || (md != "MDegrain"))

            # Extract vectors when 'multi' is used

            if (isMult && (VAR || md != "MDegrain")) {

                for(i = 1, tr, 1) {
                    Eval(Format("bVec{i} = vmulti.SelectEvery (tr2,  i*2-2)
                                 fVec{i} = vmulti.SelectEvery (tr2,  i*2-1)"))
                } }

            # Masking when 'LFR' or 'mfilter' are used

            if (VAR) {
                               MMin   = plane0 ? mfilter : mfilter.ExtractY()
                               MMsk   = ""
                               gm     = !LFRB || DCTF ? 2.222 : 0.5
                for (i = 1, tr, 1) {
                    Eval(      Format(  "Mb{i}c = MMask(MMin, bVec{i}, ml=50, gamma=gm, kind=1, Ysc=255, thSCD1=thSCD1, thSCD2=thSCD2)"))
                    Eval(      Format(  "Mf{i}c = MMask(MMin, fVec{i}, ml=50, gamma=gm, kind=1, Ysc=255, thSCD1=thSCD1, thSCD2=thSCD2)"))
                    Eval(      Format("""MMsk   = MMsk + ({i}!=1 ? "," : "") + string(Format("Mb{i}c, 1./(tr2), Mf{i}c, 1./(tr2)")) """))
                }

                Mavg   = Eval("Average("+MMsk+")")
                Mavg   = isy ? Mavg : mskY_to_YYY(mfilter, Mavg, true, false, plane0?3:1, bi) }


            if (md != "MDegrain") {


                for (i = 1, tr, 1) {

                    gcv = i==1 && isShrp && isCntr && !SLimit ? "global " : ""

                    Eval(      Format(        "b{i}c = inputP.MCompensate(super_render, bVec{i}, thSAD=thSAD, thSAD2=thSAD/2, thSCD1=thSCD1, thSCD2=thSCD2, mt=true)"))
                    Eval(      Format(        "f{i}c = inputP.MCompensate(super_render, fVec{i}, thSAD=thSAD, thSAD2=thSAD/2, thSCD1=thSCD1, thSCD2=thSCD2, mt=true)"))
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


            # Alternative Degrain modes

            DM="""
                output = TG               ? inter.ex_blur3D(0,0,tr,"weighted",UV=plane0?3:1)                                 : \
                         TM               ? inter.vsTTempSmooth (tr,limit+1,!plane0?0:int(limitc/8.)+1,!plane0?0:int(limitc/8.)+1,255,255,255,strength=1,scthresh=15,u=plane0?3:2,v=plane0?3:2) : \
                         TS               ? inter.TemporalSoften(tr,limit,  !plane0?0:int(limitc/8.),15,2)                   : \
                         md == "MedianTn" ? inter.neo_tmedian(radius=tr,Y=plane!=3?3:2, U=U, V=V)                            : \
                         md == "DFTTest"  ? inter.DFTTest(sstring="0.0:4 0.5:8 1.0:16",U=plane0,V=plane0,dither=1,sbsize=nmod(blksize*0.75),sosize=nmod(blksize*0.75)/2,tbsize=tr,tmode=(tr-1)%2,tosize=floor(tr/2.),swin=2,twin=tr>2?4:7) : \
                         T7               ? inter.ex_FluxSmoothT(tr,limit,UV=plane0?3:1)                                     : \
                                            inter.ex_median(mode=md, thres=limit, recursion=rc, Y=plane!=3?3:1, UV=plane0?3:1)"""

                                   Eval(           DM)
                rc && !T3 && !T5 ? Eval(ReplaceStr(DM, "inter", "output")) : last


                output = isMult || TS || T7 || (md == "MedianTn") || (md == "DFTTest") ? output.SelectEvery(tr2+1, tr) : output.SelectEvery((T5?2:1)*2+1,T5?2:1)

                if (LFRB) {

                    mfilterLP = inputP.ex_gaussianblur(LFR)
                    DCTF_pass = DCTF ? inputP.SMDegrain(tr=ceil(tri/3.),thSAD=thSAD/2,blksize=blksize,prefilter=mfilterLP,pel=1,rfilter=0,str=0,tv_range=false,plane=0,truemotion=false) : nop()  # Calming -Luma- Low Frequency Flicker (aka removing DCT flicker: https://forum.doom9.org/showthread.php?p=1073349)
                    mfilterLP = DCTF ? ex_repair(mfilterLP, DCTF_pass.ex_gaussianblur(LFR),"temp4",UV=plane0?3:1) : mfilterLP
                    outputLP  = output.ex_gaussianblur(LFR)
                    output    = !mfilterB ? ex_lutxyza(output, outputLP, mfilterLP,          Mavg,         "x dup dup y - z + - a range_max /    * -", UV=2, fulls=!tv)                                  : \
                                isy       ? Expr      (output, outputLP, mfilterLP, mfilter, Mavg, ex_dlut("x dup dup y - z + - b range_max / M@ * - dup a - M "+string(DCTF?"":"4 ^")+" * -", bi, !tv)) : \
                                            Expr      (output, outputLP, mfilterLP, mfilter, Mavg, ex_dlut("x dup dup y - z + - b range_max / M@ * - dup a - M "+string(DCTF?"":"4 ^")+" * -", bi, !tv), plane0?Undefined():"")
                }

                output = mfilterB && !LFRB ? ex_merge(output, mfilter, Mavg, luma=true, UV=plane0?3:1) : output


            } else {

            # Finally, MDegrain

            MDe= "output  = ( isMult  ? mfilter.MDegrainN(super_render, vmulti, tr, thSAD2=thSAD/2, thSADC2=halfthSADC,                                     thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \           (tr == 6) ? mfilter.MDegrain6(super_render, bVec1, fVec1, bVec2, fVec2, bVec3, fVec3, bVec4, fVec4, bVec5, fVec5, bVec6, fVec6, thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \           (tr == 5) ? mfilter.MDegrain5(super_render, bVec1, fVec1, bVec2, fVec2, bVec3, fVec3, bVec4, fVec4, bVec5, fVec5,               thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \           (tr == 4) ? mfilter.MDegrain4(super_render, bVec1, fVec1, bVec2, fVec2, bVec3, fVec3, bVec4, fVec4,                             thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \           (tr == 3) ? mfilter.MDegrain3(super_render, bVec1, fVec1, bVec2, fVec2, bVec3, fVec3,                                           thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \           (tr == 2) ? mfilter.MDegrain2(super_render, bVec1, fVec1, bVec2, fVec2,                                                         thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
                \                       mfilter.MDegrain1(super_render, bVec1, fVec1,                                                                       thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true))"

            Eval(MDe)
            rc ? Eval(ReplaceStr(MDe, "mfilter", "output")) : last

            if (LFRB) {

                mfilterLP = mfilter.ex_gaussianblur(LFR)
                DCTF_pass = DCTF  ? mfilter.SMDegrain(tr=ceil(tri/3.),thSAD=thSAD/2,blksize=blksize,prefilter=mfilterLP,pel=1,rfilter=0,str=0,tv_range=false,plane=0,chroma=false,truemotion=false) : nop() # Calming -Luma- Low Frequency Flicker (aka removing DCT flicker: https://forum.doom9.org/showthread.php?p=1073349)
                mfilterLP = DCTF  ? ex_repair(mfilterLP, DCTF_pass.ex_gaussianblur(LFR),"temp4",UV=plane0?3:1) : mfilterLP
                outputLP  =  output.ex_gaussianblur(LFR)
                output    =  ex_lutxyza(output, outputLP, mfilterLP, Mavg, "x dup dup y - z + - a range_max / * -", UV=2)

            } }


        # Contrasharp (only sharpens luma)

        if (isShrp) {

            !SLimit && (!isCntr || (isCntr && md == "MDegrain")) ? Eval("""

                global srchSuper       = super_render
                global cb1             = !isMult ? bVec1 : vmulti.SelectEvery (tr2, 0)
                global cf1             = !isMult ? fVec1 : vmulti.SelectEvery (tr2, 1)""") : nop()

                if (isCClip) {
                CClip = isYUY2(CClip) ? ConvertToYUV422(CClip,interlaced=IsInter)        : CClip
                CClip = isInter       ? SMD_UnfoldFieldsVertical(CClip,true,InterPar==2) : CClip.propSet("_FieldBased", 0)
                } else { CClip = inputP }
                CClip = MFilterB && SLimit ? ex_merge(CClip, mfilter, Mavg, luma=true, UV=plane0?3:1) : CClip

        } }


        # Globals Output

        GlobalO || Globals == 2  ? (!isMult ? Eval("""
        global srchSuper     = super_render # But not required for SMDegrain(Globals=1)
        global bVec6         = VarExist("bVec6") ? bVec6 : nop()
        global bVec5         = VarExist("bVec5") ? bVec5 : nop()
        global bVec4         = VarExist("bVec4") ? bVec4 : nop()
        global bVec3         = VarExist("bVec3") ? bVec3 : nop()
        global bVec2         = VarExist("bVec2") ? bVec2 : nop()
        global bVec1         =                     bVec1

        global fVec1         =                     fVec1
        global fVec2         = VarExist("fVec2") ? fVec2 : nop()
        global fVec3         = VarExist("fVec3") ? fVec3 : nop()
        global fVec4         = VarExist("fVec4") ? fVec4 : nop()
        global fVec5         = VarExist("fVec5") ? fVec5 : nop()
        global fVec6         = VarExist("fVec6") ? fVec6 : nop()
        """) : Eval("""
        global bVec1         =          vmulti.SelectEvery (tr2,  0)
        global bVec2         =          vmulti.SelectEvery (tr2,  2)
        global bVec3         =          vmulti.SelectEvery (tr2,  4)
        global bVec4         =          vmulti.SelectEvery (tr2,  6)
        global bVec5         = tr > 4 ? vmulti.SelectEvery (tr2,  8) : nop()
        global bVec6         = tr > 5 ? vmulti.SelectEvery (tr2, 10) : nop()
        global bVec7         = tr > 6 ? vmulti.SelectEvery (tr2, 12) : nop()
        global bVec8         = tr > 7 ? vmulti.SelectEvery (tr2, 14) : nop()
        global bVec9         = tr > 8 ? vmulti.SelectEvery (tr2, 16) : nop()

        global fVec1         =          vmulti.SelectEvery (tr2,  1)
        global fVec2         =          vmulti.SelectEvery (tr2,  3)
        global fVec3         =          vmulti.SelectEvery (tr2,  5)
        global fVec4         =          vmulti.SelectEvery (tr2,  7)
        global fVec5         = tr > 4 ? vmulti.SelectEvery (tr2,  9) : nop()
        global fVec6         = tr > 5 ? vmulti.SelectEvery (tr2, 11) : nop()
        global fVec7         = tr > 6 ? vmulti.SelectEvery (tr2, 13) : nop()
        global fVec8         = tr > 7 ? vmulti.SelectEvery (tr2, 15) : nop()
        global fVec9         = tr > 8 ? vmulti.SelectEvery (tr2, 17) : nop()
        global srchSuper     = super_render
        global vmulti        = vmulti
        global Rtr           = tr
        """)) : nop()



        output =  GlobalO ? input : isShrp ? isCntr ? ex_ContraSharpening(output, CClip, MC=!SLimit, HD=isHD, overshoot=TS?100:0)                                                      : \
                                    SLimit ? LSFplus(output,source=CClip,preset="LSF",strength=Contrasharp,Smode=isHD?4:5,Lmode=0,edgemode=0,soothe=false,overshoot=0,soft=-2,keep=0)  : \
                                             LSFplus(output,             preset="LSF",strength=Contrasharp,Smode=isHD?4:5,Lmode=6,edgemode=0,soothe=false,overshoot=0,soft=-2,keep=0)  : output

                 !GlobalO ? (isInter ? output.SMD_FoldFieldsVertical(true,InterPar==2).propCopy(input) : output) : output




    } ELSE {



    ##############
    # SHOW PANEL #
    ##############

          # Common Variables

        dbl   = isInter ? 0.5 : 1
        pref8 = isInter ? pref8.SMD_FoldFieldsVertical(true,InterPar==2).SeparateFields().AssumeFrameBased() : pref8
        w2    = UHDhalf ? nw : w     w2 = float(w2)
        h2    = UHDhalf ? nh : h     h2 = float(h2)
        hi    = round(h2*dbl)
        AR    = w2/h2
        lsp   = int(30*dbl)
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

        if (Str > 1.0) {

            w2  = round(w2)
            sw  = nmod(w2/5.)   sh = sw
            plt = pref8.GradientLinear(zoom=1, positive=true, precision=2, smooth=true, tv_range=!fsp)
            plt = plt.ex_Luma_Rebuild(S0=Str,c=Amp,tv_in=!fsp)
            plt = plt.HistoCurve(size=2,gradient=false)
            plt = plt.BicubicResize(sw,sh,-0.5,0.25).Subtitle("Luma Rebuild curve", size=min(w2,h2)/45, text_color=$FFFFFF)
            plt = PadBorders(plt,w2-sw,0,0,hi-sh)
            plt = Merge(pref8,plt)
            pref8 = ex_merge(pref8,plt,BoxMask(pref8,w2-sw,w2,0,sh),UV=3)
        }

        pref   = pref8.ConvertBits(min(bi,16), fulls=true)
        pref   = Str == 1 && !chroma ? CombinePlanes(pref, inputP, planes="YUV", pixel_type=PixelType(input)) : pref
        blkclp = BlankClip(isInter?AssumeFrameBased(pref):pref,length=1,pixel_type=PixelType(input),color=$161616,channels=0)
                 \.crop(0,hi%8,0,0,true).SeparateFields().AssumeFrameBased().SeparateFields()

        Interleave(SelectEven(blkclp).AddBorders(2,0,0,0,color=$7f7f7f).Crop(0,0,-2,0,true),SelectOdd(blkclp))

        bi == 32 ? ConvertBits(16, dither=-1, fulls=fsp, fulld=fsp) : last
        WOut=Weave().AssumeFieldBased().Weave()
        sep=(hi-Height(WOut))/2

        StackHorizontal(pref,WOut.AddBorders(0,sep-sep%2,0,hi-(Height(WOut)+(sep-sep%2)),color=$161616))


          # Color Guide Squares

        a=h2*(0.74*dbl)       aa=h2*(0.767*dbl)
        b=h2*(0.80*dbl)       bb=h2*(0.827*dbl)
        c=h2*(0.86*dbl)       cc=h2*(0.887*dbl)

        ex_merge(isy ? Expr("151 scalef") : Expr("127 scalef" ,"183 scalef" ,"47  scalef") ,ex_lutspa(Format("x {w3} >= x {w3sq} <= & y {a} >= y {aa} <= & & range_max 0 ?")),luma=true)
        ex_merge(isy ? Expr("132 scalef") : Expr("81  scalef" ,"91  scalef" ,"240 scalef") ,ex_lutspa(Format("x {w3} >= x {w3sq} <= & y {b} >= y {bb} <= & & range_max 0 ?")),luma=true)
        ex_merge(isy ? Expr("235 scalef") : Expr("210 scalef" ,"16  scalef" ,"146 scalef") ,ex_lutspa(Format("x {w3} >= x {w3sq} <= & y {c} >= y {cc} <= & & range_max 0 ?")),luma=true)


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

        Subtitle("SMDegrain Mod v4.5.1",text_color=red||blue||yellow?Color:$7f7f7f,halo_color=$000000,font="VERDANA",size=s*2,x=w1,y=h/round(25/dbl))

        Subtitle("BASIC"   ,lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(            "\n\ntr           = " + string(round(tr/dbl))                                                                   + \
                 varn+varn+      "luma         = " + string(luma)                                                                            + \
                               "\nchroma       = " + string(chroma)                                                                          ,lsp=lsp,text_color=red||blue               ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(          "\n\n\nthSAD(C)     = " + string( GlobalO?"bypass":string(thSAD)     + "(" + string(plane0?thSADC:"bypass") + ")")+ \
                 varn+           "CClip        = " + string( GlobalO?"bypass":(Defined(CClip)?"defined":"Undefined"))                        + \
                             "\n\nInterlaced   = " + string(isInter)                                                                         ,lsp=lsp,text_color=                               $ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+           "Mode         = " + string( GlobalO?"bypass":md=="MedianTn"?"MedianT":(rc?"r":"")+md)                       ,lsp=lsp,text_color=(yellow||red||blue)     ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+         "\nRefineMotion = " + string( GlobalO?"bypass":RefineMotion)                                                  ,lsp=lsp,text_color=yellow                  ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+       "\n\nContrasharp  = " + string( GlobalO?"bypass":contrasharp)                                                   ,lsp=lsp,text_color=yellow&&!GlobalO        ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+varn+    "\nplane        = " + string( GlobalO?"bypass":(plane==0?"0 (Luma)":plane==1?"1 (U plane)":plane==2?"2 (V plane)":plane==3?"3 (Chroma)":"4(Luma+Chroma)")),lsp=lsp,text_color=(red||blue)&&!GlobalO?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle("<-- "+string(IsClip(prefilter)||prefilter!=-1?"Prefiltered clip converted\n    to PC levels":"Clip converted to PC levels\n   ")+" for the motion search", lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1-10,y=hi-round(ys/1.5))

        Subtitle("ADVANCED",lsp=lsp,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(              "\n\npel        = " + string(pel)                                                                             ,lsp=lsp,text_color=red                     ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(            "\n\n\nsubpixel   = " + string( pel==1 ?"bypass":subpixel)                                                      ,lsp=lsp,text_color=(yellow||blue)&&pel!=1  ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+varn+  "\n\n\ntruemotion = " + string( GlobalR?"bypass":truemotion)                                                    ,lsp=lsp,text_color=(yellow||blue)&&!GlobalR?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+             "mfilter    = " + string( GlobalR?"bypass":MFilterB?"Clip"+sp+" Variable":"OFF")                          ,lsp=lsp,text_color=                               $7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+         "\n\nStr        = " + (GlobalR?string("bypass"):string(Str,"%1.2f"))+sp+(Str<1?" Retinex":" Brightness")      + \
                 varn+             "search     = " + string( GlobalR?"bypass":search)                                                        ,lsp=lsp,text_color=yellow&&!GlobalR        ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+varn+        "blksize    = " + string( GlobalR?"bypass":blksize)                                                       + \
                                 "\noverlap    = " + string( GlobalR?"bypass":overlap)                                                       ,lsp=lsp,text_color=(red||blue)&&!GlobalR   ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)
        Subtitle(varn+           "\nprefilter  = " + (GlobalR?string("bypass"):(preclip?"Clip"+sp+" Variable":(prefilter==0?"0"+sp+"    SBR()":prefilter==1?"1"+sp+"    MinBlur(1)":prefilter==2?"2"+sp+"    MinBlur(2)":prefilter==3?"3"+sp+"    IQMV":prefilter==4?"4"+sp+"    IQMST":\
                                                                                                               prefilter==5?"5"+sp+"    DFTTest"   :prefilter==6?"6"+sp+"    KNLmeans"  :prefilter==7?"7"+sp+"    DGDenoise" :prefilter==8?"8"+sp+"    BM3D":"OFF"+sp+"    (-1)"))) + \
                               "\n\nAmp        = " + (GlobalR||str==1.0?string("bypass"):string(Amp,"%1.2f"))+" Amplitude"                   + \
                 varn+           "\nlimit(C)   = " + (GlobalO?string("bypass"):string(limit)     + "(" + string(limitc) + ")")               ,lsp=lsp,text_color=                               $7f7f7f,font="COURIER NEW",size=s,x=w4,y=ys)

        Subtitle("OTHERS"  ,lsp=lsp,text_color=$494949,font="COURIER NEW",size=s,x=w3,y=ys)
        Subtitle(             "\n\n\nthSCD1(2) = " + (GlobalO?string("bypass"):string(thSCD1) + "(" + string(thSCD2) + ")")                  + \
                           varn+"\n\nGlobals   = " + string(Globals==0 ? "0 (OFF)" : Globals==1 ? "1 (Import)" : Globals==2 ? "2 (Export)" : "3 (E.Only)"),lsp=lsp,text_color=                  $494949,font="COURIER NEW",size=s,x=w3,y=ys)
        Subtitle(               "\n\nhpad(v)   = " + string(hpad)   + "(" + string(vpad)   + ")"                                             ,lsp=lsp,text_color=red||blue               ?Color:$494949,font="COURIER NEW",size=s,x=w3,y=ys)
        Subtitle(varn+              "bitdepth  = " + string(bi)                                                                              ,lsp=lsp,text_color=yellow||blue            ?Color:$494949,font="COURIER NEW",size=s,x=w3,y=ys)

        Subtitle("   Speed"   ,lsp=round(30*dbl),text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(a-1))
        Subtitle("   Memory"  ,lsp=round(34*dbl),text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(b-1))
        Subtitle("   Quality" ,lsp=round(38*dbl),text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(c-1))
        }

        isyuy ? ConvertToYUY2(interlaced=isInter) : last }






########################################################
#                                                      #
#                     PREFILTERS                       #
#                                                      #
########################################################


########################################
## Didée's functions:
##
## MinBlur   by Didée (24-10-2006)
## Minimum Blur - Nifty Gauss/Median combination (spatial version of FluxSmoothT)
## (https://forum.doom9.org/showthread.php?p=1018488)
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
##    int r=1 (0 to 3),
##    [string "mode"="median" ("median"/ "blur"/ "blur_horizontal"/ "blur_vertical")],
##    [int "thres"=20 (0 to 255)],
##    [bool "sharp"=false],
##    [bool "old"=false]
##    )
##
function ex_MinBlur(clip clp, int "r", int "UV", string "mode", bool "sharp", int "thres", bool "old", int "Y") {

    rgb     = isrgb(clp)
    bi      = BitsPerComponent(clp)
    fs      = propNumElements (clp,"_ColorRange")  > 0 ? \
              propGetInt      (clp,"_ColorRange") == 0 : rgb

    r       = Default(r,  1)                # 1, 2 or 3. For 3 you can alternatively use ex_median("IQMV")
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

    blurstr = mode == "median"          ? """ex_median("smart"+string(r), th, Y=y, UV=uv)""" : \
              mode == "blur"            ? """ex_boxblur(r*2, r*2, "weighted", Y=y, UV=uv)""" : \
              mode == "blur_horizontal" ? """ex_boxblur(r*2,   0, "weighted", Y=y, UV=uv)""" : \
              mode == "blur_vertical"   ? """ex_boxblur(0,   r*2, "weighted", Y=y, UV=uv)""" : \
              mode

    rg12D = (r==0) ? ex_makediff(clp,clp.ex_sbr(Y=y,UV=uv),      Y=y,UV=uv,fulls=fs)                                               : \
            (r==1) ? ex_makediff(clp,clp.removegrain(rg12y,rg12),Y=y,UV=uv,fulls=fs)                                               : \
            (r==2) ? ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20),Y=y,UV=uv,fulls=fs)                       : \
                     ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20).removegrain(rg20y,rg20),Y=y,UV=uv,fulls=fs)

    RG4D  =  old               ? (rg4v) ? clp.removegrain(rg4y,rg4)   : med ? clp.ex_median(r==2?"median5":"median7",Y=y,UV=uv)    : Eval("clp."+blurstr+"") :\
                                 (rg4v) ? clp.removegrain(rg27y,rg27)                                                              : Eval("clp."+blurstr+"")
    RG4D  = !old && !sh && med ? (r<=1) ? RG4D.ex_boxblur(r==0?0.3:0.5,mode="weighted",Y=y,UV=uv) : RG4D.removegrain(rg12y,rg12)   : RG4D

    ex_lutxyz(clp, rg12D, RG4D,"y "+bi32+" A@ x z - B@ * 0 < x A abs B abs < x A - z ? ?",Y=y,UV=uv,fulls=fs)

    (!old && !med || old) && sh ? Repair(clp.removegrain(y!=3 ? 0 : 17,uv==3 ? 0 : -1),y!=3 ? 0 : 9, 0) : last }



## sbr()   by Didée (25-03-2009)
## Sharp Blur Repair - Make a highpass on a blur's difference (well, kind of that)
## (https://forum.doom9.org/showthread.php?p=1265491)
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

    r      = Default(r,  1) # 1, 2 or 3.
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

    rg12D  = ex_makediff(c, rg12, Y=Y31, UV=UV31, fulls=fs)

    RG12DS = (r<=1) ? rg12D.removegrain(Y12, UV12)                                             : \
             (r==2) ? rg12D.removegrain(Y12, UV12).removegrain(Y20, UV20)                      : \
                      rg12D.removegrain(Y12, UV12).removegrain(Y20, UV20).removegrain(Y20, UV20)

    ex_lutxyz(c, RG12D, RG12DS, "y z - A@ y "+bi32m+" B@ * 0 < x A abs B abs < A B ? x swap - ?", Y=Y31, UV=UV31, fulls=fs) }


# BUG, when input and output is PC range, 'lo' and 'hi' won't work
## Dither_Luma_Rebuild()  by cretindesalpes (02-01-2012)
##  https://forum.doom9.org/showthread.php?p=1548318
##  Converts luma (and chroma) to PC levels, and optionally allows tweaking for pumping up the darks. (for the clip to be fed to motion search only)
##
## Function Definition:
##    (
##    clip,
##    float S0=5.0 (1.0 to 9.0),
##    float c=0.03 (0.00 to 1.00),
##    [int "lo"=0 (0 to 32)],
##    [int "hi"=255 (220 to 255)],
##    [bool "tv_out"=false],
##    [bool "show"=false]
##    )
##
function ex_Luma_Rebuild (clip src, float "s0", float "c", int "lo", int "hi", int "Y", int "UV", bool "tv_in", bool "tv_out", int "bits", bool "show") {

    rgb   = isrgb(src)
    bi    = BitsPerComponent(src)
    fs    = propNumElements (src,"_ColorRange")  > 0 ? \
            propGetInt      (src,"_ColorRange") == 0 : rgb

    lod   = Defined(lo)
    hid   = Defined(hi)
    Y     = Default(Y,          3)
    UV    = Default(UV,         3)
    s0    = Default(s0,       5.0)
    c     = Default(c,     1.0/32)
    bit   = Default(bits,      bi)
    tv    = Default(tv_in,    !fs)
    tvo   = Default(tv_out, false)
    lop   = Default(lo, !tv ?   0 :  16)
    hip   = Default(hi, !tv ? 255 : 235)
    sh    = Default(show,   false)
    bi32  = bi == 32
    si    = bi32 && UV==3 ? "floatUV" : tv ? "none" : "intf"

  # RATIONALE (TV to PC and lerp in one shot)
    lox   = (tv ? lop-16       : lop    ) + 1
    rn    = (tv ? hip+20 - lox : hip-lop) - 1
    mn    = (lox*rn+16*rn)-(lox*16)
    mul   = bi==32 ? 1 : BitLShift(1, bi-8)
    mn    = ex_bs(mn,   8, bi, tv_in=false, tv_out=false, clamp=false)
    lob   = ex_bs(lox-1,8, bi, tv_in=false, tv_out=false)
    div1  = ex_bs(rn,   8, bi, tv_in=false, tv_out=false)
    div2  = ex_bs(219,  8, bi, tv_in=false, tv_out=false)
    mx    = ex_bs(255,  8, bi, tv_in=false, tv_out=false)


    k  = (s0 - 1) * c
    l  = 1 - k
    d  = 1 + c
    f  = d * c
    lh = (lod || hid ) && ((lop != (!tv ? 0 :  16)) || (hip != (!tv ? 255 : 235)))
    t  = tv  ? "ymin - 0 max ymax ymin - /" : ""
    t  = lh ? tv ? bi==32 ? Format("{mn} 255 / - 0 max {div1} {div2} * / ")               : \
                            Format("range_max * {mn} {mul} * - 0 max {div1} {div2} * / ") : \
                            Format("{lob} - 0 max {div1} / ")                             : t
    o  = tvo ? " ymax ymin - * ymin +"      : ""
    e  = Format("f32 {k} {d} {f} x "+t+" A@ {c} + / - * A {l} * +") + (!tvo && !bi32 && !rgb ? " range_max *" : tvo ? o : "")
    ec = tv==tvo ? "" : !tvo ? "x cmin - range_max cmax cmin - / *" : "x cmax cmin - range_max / * cmin +"

    if (S0 > 1.0) {
        ex_lut(src, e, rgb ? e : ec, Y=y, UV=uv, fulls=!tv, scale_inputs=si, clamp_float=bi32)
        ConvertBits(bit, dither=-1, fulls=!tvo)
        tv!=tvo ? propSet("_ColorRange", !tvo ? 0 : 1) : last
    } else {
        ConvertBits(src, bit, dither= lh ? 1 : -1, fulls=!tv, fulld=!tvo)  # dither=-1 because ex_Luma_Rebuild() typically used for prefiltering
    }
    propNumElements("_SceneStats") > 0 ? propDelete("_SceneStats") : last

    if (sh) {

        bit > 8 ? ConvertBits(8,dither=1,fulls=!tvo) : last
        w   = src.width()
        h   = src.height()
        sw  = nmod(w/5.)   sh = sw
        plt = GradientLinear(last, zoom=1, precision=4, positive=true, smooth=true, tv_range=tv)
        plt = ex_Luma_Rebuild(plt,s0,c,lop,hip,tv_in=tv,tv_out=tvo)
        plt = HistoCurve(plt,size=2,gradient=false).BicubicResize(sw,sh,-0.5,0.25)
        plt = PadBorders(plt,w-sw,0,0,h-sh)
        plt = Merge(last,rgb ? plt.ConvertToPlanarRGB() : plt)
        ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
    } }



## ex_retinex()   by Dogway (20-02-2023)
## Multi-Scale Retinex
##
## Optimized MSR for only Luma channel, akin to MSRCP but without going through RGB.
## Output is PC range.  Performance is by default 50% of ex_Luma_Rebuild() although still fast and quality isn't comparable.
## lvl=2 uses auto-levels so performance drops to 25% of ex_Luma_Rebuild(), and prone to some "smooth flicker".
## lvl=3 uses SceneStats so there's no "smooth flicker", but performance drops further.
## Gamma aware + PC levels blurring didn't yield better results, actually worse. RGB isn't supported yet despite code reference.
##
## "Contrast enhancement is a classic image restoration technique that traditionally has been performed using forms of histogram equalization.
##  While effective these techniques often introduce unrealistic tonal rendition in real-world scenes. This paper explores the use of Retinex theory to perform
##  contrast enhancement of real-world scenes. We propose an improvement to the Multi-Scale Retinex algorithm which enhances its ability to perform
##  dynamic range compression while not introducing halo artifacts and greying."
##
## [2] P. Robinson, Y. Roodt and A. Nel. "Adaptive Multi-Scale Retinex algorithm for contrast enhancement of real world scenes".
##     In the Proceedings of Twenty - Third Annual Symposium of the Pattern Recognition Association of South Africa, Pretoria, South Africa,
##     Edited by Alta de Waal, November 29 - 30, 2012.
##
## Dependencies:
##               ExTools
##               GradePack
##               ResizersPack
##               ScenesPack     (for lvl=3)
##               TransformsPack (for RGB)
##
## Example:
##
##     # ex_retinex() will apply an HDR like contrast enhancement, that is, it will also optimize highlight contrast
##     # To only apply shadow enhancement, set highlights=false
##
##         ex_retinex(lvl=1,tv_in=false,tv_out=false,highlights=false)
##
##     # equals but faster (when lvl=1) than:
##
##         a=last
##         a=ex_retinex(lvl=1,tv_in=false,tv_out=false)
##         ex_merge(a,LumaMask(lo=80, hi=240, invert=true),luma=true)
##
##
## Function Definition:
##    (
##    clip,
##    int "lvl"=1 (0 to 3),
##    [float "lo"=50.0 (0.0 to 128.0 by 1.0)],
##    [float "hi"=242.0 (128.0 to 255.0 by 1.0)],
##    [float "sigma"=1.0 (1.0 to 5.0)],
##    [bool "highlights"=false],
##    [bool "tv_out"=false]
##    )
##
function ex_retinex(clip clp, int "lvl", float "lo", float "hi", float "sigma", bool "highlights", bool "tv_in", bool "tv_out", int "UV") {

    w     = width (clp)
    h     = height(clp)
    wh    = max(w,h)
    rgb   = isRGB (clp)
    isy   = isy   (clp)
    bi    = BitsPerComponent(clp)
    rn    = propNumElements (clp,"_SceneRange")  > 0
    fs    = propNumElements (clp,"_ColorRange")  > 0 ? \
            propGetInt      (clp,"_ColorRange") == 0 : rgb
    isHD  = (w > 1099 || h > 599 )
    isUHD = (w > 2599 || h > 1499)

    lvl   = Default(lvl,  rn ? 3 : 1)        # 0: MSR output   1: Fixed levels output  2: auto-levels  3: scene's levels (requires '_SceneRange' frame properties present)
    hl    = Default(highlights, true)        # Set to false to only recover shadows. For lvl=3 it might cause mid-range expansion (loss of shading) so in this case probably ex_luma_rebuild() should be more indicated as it spreads the expansion through the rest of the range.
    lo    = Default(lo,  lvl==1?50:4)        # value in input range levels of low  level for normalization in lvl=1. For lvl=2 the divisor for the low level percentile (Reminder: crop black borders)
    hi    = Default(hi,!hl?255:255-lo/3.)    # value in input range levels of high level for normalization in lvl=1.
    r     = Default(sigma,         1)        # Multiplier. 1 to 5 roughly (leave it at 1 for the most time)
    tv    = Default(tv_in,       !fs)        # Range of input  clip
    tvo   = Default(tv_out,       tv)        # Range of output clip
    UV    = Default(UV,  tvo ? 3 : 2)        # Set to 3 to convert Chroma to TV range if tv_out=true
    bi32  = bi==32
    si    = tv ? "none" : "intf"

    hll   = hl || lvl>1
    mn    = tvo ? 16      : 0
    mx    = tvo ? 255-235 : 0

    if (!hl) {
        MAX  =            ex_bs(255, 8, 32, fulls=true)
        HR   =            ex_bs(240, 8, 32, tv_in=false, tv_out=tvo) # mask threshold 'hi' when highlights=false and lvl<2
        LR   =            ex_bs(80,  8, 32, tv_in=false, tv_out=tvo) # mask threshold 'lo' when highlights=false and lvl<2
        LIM  = 1. / (HR - LR)
    }
        LON  =            ex_bs(lo,  8, 32, tv_in=tv,    tv_out=false)
        HIN  = !hl? MAX : ex_bs(hi,  8, 32, tv_in=tv,    tv_out=false)


    a    = isy ? clp : !rgb ? clp.ExtractY() : isUHD ? clp.DotClip([0.262372,0.678464,0.059164]) : \
                                                isHD ? clp.DotClip([0.212600,0.715179,0.072221]) : \
                                                       clp.DotClip([0.298912,0.586603,0.114485])
    y    = a.ConvertBits(8, dither=-1, fulls=!tv, fulld=!tv)
    b    = y.ex_GaussianBlur(wh*0.015 * r,pad=true).ConvertBits(bi, fulls=!tv, fulld=!tv)
    c    = y.ex_GaussianBlur(wh*0.05  * r,pad=true).ConvertBits(bi, fulls=!tv, fulld=!tv)
    d    = y.ScriptClip(function [] () { ex_lut(string(AverageLuma(last))) } ).ConvertBits(bi, fulls=!tv, fulld=!tv)

    rangePC =                          tv  ? "ymin - ymax ymin - /"                                           : ""
    rangeTV =                          tvo ? "ymax ymin - * ymin +" : tv && !bi32 ? "range_max * "            : ""
    str     = Format("f32 x "+rangePC+(hll ? "" : " A@")+" 0.002 max A@ log y 0.2 * z 0.1 * a 0.7 * + + "+rangePC+" A * log / 1 swap - ")
    str     = str + (lvl!=1                ? ""      : Format("{LON} - {HIN} {LON} - / ") + (hl ? "0 1 clip " : ""))
    str     = str + (hll                   ? rangeTV : Format("dup A - A {LR} - {LIM} * 0 1 clip neg * + ") + rangeTV)

    MSR     = ex_lutxyza(a,b,c,d, str, fulls=!tv, scale_inputs=si, clamp_float=bi32)


    if        (lvl<2) {

        MSR

    } else if (lvl==2) {

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

        ScriptClip(MSR, function [TS,rgb,lo,mn,mx,hl] () {

            sts  = PlaneMinMaxStats(TS, 1./lo, 0, 0, false)
            pmin = sts[2]
            pmax = sts[1]

            pmin > 0 || (hl && pmax < 255) ? ex_levels(max(0,pmin-mn),1.0,!hl ? 255 : min(255,pmax+mx),0,255,false,rgb?3:1) : last
        } )

    } else {

        Assert(rn, "ex_retinex: lvl=3 requires '_SceneRange' frame properties")
        MSR
        SceneStats("Stats")

        ScriptClip(function [rgb,mn,mx,hl,bi] () {

            sts  = propGetAsArray("_SceneStats")
            pmin = sts[2]
            pmin = bi>8 ? ex_bs(pmin, bi, 8, fulls=true, flt=true) : pmin
            pmax = sts[1]
            pmax = bi>8 ? ex_bs(pmax, bi, 8, fulls=true, flt=true) : pmax

            pmin > 0 || (hl && pmax < 255) ? ex_levels(max(0,pmin-mn),1.0,!hl ? 255 : min(255,pmax+mx),0,255,false,rgb?3:1) : last
        } )

        propDelete("_SceneStats")
    }

    UV != 128 ? !isy ? CombinePlanes(last, clp, planes=rgb ? "RGB" : "YUV", pixel_type=PixelType(clp)).\
                       propCopy(clp,true,props="_ChromaLocation")  : last : last
                       propSet("_ColorRange", tvo ? 1 : 0)
    UV == 3  && !isy ?          tv!=tvo ? SMPTE_legal(tvo,Y=1)     : last : last

    lvl>1    && !hl  ? ex_merge(tv!=tvo ? SMPTE_legal(clp,tvo):clp,LumaMask(a, lo=70, hi=140, invert=false), luma=false, UV=rgb?3:1) : last }




# Wrapper for BM3D CUDA by WolframRhodium for AviSynth+
#   https://github.com/WolframRhodium/VapourSynth-BM3DCUDA/issues/7
#   test10 for Win10, test10-cuda118 for Win7
#
# BM3D is a state-of-the-art image and video denoising algorithm.
# It performs best in OPP model rather than RGB or YCbCr.
# The spatial feature set hasn't been ported to AVS+ though.
# Requires TransformsPack for OPP=true, RGB clips or processing chroma.
#
# Disclaimer: BM3D() causes issues when gpuid >= 0 (CUDA) and a high combination of radius + sigma unless you fine tune 'block_step' argument
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
#    float sigma=3.0 (1.0 to 30.0 by 0.5),
#    [int "radius"=1 (1 to 5)],
#    [string "preset"="Low" ("Fast"/ "Low"/ "Normal"/ "High"/ "Noisy")],
#    [int "gpuid"=0 (-1 to 2)],
#    [bool "OPP"=true]
#    )
#
function ex_BM3D(clip a, float "sigma", int "radius", string "preset", bool "OPP", int "UV", bool "tv_range", int "gpuid") {

    rgb  = isRGB(a)
    isy  = isy  (a)
    bi   = BitsPerComponent(a)
    pID  = color_propGet   (a)

    s    = Default(sigma,      3)  # Denoising strength
    md   = Default(preset, "Low")  # Fast, Low, Normal, High, Noisy
    OPP  = Default(OPP,      rgb)  # RGB clips hard-coded to OPP=true
    UV   = Default(UV,    rgb ? 3 : 1)
    tv   = Default(tv_range, pID[6])
    gid  = Default(gpuid,      0)
    cd   = gid > -1
    pri  = pID[2]
    mat  = pri+(tv?":l":":f")

    pr   = md == "Fast"   ? 0 : \
           md == "Low"    ? 1 : \
           md == "Normal" ? 2 : \
           md == "High"   ? 3 : \
           md == "Noisy"  ? 4 : \
           Assert(false, "ex_BM3D: Wrong 'preset' mode")

    #                                         fast      lc          np            high           vn
    r          = Default( radius, Select(pr,  1,         2,         3,             4,             4          ) ) # temporal radius
    block_step =                  Select(pr, [8,7,8,7], [6,5,6,5], [4,3,4,3],     [3,2,3,2],     [4,6,4,6]     )
    bm_range   =                  Select(pr, [9,9,7,7], [9,9,9,9], [16,16,12,12], [16,16,16,16], [16,16,12,12] )
    ps_range   =                  Select(pr, [4,5] ,    [4,5] ,    [5,6],         [7,8],         [5,6]         )

    block_step = cd && (pr==0 || pr==2) ? ArrayOp(block_step,1,"-") : block_step

    a
    ch = !(isy || UV!=3)
    ch && !rgb && !OPP ? ConvertToYUV444   (matrix=mat,chromaresample="bicubic",param1=0,param2=0.5) : last
          !rgb &&  OPP ? ConvertToPlanarRGB(matrix=mat,chromaresample="bicubic",param1=0,param2=0.5) : last
           rgb ||  OPP ? RGB_to_OPP().ConvertBits(32, fulls=true, fulld=true) : ConvertBits(32, fulls=!tv, fulld=!tv)

    cs = rgb || OPP ? s : ch ? s/2.0 : 0

    cd ? BM3D_CUDA(sigma=[s,cs,cs], radius=r, chroma=ch, block_step=block_step, bm_range=bm_range, ps_range=ps_range, fast=true, extractor_exp=6, device_id=gid) : \
         BM3D_CPU (sigma=[s,cs,cs], radius=r, chroma=ch, block_step=block_step, bm_range=bm_range, ps_range=ps_range)
         BM3D_VAggregate(radius=r)

    if (rgb || OPP) {
        bi != 32    ? ConvertBits(bi, dither=1, fulls=true, fulld=true) : last
        OPP_to_RGB()
        !rgb && OPP ? MatchClip(a,matrix=pri) : last
    } else {
        bi != 32 ? ConvertBits(bi, dither=1, fulls=!tv, fulld=!tv)      : last
        isy ? ExtractY() : CombinePlanes(last,a,planes="YUV",pixel_type=PixelType(a)) }

    propCopy(a,true,props="_ChromaLocation") }




## ex_DGDenoise() - DGDenoise GPU denoiser wrapper
##
## CUDA implementation of non-local means denoising.
## Output is soft, similar to Photoshop's Surface Blur, so works well as prefilter, specially for anime.
## Supports YUV format at any bitdepth.
##
## Function Definition:
##    (
##    clip,
##    float str=0.10 (0.00 to 1.00),
##    [float strc=0.05 (0.00 to 1.00)],
##    float "bl"=0.00 (0.00 to 1.00),
##    [float "blc"=0.00 (0.00 to 1.00)],
##    int "searchw"=9 (5 to 9 by 2),
##    int "UV"=1 (1 to 3)
##    )
##
function ex_DGDenoise(clip a, float "str", float "strc", float "blend", float "blendc", int "searchw", float "LFR", bool "DCT", int "UV") {

    w   = width (a)
    h   = height(a)
    isy = isY   (a)
    is20= is420 (a)
    rgb = isrgb (a)
    bi  = BitsPerComponent(a)
    pID = color_propGet   (a)

    str  = Default(str,      0.10)
    strc = Default(strc,   str/2.)
    bl   = Default(blend,       0)
    blc  = Default(blendc,      0)
    srch = Default(searchw,  min(9,max(5,round(w/1.51>h?0.375*w+1.8:0.667*h+1.8))))
    LFR  = Default(LFR,         0)
    DCT  = Default(DCT,      true)
    UV   = Default(UV,rgb ? 3 : 1)
    strc = UV==3 ? strc : 0
    tv   = pID[6]
    pri  = pID[2]
    mat  = (!tv?"PC":"Rec")+pri

    a
    !is20 ? ConvertToYUV420(matrix=mat,chromaresample=isy||UV!=3?"point":"bicubic",param1=-0.5,param2=0.25) : last
    bi>8 && bi!= 16 ? ConvertBits(16, fulls=!tv, fulld=!tv)                                                 : last
    al = last

    DGDenoise(str,strc,bl,blc,srch)

    LFR > 0 ? ex_LFR(al,LFR,DCT,UV=UV) : last
    ConvertBits(bi, dither=bi==32?-1:1, fulls=!tv, fulld=!tv)

    isy     ? ExtractY()                                       : \
    UV==3   ? is20 ? last : MatchClip(a,matrix=pri)            : \
    CombinePlanes(last,a,planes="YUV",pixel_type=PixelType(a)) }



## ex_KNLMeansCL() - KNLMeansCL wrapper by Dogway (08-02-2022)
##
## OpenCL implementation of the non-local means denoising algorithm.
##
## Function Definition:
##    (
##    clip,
##    float h=7.0 (1.0 to 15.0 by 0.5),
##    int d=0 (0 to 6),
##    int a=1 (1 to 6),
##    int s=2 (1 to 6),
##    int wmode=0 (0 to 2),
##    [int "LFR"=0 (0 to 1920)],
##    bool "chroma"=true,
##    [int "gpuid"=0 (-1 to 2)]
##    )
##
function ex_KNLMeansCL (clip c, float "h", int "d", int "a", int "s", int "wmode", clip "rclip", float "LFR", bool "DCT", bool "chroma", int "gpuid", float "wref", string "knlm_params") {

    w2           = c.width()
    h2           = c.height()

    h            = Default( h, 7.0)         # Sigma
    d            = Default( d,   0)         # Temporal radius
    a            = Default( a,   1)         # Spatial  radius
    s            = min(Default( s, a*2),8)  # Spatial  radius of the similarity neighborhood
    wmode        = Default( wmode,  0)
    wref         = Default( wref, 1.0)
    gpuid        = Default( gpuid,  0)      # Set to -1 for "cpu" mode (currently -2022- not implemented)
    chroma       = Default( chroma, true)
    LFR          = Default( LFR, wmode < 1 || d > 0 ? min(2,d+1)*300*(w2/1920.) : 0) # Restore low frequency details, specially on wmode=0, and more specially with d > 0 (motion estimation is very bad in KNLMeansCL). Set to 0 to disable.
    DCT          = Default( DCT,    true)
    knlm_params  = Defined( knlm_params) ? ","+knlm_params : ""
    device_type  = gpuid < 0 ? "cpu" : "gpu"

    isy     = c.isy()
    rgb     = c.isrgb()
    is44    = c.is444()
    is20    = c.is420()

    stacked = chroma && !is44 && !isy
    UV      = stacked ? "Y" : rgb ? "auto" : !isy && chroma ? "YUV" : "Y"
    UVb     = chroma ? 3 : 2
    dwclip  = Defined( rclip )
    wclip   = dwclip ? rclip : Undefined()

    If (stacked && !rgb) {

        Uclip   =          ExtractU(c)
        Uwclip  = dwclip ? ExtractU(wclip) : nop()
        Vclip   =          ExtractV(c)
        Vwclip  = dwclip ? ExtractV(wclip) : nop()
        UVstack = is20   ? StackVertical  (Uclip, Vclip)              : \
                           StackHorizontal(Uclip, Vclip) # otherwise 422 horizontal stack
        UVwstack= dwclip ? (is20   ? StackVertical  (Uwclip, Vwclip)  : \
                                     StackHorizontal(Uwclip, Vwclip)) : nop()

        nlc     =          StackHorizontal(ExtractY(c),    UVstack )
        nlrc    = dwclip ? StackHorizontal(ExtractY(wclip),UVwstack)  : Undefined()

        nlckl   = Eval("  nlc.KNLMeansCL(D=d, A=a, h=h, s=s, device_type=device_type, device_id=gpuid, rclip=nlrc,  wmode=wmode, wref=wref, channels=UV" + knlm_params + ")")
        nlc     = LFR > 50 ? ex_LFR(nlckl,nlc,LFR,DCT,UV=UVb) : nlckl

        uvw     = Uclip.width ()
        uvh     = Uclip.height()

        nly     =          nlc.crop(0,0,is20 ? -uvw : -(uvw+uvw),0, true)

        nlu     = is20   ? nlc.crop(w2,0,0,-uvh,  true) : \
                           nlc.crop(w2,0,-uvw,0,  true)
        nlv     = is20   ? nlc.crop(w2,uvh,   0,0,true) : \
                           nlc.crop(w2+uvw,0,0,0 ,true)

                  CombinePlanes(nly, nlu, nlv, planes="YUV", pixel_type=PixelType(c))

        } else {

                out = Eval("c.KNLMeansCL(D=d, A=a, h=h, s=s, device_type=device_type, device_id=gpuid, rclip=wclip, wmode=wmode, wref=wref, channels=UV" + knlm_params + ")")
                out = LFR > 50 ? ex_LFR(out,c,LFR,DCT,UV=UVb) : out
                out

        }
                propCopy(c,true,props="_ChromaLocation") }


# Simplified port of JDL_UnfoldFieldsVertical by stickboy (07-08-2003)
#
#   Separates the fields in a clip and stacks them vertically.
#   Regardless of field order, even fields are on top.
#
#   Useful for applying spatial-temporal filters to interlaced
#   video.
#
# PARAMETERS:
#   "flip" : Pass true to flip the bottom field vertically.
#            Useful when dealing with spatial filters.
#            (Default: false)
#
function SMD_UnfoldFieldsVertical(clip c, bool "flip", bool "TFF") {

    flip   = Default(flip, false)
    TFF    = Default(TFF,   true)
    c      = c.AssumeTFF().SeparateFields()
    top    = c.SelectEven()
    bottom = c.SelectOdd()
    StackVertical(top, flip ? bottom.FlipVertical()
    \                       : bottom)
    propSet("_FieldBased", 0)
    }

# Simplified port of JDL_FoldFieldsVertical by stickboy (07-08-2003)
#
#   Recombines the fields from a clip that resulted from calling
#   SMD_UnfoldFieldsVertical. Undoes the work of SMD_UnfoldFieldsVertical.
#
# PARAMETERS:
#   "flip" : Pass true if the bottom field was flipped
#            vertically with SMD_UnfoldFieldsVertical.
#            (Default: false)
#
function SMD_FoldFieldsVertical(clip c, bool "flip", bool "TFF") {

    w      = c.Width()
    oh     = c.Height() / 2
    flip   = Default(flip, false)
    TFF    = Default(TFF,   true)
    top    = c.Crop(0, 0,  w, oh)
    bottom = c.Crop(0, oh, w, oh)
    bottom = flip ? bottom.FlipVertical() : bottom
    Interleave(top, bottom).AssumeFieldBased()
    TFF ? AssumeTFF() : AssumeBFF()
    Weave()
    propSet("_FieldBased", TFF ? 2 : 1)
    }
