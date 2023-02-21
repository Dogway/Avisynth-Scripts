##################################################
###                                            ###
###                  FilmGrain                 ###
###         a GrainFactory3mod refactor        ###
###                                            ###
###            2023.02.17 mx   by Dogway       ###
###                                            ###
##################################################
###
### Luma adaptive grain generating filter. Y/YUV only.
###
### GrainFactory3 and its mod are based on Didée's GrainFactory3 script
###
###
### +-------------+
### |  CHANGELOG  |
### +-------------+
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
### -> ExTools           [v10.0.0]
### -> ResizersPack      [v11.2.0]
### -> vsTCanny          [v1.1.8]
###

function LumaGrain       (clip clp,
 \                        float "str",     float "cstr",    float "size",  float "coarse",
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

Assert(IsVersionOrGreater(3,7,2), "GrainFactory3mod: Update AviSynth+ version")

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

    ##################################

    crs          = Default(   coarse,  0.0 )     # Increase for more grain-like (rounded) noise

    g1str        = Default( g1str,     2.0 )*st  # [ 0 - ???] strength of luma grain / for dark areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g2str        = Default( g2str,     4.0 )*st  # [ 0 - ???] strength of luma grain / for midtone areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g3str        = Default( g3str,     4.0 )*st  # [ 0 - ???] strength of luma grain / for bright areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g1cstr       = Default( g1cstr,    4.0 )*cs  # [ 0 - ???] strength of chroma grain / for dark areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g2cstr       = Default( g2cstr,    3.0 )*cs  # [ 0 - ???] strength of chroma grain / for midtone areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g3cstr       = Default( g3cstr,    1.0 )*cs  # [ 0 - ???] strength of chroma grain / for bright areas
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    g1size       = Default( g1size,   0.90 )*sz  # [0.5 - 4.0] size of grain / for dark areas
    g2size       = Default( g2size,   1.17 )*sz  # [0.5 - 4.0] size of grain / for mid-tone areas
    g3size       = Default( g3size,   1.25 )*sz  # [0.5 - 4.0] size of grain / for bright areas
    g1tex        = Default( g1tex,       0 )     # [ 0 - 100] strength of "material texture" appearance
    g2tex        = Default( g2tex,       0 )     # [ 0 - 100] (in fact: 'bump' effect)
    g3tex        = Default( g3tex,       0 )     # [ 0 - 100] for dark / midtone / bright grain
    g1const      = Default( g1const, false )     # AddGrainC "constant" parameter of grain / for dark areas
    g2const      = Default( g2const, false )     # AddGrainC "constant" parameter of grain / for midtone areas
    g3const      = Default( g3const, false )     # AddGrainC "constant" parameter of grain / for bright areas
    tmpavg       = Default( temp_avg,    1 )/100.# [ 0 - 100] percentage of noise's temporal averaging (NO EFFECT when g1const=g2const=g3const=true !!)
    th1          = Default( th1,        45 )     # start of dark->midtone  mixing zone
    th2          = Default( th2,        85 )     # end  of  dark->midtone  mixing zone
    th3          = Default( th3,       135 )     # start of midtone->bright  mixing zone
    th4          = Default( th4,       195 )     # end  of  midtone->bright  mixing zone
    ontop_grain  = Default( ontop_grain, 0 )     # [ 0 - ???] additional luma grain to put on top of prev. generated grain
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    ontop_cgrain = Default( ontop_cgrain,0 )     # [ 0 - ???] additional chroma grain to put on top of prev. generated grain
                                                 # positive value for AddGrainC strength, negative value for f3kdb grain strength
    ontop_const  = Default( ontop_const, false)  # AddGrainC "constant" parameter of ontop clip
    use_ALMask   = Default( use_sAverageLumaMask, false)
    pb           = Default( preblur,st>=1.0 )

    rgb = isRGB(clp)
    fs  = propNumElements (clp,"_ColorRange")  > 0 ? \
          propGetInt      (clp,"_ColorRange") == 0 : rgb
    tv  = Default( tv_range, !fs)

    #-----------------------------------------------------------------------------------

    bi   = BitsPerComponent(clp)
    o    = pb ? clp.ex_boxblur(0.15,mode="weighted",UV=1) : clp

    # Grain coarseness
    g  = 1+crs
    g4 = g > 1 ? g*4 : 1
    gp = pow(g,0.05)
    g1size = (g1size-1)/2.+1
    g2size = (g2size-1)/2.+1
    g3size = (g3size-1)/2.+1

    # AddGrainC size
    g1sz = (g1size/10.) / g4
    g2sz = (g2size/10.) / g4
    g3sz = (g3size/10.) / g4

    # AddGrainC stddev fix for size change
    g1str  = max(1,-26.91*pow(g1size,-2.52)+12.68)*1.78*g1str  * gp
    g2str  = max(1,-26.91*pow(g2size,-2.52)+12.68)*1.78*g2str  * gp
    g3str  = max(1,-26.91*pow(g3size,-2.52)+12.68)*1.78*g3str  * gp
    g1cstr = max(1,-26.91*pow(g1size,-2.52)+12.68)*1.78*g1cstr * gp
    g2cstr = max(1,-26.91*pow(g2size,-2.52)+12.68)*1.78*g2cstr * gp
    g3cstr = max(1,-26.91*pow(g3size,-2.52)+12.68)*1.78*g3cstr * gp

    # FilmGrain size fit to original
    g1b = max(0,0.6*g1size-0.5) * pow(g,0.25)
    g2b = max(0,0.6*g2size-0.5) * pow(g,0.25)
    g3b = max(0,0.6*g3size-0.5) * pow(g,0.25)

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

    blk         = blankclip(o, width=w, height=h, color_yuv=$808080, channels=0)
    grainlayer1 = blk.AddGrainC(g1str, g1cstr, g1sz, g1sz, constant=g1const)

    grainlayer1 = (g1tex==0)
    \           ? grainlayer1
    \           : ex_makediff(grainlayer1,grainlayer1.ex_edge(mode=BUMPKERNEL1, lo=0, hi=255, UV=cchroma), UV=cchroma, fulls=!tv)

    grainlayer1 = grainlayer1.vsTCanny(sqrt(g1b)/2.*sqrt(2),mode=-1,u=g1cstr>0?3:2,v=g1cstr>0?3:2)

    #-----------------------------------------------------------------------------------

    grainlayer2 = blk.AddGrainC(g2str, g2cstr, g2sz, g2sz, constant=g2const)

    grainlayer2 = (g2tex==0)
    \           ? grainlayer2
    \           : ex_makediff(grainlayer2,grainlayer2.ex_edge(mode=BUMPKERNEL2, lo=0, hi=255, UV=cchroma), UV=cchroma, fulls=!tv)

    grainlayer2 = grainlayer2.vsTCanny(sqrt(g2b)/2.*sqrt(2),mode=-1,u=g2cstr>0?3:2,v=g2cstr>0?3:2)

    #-----------------------------------------------------------------------------------

    grainlayer3 = blk.AddGrainC(g3str, g3cstr, g3sz, g3sz, constant=g3const)

    grainlayer3 = (g3tex==0)
    \           ? grainlayer3
    \           : ex_makediff(grainlayer3,grainlayer3.ex_edge(mode=BUMPKERNEL2, lo=0, hi=255, UV=cchroma), UV=cchroma, fulls=!tv)

    grainlayer3 = grainlayer3.vsTCanny(sqrt(g3b)/2.*sqrt(2),mode=-1,u=g3cstr>0?3:2,v=g3cstr>0?3:2)

    #-----------------------------------------------------------------------------------

    th21str = MX / (th1str - th2str)
    th43str = MX / (th3str - th4str)

    one  = temp_avg == 0  || ( g1const && g2const && g3const )
    two  = ontop_grain>0  ||  ontop_cgrain>0
    thre = !one || two
    ex   = ex_dlut(Format("x dup y - a {th1str} - {th21str} * neg range_max / 0 1 clip * -
                             dup z - a {th3str} - {th43str} * neg range_max / 0 1 clip 1 swap - 0.15 ^ neg 1 + * - ") \
       +(thre ? (chroma ? "b" : "a")+" swap - range_half +" : ""), bi, !tv)

    grainlayer = Expr(grainlayer1, grainlayer2, grainlayer3, chroma ? mskY_to_YYY(o,o) : o, chroma ? o : Undefined(), ex, chroma ? ex : Undefined())

    grainlayer = one    ? grainlayer
    \          : chroma ? grainlayer.merge(    grainlayer.temporalsoften(1,255,255,255,2), tmpavg)
    \          :          grainlayer.mergeluma(grainlayer.temporalsoften(1,255,  0,255,2), tmpavg)
    grainlayer = two    ? grainlayer.AddGrainC(ontop_grain>0?ontop_grain:0, ontop_cgrain>0?ontop_cgrain:0, 0, 0, constant=ontop_const)
    \          :          grainLayer

    #-----------------------------------------------------------------------------------

    result = thre ? grainlayer : ex_lutxy(o, grainlayer, "x y - range_half +", UV=ochroma, fulls=!tv)
    msk    = o.ScriptClip( function[] () { ex_lut(string(AverageLuma(last)),UV=1) } )

    use_ALMask ? ex_merge(result, o, msk, luma=chroma, UV=ochroma) : result }
