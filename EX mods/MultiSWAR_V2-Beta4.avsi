# MultiSWAR - Multi Step Warping And Resizing - V2 Beta 4
#
#
#             by *.mp4 guy (07-02-2007)- http://forum.doom9.org/showthread.php?t=112526
#
# It is designed to reduce the blurring and aliasing associated with linear resizing,
# without introducing additional artifacts or being too slow for practical use.
#
#
#             Beta 4: adapted for masktools2 and awarpsharp2 (Dogway) (13-05-2011)
#
#   Dependencies:
#
#         Tbilateral   (http://web.missouri.edu/~kes25c/)
#         dctfun4b     (http://forum.doom9.org/showthread.php?t=114526)
#         frfun7       (http://forum.doom9.org/showthread.php?p=825604#post825604)
#         medianblur   (http://avisynth.org/tsp/)
#         variableblur (http://avisynth.org/tsp/)
#         warpsharp    (http://avisynth.org/warpenterprises/)
#         awarpsharp2  (http://forum.doom9.org/showthread.php?t=147285)
#         MaskTools2   (http://forum.doom9.org/showthread.php?t=98985)
#
# DestX/DestY:	Default 2x input resolution. Sets the output resolution
#		 (yes its really obvious)
#
#
# StepRatio: 	Determines how many iterations of resizing wil be
#   		needed to reach your destination resolution, the default is 4.
#   		Higher values are slower but should remove more alliasing.
#   		High values may result in more artifacts. The usable range is
#   		1 to around 16.
#
#
# Smoothing: 	When Smoothing is enabled (Which it is not by
#   		default) a light noise reduction filter is used to help avoid
#   		sharpening artifacts from the source image, this is most
#   		usefull for animated content.
#
#
# Sthresh: 	Sets the strength of the smoother, default value is 1
#   		useful range is 0 to ~8.
#
#
# Sharpen: 	Sets the amount of sharpening aplied by the main
#   		sharpening functions, usable values are 10 to 65
#   		depending upon your source, the default is 40
#		higher values run the risk of aliasing and banding.
#
#
# Sharpen2: 	Sets the amount of additional sharpening to be aplied
#   		to the video, used to make faint details more prominent
#   		 usable values are 0.33 to 1 depending upon the source.
#   		The default value is 1 which doesn't usually cause any
#		problems, both this and sharpen are also affected by
#		the masking parameters, higher values run the risk of
#		excessive noise and banding.
#
#
# Warping: 	The strength parameter for Warper. The default of 4
#   		should work the best on film, 8 is a good value for animated
#   		material. if you are getting aliasing you can raise this value
#   		to get rid of it. The acceptable range is 0 to 64. Unless
#		chromawarp is specified separately this parameter has a maximum
#		value of 10.
#
#
# chromawarp:	Default warping*25. Chroma warping, usefull range 100-255.
#
#
# SSm:		Default 2. Sets the supersampling used during mask creation,
#		don't change it.
#
#
# bmrad		Default 7. Sets the radius used to detect details during mask
#		creation, higher values are slower, but probably better, the
#		default is adequate in almost all situations.
#
#
# thr:		Default 0.65. Sets the threshold for detail detection, worth
#		experimenting with, higher values makes more things detected as
#		details, higher values may cause oversharpening.
#
#
# dthr		Default 245. Sets how strongly the mask protects against
#		oversharpening, higher values give more protection, 0 gives
#		none. does not need to be set in quotes anymore.
#
#
# dbias:		Default 25. Determines how detailed areas are treated, higher
#		values cause them to be treated more like lines, lower values
#		(down to 0) cause them to be treated more like texture. does
#		 not need to be set in quotes anymore.
#
#
# lthr:		default 25. The same as dthr, but used to protect lines from being
#		oversharpened, oversharpening causes aliasing.
#
#
# lbias:	default 225. The same as dbias, but used on lines, higher values
#		cause less overall sharpening of lines and detail that
#		would otherwise be treated as lines.
#
#
# hthr/hbias:	The same parameters as d/llthr and d/lbias, used in the
#		creation of the halo prevention mask, higher values
# 		offer more protection, defaults are hthr=48, hbias=-48
#
#
# srad:		Default 1. Sets the radius of the sharpening used on
#		detailed areas.
#
# mmrad:	default 4. Sets the radius used in creating the median mask
#
#
# agmrad:	default 1. sets the radius used in creating the halo mask, higher
#		values give more protection against halos, but will cause bluring.
#
#
# reducehalos:	Default true. enables halo protection, will not reduce halos
#		in the source, only those added by multiswar.
#
#
# lanczos:	Defualt true. enables use of lanczos resizing instead of
#		spline36 resizing, lanczos is sharper but more artifact
#		prone, good for film content.
#
#
#
#Misc parameters:
#DestX
#Desty
#Stepratio
#warping
#chromawarp
#SSm
#sthresh
#Sharpen
#Sharpen2
#thr
#
#Masking parameters:
#dthr
#lthr
#hthr
#dbias
#hbias
#lbias
#
#Radius parameters:
#Srad
#bmrad
#mrad
#agmrad

Function MultiSWAR(Clip Clp, Int"DestX", Int"DestY" ,Int"StepRatio", int "warping", int "chromawarp", float "ssm", int "sthresh", Int"Sharpen", float"Sharpen2", float "thr", int "dthr", int "lthr", int "hthr", int "dbias", int "lbias", int "hbias", int "srad", int "bmrad", int "mmrad", int "agmrad", bool "reducehalos", bool "smoothing", bool "lanczos")

{
OX = m(16,Clp.Width)
OY = m(16,Clp.Height)



 DestX      = Default(DestX, OX*2)
 Desty      = Default(Desty, OY*2)
 Stepratio  = Default(Stepratio, 4)
 warping    = default(warping, 4)
 chromawarp = default(chromawarp, warping*25)
 SSm        = Default(SSm, 2)
 sthresh    = Default(sthresh, 1)
 Sharpen    = Default(Sharpen, 40)
 Sharpen2   = Default(Sharpen2, 0.5)
 thr        = Default(thr, 0.65)

 dthr       = Default(dthr, 1024)
 lthr       = default(lthr, 25)
 hthr       = default(hthr, 48)
 dbias      = default(dbias, 100)
 hbias      = default(hbias, -48)
 lbias      = default(lbias, 225)

 Srad       = default(srad, 1)
 bmrad      = default(bmrad, 7)
 mmrad      = default(mmrad, 4)
 agmrad     = default(agmrad, 1)

 reducehalos= default(reducehalos, true)
 smoothing  = default(smoothing, false)
 lanczos    = default(lanczos, true)

Clp.Spline36Resize(OX+round(OX/StepRatio/4)*4,OY+round(OY/StepRatio/4)*4)

lanczos ? Clp.lanczos4resize(OX+round(OX/StepRatio/4)*4,OY+round(OY/StepRatio/4)*4) : last

#Smooth = Clp.Bilinearresize(OX+round(OX/StepRatio/4)*4,OY+round(OY/StepRatio/4)*4)

OXo = OX+round(OX/StepRatio/4)*4
OYo = OY+round(OY/StepRatio/4)*4

o = last.converttoyv12()
s01 = o.aWarpSharp2(Depth=warping*1/2, Blur=1, chroma=2,thresh=128)
s02 = o.warpsharp(chromawarp, chromawarp)
s = s01.mergechroma(s02, 1)
ss = s.spline36resize(OX*SSm, OY*SSm)
s
smoothing ? s.dctfun4b(sthresh, sthresh) : last


detail = o.unsharp(vary=srad, varc=srad, strength=sharpen2,border=3,integrate=true)
MedianSharp = o.Xsharpen(strength=sharpen,threshold=255).dctfun4b(sthresh, sthresh)
#lsharp = s.LimitedSharpenfaster(Smode=Smode, soft=8, strength=sharpen, overshoot=Esharp, SS_X=1.25, SS_Y=1.25, lmode=1)

diff1 = ss.tbilateral(diameterl=bmrad, diameterc=3, sdevl=thr, sdevc=thr)
mask1 = mt_lutxy(ss, diff1, "y x - abs "+string(dthr)+" * "+string(dbias)+" +", "x", "x", U=3, V=3).bilinearresize(OXo, OYo)

diff2 = ss.medianblur(radiusy=mmrad, radiusu=-256, radiusv=-256)
mask2 = mt_lutxy(ss, diff2, "y x - abs "+string(lthr)+" * "+string(lbias)+" +", "x", "x", U=3, V=3).bilinearresize(OXo, OYo)

Ablur = s.averageblur(rady=agmrad, radc=0)
gblur = s.gaussianblur(vary=agmrad, varc=0)
mask3 = mt_lutxy(Ablur, Gblur, "y x - abs "+string(hthr)+" * "+string(hbias)+" +", "x", "x", U=3, V=3)


s = last
lines = mt_merge(mediansharp, s, mask2)
detail_and_lines = mt_merge(detail, lines , mask1)
reducehalos ? mt_merge(detail_and_lines, S, Mask3) : last

return (width < destx) ? MultiSWAR(destx=destx, desty=desty, stepratio=stepratio, warping=warping, chromawarp=chromawarp, ssm=ssm, sthresh=sthresh, sharpen=sharpen, sharpen2=sharpen2, thr=thr, dthr=dthr, lthr=lthr, hthr=hthr, dbias=dbias, lbias=lbias, hbias=hbias, srad=srad, bmrad=bmrad, mmrad=mmrad, agmrad=agmrad, reducehalos=reducehalos, smoothing=smoothing, lanczos=lanczos) : spline36resize(destx,desty)

}
function m(int r, float x) {return(x<16?16:int(round(x/float(r))*r))}