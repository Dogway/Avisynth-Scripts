##################################################
###                                            ###
###              GrainFactory3mod              ###
###                                            ###
###      by 06_taro - astrataro@gmail.com      ###
###                                            ###
###            2012.04.06 v1.2 by 06_taro      ###
###            2020.04.06      by A.SONY.      ###
###            2023.03.03 ex   by Dogway       ###
###                                            ###
##################################################
###
### Luma adaptive grain generating filter. Y/YUV only.
###
### Based on Didée's GrainFactory3 script
###
###
### +-------------+
### |  CHANGELOG  |
### +-------------+
###
### 2023.03.03 ex
###      - Promote to AVS+ v3.7.3
###      - Fix bug in cstr=0 case
###      - Fix typo
###
### 2023.02.17 ex
###      - Added global settings as multipliers
###      - Parameter fit between global 'size' and 'gnstr' arguments
###      - Tuned defaults for more realistic starting point
###      - 'preblur' option
###      - Performance optimizations
###      - Reduced dependencies
###
### 2022.03.05 ex
###      - Update requirements
###
### 2022.02.17 ex
###      - Fix '_ColorRange' override
###
### 2022.02.16 ex
###      - Fix 'fulls' logic
###
### 2021.11.18 ex
###      - Update 'fulls' defaults
###
### 2021.10.18 ex
###      - Rebase with latest ResizersPack
###
### 2021.10.08 ex
###      - Rebase with latest ExTools
###      - Rename m4() to avoid dup name
###      - Disable blankclip audio track
###
### 2021.09.09 ex
###      - Remove Zs_RF_Shared dependency
###
### 2021.08.12 ex
###      - Update ex_bs()
###
### 2021.08.07 ex
###      - Minor edits
###
### 2021.07.14 ex
###      - Minor Expr edit
###
### 2021.07.02 ex
###      - Convolution optimization
###      - Resizers blur fix
###
### 2021.06.28 ex
###      - Expression optimizations
###
### 2021.06.22 ex
###      - Further old checks cleanup
###      - Rebased with latest ExTools
###
### 2021.05.27 ex
###      - Removed < AviSynth+ 3.5 support
###      - Replaced MaskTools2 with internal Expr() wrappers
###
### 2020.04.06
###      - HBD for avs+
###
### v1.2 - 06 April 2012
###      - Added support for generating f3kdb based grain ( set negative value for g*str to use f3kdb based grain )
###
### v1.1 - 13 March 2012
###      - Add chroma grain support
###      - Add RemoveGrain requirement
###      - Use float for "ontop_grain" instead of int
###      - Synchronize version number with GrainFactoryLite
###
### v0.3 - 28 May 2011
###      - Split "constant" into "g*const"
###
### v0.2 - 27 May 2011
###      - Use float for "g*str" instead of int
###
### v0.1 - 22 May 2011
###      - First release, able to generate completely constant grain
###
### +---------+
### |  USAGE  |
### +---------+
###
### GrainFactory3mod()
###
### See below for explanation of parameters
###
### +----------------+
### |  REQUIREMENTS  |
### +----------------+
###
### -> AddGrainC         [v1.8.4]
### -> neo_f3kdb         [r9]       (Optional)
### -> ExTools           [v10.0.0]
### -> ResizersPack      [v11.4.0]
###

function GrainFactory3mod(clip clp,
 \                        float "str",     float "cstr",    float "size",
 \                        float "g1str",   float "g2str",   float "g3str",
 \                        float "g1cstr",  float "g2cstr",  float "g3cstr",
 \                        int   "g1shrp",  int   "g2shrp",  int   "g3shrp",
 \                        float "g1size",  float "g2size",  float "g3size",
 \                        int   "g1tex",   int   "g2tex",   int   "g3tex",
 \                        bool  "g1const", bool  "g2const", bool  "g3const",
 \                        int   "th1",     int   "th2",     int   "th3",    int "th4",
 \                        int   "temp_avg",  bool "preblur",
 \                        float "ontop_grain",
 \                        float "ontop_cgrain",
 \                        bool  "ontop_const",
 \                        bool  "tv_range",
 \                        bool  "use_sAverageLumaMask" )
{

Assert(IsVersionOrGreater(3,7,3), "GrainFactory3mod: Update AviSynth+ version")

    w            = width (clp)
    h            = height(clp)
    isHD         = w > 1099 || h >  599
    isUHD        = w > 2599 || h > 1499
    sz           = (isHD ? 1920 : isUHD ? 3840 : 1280)/1920.

    #  Global multipliers for dark/mid/bright parameters
    #  By default 1.0, 1.0, 1.0, 1.0 is designed for 1080p content
    #  But scales by default from source dimensions when not defined explicitly

    sz           = Default(   size,     sz )

    st           = Default(    str,    1.0 )*0.63*pow(sz,-2.3)+0.37

    cs           = Defined(   cstr ) ? cstr *0.63*pow(sz,-2.3)+0.37 : st

    #-----------------------------------------------------------------------------------

    g1str        = Default( g1str,     3.5 )*st  # [ 0 - ???] strength of luma grain / for dark areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g2str        = Default( g2str,     4.0 )*st  # [ 0 - ???] strength of luma grain / for midtone areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g3str        = Default( g3str,     3.0 )*st  # [ 0 - ???] strength of luma grain / for bright areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g1cstr       = Default( g1cstr,    2.0 )*cs  # [ 0 - ???] strength of chroma grain / for dark areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g2cstr       = Default( g2cstr,    1.0 )*cs  # [ 0 - ???] strength of chroma grain / for midtone areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g3cstr       = Default( g3cstr,    0.5 )*cs  # [ 0 - ???] strength of chroma grain / for bright areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g1shrp       = Default( g1shrp,     60 )     # [ 0 - 100] sharpness of grain / for dark areas (NO EFFECT when g1size=1.0 !!)
    g2shrp       = Default( g2shrp,     80 )     # [ 0 - 100] sharpness of grain / for midtone areas (NO EFFECT when g2size=1.0 !!)
    g3shrp       = Default( g3shrp,     90 )     # [ 0 - 100] sharpness of grain / for bright areas (NO EFFECT when g3size=1.0 !!)
    g1size       = Default( g1size,   0.90 )*sz  # [0.5 - 4.0] size of grain / for dark areas
    g2size       = Default( g2size,   1.17 )*sz  # [0.5 - 4.0] size of grain / for mid-tone areas
    g3size       = Default( g3size,   1.05 )*sz  # [0.5 - 4.0] size of grain / for bright areas
    g1tex        = Default( g1tex,       0 )     # [ 0 - 100] strength of "material texture" appearance
    g2tex        = Default( g2tex,       0 )     # [ 0 - 100] (in fact: 'bump' effect)
    g3tex        = Default( g3tex,       0 )     # [ 0 - 100] for dark / midtone / bright grain
    g1const      = Default( g1const, false )     # AddGrainC "constant" parameter of grain / for dark areas
    g2const      = Default( g2const, false )     # AddGrainC "constant" parameter of grain / for midtone areas
    g3const      = Default( g3const, false )     # AddGrainC "constant" parameter of grain / for bright areas
    tmpavg       = Default( temp_avg,    1 )/100.# [ 0 - 100] percentage of noise's temporal averaging (NO EFFECT when g1const=g2const=g3const=true !!)
    th1          = Default( th1,        45 )     # start of dark    -> midtone mixing zone
    th2          = Default( th2,        85 )     # end  of  dark    -> midtone mixing zone
    th3          = Default( th3,       135 )     # start of midtone -> bright  mixing zone
    th4          = Default( th4,       195 )     # end  of  midtone -> bright  mixing zone
    ontop_grain  = Default( ontop_grain, 0 )     # [ 0 - ???] additional luma grain to put on top of prev. generated grain
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    ontop_cgrain = Default( ontop_cgrain,0 )     # [ 0 - ???] additional chroma grain to put on top of prev. generated grain
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    ontop_const  = Default( ontop_const, false)  # AddGrainC "constant" parameter of ontop clip
    use_ALMask   = Default( use_sAverageLumaMask, false)
    pb           = Default( preblur,st>=1.0 )

    rgb = isRGB(clp)
    fs  = propNumElements(clp,"_ColorRange")  > 0 ? \
          propGetInt     (clp,"_ColorRange") == 0 : rgb
    tv  = Default( tv_range, !fs)

    #-----------------------------------------------------------------------------------

    bi   = BitsPerComponent(clp)
    o    = pb ? clp.ex_boxblur(0.15,mode="weighted",UV=1) : clp

    sx1  = nmod(w/float(g1size),4)
    sy1  = nmod(h/float(g1size),4)
    sx1a = nmod((w+sx1)/2.0,    4)
    sy1a = nmod((h+sy1)/2.0,    4)
    sx2  = nmod(w/float(g2size),4)
    sy2  = nmod(h/float(g2size),4)
    sx2a = nmod((w+sx2)/2.0,    4)
    sy2a = nmod((h+sy2)/2.0,    4)
    sx3  = nmod(w/float(g3size),4)
    sy3  = nmod(h/float(g3size),4)
    sx3a = nmod((w+sx3)/2.0,    4)
    sy3a = nmod((h+sy3)/2.0,    4)


    c1   = clamp(g1shrp,0,100) / 100.
    c2   = clamp(g2shrp,0,100) / 100.
    c3   = clamp(g3shrp,0,100) / 100.
    b1   = 1.0-2*c1
    b2   = 1.0-2*c2
    b3   = 1.0-2*c3
    c1a  = 0.5*c1+0.25
    c2a  = 0.5*c2+0.25
    c3a  = 0.5*c3+0.25
    b1a  = 0.5-c1
    b2a  = 0.5-c2
    b3a  = 0.5-c3

    hlf  = ex_bs(128,             8, bi, fulls=!tv)
    T1a  = ex_bs(int(g1tex*1.28), 8, bi, fulls=!tv)
    T2a  = ex_bs(int(g2tex*1.28), 8, bi, fulls=!tv)
    T3a  = ex_bs(int(g3tex*1.28), 8, bi, fulls=!tv)

    hlfr = 1. / hlf
    T1ah = hlf-T1a
    T2ah = hlf-T2a
    T3ah = hlf-T3a

    th1str = ex_bs(th1, 8, bi, tv_in=true, tv_out=tv)
    th2str = ex_bs(th2, 8, bi, tv_in=true, tv_out=tv)
    th3str = ex_bs(th3, 8, bi, tv_in=true, tv_out=tv)
    th4str = ex_bs(th4, 8, bi, tv_in=true, tv_out=tv)
    MX     = ex_bs(255, 8, bi, fulls=true, flt=true)

    chroma  = !( (g1cstr + g2cstr + g3cstr) == 0 )
    ochroma = ( ontop_cgrain != 0 ) || chroma ? 3 : 2
    cchroma = chroma ? 3 : 1

    #-----------------------------------------------------------------------------------

    BUMPKERNEL1 = Format("x[-1,1] {T1a} * x[0,0] {T1ah} * - {hlfr} *")
    BUMPKERNEL2 = Format("x[-1,1] {T2a} * x[0,0] {T2ah} * - {hlfr} *")
    BUMPKERNEL3 = Format("x[-1,1] {T3a} * x[0,0] {T3ah} * - {hlfr} *")

    #-----------------------------------------------------------------------------------

    grainlayer1 = blankclip(o, width=sx1, height=sy1, color_yuv=$808080, channels=0)
    grainlayer1 = (g1str>0   || g1cstr>0)   ? grainlayer1.AddGrainC(g1str>0?g1str:0, g1cstr>0?g1cstr:0, 0, 0, constant=g1const)
    \           : grainLayer1
    grainLayer1 = (g1str<=-1 || g1cstr<=-1) ? grainLayer1.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g1str<=-1?Int(-g1str):0, grainC=g1cstr<=-1?Int(-g1cstr):0, dynamic_grain=!g1const, random_algo_grain=1)
    \           : grainLayer1

    grainlayer1 = (g1tex==0)
    \           ? grainlayer1
    \           : ex_makediff(grainlayer1,grainlayer1.ex_edge(mode=BUMPKERNEL1, lo=0, hi=255, UV=cchroma), UV=cchroma, fulls=!tv)

    grainlayer1 = (g1size == 1.0 || sx1==w && sy1==h) ? grainlayer1
    \           : (g1size > 1.5) ? grainlayer1.bicubicresize(sx1a,sy1a, b1a,c1a).bicubicresize(w,h, b1a,c1a)
    \                            : grainlayer1.bicubicresize(w,h, b1,c1)


    #-----------------------------------------------------------------------------------

    grainlayer2 = blankclip(o, width=sx2, height=sy2, color_yuv=$808080, channels=0)
    grainlayer2 = (g2str>0   || g2cstr>0)   ? grainlayer2.AddGrainC(g2str>0?g2str:0, g2cstr>0?g2cstr:0, 0, 0, constant=g2const)
    \           : grainLayer2
    grainLayer2 = (g2str<=-1 || g2cstr<=-1) ? grainLayer2.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g2str<=-1?Int(-g2str):0, grainC=g2cstr<=-1?Int(-g2cstr):0, dynamic_grain=!g2const, random_algo_grain=1)
    \           : grainLayer2

    grainlayer2 = (g2tex==0)
    \           ? grainlayer2
    \           : ex_makediff(grainlayer2,grainlayer2.ex_edge(mode=BUMPKERNEL2, lo=0, hi=255, UV=cchroma), UV=cchroma, fulls=!tv)

    grainlayer2 = (g2size==1.0 || sx2==w && sy2==h) ? grainlayer2
    \           : (g2size > 1.5) ? grainlayer2.bicubicresize(sx2a,sy2a, b2a,c2a).bicubicresize(w,h, b2a,c2a)
    \                            : grainlayer2.bicubicresize(w,h, b2,c2)

    #-----------------------------------------------------------------------------------

    grainlayer3 = blankclip(o, width=sx3, height=sy3, color_yuv=$808080, channels=0)
    grainlayer3 = (g3str>0   || g3cstr>0)   ? grainlayer3.AddGrainC(g3str>0?g3str:0, g3cstr>0?g3cstr:0, 0, 0, constant=g3const)
    \           : grainLayer3
    grainLayer3 = (g3str<=-1 || g3cstr<=-1) ? grainLayer3.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g3str<=-1?Int(-g3str):0, grainC=g3cstr<=-1?Int(-g3cstr):0, dynamic_grain=!g3const, random_algo_grain=1)
    \           : grainLayer3

    grainlayer3 = (g3tex==0)
    \           ? grainlayer3
    \           : ex_makediff(grainlayer3,grainlayer3.ex_edge(mode=BUMPKERNEL2, lo=0, hi=255, UV=cchroma), UV=cchroma, fulls=!tv)

    grainlayer3 = (g3size==1.0 || sx3==w && sy3==h) ? grainlayer3
    \           : (g3size > 1.5) ? grainlayer3.bicubicresize(sx3a,sy3a, b3a,c3a).bicubicresize(w,h, b3a,c3a)
    \                            : grainlayer3.bicubicresize(w,h, b3,c3)

    #-----------------------------------------------------------------------------------

    th21str = MX / (th1str - th2str)
    th43str = MX / (th3str - th4str)

    one  = tmpavg   == 0  || ( g1const && g2const && g3const )
    two  = ontop_grain>0  ||  ontop_cgrain>0
    thre = !one || two
    ex   = ex_dlut(Format("x dup y - a {th1str} - {th21str} * neg range_max / 0 1 clip * -
                             dup z - a {th3str} - {th43str} * neg range_max / 0 1 clip * - ") \
       +(thre ? (chroma ? "b" : "a")+" swap - range_half +" : ""), bi, !tv)

    grainlayer = Eval("""Expr(grainlayer1, grainlayer2, grainlayer3, chroma ? mskY_to_YYY(o,o) : o, """+(chroma ? "o," : "")+""" ex, chroma ? ex : "a") """)

    grainlayer = one    ? grainlayer
    \          : chroma ? grainlayer.merge(    grainlayer.temporalsoften(1,255,255,255,2), tmpavg)
    \          :          grainlayer.mergeluma(grainlayer.temporalsoften(1,255,  0,255,2), tmpavg)
    grainlayer = two    ? grainlayer.AddGrainC(ontop_grain>0?ontop_grain:0, ontop_cgrain>0?ontop_cgrain:0, 0, 0, constant=ontop_const)
    \          :          grainLayer
    grainLayer = ( ontop_grain<=-1 || ontop_cgrain<=-1 ) ? grainLayer.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=ontop_grain<=-1?Int(-ontop_grain):0, grainC=ontop_cgrain<=-1?Int(-ontop_cgrain):0, dynamic_grain=!ontop_const, random_algo_grain=1)
    \          : grainLayer

    #-----------------------------------------------------------------------------------

    result = thre ? grainlayer : ex_lutxy(o, grainlayer, "x y - range_half +", UV=ochroma, fulls=!tv)
    msk    = o.ScriptClip( function[] () { ex_lut(string(AverageLuma(last)),UV=1) } )

    use_ALMask ? ex_merge(result, o, msk, luma=chroma, UV=ochroma) : result }
