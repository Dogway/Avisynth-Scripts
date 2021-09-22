################################################################################################
###                                                                                          ###
###                           Simple MDegrain Mod - SMDegrain()                              ###
###                                                                                          ###
###                       Mod by Dogway - Original idea by Caroliano                         ###
###                                                                                          ###
###          Special Thanks: Sagekilla, Didée, cretindesalpes, Gavino and MVtools people     ###
###                                                                                          ###
###                       v3.1.2d      by Dogway - 21 July 2015                              ###
###                       v3.1.2.111s  by A.SONY.- 09 Febr 2021                              ###
###                       v3.3.1d      by Dogway - 22 Sept 2021                              ###
###                                                                                          ###
################################################################################################
###
### General purpose simple degrain function. Pure temporal denoiser. Basically a wrapper(function)/frontend of mvtools2+mdegrain
### with some added common related options. Goal is accessibility and quality but not targeted to any specific kind of source.
### The reason behind is to keep it simple so aside ExTools you will only need MVTools2.
###
### Check documentation for deep explanation on settings and defaults.
### https://forum.doom9.org/showthread.php?t=182881
###
### UHD: Degrain (or at least add as prefilter) the decoded (and tonemapped) PQ clip (ie. DGHDRtoSDR(mode="pq",white=100))
###
################################################################################################


function SMDegrain (clip input   , int "tr"      , int "thSAD"    , int  "thSADC" , bool "RefineMotion",  val  "contrasharp", clip  "CClip"     , string "mode"     , bool "interlaced" , int   "plane"  , int   "Globals"   , bool "tv_range" ,  \
                     int "pel"   , int "subpixel", val "prefilter", clip "mfilter", int  "blksize"     , int   "overlap"    , float "limit"     , float "limitC"    , bool "limitS"     , int "thSCD1"   , int "thSCD2"      ,  \
                    bool "chroma", int "hpad"    , int "vpad"     , val  "Show"   , float "Str"        , float "Amp"        , int   "DCT"       , int "searchparam" , int "pelsearch"   , int   "search" , bool "truemotion" ,  \
                  int "device_id", bool "trymany", int "divide"   , int "srfilter", int "threads"      , bool "UHDhalf"     , bool "fulls") {

    rgb    = isRGB(input)
    bi     = BitsPerComponent(input)
    w      = input.width ()
    h      = input.height()
    p_type = input.PixelType()

    md           = Default( mode, "MDegrain")
    T3           = md == "medianT"  || md == "MedianST" || md == "ML3DEx"
    T5           = md == "medianT5" || md == "STWM"     || md == "GaussT5"
    TS           = md == "TemporalSoften"

    tr           = Default( tr,       2 )
    tr           = T3 ? 1 : T5 ? 2 : tr
    thSAD        = Default( thSAD,  300 )
    thSAD2=thSAD/2
    thSADC       = Default( thSADC, thSAD2)
    RefineMotion = Default( RefineMotion, false)

    Threads      = Default( Threads, sh_GetUserGlobalIMTint(true))
    trymany      = Default(trymany, false)
    divide       = Default(divide,    0 )

    Globals      = Default( Globals,  0 )
    GlobalR      = Globals == 1
    GlobalO      = Globals == 3

    isCClip      = Defined(CClip)
    Contrasharp  = Default( Contrasharp, !GlobalO && isCClip)
    SLimit       = Default( limitS,      true )  # Limit type for the contrasharpening   True: Spatial  False: Temporal
    isInter      = Default( Interlaced,  false)
    InterPar     = isInter ? GetParity(input) : nop()


    UHDhalf      = Default( UHDhalf,  true)
    isCntr       = IsBool(Contrasharp)
    isShrp       = !isCntr ? (Contrasharp > 0.0) : Contrasharp
    isMult       = tr > 6                        # MDegrainN is slower, so avoid >6 at possible
    isHD         = (w > 1099 ||  h > 599)
      UHD        = (w > 2599 ||  h > 1499)
    isUHD        = UHD && !UHDhalf
    UHDhalf      = UHD &&  UHDhalf

    Str          = Default( Str, 3.0 )           # 0: Automatic Range Conversion (with FrameProps)  0.0-1.0: Multi-Scale Retinex  >1.0: ex_luma_rebuild(Str)   (from 0.0 to 1.0 indicates ex_retinex() black level clipping value)
    Amp          = Default( Amp, 0.0625 )
    DefTV        = Defined(tv_range)
    tv           = Default(tv_range, !rgb)
    fs           = Default(fulls,     rgb)

    preclip      = IsClip ( prefilter )
    prefilter    = Default( prefilter, -1 )
    pel          = Default( pel, isHD ? 1 : 2 )
    subpixel     = Default( subpixel, pel)
    srfilter     = Default( srfilter, 4)
    MFilterB     = Defined( mfilter )
    pelclip      = pel>1 && subpixel == 3

    blksize      = Default( blksize,  isHD ? 16 : 8 )
    blk2=blksize/2
    overlap      = Default( overlap,  blk2 )
    ovl2=overlap/2
    search       = Default( search,   4 )
    searchparam  = Default( searchparam, isUHD ? 1 : 2 )
    pelsearch    = Default( pelsearch,   pel )
    truemotion   = Default( truemotion, TS || !isHD)
    DCT          = Default( DCT,   0 )            # Change to 5 (slower) if you get artifacts due to luminosity changes (fades, flashes, etc)
    thSCD1       = Default( thSCD1,  round(pow((blksize*2.5),2)))
    thSCD2       = Default( thSCD2,  130 )

    plane        = Default( plane,    4 )
    chroma       = Default( chroma, true)
    Chr          = chroma ? 3 : 1
    plane0       = plane!=0
    U            = plane0 && plane!=2 ? 3 : 2
    V            = plane0 && plane!=1 ? 3 : 2

    scaleCSAD = is420(input)   ? isHD ? 1 :  0 : \
                is422(input)   ? isHD ? 1 :  0 : \
                is444(input)   ? isHD ? 1 :  1 : \
                isYV411(input) ? isHD ? 0 : -1 : \
                                 isHD ? 1 :  0


    hpad         = Default( hpad, isHD ? 0   : blksize)
    hpadU        = isUHD ? hpad/2+(hpad/2)%2 : hpad
    vpad         = Default( vpad, isHD ? 0   : hpad)
    vpadU        = isUHD ? vpad/2+(vpad/2)%2 : vpad
    limit        = Default( limit, isUHD ? 2 : 255 )  # auto-scaled
    limitc       = Default( limitc,limit)

    sShow        = IsString(show)
    Show         = Default( Show,  false)



    # Error Report
                      Assert(IsVersionOrGreater(3,5,0),    "Update AviSynth+ version")
                      Assert(blksize==4 || blksize==8 || blksize==16 || blksize==32,"MAnalyse: Block's size must be 4x4, 8x4, 8x8, 16x2, 16x8, 16x16, 32x16, 32x32")
                      Assert(overlap <= blk2,              "Overlap must be at least half blksize or less")
                      Assert(overlap == overlap-overlap%2, "MAnalyse: overlap must be an even figure")
                      Assert(IsBool(Show) || sShow,        "'Show' only accepts bool inputs (true,false), or string modes ('Speed','Memory',Quality')")
                      Assert(preclip || IsInt(prefilter),  "'prefilter' only accepts integers and clip inputs")
                      Assert(isCntr  || IsInt(Contrasharp),"'Contrasharp' only accepts integers and bool inputs")
    MFilterB        ? Assert(IsClip(mfilter),              "'mfilter' only accepts clip inputs")                        : nop()
    isInter         ? Assert(h%4==0,                       "Interlaced sources require mod 4 height sizes")             : nop()
    RefineMotion    ? Assert(blksize > 7,                  "For RefineMotion you need a blksize of at least 8")         : nop()



    # RefineMotion Variables

    halfblksize  = RefineMotion ?  blk2                                  : nop() # MRecalculate works with half block size
    halfoverlap  = RefineMotion ? (overlap == 2 ? overlap : ovl2+ovl2%2) : nop() # Halve the overlap to suit the halved block size
    halfthSAD    = RefineMotion || isMult ? thSAD2                       : nop() # MRecalculate uses a more strict thSAD, which defaults to 150 (half of function's default of 300)
    halfthSADC   =                 isMult ? thSADC/2                     : nop() # For MDegrainN()




    # Input preparation for: Interlacing and MSuper optimization when pel=2

    inputP  = !isInter    ? (pel == 2 ? input.AssumeFrameBased()             : input)                             : \
                            (InterPar ? input.AssumeTFF().SeparateFields()   : input.AssumeBFF().SeparateFields())

    # Prefilter & Motion Filter

    Mfilter = MFilterB ? MFilter : inputP
    Lthres  = ex_bs(75, 8, bi, tv_in=true, tv_out=tv, fulls=fs)

    pref   = !GlobalR ? preclip ? prefilter                                                                                                                                                                         : \
                                 (prefilter==-1) ?  inputP                                                                                                                                                          : \
                                 (prefilter== 0) ?  inputP.ex_MinBlur(0,Chr,fulls=fs)                                                                                                                               : \
                                 (prefilter== 1) ?  inputP.ex_MinBlur(1,Chr,fulls=fs)                                                                                                                               : \
                                 (prefilter== 2) ?  inputP.ex_MinBlur(2,Chr,fulls=fs)                                                                                                                               : \
                                 (prefilter== 3) ?  ex_merge(dfttest(inputP,sstring="0.0:4.0 0.2:9.0 1.0:15.0",tbsize=1,U=chroma,V=chroma,dither=1,threads=1),inputP,                                                 \
                                                    inputP.ex_lut(Format("x ymin < range_max x {Lthres} > 0 range_max x ymin - range_max {Lthres} ymin - / * - ? ?"),UV=1,fulls=fs), luma=chroma, UV=chr, fulls=fs) : \
                                 (prefilter== 4) ?  inputP.ex_KNLMeansCL(a=1,d=1,h=7.0,chroma=chroma,device_type="GPU",device_id=device_id)                                                                         : \
                                 (prefilter== 5) ?  inputP.ex_BM3D(sigma=5,radius=1,CUDA=true,UV=Chr,fulls=fs)                                                                                                      : \
                                                    Assert(false, "prefilter must be between -1~5: "+string(prefilter))                                                                                             : \
                                 inputP


    # Default Auto-Prefilter - Luma expansion TV->PC (up to 16% more values for motion estimation)

    nw = round(w/2.0)
    nh = round(h/2.0)
    pref       = DefTV && tv || Str > 1.0 ? pref.ex_Luma_Rebuild(S0=Str,c=Amp,uv=Chr,tv_range=tv,fulls=fs)                        : \
                 DefTV && tv || Str > 0.0 ? pref.ex_retinex(tv_range=tv,lo=Str==1?40:(Str)*100,UV=Chr,fulls=fs)                   : \
                                            pref.ConditionalFilter(pref.ex_Luma_Rebuild(S0=1.0,uv=Chr,tv_range=tv,fulls=fs),        \
                                            pref, function[tv]() {propNumElements("_ColorRange") > 0 ? propGetInt("_ColorRange") == 1 : tv}, local=true)

    pref8      = bi > 8  ? pref.ConvertBits(8, dither=-1, fulls=fs)             : pref
    pref8      = UHDhalf ? pref8.BilinearResize(nw+nw%2, nh+nh%2, src_top=-0.5) : pref8  # todo: fix for MPEG1 to top_left (UHD default)


    If (sShow ? false : !Show) {

        # Subpixel 3

        pclip  = pelclip             ? pel==4 ?  pref8.nnedi3_rpow2(rfactor=4,nns=1,nsize=0,threads=threads/2,prefetch=threads,SetAffinity=true,MaxPhysCore=false) :  \
                                                 pref8.nnedi3_rpow2(rfactor=2,nns=1,nsize=0,threads=threads/2,prefetch=threads,SetAffinity=true,MaxPhysCore=false) : nop()
        pclip2 = pelclip && !GlobalR ? pel==4 ? inputP.nnedi3_rpow2(rfactor=4,nns=1,nsize=0,threads=threads/2,prefetch=threads,SetAffinity=true,MaxPhysCore=false) :  \
                                                inputP.nnedi3_rpow2(rfactor=2,nns=1,nsize=0,threads=threads/2,prefetch=threads,SetAffinity=true,MaxPhysCore=false) : nop()


        # Motion vectors search (mt=true requires avstp.dll in plugin path, otherwise ignored)

        super_search =                             pelclip ? MSuper(pref8,  pel=pel,               chroma=chroma, hpad=hpadU, vpad=vpadU,          pelclip=pclip,  rfilter=srfilter, mt=true) : \
                                                             MSuper(pref8,  pel=pel,sharp=subpixel,chroma=chroma, hpad=hpadU, vpad=vpadU                        ,  rfilter=srfilter, mt=true)
        super_render = !GlobalR ?                 (pelclip ? MSuper(inputP, pel=pel,               chroma=plane0, hpad=hpad,  vpad=vpad, levels=1, pelclip=pclip2                  , mt=true) : \
                                                             MSuper(inputP, pel=pel,sharp=subpixel,chroma=plane0, hpad=hpad,  vpad=vpad, levels=1                                  , mt=true)): super_search
        Recalculate  = !GlobalR && RefineMotion ? (pelclip ? MSuper(pref8,  pel=pel,               chroma=chroma, hpad=hpadU, vpad=vpadU,levels=1, pelclip=pclip                   , mt=true) : \
                                                             MSuper(pref8,  pel=pel,sharp=subpixel,chroma=chroma, hpad=hpadU, vpad=vpadU,levels=1                                  , mt=true)): nop()
            If (!isMult) {
                t2 = isInter ? tr > 1 ? tr*2 : tr : tr
                bv12 =   isInter && (tr > 5)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta =12,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv12) : nop()
                bv12 =   isInter && (tr > 5) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,bv12,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv12
                bv10 =   isInter && (tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta =10,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv10) : nop()
                bv10 =   isInter && (tr > 4) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,bv10,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv10
                bv8  =   isInter && (tr > 3)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 8,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv8)  : nop()
                bv8  =   isInter && (tr > 3) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv8,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv8
                bv6  =               t2 > 5                   ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 6,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv6)  : nop()
                bv6  =               t2 > 5  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv6,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv6
                bv5  =  !isInter ? ((tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 5,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv5)  : nop()) : nop()
                bv5  =  !isInter ? ((tr > 4  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv5,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv5)  : nop()
                bv4  =               t2 > 3                   ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 4,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv4)  : nop()
                bv4  =               t2 > 3  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv4,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv4
                bv3  =  !isInter ? ((tr > 2)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 3,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv3)  : nop()) : nop()
                bv3  =  !isInter ? ((tr > 2  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv3,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv3)  : nop()
                bv2  =  (isInter ||  tr > 1)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 2,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv2)  : nop()
                bv2  = ((isInter ||  tr > 1) && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv2,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv2
                bv1  =  !isInter ?                              (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 1,   overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv1)  : nop()
                bv1  =  !isInter ?            ( RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv1,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv1)  : nop()

                fv1  =  !isInter ?                              (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 1, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv1)  : nop()
                fv1  =  !isInter ?            ( RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv1,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv1)  : nop()
                fv2  =  (isInter ||  tr > 1)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 2, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv2)  : nop()
                fv2  = ((isInter ||  tr > 1) && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv2,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv2
                fv3  =  !isInter ? ((tr > 2)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 3, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv3)  : nop()) : nop()
                fv3  =  !isInter ? ((tr > 2  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv3,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv3)  : nop()
                fv4  =               t2 > 3                   ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 4, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv4)  : nop()
                fv4  =               t2 > 3  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv4,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv4
                fv5  =  !isInter ? ((tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 5, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv5)  : nop()) : nop()
                fv5  =  !isInter ? ((tr > 4  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv5,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv5)  : nop()
                fv6  =               t2 > 5                   ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 6, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv6)  : nop()
                fv6  =               t2 > 5  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv6,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv6
                fv8  =   isInter && (tr > 3)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 8, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv8)  : nop()
                fv8  =   isInter && (tr > 3) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv8,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv8
                fv10 =   isInter && (tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta =10, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv10) : nop()
                fv10 =   isInter && (tr > 4) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,fv10,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv10
                fv12 =   isInter && (tr > 5)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta =12, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam, pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv12) : nop()
                fv12 =   isInter && (tr > 5) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,fv12,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv12

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
                vmulti =                   !GlobalR ? super_search.MAnalyse( multi=true,overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma,truemotion=truemotion, divide=divide, delta = isInter ? tr2 : tr, dct=dct,searchparam=searchparam,pelsearch=pelsearch, temporal=TS, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : vmulti
                vmulti = RefineMotion   ? (!GlobalR ? MRecalculate (Recalculate, vmulti,overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma,truemotion=truemotion, divide=divide,    tr = isInter ? tr2 : tr, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                    vmulti) : vmulti
                vmulti =                   !GlobalR ? (isInter ? vmulti.SelectEvery (4, 2, 3) : vmulti) : vmulti.SelectRangeEvery (Rtr*2, tr2, 0, false)
                vmulti =                   !GlobalR && UHDhalf ? vmulti.MScaleVect()          : vmulti
                                 }


        if (!GlobalO) {

            if (md != "MDegrain") {

                for (i = 1, min(tr,7), 1) {

                       Eval(Format("b{i}c = !isMult ? mfilter.MCompensate(super_render, bv{i}, thSAD={thSAD}, thSCD1={thSCD1}, thSCD2={thSCD2}, mt=true) : nop()"))
                       Eval(Format("f{i}c = !isMult ? mfilter.MCompensate(super_render, fv{i}, thSAD={thSAD}, thSCD1={thSCD1}, thSCD2={thSCD2}, mt=true) : nop()"))
                !TS  ? Eval(Format("b{i}c = repair(b{i}c, mfilter, 3, plane==0?-1:3)")) : nop()
                !TS  ? Eval(Format("f{i}c = repair(f{i}c, mfilter, 3, plane==0?-1:3)")) : nop()

                }

                cmulti=  isMult ? mfilter.MCompensate(super_render, vmulti, thSAD=thSAD, thSCD1=thSCD1, thSCD2=thSCD2, mt=true, center=true, tr=tr) : nop()

                inter =  isMult ? cmulti
                \ :     (tr==6) ? interleave( f6c, f5c, f4c, f3c, f2c, f1c, mfilter, b1c, b2c, b3c, b4c, b5c, b6c )
                \ :     (tr==5) ? interleave(      f5c, f4c, f3c, f2c, f1c, mfilter, b1c, b2c, b3c, b4c, b5c      )
                \ :     (tr==4) ? interleave(           f4c, f3c, f2c, f1c, mfilter, b1c, b2c, b3c, b4c           )
                \ :     (tr==3) ? interleave(                f3c, f2c, f1c, mfilter, b1c, b2c, b3c                )
                \ :     (tr==2) ? interleave(                     f2c, f1c, mfilter, b1c, b2c                     )
                \ :               interleave(                          f1c, mfilter, b1c                          )


                output = TS ? inter.TemporalSoften(tr,limit,plane==0?0:limitc,15,2)                             : \
                              inter.ex_median(mode=md, recursion=false, Y=plane!=3?3:1, UV=plane!=0?3:1, fulls=fs)

                output = isMult ? output.selectevery(tr*2+1, tr) : output.SelectEvery((T5?2:TS?tr:1)*2+1,T5?2:TS?tr:1)

            } else {

            # Finally, MDegrain

            output  = isInter ?
            \                 ( isMult  ? mfilter.MDegrainN(super_render, vmulti, tr, thSAD2=halfthSAD, thSADC2=halfthSADC,               thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 6) ? mfilter.MDegrain6(super_render, bv2, fv2, bv4, fv4, bv6, fv6, bv8, fv8, bv10, fv10, bv12, fv12, thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 5) ? mfilter.MDegrain5(super_render, bv2, fv2, bv4, fv4, bv6, fv6, bv8, fv8, bv10, fv10,             thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 4) ? mfilter.MDegrain4(super_render, bv2, fv2, bv4, fv4, bv6, fv6, bv8, fv8,                         thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 3) ? mfilter.MDegrain3(super_render, bv2, fv2, bv4, fv4, bv6, fv6,                                   thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 2) ? mfilter.MDegrain2(super_render, bv2, fv2, bv4, fv4,                                             thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                             mfilter.MDegrain1(super_render, bv2, fv2,                                                       thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true)):
            \                 ( isMult  ? mfilter.MDegrainN(super_render, vmulti, tr, thSAD2=halfthSAD, thSADC2=halfthSADC,               thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 6) ? mfilter.MDegrain6(super_render, bv1, fv1, bv2, fv2, bv3, fv3, bv4, fv4, bv5, fv5, bv6, fv6,     thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 5) ? mfilter.MDegrain5(super_render, bv1, fv1, bv2, fv2, bv3, fv3, bv4, fv4, bv5, fv5,               thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 4) ? mfilter.MDegrain4(super_render, bv1, fv1, bv2, fv2, bv3, fv3, bv4, fv4,                         thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 3) ? mfilter.MDegrain3(super_render, bv1, fv1, bv2, fv2, bv3, fv3,                                   thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                 (tr == 2) ? mfilter.MDegrain2(super_render, bv1, fv1, bv2, fv2,                                             thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true) :
            \                             mfilter.MDegrain1(super_render, bv1, fv1,                                                       thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true))
        } }


        # Contrasharp (only sharpens luma)

        if (!GlobalO && isShrp) {

            isCntr && !SLimit ? Eval("
            global Super           = super_render
            global cb1             = !isMult ? (isInter ? bv2 : bv1) : vmulti.SelectEvery (tr2, 0)
            global cf1             = !isMult ? (isInter ? fv2 : fv1) : vmulti.SelectEvery (tr2, 1)") : nop()
                                Eval("
            CClip = (isCClip ?  ((isInter ? (InterPar ? CClip.AssumeTFF().SeparateFields() : CClip.AssumeBFF().SeparateFields()) : CClip)) : (inputP))")

        } else { nop() }


        # Globals Output

        GlobalO || Globals == 2  ? (!isMult ? Eval("
        global Super           = super_render
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



        # Output

        output = !GlobalO && isShrp ? isCntr ? ex_ContraSharpening(output, CClip, MC=!SLimit, HD=isHD, fulls=fs) : \
                                      SLimit ?  LSFmod(output,source=CClip,preset="slow",strength=Contrasharp,Smode=5,Lmode=0,LRad=isHD?2:1,edgemode=0,soothe=false,overshoot=0,soft=-2,keep=0,ss_x=1.25,ss_y=1.25,fulls=fs) : \
                                                LSFmod(output,             preset="slow",strength=Contrasharp,Smode=5,Lmode=6,LRad=isHD?2:1,edgemode=0,soothe=false,overshoot=0,soft=-2,keep=0,ss_x=1.25,ss_y=1.25,fulls=fs) : output

                 !GlobalO ? (isInter ? output.weave() : output) : input




    } ELSE {



    ##############
    # SHOW PANEL #
    ##############

      # Common Variables

        h     = h
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
        w2    = round(w1+w3)
        w3    = round(w1+(w3+Wadd2)*1.96)
        w3sq  = round(w3*1.01)

          # Panel Separator
        pref   = Str == 1 && !chroma ? CombinePlanes(pref, inputP, planes=rgb?"RGB":"YUV", pixel_type=PixelType(input)) : pref
        blkclp = BlankClip(isInter?assumeframebased(pref):pref,length=1,pixel_type=p_type,color=$161616)
                 \.crop(0,isInter?h/2%8:h%8,0,0,true).separatefields().assumeframebased().separatefields()

        Interleave(selecteven(blkclp).addborders(2,0,0,0,color=$7f7f7f).crop(0,0,-2,0,true),selectodd(blkclp))

        WOut=weave().assumefieldbased().weave()
        sep=(hi-height(WOut))/2

        StackHorizontal(pref,WOut.addborders(0,sep-sep%2,0,hi-(height(WOut)+(sep-sep%2)),color=$161616))


          # Color Guide Squares

        a=h*(isInter?0.37:0.74)       aa=h*(isInter?0.3835:0.767)
        b=h*(isInter?0.40:0.80)       bb=h*(isInter?0.4135:0.827)
        c=h*(isInter?0.43:0.86)       cc=h*(isInter?0.4435:0.887)

        ex_merge(Expr("127 scalef" ,"183 scalef" ,"47  scalef") ,ex_lutspa("absolute", Format("x {w3} >= x {w3sq} <= & y {a} >= y {aa} <= & & range_max 0 ?")).trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true, fulls=fs)
        ex_merge(Expr("81  scalef" ,"91  scalef" ,"240 scalef") ,ex_lutspa("absolute", Format("x {w3} >= x {w3sq} <= & y {b} >= y {bb} <= & & range_max 0 ?")).trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true, fulls=fs)
        ex_merge(Expr("210 scalef" ,"16  scalef" ,"146 scalef") ,ex_lutspa("absolute", Format("x {w3} >= x {w3sq} <= & y {c} >= y {cc} <= & & range_max 0 ?")).trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true, fulls=fs)


          # Parameters List

        blue   = sShow && (show=="Speed"  )
        red    = sShow && (show=="Memory" )
        yellow = sShow && (show=="Quality")

        Color  = sShow ? (blue   ? $00aef0 : \
                          red    ? $ff0000 : \
                          yellow ? $ffff00 : \
                          Assert(false,    "Revise typo for possible color guide modes: 'Speed','Memory','Quality'")) : nop()


        varn = "\n\n\n\n\n"
        sp   = !GlobalR && str==1.0 ? "  " : ""

        Subtitle("SMDegrain Mod v3.3.1",text_color=red||blue||yellow?Color:$7f7f7f,halo_color=$000000,font="VERDANA",size=s*2,x=w1,y=isInter?h/50:h/20)

        Subtitle("BASIC"   ,lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(            "\n\ntr           = " + string(tr)                                                                              + \
                 varn+varn+      "chroma       = " + string(chroma)                                                                          ,lsp=lsp,text_color=red||blue               ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(          "\n\n\nthSAD(C)     = " + string( GlobalO?"bypass":string(thSAD)     + "(" + string(plane0?thSADC:"bypass") + ")")+ \
                 varn+           "CClip        = " + string( GlobalO?"bypass":(Defined(CClip)?"defined":"Undefined"))                        + \
                             "\n\nInterlaced   = " + string(isInter)                                                                      ,lsp=lsp,text_color=                               $ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+           "RefineMotion = " + string( GlobalO?"bypass":RefineMotion)                                                  ,lsp=lsp,text_color=yellow                  ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+       "\n\nContrasharp  = " + string( GlobalO?"bypass":contrasharp)                                                   ,lsp=lsp,text_color=yellow&&!GlobalO        ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+varn+    "\nplane        = " + string( GlobalO?"bypass":(plane==0?"0 (Luma)":plane==1?"1 (U plane)":plane==2?"2 (V plane)":plane==3?"3 (Chroma)":"4(Luma+Chroma)")),lsp=lsp,text_color=(red||blue)&&!GlobalO?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle("<-- "+string(IsClip(prefilter)||prefilter!=-1?"Prefiltered clip converted\n    to PC levels":"Clip converted to PC levels\n   ")+" for the motion search",lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1-10,y=(isInter?h/2:h)-round(ys/1.5))

        Subtitle("ADVANCED",lsp=lsp,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)
        Subtitle(              "\n\npel        = " + string(pel)                                                                             ,lsp=lsp,text_color=red                     ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)
        Subtitle(            "\n\n\nsubpixel   = " + string( pel==1 ?"bypass":subpixel)                                                      ,lsp=lsp,text_color=(yellow||blue)&&pel!=1  ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)
        Subtitle(varn+varn+  "\n\n\ntruemotion = " + string( GlobalR?"bypass":truemotion)                                                    ,lsp=lsp,text_color=(yellow||blue)&&!GlobalR?Color:$7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)
        Subtitle(varn+             "mfilter    = " + string( GlobalR?"bypass":MFilterB?"Clip"+sp+" Variable":"OFF")                          ,lsp=lsp,text_color=                               $7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)
        Subtitle(varn+         "\n\nStr        = " + (GlobalR?string("bypass"):string(Str,"%1.2f"))+sp+" Brightness"                         + \
                 varn+             "search     = " + string( GlobalR?"bypass":search)                                                        ,lsp=lsp,text_color=yellow&&!GlobalR        ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)
        Subtitle(varn+varn+        "blksize    = " + string( GlobalR?"bypass":blksize)                                                       + \
                                 "\noverlap    = " + string( GlobalR?"bypass":overlap)                                                       ,lsp=lsp,text_color=(red||blue)&&!GlobalR   ?Color:$7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)
        Subtitle(varn+           "\nprefilter  = " + (GlobalR?string("bypass"):(preclip?"Clip"+sp+" Variable":(prefilter==0?"0"+sp+"    MinBlur(0)":prefilter==1?"1"+sp+"    MinBlur(1)":prefilter==2?"2"+sp+"    MinBlur(2)":prefilter==3?"3"+sp+"    Dfttest":prefilter==4?"4"+sp+"    KNLmeans":"OFF"+sp+"    (-1)"))) + \
                               "\n\nAmp        = " + (GlobalR||str==1.0?string("bypass"):string(Amp,"%1.2f"))+" Amplitude"                   + \
                 varn+           "\nlimit(C)   = " + (GlobalO?string("bypass"):string(limit)     + "(" + string(limitc) + ")")               ,lsp=lsp,text_color=                               $7f7f7f,font="COURIER NEW",size=s,x=w2,y=ys)

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
#     HELPER FUNCTIONS: For Prefilter                  #
#                                                      #
########################################################


########################################
## Didée's functions:
##
## MinBlur   by Didée (24-10-2006)
## Minimum Blur - Nifty Gauss/Median combination.
## (https://forum.doom9.org/showthread.php?p=1018488#post1018488)
##
## kgrabs: "Pixelwise median and blur admixture. If the differences are homologous to the input,
##          the weaker result of the two are taken, else the source pixel is passed"
##
## Optimized, updated and ported to ExTools by Dogway (25-08-2021)
## Output is different by default, medians have been replaced with edge retaining versions...
## and a following blur to mimic the old fat lines (needed?). Enable 'old' for old output.

function ex_MinBlur(clip clp, int "r", int "UV", string "mode", bool "sharp", bool "old", int "Y", bool "fulls") {

    rgb     = isrgb(clp)

    r       = Default(r,  1)
    UV      = Default(UV, 3)
    Y       = Default(Y,  3)
    mode    = Default(mode, "median")
    sh      = Default(sharp,   false)       # Recover edges (in old method) or remove blur (for new method)
    old     = Default(old,     false)       # Enable to use the old method with dumb medians
    fs      = Default(fulls,     rgb)       # AVS+ doesn't like Eval() with embedded functions -isrgb() in Default()-

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

    blurstr = mode == "median"          ? """ex_median(              "smart", UV=uv, fulls=fs)""" : \
              mode == "blur"            ? """ex_boxblur(r*2, r*2, "weighted", UV=uv)"""           : \
              mode == "blur_horizontal" ? """ex_boxblur(r*2,   0, "weighted", UV=uv)"""           : \
              mode == "blur_vertical"   ? """ex_boxblur(0,   r*2, "weighted", UV=uv)"""           : \
              mode

    rg12D = (r==0) ? ex_makediff(clp,clp.ex_sbr(Y=y,UV=uv,fulls=fs),Y=y,UV=uv,fulls=fs)                                            : \
            (r==1) ? ex_makediff(clp,clp.removegrain(rg12y,rg12),Y=y,UV=uv,fulls=fs)                                               : \
            (r==2) ? ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20),Y=Y,UV=UV,fulls=fs)                       : \
                     ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20).removegrain(rg20y,rg20),Y=y,UV=uv,fulls=fs)

    RG4D  =  old               ? (rg4v) ? clp.removegrain(rg4y,rg4)   : med ? clp.ex_median(r==2?"median5":"median7",UV=uv)  : Eval("clp."+blurstr+"") :\
                                 (rg4v) ? clp.removegrain(rg27y,rg27)                                                        : Eval("clp."+blurstr+"")
    RG4D  = !old && !sh && med ? (r<=1) ? RG4D.ex_boxblur(r==0?0.3:0.5,mode="weighted",UV=uv) : RG4D.removegrain(rg12y,rg12) : RG4D

    ex_lutxyz(rg12D,RG4D,clp,"x range_half - A@ z y - B@ * 0 < z A abs B abs < A B ? z swap - ? ",Y=y,UV=uv,fulls=fs)

    (!old && !med || old) && sh ? Repair(clp.removegrain(y!=3 ? 0 : 17,uv==3 ? 0 : -1),y!=3 ? 0 : 9, 0) : last }


## sbr()   by Didée (08-09-2009)
## Soft Blur Repair - Make a highpass on a blur's difference (well, kind of that)
## (https://forum.doom9.org/showthread.php?p=1323257#post1323257)
##
## kgrabs: "Takes a blur's difference and performs a blurring of the difference.
##          If both differences are homologous to the input, the weaker result is taken, else the source pixel is passed"
##
## Highpass of spatial r=1 Gaussian (like blur(1.0))

function ex_sbr(clip c, int "r", int "Y", int "UV", bool "fulls") {

    r      = Default(r,  1)
    Y      = Default(Y,  3)
    UV     = Default(UV, 3)
    fs     = Default(fulls,isrgb(c))
    Y31    = (Y==3)  ?  3 :  1
    UV31   = (UV==3) ?  3 :  1
    Y11    = (Y==3)  ? 12 : -1
    Y20    = (Y==3)  ? 20 : -1
    UV11   = (UV==3) ? 12 : -1
    UV20   = (UV==3) ? 20 : -1

    rg11   = (r<=1) ?     c.removegrain(Y11, UV11)                                             : \
             (r==2) ?     c.removegrain(Y11, UV11).removegrain(Y20, UV20)                      : \
                          c.removegrain(Y11, UV11).removegrain(Y20, UV20).removegrain(Y20, UV20)

    rg11D  = ex_makediff(c, rg11, UV=UV31, fulls=fs)

    RG11DS = (r<=1) ? rg11D.removegrain(Y11, UV11)                                             : \
             (r==2) ? rg11D.removegrain(Y11, UV11).removegrain(Y20, UV20)                      : \
                      rg11D.removegrain(Y11, UV11).removegrain(Y20, UV20).removegrain(Y20, UV20)

    ex_lutxyz(RG11D, RG11DS, c, "x y - A@ x range_half - B@ * 0 < z A abs B abs < z A - z x - range_half + ? ? ", Y=Y31, UV=UV31, fulls=fs)

    }


## Dither_Luma_Rebuild()  by cretindesalpes (02-01-2012)
## https://forum.doom9.org/showthread.php?p=1548318
## Converts luma (and chroma) to PC levels, and optionally allows tweaking for pumping up the darks. (for the clip to be fed to motion search only)

function ex_Luma_Rebuild (clip src, float "s0", float "c", int "Y", int "UV", bool "tv_range", bool "fulls") {

    rgb   = isrgb(src)

    Y     = Default(Y,       3)
    UV    = Default(UV,      3)
    s0    = Default(s0,    3.0)
    c     = Default(c,  1.0/16)
    tv    = Default(tv_range, !rgb)
    fs    = Default(fulls,     rgb)

    s0= max(s0,1.0)
    k = (s0 - 1) * c
    l = 1 - k
    d = 1 + c
    f = d * c
    t = tv ? "x ymin - 0 max ymax ymin - /" : "x range_max /"
    e = S0 > 1.0 ? Format("{k} {d} {f} "+t+" A@ {c} + / - * A {l} * + range_max *") : \
        tv       ?        "x ymin - 0 max range_max ymax ymin - / * "               : \
                          ""

    ec = tv ? "x cmin - range_max cmax cmin - / *" : ""

    ex_lut(src, e, rgb ? e : ec, Y=y, UV=uv, fulls=fs) }



## ex_retinex()   by Dogway (15-09-2021)
##
## Multi-Scale Retinex
## Optimized MSR for only Luma channel, akin to MSRCP but without going through RGB.
## Output is PC range. Performance is by default 50% of ex_Luma_Rebuild() although still fast and quality isn't comparable.
## lvl=2 uses auto-levels so performance drops to 25% of ex_Luma_Rebuild(), and some smooth flicker should arise.
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
##

function ex_retinex(clip clp, int "lvl", float "lo", float "hi", float "sigma", bool "tv_range", int "UV", bool "fulls") {

    rgb = isRGB(clp)
    bi  = BitsPerComponent(clp)

    lvl = Default(lvl,          1)         # 0: MSR output   1: Fixed levels output  2: auto-levels
    lo  = Default(lo, lvl==1?40:4)         # value in PC levels of low  level for normalization in lvl=1. For lvl=2 the divisor for the low level percentile (Reminder: crop black borders)
    hi  = Default(hi,   255-lo/3.)         # value in PC levels of high level for normalization in lvl=1.
    r   = Default(sigma,        1)         # from 1 to 5 roughly (leave it at 1 for the most time)
    tv  = Default(tv_range, !rgb)          # range of input clip
    UV  = Default(UV,        rgb ? 3 : 1)  # Set to 3 to convert Chroma to PC range
    fs  = Default(fulls,     rgb)

    w = max(clp.Width(),clp.Height())

    a = !rgb ? clp.ExtractY() : clp
    y = a.ConvertBits(8, dither=-1, fulls=fs)
    b = y.ex_GaussianBlur(w*0.015 * r,pad=false).ConvertBits(bi, fulls=fs)
    c = y.ex_GaussianBlur(w*0.05  * r,pad=false).ConvertBits(bi, fulls=fs)
    d = y.ScriptClip("ex_lut(y,string(rgb?y.AverageG():y.AverageLuma()),UV=rgb?3:1)",args="y,rgb").ConvertBits(bi, fulls=fs)

    rangePC =                        tv ? "ymin - ymax ymin - /" : "range_max /"
    str     = Format("x "+rangePC+" A@ log y 0.200001 * z 0.100001 * a 0.700001 * + + "+rangePC+" A * log / 1 swap - range_max *")
    cstr    = rgb ? str : UV == 3 && tv ? "x cmin - range_max cmax cmin - / *" : ""

    MSR     = ex_lutxyza(a,b,c,d, str, cstr, UV=uv, fulls=fs)


    if        (lvl==0) {

        MSR

    } else if (lvl==1) {

        MSR.ex_levels(lo, 1.0, hi, 0, 255,false,rgb?3:1,fs)

    } else {

        RR  = MSR.ConvertBits(8, dither=-1, fulls=fs).RatioResize(0.20,"%",kernel="Bilinear")

        b2  = RR.selectevery(1,-2)
        b   = RR.selectevery(1,-1)
        f   = RR.selectevery(1,+1)
        f2  = RR.selectevery(1,+2)

        TS  = Expr(RR,b2,b,f,f2,"x y z a b + + + + 0.200001 *")

        b2  = TS.selectevery(1,-2)
        b   = TS.selectevery(1,-1)
        f   = TS.selectevery(1,+1)
        f2  = TS.selectevery(1,+2)

        TS  = Expr(TS,b2,b,f,f2,"x y z a b + + + + 0.200001 *")

        ScriptClip(MSR,"

        pmin = rgb ? TS.GPlaneMin(1./lo) : \
                     TS.YPlaneMin(1./lo)

        pmax = rgb ? TS.GPlaneMax(0)     : \
                     TS.YPlaneMax(0)

        pmin > 0 || pmax < 255 ? MSR.ex_levels(pmin,1.0,pmax,0,255,false,rgb?3:1,fs) : MSR",args="MSR,TS,rgb,fs,lo",local=true)
    }

    UV == 3 ? CombinePlanes(last, clp, planes=rgb?"RGB":"YUV", pixel_type=PixelType(clp)) : last }



# Wrapper for BM3D CUDA by WolframRhodium for AviSynth+
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

function ex_BM3D(clip a, float "sigma", int "radius", bool "CUDA", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    s  = Default(sigma,    3)
    r  = Default(radius,   1)
    cd = Default(CUDA,  true)
    UV = Default(UV,    rgb ? 3 : 1)
    fs = Default(fulls, rgb)

    ch = !(isy || UV!=3)
    ch ? ConverttoYUV444(a,chromaresample="spline16") : a
    ConvertBits(bits=32, fulls=fs)

    cd ? BM3D_CUDA(sigma=[s,ch?s/2:0,ch?s/2:0], radius=r, chroma=ch, fast=true, extractor_exp=6) : \
         BM3D_CPU (sigma=[s,ch?s/2:0,ch?s/2:0], radius=r, chroma=ch)
         BM3D_VAggregate(radius=r)

    if (bi < 32) {
        ConvertBits(bits=16, dither=-1, fulls=fs)
        ConvertBits(bits=bi, dither= 1, fulls=fs)
    }
    ch ? MatchColorFormat(a) : mergechroma(a) }



## ex_KNLMeansCL() - KNLMeansCL wrapper by Dogway (15-09-2021)
##

function ex_KNLMeansCL (clip c, String "device_type", int "device_id", bool "chroma", float "h", int "d", int "a", String "knlm_params", clip "rclip") {

    d            = Default( d, 0)
    a            = Default( a, 1)
    h            = Default( h, 7.0)
    deviceid     = Default( device_id, 0)
    chroma       = Default( chroma , true)
    knlm_params  = Defined( knlm_params) ? ","+knlm_params : ""

    w       = c.width()
    isy     = c.isy()
    rgb     = c.isrgb()
    fullchr = c.is444()
    chr420  = c.is420()

    stacked = chroma && !fullchr && !isy
    UV      = stacked ? "Y" : rgb ? "auto" : !isy && chroma ? "YUV" : "Y"
    dwclip  = Defined( rclip )
    wclip   = dwclip ? rclip : Undefined()

    # Beware chroma placement, revise
    If (stacked && !rgb) {

        Uclip   =          ExtractU(c)
        Uwclip  = dwclip ? ExtractU(wclip) : nop()
        Vclip   =          ExtractV(c)
        Vwclip  = dwclip ? ExtractV(wclip) : nop()
        UVstack = chr420 ? StackVertical  (Uclip, Vclip) : \
                           StackHorizontal(Uclip, Vclip) # otherwise 422 horizontal stack
        UVwstack= dwclip ? (chr420 ? StackVertical  (Uwclip, Vwclip)  : \
                                     StackHorizontal(Uwclip, Vwclip)) : nop()

        nlc     =          StackHorizontal(ExtractY(c),    UVstack )
        nlrc    = dwclip ? StackHorizontal(ExtractY(wclip),UVwstack) : Undefined()

        nlc     = Eval("nlc.KNLMeansCL(D=d, A=a, h=h, device_type=device_type, device_id=deviceid, rclip=nlrc, channels=UV" + knlm_params + ")")

        uvw     = Uclip.width ()
        uvh     = Uclip.height()

        nly     =          nlc.crop(0,0,chr420 ? -uvw : -(uvw+uvw),0, true)

        nlu     = chr420 ? nlc.crop(w,0,0,-uvh,  true) : \
                           nlc.crop(w,0,-uvw,0,  true)
        nlv     = chr420 ? nlc.crop(w,uvh,   0,0,true) : \
                           nlc.crop(w+uvw,0,0,0 ,true)

                  CombinePlanes(nly, nlu, nlv, planes="YUV", pixel_type=PixelType(c))

        } else {

                  Eval("  c.KNLMeansCL(D=d, A=a, h=h, device_type=device_type, device_id=deviceid, rclip=wclip, channels=UV" + knlm_params + ")")

        } }
