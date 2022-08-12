###########################################################
###                                                      ##
###                                                      ##
###   Transforms Pack - Main v1.0 RC57  (12-08-2022)     ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182825    ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
### MAIN:                                                ##
###     Display_Referred                                 ##
###     MatchClip                                        ##
###     ConvertFormat                                    ##
### DATA RETRIEVAL:                                      ##
###     color_Fuzzy_Search                               ##
###     color_propGet                                    ##
###     format_Fuzzy_Search                              ##
###     bicubic_coeffs                                   ##
###     chroma_placement                                 ##
###     color_coef                                       ##
###     moncurve_coef                                    ##
### MATRIX HELPERS:                                      ##
###     ExtractClip                                      ##
###     MatrixClip                                       ##
###     DotClip                                          ##
###     DotClipA                                         ##
###     MatrixDot                                        ##
###     MatrixInvert                                     ##
###     MatrixTranspose                                  ##
###     Broadcast                                        ##
###     Cross                                            ##
###     Dot                                              ##
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
### chroma placement and chroma subsampling conversions among other features
### like chroma reconstruction, 'no ring' scaling, luma space scaling, and no-moirée scaling.
###
### ConvertFormat() replaces my old filter LinearResizer() (Dither Tools based)
### and is clearly inspired by cretindesalpes' fmtconv and avsresize's z_ConvertFormat().
### For a "no-fuss" high quality resizer you can use deep_resize() from ResizersPack.
###
###
### Dependencies: AviSynth+ 3.7.2+
###
### Main features (not available in other color management AVS+ solutions):
###     - About three times more scaling kernels to choose from
###     - Many more color model conversion functions
###     - Convert from any illuminant to any illuminant (ie. sRGB at D50 to NTSC at D93)
###     - Ratio resize (ie. 0.5 to halve size instead of absolute dimensions)
###     - Aliases and fuzzy search for any given string argument
###     - Preset support
###     - Scale space (ie. linear scaling, sigmoid scaling...)
###     - Filtering extras: noring, nomoiree, chroma reconstruction
###     - Show panel
###
###
####################################


### Notes about the JPEG format ###
###
### JPEGs (JPE, IJPG, JIF, etc) uses Rec.601 primaries*, PC Levels, MPEG1 (center) chroma placement, and can be many formats; from RGB to 420, 422 being to spec, but also 444, 411 or 440 (YUV440 or YUVJ440 are "rotated" versions of 422)
### *Photoshop automatically decodes JPEG as Rec.601 for JPEGs without an embedded profile at least up to version "Photoshop CC 2019"
### *Photoshop saves as 420 up to level 6, 444 for above (old versions as 422 for above level 6)
### *Photoshop quality levels vs JPEG qual (at default quantization tables)
###     level 12 -> quality 98
###     level 11 -> quality 97
###     level 10 -> quality 94 (Default for Photoshop)
### *Other High Quality nominal values for quality settings in JPEG-scale are 95 and 90
### *JPEG2000 (and sometimes JPEG) are encoded in PhotoYCC (aka PhotoCD)



###
### Display_Referred()
###
### Performance friendly viewing transform
### Note: If you are taking snapshots (ie. with AvsPmod), disable Display_Referred() so you don't burn your monitor view transform into the image
###
### Example:
###
###   display_referred(disp_ref="709",profile="MyDisplayProfile.Rec709.cube") # Define 'disp_ref' even if profile LUT is specified
###
function Display_Referred (clip clp, string "source", string "disp_ref", string "kernel", bool "gamut", bool "gamma", string "profile", bool "tv_range", string "LMS", float "b", float "c", float "p") {

    rgb        = isRGB(clp)
    propIDs    = color_propGet(clp)
    bi         =  propIDs[7]
    fs         = !propIDs[6]

    LUT        = Default (profile, Undefined()) # Display profile LUT (the path string of your monitor .cube 3D LUT, if calibrated)
    gamut      = Default (gamut, true)          # convert gamut
    gamma      = Default (gamma, true)          # convert gamma
    source     = Default (source, propIDs[2])   # Source Color Space
    disp_ref   = Default (disp_ref,Defined(LUT) ? "709" : "sRGB") # Display Referred Color Space: sRGB for typical uncalibrated monitor, 709 (with 1886 transfer) for calibrated monitors or SmartTVs
    kernel     = Default (kernel,  "Bicubic")
    tv         = Default (tv_range, !fs )
    LMS        = Default (LMS,    "CAT02B")
    b          = Default (b, 0.00)
    c          = Default (c, 0.75)              # Precise Bicubic
    p          = Default (p, 0.25)

    Assert(IsVersionOrGreater(3,7,2), "Display_Referred: Update AviSynth+ version")

    clp.ConvertBits(32, fulls=fs)

    src   = color_Fuzzy_Search (source)
    tgt   = color_Fuzzy_Search (disp_ref)
    src   = src[0]=="709" || src[0]=="170M" || src[0]=="240M" || src[0]=="Display-P3" || \
            FindStr(src[0], "470")>0 || FindStr(src[0], "2020")>0 ? [src[0],src[1],"1886"] : src
    tgt   = tgt[0]=="709" || tgt[0]=="170M" || tgt[0]=="240M" || tgt[0]=="Display-P3" || \
            FindStr(tgt[0], "470")>0 || FindStr(tgt[0], "2020")>0 ? [tgt[0],tgt[1],"1886"] : tgt
    s_gam = moncurve_coef (src[2])  # Primaries derived transfer
    t_gam = moncurve_coef (tgt[2])
    gamut = !(src[0] == tgt[0] || !gamut)

    rgb ? ConvertToPlanarRGB(src[0])                                     : \
          YUV_to_RGB(src[0], tv_range_in=tv, kernel=kernel, b=b, c=c, p=p)

    moncurve_f(s_gam[0], s_gam[1], false, false)

    if (gamut) {
    mata = RGB_to_XYZ (src[0], src[1], LMS=LMS, list=true)
    matw = CAT        (src[1], tgt[1], LMS=LMS, list=true)
    matb = XYZ_to_RGB (tgt[0], tgt[1], LMS=LMS, list=true)
    MatrixClip(MatrixDot(src[1]!=tgt[1] ? MatrixDot(mata, matw) : mata, matb) ) }

    Defined(LUT) || gamma ? moncurve_r(t_gam[0], t_gam[1], false, false) : \
                    gamut ? moncurve_r(s_gam[0], s_gam[1], false, false) : last

    Defined(LUT) ? ConvertBits(16, dither=-1, fulls=true) : last
    Defined(LUT) ? Cube(LUT, 3, true)                     : last

    ConvertBits(8, dither=1, fulls=true) }



# Matches 'a' to 'b' clip format (size, length, color model, Jab, bitdepth)
function MatchClip (clip a, clip b, string "kernel", string "matrix", bool "size", bool "props", bool "length", bool "fast") {

    krn    = Default (kernel, "Spline16")
    fst    = Default (fast,         true)
    fp     = Default (props,        true) # Assign frame properties
    sz     = Default (size,         true) # Match dimensions
    mfc    = Default (length,      false) # Match also framecount

    Assert(IsVersionOrGreater(3,7,2), "MatchClip: Update AviSynth+ version")

    propIDs= color_propGet(b)

    YUY2   = b.IsYUY2()
    rgbb   = b.isRGB()             rgba    = a.isRGB()
    w      = b.width()             wa      = a.width()
    h      = b.height()            ha      = a.height()
    fc     = b.FrameCount()        fca     = a.FrameCount()
    p_type = b.PixelType()         p_typea = a.PixelType()
    bib    = propIDs[7]            bia     = a.BitsPerComponent()


    fs      = propNumElements(a,"_ColorRange")  > 0 ? \
              propGetInt     (a,"_ColorRange") == 0 : rgba

    fd      = propIDs[6]

    isHDa   = (wa > 1099 || ha > 599 )
    isUHD   = (w  > 2599 || h  > 1499)
    isUHDa  = (wa > 2599 || ha > 1499)

    mat     = Default(matrix, propIDs[2])


        a
        yv411  = b.isYV411()      yv411a = a.isYV411()
        yv444  = b.is444()        yv444a = a.is444()
        !yv411 && bib > bia ? ConvertBits(bib, fulls=fs, fulld=fs) : last

    if (!fst) {

        ConvertFormat(w, h, fmt_in=p_typea, fmt_out=p_type, cs_in=mat, cs_out="", kernel=krn, tv_in=!fs, tv_out=!fd)

    } else {

        rgbp   = rgbb && b.isPlanar()
        isScl  = (w != wa || h != ha) && sz
        mod    = rgba && rgbb || isy(a) && isy(b) ? 1 : 2

        fmt    = format_Fuzzy_Search(b, p_type,  bib)
        fmta   = format_Fuzzy_Search(a, p_typea, bia)
        bc     = bicubic_coeffs(krn)
        krn    = bc[1]>=0. ? "Bicubic" : krn

        cplace  = rgbb || yv444  || yv411  ? "MPEG1" : isUHD  ? "top_left" : "MPEG2"
        cplacea = rgba || yv444a || yv411a ? "MPEG1" : isUHDa ? "top_left" : "MPEG2"
        not42   = LeftStr(fmta[1],2) != "42"

        # Match dimensions
        isScl ? w > h ? RatioResize(w,mode="adjust2w",kernel=krn,mod=mod,b=bc[0],c=bc[1]) : \
                        RatioResize(h,mode="adjust2h",kernel=krn,mod=mod,b=bc[0],c=bc[1]) : last
        isScl ?         PadResize(w,h,mode="dilate",             mod=mod)                 : last

        # ConvertBackToYUY2 bug: https://forum.doom9.org/showthread.php?p=1038027#post1038027
        isy(b) ? rgba ? isUHDa ? DotClip([0.262404,0.678455,0.059141]) : /* Assumes Rec2020 for UHD */
                      \  isHDa ? DotClip([0.212649,0.715169,0.072182]) : /* Assumes Rec709  for  HD */
                      \          DotClip([0.298903,0.586620,0.114477]) : ConvertToY(mat)                                                                                : \
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
    YUY2 && !rgba      ? ConvertToYUY2()           : last

    # Frame Properties
    if (fst && fp) {
    ID = color_Fuzzy_Search(mat)
                propCopy(b,true,props=["_Matrix","_Primaries"],exclude=true)
    fd !=  fs ? propSet("_ColorRange", fd ? 1 : 0) : last # Overrides the Convertto props
                propSet("_Matrix",          ID[3])        # Overrides the Convertto props
                propSet("_Primaries",       ID[4]) } }    # Disable this line and above when convertto supports writing to RGB frameprops (currently RGB is hardcoded to _Matrix 0 and _Primaries 2 -undefined-)





###
### ConvertFormat()
###
###
### Similar to avsresize's z_ConvertFormat() but more flexible, more options and more features:
### More color models and color space conversions, chroma reconstruction, scale_space, noring, mod size, ratio resize, kernel/matrix aliases (supports any resizer), presets, show settings, etc
###
### Dependencies: AviSynth+ 3.7.2 and over
###               ExTools
###               GradePack    (for show=true and 'sigmoid' scaling)
###               MasksPack    (for show=true)
###               ResizersPack (for show=true)
###               KNLMeansCL   (for UVRecon=true)
###               nnedi3       (for UVRecon=true)
###               SysInfo      (for UVRecon=true)
###               Optional resizer plugins (check links)
###
### Example 1 - Limited YUV to full RGB:
###     ConvertBits(10,fulls=false)     # RGB conversion from YUV requires at least 10-bit precision, but fairly enough for transfer/color space conversion tasks I wouldn't go any lower than 16-bit, unless you are curious on low bitdepth side-effects.
###     ConvertFormat(1,1,"YUV","RGB")
###
### Example 2 - Downscale HD Rec.709 YUV to SD 170M YUV:
###     ConvertFormat(720,kernel="SSIM2") # 0 stands for automatic size given width/height ratio
###     or
###     ConvertFormat(preset="DVD-NTSC") # Work-in-Progress
###
### Example 3 - YUV420 to YUV444 and scale up by 2 in sigmoid space with chroma reconstruction and noring (cs_out to "" or "none" to skip color space autoconversion):
###     ConvertFormat(2,fmt_out="44",cs_out="",kernel="FSRCC",scale_space="sigmoid",noring=true,UVRecon=true,cplace_in="MPEG2")
###
### Example 4 - Scale down by 2 with no moirée in linear light space (typically downscaling as well as pre-blurring -for nomoiree- are done in linear light):
###     ConvertFormat(0.5,kernel="RobiSharp",scale_space="linear",nomoiree=true)
###
### Example 5 - Scale width to 1280 and height to half with different kernels and taps for Luma/Chroma planes:
###     ConvertFormat(1280,0.5,kernel="EWA6",kernel_c="Blackman8")
###
### Example 6 - Convert from YUV444 to YUV422 and TV range to PC range:
###     ConvertFormat(1,fmt_out="422",tv_out=false,cplace_out="MPEG2")
###
### Example 7: High quality JPEG decoding and conversion to RGB
###   MP_Pipeline("""
###   ### platform: win32
###   JPEGSource("source.jpg",rec=3)
###   ### ###
###   """)
###   ConvertBits(16)
###   Implicit:
###       ConvertFormat(1,1,"YUV","RGB","jpeg","sRGB",UVRecon=true) # 'jpeg' as an alias for '170M'
###   Explicit:
###       ConvertFormat(1,1,"YUV","RGB","170M","sRGB",false,false,true,cplace_in="MPEG1",UVRecon=true)
###   ConvertBits(8, dither=1)
###
###
### Function Definition:
###     (
###     clip,
###     float width=1.0 (0.1 to 1920.0),
###     float height=1.0 (0.1 to 1080.0),
###     [string preset="none" ("none"/ "DoVi/DVp5/DVp7"/ "PQ10/UHD"/ "HLG10"/ "HD"/ "DVD-NTSC"/ "DVD-PAL"/ "DV"/ "CRT-NTSC"/ "CRT-PAL"/ "Master"/ "Archival"/ "Grade"/ "Theater"/ "JPEGXL"/ "JPEG2000"/ "JPG_old"/ "JPG")],
###     [string "fmt_in"=""  (""/ "YCbCr411"/ "YCbCr420"/ "YCbCr422"/ "YCbCr444"/ "YcCbcCrc"/ "YUVr"/ "YCoCg"/ "YCoCgR"/ "RGB"/ "HSV"/ "OPP"/ "XYZ"/ "Yxy"/ "YDzDx"/ "Duv"/ "CIELab"/ "CIELuv"/ "IPT"/ "Oklab")],
###     [string "fmt_out"="" (""/ "YCbCr411"/ "YCbCr420"/ "YCbCr422"/ "YCbCr444"/ "YcCbcCrc"/ "YUVr"/ "YCoCg"/ "YCoCgR"/ "RGB"/ "HSV"/ "OPP"/ "XYZ"/ "Yxy"/ "YDzDx"/ "Duv"/ "CIELab"/ "CIELuv"/ "IPT"/ "Oklab")],
###     [string "cs_in"=""  (""/ "709"/ "470M"/ "470BG"/ "170M"/ "240M"/ "2020NCL"/ "2020CL"/ "XYZ"/ "DCI-P3"/ "Display-P3"/ "ACEScg"/ "ACES2065"/ "ACESCCt"/ "AdobeRGB"/ "AWG")],
###     [string "cs_out"="" (""/ "709"/ "470M"/ "470BG"/ "170M"/ "240M"/ "2020NCL"/ "2020CL"/ "XYZ"/ "DCI-P3"/ "Display-P3"/ "ACEScg"/ "ACES2065"/ "ACESCCt"/ "AdobeRGB"/ "AWG")],
###     [string "OETF" ="" (""/ "1886a"/ "1886"/ "470M"/ "470BG"/ "170M"/ "240M"/ "linear"/ "log100"/ "log316"/ "xvYCC"/ "1361"/ "sRGB"/ "2020NCL"/ "2020CL"/ "PQ"/ "DCIXYZ"/ "HLG"/ "HLG NHK"/ "AdobeRGB"/ "ACESCCt")],
###     [string "OETFi"="" (""/ "1886a"/ "1886"/ "470M"/ "470BG"/ "170M"/ "240M"/ "linear"/ "log100"/ "log316"/ "xvYCC"/ "1361"/ "sRGB"/ "2020NCL"/ "2020CL"/ "PQ"/ "DCIXYZ"/ "HLG"/ "HLG NHK"/ "AdobeRGB"/ "ACESCCt")],
###     [string "EOTFi"="" (""/ "1886a"/ "1886"/ "470M"/ "470BG"/ "170M"/ "240M"/ "linear"/ "log100"/ "log316"/ "xvYCC"/ "1361"/ "sRGB"/ "2020NCL"/ "2020CL"/ "PQ"/ "DCIXYZ"/ "HLG"/ "HLG NHK"/ "AdobeRGB"/ "ACESCCt")],
###     [string "D_in"=""  (""/ "D50"/ "E"/ "D55"/ "D60"/ "DCI"/ "D65"/ "C"/ "D75"/ "D93")],
###     [string "D_out"="" (""/ "D50"/ "E"/ "D55"/ "D60"/ "DCI"/ "D65"/ "C"/ "D75"/ "D93")],
###     [string "cplace_in"=""  (""/ "center"/ "left"/ "top_left"/ "top"/ "bottom_left"/ "bottom")],
###     [string "cplace_out"="" (""/ "center"/ "left"/ "top_left"/ "top"/ "bottom_left"/ "bottom")],
###     [bool "tv_in"=true],
###     [bool "tv_out"=true],
###     [string "scale_space"="gamma" ("gamma"/ "linear"/ "sigmoid"/ "log")],
###     [string "kernel"="spline36"   ("nnedi3"/ "deep"/ "FCBI"/ "SuperResXBR"/ "Krig"/ "FSRCC"/ "DPID"/ "SSIM"/ "SSIM2"/ "--"/ "Nearest"/ "Box"/ "Bilinear"/ "Bicubic"/ "Quadratic"/ "Gauss"/ "--"/ "Wiener"/ "Spline"/ "Spline16"/ "Spline36"/ "Spline64"/ "Spline100"/ "Spline144"/ "Spline196"/ "Spline256"/ "--"/ "Jinc"/ "Jinc16"/ "Jinc36"/ "Jinc64"/ "Jinc100"/ "Jinc144"/ "Jinc196"/ "Jinc256"/ "EWASharp"/ "EWASharp2"/ "EWASharp4"/ "EWASharper"/ "EWASharper2"/ "EWASharper4"/ "EWASharpest"/ "EWASoft"/ "--"/ "Sinc"/ "SincLin"/ "SinPow"/ "--"/ "Welch"/ "Cosine"/ "Bessel"/ "Wiener"/ "Hamming"/ "Hann"/ "Kaiser"/ "Blackman"/ "Black-Harris"/ "Black-Nuttall"/ "Nuttall"/ "Bohman"/ "Parzen"/ "Lanczos"/ "Ginseng"/ "Flat-Top"/ "MinSide"/ "--"/ "Notch"/ "SoftCubic100"/ "Robidoux Soft"/ "SoftCubic75"/ "BilcubicD"/ "BilcubicU"/ "Hermite"/ "Robidoux"/ "Centroid"/ "Mitchell-Netravali"/ "Robidoux Sharp"/ "SoftCubic50"/ "CatMule-Dog"/ "Cub-grange"/ "Catmull-Rom"/ "Didee"/ "Zopti"/ "ZoptiN"/ "ZoptiH"/ "Zopti720"/ "Zopti720U"/ "Zopti1080"/ "Precise"/ "Sharp"/ "Hatch")],
###     [string "kernel_c"="spline36" ("nnedi3"/ "deep"/ "FCBI"/ "SuperResXBR"/ "Krig"/ "FSRCC"/ "DPID"/ "SSIM"/ "SSIM2"/ "--"/ "Nearest"/ "Box"/ "Bilinear"/ "Bicubic"/ "Quadratic"/ "Gauss"/ "--"/ "Wiener"/ "Spline"/ "Spline16"/ "Spline36"/ "Spline64"/ "Spline100"/ "Spline144"/ "Spline196"/ "Spline256"/ "--"/ "Jinc"/ "Jinc16"/ "Jinc36"/ "Jinc64"/ "Jinc100"/ "Jinc144"/ "Jinc196"/ "Jinc256"/ "EWASharp"/ "EWASharp2"/ "EWASharp4"/ "EWASharper"/ "EWASharper2"/ "EWASharper4"/ "EWASharpest"/ "EWASoft"/ "--"/ "Sinc"/ "SincLin"/ "SinPow"/ "--"/ "Welch"/ "Cosine"/ "Bessel"/ "Wiener"/ "Hamming"/ "Hann"/ "Kaiser"/ "Blackman"/ "Black-Harris"/ "Black-Nuttall"/ "Nuttall"/ "Bohman"/ "Parzen"/ "Lanczos"/ "Ginseng"/ "Flat-Top"/ "MinSide"/ "--"/ "Notch"/ "SoftCubic100"/ "Robidoux Soft"/ "SoftCubic75"/ "BilcubicD"/ "BilcubicU"/ "Hermite"/ "Robidoux"/ "Centroid"/ "Mitchell-Netravali"/ "Robidoux Sharp"/ "SoftCubic50"/ "CatMule-Dog"/ "Cub-grange"/ "Catmull-Rom"/ "Didee"/ "Zopti"/ "ZoptiN"/ "ZoptiH"/ "Zopti720"/ "Zopti720U"/ "Zopti1080"/ "Precise"/ "Sharp"/ "Hatch")],
###     [int "taps"=[0,0] ([0,0] to [12,12] by [1,1])],
###     [bool "nomoiree"=false],
###     [bool "noring"=false],
###     [bool "UVrecon"=false],
###     [bool "show"=false]
###     )
###
###
####################################



# Resizer Plugins:
#
# SimpleResize (2 tap lin) (8-bit)            (dw) https://avisynth.nl/index.php/SimpleResize (same than Box/Area but without pixel centering, very fast)
# Box/Dirichlet/Area/Average                  (dw) https://github.com/EleonoreMizo/fmtconv or https://github.com/Aktanusa/AreaResize
# SSIM                                        (dw) https://github.com/mysteryx93/AviSynthShader/releases
# SSIM_downsample                             (dw) https://github.com/Dogway/Avisynth-Scripts/blob/master/EX%20mods/SimilarityMetrics.avsi   (HQ settings: SSIM_downsample(w,h,smooth=0.43,resample_args="-0.6,0.4") )
# DPID                                        (dw) https://github.com/Asd-g/AviSynth-DPID (requires: http://avisynth.nl/index.php/Avsresize) (Ranking: Zopti1080 (for UHD) >= SSIM_downsample > DPID > SSIM >>> SincLin > Zopti)
# Spline100/Spline144                         (up) https://github.com/EleonoreMizo/fmtconv
# Wiener                                      (up) https://github.com/EleonoreMizo/fmtconv      (Sharp as Blackman6 but much more aliasing, and a bit more ringing)
# SincLin2ResizeMT                         (up,dw) https://github.com/jpsdr/ResampleMT/releases (like a sharper lanczos or a -moderate- ring suppresed Sinc) (Doom9 thread: https://forum.doom9.org/showthread.php?p=1919769#post1919769)
# SinPowResizeMT                              (dw) https://github.com/jpsdr/ResampleMT/releases (Doom9 thread: https://forum.doom9.org/showthread.php?p=1918124)
# Jinc (EWA Lanczos)                          (up) https://github.com/Asd-g/AviSynth-JincResize/releases
# FCBI (Fast Curve Based Interp)              (up) https://github.com/Asd-g/AviSynth-FCBI
# SuperResXBR                                 (up) https://github.com/mysteryx93/AviSynthShader/releases
# AiUpscale/FSRCNN (FastSuperResolutionConvo) (up) https://github.com/Alexkral/AviSynthAiUpscale/tree/master/Shaders (lineart / photo folders)
# KrigBilateral                               (up) https://github.com/Alexkral/AviSynthAiUpscale/tree/master/Shaders/KrigBilateral
# NoHalo                                           https://github.com/libvips/libvips/blob/master/libvips/resample/nohalo.cpp (NicolasRobidoux special up/downscalers)
# LoHalo                                           https://legacy.imagemagick.org/discourse-server/viewtopic.php?p=90433&sid=9b1885ea67cf86554709da0282c14796#p90433
# EWA QuadraticJinc 3-taps
# EWA RobidouxSharp
# EWA CatRom
# EASU - Edge Adaptive Spatial Upscaling (AMD's FSR) (up) (Uses a custom (McLaurin approx) of a 2-tap Lanczos in a single pass (EWA?), and clamped to nearest neighbour upscale to eliminate ringing)

# Internal:
# Point    / Nearest             (actually slower than bicubic!)
# Bilinear / Triangular
# Bicubic  / Cubic               (not recommended for highly quantized content: JPEGs, H.264, etc)
# Spline   / Cubic Polynomials   (spline16 -2 lobes- spline36 -3 lobes- spline64 -4 lobes-)
# Sinc     is a box-windowed             sinc filter (Default 4 lobes).
# Lanczos  is a Lanczos or sinc-windowed sinc filter (Default 4 lobes).
# Blackman is a Blackman-windowed        sinc filter (Default 6 lobes). (Improved lanczos with less ringing)

# (-) Missing. ref: https://github.com/mpv-player/mpv/blob/master/video/out/filter_kernels.c
#              ref: https://artoriuz.github.io/blog/mpv_upscaling.html
#              ref: https://en.wikipedia.org/wiki/Window_function
#              ref: https://legacy.imagemagick.org/Usage/filter/nicolas/
#              ref: https://legacy.imagemagick.org/discourse-server/viewtopic.php?f=22&t=20942
# -- untapered decay
# Welch/Welsh         is a Welch-windowed    sinc filter (parabolic window, 3 lobes)
# Cosine              is a Cosine-windowed   sinc filter (3 lobes) (Good for downscaling but also upscaling. Same as Wiener but without aliasing. Therefore very similar to Blackman6 but with a bit of ringing)
# Bessel              is a unnormalized      sinc filter (3 lobes)
# -- tapered decay (in order)
# Bartlett            is a Bartlett-windowed sinc filter (4 lobes) (actually the same mathematical function used for a 'Triangle' filter, as well as the 'Bilinear' interpolation filter)
# Sinc                is a Sinc-windowed     sinc filter (4 lobes)
# Hamming             is a Hamming-windowed  sinc filter (4 lobes) (has a gradient discontinuity so not recommended)
# Hann(ing)           is a Hanning-windowed  sinc filter (4 lobes) (2-lobes can be used for upscaling sharp images) (Just like Blackman6 bit a tiny bit softer)
# Kaiser              is a Kaiser-windowed   sinc filter (4 lobes) (also a small gradient discontinuity so not recommended)
# Bohman              is a Bohman-windowed   sinc filter (6 lobes) (Blackman would fall between Kaiser and Bohman)
# Parzen              is a Parzen-windowed   sinc filter (8 lobes) (Very similar to Blackman6)
# Ginseng             is a Jinc-windowed     sinc filter (3 lobes). Better for HBD than ewa_lanczos3. Very similar to spline36 aliasing wise, but sharper. Also adds some bloating.
# -Lagrange           is a Lagrange cubic polynomial filter that approximates a windowed filter https://legacy.imagemagick.org/Usage/filter/#lagrange
# -Jinc/Bessel        is a Box-windowed      jinc filter (3.2383154841662362 lobes). Jinc filters are not separable so they're usually slower than sinc, cubic, etc but more pleasant artifacts. See here: https://legacy.imagemagick.org/Usage/filter/#cylindrical
# -ewa_hanning        is a Hanning-windowed  jinc filter (3.238 lobes).
# -ewa_ginseng        is a sinc-windowed     jinc filter (3.238 lobes).
# ewa_lanczos         is a lanczos-windowed  jinc filter (3.238 lobes). Under same circumstances -in this case 'taps'- Jinc (radial) is always sharper than their Sinc (orthogonal) equivalent. Check ewa_lanczosradius3 below.
# ewa_lanczossharp    is a lanczos-windowed  jinc filter (3.238 lobes). Slightly sharpened as per calculations by Nicolas Robidoux, his preferred all-around scaler. Can be replicated with Jinc filter and blur = 0.9812505644269356
# ewa_lanczossharpest is a lanczos-windowed  jinc filter(3.238 lobes). Very sharp, technically not recommended by Robidoux except when downscaling. Can be replicated with Jinc filter and blur = 0.88549061701764
# ewa_lanczos2sharp   is a lanczos-windowed  jinc filter(2.2331305943815286 lobes). Good alternative to the other EWAs when you don't want the moiree or "hash pattern blur" artifact, so use this for dithered content or RobiSharp.
# ewa_lanczosradius3  is a lanczos-windowed  jinc filter(3 lobes). More sharpened than ewa_lanczossharp and very similar to Ginseng tensor, good for up and downscale. Can be replicated with Jinc filter and blur = 0.9264075766146068 (scales lobes from 3.238 to 3)
# ewa_lanczos4        is a lanczos-windowed  jinc filter (4.2410628637960699 lobes).
# ewa_lanczossoft     is a lanczos-windowed  jinc filter (3.238 lobes). Softened instead. This one makes hash patterns disappear completely (blur determined by trial and error). Can be replicated with Jinc filter and blur = 1.015. https://github.com/mpv-player/mpv/blob/27c38eac1040cd781f39d977ce53adcd65ddcfb6/video/out/filter_kernels.c#L380
# -Haasnsoft          is a Hanning-windowed  jinc filter (3.238 lobes). Removes almost all aliasing. Blur value to match orthogonal and diagonal contributions on a regular grid. Can be replicated with Jinc filter and blur = 1.11
# -Tukey              is a Hanning-windowed  jinc filter taper = 0.5
# Quadratic/Quadric/Bell like Cubic but 66% faster (1.5 taps/lobes). Also known as 'Bell' -> https://clouard.users.greyc.fr/Pantheon/experiments/rescaling/index-en.html#bell
# -RAVU / RAISR       similar to XBR and nnedi3
# -NGU                Next Generation Upscaler. madVR edge directed NN algo (closed source, similar to FSRCNN)
# -Sphinx             Continuation of Sinc and Jinc, interpolating all three dimensions at the same time using a carefully constructed filter that has a perfectly spherical frequency response. 1.4302966531242027, sphinx window.
# -ICBI               (Iterative Curve Based Interpolation) is a single image superresolution technique described in Fast artifact-free image interpolation by Andrea Giachetti and Nicola Asuni, presented at BMVC 2008
#
#
# Understanding an end-to-end transfer function pipeline for a system:
#    OETF (Input Device) -> OETFi (input transfer decode) -> EOTFi (Display transfer encode) -> EOTF (Output Device, ie. Display)
#
# * If you define 'OETF' (also known as OECF) it will override 'EOTFi'
#
function ConvertFormat (clip clp, val "width", val       "height", string   "fmt_in", string       "fmt_out", string        "cs_in", string         "cs_out", string           "OETFi", string      "EOTFi", string "OETF",  \
                                                                   string     "D_in", string         "D_out", bool          "tv_in", bool           "tv_out", string       "cplace_in", string "cplace_out", string  "LMS",  \
                         string "scale_space", string    "kernel", string "kernel_c", float_array "src_left", float_array "src_top", float_array "src_width", float_array "src_height",                                      \
                           string    "preset", float_array "taps", int         "mod", bool        "nomoiree", bool         "noring", bool          "UVrecon", bool             "show") {
    clp
    wu         = !Defined(width)
    hu         = !Defined(height)
    w          = width ()
    h          = height()
    fc         = FrameCount() < 2
    isy        = isy()
    p_type     = PixelType()
    propIDs    = color_propGet()
    bi         = propIDs[7]


    nw         = Default (width,   1)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target width
    nh         = Default (height, nw)             # 0.0 to 10.0 is a multiplier. 12 to inf is absolute target height
    i_fmt      = format_Fuzzy_Search (Default (fmt_in,  p_type), bi)
    o_fmt      = format_Fuzzy_Search (Default (fmt_out, p_type), bi)
    isRGBi     = i_fmt[0]=="RGB"
    isRGBo     = o_fmt[0]=="RGB"
    RT         = isRunTime(clp,isRGBi)
    lut1       = bi == 32 || RT ? 0 : 1
    lut2       = bi  > 12 || RT ? 0 : 2

    isRGBi ? ConvertToPlanarRGB() : last

    mod        = Default (mod, isy||isRGBo||o_fmt[1]=="444" ? 1 : 2) # mod size for resizing. ie: 1, 2, 4, 8, 16...

    Assert(isFloat(nw) || isFloat(nh), "ConvertFormat: Width/Height type not supported.") # isFloat(int) also returns true, so good for 'number' type evaluation
    nw         = isInt(nw) && nw<=10 ? float(nw) : isFloat(nw) && nw>10. ? int(nw) : nw
    nh         = isInt(nh) && nh<=10 ? float(nh) : isFloat(nh) && nh>10. ? int(nh) : nh
    nw         =  nw<=10. ? w*nw : nw            nw     = round(nw/mod)*mod
    nh         =  nh<=10. ? h*nh : nh            nh     = round(nh/mod)*mod

    nw         =  nw == 0 || wu ? round((w*(nh/float(h)))/mod)*mod : nw
    nh         =  nh == 0 || hu ? round((h*(nw/float(w)))/mod)*mod : nh

    isUHD      = ( w > 2599 || h > 1499)      isnUHD = (nw > 2599 || nh > 1499)
    isHD       = ( w > 1099 || h > 599 )      isnHD  = (nw > 1099 || nh > 599 )

    wr         = float(nw) / w                 hr     = float(nh) / h     # for nomoiree
    rat        = max(abs(wr - 1),abs(hr - 1)) == abs(wr - 1) ? wr : hr    # for nomoiree

    # DEFAULTS
    Und        = Undefined()
       cs_in_d = Defined (cs_in)
    cs_in      = cs_in_d  ? cs_in ==""  ? Und   : cs_in : fc ? "jpeg" : propIDs[2]
       cs_inFA = color_Fuzzy_Search (cs_in)
       cs_inF  = cs_inFA[0]
    cs_out     = Defined (cs_out) ? cs_out =="" ? cs_in : cs_out : cs_in_d ? cs_in : (cs_in == "jpeg" || cs_in == "jpg" || cs_inF == "sRGB") && isRGBo ? "sRGB" : isnUHD ? "2020" : isnHD ? "709" : "170M"
      cs_outFA = color_Fuzzy_Search (cs_out)
      cs_outF  = cs_outFA[0]
    OETFd      = Defined(OETF) ? OETF=="" ? false : true : false
    OETFid     = cs_inF =="709" || cs_inF =="170M" || cs_inF =="240M" || cs_inF =="Display-P3" || FindStr(cs_inF, "470")>0 || FindStr(cs_inF, "2020")>0 ? "1886" : propIDs[5]
    OETFi      = Defined(OETFi) ? OETFi =="" ? OETFid : OETFi : OETFid # By default undoes encoded display referred transfer (1886 EOTFi) for consumer media instead of scene-referred camera transfer (OETFi)
    EOTFid     = cs_outF=="709" || cs_outF=="170M" || cs_outF=="240M" || cs_outF=="Display-P3" || FindStr(cs_outF,"470")>0 || FindStr(cs_outF,"2020")>0 ? "1886" : cs_outF
    EOTFi      = OETFd ? OETF : Defined(EOTFi) ? EOTFi =="" ? OETFi : EOTFi : EOTFid
       OETFi_i = color_Fuzzy_Search (OETFi)
       EOTFi_i = color_Fuzzy_Search (EOTFi)
          EOTF = EOTFi_i[2]
       tv_in_d = Defined (tv_in)
    tv_in      = Default (tv_in,  !(isRGBi || cs_inF =="sRGB" || cs_in =="jpeg" || cs_in =="jpg") && propIDs[6]   )
    tv_out     = Default (tv_out,  (isRGBo || cs_outF=="sRGB" || cs_out=="jpeg" || cs_out=="jpg") ? false : tv_in )
    kernel     = Default (kernel,   (w>nw||h>nh)?"Didee":"Precise")
    kernel_c   = Default (kernel_c, kernel)
    LMS        = Default (LMS,            "CAT02B"     ) # Eventually until I fix for CAT16 and vonKries (HPE)
    space      = Default (scale_space,    "gamma"      ) # resizing space: "gamma", "linear" (best for down), "sigmoid" (best for up) or "log" for quasi-log. Assumes gamma encoded input. ("luminance weighted gamma resampling/sharpening"" Improvement over sigmoid: https://forum.doom9.org/showthread.php?p=1687374#post1687374) or (https://web.archive.org/web/20150420001849/http://forum.luminous-landscape.com/index.php?topic=91754.msg763345#msg763345)
    cplace_in  = Default (cplace_in, fc ? "center" : "") # Assumes default from format
    cplace_out = Default (cplace_out,  cplace_in)        # Assumes default from format
    D_in       = Defined(D_in)  ? D_in  =="" ? Und  : D_in  : cs_in_d  ? cs_in ==""  ? propIDs[2] : cs_in : propIDs[2]
    D_out      = Defined(D_out) ? D_out =="" ? D_in : D_out : D_in # By default same as input, change based on space?
        D_inA  = color_Fuzzy_Search (D_in )
        D_outA = color_Fuzzy_Search (D_out)
        D_out  = D_outA[1]
    p          = Defined (taps)     ? IsArray(taps)      ? ArraySize(taps)     > 1 ? taps     : ArrayAdd(taps,0)       : [taps,0]       : [0,0]
    pd         = p[0] > 0
    pdc        = p[1] > 0

        prp    = color_propGet (cs_inFA[4], D_inA[5], cs_inFA[4], OETFi_i[6])
        cs_in  = prp[2]
        cs_out = cs_outF
        D_in   = prp[3]
        OETF   = prp[5]
    src_left   = Defined (src_left) ? IsArray(src_left)  ? ArraySize(src_left) > 1 ? src_left : ArrayAdd(src_left,0.0) : [src_left,0.0] : [0.0,0.0]
    src_leftc  = src_left[1]       src_left = src_left[0]
    src_top    = Defined (src_top)  ? IsArray(src_top)   ? ArraySize(src_top)  > 1 ? src_top  : ArrayAdd(src_top, 0.0) : [src_top, 0.0] : [0.0,0.0]
    src_topc   = src_top [1]       src_top  = src_top [0]

    noring     = Default (noring,  false)
    nomoir     = Default (nomoiree,false)
    recon      = Default (UVrecon, false)
    fs         = !tv_in
    dg         = Default (show,    false)

    # PRESETS (maps outputs format)
    preset     = Default(preset, "none")
    num        = preset == ""             ? 0  : \
                 preset == "none"         ? 0  : \
                 preset == "DoVi"         ? 1  : \
                 preset == "DVp5"         ? 1  : \
                 preset == "DVp7"         ? 1  : \
                 preset == "DoVi/DVp5/DVp7"?1  : \
                 preset == "PQ10"         ? 2  : \
                 preset == "UHD"          ? 2  : \
                 FindStr(preset,"2100")>0 ? 2  : \
                 preset == "PQ10/UHD"     ? 2  : \
                 preset == "HLG10"        ? 3  : \
                 preset == "HD"           ? 4  : \
                 FindStr(preset,"1886")>0 ? 4  : \
                 preset == "DVD"          ? 5  : \
                 preset == "DVD-NTSC"     ? 5  : \
                 preset == "DVD-PAL"      ? 6  : \
                 preset == "DV"           ? 7  : \
                 preset == "CRT"          ? 8  : \
                 preset == "601"          ? 8  : \
                 preset == "NTSC"         ? 8  : \
                 FindStr(preset,"525")>0  ? 8  : \
                 preset == "CRT-NTSC"     ? 8  : \
                 preset == "PAL"          ? 9  : \
                 preset == "470"          ? 9  : \
                 FindStr(preset,"625")>0  ? 9  : \
                 preset == "CRT-PAL"      ? 9  : \
                 preset == "Master"       ? 10 : \
                 preset == "Archival"     ? 11 : \
                 preset == "GAM"          ? 11 : \
                 preset == "Grade"        ? 12 : \
                 preset == "Theater"      ? 13 : \
                 preset == "JPEGXL"       ? 14 : \
                 preset == "JPEG2000"     ? 15 : \
                 preset == "JPG_old"      ? 16 : \
                 preset == "JPG"          ? 17 : 0

    #                                   Default  DoVi/DVp5/DVp7  PQ10/UHD/2100   HLG10    HD/1886  DVD-NTSC/601  DVD-PAL/470BG  DV-NTSC     CRT-NTSC     CRT-PAL     Master  GAM*/Archival    Grade     Theater      JPEGXL    JPEG2000    JPG_old  JPG/sRGB
    o_fmt0        = Select (num,      o_fmt[0],      "IPTPQc2",     "YCbCr",    "YCbCr",   "YCbCr",    "YCbCr",     "YCbCr",    "YCbCr",       "YIQ",     "YUV",     "RGB",       "RGB",      "RGB",     "YUVr",      "XYB",     "YUVr",  "YCbCr",   "sYCC") # Model. sYCC is basically sRGB (prims, transfer, range) over YCbCr, but uses true Rec709 derived matrix coeffs, not from 470M
    cs_outFA      = Select (num,      cs_outFA,         "2020",      "2020",     "2020",     "709",     "170M",     "470BG",     "170M",      "170M",   "470BG",  "DCIXYZ",       "AP0",      "AP1",   "DCIXYZ",     "sRGB",     "sRGB",   "170M",   "sRGB") # Primaries. JPG_old standardized decoding (PS, mozjpeg, cjxl, etc) is always treated as encoded with 170M (470M derived) matrix, regardless of image/profile primaries, a mess: https://en.wikipedia.org/wiki/YCbCr#Chromaticity-derived_luminance_systems
    o_fmt1        = Select (num,      o_fmt[1],          "420",       "420",      "420",     "420",      "420",       "420",      "410",       "411",     "411",     "444",       "444",      "444",      "444",      "444",      "444",    "420",    "422") # [J:a:b]
    tv_out        = Select (num,        tv_out,          false,        true,       true,      true,       true,        true,      false,        true,      true,     false,       false,      false,      false,      false,      false,    false,    false)
    cplace_out    = Select (num,    cplace_out,     "top_left",  "top_left", "top_left",    "left",     "left",      "left",       "DV",    "center",  "center",        "",          "",         "",         "",         "",         "", "center", "center")
    D_out         = Select (num,         D_out,          "D65",       "D65",      "D65",     "D65",      "D65",       "D65",      "D65",       "D65",     "D65",       "E",       "D60",      "D60",        "E",      "D65",      "D65",    "D65",    "D65")
    EOTF          = Select (num,          EOTF,           "PQ",        "PQ",      "HLG",    "1886",     "1886",      "1886",     "170M",      "170M",    "170M",  "DCIXYZ",    "linear",  "ACESCCt",   "DCIXYZ",     "sRGB",     "sRGB",   "170M",   "sRGB")
    PAR           = Select (num,             1,              1,           1,          1,         1,      "601",       "470",      "601",       "601",     "601",         1,           1,          1,          1,          1,          1,        1,        1)
    cdc           = Select (num,            "",         "H265",      "H265",     "H265",    "H264",     "H262",      "H262",     "H261",          "",        "",    "TIFF",       "PIZ",      "PIZ","MJPEG2000",   "JPEGXL", "JPEG2000",    "JPG",    "JPG")
    cont          = Select (num,            "",           "TS",        "TS",       "TS",      "TS",      "VOB",       "VOB",    "MPEG2",          "",        "",    "TIFF",       "EXR",      "EXR",      "mj2",      "jxl",      "jp2",    "jpg",    "jpg")
    bit           = Select (num,            bi,             12,          10,         10,         8,          8,           8,          8,           0,         0,        16,          16,         32,         12,          8,          8,        8,        8)

  # * DVD-PAL and DVD-NTSC employ 1886 as EOTF since the dawn of digital mastering (early 2000s), otherwise used 170M.
  # * GAM (Graded Archival Master)


    ############ Data extraction and normalization + Asserts ############

                 Assert(IsVersionOrGreater(3,7,2), "ConvertFormat: Update AviSynth+ version")
    !(space=="sigmoid" || space=="gamma" || space=="linear" || space=="log") ? \
                 Assert(false, "ConvertFormat: Invalid scale space type")    : nop()


    space    = space  != "" && space  != "none" ? space : "gamma"

    # Constants for logic flow
    isGamma  = OETF      !=  EOTF
    isSpace  = cs_in     !=  cs_out
    isFrmt   = i_fmt[0]  !=  o_fmt0
    isIllu   = D_in      !=  D_out
    isScale  = nw!=w     ||  nh!=h
    isJab    = i_fmt[1]  !=  o_fmt1
    isChP    = cplace_in != cplace_out

    coef_i   =           color_coef(mat=cs_in)
    coef_o   = isSpace ? color_coef(mat=cs_out) : coef_i
    s_gam    =           moncurve_coef (OETF)
    t_gam    = isGamma ? moncurve_coef (EOTF)   : s_gam

    i_type4  = i_fmt[1] == "444"         o_type4  = o_fmt1 == "444"
    i_type2  = i_fmt[1] == "422"         o_type2  = o_fmt1 == "422"
    i_type1  = i_fmt[1] == "411"         o_type1  = o_fmt1 == "411"
    i_type10 = i_fmt[1] == "410"         o_type10 = o_fmt1 == "410"

    cow      = i_type4 ?  w : i_type1 || i_type10 ? round( w/4.0) : round( w/2.0)
    coh      = i_type4 ||     i_type1 || i_type2  ?             h : round( h/2.0)
    cnw      = o_type4 ? nw : o_type1 || o_type10 ? round(nw/4.0) : round(nw/2.0)
    cnh      = o_type4 ||     o_type1 || o_type2  ?            nh : round(nh/2.0)

    # Parsing bicubics coefficients
    kernel   = kernel   == "Bilcubic" ?   w*h   <  nw*nh  ? "BilcubicU" : "BilcubicD" : kernel
    kernel_c = kernel_c == "Bilcubic" ? cow*coh < cnw*cnh ? "BilcubicU" : "BilcubicD" : kernel_c
    bc       = bicubic_coeffs(kernel)            bch      = bicubic_coeffs(kernel_c)
    bc_b     = bc[0]>=-1.?bc[0]:1/3.             bch_b    = bch[0]>=-1.?bch[0]:1/3.
    bc_c     = bc[0]>=-1.?bc[1]:1/3.             bch_c    = bch[0]>=-1.?bch[1]:1/3.
    kernel   = bc[0]>=-1.? "Bicubic" : kernel    kernel_c = bch[0]>=-1.? "Bicubic" : kernel_c

    src_width  = Defined (src_width)  ? IsArray(src_width)  ? ArraySize(src_width)  > 1 ? src_width  : ArrayAdd(src_width, 0.0) : [src_width, 0.0] : [0.0,0.0]
    src_widthc = src_width[1]      src_width  = src_width[0]
    src_height = Defined (src_height) ? IsArray(src_height) ? ArraySize(src_height) > 1 ? src_height : ArrayAdd(src_height,0.0) : [src_height,0.0] : [0.0,0.0]
    src_heightc= src_height[1]     src_height = src_height[0]

    i_type1  || o_type1                  ? Assert(bi == 8, "ConvertFormat: Unsupported Pixel Type: HBD YUV411")         : nop()
    i_type10 || o_type10                 ? Assert(false,   "ConvertFormat: Unsupported Pixel Type: YUV410")             : nop()
    !fc && (i_type2  || i_fmt[1]=="420") ? Assert( w%2==0, "ConvertFormat: Clip Width is not mod2" )                    : nop()
    !fc &&  i_type1                      ? Assert( w%4==0, "ConvertFormat: Clip Width is not mod4" )                    : nop()
    o_type1                              ? Assert(nw%4==0, "ConvertFormat: Target Width is not mod4" )                  : nop()
    !(isRGBo ||  o_type4 || (cnw>cow || cnh>coh))                                                                       ? \
                                           Assert(!recon,  "ConvertFormat: Invalid settings for chroma reconstruction") : nop()


    # Overriding 'taps' arg by kernel name (ie. 'blackman8' means taps=8)

    function StrNumber(string str) {
        for (i = 16, 0, -1) {
           num = str == string(i)
             i = num ? 0 : i
                 num} } # Checks if string is a number between 1 and 16

    # Exclusion list
    Lkrn = LCase(kernel)    Lkrnc = LCase(kernel_c)
    nope = (kernel   == "spline16" || kernel   == "spline36" || kernel   == "spline64" || kernel   == "spline100" || kernel   == "spline144" || kernel   == "spline196" || kernel   == "spline256") && Lkrn  !="spline" || \
            FindStr(Lkrn, "jinc") > 0   && Lkrn  !="jinc" || FindStr(Lkrn, "ewasharp") > 0 || FindStr(Lkrn, "nnedi3") > 0 || FindStr(Lkrn, "ssim2") > 0
    nopc = (kernel_c == "spline16" || kernel_c == "spline36" || kernel_c == "spline64" || kernel_c == "spline100" || kernel_c == "spline144" || kernel_c == "spline196" || kernel_c == "spline256") && Lkrnc !="spline" || \
            FindStr(Lkrnc, "jinc") > 0  && Lkrnc !="jinc" || FindStr(Lkrnc,"ewasharp") > 0 || FindStr(Lkrnc,"nnedi3") > 0 || FindStr(Lkrn, "ssim2") > 0

    tapFinder1 = RightStr(kernel,1)  StrN1 = StrNumber(tapFinder1) && !nope
    tapFinder2 = RightStr(kernel,2)  StrN2 = StrNumber(tapFinder2) && !nope
    taps       = StrN2 ? Eval(tapFinder2) : StrN1 ? Eval(tapFinder1) : p[0]
    kernel     = !nope ? ReplaceStr(kernel , string(taps), "") : kernel
    pd         = StrN1 || StrN2 ? true : pd

    tapFinder1 = RightStr(kernel_c,1)  StrN1 = StrNumber(tapFinder1) && !nopc
    tapFinder2 = RightStr(kernel_c,2)  StrN2 = StrNumber(tapFinder2) && !nopc
    tapsc      = StrN2 ? Eval(tapFinder2) : StrN1 ? Eval(tapFinder1) : p[1]
    kernel_c   = !nopc ? ReplaceStr(kernel_c , string(tapsc), "") : kernel_c
    pdc        = StrN1 || StrN2 ? true : pdc



    bessel3       = [1.5708,1.525858,1.39627,1.196854,0.94988,0.681773,0.419361,0.186267,0,-0.129804,-0.201802,-0.222051,-0.202077,-0.156337,-0.0995575,-0.044427,0,0.029012,0.0420623,0.041868,0.0330862,0.020877,0.00967627,0.002371]
    quadratic15   = [0.75,0.746094,0.734375,0.714844,0.6875,0.652344,0.609375,0.558594,0.5,0.439453,0.382813,0.330078,0.28125,0.236328,0.195313,0.158203,0.125,0.095703,0.070313,0.048828,0.03125,0.017578,0.007813,0.001953]
    wiener3       = [1,0.928293,0.847768,0.749610,0.625,0.470033,0.300445,0.136885,0,-0.094068,-0.147204,-0.165801,-0.15625,-0.1255,-0.082723,-0.037647,0,0.022825,0.032783,0.034161,0.03125,0.02491,0.017308,0.008864]
    welch3        = [1,0.972804,0.894064,0.771960,0.618936,0.450106,0.281349,0.127371,0,-0.093051,-0.148802,-0.168948,-0.159155,-0.127874,-0.0848512,-0.039589,0,0.028562,0.0437654,0.046219,0.0389045,0.026257,0.0130728,0.003457]
    cosine3       = [1,0.972409,0.892614,0.769145,0.614928,0.445557,0.277261,0.124857,-0,-0.090029,-0.142854,-0.160801,-0.150053,-0.119324,-0.0782968,-0.036093,0,0.025353,0.0382818,0.039802,0.0329539,0.021856,0.0106832,0.002771]
    ginseng3      = [1,0.9706924517023813,0.8863037293563394,0.7568846746026882,0.5974484350594943,0.42568771143242046,0.2593638071484244,0.1138155395729318,0,-0.07663423509063601,-0.11630395745498025,-0.12412241952630289,\
                     -0.10861320529064979,-0.07983137551487393,-0.04746371544549015,-0.01925303598542219,0,0.008737966998564498,0.00827789347498015,0.0019289633237434013,-0.006160413752293629,-0.012153940393777712,-0.013434473237575344,-0.00910161101088654]
    hann4         = [1,0.9721491276507364,0.8916666533754284,0.7673293227933666,0.6123898750249921,0.44274830753566713,0.27481699575031854,0.12341360408603762,0,-0.08848381495693607,-0.14005052617158592,-0.1573484857988253,-0.14670726866144826,-0.11675289338122011,-0.0768542368708979,-0.035667086889988917,0,0.025852297356152947,\
                     0.040259628673424544,0.043939594567039456,0.039299593276647324,0.029609836521073,0.018187607754470616,0.007745261904000362,0,-0.0044240051920867865,-0.005835794531242358,-0.005144384187084287,-0.0034614139060841795,-0.0017466187017072979,-0.0005766441854451786,-0.00007568486302246578]
    hamming4      = [1,0.9723291304741598,0.8923302555040387,0.7686246617990514,0.6142487927491155,0.4448795641717659,0.27675712509487843,0.1246257815086694,0,-0.0900023682175275,-0.1431203033588165,-0.16168530396390082,-0.1517323766550889,-0.12167980632033411,-0.0808254466432445,-0.0379149269102415,0,0.02826674933221172,\
                     0.044845606381107544,0.05006826118507596,0.0460528222676711,0.03593314767037512,0.02307155155805429,0.010401622971455375,0,-0.00707512686962141,-0.010701323742157228,-0.011434689771183611,-0.010173206936358085,-0.00783656756150458,-0.005137221895242707,-0.002481597155711647]
    blacknuttall4 = [1,0.9691956173858006,0.8808777891436077,0.7465903227462598,0.583261858851737,0.41026820009726694,0.2462414690601752,0.10626931490160989,0,-0.06906778816628918,-0.10311203169060508,-0.10858461954425613,-0.09429622625282544,-0.06945329948290131,-0.04204507233452078,-0.0178310531150637,0,0.010590373575929674,\
                     0.014791046691013261,0.0143917812832477,0.01141108308851331,0.007582722772125722,0.004090031528918704,0.0015247187900517072,0,-0.0006668666328159042,-0.0007753811435345259,-0.0006111170869562098,-0.0003782503724444364,-0.00018625686680715366,-0.00006947677421552765,-0.00001734615796446616]
    blackharris4  = [1,0.9690685474542851,0.8804147429536661,0.7457038324654484,0.5820238498592893,0.408897820926439,0.24504664162741924,0.10556008266546878,0,-0.06828556374209023,-0.10164720692199704,-0.10668443324736704,-0.09229279162100884,-0.0676826118865924,-0.040770939188391156,-0.01719366607497128,0,0.010072521093743276,\
                     0.013950171901372979,0.013442938661666109,0.010539924532807445,0.006912782290973393,0.0036717082778625404,0.001343980906503044,0,-0.0005599450449479095,-0.0006299356259012779,-0.00047599901604884737,-0.0002782179944466215,-0.0001254132897686219,-0.00003940328671242334,-0.000006272327028117027]
    minside4      = [1,0.9677067397427601,0.8754735424031383,0.7363116111669247,0.5690387749427253,0.3947100931903589,0.2328726279464744,0.09846997346812622,0,-0.060828473848914016,-0.08807741082408858,-0.08963798222912361,-0.07495103916223587,-0.05294982732350461,-0.030621864426414024,-0.012354100121804074,0,0.006550750370351611,\
                     0.008581357979868063,0.007789505667884757,0.00572824890289049,0.0035077922683009735,0.001731217648211203,0.0005857853596332941,0,-0.0002050370640200731,-0.0002095361090755842,-0.00014308227339085642,-0.00007543851733140218,-0.000030927452169915216,-0.000009168350688844679,-0.00000158174014270345]
    flattop4      = [1,0.9633262343597194,0.859593850914732,0.7061738614429447,0.5274619393571068,0.3494083785508531,0.1941326535234994,0.07599859616307823,0,-0.03742790728859844,-0.045746423402100424,-0.03680885348596081,-0.021591047728118973,-0.007969308213425627,0.00010539639481656004,0.002167459237080162,0,-0.003812769923009659,\
                    -0.007053787251496119,-0.008498312606009256,-0.007982808809703638,-0.0060878619550795154,-0.003677603986271232,-0.0015053481284463162,0,0.0007565960905941711,0.0009239058962157,0.0007553677173860026,0.0004791071697109673,0.00023850930336092043,0.00008824527524187423,0.000021135402405053327]
    kaiser8       = [1,0.973784,0.897692,0.779078,0.629225,0.462012,0.29231,0.134312,0,-0.102037,-0.167326,-0.195688,-0.190881,-0.159791,-0.111303,-0.055016,0,0.046264,0.0786285,0.094631,0.0944555,0.080540,0.0569238,0.028458,0,-0.024290,-0.0414535,-0.050006,-0.0499464,-0.042553,-0.0300094,-0.014951,0,0.012629,\
                     0.0214054,0.025619,0.0253622,0.021395,0.0149254,0.007348,0,-0.006043,-0.0100898,-0.011883,-0.0115622,-0.009575,-0.00654779,-0.003156,0,0.002475,0.00402406,0.004606,0.00434445,0.003478,0.00229289,0.001061,0,-0.000757,-0.0011651,-0.001252,-0.00109846,-0.000808,-0.000481802,-0.000197]
    bohman8       = [1,0.973334,0.896071,0.77599,0.624897,0.457161,0.287989,0.131668,0,-0.098853,-0.161007,-0.186917,-0.180888,-0.150148,-0.103645,-0.050742,0,0.04179,0.0702274,0.083521,0.0823302,0.069284,0.0482961,0.023797,0,-0.019685,-0.0330319,-0.039145,-0.0383729,-0.032053,-0.0221387,-0.010789,0,\
                     0.008687,0.0143432,0.016696,0.0160458,0.013115,0.00884562,0.0042,0,-0.003187,-0.00508814,-0.005708,-0.00526944,-0.004121,-0.00264747,-0.001192,0,0.000798,0.00118257,0.001221,0.00102559,0.00072,0.000408479,0.000159,0,-0.000073,-0.0000834291,-0.000062,-0.000033957,-0.000013,-0.00000291302,0]
    parzen8       = [0.666667,0.648727,0.596804,0.51624,0.415088,0.303095,0.190509,0.086876,0,-0.064824,-0.105205,-0.121655,-0.117225,-0.096848,-0.0665116,-0.032382,0,0.026335,0.0439404,0.051856,0.0506892,0.042271,0.0291773,0.014224,0,-0.011489,-0.0190243,-0.022227,-0.0214634,-0.017647,-0.0119891,-0.005745,0,\
                     0.004475,0.00727292,0.008338,0.00789788,0.006366,0.00423604,0.001986,0,-0.001471,-0.00232189,-0.002577,-0.00235492,-0.001824,-0.00116114,-0.000518,0,0.000341,0.000502619,0.000515,0.000430408,0.000301,0.000169602,0.000066,0,-0.00003,-0.0000341078,-0.000025,-0.0000138158,-0.000005,-0.00000118185,0]

    function KernStr(string kernel, int nw, int nh, float bc_b, float bc_c, float p, bool pd, bool show) {

    resampler = Format( kernel == "nnedi3"       ?    "nnedi3resize({nw},{nh}"                               : \
                        kernel == "Bicubic"      ? "BicubicResize ({nw},{nh},b={bc_b},c={bc_c}"              : \
                        kernel == "Bilinear" || kernel == "Triangle" || kernel == "Bartlett"                 ? \
                                                   "BilinearResize({nw},{nh}"                                : \
                        kernel == "Nearest"  || kernel == "NearestNeighbour" || kernel == "NN"               ? \
                                                      "GaussResize({nw},{nh},p=100"                          : \
                        kernel == "Gauss"        ?    "GaussResize({nw},{nh},p={pd}?{p}:9"                   : \
                        kernel == "deep"         ?    "deep_resize({nw},{nh}"                                : \
                        kernel == "Average"  || kernel == "Box" || kernel == "Dirichlet" || kernel == "Area" || kernel == "Simple" ? \
                                                   """fmtc_resample({nw},{nh},kernel="box" """               : \
                        kernel == "Spline"       ? """fmtc_resample({nw},{nh},kernel="Spline",taps={pd}?int({p}):4""": \
                        kernel == "Spline100"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=5"""      : \
                        kernel == "Spline144"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=6"""      : \
                        kernel == "Spline196"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=7"""      : \
                        kernel == "Spline256"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=8"""      : \
                        kernel == "Wiener"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Wiener3)       """ : \
                        kernel == "Hann"         ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Hann4)         """ : \
                        kernel == "Hamming"      ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Hamming4)      """ : \
                        kernel == "Black-Harris" ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(BlackHarris4)  """ : \
                        kernel == "Black-Nuttall"? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(BlackNuttall4) """ : \
                        kernel == "Flat-Top"     ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(FlatTop4)      """ : \
                        kernel == "MinSide"      ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(MinSide4)      """ : \
                        kernel == "Ginseng"      ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Ginseng3)      """ : \
                        kernel == "Welch"        ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Welch3)        """ : \
                        kernel == "Cosine"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Cosine3)       """ : \
                        kernel == "Bessel"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(bessel3)       """ : \
                        kernel == "Parzen"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(parzen8)       """ : \
                        kernel == "Kaiser"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(kaiser8)       """ : \
                        kernel == "Bohman"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(bohman8)       """ : \
                        kernel == "Quadratic"    || kernel == "Quadric" || kernel == "Bell"                  ? \
                                                   """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=16,cnorm=true,center=true,impulse=ArraySym(quadratic15)  """ : \
                        kernel == "Nuttall"      || kernel == "BlackmanMinLobe"                              ? \
                                                   """fmtc_resample({nw},{nh},kernel="blackmanminlobe"    """: \
                        kernel == "SincLin"      || kernel == "SincLin2ResizeMT"                             ? \
                                                 "SincLin2ResizeMT({nw},{nh},range=1,taps={pd}?int({p}):15"  : \
                        kernel == "SinPow"      || kernel == "SinPowResizeMT"                                ? \
                                                 "SinPowResizeMT({nw},{nh},range=1,p={pd}?{p}:2.5"           : \
                        kernel == "SSIM"        || kernel == "ResizeShader"                                  ? \
                                                   """ResizeShader({nw},{nh},kernel="SSIM",b=0.1"""          : \
                        kernel == "SSIM2"                                                                    ? \
                                        """SSIM_downsample({nw},{nh},smooth=0.43,resample_args="-0.6,0.4" """: \
                        kernel == "Sinc"         ?     "SincResize({nw},{nh},taps={pd}?int({p}):4"           : \
                        kernel == "Blackman"     ?     "BlackmanResize({nw},{nh},taps={pd}?int({p}):6"       : \
                        kernel == "Lanczos"      ?     "LanczosResize({nw},{nh},taps={pd}?int({p}):4"        : \
                        kernel == "DPID"         ?     "DPID({nw},{nh},lambdaY=0.5"                          : \
                        kernel == "Jinc16"       ?     "JincResize({nw},{nh},tap=2"                          : \
                        kernel == "Jinc100"      ?     "JincResize({nw},{nh},tap=5"                          : \
                        kernel == "Jinc196"      ?     "JincResize({nw},{nh},tap=7"                          : \
                        kernel == "EWA"          || kernel == "Jinc"       || kernel == "ewa_lanczos"      || kernel == "LoBlur"  ? \
                                                       "JincResize({nw},{nh},tap={pd}?int({p}):3"            : \
                        kernel == "EWASharp"     || kernel == "JincSharp"  || kernel == "ewa_lanczossharp" || kernel == "LoJaggy" ? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.9812505644269356"  : \
                        kernel == "EWASharp2"    || kernel == "JincSharp2" || kernel == "ewa_lanczos2sharp"  ? \
                                                       "JincResize({nw},{nh},tap=2,blur=0.9549963639785485"  : \
                        kernel == "EWASharp4"    || kernel == "JincSharp4" || kernel == "ewa_lanczos4sharp"  ? \
                                                       "JincResize({nw},{nh},tap=4,blur=0.9885973386557245"  : \
                        kernel == "EWASharper"   || kernel == "JincSharper"|| kernel =="ewa_lanczosradius3"  ? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.9264075766146068"  : \
                        kernel == "EWASharper2"  || kernel == "JincSharper2"||kernel =="ewa_lanczosradius2"  ? \
                                                       "JincResize({nw},{nh},tap=2,blur=0.895603689740279282": \
                        kernel == "EWASharper4"  || kernel == "JincSharper4"||kernel =="ewa_lanczosradius4"  ? \
                                                       "JincResize({nw},{nh},tap=4,blur=0.943159799432847707": \
                        kernel == "EWASharpest"  || kernel == "JincSharpest"|| kernel =="ewa_lanczossharpest"? \
                                                       "JincResize({nw},{nh},tap=3,blur=0.88549061701764"    : \
                        kernel == "EWASoft"      || kernel == "JincSoft"   || kernel == "ewa_lanczossoft"    ? \
                                                       "JincResize({nw},{nh},tap=3,blur=1.015"               : \
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

                        # Exclusion of additional resize arguments
                        src_nul = kernel == "ResizeShader"    || kernel == "SSIM"   || kernel == "SSIM2"   || kernel == "DPID" || kernel == "nnedi3" || kernel == "deep" || kernel == "FSRCC" || kernel == "Krig" || kernel == "FCBI" || kernel == "SuperResXBR"
                        src_box = kernel == "Dirichlet"       || kernel == "Simple" || kernel == "Average" || kernel == "Box" || kernel == "Area" || kernel == "Spline100" || kernel == "Spline144" || kernel == "Spline" || kernel == "Spline196" || kernel == "Spline256" || \
                                  kernel == "Black-Harris"    || kernel == "Wiener" || kernel == "Hann"    || kernel == "Hamming" || kernel == "Black-Nuttall" || kernel == "Flat-Top" || kernel == "MinSide" || \
                                  kernel == "BlackmanMinLobe" || kernel == "Nuttall"|| kernel == "Welch"   || kernel == "Cosine" || kernel == "Ginseng" || kernel == "Quadratic" || kernel=="Quadric" || kernel=="Bell" || kernel == "Bessel" || kernel == "Parzen" || kernel == "Kaiser" || kernel == "Bohman"

                        # Retrieving taps for 'show'
                        if (show) {
                            resampler = TrimAll(resampler)
                            taps = FindStr(resampler, "SinPow")  > 0 ? MidStr(resampler,FindStr(resampler, "p=")+2)                                       : \
                                   FindStr(resampler, "impulse") > 0 ? MidStr(resampler,StrLen(resampler)-1,1)                                            : \
                                   FindStr(resampler, "tap")     > 0 ? FindStr(resampler, "Jinc") > 0 ? \
                                                                       kernel == "Jinc"               ? MidStr(resampler,FindStr(resampler, "tap=") +4)   : \
                                                                                                        MidStr(resampler,FindStr(resampler, "tap=") +4,1) : \
                                                                                                        MidStr(resampler,FindStr(resampler, "taps=")+5)   : "0"
                            taps = kernel == "Jinc16"    || kernel == "spline16"  ? "2"   : \
                                   kernel == "Jinc36"    || kernel == "spline36"  ? "3"   : \
                                   kernel == "Jinc64"    || kernel == "spline64"  ? "4"   : \
                                   kernel == "Jinc100"   || kernel == "spline100" ? "5"   : \
                                   kernel == "Jinc144"   || kernel == "spline144" ? "6"   : \
                                   kernel == "Jinc196"   || kernel == "spline196" ? "7"   : \
                                   kernel == "Jinc256"   || kernel == "spline256" ? "8"   : \
                                   kernel == "Quadratic" || kernel == "Bell" || kernel == "Quadric" ? "1.5" : taps

                        } else { taps = "0" }

                        [resampler, src_nul, src_box, Eval(taps)] }


    krny = KernStr(kernel  ,  nw,  nh, bc_b,  bc_c,  taps,  pd,  dg)  resampler   = krny[0]  src_nuly = krny[1]  src_boxy = krny[2]
    krnc = KernStr(kernel_c, cnw, cnh, bch_b, bch_c, tapsc, pdc, dg)  resampler_c = krnc[0]  src_nulc = krnc[1]  src_boxc = krnc[2]

    src_wh  = src_boxy ? Format(",sw={src_width},  sh={src_height}")  : Format(",src_width={src_width}, src_height={src_height}")
    src_whc = src_boxc ? Format(",sw={src_widthc}, sh={src_heightc}") : Format(",src_width={src_widthc},src_height={src_heightc}")
    fmtcb   = Format(".ConvertBits({bi},fulls={fs})")
    src_nr  = src_nuly ? ")" : src_boxy ? "" : Format(",src_left={src_left},src_top={src_top}"+src_wh+")")     # take into account cplace
    src_c   = src_nuly ? ")" : src_boxy ?      Format(",sx={src_left},sy={src_top}"+src_wh+")"+fmtcb) : src_nr # take into account cplace
    Ynr     = Format(".Repair(BicubicResize(Y,{nw},{nh},0,0"+src_nr+",1)")  # noring uses Hermite kernel. Check here if I need -1 for chroma

    cplace  = chroma_placement(w, h, nw, nh, cs_in, cs_out, i_fmt[0], o_fmt0, i_fmt[1], o_fmt1, cplace_in, cplace_out )


    cplaceY  = (src_nuly || src_boxy ? "" : ",src_left=" +string(src_left)+",src_top="+string(src_top) + src_wh ) + ")" + fmtcb
    point    = kernel_c=="Point" ? "+1.0" : ""
    c_point  = kernel_c=="Point" ? i_type4 ?  1.0 : i_type1 || i_type10 ? round( 1*4.0) : round( 1*2.0) : 0
    c_point  = c_point  *(float(cow)/cnw)  # chroma scaled
    src_leftc= i_type4 ?  src_leftc : i_type1 || i_type10 ? round( src_leftc*4.0) : round( src_leftc*2.0)
    src_leftc= src_leftc*(float(cow)/cnw)  # chroma scaled
    src_topc = i_type4 || i_type1 || i_type2  ? src_topc  : round( src_topc *2.0)
    src_topc = src_topc *(float(coh)/cnh)  # chroma scaled

    cplaceH  = (src_boxc ? ",sx=" : ",src_left=")+string(cplace[0]+src_leftc+c_point)
    cplaceV  = (src_boxc ? ",sy=" :  ",src_top=")+string(cplace[1]+src_topc)
    cplaceC  = (src_nulc ? ""     : (cplaceH + cplaceV + src_whc)) + ")" + fmtcb


    c_recon  = """threads = SI_LogicalCores()
                  cores   = SI_PhysicalCores()
                  refs    = isRGBo || isSpace || isScale ? true : !tv_in
                  c_cplace= chroma_placement(w*2, h*2, fcnw, fcnh, cs_in, cs_out, i_fmt[0], o_fmt0, i_fmt[1], o_fmt1, cplace_in, cplace_out )
                  ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), "auto", wref=1)
                  Luma    = ref.ConvertBits(8,dither=-1,fulls=refs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2,range=fs?1:2).ConvertBits(bi,fulls=fs)
                  Uu      =  Cb.ConvertBits(8,dither=-1,fulls=refs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2,range=fs?1:2)
                  Uu      =  Eval("Uu."+kernel_c+"resize(w*2,h*2,"+(kernel_c=="bicubic"?"b=bch_b,c=bch_c":"taps=tapsc")+")").ConvertBits(bi,fulls=refs)
                  Vu      =  Cr.ConvertBits(8,dither=-1,fulls=refs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2,range=fs?1:2)
                  Vu      =  Eval("Vu."+kernel_c+"resize(w*2,h*2,"+(kernel_c=="bicubic"?"b=bch_b,c=bch_c":"taps=tapsc")+")").ConvertBits(bi,fulls=refs)
                  Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc-0.5, src_top=c_cplace[1]+src_topc-0.5) # -0.5 to recenter image center shift from nnedi3()
                  Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, "auto", wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc-0.5, src_top=c_cplace[1]+src_topc-0.5)
                  Cb      = ex_LFR(Unew, Uu.BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc-0.5, src_top=c_cplace[1]+src_topc-0.5), LFR=fcnw/1.1)
                  Cr      = ex_LFR(Vnew, Vu.BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc-0.5, src_top=c_cplace[1]+src_topc-0.5), LFR=fcnw/1.1)"""



    # Only scaling (or change in range, or gamma, or chroma placement, or subpixel shift, or odd cropping)
    if (!isSpace && !isIllu && !isFrmt && !isJab || isy) {

        UVr = isRGBi ? 3 : 1
        space == "linear"  ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr)                                     : \
        space == "sigmoid" ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr).ex_contrast(-1.15,0,191,false,UVr)  : \
        space == "log"     ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr).ACEScct_f(UV=UVr)                   : \
                   isGamma ? moncurve_f(s_gam[0], s_gam[1], tv_in, false, UVr)                                     : last

        # 'SSIM' kernel requires YUV (3 planes). It changes colors so debug!
        if (isRGBi || FindStr(resampler,"ResizeShader")>0 ) {

            nomoir ? ex_blur((1. / rat) / 2., mode="gaussian") : last
            Ynr   = ReplaceStr(Ynr, "(Y,", "(")
            Eval("" + resampler + cplaceY + (noring ? Ynr : ""))

        } else {

            Y   = isy ? last  : ExtractY()
            Cb  = isy ? nop() : ExtractU()
            Cr  = isy ? nop() : ExtractV()

            if (!isy) {

                if (recon && !i_type4) {

                    Eval(ReplaceStr(c_recon, "fcn", "cn"))

                } else {

                    str  = (cnw==cow && cnh==coh) ? Format("PointResize({cnw},{cnh}") : resampler_c # if chroma is not scaled (or scaled down to original) then use point as its faster and lossless
                    Cb   = Eval("Cb." + str + cplaceC)
                    Cr   = Eval("Cr." + str + cplaceC)
                } }

            Ynr  = ReplaceStr(Ynr, "(Y,", "(")
            Y    = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y    = Eval("Y." + resampler + cplaceY + (noring ? Ynr : ""))


             isy ? Y : CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+i_fmt[1]+i_fmt[2])
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

            str  = ReplaceStr(ReplaceStr(resampler_c, "("+string(cnw), "("+string(fcnw)), ","+string(cnh), ","+string(fcnh))
            str  = (fcnw==cow && fcnh==coh) ? Format("PointResize({fcnw},{fcnh}") : str # if chroma is not scaled (or scaled down to original) then use point as its faster and lossless
            Cb   = Eval("Cb." + str + cplaceC)
            Cr   = Eval("Cr." + str + cplaceC)
            }


        if (isScale && (isRGBo || !isSpace && !isIllu)) {

            Y     = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y     = Eval("Y." + resampler + src_c + (noring ? Ynr : ""))
            Y     = space == "linear"                  ? Y.                                moncurve_r(t_gam[0], t_gam[1], false, !(isRGBo || !tv_out), 1) : \
                    space == "sigmoid"                 ? Y.ex_contrast(1.15,0,191,false,1).moncurve_r(t_gam[0], t_gam[1], false, !(isRGBo || !tv_out), 1) : \
                    space == "log"                     ? Y.ACEScct_r(UV=1).                moncurve_r(t_gam[0], t_gam[1], false, !(isRGBo || !tv_out), 1) : \
                                                         Y
            }


        if (!isRGBo && !isSpace && !isIllu) {

            CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt1+o_fmt[2])
            tv_in != tv_out ? space == "gamma" ? SMPTE_legal(tv_out,3,  3) : \
                              isScale          ? SMPTE_legal(tv_out,1,  3) : \
                             !isScale          ? SMPTE_legal(tv_out,UVr,3) : last : last
            }


        if (isRGBo || isSpace || isIllu) {

            if (i_fmt[0]=="YcCbcCrc" || cs_in == "2020CL") {

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

    }

    if (isSpace || isIllu || isGamma && isRGBi) {

        R = R.ConvertBits(32)    R = !isRGBi ? R.moncurve_f(s_gam[0], s_gam[1], false, false, 1) : R
        G = G.ConvertBits(32)    G = !isRGBi ? G.moncurve_f(s_gam[0], s_gam[1], false, false, 1) : G
        B = B.ConvertBits(32)    B = !isRGBi ? B.moncurve_f(s_gam[0], s_gam[1], false, false, 1) : B

        mata = RGB_to_XYZ (cs_in,  D_in,  LMS=LMS, list=true)
        matw = CAT        (D_in,   D_out, LMS=LMS, list=true)
        matb = XYZ_to_RGB (cs_out, D_out, LMS=LMS, list=true)
        mat  = MatrixDot(isIllu ? MatrixDot(mata, matw) : mata, matb)

        Ro = "x "+string(mat[0])+" * y "+string(mat[3])+" * + z "+string(mat[6])+" * +"
        Go = "x "+string(mat[1])+" * y "+string(mat[4])+" * + z "+string(mat[7])+" * +"
        Bo = "x "+string(mat[2])+" * y "+string(mat[5])+" * + z "+string(mat[8])+" * +"

        if (!isRGBo && (isSpace || isIllu)) {
        Ro = Expr(R, G, B, Ro, optSingleMode=true, clamp_float=true) # Implement gamut compression instead of clipping in the future
        Go = Expr(R, G, B, Go, optSingleMode=true, clamp_float=true)
        Bo = Expr(R, G, B, Bo, optSingleMode=true, clamp_float=true)
        R = Ro  G = Go  B = Bo
        } else if (isSpace || isIllu) { Expr(R, G, B, Ro, Go, Bo, Format=o_fmt[3]+o_fmt[2], optSingleMode=true, clamp_float=true).ConvertBits(bi,dither=bi==32?-1:1) }


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

        R = isSpace || isIllu || isGamma ? R.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && !isIllu && tv_in, false, 1) : R    R = R.ConvertBits(bi,dither=bi==32?-1:1)
        G = isSpace || isIllu || isGamma ? G.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && !isIllu && tv_in, false, 1) : G    G = G.ConvertBits(bi,dither=bi==32?-1:1)
        B = isSpace || isIllu || isGamma ? B.moncurve_r(t_gam[0], t_gam[1], isRGBi && !isSpace && !isIllu && tv_in, false, 1) : B    B = B.ConvertBits(bi,dither=bi==32?-1:1)

        if (o_fmt0=="YcCbcCrc" || cs_out == "2020CL") {

            YCbCr = RGB_to_YcCbcCrc( R, G, B, cs_out, coef_o, !(isSpace || isIllu || !tv_in), tv_out)

            Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]

            } else if (o_fmt0=="YCoCg") {

            } else if (o_fmt0=="YCoCgR") {

            } else if (o_fmt0=="YUVr") {

            } else if (o_fmt0=="OkLab") {

            } else if (o_fmt0=="HSV") {

            } else if (o_fmt0=="OPP") {

            } else if (o_fmt0=="ICtCp") {

            } else if (o_fmt0=="YCbCr") {

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

        str  = (cnw==cow && cnh==coh) ? Format("PointResize({cnw},{cnh}") : resampler_c # if chroma is not scaled (or scaled down to original) then use point as its faster and lossless
        Cb   = Eval("Cb." + str + cplaceC)
        Cr   = Eval("Cr." + str + cplaceC)

        if (isScale) {
            Y    = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y    = Eval("Y." + resampler + src_c + (noring ? Ynr : ""))

            Y    = space == "linear"  ? Y.                                moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1) : \
                   space == "sigmoid" ? Y.ex_contrast(1.15,0,191,false,1).moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1) : \
                   space == "log"     ? Y.ACEScct_r(UV=1).                moncurve_r(t_gam[0], t_gam[1], false, tv_out, 1) : \
                   tv_out             ? Y.SMPTE_legal(tv_out,3,1)                                                          : \
                                        Y
            }

        CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt1+o_fmt[2])

        } }

        # Frame Properties

        mat_i  = isRGBo ? 0 : cs_outFA[3]
        prim_i = cs_outFA[4]
        illu_i = D_outA[5]
        t_i    = EOTFi_i[6]

        isSpace || isFrmt ? propSet("_Matrix",      mat_i)         : last # Yes, again, hardcoding matrix for RGB to 0
        isSpace           ? propSet("_Primaries",  prim_i)         : last # Same here
        isIllu            ? propSet("_Illuminant", illu_i)         : last
        isGamma           ? propSet("_Transfer",      t_i)         : last
        tv_in != tv_out   ? propSet("_ColorRange",     tv_out?1:0) : last
        isChP             ? propSet("_ChromaLocation", cplace[4])  : last

        # Show panel
        if (dg) {

            # EOTF curve
            msize = min(nw,nh)
            sw  = nmod(nw/5.)   sh = sw
            plt = GradientLinear(last, zoom=1, positive=true, precision=4, smooth=true, tv_range=tv_in)
            plt = plt.moncurve_r(t_gam[0], t_gam[1], tv_in, tv_out, 1)
            plt = plt.HistoCurve(size=4,gradient=false).BicubicResize(sw,sh,-0.5,0.25).Subtitle("EOTF: "+EOTF,size=msize/40)
            plt = isRGBo ? plt.ConvertToPlanarRGB() : plt
            plt = Merge(PadBorders(plt,nw-sw,0,0,nh-sh))
            ex_merge(plt,BoxMask(nw-sw,nw,0,sh),UV=3)


            i_jab  = i_fmt[1]
            i_fmt  = i_fmt[0]
            o_jab  = o_fmt1
            o_fmt  = o_fmt0
            c_col  = cplace[0]   c_in = cplace[2]
            c_cot  = cplace[1]   c_ou = cplace[3]
            kernel = UCase(LeftStr(kernel,  1))+MidStr(kernel,  2) # Sentence Case
            kernelc= UCase(LeftStr(kernel_c,1))+MidStr(kernel_c,2) # Sentence Case
            y_cof  = (kernel   == "bicubic" ? string(bc_b, "%1.2f")+","+string(bc_c, "%1.2f") : krny[3] > 0 ? string(krny[3]) : "")  y_cof = y_cof == "" ? "" : (kernel   == "bicubic" ? "" : "     ")+"["+y_cof+"]"
            u_cof  = (kernel_c == "bicubic" ? string(bch_b,"%1.2f")+","+string(bch_c,"%1.2f") : krnc[3] > 0 ? string(krnc[3]) : "")  u_cof = u_cof == "" ? "" : (kernel_c == "bicubic" ? "" : "     ")+"["+u_cof+"]"
            tv_i   = tv_in  ? "Lim" : "Full"
            tv_o   = tv_out ? "Lim" : "Full"
            prp    = color_propGet (prim_i, illu_i, mat_i, t_i)
            cs_out = prp[2]
            D_out  = prp[3]
            EOTF   = prp[5]

            bg     = BoxMask(0,round(msize/1.55),0,round(msize/1.15),invert=true, tv_out=tv_out)
            ex_blend(bg,"multiply",opacity=0.5,tv_range=tv_out)

            Subtitle("ConvertFormat() 1.0 RC57",                size=msize/16,lsp=4,text_color=$00aef0,font="Segoe UI")
            Subtitle("\n\n SETTINGS:",                          size=msize/25,lsp=4)
            Subtitle(Format("\n\n\n\n\n "       \
                           +"width:\n "         \
                           +"height:\n "        \
                           +"model:\n "         \
                           +"OETFi/EOTFi:\n "   \
                           +"colorspace:\n "    \
                           +"D in/out:\n "      \
                           +"jab:\n "           \
                           +"range:\n "         \
                           +"cplacement:\n "    \
                           +"\n "               \
                           +"clocation x/y:\n " \
                           +"kernelY:\n "       \
                           +"kernelUV:\n "      \
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
                           +"{c_in} \n "        \
                           +"\n "               \
                           +string(c_col,"%1.3f")+" \n "\
                           +"{kernel} \n "      \
                           +"{kernelc} \n "     \
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
                           +"{c_ou} \n "        \
                           +"\n "               \
                           +string(c_cot,"%1.3f")+" \n "\
                           +y_cof+" \n "        \
                           +u_cof+" \n "),         x=msize/2.25,size=msize/25,lsp=4)
    } }








##########################################
###                                     ##
###      DATA RETRIEVAL FUNCTIONS       ##
###                                     ##
##########################################

# color_Fuzzy_Search: Input a Primaries, Standard Illuminant or Transfer string, and get a tuple array with standardized name -string- of it with its property ID -int-.
# format_Fuzzy_Search: Second pass of above. Will search for input model and Jab and their IDs and override primaries and matrix IDs based on model.
# color_propGet: Reads Model, Primaries, Matrix, Standard Illuminant and Transfer frame properties from input, or infer them.
#
# xxx_Fuzzy_Search family infers input/output properties from input string, while color_propGet() infers them directly from frame properties or clip characteristics.

# Matrix, Primaries, Standard Illuminant and Transfer strings fuzzy search. Input: string, Output: [string,string,string,ID,ID,ID,ID]
function color_Fuzzy_Search (string matrix) {

    matrix = UCase(matrix)
    matrixn =
\     (FindStr(matrix,"709" )>0 ) ? "709"
\   : (matrix == "HDTV"         ) ? "709"
\   : (matrix == "sRGB"         ) ? "sRGB"
\   : (matrix == "XYZ"          ) ? "XYZ"
\   : (matrix == "SDTV"         ) ? "170M"
\   : (FindStr(matrix, "274")>0 ) ? "170M"
\   : (FindStr(matrix, "170")>0 ) ? "170M"
\   : (FindStr(matrix, "601")>0 ) ? "170M"
\   : (FindStr(matrix, "525")>0 ) ? "170M"
\   : (matrix == "jpeg"         ) ? "170M"
\   : (matrix == "jpg"          ) ? "170M"
\   : (matrix == "NTSC"         ) ? "170M"
\   : (matrix == "SMPTE-C"      ) ? "170M"
\   : (matrix == "YPbPr"        ) ? "170M"
\   : (matrix == "YCC"          ) ? "709"
\   : (matrix == "YUV"          ) ? "709"
\   : (matrix == "sYCC"         ) ? "709"
\   : (matrix == "YCbCr"        ) ? "709"
\   : (FindStr(matrix,"NCL"  )>0) ? "2020NCL"
\   : (FindStr(matrix,"20-10")>0) ? "2020NCL"
\   : (FindStr(matrix,"CL"   )>0) ? "2020CL"
\   : (FindStr(matrix,"20-12")>0) ? "2020CL"
\   : (FindStr(matrix,"2020")>0 ) ? "2020NCL"
\   : (FindStr(matrix,"2084")>0 ) ? "2020CL"
\   : (FindStr(matrix,"2100")>0 ) ? "2020CL"
\   : (FindStr(matrix,"DOVI")>0 ) ? "2020DV5"
\   : (FindStr(matrix,"VISION")>0)? "2020DV5"
\   : (FindStr(matrix,"2085")>0 ) ? "YDzDx"
\   : (matrix == "AdobeWideGamut")? "AWG"
\   : (matrix == "AWG"          ) ? "AWG"
\   : (FindStr(matrix,"ADOBE")>0) ? "AdobeRGB"
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
\   : (FindStr(matrix,"APPLE")>0) ? "AppleRGB"
\   : (matrix == "OPP"          ) ? "OPP"
\   : (matrix == "OOO"          ) ? "OPP" : ""

# * ST2084 or ARIB STD-B67 is the name of the normative/paper not the transfer function (HLG)
    transfer =
\     (FindStr(matrix,"2084")>0 ) ? "PQ"
\   : (FindStr(matrix,"2100")>0 ) ? "PQ"
\   : (matrix == "PQ"           ) ? "PQ"
\   : (matrix == "Perceptual"   ) ? "PQ"
\   : (matrix == "2020DVp5"     ) ? "PQ"
\   : (matrix == "HLG"          ) ? "HLG"
\   : (FindStr(matrix,"ARIB")>0 ) ? "HLG"
\   : (FindStr(matrix,"B67" )>0 ) ? "HLG"
\   : (FindStr(matrix,"BBC" )>0 ) ? "HLG"
\   : (FindStr(matrix,"NHK" )>0 ) ? "HLG NHK"
\   : (matrix == "1886a"        ) ? "1886a"
\   : (FindStr(matrix,"1886")>0 ) ? "1886"
\   : (FindStr(matrix,"428" )>0 ) ? "DCIXYZ"
\   : (FindStr(matrix,"APPLE")>0) ? "AppleRGB"
\   : (matrix == "Camera"       ) ? "170M"
\   : (matrix == "2020CL"       ) ? "2020CL"
\   : (matrix == "2020NCL"      ) ? "2020NCL"
\   : (matrix == "709-Camera"   ) ? "170M"
\   : (matrix == "linear"       ) ? "linear"
\   : (matrixn== "170M"         ) ? "170M"
\   : (matrixn== "2020CL"       ) ? "PQ"
\   : (matrixn== "2020DV5"      ) ? "PQ"
\   : (matrixn== "2020NCL"      ) ? "1886"
\   : (matrixn== "240M"         ) ? "240M"
\   : (matrixn== "470BG"        ) ? "470BG"
\   : (matrixn== "470M"         ) ? "470M"
\   : (matrixn== "709"          ) ? "1886"
\   : (matrixn== "ACES2065"     ) ? "linear"
\   : (matrixn== "ACEScg"       ) ? "linear"
\   : (matrixn== "ACESCCt"      ) ? "ACESCCt"
\   : (matrixn== "AdobeRGB"     ) ? "AdobeRGB"
\   : (matrixn== "AWG"          ) ? "AdobeRGB"
\   : (matrixn== "DCI-P3"       ) ? "DCIXYZ"
\   : (matrixn== "Display-P3"   ) ? "sRGB"
\   : (matrixn== "OPP"          ) ? "sRGB"
\   : (matrixn== "sRGB"         ) ? "sRGB"
\   : (matrixn== "XYZ"          ) ? "linear"
\   : (matrixn== "YDzDx"        ) ? "PQ" : matrixn

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
\   : (matrix == "D93"           ) ? "D93"
\   : (matrix == "E"             ) ? "E"
\   : (matrix == "EE"            ) ? "E"
\   : (matrix == "Neutral"       ) ? "E"
\   : (matrix == "Equal"         ) ? "E"
\   : (matrix == "null"          ) ? "E"
\   : (matrixn== "170M"          ) ? "D65"
\   : (matrixn== "2020CL"        ) ? "D65"
\   : (matrixn== "2020DV5"       ) ? "D65"
\   : (matrixn== "2020NCL"       ) ? "D65"
\   : (matrixn== "240M"          ) ? "D65"
\   : (matrixn== "470BG"         ) ? "D65"
\   : (matrixn== "470M"          ) ? "C"
\   : (matrixn== "709"           ) ? "D65"
\   : (matrixn== "ACES2065"      ) ? "D60"
\   : (matrixn== "ACESCCt"       ) ? "D60"
\   : (matrixn== "ACEScg"        ) ? "D60"
\   : (matrixn== "AdobeRGB"      ) ? "D65"
\   : (matrixn== "AWG"           ) ? "D50"
\   : (matrixn== "DCI-P3"        ) ? "DCI"
\   : (matrixn== "Display-P3"    ) ? "D65"
\   : (matrixn== "OPP"           ) ? "D65"
\   : (matrixn== "sRGB"          ) ? "D65"
\   : (matrixn== "XYZ"           ) ? "E"
\   : (matrixn== "YDzDx"         ) ? "E" : matrixn

    # ID for _Matrix frame properties (BT.2380-2. Table 2.8)
    idm =
\     (matrixn == "XYZ"            ) ? 0
\   : (matrixn == "RGB"            ) ? 0
\   : (matrixn == "sRGB"           ) ? 1
\   : (matrixn == "709"            ) ? 1
\   : (matrixn == "470M"           ) ? 4
\   : (matrixn == "470BG"          ) ? 5
\   : (matrixn == "170M"           ) ? 6
\   : (matrixn == "240M"           ) ? 7
\   : (matrixn == "2020NCL"        ) ? 9
\   : (matrixn == "2020CL"         ) ? 10
\   : (matrixn == "2020"           ) ? 9
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
\     (matrixn == "2020CL"         ) ? 9
\   : (matrixn == "DCI-P3"         ) ? 11 : idm

    # ID for _Illuminant frame properties
    idi =
\     (illuminant == "D50"         ) ? 0
\   : (illuminant == "D55"         ) ? 1
\   : (illuminant == "D60"         ) ? 2
\   : (illuminant == "DCI"         ) ? 3
\   : (illuminant == "D65"         ) ? 4
\   : (illuminant == "C"           ) ? 5
\   : (illuminant == "D75"         ) ? 6
\   : (illuminant == "D93"         ) ? 7
\   : (illuminant == "E"           ) ? 8 : -1

    # ID for _Transfer frame properties (BT.2380-2. Table 2.7)
    idt =
\     (transfer == "1886a"         ) ? 0
\   : (transfer == "1886"          ) ? 1
\   : (transfer == "470M"          ) ? 4
\   : (transfer == "470BG"         ) ? 5
\   : (transfer == "170M"          ) ? 6
\   : (transfer == "709-Camera"    ) ? 6
\   : (transfer == "240M"          ) ? 7
\   : (transfer == "linear"        ) ? 8
\   : (transfer == "log100"        ) ? 9
\   : (transfer == "log316"        ) ? 10
\   : (transfer == "xvYCC"         ) ? 11
\   : (transfer == "1361"          ) ? 12
\   : (transfer == "sRGB"          ) ? 13
\   : (transfer == "2020NCL"       ) ? 14
\   : (transfer == "2020CL"        ) ? 15
\   : (transfer == "PQ"            ) ? 16
\   : (transfer == "DCIXYZ"        ) ? 17
\   : (transfer == "HLG"           ) ? 18
\   : (transfer == "HLG NHK"       ) ? 19
\   : (transfer == "AdobeRGB"      ) ? 20
\   : (transfer == "ACESCCt"       ) ? 21
\   : (transfer == "AppleRGB"      ) ? 22 : -1
# * DCIXYZ is defined in smpte428-1. It's XYZ space with DCI white point for cinema distribution in DCDM format

    [matrixn,illuminant,transfer,idm,ids,idi,idt] }


# Get frame properties or infer them from clip format. Useful to get initial Defaults.
# When input args in functions are undefined color_propGet() has prevalence over Color_fuzzy_search() and format_Fuzzy_Search()
function color_propGet (clip a, int "prim_i", int "illu_i", int "mat_i", int "t_i") {

    w        = width (a)
    h        = height(a)
    FR       = FrameRate(a)
    bi       = BitsPerComponent(a)
    isHD     = (w > 1099 || h >  599)
    isUHD    = (w > 2599 || h > 1499)

    fmt      = format_Fuzzy_Search(a, PixelType(a), bi)
    cm_i     = a.propNumElements("_Model")                                 > 0 ? propGetInt(a, "_Model")       : -1
    prim_i   = Defined(prim_i) ? prim_i : a.propNumElements("_Primaries")  > 0 ? propGetInt(a, "_Primaries")   :  2
    illu_i   = Defined(illu_i) ? illu_i : a.propNumElements("_Illuminant") > 0 ? propGetInt(a, "_Illuminant")  : -1
    mat_i    = Defined(mat_i)  ? mat_i  : a.propNumElements("_Matrix")     > 0 ? propGetInt(a, "_Matrix")      :  2
    t_i      = Defined(t_i)    ? t_i    : a.propNumElements("_Transfer")   > 0 ? propGetInt(a, "_Transfer")    :  2

    # Input Defaults
    cm_i     = cm_i   != -1 ? cm_i   : fmt[4]
    prim_i   = prim_i !=  2 ? prim_i : fmt[6] != -1 ? fmt[6] : isUHD ? 9 : isHD ? 1 : FR==25 ? 5 : 6
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

    tv_range  = propNumElements(a,"_ColorRange") > 0 ? propGetInt(a, "_ColorRange") == 1 : cm_id[1] == "YCbCr"

    # ID for _Primaries frame properties (BT.2380-2. Table 2.6)
    prim_i =
\     (prim_i == 1    ) ? "709"
\   : (prim_i == 4    ) ? "470M"
\   : (prim_i == 5    ) ? "470BG"
\   : (prim_i == 6    ) ? "170M"
\   : (prim_i == 7    ) ? "240M"
\   : (prim_i == 9    ) ? "2020"
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
\   : (mat_i == 1     ) ? "709"
\   : (mat_i == 4     ) ? "470M"
\   : (mat_i == 5     ) ? "470BG"
\   : (mat_i == 6     ) ? "170M"
\   : (mat_i == 7     ) ? "240M"
\   : (cm_i  == 8     ) ? "YCoCg"
\   : (mat_i == 9     ) ? "2020"
\   : (mat_i == 10    ) ? "2020CL"
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
\   : (illu_i == 8    ) ? "E"
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
\   : (t_i == 14      ) ? "2020NCL"
\   : (t_i == 15      ) ? "2020CL"
\   : (t_i == 16      ) ? "PQ"
\   : (t_i == 17      ) ? "DCIXYZ"
\   : (t_i == 18      ) ? "HLG"
\   : (t_i == 19      ) ? "HLG NHK"
\   : (t_i == 20      ) ? "AdobeRGB"
\   : (t_i == 21      ) ? "ACESCCt"
\   : (t_i == 22      ) ? "AppleRGB"
\   : Assert (false, "color_propGet: Unknown _Transfer ID.")
# * 1, 14, and 15 share the same function

    # model, packing, prims, illu, matrix, transfer, tv_range, bitdepth
    [cm_id[0],cm_id[1],prim_i,illu_i,mat_i,t_i,tv_range,bi] }



# Format (Model, Container/Packing, Jab and Bitepth) fuzzy search.
# Also outputs its model ID, and model based matrix and primaries IDs.
function format_Fuzzy_Search (clip c, string format, int bits) {

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

    # Store all opposing models in YUV format, otherwise (correlated) as RGB
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
\   :                           rgb ? ["RGB","RGB",1] : ["YCbCr","YUV",5]

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



# Bicubic kernels are very performant but tends to create 'blocking' in upscales compared to more advanced kernels
function bicubic_coeffs (string kernel) {

    # info: Keys Cubics family of filters are BC-splines that exactly reproduce affine gradients, those that satisfy 2C+B = 1 (along the dotted line in the Cubic filters diagram)
    # Examples are Mitchell-Netravali, Robidoux (and its flavours), Catmull-Rom, Cub-grange and Spline.
    # For downscaling you can follow a different formula: B+2C = 0 (Didée,ZoptiN)...
    # Although the next is sharper albeit more haloing (Zopti): 3B+2C = -1 , but neither will produce affine gradients.

    rb  = 12. /(19.  +9.*sqrt(2))    # 0.378216
    rc  = 113./(58.+216.*sqrt(2))    # 0.310892
    rsb = 6.  /(13.  +7.*sqrt(2))    # 0.262015
    rsc = 7.  /(2.  +12.*sqrt(2))    # 0.368993
    rbb =      (9   -3. *sqrt(2))/7. # 0.679623
    rbc =      (1   -        rbb)/2. # 0.160189

    # From blurrier to sharper
    c = [-2.,-2.]
    c = kernel == "Notch"             ? [1.5,-0.25]  : c
    c = kernel == "SoftCubic100"      ? [1.0,0.0]    : c # Also called Spline (same as GaussResize(p=21))
    c = kernel == "Robidoux Soft"     ? [rbb,rbc]    : c # BC-spline soft approximation to EWA affine scaling. Close to a 'Quadratic' kernel.
    c = kernel == "SoftCubic75"       ? [0.75,0.25]  : c
    c = kernel == "BilcubicD"         ? [1/3.,0.0]   : c # dw Bicubic practical match to Bilinear
    c = kernel == "BilcubicU"         ? [0.5, 0.2]   : c # up Bicubic practical match to Bilinear
    c = kernel == "Hermite"           ? [0.0,0.0]    : c # up,dw Canonical Bicubic approximation to Bilinear (a bit sharper than it)
    c = kernel == "Robidoux"          ? [rb,  rc]    : c # up,dw Derived from EWA considerations, the values that "minimize the maximum possible change in vertical or horizontal straight lines (Robidoux) or any image (RobidouxSharp) under no-op" while satisfying Keys Cubics (affine gradients)
    c = kernel == "Centroid"          ? [0.37,0.35]  : c # up Arithmetic mean of the satisfactory zone (by Dogway)
    c = kernel == "Mitchell-Netravali"? [1/3.,1/3.]  : c # up Canonical Bicubic (roughly equivalent to EWA Robidoux)
    c = kernel == "Robidoux Sharp"    ? [rsb,rsc]    : c
    c = kernel == "SoftCubic50"       ? [0.5,0.5]    : c
    c = kernel == "Catmule-Dog"       ? [0.1750,0.4125]:c# up Sharp while orthogonally furthest key cubic coefficients from Blocking and Ringing zones in Cubics diagram (between CatRom and RobiSharp) (by Dogway)
    c = kernel == "Cub-grange"        ? [0.0308,0.4846]:c# dw but also up. Bicubic approximation to Lagrange scaling (a bit sharper than it)
    c = kernel == "Catmull-Rom"       ? [0.0,0.5]    : c # Canonical sharp Bicubic (roughly equivalent to spline16resize() and EWA RobidouxSharp)
    c = kernel == "Didee"             ? [-0.5,0.25]  : c # dw Didée's downscaling sharp coefficients. More neutral in medium to low frequencies than Zopti. Good for intermediate resizings.
    c = kernel == "Zopti"             ? [-0.6,0.4]   : c # dw 2160p to 720p Zopti optimized (by Boulder) (beware, not neutral, adds some local contrast): https://forum.doom9.org/showthread.php?p=1865218#post1865218
    c = kernel == "ZoptiN"            ? [-0.6,0.3]   : c # dw Like Zopti but more neutral (better over/undershoot normalization). Good for final resizing.
    c = kernel == "ZoptiH"            ? [-0.83,0.14] : c # dw 1080 to half optimized (for 1080p and smaller clips)
    c = kernel == "Zopti720"          ? [-1.00,0.16] : c # dw 1080p to 720p (for upscaling it always optimized to Catmull-Rom, although I visually prefer Precise)
    c = kernel == "Zopti720U"         ? [-0.99,0.26] : c # dw 2160p to 720p. This is my optimization for going straight from UHD to 720p, but I still recommend going first "Zopti1080" to 1080p and then "SSIM2" to 720p.
    c = kernel == "Zopti1080"         ? [-0.99,0.06] : c # dw 2160p to 1080p. Suprisingly better than using "SSIM2". If you want to skip halos but retain the great texture rendition use deep_resize(1080,edge="Didee",flat="Zopti1080")
    c = kernel == "Precise"           ? [0.0,0.75]   : c # up Almost identical to spline36 but a bit more halo. Very good cheap upscaler
    c = kernel == "Sharp"             ? [0.0,1.0]    : c # dw Good alternative for dw. Less aliasing and sharper edges but softer textures
    c = kernel == "Hatch"             ? [0.0,-5.0]   : c

    # Aliases
  # c = kernel == "Spline"            ? [1.0,0.0]    : c # Commented as to not conflict with SplinexxResize kernel
    c = kernel == "SoftCubic"         ? [0.75,0.25]  : c
    c = kernel == "Precise Bicubic"   ? [0.0,0.75]   : c
    c = kernel == "Catrom"            ? [0.0,0.5]    : c
    c = kernel == "Catmull"           ? [0.0,0.5]    : c
    c = kernel == "Mitchell"          ? [1/3.,1/3.]  : c
    c = kernel == "Mitchel"           ? [1/3.,1/3.]  : c
    c = kernel == "RobiSoft"          ? [rbb,rbc]    : c
    c = kernel == "RobiSharp"         ? [rsb,rsc]    : c
    c = kernel == "Robi"              ? [rb,  rc]    : c
    c = kernel == "RobidouxSoft"      ? [rbb,rbc]    : c
    c = kernel == "RobidouxSharp"     ? [rsb,rsc]    : c
    c = kernel == "B-Spline"          ? [1.0,0.0]    : c
    c = kernel == "BSpline"           ? [1.0,0.0]    : c
    c = kernel == "BCSpline"          ? [0.5,0.5]    : c
    c = kernel == "BC-Spline"         ? [0.5,0.5]    : c
    c = kernel == "CSpline"           ? [0.0,1.0]    : c
    c = kernel == "C-Spline"          ? [0.0,1.0]    : c
    c = kernel == "Didée"             ? [-0.5,0.25]  : c
    c = kernel == "Dide"              ? [-0.5,0.25]  : c
    c = kernel == "lagrange"          ? [0.0308,0.4846] : c
    c = kernel == "cubgrange"         ? [0.0308,0.4846] : c

    c }


# chroma_placement() - helper function to output chroma location coefficient values.
# If you want to retrieve them use ConvertFormat(show=true)
#
# UHD standard chroma placement is top_left
# 422 standard chroma placement is left
# JPG standard chroma placement is center
# 444 and RGB chroma placement is obviously center (cosited)
#
function chroma_placement (int w, int h, int nw, int nh, string matrix_i, string matrix_o, string format_i, string format_o, string jab_i, string jab_o, string "cplace_in", string "cplace_out") {

    # Input Jab to chroma units
    a1 = Eval(MidStr(jab_i, 2, 1))
    b1 = Eval(MidStr(jab_i, 3, 1))
    iu = 1 - (a1 / 4.)               # source chroma units/pixels for U dimension in respect to luma units
    iv = max(iu,ceil(b1 / 4.))       # source chroma units/pixels for V dimension in respect to luma units

    # Output Jab to chroma units
    a2 = Eval(MidStr(jab_o, 2, 1))
    b2 = Eval(MidStr(jab_o, 3, 1))
    ou = 1 - (a2 / 4.)               # target chroma units/pixels for U dimension in respect to luma units
    ov = max(ou,ceil(b2 / 4.))       # target chroma units/pixels for V dimension in respect to luma units


    ryw =  w  / float(nw)            # source/target Y dimensions
    ryh =  h  / float(nh)
    rcw = (a1 / float(a2)) * ryw     # source/target U dimensions
    rch = (iv / float(ov)) * ryh     # source/target V dimensions


    tli = FindStr(matrix_i,    "2020")>0 || FindStr(matrix_i,   "2100")>0 || \
          FindStr(cplace_in,   "2020")>0 || FindStr(cplace_in,  "2100")>0 || \
          FindStr(format_i,"YcCbcCrc")>0 || FindStr(format_i,  "ICtCp")>0

    tlo = FindStr(matrix_o,    "2020")>0 || FindStr(matrix_o,   "2100")>0 || \
          FindStr(cplace_out,  "2020")>0 || FindStr(cplace_out, "2100")>0 || \
          FindStr(format_o,"YcCbcCrc")>0 || FindStr(format_o,  "ICtCp")>0

                  # source chroma placement defaults
    dplacei = tli                    ? "top_left"    : \
              jab_i == "420"         ? "left"        : \
              jab_i == "422"         ? "left"        : \
              jab_i == "411"         ? "center"      : \
              jab_i == "410"         ? "top_left"    : "left"

                  # out chroma placement defaults
    dplaceo = tlo                    ? "top_left"    : \
              jab_o == "420"         ? "left"        : \
              jab_o == "422"         ? "left"        : \
              jab_o == "411"         ? "center"      : \
              jab_o == "410"         ? "top_left"    : "left"

    cplacei = cplace_in =="" ? dplacei : Default (cplace_in,  dplacei)
    cplaceo = cplace_out=="" ? dplaceo : Default (cplace_out, dplaceo)


    # Extending with aliases (RGB or 44 hardcoded)
    fulli = FindStr(format_i,"RGB")>0 || jab_i == "444"
    fullo = FindStr(format_o,"RGB")>0 || jab_o == "444"

    # Aliases
    cplacei = fulli                     ? "center"   : \
              tli                       ? "top_left" : \
              cplacei == "DV"           ? "top_left" : \
              cplacei == "MPEG2"        ? "left"     : \
              cplacei == "MPEG1"        ? "center"   : \
              cplacei == "JPEG"         ? "center"   : \
              cplacei == "JPG"          ? "center"   : \
              cplacei == "l"            ? "left"     : \
              cplacei == "c"            ? "center"   : \
              cplacei == "tl"           ? "top_left" : \
              cplacei == "t"            ? "top"      : \
              cplacei == "bl"           ? "bottom_left": \
              cplacei == "b"            ? "bottom"   : cplacei

    cplaceo = fullo                     ? "center"   : \
              tlo                       ? "top_left" : \
              cplaceo == "DV"           ? "top_left" : \
              cplaceo == "MPEG2"        ? "left"     : \
              cplaceo == "MPEG1"        ? "center"   : \
              cplaceo == "JPEG"         ? "center"   : \
              cplaceo == "JPG"          ? "center"   : \
              cplaceo == "l"            ? "left"     : \
              cplaceo == "c"            ? "center"   : \
              cplaceo == "tl"           ? "top_left" : \
              cplaceo == "t"            ? "top"      : \
              cplaceo == "bl"           ? "bottom_left": \
              cplaceo == "b"            ? "bottom"   : cplaceo

    # In chroma units
    icloc  =  cplacei == "left"        ? [-iu,  0.0] : \
              cplacei == "center"      ? [ 0.0, 0.0] : \
              cplacei == "top_left"    ? [-iu,  -iv] : \
              cplacei == "top"         ? [ 0.0, -iv] : \
              cplacei == "bottom_left" ? [-iu,   iv] : \
              cplacei == "bottom"      ? [ 0.0,  iv] : \
              Assert (false, "chroma_placement: Unsupported input chroma placement mode.")

    # Out chroma units [third item is _ChromaLocation index for frameprops]
    ocloc  =  cplaceo == "left"        ? [-ou,  0.0, 0] : \
              cplaceo == "center"      ? [ 0.0, 0.0, 1] : \
              cplaceo == "top_left"    ? [-ou,  -ov, 2] : \
              cplaceo == "top"         ? [ 0.0, -ov, 3] : \
              cplaceo == "bottom_left" ? [-ou,   ov, 4] : \
              cplaceo == "bottom"      ? [ 0.0,  ov, 5] : \
              Assert (false, "chroma_placement: Unsupported output chroma placement mode.")

    [ocloc[0]*rcw-icloc[0],ocloc[1]*rch-icloc[1], cplacei, cplaceo, ocloc[2]] }




# NTSC and PAL YCbCr (170M and 470BG) share the same coefficients defined in (https://poynton.ca/PDFs/coloureq.pdf - 10.4),
# and derived from the old SMPTE 470M (NTSC 1953) standard. Exactly:
# kr: 0.298903070250081
# kg: 0.586619854659197
# kb: 0.114477075090722
# For context (Rec709):
# kr: 0.21264933049678802
# kg: 0.71516913175582890
# kb: 0.07218152284622192
function color_coef (string "prims", string "mat", string "illu") {

    primd      = Defined(prims)
    prims      = Default(prims,   "709")
    mat        = Default(mat,     prims)
    illu       = Default(illu,    "D65")

    mat_i =
\     (mat    == "sRGB"           ) ? 1
\   : (mat    == "709"            ) ? 1
\   : (mat    == "170M"           ) ? primd ? 2 : 0
\   : (mat    == "470M"           ) ? 0
\   : (mat    == "2020CL"         ) ? 5
\   : (mat    == "2020NCL"        ) ? 5
\   : (mat    == "AdobeRGB"       ) ? 6
\   : (mat    == "AWG"            ) ? 7
\   : (mat    == "Display-P3"     ) ? 8
\   : (mat    == "DCI-P3"         ) ? 9
\   : (mat    == "ACEScg"         ) ? 10
\   : (mat    == "ACESCCt"        ) ? 10
\   : (mat    == "ACES2065"       ) ? 11
\   : (mat    == "240M"           ) ? 3
\   : (mat    == "470BG"          ) ? primd ? 4 : 0 : 1
# * Deriving Rec709 matrix coefficients from its primaries is noted as BT.709-2, in contrast to older and slightly different BT.709-1

    mat_wp =
\     (mat    == "170M"           ) ? 1
\   : (mat    == "709"            ) ? 1
\   : (mat    == "DCI-P3"         ) ? 3
\   : (mat    == "ACES2065"       ) ? 4
\   : (mat    == "ACEScg"         ) ? 4
\   : (mat    == "AWG"            ) ? 2
\   :                                 1

    # The coordinates and CCT's are from CIE 1931 2 degree standard observer
    mat_wp =
\     (illu   == "D50"            ) ? 2
\   : (illu   == "D55"            ) ? 6
\   : (illu   == "D60"            ) ? 4
\   : (illu   == "DCI"            ) ? 3
\   : (illu   == "D65"            ) ? 1
\   : (illu   == "C"              ) ? 0
\   : (illu   == "E"              ) ? 5
\   : (illu   == "D75"            ) ? 7
\   : (illu   == "D93"            ) ? 8 : mat_wp
# * D93 is not a D standard illuminant. Here it is defined for CCT (correlated) to consumer's TV standard "9300K+27 MPCD". "9300K+8 MPCD" for master CRT corresponds to 0.2838, 0.2984

    # Hardcode constants for the Kr, Kg, Kb derivations
    mat_w =
\     (mat    == "170M"           ) ? 0
\   : (mat    == "470BG"          ) ? 0
\   : (mat    == "AWG"            ) ? 2 : mat_wp

    # These primaries are associated with their respective standard illuminants (aligned right below 'pw' and 'wp')
    # It's mandatory for them to do a chromatic adaptation to convert them to the new illuminant primaries. RGB_to_XYZ()/XYZ_to_RGB() does this automatically.
    #
    #                     NTSC 1953/YCbCr   ITU-R BT.709-6/sRGB ITU-R BT.601     Y’PbPr 601        PAL/SECAM         BT-2020/BT-2100      Adobe RGB (1998)  Adobe Wide Gamut   Display-P3/D65P3  DCI-P3            AP1                AP0                E (Neutral)    D55                D75                NTSC-J*        P22/NTSC-J (from https://bkict-ocw.knu.ac.kr/caster/file/lecture/5955F4002DC3E.pdf)
    #                     BT-470M/FCC       IEC 61966-2-1       SMPTE 170M       SMPTE 240M        BT-470BG          BT-2020/BT-2100      Adobe RGB (1998)  AWG                SMPTE RP 432-1    SMPTE RP 431-2    ACEScg/ACEScct     SMPTE ST 2065-1    XYZ            D55                D75                9300K+27 MPCD  9300K+27 MPCD  ProPhotoRGB      Sunlight        Overcast
    pr  = Select (mat_i,  [0.670,  0.330],  [0.640, 0.330],    [0.630,  0.340],  [0.630,  0.340],  [0.640,  0.330],  [0.70792, 0.29203],  [0.640,  0.330],  [0.73469,0.26531], [0.680,  0.320],  [0.680,  0.320],  [0.713,   0.293],  [0.7347,  0.2653], [1.0, 0.0] ,                                        [0.618, 0.350],[0.641, 0.327],[0.7347, 0.2653] )
    pg  = Select (mat_i,  [0.210,  0.710],  [0.300, 0.600],    [0.310,  0.595],  [0.310,  0.595],  [0.290,  0.600],  [0.17024, 0.79652],  [0.210,  0.710],  [0.11416,0.82621], [0.265,  0.690],  [0.265,  0.690],  [0.165,   0.830],  [0.0000,  1.0000], [0.0, 1.0] ,                                        [0.280, 0.605],[0.272, 0.591],[0.1596, 0.8404] )
    pb  = Select (mat_i,  [0.140,  0.080],  [0.150, 0.060],    [0.155,  0.070],  [0.155,  0.070],  [0.150,  0.060],  [0.13137, 0.04588],  [0.150,  0.060],  [0.15664,0.01770], [0.150,  0.060],  [0.150,  0.060],  [0.128,   0.044],  [0.0001, -0.0770], [0.0, 0.0] ,                                        [0.152, 0.063],[0.142, 0.052],[0.0366, 0.0001] )
    pw  = Select (mat_w,  [0.31006,0.31616],[0.312713, 0.329016],                                                                                           [0.34567,0.35850],                   [0.314,  0.351],  [0.32168,0.33767]                   , [1./3,1./3],  [0.33242, 0.34743],[0.29902, 0.31485],[0.281, 0.311]               ,[0.34567,0.35850], [0.3362,0.3502],[0.3134,0.3275])
    wp  = Select (mat_wp, [0.31006,0.31616],[0.312713, 0.329016],                                                                                           [0.34567,0.35850],                   [0.314,  0.351],  [0.32168,0.33767]                   , [1./3,1./3],  [0.33242, 0.34743],[0.29902, 0.31485],[0.281, 0.311]               ,[0.34567,0.35850], [0.3362,0.3502],[0.3134,0.3275])
    Kv  = Select (mat_wp,  6774.153        , 6503.519           ,                                                                                            5001.828        ,                    6302.797      ,   6000.07                            ,  5455.486  ,   5502.815         , 7506.288         , 8945.623                    , 5001.828        ,  5348.372      , 6477.494      )
  # Kv (Kelvin) are Correlated Color Temperatures (CCT) derived from 'CIE 1931 2º Degree Standard Observer' CMF with 'native' isotherms
  # *  A third set of primaries for Japanese NTSC (1987) simply uses 170M prims but with [0.2848, 0.2932] chromatic coordinates
  # *  BT.2035 defines D93 as 0.2831, 0.2971, but this is a simple straight CCT of 9300K not the illuminant used in standard consumer CRTs in Japan (actually 9300K+27 MPCD**)
  # ** MPCD -Minimum Perceptible Color Difference- refers to the deviation unit in respect to the temperature CCT. For example D65 can also be specified as 6700K + 18 MPCD or more correctly as 6504K + 4 MPCD.

    pr = [pr[0], pr[1], 1 - pr[0] - pr[1]]    pw = [pw[0], pw[1], 1 - pw[0] - pw[1]]
    pg = [pg[0], pg[1], 1 - pg[0] - pg[1]]    wp = [wp[0], wp[1], 1 - wp[0] - wp[1]]
    pb = [pb[0], pb[1], 1 - pb[0] - pb[1]]

    if (!primd) {
    det = pw[1] * Dot([pr[0],pg[0],pb[0]], Cross([pr[1],pg[1],pb[1]], [pr[2],pg[2],pb[2]]))
    kr  = pr[1] * Dot(pw, Cross(pg, pb)) / det
    kg  = pg[1] * Dot(pw, Cross(pb, pr)) / det
    kb  = pb[1] * Dot(pw, Cross(pr, pg)) / det
    } else { kr = 1 kg = 1 kb = 1 }

    [kr, kg, kb, wp[0], wp[1], wp[2], pr, pg, pb] }




# Typical production practices for SDTV transfer characteristics differ from those specified in ITU recommendations.
# While NTSC-525 and PAL-625 are defined with 170M and 470BG OETFs respectively nowadays 1886 is used as output transfer (inverse EOTF) (read note 3 on page 6 of REC-BT.601-7)
# You should be conscious of this and change according your requirements.

function moncurve_coef (string transfer) {

    # Normalized strings (601, 709, 2020, AWG and Display-P3 are redundant but kept for clarity)
    t_num =
\     (transfer == "sRGB"         ) ? 0
\   : (transfer == "Display-P3"   ) ? 0
\   : (transfer == "170M"         ) ? 1
\   : (transfer == "601"          ) ? 1
\   : (transfer == "709-Camera"   ) ? 1
\   : (transfer == "2020NCL"      ) ? 1
\   : (transfer == "2020CL"       ) ? 1
\   : (transfer == "2020"         ) ? 1
\   : (transfer == "240M"         ) ? 2
\   : (transfer == "470BG"        ) ? 3
\   : (transfer == "709"          ) ? 4
\   : (transfer == "1886"         ) ? 4
\   : (transfer == "AdobeRGB"     ) ? 5
\   : (transfer == "AWG"          ) ? 5
\   : (transfer == "DCIXYZ"       ) ? 6
\   : (transfer == "linear"       ) ? 7
\   : (transfer == "470M"         ) ? 8 : 4
#\  : (transfer == "1886a"        ) ? 9 : 4
#\  : (transfer == "xvYCC"        ) ? -1
#\  : (transfer == "PhotoCD"      ) ? -1 (same as xvYCC, a variant of '1' with negative fix)
#\  : (transfer == "PQ"           ) ? -1
#\  : (transfer == "HLG"          ) ? -1 : 4


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

    #                                                SMPTE-C    / BT-2020           Y’PbPr 601              PAL/SECAM                      Rec.709  AdobeRGB   DCI-P3      AP1/AP0   NTSC 1953/YCbCr  Apple TRC**
    #                       sRGB                     SMPTE 170M / BT-2020           SMPTE 240M              BT-470BG (historical)          BT-1886  AdobeRGB** DCI-P3/XYZ  ACES/LIN  BT-470M/FCC
    t_gamma = Select(t_num, 2.40                   , 1/0.45                       , 1/0.45                , 2.80                         , 2.40   , 563/256.,  2.60       , 1.0      , 2.2           , 461/256.   )
    t_alpha = Select(t_num, 0.055                  , 0.099296826809442940347282759, 0.1115                , 0.099296826809442940347282759, 0      , 0       ,  0          , 0        , 0             , 0          )
    t_beta  = Select(t_num, 0.00303993463977843    , 0.018053968510807807335869592, 0.02280681818181818182, 0.00410749063249639977       , 0      , 0       ,  0          , 0        , 0             , 0          )
    t_k0    = Select(t_num, 0.03928571428571428571 , 0.081242858298635133011413164, 0.09122727272727272727, 0.05516490378302385575       , 0      , 0       ,  0          , 0        , 0             , 0          )
    t_phi   = Select(t_num, 12.92321018078786109464, 4.5                          , 4.0                   , 13.43031761206876179575      , 4.5    , 0       ,  0          , 0        , 0             , 0          )
    p_approx= Select(t_num, 2.223333               , 1.946666                     , 1.920000              , 2.460000                     , 2.40   , 2.199219,  2.60       , 1.0      , 2.2           , 1.800781255)
  # *  Approximated matching power law gamma value
  # ** An hexadecimal rounded value of the ideal 2.2 or 1.8 power gamma. There's also the original piecewise function with a linear part in the shadows

    [t_gamma, t_alpha] }






##########################################
###                                     ##
###   LINEAR ALGEBRA HELPER FUNCTIONS   ##
###                                     ##
##########################################

function ExtractClip ( clip clp) {

    isY  (clp) ? [         clp,          clp,          clp ] : \
    isRGB(clp) ? [ExtractR(clp),ExtractG(clp),ExtractB(clp)] : \
                 [ExtractY(clp),ExtractU(clp),ExtractV(clp)] }

# Input should be in PC range and RGB or YUV (full chroma) packing format
function MatrixClip ( clip clp, float_array mat, bool "switch") {

    rgb  = isRGB(clp)
    px   = PixelType(clp)
    bi   = BitsPerComponent(clp)    bi32 = bi==32
    UVf  = !bi32 && !rgb ? "range_half - " : ""
    bi   =  bi32 ? "S" : string(bi)

    fmt  = Default(switch, !rgb) # force switching output packing format (YUV or RGB)
    CLPa = ExtractClip(clp)

    # clip · 3x3
    Expr(CLPa[0],CLPa[1],CLPa[2], "x "+string(mat[0])+" * y "+ UVf + string(mat[3])+" * + z "+ UVf + string(mat[6])+" * +", \
                                  "x "+string(mat[1])+" * y "+ UVf + string(mat[4])+" * + z "+ UVf + string(mat[7])+" * +", \
                                  "x "+string(mat[2])+" * y "+ UVf + string(mat[5])+" * + z "+ UVf + string(mat[8])+" * +", optSingleMode=true, format=fmt ? rgb ? "YUV444P"+bi : "RGBP"+bi : px, scale_inputs="none") }


function DotClip ( clip clp, float_array vec) {

    CLPa = ExtractClip(clp)

    # clip · 1x3
    DotClipA(CLPa, vec) }


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

    # 3x3 · 1x3
    } else if (ArraySize(mat2) == 3) {
        ar1 = Dot([mat1[0],mat1[1],mat1[2]],[mat2[0],mat2[1],mat2[2]])
        ar2 = Dot([mat1[3],mat1[4],mat1[5]],[mat2[0],mat2[1],mat2[2]])
        ar3 = Dot([mat1[6],mat1[7],mat1[8]],[mat2[0],mat2[1],mat2[2]])

       [ar1,ar2,ar3]

    # 3x3 · 3x3
    } else {
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


# 3x3 matrix invert (for pseudo matrix division -> A/B = A * B^-1)
function MatrixInvert (float_array mat) {

    col1 = [mat[0],mat[3],mat[6]]
    col2 = [mat[1],mat[4],mat[7]]
    col3 = [mat[2],mat[5],mat[8]]
    crs1 = Cross(col1, col2)
    crs2 = Cross(col2, col3)
    crs3 = Cross(col3, col1)
    Det  = Dot  (col1, crs2)

    ArrayOp(ArrayAppend(ArrayAppend(crs2,crs3),crs1), Det, "/") }


function MatrixTranspose (float_array mat) {

    asize = ArraySize(mat)
    sh    = sqrt(asize)
    dim   = int(sh)

    Assert(Frac(sh)==0.0, "MatrixTranspose: Matrix shape is not square")

    arr = []
    for (y = 0, dim-1, 1) {

        arr = ArrayAdd(arr, mat[y])

        for (x = 1, dim-1, 1) {
            arr = ArrayAdd(arr, mat[y + dim * x] )
      } }
    return arr }


# 3x3 matrix determinant
function Determinant (float_array mat) {

    col1 = [mat[0],mat[3],mat[6]]
    col2 = [mat[1],mat[4],mat[7]]
    col3 = [mat[2],mat[5],mat[8]]
    crs2 = Cross(col2, col3)
    Det  = Dot  (col1, crs2)

    Det }


# Convert a vector into a square matrix by filling with dups or zeroes
function Broadcast (float_array mat, string "mode", bool "fill", int "size") {

    asize = ArraySize(mat)

    md   = Default(mode, "vonKries") # Right, Bottom or von Kries (diagonal)
    fill = Default(fill,      false) # Broadcast with copies or set to null (zeroes)
    cast = Default(size,      asize) # Size of matrix in square root form (ie. 3 for a 3x3 matrix)

    arr  = []
    dim  = cast
    cast = cast*cast
    Assert(cast>=asize, "Broadcast: Matrix size cannot be reduced")

    if (!fill) {
    for (i = 1, cast-1, 1) {
        arr = i==1 ? [mat[0]] : arr
        arr = md=="Bottom" ? ArrayAdd(arr,i<     asize                  ? mat[i]                  : 0) : \
              md=="Right"  ? ArrayAdd(arr,i<(dim*asize) && i% dim   ==0 ? mat[min(i/dim,asize-1)] : 0) : \
                             ArrayAdd(arr,i<(dim*asize) && i%(dim+1)==0 ? mat[min(i/dim,asize-1)] : 0)

      } } else {

    for (i = 0, dim-1, 1) {
        arr = ArrayAppend(mat,arr)
        arr = i == dim-1 && md!="Bottom" ? MatrixTranspose(arr) : arr
    } }

    return arr }


# Inner Product (uT · v)
function Dot (float_array vec1, \
              float_array vec2) {
    # 1x3 · 1x3
    (vec1[0] * vec2[0]) + (vec1[1] * vec2[1]) + (vec1[2] * vec2[2]) }


function Cross (float_array vec1, \
                float_array vec2) {
    # 1x3 X 1x3
    cr1 = vec1[1] * vec2[2] - vec1[2] * vec2[1]
    cr2 = vec1[2] * vec2[0] - vec1[0] * vec2[2]
    cr3 = vec1[0] * vec2[1] - vec1[1] * vec2[0]

    [cr1, cr2, cr3] }
