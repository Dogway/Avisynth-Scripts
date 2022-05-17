###########################################################
###                                                      ##
###                                                      ##
###   Transforms Pack - Models v1.0 RC50  (17-05-2022)   ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182825    ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
### MODELS:                                              ##
###     YUV_to_RGB      / RGB_to_YUV                     ##
###     RGB_to_YcCbcCrc / YcCbcCrc_to_RGB                ##
###     RGB_to_YCoCg    / YCoCg_to_RGB                   ##
###     RGB_to_YCoCgR   / YCoCgR_to_RGB                  ##
###     RGB_to_YUVr     / YUVr_to_RGB                    ##
###     RGB_to_OPP      / OPP_to_RGB                     ##
###     XYZ_to_YDzDx    / YDzDx_to_XYZ                   ##
###     XYZ_to_Lab      / Lab_to_XYZ                     ##
###     XYZ_to_Luv      / Luv_to_XYZ                     ##
###     RGB_to_HSV      / HSV_to_RGB                     ##
###     RGB_to_IPT      / IPT_to_RGB                     ##
###     RGB_to_Oklab    / Oklab_to_RGB                   ##
###     RGB_to_XYZ      / XYZ_to_RGB                     ##
###     CAT                                              ##
###                                                      ##
###########################################################



##########################################
###                                     ##
###     MODEL CONVERSION FUNCTIONS      ##
###                                     ##
##########################################


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


# RGB to YcCbcCrc function (for Rec.2020CL)
function RGB_to_YcCbcCrc (clip RGB, clip "Gx", clip "Bx", string "matrix", float_array "coef", bool "tv_in", bool "tv_out") {

    isy  = isy(RGB)
    bi   = BitsPerComponent(RGB)
    lut  = bi > 12 || isRunTime(RGB,!isy) ? 0 : 2
    mat  = Default (matrix, "709")
    coef = Default (coef, Matrix_coef(mat))
    tvi  = Default (tv_in,  false)
    tvo  = Default (tv_out, false)

    mat       = color_Fuzzy_Search(mat)
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
    !isy && mat[0] == "2020CL" ? propSet("_Matrix", 10) : last }


# WIP. YcCbcCrc to RGB function (for Rec.2020CL)
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


# YCoCg to RGB function
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


# RGB to YCoCg RCT function
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


#  YCoCg RCT to RGB function
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


# RGB to YCbCr RCT function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
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


# YCbCr RCT to RGB function (Reversible Color Transform, from JPEG 2000, similar to YCoCg)
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


# XYZ to YDzDx (applied on SMPTE ST 2084 gamma space)
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


# WIP. XYZ to CIE Lab -D65 based- (process in linear space) Normalized to 0-1
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
    iRT  = isRunTime(Lab,!isy)
    lut1 = bi == 32 || iRT ? 0 : 1
    lut2 = bi  > 12 || iRT ? 0 : 2
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
# CIE Luv to XYZ
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

    Ss = ex_dlut(Ss, bi, !tv)
    Hs = ex_dlut(Hs, bi, !tv)

    if (isy) {

        S = Expr(R, G, B, V, Ss, optSingleMode=false)
        H = Expr(R, G, B, V, Hs, optSingleMode=true)
        [H, S, V]

    } else { Expr(R, G, B, V, Hs, Ss, "a", format=PixelType(RGB), optSingleMode=true) } }


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



# RGB linear to IPT (original PT range scaled from -1 +1 to 0 +1)
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




function RGB_to_XYZ (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    matrix =        cspace == "sRGB"   || cspace == "709"                                                ?  \
                                        [ 0.41241079568862915, 0.21264933049678802, 0.01933175697922707,    \
                                          0.35758456587791443, 0.71516913175582890, 0.11919485777616501,    \
                                          0.18045382201671600, 0.07218152284622192, 0.95039016008377080]  : \
                    cspace == "601" || cspace == "170M" || cspace == "240M"                              ?  \
                                        [ 0.39354196190834045, 0.21238772571086884, 0.0187400933355093,     \
                                          0.36525884270668030, 0.70106136798858640, 0.1119341626763344,     \
                                          0.19164848327636720, 0.08655092865228653, 0.9582424163818359]   : \
                    FindStr(cspace, "CL")>0                                                              ?  \
                                        [ 0.6361018419265747, 0.262403696775436400, 0.0000449275212304201,  \
                                          0.1450060009956360, 0.678454995155334500, 0.0283129680901765820,  \
                                          0.1693413406610489, 0.059141214936971664, 1.0605586767196655000]: \
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

    matrix =        cspace == "sRGB"   || cspace == "709"                                                   ?  \
                                        [  3.24081254005432130, -0.96924304962158200,  0.055638398975133896,   \
                                          -1.53730857372283940,  1.87596631050109860, -0.204007431864738460,   \
                                          -0.49858659505844116,  0.04155505076050758,  1.057129383087158200] : \
                    cspace == "601" || cspace == "170M" || cspace == "240M"                                 ?  \
                                        [  3.5058159828186035, -1.06904542446136470,  0.05631496384739876,     \
                                          -1.7396978139877320,  1.97777497768402100, -0.19700492918491364,     \
                                          -0.5440292358398438,  0.035171352326869965, 1.05010843276977540]   : \
                    FindStr(cspace, "CL")>0                                                                 ?  \
                                        [  1.71929574012756350, -0.66651082038879400,  0.017720524221658707,   \
                                          -0.35683879256248474,  1.61570894718170170, -0.043118298053741455,   \
                                          -0.25462427735328674,  0.01632426492869854,  0.942474246025085400] : \
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



# CAT (Chromatic Adaptation Transforms) types:
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
# Von Kries (Hunt-Pointer-Estevez for equal energy -E-)
# XYZ Scaling
#
# von Kries Chromatic Adaptation
# source and/or target can be a Primaries Color Space (ie. sRGB) or an illuminant (ie: D65)
function CAT (clip c, string "source", string "target", bool "tv_range", bool "list") {

    rgb     = IsRGB(c)
    propIDs = color_propGet(c)

    src    = Default (source,   propIDs[3])
    tgt    = Default (target,        "D65")
    tv     = Default (tv_range, propIDs[6])
    list   = Default (list,          false)

    src    = list ? [src] : color_Fuzzy_Search (src)
    tgt    = list ? [tgt] : color_Fuzzy_Search (tgt)
    wps    = Matrix_coef(src[0])
    wpt    = Matrix_coef(tgt[0])
    same   = wps[3] == wpt[3]

    CAT02  = [0.7328,  0.4296, -0.1624, \
             -0.7036,  1.6975,  0.0061, \
              0.0030, -0.0136,  0.9834]

    wpsn   = MatrixDot([wps[3]/wps[4],1.,wps[5]/wps[4]], CAT02)
    wptn   = MatrixDot([wpt[3]/wpt[4],1.,wpt[5]/wpt[4]], CAT02)
    trans  = ArrayOp(wptn,wpsn,"/")
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



