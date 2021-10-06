#############################################################################
###                                                                       ###
###        Similarity Metrics Pack v1.0  (15-09-2021)                     ###
###                                                                       ###
###        Collection of metric functions for AviSynth+                   ###
###            Ported by Asd-g from VapourSynth                           ###
###            Modded by Dogway for performance                           ###
###                                                                       ###
###   GMSD                                                                ###
###   MDSI                                                                ###
###   SSIM                                                                ###
###   BSSIM                                                               ###
###   SSIM_downsample                                                     ###
###   +Helper functions                                                   ###
###                                                                       ###
#############################################################################



/*

GMSD - Gradient Magnitude Similarity Deviation Calculator
This script is port of the VapourSynth GMSD - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L3373


GMSD is a new effective and efficient image quality assessment (IQA) model, which utilizes the pixel-wise gradient magnitude similarity (GMS)
between the reference and distorted images combined with standard deviation of the GMS map to predict perceptual image quality.
The distortion degree of the distorted image will be stored as frame property '_PlaneGMSD' in the output clip.
The value of GMSD reflects the range of distortion severities in an image.
The lowerer the GMSD score, the higher the image perceptual quality.
If "clip1" == "clip2", GMSD = 0.
All the internal calculations are done at 32-bit float, only one channel of the image will be processed.

Ref:
    [1] Xue, W., Zhang, L., Mou, X., & Bovik, A. C. (2014). Gradient magnitude similarity deviation:
        A highly efficient perceptual image quality index. IEEE Transactions on Image Processing, 23(2), 684-695.
    [2] http://www4.comp.polyu.edu.hk/~cslzhang/IQA/GMSD/GMSD.htm.
*/


### Requirements - AviSynth+ 3.7.1+, ExTools.


### Usage ###
###
# GMSD(clip clip1, clip clip2, bool "downsample", float "c", bool "show_map", bool "show", bool "y", bool "u", bool "v")
###
## Parameters ##
#---------------
# clip1: The distorted clip, will be copied to output if "show_map" is False.
#---------------
# clip2: Reference clip, must be of the same format and dimension as the "clip1".
#---------------
# downsample (default true): Whether to average the clips over local 2x2 window and downsample by a factor of 2 before calculation.
#---------------
# c (default 0.0026): A positive constant that supplies numerical stability. According to the paper, for all the test databases, GMSD shows similar preference to the value of c.
#---------------
# show_map (default false): Whether to return GMS map. If not, "clip1" will be returned.
#---------------
# show (default true): Whether to return subtitle with GMSD value.
#---------------
# y (default true), u (default false), v (default false): Which plane to process.


### Changelog ###
#---------------
# Ported to ExTools (14% speed gain) by Dogway
#---------------
# Changed global scope of quality_map to local.
#---------------
# Replaced mt_convolution with mt_edge for ~15% speed up.
#---------------
# Initial version by Asd-g.


function GMSD(clip clip1, clip clip2, bool "downsample", float "c", bool "show_map", bool "show", bool "Y", bool "U", bool "V", bool "fulls") {

    c        = Default(c, 0.0026)
    y        = Default(y, true)
    u        = Default(u, false)
    v        = Default(v, false)
    downscl  = Default(downsample, true)
    show_map = Default(show_map,  false)
    show     = Default(show,       true)
    fs       = Default(fulls,     false)

    w1 = clip1.Width ()
    h1 = clip1.Height()
    w2 = clip2.Width ()
    h2 = clip2.Height()

    Assert(PixelType(clip1) == PixelType(clip2),              "GMSD: clip1 and clip2 must be of the same format.")
    Assert(w1 == w2 && h1 == h2,                              "GMSD: clip1 and clip2 must be of the same width and height.")
    Assert((y && !u && !v)||(!y && u && !v)||(!y && !u && v), "GMSD: only one plane must be processed.")

    clip1_src = clip1

    clip1 = y ?
    \ ExtractY(clip1).ConvertBits(32, fulls=fs) :
    \ u ?
    \ ExtractU(clip1).ConvertBits(32, fulls=fs) :
    \ ExtractV(clip1).ConvertBits(32, fulls=fs)
    clip2 = y ?
    \ ExtractY(clip2).ConvertBits(32, fulls=fs) :
    \ u ?
    \ ExtractU(clip2).ConvertBits(32, fulls=fs) :
    \ ExtractV(clip2).ConvertBits(32, fulls=fs)

    if (downscl)
    {
        clip1 = _IQA_downsample(clip1)
        clip2 = _IQA_downsample(clip2)
    }


    quality_map = ex_lutxy(ex_edge(clip1, "qprewitt", 0, 255),  \
                           ex_edge(clip2, "qprewitt", 0, 255), Format("x y * sqrt 2 * {c} + x y + {c} + /"))


    last = show_map ?
    \ ScriptClip(quality_map, """propSet("_PlaneGMSD", Sqrt(AverageLuma(Expr("x "+ String(AverageLuma()) +" - x "+ String(AverageLuma()) +" - *"))), 0)""") :
    \ ScriptClip(clip1_src, function [quality_map] ()
        {
            propSet("_PlaneGMSD", Sqrt(AverageLuma(Expr(quality_map, "x "+ String(AverageLuma(quality_map)) +" - x "+ String(AverageLuma(quality_map)) +" - *"))), 0)
        })


    return show ? ScriptClip("""Subtitle("PlaneGMSD: " + String(propGetFloat("_PlaneGMSD")))""") : last }



/*

MDSI - Mean Deviation Similarity Index Calculator
This script is port of the VapourSynth MDSI - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L4593


MDSI is a full reference IQA model that utilize gradient similarity (GS), chromaticity similarity (CS), and deviation pooling (DP).
The lowerer the MDSI score, the higher the image perceptual quality.
Larger MDSI values indicate to the more severe distorted images, while an image with perfect quality is assessed by a quality score of zero.
The distortion degree of the distorted image will be stored as frame property '_FrameMDSI' in the output clip.
Note that bilinear downsampling is used in this implementation (but disabled by default), as opposed to the original paper.
The gradient-chromaticity similarity map is saturated before deviation pooling, as described in II.D.
Matrix used by rgb2gray() from MATLAB (similar to BT.601 matrix) is used for computation of luma component.

Ref:
    [1] Nafchi, H. Z., Shahkolaei, A., Hedjam, R., & Cheriet, M. (2016).
        Mean deviation similarity index: Efficient and reliable full-reference image quality evaluator.
        IEEE Access, 4, 5579-5590.
    [2] https://ww2.mathworks.cn/matlabcentral/fileexchange/59809-mdsi-ref-dist-combmethod
*/


### Requirements - AviSynth+ >=3.7.1, ExTools, TransformsPack.


### Usage ###
###
# MDSI(clip clip1, clip clip2, int "down_scale", float "alpha", bool "show_maps", bool "show")
###
## Parameters ##
#---------------
# clip1: The first clip to be evaluated (32-bit RGB), will be copied to output.
#---------------
# clip2: The second clip, to be compared with the first one.
#---------------
# down_scale (default 1): Factor of downsampling before quality assessment.
#---------------
# alpha (default 0.6): Weight used to merge gradient similarity (GS) map and chromaticity similarity (CS) map.
#---------------
# show_maps (default false): Whether to return gradient similarity (GS), chromaticity similarity (CS) and GCS (linear combination of CS and GCS) maps. If it is true, interleaved clip of gs, cs, gcs will be returned. If it false, clip1 will be returned.
#---------------
# show (default true): Whether to return subtitle with MDSI value.


### Changelog ###
#---------------
# Ported to ExTools and TransformsPack (44% speed gain) by Dogway
#---------------
# Changed global scope of gcs to local.
#---------------
# Initial port version by Asd-g.


function MDSI(clip clip1, clip clip2, int "down_scale", float "alpha", bool "show_maps", bool "show") {

    down_scale = Default(down_scale, 1)
    alpha      = Default(alpha,    0.6)
    show_maps  = Default(show_maps, false)
    show       = Default(show, true)

    w1 = clip1.Width ()
    h1 = clip1.Height()
    w2 = clip2.Width ()
    h2 = clip2.Height()

    Assert(PixelType(clip1) == PixelType(clip2) && (IsPlanarRGB(clip1) || IsPlanarRGBA(clip1)) , "MDSI: clip1 and clip2 must be in the same format and must be in planar RGB format.")
    Assert(w1 == w2 && h1 == h2,                                                                 "MDSI: clip1 and clip2 must be of the same width and height.")

    c1 = 140 / pow(255, 2)
    c2 = 55  / pow(255, 2)
    c3 = 550 / pow(255, 2)


    down1 = down_scale > 1 || BitsPerComponent(clip1) != 32 ?
    \ Bilinearresize(clip1, Int(RoundHalfToEven(Float(w1) / down_scale)), Int(RoundHalfToEven(Float(h1) / down_scale))) :
    \ clip1

    down2 = down_scale > 1 || BitsPerComponent(clip2) != 32 ?
    \ Bilinearresize(clip2, Int(RoundHalfToEven(Float(w2) / down_scale)), Int(RoundHalfToEven(Float(h2) / down_scale))) :
    \ clip2

    down1 = [ExtractR(down1),ExtractG(down1),ExtractB(down1)]
    down2 = [ExtractR(down2),ExtractG(down2),ExtractB(down2)]

    l1 = DotClipA(down1,[0.298967,0.586421,0.114612])
    l2 = DotClipA(down2,[0.298967,0.586421,0.114612])
    f  = Merge(l1, l2)

    g_r = ex_edge(l1, "qprewitt",0,255)
    g_d = ex_edge(l2, "qprewitt",0,255)
    g_f = ex_edge(f,  "qprewitt",0,255)

    gs_hvs = ex_lutxyz(g_r, g_d, g_f, Format("x y * 2 * {c1} + x dup * X@ y dup * Y@ {c1} + + /
                                              x z * 2 * {c2} +         X  z dup * Z@ {c2} + + / +
                                              y z * 2 * {c2} +         Y          Z  {c2} + + / -"), UV=1)
    h1 = DotClipA(down1,[0.30,0.04,0.35])
    h2 = DotClipA(down2,[0.30,0.04,0.35])
    m1 = DotClipA(down1,[0.34,0.60,0.17])
    m2 = DotClipA(down2,[0.34,0.60,0.17])

    cs  = ex_lutxyza(h1, h2, m1, m2, Format("x y * z a * + 2 * {c3} + x dup * y dup * z dup * a dup * {c3} + + + + /"), UV=1)
    gcs = ex_lutxy(gs_hvs, cs, Format("x {alpha} * y 1 {alpha} - * + 0 1 clip 0.25 ^"), UV=1)


    # SHOW
    gs_hvs = show ? gs_hvs.Subtitle("gs_hvs",y=25,text_color=$2d2d2d,halo_color=$FFFFFF) : gs_hvs
    cs     = show ?     cs.Subtitle("cs"    ,y=25,text_color=$2d2d2d,halo_color=$FFFFFF) : cs
    gcs    = show ?    gcs.Subtitle("gcs"   ,y=25,text_color=$2d2d2d,halo_color=$FFFFFF) : gcs

    last = ScriptClip(show_maps ? Interleave(gs_hvs, cs, gcs) : clip1, function [gcs] ()
        {
            propSet("_FrameMDSI", pow(AverageLuma(Expr(gcs, "x "+ String(AverageLuma(gcs)) +" - abs")), 0.25), 0)
        })

    return show ? ScriptClip(function [show_maps] () { Subtitle(show_maps?ex_invert():last,"FrameMDSI: " + String(propGetFloat("_FrameMDSI"))) } ) : last }





/*

SSIM - Structural SIMilarity Index Calculator
This script is port of the VapourSynth SSIM - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L3481


The Structural SIMilarity (SSIM) index is a method for measuring the similarity between two images.
It is based on the hypothesis that the HVS is highly adapted for extracting structural information,
which compares local patterns of pixel intensities that have been normalized for luminance and contrast.
The mean SSIM (MSSIM) index value of the distorted image will be stored as frame property '_PlaneSSIM' in the output clip.
The value of SSIM measures the structural similarity in an image.
The higher the SSIM score, the higher the image perceptual quality.
If "clip1" == "clip2", SSIM = 1.
All the internal calculations are done at 32-bit float, only one channel of the image will be processed.

Ref:
    [1] Wang, Z., Bovik, A. C., Sheikh, H. R., & Simoncelli, E. P. (2004). Image quality assessment: from error visibility to structural similarity.
        IEEE transactions on image processing, 13(4), 600-612.
    [2] https://ece.uwaterloo.ca/~z70wang/research/ssim/.
*/


### Requirements - AviSynth+ 3.7.1+, vsTCanny.


### Usage ###
###
# vsSSIM(clip clip1, clip clip2, bool "downsample", float "k1", float "k2", float "stddev", float "dynamic_range", bool "show_map", bool "show", bool "y", bool "u", bool "v")
###
## Parameters ##
#---------------
# clip1: The distorted clip, will be copied to output if "show_map" is False.
#---------------
# clip2: Reference clip, must be of the same format and dimension as the "clip1".
#---------------
# downsample (default true): Whether to average the clips over local 2x2 window and downsample by a factor of 2 before calculation.
#---------------
# k1 (default 0.01), k2 (default 0.03) : Constants in the SSIM index formula. According to the paper, the performance of the SSIM index algorithm is fairly insensitive to variations of these values.
#---------------
# stddev (default 1.5): It specifies the standard deviation of the gaussian filter. (sigma in vsTCanny). According to the paper, the quality map calculated from gaussian filter exhibits a locally isotropic property, which prevents the present of undesirable “blocking” artifacts in the resulting SSIM index map.
#---------------
# dynamic_range (default 1.0): Dynamic range of the internal float point clip.
#---------------
# show_map (default false): Whether to return SSIM index map. If not, "clip1" will be returned.
#---------------
# show (default true): Whether to return subtitle with SSIM value.
#---------------
# y (default true), u (default false), v (default false): Which plane to process.


### Changelog ###
#---------------
# Sanitized by Dogway
#---------------
# Changed global scope of ssim_map to local.
#---------------
# Initial version by Asd-g.


function vsSSIM(clip clip1, clip clip2, bool "downsample", float "k1", float "k2", float "stddev", float "dynamic_range", bool "show_map", bool "show", bool "Y", bool "U", bool "V", bool "fulls") {

    y        = Default(y,  true)
    u        = Default(u, false)
    v        = Default(v, false)
    k1       = Default(k1, 0.01)
    k2       = Default(k2, 0.03)
    downscl  = Default(downsample, true)
    DR       = Default(dynamic_range, 1.0)
    stddev   = Default(stddev,        1.5)
    show_map = Default(show_map,  false)
    show     = Default(show,       true)
    fs       = Default(fulls,     false)

    w1 = clip1.Width ()
    h1 = clip1.Height()
    w2 = clip2.Width ()
    h2 = clip2.Height()

    Assert(PixelType(clip1) == PixelType(clip2),              "SSIM: clip1 and clip2 must be of the same format.")
    Assert(w1 == w2 && h1 == h2,                              "SSIM: clip1 and clip2 must be of the same width and height.")
    Assert((y && !u && !v)||(!y && u && !v)||(!y && !u && v), "SSIM: only one plane must be processed.")

    c1 = Pow(k1 * DR, 2.0)
    c2 = Pow(k2 * DR, 2.0)

    clip1_src = clip1

    clip1 = y ?
    \ ExtractY(clip1).ConvertBits(32, fulls=fs) :
    \ u ?
    \ ExtractU(clip1).ConvertBits(32, fulls=fs) :
    \ ExtractV(clip1).ConvertBits(32, fulls=fs)
    clip2 = y ?
    \ ExtractY(clip2).ConvertBits(32, fulls=fs) :
    \ u ?
    \ ExtractU(clip2).ConvertBits(32, fulls=fs) :
    \ ExtractV(clip2).ConvertBits(32, fulls=fs)

    if (downscl)
    {
        clip1 = _IQA_downsample(clip1)
        clip2 = _IQA_downsample(clip2)
    }


    mu1     = vsTCanny(clip1, sigmay=stddev, mode=-1) # gaussian blur
    mu2     = vsTCanny(clip2, sigmay=stddev, mode=-1)
    mu1_sq  = ex_lut(mu1,      "x dup *")
    mu2_sq  = ex_lut(mu2,      "x dup *")
    mu1_mu2 = ex_lutxy(mu1, mu2, "x y *")
    sigmay1_sq_pls_mu1_sq = vsTCanny(ex_lut(clip1,        "x dup *"), sigmay=stddev, mode=-1)
    sigmay2_sq_pls_mu2_sq = vsTCanny(ex_lut(clip2,        "x dup *"), sigmay=stddev, mode=-1)
    sigmay12_pls_mu1_mu2  = vsTCanny(ex_lutxy(clip1, clip2, "x y *"), sigmay=stddev, mode=-1)

    ssim_map = c1 > 0.0 && c2 > 0.0 ?
    \ Expr(mu1_mu2, sigmay12_pls_mu1_mu2, mu1_sq, mu2_sq, sigmay1_sq_pls_mu1_sq, mu1_sq, sigmay2_sq_pls_mu2_sq, mu2_sq, Format("x 2 * {c1} + y x - 2 * {c2} + * z a + {c1} + b c - d e - + {c2} + * /")) :
    \ Expr(Expr(mu1_sq, mu2_sq, Format("x y + {c1} +")), Expr(sigmay1_sq_pls_mu1_sq, mu1_sq, sigmay2_sq_pls_mu2_sq, mu2_sq, Format("x y - z a - + {c2} +")), mu1_mu2, sigmay12_pls_mu1_mu2, Format("'x y * X@ 0 > z 2 * {c1} + a z - 2 * {c2} + * X / x 0 = not y 0 = and z 2 * {c1} + x / 1 ? ?"))


    last = show_map ?
    \ ScriptClip(ssim_map, """propSet("_PlaneSSIM", AverageLuma(), 0)""") :
    \ ScriptClip(clip1_src, function [ssim_map] ()
        {
            propSet("_PlaneSSIM", AverageLuma(ssim_map), 0)
        })


    return show ? ScriptClip("""Subtitle("PlaneSSIM: " + String(propGetFloat("_PlaneSSIM")))""") : last }




/*

SSIM downsampler - Structural SIMilarity downsampler

This script is port of the VapourSynth SSIM_downsample - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py

SSIM downsampler is an image downscaling technique that aims to optimize for the perceptual quality of the downscaled results.
Image downscaling is considered as an optimization problem where the difference between the input and output images is measured using famous Structural SIMilarity (SSIM) index.
The solution is derived in closed-form, which leads to the simple, efficient implementation.
The downscaled images retain perceptually important features and details, resulting in an accurate and spatio-temporally consistent representation of the high resolution input.

This is an pseudo-implementation of SSIM downsampler with slight modification.
The behaviour of convolution at the border is uniform.
All the internal calculations are done at 32-bit float.
*/


### Requirements - AviSynth+, avsresize, vsTCanny.


### Usage ###
###
# SSIM_downsample(clip c, int target_width, int target_height, val "smooth", string "kernel", float "epsilon", string "resample_args", string "dither")
###
## Parameters ##
#---------------
# c: Source clip.
# 32-bit source clip is assumed full range.
#---------------
# target_width: The width of the output.
#---------------
# target_height: The height of the output.
#---------------
# smooth (default 1.5): The method to smooth the image.
# If it's a float, it specifies the "sigmaX" of vsTCanny.
# If it's function, it acts as a general smoother.
#---------------
# kernel (default "BicubicResize"): Resample kernel.
#---------------
# epsilon (default 0.000001)
#---------------
# resample_args (default ""): Additional resizer arguments.
#---------------
# dither (default "none"): Whether to perform dither for the final result.
# It has effect only for < 32-bit clip.


### Examples ###
/*
SSIM_downsample(1280,532)
# Downsampling with default kernel and default smooth (vsTCanny(sigmaX=1.5)).
*/
###
/*
SSIM_downsample(1280,532, resample_args="b=-0.6, c=0", dither="error_diffusion", smooth="""ex_boxblur(1,mode="mean",UV=1)""")
# Downsampling with custom kernel arguments, custom smooth function and dither.
*/


### Changelog ###
#---------------
# Sanitized by Dogway
#---------------
# Fixed smooth when it's float.
#---------------
# Allowed other resizers than avsresize.
#---------------
# Initial version by Asd-g.


function SSIM_downsample(clip c, int target_width, int target_height, val "smooth", string "kernel", float "epsilon", string "resample_args", bool "dither", bool "fulls")
{
    smooth  = Default(smooth, 1.5)
    kernel  = Default(kernel, "BicubicResize")
    epsilon = Default(epsilon, 0.000001)
    dither  = Default(dither, false)
    fs      = Default(fulls,  false)

    bi  = BitsPerComponent(c)
    c
    _32bits = (bi == 32)

    if (!_32bits)
    {
        ConvertBits(32, fulls=fs)
    }

    resample_args = (Defined(resample_args)) ? ", " + resample_args : ""

    l = Eval(kernel + "(" + String(target_width) + "," +  String(target_height) + resample_args + ")")

    if (IsFloat(smooth))
    {
        m = vsTCanny(l, sigmaY=smooth, sigma_vY=smooth, mode=-1) # Gaussian blur
        n = vsTCanny(Expr(l, "x dup *"), sigmaY=smooth, sigma_vY=smooth, mode=-1)
        o = vsTCanny(Eval(kernel + """(Expr("x dup *"),""" + String(target_width) + "," +  String(target_height) + resample_args + ")"), sigmaY=smooth, sigma_vY=smooth, mode=-1)

        r = ex_lutxyz(n, o, Expr(m, "x dup *"), Format("x z - X@ {epsilon} < 0 y z - X / 0.5 ^ ?"), UV=3)

        m = vsTCanny(m, sigmaY=smooth, sigma_vY=smooth, mode=-1)
        n = vsTCanny(r, sigmaY=smooth, sigma_vY=smooth, mode=-1)
        o = vsTCanny(Expr(r, m, "x y *"), sigmaY=smooth, sigma_vY=smooth, mode=-1)

        ex_lutxyza(m, n, l, o, "x y z * + a -", UV=3)
    }
    else
    {
        m = l.Eval(smooth)
        r = Expr(Expr(l, "x dup *").Eval(smooth), Eval(kernel + """(Expr("x dup *"),""" + String(target_width) + "," +  String(target_height) + resample_args + ")").Eval(smooth),  Expr(m, "x dup *"), Format("x z - X@ {epsilon} < 0 y z - X / 0.5 ^ ?"))
        ex_lutxyza(m.Eval(smooth), r.Eval(smooth), l, Expr(r, m, "x y *").Eval(smooth), "x y z * + a -",UV=3)
    }

    if (bi < 32) {
        ConvertBits(bits=16, dither=-1,               fulls=fs)
        ConvertBits(bits=bi, dither= dither ? 1 : -1, fulls=fs)
    }
}


# BSSIM_MOD() by zorr
# Needs StainlessS's RT_Stats plugin for the standard deviation

function BSSIM_MOD(clip source, clip filtered, float ssim) {

    stddev_orig = RT_YPlaneStdev(source)
    stddev_alt  = RT_YPlaneStdev(filtered)

    mul = (2*stddev_orig*stddev_alt) / (stddev_orig*stddev_orig + stddev_alt*stddev_alt)
    return mul*ssim }





##############################
#                            #
#     HELPER FUNCTIONS       #
#                            #
##############################

/*
This function is a port of the VapourSynth _IQA_downsample - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L3613

Downsampler for Image Quality Assessment model.
The “clip” is first filtered by a 2x2 average filter, and then down-sampled by a factor of 2.
*/


### Requirements - RoundHalfToEven.


### Changelog ###
#---------------
# Replaced with fmtc_resample(kernel="box"), faster and fixes chroma placement by Dogway.
#---------------
# Replaced GeneralConvolution with Expr for >3.5x speed up.
#---------------
# Initial version by Asd-g.


function _IQA_downsample(clip c)
{
    return fmtc_resample(c,Int(RoundHalfToEven(Width(c) / 2.0)), Int(RoundHalfToEven(Height(c) / 2.0)), kernel="box")
}


/*
Round half to even - https://en.wikipedia.org/wiki/Rounding#Round_half_to_even

Returned value is float.
*/


function RoundHalfToEven(float n)
{
    if (Frac(n) == 0.0) { return n }
    else if (Frac(n) == 0.5)
    {
        f = Floor(n)
        return f % 2 == 0 ? f : Ceil(n)
    }
    else { return Round(n) }
}

function RoundHalfToEven_mod2(val n)
{
    q = n / 2.0

    if (Frac(q) == 0.0) { return n }
    else if (Frac(q) == 0.5)
    {
        f = Floor(q)
        return f % 2 == 0 ? f * 2.0 : Ceil(q) * 2.0
    }
    else { return Round(q) * 2.0 }
}
