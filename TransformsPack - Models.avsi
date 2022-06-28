###########################################################
###                                                      ##
###                                                      ##
###   Transforms Pack - Models v1.0 RC53  (27-06-2022)   ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182825    ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
### MODELS:                                              ##
###     RGB_to_YUV      / YUV_to_RGB                     ##
###     RGB_to_YcCbcCrc / YcCbcCrc_to_RGB                ##
###     RGB_to_YCoCg    / YCoCg_to_RGB                   ##
###     RGB_to_YCoCgR   / YCoCgR_to_RGB                  ##
###     RGB_to_YUVr     / YUVr_to_RGB                    ##
###     RGB_to_OPP      / OPP_to_RGB                     ##
###     XYZ_to_Yxy      / Yxy_to_XYZ                     ##
###     XYZ_to_YDzDx    / YDzDx_to_XYZ                   ##
###     XYZ_to_Lab      / Lab_to_XYZ                     ##
###     XYZ_to_Luv      / Luv_to_XYZ                     ##
###     XYZ_to_XYB      / XYB_to_XYZ                     ##
###     RGB_to_HSV      / HSV_to_RGB                     ##
###     RGB_to_IPT      / IPT_to_RGB                     ##
###     RGB_to_Oklab    / Oklab_to_RGB                   ##
###     RGB_to_XYZ      / XYZ_to_RGB                     ##
###     RGB_to_ICtCp    / ICtCp_to_RGB                   ##
###     XYZ_to_LMS      / LMS_to_XYZ                     ##
###     CAT                                              ##
###     CMF                                              ##
###                                                      ##
###########################################################



##########################################
###                                     ##
###     MODEL CONVERSION FUNCTIONS      ##
###                                     ##
##########################################


# List of Color Spaces:
#
# Color Spaces define the size and shape of our source color gamut container in the unitary XYZ coordinates cube. In other words, a color space conversion doesn't change the size (saturation), quantity (interpolation in HBD) or shape (gamut mapping) of our fruits (gamut), but the basket that holds them.
# Color Spaces are presented normally as a 3x3 matrix of their color primaries represented in the CIE 1931 diagram coordinates. This might be ok but be aware this is an over-simplification as color spaces are actually 3D volumes within the unitary XYZ cube, and part of them may actually fall outside the CIE 1931 color space which represents all the physically plausible colors.
#
# There are several types of Color Spaces defined by their role:
# Characterization spaces are normally used to represent device gamuts for profiling on a unit-by-unit basis.
# Standard spaces define a standard to comply with for delivery, normally they are derived from averaging measurements of real unit-by-unit devices defined by their used phosphors.
# Finally working spaces don't need to be attached to any physical constraints so they can be as big as the CIE 1931 color space (some actually bigger than that), so they are suited for heavy color transformations without much degradation in the process. They can also be geared towards certain effects like getting more color resolution in certain HUES for exposing better shades in color grading tasks. Ultimately everything is being transformed into your display color space in real time so use any working space that suits your job.
#
#-470M                   - ITU-R Rec. BT.470 M. Also known as FCC or NTSC (1953)
#-170M                   - ITU-R Rec. BT.601 (525-line = NTSC, SMPTE-C)
#-240M                   -
#-470BG                  - ITU-R Rec. BT.601 (625-line = PAL, SECAM)
#-NTSC-J
#-sRGB                   - Jointly developed by Microsoft and Hewlett-Packard as a color standard designed primarily for office, home and web users.
#-2020
#-AdobeRGB
#-Adobe Wide Gamut
#-DCI-P3                 - Digital Cinema
#-Display-P3
#-AP0
#-AP1
# S-Gamut
# S-Gamut3
# S-Gamut3 (Venice)
# S-Gamut3.Cine          - Sony Gamut Cinema. A little over DCI-P3 gamut in size, paired with S-Log3 it reproduces a scanned negative film.
# S-Gamut3.Cine (Venice)
# CinemaDay              - Canon Cinema Gamut Daylight (5500K)
# CinemaTungsten         - Canon Cinema Gamut Tungsten (3200K)
# CanonP3                - Canon DCI-P3+
# D-Gamut                - DJI D-Gamut
# D-GamutM               - DJI D-GamutM
# DragonColor
# DragonColor2
# REDColor
# REDColor2
# REDColor3
# REDColor4
# REDWide                - RED Wide Gamut RGB
# Protune                - GoPro Protune Native
# Bolex                  - Bolex Wide Gamut RGB
# DaVinci Wide Gamut
# Almira709
# LC709
# LC709A
# s709
# Cine709                - Sony Cine+709
# ADX10
# ADX16
# BlackMagic Design Wide Gamut
# BlackMagic Design Film           (Legacy)
# BlackMagic Design Broadcast Video(Legacy)
# BlackMagic Design Broadcast Film (Legacy)
# BlackMagic Design 4K Film        (Legacy)
# BlackMagic Design 4K Film V3     (Legacy)
# BlackMagic Design 4K Video V3    (Legacy)
# BlackMagic Design 4.6K Film      (Legacy)
# BlackMagic Design 4.6K Film v3   (Legacy)
# BlackMagic Design 4.6K Video     (Legacy)
# BlackMagic Design 4.6K Video v3  (Legacy)
# BlackMagic Pocket 6k Film
# Alexa                  - Arri Alexa Wide Gamut
# Film                   - Arri Film Matrix. Traditional film primaries with Illuminant C
# FS                     - SMPTE Free Scale Gamut for imagery having arbitrary chromaticity that can be conveyed, inherited from Sony's F23, F35, and F65 Wide Gamut cameras. (ST 2048-1)
# V-Gamut                - Panasonic V-Gamut (Varicam)
# V709                   - Panasonic Varicam V709
# F-Log                  - Fujifilm F-Log Gamut
# Barco Unisee
# ProPhoto RGB           - RIMM ROMM RGB
# Wide Gamut RGB
# CIE RGB                - or CIE 1931 RGB
# Apple RGB
# ColorMatch RGB         - Radius PressView Monitors
# EBU 3213               - EBU Tech. 3213-E / JEDEC P22 phosphors
# Beta RGB               - by Bruce Lindbloom, an optimized capture, archiving and editing space for high-end digital imaging applications
# Bruce RGB              - Developed by Bruce Fraser as a conservative-gamut space for dealing with 8-bit imagery that needs heavy editing.
# BestRGB                - Developed by Don Hutcheson
# DonRGB4                - Developed by Don Hutcheson
# ECI-RGB                - Developed by the European Color Initiative <www.eci.org>
# Ekta Space PS5         - Developed by Joseph Holmes for high quality storage of image data from scans of transparencies.
# And many more oldies not included here for simplicity: P22 (Measured SMPTE-C), EBU measured, Conrac 7211N19, Hitachi, Barco, Tektronics, SGI Trinitron, Sony Trinitron KV-20M20

# List of Color Models:
# Color Models -not to be confused with Color Spaces- describe the geometry coordinates of the color gamut container and hence its relation (or correlation) with the other channels. They are typically designed or tailored to certain Color Spaces, but not necesarily bound to them like RGB or YCbCr which support many different Color Spaces and thus are nicked Color Absolute Models
#
# UCS: Uniform Color Space. Space in which equal distances on the coordinate diagram correspond to equal perceived color differences.
# With *: Color Appearance Models (CAM) (Perceptually Uniform -UCS- to various degrees)
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
#-XYZ          - CIE 1931 XYZ tristimulus color model representing all the non-imaginary colors.
# LSY          - Reads lambda-SY. Spectral color space. Representation based on brightness, dominant wavelength and saturation attributes. LSY color coordinates are defined from xyY color coordinates.
#-YDzDx+       - HDR version of XYZ. Requires at least 10-bit for no visible quantization.
# YCxCz        - Color Space for image fidelity metrics. It's a first step space, you have to "filter" it and then convert to Lab to retrieve error delta.
# DCI XYZ      - XYZ space in DCI illuminant. In effect it's just a container for DCI-P3 in XYZ coordinates for delivery to theaters.
#-Yxy/xyY      - Chroma normalized XYZ space which gives full luma/chroma decorrelation. Not apt for HDR, use YDzDx+ instead.
#-HSV          - Cylindrical representation of RGB. Not recommended as it doesn't take into account human luminance perception
#-Duv*         -
# HunterLab*   - A more perceptually uniform version of CIELab
#-CIELab*      - Derived from CIEXYZ, one of the first approaches to a perceptually uniform color model. CIELch(ab) is its cylindrical (polar coordinates) version. You can derive it's Delta E with the next equation: DE = (DL^2 + Da^2 + Db^2)/2  = ( (Ly-Lx)^2 + (ay-ax)^2 + (by-bx)^2)/2
# CIEsLab*     - CIE simple Lab
# R-Lab*       - Ruderman Lab space, using log luma and different weights for ab
# L-Lab*       -
# SRLab2*      - A 2009 modification of CIELAB in the spirit of RLAB (with discounting-the-illuminant). Uses CIECAM02 chromatic adaptation matrix to fix the blue hue issue.
#-CIELuv*      - Derived from CIE UVW, a competing perceptually uniform color model of CIELab around the same time the latter appeared. CIELuv uses a Judd-type CAT, while CIELab uses "wrong" von-Kries (XYZ Scaling).
#   CIELch(uv)*- HCL (polar coordinates or cylindrical) version of CIELuv
#   HSLuv*     - A cylindrical HSL type adaptation of CIELuv. It extends CIELuv with a new saturation component that allows you to span all the available chroma as a neat percentage.
# LogLuv*+     - HDR version of CIEluv, that uses log to encode HDR values in a 15-bit container
# Y''U''V''*+  - HDR version of CIEluv by Poynton. Improves on LogLuv by using a PQ transfer which just needs 12-bits
# CIEDuDv*+    - or YDuDv. HDR version of CIE Luv. Requires only 8-bit for no visible quantization.
# CIECAM97s*   -
#-XYB*         - Uniform (UCS) space used in Guetzli's butteraugli metric and JPEG XL, with a main goal in compression. Better uniformity than CIE Lab.
# DIN99o*      -
# JzAzBz*+     - A 2017 uniform (UCS) space designed for HDR color. Has J (lightness) and two chromaticities. JzCzhz is the HCL (polar coordinates or cylindrical) version of JzAzBz
#-IPT*         - Intensity Protanope Tritanope. A more uniform color space in SDR colors. There's a version called hdrIPT
# ICaCb+       - Precursor and arguably better color model than ICtCp which based on this
#-ICtCp+       - BT.2100 (HDR + Rec.2020) version of IPT. HDR version of YcCbcCrc but with Constant Intensity this time.
# ITP*+        - Perceptually uniform color space version of ICtCp, used extensively in error metrics by scaling Ct by 0.5. This transformation is the basis of the Rec.2124 wide gamut color difference metric D.itp (simple scaled Euclidean distance: 720*sqrt(Di^2+D(t*0.5)^2+Dp^2) )
# IPTPQc2*+    - Improved HDR10 version of ICtCp. Since it's a propietary model not much information is known.
# CIECAM02*    - Improves on CIECAM97s and can be made uniform with CAM02-UCS. CIECAM02Jch is its cylindrical version.
# OSA*         -
# CIECAM16*    - Improves on CIECAM02 and can be made uniform with CAM16-UCS, which works "out-of-the-box" for Euclidean distance metrics.
# ZCAM*+       - A uniform (UCS) space for HDR color.
#-Oklab*       - A uniform (UCS) space for SDR color. Simple to compute yet powerful. Takes CAM16 lightness and chroma, and IPT for hue. OkLch is the cylindrical form of Oklab.
# iCAM06       - An image (not only color) appearance metric model to not only compute perceived difference in lightness, hue or chroma, but also contrast, sharpness or graininess. Involves converting to IPT, low-pass filtering in linear space, convert to non-linearity, then to Jch model and QM if necessary for the metrics.


# YCbCr to RGB' standalone function (recommended at least 10-bit precision)
function YUV_to_RGB (clip yuv, string "matrix", bool "tv_range_in", bool "tv_range_out", string "kernel", float "b", float "c", float "p", string "cplace", bool "UVrecon") {

    matrix     = Default (matrix, "709")
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, !(matrix=="JPEG" || matrix=="JPG"))
    tv_out     = Default (tv_range_out, false)
    cplace     = Default (cplace, "")
    recon      = Default (UVrecon, false)
    b          = Default (b, 0.0)
    c          = Default (c, 0.75)               # Precise Bicubic
    p          = Default (p,    9)

    Assert(IsVersionOrGreater(3,7,2), "YUV_to_RGB: Update AviSynth+ version")
    Assert(!isRGB(yuv),               "YUV_to_RGB: Only YUV format supported")

    bi       = BitsPerComponent(yuv)
    lut      = bi > 12 || isRunTime(yuv,false) ? 0 : 2
    p_type   = format_Fuzzy_Search(yuv, PixelType(yuv), bi)
    matrix   = color_Fuzzy_Search (matrix)
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

    cplace  = chroma_placement(w, h, nw, nh, matrix[0], matrix[0], "YUV"+p_type[1], "RGB", p_type[1], "444", cplace, "center" )

     p_type1             ? Assert(bi == 8,    "YUV_to_RGB: Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10,  "YUV_to_RGB: Unsupported Pixel Type: YUV410")


    cplaceH = ",src_left="+string(cplace[0])
    cplaceV = ",src_top ="+string(cplace[1])

    resampler = kernel == "nnedi3" ?     "deep_resize(" + String(w) + "," + String(h)                     + ")"                       : \
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
        Luma    = ref.ConvertBits(8,dither=-1,fulls=!tv_in).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2,range=fs?1:2, cshift="spline16resize").ConvertBits(bi,fulls=!tv_in)
        Uu      = Uor.ConvertBits(8,dither=-1,fulls=!tv_in).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=6, cshift="blackmanresize", mpeg2=false,range=fs?1:2).ConvertBits(bi,fulls=!tv_in)
        Vu      = Vor.ConvertBits(8,dither=-1,fulls=!tv_in).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=6, cshift="blackmanresize", mpeg2=false,range=fs?1:2).ConvertBits(bi,fulls=!tv_in)
        Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=0.0, c=0.5)
        Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=0.0, c=0.5)
        U       = ex_LFR(Unew, Uu.BicubicResize(w, h, b=0.0, c=0.5), LFR=w/1.1)
        V       = ex_LFR(Vnew, Vu.BicubicResize(w, h, b=0.0, c=0.5), LFR=w/1.1)

    } else {

        U   = p_type4 ? Uor : Eval("Uor." + resampler)
        V   = p_type4 ? Vor : Eval("Vor." + resampler)

        }


    if (matrix[0]=="2020CL" || matrix[0]=="DCI-P3" || matrix[0]=="Display-P3") {

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



# RGB' to YCbCr standalone function (recommended at least 10-bit precision)
function RGB_to_YUV (clip rgb, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", float "b", float "c", float "p", string "cplace") {

    matrix     = Default (matrix, "sRGB")
    p_type     = Default (pixel_type, "420")     # target YUV pixel_type
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, false)
    tv_out     = Default (tv_range_out, true)
    cplace     = Default (cplace, "")
    b          = Default (b, -0.5)
    c          = Default (c, 0.25)               # Didée's Bicubic
    p          = Default (p,    9)

    Assert(IsVersionOrGreater(3,7,2),   "RGB_to_YUV: Update AviSynth+ version")
    Assert(isRGB(rgb) && IsPlanar(rgb), "RGB_to_YUV: Only Planar RGB format supported")

    bi       = BitsPerComponent(rgb)
    p_type   = format_Fuzzy_Search (rgb, p_type, bi)
    matrix   = color_Fuzzy_Search (matrix)
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

    cplace  = chroma_placement(w, h, nw, nh, matrix[0], matrix[0], "RGB", "YUV"+p_type[1], "444", p_type[1], "center", cplace )

     p_type1             ? Assert(bi == 8,    "RGB_to_YUV: Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10,  "RGB_to_YUV: Unsupported Pixel Type: YUV410")

                           Assert(h%2==0,     "RGB_to_YUV: Height is not mod2" )
    !p_type1 || !p_type4 ? Assert(w%2==0,     "RGB_to_YUV: Width is not mod2" )                 : nop()
     p_type1             ? Assert(w%4==0,     "RGB_to_YUV: Width is not mod4" )                 : nop()


    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)


    if (matrix[0]=="2020CL" || matrix[0]=="DCI-P3" || matrix[0]=="Display-P3") {

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

    cplaceH = ",src_left="+string(cplace[0])
    cplaceV = ",src_top ="+string(cplace[1])

    # Although not optimal, technically YUV420 accepts odd size chroma planes
    resampler = kernel == "nnedi3" ?     "deep_resize(" + String(nw) + "," + String(nh)                     + ")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(nw) + "," + String(nh) + cplaceH + cplaceV + ",b="+bc_b+",c="+bc_c+")" : \
                kernel == "gauss"  ?     "GaussResize(" + String(nw) + "," + String(nh) + cplaceH + cplaceV + ",p=p)"     : \
                                     kernel + "Resize(" + String(nw) + "," + String(nh) + cplaceH + cplaceV + ")"

    Cb = p_type4 ? Cb : Eval("Cb." + resampler)
    Cr = p_type4 ? Cr : Eval("Cr." + resampler)

    CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+p_type[1]+p_type[2]) }


# RGB' to YcCbcCrc function (for Rec.2020CL)
function RGB_to_YcCbcCrc (clip RGB, clip "Gx", clip "Bx", string "matrix", float_array "coef", bool "tv_in", bool "tv_out") {

    isy  = isy(RGB)
    bi   = BitsPerComponent(RGB)
    lut  = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
    mat  = Default (matrix, "709")
    coef = Default (coef, Matrix_coef(mat))
    tvi  = Default (tv_in,  false)
    tvo  = Default (tv_out, false)

    mat       = color_Fuzzy_Search(mat)
    s_gam     = moncurve_coef(mat[2]) # some values are getting crushed in the Rec709 transfer
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
    !isy && mat[0] == "2020CL" ? propSet("_Matrix", 10) : last }


# WIP. YcCbcCrc to RGB' function (for Rec.2020CL)
function YcCbcCrc_to_RGB (clip YUV, clip "Cb", clip "Cr", string "matrix", float_array "coef", bool "tv_in", bool "tv_out") {

    isy  = isy(YUV)
    bi   = BitsPerComponent(YUV)
    lut  = bi > 12 || isRunTime(YUV,false) ? 0 : 2
    mat  = Default (matrix, "709")
    coef = Default (coef, Matrix_coef(mat))
    tvi  = Default (tv_in,  false)
    tvo  = Default (tv_out, false)

    mat  = color_Fuzzy_Search(mat)
    clp  = !isy ? ExtractClip(YUV) : nop()
    Y    = !isy ? clp[0] :    YUV
    Cb   = !isy ? clp[1] :     Cb
    Cr   = !isy ? clp[2] :      Cr

    bi32m     = bi == 32 ? "" : "range_half -"
    bi32p     = bi == 32 ? "" : "range_half +"
    rangeC_PC = tvi ? ""+bi32m+" range_max cmax cmin - / *" : bi32m

    s_gam = moncurve_coef(mat[2])
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

# RGB' to YCoCg function
function RGB_to_YCoCg (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
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

        fmt = format_Fuzzy_Search(RGB, "YUV", bi)
        Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ",     bi, !tvi),  \
                      ex_dlut("y 0.5  * x z + 0.25 * - "+b32, bi, !tvi),  \
                      ex_dlut("x z - 0.5  *            "+b32, bi, !tvi), format="YUV444"+fmt[2], optSingleMode=true) } }


# YCoCg to RGB' function
function YCoCg_to_RGB (clip YCC, clip "Cg", clip "Co", bool "tv_in", bool "tv_out") {

    isy = isy(YCC)
    bi  = BitsPerComponent(YCC)
    lut = bi > 12 || isRunTime(YCC,false) ? 0 : 2
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

        fmt = format_Fuzzy_Search(YCC, "RGB", bi)
        Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" + ", bi, !tvi),  \
                        ex_dlut("x y "+b32+" +",              bi, !tvi),  \
                        ex_dlut("x y "+b32+" - z "+b32+" - ", bi, !tvi), format="RGB"+fmt[2], optSingleMode=true) } }


# RGB' to YCoCg RCT function
function RGB_to_YCoCgR (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
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


#  YCoCg RCT to RGB' function
function YCoCgR_to_RGB (clip YCC, clip "Cg", clip "Co", bool "tv_in", bool "tv_out") {

    isy = isy(YCC)
    bi  = BitsPerComponent(YCC)
    lut = bi > 12 || isRunTime(YCC,false) ? 0 : 2
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

        fmt = format_Fuzzy_Search(YCC, "RGB", bi)
        Expr(Y, Cg, Co, ex_dlut("z   "+b32+" dup 0.5 * x y "+b32+" - swap - swap 2 * +", bi, !tvi),  \
                        ex_dlut("y   "+b32+" Y@ 2 * x Y - +",                            bi, !tvi),  \
                        ex_dlut("x y "+b32+" - z "+b32+" 0.5 * -",                       bi, !tvi), format="RGB"+fmt[2], optSingleMode=true) } }


# RGB' to YCbCr RCT function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
function RGB_to_YUVr (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
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

        fmt = format_Fuzzy_Search(RGB, "YUV", bi)
        Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ", bi, !tvi),  \
                      ex_dlut("z y - "+b32,               bi, !tvi),  \
                      ex_dlut("x y - "+b32,               bi, !tvi), format="YUV444"+fmt[2], optSingleMode=true) } }


# YCbCr RCT to RGB' function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
function YUVr_to_RGB (clip YUV, clip "Cb", clip "Cr", bool "tv_in", bool "tv_out") {

    isy = isy(YUV)
    bi  = BitsPerComponent(YUV)
    lut = bi > 12 || isRunTime(YUV,false) ? 0 : 2
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

        fmt = format_Fuzzy_Search(YUV, "RGB", bi)
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
#   [1/sqrt(6),  1/sqrt(6), -2/sqrt(6)],\  *  RGB'
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
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
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

    } else { Expr(R, G, B, Os, P1s, P2s, format="YUV444"+format_Fuzzy_Search(RGB,"YUV",bi)[2], optSingleMode=true) } }


# https://github.com/HomeOfVapourSynthEvolution/VapourSynth-BM3D/blob/7b3d8dd32e4aa4d962cf15d75d191b465682ed42/include/Specification.h#L176
function OPP_to_RGB (clip OPP, clip "P1", clip "P2", bool "fulls") {

    isy = isy(OPP)
    bi  = BitsPerComponent(OPP)
    lut = bi > 12 || isRunTime(OPP,false) ? 0 : 2
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

    } else { Expr(O, P1, P2, Rs, Gs, Bs, format="RGB"+format_Fuzzy_Search(OPP,"RGB",bi)[2], optSingleMode=true) } }


# XYZ to YDzDx (applied on XYZ in SMPTE ST 2084 gamma space)
function XYZ_to_YDzDx (clip XYZ, clip "Y", clip "Z", bool "tv_in", bool "tv_out") {

    isy = isy(XYZ)
    bi  = BitsPerComponent(XYZ)
    lut = bi > 12 || isRunTime(XYZ,!isy) ? 0 : 2
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
    lut = bi > 12 || isRunTime(YDzDx,!isy) ? 0 : 2
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


# XYZ to CIE Lab -D65 based- (process in linear space) (float bitdepth required as some values overflow)
# CIELAB is perceptually uniform but only at low frequencies as it is based on 2 degrees of uniform color circles.
function XYZ_to_Lab (clip XYZ, clip "Y", clip "Z", bool "Jch", bool "fulls") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    iRT  = isRunTime(XYZ,!isy)
    lut1 = bi == 32 || iRT ? 0 : 1
    lut2 = bi  > 12 || iRT ? 0 : 2
    cy   = Default (Jch,   false)
    fs   = Default (fulls,  true)

    clp  = !isy ? ExtractClip(XYZ) : nop()
    X    = !isy ? clp[0] :    XYZ
    Y    = !isy ? clp[1] :     Y
    Z    = !isy ? clp[2] :      Z

    ep    = pow(6. / 29,  3)                        # 0.00885645167903563081717167575546 (or 216 / 24389.)
    coef  = pow(6. / 29,  2) *    3                 # 0.12841854934601664684898929845422 (or 108 / 841)
    coefr = pow(6. / 29, -2) * (1/3.)               # 7.78703703703703703703703703703703 (or 841 / 108)  reciprocal of above
    rW    = [1.052134065421009,1,0.918343935177561] # Reference White (Tristimulus Values): Normalization to Y=100 of reciprocal of illuminant -D65- (and divided by 100)

    L = Expr(Y,               Format("x                        {ep} > x 0.333333333 ^ x {coefr} * 4 29 / + ? 1.16 * 0.16 -"), optSingleMode=false, lut=lut1)
    a = Expr(X, Y,    ex_dlut(Format("x "+string(rW[0])+" * X@ {ep} > X 0.333333333 ^ X {coefr} * 4 29 / + ?
                                      y                        {ep} > y 0.333333333 ^ y {coefr} * 4 29 / + ? - 5 * "), bi, fs),   optSingleMode=true,  lut=lut2)
    b = Expr(   Y, Z, ex_dlut(Format("x                        {ep} > x 0.333333333 ^ x {coefr} * 4 29 / + ?
                                      y "+string(rW[2])+" * Z@ {ep} > Z 0.333333333 ^ Z {coefr} * 4 29 / + ? - 2 * "), bi, fs),   optSingleMode=true,  lut=lut2)


    isy ? [L, a, b] : CombinePlanes(L, a, b, planes="RGB") }


# CIE Lab to XYZ -D65 based- (float bitdepth required as some values overflow)
function Lab_to_XYZ (clip Lab, clip "a", clip "b", bool "Jch", bool "fulls") {

    isy  = isy(Lab)
    bi   = BitsPerComponent(Lab)
    iRT  = isRunTime(Lab,!isy)
    lut1 = bi == 32 || iRT ? 0 : 1
    lut2 = bi  > 12 || iRT ? 0 : 2
    cy   = Default (Jch,    false)
    fs   = Default (fulls,   true)

    clp  = !isy ? ExtractClip(Lab) : nop()
    L    = !isy ? clp[0] :    Lab
    a    = !isy ? clp[1] :     a
    b    = !isy ? clp[2] :      b

    ep    =     6  / 29.                            # 0.20689655172413793103448275862069
    ep2   = pow(6  / 29., 3)                        # 0.00885645167903563081717167575546 (or 216 / 24389.)
    coef  = pow(6  / 29., 2) * 3                    # 0.12841854934601664684898929845422 (or 108 / 841)
    kappa = 24389 / 27.                             # 903.296296296296296296296296296296
    rW    = [0.950449218275099,1,1.088916648430471] # Reference White (Tristimulus Values): Normalization to Y=100 of illuminant (and divided by 100)

#    # De facto formula, for reference
#    Y = Expr( L,    Format("x 100 * 16 + 116 / Y@                 {ep} > Y 3 ^ Y 16 116 / - {coef} * ?                    "))
#    X = Expr( L, a, Format("x 100 * 16 + 116 / y 100 * 500 / + X@ {ep} > X 3 ^ X 16 116 / - {coef} * ? "+string(rW[0])+" *"))
#    Z = Expr( L, b, Format("x 100 * 16 + 116 / y 100 * 200 / - Z@ {ep} > Z 3 ^ Z 16 116 / - {coef} * ? "+string(rW[2])+" *"))

    Y = Expr( L,    Format("x 0.16 + 0.8620689656 *           Y@ {ep} > Y 3 ^ Y 4 29 / - {coef} * ?                    "), optSingleMode=false, lut=lut1)
    X = Expr( L, a, Format("x 0.16 + 0.8620689656 * y 0.2 * + X@ {ep} > X 3 ^ X 4 29 / - {coef} * ? "+string(rW[0])+" *"), optSingleMode=false, lut=lut2)
    Z = Expr( L, b, Format("x 0.16 + 0.8620689656 * y 0.5 * - Z@ {ep} > Z 3 ^ Z 4 29 / - {coef} * ? "+string(rW[2])+" *"), optSingleMode=false, lut=lut2)

    isy ? [X, Y, Z] : CombinePlanes(X, Y, Z, planes="RGB") }



# Only works in 32-bit float (for the time being)
function XYZ_to_Yxy (clip XYZ, clip "Y", clip "Z", bool "fulls") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    fs   = Default (fulls,  true)

    clp  = !isy ? ExtractClip(XYZ) : nop()
    X    = !isy ? clp[0] :    XYZ
    Y    = !isy ? clp[1] :     Y
    Z    = !isy ? clp[2] :      Z


    if (isy) {

        xl = Expr(X, Y, Z, "x dup y z + + /",  optSingleMode=false)
        yl = Expr(X, Y, Z, "y dup x z + + /",  optSingleMode=false)
        [Y, xl, yl]

    } else {

        Expr(X, Y, Z, "y", "x dup y z + + /",\
                           "y dup x z + + /",  optSingleMode=true, format=PixelType(XYZ)) } }


# Only works in 32-bit float
function Yxy_to_XYZ (clip Yxy, clip "x", clip "y", bool "fulls") {

    isy  = isy(Yxy)
    bi   = BitsPerComponent(Yxy)
    fs   = Default (fulls,  true)

    clp  = !isy ? ExtractClip(Yxy) : nop()
    Yb   = !isy ? clp[0] :    Yxy
    xl   = !isy ? clp[1] :     x
    yl   = !isy ? clp[2] :      y

    if (isy) {

        X = Expr(Yb, xl, yl, "y z / x *",                optSingleMode=false)
        Z = Expr(Yb, xl, yl, "y z / x * Y@ y / Y - x -", optSingleMode=false)
        [X, Yb, Z]

    } else {

        Expr(Yb, xl, yl, "y z / x *                ",\
                         "      x                  ",\
                         "y z / x * Y@ y / Y - x - ",    optSingleMode=true, format=PixelType(Yxy)) } }



# WIP. XYZ to Hunter Lab
function XYZ_to_HLab (clip XYZ, clip "Y", clip "Z", bool "Jch", bool "fulls") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    iRT  = isRunTime(XYZ,!isy)
    lut1 = bi == 32 || iRT ? 0 : 1
    lut2 = bi  > 12 || iRT ? 0 : 2
    cy   = Default (Jch,   false)
    fs   = Default (fulls,  true)

    clp  = !isy ? ExtractClip(XYZ) : nop()
    X    = !isy ? clp[0] :    XYZ
    Y    = !isy ? clp[1] :     Y
    Z    = !isy ? clp[2] :      Z

    rW    = [95.0449218275099, 100., 108.8916648430471] # Reference White: Normalization to Y=100 of illuminant

    L = Expr(Y,               Format("x sqrt 10 *"),                            optSingleMode=false, lut=lut1)
    a = Expr(X, Y,    ex_dlut(Format("x 1.02  * y - 17.5 * y sqrt /"), bi, fs), optSingleMode=true,  lut=lut2)
    b = Expr(   Y, Z, ex_dlut(Format("y 0.847 * x -    7 * y sqrt /"), bi, fs), optSingleMode=true,  lut=lut2)

    isy ? [L, a, b] : CombinePlanes(L, a, b, planes="RGB") }




# XYZ to CIE Luv/Duv -D65 based- (process in linear space) (32-bit float recommended)
function XYZ_to_Luv (clip XYZ, clip "Y", clip "Z", bool "Jch", bool "Duv", bool "tv_in", bool "tv_out") {

    isy = isy(XYZ)
    bi  = BitsPerComponent(XYZ)
    lut = bi == 32 || isRunTime(XYZ,!isy) ? 0 : 1
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
# CIE Luv to XYZ (32-bit float recommended)
function Luv_to_XYZ (clip Luv, clip "u", clip "v", bool "Jch", bool "Duv", bool "tv_in", bool "tv_out") {

    isy = isy(Luv)
    bi  = BitsPerComponent(Luv)
    lut = bi == 32 || isRunTime(Luv,!isy) ? 0 : 1
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


# WIP. Only works in 32-bit float (correct? grey should output [0, 1, 0.935669])
# Jyrki Alakuijala: "CIELAB is perceptually uniform but only at low frequencies as it is based on 2 degrees of uniform color circles. At high spatial frequencies something like JPEG XL's XYB space will be perceptually more meaningful"
function XYZ_to_XYB (clip XYZ, clip "Y", clip "Z", bool "fulls") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    fs   = Default (fulls,  true)

    clp  = !isy ? ExtractClip(XYZ) : nop()
    X    = !isy ? clp[0] :    XYZ
    Y    = !isy ? clp[1] :     Y
    Z    = !isy ? clp[2] :      Z
    XYZa = !isy ?[X,Y,Z] :    XYZ

    LMS = XYZ_to_LMS(XYZ,"Bradford",true,false)

    T   = [1, -1, 0, \
           1,  1, 0, \
           0,  0, 1]

    M = MatrixDot(T, LMS)

    X = DotClipA(XYZa,[M[0],M[3],M[6]])
    Y = DotClipA(XYZa,[M[1],M[4],M[7]])
    B = DotClipA(XYZa,[M[2],M[5],M[8]])

    isy ? [X, Y, B] : MatrixClip(XYZ, M) }


# WIP. Only works in 32-bit float
function XYB_to_XYZ (clip XYB, clip "Y", clip "B", bool "fulls") {

    isy  = isy(XYB)
    bi   = BitsPerComponent(XYB)
    fs   = Default (fulls,  true)

    clp  = !isy ? ExtractClip(XYB) : nop()
    X    = !isy ? clp[0] :    XYB
    Y    = !isy ? clp[1] :     Y
    B    = !isy ? clp[2] :      B
    XYBa = !isy ?[X,Y,B] :    XYB

    LMS = XYZ_to_LMS(XYB,"Bradford",true,false)

    T   = [1, -1, 0, \
           1,  1, 0, \
           0,  0, 1]

    M = MatrixInvert(MatrixDot(T, LMS))

    X = DotClipA(XYBa,[M[0],M[3],M[6]])
    Y = DotClipA(XYBa,[M[1],M[4],M[7]])
    Z = DotClipA(XYBa,[M[2],M[5],M[8]])

    isy ? [X, Y, Z] : MatrixClip(XYB, M) }


# RGB' to HSV
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

    Ss = ex_dlut(Ss, bi, !tv)
    Hs = ex_dlut(Hs, bi, !tv)

    if (isy) {

        S = Expr(R, G, B, V, Ss, optSingleMode=false)
        H = Expr(R, G, B, V, Hs, optSingleMode=true)
        [H, S, V]

    } else { Expr(R, G, B, V, Hs, Ss, "a", format=PixelType(RGB), optSingleMode=true) } }


# HSV to RGB'
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

    Rs = ex_dlut(Rs, bi, !tv)
    Gs = ex_dlut(Gs, bi, !tv)
    Bs = ex_dlut(Bs, bi, !tv)

    if (isy) {

        R = Expr(H, S, V, Rs, optSingleMode=false)
        G = Expr(H, S, V, Gs, optSingleMode=false)
        B = Expr(H, S, V, Bs, optSingleMode=false)
        [R, G, B]

    } else { Expr(H, S, V, Rs, Gs, Bs, format=PixelType(HSV), optSingleMode=true) } }



# RGB linear to IPT -requires D65- (original PT range scaled from -1 +1 to 0 +1)
# Fix some NaN in black areas
function RGB_to_IPT (clip RGB, clip "G", clip "B", bool "Jch", string "matrix", bool "fulls") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    mat = Default (matrix, "709")
    cy  = Default (Jch,    false)    # enable to convert to JCh (cylindrical IPT) in the range 0 to 1.
    fs  = Default (fulls,   true)

    mat = color_Fuzzy_Search(mat)
    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    LMS = XYZ_to_LMS(RGB,"HPEIPT",true,true)

    IPT = [0.4000,  4.4550,  0.8056, \
           0.4000, -4.8510,  0.3572, \
           0.2000,  0.3960, -1.1628]

    mata = RGB_to_XYZ (R, mat[0], list=true)
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

    mat = Default (matrix, "709")
    cy  = Default (Jch,      false)   # enable to convert from Jch (cylindrical IPT) in the range 0 to 1.
    fs  = Default (fulls,     true)

    mat = color_Fuzzy_Search(mat)
    clp = !isy ? ExtractClip(IPT) : nop()
    I   = !isy ? clp[0] :    IPT
    P   = !isy ? clp[1] :     P
    T   = !isy ? clp[2] :      T

    IPTm = [0.4000,  4.4550,  0.8056, \
            0.4000, -4.8510,  0.3572, \
            0.2000,  0.3960, -1.1628]

    LMS = LMS_to_XYZ(IPT,"HPEIPT",true,true)

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



# RGB linear to Oklab -requires D65- (original 'ab' range scaled from -1 +1 to 0 +1)
# Fix some NaN in black areas
function RGB_to_Oklab (clip RGB, clip "G", clip "B", bool "Jch", string "matrix", bool "fulls") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    mat = Default (matrix, "709")
    cy  = Default (Jch,      false)    # enable to convert to Oklch (cylindrical Oklab) in the range 0 to 1.
    fs  = Default (fulls,     true)

    mat = color_Fuzzy_Search(mat)
    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    # LMS version matrix of Oklab
    M1 = [0.8189330101, 0.3618667424, -0.1288597137, \
          0.0329845436, 0.9293118715,  0.0361456387, \
          0.0482003018, 0.2643662691,  0.6338517070]

    # From Oklab's LMS to Lab
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

    mat = Default (matrix, "709")
    cy  = Default (Jch,      false)   # enable to convert from OkLch (cylindrical OkLab) in the range 0 to 1.
    fs  = Default (fulls,     true)

    mat = color_Fuzzy_Search(mat)
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



# RGB to ICtCp. HDR version of YcCbcCrc (aka YCbCr CL)
# Used mainly for DV Profile 5 [BL+RPU]
# Requires 32-bit float
#
# Example:
#     YUV444PS ICtCp source
#     ICtCp_to_RGB("2020",4059 ,DoVi=false) # Mastered at 4059 nits
#     RGB_to_ICtCp("2020",10000,DoVi=false) # round-trip
#
# Example for IPTPQc2:
#     YUV444PS IPTPQc2 source
#     ICtCp_to_RGB("709",10000,DoVi=true)   # Decode to 709
#     st_2084_eotf(10000)                   # Reconstitute gamma (until polynomial reshaping is implemented for DVp5 or MMR for DVp8)
function RGB_to_ICtCp (clip rgb, string "matrix", int "MasterLevel", bool "DoVi") {

    mat    = color_Fuzzy_Search(matrix)
    props  = color_propGet(rgb,mat[4])

    mat    = Defined (matrix) ? mat[0] : props[0]
    PL     = Default (MasterLevel, 10000) # Max Mastering Level in Nits (1000 - 10000)
    DV     = Default (DoVi, false)        # Set to true for IPTPQc2

    # Crosstalk 4% for ICtCp, 2% for Dolby Vision (IPTPQc2)
    xt        =       DV ? 0.02 : 0.04
    Crosstalk = [ 1-2*xt,     xt,     xt, \
                      xt, 1-2*xt,     xt, \
                      xt,     xt, 1-2*xt]

    LMS = XYZ_to_LMS("HPE",       list=true)
    LMX = MatrixDot(Crosstalk, LMS)
    XYZ = RGB_to_XYZ(mat,props[3],list=true)
    RtL = MatrixDot(LMX, MatrixTranspose(XYZ)) # RGB to LMS joint matrix

    LMS = MatrixClip(rgb, MatrixTranspose(RtL), switch=false)

    LMS_gam = st_2084_eotf(LMS,MasterLevel)

    # Skin tones alignment
    alpha = 1.134464
    rot   = [ 1,          0,          0, \
              0, cos(alpha),-sin(alpha), \
              0, sin(alpha), cos(alpha)]

    # IPT by Ebner & Fairchild
    mul = DV ? 0.5 : 1    # DVp5 reshaping. Write to RPU flag
    IPT = [     0.4000,      0.4000,       0.2000, \
            mul*4.4550, mul*-4.8510,  mul* 0.3960, \
            mul*0.8056, mul* 0.3572,  mul*-1.1628]

    # Fit chroma between -0.5 - 0.5
    # First row weighted to yield 0.5 0.5 0 for I (Intensity) constant luminance coefficients
    sca   = [ 1.25, 1.25, 0.0, \
              1.40, 1.40, 1.4, \
              1.00, 1.00, 1.0]

    skin  = MatrixDot(rot, IPT)
    fit   = ArrayOp  (skin, sca, "*")

    MatrixClip(LMS_gam, MatrixTranspose(DoVi ? IPT : fit), switch=true) }


# ICtCp to RGB
function ICtCp_to_RGB (clip ictcp, string "matrix", int "MasterLevel", bool "DoVi") {

    mat    = color_Fuzzy_Search(matrix)
    props  = color_propGet(ictcp,mat[4])

    mat    = Defined (matrix) ? mat[0] : props[0]
    PL     = Default (MasterLevel, 10000) # Max Mastering Level in Nits (1000 - 10000)
    DV     = Default (DoVi, false)        # Set to true for IPTPQc2

    ictcp
    # ICtCp to LMS joint matrix
    LMS  = [ 1,  0.008607,  0.111033, \
             1, -0.008607, -0.111033, \
             1,  0.560046, -0.320632]

    # IPTPQc2 to LMS joint matrix
    mul = DV ? 2 : 1    # undo reshaping. Read from RPU flag
    LMS5 = [ 1,  mul* 0.097600, mul* 0.205200, \
             1,  mul*-0.113900, mul* 0.133200, \
             1,  mul* 0.032600, mul*-0.676900]

    LMS = MatrixClip(ictcp, MatrixTranspose(DoVi ? LMS5 : LMS), switch=!isRGB(ictcp)) # Switch=true because ICtCp is packed into YCbCr format
    LMS_gam = st_2084_oetf(LMS,MasterLevel)

    # Crosstalk 4% for ICtCp, 2% for Dolby Vision (IPTPQc2)
    xt        =       DV ? 0.02 : 0.04
    Crosstalk = [ 1-2*xt,     xt,     xt, \
                      xt, 1-2*xt,     xt, \
                      xt,     xt, 1-2*xt]

    LMS = XYZ_to_LMS("HPE",       list=true)
    LMX = MatrixDot(Crosstalk, LMS)
    RGB = XYZ_to_RGB(mat,props[3],list=true)
    LtR = MatrixDot(MatrixTranspose(MatrixInvert(LMX)), RGB) # LMS to RGB joint matrix

    MatrixClip(LMS_gam, LtR, switch=false)  }



# RGB linear to XYZ
function RGB_to_XYZ (clip rgb, string cspace, string "illuminant", bool "list") {

    cs    = color_Fuzzy_Search(cspace)
    illu  = color_propGet(rgb,cs[4])
    list  = Default(list, false)
    illu  = Default(illuminant, illu[3])

    # Properties:
    # Summing columns yields Reference White in Y=1.0 scale
    # Summing column in the middle yields 1.0
    # Middle  column represents luminance coefficients
    # Rows are proportional to color primaries rows
    #
    # matrix = cspace == "sRGB" || cspace == "709" ?  \
    #         [ 0.41241079568862915, 0.21264933049678802, 0.01933175697922707,    \
    #           0.35758456587791443, 0.71516913175582890, 0.11919485777616501,    \
    #           0.18045382201671600, 0.07218152284622192, 0.95039016008377080]  : 0

    p     = Matrix_coef(cs[0], illu)

    # Reference White
    RW    = [p[3]/p[4],1,p[5]/p[4]]

    # Primaries Flat Array
    prims = [p[6][0],p[6][1],p[6][2],\
             p[7][0],p[7][1],p[7][2],\
             p[8][0],p[8][1],p[8][2]]

    iP = MatrixInvert(prims)
    T  = MatrixDot(RW,MatrixTranspose(iP))
    M  = MatrixDot(Broadcast(T),prims)

    list ? M : MatrixClip(rgb, M) }


# XYZ to RGB linear
function XYZ_to_RGB (clip xyz, string cspace, string "illuminant", bool "list") {

    cs    = color_Fuzzy_Search(cspace)
    illu  = color_propGet(xyz,cs[4])
    list  = Default(list, false)
    illu  = Default(illuminant, illu[3])

    p     = Matrix_coef(cs[0], illu)

    # Reference White
    RW    = [p[3]/p[4],1,p[5]/p[4]]

    # Primaries Flat Array
    prims = [p[6][0],p[6][1],p[6][2],\
             p[7][0],p[7][1],p[7][2],\
             p[8][0],p[8][1],p[8][2]]

    iP = MatrixInvert(prims)
    T  = MatrixDot(MatrixTranspose(iP),RW)
    M  = MatrixDot(iP,MatrixInvert(Broadcast(T)))

    list ? M : MatrixClip(xyz, M) }



# LMS space for linear Chromatic Adaptation Transforms. LMS stands for Long, Medium, Short cone rod responses known as fundamental tristimulus values.
# XYZ Scaling
# von Kries (Hunt-Pointer-Estevez for equal energy -E-)
# von Kries (Hunt-Pointer-Estevez adjusted for D65)
# von Kries (Hunt-Pointer-Estevez D65 modification for IPT model)
# CAT97 (Bradford) (Spectral-sharpened)
# Fairchild
# CAT00
# CAT02
# CAT02 Brill 2008
# CAT16
# Bianco BS    2010
# Bianco BS PC 2010
# Sharp
# Sharp Spherical
# Sharp Spherical with HUE uniformity
# CIE 2006 Stockman & Sharpe (2000) 2º and 10º Standard Observer
#
# Recommended: CAT16, CAT02B, SharpSphere and Stockman

function XYZ_to_LMS (clip xyz, string "mode", bool "list", bool "transpose") {

    md    = Default (mode,    "CAT16")
    list  = Default (list,      false)
    trans = Default (transpose, false)

    # XYZ Scaling (known as "wrong von Kries")
    XYZvk = [1.000000, 0.000000,  0.000000, \
             0.000000, 1.000000,  0.000000, \
             0.000000, 0.000000,  1.000000]

    # Hunt-Pointer-Estevez cone response (equal energy)
    HPEE  = [0.389709204, 0.688980877, -0.078686185, \
            -0.229811028, 1.183407545,  0.046401147, \
             0.000000000, 0.000000000,  1.000000000]

    # Hunt-Pointer-Estevez cone response normalized to a D65 white point (also known as "von Kries" by association with the von Kries transform method)
    HPE65 = [0.40024, 0.70760, -0.08081, \
            -0.22630, 1.16532,  0.04570, \
             0.00000, 0.00000,  0.91822]

    # HPE65 modification for IPT model
    HPEIPT= [0.4002, 0.7075, -0.0807, \
            -0.2280, 1.1500,  0.0612, \
             0.0000, 0.0000,  0.9184]

    # CAT97/Bradford (also known as Spectral-sharpened Bradford or Linearized Bradford/CIECAM97) usually better than HPE
    # Requires a non-linearity von Kries in the blue channel that is usually omitted (check page 52 of "Computing Chromatic Adaptation" by Süsstrunk)
    Brad  = [0.8951,  0.2664, -0.1614, \
            -0.7502,  1.7135,  0.0367, \
             0.0389, -0.0685,  1.0296]

    # CAT2000, revision of CAT97 by minimizing perceptual error over a different data set
    CAT00 = [0.7982, 0.3389, -0.1371, \
            -0.5918, 1.5512,  0.0406, \
             0.0008, 0.0239,  0.9753]

    # Fairchild improvement over Bradford to make it reversible (better than CAT00)
    Fair  = [0.8562,  0.3372, -0.1934, \
            -0.8360,  1.8327,  0.0033, \
             0.0357, -0.0469,  1.0112]

    # Improvement over Bradford and CAT00 by excluding the McCann haploscopic data set
    CAT02 = [0.7328,  0.4296, -0.1624, \
            -0.7036,  1.6975,  0.0061, \
             0.0030,  0.0136,  0.9834]

    # Brill and Süsstrunk (2008) corrected CAT02 chromatic adaptation transform
    CAT02B= [0.7328,  0.4296, -0.1624, \
            -0.7036,  1.6975,  0.0061, \
             0.0000,  0.0000,  1.0000]

    # Improvement over CAT02
    CAT16 = [0.401288, 0.650173, -0.051461, \
            -0.250268, 1.204414,  0.045854, \
            -0.002079, 0.048952,  0.953127]

    # Sharp Adaptation Transform (performs similar to CAT02)
    Shp   = [1.2694, -0.0988, -0.1706, \
            -0.8364,  1.8006,  0.0357, \
             0.0297, -0.0315,  1.0018]

    # Improvement over Sharp and CAT02 with spherical sampling optimization (very similar to 'CAT16')
    Sph   = [1.1083,  0.0631, -0.1714, \
            -0.8044,  1.7798,  0.0246, \
             0.0000,  0.0151,  0.9849]

    # Improvement over Sphere for HUE uniformity for surface/natural colors (ie. Photographs) (very similar to 'Sharp')
    b20   = [1.6351, -0.4071, -0.2280, \
            -0.8044,  1.7798,  0.0246, \
             0.0000,  0.0152,  0.9848]

    # CIE 170-2 or CIE 2006 Stockman & Sharpe (2000) physiological 2º Standard Observer
    STK   = [0.210576, 0.855098, -0.0396983, \
            -0.417076, 1.177260,  0.0786283, \
             0.000000, 0.000000,  0.516835]

    # CIE 170-2 or CIE 2006 Stockman & Sharpe (2000) physiological 10º Standard Observer
    STK10 = [0.217011, 0.835734, -0.043511, \
            -0.429979, 1.203890,  0.086211, \
             0.000000, 0.000000,  0.465792]

    # WIP. Modified (2012) CIE 2006 Stockman & Sharpe (2000) physiological-relevant 2º Standard Observer
#    CAT12  = [0.000000, 0.000000,  0.000000, \
#             0.000000, 0.000000,  0.000000, \
#             0.000000, 0.000000,  0.000000]

    # Bianco and Schettini (2010) (very similar to CAT02B)
    BIA   = [0.8752, 0.2787, -0.1539, \
            -0.8904, 1.8709,  0.0195, \
            -0.0061, 0.0162,  0.9899]

    # Bianco and Schettini PC (2010)
    BIAPC = [0.6489, 0.3915, -0.0404, \
            -0.3775, 1.3055,  0.0720, \
            -0.0271, 0.0888,  0.9383]

    # This looks like a modified Stockman & Sharpe (2000), from RGB to OPP papers.
    OPP   = [0.2430,  0.8560, -0.0440, \
            -0.3910,  1.1650,  0.0870, \
             0.0100, -0.0080,  0.5630]

    # Fuzzy aliases
    mdL = LCase(md)
    LMS = md == "XYZ"       ? XYZvk         : \
          md == "Scale"     ? XYZvk         : \
          md == "Scaling"   ? XYZvk         : \
          md == "Kries"     ? HPE65         : \
          md == "von Kries" ? HPE65         : \
          md == "vonKries"  ? HPE65         : \
          md == "HPE"       ? HPE65         : \
          FindStr(mdL,"hunt")>0?HPE65       : \
          md == "E"         ? HPEE          : \
          md == "EE"        ? HPEE          : \
          md == "HPEE"      ? HPEE          : \
          md == "IPT"       ? HPEIPT        : \
          md == "HPEIPT"    ? HPEIPT        : \
          md == "Bradford"  ? Brad          : \
          md == "CAT97"     ? Brad          : \
          md == "Fairchild" ? Fair          : \
          md == "CAT00"     ? CAT00         : \
          md == "CAT02"     ? CAT02         : \
          md == "CAT02B"    ? CAT02B        : \
          md == "CAT16"     ? CAT16         : \
          md == "Sharp"     ? Shp           : \
          md == "Sphere"    ? Sph           : \
          md == "SharpSphere"?Sph           : \
          md == "Sharp2"    ? Sph           : \
          md == "Sphere2"   ? b20           : \
          md == "Sharp3"    ? b20           : \
          FindStr(mdL,"hue")>0?b20          : \
          md == "OPP"       ? OPP           : \
          md == "170-2"     ? STK           : \
          FindStr(md,"2006")   >0 ? STK     : \
          FindStr(md,"tockman")>0 ? STK     : \
          FindStr(mdL,"bianco")>0 ? BIA     : \
          FindStr(md,"PC")>0? BIAPC         : \
          Assert(false,"XYZ_to_LMS: Unsupported LMS mode.")

    LMS = trans ? MatrixTranspose(LMS) : LMS
    list  ? LMS : MatrixClip(xyz, LMS) }


function LMS_to_XYZ (clip lms, string "mode", bool "list", bool "transpose") {

    md   = Default (mode, "CAT02")
    tran = Default (transpose, false)
    list = Default (list,      false)

    XYZ  = MatrixInvert(XYZ_to_LMS(lms,md,true,tran))

    list ? XYZ : MatrixClip(lms, XYZ) }



# Linear CAT (Chromatic Adaptation Transform):
#
# Transformation Method:
#   Strong von Kries (von Kries-Ives) (used in ICC)
#   Weak   von Kries (default in CAT() )
#
# 'source' and/or 'target' can be Primaries (Color Space ie. sRGB) or a Standard Illuminant (ie: D65)
function CAT (clip c, string "source", string "target", string "LMS", bool "tv_range", bool "list") {

    rgb     = IsRGB(c)
    propIDs = color_propGet(c)

    src   = Default (source,   propIDs[3])
    tgt   = Default (target,        "D65")
    LMS   = Default (LMS,         "CAT16")
    tv    = Default (tv_range, propIDs[6])
    list  = Default (list,          false)

    src   = color_Fuzzy_Search (src)
    tgt   = color_Fuzzy_Search (tgt)
    src   = list ? [src[1],src[1]] : src
    tgt   = list ? [tgt[1],tgt[1]] : tgt
    wps   = Matrix_coef(src[1])
    wpt   = Matrix_coef(tgt[1])
    same  = wps[3] == wpt[3]

    LMS   = XYZ_to_LMS(c, LMS, true)

    wpsn  = MatrixDot([wps[3]/wps[4],1.,wps[5]/wps[4]], LMS)
    wptn  = MatrixDot([wpt[3]/wpt[4],1.,wpt[5]/wpt[4]], LMS)
    trans = ArrayOp(wptn,wpsn,"/")
    vk    = Broadcast(same ? [1,1,1] : [trans[0],trans[1],trans[2]], "vonKries")

    CAM   = !same ? MatrixDot(LMS, MatrixDot(vk, MatrixInvert(LMS))) : vk

    if (!list) {

        c
        s_pri  = src[0] == "" ? propIDs[2] : src[0]
        s_gam  = src[2] == "" ? propIDs[5] : src[2]
        s_gam  = moncurve_coef(s_gam)

        RGBpln = rgb ? IsPlanar() : false

        rgb ? RGBpln ? last : ConvertToPlanarRGB() : \
        YUV_to_RGB(c, s_pri, tv_range_in=tv, tv_range_out=false, kernel="Point")

        moncurve_f(s_gam[0], s_gam[1], false, false, 1)

        mata = RGB_to_XYZ (s_pri, list=true)
        matb = XYZ_to_RGB (s_pri, list=true)
        MatrixClip( MatrixDot(MatrixDot(mata, CAM), matb) )

        moncurve_r(s_gam[0], s_gam[1], false, false, 1)

        rgb ? RGBpln ? last : MatchClip(c) : \
        RGB_to_YUV( s_pri, tv_range_in=false, tv_range_out=tv, kernel="Point", pixel_type=PixelType(c))
        same ? c : last

    } else { CAM } }


# CIE XYZ Color Matching Functions, the sum of the corresponding CIE RGB CMF integrals define the white point energy.
# Maps spectral observer sensitivity data into linear CIE tristimulus values X, Y and Z.
#
# CIE 1931 2º Standard Observer (ideal for LED) (2º -degrees- is the angular size of the human fovea)
# CIE 1931 Judd (1951) and Vos (1978) modification
#     1955 2º and 10º Stiles and Burch CMF (was the basis for the later CIE 1964)
# CIE 1964 10º Supplementary Standard Observer
# CIE 170-1 or CIE 2006 Stockman & Sharpe (2000) physiological 2º Standard Observer
# CIE 170-1 or CIE 2006 Stockman & Sharpe (2000) physiological 10º Supplementary Standard Observer
# CIE 170-2 (2015) Stockman & Sharpe (2000) physiological 2º Standard Observer
# CIE 170-2 (2015) Stockman & Sharpe (2000) physiological 10º Supplementary Standard Observer (ideal for CCFL, good for OLED)
# CIE 170-2 Schanda-Csuti (2008) modified 2º Standard Observer (ideal for Plasma)
# CIE 170-2 TUI (TU Ilmenau, 2008) modified 2º Standard Observer (ideal for OLED)
# CIE 170-2 TUI (TU Ilmenau, 2008) modified 10º Supplementary Standard Observer
# Abhijit Sarkar (2011) - ODCI (Observer Dependent Color Imaging) (8 Observer Tables presented as Excel spreadsheet)
# Modified (2012) CIE 2006 Stockman & Sharpe (2000) physiological-relevant 2º Standard Observer (http://cvrl.ioo.ucl.ac.uk/ciexyzpr.htm)
# Modified (2012) CIE 2006 Stockman & Sharpe (2000) physiological-relevant 10º Supplementary Standard Observer (ideal for CCFL)
#
# * 10º Standard Observer should only be used for scientific purposes or where the target color patches exceed 4º of the observer field view (like illuminary, and other general related targets). Movies in a SmartTV might range between 26º and 36º (SMPTE 30 or THX) from the observer, but the individual color patches don't.
function CMF (clip c, string "source", string "target", bool "tv_range", bool "list") {

    # Multi-Lobe, Piecewise Gaussian Fit for CIE 1931 2º Standard Observer

}
