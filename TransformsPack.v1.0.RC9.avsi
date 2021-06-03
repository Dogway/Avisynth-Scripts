###########################################################
###                                                      ##
###                                                      ##
###    Transforms Pack v1.0 RC9  (03-06-2021)            ##
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
### All of them converge on ColorSpace(). An accurate and simple to use
### color space and gamma conversion filter.
###
###
### Dependencies: AviSynth+ 3.5 and over
###
###
####################################

function ColorSpace (clip clp, string "source", string "target", bool "gamut", bool "gamma", bool "tv_range_in", bool "tv_range_out", bool "linear_in", bool "linear_out", string "format_out") {

    isRGBsrc    = isRGB(clp)

    source  = Default (source, "Rec709")
    target  = Default (target, source)
    gamut   = Default (gamut, source != target)    # convert gamut
    gamma   = Default (gamma, true)                # convert gamma
    tv_in   = Default (tv_range_in,  !isRGBsrc )
    tv_out  = Default (tv_range_out, tv_range_in )
    lin_in  = Default (linear_in,  false )
    lin_out = Default (linear_out, false )
    f_out   = Default (format_out, "" )

    clp
    pxtyp = PixelType(clp)
    p_typ = f_out != "" ? Format_fuzzy_search (f_out) : pxtyp
    f_ker = f_out != "" && pxtyp != p_typ ? "Bicubic" : "Point"
    src   = Matrix_fuzzy_search (source)
    tgt   = Matrix_fuzzy_search (target)
    s_gam = moncurve_coef (src)
    t_gam = moncurve_coef (tgt)
	gamut = gamut && src != tgt

    !isRGBsrc && lin_in && gamut && gamma ? moncurve_r(s_gam[0], s_gam[1], tv_in, tv_in) : last

     isRGBsrc ? gamut ? tv_in ? ConvertToPlanarRGB(src).SMPTE_legal(false)                      : \
                                ConvertToPlanarRGB(src)                                  : last :\
                                YUV_to_RGB(src, tv_range_in=tv_in, kernel=f_ker)

    gamma || !lin_in  ? moncurve_f(s_gam[0], s_gam[1],tv_in,false)                       : last

    if (gamut) {
    mata = RGB_to_XYZ(src, list=true)
    matb = XYZ_to_RGB(tgt, list=true)
    MatrixClip( MatrixDot(mata, matb) ) }

    FindStr(target,"ACES")>0 || lin_out ? last                                        : \
                                  gamma ? moncurve_r(t_gam[0], t_gam[1],false,false) : \
                      gamut || !lin_out ? moncurve_r(s_gam[0], s_gam[1],false,false) : \
                                          last

    isRGBsrc && FindStr(p_typ, "RGB")>0 ? \
                tv_out  ? SMPTE_legal() : last : \
                lin_out ? moncurve_r(t_gam[0], t_gam[1]).RGB_to_YUV( tgt, tv_range_out=tv_out, kernel=f_ker, pixel_type=p_typ).moncurve_f(t_gam[0], t_gam[1],tv_out,tv_out) : \
                                                         RGB_to_YUV( tgt, tv_range_out=tv_out, kernel=f_ker, pixel_type=p_typ) }



function Display_Referred (clip clp, string "source", string "disp_ref", string "kernel", bool "gamut", bool "gamma", string "LUT", bool "tv_range", float "b", float "c", float "p") {

    gamut      = Default (gamut, true)      # convert gamut
    gamma      = Default (gamma, true)      # convert gamma
    disp_ref   = Default (disp_ref, "sRGB") # Display Referred Color Space
    kernel     = Default (kernel, "Bicubic")
    LUT        = Default (LUT, Undefined)   # Display LUT (the path string of your monitor 3D LUT, if calibrated)
    tv_range   = Default (tv_range, !isRGB(clp) )
    b          = Default (b, 0.00)
    c          = Default (c, 0.75)          # Precise Bicubic
    p          = Default (p, 0.25)

    bdpth < 32 ? clp.ConvertBits(16) : clp

    src = Matrix_fuzzy_search (source)
    tgt = Matrix_fuzzy_search (disp_ref)
    s_gam = moncurve_coef (src)
    t_gam = moncurve_coef (tgt)

    IsRGB() ? tv_range ? ConvertToPlanarRGB(src).SMPTE_legal(false) : ConvertToPlanarRGB(src) : \
    YUV_to_RGB(src, tv_range_in=tv_range, kernel=kernel, b=b, c=c, p=p)

    moncurve_f(s_gam[0], s_gam[1])

    if (gamut) {
    mata = RGB_to_XYZ(src, list=true)
    matb = XYZ_to_RGB(tgt, list=true)
    MatrixClip( MatrixDot(mata, matb) ) }

    Defined(LUT) || gamma ? moncurve_r(t_gam[0], t_gam[1]) : gamut ? moncurve_r(s_gam[0], s_gam[1]) : last

    Defined(LUT) ? Cube(LUT, 4, true) : last

    ConvertBits(8, dither=1)  }



# YCbCr to RGB function
function YUV_to_RGB (clip yuv, string "matrix", bool "tv_range_in", bool "tv_range_out", string "kernel", float "b", float "c", float "p", string "cplace") {

    matrix     = Default (matrix, "709")
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, true)
    tv_out     = Default (tv_range_out, false)
    b          = Default (b, 0.0)
    c          = Default (c, 0.75)               # Precise Bicubic
    p          = Default (p, 0.25)

    Assert(AvsPlusVersionNumber > 2724, "Update AviSynth+ version")

    bdpth      = BitsPerComponent(yuv)
    p_type     = Format_fuzzy_search (yuv, PixelType(yuv))
    p_typei    = StrLen(p_type) != 4 ? LeftStr(p_type,7) : p_type
    matrix     = Matrix_fuzzy_search (matrix)
    coef       = Matrix_coef(matrix)

                                  p_type4  = p_typei == "YUV444P"
                                  p_type2  = p_typei == "YUV422P"
                                  p_type1  = p_typei == "YUV411P"
                                  p_type0  = p_typei == "YUV420P"
                                  p_type10 = p_typei == "YUV9"
                                                 # source chroma placement
    cplace     = Default (cplace, matrix == "sRGB"    ? "JPEG"     : \
                          FindStr(matrix,"2020")>0    ? "top_left" : \
                          FindStr(matrix,"2100")>0    ? "top_left" : \
                                  p_type4             ? "center"   : \
                                  p_type2             ? "MPEG1"    : \
                                  p_type1             ? "MPEG1"    : \
                                  p_type0             ? "MPEG2"    : \
                                  p_type10            ? "DV"       : "MPEG2")

    p_type1   ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411") : nop()
                Assert(!p_type10, "Unsupported Pixel Type: YUV410")

    w      = width (yuv)
    h      = height(yuv)

                                  # centerU:centerV:
    cloc   = cplace == "MPEG1"       ? [0.0, 0.0] : \
             cplace == "center"      ? [0.0, 0.0] : \
             cplace == "JPEG"        ? [0.0, 0.0] : \
             cplace == "MPEG2"       ? [0.5, 0.0] : \
             cplace == "left"        ? [0.5, 0.0] : \
             cplace == "DV"          ? [0.5,-0.5] : \
             cplace == "bottom_left" ? [0.5,-0.5] : \
             FindStr(cplace,"2020")>0? [0.5, 0.5] : \
             FindStr(cplace,"2100")>0? [0.5, 0.5] : \
             cplace == "top_left"    ? [0.5, 0.5] : \
             Assert (false, "Unsupported chroma placement mode.")

                  # ratioW:ratioH
    cplace = p_type4  ? [1,1] : \
             p_type2  ? [2,1] : \
             p_type1  ? [4,1] : \
             p_type0  ? [2,2] : \
             p_type10 ? [4,2] : \
             Assert (false, "Unsupported chroma placement mode.")

    point   = kernel=="Point" ? "+1.0" : ""
    cplaceU = ",src_left="+string(cloc[0]*(1-cplace[0]))+point
    cplaceV =  ",src_top="+string(cloc[1]*(1-cplace[1]))+point

    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(w) + "," + String(h) + cplace +")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(w) + "," + String(h) + cplace +",b=b,c=c)" : \
                kernel == "gauss"  ?     "GaussResize(" + String(w) + "," + String(h) + cplace +",p=p)"     : \
                                     kernel + "Resize(" + String(w) + "," + String(h) + cplace +")"

    Y = ExtractY(yuv)
    U = Eval("ExtractU(yuv)." + resampler)
    V = Eval("ExtractV(yuv)." + resampler)


    if (matrix=="Rec2020CL" || matrix=="DCI-P3" || matrix=="Display-P3") {

        RGB = YcCbcCrc_to_RGB( Y, U, V, matrix, coef, tv_in, tv_out)

        R = RGB[0]  G = RGB[1]  B = RGB[2]

    } else {

        scale_y   = tv_in ? (256. / 219.) : 1.0
        scale_uv  = tv_in ? (256. / 112.) : 2.0

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y     m1 = 0.0                                   m2 = scale_uv * Kr
        m3 = scale_y     m4 = scale_uv * ( -Kb * coef[2] / coef[1]) m5 = scale_uv * ( -Kr * coef[0] / coef[1])
        m6 = scale_y     m7 = scale_uv * Kb                         m8 = 0.0

        rangeY   = tv_out     ? ""                          : "ymin -"
        range_TV = tv_out     ? "ymax ymin - * range_max /" : ""
        UVf      = bdpth < 32 ? "range_half - " : ""

        R = Expr(Y,    V, "x "+rangeY+" "+string(m0)+" *                            y "+UVf + string(m2)+" * + "+range_TV+"")
        G = Expr(Y, U, V, "x "+rangeY+" "+string(m3)+" * y "+UVf + string(m4)+" * + z "+UVf + string(m5)+" * + "+range_TV+"")
        B = Expr(Y, U,    "x "+rangeY+" "+string(m6)+" * y "+UVf + string(m7)+" * +                            "+range_TV+"")

    }

    CombinePlanes(R, G, B, planes="RGB") }



# RGB to YCbCr function
function RGB_to_YUV (clip rgb, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", float "b", float "c", float "p", string "cplace") {

    matrix     = Default (matrix, "sRGB")
    p_type     = Default (pixel_type, "420")     # target YUV pixel_type
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, false)
    tv_out     = Default (tv_range_out, true)
    b          = Default (b, -0.5)
    c          = Default (c, 0.25)               # Didée's Bicubic
    p          = Default (p, 0.25)

    Assert(AvsPlusVersionNumber > 2724, "Update AviSynth+ version")

    bdpth      = BitsPerComponent(rgb)
    p_type     = Format_fuzzy_search (rgb, p_type)
    p_typei    = StrLen(p_type) != 4 ? LeftStr(p_type,7) : p_type
    matrix     = Matrix_fuzzy_search (matrix)
    coef       = Matrix_coef(matrix)

                                  p_type4  = p_typei == "YUV444P"
                                  p_type2  = p_typei == "YUV422P"
                                  p_type1  = p_typei == "YUV411P"
                                  p_type0  = p_typei == "YUV420P"
                                  p_type10 = p_typei == "YUV9"
                                                 # target chroma placement
    cplace     = Default (cplace, matrix == "sRGB"    ? "JPEG"     : \
                          FindStr(matrix,"2020")>0    ? "top_left" : \
                          FindStr(matrix,"2100")>0    ? "top_left" : \
                                  p_type4             ? "center"   : \
                                  p_type2             ? "MPEG1"    : \
                                  p_type1             ? "MPEG1"    : \
                                  p_type0             ? "MPEG2"    : \
                                  p_type10            ? "DV"       : "MPEG2")

    p_type1   ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411") : nop()
                Assert(!p_type10, "Unsupported Pixel Type: YUV410")

    w  = width (rgb)
    h  = height(rgb)
    nw = p_type1 ? round(w/4.0) : round(w/2.0)
    nh =                          round(h/2.0)

    p_type2 || p_type0 ? Assert (w%2==0, "Width is not mod2." ) : nop()
                         Assert (h%2==0,"Height is not mod2." )
    p_type1            ? Assert (w%4==0, "Width is not mod4." ) : nop()


    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)


    if (matrix=="Rec2020CL" || matrix=="DCI-P3" || matrix=="Display-P3") {

        YCbCr = RGB_to_YcCbcCrc( Rx, Gx, Bx, matrix, coef, tv_in, tv_out)

        Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]

    } else {

        scale_y  = !tv_in && tv_out ? (219. / 256.) : 1.0
        scale_uv = !tv_in && tv_out ? (112. / 256.) : 0.5

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y  *   coef[0]       m1 = scale_y  *   coef[1]         m2 = scale_y  *   coef[2]
        m3 = scale_uv * (-coef[0] / Kb) m4 = scale_uv * (-coef[1] / Kb)   m5 = scale_uv
        m6 = scale_uv                   m7 = scale_uv * (-coef[1] / Kr)   m8 = scale_uv * (-coef[2] / Kr)

        UVf       =  bdpth < 32      ? "" : "range_half -"
        rangeY_TV =  tv_out ?  tv_in ? "" : "ymin +" : tv_in ? "ymin - ymax ymin - / range_max *"    : ""
        rangeC_TV = !tv_out && tv_in ? "range_half - cmax cmin - / range_max * range_half + "+UVf+"" : UVf

        Y  = Expr(Rx, Gx, Bx, "           x "+string(m0)+" *   y "+string(m1)+" * + z "+string(m2)+" * + "+rangeY_TV+"")
        Cb = Expr(Rx, Gx, Bx, "range_half x "+string(m3)+" * + y "+string(m4)+" * + z "+string(m5)+" * + "+rangeC_TV+"")
        Cr = Expr(Rx, Gx, Bx, "range_half x "+string(m6)+" * + y "+string(m7)+" * + z "+string(m8)+" * + "+rangeC_TV+"")

    }

                                  # centerU:centerV:
    cloc   = cplace == "MPEG1"       ? [0.0, 0.0] : \
             cplace == "center"      ? [0.0, 0.0] : \
             cplace == "JPEG"        ? [0.0, 0.0] : \
             cplace == "MPEG2"       ? [0.5, 0.0] : \
             cplace == "left"        ? [0.5, 0.0] : \
             cplace == "DV"          ? [0.5,-0.5] : \
             cplace == "bottom_left" ? [0.5,-0.5] : \
             FindStr(cplace,"2020")>0? [0.5, 0.5] : \
             FindStr(cplace,"2100")>0? [0.5, 0.5] : \
             cplace == "top_left"    ? [0.5, 0.5] : \
             Assert (false, "Unsupported chroma placement mode.")

                  # ratioW:ratioH
    cplace = p_type4  ? [1,1] : \
             p_type2  ? [2,1] : \
             p_type1  ? [4,1] : \
             p_type0  ? [2,2] : \
             p_type10 ? [4,2] : \
             Assert (false, "Unsupported chroma placement mode.")

    point  = kernel=="Point" ? "+1.0" : ""
    cplaceU = ",src_left="+string(cloc[0]*(1-cplace[0]))+point
    cplaceV =  ",src_top="+string(cloc[1]*(1-cplace[1]))+point

    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplaceU + cplaceV + ")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplaceU + cplaceV + ",b=b,c=c)" : \
                kernel == "gauss"  ?     "GaussResize(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplaceU + cplaceV + ",p=p)"     : \
                                     kernel + "Resize(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplaceU + cplaceV + ")"

    Cb = p_type4 ? Cb : Eval("Cb." + resampler)
    Cr = p_type4 ? Cr : Eval("Cr." + resampler)

    CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type=p_type) }


# RGB to YcCbcCrc function (for Rec.2020CL)
function RGB_to_YcCbcCrc (clip Rx, clip Gx, clip Bx, string matrix, float_array coef, bool tv_in, bool tv_out) {

    UVf       = BitsPerComponent(Rx) < 32 ? "range_half +" : ""
    rangeC_PC = tv_in  ? "range_half - cmax cmin - / range_max * range_half + " : ""
    rangeC_TV = tv_out ? "range_half + cmax cmin - * range_max / cmin + "       : UVf

    s_gam = moncurve_coef(Rx, matrix)
    a  = 1.0 + s_gam[1]
    b  = 1.0 / s_gam[0]

    Pb =  2. * (a*(1.0 - pow(coef[2], b)))
    Pr =  2. * (a*(1.0 - pow(coef[0], b)))
    Nb = -2. * (a*(1.0 - pow(coef[0] + coef[1], b)) - 1.0)
    Nr = -2. * (a*(1.0 - pow(coef[1] + coef[2], b)) - 1.0)

    Rln   = moncurve_f(Rx, s_gam[0], s_gam[1], tv_in, false)
    Gln   = moncurve_f(Gx, s_gam[0], s_gam[1], tv_in, false)
    Bln   = moncurve_f(Bx, s_gam[0], s_gam[1], tv_in, false)
    Y     = Expr(Rln, Gln, Bln, "x "+string(coef[0])+" * y "+string(coef[1])+" * + z "+string(coef[2])+" * + ")
    Yx    = moncurve_r(Y,  s_gam[0], s_gam[1], false, false)

    Cb    = Expr(Bx,  Yx, Format("x "+rangeC_PC+" y - A@ 0 <= A {Nb} / A {Pb} / ? "+rangeC_TV+" "))
    Cr    = Expr(Rx,  Yx, Format("x "+rangeC_PC+" y - A@ 0 <= A {Nr} / A {Pr} / ? "+rangeC_TV+" "))
    Y     = !tv_out ? Yx : moncurve_r(Y,  s_gam[0], s_gam[1], false, true)

    [Y, Cb, Cr] }


# YcCbcCrc to RGB function (for Rec.2020CL)
function YcCbcCrc_to_RGB (clip Y, clip Cb, clip Cr, string matrix, float_array coef, bool tv_in, bool tv_out) {

    bdpth     = BitsPerComponent(Y) < 32

    UVf       = bdpth ? "range_half -" : ""
    UVf2      = bdpth ? "range_half +" : ""
    rangeC_PC = tv_in ? ""+UVf+" cmax cmin - / range_max *" : UVf

    s_gam = moncurve_coef(Y, matrix)
    a  = 1.0 + s_gam[1]
    b  = 1.0 / s_gam[0]

    Pb =  2. * (a*(1.0 - pow(coef[2], b)))
    Pr =  2. * (a*(1.0 - pow(coef[0], b)))
    Nb = -2. * (a*(1.0 - pow(coef[0] + coef[1], b)) - 1.0)
    Nr = -2. * (a*(1.0 - pow(coef[1] + coef[2], b)) - 1.0)

    Y  = moncurve_f(Y,  s_gam[0], s_gam[1], tv_in, false)

    Bx = Expr(Cb, Y, Format("x "+rangeC_PC+" A@ 0 <= A {Nb} * y "+UVf+" B@ + A {Pb} * B + ? "+UVf2+""))
    Rx = Expr(Cr, Y, Format("x "+rangeC_PC+" A@ 0 <= A {Nr} * y "+UVf+" B@ + A {Pr} * B + ? "+UVf2+""))

    Gx = Expr(Y, Bx, Rx, "x "+string(coef[2])+" y * - "+string(coef[0])+" z * - "+string(coef[1])+" / ")

    B = moncurve_r(Bx,  s_gam[0], s_gam[1], false, tv_out)
    R = moncurve_r(Rx,  s_gam[0], s_gam[1], false, tv_out)
    G = moncurve_r(Gx,  s_gam[0], s_gam[1], false, tv_out)

    [R, G, B] }


function Format_fuzzy_search (clip a, string format) {

    bdpth   = BitsPerComponent(a)
    format  = LeftStr(format,7)

    format =
\     (FindStr(format,  "12")>0 ) ? "YUV420P"
\   : (FindStr(format,  "16")>0 ) ? "YUV422P"
\   : (FindStr(format,  "24")>0 ) ? "YUV444P"
\   : (FindStr(format, "420")>0 ) ? "YUV420P"
\   : (FindStr(format, "422")>0 ) ? "YUV422P"
\   : (FindStr(format, "411")>0 ) ? "YUV411P"
\   : (FindStr(format, "444")>0 ) ? "YUV444P"
\   : (FindStr(format, "410")>0 ) ? "YUV9"
\   : (FindStr(format,"YUV9")>0 ) ? "YUV9"
\   : (FindStr(format, "RGB")>0 ) ? "RGBP"
\   : Assert (false, "Unsupported Color Format.")

    format = format=="YUV9" ? format : \
             bdpth < 32     ? format + string(bdpth) : format + "S"
    format }



function Matrix_fuzzy_search (string matrix) {

    matrix =
\     (matrix == "srgb"         ) ? "sRGB"
\   : (matrix == "jpeg"         ) ? "Rec601"
\   : (matrix == "jpg"          ) ? "Rec601"
\   : (matrix == "NTSC"         ) ? "Rec601"
\   : (FindStr(matrix, "601")>0 ) ? "Rec601"
\   : (FindStr(matrix, "525")>0 ) ? "Rec601"
\   : (FindStr(matrix, "170")>0 ) ? "Rec601"
\   : (FindStr(matrix, "240")>0 ) ? "240M"
\   : (matrix == "YCC"          ) ? "240M"
\   : (matrix == "PAL"          ) ? "470BG"
\   : (FindStr(matrix,"470" )>0 ) ? "470BG"
\   : (FindStr(matrix,"625" )>0 ) ? "470BG"
\   : (FindStr(matrix,"NCL" )>0 ) ? "Rec2020NCL"
\   : (FindStr(matrix,"CL"  )>0 ) ? "Rec2020CL"
\   : (FindStr(matrix,"2020")>0 ) ? "Rec2020NCL"
\   : (FindStr(matrix,"2084")>0 ) ? "Rec2020DV5"
\   : (FindStr(matrix,"2100")>0 ) ? "Rec2020DV5"
\   : (FindStr(matrix,"709" )>0 ) ? "Rec709"
\   : (FindStr(matrix,"1886")>0 ) ? "Rec709"
\   : (matrix == "Adobe"        ) ? "AdobeRGB"
\   : (matrix == "AdobeRGB"     ) ? "AdobeRGB"
\   : (FindStr(matrix, "DCI")>0 ) ? "DCI-P3"
\   : (matrix == "DCI"          ) ? "DCI-P3"
\   : (matrix == "P3"           ) ? "Display-P3"
\   : (FindStr(matrix,"Display")>0) ? "Display-P3"
\   : (matrix == "Display"      ) ? "Display-P3"
\   : (matrix == "AP1"          ) ? "ACEScg"
\   : (matrix == "AP0"          ) ? "ACES2065"
\   : (matrix == "ACEScg"       ) ? "ACEScg"
\   : (matrix == "ACES"         ) ? "ACES2065"
\   : Assert (false, "Unsupported Color Space.")

       matrix }



# NTSC and PAL YCbCr share the same coefficients defined in the link below, and derived from the old SMPTE 470M (NTSC 1953) standard.
# https://poynton.ca/PDFs/coloureq.pdf - 10.4
function Matrix_coef (string matrix) {

    matrix = Matrix_fuzzy_search (matrix)

    mat_i =
\     (matrix == "srgb"      ) ? 1
\   : (matrix == "Rec601"    ) ? 0
\   : (matrix == "240M"      ) ? 3
\   : (matrix == "470BG"     ) ? 0
\   : (matrix == "Rec2020CL" ) ? 5
\   : (matrix == "Rec2020NCL") ? 5
\   : (matrix == "Rec709"    ) ? 1
\   : (matrix == "AdobeRGB"  ) ? 6
\   : (matrix == "Display-P3") ? 7
\   : (matrix == "DCI-P3"    ) ? 8
\   : (matrix == "ACEScg"    ) ? 9
\   : (matrix == "ACES2065"  ) ? 10
\   : Assert (false, "Unsupported Color Space.")

    mat_w =
\     (matrix == "Rec601"         ) ? 0
\   : (matrix == "DCI-P3"         ) ? 2
\   : (matrix == "ACES2065"       ) ? 3
\   : (matrix == "ACEScg"         ) ? 3
\   :                                 1

    #                    NTSC 1953/YCbCr  IEC 61966-2-1/sRGB SMPTE 170M       Y’PbPr 601        PAL/SECAM         BT-2020/BT-2100   Adobe RGB (1998)  SMPTE RP 432-1    SMPTE RP 431-2    AP1                AP0
    #                    SMPTE 470M       ITU-R BT.709       ITU-R BT.601     SMPTE 240M        BT-470BG          BT-2020/BT-2100   Adobe RGB (1998)  Display-P3        DCI-P3            ACEScg             ACES2065-1
    pr = Select (mat_i,  [0.670,  0.330],  [0.640, 0.330],  [0.630,  0.340],  [0.630,  0.340],  [0.640,  0.330],  [0.708,  0.292],  [0.640,  0.330],  [0.680,  0.320],  [0.680,  0.320],  [0.713,   0.293],  [0.7347,  0.2653])
    pg = Select (mat_i,  [0.210,  0.710],  [0.300, 0.600],  [0.310,  0.595],  [0.310,  0.595],  [0.290,  0.600],  [0.170,  0.797],  [0.210,  0.710],  [0.265,  0.690],  [0.265,  0.690],  [0.165,   0.830],  [0.0000,  1.0000])
    pb = Select (mat_i,  [0.140,  0.080],  [0.150, 0.060],  [0.155,  0.070],  [0.155,  0.070],  [0.150,  0.060],  [0.131,  0.046],  [0.150,  0.060],  [0.150,  0.060],  [0.150,  0.060],  [0.128,   0.044],  [0.0001, -0.0770])
    pw = Select (mat_w,  [0.310,  0.316],  [0.312713, 0.329016],                                                                                                        [0.314,  0.351],  [0.32168,0.33767]                   )

    pr2 = 1. - pr[0] - pr[1]
    pb2 = 1. - pb[0] - pb[1]
    pg2 = 1. - pg[0] - pg[1]
    pw2 = 1. - pw[0] - pw[1]


    kr = (pr[1] * (pw[0] * (pg[1] * pb2 - pb[1] * pg2) + pw[1] * (pb[0] * pg2 - pg[0] * pb2) + pw2   * (pg[0] * pb[1] - pb[0] * pg[1]))) / \
         (pw[1] * (pr[0] * (pg[1] * pb2 - pb[1] * pg2) + pg[0] * (pb[1] * pr2 - pr[1] * pb2) + pb[0] * (pr[1] * pg2   - pg[1] * pr2)))

    kb = (pb[1] * (pw[0] * (pr[1] * pg2 - pg[1] * pr2) + pw[1] * (pg[0] * pr2 - pr[0] * pg2) + pw2   * (pr[0] * pg[1] - pg[0] * pr[1]))) / \
         (pw[1] * (pr[0] * (pg[1] * pb2 - pb[1] * pg2) + pg[0] * (pb[1] * pr2 - pr[1] * pb2) + pb[0] * (pr[1] * pg2   - pg[1] * pr2)))

    kg = 1. - kb - kr

    [kr, kg, kb] }




function RGB_to_XYZ (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    cspace = Matrix_fuzzy_search(cspace)

    matrix =        cspace == "sRGB" || cspace == "Rec709"                                              ?  \
                                        [ 0.41241079568862915, 0.21264933049678802, 0.01933175697922707,   \
                                          0.35758456587791443, 0.71516913175582890, 0.11919485777616501,   \
                                          0.18045382201671600, 0.07218152284622192, 0.95039016008377080] : \
                    cspace == "Rec601" || cspace == "240M"                                              ?  \
                                        [ 0.39354196190834045, 0.21238772571086884, 0.0187400933355093,    \
                                          0.36525884270668030, 0.70106136798858640, 0.1119341626763344,    \
                                          0.19164848327636720, 0.08655092865228653, 0.9582424163818359]  : \
                    cspace == "470BG"                                                                   ?  \
                                        [ 0.43057379126548767, 0.22201462090015410, 0.02018314599990845,   \
                                          0.34154993295669556, 0.70665508508682250, 0.12955342233181000,   \
                                          0.17832535505294800, 0.07133013755083084, 0.93918019533157350] : \
                    cspace == "DCI-P3"                                                                  ?  \
                                        [ 0.44516983628273010, 0.20949168503284454, 0.00000000000000000,   \
                                          0.27713435888290405, 0.72159516811370850, 0.04706055670976639,   \
                                          0.17228263616561890, 0.06891304999589920, 0.90735518932342530] : \
                    cspace == "Display-P3"                                                              ?  \
                                        [ 0.48659050464630127, 0.22898375988006592, 0.00000000000000000,   \
                                          0.26566821336746216, 0.69173991680145260, 0.04511347413063049,   \
                                          0.19819043576717377, 0.07927616685628891, 1.04380297660827640] : \
                    FindStr(cspace, "ec2")>0                                                            ?  \
                                        [ 0.63697350025177000, 0.24840137362480164, 0.00000000000000000,   \
                                          0.15294560790061950, 0.67799961566925050, 0.04253686964511871,   \
                                          0.11785808950662613, 0.03913172334432602, 1.06084382534027100] : \
                    cspace == "AdobeRGB"                                                                ?  \
                                        [ 0.57666999101638790, 0.29734000563621520, 0.02703000046312809,   \
                                          0.18556000292301178, 0.62735998630523680, 0.07068999856710434,   \
                                          0.18822999298572540, 0.07529000192880630, 0.99133998155593870] : \
                    cspace == "ACEScg"                                                                  ?  \
                                        [ 0.66332850000000000, 0.27258800000000000, 0.00000000000000000,   \
                                          0.13399166000000000, 0.67401860000000000, 0.00406035300000000,   \
                                          0.15532595000000000, 0.05339329000000000, 1.00476470000000000] : \
                    cspace == "ACES2065"                                                                ?  \
                                        [ 0.95253682136535640000,  0.34396082162857056, 0.0000000000000000,\
                                          0.00000000000000000000,  0.74020814895629880, 0.0000000000000000,\
                                          0.00010931033466476947, -0.08416896313428879, 1.0088251829147339]:\
                    Assert(false,"Unsupported Color Space.")

            list ? matrix : MatrixClip(rgb, matrix) }




function XYZ_to_RGB (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    cspace = Matrix_fuzzy_search(cspace)

    matrix =        cspace == "sRGB" || cspace == "Rec709"                                                  ?  \
                                        [  3.24081254005432130, -0.96924304962158200,  0.055638398975133896,   \
                                          -1.53730857372283940,  1.87596631050109860, -0.204007431864738460,   \
                                          -0.49858659505844116,  0.04155505076050758,  1.057129383087158200] : \
                    cspace == "Rec601" || cspace == "240M"                                              ?  \
                                        [  3.5058159828186035, -1.06904542446136470,  0.05631496384739876,     \
                                          -1.7396978139877320,  1.97777497768402100, -0.19700492918491364,     \
                                          -0.5440292358398438,  0.035171352326869965, 1.05010843276977540]   : \
                    cspace == "470BG"                                                                       ?  \
                                        [  3.0632193088531494, -0.96924340724945070,  0.06787130981683731,     \
                                          -1.3933255672454834,  1.87596678733825680, -0.22883385419845580,     \
                                          -0.4758017063140869,  0.04155505821108818,  1.06925129890441900]   : \
                    cspace == "DCI-P3"                                                                      ?  \
                                        [  2.72539401054382320, -0.7951681613922119,  0.041241902858018875,    \
                                          -1.01800286769866940,  1.6897321939468384, -0.087639048695564270,    \
                                          -0.44016319513320923,  0.0226471945643425,  1.100929737091064500]  : \
                    cspace == "Display-P3"                                                                  ?  \
                                        [  2.49339652061462400, -0.82948720455169680,  0.035850685089826584,   \
                                          -0.93134605884552000,  1.76266026496887200, -0.076182708144187930,   \
                                          -0.40269458293914795,  0.02362464182078838,  0.957014024257659900] : \
                    FindStr(cspace, "ec2")>0                                                                ?  \
                                        [  1.71660947799682620, -0.66668272018432620,  0.017642205581068993,   \
                                          -0.35566213726997375,  1.61647748947143550, -0.042776308953762054,   \
                                          -0.25336012244224550,  0.01576850563287735,  0.942228555679321300] : \
                    cspace == "AdobeRGB"                                                                    ?  \
                                        [  2.04158997535705570, -0.96924000978469850,  0.013439999893307686,   \
                                          -0.56501001119613650,  1.87597000598907470, -0.118359997868537900,   \
                                          -0.34472998976707460,  0.04156000167131424,  1.015169978141784700] : \
                    cspace == "ACEScg"                                                                      ?  \
                                        [  1.64102330000000000, -0.66387850000000000,  0.002682799000000000,   \
                                          -0.32480330000000000,  1.61551320000000000, -0.006528448000000000,   \
                                          -0.23642470000000000,  0.01678004000000000,  0.995190000000000000] : \
                    cspace == "ACES2065"                                                                    ?  \
                                        [  1.04982817173004150000, -0.48783543705940247, 0.0000000000000000,   \
                                           0.00000000000000000000,  1.35097146034240720, 0.0000000000000000,   \
                                          -0.00011375317990314215,  0.11276797950267792, 0.9912520051002502] : \
                     Assert(false,"Unsupported Color Space.")

            list ? matrix : MatrixClip(rgb, matrix) }


function moncurve_coef (clip c, string "matrix") {

    matrix = Default (matrix, "sRGB")
    matrix = Matrix_fuzzy_search(matrix)

    t_num =
\     (matrix == "sRGB"       ) ? 0
\   : (matrix == "jpeg"       ) ? 0
\   : (matrix == "jpg"        ) ? 0
\   : (matrix == "Rec601"     ) ? 1
\   : (matrix == "240M"       ) ? 2
\   : (matrix == "470BG"      ) ? 3
\   : (matrix == "Rec2020"    ) ? 4
\   : (matrix == "Rec2020CL"  ) ? 4
\   : (matrix == "Rec2020NCL" ) ? 4
\   : (matrix == "Rec2020DVp5") ? 4
\   : (matrix == "Rec709"     ) ? 5
\   : (matrix == "AdobeRGB"   ) ? 6
\   : (matrix == "Display-P3" ) ? 0
\   : (matrix == "DCI-P3"     ) ? 7
\   : (matrix == "ACEScg"     ) ? 8
\   : (matrix == "ACES2065"   ) ? 8
\   : Assert (false, "Unsupported Color Space.")

    bdpth = BitsPerComponent(c) > 10 ? 0.09929682680944 : 0.099

    #                                  SMPTE-C     Y’PbPr 601  PAL/SECAM BT-2020    Rec.709    AdobeRGB     DCI-P3   AP1/AP0
    #                         sRGB     SMPTE 170M  SMPTE 240M  BT-470BG  BT-2020    BT-1886    AdobeRGB     DCI-P3      ACES
    t_temp  = Select (t_num,  6504   ,  6504   ,   6504   ,    6504   ,      6504,   6504   ,      6504 ,   6305  ,     6000 )
    t_off   = Select (t_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,    0      ,   0     ,      0   )
    t_gamma = Select (t_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,   563/256.,   2.60  ,      1.0 )

    return [t_gamma, t_off] }



# Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_f (clip c, float "gamma", float "offs", bool "tv_range_in", bool "tv_range_out") {

    gamma = Default(gamma, 2.222)  # gamma
    offs  = Default(offs,   0.0 )  # extension of the linear part

    c
    ptype  = IsRGB()
    contoy = !isy()

    tv_range_in  = Default(tv_range_in,  !ptype)
    tv_range_out = Default(tv_range_out, !ptype)

    rangePC = tv_range_in  ? "x ymin - ymax ymin - /"           : "x range_max /"
    rangeTV = tv_range_out ? "ymax ymin - * range_max / ymin +" : ""
    fs  = "{gamma} 1 - {offs} / {offs} {gamma} * {gamma} 1 - 1 {offs} + * / {gamma} ^ *"
    xb  = "{offs} {gamma} 1 - /"
    out = offs > 0.0 ? Format("range_max range_min "+rangePC+" max min A@ "+xb+" > A {offs} + 1 {offs} + / {gamma} ^ range_max * A "+fs+" * range_max * ? "+rangeTV+"") : \
                       Format("range_max range_min "+rangePC+" max min {gamma} ^ range_max * "+rangeTV+"")

    cplane  = contoy ? ptype ? out : "" : Undefined

    gamma <= 1.0 ? last : \
    Expr(out,cplane,cplane) }




# Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_r (clip c, float "gamma", float "offs", bool "tv_range_in", bool "tv_range_out") {

    gamma = Default(gamma, 2.222)  # gamma
    offs  = Default(offs,   0.0 )  # extension of the linear part

    c
    ptype  = IsRGB()
    contoy = !isy()

    tv_range_in  = Default(tv_range_in,  !ptype)
    tv_range_out = Default(tv_range_out, !ptype)

    rangePC = tv_range_in  ? "x ymin - ymax ymin - /"           : "x range_max /"
    rangeTV = tv_range_out ? "ymax ymin - * range_max / ymin +" : ""
    yb  = "{offs} {gamma} * {gamma} 1 - 1 {offs} + * / {gamma} ^"
    rs  = "{gamma} 1 - {offs} / {gamma} 1 - ^ 1 {offs} + {gamma} / {gamma} ^ *"
    out = offs > 0.0 ? Format("range_max range_min "+rangePC+" max min A@ "+yb+" > 1 {offs} + A 1 {gamma} / ^ * {offs} - range_max * A "+rs+" * range_max * ? "+rangeTV+"") : \
                       Format("range_max range_min "+rangePC+" max min 1 {gamma} / ^ range_max * "+rangeTV+"")

    cplane  = contoy ? ptype ? out : "" : Undefined

    gamma <= 1.0 ? last : \
    Expr(out,cplane,cplane) }



function SMPTE_legal (clip c, bool "forward") {

    fw = Default(forward, true)    # forward converts to SMPTE legal, otherwise converts to Full Range.
    Assert (IsRGB(c), "YUV is not supported.")

    Expr(c, fw ? "x ymax ymin - * range_max / ymin + " : "x ymin - ymax ymin - / range_max *") }



function MatrixClip ( clip rgb, float_array mat) {

    # clip · 3x3
    R = DotClip(rgb,[mat[0],mat[3],mat[6]])
    G = DotClip(rgb,[mat[1],mat[4],mat[7]])
    B = DotClip(rgb,[mat[2],mat[5],mat[8]])

    CombinePlanes(R, G, B, planes="RGB", sample_clip=rgb) }



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




function DotClip ( clip rgb, float_array vec) {

    # clip · 1x3
    Expr(ExtractR(rgb), \
         ExtractG(rgb), \
         ExtractB(rgb), "x "+string(vec[0])+" * y "+string(vec[1])+" * + z "+string(vec[2])+" * +") }



function MatrixDiv ( float_array mat1, \
                     float_array mat2) {

    asize = ArraySize(mat1)
    str = ""
    for (i=0, asize, 1) {
        cm = asize == i+1 ? "" : ","
        str = str + string(mat1[i] / mat2[i]) + cm
        i   = asize == i+1 ? asize : i
       }

    result = "["+str+"]"
    Eval(result) }
