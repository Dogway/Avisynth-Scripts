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
###                       v3.2.5d      by Dogway - 24 Augu 2021                              ###
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


function SMDegrain (clip input   , int "tr"      , int "thSAD"    , int  "thSADC" , bool "RefineMotion",  val  "contrasharp", clip  "CClip"     , bool "interlaced" , int   "plane" , int   "Globals"  , bool   "tv_range",               \
                     int "pel"   , int "subpixel", val "prefilter", clip "mfilter", int  "blksize"     , int   "overlap"    , int   "search"    , bool "truemotion" , float "limit" , float "limitc"   , int "thSCD1"   , int "thSCD2",   \
                    bool "chroma", int "hpad"    , int "vpad"     , val  "Show"   , float "Str"        , float "Amp"        , int   "dct"       , int "searchparam", int "pelsearch",                                                     \
                  int "device_id", bool "trymany", int "divide"   , int "srfilter", int "threads", bool "UHDhalf", bool "fulls") {

    rgb  = isRGB(input)
    bi   = BitsPerComponent(input)

    tr           = Default( tr,       2 )
    thSAD        = Default( thSAD,  300 )
    thSAD2=thSAD/2
    thSADC       = Default( thSADC, thSAD2)
    RefineMotion = Default( RefineMotion, false)
    Threads      = Default( Threads, sh_GetUserGlobalIMTint(true))

    trymany      = Default(trymany, false)

    Globals      = Default( Globals,  0 )
    GlobalR = Globals == 1
    GlobalO = Globals == 3
    isCClip = Defined(CClip)

    Contrasharp  = Default( Contrasharp, !GlobalO && isCClip)
    Interlaced   = Default( Interlaced,  false)

    w       = input.width ()
    h       = input.height()
    sShow   = IsString(show)
    preclip = IsClip(prefilter)
    p_type  = input.PixelType()

    UHDhalf = Default( UHDhalf,  true)
    isCntr  = IsBool(Contrasharp)
    isLSFm  = !isCntr ? (Contrasharp > 0.0) : Contrasharp
    isMult  = tr > 6     # MDegrainN is slower, so avoid >6 at possible
    isHD    = (w > 1099 ||  h > 599)
    isUHD   = (w > 2599 ||  h > 1499) && !UHDhalf
    tv      = Default(tv_range, !rgb)
    fs      = Default(fulls,     rgb)
    isInter = interlaced ? GetParity(input) : nop()

    scaleCSAD = is420(input)   ? isHD ? 1 :  0 : \
                is444(input)   ? isHD ? 1 :  1 : \
                isYV411(input) ? isHD ? 0 : -1 : \
                                 isHD ? 1 : 0

    pel          = Default( pel,      isHD ? 1 : 2 )
    subpixel     = Default( subpixel, pel)
    srfilter     = Default( srfilter, 4)
    prefilter    = Default( prefilter, -1 )
    MFilterB     = Defined( mfilter )
    pelclip      = pel>1 && subpixel == 3
    Str          = Default( Str, 3.0 )
    Amp          = Default( Amp, 0.0625 )

    blksize      = Default( blksize,  isHD ? 16 : 8 )
    blk2=blksize/2
    overlap      = Default( overlap,  blk2 )
    ovl2=overlap/2
    search       = Default( search,   4 )
    searchparam  = Default( searchparam,   isUHD ? 1 : 2 )
    pelsearch    = Default( pelsearch,   14 )
    truemotion   = Default( truemotion, !isHD)
    DCT          = Default( DCT,   0 )
    thSCD1       = Default( thSCD1,  round(pow((blksize*2.5),2)))
    thSCD2       = Default( thSCD2,  130 )


    plane        = Default( plane,    4 )
    chroma       = Default( chroma, true)
    Chr          = chroma ? 3 : 1
    plane0       = plane!=0
    U            = plane0 && plane!=2 ? 3 : 2
    V            = plane0 && plane!=1 ? 3 : 2


    hpad         = Default( hpad, isHD ? 0   : blksize)
    hpadU        = isUHD ? hpad/2+(hpad/2)%2 : hpad
    vpad         = Default( vpad, isHD ? 0   : hpad)
    vpadU        = isUHD ? vpad/2+(vpad/2)%2 : vpad
    limit        = Default( limit,  isUHD ? 2 : 255 )  # auto-scaled
    limitc       = Default( limitc, limit)

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
    interlaced      ? Assert(h%4==0,                       "Interlaced sources require mod 4 height sizes")             : nop()
    RefineMotion    ? Assert(blksize > 7,                  "For RefineMotion you need a blksize of at least 8")         : nop()



    # RefineMotion Variables

    halfblksize  = RefineMotion ?  blk2                                  : nop() # MRecalculate works with half block size
    halfoverlap  = RefineMotion ? (overlap == 2 ? overlap : ovl2+ovl2%2) : nop() # Halve the overlap to suit the halved block size
    halfthSAD    = RefineMotion || isMult ? thSAD2                       : nop() # MRecalculate uses a more strict thSAD, which defaults to 150 (half of function's default of 300)
    halfthSADC   =                 isMult ? thSADC/2                     : nop() # For MDegrainN()




    # Input preparation for: Interlacing and MSuper optimization when pel=2

    inputP  = !interlaced ? (pel == 2         ? input.AssumeFrameBased()             : input)                             : \
                            (GetParity(input) ? input.AssumeTFF().SeparateFields()   : input.AssumeBFF().SeparateFields())

    # Prefilter & Motion Filter

    Mfilter = MFilterB ? MFilter : inputP
    Lthres  = ex_bs(75, 8, bi, fulls=fs)

    pref   = !GlobalR ? preclip ? prefilter                                                                               : \
                                 (prefilter==-1) ?  inputP                                                                : \
                                 (prefilter== 0) ?  inputP.ex_MinBlur(0,Chr,fulls=fs)                                     : \
                                 (prefilter== 1) ?  inputP.ex_MinBlur(1,Chr,fulls=fs)                                     : \
                                 (prefilter== 2) ?  inputP.ex_MinBlur(2,Chr,fulls=fs)                                     : \
                                 (prefilter== 3) ?  ex_merge(dfttest(inputP,sstring="0.0:4.0 0.2:9.0 1.0:15.0",tbsize=1,U=chroma,V=chroma,dither=1,threads=1),inputP,                                                 \
                                                    inputP.ex_lut(Format("x ymin < range_max x {Lthres} > 0 range_max x ymin - range_max {Lthres} ymin - / * - ? ?"),UV=1,fulls=fs), luma=chroma, UV=chr, fulls=fs) : \
                                 (prefilter== 4) ?  inputP.ex_KNLMeansCL(device_type="GPU", device_id=device_id, chroma=chroma, a=1,d=1,h=7.0)                                                                      : \
                                 (prefilter== 5) ?  inputP.ex_BM3D(sigma=5,radius=1,UV=Chr)                                                                                                                         : \
                                                    Assert(false, "prefilter must be between -1~5: "+string(prefilter))                                                                                             : \
                                 inputP


    # Default Auto-Prefilter - Luma expansion TV->PC (up to 16% more values for motion estimation)

    nw = round(w/2.0)
    nh = round(h/2.0)
    pref       = pref.ex_Luma_Rebuild(S0=Str,c=Amp,uv=Chr,tv_range=tv,fulls=fs)
    pref8      = bi > 8  ? pref.ConvertBits(8,dither=-1, fulls=fs)              : pref
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
                t2 = interlaced ? tr > 1 ? tr*2 : tr : tr
                bv12 =   interlaced && (tr > 5)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta =12,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv12) : nop()
                bv12 =   interlaced && (tr > 5) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,bv12,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv12
                bv10 =   interlaced && (tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta =10,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv10) : nop()
                bv10 =   interlaced && (tr > 4) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,bv10,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv10
                bv8  =   interlaced && (tr > 3)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 8,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv8)  : nop()
                bv8  =   interlaced && (tr > 3) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv8,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv8
                bv6  =                  t2 > 5                   ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 6,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv6)  : nop()
                bv6  =                  t2 > 5  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv6,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv6
                bv5  =  !interlaced ? ((tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 5,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv5)  : nop()) : nop()
                bv5  =  !interlaced ? ((tr > 4  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv5,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv5)  : nop()
                bv4  =                  t2 > 3                   ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 4,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv4)  : nop()
                bv4  =                  t2 > 3  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv4,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv4
                bv3  =  !interlaced ? ((tr > 2)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 3,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv3)  : nop()) : nop()
                bv3  =  !interlaced ? ((tr > 2  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv3,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv3)  : nop()
                bv2  =  (interlaced ||  tr > 1)                  ? (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 2,  overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv2)  : nop()
                bv2  = ((interlaced ||  tr > 1) && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, bv2,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv2
                bv1  =  !interlaced ?                              (!GlobalR  ? super_search.MAnalyse(isb = true, delta = 1,   overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : bv1)  : nop()
                bv1  =  !interlaced ?            ( RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, bv1,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              bv1)  : nop()

                fv1  =  !interlaced ?                              (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 1, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv1)  : nop()
                fv1  =  !interlaced ?            ( RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv1,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv1)  : nop()
                fv2  =  (interlaced ||  tr > 1)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 2, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv2)  : nop()
                fv2  = ((interlaced ||  tr > 1) && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv2,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv2
                fv3  =  !interlaced ? ((tr > 2)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 3, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv3)  : nop()) : nop()
                fv3  =  !interlaced ? ((tr > 2  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv3,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv3)  : nop()
                fv4  =                  t2 > 3                   ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 4, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv4)  : nop()
                fv4  =                  t2 > 3  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv4,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv4
                fv5  =  !interlaced ? ((tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 5, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv5)  : nop()) : nop()
                fv5  =  !interlaced ? ((tr > 4  && RefineMotion &&  !GlobalR) ?   MRecalculate           (Recalculate, fv5,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv5)  : nop()
                fv6  =                  t2 > 5                   ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 6, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv6)  : nop()
                fv6  =                  t2 > 5  && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv6,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv6
                fv8  =   interlaced && (tr > 3)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta = 8, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv8)  : nop()
                fv8  =   interlaced && (tr > 3) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate, fv8,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv8
                fv10 =   interlaced && (tr > 4)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta =10, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv10) : nop()
                fv10 =   interlaced && (tr > 4) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,fv10,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv10
                fv12 =   interlaced && (tr > 5)                  ? (!GlobalR  ? super_search.MAnalyse(isb = false, delta =12, overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : fv12) : nop()
                fv12 =   interlaced && (tr > 5) && RefineMotion &&  !GlobalR  ?   MRecalculate           (Recalculate,fv12,   overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma, truemotion=truemotion, divide=divide, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                              fv12

                # Scaling vectors for UHD

                if (UHDhalf) {

                bv1  = !interlaced             ? !GlobalR ?  bv1.MScaleVect() :  bv1 : nop()             fv1  = !interlaced             ? !GlobalR ?  fv1.MScaleVect() :  fv1 : nop()
                bv2  = (interlaced ||  tr > 1) ? !GlobalR ?  bv2.MScaleVect() :  bv2 : nop()             fv2  = (interlaced ||  tr > 1) ? !GlobalR ?  fv2.MScaleVect() :  fv2 : nop()
                bv3  = !interlaced && (tr > 2) ? !GlobalR ?  bv3.MScaleVect() :  bv3 : nop()             fv3  = !interlaced && (tr > 2) ? !GlobalR ?  fv3.MScaleVect() :  fv3 : nop()
                bv4  =                 t2 > 3  ? !GlobalR ?  bv4.MScaleVect() :  bv4 : nop()             fv4  =                 t2 > 3  ? !GlobalR ?  fv4.MScaleVect() :  fv4 : nop()
                bv5  = !interlaced && (tr > 4) ? !GlobalR ?  bv5.MScaleVect() :  bv5 : nop()             fv5  = !interlaced && (tr > 4) ? !GlobalR ?  fv5.MScaleVect() :  fv5 : nop()
                bv6  =                 t2 > 5  ? !GlobalR ?  bv6.MScaleVect() :  bv6 : nop()             fv6  =                 t2 > 5  ? !GlobalR ?  fv6.MScaleVect() :  fv6 : nop()
                bv8  =  interlaced && (tr > 3) ? !GlobalR ?  bv8.MScaleVect() :  bv8 : nop()             fv8  =  interlaced && (tr > 3) ? !GlobalR ?  fv8.MScaleVect() :  fv8 : nop()
                bv10 =  interlaced && (tr > 4) ? !GlobalR ? bv10.MScaleVect() : bv10 : nop()             fv10 =  interlaced && (tr > 4) ? !GlobalR ? fv10.MScaleVect() : fv10 : nop()
                bv12 =  interlaced && (tr > 5) ? !GlobalR ? bv12.MScaleVect() : bv12 : nop()             fv12 =  interlaced && (tr > 5) ? !GlobalR ? fv12.MScaleVect() : fv12 : nop()

                            }

                          } else {

                tr2    = tr*2
                vmulti =                   !GlobalR ? super_search.MAnalyse( multi=true,overlap=    overlap,blksize=    blksize,   search=search,chroma=chroma,truemotion=truemotion, divide=divide, delta = interlaced ? tr2 : tr, dct=dct,searchparam=searchparam,pelsearch=pelsearch, trymany=trymany, scaleCSAD=scaleCSAD, mt=true) : vmulti
                vmulti = RefineMotion   ? (!GlobalR ? MRecalculate (Recalculate, vmulti,overlap=halfoverlap,blksize=halfblksize, thSAD=halfthSAD,chroma=chroma,truemotion=truemotion, divide=divide,    tr = interlaced ? tr2 : tr, dct=dct, scaleCSAD=scaleCSAD, mt=true) :                                                    vmulti) : vmulti
                vmulti =                   !GlobalR ? (interlaced ? vmulti.SelectEvery (4, 2, 3) : vmulti) : vmulti.SelectRangeEvery (Rtr*2, tr2, 0, false)
                vmulti =                   !GlobalR && UHDhalf    ? vmulti.MScaleVect()          : vmulti
                                 }



        # Finally, MDegrain

        output  = !GlobalO ? interlaced ?
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
         \                             mfilter.MDegrain1(super_render, bv1, fv1,                                                       thSAD=thSAD, thSADC=thSADC, thSCD1=thSCD1, thSCD2=thSCD2, limit=limit, limitc=limitc, plane=plane, mt=true)):    nop()



        # Contrasharp (only sharpens luma)

        isCntr && isLSFm && isHD ? Eval("
        global Super    = super_render
        global cb1      = !isMult ? (interlaced ? bv2 : bv1) : vmulti.SelectEvery (tr2, 0)
        global cf1      = !isMult ? (interlaced ? fv2 : fv1) : vmulti.SelectEvery (tr2, 1)") : nop()

        !GlobalO && isLSFm       ? Eval("
        CClip = (isCClip ?  ((interlaced ? (isInter ? CClip.AssumeTFF().SeparateFields() : CClip.AssumeBFF().SeparateFields()) : CClip)) : (input))") : nop()


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
        global bv1             =                                             vmulti.SelectEvery (tr2,  0)
        global bv2             = interlaced ? bv1                          : vmulti.SelectEvery (tr2,  2)
        global bv3             =                                             vmulti.SelectEvery (tr2,  4)
        global bv4             = interlaced ? vmulti.SelectEvery (tr2,  2) : vmulti.SelectEvery (tr2,  6)
        global bv5             =                                             vmulti.SelectEvery (tr2,  8)
        global bv6             = interlaced ? bv3                          : vmulti.SelectEvery (tr2, 10)
        global bv8             = interlaced ? vmulti.SelectEvery (tr2,  6) : nop()
        global bv10            = interlaced ? bv5                          : nop()
        global bv12            = interlaced ? vmulti.SelectEvery (tr2, 10) : nop()

        global fv1             =                                             vmulti.SelectEvery (tr2,  1)
        global fv2             = interlaced ? fv1                          : vmulti.SelectEvery (tr2,  3)
        global fv3             =                                             vmulti.SelectEvery (tr2,  5)
        global fv4             = interlaced ? vmulti.SelectEvery (tr2,  3) : vmulti.SelectEvery (tr2,  7)
        global fv5             =                                             vmulti.SelectEvery (tr2,  9)
        global fv6             = interlaced ? fv3                          : vmulti.SelectEvery (tr2, 11)
        global fv8             = interlaced ? vmulti.SelectEvery (tr2,  7) : nop()
        global fv10            = interlaced ? fv5                          : nop()
        global fv12            = interlaced ? vmulti.SelectEvery (tr2, 11) : nop()
        global Super           = super_render
        global vmulti          = vmulti
        global Rtr             = tr
        ")) : nop()



        # Output

        output = !GlobalO && isLSFm ? isCntr ? ex_ContraSharpening(output, CClip, HD=isHD, fulls=fs) : \
                                               LSFmod(output,source=CClip,preset="slow",strength=Contrasharp,soothe=false,Lmode=0,soft=-2,keep=0,ss_x=1.5,ss_y=1.5,fulls=fs) : output

                 !GlobalO ? (interlaced ? output.weave() : output) : input




    } ELSE {



    ##############
    # SHOW PANEL #
    ##############

      # Common Variables

        h     = h
        w2    = float(w)
        h2    = float(h)
        hi    = interlaced ? round(h/2.0) : h
        AR    = w2/h2
        lsp   = interlaced?15:30
        lsp   = AR < 1.9 ? lsp : floor(AR < 1.9 ? lsp : ((AR>2.4) ? 0 : lsp-((AR-1.9)*(lsp/(2.4-1.9)))))
        ys    = round(interlaced?h2/15:h2/6)
        s     = floor(((interlaced?w2/1.6:w2)/720.0)*16.0)

        Wadd  = w2/40
        Wadd2 = Wadd/2
        w1    = round(w2+Wadd+Wadd2)
        w3    = (w2/3)+Wadd/2.1
        w2    = round(w1+w3)
        w3    = round(w1+(w3+Wadd2)*1.96)
        w3sq  = round(w3*1.01)

          # Panel Separator

        blkclp = BlankClip(interlaced?assumeframebased(pref):pref,length=1,pixel_type=p_type,color=$161616)
                 \.crop(0,interlaced?h/2%8:h%8,0,0,true).separatefields().assumeframebased().separatefields()

        Interleave(selecteven(blkclp).addborders(2,0,0,0,color=$7f7f7f).crop(0,0,-2,0,true),selectodd(blkclp))

        WOut=weave().assumefieldbased().weave()
        sep=(hi-height(WOut))/2

        StackHorizontal(pref,WOut.addborders(0,sep-sep%2,0,hi-(height(WOut)+(sep-sep%2)),color=$161616))


          # Color Guide Squares

        a=h*(interlaced?0.37:0.74)       aa=h*(interlaced?0.3835:0.767)
        b=h*(interlaced?0.40:0.80)       bb=h*(interlaced?0.4135:0.827)
        c=h*(interlaced?0.43:0.86)       cc=h*(interlaced?0.4435:0.887)

        ex_merge(Expr("127 scalef" ,"183 scalef" ,"47  scalef") ,ex_lutspa("absolute", Format("x {w3} >= x {w3sq} <= & y {a} >= y {aa} <= & & range_max 0 ?")).trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true, fulls=fs)
        ex_merge(Expr("81  scalef" ,"91  scalef" ,"240 scalef") ,ex_lutspa("absolute", Format("x {w3} >= x {w3sq} <= & y {b} >= y {bb} <= & & range_max 0 ?")).trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true, fulls=fs)
        ex_merge(Expr("210 scalef" ,"16  scalef" ,"146 scalef") ,ex_lutspa("absolute", Format("x {w3} >= x {w3sq} <= & y {c} >= y {cc} <= & & range_max 0 ?")).trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true, fulls=fs)


          # Parameters List

        blue   = sShow ? (show=="Speed"   ? true : false) : false
        red    = sShow ? (show=="Memory"  ? true : false) : false
        yellow = sShow ? (show=="Quality" ? true : false) : false

        Color  = sShow ? (blue   ? $00aef0 : \
                          red    ? $ff0000 : \
                          yellow ? $ffff00 : \
                          Assert(false,    "Revise typo for possible color guide modes: 'Speed','Memory','Quality'")) : nop()


        varn = "\n\n\n\n\n"
        sp   = !GlobalR && str==1.0 ? "  " : ""

        Subtitle("SMDegrain Mod v3.2.3",text_color=red||blue||yellow?Color:$7f7f7f,halo_color=$000000,font="VERDANA",size=s*2,x=w1,y=interlaced?h/50:h/20)

        Subtitle("BASIC"   ,lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(            "\n\ntr           = " + string(tr)                                                                              + \
                 varn+varn+      "chroma       = " + string(chroma)                                                                          ,lsp=lsp,text_color=red||blue               ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(          "\n\n\nthSAD(C)     = " + string( GlobalO?"bypass":string(thSAD)     + "(" + string(plane0?thSADC:"bypass") + ")")+ \
                 varn+           "CClip        = " + string( GlobalO?"bypass":(Defined(CClip)?"defined":"Undefined"))                        + \
                             "\n\nInterlaced   = " + string(interlaced)                                                                      ,lsp=lsp,text_color=                               $ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+           "RefineMotion = " + string( GlobalO?"bypass":RefineMotion)                                                  ,lsp=lsp,text_color=yellow                  ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+       "\n\nContrasharp  = " + string( GlobalO?"bypass":contrasharp)                                                   ,lsp=lsp,text_color=yellow&&!GlobalO        ?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle(varn+varn+    "\nplane        = " + string( GlobalO?"bypass":(plane==0?"0 (Luma)":plane==1?"1 (U plane)":plane==2?"2 (V plane)":plane==3?"3 (Chroma)":"4(Luma+Chroma)")),lsp=lsp,text_color=(red||blue)&&!GlobalO?Color:$ffffff,font="COURIER NEW",size=s,x=w1,y=ys)
        Subtitle("<-- "+string(IsClip(prefilter)||prefilter!=-1?"Prefiltered clip converted\n    to PC levels":"Clip converted to PC levels\n   ")+" for the motion search",lsp=lsp,text_color=$ffffff,font="COURIER NEW",size=s,x=w1-10,y=(interlaced?h/2:h)-round(ys/1.5))

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

        Subtitle("   Speed"   ,lsp=interlaced?15:30,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(a-1))
        Subtitle("   Memory"  ,lsp=interlaced?17:34,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(b-1))
        Subtitle("   Quality" ,lsp=interlaced?19:38,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(c-1))
        } }





########################################################
#                                                      #
# HELPER FUNCTIONS: For Contrasharp and Prefilter      #
#                                                      #
########################################################


########################################
## Didée's functions:
##
## MinBlur   by Didée (24-10-2006)
## Nifty Gauss/Median combination, reminds a little of a bilateral filter.
## (https://forum.doom9.org/showthread.php?p=1018488#post1018488)
##
## Optimized, updated and ported to ExTools by Dogway (22-08-2021)
## Output is different by default, medians have been replaced with edge retaining versions...
## and a following blur to mimic the old fat lines (needed?). Enable 'old' for old output.

function ex_MinBlur(clip clp, int "r", int "UV", bool "planar", string "mode", bool "sharp", bool "old", int "Y", bool "fulls") {

    r       = Default(r,  1)
    UV      = Default(UV, 3)
    Y       = Default(Y,  3)
    defmod  = Defined(mode)
    mode    = Default(mode, "median")
    sh      = Default(sharp,   false)   # recover edges (in old method) or remove blur (for new method)
    old     = Default(old,     false)   # Enable to use the old method with dumb medians
    fs      = Default(fulls,   false)

    ch    =  uv==1
    uv2   = (uv==2) ? 1 : uv
    ch2   =  uv2==1
    y2    = (y ==2) ? 1  : y
    rg4   = (uv==3) ? 4  : -1
    rg12  = (uv==3) ? 12 : -1
    rg20  = (uv==3) ? 20 : -1
    rg4v  = (uv==3) ? 4  : -1
    rg12v = (uv==3) ? 12 : -1
    rg20v = (uv==3) ? 20 : -1
    rg4y  = (y ==3) ? 4  : -1
    rg12y = (y ==3) ? 12 : -1
    rg20y = (y ==3) ? 20 : -1
    rg4v  = !(defmod && r==1) && (r<=1)

    blurstr = mode == "median"          ? """ex_median(mode=r==1 ? "edgeCL" : "EMF2",UV=uv)""" : \
              mode == "blur"            ? """ex_boxblur(r*2, r*2, "weighted",        UV=uv)""" : \
              mode == "blur_horizontal" ? """ex_boxblur(r*2,   0, "weighted",        UV=uv)""" : \
              mode == "blur_vertical"   ? """ex_boxblur(0,   r*2, "weighted",        UV=uv)""" : \
              mode

    rg12D = (r==0) ? ex_makediff(clp,clp.ex_sbr(Y=y2,UV=uv2,fulls=fs),Y=y2,UV=uv2,fulls=fs)                                                 : \
            (r==1) ? ex_makediff(clp,clp.removegrain(rg12y,rg12),Y=y2,UV=uv2,fulls=fs)                                                      : \
            (r==2) ? ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20),Y=y2,UV=uv2,fulls=fs)                              : \
                     ex_makediff(clp,clp.removegrain(rg12y,rg12).removegrain(rg20y,rg20).removegrain(rg20y,rg20),Y=y2,UV=uv2,fulls=fs)

    RG4D  =  old        ? (rg4v) ? clp.removegrain(rg4y,rg4)                           : clp.ex_median(mode=r==2?"median5":"median7",UV=uv) : \
                          (rg4v) ? clp.removegrain(27,rg4)                             : Eval("clp."+blurstr+"")
    RG4D  = !old && !sh ? (rg4v) ? RG4D.ex_boxblur(r==0?0.3:0.5,mode="weighted",UV=uv) : RG4D.removegrain(rg12y,rg12) : RG4D

    ex_lutxyz(rg12D,RG4D,clp,"x range_half - A@ z y - 0 range_half - max B@ * 0 < range_half A abs B abs < x B range_half + ? ? z swap - range_half +",y=y2,UV=uv2,fulls=fs)

    old && sh ? Repair(clp.removegrain(y!=3 ? 0 : 17,uv==3 ? 0 : -1),y!=3 ? 0 : 9,uv==3 ? 0 : -1) : last }


## sbr()   by Didée (08-09-2009)
## Make a highpass on a blur's difference (well, kind of that)
## Highpass of spatial r=1 Gaussian (like blur(1.0)) (https://forum.doom9.org/showthread.php?p=1323257#post1323257)

function ex_sbr(clip c, int "r", int "Y", int "UV", bool "fulls") {

    r      = Default(r,  1)
    Y      = Default(Y,  3)
    UV     = Default(UV, 3)
    fs     = Default(fulls, false)
    Y31    = (Y==3)  ?  3 :  1
    UV31   = (UV==3) ?  3 :  1
    Y11    = (Y==3)  ? 12 : -1
    Y20    = (Y==3)  ? 20 : -1
    UV11   = (UV==3) ? 12 : -1
    UV20   = (UV==3) ? 20 : -1

    rg11   = (r<=1) ?     c.removegrain(Y11, UV11)                                                   : \
             (r==2) ?     c.removegrain(Y11, UV11).removegrain(Y20, UV20)                            : \
                          c.removegrain(Y11, UV11).removegrain(Y20, UV20).removegrain(Y20, UV20)

    rg11D  = ex_makediff(c, rg11, UV=UV31, fulls=fs)

    RG11DS = (r<=1) ? rg11D.removegrain(Y11, UV11)                                                   : \
             (r==2) ? rg11D.removegrain(Y11, UV11).removegrain(Y20, UV20)                            : \
                      rg11D.removegrain(Y11, UV11).removegrain(Y20, UV20).removegrain(Y20, UV20)

    ex_lutxyz(RG11D, RG11DS, c, "x y - A@ x range_half - B@ * 0 < range_half A abs B abs < A range_half + x ? ? z swap - range_half +", Y=Y31, UV=UV31, fulls=fs)

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
    tv    = Default(tv_range,  !rgb)
    fs    = Default(fulls,  false)

    k = (s0 - 1) * c
    l = 1 - k
    d = 1 + c
    f = d * c
    t = tv ? "x ymin - 0 max ymax ymin - /" : "x range_max /"
    e = S0 != 1.0 ? Format("{k} {d} {f} "+t+" A@ {c} + / - * A {l} * + range_max *") : \
        tv        ?        "x ymin - 0 max range_max ymax ymin - / * "               : \
                           "x"

    ec = tv ? "x cmin - range_max cmax cmin - / *" : "x"

    ex_lut(src, e, rgb ? e : ec, Y=Y, UV=UV, fulls=fs) }



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

function ex_BM3D(clip a, float "sigma", int "radius", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    s  = Default(sigma,    3)
    r  = Default(radius,   1)
    UV = Default(UV, rgb ? 3 : 1)

    ch = !(isy || UV!=3)
    ch ? ConverttoYUV444(a) : a
    ConvertBits(bits=32)

    BM3D_CUDA(sigma=[s,ch?s/2:0,ch?s/2:0], radius=r, chroma=ch, fast=true, extractor_exp=6)
    BM3D_VAggregate(radius=r)

    if (bi < 32) {
        ConvertBits(bits=16, dither=-1)
        ConvertBits(bits=bi, dither= 1)
    }
    ch ? MatchColorFormat(a) : mergechroma(a) }



# ex_KNLMeansCL() - KNLMeansCL wrapper by Dogway (21-07-2015)

function ex_KNLMeansCL (clip input, String "device_type", int "device_id", bool "chroma", float "h", int "d", int "a", String "knlm_params", clip "rclip") {

    d            = Default( d, 0)
    a            = Default( a, 1)
    h            = Default( h, 7.0)
    deviceid     = Default( device_id, 0)
    knlm_params  = Default( knlm_params, "")
    chroma       = Default( chroma , true)

    fullchr = input.is444()
    chr420  = input.is420()
    nochr   = input.isy()
    chrlsb  = chroma && !fullchr && !nochr
    cnl     = chrlsb ? "Y" : input.isrgb() ? "auto" : !nochr && chroma ? "YUV" : "Y"
    drclip  = Defined( rclip )
    rclip   = drclip ? rclip : Undefined

    # Beware chroma placement, revise
    If (chrlsb) {
                NL_W    = width(input)
                Uclip   =          ExtractU(input)
                Urclip  = drclip ? ExtractU(rclip) : nop()
                Vclip   =          ExtractV(input)
                Vrclip  = drclip ? ExtractV(rclip) : nop()
                NL_lsb  = chr420 ? StackVertical(  uclip, vclip) : \
                                   StackHorizontal(uclip, vclip)
                rNL_lsb = drclip ? (chr420 ? StackVertical(  urclip, vrclip)  : \
                                             StackHorizontal(urclip, vrclip)) : nop()

                nlc     =          StackHorizontal(ConvertToY(input),  NL_lsb)
                nlrc    = drclip ? StackHorizontal(ConvertToY(rclip) ,rNL_lsb) : Undefined

                nlc     = Eval("nlc.KNLMeansCL(D=d, A=a, h=h, device_type=device_type, device_id=deviceid, rclip=nlrc, channels=cnl" + knlm_params + ")")

                uvh = uclip.height()
                uvw = uclip.width()

                nly = nlc.crop(0,0,chr420 ? -uvw : -(uvw+uvw),0,true)

                nlu = chr420 ? nlc.crop(NL_W,0,0,-uvh,true) : nlc.crop(NL_W    ,0,-uvw,0,true)
                nlv = chr420 ? nlc.crop(NL_W,uvh, 0,0,true) : nlc.crop(NL_W+uvw,0,   0,0,true)
                      CombinePlanes(nly, nlu, nlv, planes="YUV", pixel_type=PixelType(input))
                } else {
                        Eval("input.KNLMeansCL(D=d, A=a, h=h, device_type=device_type, device_id=deviceid, rclip=rclip, channels=cnl" + knlm_params + ")")
                    } }
