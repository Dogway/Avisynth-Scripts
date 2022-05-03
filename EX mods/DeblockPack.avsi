#############################################################################
###                                                                       ###
###        Deblock Pack v2.3  (01-05-2022)                                ###
###                                                                       ###
###        Collection of deblocking solutions for AviSynth+               ###
###                                                                       ###
###                                                                       ###
###        Included:                                                      ###
###            Deblock_QED     (+Deblock plugin)                          ###
###            DeblockFFT3D    (+FFT3D plugin)                            ###
###            CCD             (Script)                                   ###
###            MCDeblockFFT3D  (+FFT3D plugin)                            ###
###            SmoothD2c       (+SmoothD2 plugin)                         ###
###            MSUDeCor        (+MSU_Smart_Deblocking plugin)             ###
###            SmoothDeblock   (Script) (WIP)                             ###
###            Oyster          (Script) (WIP)                             ###
###        Other (not included):                                          ###
###            BlindPP("xxxx")(DCDecode)                                  ###
###            Deblock(DGDecode,MVTools)                                  ###
###            DeblockM                                                   ###
###            vsDeblockPP7                                               ###
###            MSUDeblock                                                 ###
###            MSUSmartDeblocking                                         ###
###            SmoothD2                                                   ###
###            Unblock                                                    ###
###            BlockTerminator (Script)                                   ###
###            BlockKiller     (Script)                                   ###
###            FunkyDeblock    (Script)                                   ###
###            AutoDeblock3    (Script)                                   ###
###                                                                       ###
###                                                                       ###
#############################################################################
###
### Deblock_QED by Didée (17-11-2005)
###
### "A postprocessed Deblock(): Uses full frequencies of Deblock's changes on block borders, but DCT-lowpassed changes on block interiours."
### Idea is just that blocking will show high frequencies at block borders, so high frequencies at block borders are reduced (If deblock() did so).
### In block interiours, the chances of differentiating 1st/2nd generation blocking artefacts from actual detail are poor anyway, and danger is high to remove detail.
### So, for block interiours get only a different "shading"
###
### https://avisynth.nl/index.php/Deblock_QED
### https://web.archive.org/web/20060509152326/http://home.arcor.de/dhanselmann/_stuff/Deblock_QED.avs
### https://videoprocessing.forumer.com/viewtopic.php?p=413
### https://forum.doom9.org/showthread.php?p=751174#post751174
###
### Dependencies:
###             Deblock
###             DCTFilter
###             ExTools
###             ResizersPack
###
### Changelog:
###
### Changes 2005-11-17: (Didée)
### - Initial version (date is estimate, could be few months earlier)
###
### Changes 2008-08-18: (Didée)
### - Replaced the ugly stackXXX cascade with mt_LutSpa() (requires MaskTools v2.0a35)
### - Changed Quant and Offset defaults to 24,28,2,4,4,8
###
### Changes 2010-05-25: (Bi11)
### - Explicitly specified parameters of mt_LutSpa()
###   (required due to position of new 'biased' parameter, starting from MaskTools 2.0a43)
### - Non mod 16 input is now padded with borders internally
###
### Changes 2010-08-18: (Bi11)
### - Replaced AddBorders with PointResize
### - Changed Quant and Offset defaults to 18,19,3,4,1,1 to reduce blurring
###
### Changes 2010-10-16: (Bi11)
### - Replaced 'relative' with the new 'mode' parameter in mt_LutSpa(), starting from MaskTools 2.0a45
### - Changed Quant and Offset defaults to 24,26,1,1,2,2 to increase effectiveness, but still within sensible limits.
###   (see for details: https://forum.doom9.org/showthread.php?p=810932#post810932)
###
### Changes 2011-11-29: (06_taro)
### - Replaced (chroma=uv>2?"process":"ignore") by (chroma=uv>2?"process":"copy") to avoid garbage clip when uv=2.
###   The formal parameter is not used by MaskTools2 any more, if ever used.
###   Foxyshadis once mentioned chroma="ignore" but I had never found a document containing it.
###
### Changes 2014-10-20: (GMJCZP)
### - Now calling to plugin deblock exclusively and not to the older function deblock of DGDecode
###
### Changes 2016-05-08: (Motenai Yoda)
### - Added internal variable uvp for skip chroma post processing when uv!=3
### - Replaced most (chroma=uv>2?"process":"copy") and all U=uv,V=uv by U=uvp,V=uvp to trash chroma planes when uv!=3
### - Replaced last (chroma=uv>2?"process":"copy") by (U= uv<2 ? 1 : uv,V= uv<2 ? 1 : uv) to trash chroma planes when uv=1|-1
###
### Changes 2016-06-19: (A.SONY)
### - re add "ignore" for chroma but if uv=2 will use "copy"
### - add exdeblock1 and exdeblock2 to use an external deblock
###
### Changes 2021-09-21: (Dogway)
### - Ported to ExTools
### - Optimized expressions (29% speed increase)
### - Replaced PointResize with PadBorders (2021-10-18)
###
###
### Function Definition:
###     (
###     clip,
###     int "quant1"=24 (0 to 60),
###     int "quant2"=26 (0 to 60),
###     int "aOff1"=1 (1 to 50),
###     int "bOff1"=2 (1 to 50),
###     int "aOff2"=1 (1 to 50),
###     int "bOff2"=2 (1 to 50),
###     int "UV"=3 (1 / 2 / 3)
###     )
###

function Deblock_QED ( clip clp, int "quant1", int "quant2", int "aOff1", int "bOff1", int "aOff2", int "bOff2", string "exdeblock1", string "exdeblock2", int "UV"  ) {

    rgb    = isRGB(clp)
    fs     = propNumElements (clp,"_ColorRange")  > 0 ? \
             propGetInt      (clp,"_ColorRange") == 0 : rgb

    quant1 = Default( quant1, 24 ) # Strength of block edge deblocking
    quant2 = Default( quant2, 26 ) # Strength of block internal deblocking

    # aOff and bOff controls block detection and removal strength, for quant1 and quant2 respectively
    aOff1  = Default( aOff1,   1 ) # Halfway "sensitivity" and halfway a strength modifier for borders
    aOff2  = Default( aOff2,   1 ) # Halfway "sensitivity" and halfway a strength modifier for block interiors
    bOff1  = Default( bOff1,   2 ) # "Sensitivity to detect blocking" for borders
    bOff2  = Default( bOff2,   2 ) # "Sensitivity to detect blocking" for block interiors

    UV     = Default( uv, 3 )      # u=3  -> use proposed method for chroma deblocking
                                   # u=2  -> no chroma deblocking at all (just copy it from source)
                                   # u=1  -> directly use chroma deblocking from the normal deblock()
                                   # u=-1 -> directly use chroma deblocking from the strong deblock()
    isy = isy(clp)
    UV1 = !isy ?  uv == 1 ?  4  : abs(UV) : 1
    UV2 = !isy && uv == 1 ? "z" : Undefined()

    # add borders if clp is not mod 8
    w    = clp.width ()
    h    = clp.height()
    padX = w%8 == 0 ? 0 : (8 - w%8)
    padY = h%8 == 0 ? 0 : (8 - h%8)
    clp  = clp.PadBorders(0,0,padX,padY,"Dilate")

    # block
    block = clp.ex_lutspa(mode="absolute",expr="x 1 + 8 % 1 < x 8 % 1 < y 1 + 8 % 1 < y 8 % 1 < | | | range_max 0 ?", UV=!isy && uv!=2 ? 3 : 1)

    # create normal deblocking (for block borders) and strong deblocking (for block interiour)
    normal = Defined(exdeblock1) ? Eval("clp." + exdeblock1) : clp.Deblock_deblock(quant=quant1,aOffset=aOff1,bOffset=bOff1)
    strong = Defined(exdeblock2) ? Eval("clp." + exdeblock2) : clp.Deblock_deblock(quant=quant2,aOffset=aOff2,bOffset=bOff2)

    # build difference maps of both and...
    # separate border values of the difference maps, and set the interiours to '128'
    normalD2 = ex_lutxyz(clp,normal,block,"z range_max == x y -        range_half + range_half ?",UV=uv1,fulls=fs)
    strongD2 = ex_lutxyz(clp,Strong,block,"z range_max == x y - 1.01 * range_half + range_half ?",UV=uv1,fulls=fs)

    # interpolate the border values over the whole block: DCTFilter can do it. (Kiss to Tom Barry!)
    # (Note: this is not fully accurate, but a reasonable approximation.)
    # add borders if clp is not mod 16
    sw   = strongD2.width ()
    sh   = strongD2.height()
    remX = sw%16 == 0 ? 0 : (16 - sw%16)
    remY = sh%16 == 0 ? 0 : (16 - sh%16)

    strongD3 = strongD2.PadBorders(0,0,remX,remY,"Dilate").DCTfilter(1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0).crop(0,0,-remX,-remY)

    # apply compensation from "normal" deblocking to the borders of
    # the full-block-compensations calculated from "strong" deblocking ... and apply it.
    deblocked = ex_lutxyz(clp, strongD3, normalD2, "z range_half == y z ? x swap - range_half +", UV2, UV=min(uv1,3),fulls=fs)

    # simple decisions how to treat chroma
    deblocked = (uv<0) ? deblocked.mergechroma(strong) : deblocked

    # remove mod 8 borders
    deblocked.crop(0,0,-padX,-padY) }




function DeblockFFT3D(clip a, int "UV", bool "fulls") {

    rgb   = isRGB(a)
    bi    = BitsPerComponent(a)

    UV    = Default(UV,      3)
    fs    = Default(fulls, rgb)

    fft   = a.fft3dfilter(sigma=16,sigma2=6,sigma3=1,sigma4=0,bw=12,bh=12,ow=6,oh=6,bt=5,plane=UV==3?4:0,ncpu=2)
#    fft   = a.FFT3DGPU(sigma=16,sigma2=8,sigma3=4,sigma4=2,bw=16,bh=16,ow=8,oh=8,bt=4,plane=UV==3?4:0,precision=bi>8?0:2)  # x7 performance but not a match (also severely bugged, avoid)
    rg20D = ex_lutxy(fft,fft.removegrain(20,UV==3?20:-1),"x y - 1.49 * range_half +",UV=uv,fulls=fs)
            ex_lutxyza(a,fft,rg20D,fft,"x y - X@ z range_half - Z@ * 0 < a X abs Z abs < X a + z a range_half - + ? ? ",UV=uv,fulls=fs) }



## Motion Compensated Deblock
function MCDeblockFFT3D(clip a, int "UV", bool "fulls") {

    rgb     = isRGB(a)
    bi    = BitsPerComponent(a)

    UV      = Default(UV,      3)
    fs      = Default(fulls, rgb)

    pre     = UV<3 && !isy(a) ? a.ExtractY() : a
    pre     = pre.ConvertBits(8, dither=-1, fulls=fs)

    sup     = pre.MSuper(pel=1, hpad = 0, vpad = 0, chroma=UV==3, mt=true)
    vectors = sup.MAnalyse(isb = false, lambda = 1000,truemotion=false,chroma=UV==3,mt=true)
    compensation = pre.MCompensate(sup,vectors).ConvertBits(bi, fulls=fs)

    compensation.DeblockFFT3D(UV=uv,fulls=fs)
    UV<3 && !isy(a) ? CombinePlanes(last,a,planes="YUV",Pixel_Type=PixelType(a)) : last
    }





###
### CCD() - by Sergey Stolyarevsky (18-11-2007)
### CCD - Camcorder Color Denoise, port by Dogway (30-04-2022)
###
### AviSynth+ port of Julek's VapourSynth port of "Camcorder Color Denoise" VirtualDub plugin by Sergey Stolyarevsky.
### This is a chroma denoiser, characterized to easily present blocking in digital video recordings,
### specially with codecs preceding H.264, like camcorders or VHS captures.
### The author designed it against video from a Canon MD160 camera (320x240 12.5fps interlaced).
###
### https://github.com/dnjulek/jvsfunc/blob/main/jvsfunc/expr.py
### http://acobw.narod.ru/
###
function CCD (clip a, float "thres", bool "interlaced", int "U", int "V") {

    rgb  = isRGB(a)
    is4  = is444(a)
    isy  = isy  (a)
    w    = width(a)
    h    = height(a)
    isHD = (w > 1099 || h > 599 )
    isUHD= (w > 2599 || h > 1499)

    bi   = BitsPerComponent(a)
    pr   = propNumElements (a,"_Primaries" )  > 0 ? \
           propGetInt      (a,"_Primaries" )  :-1
    fbn  = propNumElements (a,"_FieldBased")  > 0
    fb   = fbn                                    ? \
           propGetInt      (a,"_FieldBased")  : GetParity(a) ? 2 : 1
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : false

    th   = Default(thres,  4)  # 0 - 100 (good values span 4-30)
    inter= Default(interlaced, fbn && fb!=0)
    U    = Default(U,      3)
    V    = Default(V,      3)
    in   = is4 ? round(w/80.)       : round(w/160.)
    ou   = is4 ? round(w/26.666666) : round(w/53.333333)
    ih   = fbn && fb!=0 && Defined(interlaced) ? round(in * 0.5) : in
    oh   = fbn && fb!=0 && Defined(interlaced) ? round(ou * 0.5) : ou

    Assert(IsVersionOrGreater(3,7,2), "CCD: Update AviSynth+ version")
    Assert(!rgb && !isy,              "CCD: Only YUV formats are supported")

    if (inter) {

        fb==1 ? fbn ? AssumeBFF(a) : AssumeBFF(a).propSet("_FieldBased",1) : \
                fbn ? AssumeTFF(a) : AssumeTFF(a).propSet("_FieldBased",2)
        E = SeparateFields().SelectEven().CCD(th,false,U,V)
        O = SeparateFields().SelectOdd ().CCD(th,false,U,V)
        Interleave(E,O).Weave()

    } else {

        th  = pow(th,2)/195075.0
        pr  = pr > 0 && pr != 2 ? pr==1 ? "709"    : \
                                  pr==4 ? "bt470m" : \
                                  pr==5 ? "470bg"  : \
                                  pr==6 ? "170m"   : \
                                  pr==6 ? "240m"   : \
                                  pr==9 ? "2020"   : "709" : isUHD ? "2020" : isHD ? "709" : "170m"

        y   = ExtractY(a)
        a4  = CombinePlanes(y.BicubicResize(w/2, h/2, -0.5, 0.3), a, planes="YUV", pixel_type="YUV444P"+string(bi==32 ? "S" : bi))
        rgb = ConvertToPlanarRGB(is4 ? a : a4, matrix=fs?pr+":f":pr+":l")

        r   = CombinePlanes(rgb, planes="RGB", source_planes="RRR")
        g   = CombinePlanes(rgb, planes="RGB", source_planes="GGG")
        b   = CombinePlanes(rgb, planes="RGB", source_planes="BBB")

        ex  = Format("f32
             y[-{ou},-{oh}] y - 2 ^ z[-{ou},-{oh}] z - 2 ^ a[-{ou},-{oh}] a - 2 ^ + + {th} < A@ 1 0 ?
             y[-{in},-{oh}] y - 2 ^ z[-{in},-{oh}] z - 2 ^ a[-{in},-{oh}] a - 2 ^ + + {th} < B@ 1 0 ? +
             y[{in},-{oh}]  y - 2 ^ z[{in},-{oh}]  z - 2 ^ a[{in},-{oh}]  a - 2 ^ + + {th} < C@ 1 0 ? +
             y[{ou},-{oh}]  y - 2 ^ z[{ou},-{oh}]  z - 2 ^ a[{ou},-{oh}]  a - 2 ^ + + {th} < D@ 1 0 ? +
             y[-{ou},-{ih}] y - 2 ^ z[-{ou},-{ih}] z - 2 ^ a[-{ou},-{ih}] a - 2 ^ + + {th} < E@ 1 0 ? +
             y[-{in},-{ih}] y - 2 ^ z[-{in},-{ih}] z - 2 ^ a[-{in},-{ih}] a - 2 ^ + + {th} < F@ 1 0 ? +
             y[{in},-{ih}]  y - 2 ^ z[{in},-{ih}]  z - 2 ^ a[{in},-{ih}]  a - 2 ^ + + {th} < G@ 1 0 ? +
             y[{ou},-{ih}]  y - 2 ^ z[{ou},-{ih}]  z - 2 ^ a[{ou},-{ih}]  a - 2 ^ + + {th} < H@ 1 0 ? +
             y[-{ou},{ih}]  y - 2 ^ z[-{ou},{ih}]  z - 2 ^ a[-{ou},{ih}]  a - 2 ^ + + {th} < I@ 1 0 ? +
             y[-{in},{ih}]  y - 2 ^ z[-{in},{ih}]  z - 2 ^ a[-{in},{ih}]  a - 2 ^ + + {th} < J@ 1 0 ? +
             y[{in},{ih}]   y - 2 ^ z[{in},{ih}]   z - 2 ^ a[{in},{ih}]   a - 2 ^ + + {th} < K@ 1 0 ? +
             y[{ou},{ih}]   y - 2 ^ z[{ou},{ih}]   z - 2 ^ a[{ou},{ih}]   a - 2 ^ + + {th} < L@ 1 0 ? +
             y[-{ou},{oh}]  y - 2 ^ z[-{ou},{oh}]  z - 2 ^ a[-{ou},{oh}]  a - 2 ^ + + {th} < M@ 1 0 ? +
             y[-{in},{oh}]  y - 2 ^ z[-{in},{oh}]  z - 2 ^ a[-{in},{oh}]  a - 2 ^ + + {th} < N@ 1 0 ? +
             y[{in},{oh}]   y - 2 ^ z[{in},{oh}]   z - 2 ^ a[{in},{oh}]   a - 2 ^ + + {th} < O@ 1 0 ? +
             y[{ou},{oh}]   y - 2 ^ z[{ou},{oh}]   z - 2 ^ a[{ou},{oh}]   a - 2 ^ + + {th} < P@ 1 0 ? 1 + + Q^
             A x[-{ou},-{oh}] 0 ?   B x[-{in},-{oh}] 0 ? +
             C x[{in},-{oh}]  0 ? + D x[{ou},-{oh}]  0 ? +
             E x[-{ou},-{ih}] 0 ? + F x[-{in},-{ih}] 0 ? +
             G x[{in},-{ih}]  0 ? + H x[{ou},-{ih}]  0 ? +
             I x[-{ou},{ih}]  0 ? + J x[-{in},{ih}]  0 ? +
             K x[{in},{ih}]   0 ? + L x[{ou},{ih}]   0 ? +
             M x[-{ou},{oh}]  0 ? + N x[-{in},{oh}]  0 ? +
             O x[{in},{oh}]   0 ? + P x[{ou},{oh}]   0 ? x + + Q /")

        Expr(a4, r, g, b, "", U==3 ? ex : "", V==3 ? ex : "", scale_inputs="intf")

        CombinePlanes(a, last, planes="YUV")                                   } }





################################
###                          ###
###   Oyster by  feisty2     ###
###                          ###
################################

## Initial VapourSynth release (01-05-2016)
## AviSynth+ port    by Dogway (20-09-2021) (WIP)
##
## Input: 444 YUV/RGB at any bitdepth (output is float)
##
##  - Destaircase + Deringing
##      sup   = oyster_Super(clp)
##      ref_f = oyster_Basic(clp, sup, short_time=False)
##      ref_s = oyster_Basic(clp, sup, short_time=True)
##      clp   = oyster_Destaircase(clp, ref_f, block_step=2)
##      clp   = oyster_Deringing  (clp, ref_s, block_step=2)
##
##  - Destaircase + Deringing (severe mosquito noise)
##      sup   = oyster_Super(clp)
##      ref_f = oyster_Basic(clp, sup, short_time=False)
##      ref_s = oyster_Basic(clp, sup, short_time=True)
##      clp   = oyster_Destaircase(clp, ref_f, block_step=2, lowpass="0.0:1024 1.0:1024")
##      clp   = oyster_Deringing  (clp, ref_s, sigma=24.0, h=12.8, block_step=2, lowpass="0.0:1024 1.0:1024")
##
##  - Destaircase + Deringing (H.264/H.265 compression artifacts)
##      sup   = oyster_Super(clp)
##      ref_f = oyster_Basic(clp, sup, short_time=False)
##      ref_s = oyster_Basic(clp, sup, short_time=True)
##      clp   = oyster_Destaircase(clp, ref_f, sigma=24.0, block_step=2)
##      clp   = oyster_Deringing  (clp, ref_s, sigma=24.0, h=9.6, block_step=2)
##
##  - Deblocking + Deringing
##      sup   = oyster_Super(clp)
##      ref_f = oyster_Basic(clp, sup, short_time=False)
##      ref_s = oyster_Basic(clp, sup, short_time=True)
##      clp   = oyster_Deblocking(clp, ref_f, block_step=2)
##      clp   = oyster_Deringing (clp, ref_s, sigma=24.0, h=10.8, block_step=2)
##
##    Dependencies:
##                  ExTools
##                  ResizersPack
##                  MVTools
##                  KNLMeansCL
##                  BM3D
##                  DFTTest
##                  nnedi3
##                  SysInfo
##                  TransformsPack (for RGB)


function oyster_Super(clip src, int "pel") {

    pel = Default(pel, 2)
    bi  = BitsPerComponent(src)
    rgb = isRGB(src)
    fs  = propNumElements (src,"_ColorRange")  > 0 ? \
          propGetInt      (src,"_ColorRange") == 0 : rgb

    Assert(isclip(src),          "oyster_Super: src has to be a video clip!")
    Assert(bi == 32,             "oyster_Super: the sample type of src has to be single precision!")
    Assert(is444(src) || rgb,    "oyster_Super: subsampled stuff not supported!")
    Assert(pel == 2 || pel == 4, "oyster_Super: pel has to be 2 or 4!")
    cores   = SI_PhysicalCores()
    threads = SI_LogicalCores()

    src
    AssumeFrameBased()
    rgb ? !fs ? SMPTE_legal(false).RGB_to_OPP() : RGB_to_OPP() : last
    ConvertBits(8, dither=-1, fulls=rgb ? false : fs)

#    PadBorders(128, 128, 128, 128, "Dilate")
    PadBorders(64, 64, 64, 64, "Dilate")
#    nnedi3_rpow2(rfactor=pel,nns=4,nsize=0,qual=2,threads=th/2,prefetch=th,SetAffinity=true,MaxPhysCore=false)
    nnedi3_rpow2(rfactor=pel,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)

    return last }



function oyster_Basic(clip src, clip "super", int "radius", int "pel", int "sad", bool "short_time", bool "color") {

    super      = Default(super, Undefined())
    radius     = Default(radius, 6)
    pel        = Default(pel,    2)
    sad        = Default(sad, 2000)
    short_time = Default(short_time, false)
    color      = Default(color, !isy(src))
    plane      = color ? 4 : 0

    rgb = isRGB(src)
    bi  = BitsPerComponent(src)
    fs  = propNumElements (src,"_ColorRange")  > 0 ? \
          propGetInt      (src,"_ColorRange") == 0 : rgb

    Assert(isclip(src),                "oyster_Basic: src has to be a video clip!")
    Assert(is444(src) || rgb,          "oyster_Basic: subsampled stuff not supported!")
    Assert(pel == 1 || pel == 2 || pel == 4, "oyster_Super: pel has to be 1, 2 or 4!")
    Assert(isclip(super),              "oyster_Basic: super has to be a video clip or None!")
    Assert(isint(radius),              "oyster_Basic: radius has to be an integer!")
    Assert(radius>1,                   "oyster_Basic: radius has to be greater than 0!")
    Assert(isint(pel),                 "oyster_Basic: pel has to be an integer!")
    Assert(isfloat(sad),               "oyster_Basic: sad has to be a real number!")
    Assert(sad>0,                      "oyster_Basic: sad has to be greater than 0!")
    Assert(isbool(short_time),         "oyster_Basic: short_time has to be boolean!")

    src   = rgb ? !fs ? src.SMPTE_legal(false).RGB_to_OPP() : src.RGB_to_OPP() : src
    src   = AssumeFrameBased(src)
    super = Defined(super) ? super : AssumeFrameBased(super)

#    src         = PadBorders(src, 128, 128, 128, 128, "Dilate")
    src         = PadBorders(src, 64, 64, 64, 64, "Dilate")
    pre         = src.ConvertBits(8, dither=-1, fulls=rgb ? false : fs)
    supersoft   = MSuper(pre, pelclip=super, rfilter=4, pel=pel, chroma=color, hpad=0, vpad=0, sharp=2, levels=0)
    supersharp  = MSuper(pre, pelclip=super, rfilter=2, pel=pel, chroma=color, hpad=0, vpad=0, sharp=2, levels=0).ConvertBits(32, fulls=fs)

    if (short_time) {

       constant = 0.0001989762736579584832432989326
       me_sad0  = round(constant * pow(sad, 2.0) * log(1.0 + 1.0 / (constant * sad)))
       me_sad1  = sad
       vmulti   = MAnalyse(supersoft, delta=radius, chroma=color, overlap=4, blksize=8, search=3, truemotion=False, trymany=True, levels=0, badrange=-24, divide=0, dct=0, multi=true, mt=true)
       vmulti   = MRecalculate(supersoft, vmulti, tr=radius, chroma=color, overlap=2, blksize=4, thsad=me_sad0, truemotion=False, search=3, smooth=1, divide=0, dct=0, mt=true)
       vmulti   = MRecalculate(supersoft, vmulti, tr=radius, chroma=color, overlap=1, blksize=2, thsad=me_sad1, truemotion=False, search=3, smooth=1, divide=0, dct=0, mt=true)

    } else {

       constant = 0.0000139144247313257680589719533
       me_sad   = round(constant * pow(sad, 2.0) * log(1.0 + 1.0 / (constant * sad)))
#       vmulti   = MAnalyse(supersoft, delta=radius, chroma=color, overlap=64, blksize=128, search=3, truemotion=False, trymany=True, levels=0, badrange=-24, divide=0, dct=0, multi=true, mt=true)
       vmulti   = MAnalyse(supersoft, delta=radius, chroma=color, overlap=32, blksize=64, search=3, truemotion=False, trymany=True, levels=0, badrange=-24, divide=0, dct=0, multi=true, mt=true)
#       vmulti   = MRecalculate(supersoft, vmulti, tr=radius, chroma=color, overlap=32, blksize=64, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, mt=true)
       vmulti   = MRecalculate(supersoft, vmulti, tr=radius, chroma=color, overlap=16, blksize=32, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, mt=true)
       vmulti   = MRecalculate(supersoft, vmulti, tr=radius, chroma=color, overlap=8, blksize=16, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, mt=true)
       vmulti   = MRecalculate(supersoft, vmulti, tr=radius, chroma=color, overlap=4, blksize=8, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, mt=true)
       vmulti   = MRecalculate(supersoft, vmulti, tr=radius, chroma=color, overlap=2, blksize=4, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, mt=true)

  }
    clp         = src.MDegrainN(supersharp, vmulti, radius, thsad=sad, plane=plane, thscd1=8*8*255, thscd2=255, mt=true)
    clp         = Crop(clp, 64, 64, -64, -64)

    return clp }



function oyster_Deringing(clip src, clip ref, int "radius", float "h", float "sigma", float "mse0", float "mse1", float "hard_thr", int "block_size", int "block_step", int "group_size", int "bm_range", int "bm_step", int "ps_num", int "ps_range", int "ps_step", string "lowpass", bool "color") {

    radius      = Default(radius,       6)
    h           = Default(h,          6.4)
    sigma       = Default(sigma,     16.0)
#    mse0        = Default(mse0, sigma * 160.0 + 1200.0)
#    mse1        = Default(mse1, sigma * 120.0 + 800.0)
#    hard_thr    = Default(hard_thr,  3.2)
    block_size  = Default(block_size,   8)
    block_step  = Default(block_step,   1)
#    group_size  = Default(group_size, 32)
    bm_range    = Default(bm_range,    24)
#    bm_step     = Default(bm_step,     1)
    ps_num      = Default(ps_num,       2)
    ps_range    = Default(ps_range,     8)
#    ps_step     = Default(ps_step,     1)
    lowpass     = Default(lowpass, Format("0.0:{sigma} 0.48:1024.0 1.0:1024.0"))
    color       = Default(color, !isy(src))

    rgb = isRGB(src)
    bi  = BitsPerComponent(src)
    bir = BitsPerComponent(ref)

    Assert(isclip(src),              "oyster_Deringing: src has to be a video clip!")
    Assert(bi == 32,                 "oyster_Deringing: the sample type of src has to be single precision!")
    Assert(is444(src) || rgb,        "oyster_Deringing: subsampled stuff not supported!")
    Assert(isclip(ref),              "oyster_Deringing: ref has to be a video clip!")
    Assert(bir == 32,                "oyster_Deringing: the sample type of ref has to be single precision!")
    Assert(is444(ref) || isrgb(ref), "oyster_Deringing: subsampled stuff not supported!")
    Assert(isint(radius),            "oyster_Deringing: radius has to be an integer!")
    Assert(radius>1,                 "oyster_Deringing: radius has to be greater than 0!")
    Assert(isfloat(h),               "oyster_Deringing: h has to be a real number!")
    Assert(h>=0,                     "oyster_Deringing: h has to be greater than 0!")
#    Assert(isint(mse0) || isfloat(mse0), "oyster_Deringing: sad has to be a real number or None!")
#    Assert(isint(mse1) || isfloat(mse1), "oyster_Deringing: sad has to be a real number or None!")

    if (rgb) {
       src    = !fs ? src.SMPTE_legal(false).RGB_to_OPP() : src.RGB_to_OPP()
       ref    = ref
    }
    src       = AssumeFrameBased(src)
    ref       = AssumeFrameBased(ref)


    c1        = 0.1134141984932795312503328847998
    c2        = 2.8623043756241389436528021745239
    strength0 = h
    strength1 = h * pow(c1 * h, c2) * log(1.0 + 1.0 / pow(c1 * h, c2))

    function oy_loop(clip flt, clip init, clip src, int n, float strength0, float strength1, bool color) {
            strength2        = n * strength0 / 4. + strength1 * (1 - n / 4.)
            window           = int(32. / pow(2, n))
            flt              = n == 4 ? init : flt
            dif              = ex_makediff(src, flt)
            dif              = NLMeans(dif, 0, window, 1, strength2, flt, color)
            fnl              = ex_adddiff(flt, dif)
            n                = n - 1
            n == -1 ? fnl : oy_loop(fnl, init, src, n, strength0, strength1, color) }


    ref     = FreqMerge(src, ref, nmod(block_size,2) + 1, lowpass)
    dif     = ex_makediff(src, ref)
#    dif     = BM3D_CUDA(dif, ref, radius=radius, th_mse=mse0, hard_thr=hard_thr, sigma=sigma, \
#                         block_size=block_size, block_step=block_step, group_size=group_size, bm_range=bm_range, bm_step=bm_step, \
#                         ps_num=ps_num, ps_range=ps_range, ps_step=ps_step, matrix=matrix, fast=true, extractor_exp=6)
#    dif     = BM3D_CPU(dif, ref, radius=radius, sigma=sigma, block_step=block_step, bm_range=bm_range/3, ps_num=ps_num, ps_range=ps_range)
    dif     = BM3D_CUDA(dif, ref, radius=radius, sigma=sigma, block_step=block_step, bm_range=bm_range/3, ps_num=ps_num, ps_range=ps_range)
    dif     = BM3D_VAggregate(dif, radius)
    ref     = ex_adddiff(ref, dif)
    refined = oy_loop(ref, ref, src, 4, strength0, strength1, color)
#    bm3d    = BM3D_CUDA(refined, ref, radius=radius, th_mse=mse1, sigma=sigma, \
#                         block_size=block_size, block_step=block_step, group_size=group_size, bm_range=bm_range, bm_step=bm_step, \
#                         ps_num=ps_num, ps_range=ps_range, ps_step=ps_step, matrix=matrix, fast=true, extractor_exp=6)
    bm3d    = BM3D_CUDA(refined, ref, radius=radius, sigma=sigma, block_step=block_step, bm_range=bm_range/3, ps_num=ps_num, ps_range=ps_range)
    bm3d    = BM3D_VAggregate(bm3d, radius)
    bm3d    = FreqMerge(refined, bm3d, nmod(block_size,2) + 1, lowpass)
    clp     = oy_loop(bm3d, bm3d, refined, 4, strength0, strength1, color)

    clp     = rgb ? OPP_to_RGB(clp).SMPTE_legal(true) : clp
    return clp }



function oyster_Destaircase(clip src, clip ref, int "radius", float "sigma", float "mse0", float "mse1", float "hard_thr", int "block_size", int "block_step", int "group_size", int "bm_range", int "bm_step", int "ps_num", int "ps_range", int "ps_step", float "thr", float "elast", string "lowpass") {


    radius      = Default(radius,       6)
    sigma       = Default(sigma,     16.0)
#    mse0        = Default(mse0, sigma * 160.0 + 1200.0)
#    mse1        = Default(mse0, sigma * 120.0 + 800.0)
#    hard_thr    = Default(hard_thr,  3.2)
    block_size  = Default(block_size,   8)
    block_step  = Default(block_step,   1)
#    group_size  = Default(group_size, 32)
    bm_range    = Default(bm_range,    24)
#    bm_step     = Default(bm_step,     1)
    ps_num      = Default(ps_num,       2)
    ps_range    = Default(ps_range,     8)
#    ps_step     = Default(ps_step,     1)
    thr         = Default(thr,    0.03125)
    elast       = Default(elast, 0.015625)
    lowpass     = Default(lowpass, Format("0.0:{sigma} 0.48:1024.0 1.0:1024.0"))
    color       = !isy(src)

    rgb = isRGB(src)
    bi  = BitsPerComponent(src)
    bir = BitsPerComponent(ref)

    Assert(isclip(src),                    "oyster_Destaircase: src has to be a video clip!")
    Assert(bi == 32,                       "oyster_Destaircase: the sample type of src has to be single precision!")
    Assert(is444(src) || rgb,              "oyster_Destaircase: subsampled stuff not supported!")
    Assert(isclip(ref),                    "oyster_Destaircase: ref has to be a video clip!")
    Assert(bir == 32,                      "oyster_Destaircase: the sample type of ref has to be single precision!")
    Assert(is444(ref) || isrgb(ref),       "oyster_Destaircase: subsampled stuff not supported!")
    Assert(isint(radius),                  "oyster_Destaircase: radius has to be an integer!")
    Assert(radius>1,                       "oyster_Destaircase: radius has to be greater than 0!")
    Assert(isfloat(thr),                   "oyster_Destaircase: thr has to be a real number!")
    Assert(thr>=0 && thr<= 1,              "oyster_Destaircase: thr has to fall in [0, 1]!")
    Assert(isfloat(elast),                 "oyster_Destaircase: elast has to be a real number!")
    Assert(elast>=0 && elast<=thr,         "oyster_Destaircase: elast has to fall in [0, thr]!")
#   Assert(isfloat(mse0),                  "oyster_Destaircase: sad has to be a real number or None!")
#   Assert(isfloat(mse1),                  "oyster_Destaircase: sad has to be a real number or None!")

    if (rgb) {
       src    = !fs ? src.SMPTE_legal(false).RGB_to_OPP() : src.RGB_to_OPP()
       ref    = ref
    }
    src       = AssumeFrameBased(src)
    ref       = AssumeFrameBased(ref)

    msk       = ex_lutspa(ExtractY(src),mode="absolute",expr="x 1 + 8 % 1 < x 8 % 1 < y 1 + 8 % 1 < y 8 % 1 < | | | range_max 0 ?")
    ref       = FreqMerge(src, ref, nmod(block_size,2) + 1, lowpass)
    ref       = ThrMerge(src, ref, thr=thr, elast=elast)
    dif       = ex_makediff(src, ref)
#    dif       = BM3D_CUDA(dif, ref, radius=radius, th_mse=mse0, hard_thr=hard_thr, sigma=sigma, \
#                           block_size=block_size, block_step=block_step, group_size=group_size, bm_range=bm_range, bm_step=bm_step, \
#                           ps_num=ps_num, ps_range=ps_range, ps_step=ps_step, matrix=matrix, fast=true, extractor_exp=6)
    dif       = BM3D_CUDA(dif, ref, radius=radius, sigma=sigma, block_step=block_step, bm_range=bm_range/3, ps_num=ps_num, ps_range=ps_range)
    dif       = BM3D_VAggregate(dif, radius)
    ref       = ex_adddiff(ref, dif)
    dif       = ex_makediff(src, ref)
#    dif       = BM3D_CUDA(dif, ref, radius=radius, th_mse=mse1, sigma=sigma, \
#                           block_size=block_size, block_step=block_step, group_size=group_size, bm_range=bm_range, bm_step=bm_step, \
#                           ps_num=ps_num, ps_range=ps_range, ps_step=ps_step, matrix=matrix, fast=true, extractor_exp=6)
    dif       = BM3D_CUDA(dif, ref, radius=radius, sigma=sigma, block_step=block_step, bm_range=bm_range/3, ps_num=ps_num, ps_range=ps_range)
    dif       = BM3D_VAggregate(dif, radius)
    ref       = ex_adddiff(ref, dif)
    clp       = ex_merge(src, ref, msk, luma=true)

    clp       = rgb ? OPP_to_RGB(clp).SMPTE_legal(true) : clp
    return clp }



function oyster_Deblocking(clip src, clip ref, int "radius", float "h", float "sigma", float "mse0", float "mse1", float "hard_thr", int "block_size", int "block_step", int "group_size", int "bm_range", int "bm_step", int "ps_num", int "ps_range", int "ps_step", string "lowpass") {

    radius      = Default(radius,       6)
    h           = Default(h,          6.4)
    sigma       = Default(sigma,     16.0)
#    mse0        = Default(mse0, sigma * 160.0 + 1200.0)
#    mse1        = Default(mse0, sigma * 120.0 + 800.0)
#    hard_thr    = Default(hard_thr,  3.2)
    block_size  = Default(block_size,   8)
    block_step  = Default(block_step,   1)
#    group_size  = Default(group_size, 32)
    bm_range    = Default(bm_range,    24)
#    bm_step     = Default(bm_step,     1)
    ps_num      = Default(ps_num,       2)
    ps_range    = Default(ps_range,     8)
#    ps_step     = Default(ps_step,     1)
    lowpass     = Default(lowpass, "0.0:0.0 0.12:1024.0 1.0:1024.0")
    color       = !isy(src)

    rgb = isRGB(src)
    bi  = BitsPerComponent(src)
    bir = BitsPerComponent(ref)

    Assert(isclip(src),              "oyster_Deblocking: src has to be a video clip!")
    Assert(bi == 32,                 "oyster_Deblocking: the sample type of src has to be single precision!")
    Assert(is444(src) || rgb,        "oyster_Deblocking: subsampled stuff not supported!")
    Assert(isclip(ref),              "oyster_Deblocking: ref has to be a video clip!")
    Assert(bir == 32,                "oyster_Deblocking: the sample type of ref has to be single precision!")
    Assert(is444(ref) || isrgb(ref), "oyster_Deblocking: subsampled stuff not supported!")
    Assert(isint(radius),            "oyster_Deblocking: radius has to be an integer!")
    Assert(radius>1,                 "oyster_Deblocking: radius has to be greater than 0!")
    Assert(isfloat(h),               "oyster_Deblocking: h has to be a real number!")
    Assert(h>0,                      "oyster_Deblocking: h has to be greater than 0!")

    if (rgb) {
       src    = !fs ? src.SMPTE_legal(false).RGB_to_OPP() : src.RGB_to_OPP()
       ref    = ref
    }
    src      = AssumeFrameBased(src)
    ref      = AssumeFrameBased(ref)

    msk      = ex_lutspa(ExtractY(src),mode="absolute",expr="x 1 + 8 % 1 < x 8 % 1 < y 1 + 8 % 1 < y 8 % 1 < | | | range_max 0 ?")
    cleansed = NLMeans(ref, radius, block_size, ceil(block_size / 2.), h, ref, color)
    dif      = ex_makediff(ref, cleansed)
#    dif      = BM3D_CUDA(dif, cleansed, radius=radius, th_mse=mse0, hard_thr=hard_thr, sigma=sigma, \
#                          block_size=block_size, block_step=block_step, group_size=group_size, bm_range=bm_range, bm_step=bm_step, \
#                          ps_num=ps_num, ps_range=ps_range, ps_step=ps_step, matrix=matrix, fast=true, extractor_exp=6)
    dif      = BM3D_CUDA(dif, cleansed, radius=radius, sigma=sigma, block_step=block_step, bm_range=bm_range/3, ps_num=ps_num, ps_range=ps_range)
    dif      = BM3D_VAggregate(dif, radius)
    cleansed = ex_adddiff(cleansed, dif)
    dif      = ex_makediff(ref, cleansed)
#    dif      = BM3D_CUDA(dif, cleansed, radius=radius, th_mse=mse1, sigma=sigma, \
#                          block_size=block_size, block_step=block_step, group_size=group_size, bm_range=bm_range, bm_step=bm_step, \
#                          ps_num=ps_num, ps_range=ps_range, ps_step=ps_step, matrix=matrix, fast=true, extractor_exp=6)
    dif      = BM3D_CUDA(dif, cleansed, radius=radius, sigma=sigma, block_step=block_step, bm_range=bm_range/3, ps_num=ps_num, ps_range=ps_range)
    dif      = BM3D_VAggregate(dif, radius)
    cleansed = ex_adddiff(cleansed, dif)
    ref      = FreqMerge(cleansed, ref, nmod(block_size,2) + 1, lowpass)
    src      = FreqMerge(cleansed, src, nmod(block_size,2) + 1, lowpass)
    clp      = ex_merge(src, ref, msk, luma=True)

    clp      = rgb ? OPP_to_RGB(clp).SMPTE_legal(true) : clp
    return clp }





#####################################
#                                   #
#   HELPER FUNCTIONS for Oyster     #
#                                   #
#####################################


function FreqMerge(clip low, clip hi, int sbsize, string slocation) {
    hif = DFTTest(hi,  sbsize=sbsize, sstring=slocation, smode=0, sosize=0, tbsize=1, tosize=0, tmode=0, dither=1, threads=1)
    lof = DFTTest(low, sbsize=sbsize, sstring=slocation, smode=0, sosize=0, tbsize=1, tosize=0, tmode=0, dither=1, threads=1)
    clp = ex_makeadddiff(hi, hif, lof)
    return clp }


function NLMeans(clip src, int d, int a, int s, float h, clip rclip, bool color) {

    function duplicate(clip src, int d) {
        if (d > 0) {
                blank   = ex_lut(src.trim(0,-1), "0", UV=1, scale_inputs="none")
           for (i = 1, d, 1) {
                blank   = blank + blank
            }
           clp          = blank + src + blank
        } else {
           clp          = src
        }
        return clp }

    pad                 = AddBorders(src, a+s, a+s, a+s, a+s)
    pad                 = duplicate(pad, d)

    if (Defined(rclip)) {
       rclip            = AddBorders(rclip, a+s, a+s, a+s, a+s)
       rclip            = duplicate(rclip, d)
    } else {
       rclip            = Undefined()
    }

    nlm                 = KNLMeansCL(pad, d=d, a=a, s=s, h=h, channels=color ? "YUV" : "Y", wref=1.0, rclip=rclip)
    clp                 = Crop(nlm, a+s, a+s, -a-s, -a-s)

    return clp.trim(d,src.framecount()-d) }






#######################
###                 ###
###    redfordxx    ###
###                 ###
#######################

## MSUDeCor 0.1 by redfordxx
## MSU Smart Deblocking corrector (VDub plugin, only available in x86 architecture)
## LoadVirtualDubPlugin("C:\Program Files\Multimedia\Video\VirtualDub-MPEG2\plugins\MSU_Smart_Deblocking.vdf","MSU_Smart_Deblocking", 0)

function MSUDeCor(clip a, int "UV") {

    UV  = Default(UV, 3)
    mat = color_propGet(a)

    #d=t.ConvertToRGB32(matrix="rec709").MSU_Smart_Deblocking(1, 1, 1, 1, 0, 50, 50).ConvertBackToYUY2(matrix="rec709").ConvertToYV12() #use if MPEG2
    d  = a.ConvertToPlanarRGB(matrix=mat[4]).MSU_Smart_Deblocking(1, 1, 1, 1, 0, 50, 50).MatchClip(a)

    s1 = ex_makediff(d, a, UV=uv).ex_boxblur(1, mode="mean", UV=uv)

    ex_makediff(d, s1, UV=uv) }


############################
##
##    SmoothDeblock 0.3 by Redford (redfordxx) (23-05-2006)
##    Port to ExTools (WIP)
##
##    https://forum.doom9.org/showthread.php?t=111526
##
##    issues and todo's:
##        Find best averaging weight matrices for combining DCT shifts (=minimize artefacts at high quants and increase sharpness)
##        Find best smoothing of the adaptation mask clip or better, adaptationmask shouldnot be block oriented, but only detail oriented
##        Tuning and speed up
##
##
##    Remember SmoothD? I tried to figure out how it works and made similar script (that§s why I borrowed the name) but adaptive... and slow
##
##    I made shifted DCTFilter applications to remove high frequencies. This caused removing the blocking on original block borders (shifted into middles of the blocks) but introduced new blocking on the new borders. So, when I shift the clips back, I have (for example) four clips with blocking on diferent places. I merge the clips so that I take only the inner part of the block (without blocking edge).
##    For this I use weighting mask made by function WeightMatrixClip which is clip made of all the same 8x8 blocks with values 255 in the middle and going down to borders. Additional functionWeightMatrixSum delivers the average value of the mask clip which is later used to normalize the weighted average.
##    This all delivers function SmoothDeblockLayer and it is possible to choose the density, quant, weightmask.
##    density = number of shifts on each axis per 8pixels - possible values are 2 or 4. (so 4 means 16 shifts per 8x8 block), 4 produces sharper image and less artifacts on hi quants but is more than 4times slower than 2, which means only 4 shifts...)
##    quant = 0,...,7 number of coeficients removed by DCTfilter. 0 makes no change to the picture.
##    weightmask = WeightMatrixClip mask together with WeightMatrixSum controls how the shifted clips are merged.
##    So, SmoothDeblockLayer returns deblocked clip on certain quant.
##
##    I can have 7 different deblocked clips according to quant. I want to merge some of them depending on detail presence.
##
##    Then, my assumption (not 100% correct) was, blocking is where is hi quantization, so, let's detect the quantization. I detect the quantization with DCTFilter again on certain quant again. That's function QuantDiff. It produces the mask of "what could be removed with lowpass on certain quant".
##
##    From this mask, the function AdaptionMask produces mask for merging the deblocked "layers". It is just some values increasing, blockaveraging and blurring depending on given parameters. This is part wherer I am not sure. Now it is block oriented but maybe the mask should more precisely follow the detail of the clip.
##
##    Finally the SmoothDeblock function puts everything together. Now it is fixed for 3 deblocking layer, later is should be parametrizable.
##    It is pretty slow now and it will be probably always. I think still there is significant speedup possible when reorganizing the script, but I wanna keep the script structured like this until it is finished, to keep it a little readable.


function SmoothDeblock1(clip orig, int "passes", int "density", int "inclOrig", string "wieghtMX",string "dct_type",int "pregain",int "pregainoffset",int "gain",string "adaption_blursmall",string "adaption_blurbig") {

    passes        = 3#fixed for now
    inclOrig      = Default(inclOrig,1)
    density       = Default(density, 2)
    pregainoffset = Default(pregainoffset,0)
    pregain       = Default(pregain,10)
    gain          = Default(gain,   10)
    b1            = Default(adaption_blursmall,"1")
    b2            = Default(adaption_blurbig,"1 1 2 2 2 1 1")
    wieghtMX      = Default(wieghtMX,"04center255border0smooth_1")
    dct_type      = Default(dct_type,"DCTFilter")

    mx2=orig.AddBorders(16,16,0,0).WeightMatrixClip(wieghtMX)
    mxs=WeightMatrixSum(wieghtMX)

    sdl8=orig.LanczosResize(orig.width()/2,orig.height()/2)
    sdl8=((sdl8.width () % 32)==0) ? sdl8 : StackHorizontal(sdl8,sdl8.crop(  sdl8.width ()-32+(sdl8.width () % 32),0,-0,-0).FlipHorizontal())
    sdl8=((sdl8.height() % 32)==0) ? sdl8 : StackVertical  (sdl8,sdl8.crop(0,sdl8.height()-32+(sdl8.height() % 32),-0,-0  ).FlipVertical())
    sdl8=sdl8.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter",DCTorig=1)
    sdl8=sdl8.GaussResize(sdl8.width()*2,sdl8.height()*2,p=20).crop(0,0,orig.width(),orig.height())
    #sdl8=sdl8.ex_boxblur(1,mode="weighted",UV=3)
    sdl5=orig.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter")
    sdl3=orig.SmoothDeblockLayer(3,density,mx2,mxs,"DCTFilter")
    qd8=orig.QuantDiff(6)
    qd5=orig.QuantDiff(5)
    qdo=orig.QuantDiff(inclOrig)
    am8=qd8.AdaptionMask(pregain,pregainoffset,gain,b1,b2)
    am5=qd5.AdaptionMask(pregain,pregainoffset,gain,b1,b2)
    amo=qdo.AdaptionMask(pregain,pregainoffset,gain,b1,b2)

    deblocked=ex_merge(sdl8,sdl5,am8,UV=3)
    deblocked=ex_merge(deblocked,sdl3,am5,UV=3)
    deblocked=(inclOrig==0) ? deblocked : ex_merge(deblocked,orig,amo,UV=3)
    return(deblocked)
}


# SmoothDeblock2 - Different layers masking. Deblocking looks very nice and it's most succesful in deblocking. Detail retention is quite good, as long as the detail contrast is over certain level --- otherwise it just disappears
function SmoothDeblock2(clip orig, int "passes", int "density", int "inclOrig", string "wieghtMX",string "dct_type",int "pregain",int "pregainoffset",int "gain", int "thresh", string "adaption_blur") {

    passes   = 3#fixed for now
    inclOrig = Default(inclOrig,2)
    density  = Default(density,2)
    #pregainoffset= Default(pregainoffset,-2)
    #pregain= Default(pregain,100)
    #gain= Default(gain,30)
    #thresh= Default(thresh,1)
    #b2= Default(adaption_blurbig,"1 1 1")
    wieghtMX = Default(wieghtMX,(density==4) ? "16center255border0smooth_1" : "04center255border0smooth_1")
    dct_type = Default(dct_type,"DCTFilter")

    mx2=orig.AddBorders(16,16,0,0).WeightMatrixClip(wieghtMX)
    mxs=WeightMatrixSum(wieghtMX)

    sdl8=orig.LanczosResize(orig.width()/2,orig.height()/2)
    sdl8=((sdl8.width () % 32)==0) ? sdl8 : StackHorizontal(sdl8,sdl8.crop(  sdl8.width ()-32+(sdl8.width () % 32),0,-0,-0).FlipHorizontal())
    sdl8=((sdl8.height() % 32)==0) ? sdl8 : StackVertical  (sdl8,sdl8.crop(0,sdl8.height()-32+(sdl8.height() % 32),-0,-0  ).FlipVertical())
    sdl8=sdl8.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter",DCTorig=1)
    sdl8=sdl8.GaussResize(sdl8.width()*2,sdl8.height()*2,p=20).crop(0,0,orig.width(),orig.height())
    #sdl8=sdl8.ex_boxblur(1,mode="weighted",UV=3)
    sdl5=orig.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter")
    sdl3=orig.SmoothDeblockLayer(3,density,mx2,mxs,"DCTFilter")
    am8=orig.AdaptionMaskDiff(sdl8,6,pregain,pregainoffset,gain,thresh,adaption_blur,expands=5)
    am5=orig.AdaptionMaskDiff(sdl5,5,pregain,pregainoffset,gain,thresh,adaption_blur,expands=2)
    amo=orig.AdaptionMaskDiff(sdl3,inclOrig,pregain,pregainoffset,gain,thresh,adaption_blur,expands=1)

    deblocked=sdl8
    deblocked=ex_merge(deblocked,sdl5,am8,UV=3)
    deblocked=ex_merge(deblocked,sdl3,am5,UV=3)
    deblocked=(inclOrig==0) ? deblocked : ex_merge(deblocked,orig,amo,UV=3)
    return(deblocked)
}


# SmoothDeblock3 - Detail preservation and real border-edge preservation routine added.
function SmoothDeblock3(clip orig, int "passes", int "density", int "inclOrig", string "wieghtMX",string "dct_type",int "pregain",int "pregainoffset",int "gain", int "thresh", string "adaption_blur", int "bth1", int "bth2", int "bshare", int "eth1", int "eth2", int "eshare", float "buvmod", float "euvmod") {

    passes   = 3 #fixed for now
    inclOrig = Default(inclOrig,2)
    density  = Default(density,2)
    wieghtMX = Default(wieghtMX,(density==4) ? "16center255border0smooth_1" : "04center255border0smooth_1")
    dct_type = Default(dct_type,"DCTFilter")

    mx2=orig.AddBorders(16,16,0,0).WeightMatrixClip(wieghtMX)
    mxs=WeightMatrixSum(wieghtMX)
    bdm=orig.BorderMask(bth1, bth2, bshare, eth1, eth2, eshare)

    sdl8=orig.LanczosResize(orig.width()/2,orig.height()/2)
    sdl8=((sdl8.width () % 32)==0) ? sdl8 : StackHorizontal(sdl8,sdl8.crop(  sdl8.width ()-32+(sdl8.width () % 32),0,-0,-0).FlipHorizontal())
    sdl8=((sdl8.height() % 32)==0) ? sdl8 : StackVertical  (sdl8,sdl8.crop(0,sdl8.height()-32+(sdl8.height() % 32),-0,-0  ).FlipVertical())
    sdl8=sdl8.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter",DCTorig=1)
    sdl8=sdl8.GaussResize(sdl8.width()*2,sdl8.height()*2,p=20).crop(0,0,orig.width(),orig.height())
    #sdl8=sdl8.ex_boxblur(1,mode="weighted",UV=3)
    sdl5=orig.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter")
    sdl3=orig.SmoothDeblockLayer(3,density,mx2,mxs,"DCTFilter")
    am8=orig.AdaptionMaskDiff(sdl8,6,pregain,pregainoffset,gain,thresh,adaption_blur,expands=5).ex_lutxy(bdm,"range_max range_max x - y * range_max / -",UV=3)#   255-((255-x)*y)/255 = x+255-y-x*(255-y)/255
    am5=orig.AdaptionMaskDiff(sdl5,5,pregain,pregainoffset,gain,thresh,adaption_blur,expands=2).ex_lutxy(bdm,"range_max range_max x - y * range_max / -",UV=3)
    amo=orig.AdaptionMaskDiff(sdl3,inclOrig,pregain,pregainoffset,gain,thresh,adaption_blur,expands=1).ex_lutxy(bdm,"range_max range_max x - y * range_max / -",UV=3)

    deblocked=sdl8
    deblocked=ex_merge(deblocked,sdl5,am8,UV=3)
    deblocked=ex_merge(deblocked,sdl3,am5,UV=3)
    deblocked=(inclOrig==0) ? deblocked : ex_merge(deblocked,orig,amo,UV=3)
    return(deblocked)
}



function SmoothDeblock4(clip orig, int "passes", int "density", int "inclOrig", string "wieghtMX",string "dct_type",int "pregain",int "pregainoffset",int "gain",string "adaption_blursmall",string "adaption_blurbig", int "bth1", int "bth2", int "bshare", int "eth1", int "eth2", int "eshare", float "buvmod", float "euvmod") {

    passes        = 3 #fixed for now
    inclOrig      = Default(inclOrig,1)
    density       = Default(density,2)
    pregainoffset = Default(pregainoffset,0)
    pregain       = Default(pregain,10)
    gain          = Default(gain,10)
    b1            = Default(adaption_blursmall,"1")
    b2            = Default(adaption_blurbig,"1 1 2 2 2 1 1")
    wieghtMX      = Default(wieghtMX,"04center255border0smooth_1")
    dct_type      = Default(dct_type,"DCTFilter")

    mx2=orig.AddBorders(16,16,0,0).WeightMatrixClip(wieghtMX)
    mxs=WeightMatrixSum(wieghtMX)
    bdm=orig.BorderMask(bth1, bth2, bshare, eth1, eth2, eshare)

    sdl8=orig.LanczosResize(orig.width()/2,orig.height()/2)
    sdl8=((sdl8.width () % 32)==0) ? sdl8 : StackHorizontal(sdl8,sdl8.crop(  sdl8.width ()-32+(sdl8.width () % 32),0,-0,-0).FlipHorizontal())
    sdl8=((sdl8.height() % 32)==0) ? sdl8 : StackVertical  (sdl8,sdl8.crop(0,sdl8.height()-32+(sdl8.height() % 32),-0,-0  ).FlipVertical())
    sdl8=sdl8.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter",DCTorig=1)
    sdl8=sdl8.GaussResize(sdl8.width()*2,sdl8.height()*2,p=20).crop(0,0,orig.width(),orig.height())
    #sdl8=sdl8.ex_boxblur(1,mode="weighted",UV=3)
    sdl5=orig.SmoothDeblockLayer(5,density,mx2,mxs,"DCTFilter")
    sdl3=orig.SmoothDeblockLayer(3,density,mx2,mxs,"DCTFilter")
    qd8=orig.QuantDiff(6)
    qd5=orig.QuantDiff(5)
    qdo=orig.QuantDiff(inclOrig)
    am8=qd8.AdaptionMask(pregain,pregainoffset,gain,b1,b2).ex_lutxy(bdm,"range_max range_max x - y * range_max / -",UV=3)
    am5=qd5.AdaptionMask(pregain,pregainoffset,gain,b1,b2).ex_lutxy(bdm,"range_max range_max x - y * range_max / -",UV=3)
    amo=qdo.AdaptionMask(pregain,pregainoffset,gain,b1,b2).ex_lutxy(bdm,"range_max range_max x - y * range_max / -",UV=3)

    deblocked=ex_merge(sdl8,sdl5,am8,UV=3)
    deblocked=ex_merge(deblocked,sdl3,am5,UV=3)
    deblocked=(inclOrig==0) ? deblocked : ex_merge(deblocked,orig,amo,UV=3)
    return(deblocked)
}





#######################
###                 ###
###    jconklin     ###
###                 ###
#######################

###
#  SmoothD2c() Version a3
#  https://avisynth.nl/index.php/SmoothD2
#
#  Dependencies
#    ExTools
#    ResizersPack
#    SmoothD2       https://avisynth.nl/index.php/SmoothD2
#    aWarpSharp2    https://avisynth.nl/index.php/AWarpSharp2
#
###
#  RESTRICTIONS
#
#  The Input clip must be evenly divisible by 4 in both height and width.
#
###
#  ARGUMENTS
#
#  SmoothD2c() provides a wrapper around SmoothD2() that takes a clip with the luma deblocked and uses SmoothD2 to deblock the chroma.
#              The arguments quant, num_shift, Matrix, Qtype, and ZW  are the same as those in SmoothD2 and have the same defaults.
#              The arguments Cpr, cWarpToLuma and downSize are specific to SmoothD2c().
#
#              Cpr (0..8) Chroma Protection Strength. Provides control over chroma desaturation at low luma levels.
#                         It does so by building a SmoothD2 Zero Weight Mask "ZWmask".
#                         Low luma pixels map to high Zero weights in ZWMASK.
#                         Default 0 no protection
#                         8 strong protection.
#
#              cWarpToLuma (0...8) uses aWarpSharp2() to warp the chroma to the luma. Default 0 no warping 8 strong warping.
#                                  This will move the chroma from high luma areas toward strong low luma edges which is
#                                  useful to reduce chroma bleeding.
#                                  Places where the chroma has been moved from may be visibly desaturated.
#                                  NOTE: The SmoothD2c() argument Cpr will have NO effect on chroma desaturation caused by
#                                  cWarpToLuma.
#
#              downSize (1...4) This specifies how much the image should be shrunk before deblocking.
#                               Default 1 no downsizing.
#                                       2 reduce image to 1/2 it's original size before processing.
#                                       3 reduce image to 1/3 it's original size before processing.
#                                       4 reduce image to 1/4 it's original size before processing.
#                               This can be useful if you have really bad chroma blocking. see examples at
#                               https://sites.google.com/site/jconklin754smoothd2/home
#

###
#  GETTING STARTED
#
#  First all parameters default to reasonable values so SmoothD2c() should work, though it will provide only very weak deblocking.
#  The most important parameter is quant, which is the primary control of deblocking strength.
#  If you can not get as much deblocking as desired then try using a different Matrix.
#     Matrix 8, or Matrix 13-29
#  If you still can't get enough deblocking then try Qtype=2 or 4.
#  If you still can't get enough deblocking then increase downSize. For Qtype=1 you probably want a Matrix between 13-29.
#  When you get enough deblocking find an area, usually in a darker part of the picture, that the chroma has washed out and start increasing Cpr
#  until the chroma returns.  Its a balancing act between chroma washout and chroma deblocking.
#  When you have gotten this far and you have chroma bleeding around strong luma edges then you can try increasing cWarpToLuma
#  to see if it will help reduce it.  Note that cWarpToLuma especially at higher settings will tend to washout the chroma around the edges.
#  This chroma washout cannot be corrected by increasing Cpr.


###
# This routine takes a clip that has already had the luma deblocked and uses SmoothD2 to deblock the chroma.
# Defaults SmoothD2c(quant=3, num_shift=3, Matrix=3, Qtype=1, ZW=1, Cpr=0, cWarpToLuma=0, downSize=1, ncpu=1)
function SmoothD2c(clip clp, int "quant", int "num_shift", int "Matrix", int "Qtype", int "ZW", int "Cpr", int "cWarpToLuma", int "downSize", int "ncpu") {

    ow = width(clp)
    oh = height(clp)
    px = PixelType(clp)
    fs = propNumElements(clp,"_ColorRange")  > 0 ? \
         propGetInt     (clp,"_ColorRange") == 0 : false

    quant       = Default( quant,          3 )
    num_shift   = Default( num_shift,      3 )
    Matrix      = Default( Matrix,         3 )  # By default matrix 3 produces only vertical smoothing (bug?)
    Qtype       = Default( Qtype,          2 )
    ZW          = Default( ZW,             1 )
    Cpr         = Default( Cpr,            0 )  # Chroma Protection Strength aka Chroma Vampire Be Gone
    cWarpToLuma = Default( cWarpToLuma,    0 )
    downSize    = Default( downSize,       1 )
    ncpu        = Default( ncpu,           4 )

    Assert( quant       >= 1  &&  quant       <=  31, chr(10) + "SmoothD2c: 'quant' wrong value! [1-31]"           + chr(10))
    Assert( num_shift   >= 1  &&  num_shift   <=   4, chr(10) + "SmoothD2c: 'num_shift' wrong value! [1-4]"        + chr(10))
    Assert( Matrix      >= 1  &&  Matrix      <= 110, chr(10) + "SmoothD2c: 'Matrix' wrong value! [1-110]"         + chr(10))
    Assert( Qtype       >= 0  &&  Qtype       <=   4, chr(10) + "SmoothD2c: 'Qtype' wrong value! [0-4]"            + chr(10))
    Assert( ZW          >= 0  &&  ZW          <=  16, chr(10) + "SmoothD2c: 'ZW' wrong value! [1-16]"              + chr(10))
    Assert( Cpr         >= 0  &&  Cpr         <=   6, chr(10) + "SmoothD2c: 'Cpr' wrong value! [0-6]"              + chr(10))
    Assert( cWarpToLuma >= 0  &&  cWarpToLuma <=   8, chr(10) + "SmoothD2c: 'cWarpToLuma' wrong value! [0-8]"      + chr(10))
    Assert( downSize    >= 1  &&  downSize    <=   4, chr(10) + "SmoothD2c: 'downSize' wrong value! [1-4]"         + chr(10))
    Assert( ncpu        >= 1  &&  ncpu        <=   4, chr(10) + "SmoothD2c: 'ncpu' wrong value! [1-4]"             + chr(10))
    Assert( ow          ==        nmod(ow,4)        , chr(10) + "SmoothD2c: 'clip width'  must be a multiple of 4" + chr(10))
    Assert( oh          ==        nmod(oh,4)        , chr(10) + "SmoothD2c: 'clip height' must be a multiple of 4" + chr(10))


   sd1 = clp

   sd1 = (downSize    > 1) ? sd1.BicubicResize(nmod(ow/float(downSize),32,64), nmod(oh/float(downSize),32,64),-0.5,0.25) : sd1
   sd1 = (cWarpToLuma > 0) ? sd1.colorWarpToLuma(strength=cWarpToLuma)                                                   : sd1

   zw1 = (Cpr == 0)  ?  sd1.ex_Ylevels( 0, 1.0, 255, 0, 0, fs)  :  sd1.buildZmask(cpr=cpr)


   u2  = sd1.ShowU(pixel_type=px)
   v2  = sd1.ShowV(pixel_type=px)

   cw  = u2.width()
   ch  = u2.height()

   zwuv = zw1.BicubicResize(cw, ch,-0.5,0.25)

   u2  = u2.SmoothD2(quant=quant, num_shift=num_shift, Matrix=Matrix, Qtype=Qtype, ZW=ZW, ZWmask=zwuv, ncpu=ncpu)
   v2  = v2.SmoothD2(quant=quant, num_shift=num_shift, Matrix=Matrix, Qtype=Qtype, ZW=ZW, ZWmask=zwuv, ncpu=ncpu)

   u2 = (downSize > 1) ? u2.BicubicResize(nmod(ow/2), nmod(oh/2),-0.5,0.25) : u2
   v2 = (downSize > 1) ? v2.BicubicResize(nmod(ow/2), nmod(oh/2),-0.5,0.25) : v2

   sd1 = YToUV(u2, v2).MergeLuma(clp)

   return(sd1) }


/*
Getting Started:

First all parameters default to reasonable values so SmoothD2() should work, though it will provide only very weak deblocking. The most important parameter is quant, which is the primary control of deblocking strength. If you can get the amount of deblocking needed then try using the Zero Weight parameters to recover some detail. If you could not get as much deblocking as desired then try using a different Matrix. If you still can't get enough deblocking then try a different Qtype.

    SmoothD2 (clip clip, clip "ZWmask", int "quant", int "num_shift", int "Matrix", int "Qtype", int "ZW", int "ZWce", int "ZWlmDark", int "ZWlmBright", int "ncpu")

        clip  ZWmask = Null
            Zero Weight mask. This clip specifies the zero weight value to be applied to each pixel in the source clip. Any pixel values greater than 16 will be clipped to 16.


        int  quant = 3
            This parameter specifies the quantizer value used (1 to 31). Larger values mean stronger filtering.


        int  num_shift = 3
            Specifies the number of shifted versions used for filtering providing a speed vs. quality trade-off. A larger value is more accurate and time consuming.

                1 : Uses 4 shifted versions.
                2 : Uses 8 shifted versions.
                3 : Uses 16 shifted versions. Best speed vs. Quality
                4 : Uses 64 shifted versions

            If using num_shift = 1 there are not enough samples to eliminate "beat" artifacts when using Qtypes > 1. "Beat" artifacts may be visible for Qtype=2 with quant>16 or Qtype=4 with quant>9. The following table gives the quant values that may produce "beat" artifacts for Qtype=3 for each matrix.


nt  Matrix = 3
    Selects a prebuilt matrix to use (1 to 110). 1 thru 9 are either "standard" matrices that I found on the net or slightly modified versions of them. They are ordered according to their deblocking strength from weak to strong. They are the only ones with calibrated strengths which allows the ZW arguments to produce consistent results. Note Matrix is not used by used by Qtype’s 2 and 4 which use the built in h263 matrices.

        int  Qtype = 1

            Quant Type. Selects the type of quant-dequant processing that is used in the filtering. They are ordered by their deblocking strength from least strong to strongest. h263 intra and h263 inter, Qtype’s 2 and 4, ignore the matrix argument and use their own built in matrix.

                1 : mpeg intra
                2 : h263 intra
                3 : mpeg inter
                4 : h263 inter

            The intra in Qtypes 1 and 2 referes to the encoding done for I-Frames. The inter in Qtypes 3 and 4 refers to the encoding done for P-frames and B-Frames. See A Beginners Guide for MPEG2 Standard for a good introduction to mpeg coding. Different matrices are usually used when encoding I-Frames then when encoding P-Frames and B-Frames. All the information about how a particular frame was originally encoded, I-Frame, P-Frame, B-Frame, and Matrix value, has been lost by the time SmoothD2 is passed a frame to process, SmoothD2 does not do automatic intra-inter Qtype or matrix switching.


Zero Weight Arguments:

The Zero Weight arguments can be used to control the strength of filtering. The strength can be specified for the frame as a whole, by the distance from a macroblock edge, and at the individual pixel level. The strength can also be specified based upon the brightness of the pixel.
The ZW arguments control the filtering strength by changing the number of original unfiltered images added to the shifted and filtered images before they are averaged to produce the output image. Obviously the more unfiltered images that are added the less filtering will occur. Internally the amount of filtering is normalized so that the lowest value for an argument produces full filtering strength and the highest value produces virtually no filtering of the original image. For ZW values 1-16 this attempts to be independent of the quant, num_shift, Matrix (for Matrix values less then 10), and Qtype values. Internally, at each pixel location, each argument will produce a normalized value. The 4 normalized values are added and the result is clipped to the value that will produce almost zero filtering.

        int  ZW = 1
            Zero Weight (0 to 16). Specifies the relative weight of the non-shifted original image to the weight of the shifted and processed images. A higher value counteracts filtering but keeps more detail. This operates on the frame as a whole. Note that ZW values 1-16 are normalized so that the perceived effect of the reduction of filtering due to ZWremains constant when changes are made to quant, num_shift, Matrix (for Matrix values less then 10), and Qtype values. ZW=0 does not include the non-shifted original image in the output image and will produce the strongest filtering.


        int  ZWce = 1
            Zero Weight Center to Edge (1 to 20). This argument allows the center of all 8x8 macroblocks to have less filtering then the edge of the macroblock. The edge of the macroblock always receives the amount of filtering determined by the other arguments. This allows for less detail loss while maintaining strong deblocking. ZWce specifies the entry in a table which is used to determine the the processing strength from the center of a macroblock to its edge.

            There are 4 possible values that VP1, VP2 and VP3 can have.

                0 - Full filtering strength
                1 - Medium filtering strength
                2 - Low filtering strength
                3 - Almost zero filtering

            The values ZWce can take start from 1 which sets values VP1, VP2 and VP3 to 0 which means there is full filtering strength everywhere in the macroblock. As the values get larger the filtering gets stronger from the center outward. When ZWce equals 5 VP1, VP2 are 0 and VP3 is 4 which means the the center 4 pixels have no filtering applied (the source pixel values are copied to the output frame) and the rest of the pixels in the block are filtered at full strength. This will usually produce obvious artifacts.


        int  ZWlmDark = 0
            Zero Weight Luma Dark Value (0 to 255). The filter strength is reduced for any pixel value starting at ZWlmDark and reaching 0 filtering strength as the pixel value approaches 0. The filtering strength is reduced less at block boundaries. Values between 32-64 are a good place to start. This argument allows more detail to be retained in dark areas which might otherwise appear over smoothed. Obviously when setting this value it is important that the monitor you are working on displays dark grey to black with reasonable fidelity.


        int  ZWlmBright = 255
            Zero Weight Luma Bright Value (0 to 255). Any source pixel value that is = ZWlmBright will be filtered at the value specified by the ZW argument. This can be used to reduce bright spots that ZWce might otherwise let through. Values > 192 are a good place to start.


        int  ncpu = 1
            Number of cpu cores to use (1 to 4). The multithreading code path is completely bypassed if only 1 cpu is used.

*/



#############################################
#                                           #
#   HELPER FUNCTIONS for SmoothD2c          #
#                                           #
#############################################


###
#
#  This routine builds a zero Weight Mask
#  which is used to limit the strength of chroma
#  processing in dark areas.
#
# Defaults buildZmask(Cpr=1)
function buildZmask(clip clp, int "Cpr", bool "fulls") {

    Cpr = Default( Cpr, 1 )
    fs  = Default( fulls, false )

    clp.SmoothD2(quant=31, num_shift=4, Matrix=29, Qtype=1, ZW=0, ZWce=1, ZWlmDark=0, ZWlmBright=255, ncpu=1)
    ex_invert()
    ex_YlevelsS(90,1.01,240,0,255,fs) # This does a non linear range expansion see https://forum.doom9.org/showthread.php?t=79898
    msk = ex_invert()

    ZWmask = (Cpr ==  0)  ?  clp
\          : (Cpr ==  1)  ?  msk.ex_Ylevels(32, 60.0, 255,   8, 0, fs)
\          : (Cpr ==  2)  ?  msk.ex_Ylevels(32, 50.0, 255,  16, 0, fs)
\          : (Cpr ==  3)  ?  msk.ex_Ylevels(32, 30.0, 255,  16, 0, fs)
\          : (Cpr ==  4)  ?  msk.ex_Ylevels(32, 12.0, 255,  16, 0, fs)
\          : (Cpr ==  5)  ?  msk.ex_Ylevels(32,  7.0, 255,  16, 0, fs)
\          :                 msk.ex_Ylevels(32,  1.0, 255,  16, 0, fs)

    return ZWmask }



###
#
#  This routine moves the color information toward the edges in the luma
#
# Defaults colorWarpToLuma(strength=1)
function colorWarpToLuma(clip clp, int "strength") {

    strength = Default( strength, 1 )

    thresh = (strength ==  0)  ?    1
    \      : (strength ==  1)  ?   24
    \      : (strength ==  2)  ?   32
    \      : (strength ==  3)  ?   48
    \      : (strength ==  4)  ?   64
    \      : (strength ==  5)  ?   96
    \      : (strength ==  6)  ?  128
    \      : (strength ==  7)  ?  192
    \      :                      255

    blur = strength + 2

    warpedColor = clp.aWarpSharp2(thresh=thresh, blur=blur, type=1, depth=14, chroma=4)

    ex_merge(clp, clp, warpedColor, Y=2, UV=6) }


# Reminder: Yexpr = "x a - b a - / 1 gamma / ^ d c - * c +"
function ex_Ylevels(clip clp, int a, float gamma, int b, int c, int d, bool fs) {

    bi= clp.BitsPerComponent()
    a = ex_bs(a, 8, bi, fulls=fs)
    b = ex_bs(b, 8, bi, fulls=fs)
    c = ex_bs(c, 8, bi, fulls=fs)
    d = ex_bs(d, 8, bi, fulls=fs)

    wicked = Format("x {a} - {b} {a} - / 1 {gamma} / ^ {d} {c} - * {c} +")
    return clp.ex_lut(str = wicked, UV=1, fulls=fs) }


function ex_YlevelsS(clip clp, int a, float gamma, int b, int c, int d, bool fs) {

    bi= clp.BitsPerComponent()
    a = ex_bs(a, 8, bi, fulls=fs)
    b = ex_bs(b, 8, bi, fulls=fs)
    c = ex_bs(c, 8, bi, fulls=fs)
    d = ex_bs(d, 8, bi, fulls=fs)

    wicked = Format("x {a} - {b} {a} - / 1 {gamma} / ^ {d} {c} - * {c} + x 162.97466 / sin range_max * * x range_max x 162.97466 / sin range_max * - * + range_max /")
    return clp.ex_lut(str = wicked, UV=1, fulls=fs) }






#############################################
#                                           #
#   HELPER FUNCTIONS 1 for SmoothDeblock    #
#                                           #
#############################################

# https://forum.doom9.org/showthread.php?t=111526 redfordxx 23rd May 2006, 21:14

function SD_Matrix (clip clp, int "UV") {

    uv = Default(uv,3)

    unit=blankclip(clp,4,4,pixel_type="YV12")
    row=stackhorizontal( unit.ex_lut(y=0,UV=2),
        \                unit.ex_lut(y=-1,UV=2),
        \                unit.ex_lut(y=-2,UV=2),
        \                unit.ex_lut(y=-3,UV=2),
        \                unit.ex_lut(y=-4,UV=2),
        \                unit.ex_lut(y=-5,UV=2),
        \                unit.ex_lut(y=-6,UV=2),
        \                unit.ex_lut(y=-7,UV=2))
    square=stackvertical(row.ex_lut("x 0 +",UV=2),
        \                row.ex_lut("x  8 +",UV=2),
        \                row.ex_lut("x 16 +",UV=2),
        \                row.ex_lut("x 24 +",UV=2),
        \                row.ex_lut("x 32 +",UV=2),
        \                row.ex_lut("x 40 +",UV=2),
        \                row.ex_lut("x 48 +",UV=2),
        \                row.ex_lut("x 56 +",UV=2))
    block=square#.ex_lut("x 4 *",UV=2)
    block4=stackvertical(stackhorizontal(block,block),stackhorizontal(block,block)).pointresize(16,16)
    block4 = (uv!=3)    ? block4.ex_lut(UV=uv)
        \       : YtoUV(block4.crop(0,0,8,8),block4.crop(0,0,8,8),block4)

    return block4.trim(1,-1) }

function PtrnFormat(clip clp, clip form) {

    fh=form.height()
    fw=form.width()
    clp=StackHorizontal(clp,clp,clp,clp,clp,clp,clp,clp,clp,clp,clp)
    clp=StackVertical(clp,clp,clp,clp,clp,clp,clp,clp,clp)
    clp=(fw > 160) ? StackHorizontal(clp,clp,clp,clp) : clp
    clp=(fh > 128) ? StackVertical(clp,clp,clp,clp) : clp
    clp=(fw > 640) ? StackHorizontal(clp,clp,clp) : clp
    clp=(fh > 512) ? StackVertical(clp,clp,clp) : clp
    clp=clp.crop(0,0,fw,fh)

    return clp.loop(framecount(form)) }

function PtrnVertical(clip clp, int "uv", int "v0", int "v1", int "v2", int "v3", int "v4", int "v5", int "v6", int "v7") {

    v0     = Default(v0, 0)
    v1     = Default(v1,255-v0)
    v2     = Default(v2,v1)
    v3     = Default(v3,v2)
    v4     = Default(v4,v3)
    v5     = Default(v5,v2)
    v6     = Default(v6,v1)
    v7     = Default(v7,v0)

    mtrx=SD_Matrix(clp,uv)
    ptrn=ex_lutxy(mtrx,mtrx,Format("x 8 % 0 == {v0} {v1} ?"),UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 8 % 2 == {v2} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 8 % 3 == {v3} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 8 % 4 == {v4} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 8 % 5 == {v5} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 8 % 6 == {v6} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 8 % 7 == {v7} y ?"),   UV=uv)

    return ptrn.PtrnFormat(clp) }

function PtrnHorizontal(clip clp, int "uv", int "v0", int "v1", int "v2", int "v3", int "v4", int "v5", int "v6", int "v7") {

    v0     = Default(v0, 0)
    v1     = Default(v1,255-v0)
    v2     = Default(v2,v1)
    v3     = Default(v3,v2)
    v4     = Default(v4,v3)
    v5     = Default(v5,v2)
    v6     = Default(v6,v1)
    v7     = Default(v7,v0)

    mtrx=SD_Matrix(clp,uv)
    ptrn=ex_lutxy(mtrx,mtrx,Format("x 4 - 8 / 8 % 0 == {v0} {v1} ?"),UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 2 == {v2} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 3 == {v3} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 4 == {v4} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 5 == {v5} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 6 == {v6} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 7 == {v7} y ?"),   UV=uv)

    return ptrn.PtrnFormat(clp) }

function PtrnBlock(clip clp, int "uv", int "v0", int "v1", int "v2", int "v3") {

    v0     = Default(v0, 0)
    v1     = Default(v1,255-v0)
    v2     = Default(v2,v1)
    v3     = Default(v3,v2)

    mtrx=SD_Matrix(clp,uv)
    ptrn=ex_lutxy(mtrx,mtrx,Format("x 4 - 8 / 8 % 1 >= x 4 - 8 / 8 % 6 <= & x 8 % 1 >= x 8 % 6 <= & & {v1} {v0} ?"),UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 2 >= x 4 - 8 / 8 % 5 <= & x 8 % 2 >= x 8 % 5 <= & & {v2} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 3 >= x 4 - 8 / 8 % 4 <= & x 8 % 3 >= x 8 % 4 <= & & {v3} y ?"),   UV=uv)

    return ptrn.PtrnFormat(clp) }

function PtrnChess(clip clp, int "uv", int "v0", int "v1", int "v2", int "v3") {

    v0     = Default(v0, 0)
    v1     = Default(v1,255-v0)
    v2     = Default(v2,v0)
    v3     = Default(v3,v1)

    mtrx=SD_Matrix(clp,uv)
    ptrn=ex_lutxy(mtrx,mtrx,Format("x 4 - 8 / 2 % 0 == x 2 % 0 == & {v0} {v1} ?"),UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % 1 == x 2 % 1 == & {v2} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % 1 == x 2 % 0 == & {v3} y ?"),   UV=uv)

    return ptrn.PtrnFormat(clp) }

function PtrnSawH(clip clp, int "uv", string "shift", int "v0", int "v1", int "v2", int "v3", int "v4", int "v5", int "v6", int "v7") {

    Shift  = string(Default(Shift, 0))
    v0     = Default(v0, 0)
    v1     = Default(v1,255-v0)
    v2     = Default(v2,v1)
    v3     = Default(v3,v2)
    v4     = Default(v4,v3)
    v5     = Default(v5,255-v4)
    v6     = Default(v6,v5)
    v7     = Default(v7,v6)

    mtrx=SD_Matrix(clp,uv)
    ptrn=ex_lutxy(mtrx,mtrx,Format("x 4 - 8 / 8 % 0 == x 2 % "+shift+" 2 %  == & x 4 + 8 / 8 % 0 == x 1 + 2 % "+shift+" 2 % == & | {v0} {v1} ?"),UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 2 == x 2 % "+shift+" 2 %  == & x 4 + 8 / 8 % 2 == x 1 + 2 % "+shift+" 2 % == & | {v2} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 3 == x 2 % "+shift+" 2 %  == & x 4 + 8 / 8 % 3 == x 1 + 2 % "+shift+" 2 % == & | {v3} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 4 == x 2 % "+shift+" 2 %  == & x 4 + 8 / 8 % 4 == x 1 + 2 % "+shift+" 2 % == & | {v4} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 5 == x 2 % "+shift+" 2 %  == & x 4 + 8 / 8 % 5 == x 1 + 2 % "+shift+" 2 % == & | {v5} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 6 == x 2 % "+shift+" 2 %  == & x 4 + 8 / 8 % 6 == x 1 + 2 % "+shift+" 2 % == & | {v6} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 8 % 7 == x 2 % "+shift+" 2 %  == & x 4 + 8 / 8 % 7 == x 1 + 2 % "+shift+" 2 % == & | {v7} y ?"),   UV=uv)

    return ptrn.PtrnFormat(clp) }

function PtrnSawV(clip clp, int "uv", string "shift", int "v0", int "v1", int "v2", int "v3", int "v4", int "v5", int "v6", int "v7") {

    Shift  = string(Default(Shift, 0))
    v0     = Default(v0, 0)
    v1     = Default(v1,255-v0)
    v2     = Default(v2,v1)
    v3     = Default(v3,v2)
    v4     = Default(v4,v3)
    v5     = Default(v5,255-v4)
    v6     = Default(v6,v5)
    v7     = Default(v7,v6)

    mtrx=SD_Matrix(clp,uv)
    ptrn=ex_lutxy(mtrx,mtrx,Format("x 4 - 8 / 2 % "+shift+" 2 % == x 8 % 0 == & x 4 + 8 / 2 % "+shift+" 2 % == x 1 + 8 % 0 == & | {v0} {v1} ?"),UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % "+shift+" 2 % == x 8 % 2 == & x 4 + 8 / 2 % "+shift+" 2 % == x 1 + 8 % 2 == & | {v2} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % "+shift+" 2 % == x 8 % 3 == & x 4 + 8 / 2 % "+shift+" 2 % == x 1 + 8 % 3 == & | {v3} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % "+shift+" 2 % == x 8 % 4 == & x 4 + 8 / 2 % "+shift+" 2 % == x 1 + 8 % 4 == & | {v4} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % "+shift+" 2 % == x 8 % 5 == & x 4 + 8 / 2 % "+shift+" 2 % == x 1 + 8 % 5 == & | {v5} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % "+shift+" 2 % == x 8 % 6 == & x 4 + 8 / 2 % "+shift+" 2 % == x 1 + 8 % 6 == & | {v6} y ?"),   UV=uv)
    ptrn=ex_lutxy(mtrx,ptrn,Format("x 4 - 8 / 2 % "+shift+" 2 % == x 8 % 7 == & x 4 + 8 / 2 % "+shift+" 2 % == x 1 + 8 % 7 == & | {v7} y ?"),   UV=uv)

    return ptrn.PtrnFormat(clp)

}

# DCTFilter(1,0,0,0,0,0,0,0) is 40% faster (337fps on HBD)
#function AverageBlock8(clip orig) {

#    w = orig.width ()
#    h = orig.height()
#    fmtc_resample(orig,w/8,h/8,kernel="box").ConvertBits(BitsPerComponent(orig),dither=-1)
#    PointResize(w,h) }


function VerticalLinearBlock(clip orig)
{
    p1=PtrnHorizontal(orig,3,255,219,182,146,109,73,36,0)
    top1=orig.PointResize(orig.width(),nmod(orig.height()/8,2))
    top2=top1.PointResize(orig.width(),orig.height())
    shift1=orig.Expr("x[0,7]") # shifting up 7 pixels
    bottom1=shift1.PointResize(orig.width(),nmod(orig.height()/8,2))
    bottom2=bottom1.PointResize(orig.width(),orig.height())
    ex_merge(bottom2,top2,p1,UV=3)
}


function HorizontalLinearBlock(clip orig)
{
    p1=PtrnVertical(orig,3,255,219,182,146,109,73,36,0)
    top1=orig.PointResize(nmod(orig.width()/8,2),orig.height())
    top2=top1.PointResize(orig.width(),orig.height())
    shift1=orig.Expr("x[7,0]") # shifting left 7 pixels
    bottom1=shift1.PointResize(nmod(orig.width()/8,2),orig.height())
    bottom2=bottom1.PointResize(orig.width(),orig.height())
    ex_merge(bottom2,top2,p1,UV=3)
}


function ShiftDCTBack(clip orig,int density, clip wmc, float wms, string dct_type, int i, int j, int DCTorig, int "quant") {

    den_i = Int(8/density)*i
    den_j = Int(8/density)*j

    l=orig.crop(0,0,den_i+16,-0).FlipHorizontal()
    r=orig.crop(orig.width()-den_i-16,0,-0,-0).FlipHorizontal()
    cMain=(i==0) ? orig : StackHorizontal(l,orig,r)
    t=cMain.crop(0,0,0,den_j+16).FlipVertical()
    b=cMain.crop(0,orig.height()-den_j-16,0,-0).FlipVertical()
    idens = i*density+j

    cMain=(j==0) ? cMain : StackVertical(t,cMain,b)
    cMain=(i+j==0) ? orig : MergeChroma(cMain,cMain.AddBorders(den_i,den_j,0,0).Crop(0,0,cMain.width(),cMain.height()))
    cMain=(i==0) ? cMain : cMain.crop(16,0,orig.width()+16,0)
    cMain=(j==0) ? cMain : cMain.crop(0,16,0,orig.height()+16)
    cMain=((i+j==0)&&(DCTorig==0)) ? orig : (dct_type=="DCTFilterD") ? cMain.DCTFilterD(quant) : cMain.DCTFilter(DctParams7,DctParams6,DctParams5,DctParams4,DctParams3,DctParams2,DctParams1,DctParams0)
    cFlot=ex_lutxy(cMain,wmc,"x y * range_max %",UV=3)
    cMain=ex_lutxy(cMain,wmc,"x y * dup range_max % - range_max /",UV=3)
    cFlot=(i+j==0) ? cFlot : MergeChroma(cFlot,cFlot.AddBorders(0,0,den_i,den_j).Crop(den_i,den_j,cFlot.width(),cFlot.height()))
    cMain=(i+j==0) ? cMain : MergeChroma(cMain,cMain.AddBorders(0,0,den_i,den_j).Crop(den_i,den_j,cMain.width(),cMain.height()))
    shiftClip.Set(idens+Int(Pow(density,2)),(i+j==0) ? cFlot : cFlot.crop(den_i,den_j,orig.width(),orig.height()))
    shiftClip.Set(idens,                    (i+j==0) ? cMain : cMain.crop(den_i,den_j,orig.width(),orig.height()))
    global avgI = avgI+", shiftClip"+String(idens)+", 255.0/"+String(wms)
    global avgF = (i+j==0) ? avgF : avgF+", shiftClip"+String(idens+Int(Pow(density,2)))+", "+String(1/Pow(density,2))
}


function SmoothDeblockLayer(clip orig,float quant,int density, clip wmc, float wms, string "dct_type",int "DCTorig")
{
    global gDCTtype= Default(dct_type,"DCTFilter")    #fixed now
    global gDensity=density  #number of DCT per 8 pix
    global gOrig=orig
    global rep=wms*Pow(density,2)
    global q=Int(quant)
    global matrix1=wmc
    global avgI="clipAverageFloat, "+String(1/wms)
    global avgF="shiftClip"+String(Int(Pow(density,2)))+", "+String(1/Pow(density,2))
    global DCTO= Default(DCTorig,0)

    Dim("DctParams",8,0)
    Dim("shiftClip",Int(Pow(density,2))*2,Blackness())
    SimFor2("i=7","i>="+String(quant),"i=i-1",
    \"""
        DctParams.Set(i,1)
    """)
    SimFor2("i=0", "i<gDensity", "i=i+1",
    \"""
        SimFor2("j=0", "j<gDensity", "j=j+1",
        \"
    ShiftDCTBack(gOrig,gDensity,matrix1,rep,gDCTtype,i,j,DCTO,q)
        ")
    """)
    Eval("clipAverageFloat=Average("+avgF+")")
    Eval("Average("+avgI+")")
    #Subtitle(avgI)
}


function QuantDiff(clip orig,float "quant",string "dct_type") {

    dct_type = Default(dct_type,"DCTFilter")    #fixed now
    quant    = Default(quant,4)

    Dim("DctParams",8,0)
    SimFor2("i=7","i>="+String(quant),"i=i-1",
    \"""
        DctParams.Set(i,1)
    """)
    a=orig.DCTFilter(1,0,0,0,0,0,0,0) # 8x8 block average
    n=ex_makediff(orig,a,UV=3)
    d=n.DCTFilter(1,1-DctParams6,1-DctParams5,1-DctParams4,1-DctParams3,1-DctParams2,1-DctParams1,1-DctParams0)
    return d }


function AdaptionMask(clip orig,int "pregain",int "pregainoffset",int "gain",string "adaption_blursmall",string "adaption_blurbig") {

    pregainoffset      = Default(pregainoffset,-2)
    pregain            = Default(pregain,100)
    gain               = Default(gain,100)
    adaption_blursmall = Default(adaption_blursmall,"1")
    #adaption_blurbig  = Default(adaption_blurbig,"1 1 2 2 2 1 1")
    adaption_blurbig   = Default(adaption_blurbig,"1")

    o1=orig.ex_lut(Format("x range_half - abs x range_half == 0 {pregainoffset} ? + {pregain} *"),UV=3)
    o1=o1.ex_lut("x[0,0] x[1,0] x[2,0] x[3,0] x[4,0] x[5,0] x[6,0] x[7,0] + + + + + + + 0.125 *" ,UV=3).\
          ex_lut("x[0,0] x[0,1] x[0,2] x[0,3] x[0,4] x[0,5] x[0,6] x[0,7] + + + + + + + 0.125 *" ,UV=3).\
          AddBorders(0,0,(32 - (orig.width() % 32)) % 32,(32 - (orig.height() % 32)) % 32)

    o1=o1.pointresize(nmod(o1.width()/8,2),nmod(o1.height()/8,2))
    o1=(adaption_blursmall=="1")       ? o1                  : \
       (adaption_blursmall=="expand")  ? o1.ex_expand(UV=3)  : \
       (adaption_blursmall=="inpand")  ? o1.ex_inpand(UV=3)  : \
       (adaption_blursmall=="inflate") ? o1.ex_inflate(UV=3) : \
       (adaption_blursmall=="deflate") ? o1.ex_deflate(UV=3) : \
      o1.mt_convolution(adaption_blursmall,adaption_blursmall,UV=3)
    o1=o1.pointresize(o1.width()*8,o1.height()*8).Crop(0,0,orig.width(),orig.height())
    o1=(adaption_blurbig=="1") ? o1 : o1.mt_convolution(adaption_blurbig,adaption_blurbig,UV=3)
    o1=o1.ex_lut(Format("x {gain} *"),UV=3)
    return(o1)
}


function AdaptionMaskDiff(clip orig, clip deb,float "quant", int "pregain", int "pregainoffset", int "gain", int "thresh", string "adaption_blur", int "borders", int "expands" ,string "dct_type") {

    pregainoffset = Default(pregainoffset,-3)
    pregain       = Default(pregain,100)
    borders       = Default(borders,0)
    expands       = Default(expands,1)
    gain          = Default(gain,8)
    thresh        = Default(thresh,2)
    adaption_blur = Default(adaption_blur,"1 2 1")
    dct_type      = Default(dct_type,"DCTFilter")    #fixed now
    quant         = Default(quant,4)

    pregain5      = pregain/5.
    Dim("DctParams",8,0)
    SimFor2("i=7","i>="+String(quant),"i=i-1",
    \"""
        DctParams.Set(i,1)
    """)

    a=orig.DCTFilter(1,0,0,0,0,0,0,0) # 8x8 block average
    n=ex_makediff(orig,a,UV=3)
    d=n.DCTFilter(1,1-DctParams6,1-DctParams5,1-DctParams4,1-DctParams3,1-DctParams2,1-DctParams1,1-DctParams0)

    o1=d.ex_lut(Format("x range_half - abs x range_half == 0 {pregainoffset} ? + {pregain} *"),UV=3)
    o1=o1.DCTFilter(1,0,0,0,0,0,0,0) # 8x8 block average
    o1=o1.ex_lut(Format("x {pregain5} *"),UV=3)

    diff  = ex_makediff(deb,orig,UV=3)
    diff2 = ex_lutxy(o1,diff,Format("y range_half - x * range_max / abs {thresh} -"),UV=3)
    p1    = diff2.PtrnBlock(3,borders,255,255,255)
    diff3 = ex_lutxy(diff2,p1,Format("x y * range_max / {gain} *"),UV=3)
    diff4 = diff3.ex_expand(UV=3)
    (adaption_blur=="1") ? diff4 : diff4.mt_convolution(adaption_blur,adaption_blur,UV=3)
    ex_lut(Format("x {gain} *"),UV=3)
    (expands>0) ? ex_expand(expands,UV=3) : last
}


function WeightMatrixClip(clip orig, string "name",int "level") {

    level = Default(level,0)
    name  = Default(name,"04center255x2")
    clp   =orig.Crop(0,0,16,16).Trim(1,1)

    mx1 =  (name=="04all78")||(name=="04center255x2")||(name=="16center255") ? clp : clp.SD_Matrix(3).PtrnFormat(clp)
    mx  =  (name=="04center255border0smooth_1") ? clp.PtrnBlock(3,0,50,200,255)    : \
           (name=="16center255border0smooth_1") ? clp.PtrnBlock(3,0,70,185,255)    : \
           (name=="16center255border0smooth_2") ? clp.PtrnBlock(3,100,150,220,255) : clp
    #middle1
    mx  =   (name=="04all78")||(name=="04center255x2")||(name=="16center255") ? mx : ex_lutxy(mx,mx1,"y 12 == y 11 == y 25 == y 30 == y 33 == y 38 == y 51 == y 52 == | | | | | | | " + ( \
            (name=="04center255border0smooth_1") ? "55"  : \
            (name=="16center255border0smooth_1") ? "115" : \
            (name=="16center255border0smooth_2") ? "180" : "x") + " x ?",UV=3)
    #diag0
    #diag1
    mx  =   (name=="04all78")||(name=="04center255x2")||(name=="16center255") ? mx : ex_lutxy(mx,mx1,"y 9 == y 14 == y 54 == y 49 == | | | " + ( \
            (name=="04center255border0smooth_1") ? "25" : \
            (name=="16center255border0smooth_1") ? "20" : \
            (name=="16center255border0smooth_2") ? "130" : "x") + " x ?",UV=3)
    #diag2
    mx  =   (name=="04all78")||(name=="04center255x2")||(name=="16center255") ? mx : ex_lutxy(mx,mx1,"y 18 == y 21 == y 42 == y 45 == | | | " + ( \
            (name=="04center255border0smooth_1") ? "130" : \
            (name=="16center255border0smooth_1") ? "140" : \
            (name=="16center255border0smooth_2") ? "200" : "x") + " x ?",UV=3)

            (name=="16center255")   ? (clp.PtrnBlock(3,0,0,0,255))       : \
            (name=="04center255x2") ? (clp.PtrnBlock(3,0,0,255,255))     : \
            (name=="04all78")       ? (clp.PtrnBlock(3,150,150,212,212)) : mx
    #ex_lut(String(level)+" 255 "+String(level)+" - 255 / x * +",UV=3)
    PtrnFormat(orig) }

function WeightMatrixSum(string "name",int "level") {

    level = Default(level,0)
    l=  (name=="16center255")                ? (255.0/16)  : \
        (name=="04center255x2")              ? (255.0/4)   : \
        (name=="04center255border0smooth_1") ? (255.0/4)   : \
        (name=="16center255border0smooth_1") ? (1155.0/16) : \
        (name=="16center255border0smooth_2") ? (2385.0/16) : \
        (name=="04all78")                    ? (662.0/4)   : (255.0/4)
    #return((255.0-level)/255.0*l+level)
    l }


function BorderMask(clip orig, int "bth1", int "bth2", int "bshare", int "eth1", int "eth2", int "eshare", float "buvmod", float "euvmod") {

    bth1   = Default(bth1,0)
    bth2   = Default(bth2,2)
    bshare = Default(bshare,200)
    eth1   = Default(eth1,30)
    eth2   = Default(eth2,50)
    eshare = Default(eshare,0)  #0=real edge protection off
    buvmod = Default(buvmod,2.0)
    euvmod = Default(euvmod,2.4)

    eth12  = eth2 - eth1
    eth1d  = eth1/euvmod
    eth2d  = eth2/euvmod
    eth12d = eth2d - eth1d

    ph=orig.PtrnHorizontal(3,0,1,2,3,4,5,6,7)
    pv=orig.PtrnVertical(3,0,1,2,3,4,5,6,7)
    h1a=orig.ex_lutxy(ph,"y 0 == y 7 == | x range_half ?",UV=3)
    v1a=orig.ex_lutxy(pv,"y 0 == y 7 == | x range_half ?",UV=3)
    h1b=orig.ex_lutxy(ph,"y 1 == y 6 == | x range_half ?",UV=3)
    v1b=orig.ex_lutxy(pv,"y 1 == y 6 == | x range_half ?",UV=3)
    h2a=h1a.Expr("x[0,-1] x[0,1] + x[0,0] - ")
    v2a=v1a.Expr("x[-1,0] x[1,0] + x[0,0] - ")
    h2b=h1b.Expr("x[0,-2] x[0,0] x[0,2] + + x[0,-1] - x[0,1] - ")
    v2b=v1b.Expr("x[-2,0] x[0,0] x[2,0] + + x[-1,0] - x[1,0] - ")
    v2=ex_lutxy(v2a,v2b,"x range_half - y range_half - 3 / - abs x range_half - abs > x x y range_half - 3 / - ?",UV=3)
    h2=ex_lutxy(h2a,h2b,"x range_half - y range_half - 3 / - abs x range_half - abs > x x y range_half - 3 / - ?",UV=3)
    v3b=v2.ex_lutxy(pv,"y 0 == y 7 == | x range_half ? range_half - abs 5 * 1.1 * ",UV=3).ex_boxblur(0,1,mode="mean",UV=3)
    h3b=h2.ex_lutxy(ph,"y 0 == y 7 == | x range_half ? range_half - abs 5 * 1.1 * ",UV=3).ex_boxblur(1,0,mode="mean",UV=3)
    v3e0=v2a.ex_boxblur(0,4,mode="mean",UV=2).ex_boxblur(0,3,mode="mean",Y=2,UV=3)
    h3e0=h2a.ex_boxblur(4,0,mode="mean",UV=2).ex_boxblur(3,0,mode="mean",Y=2,UV=3)
    v3e=(eshare==0) ? orig : v3e0.ex_lutxy(pv,str=Format("y 0 == y 7 == | x range_half ? range_half - abs {eth1} - {eth12} / range_max *"), \
                         cstr =Format("y 0 == y 7 == | x range_half ? range_half - abs {eth1d} - {eth12d} / range_max *"),UV=3)
    h3e=(eshare==0) ? orig : h3e0.ex_lutxy(ph,str=Format("y 0 == y 7 == | x range_half ? range_half - abs {eth1} - {eth12} / range_max *"), \
                         cstr =Format("y 0 == y 7 == | x range_half ? range_half - abs {eth1d} - {eth12d} / range_max *"),UV=3)
    v4e =(eshare==0) ? orig : v3e.HorizontalLinearBlock
    h4e =(eshare==0) ? orig : h3e.VerticalLinearBlock
    e1  =(eshare==0) ? orig : ex_lutxy(v4e,h4e,"x y max",UV=3)
    e2  =(eshare==0) ? orig : e1.ex_lut(Format("range_max x - {eshare} * range_max / {eshare} - range_max +"),UV=3)
    v4b =(eshare==0) ? v3b  : v3b.ex_lutxy(v3e,"x y 1 + /",UV=3)
    h4b =(eshare==0) ? h3b  : h3b.ex_lutxy(h3e,"x y 1 + /",UV=3)
    v5b =v4b.HorizontalLinearBlock
    h5b =h4b.VerticalLinearBlock
    b1  =ex_lutxy(v5b,h5b,str=Format("x y max 5 / {bth1} - {bth2} {bth1} - / range_max *"), cstr=Format("x y max 5 / {bth1/buvmod} - {bth2/buvmod} {bth1/buvmod} - / range_max *"),UV=3)
    b2=b1.ex_boxblur(2,mode="mean",UV=3)
    b3=b2.ex_lut(Format("x {bshare} * range_max / {bshare} - range_max +"),UV=3)
    (eshare==0) ? b3 : ex_lutxy(e2,b3,"x y min",UV=3)
}





#############################################
#                                           #
#   HELPER FUNCTIONS 2 for SmoothDeblock    #
#                                           #
#############################################

# Updated by StainlessS (22-01-2020)
# https://forum.doom9.org/showthread.php?p=1896631#post1896631
#
# rb-array.avsi -- functions SimFor simulating arrays & loops in Avisynth 2.xx
#
# Last modified: 2006-02-05
#
# Written by Richard Berg and assigned to the public domain.
#

# Dim
#
#   Create a collection of global variables that can be manipulated similar to an array.  You can re-Dim
#   an existing array, but the contents will be cleared.  The type of the "initValue" parameter determines the type
#   of the array.  All Avisynth types are supported.
#
# PARAMETERS:
#           "arr"       :   Name of the array variable.  Pass this variable name to Deref and Set.
#           "size"      :   Size of the array; 0-based, like C/C++.  Dim("foo", 10) creates foo0-foo9.
#           "initValue" :   Each element is initialized to this value.  Its type determines the array type.  It uses SimFor
#                           internally, so initValue can be parametrized by 'i'.
#
# USAGE: see example.avs
#
function Dim(string arr, int size, val initValue)
{
    # create "base" string variable whose value is its name.  every Eval in internal array functions
    # needs this to build the element's name
    Eval("global " + arr + "=" + chr(34) + arr + chr(34))

    # store size so that Length() is O(1)
    Eval("global " + arr + "Length = " + string(size))

    # create each element
    global DimThunkVal = initValue   # thunk requires this in case it's a clip
    SimFor(0, "<="+string(size), "+1", arr + ".set(i, " + thunk(initValue, "DimThunkVal") + ")")
}

# DeRef
#
#   Gives you programmatic access to the "arrays" created by Dim
#
# USAGE: foo.deref(2+2)
#               ...is semantically equivalent* to foo[2+2] in C/C++
#               ...is syntactically equivalent to foo4 in Avisynth
#
#               *exception: the output of deref is NOT an lvalue.  If you need to assign something to
#                           an array element, use Set.
#
function DeRef(string arr, int index)
{
    Eval(arr + string(index))
}


# Set
#
#   Allows you to programmatically assign values to the "arrays" created by Dim
#
# USAGE: foo.set(i, i*2)
#               ...is semantically equivalent to foo[i] = i*2; in C/C++
#               ...is syntactically equivalent to fooI = i*2 in Avisynth
#
function Set(string arr, int index, val val)
{
    Eval("global " + arr + string(index) + "=" + thunk(val))
}

# Thunk
#
#   Makes a generic (untyped) parameter suitable for building Eval strings.
#
# PARAMETERS:
#       "clipName"  :   In order to assign clips to arrays with Eval, the rvalue has to be another Eval
#                       on a clip variable.  By Default, this variable is the parameter "val," as used
#                       in functions like Set.  However, if you are building an Eval string for use with
#                       For, you'll need to set a global variable that can be accessed inside the loop.  So
#                       as to not pollute the global namespace, you can create a unique variable name; pass
#                       it as 'clipName' to make Thunk work correctly.
#
#
function Thunk(val val, string "clipName")
{
    clipName = Default(clipName, "val")

    # string -> escape it
    # clip -> double-thunk it
    # everything else -> stringify it
    return val.IsString()
        \ ? chr(34) + val + chr(34)
        \ : val.IsClip()
            \ ? "Eval(" + chr(34) + clipName + chr(34) + ")"
            \ : string(val)
}

# Length
#
#   Returns the length of an "array" created by Dim
#
function Length(string arr)
{
    try {
        return Eval(arr + "Length")
    }
    catch (err_msg) {
        Throw("Length: the array " + arr + " was not created by Dim or is corrupt")
    }
}

# Length2
#
#   Returns the length of an "array" that was not created by Dim, or has had elements manipulated directly.  O(n) search.
#
# PARAMETERS:
#       "startIndex"    :   Start searching at this index.  Default = 0.  Note: elements lower than startIndex are
#                           not counted in the length calculation.
#
function Length2(string arr, int "startIndex")
{
    startIndex = Default(startIndex, 0)

    # store size in Dim-style global so we don't have to do this again
    Eval("global " + arr + "Length = " + string(Length2Loop(arr, startIndex)))
    return arr.length
}

function Length2Loop(string arr, int index)
{
    try {
        # note: using deref won't work - after the callstack unwinds, index will be lost
        Eval(arr + string(index))
        return Length2Loop(arr, index + 1)
    }
    catch (err_msg) {
        return index
    }
}

# Fill
#
#   Fill an array with values entered as a comma-delimited string literal.
#   (thanks to James "stickboy" Lin for the idea)
#
#
# USAGE: array.Fill("3, -50, 124")
#
# PARAMETERS:
#       "index"     :   Start writing values at this index.  Default is 0.
#       "string"    :   If true, fills the array with strings instead of parsing into values.  Default is false.
#
function Fill(string arr, string values, int "index", bool "string")
{
    index = Default(index, 0)
    string = Default(string, false)

    offset = FindStr(values, ",")
    # FindStr returns 0 if not found
    return (offset == 0)
        \ ? NOP
        \ : Eval("""
                element = LeftStr(values, offset - 1)
                element = string ? element : Value(element)
                arr.Set(index, element)
                arr.Fill(MidStr(values, offset + 1), index + 1)
            """)
}

# SimFor
#
#   A simple for-loop construct for Avisynth 2.xx
#
# USAGE: SimFor(1, "<=3", "+1", "global x = x*2" )
#               ...is semantically equivalent to for(int i=1, i<=3, i=i+1) { x = x*2 } in C/C++
#
# Notes:
#   -   with SimFor, the loop variable is always 'i', and the first parameter (its initial value) is always an int.  If you
#       want to use a custom loop variable (so you can nest loops, for instance, or have a floating-point counter) then use SimFor2.
#   -   any script variables you want manipulate inside the loop must be globals
#   -   corollary: you cannot use the implicit 'last' variable.  if you want to apply a filter inside the loop,
#       you must use assignment syntax.  Example: SimFor(0, "<=2", "+1", "global clip = clip.FFT3DFilter(sigma=2.5, plane=i)" )
#
function SimFor(int i, string cond, string iter, string block)
{
    return Eval("i" + cond)
        \ ? Eval("""
                Eval(block)
                SimFor(Eval("i" + iter), cond, iter, block)
            """)
        \ : NOP
}

# SimFor2
#
#   A more generalized for-loop construct for Avisynth 2.xx
#
# USAGE: SimFor("j=1", "j<=3", "j=j+1", "global x = x*2")
#               ...is semantically equivalent to SimFor(int j=1, j<=3, j=j+1) { x = x*2 } in C/C++
#
# Notes:
#   -   SimFor's guidelines about manipulating globals apply to SimFor2 as well.  In addition, the loop variable must
#       be a global (this is handled for you -- if this hack isn't sufficiently general, use SimFor2Loop directly).
#
function SimFor2(string init, string cond, string iter, string block)
{
    SimFor2Loop("global " + init, cond, "global " + iter, block)
}

function SimFor2Loop(string init, string cond, string iter, string block)
{
    Eval(init)
    return Eval(cond)
        \ ? Eval("""
                    Eval(block)
                    SimFor2Loop(iter, cond, iter, block)
                """)
        \ : NOP
}

# SimFor3
#
#   Same as SimFor, but implemented using SimFor2.  Mostly a proof of concept, but there's a practical difference: the
#   loop variable here is global, so nesting SimFor3's probably does weird things.
#
function SimFor3(int i, string cond, string iter, string block)
{
    SimFor2("i=" + string(i), "i" + cond, "i=i" + iter, block)
}

# While
#
#   A simple while-loop construct for Avisynth 2.xx
#
# USAGE: while(b, "DoSomething()")
#               ...is semantically equivalent to while(b) { DoSomething() } in C/C++
#
# Notes:
#   -   If you put it into an infinite loop, the host app will crash after several seconds.  An easy way to do this
#       is to forget to use 'global' when manipulating variables that affect 'cond' inside the loop.
#   -   I honestly don't think this is a very useful function.  Most of the time you want while()-like semantics, you
#       really want to operate on frames (not clips or other variables), in which case ConditionalFilter is the far
#       better choice.
#
function While(string cond, string block)
{
    SimFor2Loop("", cond, "", block)
}