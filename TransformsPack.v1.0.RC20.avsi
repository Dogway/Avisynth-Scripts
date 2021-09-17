###########################################################
###                                                      ##
###                                                      ##
###    Transforms Pack v1.0 RC21  (16-09-2021)           ##
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
### With color management in place, I took it one step further and made ConvertFormat(),
### replacement for (Dither Tools based) LinearResizer() and clearly inspired
### by avsresize's z_ConvertFormat() with more features, accuracy and easier to use.
###
###
### Dependencies: AviSynth+ 3.7.1 and over
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
    LUT        = Default (LUT, Undefined()) # Display LUT (the path string of your monitor .cube 3D LUT, if calibrated)
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
### Dependencies: AviSynth+ 3.7.1 and over
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
###       ConvertFormat(1,1,"RGB","jpeg","sRGB",false,false,true,cplace_in="MPEG1",UVRecon=true)
###   ConvertBits(8, dither=1)
###
####################################


# List of Color Models-Formats:
#
# RGB      - RGB color model for channels Red, Green, and Blue. Normally found in interleaved packing format. AviSynth works best with planar RGB so a conversion is first needed.
# YCbCr    - Color format based on human perception of luma and chroma contribution. Uses 3 planes for Luma, opposing blue-yellow, and opposing red-green.
# YUVr     - "YUV RCT". Same as YUV but fully reversible to RGB
# sYUV     - "Sharp YUV". Same as YUV but luma-weighted chroma subsampling, retaining chroma fidelity.
# YcCbcCrc -
# xvYCC    -
# OPP      -
# YCgCo    - Better luma/chroma decorrelation and compression efficiency than YCbCr
# YCgCoR   - Same as YCgCo but losslessly reversible to RGB
# ICtCp    - HDR version of YUV.
# YDzDx    - HDR version of XYZ. Requires at least 10-bit for no visible quantization.
# YDuDv    - HDR version of CIE Luv. Requires only 8-bit for no visible quantization.
# XYZ      -
# Yxy/xyY  - Chroma normalized XYZ space which gives full luma/chroma decorrelation.
# Jzazbz   -
# JzCzhz   -
# HSV      -
# Duv      -
# CIELuv   -
# CIEDuDv  - HDR version of CIE Luv
# CIELab   -
# CIEsLab  - CIE simple Lab
# HunterLab- A more perceptually uniform version of CIELab


# Resizer Plugins:
#
# SimpleResize (2 tap lin) (8-bit)            (dw) http://avisynth.nl/index.php/SimpleResize (same than Area and ~SSIM but without pixel centering, very fast)
# Box/Area Average                            (dw) https://github.com/EleonoreMizo/fmtconv
# SSIM                                        (dw) https://github.com/mysteryx93/AviSynthShader/releases
# SincLin2ResizeMT                            (up) https://github.com/jpsdr/ResampleMT/releases (like a sharper lanczos)
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
# Bicubic / Cubic
# Spline / Cubic Polynomials
# Sinc     is a box-windowed      sinc filter (2 lobes).
# Lanczos  is a Lanczos-windowed  sinc filter (3 lobes).
# Blackman is a Blackman-windowed sinc filter (3 lobes). (improved lanczos with less ringing)

# Missing. ref: https://github.com/mpv-player/mpv/blob/master/video/out/filter_kernels.c
#          ref: https://artoriuz.github.io/blog/mpv_upscaling.html
# Bartlett is a Bartlett-windowed sinc filter (3 lobes).
# Hann(ing) is a Hanning-windowed sinc filter (3 lobes).
# Hamming is a Hamming-windowed sinc filter (3 lobes).
# Welch is a Welch-windowed sinc filter (parabolic window, 3 lobes).
# Cosine is a Cosine-windowed sinc filter (3 lobes).
# Bessel is a unnormalized sinc filter (3 lobes).
# Ginseng is a Jinc-windowed sinc filter (3 lobes).
# Quadratic / Quadric, like Cubic but 66% faster
# RAVU / RAISR (similar to XBR and nnedi3)
# NGU - Next Generation Upscaler. madVR edge directed NN algo (closed source, similar to FSRCNN)
# Jinc is a Box-windowed jinc filter (3 lobes).
# ewa_hanning is a Hanning-windowed jinc filter (3 lobes).
# ewa_ginseng is a sinc-windowed jinc filter (3 lobes).
# -ewa_lanczos is a lanczos-windowed jinc filter (3 lobes).
# -ewa_lanczossharp is a lanczos-windowed jinc filter (3.238 lobes). Slightly sharpened as per calculations by Nicolas Robidoux. 3.2383154841662362, jinc, .blur = 0.9812505644269356
# -ewa_lanczossoft is a lanczos-windowed jinc filter (3.238 lobes). Softened instead. This one makes hash patterns disappear completely. 3.2383154841662362, jinc, .blur = 1.015
# -Haasnsoft is a Hanning-windowed jinc filter (3.238 lobes). Removes almost all aliasing. Blur value to match orthogonal and diagonal contributions. 3.2383154841662362, jinc, .blur = 1.11
# Tukey - hanning window, taper = 0.5
# Sphinx - Continuation of Sinc and Jinc. interpolating all three dimensions at the same time using a carefully constructed filter that has a perfectly spherical frequency response. 1.4302966531242027, sphinx window.
# ICBI (Iterative Curve Based Interpolation) is a single image superresolution technique described in Fast artifact-free image interpolation by Andrea Giachetti and Nicola Asuni, presented at BMVC 2008

function ConvertFormat (clip clp, val "width", val "height", string "fmt_i", string "fmt_o", string "cs_in", string "cs_out", bool "tv_range_in", bool "tv_range_out", bool "linear_in", bool "linear_out",        \
                        bool "gamma", string "cplace_in", string "cplace_out", string "kernel", string "kernel_c", float "src_left", float "src_top", float "src_width", float "src_height", \
                        string "scale_space", float "p", int "mod", bool "nomoiree", bool "noring", bool "UVrecon", bool "fulls", bool "fulld", bool "debug") {

    clp
    w          = width ()
    h          = height()
    fc         = FrameCount() < 2
    p_type     = PixelType()
    bdpth      = BitsPerComponent()


    nw         = Default (width,   1)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target width
    nh         = Default (height, nw)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target height
    fmt_i      = Default (fmt_i,    "")
    fmt_o      = Default (fmt_o, fmt_i)
    i_fmt      = Format_fuzzy_search (fmt_i=="" ? p_type : fmt_i, bdpth)
    o_fmt      = Format_fuzzy_search (fmt_o=="" ? p_type : fmt_o, bdpth)
    isRGBi     = i_fmt[0]=="RGB"
    isRGBo     = o_fmt[0]=="RGB"

    isRGBi ? ConvertToPlanarRGB() : last

    mod        = Default (mod, isRGBo ? 1 : 2) # mod size for resizing. ie: 1, 2, 4, 8, 16...

    nw         = isInt(nw) && nw<=10 ? float(nw) : isFloat(nw) && nw>10. ? int(nw) : nw
    nh         = isInt(nh) && nh<=10 ? float(nh) : isFloat(nh) && nh>10. ? int(nh) : nh
    nw         =  nw<=10. ? w*nw : nw            nw     = round(nw/mod)*mod
    nh         =  nh<=10. ? h*nh : nh            nh     = round(nh/mod)*mod
    isUHD      = ( w > 2599 ||   h > 1499)       isnUHD = (nw > 2599 ||  nh > 1499)
    isHD       = ( w > 1099 ||   h > 599 )       isnHD  = (nw > 1099 ||  nh > 599 )
    wr         = float(nw) / w                   hr     = float(nh) / h
    rat        = max(abs(wr - 1),abs(hr - 1)) == abs(wr - 1) ? wr : hr

    cs_in      = Default (cs_in,   isRGBi || fc ? "jpeg"                : isUHD  ? "2020" : isHD  ? "709"   : "601")
    cs_out     = Default (cs_out, (cs_in == "jpeg" || cs_in == "srgb") && isRGBo ? "srgb" : isnUHD ? "2020" : isnHD ? "709" : "601")
    linei      = Default (linear_in,  false)
    lineo      = Default (linear_out, false)
    tv_in      = Default (tv_range_in,                         !(isRGBi || cs_in =="sRGB" || cs_in =="jpeg" || cs_in =="jpg") )
    tv_out     = Default (tv_range_out, cs_out == "" ? tv_in : !(isRGBo || cs_out=="sRGB" || cs_out=="jpeg" || cs_out=="jpg") )
    kernel     = Default (kernel,   (w>nw||h>nh)?"Didee":"Precise")
    kernel_c   = Default (kernel_c, kernel)
    space      = Default (scale_space, "gamma")  # resizing space: "gamma", "linear", "sigmoid" or "log" for quasi-log. Assumes gamma encoded input.
    cplace_in  = Default (cplace_in,   "")       # Assumes default from format
    cplace_out = Default (cplace_out,  "")       # Assumes default from format
    p          = Default (p,         15)
    src_left   = Default (src_left, 0.0)
    src_top    = Default (src_top,  0.0)
    src_width  = Default (src_width,  w)
    src_height = Default (src_height, h)
    noring     = Default (noring,  false)
    nomoir     = Default (nomoiree,false)
    recon      = Default (UVrecon, false)
    fs         = Default (fulls,   false)


    ############ Data extraction and normalization + Asserts ############

                 Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    !(isInt(nw) || isInt(nh) || isFloat(nw) || isFloat(nh))                  ? \
                 Assert(false, "Width/Height type not supported.")           : nop()
    !(space=="sigmoid" || space=="gamma" || space=="linear" || space=="log") ? \
                 Assert(false, "Invalid space type.")                        : nop()


    cs_in    =                Matrix_fuzzy_search (cs_in)
    cs_out   = cs_out != "" ? Matrix_fuzzy_search (cs_out) : cs_in
    space    = space  != "" ? space : "gamma"

    isGamma  = Default (gamma, (cs_in != cs_out) || (linei!=lineo))
    isSpace  = cs_in    !=  cs_out
    isFrmt   = i_fmt[0] !=  o_fmt[0]
    isScale  = nw!=w    ||  nh!=h

    coef_i   =           Matrix_coef(cs_in)
    coef_o   = isSpace ? Matrix_coef(cs_out) : coef_i
    s_gam    =           moncurve_coef (linei?"linear":cs_in)
    t_gam    = isGamma ? moncurve_coef (lineo?"linear":cs_out) : s_gam
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

     i_type1  || o_type1        ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411")      : nop()
     i_type10 || o_type10       ? Assert(false,     "Unsupported Pixel Type: YUV410")           : nop()
     !isRGBi                    ? Assert(h%2==0,  "Clip Height is not mod2." )                  : nop()
     i_type2||i_fmt[1]=="420"   ? Assert(w%2==0,  "Clip Width is not mod2." )                   : nop()
     i_type1                    ? Assert(w%4==0,  "Clip Width is not mod4." )                   : nop()
     o_type1                    ? Assert(nw%4==0, "Target Width is not mod4." )                 : nop()
    !(isRGBo ||  o_type4 || (cnw>cow || cnh>coh))                                               ? \
                                  Assert(!recon, "Invalid settings for chroma reconstruction.") : nop()


    resampler = Format( kernel == "nnedi3"       ?"nnedi3_resize16({nw},{nh}"                                : \
                        kernel == "Bicubic"      ?  "BicubicResize({nw},{nh},b={bc_b},c={bc_c}"              : \
                        kernel == "Spline100"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=5"""      : \
                        kernel == "Spline144"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=6"""      : \
                        kernel == "SincLin"      || kernel == "SincLin2ResizeMT"                             ? \
                                                 "SincLin2ResizeMT({nw},{nh},taps=16"                        : \
                        kernel == "SinPow"      || kernel == "SinPowResizeMT"                                ? \
                                                 "SinPowResizeMT({nw},{nh}"                                  : \
                        kernel == "ResizeShader" || kernel == "SSIM"                                         ? \
                                                   """ResizeShader({nw},{nh},kernel="SSIM",b=0.1"""          : \
                        kernel == "Gauss"        ?    "GaussResize({nw},{nh},p=p"                            : \
                        kernel == "Average"      || kernel == "Box"       || kernel == "Area"                ? \
                                                     """fmtc_resample({nw},{nh},kernel="box" """             : \
                        kernel == "Sinc"         ?     "SincResize({nw},{nh},taps=2"                         : \
                        kernel == "EWA"          || kernel == "Jinc"      || kernel == "ewa_lanczos"         ? \
                                                       "JincResize({nw},{nh},tap=3"                          : \
                        kernel == "EWASharp"     || kernel == "JincSharp" || kernel == "ewa_lanczossharp"    ? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.9812505644269356"  : \
                        kernel == "EWASoft"      || kernel == "JincSoft"  || kernel == "ewa_lanczossoft"     ? \
                                                       "JincResize({nw},{nh},tap=3,blur=1.015"               : \
                        kernel == "Haasn"        || kernel == "HaasnSoft" || kernel == "ewa_haasn"           ? \
                                                       "JincResize({nw},{nh},tap=3,blur=1.11"                : \
                        kernel == "FCBI"         ? "FCBI().BicubicResize({nw},{nh},b=-0.5,c=0.25"            : \
                        kernel == "SuperResXBR"  || kernel == "XBR"                                          ? \
                                                         "SuperResXBR(factor=2)."                              \
                                                   +"BicubicResize({nw},{nh},b=-0.5,c=0.25"                  : \
                        kernel == "Krig"         || kernel == "KrigBilateral"                                ? \
                                    "KrigBilateral().BicubicResize({nw},{nh},b=-0.5,c=0.25"                  : \
                        kernel == "FSRCC"        || kernel == "AiUpscale"                                    ? \
                                             """AiUpscale(2,Luma="Medium",Chroma="Spline36",Mode="Photo")."""  \
                                                   +"BicubicResize({nw},{nh},b=-0.5,c=0.25"                  : \
                        kernel +                           "Resize({nw},{nh}"                                 )


    src_nul = kernel == "ResizeShader" || kernel == "SSIM"
    src_box = kernel == "Average" || kernel == "Box" || kernel == "Area" || kernel == "Spline100" || kernel == "Spline144"
    src_wh  = src_box ? Format(",sw={src_width},sh={src_height}") : Format(",src_width={src_width},src_height={src_height}")
    src_whc = src_box ? Format(",sw={cow},     sh={coh}")        : Format(",src_width={cow},      src_height={coh}")
    fmtcb   = Format(".ConvertBits({bdpth},fulls={fs})")
    src_c   = src_nul ? "" : src_box ? Format(",sx={src_left},sy={src_top}"+src_wh+")"+fmtcb) : src_nr
    src_nr  = Format(",src_left={src_left},src_top={src_top}"+src_wh+")")
    Ynr     = Format(".Repair(BicubicResize(Y,{nw},{nh},0,0"+src_nr+",1)")

    cplacei  = chroma_placement(cow, coh, cs_in,  i_fmt[0]+i_fmt[1], cplace_in )
    cplaceo  = chroma_placement(cnw, cnh, cs_out, o_fmt[0]+o_fmt[1], cplace_out)

    if (!isSpace && !isFrmt) {

        UVr = isRGBi ? 3 : 1
        space == "linear"  ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr, fs)                                       : \
        space == "sigmoid" ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr, fs).ex_contrast(-1.15,0,191,false,UVr,fs) : \
        space == "log"     ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr, fs).ACEScct_f(UV=UVr,fulls=fs)            : \
                             last

        nomoir ? ex_blur((1. / rat) / 2., bifit=false) : last
        Ynr   = ReplaceStr(Ynr, "(Y,", "(")
        Eval("" + resampler + src_c + (noring ? Ynr : ""))

        space == "linear"  ?                                      moncurve_r(t_gam[0], t_gam[1], false, tv_out, UVr, fs) : \
        space == "sigmoid" ? ex_contrast(1.15,0,191,false,UVr,fs).moncurve_r(t_gam[0], t_gam[1], false, tv_out, UVr, fs) : \
        space == "log"     ? ACEScct_r(UV=UVr,fulls=fs).          moncurve_r(t_gam[0], t_gam[1], false, tv_out, UVr, fs) : \
                             last

        tv_in != tv_out ? space == "gamma"   ? SMPTE_legal(tv_out,3,  3,fs) : \
                          isScale && !isRGBi ? SMPTE_legal(tv_out,1,  3,fs) : \
                         !isScale            ? SMPTE_legal(tv_out,UVr,3,fs) : last : last

    } else if (!isRGBi) {


        if (isScale && (isRGBo || !isSpace)) {

            space == "linear"  ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 1, fs)                                     : \
            space == "sigmoid" ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 1, fs).ex_contrast(-1.15,0,191,false,1,fs) : \
            space == "log"     ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 1, fs).ACEScct_f(UV=1,fulls=fs)            : \
                                 last
        }

        Y   = ExtractY()
        Cb  = ExtractU()
        Cr  = ExtractV()

        fcnw = isSpace && !isRGBo ? w : cnw
        fcnh = isSpace && !isRGBo ? h : cnh


        if (recon && !i_type4) {

            threads = 4
            ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), "auto", wref=1)
            Luma    = ref.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false)
            Uu      =  Cb.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false, fwidth=w*2, fheight=h*2, ep0=bc_b, ep1=bc_c, cshift=kernel+"resize", mpeg2=false)
            Vu      =  Cr.nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=threads/2, prefetch=threads, SetAffinity=true, MaxPhysCore=false, fwidth=w*2, fheight=h*2, ep0=bc_b, ep1=bc_c, cshift=kernel+"resize", mpeg2=false)
            Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=-0.5, c=0.25)
            Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=-0.5, c=0.25)
            Cb      = ex_makeadddiff(Unew, Removegrain(Unew, 19), Uu.BicubicResize(fcnw, fcnh, b=-0.5, c=0.25), fulls=fs)
            Cr      = ex_makeadddiff(Vnew, Removegrain(Vnew, 19), Vu.BicubicResize(fcnw, fcnh, b=-0.5, c=0.25), fulls=fs)

        } else {

            point   = kernel=="Point" ? "+1.0" : ""
            cplaceH = (src_box ? ",sx=" : ",src_left=")+string(cplaceo[0]+cplacei[0]+src_left)+point
            cplaceV = (src_box ? ",sy=" :  ",src_top=")+string(cplaceo[1]+cplacei[1]+src_top)

            str  = ReplaceStr(ReplaceStr(resampler, "("+string(nw), "("+string(fcnw)), ","+string(nh), ","+string(fcnh))
            str  = (fcnw==cow && fcnh==coh) ? Format("PointResize({fcnw},{fcnh}") : str
            Cb   = Eval("Cb." + str + (src_nul ? "" : (cplaceH + cplaceV + src_whc)) + ")" + fmtcb)
            Cr   = Eval("Cr." + str + (src_nul ? "" : (cplaceH + cplaceV + src_whc)) + ")" + fmtcb)
            }


        if (isScale && (isRGBo || !isSpace)) {

            Y     = nomoir ? Y.ex_blur((1. / rat) / 2., bifit=false) : Y
            Y     = Eval("Y." + resampler + src_c + (noring ? Ynr : ""))
            Y     = space == "linear"                  ? Y.                                   moncurve_r(s_gam[0], s_gam[1], false, !(isRGBo || !tv_out), 1, fs) : \
                    space == "sigmoid"                 ? Y.ex_contrast(1.15,0,191,false,1,fs).moncurve_r(s_gam[0], s_gam[1], false, !(isRGBo || !tv_out), 1, fs) : \
                    space == "log"                     ? Y.ACEScct_r(UV=1,fulls=fs).          moncurve_r(s_gam[0], s_gam[1], false, !(isRGBo || !tv_out), 1, fs) : \
                                                         Y
            }


        if (!isRGBo && !isSpace) {

            CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt[1]+o_fmt[2])
            tv_in != tv_out ? space == "gamma" ? SMPTE_legal(tv_out,3,  3,fs) : \
                              isScale          ? SMPTE_legal(tv_out,1,  3,fs) : \
                             !isScale          ? SMPTE_legal(tv_out,UVr,3,fs) : last : last
            }


        if (isRGBo || isSpace) {

            if (i_fmt[0]=="YcCbcCrc") {

                RGB = YcCbcCrc_to_RGB( Y, Cb, Cr, cs_in, coef_i, !(isScale || !tv_in), !(isSpace || !tv_out), fs)

                R = RGB[0]  G = RGB[1]  B = RGB[2]

            } else if (i_fmt[0]=="YCgCo") {



            } else if (i_fmt[0]=="YCgCor") {



            } else if (i_fmt[0]=="YUVr") {


            } else if (i_fmt[0]=="ICtCp") {



            } else if (i_fmt[0]=="YCbCr") {

                scale_y   = tv_in && (isSpace || !tv_out) ? (255 / 219.) : !tv_in && !(isSpace || !tv_out) ? (219 / 255.) : 1.0
                scale_uv  = tv_in && (isSpace || !tv_out) ? (255 / 112.) : !tv_in && !(isSpace || !tv_out) ? (224 / 128.) : 2.0

                Kr = 1. - coef_i[0]
                Kb = 1. - coef_i[2]

                m0 = scale_y     m1 = 0.0                                       m2 = scale_uv * Kr
                m3 = scale_y     m4 = scale_uv * ( -Kb * coef_i[2] / coef_i[1]) m5 = scale_uv * ( -Kr * coef_i[0] / coef_i[1])
                m6 = scale_y     m7 = scale_uv * Kb                             m8 = 0.0

                range_PC = scale_y == 255/219. ? "ymin - " : ""
                range_TV = scale_y == 219/255. ? "ymin + " : ""
                UVf      = bdpth < 32          ? "range_half - " : ""

                R = Expr(Y,     Cr, ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+"                            y "+UVf + string(m2)+" * + ", bdpth, fs), optSingleMode=false)
                G = Expr(Y, Cb, Cr, ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m4)+" * + z "+UVf + string(m5)+" * + ", bdpth, fs), optSingleMode=true )
                B = Expr(Y, Cb,     ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m7)+" * +                            ", bdpth, fs), optSingleMode=false)

            }

        !isSpace ? CombinePlanes(R, G, B, planes="RGB") : last } }

    if (isRGBi) {

        isSpace || isGamma ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, 3, fs) : last
        R = ExtractR()
        G = ExtractG()
        B = ExtractB()

    } else if (isSpace || isGamma) {

        R = R.moncurve_f(s_gam[0], s_gam[1], false, false, 1, fs)
        G = G.moncurve_f(s_gam[0], s_gam[1], false, false, 1, fs)
        B = B.moncurve_f(s_gam[0], s_gam[1], false, false, 1, fs)
     }

    if (isSpace || isGamma) {

        mata = RGB_to_XYZ  (cs_in,         list=true)
        matw = c_adaptation(cs_in, cs_out, list=true)
        matb = XYZ_to_RGB  (cs_out,        list=true)
        mat  = MatrixDot(MatrixDot(mata, matw), matb)

        Ro = Expr(R, G, B, "x "+string(mat[0])+" * y "+string(mat[3])+" * + z "+string(mat[6])+" * +", optSingleMode=true)
        Go = Expr(R, G, B, "x "+string(mat[1])+" * y "+string(mat[4])+" * + z "+string(mat[7])+" * +", optSingleMode=true)
        Bo = Expr(R, G, B, "x "+string(mat[2])+" * y "+string(mat[5])+" * + z "+string(mat[8])+" * +", optSingleMode=true)
        R = Ro  G = Go  B = Bo

        isRGBo ? CombinePlanes(Ro, Go, Bo, planes="RGB") : last


    if (isRGBi && isRGBo && isScale) {


        RGB  = space == "linear"  ? moncurve_f(s_gam[0], s_gam[1], false, false, 3, fs)                                         : \
               space == "sigmoid" ? moncurve_f(s_gam[0], s_gam[1], false, false, 3, fs).ex_contrast(-1.15,0,191,false,3,fs)     : \
               space == "log"     ? moncurve_f(s_gam[0], s_gam[1], false, false, 3, fs).ACEScct_f(UV=3,fulls=fs)                : \
               isSpace            ? moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3, fs)                                        : \
                                    last

        RGB   = nomoir ? RGB.ex_blur((1. / rat) / 2.,bifit=false) : RGB
        RGBnr = ReplaceStr(Ynr, "(Y,", "(RGB,")
        RGB   = Eval("RGB." + resampler + src_c + (noring ? RGBnr : ""))

               space == "linear"  ? RGB.                                   moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3, fs) : \
               space == "sigmoid" ? RGB.ex_contrast(1.15,0,191,false,3,fs).moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3, fs) : \
               space == "log"     ? RGB.ACEScct_r(UV=3,fulls=fs).          moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3, fs) : \
                                    RGB

        } else if (isRGBo) {

               moncurve_r(t_gam[0], t_gam[1], false, tv_out, 3, fs)
        } }

    if (!isRGBo && isSpace || isRGBi && isFrmt) {

        R = isSpace || isGamma ? R.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && tv_in, false, 1, fs) : R
        G = isSpace || isGamma ? G.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && tv_in, false, 1, fs) : G
        B = isSpace || isGamma ? B.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && tv_in, false, 1, fs) : B

        if (o_fmt[0]=="YcCbcCrc") {

            YCbCr = RGB_to_YcCbcCrc( R, G, B, cs_out, coef_o, !(isSpace || !tv_in), tv_out, fs)

            Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]

        } else if (o_fmt[0]=="YCgCo"){



        } else if (o_fmt[0]=="YCgCor"){



        } else if (o_fmt[0]=="YUVr"){


        } else if (o_fmt[0]=="ICtCp"){



        } else if (o_fmt[0]=="YCbCr"){

            scale_y   = !(isSpace || !tv_in) && (isScale || !tv_out) ? ( 255 / 219.) : (isSpace || !tv_in) && !(isScale || !tv_out) ? ( 219 / 255.) : 1.0
            scale_uv  = !(isSpace || !tv_in) && (isScale || !tv_out) ? ( 255 / 112.) : (isSpace || !tv_in) && !(isScale || !tv_out) ? ( 112 / 255.) : 0.5

            Kr = 1. - coef_o[0]
            Kb = 1. - coef_o[2]

            m0 = scale_y  *   coef_o[0]       m1 = scale_y  *   coef_o[1]         m2 = scale_y  *   coef_o[2]
            m3 = scale_uv * (-coef_o[0] / Kb) m4 = scale_uv * (-coef_o[1] / Kb)   m5 = scale_uv
            m6 = scale_uv                     m7 = scale_uv * (-coef_o[1] / Kr)   m8 = scale_uv * (-coef_o[2] / Kr)

            rangeY_TV = scale_y==219/255. ? "ymin +" : \
                        scale_y==255/219. ? "ymin -" : ""
            rangeC_TV = bdpth < 32        ? "range_half +" : ""

            Y  = Expr(R, G, B, ex_dlut("x "+rangeY_TV+" "+string(m0)+" * y "+rangeY_TV+" "+string(m1)+" * + z "+rangeY_TV+" "+string(m2)+" * + ",              bdpth, fs), optSingleMode=true)
            Cb = Expr(R, G, B, ex_dlut("x "+rangeY_TV+" "+string(m3)+" * y "+rangeY_TV+" "+string(m4)+" * + z "+rangeY_TV+" "+string(m5)+" * + "+rangeC_TV+"", bdpth, fs), optSingleMode=true)
            Cr = Expr(R, G, B, ex_dlut("x "+rangeY_TV+" "+string(m6)+" * y "+rangeY_TV+" "+string(m7)+" * + z "+rangeY_TV+" "+string(m8)+" * + "+rangeC_TV+"", bdpth, fs), optSingleMode=true)

        }

        if (isScale) {

            Y    = space == "linear"  ? Y.moncurve_f(t_gam[0], t_gam[1], false, false, 1, fs)                                     : \
                   space == "sigmoid" ? Y.moncurve_f(t_gam[0], t_gam[1], false, false, 1, fs).ex_contrast(-1.15,0,191,false,1,fs) : \
                   space == "log"     ? Y.moncurve_f(t_gam[0], t_gam[1], false, false, 1, fs).ACEScct_f(UV=1,fulls=fs)            : \
                                        Y
            }

        point   = kernel=="Point" ? "+1.0" : ""
        cplaceH = (src_box ? ",sx=" : ",src_left=")+string(cplaceo[0]+cplacei[0]+src_left)+point
        cplaceV = (src_box ? ",sy=" :  ",src_top=")+string(cplaceo[1]+cplacei[1]+src_top)

        str  = ReplaceStr(ReplaceStr(resampler, "("+string(nw), "("+string(cnw)), ","+string(nh), ","+string(cnh))
        str  = (cnw==cow && cnh==coh) ? Format("PointResize({cnw},{cnh}") : str
        Cb   = Eval("Cb." + str + (src_nul ? "" : (cplaceH + cplaceV + src_wh)) + ")" + fmtcb)
        Cr   = Eval("Cr." + str + (src_nul ? "" : (cplaceH + cplaceV + src_wh)) + ")" + fmtcb)

        if (isScale) {
            Y    = nomoir ? Y.ex_blur((1. / rat) / 2., bifit=false) : Y
            Y    = Eval("Y." + resampler + src_c + (noring ? Ynr : ""))

            Y    = space == "linear"  ? Y.                                   moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1, fs) : \
                   space == "sigmoid" ? Y.ex_contrast(1.15,0,191,false,1,fs).moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1, fs) : \
                   space == "log"     ? Y.ACEScct_r(UV=1,fulls=fs).          moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1, fs) : \
                   tv_out             ? Y.SMPTE_legal(tv_out,3,1,fs)                                                              : \
                                        Y
            }

        CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt[1]+o_fmt[2])

        }

    }







####### FORMAT CONVERSION FUNCTIONS #######



# YCbCr to RGB function
function YUV_to_RGB (clip yuv, string "matrix", bool "tv_range_in", bool "tv_range_out", string "kernel", float "b", float "c", float "p", string "cplace", bool "UVrecon", bool "fulls") {

    matrix     = Default (matrix, "709")
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, !(matrix=="JPEG" || matrix=="JPG"))
    tv_out     = Default (tv_range_out, false)
    cplace     = Default (cplace, "")
    recon      = Default (UVrecon, false)
    b          = Default (b, 0.0)
    c          = Default (c, 0.75)               # Precise Bicubic
    p          = Default (p, 0.25)
    fs         = Default (fulls, false)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    Assert(isRGB(yuv)==false, "Only YUV format supported.")

    bdpth    = BitsPerComponent(yuv)
    p_type   = Format_fuzzy_search(yuv, PixelType(yuv), bdpth)
    matrix   = Matrix_fuzzy_search (matrix)
    coef     = Matrix_coef(matrix)
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

    cplace     = chroma_placement(yuv, w, h, matrix, "YUV"+p_type[1], cplace)

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
        U       = ex_makeadddiff(Unew, Removegrain(Unew, 19), Uu.BicubicResize(w, h, b=-0.5, c=0.25), fulls=fs)
        V       = ex_makeadddiff(Vnew, Removegrain(Vnew, 19), Vu.BicubicResize(w, h, b=-0.5, c=0.25), fulls=fs)

    } else {

        U   = p_type4 ? Uor : Eval("Uor." + resampler)
        V   = p_type4 ? Vor : Eval("Vor." + resampler)

        }


    if (matrix=="Rec2020CL" || matrix=="DCI-P3" || matrix=="Display-P3") {

        RGB = YcCbcCrc_to_RGB( Y, U, V, matrix, coef, tv_in, tv_out, fs)

        R = RGB[0]  G = RGB[1]  B = RGB[2]

    } else {

        scale_y   = tv_in ? (255 / 219.) : 1.0
        scale_uv  = tv_in ? (255 / 112.) : 2.0

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y     m1 = 0.0                                   m2 = scale_uv * Kr
        m3 = scale_y     m4 = scale_uv * ( -Kb * coef[2] / coef[1]) m5 = scale_uv * ( -Kr * coef[0] / coef[1])
        m6 = scale_y     m7 = scale_uv * Kb                         m8 = 0.0

        rangeY   = tv_in      ? "ymin - "                          : ""
        range_TV = tv_out     ? "ymax ymin - range_max / * ymin +" : ""
        UVf      = bdpth < 32 ? "range_half - " : ""

        R = Expr(Y,    V, ex_dlut( "x "+rangeY+" "+string(m0)+" *                            y "+UVf + string(m2)+" * + "+range_TV+"", bdpth, fs), optSingleMode=false)
        G = Expr(Y, U, V, ex_dlut( "x "+rangeY+" "+string(m3)+" * y "+UVf + string(m4)+" * + z "+UVf + string(m5)+" * + "+range_TV+"", bdpth, fs), optSingleMode=true)
        B = Expr(Y, U,    ex_dlut( "x "+rangeY+" "+string(m6)+" * y "+UVf + string(m7)+" * +                            "+range_TV+"", bdpth, fs), optSingleMode=false)

    }

    CombinePlanes(R, G, B, planes="RGB") }



# RGB to YCbCr function
function RGB_to_YUV (clip rgb, string "matrix", bool "tv_range_in", bool "tv_range_out", string "pixel_type", string "kernel", float "b", float "c", float "p", string "cplace", bool "fulls") {

    matrix     = Default (matrix, "sRGB")
    p_type     = Default (pixel_type, "420")     # target YUV pixel_type
    kernel     = Default (kernel, "Bicubic")
    tv_in      = Default (tv_range_in, false)
    tv_out     = Default (tv_range_out, true)
    cplace     = Default (cplace, "")
    b          = Default (b, -0.5)
    c          = Default (c, 0.25)               # Didée's Bicubic
    p          = Default (p, 0.25)
    fs         = Default (fulls, false)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    Assert(isRGB(rgb)==true && IsPlanar(rgb)==true, "Only Planar RGB format supported.")

    bdpth    = BitsPerComponent(rgb)
    p_type   = Format_fuzzy_search (rgb, p_type, bdpth)
    matrix   = Matrix_fuzzy_search (matrix)
    coef     = Matrix_coef(matrix)
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
    cplace     = chroma_placement(rgb, nw, nh, matrix, "YUV"+p_type[1], cplace)

     p_type1             ? Assert(bdpth == 8, "Unsupported Pixel Type: HBD YUV411") : nop()
                           Assert(!p_type10,  "Unsupported Pixel Type: YUV410")

                           Assert(h%2==0,"Height is not mod2." )
    !p_type1 || !p_type4 ? Assert(w%2==0, "Width is not mod2." )                    : nop()
     p_type1             ? Assert(w%4==0, "Width is not mod4." )                    : nop()


    Rx = ExtractR(rgb)
    Gx = ExtractG(rgb)
    Bx = ExtractB(rgb)


    if (matrix=="Rec2020CL" || matrix=="DCI-P3" || matrix=="Display-P3") {

        YCbCr = RGB_to_YcCbcCrc( Rx, Gx, Bx, matrix, coef, tv_in, tv_out, fs)

        Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]

    } else {

        scale_y   = !tv_in && tv_out ? ( 219 / 255.) : 1.0
        scale_uv  = !tv_in && tv_out ? ( 112 / 255.) : 0.5

        Kr = 1. - coef[0]
        Kb = 1. - coef[2]

        m0 = scale_y  *   coef[0]       m1 = scale_y  *   coef[1]         m2 = scale_y  *   coef[2]
        m3 = scale_uv * (-coef[0] / Kb) m4 = scale_uv * (-coef[1] / Kb)   m5 = scale_uv
        m6 = scale_uv                   m7 = scale_uv * (-coef[1] / Kr)   m8 = scale_uv * (-coef[2] / Kr)

        UVf       =  bdpth < 32      ? "" : "range_half -"
        rangeY_TV =  tv_out ?  tv_in ? "" : "ymin +" : tv_in ? "ymin - range_max ymax ymin - / *"    : ""
        rangeC_TV = !tv_out && tv_in ? "range_half - range_max cmax cmin - / * range_half + "+UVf+"" : UVf

        Y  = Expr(Rx, Gx, Bx, ex_dlut("           x "+string(m0)+" *   y "+string(m1)+" * + z "+string(m2)+" * + "+rangeY_TV+"", bdpth, fs), optSingleMode=true)
        Cb = Expr(Rx, Gx, Bx, ex_dlut("range_half x "+string(m3)+" * + y "+string(m4)+" * + z "+string(m5)+" * + "+rangeC_TV+"", bdpth, fs), optSingleMode=true)
        Cr = Expr(Rx, Gx, Bx, ex_dlut("range_half x "+string(m6)+" * + y "+string(m7)+" * + z "+string(m8)+" * + "+rangeC_TV+"", bdpth, fs), optSingleMode=true)

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

    CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+p_type[1]) }


# RGB to YcCbcCrc function (for Rec.2020CL)
function RGB_to_YcCbcCrc (clip Rx, clip Gx, clip Bx, string matrix, float_array coef, bool tv_in, bool tv_out, bool fulls) {

    bi        = BitsPerComponent(Rx)
    UVf       = bi < 32 ? "range_half +" : ""
    rangeC_PC = tv_in   ? "range_half - range_max cmax cmin - / * range_half + " : ""
    rangeC_TV = tv_out  ? "range_half + cmax cmin - range_max / * cmin + "       : UVf

    s_gam = moncurve_coef(matrix)
    a  = 1.0 + s_gam[1]
    b  = 1.0 / s_gam[0]

    Pb = 1 /  (2. * (a*(1.0 - pow(coef[2], b))))
    Pr = 1 /  (2. * (a*(1.0 - pow(coef[0], b))))
    Nb = 1 / (-2. * (a*(1.0 - pow(coef[0] + coef[1], b)) - 1.0))
    Nr = 1 / (-2. * (a*(1.0 - pow(coef[1] + coef[2], b)) - 1.0))

    Rln   = moncurve_f(Rx, s_gam[0], s_gam[1], tv_in, false, 1, fulls)
    Gln   = moncurve_f(Gx, s_gam[0], s_gam[1], tv_in, false, 1, fulls)
    Bln   = moncurve_f(Bx, s_gam[0], s_gam[1], tv_in, false, 1, fulls)
    Y     = Expr(Rln, Gln, Bln, "x "+string(coef[0])+" * y "+string(coef[1])+" * + z "+string(coef[2])+" * + ")
    Yx    = moncurve_r(Y,  s_gam[0], s_gam[1], false, false, 1, fulls)

    Cb    = Expr(Bx,  Yx, ex_dlut(Format("x "+rangeC_PC+" y - A@ 0 <= A {Nb} * A {Pb} * ? "+rangeC_TV+" "), bi, fulls))
    Cr    = Expr(Rx,  Yx, ex_dlut(Format("x "+rangeC_PC+" y - A@ 0 <= A {Nr} * A {Pr} * ? "+rangeC_TV+" "), bi, fulls))
    Y     = !tv_out ? Yx : moncurve_r(Y,  s_gam[0], s_gam[1], false, true, 1, fulls)

    [Y, Cb, Cr] }


# YcCbcCrc to RGB function (for Rec.2020CL)
function YcCbcCrc_to_RGB (clip Y, clip Cb, clip Cr, string matrix, float_array coef, bool tv_in, bool tv_out, bool fulls) {

    bi        = BitsPerComponent(Y)
    bdpth     = bi < 32
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

    Y  = moncurve_f(Y,  s_gam[0], s_gam[1], tv_in, false, 1, fulls)

    Bx = Expr(Cb, Y, ex_dlut(Format("x "+rangeC_PC+" A@ 0 <= A {Nb} * y "+UVf+" B@ + A {Pb} * B + ? "+UVf2+""), bi, fulls))
    Rx = Expr(Cr, Y, ex_dlut(Format("x "+rangeC_PC+" A@ 0 <= A {Nr} * y "+UVf+" B@ + A {Pr} * B + ? "+UVf2+""), bi, fulls))

    Gx = Expr(Y, Bx, Rx, "x "+string(coef[2])+" y * - "+string(coef[0])+" z * - "+string(coef[1])+" / ", optSingleMode=true)

    B = moncurve_r(Bx,  s_gam[0], s_gam[1], false, tv_out, 1, fulls)
    R = moncurve_r(Rx,  s_gam[0], s_gam[1], false, tv_out, 1, fulls)
    G = moncurve_r(Gx,  s_gam[0], s_gam[1], false, tv_out, 1, fulls)

    [R, G, B] }




# YCgCo, YCgCoR and YUVr compress better than plain YUV. YCgCo variants a tiny bit over YUVr, and YUVr and YCgCoR being losslessly reversible (RCT) with RGB
# These formats are ColorSpace and Chroma Subsampling independent, as well as signal range (full or legal)

# RGB to YCgCo function (this is correct)
function RGB_to_YCgCo (clip R, clip G, clip B, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(R)
    fs = Default (fulls, false)

    Y  = Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ",             bi, fs), optSingleMode=true)
    Cg = Expr(R, G, B, ex_dlut("y 0.5  * x z + 0.25 * - range_half +", bi, fs), optSingleMode=true)
    Co = Expr(R,    B, ex_dlut("x 0.5  * y 0.5  *     - range_half +", bi, fs), optSingleMode=false)

    [Y, Cg, Co] }


# YCgCo to RGB function
function YCgCo_to_RGB (clip Y, clip Cg, clip Co, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    R = Expr(Y, Cg, Co, ex_dlut("x y range_half - - z range_half - + ", bi, fs), optSingleMode=true)
    G = Expr(Y, Cg,     ex_dlut("x y range_half - +",                   bi, fs), optSingleMode=false)
    B = Expr(Y, Cg, Co, ex_dlut("x y range_half - - z range_half - - ", bi, fs), optSingleMode=true)

    [R, G, B] }


# RGB to YCgCo RCT function
function RGB_to_YCgCoR (clip R, clip G, clip B, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(R)
    fs = Default (fulls, false)

    Co = Expr(R,      B, ex_dlut("x 0.5  * y 0.5  * - range_half +",                bi, fs), optSingleMode=false)
    Cg = Expr(Co, G,  B, ex_dlut("y z x range_half - 0.5 * + - 0.5 * range_half +", bi, fs), optSingleMode=false)
    Y  = Expr(Co, Cg, B, ex_dlut("z x range_half - 0.5 * + y range_half - +",       bi, fs), optSingleMode=false)

    [Y, Cg, Co] }


#  YCgCo RCT to RGB function
function YCgCoR_to_RGB (clip Y, clip Cg, clip Co, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    G = Expr(Y, Cg,     ex_dlut("y range_half - Y@ 2 * x Y - +",             bi, fs), optSingleMode=false)
    B = Expr(Y, Cg, Co, ex_dlut("x y range_half - - z range_half - 0.5 * -", bi, fs), optSingleMode=true)
    R = Expr(Co, B,     ex_dlut("y x range_half - 2 * +",                    bi, fs), optSingleMode=false)

    [R, G, B] }


# RGB to YCbCr RCT function (Reversible Color Transform, from JPEG 2000, similar to YCgCo)
function RGB_to_YUVr (clip R, clip G, clip B, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(R)
    fs = Default (fulls, false)

    Y  = Expr(R, G, B, ex_dlut("x z + 0.25 * y 0.5  * + ", bi, fs), optSingleMode=true)
    Cb = Expr(   G, B, ex_dlut("y x - range_half +",       bi, fs), optSingleMode=false)
    Cr = Expr(R, G,    ex_dlut("x y - range_half +",       bi, fs), optSingleMode=false)

    [Y, Cb, Cr ] }

# YCbCr RCT to RGB function (Reversible Color Transform, from JPEG 2000, similar to YCgCo)
function YUVr_to_RGB (clip Y, clip Cb, clip Cr, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    G = Expr(Y, Cb, Cr, ex_dlut("x y z + 0.25 * - range_half 0.5 * +", bi, fs), optSingleMode=true)
    R = Expr(G,     Cr, ex_dlut("x y + range_half -",                  bi, fs), optSingleMode=false)
    B = Expr(G, Cb,     ex_dlut("x y + range_half -",                  bi, fs), optSingleMode=false)

    [R, G, B] }


# XYZ to YDzDx (applied on SMPTE ST 2084 gamma space)
function XYZ_to_YDzDx (clip X, clip Y, clip Z, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    cf1   = 2763/2800.
    cf2   = 2741/2763.

    Dz = Expr(   Y, Z, ex_dlut(Format("{cf1} y range_half + * x  - "), bi, fs), optSingleMode=false)
    Dx = Expr(X, Y,    ex_dlut(Format("x range_half +  {cf2} y * - "), bi, fs), optSingleMode=false)

    [Y, Dz, Dx ] }


# YDzDx to XYZ
function YDzDx_to_XYZ (clip Y, clip Dz, clip Dx, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    cf1   = 2800/2763.
    cf2   = 2763/2741.

    Z = Expr(Dz, Y, ex_dlut(Format("x range_half - y {cf1} * + "), bi, fs), optSingleMode=false)
    X = Expr(Dx, Y, ex_dlut(Format("x range_half - y {cf2} * + "), bi, fs), optSingleMode=false)

    [X, Y, Z] }


# XYZ to CIE Luv -D65 based- (process in linear space) (32-bit float recommended)
function XYZ_to_Luv (clip X, clip Y, clip Z, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    Yr    = 1 / 0.329016  # its reciprocal
    ep    = 216 / 24389.
    kappa = 24389 / 27.

    nrm = ex_bs(255, 8, bi, fulls=fs)
    mat = RGB_to_XYZ  (L, "sRGB", list=true)
    mat = MatrixDot([nrm, nrm, nrm], mat)

    rW    = [95.0449218275099, 100., 108.8916648430471]

    detu  = (4 * rW[0] / (rW[0] + 15 * rW[1] + 3 * rW[2]))
    detv  = (9 * rW[1] / (rW[0] + 15 * rW[1] + 3 * rW[2]))

    L = Expr(Y,                  Format("x {ep} > x 0.333333333 ^ 116 * 16 - x {kappa} * ? "),                 optSingleMode=false)
    u = Expr(X, Y, Z, L, ex_dlut(Format("x 4 * x y 15 * + z 3 * + / {detu} - a 13 * * range_half +"), bi, fs), optSingleMode=true)
    v = Expr(X, Y, Z, L, ex_dlut(Format("x 9 * x y 15 * + z 3 * + / {detv} - a 13 * * range_half +"), bi, fs), optSingleMode=true)

    [L, u, v ] }

#http://www.brucelindbloom.com/index.html?Eqn_Luv_to_XYZ.html
# CIE Luv to XYZ (can remove range_half entries if processed in 32-bit)
function Luv_to_XYZ (clip L, clip u, clip v, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(L)
    fs = Default (fulls, false)

    ep    = 216 / 24389.
    kappa = 24389 / 27.
    exk   = ep * kappa
    D65N  = [0.312713, 0.329016, 0.358271]
    Wr    = [95.0449218275099, 100., 108.8916648430471]

    mat = RGB_to_XYZ  (L, "sRGB", list=true)
    mat = MatrixDot([0.312713, 0.329016, 0.358271], mat)

    detu  = (4 * D65N[0] / (D65N[0] + 15 * D65N[1] + 3 * D65N[2]))
    detv  = (9 * D65N[1] / (D65N[0] + 15 * D65N[1] + 3 * D65N[2]))

    Y = Expr(      L,       Format("x {exk} > x 16 + 116 / 3 ^ x {kappa} / ?"),                                 optSingleMode=false)
    X = Expr(   Y, L, u, v, Format("y 39 * y 13 * A@ {detv} * a range_half - + / 5 - x * x 5 * +
                                    y 52 * A {detu} * z range_half - + / 1 - 0.333333333 * 0.333333333 + / "),  optSingleMode=true)
    Z = Expr(X, Y, L, u,    Format("z 52 * z 13 * {detu} * a range_half - + / 1 - 0.333333333 * x * y 5 * - "), optSingleMode=true)

    [X, Y, Z] }


# CIE Luv to CIE DuDv (HDR version of CIE Luv)
function Luv_to_Duv (clip L, clip u, clip v, bool fulls) {

    bi = BitsPerComponent(L)
    fs = Default (fulls, false)

    c = 1 / 0.62
    Du = Expr(u, Format("x {c} *"), optSingleMode=false)
    Dv = Expr(v, Format("x {c} *"), optSingleMode=false)

    [L, Du, Dv ] }

# CIE DuDv to CIE Luv
function Duv_to_Luv (clip Y, clip Du, clip Dv, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    u = Expr(Du, "x 0.62 *", optSingleMode=false)
    v = Expr(Dv, "x 0.62 *", optSingleMode=false)

    [Y, u, v] }


# XYZ to CIE Lab -D65 based- (process in linear space) (32-bit float recommended)
function XYZ_to_Lab (clip X, clip Y, clip Z, bool tv_in, bool tv_out, bool fulls) {

    bi = BitsPerComponent(Y)
    fs = Default (fulls, false)

    Yr    = 1 / 0.329016  # its reciprocal
    ep    = 216 / 24389.
    kappa = 24389 / 27.
    rW    = [95.0449218275099, 100., 108.8916648430471]

    L = Expr(Y,               Format("x {ep} > x 0.333333333 ^ 116 * 16 - x {kappa} * ? 0.01 *"),                                                     optSingleMode=false)
    a = Expr(X, Y,    ex_dlut(Format("x "+string(rW[0])+" * 0.333333333 ^ y "+string(rW[1])+" * 0.333333333 ^ - 500 * 0.01 * range_half +"), bi, fs), optSingleMode=true)
    b = Expr(   Y, Z, ex_dlut(Format("x "+string(rW[1])+" * 0.333333333 ^ y "+string(rW[2])+" * 0.333333333 ^ - 200 * 0.01 * range_half +"), bi, fs), optSingleMode=true)

    [L, a, b ] }





####### FUNCTION TRANSFORMS #######


# OETF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_f (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out", int "UV", bool "fulls") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()

    gamma  = Default(gamma, 1/0.45)    # gamma
    alpha  = Default(alpha,   0.0 )    # extension in x coords of the linear part
    tv_in  = Default(tv_range_in, !rgb)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 ) # Chroma planes TV<->PC conversion or not
    fs     = Default(fulls, false)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    beta   = (( gamma - 1.0) / alpha) * pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = alpha / ( gamma - 1.0)
    aplus  = 1 / (1. + alpha)
    eps    = bi != 32 && bi != 8 ? "0.001 -" : ""

    str    = alpha > 0.0 ? Format("range_min "+rangePC+" max A@ {phi} > A {alpha} + {aplus} * {gamma} ^ A {beta} * ? "+rangeTV+"") : \
                           Format("range_min "+rangePC+" "+eps+" max {gamma} ^ "+rangeTV+"")

    str    =        ex_dlut( str, bi, fs)
    cstr   = !rgb ? ex_dlut(tv_in && !tv_out ? "x cmin - range_max cmax cmin - / *" : \
                           !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin +" : "", bi, fs) : str

    gamma <= 1.0 ? last                                                                      : \
    isy          ? Expr(str                                                                ) : \
    UV == 1      ? Expr(str, ""                                                            ) : \
                   Expr(str, ex_UVexpr(cstr, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }


# EOTF. Monitor Curve Functions: https://github.com/ampas/aces-dev
function moncurve_r (clip c, float "gamma", float "alpha", bool "tv_range_in", bool "tv_range_out", int "UV", bool "fulls") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()

    gamma  = Default(gamma, 1/0.45)    # gamma
    alpha  = Default(alpha,   0.0 )    # extension in x coords of the linear part
    tv_in  = Default(tv_range_in, !rgb)
    tv_out = Default(tv_range_out, tv_in)
    UV     = Default(UV, rgb ? 3 : 1 ) # Chroma planes TV<->PC conversion or not
    fs     = Default(fulls, false)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    beta   = pow( alpha * gamma / ( ( gamma - 1.0) * ( 1.0 + alpha)), gamma)
    phi    = pow( ( gamma - 1.0) / alpha, gamma - 1.0) * pow( ( 1.0 + alpha) / gamma, gamma)
    igam   = 1. / gamma
    aplus  = 1. + alpha

    str    = alpha > 0.0 ? Format("range_min "+rangePC+" max A@ {beta} > {aplus} A {igam} ^ * {alpha} - A {phi} * ? "+rangeTV+"") : \
                           Format("range_min "+rangePC+" max {igam} ^ "+rangeTV+"")

    str    =        ex_dlut( str, bi, fs)
    cstr   = !rgb ? ex_dlut(tv_in && !tv_out ? "x cmin - range_max cmax cmin - / *" : \
                           !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin +" : "", bi, fs) : str

    gamma <= 1.0 ? last                                                                      : \
    isy          ? Expr(str                                                                ) : \
    UV == 1      ? Expr(str, ""                                                            ) : \
                   Expr(str, ex_UVexpr(cstr, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }


# Linear to ACEScct: https://github.com/ampas/aces-dev
function ACEScct_f (clip c, bool "tv_range_in", bool "tv_range_out", int "UV", bool "fulls") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()

    tv_in  = Default(tv_range_in,  !rgb)
    tv_out = Default(tv_range_out,  tv_in)
    fs     = Default(fulls, rgb)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    X_BRK  = 0.0078125
    coeffA = 10.5402377416545
    coeffB = 0.0729055341958355
    lb     = 1. / log(2)
    coeffC = 1 / 17.52

    str    = Format(""+rangePC+" A@ {X_BRK} <= A {coeffA} * {coeffB} + A log {lb} * 9.72 + {coeffC} * ? "+rangeTV+"")

    str    =        ex_dlut( str, bi, fs)
    cstr   = !rgb ? ex_dlut(tv_in && !tv_out ? "x cmin - range_max cmax cmin - / *" : \
                           !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin +" : "", bi, fs) : str

    isy     ? Expr(str                                                                ) : \
    UV == 1 ? Expr(str, ""                                                            ) : \
              Expr(str, ex_UVexpr(cstr, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }


# ACEScct to Linear: https://github.com/ampas/aces-dev
function ACEScct_r (clip c, bool "tv_range_in", bool "tv_range_out", int "UV", bool "fulls") {

    c
    rgb = IsRGB()
    isy = isy()
    bi  = BitsPerComponent()

    tv_in  = Default(tv_range_in,  !rgb)
    tv_out = Default(tv_range_out,  tv_in)
    fs     = Default(fulls, rgb)

    rangePC = tv_in  ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV = tv_out ? "ymax ymin - * ymin +"   : "  range_max *"

    Y_BRK  = 0.155251141552511
    coeffA = 1 / 10.5402377416545
    coeffB = 0.0729055341958355

    str    = Format(""+rangePC+" A@ {Y_BRK} > 2 A 17.52 * 9.72 - ^ A {coeffB} - {coeffA} * ? "+rangeTV+"")

    str    =        ex_dlut( str, bi, fs)
    cstr   = !rgb ? ex_dlut(tv_in && !tv_out ? "x cmin - range_max cmax cmin - / *" : \
                           !tv_in &&  tv_out ? "x cmax cmin - range_max / * cmin +" : "", bi, fs) : str

    isy     ? Expr(str                                                                ) : \
    UV == 1 ? Expr(str, ""                                                            ) : \
              Expr(str, ex_UVexpr(cstr, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi)) }


function SMPTE_legal (clip a, bool "forward", int "Y", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    fw  = Default(forward, true)    # forward converts to SMPTE legal, otherwise converts to Full Range.
    Y   = Default(Y,            3 )
    UV  = Default(UV, isy ? 1 : 3 )
    fs  = Default(fulls, false)

    str  = fw ? "x ymax ymin - range_max / * ymin +"  : \
                "x ymin - range_max ymax ymin - / *"

    cstr = fw ? "x cmax cmin - range_max / * cmin +"  : \
                "x cmin - range_max cmax cmin - / *"

    str  =        ex_dlut( ex_Yexpr(  str,  Y, bi, rgb, fs), bi, fs)
    cstr = !rgb ? ex_dlut( ex_UVexpr(cstr, UV, bi, rgb, fs), bi, fs) : str

    isy     ? Expr(a, str                                    ) : \
    UV == 1 ? Expr(a, str, ""                                ) : \
              Expr(a, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }






####### DATA RETRIEVAL FUNCTIONS #######



function Format_fuzzy_search (clip c, string format, int bits) {


    rgb  = isRGB(c)
    Up   = rgb || isy(c) ? c : ExtractU(c)
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
\   : (FindStr(format, "12"     )>0) ? "420"
\   : (FindStr(format,"444"     )>0) ? "444"
\   : (FindStr(format, "24"     )>0) ? "444"
\   : (FindStr(format,"422"     )>0) ? "422"
\   : (FindStr(format, "16"     )>0) ? "422"
\   : (FindStr(format,"411"     )>0) ? "411"
\   : (FindStr(format,"410"     )>0) ? "410"
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


    format  = ReplaceStr(format, jab, "")

    fmt =
\     (FindStr(format,"RGB"     )>0) ? "RGB"
\   : (FindStr(format,"rgb"     )>0) ? "RGB"
\   : (        format=="JPEG"      ) ? "YCbCr"
\   : (        format=="JPG"       ) ? "YCbCr"
\   : (        format=="YUVJ"      ) ? "YCbCr"
\   : (        format=="YCbCr"     ) ? "YCbCr"
\   : (        format=="YUV"       ) ? "YCbCr"
\   : (FindStr(format, "YV"     )>0) ? "YCbCr"
\   : (FindStr(format, "DV"     )>0) ? "YCbCr"
\   : (        format=="YCC"       ) ? "YCbCr"
\   : (        format=="YPbPr"     ) ? "YCbCr"
\   : (        format=="YUVr"      ) ? "YUVr"
\   : (        format=="sYUV"      ) ? "sYUV"
\   : (FindStr(format, "Sharp"  )>0) ? "sYUV"
\   : (        format=="YcCbcCr"   ) ? "YcCbcCrc"
\   : (FindStr(format, "YcCbc"  )>0) ? "YcCbcCrc"
\   : (        format=="YCgCo"     ) ? "YCgCo"
\   : (        format=="YCgCoR"    ) ? "YCgCoR"
\   : (        format=="YCoCg"     ) ? "YCgCo"
\   : (        format=="YCoCgR"    ) ? "YCgCoR"
\   : (        format=="ICtCp"     ) ? "ICtCp"
\   : (        format=="IPT"       ) ? "ICtCp"
\   : (        format=="YDzDx"     ) ? "YDzDx"
\   : (        format=="Yxy"       ) ? "Yxy"
\   : (        format=="xyY"       ) ? "Yxy"
\   : (        format=="XYZ"       ) ? "XYZ"
\   : (        format=="Jzazbz"    ) ? "Jzazbz"
\   : (        format=="JzCzhz"    ) ? "JzCzhz"
\   : (        format=="HSV"       ) ? "HSV"
\   : (        format=="Duv"       ) ? "Duv"
\   : (        format=="CIELuv"    ) ? "CIELuv"
\   : (FindStr(format, "luv"  )>0  ) ? "CIELuv"
\   : (FindStr(format, "lab"  )>0  ) ? "CIELab"
\   : (        format=="CIELab"    ) ? "CIELab"
\   : (        format=="HunterLab" ) ? "HunterLab"
\   : (        format=="Hunter"    ) ? "HunterLab"
\   :                   rgb          ? "RGB" : "YCbCr"

    bdpth = bits < 32         ? "P" + string(bits) : "PS"

    [fmt, jab, bdpth] }




function bicubic_coeffs (string kernel) {

    rb  = 12./(19.+9.*sqrt(2.))      # 0.378216
    rc  = 113./(58.+216.*sqrt(2.))   # 0.310892
    rsb = 6./(13.+7.*sqrt(2.))       # 0.262015
    rsc = 7./(2.+12.*sqrt(2.))       # 0.368993

    # From smoother to sharper
    coeffs =
\     (kernel == "Didee"             ) ? [-0.5,0.25]
\
\   : (kernel == "SoftCubic100"      ) ? [1.0,0.0]
\   : (kernel == "SoftCubic75"       ) ? [0.75,0.25]
\   : (kernel == "Hermite"           ) ? [0.0,0.0]
\   : (kernel == "Robidoux"          ) ? [rb,rc]
\   : (kernel == "Mitchell-Netravali") ? [1/3.,1/3.]
\   : (kernel == "Robidoux Sharp"    ) ? [rsb,rsc]
\   : (kernel == "SoftCubic50"       ) ? [0.5,0.5]
\   : (kernel == "Catmull-Rom"       ) ? [0.0,0.5]
\   : (kernel == "Precise Bicubic"   ) ? [0.0,0.75]
\   : (kernel == "Sharp"             ) ? [0.0,1.0]
\   : (kernel == "Hatch"             ) ? [0.0,-5.0]
\
\   : (kernel == "SoftCubic"         ) ? [0.75,0.25]
\   : (kernel == "Precise"           ) ? [0.0,0.75]
\   : (kernel == "catrom"            ) ? [0.0,0.5]
\   : (kernel == "Catmull"           ) ? [0.0,0.5]
\   : (kernel == "Mitchell"          ) ? [1/3.,1/3.]
\   : (kernel == "Mitchel"           ) ? [1/3.,1/3.]
\   : (kernel == "RobiSharp"         ) ? [rsb,rsc]
\   : (kernel == "Robi"              ) ? [rb,rc]
\   : (kernel == "RobidouxSharp"     ) ? [rsb,rsc]
\   : (kernel == "B-Spline"          ) ? [1.0,0.0]
\   : (kernel == "BSpline"           ) ? [1.0,0.0]
\   : (kernel == "BCSpline"          ) ? [0.5,0.5]
\   : (kernel == "BC-Spline"         ) ? [0.5,0.5]
\   : (kernel == "CSpline"           ) ? [0.0,1.0]
\   : (kernel == "C-Spline"          ) ? [0.0,1.0]
\   : (kernel == "Didée"             ) ? [-0.5,0.25]
\   : (kernel == "Dide"              ) ? [-0.5,0.25] : [-1,-1]

    coeffs }


# JPEGs uses Rec.601 primaries, PC Levels, MPEG1 chroma placement, and can be many formats; from RGB to 420, 422 being to spec, but also 440*, 444, 411, etc
#*YUV440 or YUVJ440 are for rotated versions of 422 (rotated JPEG)
# Photoshop saves as 420 up to level 6, 422 for above
function chroma_placement (clip a, int UVw, int UVh, string matrix, string format, string "cplace") {

    plane      = isRGB(a) || isy(a) ? a : ExtractU(a)
    rw         = width (plane) / float(UVw)      # source/target UV dimensions
    rh         = height(plane) / float(UVh)

                         # source chroma placement defaults
    dplace = FindStr(format,"RGB")>0      ? "center"   : \
             format == "YUV444"           ? "center"   : \
             format == "YUV420"           ? "MPEG2"    : \
             format == "YUV422"           ? "MPEG1"    : \
             format == "YUV411"           ? "MPEG1"    : \
             FindStr(matrix,"2020")>0     ? "top_left" : \
             FindStr(matrix,"2100")>0     ? "top_left" : \
             FindStr(format,"YcCbcCrc")>0 ? "top_left" : \
             FindStr(format,"ICtCp")>0    ? "top_left" : \
             format == "YUV410"           ? "DV"       : "MPEG2"

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
\   : (FindStr(matrix,"ACES2")>0) ? "ACES2065"
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
    pr = Select (mat_i,  [0.670,  0.330],  [0.640, 0.330],  [0.630,  0.340],  [0.630,  0.340],  [0.640,  0.330],  [0.708,  0.292],  [0.640,  0.330],  [0.7347, 0.2653],  [0.680,  0.320],  [0.680,  0.320],  [0.713,   0.293],  [0.7347,  0.2653])
    pg = Select (mat_i,  [0.210,  0.710],  [0.300, 0.600],  [0.310,  0.595],  [0.310,  0.595],  [0.290,  0.600],  [0.170,  0.797],  [0.210,  0.710],  [0.1152, 0.8264],  [0.265,  0.690],  [0.265,  0.690],  [0.165,   0.830],  [0.0000,  1.0000])
    pb = Select (mat_i,  [0.140,  0.080],  [0.150, 0.060],  [0.155,  0.070],  [0.155,  0.070],  [0.150,  0.060],  [0.131,  0.046],  [0.150,  0.060],  [0.1566, 0.0177],  [0.150,  0.060],  [0.150,  0.060],  [0.128,   0.044],  [0.0001, -0.0770])
    pw = Select (mat_w,  [0.310,  0.316],  [0.312713, 0.329016],                                                                                      [0.3457, 0.3585],                    [0.314,  0.351],  [0.32168,0.33767]                   )
    wp = Select (mat_wp, [0.310,  0.316],  [0.312713, 0.329016],                                                                                      [0.3457, 0.3585],                    [0.314,  0.351],  [0.32168,0.33767]                   )
    Kv = Select (mat_wp,  6779.653      ,   6504.13            ,                                                                                       5000.569       ,                     6304.573      ,   6000.211                           )

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
\   : (matrix == "linear"     ) ? 7
\   : (matrix == "240M"       ) ? 2
\   : (matrix == "470BG"      ) ? 3
\   : Assert (false, "Unsupported Color Space.")


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

    #                                                SMPTE-C    / BT-2020           Y’PbPr 601              PAL/SECAM                      Rec.709  AdobeRGB  DCI-P3  AP1/AP0  Rec.709
    #                       sRGB                     SMPTE 170M / BT-2020           SMPTE 240M              BT-470BG                       BT-1886  AdobeRGB  DCI-P3  ACES     BT-1886a
    t_gamma = Select(t_num, 2.40                   , 1/0.45                       , 1/0.45                , 2.80                         , 2.40   , 563/256., 2.60  , 1.0      , 2.60   )
    t_alpha = Select(t_num, 0.055                  , 0.099296826809442940347282759, 0.1115                , 0.099296826809442940347282759, 0      , 0       , 0     , 0        , 0      )
    t_beta  = Select(t_num, 0.00303993463977843    , 0.018053968510807807335869592, 0.02280681818181818182, 0.00410749063249639977       , 0      , 0       , 0     , 0        , 0.35/pow(0.35, 3.0-2.6))
    t_k0    = Select(t_num, 0.03928571428571428571 , 0.081242858298635133011413164, 0.09122727272727272727, 0.05516490378302385575       , 0      , 0       , 0     , 0        , 0.35   )
    t_phi   = Select(t_num, 12.92321018078786109464, 4.5                          , 4.0                   , 13.43031761206876179575      , 4.5    , 0       , 0     , 0        , pow(0.35, 3.0-2.6) )

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
                                        [ 0.71650063991546630, 0.258728206157684300, 0.00000000000000000,  \
                                          0.10102055221796036, 0.724682152271270800, 0.05121181160211563,  \
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
                    cspace == "Rec601" || cspace == "240M"                                                  ?  \
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



# von Kries Chromatic Adaptation
function c_adaptation (clip c, string "source", string "target", bool "tv_range", bool "list", bool "fulls") {

    rgb    = IsRGB(c)

    src    = Default (source, "sRGB")
    tgt    = Default (target, "sRGB")
    range  = Default (tv_range, !rgb)
    list   = Default (list,    false)
    fs     = Default (fulls,   false)

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
    vk     = [same?1.:trans[0],   0.0000,        0.0000,  \
              0.0000,   same?1.:trans[1],        0.0000,  \
              0.0000,            0.0000,same?1.:trans[2]]

    CAM    = !same ? MatrixDot(CAT02, MatrixDot(vk, MatrixInvert(CAT02))) : vk

    if (!list) {

        c
        s_gam  = moncurve_coef(src)

        RGBpln = rgb ? IsPlanar() : false

        rgb ? RGBpln ? last : ConvertToPlanarRGB() : \
        YUV_to_RGB(c, src, tv_range_in=range, tv_range_out=false, kernel="Point", fulls=fs)

        moncurve_f(s_gam[0], s_gam[1], false, false, 1, fs)

        mata = RGB_to_XYZ (src, list=true)
        matb = XYZ_to_RGB (src, list=true)
        MatrixClip( MatrixDot(MatrixDot(mata, CAM), matb) )

        moncurve_r(s_gam[0], s_gam[1], false, false, 1, fs)

        rgb ? RGBpln ? last : MatchColorFormat(c) : \
        RGB_to_YUV( src, tv_range_in=false, tv_range_out=range, kernel="Point", pixel_type=PixelType(c), fulls=fs)
        same ? c : last

    } else { CAM } }





####### MATRIX FUNCTIONS #######


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


function DotClipA ( clip_array rgb, float_array vec) {

    # clip · 1x3
    Expr(rgb[0], \
         rgb[1], \
         rgb[2], "x "+string(vec[0])+" * y "+string(vec[1])+" * + z "+string(vec[2])+" * +", optSingleMode=true) }


function DotClip ( clip rgb, float_array vec) {

    # clip · 1x3
    Expr(ExtractR(rgb), \
         ExtractG(rgb), \
         ExtractB(rgb), "x "+string(vec[0])+" * y "+string(vec[1])+" * + z "+string(vec[2])+" * +", optSingleMode=true) }


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


# Arguments should be declared in the call for val_array to work (ie. ArrayAdd(a=a,b=b) ) unless you use AVS+ 3.7.1 test14
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
