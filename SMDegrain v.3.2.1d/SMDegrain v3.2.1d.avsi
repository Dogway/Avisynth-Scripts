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
###                       v3.2.1d      by Dogway - 18 June 2021                              ###
###                                                                                          ###
################################################################################################
###
### General purpose simple degrain function. Pure temporal denoiser. Basically a wrapper(function)/frontend of mvtools2+mdegrain
### with some added common related options. Goal is accessibility and quality but not targeted to any specific kind of source.
### The reason behind is to keep it simple so aside masktools2 you will only need MVTools2.
###
### Check documentation for deep explanation on settings and defaults.
### https://forum.doom9.org/showthread.php?t=182881
###
### UHD input requires SimpleResize 0.3.5,
### UHD: Degrain (or at least add as prefilter) the decoded (and tonemapped) PQ clip (ie. DGHDRtoSDR(mode="pq",white=100))
###
################################################################################################


function SMDegrain (clip input   , int "tr"      , int "thSAD"    , int  "thSADC" , bool "RefineMotion",  val  "contrasharp", clip  "CClip"     , bool "interlaced" , int   "plane" , int   "Globals"  , bool   "tv_range",               \
                     int "pel"   , int "subpixel", val "prefilter", clip "mfilter", int  "blksize"     , int   "overlap"    , int   "search"    , bool "truemotion" , float "limit" , float "limitc"   , int "thSCD1"   , int "thSCD2",   \
                    bool "chroma", int "hpad"    , int "vpad"     , val  "Show"   , float "Str"        , float "Amp"        , int   "dct"       , int "searchparam", int "pelsearch",                                                     \
                  int "device_id", bool "trymany", int "divide"   , int "srfilter", int "threads") {


    tr           = Default( tr,       2 )
    thSAD        = Default( thSAD,  300 )
    thSAD2=thSAD/2
    thSADC       = Default( thSADC, thSAD2)
    RefineMotion = Default( RefineMotion, false)
    Threads      = Default( Threads, sh_GetUserGlobalIMTint())

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
    SBitsn  = input.BitsPerComponent()
    p_type  = input.PixelType()

    isCntr  = IsBool(Contrasharp)
    isLSFm  = !isCntr ? (Contrasharp > 0.0) : Contrasharp
    isMult  = tr > 6     # MDegrainN is slower, so avoid at possible
    isUHD   = (w > 2599 ||  h > 1499)
    isHD    = (w > 1099 ||  h > 599)
    tv_in   = Default(tv_range, !isRGB(input))
    isInter = interlaced ? GetParity(input) : nop()


    pel          = Default( pel,      isHD ? 1 : 2 )
    subpixel     = Default( subpixel, pel)
    srfilter     = Default( srfilter, 4)
    prefilter    = Default( prefilter, -1 )
    MFilterB     = Defined( mfilter )
    pelclip      = pel>1 && subpixel == 3
    Str          = Default( Str, 2.0 )
    Amp          = Default( Amp, 0.0625 )

    blksize      = Default( blksize,  isHD ? 16 : 8 )
    blk2=blksize/2
    overlap      = Default( overlap,  blk2 )
    ovl2=overlap/2
    search       = Default( search,   4 )
    searchparam  = Default( searchparam,   isUHD ? 1 : 2 )
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


    hpad         = Default( hpad, isHD ? 0 : blksize)
    hpadU        = isUHD ? hpad/2+(hpad/2)%2 : hpad
    vpad         = Default( vpad, isHD ? 0 : blksize)
    vpadU        = isUHD ? vpad/2+(vpad/2)%2 : hpad
    vpad         = Default( vpad, isHD ? 0 : blksize)
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

    pref   = !GlobalR ? preclip ? prefilter                                                                               : \
                                 (prefilter==-1) ?  inputP                                                                : \
                                 (prefilter== 0) ?  inputP.ex_MinBlur(0,Chr)                                              : \
                                 (prefilter== 1) ?  inputP.ex_MinBlur(1,Chr)                                              : \
                                 (prefilter== 2) ?  inputP.ex_MinBlur(2,Chr)                                              : \
                                 (prefilter== 3) ?  mt_merge(sneo_dfttest(inputP,slocation="0.0:4.0 0.2:9.0 1.0:15.0",tbsize=1,U=chroma?3:2,V=chroma?3:2,dither=1,threads=Threads,fft_threads=Threads),inputP,        \
                                                    inputP.ex_lut("x ymin < range_max x 75 scaleb > range_min range_max x ymin - range_max 75 scaleb ymin - / * - ? ?"), luma=chroma, cplace="mpeg1", U=chr, V=chr) : \
                                 (prefilter== 4) ?  inputP.ex_KNLMeansCL(device_type="GPU", device_id=device_id, chroma=chroma, a=1,d=1,h=7.0)                                                                      : \
                                                    Assert(false, "prefilter must be between -1~4: "+string(prefilter))                                                                                             : \
                                 inputP

      p_type    = PixelType(input)
      p_typeT   = LeftStr(p_type,6)
      scaleCSAD = p_typeT == "YUV420" ?  0 : \
                  p_typeT == "YUV444" ?  1 : \
                  p_typeT == "YUV411" ? -1 : 0

    # Default Auto-Prefilter - Luma expansion TV->PC (up to 16% more values for motion estimation)

    nw = round(w/2.0)
    nh = round(h/2.0)
    pref       = pref.ex_Luma_Rebuild(S0=Str,c=Amp,uv=Chr,tv_in)   : pref
    pref8      = SBitsn > 8 ? pref.ConvertBits(8,dither=-1)        : pref
    pref8      = isUHD      ? pref8.SimpleResize(nw+nw%2, nh+nh%2) : pref8


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
                if (isUHD) {
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
                vmulti =                   !GlobalR && isUHD ? vmulti.MScaleVect()               : vmulti
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

        output = !GlobalO && isLSFm ? isCntr ? ex_ContraSharpeningHD(output, CClip, HD=isHD) : \
                                                LSFmod(output,source=CClip,defaults="slow",strength=Contrasharp,soothe=false,Lmode=0,soft=-2,keep=0) : output

                 !GlobalO ? (interlaced ? output.weave() : output) : input




    } ELSE {



    ##############
    # SHOW PANEL #
    ##############

      # Common Variables

        h     = h
        w2    = w*1.0
        h2    = h*1.0
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
        w3sq  = string(round(w3*1.01))
        w3s   = string(w3)

          # Panel Separator

        blkclp = BlankClip(interlaced?assumeframebased(pref):pref,length=1,pixel_type=p_type,color=$161616)
                 \.crop(0,interlaced?h/2%8:h%8,0,0,true).separatefields().assumeframebased().separatefields()

        Interleave(selecteven(blkclp).addborders(2,0,0,0,color=$7f7f7f).crop(0,0,-2,0,true),selectodd(blkclp))

        WOut=weave().assumefieldbased().weave()
        sep=(hi-height(WOut))/2

        StackHorizontal(pref,WOut.addborders(0,sep-sep%2,0,hi-(height(WOut)+(sep-sep%2)),color=$161616))


          # Color Guide Squares

        a=interlaced?h*0.37:h*0.74
        b=interlaced?h*0.40:h*0.80
        c=interlaced?h*0.43:h*0.86

        mt_merge(Expr("127 scalef","183 scalef","47 scalef" ) ,mt_lutspa(mode="absolute", yexpr="x "+w3s+" >= x "+w3sq+" <= & y "+string(a)+" >= y "+string(interlaced?h*0.3835:h*0.767)+" <= & & 255 0 ? scalef",scale_inputs="intf").trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true)
        mt_merge(Expr("81 scalef" ,"91 scalef" ,"240 scalef") ,mt_lutspa(mode="absolute", yexpr="x "+w3s+" >= x "+w3sq+" <= & y "+string(b)+" >= y "+string(interlaced?h*0.4135:h*0.827)+" <= & & 255 0 ? scalef",scale_inputs="intf").trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true)
        mt_merge(Expr("210 scalef","16 scalef" ,"146 scalef") ,mt_lutspa(mode="absolute", yexpr="x "+w3s+" >= x "+w3sq+" <= & y "+string(c)+" >= y "+string(interlaced?h*0.4435:h*0.887)+" <= & & 255 0 ? scalef",scale_inputs="intf").trim(0,-1).FreezeFrame(0, FrameCount(pref)-1, 0),luma=true)


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

        Subtitle("SMDegrain Mod v3.2.0",text_color=red||blue||yellow?Color:$7f7f7f,halo_color=$000000,font="VERDANA",size=s*2,x=w1,y=interlaced?h/50:h/20)

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
        Subtitle(varn+              "bitdepth  = " + string(SBitsn)                                                                          ,lsp=lsp,text_color=yellow||blue            ?Color:$494949,font="COURIER NEW",size=s,x=w3,y=ys)

        Subtitle("   Speed"   ,lsp=interlaced?15:30,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(a-1))
        Subtitle("   Memory"  ,lsp=interlaced?17:34,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(b-1))
        Subtitle("   Quality" ,lsp=interlaced?19:38,text_color=$7f7f7f,font="COURIER NEW",size=s,x=w3,y=round(c-1))
        } }



# Didée MCDegrain, mod

function MCDegrainModex(clip c, int "frames", clip "srch", bool "soft", int "thSAD")
{
    frames = Default(frames, 2)
    srch   = Default(srch,c)
    soft   = Default(soft,false)
    thSAD  = Default(thSAD,400)
    bs = (c.width>960) ? 16 : 8
    rg = (c.width<640) ? 11 : (c.width<1200) ? 12 : 19
    rg = soft ? rg : 0
    input = !soft ? c : c.ex_adddiff(ex_makediff(c,c.removegrain(rg)),UV=2)
      (frames<=0) ? c : input.SMDegrain(frames,thsad,pel=2,prefilter=srch,mfilter=c.removegrain(rg),subpixel=1,srfilter=2,Truemotion=true,vpad=8,hpad=8)
    return(last) }




########################################################
#                                                      #
# HELPER FUNCTIONS: For Contrasharp and Prefilter      #
#                                                      #
########################################################


########################################
## Didée's functions:

 # contra-sharpening: sharpen the denoised clip, but don't add more to any pixel than what was removed previously.
 # script function from Didée, at the VERY GRAINY thread

 # In final version 2.0d ContraHD() was merged, to allow proper HD sharpening.
 # In this case global variables of (before denoising) source MSuper and forward and backward
 # compensated motion vectors are necessary as: Super, cb1 and cf1, if used as a stand alone function.
 # Don't know who made (mod) it, so I can't give proper credits, sorry.

function ex_ContraSharpeningHD(clip denoised, clip original, bool "HD", int "overshoot") {

    HD        = Default(HD    ,false)
    overshoot = Default(overshoot, 0)

    HD ? Eval("""
    cb1  = original.MCompensate(Super, cb1)
    cf1  = original.MCompensate(Super, cf1)
    pmax = original.mt_logic(cb1, "max").mt_logic(cf1, "max")
    pmin = original.mt_logic(cb1, "min").mt_logic(cf1, "min")""") : nop()

    s    = denoised.ex_MinBlur(HD?2:1,1)                                      # Damp down remaining spots of the denoised clip.

    allD = ex_makediff(original,denoised)                                     # The difference achieved by the denoising.
    ssD  = ex_makediff(s,HD?s.removegrain(19,-1).\
                              removegrain(19,-1):\
                            s.removegrain(12,-1))                             # The difference of a simple kernel blur.
    ssDD = ssD.repair(HD?ssD.repair(allD,1):allD,HD?12:1)                     # Limit the difference to the max of what the denoising removed locally.

    ssDD = SSDD.ex_lutxy(ssD,"x range_half - abs y range_half - abs < x y ?") # abs(diff) after limiting may not be bigger than before.

    denoised.ex_adddiff(ssDD,UV=2)                                            # Apply the limited difference. (Sharpening is just inverse blurring)
    HD ? ex_clamp(last,pmax,pmin,overshoot,overshoot,UV=2) : last }



 # MinBlur   by Didée
 # Nifty Gauss/Median combination
 # TODO: abtype default is missing
function ex_MinBlur(clip clp, int "r", int "uv", bool "planar", string "mode", int "abtype", bool "blurrep", int "y", int "u", int "v") {

    r       = Default(r,1)
    uv      = Default(uv,3)
    u       = Defined(u) ? u : uv
    v       = Defined(v) ? v : uv
    Y       = Default(Y, 3)
    defmod  = Defined(mode)
    mode    = Default(mode,"Median_Both")
    blurrep = Default(blurrep, false)

    ch    = u==1 && v==1
    u2    = (u==2) ? 1  : u
    v2    = (v==2) ? 1  : v
    ch2   = u2==1 && v2==1
    y2    = (y==2) ? 1  : y
    rg4   = (u==3) ? 4  : -1
    rg11  = (u==3) ? 12 : -1
    rg20  = (u==3) ? 19 : -1
    rg4v  = (v==3) ? 4  : -1
    rg11v = (v==3) ? 12 : -1
    rg20v = (v==3) ? 19 : -1
    rg4y  = (y==3) ? 4  : -1
    rg11y = (y==3) ? 12 : -1
    rg20y = (y==3) ? 19 : -1
    rg4v  = !(defmod && r==1) && (r<=1)
    medfy = (y==3) ? 1 : -200
    medf  = (u==3) ? 1 : -200

    blurstr = mode == "Median_Both"        ? "medianblur(r*medfy,r*medf,r*medf)"                           : \
              mode == "average_Both"       ? "aBlur(r, abtype, chroma=uv)"                                 : \
              mode == "average_horizontal" ? "aBlur(r, abtype, blurv="+String(r==1 ? 0 : 1)+", chroma=uv)" : \
              mode == "average_vertical"   ? "aBlur("+String(r==1 ? 0 : 1)+", abtype, blurv=r, chroma=uv)" : \
              mode

    # Add Y= argument to ex_makediff for chroma only minblur
    RG11D = (r==0) ?  ex_makediff(clp,clp.ex_sbr(U=u2,V=v2),UV=u2)                                                       : \
            (r==1) ?  ex_makediff(clp,clp.removegrain(rg11y,rg11),UV=u2)                                                 : \
            (r==2) ?  ex_makediff(clp,clp.removegrain(rg11y,rg11).removegrain(rg20y,rg20),UV=u2)                         : \
                      ex_makediff(clp,clp.removegrain(rg11y,rg11).removegrain(rg20y,rg20).removegrain(rg20y,rg20),UV=u2)

    RG4D  = (rg4v) ?  ex_makediff(clp,clp.removegrain(rg4y,rg4),UV=u2)                                                   : \
                      Eval("ex_makediff(clp,clp."+blurstr+",UV=u2)")

    DD    =           ex_lutxy(RG11D,RG4D,"x range_half - A@ y range_half - B@ * 0 < range_half A abs B abs < x y ? ?",y=y2,UV=u2)
                      clp.ex_makediff(DD,UV=u)
    blurrep ? Repair(clp.removegrain(y!=3 ? 0 : 17,u==3 ? 0 : -1,v==3 ? 0 : -1),y!=3 ? 0 : 9,u==3 ? 0 : -1,v==3 ? 0 : -1) : last }



 # helper function: make a highpass on a blur's difference (well, kind of that)
 # Highpass of spatial r=1 Gaussian (like blur(1.0))

function ex_sbr(clip c, int "r", int "y", int "U", int "V") {

    r      = Default(r, 1)
    Y      = Default(Y, 3)
    U      = Default(U, 3)
    V      = Default(V, 3)
    Y31    = (Y==3) ? 3 : 1
    U31    = (U==3) ? 3 : 1
    V31    = (V==3) ? 3 : 1
    Y11    = (Y==3) ? 12 : -1
    Y20    = (Y==3) ? 19 : -1
    U11    = (U==3) ? 12 : -1
    U20    = (U==3) ? 19 : -1
    V11    = (V==3) ? 12 : -1
    V20    = (V==3) ? 19 : -1

    rg11   = (r<=1) ?     c.removegrain(Y11, U11, V11)                                                       : \
             (r==2) ?     c.removegrain(Y11, U11, V11).removegrain(Y20, U20, V20)                            : \
                          c.removegrain(Y11, U11, V11).removegrain(Y20, U20, V20).removegrain(Y20, U20, V20)

    rg11D  = ex_makediff(c,rg11, UV=U31)

    RG11DS = (r<=1) ? rg11D.removegrain(Y11, U11, V11)                                                       : \
             (r==2) ? rg11D.removegrain(Y11, U11, V11).removegrain(Y20, U20, V20)                            : \
                      rg11D.removegrain(Y11, U11, V11).removegrain(Y20, U20, V20).removegrain(Y20, U20, V20)

    rg11DD = ex_lutxy(RG11D, RG11DS, "x y - A@ x range_half - * 0 < range_half A abs x range_half - abs < A range_half + x ? ?", Y=Y31, UV=U31)
             ex_makediff(c,rg11DD, UV=U) }



# Converts luma (and chroma) to PC levels, and optionally allows tweaking for pumping up the darks. (for the clip to be fed to motion search only)
# By courtesy of cretindesalpes.

function ex_Luma_Rebuild (clip src, float "s0", float "c", int "Y", int "UV", bool "tv_range") {

    rgb   = isrgb(src)

    Y     = Default(Y,       3)
    UV    = Default(UV,      3)
    s0    = Default(s0,    1.0)
    c     = Default(c,  1.0/16)
    tv    = Default(tv_range,  !rgb)

    Assert(!rgb, "ex_Luma_Rebuild: RGB Color format is not supported" )

    k = (s0 - 1) * c
    l = 1 - k
    d = 1 + c
    f = d * c
    t = tv ? "x ymin - ymax ymin - /" : "x range_max /"
    e = S0 != 1.0 ? Format("{k} {d} {f} "+t+" A@ {c} + / - * A {l} * + range_max *") : \
        tv        ? Format("x ymin - range_max ymax ymin - / *")                     : \
                           "x"

    ec = tv ? "x range_half - range_max cmax cmin - / * range_half +" : "x"

    bi = BitsPerComponent(src)
    ex_lut(src, ex_Yexpr(e,Y), ex_UVexpr(rgb,ec,UV,bi), Y=y, UV=uv) }


# ex_KNLMeansCL

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
    drclip  = Defined(rclip)
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
