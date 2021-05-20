###########################################################
###                                                      ##
###                                                      ##
###    Transforms Pack v1.0 RC6  (20-05-2021)            ##
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
### Dependencies: AviSynth+ r2724+
###
###
####################################


function ColorSpace (clip clp, string "source", string "target", bool "gamut", bool "gamma", bool "tv_range_in", bool "tv_range_out") {

    gamut       = Default (gamut, true)           # convert gamut
    gamma       = Default (gamma, true)           # convert gamma
    tv_range_in = Default (tv_range_in,  !isRGB(clp) )
    tv_range_out= Default (tv_range_out, tv_range_in )

    src = Matrix_fuzzy_search (source)
    tgt = Matrix_fuzzy_search (target)

    s_num =
\     (src == "sRGB"      ) ? 0
\   : (source == "jpeg"   ) ? 0
\   : (source == "jpg"    ) ? 0
\   : (src == "Rec601"    ) ? 1
\   : (src == "240M"      ) ? 2
\   : (src == "470BG"     ) ? 3
\   : (src == "Rec2020"   ) ? 4
\   : (src == "Rec2020CL" ) ? 4
\   : (src == "Rec2020DVp5") ? 4
\   : (src == "Rec709"    ) ? 5
\   : (src == "AdobeRGB"  ) ? 6
\   : (src == "Display-P3") ? 0
\   : (src == "DCI-P3"    ) ? 7
\   : (src == "ACEScg"    ) ? 8
\   : (src == "ACES2065"  ) ? 8
\   : Assert (false, "Unsupported Color Space.")

    t_num =
\     (tgt == "sRGB"      ) ? 0
\   : (target == "jpeg"   ) ? 0
\   : (target == "jpg"    ) ? 0
\   : (tgt == "Rec601"    ) ? 1
\   : (tgt == "240M"      ) ? 2
\   : (tgt == "470BG"     ) ? 3
\   : (tgt == "Rec2020"   ) ? 4
\   : (tgt == "Rec2020CL" ) ? 4
\   : (tgt == "Rec2020DVp5") ? 4
\   : (tgt == "Rec709"    ) ? 5
\   : (tgt == "AdobeRGB"  ) ? 6
\   : (tgt == "Display-P3") ? 0
\   : (tgt == "DCI-P3"    ) ? 7
\   : (tgt == "ACEScg"    ) ? 8
\   : (tgt == "ACES2065"  ) ? 8
\   : Assert (false, "Unsupported Color Space.")

    bdpth = BitsPerComponent(clp) > 10 ? 0.09929682680944 : 0.099

    #                                  SMPTE-C     Y’PbPr 601  PAL/SECAM BT-2020    Rec.709    AdobeRGB     DCI-P3   AP1/AP0
    #                         sRGB     SMPTE 170M  SMPTE 240M  BT-470BG  BT-2020    BT-1886    AdobeRGB     DCI-P3      ACES
    t_temp  = Select (t_num,  6504   ,  6504   ,   6504   ,    6504   ,      6504,   6504   ,      6504 ,   6305  ,     6000 )
    s_off   = Select (s_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,    0      ,   0     ,      0   )
    s_gamma = Select (s_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,    2.1992 ,   2.60  ,      1.0 )

    t_off   = Select (t_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,    0      ,   0     ,      0   )
    t_gamma = Select (t_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,    2.1992 ,   2.60  ,      1.0 )


    clp

    IsRGB(clp) ? ConvertToPlanarRGB(src) : \
    YUV_to_RGB(src, tv_range_in=tv_range_in, kernel="Point")

    moncurve_f(s_gamma, s_off, false)

    if (gamut) {
    mata = RGB_to_XYZ(src, list=true)
    matb = XYZ_to_RGB(tgt, list=true)
    MatrixClip( MatrixDot(mata, matb) ) }

    t_num==9 ? last : gamma ? moncurve_r(t_gamma, t_off, false) : !gamma && gamut ? moncurve_r(s_gamma, s_off, false) : last

    IsRGB(clp) ? last : \
    RGB_to_YUV( tgt, tv_range_out=tv_range_out, kernel="Point", pixel_type=PixelType(clp)) }




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

    noop = source == disp_ref

    src = Matrix_fuzzy_search (source)
    tgt = Matrix_fuzzy_search (disp_ref)

    s_num =
\     (src == "sRGB"      ) ? 0
\   : (source == "jpeg"   ) ? 0
\   : (source == "jpg"    ) ? 0
\   : (src == "Rec601"    ) ? 1
\   : (src == "240M"      ) ? 2
\   : (src == "470BG"     ) ? 3
\   : (src == "Rec2020"   ) ? 4
\   : (src == "Rec709"    ) ? 5
\   : (src == "AdobeRGB"  ) ? 6
\   : (src == "Display-P3") ? 0
\   : (src == "DCI-P3"    ) ? 7
\   : (src == "ACEScg"    ) ? 8
\   : (src == "ACES2065"  ) ? 8
\   : Assert (false, "Unsupported Color Space.")

    t_num =
\     (tgt == "sRGB"      ) ? 0
\   : (disp_ref == "jpeg" ) ? 0
\   : (disp_ref == "jpg"  ) ? 0
\   : (tgt == "Rec601"    ) ? 1
\   : (tgt == "240M"      ) ? 2
\   : (tgt == "470BG"     ) ? 3
\   : (tgt == "Rec2020"   ) ? 4
\   : (tgt == "Rec709"    ) ? 5
\   : (tgt == "AdobeRGB"  ) ? 6
\   : (tgt == "Display-P3") ? 0
\   : (tgt == "DCI-P3"    ) ? 7
\   : (tgt == "ACEScg"    ) ? 8
\   : (tgt == "ACES2065"  ) ? 8
\   : Assert (false, "Unsupported Color Space.")


    bdpth = BitsPerComponent(clp) > 10 ? 0.09929682680944 : 0.099

    #                                  SMPTE-C     Y’PbPr 601  PAL/SECAM BT-2020    Rec.709    AdobeRGB     DCI-P3   AP1/AP0
    #                         sRGB     SMPTE 170M  SMPTE 240M  BT-470BG  BT-2020    BT-1886    AdobeRGB     DCI-P3      ACES
    t_temp  = Select (t_num,  6504   ,  6504   ,   6504   ,    6504   ,      6504,   6504   ,      6504 ,   6305  ,     6000 )
    s_off   = Select (s_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,    0      ,   0     ,      0   )
    s_gamma = Select (s_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,    2.1992 ,   2.60  ,      1.0 )

    t_off   = Select (t_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,    0      ,   0     ,      0   )
    t_gamma = Select (t_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,    2.1992 ,   2.60  ,      1.0 )


    clp.ConvertBits(16)

    IsRGB(clp) ? ConvertToPlanarRGB(src) : \
    YUV_to_RGB(src, tv_range_in=tv_range, kernel=kernel, b=b, c=c, p=p)

    !noop ? moncurve_f(s_gamma, s_off, false) : last

    if (gamut && !noop) {
    mata = RGB_to_XYZ(src, list=true)
    matb = XYZ_to_RGB(tgt, list=true)
    MatrixClip( MatrixDot(mata, matb) ) }

    Defined(LUT) || gamma ? moncurve_r(t_gamma, t_off, false) : !gamma && gamut ? moncurve_r(s_gamma, s_off, false) : last

    Defined(LUT) ? Cube(LUT, 4, true) : last

    ConvertBits(8, dither=1)  }




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
\   : (FindStr(matrix,"470")>0  ) ? "470BG"
\   : (FindStr(matrix,"625")>0  ) ? "470BG"
\   : (FindStr(matrix,"2020")>0 ) ? "Rec2020"
\   : (FindStr(matrix,"2100")>0 ) ? "Rec2020CL"
\   : (FindStr(matrix,"2084")>0 ) ? "Rec2020CL"
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




function YUV_to_RGB (clip yuv, string "matrix", bool "tv_range_in", bool "tv_range_out", string "kernel", string "cplace", float "b", float "c", float "p") {

    matrix     = Default (matrix, "709")
    kernel     = Default (kernel, "Bicubic")
    cplace     = Default (cplace, "MPEG2")
    tv_in      = Default (tv_range_in, true)
    tv_out     = Default (tv_range_out, false)
    b          = Default (b, 0.0)
    c          = Default (c, 0.75) # Precise Bicubic
    p          = Default (p, 0.25)

    Assert(AvsPlusVersionNumber > 2724, "Update AviSynth+ version")

    coef = Matrix_coef(matrix)

    # Adapted from Dither_convert_yuv_to_rgb()
    scale_y  = tv_in ? (256. / 219.) : 1.0
    scale_uv = tv_in ? (256. / 112.) : 2.0

    Kr = 1. - coef[0]
    Kb = 1. - coef[2]

    m1 = scale_y
    m2 = 0.0
    m3 = scale_uv * Kr
    m4 = scale_y
    m5 = scale_uv * ( -Kb * coef[2] / coef[1])
    m6 = scale_uv * ( -Kr * coef[0] / coef[1])
    m7 = scale_y
    m8 = scale_uv * Kb
    m9 = 0.0

    mat = [m1,m2,m3,m4,m5,m6,m7,m8,m9]

    w =  width(yuv)
    h = height(yuv)

    cplace = is444(yuv) ? ",src_left=0.0" : cplace=="MPEG2" ? ",src_left=0.25" : ",src_left=0.0"
    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(w) + "," + String(h) + cplace +")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(w) + "," + String(h) + cplace +",b=b,c=c)" : \
                kernel == "gauss"  ?     "GaussResize(" + String(w) + "," + String(h) + cplace +",p=p)"     : \
                                     kernel + "Resize(" + String(w) + "," + String(h) + cplace +")"

    Y = ExtractY(yuv)
    U = Eval("ExtractU(yuv)." + resampler)
    V = Eval("ExtractV(yuv)." + resampler)

    rangeY   = tv_out ? "" : "ymin -"
    range_TV = tv_out ? "ymax ymin - * range_max /" : ""

    R = mat[1]==0.0 ? Expr(Y,    V, "x "+rangeY+" "+string(mat[0])+" *                                       y range_half - "+string(mat[2])+" * + "+range_TV+"") : \
                      Expr(Y, U, V, "x "+rangeY+" "+string(mat[0])+" * y range_half - "+string(mat[1])+" * + z range_half - "+string(mat[2])+" * + "+range_TV+"")
    G =               Expr(Y, U, V, "x "+rangeY+" "+string(mat[3])+" * y range_half - "+string(mat[4])+" * + z range_half - "+string(mat[5])+" * + "+range_TV+"")
    B = mat[8]==0.0 ? Expr(Y, U,    "x "+rangeY+" "+string(mat[6])+" * y range_half - "+string(mat[7])+" * + "+range_TV+"")                                        : \
                      Expr(Y, U, V, "x "+rangeY+" "+string(mat[6])+" * y range_half - "+string(mat[7])+" * + z range_half - "+string(mat[8])+" * + "+range_TV+"")

    CombinePlanes(R, G, B, planes="RGB")

    # Limiting (clipping) for color excursions when gamut mapping
    tv_out ? Expr("x ymin ymax clip") : last}



function RGB_to_YUV (clip rgb, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", string "cplace", float "b", float "c", float "p") {

    matrix     = Default (matrix, "709")
    kernel     = Default (kernel, "Bicubic")
    cplace     = Default (cplace, "MPEG2")
    pixel_type = Default (pixel_type, "420")
    tv_in      = Default (tv_range_in, false)
    tv_out     = Default (tv_range_out, true)
    b          = Default (b, -0.5)
    c          = Default (c, 0.25) # Didée's Bicubic
    p          = Default (p, 0.25)

    Assert(AvsPlusVersionNumber > 2724, "Update AviSynth+ version")

    w =  width(rgb)
    h = height(rgb)

    bdpth   = BitsPerComponent(rgb)
    p_type4 = FindStr(pixel_type, "44")>0
    p_type2 = FindStr(pixel_type, "22")>0
    p_type1 = FindStr(pixel_type, "11")>0
    p_type0 = FindStr(pixel_type, "20")>0

    p_type2 || p_type0 ? Assert (w%2==0, "Width is not mod2." ) : nop()
                         Assert (h%2==0, "Height is not mod2.")
    p_type1            ? Assert (w%4==0, "Width is not mod4." ) : nop()

    coef   = Matrix_coef(matrix)
    matrix = Matrix_fuzzy_search (matrix)

    # Adapted from Dither_convert_rgb_to_yuv()
    scale_y  = !tv_in && tv_out ? (219. / 256.) : 1.0
    scale_uv = !tv_in && tv_out ? (112. / 256.) : 0.5

    Kr = 1. - coef[0]
    Kb = 1. - coef[2]

    m1 = scale_y  * coef[0]
    m2 = scale_y  * coef[1]
    m3 = scale_y  * coef[2]
    m4 = scale_uv * (-coef[0] / Kb)
    m5 = scale_uv * (-coef[1] / Kb)
    m6 = scale_uv
    m7 = scale_uv
    m8 = scale_uv * (-coef[1] / Kr)
    m9 = scale_uv * (-coef[2] / Kr)

    mat = [m1,m2,m3,m4,m5,m6,m7,m8,m9]


    p_type = p_type4 ? "YUV444P" : p_type2 ? "YUV422P" : p_type1 ? "YUV411P" : "YUV420P"
    p_type = string(bdpth) == "32" ? p_type + "S" : p_type + string(bdpth)
    nw = p_type1 ? round(w/4.0) : round(w/2.0)
    nh =                          round(h/2.0)

#   rgb = rgb.ConvertToRGB32(matrix)   # There's some bitshift issue where only the tv range code works in RGB32, and not RGB64 for example
    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)

    rangeY_TV = tv_out ? tv_in ? "" : "ymin +" : tv_in ? "ymin - ymax ymin - / range_max *" : ""
    rangeC_TV = !tv_out && tv_in ? "range_half - cmax cmin - / range_max * range_half +" : ""

    Y  = Expr(Rx, Gx, Bx, "           x "+string(mat[0])+" *   y "+string(mat[1])+" * + z "+string(mat[2])+" * + "+rangeY_TV+"")
    Cb = Expr(Rx, Gx, Bx, "range_half x "+string(mat[3])+" * + y "+string(mat[4])+" * + z "+string(mat[5])+" * + "+rangeC_TV+"")
    Cr = Expr(Rx, Gx, Bx, "range_half x "+string(mat[6])+" * + y "+string(mat[7])+" * + z "+string(mat[8])+" * + "+rangeC_TV+"")

    point  = kernel=="Point" ? "+1.0" : ""
    cplace = p_type4 || cplace=="MPEG2" ? ",src_left=-0.50"+point : ",src_left=0.0"+point
    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplace + ")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplace + ",b=b,c=c)" : \
                kernel == "gauss"  ?     "GaussResize(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplace + ",p=p)"     : \
                                     kernel + "Resize(" + String(nw+nw%2) + "," + String(p_type2 || p_type1 ? h : nh+nh%2) + cplace + ")"

    Cb = p_type4 ? Cb : Eval("Cb." + resampler)
    Cr = p_type4 ? Cr : Eval("Cr." + resampler)

    CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type=p_type)

    # Limiting (clipping) for color excursions when gamut mapping
    Limiter(min_luma=0, max_luma=255, paramscale=true) }


# WIP
# This is for Rec.2020CL -> Rec. ITU-R BT.2020-2 (Constant Luminance)
function RGB_to_YcCbcCrc (clip rgb, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", string "cplace", float "b", float "c", float "p") {


    Y = Expr(Rx, Gx, Bx, " x "+string(coef[0])+" * 1 "+string(coef[0])+" - "+string(coef[2])+" - y * + z "+string(coef[2])+" * +")
    Pb = 1.0 - coef[2]
    Pr = 1.0 - coef[0]
    Cb = Expr(Bx, Y, Format("x y - A@ {Pb} <= A 0 <= A 2 -{Pb} * / A 2 {Pb} * / ? {Pb} ? "))
    Cr = Expr(Rx, Y, Format("x y - A@ {Pr} <= A 0 <= A 2 -{Pr} * / A 2 {Pr} * / ? {Pr} ? "))

}


# WIP
# SMPTE ST 2085 (2015) (HDR CIE-XYZ space)
function RGB_to_YDzDx (clip rgb, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", string "cplace", float "b", float "c", float "p") {

    Y = Gx
    Cb = Expr(Bx, Y, "x 0.986566 * y - 2 /")
    Cr = Expr(Rx, Y, "x 0.991902 y * - 2 /")

}

# WIP
# SMPTE ST 2085 (2015)
# Implement Dolby IPTPQc2/IPT (IPT-PQ)
function RGB_to_ICtCp (clip rgb, bool "IPT", string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", string "cplace", float "b", float "c", float "p") {

    # to RGBPS (RGB 32-bit float)
    IsRGB(rgb) ? ConvertToPlanarRGB(rgb).ConvertBits(32) : \
    Assert (false, "Unsupported Color Space.")

    # Full range RGB
    RGB_lin = st_2084_eotf()

    # crosstalk 4% but Dolby Vision uses 2%
    Crosstalk = [ 1-2*0.04,     0.04,     0.04, \
                      0.04, 1-2*0.04,     0.04,\
                      0.04,     0.04, 1-2*0.04]


    LMS = [ 1688. / 4096, 2146. / 4096,  262. / 4096, \
             683. / 4096, 2951. / 4096,  462. / 4096, \
              99. / 4096, 309.  / 4096, 3688. / 4096]

    LMS = MatrixClip(RGB_lin, LMS)

    LMS_gam = st_2084_inverse_eotf(LMS)

    ICtCp = [ 2048. / 4096,   2048. / 4096,           0.0, \
              6610. / 4096, -13613. / 4096,  7003. / 4096, \
             17933. / 4096, -17390. / 4096,  -543. / 4096]

    # ARIB_B67 (for HLG)
    ICtCp_B67 = [ 2048. / 4096,  2048. / 4096,           0.0, \
                  3625. / 4096, -7465. / 4096,  3840. / 4096, \
                  9500. / 4096, -9212. / 4096,  -288. / 4096]

    ICtCp =  MatrixClip(LMS_gam, ICtCp)


    ICtCp
}

# WIP
# SMPTE ST 2085 (2015)
function ICtCp_to_RGB (clip ICtCp, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", string "cplace", float "b", float "c", float "p") {


    LMS = [ 1688. / 4096, 2146. / 4096,  262. / 4096, \
             683. / 4096, 2951. / 4096,  462. / 4096, \
              99. / 4096, 309.  / 4096, 3688. / 4096]

    LMSinv = MatrixInvert (LMS)
    LMS = MatrixClip(ICtCp, LMSinv)

    LMS_lin = st_2084_eotf(LMS)


    ICtCp = [ 2048. / 4096,   2048. / 4096,           0.0, \
              6610. / 4096, -13613. / 4096,  7003. / 4096, \
             17933. / 4096, -17390. / 4096,  -543. / 4096]

    # ARIB_B67 (for HLG)
    ICtCp_B67 = [ 2048. / 4096,  2048. / 4096,           0.0, \
                  3625. / 4096, -7465. / 4096,  3840. / 4096, \
                  9500. / 4096, -9212. / 4096,  -288. / 4096]

    ICtCp_inv = MatrixInvert (ICtCp)
    RGB_lin =  MatrixClip(LMS_lin, ICtCp_inv)
    RGB = st_2084_inverse_eotf(RGB_lin)

    RGB
}



# Adapted from zimg
function st_2084_eotf (clip c, int "MasterLevel")
{
    PL        = Default (MasterLevel, 4000) # Max Mastering Level in Nits (1000 - 10000)
    PL        = PL / 10000.

    ST2084_N1 = 2610./4096 * 0.25
    ST2084_M1 = 2523./4096 * 128
    ST2084_C1 = 3424./4096   # or 1 + c3 -c2
    ST2084_C2 = 2413./4096 * 32
    ST2084_C3 = 2392./4096 * 32

    HLG_A = 0.17883277
    HLG_B = 0.28466892
    HLG_C = 0.55991073

    ConvertToPlanarRGB(c)
    Expr(Format("x {PL} {ST2084_M1} / ^ A^ x 0.0 > A {ST2084_C1} - 0.0 max {ST2084_C2} {ST2084_C3} A * - 0.0 max / {PL} {ST2084_N1} / ^ 0.0 ?"))

}

# Adapted from zimg
function st_2084_inverse_eotf (clip c, int "MasterLevel")
{
    PL        = Default (MasterLevel, 4000) # Max Mastering Level in Nits
    PL        = PL / 10000.

    ST2084_N1 = 2610./4096 * 0.25
    ST2084_M1 = 2523./4096 * 128
    ST2084_C1 = 3424./4096   # or 1 + c3 -c2
    ST2084_C2 = 2413./4096 * 32
    ST2084_C3 = 2392./4096 * 32

    # From BT.2124-0 Annex 2 Conversion 3
    ConvertToPlanarRGB(c)
    Expr(Format("x {ST2084_N1} ^ A^ x 0.0 > {ST2084_C1} {ST2084_C2} A * + {PL} {ST2084_C3} A * + / {ST2084_M1} ^ 0.0 ?"))

}

# WIP
# Implement Dolby Vision Profile 5 (IPTPQc2 or IPT-PQ) (saves 10% of bitrate when encoded at 12-bits HEVC)
function RGB_to_IPT (clip rgb, bool "IPT", string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", string "cplace", float "b", float "c", float "p") {

    # to RGBPS (RGB 32-bit float)
    IsRGB(rgb) ? ConvertToPlanarRGB(rgb).ConvertBits(32) : \
    Assert (false, "Unsupported Color Space.")

#        // Similar to ICtCp above, but with a proprietary matrix. The code
#        // to generate this is identical, but with the crosstalk factor
#        // set to 0.02 (instead of 0.04).
#        static const char *dvipt_lms2rgb = "mat3("
#            " 3.238998, -0.719461, -0.002862, "
#            "-2.272734,  1.874998, -0.268066, "
#            " 0.086733, -0.158947,  1.074494) ";


}

# NTSC and PAL YCbCr share the same coefficients defined in the link below, and derived from the old NTSC 1953 standard.
# https://poynton.ca/PDFs/coloureq.pdf - 10.4
function Matrix_coef (string matrix) {

    matrix = Matrix_fuzzy_search (matrix)

    # Rec601 (SMPTE 170M) kept the YUV<->RGB coefficients from SMPTE 470M (NTSC 1953)
    mat_i =
\     (matrix == "srgb"      ) ? 1
\   : (matrix == "Rec601"    ) ? 0
\   : (matrix == "240M"      ) ? 3
\   : (matrix == "470BG"     ) ? 0
\   : (matrix == "Rec2020"   ) ? 5
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

    #                    NTSC 1953/YCbCr  IEC 61966-2-1/sRGB SMPTE 170M       Y’PbPr 601        PAL/SECAM         BT-2020/BT-2100   Adobe RGB (1998)  Display-P3        DCI-P3            AP1                AP0
    #                    SMPTE 470M       ITU-R BT.709       ITU-R BT.601     SMPTE 240M        BT-470BG          BT-2020/BT-2100   Adobe RGB (1998)  P3-D65            DCI-P3            ACEScg             ACES2065-1
    pr = Select (mat_i,  [0.670,  0.330],  [0.640, 0.330],  [0.630,  0.340],  [0.630,  0.340],  [0.640,  0.330],  [0.708,  0.292],  [0.640,  0.330],  [0.680,  0.320],  [0.680,  0.320],  [0.713,   0.293],  [0.7347,  0.2653])
    pg = Select (mat_i,  [0.210,  0.710],  [0.300, 0.600],  [0.310,  0.595],  [0.310,  0.595],  [0.290,  0.600],  [0.170,  0.797],  [0.210,  0.710],  [0.265,  0.690],  [0.265,  0.690],  [0.165,   0.830],  [0.0000,  1.0000])
    pb = Select (mat_i,  [0.140,  0.080],  [0.150, 0.060],  [0.155,  0.070],  [0.155,  0.070],  [0.150,  0.060],  [0.131,  0.046],  [0.150,  0.060],  [0.150,  0.060],  [0.150,  0.060],  [0.128,   0.044],  [0.0001, -0.0770])
    pw = Select (mat_w,  [0.310,  0.316],  [0.312713, 0.329016],                                                                                                        [0.314,  0.351],  [0.32168,0.33767], [0.32168, 0.33767])

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




function WhitePoint (clip c, int "temperature", string "matrix", bool "tv_range") {

    temp        = Default (temperature, 6504)  # Target temperature in Kelvin (Default: D65 == nop())
    matrix      = Default (matrix, "sRGB")
    tv_range    = Default (tv_range,  !isRGB(c) )

    matrix = Matrix_fuzzy_search (matrix)
	
	RGBsrc = IsRGB(c)
	RGBpln = RGBsrc ? IsPlanar(c) : false
	
    RGBsrc ? RGBpln ? c : ConvertToPlanarRGB(c) : \
    YUV_to_RGB(c, matrix, tv_range_in=tv_range, tv_range_out=false, kernel="Point")


    temp3 = 1000.       / temp
    temp6 = 1000000.    / pow(temp, 2.)
    temp9 = 1000000000. / pow(temp, 3.)

    wpx = (temp <= 7000.) ? 0.244063 + 0.09911 * temp3 + 2.9678 * temp6 - 4.6070 * temp9 : \
                            0.237040 + 0.24748 * temp3 + 1.9018 * temp6 - 2.0064 * temp9

    wpy = -3. * pow(wpx,2.) + 2.870 * wpx - 0.275
    wpz = 1. - wpx - wpy

    CAT02 = [0.7328,  0.4296, -0.1624, \
            -0.70360, 1.6975,  0.0061, \
             0.003,  -0.0136,  0.9834]

    fw1       = MatrixDot([wpx/wpy,1.,wpz/wpy] ,CAT02)
    fw2       = MatrixDot([0.95045,1.,1.088917],CAT02)
    fw_trans  = MatrixDiv(fw1,fw2)

    RGB_to_XYZ(matrix)
    Expr(last,string(fw_trans[0])+" x *",string(fw_trans[1])+" x *",string(fw_trans[2])+" x *")
    XYZ_to_RGB(matrix)

    RGBsrc ? RGBpln : last : MatchColorFormat(c) : \
    RGB_to_YUV( matrix, tv_range_in=false, tv_range_out=tv_range, kernel="Point", pixel_type=PixelType(c)) }




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
                    cspace == "Rec2020"                                                                 ?  \
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
                    cspace == "Rec2020"                                                                     ?  \
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



# Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_f (clip c, float "gamma", float "offs", bool "tv_range_in", bool "tv_range_out") {

    gamma = Default(gamma, 2.222)  # gamma
    offs  = Default(offs,   0.0 )  # extension of the linear part

    ptype  = IsPlanarRGB(c)
    contoy = !isy(c)

    tv_range_in  = Default(tv_range_in,  !ptype)
    tv_range_out = Default(tv_range_out, !ptype)

    c
    rangePC = tv_range_in  ? "x ymin - ymax ymin - /"           : "x range_max /"
    rangeTV = tv_range_out ? "ymax ymin - * range_max / ymin +" : ""
    fs  = "{gamma} 1 - {offs} / {offs} {gamma} * {gamma} 1 - 1 {offs} + * / {gamma} ^ *"
    xb  = "{offs} {gamma} 1 - /"
    out = offs > 0.0 ? Format(""+rangePC+" A@ "+xb+" > A {offs} + 1 {offs} + / {gamma} ^ range_max * A "+fs+" * range_max * ? "+rangeTV+"") : \
                       Format(""+rangePC+" {gamma} ^ range_max * "+rangeTV+"")

    cplane  = contoy ? ptype ? out : "" : Undefined

    gamma <= 1.0 ? last : \
    Expr(out,cplane,cplane) }




# Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_r (clip c, float "gamma", float "offs", bool "tv_range_in", bool "tv_range_out") {

    gamma = Default(gamma, 2.222)  # gamma
    offs  = Default(offs,   0.0 )  # extension of the linear part

    ptype  = IsPlanarRGB(c)
    contoy = !isy(c)

    tv_range_in  = Default(tv_range_in,  !ptype)
    tv_range_out = Default(tv_range_out, !ptype)

    c
    rangePC = tv_range_in  ? "x ymin - ymax ymin - /"           : "x range_max /"
    rangeTV = tv_range_out ? "ymax ymin - * range_max / ymin +" : ""
    yb  = "{offs} {gamma} * {gamma} 1 - 1 {offs} + * / {gamma} ^"
    rs  = "{gamma} 1 - {offs} / {gamma} 1 - ^ 1 {offs} + {gamma} / {gamma} ^ *"
    out = offs > 0.0 ? Format(""+rangePC+" A@ "+yb+" > 1 {offs} + A 1 {gamma} / ^ * {offs} - range_max * A "+rs+" * range_max * ? "+rangeTV+"") : \
                       Format(""+rangePC+" 1 {gamma} / ^ range_max * "+rangeTV+"")

    cplane  = contoy ? ptype ? out : "" : Undefined

    gamma <= 1.0 ? last : \
    Expr(out,cplane,cplane) }




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
