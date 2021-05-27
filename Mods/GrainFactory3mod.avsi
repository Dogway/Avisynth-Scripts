##################################################
###                                            ###
###              GrainFactory3mod              ###
###                                            ###
###      by 06_taro - astrataro@gmail.com      ###
###                                            ###
###            v1.2 - 06 April 2012            ###
###               2020.04.06    by A.SONY.     ###
###               2021.05.27 ex by Dogway      ###
###                                            ###
##################################################
###
### Luma adaptive grain generating filter in 8-bit precision
###
### Based on Didée's GrainFactory3 script
### 
###
### +-------------+
### |  CHANGELOG  |
### +-------------+
###
### 2021.05.27 ex
###      - Removed < AviSynth+ 3.5 support
###      - Replaced with internal Expr() wrappers.
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
### -> AddGrainC         [v1.6.1]
### -> RemoveGrain      [v1.0pre]
### -> MaskTools2       [v2.0a48]
### -> f3kdb             [v1.5.0]
### -> ExTools           [v1.0.0]
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
 \                        bool  "use_sAverageLumaMask")
{

sisphbd = AvsPlusVersionNumber > 2294
fullchr = sisphbd ? clp.is444() : clp.isyv24()
chr420  = sisphbd ? clp.is420() : clp.isyv12()
nochr   = sisphbd ?   clp.isy() : clp.isy8()

dorealm4s = !(fullchr || nochr)
m4v = dorealm4s ? 2 : 0

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


#-----------------------------------------------------------------------------------

o    = clp
ox   = o.width()
oy   = o.height()
oblr = o.ex_boxblur(1,UV=1)
sx1  = m4_sh(ox/float(g1size),m4v)
sy1  = m4_sh(oy/float(g1size),m4v)
sx1a = m4_sh((ox+sx1)/2.0,m4v)
sy1a = m4_sh((oy+sy1)/2.0,m4v)
sx2  = m4_sh(ox/float(g2size),m4v)
sy2  = m4_sh(oy/float(g2size),m4v)
sx2a = m4_sh((ox+sx2)/2.0,m4v)
sy2a = m4_sh((oy+sy2)/2.0,m4v)
sx3  = m4_sh(ox/float(g3size),m4v)
sy3  = m4_sh(oy/float(g3size),m4v)
sx3a = m4_sh((ox+sx3)/2.0,m4v)
sy3a = m4_sh((oy+sy3)/2.0,m4v)

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
T1a  = string(int(g1tex*1.28))
T2a  = string(int(g2tex*1.28))
T3a  = string(int(g3tex*1.28))
th1str = string(th1)
th2str = string(th2)
th3str = string(th3)
th4str = string(th4)
tmpavg = temp_avg/100.0

chroma  = ( g1cstr == 0 ) && ( g2cstr == 0 ) && ( g3cstr == 0 ) ? false : true
ochroma = ( ontop_cgrain != 0 ) || chroma ? true : false

#-----------------------------------------------------------------------------------

BUMPKERNEL1 = " x[-1,1] " +T1a + " scaleb * x[0,0] range_half " + T1a + " scaleb - * - range_half /"
BUMPKERNEL2 = " x[-1,1] " +T2a + " scaleb * x[0,0] range_half " + T2a + " scaleb - * - range_half /"
BUMPKERNEL3 = " x[-1,1] " +T3a + " scaleb * x[0,0] range_half " + T3a + " scaleb - * - range_half /"

#-----------------------------------------------------------------------------------

grainlayer1 = blankclip(o, width=sx1, height=sy1, color_yuv=$808080)
grainlayer1 = (g1str>0 || g1cstr>0) ? grainlayer1.AddGrainC(g1str>0?g1str:0, g1cstr>0?g1cstr:0, 0, 0, constant=g1const)
\           : grainLayer1
grainLayer1 = (g1str<=-1 || g1cstr<=-1) ? grainLayer1.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g1str<=-1?Int(-g1str):0, grainC=g1cstr<=-1?Int(-g1cstr):0, dynamic_grain=!g1const, random_algo_grain=1)
\           : grainLayer1

grainlayer1 = (g1tex==0)
\           ? grainlayer1
\           : ex_makediff(grainlayer1,grainlayer1.ex_edge(mode=BUMPKERNEL1, lo=0,hi=255, UV=chroma?3:1), chroma?3:1)

grainlayer1 = (g1size == 1.0 || sx1==ox && sy1==oy) ? grainlayer1
\           : (g1size > 1.5) ? grainlayer1.bicubicresize(sx1a,sy1a, b1a,c1a).bicubicresize(ox,oy, b1a,c1a)
\                            : grainlayer1.bicubicresize(ox,oy, b1,c1)


#-----------------------------------------------------------------------------------

grainlayer2 = blankclip(o, width=sx2, height=sy2, color_yuv=$808080)
grainlayer2 = (g2str>0 || g2cstr>0) ? grainlayer2.AddGrainC(g2str>0?g2str:0, g2cstr>0?g2cstr:0, 0, 0, constant=g2const)
\           : grainLayer2
grainLayer2 = (g2str<=-1 || g2cstr<=-1) ? grainLayer2.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g2str<=-1?Int(-g2str):0, grainC=g2cstr<=-1?Int(-g2cstr):0, dynamic_grain=!g2const, random_algo_grain=1)
\           : grainLayer2

grainlayer2 = (g2tex==0)
\           ? grainlayer2
\           : ex_makediff(grainlayer2,grainlayer2.ex_edge(mode=BUMPKERNEL2, lo=0,hi=255, UV=chroma?3:1), chroma?3:1)

grainlayer2 = (g2size==1.0 || sx2==ox && sy2==oy) ? grainlayer2
\           : (g2size > 1.5) ? grainlayer2.bicubicresize(sx2a,sy2a, b2a,c2a).bicubicresize(ox,oy, b2a,c2a)
\                            : grainlayer2.bicubicresize(ox,oy, b2,c2)

#-----------------------------------------------------------------------------------

grainlayer3 = blankclip(o, width=sx3, height=sy3, color_yuv=$808080)
grainlayer3 = (g3str>0 || g3cstr>0) ? grainlayer3.AddGrainC(g3str>0?g3str:0, g3cstr>0?g3cstr:0, 0, 0, constant=g3const)
\           : grainLayer3
grainLayer3 = (g3str<=-1 || g3cstr<=-1) ? grainLayer3.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=g3str<=-1?Int(-g3str):0, grainC=g3cstr<=-1?Int(-g3cstr):0, dynamic_grain=!g3const, random_algo_grain=1)
\           : grainLayer3

grainlayer3 = (g3tex==0)
\           ? grainlayer3
\           : ex_makediff(grainlayer3,grainlayer3.ex_edge(mode=BUMPKERNEL2, lo=0,hi=255, UV=chroma?3:1), chroma?3:1)

grainlayer3 = (g3size==1.0 || sx3==ox && sy3==oy) ? grainlayer3
\           : (g3size > 1.5) ? grainlayer3.bicubicresize(sx3a,sy3a, b3a,c3a).bicubicresize(ox,oy, b3a,c3a)
\                            : grainlayer3.bicubicresize(ox,oy, b3,c3)

#-----------------------------------------------------------------------------------

grainlayer = grainlayer1.ex_merge(grainlayer2, oblr.Expr("x "+th1str+" scalef < 0 x "+th2str+" scalef > range_max range_max "+th2str+" scalef "+th1str+" scalef - / x "+th1str+" scalef - * ? ?"), luma=chroma, UV=chroma?3:1)
 \                      .ex_merge(grainlayer3, oblr.Expr("x "+th3str+" scalef < 0 x "+th4str+" scalef > range_max range_max "+th4str+" scalef "+th3str+" scalef - / x "+th3str+" scalef - * ? ?"), luma=chroma, UV=chroma?3:1)

grainlayer = (temp_avg==0 || ( g1const==true && g2const==true && g3const==true ) ) ? grainlayer
\          : chroma ? grainlayer.merge(grainlayer.temporalsoften(1,255,255,255,2), tmpavg)
\          :          grainlayer.mergeluma(grainlayer.temporalsoften(1,255,0,255,2), tmpavg)
grainlayer = (  ontop_grain>0  ||  ontop_cgrain>0  ) ? grainlayer.AddGrainC(ontop_grain>0?ontop_grain:0, ontop_cgrain>0?ontop_cgrain:0, 0, 0, constant=ontop_const)
\          : grainLayer
grainLayer = ( ontop_grain<=-1 || ontop_cgrain<=-1 ) ? grainLayer.neo_f3kdb(Y=0, Cb=0, Cr=0, grainY=ontop_grain<=-1?Int(-ontop_grain):0, grainC=ontop_cgrain<=-1?Int(-ontop_cgrain):0, dynamic_grain=!ontop_const, random_algo_grain=1)
\          : grainLayer

#-----------------------------------------------------------------------------------

result = o.ex_makediff(grainlayer, ochroma?3:2)
result = use_ALMask ? ex_merge(result,o,o.sAverageLumaMask, luma=chroma, UV=ochroma?3:2) : result




return( result ) }
