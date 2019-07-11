# LSharpAAF() by Leinad4Mind
# v1.20 updated in 2010-06-08
# v1.21 updated in 2011-03-10 (Dogway)
# v1.50 updated in 2011-12-06
# v1.51 updated in 2012-04-10 (Dogway)
# v1.52 updated in 2012-04-28 (Dogway) Added raa()
# v1.53 updated in 2012-09-29 (Dogway) Added mrdaa()
# v1.54 updated in 2013-01-18 (Dogway) small addition to daa()
# v1.55 updated in 2013-09-03 (Dogway) added daa3()
# v1.56 updated in 2015-08-01 (Dogway) added prot
# v1.57 updated in 2015-08-01 (Dogway) added SantiagMod
#
# Requirements:
#    awarpsharp2
#    FastLineDarkenMOD.avsi
#    LSFmod.v1.9.avsi
#    MaskTools.dll
#    mt_masktools-2x.dll
#    EEDI2.dll
#    nnedi2.dll, nnedi3.dll
#    RemoveGrain*.dll
#    Repair*.dll
#    SangNom.dll
#    UnFilter.dll
# * HD; HDS; S; SSE2; SSE3; T; TSSE2; TSSE3
#
# All AA Scripts are in this script, so there are no need to download them separately.
#
# This is an Anti-Aliasing Combo with some Extras like FastLineDarkenMOD, Presharpening, Postsharpening and Postsmoothing
#
# Thanks to @ Didée, thetoof, Mystery Keeper, Soulhunter, MisterHatt, martino, mf, Akirasuto, SpikeSpiegel, ScharfisBrain & Sagekilla
# Edited by Dogway for masktools2 function updates, included some aa functions (ediaa,maa,daa,aaa,faa,raa) and tweaked introduction.
#
# Example: LSharpAAF(StrDrk=18, ShPre=100, ShPost=280, SmPost=80, aatype="ediaa")
# OR: LSharpAAF(18,100,280,80,"ediaa")
# OR: ediaa() # Use the AA straight forward
#
#
# aaf
# naa      fps: 1,9 | cpu: 75%
# supaa	   fps: 2,2 | cpu: 60%
# shaarp   fps: 4,2 | cpu: 55%
# ediaa	   fps: 4.6 | cpu: 99%
# maa      fps: 4,9 | cpu: 30%
# aaliasingfps: 5,6 | cpu: 40%
# aaa      fps: 5,7 | cpu: 40%
# splinaa  fps: 6,0 | cpu: 35%
#
# supported anti-alias methods:
#
# nnedi()
# nnedi2()
# nnedi3()
# EEDI2()
# EEDI3()
# ediaa()
# Sangnom()
# antialiasing()
# aaa()
# maa()
# daa()
# daa3()
# saa()
# naa()
# faa()
# splinaa()
# supaa()
# shaarp()
# aaf()
# raa()
# laa()
# nediAA()
# naa3mod()

function LSharpAAF(clip a, int "StrDrk", int "ShPre", int "ShPost", int "SmPost", int "prot", bool "stabilize", int "tradius", int "aapel", int "aaov", int "aablk", string "aatype"){

StrDrk    = default(StrDrk,38)        #FastLineDarkenMOD
ShPre     = default(ShPre,18)         #Presharpening
ShPost    = default(ShPost,300)       #Postsharpening
SmPost    = default(SmPost,100)       #Postsmoothing
stabilize = default(stabilize,false ) # Use post stabilization with Motion Compensation
tradius	  = default(tradius,2)        # 2 = MDegrain2 / 3 = MDegrain3
aapel	  = default(aapel,1)          # accuracy of the motion estimation
                                      # \ (Value can only be 1, 2 or 4. 1 means a precision to the pixel. 2 means a precision to half a pixel,
                                      # 4 means a precision to quarter a pixel, produced by spatial interpolation (better but slower).)
aaov	  = default ( aaov, (a.width>1100) ? 8 : 4 )  # block overlap value (horizontal). Must be even and less than block size. (Higher = more precise & slower)
aablk	  = default ( aablk,(a.width>1100) ? 16 : 8 ) # Size of a block (horizontal). It's either 4, 8 or 16 ( default is 8 ). Larger blocks are less sensitive to noise, are faster, but also less accurate.
aatype    = default(aatype,"EEDI2")                   # Use EEDI2() or EEDI3() or Sangnom() or maa() or daa() or ediaa() or aaa() or saa()
                                                      # or faa() or splinaa() or supaa() or naa() or shaarp() or aaf() or nnedi() or nnedi2() or nnedi3() or antialiasing() for anti-aliasing.
prot      = default(prot, 4) # protection for fastlinedarkenmod

a = a.AssumeTFF()
w = width(a)
h = height(a)
m = mt_logic(a.mt_edge(mode="5 10 5 0 0 0 -5 -10 -5",thY1=0,thY2=255,thC1=0,thC2=255,Y=3,U=3,V=3),\
             a.mt_edge(mode="5 0 -5 10 0 -10 5 0 -5",thY1=0,thY2=255,thC1=0,thC2=255,Y=3,U=3,V=3),\
             "max").mt_lut("x 128 / 0.86 ^ 255 *")

preaa = (ShPre==0 && StrDrk==0) ? a                                                     : \
                     (ShPre==0) ? a.FastLineDarkenMOD(thinning=0, strength=StrDrk,prot=prot)      : \
                    (StrDrk==0) ? a.lsfmod(defaults="slow",preblur="ON",strength=ShPre) : \
                                  a.FastLineDarkenMOD(thinning=0, strength=StrDrk,prot=prot).lsfmod(defaults="slow",preblur="ON",strength=ShPre)

aa= (aatype=="EEDI2")        ? preaa.TurnLeft().EEDI2().TurnRight().EEDI2().spline36resize(w,h,0.5,-0.5,2*w+.001,2*h+.001)
\ : (aatype=="EEDI3")        ? preaa.TurnLeft().EEDI3().TurnRight().EEDI3().spline36resize(w,h)
\ : (aatype=="Sangnom")      ? preaa.spline64resize(w*2,h*2).TurnLeft().SangNom(aa=255).TurnRight().SangNom(aa=255).spline36resize(w,h)
\ : (aatype=="maa")          ? preaa.maa()
\ : (aatype=="daa")          ? preaa.daa()
\ : (aatype=="daa3")         ? preaa.daa3()
\ : (aatype=="ediaa")        ? preaa.ediaa()
\ : (aatype=="aaa")          ? preaa.aaa()
\ : (aatype=="saa")          ? preaa.SAA()
\ : (aatype=="splinaa")      ? preaa.splinaa()
\ : (aatype=="supaa")        ? preaa.supaa()
\ : (aatype=="naa")          ? preaa.naa()
\ : (aatype=="raa")          ? preaa.raa()
\ : (aatype=="naa3mod")      ? preaa.naa3mod()
\ : (aatype=="mrdaa")        ? preaa.mrdaa()
\ : (aatype=="shaarp")       ? preaa.shaarp()
\ : (aatype=="aaf")          ? preaa.aaf(aam=-0.7,rep=true)
\ : (aatype=="laa")          ? preaa.laa(96, 10, true, 2.0)
\ : (aatype=="NediAA")       ? preaa.NediAA()
\ : (aatype=="SantiagMod")   ? preaa.SantiagMod(strh=2,strv=2)
\ : (aatype=="nnedi")        ? preaa.NNEDI (dh=true,field=1).TurnRight().NNEDI(dh=true,field=1).TurnLeft().Spline36Resize(w,h)
\ : (aatype=="nnedi2")       ? preaa.NNEDI2(dh=true,field=1,nsize=2,qual=2).TurnRight().NNEDI2(dh=true,field=1,nsize=2,qual=2).TurnLeft().Spline36Resize(w,h,0.5,-0.5,2*w+.001,2*h+.001)
\ : (aatype=="nnedi3")       ? preaa.NNEDI3(dh=true,field=1,nsize=2,qual=2).TurnRight().NNEDI3(dh=true,field=1,nsize=2,qual=2).TurnLeft().Spline36Resize(w, h)
\ : (aatype=="antialiasing") ? preaa.antialiasing()
\ : Assert(false, "Please use Sangnom, EEDI2, EEDI3, maa, daa, daa3, ediaa, aaa, ssa, splinaa, supaa, naa, laa, shaarp, aaf, nnedi, nnedi2, nnedi3, or antialiasing for aatype")

postsh=(ShPost==0 && SmPost==0) ? aa : aa.LimitedSharpenFaster(edgemode=1,strength=ShPost,overshoot=1,soft=SmPost)


merged   = mt_merge(a,postsh,m,Y=3,U=3,V=3)
sD       = mt_makediff(a,merged)

asuper   =  a.MSuper(pel=aapel)
sDsuper  = sD.MSuper(pel=aapel, levels=1)

fv1 = tradius>=1 ? asuper.MAnalyse(isb=false,delta=1,overlap=aaov,blksize=aablk) : nop()
bv1 = tradius>=1 ? asuper.MAnalyse(isb=true, delta=1,overlap=aaov,blksize=aablk) : nop()
fv2 = tradius>=2 ? asuper.MAnalyse(isb=false,delta=2,overlap=aaov,blksize=aablk) : nop()
bv2 = tradius>=2 ? asuper.MAnalyse(isb=true, delta=2,overlap=aaov,blksize=aablk) : nop()
fv3 = tradius==3 ? asuper.MAnalyse(isb=false,delta=3,overlap=aaov,blksize=aablk) : nop()
bv3 = tradius==3 ? asuper.MAnalyse(isb=true, delta=3,overlap=aaov,blksize=aablk) : nop()


sDD2 = tradius==1 ? sD.MDegrain1(sDsuper,bv1,fv1,                thSAD=600)
\    : tradius==2 ? sD.MDegrain2(sDsuper,bv1,fv1,bv2,fv2        ,thSAD=600)
\                 : sD.MDegrain3(sDsuper,bv1,fv1,bv2,fv2,bv3,fv3,thSAD=600)

reduc = 0.4
sDD2 = mt_lutxy(sD,sDD2,"x 128 - abs y 128 - abs < x y ?").mergeluma(sDD2,1.0-reduc)

return stabilize ? a.mt_makediff(sDD2,U=2,V=2) : merged}

 ##########
 #        #
 #  saa   #
 #        #
 ##########
#Simple Anti-aliasing by Soulhunter
FUNCTION saa(Clip Clp,Int"SS",Bool"CP") {
OX = Clp.Width
OY = Clp.Height
SS = Default(SS,2)
CP = Default(CP,True)
Clp = Clp.IsYV12() ? Clp : Clp.ConvertToYV12()
Clp.PointResize(OX*SS,OY*SS).SangNom().TurnRight()
\ .SangNom().TurnLeft().BilinearResize(OX,OY)
CP ? Last : MergeChroma(Clp)
Return(Last) }

 ##############
 #            #
 #antialiasing#
 #            #
 ##############
#Normal Anti-aliasing by Didée
FUNCTION antialiasing(clip orig,int "th_luma",int "th_croma",string "type",int "aath") {

# "th_luma" & "th_croma" are the edge detection thres.: lower values=more edges filtered
# "type" is the matrix used for edge detection: with "sobel" (default) only the
#     hi-contrast edges, where artefacts are more noticeable, are filtered. If you want
#     to test other matrices, read the MaskTools Guide for more info.
# "aath" = anti-aliasing strenght (default should be fine)

th_luma  = Default(th_luma, 20)
th_croma = Default(th_croma, 20)
type     = Default(type, "sobel")
aath     = Default(aath, 48)
ox = orig.width
oy = orig.height
dx = orig.width * 2
dy = orig.height * 2
clp = orig.IsYV12() ? orig : orig.ConvertToYV12()

a=clp
b=clp.Lanczos4Resize(dx,dy).TurnLeft().SangNom(aa=aath).TurnRight().SangNom(aa=aath) \
.LanczosResize(ox,oy)
c=clp.mt_edge(type,th_luma,th_luma,th_croma,th_croma)
mt_merge(a,b,c)}

 ##########
 #        #
 #splinaa #
 #        #
 ##########
# Written by MisterHatt, based off of Soulhunter's SAA() and martino's excellent MAA(), and is slightly
# faster at times for some reason or another. These functions work by generally supersampling, usually with
# nnedi2, and then running a deinterlacer (sangnom and nnedi2 respectively) to get rid of most jaggies.
# I have no idea how destructive these are on whatever random thing people care to throw them at.
# For large supersamples, avs2yuv bitches for no real reason and requires assumeframebased() in your script.
# Requires nnedi2, sangnom, o9k hours of your life.

FUNCTION splinaa(Clip Clp,int "x", int "y", Int"SS",Bool"CP") {
OX = Clp.Width
OY = Clp.Height
x = Default(x,OX)
y = Default(y,OY)
SS = Default(SS,2)
CP = Default(CP,True)
Clp = Clp.IsYV12() ? Clp : Clp.ConvertToYV12()
Clp.PointResize(OX*SS,OY*SS).SangNom().TurnRight()
\  .SangNom().TurnLeft().Spline36Resize(x,y,-0.5,-0.5)
CP ? Last : MergeChroma(Clp)
Return(Last) }

 ##########
 #        #
 # supaa  #
 #        #
 ##########
FUNCTION supaa(Clip Clp,Int"SS",Bool"CP") {
OX = Clp.Width
OY = Clp.Height
SS = Default(SS,2)
CP = Default(CP,True)
Clp = Clp.IsYV12() ? Clp : Clp.ConvertToYV12()
Clp.nnedi2_rpow2(rfactor=SS,cshift="spline36resize",qual=3).SangNom().TurnRight()
\  .SangNom().TurnLeft().Spline36Resize(OX,OY)
CP ? Last : MergeChroma(Clp)
Return(Last) }

 ##########
 #        #
 #  naa   #
 #        #
 ##########
FUNCTION naa(Clip Clp,Int"SS",Bool"CP") {
OX = Clp.Width
OY = Clp.Height
SS = Default(SS,2)
CP = Default(CP,True)
Clp = Clp.IsYV12() ? Clp : Clp.ConvertToYV12()
Clp.nnedi2_rpow2(rfactor=SS,cshift="spline36resize",qual=3).nnedi2(qual=3).TurnRight()
\  .nnedi2(qual=3).TurnLeft().Spline36Resize(OX,OY)
CP ? Last : MergeChroma(Clp)
Return(Last) }

 ############
 #          #
 # naa3mod  #
 #          #
 ############
FUNCTION naa3mod(Clip Clp,Bool "CP")
{
OX = Clp.Width()
OY = Clp.Height()
CP = Default(CP,True)
Clp = Clp.IsYV12() ? Clp : Clp.ConvertToYV12()
Clpnn1 = Clp.nnedi3(1, dh=true,nsize=2,qual=2,U=CP,V=CP).nnedi3(0,nsize=2,qual=2,U=CP,V=CP)
Clpy1 = Clpnn1.Spline36Resize(OX,OY,0,-0.5,OX,OY*2)
Clps1 = CP ? Clpy1.MergeChroma(Clpnn1.Spline36Resize(OX,OY,0,-1,OX,OY*2)) : Clpy1.MergeChroma(Clp)
Clpnn2 = Clps1.turnright().nnedi3(1, dh=true,nsize=2,qual=2,U=CP,V=CP).nnedi3(0,nsize=2,qual=2,U=CP,V=CP)
Clpy2 = Clpnn2.Spline36Resize(OY,OX,0,-0.5,OY,OX*2)
CP ? Clpy2.MergeChroma(Clpnn2.Spline36Resize(OY,OX,0,-1,OY,OX*2)).turnleft() : Clpy2.turnleft().MergeChroma(Clp)
Return(Last)}

 ##########
 #        #
 # shaarp #
 #        #
 ##########
FUNCTION shaarp(clip input, int "mask", int "type") {
mask = Default(mask,1)
type = Default(type,1)
Assert(mask == 1 || mask == 2, "Please use mask = 1 or 2")
Assert(type == 1 || type == 2, "Please use type = 1 or 2")
aa_clip = (type == 1) ? input.spline36Resize(width(input)*2,height(input)*2) : input.nnedi2_rpow2(rfactor=2,qual=3)
aa_clip = aa_clip.TurnLeft().nnedi2().TurnRight().nnedi2().spline36Resize(width(input),height(input)).MergeChroma(input)
mask = (mask==1) ? input.mt_edge("sobel",7,7,5,5).mt_inflate() : input.mt_edge("roberts",0,4,0,4).mt_inflate()

return mt_merge(input,aa_clip,mask) }

 ##########
 #        #
 #  aaf   #
 #        #
 ##########
function aaf(clip input, float "aam", int "aay", "aax", bool "rep")
{
input =	input.isYV12() ? input : input.converttoyv12()

aam	= default(aam, -0.6)
aar	= aam<0 ? (aam-1)*0.25 : (aam+1)*0.25
aay	= default(aay, 28)
aax	= default(aax, aay)
rep	= default(rep, true)

sx	= width(input)
sy	= height(input)

aa	= aar<0 ? input.LanczosResize(sx,int(sy*abs(aar))*4) :
	\	aar==0.5 ? input.Pointresize(sx*2, sy*2) :
	\	input.LanczosResize(int(sx*abs(aar)*4),int(sy*abs(aar))*4)
aa	= aay>0 ? aa.SangNom(aa=aax) : input
aa	= aar<0 && aax>0 ? aa.LanczosResize(int(sx*abs(aar))*4,sy) : aa
aa	= aax>0 ? aa.turnright().SangNom(aa=aax).Turnleft() : aa
aa	= aa.LanczosResize(sx,sy)

return rep==true ? aa.repair(input,18) : aa}

 ##########
 #        #
 # ediaa  #
 #        #
 ##########
#Suggested by Mystery Keeper in "Denoise of tv-anime" thread
FUNCTION ediaa(clip a) {return a.EEDI2(field=1).TurnRight().EEDI2(field=1).TurnLeft().spline36resize(a.width,a.height,-0.5,-0.5)}

 ##########
 #        #
 #  daa   #
 #        #
 ##########
#general-purpose Anti-aliasing with contra-sharpening by Didée
#it also has other names, NNEDI3AA(), daa3, etc. Very common for the pixelating artifact of wrong field order deinterlacings.
#from this thread: 				 http://forum.doom9.org/showthread.php?t=153485
#variation with stronger contra: http://forum.doom9.org/showthread.php?p=1490010
#you can call like: NNEDI3AA().turnleft().NNEDI3AA().turnright()
function daa(clip c) {
nn	= c.nnedi3(field=-2, qual=2)
dbl   	= Merge(SelectEven(nn),SelectOdd(nn))
dblD 	= mt_makediff(c,dbl,U=3,V=3)
shrpD 	= mt_makediff(dbl,dbl.removegrain((width(c)>1100) ? 20 : 11),U=3,V=3)
DD 	= shrpD.repair(dblD,13)
return dbl.mt_adddiff(DD,U=3,V=3) }


 ##########
 #        #
 #  daa3  #
 #        #
 ##########
#Anti-aliasing with contra-sharpening by Didée, modded by Terranigma for nnedi and by thetoof for merge
function daa3(clip c) {
dbl   = merge(c.nnedi3(field = 1, nns = 1),c.nnedi3(field = 0, nns = 1))
dblD = mt_makediff(c,dbl,U=3,V=3)
shrpD = mt_makediff(dbl,dbl.removegrain(11),U=3,V=3)
DD = shrpD.repair(dblD,13)
return dbl.mt_adddiff(DD,U=3,V=3) }

 ##########
 #        #
 #  maa   #
 #        #
 ##########
#Anti-aliasing with edge masking by martino, mask using "sobel" taken from Kintaro's useless filterscripts and modded by thetoof for spline36
function maa(clip input, int "mask") {
mask = input.mt_edge("sobel",7,7,5,5).mt_inflate()
aa_clip=input.spline36Resize(width(input)*2,height(input)*2).TurnLeft().SangNom().TurnRight().SangNom().spline36Resize(width(input),height(input)).MergeChroma(input)
return mt_merge(input,aa_clip,mask) }

 ##########
 #        #
 #  faa   #
 #        #
 ##########
#FASTER ANTI ALIASING FILTER
#REQUIRED:
#    SangNom
#    mt_masktools

function FAA(clip input,int "str") {
	str = Default(str, 50)
	vid = input.IsYV12() ? input : input.ConvertToYV12()
	w=width(input)
	h=height(input)

	aa=vid.pointResize(w*2,h) . TurnLeft() . SangNom(AA=str) . TurnRight(). lanczosResize(w,h)

	return mt_merge(vid , aa , vid.mt_edge().mt_inflate() )}


 ##########
 #        #
 #  raa   #
 #        #
 ##########
# Residual Anti-Aliasing

function RAA (clip input) {
w=input.width()
h=input.height()

input.spline64resize(w*2,h*2).eedi3(vcheck=3).spline64resize(w,h)
}

 ##########
 #        #
 #  laa   #
 #        #
 ##########
### LaTo Antialiasing Script v2
### Need: asharp.dll & sangnom.dll
function LAA(clip input, int "strength", int "threshold", bool "sharp", float "ss") {

strength = default(strength, 96)
threshold = default(threshold, 10)
sharp = default(sharp, true)
ss = default(ss, 2.0)
aastr = int(strength) /2
asthr = float(strength) /100
ox = input.width
oy = input.height
ox2 = round(ox*ss/8)*8
oy2 = round(oy*ss/8)*8

process = input.spline36resize(ox2,oy2).turnleft().sangnom(aastr).turnright().sangnom(aastr)
process = ( sharp == true ) ? process.asharp(asthr,0,0).spline36resize(ox,oy) : process.spline36resize(ox,oy)
mask = mt_average(input,process,u=1,v=1).mt_edge(thy1=threshold,thy2=threshold,u=1,v=1)
output = mt_merge(input,process,mask,u=2,v=2)

return ( output )}

 ############
 #          #
 #  NediAA  #
 #          #
 ############
function NediAA(clip c)
{   c.nnedi3(field=-2)
    merge(selecteven(),selectodd())  }


 ############
 #          #
 #  mrdaa   #
 #          #
 ############

#Based on Daa: Anti-aliasing with contra-sharpening by Didée, modded by Terranigma for nnedi and by thetoof for merge
function mrdaa(clip c, float "resharpen") {
resharpen = Default(resharpen,1.0)
dbl   = c.nnedi3_rpow2(rfactor=2,cshift="spline36resize",fwidth=c.width,fheight=c.height,fapprox=7,pscrn=1,etype=1,nns=2,nsize=3,qual=1)
dblD = mt_makediff(c,dbl,U=3,V=3)
shrpD = mt_makediff(dbl,dbl.blur(resharpen*0.2,MMX=false),U=3,V=3)
DD = shrpD.repair(dblD,13)
return dbl.mt_adddiff(DD,U=3,V=3) }



 ############
 #          #
 #SantiagMod#
 #          #
 ############

#Antialiasing function by Archimedes,
function SantiagMod(clip input, string "type", int "strh", int "strv") {
  type = Default(type, "NNEDI3")
  strh = Default(strh, 1)
  strv = Default(strv, strh)

  input

  strh > 0 ? AntiAliasing1(type=type, strength=strh) : NOP()
  TurnLeft()
  strv > 0 ? AntiAliasing1(type=type, strength=strv) : NOP()
  TurnRight()

  function AntiAliasing1(clip input, string "type", int "strength") {
    input

      if (type == "EEDI3") {
        EEDI3(dh=True, field=0)
        for (i = 2, strength) {
          EEDI3(dh=False, field=(i + 1) % 2)
        }
      }
      else if (type == "NNEDI2") {
        NNEDI2(dh=True, field=0)
        for (i = 2, strength) {
          NNEDI2(dh=False, field=(i + 1) % 2)
        }
      }
      else {
        NNEDI3(dh=True, field=0,qual=2)
        for (i = 2, strength) {
          NNEDI3(qual=2,dh=False, field=(i + 1) % 2)
        }
      }

    Spline36Resize(input.Width(), input.Height(), 0, 0.5, input.Width(), input.Height() * 2)
  }
}


 ##########
 #        #
 #  AAA   #
 #        #
 ##########
# AAA - AnimeAntiAliasing
# Thanks @ Didée, mf, Akirasuto, SpikeSpiegel & ScharfisBrain...
#
# Xres/Yres = The final resolution... InputSize = OutputSize is the default
# Xshrp/Yshrp = Unfilter strength... Settings of 15,15 are the defaults
# Us = Resizer for upsampling... 0 = PointResize (default) / 1 = Lanczos
# Ds = Resizer for downsampling... 0 = Bilinear (default) / 1 = Bicubic / 2 = Lanczos
# Chroma = Enable/disable chroma antialiasing... Disable = false (default) / enable = true
# Note: AAASimple (and "_QED) was a failed attempt at reaching results ala Vinverse() by Byme.

function AAA(clip clp, int "Xres", int "Yres", int "Xshrp", int "Yshrp",
\ int "US", int "DS", bool "chroma")
      {
        clp = clp.isYV12() ? clp : clp.ConvertToYV12()
        ox = clp.width
        oy = clp.height
        Xres  = default(Xres,  ox)
        Yres  = default(Yres,  oy)
        us = default(us, 1)
        ds = default(ds, 2)
        Xshrp = default(Xshrp, 0)
        Yshrp = default(Yshrp, 0)
        chroma = default(chroma, false)

        us==0 ? clp.PointResize(ox*2,oy*2) :
\               clp.LanczosResize(ox*2,oy*2)

        TurnLeft()
        SangNom()

        TurnRight()
        SangNom()

  ds==0 ? BilinearResize(Xres,Yres):
\ ds==1 ? BicubicResize(Xres,Yres) :
\         LanczosResize(Xres,Yres)

Xshrp != 0 ? Unfilter(Xshrp,Yshrp) : last
    chroma ? MergeChroma(clp.Lanczosresize(Xres,Yres)) : last
}