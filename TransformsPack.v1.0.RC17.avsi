###########################################################
###                                                      ##
###                                                      ##
###    Transforms Pack v1.0 RC17  (14-06-2021)           ##
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
### All of them converge in ColorSpace(). An accurate and simple to use
### color space and gamma conversion filter.
###
### With color management in place, I took it one step further and
### made ConvertFormat(), clearly inspired by avsresize's z_ConvertFormat()
### but with more features and easier to use.
###
###
### Dependencies: AviSynth+ 3.5 and over
###
####################################

function ColorSpace (clip clp, string "source", string "target", bool "gamut", bool "gamma", bool "tv_range_in", bool "tv_range_out", bool "linear_in", bool "linear_out", string "format_out") {

    isRGBc  = isRGB(clp)

    source  = Default (source, "Rec709")
    target  = Default (target, source)
    gamut   = Default (gamut, source != target)    # convert gamut
    gamma   = Default (gamma, true)                # convert gamma
    tv_in   = Default (tv_range_in,  !isRGBc )
    tv_out  = Default (tv_range_out, tv_in )
    lin_in  = Default (linear_in,  false )
    lin_out = Default (linear_out, false )
    f_out   = Default (format_out, "" )

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

    clp
    # Data extraction and normalization
    pxtyp = PixelType(clp)
    p_typ = f_out == "" ?  pxtyp : Format_fuzzy_search (f_out, BitsPerComponent(clp))
    f_ker = f_out != "" && pxtyp != p_typ ? "Bicubic" : "Point"
    f_pla = f_out != "" && pxtyp != p_typ ? ""        : "MPEG1"
    src   = Matrix_fuzzy_search (source)
    tgt   = Matrix_fuzzy_search (target)
    s_gam = moncurve_coef (src)
    t_gam = moncurve_coef (tgt)
    gamut = gamut && src != tgt


    # RGB conversion and gamma decode
    !isRGBc && lin_in ? moncurve_r(s_gam[0], s_gam[1], tv_in, tv_in)                  : last

     isRGBc ? ConvertToPlanarRGB(src)                                                 : \
              YUV_to_RGB(src, tv_range_in=tv_in, kernel=f_ker, cplace=f_pla)

     isRGBc && lin_in ? tv_in ? SMPTE_legal(false) : last                             : \
                        moncurve_f(s_gam[0], s_gam[1],isRGBc?tv_in:false,false)

    # color space conversion
    if (gamut) {
    mata = RGB_to_XYZ  (src,      list=true)
    matw = c_adaptation(src, tgt, list=true)
    matb = XYZ_to_RGB  (tgt,      list=true)
    MatrixClip( MatrixDot(MatrixDot(mata, matw), matb) ) }

    # gamma reencode
    FindStr(target,"ACES")>0 || lin_out ? last                                        : \
                                  gamma ? moncurve_r(t_gam[0], t_gam[1],false,false) : \
                      gamut || !lin_out ? moncurve_r(s_gam[0], s_gam[1],false,false) : \
                                          last

    # YUV conversion
    isRGBc && FindStr(p_typ, "RGB")>0 ?        \
              tv_out  ? SMPTE_legal() : last : \
              lin_out ? moncurve_r(t_gam[0], t_gam[1]).RGB_to_YUV( tgt, tv_range_out=tv_out, kernel=f_ker, pixel_type=p_typ, cplace=f_pla).moncurve_f(t_gam[0], t_gam[1],tv_out,tv_out) : \
                                                       RGB_to_YUV( tgt, tv_range_out=tv_out, kernel=f_ker, pixel_type=p_typ, cplace=f_pla) }



function Display_Referred (clip clp, string "source", string "disp_ref", string "kernel", bool "gamut", bool "gamma", string "LUT", bool "tv_range", float "b", float "c", float "p") {

    isRGBsrc    = isRGB(clp)

    gamut      = Default (gamut, true)      # convert gamut
    gamma      = Default (gamma, true)      # convert gamma
    disp_ref   = Default (disp_ref, "sRGB") # Display Referred Color Space
    kernel     = Default (kernel, "Bicubic")
    LUT        = Default (LUT, Undefined)   # Display LUT (the path string of your monitor .cube 3D LUT, if calibrated)
    tv_range   = Default (tv_range, !isRGBsrc )
    b          = Default (b, 0.00)
    c          = Default (c, 0.75)          # Precise Bicubic
    p          = Default (p, 0.25)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

    BitsPerComponent(clp) < 32 ? clp.ConvertBits(16) : clp

    src   = Matrix_fuzzy_search (source)
    tgt   = Matrix_fuzzy_search (disp_ref)
    s_gam = moncurve_coef (src)
    t_gam = moncurve_coef (tgt)
    gamut = gamut && src != tgt

    isRGBsrc ? ConvertToPlanarRGB(src)                                            : \
               YUV_to_RGB(src, tv_range_in=tv_range, kernel=kernel, b=b, c=c, p=p)

    moncurve_f(s_gam[0], s_gam[1],isRGBsrc?tv_range:false,false)

    if (gamut) {
    mata = RGB_to_XYZ  (src,      list=true)
    matw = c_adaptation(src, tgt, list=true)
    matb = XYZ_to_RGB  (tgt,      list=true)
    MatrixClip( MatrixDot(MatrixDot(mata, matw), matb) ) }

    Defined(LUT) || gamma ? moncurve_r(t_gam[0], t_gam[1],false,false) : \
                    gamut ? moncurve_r(s_gam[0], s_gam[1],false,false) : last

    Defined(LUT) ? Cube(LUT, 4, true) : last

    ConvertBits(8, dither=1)  }



###
### ConvertFormat()
###
###
### Similar to avsresize's z_ConvertFormat() but more flexible, more options and more features:
### Chroma reconstruction, scale_space, noring, mod size, ratio resize, kernel/matrix aliases (supports any resizer), etc
###
### Dependencies: AviSynth+ 3.5 and over
###
###
### Example: High quality JPEG decoding and conversion to RGB
###   MP_Pipeline("""
###   ### platform: win32
###   JPEGSource("source.jpg",rec=3)
###   ### ###
###   """)
###   ConvertBits(16)
###   Implicit:
###       ConvertFormat(1,1,"RGB","jpeg","sRGB",UVRecon=true)
###   Explicit:
###       ConvertFormat(1,1,"RGB","jpeg","sRGB",false,false,cplace_in="MPEG1",UVRecon=true)
###   ConvertBits(8, dither=1)
###
####################################

# Work In Progress
function ConvertFormat (clip clp, val "width", val "height", string "format", string "cs_in", string "cs_out", bool "tv_range_in", bool "tv_range_out", string "cplace_in", string "cplace_out", \
                        string "scale_space", string "kernel", float "b", float "c", float "p", int "mod", float "src_left", float "src_top", float "src_width", float "src_height", bool "noring", bool "UVrecon") {
    clp
    w          = width ()
    h          = height()
    isRGBc     = isRGB()
    isRGBout   = FindStr(format,"RGB")>0 || FindStr(format,"rgb")>0
    p_type     = PixelType()
    isUHD      = (w > 2599 ||  h > 1499)
    isHD       = (w > 1099 ||  h > 599 )

    nw         = Default (width,  1)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target width
    nh         = Default (height, 1)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target height
    format     = Default (format, p_type)
    cs_in      = Default (cs_in, isUHD ? "2020" : isHD ? "709" : "601")
    cs_out     = Default (cs_out, cs_in)
    tv_in      = Default (tv_range_in,  !(isRGBc   || cs_in =="srgb" || cs_in =="jpeg" || cs_in =="jpg") )
    tv_out     = Default (tv_range_out, !(isRGBout || cs_out=="srgb" || cs_out=="jpeg" || cs_out=="jpg") )
    kernel     = Default (kernel, "Bicubic")
    space      = Default (scale_space, "")       # resizing space: "gamma" / "", "linear" or "log". Assumes gamma encoded input.
    cplace_in  = Default (cplace_in,   "")       # Assumed default from format
    cplace_out = Default (cplace_out,  "")       # Assumed default from format
    mod        = Default (mod, isRGBout ? 1 : 2) # mod size for resizing. ie: 2, 4, 8, 16...
    b          = Default (b, (w>nw||h>nh)?-0.5:0.0 )
    c          = Default (c, (w>nw||h>nh)?0.25:0.75)
    p          = Default (p, 0.25)
    src_left   = Default (src_left, 0.0)
    src_top    = Default (src_top,  0.0)
    src_width  = Default (src_width,  w)
    src_height = Default (src_height, h)
    noring     = Default (noring,  false)
    recon      = Default (UVrecon, false)

    nw = isInt(nw) && nw<=10 ? float(nw) : isFloat(nw) && nw>10. ? int(nw) : nw
    nh = isInt(nh) && nh<=10 ? float(nh) : isFloat(nh) && nh>10. ? int(nh) : nh

    !(isInt(nw) || isInt(nh) || isFloat(nw) || isFloat(nh)) ? \
                 Assert(false, "Width/Height type not supported.")               : nop()
                 Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

    # YUV to RGB
    if (!isRGBc && isRGBout) {

        YUV_to_RGB (cs_in, tv_in, tv_out,         kernel, b, c, p, cplace, recon)

    # RGB to YUV
    } else if ( isRGBc && !isRGBout) {

        RGB_to_YUV (cs_in, tv_in, tv_out, p_type, kernel, b, c, p, cplace)

    # YUV to YUV
    } else {

    bdpth    = BitsPerComponent()
    format   = Format_fuzzy_search (format, bdpth)
    i_type   = LeftStr(p_type, 7)
    o_type   = LeftStr(format, 7)
    cs_in    = Matrix_fuzzy_search (cs_in)
    cs_out   = Matrix_fuzzy_search (cs_out)
    coef_i   = Matrix_coef(cs_in)
    coef_o   = Matrix_coef(cs_out)
    s_gam    = moncurve_coef (cs_in)
    t_gam    = moncurve_coef (cs_out)
    bc       = bicubic_coeffs(kernel)
    bc_b     = bc[1]>=0.?bc[0]:b
    bc_c     = bc[1]>=0.?bc[1]:c
    kernel   = bc[1]>=0. ? "Bicubic" : kernel

    i_type4  = i_type == "YUV444P"          o_type4  = o_type == "YUV444P"
    i_type2  = i_type == "YUV422P"          o_type2  = o_type == "YUV422P"
    i_type1  = i_type == "YUV411P"          o_type1  = o_type == "YUV411P"
    i_type10 = i_type == "YUV9"             o_type10 = o_type == "YUV9"

    nw       = nw<=10. ? w*nw : nw      nw = round(nw/mod)*mod
    nh       = nh<=10. ? h*nh : nh      nh = round(nh/mod)*mod
    cow      = i_type4 ?  w : i_type1 || i_type10 ? round( w/4.0) : round( w/2.0)
    coh      = i_type4 ||     i_type1 || i_type2  ?             h : round( h/2.0)
    cnw      = o_type4 ? nw : o_type1 || o_type10 ? round(nw/4.0) : round(nw/2.0)
    cnh      = o_type4 ||     o_type1 || o_type2  ?            nh : round(nh/2.0)
    cplacei  = chroma_placement(cow, coh, cs_in,  i_type, cplace_in )
    cplaceo  = chroma_placement(cnw, cnh, cs_out, o_type, cplace_out)

     i_type1               ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411")     : nop()
                             Assert(!i_type10,  "Unsupported Pixel Type: YUV410")
     !isRGBc               ? Assert(h%2==0,"Clip Height is not mod2." )                   : nop()
     i_type2   || i_type0  ? Assert(w%2==0, "Clip Width is not mod2." )                   : nop()
     i_type1               ? Assert(w%4==0, "Clip Width is not mod4." )                   : nop()

     o_type1               ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411")     : nop()
                             Assert(!o_type10,  "Unsupported Pixel Type: YUV410")
     o_type1               ? Assert(nw%4==0, "Target Width is not mod4." )                : nop()
    !(isRGBout ||  o_type4 || (cnw>cow || cnh>coh))                                             ? \
                                  Assert(!recon, "Invalid settings for chroma reconstruction.") : nop()


    space == "linear" ? moncurve_f(s_gam[0], s_gam[1], tv_in, false)             : \
    space == "log"    ? moncurve_f(s_gam[0], s_gam[1], tv_in, false).ACEScct_f() : \
                        last

    Y   = ExtractY()
    Uor = ExtractU()
    Vor = ExtractV()


    resampler = Format( kernel == "nnedi3"           ?  "nnedi3_resize16({nw},{nh}"                         : \
                        kernel == "bicubic"          ?    "BicubicResize({nw},{nh},b={bc_b},c={bc_c}"       : \
                        kernel == "SincLin2ResizeMT" ? "SincLin2ResizeMT({nw},{nh},taps=16"                 : \
                        kernel == "ResizeShader"     ?   """ResizeShader({nw},{nh},kernel="SSIM",b=0.1"""   : \
                        kernel == "SSIM"             ?   """ResizeShader({nw},{nh},kernel="SSIM",b=0.1"""   : \
                        kernel == "gauss"            ?      "GaussResize({nw},{nh},p=p"                     : \
                        kernel == "AiUpscale"        ? """AiUpscale(2,Luma="Medium",Chroma="Spline36",Mode="Photo").""" \
                                                         +"BicubicResize({nw},{nh},b=-0.5,c=0.25"           : \
                        kernel +                                 "Resize({nw},{nh}"                         )

    src_wh  =  Format(",src_width={src_width},src_height={src_height}")
    src_nul =  kernel == "ResizeShader" || kernel == "SSIM"

    # feisty2's ChromaReconstructor_faster v3.0 HBD mod

    if (recon && (o_type4 || isRGBout || (cnw>cow || cnh>coh))) {

        threads = 4

        ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), "auto", wref=1)
        Luma    = ref.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false)
        Uu      = Uor.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false, fwidth=w*2, fheight=h*2, ep0=bc_b, ep1=bc_c, cshift=kernel+"resize", mpeg2=false)
        Vu      = Vor.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false, fwidth=w*2, fheight=h*2, ep0=bc_b, ep1=bc_c, cshift=kernel+"resize", mpeg2=false)
        Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(cnw, cnh, b=-0.5, c=0.25)
        Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(cnw, cnh, b=-0.5, c=0.25)
        U       = ex_adddiff(Uu.BicubicResize(cnw, cnh, b=-0.5, c=0.25), ex_makediff(Unew, Removegrain(Unew, 19)))  # Sharpening
        V       = ex_adddiff(Vu.BicubicResize(cnw, cnh, b=-0.5, c=0.25), ex_makediff(Vnew, Removegrain(Vnew, 19)))  # Sharpening

    } else {

        point   = kernel=="Point" ? "+1.0" : ""
        cplaceH = ",src_left="+string(cplaceo[0]-cplacei[0]+src_left)+point
        cplaceV =  ",src_top="+string(cplaceo[1]-cplacei[1]+src_top)

        str = ReplaceStr(ReplaceStr(resampler, "("+string(nw), "("+string(cnw)), ","+string(nh), ","+string(cnh))
        U   = Eval("Uor." + (src_nul ? "" : (str + cplaceH + cplaceV + src_wh)) + ")")
        V   = Eval("Vor." + (src_nul ? "" : (str + cplaceH + cplaceV + src_wh)) + ")")

        }

        src_c = src_nul ? "" : Format(",src_left={src_left},src_top={src_top}"+src_wh+")")
        Ynr   = Format(".Repair(BicubicResize(Y,{nw},{nh},0,0"+src_c+",1)")
        Y     = Eval("Y." + resampler + src_c + (noring ? Ynr : ""))

    CombinePlanes(Y, U, V, planes="YUV", pixel_type=format)

    space == "linear" ?             moncurve_r(t_gam[0], t_gam[1], false, tv_out) : \
    space == "log"    ? ACEScct_r().moncurve_r(t_gam[0], t_gam[1], false, tv_out) : \
    tv_in != tv_out   ? SMPTE_legal(tv_out)                                       : last } }



# YCbCr to RGB function
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

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    Assert(isRGB(yuv)==false, "Only YUV format supported.")

    bdpth    = BitsPerComponent(yuv)
    p_type   = LeftStr(Format_fuzzy_search(PixelType(yuv), bdpth), 7)
    matrix   = Matrix_fuzzy_search (matrix)
    coef     = Matrix_coef(matrix)
    bc       = bicubic_coeffs(kernel)
    bc_b     = string(bc[1]>=0.?bc[0]:b)
    bc_c     = string(bc[1]>=0.?bc[1]:c)
    kernel   = bc[1]>=0. ? "Bicubic" : kernel

    p_type4  = p_type == "YUV444P"
    p_type2  = p_type == "YUV422P"
    p_type1  = p_type == "YUV411P"
    p_type10 = p_type == "YUV9"

    w  = width (yuv)
    h  = height(yuv)
    nw = p_type4 ? w : p_type1 || p_type10 ? round(w/4.0) : round(w/2.0)
    nh = p_type4 ||    p_type1 || p_type2  ?            h : round(h/2.0)

    cplace     = chroma_placement(yuv, w, h, matrix, p_type, cplace)

     p_type1             ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10,  "Unsupported Pixel Type: YUV410")

                           Assert(h%2==0,"Height is not mod2." )
    !p_type1 || !p_type4 ? Assert(w%2==0, "Width is not mod2." )                    : nop()
     p_type1             ? Assert(w%4==0, "Width is not mod4." )                    : nop()

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

        threads = 4

        ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), "auto", wref=1)
        Luma    = ref.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false)
        Uu      = Uor.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false, fwidth=w*2, fheight=h*2, ep0=0.0, ep1=0.75, cshift="bicubicresize",mpeg2=false)
        Vu      = Vor.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false, fwidth=w*2, fheight=h*2, ep0=0.0, ep1=0.75, cshift="bicubicresize",mpeg2=false)
        Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=-0.5, c=0.25)
        Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=-0.5, c=0.25)
        U       = ex_adddiff(Uu.BicubicResize(w, h, b=-0.5, c=0.25), ex_makediff(Unew, Removegrain(Unew, 19)))  # Sharpening
        V       = ex_adddiff(Vu.BicubicResize(w, h, b=-0.5, c=0.25), ex_makediff(Vnew, Removegrain(Vnew, 19)))  # Sharpening

    } else {

        U   = p_type4 ? Uor : Eval("Uor." + resampler)
        V   = p_type4 ? Vor : Eval("Vor." + resampler)

        }


    if (matrix=="Rec2020CL" || matrix=="DCI-P3" || matrix=="Display-P3") {

        RGB = YcCbcCrc_to_RGB( Y, U, V, matrix, coef, tv_in, tv_out)

        R = RGB[0]  G = RGB[1]  B = RGB[2]

    } else {

        scale_y   = tv_in ? (255. / 219.) : 1.0
        scale_uv  = tv_in ? (255. / 112.) : 2.0

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y     m1 = 0.0                                   m2 = scale_uv * Kr
        m3 = scale_y     m4 = scale_uv * ( -Kb * coef[2] / coef[1]) m5 = scale_uv * ( -Kr * coef[0] / coef[1])
        m6 = scale_y     m7 = scale_uv * Kb                         m8 = 0.0

        rangeY   = tv_in      ? "ymin - "                          : ""
        range_TV = tv_out     ? "ymax ymin - range_max / * ymin +" : ""
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
    cplace     = Default (cplace, "")
    b          = Default (b, -0.5)
    c          = Default (c, 0.25)               # Didée's Bicubic
    p          = Default (p, 0.25)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    Assert(isRGB(rgb)==true && IsPlanar(rgb)==true, "Only Planar RGB format supported.")

    bdpth    = BitsPerComponent(rgb)
    format   = Format_fuzzy_search (p_type, bdpth)
    p_type   = LeftStr(format, 7)
    matrix   = Matrix_fuzzy_search (matrix)
    coef     = Matrix_coef(matrix)
    bc       = bicubic_coeffs(kernel)
    bc_b     = string(bc[1]>=0.?bc[0]:b)
    bc_c     = string(bc[1]>=0.?bc[1]:c)
    kernel   = bc[1]>=0. ? "Bicubic" : kernel

    p_type4  = p_type == "YUV444P"
    p_type2  = p_type == "YUV422P"
    p_type1  = p_type == "YUV411P"
    p_type10 = p_type == "YUV9"

    w  = width (rgb)
    h  = height(rgb)
    nw = p_type4 ? w : p_type1 || p_type10 ? round(w/4.0) : round(w/2.0)
    nh = p_type4 ||    p_type1 || p_type2  ?            h : round(h/2.0)
    cplace     = chroma_placement(rgb, nw, nh, matrix, p_type, cplace)

     p_type1             ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10,  "Unsupported Pixel Type: YUV410")

                           Assert(h%2==0,"Height is not mod2." )
    !p_type1 || !p_type4 ? Assert(w%2==0, "Width is not mod2." )                    : nop()
     p_type1             ? Assert(w%4==0, "Width is not mod4." )                    : nop()


    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)


    if (matrix=="Rec2020CL" || matrix=="DCI-P3" || matrix=="Display-P3") {

        YCbCr = RGB_to_YcCbcCrc( Rx, Gx, Bx, matrix, coef, tv_in, tv_out)

        Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]

    } else {

        scale_y  = !tv_in && tv_out ? (219. / 255.) : 1.0
        scale_uv = !tv_in && tv_out ? (112. / 255.) : 0.5

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y  *   coef[0]       m1 = scale_y  *   coef[1]         m2 = scale_y  *   coef[2]
        m3 = scale_uv * (-coef[0] / Kb) m4 = scale_uv * (-coef[1] / Kb)   m5 = scale_uv
        m6 = scale_uv                   m7 = scale_uv * (-coef[1] / Kr)   m8 = scale_uv * (-coef[2] / Kr)

        UVf       =  bdpth < 32      ? "" : "range_half -"
        rangeY_TV =  tv_out ?  tv_in ? "" : "ymin +" : tv_in ? "ymin - range_max ymax ymin - / *"    : ""
        rangeC_TV = !tv_out && tv_in ? "range_half - range_max cmax cmin - / * range_half + "+UVf+"" : UVf

        Y  = Expr(Rx, Gx, Bx, "           x "+string(m0)+" *   y "+string(m1)+" * + z "+string(m2)+" * + "+rangeY_TV+"")
        Cb = Expr(Rx, Gx, Bx, "range_half x "+string(m3)+" * + y "+string(m4)+" * + z "+string(m5)+" * + "+rangeC_TV+"")
        Cr = Expr(Rx, Gx, Bx, "range_half x "+string(m6)+" * + y "+string(m7)+" * + z "+string(m8)+" * + "+rangeC_TV+"")

    }

    point  = kernel=="Point" ? "+1.0" : ""
    cplaceH = ",src_left="+string(cplace[0])+point
    cplaceV =  ",src_top="+string(cplace[1])

    resampler = kernel == "nnedi3" ? "nnedi3_resize16(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ")"         : \
                kernel == "bicubic"?   "BicubicResize(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ",b="+bc_b+",c="+bc_c+")" : \
                kernel == "gauss"  ?     "GaussResize(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ",p=p)"     : \
                                     kernel + "Resize(" + String(nw+nw%2) + "," + String(nh+nh%2) + cplaceH + cplaceV + ")"

    Cb = p_type4 ? Cb : Eval("Cb." + resampler)
    Cr = p_type4 ? Cr : Eval("Cr." + resampler)

    CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type=format) }


# RGB to YcCbcCrc function (for Rec.2020CL)
function RGB_to_YcCbcCrc (clip Rx, clip Gx, clip Bx, string matrix, float_array coef, bool tv_in, bool tv_out) {

    UVf       = BitsPerComponent(Rx) < 32 ? "range_half +" : ""
    rangeC_PC = tv_in  ? "range_half - range_max cmax cmin - / * range_half + " : ""
    rangeC_TV = tv_out ? "range_half + cmax cmin - range_max / * cmin + "       : UVf

    s_gam = moncurve_coef(matrix)
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
    rangeC_PC = tv_in ? ""+UVf+" range_max cmax cmin - / *" : UVf

    s_gam = moncurve_coef(matrix)
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


# OETF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_f (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out") {

    isRGBc = IsRGB(c)

    gamma  = Default(gamma, 1/0.45)  # gamma
    alpha  = Default(alpha,   0.0 )  # extension in x coords of the linear part

    c
    tv_in  = Default(tv_range_in,  !isRGBc)
    tv_out = Default(tv_range_out,  tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    beta   = (( gamma - 1.0) / alpha) * pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = alpha / ( gamma - 1.0)

    out    = alpha > 0.0 ? Format(""+rangePC+" A@ {phi} > A {alpha} + 1 {alpha} + / {gamma} ^ A {beta} * ? "+rangeTV+"") : \
                           Format(""+rangePC+" {gamma} ^ "+rangeTV+"")

    cplane = !isy() ? isRGBc ? out : "" : Undefined

    gamma <= 1.0 ? last       : \
    Expr(out, cplane, cplane) }


# EOTF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_r (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out") {

    isRGBc = IsRGB(c)

    gamma  = Default(gamma, 1/0.45)  # gamma
    alpha  = Default(alpha,   0.0 )  # extension in x coords of the linear part

    c
    tv_in  = Default(tv_range_in,  !isRGBc)
    tv_out = Default(tv_range_out,  tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    beta   = pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = pow( ( gamma - 1.0) / alpha, gamma - 1.0) * pow( ( 1.0 + alpha) / gamma, gamma)
    igam   = 1. / gamma

    out    = alpha > 0.0 ? Format(""+rangePC+" A@ {beta} > 1 {alpha} + A {igam} ^ * {alpha} - A {phi} * ? "+rangeTV+"") : \
                           Format(""+rangePC+" {igam} ^ "+rangeTV+"")

    cplane = !isy() ? isRGBc ? out : "" : Undefined

    gamma <= 1.0 ? last       : \
    Expr(out, cplane, cplane) }


# Linear to ACEScct: https://github.com/ampas/aces-dev
function ACEScct_f (clip c, bool "tv_range_in", bool "tv_range_out") {

    c
    tv_in  = Default(tv_range_in,  false)
    tv_out = Default(tv_range_out,  tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    X_BRK  = 0.0078125
    coeffA = 10.5402377416545
    coeffB = 0.0729055341958355
    lb     = log(2)

    out    = Format(""+rangePC+" A@ {X_BRK} <= A {coeffA} * {coeffB} + A log {lb} / 9.72 + 17.52 / ? "+rangeTV+"")

    cplane = !isy() ? IsRGB() ? out : "" : Undefined

    Expr(out, cplane, cplane) }


# ACEScct to Linear: https://github.com/ampas/aces-dev
function ACEScct_r (clip c, bool "tv_range_in", bool "tv_range_out") {

    c
    tv_in  = Default(tv_range_in,  false)
    tv_out = Default(tv_range_out,  tv_in)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    Y_BRK  = 0.155251141552511
    coeffA = 10.5402377416545
    coeffB = 0.0729055341958355

    out    = Format(""+rangePC+" A@ {Y_BRK} > 2 A 17.52 * 9.72 - ^ A {coeffB} - {coeffA} / ? "+rangeTV+"")

    cplane = !isy() ? IsRGB() ? out : "" : Undefined

    Expr(out, cplane, cplane) }



function Format_fuzzy_search (string format, int bits) {

    format  = LeftStr(format,7)

    format =
\     (FindStr(format, "420"    )>0) ? "YUV420P"
\   : (FindStr(format,  "12"    )>0) ? "YUV420P"
\   : (FindStr(format, "444"    )>0) ? "YUV444P"
\   : (FindStr(format,  "24"    )>0) ? "YUV444P"
\   : (FindStr(format, "422"    )>0) ? "YUV422P"
\   : (FindStr(format,  "16"    )>0) ? "YUV422P"
\   : (FindStr(format, "411"    )>0) ? "YUV411P"
\   : (FindStr(format,"RGB"     )>0) ? "RGBP"
\   : (FindStr(format,"rgb"     )>0) ? "RGBP"
\   : (        format=="JPEG"      ) ? "YUV420P"
\   : (        format=="JPG"       ) ? "YUV420P"
\   : (FindStr(format,"ICtCp"   )>0) ? "ICtCp"
\   : (FindStr(format,"ictcp"   )>0) ? "ICtCp"
\   : (FindStr(format,"IPT"     )>0) ? "ICtCp"
\   : (FindStr(format,"ipt"     )>0) ? "ICtCp"
\   : (FindStr(format,"YcCbcCr" )>0) ? "YcCbcCrc"
\   : (FindStr(format,"yccbccr" )>0) ? "YcCbcCrc"
\   : (FindStr(format, "410"    )>0) ? "YUV9"
\   : (FindStr(format,"YUV9"    )>0) ? "YUV9"
\   : (        format=="YCbCr"     ) ? "YUV420P"
\   : (        format=="YPbPr"     ) ? "YUV420P"
\   : (        format=="YCC"       ) ? "YUV420P"
\   : Assert (false, "Unsupported Color Format.")

    format = format=="ICtCp"    ? format : \
             format=="YcCbcCrc" ? format : \
             format=="YUV9"     ? format : \
             bits < 32          ? format + string(bits) : format + "S"
    format }



function bicubic_coeffs (string kernel) {

    rb  = 12./(19.+9.*sqrt(2.))      # 0.378216
    rc  = 113./(58.+216.*sqrt(2.))   # 0.310892
    rsb = 6./(13.+7.*sqrt(2.))       # 0.262015
    rsc = 7./(2.+12.*sqrt(2.))       # 0.368993

    coeffs =
\     (kernel == "Catmull-Rom"       ) ? [0.0,0.5]
\   : (kernel == "Mitchell-Netravali") ? [1/3.,1/3.]
\   : (kernel == "Robidoux"          ) ? [rb,rc]
\   : (kernel == "Robidoux Sharp"    ) ? [rsb,rsc]
\   : (kernel == "Hermite"           ) ? [0.0,0.0]
\   : (kernel == "B-Spline"          ) ? [1.0,0.0]
\   : (kernel == "Sharp"             ) ? [0.0,1.0]
\   : (kernel == "Precise Bicubic"   ) ? [0.0,0.75]
\   : (kernel == "Didée"             ) ? [-0.5,0.25]
\
\   : (kernel == "Catmull"           ) ? [0.0,0.5]
\   : (kernel == "catrom"            ) ? [0.0,0.5]
\   : (kernel == "Mitchell"          ) ? [1/3.,1/3.]
\   : (kernel == "Mitchel"           ) ? [1/3.,1/3.]
\   : (kernel == "Robi"              ) ? [rb,rc]
\   : (kernel == "RobiSharp"         ) ? [rsb,rsc]
\   : (kernel == "RobidouxSharp"     ) ? [rsb,rsc]
\   : (kernel == "Spline"            ) ? [1.0,0.0]
\   : (kernel == "B-cubic"           ) ? [0.0,1.0]
\   : (kernel == "Precise"           ) ? [0.0,0.75]
\   : (kernel == "Dide"              ) ? [-0.5,0.25]
\   : (kernel == "Didee"             ) ? [-0.5,0.25]
\   : (kernel == "Didee"             ) ? [-0.5,0.25] : [-1,-1]

    coeffs }


# JPEGs uses Rec.601 primaries, PC Levels, MPEG1 chroma placement, and can be many formats; from RGB to 420,440,444,422, etc
function chroma_placement (clip a, int UVw, int UVh, string matrix, string format, string "cplace") {

    w          = UVw                             # target UV dimensions
    h          = UVh

    plane      = isRGB(a) ? a : ExtractU(a)      # source UV dimensions
    rw         = width (plane) / float(w)
    rh         = height(plane) / float(h)

                         # source chroma placement
    dplace = matrix == "sRGB"        ? "JPEG"     : \
             format == "YUV444P"     ? "center"   : \
             format == "YUV420P"     ? "MPEG2"    : \
             format == "YUV422P"     ? "MPEG1"    : \
             format == "YUV411P"     ? "MPEG1"    : \
             FindStr(matrix,"2020")>0? "top_left" : \
             FindStr(matrix,"2100")>0? "top_left" : \
             format == "YcCbcCrc"    ? "top_left" : \
             format == "ICtCp"       ? "top_left" : \
             format == "YUV9"        ? "DV"       : "MPEG2"

    cplace = Default (cplace, dplace)
    cplace = cplace=="" ? dplace : cplace

    cloc   = cplace == "MPEG2"       ? [-0.25,  0.0]  : \
             cplace == "left"        ? [-0.25,  0.0]  : \
             cplace == "MPEG1"       ? [ 0.0,   0.0]  : \
             cplace == "center"      ? [ 0.0,   0.0]  : \
             cplace == "JPEG"        ? [ 0.0,   0.0]  : \
             cplace == "JPG"         ? [ 0.0,   0.0]  : \
             FindStr(cplace,"2020")>0? [-0.25, -0.25] : \
             FindStr(cplace,"2100")>0? [-0.25, -0.25] : \
             cplace == "top_left"    ? [-0.25, -0.25] : \
             cplace == "DV"          ? [-0.25, -0.25] : \
             cplace == "bottom_left" ? [-0.25, -0.25] : \
             Assert (false, "Unsupported chroma placement mode.")

#   cplaceH                 cplaceV
    [cloc[0]*(1-rw), cloc[1]*(1-rh)] }


function Matrix_fuzzy_search (string matrix) {

    matrix =
\     (FindStr(matrix,"709" )>0 ) ? "Rec709"
\   : (FindStr(matrix,"1886")>0 ) ? "Rec709"
\   : (matrix == "srgb"         ) ? "sRGB"
\   : (FindStr(matrix, "601")>0 ) ? "Rec601"
\   : (FindStr(matrix, "525")>0 ) ? "Rec601"
\   : (FindStr(matrix, "170")>0 ) ? "Rec601"
\   : (matrix == "jpeg"         ) ? "Rec601"
\   : (matrix == "jpg"          ) ? "Rec601"
\   : (matrix == "NTSC"         ) ? "Rec601"
\   : (matrix == "YCC"          ) ? "Rec601"
\   : (matrix == "YCbCr"        ) ? "Rec601"
\   : (matrix == "YPbPr"        ) ? "Rec601"
\   : (FindStr(matrix,"NCL" )>0 ) ? "Rec2020NCL"
\   : (FindStr(matrix,"CL"  )>0 ) ? "Rec2020CL"
\   : (FindStr(matrix,"2020")>0 ) ? "Rec2020NCL"
\   : (FindStr(matrix,"2084")>0 ) ? "Rec2020DV5"
\   : (FindStr(matrix,"2100")>0 ) ? "Rec2020DV5"
\   : (matrix == "Adobe"        ) ? "AdobeRGB"
\   : (matrix == "AdobeRGB"     ) ? "AdobeRGB"
\   : (matrix == "AdobeWideGamut")? "AWG"
\   : (matrix == "AWG"          ) ? "AWG"
\   : (FindStr(matrix, "DCI")>0 ) ? "DCI-P3"
\   : (matrix == "DCI"          ) ? "DCI-P3"
\   : (matrix == "P3"           ) ? "Display-P3"
\   : (matrix == "P3D65"        ) ? "Display-P3"
\   : (FindStr(matrix,"Display")>0)?"Display-P3"
\   : (matrix == "Display"      ) ? "Display-P3"
\   : (matrix == "AP1"          ) ? "ACEScg"
\   : (matrix == "AP0"          ) ? "ACES2065"
\   : (matrix == "ACEScg"       ) ? "ACEScg"
\   : (FindStr(matrix,"ACES2")>0 ) ? "ACES2065"
\   : (FindStr(matrix, "240")>0 ) ? "240M"
\   : (matrix == "PAL"          ) ? "470BG"
\   : (FindStr(matrix,"470" )>0 ) ? "470BG"
\   : (FindStr(matrix,"625" )>0 ) ? "470BG"
\   : Assert (false, "Unsupported Color Space.")

       matrix }


# NTSC and PAL YCbCr share the same coefficients defined in the link below, and derived from the old SMPTE 470M (NTSC 1953) standard.
# https://poynton.ca/PDFs/coloureq.pdf - 10.4
function Matrix_coef (string matrix) {

    mat_i =
\     (matrix == "srgb"           ) ? 1
\   : (matrix == "Rec601"         ) ? 0
\   : (matrix == "Rec709"         ) ? 1
\   : (matrix == "Rec2020CL"      ) ? 5
\   : (matrix == "Rec2020NCL"     ) ? 5
\   : (matrix == "AdobeRGB"       ) ? 6
\   : (matrix == "AWG"            ) ? 7
\   : (matrix == "Display-P3"     ) ? 8
\   : (matrix == "DCI-P3"         ) ? 9
\   : (matrix == "ACEScg"         ) ? 10
\   : (matrix == "ACES2065"       ) ? 11
\   : (matrix == "240M"           ) ? 3
\   : (matrix == "470BG"          ) ? 0
\   : Assert (false, "Unsupported Color Space.")

    mat_w =
\     (matrix == "Rec601"         ) ? 0
\   : (matrix == "Rec709"         ) ? 1
\   : (matrix == "DCI-P3"         ) ? 3
\   : (matrix == "ACES2065"       ) ? 4
\   : (matrix == "ACEScg"         ) ? 4
\   : (matrix == "470BG"          ) ? 0
\   : (matrix == "AWG"            ) ? 2
\   :                                 1

    mat_wp =
\     (matrix == "Rec601"         ) ? 1
\   : (matrix == "Rec709"         ) ? 1
\   : (matrix == "DCI-P3"         ) ? 3
\   : (matrix == "ACES2065"       ) ? 4
\   : (matrix == "ACEScg"         ) ? 4
\   : (matrix == "AWG"            ) ? 2
\   :                                 1

    #                    NTSC 1953/YCbCr   ITU-R BT.709/sRGB  ITU-R BT.601    Y’PbPr 601        PAL/SECAM         BT-2020/BT-2100   Adobe RGB (1998)  Adobe Wide Gamut  Display-P3/D65P3  DCI-P3            AP1                AP0
    #                    SMPTE 470M        IEC 61966-2-1      SMPTE 170M      SMPTE 240M        BT-470BG          BT-2020/BT-2100   Adobe RGB (1998)  AWG               SMPTE RP 432-1    SMPTE RP 431-2    ACEScg             SMPTE ST 2065-1
    pr = Select (mat_i,  [0.670,  0.330],  [0.640, 0.330],  [0.630,  0.340],  [0.630,  0.340],  [0.640,  0.330],  [0.708,  0.292],  [0.640,  0.330],  [0.7347,0.2653],  [0.680,  0.320],  [0.680,  0.320],  [0.713,   0.293],  [0.7347,  0.2653])
    pg = Select (mat_i,  [0.210,  0.710],  [0.300, 0.600],  [0.310,  0.595],  [0.310,  0.595],  [0.290,  0.600],  [0.170,  0.797],  [0.210,  0.710],  [0.1152,0.8264],  [0.265,  0.690],  [0.265,  0.690],  [0.165,   0.830],  [0.0000,  1.0000])
    pb = Select (mat_i,  [0.140,  0.080],  [0.150, 0.060],  [0.155,  0.070],  [0.155,  0.070],  [0.150,  0.060],  [0.131,  0.046],  [0.150,  0.060],  [0.1566,0.0177],  [0.150,  0.060],  [0.150,  0.060],  [0.128,   0.044],  [0.0001, -0.0770])
    pw = Select (mat_w,  [0.310,  0.316],  [0.312713, 0.329016],                                                                                      [0.3457,0.3585],                    [0.314,  0.351],  [0.32168,0.33767]                   )
    wp = Select (mat_wp, [0.310,  0.316],  [0.312713, 0.329016],                                                                                      [0.3457,0.3585],                    [0.314,  0.351],  [0.32168,0.33767]                   )
    Kv = Select (mat_wp,  6779.653      ,   6504.13            ,                                                                                       5000.569      ,                     6304.573      ,   6000.211                           )

    pr2 = 1. - pr[0] - pr[1]    pw2 = 1. - pw[0] - pw[1]
    pb2 = 1. - pb[0] - pb[1]    wp2 = 1. - wp[0] - wp[1]
    pg2 = 1. - pg[0] - pg[1]

    det = (pw[1] * (pr[0] * (pg[1] * pb2 - pb[1] * pg2) + pg[0] * (pb[1] * pr2 - pr[1] * pb2) + pb[0] * (pr[1] * pg2   - pg[1] * pr2)))
    kr  = (pr[1] * (pw[0] * (pg[1] * pb2 - pb[1] * pg2) + pw[1] * (pb[0] * pg2 - pg[0] * pb2) + pw2   * (pg[0] * pb[1] - pb[0] * pg[1]))) / det
    kb  = (pb[1] * (pw[0] * (pr[1] * pg2 - pg[1] * pr2) + pw[1] * (pg[0] * pr2 - pr[0] * pg2) + pw2   * (pr[0] * pg[1] - pg[0] * pr[1]))) / det
    kg  = 1. - kb - kr

    [kr, kg, kb, wp[0], wp[1], wp2] }



function moncurve_coef (string matrix) {

    t_num =
\     (matrix == "Rec709"     ) ? 4
\   : (matrix == "Rec601"     ) ? 1
\   : (matrix == "sRGB"       ) ? 0
\   : (matrix == "jpeg"       ) ? 0
\   : (matrix == "jpg"        ) ? 0
\   : (matrix == "Rec2020"    ) ? 1
\   : (matrix == "Rec2020CL"  ) ? 1
\   : (matrix == "Rec2020NCL" ) ? 1
\   : (matrix == "Rec2020DVp5") ? 1
\   : (matrix == "AdobeRGB"   ) ? 5
\   : (matrix == "AWG"        ) ? 5
\   : (matrix == "Display-P3" ) ? 0
\   : (matrix == "DCI-P3"     ) ? 6
\   : (matrix == "ACEScg"     ) ? 7
\   : (matrix == "ACES2065"   ) ? 7
\   : (matrix == "240M"       ) ? 2
\   : (matrix == "470BG"      ) ? 3
\   : Assert (false, "Unsupported Color Space.")


       /* Coeff Derivations:
          BT.2020/SMPTE 170M "simultaneous equations" require brute force root-finding algos (ie. bisection method)
          Added only as reference here since moncurve_x() functions compute them correctly from "alpha" coeff.

        #   alpha = offset     (x coord - 1)
        #   beta  = transition (y coord)= K0/Phi
        #   phi   = slope
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


    #                                                SMPTE-C    / BT-2020           Y’PbPr 601              PAL/SECAM                      Rec.709  AdobeRGB  DCI-P3  AP1/AP0
    #                       sRGB                     SMPTE 170M / BT-2020           SMPTE 240M              BT-470BG                       BT-1886  AdobeRGB  DCI-P3  ACES
    t_gamma = Select(t_num, 2.40                   , 1/0.45                       , 1/0.45                , 2.80                         , 2.40   , 563/256., 2.60  , 1.0  )
    t_alpha = Select(t_num, 0.055                  , 0.099296826809442940347282759, 0.1115                , 0.099296826809442940347282759, 0      , 0       , 0     , 0    )
    t_beta  = Select(t_num, 0.00303993463977843    , 0.018053968510807807335869592, 0.02280681818181818182, 0.00410749063249639977       , 0      , 0       , 0     , 0    )
    t_k0    = Select(t_num, 0.03928571428571428571 , 0.081242858298635133011413164, 0.09122727272727272727, 0.05516490378302385575       , 0      , 0       , 0     , 0    )
    t_phi   = Select(t_num, 12.92321018078786109464, 4.5                          , 4.0                   , 13.43031761206876179575      , 4.5    , 0       , 0     , 0    )

    [t_gamma, t_alpha] }



function RGB_to_XYZ (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    matrix =        cspace == "sRGB"   || cspace == "Rec709"                                            ?  \
                                        [ 0.41241079568862915, 0.21264933049678802, 0.01933175697922707,   \
                                          0.35758456587791443, 0.71516913175582890, 0.11919485777616501,   \
                                          0.18045382201671600, 0.07218152284622192, 0.95039016008377080] : \
                    cspace == "Rec601" || cspace == "240M"                                              ?  \
                                        [ 0.39354196190834045, 0.21238772571086884, 0.0187400933355093,    \
                                          0.36525884270668030, 0.70106136798858640, 0.1119341626763344,    \
                                          0.19164848327636720, 0.08655092865228653, 0.9582424163818359]  : \
                    FindStr(cspace, "ec2")>0                                                            ?  \
                                        [ 0.63697350025177000, 0.24840137362480164, 0.00000000000000000,   \
                                          0.15294560790061950, 0.67799961566925050, 0.04253686964511871,   \
                                          0.11785808950662613, 0.03913172334432602, 1.06084382534027100] : \
                    cspace == "DCI-P3"                                                                  ?  \
                                        [ 0.44516983628273010, 0.20949168503284454, 0.00000000000000000,   \
                                          0.27713435888290405, 0.72159516811370850, 0.04706055670976639,   \
                                          0.17228263616561890, 0.06891304999589920, 0.90735518932342530] : \
                    cspace == "Display-P3"                                                              ?  \
                                        [ 0.48659050464630127, 0.22898375988006592, 0.00000000000000000,   \
                                          0.26566821336746216, 0.69173991680145260, 0.04511347413063049,   \
                                          0.19819043576717377, 0.07927616685628891, 1.04380297660827640] : \
                    cspace == "AdobeRGB"                                                                ?  \
                                        [ 0.57666999101638790, 0.29734000563621520, 0.02703000046312809,   \
                                          0.18556000292301178, 0.62735998630523680, 0.07068999856710434,   \
                                          0.18822999298572540, 0.07529000192880630, 0.99133998155593870] : \
                    cspace == "AWG"                                                                     ?  \
                                        [ 0.71650063991546630, 0.258728206157684300, 0.00000000000000000, \
                                          0.10102055221796036, 0.724682152271270800, 0.05121181160211563, \
                                          0.14677436649799347, 0.016589440405368805, 0.77389270067214970]: \
                    cspace == "ACEScg"                                                                  ?  \
                                        [ 0.66332850000000000, 0.27258800000000000, 0.00000000000000000,   \
                                          0.13399166000000000, 0.67401860000000000, 0.00406035300000000,   \
                                          0.15532595000000000, 0.05339329000000000, 1.00476470000000000] : \
                    cspace == "ACES2065"                                                                ?  \
                                        [ 0.95253682136535640000,  0.34396082162857056, 0.0000000000000000,\
                                          0.00000000000000000000,  0.74020814895629880, 0.0000000000000000,\
                                          0.00010931033466476947, -0.08416896313428879, 1.0088251829147339]:\
                    cspace == "470BG"                                                                   ?  \
                                        [ 0.43057379126548767, 0.22201462090015410, 0.02018314599990845,   \
                                          0.34154993295669556, 0.70665508508682250, 0.12955342233181000,   \
                                          0.17832535505294800, 0.07133013755083084, 0.93918019533157350] : \
                    Assert(false,"Unsupported Color Space.")

    list ? matrix : MatrixClip(rgb, matrix) }




function XYZ_to_RGB (clip rgb, string cspace, bool "list") {

    list = Default(list, false)

    matrix =        cspace == "sRGB"   || cspace == "Rec709"                                                ?  \
                                        [  3.24081254005432130, -0.96924304962158200,  0.055638398975133896,   \
                                          -1.53730857372283940,  1.87596631050109860, -0.204007431864738460,   \
                                          -0.49858659505844116,  0.04155505076050758,  1.057129383087158200] : \
                    cspace == "Rec601" || cspace == "240M"                                              ?  \
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
                    cspace == "ACEScg"                                                                      ?  \
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
                     Assert(false,"Unsupported Color Space.")

    list ? matrix : MatrixClip(rgb, matrix) }


# Chromatic Adaptation
function c_adaptation (clip c, string "source", string "target", bool "tv_range", bool "list") {

    isRGBc = IsRGB(c)

    src    = Default (source, "sRGB")
    tgt    = Default (target, "sRGB")
    list   = Default (list, false)
    range  = Default (tv_range,  !isRGBc )

    src    = list ? src : Matrix_fuzzy_search (src)
    tgt    = list ? tgt : Matrix_fuzzy_search (tgt)
    wps    = Matrix_coef(src)
    wpt    = Matrix_coef(tgt)
    same   = wps[3] == wpt[3]

    CAT02  = [0.7328,  0.4296, -0.1624, \
             -0.7036,  1.6975,  0.0061, \
              0.0030, -0.0136,  0.9834]

    wpsn   = MatrixDot([wps[3]/wps[4],1.,wps[5]/wps[4]], CAT02)
    wptn   = MatrixDot([wpt[3]/wpt[4],1.,wpt[5]/wpt[4]], CAT02)
    trans  = MatrixDiv(wptn,wpsn)
    vk     = [same?1:trans[0],   0.0000,        0.0000,  \
              0.0000,   same?1:trans[1],        0.0000,  \
              0.0000,            0.0000,same?1:trans[2]]

    CAM    = !same ? MatrixDot(CAT02, MatrixDot(vk, MatrixInvert(CAT02))) : vk

    if (!list) {

        c
        s_gam  = moncurve_coef(src)

        RGBpln = isRGBc ? IsPlanar() : false

        isRGBc ? RGBpln ? last : ConvertToPlanarRGB() : \
        YUV_to_RGB(c, src, tv_range_in=range, tv_range_out=false, kernel="Point")

        moncurve_f(s_gam[0], s_gam[1], false, false)

        mata = RGB_to_XYZ  (src,      list=true)
        matb = XYZ_to_RGB  (src,      list=true)
        MatrixClip( MatrixDot(MatrixDot(mata, CAM), matb) )

        moncurve_r(s_gam[0], s_gam[1], false, false)

        isRGBc ? RGBpln ? last : MatchColorFormat(c) : \
        RGB_to_YUV( src, tv_range_in=false, tv_range_out=range, kernel="Point", pixel_type=PixelType(c))
        same ? c : last

    } else { CAM } }



function SMPTE_legal (clip a, bool "forward", int "Y", int "UV") {

    fw = Default(forward, true)    # forward converts to SMPTE legal, otherwise converts to Full Range.
    Y  = Default(Y,  3 )
    UV = Default(UV, 3 )
    bi = BitsPerComponent(a)

    str  = fw ? "x ymax ymin - range_max / * ymin +"  : \
                "x ymin - range_max ymax ymin - / *"

    strY = ex_Yexpr(a, str,  Y)

    UV == 1 ? isy(a) ? Expr(a, strY) : Expr(a,  strY, "")                                   : \
                       Expr(a, strY, ex_UVexpr(a, str, UV, bi), scale_inputs=ex_UVf(a, bi)) }


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
