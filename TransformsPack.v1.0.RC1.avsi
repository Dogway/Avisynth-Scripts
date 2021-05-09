###########################################################
###                                                      ##
###                                                      ##
###    Transforms Pack v1.0 RC2  (09-05-2021)            ##
###                                                      ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###########################################################
###
### Pack of tools for proper color managing Avisynth+.
### From function transforms like performant piecewise gamma functions,
### to color gamut converters and a list of building block functions
### for matrix operations.
###
### All of them converge on ColorSpace(). An accurate and simple to use
### color space and gamma conversion filter.
###
###
### No Dependencies.
###
###
####################################



function ColorSpace (clip clp, string "source", string "target", string "kernel_up", string "kernel_down", bool "gamut", bool "gamma" \
                    , bool "tv_range_in", bool "tv_range_out", float "b_up", float "c_up", float "p_up", float "b_down", float "c_down", float "p_down") {

    gamut       = Default (gamut, true)           # convert gamut
    gamma       = Default (gamma, true)           # convert gamma
    tv_range_in = Default (tv_range_in,  !isRGB(clp) )
    tv_range_out= Default (tv_range_out, tv_range_in )
    kernelu     = Default (kernel_up, "bicubic")
    kerneld     = Default (kernel_down, kernelu)
    bu          = Default (b_up, 0.00)
    cu          = Default (c_up, 0.75)   # Precise Bicubic
    pu          = Default (p_up, 0.25)
    bd          = Default (b_down, -0.5)
    cd          = Default (c_down, 0.25) # Didée's Bicubic
    pd          = Default (p_down, 0.25)

    source = Matrix_fuzzy_search (source)
    target = Matrix_fuzzy_search (target)

    s_num =
\     (source == "sRGB"      ) ? 0
\   : (source == "Rec601"    ) ? 1
\   : (source == "240M"      ) ? 2
\   : (source == "470BG"     ) ? 3
\   : (source == "Rec2020"   ) ? 4
\   : (source == "Rec709"    ) ? 5
\   : (source == "1886a"     ) ? 6
\   : (source == "AdobeRGB"  ) ? 7
\   : (source == "Display-P3") ? 0
\   : (source == "DCI-P3"    ) ? 8
\   : (source == "ACEScg"    ) ? 9
\   : (source == "ACES2065"  ) ? 9
\   : Assert (false, "Unsupported Color Space.")

    t_num =
\     (target == "sRGB"      ) ? 0
\   : (target == "Rec601"    ) ? 1
\   : (target == "240M"      ) ? 2
\   : (target == "470BG"     ) ? 3
\   : (target == "Rec2020"   ) ? 4
\   : (target == "Rec709"    ) ? 5
\   : (target == "1886a"     ) ? 6
\   : (target == "AdobeRGB"  ) ? 7
\   : (target == "Display-P3") ? 0
\   : (target == "DCI-P3"    ) ? 8
\   : (target == "ACEScg"    ) ? 9
\   : (target == "ACES2065"  ) ? 9
\   : Assert (false, "Unsupported Color Space.")

    bdpth = BitsPerComponent(clp) > 10 ? 0.09929682680944 : 0.099

    #                                  SMPTE-C     Y’PbPr 601  PAL/SECAM BT-2020    Rec.709    BT-1886a  AdobeRGB     DCI-P3   AP1/AP0
    #                         sRGB     SMPTE 170M  SMPTE 240M  BT-470BG  BT-2020    BT-1886    BT-1886a  AdobeRGB     DCI-P3      ACES
    t_temp  = Select (t_num,  6504   ,  6504   ,   6504   ,    6504   ,      6504,   6504   ,   6504   ,     6504 ,   6305  ,     6000 )
    s_off   = Select (s_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,   0      ,   0      ,   0     ,      0   )
    s_gamma = Select (s_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,   2.60   ,   2.1992 ,   2.60  ,      1.0 )

    t_off   = Select (t_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,   0      ,   0      ,   0     ,      0   )
    t_gamma = Select (t_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,   2.60   ,   2.1992 ,   2.60  ,      1.0 )


    clp

    IsPlanarRGB(clp) ? last : \
    YCbCrToRGB( YCbCrToRGB_mat(source, tv_range_in), kernel=kernelu, b=bu, c=cu, p=pu)

    moncurve_f(s_gamma, s_off, false)

    if (gamut) {
    mata = RGB_to_XYZ(source, list=true)
    matb = XYZ_to_RGB(target, list=true)
    MatrixClip( MatrixDot(mata, matb) ) }

    t_num==9 ? last : gamma ? moncurve_r(t_gamma, t_off, false) : !gamma && gamut ? moncurve_r(s_gamma, s_off, false) : last

    IsPlanarRGB(clp) ? last : \
    RGBToYCbCr( RGBToYCbCr_mat(target, tv_range_out), kernel=kerneld, pixel_type=PixelType(clp), b=bd, c=cd, p=pd)  }




function Display_Referred (clip clp, string "source", string "disp_ref", string "kernel", string "LUT", bool "gamut", bool "gamma", bool "tv_range", float "b", float "c", float "p") {

    gamut      = Default (gamut, true)      # convert gamut
    gamma      = Default (gamma, true)      # convert gamma
    disp_ref   = Default (disp_ref, "sRGB") # Display Referred Color Space
    LUT        = Default (LUT, Undefined)   # Display LUT (the path string of your monitor 3D LUT, if calibrated)
    tv_range   = Default (tv_range, !isRGB(clp) )
    kernel     = Default (kernel, "bicubic")
    b          = Default (b, 0.00)
    c          = Default (c, 0.75)          # Precise Bicubic
    p          = Default (p, 0.25)

    noop = source == disp_ref

    source = Matrix_fuzzy_search (source)
    target = Matrix_fuzzy_search (disp_ref)

    s_num =
\     (source == "sRGB"      ) ? 0
\   : (source == "Rec601"    ) ? 1
\   : (source == "240M"      ) ? 2
\   : (source == "470BG"     ) ? 3
\   : (source == "Rec2020"   ) ? 4
\   : (source == "Rec709"    ) ? 5
\   : (source == "1886a"     ) ? 6
\   : (source == "AdobeRGB"  ) ? 7
\   : (source == "DCI-P3"    ) ? 8
\   : (source == "Display-P3") ? 0
\   : (source == "ACES2065"  ) ? 9
\   : (source == "ACEScg"    ) ? 9
\   : Assert (false, "Unsupported Color Space.")

    t_num =
\     (target == "sRGB"      ) ? 0
\   : (target == "Rec601"    ) ? 1
\   : (target == "240M"      ) ? 2
\   : (target == "470BG"     ) ? 3
\   : (target == "Rec2020"   ) ? 4
\   : (target == "Rec709"    ) ? 5
\   : (target == "1886a"     ) ? 6
\   : (target == "AdobeRGB"  ) ? 7
\   : (target == "DCI-P3"    ) ? 8
\   : (target == "Display-P3") ? 0
\   : (target == "ACES2065"  ) ? 9
\   : (target == "ACEScg"    ) ? 9
\   : Assert (false, "Unsupported Color Space.")


    bdpth = BitsPerComponent(clp) > 10 ? 0.09929682680944 : 0.099

    #                                  SMPTE-C     Y’PbPr 601  PAL/SECAM BT-2020    Rec.709    BT-1886a  AdobeRGB     DCI-P3   AP1/AP0
    #                         sRGB     SMPTE 170M  SMPTE 240M  BT-470BG  BT-2020    BT-1886    BT-1886a  AdobeRGB     DCI-P3      ACES
    t_temp  = Select (t_num,  6504   ,  6504   ,   6504   ,    6504   ,      6504,   6504   ,   6504   ,     6504 ,   6305  ,     6000 )
    s_off   = Select (s_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,   0      ,   0      ,   0     ,      0   )
    s_gamma = Select (s_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,   2.60   ,   2.1992 ,   2.60  ,      1.0 )

    t_off   = Select (t_num,  0.055  ,  0.099  ,   0.1115 ,    0.099  ,     bdpth,   0      ,   0      ,   0      ,   0     ,      0   )
    t_gamma = Select (t_num,  2.40   ,  2.22222,   2.22222,    2.80   ,   2.22222,   2.40   ,   2.60   ,   2.1992 ,   2.60  ,      1.0 )


    clp.ConvertBits(16)

    IsPlanarRGB(clp) ? last : \
    YCbCrToRGB( YCbCrToRGB_mat(source, tv_range), kernel=kernel, b=b, c=c, p=p)

    !noop ? moncurve_f(s_gamma, s_off, false) : last

    if (gamut && !noop) {
    mata = RGB_to_XYZ(source, list=true)
    matb = XYZ_to_RGB(target, list=true)
    MatrixClip( MatrixDot(mata, matb) ) }

    Defined(LUT) || gamma ? moncurve_r(t_gamma, t_off, false) : !gamma && gamut ? moncurve_r(s_gamma, s_off, false) : last

    Defined(LUT) ? Cube(LUT, 4, true) : last

    ConvertBits(8, dither=1)  }




function Matrix_fuzzy_search (string matrix) {

    matrix =
\     (matrix == "srgb"         ) ? "sRGB"
\   : (matrix == "jpeg"         ) ? "Rec601"
\   : (matrix == "jpg"          ) ? "Rec601"
\   : (FindStr(matrix, "601")>0 ) ? "Rec601"
\   : (FindStr(matrix, "170")>0 ) ? "Rec601"
\   : (FindStr(matrix, "240")>0 ) ? "240M"
\   : (matrix == "YCC"          ) ? "240M"
\   : (matrix == "470bg"        ) ? "470BG"
\   : (FindStr(matrix,"2020")>0 ) ? "Rec2020"
\   : (FindStr(matrix,"2100")>0 ) ? "Rec2020"
\   : (FindStr(matrix,"2084")>0 ) ? "Rec2020"
\   : (FindStr(matrix,"709" )>0 ) ? "Rec709"
\   : (FindStr(matrix,"1886")>0 ) ? "Rec709"
\   : (matrix == "1886a"        ) ? "1886a"
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




function YCbCrToRGB (clip yuv, float_array mat, string "kernel", string "cplace", float "b", float "c", float "p") {

    kernel     = Default (kernel, "bicubic")
    cplace     = Default (cplace, "MPEG2")
    b          = Default (b, 0.0)
    c          = Default (c, 0.75)
    p          = Default (p, 0.25)

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

    R = mat[1]==0.0 ? Expr(Y,    V, "x ymin - "+string(mat[0])+" *                                       y range_half - "+string(mat[2])+" * + ") : \
                      Expr(Y, U, V, "x ymin - "+string(mat[0])+" * y range_half - "+string(mat[1])+" * + z range_half - "+string(mat[2])+" * + ")
    G =               Expr(Y, U, V, "x ymin - "+string(mat[3])+" * y range_half - "+string(mat[4])+" * + z range_half - "+string(mat[5])+" * + ")
    B = mat[8]==0.0 ? Expr(Y, U,    "x ymin - "+string(mat[6])+" * y range_half - "+string(mat[7])+" * +")                                        : \
                      Expr(Y, U, V, "x ymin - "+string(mat[6])+" * y range_half - "+string(mat[7])+" * + z range_half - "+string(mat[8])+" * + ")

    CombinePlanes(R, G, B, planes="RGB") }




function RGBtoYCbCr (clip rgb, float_array mat, string "pixel_type", string "kernel", string "cplace", float "b", float "c", float "p") {

    pixel_type = Default (pixel_type, "420")
    kernel     = Default (kernel, "bicubic")
    cplace     = Default (cplace, "MPEG2")
    b          = Default (b, -0.5)
    c          = Default (c, 0.25)
    p          = Default (p, 0.25)

    w =  width(rgb)
    nw = round(w/2.0)
    h = height(rgb)
    nh = round(h/2.0)

    p_type4 = FindStr(pixel_type, "44")>0
    p_type2 = FindStr(pixel_type, "22")>0

    p_type = p_type4 ? "YUV444P" : p_type2 ? "YUV422P" : "YUV420P"
    p_type = p_type + string(BitsPerComponent(rgb))

    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)

    Y  = Expr(Rx, Gx, Bx, "      ymin x "+string(mat[0])+" * + y "+string(mat[1])+" * + z "+string(mat[2])+" * + ")
    Cb = Expr(Rx, Gx, Bx, "range_half x "+string(mat[3])+" * + y "+string(mat[4])+" * + z "+string(mat[5])+" * + ")
    Cr = Expr(Rx, Gx, Bx, "range_half x "+string(mat[6])+" * + y "+string(mat[7])+" * + z "+string(mat[8])+" * + ")

    cplace = p_type4 || cplace=="MPEG2" ? ",src_left=-0.50" : ",src_left=0.0"
    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(nw+nw%2) + "," + String(p_type2 ? h : nh+nh%2) + cplace + ")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(nw+nw%2) + "," + String(p_type2 ? h : nh+nh%2) + cplace + ",b=b,c=c)" : \
                kernel == "gauss"  ?     "GaussResize(" + String(nw+nw%2) + "," + String(p_type2 ? h : nh+nh%2) + cplace + ",p=p)"     : \
                                     kernel + "Resize(" + String(nw+nw%2) + "," + String(p_type2 ? h : nh+nh%2) + cplace + ")"

    Cb = p_type4 ? Cb : Eval("Cb." + resampler)
    Cr = p_type4 ? Cr : Eval("Cr." + resampler)

    CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type=p_type) }




# Adapted from Dither_convert_yuv_to_rgb()
function YCbCrToRGB_mat (string matrix, bool "tv_range") {

    tv_range = Default (tv_range, true)

    coef = Matrix_coef(matrix)

    scale_y  = tv_range ? (255. / 219.) : 1.0
    scale_uv = tv_range ? (255. / 112.) : 2.0

    tn = 1. - coef[0]
    tb = 1. - coef[2]

    m1 = scale_y
    m2 = 0.0
    m3 = scale_uv * tn
    m4 = scale_y
    m5 = scale_uv * ( -tb * coef[2] / coef[1])
    m6 = scale_uv * ( -tn * coef[0] / coef[1])
    m7 = scale_y
    m8 = scale_uv * tb
    m9 = 0.0

    [m1,m2,m3,m4,m5,m6,m7,m8,m9] }



# Adapted from Dither_convert_rgb_to_yuv()
function RGBToYCbCr_mat (string matrix, bool "tv_range") {

    tv_range = Default (tv_range, true)

    coef = Matrix_coef(matrix)

    scale_y  = tv_range ? (219. / 255.) : 1.0
    scale_uv = tv_range ? (112. / 255.) : 0.5

    tn = 1. - coef[0]
    tb = 1. - coef[2]

    m1 = scale_y  * coef[0]
    m2 = scale_y  * coef[1]
    m3 = scale_y  * coef[2]
    m4 = scale_uv * (-coef[0] / tb)
    m5 = scale_uv * (-coef[1] / tb)
    m6 = scale_uv
    m7 = scale_uv
    m8 = scale_uv * (-coef[1] / tn)
    m9 = scale_uv * (-coef[2] / tn)

    [m1,m2,m3,m4,m5,m6,m7,m8,m9] }




function Matrix_coef (string matrix) {

    matrix = Matrix_fuzzy_search (matrix)

    mat_i =
\     (matrix == "srgb"      ) ? 0
\   : (matrix == "Rec601"    ) ? 1
\   : (matrix == "240M"      ) ? 2
\   : (matrix == "470BG"     ) ? 3
\   : (matrix == "Rec2020"   ) ? 4
\   : (matrix == "Rec709"    ) ? 0
\   : (matrix == "1886a"     ) ? 0
\   : (matrix == "AdobeRGB"  ) ? 5
\   : (matrix == "Display-P3") ? 6
\   : (matrix == "DCI-P3"    ) ? 7
\   : (matrix == "ACEScg"    ) ? 8
\   : (matrix == "ACES2065"  ) ? 9
\   : Assert (false, "Unsupported Color Space.")

    mat_w =
\     (matrix == "DCI-P3"         ) ? 1
\   : (matrix == "ACES2065"       ) ? 2
\   : (matrix == "ACEScg"         ) ? 2
\   :                                 0

    #                    IEC 61966-2-1 sRGB SMPTE-C*        Y’PbPr 601        PAL/SECAM         BT-2020/BT-2100   Adobe RGB (1998)  Display-P3        DCI-P3            AP1                AP0
    #                    ITU-R BT.709       SMPTE 170M      SMPTE 240M        BT-470BG          BT-2020/BT-2100   Adobe RGB (1998)  P3-D65            DCI-P3            ACEScg             ACES2065-1
    pr = Select (mat_i,  [0.640, 0.330],  [0.630,  0.340],  [0.630,  0.340],  [0.640,  0.330],  [0.708,  0.292],  [0.640,  0.330],  [0.680,  0.320],  [0.680,  0.320],  [0.713,   0.293],  [0.7347,  0.2653])
    pg = Select (mat_i,  [0.300, 0.600],  [0.310,  0.595],  [0.310,  0.595],  [0.290,  0.600],  [0.170,  0.797],  [0.210,  0.710],  [0.265,  0.690],  [0.265,  0.690],  [0.165,   0.830],  [0.0000,  1.0000])
    pb = Select (mat_i,  [0.150, 0.060],  [0.155,  0.070],  [0.155,  0.070],  [0.150,  0.060],  [0.131,  0.046],  [0.150,  0.060],  [0.150,  0.060],  [0.150,  0.060],  [0.128,   0.044],  [0.0001, -0.0770])
    pw = Select (mat_w,  [0.312713, 0.329016],                                                                                                        [0.314,  0.351],  [0.32168,0.33767], [0.32168, 0.33767])

    pr2 = 1. - pr[0] - pr[1]
    pb2 = 1. - pb[0] - pb[1]
    pg2 = 1. - pg[0] - pg[1]
    pw2 = 1. - pw[0] - pw[1]

    kr = (pr[1] * (pw[0] * (pg[1] * pb2 - pb[1] * pg2) + pw[1] * (pb[0] * pg2 - pg[0] * pb2) + pw2   * (pg[0] * pb[1] - pb[0] * pg[1]))) / \
         (pw[1] * (pr[0] * (pg[1] * pb2 - pb[1] * pg2) + pg[0] * (pb[1] * pr2 - pr[1] * pb2) + pb[0] * (pr[1] * pg2   - pg[1] * pr2)))

    kb = (pb[1] * (pw[0] * (pr[1] * pg2 - pg[1] * pr2) + pw[1] * (pg[0] * pr2 - pr[0] * pg2) + pw2   * (pr[0] * pg[1] - pg[0] * pr[1]))) / \
         (pw[1] * (pr[0] * (pg[1] * pb2 - pb[1] * pg2) + pg[0] * (pb[1] * pr2 - pr[1] * pb2) + pb[0] * (pr[1] * pg2   - pg[1] * pr2)))

    kg = 1. - kb - kr

    mat_i == 1 ? [0.299, 0.587, 0.114] : \
                 [   kr,    kg,    kb] }




function WhitePoint (clip c, int "temperature", string "matrix", bool "tv_range", string "kernel_up", string "kernel_down" \
                   , float "b_up", float "c_up", float "p_up", float "b_down", float "c_down", float "p_down") {

    temp        = Default (temperature, 6504)  # Target temperature in Kelvin (Default: D65 == nop())
    matrix      = Default (matrix, "sRGB")
    tv_range    = Default (tv_range,  !isRGB(c) )
    kernelu     = Default (kernel_up, "bicubic")
    kerneld     = Default (kernel_down, kernelu)
    bu          = Default (b_up, 0.00)
    cu          = Default (c_up, 0.75)
    pu          = Default (p_up, 0.25)
    bd          = Default (b_down, -0.5)
    cd          = Default (c_down, 0.25)
    pd          = Default (p_down, 0.25)

    matrix = Matrix_fuzzy_search (matrix)

    IsPlanarRGB(c) ? c : \
    YCbCrToRGB(c, YCbCrToRGB_mat(matrix, tv_range), kernel=kernelu, b=bu, c=cu, p=pu)


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
    fw_trans = [fw1[0]/fw2[0],fw1[1]/fw2[1],fw1[2]/fw2[2]]

    RGB_to_XYZ(matrix)
    Expr(last,string(fw_trans[0])+" x *",string(fw_trans[1])+" x *",string(fw_trans[2])+" x *")
    XYZ_to_RGB(matrix)

    IsPlanarRGB(c) ? c : \
    RGBToYCbCr( RGBToYCbCr_mat(matrix, tv_range), kernel=kerneld, pixel_type=PixelType(c), b=bd, c=cd, p=pd)

}




function RGB_to_XYZ (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    cspace = Matrix_fuzzy_search(cspace)

    matrix =        cspace == "sRGB" || cspace == "Rec709"                                              ?  \
                                        [ 0.41241079568862915, 0.21264933049678802, 0.01933175697922707,   \
                                          0.35758456587791443, 0.71516913175582890, 0.11919485777616501,   \
                                          0.18045382201671600, 0.07218152284622192, 0.95039016008377080] : \
                    cspace == "Rec601"                                                                  ?  \
                                        [ 0.39354196190834045, 0.21238772571086884, 0.0187400933355093,    \
                                          0.36525884270668030, 0.70106136798858640, 0.1119341626763344,    \
                                          0.19164848327636720, 0.08655092865228653, 0.9582424163818359]  : \
                    cspace == "240M"                                                                    ?  \
                                        [ 0.39363747835159300, 0.21234387159347534, 0.01903081871569157,   \
                                          0.36482381820678710, 0.70066159963607790, 0.11194594204425812,   \
                                          0.19198796153068542, 0.08699454367160797, 0.95793992280960080] : \
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
                    cspace == "Rec601"                                                                      ?  \
                                        [  3.5058159828186035, -1.06904542446136470,  0.05631496384739876,     \
                                          -1.7396978139877320,  1.97777497768402100, -0.19700492918491364,     \
                                          -0.5440292358398438,  0.035171352326869965, 1.05010843276977540]   : \
                    cspace == "240M"                                                                        ?  \
                                        [  3.5040030479431152, -1.06879472732543950,  0.05528862774372101,     \
                                          -1.7374893426895142,  1.97820663452148440, -0.19665780663490295,     \
                                          -0.5444750189781189,  0.03455597534775734,  1.05068528652191160]   : \
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
    fs  = "{gamma} 1.0 - {offs} / {offs} {gamma} * {gamma} 1.0 - 1.0 {offs} + * / {gamma} ^ *"
    xb  = "{offs} {gamma} 1.0 - /"
    out = offs > 0.0 ? Format(""+rangePC+" A@ "+xb+" > A {offs} + 1.0 {offs} + / {gamma} ^ range_max * A "+fs+" * range_max * ? "+rangeTV+"") : \
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
    yb  = "{offs} {gamma} * {gamma} 1.0 - 1.0 {offs} + * / {gamma} ^"
    rs  = "{gamma} 1.0 - {offs} / {gamma} 1.0 - ^ 1.0 {offs} + {gamma} / {gamma} ^ *"
    out = offs > 0.0 ? Format(""+rangePC+" A@ "+yb+" > 1.0 {offs} + A 1.0 {gamma} / ^ * {offs} - range_max * A "+rs+" * range_max * ? "+rangeTV+"") : \
                       Format(""+rangePC+" 1.0 {gamma} / ^ range_max * "+rangeTV+"")

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




function Dot( float_array vec1, \
              float_array vec2) {
    # 1x3 · 1x3
    (vec1[0] * vec2[0]) + (vec1[1] * vec2[1]) + (vec1[2] * vec2[2]) }




function DotClip ( clip rgb, float_array vec) {

    # clip · 1x3
    Expr(ExtractR(rgb), \
         ExtractG(rgb), \
         ExtractB(rgb), "x "+string(vec[0])+" * y "+string(vec[1])+" * + z "+string(vec[2])+" * +") }




function MatrixDiv ( float_array rgb, \
                     float_array rgbx) {

    asize = ArraySize(rgb)
    str = ""
    for (i=0, asize, 1) {
        cm = asize == i+1 ? "" : ","
        str = str + string(rgb[i] / rgbx[i]) + cm
        i   = asize == i+1 ? asize : i
       }

    "["+str+"]" }
