##################################################
###                                            ###
###              GrainFactory3mod              ###
###                                            ###
###      by 06_taro - astrataro@gmail.com      ###
###                                            ###
###            2012.04.06 v1.2 by 06_taro      ###
###            2020.04.06      by A.SONY.      ###
###            2021.11.18 mx   by Dogway       ###
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
### 2021.11.18 mx
###      - Update 'fulls' defaults
###
### 2021.10.18 mx
###      - Rebase with latest ResizersPack
###
### 2021.10.08 mx
###      - Rebase with latest ExTools
###      - Rename m4() to avoid dup name
###      - Disable blankclip audio track
###
### 2021.09.09 mx
###      - Remove Zs_RF_Shared dependency
###
### 2021.08.12 mx
###      - Update ex_bs()
###
### 2021.08.07 mx
###      - Minor edits
###
### 2021.07.14 mx
###      - Minor Expr edit
###
### 2021.07.02 mx
###      - Convolution optimization
###      - Resizers blur fix
###
### 2021.06.28 mx
###      - Expression optimizations
###
### 2021.06.22 mx
###      - Further old checks cleanup
###      - Rebased with latest ExTools
###
### 2021.05.27 mx
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
### -> AddGrainC         [v1.8.3]
### -> RgTools           [v1.2]
### -> MaskTools2        [v2.2.29]
### -> neo_f3kdb         [r6]       (Optional)
### -> ExTools           [v6.9.0]
### -> ResizersPack      [v7.0.0]
###

function GrainFactory3mod(clip clp,
 \                        float "g1str",   float "g2str",   float "g3str",
 \                        float "g1cstr",  float "g2cstr",  float "g3cstr",
 \                        int   "g1shrp",  int   "g2shrp",  int   "g3shrp",
 \                        float "g1size",  float "g2size",  float "g3size",
 \                        int   "g1tex",   int   "g2tex",   int   "g3tex",
 \                        bool  "g1const", bool  "g2const", bool  "g3const",
 \                        int   "th1",     int   "th2",     int   "th3",     int "th4",
 \                        int   "temp_avg",
 \                        float "ontop_grain",
 \                        float "ontop_cgrain",
 \                        bool  "ontop_const",
 \                        bool  "tv_range",
 \                        bool  "use_sAverageLumaMask" )
{


Assert(IsVersionOrGreater(3,5,0), "GrainFactory3mod: Update AviSynth+ version")


g1str        = Default( g1str,         13 )  # [ 0 - ???] strength of luma grain / for dark areas
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
g2str        = Default( g2str,         15 )  # [ 0 - ???] strength of luma grain / for midtone areas
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
g3str        = Default( g3str,         25 )  # [ 0 - ???] strength of luma grain / for bright areas
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
g1cstr       = Default( g1cstr,         0 )  # [ 0 - ???] strength of chroma grain / for dark areas
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
g2cstr       = Default( g2cstr,         0 )  # [ 0 - ???] strength of chroma grain / for midtone areas
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
g3cstr       = Default( g3cstr,         0 )  # [ 0 - ???] strength of chroma grain / for bright areas
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
g1shrp       = Default( g1shrp,        60 )  # [ 0 - 100] sharpness of grain / for dark areas (NO EFFECT when g1size=1.0 !!)
g2shrp       = Default( g2shrp,        66 )  # [ 0 - 100] sharpness of grain / for midtone areas (NO EFFECT when g2size=1.0 !!)
g3shrp       = Default( g3shrp,        80 )  # [ 0 - 100] sharpness of grain / for bright areas (NO EFFECT when g3size=1.0 !!)
g1size       = Default( g1size,      1.50 )  # [0.5 - 4.0] size of grain / for dark areas
g2size       = Default( g2size,      1.20 )  # [0.5 - 4.0] size of grain / for mid-tone areas
g3size       = Default( g3size,      0.90 )  # [0.5 - 4.0] size of grain / for bright areas
g1tex        = Default( g1tex,          0 )  # [ 0 - 100] strength of "material texture" appearance
g2tex        = Default( g2tex,          0 )  # [ 0 - 100] (in fact: 'bump' effect)
g3tex        = Default( g3tex,          0 )  # [ 0 - 100] for dark / midtone / bright grain
g1const      = Default( g1const,    false )  # AddGrainC "constant" parameter of grain / for dark areas
g2const      = Default( g2const,    false )  # AddGrainC "constant" parameter of grain / for midtone areas
g3const      = Default( g3const,    false )  # AddGrainC "constant" parameter of grain / for bright areas
temp_avg     = Default( temp_avg,       0 )  # [ 0 - 100] percentage of noise's temporal averaging (NO EFFECT when g1const=g2const=g3const=true !!)
th1          = Default( th1,           24 )  # start of dark->midtone  mixing zone
th2          = Default( th2,           56 )  # end  of  dark->midtone  mixing zone
th3          = Default( th3,          128 )  # start of midtone->bright  mixing zone
th4          = Default( th4,          160 )  # end  of  midtone->bright  mixing zone
ontop_grain  = Default( ontop_grain,    0 )  # [ 0 - ???] additional luma grain to put on top of prev. generated grain
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
ontop_cgrain = Default( ontop_cgrain,   0 )  # [ 0 - ???] additional chroma grain to put on top of prev. generated grain
                                             # positive value for AddGrainC strength, negative value for f3kdb grain strength
ontop_const  = Default( ontop_const, false)  # AddGrainC "constant" parameter of ontop clip
use_ALMask   = Default( use_sAverageLumaMask, false)

tv_D         = Defined( tv_range)
rgb = isRGB(clp)
fs  = tv_D ? tv : propNumElements (clp,"_ColorRange")  > 0 ? \
                  propGetInt      (clp,"_ColorRange") == 0 : rgb
tv           = Default( tv_range, !fs)


#-----------------------------------------------------------------------------------

bi   = BitsPerComponent(clp)
o    = clp
ox   = o.width()
oy   = o.height()
oblr = o.removegrain(19,-1)
sx1  = nmod(ox/float(g1size),4)
sy1  = nmod(oy/float(g1size),4)
sx1a = nmod((ox+sx1)/2.0,    4)
sy1a = nmod((oy+sy1)/2.0,    4)
sx2  = nmod(ox/float(g2size),4)
sy2  = nmod(oy/float(g2size),4)
sx2a = nmod((ox+sx2)/2.0,    4)
sy2a = nmod((oy+sy2)/2.0,    4)
sx3  = nmod(ox/float(g3size),4)
sy3  = nmod(oy/float(g3size),4)
sx3a = nmod((ox+sx3)/2.0,    4)
sy3a = nmod((oy+sy3)/2.0,    4)

b1   = g1shrp/(-50.0) + 1.0
b2   = g2shrp/(-50.0) + 1.0
b3   = g3shrp/(-50.0) + 1.0
b1a  = b1/2.0
b2a  = b2/2.0
b3a  = b3/2.0
c1   = (1.0-b1)/2.0
c2   = (1.0-b2)/2.0
c3   = (1.0-b3)/2.0
c1a  = (1.0-b1a)/2.0
c2a  = (1.0-b2a)/2.0
c3a  = (1.0-b3a)/2.0

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

tmpavg = temp_avg/100.0

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
\           : ex_makediff(grainlayer1,grainlayer1.ex_edge(mode=BUMPKERNEL1, lo=0, hi=255, UV=cchroma, fulls=!tv), UV=cchroma, fulls=!tv)

grainlayer1 = (g1size == 1.0 || sx1==ox && sy1==oy) ? grainlayer1
\           : (g1size > 1.5) ? grainlayer1.bicubicresize(sx1a,sy1a, b1a,c1a).bicubicresize(ox,oy, b1a,c1a)
\                            : grainlayer1.bicubicresize(ox,oy, b1,c1)


#-----------------------------------------------------------------------------------

grainlayer2 = blankclip(o, width=sx2, height=sy2, color_yuv=$808080, channels=0)
grainlayer2 = (g2str>0   || g2cstr>0)   ? grainlayer2.AddGrainC(g2str>0?g2str:0, g2cstr>0?g2cstr:0, 0, 0, constant=g2const)
\           : grainLayer2
grainLayer2 = (g2str<=-1 || g2cstr<=-1) ? grainLayer2.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g2str<=-1?Int(-g2str):0, grainC=g2cstr<=-1?Int(-g2cstr):0, dynamic_grain=!g2const, random_algo_grain=1)
\           : grainLayer2

grainlayer2 = (g2tex==0)
\           ? grainlayer2
\           : ex_makediff(grainlayer2,grainlayer2.ex_edge(mode=BUMPKERNEL2, lo=0, hi=255, UV=cchroma, fulls=!tv), UV=cchroma, fulls=!tv)

grainlayer2 = (g2size==1.0 || sx2==ox && sy2==oy) ? grainlayer2
\           : (g2size > 1.5) ? grainlayer2.bicubicresize(sx2a,sy2a, b2a,c2a).bicubicresize(ox,oy, b2a,c2a)
\                            : grainlayer2.bicubicresize(ox,oy, b2,c2)

#-----------------------------------------------------------------------------------

grainlayer3 = blankclip(o, width=sx3, height=sy3, color_yuv=$808080, channels=0)
grainlayer3 = (g3str>0   || g3cstr>0)   ? grainlayer3.AddGrainC(g3str>0?g3str:0, g3cstr>0?g3cstr:0, 0, 0, constant=g3const)
\           : grainLayer3
grainLayer3 = (g3str<=-1 || g3cstr<=-1) ? grainLayer3.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g3str<=-1?Int(-g3str):0, grainC=g3cstr<=-1?Int(-g3cstr):0, dynamic_grain=!g3const, random_algo_grain=1)
\           : grainLayer3

grainlayer3 = (g3tex==0)
\           ? grainlayer3
\           : ex_makediff(grainlayer3,grainlayer3.ex_edge(mode=BUMPKERNEL2, lo=0, hi=255, UV=cchroma, fulls=!tv), UV=cchroma, fulls=!tv)

grainlayer3 = (g3size==1.0 || sx3==ox && sy3==oy) ? grainlayer3
\           : (g3size > 1.5) ? grainlayer3.bicubicresize(sx3a,sy3a, b3a,c3a).bicubicresize(ox,oy, b3a,c3a)
\                            : grainlayer3.bicubicresize(ox,oy, b3,c3)

#-----------------------------------------------------------------------------------

th21str = th2str - th1str
th43str = th4str - th3str
grainlayer = grainlayer1.mt_merge(grainlayer2, oblr.ex_lut(Format("x {th1str} < 0 x {th2str} > range_max range_max {th21str} / x {th1str} - * ? ?"), fulls=!tv), luma=chroma, U=cchroma,V=cchroma)
 \                      .mt_merge(grainlayer3, oblr.ex_lut(Format("x {th3str} < 0 x {th4str} > range_max range_max {th43str} / x {th3str} - * ? ?"), fulls=!tv), luma=chroma, U=cchroma,V=cchroma)

grainlayer = (temp_avg==0 || ( g1const && g2const && g3const ) ) ? grainlayer
\          : chroma ? grainlayer.merge(    grainlayer.temporalsoften(1,255,255,255,2), tmpavg)
\          :          grainlayer.mergeluma(grainlayer.temporalsoften(1,255,  0,255,2), tmpavg)
grainlayer = ( ontop_grain>0  ||  ontop_cgrain>0  )  ? grainlayer.AddGrainC(ontop_grain>0?ontop_grain:0, ontop_cgrain>0?ontop_cgrain:0, 0, 0, constant=ontop_const)
\          : grainLayer
grainLayer = ( ontop_grain<=-1 || ontop_cgrain<=-1 ) ? grainLayer.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=ontop_grain<=-1?Int(-ontop_grain):0, grainC=ontop_cgrain<=-1?Int(-ontop_cgrain):0, dynamic_grain=!ontop_const, random_algo_grain=1)
\          : grainLayer

#-----------------------------------------------------------------------------------

result = o.ex_makediff(grainlayer, UV=ochroma, fulls=!tv)
msk    = o.ScriptClip( function[] () { ex_lut(string(AverageLuma(last)),UV=1) } )

use_ALMask ? mt_merge(result, o, msk, luma=chroma, U=ochroma,V=ochroma) : result }
