# MultiSWAR - Multi Step Warping And Resizing - V2 Beta 9
#
#
#             by *.mp4 guy (07-02-2007)- https://forum.doom9.org/showthread.php?t=112526
#
# It is designed to reduce the blurring and aliasing associated with linear resizing,
# without introducing additional artifacts or being too slow for practical use.
#
#
#             Beta 4: adapted for masktools2 and awarpsharp2 (Dogway) (13-05-2011)
#             Beta 5: adapted for ExTools and sanitized      (Dogway) (06-09-2021)
#             Beta 6: optimizations and fix for HBD          (Dogway) (18-10-2021)
#             Beta 7: Porting to SharpenersPack functions    (Dogway) (12-11-2021)
#             Beta 8: Read fulls from source                 (Dogway) (11-12-2021)
#             Beta 9: Rebasing, cleanup and fixes            (Dogway) (05-03-2022)
#
#
#   Dependencies:
#         ExTools
#         ResizersPack
#         SharpenersPack
#         SPresso
#         vsTbilateral (https://avisynth.nl/index.php/VsTBilateral)
#         MedianBlur2  (https://avisynth.nl/index.php/MedianBlur2)
#         WarpSharp    (https://avisynth.nl/index.php/WarpSharp)
#         aWarpSharp2  (https://avisynth.nl/index.php/AWarpSharp2)
#
# DestX/DestY:  Default 2x input resolution. Sets the output resolution
#        (yes its really obvious)
#
#
# StepRatio:    Determines how many iterations of resizing wil be
#           needed to reach your destination resolution, the Default is 4.
#           Higher values are slower but should remove more aliasing.
#           High values may result in more artifacts. The usable range is
#           1 to around 16.
#
#
# Smoothing:    When Smoothing is enabled (Which it is not by
#           Default) a light noise reduction filter is used to help avoid
#           sharpening artifacts from the source image, this is most
#           usefull for animated content.
#
#
# Sthresh:  Sets the strength of the smoother, Default value is 1
#           useful range is 0 to ~8.
#
#
# Sharpen:  Sets the amount of sharpening aplied by the main
#           sharpening functions, usable values are 10 to 65
#           depending upon your source, the Default is 40
#       higher values run the risk of aliasing and banding.
#
#
# Sharpen2:     Sets the amount of additional sharpening to be aplied
#           to the video, used to make faint details more prominent
#            usable values are 0.33 to 1 depending upon the source.
#           The Default value is 1 which doesn't usually cause any
#       problems, both this and sharpen are also affected by
#       the masking parameters, higher values run the risk of
#       excessive noise and banding.
#
#
# Warping:  The strength parameter for Warper. The Default of 4
#           should work the best on film, 8 is a good value for animated
#           material. if you are getting aliasing you can raise this value
#           to get rid of it. The acceptable range is 0 to 64. Unless
#       chromawarp is specified separately this parameter has a maximum
#       value of 10.
#
#
# chromawarp:   Default warping*25. Chroma warping, usefull range 100-255.
#
#
# SSm:      Default 2. Sets the supersampling used during mask creation,
#       don't change it.
#
#
# bmrad     Default 7. Sets the radius used to detect details during mask
#       creation, higher values are slower, but probably better, the
#       Default is adequate in almost all situations.
#
#
# thr:      Default 0.65. Sets the threshold for detail detection, worth
#       experimenting with, higher values makes more things detected as
#       details, higher values may cause oversharpening.
#
#
# dthr      Default 245. Sets how strongly the mask protects against
#       oversharpening, higher values give more protection, 0 gives
#       none. does not need to be set in quotes anymore.
#
#
# dbias:        Default 25. Determines how detailed areas are treated, higher
#       values cause them to be treated more like lines, lower values
#       (down to 0) cause them to be treated more like texture. does
#        not need to be set in quotes anymore.
#
#
# lthr:     Default 25. The same as dthr, but used to protect lines from being
#       oversharpened, oversharpening causes aliasing.
#
#
# lbias:    Default 225. The same as dbias, but used on lines, higher values
#       cause less overall sharpening of lines and detail that
#       would otherwise be treated as lines.
#
#
# hthr/hbias:   The same parameters as d/llthr and d/lbias, used in the
#       creation of the halo prevention mask, higher values
#       offer more protection, Defaults are hthr=48, hbias=-48
#
#
# srad:     Default 1. Sets the radius of the sharpening used on
#       detailed areas.
#
# mmrad:    Default 4. Sets the radius used in creating the median mask
#
#
# agmrad:   Default 1. sets the radius used in creating the halo mask, higher
#       values give more protection against halos, but will cause bluring.
#
#
# reducehalos:  Default true. enables halo protection, will not reduce halos
#       in the source, only those added by multiswar.
#
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

function MultiSWAR(clip Clp, int "DestX", int "DestY" ,int "StepRatio", int "warping", int "chromawarp", float "ssm", int "sthresh", int "Sharpen", float"Sharpen2", \
                  float "thr", int "dthr", int "lthr", int "hthr", int "dbias", int "lbias", int "hbias", int "srad", int "bmrad", int "mmrad", int "agmrad", bool "reducehalos", bool "smoothing") {

    rgb = isRGB(Clp)
    fs  = propNumElements(Clp,"_ColorRange")  > 0 ? \
          propGetInt     (Clp,"_ColorRange") == 0 : rgb

    OX = nmod(Clp.Width (),16,16)
    OY = nmod(Clp.Height(),16,16)
    bi = BitsPerComponent(Clp)

    DestX      = Default(DestX, OX*2)
    Desty      = Default(Desty, OY*2)
    Stepratio  = Default(Stepratio, 4)
    warping    = Default(warping, 4)
    chromawarp = Default(chromawarp, warping*25)
    SSm        = Default(SSm, 2)
    sthresh    = Default(sthresh,    1)
    Sharp      = Default(Sharpen,   40)
    Sharp2     = Default(Sharpen2, 0.5)
    thr        = Default(thr, 0.65)

    dthr       = Default(dthr, 1024)
    lthr       = Default(lthr,   25)
    hthr       = Default(hthr,   48)
    dbias      = Default(dbias, 100)
    hbias      = Default(hbias, -48)
    lbias      = Default(lbias, 225)

    Srad       = Default(srad,   1)
    bmrad      = Default(bmrad,  7)
    mmrad      = Default(mmrad,  4)
    agmrad     = Default(agmrad, 1)

    reducehalos= Default(reducehalos, true)
    smoothing  = Default(smoothing,  false)

    OXs = OX+nmod(OX/StepRatio,4)
    OYs = OY+nmod(OY/StepRatio,4)

    clp.blackmanresize(OXs,OYs,taps=5)

    #Smooth = Clp.Bilinearresize(OX+round(OX/StepRatio/4)*4,OY+round(OY/StepRatio/4)*4)

    o   = !is420() ? ConvertToYUV420() : last
    s01 = o.aWarpSharp2(Depth=round(warping*0.5), Blur=1, chroma=2,thresh=128)
    s02 = o.warpsharp(chromawarp, chromawarp)
    s   = s01.mergechroma(s02, 1)
    ss  = s.blackmanresize(nmod(OX*SSm),nmod(OY*SSm),taps=6)
    s
    #smoothing ? s.ex_repair(ex_median("edges"),mode="edgeW") : last
    smoothing ? s.ex_repair(SPresso(s,3,sthresh*7,18),mode="edgeW") : last
    #smoothing ? s.dctfun4b(sthresh, sthresh) : last


    detail      = o.ex_unsharp(str=sharp2/(1.489*pow(srad,-1.112)+0.51), Fc=max(OXs,OYs)*0.8, th=0, UV=1) # Parametrized to original variableblur's unsharp
    MedianSharp = o.XSharpenPlus(strength=sharp,threshold=255)
    MedianSharp = MedianSharp.SPresso(3,sthresh*7,18).ex_repair(o,mode="edgeW")
    #lsharp = s.LimitedSharpenfaster(Smode=Smode, soft=8, strength=sharpen, overshoot=Esharp, SS_X=1.25, SS_Y=1.25, lmode=1)

    dbias = ex_bs(dbias, 8, bi, fulls=fs)
    lbias = ex_bs(lbias, 8, bi, fulls=fs)
    hbias = ex_bs(hbias, 8, bi, fulls=fs)

    diff1 = ss.vsTBilateral(diameterY=bmrad, diameterU=3, diameterV=3, sdevY=thr, sdevU=thr, sdevV=thr)
    mask1 = ex_lutxy(ss, diff1, Format("y x - abs {dthr} * {dbias} +"), UV=1).bicubicresize(OXs, OYs,-0.5,0.25)

    diff2 = mmrad == 1 ? ss.ex_median("median")   : \
            mmrad == 2 ? ss.ex_median("median5")  : \
            mmrad == 3 ? ss.ex_median("median7")  : \
                         ss.medianblur(radiusy=mmrad, radiusu=-256, radiusv=-256)

    mask2 = ex_lutxy(ss, diff2, Format("y x - abs {lthr} * {lbias} +"), UV=1).bicubicresize(OXs, OYs,-0.5,0.25)

    # Difference of Blurs (DoB x DoG)
    Ablur = s.ex_boxblur(agmrad,  mode="mean")
    Gblur = s.ex_boxblur(agmrad*2,mode="weighted")
    mask3 = ex_lutxy(Ablur, Gblur, Format("y x - abs {hthr} * {hbias} +"), UV=1)


    s = last
    lines            = ex_merge(MedianSharp,      s, mask2)
    detail_and_lines = ex_merge(detail,    lines,    mask1)
    reducehalos ?      ex_merge(detail_and_lines, s, mask3) : last

    (width() >= destx) ? blackmanresize(destx,desty,taps=5) : \
                        MultiSWAR(destx=destx, desty=desty, stepratio=stepratio, warping=warping, chromawarp=chromawarp, ssm=ssm, sthresh=sthresh, sharpen=sharp, sharpen2=sharp2, \
                        thr=thr, dthr=dthr, lthr=lthr, hthr=hthr, dbias=dbias, lbias=lbias, hbias=hbias, srad=srad, bmrad=bmrad, mmrad=mmrad, agmrad=agmrad, reducehalos=reducehalos, smoothing=smoothing)
    }