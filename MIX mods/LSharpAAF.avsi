
# LSharpAAF() by Leinad4Mind (2010-04-06)
# https://forum.doom9.org/showthread.php?p=1393006
#
#
# v1.00 updated in 2010-04-06 (initial release)
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
# v1.58 updated in 2020-07-19 (Dogway) fixed SantiagMod (unnesting function)
# v1.59 updated in 2020-07-19 (Dogway) added Santiag
# v1.60 updated in 2020-07-19 (Dogway) MT version for resizers
# v1.70 updated in 2021-12-18 (Dogway) Revert MT version for resizers. Optimized edge mask. Sanitized
# v1.80 updated in 2021-12-23 (Dogway) Replace SangNom with SangNom2, and nnedi2 with nnedi3. Some cosmetics and better U/V plane handling
# v1.81 updated in 2022-03-05 (Dogway) Rebase with latest LSFplus
# v1.90 updated in 2022-06-24 (Dogway) Saturate default SangNom2 to 128. Update scaling kernels in LSharpAAF()
#
#
# Requirements (Plugins):
#    MaskTools2
#    MVTools (for stabilize=true)
#
# Requirements (Scripts):
#    ExTools
#    LSFplus
#    FastLineDarkenMOD
#    Santiag (Optional for 'aatype')
#
# Optional (Plugins):
#    RgTools (for LSFplus MIX mod, or required by 'aatype' or standalone AA function)
#    SangNom2
#    awarpsharp2
#    EEDI2
#    EEDI3
#    nnedi
#    nnedi2
#    nnedi3
#    UnFilter (for AAA() )
#
#
# All AA Scripts are in this script, so there's no need to download them separately.
#
# This is an Anti-Aliasing Combo with some Extras like FastLineDarkenMOD, Presharpening, Postsharpening and Postsmoothing
#
# Thanks to @ Didée, thetoof, Mystery Keeper, Soulhunter, MisterHatt, martino, mf, Akirasuto, SpikeSpiegel, ScharfisBrain & Sagekilla
# Edited by Dogway for masktools2 function updates, included some aa functions (ediaa,maa,daa,aaa,faa,raa) and tweaked introduction.
#
# Example: LSharpAAF(StrDrk=18, ShPre=100, ShPost=280, SmPost=80, aatype="ediaa")
#      or: LSharpAAF(18,100,280,80,"ediaa")
#      or: ediaa()                         # Use the AA straight forward
#
# 25 supported anti-alias modes:
#
# "antialiasing"
# "EEDI2"
# "EEDI3"
# "EdiAA"
# "nnedi"
# "nnedi2"
# "nnedi3"
# "NediAA"
# "Sangnom"
# "aaf"
# "aaa"
# "daa"
# "daa3"
# "mrdaa"
# "laa"
# "maa"
# "naa"
# "naa3mod"
# "raa"
# "saa"
# "splinaa"
# "supaa"
# "shaarp"
# "Santiag"
# "SantiagMod"

function LSharpAAF(clip a, int "StrDrk", int "ShPre", int "ShPost", int "SmPost", int "prot", bool "stabilize", int "tradius", int "aapel", int "aaov", int "aablk", string "aatype"){

    rgb = isRGB(a)
    w   = width(a)
    h   = height(a)
    a   = a.AssumeTFF()
    fs  = propNumElements(a,"_ColorRange")  > 0 ? \
          propGetInt     (a,"_ColorRange") == 0 : rgb

    isHD      = (w > 1099 || h > 599)

    StrDrk    = Default(StrDrk, 38)                  # FastLineDarkenMOD
    ShPre     = Default(ShPre,  18)                  # Presharpening
    ShPost    = Default(ShPost,300)                  # Postsharpening
    SmPost    = Default(SmPost,100)                  # Postsmoothing
    stabilize = Default(stabilize,false )            # Use post stabilization with Motion Compensation
    tradius   = Default(tradius, 2)                  # 2 = MDegrain2 / 3 = MDegrain3
    aapel     = Default(aapel,   1)                  # accuracy of the motion estimation
                                                     # \ (Value can only be 1, 2 or 4. 1 means a precision to the pixel. 2 means a precision to half a pixel,
                                                     # 4 means a precision to quarter a pixel, produced by spatial interpolation (better but slower).)
    aablk     = Default(aablk, isHD ? 16 : 8 )       # Size of a block (horizontal). It's either 4, 8 or 16 ( Default is 8 ). Larger blocks are less sensitive to noise, are faster, but also less accurate.
    aaov      = Default(aaov,  aablk / 2 )           # block overlap value (horizontal). Must be even and less than block size. (Higher = more precise & slower)
    aatype    = Default(aatype,"SantiagMod")         # Use EEDI2() or EEDI3() or Sangnom() or maa() or daa() or ediaa() or aaa() or saa()
                                                     # or faa() or splinaa() or supaa() or naa() or shaarp() or aaf() or nnedi() or nnedi2() or nnedi3() or antialiasing() for anti-aliasing.
    prot      = Default(prot, 4)                     # protection for fastlinedarkenmod
    f         = false


    m = ex_edge(a,"sobel5",0,255,UV=2).ex_lut("x range_half / 0.86 ^ range_max *", fulls=false)

    preaa = (ShPre==0 && StrDrk==0) ? a                                                           : \
                         (ShPre==0) ? a.FastLineDarkenMOD(thinning=0, strength=StrDrk,prot=prot)  : \
                        (StrDrk==0) ? a.LSFplus(preset="slow",preblur="ON",strength=ShPre)        : \
                                      a.FastLineDarkenMOD(thinning=0, strength=StrDrk,prot=prot).LSFplus(preset="slow",preblur="ON",strength=ShPre)

    ant=(aatype=="EEDI2")        ? preaa.TurnLeft().EEDI2(       ).TurnRight().EEDI2(       ).bicubicresize(w,h,-0.5,0.25,0.5,-0.5,2*w+.001,2*h+.001)
    \ : (aatype=="EEDI3")        ? preaa.TurnLeft().EEDI3(U=f,V=f).TurnRight().EEDI3(U=f,V=f).bicubicresize(w,h,-0.5,0.25)
    \ : (aatype=="EdiAA")        ? preaa.ediaa()
    \ : (aatype=="nnedi")        ? preaa.NNEDI (dh=true,field=1,               U=f,V=f).TurnRight().NNEDI (dh=true,field=1,               U=f,V=f).TurnLeft().bicubicresize(w,h,-0.5,0.25)
    \ : (aatype=="nnedi2")       ? preaa.NNEDI2(dh=true,field=1,nsize=2,qual=3,U=f,V=f).TurnRight().NNEDI2(dh=true,field=1,nsize=2,qual=3,U=f,V=f).TurnLeft().bicubicresize(w,h,-0.5,0.25,0.5,-0.5,2*w+.001,2*h+.001)
    \ : (aatype=="nnedi3")       ? preaa.NNEDI3(dh=true,field=1,nsize=2,qual=2,U=f,V=f).TurnRight().NNEDI3(dh=true,field=1,nsize=2,qual=2,U=f,V=f).TurnLeft().bicubicresize(w,h,-0.5,0.25)
    \ : (aatype=="NediAA")       ? preaa.NediAA()
    \ : (aatype=="SangNom")      ? preaa.blackmanresize(w*2,h*2,taps=6).TurnRight().SangNom2(aa=128, chroma=false).TurnLeft().SangNom2(aa=128, chroma=false) .bicubicresize(w,h,-0.5,0.25)
    \ : (aatype=="aaf")          ? preaa.aaf(aam=-0.7,rep=true)
    \ : (aatype=="aaa")          ? preaa.aaa()
    \ : (aatype=="daa")          ? preaa.daa()
    \ : (aatype=="daa3")         ? preaa.daa3()
    \ : (aatype=="mrdaa")        ? preaa.mrdaa()
    \ : (aatype=="laa")          ? preaa.laa(96, 10, true, 2.0)
    \ : (aatype=="maa")          ? preaa.maa()
    \ : (aatype=="naa")          ? preaa.naa()
    \ : (aatype=="naa3mod")      ? preaa.naa3mod()
    \ : (aatype=="raa")          ? preaa.raa()
    \ : (aatype=="saa")          ? preaa.SAA()
    \ : (aatype=="splinaa")      ? preaa.splinaa()
    \ : (aatype=="supaa")        ? preaa.supaa()
    \ : (aatype=="shaarp")       ? preaa.shaarp()
    \ : (aatype=="Santiag")      ? preaa.Santiag   (strh=2,strv=2)
    \ : (aatype=="SantiagMod")   ? preaa.SantiagMod(strh=2,strv=2)
    \ : (aatype=="antialiasing") ? preaa.antialiasing()
    \ : Assert(false, "LSharpAAF: "+aatype+", unsupported 'aatype' mode")

    postsh   = (ShPost==0 && SmPost==0) ? ant : ant.LSFplus(edgemode=1,strength=float(ShPost),overshoot=1.0,soft=SmPost)


    merged   = mt_merge(a,postsh,m,Y=3,U=2,V=2)

    if (!stabilize) {

        merged

    } else {

        sD       = ex_makediff(a, merged, fulls=fs)

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

        sDD2 = ex_lutxy(sD,sDD2,"x range_half - abs y range_half - abs < x y ? 0.4 * y 0.6 * +", fulls=fs)

        a.ex_makediff(sDD2, UV=2, fulls=fs) } }



 ##########
 #        #
 #  saa   #
 #        #
 ##########
#Simple Anti-aliasing by Soulhunter
function saa(clip Clp, int "SS", bool "CP") {

    OX  = Clp.Width()
    OY  = Clp.Height()
    Clp = Clp.is420() ? Clp : Clp.ConvertToYUV420()

    SS = Default(SS,2)
    CP = Default(CP,True)

    Clp.PointResize(OX*SS,OY*SS).SangNom2(chroma=CP).TurnRight()
    \ .SangNom2(chroma=CP).TurnLeft().BilinearResize(OX,OY)

    CP ? Last : MergeChroma(Clp) }


 ##############
 #            #
 #antialiasing#
 #            #
 ##############
# Normal Anti-aliasing by Didée
#
# "th_luma" & "th_croma" are the edge detection thres.: lower values=more edges filtered
# "type" is the matrix used for edge detection: with "sobel" (Default) only the
#     hi-contrast edges, where artefacts are more noticeable, are filtered. If you want
#     to test other matrices, read the MaskTools2 Guide for more info.
# "aath" = anti-aliasing strenght (Default should be fine)
function AntiAliasing(clip orig, int "th_luma", int "th_croma", string "type", int "aath") {

    th_luma  = Default(th_luma,  20)
    th_croma = Default(th_croma, 20)  # 255 to disable chroma
    aath     = Default(aath,     48)
    type     = Default(type, "mt_sobel")
    CP       = th_croma > 254
    ch       = CP ? 3 : 2

    ox  = orig.width()
    oy  = orig.height()
    dx  = ox * 2
    dy  = oy * 2
    clp = orig.is420() ? orig : orig.ConvertToYUV420()

    a = clp
    b = clp.Lanczos4Resize(dx,dy).TurnLeft().SangNom2(aa=aath,chroma=CP).TurnRight().SangNom2(aa=aath,chroma=CP).LanczosResize(ox,oy)
    c = clp.ex_edge(type,th_luma,th_luma,UV=ch)

    mt_merge(a,b,c,u=ch,v=ch) }


 ##########
 #        #
 #splinaa #
 #        #
 ##########
# Written by MisterHatt, based off of Soulhunter's SAA() and martino's excellent MAA(), and is slightly
# faster at times for some reason or another. These functions work by generally supersampling, usually with
# nnedi2/3, and then running a deinterlacer (SangNom2 and nnedi2/3 respectively) to get rid of most jaggies.
# I have no idea how destructive these are on whatever random thing people care to throw them at.
# For large supersamples, avs2yuv bitches for no real reason and requires assumeframebased() in your script.
# Requires nnedi2/3, SangNom2, o9k hours of your life.

function splinaa(clip Clp, int "x", int "y", int "SS", bool "CP") {

    OX  = Clp.Width()
    OY  = Clp.Height()
    Clp = Clp.is420() ? Clp : Clp.ConvertToYUV420()

    x  = Default(x,OX)
    y  = Default(y,OY)
    SS = Default(SS,2)
    CP = Default(CP,True)

    Clp.PointResize(OX*ss,OY*ss).SangNom2(chroma=CP).TurnRight()
    \  .SangNom2(chroma=CP).TurnLeft().Spline36Resize(x,y,-0.5,-0.5)

    CP ? Last : MergeChroma(Clp) }


 ##########
 #        #
 # supaa  #
 #        #
 ##########
function supaa(clip Clp, int "SS", bool "CP") {

    OX  = Clp.Width()
    OY  = Clp.Height()
    Clp = Clp.is420() ? Clp : Clp.ConvertToYUV420()

    SS  = Default(SS,2)
    CP  = Default(CP,True)

    Clp.nnedi3_rpow2(rfactor=SS,cshift="Spline36Resize",qual=2).SangNom2(chroma=CP).TurnRight()
    \  .SangNom2(chroma=CP).TurnLeft().Spline36Resize(OX,OY)

    CP ? Last : MergeChroma(Clp) }


 ##########
 #        #
 #  naa   #
 #        #
 ##########
function naa(clip Clp, int "SS", bool "CP") {

    OX  = Clp.Width()
    OY  = Clp.Height()
    Clp = Clp.is420() ? Clp : Clp.ConvertToYUV420()

    SS  = Default(SS,2)
    CP  = Default(CP,True)

    Clp.nnedi3_rpow2(rfactor=SS,cshift="Spline36Resize",qual=2).nnedi3(qual=2,u=CP,v=CP).TurnRight()
    \  .nnedi3(qual=2,u=CP,v=CP).TurnLeft().Spline36Resize(OX,OY)

    CP ? Last : MergeChroma(Clp) }


 ############
 #          #
 # naa3mod  #
 #          #
 ############
function naa3mod(clip Clp, bool "CP") {

    OX  = Clp.Width()
    OY  = Clp.Height()
    Clp = Clp.is420() ? Clp : Clp.ConvertToYUV420()

    CP  = Default(CP,True)

    Clpnn1 = Clp.nnedi3(1, dh=true,nsize=2,qual=2,U=CP,V=CP).nnedi3(0,nsize=2,qual=2,U=CP,V=CP)
    Clpy1  = Clpnn1.Spline36Resize(OX,OY,0,-0.5,OX,OY*2)
    Clps1  = CP ? Clpy1.MergeChroma(Clpnn1.Spline36Resize(OX,OY,0,-1,OX,OY*2)) : Clpy1.MergeChroma(Clp)
    Clpnn2 = Clps1.TurnRight().nnedi3(1, dh=true,nsize=2,qual=2,U=CP,V=CP).nnedi3(0,nsize=2,qual=2,U=CP,V=CP)
    Clpy2  = Clpnn2.Spline36Resize(OY,OX,0,-0.5,OY,OX*2)

    CP ? Clpy2.MergeChroma(Clpnn2.Spline36Resize(OY,OX,0,-1,OY,OX*2)).TurnLeft() : Clpy2.TurnLeft().MergeChroma(Clp) }


 ##########
 #        #
 # shaarp #
 #        #
 ##########
function shaarp(clip input, int "mask", int "type") {

    sx   = width(input)
    sy   = height(input)
    mask = Default(mask,1)
    type = Default(type,1)

    Assert(mask == 1 || mask == 2, "Please use mask = 1 or 2")
    Assert(type == 1 || type == 2, "Please use type = 1 or 2")

    aa_clip = (type == 1) ? input.Spline36Resize(sx*2,sy*2) : \
                            input.nnedi3_rpow2(rfactor=2,qual=2)
    aa_clip = aa_clip.TurnLeft().nnedi3(u=false,v=false).TurnRight().nnedi3(u=false,v=false).Spline36Resize(sx,sy).MergeChroma(input)

    mask = (mask==1) ? input.mt_edge("sobel",7,7,5,5).mt_inflate() : \
                       input.mt_edge("roberts",0,4,0,4).mt_inflate()

    mt_merge(input,aa_clip,mask) }


 ##########
 #        #
 #  aaf   #
 #        #
 ##########
function aaf(clip input, float "aam", int "aay", int "aax", bool "rep") {

    sx    = width(input)
    sy    = height(input)
    input = input.is420() ? input : input.ConvertToYUV420()

    aam = Default (aam, -0.6)
    aar = aam<0 ? (aam-1)*0.25 : (aam+1)*0.25
    aay = Default (aay, 28)
    aax = Default (aax, aay)
    rep = Default (rep, true)

    sxa = int(sx*abs(aar))*4
    sya = int(sy*abs(aar))*4

    aa  =   aar < 0  ? input.LanczosResize(sx,sya)    : \
            aar==0.5 ? input.PointResize  (sx*2,sy*2) : \
                       input.LanczosResize(sxa,sya)

    aa  = aay>0 ? aa.SangNom2(aa=aax) : input
    aa  = aar<0 && aax>0 ? aa.LanczosResize(sxa,sy) : aa
    aa  = aax>0 ? aa.TurnRight().SangNom2(aa=aax).Turnleft() : aa
    aa  = aa.LanczosResize(sx,sy)

    rep ? aa.repair(input,18) : aa }


 ##########
 #        #
 # ediaa  #
 #        #
 ##########
#Suggested by Mystery Keeper in "Denoise of tv-anime" thread
function ediaa(clip a) {
    a
    EEDI2(field=1)
    TurnRight()
    EEDI2(field=1)
    TurnLeft()
    Spline36Resize(a.width(),a.height(),-0.5,-0.5) }


 ##########
 #        #
 #  daa   #
 #        #
 ##########
# General-purpose Anti-aliasing with contra-sharpening by Didée
# It also has other names, NNEDI3AA(), daa3, etc. Very common for the pixelating artifact of wrong field order deinterlacings.
# from this thread:               https://forum.doom9.org/showthread.php?t=153485
# variation with stronger contra: https://forum.doom9.org/showthread.php?p=1490010
# you can call like: NNEDI3AA().TurnLeft().NNEDI3AA().TurnRight()
function daa(clip c) {

    rgb = isRGB(c)
    fs  = propNumElements(c,"_ColorRange")  > 0 ? \
          propGetInt     (c,"_ColorRange") == 0 : rgb

    nn    = c.nnedi3(field=-2, qual=2)
    dbl   = Merge(SelectEven(nn),SelectOdd(nn))
    dblD  = ex_makediff(c,dbl,UV=3,fulls=fs)
    shrpD = ex_makediff(dbl,dbl.removegrain((width(c)>1100) ? 20 : 11),UV=3,fulls=fs)
    DD    = shrpD.repair(dblD,13)

    dbl.ex_adddiff(DD,UV=3,fulls=fs) }


 ##########
 #        #
 #  daa3  #
 #        #
 ##########
#Anti-aliasing with contra-sharpening by Didée, modded by Terranigma for nnedi and by thetoof for merge
function daa3(clip c) {

    rgb = isRGB(c)
    fs  = propNumElements(c,"_ColorRange")  > 0 ? \
          propGetInt     (c,"_ColorRange") == 0 : rgb

    dbl   = Merge(c.nnedi3(field = 1, nns = 1),c.nnedi3(field = 0, nns = 1))
    dblD  = ex_makediff(c,dbl,UV=3,fulls=fs)
    shrpD = ex_makediff(dbl,dbl.removegrain(11),UV=3,fulls=fs)
    DD    = shrpD.repair(dblD,13)

    dbl.ex_adddiff(DD,UV=3,fulls=fs) }



 ############
 #          #
 #  mrdaa   #
 #          #
 ############

#Based on Daa: Anti-aliasing with contra-sharpening by Didée, modded by Terranigma for nnedi and by thetoof for merge
function mrdaa(clip c, float "resharpen") {

    rgb = isRGB(c)
    fs  = propNumElements(c,"_ColorRange")  > 0 ? \
          propGetInt     (c,"_ColorRange") == 0 : rgb

    resharpen = Default(resharpen,1.0)

    dbl   = c.nnedi3_rpow2(rfactor=2,cshift="Spline36Resize",fwidth=c.width(),fheight=c.height(),pscrn=1,etype=1,nns=2,nsize=3,qual=1)
    dblD  = ex_makediff(c,dbl,UV=3,fulls=fs)
    shrpD = ex_makediff(dbl,dbl.ex_blur(resharpen*0.2,UV=3),UV=3,fulls=fs)
    DD    = shrpD.repair(dblD,13)

    dbl.ex_adddiff(DD,UV=3,fulls=fs) }


 ##########
 #        #
 #  maa   #
 #        #
 ##########
#Anti-aliasing with edge masking by martino, mask using "sobel" taken from Kintaro's useless filterscripts and modded by thetoof for spline36
function maa(clip input, int "mask") {

    w   = width(input)
    h   = height(input)

    aa_clip = input.Spline36Resize(w*2,h*2).TurnLeft().SangNom2(chroma=false).TurnRight().SangNom2(chroma=false).Spline36Resize(w,h)
    mask    = input.mt_edge("sobel",7,7,5,5).mt_inflate()

    mt_merge(input, aa_clip, mask) }


 ##########
 #        #
 #  faa   #
 #        #
 ##########
#FASTER ANTI ALIASING FILTER
#REQUIRED:
#    SangNom2
#    MaskTools2

function FAA(clip input,int "str") {

    w   = width(input)
    h   = height(input)
    vid = input.is420() ? input : input.ConvertToYUV420()

    str = Default(str, 50)

    aa  = vid.PointResize(w*2,h).TurnLeft().SangNom2(aa=str,chroma=false).TurnRight().LanczosResize(w,h)
    msk = vid.mt_edge().mt_inflate()

    mt_merge(vid , aa , msk ) }


 ##########
 #        #
 #  raa   #
 #        #
 ##########
# Residual Anti-Aliasing

function RAA (clip input) {

    w = input.width()
    h = input.height()

    input.Spline64Resize(w*2,h*2).EEDI3(vcheck=3).Spline64Resize(w,h) }


 ##########
 #        #
 #  laa   #
 #        #
 ##########
### LaTo Antialiasing Script v2
### Need: asharp, SangNom2 and ResizersPack
function LAA(clip input, int "strength", int "threshold", bool "sharp", float "ss") {

    strength  = Default(strength,  96)
    threshold = Default(threshold, 10)
    sharp     = Default(sharp, true)
    ss        = Default(ss, 2.0)
    aastr     = strength / 2
    asthr     = strength / 100.

    ox  = input.width()
    oy  = input.height()
    ox2 = nmod(ox*ss,8)
    oy2 = nmod(oy*ss,8)

    process = input.Spline36Resize(ox2,oy2).TurnLeft().SangNom2(aa=aastr,chroma=false).TurnRight().SangNom2(aa=aastr,chroma=false)
    process = sharp ? process.asharp(asthr,0,0).Spline36Resize(ox,oy) : \
                      process.Spline36Resize(ox,oy)
    mask    = Merge(input,process).mt_edge(thy1=threshold,thy2=threshold,u=1,v=1)

    mt_merge(input,process,mask,u=2,v=2) }


 ############
 #          #
 #  NediAA  #
 #          #
 ############
function NediAA(clip c) {

    c.nnedi3(field=-2)
    Merge(selecteven(),selectodd()) }


 ############
 #          #
 #SantiagMod#
 #          #
 ############

#Antialiasing function by Archimedes,
function SantiagMod(clip input, int "strh", int "strv", string "type") {

    type = Default(type, "NNEDI3")
    strh = Default(strh, 1)
    strv = Default(strv, strh)

    input

    strh > 0 ? SantiagMod_helper(type=type, strength=strh) : nop()
    TurnLeft()
    strv > 0 ? SantiagMod_helper(type=type, strength=strv) : nop()
    TurnRight() }

function SantiagMod_helper(clip input, string "type", int "strength") {

    input
    w = width()
    h = height()

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

  Spline36Resize(w, h, 0, 0.5, w, h * 2) }


 ##########
 #        #
 #  AAA   #
 #        #
 ##########
# AAA - AnimeAntiAliasing
# Thanks @ Didée, mf, Akirasuto, SpikeSpiegel & ScharfisBrain...
#
# Xres/Yres = The final resolution... InputSize = OutputSize is the Default
# Xshrp/Yshrp = Unfilter strength... Settings of 15,15 are the Defaults
# Us = Resizer for upsampling... 0 = PointResize (Default) / 1 = Lanczos
# Ds = Resizer for downsampling... 0 = Bilinear (Default) / 1 = Bicubic / 2 = Lanczos
# Chroma = Enable/disable chroma antialiasing... Disable = false (Default) / enable = true
# Note: AAASimple (and "_QED) was a failed attempt at reaching results ala Vinverse() by Byme.

function AAA(clip clp, int "Xres", int "Yres", int "Xshrp", int "Yshrp", int "US", int "DS", bool "chroma") {

        ox  = clp.width()
        oy  = clp.height()
        clp = clp.is420() ? clp : clp.ConvertToYUV420()

        Xres   = Default(Xres,  ox)
        Yres   = Default(Yres,  oy)
        us     = Default(us, 1)
        ds     = Default(ds, 2)
        Xshrp  = Default(Xshrp, 0)
        Yshrp  = Default(Yshrp, 0)
        chroma = Default(chroma, false)

        us==0 ? clp.PointResize  (ox*2,oy*2) : \
                clp.LanczosResize(ox*2,oy*2)

        TurnLeft()
        SangNom2(chroma=chroma)

        TurnRight()
        SangNom2(chroma=chroma)

        ds==0 ? BilinearResize(Xres,Yres) : \
        ds==1 ? BicubicResize (Xres,Yres) : \
                LanczosResize (Xres,Yres)

        Xshrp != 0 ? Unfilter(Xshrp,Yshrp) : last

        chroma ? MergeChroma(clp.Lanczosresize(Xres,Yres)) : last }
