###########################################################
###                                                      ##
###                                                      ##
###    Transforms Pack v1.0 RC35  (30-01-2022)           ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182825    ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
###########################################################
###
### Pack of tools for proper color managing AviSynth+.
### From function transforms like performant piecewise gamma functions,
### to color gamut converters and a list of building block functions
### for matrix operations.
###
### All of them converge in ConvertFormat(). A simple and accurate to use
### All-In-One (AIO) filter to scale, convert and transform colors.
###
### ConvertFormat() supports color space, color model, transfer function, color range,
### chroma placement and chroma subsampling conversion among other features
### like chroma reconstruction, 'no ring' scaling, luma space scaling, and no-moirée scaling.
###
### ConvertFormat() replaces my old filter LinearResizer() (Dither Tools based)
### and is clearly inspired by cretindesalpes' fmtconv and avsresize's z_ConvertFormat().
### For a "no-fuss" high quality resizer you can use deep_resize() from ResizersPack.
###
###
### Dependencies: AviSynth+ 3.7.1+
###
####################################


function Display_Referred (clip clp, string "source", string "disp_ref", string "kernel", bool "gamut", bool "gamma", string "LUT", bool "tv_range", float "b", float "c", float "p") {

    rgb        = isRGB(clp)
    bi         = BitsPerComponent(clp)
    propIDs    = color_propGet(clp)
    fs         = !propIDs[6]

    gamut      = Default (gamut, true)        # convert gamut
    gamma      = Default (gamma, true)        # convert gamma
    source     = Default (source, propIDs[2]) # Source Color Space
    disp_ref   = Default (disp_ref,   "sRGB") # Display Referred Color Space
    kernel     = Default (kernel,  "Bicubic")
    LUT        = Default (LUT, Undefined())   # Display LUT (the path string of your monitor .cube 3D LUT, if calibrated)
    tv         = Default (tv_range, !fs )
    b          = Default (b, 0.00)
    c          = Default (c, 0.75)            # Precise Bicubic
    p          = Default (p, 0.25)

    Assert(IsVersionOrGreater(3,7,1), "Display_Referred: Update AviSynth+ version")

    bi < 32 ? clp.ConvertBits(16, fulls=fs) : clp

    src   = Color_Fuzzy_search (source)
    tgt   = Color_Fuzzy_search (disp_ref)
    s_gam = moncurve_coef (src[0]) # Primaries derived gamma
    t_gam = moncurve_coef (tgt[0])
    gamut = gamut && src[0] != tgt[0]

    rgb ? ConvertToPlanarRGB(src[0])                                       : \
          YUV_to_RGB(src[0], tv_range_in=tv, kernel=kernel, b=b, c=c, p=p)

    moncurve_f(s_gam[0], s_gam[1],tv,false)

    if (gamut) {
    mata = RGB_to_XYZ  (src[0],         list=true)
    matw = c_adaptation(src[0], tgt[0], list=true)
    matb = XYZ_to_RGB  (tgt[0],         list=true)
    MatrixClip( MatrixDot(MatrixDot(mata, matw), matb) ) }

    Defined(LUT) || gamma ? moncurve_r(t_gam[0], t_gam[1],false,false) : \
                    gamut ? moncurve_r(s_gam[0], s_gam[1],false,false) : last

    Defined(LUT) ? Cube(LUT, 4, true) : last

    ConvertBits(8, dither=1, fulls=false)  }



# Matches 'a' to 'b' clip format (size, length, color model, Jab, bitdepth)
function MatchClip (clip a, clip b, string "kernel", string "matrix", bool "props", bool "length", bool "fast") {

    krn    = Default (kernel, "Spline16")
    fst    = Default (fast,         true)
    fp     = Default (props,        true)
    mfc    = Default (length,      false) # Match also framecount

    Assert(IsVersionOrGreater(3,7,1), "MatchClip: Update AviSynth+ version")

    YUY2   = b.IsYUY2()
    rgbb   = b.isRGB()             rgba    = a.isRGB()
    w      = b.width()             wa      = a.width()
    h      = b.height()            ha      = a.height()
    fc     = b.FrameCount()        fca     = a.FrameCount()
    p_type = b.PixelType()         p_typea = a.PixelType()
    bib    = b.BitsPerComponent()  bia     = a.BitsPerComponent()

    propIDs = color_propGet(b)

    fs      = propNumElements(a,"_ColorRange")  > 0 ? \
              propGetInt     (a,"_ColorRange") == 0 : rgba

    fd      = propIDs[6]

    isUHD   = (w  > 2599 ||  h  > 1499)
    isUHDa  = (wa > 2599 ||  ha > 1499)

    mat     = Default(matrix, propIDs[2])
    mat     = ReplaceStr(mat, "Rec", "")


        a
        yv411  = b.isYV411()      yv411a = a.isYV411()
        yv444  = b.is444()        yv444a = a.is444()
        !yv411 && bib > bia ? ConvertBits(bib, fulls=fs, fulld=fs) : last

    if (!fst) {

        ConvertFormat(w, h, fmt_in=p_typea, fmt_out=p_type, cs_in=mat, cs_out="", kernel=krn, tv_range_in=!fs, tv_range_out=!fd, show=false)

    } else {

        rgbp   = rgbb && b.isPlanar()
        isScl  = w != wa || h != ha
        mod    = rgba && rgbb || isy(a) && isy(b) ? 1 : 2

        fmt    = Format_fuzzy_search(b, p_type,  bib)
        fmta   = Format_fuzzy_search(a, p_typea, bia)
        bc     = bicubic_coeffs(krn)
        krn    = bc[1]>=0. ? "Bicubic" : krn

        cplace  = rgbb || yv444  || yv411  ? "MPEG1" : isUHD  ? "top_left" : "MPEG2"
        cplacea = rgba || yv444a || yv411a ? "MPEG1" : isUHDa ? "top_left" : "MPEG2"
        not42   = LeftStr(fmta[1],2) != "42"

        # Match dimensions
        isScl ? w > h ? RatioResize(w,mode="adjust2w",kernel=krn,mod=mod,b=bc[0],c=bc[1]) : \
                        RatioResize(h,mode="adjust2h",kernel=krn,mod=mod,b=bc[0],c=bc[1]) : last
                        PadResize(w,h,mode="dilate",             mod=mod)

        # ConvertBackToYUY2 bug: https://forum.doom9.org/showthread.php?p=1038027#post1038027
        isy(b) ? rgba ? DotClip([0.298903,0.586620,0.114477]) : ConvertToY(mat)                                                                                         : \
        rgbb   ? rgbp ? Eval(  "ConvertToPlanarRGB            (mat,interlaced=false"+(yv411a || rgba ? ")" : ",ChromaInPlacement=cplacea,       chromaresample=krn)"))  : \
                        Eval(  "ConvertTo"   +string(fmt[3])+"(mat,interlaced=false"+(yv411a || rgba ? ")" : ",ChromaInPlacement=cplacea,       chromaresample=krn)"))  : \
        yv411         ? Eval(  "ConvertToYV411                (false,mat,"          +(not42 ? ""   :        """ChromaInPlacement=cplacea, """)+"chromaresample=krn)")   : \
        YUY2  && rgba ? Eval("""ConvertBackToYUY2             (      mat                                                                                        """)    : \
                        Eval(  "ConvertToYUV"+string(fmt[1])+"(false,mat"           +(not42 ? ""   :         ",ChromaInPlacement=cplacea")+(yv444 ? ")" : ",chromaresample=krn, ChromaOutPlacement=cplace)"))
    }

    clr = !rgbb ? fd ? $008080 : $108080 : \
                  fd ? $000000 : $101010

    !yv411 ? bia > bib ? ConvertBits(bib, dither=1, fulls=fd, fulld=fd)          : \
                         ConvertBits(bib,           fulls=fd, fulld=fd)          : last
     mfc   ? fca > fc  ? Trim(last, fc-1) : last+BlankClip(b,fc-1,color_yuv=clr) : last

    # Planar to Interleaved
    YUY2 && !rgba  ? ConvertToYUY2()               : last

    # Frame Properties
    if (fst && fp) {
    ID = Color_Fuzzy_search(mat)
                PropCopy(b)
    fd !=  fs ? PropSet("_ColorRange", fd ? 1 : 0) : last # Overrides the Convertto props
                PropSet("_Matrix",          ID[1])        # Overrides the Convertto props
                PropSet("_Primaries",       ID[2]) } }    # Disable this line and above when convertto supports writing to RGB frameprops (currently RGB is hardcoded to _Matrix 0 and _Primaries 2 -undefined-)





###
### ConvertFormat()
###
###
### Similar to avsresize's z_ConvertFormat() but more flexible, more options and more features:
### More color models and color space conversions, chroma reconstruction, scale_space, noring, mod size, ratio resize, kernel/matrix aliases (supports any resizer), presets, show settings, etc
###
### Dependencies: AviSynth+ 3.7.1 and over
###               ExTools
###               GradePack  (for show=true and 'sigmoid' scaling)
###               MasksPack  (for show=true)
###               KNLMeansCL (for UVRecon=true)
###               nnedi3     (for UVRecon=true)
###               SysInfo    (for UVRecon=true)
###               Optional resizer plugins (check links)
###
### Example 1 - Limited YUV to full RGB:
###     ConvertBits(10,fulls=true)     # RGB conversion from YUV requires at least 10-bit precision
###     ConvertFormat(1,1,"YUV","RGB")
###
### Example 2 - Scale HD Rec.709 YUV to SD Rec.601 YUV:
###     ConvertFormat(720,0) # 0 stands for automatic size given width/height ratio
###     or
###     ConvertFormat(preset="DVD-NTSC")
###
### Example 3 - YUV420 to YUV444 and scale up by 2 with chroma reconstruction and noring (cs_out to "" or "none" to skip color space autoconversion):
###     ConvertFormat(2,fmt_out="44",cs_out="",kernel="FSRCC",noring=true,UVRecon=true,cplace_in="MPEG2")
###
### Example 4 - Scale down by 2 with no moirée in sigmoid space (typically pre-blurring -for nomoiree- is done in linear light so "linear" is also a good option):
###     ConvertFormat(0.5,scale_space="sigmoid",kernel="RobiSharp",nomoiree=true)
###
### Example 5 - Scale width to 1280 and height to half:
###     ConvertFormat(1280,0.5)
###
### Example 6 - Convert from YUV444 to YUV422 and TV range to PC range:
###     ConvertFormat(1,1,fmt_out="422",tv_range_out=false,cplace_out="MPEG2")
###
### Example 7: High quality JPEG decoding and conversion to RGB
###   MP_Pipeline("""
###   ### platform: win32
###   JPEGSource("source.jpg",rec=3)
###   ### ###
###   """)
###   ConvertBits(16)
###   Implicit:
###       ConvertFormat(1,1,"YUV","RGB","jpeg","sRGB",UVRecon=true)
###   Explicit:
###       ConvertFormat(1,1,"YUV","RGB","jpeg","sRGB",false,false,true,cplace_in="MPEG1",UVRecon=true)
###   ConvertBits(8, dither=1)
###
####################################


# List of Color Models:
# Color Models -not to be confused with Color Spaces- describe the geometry coordinates of the color gamut container and hence its relation (or correlation) with the other channels. They are typically designed or tailored to certain Color Spaces, but not necesarily bound to them like RGB or YCbCr which support many different Color Spaces and thus are nicked Color Absolute Models
#
# With *: Color Appearance Models (CAM) (Perceptually Uniform to various degrees)
# With +: HDR aware
# With -: Implemented
#
# CMYK         - Color model used in print industry
#-RGB+         - RGB color model for channels Red, Green, and Blue. Normally found in interleaved packing format. AviSynth works best with planar RGB so a conversion is first needed.
#-OPP          - by Liang et al. RGB opponent space
# NOPP         - by Liang et al.
# COPP         - by Liang et al.
# rg           - Photometric invariant (shadows, shading) 2 channel color representation, by Danelljan [R/(R+G+B), G/(R+G+B)]
# I1I2I3       - by Guo and Lyu [0.3333*(R+G+B),0.5*(R-B),0.25*(2G-R-B)]
# C1C2C3       - by Salvador et al.
# LSLM         - RGB opponent space based on the signals of the cones: black-white, red-green, and yellow-blue
# YES          - by Saber et al.
# UVW          - by Ohta et al.
# SO           - Biologically Inspired Color Image Descriptor
#-YCbCr        - Color format roughly based on human perception of luma and chroma contribution (approximately perceptually uniform). Uses 3 planes for Luma, opposing blue-yellow, and opposing red-green. It's a 45º skewed parallelogram relative to the square RGB box, therefore only 23.6% of its color volume matches RGB and 76.4% is out of RGB gamut.
# YIQ          - YCbCr with (YCbCr) UV axes rotated 33º, used for NTSC TV analogue system. Quote from avisynth.nl/index.php/Tweak: "In YIQ, orange and teal are along the in-phase (I) axis, while green and magenta are along the quadrature (Q) axis. The eye is far more sensitive to detail along the I axis than along the Q axis, and NTSC allocated more bandwidth for I than for Q."
# YDbDr        - PAL-N and SECAM TV analogue format
#-YUVr         - "YUV RCT". Same as YUV but fully reversible to RGB
# sYUV         - "Sharp YUV". Same as YUV but luma-weighted chroma subsampling, retaining chroma fidelity.
#-YcCbcCrc     - YCbCr Constant Luminance (CL). Better decorrelation than YCbCr.
# xvYCC        - Expanded Gamut YCbCr. For newer TV systems it was/is a model that allowed the color gamut (typically Rec709) to be stored in the full range while luma in the narrow range.
#-YCoCg        - Better luma/chroma decorrelation and compression efficiency than YCbCr
#-YCoCgR       - Same as YCoCg but losslessly reversible to RGB
#-XYZ          -
# LSY          - Reads lambda-SY. Spectral color space. Representation based on brightness, dominant wavelength and saturation attributes. LSY color coordinates are defined from xyY color coordinates.
#-YDzDx+       - HDR version of XYZ. Requires at least 10-bit for no visible quantization.
# YCxCz        - Color Space for image fidelity metrics. It's a first step space, you have to "filter" it and then convert to Lab to retrieve error delta.
# DCI XYZ      - XYZ space in DCI illuminant. In effect it's just a container for DCI-P3 in XYZ coordinates for delivery to theaters.
# Yxy/xyY      - Chroma normalized XYZ space which gives full luma/chroma decorrelation. Not apt for HDR, use YDzDx+ instead.
#-HSV          - Cylindrical representation of RGB. Not recommended as it doesn't take into account human luminance perception
#-Duv*         -
# HunterLab*   - A more perceptually uniform version of CIELab
#-CIELab*      - Derived from CIEXYZ, one of the first approaches to a perceptually uniform color model. You can derive it's Delta E with the next equation: DE = (DL^2 + Da^2 + Db^2)/2  = ( (Ly-Lx)^2 + (ay-ax)^2 + (by-bx)^2)/2
# CIELch(ab)*  - HCL (polar coordinates or cylindrical) version of CIELab
# CIEsLab*     - CIE simple Lab
# R-Lab*       - Ruderman Lab space, using log luma and different weights for ab
# L-Lab*       -
# SRLab2*      - A 2009 modification of CIELAB in the spirit of RLAB (with discounting-the-illuminant). Uses CIECAM02 chromatic adaptation matrix to fix the blue hue issue.
#-CIELuv*      -
# CIELch(uv)*  - HCL (polar coordinates or cylindrical) version of CIELuv
# HSLuv*       - A cylindrical HSL type adaptation of CIELuv
# LogLuv*+     - HDR version of CIEluv, that uses log to encode HDR values in a 15-bit container
# Y''U''V''*+  - HDR version of CIEluv by Poynton. Improves on LogLuv by using a PQ transfer which just needs 12-bits
# CIEDuDv*+    - or YDuDv. HDR version of CIE Luv. Requires only 8-bit for no visible quantization.
# CIECAM97s*   -
# XYB*         - A family of uniform (UCS) spaces used in Guetzli and JPEG XL, with a main goal in compression. Better uniformity than CIELAB.
# JzAzBz*+     - A 2017 uniform (UCS) space designed for HDR color. Has J (lightness) and two chromaticities.
# JzCzhz*+     - HCL (polar coordinates or cylindrical) version of JzAzBz
#-IPT*         - Intensity Protanope Tritanope. A more uniform color space in SDR colors. There's a version called hdrIPT
# ICaCb+       - Precursor and arguably better color model than ICtCp which based on this
# ICtCp+       - BT.2100 (HDR + Rec.2020) version of IPT. HDR version of YcCbcCrc but with Constant Intensity this time.
# ITP*+        - Perceptually uniform color space version of ICtCp, used extensively in error metrics by scaling Ct by 0.5. This transformation is the basis of the Rec.2124 wide gamut color difference metric D.itp (simple scaled Euclidean distance: 720*sqrt(Di^2+D(t*0.5)^2+Dp^2) )
# IPTPQc2*+    - Improved HDR10 version of ICtCp. Since it's a propietary space no much information is known.
# CIECAM02*    - Improves on CIECAM97s and can be made uniform with CAM02-UCS.
# CIECAM02Jch* -
# OSA*         -
# CAM16*       - Not yet a CIE standard. Improves on CIECAM02 and can be made uniform with CAM16-UCS, which works "out-of-the-box" for Euclidean distance metrics.
# ZCAM*+       - A uniform (UCS) space for HDR color.
#-Oklab*       - A uniform (UCS) space for SDR color. Simple to compute yet powerful. Takes CAM16 lightness and chroma, and IPT for hue.
#-OkLch*       - The cylindrical form of Oklab
# iCAM06       - An image (not only color) appearance metric model to not only compute perceived difference in lightness, hue or chroma, but also contrast, sharpness or graininess. Involves converting to IPT, low-pass filtering in linear space, convert to non-linearity, then to Jch model and QM if necessary for the metrics.


# Resizer Plugins:
#
# SimpleResize (2 tap lin) (8-bit)            (dw) https://avisynth.nl/index.php/SimpleResize (same than Box/Area but without pixel centering, very fast)
# Box/Dirichlet/Area Average                  (dw) https://github.com/EleonoreMizo/fmtconv or https://github.com/Aktanusa/AreaResize
# SSIM                                        (dw) https://github.com/mysteryx93/AviSynthShader/releases
# SSIM_downsample                             (dw) https://github.com/Dogway/Avisynth-Scripts/blob/master/EX%20mods/SimilarityMetrics.avsi ( HQ settings: SSIM_downsample(w,h,smooth=0.43,resample_args="-0.6,0.4") )
# DPID                                        (dw) https://github.com/Asd-g/AviSynth-DPID       (Best downscaler followed by SSIM_downsample > SSIM >>> SincLin > Zopti)
# SincLin2ResizeMT                         (up,dw) https://github.com/jpsdr/ResampleMT/releases (like a sharper lanczos)
# Spline100/Spline144                         (up) https://github.com/EleonoreMizo/fmtconv
# SinPowResizeMT                              (dw) https://github.com/jpsdr/ResampleMT/releases
# Jinc (EWA Lanczos)                          (up) https://github.com/Asd-g/AviSynth-JincResize/releases
# FCBI (Fast Curve Based Interp) (8-bit)      (up) https://github.com/chikuzen/FCBI/releases
# SuperResXBR                                 (up) https://github.com/mysteryx93/AviSynthShader/releases
# AiUpscale/FSRCNN (FastSuperResolutionConvo) (up) https://github.com/Alexkral/AviSynthAiUpscale/tree/master/Shaders (lineart / photo folders)
# KrigBilateral                               (up) https://github.com/Alexkral/AviSynthAiUpscale/tree/master/Shaders/KrigBilateral

# Internal:
# Point / Nearest       (actually slower than bicubic!)
# Bilinear / Triangular
# Bicubic  / Cubic               (not recommended for highly quantized content: JPEGs, H.264, etc)
# Spline   / Cubic Polynomials   (spline16 -2 lobes- spline36 -3 lobes- spline64 -4 lobes-)
# Sinc     is a box-windowed      sinc filter (2 lobes).
# Lanczos  is a Lanczos-windowed  sinc filter (3 lobes).
# Blackman is a Blackman-windowed sinc filter (3 lobes). (improved lanczos with less ringing)

# Missing. ref: https://github.com/mpv-player/mpv/blob/master/video/out/filter_kernels.c
#          ref: https://artoriuz.github.io/blog/mpv_upscaling.html
#          ref: https://en.wikipedia.org/wiki/Window_function
#          ref: https://legacy.imagemagick.org/Usage/filter/nicolas/
# Bartlett          is a Bartlett-windowed sinc filter (3 lobes)
# Hann(ing)         is a Hanning-windowed  sinc filter (3 lobes)
# Hamming           is a Hamming-windowed  sinc filter (3 lobes)
# Welch/Welsh       is a Welch-windowed    sinc filter (parabolic window, 3 lobes)
# Cosine            is a Cosine-windowed   sinc filter (3 lobes)
# Bessel            is a unnormalized      sinc filter (3 lobes)
# Ginseng           is a Jinc-windowed     sinc filter (3 lobes). Better for HBD than ewa_lanczos3.
# Bohman            is a Bohman-windowed   sinc filter (3 lobes)
# Kaiser            is a Kaiser-windowed   sinc filter (3 lobes)
# Parzen            is a Parzen-windowed   sinc filter (3 lobes)
# Lagrange
# Jinc              is a Box-windowed      jinc filter (3.2383154841662362 lobes). Jinc filters are not separable so they're usually slower than sinc, cubic, etc but more pleasant artifacts. See here: https://legacy.imagemagick.org/Usage/filter/#cylindrical
# ewa_hanning       is a Hanning-windowed  jinc filter (3.238 lobes).
# ewa_ginseng       is a sinc-windowed     jinc filter (3.238 lobes).
# -ewa_lanczos      is a lanczos-windowed  jinc filter (3.238 lobes).
# -ewa_lanczossharp is a lanczos-windowed  jinc filter (3.238 lobes). Slightly sharpened as per calculations by Nicolas Robidoux. Can be replicated with Jinc filter and blur = 0.9812505644269356
# -ewa_lanczossharpest is a lanczos-windowed jinc filter (3.238 lobes). Very sharp, technically not recommended by Robidoux except when downscaling. Can be replicated with Jinc filter and blur = 0.88549061701764
# -ewa_lanczos2sharp   is a lanczos-windowed jinc filter (2.2331305943815286 lobes). Good alternative to the other EWAs when you don't want the moiree or "hash pattern blur" artifact, so use this for dithered content or RobiSharp.
# -ewa_lanczosradius3  is a lanczos-windowed jinc filter (3 lobes). More sharpened than ewa_lanczossharp and very similar to Ginseng tensor. Can be replicated with Jinc filter and blur = 0.9264075766146068 (scales lobes from 3.238 to 3)
# -ewa_lanczos4     is a lanczos-windowed  jinc filter (4.2410628637960699 lobes).
# -ewa_lanczossoft  is a lanczos-windowed  jinc filter (3.238 lobes). Softened instead. This one makes hash patterns disappear completely. Can be replicated with Jinc filter and blur = 1.015
# -Haasnsoft        is a Hanning-windowed  jinc filter (3.238 lobes). Removes almost all aliasing. Blur value to match orthogonal and diagonal contributions. Can be replicated with Jinc filter and blur = 1.11
# Tukey             is a Hanning-windowed  jinc filter taper = 0.5
# Quadratic/Quadric like Cubic but 66% faster (1.5 taps/lobes)
# RAVU / RAISR      similar to XBR and nnedi3
# NGU               Next Generation Upscaler. madVR edge directed NN algo (closed source, similar to FSRCNN)
# Sphinx            Continuation of Sinc and Jinc. interpolating all three dimensions at the same time using a carefully constructed filter that has a perfectly spherical frequency response. 1.4302966531242027, sphinx window.
# ICBI              (Iterative Curve Based Interpolation) is a single image superresolution technique described in Fast artifact-free image interpolation by Andrea Giachetti and Nicola Asuni, presented at BMVC 2008

function ConvertFormat (clip clp, val "width", val    "height", string   "fmt_in", string  "fmt_out", string   "cs_in", string   "cs_out", string      "OETF", string   "EOTF", string "D_in", string "D_out", bool "tv_in", bool "tv_out", string "cplace_in", string "cplace_out", \
                         string "scale_space", string "kernel", string "kernel_c", float  "src_left", float  "src_top", float "src_width", float "src_height",                                                                                                                       \
                                 float "taps", int       "mod", bool   "nomoiree", bool     "noring", bool   "UVrecon", bool     "show") {
    clp
    wu         = !Defined(width)
    hu         = !Defined(height)
    w          = width ()
    h          = height()
    fc         = FrameCount() < 2
    p_type     = PixelType()
    bi         = BitsPerComponent()
    lut1       = bi == 32 ? 0 : 1
    lut2       = bi  < 16 ? 2 : 0
    propIDs    = color_propGet()


    nw         = Default (width,   1)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target width
    nh         = Default (height, nw)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target height
    i_fmt      = Format_fuzzy_search (Default (fmt_in,  p_type), bi)
    o_fmt      = Format_fuzzy_search (Default (fmt_out, p_type), bi)
    isRGBi     = i_fmt[0]=="RGB"
    isRGBo     = o_fmt[0]=="RGB"

    isRGBi ? ConvertToPlanarRGB() : last

    mod        = Default (mod, isRGBo ? 1 : 2) # mod size for resizing. ie: 1, 2, 4, 8, 16...

    Assert(isFloat(nw) || isFloat(nh), "ConvertFormat: Width/Height type not supported.") # isFloat(int) also returns true, so good for 'number' type evaluation
    nw         = isInt(nw) && nw<=10 ? float(nw) : isFloat(nw) && nw>10. ? int(nw) : nw
    nh         = isInt(nh) && nh<=10 ? float(nh) : isFloat(nh) && nh>10. ? int(nh) : nh
    nw         =  nw<=10. ? w*nw : nw            nw     = round(nw/mod)*mod
    nh         =  nh<=10. ? h*nh : nh            nh     = round(nh/mod)*mod

    nw         =  nw == 0 || wu ? round((w*(nh/float(h)))/mod)*mod : nw
    nh         =  nh == 0 || hu ? round((h*(nw/float(w)))/mod)*mod : nh

    isUHD      = ( w > 2599 ||   h > 1499)     isnUHD = (nw > 2599 ||  nh > 1499)
    isHD       = ( w > 1099 ||   h > 599 )     isnHD  = (nw > 1099 ||  nh > 599 )

    wr         = float(nw) / w                 hr     = float(nh) / h     # for nomoiree
    rat        = max(abs(wr - 1),abs(hr - 1)) == abs(wr - 1) ? wr : hr    # for nomoiree

    # DEFAULTS
    Und        = Undefined()
       cs_in_d = Defined (cs_in)
      cs_out_d = Defined (cs_out)
    cs_in      = Default (cs_in_d  ? cs_in ==""  ? Und   : cs_in : cs_in,                          fc ? "jpeg" : propIDs[2])
       cs_inFA = Color_Fuzzy_search (cs_in)
       cs_inF  = cs_inFA[0]
    cs_out     = Default (cs_out_d ? cs_out =="" ? cs_in : cs_out : cs_out, cs_in_d ? cs_in : (cs_in == "jpeg" || cs_in == "jpg" || cs_inF == "sRGB") && isRGBo ? "sRGB" : isnUHD ? "2020" : isnHD ? "709" : "601")
      cs_outFA = Color_Fuzzy_search (cs_out)
      cs_outF  = cs_outFA[0]
    OETF       = Default (Defined(OETF) ? OETF =="" ? Und  : OETF : OETF,  cs_in_d  ? cs_in ==""  ? propIDs[5] : cs_in : propIDs[5])
    EOTF       = Default (Defined(EOTF) ? EOTF =="" ? OETF : EOTF : EOTF,  cs_out) # By default derived from space
          OETF = Color_Fuzzy_search (OETF)[0]
          EOTF = Color_Fuzzy_search (EOTF)[0]
       tv_in_d = Defined (tv_in)
    tv_in      = Default (tv_in,                    !(isRGBi || cs_inF =="sRGB" || cs_in =="jpeg" || cs_in =="jpg") && propIDs[6] )
    tv_out     = Default (tv_out, tv_in_d ? tv_in : !(isRGBo || cs_outF=="sRGB" || cs_out=="jpeg" || cs_out=="jpg") )
    kernel     = Default (kernel,   (w>nw||h>nh)?"Didee":"Precise")
    kernel_c   = Default (kernel_c, kernel)
    space      = Default (scale_space, "gamma")  # resizing space: "gamma", "linear", "sigmoid" or "log" for quasi-log. Assumes gamma encoded input. ("luminance weighted gamma resampling/sharpening"" Improvement over sigmoid: https://forum.doom9.org/showthread.php?p=1687374#post1687374) or (http://web.archive.org/web/20150420001849/http://forum.luminous-landscape.com/index.php?topic=91754.msg763345#msg763345)
    cplace_in  = Default (cplace_in,   "")       # Assumes default from format
    cplace_out = Default (cplace_out,  "")       # Assumes default from format
    D_in       = Default (Defined(D_in)  ? D_in  =="" ? Und  : D_in  : D_in , cs_in_d  ? cs_in ==""  ? propIDs[2] : cs_in : propIDs[2])
    D_out      = Default (Defined(D_out) ? D_out =="" ? D_in : D_out : D_out, D_in) # By default same as input, change based on space?
        D_in   = Color_Fuzzy_search (D_in )[0]
        D_outA = Color_Fuzzy_search (D_out)
        D_out  = D_outA[0]
    pd         = Defined (taps)
    p          = Default (taps,       9)  # 'p' value for GaussianResize() or 'taps' for Lanczos, Blackman, Sinc, EWA, etc
    src_left   = Default (src_left, 0.0)
    src_top    = Default (src_top,  0.0)
    src_width  = Default (src_width,  w)
    src_height = Default (src_height, h)
    noring     = Default (noring,  false)
    nomoir     = Default (nomoiree,false)
    recon      = Default (UVrecon, false)
    fs         = !tv_in
    dg         = Default (show,    false)


#    PRESETS
#                                DoVi/DVp5/DVp7     PQ10/UHD       HLG10         HD    DVD-NTSC    DVD-PAL        DV    CRT-NTSC    CRT-PAL     Master     Archival      Grade     Theater    JPEG2000    JPG_old      JPG
#    fmt_out       = Select (num,     "IPTPQc2",     "YCbCr",    "YCbCr",   "YCbCr",    "YCbCr",   "YCbCr",  "YCbCr",     "YIQ",     "YUV",     "RGB",       "RGB",      "RGB",     "YUVr",     "YUVr",  "YCbCr",   "sYCC") # sYCC is basically sRGB (prims, transfer, range) over YCbCr, but uses true Rec709 derived matrix coeffs, not from 470M
#    prims         = Select (num,        "2020",      "2020",     "2020",     "709",     "170M",   "470BG",        4,    "170M",   "470BG",  "DCIXYZ",       "AP0",      "AP1",   "DCIXYZ",     "sRGB",   "170M",   "sRGB") # JPG_old uses sRGB primaries but with 170M (470M derived) matrix, a mess: https://en.wikipedia.org/wiki/YCbCr#Chromaticity-derived_luminance_systems
#    Jab           = Select (num,         "420",       "420",      "420",     "420",      "420",     "420",    "410",     "411",     "411",     "444",       "444",      "444",      "444",      "444",    "420",    "422")
#    tv_out        = Select (num,         false,        true,       true,      true,       true,      true,    false,      true,      true,     false,       false,      false,      false,      false,    false,    false)
#    cplace_out    = Select (num,    "top_left",  "top_left", "top_left",   "MPEG2",    "MPEG2",   "MPEG2",     "DV",   "MPEG1",   "MPEG1",        "",          "",         "",         "",         "",  "MPEG1",  "MPEG1")
#    D_out         = Select (num,         "D65",       "D65",      "D65",     "D65",      "D65",     "D65",        4,     "601",     "601",       "E",       "D60",      "D60",        "E",      "D65",    "D65",    "D65")
#    EOTF          = Select (num,          "PQ",        "PQ",      "HLG",    "1886",     "170M",     "470",        4,    "170M",    "170M",     "DCI",    "linear",  "ACESCCt",      "DCI",     "sRGB",   "170M",   "sRGB")
#    PAR           = Select (num,             1,           1,          1,         1,      "601",     "470",        4,     "601",     "601",         1,           1,          1,          1,          1,        1,        1)
#    cdc           = Select (num,        "H265",      "H265",     "H265",    "H264",     "H262",    "H262",   "H261",        "",        "",    "TIFF",       "PIZ",      "PIZ","MJPEG2000", "JPEG2000",    "JPG",    "JPG")
#    cont          = Select (num,          "TS",        "TS",       "TS",      "TS",      "VOB",     "VOB",  "MPEG2",        "",        "",    "TIFF",       "EXR",      "EXR",      "mj2",      "jp2",    "JPG",    "JPG")
#    bit           = Select (num,            12,          10,         10,         8,          8,         8,        8,        "",        "",        16,          16,         32,         12,          8,        8,        8)



    ############ Data extraction and normalization + Asserts ############

                 Assert(IsVersionOrGreater(3,7,1), "ConvertFormat: Update AviSynth+ version")
    !(space=="sigmoid" || space=="gamma" || space=="linear" || space=="log") ? \
                 Assert(false, "ConvertFormat: Invalid space type.")         : nop()


    cs_in    = cs_inF
    cs_out   = cs_outF
    space    = space  != "" && space  != "none" ? space : "gamma"

    isGamma  = OETF      !=  EOTF
    isSpace  = cs_in     !=  cs_out
    isFrmt   = i_fmt[0]  !=  o_fmt[0]
    isIllu   = D_in      !=  D_out
    isScale  = nw!=w     ||  nh!=h
    isJab    = i_fmt[1]  !=  o_fmt[1]
    isChP    = cplace_in != cplace_out

    coef_i   =           Matrix_coef(cs_in)
    coef_o   = isSpace ? Matrix_coef(cs_out) : coef_i
    s_gam    =           moncurve_coef (OETF)
    t_gam    = isGamma ? moncurve_coef (EOTF) : s_gam
    kernel   = kernel == "Bilcubic" ? w*h < nw*nh ? "BilcubicU" : "BilcubicD" : kernel
    bc       = bicubic_coeffs(kernel)
    bc_b     = bc[1]>=0.?bc[0]:1/3.
    bc_c     = bc[1]>=0.?bc[1]:1/3.
    kernel   = bc[1]>=0. ? "Bicubic" : kernel

    i_type4  = i_fmt[1] == "444"         o_type4  = o_fmt[1] == "444"
    i_type2  = i_fmt[1] == "422"         o_type2  = o_fmt[1] == "422"
    i_type1  = i_fmt[1] == "411"         o_type1  = o_fmt[1] == "411"
    i_type10 = i_fmt[1] == "410"         o_type10 = o_fmt[1] == "410"

    cow      = i_type4 ?  w : i_type1 || i_type10 ? round( w/4.0) : round( w/2.0)
    coh      = i_type4 ||     i_type1 || i_type2  ?             h : round( h/2.0)
    cnw      = o_type4 ? nw : o_type1 || o_type10 ? round(nw/4.0) : round(nw/2.0)
    cnh      = o_type4 ||     o_type1 || o_type2  ?            nh : round(nh/2.0)

     i_type1  || o_type1        ? Assert(bi == 8,    "ConvertFormat: Unsupported Pixel Type: HBD YUV411")          : nop()
     i_type10 || o_type10       ? Assert(false,      "ConvertFormat: Unsupported Pixel Type: YUV410")              : nop()
     !isRGBi                    ? Assert( h%2==0,    "ConvertFormat: Clip Height is not mod2" )                    : nop()
     i_type2||i_fmt[1]=="420"   ? Assert( w%2==0,    "ConvertFormat: Clip Width is not mod2" )                     : nop()
     i_type1                    ? Assert( w%4==0,    "ConvertFormat: Clip Width is not mod4" )                     : nop()
     o_type1                    ? Assert(nw%4==0,    "ConvertFormat: Target Width is not mod4" )                   : nop()
    !(isRGBo ||  o_type4 || (cnw>cow || cnh>coh))                                                                  ? \
                                  Assert(!recon,     "ConvertFormat: Invalid settings for chroma reconstruction.") : nop()


    resampler = Format( kernel == "nnedi3"       ?  "deep_resize({nw},{nh}"                                  : \
                        kernel == "Bicubic"      ?  "BicubicResize({nw},{nh},b={bc_b},c={bc_c}"              : \
                        kernel == "Spline100"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=5"""      : \
                        kernel == "Spline144"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=6"""      : \
                        kernel == "SincLin"      || kernel == "SincLin2ResizeMT"                             ? \
                                                 "SincLin2ResizeMT({nw},{nh},taps=16"                        : \
                        kernel == "SinPow"      || kernel == "SinPowResizeMT"                                ? \
                                                 "SinPowResizeMT({nw},{nh}"                                  : \
                        kernel == "SSIM"        || kernel == "ResizeShader"                                  ? \
                                                   """ResizeShader({nw},{nh},kernel="SSIM",b=0.1"""          : \
                        kernel == "SSIM2"                                                                    ? \
                                        """SSIM_downsample({nw},{nh},smooth=0.43,resample_args="-0.6,0.4" """: \
                        kernel == "Gauss"        ?    "GaussResize({nw},{nh},p=pd?9:p"                       : \
                        kernel == "Nearest" || kernel == "NearestNeighbour" || kernel == "NN"                ? \
                                                      "GaussResize({nw},{nh},p=100"                          : \
                        kernel == "Average"  || kernel == "Box" || kernel == "Dirichlet" || kernel == "Area" ? \
                                                     """fmtc_resample({nw},{nh},kernel="box" """             : \
                        kernel == "Sinc"         ?     "SincResize({nw},{nh},taps=pd?p:4"                    : \
                        kernel == "Blackman"     ?     "BlackmanResize({nw},{nh},taps=pd?p:5"                : \
                        kernel == "Lanczos"      ?     "LanczosnResize({nw},{nh},taps=pd?p:3"                : \
                        kernel == "DPID"         ?     "DPID({nw},{nh},lambdaY=0.5"                          : \
                        kernel == "EWA"          || kernel == "Jinc"       || kernel == "ewa_lanczos"        ? \
                                                       "JincResize({nw},{nh},tap=pd?p:3"                     : \
                        kernel == "EWASharp2"    || kernel == "JincSharp2" || kernel == "ewa_lanczos2sharp"  ? \
                                                       "JincResize({nw},{nh},tap=2,blur=0.9549963639785485"  : \
                        kernel == "EWASharp"     || kernel == "JincSharp"  || kernel == "ewa_lanczossharp"   ? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.9812505644269356"  : \
                        kernel == "EWASharp4"    || kernel == "JincSharp4" || kernel == "ewa_lanczos4sharp"  ? \
                                                       "JincResize({nw},{nh},tap=4,blur=0.9885973386557245"  : \
                        kernel == "EWASharper2"  || kernel == "JincSharper2"||kernel =="ewa_lanczosradius2"  ? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.895603689740279282": \
                        kernel == "EWASharper"   || kernel == "JincSharper"|| kernel =="ewa_lanczosradius3" || kernel =="Ginseng" ? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.9264075766146068"  : \
                        kernel == "EWASharper4"  || kernel == "JincSharper4"||kernel =="ewa_lanczosradius4"  ? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.943159799432847707": \
                        kernel == "EWASharpest"  || kernel == "JincSharpest"|| kernel =="ewa_lanczossharpest"? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.88549061701764"    : \
                        kernel == "EWASoft"      || kernel == "JincSoft"   || kernel == "ewa_lanczossoft"    ? \
                                                       "JincResize({nw},{nh},tap=3,blur=1.015"               : \
                        kernel == "Haasn"        || kernel == "HaasnSoft"  || kernel == "ewa_haasn"          ? \
                                                       "JincResize({nw},{nh},tap=3,blur=1.11"                : \
                        kernel == "FCBI"         ? "FCBI().BicubicResize({nw},{nh},b=-0.6,c=0.4"             : \
                        kernel == "SuperResXBR"  || kernel == "XBR"                                          ? \
                                                         "SuperResXBR(factor=2)."                              \
                                                   +"BicubicResize({nw},{nh},b=-0.6,c=0.4"                   : \
                        kernel == "Krig"         || kernel == "KrigBilateral"                                ? \
                                    "KrigBilateral().BicubicResize({nw},{nh},b=-0.6,c=0.4"                   : \
                        kernel == "FSRCC"        || kernel == "AiUpscale"                                    ? \
                                             """AiUpscale(2,Luma="Medium",Chroma="Spline36",Mode="Photo")."""  \
                                                   +"BicubicResize({nw},{nh},b=0.378216,c=0.310892"          : \
                        kernel +                           "Resize({nw},{nh}"                                 )


    src_nul = kernel == "ResizeShader" || kernel == "SSIM" || kernel == "SSIM2" || kernel == "DPID" || kernel == "nnedi3" || kernel == "FSRCC" || kernel == "Krig" || kernel == "FCBI" || kernel == "SuperResXBR"
    src_box = kernel == "Simple" || kernel == "Average" || kernel == "Box" || kernel == "Area" || kernel == "Spline100" || kernel == "Spline144"
    src_wh  = src_box ? Format(",sw={src_width},sh={src_height}") : Format(",src_width={src_width},src_height={src_height}")
    src_whc = src_box ? Format(",sw={cow},     sh={coh}")         : Format(",src_width={cow},      src_height={coh}")
    fmtcb   = Format(".ConvertBits({bi},fulls={fs})")
    src_nr  = src_nul ? ")" : src_box ? "" : Format(",src_left={src_left},src_top={src_top}"+src_wh+")")     # take into account cplace
    src_c   = src_nul ? ")" : src_box ?      Format(",sx={src_left},sy={src_top}"+src_wh+")"+fmtcb) : src_nr # take into account cplace
    Ynr     = Format(".Repair(BicubicResize(Y,{nw},{nh},0,0"+src_nr+",1)")  # noring uses Hermite kernel. Check here if I need -1 for chroma

    cplace  = chroma_placement(w, h, nw, nh, cs_in, cs_out, i_fmt[0], o_fmt[0], i_fmt[1], o_fmt[1], cplace_in, cplace_out )


    cplaceY  = (src_nul || src_box ? "" : ",src_left=" +string(src_left)+",src_top="+string(src_top) + src_wh ) + ")" + fmtcb
    point    = kernel=="Point" ? "+1.0" : ""
    c_point  = kernel=="Point" ? i_type4 ?  1.0 : i_type1 || i_type10 ? round( 1*4.0) : round( 1*2.0) : 0
    c_point  = c_point *(float(cow)/cnw)  # chroma scaled
    src_left = i_type4 ?  src_left : i_type1 || i_type10 ? round( src_left*4.0) : round( src_left*2.0)
    src_left = src_left*(float(cow)/cnw)  # chroma scaled
    src_top  = i_type4 || i_type1 || i_type2  ? src_top  : round( src_top *2.0)
    src_top  = src_top *(float(coh)/cnh)  # chroma scaled

    cplaceH  = (src_box ? ",sx=" : ",src_left=")+string(cplace[0]+src_left+c_point)
    cplaceV  = (src_box ? ",sy=" :  ",src_top=")+string(cplace[1]+src_top)
    cplaceC  = (src_nul ? ""     : (cplaceH + cplaceV + src_whc)) + ")" + fmtcb


    c_kernel = InternalFunctionExists(kernel+"resize") || FindStr(LCase(kernel), "nearest") > 0 ? kernel : "bicubic"
    c_recon  = """threads = SI_LogicalCores()
                  cores   = SI_PhysicalCores()
                  c_cplace= chroma_placement(w*2, h*2, fcnw, fcnh, cs_in, cs_out, i_fmt[0], o_fmt[0], i_fmt[1], o_fmt[1], cplace_in, cplace_out )
                  ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), "auto", wref=1)
                  Luma    = ref.ConvertBits(8,dither=-1,fulls=fs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2,range=fs?1:2).ConvertBits(bi,fulls=fs)
                  Uu      =  Cb.ConvertBits(8,dither=-1,fulls=fs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=bc_b, ep1=bc_c, cshift=kernel+"resize", csresize=true, mpeg2=cplace_in=="MPEG2",range=fs?1:2).ConvertBits(bi,fulls=fs)
                  Vu      =  Cr.ConvertBits(8,dither=-1,fulls=fs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=bc_b, ep1=bc_c, cshift=kernel+"resize", csresize=true, mpeg2=cplace_in=="MPEG2",range=fs?1:2).ConvertBits(bi,fulls=fs)
                  Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=-0.5, c=0.25, src_left=c_cplace[0]+src_left, src_top=c_cplace[1]+src_top)
                  Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=-0.5, c=0.25, src_left=c_cplace[0]+src_left, src_top=c_cplace[1]+src_top)
                  Cb      = ex_makeadddiff(Unew, Removegrain(Unew, 19), Uu.BicubicResize(fcnw, fcnh, b=-0.5, c=0.25, src_left=c_cplace[0]+src_left, src_top=c_cplace[1]+src_top))
                  Cr      = ex_makeadddiff(Vnew, Removegrain(Vnew, 19), Vu.BicubicResize(fcnw, fcnh, b=-0.5, c=0.25, src_left=c_cplace[0]+src_left, src_top=c_cplace[1]+src_top))"""




    # Only scaling (or change in range, or gamma, or chroma placement, or subpixel shift, or odd cropping)
    if (!isSpace && !isIllu && !isFrmt && !isJab) {

        UVr = isRGBi ? 3 : 1
        space == "linear"  ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr)                                     : \
        space == "sigmoid" ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr).ex_contrast(-1.15,0,191,false,UVr)  : \
        space == "log"     ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr).ACEScct_f(UV=UVr)                   : \
                   isGamma ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr)                                     : last

        if (isRGBi) {

            nomoir ? ex_blur((1. / rat) / 2., mode="gaussian") : last
            Ynr   = ReplaceStr(Ynr, "(Y,", "(")
            Eval("" + resampler + cplaceY + (noring ? Ynr : ""))

        } else {

            Y   = ExtractY()
            Cb  = ExtractU()
            Cr  = ExtractV()

            if (recon && !i_type4) {

                Eval(ReplaceStr(c_recon, "fcn", "cn"))

            } else {

                str  = ReplaceStr(ReplaceStr(resampler, "("+string(nw), "("+string(cnw)), ","+string(nh), ","+string(cnh))
                str  = (cnw==cow && cnh==coh) ? Format("PointResize({cnw},{cnh}") : str # if chroma is not scaled (or scaled down to original) then use point as its faster and lossless
                Cb   = Eval("Cb." + str + cplaceC)
                Cr   = Eval("Cr." + str + cplaceC)
            }

            Ynr  = ReplaceStr(Ynr, "(Y,", "(")
            Y    = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y    = Eval("Y." + resampler + cplaceY + (noring ? Ynr : ""))


            CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+i_fmt[1]+i_fmt[2])
        }

        space == "linear"  ?                                   moncurve_r(t_gam[0], t_gam[1], false, tv_out, UVr) : \
        space == "sigmoid" ? ex_contrast(1.15,0,191,false,UVr).moncurve_r(t_gam[0], t_gam[1], false, tv_out, UVr) : \
        space == "log"     ? ACEScct_r(UV=UVr).                moncurve_r(t_gam[0], t_gam[1], false, tv_out, UVr) : \
                   isGamma ?                                   moncurve_r(t_gam[0], t_gam[1], false, tv_out, UVr) : last

        tv_in != tv_out ? space == "gamma"    ?     SMPTE_legal(tv_out,3,  3) : \
                          isScale && !isRGBi  ?     SMPTE_legal(tv_out,1,  3) : \
                         !isScale && !isGamma ? clp.SMPTE_legal(tv_out,UVr,3) : last : last

    } else {

        if (!isRGBi) {


        if (isScale && (isRGBo || !isSpace && !isIllu)) {

            space == "linear"  ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 1)                                  : \
            space == "sigmoid" ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 1).ex_contrast(-1.15,0,191,false,1) : \
            space == "log"     ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 1).ACEScct_f(UV=1)                  : \
                                 last
        }

        Y   = ExtractY()
        Cb  = ExtractU()
        Cr  = ExtractV()

        fcnw = (isSpace || isIllu) && !isRGBo ? w : cnw
        fcnh = (isSpace || isIllu) && !isRGBo ? h : cnh


        if (recon && !i_type4) {

            Eval(c_recon)

        } else {

            str  = ReplaceStr(ReplaceStr(resampler, "("+string(nw), "("+string(fcnw)), ","+string(nh), ","+string(fcnh))
            str  = (fcnw==cow && fcnh==coh) ? Format("PointResize({fcnw},{fcnh}") : str # if chroma is not scaled (or scaled down to original) then use point as its faster and lossless
            Cb   = Eval("Cb." + str + cplaceC)
            Cr   = Eval("Cr." + str + cplaceC)
            }


        if (isScale && (isRGBo || !isSpace && !isIllu)) {

            Y     = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y     = Eval("Y." + resampler + src_c + (noring ? Ynr : ""))
            Y     = space == "linear"                  ? Y.                                moncurve_r(s_gam[0], s_gam[1], false, !(isRGBo || !tv_out), 1) : \
                    space == "sigmoid"                 ? Y.ex_contrast(1.15,0,191,false,1).moncurve_r(s_gam[0], s_gam[1], false, !(isRGBo || !tv_out), 1) : \
                    space == "log"                     ? Y.ACEScct_r(UV=1).                moncurve_r(s_gam[0], s_gam[1], false, !(isRGBo || !tv_out), 1) : \
                                                         Y
            }


        if (!isRGBo && !isSpace && !isIllu) {

            CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt[1]+o_fmt[2])
            tv_in != tv_out ? space == "gamma" ? SMPTE_legal(tv_out,3,  3) : \
                              isScale          ? SMPTE_legal(tv_out,1,  3) : \
                             !isScale          ? SMPTE_legal(tv_out,UVr,3) : last : last
            }


        if (isRGBo || isSpace || isIllu) {

            if (i_fmt[0]=="YcCbcCrc" || cs_in == "Rec2020CL") {

                RGB = YcCbcCrc_to_RGB( Y, Cb, Cr, cs_in, coef_i, !(isScale || !tv_in), !(isSpace || !tv_out))

                R = RGB[0]  G = RGB[1]  B = RGB[2]

            } else if (i_fmt[0]=="YCoCg") {

            } else if (i_fmt[0]=="YCoCgR") {

            } else if (i_fmt[0]=="YUVr") {

            } else if (i_fmt[0]=="OkLab") {

            } else if (i_fmt[0]=="HSV") {

            } else if (i_fmt[0]=="OPP") {

            } else if (i_fmt[0]=="ICtCp") {

            } else if (i_fmt[0]=="YCbCr") {

                scale_y   = tv_in && (isSpace || isIllu || !tv_out) ? (255 / 219.) : !tv_in && !(isSpace || isIllu || !tv_out) ? (219 / 255.) : 1.0
                scale_uv  = tv_in && (isSpace || isIllu || !tv_out) ? (255 / 112.) : !tv_in && !(isSpace || isIllu || !tv_out) ? (224 / 128.) : 2.0

                Kr = 1. - coef_i[0]
                Kb = 1. - coef_i[2]

                m0 = scale_y     m1 = 0.0                                       m2 = scale_uv * Kr
                m3 = scale_y     m4 = scale_uv * ( -Kb * coef_i[2] / coef_i[1]) m5 = scale_uv * ( -Kr * coef_i[0] / coef_i[1])
                m6 = scale_y     m7 = scale_uv * Kb                             m8 = 0.0

                range_PC = scale_y == 255/219. ? "ymin - " : ""
                range_TV = scale_y == 219/255. ? "ymin + " : ""
                UVf      = bi < 32             ? "range_half - " : ""

                R = Expr(Y,     Cr, ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+"                            y "+UVf + string(m2)+" * + ", bi, !tv_in), optSingleMode=false, lut=lut2)
                G = Expr(Y, Cb, Cr, ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m4)+" * + z "+UVf + string(m5)+" * + ", bi, !tv_in), optSingleMode=true , lut=   0)
                B = Expr(Y, Cb,     ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m7)+" * +                            ", bi, !tv_in), optSingleMode=false, lut=lut2)

            }

        !isSpace && !isIllu ? CombinePlanes(R, G, B, planes="RGB", pixel_type=o_fmt[3]+o_fmt[2]) : last } }

    if (isRGBi) {

        isSpace || isIllu || isGamma ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 3) : last
        R = ExtractR()
        G = ExtractG()
        B = ExtractB()

    } else if (isSpace || isIllu || isGamma && isRGBi) {

        R = R.moncurve_f(s_gam[0], s_gam[1], false, false, 1)
        G = G.moncurve_f(s_gam[0], s_gam[1], false, false, 1)
        B = B.moncurve_f(s_gam[0], s_gam[1], false, false, 1)
     }

    if (isSpace || isIllu || isGamma && isRGBi) {

        mata = RGB_to_XYZ  (cs_in,         list=true)
        matw = c_adaptation(D_in, D_out,   list=true)
        matb = XYZ_to_RGB  (cs_out,        list=true)
        mat  = MatrixDot(MatrixDot(mata, matw), matb)

        Ro = "x "+string(mat[0])+" * y "+string(mat[3])+" * + z "+string(mat[6])+" * +"
        Go = "x "+string(mat[1])+" * y "+string(mat[4])+" * + z "+string(mat[7])+" * +"
        Bo = "x "+string(mat[2])+" * y "+string(mat[5])+" * + z "+string(mat[8])+" * +"

        if (!isRGBo) {
        Ro = Expr(R, G, B, Ro, optSingleMode=true)
        Go = Expr(R, G, B, Go, optSingleMode=true)
        Bo = Expr(R, G, B, Bo, optSingleMode=true)
        R = Ro  G = Go  B = Bo
        } else { Expr(R, G, B, Ro, Go, Bo, Format=o_fmt[3]+o_fmt[2], optSingleMode=true) }


    if (isRGBi && isRGBo && isScale) {


        RGB  = space == "linear"  ? isSpace || isIllu || isGamma ?                             last : moncurve_f(s_gam[0], s_gam[1], false, false, 3)                                    : \
               space == "sigmoid" ? isSpace || isIllu || isGamma ? ex_contrast(-1.15,0,191,false,3) : moncurve_f(s_gam[0], s_gam[1], false, false, 3).ex_contrast(-1.15,0,191,false,3)   : \
               space == "log"     ? isSpace || isIllu || isGamma ? ACEScct_f(UV=3)                  : moncurve_f(s_gam[0], s_gam[1], false, false, 3).ACEScct_f(UV=3)                    : \
               isSpace || isIllu  ?                                                                   moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3)                                   : \
                                    last

        RGB   = nomoir ? RGB.ex_blur((1. / rat) / 2.,mode="gaussian") : RGB
        RGBnr = ReplaceStr(Ynr, "(Y,", "(RGB,")
        RGB   = Eval("RGB." + resampler + src_c + (noring ? RGBnr : ""))

               space == "linear"  ? RGB.                                moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3) : \
               space == "sigmoid" ? RGB.ex_contrast(1.15,0,191,false,3).moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3) : \
               space == "log"     ? RGB.ACEScct_r(UV=3).                moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3) : \
                                    RGB

        } else if (isRGBo) {

               moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3)
        } }

    if (!isRGBo && (isSpace || isIllu) || isRGBi && isFrmt) {

        R = isSpace || isIllu || isGamma ? R.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && !isIllu && tv_in, false, 1) : R
        G = isSpace || isIllu || isGamma ? G.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && !isIllu && tv_in, false, 1) : G
        B = isSpace || isIllu || isGamma ? B.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && !isIllu && tv_in, false, 1) : B

        if (o_fmt[0]=="YcCbcCrc" || cs_out == "Rec2020CL") {

            YCbCr = RGB_to_YcCbcCrc( R, G, B, cs_out, coef_o, !(isSpace || isIllu || !tv_in), tv_out)

            Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]

            } else if (o_fmt[0]=="YCoCg") {

            } else if (o_fmt[0]=="YCoCgR") {

            } else if (o_fmt[0]=="YUVr") {

            } else if (o_fmt[0]=="OkLab") {

            } else if (o_fmt[0]=="HSV") {

            } else if (o_fmt[0]=="OPP") {

            } else if (o_fmt[0]=="ICtCp") {

            } else if (o_fmt[0]=="YCbCr") {

            scale_y   = !(isSpace || isIllu || !tv_in) && (isScale || !tv_out) ? ( 255 / 219.) : (isSpace || isIllu || !tv_in) && !(isScale || !tv_out) ? ( 219 / 255.) : 1.0
            scale_uv  = !(isSpace || isIllu || !tv_in) && (isScale || !tv_out) ? ( 255 / 112.) : (isSpace || isIllu || !tv_in) && !(isScale || !tv_out) ? ( 112 / 255.) : 0.5

            Kr = 1. - coef_o[0]
            Kb = 1. - coef_o[2]

            m0 = scale_y  *   coef_o[0]       m1 = scale_y  *   coef_o[1]         m2 = scale_y  *   coef_o[2]
            m3 = scale_uv * (-coef_o[0] / Kb) m4 = scale_uv * (-coef_o[1] / Kb)   m5 = scale_uv
            m6 = scale_uv                     m7 = scale_uv * (-coef_o[1] / Kr)   m8 = scale_uv * (-coef_o[2] / Kr)

            rangeY_TV = scale_y==219/255. ? "ymin +" : \
                        scale_y==255/219. ? "ymin -" : ""
            rangeC_TV = bi < 32           ? "range_half +" : ""

            Y  = Expr(R, G, B, ex_dlut("x "+rangeY_TV+" "+string(m0)+" * y "+rangeY_TV+" "+string(m1)+" * + z "+rangeY_TV+" "+string(m2)+" * + ",              bi, !tv_in), optSingleMode=true)
            Cb = Expr(R, G, B, ex_dlut("x "+rangeY_TV+" "+string(m3)+" * y "+rangeY_TV+" "+string(m4)+" * + z "+rangeY_TV+" "+string(m5)+" * + "+rangeC_TV+"", bi, !tv_in), optSingleMode=true)
            Cr = Expr(R, G, B, ex_dlut("x "+rangeY_TV+" "+string(m6)+" * y "+rangeY_TV+" "+string(m7)+" * + z "+rangeY_TV+" "+string(m8)+" * + "+rangeC_TV+"", bi, !tv_in), optSingleMode=true)

        }

        if (isScale) {

            Y    = space == "linear"  ? Y.moncurve_f(t_gam[0], t_gam[1], false, false, 1)                                  : \
                   space == "sigmoid" ? Y.moncurve_f(t_gam[0], t_gam[1], false, false, 1).ex_contrast(-1.15,0,191,false,1) : \
                   space == "log"     ? Y.moncurve_f(t_gam[0], t_gam[1], false, false, 1).ACEScct_f(UV=1)                  : \
                                        Y
            }

        str  = ReplaceStr(ReplaceStr(resampler, "("+string(nw), "("+string(cnw)), ","+string(nh), ","+string(cnh))
        str  = (cnw==cow && cnh==coh) ? Format("PointResize({cnw},{cnh}") : str # if chroma is not scaled (or scaled down to original) then use point as its faster and lossless
        Cb   = Eval("Cb." + str + cplaceY)
        Cr   = Eval("Cr." + str + cplaceY)

        if (isScale) {
            Y    = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y    = Eval("Y." + resampler + src_c + (noring ? Ynr : ""))

            Y    = space == "linear"  ? Y.                                moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1) : \
                   space == "sigmoid" ? Y.ex_contrast(1.15,0,191,false,1).moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1) : \
                   space == "log"     ? Y.ACEScct_r(UV=1).                moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1) : \
                   tv_out             ? Y.SMPTE_legal(tv_out,3,1)                                                          : \
                                        Y
            }

        CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt[1]+o_fmt[2])

        } }

        # Frame Properties

        isSpace || isFrmt ? PropSet("_Matrix", isRGBo?0:o_fmt[4]==-1?cs_outFA[1]:o_fmt[4])       : last # Yes, again, hardcoding matrix for RGB to 0
        isSpace           ? PropSet("_Primaries",o_fmt[5]==0||o_fmt[5]==-1?cs_outFA[2]:o_fmt[5]) : last # Same here
        isIllu            ? PropSet("_Illuminant",                        D_outA[3])             : last
        isGamma           ? PropSet("_Transfer",        Color_Fuzzy_search(EOTF)[4])             : last
        tv_in != tv_out   ? PropSet("_ColorRange",      tv_out?1:0)                              : last
        isChP             ? PropSet("_ChromaLocation",  cplace[2])                               : last

        # Show panel
        if (dg) {

            w2   = width()
            h2   = height()
            sw  = nmod(w2/5.)   sh = sw
            plt = GradientLinear(last, zoom=1, positive=true, smooth=true, tv_range=tv_in)
            plt = plt.moncurve_r(t_gam[0], t_gam[1], tv_in, tv_out, 1)
            plt = plt.HistoCurve(size=1,gradient=false)
            plt = plt.BicubicResize(sw,sh,-0.5,0.25).Subtitle("EOTF: "+EOTF)
            plt = PadBorders(plt,w2-sw,0,0,h2-sh)
            plt = Merge(isRGBo ? plt.ConvertToPlanarRGB() : plt)
            ex_merge(plt,BoxMask(w2-sw,w2,0,sh),UV=3)


            i_jab  = i_fmt[1]
            i_fmt  = i_fmt[0]
            o_jab  = o_fmt[1]
            o_fmt  = o_fmt[0]
            c_col  = cplace[0]
            c_cot  = cplace[1]
            tv_i   = tv_in  ? "Lim" : "Full"
            tv_o   = tv_out ? "Lim" : "Full"
            msize  = min(nw,nh)

            bg     = BoxMask(0,round(msize/1.6),0,round(msize/1.3),invert=true, tv_out=tv_out)
            ex_blend(bg,"multiply",opacity=0.5,tv_range=tv_out)

            Subtitle(" ConvertFormat() 1.0 RC35",               size=msize/16,lsp=4,text_color=$00aef0,font="Segoe UI")
            Subtitle("\n\n SETTINGS:",                          size=msize/25,lsp=4)
            Subtitle(Format("\n\n\n\n\n "       \
                           +"width:\n "         \
                           +"height:\n "        \
                           +"model:\n "         \
                           +"OETF/EOTF:\n "     \
                           +"colorspace:\n "    \
                           +"D in/out:\n "      \
                           +"jab:\n "           \
                           +"range:\n "         \
                           +"cplacement:\n "    \
                           +"clocation:\n "     \
                           +"kernel:\n "        \
                           +"noring:\n "        \
                           +"nomoiree:\n "      \
                           +"UVrecon:"),                        size=msize/25,lsp=4)
            Subtitle(Format("\n\n\n\n IN\n "    \
                           +"{w} \n "           \
                           +"{h} \n "           \
                           +"{i_fmt} \n "       \
                           +"{OETF} \n "        \
                           +"{cs_in} \n "       \
                           +"{D_in} \n "        \
                           +"{i_jab} \n "       \
                           +"{tv_i} \n "        \
                           +"{cplace_in} \n "   \
                           +string(c_col,"%1.3f")+" \n "\
                           +"{kernel} \n "      \
                           +"{noring} \n "      \
                           +"{nomoir} \n "      \
                           +"{recon}"),            x=msize/4,   size=msize/25,lsp=4)
            Subtitle(Format("\n\n\n\n OUT\n "   \
                           +"{nw} \n "          \
                           +"{nh} \n "          \
                           +"{o_fmt} \n "       \
                           +"{EOTF} \n "        \
                           +"{cs_out} \n "      \
                           +"{D_out} \n "       \
                           +"{o_jab} \n "       \
                           +"{tv_o} \n "        \
                           +"{cplace_out} \n "  \
                           +string(c_cot,"%1.3f")),x=msize/2.25,size=msize/25,lsp=4)
    } }







####### FORMAT CONVERSION FUNCTIONS #######



# YCbCr to RGB standalone function
function YUV_to_RGB (clip yuv, string "matrix", bool "tv_range_in", bool "tv_range_out", string "kernel", float "b", float "c", float "p", string "cplace", bool "UVrecon") {

    matrix     = Default (matrix, "709")
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, !(matrix=="JPEG" || matrix=="JPG"))
    tv_out     = Default (tv_range_out, false)
    cplace     = Default (cplace, "")
    recon      = Default (UVrecon, false)
    b          = Default (b, 0.0)
    c          = Default (c, 0.75)               # Precise Bicubic
    p          = Default (p, 0.25)

    Assert(IsVersionOrGreater(3,7,1), "YUV_to_RGB: Update AviSynth+ version")
    Assert(!isRGB(yuv),               "YUV_to_RGB: Only YUV format supported")

    bi       = BitsPerComponent(yuv)
    lut      = bi < 16 ? 2 : 0
    p_type   = Format_fuzzy_search(yuv, PixelType(yuv), bi)
    matrix   = Color_Fuzzy_search (matrix)
    coef     = Matrix_coef(matrix[0])
    bc       = bicubic_coeffs(kernel)
    bc_b     = string(bc[1]>=0.?bc[0]:b)
    bc_c     = string(bc[1]>=0.?bc[1]:c)
    kernel   = bc[1]>=0. ? "Bicubic" : kernel

    p_type4  = p_type[1] == "444"
    p_type2  = p_type[1] == "422"
    p_type1  = p_type[1] == "411"
    p_type10 = p_type[1] == "410"

    w  = width (yuv)
    h  = height(yuv)
    nw = p_type4 ? w : p_type1 || p_type10 ? round(w/4.0) : round(w/2.0)
    nh = p_type4 ||    p_type1 || p_type2  ?            h : round(h/2.0)

    cplace  = chroma_placement(w, h, w, h, matrix[0], matrix[0], "YUV", "RGB", p_type[1], "444", cplace, "center" )

     p_type1             ? Assert(bi == 8,    "YUV_to_RGB: Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10,  "YUV_to_RGB: Unsupported Pixel Type: YUV410")

                           Assert(h%2==0,     "YUV_to_RGB: Height is not mod2" )
    !p_type1 || !p_type4 ? Assert(w%2==0,     "YUV_to_RGB: Width is not mod2" )                 : nop()
     p_type1             ? Assert(w%4==0,     "YUV_to_RGB: Width is not mod4" )                 : nop()

    point   = kernel=="Point" ? "+1.0" : ""
    cplaceH = ",src_left="+string(cplace[0])+point
    cplaceV = ",src_top ="+string(cplace[1])

    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(w) + "," + String(h) + cplaceH + cplaceV +")"                       : \
                kernel == "bicubic"?   "BicubicResize(" + String(w) + "," + String(h) + cplaceH + cplaceV +",b="+bc_b+",c="+bc_c+")" : \
                kernel == "gauss"  ?     "GaussResize(" + String(w) + "," + String(h) + cplaceH + cplaceV +",p=p)"                   : \
                                     kernel + "Resize(" + String(w) + "," + String(h) + cplaceH + cplaceV +")"

    Y   = ExtractY(yuv)
    Uor = ExtractU(yuv)
    Vor = ExtractV(yuv)

    # feisty2's ChromaReconstructor_faster v3.0 HBD mod

    if (recon && !p_type4) {

        cores   = SI_PhysicalCores()
        threads = SI_LogicalCores()

        ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), "auto", wref=1)
        Luma    = ref.ConvertBits(8,dither=-1,fulls=!tv_in).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2,range=fs?1:2).ConvertBits(bi,fulls=!tv_in)
        Uu      = Uor.ConvertBits(8,dither=-1,fulls=!tv_in).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=0.0, ep1=0.75, cshift="bicubicresize", mpeg2=false,range=fs?1:2).ConvertBits(bi,fulls=!tv_in)
        Vu      = Vor.ConvertBits(8,dither=-1,fulls=!tv_in).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=0.0, ep1=0.75, cshift="bicubicresize", mpeg2=false,range=fs?1:2).ConvertBits(bi,fulls=!tv_in)
        Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=-0.5, c=0.25)
        Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=-0.5, c=0.25)
        U       = ex_makeadddiff(Unew, Removegrain(Unew, 19), Uu.BicubicResize(w, h, b=-0.5, c=0.25))
        V       = ex_makeadddiff(Vnew, Removegrain(Vnew, 19), Vu.BicubicResize(w, h, b=-0.5, c=0.25))

    } else {

        U   = p_type4 ? Uor : Eval("Uor." + resampler)
        V   = p_type4 ? Vor : Eval("Vor." + resampler)

        }


    if (matrix[0]=="Rec2020CL" || matrix[0]=="DCI-P3" || matrix[0]=="Display-P3") {

        RGB = YcCbcCrc_to_RGB( Y, U, V, matrix[0], coef, tv_in, tv_out)

        R = RGB[0]  G = RGB[1]  B = RGB[2]

    } else {

        scale_y   = tv_in ? (255 / 219.) : 1.0
        scale_uv  = tv_in ? (255 / 112.) : 2.0

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y     m1 = 0.0                                   m2 = scale_uv * Kr
        m3 = scale_y     m4 = scale_uv * ( -Kb * coef[2] / coef[1]) m5 = scale_uv * ( -Kr * coef[0] / coef[1])
        m6 = scale_y     m7 = scale_uv * Kb                         m8 = 0.0

        rangeY   = tv_in   ? "ymin - "                          : ""
        range_TV = tv_out  ? "ymax ymin - range_max / * ymin +" : ""
        UVf      = bi < 32 ? "range_half - " : ""

        R = Expr(Y,    V, ex_dlut( "x "+rangeY+" "+string(m0)+" *                            y "+UVf + string(m2)+" * + "+range_TV+"", bi, !tv_in), optSingleMode=false, lut=lut)
        G = Expr(Y, U, V, ex_dlut( "x "+rangeY+" "+string(m3)+" * y "+UVf + string(m4)+" * + z "+UVf + string(m5)+" * + "+range_TV+"", bi, !tv_in), optSingleMode=true , lut=  0)
        B = Expr(Y, U,    ex_dlut( "x "+rangeY+" "+string(m6)+" * y "+UVf + string(m7)+" * +                            "+range_TV+"", bi, !tv_in), optSingleMode=false, lut=lut)

    }

    CombinePlanes(R, G, B, planes="RGB") }



# RGB to YCbCr standalone function
function RGB_to_YUV (clip rgb, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", float "b", float "c", float "p", string "cplace") {

    matrix     = Default (matrix, "sRGB")
    p_type     = Default (pixel_type, "420")     # target YUV pixel_type
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, false)
    tv_out     = Default (tv_range_out, true)
    cplace     = Default (cplace, "")
    b          = Default (b, -0.5)
    c          = Default (c, 0.25)               # Didée's Bicubic
    p          = Default (p, 0.25)

    Assert(IsVersionOrGreater(3,7,1),   "RGB_to_YUV: Update AviSynth+ version")
    Assert(isRGB(rgb) && IsPlanar(rgb), "RGB_to_YUV: Only Planar RGB format supported")

    bi       = BitsPerComponent(rgb)
    p_type   = Format_fuzzy_search (rgb, p_type, bi)
    matrix   = Color_Fuzzy_search (matrix)
    coef     = Matrix_coef(matrix[0])
    bc       = bicubic_coeffs(kernel)
    bc_b     = string(bc[1]>=0.?bc[0]:b)
    bc_c     = string(bc[1]>=0.?bc[1]:c)
    kernel   = bc[1]>=0. ? "Bicubic" : kernel

    p_type4  = p_type[1] == "444"
    p_type2  = p_type[1] == "422"
    p_type1  = p_type[1] == "411"
    p_type10 = p_type[1] == "410"

    w  = width (rgb)
    h  = height(rgb)
    nw = p_type4 ? w : p_type1 || p_type10 ? round(w/4.0) : round(w/2.0)
    nh = p_type4 ||    p_type1 || p_type2  ?            h : round(h/2.0)

    cplace  = chroma_placement(w, h, w, h, matrix[0], matrix[0], "RGB", "YUV", "444", p_type[1], "center", cplace )

     p_type1             ? Assert(bi == 8,    "RGB_to_YUV: Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10,  "RGB_to_YUV: Unsupported Pixel Type: YUV410")

                           Assert(h%2==0,     "RGB_to_YUV: Height is not mod2" )
    !p_type1 || !p_type4 ? Assert(w%2==0,     "RGB_to_YUV: Width is not mod2" )                 : nop()
     p_type1             ? Assert(w%4==0,     "RGB_to_YUV: Width is not mod4" )                 : nop()


    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)


    if (matrix[0]=="Rec2020CL" || matrix[0]=="DCI-P3" || matrix[0]=="Display-P3") {

        YCbCr = RGB_to_YcCbcCrc( Rx, Gx, Bx, matrix[0], coef, tv_in, tv_out)

        Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]

    } else {

        scale_y   = !tv_in && tv_out ? ( 219 / 255.) : 1.0
        scale_uv  = !tv_in && tv_out ? ( 112 / 255.) : 0.5

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y  *   coef[0]       m1 = scale_y  *   coef[1]         m2 = scale_y  *   coef[2]
        m3 = scale_uv * (-coef[0] / Kb) m4 = scale_uv * (-coef[1] / Kb)   m5 = scale_uv
        m6 = scale_uv                   m7 = scale_uv * (-coef[1] / Kr)   m8 = scale_uv * (-coef[2] / Kr)

        UVf       =  bi < 32         ? "" : "range_half -"
        rangeY_TV =  tv_out ?  tv_in ? "" : "ymin +" : tv_in ? "ymin - range_max ymax ymin - / *"    : ""
        rangeC_TV = !tv_out && tv_in ? "range_half - range_max cmax cmin - / * range_half + "+UVf+"" : UVf

        Y  = Expr(Rx, Gx, Bx, ex_dlut("           x "+string(m0)+" *   y "+string(m1)+" * + z "+string(m2)+" * + "+rangeY_TV+"", bi, !tv_in), optSingleMode=true)
        Cb = Expr(Rx, Gx, Bx, ex_dlut("range_half x "+string(m3)+" * + y "+string(m4)+" * + z "+string(m5)+" * + "+rangeC_TV+"", bi, !tv_in), optSingleMode=true)
        Cr = Expr(Rx, Gx, Bx, ex_dlut("range_half x "+string(m6)+" * + y "+string(m7)+" * + z "+string(m8)+" * + "+rangeC_TV+"", bi, !tv_in), optSingleMode=true)

    }

    point   = kernel=="Point" ? "+1.0" : ""
    cplaceH = ",src_left="+string(cplace[0])+point
    cplaceV =  ",src_top="+string(cplace[1])

    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ",b="+bc_b+",c="+bc_c+")" : \
                kernel == "gauss"  ?     "GaussResize(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ",p=p)"     : \
                                     kernel + "Resize(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ")"

    Cb = p_type4 ? Cb : Eval("Cb." + resampler)
    Cr = p_type4 ? Cr : Eval("Cr." + resampler)

    CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+p_type[1]+p_type[2]) }


# RGB to YcCbcCrc function (for Rec.2020CL)
function RGB_to_YcCbcCrc (clip RGB, clip "Gx", clip "Bx", string "matrix", float_array "coef", bool "tv_in", bool "tv_out") {

    isy  = isy(RGB)
    bi   = BitsPerComponent(RGB)
    lut  = bi < 16 ? 2 : 0
    mat  = Default (matrix, "Rec709")
    coef = Default (coef, Matrix_coef(mat))
    tvi  = Default (tv_in,  false)
    tvo  = Default (tv_out, false)

    mat       = Color_Fuzzy_search(mat)
    s_gam     = moncurve_coef(mat[0]) # some values are getting crushed in the Rec709 transfer
    bi32      = bi == 32 ? "" : "range_half +"
    rangeC_PC = tvi      ? "range_half - range_max cmax cmin - / * range_half + " : ""
    rangeC_TV = tvo      ? "range_half + cmax cmin - range_max / * cmin + "       : bi32

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    B   = !isy ? clp[2] :      Bx

    clp = !isy ?          moncurve_f(RGB, s_gam[0], s_gam[1], tvi, false, 3).ExtractClip() : nop()
    Rln = !isy ? clp[0] : moncurve_f(RGB, s_gam[0], s_gam[1], tvi, false, 1)
    Gln = !isy ? clp[1] : moncurve_f(Gx,  s_gam[0], s_gam[1], tvi, false, 1)
    Bln = !isy ? clp[2] : moncurve_f(Bx,  s_gam[0], s_gam[1], tvi, false, 1)

    ca = 1.0 + s_gam[1]
    cb = 1.0 / s_gam[0]

    Pb = 1 /  (2. * (ca*(1.0 - pow(coef[2], cb))))
    Pr = 1 /  (2. * (ca*(1.0 - pow(coef[0], cb))))
    Nb = 1 / (-2. * (ca*(1.0 - pow(coef[0] + coef[1], cb)) - 1.0))
    Nr = 1 / (-2. * (ca*(1.0 - pow(coef[1] + coef[2], cb)) - 1.0))

    Y     = Expr(Rln, Gln, Bln, "x "+string(coef[0])+" * y "+string(coef[1])+" * + z "+string(coef[2])+" * + ")
    Yx    = moncurve_r(Y,  s_gam[0], s_gam[1], false, false, 1)

    Cbc   = Expr(B, Yx, ex_dlut(Format("x "+rangeC_PC+" y - A@ 0 <= A {Nb} * A {Pb} * ? "+rangeC_TV+" "), bi, !tvi), lut=lut)
    Crc   = Expr(R, Yx, ex_dlut(Format("x "+rangeC_PC+" y - A@ 0 <= A {Nr} * A {Pr} * ? "+rangeC_TV+" "), bi, !tvi), lut=lut)
    Yc    = !tvo ?  Yx : moncurve_r(Y,  s_gam[0], s_gam[1], false, true, 1)

     isy ? [Yc, Cbc, Crc] : CombinePlanes(Yc, Cbc, Crc, planes="YUV")
    !isy && mat[0] == "Rec2020CL" ? PropSet("_Matrix", 10) : last }


# WIP. YcCbcCrc to RGB function (for Rec.2020CL)
function YcCbcCrc_to_RGB (clip YUV, clip "Cb", clip "Cr", string "matrix", float_array "coef", bool "tv_in", bool "tv_out") {

    isy  = isy(YUV)
    bi   = BitsPerComponent(YUV)
    lut  = bi < 16 ? 2 : 0
    mat  = Default (matrix, "Rec709")
    coef = Default (coef, Matrix_coef(mat))
    tvi  = Default (tv_in,  false)
    tvo  = Default (tv_out, false)

    mat  = Color_Fuzzy_search(mat)
    clp  = !isy ? ExtractClip(YUV) : nop()
    Y    = !isy ? clp[0] :    YUV
    Cb   = !isy ? clp[1] :     Cb
    Cr   = !isy ? clp[2] :      Cr

    bi32m     = bi == 32 ? "" : "range_half -"
    bi32p     = bi == 32 ? "" : "range_half +"
    rangeC_PC = tvi ? ""+bi32m+" range_max cmax cmin - / *" : bi32m

    s_gam = moncurve_coef(mat[0])
    a = 1.0 + s_gam[1]
    b = 1.0 / s_gam[0]

    Pb =  2. * (a*(1.0 - pow(coef[2], b)))
    Pr =  2. * (a*(1.0 - pow(coef[0], b)))
    Nb = -2. * (a*(1.0 - pow(coef[0] + coef[1], b)) - 1.0)
    Nr = -2. * (a*(1.0 - pow(coef[1] + coef[2], b)) - 1.0)

    Y  = moncurve_f(Y,  s_gam[0], s_gam[1], tvi, false, 1)

    Bx = Expr(Cb, Y, ex_dlut(Format("x "+rangeC_PC+" A@ 0 <= A {Nb} * y "+bi32m+" B@ + A {Pb} * B + ? "+bi32p), bi, !tvi), lut=lut)
    Rx = Expr(Cr, Y, ex_dlut(Format("x "+rangeC_PC+" A@ 0 <= A {Nr} * y "+bi32m+" B@ + A {Pr} * B + ? "+bi32p), bi, !tvi), lut=lut)

    Gx = Expr(Y, Bx, Rx, "x "+string(coef[2])+" y * - "+string(coef[0])+" z * - "+string(coef[1])+" / ", optSingleMode=true)

    if (isy) {

        B = moncurve_r(Bx,  s_gam[0], s_gam[1], false, tvo, 1)
        R = moncurve_r(Rx,  s_gam[0], s_gam[1], false, tvo, 1)
        G = moncurve_r(Gx,  s_gam[0], s_gam[1], false, tvo, 1)
        [R, G, B]

    } else {

        CombinePlanes(Rx, Gx, Bx, planes="RGB")
        moncurve_r(s_gam[0], s_gam[1], false, tvo, 3)

    } }




# YCoCg, YCoCgR and YUVr compress better than plain YUV. YCoCg variants a tiny bit over YUVr, and YUVr and YCoCgR being losslessly reversible (RCT) with RGB
# These formats are ColorSpace and Chroma Subsampling independent, as well as signal range (full or legal)

# RGB to YCoCg function
function RGB_to_YCoCg (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    b32 = bi == 32 ? "" : "range_half +"

    if (isy) {
        Y  = Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ",     bi, !tvi), optSingleMode=true,  lut=  0)
        Cg = Expr(R, G, B, ex_dlut("y 0.5  * x z + 0.25 * - "+b32, bi, !tvi), optSingleMode=true,  lut=  0)
        Co = Expr(R,    B, ex_dlut("x y - 0.5  *            "+b32, bi, !tvi), optSingleMode=false, lut=lut)
        [Y, Cg, Co]

    } else {

        fmt = Format_fuzzy_search(RGB, "YUV", bi)
        Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ",     bi, !tvi),  \
                      ex_dlut("y 0.5  * x z + 0.25 * - "+b32, bi, !tvi),  \
                      ex_dlut("x z - 0.5  *            "+b32, bi, !tvi), format="YUV444"+fmt[2], optSingleMode=true) } }


# YCoCg to RGB function
function YCoCg_to_RGB (clip YCC, clip "Cg", clip "Co", bool "tv_in", bool "tv_out") {

    isy = isy(YCC)
    bi  = BitsPerComponent(YCC)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(YCC) : nop()
    Y   = !isy ? clp[0] :    YCC
    Cg  = !isy ? clp[1] :     Cg
    Co  = !isy ? clp[2] :      Co

    b32 = bi == 32 ? "" : "range_half -"

    if (isy) {

        R = Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" + ", bi, !tvi), optSingleMode=true,  lut=  0)
        G = Expr(Y, Cg,     ex_dlut("x y "+b32+" +",              bi, !tvi), optSingleMode=false, lut=lut)
        B = Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" - ", bi, !tvi), optSingleMode=true,  lut=  0)
        [R, G, B]

    } else {

        fmt = Format_fuzzy_search(YCC, "RGB", bi)
        Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" + ", bi, !tvi),  \
                        ex_dlut("x y "+b32+" +",              bi, !tvi),  \
                        ex_dlut("x y "+b32+" - z "+b32+" - ", bi, !tvi), format="RGB"+fmt[2], optSingleMode=true) } }


# RGB to YCoCg RCT function
function RGB_to_YCoCgR (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    b32i = bi == 32 ? "" : "range_half +"
    b32f = bi == 32 ? "" : "range_half -"

    Co = Expr(R,      B, ex_dlut("x 0.5  * y 0.5  * - "+b32i,            bi, !tvi), optSingleMode=false, lut=lut)
    Cg = Expr(Co, G,  B, ex_dlut("y z x "+b32f+" 0.5 * + - 0.5 * "+b32i, bi, !tvi), optSingleMode=false, lut=  0)
    Y  = Expr(Co, Cg, B, ex_dlut("  z x "+b32f+" 0.5 * + y "+b32f+" +",  bi, !tvi), optSingleMode=false, lut=  0)

    isy ? [Y, Cg, Co] : CombinePlanes(Y, Cg, Co, planes="YUV") }


#  YCoCg RCT to RGB function
function YCoCgR_to_RGB (clip YCC, clip "Cg", clip "Co", bool "tv_in", bool "tv_out") {

    isy = isy(YCC)
    bi  = BitsPerComponent(YCC)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(YCC) : nop()
    Y   = !isy ? clp[0] :    YCC
    Cg  = !isy ? clp[1] :     Cg
    Co  = !isy ? clp[2] :      Co

    b32 = bi == 32 ? "" : "range_half -"

    if (isy) {

        G = Expr(Y, Cg,     ex_dlut("y   "+b32+" Y@ 2 * x Y - +",      bi, !tvi), optSingleMode=false, lut=lut)
        B = Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" 0.5 * -", bi, !tvi), optSingleMode=true,  lut=  0)
        R = Expr(Co, B,     ex_dlut("y x "+b32+" 2 * +",               bi, !tvi), optSingleMode=false, lut=lut)
        [R, G, B]

    } else {

        fmt = Format_fuzzy_search(YCC, "RGB", bi)
        Expr(Y, Cg, Co, ex_dlut("z   "+b32+" dup 0.5 * x y "+b32+" - swap - swap 2 * +", bi, !tvi),  \
                        ex_dlut("y   "+b32+" Y@ 2 * x Y - +",                            bi, !tvi),  \
                        ex_dlut("x y "+b32+" - z "+b32+" 0.5 * -",                       bi, !tvi), format="RGB"+fmt[2], optSingleMode=true) } }


# RGB to YCbCr RCT function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
function RGB_to_YUVr (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    b32 = bi == 32 ? "" : "range_half +"

    if (isy) {
        Y  = Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ", bi, !tvi), optSingleMode=true,  lut=  0)
        Cb = Expr(   G, B, ex_dlut("y x - "+b32,               bi, !tvi), optSingleMode=false, lut=lut)
        Cr = Expr(R, G,    ex_dlut("x y - "+b32,               bi, !tvi), optSingleMode=false, lut=lut)
        [Y, Cb, Cr]

    } else {

        fmt = Format_fuzzy_search(RGB, "YUV", bi)
        Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ", bi, !tvi),  \
                      ex_dlut("z y - "+b32,               bi, !tvi),  \
                      ex_dlut("x y - "+b32,               bi, !tvi), format="YUV444"+fmt[2], optSingleMode=true) } }


# YCbCr RCT to RGB function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
function YUVr_to_RGB (clip YUV, clip "Cb", clip "Cr", bool "tv_in", bool "tv_out") {

    isy = isy(YUV)
    bi  = BitsPerComponent(YUV)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(YUV) : nop()
    Y   = !isy ? clp[0] :    YUV
    Cb  = !isy ? clp[1] :     Cb
    Cr  = !isy ? clp[2] :      Cr

    b32  = bi == 32 ? "" : "range_half -"
    b32h = bi == 32 ? "" : "range_half 0.5 * +"

        G = Expr(Y, Cb, Cr, ex_dlut("x y z + 0.25 * - "+b32h, bi, !tvi), optSingleMode=true,  lut=  0)

    if (isy) {

        R = Expr(G,     Cr, ex_dlut("x y + "+b32,             bi, !tvi), optSingleMode=false, lut=lut)
        B = Expr(G, Cb,     ex_dlut("x y + "+b32,             bi, !tvi), optSingleMode=false, lut=lut)
        [R, G, B]

    } else {

        fmt = Format_fuzzy_search(YUV, "RGB", bi)
        Expr(G, Cb, Cr, ex_dlut("x z + "+b32,                 bi, !tvi),"",  \
                        ex_dlut("x y + "+b32,                 bi, !tvi), format="RGB"+fmt[2]) } }


# RGB' to LSLM'
#
#  L  [0.209(R-0.5),  0.715(G-0.5), 0.076(B-0.5)],\
#  S  [0.209(R-0.5),  0.715(G-0.5),-0.924(B-0.5)],\
#  LM [3.148(R-0.5), -2.799(G-0.5),-0.349(B-0.5)]]
#
# RGB' to OPP'
# This looks like a gamma encoded transformation.
#
#   [1/sqrt(2), -1/sqrt(2),          0],\
#   [1/sqrt(6),  1/sqrt(6), -2/sqrt(6)],\  *  RGB
#   [1/sqrt(3),  1/sqrt(3), 1/sqrt(3)]]
#
# For the linear version use the matrix functions.
# The matrix there yields from a joint matrix between XYZ to a modified LMS matrix and a LMS to OPP matrix
#
#   # XYZ to LMS. Looks like a version of Stockman & Sharpe (2000) LMS (and not the usual Hunt-Pointer-Estevez normalized to D65)
#   [[0.2430, 0.8560, -0.0440],\
#   [-0.3910,  1.1650, 0.0870],\
#   [0.0100,  -0.0080, 0.5630]]

#   # LMS to OPP
#   [[1.0,   0.0,   0.0],\
#   [-0.59,  0.80, -0.12],\
#   [-0.34, -0.11,  0.93]]

# https://github.com/HomeOfVapourSynthEvolution/VapourSynth-BM3D/blob/7b3d8dd32e4aa4d962cf15d75d191b465682ed42/include/Specification.h#L176
function RGB_to_OPP (clip RGB, clip "G", clip "B", bool "fulls") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi < 16 ? 2 : 0
    fs  = Default (fulls, true)

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    b32 = bi == 32 ? "" : "range_half +"

        Os  = ex_dlut(Format("x y z + + 0.333333333 *")         , bi, fs)
        P1s = ex_dlut(Format("x "+(isy?"y":"z")+" - 0.5 * "+b32), bi, fs)
        P2s = ex_dlut(Format("x z + 0.25 * y 0.5 * - "     +b32), bi, fs)

    if (isy) {

        O  = Expr(R, G, B, Os,  optSingleMode=false, lut=  0)
        P1 = Expr(R,    B, P1s, optSingleMode=false, lut=lut)
        P2 = Expr(R, G, B, P2s, optSingleMode=false, lut=  0)
        [O, P1, P2]

    } else { Expr(R, G, B, Os, P1s, P2s, format="YUV444"+Format_fuzzy_search(RGB,"YUV",bi)[2], optSingleMode=true) } }


# https://github.com/HomeOfVapourSynthEvolution/VapourSynth-BM3D/blob/7b3d8dd32e4aa4d962cf15d75d191b465682ed42/include/Specification.h#L176
function OPP_to_RGB (clip OPP, clip "P1", clip "P2", bool "fulls") {

    isy = isy(OPP)
    bi  = BitsPerComponent(OPP)
    lut = bi < 16 ? 2 : 0
    fs  = Default (fulls, true)

    clp = !isy ? ExtractClip(OPP) : nop()
    O   = !isy ? clp[0] :    OPP
    P1  = !isy ? clp[1] :     P1
    P2  = !isy ? clp[2] :      P2

    b32 = bi == 32 ? "" : "range_half -"

        Rs = ex_dlut(Format("x y "+b32+" + z "+b32+" 0.666666666 * +")    , bi, fs)
        Gs = ex_dlut(Format("x "+(isy?"y":"z")+" "+b32+" 1.333333333 * -"), bi, fs)
        Bs = ex_dlut(Format("x z "+b32+" 0.666666666 * + y "+b32+" -")    , bi, fs)

    if (isy) {

        R = Expr(O, P1, P2, Rs, optSingleMode=false, lut=  0)
        G = Expr(O,     P2, Gs, optSingleMode=false, lut=lut)
        B = Expr(O, P1, P2, Bs, optSingleMode=false, lut=  0)
        [R, G, B]

    } else { Expr(O, P1, P2, Rs, Gs, Bs, format="RGB"+Format_fuzzy_search(OPP,"RGB",bi)[2], optSingleMode=true) } }


# XYZ to YDzDx (applied on SMPTE ST 2084 gamma space)
function XYZ_to_YDzDx (clip XYZ, clip "Y", clip "Z", bool "tv_in", bool "tv_out") {

    isy = isy(XYZ)
    bi  = BitsPerComponent(XYZ)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(XYZ) : nop()
    X   = !isy ? clp[0] :    XYZ
    Y   = !isy ? clp[1] :     Y
    Z   = !isy ? clp[2] :      Z

    b32 = bi == 32 ? "" : "range_half +"

    cf1   = 2763/2800.
    cf2   = 2741/2763.

    if (isy) {

        Dz = Expr(   Y, Z, ex_dlut(Format("{cf1} y "+b32+" * x  - "), bi, !tvi), optSingleMode=false, lut=lut)
        Dx = Expr(X, Y,    ex_dlut(Format("x "+b32+"  {cf2} y * - "), bi, !tvi), optSingleMode=false, lut=lut)
        [Y, Dz, Dx]

    } else {

        Expr(Y, X, Z, "", ex_dlut(Format("{cf1} z "+b32+" * x  - "), bi, !tvi),  \
                          ex_dlut(Format("y "+b32+"  {cf2} x * - "), bi, !tvi), format=PixelType(XYZ)) } }


# YDzDx to XYZ
function YDzDx_to_XYZ (clip YDzDx, clip "Dz", clip "Dx", bool "tv_in", bool "tv_out") {

    isy = isy(YDzDx)
    bi  = BitsPerComponent(YDzDx)
    lut = bi < 16 ? 2 : 0
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(YDzDx) : nop()
    Y   = !isy ? clp[0] :    YDzDx
    Dz  = !isy ? clp[1] :     Dz
    Dx  = !isy ? clp[2] :      Dx

    b32 = bi == 32 ? "" : "range_half -"

    cf1   = 2800/2763.
    cf2   = 2763/2741.

    if (isy) {

        X = Expr(Dx, Y, ex_dlut(Format("x "+b32+" y {cf2} * + "), bi, !tvi), optSingleMode=false, lut=lut)
        Z = Expr(Dz, Y, ex_dlut(Format("x "+b32+" y {cf1} * + "), bi, !tvi), optSingleMode=false, lut=lut)
        [X, Y, Z]

    } else {

        Expr(Dx, Y, Dz, ex_dlut(Format("x "+b32+" y {cf1} * + "), bi, !tvi), "",  \
                        ex_dlut(Format("z "+b32+" y {cf2} * + "), bi, !tvi), format=PixelType(YDzDx)) } }


# WIP. XYZ to CIE Lab -D65 based- (process in linear space) Normalized to 0-1
function XYZ_to_Lab (clip XYZ, clip "Y", clip "Z", bool "Jch", bool "fulls") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    lut1 = bi == 32 ? 0 : 1
    lut2 = bi  < 16 ? 2 : 0
    cy   = Default (Jch,   false)
    fs   = Default (fulls,  true)

    clp  = !isy ? ExtractClip(XYZ) : nop()
    X    = !isy ? clp[0] :    XYZ
    Y    = !isy ? clp[1] :     Y
    Z    = !isy ? clp[2] :      Z

    ep    = pow(24. / 116,  3)               # 0.00885645167903563081717167575546 (or 216 / 24389.)
    coef  = pow(24. / 116,  2) * 3           # 0.12841854934601664684898929845422 (or 108 / 841)
    coefr = pow(24. / 116, -2) * (1 / 3.)    # 7.78703703703703703703703703703703 (or 841 / 108)  reciprocal of above
    rW    = [95.0449218275099, 100., 108.8916648430471] # Reference White: Normalization to Y=100 of reciprocal of illuminant

    L = Expr(Y,               Format("x "+string(rW[1])+" / Y@ {ep} > Y 0.333333333 ^ Y {coefr} * 16 116 / + ? 116 * 16 - "+" 9 /"),           optSingleMode=false, lut=lut1)
    a = Expr(X, Y,    ex_dlut(Format("x "+string(rW[0])+" / X@ {ep} > X 0.333333333 ^ X {coefr} * 16 116 / + ?
                                      y "+string(rW[1])+" / Y@ {ep} > Y 0.333333333 ^ Y {coefr} * 16 116 / + ? - 500 * "+" 13.45 /"), bi, fs), optSingleMode=true,  lut=lut2)
    b = Expr(   Y, Z, ex_dlut(Format("x "+string(rW[1])+" / Y@ {ep} > Y 0.333333333 ^ Y {coefr} * 16 116 / + ?
                                      y "+string(rW[2])+" / Z@ {ep} > Z 0.333333333 ^ Z {coefr} * 16 116 / + ? - 200 * "+" 12.3  /"), bi, fs), optSingleMode=true,  lut=lut2)

    isy ? [L, a, b] : CombinePlanes(L, a, b, planes="RGB") }


# WIP. CIE Lab to XYZ
function Lab_to_XYZ (clip Lab, clip "a", clip "b", bool "Jch", bool "fulls") {

    isy  = isy(Lab)
    bi   = BitsPerComponent(Lab)
    lut1 = bi == 32 ? 0 : 1
    lut2 = bi  < 16 ? 2 : 0
    cy   = Default (Jch,    false)
    fs   = Default (fulls,   true)

    clp  = !isy ? ExtractClip(Lab) : nop()
    L    = !isy ? clp[0] :    Lab
    a    = !isy ? clp[1] :     a
    b    = !isy ? clp[2] :      b

    ep    = 24  / 116.          # 0.20689655172413793103448275862069
    ep2   = pow(ep, 3)          # 0.00885645167903563081717167575546 (or 216 / 24389.)
    coef  = pow(ep, 2) * 3      # 0.12841854934601664684898929845422 (or 108 / 841)
    kappa = 24389 / 27.         # 903.296296296296296296296296296296
    rW    = [95.0449218275099, 100., 108.8916648430471] # Reference White: Normalization to Y=100 of reciprocal of illuminant

    Y = Expr( L,    Format("x 100 * 16 + 116 / Y@                 {ep} > Y 3 ^ Y 16 116 / - {coef} * ?                          "), optSingleMode=false, lut=lut1)
    X = Expr( L, a, Format("x 100 * 16 + 116 / y 100 * 500 / + X@ {ep} > X 3 ^ X 16 116 / - {coef} * ? "+string(rW[0])+" * 100 /"), optSingleMode=false, lut=lut2)
    Z = Expr( L, b, Format("x 100 * 16 + 116 / y 100 * 200 / - Z@ {ep} > Z 3 ^ Z 16 116 / - {coef} * ? "+string(rW[2])+" * 100 /"), optSingleMode=false, lut=lut2)

    isy ? [X, Y, Z] : CombinePlanes(X, Y, Z, planes="RGB") }



# XYZ to CIE Luv/Duv -D65 based- (process in linear space) (32-bit float recommended)
function XYZ_to_Luv (clip XYZ, clip "Y", clip "Z", bool "Jch", bool "Duv", bool "tv_in", bool "tv_out") {

    isy = isy(XYZ)
    bi  = BitsPerComponent(XYZ)
    lut = bi == 32 ? 0 : 1
    cy  = Default (Jch,    false)
    uv  = Default (Duv,    false)
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(XYZ) : nop()
    X   = !isy ? clp[0] :    XYZ
    Y   = !isy ? clp[1] :     Y
    Z   = !isy ? clp[2] :      Z

    b32 = bi == 32 ? "" : "range_half +"

    ep    = 216 / 24389.
    kappa = 24389 / 27.
    c     = 1 / 0.62

    rW    = [95.0449218275099, 100., 108.8916648430471]

    detu  = (4 * rW[0] / (rW[0] + 15 * rW[1] + 3 * rW[2]))
    detv  = (9 * rW[1] / (rW[0] + 15 * rW[1] + 3 * rW[2]))
    duv   = uv ? Format(" {c} * ") : ""

    L = Expr(Y,                  Format("x {ep} > x 0.333333333 ^ 116 * 16 - x {kappa} * ? "),               optSingleMode=false, lut=lut)
    u = Expr(X, Y, Z, L, ex_dlut(Format("x 4 * x y 15 * + z 3 * + / {detu} - a 13 * * "+duv+b32), bi, !tvi), optSingleMode=true,  lut=  0)
    v = Expr(X, Y, Z, L, ex_dlut(Format("x 9 * x y 15 * + z 3 * + / {detv} - a 13 * * "+duv+b32), bi, !tvi), optSingleMode=true,  lut=  0)

    isy ? [L, u, v] : CombinePlanes(L, u, v, planes="RGB") }


#https://www.brucelindbloom.com/index.html?Eqn_Luv_to_XYZ.html
# CIE Luv to XYZ
function Luv_to_XYZ (clip Luv, clip "u", clip "v", bool "Jch", bool "Duv", bool "tv_in", bool "tv_out") {

    isy = isy(Luv)
    bi  = BitsPerComponent(Luv)
    lut = bi == 32 ? 0 : 1
    cy  = Default (Jch,    false)
    uv  = Default (Duv,    false)
    tvi = Default (tv_in,  false)
    tvo = Default (tv_out, false)

    clp = !isy ? ExtractClip(Luv) : nop()
    L   = !isy ? clp[0] :    Luv
    u   = !isy ? clp[1] :     u
    v   = !isy ? clp[2] :      v

    b32 = bi == 32 ? "" : "range_half -"

    ep    = 216 / 24389.
    kappa = 24389 / 27.
    exk   = ep * kappa
    D65N  = [0.312713, 0.329016, 0.358271]
    Wr    = [95.0449218275099, 100., 108.8916648430471]

    detu  = (4 * D65N[0] / (D65N[0] + 15 * D65N[1] + 3 * D65N[2]))
    detv  = (9 * D65N[1] / (D65N[0] + 15 * D65N[1] + 3 * D65N[2]))
    duv   = uv ? Format(" 0.62 * ") : ""

    Y = Expr(      L,       Format("x {exk} > x 16 + 116 / 3 ^ x {kappa} / ?"),                                optSingleMode=false, lut=lut)
    X = Expr(   Y, L, u, v, Format("y 39 * y 13 * A@ {detv} * a "+duv+b32+" + / 5 - x * x 5 * +
                                    y 52 * A {detu} * z "+duv+b32+" + / 1 - 0.333333333 * 0.333333333 + / "),  optSingleMode=true,  lut=  0)
    Z = Expr(X, Y, L, u,    Format("z 52 * z 13 * {detu} * a "+duv+b32+" + / 1 - 0.333333333 * x * y 5 * - "), optSingleMode=true,  lut=  0)

    isy ? [X, Y, Z] : CombinePlanes(X, Y, Z, planes="RGB") }


# RGB' (gamma encoded) to HSV
function RGB_to_HSV (clip RGB, clip "G", clip "B", bool "tv_range") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    tv  = Default (tv_range, false)

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    rangePC  = tv ? "ymin - ymax ymin - /" : bi == 32 ? "" : "range_max /"
    rangeTV  = tv ? "ymax ymin - * ymin +" : bi == 32 ? "" : "range_max *"

    V  = Expr(R, G, B,"z y max x max", optSingleMode=false)                   # Lightness Hexcone
    Ss = "a 0 == 0 a z y min x min - "+rangePC+" a "+rangePC+" / ? "+rangeTV  # Hexagonal Chroma
    Hs = "60       a z y min x min - "+rangePC+" S@ / D^
          a 0 == S a / 0 == or 0
          x a == y z - "+rangePC+" D * 360 + 360 %
          y a == z x - "+rangePC+" D * 120 + 360 %
          z a == x y - "+rangePC+" D * 240 + 360 % 0 ? ? ? ? 0.002777778 range_max * * "

    if (isy) {

        S = Expr(R, G, B, V, Ss, optSingleMode=false)
        H = Expr(R, G, B, V, Hs, optSingleMode=true)
        [H, S, V]

    } else { Expr(R, G, B, V, Hs, Ss, "a",format=PixelType(RGB), optSingleMode=true) } }


function HSV_to_RGB (clip HSV, clip "S", clip "V", bool "tv_range") {

    isy = isy(HSV)
    bi  = BitsPerComponent(HSV)

    tv  = Default (tv_range, false)

    clp = !isy ? ExtractClip(HSV) : nop()
    H   = !isy ? clp[0] :    HSV
    S   = !isy ? clp[1] :     S
    V   = !isy ? clp[2] :      V

    rangePC  = tv ? "ymin - ymax ymin - /" : bi == 32 ? "" : "range_max /"
    rangeTV  = tv ? "ymax ymin - * ymin +" : bi == 32 ? "" : "range_max *"

    m = "0 1 clip 1 -    y "+rangePC+" * 1 + z "+rangePC+" * "+rangeTV
    Rs = "  x "+rangePC+" 6 * 3 - abs 1 - "+m
    Gs = "2 x "+rangePC+" 6 * 2 - abs   - "+m
    Bs = "2 x "+rangePC+" 6 * 4 - abs   - "+m

    if (isy) {

        R = Expr(H, S, V, Rs, optSingleMode=false)
        G = Expr(H, S, V, Gs, optSingleMode=false)
        B = Expr(H, S, V, Bs, optSingleMode=false)
        [R, G, B]

    } else { Expr(H, S, V, Rs, Gs, Bs, format=PixelType(HSV), optSingleMode=true) } }



# RGB linear to IPT (original PT range scaled from -1 +1 to 0 +1)
# Fix some NaN in black areas
function RGB_to_IPT (clip RGB, clip "G", clip "B", bool "Jch", string "matrix", bool "fulls") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    mat = Default (matrix, "Rec709")
    cy  = Default (Jch,      false)    # enable to convert to JCh (cylindrical IPT) in the range 0 to 1.
    fs  = Default (fulls,     true)

    mat = Color_Fuzzy_search(mat)
    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    LMS = [0.4002, 0.7075, -0.0807, \
          -0.2280, 1.1500,  0.0612, \
           0.0000, 0.0000,  0.9184]

    IPT = [0.4000,  4.4550,  0.8056, \
           0.4000, -4.8510,  0.3572, \
           0.2000,  0.3960, -1.1628]

    mata = RGB_to_XYZ (R, mat[0], list=true)
    LMS  = MatrixTranspose(LMS)
    LMS  = MatrixDot(mata, LMS)
    b32m = bi == 32 ? "" : ex_dlut(" range_max *", bi, fs)
    b32d = bi == 32 ? "" : ex_dlut( "range_max /", bi, fs)

    L = Expr(R,G,B, "x "+b32d+" "+string(LMS[0])+" * y "+b32d+" "+string(LMS[3])+" * + z "+b32d+" "+string(LMS[6])+" * + dup dup 0 >= swap 0.43 ^ swap neg 0.43 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
    M = Expr(R,G,B, "x "+b32d+" "+string(LMS[1])+" * y "+b32d+" "+string(LMS[4])+" * + z "+b32d+" "+string(LMS[7])+" * + dup dup 0 >= swap 0.43 ^ swap neg 0.43 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
    S = Expr(R,G,B, "x "+b32d+" "+string(LMS[2])+" * y "+b32d+" "+string(LMS[5])+" * + z "+b32d+" "+string(LMS[8])+" * + dup dup 0 >= swap 0.43 ^ swap neg 0.43 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")

        Is  = " x "+b32d+" "+string(IPT[0])+" * y "+b32d+" "+string(IPT[3])+" * + z "+b32d+" "+string(IPT[6])+" * +"+b32m
        I   = isy ? Expr(L,M,S, Is, optSingleMode=true) : nop()

    if (!cy) {

        Ps  = " x "+b32d+" "+string(IPT[1])+" * y "+b32d+" "+string(IPT[4])+" * + z "+b32d+" "+string(IPT[7])+" * + 1 + 0.5 *"+b32m
        Ts  = " x "+b32d+" "+string(IPT[2])+" * y "+b32d+" "+string(IPT[5])+" * + z "+b32d+" "+string(IPT[8])+" * + 1 + 0.5 *"+b32m

        if (isy) {

            P  = Expr(L,M,S, Ps, optSingleMode=true)
            T  = Expr(L,M,S, Ts, optSingleMode=true)
            [I, P, T]

        } else { Expr(L,M,S, Is, Ps, Ts, format=PixelType(RGB), optSingleMode=true) }

    } else {

        Cs  = " x "+b32d+" X@ "+string(IPT[1])+" * y "+b32d+" Y@ "+string(IPT[4])+" * + z "+b32d+" Z@ "+string(IPT[7])+" * + dup *
                X             "+string(IPT[2])+" * Y             "+string(IPT[5])+" * + Z             "+string(IPT[8])+" * + dup * + sqrt pi *"+b32m
        hs  = " x "+b32d+" X@ "+string(IPT[1])+" * y "+b32d+" Y@ "+string(IPT[4])+" * + z "+b32d+" Z@ "+string(IPT[7])+" * +
                X             "+string(IPT[2])+" * Y             "+string(IPT[5])+" * + Z             "+string(IPT[8])+" * + swap atan2 pi + pi 2 * /"+b32m

        if (isy) {

            C  = Expr(L,M,S, Cs, optSingleMode=true)  # maybe normalize with 4.956244 instead
            h  = Expr(L,M,S, hs, optSingleMode=true)
            [I, C, h]

        } else { Expr(L,M,S, Is, Cs, hs, format=PixelType(RGB), optSingleMode=true) } } }



function IPT_to_RGB (clip IPT, clip "P", clip "T", bool "Jch", string "matrix", bool "fulls") {

    isy = isy(IPT)
    bi  = BitsPerComponent(IPT)

    mat = Default (matrix, "Rec709")
    cy  = Default (Jch,      false)   # enable to convert from Jch (cylindrical IPT) in the range 0 to 1.
    fs  = Default (fulls,     true)

    mat = Color_Fuzzy_search(mat)
    clp = !isy ? ExtractClip(IPT) : nop()
    I   = !isy ? clp[0] :    IPT
    P   = !isy ? clp[1] :     P
    T   = !isy ? clp[2] :      T

    IPTm = [0.4000,  4.4550,  0.8056, \
            0.4000, -4.8510,  0.3572, \
            0.2000,  0.3960, -1.1628]

    LMS  = [0.4002, 0.7075, -0.0807, \
           -0.2280, 1.1500,  0.0612, \
            0.0000, 0.0000,  0.9184]

    IPTc  = MatrixInvert(IPTm)

    b32m = bi == 32 ? "" : ex_dlut(" range_max *", bi, fs)
    b32d = bi == 32 ? "" : ex_dlut( "range_max /", bi, fs)
    nm   = !cy ? "2 * 1 -" : ""

    if (!cy) {

        L = Expr(I, P, T, "x "+b32d+" "+string(IPTc[0])+" * y "+b32d+" "+nm+" "+string(IPTc[3])+" * + z "+b32d+" "+nm+" "+string(IPTc[6])+" * + dup dup 0 >= swap 1 0.43 / ^ swap neg 1 0.43 / ^ neg ?"+b32m, optSingleMode=true)
        M = Expr(I, P, T, "x "+b32d+" "+string(IPTc[1])+" * y "+b32d+" "+nm+" "+string(IPTc[4])+" * + z "+b32d+" "+nm+" "+string(IPTc[7])+" * + dup dup 0 >= swap 1 0.43 / ^ swap neg 1 0.43 / ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
        S = Expr(I, P, T, "x "+b32d+" "+string(IPTc[2])+" * y "+b32d+" "+nm+" "+string(IPTc[5])+" * + z "+b32d+" "+nm+" "+string(IPTc[8])+" * + dup dup 0 >= swap 1 0.43 / ^ swap neg 1 0.43 / ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")

    } else {

        L = Expr(I, P, T, "x "+b32d+" "+string(IPTc[0])+" * z "+b32d+" pi 2 * * pi - H@ cos y "+b32d+" pi / Y@ * "+string(IPTc[3])+" * + H sin Y * "+string(IPTc[6])+" * + dup dup 0 >= swap 1 0.43 / ^ swap neg 1 0.43 / ^ neg ?"+b32m, optSingleMode=true)
        M = Expr(I, P, T, "x "+b32d+" "+string(IPTc[1])+" * z "+b32d+" pi 2 * * pi - H@ cos y "+b32d+" pi / Y@ * "+string(IPTc[4])+" * + H sin Y * "+string(IPTc[7])+" * + dup dup 0 >= swap 1 0.43 / ^ swap neg 1 0.43 / ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
        S = Expr(I, P, T, "x "+b32d+" "+string(IPTc[2])+" * z "+b32d+" pi 2 * * pi - H@ cos y "+b32d+" pi / Y@ * "+string(IPTc[5])+" * + H sin Y * "+string(IPTc[8])+" * + dup dup 0 >= swap 1 0.43 / ^ swap neg 1 0.43 / ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
    }

    LMS  = MatrixTranspose(LMS)
    LMS  = MatrixInvert(LMS)
    mata = XYZ_to_RGB (I, mat[0], list=true)
    RGB  = MatrixDot(LMS, mata)

        Rs = "x "+b32d+" "+string(RGB[0])+" * y "+b32d+" "+string(RGB[3])+" * + z "+b32d+" "+string(RGB[6])+" * + "+b32m
        Gs = "x "+b32d+" "+string(RGB[1])+" * y "+b32d+" "+string(RGB[4])+" * + z "+b32d+" "+string(RGB[7])+" * + "+b32m
        Bs = "x "+b32d+" "+string(RGB[2])+" * y "+b32d+" "+string(RGB[5])+" * + z "+b32d+" "+string(RGB[8])+" * + "+b32m

    if (isy) {

        R = Expr(L,M,S, Rs, optSingleMode=false)
        G = Expr(L,M,S, Gs, optSingleMode=false)
        B = Expr(L,M,S, Bs, optSingleMode=false)
        [R, G, B]

    } else { Expr(L,M,S, Rs, Gs, Bs, format=PixelType(IPT), optSingleMode=true) } }



# RGB linear to Oklab (original 'ab' range scaled from -1 +1 to 0 +1)
# Fix some NaN in black areas
function RGB_to_Oklab (clip RGB, clip "G", clip "B", bool "Jch", string "matrix", bool "fulls") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    mat = Default (matrix, "Rec709")
    cy  = Default (Jch,      false)    # enable to convert to Oklch (cylindrical Oklab) in the range 0 to 1.
    fs  = Default (fulls,     true)

    mat = Color_Fuzzy_search(mat)
    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    # LMS version matrix of Oklab
    M1 = [0.8189330101, 0.3618667424, -0.1288597137, \
          0.0329845436, 0.9293118715,  0.0361456387, \
          0.0482003018, 0.2643662691,  0.6338517070]

    M2 = [0.2104542553,  0.7936177850, -0.0040720468, \
          1.9779984951, -2.4285922050,  0.4505937099, \
          0.0259040371,  0.7827717662, -0.8086757660]

    mata = RGB_to_XYZ (R, mat[0], list=true)
    M1   = MatrixTranspose(M1)
    LMS  = MatrixDot(mata, M1)
    M2   = MatrixTranspose(M2)

    b32m = bi == 32 ? "" : ex_dlut(" range_max *", bi, fs)
    b32d = bi == 32 ? "" : ex_dlut(" range_max /", bi, fs)

    L = Expr(R,G,B, "x "+b32d+" "+string(LMS[0])+" * y "+b32d+" "+string(LMS[3])+" * + z "+b32d+" "+string(LMS[6])+" * + dup dup 0 >= swap 0.333333333 ^ swap neg 0.333333333 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
    M = Expr(R,G,B, "x "+b32d+" "+string(LMS[1])+" * y "+b32d+" "+string(LMS[4])+" * + z "+b32d+" "+string(LMS[7])+" * + dup dup 0 >= swap 0.333333333 ^ swap neg 0.333333333 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
    S = Expr(R,G,B, "x "+b32d+" "+string(LMS[2])+" * y "+b32d+" "+string(LMS[5])+" * + z "+b32d+" "+string(LMS[8])+" * + dup dup 0 >= swap 0.333333333 ^ swap neg 0.333333333 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")

        Ls  = " x "+b32d+" "+string(M2[0])+" * y "+b32d+" "+string(M2[3])+" * + z "+b32d+" "+string(M2[6])+" * +"+b32m
        Lk  = isy ? Expr(L,M,S, Ls, optSingleMode=true) : nop()

    if (!cy) {

        as  = " x "+b32d+" "+string(M2[1])+" * y "+b32d+" "+string(M2[4])+" * + z "+b32d+" "+string(M2[7])+" * + 1 + 0.5 *"+b32m
        bs  = " x "+b32d+" "+string(M2[2])+" * y "+b32d+" "+string(M2[5])+" * + z "+b32d+" "+string(M2[8])+" * + 1 + 0.5 *"+b32m

        if (isy) {

            a   = Expr(L,M,S, as, optSingleMode=true)
            b   = Expr(L,M,S, bs, optSingleMode=true)
            [Lk, a, b]

        } else { Expr(L,M,S, Ls, as, bs, format=PixelType(RGB), optSingleMode=true) }

    } else {

        Cs  = " x "+b32d+" X@ "+string(M2[1])+" * y "+b32d+" Y@ "+string(M2[4])+" * + z "+b32d+" Z@ "+string(M2[7])+" * + dup *
                X             "+string(M2[2])+" * Y             "+string(M2[5])+" * + Z             "+string(M2[8])+" * + dup * + sqrt pi *"+b32m
        hs  = " x "+b32d+" X@ "+string(M2[1])+" * y "+b32d+" Y@ "+string(M2[4])+" * + z "+b32d+" Z@ "+string(M2[7])+" * +
                X             "+string(M2[2])+" * Y             "+string(M2[5])+" * + Z             "+string(M2[8])+" * + swap atan2 pi + pi 2 * /"+b32m

        if (isy) {

            C  = Expr(L,M,S, Cs, optSingleMode=true)
            h  = Expr(L,M,S, hs, optSingleMode=true)
            [Lk, C, h]

        } else { Expr(L,M,S, Ls, Cs, hs, format=PixelType(RGB), optSingleMode=true) } } }



function Oklab_to_RGB (clip Lab, clip "a", clip "b", bool "Jch", string "matrix", bool "fulls") {

    isy = isy(Lab)
    bi  = BitsPerComponent(Lab)

    mat = Default (matrix, "Rec709")
    cy  = Default (Jch,      false)   # enable to convert from OkLch (cylindrical OkLab) in the range 0 to 1.
    fs  = Default (fulls,     true)

    mat = Color_Fuzzy_search(mat)
    clp = !isy ? ExtractClip(Lab) : nop()
    Lk  = !isy ? clp[0] :    Lab
    a   = !isy ? clp[1] :     a
    b   = !isy ? clp[2] :      b

    # LMS matrix version of Oklab
    M1 = [0.8189330101, 0.3618667424, -0.1288597137, \
          0.0329845436, 0.9293118715,  0.0361456387, \
          0.0482003018, 0.2643662691,  0.6338517070]

    M2 = [0.2104542553,  0.7936177850, -0.0040720468, \
          1.9779984951, -2.4285922050,  0.4505937099, \
          0.0259040371,  0.7827717662, -0.8086757660]

    M2   = MatrixTranspose(M2)
    Labc = MatrixInvert(M2)

    b32m = bi == 32 ? "" : ex_dlut(" range_max *", bi, fs)
    b32d = bi == 32 ? "" : ex_dlut( "range_max /", bi, fs)
    nm   = !cy ? "2 * 1 -" : ""

    if (!cy) {

        L = Expr(Lk, a, b, "x "+b32d+" "+string(Labc[0])+" * y "+b32d+" "+nm+" "+string(Labc[3])+" * + z "+b32d+" "+nm+" "+string(Labc[6])+" * + dup dup 0 >= swap 3 ^ swap neg 3 ^ neg ?"+b32m, optSingleMode=true)
        M = Expr(Lk, a, b, "x "+b32d+" "+string(Labc[1])+" * y "+b32d+" "+nm+" "+string(Labc[4])+" * + z "+b32d+" "+nm+" "+string(Labc[7])+" * + dup dup 0 >= swap 3 ^ swap neg 3 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
        S = Expr(Lk, a, b, "x "+b32d+" "+string(Labc[2])+" * y "+b32d+" "+nm+" "+string(Labc[5])+" * + z "+b32d+" "+nm+" "+string(Labc[8])+" * + dup dup 0 >= swap 3 ^ swap neg 3 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")

    } else {

        L = Expr(Lk, a, b, "x "+b32d+" "+string(Labc[0])+" * z "+b32d+" pi 2 * * pi - H@ cos y "+b32d+" pi / Y@ * "+string(Labc[3])+" * + H sin Y * "+string(Labc[6])+" * + dup dup 0 >= swap 3 ^ swap neg 3 ^ neg ?"+b32m, optSingleMode=true)
        M = Expr(Lk, a, b, "x "+b32d+" "+string(Labc[1])+" * z "+b32d+" pi 2 * * pi - H@ cos y "+b32d+" pi / Y@ * "+string(Labc[4])+" * + H sin Y * "+string(Labc[7])+" * + dup dup 0 >= swap 3 ^ swap neg 3 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
        S = Expr(Lk, a, b, "x "+b32d+" "+string(Labc[2])+" * z "+b32d+" pi 2 * * pi - H@ cos y "+b32d+" pi / Y@ * "+string(Labc[5])+" * + H sin Y * "+string(Labc[8])+" * + dup dup 0 >= swap 3 ^ swap neg 3 ^ neg ?"+b32m, optSingleMode=true,scale_inputs="none")
    }

    M1   = MatrixTranspose(M1)
    XYZ  = MatrixInvert(M1)
    mata = XYZ_to_RGB(Lk, mat[0], list=true)
    RGB  = MatrixDot(XYZ, mata)

        Rs = "x "+b32d+" "+string(RGB[0])+" * y "+b32d+" "+string(RGB[3])+" * + z "+b32d+" "+string(RGB[6])+" * + "+b32m
        Gs = "x "+b32d+" "+string(RGB[1])+" * y "+b32d+" "+string(RGB[4])+" * + z "+b32d+" "+string(RGB[7])+" * + "+b32m
        Bs = "x "+b32d+" "+string(RGB[2])+" * y "+b32d+" "+string(RGB[5])+" * + z "+b32d+" "+string(RGB[8])+" * + "+b32m

    if (isy) {

        R = Expr(L,M,S, Rs, optSingleMode=true)
        G = Expr(L,M,S, Gs, optSingleMode=true)
        B = Expr(L,M,S, Bs, optSingleMode=true)
        [R, G, B]

    } else { Expr(L,M,S, Rs, Gs, Bs, format=PixelType(Lab), optSingleMode=true) } }




####### FUNCTION TRANSFORMS #######


# OETF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_f (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    gamma  = Default(gamma, 1/0.45)       # gamma
    alpha  = Default(alpha,   0.0 )       # extension in x coords of the linear part
    tv_in  = Default(tv_range_in,    !fs)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )    # Chroma planes TV<->PC conversion or not
    si     = ex_UVf(rgb, bi)

    scl = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    beta   = (( gamma - 1.0) / alpha) * pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = alpha / ( gamma - 1.0)
    aplus  = 1 / (1. + alpha)
    eps    = 8 < bi < 32 ? "0.001 -" : ""

    str    = alpha > 0.0 ? Format("range_min x "+rangePC+" max A@ {phi} > A {alpha} + {aplus} * {gamma} ^ A {beta} * ? "+rangeTV) : \
                           Format("range_min x "+rangePC+" "+eps+" max {gamma} ^ "+rangeTV+"")

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    gamma <= 1.0 ? last                                      : \
    isy          ? Expr(str                       , lut=lut) : \
    UV == 1      ? Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? PropSet("_ColorRange", tv_out?1:0)        : last }


# EOTF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_r (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    gamma  = Default(gamma, 1/0.45)       # gamma
    alpha  = Default(alpha,   0.0 )       # extension in x coords of the linear part
    tv_in  = Default(tv_range_in,    !fs)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )    # Chroma planes TV<->PC conversion or not
    si     = ex_UVf(rgb, bi)

    scl = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    beta   = pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = pow( ( gamma - 1.0) / alpha, gamma - 1.0) * pow( ( 1.0 + alpha) / gamma, gamma)
    igam   = 1. / gamma
    aplus  = 1. + alpha

    str    = alpha > 0.0 ? Format("range_min x "+rangePC+" max A@ {beta} > {aplus} A {igam} ^ * {alpha} - A {phi} * ? "+rangeTV) : \
                           Format("range_min x "+rangePC+" max {igam} ^ "+rangeTV+"")

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    gamma <= 1.0 ? last                                      : \
    isy          ? Expr(str                       , lut=lut) : \
    UV == 1      ? Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? PropSet("_ColorRange", tv_out?1:0)        : last }


# Linear to ACEScct: https://github.com/ampas/aces-dev
function ACEScct_f (clip c, bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    tv_in  = Default(tv_range_in,     !fs)
    tv_out = Default(tv_range_out,  tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )
    si     = ex_UVf(rgb, bi)

    scl    = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    X_BRK  = 0.0078125
    coeffA = 10.5402377416545
    coeffB = 0.0729055341958355
    lb     = 1. / log(2)
    coeffC = 1 / 17.52

    str    = Format("x "+rangePC+" A@ {X_BRK} <= A {coeffA} * {coeffB} + A log {lb} * 9.72 + {coeffC} * ? "+rangeTV)

    str    = ex_dlut( str, bi, !tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    isy     ?      Expr(str                       , lut=lut) : \
    UV == 1 ?      Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? PropSet("_ColorRange", tv_out?1:0)        : last }


# ACEScct to Linear: https://github.com/ampas/aces-dev
function ACEScct_r (clip c, bool "tv_range_in", bool "tv_range_out", int "UV") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    tv_in  = Default(tv_range_in,    !fs)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 )
    si     = ex_UVf(rgb, bi)

    scl    = tv_in!=tv_out && ( 8 < bi < 32) ? string(!tv_out ? 257/256. : 256/257.)+" *" : ""

    rangePC =         tv_in  ? "ymin - ymax ymin - /"  : bi==32 ? "" : "range_max /"
    rangeTV = ex_dlut(tv_out ? "ymax ymin - * ymin +"  : bi==32 ? "" : "range_max *", bi, !tv_out)

    Y_BRK  = 0.155251141552511
    coeffA = 1 / 10.5402377416545
    coeffB = 0.0729055341958355

    str    = Format("x "+rangePC+" A@ {Y_BRK} > 2 A 17.52 * 9.72 - ^ A {coeffB} - {coeffA} * ? "+rangeTV)

    str    = ex_dlut( str, bi,!tv_in)
    cstr   = tv_in && !tv_out ? "x cmin - range_max cmax cmin - / * "     : \
            !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin + "+scl : ""

    cstr   = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, !tv_in, si) : str

    isy     ?      Expr(str                       , lut=lut) : \
    UV == 1 ?      Expr(str, ""                   , lut=lut) : \
                   Expr(str, cstr, scale_inputs=si, lut=lut)
    tv_in!=tv_out? PropSet("_ColorRange", tv_out?1:0)        : last }


# Other names:  Broadcast Safe, Studio Swing, Limited/Narrow/Video/Head/TV range.
# For opposite: Full Swing, Full/Data/CG/RGB/PC range.
# Other:        SMPTE+, Extended Range (Ocassional case in HLG for 10-bit [64-1020] narrow blacks + super-whites)
function SMPTE_legal (clip a, bool "forward", int "Y", int "UV", bool "fulls", bool "fulld") {

    rgb = isRGB(a)
    yuv = isYUV(a) # as in !isy && !rgb
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    fw  = Default(forward,  fs)     # forward converts to SMPTE legal, otherwise converts to Full Range.
    Y   = Default(Y,            3 )
    UV  = Default(UV, isy ? 1 : 3 )
    fi  = Defined(fulls) || Defined(fulld)
    fs  = Default(fulls,    fs)
    fd  = Default(fulld,   !fw)
    si  = ex_UVf(rgb, bi)

    if (fi && fs!=fd) {
        scl = fs!=fd && ( 8 < bi < 32) ? string(fd ? 257/256. : 256/257.)+" *" : ""

        str  = fw ? "x ymax ymin - range_max / * ymin  + "+scl : \
                    "x ymin - range_max ymax ymin - / *  "

        cstr = fw ? "x cmax cmin - range_max / * cmin  + "+scl : \
                    "x cmin - range_max cmax cmin - / *  "

        str  =        ex_Yexpr(  str,  Y, bi, rgb, fs)
        cstr = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, fs, si) : str

        isy     ? Expr(a, str                       , lut=lut) : \
        UV == 1 ? Expr(a, str, ""                   , lut=lut) : \
                  Expr(a, str, cstr, scale_inputs=si, lut=lut)
                  PropSet("_ColorRange", fw?1:0)
    } else {
        ConvertBits(a, bi, fulls=fw, fulld=!fw)
        Y == 3 && UV != 3 && yuv ? mergechroma(a) : \
        Y != 3 && UV == 3 && yuv ? mergeluma  (a) : \
        Y != 3 && UV != 3        ?             a  : last } } # faster than CombinePlanes()


# For fixing purposes. To convert from bitshift scale to fullscale and reverse (no range conversion, as in TV to PC levels)
function Full_scale (clip a, bool "forward", int "Y", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fsd = propNumElements (a,"_ColorRange")  > 0
    fs  = fsd                                    ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    fw  = Default(forward,     !fs) # forward converts to full scale, otherwise converts to bitshift scale
    Y   = Default(Y,            3 )
    UV  = Default(UV, isy ? 1 : 3 )
    si  = ex_UVf(rgb, bi)

    scl = fw ? 257/256. : 256/257.

    str  = Format("x {scl} *")
    cstr = !rgb ? ex_UVexpr( str, UV, bi, rgb, fs, si) : ex_dlut(str, bi, fs)
    str  =        ex_Yexpr(  str,  Y, bi, rgb, fs)

    !(8 < bi < 32) ?      a                                       : \
    isy            ? Expr(a, str                       , lut=lut) : \
    UV == 1        ? Expr(a, str, ""                   , lut=lut) : \
                     Expr(a, str, cstr, scale_inputs=si, lut=lut)
    !fsd           ? PropSet("_ColorRange", !fw?1:0)              : last }


# SoftLimiter (11-01-2022)
#
# SoftLimiter is an inclusive limiter, it brings clips with under or overshoot values to in-range legal broadcast values
# It does so in a gentle manner by rolling off the values into range without altering the clip's levels and then clipping leftovers.
# RGB is not yet supported.
#
# Disclaimer1: This is not a range conversion filter! Input is assumed to be "legal/tv range"
# Disclaimer2: For static mode, first find the under and overshoot values by inspecting the clip with show=true
#
# Dependencies: ExTools
#               ResizersPack (for show)
#
# Examples:
#   SoftLimiter(16,235)        # no rolloff (straight clamp), assumes input IS legal (within 16,235)
#   SoftLimiter(12,240,12,245) # Bring specified values to legal range with rolloff
#
# modes:
# dyn = 0  -> static mode, set values after manual inspection
# dyn = 1  -> accumulative loose  dynamic mode. Very conservative, for set and forget (after proper cropping black borders)
# dyn = 2  ->              loose  dynamic mode. Medium,         will bring some values into range (recommended)
# dyn = 3  ->              strict dynamic mode. Very sensitive, will bring many values into range
#
function SoftLimiter (clip a, float "lo", float "hi", float "lo_c", float "hi_c", int "tolerance", int "dyn", bool "show", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    w   = Width(a)
    h   = Height(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    lo  = Default(lo,      16)   # Low  limit
    hi  = Default(hi,     235)   # High limit
    loc = Default(lo_c,    lo)   # Low  limit (Chroma)
    hic = Default(hi_c,   240)   # High limit (Chroma)
    tol = Default(tolerance,0)   # 0-100 Percentage of allowed under/overshoot
    dyn = Default(dyn,      0)   # 0: static  1: accumulated loose (min/max 0.454% ignored)  2: medium (min/max 0.2% ignored)  3: strict (min/max 0.1% ignored)
    sh  = Default(show, false)
    UV  = Default(UV, isy ? 1 : 3 )
    si  = ex_UVf(rgb, bi)

    # Store for 'show' when dyn=0
    if (sh && dyn==0) {
        slo  = lo
        shi  = hi
        sloc = loc
        shic = hic
        sdyn = dyn
    }

    lo  = min(16, max(0,   lo))   loc  = min(16, max(0,   loc))
    hi  = min(255,max(235, hi))   hic  = min(255,max(240, hic))

    if (tol > 0) {
    pc  = tol/100.
    lo  = lo + ((16-lo)  * pc)    loc  = loc + ((16-loc)  * pc)
    hi  = hi - ((hi-235) * pc)    hic  = hic - ((hic-240) * pc)
    }

    lo0 = lo == 16                loc0 = loc == 16
    hi0 = hi == 235               hic0 = hic == 240


    if (sh) {

        a.ConvertBits(8, dither=1, fulls=fs)
        w4   = nmod(w/4.)
        h2   = nmod(h/2.)
        w2   = w4*2
        n4   = min(w4,h2)
        padw = (w4-n4)/2
        padh = (h2-n4)/2
        lo   = ex_bs(lo,  8, bi, fs)
        loc  = ex_bs(loc, 8, bi, fs)
        loc  = bi > 16 ? loc - 0.5 : loc
        hi   = ex_bs(hi,  8, bi, fs)
        hic  = ex_bs(hic, 8, bi, fs)
        hic  = bi > 16 ? hic - 0.5 : hic

        b = StackHorizontal( \
            Histogram("levels").blackmanresize(w4,h2,w,0,256,256), \
            Histogram("color2").blackmanresize(n4,n4,w,0,256,256).AddBorders(padw+padw%2, padh+padh%2, padw-padw%2, padh-padh%2) )

        c = StackVertical( \
            a.Limiter(lo, hi, loc, hic, "luma_grey"  ).Subtitle("Luma Spill"  , align=7, size=30), \
            a.Limiter(lo, hi, loc, hic, "chroma_grey").Subtitle("Chroma Spill", align=7, size=30) ).BicubicResize(w2,h2*2,-0.5,0.25).ConvertBits(8, dither=1, fulls=fs)

        d = TurnRight().Histogram(mode="classic").BilinearResize(h2,w2,src_left=h2*2,src_width=-0).TurnLeft()

        s = StackHorizontal(StackVertical(d, b), c).PadResize(w, h ).ConvertBits(bi, fulls=fs)
    }


    if (dyn > 0) {
        a
        ab = removegrain(12,UV==3?12:-1)
        th = dyn > 2 ? 0.1 : dyn > 1 ? 0.2 : 0.454
        PS = "Y  = PlaneMinMaxStats(ab, th, 0, 0, false)
              U  = PlaneMinMaxStats(ab, th, 0, 1, false)
              V  = PlaneMinMaxStats(ab, th, 0, 2, false)
              Y1 = ex_bs(Y[2], bi, 8, fs, flt=true)     Y2 = ex_bs(Y[3], bi, 8, fs, flt=true)
              U1 = ex_bs(U[2], bi, 8, fs, flt=true)     U2 = ex_bs(U[3], bi, 8, fs, flt=true)
              V1 = ex_bs(V[2], bi, 8, fs, flt=true)     V2 = ex_bs(V[3], bi, 8, fs, flt=true)"

        if (sh) {
            ScriptClip( function [ab,bi,fs,th,PS,tol,uv] () {
            Eval(PS)
            fl = "%0.2f"  gp="     "
            SoftLimiter(             Y1,Y2,(U1+V1)/2.,(U2+V2)/2., tol, 0, false, uv)
            PropSet("_MinMaxStats", [Y1,Y2,(U1+V1)/2.,(U2+V2)/2.])
            Subtitle("YMin: "+string(Y1, fl)+gp+"YMax: "+string(Y2, fl)+gp+"UVMin: "+string((U1+V1)/2., fl)+gp+"UVMax: "+string((U2+V2)/2., fl), align=1) }, after_frame=true )
        } else {
            ScriptClip( function [ab,bi,fs,th,tol,uv,PS] () {
            Eval(PS)
            SoftLimiter(Y1, Y2, (U1+V1)/2., (U2+V2)/2., tol, 0, false, uv) }, after_frame=true )
        }

    } else {


        lol  = ex_bs(16,  8, bi, fs)
        hil  = ex_bs(235, 8, bi, fs)
        hicl = ex_bs(240, 8, bi, fs)

    if (lo0 && loc0 && hi0 && hic0 && !(w == h == 256)) {

        limiter(a, lol,hil,bi>16?lol-0.5:lol,bi>16?hicl-0.5:hicl)

    } else {

        b = spline(hi,  236,-0.44, 237,-0.815, 238,-1.131, 239,-1.396, 240,-1.617, 241,-1.8, 242,-1.951, 243,-2.073, 244,-2.17, 245,-2.247, 246,-2.305, 247,-2.348, 248,-2.378, 249,-2.397, 250,-2.4065, 251,-2.408, 252,-2.408, 253,-2.408, 254,-2.4078, 255,-2.4077)
        c = spline(hic, 236,-0.44, 237,-0.815, 238,-1.131, 239,-1.396, 240,-1.617, 241,-1.8, 242,-1.951, 243,-2.073, 244,-2.17, 245,-2.247, 246,-2.305, 247,-2.348, 248,-2.378, 249,-2.397, 250,-2.4065, 251,-2.408, 252,-2.408, 253,-2.408, 254,-2.4078, 255,-2.4077)
        d = spline(lo,  0,-1.871, 1,-1.861, 2,-1.845, 3,-1.8215, 4,-1.7905, 5,-1.7495, 6,-1.697, 7,-1.6325, 8,-1.552, 9,-1.454, 10,-1.3365, 11,-1.195, 12,-1.028, 13,-0.829, 14,-0.595, 15,-0.321)
        e = spline(loc, 0,-1.871, 1,-1.861, 2,-1.845, 3,-1.8215, 4,-1.7905, 5,-1.7495, 6,-1.697, 7,-1.6325, 8,-1.552, 9,-1.454, 10,-1.3365, 11,-1.195, 12,-1.028, 13,-0.829, 14,-0.595, 15,-0.321)

        phi = 20
        phr = 1./phi
        bi32m = bi == 32 ? "" : " range_max *"
        bi32d = bi == 32 ? "" : " range_max /"

        hi  = Format("    x "+bi32d+"   dup log {phi} * exp 1 + log {phr} {b} * * "+expT(1)+" *  ")
        lo  = Format("1 1 x "+bi32d+" - dup log {phi} * exp 1 + log {phr} {d} * * "+expT(1)+" * -")
        hic = Format("    x "+bi32d+"   dup log {phi} * exp 1 + log {phr} {c} * * "+expT(1)+" *  ")
        loc = Format("1 1 x "+bi32d+" - dup log {phi} * exp 1 + log {phr} {e} * * "+expT(1)+" * -")

        clp = w == h == 256 # for plot purposes
        str  = (lo0  && hi0  ? "x " :  (lo0  && !hi0  ? hi  : !lo0  && hi0  ? lo  : "x range_half > "+hi +" "+lo +" ?") + bi32m) + ( clp ? "" : Format(" {lol} {hil}  clip")) # still need to account for 'tolerance'
        cstr =  loc0 && hic0 ? "x " : ((loc0 && !hic0 ? hic : !loc0 && hic0 ? loc : "x range_half > "+hic+" "+loc+" ?") + bi32m  + ( clp ? "" : Format(" {lol} {hicl} clip")))


        str  =        ex_dlut  ( str,     bi,      fs)
        cstr = !rgb ? ex_UVexpr(cstr, UV, bi, rgb, fs, si) : str

        isy     ? Expr(a, str                       , lut=lut) : \
        UV == 1 ? Expr(a, str, ""                   , lut=lut) : \
                  Expr(a, str, cstr, scale_inputs=si, lut=lut) } }

    if (sh) {
        sts = propNumElements("_MinMaxStats") > 0
        sw  = nmod(w/5.)   sh = sw
        plt = GradientLinear(last, zoom=1, positive=true, smooth=true, tv_range=false)
        plt = sts ? ScriptClip(blankclip(last,width=256,height=256,channels=0), function[last,plt] () {
                        sts = propGetAsArray("_MinMaxStats")
                        SoftLimiter(plt,sts[0],sts[1],sts[2],sts[3],0,0)
                        HistoCurve(size=1,gradient=false) } ) : \
                    plt.SoftLimiter (slo,shi,sloc,shic,0,0)
        plt = sts ? plt : plt.HistoCurve(size=1,gradient=false)
        plt = plt.BicubicResize(sw,sh,-0.5,0.25)
        plt = PadBorders(plt,w-sw,0,0,h-sh)
        plt = Merge(plt)
        plt = ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
        StackVertical(plt, s) } }






####### DATA RETRIEVAL FUNCTIONS #######



# Matrix, Primaries, Illuminant and Transfer fuzzy search. Input: string, Output: [string, ID]
function Color_Fuzzy_search (string matrix) {

    matrix = UCase(matrix)
    matrixn =
\     (FindStr(matrix,"709" )>0 ) ? "Rec709"
\   : (matrix == "HDTV"         ) ? "Rec709"
\   : (matrix == "sRGB"         ) ? "sRGB"
\   : (matrix == "XYZ"          ) ? "XYZ"
\   : (matrix == "SDTV"         ) ? "170M"
\   : (FindStr(matrix, "274")>0 ) ? "170M"
\   : (FindStr(matrix, "601")>0 ) ? "170M"
\   : (FindStr(matrix, "525")>0 ) ? "170M"
\   : (FindStr(matrix, "170")>0 ) ? "170M"
\   : (matrix == "jpeg"         ) ? "170M"
\   : (matrix == "jpg"          ) ? "170M"
\   : (matrix == "NTSC"         ) ? "170M"
\   : (matrix == "SMPTE-C"      ) ? "170M"
\   : (matrix == "YPbPr"        ) ? "170M"
\   : (matrix == "YCC"          ) ? "Rec709"
\   : (matrix == "YUV"          ) ? "Rec709"
\   : (matrix == "sYCC"         ) ? "Rec709"
\   : (matrix == "YCbCr"        ) ? "Rec709"
\   : (FindStr(matrix,"NCL"  )>0) ? "Rec2020NCL"
\   : (FindStr(matrix,"20-10")>0) ? "Rec2020NCL"
\   : (FindStr(matrix,"CL"   )>0) ? "Rec2020CL"
\   : (FindStr(matrix,"20-12")>0) ? "Rec2020CL"
\   : (FindStr(matrix,"2020")>0 ) ? "Rec2020NCL"
\   : (FindStr(matrix,"2084")>0 ) ? "Rec2020CL"
\   : (FindStr(matrix,"2100")>0 ) ? "Rec2020CL"
\   : (FindStr(matrix,"DOVI")>0 ) ? "Rec2020DV5"
\   : (FindStr(matrix,"VISION")>0)? "Rec2020DV5"
\   : (FindStr(matrix,"2085")>0 ) ? "YDzDx"
\   : (matrix == "AdobeWideGamut")? "AWG"
\   : (matrix == "AWG"          ) ? "AWG"
\   : (matrix == "Adobe"        ) ? "AdobeRGB"
\   : (matrix == "opRGB"        ) ? "AdobeRGB"
\   : (matrix == "opYCC"        ) ? "AdobeRGB"
\   : (FindStr(matrix, "DCI")>0 ) ? "DCI-P3"
\   : (matrix == "P3"           ) ? "Display-P3"
\   : (matrix == "P3D65"        ) ? "Display-P3"
\   : (FindStr(matrix,"DISPLAY")>0)?"Display-P3"
\   : (matrix == "AP1"          ) ? "ACEScg"
\   : (matrix == "AP0"          ) ? "ACES2065"
\   : (matrix == "ACEScg"       ) ? "ACEScg"
\   : (matrix == "ACESCCt"      ) ? "ACESCCt"
\   : (FindStr(matrix,"ACES2")>0) ? "ACES2065"
\   : (FindStr(matrix, "240")>0 ) ? "240M"
\   : (matrix == "PAL"          ) ? "470BG"
\   : (matrix == "SECAM"        ) ? "470BG"
\   : (matrix == "NTSC-M"       ) ? "470M"
\   : (matrix == "FCC"          ) ? "470M"
\   : (FindStr(matrix,"470M")>0 ) ? "470M"
\   : (FindStr(matrix,"470" )>0 ) ? "470BG"
\   : (FindStr(matrix,"1701")>0 ) ? "470BG"
\   : (FindStr(matrix,"625" )>0 ) ? "470BG"
\   : (matrix == "OPP"          ) ? "OPP"
\   : (matrix == "OOO"          ) ? "OPP" : ""

# * ST2084 or ARIB STD-B67 is the name of the normative/paper not the transfer function
    transfer =
\     (FindStr(matrix,"2084")>0 ) ? "PQ"
\   : (FindStr(matrix,"2100")>0 ) ? "PQ"
\   : (matrix == "PQ"           ) ? "PQ"
\   : (matrix == "Perceptual"   ) ? "PQ"
\   : (matrix == "Rec2020DVp5"  ) ? "PQ"
\   : (matrix == "HLG"          ) ? "HLG"
\   : (FindStr(matrix,"ARIB")>0 ) ? "HLG"
\   : (FindStr(matrix,"B67" )>0 ) ? "HLG"
\   : (FindStr(matrix,"BBC" )>0 ) ? "HLG"
\   : (FindStr(matrix,"NHK" )>0 ) ? "NHK HLG"
\   : (matrix == "1886a"        ) ? "1886a"
\   : (FindStr(matrix,"1886")>0 ) ? "1886"
\   : (FindStr(matrix,"428" )>0 ) ? "DCI-P3"
\   : (matrix == "Camera"       ) ? "170M"
\   : (matrix == "Rec709-Camera") ? "170M"
\   : (matrix == "AWG"          ) ? "AdobeRGB"
\   : (matrix == "XYZ"          ) ? "linear"
\   : (matrix == "linear"       ) ? "linear"
\   : (matrix == "ACEScg"       ) ? "linear"
\   : (matrix == "ACES2065"     ) ? "linear"
\   : (matrix == "ACESCCt"      ) ? "ACESCCt" : matrixn

    illuminant =
\     (matrix == "50"            ) ? "D50"
\   : (matrix == "D50"           ) ? "D50"
\   : (matrix == "55"            ) ? "D55"
\   : (matrix == "D55"           ) ? "D55"
\   : (matrix == "60"            ) ? "D60"
\   : (matrix == "D60"           ) ? "D60"
\   : (matrix == "DCI"           ) ? "DCI"
\   : (matrix == "65"            ) ? "D65"
\   : (matrix == "D65"           ) ? "D65"
\   : (matrix == "75"            ) ? "D75"
\   : (matrix == "D75"           ) ? "D75"
\   : (matrix == "C"             ) ? "C"
\   : (matrix == "93"            ) ? "D93"
\   : (matrix == "D93"           ) ? "D93" : matrixn


    # ID for _Matrix frame properties (BT.2380-2. Table 2.8)
    idm =
\     (matrixn == "XYZ"            ) ? 0
\   : (matrixn == "RGB"            ) ? 0
\   : (matrixn == "sRGB"           ) ? 1
\   : (matrixn == "Rec709"         ) ? 1
\   : (matrixn == "470M"           ) ? 4
\   : (matrixn == "470BG"          ) ? 5
\   : (matrixn == "170M"           ) ? 6
\   : (matrixn == "240M"           ) ? 7
\   : (matrixn == "Rec2020NCL"     ) ? 9
\   : (matrixn == "Rec2020CL"      ) ? 10
\   : (matrixn == "Rec2020"        ) ? 9
\   : (matrixn == "YDzDx"          ) ? 11
\   : (matrixn == "DCI-P3"         ) ? 12
\   : (matrixn == "Display-P3"     ) ? 12
\   : (matrixn == "ACEScg"         ) ? 13
\   : (matrixn == "ACES2065"       ) ? 14
\   : (matrixn == "ACESCCt"        ) ? 15
\   : (matrixn == "AdobeRGB"       ) ? 16
\   : (matrixn == "AWG"            ) ? 17 : -1
# * YDzDx is defined in SMPTE 2085

    # ID for _Primaries frame properties (BT.2380-2. Table 2.6)
    ids =
\     (matrixn == "Rec2020CL"      ) ? 9
\   : (matrixn == "DCI-P3"         ) ? 11 : idm

    idi =
\     (illuminant == "D50"         ) ? 0
\   : (illuminant == "D55"         ) ? 1
\   : (illuminant == "D60"         ) ? 2
\   : (illuminant == "DCI"         ) ? 3
\   : (illuminant == "D65"         ) ? 4
\   : (illuminant == "C"           ) ? 5
\   : (illuminant == "D75"         ) ? 6
\   : (illuminant == "D93"         ) ? 7 : -1

    # ID for _Transfer frame properties (BT.2380-2. Table 2.7)
    idt =
\     (transfer == "1886a"        ) ? 0
\   : (transfer == "1886"         ) ? 1
\   : (transfer == "Rec709"       ) ? 1
\   : (transfer == "470M"         ) ? 4
\   : (transfer == "470BG"        ) ? 5
\   : (transfer == "170M"         ) ? 6
\   : (transfer == "Rec709-Camera") ? 6
\   : (transfer == "240M"         ) ? 7
\   : (transfer == "linear"       ) ? 8
\   : (transfer == "log100"       ) ? 9
\   : (transfer == "log316"       ) ? 10
\   : (transfer == "xvYCC"        ) ? 11
\   : (transfer == "1361"         ) ? 12
\   : (transfer == "sRGB"         ) ? 13
\   : (transfer == "Display-P3"   ) ? 13
\   : (transfer == "Rec2020"      ) ? 14
\   : (transfer == "Rec2020NCL"   ) ? 14
\   : (transfer == "Rec2020CL"    ) ? 15
\   : (transfer == "PQ"           ) ? 16
\   : (transfer == "DCIXYZ"       ) ? 17
\   : (transfer == "HLG"          ) ? 18
\   : (transfer == "NHK HLG"      ) ? 19
\   : (transfer == "AdobeRGB"     ) ? 20
\   : (transfer == "ACESCCt"      ) ? 21 : -1
# * DCIXYZ is defined in smpte428-1. It's XYZ space with DCI white point for cinema distribution in DCDM format

    str = illuminant != "" ? [illuminant,idm,ids,idi,idt] : \
          transfer   != "" ? [transfer,  idm,ids,idi,idt] : \
          matrixn    != "" ? [matrixn,   idm,ids,idi,idt] : ["",-1,-1,-1,-1]

    str }



# Has prevalence over string based Color_fuzzy_search() and Format_fuzzy_search() when input input arg is undefined (ie. for Defaults() )
function color_propGet (clip a) {

    w        = width (a)
    h        = height(a)
    bi       = BitsPerComponent(a)
    isHD     = (w  > 1099 ||  h  >  599)
    isUHD    = (w  > 2599 ||  h  > 1499)

    fmt      = Format_fuzzy_search(a, PixelType(a), bi)
    cm_i     = a.propNumElements("_Model")      > 0 ? PropGetInt(a, "_Model")       : -1
    prim_i   = a.propNumElements("_Primaries")  > 0 ? PropGetInt(a, "_Primaries")   : 2
    illu_i   = a.propNumElements("_Illuminant") > 0 ? PropGetInt(a, "_Illuminant")  : -1
    mat_i    = a.propNumElements("_Matrix")     > 0 ? PropGetInt(a, "_Matrix")      : 2
    t_i      = a.propNumElements("_Transfer")   > 0 ? PropGetInt(a, "_Transfer")    : 2

    # Input Defaults
    cm_i     = cm_i   != -1 ? cm_i   : fmt[4]
    prim_i   = prim_i !=  2 ? prim_i : fmt[6] != -1 ? fmt[6] : isUHD ? 9 : isHD ? 1 : 6
    illu_i   = illu_i != -1 ? illu_i :                             prim_i == 17 || cm_i == 2 ? 0 : prim_i == 11 ? 3 : prim_i == 13 || prim_i == 14 ? 2 : 4
    mat_i    = mat_i  !=  2 ? mat_i  : fmt[5] != -1 ? fmt[5] : 3 < prim_i  < 10 ?  prim_i : cm_i == 15 ? 11 : prim_i == 11 || prim_i == 12  ? 12 : 1
    t_i      = t_i    !=  2 ? t_i    :                             cm_i == 0 || cm_i == 23 ? 8 : \
                                                                   cm_i == 24 ? 11 : \
                                                               3 < prim_i  < 8  ?  prim_i : \
                                                                   prim_i == 13 || prim_i == 14 || prim_i == 10 ? 8 : \
                                                                   prim_i == 15 ? 21 : \
                                                                   prim_i == 16 || prim_i == 17 ? 20 : \
                                                                   prim_i == 9  ? 16 : \
                                                                   prim_i == 11 ? 21 : \
                                                                   prim_i == 12 ? 13 : 1
    cm_id =
\     (cm_i == 0      ) ? ["XYZ",      "RGB"  ]
\   : (cm_i == 1      ) ? ["RGB",      "RGB"  ]
\   : (cm_i == 2      ) ? ["CMYK",     "RGBA" ]
\   : (cm_i == 3      ) ? ["YIQ",      "YCbCr"]
\   : (cm_i == 4      ) ? ["YDbDr",    "YCbCr"]
\   : (cm_i == 5      ) ? ["YCbCr",    "YCbCr"]
\   : (cm_i == 6      ) ? ["YUVr",     "YCbCr"]
\   : (cm_i == 7      ) ? ["sYUV",     "YCbCr"]
\   : (cm_i == 8      ) ? ["YUVJ",     "YCbCr"]
\   : (cm_i == 8      ) ? ["sYCC",     "YCbCr"]
\   : (cm_i == 9      ) ? ["YCoCg",    "YCbCr"]
\   : (cm_i == 10     ) ? ["YCoCgR",   "YCbCr"]
\   : (cm_i == 11     ) ? ["YcCbcCr",  "YCbCr"]
\   : (cm_i == 12     ) ? ["OPP",      "RGB"  ]
\   : (cm_i == 13     ) ? ["Jzazbz",   "YCbCr"]
\   : (cm_i == 14     ) ? ["JzCzhz",   "YCbCr"]
\   : (cm_i == 15     ) ? ["YDzDx",    "YCbCr"]
\   : (cm_i == 16     ) ? ["YCxCz",    "YCbCr"]
\   : (cm_i == 17     ) ? ["IPT",      "YCbCr"]
\   : (cm_i == 18     ) ? ["IPTJch",   "YCbCr"]
\   : (cm_i == 19     ) ? ["ICaCb",    "YCbCr"]
\   : (cm_i == 20     ) ? ["ITP",      "YCbCr"]
\   : (cm_i == 21     ) ? ["ICtCp",    "YCbCr"]
\   : (cm_i == 22     ) ? ["IPTPQc2",  "YCbCr"]
\   : (cm_i == 23     ) ? ["Yxy",      "RGB"  ]
\   : (cm_i == 24     ) ? ["xvYCC",    "YCbCr"]
\   : (cm_i == 25     ) ? ["HSV",      "RGB"  ]
\   : (cm_i == 26     ) ? ["HunterLab","YCbCr"]
\   : (cm_i == 27     ) ? ["CIELab",   "YCbCr"]
\   : (cm_i == 28     ) ? ["CIELch",   "RGB"  ]
\   : (cm_i == 29     ) ? ["CIELuv",   "YCbCr"]
\   : (cm_i == 30     ) ? ["CIELchuv", "RGB"  ]
\   : (cm_i == 31     ) ? ["CIEDuDv",  "YCbCr"]
\   : (cm_i == 32     ) ? ["CIECAM97s","YCbCr"]
\   : (cm_i == 33     ) ? ["CIECAM02", "YCbCr"]
\   : (cm_i == 34     ) ? ["CAM16",    "YCbCr"]
\   : (cm_i == 35     ) ? ["Duv",      "YCbCr"]
\   : (cm_i == 36     ) ? ["OSA",      "YCbCr"]
\   : (cm_i == 37     ) ? ["OkLab",    "YCbCr"]
\   : (cm_i == 38     ) ? ["OkLch",    "RGB"  ]
\   : (cm_i == 39     ) ? ["iCAM",     "RGB"  ]
\   : Assert (false, "color_propGet: Unknown _Model ID.")
# * YDbDr is for PAL-N and SECAM
# * xvYCC is defined in IEC61966-2-4

    range    = propNumElements(a,"_ColorRange") > 0 ? PropGetInt(a, "_ColorRange") == 1 : cm_id[1] == "YCbCr"

    # ID for _Primaries frame properties (BT.2380-2. Table 2.6)
    prim_i =
\     (prim_i == 1    ) ? "Rec709"
\   : (prim_i == 4    ) ? "470M"
\   : (prim_i == 5    ) ? "470BG"
\   : (prim_i == 6    ) ? "170M"
\   : (prim_i == 7    ) ? "240M"
\   : (prim_i == 9    ) ? "Rec2020"
\   : (prim_i == 10   ) ? "XYZ"
\   : (prim_i == 11   ) ? "DCI-P3"
\   : (prim_i == 12   ) ? "Display-P3"
\   : (prim_i == 13   ) ? "ACEScg"
\   : (prim_i == 14   ) ? "ACES2065"
\   : (prim_i == 15   ) ? "ACESCCt"
\   : (prim_i == 16   ) ? "AdobeRGB"
\   : (prim_i == 17   ) ? "AWG"
\   : Assert (false, "color_propGet: Unknown _Primaries ID.")

    # ID for _Matrix frame properties (BT.2380-2. Table 2.8)
    mat_i =
\     (mat_i == 0     ) ? "XYZ"
\   : (mat_i == 1     ) ? "Rec709"
\   : (mat_i == 4     ) ? "470M"
\   : (mat_i == 5     ) ? "470BG"
\   : (mat_i == 6     ) ? "170M"
\   : (mat_i == 7     ) ? "240M"
\   : (cm_i  == 8     ) ? "YCoCg"
\   : (mat_i == 9     ) ? "Rec2020"
\   : (mat_i == 10    ) ? "Rec2020CL"
\   : (mat_i == 11    ) ? "YDzDx"
\   : (mat_i == 12    ) ? "DCI-P3"
\   : (mat_i == 12    ) ? "Display-P3"
\   : (mat_i == 14    ) ? "ICtCp"
\   : Assert (false, "color_propGet: Unknown _Matrix ID.")

    illu_i =
\     (illu_i == 0    ) ? "D50"
\   : (illu_i == 1    ) ? "D55"
\   : (illu_i == 2    ) ? "D60"
\   : (illu_i == 3    ) ? "DCI"
\   : (illu_i == 4    ) ? "D65"
\   : (illu_i == 5    ) ? "C"
\   : (illu_i == 6    ) ? "D75"
\   : (illu_i == 7    ) ? "D93"
\   : Assert (false, "color_propGet: Unknown _Illuminant ID.")

    # ID for _Transfer frame properties (BT.2380-2. Table 2.7)
    t_i =
\     (t_i == 0       ) ? "1886a"
\   : (t_i == 1       ) ? "1886"
\   : (t_i == 4       ) ? "470M"
\   : (t_i == 5       ) ? "470BG"
\   : (t_i == 6       ) ? "170M"
\   : (t_i == 7       ) ? "240M"
\   : (t_i == 8       ) ? "linear"
\   : (t_i == 9       ) ? "log100"
\   : (t_i == 10      ) ? "log316"
\   : (t_i == 11      ) ? "xvYCC"
\   : (t_i == 12      ) ? "1361"
\   : (t_i == 13      ) ? "sRGB"
\   : (t_i == 14      ) ? "Rec2020NCL"
\   : (t_i == 15      ) ? "Rec2020CL"
\   : (t_i == 16      ) ? "PQ"
\   : (t_i == 17      ) ? "DCIXYZ"
\   : (t_i == 18      ) ? "HLG"
\   : (t_i == 19      ) ? "NHK HLG"
\   : (t_i == 20      ) ? "AdobeRGB"
\   : (t_i == 21      ) ? "ACESCCt"
\   : Assert (false, "color_propGet: Unknown _Transfer ID.")
# * 1, 14, and 15 share the same function

    # model, packing, prims, illu, matrix, transfer, range, bitdepth
    [cm_id[0],cm_id[1],prim_i,illu_i,mat_i,t_i,range,bi] }



# Jab and Model fuzzy search. Also sets model id and packing format.
function Format_fuzzy_search (clip c, string format, int bits) {

    # Block not evaluated unless Jab enum fails the search
    rgb  = isRGB(c)
    isy  = isy(c)
    Up   = rgb || isy ? c : ExtractU(c)
    rw   = width (Up) / float(width (c))
    rh   = height(Up) / float(height(c))
    a    = int(rw * 4.)
    b    = round(rh-0.01)*a

    str    = ReplaceStr(format, "P8", "")
    str    = ReplaceStr(format, "PS", "")
    trhbd  = FindStr(format,    "P1")
    format = trhbd>0 ? LeftStr(format,trhbd-1) : str


    jab =
\     (FindStr(format,"420"     )>0) ? "420"
\   : (FindStr(format, "42"     )>0) ? "420"
\   : (FindStr(format, "20"     )>0) ? "420"
\   : (FindStr(format, "12"     )>0) ? "420"
\   : (FindStr(format,"444"     )>0) ? "444"
\   : (FindStr(format, "44"     )>0) ? "444"
\   : (FindStr(format, "24"     )>0) ? "444"
\   : (FindStr(format,"422"     )>0) ? "422"
\   : (FindStr(format, "22"     )>0) ? "422"
\   : (FindStr(format, "16"     )>0) ? "422"
\   : (FindStr(format,"411"     )>0) ? "411"
\   : (FindStr(format, "11"     )>0) ? "411"
\   : (FindStr(format,"440"     )>0) ? "440"
\   : (FindStr(format, "40"     )>0) ? "410"
\   : (FindStr(format,"410"     )>0) ? "410"
\   : (FindStr(format, "41"     )>0) ? "410"
\   : (FindStr(format, "10"     )>0) ? "410"
\   : (FindStr(format,"YUV9"    )>0) ? "410"
\
\   : (FindStr(format,"RGB"     )>0) ? "444"
\   : (FindStr(format,"Yxy"     )>0) ? "444"
\   : (FindStr(format,"xyY"     )>0) ? "444"
\   : (        format=="Yxy"       ) ? "444"
\   : (        format=="xyY"       ) ? "444"
\   : (FindStr(format,"XYZ"     )>0) ? "444"
\   : (        format=="XYZ"       ) ? "444"
\   : (FindStr(format,"Jzazbz"  )>0) ? "444"
\   : (FindStr(format,"JzCzhz"  )>0) ? "444"
\   : (FindStr(format,"HSV"     )>0) ? "444"
\   : (        format=="HSV"       ) ? "444"
\   :                "4"+string(a)+string(b)


    model  = UCase(ReplaceStr(format, jab, ""))

    # store all opposing models in YUV format, otherwise (correlated) as RGB
    # Input Model, Name Normalizing, Packing format, model ID
    cm =
\     (FindStr(model, "RGB"    )>0) ? ["RGB",      "RGB",1]
\   : (        model=="JPEG"      ) ? ["YCbCr",    "YUV",5]
\   : (        model=="JPG"       ) ? ["YCbCr",    "YUV",5]
\   : (        model=="YUVJ"      ) ? ["YUVJ",     "YUV",5]
\   : (        model=="YCbCr"     ) ? ["YCbCr",    "YUV",5]
\   : (        model=="YUV"       ) ? ["YCbCr",    "YUV",5]
\   : (FindStr(model, "YV"     )>0) ? ["YCbCr",    "YUV",5]
\   : (FindStr(model, "DV"     )>0) ? ["YCbCr",    "YUV",5]
\   : (        model=="YCC"       ) ? ["YCbCr",    "YUV",5]
\   : (        model=="sYCC"      ) ? ["sYCC",     "YUV",8]
\   : (        model=="YPbPr"     ) ? ["YCbCr",    "YUV",5]
\   : (        model=="YIQ"       ) ? ["YIQ",      "YUV",3]
\   : (        model=="YDbDr"     ) ? ["YDbDr",    "YUV",4]
\   : (        model=="YUVr"      ) ? ["YUVr",     "YUV",6]
\   : (        model=="sYUV"      ) ? ["sYUV",     "YUV",7]
\   : (FindStr(model, "SHARP"  )>0) ? ["sYUV",     "YUV",7]
\   : (        model=="YcCbcCr"   ) ? ["YcCbcCrc", "YUV",11]
\   : (FindStr(model, "YCCBC"  )>0) ? ["YcCbcCrc", "YUV",11]
\   : (        model=="YCgCo"     ) ? ["YCoCg",    "YUV",9]
\   : (        model=="YCgCoR"    ) ? ["YCoCgR",   "YUV",10]
\   : (        model=="YCoCg"     ) ? ["YCoCg",    "YUV",9]
\   : (        model=="YCoCgR"    ) ? ["YCoCgR",   "YUV",10]
\   : (        model=="ICaCb"     ) ? ["ICaCb",    "YUV",19]
\   : (        model=="ICtCp"     ) ? ["ICtCp",    "YUV",21]
\   : (        model=="IPT"       ) ? ["ICtCp",    "YUV",21]
\   : (        model=="YDzDx"     ) ? ["YDzDx",    "YUV",15]
\   : (        model=="YCxCz"     ) ? ["YCxCz",    "YUV",16]
\   : (        model=="xvYCC"     ) ? ["xvYCC",    "YUV",24]
\   : (        model=="Yxy"       ) ? ["Yxy",      "RGB",23]
\   : (        model=="xyY"       ) ? ["Yxy",      "RGB",23]
\   : (        model=="XYZ"       ) ? ["XYZ",      "RGB",0]
\   : (        model=="CIEXYZ"    ) ? ["XYZ",      "RGB",0]
\   : (        model=="YZX"       ) ? ["XYZ",      "RGB",0]
\   : (        model=="CMYK"      ) ? ["CMYK",     "RGBA",2]
\   : (        model=="OPP"       ) ? ["OPP",      "RGB",12]
\   : (        model=="Jzazbz"    ) ? ["Jzazbz",   "YUV",13]
\   : (        model=="JzCzhz"    ) ? ["JzCzhz",   "YUV",14]
\   : (        model=="HSV"       ) ? ["HSV",      "RGB",24]
\   : (        model=="CIEDuv"    ) ? ["Duv",      "YUV",35]
\   : (        model=="Duv"       ) ? ["Duv",      "YUV",35]
\   : (        model=="OSA"       ) ? ["OSA",      "YUV",36]
\   : (FindStr(model, "CAM97"  )>0) ? ["CIECAM97s","YUV",32]
\   : (FindStr(model, "CAM02"  )>0) ? ["CIECAM02", "YUV",33]
\   : (FindStr(model, "CAM16"  )>0) ? ["CAM16",    "YUV",34]
\   : (FindStr(model, "HUNTER" )>0) ? ["HunterLab","YUV",26]
\   : (FindStr(model, "OK"     )>0) ? ["OkLab",    "YUV",37]
\   : (FindStr(model, "LUV"    )>0) ? ["CIELuv",   "YUV",29]
\   : (FindStr(model, "LAB"    )>0) ? ["CIELab",   "YUV",27]
\   :                     rgb ? ["RGB","RGB",1] : ["YCbCr","YUV",5]

    # Color Model based Matrix constants (for frameprops)
    ma =
\     (        cm[0]=="RGB"       ) ? 0
\   : (        cm[0]=="XYZ"       ) ? 0
\   : (        cm[0]=="xvYCC"     ) ? 1
\   : (        cm[0]=="YCoCg"     ) ? 8
\   : (        cm[0]=="ICtCp"     ) ? 14 : -1


    # Color Model based Primaries constants (for frameprops)
    pr =
\     (        cm[0]=="sYCC"      ) ? 1
\   : (        cm[0]=="XYZ"       ) ? 10 : -1

    bdpth = isy ? string(bits) : bits < 32 ? "P" + string(bits) : "PS"

    #model, jab, bitdepth type, packing, model ID, matrix ID override, prim ID override
    [cm[0], jab, bdpth, cm[1], cm[2], ma, pr] }



# Bicubic kernels are very performant but tends to 'blocking' in upscales compared to more advanced kernels
function bicubic_coeffs (string kernel) {

    # info: Keys Cubic family of filters are those that satisfy 2C+B = 1  (along the dotted line in the Cubic filters diagram)
    # Examples are Mitchell-Netravali, Robidoux (and its flavours), Catmull-Rom, Spline and Bartvander.

    rb  = 12. /(19.  +9.*sqrt(2))    # 0.378216
    rc  = 113./(58.+216.*sqrt(2))    # 0.310892
    rsb = 6.  /(13.  +7.*sqrt(2))    # 0.262015
    rsc = 7.  /(2.  +12.*sqrt(2))    # 0.368993
    rbb =      (9   -3. *sqrt(2))/7. # 0.679623
    rbc =      (1   -        rbb)/2. # 0.160189
    bbb = 0.6796227589829592
    bbc = 0.1601886205085204

    # From smoother to sharper
    c = [-1,-1]
    c = kernel == "SoftCubic100"      ? [1.0,0.0]   : c # same as GaussResize(p=21)
    c = kernel == "Robidoux Soft"     ? [rbb,rbc]   : c
    c = kernel == "SoftCubic75"       ? [0.75,0.25] : c
    c = kernel == "Bartvander"        ? [bbb,bbc]   : c # dw Originally implemented as an EWA filter by BartvanderWolf with a post-sharpening step in mind
    c = kernel == "BilcubicD"         ? [1/3.,0.0]  : c # dw Bicubic practical match to Bilinear
    c = kernel == "BilcubicU"         ? [0.5, 0.2]  : c # up Bicubic practical match to Bilinear
    c = kernel == "Hermite"           ? [0.0,0.0]   : c # dw Bicubic approximation   to Bilinear (a bit sharper than it)
    c = kernel == "Robidoux"          ? [rb,  rc]   : c
    c = kernel == "Centroid"          ? [0.37,0.35] : c # Arithmetic mean of the satisfactory zone (by Dogway)
    c = kernel == "Mitchell-Netravali"? [1/3.,1/3.] : c # Canonical Bicubic
    c = kernel == "Robidoux Sharp"    ? [rsb,rsc]   : c
    c = kernel == "SoftCubic50"       ? [0.5,0.5]   : c
    c = kernel == "Catmull-Rom"       ? [0.0,0.5]   : c # Canonical sharp Bicubic
    c = kernel == "Didee"             ? [-0.5,0.25] : c # dw Didée's downscaling sharp coefficients
    c = kernel == "Zopti"             ? [-0.6,0.4]  : c # dw Zopti calculated best from UHD to 720p: https://forum.doom9.org/showthread.php?p=1865218#post1865218
    c = kernel == "Precise Bicubic"   ? [0.0,0.75]  : c
    c = kernel == "Sharp"             ? [0.0,1.0]   : c
    c = kernel == "Hatch"             ? [0.0,-5.0]  : c

    # Aliases
    c = kernel == "Spline"            ? [1.0,0.0]   : c
    c = kernel == "SoftCubic"         ? [0.75,0.25] : c
    c = kernel == "Precise"           ? [0.0,0.75]  : c
    c = kernel == "catrom"            ? [0.0,0.5]   : c
    c = kernel == "Catmull"           ? [0.0,0.5]   : c
    c = kernel == "Mitchell"          ? [1/3.,1/3.] : c
    c = kernel == "Mitchel"           ? [1/3.,1/3.] : c
    c = kernel == "RobiSoft"          ? [rbb,rbc]   : c
    c = kernel == "RobiSharp"         ? [rsb,rsc]   : c
    c = kernel == "Robi"              ? [rb,  rc]   : c
    c = kernel == "RobidouxSoft"      ? [rbb,rbc]   : c
    c = kernel == "RobidouxSharp"     ? [rsb,rsc]   : c
    c = kernel == "B-Spline"          ? [1.0,0.0]   : c
    c = kernel == "BSpline"           ? [1.0,0.0]   : c
    c = kernel == "BCSpline"          ? [0.5,0.5]   : c
    c = kernel == "BC-Spline"         ? [0.5,0.5]   : c
    c = kernel == "CSpline"           ? [0.0,1.0]   : c
    c = kernel == "C-Spline"          ? [0.0,1.0]   : c
    c = kernel == "Didée"             ? [-0.5,0.25] : c
    c = kernel == "Dide"              ? [-0.5,0.25] : c

    c }


# JPEGs uses Rec.601 primaries, PC Levels, MPEG1 chroma placement, and can be many formats; from RGB to 420, 422 being to spec, but also 440*, 444, 411, etc
#*YUV440 or YUVJ440 are for rotated versions of 422 (rotated JPEG)
# Photoshop saves as 420 up to level 6, 422 for above

function chroma_placement (int w, int h, int nw, int nh, string matrix_i, string matrix_o, string format_i, string format_o, string jab_i, string jab_o, string "cplace_in", string "cplace_out") {

    ryw = w  / float(nw)       # source/target Y  dimensions
    ryh = h  / float(nh)

    # Input Jab to chroma units
    eps= 0.001
    a  = Eval(MidStr(jab_i, 2, 1))
    b  = Eval(MidStr(jab_i, 3, 1))
    iu =                       a  / 8.         # chroma units/pixels for U dimension in respect to luma units
    iv = (round((b/(b+eps))) + 1) / 4.         # chroma units/pixels for V dimension in respect to luma units

    # Output Jab to chroma units
    a  = Eval(MidStr(jab_o, 2, 1))
    b  = Eval(MidStr(jab_o, 3, 1))
    ou =                       a  / 8.         # chroma units/pixels for U dimension in respect to luma units
    ov = (round((b/(b+eps))) + 1) / 4.         # chroma units/pixels for V dimension in respect to luma units

                         # source chroma placement defaults
                         # top_left is always on 4:2:0 by spec
    dplacei= FindStr(format_i,"RGB")>0      ? "center"   : \
             format_i == "YUV444"           ? "center"   : \
             FindStr(matrix_i,"2020")>0     ? "top_left" : \
             FindStr(matrix_i,"2100")>0     ? "top_left" : \
             FindStr(format_i,"YcCbcCrc")>0 ? "top_left" : \
             FindStr(format_i,"ICtCp")>0    ? "top_left" : \
             format_i == "YUV420"           ? "MPEG2"    : \
             format_i == "YUV422"           ? "MPEG2"    : \
             format_i == "YUV411"           ? "MPEG1"    : \
             format_i == "YUV410"           ? "DV"       : "MPEG2"

                         # out chroma placement defaults
    dplaceo= FindStr(format_o,"RGB")>0      ? "center"   : \
             format_o == "YUV444"           ? "center"   : \
             FindStr(matrix_o,"2020")>0     ? "top_left" : \
             FindStr(matrix_o,"2100")>0     ? "top_left" : \
             FindStr(format_o,"YcCbcCrc")>0 ? "top_left" : \
             FindStr(format_o,"ICtCp")>0    ? "top_left" : \
             format_o == "YUV420"           ? "MPEG2"    : \
             format_o == "YUV422"           ? "MPEG2"    : \
             format_o == "YUV411"           ? "MPEG1"    : \
             format_o == "YUV410"           ? "DV"       : "MPEG2"

    cplacei = cplace_in =="" ? dplacei : Default (cplace_in,  dplacei)
    cplaceo = cplace_out=="" ? dplaceo : Default (cplace_out, dplaceo)

    cplacei = cplacei == "center"       ? "MPEG1"    : \
              cplacei == "JPEG"         ? "MPEG1"    : \
              cplacei == "JPG"          ? "MPEG1"    : \
              cplacei == "DV"           ? "top_left" : \
              FindStr(cplacei,"2020")>0 ? "top_left" : \
              FindStr(cplacei,"2100")>0 ? "top_left" : \
              cplacei == "left"         ? "MPEG2"    : cplacei

    cplaceo = cplaceo == "center"       ? "MPEG1"    : \
              cplaceo == "JPEG"         ? "MPEG1"    : \
              cplaceo == "JPG"          ? "MPEG1"    : \
              cplaceo == "DV"           ? "top_left" : \
              FindStr(cplaceo,"2020")>0 ? "top_left" : \
              FindStr(cplaceo,"2100")>0 ? "top_left" : \
              cplaceo == "left"         ? "MPEG2"    : cplaceo

    # Scale chroma units (MPEG1 aware)
    scloc  = cplacei == "MPEG2"       ? [-iu,  0.0]  : \
             cplacei == "MPEG1"       ? [ iu,   iv]  : \
             cplacei == "top_left"    ? [ 0.0, 0.0]  : \
             cplacei == "bottom_left" ? [ 0.0, iv*2] : \
             Assert (false, "chroma_placement: Unsupported chroma placement mode.")

    # In chroma units
    icloc  = cplacei == "MPEG2"       ? [-ou,  0.0]  : \
             cplacei == "MPEG1"       ? [ ou,   ov]  : \
             cplacei == "top_left"    ? [ 0.0, 0.0]  : \
             cplacei == "top"         ? [ ou,  0.0]  : \
             cplacei == "bottom_left" ? [ 0.0, ov*2] : \
             cplacei == "bottom"      ? [ ou,  ov*2] : \
             Assert (false, "chroma_placement: Unsupported chroma placement mode.")

    # Out chroma units [third item is _ChromaLocation index for frameprops]
    ocloc  = cplaceo == "MPEG2"       ? [-ou,  0.0,  0] : \
             cplaceo == "MPEG1"       ? [ ou,   ov,  1] : \
             cplaceo == "top_left"    ? [ 0.0, 0.0,  2] : \
             cplaceo == "top"         ? [ ou,  0.0,  3] : \
             cplaceo == "bottom_left" ? [ 0.0, ov*2, 4] : \
             cplaceo == "bottom"      ? [ ou,  ov*2, 5] : \
             Assert (false, "chroma_placement: Unsupported chroma placement mode.")

    [-scloc[0]*(1-ryw)+(ocloc[0]-icloc[0]), -scloc[1]*(1-ryh)+(ocloc[1]-icloc[1]), ocloc[2]] }




# NTSC and PAL YCbCr (Rec601 and BT-470BG) share the same coefficients defined in (https://poynton.ca/PDFs/coloureq.pdf - 10.4),
# and derived from the old SMPTE 470M (NTSC 1953) standard. Exactly:
# kr: 0.298903070250081
# kg: 0.586619854659197
# kb: 0.114477075090722
# For context (Rec709):
# kr: 0.21264933049678802
# kg: 0.71516913175582890
# kb: 0.07218152284622192
function Matrix_coef (string matrix, string "illuminant") {

    illuminant = Default(illuminant, matrix)

    mat_i =
\     (matrix == "sRGB"           ) ? 1
\   : (matrix == "170M"           ) ? 0
\   : (matrix == "Rec709"         ) ? 1
\   : (matrix == "Rec2020CL"      ) ? 5
\   : (matrix == "Rec2020NCL"     ) ? 5
\   : (matrix == "AdobeRGB"       ) ? 6
\   : (matrix == "AWG"            ) ? 7
\   : (matrix == "Display-P3"     ) ? 8
\   : (matrix == "DCI-P3"         ) ? 9
\   : (matrix == "ACEScg"         ) ? 10
\   : (matrix == "ACESCCt"        ) ? 10
\   : (matrix == "ACES2065"       ) ? 11
\   : (matrix == "240M"           ) ? 3
\   : (matrix == "470BG"          ) ? 0 : 1
# * Deriving Rec709 matrix coefficients from its primaries is noted as BT.709-2, in contrast to older and slightly different BT.709-1

    mat_wp =
\     (matrix == "170M"           ) ? 1
\   : (matrix == "Rec709"         ) ? 1
\   : (matrix == "DCI-P3"         ) ? 3
\   : (matrix == "ACES2065"       ) ? 4
\   : (matrix == "ACEScg"         ) ? 4
\   : (matrix == "AWG"            ) ? 2
\   :                                 1

    # The coordinates and CCT's are from CIE 1931 2 degree standard observer
    mat_wp =
\     (illuminant == "D50"        ) ? 2
\   : (illuminant == "D55"        ) ? 5
\   : (illuminant == "D60"        ) ? 4
\   : (illuminant == "DCI"        ) ? 3
\   : (illuminant == "D65"        ) ? 1
\   : (illuminant == "C"          ) ? 0
\   : (illuminant == "D75"        ) ? 6
\   : (illuminant == "D93"        ) ? 7 : mat_wp
# * D93 is not a D standard illuminant. Here it is defined for CCT (correlated) to consumer's TV standard "9300K+27 MPCD". "9300K+8 MPCD" for master CRT corresponds to 0.2838, 0.2984

    # Hardcode constants for the Kr, Kg, Kb derivations
    mat_w =
\     (matrix == "170M"           ) ? 0
\   : (matrix == "470BG"          ) ? 0
\   : (matrix == "AWG"            ) ? 2 : mat_wp


    #                     NTSC 1953/YCbCr   ITU-R BT.709-6/sRGB ITU-R BT.601     Y’PbPr 601        PAL/SECAM         BT-2020/BT-2100   Adobe RGB (1998)  Adobe Wide Gamut   Display-P3/D65P3  DCI-P3            AP1                AP0                D55                D75                D93
    #                     BT-470M/FCC       IEC 61966-2-1       SMPTE 170M       SMPTE 240M        BT-470BG          BT-2020/BT-2100   Adobe RGB (1998)  AWG                SMPTE RP 432-1    SMPTE RP 431-2    ACEScg/ACEScct     SMPTE ST 2065-1    D55                D75                9300K+27 MPCD   Sunlight        Overcast
    pr  = Select (mat_i,  [0.670,  0.330],  [0.640, 0.330],    [0.630,  0.340],  [0.630,  0.340],  [0.640,  0.330],  [0.708,  0.292],  [0.640,  0.330],  [0.73469,0.26531], [0.680,  0.320],  [0.680,  0.320],  [0.713,   0.293],  [0.7347,  0.2653])
    pg  = Select (mat_i,  [0.210,  0.710],  [0.300, 0.600],    [0.310,  0.595],  [0.310,  0.595],  [0.290,  0.600],  [0.170,  0.797],  [0.210,  0.710],  [0.11416,0.82621], [0.265,  0.690],  [0.265,  0.690],  [0.165,   0.830],  [0.0000,  1.0000])
    pb  = Select (mat_i,  [0.140,  0.080],  [0.150, 0.060],    [0.155,  0.070],  [0.155,  0.070],  [0.150,  0.060],  [0.131,  0.046],  [0.150,  0.060],  [0.15664,0.01770], [0.150,  0.060],  [0.150,  0.060],  [0.128,   0.044],  [0.0001, -0.0770])
    pw  = Select (mat_w,  [0.31006,0.31616],[0.312713, 0.329016],                                                                                        [0.34567,0.35850],                   [0.314,  0.351],  [0.32168,0.33767]                   , [0.33242, 0.34743],[0.29902, 0.31485],[0.281, 0.311],[0.3362,0.3502],[0.3134,0.3275])
    wp  = Select (mat_wp, [0.31006,0.31616],[0.312713, 0.329016],                                                                                        [0.34567,0.35850],                   [0.314,  0.351],  [0.32168,0.33767]                   , [0.33242, 0.34743],[0.29902, 0.31485],[0.281, 0.311],[0.3362,0.3502],[0.3134,0.3275])
    Kv  = Select (mat_wp,  6774.202        , 6504.13            ,                                                                                         5001.668        ,                    6304.573      ,   6000.211                           ,  5502.33          , 7506.16          , 8941.864     , 5347.894     ,  6477.94     )

    pr = [pr[0], pr[1], 1 - pr[0] - pr[1]]
    pb = [pb[0], pb[1], 1 - pb[0] - pb[1]]
    pg = [pg[0], pg[1], 1 - pg[0] - pg[1]]
    pw = [pw[0], pw[1], 1 - pw[0] - pw[1]]
    wp = [wp[0], wp[1], 1 - wp[0] - wp[1]]

    det = pw[1] * Dot([pr[0],pg[0],pb[0]], Cross([pr[1],pg[1],pb[1]], [pr[2],pg[2],pb[2]]))
    kr  = pr[1] * Dot(pw, Cross(pg, pb)) / det
    kb  = pb[1] * Dot(pw, Cross(pr, pg)) / det
    kg  = 1 - kb - kr

    [kr, kg, kb, wp[0], wp[1], wp[2]] }


# Should pass through Color_Fuzzy_search() for string normalizing
function moncurve_coef (string transfer) {

    t_num =
\     (transfer == "sRGB"         ) ? 0
\   : (transfer == "Display-P3"   ) ? 0
\   : (transfer == "170M"         ) ? 1
\   : (transfer == "Rec601"       ) ? 1
\   : (transfer == "Rec709-Camera") ? 1
\   : (transfer == "Rec2020NCL"   ) ? 1
\   : (transfer == "Rec2020CL"    ) ? 1
\   : (transfer == "Rec2020"      ) ? 1
\   : (transfer == "240M"         ) ? 2
\   : (transfer == "470BG"        ) ? 3
\   : (transfer == "Rec709"       ) ? 4
\   : (transfer == "1886"         ) ? 4
\   : (transfer == "AdobeRGB"     ) ? 5
\   : (transfer == "AWG"          ) ? 5
\   : (transfer == "DCIXYZ"       ) ? 6
\   : (transfer == "linear"       ) ? 7
\   : (transfer == "470M"         ) ? 8
\   : (transfer == "1886a"        ) ? 9
\   : (transfer == "xvYCC"        ) ? -1
\   : (transfer == "PQ"           ) ? -1
\   : (transfer == "HLG"          ) ? -1 : 4


       /* Coeff Derivations:
          BT.2020/SMPTE 170M "simultaneous equations" require brute force root-finding algos (ie. bisection method)
          Added only as reference here since moncurve_x() functions compute them correctly from "alpha" coeff.

        #   alpha = offset     (x coord - 1)
        #   beta  = transition (y coord)= K0/Phi
        #   phi   = slope
        #   k0    = beta * phi or alpha / (gam-1)
                                                                      #  SMPTE 240M
        #   BT.2020/SMPTE 170M                                        #  piece+slope match
        #   phi*y = a*b^igam-x+1                                      #  k0  = a / (gam-1)
        #   phi   = igam*a*b^(igam-1)                                 #  phi = (((1+a)^gam)*(gam-1)^(gam-1))/((a^(gam-1))*gam^gam)
            gamma = 1/0.45                                               gamma = 1/0.45 = 2.2222
            alpha = 0.099296826809442940347282759                        alpha = 0.1115
            beta  = 0.018053968510807807335869592                        beta  = 0.02280681818181818182
            k0    = 0.081242858298635133011413164                        k0    = 0.09122727272727272727
            phi   = 4.5                                                  phi   = 4.0

        #   sRGB                                                      #  sRGB
        #   piece+slope match                                         #  piece match
        #   k0  = a / (gam-1)                                         #  phi*b = a*b^igam-a+1
        #   phi = (((1+a)^gam)*(gam-1)^(gam-1))/((a^(gam-1))*gam^gam) #  phi   = igam*a*b^(igam-1)
            gamma = 2.40                                                 gamma = 2.40
            alpha = 0.055                                                alpha = 0.05501071894758659721
            beta  = 0.00303993463977843                                  beta  = 0.00304128256012752085
            k0    = 0.03928571428571428571                               k0    = 0.039293370676847569382
            phi   = 12.92321018078786109464                              phi   = 12.92
            */

    #                                                SMPTE-C    / BT-2020           Y’PbPr 601              PAL/SECAM                      Rec.709  AdobeRGB  DCI-P3      AP1/AP0   NTSC 1953/YCbCr Rec.709
    #                       sRGB                     SMPTE 170M / BT-2020           SMPTE 240M              BT-470BG (historical)          BT-1886  AdobeRGB  DCI-P3/XYZ  ACES/LIN  BT-470M/FCC     BT-1886a (more CRT alike)
    t_gamma = Select(t_num, 2.40                   , 1/0.45                       , 1/0.45                , 2.80                         , 2.40   , 563/256., 2.60       , 1.0      , 2.2          , 2.60   )
    t_alpha = Select(t_num, 0.055                  , 0.099296826809442940347282759, 0.1115                , 0.099296826809442940347282759, 0      , 0       , 0          , 0        , 0            , 0      )
    t_beta  = Select(t_num, 0.00303993463977843    , 0.018053968510807807335869592, 0.02280681818181818182, 0.00410749063249639977       , 0      , 0       , 0          , 0        , 0            , 0.35/pow(0.35, 3.0-2.6))
    t_k0    = Select(t_num, 0.03928571428571428571 , 0.081242858298635133011413164, 0.09122727272727272727, 0.05516490378302385575       , 0      , 0       , 0          , 0        , 0            , 0.35   )
    t_phi   = Select(t_num, 12.92321018078786109464, 4.5                          , 4.0                   , 13.43031761206876179575      , 4.5    , 0       , 0          , 0        , 0            ,      pow(0.35, 3.0-2.6) )

    [t_gamma, t_alpha] }



function RGB_to_XYZ (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    matrix =        cspace == "sRGB"   || cspace == "Rec709"                                             ?  \
                                        [ 0.41241079568862915, 0.21264933049678802, 0.01933175697922707,    \
                                          0.35758456587791443, 0.71516913175582890, 0.11919485777616501,    \
                                          0.18045382201671600, 0.07218152284622192, 0.95039016008377080]  : \
                    cspace == "Rec601" || cspace == "170M" || cspace == "240M"                           ?  \
                                        [ 0.39354196190834045, 0.21238772571086884, 0.0187400933355093,     \
                                          0.36525884270668030, 0.70106136798858640, 0.1119341626763344,     \
                                          0.19164848327636720, 0.08655092865228653, 0.9582424163818359]   : \
                    FindStr(cspace, "ec2")>0                                                             ?  \
                                        [ 0.63697350025177000, 0.24840137362480164, 0.00000000000000000,    \
                                          0.15294560790061950, 0.67799961566925050, 0.04253686964511871,    \
                                          0.11785808950662613, 0.03913172334432602, 1.06084382534027100]  : \
                    cspace == "DCI-P3"                                                                   ?  \
                                        [ 0.44516983628273010, 0.20949168503284454, 0.00000000000000000,    \
                                          0.27713435888290405, 0.72159516811370850, 0.04706055670976639,    \
                                          0.17228263616561890, 0.06891304999589920, 0.90735518932342530]  : \
                    cspace == "Display-P3"                                                               ?  \
                                        [ 0.48659050464630127, 0.22898375988006592, 0.00000000000000000,    \
                                          0.26566821336746216, 0.69173991680145260, 0.04511347413063049,    \
                                          0.19819043576717377, 0.07927616685628891, 1.04380297660827640]  : \
                    cspace == "AdobeRGB"                                                                 ?  \
                                        [ 0.57666999101638790, 0.29734000563621520, 0.02703000046312809,    \
                                          0.18556000292301178, 0.62735998630523680, 0.07068999856710434,    \
                                          0.18822999298572540, 0.07529000192880630, 0.99133998155593870]  : \
                    cspace == "AWG"                                                                      ?  \
                                        [ 0.71650063991546630, 0.258728206157684300, 0.00000000000000000,   \
                                          0.10102055221796036, 0.724682152271270800, 0.05121181160211563,   \
                                          0.14677436649799347, 0.016589440405368805, 0.77389270067214970]:  \
                    cspace == "ACEScg"  ||  cspace == "ACESCCt"                                          ?  \
                                        [ 0.66332850000000000, 0.27258800000000000, 0.00000000000000000,    \
                                          0.13399166000000000, 0.67401860000000000, 0.00406035300000000,    \
                                          0.15532595000000000, 0.05339329000000000, 1.00476470000000000]  : \
                    cspace == "ACES2065"                                                                 ?  \
                                        [ 0.95253682136535640000,  0.34396082162857056, 0.0000000000000000, \
                                          0.00000000000000000000,  0.74020814895629880, 0.0000000000000000, \
                                          0.00010931033466476947, -0.08416896313428879, 1.0088251829147339]:\
                    cspace == "470BG"                                                                    ?  \
                                        [ 0.43057379126548767, 0.22201462090015410, 0.02018314599990845,    \
                                          0.34154993295669556, 0.70665508508682250, 0.12955342233181000,    \
                                          0.17832535505294800, 0.07133013755083084, 0.93918019533157350]  : \
                    cspace == "OPP"                                                                      ?  \
                                        [ 0.93410000000000000, -1.70130000000000000, 0.16770000000000000,   \
                                          0.94500000000000000,  0.49860000000000000, 0.05220000000000000,   \
                                          0.81570000000000000,  0.30470000000000000, 1.94220000000000000] : \
                    Assert(false,"RGB_to_XYZ: Unsupported Color Space.")

    list ? matrix : MatrixClip(rgb, matrix) }



function XYZ_to_RGB (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    matrix =        cspace == "sRGB"   || cspace == "Rec709"                                                ?  \
                                        [  3.24081254005432130, -0.96924304962158200,  0.055638398975133896,   \
                                          -1.53730857372283940,  1.87596631050109860, -0.204007431864738460,   \
                                          -0.49858659505844116,  0.04155505076050758,  1.057129383087158200] : \
                    cspace == "Rec601" || cspace == "170M" || cspace == "240M"                              ?  \
                                        [  3.5058159828186035, -1.06904542446136470,  0.05631496384739876,     \
                                          -1.7396978139877320,  1.97777497768402100, -0.19700492918491364,     \
                                          -0.5440292358398438,  0.035171352326869965, 1.05010843276977540]   : \
                    FindStr(cspace, "ec2")>0                                                                ?  \
                                        [  1.71660947799682620, -0.66668272018432620,  0.017642205581068993,   \
                                          -0.35566213726997375,  1.61647748947143550, -0.042776308953762054,   \
                                          -0.25336012244224550,  0.01576850563287735,  0.942228555679321300] : \
                    cspace == "DCI-P3"                                                                      ?  \
                                        [  2.72539401054382320, -0.7951681613922119,  0.041241902858018875,    \
                                          -1.01800286769866940,  1.6897321939468384, -0.087639048695564270,    \
                                          -0.44016319513320923,  0.0226471945643425,  1.100929737091064500]  : \
                    cspace == "Display-P3"                                                                  ?  \
                                        [  2.49339652061462400, -0.82948720455169680,  0.035850685089826584,   \
                                          -0.93134605884552000,  1.76266026496887200, -0.076182708144187930,   \
                                          -0.40269458293914795,  0.02362464182078838,  0.957014024257659900] : \
                    cspace == "AdobeRGB"                                                                    ?  \
                                        [  2.04158997535705570, -0.96924000978469850,  0.013439999893307686,   \
                                          -0.56501001119613650,  1.87597000598907470, -0.118359997868537900,   \
                                          -0.34472998976707460,  0.04156000167131424,  1.015169978141784700] : \
                    cspace == "AWG"                                                                         ?  \
                                        [  1.46230435371398930, -0.52286839485168460,  0.034600451588630676,   \
                                          -0.18452566862106323,  1.44798874855041500, -0.095819652080535890,   \
                                          -0.27338108420372010,  0.06812617927789688,  1.287660717964172400] : \
                    cspace == "ACEScg"  ||  cspace == "ACESCCt"                                             ?  \
                                        [  1.64102330000000000, -0.66387850000000000,  0.002682799000000000,   \
                                          -0.32480330000000000,  1.61551320000000000, -0.006528448000000000,   \
                                          -0.23642470000000000,  0.01678004000000000,  0.995190000000000000] : \
                    cspace == "ACES2065"                                                                    ?  \
                                        [  1.04982817173004150000, -0.48783543705940247, 0.0000000000000000,   \
                                           0.00000000000000000000,  1.35097146034240720, 0.0000000000000000,   \
                                          -0.00011375317990314215,  0.11276797950267792, 0.9912520051002502] : \
                    cspace == "470BG"                                                                       ?  \
                                        [  3.0632193088531494, -0.96924340724945070,  0.06787130981683731,     \
                                          -1.3933255672454834,  1.87596678733825680, -0.22883385419845580,     \
                                          -0.4758017063140869,  0.04155505821108818,  1.06925129890441900]   : \
                    cspace == "OPP"                                                                         ?  \
                                        [  0.24300000000000000,  0.85600000000000000, -0.04400000000000000,    \
                                          -0.45740000000000000,  0.42790000000000000,  0.02800000000000000,    \
                                          -0.03030000000000000, -0.42660000000000000,  0.52900000000000000]  : \
                    Assert(false,"XYZ_to_RGB: Unsupported Color Space.")

    list ? matrix : MatrixClip(rgb, matrix) }



# Chromatic Adaptation types:
# Bianco 2010
# Bianco PC 2010
# Bradford
# CAT02
# CAT02 Brill 2008
# CMCCAT2000
# CMCCAT97
# Fairchild
# Sharp
# Spectral-sharpened Bradford
# Von Kries (Hunt-Pointer-Estevez adjusted for D65)
# Von Kries (Hunt-Pointer-Estevez for equal energy)
# XYZ Scaling
#
# von Kries Chromatic Adaptation
# source and/or target can be a Primaries Color Space (ie. sRGB) or an illuminant (ie: D65)
function c_adaptation (clip c, string "source", string "target", bool "tv_range", bool "list", bool "fulls") {

    rgb     = IsRGB(c)
    propIDs = color_propGet(c)

    src    = Default (source,   propIDs[3])
    tgt    = Default (target,        "D65")
    tv     = Default (tv_range, propIDs[6])
    list   = Default (list,          false)


    src    = list ? [src] : Color_Fuzzy_search (src)
    tgt    = list ? [tgt] : Color_Fuzzy_search (tgt)
    wps    = Matrix_coef(src[0])
    wpt    = Matrix_coef(tgt[0])
    same   = wps[3] == wpt[3]

    CAT02  = [0.7328,  0.4296, -0.1624, \
             -0.7036,  1.6975,  0.0061, \
              0.0030, -0.0136,  0.9834]

    wpsn   = MatrixDot([wps[3]/wps[4],1.,wps[5]/wps[4]], CAT02)
    wptn   = MatrixDot([wpt[3]/wpt[4],1.,wpt[5]/wpt[4]], CAT02)
    trans  = MatrixDiv(wptn,wpsn)
    vk     = [same?1.:trans[0],   0.0000,        0.0000,  \
              0.0000,   same?1.:trans[1],        0.0000,  \
              0.0000,            0.0000,same?1.:trans[2]]

    CAM    = !same ? MatrixDot(CAT02, MatrixDot(vk, MatrixInvert(CAT02))) : vk

    if (!list) {

        c
        s_gam  = moncurve_coef(src[0])

        RGBpln = rgb ? IsPlanar() : false

        rgb ? RGBpln ? last : ConvertToPlanarRGB() : \
        YUV_to_RGB(c, src[0], tv_range_in=tv, tv_range_out=false, kernel="Point")

        moncurve_f(s_gam[0], s_gam[1], false, false, 1)

        mata = RGB_to_XYZ (src[0], list=true)
        matb = XYZ_to_RGB (src[0], list=true)
        MatrixClip( MatrixDot(MatrixDot(mata, CAM), matb) )

        moncurve_r(s_gam[0], s_gam[1], false, false, 1)

        rgb ? RGBpln ? last : MatchClip(c) : \
        RGB_to_YUV( src[0], tv_range_in=false, tv_range_out=tv, kernel="Point", pixel_type=PixelType(c))
        same ? c : last

    } else { CAM } }




####### ARRAY FUNCTIONS #######

function ExtractClip ( clip clp) {

    isY  (clp) ? [         clp,          clp,          clp ] : \
    isRGB(clp) ? [ExtractR(clp),ExtractG(clp),ExtractB(clp)] : \
                 [ExtractY(clp),ExtractU(clp),ExtractV(clp)] }


function MatrixClip ( clip clp, float_array mat) {

    CLPa = ExtractClip(clp)

    # clip · 3x3
    Expr(CLPa[0], CLPa[1], CLPa[2], "x "+string(mat[0])+" * y "+string(mat[3])+" * + z "+string(mat[6])+" * +", \
                                    "x "+string(mat[1])+" * y "+string(mat[4])+" * + z "+string(mat[7])+" * +", \
                                    "x "+string(mat[2])+" * y "+string(mat[5])+" * + z "+string(mat[8])+" * +", optSingleMode=true, format=PixelType(clp)) }


function DotClip ( clip clp, float_array vec) {

    CLPa = ExtractClip(clp)

    # clip · 1x3
    Expr(CLPa[0], \
         CLPa[0], \
         CLPa[0], "x "+string(vec[0])+" * y "+string(vec[1])+" * + z "+string(vec[2])+" * +", optSingleMode=true) }


function DotClipA ( clip_array clp, float_array vec) {

    # clipA · 1x3
    Expr(clp[0], \
         clp[1], \
         clp[2], "x "+string(vec[0])+" * y "+string(vec[1])+" * + z "+string(vec[2])+" * +", optSingleMode=true) }


function MatrixDot ( float_array mat1, \
                     float_array mat2) {
    # 1x3 · 3x3
    if (ArraySize(mat1) == 3) {
        ar1 = Dot([mat1[0],mat1[1],mat1[2]],[mat2[0],mat2[1],mat2[2]])
        ar2 = Dot([mat1[0],mat1[1],mat1[2]],[mat2[3],mat2[4],mat2[5]])
        ar3 = Dot([mat1[0],mat1[1],mat1[2]],[mat2[6],mat2[7],mat2[8]])

       [ar1,ar2,ar3]
    }
    # 3x3 · 3x3
    else if (ArraySize(mat1) == 9) {
        ar1 = Dot([mat1[0],mat1[1],mat1[2]],[mat2[0],mat2[3],mat2[6]])
        ar2 = Dot([mat1[0],mat1[1],mat1[2]],[mat2[1],mat2[4],mat2[7]])
        ar3 = Dot([mat1[0],mat1[1],mat1[2]],[mat2[2],mat2[5],mat2[8]])
        ar4 = Dot([mat1[3],mat1[4],mat1[5]],[mat2[0],mat2[3],mat2[6]])
        ar5 = Dot([mat1[3],mat1[4],mat1[5]],[mat2[1],mat2[4],mat2[7]])
        ar6 = Dot([mat1[3],mat1[4],mat1[5]],[mat2[2],mat2[5],mat2[8]])
        ar7 = Dot([mat1[6],mat1[7],mat1[8]],[mat2[0],mat2[3],mat2[6]])
        ar8 = Dot([mat1[6],mat1[7],mat1[8]],[mat2[1],mat2[4],mat2[7]])
        ar9 = Dot([mat1[6],mat1[7],mat1[8]],[mat2[2],mat2[5],mat2[8]])

       [ar1,ar2,ar3,ar4,ar5,ar6,ar7,ar8,ar9]  }  }


function MatrixInvert (float_array mat) {

    Det = (mat[0]*((mat[8]*mat[4])-(mat[7]*mat[5]))) - \
          (mat[3]*((mat[8]*mat[1])-(mat[7]*mat[2]))) + \
          (mat[6]*((mat[5]*mat[1])-(mat[4]*mat[2])))

           ar1 =  ((mat[8]*mat[4])-(mat[7]*mat[5]))/Det
           ar2 = -((mat[8]*mat[1])-(mat[7]*mat[2]))/Det
           ar3 =  ((mat[5]*mat[1])-(mat[4]*mat[2]))/Det
           ar4 = -((mat[8]*mat[3])-(mat[6]*mat[5]))/Det
           ar5 =  ((mat[8]*mat[0])-(mat[6]*mat[2]))/Det
           ar6 = -((mat[5]*mat[0])-(mat[3]*mat[2]))/Det
           ar7 =  ((mat[7]*mat[3])-(mat[6]*mat[4]))/Det
           ar8 = -((mat[7]*mat[0])-(mat[6]*mat[1]))/Det
           ar9 =  ((mat[4]*mat[0])-(mat[3]*mat[1]))/Det

           [ar1,ar2,ar3,ar4,ar5,ar6,ar7,ar8,ar9] }


function MatrixTranspose (float_array mat) {

  [mat[0],mat[3],mat[6],\
   mat[1],mat[4],mat[7],\
   mat[2],mat[5],mat[8]] }


function Cross (float_array vec1, \
                float_array vec2) {
    # 1x3 X 1x3
    cr1 = vec1[1] * vec2[2] - vec1[2] * vec2[1]
    cr2 = vec1[2] * vec2[0] - vec1[0] * vec2[2]
    cr3 = vec1[0] * vec2[1] - vec1[1] * vec2[0]

    [cr1, cr2, cr3] }


function Dot (float_array vec1, \
              float_array vec2) {
    # 1x3 · 1x3
    (vec1[0] * vec2[0]) + (vec1[1] * vec2[1]) + (vec1[2] * vec2[2]) }


function MatrixDiv ( float_array mat1, \
                     float_array mat2) {

    asize = ArraySize(mat1)
    str = ""
    for (i=0, asize, 1) {
        cm  = asize == i+1 ? "" : ","
        str = str + string(mat1[i] / mat2[i]) + cm
        i   = asize == i+1 ? asize : i
       }

    return Eval("["+str+"]") }


function MatrixMul ( float_array mat1, \
                     float_array mat2) {

    asize = ArraySize(mat1)
    str = ""
    for (i=0, asize, 1) {
        cm  = asize == i+1 ? "" : ","
        str = str + string(mat1[i] * mat2[i]) + cm
        i   = asize == i+1 ? asize : i
       }

    return Eval("["+str+"]") }


/*
# (LEGACY: since v3.7.1 test29)
function ArrayAdd( val_array "a", val_array "b") {

    as = ArraySize(a)-1
    bs = ArraySize(b)-1
    na = ""
    for (i = 0, as+bs+1, 1) {

        o  = i  - as  - 1
        cm = i != as+bs+1 ? "," : ""
        na = na + ( i > as ? String(Eval(Format("b[{o}]"))) : \
                             String(Eval(Format("a[{i}]")))) + cm
      }

    return Eval("["+na+"]") }
*/