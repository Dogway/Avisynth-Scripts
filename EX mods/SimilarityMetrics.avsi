#############################################################################
###                                                                       ###
###        Similarity Metrics Pack v3.9  (14-03-2023)                     ###
###                                                                       ###
###        Collection of metric functions for AviSynth+                   ###
###            Ported by Asd-g from VapourSynth                           ###
###                https://github.com/Asd-g/AviSynthPlus-Scripts          ###
###            Modded by Dogway for performance                           ###
###                                                                       ###
###   GMSD                                                                ###
###   MDSI                                                                ###
###   SSIM                                                                ###
###   BSSIM                                                               ###
###   SVM                                                                 ###
###   SSIM_downsample                                                     ###
###   _IQA_downsample                                                     ###
###   RoundHalfToEven                                                     ###
###   RoundHalfToEven_mod                                                 ###
###                                                                       ###
#############################################################################


/*

GMSD - Gradient Magnitude Similarity Deviation Calculator
This script is a port of the VapourSynth GMSD - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L3417


    GMSD is a new effective and efficient image quality assessment (IQA) model, which utilizes the pixel-wise gradient magnitude similarity (GMS)
    between the reference and distorted images combined with standard deviation of the GMS map to predict perceptual image quality.

    The distortion degree of the distorted image will be stored as frame property '_PlaneGMSD' in the output clip.

    The value of GMSD reflects the range of distortion severities in an image.
    The lower the GMSD score, the higher the image perceptual quality.
    If "clip1" == "clip2", GMSD = 0.

    All the internal calculations are done at 32-bit float, only one channel of the image will be processed.

Ref:
    [1] Xue, W., Zhang, L., Mou, X., & Bovik, A. C. (2014). Gradient magnitude similarity deviation:
        A highly efficient perceptual image quality index. IEEE Transactions on Image Processing, 23(2), 684-695.
    [2] https://www4.comp.polyu.edu.hk/~cslzhang/IQA/GMSD/GMSD.htm.
*/


### Requirements - AviSynth+ 3.7.3+, ExTools and fmtconv (for downsample=true)


### Usage ###
###
# GMSD(clip clip1, clip clip2, bool "downsample", float "c", bool "show_map", bool "show", bool "y", bool "u", bool "v")
###
## Parameters ##
#---------------
# clip1: The distorted clip (YUV 32-bit float), will be copied to output if "show_map" is False.
#---------------
# clip2: Reference clip, must be of the same format and dimension as the "clip1".
#---------------
# downsample (default true): Whether to average the clips over local 2x2 window and downsample by a factor of 2 before calculation.
#---------------
# c (default 0.0026): A positive constant that supplies numerical stability. According to the paper, for all the test databases, GMSD shows similar preference to the value of c.
#---------------
# show_map (default false): Whether to return GMS map. If not, "clip1" will be returned.
#---------------
# show (default 0): Decides output form. 0 returns 'distorted' with frameprops, 1 returns 'reference' with frameprops. 2 returns 'distorted' subtitled with GMSD value and frameprops.
#---------------
# propName (default "_PlaneGMSD"): Identifier assigned to the metric frame property, in case you want to stack metrics against different distorted clips.
#---------------
# y (default true), u (default false), v (default false): Which plane to process.


### Changelog ###
#---------------
# Ported to ExTools, optimized gradient, changed 'show' behaviour (x4 speed gain) by Dogway
#---------------
# Changed global scope of quality_map to local.
#---------------
# Replaced mt_convolution with mt_edge for ~15% speed up.
#---------------
# Initial version by Asd-g.


function GMSD(clip dist, clip ref, bool "downsample", float "c", string "propName", bool "show_map", int "show", bool "Y", bool "U", bool "V", bool "fulls") {

    rgb      = isRGB (dist)
    w        = width (dist)
    h        = height(dist)
    isHD     = (w > 1099 || h > 599)
    bi       = BitsPerComponent(dist)
    fs       = propNumElements (dist,"_ColorRange")  > 0 ? \
               propGetInt      (dist,"_ColorRange") == 0 : rgb

    c        = Default(c, 0.0026)
    y        = Default(y, true)
    u        = Default(u, false)
    v        = Default(v, false)
    downscl  = Default(downsample, isHD)
    show_map = Default(show_map,  false)
    show     = Default(show,          0)  # 0: output 'dist'  1: output 'ref'  2: output 'dist' with subtitle
    fs       = Default(fulls,        fs)
    pn       = Default(propName,"_PlaneGMSD")

    clip1 = dist
    clip2 = ref

    Assert(IsVersionOrGreater(3,7,3),                         "GMSD: Update AviSynth+ version")
    Assert(PixelType(clip1) == PixelType(clip2),              "GMSD: clip1 and clip2 must be of the same format")
    Assert(w == clip2.Width() && h == clip2.Height(),         "GMSD: clip1 and clip2 must be of the same width and height")
    Assert((y && !u && !v)||(!y && u && !v)||(!y && !u && v), "GMSD: only one plane must be processed")

    clip1 = y ? ExtractY(clip1) : u ? ExtractU(clip1) : ExtractV(clip1)
    clip2 = y ? ExtractY(clip2) : u ? ExtractU(clip2) : ExtractV(clip2)

    if (downscl)
    {
        clip1 = _IQA_downsample(clip1, fulls=fs, fulld=true).ConvertBits(32, fulls=true, fulld=true)
        clip2 = _IQA_downsample(clip2, fulls=fs, fulld=true).ConvertBits(32, fulls=true, fulld=true)

    } else {

        clip1 = clip1.ConvertBits(32, fulls=fs, fulld=true) # saturating range for correct calculations
        clip2 = clip2.ConvertBits(32, fulls=fs, fulld=true)
    }

    # qprewitt gradient magnitude with ad hoc normalization
    krn         = ex_shape(1,center=false)
    quality_map = ex_lutxy(ex_edge(clip1, krn+"A D F + + C - E - H - dup *
                                               A B C + + F - G - H - dup * +", 0, 255, clamp_float=false),  \
                           ex_edge(clip2, krn+"A D F + + C - E - H - dup *
                                               A B C + + F - G - H - dup * +", 0, 255, clamp_float=false), Format("x y * sqrt 2 * {c} + x y + {c} + /"))

    last = show_map ?
    \ ScriptClip(quality_map, function[pn] () { propSet(last,pn, Sqrt(AverageLuma(Expr(last,"x "+ String(AverageLuma(last)) +" - dup *"))), 0) } ) :
    \ ScriptClip(show == 1 ? ref : dist, function [quality_map,pn] ()
        {
            avg = String(AverageLuma(quality_map))
            propSet(pn, Sqrt(AverageLuma(Expr(quality_map, "x "+ avg +" - dup *"))), 0)
        } )


    return show == 2 ? ScriptClip(function[pn] () { Subtitle("PlaneGMSD: " + String(propGetFloat(pn))) } ) : last }



/*

MDSI - Mean Deviation Similarity Index Calculator
This script is a port of the VapourSynth MDSI - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L4641


    MDSI is a full reference IQA model that utilizes gradient similarity (GS), chromaticity similarity (CS), and deviation pooling (DP).
    The lower the MDSI score, the higher the image perceptual quality.

    Larger MDSI values indicate more severe distorted images, while an image with perfect quality is assessed by a quality score of zero.
    The distortion degree of the distorted image will be stored as frame property '_PlaneMDSI' in the output clip.

    Note that bilinear downsampling is used in this implementation (but disabled by default), as opposed to the original paper.
    The gradient-chromaticity similarity map is saturated before deviation pooling, as described in II.D.
    Matrix used by rgb2gray() from MATLAB (similar to BT.601 matrix) is used for computation of luma component.

Ref:
    [1] Nafchi, H. Z., Shahkolaei, A., Hedjam, R., & Cheriet, M. (2016).
        Mean deviation similarity index: Efficient and reliable full-reference image quality evaluator.
        IEEE Access, 4, 5579-5590.
    [2] https://ww2.mathworks.cn/matlabcentral/fileexchange/59809-mdsi-ref-dist-combmethod
*/


### Requirements - AviSynth+ 3.7.3+, ExTools, TransformsPack and fmtconv (for downsample=true)


### Usage ###
###
# MDSI(clip clip1, clip clip2, int "down_scale", float "alpha", bool "show_map", bool "show")
###
## Parameters ##
#---------------
# clip1: The first clip to be evaluated (RGB 32-bit float), will be copied to output.
#---------------
# clip2: The second clip, to be compared with the first one.
#---------------
# downsample (default true): Whether to average the clips over local 2x2 window and downsample by a factor of 2 before calculation.
#---------------
# alpha (default 0.6): Weight used to merge Gradient Similarity (GS) map and Chromaticity Similarity (CS) map.
#---------------
# propName (default "_PlaneMDSI"): Identifier assigned to the metric frame property, in case you want to stack metrics against different distorted clips.
#---------------
# show_map (default false): Whether to return Gradient Similarity (GS), Chromaticity Similarity (CS) and pooled Gradient-Chromacity Similarity (GCS -linear combination of CS and GS-) maps. If it is true, interleaved clip of GS, CS, GCS will be returned. If it false, clip1 will be returned.
#---------------
# show (default 0): Decides output form. 0 returns 'distorted' with frameprops, 1 returns 'reference' with frameprops. 2 returns 'distorted' subtitled with MDSI value and frameprops,


### Changelog ###
#---------------
# Ported to ExTools and TransformsPack (137% speed gain) by Dogway. Also implemented back IQA downsample from the official paper.
#---------------
# Changed global scope of gcs to local.
#---------------
# Initial port version by Asd-g.


function MDSI(clip dist, clip ref, bool "downsample", float "alpha", string "propName", bool "show_map", int "show", bool "fulls") {

    rgb      = isRGB (dist)
    w        = width (dist)
    h        = height(dist)
    isHD     = (w > 1099 || h > 599)
    isUHD    = (w > 2599 || h > 1499)
    bi       = BitsPerComponent(dist)
    fs       = propNumElements (dist,"_ColorRange")  > 0 ? \
               propGetInt      (dist,"_ColorRange") == 0 : rgb

    downscl  = Default(downsample,  isHD)
    alpha    = Default(alpha,        0.6)
    show_map = Default(show_map,   false)
    show     = Default(show,           0)  # 0: output 'dist'  1: output 'ref'  2: output 'dist' with subtitle
    fs       = Default(fulls,         fs)
    pn       = Default(propName,"_PlaneMDSI")

    clip1 = dist
    clip2 = ref

    Assert(IsVersionOrGreater(3,7,3),                                                           "MDSI: Update AviSynth+ version")
    Assert(PixelType(clip1) == PixelType(clip2) && (IsPlanarRGB(clip1) || IsPlanarRGBA(clip1)), "MDSI: clip1 and clip2 must be in planar RGB format")
    Assert(w == clip2.Width() && h == clip2.Height(),                                           "MDSI: clip1 and clip2 must be of the same width and height")

    c1 = 140 / pow(255, 2)
    c2 = 55  / pow(255, 2)
    c3 = 550 / pow(255, 2)

    down1 = !downscl ? clip1 : _IQA_downsample(clip1, fulls=fs, fulld=true) # saturating range for correct calculations
    down2 = !downscl ? clip2 : _IQA_downsample(clip2, fulls=fs, fulld=true)

    down1 = down1.ConvertBits(bi, fulls=!downscl ? fs : true, fulld=true).ExtractClip()
    down2 = down2.ConvertBits(bi, fulls=!downscl ? fs : true, fulld=true).ExtractClip()

    l1    = isUHD ? DotClipA(down1,[0.262372,0.678464,0.059164]) : isHD ? DotClipA(down1,[0.212600,0.715179,0.072221]) : DotClipA(down1,[0.298912,0.586603,0.114485])  # Correct coefs for Luma (/wiki/Luma_(video)#Use_of_relative_luminance), but consider converting properly in linear light with greyscale_rgb()
    l2    = isUHD ? DotClipA(down2,[0.262372,0.678464,0.059164]) : isHD ? DotClipA(down2,[0.212600,0.715179,0.072221]) : DotClipA(down2,[0.298912,0.586603,0.114485])  # Correct coefs for Luma (/wiki/Luma_(video)#Use_of_relative_luminance), but consider converting properly in linear light with greyscale_rgb()
    l1l2  = Merge(l1, l2)

    # HVS (Human Visual System) based Gradient Similarity (GS)
    gs_hvs = ex_lutxyz(l1, l2, l1l2,Format("f32 z[-1,-1] A@ z[-1,0] z[-1,1] F@ + + z[1,-1] C@ - z[1,0] - z[1,1] H@ - dup *
                                                A C z[0,-1] + + F - H - z[0,1] - dup * + sqrt Z^
                                                x[-1,-1] A@ x[-1,0] x[-1,1] F@ + + x[1,-1] C@ - x[1,0] - x[1,1] H@ - dup *
                                                A C x[0,-1] + + F - H - x[0,1] - dup * + sqrt X^
                                                y[-1,-1] A@ y[-1,0] y[-1,1] F@ + + y[1,-1] C@ - y[1,0] - y[1,1] H@ - dup *
                                                A C y[0,-1] + + F - H - y[0,1] - dup * + sqrt Y@
                                                X * 2 * {c1} + X dup * XX@ Y dup * YY@ {c1} + + /
                                              X Z * 2 * {c2} +         XX  Z dup * ZZ@ {c2} + + / +
                                              Y Z * 2 * {c2} +         YY          ZZ  {c2} + + / -"), UV=1, scale_inputs="intf").ConvertBits(32, fulls=true, fulld=true)

    # Opponent color space
    h1 = DotClipA(down1,[0.30,0.04,0.35]).ConvertBits(32, fulls=true, fulld=true)
    h2 = DotClipA(down2,[0.30,0.04,0.35]).ConvertBits(32, fulls=true, fulld=true)
    m1 = DotClipA(down1,[0.34,0.60,0.17]).ConvertBits(32, fulls=true, fulld=true)
    m2 = DotClipA(down2,[0.34,0.60,0.17]).ConvertBits(32, fulls=true, fulld=true)

    if (show_map) {

        # Chromaticity Similarity (CS)
        cs  = ex_lutxyza(h1, h2, m1, m2, Format("x y * z a * + 2 * {c3} + x dup * y dup * z dup * a dup * {c3} + + + + /"), UV=1)
        # Gradient-Chromaticity Similarity (GCS)
        gcs = ex_lutxy(gs_hvs, cs, Format("x y - {alpha} * y + 0 1 clip 0.25 ^"), UV=1)

            if (show == 2) {
                gs_hvs = gs_hvs.Subtitle("gs_hvs",y=25, text_color=$2d2d2d, halo_color=$FFFFFF)
                cs     =     cs.Subtitle("cs"    ,y=25, text_color=$2d2d2d, halo_color=$FFFFFF)
                gcs    =    gcs.Subtitle("gcs"   ,y=25, text_color=$2d2d2d, halo_color=$FFFFFF)
            }

    } else {
        gcs = Expr(h1, h2, m1, m2, gs_hvs, Format("x y * z a * + 2 * {c3} + x dup * y dup * z dup * a dup * {c3} + + + + / dup b swap - {alpha} * + 0 1 clip 0.25 ^"))
    }


    last = ScriptClip(show_map ? Interleave(gs_hvs, cs, gcs) : show == 1 ? ref : dist, function [gcs,pn] ()
        {
            propSet(last,pn, pow(AverageLuma(Expr(gcs, "x "+ String(AverageLuma(gcs)) +" - abs")), 0.25), 0) # MAD
        })

    return show == 2 ? ScriptClip(function [show_map,pn] () { Subtitle(show_map ? ex_invert(last) : last, "PlaneMDSI: " + String(propGetFloat(pn))) } ) : last }





/*

SSIM - Structural SIMilarity Index Calculator
This script is a port of the VapourSynth SSIM - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L3529


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


### Requirements - AviSynth+ 3.7.3+, vsTCanny, ExTools and fmtconv (for downsample=true)


### Usage ###
###
# vsSSIM(clip clip1, clip clip2, bool "downsample", float "k1", float "k2", float "stddev", float "dynamic_range", bool "show_map", bool "show", bool "y", bool "u", bool "v")
###
## Parameters ##
#---------------
# clip1: The distorted clip (YUV 32-bit float), will be copied to output if "show_map" is False.
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
# propName (default "_PlaneSSIM"): Identifier assigned to the metric frame property, in case you want to stack metrics against different distorted clips.
#---------------
# show_map (default false): Whether to return SSIM index map. If not, "clip1" will be returned.
#---------------
# show (default 0): Decides output form. 0 returns 'distorted' with frameprops, 1 returns 'reference' with frameprops. 2 returns 'distorted' subtitled with SSIM value and frameprops,
#---------------
# y (default true), u (default false), v (default false): Which plane to process.


### Changelog ###
#---------------
# Sanitized and optimized by Dogway (x3 speed gain)
#---------------
# Changed global scope of ssim_map to local.
#---------------
# Initial version by Asd-g.


function vsSSIM(clip dist, clip ref, bool "downsample", float "k1", float "k2", float "stddev", float "dynamic_range", string "propName", bool "show_map", int "show", bool "Y", bool "U", bool "V", bool "fulls") {

    rgb      = isRGB (dist)
    w        = width (dist)
    h        = height(dist)
    isHD     = (w > 1099 || h > 599)
    bi       = BitsPerComponent(dist)
    fs       = propNumElements (dist,"_ColorRange")  > 0 ? \
               propGetInt      (dist,"_ColorRange") == 0 : rgb

    y        = Default(y,  true)
    u        = Default(u, false)
    v        = Default(v, false)
    k1       = Default(k1, 0.01)
    k2       = Default(k2, 0.03)
    downscl  = Default(downsample,   isHD)
    DR       = Default(dynamic_range, 1.0)
    stddev   = Default(stddev,        1.5)
    show_map = Default(show_map,    false)
    show     = Default(show,            0)  # 0: output 'dist'  1: output 'ref'  2: output 'dist' with subtitle
    fs       = Default(fulls,          fs)
    pn       = Default(propName,"_PlaneSSIM")

    clip1 = dist
    clip2 = ref

    Assert(IsVersionOrGreater(3,7,3),                         "vsSSIM: Update AviSynth+ version")
    Assert(PixelType(clip1) == PixelType(clip2),              "vsSSIM: clip1 and clip2 must be of the same format")
    Assert(w == clip2.Width() && h == clip2.Height(),         "vsSSIM: clip1 and clip2 must be of the same width and height")
    Assert((y && !u && !v)||(!y && u && !v)||(!y && !u && v), "vsSSIM: only one plane must be processed")

    c1 = pow(k1 * DR, 2)
    c2 = pow(k2 * DR, 2)

    clip1 = y ? ExtractY(clip1) : u ? ExtractU(clip1) : ExtractV(clip1)
    clip2 = y ? ExtractY(clip2) : u ? ExtractU(clip2) : ExtractV(clip2)

    if (downscl)
    {
        clip1 = _IQA_downsample(clip1, fulls=fs, fulld=true).ConvertBits(32, fulls=true, fulld=true)
        clip2 = _IQA_downsample(clip2, fulls=fs, fulld=true).ConvertBits(32, fulls=true, fulld=true)

    } else {

        clip1 = clip1.ConvertBits(32, fulls=fs, fulld=true) # saturating range for correct calculations
        clip2 = clip2.ConvertBits(32, fulls=fs, fulld=true)
    }

    mu1     = vsTCanny(clip1, sigmay=stddev, mode=-1) # gaussian blur
    mu2     = vsTCanny(clip2, sigmay=stddev, mode=-1)
    mu1_sq  = ex_lut(mu1,      "x 2 ^")
    mu2_sq  = ex_lut(mu2,      "x 2 ^")
    sigmay1_sq_pls_mu1_sq = vsTCanny(ex_lut  (clip1,        "x 2 ^"), sigmay=stddev, mode=-1)
    sigmay2_sq_pls_mu2_sq = vsTCanny(ex_lut  (clip2,        "x 2 ^"), sigmay=stddev, mode=-1)
    sigmay12_pls_mu1_mu2  = vsTCanny(ex_lutxy(clip1, clip2, "x y *"), sigmay=stddev, mode=-1)

    ssim_map = c1 > 0.0 && c2 > 0.0 ?
    \ Expr(sigmay12_pls_mu1_mu2, mu1_sq, mu2_sq, sigmay1_sq_pls_mu1_sq, sigmay2_sq_pls_mu2_sq, mu1, mu2, Format("c d * X@ 2 * {c1} + x X - 2 * {c2} + * y z + {c1} + a y - b z - + {c2} + * /")) :
    \ Expr(Expr(mu1_sq, mu2_sq, Format("x y + {c1} +")), Expr(sigmay1_sq_pls_mu1_sq, mu1_sq, sigmay2_sq_pls_mu2_sq, mu2_sq, Format("x y - z a - + {c2} +")), mu1, mu2, sigmay12_pls_mu1_mu2, Format("'x y * X@ 0 > z a * 2 * A@ {c1} + b 2 * A - {c2} + * X / x 0 = not y 0 = and A {c1} + x / 1 ? ?"))


    last = show_map ?
    \ ScriptClip(ssim_map, function[pn] () { propSet(last,pn, AverageLuma(last), 0) } ) :
    \ ScriptClip(show == 1 ? ref : dist, function [ssim_map,pn] ()
        {
            propSet(pn, AverageLuma(ssim_map), 0)
        } )


    return show == 2 ? ScriptClip(function[pn] () { Subtitle("PlaneSSIM: " + String(propGetFloat(pn))) } ) : last }



# BSSIM() by zorr from B-SSIM paper: "B-SSIM - Structural Similarity Index for Blurred Videos"
# Adapted by Dogway for optimization and read '_PlaneSSIM' (or 'propNameSSIM' defined) frame property
#
# Dependencies:
#     ExTools
#     vsTCanny
#     fmtconv  (for HD or downsample=true)

function BSSIM(clip dist, clip ref, bool "downsample", string "propName", string "propNameSSIM", int "show", bool "fulls") {

    w    = width (dist)
    h    = height(dist)
    isHD = (w > 1099 || h > 599)
    rgb  = isRGB(dist)
    bi   = BitsPerComponent(dist)
    fs   = propNumElements (dist,"_ColorRange")  > 0 ? \
           propGetInt      (dist,"_ColorRange") == 0 : rgb

    show = Default(show,        0)  # 0: output 'dist'  1: output 'ref'  2: output 'dist' with subtitle
    dw   = Default(downsample, isHD)
    fs   = Default(fulls,      fs)
    pn   = Default(propName,    "_PlaneBSSIM")
    pnS  = Default(propNameSSIM,"_PlaneSSIM")

    Assert(IsVersionOrGreater(3,7,3), "BSSIM: Update AviSynth+ version")

    vSSIM = propNumElements (dist, pnS)  > 0 ? \
                             dist            : vsSSIM(dist, ref, downsample=dw, fulls=fs)

    source  = ref
    blurred = vSSIM

    source8        =  source.ConvertBits(8, dither=-1, fulls=fs, fulld=true)
    blurred8       = blurred.ConvertBits(8, dither=-1, fulls=fs, fulld=true)

    scharr_orig    = ex_edge(source8,  "tritical", 0, 50) # Original paper uses 'sobel' but this is faster ('scharr' in original script)
    scharr_blurred = ex_edge(blurred8, "tritical", 0, 50)

    ScriptClip(show == 1 ? ref : dist, function [blurred, source8, blurred8, scharr_orig, scharr_blurred, pn, pnS, show] () {

        SSIM        = propGetFloat(blurred, pnS)

        mean8       = AverageLuma(scharr_orig)
        var8        = ex_lut(scharr_orig,   Format("x {mean8} - dup *"))
        varian_orig = AverageLuma(var8)
      # stddev_orig = sqrt(varian_orig)

        mean8       = AverageLuma(scharr_blurred)
        var8        = ex_lut(scharr_blurred,Format("x {mean8} - dup *"))
        varian_alt  = AverageLuma(var8)
      # stddev_alt  = sqrt(varian_alt)

        BSSIM = SSIM * (2*sqrt(varian_orig * varian_alt)) / (varian_orig + varian_alt)

        propSet(last,pn, BSSIM, 0)

        return show == 2 ? Subtitle(Format("PlaneBSSIM: {BSSIM}")) : last } ) }



# SVM() by Dogway
#
# Sharpness Variance Metric - An efficient metric index calculator for image sharpness/detail
#
# Dependencies:
#     ExTools

function SVM(clip a, int "rad", int "radV", string "mode", bool "emphasize", bool "aug", bool "Y", bool "U", bool "V", string "propName", int "show", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isY(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb

    show = Default(show,        0)  # 0: output 'diff'  1: output 'clip'  2: output 'diff' with subtitle
    rd   = Default(rad,         1)
    rdv  = Default(radV,       rd)
    md   = Default(mode, rd>1?"disk":"square")
    ep   = Default(emphasize,true) # Enable to emphasize low diffs to evaluate texture sharpness
    au   = Default(aug,      true) # Augment difference map
    y    = Default(y, true)
    u    = Default(u, false)
    v    = Default(v, false)
    fs   = Default(fulls,      fs)
    pn   = Default(propName, "_PlaneSharpness")

    Assert(IsVersionOrGreater(3,7,3),                         "SVM: Update AviSynth+ version")
    Assert((y && !u && !v)||(!y && u && !v)||(!y && !u && v), "SVM: Only one plane must be processed")

    clp = isy ? a : y ? rgb ? ExtractR(a) : ExtractY(a) : \
                    u ? rgb ? ExtractG(a) : ExtractU(a) : \
                        rgb ? ExtractB(a) : ExtractV(a)

    clp = clp.ConvertBits(32, dither=-1, fulls=fs, fulld=true)
    px  = ex_shape(rd,rdV,mode=md)

    # Could be optimized into a one-liner though
    mx = ex_luts(clp, mode="max", pixels=px)
    mn = ex_luts(clp, mode="min", pixels=px)
    av = ex_luts(clp, mode="avg", pixels=px)

    var = ex_lutxyz(av,mn,mx,(ep ? "y sqrt x sqrt X@ - dup * z sqrt X" : "y x - dup * z x") +  " - dup * + 0.5 *").ex_deflate()

    ScriptClip(show == 1 ? a : var, function [var,pn] () {
        propSet(last,pn, AverageLuma(var), 0) } )

    show != 1 ? ConvertBits(au ? ex_lut("x 4 *"):last, bi, dither=-1, fulls=true) : last

    show == 2 ? ScriptClip(function [pn] () {
        Subtitle("_PlaneSharpness: "+string(propGetFloat(pn))) } ) : last }





/*

SSIM downsampler - Structural SIMilarity downsampler

This script is port of the VapourSynth SSIM_downsample - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L3670

    SSIM downsampler is an image downscaling technique that aims to optimize for the perceptual quality of the downscaled results.
    Image downscaling is considered as an optimization problem where the difference between the input and output images is measured using famous Structural SIMilarity (SSIM) index.
    The solution is derived in closed-form, which leads to the simple, efficient implementation.
    The downscaled images retain perceptually important features and details, resulting in an accurate and spatio-temporally consistent representation of the high resolution input.

    This is an pseudo-implementation of SSIM downsampler with slight modification.
    The behaviour of convolution at the border is uniform.
    All the internal calculations are done at 32-bit float.

*/

### Requirements - AviSynth+, vsTCanny and ExTools.


### Usage ###
###
# SSIM_downsample(clip c, int target_width, int target_height, val "smooth", string "kernel", float "epsilon", string "resample_args", string "dither")
###
## Parameters ##
#---------------
# c: Source clip.
# 32-bit source clip is assumed full range otherwise it's internally converted.
#---------------
# target_width: The width of the output.
#---------------
# target_height: The height of the output.
#---------------
# smooth (default 1.5): The method to smooth the image.
# If it's a float, it specifies the "sigmaX" of vsTCanny.
# If it's a function, it acts as a general smoother.
#---------------
# kernel (default "Bicubic"): Resample kernel.
#---------------
# epsilon (default 0.000001)
#---------------
# resample_args (default ""): Additional resizer arguments.
#---------------
# dither (default true): Whether to perform dither for the final result.
# It has effect only for < 32-bit clip.


### Examples ###
/*
SSIM_downsample(1280,532)
# Downsampling with default kernel and default smooth (vsTCanny(sigmaX=1.5)).
*/
###
/*
SSIM_downsample(1280,532, resample_args="b=-0.6, c=0", dither=true, smooth="""ex_boxblur(1,mode="mean",UV=1)""")
# Downsampling with custom kernel arguments, custom smooth function and dither.
*/
###
/*
SSIM_downsample(w,h,smooth=0.43,resample_args="-0.6,0.4")
# High Quality Downsampling with custom kernel arguments and custom smooth sigma.
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
    rgb     = isRGB(c)
    bi      = BitsPerComponent(c)
    fs      = propNumElements (c,"_ColorRange")  > 0 ? \
              propGetInt      (c,"_ColorRange") == 0 : rgb

    smooth  = Default(smooth,       1.5)        # Can be a float or a string for a blurring function (ie. "ex_blur(1)")
    kernel  = Default(kernel, "Bicubic")+"Resize"
    epsilon = Default(epsilon, 0.000001)
    dither  = Default(dither,      true)
    fs      = Default(fulls,         fs)

    c.ConvertBits(32, fulls=fs, fulld=true)

    sw = String(target_width)
    sh = String(target_height)
    resample_args = (Defined(resample_args)) ? ", " + resample_args : ""

    l   = Eval(kernel + "(" + sw + "," +  sh + resample_args + ")")
    sqr = ex_lut(l, "x dup *", UV=3, scale_inputs="none")

    if (IsFloat(smooth))
    {
        m = vsTCanny(l,   sigmaY=smooth, mode=-1) # Gaussian blur
        n = vsTCanny(sqr, sigmaY=smooth, mode=-1)
        o = vsTCanny(Eval(kernel + """(ex_lut("x dup *", UV=3, scale_inputs="none"),""" + sw + "," +  sh + resample_args + ")"), sigmaY=smooth, mode=-1)

        r = ex_lutxyz(n, o, ex_lut(m, "x dup *", UV=3, scale_inputs="none"), Format("x z - X@ {epsilon} < 0 y z - X / sqrt ?"), UV=3, scale_inputs="none")

        m = vsTCanny(m, sigmaY=smooth, mode=-1)
        n = vsTCanny(r, sigmaY=smooth, mode=-1)
        o = vsTCanny(ex_lutxy(r, m, "x y *",     UV=3, scale_inputs="none"), sigmaY=smooth, mode=-1)

        ex_lutxyza(m, n, l, o, "y z * x + a -",  UV=3, scale_inputs="none")

    } else {

        m = l.Eval(smooth)
        n = ex_lut(m, "x dup *", UV=3, scale_inputs="none")
        r = ex_lutxyz(sqr.Eval(smooth), Eval(kernel + """(ex_lut("x dup *", UV=3, scale_inputs="none"),""" + sw + "," +  sh + resample_args + ")").Eval(smooth),  n, Format("x z - X@ {epsilon} < 0 y z - X / sqrt ?"), UV=3, scale_inputs="none")
        o = ex_lutxy(r, m, "x y *", UV=3, scale_inputs="none").Eval(smooth)
        ex_lutxyza(m.Eval(smooth), r.Eval(smooth), l, o, "y z * x + a -", UV=3, scale_inputs="none")
    }

    bi != 32 ? ConvertBits(bits=bi, dither= dither ? 1 : -1, fulls=true, fulld=fs) : \
               ConvertBits(bits=bi,                          fulls=true, fulld=fs) }





##############################
#                            #
#     HELPER FUNCTIONS       #
#                            #
##############################

/*
This function is a port of the VapourSynth _IQA_downsample - https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L3613

Downsampler for Image Quality Assessment model.
The “clip” is down-sampled by a factor of 2 with a 'Box' kernel, akin to processing 2x2 microblocks.
*/


### Requirements - fmtconv


### Changelog ###
#---------------
# Replaced with fmtc_resample(kernel="box"), faster and fixes chroma placement by Dogway. (fmtc_resample output is always 16-bit int, regardless of input bitdepth -except 32-bit float inputs-)
#---------------
# Replaced GeneralConvolution with Expr for >3.5x speed up.
#---------------
# Initial version by Asd-g.


function _IQA_downsample(clip c, bool "fulls", bool "fulld")
{
    return fmtc_resample(c, RoundHalfToEven(Width(c) / 2.0), RoundHalfToEven(Height(c) / 2.0), kernel="box", sx=-1, sy=-1, fulls=fulls, fulld=fulld)
}



/*
Round half to even - https://en.wikipedia.org/wiki/Rounding#Round_half_to_even

### Changelog ###
#---------------
# Updated from upstream. "Fixed check for negative numbers."
#---------------
# Added output value type (int or float) and edited RoundHalfToEven_mod2() to accept any mod type
#---------------
# Initial version
*/

function RoundHalfToEven(float n, string "type") {

    tp  = Default(type, "int")
    flt = tp != "int"

    if (Frac(n) == 0.0) {

        n = n

    } else if (Frac(n) == sign(n) * 0.5) {

        f = Floor(n)
        n = f % 2 == 0 ? f : Ceil(n)

    } else {

        n = Round(n)
    }

       return flt ? float(n) : round(n)
    }



function RoundHalfToEven_mod(float n, int "mod", string "type") {

    tp   = Default(type, "int")
    mod  = float(Default(mod, 2))
    flt = tp != "int"

    q = n / mod

    if (Frac(q) == 0.0) {

        n = n

    } else if (Frac(q) == sign(n) * 0.5) {

        f = Floor(q)
        n = f % 2 == 0 ? f * mod : Ceil(q) * mod

    } else {
        n = Round(q) * mod
    }

       return flt ? float(n) : round(n)
    }
