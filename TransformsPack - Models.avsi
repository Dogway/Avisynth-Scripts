###########################################################
###                                                      ##
###                                                      ##
###   Transforms Pack - Models v1.3       (29-12-2022)   ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182825    ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
### MODELS:                                              ##
###     RGB_to_YUV      /    YUV_to_RGB                  ##
###     RGB_to_YcCbcCrc /    YcCbcCrc_to_RGB             ##
###     RGB_to_YCoCg    /    YCoCg_to_RGB                ##
###     RGB_to_YCoCgR   /    YCoCgR_to_RGB               ##
###     RGB_to_YUVr     /    YUVr_to_RGB                 ##
###     RGB_to_OPP      /    OPP_to_RGB                  ##
###     XYZ_to_Yxy      /    Yxy_to_XYZ                  ##
###     XYZ_to_YDzDx    /    YDzDx_to_XYZ                ##
###     XYZ_to_Lab      /    Lab_to_XYZ                  ##
###     XYZ_to_Luv      /    Luv_to_XYZ                  ##
###     XYZ_to_XYB      /    XYB_to_XYZ                  ##
###     RGB_to_HSV      /    HSV_to_RGB                  ##
###     RGB_to_IPT      /    IPT_to_RGB                  ##
###     RGB_to_ICtCp    /    ICtCp_to_RGB                ##
###     RGB_to_Oklab    /    Oklab_to_RGB                ##
###     RGB_to_XYZ      /    XYZ_to_RGB                  ##
###     XYZ_to_LMS      /    LMS_to_XYZ                  ##
### ADAPTATION:                                          ##
###     CAT                                              ##
###     CMF                                              ##
###     SPD_D                                            ##
###     Chromaticity_xy                                  ##
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
# Characterization spaces are normally used to represent device gamuts for profiling on a unit-to-unit basis.
# Standard spaces define a standard to comply with for delivery, normally they are derived from averaging measurements of real unit-by-unit devices defined by their used phosphors.
# Finally working spaces don't need to be attached to any physical constraints so they can be as big as the CIE 1931 color space (some actually bigger than that), so they are suited for heavy color transformations without much degradation in the process. They can also be geared towards certain effects like getting more color resolution in certain HUEs for exposing better shades in color grading tasks. Ultimately everything is being transformed into your viewing transform color space in real time so use any working space that suits your job.
#
#-470M                   - (Historical) ITU-R Rec. BT.470 M. Also known as FCC or NTSC (1953) with C illuminant and 170M OETF.
#-470BG                  - ITU-R Rec. BT.1700 (or legacy ITU-R Rec. BT.601) (625-line = PAL, SECAM).
#-170M                   - ITU-R Rec. BT.1700 (or legacy ITU-R Rec. BT.601) (525-line = NTSC, SMPTE-C) (originally defined in "CCIR Recommendation 601-1 (1982-1986)").
#-240M                   - SMPTE 240M.
#-NTSC-J                 - ARIB TR-B9. Phosphor primaries used in Japan's consumer CRTs along 9300K + 27 MPCD illuminant.
#-sRGB                   - IEC 61966-2. Jointly developed by Microsoft and Hewlett-Packard as a color standard designed primarily for office, home and web users. Comprises Primaries -derived from phosphors of calibrated consumer CRTs of the 90s-, Illuminant and Transfer Characteristics.
#-2020                   - ITU-R Rec. BT.2020.
#-AdobeRGB               - IEC 61966-2-5:1999. Also known as opRGB (optional RGB). Designed to encompass most printers' gamuts and to be used as a working space in Photoshop, ideally at 16-bit. It's basically the 470BG primaries with greens from 470M allegedly after a sucessions of mistakes.
#-Adobe Wide Gamut       - Adobe second and final wide gamut version of AdobeRGB with same transfer but in D50 illuminant.
#-DCI-P3                 - SMPTE RP 432-2. Digital Cinema.
#-Display-P3             - SMPTE RP 432-1.
#-AP0                    - ACES AP0 coefficients used for ACES2065 color space.
#-AP1                    - ACES AP1 coefficients used for ACEScg   color space.
# S-Gamut                -
# S-Gamut3               -
# S-Gamut3 (Venice)      -
# S-Gamut3.Cine          - Sony Gamut Cinema. A little over DCI-P3 gamut in size, paired with S-Log3 it reproduces a scanned negative film.
# S-Gamut3.Cine (Venice) -
# CinemaDay              - Canon Cinema Gamut Daylight (5500K).
# CinemaTungsten         - Canon Cinema Gamut Tungsten (3200K).
# CanonP3                - Canon DCI-P3+.
# D-Gamut                - DJI D-Gamut.
# D-GamutM               - DJI D-GamutM.
# DragonColor            - RED DragonColor
# DragonColor2           - RED DragonColor2
# REDColor               -
# REDColor2              -
# REDColor3              -
# REDColor4              -
# REDWide                - RED Wide Gamut RGB.
# Protune                - GoPro Protune Native.
# Bolex                  - Bolex Wide Gamut RGB.
# DaVinci Wide Gamut     -
# Almira709              -
# LC709                  -
# LC709A                 -
# s709                   -
# Cine709                - Sony Cine+709.
# ADX10                  -
# ADX16                  -
# BMD Wide Gamut         - BlackMagic Design Wide Gamut
# BMP 6k Film            - BlackMagic Pocket 6K Film
# BMD Film               - (Legacy)
# BMD Broadcast Video    - (Legacy)
# BMD Broadcast Film     - (Legacy)
# BMD 4K Film            - (Legacy)
# BMD 4K Film V3         - (Legacy)
# BMD 4K Video V3        - (Legacy)
# BMD 4.6K Film          - (Legacy)
# BMD 4.6K Film v3       - (Legacy)
# BMD 4.6K Video         - (Legacy)
# BMD 4.6K Video v3      - (Legacy)
# Alexa                  - Arri (Alexa) Wide Gamut.
# Film                   - Arri Film Matrix. Traditional film primaries with Illuminant C.
# FS                     - SMPTE Free Scale Gamut for imagery having arbitrary chromaticity that can be conveyed, inherited from Sony's F23, F35, and F65 Wide Gamut cameras. (ST 2048-1).
# V-Gamut                - Panasonic V-Gamut (Varicam).
# V709                   - Panasonic Varicam V709.
# F-Log                  - Fujifilm F-Log Gamut.
# Barco Unisee           -
#-ProPhoto RGB           - RIMM/ROMM RGB by Kodak to encompass all printable and most real world colors. D50 with Apple gamma. ERIMM RGB is geared towards HDR.
#-Wide Gamut RGB         - Adobe first wide gamut version with D50, and AdobeRGB gamma (2.19921875). Designed by Adobe to be a wide gamut color space that uses spectral colors as its primaries.
#-AllColorsRGB           - Developed by Ellen Stone to encompass all colors, slightly wider than AP0. Defined with linear transfer at D50 and prims: 0.734690265, 0.265309735, 0.17451, 0.005182, 0.0, -0.07585421971554103213.
#-MaxRGB                 - Developed by Don Hutcheson. "If you can accept 'illegal' colors (outside the CIEYxy limits) then try the outrageously saturated gamut of MaxRGB. Not that you gain anything useful, but at least you can say you have an even bigger Photoshop-style tri-coordinate RGB working space than ProPhoto RGB!"
#-xTremeRGB              - Developed by Don Hutcheson. "XtremeRGB pushes Photoshop (tri-coordinate 3x3 matrix) color spaces rules to the absolute limit, producing the world's largest possible Photoshop-legal tricoordinate RGB space. However it does so at extreme risk and is provided here as a curiosity more than a useful tool. Only use XtremeRGB on 16 bit-per-channel (or higher) images."
#-CIE RGB                - or CIE 1931 RGB in linear space (sometimes over generic gamma of 2.2) and E illuminant.
#-Apple RGB              - RGB color space by Apple derived from Sony Trinitron phosphors, similar in gamut size to sRGB or ColorMatch. Employs a gamma of 1.8.
#-ColorMatch RGB         - Radius PressView Monitors with D50 and a power gamma of 1.8.
# EBU 3213               - EBU Tech. 3213-E / JEDEC P22 phosphors.
#-Bruce RGB              - Developed by Bruce Fraser as a conservative-gamut space for dealing with 8-bit imagery that needs heavy editing. Early and modest gamut that made into one of the SWOP printing standards in the U.S.
#-DonRGB4                - Developed by Don Hutcheson in 1996. Wide gamut working space for photography, prepress, etc. 2.2 pure power gamma.
#-BestRGB                - Developed by Don Hutcheson. Improved DonRGB4 for saturated reds and magentas. 2.2 pure power gamma.
#-Beta RGB               - Developed by Bruce Lindbloom. An optimized capture, archiving and editing space for high-end digital imaging applications, modeled after famous photographic films like Fuji, Agfa or Kodak. 2.2 pure power gamma.
#-Russell RGB            - Developed by Russell Cottrell. An extension of Beta RGB for cyans and blues to encompass some printers' gamuts. Uses D55 illuminant in 2.2 power gamma.
#-ECI-RGB v2             - Developed by the European Color Initiative <www.eci.org>. Employs the L* gamma transfer.
#-Ekta Space PS5         - Developed by Joseph Holmes for high quality storage of image data from scans of transparencies (aka chromes), mostly for positives but works fine also for negative film. 2.2 pure power gamma.
#-Chrome Space 100       - Developed by Joseph Holmes. Refined 2005 version of Ekta Space PS5, conserving primaries and illuminant but with a different gamma, designed to match the tonality of a perceptually linear greyscale for printers.
# DCam Sets              - Developed by Joseph Holmes. 5 color spaces designed for digital cameras, they also use Chrome Space 100 tone curve.
# And many more oldies not included here for simplicity: P22 (Measured SMPTE-C), EBU measured, Conrac 7211N19, Hitachi, Barco, Tektronics, SGI Trinitron, Sony Trinitron KV-20M20.

# List of Color Models:
# Color Models -not to be confused with Color Spaces- describe the geometry coordinates of the color gamut container and hence its relation (or correlation) with the other channels. They are typically designed or tailored to certain Color Spaces, but not necessarily bound to them, like RGB or YCbCr which support many different Color Spaces and thus are nicked Color Absolute Models.
# Color Spaces comprises Primaries and an associated Illuminant. It is also common to be associated with a transfer function although its relationship is not as strict (as it depends on viewing conditions).
#
# UCS: Uniform Color Space. Space (model) in which equal distances on the coordinate diagram correspond to equal perceived color differences.
# With *: Color Appearance Models (CAM) (Perceptually Uniform -UCS- to various degrees)
# With +: HDR aware
# With -: Implemented
#
# CMYK         - Color model used in print industry.
#-RGB+         - RGB color model for channels Red, Green, and Blue. Normally found in interleaved packing format. AviSynth works best with planar RGB so a conversion is first needed.
#-OPP          - by Liang et al. RGB opponent space.
# NOPP         - by Liang et al.
# COPP         - by Liang et al.
# rg           - Photometric invariant (shadows, shading) 2 channel color representation, by Danelljan [R/(R+G+B), G/(R+G+B)]
# I1I2I3       - by Guo and Lyu [0.3333*(R+G+B),0.5*(R-B),0.25*(2G-R-B)]
# C1C2C3       - by Salvador et al.
# LSLM         - RGB opponent space based on the signals of the cones: black-white, red-green, and yellow-blue.
# YES          - by Saber et al.
# UVW          - by Ohta et al.
# SO           - Biologically Inspired Color Image Descriptor.
# c1c2c4       - Biologically Inspired Color Image Descriptor.
# o1o2         - For Robust Image Detection in Scenes under Cast Shadows. https://digital.csic.es/bitstream/10261/30099/1/Combining%20color-based.pdf
#-YCbCr        - Color format roughly based on human perception of luma and chroma contribution (approximately perceptually uniform). Uses 3 planes for Luma, opposing blue-yellow, and opposing red-green. It's a 45º skewed parallelogram relative to the square RGB box, therefore only 23.6% of its color volume matches RGB and 76.4% is out of RGB gamut.
#-YPbPr        - A model for analogue signals. It's basically the same as YCbCr but with no definition for the SMPTE range.
# YIQ          - YCbCr with (YCbCr) UV axes rotated 33º, used for NTSC TV analogue system. Quote from avisynth.nl/index.php/Tweak: "In YIQ, orange and teal are along the in-phase (I) axis, while green and magenta are along the quadrature (Q) axis. The eye is far more sensitive to detail along the I axis than along the Q axis, and NTSC allocated more bandwidth for I than for Q."
# YDbDr        - PAL-N and SECAM TV analogue format.
#-YUVr         - "YUV RCT". Same as YUV but fully reversible to RGB.
# sYUV         - "Sharp YUV". Same as YUV but luma-weighted chroma subsampling, retaining chroma fidelity.
#-YcCbcCrc     - YCbCr Constant Luminance (CL). Better decorrelation than YCbCr.
# xvYCC        - Expanded Gamut YCbCr. For newer TV systems it is/was a model that allowed the color gamut (typically Rec709) to be stored in the full range while luma in the narrow range.
#-YCoCg        - Better luma/chroma decorrelation and compression efficiency than YCbCr.
#-YCoCgR       - Same as YCoCg but losslessly reversible to RGB.
# YFbFr        - Similar to YCoCg, employs Karhunen-Loève transform (KLT) to design an integer reversible transform.
#-XYZ          - CIE 1931 XYZ tristimulus color model representing all the non-imaginary colors.
# LSY          - Reads lambda-SY. Spectral color space. Representation based on brightness, dominant wavelength and saturation attributes. LSY color coordinates are defined from xyY color coordinates.
#-YDzDx+       - HDR version of XYZ. Requires at least 10-bit for no visible quantization.
# YCxCz        - Color Space for image fidelity metrics. It's a first step space, you have to "filter" it and then convert to Lab to retrieve error delta.
#-DCI XYZ      - XYZ space in DCI illuminant. In effect it's just a container for DCI-P3 in XYZ coordinates for delivery to theaters.
#-Yxy/xyY      - Chroma normalized XYZ space which gives full luma/chroma decorrelation. Not apt for HDR, use YDzDx+ instead.
#-HSV          - Cylindrical representation of RGB. Not recommended as it doesn't take into account human luminance perception.
#-Duv*         - Perceptual based model which measures the closest distance from the Planckian locus on the CIE 1976 (u', 2/3 v') diagram. Some color spaces and Delta metrics are computed in this model which is an update of the CIE 1960 UCS chromaticity diagram. A white point defined in Duv coordinates is called a "color tint".
# HunterLab*   - A more perceptually uniform version of CIELab.
#-CIELab*      - Derived from CIE XYZ, one of the first approaches to a perceptually uniform color model. CIELch(ab) is its cylindrical (polar coordinates) version. You can derive it's Delta E with the next equation: DE = (DL^2 + Da^2 + Db^2)/2  = ( (Ly-Lx)^2 + (ay-ax)^2 + (by-bx)^2)/2.
# CIEsLab*     - CIE simple Lab.
# R-Lab*       - Ruderman Lab space, using log luma and different weights for ab.
# L-Lab*       -
# SRLab2*      - A 2009 modification of CIELab by Jan Behrens in the spirit of RLAB. Uses CIECAM02 chromatic adaptation matrix to fix the blue hue issue but keeps CIELab transfer.
#-CIELuv*      - CIE 1976. Derived from CIE 1964 UVW, a competing perceptually uniform color model of CIELab around the same time the latter appeared. CIELuv uses a Judd-type CAT, while CIELab uses "wrong" von-Kries (XYZ Scaling).
#   CIELch(uv)*- HCL (polar coordinates or cylindrical) version of CIELuv.
#   HSLuv*     - A cylindrical HSL type adaptation of CIELuv. It extends CIELuv with a new saturation component that allows you to span all the available chroma as a neat percentage.
# LogLuv*+     - HDR version of CIELuv, that uses log to encode HDR values in a 15-bit container.
# Y''U''V''*+  - HDR version of CIELuv by Charles Poynton. Improves on LogLuv by using a PQ transfer which just needs 12-bits.
# CIEDuDv*+    - or YDuDv. HDR version of CIE Luv. Requires only 8-bit for no visible quantization.
# CIECAM97s*   -
#-XYB*         - Uniform (UCS) space used in Guetzli's butteraugli metric and JPEG-XL, with a main goal in compression. Better uniformity than CIE Lab but not as good as IPT.
# DIN99o*      - Color space based on CIE Lab for which main characteristic is to show comparable accuracy to CIEDE2000 but with a simple Euclidean distance.
# JzAzBz*+     - A 2017 uniform (UCS) space designed for HDR color. Has J (lightness) and two chromaticities. JzCzhz is the HCL (polar coordinates or cylindrical) version of JzAzBz.
#-IPT*         - Intensity Protanope Tritanope. A more uniform color space in SDR colors. There's a version called hdrIPT.
# IgPgTg       - Based on IPT but optimized using gaussian spectra to derive a hue-linear color space.
# ICaCb+       - Precursor and arguably better color model than ICtCp which based on this.
#-ICtCp+       - BT.2100 (HDR + Rec.2020) version of IPT. HDR version of YcCbcCrc but with Constant Intensity this time.
# ITP*+        - Perceptually uniform color space version of ICtCp, used extensively in error metrics by scaling Ct by 0.5. This transformation is the basis of the Rec.2124 wide gamut color difference metric D.itp (simple scaled Euclidean distance: 720*sqrt(Di^2+D(t*0.5)^2+Dp^2) )
#-IPTPQc2*+    - Improved HDR10 version of ICtCp. Since it's a propietary model not much information is known.
# CIECAM02*    - Improves on CIECAM97s and can be made uniform with CAM02-UCS. CIECAM02Jch is its cylindrical version.
# OSA*         -
# CIECAM16*    - Improves on CIECAM02 and can be made uniform with CAM16-UCS, which works "out-of-the-box" for Euclidean distance metrics.
# CAM20u       - Improvement over CIECAM16 for predicting the color appearance of unrelated colors.
# ZCAM*+       - A uniform (UCS) space for HDR color.
#-Oklab*       - A uniform (UCS) space for SDR color. Simple to compute yet powerful. Takes CAM16 lightness and chroma, and IPT for hue. OkLch is the cylindrical form of Oklab.
# iCAM06       - An image (not only color) appearance metric model to not only compute perceived difference in lightness, hue or chroma, but also contrast, sharpness or graininess. Involves converting to IPT, low-pass filtering in linear space, convert to non-linearity, then to Jch model and QM if necessary for the metrics.


# YCbCr to RGB' standalone function (at least 10-bit precision recommended)
function YUV_to_RGB (clip yuv, string "matrix", bool "tv_in", bool "tv_out", string "kernel", float "b", float "c", float "p", string "cplace", bool "UVrecon") {

    matrix     = Default (matrix, "709")

    bi         = BitsPerComponent(yuv)
    fs         = propNumElements (yuv,"_ColorRange")  > 0 ? \
                 propGetInt      (yuv,"_ColorRange") == 0 : (matrix=="JPEG" || matrix=="JPG")

    kernel     = Default (kernel,"Precise")      # Precise Bicubic. A better alternative although slower is lanczos3
    tv_in      = Default (tv_in,       !fs)
    tv_out     = Default (tv_out,    false)
    cplace     = Default (cplace,       "")
    recon      = Default (UVrecon,   false)
    b          = Default (b,  0.0)               # Bicubic 'b' coefficient, or 'taps' for sinc kernels
    c          = Default (c, 0.75)               # Precise Bicubic
    p          = Default (p,    9)

    Assert(IsVersionOrGreater(3,7,2), "YUV_to_RGB: Update AviSynth+ version")
    Assert(!isRGB(yuv),               "YUV_to_RGB: Only YUV format supported")

    p_type   = format_Fuzzy_Search(yuv, PixelType(yuv), bi)
    matrix   = color_Fuzzy_Search (matrix)
    coef     = color_coef(mat=matrix[0])
    bc       = bicubic_coeffs(kernel)
    bc_b     = string(bc[1]>=-1?bc[0]:b)
    bc_c     = string(bc[1]>=-1?bc[1]:c)
    kernel   = bc[1]>=-1 ? "Bicubic" : LCase(kernel)

    p_type4  = p_type[1] == "444"
    p_type2  = p_type[1] == "422"
    p_type1  = p_type[1] == "411"
    p_type10 = p_type[1] == "410"

    w  = width (yuv)
    h  = height(yuv)
    nw = p_type4 ? w : p_type1 || p_type10 ? round(w/4.0) : round(w/2.0)
    nh = p_type4 ||    p_type1 || p_type2  ?            h : round(h/2.0)

    cplace  = chroma_placement(w, h, w, h, matrix[0], matrix[0], "YUV"+p_type[1], "RGB", p_type[1], "444", cplace, "center" )

     p_type1             ? Assert(bi == 8,   "YUV_to_RGB: Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10, "YUV_to_RGB: Unsupported Pixel Type: YUV410")


    cplaceH = ",src_left="+string(cplace[0])
    cplaceV = ",src_top ="+string(cplace[1])

    resampler = FindStr(kernel, "lanczos")>0 && kernel!="lanczos4" || FindStr(kernel, "blackman")>0 || FindStr(kernel, "sinc")>0     ? \
                                     kernel + "Resize(" + String(w) + "," + String(h) + cplaceH + cplaceV +",taps=    int("+bc_b+"))": \
                kernel == "nnedi3" ?    "nnedi3resize(" + String(w) + "," + String(h)                     + ")"                      : \
                kernel == "bicubic"?   "BicubicResize(" + String(w) + "," + String(h) + cplaceH + cplaceV +",b="+bc_b+",c="+bc_c+")" : \
                kernel == "gauss"  ?     "GaussResize(" + String(w) + "," + String(h) + cplaceH + cplaceV +",p=p)"                   : \
                                     kernel + "Resize(" + String(w) + "," + String(h) + cplaceH + cplaceV +")"

    Y   = ExtractY(yuv)
    Uor = ExtractU(yuv)
    Vor = ExtractV(yuv)

    # feisty2's ChromaReconstructor_faster v3.0 HBD mod

    if (recon && !p_type4) {

        ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), "auto", wref=1)
        Luma    = ref.nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, HBD=false, gpuid=0)
        Uu      = Uor.nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, HBD=false, gpuid=0, fwidth=w*2, fheight=h*2)
        Vu      = Vor.nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, HBD=false, gpuid=0, fwidth=w*2, fheight=h*2)
        Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=0.0, c=0.5)
        Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=0.0, c=0.5)
        U       = ex_LFR(Unew, Uu.BicubicResize(w, h, b=0.0, c=0.5), LFR=w/1.1)
        V       = ex_LFR(Vnew, Vu.BicubicResize(w, h, b=0.0, c=0.5), LFR=w/1.1)

    } else {

        U   = p_type4 ? Uor : Eval("Uor." + resampler)
        V   = p_type4 ? Vor : Eval("Vor." + resampler)

        }


    if (matrix[0]=="2020CL" || matrix[0]=="DCI-P3" || matrix[0]=="Display-P3") {

        Assert(false, "YUV_to_RGB: Use YcCbcCrc_to_RGB() function")

    } else {

        scale_y   = tv_in != tv_out ? tv_in ? 256/219. : 219/256. : 1.0
        scale_uv  = tv_in != tv_out ? tv_in ? 256/112. : 224/128. : 2.0

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y                                                m2 = scale_uv * Kr
                         m4 = scale_uv * ( -Kb * coef[2] / coef[1]) m5 = scale_uv * ( -Kr * coef[0] / coef[1])
                         m7 = scale_uv *    Kb

        range_PC = scale_y == 256/219. ? "ymin - " : ""
        range_TV = scale_y == 219/256. ? "ymin + " : ""
        UVf      = bi < 32             ? "range_half - " : ""

        Expr(Y, U, V, ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+"                            z "+UVf + string(m2)+" * + ", bi, false), \
                      ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m4)+" * + z "+UVf + string(m5)+" * + ", bi, false), \
                      ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m7)+" * +                            ", bi, false), optSingleMode=true, format=bi>16?"RGBPS":"RGBP"+string(bi))
    }

    tv_in!=tv_out ? propSet("_ColorRange", tv_out ? 1 : 0) : last
                    propSet("_Matrix",     0)
                    propSet("_Model",      1) }



# RGB' to YCbCr standalone function (at least 10-bit precision recommended)
function RGB_to_YUV (clip rgb, string "matrix", bool "tv_in", bool "tv_out", string "Jab", string "kernel", float "b", float "c", float "p", string "cplace") {

    bi         = BitsPerComponent(rgb)
    fs         = propNumElements (rgb,"_ColorRange")  > 0 ? \
                 propGetInt      (rgb,"_ColorRange") == 0 : true

    matrix     = Default (matrix,   "709")
    p_type     = Default (Jab,      "420")     # target YUV chroma subsampling
    kernel     = Default (kernel, "Didee")
    tv_in      = Default (tv_in,      !fs)
    tv_out     = Default (tv_out,    true)
    cplace     = Default (cplace,      "")
    b          = Default (b, -0.5)
    c          = Default (c, 0.25)             # Didée's Bicubic
    p          = Default (p,    9)

    Assert(IsVersionOrGreater(3,7,2),   "RGB_to_YUV: Update AviSynth+ version")
    Assert(isRGB(rgb) && IsPlanar(rgb), "RGB_to_YUV: Only Planar RGB format supported")

    p_type   = format_Fuzzy_Search (rgb, p_type, bi)
    matrix   = color_Fuzzy_Search (matrix)
    coef     = color_coef(mat=matrix[0])
    bc       = bicubic_coeffs(kernel)
    bc_b     = string(bc[1]>=-1?bc[0]:b)
    bc_c     = string(bc[1]>=-1?bc[1]:c)
    kernel   = bc[1]>=-1 ? "Bicubic" : LCase(kernel)

    p_type4  = p_type[1] == "444"
    p_type2  = p_type[1] == "422"
    p_type1  = p_type[1] == "411"
    p_type10 = p_type[1] == "410"

    w  = width (rgb)
    h  = height(rgb)
    nw = p_type4 ? w : p_type1 || p_type10 ? round(w/4.0) : round(w/2.0)
    nh = p_type4 ||    p_type1 || p_type2  ?            h : round(h/2.0)

    cplace  = chroma_placement(w, h, w, h, matrix[0], matrix[0], "RGB", "YUV"+p_type[1], "444", p_type[1], "center", cplace )

     p_type1             ? Assert(bi == 8,   "RGB_to_YUV: Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10, "RGB_to_YUV: Unsupported Pixel Type: YUV410")

                           Assert(h%2==0,    "RGB_to_YUV: Height is not mod2" )
    !p_type1 || !p_type4 ? Assert(w%2==0,    "RGB_to_YUV: Width is not mod2" )                 : nop()
     p_type1             ? Assert(w%4==0,    "RGB_to_YUV: Width is not mod4" )                 : nop()


    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)

    if (matrix[0]=="2020CL" || matrix[0]=="DCI-P3" || matrix[0]=="Display-P3") {

        Assert(false, "RGB_to_YUV: Use RGB_to_YcCbcCrc() function")

    } else {

        scale_y   = tv_in != tv_out ? tv_in ? 256/219. : 219/256. : 1.0
        scale_uv  = tv_in != tv_out ? tv_in ? 256/112. : 112/256. : 0.5

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y  *   coef[0]       m1 = scale_y  *   coef[1]         m2 = scale_y  *   coef[2]
        m3 = scale_uv * (-coef[0] / Kb) m4 = scale_uv * (-coef[1] / Kb)   m5 = scale_uv
                                        m7 = scale_uv * (-coef[1] / Kr)   m8 = scale_uv * (-coef[2] / Kr)

            rangeY_TV = scale_y ==219/256. ? "ymin +" : \
                        scale_y ==256/219. ? "ymin -" : ""
            rangeC_TV = bi < 32            ? "range_half +" : ""

        Y  = ex_dlut("x "+string(m0)+" * y "+string(m1)+" * + z "+string(m2)+" * + "+rangeY_TV+"", bi, false)
        Cb = ex_dlut("x "+string(m3)+" * y "+string(m4)+" * + z "+string(m5)+" * + "+rangeC_TV+"", bi, false)
        Cr = ex_dlut("x "+string(m5)+" * y "+string(m7)+" * + z "+string(m8)+" * + "+rangeC_TV+"", bi, false)

    }

    if (p_type4) {

        Expr(Rx, Gx, Bx, Y, Cb, Cr, optSingleMode=true, format=bi>16?"YUV444PS":"YUV444P"+string(bi))

    } else {

        Y  = Expr(Rx, Gx, Bx, Y,  optSingleMode=true)
        Cb = Expr(Rx, Gx, Bx, Cb, optSingleMode=true)
        Cr = Expr(Rx, Gx, Bx, Cr, optSingleMode=true)

        cplaceH = ",src_left="+string(cplace[0])
        cplaceV = ",src_top ="+string(cplace[1])

        # Although not optimal, technically YUV420 accepts odd size chroma planes
        resampler = FindStr(kernel, "lanczos")>0 && kernel!="lanczos4" || FindStr(kernel, "blackman")>0 || FindStr(kernel, "sinc")>0       ? \
                                         kernel + "Resize(" + String(nw) + "," + String(nh) + cplaceH + cplaceV +",taps=    int("+bc_b+"))": \
                    kernel == "nnedi3" ?    "nnedi3resize(" + String(nw) + "," + String(nh)                     + ")"                      : \
                    kernel == "bicubic"?   "BicubicResize(" + String(nw) + "," + String(nh) + cplaceH + cplaceV +",b="+bc_b+",c="+bc_c+")" : \
                    kernel == "gauss"  ?     "GaussResize(" + String(nw) + "," + String(nh) + cplaceH + cplaceV +",p=p)"                   : \
                                         kernel + "Resize(" + String(nw) + "," + String(nh) + cplaceH + cplaceV +")"

        Cb = p_type4 ? Cb : Eval("Cb." + resampler)
        Cr = p_type4 ? Cr : Eval("Cr." + resampler)

        CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+p_type[1]+p_type[2])
    }

    tv_in!=tv_out ? propSet("_ColorRange", tv_out ? 1 : 0) : last
                    propSet("_Matrix", matrix[3])
                    propSet("_Model",         5 ) }


# RGB' to YcCbcCrc 444 function (for Rec.2020CL)
function RGB_to_YcCbcCrc (clip RGB, clip "Gx", clip "Bx", string "matrix", string "EOTFi", float_array "coef", bool "tv_in", bool "tv_out", bool "Array") {

    isy  = isy(RGB)
    bi   = BitsPerComponent(RGB)
    fs   = propNumElements (RGB,"_ColorRange")  > 0 ? \
           propGetInt      (RGB,"_ColorRange") == 0 : true
    tr   = propNumElements (RGB,"_Transfer")    > 0 ? \
           propGetInt      (RGB,"_Transfer")   == 8 : false
    lut  = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
    mat  = Default (matrix, "709")
    trc  = Default (EOTFi, "1886")
    coef = Default (coef, color_coef(mat=mat))
    tvi  = Default (tv_in,    !fs)
    tvo  = Default (tv_out, false)
    arc  = Default (Array,    isy)
    trcl = tr ? "linear" : trc

    mat       = color_Fuzzy_Search(mat)
    s_gam     = moncurve_coef(trc)      # some values are getting crushed in the Rec709 transfer
    bi32      = bi == 32 ? "" : "range_half +"
    rangeC_PC = tvi      ? "range_half - range_max cmax cmin - / * range_half + " : ""
    rangeC_TV = tvo      ? "range_half + cmax cmin - range_max / * cmin + "       : bi32

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    B   = !isy ? clp[2] :      Bx

    clp = !isy ?          CCTF(RGB, trcl, true, tvi, false).ExtractClip() : nop()
    Rln = !isy ? clp[0] : CCTF(RGB, trcl, true, tvi, false)
    Gln = !isy ? clp[1] : CCTF(Gx,  trcl, true, tvi, false)
    Bln = !isy ? clp[2] : CCTF(Bx,  trcl, true, tvi, false)

    ca  = 1.0 + s_gam[1]
    cb  = 1.0 / s_gam[0]

    Pb  = 1 /  (2. * (ca*(1.0 - pow(coef[2], cb))))
    Pr  = 1 /  (2. * (ca*(1.0 - pow(coef[0], cb))))
    Nb  = 1 / (-2. * (ca*(1.0 - pow(coef[0] + coef[1], cb)) - 1.0))
    Nr  = 1 / (-2. * (ca*(1.0 - pow(coef[1] + coef[2], cb)) - 1.0))

    Y   = Expr(Rln, Gln, Bln, "x "+string(coef[0])+" * y "+string(coef[1])+" * + z "+string(coef[2])+" * + ")
    Yx  = CCTF(Y,  trc, false, false, false).propSet("_Matrix", mat[3]).propSet("_Model", 11)

    Cbc = Expr(B, Yx, ex_dlut(Format("x "+rangeC_PC+" y - A@ 0 <= A {Nb} * A {Pb} * ? "+rangeC_TV+" "), bi, true), lut=lut)
    Crc = Expr(R, Yx, ex_dlut(Format("x "+rangeC_PC+" y - A@ 0 <= A {Nr} * A {Pr} * ? "+rangeC_TV+" "), bi, true), lut=lut)
    Yc  = !tvo ?  Yx : CCTF(Y, trc, false, false, true)

    arc ? [Yc, Cbc, Crc] : CombinePlanes(Yc, Cbc, Crc, planes="YUV") }


# WIP. YcCbcCrc 444 to RGB' function (for Rec.2020CL)
function YcCbcCrc_to_RGB (clip YUV, clip "Cb", clip "Cr", string "matrix", string "EOTFi", float_array "coef", string "kernel", bool "tv_in", bool "tv_out", bool "Array") {

    isy  = isy(YUV)
    bi   = BitsPerComponent(YUV)
    fs   = propNumElements (YUV,"_ColorRange")  > 0 ? \
           propGetInt      (YUV,"_ColorRange") == 0 : false
    tr   = propNumElements (YUV,"_Transfer")    > 0 ? \
           propGetInt      (YUV,"_Transfer")   == 8 : false
    lut  = bi > 12 || isRunTime(YUV,false) ? 0 : 2
    mat  = Default (matrix, "709")
    trc  = Default (EOTFi, "1886")
    knn  = Default (kernel, "Blackman4")
    coef = Default (coef, color_coef(mat=mat))
    tvi  = Default (tv_in,    !fs)
    tvo  = Default (tv_out, false)
    arc  = Default (Array,    isy)
    trcl = tr ? "linear" : trc

    mat  = color_Fuzzy_Search(mat)
    Y444 = ConvertFormat(YUV,1,1,fmt_out="444",kernel_c=knn,tv_in=tvi,tv_out=tvi)

    clp  = !isy ? ExtractClip(Y444) : nop()
    Y    = !isy ? clp[0] :    YUV
    Cb   = !isy ? clp[1] :     Cb   # Need to scale up
    Cr   = !isy ? clp[2] :      Cr

    bi32m     = bi == 32 ? "" : "range_half -"
    bi32p     = bi == 32 ? "" : "range_half +"
    rangeC_PC = tvi ? ""+bi32m+" range_max cmax cmin - / *" : bi32m

    s_gam = moncurve_coef(trc)
    a = 1.0 + s_gam[1]
    b = 1.0 / s_gam[0]

    Pb =  2. * (a*(1.0 - pow(coef[2], b)))
    Pr =  2. * (a*(1.0 - pow(coef[0], b)))
    Nb = -2. * (a*(1.0 - pow(coef[0] + coef[1], b)) - 1.0)
    Nr = -2. * (a*(1.0 - pow(coef[1] + coef[2], b)) - 1.0)

    Y  = CCTF(Y,  trcl, true, tvi, false)

    Bx = Expr(Cb, Y, ex_dlut(Format("x "+rangeC_PC+" A@ 0 <= A {Nb} * y "+bi32m+" B@ + A {Pb} * B + ? "+bi32p), bi, true), lut=lut)
    Rx = Expr(Cr, Y, ex_dlut(Format("x "+rangeC_PC+" A@ 0 <= A {Nr} * y "+bi32m+" B@ + A {Pr} * B + ? "+bi32p), bi, true), lut=lut)

    Gx = Expr(Y, Bx, Rx, "x "+string(coef[2])+" y * - "+string(coef[0])+" z * - "+string(coef[1])+" / ", optSingleMode=true)

    if (arc) {

        R = CCTF(Rx,  trc, false, false, tvo).propSet("_Matrix", 0).propSet("_Model", 1)
        B = CCTF(Bx,  trc, false, false, tvo)
        G = CCTF(Gx,  trc, false, false, tvo)
        [R, G, B]

    } else {

        CombinePlanes(Rx, Gx, Bx, planes="RGB")
        CCTF(trc, false, false, tvo)
        propSet("_Matrix",        0)
        propSet("_Model",         1)          } }



# YCoCg, YCoCgR and YUVr compress better than plain YUV. YCoCg variants a tiny bit over YUVr, and YUVr and YCoCgR being losslessly reversible (RCT) with RGB
# These formats are ColorSpace and Chroma Subsampling independent, as well as signal range (full or legal), although specification defines it as full range.
# Originally called YCoCg, was later renamed and standardized to YCgCo, since the Co channel corresponds better to Cr from YCbCr

# RGB' to YCoCg/YCgCo 444 function
function RGB_to_YCoCg (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out", bool "Array") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    fs  = propNumElements (RGB,"_ColorRange")  > 0 ? \
          propGetInt      (RGB,"_ColorRange") == 0 : true
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
    tvi = Default (tv_in,    !fs)
    tvo = Default (tv_out, false) # The specification defines it with PC levels
    arc = Default (Array,    isy)

    RGB =  tvi ? SMPTE_legal   (RGB,false) : RGB
    clp = !isy ? ExtractClip   (RGB)       : nop()
    R   = !isy ? clp[0] : tvi ? RGB.SMPTE_legal(false) : RGB
    G   = !isy ? clp[1] :  tvi ? G. SMPTE_legal(false) :  G
    B   = !isy ? clp[2] :   tvi ? B.SMPTE_legal(false) :   B

    b32 = bi == 32 ? "" : "range_half +"

    rangeTV   = tvo ? " ymax ymin - range_max / * ymin +"                    : ""
    rangeC_TV = tvo ? " cmax cmin - range_max / * "+(bi==32 ? "" : "cmin +") : ""

    if (arc) {
        Y  = Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + "    +rangeTV,   bi, true), optSingleMode=true,  lut=  0).propSet("_Matrix", 2).propSet("_Model", 9)
        Cg = Expr(R, G, B, ex_dlut("y 0.5  * x z + 0.25 * - "+b32+rangeC_TV, bi, true), optSingleMode=true,  lut=  0)
        Co = Expr(R,    B, ex_dlut("x y - 0.5  *            "+b32+rangeC_TV, bi, true), optSingleMode=false, lut=lut)
        [Y, Cg, Co]

    } else {

        fmt = format_Fuzzy_Search(RGB, "YUV", bi)
        Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + "    +rangeTV,   bi, true),  \
                      ex_dlut("y 0.5  * x z + 0.25 * - "+b32+rangeC_TV, bi, true),  \
                      ex_dlut("x z - 0.5  *            "+b32+rangeC_TV, bi, true), format="YUV444"+fmt[2], optSingleMode=true)

        tvo ? propSet("_ColorRange", 1) : last
              propSet("_Matrix",     2)
              propSet("_Model",      9)      } }


# YCoCg 444 to RGB' function
function YCoCg_to_RGB (clip YCC, clip "Cg", clip "Co", bool "tv_in", bool "tv_out", bool "Array") {

    isy = isy(YCC)
    bi  = BitsPerComponent(YCC)
    fs  = propNumElements (YCC,"_ColorRange")  > 0 ? \
          propGetInt      (YCC,"_ColorRange") == 0 : true
    lut = bi > 12 || isRunTime(YCC,false) ? 0  : 2
    tvi = Default (tv_in,    !fs)
    tvo = Default (tv_out, false)
    arc = Default (Array,    isy)

    YCC =  tvi ? SMPTE_legal   (YCC,false) : YCC
    clp = !isy ? ExtractClip   (YCC)       : nop()
    Y   = !isy ? clp[0] : tvi ? YCC. SMPTE_legal(false)          : YCC
    Cg  = !isy ? clp[1] :  tvi ? Cg. SMPTE_legal(false,Y=1,UV=3) :  Cg
    Co  = !isy ? clp[2] :   tvi ? Co.SMPTE_legal(false,Y=1,UV=3) :   Co

    b32 = bi == 32 ? "" : "range_half -"

    rangeTV   = tvo ? " ymax ymin - range_max / * ymin +" : ""

    if (arc) {

        R = Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" + "+rangeTV, bi, true), optSingleMode=true,  lut=  0).propSet("_Matrix", 0).propSet("_Model", 1)
        G = Expr(Y, Cg,     ex_dlut("x y "+b32+" +"             +rangeTV, bi, true), optSingleMode=false, lut=lut)
        B = Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" - "+rangeTV, bi, true), optSingleMode=true,  lut=  0)
        [R, G, B]

    } else {

        fmt = format_Fuzzy_Search(YCC, "RGB", bi)
        Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" + "+rangeTV, bi, true),  \
                        ex_dlut("x y "+b32+" +             "+rangeTV, bi, true),  \
                        ex_dlut("x y "+b32+" - z "+b32+" - "+rangeTV, bi, true), format="RGB"+fmt[2], optSingleMode=true)

        tvo ? propSet("_ColorRange", 1) : last
              propSet("_Matrix",     0)
              propSet("_Model",      1)      } }


# RGB' to YCoCg RCT 444 function
function RGB_to_YCoCgR (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out", bool "Array") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    fs  = propNumElements (RGB,"_ColorRange")  > 0 ? \
          propGetInt      (RGB,"_ColorRange") == 0 : true
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
    tvi = Default (tv_in,    !fs)
    tvo = Default (tv_out, false) # The specification defines it with PC levels
    arc = Default (Array,    isy)

    RGB =  tvi ? SMPTE_legal(RGB,false) : RGB
    clp = !isy ? ExtractClip(RGB)       : nop()
    R   = !isy ? clp[0] : tvi ? RGB.SMPTE_legal(false) : RGB
    G   = !isy ? clp[1] :  tvi ? G. SMPTE_legal(false) :  G
    B   = !isy ? clp[2] :   tvi ? B.SMPTE_legal(false) :   B

    b32i = bi == 32 ? "" : "range_half +"
    b32f = bi == 32 ? "" : "range_half -"

    Co = Expr(R,      B, ex_dlut("x 0.5  * y 0.5  * - "+b32i,            bi, true), optSingleMode=false, lut=lut)
    Cg = Expr(Co, G,  B, ex_dlut("y z x "+b32f+" 0.5 * + - 0.5 * "+b32i, bi, true), optSingleMode=false, lut=  0)
    Y  = Expr(Co, Cg, B, ex_dlut("  z x "+b32f+" 0.5 * + y "+b32f+" +",  bi, true), optSingleMode=false, lut=  0).propSet("_Matrix", 2).propSet("_Model", 10)

    if (arc) {
        tvo ? CombinePlanes(Y, Cg, Co, planes="YUV").SMPTE_legal(true).ExtractClip() : [Y, Cg, Co]
    } else {
              CombinePlanes(Y, Cg, Co, planes="YUV")
        tvo ? SMPTE_legal(true) : last
              propSet("_Matrix",     2)
              propSet("_Model",     10)  } }


#  YCoCg RCT 444 to RGB' function
function YCoCgR_to_RGB (clip YCC, clip "Cg", clip "Co", bool "tv_in", bool "tv_out", bool "Array") {

    isy = isy(YCC)
    bi  = BitsPerComponent(YCC)
    fs  = propNumElements (YCC,"_ColorRange")  > 0 ? \
          propGetInt      (YCC,"_ColorRange") == 0 : true
    lut = bi > 12 || isRunTime(YCC,false) ? 0 : 2
    tvi = Default (tv_in,    !fs)
    tvo = Default (tv_out, false)
    arc = Default (Array,    isy)

    YCC =  tvi ? SMPTE_legal   (YCC,false) : YCC
    clp = !isy ? ExtractClip   (YCC)       : nop()
    Y   = !isy ? clp[0] : tvi ? YCC. SMPTE_legal(false)          : YCC
    Cg  = !isy ? clp[1] :  tvi ? Cg. SMPTE_legal(false,Y=1,UV=3) :  Cg
    Co  = !isy ? clp[2] :   tvi ? Co.SMPTE_legal(false,Y=1,UV=3) :   Co

    b32 = bi == 32 ? "" : "range_half -"

    rangeTV = tvo ? " ymax ymin - range_max / * ymin +" : ""
    rangePC = tvo ? " ymin - range_max ymax ymin - / *" : ""

    if (arc) {

        G = Expr(Y, Cg,     ex_dlut("y   "+b32+" Y@ 2 * x Y - +"     +rangeTV, bi, true), optSingleMode=false, lut=lut)
        B = Expr(Y, Cg, Co, ex_dlut("x y "+b32+" - z "+b32+" 0.5 * -"+rangeTV, bi, true), optSingleMode=true,  lut=  0)
        R = Expr(Co, B,     ex_dlut("y "+rangePC+" x "+b32+" 2 * +"  +rangeTV, bi, true), optSingleMode=false, lut=lut).propSet("_Matrix", 0).propSet("_Model", 1)
        [R, G, B]

    } else {

        fmt = format_Fuzzy_Search(YCC, "RGB", bi)
        Expr(Y, Cg, Co, ex_dlut("z   "+b32+" dup 0.5 * x y "+b32+" - swap - swap 2 * +"+rangeTV, bi, true),  \
                        ex_dlut("y   "+b32+" Y@ 2 * x Y - +"                           +rangeTV, bi, true),  \
                        ex_dlut("x y "+b32+" - z "+b32+" 0.5 * -"                      +rangeTV, bi, true), format="RGB"+fmt[2], optSingleMode=true)

        tvo ? propSet("_ColorRange", 1) : last
              propSet("_Matrix",     0)
              propSet("_Model",      1)      } }


# RGB' to YCbCr RCT 444 function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
function RGB_to_YUVr (clip RGB, clip "G", clip "B", bool "tv_in", bool "tv_out", bool "Array") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    fs  = propNumElements (RGB,"_ColorRange")  > 0 ? \
          propGetInt      (RGB,"_ColorRange") == 0 : true
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
    tvi = Default (tv_in,    !fs)
    tvo = Default (tv_out, false)
    arc = Default (Array,    isy)

    RGB =  tvi ? SMPTE_legal   (RGB,false) : RGB
    clp = !isy ? ExtractClip   (RGB)       : nop()
    R   = !isy ? clp[0] : tvi ? RGB.SMPTE_legal(false) : RGB
    G   = !isy ? clp[1] :  tvi ? G. SMPTE_legal(false) :  G
    B   = !isy ? clp[2] :   tvi ? B.SMPTE_legal(false) :   B

    b32 = bi == 32 ? "" : "range_half +"

    rangeTV   = tvo ? " ymax ymin - range_max / * ymin +"                    : ""
    rangeC_TV = tvo ? " cmax cmin - range_max / * "+(bi==32 ? "" : "cmin +") : ""

    if (arc) {
        Y  = Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + "+rangeTV, bi, true), optSingleMode=true,  lut=  0).propSet("_Matrix", 2).propSet("_Model", 5)
        Cb = Expr(   G, B, ex_dlut("y x - "+b32+rangeC_TV,             bi, true), optSingleMode=false, lut=lut)
        Cr = Expr(R, G,    ex_dlut("x y - "+b32+rangeC_TV,             bi, true), optSingleMode=false, lut=lut)
        [Y, Cb, Cr]

    } else {

        fmt = format_Fuzzy_Search(RGB, "YUV", bi)
        Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + "+rangeTV, bi, true),  \
                      ex_dlut("z y - "+b32+rangeC_TV,             bi, true),  \
                      ex_dlut("x y - "+b32+rangeC_TV,             bi, true), format="YUV444"+fmt[2], optSingleMode=true)

        tvo ? propSet("_ColorRange", 1) : last
              propSet("_Matrix",     2)
              propSet("_Model",      5)      } }


# YCbCr RCT 444 to RGB' function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
function YUVr_to_RGB (clip YUV, clip "Cb", clip "Cr", bool "tv_in", bool "tv_out", bool "Array") {

    isy = isy(YUV)
    bi  = BitsPerComponent(YUV)
    fs  = propNumElements (YUV,"_ColorRange")  > 0 ? \
          propGetInt      (YUV,"_ColorRange") == 0 : true
    lut = bi > 12 || isRunTime(YUV,false) ? 0 : 2
    tvi = Default (tv_in,    !fs)
    tvo = Default (tv_out, false)
    arc = Default (Array,    isy)

    YUV =  tvi ? SMPTE_legal   (YUV,false) : YUV
    clp = !isy ? ExtractClip   (YUV)       : nop()
    Y   = !isy ? clp[0] : tvi ? YUV. SMPTE_legal(false)          : YUV
    Cb  = !isy ? clp[1] :  tvi ? Cb. SMPTE_legal(false,Y=1,UV=3) :  Cb
    Cr  = !isy ? clp[2] :   tvi ? Cr.SMPTE_legal(false,Y=1,UV=3) :   Cr

    rangeTV = tvo ? " ymax ymin - range_max / * ymin +" : ""

    b32  = bi == 32 ? "" : "range_half -"
    b32h = bi == 32 ? "" : "range_half 0.5 * +"

        G = Expr(Y, Cb, Cr, ex_dlut("x y z + 0.25 * - "+b32h, bi, true), optSingleMode=true,  lut=  0)

    if (arc) {

        R = Expr(G,     Cr, ex_dlut("x y + "+b32+rangeTV,     bi, true), optSingleMode=false, lut=lut).propSet("_Matrix", 0).propSet("_Model", 1)
        B = Expr(G, Cb,     ex_dlut("x y + "+b32+rangeTV,     bi, true), optSingleMode=false, lut=lut)
        G = ex_lut(G,"x "+rangeTV)
        [R, G, B]

    } else {

        fmt = format_Fuzzy_Search(YUV, "RGB", bi)
        Expr(G, Cb, Cr, ex_dlut("x z + "+b32+rangeTV,         bi, true), ex_dlut("x "+rangeTV, bi, true), \
                        ex_dlut("x y + "+b32+rangeTV,         bi, true), format="RGB"+fmt[2])

        tvo ? propSet("_ColorRange", 1) : last
              propSet("_Matrix",     0)
              propSet("_Model",      1)      } }




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
function RGB_to_OPP (clip RGB, clip "G", clip "B", bool "Array") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)
    lut = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
    arc = Default (Array,  isy)

    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    b32 = bi == 32 ? "" : "range_half +"

        Os  = ex_dlut(Format("x y z + + 0.333333333 *")         , bi, true)
        P1s = ex_dlut(Format("x "+(isy?"y":"z")+" - 0.5 * "+b32), bi, true)
        P2s = ex_dlut(Format("x z + 0.25 * y 0.5 * - "     +b32), bi, true)

    if (arc) {

        O  = Expr(R, G, B, Os,  optSingleMode=false, lut=  0).propSet("_Matrix",2).propSet("_Model",12)
        P1 = Expr(R,    B, P1s, optSingleMode=false, lut=lut)
        P2 = Expr(R, G, B, P2s, optSingleMode=false, lut=  0)
        [O, P1, P2]

    } else { Expr(R, G, B, Os, P1s, P2s, format="YUV444"+format_Fuzzy_Search(RGB,"YUV",bi)[2], optSingleMode=true)
             propSet("_Matrix",      2)
             propSet("_Model",      12) } }


# https://github.com/HomeOfVapourSynthEvolution/VapourSynth-BM3D/blob/7b3d8dd32e4aa4d962cf15d75d191b465682ed42/include/Specification.h#L176
function OPP_to_RGB (clip OPP, clip "P1", clip "P2", bool "Array") {

    isy = isy(OPP)
    bi  = BitsPerComponent(OPP)
    lut = bi > 12 || isRunTime(OPP,false) ? 0 : 2
    arc = Default (Array,  isy)

    clp = !isy ? ExtractClip(OPP) : nop()
    O   = !isy ? clp[0] :    OPP
    P1  = !isy ? clp[1] :     P1
    P2  = !isy ? clp[2] :      P2

    b32 = bi == 32 ? "" : "range_half -"

        Rs = ex_dlut(Format("x y "+b32+" + z "+b32+" 0.666666666 * +")    , bi, true)
        Gs = ex_dlut(Format("x "+(isy?"y":"z")+" "+b32+" 1.333333333 * -"), bi, true)
        Bs = ex_dlut(Format("x z "+b32+" 0.666666666 * + y "+b32+" -")    , bi, true)

    if (arc) {

        R = Expr(O, P1, P2, Rs, optSingleMode=false, lut=  0).propSet("_Matrix", 0).propSet("_Model", 1)
        G = Expr(O,     P2, Gs, optSingleMode=false, lut=lut)
        B = Expr(O, P1, P2, Bs, optSingleMode=false, lut=  0)
        [R, G, B]

    } else { Expr(O, P1, P2, Rs, Gs, Bs, format="RGB"+format_Fuzzy_Search(OPP,"RGB",bi)[2], optSingleMode=true)
             propSet("_Matrix",     0)
             propSet("_Model",      1) } }


# XYZ to YDzDx (applied on XYZ in SMPTE ST 2084 gamma space)
function XYZ_to_YDzDx (clip XYZ, clip "Y", clip "Z", bool "Array") {

    isy = isy(XYZ)
    bi  = BitsPerComponent(XYZ)
    lut = bi > 12 || isRunTime(XYZ,!isy) ? 0 : 2
    arc = Default (Array,  isy)

    clp = !isy ? ExtractClip(XYZ) : nop()
    X   = !isy ? clp[0] :    XYZ
    Y   = !isy ? clp[1] :     Y
    Z   = !isy ? clp[2] :      Z

    b32 = bi == 32 ? "" : "range_half +"

    cf1   = 2763/2800.
    cf2   = 2741/2763.

    if (arc) {

        Dz = Expr(   Y, Z, ex_dlut(Format("{cf1} y "+b32+" * x  - "), bi, true), optSingleMode=false, lut=lut)
        Dx = Expr(X, Y,    ex_dlut(Format("x "+b32+"  {cf2} y * - "), bi, true), optSingleMode=false, lut=lut)
        Y  = Y.propSet("_Matrix", 13).propSet("_Model", 15)
        [Y, Dz, Dx]

    } else {

        Expr(Y, X, Z, "", ex_dlut(Format("{cf1} z "+b32+" * x  - "), bi, true),  \
                          ex_dlut(Format("y "+b32+"  {cf2} x * - "), bi, true), format=PixelType(XYZ))
        propSet("_Matrix",     13)
        propSet("_Model",      15) } }


# YDzDx to XYZ
function YDzDx_to_XYZ (clip YDzDx, clip "Dz", clip "Dx", bool "Array") {

    isy = isy(YDzDx)
    bi  = BitsPerComponent(YDzDx)
    lut = bi > 12 || isRunTime(YDzDx,!isy) ? 0 : 2
    arc = Default (Array,    isy)

    clp = !isy ? ExtractClip(YDzDx) : nop()
    Y   = !isy ? clp[0] :    YDzDx
    Dz  = !isy ? clp[1] :     Dz
    Dx  = !isy ? clp[2] :      Dx

    b32 = bi == 32 ? "" : "range_half -"

    cf1   = 2800/2763.
    cf2   = 2763/2741.

    if (arc) {

        X = Expr(Dx, Y, ex_dlut(Format("x "+b32+" y {cf2} * + "), bi, true), optSingleMode=false, lut=lut).propSet("_Matrix", 0).propSet("_Model", 0)
        Z = Expr(Dz, Y, ex_dlut(Format("x "+b32+" y {cf1} * + "), bi, true), optSingleMode=false, lut=lut)
        [X, Y, Z]

    } else {

        Expr(Dx, Y, Dz, ex_dlut(Format("x "+b32+" y {cf1} * + "), bi, true), "",  \
                        ex_dlut(Format("z "+b32+" y {cf2} * + "), bi, true), format=PixelType(YDzDx))
        propSet("_Matrix",     0)
        propSet("_Model",      0) } }


# XYZ to CIE Lab -D65 based- (process in linear space) (float bitdepth required as some values overflow)
# CIELAB is perceptually uniform but only at low frequencies as it is based on 2 degrees of uniform color circles.
function XYZ_to_Lab (clip XYZ, clip "Y", clip "Z", bool "Jch", bool "Array") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    iRT  = isRunTime(XYZ,!isy)
    lut1 = bi == 32 || iRT ? 0 : 1
    lut2 = bi  > 12 || iRT ? 0 : 2
    cy   = Default (Jch,   false)
    arc  = Default (Array,   isy)

    clp  = !isy ? ExtractClip(XYZ) : nop()
    X    = !isy ? clp[0] :    XYZ
    Y    = !isy ? clp[1] :     Y
    Z    = !isy ? clp[2] :      Z

    ep    = pow(6. / 29,  3)                        # 0.00885645167903563081717167575546 (or 216 / 24389.)
    coef  = pow(6. / 29,  2) *    3                 # 0.12841854934601664684898929845422 (or 108 / 841)
    coefr = pow(6. / 29, -2) * (1/3.)               # 7.78703703703703703703703703703703 (or 841 / 108)  reciprocal of above
    rW    = [1.052134065421009,1,0.918343935177561] # Reference White (Tristimulus Values): Normalization to Y=100 of reciprocal of illuminant -D65- (and divided by 100)

    L = Expr(Y,               Format("x                        {ep} > x 0.333333333 ^ x {coefr} * 4 29 / + ? 1.16 * 0.16 -"),     optSingleMode=false, lut=lut1).propSet("_Matrix", 2).propSet("_Model", 27)
    a = Expr(X, Y,    ex_dlut(Format("x "+string(rW[0])+" * X@ {ep} > X 0.333333333 ^ X {coefr} * 4 29 / + ?
                                      y                        {ep} > y 0.333333333 ^ y {coefr} * 4 29 / + ? - 5 * "), bi, true), optSingleMode=true,  lut=lut2)
    b = Expr(   Y, Z, ex_dlut(Format("x                        {ep} > x 0.333333333 ^ x {coefr} * 4 29 / + ?
                                      y "+string(rW[2])+" * Z@ {ep} > Z 0.333333333 ^ Z {coefr} * 4 29 / + ? - 2 * "), bi, true), optSingleMode=true,  lut=lut2)

    isy ? [L, a, b] : CombinePlanes(L, a, b, planes="RGB") }


# CIE Lab to XYZ -D65 based- (float bitdepth required as some values overflow)
function Lab_to_XYZ (clip Lab, clip "a", clip "b", bool "Jch", bool "Array") {

    isy  = isy(Lab)
    bi   = BitsPerComponent(Lab)
    iRT  = isRunTime(Lab,!isy)
    lut1 = bi == 32 || iRT ? 0 : 1
    lut2 = bi  > 12 || iRT ? 0 : 2
    cy   = Default (Jch,    false)
    arc  = Default (Array,    isy)

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

    X = Expr( L, a, Format("x 0.16 + 0.8620689656 * y 0.2 * + X@ {ep} > X 3 ^ X 4 29 / - {coef} * ? "+string(rW[0])+" *"), optSingleMode=false, lut=lut2).propSet("_Matrix", 0).propSet("_Model", 0)
    Y = Expr( L,    Format("x 0.16 + 0.8620689656 *           Y@ {ep} > Y 3 ^ Y 4 29 / - {coef} * ?                    "), optSingleMode=false, lut=lut1)
    Z = Expr( L, b, Format("x 0.16 + 0.8620689656 * y 0.5 * - Z@ {ep} > Z 3 ^ Z 4 29 / - {coef} * ? "+string(rW[2])+" *"), optSingleMode=false, lut=lut2)

    isy ? [X, Y, Z] : CombinePlanes(X, Y, Z, planes="RGB") }



# Only works in 32-bit float (for the time being)
function XYZ_to_Yxy (clip XYZ, clip "Y", clip "Z", bool "Array") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    arc  = Default (Array,  isy)

    clp  = !isy ? ExtractClip(XYZ) : nop()
    X    = !isy ? clp[0] :    XYZ
    Y    = !isy ? clp[1] :     Y
    Z    = !isy ? clp[2] :      Z

    if (arc) {
        xl = Expr(X, Y, Z, "x 0 <= 0.3805 x dup y z + + / ?",  optSingleMode=false)
        yl = Expr(X, Y, Z, "y 0 <= 0.3769 y dup x z + + / ?",  optSingleMode=false)
        Y  = Y.propSet("_Matrix", 0).propSet("_Model", 23)
        [Y, xl, yl]

    } else {

        Expr(X, Y, Z, "y", "x 0 <= 0.3805 x dup y z + + / ?",\
                           "y 0 <= 0.3769 y dup x z + + / ?",  optSingleMode=true, format=PixelType(XYZ))
        propSet("_Matrix", 2)
        propSet("_Model",  23) } }


# Only works in 32-bit float
function Yxy_to_XYZ (clip Yxy, clip "x", clip "y", bool "Array") {

    isy  = isy(Yxy)
    bi   = BitsPerComponent(Yxy)
    arc  = Default (Array,  isy)

    clp  = !isy ? ExtractClip(Yxy) : nop()
    Yb   = !isy ? clp[0] :    Yxy
    xl   = !isy ? clp[1] :     x
    yl   = !isy ? clp[2] :      y

    if (arc) {

        X = Expr(Yb, xl, yl, "y z / x *",                optSingleMode=false).propSet("_Matrix", 0).propSet("_Model", 0)
        Z = Expr(Yb, xl, yl, "y z / x * Y@ y / Y - x -", optSingleMode=false)
        [X, Yb, Z]

    } else {

            Expr(Yb, xl, yl, "y z / x *               ", \
                             "      x                 ", \
                             "y z / x * Y@ y / Y - x -", optSingleMode=true, format=PixelType(Yxy))
            propSet("_Matrix", 0)
            propSet("_Model",  0) } }



# XYZ to CIE Luv/Duv -D65 based- (process in linear space) (32-bit float recommended)
function XYZ_to_Luv (clip XYZ, clip "Y", clip "Z", bool "Jch", bool "Duv", bool "Array") {

    isy = isy(XYZ)
    bi  = BitsPerComponent(XYZ)
    lut = bi == 32 || isRunTime(XYZ,!isy) ? 0 : 1
    cy  = Default (Jch,    false)
    uv  = Default (Duv,    false)
    arc = Default (Array,    isy)

    clp = !isy ? ExtractClip(XYZ) : nop()
    X   = !isy ? clp[0] :    XYZ
    Y   = !isy ? clp[1] :     Y
    Z   = !isy ? clp[2] :      Z

    b32   = bi == 32 ? "" : "range_half +"

    ep    = 216 / 24389.
    kappa = 24389 / 27.
    c     = 1 / 0.62

    rW    = [95.0449218275099, 100., 108.8916648430471]

    detu  = (4 * rW[0] / (rW[0] + 15 * rW[1] + 3 * rW[2]))
    detv  = (9 * rW[1] / (rW[0] + 15 * rW[1] + 3 * rW[2]))
    duv   = uv ? Format(" {c} * ") : ""

    L = Expr(Y,                  Format("x {ep} > x 0.333333333 ^ 116 * 16 - x {kappa} * ? "),               optSingleMode=false, lut=lut).propSet("_Matrix", 2).propSet("_Model", cy ? 30 : 29)
    u = Expr(X, Y, Z, L, ex_dlut(Format("x 4 * x y 15 * + z 3 * + / {detu} - a 13 * * "+duv+b32), bi, true), optSingleMode=true,  lut=  0)
    v = Expr(X, Y, Z, L, ex_dlut(Format("x 9 * x y 15 * + z 3 * + / {detv} - a 13 * * "+duv+b32), bi, true), optSingleMode=true,  lut=  0)

    isy ? [L, u, v] : CombinePlanes(L, u, v, planes="RGB") }


# https://www.brucelindbloom.com/index.html?Eqn_Luv_to_XYZ.html
# CIE Luv to XYZ (32-bit float recommended)
function Luv_to_XYZ (clip Luv, clip "u", clip "v", bool "Jch", bool "Duv", bool "Array") {

    isy = isy(Luv)
    bi  = BitsPerComponent(Luv)
    lut = bi == 32 || isRunTime(Luv,!isy) ? 0 : 1
    cy  = Default (Jch,    false)
    uv  = Default (Duv,    false)
    arc = Default (Array,    isy)

    clp = !isy ? ExtractClip(Luv) : nop()
    L   = !isy ? clp[0] :    Luv
    u   = !isy ? clp[1] :     u
    v   = !isy ? clp[2] :      v

    b32   = bi == 32 ? "" : "range_half -"

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
                                    y 52 * A {detu} * z "+duv+b32+" + / 1 - 0.333333333 * 0.333333333 + / "),  optSingleMode=true,  lut=  0).propSet("_Matrix", 0).propSet("_Model", 0)
    Z = Expr(X, Y, L, u,    Format("z 52 * z 13 * {detu} * a "+duv+b32+" + / 1 - 0.333333333 * x * y 5 * - "), optSingleMode=true,  lut=  0)

    isy ? [X, Y, Z] : CombinePlanes(X, Y, Z, planes="RGB") }


# WIP. Only works in 32-bit float (correct? grey should output [0, 1, 0.935669])
# Jyrki Alakuijala: "CIELAB is perceptually uniform but only at low frequencies as it is based on 2 degrees of uniform color circles.
# ...At high spatial frequencies something like JPEG XL's XYB space will be perceptually more meaningful"
function XYZ_to_XYB (clip XYZ, clip "Y", clip "Z", bool "Array") {

    isy  = isy(XYZ)
    bi   = BitsPerComponent(XYZ)
    arc  = Default (Array,  isy)

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

    X = DotClipA(XYZa,[M[0],M[3],M[6]]).propSet("_Matrix", 2).propSet("_Model", 40)
    Y = DotClipA(XYZa,[M[1],M[4],M[7]])
    B = DotClipA(XYZa,[M[2],M[5],M[8]])

    if (arc) { [X, Y, B] } else {

        MatrixClip(XYZ, M)
        propSet("_Matrix", 2)
        propSet("_Model",  40) } }


# WIP. Only works in 32-bit float
function XYB_to_XYZ (clip XYB, clip "Y", clip "B", bool "Array") {

    isy  = isy(XYB)
    bi   = BitsPerComponent(XYB)
    arc  = Default (Array,  isy)

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

    X = DotClipA(XYBa,[M[0],M[3],M[6]]).propSet("_Matrix", 0).propSet("_Model", 0)
    Y = DotClipA(XYBa,[M[1],M[4],M[7]])
    Z = DotClipA(XYBa,[M[2],M[5],M[8]])

    if (arc) { [X, Y, Z] } else {

        MatrixClip(XYB, M)
        propSet("_Matrix", 0)
        propSet("_Model",  0) } }


# RGB' to HSV
function RGB_to_HSV (clip RGB, clip "G", clip "B", bool "tv_range", bool "Array") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    tv  = Default (tv_range, false)
    arc = Default (Array,      isy)

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

    if (arc) {

        S = Expr(R, G, B, V, Ss, optSingleMode=false)
        H = Expr(R, G, B, V, Hs, optSingleMode=true).propSet("_Matrix", 2).propSet("_Model", 25)
        [H, S, V]

    } else { Expr(R, G, B, V, Hs, Ss, "a", format=PixelType(RGB), optSingleMode=true)
             propSet("_Matrix",     2)
             propSet("_Model",      25) } }


# HSV to RGB'
function HSV_to_RGB (clip HSV, clip "S", clip "V", bool "tv_range", bool "Array") {

    isy = isy(HSV)
    bi  = BitsPerComponent(HSV)

    tv  = Default (tv_range, false)
    arc = Default (Array,      isy)

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

    if (arc) {

        R = Expr(H, S, V, Rs, optSingleMode=false).propSet("_Matrix", 0).propSet("_Model", 1)
        G = Expr(H, S, V, Gs, optSingleMode=false)
        B = Expr(H, S, V, Bs, optSingleMode=false)
        [R, G, B]

    } else { Expr(H, S, V, Rs, Gs, Bs, format=PixelType(HSV), optSingleMode=true)
             propSet("_Matrix",     0)
             propSet("_Model",      1) } }


# RGB linear to IPT -requires D65- (original PT range scaled from -1 +1 to 0 +1)
function RGB_to_IPT (clip RGB, clip "G", clip "B", bool "Jch", string "matrix", bool "Array", bool "fulls") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    mat = Default (matrix, "709")
    cy  = Default (Jch,    false)    # enable to convert to JCh (cylindrical IPT) in the range 0 to 1.
    fs  = Default (fulls,   true)
    arc = Default (Array,    isy)

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
        I   = isy ? Expr(L,M,S, Is, optSingleMode=true).propSet("_Matrix", 2).propSet("_Model", cy ? 18 : 17) : nop()

    if (!cy) {

        Ps  = " x "+b32d+" "+string(IPT[1])+" * y "+b32d+" "+string(IPT[4])+" * + z "+b32d+" "+string(IPT[7])+" * + 1 + 0.5 *"+b32m
        Ts  = " x "+b32d+" "+string(IPT[2])+" * y "+b32d+" "+string(IPT[5])+" * + z "+b32d+" "+string(IPT[8])+" * + 1 + 0.5 *"+b32m

        if (arc) {

            P  = Expr(L,M,S, Ps, optSingleMode=true)
            T  = Expr(L,M,S, Ts, optSingleMode=true)
            [I, P, T]

        } else { Expr(L,M,S, Is, Ps, Ts, format=PixelType(RGB), optSingleMode=true)
                 propSet("_Matrix",     2)
                 propSet("_Model",      17) }

    } else {

        Cs  = " x "+b32d+" X@ "+string(IPT[1])+" * y "+b32d+" Y@ "+string(IPT[4])+" * + z "+b32d+" Z@ "+string(IPT[7])+" * + dup *
                X             "+string(IPT[2])+" * Y             "+string(IPT[5])+" * + Z             "+string(IPT[8])+" * + dup * + sqrt pi *"+b32m
        hs  = " x "+b32d+" X@ "+string(IPT[1])+" * y "+b32d+" Y@ "+string(IPT[4])+" * + z "+b32d+" Z@ "+string(IPT[7])+" * +
                X             "+string(IPT[2])+" * Y             "+string(IPT[5])+" * + Z             "+string(IPT[8])+" * + swap atan2 pi + pi 2 * /"+b32m

        if (arc) {

            C  = Expr(L,M,S, Cs, optSingleMode=true)  # maybe normalize with 4.956244 instead
            h  = Expr(L,M,S, hs, optSingleMode=true)
            [I, C, h]

        } else { Expr(L,M,S, Is, Cs, hs, format=PixelType(RGB), optSingleMode=true)
                 propSet("_Matrix",     2)
                 propSet("_Model",      18) } } }



function IPT_to_RGB (clip IPT, clip "P", clip "T", bool "Jch", string "matrix", bool "Array", bool "fulls") {

    isy = isy(IPT)
    bi  = BitsPerComponent(IPT)

    mat = Default (matrix, "709")
    cy  = Default (Jch,      false)   # enable to convert from Jch (cylindrical IPT) in the range 0 to 1.
    fs  = Default (fulls,     true)
    arc = Default (Array,      isy)

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

    if (arc) {

        R = Expr(L,M,S, Rs, optSingleMode=false).propSet("_Matrix", 0).propSet("_Model", 1)
        G = Expr(L,M,S, Gs, optSingleMode=false)
        B = Expr(L,M,S, Bs, optSingleMode=false)
        [R, G, B]

    } else { Expr(L,M,S, Rs, Gs, Bs, format=PixelType(IPT), optSingleMode=true)
             propSet("_Matrix",     0)
             propSet("_Model",      1) } }



# RGB linear to Oklab -requires D65- (original 'ab' range scaled from -1 +1 to 0 +1)
# By the spec, OkLab can be gamma encoded with a cube root (ie. OkLab^1/3)
# OkLab Delta is simply the Euclidean distance.
function RGB_to_Oklab (clip RGB, clip "G", clip "B", bool "Jch", string "matrix", bool "Array", bool "fulls") {

    isy = isy(RGB)
    bi  = BitsPerComponent(RGB)

    mat = Default (matrix, "709")
    cy  = Default (Jch,      false)    # enable to convert to Oklch (cylindrical Oklab) in the range 0 to 1.
    fs  = Default (fulls,     true)
    arc = Default (Array,      isy)

    mat = color_Fuzzy_Search(mat)
    clp = !isy ? ExtractClip(RGB) : nop()
    R   = !isy ? clp[0] :    RGB
    G   = !isy ? clp[1] :     G
    B   = !isy ? clp[2] :      B

    # Oklab's LMS matrix
    M1  =  XYZ_to_LMS(RGB,"Oklab",true,false)

    # From Oklab's LMS to Lab
    M2  = [0.2104542553,  0.7936177850, -0.0040720468, \
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
        Lk  = isy ? Expr(L,M,S, Ls, optSingleMode=true).propSet("_Matrix",2).propSet("_Model", cy ? 38 : 37) : nop()

    if (!cy) {

        as  = " x "+b32d+" "+string(M2[1])+" * y "+b32d+" "+string(M2[4])+" * + z "+b32d+" "+string(M2[7])+" * + 1 + 0.5 *"+b32m
        bs  = " x "+b32d+" "+string(M2[2])+" * y "+b32d+" "+string(M2[5])+" * + z "+b32d+" "+string(M2[8])+" * + 1 + 0.5 *"+b32m

        if (arc) {

            a   = Expr(L,M,S, as, optSingleMode=true)
            b   = Expr(L,M,S, bs, optSingleMode=true)
            [Lk, a, b]

        } else { Expr(L,M,S, Ls, as, bs, format=PixelType(RGB), optSingleMode=true)
                 propSet("_Matrix",      2)
                 propSet("_Model",      37) }

    } else {

        Cs  = " x "+b32d+" X@ "+string(M2[1])+" * y "+b32d+" Y@ "+string(M2[4])+" * + z "+b32d+" Z@ "+string(M2[7])+" * + dup *
                X             "+string(M2[2])+" * Y             "+string(M2[5])+" * + Z             "+string(M2[8])+" * + dup * + sqrt pi *"+b32m
        hs  = " x "+b32d+" X@ "+string(M2[1])+" * y "+b32d+" Y@ "+string(M2[4])+" * + z "+b32d+" Z@ "+string(M2[7])+" * +
                X             "+string(M2[2])+" * Y             "+string(M2[5])+" * + Z             "+string(M2[8])+" * + swap atan2 pi + pi 2 * /"+b32m

        if (arc) {

            C  = Expr(L,M,S, Cs, optSingleMode=true)
            h  = Expr(L,M,S, hs, optSingleMode=true)
            [Lk, C, h]

        } else { Expr(L,M,S, Ls, Cs, hs, format=PixelType(RGB), optSingleMode=true)
                 propSet("_Matrix",      2)
                 propSet("_Model",      38) } } }



function Oklab_to_RGB (clip Lab, clip "a", clip "b", bool "Jch", string "matrix", bool "Array", bool "fulls") {

    isy = isy(Lab)
    bi  = BitsPerComponent(Lab)

    mat = Default (matrix, "709")
    cy  = Default (Jch,      false)   # enable to convert from OkLch (cylindrical OkLab) in the range 0 to 1.
    fs  = Default (fulls,     true)
    arc = Default (Array,      isy)

    mat = color_Fuzzy_Search(mat)
    clp = !isy ? ExtractClip(Lab) : nop()
    Lk  = !isy ? clp[0] :    Lab
    a   = !isy ? clp[1] :     a
    b   = !isy ? clp[2] :      b

    # Oklab's LMS matrix
    M1  =  XYZ_to_LMS(Lab,"Oklab",true,false)

    M2  = [0.2104542553,  0.7936177850, -0.0040720468, \
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

    if (arc) {

        R = Expr(L,M,S, Rs, optSingleMode=true).propSet("_Matrix", 0).propSet("_Model", 1)
        G = Expr(L,M,S, Gs, optSingleMode=true)
        B = Expr(L,M,S, Bs, optSingleMode=true)
        [R, G, B]

    } else { Expr(L,M,S, Rs, Gs, Bs, format=PixelType(Lab), optSingleMode=true)
             propSet("_Matrix",     0)
             propSet("_Model",      1) } }



# RGB linear to ICtCp PQ. HDR version of YcCbcCrc (aka YCbCr Constant Luminance)
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
#     EOTFi_PQ(10000)                       # Reconstitute gamma (until polynomial reshaping is implemented for DVp5 or MMR for DVp8)
function RGB_to_ICtCp (clip rgb, string "matrix", int "MasterLevel", bool "DoVi") {

    fs     = propNumElements (rgb,"_ColorRange")  > 0 ? \
             propGetInt      (rgb,"_ColorRange") == 0 : true
    bi     = BitsPerComponent(rgb)
    mat    = Default (matrix, "709")
    mat    = color_Fuzzy_Search(mat)
    props  = color_propGet(rgb,mat[4])

    mat    = Defined (matrix) ? mat[0] : color_propGet(rgb)[2]
    PL     = Default (MasterLevel, 10000) # Max Mastering Level in Nits (1000 to 10000)
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

    rgb = rgb.ConvertBits(32,fulls=fs,fulld=true)
    LMS = MatrixClip(rgb, MatrixTranspose(RtL), switch=false)

    LMS_gam = EOTFi_PQ(LMS,PL)

    # Skin tones alignment
    alpha = 1.134464
    cosa = cos(alpha)
    sina = sin(alpha)
    rot   = [ 1,    0,     0, \
              0, cosa, -sina, \
              0, sina,  cosa]

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

    MatrixClip (LMS_gam, MatrixTranspose(DoVi ? IPT : fit), switch=true)
    ConvertBits(bi,dither=1,fulls=true,fulld=fs)
    propSet("_Transfer",           16)
    propSet("_Matrix", DoVi ?  2 : 14)
    propSet("_Model",  DoVi ? 22 : 21) }


# ICtCp PQ to RGB linear
function ICtCp_to_RGB (clip ictcp, string "matrix", int "MasterLevel", bool "DoVi") {

    fs     = propNumElements (ictcp,"_ColorRange")  > 0 ? \
             propGetInt      (ictcp,"_ColorRange") == 0 : true
    bi     = BitsPerComponent(ictcp)
    mat    = Default (matrix, "709")
    mat    = color_Fuzzy_Search(mat)
    props  = color_propGet(ictcp,mat[4])

    mat    = Defined (matrix) ? mat[0] : color_propGet(ictcp)[2]
    PL     = Default (MasterLevel, 10000) # Max Mastering Level in Nits (1000 to 10000)
    DV     = Default (DoVi, false)        # Set to true for IPTPQc2

    ictcp
    # ICtCp to LMS joint matrix
    LMS  = [ 1,  0.008607,  0.111033, \
             1, -0.008607, -0.111033, \
             1,  0.560046, -0.320632]

    # IPTPQc2 to LMS joint matrix
    mul  =       DV ? 2 : 1    # undo reshaping. Read from RPU flag
    LMS5 = [ 1,  mul* 0.097600, mul* 0.205200, \
             1,  mul*-0.113900, mul* 0.133200, \
             1,  mul* 0.032600, mul*-0.676900]

    ictcp     = ictcp.ConvertBits(32,fulls=fs,fulld=true)
    LMS       = MatrixClip(ictcp, MatrixTranspose(DoVi ? LMS5 : LMS), switch=!isRGB(ictcp)) # Switch=true because ICtCp is packed into YCbCr format
    LMS_gam   = EOTF_PQ(LMS,PL)

    # Crosstalk 4% for ICtCp, 2% for Dolby Vision (IPTPQc2)
    xt        =       DV ? 0.02 : 0.04
    Crosstalk = [ 1-2*xt,     xt,     xt, \
                      xt, 1-2*xt,     xt, \
                      xt,     xt, 1-2*xt]

    LMS = XYZ_to_LMS("HPE",       list=true)
    LMX = MatrixDot(Crosstalk, LMS)
    RGB = XYZ_to_RGB(mat,props[3],list=true)
    LtR = MatrixDot(MatrixTranspose(MatrixInvert(LMX)), RGB) # LMS to RGB joint matrix

    MatrixClip(LMS_gam, LtR, switch=false)
    ConvertBits(bi,dither=1,fulls=true,fulld=fs)
    propSet("_Transfer",   8)
    propSet("_Matrix",     0)
    propSet("_Model",      1) }



# RGB linear to XYZ
function RGB_to_XYZ (clip rgb, string cspace, val "illuminant", string "LMS", bool "list", bool "adaptXYZ") {

    illu  = illuminant
    isIllu= isArray(illu)
    Assert(!isFloat(illu) && !isFloat(illu), "RGB_to_XYZ: Illuminant only supports string or array type.")

    cs    = color_Fuzzy_Search(cspace)
    list  = Default(list, false)     # Enable to output the Normalized Primary Matrix
    LMS   = Default(LMS, "CAT16")
    illu  = Defined(illuminant) ? isIllu ? ArraySize(illu)>2 ? illu : [illu[0],illu[1],1-illu[0]-illu[1]] : illu : color_propGet(rgb,cs[4])[3]
    adpt  = Default(adaptXYZ, true)  # By default adapt Transformation Matrix to defined Illuminant when it differs from Illuminant of the Gamut Primaries
                                     # Only 'false' required for a joint matrix transformations where Illuminants differ (the conversion is then handled by CAT() )

    # Properties:
    # Summing columns yields XYZ tristimulus values or Reference White in Y=1.0 scale [0.95048, 1, 1.08955]. From where you can extract the white point (ie. x = X/(X+Y+Z)...)
    # Summing column in the middle yields 1.0 (this column represents luminance coefficients)
    # Summing rows are proportional to summing rows with the color primaries. Extract primaries by pr1 = x[0]/(x[0]+x[1]+x[2]), pr2 = x[1]/(x[0]+x[1]+x[2]), etc
    #
    # matrix = cspace == "sRGB" || cspace == "709" ?  \
    #              [ 0.412313, 0.212599, 0.019327, \
    #                0.357590, 0.715180, 0.119197, \
    #                0.180553, 0.072221, 0.950913] : 0

    # Checking discrepancies
    p1    =                 color_coef(cs[0])
    p2    = isIllu ? illu : color_coef(cs[0], illu=illu)

    # White Point
    wp1   =                 [p1[3],p1[4],p1[5]]
    wp2   = isIllu ? illu : [p2[3],p2[4],p2[5]]

    # Primaries Flat Array
    prims = [p1[6][0],p1[6][1],p1[6][2],\
             p1[7][0],p1[7][1],p1[7][2],\
             p1[8][0],p1[8][1],p1[8][2]]

    # Reference White
    RW = wp1[2]!=wp2[2] && adpt ? ArrayOp(wp1, wp1[1], "/") : \
                                  ArrayOp(wp2, wp2[1], "/")

    T  = MatrixDot(RW,MatrixTranspose(MatrixInvert(prims)))
    M  = MatrixDot(Broadcast(T),prims)

    # Chromaticity Adapted Transform matrix
    if (wp1[2]!=wp2[2] && adpt) {

        D  = CAT(rgb, wp1, wp2, LMS=LMS, list=true)
        M  = MatrixDot(M, MatrixTranspose(D))
    }

    if (list) { M } else {

        MatrixClip(rgb, M)
        propSet("_Matrix", 0)
        propSet("_Model",  0) } }


# XYZ to RGB linear
function XYZ_to_RGB (clip xyz, string cspace, val "illuminant", string "LMS", bool "list", bool "adaptXYZ") {

    illu  = illuminant
    list  = Default(list, false)     # Enable to output the Normalized Primary Matrix
    Assert(!isFloat(illu) && !isFloat(illu), "XYZ_to_RGB: Illuminant only supports string or array type.")

    M = MatrixInvert(RGB_to_XYZ(xyz, cspace, illu, LMS, true, adaptXYZ))

    if (list) { M } else {

        MatrixClip(xyz, M)
        propSet("_Matrix", 0)
        propSet("_Model",  1) } }





# LMS space for linear Chromatic Adaptation Transform.
# LMS stands for Long, Medium, Short cone rod responses known as fundamental tristimulus values.
# This is the fastest and more straight-forward method for chromatic adaptation, without actually going through the model -CAM-.
# All of them work over 1931 and 1964 Standard Observers although some of them make a distinction (ie. CIE 2015)
#    XYZ Scaling
#    von Kries (Hunt-Pointer-Estevez for equal energy -E-)
#    von Kries (Hunt-Pointer-Estevez adjusted for D65)
#    von Kries (Hunt-Pointer-Estevez D65 modification for IPT model)
#    CAT97 (Bradford) (Spectral-sharpened)
#    Fairchild - by Mark D. Fairchild
#    CAT00 - by Li Changjun
#    CAT02 - by Li Changjun
#    CAT02 Brill 2008
#    CAT02 CRA
#    CAT16
#    OkLab
#    CIE 2015 - Stockman & Sharpe (2000) 2º and 10º Standard Observer (aims to be the defacto CIE standard for the forthcoming future)
#    Cat.5 from Abhijit Sarkar 10º Observer tests
#    Cat.9 from Abhijit Sarkar 10º Observer tests
#    Bianco BS    2010
#    Bianco BS PC 2010
#    Sharp - by Sabine Susstrunk
#    Sharp Spherical
#    Sharp Spherical with HUE uniformity
#
# Recommended: CAT16, CAT02B, CAT02CRA, SharpSphere and CIE 2015

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

    # HPE65 modification for DVp5 model
    HPEDV = [0.379702729270854, 0.702595741823277, -0.058294843714358, \
            -0.209241415246258, 1.132854830780842,  0.060621130953413, \
             0.003478802327033, 0.037458174951104,  0.880793856972993]

    # CAT97/Bradford (also known as Spectral-sharpened Bradford or Linearized Bradford/CIECAM97) usually better than HPE
    # Requires a non-linearity von Kries in the blue channel that is usually omitted (check page 52 of "Computing Chromatic Adaptation" by Süsstrunk)
    Brad  = [0.8951,  0.2664, -0.1614, \
            -0.7502,  1.7135,  0.0367, \
             0.0389, -0.0685,  1.0296]

    # From CIECAM2000 model. CAT00 is a revision of CAT97 by minimizing perceptual error over a different data set
    CAT00 = [0.7982, 0.3389, -0.1371, \
            -0.5918, 1.5512,  0.0406, \
             0.0008, 0.0239,  0.9753]

    # Fairchild improvement over Bradford to make it reversible (better than CAT00)
    Fair  = [0.8562,  0.3372, -0.1934, \
            -0.8360,  1.8327,  0.0033, \
             0.0357, -0.0469,  1.0112]

    # From CIECAM02 model. CAT02 is an improvement over Bradford and CAT00 by excluding the McCann haploscopic data set
    CAT02 = [0.7328,  0.4296, -0.1624, \
            -0.7036,  1.6975,  0.0061, \
             0.0030,  0.0136,  0.9834]

    # Brill and Süsstrunk (2008) corrected CAT02 chromatic adaptation transform
    CAT02B= [0.7328,  0.4296, -0.1624, \
            -0.7036,  1.6975,  0.0061, \
             0.0000,  0.0000,  1.0000]

    # Fix over CAT02B to predict adaptation of very saturated colors (negative values). Except for this case accuracy is worse than CAT02B (from: "The Problem with CAT02 and Its Correction")
    CAT02CRA= [1.007245,0.011136,-0.018381, \
              -0.318061,1.314589, 0.003471, \
               0.0000,  0.0000,   1.0000]

    # From CIECAM16 model. CAT16 is an improvement over CAT02 (grey with zero chroma). Resembles HPEIPT.
    CAT16 = [0.401288, 0.650173, -0.051461, \
            -0.250268, 1.204414,  0.045854, \
            -0.002079, 0.048952,  0.953127]

    # Oklab's cone response LMS matrix (derived from IPT and CAM16 models with some constraints, read: https://bottosson.github.io/posts/oklab/#how-oklab-was-derived)
    OK    = [0.8189330101, 0.3618667424, -0.1288597137, \
             0.0329845436, 0.9293118715,  0.0361456387, \
             0.0482003018, 0.2643662691,  0.6338517070]

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

    # CIE 2015 or CIE 170-2 or (previous CIE 170-1 or CIE 2006/2012) Stockman & Sharpe (2000) physiological 2º Standard Observer
    STK   = [0.210576, 0.855098, -0.0396983, \
            -0.417076, 1.177260,  0.0786283, \
             0.000000, 0.000000,  0.516835]

    # CIE 2015 or CIE 170-2 or (previous CIE 170-1 or CIE 2006/2012) Stockman & Sharpe (2000) physiological 10º Supplementary Standard Observer
    STK10 = [0.217011, 0.835734, -0.043511, \
            -0.429979, 1.203890,  0.086211, \
             0.000000, 0.000000,  0.465792]

    # Cat.5 of Abhijit Sarkar 10º Observer tests (mean age of 34.5)
    Cat5   = [ 0.979985, -0.011363, -0.009032, \
              -0.065248,  1.011010,  0.011730, \
               0.007037,  0.006649,  1.002210]

    # Cat.9 of Abhijit Sarkar 10º Observer tests (mean age of 52.2)
    Cat9   = [ 1.121113, -0.011363, -0.012619, \
              -0.160701,  1.011010,  0.012059, \
               0.005468,  0.006649,  1.010796]

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
    LMS = md == "XYZ"           ? XYZvk   :  md == "CAT00"           ? CAT00    : \
          md == "Scale"         ? XYZvk   :  md == "CAT02"           ? CAT02    : \
          md == "Scaling"       ? XYZvk   :  md == "CAT02B"          ? CAT02B   : \
          md == "Kries"         ? HPE65   :  md == "CAT02CRA"        ? CAT02CRA : \
          md == "von Kries"     ? HPE65   :  md == "CAT16"           ? CAT16    : \
          md == "vonKries"      ? HPE65   :  md == "Sharp"           ? Shp      : \
          md == "HPE"           ? HPE65   :  md == "Sphere"          ? Sph      : \
          FindStr(mdL,"hunt")>0 ? HPE65   :  md == "SharpSphere"     ? Sph      : \
          md == "E"             ? HPEE    :  md == "Sharp2"          ? Sph      : \
          md == "EE"            ? HPEE    :  md == "Sphere2"         ? b20      : \
          md == "HPEE"          ? HPEE    :  md == "Sharp3"          ? b20      : \
          md == "HPEDV"         ? HPEDV   :  FindStr(mdL,"hue")>0    ? b20      : \
          md == "IPT"           ? HPEIPT  :  md == "OPP"             ? OPP      : \
          md == "HPEIPT"        ? HPEIPT  :  md == "170-2"           ? STK      : \
          md == "Oklab"         ? OK      :  FindStr(md,"2006")   >0 ? STK      : \
          md == "Bradford"      ? Brad    :  FindStr(md,"2012")   >0 ? STK      : \
          md == "Brad"          ? Brad    :  FindStr(md,"2015")   >0 ? STK      : \
          md == "CAT97"         ? Brad    :  FindStr(md,"tockman")>0 ? STK      : \
          md == "Fairchild"     ? Fair    :  FindStr(mdL,"bianco")>0 ? BIA      : \
          md == "Cat5"          ? Cat5    :  FindStr(md,"PC"     )>0 ? BIAPC    : \
          md == "Cat9"          ? Cat9    :  Assert(false,"XYZ_to_LMS: Unsupported LMS mode.")

    LMS = trans ? MatrixTranspose(LMS) : LMS
    list  ? LMS : MatrixClip(xyz, LMS) }


function LMS_to_XYZ (clip lms, string "mode", bool "list", bool "transpose") {

    md   = Default (mode, "CAT02B")
    tran = Default (transpose, false)
    list = Default (list,      false)

    XYZ  = MatrixInvert(XYZ_to_LMS(lms,md,true,tran))

    if (list) { XYZ } else {

        MatrixClip(lms, XYZ)
        propSet("_Matrix", 0)
        propSet("_Model",  0) } }





##########################################
###                                     ##
###       ADAPTATION FUNCTIONS          ##
###                                     ##
##########################################



# Linear CAT (Chromatic Adaptation Transform):
# Adapts colors (HUEs) to match those viewed under a different target illuminant.
# To also match white point (aka White Balance or "Simulation") set mode="Simulation".
#
# Transformation Method:
#   Strong von Kries (von Kries-Ives) (used in ICC)
#   Weak   von Kries (default in CAT() )
#
# 'source' and/or 'target' can be Primaries (Color Space ie. "sRGB"), Standard Illuminant (ie: "D65") or a white point tuplet [x,y]
function CAT (clip c, val "source", val "target", string "LMS", string "mode", bool "tv_range", bool "list") {

    rgb     = IsRGB(c)
    propIDs = color_propGet(c)

    src   = Default (source,   propIDs[3]) # Source illuminant
    tgt   = Default (target,        "D65") # Target illuminant
    LMS   = Default (LMS,         "CAT16")
    tv    = Default (tv_range, propIDs[6])
    list  = Default (list,          false)
    md    = Default (mode,          "CAT") # 'CAT', 'Simulation' or 'Compensation'

    Assert(!isFloat(src)&&!isFloat(src), "CAT: Only string or array type supported")

    if (isArray(src)) {
        wps = ArraySize(src)>2 ? src : [src[0],src[1],1-src[0]-src[1],src[0]]
        wps = ArrayAppend(wps,wps)
    } else {
        src   = color_Fuzzy_Search (src)
        src   = list ? [src[1],src[1]] : src
        wps   = color_coef(src[1],illu=src[1])
    }
    if (isArray(tgt)) {
        wpt = ArraySize(tgt)>2 ? tgt : [tgt[0],tgt[1],1-tgt[0]-tgt[1],tgt[0]]
        wpt = ArrayAppend(wpt,wpt)
    } else {
        tgt   = color_Fuzzy_Search (tgt)
        tgt   = list ? [tgt[1],tgt[1]] : tgt
        wpt   = color_coef(tgt[1],illu=tgt[1])
    }

    same  = wps[3] == wpt[3]

    LMSm  = XYZ_to_LMS(c, LMS, true)

    wpsn  = MatrixDot([wps[3]/wps[4],1.,wps[5]/wps[4]], LMSm)
    wptn  = MatrixDot([wpt[3]/wpt[4],1.,wpt[5]/wpt[4]], LMSm)
    vk    = Broadcast(same ? [1,1,1] : ArrayOp(wptn,wpsn,"/"), "vonKries")

    CAM   = !same ? MatrixDot(MatrixInvert(LMSm), MatrixDot(vk, LMSm)) : vk

    if (!list) {

        c
        s_pri  = src[0] == "" ? propIDs[2] : src[0]
        s_gam  = src[2] == "" ? propIDs[5] : src[2]

        RGBpln = rgb ? IsPlanar() : false

        rgb ? RGBpln ? last : ConvertToPlanarRGB() : \
        YUV_to_RGB(c, s_pri, tv_in=tv, tv_out=false, kernel="lanczos", b=3)

        CCTF(s_gam, true, false, false)

        mata = RGB_to_XYZ (s_pri, md=="Simulation" ? tgt[1] : src[1], LMS=LMS, list=true, adaptXYZ=md!="CAT")
        matb = XYZ_to_RGB (s_pri, md=="Simulation" ? src[1] : tgt[1], LMS=LMS, list=true, adaptXYZ=md!="CAT")
        scl  = src[1]!=tgt[1]  && md=="CAT"        ? MatrixDot(mata, MatrixTranspose(CAM)) : mata
        MatrixClip(MatrixDot(scl, matb))

        CCTF(s_gam, false, false, false)

        rgb ? RGBpln ? last : MatchClip(c,internal=true) : \
        RGB_to_YUV( s_pri, tv_in=false, tv_out=tv, kernel="bicubic", b=-0.5, c=0.25, Jab=PixelType(c))

                           propCopy(c,true,props="_ChromaLocation")
        isString(target) ? propSet("_Illuminant", color_Fuzzy_Search(target)[5]) : last
        same ? c : last

    } else { CAM } }


# CIE XYZ Color Matching Functions approximations from tabulated data.
# The sum of the corresponding CIE RGB CMF integrals define the white point energy.
# Maps spectral observer sensitivity data into linear CIE tristimulus values X, Y and Z.
#
# Wright & Guild 1931 2º RGB CMFs primaries (which CIE 1931 is based on) fall at 700nm, 546.1nm and 435.8nm wavelengths.
# Since computation of RGB spectral tristimulus values was impractical the CIE transformed it into XYZ under the name CIE 1931 2º Standard Observer.
#
# CIE 1931 2º Standard Observer (ideal for LED) (conversion from Wright & Guild 1931 2º RGB CMF)
#  |_ CIE 1931 2º Judd (1951) and Vos (1978) modification
#     |_  1975 2º Smith & Pokorny CMF (LMS based)
#        |_ 1992 2º DeMarco, Pokorny & Smith CMF
# 1955 2º  Stiles and Burch CMF (RGB based) (download in XYZ)
#  |_ 1993 2º  Stockman, MacLeod and Johnson (LMS based)
# 1959 10º Stiles and Burch CMF
#  |_ CIE 1964 10º Supplementary Standard Observer (conversion from 10º (1959) Stiles and Burch CMF)
#  |_ CIE 170-2 or CIE 2015/12/06 Stockman & Sharpe (2000) physiological 2º  Standard Observer
#  |_ CIE 170-2 or CIE 2015/12/06 Stockman & Sharpe (2000) physiological 10º Supplementary Standard Observer (ideal for CCFL, good for OLED)
#      |_ CIE 170-2 Schanda-Csuti   (2008) modified 2º Standard Observer (ideal for Plasma)
#      |_ CIE 170-2 TUI (TU Ilmenau, 2008) modified 2º Standard Observer (ideal for OLED)
#      |_ CIE 170-2 TUI (TU Ilmenau, 2008) modified 10º Supplementary Standard Observer
# 2011 Cat.5 & Cat.9 (Abhijit Sarkar 2011) - ODCI (Observer Dependent Color Imaging) (8 Observers Table presented as Excel spreadsheet)
# 2015 Asano Cat.1 2º Standard Observer (151 Observers)
#
# * 2º -degrees- is the angular size of the human fovea
# * 10º (large field) Standard Observer should only be used for scientific purposes or where the target color patches exceed 4º of the observer field view (like illuminary, and other general related targets).
#   Movies in a SmartTV might range between 26º and 36º ('SMPTE 30' or 'THX') from the observer, but the individual color patches don't.
function CMF (clip c, string "CMF", int "wavelength", bool "show") {

    nm  = Default (wavelength,   560) # from 380 to 830. *Shorter wavelengths are absorbed by the cornea (<295nm) and lens (315–390nm)
    sh  = Default (show,        true) # Show the CMF plot (scaled to unit quadrant) or output the XYZ values
    CMF = Default (CMF,       "1931") # Color Matching Function

    if (sh) {
        GradientLinear(c, zoom=1, positive=true, precision=4, smooth=true, x=0, y=0, tv_range=false)
        L = ExtractY()
        MergeRGB(L,L,L)
    }

    # 390nm to 830nm. Multi-Lobe, Piecewise Gaussian Fit for CIE 1931 2º Standard Observer
    if        (CMF=="1931") {
    Wx = 0.312712      Wy = 0.329008 # D65 illuminant at [0.312712, 0.329008]
    t1 = (nm-442.0) * (nm<442.0?0.0624:0.0374)
    t2 = (nm-599.8) * (nm<599.8?0.0264:0.0323)
    t3 = (nm-501.1) * (nm<501.1?0.0490:0.0382)
    X  = 0.362 * exp(-0.5 * t1 * t1) + 1.056 * exp(-0.5 * t2 * t2) - 0.065 * exp(-0.5 * t3 * t3)
    t1 = (nm-568.8) * (nm<568.8?0.0213:0.0247)
    t2 = (nm-530.9) * (nm<530.9?0.0613:0.0322)
    Y  = 0.821 * exp(-0.5 * t1 * t1) + 0.286 * exp(-0.5 * t2 * t2)
    t1 = (nm-437.0) * (nm<437.0?0.0845:0.0278)
    t2 = (nm-459.0) * (nm<459.0?0.0385:0.0725)
    Z  = 1.217 * exp(-0.5 * t1 * t1) + 0.681 * exp(-0.5 * t2 * t2)

    sh ? Expr("x 350 * X@ 442   370 - < 0.0624 0.0374 ? X 442   370 - - * 2 ^ -0.5 * exp 0.362 *
               X          599.8 370 - < 0.0264 0.0323 ? X 599.8 370 - - * 2 ^ -0.5 * exp 1.056 * +
               X          501.1 370 - < 0.0490 0.0382 ? X 501.1 370 - - * 2 ^ -0.5 * exp 0.065 * - 0.45 *",\
              "x 350 * X@ 568.8 370 - < 0.0213 0.0247 ? X 568.8 370 - - * 2 ^ -0.5 * exp 0.821 *
               X          530.9 370 - < 0.0613 0.0322 ? X 530.9 370 - - * 2 ^ -0.5 * exp 0.286 * + 0.45 *",\
              "x 350 * X@ 437   370 - < 0.0845 0.0278 ? X 437   370 - - * 2 ^ -0.5 * exp 1.217 *
               X          459   370 - < 0.0385 0.0725 ? X 459   370 - - * 2 ^ -0.5 * exp 0.681 * + 0.45 *") : nop()

    # 360nm to 830nm. Multi-Lobe, Piecewise Gaussian Fit for CIE 1964 10º Standard Observer
    } else if (CMF=="1964") {
    Wx = 0.313824      Wy = 0.330999     # D65 illuminant at [0.313824, 0.330999]
    X  = 1.160477     * exp(-1           * pow((nm - 593.27583359)  /48.81284125,2)) + \
         0.406066     * exp(-1           * pow((nm - 444.33348762)  /27.9289803 ,2))
    Y  = 1.01318991   * exp(-0.937256650 * pow((nm - 556.301693)    /62.6625473 ,2)) + \
         0.0235000968 * exp(-7.64404005  * pow((nm - 445.479040)    /67.4229279 ,2))
    Z  = 2.146832     * exp(-33.88482265 * pow(log((nm - 266.13893779)/180.0702459),2))

    sh ? Expr("x 350 * X@ 593.27583359 370 - - 0.020486412476553 * 2 ^  neg           exp 1.160477     *
               X          444.33348762 370 - - 0.035805102415429 * 2 ^  neg           exp 0.406066     * + 0.45 *",\
              "x 350 * X@ 556.301693   370 - - 0.015958495833443 * 2 ^ -0.937256650 * exp 1.01318991   *
               X          445.479040   370 - - 0.014831749838618 * 2 ^ -7.64404005  * exp 0.0235000968 * + 0.45 *",\
              "x 350 * X@ 266.13893779 370 - - 0.005553388317998 * log 2 ^ -33.88482265 * exp 2.146832 *   0.45 *") : nop()

    # Multi-Lobe, Piecewise Gaussian Fit for CIE 2015 2º Standard Observer
    } else if (CMF=="2015_2") {
    Wx = 0.313453      Wy = 0.330802    # D65 illuminant at [0.313453, 0.330802]
    X  = 1.151326    * exp(-1           * pow((nm - 596.83152348)/46.78554306,2)) + \
         0.3494153   * exp(-1           * pow((nm - 443.24921254)/29.65566071,2))
    Y  = 0.918944680 * exp(-1.29798797  * pow((nm - 570.182202)  /63.9498238 ,2)) + \
         0.291610647 * exp(-2.86867802  * pow((nm - 529.871581)  /49.6014425 ,2)) + \
         0.089       * exp(-1.87130868  * pow((nm - 475.995186)  /60.5116873 ,2))
    Z  = 0.9         * exp(-2.40006110  * pow((nm - 433.071156)  /33.3751810 ,2)) + \
         1.39610998  * exp(-0.413682732 * pow((nm - 455.951450)  /20.4419130 ,2))

    sh ? Expr("x 350 * X@ 596.83152348 370 - - 0.021374124026252 * 2 ^  neg           exp 1.151326    *
               X          443.24921254 370 - - 0.033720374999529 * 2 ^  neg           exp 0.3494153   * + 0.45 *",\
              "x 350 * X@ 570.182202   370 - - 0.015637259660440 * 2 ^ -1.29798797  * exp 0.918944680 *
               X          529.871581   370 - - 0.020160703995655 * 2 ^ -2.86867802  * exp 0.291610647 * +
               X          475.995186   370 - - 0.016525733203278 * 2 ^ -1.87130868  * exp 0.089       * + 0.45 *",\
              "x 350 * X@ 433.071156   370 - - 0.029962384323848 * 2 ^ -2.40006110  * exp 0.9         *
               X          455.951450   370 - - 0.048919100673210 * 2 ^ -0.413682732 * exp 1.39610998  * + 0.45 *") : nop()

    # Multi-Lobe, Piecewise Gaussian Fit for CIE 2015 10º Standard Observer
    } else if (CMF=="2015_10") {
    Wx = 0.313786      Wy = 0.331275       # D65 illuminant at [0.313786, 0.331275]
    X  = 1.160477       * exp(-1           * pow((nm - 593.11837073) /48.15263773,2)) + \
         0.406066       * exp(-1           * pow((nm - 444.07099185) /27.94059768,2))
    Y  = 0.989818002    * exp(-0.957978328 * pow((nm - 557.662171)   /62.5184569 ,2)) + \
         0.055256131    * exp(-0.851496216 * pow((nm - 497.775569)   /67.5518673 ,2))
    Z  = 2.146832       * exp(-33.70579437 * pow(log((nm - 265.93990665)/179.93730243),2))

    sh ? Expr("x 350 * X@ 593.11837073 370 - - 0.020767294319517 * 2 ^  neg           exp 1.160477    *
               X          444.07099185 370 - - 0.035790215064576 * 2 ^  neg           exp 0.406066    * + 0.45 *",\
              "x 350 * X@ 557.662171   370 - - 0.015995276428520 * 2 ^ -0.957978328 * exp 0.989818002 *
               X          497.775569   370 - - 0.014803439785890 * 2 ^ -0.851496216 * exp 0.055256131 * + 0.45 *",\
              "x 350 * X@ 265.93990665 370 - - 0.005557491340013 * log 2 ^ -33.70579437 * exp 2.146832 *  0.45 *") : nop()

    # 380nm to 825nm. Multi-Lobe, Piecewise Gaussian Fit for Judd(1951)-Vos(1978) modified CIE 1931 2º Standard Observer
    } else if (CMF=="Judd-Vos") {
    Wx = 0.316084      Wy = 0.335067    # D65 illuminant at [0.316084, 0.335067]
    X  = 1.151326    * exp(-1           * pow((nm - 596.16761823)/44.86322931,2)) + \
         0.3494153   * exp(-1           * pow((nm - 441.85056287)/30.60218578,2))
    Y  = 0.601847253 * exp(-1.51659845  * pow((nm - 581.234908)  /63.9735453 ,2)) + \
         0.712156002 * exp(-0.900352124 * pow((nm - 527.940921)  /49.6827585 ,2)) + \
        -0.257747007 * exp(-3.95568352  * pow((nm - 496.724457)  /61.8141296 ,2))
    Z  = 0.53        * exp(-10.7859617  * pow((nm - 429.692756)  /66.7792884 ,2)) + \
        -703.724202  * exp(-2.81482710  * pow((nm - 475.579269)  /55.2441554 ,2)) + \
         704.629016  * exp(-4.12148933  * pow((nm - 475.555344)  /66.8735868 ,2))

    sh ? Expr("x 350 * X@ 596.16761823 370 - - 0.022289969210422 * 2 ^  neg           exp  1.151326    *
               X          441.85056287 370 - - 0.032677404391602 * 2 ^  neg           exp  0.3494153   * + 0.45 *",\
              "x 350 * X@ 581.234908   370 - - 0.015631461337816 * 2 ^ -1.51659845  * exp  0.601847253 *
               X          527.940921   370 - - 0.020127706878433 * 2 ^ -0.900352124 * exp  0.712156002 * +
               X          496.724457   370 - - 0.016177531034911 * 2 ^ -3.95568352  * exp -0.257747007 * + 0.45 *",\
              "x 350 * X@ 429.692756   370 - - 0.014974702845141 * 2 ^ -10.7859617  * exp  1           *
               X          475.579269   370 - - 0.018101462367547 * 2 ^ -2.81482710  * exp -703.724202  * +
               X          475.555344   370 - - 0.014953587026679 * 2 ^ -4.12148933  * exp  704.629016  * + 0.45 *") : nop()

    # 380nm to 780nm. Multi-Lobe, Piecewise Gaussian Fit for Cat5 Abhijit Sarkar's Observer tests 10º Standard Observer
    } else if (CMF=="Cat5") {
    Wx = 0.293241      Wy = 0.34077       # D65 illuminant at [0.293241, 0.340770]
    X  = 1.160477       * exp(-1          * pow((nm - 594.34831376)  /44.70087141,2)) + \
         0.406066       * exp(-1          * pow((nm - 443.85540032)  /27.42727776,2))
    Y  = 0.0589846547   * exp(-4.04288641 * pow((nm - 606.960286)    /61.9859710 ,2)) + \
         0.99262461     * exp(-1.07728930 * pow((nm - 553.655314)    /67.4112904 ,2))
    Z  = 2.146832       * exp(-33.7308306 * pow(log((nm - 266.07141426)/180.05473374),2))

    sh ? Expr("x 350 * X@ 594.34831376 370 - - 0.022370928540250 * 2 ^  neg           exp 1.160477     *
               X          443.85540032 370 - - 0.036460052971732 * 2 ^  neg           exp 0.406066     * + 0.45 *",\
              "x 350 * X@ 606.960286   370 - - 0.016132682667825 * 2 ^ -4.04288641  * exp 0.0589846547 *
               X          553.655314   370 - - 0.014834310307165 * 2 ^ -1.07728930  * exp 0.99262461   * + 0.45 *",\
              "x 350 * X@ 266.07141426 370 - - 0.005553866756117 * log 2 ^ -33.7308306 * exp 2.146832  *   0.45 *") : nop()

    # 380nm to 780nm. Multi-Lobe, Piecewise Gaussian Fit for Cat9 Abhijit Sarkar's Observer tests 10º Standard Observer
    } else if (CMF=="Cat9") {
    Wx = 0.301797      Wy = 0.341821       # D65 illuminant at [0.301797, 0.341821]
    X  = 1.160477       * exp(-1           * pow((nm - 598.09202261)  /45.81682164,2)) + \
         0.406066       * exp(-1           * pow((nm - 447.75849618)  /25.77397532,2))
    Y  = 0.0589846547   * exp(-4.04288641  * pow((nm - 606.960286)    /61.9859710 ,2)) + \
         0.992624610    * exp(-1.07728930  * pow((nm - 553.655314)    /67.4112904 ,2))
    Z  = 2.146832       * exp(-35.77737624 * pow(log((nm - 267.192609)/180.44075615),2))

    sh ? Expr("x 350 * X@ 598.09202261 370 - - 0.021826044762716 * 2 ^  neg           exp 1.160477     *
               X          447.75849618 370 - - 0.038798826629745 * 2 ^  neg           exp 0.406066     * + 0.45 *",\
              "x 350 * X@ 606.960286   370 - - 0.016132682667825 * 2 ^ -4.04288641  * exp 0.0589846547 *
               X          553.655314   370 - - 0.014834310307165 * 2 ^ -1.07728930  * exp 0.99262461   * + 0.45 *",\
              "x 350 * X@ 267.192609   370 - - 0.005541985199667 * log 2 ^ -35.77737624 * exp 2.146832 *   0.45 *") : nop()

    # 390nm to 780nm. Multi-Lobe, Piecewise Gaussian Fit for Asanos's 151 Cat.1 2º Observer tests
    } else { /* if (CMF=="Asano") revise fit for Z prolly also for Judd-Vos */
    Wx = 0.312994      Wy = 0.328972    # D65 illuminant at [0.312994, 0.328972]
    X  = 1.151326    * exp(-1           * pow((nm - 596.85301964)/44.83663761,2)) + \
         0.3494153   * exp(-1           * pow((nm - 444.51663941)/30.28442651,2))
    Y  =-0.468768354 * exp(-2.88091492  * pow((nm - 568.978314)  /63.7801126 ,2)) + \
         1.412251930 * exp(-0.865345614 * pow((nm - 562.841338)  /50.0097534 ,2)) + \
         0.0304406374* exp(-0.736336456 * pow((nm - 519.029938)  /60.6092595 ,2))
    Z  = 0.53        * exp(-13.9353165  * pow((nm - 469.623230)  /66.1854288 ,2)) + \
        -578.815828  * exp(-3.21437574  * pow((nm - 462.275075)  /52.7574052 ,2)) + \
         579.414011  * exp(-4.60573889  * pow((nm - 462.225862)  /63.2476534 ,2))

    sh ? Expr("x 350 * X@ 596.85301964 370 - - 0.022303188938882 * 2 ^  neg           exp  1.151326     *
               X          444.51663941 370 - - 0.033020271976086 * 2 ^  neg           exp  0.3494153    * + 0.45 *",\
              "x 350 * X@ 568.978314   370 - - 0.015678868525547 * 2 ^ -2.88091492  * exp -0.468768354  *
               X          562.841338   370 - - 0.019996099400882 * 2 ^ -0.865345614 * exp  1.412251930  * +
               X          519.029938   370 - - 0.016499129147090 * 2 ^ -0.736336456 * exp  0.0304406374 * + 0.45 *",\
              "x 350 * X@ 469.623230   370 - - 0.015109065819031 * 2 ^ -13.9353165  * exp  0.53         *
               X          462.275075   370 - - 0.018954685057179 * 2 ^ -3.21437574  * exp -578.815828   * +
               X          462.225862   370 - - 0.015810863269119 * 2 ^ -4.60573889  * exp  579.414011   * + 0.45 *") : nop()
    }

    if (!sh) { [X,Y,Z,Wx,Wy] } else {
        R=ExtractR().HistoCurve(3,gradient=true)
        G=ExtractG().HistoCurve(3,gradient=true)
        B=ExtractB().HistoCurve(3,gradient=true)
        MergeRGB(R,G,B).subtitle(CMF,y=10,align=9)
        }
    }

# Add Spectral Luminous Efficiency functions (Photopic, Mesopic and Scotopic)
# WIP
# Calculate the Chromaticity Coordinates for the given temperature and Color Matching Function
function Chromaticity_xy(clip a, int "Temp", string "CMF") {

    T   = Default(temp, 6504)
    CMF = Default(CMF, "1931")
    a
    wp  = WhitePoint(temp, locus=T<5000 ? "Planckian" : "Daylight", list=true) # From 5000 onwards use 'Daylight'
    wpx = wp[0]
    wpy = wp[1]

    M  =   0.0241 + 0.2562  * wpx - 0.7341  * wpy
    M1 = (-1.3515 - 1.7703  * wpx + 5.9114  * wpy) / M
    M2 = ( 0.0300 - 31.4424 * wpx + 30.0717 * wpy) / M

    # Beware, some CMFs start at 360nm or 390nm
    # Similarly some end at 830nm instead of 780nm
    W = []
    for (i=380, 780, 5) {

        SPD = SPD_D(i)
        SPD = SPD[0] + M1 * SPD[1] + M2 * SPD[2]

        MF  = CMF(CMF,i,false)
        W   = ArrayOp(ArrayOp(MF,SPD,"*"),W,"+")
    }

    ArrayDel(ArrayDel(ArrayOp(W,W[0] + W[1] + W[2],"/"),4),3)

    }



# CIE Standard Illuminant D Series SPD (Spectral Power Distribution) dataset
# https://en.wikipedia.org/wiki/Illuminant_D65#External_links
# Original precision of 10nm, Sprague interpolated* to 5nm and further cubic spline interpolated with spline() (as recommended in "Reevaluation of daylight spectral distributions" 2000)
#   *Currently CIE recommends "Sprague (1880)" interpolation (a 5th degree polynomial), in cases where intervals are constant
function SPD_D(int i) {

    S0 = spline(i, 300,0.04, 305,1.38, 310,6.0, 315,16.0, 320,29.6, 325,44.29, 330,55.3, 335,57.84, 340,57.3, 345,59.53, 350,61.8, 355,61.32, 360,61.5, 365,65.56, 370,68.8, 375,66.86, 380,63.4, 385,61.68, 390,65.8, 395,79.72, 400,94.8, 405,102.06, 410,104.8, 415,106.85, 420,105.9, 425,99.99, 430,96.8, 435,103.55, 440,113.9, 445,121.29, 450,125.6, 455,126.72, 460,125.5, 465,123.16, 470,121.3, 475,121.61, 480,121.3, 485,117.46, 490,113.5, 495,112.78, 500,113.1, 505,112.4, 510,110.8, 515,108.22, 520,106.5, 525,107.6, 530,108.8, 535,107.32, 540,105.3, 545,104.85, 550,104.4, 555,102.5, \
                  560,100.0, 565,97.64, 570,96.0, 575,95.79, 580,95.1, 585,91.95, 590,89.1, 595,89.29, 600,90.5, 605,90.7, 610,90.3, 615,89.71, 620,88.4, 625,85.91, 630,84.0, 635,84.48, 640,85.1, 645,83.61, 650,81.9, 655,81.72, 660,82.6, 665,84.05, 670,84.9, 675,84.13, 680,81.3, 685,76.08, 690,71.9, 695,72.0, 700,74.3, 705,76.89, 710,76.4, 715,69.34, 720,63.3, 725,65.76, 730,71.7, 735,76.03, 740,77.0, 745,73.21, 750,65.2, 755,53.54, 760,47.7, 765,57.11, 770,68.6, 775,68.66, 780,65.0, 785,65.29, 790,66.0, 795,64.36, 800,61.0, 805,56.26, 810,53.3, 815,55.14, 820,58.9, 825,61.0, 830,61.9)
    S1 = spline(i, 300,0.02, 305,1.03, 310,4.5, 315,12.02, 320,22.4, 325,33.82, 330,42.0, 335,42.65, 340,40.6, 345,41.11, 350,41.6, 355,39.48, 360,38.0, 365,40.17, 370,42.4, 375,41.27, 380,38.5, 385,35.68, 390,35.0, 395,38.67, 400,43.4, 405,45.74, 410,46.3, 415,45.83, 420,43.9, 425,40.28, 430,37.1, 435,36.37, 440,36.7, 445,36.57, 450,35.9, 455,34.55, 460,32.6, 465,30.24, 470,27.9, 475,26.05, 480,24.3, 485,22.25, 490,20.1, 495,18.04, 500,16.2, 505,14.78, 510,13.2, 515,10.88, 520,8.6, 525,7.13, 530,6.1, 535,5.16, 540,4.2, 545,3.06, 550,1.9, 555,0.89, 560,-0.0, 565,-0.77, 570,-1.6, \
                    575,-2.69, 580,-3.5, 585,-3.46, 590,-3.5, 595,-4.52, 600,-5.8, 605,-6.59, 610,-7.2, 615,-7.93, 620,-8.6, 625,-9.03, 630,-9.5, 635,-10.29, 640,-10.9, 645,-10.82, 650,-10.7, 655,-11.14, 660,-12.0, 665,-13.13, 670,-14.0, 675,-14.11, 680,-13.6, 685,-12.63, 690,-12.0, 695,-12.52, 700,-13.3, 705,-13.44, 710,-12.9, 715,-11.62, 720,-10.6, 725,-10.83, 730,-11.6, 735,-12.16, 740,-12.2, 745,-11.49, 750,-10.2, 755,-8.52, 760,-7.8, 765,-9.39, 770,-11.2, 775,-11.09, 780,-10.4, 785,-10.45, 790,-10.6, 795,-10.31, 800,-9.7, 805,-8.84, 810,-8.3, 815,-8.63, 820,-9.3, 825,-9.66, 830,-9.8)
    S2 = spline(i, 300,0.0, 305,1.08, 310,2.0, 315,2.7, 320,4.0, 325,6.45, 330,8.5, 335,8.59, 340,7.8, 345,7.27, 350,6.7, 355,5.81, 360,5.3, 365,5.84, 370,6.1, 375,4.76, 380,3.0, 385,2.03, 390,1.2, 395,-0.12, 400,-1.1, 405,-0.97, 410,-0.5, 415,-0.49, 420,-0.7, 425,-0.86, 430,-1.2, 435,-1.91, 440,-2.6, 445,-2.87, 450,-2.9, 455,-2.88, 460,-2.8, 465,-2.68, 470,-2.6, 475,-2.65, 480,-2.6, 485,-2.23, 490,-1.8, 495,-1.6, 500,-1.5, 505,-1.39, 510,-1.3, 515,-1.25, 520,-1.2, 525,-1.13, 530,-1.0, 535,-0.75, 540,-0.5, 545,-0.38, 550,-0.3, 555,-0.15, \
                   560,0.0, 565,0.12, 570,0.2, 575,0.24, 580,0.5, 585,1.24, 590,2.1, 595,2.71, 600,3.2, 605,3.68, 610,4.1, 615,4.45, 620,4.7, 625,4.81, 630,5.1, 635,5.89, 640,6.7, 645,7.04, 650,7.3, 655,7.88, 660,8.6, 665,9.25, 670,9.8, 675,10.27, 680,10.2, 685,9.15, 690,8.3, 695,8.86, 700,9.6, 705,9.32, 710,8.5, 715,7.59, 720,7.0, 725,7.13, 730,7.6, 735,7.96, 740,8.0, 745,7.53, 750,6.7, 755,5.64, 760,5.2, 765,6.24, 770,7.4, 775,7.28, 780,6.8, 785,6.86, 790,7.0, 795,6.81, 800,6.4, 805,5.85, 810,5.5, 815,5.69, 820,6.1, 825,6.36, 830,6.5)
    [S0,S1,S2] }