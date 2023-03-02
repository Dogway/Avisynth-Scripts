###########################################################
###                                                      ##
###                                                      ##
###   Transforms Pack - Main v1.5         (02-03-2023)   ##
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
### All of them converge into ConvertFormat(). An accurate and simple to use
### All-In-One (AIO) filter, to scale, convert and transform colors.
###
### ConvertFormat() supports color space, color model, transfer function, color range,
### CAT, chroma placement and chroma subsampling conversions among other features
### like chroma reconstruction, 'no ring' scaling, luma space scaling, and no-moirée scaling.
###
### ConvertFormat() is the spiritual successor of LinearResizer()
### and is clearly inspired by cretindesalpes' fmtconv and avsresize's z_ConvertFormat().
### For a "no-fuss" high quality resizer you can use deep_resize() from ResizersPack.
###
###
### Dependencies: AviSynth+ 3.7.3+
###
### Main features (not available in other color management AVS+ solutions):
###     - Many more scaling kernels to choose from (~97 kernels)
###     - GPU support for all scalers
###     - Many more color model conversion functions
###     - Convert/Simulate/Compensate from any illuminant to any illuminant
###     - Color Space conversion with optional Gamut Compression
###     - Full coefficient derivations
###     - Ratio resize (ie. 0.5 to halve size instead of absolute dimensions)
###     - Relative resize (ie. 1920 to resize to 1920 width, keeping height ratio)
###     - Aliases and fuzzy search for any given string argument
###     - Preset support
###     - Scale spaces (ie. linear scaling, sigmoid scaling...)
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

    img        = FrameCount(clp) < 2
    rgb        = isRGB(clp)
    propIDs    = color_propGet(clp)
    bi         =  propIDs[7]
    fs         = !propIDs[6]

    LUT        = Default (profile, Undefined()) # Display profile LUT (the path string of your monitor .cube 3D LUT, if calibrated)
    gamut      = Default (gamut, true)          # convert gamut
    gamma      = Default (gamma, true)          # convert gamma
    source     = Default (source, img ? "jpg" : propIDs[2])       # Source Color Space
    disp_ref   = Default (disp_ref,Defined(LUT) ? "709" : "sRGB") # Display Referred Color Space: sRGB for typical uncalibrated monitor, 709 (with 1886 transfer) for calibrated monitors or SmartTVs
    kernel     = Default (kernel,  "Precise")
    tv         = Default (tv_range,     !fs )
    LMS        = Default (LMS,       "CAT16")
    b          = Default (b, 0.00)              # Bicubic's 'b' arg or 'taps' for sinc kernels
    c          = Default (c, 0.75)              # Precise Bicubic
    p          = Default (p, 0.25)

    Assert(IsVersionOrGreater(3,7,3), "Display_Referred: Update AviSynth+ version")

    clp.ConvertBits(32, fulls=fs)

    src   = color_Fuzzy_Search (source)
    tgt   = color_Fuzzy_Search (disp_ref)
    src   = src[0]=="709" || src[0]=="170M" && !img || src[0]=="240M" || src[0]=="Display-P3" || \
            FindStr(src[0], "470")>0 && !img || FindStr(src[0],"2020")>0 ? [src[0],src[1],"1886"] : [src[0],src[1],img?"sRGB":src[2]]
    tgt   = tgt[0]=="709" || tgt[0]=="170M"         || tgt[0]=="240M" || tgt[0]=="Display-P3" || \
            FindStr(tgt[0], "470")>0         || FindStr(tgt[0],"2020")>0 ? [tgt[0],tgt[1],"1886"] : tgt
    gamut = !(src[0] == tgt[0] || !gamut)

    rgb ? ConvertToPlanarRGB(src[0])                               : \
          YUV_to_RGB(src[0], tv_in=tv, kernel=kernel, b=b, c=c, p=p)

    CCTF(src[2], true, false, false)

    if (gamut) {
    mata = RGB_to_XYZ (src[0], src[1], LMS=LMS, list=true, adaptXYZ=false)
    matw = CAT        (src[1], tgt[1], LMS=LMS, list=true)
    matb = XYZ_to_RGB (tgt[0], tgt[1], LMS=LMS, list=true, adaptXYZ=false)
    MatrixClip(MatrixDot(src[1]!=tgt[1] ? MatrixDot(mata, MatrixTranspose(matw)) : mata, matb) ) }

    Defined(LUT) || gamma ? CCTF(tgt[2], false, false, false) : \
                    gamut ? CCTF(src[2], false, false, false) : last

    Defined(LUT) ? ConvertBits(16, dither=-1, fulls=true)     : last
    Defined(LUT) ? Cube(LUT, 3, true)                         : last

    ConvertBits(8, dither=1, fulls=true) }



# Matches 'a' to 'b' clip format (size, length, color model, range, Jab, bitdepth) *Interlacing not supported
function MatchClip (clip a, clip b, string "kernel", string "matrix", bool "size", bool "props", bool "length", bool "Internal") {

    fst    = Default (Internal,    false) # Set to true to use internal ConvertTo... filters instead of ConvertFormat(). Might be slower though.
    fp     = Default (props,        true) # Assign frame properties
    sz     = Default (size,         true) # Match dimensions
    mfc    = Default (length,      false) # Match also framecount
    krn    = Default (kernel,   "CatRom")

    Assert(IsVersionOrGreater(3,7,3), "MatchClip: Update AviSynth+ version")

    propIDs= color_propGet(b)

    YUY2   = b.IsYUY2()
    rgbb   = b.isRGB()             rgba    = a.isRGB()
    isyb   = b.isY()               isya    = a.isY()
    w      = b.width()             wa      = a.width()
    h      = b.height()            ha      = a.height()
    alpha  = b.HasAlpha()          alphaa  = a.HasAlpha()
    fc     = b.FrameCount()        fca     = a.FrameCount()
    p_type = b.PixelType()         p_typea = a.PixelType()
    bib    = propIDs[7]            bia     = a.BitsPerComponent()


    fs     = propNumElements(a,"_ColorRange")  > 0 ? \
             propGetInt     (a,"_ColorRange") == 0 : rgba

    fd     = !propIDs[6]

    isHDa  = (wa > 1099 || ha > 599 )
    isUHD  = (w  > 2599 || h  > 1499)
    isUHDa = (wa > 2599 || ha > 1499)

    mat    = Default(matrix, propIDs[2])

        a
        yv411  = b.isYV411()      yv411a = a.isYV411()
        yv444  = b.is444()        yv444a = a.is444()
        !yv411 && bib > bia ? ConvertBits(bib, fulls=fs, fulld=fs) : last
        rat    = min(w/float(wa),h/float(ha))
        rgbp   = rgbb && b.isPlanar()
        mod    = rgba && rgbb || isya && isyb || yv444 && yv444a ? 1 : 2
        isScl  = (w != wa || h != ha) && sz

        fmt    = format_Fuzzy_Search(b, p_type,  bib)
        fmta   = format_Fuzzy_Search(a, p_typea, bia)
        krnc   = Eval(fmta[1])>Eval(fmt[1]) ? "Didee" : krn

    if (!fst) {

        ConvertFormat(isScl ? rat : 1, fmt_in=p_typea, fmt_out=p_type, cs_in=mat, cs_out="", kernel=krn, kernel_c=krnc, tv_in=!fs, tv_out=!fd)
        isScl ? PadResize(w, h, mode="dilate", mod=mod) : last
        alpha ? AddAlphaPlane(b)                        : last

    } else {

        # Match dimensions
        isScl ? RatioResize(rat,  mode="%",kernel=w>wa?krn:"Didee",mod=mod) : last
        isScl ? PadResize  (w, h, mode="dilate",      mod=mod)              : last

        cplace  = rgbb || yv444  || yv411  ? "MPEG1" : isUHD  ? "top_left"  : "MPEG2"
        cplacea = rgba || yv444a || yv411a ? "MPEG1" : isUHDa ? "top_left"  : "MPEG2"

        mat     = mat+(fd!=fs?":l":":f")
        bc      = bicubic_coeffs(krnc) # Hardcode 'Didee' when downscaling chroma
        krn     = bc[0]>=-2 ? "Bicubic" : krn

        not42   = LeftStr(fmta[1],2) != "42"

        # ConvertBackToYUY2 bug: https://forum.doom9.org/showthread.php?p=1038027
        isyb   ? rgba ? isUHDa ? DotClip([0.262372,0.678464,0.059164]) : /* Assumes Rec2020 for UHD */
                      \  isHDa ? DotClip([0.212600,0.715179,0.072221]) : /* Assumes Rec709  for  HD */
                      \          DotClip([0.298912,0.586603,0.114485]) : ConvertToY(mat)                                                                                : \
        rgbb   ? rgbp ? Eval(  "ConvertToPlanarRGB            (mat,interlaced=false"+(yv411a || rgba ? ")" : ",ChromaInPlacement=cplacea,       chromaresample=krn,param1=bc[0],param2=bc[1])")) : \
                        Eval(  "ConvertTo"   +string(fmt[3])+"(mat,interlaced=false"+(yv411a || rgba ? ")" : ",ChromaInPlacement=cplacea,       chromaresample=krn,param1=bc[0],param2=bc[1])")) : \
        yv411         ? Eval(  "ConvertToYV411                (false,mat,"          +(not42 ? ""   :        """ChromaInPlacement=cplacea, """)+"chromaresample=krn,param1=bc[0],param2=bc[1])")  : \
        YUY2  && rgba ? Eval("""ConvertBackToYUY2             (      mat                                                                                        """)    : \
                        Eval(  "ConvertToYUV"+string(fmt[1])+"(false,mat"           +(not42 ? ""   :         ",ChromaInPlacement=cplacea")+(yv444 ? ")" : ",chromaresample=krn,param1=bc[0],param2=bc[1], ChromaOutPlacement=cplace)"))
    }

    clr = !rgbb ? fd  ? $008080 : $108080 : \
                  fd  ? $000000 : $101010

    Und = bia > bib   ? Undefined() : 1
    isyb || !yv411    ? ConvertBits(bib, dither=Und, fulls=isyb?fs:fd, fulld=fd) : last

    alpha             ? AddAlphaPlane(b)                                         : last
    mfc  ? fca > fc   ? Trim(last, 0, fc==1 ? -1 : fc-1)                         : \
                        last+BlankClip(a,fc-fca,color_yuv=clr,pixel_type=p_type,width=sz?w:wa,height=sz?h:ha) : last

    # Planar to Interleaved
    YUY2 && !rgba     ? ConvertToYUY2()  : last

    # Frame Properties
    if (fst && fp) {
                propCopy(b,true,props=["_Matrix","_Primaries"],exclude=true)
    fd !=  fs ? propSet("_ColorRange", fd ? 0 : 1) : last # Overrides the ConvertTo... props
                } }





###
### ConvertFormat()
###
### Dependencies: AviSynth+ 3.7.3 and over
###               ExTools
###               GradePack    (for show=true or 'sigmoid' scaling)
###               MasksPack    (for show=true)
###               ResizersPack (for show=true or UVRecon=true or NN scalers)
###               KNLMeansCL   (for UVRecon=true)
###               nnedi3(CL)   (for UVRecon=true)
###               Optional resizer plugins (check links)
###
### Example 1 - Limited YUV to full RGB:
###     ConvertBits(10,fulls=false)       # RGB conversion from YUV requires at least 10-bit precision, but fairly enough for transfer/color space conversion tasks I wouldn't go any lower than 16-bit, unless you are curious on low bitdepth side-effects.
###     ConvertFormat(1,1,"YUV","RGB")
###
### Example 2 - Downscale HD Rec.709 YUV to SD 170M YUV:
###     ConvertFormat(720,kernel="SSIM2") # Undefined or 0 stands for automatic size given width/height ratio
###     or
###     ConvertFormat(preset="DVD-NTSC")  # Work-in-Progress
###
### Example 3 - YUV420 to YUV444 and scale up by 2 in sigmoid space with chroma reconstruction and noring (cs_out to "" or "none" to skip color space autoconversion):
###     ConvertFormat(2,fmt_out="44",cs_out="",kernel="FSRCNN",scale_space="sigmoid",noring=true,UVRecon=true,cplace_in="MPEG2")
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
### Example 7: High quality JPEG decoding and conversion to RGB (sRGB primaries)
###   MP_Pipeline("""
###   ### platform: win32
###   JPEGSource("source.jpg",rec=3)
###   ### ###
###   """)
###   ConvertBits(16)
###   Implicit:
###       ConvertFormat(1,1,"YUV","RGB","jpeg","sRGB",UVRecon=true) # 'jpeg' as an alias for '170M'
###   Explicit:
###       ConvertFormat(1,1,"YUV","RGB",cs_in="170M",cs_out="sRGB",tv_in=false,tv_out=false,cplace_in="MPEG1",UVRecon=true)
###   fmtc_bitdepth(bits=8, dmode=7) # Ostromoukhov error diffusion
###
### Example 8: Another JPEG conversion to RGB while keeping primaries
###   ConvertFormat(1,1,"YUV","RGB","470BG") # In this case the jpeg was 470BG encoded
###
###
### Function Definition:
###     (
###     clip,
###     float width=1.0 (0.1 to 1920.0),
###     float height=1.0 (0.1 to 1080.0),
###     [string preset="" (""/ "none"/ "DoVi/DVp5/DVp7"/ "PQ10/UHD"/ "HLG10"/ "HD"/ "DVD-NTSC"/ "DVD-PAL"/ "DV"/ "CRT-NTSC"/ "CRT-PAL"/ "Master"/ "Archival"/ "Grade"/ "Theater"/ "JPEGXL"/ "JPEG2000"/ "JPG_old"/ "JPG")],
###     [string "fmt_in"=""  (""/ "YCbCr411"/ "YCbCr420"/ "YCbCr422"/ "YCbCr444"/ "YcCbcCrc"/ "YUVr"/ "YCoCg"/ "YCoCgR"/ "RGB"/ "HSV"/ "OPP"/ "XYZ"/ "Yxy"/ "YDzDx"/ "Duv"/ "CIELab"/ "CIELuv"/ "IPT"/ "Oklab")],
###     [string "fmt_out"="" (""/ "YCbCr411"/ "YCbCr420"/ "YCbCr422"/ "YCbCr444"/ "YcCbcCrc"/ "YUVr"/ "YCoCg"/ "YCoCgR"/ "RGB"/ "HSV"/ "OPP"/ "XYZ"/ "Yxy"/ "YDzDx"/ "Duv"/ "CIELab"/ "CIELuv"/ "IPT"/ "Oklab")],
###     [string "cs_in"=""  (""/ "709"/ "470M"/ "470BG"/ "170M"/ "NTSC-J"/ "240M"/ "2020NCL"/ "2020CL"/ "XYZ"/ "DCI-P3"/ "Display-P3"/ "ACEScg"/ "ACES2065"/ "ACESCCt"/ "AdobeRGB"/ "AWG"/ "WideGamut"/ "AppleRGB"/ "ProPhoto"/ "AllColorsRGB"/ "MaxRGB"/ "xTremeRGB"/ "ColorMatch"/ "BruceRGB"/ "DonRGB4"/ "BestRGB"/ "BetaRGB"/ "RussellRGB"/ "ECI-RGB"/ "EktaSpacePS5"/ "ChromeSpace100"/ "CIE RGB")],
###     [string "cs_out"="" (""/ "709"/ "470M"/ "470BG"/ "170M"/ "NTSC-J"/ "240M"/ "2020NCL"/ "2020CL"/ "XYZ"/ "DCI-P3"/ "Display-P3"/ "ACEScg"/ "ACES2065"/ "ACESCCt"/ "AdobeRGB"/ "AWG"/ "WideGamut"/ "AppleRGB"/ "ProPhoto"/ "AllColorsRGB"/ "MaxRGB"/ "xTremeRGB"/ "ColorMatch"/ "BruceRGB"/ "DonRGB4"/ "BestRGB"/ "BetaRGB"/ "RussellRGB"/ "ECI-RGB"/ "EktaSpacePS5"/ "ChromeSpace100"/ "CIE RGB")],
###     [string "OETF" ="" (""/ "linear"/ "1886a"/ "1886"/ "470M"/ "470BG"/ "240M"/ ""170M"/ 709-Camera"/ "sRGB"/ "AdobeRGB"/ "CIELab"/ "Apple"/ "Chrome"/ "xvYCC"/ "PhotoCD"/ "2020NCL"/ "2020CL"/ "DCIXYZ"/ "PQ"/ "HLG"/ "HLG ARIB"/ "ACESCCt"/ "log100"/ "log316"/ "1361")],
###     [string "OETFi"="" (""/ "linear"/ "1886a"/ "1886"/ "470M"/ "470BG"/ "240M"/ ""170M"/ 709-Camera"/ "sRGB"/ "AdobeRGB"/ "CIELab"/ "Apple"/ "Chrome"/ "xvYCC"/ "PhotoCD"/ "2020NCL"/ "2020CL"/ "DCIXYZ"/ "PQ"/ "HLG"/ "HLG ARIB"/ "ACESCCt"/ "log100"/ "log316"/ "1361")],
###     [string "EOTFi"="" (""/ "linear"/ "1886a"/ "1886"/ "470M"/ "470BG"/ "240M"/ ""170M"/ 709-Camera"/ "sRGB"/ "AdobeRGB"/ "CIELab"/ "Apple"/ "Chrome"/ "xvYCC"/ "PhotoCD"/ "2020NCL"/ "2020CL"/ "DCIXYZ"/ "PQ"/ "HLG"/ "HLG ARIB"/ "ACESCCt"/ "log100"/ "log316"/ "1361")],
###     [string "D_in"=""  (""/ "A"/ "B"/ "D50"/ "E"/ "D55"/ "ACES"/ "D60"/ "DCI"/ "D65"/ "C"/ "D75"/ "D93"/ "ID50"/ "ID65"/ "Sunlight"/ "Overcast")],
###     [string "D_out"="" (""/ "A"/ "B"/ "D50"/ "E"/ "D55"/ "ACES"/ "D60"/ "DCI"/ "D65"/ "C"/ "D75"/ "D93"/ "ID50"/ "ID65"/ "Sunlight"/ "Overcast")],
###     [string "cplace_in"=""  (""/ "center"/ "left"/ "top_left"/ "top"/ "bottom_left"/ "bottom")],
###     [string "cplace_out"="" (""/ "center"/ "left"/ "top_left"/ "top"/ "bottom_left"/ "bottom")],
###     [string "CAT"="CAT" ("CAT"/ "Simulation"/ "Compensation")],
###     [bool "tv_in"=true],
###     [bool "tv_out"=true],
###     [string "scale_space"="gamma" ("gamma"/ "linear"/ "sigmoid"/ "log")],
###     [string "kernel"="spline36"   ("nnedi3"/ "EEDI3"/ "deep"/ "FCBI"/ "SuperResXBR"/ "Waifu2x"/ "RAVU"/ "FSR1"/ "Krig"/ "FSRCNN"/ "DPID"/ "SSIM"/ "SSIM2"/ "--"/ "Point"/ "Nearest"/ "Box"/ "Bilinear"/ "Bicubic"/ "Quadratic"/ "Gauss"/ "--"/ "Wiener"/ "Spline"/ "Spline16"/ "Spline36"/ "Spline64"/ "Spline100"/ "Spline144"/ "Spline196"/ "Spline256"/ "--"/ "Jinc"/ "Jinc16"/ "Jinc36"/ "Jinc64"/ "Jinc100"/ "Jinc144"/ "Jinc196"/ "Jinc256"/ "EWASharp"/ "EWASharp2"/ "EWASharp4"/ "EWASharper"/ "EWASharper2"/ "EWASharper4"/ "EWASharpest"/ "EWASoft"/ "HaasnSoft"/ "Tukey"/ "--"/ "Sinc"/ "SincLin"/ "SinPow"/ "--"/ "Welch"/ "Cosine"/ "Bessel"/ "Wiener"/ "Hamming"/ "Hann"/ "EWA_Hann"/ "Kaiser"/ "Blackman"/ "Black-Harris"/ "Black-Nuttall"/ "Nuttall"/ "Bohman"/ "Parzen"/ "Lanczos"/ "EWA_Lanczos"/ "Ginseng"/ "EWA_Ginseng"/ "Flat-Top"/ "MinSide"/ "--"/ "Notch"/ "SoftCubic100"/ "Robidoux Soft"/ "SoftCubic75"/ "BilcubicD"/ "BilcubicU"/ "Hermite"/ "Robidoux"/ "EWA_Robidoux"/ "Centroid"/ "Mitchell-Netravali"/ "Robidoux Sharp"/ "EWA_RobidouxSharp"/ "SoftCubic50"/ "CatMule-Dog"/ "Cub-grange"/ "Catmull-Rom"/ "Didee"/ "Zopti"/ "ZoptiN"/ "ZoptiH"/ "Zopti720"/ "Zopti720U"/ "Zopti1080"/ "Precise"/ "Sharp"/ "Hatch")],
###     [string "kernel_c"="spline36" ("nnedi3"/ "EEDI3"/ "deep"/ "FCBI"/ "SuperResXBR"/ "Waifu2x"/ "RAVU"/ "FSR1"/ "Krig"/ "FSRCNN"/ "DPID"/ "SSIM"/ "SSIM2"/ "--"/ "Point"/ "Nearest"/ "Box"/ "Bilinear"/ "Bicubic"/ "Quadratic"/ "Gauss"/ "--"/ "Wiener"/ "Spline"/ "Spline16"/ "Spline36"/ "Spline64"/ "Spline100"/ "Spline144"/ "Spline196"/ "Spline256"/ "--"/ "Jinc"/ "Jinc16"/ "Jinc36"/ "Jinc64"/ "Jinc100"/ "Jinc144"/ "Jinc196"/ "Jinc256"/ "EWASharp"/ "EWASharp2"/ "EWASharp4"/ "EWASharper"/ "EWASharper2"/ "EWASharper4"/ "EWASharpest"/ "EWASoft"/ "HaasnSoft"/ "Tukey"/ "--"/ "Sinc"/ "SincLin"/ "SinPow"/ "--"/ "Welch"/ "Cosine"/ "Bessel"/ "Wiener"/ "Hamming"/ "Hann"/ "EWA_Hann"/ "Kaiser"/ "Blackman"/ "Black-Harris"/ "Black-Nuttall"/ "Nuttall"/ "Bohman"/ "Parzen"/ "Lanczos"/ "EWA_Lanczos"/ "Ginseng"/ "EWA_Ginseng"/ "Flat-Top"/ "MinSide"/ "--"/ "Notch"/ "SoftCubic100"/ "Robidoux Soft"/ "SoftCubic75"/ "BilcubicD"/ "BilcubicU"/ "Hermite"/ "Robidoux"/ "EWA_Robidoux"/ "Centroid"/ "Mitchell-Netravali"/ "Robidoux Sharp"/ "EWA_RobidouxSharp"/ "SoftCubic50"/ "CatMule-Dog"/ "Cub-grange"/ "Catmull-Rom"/ "Didee"/ "Zopti"/ "ZoptiN"/ "ZoptiH"/ "Zopti720"/ "Zopti720U"/ "Zopti1080"/ "Precise"/ "Sharp"/ "Hatch")],
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
# Jinc (EWA Lanczos)                          (up) https://github.com/Asd-g/AviSynth-JincResize/releases
# FCBI (Fast Curve Based Interp)              (up) https://github.com/Asd-g/AviSynth-FCBI
# SuperResXBR                                 (up) https://github.com/mysteryx93/AviSynthShader/releases
# AiUpscale/FSRCNN (FastSuperResolutionConvo) (up) https://github.com/Alexkral/AviSynthAiUpscale/tree/master/Shaders (lineart / photo folders), designed for clean sources and at least x1.42 upscaling
# Waifu2x                                     (up) https://github.com/Asd-g/AviSynthPlus-w2xncnnvk (best upscaler among the no-hallucination types)
# NNEDI3CL                                    (up) https://github.com/Asd-g/AviSynthPlus-NNEDI3CL
# RAVU (or gpuid>-1)                          (up) https://github.com/Asd-g/avslibplacebo
# KrigBilateral                               (up) https://github.com/Alexkral/AviSynthAiUpscale/tree/master/Shaders/KrigBilateral
# NoHalo                                           https://github.com/libvips/libvips/blob/master/libvips/resample/nohalo.cpp (NicolasRobidoux special up/downscalers)
# LoHalo                                           https://legacy.imagemagick.org/discourse-server/viewtopic.php?p=90433&sid=9b1885ea67cf86554709da0282c14796#p90433
# EWA_RobidouxSharp                                https://github.com/Asd-g/avslibplacebo

# Internal:
#
# Point    / Nearest             (actually slower than bicubic!)
# Bilinear / Triangular
# Bicubic  / Cubic               (not recommended for highly quantized content: JPEGs, H.264, etc)
# Spline   / Cubic Polynomials   (spline16 -2 lobes- spline36 -3 lobes- spline64 -4 lobes-)
# Sinc     is a box-windowed             sinc filter (Default 4 lobes).
# Lanczos  is a Lanczos or sinc-windowed sinc filter (Default 4 lobes).
# Blackman is a Blackman-windowed        sinc filter (Default 6 lobes). (Improved lanczos with less ringing)
# SincLin2Resize                 (up,dw) like a sharper lanczos or a -moderate- ring suppresed Sinc (Doom9 thread: https://forum.doom9.org/showthread.php?p=1919769)
# SinPowerResize                    (dw)                                                            (Doom9 thread: https://forum.doom9.org/showthread.php?p=1918124)

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
# ewa_hanning         is a Hanning-windowed  jinc filter (3.238 lobes).
# ewa_ginseng         is a sinc-windowed     jinc filter (3.238 lobes).
# ewa_lanczos         is a lanczos-windowed  jinc filter (3.238 lobes). Under same circumstances -in this case 'taps'- Jinc (radial) is always sharper than their Sinc (orthogonal) equivalent. Check ewa_lanczosradius3 below.
# ewa_lanczossharp    is a lanczos-windowed  jinc filter (3.238 lobes). Slightly sharpened as per calculations by Nicolas Robidoux, his preferred all-around scaler. Can be replicated with Jinc filter and blur = 0.9812505644269356
# ewa_lanczossharpest is a lanczos-windowed  jinc filter (3.238 lobes). Very sharp, technically not recommended by Nicolas Robidoux except when downscaling. Can be replicated with Jinc filter and blur = 0.88549061701764
# ewa_lanczos2sharp   is a lanczos-windowed  jinc filter (2.2331305943815286 lobes). Good alternative to the other EWAs when you don't want the moiree or "hash pattern blur" artifact, so use this for dithered content or RobiSharp.
# ewa_lanczosradius3  is a lanczos-windowed  jinc filter (3 lobes). More sharpened than ewa_lanczossharp and very similar to Ginseng tensor, good for up and downscale. Can be replicated with Jinc filter and blur = 0.9264075766146068 (scales lobes from 3.238 to 3)
# ewa_lanczos4        is a lanczos-windowed  jinc filter (4.2410628637960699 lobes).
# ewa_lanczossoft     is a lanczos-windowed  jinc filter (3.238 lobes). Softened instead. This one makes hash patterns disappear completely (blur determined by trial and error). Can be replicated with Jinc filter and blur = 1.015. https://github.com/mpv-player/mpv/blob/27c38eac1040cd781f39d977ce53adcd65ddcfb6/video/out/filter_kernels.c#L380
#-ewa_catrom
#-ewa_QuadraticJinc 3-taps
# Haasnsoft           is a Hanning-windowed  jinc filter (3.238 lobes). Removes almost all aliasing. Blur value to match orthogonal and diagonal contributions on a regular grid. Can be replicated with Jinc filter and blur = 1.11
# Tukey               is a Hanning-windowed  jinc filter taper = 0.5
# Quadratic/Quadric/Bell like Cubic but 66% faster (1.5 taps/lobes). Also known as 'Bell' -> https://clouard.users.greyc.fr/Pantheon/experiments/rescaling/index-en.html#bell
#  RAVU / RAISR       RAVU (Rapid and Accurate Video Upscaling) is a set of prescalers inspired by RAISR (Rapid and Accurate Image Super Resolution). Similar in quality to XBR and nnedi3. RAVU 4 Lite looks very much like spline36 though.
# -NGU                Next Generation Upscaler. madVR edge directed NN algo (closed source, similar to FSRCNN)
#  EASU               Edge Adaptive Spatial Upscaling (AMD's FSR 1.0) (up) (Uses a custom (McLaurin approx) 2-tap Lanczos in a single pass (EWA?), and clamped to nearest neighbour upscale to eliminate ringing) (https://gist.github.com/agyild/82219c545228d70c5604f865ce0b0ce5)
# -FSR2.1             AMD FidelityFX Super Resolution v2.1.1 (https://github.com/GPUOpen-Effects/FidelityFX-FSR2)
#  Waifu2x            Image Super-Resolution for Anime-style art (also includes a photo model) using Deep Convolutional Neural Networks running on Vulkan (uses the ncnn framework). Inspired by SRCNN (http://arxiv.org/abs/1501.00092)
# -Sphinx             Continuation of Sinc and Jinc, interpolating all three dimensions at the same time using a carefully constructed filter that has a perfectly spherical frequency response. 1.4302966531242027, sphinx window.
# -ICBI               (Iterative Curve Based Interpolation) is a single image superresolution technique described in Fast artifact-free image interpolation by Andrea Giachetti and Nicola Asuni, presented at BMVC 2008
#
#
# Understanding an end-to-end transfer function pipeline for a system:
#   _                                                                                                                                                                                                    _\/_
# [|_| OETF (Input Device) -> OETFi (Input transfer decode) -> OOTF* (Rendering Intent) -> EETF (HDR PQ Peak Luminance scaling) -> EOTFi (Display transfer encode) -> EOTF (Output Device, ie. Display) |    |
#  /|\                                                                                                                                                                                                  |____|
#
# * The OOTF can be implemented within the pipeline for a 1:1 scene referred output (assumes EOTFi transfer matches the inverse of EOTF)
#   or added directly in the EOTFi. Example: moncurve_r(1.2).moncurve_r(2.2) -> moncurve_r(1.2*2.2)
#


# * If you define the argument 'OETF' (also known as OECF) it will override 'EOTFi'
#
function ConvertFormat (clip clp, val "width", val       "height", string   "fmt_in", string       "fmt_out", string        "cs_in", string         "cs_out", string           "OETFi", string      "EOTFi", string "OETF",  \
                            string     "D_in", string     "D_out", bool      "tv_in", bool          "tv_out", string    "cplace_in", string     "cplace_out", string             "CAT", string        "LMS", bool     "GC",  \
                         string "scale_space", string    "kernel", string "kernel_c", float_array "src_left", float_array "src_top", float_array "src_width", float_array "src_height",                                      \
                           string    "preset", float_array "taps", int         "mod", bool        "nomoiree", bool         "noring", bool          "UVrecon", bool              "show", int       "threads", int   "cores", val "gpuid") {

    IsPackedRGB(clp) ? ConvertToPlanarRGB(clp) : clp

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
    RT         = isRunTime(clp,i_fmt[3]=="RGB")
    isyv       = !isy && !isRGBi
    fch        =  isy ||  isRGBo || o_fmt[1]=="444"
    lut1       = bi == 32 || RT ? 0 : 1
    lut2       = bi  > 12 || RT ? 0 : 2

    mod        = Default (mod, fch ? 1 : 2) # Rounding target size to mod. Powers of 2 ie: 1, 2, 4, 8, 16...

    Assert(isFloat(nw) || isFloat(nh), "ConvertFormat: Width/Height type not supported.") # isFloat(int) also returns true, so good for 'number' type evaluation
    nw         = isInt(nw) && nw<=10 ? float(nw) : isFloat(nw) && nw>10. ? int(nw) : nw
    nh         = isInt(nh) && nh<=10 ? float(nh) : isFloat(nh) && nh>10. ? int(nh) : nh
    nw         =  nw<=10. ? w*nw : nw            nw     = nmod(nw,mod)
    nh         =  nh<=10. ? h*nh : nh            nh     = nmod(nh,mod)

    nw         =  nw == 0 || wu ? nmod((w*(nh/float(h))),mod) : nw
    nh         =  nh == 0 || hu ? nmod((h*(nw/float(w))),mod) : nh

    isUHD      = ( w > 2599 || h > 1499)      isnUHD = (nw > 2599 || nh > 1499)
    isHD       = ( w > 1099 || h > 599 )      isnHD  = (nw > 1099 || nh > 599 )

    wr         = float(nw) / w                 hr     = float(nh) / h     # for nomoiree
    rat        = max(abs(wr - 1),abs(hr - 1)) == abs(wr - 1) ? wr : hr    # for nomoiree

    # DEFAULTS
    Und        = Undefined()
       cs_in_d = Defined (cs_in)
    cs_in      = cs_in_d  ? cs_in ==""  ? propIDs[2] : cs_in : fc ? "jpeg" : propIDs[2]
       cs_inFA = color_Fuzzy_Search (cs_in)
       cs_inF  = cs_inFA[0]
    cs_out     = Defined (cs_out) ? cs_out =="" ? cs_in : cs_out : cs_in_d ? cs_in : (cs_in == "jpeg" || cs_in == "jpg" || cs_inF == "sRGB") && isRGBo ? "sRGB" : isnUHD ? "2020NCL" : isnHD ? "709" : "170M"
      cs_outFA = color_Fuzzy_Search (cs_out)
      cs_outF  = cs_outFA[0]

    OETFd      = Defined(OETF)  ? OETF =="" ? false : true : false
    OETFid     = propIDs[5]!="linear" ? cs_inF =="709" || cs_inF =="170M" && !fc || cs_inF =="240M" || cs_inF =="Display-P3" || FindStr(cs_inF, "470")>0 && !fc || FindStr(cs_inF, "2020")>0 ? "1886" : fc ? "sRGB" : propIDs[5] : propIDs[5]
    OETFi      = Defined(OETFi) ? OETFi=="" ? OETFid : OETFi : OETFid # By default undoes encoded display referred transfer (1886 EOTFi) for consumer media instead of scene-referred camera transfer (OETFi)
    EOTFid     =                        cs_outF=="709" || cs_outF=="170M" && !fc || cs_outF=="240M" || cs_outF=="Display-P3" || FindStr(cs_outF,"470")>0 && !fc || FindStr(cs_outF,"2020")>0 ? "1886" : fc ? "sRGB" : cs_outF
    EOTFi      = OETFd ? OETF : Defined(EOTFi) ? EOTFi =="" ? OETFi : EOTFi : EOTFid
       OETFi_i = color_Fuzzy_Search (OETFi)
       EOTFi_i = color_Fuzzy_Search (EOTFi)
          EOTF = EOTFi_i[2]

       tv_in_d = Defined (tv_in)
    tv_in      = Default (tv_in,  !(isRGBi || cs_inF =="sRGB" || cs_in =="jpeg" || cs_in =="jpg") && propIDs[6]   )
    tv_out     = Default (tv_out,  (isRGBo || cs_outF=="sRGB" || cs_out=="jpeg" || cs_out=="jpg") ? false : i_fmt[0]!=o_fmt[0] && o_fmt[1]!="444" ? true : tv_in )

    kernel     = Default (kernel,   (w>nw||h>nh)?"Didee":"Precise")
    Lkrn       = LCase   (kernel)

    deep1      = FindStr(Lkrn,  "deep")>0 || FindStr(Lkrn,  "nnedi3")>0
    deep2      = deep1  || FindStr(Lkrn,  "ravu")>0 || FindStr(Lkrn,  "xbr")>0 || FindStr(Lkrn, "waifu")>0 || FindStr(Lkrn, "fsr")>0 || FindStr(Lkrn, "fsrcnn")>0 || FindStr(Lkrn, "fcbi")>0
    gpu        = deep1  || FindStr(Lkrn,  "jinc")>0 || FindStr(Lkrn,  "ewa")>0 ? 0 : -1
    kernel_c   = Default (kernel_c, deep2 ? "lanczos3" : kernel)
    Lkrnc      = LCase   (kernel_c)

    deep1c     = FindStr(Lkrnc, "deep")>0 || FindStr(Lkrnc, "nnedi3")>0
    gpuc       = deep1c || FindStr(Lkrnc, "jinc")>0 || FindStr(Lkrnc, "ewa")>0 ? 0 : -1

    D_out_d    = color_propGet(cs_outFA[4])[3]
    D_in       = Defined(D_in)  ? D_in  =="" ? propIDs[2]  : D_in  : cs_in_d  ? cs_in =="" ? propIDs[2] : cs_in : propIDs[2]
    D_out      = Defined(D_out) ? D_out =="" ? D_in : D_out : D_out_d
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
    LMS        = Default (LMS,            "CAT16"      )
    CAT        = Default (CAT,            "CAT"        )                # 'CAT', 'Simulation' or 'Compensation'. Perform CAT (Chromatic Adaptation Transform), illuminant simulation or compensation (full White Point conversion)
    space      = Default (scale_space, OETF=="linear"?"linear":"gamma") # resizing space: "gamma", "linear" (best for down), "sigmoid" (best for up) or "log" for quasilog -log(x+a)-. ("luminance weighted gamma resampling/sharpening"" Improvement over sigmoid: https://forum.doom9.org/showthread.php?p=1687374) or (https://web.archive.org/web/20150420001849/http://forum.luminous-landscape.com/index.php?topic=91754.msg763345)
    cplace_in  = Default (cplace_in, fc ? "center" : "")                # Assumes default from format
    cplace_out = Default (cplace_out,  cplace_in)                       # Assumes default from format
    src_left   = Defined (src_left) ? IsArray(src_left)  ? ArraySize(src_left) > 1 ? src_left : ArrayAdd(src_left,0.0) : [src_left,0.0] : [0.0,0.0]
    # src_left/top for chroma is autoscaled from luma units, therefore input [1,1] will be converted to [1,0.5] for 420
    src_leftc  = src_left[1]       src_left = src_left[0]
    src_top    = Defined (src_top)  ? IsArray(src_top)   ? ArraySize(src_top)  > 1 ? src_top  : ArrayAdd(src_top, 0.0) : [src_top, 0.0] : [0.0,0.0]
    src_topc   = src_top [1]       src_top  = src_top [0]

    noring     = Default (noring,  false)
    nomoir     = Default (nomoiree,false)
    recon      = Default (UVrecon, false)
    Comp       = Default (GC,      false)        # Gamut compression
    dg         = Default (show,    false)
    th         = Default (threads,     8)        # for kernel CPU nnedi3 (gpu=-1) or deep
    co         = Default (cores,nmod(th/2,2,4))  # for kernel CPU nnedi3 (gpu=-1) or deep
    gpu        = Defined(gpuid) ? IsInt(gpuid) ? [gpuid,gpuc] : ArraySize(gpuid)==1 ? ArrayAdd(gpuid,gpuc) : gpuid : [gpu,gpuc]
    # Set gpuid to 0 or above to run scalers over the GPU. Supported kernels are nnedi3 and those supported by avslibplacebo (bicubics, splines, sincs, and some jincs).
    # Waifu, RAVU, SSIM, FSRCNN, Krig, SuperResXBR, FCBI and Tukey are GPU only. GPU scaling for anything other than jincs is surprisingly slower though.

    # PRESETS (maps outputs format)
    preset     = Default(preset, "none")
    num        = preset == ""             ? 0  :  preset == "NTSC"        ? 8  : \
                 preset == "none"         ? 0  :  FindStr(preset,"525")>0 ? 8  : \
                 preset == "DoVi"         ? 1  :  preset == "CRT-NTSC"    ? 8  : \
                 preset == "DVp5"         ? 1  :  preset == "PAL"         ? 9  : \
                 preset == "DVp7"         ? 1  :  preset == "470"         ? 9  : \
                 preset == "DoVi/DVp5/DVp7"?1  :  FindStr(preset,"625")>0 ? 9  : \
                 preset == "PQ10"         ? 2  :  preset == "CRT-PAL"     ? 9  : \
                 preset == "UHD"          ? 2  :  preset == "Master"      ? 10 : \
                 FindStr(preset,"2100")>0 ? 2  :  preset == "Archival"    ? 11 : \
                 preset == "PQ10/UHD"     ? 2  :  preset == "GAM"         ? 11 : \
                 preset == "HLG10"        ? 3  :  preset == "Grade"       ? 12 : \
                 preset == "HD"           ? 4  :  preset == "Theater"     ? 13 : \
                 FindStr(preset,"1886")>0 ? 4  :  preset == "JXL"         ? 14 : \
                 preset == "DVD"          ? 5  :  preset == "JPEGXL"      ? 14 : \
                 preset == "DVD-NTSC"     ? 5  :  preset == "JPEG-XL"     ? 14 : \
                 preset == "DVD-PAL"      ? 6  :  preset == "JPEG2000"    ? 15 : \
                 preset == "DV"           ? 7  :  preset == "JP2"         ? 15 : \
                 preset == "CRT"          ? 8  :  preset == "JPG_old"     ? 16 : \
                 preset == "601"          ? 8  :  preset == "JPG"         ? 17 : 0


    #                           Default  DoVi/DVp5/DVp7  PQ10/UHD/2100   HLG10    HD/1886  DVD-NTSC/601  DVD-PAL/470BG  DV-NTSC     CRT-NTSC     CRT-PAL     Master  GAM*/Archival    Grade     Theater     JPEG-XL    JPEG2000    JPG_old  JPG/sRGB
    o_fmt0     = Select (num,   o_fmt[0],    "IPTPQc2",     "YCbCr",    "YCbCr",   "YCbCr",    "YCbCr",     "YCbCr",    "YCbCr",       "YIQ",     "YUV",     "RGB",       "RGB",      "RGB",     "YUVr",      "XYB",     "YUVr",  "YCbCr",   "sYCC") # Model. sYCC is basically sRGB (prims, transfer, range) over YCbCr, but uses true Rec709 derived matrix coeffs, not from 470M
    cs_outFA   = Select (num,   cs_outFA,       "2020",      "2020",     "2020",     "709",     "170M",     "470BG",     "170M",      "170M",   "470BG",  "DCIXYZ",       "AP0",      "AP1",   "DCIXYZ",     "sRGB",     "sRGB",   "170M",   "sRGB") # Primaries. JPG_old standardized decoding (PS, mozjpeg, cjxl, etc) is always treated as encoded with 170M (470M derived) matrix, regardless of image/profile primaries, a mess: https://en.wikipedia.org/wiki/YCbCr#Chromaticity-derived_luminance_systems
    o_fmt1     = Select (num,   o_fmt[1],        "420",       "420",      "420",     "420",      "420",       "420",      "410",       "411",     "411",     "444",       "444",      "444",      "444",      "444",      "444",    "420",    "422") # [J:a:b]
    tv_out     = Select (num,     tv_out,        false,        true,       true,      true,       true,        true,      false,        true,      true,     false,       false,      false,      false,      false,      false,    false,    false)
    cplace_out = Select (num, cplace_out,   "top_left",  "top_left", "top_left",    "left",     "left",      "left",       "DV",    "center",  "center",        "",          "",         "",         "",         "",         "", "center", "center")
    D_out      = Select (num,      D_out,        "D65",       "D65",      "D65",     "D65",      "D65",       "D65",      "D65",       "D65",     "D65",       "E",      "ACES",     "ACES",        "E",      "D65",      "D65",    "D65",    "D65")
    EOTF       = Select (num,       EOTF,         "PQ",        "PQ",      "HLG",    "1886",     "1886",      "1886",     "170M",      "170M",    "170M",  "DCIXYZ",    "linear",  "ACESCCt",   "DCIXYZ",     "sRGB",     "sRGB",   "170M",   "sRGB")
    PAR        = Select (num,          1,            1,           1,          1,         1,      "601",       "470",      "601",       "601",     "601",         1,           1,          1,          1,          1,          1,        1,        1)
    cdc        = Select (num,         "",       "H265",      "H265",     "H265",    "H264",     "H262",      "H262",     "H261",          "",        "",    "TIFF",       "PIZ",      "PIZ","MJPEG2000",   "JPEGXL", "JPEG2000",    "JPG",    "JPG")
    cont       = Select (num,         "",         "TS",        "TS",       "TS",      "TS",      "VOB",       "VOB",    "MPEG2",          "",        "",    "TIFF",       "EXR",      "EXR",      "mj2",      "jxl",      "jp2",    "jpg",    "jpg")
    bit        = Select (num,         bi,           12,          10,         10,         8,          8,           8,          8,           0,         0,        16,          16,         32,         12,          8,          8,        8,        8)

  # * DVD-PAL and DVD-NTSC employ 1886 as EOTFi since the dawn of digital mastering (early 2000s), otherwise used 170M.
  # * GAM (Graded Archival Master)


    ############ Data extraction and normalization + Asserts ############

                 Assert(IsVersionOrGreater(3,7,3), "ConvertFormat: Update AviSynth+ version")
    !(space=="sigmoid" || space=="gamma" || space=="linear" || space=="log") ? \
                 Assert(false, "ConvertFormat: Invalid scale space type")    : nop()


    space    = space     != "" && space  != "none" ? space : "gamma"

    # Constants for logic flow
    isGamma  = OETF      !=  EOTF
    isFrmt   = i_fmt[0]  !=  o_fmt0
    isSpace  = cs_in     !=  cs_out
    isIllu   = D_in      !=  D_out
    isSpaIllu= isSpace   || isIllu
    isScale  = nw!=w     ||  nh!=h
    isJab    = i_fmt[1]  !=  o_fmt1
    isChP    = cplace_in != cplace_out

    coef_i   =           color_coef(mat=cs_in)
    coef_o   = isSpace ? color_coef(mat=cs_out) : coef_i
    EOTF2    = isGamma ? EOTF   : OETF

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

    src_width  = Defined (src_width)  ? IsArray(src_width)  ? ArraySize(src_width)  > 1 ? src_width  : ArrayAdd(src_width, cow) : [src_width, cow] : [w,cow]
    src_widthc = src_width[1]      src_width  = src_width[0]
    src_height = Defined (src_height) ? IsArray(src_height) ? ArraySize(src_height) > 1 ? src_height : ArrayAdd(src_height,coh) : [src_height,coh] : [h,coh]
    src_heightc= src_height[1]     src_height = src_height[0]

    i_type1  || o_type1                          ? Assert(  bi==8, "ConvertFormat: Unsupported Pixel Type: HBD YUV411")         : nop()
    i_type10 || o_type10                         ? Assert(false,   "ConvertFormat: Unsupported Pixel Type: YUV410")             : nop()
    !fc && !isy && (i_type2 || i_fmt[1]=="420")  ? Assert( w%2==0, "ConvertFormat: Clip Width is not mod2" )                    : nop()
    !fc &&  i_type1                              ? Assert( w%4==0, "ConvertFormat: Clip Width is not mod4" )                    : nop()
    o_type1                                      ? Assert(nw%4==0, "ConvertFormat: Target Width is not mod4" )                  : nop()
    !(isRGBo || o_type4 || (cnw>cow || cnh>coh)) ? Assert(!recon,  "ConvertFormat: Invalid settings for chroma reconstruction") : nop()


    # Overriding 'taps' arg by kernel name (ie. 'blackman8' means taps=8)

    function StrNumber(string str) {
        for (i = 16, 0, -1) {
           num = str == string(i)
             i = num ? 0 : i
                 num} } # Checks if string is a number between 1 and 16

    # Exclusion list
    nope = FindStr(Lkrn,  "spline") > 0 && Lkrn  !="spline" && kernel  !="Bicubic" || FindStr(Lkrn,  "jinc") > 0 && Lkrn  !="jinc" || FindStr(Lkrn, "ewasharp") > 0 || FindStr(Lkrn, "nnedi3") > 0 || FindStr(Lkrn, "ssim2") > 0 || FindStr(Lkrn, "ewas") > 0
    nopc = FindStr(Lkrnc, "spline") > 0 && Lkrnc !="spline" && kernel_c!="Bicubic" || FindStr(Lkrnc, "jinc") > 0 && Lkrnc !="jinc" || FindStr(Lkrnc,"ewasharp") > 0 || FindStr(Lkrnc,"nnedi3") > 0 || FindStr(Lkrn, "ssim2") > 0 || FindStr(Lkrn, "ewas") > 0

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

    function KernStr(string kernel, int nw, int nh, float bc_b, float bc_c, float p, bool pd, bool show, int gpuid) {

    shpath = "C:\Program Files (x86)\AviSynth+\plugins64+\Shaders\avslibplacebo\"
    ewarad = pd ? int(p) + 0.24 : 3.2383154841662362

    resampler = Format( kernel == "nnedi3" || kernel == "nnedi"                                              ? \
                                          """nnedi3resize({nw},{nh},cshift="spline36",gpuid={gpuid},HBD=space!="gamma"?true:Undefined(),threads=th,cores=co""" : \
                        kernel == "EEDI3"  || kernel == "EEDI"                                               ? \
                                          """eedi3resize ({nw},{nh},cshift="spline36",gpuid={gpuid},HBD=space!="gamma"?true:Undefined()""" : \
                        kernel == "Bicubic"                                                                  ? \
                                   gpuid<0       ? "BicubicResize ( {nw},{nh},b={bc_b},c={bc_c}"             : \
                                   """libplacebo_Resample({nw},{nh},"bicubic",param1={bc_b},param2={bc_c},device={gpuid}""" : \
                        kernel == "Bilinear" || kernel == "Triangle" || kernel == "Bartlett"                 ? \
                                   gpuid<0       ? "BilinearResize( {nw},{nh}"                               : \
                                   """libplacebo_Resample({nw},{nh},"bilinear",device={gpuid}"""             : \
                        kernel == "Nearest"  || kernel == "NearestNeighbour" || kernel == "NN"               ? \
                                   gpuid<0       ? "GaussResize({nw},{nh},p=100"                             : \
                                   """libplacebo_Resample({nw},{nh},"gaussian",param1=100,device={gpuid}"""  : \
                        kernel == "Point"  || kernel == "Pointer"                                            ? \
                                   gpuid<0       ? "PointResize({nw},{nh}"                                   : \
                                   """libplacebo_Resample({nw},{nh},"nearest",            device={gpuid}"""  : \
                        kernel == "Gauss"                                                                    ? \
                                   gpuid<0       ? "GaussResize({nw},{nh},p={pd}?{p}:9"                      : \
                                   """libplacebo_Resample({nw},{nh},"gaussian",param1={pd}?{p}:9,device={gpuid}""" : \
                        kernel == "deep"         ? """deep_resize({nw},{nh},grain=0,gpuid={gpuid},HBD=space!="gamma"?true:Undefined(),threads=th,cores=co""" : \
                        kernel == "Average"  || kernel == "Box" || kernel == "Dirichlet" || kernel == "Area" || kernel == "Simple" ? \
                                                   """fmtc_resample({nw},{nh},kernel="box" """               : \
                        kernel == "Spline"       ? """fmtc_resample({nw},{nh},kernel="Spline",taps={pd}?int({p}):4""": \
                        kernel == "Spline16" && gpuid>-1 ? """libplacebo_Resample({nw},{nh},"spline16",device={gpuid}""": \
                        kernel == "Spline36" && gpuid>-1 ? """libplacebo_Resample({nw},{nh},"spline36",device={gpuid}""": \
                        kernel == "Spline64" && gpuid>-1 ? """libplacebo_Resample({nw},{nh},"spline64",device={gpuid}""": \
                        kernel == "Spline100"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=5"""      : \
                        kernel == "Spline144"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=6"""      : \
                        kernel == "Spline196"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=7"""      : \
                        kernel == "Spline256"    ? """fmtc_resample({nw},{nh},kernel="Spline",taps=8"""      : \
                        kernel == "Wiener"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Wiener3)       """ : \
                        kernel == "Hamming"      ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Hamming4)      """ : \
                        kernel == "Black-Harris" ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(BlackHarris4)  """ : \
                        kernel == "Black-Nuttall"? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(BlackNuttall4) """ : \
                        kernel == "Flat-Top"     ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(FlatTop4)      """ : \
                        kernel == "MinSide"      ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(MinSide4)      """ : \
                        kernel == "Welch"        ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Welch3)        """ : \
                        kernel == "Cosine"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Cosine3)       """ : \
                        kernel == "Bessel"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Bessel3)       """ : \
                        kernel == "Parzen"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Parzen8)       """ : \
                        kernel == "Kaiser"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Kaiser8)       """ : \
                        kernel == "Bohman"       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Bohman8)       """ : \
                        kernel == "Ginseng"                                                                                                                         ? \
                                   gpuid<0       ? """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Ginseng3)      """ : \
                                                   """libplacebo_Resample({nw},{nh},"ginseng",device={gpuid},radius={pd}?int({p}):3"""                              : \
                        kernel == "Hann"         || kernel == "Hanning"                                                                                             ? \
                                                   """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=8,cnorm=true,center=true,impulse=ArraySym(Hann4)         """ : \
                        kernel == "Quadratic"    || kernel == "Quadric" || kernel == "Bell"                  ? \
                                                   """fmtc_resample({nw},{nh},kernel="impulse",kovrspl=16,cnorm=true,center=true,impulse=ArraySym(quadratic15)  """ : \
                        kernel == "Nuttall"      || kernel == "BlackmanMinLobe"                              ? \
                                                   """fmtc_resample({nw},{nh},kernel="blackmanminlobe"    """: \
                        kernel == "SincLin"      || kernel == "SincLin2ResizeMT"                             ? \
                                                 "SincLin2Resize({nw},{nh},range=1,taps={pd}?int({p}):15"    : \
                        kernel == "SinPow"      || kernel == "SinPowResizeMT"                                ? \
                                                 "SinPowerResize({nw},{nh},range=1,p={pd}?{p}:2.5"           : \
                        kernel == "SSIM"        || kernel == "ResizeShader"                                  ? \
                                                   """ResizeShader({nw},{nh},kernel="SSIM",b=0.1"""          : \
                        kernel == "SSIM2"                                                                    ? \
                                        """SSIM_downsample({nw},{nh},smooth=0.43,resample_args="-0.6,0.4" """: \
                        kernel == "Sinc"                                                                     ? \
                                   gpuid<0       ?     "SincResize(    {nw},{nh},taps={pd}?int({p}):4"       : \
                                   """libplacebo_Resample({nw},{nh},"sinc",device={gpuid},radius={pd}?int({p}):4""" : \
                        kernel == "Blackman"     ?     "BlackmanResize({nw},{nh},taps={pd}?int({p}):6"       : \
                        kernel == "Lanczos"                                                                  ? \
                                   gpuid<0       ?     "LanczosResize( {nw},{nh},taps={pd}?int({p}):4"       : \
                                   """libplacebo_Resample({nw},{nh},"lanczos",device={gpuid},radius={pd}?int({p}):4""" : \
                        kernel == "DPID"         ?     "DPID({nw},{nh},lambdaY=0.5"                          : \
                        kernel == "Jinc16"                                                                   ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=2"                          : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius=2.2331305943815286""" : \
                        kernel == "Jinc36"                                                                   ? \
                                   gpuid<0       ?     "Jinc36Resize({nw},{nh}"                              : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius=3.2383154841662362""" : \
                        kernel == "Jinc64"                                                                   ? \
                                   gpuid<0       ?     "Jinc64Resize({nw},{nh}"                              : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius=4.2410628637960699""" : \
                        kernel == "Jinc100"                                                                  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=5"                          : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius=5.2427643768701817""" : \
                        kernel == "Jinc144"                                                                  ? \
                                   gpuid<0       ?     "Jinc144Resize({nw},{nh}"                             : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius=6.2439216898644877""" : \
                        kernel == "Jinc196"                                                                  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=7"                          : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius=7.2447598687199570""" : \
                        kernel == "Jinc256"                                                                  ? \
                                   gpuid<0       ?     "Jinc256Resize({nw},{nh}"                             : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius=8.2453949139520427""" : \
                        kernel == "EWA"          || kernel == "Jinc"       || kernel == "ewa_lanczos"      || kernel == "LoBlur"  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap={pd}?int({p}):3"            : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",device={gpuid},radius={ewarad}""" : \
                        kernel == "EWASharp"     || kernel == "JincSharp"  || kernel == "ewa_lanczossharp" || kernel == "LoJaggy" ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=3,blur=0.9812505644269356"  : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=0.9812505644269356,device={gpuid},radius=3.2383154841662362""" : \
                        kernel == "EWASharp2"    || kernel == "JincSharp2" || kernel == "ewa_lanczos2sharp"  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=2,blur=0.9549963639785485"  : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=0.9549963639785485,device={gpuid},radius=2.2331305943815286""" : \
                        kernel == "EWASharp4"    || kernel == "JincSharp4" || kernel == "ewa_lanczos4sharp"  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=4,blur=0.9885973386557245"  : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=0.9885973386557245,device={gpuid},radius=4.2410628637960699""" : \
                        kernel == "EWASharper"   || kernel == "JincSharper"|| kernel =="ewa_lanczosradius3"  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=3,blur=0.9264075766146068"  : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=0.9264075766146068,device={gpuid},radius=3.2383154841662362""" : \
                        kernel == "EWASharper2"  || kernel == "JincSharper2"||kernel =="ewa_lanczosradius2"  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=2,blur=0.895603689740279282": \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=0.895603689740279282,device={gpuid},radius=2.2331305943815286""" : \
                        kernel == "EWASharper4"  || kernel == "JincSharper4"||kernel =="ewa_lanczosradius4"  ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=4,blur=0.943159799432847707": \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=0.943159799432847707,device={gpuid},radius=4.2410628637960699""" : \
                        kernel == "EWASharpest"  || kernel == "JincSharpest"|| kernel =="ewa_lanczossharpest"? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=3,blur=0.88549061701764"    : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=0.88549061701764,device={gpuid},radius=3.2383154841662362""" : \
                        kernel == "EWASoft"      || kernel == "JincSoft"   || kernel == "ewa_lanczossoft"    ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=3,blur=1.015"               : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=1.015 ,device={gpuid},radius=3.2383154841662362""" : \
                        kernel == "Haasnsoft"                                                                ? \
                                   gpuid<0       ?     "JincResize({nw},{nh},tap=3,blur=1.11"                : \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=1.11  ,device={gpuid},radius=3.2383154841662362""" : \
                        kernel == "Tukey"                                                                    ? \
                                   """libplacebo_Resample({nw},{nh},"ewa_lanczos",blur=1.11,taper=0.5,device=max(0,{gpuid}),radius=3.2383154841662362""" : \
                        kernel == "ewa_robidoux"                                                             ? \
                                   """libplacebo_Resample({nw},{nh},"ewa_robidoux"     ,device=max(0,{gpuid})""" : \
                        kernel == "ewa_robidouxsharp"                                                        ? \
                                   """libplacebo_Resample({nw},{nh},"ewa_robidouxsharp",device=max(0,{gpuid})""" : \
                        kernel == "ewa_hann"     || kernel == "ewa_hanning"                                  ? \
                                   """libplacebo_Resample({nw},{nh},"ewa_hann"         ,device=max(0,{gpuid}),radius={ewarad}""" : \
                        kernel == "ewa_ginseng"                                                              ? \
                                   """libplacebo_Resample({nw},{nh},"ewa_ginseng"      ,device=max(0,{gpuid}),radius={ewarad}""" : \
                        kernel == "FCBI"         ? "FCBI().deep_resize({nw},{nh},grain=0,gpuid={gpuid}"      : \
                        kernel == "SuperResXBR"  || kernel == "XBR"                                          ? \
                                    "SuperResXBR(factor=2).deep_resize({nw},{nh},grain=0,gpuid={gpuid}"      : \
                        FindStr(kernel,"aifu")>0                                                             ? \
                                    "waifu2xresize({nw},{nh},1,0,grain=0,soothe=false,gpuid={gpuid}"         : \
                        kernel == "RAVU"         || kernel == "RAISR"                                        ? \
                                    """RAVUresize({nw},{nh},path=""""+string(shpath+"ravu-r4.hook")+"""",gpuid={gpuid},grain=0""" : \
                        kernel == "FSR"         || kernel == "EASU"                                          ? \
                                    """FSRresize( {nw},{nh},path=""""+string(shpath+"FSR.glsl")+""""    ,gpuid={gpuid},grain=0""" : \
                        kernel == "Krig"         || kernel == "KrigBilateral"                                ? \
                                    "KrigBilateral().deep_resize({nw},{nh},grain=0,gpuid={gpuid}"            : \
                        kernel == "FSRCNN"       || kernel == "AiUpscale"                                    ? \
                                             """AiUpscale(2,Luma="Medium",Chroma="Lanczos4",Mode="Photo")."""  \
                                                   +"BicubicResize({nw},{nh},b=0.378216,c=0.310892"          : \
                        kernel +                           "Resize({nw},{nh}"                                 )


                        # Exclusion of additional resize arguments
                        src_nul = FindStr(resampler,"grain")>0  ||  FindStr(UCase(resampler),"AIUPSCALE")>0 || FindStr(UCase(resampler),"SSIM")>0 || kernel == "DPID"
                        src_box = FindStr(resampler,"fmtc_resample")>0 || FindStr(resampler,"libplacebo")>0

                        # Retrieving taps for 'show'
                        if (show) {
                            resampler = TrimAll(resampler)
                            taps = FindStr(resampler, "placebo") > 0 ? FindStr(resampler, "radius=")>0 ? MidStr(resampler,FindStr(resampler,"radius=")+7) : "0" : \
                                   FindStr(resampler, "inPow")   > 0 ? MidStr (resampler,FindStr(resampler, "p=")+2)                                      : \
                                   FindStr(resampler, "impulse") > 0 ? MidStr (resampler,StrLen (resampler)-1,1)                                          : \
                                   FindStr(resampler, "tap")     > 0 ? FindStr(resampler, "Jinc") > 0 ?                                                     \
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


    krny = KernStr(kernel  ,  nw,  nh, bc_b,  bc_c,  taps,  pd,  dg, gpu[0])  resampler   = krny[0]  src_nuly = krny[1]  src_boxy = krny[2]
    krnc = KernStr(kernel_c, cnw, cnh, bch_b, bch_c, tapsc, pdc, dg, gpu[1])  resampler_c = krnc[0]  src_nulc = krnc[1]  src_boxc = krnc[2]

    src_lbp = FindStr(resampler,   "placebo") > 0   src_nn  = FindStr(resampler,   "nnedi3resize") > 0 || FindStr(resampler,   "eedi3resize") > 0
    src_lbpc= FindStr(resampler_c, "placebo") > 0   src_nnc = FindStr(resampler_c, "nnedi3resize") > 0 || FindStr(resampler_c, "eedi3resize") > 0
    src_wh  = src_boxy && !src_lbp  ? Format(",sw={src_width},  sh={src_height}")  : src_nn  ? "" : Format(",src_width={src_width}, src_height={src_height}")
    src_whc = src_boxc && !src_lbpc ? Format(",sw={src_widthc}, sh={src_heightc}") : src_nnc ? "" : Format(",src_width={src_widthc},src_height={src_heightc}")
    src_whc4= src_boxc && !src_lbpc ? Format(",sw={nw}, sh={nh}")                  : src_nnc ? "" : Format(",src_width={nw},src_height={nh}")
    fmtcb   = src_lbp  ? ""  : src_boxy ?       Format(".ConvertBits({bi})") : ""
    fmtcbc  = src_lbpc ? ""  : src_boxc ?       Format(".ConvertBits({bi})") : ""
    src_nr  = src_nuly ? ")" : src_boxy ? ")" : Format(",src_left={src_left},src_top={src_top}"+src_wh+")")
    cplaceY = src_nuly ? ")" : src_boxy ?       Format(",sx={src_left},sy={src_top}"+src_wh+")"+fmtcb) : src_nr
    Ynr     = deep2 ? Format("""ex_luts(Y,Y.Repair(kernel!="FSRCNN"?BicubicResize(Ym,{nw},{nh},0,0"""+src_nr+""":waifu2xresize(Ym,{nw},{nh}"""+src_nr+""",1),mode="clamp")""") : \
                      Format(".Repair(BicubicResize(Ym,{nw},{nh},0,0"+src_nr+",1)")  # noring uses Hermite kernel. Check here if I need -1 for chroma
                                                                                     # BEWARE! Might not work for edge directed kernels!!

        nnpln     = o_fmt1=="420" ? 2 : o_type2 ? 3 : o_type4 || isy ? 4 : 1
        CPB       = """src_leftc = i_type4 ?  src_leftc : i_type1 || i_type10 ? 0.625-0.375*(src_leftc*float(cow)/cnw) : src_leftc*0.5
                       src_topc  = i_type4 || i_type1  || i_type2  ? src_topc : src_topc*0.5

                       cplaceH1  = (src_boxc ? ",sx=" : ",src_left=")+string(cplace1[0]+src_leftc)
                       cplaceV1  = (src_boxc ? ",sy=" : ",src_top =")+string(cplace1[1]+src_topc)"""

    if (isSpaIllu && !isFrmt && !isRGBi) {

        cplace2   = chroma_placement(nw, nh, nw, nh, cs_in, cs_out,    "RGB", o_fmt0,    "444", o_fmt1,  "center", cplace_out )

        cplaceH2  = (src_boxc ? ",sx=" : ",src_left=")+string(cplace2[0])
        cplaceV2  = (src_boxc ? ",sy=" : ",src_top =")+string(cplace2[1])
        cplaceC2  = (src_nulc ? "" : src_nnc ? Format(",planes=[2,{nnpln}]") : (cplaceH2 + cplaceV2 + src_whc4)) + ")" + fmtcbc

        cplace1   = chroma_placement( w,  h, nw, nh, cs_in, cs_out, i_fmt[0],  "RGB", i_fmt[1],  "444", cplace_in,   "center" )
        Eval(CPB)
        cplaceC1  = (src_nulc ? "" : src_nnc ? Format(",planes=[2,4]") : (cplaceH1 + cplaceV1 + src_whc)) + ")" + fmtcbc

    } else {

        cplace1   = chroma_placement(w,   h, nw, nh, cs_in, cs_out, i_fmt[0], o_fmt0, i_fmt[1], o_fmt1, cplace_in, cplace_out )
        Eval(CPB)
        cplaceC1  = (src_nulc ? "" : src_nnc ? Format(",planes=[2,{nnpln}]") : (cplaceH1 + cplaceV1 + src_whc)) + ")" + fmtcbc
        cplace2   = cplace1
        cplaceC2  = cplaceC1
    }



    c_recon  = """c_cplace= chroma_placement(w*2, h*2, fcnw, fcnh, cs_in, cs_out, i_fmt[0], o_fmt0, i_fmt[1], o_fmt1, cplace_in, cplace_out )
                  ref     =   Y.KNLMeansCL(0, 16, 0, pow(1.464968620512209618455732713658, 6.4), wref=1)
                  Luma    = ref.nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, HBD=false, gpuid=gpu[0])
                  Uu      =  Cb.nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, HBD=false, gpuid=gpu[1], fwidth=w*4, fheight=h*4, cshift=kernel_c)
                  Vu      =  Cr.nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, HBD=false, gpuid=gpu[1], fwidth=w*4, fheight=h*4, cshift=kernel_c)
                  Unew    = Uu.KNLMeansCL(0, 16, 0, 6.4, wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc, src_top=c_cplace[1]+src_topc)
                  Vnew    = Vu.KNLMeansCL(0, 16, 0, 6.4, wref=0, rclip=Luma).BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc, src_top=c_cplace[1]+src_topc)
                  Cb      = ex_LFR(Unew, Uu.BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc, src_top=c_cplace[1]+src_topc), LFR=fcnw/1.1)
                  Cr      = ex_LFR(Vnew, Vu.BicubicResize(fcnw, fcnh, b=0.0, c=0.5, src_left=c_cplace[0]+src_leftc, src_top=c_cplace[1]+src_topc), LFR=fcnw/1.1)"""


    # Only scaling (or change in range, or gamma, or chroma placement, or subpixel shift, or odd cropping)
    if (isy || !isSpaIllu && !isFrmt) {

        Y     =  isyv      ? ExtractY() : last
        Y     =            \
        space == "linear"  ? Y.CCTF(OETF, true,  tv_in, false)                                        : \
        space == "sigmoid" ? Y.CCTF(OETF, true,  tv_in, false).ex_contrast(-1.15,1,191,false)         : \
        space == "log"     ? Y.CCTF(OETF, true,  tv_in, false).ACEScct_r()                            : \
        OETF  == "linear"  ?                                                                            \
        EOTF  != "linear"  ? Y.CCTF(EOTF, false, tv_in, tv_out) : Y.CCTF("470M", false, tv_in, false) : Y

        Ym   = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
        Y    = Eval("Ym." + resampler + cplaceY + (noring && !deep2 ? Ynr : ""))
        Y    = noring && deep2 ? Eval(Ynr) : Y

        # 'SSIM' kernel requires YUV (3 planes). It changes colors so debug!
        if (isRGBi || FindStr(resampler,"ResizeShader")>0 ) {
            Y
        } else {

            if (isyv) {

                Cb  = ExtractU()
                Cr  = ExtractV()
                Y

                if (recon && !i_type4) {

                    Eval(ReplaceStr(c_recon, "fcn", "cn"))

                } else {

                    Cb  = Eval("Cb." + resampler_c + cplaceC1)
                    Cr  = Eval("Cr." + resampler_c + cplaceC1)
                }
                } else { Y } }

            space == "linear"  ?                                 CCTF(EOTF,  false, false, tv_out) : \
            space == "sigmoid" ? ex_contrast(1.15,1,191,false,3).CCTF(EOTF,  false, false, tv_out) : \
            space == "log"     ? ACEScct_f(UV=3).                CCTF(EOTF,  false, false, tv_out) : \
            OETF  == "linear"  ?                                                                     \
            EOTF  != "linear"  ? last                          : CCTF("470M", true, false, tv_out) : \
            isGamma            ?                                 CCTF(OETF,   true, tv_in, false ).  \
                                                                 CCTF(EOTF,  false, false, tv_out) : !isyv && tv_in != tv_out ? SMPTE_legal(tv_out) : last

            if (isyv) {
                CombinePlanes(last, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt1+o_fmt[2])
                tv_in != tv_out ? SMPTE_legal(tv_out, space=="gamma" && !isGamma && (!tv_out || tv_out && EOTF!="linear") ? 3 : 1, 3) : last
                }
    } else {

        propSet("_ColorRange", tv_in ? 1 : 0)

        if (!isRGBi) {

        Y   = ExtractY()
        Cb  = ExtractU()
        Cr  = ExtractV()

        if (isScale || isGamma) {

            Y     =            \
            space == "linear"  ? Y.CCTF(OETF, true,  tv_in, false)                                       : \
            space == "sigmoid" ? Y.CCTF(OETF, true,  tv_in, false).ex_contrast(-1.15,1,191,false)        : \
            space == "log"     ? Y.CCTF(OETF, true,  tv_in, false).ACEScct_r()                           : \
            OETF  == "linear"  ?                                                                           \
            EOTF  != "linear"  ? Y.CCTF(EOTF, false, tv_in, false) : Y.CCTF("470M", false, tv_in, false) : Y

        }

        if (recon && !i_type4) {

            fcnw = isSpaIllu ? nw : cnw
            fcnh = isSpaIllu ? nh : cnh

            Eval(c_recon)

        } else {

            str  = !isSpaIllu ? resampler_c : ReplaceStr(ReplaceStr(ReplaceStr(resampler_c, " ", ""), "("+string(cnw), "("+string(nw)), ","+string(cnh), ","+string(nh))
            Cb   = Eval("Cb." + str + cplaceC1)
            Cr   = Eval("Cr." + str + cplaceC1)
            }


        if (isScale || isGamma) {

            Ym    = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y     = Eval("Ym." + resampler + cplaceY + (noring && !deep2 ? Ynr : ""))
            Y     = noring && deep2 ? Eval(Ynr) : Y

            Y     =             space == "linear"  ? Y.                              CCTF(EOTF,   false, false, !(isRGBo || isSpaIllu || !tv_out)) : \
                                space == "sigmoid" ? Y.ex_contrast(1.15,1,191,false).CCTF(EOTF,   false, false, !(isRGBo || isSpaIllu || !tv_out)) : \
                                space == "log"     ? Y.ACEScct_f(UV=1, false ,false).CCTF(EOTF,   false, false, !(isRGBo || isSpaIllu || !tv_out)) : \
                                OETF  == "linear"  ?                                                                                                 \
                                EOTF  != "linear"  ? Y                             : CCTF(Y,"470M",true, false, false)                             : \
                                isGamma            ? Y.                              CCTF(OETF,    true, tv_in, false ).                             \
                                                                                     CCTF(EOTF,   false, false, !(isRGBo || isSpaIllu || !tv_out)) : Y
            }


        if (!(isRGBo || isSpaIllu)) {

            CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt1+o_fmt[2])
            tv_in != tv_out ? space=="gamma" && EOTF!="linear" ? SMPTE_legal(tv_out,3,  3) : \
                              isScale                          ? SMPTE_legal(tv_out,1,  3) : \
                             !isScale                          ? SMPTE_legal(tv_out,UVr,3) : last : last

        } else {

            ArEx = "R = RGB[0]  G = RGB[1]  B = RGB[2]"
            ArEx = i_fmt[0]!="YCbCr" ? ArEx : "RGB"

            if (i_fmt[0]=="YcCbcCrc" || cs_in == "2020CL") {

                RGB = YcCbcCrc_to_RGB( Y, Cb, Cr, cs_in, coef_i, !(isScale || !tv_in), !(isSpace || !tv_out), isSpaIllu)

            } else if (i_fmt[0]=="YCoCg") {

                RGB = YCoCg_to_RGB   ( Y, Cb, Cr,                !(isScale || !tv_in), !(isSpace || !tv_out), isSpaIllu)

            } else if (i_fmt[0]=="YCoCgR") {

                RGB = YCoCgR_to_RGB  ( Y, Cb, Cr,                !(isScale || !tv_in), !(isSpace || !tv_out), isSpaIllu)

            } else if (i_fmt[0]=="YUVr") {

                RGB = YUVr_to_RGB    ( Y, Cb, Cr,                !(isScale || !tv_in), !(isSpace || !tv_out), isSpaIllu)

            } else if (i_fmt[0]=="OkLab") {

                # Requires Range conversion
                RGB = Oklab_to_RGB   ( Y, Cb, Cr, false, cs_in, isSpaIllu)

            } else if (i_fmt[0]=="HSV") {

                # Requires Range conversion
                RGB = HSV_to_RGB     ( Y, Cb, Cr,                !(isScale || !tv_in), isSpaIllu)

            } else if (i_fmt[0]=="CIELab") {

                # Requires Range conversion
                XYZ = Lab_to_XYZ( Y, Cb, Cr, false)
                RGB = XYZ_to_RGB( XYZ, cs_in, D_in)
                RGB = isSpaIllu ? ExtractClip(RGB) : RGB

            } else if (i_fmt[0]=="Yxy") {

                # Requires Range conversion
                RGB = Yxy_to_RGB  ( Y, Cb, Cr, isSpaIllu)

            } else if (i_fmt[0]=="OPP") {

                # Requires Range conversion
                RGB = OPP_to_RGB  ( Y, Cb, Cr, isSpaIllu)

            } else if (i_fmt[0]=="ICtCp") {

                # Requires Range conversion
                RGB = ICtCp_to_RGB( Y, Cb, Cr, cs_in, isSpaIllu)

            } else if (i_fmt[0]=="YCbCr") {

                ytvi       = propGetInt(Y, "_ColorRange")==1
                ctvi       = propGetInt(Cb,"_ColorRange")==1
                ytvo       = isSpaIllu || EOTF == "linear" ? false : tv_out
                scale_y   = ytvi != ytvo ? ytvi ? 256/219. : 219/256. : 1.0
                scale_uv  = ctvi != ytvo ? ctvi ? 256/112. : 224/128. : 2.0

                Kr = 1. - coef_i[0]
                Kb = 1. - coef_i[2]

                m0 = scale_y                                                    m2 = scale_uv * Kr
                                 m4 = scale_uv * ( -Kb * coef_i[2] / coef_i[1]) m5 = scale_uv * ( -Kr * coef_i[0] / coef_i[1])
                                 m7 = scale_uv * Kb

                range_PC = scale_y == 256/219. ? "ymin - " : ""
                range_TV = scale_y == 219/256. ? "ymin + " : ""
                UVf      = bi < 32             ? "range_half - " : ""

                Rs = ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+"        "+(isSpaIllu?"y " :"z ")+UVf + string(m2)+" * + ", bi, false)
                Gs = ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m4)+" * + z " +UVf + string(m5)+" * + ", bi, false)
                Bs = ex_dlut("x "+range_PC+" "+string(m0)+" * "+range_TV+" y "+UVf + string(m7)+" * +                             ", bi, false)

                if (!isSpaIllu) {
                    Expr(Y, Cb, Cr, Rs, Gs, Bs, optSingleMode=true, format=o_fmt[3]+o_fmt[2])
                } else {
                    R = Expr(Y,     Cr, Rs,     optSingleMode=false, lut=lut2)
                    G = Expr(Y, Cb, Cr, Gs,     optSingleMode=true , lut=   0)
                    B = Expr(Y, Cb,     Bs,     optSingleMode=false, lut=lut2)
            } }

        Eval("ArEx")
        !isSpaIllu && EOTF == "linear" ? CCTF("470M", true, false, tv_out) : last } }  # Reverting gamma encoding needed for RGB<->YCbCr model conversion



    if (isSpaIllu) {

        d_gam =isScale && space!="gamma" || isGamma ? EOTF2 : OETF

            isRGBi ?                ConvertBits(32, fulls=!tv_in,fulld=true).CCTF(OETF,  true, false, false) : last
        R = isRGBi ? ExtractR() : R.ConvertBits(32, fulls=true,  fulld=true).CCTF(d_gam, true, false, false)
        G = isRGBi ? ExtractG() : G.ConvertBits(32, fulls=true,  fulld=true).CCTF(d_gam, true, false, false)
        B = isRGBi ? ExtractB() : B.ConvertBits(32, fulls=true,  fulld=true).CCTF(d_gam, true, false, false)



        mata = RGB_to_XYZ (cs_in,  CAT=="Simulation" ? D_out : D_in,  LMS=LMS, list=true, adaptXYZ=CAT!="CAT")
        matw = CAT        (D_in,                       D_out,         LMS=LMS, list=true)
        matb = XYZ_to_RGB (cs_out, CAT=="Simulation" ? D_in  : D_out, LMS=LMS, list=true, adaptXYZ=CAT!="CAT")
        mat  = MatrixDot(isIllu && CAT=="CAT" ? MatrixDot(mata, MatrixTranspose(matw)) : mata, matb)

        Ro = "x "+string(mat[0])+" * y "+string(mat[3])+" * + z "+string(mat[6])+" * +"
        Go = "x "+string(mat[1])+" * y "+string(mat[4])+" * + z "+string(mat[7])+" * +"
        Bo = "x "+string(mat[2])+" * y "+string(mat[5])+" * + z "+string(mat[8])+" * +"

        if (!isRGBo && !Comp) {

            Ro = Expr(R, G, B, Ro, optSingleMode=true, clamp_float=false)
            Go = Expr(R, G, B, Go, optSingleMode=true, clamp_float=false)
            Bo = Expr(R, G, B, Bo, optSingleMode=true, clamp_float=false)
            R = Ro  G = Go  B = Bo

        } else {

            Expr(R, G, B, Ro, Go, Bo, Format="RGBPS", optSingleMode=true, clamp_float=false)

            if (Comp) {

                # 'Desaturate' Gamut Compression (by John Walker: https://www.fourmilab.ch/documents/specrend)
                RGB = ExtractClip()
                OF  = "x 0 min y min z min neg dup dup x +"
                Expr(RGB[0], RGB[1], RGB[2], OF+" X@ swap2 y +    swap z +    max max dup 1 > X swap swap2 / X ?", \
                                             OF+"    swap2 y + Y@ swap z +    max max dup 1 > Y swap swap2 / Y ?", \
                                             OF+"    swap2 y    + swap z + Z@ max max dup 1 > Z swap swap2 / Z ?", Format="RGBPS", optSingleMode=true, clamp_float=false)

        } }

    if (isRGBo && isRGBi && isScale) {

        RGB  = space == "linear"  ? last                            : \
               space == "sigmoid" ? ex_contrast(-1.15,1,191,false)  : \
               space == "log"     ? ACEScct_r(UV=3,false,false)     : \
               OETF  == "linear"                                    ? \
               EOTF  != "linear"  ? CCTF(isGamma ? EOTF2 : "470M", false, false, !(isGamma || !tv_out)) : last : last


        RGBm  = nomoir ? RGB.ex_blur((1. / rat) / 2.,mode="gaussian") : RGB
        RGBnr = ReplaceStr(ReplaceStr(Ynr, "(Ym,", "(RGBm,"), "(Y,", "(RGB,")
        RGB   = Eval("RGBm." + resampler + cplaceY + (noring && !deep2 ? RGBnr : ""))
        RGB   = noring && deep2 ? Eval(RGBnr) : RGB

               space == "linear"  ? RGB.                              CCTF(EOTF, false, false, tv_out) : \
               space == "sigmoid" ? RGB.ex_contrast(1.15,1,191,false).CCTF(EOTF, false, false, tv_out) : \
               space == "log"     ? RGB.ACEScct_f(UV=3,false,false).  CCTF(EOTF, false, false, tv_out) : \
               OETF  == "linear"                                                                       ? \
               EOTF  != "linear" && !isGamma ? RGB.CCTF("470M",true, false, tv_out) : RGB : RGB

        tv_in != tv_out && space == "gamma" && !isGamma ? \
        ConvertBits(bi,dither=bi==32?-1:1,fulls=true,fulld=!tv_out) : last

        } else if (isRGBo) {

               EOTF!="linear" ? CCTF(EOTF, false, false, tv_out) : last
               ConvertBits(bi,dither=bi==32?-1:1,fulls=EOTF=="linear" ? true : !tv_out, fulld=!tv_out)

        } }


    if (!isRGBo && isSpaIllu || isRGBi && isFrmt) {

        ArEx = "Y  = YCbCr[0]  Cb = YCbCr[1]  Cr = YCbCr[2]"
        ArEx = o_fmt0!="YCbCr" ? ArEx : "YCbCr"

        RGBlin    = (isRGBi && OETF=="linear" && !tv_in)
        isSpaIllu = RGBlin || isSpaIllu
        R = RGBlin || isRGBi ? ExtractR() : R
        G = RGBlin || isRGBi ? ExtractG() : G
        B = RGBlin || isRGBi ? ExtractB() : B

        tv_ir =  propGetInt(R,"_ColorRange")==1

        R = isSpaIllu ? R.CCTF(EOTF2, false, tv_ir, false) : R    R = R.ConvertBits(bi,dither=bi==32?-1:1)
        G = isSpaIllu ? G.CCTF(EOTF2, false, tv_ir, false) : G    G = G.ConvertBits(bi,dither=bi==32?-1:1)
        B = isSpaIllu ? B.CCTF(EOTF2, false, tv_ir, false) : B    B = B.ConvertBits(bi,dither=bi==32?-1:1)

        arc = isScale || isGamma || o_fmt[1]=="444" && isJab

        if (o_fmt0=="YcCbcCrc" || cs_out == "2020CL") {

                YCbCr = RGB_to_YcCbcCrc( R, G, B, cs_out, coef_o, tv_ir, tv_out)

            } else if (o_fmt0=="YCoCg") {

                YCbCr = RGB_to_YCoCg   ( R, G, B, tv_ir, tv_out, arc)

            } else if (o_fmt0=="YCoCgR") {

                YCbCr = RGB_to_YCoCgR  ( R, G, B, tv_ir, tv_out, arc)

            } else if (o_fmt0=="YUVr") {

                YCbCr = RGB_to_YUVr    ( R, G, B, tv_ir, tv_out, arc)

            } else if (o_fmt0=="OkLab") {

                # Requires Range conversion
                YCbCr = RGB_to_Oklab   ( R, G, B, false, cs_in, arc)

            } else if (o_fmt0=="HSV") {

                # Requires Range conversion
                YCbCr = RGB_to_HSV     ( R, G, B, tv_ir, arc)

            } else if (i_fmt[0]=="CIELab") {

                # Requires Range conversion
                Lmat  = RGB_to_XYZ( R, cs_in, D_in, true)
              # XYZ   = DotClip(Lmat
                YCbCr = XYZ_to_Lab( XYZ, Array=arc)

            } else if (i_fmt[0]=="Yxy") {

                # Requires Range conversion
                RGB = Yxy_to_RGB( Y, Cb, Cr, isSpaIllu, arc)

            } else if (o_fmt0=="OPP") {

                # Requires Range conversion
                YCbCr = RGB_to_OPP( R, G, B, arc)

            } else if (o_fmt0=="ICtCp") {

                # Requires Range conversion
                YCbCr = RGB_to_ICtCp( R, G, B, cs_in, arc)

            } else if (o_fmt0=="YCbCr") {

            scale_y   = isRGBi && (isScale || isGamma) ? isSpaIllu || !tv_ir ? 1.0 : 256/219. : tv_ir != tv_out ? tv_ir ? 256/219. : 219/256. : 1.0
            scale_uv  =                                                                         tv_ir != tv_out ? tv_ir ? 256/112. : 112/256. : 0.5

            Kr = 1. - coef_o[0]
            Kb = 1. - coef_o[2]

            m0 = scale_y  *   coef_o[0]       m1 = scale_y  *   coef_o[1]         m2 = scale_y  *   coef_o[2]
            m3 = scale_uv * (-coef_o[0] / Kb) m4 = scale_uv * (-coef_o[1] / Kb)   m5 = scale_uv
                                              m7 = scale_uv * (-coef_o[1] / Kr)   m8 = scale_uv * (-coef_o[2] / Kr)

            rangeY_TV = scale_y ==219/256. ? "ymin +" : \
                        scale_y ==256/219. ? "ymin -" : ""
            rangeC_TV = bi < 32            ? "range_half +" : ""

            Y  = Expr(R, G, B, ex_dlut("x "+string(m0)+" * y "+string(m1)+" * + z "+string(m2)+" * + "+rangeY_TV+"", bi, false), optSingleMode=true)
            Cb = Expr(R, G, B, ex_dlut("x "+string(m3)+" * y "+string(m4)+" * + z "+string(m5)+" * + "+rangeC_TV+"", bi, false), optSingleMode=true)
            Cr = Expr(R, G, B, ex_dlut("x "+string(m5)+" * y "+string(m7)+" * + z "+string(m8)+" * + "+rangeC_TV+"", bi, false), optSingleMode=true)

        }

        Eval("ArEx")

        if (isRGBi && isScale) {

            Y     =            \
            space == "linear"  ? Y.CCTF(isSpaIllu ? EOTF2 : OETF,  true, false, false)                                       : \
            space == "sigmoid" ? Y.CCTF(isSpaIllu ? EOTF2 : OETF,  true, false, false).ex_contrast(-1.15,1,191,false)        : \
            space == "log"     ? Y.CCTF(isSpaIllu ? EOTF2 : OETF,  true, false, false).ACEScct_r()                           : \
            OETF  == "linear"  ?                                                                                               \
            EOTF  != "linear"  ? Y.CCTF(isSpaIllu ? EOTF2 : OETF, false, false, false) : Y.CCTF("470M", false, false, false) : Y

            }

        Cb   = Eval("Cb." + resampler_c + cplaceC2)
        Cr   = Eval("Cr." + resampler_c + cplaceC2)

        if (isRGBi && (isScale || isGamma)) {
            Ym   = nomoir ? Y.ex_blur((1. / rat) / 2., mode="gaussian") : Y
            Y    = Eval("Ym." + resampler + cplaceY + (noring && !deep2 ? Ynr : ""))
            Y    = noring && deep2 ? Eval(Ynr) : Y

            Y     =            \
            space == "linear"  ? Y.                                CCTF(EOTF,  false, false, tv_out) : \
            space == "sigmoid" ? Y.ex_contrast(1.15,1,191,false,1).CCTF(EOTF,  false, false, tv_out) : \
            space == "log"     ? Y.ACEScct_f(UV=1,false,false).    CCTF(EOTF,  false, false, tv_out) : \
            OETF  == "linear"  ?                                                                       \
            EOTF  != "linear"  ? Y                             : Y.CCTF("470M", true, false, tv_out) : \
            isGamma && !isSpaIllu ?                              Y.CCTF(OETF,   true, false, false ).  \
                                                                   CCTF(EOTF,  false, false, tv_out) : tv_in != tv_out ? Y.SMPTE_legal(tv_out) : Y
            }

        CombinePlanes(Y, Cb, Cr, planes="YUV", pixel_type="YUV"+o_fmt1+o_fmt[2])

        } }

        # Frame Properties (fix this when using presets)
        mat_i   = isRGBo ? 0 : num==0 ? cs_outFA[3] : color_Fuzzy_Search(cs_outFA)[3]
        prim_i  =              num==0 ? cs_outFA[4] : color_Fuzzy_Search(cs_outFA)[4]
        illu_i  =              num==0 ? D_outA[5]   : color_Fuzzy_Search(D_out)[5]
        t_i     =              num==0 ? EOTFi_i[6]  : color_Fuzzy_Search(EOTF)[6]

        # Populating frameprops
        if (!isy) {
        !isRGBo             ? propSet("_Matrix",      mat_i)       : last # Yes, again, hardcoding matrix for RGB to 0
                              propSet("_Primaries",  prim_i)
        isIllu              ? propSet("_Illuminant", illu_i)       : last
        o_type1 || o_type10 ? last : !isChP ? propCopy(clp,true,props="_ChromaLocation") : propSet("_ChromaLocation", cplace2[4]) } # 1/4 subsampling formats don't support '_ChromaLocation' frameprop
                              propSet("_Transfer",      t_i)
                              propSet("_ColorRange",    tv_out ? 1 : 0)

        # Show panel
        if (dg) {

            # EOTF curve plot
            msize = min(nw,nh)
            sw  = nmod(nw/5.)   sh = sw
            plt = GradientLinear(last, zoom=1, positive=true, precision=4, smooth=true, tv_range=tv_in)
            plt = plt.CCTF(EOTF2, false, tv_in, tv_out)  # Might need to ExtractY()
            plt = plt.HistoCurve(size=4,gradient=false).BicubicResize(sw,sh,-0.5,0.25).Subtitle("EOTFi: "+EOTF,size=msize/40)
            plt = isRGBo ? plt.ConvertToPlanarRGB() : plt
            plt = Merge(PadBorders(plt,nw-sw,0,0,nh-sh))
            ex_merge(plt,BoxMask(nw-sw,nw,0,sh),UV=3)


            i_jab  = i_fmt[1]  i_fmt  = i_fmt[0]
            o_jab  = o_fmt1    o_fmt  = o_fmt0
            c_col  = cplace2[0]+src_leftc  c_in = cplace2[2]
            c_cot  = cplace2[1]+src_topc   c_ou = cplace2[3]
            kernel = UCase(LeftStr(kernel,  1))+MidStr(kernel,  2) # Sentence Case
            kernel = ReplaceStr(kernel, "ewas","EWAS",dg).ReplaceStr("ewa","EWA",dg).ReplaceStr("ssim","SSIM",dg).ReplaceStr("dpid","DPID",dg).ReplaceStr("fsrcnn","FSRCNN",dg).ReplaceStr("fcbi","FCBI",dg).ReplaceStr("nnedi","nnedi",dg)
            kernelc= UCase(LeftStr(kernel_c,1))+MidStr(kernel_c,2) # Sentence Case
            kernelc= ReplaceStr(kernelc,"ewas","EWAS",dg).ReplaceStr("ewa","EWA",dg).ReplaceStr("ssim","SSIM",dg).ReplaceStr("dpid","DPID",dg).ReplaceStr("fsrcnn","FSRCNN",dg).ReplaceStr("fcbi","FCBI",dg).ReplaceStr("nnedi","nnedi",dg)
            y_cof  = (kernel   == "bicubic" ? string(bc_b, "%1.2f")+","+string(bc_c, "%1.2f") : krny[3] > 0 ? isInt(krny[3]) ? string(krny[3]) : string(krny[3],"%1.3f") : "")  y_cof = y_cof == "" ? "" : (StrLen(y_cof)>2 && StrLen(kernel) <10 ? "" : "     ")+"["+y_cof+"]"
            u_cof  = (kernel_c == "bicubic" ? string(bch_b,"%1.2f")+","+string(bch_c,"%1.2f") : krnc[3] > 0 ? isInt(krnc[3]) ? string(krnc[3]) : string(krnc[3],"%1.3f") : "")  u_cof = u_cof == "" ? "" : (StrLen(u_cof)>2 && StrLen(kernelc)<10 ? "" : "     ")+"["+u_cof+"]"
            tv_i   = tv_in  ? "Lim" : "Full"
            tv_o   = tv_out ? "Lim" : "Full"
            prp    = color_propGet (prim_i, illu_i, mat_i, t_i)
            cs_out = prp[2]
            D_out  = prp[3]
            EOTF   = prp[5]

            bg     = BoxMask(0,round(msize/1.55),0,round(msize/1.15),invert=true, tv_out=tv_out)
            ex_blend(bg,"multiply",opacity=0.5,tv_range=tv_out)

            Subtitle("ConvertFormat() 1.5",                     size=msize/16,lsp=4,text_color=$00aef0,font="Segoe UI")
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
                           +"{recon}"),           x=msize/4,    size=msize/25,lsp=4)
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
                           +u_cof+" \n "),        x=msize/2.25, size=msize/25,lsp=4)
    } }








##########################################
###                                     ##
###      DATA RETRIEVAL FUNCTIONS       ##
###                                     ##
##########################################

# color_propGet: Reads Model, Primaries, Matrix, Standard Illuminant and Transfer frame properties from input, or infer them.
# color_Fuzzy_Search: Input a Primaries, Standard Illuminant or Transfer string, and get an array with inferred standardized names -strings- and their property ID -int- for the different space characteristics.
# format_Fuzzy_Search: Second pass of above. Will search for input model and Jab and their IDs and override primaries and matrix IDs based on model.
#
# xxx_Fuzzy_Search family infers input/output properties from input string, while color_propGet() infers them directly from frame properties or clip characteristics.


# Matrix, Primaries, Standard Illuminant and Transfer strings fuzzy search. Input: string, Output: [string,string,string,ID,ID,ID,ID]
function color_Fuzzy_Search (string matrix) {

    matrix = UCase(matrix)
    matrixn =
\     FindStr(matrix,   "709"  )>0 ? "709"        :         matrix == "HDTV"     ? "709"
\   :         matrix == "sRGB"     ? "sRGB"       :         matrix == "XYZ"      ? "XYZ"
\   :         matrix == "SDTV"     ? "170M"       : FindStr(matrix,   "274"  )>0 ? "170M"
\   : FindStr(matrix,   "170"  )>0 ? "170M"       : FindStr(matrix,   "601"  )>0 ? "170M"
\   : FindStr(matrix,   "525"  )>0 ? "170M"       :         matrix == "jpeg"     ? "170M"
\   :         matrix == "jpg"      ? "170M"       :         matrix == "NTSC"     ? "170M"
\   :         matrix == "SMPTE-C"  ? "170M"       :         matrix == "YPbPr"    ? "170M"
\   :         matrix == "YCC"      ? "709"        :         matrix == "YUV"      ? "709"
\   :         matrix == "sYCC"     ? "709"        :         matrix == "YCbCr"    ? "709"
\   : FindStr(matrix,   "NCL"  )>0 ? "2020NCL"    : FindStr(matrix,   "20-10")>0 ? "2020NCL"
\   : FindStr(matrix,   "CL"   )>0 ? "2020CL"     : FindStr(matrix,   "20-12")>0 ? "2020CL"
\   : FindStr(matrix,   "2020" )>0 ? "2020NCL"    : FindStr(matrix,   "2084" )>0 ? "2020CL"
\   : FindStr(matrix,   "2100" )>0 ? "2020CL"     : FindStr(matrix,   "DOVI" )>0 ? "2020DV5"
\   : FindStr(matrix,   "VISION")>0? "2020DV5"    : FindStr(matrix,   "2085" )>0 ? "YDzDx"
\   :         matrix == "AdobeWideGamut" ? "AWG"  :         matrix == "AWG"      ? "AWG"
\   : FindStr(matrix,   "ADOBE")>0 ? "AdobeRGB"   :         matrix == "opRGB"    ? "AdobeRGB"
\   :         matrix == "opYCC"    ? "AdobeRGB"   : FindStr(matrix,   "DCI"  )>0 ? "DCI-P3"
\   : FindStr(matrix,   "CLAY" )>0 ? "AdobeRGB"   :         matrix == "P3D65"    ? "Display-P3"
\   :         matrix == "P3"       ? "Display-P3" :         matrix == "AP1"      ? "ACEScg"
\   : FindStr(matrix,   "DISPLAY")>0?"Display-P3" :         matrix == "ACEScg"   ? "ACEScg"
\   :         matrix == "AP0"      ? "ACES2065"   : FindStr(matrix,   "ACES2")>0 ? "ACES2065"
\   :         matrix == "ACESCCt"  ? "ACESCCt"    :         matrix == "PAL"      ? "470BG"
\   : FindStr(matrix,   "240"  )>0 ? "240M"       :         matrix == "NTSC-M"   ? "470M"
\   :         matrix == "SECAM"    ? "470BG"      : FindStr(matrix,   "470M" )>0 ? "470M"
\   :         matrix == "FCC"      ? "470M"       : FindStr(matrix,   "1701" )>0 ? "470BG"
\   : FindStr(matrix,   "470"  )>0 ? "470BG"      : FindStr(matrix,   "APPLE")>0 ? "AppleRGB"
\   : FindStr(matrix,   "625"  )>0 ? "470BG"      : FindStr(matrix,   "RUSSELL")>0?"RussellRGB"
\   : FindStr(matrix,   "WIDE" )>0 ? "WideGamut"  : FindStr(matrix,   "BEST" )>0 ? "BestRGB"
\   : FindStr(matrix,   "DON"  )>0 ? "DonRGB4"    : FindStr(matrix,   "BRUCE")>0 ? "BruceRGB"
\   : FindStr(matrix,   "BETA" )>0 ? "BetaRGB"    : FindStr(matrix,   "MATCH")>0 ? "ColorMatch"
\   : FindStr(matrix,   "ECI"  )>0 ? "ECI-RGB"    : FindStr(matrix,   "PHOTO")>0 ? "ProPhoto"
\   : FindStr(matrix,   "CIE"  )>0 ? "CIE RGB"    : FindStr(matrix,   "LARGE")>0 ? "ProPhoto"
\   :         matrix == "NTSCJ"    ? "NTSC-J"     :         matrix == "Melissa"  ? "ProPhoto"
\   :         matrix == "OOO"      ? "OPP"        :         matrix == "NTSC-J"   ? "NTSC-J"
\   :         matrix == "OPP"      ? "OPP"        : FindStr(matrix,   "ALL"  )>0 ? "AllColorsRGB"
\   : FindStr(matrix,   "MAX"  )>0 ? "MaxRGB"     : FindStr(matrix,   "EKTA" )>0 ? "EktaSpacePS5"
\   : FindStr(matrix,   "XTREM")>0 ? "xTremeRGB"  : FindStr(matrix,  "CHROME")>0 ? "ChromeSpace100" : ""


# * 'Melissa' is ProPhoto with sRGB transfer as defined in Adobe Lightroom
# * ST 2084 or ARIB STD-B67 are the names of the normative/paper not the transfer function (PQ and HLG respectively)
    transfer =
\     FindStr(matrix,   "2084"  )>0  ? "PQ"       : FindStr(matrix,   "2100"   )>0 ? "PQ"
\   :         matrix == "PQ"         ? "PQ"       :         matrix == "Perceptual" ? "PQ"
\   :         matrix == "2020DVp5"   ? "PQ"       : FindStr(matrix,   "BBC"   )>0  ? "HLG ARIB"
\   :         matrix == "HLG"        ? "HLG"      : FindStr(matrix,   "NHK"   )>0  ? "HLG ARIB"
\   : FindStr(matrix,   "ARIB"  )>0  ? "HLG ARIB" : FindStr(matrix,   "B67"   )>0  ? "HLG ARIB"
\   :         matrix == "1886a"      ? "1886a"    : FindStr(matrix,   "1886"   )>0 ? "1886"
\   : FindStr(matrix,   "428"   )>0  ? "DCIXYZ"   : FindStr(matrix,   "APPLE"  )>0 ? "AppleRGB"
\   :         matrix == "Camera"     ? "170M"     :         matrix == "709-Camera" ? "170M"
\   :         matrix == "linear"     ? "linear"   :         matrix == "L*"         ? "CIELab"
\   :         matrix == "Lstar"      ? "CIELab"   :         matrix == "CIELab"     ? "CIELab"
\   :         matrixn== "170M"       ? "170M"     :         matrix == "Melissa"    ? "sRGB"
\   :         matrixn== "2020CL"     ? "1886"     :         matrixn== "2020DV5"    ? "PQ"
\   :         matrixn== "240M"       ? "240M"     :         matrixn== "2020NCL"    ? "1886"
\   :         matrixn== "470M"       ? "470M"     :         matrixn== "470BG"      ? "470BG"
\   :         matrixn== "ACES2065"   ? "linear"   :         matrixn== "709"        ? "1886"
\   :         matrixn== "ACESCCt"    ? "ACESCCt"  :         matrixn== "ACEScg"     ? "linear"
\   :         matrixn== "AWG"        ? "AdobeRGB" :         matrixn== "AdobeRGB"   ? "AdobeRGB"
\   :         matrixn== "Display-P3" ? "sRGB"     :         matrixn== "DCI-P3"     ? "DCIXYZ"
\   :         matrixn== "sRGB"       ? "sRGB"     :         matrixn== "OPP"        ? "sRGB"
\   :         matrixn== "BestRGB"    ? "AdobeRGB" :         matrixn== "RussellRGB" ? "AdobeRGB"
\   :         matrixn== "DonRGB4"    ? "AdobeRGB" :         matrixn== "BruceRGB"   ? "AdobeRGB"
\   :         matrixn== "ECI-RGB"    ? "CIELab"   :         matrixn== "BetaRGB"    ? "AdobeRGB"
\   :         matrixn== "ColorMatch" ? "AppleRGB" :         matrixn== "CIE RGB"    ? "AdobeRGB"
\   :         matrixn== "NTSC-J"     ? "1886"     :         matrixn== "WideGamut"  ? "AdobeRGB"
\   :         matrixn== "XYZ"        ? "linear"   :         matrixn== "ProPhoto"   ? "AppleRGB"
\   :         matrixn== "YDzDx"      ? "PQ"       :         matrixn=="AllColorsRGB"? "linear"
\   :         matrixn== "MaxRGB"     ? "AdobeRGB" :         matrixn=="EktaSpacePS5"? "AdobeRGB"
\   :         matrixn== "ChromeSpace100"?"Chrome" :         matrixn=="xTremeRGB"   ? "AdobeRGB"
\   :         matrix == "XYB"        ? "XYB"      : matrixn

    illuminant =
\             matrix == "50"         ? "D50"      :         matrix == "A"          ? "A"
\   :         matrix == "55"         ? "D55"      :         matrix == "D50"        ? "D50"
\   : FindStr(matrixn,  "ACES"   )>0 ? "ACES"     :         matrix == "D55"        ? "D55"
\   :         matrix == "60"         ? "D60"      :         matrix == "D65"        ? "D65"
\   :         matrix == "65"         ? "D65"      :         matrix == "B"          ? "B"
\   :         matrix == "D"          ? "D65"      :         matrix == "C"          ? "C"
\   :         matrix == "75"         ? "D75"      :         matrix == "D75"        ? "D75"
\   :         matrix == "93"         ? "D93"      :         matrix == "D93"        ? "D93"
\   :         matrix == "DCI"        ? "DCI"      :         matrix == "EE"         ? "E"
\   :         matrix == "ID50"       ? "ID50"     :         matrix == "ID65"       ? "ID65"
\   :         matrix == "E"          ? "E"        :         matrix == "Equal"      ? "E"
\   :         matrix == "Neutral"    ? "E"        :         matrix == "Sun"        ? "Sunlight"
\   :         matrix == "null"       ? "E"        :         matrix == "Sunlight"   ? "Sunlight"
\   :         matrix == "Overcast"   ? "Overcast" :         matrixn== "170M"       ? "D65"
\   :         matrixn== "2020CL"     ? "D65"      :         matrixn== "2020DV5"    ? "D65"
\   :         matrixn== "2020NCL"    ? "D65"      :         matrixn== "240M"       ? "D65"
\   :         matrixn== "470BG"      ? "D65"      :         matrixn== "470M"       ? "C"
\   :         matrixn== "709"        ? "D65"      :         matrixn== "ACES2065"   ? "ACES"
\   :         matrixn== "AdobeRGB"   ? "D65"      :         matrixn== "AWG"        ? "D50"
\   :         matrixn== "DCI-P3"     ? "DCI"      :         matrixn== "Display-P3" ? "D65"
\   :         matrixn== "OPP"        ? "D65"      :         matrixn== "sRGB"       ? "D65"
\   :         matrixn== "AppleRGB"   ? "D65"      :         matrixn== "RussellRGB" ? "D55"
\   :         matrixn== "BestRGB"    ? "D50"      :         matrixn== "BruceRGB"   ? "D65"
\   :         matrixn== "DonRGB4"    ? "D50"      :         matrixn== "BetaRGB"    ? "D50"
\   :         matrixn== "ECI-RGB"    ? "D50"      :         matrixn== "CIE RGB"    ? "E"
\   :         matrixn== "ColorMatch" ? "D50"      :         matrixn== "WideGamut"  ? "D50"
\   :         matrixn== "ProPhoto"   ? "D50"      :         matrixn== "NTSC-J"     ? "D93"
\   :         matrixn== "XYZ"        ? "E"        :         matrixn=="AllColorsRGB"? "D50"
\   :         matrixn== "YDzDx"      ? "E"        :         matrixn=="EktaSpacePS5"? "D50"
\   :         matrixn== "MaxRGB"     ? "D50"      :         matrixn== "xTremeRGB"  ? "D50"
\   :         matrixn== "ChromeSpace100" ? "D50"  : matrixn

    # ID for _Matrix frame properties (BT.2380-2. Table 2.8)
    idm =
\             matrixn == "XYZ"             ? 0    :         matrixn == "AdobeRGB"        ? 17
\   :         matrixn == "RGB"             ? 0    :         matrixn == "AWG"             ? 18
\   :         matrixn == "sRGB"            ? 1    :         matrixn == "WideGamut"       ? 19
\   :         matrixn == "709"             ? 1    :         matrixn == "AppleRGB"        ? 20
\   :         matrixn == "470M"            ? 4    :         matrixn == "ProPhoto"        ? 21
\   :         matrixn == "470BG"           ? 5    :         matrixn == "AllColorsRGB"    ? 22
\   :         matrixn == "170M"            ? 6    :         matrixn == "ColorMatch"      ? 23
\   :         matrixn == "240M"            ? 7    :         matrixn == "RussellRGB"      ? 24
\   :         matrixn == "2020NCL"         ? 9    :         matrixn == "BestRGB"         ? 25
\   :         matrixn == "2020CL"          ? 10   :         matrixn == "BruceRGB"        ? 26
\   :         matrixn == "YDzDx"           ? 11   :         matrixn == "DonRGB4"         ? 27
\   :         matrixn == "DCI-P3"          ? 12   :         matrixn == "BetaRGB"         ? 28
\   :         matrixn == "Display-P3"      ? 12   :         matrixn == "ECI-RGB"         ? 29
\   :         matrixn == "NTSC-J"          ? 13   :         matrixn == "EktaSpacePS5"    ? 30
\   :         matrixn == "ACEScg"          ? 14   :         matrixn == "CIE RGB"         ? 31
\   :         matrixn == "ACES2065"        ? 15   :         matrixn == "xTremeRGB"       ? 32
\   :         matrixn == "ACESCCt"         ? 16   :         matrixn == "MaxRGB"          ? 33
\   :         matrixn == "ChromeSpace100"  ? 34   :         -1
# * YDzDx is defined in SMPTE 2085


    # ID for _Primaries frame properties (BT.2380-2. Table 2.6)
    ids =
\     (matrixn    == "2020CL"      ) ? 9
\   : (matrixn    == "DCI-P3"      ) ? 11 : idm

    # ID for _Illuminant frame properties
    idi =
\     (illuminant == "A"           ) ? 13
\   : (illuminant == "B"           ) ? 14
\   : (illuminant == "D50"         ) ? 0
\   : (illuminant == "D55"         ) ? 1
\   : (illuminant == "ACES"        ) ? 9
\   : (illuminant == "D60"         ) ? 2
\   : (illuminant == "DCI"         ) ? 3
\   : (illuminant == "D65"         ) ? 4
\   : (illuminant == "C"           ) ? 5
\   : (illuminant == "D75"         ) ? 6
\   : (illuminant == "D93"         ) ? 7
\   : (illuminant == "E"           ) ? 8
\   : (illuminant == "Sunlight"    ) ? 11
\   : (illuminant == "Overcast"    ) ? 12
\   : (illuminant == "ID50"        ) ? 15
\   : (illuminant == "ID65"        ) ? 16 : -1

    # ID for _Transfer frame properties (BT.2380-2. Table 2.7)
    idt =
\     (transfer   == "1886a"       ) ? 0
\   : (transfer   == "1886"        ) ? 1
\   : (transfer   == "470M"        ) ? 4
\   : (transfer   == "470BG"       ) ? 5
\   : (transfer   == "170M"        ) ? 6
\   : (transfer   == "709-Camera"  ) ? 6
\   : (transfer   == "240M"        ) ? 7
\   : (transfer   == "linear"      ) ? 8
\   : (transfer   == "log100"      ) ? 9
\   : (transfer   == "log316"      ) ? 10
\   : (transfer   == "xvYCC"       ) ? 11
\   : (transfer   == "1361"        ) ? 12
\   : (transfer   == "sRGB"        ) ? 13
\   : (transfer   == "2020NCL"     ) ? 14
\   : (transfer   == "2020CL"      ) ? 15
\   : (transfer   == "PQ"          ) ? 16
\   : (transfer   == "DCIXYZ"      ) ? 17
\   : (transfer   == "HLG"         ) ? 18
\   : (transfer   == "HLG ARIB"    ) ? 19
\   : (transfer   == "AdobeRGB"    ) ? 20
\   : (transfer   == "ACESCCt"     ) ? 21
\   : (transfer   == "AppleRGB"    ) ? 22
\   : (transfer   == "CIELab"      ) ? 23
\   : (transfer   == "Chrome"      ) ? 24
\   : (transfer   == "XYB"         ) ? 25 : -1
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
    prim_i   = prim_i !=  2 ? prim_i : fmt[6] != -1 ? fmt[6] : 2
    mat_i    = mat_i  !=  2 ? mat_i  : fmt[5] != -1 ? fmt[5] : 3 < prim_i  < 10 ?  prim_i : cm_i == 15 || prim_i == 11 ? 11 : prim_i == 12 ? 12 : 2
    prim_i   = prim_i !=  2 ? prim_i : 0 > mat_i > 8 || 10 > mat_i > 13 ? mat_i : isUHD ? 9 : isHD ? 1 : FR==25 ? 5 : FR==29.970 ? 6 : 2
    mat_i    = mat_i  !=  2 ? mat_i  :                         3 < prim_i  < 10 ?  prim_i : cm_i == 15 || prim_i == 11 ? 11 : prim_i == 12 ? 12 : 1
    prim_i   = prim_i !=  2 ? prim_i : 0 > mat_i > 8 || 10 > mat_i > 13 ? mat_i : 1

    illu_i   = illu_i != -1 ? illu_i :                             20 > prim_i > 34 ? 0 : prim_i == 11 || mat_i == 11 ? 3 : 13 > prim_i > 17 ? 2 : \
                                                                   prim_i == 20 ? 1 : prim_i == 13 ? 7 : prim_i == 10 || prim_i == 34 ? 8 : \
                                                                   prim_i == 4 || mat_i == 4 ? 5 : 4
    t_i      = t_i    !=  2 ? t_i    :                             cm_i == 0 || cm_i == 23 ? 8 : \
                                                                   cm_i == 24 ? 11 : \
                                                               3 < prim_i  < 8  ?  prim_i : \
                                                                   prim_i == 18 || prim_i == 23 || prim_i == 25 ? 18 : \
                                                                   prim_i == 29 ? 23 : \
                                                                   prim_i == 33 ? 24 : \
                                                              16 > prim_i  > 35 ? 20 : \
                                                                   prim_i == 10 || prim_i == 13 || prim_i == 15 ? 8 : \
                                                                   prim_i == 16 ? 21 : \
                                                                   prim_i == 9  ? 16 : \
                                                                   prim_i == 11 ? 17 : \
                                                                   prim_i == 12 ? 13 : 1
    cm_id =
\     (cm_i == 0      ) ? ["XYZ",      "RGB"  ]   :   (cm_i == 22     ) ? ["IPTPQc2",  "YCbCr"]
\   : (cm_i == 1      ) ? ["RGB",      "RGB"  ]   :   (cm_i == 23     ) ? ["Yxy",      "RGB"  ]
\   : (cm_i == 2      ) ? ["CMYK",     "RGBA" ]   :   (cm_i == 24     ) ? ["xvYCC",    "YCbCr"]
\   : (cm_i == 3      ) ? ["YIQ",      "YCbCr"]   :   (cm_i == 25     ) ? ["HSV",      "RGB"  ]
\   : (cm_i == 4      ) ? ["YCbCr",    "YCbCr"]   :   (cm_i == 26     ) ? ["HunterLab","YCbCr"]
\   : (cm_i == 5      ) ? ["YUVr",     "YCbCr"]   :   (cm_i == 27     ) ? ["CIELab",   "YCbCr"]
\   : (cm_i == 6      ) ? ["sYUV",     "YCbCr"]   :   (cm_i == 28     ) ? ["CIELch",   "RGB"  ]
\   : (cm_i == 7      ) ? ["YUVJ",     "YCbCr"]   :   (cm_i == 29     ) ? ["CIELuv",   "YCbCr"]
\   : (cm_i == 8      ) ? ["sYCC",     "YCbCr"]   :   (cm_i == 30     ) ? ["CIELchuv", "RGB"  ]
\   : (cm_i == 9      ) ? ["YCoCg",    "YCbCr"]   :   (cm_i == 31     ) ? ["CIEDuDv",  "YCbCr"]
\   : (cm_i == 10     ) ? ["YCoCgR",   "YCbCr"]   :   (cm_i == 32     ) ? ["CIECAM97s","YCbCr"]
\   : (cm_i == 11     ) ? ["YcCbcCrc", "YCbCr"]   :   (cm_i == 33     ) ? ["CIECAM02", "YCbCr"]
\   : (cm_i == 12     ) ? ["OPP",      "RGB"  ]   :   (cm_i == 34     ) ? ["CAM16",    "YCbCr"]
\   : (cm_i == 13     ) ? ["Jzazbz",   "YCbCr"]   :   (cm_i == 35     ) ? ["Duv",      "YCbCr"]
\   : (cm_i == 14     ) ? ["JzCzhz",   "YCbCr"]   :   (cm_i == 36     ) ? ["OSA",      "YCbCr"]
\   : (cm_i == 15     ) ? ["YDzDx",    "YCbCr"]   :   (cm_i == 37     ) ? ["OkLab",    "YCbCr"]
\   : (cm_i == 16     ) ? ["YCxCz",    "YCbCr"]   :   (cm_i == 38     ) ? ["OkLch",    "RGB"  ]
\   : (cm_i == 17     ) ? ["IPT",      "YCbCr"]   :   (cm_i == 39     ) ? ["iCAM",     "RGB"  ]
\   : (cm_i == 18     ) ? ["IPTJch",   "YCbCr"]   :   (cm_i == 40     ) ? ["XYB",      "YCbCr"]
\   : (cm_i == 19     ) ? ["ICaCb",    "YCbCr"]   :   (cm_i == 41     ) ? ["YDbDr",    "YCbCr"]
\   : (cm_i == 20     ) ? ["ITP",      "YCbCr"]   :   (cm_i == 42     ) ? ["YUV",      "YCbCr"]
\   : (cm_i == 21     ) ? ["ICtCp",    "YCbCr"]   :   Assert (false, "color_propGet: Unknown _Model ID.")
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
\   : (prim_i == 9    ) ? "2020NCL"
\   : (prim_i == 10   ) ? "XYZ"
\   : (prim_i == 11   ) ? "DCI-P3"
\   : (prim_i == 12   ) ? "Display-P3"
\   : (prim_i == 13   ) ? "NTSC-J"
\   : (prim_i == 14   ) ? "ACEScg"
\   : (prim_i == 15   ) ? "ACES2065"
\   : (prim_i == 16   ) ? "ACESCCt"
\   : (prim_i == 17   ) ? "AdobeRGB"
\   : (prim_i == 18   ) ? "AppleRGB"
\   : (prim_i == 19   ) ? "BruceRGB"
\   : (prim_i == 20   ) ? "RussellRGB"
\   : (prim_i == 21   ) ? "AWG"
\   : (prim_i == 22   ) ? "WideGamut"
\   : (prim_i == 23   ) ? "ProPhoto"
\   : (prim_i == 24   ) ? "AllColorsRGB"
\   : (prim_i == 25   ) ? "ColorMatch"
\   : (prim_i == 26   ) ? "BestRGB"
\   : (prim_i == 27   ) ? "DonRGB4"
\   : (prim_i == 28   ) ? "BetaRGB"
\   : (prim_i == 29   ) ? "ECI-RGB"
\   : (prim_i == 30   ) ? "MaxRGB"
\   : (prim_i == 31   ) ? "xTremeRGB"
\   : (prim_i == 32   ) ? "EktaSpacePS5"
\   : (prim_i == 33   ) ? "ChromeSpace100"
\   : (prim_i == 34   ) ? "CIE RGB"
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
\   : (mat_i == 9     ) ? "2020NCL"
\   : (mat_i == 10    ) ? "2020CL"
\   : (mat_i == 11    ) ? "DCI-P3"
\   : (mat_i == 12    ) ? "Display-P3"
\   : (mat_i == 13    ) ? "YDzDx"
\   : (mat_i == 14    ) ? "ICtCp"
\   : prim_i

    illu_i =
\     (illu_i == 0    ) ? "D50"
\   : (illu_i == 1    ) ? "D55"
\   : (illu_i == 9    ) ? "ACES"
\   : (illu_i == 2    ) ? "D60"
\   : (illu_i == 3    ) ? "DCI"
\   : (illu_i == 4    ) ? "D65"
\   : (illu_i == 5    ) ? "C"
\   : (illu_i == 6    ) ? "D75"
\   : (illu_i == 7    ) ? "D93"
\   : (illu_i == 8    ) ? "E"
\   : (illu_i == 11   ) ? "Sunlight"
\   : (illu_i == 12   ) ? "Overcast"
\   : (illu_i == 13   ) ? "A"
\   : (illu_i == 14   ) ? "B"
\   : (illu_i == 15   ) ? "ID50"
\   : (illu_i == 16   ) ? "ID65"
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
\   : (t_i == 19      ) ? "HLG ARIB"
\   : (t_i == 20      ) ? "AdobeRGB"
\   : (t_i == 21      ) ? "ACESCCt"
\   : (t_i == 22      ) ? "AppleRGB"
\   : (t_i == 23      ) ? "CIELab"
\   : (t_i == 24      ) ? "Chrome"
\   : (t_i == 25      ) ? "XYB"
\   : Assert (false, "color_propGet: Unknown _Transfer ID.")
# * 1, 14, and 15 share the same transfer

    # model, packing, prims, illu, matrix, transfer, tv_range, bitdepth
    [cm_id[0],cm_id[1],prim_i,illu_i,mat_i,t_i,tv_range,bi] }



# Format (Model, Container/Packing, Jab and Bitepth) fuzzy search.
# Also outputs its model ID, and model based matrix and primaries IDs.
function format_Fuzzy_Search (clip c, string format, int bits) {

    # Block not evaluated unless Jab enum fails the search
    rgb  = isRGB(c)
    isy  = isy  (c)
    Up   = rgb || isy ? c : ExtractU(c)
    rw   = width (Up) / float(width (c))
    rh   = height(Up) / float(height(c))
    a    = int  (rw * 4.)
    b    = round(rh-0.01)*a

    str    = ReplaceStr(format+" ", "P8 ", "", true)
    str    = ReplaceStr(str,        "PS ", "", true)
    trhbd  = FindStr   (format, "P1")
    format = trhbd>0 ? LeftStr(format,trhbd-1) : str

    format = TrimAll(UCase(format))

    jab =
\     FindStr(format,"422"     )>0 ? "422"
\   : FindStr(format, "22"     )>0 ? "422"
\   : FindStr(format, "16"     )>0 ? "422"
\   : FindStr(format,"420"     )>0 ? "420"
\   : FindStr(format, "42"     )>0 ? "420"
\   : FindStr(format, "20"     )>0 ? "420"
\   : FindStr(format, "12"     )>0 ? "420"
\   : FindStr(format,"440"     )>0 ? "440"
\   : FindStr(format, "40"     )>0 ? "440"
\   : FindStr(format,"444"     )>0 ? "444"
\   : FindStr(format, "44"     )>0 ? "444"
\   : FindStr(format, "24"     )>0 ? "444"
\   : FindStr(format,"411"     )>0 ? "411"
\   : FindStr(format, "41"     )>0 ? "411"
\   : FindStr(format, "11"     )>0 ? "411"
\   : FindStr(format,"410"     )>0 ? "410"
\   : FindStr(format, "10"     )>0 ? "410"
\   : FindStr(format,"YUV9"    )>0 ? "410"
\
\   : FindStr(format,"RGB"     )>0 ? "444"
\   : FindStr(format,"YXY"     )>0 ? "444"
\   : FindStr(format,"XYY"     )>0 ? "444"
\   : FindStr(format,"XYZ"     )>0 ? "444"
\   : FindStr(format,"XYB"     )>0 ? "444"
\   : FindStr(format,"JZAZBZ"  )>0 ? "444"
\   : FindStr(format,"JZCZHZ"  )>0 ? "444"
\   : FindStr(format,"CIELAB"  )>0 ? "444"
\   : FindStr(format,"CIELUV"  )>0 ? "444"
\   : FindStr(format,"HSV"     )>0 ? "444"
\   : FindStr(format,"ICTCP"   )>0 ? "444"
\   : FindStr(format,"OKLAB"   )>0 ? "444" : "none"


    model  = ReplaceStr(format, jab, "")

    # Store all opposing models in YUV format, otherwise (correlated) as RGB
    # Input Model, Name Normalizing, Packing format, model ID
    cm =
\     FindStr(model, "RGB"    )>0 ? ["RGB",      "RGB", 1]  :          model=="JPEG"       ? ["YCbCr",    "YUV", 4]
\   :         model=="JPG"        ? ["YCbCr",    "YUV", 4]  :          model=="YUVJ"       ? ["YUVJ",     "YUV", 7]
\   :         model=="YCbCr"      ? ["YCbCr",    "YUV", 4]  :          model=="YUV"        ? ["YCbCr",    "YUV", 4]
\   : FindStr(model, "YV"     )>0 ? ["YCbCr",    "YUV", 4]  :  FindStr(model, "DV"     )>0 ? ["YCbCr",    "YUV", 4]
\   :         model=="YCC"        ? ["YCbCr",    "YUV", 4]  :          model=="sYCC"       ? ["sYCC",     "YUV", 8]
\   :         model=="YPbPr"      ? ["YCbCr",    "YUV", 4]  :          model=="DVD"        ? ["YCbCr",    "YUV", 4]
\   :         model=="NTSC"       ? ["YCbCr",    "YUV", 4]  :          model=="YIQ"        ? ["YIQ",      "YUV", 3]
\   :         model=="CRT"        ? ["YIQ",      "YUV", 3]  :          model=="YDbDr"      ? ["YDbDr",    "YUV",41]
\   :         model=="YUVr"       ? ["YUVr",     "YUV", 5]  :          model=="sYUV"       ? ["sYUV",     "YUV", 6]
\   : FindStr(model, "SHARP"  )>0 ? ["sYUV",     "YUV", 6]  :          model=="YcCbcCr"    ? ["YcCbcCrc", "YUV",11]
\   : FindStr(model, "YCCBC"  )>0 ? ["YcCbcCrc", "YUV",11]  :          model=="YCgCo"      ? ["YCoCg",    "YUV", 9]
\   :         model=="YCgCoR"     ? ["YCoCgR",   "YUV",10]  :          model=="YCoCg"      ? ["YCoCg",    "YUV", 9]
\   :         model=="YCoCgR"     ? ["YCoCgR",   "YUV",10]  :          model=="ICaCb"      ? ["ICaCb",    "YUV",19]
\   :         model=="ICtCp"      ? ["ICtCp",    "YUV",21]  :          model=="IPT"        ? ["IPT",      "YUV",17]
\   :         model=="IPTJch"     ? ["IPTJch",   "YUV",18]  :          model=="Dolby"      ? ["IPTPQc2",  "YUV",22]
\   :         model=="Vision"     ? ["IPTPQc2",  "YUV",22]  :          model=="DoVi"       ? ["IPTPQc2",  "YUV",22]
\   : FindStr(model, "DVP"    )>0 ? ["IPTPQc2",  "YUV",22]  :          model=="YDzDx"      ? ["YDzDx",    "YUV",15]
\   :         model=="YCxCz"      ? ["YCxCz",    "YUV",16]  :          model=="xvYCC"      ? ["xvYCC",    "YUV",24]
\   :         model=="Yxy"        ? ["Yxy",      "RGB",23]  :          model=="xyY"        ? ["Yxy",      "RGB",23]
\   :         model=="XYZ"        ? ["XYZ",      "RGB", 0]  :          model=="CIEXYZ"     ? ["XYZ",      "RGB", 0]
\   :         model=="YZX"        ? ["XYZ",      "RGB", 0]  :          model=="CMYK"       ? ["CMYK",     "RGBA",2]
\   :         model=="OPP"        ? ["OPP",      "RGB",12]  :          model=="Jzazbz"     ? ["Jzazbz",   "YUV",13]
\   :         model=="JzCzhz"     ? ["JzCzhz",   "YUV",14]  :          model=="HSV"        ? ["HSV",      "RGB",24]
\   :         model=="CIEDuv"     ? ["Duv",      "YUV",35]  :          model=="Duv"        ? ["Duv",      "YUV",35]
\   :         model=="OSA"        ? ["OSA",      "YUV",36]  :          model=="XYB"        ? ["XYB",      "YUV",40]
\   : FindStr(model, "PAL"    )>0 ? ["YUV",      "YUV",42]  :  FindStr(model, "625"    )>0 ? ["YUV",      "YUV",42]
\   : FindStr(model, "CAM97"  )>0 ? ["CIECAM97s","YUV",32]  :  FindStr(model, "CAM02"  )>0 ? ["CIECAM02", "YUV",33]
\   : FindStr(model, "CAM16"  )>0 ? ["CAM16",    "YUV",34]  :  FindStr(model, "HUNTER" )>0 ? ["HunterLab","YUV",26]
\   : FindStr(model, "OK"     )>0 ? ["OkLab",    "YUV",37]  :  FindStr(model, "LUV"    )>0 ? ["CIELuv",   "YUV",29]
\   : FindStr(model, "LAB"    )>0 ? ["CIELab",   "YUV",27]  :  FindStr(model, "2000"   )>0 ? ["YUVr",     "YUV", 5]
\   : FindStr(model, "GXL"    )>0 ? ["XYB",      "YUV",40]  :  FindStr(model, "-XL"    )>0 ? ["XYB",      "YUV",40]
\   :         jab  =="420"        ? ["YCbCr",    "YUV", 4]  :          jab  =="422"        ? ["YCbCr",    "YUV", 4]
\   :         format=="444"       ? ["YCbCr",    "YUV", 4]  : rgb ? ["RGB","RGB",1] : ["YCbCr","YUV",4]

    cm0 = cm[0]
    jab = jab=="none"               ?
\     (        cm0=="YCbCr"       ) ? "420"
\   : (        cm0=="YcCbcCrc"    ) ? "420"
\   : (        cm0=="YUVJ"        ) ? "420"
\   : (        cm0=="YCoCg"       ) ? "420"
\   : (        cm0=="YCoCgR"      ) ? "420"
\   : (        cm0=="sYUV"        ) ? "420"
\   : (        cm0=="YUVr"        ) ? "444"
\   : (        cm0=="YDbDr"       ) ? "411"
\   : (        cm0=="YIQ"         ) ? "411"
\   : (        cm0=="YUV"         ) ? "411"
\   : (        cm0=="sYCC"        ) ? "422"
\   : (        cm0=="ICtCp"       ) ? "420"
\   : (        cm0=="IPT"         ) ? "420"
\   : (        cm0=="IPTPQc2"     ) ? "420"
\   :         isy                   ? "444"
\   :                "4"+string(a)+string(b) : jab


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

    #model, jab, bitdepth string, packing, model ID, matrix ID override, prim ID override
    [cm0, jab, bdpth, cm[1], cm[2], ma, pr] }



# Bicubic kernels are very performant but tends to create 'blocking' in upscales compared to more advanced kernels
function bicubic_coeffs (string kernel) {

    # info: Keys Cubics family of filters are BC-splines that exactly reproduce affine gradients, those that satisfy 2C+B = 1 (along the dotted line in the Cubic filters diagram)
    # Examples are Mitchell-Netravali, Robidoux (and its flavours), Catmull-Rom, Cub-grange and Spline.
    # For downscaling you can follow a different formula: B+2C  =  0 (Didée, ZoptiN)...
    # The next is sharper albeit more haloing    (Zopti): 3B+2C = -1 , but neither will produce affine gradients.

    rb  = 12. /(19.  +9.*sqrt(2))    # 0.378216
    rc  = 113./(58.+216.*sqrt(2))    # 0.310892
    rsb = 6.  /(13.  +7.*sqrt(2))    # 0.262015
    rsc = 7.  /(2.  +12.*sqrt(2))    # 0.368993
    rbb =      (9   -3. *sqrt(2))/7. # 0.679623
    rbc =      (1   -    rbb    )/2. # 0.160189

    # From blurrier to sharper
    c = [-2.,-2.]
    c = kernel == "Notch"             ? [1.5, -0.25] : c
    c = kernel == "SoftCubic100"      ? [1.0,   0.0] : c  # Also called Spline (same as GaussResize(p=21))
    c = kernel == "Robidoux Soft"     ? [rbb,   rbc] : c  # up,dw BC-spline soft approximation to EWA affine scaling. Close to a 'Quadratic' kernel.
    c = kernel == "SoftCubic75"       ? [0.75, 0.25] : c
    c = kernel == "BilcubicD"         ? [1/3.,  0.0] : c  # dw Bicubic practical match to Bilinear.
    c = kernel == "BilcubicU"         ? [0.5,   0.2] : c  # up Bicubic practical match to Bilinear.
    c = kernel == "Hermite"           ? [0.0,   0.0] : c  # up,dw Canonical Bicubic approximation to Bilinear (a bit sharper than it)
    c = kernel == "Robidoux"          ? [rb,     rc] : c  # up,dw Derived from EWA considerations, the values that "minimize the maximum possible change in vertical or horizontal straight lines (Robidoux) or any image (RobidouxSharp) under no-op" while satisfying Keys Cubics (affine gradients)
    c = kernel == "Centroid"          ? [0.37, 0.35] : c  # up Arithmetic mean of the satisfactory zone (by Dogway)
    c = kernel == "Mitchell-Netravali"? [1/3., 1/3.] : c  # up Canonical Bicubic (roughly equivalent to EWA Robidoux, a little softer though)
    c = kernel == "Robidoux Sharp"    ? [rsb,   rsc] : c  # up,dw
    c = kernel == "SoftCubic50"       ? [0.5,   0.5] : c
    c = kernel == "Catmule-Dog"       ? [0.1750,0.4125]:c # up Sharp while orthogonally furthest key cubic coefficients from Blocking and Ringing zones in Cubics diagram (between CatRom and RobiSharp) (by Dogway)
    c = kernel == "Cub-grange"        ? [0.0308,0.4846]:c # up but also dw. Bicubic approximation to Lagrange scaling (a bit sharper than it)
    c = kernel == "Catmull-Rom"       ? [ 0.0,  0.5] : c  # up Canonical sharp Bicubic (roughly equivalent to spline16resize() and EWA RobidouxSharp)
    c = kernel == "Didee"             ? [-0.5, 0.25] : c  # dw Didée's downscaling sharp coefficients for 1080p to 720p. More neutral in medium to low frequencies than Zopti. Good for intermediate resizings.
    c = kernel == "Zopti"             ? [-0.6,  0.4] : c  # dw 2160p to 720p Zopti optimized (by Boulder) (beware, not neutral, adds some local contrast): https://forum.doom9.org/showthread.php?p=1865218
    c = kernel == "ZoptiN"            ? [-0.6,  0.3] : c  # dw Like Zopti but more neutral (better over/undershoot normalization). Good for final resizing.
    c = kernel == "ZoptiH"            ? [-0.83,0.14] : c  # dw 1080 to half optimized (for 1080p and smaller clips)
    c = kernel == "Zopti720"          ? [-1.00,0.16] : c  # dw 1080p to 720p (for upscaling it always optimized to Catmull-Rom, although I visually prefer Precise)
    c = kernel == "Zopti720U"         ? [-0.99,0.26] : c  # dw 2160p to 720p. This is my optimization for going straight from UHD to 720p, but I still recommend going first "Zopti1080" to 1080p and then "SSIM2" to 720p.
    c = kernel == "Zopti1080"         ? [-0.99,0.06] : c  # dw 2160p to 1080p. Suprisingly better than using "SSIM2". If you want to skip halos but retain the great texture rendition use deep_resize(1080,edge="Didee",flat="Zopti1080")
    c = kernel == "Precise"           ? [ 0.0, 0.75] : c  # up Almost identical to spline36 but a bit more halo. Very good cheap upscaler.
    c = kernel == "Sharp"             ? [ 0.0,  1.0] : c  # dw Good alternative for dw. Less aliasing and sharper edges but softer textures.
    c = kernel == "Hatch"             ? [ 0.0, -5.0] : c

    # Aliases
  # c = kernel == "Spline"            ? [1.0,0.0]    : c # Commented as to not conflict with SplinexxResize kernel.
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


# chroma_placement() - helper function to calculate chroma location coefficient values.
# If you want to retrieve them use ConvertFormat(show=true)
#
# UHD standard chroma placement is top_left
# 422 standard chroma placement is left
# JPG standard chroma placement is center
# 444 and RGB  chroma placement is obviously center (cosited)
#
function chroma_placement (int w, int h, int nw, int nh, string matrix_i, string matrix_o, string format_i, string format_o, string jab_i, string jab_o, string "cplace_in", string "cplace_out") {

    rw =  w  / float(nw)               # source/target Y dimensions
    rh =  h  / float(nh)

    # Input Jab to chroma units
    a1 = Eval(MidStr(jab_i, 2, 1))
    b1 = Eval(MidStr(jab_i, 3, 1))
    iu = a1 / 4.                       # source chroma units/pixels for U dimension in respect to luma units
    iv = max(iu,ceil(b1 / 4.))         # source chroma units/pixels for V dimension in respect to luma units
    iu = (1 - iu) * 0.5                # Calculate shift in respect to luma units and convert to chroma units (if there's subsampling)
    iv = (1 - iv) * 0.5

    # Output Jab to chroma units
    a1 = Eval(MidStr(jab_o, 2, 1))
    b1 = Eval(MidStr(jab_o, 3, 1))
    ou = a1 / 4.                       # target chroma units/pixels for U dimension in respect to luma units
    ov = max(ou,ceil(b1 / 4.))         # target chroma units/pixels for V dimension in respect to luma units
    ou = (1 - ou) * 0.5                # Calculate shift in respect to luma units and convert to chroma units (if there's subsampling)
    ov = (1 - ov) * 0.5


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


    # Extending with aliases (RGB, Y or 44 -> hardcoded)
    fulli = FindStr(format_i,"RGB")>0 || jab_i == "444"
    fullo = FindStr(format_o,"RGB")>0 || jab_o == "444"

    # Aliases
    cplacei = fulli                    ? "center"   : \
              tli                      ? "top_left" : \
              cplacei == "DV"          ? "top_left" : \
              cplacei == "MPEG2"       ? "left"     : \
              cplacei == "MPEG1"       ? "center"   : \
              cplacei == "JPEG"        ? "center"   : \
              cplacei == "JPG"         ? "center"   : \
              cplacei == "l"           ? "left"     : \
              cplacei == "c"           ? "center"   : \
              cplacei == "tl"          ? "top_left" : \
              cplacei == "t"           ? "top"      : \
              cplacei == "bl"          ? "bottom_left": \
              cplacei == "b"           ? "bottom"   : cplacei

    cplaceo = fullo                    ? "center"   : \
              tlo                      ? "top_left" : \
              cplaceo == "DV"          ? "top_left" : \
              cplaceo == "MPEG2"       ? "left"     : \
              cplaceo == "MPEG1"       ? "center"   : \
              cplaceo == "JPEG"        ? "center"   : \
              cplaceo == "JPG"         ? "center"   : \
              cplaceo == "l"           ? "left"     : \
              cplaceo == "c"           ? "center"   : \
              cplaceo == "tl"          ? "top_left" : \
              cplaceo == "t"           ? "top"      : \
              cplaceo == "bl"          ? "bottom_left": \
              cplaceo == "b"           ? "bottom"   : cplaceo

    # In chroma units (compared to default MPEG1/center)
    icloc  =  cplacei == "left"        ? [ iu,0.0] : \
              cplacei == "center"      ? [0.0,0.0] : \
              cplacei == "top_left"    ? [ iu, iv] : \
              cplacei == "top"         ? [0.0, iv] : \
              cplacei == "bottom_left" ? [ iu,-iv] : \
              cplacei == "bottom"      ? [0.0,-iv] : \
              Assert (false, "chroma_placement: Unsupported input chroma placement mode.")

    # Out chroma units [third item is _ChromaLocation index for frameprops]
    ocloc  =  cplaceo == "left"        ? [ ou,0.0, 0] : \
              cplaceo == "center"      ? [0.0,0.0, 1] : \
              cplaceo == "top_left"    ? [ ou, ov, 2] : \
              cplaceo == "top"         ? [0.0, ov, 3] : \
              cplaceo == "bottom_left" ? [ ou,-ov, 4] : \
              cplaceo == "bottom"      ? [0.0,-ov, 5] : \
              Assert (false, "chroma_placement: Unsupported output chroma placement mode.")

    [icloc[0]*(1-rw)-(ocloc[0]-icloc[0])*rw, \
     icloc[1]*(1-rh)-(ocloc[1]-icloc[1])*rh, cplacei, cplaceo, ocloc[2]] }




# NTSC and PAL YCbCr (170M and 470BG) share the same matrix coefficients defined in (https://poynton.ca/PDFs/coloureq.pdf - 10.4),
# and derived from the old SMPTE 470M (FCC/NTSC 1953) standard. Exactly:
# kr: 0.298912
# kg: 0.586603
# kb: 0.114485
function color_coef (string "prims", string "mat", string "illu") {

    primd      = Defined(prims)
    prims      = Default(prims,   "709")
    mat        = Default(mat,     prims)
    illu       = Default(illu,    "D65")

    mat_i =
\     (mat    == "sRGB"           ) ? 1              : (mat    == "WideGamut"      ) ? 13
\   : (mat    == "709"            ) ? 1              : (mat    == "AppleRGB"       ) ? 14
\   : (mat    == "170M"           ) ? primd ? 2 : 0  : (mat    == "ProPhoto"       ) ? 15
\   : (mat    == "470M"           ) ? 0              : (mat    == "ColorMatch"     ) ? 16
\   : (mat    == "2020CL"         ) ? 5              : (mat    == "RussellRGB"     ) ? 17
\   : (mat    == "2020NCL"        ) ? 5              : (mat    == "BestRGB"        ) ? 18
\   : (mat    == "AdobeRGB"       ) ? 6              : (mat    == "BruceRGB"       ) ? 19
\   : (mat    == "AWG"            ) ? 7              : (mat    == "DonRGB4"        ) ? 20
\   : (mat    == "Display-P3"     ) ? 8              : (mat    == "BetaRGB"        ) ? 21
\   : (mat    == "DCI-P3"         ) ? 9              : (mat    == "ECI-RGB"        ) ? 22
\   : (mat    == "ACEScg"         ) ? 10             : (mat    == "AllColorsRGB"   ) ? 23
\   : (mat    == "ACESCCt"        ) ? 10             : (mat    == "EktaSpacePS5"   ) ? 24
\   : (mat    == "ACES2065"       ) ? 11             : (mat    == "CIE RGB"        ) ? 25
\   : (mat    == "240M"           ) ? 2              : (mat    == "MaxRGB"         ) ? 26
\   : (mat    == "470BG"          ) ? primd ? 4 : 0  : (mat    == "xTremeRGB"      ) ? 27
\   : (mat    == "NTSC-J"         ) ? 12             : (mat    == "ChromeSpace100" ) ? 24 : 1

# * Deriving Rec709 matrix coefficients from its primaries is noted as BT.709-2, in contrast to older and slightly different BT.709-1

    mat_wp =
\     (mat    == "170M"           ) ? 1
\   : (mat    == "709"            ) ? 1
\   : (mat    == "DCI-P3"         ) ? 3
\   : (mat    == "ACES2065"       ) ? 4
\   : (mat    == "ACEScg"         ) ? 4
\   : (mat    == "AWG"            ) ? 2 : 1

    # The coordinates and CCT's are from CIE 1931 2º Standard Observer
    mat_wp =
\     (illu   == "A"              ) ? 13
\   : (illu   == "B"              ) ? 14
\   : (illu   == "D50"            ) ? 2
\   : (illu   == "D55"            ) ? 6
\   : (illu   == "ACES"           ) ? 9
\   : (illu   == "D60"            ) ? 4
\   : (illu   == "DCI"            ) ? 3
\   : (illu   == "D65"            ) ? 1
\   : (illu   == "C"              ) ? 0
\   : (illu   == "E"              ) ? 5
\   : (illu   == "D75"            ) ? 7
\   : (illu   == "D93"            ) ? 8
\   : (illu   == "Sunlight"       ) ? 11
\   : (illu   == "Overcast"       ) ? 12
\   : (illu   == "ID50"           ) ? 15
\   : (illu   == "ID65"           ) ? 16 : mat_wp

# Background:
#   Initially D (Daylight) series illuminants made reference to its number designation in absolute numbers (ie. D50 = 5000K)
#   In 1948, Planck's c2 coefficient (second radiation constant) was updated from 1.438 * 10^(-2) to 1.4388 * 10^(-2)
#   Since 2018, c2 is fixed at an exact value of 1.438776877 * 10^(-2), therefore turning the original 5000K to 5000*(1.438776877/1.438) = 5002.70124K
#   Before 1948, c2 was defined at 1.432 by the SI (Système International d'Unités), despite this CIE used the "U.S. National Bureau of Standards" constant proposal of 1.435, which was used in 1931 for the Illuminants A, B and C.

# Illuminants try to match the medium and environment mixed white point contribution where the colors are meant to be reproduced.
# * CCT of about 1850K matches that of a candle light
# * 'A' Illuminant represents the temperature of a gas-filled tungsten light of ~100W (2855.496K)
# * CCT between 2650K and 3500K is typical of halogen-tungsten light bulbs
# * CCT between 4200K and 4800K is typical of fluorescents used in scanners
# * D50 is commonly used for printing and ICC profiles
# * D55 is common in photography as it matches daylight-balanced color negative film temperature. Represents a clear sky sunny daylight.
# * ACES white point is used for ACES color spaces. With a CCT of 5999.95K actually this is not a D illuminant, neither a Planckian locus. Reasoning: https://docs.acescentral.com/tb/white-point
# * D60 is called 'Day White' or sometimes 'Cloudy'. It's common for car LED headlights and DSLR flashes. Actually flashes have a nominal value of 5900K in brands like Canon or Nikon, but using higher shutter speeds can increase the captured temperature by 300K with 1/64 or 1/128
# * DCI is for (cinema) projectors
# * D65 is used for consumer media shown in LED displays under dim surround, represents an overcast daylight temperature at noon
# * D93 is not a D (Daylight) standard illuminant. Here it is defined for CCT (correlated) to Japanese consumer's TV standard "9300K+27 MPCD". "9300K+8 MPCD" for master CRT corresponds to 0.2838, 0.2984


# These primaries are associated with their respective standard illuminants.
# It's mandatory for them to do a chromatic adaptation to convert them to the new illuminant primaries. RGB_to_XYZ() and XYZ_to_RGB() do this automatically.
# Correlated Color Temperatures (CCT) in K (Kelvin) are derived from 'CIE 1931 2º Degree Standard Observer' CMF with 'native' isotherms.

# Note: The Illuminants chromacity coordinates have been calculated from 'Sprague' interpolated SPD of the original datasets with updated (2023) SI constants.
# Note: For ICC compliant coefficients you need to round them to hexadecimal after 16-bit allocation. Revert the process and round to 8 significant decimal figures
#       ( HEX2DEC ( DEC2HEX ( number-to-be-converted * 65536; 9 ) ) ) / 65536  # From: https://ninedegreesbelow.com
#
######################################################################################
###                                                                                 ##
### Illuminant 'C' family color spaces (6757.739K) (shade/indirect sunlight) Legacy ##  Originally 6740K
    wp = mat_wp==0 ? [0.31005856,0.31614964] : [0.31266142,0.3289589]               ##  Here derived from SPD (6774K with 'Ohno'). Coordinates 0.3087885,0.325172 if derived from CCT
###                                                                                 ##
######################################################################################

    # NTSC 1953
    # BT-470M / FCC
    cs = mat_i==0 ? [0.670,  0.330,   \
                     0.210,  0.710,   \
                     0.140,  0.080] : \
                    [0.640,  0.330,   \
                     0.300,  0.600,   \
                     0.150,  0.060]   # Fallback to 709 + D65 when no match

####################################################
###                                               ##
### 'D65' family color spaces (6503.512K)         ##
    wp = mat_wp==1 ? [0.31266142,0.3289589]  : wp ## From SPD converts to 6507.48K with 'mccamy', 6506.12K 'robertson' and 6506.62K with 'ohno' methods
###                                               ##
####################################################

    # sRGB (IEC 61966-2-1) and ITU-R BT.709-6 (originally CCIR Rec.709)
    cs = mat_i==1 ? [0.640,  0.330, \
                     0.300,  0.600, \
                     0.150,  0.060] : cs
    # Y’PbPr 601 | ITU-R BT.601 (originally CCIR Rec.601-1 circa 1982)
    # SMPTE 240M | SMPTE 170M   (modeled after P22 phosphors of Conrac consumer CRTs)
    cs = mat_i==2 ? [0.630,   0.340, \
                     0.310,   0.595, \
                     0.155,   0.070] : cs
    # PAL/SECAM
    # BT-470BG (originally EBU Tech.3123)
    cs = mat_i==4 ? [0.640,   0.330, \
                     0.290,   0.600, \
                     0.150,   0.060] : cs
    # BT-2020/BT-2100 (for 630nm, 532nm and 467nm)
    cs = mat_i==5 ? [0.707917792, 0.292027109, \
                     0.170237195, 0.796518542, \
                     0.131370635, 0.045875976] : cs
    # Adobe RGB (1998) (ClayRGB in Elle Stone's profiles)
    cs = mat_i==6 ? [0.640,   0.330, \
                     0.210,   0.710, \
                     0.150,   0.060] : cs
    # Apple RGB
    cs = mat_i==15? [0.6250,  0.3400, \
                     0.2800,  0.5950, \
                     0.1550,  0.0700] : cs
    # Bruce RGB (very early SWOP printing standard space)
    cs = mat_i==19? [0.6400,  0.3300, \
                     0.2800,  0.6500, \
                     0.1500,  0.0600] : cs

###################################################
###                                              ##
### 'DCI' family color spaces (CCT of 6302.663K) ##
    wp = mat_wp==3 ? [0.314,  0.351] : wp        ##
###                                              ##
###################################################


    # SMPTE RP 432-1 (Display-P3 / D65P3)  (Display-P3 keeps the same primaries but over a D65 illuminant)
    # SMPTE RP 432-2 (DCI-P3)
    cs = mat_i==9 ? [0.680,  0.320, \
                     0.265,  0.690, \
                     0.150,  0.060] : cs

###################################################
###                                              ##
### 'ACES' family color spaces (CCT of 5999.95K) ##
    wp = mat_wp==9 ? [0.32168,0.33767] : wp      ##
###                                              ##
###################################################

    # AP1 (ACEScg/ACEScc/ACEScct)
    cs = mat_i==10? [0.713,   0.293, \
                     0.165,   0.830, \
                     0.128,   0.044 ] : cs
    # AP0 (ACES2065 -SMPTE ST 2065-1-)
    cs = mat_i==11? [0.7347,  0.2653, \
                     0.0000,  1.0000, \
                     0.0001, -0.0770] : cs

##############################################################
###                                                         ##
### 'E' -achromatic- family color spaces (CCT of 5455.371K) ##
    wp = mat_wp==5 ? [1./3,1./3] : wp                       ##
###                                                         ##
##############################################################

    # CIE RGB (from 700.0nm, 546.1nm and 435.8nm)
    cs = mat_i==25? [0.7346900232, 0.2653099767, \
                     0.2736751797, 0.7174317825, \
                     0.1665376306, 0.0088803172] : cs
    # XYZ
    cs = mat_i==13? [1.0, 0.0, \
                     0.0, 1.0, \
                     0.0, 0.0] : cs

###########################################################
###                                                      ##
### '9300+27MPCD' family color spaces (CCT of 8945.436K) ##
    wp = mat_wp==8 ? [0.281, 0.311] : wp                 ##
###                                                      ##
###########################################################
# * BT.2035 defines 'D93' as 0.2831, 0.2971, but this is a simple straight Daylight CCT derivation of 9300K not the illuminant used in standard consumer CRTs in Japan, which actually was 9300K+27 MPCD** (x=0.281 y=0.311)
# * In contrast, Master CRT for studio monitors used 9300K+8 MPCD** (x=0.2838 y=0.2984)
# * A third set of primaries for Japanese NTSC (1987) simply uses 170M prims but with [0.2848, 0.2932] illuminant chromatic coordinates, which is also another (worse?) CCT derivation of 9300K.
# * In (http://www.imaging.org/site/PDFS/Papers/1997/RP-0-67/2401.pdf) Mark Fairchild measured a 9300K Sony Trinitron CRT with coordinates x=0.2838, y=0.3290

    # NTSC-J (https://web.archive.org/web/20130413104152if_/http://arib.or.jp/english/html/overview/doc/4-TR-B09v1_0.pdf#[{"num":73,"gen":0},{"name":"FitR"},-119,195,724,850])
    cs = mat_i==12 ? [0.618, 0.350, \
                      0.280, 0.605, \
                      0.152, 0.063] : cs
    # NTSC-J/P22 (https://bkict-ocw.knu.ac.kr/caster/file/lecture/5955F4002DC3E.pdf#page=14)
    cs = mat_i==30 ? [0.641, 0.327, \
                      0.272, 0.591, \
                      0.142, 0.052] : cs

# ** MPCD -Minimum Perceptible Color Difference- refers to the deviation unit in respect to the temperature CCT. For example D65 can also be specified as 6700K + 18 MPCD or more correctly as 6504K + 4 MPCD.

###########################################################
###                                                      ##
### 'D50' family color spaces (5002.701K)                ##
    wp = mat_wp==2 ? [0.34561718,0.35846945] : wp        ##
###                                                      ##
###########################################################
# Most of these come from: http://www.brucelindbloom.com/index.html?WorkingSpaceInfo.html
#                     and: http://www.russellcottrell.com/photo/matrixCalculator.htm
    # Don RGB 4
    cs = mat_i==20? [0.6960, 0.3000, \
                     0.2150, 0.7650, \
                     0.1300, 0.0350] : cs
    # Best RGB
    cs = mat_i==18? [0.7347, 0.2653, \
                     0.2150, 0.7750, \
                     0.1300, 0.0350] : cs
    # Beta RGB
    cs = mat_i==21? [0.6888, 0.3112, \
                     0.1986, 0.7551, \
                     0.1265, 0.0352] : cs
    # ColorMatch RGB (very close to PAL/SECAM but with D50 illuminant)
    cs = mat_i==16? [0.6300, 0.3400, \
                     0.2950, 0.6050, \
                     0.1500, 0.0750] : cs
    # ECI RGB v2
    cs = mat_i==22? [0.6700, 0.3300, \
                     0.2100, 0.7100, \
                     0.1400, 0.0800] : cs
    # Ekta Space PS5 / Chrome Space 100
    cs = mat_i==24? [0.6950, 0.3050, \
                     0.2600, 0.7000, \
                     0.1100, 0.0050] : cs
    # Wide Gamut RGB (Adobe's first attempt at a Wide Gamut). Danny Pascale's primaries.
    cs = mat_i==13? [0.7347, 0.2653, \
                     0.1152, 0.8264, \
                     0.1566, 0.0177] : cs
    # AWG (Adobe Wide Gamut)
    cs = mat_i==7 ? [0.73469, 0.26531, \
                     0.11416, 0.82621, \
                     0.15664, 0.01770] : cs
    # ProPhotoRGB (LargeRGB in RawTherapee and Elle Stone's profiles)
    cs = mat_i==15? [0.734699, 0.265301, \
                     0.159597, 0.840403, \
                     0.036598, 0.000105] : cs
    # AllColorsRGB (includes illegal values)
    cs = mat_i==23? [0.7346900232,  0.2653099767, \
                     0.0000000000,  1.0000000000, \
                     0.0000000000, -0.07585421971554103213] : cs
    # MaxRGB (includes illegal values)
    cs = mat_i==26? [0.7340, 0.2660, \
                     0.1000, 0.9000, \
                     0.0366, 0.0001] : cs
    # Xtreme16RGB (includes irreal values)
    cs = mat_i==27? [0.9999, 0.0001, \
                     0.0001, 0.9999, \
                     0.0001, 0.0001] : cs
    # "Gamut A" - Philips LivingColors gamut
    cs = mat_i==30? [0.7040, 0.2960, \
                     0.2151, 0.7106, \
                     0.1380, 0.0800] : cs
    # "Gamut B" - Philips HUE Gen1 & Gen2 (uses the sRGB transfer) Illuminant Unknown (D50 assumed)
    cs = mat_i==30? [0.6750, 0.322, \
                     0.4091, 0.518, \
                     0.1670, 0.040] : cs
    # "Gamut C" - Philips HUE Gen3+, HUE Go, and Lightstrip Plus
    cs = mat_i==30? [0.692, 0.308, \
                     0.170, 0.700, \
                     0.153, 0.048] : cs

#########################################################
###                                                    ##
### 'D55' (Film Stock) family color spaces (5502.971K) ##
    wp = mat_wp==6 ? [0.3323727,0.34739135] : wp       ##
###                                                    ##
#########################################################

    # Russell RGB
    cs = mat_i==17? [0.6900, 0.3100, \
                     0.1800, 0.7700, \
                     0.1000, 0.0200] : cs

####################################################
###                                               ##
### 'D60' illuminant (6003.241K)                  ##
    wp = mat_wp==4 ? [0.32156601,0.33757597] : wp ##
###                                               ##
####################################################

####################################################
###                                               ##
### 'D75' illuminant (7504.052K)                  ##
    wp = mat_wp==7 ? [0.29897489,0.31479446] : wp ##
###                                               ##
####################################################

############################################################################
###                                                                       ##
### Illuminant 'A' (2855.496K) Tungsten incandescent bulb at ~100W        ##
    wp = mat_wp==13 ? [0.44757142,0.40744043] : wp  # Derived from SPD    ##
###                                                                       ##
### Illuminant 'B' (4882.818K) Deprecated 4870K Sunlight standard, see 'Sunlight' below for updated CCT
    wp = mat_wp==14 ? [0.34840776,0.35161716] : wp  # Derived from SPD, 0.34926529,0.36143266 if derived from CCT
###                                                                       ##
### Illuminant 'ID50' (CCT of 5099.09K) Interior Daylight D50             ##
    wp = mat_wp==15 ? [0.34316021,0.36018097] : wp                        ##
###                                                                       ##
### Illuminant 'ID65' (CCT of 6604.84K) Interior Daylight D65             ##
    wp = mat_wp==16 ? [0.31060736,0.33061329] : wp                        ##
###                                                                       ##
### 'Sunlight' illuminant (CCT of 5348.259K)                              ##
    wp = mat_wp==9  ? [0.3362, 0.3502]  : wp                              ##
###                                                                       ##
### 'Overcast' illuminant (CCT of 6477.361K)                              ##
    wp = mat_wp==10 ? [0.3134, 0.3275]  : wp                              ##
###                                                                       ##
### LED-B1   (CCT of 2733.41K)                                            ##
    wp = mat_wp==30 ? [0.45595087,0.40779804] : wp                        ##
###                                                                       ##
### LED-B2   (CCT of 2997.70K)                                            ##
    wp = mat_wp==30 ? [0.43566143,0.40117991] : wp                        ##
###                                                                       ##
### LED-B3   (CCT of 4102.43K)                                            ##
    wp = mat_wp==30 ? [0.37561412,0.37228699] : wp                        ##
###                                                                       ##
### LED-B4   (CCT of 5108.79K)                                            ##
    wp = mat_wp==30 ? [0.34218376,0.35015381] : wp                        ##
###                                                                       ##
### LED-B5   (CCT of 6597.46K)                                            ##
    wp = mat_wp==30 ? [0.3118073,0.32363414]  : wp                        ##
###                                                                       ##
### LED-BH1  (CCT of 2851.22K)                                            ##
    wp = mat_wp==30 ? [0.44740999,0.40659402] : wp                        ##
###                                                                       ##
### LED-RGB1 (CCT of 2839.75K)                                            ##
    wp = mat_wp==30 ? [0.45574636,0.42111994] : wp                        ##
###                                                                       ##
### LED-V1   (CCT of 2723.62K)                                            ##
    wp = mat_wp==30 ? [0.45476074,0.40440401] : wp                        ##
###                                                                       ##
### LED-V2   (CCT of 4069.47K)                                            ##
    wp = mat_wp==30 ? [0.37811096,0.37749661] : wp                        ##
###                                                                       ##
############################################################################


    # Hard-coded white-point constant for the Kr, Kg, Kb derivations
    pw = mat == "170M" || mat == "470BG" ? [0.31005856,0.31614964] : wp

    pr = [cs[0], cs[1], 1 - cs[0] - cs[1]]    pw = [pw[0], pw[1], 1 - pw[0] - pw[1]]
    pg = [cs[2], cs[3], 1 - cs[2] - cs[3]]    wp = [wp[0], wp[1], 1 - wp[0] - wp[1]]
    pb = [cs[4], cs[5], 1 - cs[4] - cs[5]]

    # If 'prims' is defined, set kr,kg,kb coefs to 1
    if (!primd) {
    det = pw[1] * Dot([pr[0],pg[0],pb[0]], Cross([pr[1],pg[1],pb[1]], [pr[2],pg[2],pb[2]]))
    kr  = pr[1] * Dot(pw, Cross(pg, pb)) / det
    kg  = pg[1] * Dot(pw, Cross(pb, pr)) / det
    kb  = pb[1] * Dot(pw, Cross(pr, pg)) / det
    } else { kr = 1 kg = 1 kb = 1 }

    [kr, kg, kb, wp[0], wp[1], wp[2], pr, pg, pb] }




# Typical production practices for SDTV transfer characteristics differ from those specified in ITU recommendations.
# While NTSC-525 and PAL-625 are defined with 170M and 470BG OETFs respectively nowadays 1886 is used as output transfer (inverse EOTF) (read note 3 on page 6 of REC-BT.601-7)
# You should be aware of this and change according your requirements.

# Transfer functions help redistribute the values of the color gamut for better precision.

function moncurve_coef (string transfer) {

    # Normalized transfer strings (601, 709, 2020, AWG and Display-P3 are duplicates but kept as reference)
    # The assignations here are OETF related.
    t_num =
\     (transfer == "1886"         ) ? 5
\   : (transfer == "470M"         ) ? 0
\   : (transfer == "sRGB"         ) ? 1
\   : (transfer == "Display-P3"   ) ? 1
\   : (transfer == "170M"         ) ? 2
\   : (transfer == "601"          ) ? 2
\   : (transfer == "NTSC-J"       ) ? 2
\   : (transfer == "709-Camera"   ) ? 2
\   : (transfer == "2020NCL"      ) ? 2
\   : (transfer == "2020CL"       ) ? 2
\   : (transfer == "2020"         ) ? 2
\   : (transfer == "240M"         ) ? 3
\   : (transfer == "470BG"        ) ? 4
\   : (transfer == "709"          ) ? 5
\   : (transfer == "AdobeRGB"     ) ? 6
\   : (transfer == "AWG"          ) ? 6
\   : (transfer == "DCIXYZ"       ) ? 7
\   : (transfer == "linear"       ) ? 8
\   : (transfer == "CIELab"       ) ? 9 : 5

# Use CCTF() or the dedicated functions in "TransformsPack - Transfers" for the below transfers
#\  : (transfer == "Chrome"       ) ? x
#\  : (transfer == "AppleRGB"     ) ? x
#\  : (transfer == "ColorMatch"   ) ? x # same as AppleRGB and ProPhotoRGB
#\  : (transfer == "1886a"        ) ? x
#\  : (transfer == "xvYCC"        ) ? -1
#\  : (transfer == "PhotoCD"      ) ? -1 (same as xvYCC, a variant of '1' with negative fix)
#\  : (transfer == "PQ"           ) ? -1
#\  : (transfer == "HLG"          ) ? -1 : 4


       /* Coeff Derivations:
          "Simultaneous equations" require brute force root-finding algos (ie. bisection method)
           Added only as reference here since moncurve_x() functions compute them correctly from proper "alpha" coeff.

        #   alpha = offset     (x coord - 1)
        #   beta  = transition (y coord)= K0/Phi
        #   phi   = slope                (k0/beta)
        #   k0    = beta * phi or alpha / (gam-1)

        #   BT.2020/SMPTE 170M                                #  SMPTE 240M
        #   piece match                                       #  piece+slope match
        #   phi*y = a*b^igam-x+1                              #  k0  = a / (gam-1)
        #   phi   = igam*a*b^(igam-1)                         #  phi = (((1+a)^gam)*(gam-1)^(gam-1))/((a^(gam-1))*gam^gam)
            gamma = 1/0.45                                       gamma = 1/0.45 = 2.2222
            alpha = 0.099296826809442940347282759                alpha = 0.1115
            beta  = 0.018053968510807807335869592                beta  = 0.02280681818181818182
            k0    = 0.081242858298635133011413164                k0    = 0.09122727272727272727
            phi   = 4.5                                          phi   = 4.0

        #   sRGB                                              #  sRGB
        #   piece match                                       #  piece+slope match
        #   phi*b = a*b^igam-a+1                              #  k0  = a / (gam-1)
        #   phi   = igam*a*b^(igam-1)                         #  phi = (((1+a)^gam)*(gam-1)^(gam-1))/((a^(gam-1))*gam^gam)
            gamma = 2.40                                         gamma = 2.40
            alpha = 0.05501071894758659721                       alpha = 0.055
            beta  = 0.00304128256012752085                       beta  = 0.00303993463977843
            k0    = 0.039293370676847569382                      k0    = 0.03928571428571428571
            phi   = 12.92                                        phi   = 12.92321018078786109464
            */

    #                        NTSC 1953/YCbCr                          SMPTE-C    / BT-2020           Y’PbPr 601              PAL/SECAM                      Rec.709  AdobeRGB     DCI-P3      AP1/AP0    CIE L*ab
    #                        BT-470M/FCC     sRGB                     SMPTE 170M / BT-2020           SMPTE 240M (historical) BT-470BG (historical)          BT-1886  AdobeRGB**   DCI-P3/XYZ  ACES/LIN
    t_gamma = Select(t_num,  2.2           , 2.40                   , 1/0.45                       , 1/0.45                , 2.80                         , 2.40   , 563/256.  ,  2.60       , 1.0      , 3.0       )
    t_alpha = Select(t_num,  0             , 0.055                  , 0.099296826809442940347282759, 0.1115                , 0.099296826809442940347282759, 0      , 0         ,  0          , 0        , 0.16      )
    t_beta  = Select(t_num,  0             , 0.00303993463977843    , 0.018053968510807807335869592, 0.02280681818181818182, 0.00410749063249639977       , 0      , 0         ,  0          , 0        , 0.00885645167903563082)
    t_k0    = Select(t_num,  0             , 0.03928571428571428571 , 0.081242858298635133011413164, 0.09122727272727272727, 0.05516490378302385575       , 0      , 0         ,  0          , 0        , 0.08      )
    t_phi   = Select(t_num,  0             , 12.92321018078786109464, 4.5                          , 4.0                   , 13.43031761206876179575      , 4.5    , 0         ,  0          , 0        , (24389/27.)/100) # 9.032963
    p_approx= Select(t_num,  2.2           , 2.220000               , 1.943333                     , 1.916666              , 2.460000                     , 2.40   , 2.19921875,  2.60       , 1.0      , 2.48      )
  # *  Approximated matching power law gamma value
  # ** An hexadecimal rounded value of the ideal 2.2 power gamma.

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

# Input should be in PC range and RGB or YUV (full size chroma) packing format
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

        mat10=mat1[0]    mat11=mat1[1]    mat12=mat1[2]
        ar1 = Dot([mat10,mat11,mat12],[mat2[0],mat2[1],mat2[2]])
        ar2 = Dot([mat10,mat11,mat12],[mat2[3],mat2[4],mat2[5]])
        ar3 = Dot([mat10,mat11,mat12],[mat2[6],mat2[7],mat2[8]])

       [ar1,ar2,ar3]

    # 3x3 · 1x3
    } else if (ArraySize(mat2) == 3) {

        mat20=mat2[0]    mat21=mat2[1]    mat22=mat2[2]
        ar1 = Dot([mat1[0],mat1[1],mat1[2]],[mat20,mat21,mat22])
        ar2 = Dot([mat1[3],mat1[4],mat1[5]],[mat20,mat21,mat22])
        ar3 = Dot([mat1[6],mat1[7],mat1[8]],[mat20,mat21,mat22])

       [ar1,ar2,ar3]

    # 3x3 · 3x3
    } else {

        mat10=mat1[0]    mat11=mat1[1]    mat12=mat1[2]
        mat13=mat1[3]    mat14=mat1[4]    mat15=mat1[5]
        mat16=mat1[6]    mat17=mat1[7]    mat18=mat1[8]

        mat20=mat2[0]    mat21=mat2[1]    mat22=mat2[2]
        mat23=mat2[3]    mat24=mat2[4]    mat25=mat2[5]
        mat26=mat2[6]    mat27=mat2[7]    mat28=mat2[8]

        ar1 = Dot([mat10,mat11,mat12],[mat20,mat23,mat26])
        ar2 = Dot([mat10,mat11,mat12],[mat21,mat24,mat27])
        ar3 = Dot([mat10,mat11,mat12],[mat22,mat25,mat28])
        ar4 = Dot([mat13,mat14,mat15],[mat20,mat23,mat26])
        ar5 = Dot([mat13,mat14,mat15],[mat21,mat24,mat27])
        ar6 = Dot([mat13,mat14,mat15],[mat22,mat25,mat28])
        ar7 = Dot([mat16,mat17,mat18],[mat20,mat23,mat26])
        ar8 = Dot([mat16,mat17,mat18],[mat21,mat24,mat27])
        ar9 = Dot([mat16,mat17,mat18],[mat22,mat25,mat28])

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

    a3  = ArraySize(vec1)==3 || ArraySize(vec2)==3
    # 1x3 · 1x3 or 1x2 · 1x2
    a3 ? (vec1[0] * vec2[0]) + (vec1[1] * vec2[1]) + (vec1[2] * vec2[2]) : \
         (vec1[0] * vec2[0]) + (vec1[1] * vec2[1])   }


function Cross (float_array vec1, \
                float_array vec2) {

    a3  = ArraySize(vec1)==3 || ArraySize(vec2)==3
    # 1x3 X 1x3
    if (a3) {
        vec10=vec1[0]  vec11=vec1[1]   vec12=vec1[2]
        vec20=vec2[0]  vec21=vec2[1]   vec22=vec2[2]
        cr1 = vec11 *  vec22 - vec12 * vec21
        cr2 = vec12 *  vec20 - vec10 * vec22
        cr3 = vec10 *  vec21 - vec11 * vec20
        [cr1, cr2, cr3]
    } else {
    # 1x2 X 1x2
        cr1 = vec1[0] * vec2[1] - vec2[0] * vec1[1]
        [cr1] } }

