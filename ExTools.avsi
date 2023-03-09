###########################################################
###                                                      ##
###                                                      ##
###        ExTools v10.1    (09-03-2023)                 ##
###                                                      ##
###                          by Dogway (Jose Linares)    ##
###                                                      ##
###   https://forum.doom9.org/showthread.php?t=182881    ##
###                                                      ##
###########################################################
###
### Pack of masktools2/removegrain replacement functions with...
### internal Expr() and many extra features.
### Generally works faster* than masktools2 counterparts for any given bitdepth.
### See performance notes (benchmarks over 1080p@16-bit).
###
### *Convolutions are slower than in masktools2/removegrain (SSSE3 vs AVX2)
###
### UV setting works similarly as in masktools2:
###
### 1:   garbage
### 2:   copy first
### 3:   process
### 4:   copy second
### 6:   copy third (differs with masktools2's '5')
### 128: range_half
### x:   custom value in 8-bit (bitdepth autoscaled) (1, 2, 3, 4, and 6 not available)
###
### fulls: Defines the source bitdepth scale (full/bitshift range) when converting from/to integer HBD formats (10, 12, 14, 16)
###        ConvertBits() defaults to false for YUV, same in ExTools if frame properties are not present.
###
### Dependencies: AviSynth+ 3.7.3+ (https://forum.doom9.org/showthread.php?t=181351)
###
### Credits: Thanks to wonkey_monkey (David Horman) for Expr optimization tips
###          and pinterf for Expr's pixel addressing feature and his continued efforts on AVS+ development
###
###########################################################
###                                                      ##
### EXPRESSIONS:                                         ##
###     ex_lut                                           ##
###     ex_lutxy                                         ##
###     ex_lutxyz                                        ##
###     ex_lutxyza                                       ##
###     ex_makediff                                      ##
###     ex_adddiff                                       ##
###     ex_makeadddiff                                   ##
###     ex_logic                                         ##
###     ex_merge                                         ##
###     ex_clamp                                         ##
###     ex_binarize                                      ##
###     ex_athres                                        ##
###     ex_invert                                        ##
###     ex_lutspa                                        ##
###     ex_motion                                        ##
### BLURS:                                               ##
###     ex_boxblur                                       ##
###     ex_blur                                          ##
###     ex_blur3D                                        ##
###     ex_bilateral                                     ##
###     ex_smartblur                                     ##
###     ex_smooth                                        ##
###     ex_kawase                                        ##
###     ex_GaussianBlur                                  ##
###     ex_LFR                                           ##
###     ex_MFR                                           ##
###     ex_FluxSmoothT                                   ##
###     ex_FluxSmoothST                                  ##
###     STTWM                                            ##
###     ex_median                                        ##
###     ex_repair                                        ##
### MORPHOLOGICAL:                                       ##
###     ex_expand                                        ##
###     ex_inpand                                        ##
###     ex_deflate                                       ##
###     ex_inflate                                       ##
###     ex_hitormiss                                     ##
###     ex_edge                                          ##
###     ex_luts                                          ##
###     ex_shape                                         ##
### HELPERS:                                             ##
###     clamp                                            ##
###     isRunTime                                        ##
###     DivideStr                                        ##
###     FindStrInstance                                  ##
###     pixel_parser                                     ##
###     ex_UVexpr                                        ##
###     ex_Yexpr                                         ##
###     ex_UVf                                           ##
###     ex_bs                                            ##
###     ex_dlut                                          ##
###     mskY_to_YYY                                      ##
### ARRAY HELPERS:                                       ##
###     ArrayOp                                          ##
###     ArrayInv                                         ##
###     ArrayZip                                         ##
###     ArraySym                                         ##
###     ArrayAppend                                      ##
###     ArrayDelVal                                      ##
###     ArrayFind                                        ##
###     ArrayPrint                                       ##
###     ArrayEval                                        ##
###     ArrayMedian                                      ##
###     ArrayIQM                                         ##
### FUNCTION APPROXIMATIONS:                             ##
###     atanT                                            ##
###     atan2T                                           ##
###     tanhT                                            ##
###     atanhT                                           ##
###     expT                                             ##
###     cosT                                             ##
###     sinT                                             ##
###                                                      ##
###########################################################


function ex_lut(clip a, string "str", string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc || Y!=3 ? 3 : 1)
    fs   = Default(fulls,    fs)
    cf   = Default(clamp_float, false)
    si   = Default(scale_inputs, ex_UVf(rgb, bi))

    # Overall 1D LUT calculations work when input bitdepth is < 32, regardless of internal expression bitdepth scaling.
    # In practice enabling LUT causes a slight (~7%) slowdown. But this has to be fixed upstream, not here.
    # Supporting LUT calculations when internal bitdepth scaling might allow it (ie. Expr(32f_src,"i8 x 1 -", scale_inputs="all", lut=1) ) would also be a great addition to Expr().
    px   = FindStr(str, "[") > 0 || (isc ? FindStr(cstr, "[") > 0 : false)
    lut  = px || bi == 32 || isRunTime(a,rgb) ? 0 : 1

    cstr = !isc && Y!=3 ? str : isc && UV==3 ? cstr : str # Evaluate str as cstr if Y!=3 and cstr is not defined
    ystr =                              ex_Yexpr ( str,  Y, bi, rgb, fs, si)
    cstr = rgb ? ex_dlut(str, bi, fs) : ex_UVexpr(cstr, UV, bi, rgb, fs, si, isc)

    isy     ?  Expr(a, ystr,       scale_inputs=si, clamp_float=cf, lut=lut) : \
    UV == 1 ?  Expr(a, ystr, "",   scale_inputs=si, clamp_float=cf, lut=lut) : \
               Expr(a, ystr, cstr, scale_inputs=si, clamp_float=cf, lut=lut) }


function ex_lutxy(clip a, clip b, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc || Y!=3 ? 3 : 1)
    fs   = Default(fulls,    fs)
    cf   = Default(clamp_float, false)
    si   = Default(scale_inputs, ex_UVf(rgb, bi))

    px   = FindStr(str, "[") > 0 || (isc ? FindStr(cstr, "[") > 0 : false)
    lut  = px || bi > 12 || isRunTime(a,rgb) ? 0 : 2  # Technically 14-bit supports LUT calcs but in practice depends on cache size which most not-too-recent (pre-2021) CPUs lack

    cstr = !isc && Y!=3 ? str : isc && UV==3 ? cstr : str
    ystr =                              ex_Yexpr ( str,  Y, bi, rgb, fs, si)
    cstr = rgb ? ex_dlut(str, bi, fs) : ex_UVexpr(cstr, UV, bi, rgb, fs, si, isc)

    isy     ?  Expr(a, b, ystr,       scale_inputs=si, clamp_float=cf, lut=lut) : \
    UV == 1 ?  Expr(a, b, ystr, "",   scale_inputs=si, clamp_float=cf, lut=lut) : \
               Expr(a, b, ystr, cstr, scale_inputs=si, clamp_float=cf, lut=lut) }


function ex_lutxyz(clip a, clip b, clip c, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "opt", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc || Y!=3 ? 3 : 1)
    fs   = Default(fulls,    fs)
    cf   = Default(clamp_float, false)
    op   = Default(opt,         false)
    si   = Default(scale_inputs, ex_UVf(rgb, bi))

    cstr = !isc && Y!=3 ? str : isc && UV==3 ? cstr : str
    ystr =                              ex_Yexpr ( str,  Y, bi, rgb, fs, si)
    cstr = rgb ? ex_dlut(str, bi, fs) : ex_UVexpr(cstr, UV, bi, rgb, fs, si, isc)

    isy     ?  Expr(a, b, c, ystr,       scale_inputs=si, clamp_float=cf, optSingleMode=op) : \
    UV == 1 ?  Expr(a, b, c, ystr, "",   scale_inputs=si, clamp_float=cf, optSingleMode=op) : \
               Expr(a, b, c, ystr, cstr, scale_inputs=si, clamp_float=cf, optSingleMode=op) }


function ex_lutxyza(clip a, clip b, clip c, clip d, string str, string "cstr", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "opt", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    isc  = Defined(cstr)

    str  = Default(str, "")
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : isc || Y!=3 ? 3 : 1)
    fs   = Default(fulls,    fs)
    cf   = Default(clamp_float, false)
    op   = Default(opt,         false)
    si   = Default(scale_inputs, ex_UVf(rgb, bi))

    cstr = !isc && Y!=3 ? str : isc && UV==3 ? cstr : str
    ystr =                              ex_Yexpr ( str,  Y, bi, rgb, fs, si)
    cstr = rgb ? ex_dlut(str, bi, fs) : ex_UVexpr(cstr, UV, bi, rgb, fs, si, isc)

    isy     ?  Expr(a, b, c, d, ystr,       scale_inputs=si, clamp_float=cf, optSingleMode=op) : \
    UV == 1 ?  Expr(a, b, c, d, ystr, "",   scale_inputs=si, clamp_float=cf, optSingleMode=op) : \
               Expr(a, b, c, d, ystr, cstr, scale_inputs=si, clamp_float=cf, optSingleMode=op) }



# mt_makediff() is 5% slower
#
# Use aug=n to augment difference map
# Use metric="metric_name" to write/show metric(s) to frame properties (check dependencies below)
# Use 'show' to choose output; 0: clip 'a'  1: clip 'b'  2: diff  3: diff subtitled (no frameprops)
#
# Dependencies:
#           SimilarityMetrics (for HD inputs when metric: ALL or simply metric: SSIM, BSSIM, GMSD or MDSI)
#               fmtconv
#           TransformsPack    (for metric: RedMean or OkMSE)
#           VMAF              (for metric: MS-SSIM, CAMBI or CIEDE2000)
#           Butteraugli       (for metric: Butteraugli)
#
# Function Definition:
#    (
#    clip a,
#    clip b,
#    string "metric"="none" ("none"/ "ALL"/ "--"/ "ME"/ "MAE"/ "SMAE"/ "MAD"/ "MAD2"/ "MSE"/ "MSLE"/ "RMSE"/ "CHAR"/ "--"/ "OkMSE"/ "RedMe"/ "CIEDE2000"/ "R2"/ "ZTest"/ "CAMBI"/ "--"/ "PSNR"/ "SSIM"/ "MS_SSIM"/ "BSSIM"/ "SSIMU"/ "SSIMU2"/ "GMSD"/ "MDSI"/ "BUTT"),
#    bool "aug"=false,
#    bool "dif"=false,
#    int "show"=2 (0 to 3)
#    )
#
# modes:
# error = e = (predicted - observed) or (distorted - reference) = x - y
# ME      - Mean Error or Bias. M(e). Measures additive bias in the error
# MAE     - Mean Absolute Error -Manhattan or L1 norm-. M(|e|). Measures additive bias in the error but in a magnitude scale without sign
# PAE     - Percentage of Absolute Error (not implemented)
# SMAE    - Smooth Mean Absolute Error or Huber Loss. Same as MAE but less sensitive to outliers. It performs like MAE with low error and like MSE with high error
# MAD     - Mean Absolute Deviation
# MAD2    - Median Absolute Deviation. median(|e-median(|e|)|). Similar to a standard deviation but more robust to outliers by replacing the means of squares with median of absolutes
# MSE     - Mean Square Error / SSR / Quadratic Loss. Sometimes also erroneously labeled L2 norm. M(e^2) Gives more weight to large deviations or outliers
# MSLE    - Mean Square Log Error. Gives less weight to large deviations or outliers. Useful when dealing with right skewed references
# RMSLE   - Not implemented
# RMSE    - Root Mean Squared Error / Standard Error / SRSS -Euclidean or L2 norm-. sqrt(M(e^2)). Gives more weight to large deviations or outliers. Same as MSE but rooted to normalize the units
# PSNR    - Peak Signal-to-Noise Ratio
# CHAR    - Charbonnier -L1-L2 loss-
# OkMSE   - Euclidean Distance -RMSE- in OkLab
# RedMean - RedMean -sRGB fast metric-
# R2      - Coefficient of determination. Measure of the ratio of variability between the distorted and the reference
# ZTest   - Two Sample Z-Test / Z-Score -Difference of Means of Distributions-
# SSIM    - Structural SIMilarity
# MS-SSIM - Structural SIMilarity for Multi-Scale
# SSIMU   - SSIMULACRA  - Structural SIMilarity Unveiling Local And Compression Related Artifacts
# SSIMU2  - SSIMULACRA2 - Structural SIMilarity Unveiling Local And Compression Related Artifacts, Version 2 (https://github.com/cloudinary/ssimulacra2)
# BSSIM   - Structural SIMilarity for Blurred
# GMSD    - Gradient Magnitude Similarity Deviation
# BUTT    - Butteraugli psychovisual similarity index for DCT compression. Google's open source image metric tool tuned to high quality content (mainly between -q 90 to 95 in JPEG scale)
# MDSI    - Mean Deviation Similarity Index. IQA model that utilizes gradient similarity (GS), chromaticity similarity (CS), and deviation pooling (DP)
# CAMBI   - Contrast-Aware Multiscale Banding Index
# CIEDE2000-CIE Delta-E 2000

function ex_makediff(clip a, clip b, bool "dif", val "aug", bool "tv_range", string "metric", int "show", int "Y", int "UV", bool "fulls", bool "clamp_float", string "scale_inputs") {

    rgb  = isRGB(a)
    isy  = isy  (a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    lut  = bi > 12 || isRunTime(a,rgb) ? 0 : 2

    Daug = Defined(aug)     Baug = isBool(aug)
    met  = Daug && !Baug ? aug == -1 ? "ALL" : "none" : "none"
    tv   = Default(tv_range,    false)   # Enable to mimic Subtract(), "ygrey" centered instead of "range_half" (only applies to luma plane)
    dif  = Default(dif,  tv || bi!=32)
    fs   = Default(fulls,          fs)   # Only used for 'metric' to properly convert to PC range
    cf   = Default(clamp_float, false)
    mcf  = Default(metric,        met)   # "ALL", "none" or "metric_name".
    mcf  = mcf=="--" || mcf=="" ? "none" : mcf
    sh   = Default(show,            2)   # Output clip to return when 'metric' is defined. 0: clip 'a'  1: clip 'b'  2: diff  3: diff subtitled (no frameprops)
    aug  = Daug ? Baug ? aug ? 50 : -1 : aug == -1 ? 50 : aug : mcf == "none" ? 0 : 50
    Y    = Default(Y,               3)
    UV   = Default(UV,        rgb ? 3 : aug > 0 ? 128 : 1)
    si   = Default(scale_inputs, ex_UVf(rgb, bi))


    gr   =             tv ? "ygrey" : "range_half"
    str  = Format(aug > 0 ? "x y - abs {aug} *"    : \
                  dif     ? "x y - "+gr+" +"       : \
                            "x y -")

    ystr = ex_Yexpr (           str,                        Y, bi, rgb, fs, si)
    cstr = ex_UVexpr(ReplaceStr(str,"ygrey","range_half"), UV, bi, rgb, fs, si)

    isy     ? Expr(a, b, ystr      , scale_inputs=si, clamp_float=cf, lut=lut) : \
    UV == 1 ? Expr(a, b, ystr, ""  , scale_inputs=si, clamp_float=cf, lut=lut) : \
              Expr(a, b, ystr, cstr, scale_inputs=si, clamp_float=cf, lut=lut)

    if (!tv) {
              prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
              propDelete(UV<5?prop:ArrayAdd(prop,"_ChromaLocation"))
              propSet("_ColorRange", 0)     }


    # Cost Functions for Similarity Index Metric Distances (Residuals)
    if (mcf != "none") {

        fc  = FrameCount() < 2
        mcf = mcf == "Butteraugli" ? "BUTT"   : \
              mcf == "Charbonnier" ? "CHAR"   : \
              mcf == "stderr"      ? "RMSE"   : \
              mcf == "L1"          ? "MAE"    : \
              mcf == "L2"          ? "MSE"    : \
              mcf == "SSR"         ? "MSE"    : \
              mcf == "RedMean"     ? "rMEA"   : \
              mcf == "SSIMULACRA"  ? "SSIMU"  : \
              mcf == "SSIMULACRA2" ? "SSIMU2" : \
              mcf == "OkLab"       ? "OkMSE"  : UCase(mcf)

        mcfa  =  mcf == "ALL"
        mPLUG = (mcf == "BSSIM"   || mcf == "GMSD" || mcf == "MDSI" || mcf == "SSIM")
        mVMAF =  mcf == "MS_SSIM" || mcf == "CIEDE2000"
        RGBm  =  mcf == "OkMSE"   || mcf == "CIEDE2000" || mcf == "rMEA" || mcf == "MDSI" || mcf == "BUTT"

        isy && !mcfa ? Assert(!RGBm, "ex_makediff: Unsupported mode for greyscale clips") : nop()

        w  = a.width()
        h  = a.height()
        pd = max(w,h)/(w/144.)

        isUHD = (w > 2599 || h > 1499)
        isHD  = (w > 1099 || h >  599)

        matA = isUHD ? "2020:f" : isHD ? "709:f" : "170m:f"

        a1   = mcfa && sh < 2 ? a.propClearAll() :a
        a1   = mcfa || mcf == "CAMBI" || mVMAF ? mcfa && isHD ? _IQA_downsample(a1, fulls=fs, fulld=true).ConvertBits(10,dither=-1,fulls=true) : a1.ConvertBits(10,dither=-1,fulls=fs,fulld=true) : a1.ConvertBits(32,fulls=fs,fulld=true)  # _IQA_downsample() is not much better than bicubic(b=-0.5,c=0.3), but better in any case.
        b1   = mcfa || mcf == "CAMBI" || mVMAF ? mcfa && isHD ? _IQA_downsample(b,  fulls=fs, fulld=true).ConvertBits(10,dither=-1,fulls=true) : b. ConvertBits(10,dither=-1,fulls=fs,fulld=true) : b. ConvertBits(32,fulls=fs,fulld=true)
        a1   = rgb && (mcfa || mcf != "MDSI" && mcf != "BUTT" && mcf != "rMEA" && mcf != "OkMSE") ? a1.ConvertToYUV420(matrix=matA) : a1
        b1   = rgb && (mcfa || mcf != "MDSI" && mcf != "BUTT" && mcf != "rMEA" && mcf != "OkMSE") ? b1.ConvertToYUV420(matrix=matA) : b1
        a1   = mcfa || mcf == "CAMBI" || mVMAF ? isy ? CombinePlanes(a1, planes="YUV", source_planes="YYY", pixel_type="YUV444"+(BitsPerComponent(a1)==32?"PS":"P10")) : a1 : a1
        b1   = mcfa || mcf == "CAMBI" || mVMAF ? isy ? CombinePlanes(b1, planes="YUV", source_planes="YYY", pixel_type="YUV444"+(BitsPerComponent(b1)==32?"PS":"P10")) : b1 : b1

      # y    = mcfa || mcf == "VMAF"  ? VMAF  (a1, b1,"",log_format=2,model=0)                        : a1 # VMAF is not supported as it requires writing to disk
        y    = mcfa || mVMAF          ? VMAF2 (a1, b1, feature=mcfa?isy?[3]:[3,4]:mcf=="MS_SSIM"?3:4) : a1 # Requires 8-10-bit input, YCbCr 3 planes (feature: 1: PSNR-HSV 3: MS-SSIM 4: CIEDE2000 5: CAMBI)
        y    = mcfa || mcf == "CAMBI" ? VMAF2 (y,  b1, feature=5, cambi_opt=Format("enc_width={w} enc_height={h}")) : y
        y    = mcfa || mcf == "CAMBI" || mVMAF ?   y.ConvertBits(32,fulls=true)          : y
        a1   = mcfa && sh < 2 ? y.propClearAll() : isHD ? a1.ConvertBits(32,fulls=true) : a.ConvertBits(32,fulls=fs,fulld=true)
        b1   = mcfa || mcf == "CAMBI" || mVMAF ?   isHD ? b1.ConvertBits(32,fulls=true) : b.ConvertBits(32,fulls=fs,fulld=true) : b1
        b2   = rgb  || isy || is444(b1) ? b1.ConvertToPlanarRGB(matrix=matA) : b1.ConvertToPlanarRGB(matrix=matA,chromaresample="bicubic",param1=0,param2=0.5)

        y    = mcfa || mcf == "SSIM" || mcf == "BSSIM" ? \
                                        vsSSIM(b1, y, show=1, fulls=true) : y
        y    = mcfa || mcf == "BSSIM" ? BSSIM (b1, y, show=1, fulls=true) : y
        y    = mcfa                   ? rgb || isy ? GMSD(b1, y, show=1, fulls=true).ConvertToPlanarRGB(matrix=matA) :      is444(b1) ? GMSD(b1, y, show=1, fulls=true).ConvertToPlanarRGB(matrix=matA) : GMSD(b1, y, show=1, fulls=true).ConvertToPlanarRGB(matrix=matA,chromaresample="bicubic",param1=0,param2=0.5) : \
                       mcf == "GMSD"  ?              GMSD(b1, y, show=1, fulls=true) : mcf=="SSIMU" || mcf=="SSIMU2" || mcf=="MDSI" || mcf=="BUTT" || mcf=="rMEA" || mcf=="OkMSE" ? is444(y) ? y.ConvertToPlanarRGB(matrix=matA) :      y.ConvertToPlanarRGB(matrix=matA,chromaresample="bicubic",param1=0,param2=0.5) : y
        y    = mcfa || mcf == "MDSI"  ? !isy ? MDSI  (b2, y, show=1, fulls=true)                                 : y : y
        y    = mcfa || FindStr(UCase(mcf),"SSIMU")>0 ? !isy ? ssimulacra(y, b2, feature=mcfa?2:mcf=="SSIMU"?0:1) : y : y
        b3   = mcfa || mcf == "BUTT"  ? !isy ? Butteraugli(y, b2)                                                : y : y  # Very slow filter ~3fps

        z1   = mcfa || mcf == "ME"  || mcf == "MAE"  || mcf == "SMAE"                  ? ex_lutxy(a1,b1,"x y -"                      ,UV=1,fulls=true) : nop()
        z2   = mcfa || mcf == "MSE" || mcf == "CHAR" || mcf == "RMSE" || mcf == "PSNR" ? ex_lutxy(a1,b1,"x y - dup *"                ,UV=1,fulls=true) : nop()
        z3   = mcfa || mcf == "MSLE"                                                   ? ex_lutxy(a1,b1,"x 1 + log y 1 + log - dup *",UV=1,fulls=true) : nop()

        # RedMean
        yA   = mcfa || mcf == "rMEA"  ? !isy ?  y.ExtractClip() : nop() : nop()
        bA   = mcfa || mcf == "rMEA"  ? !isy ? b2.ExtractClip() : nop() : nop()
        z4   = mcfa || mcf == "rMEA"  ? !isy ? Expr(yA[0],yA[1],yA[2],bA[0],bA[1],bA[2],"x a + 0.5 * R@ 0.00390625 * 2 + x a - dup * *   y b - dup * 4 * +   255 R - 0.00390625 * 2 + z c - dup * * + sqrt") : nop() : nop()

        # OkLab
        oky  = mcfa || mcf == "OkMSE" ? !isy ?  y.CCTF(fc?"sRGB":"1886",true,false,false).RGB_to_Oklab(matrix=matA).ExtractClip() : nop() : nop()
        okb  = mcfa || mcf == "OkMSE" ? !isy ? b2.CCTF(fc?"sRGB":"1886",true,false,false).RGB_to_Oklab(matrix=matA).ExtractClip() : nop() : nop()
        OkD  = mcfa || mcf == "OkMSE" ? !isy ? Expr(oky[0],oky[1],oky[2],okb[0],okb[1],okb[2],"x a - dup * y b - dup * z c - dup * + + sqrt") : nop() : nop() # RMSE (Euclidean Distance) over OkLab

        ScriptClip  (sh>1?last:sh==1?b:a, function [y,a,b,z1,z2,z3,z4,a1,b1,b3,OkD,pd,mcf,mcfa,mPLUG,isy,sh,fs] () {

            Ava  = AverageLuma (a1)
            Avb  = AverageLuma (b1)
            VARa = mcfa || mcf == "ZTest" ? AverageLuma(ex_lut(a1,Format("x {Ava} - dup *"),UV=1,fulls=true)) : nop()
            VARb = mcfa || mcf == "ZTest" ? AverageLuma(ex_lut(b1,Format("x {Avb} - dup *"),UV=1,fulls=true)) : nop()
            ZTest= mcfa || mcf == "ZTest" ? abs(Ava - Avb) / sqrt(VARa + VARb) : nop() # Difference of means / stderr
            Mea  = mcfa || mcf == "MAD2"  ? YPlaneMedian(a1) : nop()
            Meb  = mcfa || mcf == "MAD2"  ? YPlaneMedian(b1) : nop()
            MAD  = mcfa || mcf == "MAD"   ? AverageLuma (ex_lutxy(a1,b1,Format("{Ava} x - abs {Avb} y - abs - abs"),UV=1,fulls=true)) : nop()
            MAD2 = mcfa || mcf == "MAD2"  ? YPlaneMedian(ex_lutxy(a1,b1,Format("{Mea} x - abs {Meb} y - abs - abs"),UV=1,fulls=true)) : nop()
            ME   = mcfa || mcf == "ME"    || \
                           mcf == "MAE"   || \
                           mcf == "SMAE"  ? AverageLuma(z1)          : nop()
            MAE  = mcfa || mcf == "MAE"   || \
                           mcf == "SMAE"  ? abs(ME) : nop()
            SMAE = mcfa || mcf == "SMAE"  ? MAE < 1. ? pow(MAE,2)/2. : MAE - 0.5 : nop()
            MSE  = mcfa || mcf == "MSE"   || \
                           mcf == "CHAR"  || \
                           mcf == "RMSE"  || \
                           mcf == "PSNR"  ? AverageLuma(z2)          : nop()
            MSLE = mcfa || mcf == "CHI"   ? AverageLuma(z3)          : nop()
            MSLE = mcfa || mcf == "MSLE"  ? AverageLuma(z3)          : nop()
            RedMean=mcfa|| mcf == "rMEA"  ? !isy ? AverageLuma(z4)   : nop() : nop()
            CHAR = mcfa || mcf == "CHAR"  ? sqrt(MSE+pow(0.001,2))   : nop()
            RMSE = mcfa || mcf == "RMSE"  || \
                           mcf == "PSNR"  ? sqrt(MSE) : nop()                # Technically should be first sqrt(loss) and then Mean but in practice a close match
            PSNR = mcfa || mcf == "PSNR"  ? 20*log10(1./RMSE)        : nop() # 20*log10() to convert to dB
            R2   = mcfa || mcf == "R2"    ? AverageLuma(ex_lutxy(a1,b1,Format("{Ava} dup x - swap dup * swap y - swap dup * swap / 1 swap -"),UV=1,fulls=true)) : nop()
            OkMSE= mcfa || mcf == "OkMSE" ?  !isy ? AverageLuma(OkD)                      : nop() : nop()
            BUTT = mcfa || mcf == "BUTT"  ?  !isy ?  propGetFloat(b3,"_FrameButteraugli") : nop() : nop()
            SSIMU= mcfa || FindStr(UCase(mcf),"SSIMU") >0? !isy ? mcfa ? [propGetFloat(y,"SSIMULACRA"),propGetFloat(y,"SSIMULACRA2")] : propGetFloat(y,mcf=="SSIMU"?"SSIMULACRA":"SSIMULACRA2") : "" : ""
            SSIMU2= SSIMU
            CAMBI= mcfa || mcf == "CAMBI" ?          propGetFloat(y,"cambi")              : nop()
            MS_SSIM= mcfa||mcf == "MS_SSIM"?         propGetFloat(y,"float_ms_ssim")      : nop()
            CIEDe2000=mcfa||mcf=="CIEDE2000"?!isy ?  propGetFloat(y,"ciede2000")          : nop() : nop()


            if (!mcfa && mPLUG) {

                y  = propCopy(last,y,true,props=["_Plane"+MCF])

            } else if (mcfa) {

                y  = propCopy(last,y,true,props=["_PlaneSSIM","_PlaneBSSIM","_PlaneGMSD","_PlaneMDSI"])

            } else {

                y  = last

            }


            if (mcfa) {

                y   = propSet(y,"_PlaneME"  ,      ME ,  0)
                y   = propSet(y,"_PlaneMAE" ,      MAE,  0)
                y   = propSet(y,"_PlaneSMAE",     SMAE,  0)
                y   = propSet(y,"_PlaneMAD" ,      MAD,  0)
                y   = propSet(y,"_PlaneMAD2",      MAD2, 0)
                y   = propSet(y,"_PlaneMSE" ,      MSE,  0)
                y   = propSet(y,"_PlaneMSLE",      MSLE, 0)
                y   = propSet(y,"_PlaneRMSE",      RMSE, 0)
                y   = propSet(y,"_PlaneCHAR",      CHAR, 0)
                y   = propSet(y,"_PlaneOkMSE",    OkMSE, 0)
                y   = propSet(y,"_PlaneRedMean",RedMean, 0)
                y   = propSet(y,"_PlaneR2"  ,       R2 , 0)
                y   = propSet(y,"_PlaneSSIMU", SSIMU[0], 0)
                y   = propSet(y,"_PlaneSSIMU2",SSIMU[1], 0)
                y   = propSet(y,"_PlaneZTest",    ZTest, 0)
                y   = propSet(y,"_PlaneBUTT",      BUTT, 0)
                y   = propSet(y,"_PlanePSNR",      PSNR, 0)
                y   = propSet(y,"_PlaneMS_SSIM",MS_SSIM, 0)
                y   = propSet(y,"_PlaneCIEDE2000",CIEDe2000,0)
                y   = propSet(y,"_PlaneCAMBI",    CAMBI, 0)

            } else {

                MCF = ReplaceStr(MCF,"rMEA","RedMean" )
                y   = !mPLUG ? propSet(y,"_Plane"+MCF, Eval(MCF), 0) : y

                Subtitle(y, "Plane"+MCF+":  "+String(mPLUG ? propGetFloat(y,"_Plane"+MCF ) : Eval(MCF)))
            }


            if (sh != 3) { y } else if (!mcfa) { last } else {
                NaN = "NaN        "
                Subtitle(last,\
                          "PlaneME:\n"     \
                         +"PlaneMAE:\n"    \
                         +"PlaneSMAE:\n"   \
                         +"PlaneMAD:\n"    \
                         +"PlaneMAD2:\n"   \
                         +"PlaneMSE:\n"    \
                         +"PlaneMSLE:\n"   \
                         +"PlaneRMSE:\n"   \
                         +"PlanePSNR:\n"   \
                         +"PlaneCHAR:\n"   \
                         +"PlaneOkMSE:\n"  \
                         +"PlaneRedMean:\n"\
                         +"PlaneR2:\n"     \
                         +"PlaneZTest:\n"  \
                         +"PlaneSSIM:\n"   \
                         +"PlaneSSIMU:\n"  \
                         +"PlaneSSIMU2:\n" \
                         +"PlaneBSSIM:\n"  \
                         +"PlaneGMSD:\n"   \
                         +"PlaneBUTT:\n"   \
                         +"PlaneMDSI:\n"   \
                         +"PlaneMS_SSIM:\n"\
                         +"PlaneCIEDE2000:\n"\
                         +"PlaneCAMBI:\n",lsp=4)
                Subtitle(  String(        propGetFloat(y,"_PlaneME"   ))  +"   (Mean Error or Bias)\n"                             \
                         + String(        propGetFloat(y,"_PlaneMAE"  ))  +"   (Mean Absolute Error -Manhattan or L1 norm-)\n"     \
                         + String(        propGetFloat(y,"_PlaneSMAE" ))  +"   (Smooth Mean Absolute Error -Huber Loss-)\n"        \
                         + String(        propGetFloat(y,"_PlaneMAD"  ))  +"   (Mean Absolute Deviation)\n"                        \
                         + String(        propGetFloat(y,"_PlaneMAD2" ))  +"   (Median Absolute Deviation)\n"                      \
                         + String(        propGetFloat(y,"_PlaneMSE"  ))  +"   (Mean Square Error / SSR)\n"                        \
                         + String(        propGetFloat(y,"_PlaneMSLE" ))  +"   (Mean Square Log Error)\n"                          \
                         + String(        propGetFloat(y,"_PlaneRMSE" ))  +"   (Root Mean Squared Error / Standard Error / SRSS -Euclidean or L2 norm-)\n"\
                         + String(        propGetFloat(y,"_PlanePSNR" ),"%3.5f")+"   (Peak Signal-to-Noise Ratio)\n"               \
                         + String(        propGetFloat(y,"_PlaneCHAR" ))  +"   (Charbonnier -L1-L2 loss-)\n"                       \
                         + String(isy?NaN:propGetFloat(y,"_PlaneOkMSE"))  +"   (Euclidean Distance -RMSE- in OkLab)\n"             \
                         + String(isy?NaN:propGetFloat(y,"_PlaneRedMean"))+"   (RedMean -sRGB fast metric-)\n"                     \
                         + String(        propGetFloat(y,"_PlaneR2"   ))  +"   (Coefficient of determination)\n"                   \
                         + String(        propGetFloat(y,"_PlaneZTest"))  +"   (Two Sample Z-Test / Z-Score -Difference of Means of Distributions-)\n"\
                         + String(        propGetFloat(y,"_PlaneSSIM" ))  +"   (Structural SIMilarity)\n"                          \
                         + String(isy?NaN:propGetFloat(y,"_PlaneSSIMU" )) +       "   (Structural SIMilarity Unveiling Local And Compression Related Artifacts)\n"    \
                         + String(isy?NaN:propGetFloat(y,"_PlaneSSIMU2"),"%3.5f")+"   (Structural SIMilarity Unveiling Local And Compression Related Artifacts v2)\n" \
                         + String(        propGetFloat(y,"_PlaneBSSIM"))  +"   (Structural SIMilarity for Blurred)\n"              \
                         + String(        propGetFloat(y,"_PlaneGMSD" ))  +"   (Gradient Magnitude Similarity Deviation)\n"        \
                         + String(isy?NaN:propGetFloat(y,"_PlaneBUTT" ))  +"   (Butteraugli psychovisual similarity index for DCT compression)\n"\
                         + String(isy?NaN:propGetFloat(y,"_PlaneMDSI" ))  +"   (Mean Deviation Similarity Index)\n"                \
                         + String(        propGetFloat(y,"_PlaneMS_SSIM"))+"   (Multi-Scale SSIM)\n"                               \
                         + String(isy?NaN:propGetFloat(y,"_PlaneCIEDE2000"),"%3.5f")+"   (CIE Delta-E 2000)\n"                     \
                         + String(        propGetFloat(y,"_PlaneCAMBI"))  +"   (Contrast-Aware Multiscale Banding Index)",x=pd,lsp=4)
    } } )
    sh < 2 && !fs && mcfa ? propSet("_ColorRange", 1) : last
    } }



# mt_adddiff() is 5% slower
function ex_adddiff(clip a, clip b, int "Y", int "UV", bool "dif", bool "tv_range", bool "fulls", string "scale_inputs") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = bi > 12 || isRunTime(a,rgb) ? 0 : 2

    Y   = Default(Y,         3)
    UV  = Default(UV,  rgb ? 3 : 1)
    dif = Default(dif,     bi!=32)
    fs  = Default(fulls, Defined(tv_range) ? tv_range ? false : fs : fs)
    tv  = Default(tv_range, false)
    si  = Default(scale_inputs, ex_UVf(rgb, bi))

    gr  = tv  ? "ygrey" : "range_half"
    str = dif ? "x y + "+gr+" -"      : \
                "x y +"

    ystr = ex_Yexpr (str,  Y, bi, rgb, fs, si)
    cstr = ex_UVexpr(str, UV, bi, rgb, fs, si)

    isy     ? Expr(a, b, ystr      , scale_inputs=si, lut=lut) : \
    UV == 1 ? Expr(a, b, ystr, ""  , scale_inputs=si, lut=lut) : \
              Expr(a, b, ystr, cstr, scale_inputs=si, lut=lut) }


function ex_makeadddiff(clip a, clip b, clip "c", int "Y", int "UV", string "scale_inputs", bool "clamp_float") {

    rgb = isRGB(a)
    isy = isy(a)
    isc = Defined(c)
    bi  = BitsPerComponent(a)
    lut = bi > 12 || isRunTime(a,rgb) ? 0 : 2

    Y   = Default(Y,           3)
    UV  = Default(UV,    rgb ? 3 : 1)
    un  = Undefined()
    cf  = Default(clamp_float, false)  # Works two ways. Not only it will clamp floats output, but also the first in-expression differential
    si  = Default(scale_inputs, ex_UVf(rgb, bi))

    str = cf  ? "0 max" : ""
    str = isc ? "x y - "+str+" z +" : "x y - "+str+" x +"

    ystr = ex_Yexpr (str,  Y, bi, rgb, un, si)
    cstr = ex_UVexpr(str, UV, bi, rgb, un, si)

    isc     ?                                                                        \
    isy     ? Expr(a, b, c, ystr      , scale_inputs=si, clamp_float=cf          ) : \
    UV == 1 ? Expr(a, b, c, ystr, ""  , scale_inputs=si, clamp_float=cf          ) : \
              Expr(a, b, c, ystr, cstr, scale_inputs=si, clamp_float=cf          ) : \
    isy     ? Expr(a, b,    ystr      , scale_inputs=si, clamp_float=cf, lut=lut ) : \
    UV == 1 ? Expr(a, b,    ystr, ""  , scale_inputs=si, clamp_float=cf, lut=lut ) : \
              Expr(a, b,    ystr, cstr, scale_inputs=si, clamp_float=cf, lut=lut ) }


# mt_logic(mode="and") is 6% slower
#
# AND  : if both pixels in a pair have the value of 255, you'll get 255 in a result clip, otherwise 0.
# OR   : if any of pixels in a pair has the value of 255, you'l get 255, otherwise 0.
# XOR  : if both pixels have the value of 255 or 0, you'l get 0, otherwise (if only one of the pixels is 255) 255.
# ANDN : you'll get 255 if and only if the first pixel is 255 and the second is 0.
#
#
# Function Definition:
#    (
#    clip a,
#    clip b,
#    string "mode"="and" ("and"/ "andn"/ "or"/ "xor"/ "min"/ "max")
#    )
#
function ex_logic(clip a, clip b, string "mode", int "thx", int "thy", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : true
    bi32 = bi == 32
    lut  = bi > 12 || isRunTime(a,rgb) ? 0 : 2

    mode = Default(mode, "and")
    th1  = Default(thx,     0 )       # threshold for clip x in modes 'min' or 'max'
    th2  = Default(thy,     0 )       # threshold for clip y in modes 'min' or 'max'
    UV   = Default(UV,    rgb ? 3 : 1)
    si   = ex_UVf(rgb, bi)

    th1 = th1 != 0 ? string(ex_bs(th1, 8, bi, fulls=fs))+" + " : ""
    th2 = th2 != 0 ? string(ex_bs(th2, 8, bi, fulls=fs))+" + " : ""

    str =                                                                        \
        mode == "and"   ? bi32 ? "x y *" : "x y * range_max /"                 : \
        mode == "or"    ?        "x y + range_min range_max clip"              : \
        mode == "xor"   ?        "x y - abs"                                   : \
        mode == "andn"  ? bi32 ? "1 x - y *" : "range_max x - y * range_max /" : \
        mode == "andnot"? bi32 ? "1 x - y *" : "range_max x - y * range_max /" : \
        mode == "min"   ?        "x "+th1+" y "+th2+" min"                     : \
        mode == "max"   ?        "x "+th1+" y "+th2+" max"                     : \
                                 Assert (false, "ex_logic: Unsupported logic mode.")

    cstr = ex_UVexpr(str, UV, bi, rgb, fs, si)
    str  = ex_dlut  (str, bi, fs)

    isy     ? Expr(a, b, str                       , lut=lut) : \
    UV == 1 ? Expr(a, b, str, ""                   , lut=lut) : \
              Expr(a, b, str, cstr, scale_inputs=si, lut=lut) }


# The higher the mask value the more the second clip merges into the first (mask bitdepth scale should always saturate full range -ie. 65535 for 16-bit int-)
# mt_merge() is 5%  slower on                  Y clips / masks
#               5%  slower on luma=false for YUV clips / masks
#               8%  faster on luma=true  for YUV clips / masks
#               13% faster on luma=true  for YUV clips Y masks
#               8%  faster on luma=false for YUV clips Y masks
function ex_merge(clip a, clip b, clip msk, bool "luma", int "Y", int "UV") {

    rgb  = isRGB(a)
    isya = isy(a)
    isyb = isy(b)
    isym = isy(msk)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb

    lm  = Default(luma,     isym && rgb)
    Y   = Default(Y,                  3)
    UV  = Default(UV,    isya ? 1 : rgb || lm ? 3 : 2)
    si  = ex_UVf(rgb, bi)

    isRGB(msk) ? Assert (!lm, "ex_merge: 'luma=true' unsupported for RGB masks.") : nop()

    b =  isya && !isyb ? b.ExtractY()                          : \
        !isya &&  isyb ? mskY_to_YYY(a, b, false, rgb, UV, bi) : b

    msk = isya ? isym ? msk           : \
                        ExtractY(msk) : \
          lm  || isym ||                \
          width (msk)!=width (a) ||     \
          height(msk)!=height(a)      ? \
          mskY_to_YYY(a, msk, lm, rgb, UV, bi) : msk

    mr  = bi  > 14 ? "range_max /"     : string(1. / Eval(ex_dlut("range_max", bi, true))) + " *"
    str = bi == 32 ? "x dup y - z * -" : "x dup y - z "+mr+" * -"

    cstr = ex_UVexpr( str, UV, bi, rgb, !(UV!=3 && !fs), si)
    ystr = ex_Yexpr ( str,  Y, bi, rgb, true           , si)

    isya    ? Expr(a, b, msk, ystr,                        optSingleMode=false) : \
    UV == 1 ? Expr(a, b, msk, ystr, "",                    optSingleMode=false) : \
              Expr(a, b, msk, ystr, cstr, scale_inputs=si, optSingleMode=false) }


# mt_clamp() is 6% slower
function ex_clamp(clip a, clip hi, clip lo, int "overshoot", int "undershoot", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    os = Default(overshoot,  0)
    us = Default(undershoot, 0)
    UV = Default(UV,    rgb ? 3 : 1)
    si = ex_UVf(rgb, bi)

    os = ex_bs(os, 8, bi, fulls=fs)
    us = ex_bs(us, 8, bi, fulls=fs)

    str = (os == 0) && (us == 0) ?        "x y min z max"              : \
                                   Format("x y {os} + min z {us} - max")

    cstr = ex_UVexpr( str, UV, bi, rgb, fs, si)

    isy     ? Expr(a, hi, lo, str,                        optSingleMode=false) : \
    UV == 1 ? Expr(a, hi, lo, str, "",                    optSingleMode=false) : \
              Expr(a, hi, lo, str, cstr, scale_inputs=si, optSingleMode=false) }


# mt_binarize() is 12% slower than ex_binarize()
# mt_binarize() is 17% faster than ex_binarize(smooth=true)
# lo=-1 | hi=-1 replaces lo|hi with source "x"
#
# Dependencies:
#               ResizersPack   ('dynamic' and 'otsu' modes)
#               TransformsPack (for RGB inputs)
#
# modes:
# simple  - fixed static threshold
# dynamic - temporal stable dynamic threshold.
# otsu    - simplified Otsu's method with 10 histogram bins
#
# Example:
#     ex_binarize(10,hi=-1) # Cleaning/clamping faint values. Same as: "x < 10 ? 0 : x"
#
# Function Definition:
#    (
#    clip,
#    float thres=115.0 (0.0 to 255.0 by 1),
#    string "mode"="simple" ("simple"/ "dynamic"/ "otsu"),
#    bool "smooth"=false,
#    bool "invert"=false
#    )
#
function ex_binarize(clip a, float "thres", bool "invert", bool "smooth", string "mode", int "lo", int "hi", int "UV", bool "fulls") {

    w    = width (a)
    h    = height(a)
    rgb  = isRGB (a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    lut  = isRunTime       (a,rgb) || bi==32  ? 0 : 1
    isHD = (w > 1099 || h > 599 ) && !isy
    isUHD= (w > 2599 || h > 1499) && !isy

    th   = Default(thres, 115)
    lo   = Default(lo,      0)          # Value for under threshold (set to -1 to passthrough clip values)
    hi   = Default(hi,    255)          # Value for above threshold (set to -1 to passthrough clip values)
    in   = Default(invert, false)       # Use this for invert instead of lo=255 and hi=0
    sm   = Default(smooth, false)
    md   = Default(mode, "simple")      # 'simple', 'dynamic' or 'otsu'
    UV   = Default(UV,        128)      # Currently this is noop as chroma thresholding makes no sense
    fs   = Default(fulls,  fs)
    si   = ex_UVf(rgb, bi)

    th  = ex_bs(th,  8, bi, fulls=fs, flt=true)
    lox = lo < 0   hix = hi < 0
    lox && hix ? Assert (false, "ex_binarize: 'lo' or 'hi': At least one bound should be binarized.") : nop()



    bs  =               a. ConvertBits(8,dither=-1,fulls=fs)     # Matrix assumed by dimensions
    bs  = rgb ? isUHD ? bs.DotClip([0.262372,0.678464,0.059164]) : \
                 isHD ? bs.DotClip([0.212600,0.715179,0.072221]) : \
                        bs.DotClip([0.298912,0.586603,0.114485]) : \
                        a. ConvertBits(8,dither=-1,fulls=fs)
    a   = rgb ?         bs.ConvertBits(bi,fulls=fs) : a
    br  = w > 720 ? bs.RatioResize(720., "adjust2w", kernel="bilinear") : bs


    isy = rgb || isy

    if (md=="otsu") {

        # Assumes TV range for YUV
        bnth = (fs ? 255 : 219) / 10.
        off  =  fs ?   0 :  16
        rnm  =  1. / 255

        ScriptClip(a, function [br,bnth,off,rnm,in,sm,lo,hi,UV,fs] () {

            thr1 =br.ex_binarize(bnth+off,true,UV=UV,fulls=fs)
            bin1 =thr1.AverageLuma()
            thr2 =bnth * 2 + off
            thr2 =ex_lutxy(thr1,br,Format("range_max x - y {thr2} < range_max 0 ? {rnm} * *"), UV=1, fulls=true)
            bin2 =thr2.AverageLuma()
            thr3 =bnth * 3 + off
            thr3 =ex_lutxy(thr2,br,Format("range_max x - y {thr3} < range_max 0 ? {rnm} * *"), UV=1, fulls=true)
            bin3 =thr3.AverageLuma()
            thr4 =bnth * 4 + off
            thr4 =ex_lutxy(thr3,br,Format("range_max x - y {thr4} < range_max 0 ? {rnm} * *"), UV=1, fulls=true)
            bin4 =thr4.AverageLuma()
            thr5 =bnth * 5 + off
            thr5 =ex_lutxy(thr4,br,Format("range_max x - y {thr5} < range_max 0 ? {rnm} * *"), UV=1, fulls=true)
            bin5 =thr5.AverageLuma()
            thr6 =bnth * 6 + off
            thr6 =ex_lutxy(thr5,br,Format("range_max x - y {thr6} < range_max 0 ? {rnm} * *"), UV=1, fulls=true)
            bin6 =thr6.AverageLuma()
            thr7 =bnth * 7 + off
            thr7 =ex_lutxy(thr6,br,Format("range_max x - y {thr7} < range_max 0 ? {rnm} * *"), UV=1, fulls=true)
            bin7 =thr7.AverageLuma()
            thr8 =bnth * 8 + off
            thr8 =ex_lutxy(thr7,br,Format("range_max x - y {thr8} < range_max 0 ? {rnm} * *"), UV=1, fulls=true)
            bin8 =thr8.AverageLuma()
            thr9 =bnth * 9 + off
            thr10=br.ex_lut(Format("x {thr9} > range_max 0 ?"),                                UV=1, fulls=true)
            thr9 =ex_lutxy(thr8,thr10,Format("range_max x - range_max y - *       {rnm} *"),   UV=1, fulls=true)
            bin9 =thr9.AverageLuma()
            bin10=thr10.AverageLuma()

            hist = [bin1, bin2, bin3, bin4, bin5, bin6, bin7, bin8, bin9, bin10]

            for (t = 0, 9, 1) {

                B = 0  F = 0  Mb = 0 Mf = 0
                for (i = 0, t, 1) {
                    B  = B  + hist[i]
                    Mb = Mb + hist[i] * i
                }
                    Mb = B != 0 ? Mb / B : 0

                for (i = t+1, 9, 1) {
                    F  = F  + hist[i]
                    Mf = Mf + hist[i] * i
                }
                    Mf = F != 0 ? Mf / F : 0

                # Between class variance for each 't'
                Eval(Format("th{t} = ((B * F)/pow(B+F,2)) * pow(Mb - Mf, 2) "))
            }

            th = max(max(max(max(max(max(max(max(max(th0,th1),th2),th3),th4),th5),th6),th7),th8),th9)
            th = th == th0 ? 1 : th == th1 ? 2 : th == th2 ? 3 : th == th3 ? 4 : th == th4 ? 5 : th == th5 ? 6 : th == th6 ? 7 : th == th7 ? 8 : th == th8 ? 9 : 10
            th = (th*bnth+off)-bnth*0.5

            ex_binarize(th,in,sm,"simple",lo,hi,UV,fs)

        } )

        rgb ? CombinePlanes(last, planes="RGB") : last

    } else if (md=="dynamic") {

        ScriptClip(a, function [br,in,sm,lo,hi,UV,fs] () {

            th = (AverageLuma(br,-2)+AverageLuma(br,0)+AverageLuma(br,2))*0.333333333
            ex_binarize(th,in,sm,"simple",lo,hi,UV,fs)

        } )

        rgb ? CombinePlanes(last, planes="RGB") : last

    } else {

        if (sm) {

            # same output than smoothstep but faster
            bi32 = bi == 32
            mx   = ex_bs(255, 8, bi, fulls=fs, fulld=true)
            thl  = th * 0.9    thl = bi32 ? thl : round(thl)
            thh  = th * 1.1    thh = bi32 ? thh : round(thh)
            thm  = 1./(thh - thl)

            lob = lox ? 0  : ex_bs(lo, 8, bi, fulls=fs, fulld=true)
            hib = hix ? mx : ex_bs(hi, 8, bi, fulls=fs, fulld=true)

            msk = Format("x {thl} - {thm} * 0 1 clip")
            msk = in ? "1 "+msk+" -" : msk

            str = Format( lox ? "x dup {hib}        - "+msk+" * -"           : \
                          hix ? "{lob} dup x        - "+msk+" * -"           : \
                         (in  ? "1" : "")+" x {thl} - {thm} * 0 max "+(in?"-":"")+" range_max *" )

        } else {

            lob = lox ? "x" : string(ex_bs(lo, 8, bi, fulls=fs, fulld=true))
            hib = hix ? "x" : string(ex_bs(hi, 8, bi, fulls=fs, fulld=true))

            str = Format(in ? "x {th} < "+hib+" "+lob+" ?" : \
                              "x {th} > "+hib+" "+lob+" ?")
        }

    cstr = ex_UVexpr(  str, UV, bi, rgb, fs, si)

    isy     ?  Expr(a, str                       , lut=lut, clamp_float=sm && bi32 ) : \
    UV == 1 ?  Expr(a, str, ""                   , lut=lut, clamp_float=sm && bi32 ) : \
               Expr(a, str, cstr, scale_inputs=si, lut=lut, clamp_float=sm && bi32 )

    if (lo == 0 && hi == 255) {
               prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
               propDelete(UV<4?prop:ArrayAdd(prop,"_ChromaLocation"))
               propSet("_ColorRange", 0)                     }

    sm      ?  ex_boxblur(0.5, mode="weighted", UV=1) : last } }



# Adaptive Threshold
#
# Useful for binary feature extraction under luminosity changes (ie. fonts in page scans)
# If you are not getting satisfactory results, try to upscale by 2
#
# modes:
# mean     - Normally the default in most solutions, good for fonts or geometric shapes.
# gaussian - Cleaner output. Uses a gaussian approximation so it's faster than 'mean' (Default)

function ex_athres(clip a, float "th", float "sigma", bool "invert", string "mode", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    lut = bi > 12 || isRunTime(a,rgb) ? 0 : 2

    th  = Default(th,        40)
    sg  = Default(sigma,      6)          # sigma=6 is default for 1080p inputs
    in  = Default(invert, false)
    md  = Default(mode,    "gaussian")    # 'mean' or 'gaussian'
    UV  = Default(UV,    rgb ? 3 : 128)
    un  = Undefined()
    si  = ex_UVf(rgb, bi)

    sg  = max(sg,0)
    th  = 1 - (th / 1000.)

    # INTEGRAL
    str = "x[-2,-2] x[-1,-2] x[0,-2] x[1,-2]     + + + A@  x[2,-2] +         B^
           x[-2,-1] x[-1,-1] x[0,-1] x[1,-1] A + + + + C@  x[2,-1] B + + A - D^
           x[-2,0]  x[-1,0]  x[0,0]  x[1,0]  C + + + + E@  x[2,0]  D + + C - F^
           x[-2,1]  x[-1,1]  x[0,1]  x[1,1]  E + + + + G@  x[2,1]  F + + E - H^
           x[-2,2]  x[-1,2]  x[0,2]  x[1,2]  + + + dup     x[2,2]  H dup G dup

           + + + + + + 0.012345679 *"

    isy     ?  Expr(a, str                                                      ) : \
    UV == 1 ?  Expr(a, str, ""                                                  ) : \
               Expr(a, str, ex_UVexpr(str, UV, bi, rgb, un, si), scale_inputs=si)

    integral = last

    # BLUR
    md=="gaussian" ? ex_gaussianblur(sg,pad=false,UV=uv!=3?2:3) : ex_boxblur(ceil(sg*2),mode="mean",UV=uv!=3?2:3)

    # THRESHOLD
    str  = Format("y x {th} * "+(in ? ">" : "<")+" 0 range_max ?")

    isy     ? Expr(last, integral, str                                                      , lut=lut) : \
    UV == 1 ? Expr(last, integral, str, ""                                                  , lut=lut) : \
              Expr(last, integral, str, ex_UVexpr(str, UV, bi, rgb, un), scale_inputs="none", lut=lut)

              prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
              propDelete(UV<4?prop:ArrayAdd(prop,"_ChromaLocation"))
              propSet("_ColorRange", 0) }


# mt_invert() is 10% slower and invert(channels="Y") is 17% slower
function ex_invert(clip a, bool "tv_range", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb
    lut = bi == 32 ? 0 : 1

    fs  = Defined(tv_range) ? tv_range ? false : fs : fs
    tv  = Default(tv_range, false)    # enable for non-scalar TV range clips
    UV  = Default(UV, rgb ? 3 : 1)
    si  = ex_UVf(rgb, bi)

    if (tv) {

        rmax = ex_bs(255, 8, bi, fulls=fs)
        rdif = ex_bs(  4, 8, bi, fulls=fs)
        rdifc= ex_bs(  1, 8, bi, fulls=fs)
        tvr  = rmax - rdif
        tvcr = rmax + rdifc

        str  = Format("{tvr}  x -")
        cstr = Format("{tvcr} x -")
        cstr = ex_UVexpr(cstr, UV, bi, rgb, fs, si)

    } else {

        str  = "range_max x -"
        cstr = ex_UVexpr(str, UV, bi, rgb, fs, si)
        str  = ex_dlut  (str,     bi,      fs)
    }

    isy     ?  Expr(a, str                       , lut=lut) : \
    UV == 1 ?  Expr(a, str, ""                   , lut=lut) : \
               Expr(a, str, cstr, scale_inputs=si, lut=lut) }



# mt_lutspa() is same speed (instant when spatial)
# Find usage examples here: https://avisynth.nl/index.php/MaskTools2/mt_lutspa#Examples
#
# modes:
#       absolute: x and y go from 0 to width - 1  and 0 to height - 1
#       relative: x and y go from 0 to 1.0 (excluded)
#       mix:      Can mix 'absolute' (sx,sy) with 'relative' (sxr,syr) and recall 'x' for source clip
#
# Example for 'mix' mode features:
#     ex_lutspa("sy 400 < sxr range_max * x ?")
# Example for a zone plate (0.8 is the scale):
#     ex_lutspa(Format("f32 x width 0.5 * - 2 ^ y height 0.5 * - 2 ^ + E@ pi 0.8 * * width 2 * / sin width E sqrt - width 0.1 * / "+tanhT()+" 0.5 * 0.5 + * 1 + 0.5 *"), scale_inputs="all")
#
function ex_lutspa(clip a, string "expr", string "cexpr", string "mode", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "fulld") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    isc  = Defined(cexpr)

    str  = Default( expr,  "")
    Lstr = LCase(     " "+str)
    cstr = Default(cexpr, str)
    Lcst = LCase(    " "+cstr)
    mix  = FindStr(Lstr, " sx") > 0 || FindStr(Lstr, " sy") > 0 || FindStr(Lcst, " sx") > 0 || FindStr(Lcst, " sy") > 0
    md   = Default(mode, mix ? "mix" : "absolute")
    Y    = Default(Y,          3)
    UV   = Default(UV,   rgb ? 3 : 128)
    cf   = Default(clamp_float, false)
    fd   = Default(fulld,        true)
    si   = Default(scale_inputs, ex_UVf(rgb, bi))

    tem  = FindStr(Lstr, " frameno")  > 0 || FindStr(Lstr, " time") > 0 || FindStr(Lcst, " frameno")  > 0 || FindStr(Lcst, " time") > 0

    str  = md=="absolute" ? ReplaceStr(ReplaceStr(" "+str+" " ," y "," sy " ), " x ", " sx " )  : \
           md=="relative" ? ReplaceStr(ReplaceStr(" "+str+" " ," y "," syr "), " x ", " sxr ")  : \
           md=="mix"      ?                           str                                       : \
                            Assert (false, "ex_lutspa: Unsupported mode.")
    cstr = md=="absolute" ? ReplaceStr(ReplaceStr(" "+cstr+" "," y "," sy " ), " x ", " sx " )  : \
           md=="relative" ? ReplaceStr(ReplaceStr(" "+cstr+" "," y "," syr "), " x ", " sxr ")  : \
           md=="mix"      ?                           cstr                                      : \
                            Assert (false, "ex_lutspa: Unsupported mode.")

    cstr = ex_UVexpr(cstr, UV, bi, rgb, fd, si, isc)
    str  = ex_Yexpr(  str,  Y, bi, rgb, fd, si)

    isy     ?  Expr(a, str      , scale_inputs=si, clamp_float=cf ) : \
    UV == 1 ?  Expr(a, str, ""  , scale_inputs=si, clamp_float=cf ) : \
               Expr(a, str, cstr, scale_inputs=si, clamp_float=cf )
    UV < 3 || \
    Y  < 3 ||  tem ? last : trim(last,0,-1).Loop(FrameCount(a))
    md=="mix"      ? last : propSet("_ColorRange", fd?0:1)    }



# ex_motion() replaces mt_motion(). A very basic motion mask filter.
# A better alternative is MotionMask() from MasksPack. In the future study to include a Kalman filter.
#
function ex_motion(clip a, int "lo", int "hi", int "Y", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    lut  = bi > 12 || isRunTime(a,rgb) ? 0 : 2

    lo   = Default(lo,       10)
    hi   = Default(hi,       10)
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : Y!=3 ? 3 : 128)
    un   = Undefined()

    lo   = ex_bs(lo, 8, bi, fulls=true)
    hi   = ex_bs(hi, 8, bi, fulls=true)
    th   = (lo == 0) && (hi == ex_bs(255, 8, bi, fulls=true)) ? "" : Format(" {lo} - range_max {hi} {lo} - / *")
    str  = "x y - abs"+th

    ystr =              ex_Yexpr(  str,  Y, bi, rgb, un)
    cstr = rgb ? ystr : ex_UVexpr( str, UV, bi, rgb, un)

    b    = a.selectevery(1,-1)
    isy     ?  Expr(a, b, ystr,       lut=lut) : \
    UV == 1 ?  Expr(a, b, ystr, "",   lut=lut) : \
               Expr(a, b, ystr, cstr, lut=lut)
               prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
               propDelete(UV<4?prop:ArrayAdd(prop,"_ChromaLocation"))
               propSet("_ColorRange", 0)                            }










######################
##   CONVOLUTIONS   ##
######################

# Convolutions in AviSynth+ perform better with Prefetch(min(physical cores,8)) than with threads. Also for RgTools and other plugins.

# EQUIVALENCES (ex_blur() with default mode="binomial"):
# blur(0.5)                                       ~> ex_boxblur(0.5,mode="weighted") ~> ex_blur(0.63)
# removegrain(12) / blur(1.0)                     -> ex_boxblur(1,mode="weighted") (also called half-band lowpass)
# removegrain(20) / blur(1.58)                    -> ex_boxblur(1,mode="mean")       -> ex_blur(1.5,n=300,mode="butterworth")
# removegrain(19)                                 -> ex_boxblur(1,mode="rg19")
# removegrain(12).removegrain(20)                 ~> ex_blur(2.45)
# removegrain(12).removegrain(20).removegrain(20) ~> ex_blur(3.8)
# removegrain(20).removegrain(20)                 ~> ex_blur(2.82) -> ex_boxblur(3,mode="weighted") -> ex_boxblur(1,mode="mean").ex_boxblur(1,mode="mean")
# ex_blur(n)                                      -> ex_blur(0.707*n-1).ex_blur(0.707*n-1)   (slower though)
# ex_boxblur(n,mode="mean")                       -> ex_blur(n+0.5,n=300,mode="butterworth") (slower though)



# Variable Box Blur
#
# Benchmark:
# 100% removegrain(20,-1) (485fps)
#  91% ex_boxblur(1,mode="mean",UV=1)
#  90% MiniDeen(radiusY=1, thrY=255, u=1,v=1)  # crumbles from rad=3 onwards
#  89% neo_MiniDeen(radiusY=1, thrY=255, u=1,v=1)
#  80% mt_inflate().mt_deflate()               # mean blur approximation
#  70% ex_blur(1.5,n=300,mode="butterworth")
#  69% blur(1.58)
#  67% generalconvolution(matrix="1 1 1 1 1 1 1 1 1",chroma=false)
#  65% Dither_box_filter16(2,U=1,V=1)          # with ConverttoStacked() and ConvertfromStacked()
#  44% mt_convolution("1 1 1","1 1 1",U=1,V=1)
#  13% SpatialSoften(1,30,0)                   # 8-bit YUY2 only, thresholded. Prefetch(8)
#   5% mt_luts(last, "avg", mt_square(1), "y",chroma="-1")
#
# modes:
# mean     average: mean average of a square kernel with equal weight per component (also known as moving/local mean/average)
# tent        blur: two   pass mean average (same as ex_blur(2.82)) *Not included as mode, call twice manually
# quadratic   blur: three pass mean average                         *Not included as mode, call thrice manually
# bokeh    average: mean average of a ring   kernel with equal weight per component (also known as lens blur) ( ex_expand(n,mode="ring") also works fine)
# rg19     average: mean average of a square kernel with equal weight per component except central pixel (weight = 0) -matches removegrain(19)-
# weighted average: mean average of a square kernel with custom local weights per component (also called 'binomial' commonly used for Gaussian approximation; blur(1), removegrain(12), etc)
# trimmed  average: mean average of a square kernel with equal weight per component limited by its local median
#
# ex_boxblur(2,mode="weighted") same to ex_blur(2.1) and ex_boxblur(1,mode="mean").ex_boxblur(1,mode="mean"), and Dither_box_filter16(1,U=1,V=1).Dither_box_filter16(1,U=1,V=1), Dither_ about same speed
#
#
# Function Definition:
#    (
#    clip,
#    int radius=1 (0 to 14),
#    [int radiusV=1 (0 to 14)],
#    string "mode"="mean" ("mean"/ "weighted"/ "rg19"/ "trimmed"/ "bokeh")
#    )
#
function ex_boxblur(clip a, float "radius", float "radiusV", string "mode", int "Y", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # integers from 0 to inf ('weighted' also allows 0.15, 0.3, 0.5 and integers up to 14 -single float AVSValue limit-)
    rv = Default(radiusV, rd)           # integers from 0 to inf ('weighted' also allows 0.15, 0.3, 0.5 and integers up to 14 -single float AVSValue limit-)

    fbox  = rd == 1    && rv == 1
    fbox2 = rd == 0.5  && rv == 0.5
    fbox3 = rd == 0.3  && rv == 0.3
    fbox4 = rd == 0.15 && rv == 0.15

    Y  = Default( Y,           3)
    UV = Default(UV,    rgb  ? 3 : 1)
    md = Default(mode,  "mean")
    md = md == "binomial" ? "weighted" : md
    rd = max(rd>1?round(rd):rd, 0)
    rv = max(rv>1?round(rv):rv, 0)
    un = Undefined()

    isf = (rv > 0 && rv < 1) || (rd > 0 && rd < 1)
    isf              ? Assert (md == "weighted",   "ex_boxblur: float radius requires 'weighted' mode")                     : nop()
    md == "trimmed"  ? Assert (fbox,               "ex_boxblur: 'Trimmed' mode only supports radius=1 for both dimensions") : nop()
    md == "bokeh"    ? Assert (rd == rv,           "ex_boxblur: 'Bokeh' mode only supports isotropic radii")                : nop()
    md == "weighted" ? Assert (rd < 15 || rv < 15, "ex_boxblur: Maximum radius reached for 'weighted' mode")                : nop()

    krnlsz = ceil(2 * rd)
    krnlrd = krnlsz/2

    krnh = ""  krnv = ""  plsh = ""  plsv = ""  divx=0  divy=0  divw=0
    if (md == "bokeh") {

        for (px = -krnlrd, krnlrd, 1) {
                for (py = -krnlrd, krnlrd, 1) {
                    skipo = (px*px + py*py) > pow(krnlrd+0.3,   2)
                    skipi = (px*px + py*py) > pow(krnlrd+0.3-1, 2)
                    krnv  = skipo || !skipi ? krnv : Format(krnv + "x[{px},{py}] ")
                    plsv  = skipo || !skipi ? plsv : plsv + "+ "
                    divy  = skipo || !skipi ? divy : divy + 1
           }
      }
                    plsv = LeftStr(plsv, StrLen(plsv)-2)

    } else if (!fbox || !(rd<1 || rv<1)) {

            wgc  = md == "weighted" ?  binom_coeffs(krnlsz, krnlrd)                  : nop()

        for (px = -krnlrd, krnlrd, 1) {
            wg   = md == "weighted" ?  binom_coeffs(krnlsz, krnlsz-(abs(px)+krnlrd)) : nop()
            krnh = md == "rg19"     && px == 0 ? krnh                                                                 : \
                   md == "weighted" && px  > 0 ? px == krnlrd ? Format(krnh + "x[{px},0] x[-{px},0] x[0,0] {wgc} * ") : \
                                                                Format(krnh + "x[{px},0] x[-{px},0] + {wg} * ")       : \
                   md != "weighted"                           ? Format(krnh + "x[{px},0] ") : ""
            plsh = px ==  -krnlrd || (md == "rg19" && px == 0) || md == "weighted" && px < 0 ? plsh : plsh + "+ "
            divw = md == "weighted" ?       wg + divw  : nop()
            divx = md == "rg19"     && px == 0 ? divx  : \
                   md == "weighted"            ? divw  : divx + 1
           }


        krnlsz = ceil(2 * rv)
        krnlrv = krnlsz/2       divw=0

            wgc  = md == "weighted" ?  binom_coeffs(krnlsz, krnlrv)                  : nop()

        for (py = -krnlrv, krnlrv, 1) {
            wg   = md == "weighted" ?  binom_coeffs(krnlsz, krnlsz-(abs(py)+krnlrv)) : nop()
            krnv = md == "rg19"     && py == 0 ? krnv                                                                 : \
                   md == "weighted" && py  > 0 ? py == krnlrv ? Format(krnv + "x[0,{py}] x[0,-{py}] x[0,0] {wgc} * ") : \
                                                                Format(krnv + "x[0,{py}] x[0,-{py}] + {wg} * ")       : \
                   md != "weighted"                           ? Format(krnv + "x[0,{py}] ") : ""
            plsv = py ==  -krnlrv || (md == "rg19" && py == 0) || md == "weighted" && py < 0 ? plsv : plsv + "+ "
            divw = md == "weighted" ?       wg + divw  : nop()
            divy = md == "rg19"     && py == 0 ? divy  : \
                   md == "weighted"            ? divw  : divy + 1
           }
   }

    strv =       md == "weighted" ?                                                                                                                                  \
                 fbox             ? "x[-1,1] x[1,1] x[-1,-1] x[1,-1] + + + 0.5 * x[0,1] x[-1,0] x[1,0] x[0,-1] x[0,0] 2 * + + + + + 0.125 *"                       : \
                 fbox2            ? "x[0,1] x[-1,0] x[0,0] 3  * x[1,0] x[0,-1] + + + + 0.142857143 *"                                                              : \
                 fbox3            ? "x[0,1] x[-1,0] x[0,0] 6  * x[1,0] x[0,-1] + + + + 0.1         *"                                                              : \
                 fbox4            ? "x[0,1] x[-1,0] x[0,0] 12 * x[1,0] x[0,-1] + + + + 0.0625      *"                                                              : \
                 rv == 0.5        ? "x[0,1]  x[0,0] 5  * x[0,-1] + + 0.142857143 *"                                                                                : \
                 rv == 0.3        ? "x[0,1]  x[0,0] 8  * x[0,-1] + + 0.1         *"                                                                                : \
                 rv == 0.15       ? "x[0,1]  x[0,0] 16 * x[0,-1] + + 0.055555555 *"                                                                                : \
                                    krnv + plsv + (rv > 7 ? string(divy)+" /" : string(1./divy)+" *") : ""

    strh =       md == "weighted" ?                                                                                                                                  \
                 rd == 0.5        ? "x[-1,0] x[0,0] 5  * x[1,0]  + + 0.142857143 *"                                                                                : \
                 rd == 0.3        ? "x[-1,0] x[0,0] 8  * x[1,0]  + + 0.1         *"                                                                                : \
                 rd == 0.15       ? "x[-1,0] x[0,0] 16 * x[1,0]  + + 0.055555555 *"                                                                                : \
                                    krnh + plsh + (rd > 7 ? string(divx)+" /" : string(1./divx)+" *") : ""


    str = fbox ? md == "rg19"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + 0.125 *"                                           : \
                 md == "bokeh"    ?"x[0,1] x[-1,0] x[1,0] x[0,-1] + + + 0.25 *"                                                                                    : \
                 md == "mean"     ?"x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[0,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + 0.111111111 *"                            : \
                 md == "trimmed"  ?"x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[0,0] E@ x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ + + + + + + + + 0.111111111 * X^ "\
                                  +"F I  dup1 dup1 min F^ max I^ "                                                                                                   \
                                  +"B H  dup1 dup1 min B^ max H^ "                                                                                                   \
                                  +"D G  dup1 dup1 min D^ max G^ "                                                                                                   \
                                  +"A E  dup1 dup1 min A^ max E^ "                                                                                                   \
                                  +"B I  dup1 dup1 min B^ max I^ "                                                                                                   \
                                  +"E G  dup1 dup1 min E^ max G^ "                                                                                                   \
                                  +"A F  dup1 dup1 min A^ max F^ "                                                                                                   \
                                  +"C D  dup1 dup1 min C^ max D^ "                                                                                                   \
                                  +"G I            min G^        "                                                                                                   \
                                  +"F H  dup1 dup1 min F^ max H^ "                                                                                                   \
                                  +"D E  dup1 dup1 min D^ max E^ "                                                                                                   \
                                  +"A B  dup1 dup1 min A^ max B^ "                                                                                                   \
                                  +"E H            min E^        "                                                                                                   \
                                  +"C F  dup1 dup1 min C^ max F^ "                                                                                                   \
                                  +"B D  dup1 dup1 min B^ max D^ "                                                                                                   \
                                  +"E G  dup1 dup1 min E^ max G^ "                                                                                                   \
                                  +"D F  dup1 dup1 min D^ max F^ "                                                                                                   \
                                  +"A C                   max C^ "                                                                                                   \
                                  +"F G            min F^        "                                                                                                   \
                                  +"D E  dup1 dup1 min D^ max E^ "                                                                                                   \
                                  +"B C                   max C^ "                                                                                                   \
                                  +"E F                   max    "                                                                                                   \
                                  +"C D                   max    "                                                                                                   \
                                  +"X swap2 clip" : "" : krnv + plsv + string(1./divy) + " *"


    strv  =          md == "weighted" ? strv : \
            fbox  || md == "bokeh"    ? str  : \
            krnv + plsv + string(1./divy) + " *"

    strh  =          md == "weighted" ? strh : \
            krnh + plsh + string(1./divx) + " *"

    ystrv = ex_Yexpr (strv, Y, bi, rgb, un)
    ystrh = ex_Yexpr (strh, Y, bi, rgb, un)

    rv == 0 ?      a                                                                   : \
    isy     ? Expr(a,    ystrv                                                       ) : \
    UV == 1 ? Expr(a,    ystrv, ""                                                   ) : \
              Expr(a,    ystrv, ex_UVexpr(strv, UV, bi, rgb, un), scale_inputs="none")
    rd == 0 || fbox || fbox2 || fbox3 || fbox4 || md=="bokeh"  ? last                  : \
    isy     ? Expr(last, ystrh                                                       ) : \
    UV == 1 ? Expr(last, ystrh, ""                                                   ) : \
              Expr(last, ystrh, ex_UVexpr(strh, UV, bi, rgb, un), scale_inputs="none") }


function binom_coeffs(n, k) {
    k > n   ? Assert(false,"binom_coeffs: k > n error")    : \
    k == 0  ? 1                              : \
    k > n/2 ? binom_coeffs(n,n-k)            : \
              n * binom_coeffs(n-1,k-1) / k  }



# Variable Gaussian Blur
#
# Benchmark (binomial fitted):
# 100% removegrain(12,-1) (486fps)                  # technically a binomial weighted mean of [1 2 1]
#  97% GBlur2(sqrt(1)/2.*sqrt(2),chroma=2)          # only in 8-bit.         weighted mean of [1 2 1]
#  90% ex_boxblur(1,mode="weighted",UV=1)           # binomial weighted mean
#  88% ablur(1, 1, chroma=1)                        # against ex_boxblur(2,mode="weighted",UV=1)
#  85% BinomialBlur(sqrt(1)/2.*sqrt(2),U=1,V=1)     # only in 8-bit
#  81% vsTCanny(sqrt(1)/2.*sqrt(2),mode=-1,u=1,v=1) # true gaussian (fastest for mid sigma, not apt for combing -not exact binomial fit of rad=1-)
#  70% ex_blur(1,mode="binomial",UV=1)              # true gaussian blur
#  68% blur(1.00)                                   # weighted mean of [1 2 1]
#  65% generalconvolution(matrix="1 2 1 2 4 2 1 2 1",chroma=false)
#  44% mt_convolution("1 2 1","1 2 1",U=1,V=1)
#  23% GBlur(rad=1,sd=0.9,u=false,v=false)
#  11% FastBlur(sqrt(1)/2.*sqrt(2),gamma=false)
#  11% GaussianBlur(1/2.,U=1,V=1)                   # only in 8-bit
#
# ex_blur() is the reference blur function, with correct gaussian coefficients and chroma subsampling adapted sigma.
# Also includes a gamma aware option for more correct defocus on non-scalar clips (requires TransformsPack).
# Borders are not as protected as vsTCanny().
#
# modes:
# gaussian:    true gaussian blur
# binomial:    discreet gaussian blur approximation (Default)
# butterworth: bias between a ~gaussian (n=8) and mean (n=300) blur distribution with default n=6 (decay of 6dB/oct) typical for frequency domain low-pass.
#
# Other:
# half-band:    ex_blur(1) or ex_boxblur(1,mode="weighted"). 'low-pass' filter, reduces the maximum bandwidth of sampled data (resolution) by a factor of 2 (1 octave)
# quarter-band: ex_blur(5) or ex_boxblur(5,mode="weighted"). 'low-pass' filter, reduces the maximum bandwidth of sampled data (resolution) by a factor of 4 (2 octaves)
#
#
# Function Definition:
#    (
#    clip,
#    float radius=1.0 (0.0 to 43.0),
#    [float radiusV=1.0 (0.0 to 43.0)],
#    [int "n"=6 (0 to 300)],
#    [string "mode"="binomial" ("gaussian"/ "binomial"/ "butterworth")],
#    [string "gamma"="none" ("none"/ "linear"/ "1886a"/ "1886"/ "470M"/ "470BG"/ "240M"/ "170M"/ "709-Camera"/ "sRGB"/ "AdobeRGB"/ "CIELab"/ "Apple"/ "Chrome"/ "xvYCC"/ "PhotoCD"/ "2020NCL"/ "2020CL"/ "DCIXYZ"/ "PQ"/ "HLG"/ "HLG NHK"/ "ACESCCt"/ "log100"/ "log316"/ "1361")],
#    [int "UV"=3 (2 to 3)]
#    )
#
function ex_blur(clip a, float "radius", float "radiusV", int "n", string "mode", string "gamma", int "Y", int "UV", bool "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    rm  = Default(radius,   1)             # Avoid going over 43 for "butterworth" at default 'n=6' or clip range will be compromised -single float AVSValue limit-
    rv  = Default(radiusv, rm)
    n   = Default(n,        6)             # 0-inf. slope in frequency domain of the lowpass in dB/oct units. In spatial domain a bias between "butterworth" 1st order (similar to "gaussian") and "sinc" or "brickwall" ideal filter (same to "mean" blur with rad+0.5 and n>300)
    md  = Default(mode,"binomial")         # "gaussian": true gaussian distribution  "binomial": binomial distribution fit (like blur() or ex_boxblur(mode="weighted") )  "butterworth": between gaussian and mean blur falloff distribution
    gm  = Default(gamma,   "none")         # Set transfer for "gamma" encoded clips (ie. 601, 709, 2020...). Requires TransformsPack
    Y   = Default( Y,          3)
    UV  = Default(UV,    rgb ? 3 : 1)
    fs  = Default(fulls, fs)

    # Binomial Fit
    rm  = max(rm,0)
    rv  = max(rv,0)
    sm  = md == "binomial" ? (sqrt(rm) / 2) * sqrt(2) : float(rm)
    sv  = md == "binomial" ? (sqrt(rv) / 2) * sqrt(2) : float(rv)

    # LUMA
    strv = md == "butterworth" ? butt_constructor(sv,n,true)  : gauss_constructor(sv,true)
    strh = md == "butterworth" ? butt_constructor(sm,n,false) : gauss_constructor(sm,false)

    # CHROMA
    p_4 = is444(a) || rgb  p_1 = isYV411(a)
    p_2 = is422(a)         p_0 = is420(a)

    sv = sv/(!p_0 ? 1 :           2)
    sm = sm/( p_4 ? 1 : p_1 ? 4 : 2)

    cstrv = md == "butterworth" ? butt_constructor(sv,n,true)  : gauss_constructor(sv,true)
    cstrh = md == "butterworth" ? butt_constructor(sm,n,false) : gauss_constructor(sm,false)

    if (gm != "none") {
        a      = CCTF(a, gm, true, !fs, false)
    }

    strv = ex_Yexpr (strv, Y, bi, rgb, fs)
    strh = ex_Yexpr (strh, Y, bi, rgb, fs)

    sv == 0 ?      a                                                                   : \
    isy     ? Expr(a,    strv                                                        ) : \
    UV == 1 ? Expr(a,    strv, ""                                                    ) : \
              Expr(a,    strv, ex_UVexpr(cstrv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ?      last                                                                : \
    isy     ? Expr(last, strh                                                        ) : \
    UV == 1 ? Expr(last, strh, ""                                                    ) : \
              Expr(last, strh, ex_UVexpr(cstrh, UV, bi, rgb, fs), scale_inputs="none")

    gm != "none" ? CCTF(last, gm, false, false, !fs) : last                          }


function gauss_constructor(float rad, bool vert) {

    str = "" pls="" di=0
    krnlsz = 2*ceil(3*rad)
    krnlrd = krnlsz/2

    for (i=0, krnlsz, 1) {
        wgc   = exp(-(pow(i-krnlrd,2))/(2*rad*rad))
        di    = wgc < 0.001 ? di : di + wgc
       }

    for (i=0, krnlrd, 1) {

        ga    = exp(-(pow(i-krnlrd,2))/(2*rad*rad))
        wg    = ga/di
        px    = abs(i-krnlrd)
        str   = ga < 0.001 ? str : Format( str + (i == krnlrd ? "x[0,0] {wg} * " : \
                vert ? "x[0,{px}] x[0,-{px}] + {wg} * " : "x[{px},0] x[-{px},0] + {wg} * "))
        pls   = i == krnlrd || ga < 0.001 ? pls : pls + "+ "
       }

    str + pls }


function butt_constructor(float rad, int n, bool vert) {

    str = "" pls="" di=0
    krnlsz = 2*ceil(3*rad)
    krnlrd = krnlsz/2

    for (i=0, krnlsz, 1) {
        wgc   = 1. / (1 + pow( (abs(i-krnlrd)/rad), 2*(n/6.) ))
        di    = wgc < 0.001 ? di : di + wgc
       }

    for (i=0, krnlrd, 1) {

        px    = abs(i-krnlrd)
        ga    = 1. / (1 + pow( px/rad, 2*(n/6.) ))
        wg    = ga/di
        str   = ga < 0.001 ? str : Format( str + (i == krnlrd ? "x[0,0] {wg} * " : \
                vert ? "x[0,{px}] x[0,-{px}] + {wg} * " : "x[{px},0] x[-{px},0] + {wg} * "))
        pls   = i == krnlrd || ga < 0.001 ? pls : pls + "+ "
       }

    str + pls }



# ex_blur3D()
#
# modes:
# mean     - cubic     blur
# weighted - spherical blur (beware this mode doesn't have SCD -scene change detection-)
#
# By order of strength: mean3D > weighted3D > ex_median("IQMT") > ex_fluxsmoothST(th=255>0)
#
# Function Definition:
#    (
#    clip,
#    int x=1 (0 to 14),
#    int y=1 (0 to 14),
#    int z=1 (0 to 7),
#    string "mode"="mean" ("mean"/ "weighted")
#    )
#
function ex_blur3D(clip a, int "x", int "y", int "z", string "mode", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    x   = Default(x,  1)        # from 0 to 14
    y   = Default(y,  x)        # from 0 to 14
    z   = Default(z,  x)        # from 0 to 7
    md  = Default(mode,  "mean")
    UV  = Default(UV,    rgb ? 3 : 1)
    un  = Undefined()

    md  = md == "avg"     ? "mean" : \
          md == "average" ? "mean" : \
          md == "mean"    ? "mean" : "weighted"
    a
    x+y!=0 ? ex_boxblur(x,y, mode=md, UV=uv) : last

    TG = z == 1 ? "                                                                                             y z                 x 2           * + + 0.25 * " : \
         z == 2 ? "y z + 4           *                                                                          a b                 x 6           * + + + 0.0625 * " : \
         z == 3 ? "a b + 6           * y z + 15          *                                                      c d                 x 20          * + + + + 0.015625 * " : \
         z == 4 ? "c d + 0.571428571 * a b + 2           * y z + 4           *                                  e f + 0.071428571 * x 5           * + + + + 0.0546875 * " : \
         z == 5 ? "e f + 0.238095238 * c d + 1.071428571 * a b + 2.857142857 * y z + 5    *                     g h + 0.023809523 * x 6           * + + + + + 0.041015625 * " : \
         z == 6 ? "g h + 0.090909091 * e f + 0.5         * c d + 1.666666666 * a b + 3.75 * y z + 6 *           i j + 0.007575757 * x 7           * + + + + + + 0.032226562 * " : \
                  "i j + 0.013986014 * g h + 0.090909091 * e f + 0.363636363 * c d +        a b + 2 * y z + 3 * k l + 0.001       * x 3.428571428 * + + + + + + + 0.061096191 * "

    for (i=1, min(z,7), 1) {
        clps = (i==1 ? "last," : clps) + Format("last.selectevery(1,-{i}), last.selectevery(1,{i}),") }

    z  == 0 || md!="weighted" ? last                                                                                                          : \
    isy                       ? Eval("""Expr("""+clps+""" TG,                                 optSingleMode = false                     )""") : \
    UV == 1                   ? Eval("""Expr("""+clps+""" TG, "",                             optSingleMode = false                     )""") : \
                                Eval("""Expr("""+clps+""" TG, ex_UVexpr(TG, UV, bi, rgb, un), optSingleMode = false, scale_inputs="none")""")

    z  != 0 && md=="mean"     ? TemporalSoften(z,255,UV==3?255:0,25,2) : last }



# 100% Dither_bilateral16(radius=2, thr=10, flat=1.0,   u=1, v=1) (216fps) # Output is dirtier though
#  77% ex_bilateral(1,dejaggie=false)
#  59% vsTBilateral(diameterY=3, sdevY=4, idevY=4.0,    u=1, v=1)
#  43% TBilateral(3,3,chroma=false)                                        # only supports 8-bits
#  23% bilateral(sigmaSY=1, sigmaRY=0.02, algorithmY=2, u=1, v=1)
#
# Function Definition:
#    (
#    clip,
#    float radius=1.0 (0.0 to 3.0),
#    [float radiusV=1.0 (0.0 to 3.0)],
#    float "ithres"=4.0 (0.0 to 10.0),
#    float "sthres"=4.0 (0.0 to 10.0),
#    bool "dejaggie"=true
#    )
#
function ex_bilateral(clip a, float "radius", float "radiusV", float "ithres", float "sthres", bool "dejaggie", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    sm = Default(radius,   2)           # from 0 to 6. More doesn't bring more denoising.
    sv = Default(radiusv, sm)           # from 0 to 6
    it = Default(ithres,   4)           # 0.1 to 10. Intensity standard deviation target used to compute coefficients for the intensity Gaussian filter. Keep low for more edge preservation.
    st = Default(sthres,   4)           # 0.1 to 10. Spatial   standard deviation target used to compute coefficients for the spatial   Gaussian filter. Higher values spread the weights further away.
    dj = Default(dejaggie, true)
    UV = Default(UV,    rgb ? 3 : 1)

    sm > 13 || sv > 13 ? Assert (false, "ex_bilateral: Radius should be 13 or below") : nop()
    sm = sm * 0.30
    sv = sv * 0.30

    krnlsz = 2*ceil(3*sv)
    krnlrv = krnlsz/2

    vars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    Vc   = MidStr(vars,krnlrv+1,1)
    dj   = dj ? Vc+" 0.3 * min" : ""
    it   = 1./ ex_bs(it, 8, bi, fulls=fs, flt=true)

    krnv2 = "" krnv3 = ""  Vv = "" krnh2 = "" krnh3 = "" Vh = ""

    for (i=0, krnlsz, 1) {

        V     = MidStr(vars,i+1,1)
        py    = i - krnlrv
        krnv1 = Format("x[0,{py}] ")

        Vv    = Vv + " " + V
        wg    = exp(pow(sqrt(pow(py,2))/st,2))
        krnv2 = i != krnlrv ? Format(krnv2 + krnv1 + V + "@ "+Vc+" - "+dj+" {it} * dup * 0.5 * "+expT(5)+" {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnv2
        krnv3 = i == krnlrv ? Format(                V + "  "+Vc+" - "+dj+" {it} * dup * 0.5 * "+expT(5)+" {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnv3
        plsv  = i == 0 ? "" : plsv + " + " }


    krnlszh = 2*ceil(3*sm)
    krnlrd  = krnlszh/2
    Vc      = MidStr(vars,krnlrd+1,1)

    for (i=0, krnlszh, 1) {

        V     = MidStr(vars,i+1,1)
        px    = i - krnlrd
        krnh1 = Format("x[{px},0] ")

        Vh    = Vh + " " + V
        wg    = exp(pow(sqrt(pow(px,2))/st,2))
        krnh2 = i != krnlrd ? Format(krnh2 + krnh1 + V + "@ "+Vc+" - "+dj+" {it} * dup * 0.5 * "+expT(5)+" {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnh2
        krnh3 = i == krnlrd ? Format(                V + "  "+Vc+" - "+dj+" {it} * dup * 0.5 * "+expT(5)+" {wg} * 1 swap / "+V+" swap "+V+"@ * ") : krnh3
        plsh  = i == 0 ? "" : plsh + " + " }

    strv = "x[0,0] " + Vc + "^ " + krnv2 + krnv3 + plsv + Vv + plsv + "1 swap / *"
    strh = "x[0,0] " + Vc + "^ " + krnh2 + krnh3 + plsh + Vh + plsh + "1 swap / *"

    sv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ?      last                                                               : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }



# Like ex_bilateral(), a less gentle blurring but more performant
# Similar to SurfaceBlur() by Didée: https://forum.doom9.org/showthread.php?p=1586287
# SurfaceBlur(3,5) is 22% slower than ex_smartblur(3,thres=20)
#
# A good value for HD anime is: ex_smartblur(3,thres=6)
#
function ex_smartblur(clip a, float "radius", float "radiusV", float "thres", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    sm = Default(radius,   1)           # from 0 to 6
    sv = Default(radiusv, sm)           # from 0 to 6
    th = Default(thres,   15)
    UV = Default(UV,    rgb ? 3 : 1)
    th = ex_bs(th, 8, bi, fulls=fs, flt=true)

    sm > 13 || sv > 13 ? Assert (false, "ex_smartblur: Radius should be 13 or below") : nop()

    krnlsz = 2*ceil(3*sv * 0.30)

    vars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    Vc   = MidStr(vars,krnlsz/2+1,1)

    krnv2 = "" krnv3 = ""  Vv = "" krnh2 = "" krnh3 = "" Vh = ""  divx=0  divy=0

    for (i=0, krnlsz, 1) {

        V     = MidStr(vars,i+1,1)
        Vv    = Vv + " " + V
        py    = i - krnlsz/2
        krnv2 = Format(krnv2 + "x[0,{py}] " + V + "^ ")
        krnv3 = Vc != V ? Format(krnv3      + V + " " + Vc + " - abs ") : krnv3
        plsv  = i == 0 ? "" : Vc == V ? plsv : plsv + " + "
        divy  = divy + 1  }


    krnlszh = 2*ceil(3*sm * 0.30)
    Vc      = MidStr(vars,krnlszh/2+1,1)

    for (i=0, krnlszh, 1) {

        V     = MidStr(vars,i+1,1)
        Vh    = Vh + " " + V
        px    = i - krnlszh/2
        krnh2 = Format(krnh2 + "x[{px},0] " + V + "^ ")
        krnh3 = Vc != V ? Format(krnh3      + V + " " + Vc + " - abs ") : krnh3
        plsh  = i == 0 ? "" : Vc == V ? plsh : plsh + " + "
        divx = divx + 1   }

    strv = krnv2 + krnv3 + plsv + string(th*sv) + " < " + Vv + plsv + " + " + string(1./divy) + " * x ?"
    strh = krnh2 + krnh3 + plsh + string(th*sm) + " < " + Vh + plsh + " + " + string(1./divx) + " * x ?"

    sv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    sm == 0 ?      last                                                               : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }


# modes:
# SG  - Savitzky-Golay (S-G) smoothing filter, a least-squares polynomial smoothing approach (between an antialiaser and a blur)
# SNN - Symmetrical Nearest Neighbour based pair average. Resembles ex_sbr() but a bit blurrier
#
# Function Definition:
#    (
#    clip,
#    int radius=1 (0 to 3),
#    [int radiusV=1 (0 to 3)],
#    string "mode"="SG" ("SG"/ "SNN"),
#    bool "limit"=false,
#    bool "sharp"=false
#    )
#
function ex_smooth(clip a, int "radius", int "radiusV", bool "sharp", bool "limit", string "mode", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to 3
    rv = Default(radiusV, rd)           # from 0 to 3
    sh = Default(sharp, false)          # Sharp version of S-G mode
    lm = Default(limit,    sh)          # Enable limiting for Sharp mode
    md = Default(mode,  "SG")
    UV = Default(UV,    rgb ? 3 : 1)
    un = Undefined()
    rd = max(rd, 0)
    rv = max(rv, 0)

    rd == 3 || rv == 3 ? Assert (!sh,                          "ex_smooth: S-G Sharp mode only supports radius < 3") : nop()
    md == "SNN"        ? Assert (rd == rv && rd < 2 && rv < 2, "ex_smooth: SNN mode only supports radius < 2")       : nop()

    if (!sh) {

    # Quadratic/Cubic (2nd and 3rd degree polynomials)
    strv = rv == 1 ? "x[0,1] x[0,-1] + 4 * x[0,0] 5.666666666 * + x[0,-2] x[0,2] + - 0.085714286 *"                                                                : \
           rv == 2 ? "x[0,1] x[0,-1] + 2 * x[0,0] 2.333333333 * x[0,-2] x[0,2] + + + x[0,-3] x[0,3] + 0.666666666 * - 0.142857143 *"                               : \
           rv == 3 ? "x[0,3] x[0,-3] + 4.666666666 * x[0,2] x[0,-2] + 13 * x[0,1] x[0,-1] + 18 * x[0,0] 19.666666666 * + + + x[0,-4] x[0,4] + 7 * - 0.012987013 *" : ""

    strh = rd == 1 ? "x[-1,0] x[1,0] + 4 * x[0,0] 5.666666666 * + x[2,0] x[-2,0] + - 0.085714286 *"                                                                : \
           rd == 2 ? "x[-1,0] x[1,0] + 2 * x[0,0] 2.333333333 * x[2,0] x[-2,0] + + + x[3,0] x[-3,0] + 0.666666666 * - 0.142857143 *"                               : \
           rd == 3 ? "x[3,0] x[-3,0] + 4.666666666 * x[2,0] x[-2,0] + 13 * x[1,0] x[-1,0] + 18 * x[0,0] 19.666666666 * + + + x[-4,0] x[4,0] + 7 * - 0.012987013 *" : ""

    } else {

    # Quartic/Quintic (4th and 5th degree polynomials) (sharper)
    strv = rv == 1 ? "x[0,1] x[0,-1] + 15 * x[0,0] 26.2 * x[0,3] x[0,-3] + + + x[0,-2] x[0,2] + 6 * - 0.021645022 *"                                               : \
           rv == 2 ? "x[0,2] x[0,-2] + 2 * x[0,1] x[0,-1] + 9 * x[0,0] 11.933333333 * x[0,4] x[0,-4] + + + + x[0,-3] x[0,3] + 3.666666666 * - 0.034965035 *"       : ""

    strh = rd == 1 ? "x[1,0] x[-1,0] + 15 * x[0,0] 26.2 * x[3,0] x[-3,0] + + + x[-2,0] x[2,0] + 6 * - 0.021645022 *"                                               : \
           rd == 2 ? "x[2,0] x[-2,0] + 2 * x[1,0] x[-1,0] + 9 * x[0,0] 11.933333333 * x[4,0] x[-4,0] + + + + x[-3,0] x[3,0] + 3.666666666 * - 0.034965035 *"       : ""

    }

    strv = md == "SNN" ? "x[0,0] X@  x[-1,1] A@ - abs X x[1,-1]  H@ - abs + M@
                          X          x[0,1]  B@ - abs X x[0,-1]  G@ - abs + N@ min
                          X          x[1,1]  C@ - abs X x[-1,-1] F@ - abs + O@ min
                          X          x[-1,0] D@ - abs X x[1,0]   E@ - abs +    min W^
                          W M == A H + W N == B G + W O == C F + D E + ? ? ? 0.5 *"    : strv

    rv == 0  ?      a                                                                  : \
    isy      ? Expr(a,    strv                                                       ) : \
    UV == 1  ? Expr(a,    strv, ""                                                   ) : \
               Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, un), scale_inputs="none")
    rd == 0  || md == "SNN" ? last                                                     : \
    isy      ? Expr(last, strh                                                       ) : \
    UV == 1  ? Expr(last, strh, ""                                                   ) : \
               Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, un), scale_inputs="none")

    lm && sh ? ex_luts(last,a,mode="clamp",pixels=ex_shape(min(1,rd),min(1,rv)),UV=uv) : last }


# Kawase blur multipass kernel for optimized Gaussian blur approximation with high sigma (don't use for binarized masks)
#
# Benchmark:
# 100% ex_kawase(1,"lin",UV=1)  (442fps)
#  77% ex_boxblur(2,mode="weighted",UV=1)
#  76% FastGaussBlur(1)                      # but scales up better than kawase for ex_kawase() > 2
#  75% removegrain(12,-1).removegrain(12,-1)
#  75% FRC_GaussianBlur42(1)                 # but scales up better than kawase for ex_kawase() > 2
#  72% ex_blur(2,UV=1)                       # ex_kawase(2,"lin") equals to ex_blur(8,UV=1)
#
# Benchmark (max blur):
# 100% ex_gaussianblur(156,UV=2)  (302fps)
#  37% ex_kawase(9,"trib" ,UV=2)  (111fps)
# 1.3% vsTCanny(156,mode=-1,U=2,V=2)
#
# modes:
# lin  - linear     multipass: 1,2,3,4,5...
# log  - log2       multipass: 1,2,2,3,3,3...
# fib  - fibonacci  multipass: 1,1,2,3,5,8...
# trib - tribonacci multipass: 1,1,2,4,7,13...
#
function ex_kawase(clip a, int "radius", string "mode", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,  1)            # from 0 to ~12 (hard limit)
    md = Default(mode, "log")
    UV = Default(UV,    rgb ? 3 : 2)
    un = Undefined()

    str = ""
    for (i = 1, rd, 1) {
        c   = i  == 1      ? "a," : ""
        dot = i  == rd     ? ""   : "."
        px  = md == "log"  ? Eval(LeftStr(String(log(i)/log(2)+1,"%0.1f"),1))      : \
              md == "fib"  ? floor(pow((1+sqrt(5))/2,i)/sqrt(5)+0.5)               : \
              md == "trib" ? floor(0.618033988749895*pow(1.839286755214161,i)+0.5) : \
                             i
        krn =                         Format("x[-{px},{px}] x[{px},{px}] x[-{px},-{px}] x[{px},-{px}]         x[0,0] + + + + 0.2 *")
        pxc = max(0, px - 1)
        krc = is444(a) || rgb ? krn : Format("x[-{pxc},{pxc}] x[{pxc},{pxc}] x[-{pxc},-{pxc}] x[{pxc},-{pxc}] x[0,0] + + + + 0.2 *")
        str = str + Format(isy     ?   "Expr(  "+c+"     "+Chr(34)+krn+Chr(34)+"                                                                                )"   : \
                           UV == 1 ?   "Expr(  "+c+"     "+Chr(34)+krn+Chr(34)+",               "+Chr(34)+" "+Chr(34)+"                                         )"   : \
                                     """Expr("""+c+""" """+Chr(34)+krn+Chr(34)+""", ex_UVexpr("""+Chr(34)+krc+Chr(34)+""", UV, bi, rgb, un), scale_inputs="none")""")+dot
           }

    rd != 0 ? Eval(str) : a }



#######################################################################
##
## ex_GaussianBlur() by Dogway (15-12-2021)
## Large-sigma optimized gaussian blur filter
##
## Heavy mod of FRC_GaussianBlur42()
## https://forum.doom9.org/showthread.php?p=1807156
##
##
## Dependencies:
##     ResizersPack
##     vsTCanny  (for small radii or small sources - h <= 480)
##
## 2013-10-23 raffriff42
## 2014-05-31 discrete hor. and vert. args
## 2017-05-21 bugfix: blockiness
## 2021-09-05 Optimized (~38% gain) and profiled after ex_blur(), also Y+UV args
## 2021-09-22 Added padding to protect borders and fallback to ex_blur() for low sigma
## 2021-10-12 Reparametrized. Changed to bilinear downscale, faster and more accurate. Change to mod2
## 2021-10-31 Reparametrized. Optimal 'p' value and linear regressed when pad=true
## 2021-12-15 Reparametrized. Correct UV blurring. Further fit fine-tuning and fallback to vsTcanny for erratic fit in pad=false + high radii (>21) + small source
##
##
## Function Definition:
##    (
##     clip,
##     float sigma=1.0 (0.0 to 150.0),
##    [float sigmaV=1.0 (0.0 to 150.0)],
##    [bool "pad"=true],
##    [bool "mblur"=true],
##    [int "UV"=3 (1 / 2 / 3)]
##    )
##
## Benchmarks:
##    100% ex_gaussianblur(6,UV=2)  (396fps)      (gaussian approximation, fastest for large sigma)
##     47% vsTCanny(6,mode=-1,u=1,v=1)            (true gaussian,          fastest for mid   sigma)
##     21% ex_blur (6,mode="gaussian",UV=1)       (true gaussian,          best    for low   sigma)

function ex_GaussianBlur(clip a, float "sigma", float "sigmaV", bool "pad", bool "mblur", int "Y", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    w0   = Width(a)
    h0   = Height(a)
    bi   = BitsPerComponent(a)

    rd   = Default(sigma,    10)
    rv   = Default(sigmaV,   rd)
    pad  = Default(pad,    true)
    mb   = Default(mblur,  true)              # minimum blur. Default true to swap to vsTcanny() for low sigmas (more accuracy)
    Y    = Default(Y,         3)
    UV   = Default(UV,  rgb ? 3 : 2)

    # Reparametrization to gaussian like standard deviation via piecewise multivariate regression
    py = "a1   = -0.000484987*pow(rd, -0.0101*rd+3.86267)-5.58416
          a1   = rd < 28.5 ? a1 : -6.28157*rd+96.4469
          c1   = -0.00628214*(rd*rd)+0.126164*rd-1.43351
          c1   = rd < 15   ? c1 : rd > 54 ? -1.8 : 3.85836*cos(0.0178972*rd+2.2192)+2.09942
          rad  = a1*pow(w0/100.,c1)+rd"

    pn = "a1   = rd > 60 ? 1 : max(0,-0.0153452*rd*rd+1.94884*rd-60.6877)
          b1   = rd < 55 ? a1==0 ? 1 : 0 : 0.04/(1.90291-1500*pow(rd,-1.66497))-9.67535
          c1   = 0.000117449*rd*rd+1.02309*rd-1.00184
          rad  = (1/(a1*w0/100.+b1)) + c1"

    str = pad ? py : pn
    Eval(str)
    Eval(ReplaceStr(str, "rd", "rv").ReplaceStr("w0", "h0").ReplaceStr("rad", "radv"))

    p   = pad ? 64 : 0      p2  = p*2

    w1  = Min(nmod(w0/rad, 2), w0)
    h1  = Min(nmod(h0/radv,2), h0)

    full= isy || a.is444() || rgb
    UV3 = UV==3
    sm  = (w1 < 16 || h1 < 16)
    smc = !isy && (!full || sm && !UV3)
    ay  = smc ? a.ExtractY() : a
    au  = smc ? a.ExtractU() : a
    av  = smc ? a.ExtractV() : a

    w2  = smc ? au.Width ()  : w0
    h2  = smc ? au.Height()  : h0


    if (rad<0.01 && radv<0.01) {

        a

    } else if (!full && sm && UV==3                         || \
              ( rd < 2.00 && rv < 2.00 && mb)               || \
              (!pad &&  w0 <= 1099 && (w1 < 24 || h1 < 24)) || \
                pad && (w0 <= 480 || h0 <= 480) ) {

        vsTCanny(a,rd,sigma_vY=rv,mode=-1,y=y,u=uv,v=uv)

    } else if (full && UV==3 || isy) {

        B  = max(rd, rv) > 19.3 ? a.BicubicResize (w1, h1, src_left=-p, src_top=-p, src_width=w0+p2, src_height=h0+p2) : \
                                  a.BilinearResize(w1, h1, src_left=-p, src_top=-p, src_width=w0+p2, src_height=h0+p2) # extend borders before resizing

        B.GaussResize(w0+p2, h0+p2, p=9)
        pad ? crop (p, p, -p, -p) : last

    } else {

        Assert(!rgb, "ex_GaussianBlur: RGB requires UV=3!")

        B  =       max(rd, rv) > 19.3 ? ay.BicubicResize (w1, h1, src_left=-p, src_top=-p, src_width=w0+p2, src_height=h0+p2) : \
                                        ay.BilinearResize(w1, h1, src_left=-p, src_top=-p, src_width=w0+p2, src_height=h0+p2)
        Bu = !sm ? max(rd, rv) > 19.3 ? au.BicubicResize (w1, h1, src_left=-p, src_top=-p, src_width=w2+p2, src_height=h2+p2) : \
                                        au.BilinearResize(w1, h1, src_left=-p, src_top=-p, src_width=w2+p2, src_height=h2+p2) : nop() # sm (>117 high radii) only possible for UV!=3
        Bv = !sm ? max(rd, rv) > 19.3 ? av.BicubicResize (w1, h1, src_left=-p, src_top=-p, src_width=w2+p2, src_height=h2+p2) : \
                                        av.BilinearResize(w1, h1, src_left=-p, src_top=-p, src_width=w2+p2, src_height=h2+p2) : nop()

                   B. GaussResize(w0+p2, h0+p2, p=9)
        Bu = !sm ? Bu.GaussResize(w2+p2, h2+p2, p=9) : nop()
        Bv = !sm ? Bv.GaussResize(w2+p2, h2+p2, p=9) : nop()
        Bu = !sm ? pad ? Bu.crop (p, p, -p, -p) : Bu : nop()
        Bv = !sm ? pad ? Bv.crop (p, p, -p, -p) : Bv : nop()
                   pad ?    crop (p, p, -p, -p) : last

        Y  == 3 && UV < 3 ? mergeluma(a,last) : \
        Y  == 3 && UV ==3 ? YtoUV(Bu,Bv,last) : \
        UV == 3 && Y  < 3 ? YtoUV(Bu,Bv,  ay) : \
        Y  != 3 && UV !=3 ?                a  : UV>6 ? mskY_to_YYY(a, last, true, rgb, UV, bi) : last
        propCopy(a,true,props="_ChromaLocation") } }



# Replace Low Frequency of first clip from the second clip
# In other words, add the lowpass of the second clip into the highpass of the first
#
function ex_LFR (clip c, clip ref, float "LFR", bool "DCTFlicker", int "UV") {

    w    = c.width ()
    h    = c.height()
    bi   = BitsPerComponent(c)
    LFR  = Default( LFR, 300*(w/1920.)) # 50 to width(). Frequency cutoff for the replacement. Default 300 for 1080p
    UV   = Default( UV,              1) # Set UV to 4 to copy the chroma from the 'ref' clip
    DCT  = Default( DCTFlicker,  false) # Clean up remaining blotches of the reference lowpass

    mwh  = max(w,h)
    LFR  = clamp(LFR,50,mwh)
    Fs   = mwh * 2                      # Frequency sample rate is resolution * 2 (for Nyquist)
    k    = sqrt(log(2)/2) * LFR         # Constant for -3dB
    LFR  = Fs / ( k * 2 * pi )          # Frequency Cutoff for Gaussian Sigma
    sec  = ex_bs(0.51, 8, bi, fulls=true, flt=true)

    lpc =   c.ex_gaussianblur(LFR, UV=UV==4?2:UV)
    lpr = ref.ex_gaussianblur(LFR, UV=UV==4?2:UV)

    DCT = DCT ? Format("y z == swap dup y z - sgn {sec} * + ?") : "" # "shift-back-by-one": https://forum.doom9.org/showthread.php?p=1539241
    ex_lutxyz(c, lpc, lpr, "x y - z + "+DCT, UV=UV)                  # ex_makeadddiff()

    UV==4 ? MergeChroma(ref) : last }




# Bandpass replacement
# Replace Mid Frequencies of first clip from the second clip
# Requires vsTCanny()
#
# ex_MFR() workflow diagram (shaded '/' means deleted by lowpassing):
#
#          A  -  LOWPASS               HIPASS   +  LOWPASS          BANDSTOP
#     A               A                  A            A                 A
#  _______         _______            _______      _______           _______
# |       |       |/ / / /|          |       |    |/ / / /|         |       |
# |       |       | / / / |          |       |    | / / / |         |       |
# |       |       |-------|-> HI      -------     |/ / / /|          -------
# |       |       |       |                       | / / / |
# |       |   -   |       |     =               + |/ / / /|     =
# |       |       |       |                       |-------|-> LO     _______
# |       |       |       |                       |       |         |       |
# |       |       |       |                       |       |         |       |
#  -------         -------                         -------           -------
#
#    LOWPASS  -  LOWPASS             BANDPASS               A
#     B               B                  B                 /           A+B
#  _______         _______                                /          _______
# |/ / / /|       |/ / / /|                              /\ +       |       |
# | / / / |       | / / / |                             /  \        |   A   |
# |-------|-> HI  |/ / / /|           _______          /    \       |-------|
# |       |       | / / / |          |       |        B      -----> |       |
# |       |   -   |/ / / /|     =    |       |                      |   B   |
# |       |       |-------|-> LO      -------                       |-------|
# |       |       |       |                                         |       |
# |       |       |       |                                         |   A   |
#  -------         -------                                           -------
#
# Example:
#     ex_MFR(a,b,700,1700) # Replace mid frequencies from 700 to 1700 of 'a' clip from 'b'
#
#
# Function Definition:
#    (
#    clip a,
#    clip b,
#    float "lo"=900.0 (100.0 to 1900.0),
#    float "hi"=1800.0 (100.0 to 1900.0)
#    )
#
function ex_MFR (clip c, clip ref, float "lo", float "hi", int "UV") {

    rgb  = isRGB (c)
    w    = width (c)
    h    = height(c)
    bi   = BitsPerComponent(c)
    fulls= propNumElements (c,"_ColorRange")  > 0 ? \
           propGetInt      (c,"_ColorRange") == 0 : rgb

    HI   = Default( HI, 1800*(w/1920.)) # Hi  frequency bound. Default is 1800 for 1080p
    LO   = Default( LO,         HI/2. ) # Low frequency bound.
    UV   = Default( UV,              3) # Set UV to 4 to copy the chroma from the 'ref' clip
    UV2  = UV==4?2:UV

    mwh  = max(w,h)
    LO   = max(LO, 4)
    HI   = min(HI, mwh)

    Fs   = mwh * 2                      # Frequency sample rate is resolution * 2 (for Nyquist)
    k    = sqrt(log(2)/2) * HI          # Constant for -3dB
    HI   = Fs / ( k * 2 * pi )          # Frequency Cutoff for Gaussian Sigma

    k    = sqrt(log(2)/2) * LO
    LO   = Fs / ( k * 2 * pi )

  # The perfect lowpass filter is a brick-wall filter like a 'mean' blur
  # We could use this instead for high frequency lowpass albeit much slower
  # mpc   =   c.ex_blur(HI+0.5, mode="butterworth",n=300,UV=UV2)
  # mpr   = ref.ex_blur(HI+0.5, mode="butterworth",n=300,UV=UV2)

    # vsTCanny() shows slightly better performance than ex_gaussianblur() when called multiple times (at mid sigmas only)
    mpc   =   c.vsTCanny(HI, mode=-1, u=UV2, v=UV2)
    mpc2  =   c.vsTCanny(LO, mode=-1, u=UV2, v=UV2)
    mpr   = ref.vsTCanny(HI, mode=-1, u=UV2, v=UV2)
    mpr2  = ref.vsTCanny(LO, mode=-1, u=UV2, v=UV2)

    Expr(c, mpc, mpc2, mpr, mpr2, "x y - z + a b - +", isy(c) ? Undefined() : ex_UVexpr("x y - z + a b - +", UV2, bi, rgb, fulls, "none") ) }




# ex_FluxSmoothT - fluctuating smooth (Nifty Temporal Mean/Median combination -temporal version of MinBlur-)
#
# Soft thresholded minimal change of temporal average + temporal median
# Based on Didée's concept: https://forum.doom9.org/showthread.php?p=1471858
# 6% faster than FluxSmoothT() (AVX2), also allows higer temporal radii
#
function ex_FluxSmoothT(clip a, int "rad", int "th", bool "LFR", bool "DCTFlicker", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    rd  = Default( rad,  1)                                   # radius can be 1, 2 or 3 (original FluxSMoothT only does rad=1)
    th  = Default( th,   1)                                   # Soft threshold 0-255 (Default: 1 to respond similar to original "Default=7")
    UV  = Default( UV, rgb ? 3 : 1)
    LFR = Default( LFR, false)                                # Enable LFR to recover low frequency detail ('smearing')
    LFR = LFR ? 300*(width(a)/1920.) : 0                      # Default 300 for 1080p
    DCT = Default( DCTFlicker,  false)                        # Clean up remaining blotches of the reference lowpass
    si  = ex_UVf(rgb, bi)

    Assert (rd < 4, "ex_FluxSmoothT: radii > 3 is not supported")

    # Soft threshold
    bias =        min(2*cos(pi+2*pi*th/255.)+2,1)*10           # Minimize soft threshold spread on extremes
    thr1 = ex_bs( max(th-10 - rd * bias,   0), 8, bi, fulls=true, flt=true)
    thr2 = ex_bs( min(th+10 + rd * bias, 255), 8, bi, fulls=true, flt=true)
    mx   = ex_bs( 255,                         8, bi, fulls=true)
    thrd = mx / (thr2 - thr1)
    mx   = bi  > 14  ? "range_max /" : string(1. / Eval(ex_dlut("range_max", bi, true))) + " *"
    ths  = th != 255 ? Format("x swap - dup abs {thr1} - {thrd} * range_max swap - 0 range_max clip "+mx+" * x swap -") : ""

    a
    rd   = 2 * rd + 1
    b3   = rd > 5 ? selectevery(1,-3) : nop()
    b2   = rd > 3 ? selectevery(1,-2) : nop()
    b    =          selectevery(1,-1)
    f    =          selectevery(1,+1)
    f2   = rd > 3 ? selectevery(1,+2) : nop()
    f3   = rd > 5 ? selectevery(1,+3) : nop()

    FL = rd == 3 ? "y z dup1 dup1 min swap2 max swap1 x max min A@ x swap - M^
                    x dup y z + + 0.333333333 * "+ths+"         B@        - S@
                        M * 0 < x M abs S abs < A B ? ?"                    : \
                                                                              \
         rd == 5 ? "x y                   dup1 dup1 min swap2 max
                    z a                   dup1 dup1 min swap2 max
                    swap3  b              dup1 dup1 min swap2 max
                    swap2  swap1  swap3   dup1 dup1 min swap2 max
                    swap3                                     max
                    swap3                 dup1 dup1 min swap2 max
                    swap3                                     max
                    swap2                           min
                                                    min A@ x swap   - M^
                    x dup y z a b         + + + + 0.20 * "+ths+" B@ - S@
                        M * 0 < x M abs S abs < A B ? ?"                    : \
                                                                              \
         rd == 7 ? "x y                   dup1 dup1 min swap2 max
                    z a                   dup1 dup1 min swap2 max
                    b c                   dup1 dup1 min swap2 max
                    swap5  swap1  swap3   dup1 dup1 min swap2 max
                    swap3  d              dup1 dup1 min swap2 max
                    swap3  swap1  swap5   dup1 dup1 min swap2 max
                    swap2  swap1  swap5                       max
                    swap3  swap1  swap5   dup1 dup1 min swap2 max
                    swap4  swap1  swap2   dup1 dup1 min swap2 max
                    swap3  swap1  swap2                       max
                    swap2  swap1  swap4             min
                    swap3                                     max
                    swap2                           min
                                                    min A@ x swap          - M^
                    x dup y z a b c d + + + + + + 0.142857143 * "+ths+" B@ - S@
                        M * 0 < x M abs S abs < A B ? ?" : ""


    str   = ex_dlut( FL, bi, true)
    clips = rd == 7 ? "b3,b2,b,f,f2,f3" : rd == 5 ? "b2,b,f,f2" : "b,f"

    rd == 0 ?              a                                                                                            : \
    isy     ? Eval("""Expr(a, """+clips+""", str                                                                  )""") : \
    UV == 1 ? Eval("""Expr(a, """+clips+""", str, ""                                                              )""") : \
              Eval("""Expr(a, """+clips+""", str, ex_UVexpr(FL, UV, bi, rgb, !(UV!=3 && !fs), si), scale_inputs=si)""")

    LFR > 0 ? ex_lfr(a,LFR,DCT) : last }



# ex_FluxSmoothST - fluctuating smooth (Nifty Spatio-Temporal Mean/Median combination)
#
# Requires SMDegrain (and RGTools) for ex_MinBlur()
#
# Works good as a prefilter when sharp=false.
# radius can go up to 3 for temporal and spatial (slow in high spatial though)
#
# Function Definition:
#    (
#    clip,
#    int rad=1 (0 to 3),
#    int radT=1 (0 to 3),
#    int "th"=7 (0 to 255),
#    int "Tth"=0 (0 to 255),
#    bool "sharp"=true
#    )
#
function ex_FluxSmoothST(clip a, int "rad", int "radT", int "th", int "Tth", bool "sharp", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd  = Default(rad,    1)           # radius can be 1, 2 or 3
    rt  = Default(radT,  rd)           # radius can be 1, 2 or 3 (original FluxSmoothT only does rad=1)
    sth = Default( th,    7)           # Spatial  Hard threshold
    tth = Default(Tth,    0)           # Temporal Soft threshold (I don't recommend going higher than 0, except if passed through a motion mask)
    UV  = Default(UV,    rgb ? 3 : 1)
    sh  = Default(sharp, true)         # Disable to use output as a prefilter

    rd = min(rd,3)
    rt = min(rt,3)

    a
    rd > 0 ? ex_MinBlur    (rd,UV,"median",sh,sth) : last
    rt > 0 ? ex_FluxSmoothT(rt,tth,true,UV=UV)     : last }



# Spatio-Temporal Thresholded Weighted Median (STPresso() inspired / not a port)
# Spatial  3x3
# Temporal 1x5
#
# Function Definition:
#    (
#    clip,
#    int "sw"=24 (0 to 100),
#    int "tw"=49 (0 to 100),
#    int "aw"=1 (0 to 100),
#    int "sthres"=5 (0 to 255),
#    int "tthres"=5 (0 to 255 by 1)
#    )
#
function STTWM(clip a, int "sw", int "tw", int "aw", int "sthres", int "tthres", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    sw  = Default(sw,     24)          # 0 - 100% Spatial  Weight
    tw  = Default(tw,     49)          # 0 - 100% Temporal Weight
    aw  = Default(aw,      1)          # 0 - 100% Absolute Weight
    ths = Default(sthres,  5)          # 0 - 255  Spatial  threshold
    tht = Default(tthres,  5)          # 0 - 255  Temporal threshold
    UV  = Default(UV,    rgb ? 3 : 1)
    un  = Undefined()

    ths = ex_bs( ths , 8, bi, fulls=true)
    tht = ex_bs( tht , 8, bi, fulls=true)

    ws  = (float(sw)/(sw+tw))
    wt  = (float(tw)/(sw+tw))
    wa  = aw/100.
    wr  = 1 - wa

    Assert(IsVersionOrGreater(3,7,2), "STTWM: Update AviSynth+ version")

    str =  Format(                                         \
           "x[-1,1]  x[1,1]       dup1 dup1 min K^ max P^
            x[-1,-1] x[1,-1]      dup1 dup1 min L^ max O^
            x[0,1]   dup                        D^     N^
            x[-1,0]  dup                        C^     M^
            x[0,-1]  dup                        I^     J^
            x[1,0]   dup                        G^     H^
            x[0,0]   dup dup dup                A^     F^
                                                B^     E^
            N P                   dup1 dup1 min N^ max P^
            F O                   dup1 dup1 min F^ max O^
            J M                   dup1 dup1 min J^ max M^
            I L                   dup1 dup1 min I^ max L^
            B K                   dup1 dup1 min B^ max K^
            E H                   dup1 dup1 min E^ max H^
            D G                   dup1 dup1 min D^ max G^
            A C                   dup1 dup1 min A^ max C^
            H P                   dup1 dup1 min H^ max P^
            M O                   dup1 dup1 min M^ max O^
            E N                   dup1 dup1 min E^ max N^
            C L                   dup1 dup1 min C^ max L^
            G K                   dup1 dup1 min G^ max K^
            F J                   dup1 dup1 min F^ max J^
            A I                   dup1 dup1 min A^ max I^
            B D                   dup1 dup1 min B^ max D^
            O P                             min O^
            L N                   dup1 dup1 min L^ max N^
            H M                   dup1 dup1 min H^ max M^
            J K                   dup1 dup1 min J^ max K^
            D I                   dup1 dup1 min D^ max I^
            F G                   dup1 dup1 min F^ max G^
            C E                   dup1 dup1 min C^ max E^
            A B                                    max B^
            M O                             min M^
            K N                             min K^
            H L                   dup1 dup1 min H^ max L^
            G J                   dup1 dup1 min G^ max J^
            E I                   dup1 dup1 min E^ max I^
            C F                                    max F^
            B D                                    max D^
            K M                             min K^
            E L                   dup1 dup1 min E^ max L^
            H J                   dup1 dup1 min H^ max J^
            G I                   dup1 dup1 min G^ max I^
            D F                                    max F^
            E F max G H max max I J min K L min min dup1 dup1 max swap2 min

            x swap2 clip S@

                     dup dup dup
            a dup
            z dup
            y b                   dup1 dup1 min swap2 max
            swap4  swap1  swap8   dup1 dup1 min swap2 max
            swap4  swap1  swap6   dup1 dup1 min swap2 max
            swap9  swap1  swap3   dup1 dup1 min swap2 max
            swap7  swap1  swap5   dup1 dup1 min swap2 max
            swap2  swap1  swap4   dup1 dup1 min swap2 max
            swap3  swap1  swap6   dup1 dup1 min swap2 max
            swap2  swap1  swap7   dup1 dup1 min swap2 max
            swap4  swap1  swap8   dup1 dup1 min swap2 max
            swap9  swap1  swap3             min
            swap8  swap1  swap5   dup1 dup1 min swap2 max
            swap2  swap1  swap4                       max
            swap2  swap1  swap7   dup1 dup1 min swap2 max
            swap7  swap1  swap4   dup1 dup1 min swap2 max
            swap2  swap1  swap5   dup1 dup1 min swap2 max
            swap6  swap1  swap3   dup1 dup1 min swap2 max
            swap2  swap1  swap7             min
            swap3  swap1  swap4   dup1 dup1 min swap2 max
            swap4  swap1  swap5   dup1 dup1 min swap2 max
            swap2  swap1  swap6                       max
            swap3  swap1  swap2             min
            swap3                 dup1 dup1 min swap2 max
            swap2  swap1  swap4                       max
            swap2                           min
            swap2                                     max

            x swap2 clip T@
              x - abs {tht} > x T ? {wt} *
            S x - abs {ths} > x S ? {ws} * + {wa} * x {wr} * + ")

        b2 = a.selectevery(1,-2)
        b  = a.selectevery(1,-1)
        f  = a.selectevery(1,+1)
        f2 = a.selectevery(1,+2)

        isy     ? Expr(a, b2, b, f, f2, str,                                  optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, b2, b, f, f2, str, "",                              optSingleMode = false                     ) : \
                  Expr(a, b2, b, f, f2, str, ex_UVexpr(str, UV, bi, rgb, un), optSingleMode = false, scale_inputs="none") }






##############################
##
## Median Blur
##
## Replaces removegrain medians, adaptivemedian, verticalcleaner, clense, degrainmedian, medianblur, medianblurtemporal, DeSaltPepper/SaltPepper and UnDot plugins, and adds new modes.
## Sorting Networks perform better with Prefetch(logical_cores*0.75) in multi-threaded CPUs.
##
##
##  100% removegrain(1,-1)
##   91% ex_median(mode="undot",UV=1) # same as DeSaltPepper or SaltPepper from manyplus, or UnDot by Tom Barry.
##
##  100% removegrain(2,-1)
##   75% ex_median(mode="undot2",UV=1)
##
##  100% removegrain(4,-1)   (480fps)
##   78% ex_median(mode="median",UV=1)  # same as "undot4"
##   60% Dither_median16(rx=1, ry=1, rt=0, y=3, u=1, v=1)
##    8% Morph(opt = "median")
##  1.2% MedianBlur(1,0,0)
## 0.06% mt_luts(last, "med", mt_square(1), "y",chroma="-1")
##
##  100% quantile(rank=13,radius_u=0,radius_v=0) (155fps) # (only 8-bits)
##   84% removegrainHD(rank=13,radius_u=0,radius_v=0)     # (only 8-bits)
##   72% ex_median(mode="median5",UV=1)
##   10% Dither_median16(rx=2, ry=2, rt=0, y=3, u=1, v=1)
##  3.3% MedianBlur(2,0,0) # 5fps with or without chroma (unstable filter)
##
##  100% Clense(grey=true)  (437fps)
##   98% neo_tmedian(radius=1,u=1,v=1)
##   91% ex_median(mode="medianT",UV=1)
##   91% MedianBlurTemporal(0,0,0)
##
##  100% ex_median(mode="medianST",UV=1) (93fps)
##   81% MedianBlurTemporal(1,1,1) # 2fps without chroma (unstable filter)
##
## Recommended: EMF, smart1/2/3, IQM/5/V/T/ST, CAM, edgeCL, cartoon, DGM1, ML3D and STWM
#
# 64 modes (with '*' own algos):
# undot(1)   - Also called "conservative", removes 1 pixel "salt'n'pepper" impulsive noise            -removegrain(1)-
# undot2     - Same as undot but clip up to the second closest minimum values. Prune 1x2 pixels       -removegrain(2)-
# undot3     - Same as undot but clip up to the third  closest minimum values. Prune 3 pixel clusters -removegrain(3)-
# undot4     - Same as undot but clip up to the fourth closest minimum values. Prune 2x2 pixels       -removegrain(4)- *Same as 'median'
# undot6     - Median of 2x3 -upper and lower rows- (akin vsDegrainMedian(norows=true). Useful for 'ghosting' like artifacts after deblending field blends. Port from @Colours' source: https://gist.github.com/torchlight/5b5df916c5a7a7b00204
#*unblob3    - Same as undot3 but over a 5x5   kernel matrix.                                                          *Maybe suited for HD/UHD sources
#*unblob3D   - Same as undot3 but over a 3x3x3 kernel matrix.                      (Spatio-Temporal, Motion Protected) *Similar output to 'unblob3'
# median     - True median. Replace with kernel middle value (3x3 kernel)                             -removegrain(4)- *Same as 'undot4'
# median5    - True median. Replace with kernel middle value (5x5 kernel)
# median7    - True median. Replace with kernel middle value (7x7 kernel)  (580 CE for BB and CC)
#*median7o   - Circle kernel median of radius 3 (7x7)
#*smart      - Smart Median Filter. Threshold against variance. Similar in concept to ex_smartblur() and somewhat to MinVar() (old DeNoise plugin)
#*smart2     - Smart Median Filter. Same as above but radius 2.
#*smart3     - Smart Median Filter. Same as above but radius 3.
# midsum     - Midsummary. Computes the mean average of the 1st and 3rd terciles. Fast but not as good as Winsor or Trimean below.
# Winsor     - 11% winsorized mean. Robust estimator similar to a weighted trimmed mean                                *Same as ex_boxblur(1, mode="mean") but better edge protection
# Winsor5    - 10% winsorized mean for a 5x5 kernel window.                                                            *Same as ex_boxblur(2, mode="mean") but better edge protection
# Trimean    - High estimation efficiency (88%) three point mean average of 20th, 50th and 80th percentiles.           *Same as                 'Winsor'   but better edge protection. Similar to ex_sbr(2) but faster.
# Trimean5   - Same as Trimean but with a 5x5 kernel window.                                                           *Same as                 'Winsor5'  but better edge protection
# IQM        - Interquartile mean or midmean for a 3x3 kernel. Discards outliers before the mean average.              *Same as                 'Trimean'  but better edge protection
# IQM5       - Interquartile mean or midmean for a 5x5 kernel.                                                         *Same as                 'Trimean5' but better edge protection
#*IQMV       - Switches between IQM and IQM5 depending on a difference threshold for better edge protection.           *Similar to ex_MinBlur(3) in output but near 3 times faster.
# IQMT       - Interquartile mean or midmean of 5 frames.                          (Temporal)                          *Similar to temporal average but more motion protection, albeit less than ex_FluxSmoothT(th=255)
#*IQMST      - Spatio-temporal IQM. Mix between IQM + IQMT taking the best of both.(Spatio-Temporal, Mostly Motion Protected)
# EMF        - Extended Median Filter. 3x3 kernel median thresholded against center pixel
# CWM        - Center Weighted Median
# CWM2       - Center -stronger- Weighted Median. Similar output to edgeCL but a bit slower
# WMF        - Gauss Weighted Median
#*AWM        - Mean Average Weighted Median
#*PWM        - 50% weighted Percentile Weighted Median
# RMF        - Recursive Median Filter. Computes the new median from previous pixel medians. *Proof of concept, actually runs faster with 2 passes of "median"
# AMF        - Adaptive Median. Similar to undot but better at salt'n'pepper noise.                 -From VC Mohan AdaptiveMedian-
#*CAM        - Cross kernel Adaptive Median
# SNN        - Symmetric Nearest Neighbour Mean. Average of 4 closest pixels in opposing pairs.
# kuwahara   - Nagao Kuwahara. (Simplified) Mean average of the least variance quadrant in a 5x5 kernel window. (oil paint look/filter)
# edgeW      - Edge sensitive. Line pairs are used.                                    Weak denoise -removegrain(18)-
# edgeS      - Edge sensitive. Same as 'median' but better edge   protection.        Strong denoise -removegrain(17)-
# edgeC      - Edge sensitive. Same as 'edgeS'  but better corner protection.        Strong denoise -removegrain(26)-
# edgeCL     - Edge sensitive. Same as 'edgeC'  but better line   protection.        Strong denoise -removegrain(27)-
# cartoon    - Clipping is done with respect to averages of neighbours.           Best for cartoons -removegrain(22)-
# vertical   - Vertical median. Port of VerticalCleaner mode=1
# verticalS  - Vertical median. Port of VerticalCleaner mode=2 (edge sensitive)
# horizontal - Horizontal median. Horizontal version of 'vertical'
# horizontalS- Horizontal median. Horizontal version of 'verticalS'
# GaussT5    - Temporal Gauss Blur of 5 frames                                     (Temporal)
#*GaussST5   - 5x5x5 Cubic Spatio-Temporal Gauss Blur                              (Spatio-Temporal) ( sameish to but x4 slower than ex_blur3D(1,mode="weighted") )
# medianT    - Temporal median of 3 frames                                         (Temporal) (like Clense())
# medianT5   - Temporal median of 5 frames                                         (Temporal)
# medianST   - 3x3x3 Cubic Spatio-Temporal                                         (Spatio-Temporal)
#*medianSTS  - 1x3x5x3x1 Quasi-Spherical Spatio-Temporal                           (Spatio-Temporal, Semi Motion Protected)
# SixNN      - 1x3x1 Six Nearest-Neighbours                                        (Spatio-Temporal, Motion Protected)
#*STWM       - 1x2xWMFx2x1 Spatio-Temporal Gaussian Weighted Median                (Spatio-Temporal, Motion Protected)
# PML/P3D    - Planar Multi-Level Median Filter                                    (Spatio-Temporal, Motion Protected)
# TL3D       - Two-Level Median Filter                                             (Spatio-Temporal)
# ML3D       - Multi-Level Median Filter                                           (Spatio-Temporal, Motion Protected)
# ML3Dex     - Extended Multi-Level Median Filter                                  (Spatio-Temporal)
# Hybrid     - 3D Hybrid Median Filter. Like ML3Dex but a bit softer               (Spatio-Temporal)
# BDM        - Arce Bi-directional Multi-Level Median Filter                       (Spatio-Temporal, Motion Protected)
# MMF        - Multistage Median Filter                                            (Spatio-Temporal, Motion Protected) (like a 3D undot)
# DGM0       - Mode=0 of DeGrainMedian (similar    to spatial only RemoveGrain(9)) (Spatio-Temporal, Motion Protected) (based itself on STMedianFilter)
# DGM1       - Mode=1 of DeGrainMedian (stronger than spatial only RemoveGrain(8)) (Spatio-Temporal, Motion Protected) (Default in DGM)
# DGM2       - Mode=2 of DeGrainMedian (similar    to spatial only RemoveGrain(8)) (Spatio-Temporal, Motion Protected)
# DGM3       - Mode=3 of DeGrainMedian (similar    to spatial only RemoveGrain(7)) (Spatio-Temporal, Motion Protected)
# DGM4       - Mode=4 of DeGrainMedian (similar    to spatial only RemoveGrain(6)) (Spatio-Temporal, Motion Protected)
# DGM5       - Mode=5 of DeGrainMedian (similar    to spatial only RemoveGrain(5)) (Spatio-Temporal, Motion Protected)
#
# SNN (Symmetric Nearest Neighbour Median) is not implemented due to low edge integrity protection. -removegrain(9)-
# *SmartMedian and SmartMedian2 from RemoveGrainHD are not included. With radius=1 output is blotchy and jagged lines, with radius=2 it's like strong undot, it protects lines to some degree
#
#
# Function Definition:
#    (
#    clip,
#    string "mode"="median" ("undot"/ "undot2"/ "undot3"/ "undot4"/ "undot6"/ "unblob3"/ "unblob3D"/ "--"/ "median"/ "median5"/ "median7"/ "median7o"/ "--"/ "smart"/ "smart2"/ "smart3"/ "--"/ "midsum"/ "Winsor"/ "Winsor5"/ "Trimean"/ "Trimean5"/ "IQM"/ "IQM5"/ "IQMV"/ "--"/ "EMF"/ "CWM"/ "CWM2"/ "WMF"/ "AWM"/ "PWM"/ "RMF"/ "AMF"/ "CAM"/ "SNN"/ "kuwahara"/ "--"/ "edgeW"/ "edgeS"/ "edgeC"/ "edgeCL"/ "cartoon"/ "--"/ "vertical"/ "verticalS"/ "horizontal"/ "horizontalS"/ "--"/ "GaussT5"/ "GaussST5"/ "IQMT"/ "IQMST"/ "medianT"/ "medianT5"/ "medianST"/ "medianSTS"/ "SixNN"/ "STWM"/ "PML"/ "TL3D"/ "ML3D"/ "ML3Dex"/ "Hybrid"/ "BDM"/ "MMF"/ "--"/ "DGM0"/ "DGM1"/ "DGM2"/ "DGM3"/ "DGM4"/ "DGM5"),
#    float "thres"=255.0 (0.0 to 255.0 by 1),
#    bool "recursion"=false
#    )

function ex_median(clip a, string "mode", float "thres", bool "recursion", int "Y", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    mode = Default(mode,        "median")
    mode = ReplaceStr(UCase(mode)," ","")
    rc   = Default(recursion,      false)                       # Use recursion for temporal modes. Performance penalty for little improvement though
    Y    = Default( Y,          3)
    UV   = Default(UV,    rgb ? 3 : 1)
    smart= FindStr(mode,"SMART")>0
    DGM  = FindStr(mode,"DGM"  )>0
    thr  = Default(thres, mode=="EMF"           ?   9 : \
                          mode=="smart"         ?  50 : \
                          mode=="smart1"        ?  50 : \
                          mode=="smart2"        ? 128 : \
                          mode=="smart3"        ? 128 : \
                          mode=="SNN"           ?  20 : \
                          mode=="IQMST"         ?  20 : \
                          DGM                   ?   4 : 255)    # Absolute Error threshold. For all modes

    th =        ex_bs(thr, 8, bi, fulls=true, flt=true)
    ti = string(ex_bs(5,   8, bi, fulls=true, flt=true))        # Threshold for IQMV


    # Soft threshold
    bias =        min(2*cos(pi+2*pi*thr/255.)+2,1)*20           # Minimize soft threshold spread on extremes
    thr1 = ex_bs( max(thr-10 - bias,   0), 8, bi, fulls=true, flt=true)
    thr2 = ex_bs( min(thr+10 + bias, 255), 8, bi, fulls=true, flt=true)
    mx   = ex_bs( 255,                     8, bi, fulls=true)
    thrd = mx / (thr2 - thr1)
    mx   = bi > 14 ? "range_max /" : string(1. / Eval(ex_dlut("range_max", bi, true))) + " *"
    ths = mode!="EMF" && mode!="SNN" && !smart && !DGM && thr != 255 ?                                      \
          Format(" x swap - dup abs {thr1} - {thrd} * range_max swap - 0 range_max clip "+mx+" * x swap -") : ""

    Assert(IsVersionOrGreater(3,7,2), "ex_median: Update AviSynth+ version")

    str =                                                                                                                                                                       \
        mode == "--"     ? "x"                                                                                                                                                : \
                                                                                                                                                                                \
        mode == "median5"? "x[-2,-2] x[-2,-1]     dup1 dup1 min D^ max X^
                            x[-2,0]  x[-2,1]      dup1 dup1 min L^ max W^
                            x[-2,2]  x[-1,-2]     dup1 dup1 min H^ max V^
                            x[-1,-1] x[-1,0]      dup1 dup1 min A^ max U^
                            x[-1,1]  x[-1,2]      dup1 dup1 min R^ max T^
                            x[0,-2]  x[0,-1]      dup1 dup1 min N^ max S^
                            x[0,1]   x[0,2]       dup1 dup1 min C^ max Q^
                            x[1,-2]  x[1,-1]      dup1 dup1 min J^ max P^
                            x[1,0]   x[1,1]       dup1 dup1 min I^ max O^
                            x[1,2]   x[2,-2]      dup1 dup1 min B^ max M^
                            x[2,-1]  x[2,0]       dup1 dup1 min F^ max K^
                            x[2,1]   x[2,2]       dup1 dup1 min E^ max G^
                            U X                   dup1 dup1 min U^ max X^
                            M W                   dup1 dup1 min M^ max W^
                            Q V                   dup1 dup1 min Q^ max V^
                            G T                   dup1 dup1 min G^ max T^
                            K S                   dup1 dup1 min K^ max S^
                            E R                   dup1 dup1 min E^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            B L                   dup1 dup1 min B^ max L^
                            I J                   dup1 dup1 min I^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            A D                   dup1 dup1 min A^ max D^
                            W X                   dup1 dup1 min W^ max X^
                            T V                   dup1 dup1 min T^ max V^
                            L U                   dup1 dup1 min L^ max U^
                            P S                   dup1 dup1 min P^ max S^
                            O R                   dup1 dup1 min O^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            S V                             min S^
                            P T                   dup1 dup1 min P^ max T^
                            M R                   dup1 dup1 min M^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            G L                   dup1 dup1 min G^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            C F                                    max F^
                            P W                   dup1 dup1 min P^ max W^
                            J U                   dup1 dup1 min J^ max U^
                            Q T                   dup1 dup1 min Q^ max T^
                            D O                   dup1 dup1 min D^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            B I                   dup1 dup1 min B^ max I^
                            E H                   dup1 dup1 min E^ max H^
                            Q X                             min Q^
                            S W                   dup1 dup1 min S^ max W^
                            T U                             min T^
                            M R                   dup1 dup1 min M^ max R^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            K N                   dup1 dup1 min K^ max N^
                            G L                   dup1 dup1 min G^ max L^
                            A H                                    max H^
                            B F                   dup1 dup1 min B^ max F^
                            D E                                    max E^
                            R W                             min R^
                            Q T                   dup1 dup1 min Q^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            I K                   dup1 dup1 min I^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            S T                   dup1 dup1 min S^ max T^
                            O Q                   dup1 dup1 min O^ max Q^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            E F                   dup1 dup1 min E^ max F^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            P R min Q min O min N T min S min L       min min
                            B G max I max H max J max E K max F max M max max
                                                  dup1 dup1 max swap2 min
                            x swap2 clip"+ths                                                                                                                                 : \
                                                                                                                                                                                \
        mode == "median7"? "x[-3,-3] x[-2,-3]       dup1 dup1 min D^ max Z^
                            x[-1,-3] x[0,-3]        dup1 dup1 min L^ max W^
                            x[1,-3]  x[2,-3]        dup1 dup1 min H^ max V^
                            x[3,-3]  x[-3,-2]       dup1 dup1 min A^ max U^
                            x[-2,-2] x[-1,-2]       dup1 dup1 min R^ max T^
                            x[0,-2]  x[1,-2]        dup1 dup1 min N^ max S^
                            x[2,-2]  x[3,-2]        dup1 dup1 min C^ max Q^
                            x[-3,-1] x[-2,-1]       dup1 dup1 min J^ max P^
                            x[-1,-1] x[0,-1]        dup1 dup1 min I^ max O^
                            x[1,-1]  x[2,-1]        dup1 dup1 min B^ max M^
                            x[3,-1]  x[-3,0]        dup1 dup1 min F^ max K^
                            x[-2,0]  x[-1,0]        dup1 dup1 min E^ max G^
                            x[1,0]  x[2,0]          dup1 dup1 min DD^ max YY^
                            x[3,0]  x[-3,1]         dup1 dup1 min LL^ max WW^
                            x[-2,1] x[-1,1]         dup1 dup1 min HH^ max VV^
                            x[0,1]  x[1,1]          dup1 dup1 min AA^ max UU^
                            x[2,1]  x[3,1]          dup1 dup1 min RR^ max TT^
                            x[-3,2] x[-2,2]         dup1 dup1 min NN^ max SS^
                            x[-1,2] x[0,2]          dup1 dup1 min CC^ max QQ^
                            x[1,2]  x[2,2]          dup1 dup1 min JJ^ max PP^
                            x[3,2]  x[-3,3]         dup1 dup1 min II^ max OO^
                            x[-2,3] x[-1,3]         dup1 dup1 min BB^ max MM^
                            x[0,3]  x[1,3]          dup1 dup1 min FF^ max KK^
                            x[2,3]  x[3,3]          dup1 dup1 min EE^ max GG^
                            U Z                     dup1 dup1 min U^ max Z^
                            M W                     dup1 dup1 min M^ max W^
                            Q V                     dup1 dup1 min Q^ max V^
                            G T                     dup1 dup1 min G^ max T^
                            K S                     dup1 dup1 min K^ max S^
                            E R                     dup1 dup1 min E^ max R^
                            O P                     dup1 dup1 min O^ max P^
                            F N                     dup1 dup1 min F^ max N^
                            B L                     dup1 dup1 min B^ max L^
                            I J                     dup1 dup1 min I^ max J^
                            C H                     dup1 dup1 min C^ max H^
                            A D                     dup1 dup1 min A^ max D^
                            UU YY                   dup1 dup1 min UU^ max YY^
                            MM WW                   dup1 dup1 min MM^ max WW^
                            QQ VV                   dup1 dup1 min QQ^ max VV^
                            GG TT                   dup1 dup1 min GG^ max TT^
                            KK SS                   dup1 dup1 min KK^ max SS^
                            EE RR                   dup1 dup1 min EE^ max RR^
                            OO PP                   dup1 dup1 min OO^ max PP^
                            FF NN                   dup1 dup1 min FF^ max NN^
                            BB LL                   dup1 dup1 min BB^ max LL^
                            II JJ                   dup1 dup1 min II^ max JJ^
                            CC HH                   dup1 dup1 min CC^ max HH^
                            AA DD                   dup1 dup1 min AA^ max DD^
                            W Z                     dup1 dup1 min W^ max Z^
                            T V                     dup1 dup1 min T^ max V^
                            L U                     dup1 dup1 min L^ max U^
                            P S                     dup1 dup1 min P^ max S^
                            O R                     dup1 dup1 min O^ max R^
                            N Q                     dup1 dup1 min N^ max Q^
                            D M                     dup1 dup1 min D^ max M^
                            H K                     dup1 dup1 min H^ max K^
                            G J                     dup1 dup1 min G^ max J^
                            F I                     dup1 dup1 min F^ max I^
                            C E                     dup1 dup1 min C^ max E^
                            A B                     dup1 dup1 min A^ max B^
                            WW YY                   dup1 dup1 min WW^ max YY^
                            TT VV                   dup1 dup1 min TT^ max VV^
                            LL UU                   dup1 dup1 min LL^ max UU^
                            PP SS                   dup1 dup1 min PP^ max SS^
                            OO RR                   dup1 dup1 min OO^ max RR^
                            NN QQ                   dup1 dup1 min NN^ max QQ^
                            DD MM                   dup1 dup1 min DD^ max MM^
                            HH KK                   dup1 dup1 min HH^ max KK^
                            GG JJ                   dup1 dup1 min GG^ max JJ^
                            FF II                   dup1 dup1 min FF^ max II^
                            CC EE                   dup1 dup1 min CC^ max EE^
                            AA BB                   dup1 dup1 min AA^ max BB^
                            S V                     dup1 dup1 min S^ max V^
                            P T                     dup1 dup1 min P^ max T^
                            M R                     dup1 dup1 min M^ max R^
                            J Q                     dup1 dup1 min J^ max Q^
                            H O                     dup1 dup1 min H^ max O^
                            G L                     dup1 dup1 min G^ max L^
                            E I                     dup1 dup1 min E^ max I^
                            C F                     dup1 dup1 min C^ max F^
                            P W                     dup1 dup1 min P^ max W^
                            J U                     dup1 dup1 min J^ max U^
                            Q T                     dup1 dup1 min Q^ max T^
                            D O                     dup1 dup1 min D^ max O^
                            SS VV                   dup1 dup1 min SS^ max VV^
                            PP TT                   dup1 dup1 min PP^ max TT^
                            MM RR                   dup1 dup1 min MM^ max RR^
                            JJ QQ                   dup1 dup1 min JJ^ max QQ^
                            HH OO                   dup1 dup1 min HH^ max OO^
                            GG LL                   dup1 dup1 min GG^ max LL^
                            EE II                   dup1 dup1 min EE^ max II^
                            CC FF                   dup1 dup1 min CC^ max FF^
                            PP WW                   dup1 dup1 min PP^ max WW^
                            JJ UU                   dup1 dup1 min JJ^ max UU^
                            QQ TT                   dup1 dup1 min QQ^ max TT^
                            DD OO                   dup1 dup1 min DD^ max OO^
                            L N                     dup1 dup1 min L^ max N^
                            K M                     dup1 dup1 min K^ max M^
                            B I                     dup1 dup1 min B^ max I^
                            E H                     dup1 dup1 min E^ max H^
                            Q Z                     dup1 dup1 min Q^ max Z^
                            S W                     dup1 dup1 min S^ max W^
                            T U                     dup1 dup1 min T^ max U^
                            M R                     dup1 dup1 min M^ max R^
                            I P                     dup1 dup1 min I^ max P^
                            J O                     dup1 dup1 min J^ max O^
                            K N                     dup1 dup1 min K^ max N^
                            G L                     dup1 dup1 min G^ max L^
                            LL NN                   dup1 dup1 min LL^ max NN^
                            KK MM                   dup1 dup1 min KK^ max MM^
                            BB II                   dup1 dup1 min BB^ max II^
                            EE HH                   dup1 dup1 min EE^ max HH^
                            QQ YY                   dup1 dup1 min QQ^ max YY^
                            SS WW                   dup1 dup1 min SS^ max WW^
                            TT UU                   dup1 dup1 min TT^ max UU^
                            MM RR                   dup1 dup1 min MM^ max RR^
                            II PP                   dup1 dup1 min II^ max PP^
                            JJ OO                   dup1 dup1 min JJ^ max OO^
                            KK NN                   dup1 dup1 min KK^ max NN^
                            GG LL                   dup1 dup1 min GG^ max LL^
                            A H                     dup1 dup1 min A^ max H^
                            B F                     dup1 dup1 min B^ max F^
                            D E                     dup1 dup1 min D^ max E^
                            V Z                     dup1 dup1 min V^ max Z^
                            R W                     dup1 dup1 min R^ max W^
                            Q T                     dup1 dup1 min Q^ max T^
                            O S                     dup1 dup1 min O^ max S^
                            N P                     dup1 dup1 min N^ max P^
                            I K                     dup1 dup1 min I^ max K^
                            F J                     dup1 dup1 min F^ max J^
                            E H                     dup1 dup1 min E^ max H^
                            B G                     dup1 dup1 min B^ max G^
                            AA HH                   dup1 dup1 min AA^ max HH^
                            BB FF                   dup1 dup1 min BB^ max FF^
                            DD EE                   dup1 dup1 min DD^ max EE^
                            VV YY                   dup1 dup1 min VV^ max YY^
                            RR WW                   dup1 dup1 min RR^ max WW^
                            QQ TT                   dup1 dup1 min QQ^ max TT^
                            OO SS                   dup1 dup1 min OO^ max SS^
                            NN PP                   dup1 dup1 min NN^ max PP^
                            II KK                   dup1 dup1 min II^ max KK^
                            FF JJ                   dup1 dup1 min FF^ max JJ^
                            EE HH                   dup1 dup1 min EE^ max HH^
                            BB GG                   dup1 dup1 min BB^ max GG^
                            A C                     dup1 dup1 min A^ max C^
                            U V                     dup1 dup1 min U^ max V^
                            S T                     dup1 dup1 min S^ max T^
                            P R                     dup1 dup1 min P^ max R^
                            O Q                     dup1 dup1 min O^ max Q^
                            M N                     dup1 dup1 min M^ max N^
                            K L                     dup1 dup1 min K^ max L^
                            H J                     dup1 dup1 min H^ max J^
                            G I                     dup1 dup1 min G^ max I^
                            E F                     dup1 dup1 min E^ max F^
                            C D                     dup1 dup1 min C^ max D^
                            V W                     dup1 dup1 min V^ max W^
                            AA CC                   dup1 dup1 min AA^ max CC^
                            UU VV                   dup1 dup1 min UU^ max VV^
                            SS TT                   dup1 dup1 min SS^ max TT^
                            PP RR                   dup1 dup1 min PP^ max RR^
                            OO QQ                   dup1 dup1 min OO^ max QQ^
                            MM NN                   dup1 dup1 min MM^ max NN^
                            KK LL                   dup1 dup1 min KK^ max LL^
                            HH JJ                   dup1 dup1 min HH^ max JJ^
                            GG II                   dup1 dup1 min GG^ max II^
                            EE FF                   dup1 dup1 min EE^ max FF^
                            CC DD                   dup1 dup1 min CC^ max DD^
                            VV WW                   dup1 dup1 min VV^ max WW^
                            R U                     dup1 dup1 min R^ max U^
                            N T                     dup1 dup1 min N^ max T^
                            P Q                     dup1 dup1 min P^ max Q^
                            M O                     dup1 dup1 min M^ max O^
                            J L                     dup1 dup1 min J^ max L^
                            E K                     dup1 dup1 min E^ max K^
                            H I                     dup1 dup1 min H^ max I^
                            D G                     dup1 dup1 min D^ max G^
                            B C                     dup1 dup1 min B^ max C^
                            U V                     dup1 dup1 min U^ max V^
                            N S                     dup1 dup1 min N^ max S^
                            Q R                     dup1 dup1 min Q^ max R^
                            RR UU                   dup1 dup1 min RR^ max UU^
                            NN TT                   dup1 dup1 min NN^ max TT^
                            PP QQ                   dup1 dup1 min PP^ max QQ^
                            MM OO                   dup1 dup1 min MM^ max OO^
                            JJ LL                   dup1 dup1 min JJ^ max LL^
                            EE KK                   dup1 dup1 min EE^ max KK^
                            HH II                   dup1 dup1 min HH^ max II^
                            DD GG                   dup1 dup1 min DD^ max GG^
                            BB CC                   dup1 dup1 min BB^ max CC^
                            UU VV                   dup1 dup1 min UU^ max VV^
                            NN SS                   dup1 dup1 min NN^ max SS^
                            QQ RR                   dup1 dup1 min QQ^ max RR^
                            O P                     dup1 dup1 min O^ max P^
                            F K                     dup1 dup1 min F^ max K^
                            I J                     dup1 dup1 min I^ max J^
                            G H                     dup1 dup1 min G^ max H^
                            C D                     dup1 dup1 min C^ max D^
                            T U                     dup1 dup1 min T^ max U^
                            Q S                     dup1 dup1 min Q^ max S^
                            L N                     dup1 dup1 min L^ max N^
                            K M                     dup1 dup1 min K^ max M^
                            F H                     dup1 dup1 min F^ max H^
                            D E                     dup1 dup1 min D^ max E^
                            R T                     dup1 dup1 min R^ max T^
                            OO PP                   dup1 dup1 min OO^ max PP^
                            FF KK                   dup1 dup1 min FF^ max KK^
                            II JJ                   dup1 dup1 min II^ max JJ^
                            GG HH                   dup1 dup1 min GG^ max HH^
                            CC DD                   dup1 dup1 min CC^ max DD^
                            TT UU                   dup1 dup1 min TT^ max UU^
                            QQ SS                   dup1 dup1 min QQ^ max SS^
                            LL NN                   dup1 dup1 min LL^ max NN^
                            KK MM                   dup1 dup1 min KK^ max MM^
                            FF HH                   dup1 dup1 min FF^ max HH^
                            DD EE                   dup1 dup1 min DD^ max EE^
                            RR TT                   dup1 dup1 min RR^ max TT^
                            N P                     dup1 dup1 min N^ max P^
                            L O                     dup1 dup1 min L^ max O^
                            J M                     dup1 dup1 min J^ max M^
                            I K                     dup1 dup1 min I^ max K^
                            E G                     dup1 dup1 min E^ max G^
                            R S                     dup1 dup1 min R^ max S^
                            P Q                     dup1 dup1 min P^ max Q^
                            N O                     dup1 dup1 min N^ max O^
                            L M                     dup1 dup1 min L^ max M^
                            J K                     dup1 dup1 min J^ max K^
                            H I                     dup1 dup1 min H^ max I^
                            F G                     dup1 dup1 min F^ max G^
                            NN PP                   dup1 dup1 min NN^ max PP^
                            LL OO                   dup1 dup1 min LL^ max OO^
                            JJ MM                   dup1 dup1 min JJ^ max MM^
                            II KK                   dup1 dup1 min II^ max KK^
                            EE GG                   dup1 dup1 min EE^ max GG^
                            RR SS                   dup1 dup1 min RR^ max SS^
                            PP QQ                   dup1 dup1 min PP^ max QQ^
                            NN OO                   dup1 dup1 min NN^ max OO^
                            LL MM                   dup1 dup1 min LL^ max MM^
                            JJ KK                   dup1 dup1 min JJ^ max KK^
                            HH II                   dup1 dup1 min HH^ max II^
                            FF GG                   dup1 dup1 min FF^ max GG^
                            A YY                    dup1 dup1 min A^ max YY^
                            B WW                    dup1 dup1 min B^ max WW^
                            C VV                    dup1 dup1 min C^ max VV^
                            D UU                    dup1 dup1 min D^ max UU^
                            E TT                    dup1 dup1 min E^ max TT^
                            F SS                    dup1 dup1 min F^ max SS^
                            G RR                    dup1 dup1 min G^ max RR^
                            H QQ                    dup1 dup1 min H^ max QQ^
                            I PP                    dup1 dup1 min I^ max PP^
                            J OO                    dup1 dup1 min J^ max OO^
                            K NN                    dup1 dup1 min K^ max NN^
                            L MM                    dup1 dup1 min L^ max MM^
                            M LL                    dup1 dup1 min M^ max LL^
                            N KK                    dup1 dup1 min N^ max KK^
                            O JJ                    dup1 dup1 min O^ max JJ^
                            P II                    dup1 dup1 min P^ max II^
                            Q HH                    dup1 dup1 min Q^ max HH^
                            R GG                    dup1 dup1 min R^ max GG^
                            S FF                    dup1 dup1 min S^ max FF^
                            T EE                    dup1 dup1 min T^ max EE^
                            U DD                    dup1 dup1 min U^ max DD^
                            V CC                    dup1 dup1 min V^ max CC^
                            W BB                    dup1 dup1 min W^ max BB^
                            Z AA                    dup1 dup1 min Z^ max AA^
                            HH TT min BB NN min               min BB^
                            II UU min CC OO min               min CC^
                            KK WW min EE QQ min               min EE^
                            LL YY min FF RR min               min FF^
                            A M max G S max                          max S^
                            B N max H T max                          max T^
                            D P max J V max                          max V^
                            E Q max K W max                          max W^
                            C O max I U max                          max
                            F R max L Z max                          max
                                                    dup1 dup1 min U^ max Z^
                            GG SS min AA MM min               min
                            JJ VV min DD PP min               min
                                                    dup1 dup1 min AA^ max DD^
                            CC FF min AA BB min min EE DD min min
                            T W max U S max max V Z max               max

                            x swap2 clip "+ths                                                                                                                                : \
                                                                                                                                                                                \
        mode == "median7o"?"x[-3,0]  x[-2,-2]     dup1 dup1 min AA^ max AB^
                            x[-2,-1] x[-2,0]      dup1 dup1 min Y^ max Z^
                            x[-2,1]  x[-2,2]      dup1 dup1 min W^ max X^
                            x[-1,-2] x[-1,-1]     dup1 dup1 min U^ max V^
                            x[-1,0]  x[-1,1]      dup1 dup1 min S^ max T^
                            x[-1,2]  x[0,-3]      dup1 dup1 min Q^ max R^
                            x[0,-2]  x[0,-1]      dup1 dup1 min O^ max P^
                            x[0,1]   x[0,2]       dup1 dup1 min M^ max N^
                            x[0,3]   x[1,-2]      dup1 dup1 min K^ max L^
                            x[1,-1]  x[1,0]       dup1 dup1 min I^ max J^
                            x[1,1]   x[1,2]       dup1 dup1 min G^ max H^
                            x[2,-2]  x[2,-1]      dup1 dup1 min E^ max F^
                            x[2,0]   x[2,1]       dup1 dup1 min C^ max D^
                            x[2,2]   x[3,0]       dup1 dup1 min A^ max B^
                            B AB                  dup1 dup1 min B^ max AB^
                            A AA                  dup1 dup1 min A^ max AA^
                            D Z                   dup1 dup1 min D^ max Z^
                            C Y                   dup1 dup1 min C^ max Y^
                            F X                   dup1 dup1 min F^ max X^
                            E W                   dup1 dup1 min E^ max W^
                            H V                   dup1 dup1 min H^ max V^
                            G U                   dup1 dup1 min G^ max U^
                            J T                   dup1 dup1 min J^ max T^
                            I S                   dup1 dup1 min I^ max S^
                            L R                   dup1 dup1 min L^ max R^
                            K Q                   dup1 dup1 min K^ max Q^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            V AB                  dup1 dup1 min V^ max AB^
                            H AA                  dup1 dup1 min H^ max AA^
                            X Z                   dup1 dup1 min X^ max Z^
                            W Y                   dup1 dup1 min W^ max Y^
                            B U                   dup1 dup1 min B^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            L O                   dup1 dup1 min L^ max O^
                            K M                   dup1 dup1 min K^ max M^
                            A G                   dup1 dup1 min A^ max G^
                            D F                   dup1 dup1 min D^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            J AA                  dup1 dup1 min J^ max AA^
                            R Z                   dup1 dup1 min R^ max Z^
                            F X                   dup1 dup1 min F^ max X^
                            E W                   dup1 dup1 min E^ max W^
                            T V                   dup1 dup1 min T^ max V^
                            B S                   dup1 dup1 min B^ max S^
                            O P                   dup1 dup1 min O^ max P^
                            M N                   dup1 dup1 min M^ max N^
                            C K                   dup1 dup1 min C^ max K^
                            G I                   dup1 dup1 min G^ max I^
                            V AB                  dup1 dup1 min V^ max AB^
                            F Y                   dup1 dup1 min F^ max Y^
                            P X                   dup1 dup1 min P^ max X^
                            D W                   dup1 dup1 min D^ max W^
                            S U                   dup1 dup1 min S^ max U^
                            O Q                   dup1 dup1 min O^ max Q^
                            L N                   dup1 dup1 min L^ max N^
                            E M                   dup1 dup1 min E^ max M^
                            H J                   dup1 dup1 min H^ max J^
                            A G                   dup1 dup1 min A^ max G^
                            Z AB                            min Z^
                            X AA                            min X^
                            Q Y                   dup1 dup1 min Q^ max Y^
                            O W                   dup1 dup1 min O^ max W^
                            R V                             min R^
                            T U                   dup1 dup1 min T^ max U^
                            F N                   dup1 dup1 min F^ max N^
                            D L                   dup1 dup1 min D^ max L^
                            G K                                    max K^
                            H I                   dup1 dup1 min H^ max I^
                            B E                                    max E^
                            A C                                    max C^
                            U Y                             min U^
                            Q X                   dup1 dup1 min Q^ max X^
                            R W                   dup1 dup1 min R^ max W^
                            M T                   dup1 dup1 min M^ max T^
                            N S                   dup1 dup1 min N^ max S^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            E L                   dup1 dup1 min E^ max L^
                            F K                   dup1 dup1 min F^ max K^
                            D H                                    max H^
                            S Z                             min S^
                            T X                             min T^
                            O W                             min O^
                            K U                   dup1 dup1 min K^ max U^
                            H R                   dup1 dup1 min H^ max R^
                            M Q                   dup1 dup1 min M^ max Q^
                            L P                   dup1 dup1 min L^ max P^
                            F N                                    max N^
                            C J                                    max J^
                            E I                                    max I^
                            P U                             min P^
                            Q T                   dup1 dup1 min Q^ max T^
                            O R                   dup1 dup1 min O^ max R^
                            K N                   dup1 dup1 min K^ max N^
                            H M                                    max M^
                            I L                   dup1 dup1 min I^ max L^
                            R T                             min R^
                            P S                             min P^
                            N Q                   dup1 dup1 min N^ max Q^
                            L O                   dup1 dup1 min L^ max O^
                            J M                                    max M^
                            I K                                    max K^
                            P R                             min P^
                            O Q                             min O^
                            L N                                    max N^
                            K M                                    max M^
                            O P                   dup1 dup1 min O^ max P^
                            M N                   dup1 dup1 min M^ max N^
                            N P                             min N^
                            M O                                    max O^
                            N O                   dup1 dup1 max swap2 min

                            x swap2 clip"+ths                                                                                                                                 : \
                                                                                                                                                                                \
        mode == "CAM"    ? "x[0,2] A^ x[0,-2] G^ x[-2,0] C^ x[2,0] E^ x[-1,0] D@ x[1,0] F@ x[0,1] B@ x[0,-1] H@ x[0,0] X@ + + + + 0.2 * M^
                            A B                   dup1 dup1 min swap2 max
                            C D                   dup1 dup1 min swap2 max
                            E F                   dup1 dup1 min swap2 max
                            G H                   dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            X swap2 clip S^

                            B D                   dup1 dup1 min swap2 max
                            F H                   dup1 dup1 min swap2 max
                            swap1  swap2                    min
                            swap2                                     max
                                                  dup1 dup1 max swap2 min
                            X swap2 clip T^
                            S M - abs T M - abs > T S ?"+ths                                                                                                                  : \
                                                                                                                                                                                \
        mode == "SNN"    ? Format("
                            x[0,0] X@ x[-1,1] A@ - abs X x[1,-1]  H@ - abs M@ min L^
                            X         x[0,1]  B@ - abs X x[0,-1]  G@ - abs N@ min W^
                            X         x[1,1]  C@ - abs X x[-1,-1] F@ - abs O@ min Y^
                            X         x[-1,0] D@ - abs X x[1,0]   E@ - abs P@ min Z^

                            L {th} < L M == H A ? X ? W {th} < W N == G B ? X ? Y {th} < Y O == F C ? X ? Z {th} < Z P == E D ? X ? + + + 0.25 *")                            : \
                                                                                                                                                                                \
        mode == "kuwahara"?"x[-2,2] A@ x[-1,2] B@ x[0,2] C@ x[-2,1] F@ x[-1,1] G@ x[0,1] H@ x[-2,0] K@ x[-1,0] L@ x[0,0] M@ + + + + + + + + 0.111111111 * W^
                            C x[1,2] D@ x[2,2] E@ H x[1,1] I@ x[2,1] J@ M x[1,0] N@ x[2,0] O@                               + + + + + + + + 0.111111111 * WW^
                            K L M x[-2,-1] P@ x[-1,-1] Q@ x[0,-1] R@ x[-2,-2] U@ x[-1,-2] V@ x[0,-2] X@                     + + + + + + + + 0.111111111 * WWW^
                            A W   - dup * B W   - dup * C W   - dup * F W   - dup * G W   - dup * H W   - dup * K W   - dup * L W   - dup * M W   - dup * + + + + + + + + AA^
                            C WW  - dup * D WW  - dup * E WW  - dup * H WW  - dup * I WW  - dup * J WW  - dup * M WW  - dup * N WW  - dup * O WW  - dup * + + + + + + + + BB^
                            K WWW - dup * L WWW - dup * M WWW - dup * P WWW - dup * Q WWW - dup * R WWW - dup * U WWW - dup * V WWW - dup * X WWW - dup * + + + + + + + + CC^
                            AA BB min CC min EE@ AA == W EE BB == WW EE CC == WWW M N O R x[1,-1] x[2,-1] X x[1,-2] x[2,-2] + + + + + + + + 0.111111111 * ? ? ?"+ths: \
                                                                                                                                                                      \
        mode == "PWM"    ? "x[-1,1]  x[0,1]       dup1 dup1 min swap2 max
                            x[1,1]   x[-1,0]      dup1 dup1 min swap2 max
                            x[0,0]   x[1,0]       dup1 dup1 min swap2 max
                            x[-1,-1] x[0,-1]      dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  x[1,-1]        dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap8   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap8  swap1  swap3   dup1 dup1 min swap2 max
                            swap7  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap8   dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap8  swap1  swap2   dup1 dup1 min swap2 max
                            swap6  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap8  swap1  swap4   dup1 dup1 min swap2 max
                            swap5  swap8  swap6  swap7  swap5  swap6  swap1  swap5  swap1  swap4  swap3  swap2  swap1
                            A^ B^ C^ D^ E^ F^ G^ H^ I^
                            A B C + + R@ dup D E F G H I + + + + + + 0.5 * W@ - abs Z^
                            R     D  +                                                  W  - abs Y^ R D E + + W - abs X^ R D E F + + + W - abs V^
                            Z Y < B C + Y X < C D + X V < D E + E F + ? ? ? 0.5 *"+ths                                                                              : \
                                                                                                                                                                      \
        mode == "AWM"  ?   "x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[0,0] x[1,0] F@ x[-1,-1] G@ x[0,-1] H@ x[1,-1] I@ + + + + + + + + 0.111111111 * W^
                            F I                   dup1 dup1 min F^ max I^
                            B H                   dup1 dup1 min B^ max H^
                            D G                   dup1 dup1 min D^ max G^
                            A C                   dup1 dup1 min A^ max E^
                            B I                   dup1 dup1 min B^ max I^
                            E G                   dup1 dup1 min E^ max G^
                            A F                   dup1 dup1 min A^ max F^
                            D W                   dup1 dup1 min C^ max D^
                            G I                             min G^
                            F H                   dup1 dup1 min F^ max H^
                            D E                   dup1 dup1 min D^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            E H                             min E^
                            C F                   dup1 dup1 min C^ max F^
                            B D                   dup1 dup1 min B^ max D^
                            E G                   dup1 dup1 min E^ max G^
                            D F                   dup1 dup1 min D^ max F^
                            A C                                    max C^
                            F G                             min F^
                            D E                   dup1 dup1 min D^ max E^
                            B C                                    max C^
                            E F                                    max
                            C D                                    max

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "AMF"  ?   "x[-1,1]  G@ x[0,1]  H@ dup1 dup1 min swap2 max
                            x[1,1]   I@ x[-1,0] L@ dup1 dup1 min swap2 max
                            x[1,-1]  S@ x[1,0]  N@ dup1 dup1 min swap2 max
                            x[-1,-1] Q@ x[0,-1] R@ dup1 dup1 min swap2 max
                            swap2  swap1  swap6    dup1 dup1 min swap2 max
                            swap2  swap1  swap4    dup1 dup1 min swap2 max
                            swap3  swap1  swap7    dup1 dup1 min swap2 max
                            swap6  swap1  swap5    dup1 dup1 min swap2 max
                            swap3  swap1  swap2    dup1 dup1 min swap2 max
                            swap3  swap1  swap6    dup1 dup1 min swap2 max
                            swap7  swap1  swap4    dup1 dup1 min swap2 max
                            swap2  swap1  swap5    dup1 dup1 min swap2 max
                            swap2  swap1  swap7              min
                            swap4  swap1  swap3                        max
                            swap3  swap1  swap4              min
                            swap2                                      max
                                                   dup1 dup1 min swap2 max
                            swap2  swap3
                            ZA^ ZO^ ZP^ ZZ^
                            x ZO ZP clip MT^

                            L H                   dup1 dup1 min D^ max X^
                            R S                   dup1 dup1 min L^ max W^
                            I N                   dup1 dup1 min H^ max V^
                            Q G                   dup1 dup1 min A^ max U^
                            x[-2,-2] x[-2,-1]     dup1 dup1 min R^ max T^
                            x[-2,0]  x[-2,1]      dup1 dup1 min N^ max S^
                            x[-2,2]  x[-1,-2]     dup1 dup1 min C^ max Q^
                            x[-1,2]  x[0,-2]      dup1 dup1 min J^ max P^
                            x[0,2]   x[1,-2]      dup1 dup1 min I^ max O^
                            x[1,2]   x[2,-2]      dup1 dup1 min B^ max M^
                            x[2,-1]  x[2,0]       dup1 dup1 min F^ max K^
                            x[2,1]   x[2,2]       dup1 dup1 min E^ max G^
                            U X                   dup1 dup1 min U^ max X^
                            M W                   dup1 dup1 min M^ max W^
                            Q V                   dup1 dup1 min Q^ max V^
                            G T                   dup1 dup1 min G^ max T^
                            K S                   dup1 dup1 min K^ max S^
                            E R                   dup1 dup1 min E^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            B L                   dup1 dup1 min B^ max L^
                            I J                   dup1 dup1 min I^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            A D                   dup1 dup1 min A^ max D^
                            W X                   dup1 dup1 min W^ max X^
                            T V                   dup1 dup1 min T^ max V^
                            L U                   dup1 dup1 min L^ max U^
                            P S                   dup1 dup1 min P^ max S^
                            O R                   dup1 dup1 min O^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            S V                   dup1 dup1 min S^ max V^
                            P T                   dup1 dup1 min P^ max T^
                            M R                   dup1 dup1 min M^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            G L                   dup1 dup1 min G^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            C F                   dup1 dup1 min C^ max F^
                            P W                   dup1 dup1 min P^ max W^
                            J U                   dup1 dup1 min J^ max U^
                            Q T                   dup1 dup1 min Q^ max T^
                            D O                   dup1 dup1 min D^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            B I                   dup1 dup1 min B^ max I^
                            E H                   dup1 dup1 min E^ max H^
                            Q X                   dup1 dup1 min Q^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            T U                             min T^
                            M R                   dup1 dup1 min M^ max R^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            K N                   dup1 dup1 min K^ max N^
                            G L                   dup1 dup1 min G^ max L^
                            A H                   dup1 dup1 min A^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            D E                                    max E^
                            V X                                    max X^
                            R W                             min R^
                            Q T                   dup1 dup1 min Q^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            I K                   dup1 dup1 min I^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            B G                                    max G^
                            A C                             min A^
                            S T                   dup1 dup1 min S^ max T^
                            P R                             min P^
                            O Q                   dup1 dup1 min O^ max Q^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            G I                                    max I^
                            E F                   dup1 dup1 min E^ max F^
                            N T                             min N^
                            P Q                             min P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            E K                                    max K^
                            H I                                    max I^
                            N S                             min N^
                            O P                             min O^
                            F K                                    max K^
                            I J                                    max J^
                            L N                             min L^
                            K M                                    max M^
                            L O                             min L^
                            J M                                    max M^
                            L M                   dup1 dup1 max swap2 min

                            x swap2 clip F^
                            MT ZA > MT ZZ < & x ZA > x ZZ < & x MT ? F A > F X < & x A > x X < & x F ? x ? ?"+ths                                                   : \
                                                                                                                                                                      \
        mode == "unblob3"? "x[-2,-2] x[-2,-1]     dup1 dup1 min W^ max X^
                            x[-2,0]  x[-2,1]      dup1 dup1 min U^ max V^
                            x[-2,2]  x[-1,-2]     dup1 dup1 min S^ max T^
                            x[-1,-1] x[-1,0]      dup1 dup1 min Q^ max R^
                            x[-1,1]  x[-1,2]      dup1 dup1 min O^ max P^
                            x[0,-2]  x[0,-1]      dup1 dup1 min M^ max N^
                            x[0,1]   x[0,2]       dup1 dup1 min K^ max L^
                            x[1,-2]  x[1,-1]      dup1 dup1 min I^ max J^
                            x[1,0]   x[1,1]       dup1 dup1 min G^ max H^
                            x[1,2]   x[2,-2]      dup1 dup1 min E^ max F^
                            x[2,-1]  x[2,0]       dup1 dup1 min C^ max D^
                            x[2,1]   x[2,2]       dup1 dup1 min A^ max B^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            T X                   dup1 dup1 min T^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            P V                   dup1 dup1 min P^ max V^
                            O U                   dup1 dup1 min O^ max U^
                            N R                   dup1 dup1 min N^ max R^
                            M Q                   dup1 dup1 min M^ max Q^
                            H L                   dup1 dup1 min H^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            D J                   dup1 dup1 min D^ max J^
                            C I                   dup1 dup1 min C^ max I^
                            B F                   dup1 dup1 min B^ max F^
                            A E                   dup1 dup1 min A^ max E^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            L X                             min L^
                            K W                   dup1 dup1 min K^ max W^
                            T V                   dup1 dup1 min T^ max V^
                            S U                   dup1 dup1 min S^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            O Q                   dup1 dup1 min O^ max Q^
                            B N                   dup1 dup1 min B^ max N^
                            A M                                    max M^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            L W                   dup1 dup1 min L^ max W^
                            J V                   dup1 dup1 min J^ max V^
                            I U                   dup1 dup1 min I^ max U^
                            H T                                    max T^
                            G S                             min G^
                            F R                                    max R^
                            E Q                             min E^
                            D P                   dup1 dup1 min D^ max P^
                            C O                   dup1 dup1 min C^ max O^
                            B M                   dup1 dup1 min B^ max M^
                            V W                             min V^
                            J U                                    max U^
                            R T                   dup1 dup1 min R^ max T^
                            K P                                    max P^
                            D O                             min D^
                            I N                             min I^
                            E G                   dup1 dup1 min E^ max G^
                            B C                                    max C^
                            R U                                    max U^
                            L P                                    max P^
                            I M                             min I^
                            D G                             min D^
                            U V                     max P T max max
                            E I                     min C D min min

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "unblob3D"?"x[-1,1] x[0,1]        dup1 dup1 min A^ max Z^
                            x[1,1]  x[-1,0]       dup1 dup1 min W^ max Y^
                            x[1,0]  x[-1,-1]      dup1 dup1 min Q^ max X^
                            x[0,-1] x[1,-1]       dup1 dup1 min G^ max V^
                            y[-1,1] y[0,1]        dup1 dup1 min H^ max U^
                            y[1,1]  y[-1,0]       dup1 dup1 min E^ max T^
                            y[1,0]  y[-1,-1]      dup1 dup1 min F^ max S^
                            y[0,-1] y[1,-1]       dup1 dup1 min P^ max R^
                            z[-1,1] z[0,1]        dup1 dup1 min N^ max O^
                            z[1,1]  z[-1,0]       dup1 dup1 min L^ max M^
                            z[1,0]  z[-1,-1]      dup1 dup1 min I^ max K^
                            z[0,-1] z[1,-1]       dup1 dup1 min C^ max J^
                            z[0,0]  y[0,0]        dup1 dup1 min B^ max D^
                            V Y                   dup1 dup1 min V^ max Y^
                            J X                   dup1 dup1 min J^ max X^
                            G W                   dup1 dup1 min G^ max W^
                            M U                   dup1 dup1 min M^ max U^
                            D T                   dup1 dup1 min D^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            K R                   dup1 dup1 min K^ max R^
                            C Q                   dup1 dup1 min C^ max Q^
                            I P                   dup1 dup1 min I^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            H L                   dup1 dup1 min H^ max L^
                            B E                   dup1 dup1 min B^ max E^
                            U Y                   dup1 dup1 min U^ max Y^
                            R X                   dup1 dup1 min R^ max X^
                            L W                   dup1 dup1 min L^ max W^
                            M V                   dup1 dup1 min M^ max V^
                            S T                   dup1 dup1 min S^ max T^
                            K Q                   dup1 dup1 min K^ max Q^
                            J P                   dup1 dup1 min J^ max P^
                            D O                   dup1 dup1 min D^ max O^
                            E N                   dup1 dup1 min E^ max N^
                            C I                   dup1 dup1 min C^ max I^
                            G H                   dup1 dup1 min G^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            Q Z                   dup1 dup1 min Q^ max Z^
                            T X                   dup1 dup1 min T^ max X^
                            N U                   dup1 dup1 min N^ max U^
                            P S                                    max S^
                            F M                   dup1 dup1 min F^ max M^
                            H K                             min H^
                            A J                   dup1 dup1 min A^ max J^
                            C G                   dup1 dup1 min C^ max G^
                            U Z                   dup1 dup1 min U^ max Z^
                            N W                                    max W^
                            Q R                   dup1 dup1 min Q^ max R^
                            D M                             min D^
                            I J                   dup1 dup1 min I^ max J^
                            A F                   dup1 dup1 min A^ max F^
                            Y Z                   dup1 dup1 min Y^ max Z^
                            J W                                    max W^
                            R V                                    max V^
                            O U                                    max U^
                            D Q                             min D^
                            F L                             min F^
                            E I                             min E^
                            A B                   dup1 dup1 min A^ max B^
                            X Z                             min X^
                            T Y                                    max Y^
                            S W                                    max W^
                            U V                                    max V^
                            D H                             min D^
                            B G                             min B^
                            E F                             min E^
                            A C                                    max C^
                            W Y                   dup1 dup1 min W^ max Y^
                            V X                   dup1 dup1 min V^ max X^
                            C E                   dup1 dup1 min C^ max E^
                            B D                   dup1 dup1 min B^ max D^
                            V W max  X Y min                       max
                            B C max  D E min                min

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "undot1" ||                                                                                                                                           \
        mode == "undot"  ? "x[-1,1] A@ x[0,1] B@ max x[1,1] C@ max x[-1,0] D@ max x[1,0] E@ max x[-1,-1] F@ max x[0,-1] G@ max x[1,-1] H@ max
                            A B min C min D min E min F min G min H min x swap2 clip"+ths                                                                           : \
                                                                                                                                                                      \
        mode == "undot2" ? "x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap5  swap1  swap3             min
                            swap2  swap1  swap3                       max
                            swap2                           min
                            swap2                                     max
                            x swap2 swap1 clip"+ths                                                                                                                 : \
                                                                                                                                                                      \
        mode == "undot3" ? "x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap5  swap1  swap3             min
                            swap2  swap1  swap3                       max
                            swap2                                     max
                            swap2                           min
                            x swap2 swap1 clip"+ths                                                                                                                 : \
                                                                                                                                                                      \
        mode == "undot4" ||                                                                                                                                           \
        mode == "median" ? "x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "undot6" ? "x[-1,-1] A@     x[1,-1] B@ max x[0,-1] C@ max
                            x[-1,1]  D@ max x[1,1]  E@ max x[0,1]  F@ max M^
                            A B min C min D min E min F min

                            x swap M clip "+ths                                                                                                                     : \
                                                                                                                                                                      \
        mode == "IQM"    ? "x[-1,-1] x[-1,0]      dup1 dup1 min swap2 max
                            x[-1,1] x[0,-1]       dup1 dup1 min swap2 max
                            x[1,1] x[0,1]         dup1 dup1 min swap2 max
                            x[1,-1] x[1,0]        dup1 dup1 min swap2 max
                            swap2  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7   dup1 dup1 min swap2 max
                            swap6  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap6  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap4                       max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap2   dup1 dup1 min swap2 max
                            swap3  swap1  swap4             min
                            swap2                 dup1 dup1 min swap2 max
                            swap3  swap1  swap4                       max
                            swap2 swap swap3 dup1 dup1 x swap2 clip
                            + + swap2 + 0.75 * + 0.222222222 *"+ths                                                                                                 : \
                                                                                                                                                                      \
        mode == "IQM5"   ? "x[-2,-2] x[-2,-1]     dup1 dup1 min W^ max X^
                            x[-2,0] x[-2,1]       dup1 dup1 min U^ max V^
                            x[-2,2] x[-1,-2]      dup1 dup1 min S^ max T^
                            x[-1,-1] x[-1,0]      dup1 dup1 min Q^ max R^
                            x[-1,1] x[-1,2]       dup1 dup1 min O^ max P^
                            x[0,-2] x[0,-1]       dup1 dup1 min M^ max N^
                            x[0,1] x[0,2]         dup1 dup1 min K^ max L^
                            x[1,-2] x[1,-1]       dup1 dup1 min I^ max J^
                            x[1,0] x[1,1]         dup1 dup1 min G^ max H^
                            x[1,2] x[2,-2]        dup1 dup1 min E^ max F^
                            x[2,-1] x[2,0]        dup1 dup1 min C^ max D^
                            x[2,1] x[2,2]         dup1 dup1 min A^ max B^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            T X                   dup1 dup1 min T^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            P V                   dup1 dup1 min P^ max V^
                            O U                   dup1 dup1 min O^ max U^
                            N R                   dup1 dup1 min N^ max R^
                            M Q                   dup1 dup1 min M^ max Q^
                            H L                   dup1 dup1 min H^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            D J                   dup1 dup1 min D^ max J^
                            C I                   dup1 dup1 min C^ max I^
                            B F                   dup1 dup1 min B^ max F^
                            A E                   dup1 dup1 min A^ max E^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            L X                             min L^
                            K W                   dup1 dup1 min K^ max W^
                            T V                   dup1 dup1 min T^ max V^
                            S U                   dup1 dup1 min S^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            O Q                   dup1 dup1 min O^ max Q^
                            B N                   dup1 dup1 min B^ max N^
                            A M                                    max M^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            L W                   dup1 dup1 min L^ max W^
                            J V                   dup1 dup1 min J^ max V^
                            I U                   dup1 dup1 min I^ max U^
                            H T                   dup1 dup1 min H^ max T^
                            G S                   dup1 dup1 min G^ max S^
                            F R                   dup1 dup1 min F^ max R^
                            E Q                   dup1 dup1 min E^ max Q^
                            D P                   dup1 dup1 min D^ max P^
                            C O                   dup1 dup1 min C^ max O^
                            B M                   dup1 dup1 min B^ max M^
                            V W                             min V^
                            J U                   dup1 dup1 min J^ max U^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            K P                   dup1 dup1 min K^ max P^
                            D O                   dup1 dup1 min D^ max O^
                            I N                   dup1 dup1 min I^ max N^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B C                                    max C^
                            R U                   dup1 dup1 min R^ max U^
                            H S                   dup1 dup1 min H^ max S^
                            F Q                   dup1 dup1 min F^ max Q^
                            L P                   dup1 dup1 min L^ max P^
                            K O                   dup1 dup1 min K^ max O^
                            J N                   dup1 dup1 min J^ max N^
                            I M                   dup1 dup1 min I^ max M^
                            D G                   dup1 dup1 min D^ max G^
                            U V                             min U^
                            P T                             min P^
                            L S                   dup1 dup1 min L^ max S^
                            N R                   dup1 dup1 min N^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            F M                   dup1 dup1 min F^ max M^
                            G K                   dup1 dup1 min G^ max K^
                            E I                                    max I^
                            P S                   dup1 dup1 min P^ max S^
                            O Q                   dup1 dup1 min O^ max Q^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            H J                   dup1 dup1 min H^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            P R                   dup1 dup1 min P^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            L O                   dup1 dup1 min L^ max O^
                            J M                   dup1 dup1 min J^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G I                   dup1 dup1 min G^ max I^
                            P Q                   dup1 dup1 min P^ max Q^
                            N O                   dup1 dup1 min N^ max O^
                            L M                   dup1 dup1 min L^ max M^
                            J K                   dup1 dup1 min J^ max K^
                            H I                   dup1 dup1 min H^ max I^

                            x L M clip H I J K L M N O P Q
                            C D max F max G max S U min R min + 0.75 * + + + + + + + + + + + 0.08 *"+ths                                                            : \
                                                                                                                                                                      \
        mode == "IQMST"  ? "x[-2,-2] x[-1,0]      dup1 dup1 min D^ max L^
                            x[-2,2] x[0,-1]       dup1 dup1 min E^ max K^
                            x[2,2] x[0,1]         dup1 dup1 min F^ max J^
                            x[2,-2] x[1,0]        dup1 dup1 min A^ max I^
                            y z                   dup1 dup1 min B^ max H^
                            a b                   dup1 dup1 min C^ max G^
                            K L                   dup1 dup1 min K^ max L^
                            G J                   dup1 dup1 min G^ max J^
                            H I                   dup1 dup1 min H^ max I^
                            C F                   dup1 dup1 min C^ max F^
                            D E                   dup1 dup1 min D^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            J L                   dup1 dup1 min J^ max L^
                            F K                   dup1 dup1 min F^ max K^
                            B G                   dup1 dup1 min B^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            I L                             min I^
                            J K                   dup1 dup1 min J^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            A D                                    max D^
                            B C                   dup1 dup1 min B^ max C^
                            H K                   dup1 dup1 min H^ max K^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            B E                   dup1 dup1 min B^ max E^
                            I K                             min I^
                            G J                   dup1 dup1 min G^ max J^
                            C F                   dup1 dup1 min C^ max F^
                            B D                                    max D^
                            I J                             min I^
                            G H                   dup1 dup1 min G^ max H^
                            E F                   dup1 dup1 min E^ max F^
                            C D                                    max D^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            F G                   dup1 dup1 min F^ max G^
                            H I                   dup1 dup1 min H^ max I^
                            D E                   dup1 dup1 min D^ max E^
                            x F G clip E F G H
                            + + + + D I + 0.75 * + 0.153846154 *"+ths                                                                                               : \
                                                                                                                                                                      \
        mode == "IQMT"   ? "y z                   dup1 dup1 min swap2 max
                            a b                   dup1 dup1 min swap2 max
                            swap1  swap2                    min
                            swap2                                     max
                                                  dup1 dup1 max swap2 min

                            dup1 dup1 x swap2 clip + + 0.333333333 *"+ths                                                                                           : \
                                                                                                                                                                      \
        mode == "IQMV"   ? "x[-2,-2] x[-2,-1]     dup1 dup1 min W^ max X^
                            x[-2,0] x[-2,1]       dup1 dup1 min U^ max V^
                            x[-2,2] x[-1,-2]      dup1 dup1 min S^ max T^
                            x[-1,-1] AA@ x[-1,0] BB@  dup1 dup1 min Q^ max R^
                            x[-1,1] CC@ x[-1,2]       dup1 dup1 min O^ max P^
                            x[0,-2] x[0,-1] DD@       dup1 dup1 min M^ max N^
                            x[0,1] EE@ x[0,2]         dup1 dup1 min K^ max L^
                            x[1,-2] x[1,-1] FF@       dup1 dup1 min I^ max J^
                            x[1,0] GG@ x[1,1] HH@     dup1 dup1 min G^ max H^
                            x[1,2] x[2,-2]        dup1 dup1 min E^ max F^
                            x[2,-1] x[2,0]        dup1 dup1 min C^ max D^
                            x[2,1] x[2,2]         dup1 dup1 min A^ max B^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            T X                   dup1 dup1 min T^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            P V                   dup1 dup1 min P^ max V^
                            O U                   dup1 dup1 min O^ max U^
                            N R                   dup1 dup1 min N^ max R^
                            M Q                   dup1 dup1 min M^ max Q^
                            H L                   dup1 dup1 min H^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            D J                   dup1 dup1 min D^ max J^
                            C I                   dup1 dup1 min C^ max I^
                            B F                   dup1 dup1 min B^ max F^
                            A E                   dup1 dup1 min A^ max E^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            L X                             min L^
                            K W                   dup1 dup1 min K^ max W^
                            T V                   dup1 dup1 min T^ max V^
                            S U                   dup1 dup1 min S^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            O Q                   dup1 dup1 min O^ max Q^
                            B N                   dup1 dup1 min B^ max N^
                            A M                                    max M^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            L W                   dup1 dup1 min L^ max W^
                            J V                   dup1 dup1 min J^ max V^
                            I U                   dup1 dup1 min I^ max U^
                            H T                   dup1 dup1 min H^ max T^
                            G S                   dup1 dup1 min G^ max S^
                            F R                   dup1 dup1 min F^ max R^
                            E Q                   dup1 dup1 min E^ max Q^
                            D P                   dup1 dup1 min D^ max P^
                            C O                   dup1 dup1 min C^ max O^
                            B M                   dup1 dup1 min B^ max M^
                            V W                             min V^
                            J U                   dup1 dup1 min J^ max U^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            K P                   dup1 dup1 min K^ max P^
                            D O                   dup1 dup1 min D^ max O^
                            I N                   dup1 dup1 min I^ max N^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B C                                    max C^
                            R U                   dup1 dup1 min R^ max U^
                            H S                   dup1 dup1 min H^ max S^
                            F Q                   dup1 dup1 min F^ max Q^
                            L P                   dup1 dup1 min L^ max P^
                            K O                   dup1 dup1 min K^ max O^
                            J N                   dup1 dup1 min J^ max N^
                            I M                   dup1 dup1 min I^ max M^
                            D G                   dup1 dup1 min D^ max G^
                            U V                             min U^
                            P T                             min P^
                            L S                   dup1 dup1 min L^ max S^
                            N R                   dup1 dup1 min N^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            F M                   dup1 dup1 min F^ max M^
                            G K                   dup1 dup1 min G^ max K^
                            E I                                    max I^
                            P S                   dup1 dup1 min P^ max S^
                            O Q                   dup1 dup1 min O^ max Q^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            H J                   dup1 dup1 min H^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            P R                   dup1 dup1 min P^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            L O                   dup1 dup1 min L^ max O^
                            J M                   dup1 dup1 min J^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G I                   dup1 dup1 min G^ max I^
                            P Q                   dup1 dup1 min P^ max Q^
                            N O                   dup1 dup1 min N^ max O^
                            L M                   dup1 dup1 min L^ max M^
                            J K                   dup1 dup1 min J^ max K^
                            H I                   dup1 dup1 min H^ max I^

                            x L M clip H I J K L M N O P Q
                            C D max F max G max S U min R min + 0.75 * + + + + + + + + + + + 0.08 *"+ths+" YY^


                            AA BB                 dup1 dup1 min swap2 max
                            CC DD                 dup1 dup1 min swap2 max
                            EE FF                 dup1 dup1 min swap2 max
                            GG HH                 dup1 dup1 min swap2 max
                            swap2  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7   dup1 dup1 min swap2 max
                            swap6  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap6  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap4                       max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap2   dup1 dup1 min swap2 max
                            swap3  swap1  swap4             min
                            swap2                 dup1 dup1 min swap2 max
                            swap3  swap1  swap4                       max
                            swap2 swap swap3 dup1 dup1 x swap2 clip
                            + + swap2 + 0.75 * + 0.222222222 *"+ths+"

                            YY dup x - abs "+ti+" > swap2 swap1 ?"                                                                                                            : \
                                                                                                                                                                        \
        mode == "Trimean"? "x[-1,-1] x[-1,0]      dup1 dup1 min swap2 max
                            x[-1,1] x[0,-1]       dup1 dup1 min swap2 max
                            x[1,1] x[0,1]         dup1 dup1 min swap2 max
                            x[1,-1] x[1,0]        dup1 dup1 min swap2 max
                            swap2  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7   dup1 dup1 min swap2 max
                            swap6  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap6  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap4                       max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap2   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap2  swap1  swap3   dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap2 + 0.8 * swap2 + 0.2 * + swap2 x swap2 clip 2 * + 0.25 *"+ths                                                                      : \
                                                                                                                                                                      \
        mode == "Trimean5"?"x[-2,-2] x[-2,-1]     dup1 dup1 min W^ max X^
                            x[-2,0] x[-2,1]       dup1 dup1 min U^ max V^
                            x[-2,2] x[-1,-2]      dup1 dup1 min S^ max T^
                            x[-1,-1] x[-1,0]      dup1 dup1 min Q^ max R^
                            x[-1,1] x[-1,2]       dup1 dup1 min O^ max P^
                            x[0,-2] x[0,-1]       dup1 dup1 min M^ max N^
                            x[0,1] x[0,2]         dup1 dup1 min K^ max L^
                            x[1,-2] x[1,-1]       dup1 dup1 min I^ max J^
                            x[1,0] x[1,1]         dup1 dup1 min G^ max H^
                            x[1,2] x[2,-2]        dup1 dup1 min E^ max F^
                            x[2,-1] x[2,0]        dup1 dup1 min C^ max D^
                            x[2,1] x[2,2]         dup1 dup1 min A^ max B^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            T X                   dup1 dup1 min T^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            P V                   dup1 dup1 min P^ max V^
                            O U                   dup1 dup1 min O^ max U^
                            N R                   dup1 dup1 min N^ max R^
                            M Q                   dup1 dup1 min M^ max Q^
                            H L                   dup1 dup1 min H^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            D J                   dup1 dup1 min D^ max J^
                            C I                   dup1 dup1 min C^ max I^
                            B F                   dup1 dup1 min B^ max F^
                            A E                   dup1 dup1 min A^ max E^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            L X                             min L^
                            K W                   dup1 dup1 min K^ max W^
                            T V                   dup1 dup1 min T^ max V^
                            S U                   dup1 dup1 min S^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            O Q                   dup1 dup1 min O^ max Q^
                            B N                   dup1 dup1 min B^ max N^
                            A M                                    max M^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            L W                   dup1 dup1 min L^ max W^
                            J V                   dup1 dup1 min J^ max V^
                            I U                   dup1 dup1 min I^ max U^
                            H T                   dup1 dup1 min H^ max T^
                            G S                   dup1 dup1 min G^ max S^
                            F R                   dup1 dup1 min F^ max R^
                            E Q                   dup1 dup1 min E^ max Q^
                            D P                   dup1 dup1 min D^ max P^
                            C O                   dup1 dup1 min C^ max O^
                            B M                   dup1 dup1 min B^ max M^
                            V W                             min V^
                            J U                   dup1 dup1 min J^ max U^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            K P                   dup1 dup1 min K^ max P^
                            D O                   dup1 dup1 min D^ max O^
                            I N                   dup1 dup1 min I^ max N^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B C                                    max C^
                            R U                   dup1 dup1 min R^ max U^
                            H S                   dup1 dup1 min H^ max S^
                            F Q                   dup1 dup1 min F^ max Q^
                            L P                   dup1 dup1 min L^ max P^
                            K O                   dup1 dup1 min K^ max O^
                            J N                   dup1 dup1 min J^ max N^
                            I M                   dup1 dup1 min I^ max M^
                            D G                   dup1 dup1 min D^ max G^
                            U V                   dup1 dup1 min U^ max V^
                            P T                   dup1 dup1 min P^ max T^
                            L S                   dup1 dup1 min L^ max S^
                            N R                             min N^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            F M                   dup1 dup1 min F^ max M^
                            G K                                    max K^
                            E I                   dup1 dup1 min E^ max I^
                            C D                   dup1 dup1 min C^ max D^
                            T V                             min T^
                            P S                                    max S^
                            O Q                             min O^
                            L N                             min L^
                            K M                                    max M^
                            H J                                    max J^
                            F I                             min F^
                            C E                                    max E^
                            S U                                    max U^
                            L O                             min L^
                            J M                                    max M^
                            D F                             min D^
                            T U                             min T^
                            L M                   dup1 dup1 min L^ max M^
                            D E                                    max E^

                            x L M clip 2 * E T + + 0.25 *"+ths                                                                                                      : \
                                                                                                                                                                      \
        mode == "Winsor" ? "x[-1,-1] x[-1,0]      dup1 dup1 min swap2 max
                            x[-1,1] x[0,-1]       dup1 dup1 min swap2 max
                            x[1,1] x[0,1]         dup1 dup1 min swap2 max
                            x[1,-1] x[1,0]        dup1 dup1 min swap2 max
                            swap2  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7   dup1 dup1 min swap2 max
                            swap6  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap6  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap4                       max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap2   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap2  swap1  swap3   dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap2 dup1 dup1 + + + + + swap2 dup dup2 swap x swap2 clip + + + 0.111111111 *"+ths                                                                                                : \
                                                                                                                                                                      \
        mode == "Winsor5"? "x[-2,-2] x[-2,-1]     dup1 dup1 min D^ max X^
                            x[-2,0] x[-2,1]       dup1 dup1 min L^ max W^
                            x[-2,2] x[-1,-2]      dup1 dup1 min H^ max V^
                            x[-1,-1] x[-1,0]      dup1 dup1 min A^ max U^
                            x[-1,1] x[-1,2]       dup1 dup1 min R^ max T^
                            x[0,-2] x[0,-1]       dup1 dup1 min N^ max S^
                            x[0,1] x[0,2]         dup1 dup1 min C^ max Q^
                            x[1,-2] x[1,-1]       dup1 dup1 min J^ max P^
                            x[1,0] x[1,1]         dup1 dup1 min I^ max O^
                            x[1,2] x[2,-2]        dup1 dup1 min B^ max M^
                            x[2,-1] x[2,0]        dup1 dup1 min F^ max K^
                            x[2,1] x[2,2]         dup1 dup1 min E^ max G^
                            U X                   dup1 dup1 min U^ max X^
                            M W                   dup1 dup1 min M^ max W^
                            Q V                   dup1 dup1 min Q^ max V^
                            G T                   dup1 dup1 min G^ max T^
                            K S                   dup1 dup1 min K^ max S^
                            E R                   dup1 dup1 min E^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            B L                   dup1 dup1 min B^ max L^
                            I J                   dup1 dup1 min I^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            A D                   dup1 dup1 min A^ max D^
                            W X                   dup1 dup1 min W^ max X^
                            T V                   dup1 dup1 min T^ max V^
                            L U                   dup1 dup1 min L^ max U^
                            P S                   dup1 dup1 min P^ max S^
                            O R                   dup1 dup1 min O^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            S V                   dup1 dup1 min S^ max V^
                            P T                   dup1 dup1 min P^ max T^
                            M R                   dup1 dup1 min M^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            G L                   dup1 dup1 min G^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            C F                   dup1 dup1 min C^ max F^
                            P W                   dup1 dup1 min P^ max W^
                            J U                   dup1 dup1 min J^ max U^
                            Q T                   dup1 dup1 min Q^ max T^
                            D O                   dup1 dup1 min D^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            B I                   dup1 dup1 min B^ max I^
                            E H                   dup1 dup1 min E^ max H^
                            Q X                   dup1 dup1 min Q^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            T U                   dup1 dup1 min T^ max U^
                            M R                   dup1 dup1 min M^ max R^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            K N                   dup1 dup1 min K^ max N^
                            G L                   dup1 dup1 min G^ max L^
                            A H                   dup1 dup1 min A^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            D E                   dup1 dup1 min D^ max E^
                            V X                             min V^
                            R W                   dup1 dup1 min R^ max W^
                            Q T                   dup1 dup1 min Q^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            I K                   dup1 dup1 min I^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            B G                   dup1 dup1 min B^ max G^
                            A C                                    max C^
                            U V                   dup1 dup1 min U^ max V^
                            S T                   dup1 dup1 min S^ max T^
                            P R                   dup1 dup1 min P^ max R^
                            O Q                   dup1 dup1 min O^ max Q^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            E F                   dup1 dup1 min E^ max F^
                            C D                   dup1 dup1 min C^ max D^
                            V W                             min V^
                            R U                   dup1 dup1 min R^ max U^
                            N T                   dup1 dup1 min N^ max T^
                            P Q                   dup1 dup1 min P^ max Q^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            E K                   dup1 dup1 min E^ max K^
                            H I                   dup1 dup1 min H^ max I^
                            D G                   dup1 dup1 min D^ max G^
                            B C                                    max C^
                            U V                   dup1 dup1 min U^ max V^
                            N S                   dup1 dup1 min N^ max S^
                            Q R                   dup1 dup1 min Q^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F K                   dup1 dup1 min F^ max K^
                            I J                   dup1 dup1 min I^ max J^
                            G H                   dup1 dup1 min G^ max H^
                            C D                   dup1 dup1 min C^ max D^
                            T U                   dup1 dup1 min T^ max U^
                            Q S                   dup1 dup1 min Q^ max S^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            F H                   dup1 dup1 min F^ max H^
                            D E                   dup1 dup1 min D^ max E^
                            R T                   dup1 dup1 min R^ max T^
                            N P                   dup1 dup1 min N^ max P^
                            L O                   dup1 dup1 min L^ max O^
                            J M                   dup1 dup1 min J^ max M^
                            I K                   dup1 dup1 min I^ max K^
                            E G                   dup1 dup1 min E^ max G^
                            R S                   dup1 dup1 min R^ max S^
                            P Q                   dup1 dup1 min P^ max Q^
                            N O                   dup1 dup1 min N^ max O^
                            L M                   dup1 dup1 min L^ max M^
                            J K                   dup1 dup1 min J^ max K^
                            H I                   dup1 dup1 min H^ max I^
                            F G                   dup1 dup1 min F^ max G^

                            U V C D + + + 2 * E F G H I J K L M N O P Q R S T
                            x M N clip + + + + + + + + + + + + + + + + + 0.04 *"+ths                                                                                : \
                                                                                                                                                                      \
        mode == "midsum" ? "x[-1,-1] x[-1,0]      dup1 dup1 min swap2 max
                            x[-1,1] x[0,-1]       dup1 dup1 min swap2 max
                            x[1,1] x[0,1]         dup1 dup1 min swap2 max
                            x[1,-1] x[1,0]        dup1 dup1 min swap2 max
                            swap2  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7   dup1 dup1 min swap2 max
                            swap6  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap6  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap4                       max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap2  swap1  swap5                       max
                            swap3                           min
                            swap2                           min
                            swap2                                     max
                            + 0.5 *"+ths                                                                                                                            : \
                                                                                                                                                                      \
        mode == "RMF"    ? "x[-2,-2]   x[-1,-2] A@ dup1 dup1 min swap2 max
                            x[0,-2] B@ x[-2,-1] C@ dup1 dup1 min swap2 max
                            x[0,0]  X@ x[0,-1]  D@ dup1 dup1 min swap2 max
                            x[-2,0] E@ x[-1,0]  F@ dup1 dup1 min swap2 max
                            swap7  swap1  swap3    dup1 dup1 min swap2 max
                            swap5  swap1  swap3    dup1 dup1 min swap2 max
                            swap6  swap1  swap2    dup1 dup1 min swap2 max
                            swap4  swap1  swap7    dup1 dup1 min swap2 max
                            swap3  swap1  swap2                        max
                            swap6                  dup1 dup1 min swap2 max
                            swap4  swap1  swap5    dup1 dup1 min swap2 max
                            swap3  swap1  swap2              min
                            swap4                                      max
                            swap2                            min
                            swap3                                      max
                            swap2                            min
                                                   dup1 dup1 max swap2 min

                            x[-1,-1] H@ swap2 clip TL^

                            A                  B   dup1 dup1 min swap2 max
                            x[1,-2] G@         H   dup1 dup1 min swap2 max
                            X          x[1,-1] I@  dup1 dup1 min swap2 max
                            F          x[1,0]  J@  dup1 dup1 min swap2 max
                            swap7  swap1  swap3    dup1 dup1 min swap2 max
                            swap5  swap1  swap3    dup1 dup1 min swap2 max
                            swap6  swap1  swap2    dup1 dup1 min swap2 max
                            swap4  swap1  swap7    dup1 dup1 min swap2 max
                            swap3  swap1  swap2                        max
                            swap6                  dup1 dup1 min swap2 max
                            swap4  swap1  swap5    dup1 dup1 min swap2 max
                            swap3  swap1  swap2              min
                            swap4                                      max
                            swap2                            min
                            swap3                                      max
                            swap2                            min
                                                   dup1 dup1 max swap2 min
                            D swap2 clip TC^

                            B       G             dup1 dup1 min swap2 max
                            x[2,-2] D             dup1 dup1 min swap2 max
                            X       x[2,-1]       dup1 dup1 min swap2 max
                            J       x[2,0]        dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            I swap2 clip TR^

                            C                  H  dup1 dup1 min swap2 max
                            D                  E  dup1 dup1 min swap2 max
                            X          x[-2,1]    dup1 dup1 min swap2 max
                            x[-1,1] K@ x[0,1]  L@ dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            F swap2 clip CL^

                            TL TC                 dup1 dup1 min swap2 max
                            TR CL                 dup1 dup1 min swap2 max
                            J  K                  dup1 dup1 min swap2 max
                            L x[1,1]              dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min
                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "cartoon"? "x[-1,1] A@ x[1,-1] H@ + x[0,1] B@ x[0,-1] G@ + max x[1,1] C@ x[-1,-1] F@ + max x[-1,0] D@ x[1,0] E@ + max 0.5 * "                         \
                          +"A H +                          B G + min                  C F +            min         D E +          min 0.5 * x swap2 clip"+ths       : \
                                                                                                                                                                      \
        mode == "edgeS"  ? "x[-1,1] x[1,-1]  dup1 dup1 min swap2 max
                            x[0,1]  x[0,-1]  dup1 dup1 min swap2 max
                            x[1,1]  x[-1,-1] dup1 dup1 min swap2 max
                            x[-1,0] x[1,0]   dup1 dup1 min swap2 max
                            swap3                      max swap2 min
                            swap3 swap1 swap5          max swap3 min
                                                       min swap2 max
                                             dup1 dup1 max swap2 min
                            x swap2 clip"+ths                                                                                                                      : \
                                                                                                                                                                     \
        mode == "edgeW"  ? "                                             x[0,0] I@ x[0,1]  B@ - abs I x[0,-1] G@ - abs max BB@
                            I x[1,1]  C@ - abs I x[-1,-1] F@ - abs max CC@ min  I  x[-1,0] D@ - abs I x[1,0]  E@ - abs max DD@ min
                            I x[-1,1] A@ - abs I x[1,-1] H@ - abs max      min
                            X@ DD == I D E dup1 dup1 min swap2 max clip X BB == I B G dup1 dup1 min swap2 max clip
                            X  CC == I C F dup1 dup1 min swap2 max clip         I A H dup1 dup1 min swap2 max clip ? ? ?"+ths                                      : \
                                                                                                                                                                     \
        mode == "edgeC"  ? "x[-1,1]   A@ x[0,1] B@  dup1 dup1 min swap2 max
                            B x[1,1]  C@            dup1 dup1 min swap2 max
                            C x[1,0]  E@            dup1 dup1 min swap2 max
                            E x[1,-1] H@            dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO^
                            swap1 swap2 min min min                         HI^

                            x[0,-1]  G@ H dup1 dup1 min swap2 max
                            x[-1,-1] F@ G dup1 dup1 min swap2 max
                            x[-1,0]  D@ F dup1 dup1 min swap2 max
                            A D           dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO max LO^
                            swap1 swap2 min min min                         HI min HI@ LO

                            x swap2 min LO HI max clip"+ths                                                                                                        : \
                                                                                                                                                                     \
        mode == "edgeCL" ? "x[-1,1] A@ x[1,-1] H@   dup1 dup1 min swap2 max
                            A          x[0,1]  B@   dup1 dup1 min swap2 max
                            x[0,-1] G@         H    dup1 dup1 min swap2 max
                            B                  G    dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO^
                            swap1 swap2 min min min                         HI^

                            x[1,1]   C@ B dup1 dup1 min swap2 max
                            x[-1,-1] F@ G dup1 dup1 min swap2 max
                                     C  F dup1 dup1 min swap2 max
                            x[1,0]   E@ C dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO max LO^
                            swap1 swap2 min min min                         HI min HI^

                            x[-1,0]  D@ F dup1 dup1 min swap2 max
                                     D  E dup1 dup1 min swap2 max
                                     E  H dup1 dup1 min swap2 max
                                     D  A dup1 dup1 min swap2 max
                            swap7 swap1 swap5 max swap1 swap4 swap2 max max LO max LO^
                            swap1 swap2 min min min                         HI min LO

                            dup1 dup1 max swap2 min
                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "EMF" ?    Format("
                            x[-1,1] x[0,1]        dup1 dup1 min swap2 max
                            x[1,1]  x[-1,0]       dup1 dup1 min swap2 max
                            x[1,0]  x[-1,-1]      dup1 dup1 min swap2 max
                            x[0,-1] x[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                                     max
                            swap2                           min
                            swap3                                     max
                            swap2                           min
                                                  dup1 dup1 max swap2 min

                            x swap2 clip M@ x swap - abs {th} <= M x ?")                                                                                            : \
                                                                                                                                                                      \
        mode == "smart" ||                                                                                                                                            \
        mode == "smart1" ?   Format("
                            x[-1,1] A@ x[0,1] B@ x[1,1] C@ x[-1,0] D@ x[1,0] E@ x[-1,-1] F@ x[0,-1] G@ x[1,-1] H@ + + + + + + + 0.125 * W^
                            A B                   dup1 dup1 min swap2 max
                            C D                   dup1 dup1 min swap2 max
                            E F                   dup1 dup1 min swap2 max
                            G H                   dup1 dup1 min swap2 max
                            swap2  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7   dup1 dup1 min swap2 max
                            swap6  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap3  swap1  swap6   dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap2  swap1  swap5   dup1 dup1 min swap2 max
                            swap2  swap1  swap7             min
                            swap4  swap1  swap3                       max
                            swap3  swap1  swap4             min
                            swap2                                     max
                                                  dup1 dup1 min swap2 max
                            E^ D^ H^
                              W - dup * H W - dup * + sqrt 13 *
                              x - abs {th} <= x D E clip x ?")                                                                                                      : \
                                                                                                                                                                      \
        mode == "smart2" ?   Format(ex_shape(2,center=false,pop=false)+"
                            + + + + + + + + + + + + + + + + + + + + + + + 0.04 * Y^
                            D Z                   dup1 dup1 min D^ max Z^
                            L W                   dup1 dup1 min L^ max W^
                            H V                   dup1 dup1 min H^ max V^
                            A U                   dup1 dup1 min A^ max U^
                            R T                   dup1 dup1 min R^ max T^
                            N S                   dup1 dup1 min N^ max S^
                            C Q                   dup1 dup1 min C^ max Q^
                            J P                   dup1 dup1 min J^ max P^
                            I O                   dup1 dup1 min I^ max O^
                            B M                   dup1 dup1 min B^ max M^
                            F K                   dup1 dup1 min F^ max K^
                            E G                   dup1 dup1 min E^ max G^
                            U Z                   dup1 dup1 min U^ max Z^
                            M W                   dup1 dup1 min M^ max W^
                            Q V                   dup1 dup1 min Q^ max V^
                            G T                   dup1 dup1 min G^ max T^
                            K S                   dup1 dup1 min K^ max S^
                            E R                   dup1 dup1 min E^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            B L                   dup1 dup1 min B^ max L^
                            I J                   dup1 dup1 min I^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            A D                   dup1 dup1 min A^ max D^
                            W Z                   dup1 dup1 min W^ max Z^
                            T V                   dup1 dup1 min T^ max V^
                            L U                   dup1 dup1 min L^ max U^
                            P S                   dup1 dup1 min P^ max S^
                            O R                   dup1 dup1 min O^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            S V                   dup1 dup1 min S^ max V^
                            P T                   dup1 dup1 min P^ max T^
                            M R                   dup1 dup1 min M^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            G L                   dup1 dup1 min G^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            C F                   dup1 dup1 min C^ max F^
                            P W                   dup1 dup1 min P^ max W^
                            J U                   dup1 dup1 min J^ max U^
                            Q T                   dup1 dup1 min Q^ max T^
                            D O                   dup1 dup1 min D^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            B I                   dup1 dup1 min B^ max I^
                            E H                   dup1 dup1 min E^ max H^
                            Q Z                   dup1 dup1 min Q^ max Z^
                            S W                   dup1 dup1 min S^ max W^
                            M R                   dup1 dup1 min M^ max R^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            K N                   dup1 dup1 min K^ max N^
                            G L                   dup1 dup1 min G^ max L^
                            A H                   dup1 dup1 min A^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            Q T U min             dup1 dup1 min Q^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            I K                   dup1 dup1 min I^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            D E max H             dup1 dup1 min E^ max H^
                            S T                   dup1 dup1 min S^ max T^
                            O Q                   dup1 dup1 min O^ max Q^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            E F                   dup1 dup1 min E^ max F^
                            R W min P min Q                 min P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            O P min N T min S min L min min
                            B G max I max H max J max  E K max F max M max max
                            dup1 dup1 min L^ max M^
                            V Z                                    max
                            A C                             min

                              Y - dup * swap Y - dup * + sqrt 13 *
                              x - abs {th} <= x L M clip x ?")                                                                                                      : \
                                                                                                                                                                      \
        mode == "smart3" ?   Format(ex_shape(3,center=false,pop=false)+"
                            + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + 0.02 * Y^
                            D Z                   dup1 dup1 min D^ max Z^
                            L W                   dup1 dup1 min L^ max W^
                            H V                   dup1 dup1 min H^ max V^
                            A U                   dup1 dup1 min A^ max U^
                            R T                   dup1 dup1 min R^ max T^
                            N S                   dup1 dup1 min N^ max S^
                            C Q                   dup1 dup1 min C^ max Q^
                            J P                   dup1 dup1 min J^ max P^
                            I O                   dup1 dup1 min I^ max O^
                            B M                   dup1 dup1 min B^ max M^
                            F K                   dup1 dup1 min F^ max K^
                            E G                   dup1 dup1 min E^ max G^
                            U Z                   dup1 dup1 min U^ max Z^
                            M W                   dup1 dup1 min M^ max W^
                            Q V                   dup1 dup1 min Q^ max V^
                            G T                   dup1 dup1 min G^ max T^
                            K S                   dup1 dup1 min K^ max S^
                            E R                   dup1 dup1 min E^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            B L                   dup1 dup1 min B^ max L^
                            I J                   dup1 dup1 min I^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            A D                   dup1 dup1 min A^ max D^
                            W Z                   dup1 dup1 min W^ max Z^
                            T V                   dup1 dup1 min T^ max V^
                            L U                   dup1 dup1 min L^ max U^
                            P S                   dup1 dup1 min P^ max S^
                            O R                   dup1 dup1 min O^ max R^
                            N Q                   dup1 dup1 min N^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            F I                   dup1 dup1 min F^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            A B                   dup1 dup1 min A^ max B^
                            S V                   dup1 dup1 min S^ max V^
                            P T                   dup1 dup1 min P^ max T^
                            M R                   dup1 dup1 min M^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            G L                   dup1 dup1 min G^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            C F                   dup1 dup1 min C^ max F^
                            P W                   dup1 dup1 min P^ max W^
                            J U                   dup1 dup1 min J^ max U^
                            Q T                   dup1 dup1 min Q^ max T^
                            D O                   dup1 dup1 min D^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            B I                   dup1 dup1 min B^ max I^
                            E H                   dup1 dup1 min E^ max H^
                            Q Z                   dup1 dup1 min Q^ max Z^
                            S W                   dup1 dup1 min S^ max W^
                            T U                   dup1 dup1 min T^ max U^
                            M R                   dup1 dup1 min M^ max R^
                            I P                   dup1 dup1 min I^ max P^
                            J O                   dup1 dup1 min J^ max O^
                            K N                   dup1 dup1 min K^ max N^
                            G L                   dup1 dup1 min G^ max L^
                            A H                   dup1 dup1 min A^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            D E                   dup1 dup1 min D^ max E^
                            V Z                   dup1 dup1 min V^ max Z^
                            R W                   dup1 dup1 min R^ max W^
                            Q T                   dup1 dup1 min Q^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            I K                   dup1 dup1 min I^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            B G                   dup1 dup1 min B^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            U V                   dup1 dup1 min U^ max V^
                            S T                   dup1 dup1 min S^ max T^
                            P R                   dup1 dup1 min P^ max R^
                            O Q                   dup1 dup1 min O^ max Q^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            E F                   dup1 dup1 min E^ max F^
                            C D                   dup1 dup1 min C^ max D^
                            V W                   dup1 dup1 min V^ max W^
                            R U                   dup1 dup1 min R^ max U^
                            N T                   dup1 dup1 min N^ max T^
                            P Q                   dup1 dup1 min P^ max Q^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            E K                   dup1 dup1 min E^ max K^
                            H I                   dup1 dup1 min H^ max I^
                            D G                   dup1 dup1 min D^ max G^
                            B C                   dup1 dup1 min B^ max C^
                            U V                   dup1 dup1 min U^ max V^
                            N S                   dup1 dup1 min N^ max S^
                            Q R                   dup1 dup1 min Q^ max R^
                            O P                   dup1 dup1 min O^ max P^
                            F K                   dup1 dup1 min F^ max K^
                            I J                   dup1 dup1 min I^ max J^
                            G H                   dup1 dup1 min G^ max H^
                            C D                   dup1 dup1 min C^ max D^
                            T U                   dup1 dup1 min T^ max U^
                            Q S                   dup1 dup1 min Q^ max S^
                            L N                   dup1 dup1 min L^ max N^
                            K M                   dup1 dup1 min K^ max M^
                            F H                   dup1 dup1 min F^ max H^
                            D E                   dup1 dup1 min D^ max E^
                            R T                   dup1 dup1 min R^ max T^
                            N P                   dup1 dup1 min N^ max P^
                            L O                   dup1 dup1 min L^ max O^
                            J M                   dup1 dup1 min J^ max M^
                            I K                   dup1 dup1 min I^ max K^
                            E G                   dup1 dup1 min E^ max G^
                            R S                   dup1 dup1 min R^ max S^
                            P Q                   dup1 dup1 min P^ max Q^
                            N O                   dup1 dup1 min N^ max O^
                            L M                   dup1 dup1 min L^ max M^
                            J K                   dup1 dup1 min J^ max K^
                            H I                   dup1 dup1 min H^ max I^
                            F G                   dup1 dup1 min F^ max G^
                            DD YY                 dup1 dup1 min DD^ max YY^
                            LL WW                 dup1 dup1 min LL^ max WW^
                            HH VV                 dup1 dup1 min HH^ max VV^
                            AA UU                 dup1 dup1 min AA^ max UU^
                            RR TT                 dup1 dup1 min RR^ max TT^
                            NN SS                 dup1 dup1 min NN^ max SS^
                            CC QQ                 dup1 dup1 min CC^ max QQ^
                            JJ PP                 dup1 dup1 min JJ^ max PP^
                            II OO                 dup1 dup1 min II^ max OO^
                            BB MM                 dup1 dup1 min BB^ max MM^
                            FF KK                 dup1 dup1 min FF^ max KK^
                            EE GG                 dup1 dup1 min EE^ max GG^
                            UU YY                 dup1 dup1 min UU^ max YY^
                            MM WW                 dup1 dup1 min MM^ max WW^
                            QQ VV                 dup1 dup1 min QQ^ max VV^
                            GG TT                 dup1 dup1 min GG^ max TT^
                            KK SS                 dup1 dup1 min KK^ max SS^
                            EE RR                 dup1 dup1 min EE^ max RR^
                            OO PP                 dup1 dup1 min OO^ max PP^
                            FF NN                 dup1 dup1 min FF^ max NN^
                            BB LL                 dup1 dup1 min BB^ max LL^
                            II JJ                 dup1 dup1 min II^ max JJ^
                            CC HH                 dup1 dup1 min CC^ max HH^
                            AA DD                 dup1 dup1 min AA^ max DD^
                            WW YY                 dup1 dup1 min WW^ max YY^
                            TT VV                 dup1 dup1 min TT^ max VV^
                            LL UU                 dup1 dup1 min LL^ max UU^
                            PP SS                 dup1 dup1 min PP^ max SS^
                            OO RR                 dup1 dup1 min OO^ max RR^
                            NN QQ                 dup1 dup1 min NN^ max QQ^
                            DD MM                 dup1 dup1 min DD^ max MM^
                            HH KK                 dup1 dup1 min HH^ max KK^
                            GG JJ                 dup1 dup1 min GG^ max JJ^
                            FF II                 dup1 dup1 min FF^ max II^
                            CC EE                 dup1 dup1 min CC^ max EE^
                            AA BB                 dup1 dup1 min AA^ max BB^
                            SS VV                 dup1 dup1 min SS^ max VV^
                            PP TT                 dup1 dup1 min PP^ max TT^
                            MM RR                 dup1 dup1 min MM^ max RR^
                            JJ QQ                 dup1 dup1 min JJ^ max QQ^
                            HH OO                 dup1 dup1 min HH^ max OO^
                            GG LL                 dup1 dup1 min GG^ max LL^
                            EE II                 dup1 dup1 min EE^ max II^
                            CC FF                 dup1 dup1 min CC^ max FF^
                            PP WW                 dup1 dup1 min PP^ max WW^
                            JJ UU                 dup1 dup1 min JJ^ max UU^
                            QQ TT                 dup1 dup1 min QQ^ max TT^
                            DD OO                 dup1 dup1 min DD^ max OO^
                            LL NN                 dup1 dup1 min LL^ max NN^
                            KK MM                 dup1 dup1 min KK^ max MM^
                            BB II                 dup1 dup1 min BB^ max II^
                            EE HH                 dup1 dup1 min EE^ max HH^
                            QQ YY                 dup1 dup1 min QQ^ max YY^
                            SS WW                 dup1 dup1 min SS^ max WW^
                            TT UU                 dup1 dup1 min TT^ max UU^
                            MM RR                 dup1 dup1 min MM^ max RR^
                            II PP                 dup1 dup1 min II^ max PP^
                            JJ OO                 dup1 dup1 min JJ^ max OO^
                            KK NN                 dup1 dup1 min KK^ max NN^
                            GG LL                 dup1 dup1 min GG^ max LL^
                            AA HH                 dup1 dup1 min AA^ max HH^
                            BB FF                 dup1 dup1 min BB^ max FF^
                            DD EE                 dup1 dup1 min DD^ max EE^
                            VV YY                 dup1 dup1 min VV^ max YY^
                            RR WW                 dup1 dup1 min RR^ max WW^
                            QQ TT                 dup1 dup1 min QQ^ max TT^
                            OO SS                 dup1 dup1 min OO^ max SS^
                            NN PP                 dup1 dup1 min NN^ max PP^
                            II KK                 dup1 dup1 min II^ max KK^
                            FF JJ                 dup1 dup1 min FF^ max JJ^
                            EE HH                 dup1 dup1 min EE^ max HH^
                            BB GG                 dup1 dup1 min BB^ max GG^
                            AA CC                 dup1 dup1 min AA^ max CC^
                            UU VV                 dup1 dup1 min UU^ max VV^
                            SS TT                 dup1 dup1 min SS^ max TT^
                            PP RR                 dup1 dup1 min PP^ max RR^
                            OO QQ                 dup1 dup1 min OO^ max QQ^
                            MM NN                 dup1 dup1 min MM^ max NN^
                            KK LL                 dup1 dup1 min KK^ max LL^
                            HH JJ                 dup1 dup1 min HH^ max JJ^
                            GG II                 dup1 dup1 min GG^ max II^
                            EE FF                 dup1 dup1 min EE^ max FF^
                            CC DD                 dup1 dup1 min CC^ max DD^
                            VV WW                 dup1 dup1 min VV^ max WW^
                            RR UU                 dup1 dup1 min RR^ max UU^
                            NN TT                 dup1 dup1 min NN^ max TT^
                            PP QQ                 dup1 dup1 min PP^ max QQ^
                            MM OO                 dup1 dup1 min MM^ max OO^
                            JJ LL                 dup1 dup1 min JJ^ max LL^
                            EE KK                 dup1 dup1 min EE^ max KK^
                            HH II                 dup1 dup1 min HH^ max II^
                            DD GG                 dup1 dup1 min DD^ max GG^
                            BB CC                 dup1 dup1 min BB^ max CC^
                            UU VV                 dup1 dup1 min UU^ max VV^
                            NN SS                 dup1 dup1 min NN^ max SS^
                            QQ RR                 dup1 dup1 min QQ^ max RR^
                            OO PP                 dup1 dup1 min OO^ max PP^
                            FF KK                 dup1 dup1 min FF^ max KK^
                            II JJ                 dup1 dup1 min II^ max JJ^
                            GG HH                 dup1 dup1 min GG^ max HH^
                            CC DD                 dup1 dup1 min CC^ max DD^
                            TT UU                 dup1 dup1 min TT^ max UU^
                            QQ SS                 dup1 dup1 min QQ^ max SS^
                            LL NN                 dup1 dup1 min LL^ max NN^
                            KK MM                 dup1 dup1 min KK^ max MM^
                            FF HH                 dup1 dup1 min FF^ max HH^
                            DD EE                 dup1 dup1 min DD^ max EE^
                            RR TT                 dup1 dup1 min RR^ max TT^
                            NN PP                 dup1 dup1 min NN^ max PP^
                            LL OO                 dup1 dup1 min LL^ max OO^
                            JJ MM                 dup1 dup1 min JJ^ max MM^
                            II KK                 dup1 dup1 min II^ max KK^
                            EE GG                 dup1 dup1 min EE^ max GG^
                            RR SS                 dup1 dup1 min RR^ max SS^
                            PP QQ                 dup1 dup1 min PP^ max QQ^
                            NN OO                 dup1 dup1 min NN^ max OO^
                            LL MM                 dup1 dup1 min LL^ max MM^
                            JJ KK                 dup1 dup1 min JJ^ max KK^
                            HH II                 dup1 dup1 min HH^ max II^
                            FF GG                 dup1 dup1 min FF^ max GG^

                            A YY                  dup1 dup1 min A^ max YY^
                            B WW                  dup1 dup1 min B^ max WW^
                            C VV                  dup1 dup1 min C^ max VV^
                            D UU                  dup1 dup1 min D^ max UU^
                            E TT                  dup1 dup1 min E^ max TT^
                            F SS                  dup1 dup1 min F^ max SS^
                            G RR                  dup1 dup1 min G^ max RR^
                            H QQ                  dup1 dup1 min H^ max QQ^
                            I PP                  dup1 dup1 min I^ max PP^
                            J OO                  dup1 dup1 min J^ max OO^
                            K NN                  dup1 dup1 min K^ max NN^
                            L MM                  dup1 dup1 min L^ max MM^
                            M LL                  dup1 dup1 min M^ max LL^
                            N KK                  dup1 dup1 min N^ max KK^
                            O JJ                  dup1 dup1 min O^ max JJ^
                            P II                  dup1 dup1 min P^ max II^
                            Q HH                  dup1 dup1 min Q^ max HH^
                            R GG                  dup1 dup1 min R^ max GG^
                            S FF                  dup1 dup1 min S^ max FF^
                            T EE                  dup1 dup1 min T^ max EE^
                            U DD                  dup1 dup1 min U^ max DD^
                            V CC                  dup1 dup1 min V^ max CC^
                            W BB                  dup1 dup1 min W^ max BB^
                            Z AA                  dup1 dup1 min Z^ max AA^

                            A M                   dup1 dup1 min A^ max M^
                            B N                   dup1 dup1 min B^ max N^
                            C O                   dup1 dup1 min C^ max O^
                            D P                   dup1 dup1 min D^ max P^
                            E Q                   dup1 dup1 min E^ max Q^
                            F R                   dup1 dup1 min F^ max R^
                            G S                   dup1 dup1 min G^ max S^
                            H T                   dup1 dup1 min H^ max T^
                            I U                   dup1 dup1 min I^ max U^
                            J V                   dup1 dup1 min J^ max V^
                            K W                   dup1 dup1 min K^ max W^
                            L Z                   dup1 dup1 min L^ max Z^

                            AA MM                 dup1 dup1 min AA^ max MM^
                            BB NN                 dup1 dup1 min BB^ max NN^
                            CC OO                 dup1 dup1 min CC^ max OO^
                            DD PP                 dup1 dup1 min DD^ max PP^
                            EE QQ                 dup1 dup1 min EE^ max QQ^
                            FF RR                 dup1 dup1 min FF^ max RR^
                            GG SS                 dup1 dup1 min GG^ max SS^
                            HH TT                 dup1 dup1 min HH^ max TT^
                            II UU                 dup1 dup1 min II^ max UU^
                            JJ VV                 dup1 dup1 min JJ^ max VV^
                            KK WW                 dup1 dup1 min KK^ max WW^
                            LL YY                 dup1 dup1 min LL^ max YY^

                            M S max P V max                         max V^
                            N T max Q W max                         max W^
                            O U max R Z max       dup1 dup1 min U^  max Z^

                            AA GG min DD JJ min   dup1 dup1 min AA^ max DD^
                            BB HH min EE KK min             min BB^
                            CC II min FF LL min             min CC^

                            MM SS max PP VV max                     max VV^
                            NN TT max QQ WW max                     max WW^

                            U W max V Z max                         max Z^
                            AA CC min BB DD min             min AA^

                            OO UU max RR YY max   dup1 dup1 min UU^ max YY^
                            UU WW max VV YY max                     max YY^

                            A G min D J min        dup1 dup1 min A^ max D^
                            C I min F L min min A min B H min E K min min D min min

                            Y - dup * YY Y - dup * + sqrt 13 *
                            x - abs {th} <= x Z AA clip x ?")                                                                                                       : \
                                                                                                                                                                      \
        mode == "CWM" ?    "x[-1,1] x[0,1]        dup1 dup1 min I^ max J^
                            x[1,1]  x[-1,0]       dup1 dup1 min E^ max H^
                            x[1,0]  x[-1,-1]      dup1 dup1 min D^ max G^
                            x[0,-1] x[1,-1]       dup1 dup1 min C^ max F^
                            x[0,0]  dup                         A^     B^
                            D J                   dup1 dup1 min D^ max J^
                            B I                   dup1 dup1 min B^ max I^
                            F H                   dup1 dup1 min F^ max H^
                            A G                   dup1 dup1 min A^ max G^
                            C E                   dup1 dup1 min C^ max E^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            E F                   dup1 dup1 min E^ max F^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            I J                             min I^
                            C H                   dup1 dup1 min C^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            D F                   dup1 dup1 min D^ max F^
                            A B                                    max B^
                            H I                             min H^
                            F G                             min F^
                            D E                                    max E^
                            B C                                    max C^
                            F H                             min F^
                            C E                                    max E^
                            E F                   dup1 dup1 max swap2 min

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "CWM2" ?   "x[-1,1] x[0,1]        dup1 dup1 min D^ max L^
                            x[1,1]  x[-1,0]       dup1 dup1 min E^ max K^
                            x[1,0]  x[-1,-1]      dup1 dup1 min F^ max J^
                            x[0,-1] x[1,-1]       dup1 dup1 min A^ max I^
                            x[0,0]  dup dup dup                 B^     H^
                                                                C^     G^
                            J L                   dup1 dup1 min J^ max L^
                            H K                   dup1 dup1 min H^ max K^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            B E                   dup1 dup1 min B^ max E^
                            A C                   dup1 dup1 min A^ max C^
                            K L                             min K^
                            C J                   dup1 dup1 min C^ max J^
                            E H                   dup1 dup1 min E^ max H^
                            F G                   dup1 dup1 min F^ max G^
                            A B                                    max B^
                            I K                             min I^
                            E J                   dup1 dup1 min E^ max J^
                            C H                   dup1 dup1 min C^ max H^
                            B D                                    max D^
                            I J                             min I^
                            G H                             min G^
                            E F                                    max F^
                            C D                                    max D^
                            G I                   dup1 dup1 min G^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            F I                             min F^
                            D G                                    max G^
                            F G                   dup1 dup1 max swap2 min

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "WMF"  ?   "x[-1,1]  x[1,1]       dup1 dup1 min K^ max P^
                            x[-1,-1] x[1,-1]      dup1 dup1 min L^ max O^
                            x[0,1]   dup                        D^     N^
                            x[-1,0]  dup                        C^     M^
                            x[0,-1]  dup                        I^     J^
                            x[1,0]   dup                        G^     H^
                            x[0,0]   dup dup dup                A^     F^
                                                                B^     E^
                            N P                   dup1 dup1 min N^ max P^
                            F O                   dup1 dup1 min F^ max O^
                            J M                   dup1 dup1 min J^ max M^
                            I L                   dup1 dup1 min I^ max L^
                            B K                   dup1 dup1 min B^ max K^
                            E H                   dup1 dup1 min E^ max H^
                            D G                   dup1 dup1 min D^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            H P                   dup1 dup1 min H^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            E N                   dup1 dup1 min E^ max N^
                            C L                   dup1 dup1 min C^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            A I                   dup1 dup1 min A^ max I^
                            B D                   dup1 dup1 min B^ max D^
                            O P                             min O^
                            L N                   dup1 dup1 min L^ max N^
                            H M                   dup1 dup1 min H^ max M^
                            J K                   dup1 dup1 min J^ max K^
                            D I                   dup1 dup1 min D^ max I^
                            F G                   dup1 dup1 min F^ max G^
                            C E                   dup1 dup1 min C^ max E^
                            A B                                    max B^
                            M O                             min M^
                            K N                             min K^
                            H L                   dup1 dup1 min H^ max L^
                            G J                   dup1 dup1 min G^ max J^
                            E I                   dup1 dup1 min E^ max I^
                            C F                                    max F^
                            B D                                    max D^
                            K M                             min K^
                            E L                   dup1 dup1 min E^ max L^
                            H J                   dup1 dup1 min H^ max J^
                            G I                   dup1 dup1 min G^ max I^
                            D F                                    max F^
                            K L                             min K^
                            I J                             min I^
                            G H                                    max H^
                            E F                                    max F^
                            I K                             min I^
                            F H                                    max H^
                            H I                   dup1 dup1 max swap2 min

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "STWM"   ? "x[-1,1]  x[1,1]       dup1 dup1 min U^ max V^
                            x[-1,-1] x[1,-1]      dup1 dup1 min S^ max T^
                            x[0,1]   dup                        Q^     R^
                            x[-1,0]  dup                        O^     P^
                            x[0,-1]  dup                        M^     N^
                            x[1,0]   dup                        K^     L^
                            x[0,0]   dup dup dup                I^     J^
                                                                G^     H^
                            y b                   dup1 dup1 min E^ max F^
                            a dup                               C^     D^
                            z dup                               A^     B^
                            J V                   dup1 dup1 min J^ max V^
                            I U                   dup1 dup1 min I^ max U^
                            P T                   dup1 dup1 min P^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            L R                   dup1 dup1 min L^ max R^
                            B N                   dup1 dup1 min B^ max N^
                            A M                   dup1 dup1 min A^ max M^
                            E K                   dup1 dup1 min E^ max K^
                            D H                   dup1 dup1 min D^ max H^
                            C G                   dup1 dup1 min C^ max G^
                            T V                   dup1 dup1 min T^ max V^
                            P U                   dup1 dup1 min P^ max U^
                            J S                   dup1 dup1 min J^ max S^
                            F R                   dup1 dup1 min F^ max R^
                            E Q                   dup1 dup1 min E^ max Q^
                            I O                   dup1 dup1 min I^ max O^
                            H N                   dup1 dup1 min H^ max N^
                            D M                   dup1 dup1 min D^ max M^
                            B G                   dup1 dup1 min B^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            N V                   dup1 dup1 min N^ max V^
                            G U                   dup1 dup1 min G^ max U^
                            H T                   dup1 dup1 min H^ max T^
                            M S                   dup1 dup1 min M^ max S^
                            K Q                   dup1 dup1 min K^ max Q^
                            B P                   dup1 dup1 min B^ max P^
                            C O                   dup1 dup1 min C^ max O^
                            F L                   dup1 dup1 min F^ max L^
                            D J                   dup1 dup1 min D^ max J^
                            A I                   dup1 dup1 min A^ max I^
                            R V                             min R^
                            L U                   dup1 dup1 min L^ max U^
                            N S                   dup1 dup1 min N^ max S^
                            M Q                   dup1 dup1 min M^ max Q^
                            H O                   dup1 dup1 min H^ max O^
                            B K                   dup1 dup1 min B^ max K^
                            F J                   dup1 dup1 min F^ max J^
                            D I                   dup1 dup1 min D^ max I^
                            A E                                    max E^
                            S U                             min S^
                            Q T                             min Q^
                            N R                             min N^
                            M P                   dup1 dup1 min M^ max P^
                            L O                   dup1 dup1 min L^ max O^
                            H K                   dup1 dup1 min H^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            E I                                    max I^
                            C F                                    max F^
                            B D                                    max D^
                            J S                             min J^
                            N Q                   dup1 dup1 min N^ max Q^
                            K P                   dup1 dup1 min K^ max P^
                            D M                                    max M^
                            G L                   dup1 dup1 min G^ max L^
                            F I                   dup1 dup1 min F^ max I^
                            O Q                             min O^
                            J P                             min J^
                            K N                   dup1 dup1 min K^ max N^
                            G M                                    max M^
                            I L                   dup1 dup1 min I^ max L^
                            F H                                    max H^
                            J O                             min J^
                            L N                             min L^
                            H M                                    max M^
                            I K                                    max K^
                            K M                   dup1 dup1 min K^ max M^
                            J L                   dup1 dup1 min J^ max L^
                            J K max L M min       dup1 dup1 max swap2 min

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "Vertical" ?"x[0,-1] x[0,1] dup1 dup1 max swap2 min
                             x swap2 clip"+ths                                                                                                                      : \
                                                                                                                                                                      \
        mode == "verticalS"?"x[0,-2] B2^ x[0,-1] B1^ x[0,1] T1^ x[0,2] T2^
                             B1 B2    - 0 range_max clip B1 + 0 range_max clip    T1 T2 - 0 range_max clip T1 + 0 range_max clip min B1 max T1 max
                             B1 B2 B1 - 0 range_max clip -    0 range_max clip T1 T2 T1 - 0 range_max clip    - 0 range_max clip max B1 T1 min min
                             x swap2 clip"+ths                                                                                                                      : \
                                                                                                                                                                      \
        mode == "horizontal"?"x[-1,0] x[1,0] dup1 dup1 max swap2 min
                              x swap2 clip"+ths                                                                                                                     : \
                                                                                                                                                                      \
        mode == "horizontalS"?"x[-2,0] B2^ x[-1,0] B1^ x[1,0] T1^ x[2,0] T2^
                               B1 B2    - 0 range_max clip B1 + 0 range_max clip    T1 T2 - 0 range_max clip T1 + 0 range_max clip min B1 max T1 max
                               B1 B2 B1 - 0 range_max clip -    0 range_max clip T1 T2 T1 - 0 range_max clip    - 0 range_max clip max B1 T1 min min
                               x swap2 clip"+ths                                                                                                                    : \
                                                                                                                                                                      \
        mode == "DGM0"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - AM@
                            D C - AA@ min
                            F E - AB@ min
                            H G - AC@ min
                            J I - AD@ min
                            L K - AE@ min
                            N M - AF@ min
                            P O - AG@ min
                            R Q - AH@ min
                            T S - AI@ min
                            V U - AJ@ min
                            X W - AK@ min
                            Z Y - AL@ min BB@

                               AL == x Y Z clip BB AJ == x U V clip BB AK == x W X clip BB AI == x S T clip BB AG == x O P clip BB AH == x Q R clip
                            BB AF == x M N clip BB AD == x I J clip BB AE == x K L clip BB AC == x G H clip BB AA == x C D clip BB AB == x E F clip x A B clip ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                         : \
                                                                                                                                                                     \
        mode == "DGM1"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - 4 * x dup A B clip A@ - abs + AM@
                            D C - 4 * x dup C D clip B@ - abs + AA@ min
                            F E - 4 * x dup E F clip C@ - abs + AB@ min
                            H G - 4 * x dup G H clip D@ - abs + AC@ min
                            J I - 4 * x dup I J clip E@ - abs + AD@ min
                            L K - 4 * x dup K L clip F@ - abs + AE@ min
                            N M - 4 * x dup M N clip G@ - abs + AF@ min
                            P O - 4 * x dup O P clip H@ - abs + AG@ min
                            R Q - 4 * x dup Q R clip I@ - abs + AH@ min
                            T S - 4 * x dup S T clip J@ - abs + AI@ min
                            V U - 4 * x dup U V clip K@ - abs + AJ@ min
                            X W - 4 * x dup W X clip L@ - abs + AK@ min
                            Z Y - 4 * x dup Y Z clip M@ - abs + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM2"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - 2 * x dup A B clip A@ - abs + AM@
                            D C - 2 * x dup C D clip B@ - abs + AA@ min
                            F E - 2 * x dup E F clip C@ - abs + AB@ min
                            H G - 2 * x dup G H clip D@ - abs + AC@ min
                            J I - 2 * x dup I J clip E@ - abs + AD@ min
                            L K - 2 * x dup K L clip F@ - abs + AE@ min
                            N M - 2 * x dup M N clip G@ - abs + AF@ min
                            P O - 2 * x dup O P clip H@ - abs + AG@ min
                            R Q - 2 * x dup Q R clip I@ - abs + AH@ min
                            T S - 2 * x dup S T clip J@ - abs + AI@ min
                            V U - 2 * x dup U V clip K@ - abs + AJ@ min
                            X W - 2 * x dup W X clip L@ - abs + AK@ min
                            Z Y - 2 * x dup Y Z clip M@ - abs + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM3"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - x dup A B clip A@ - abs + AM@
                            D C - x dup C D clip B@ - abs + AA@ min
                            F E - x dup E F clip C@ - abs + AB@ min
                            H G - x dup G H clip D@ - abs + AC@ min
                            J I - x dup I J clip E@ - abs + AD@ min
                            L K - x dup K L clip F@ - abs + AE@ min
                            N M - x dup M N clip G@ - abs + AF@ min
                            P O - x dup O P clip H@ - abs + AG@ min
                            R Q - x dup Q R clip I@ - abs + AH@ min
                            T S - x dup S T clip J@ - abs + AI@ min
                            V U - x dup U V clip K@ - abs + AJ@ min
                            X W - x dup W X clip L@ - abs + AK@ min
                            Z Y - x dup Y Z clip M@ - abs + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM4"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            B A - x dup A B clip A@ - abs 2 * + AM@
                            D C - x dup C D clip B@ - abs 2 * + AA@ min
                            F E - x dup E F clip C@ - abs 2 * + AB@ min
                            H G - x dup G H clip D@ - abs 2 * + AC@ min
                            J I - x dup I J clip E@ - abs 2 * + AD@ min
                            L K - x dup K L clip F@ - abs 2 * + AE@ min
                            N M - x dup M N clip G@ - abs 2 * + AF@ min
                            P O - x dup O P clip H@ - abs 2 * + AG@ min
                            R Q - x dup Q R clip I@ - abs 2 * + AH@ min
                            T S - x dup S T clip J@ - abs 2 * + AI@ min
                            V U - x dup U V clip K@ - abs 2 * + AJ@ min
                            X W - x dup W X clip L@ - abs 2 * + AK@ min
                            Z Y - x dup Y Z clip M@ - abs 2 * + AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "DGM5"   ?  Format("
                            x[1,-1] x[-1,1]  dup1 dup1 min A^ max B^
                            x[1,1]  x[-1,-1] dup1 dup1 min C^ max D^
                            x[0,1]  x[0,-1]  dup1 dup1 min E^ max F^
                            x[1,0]  x[-1,0]  dup1 dup1 min G^ max H^
                            z[-1,1] y[1,-1]  dup1 dup1 min I^ max J^
                            z[1,1]  y[-1,-1] dup1 dup1 min K^ max L^
                            y[1,1]  z[-1,-1] dup1 dup1 min M^ max N^
                            z[1,-1] y[-1,1]  dup1 dup1 min O^ max P^
                            z[0,-1] y[0,1]   dup1 dup1 min Q^ max R^
                            z[0,1]  y[0,-1]  dup1 dup1 min S^ max T^
                            y[1,0]  z[-1,0]  dup1 dup1 min U^ max V^
                            z[1,0]  y[-1,0]  dup1 dup1 min W^ max X^
                            z[0,0]  y[0,0]   dup1 dup1 min Y^ max Z^

                            x dup A B clip A@ - abs AM@
                            x dup C D clip B@ - abs AA@ min
                            x dup E F clip C@ - abs AB@ min
                            x dup G H clip D@ - abs AC@ min
                            x dup I J clip E@ - abs AD@ min
                            x dup K L clip F@ - abs AE@ min
                            x dup M N clip G@ - abs AF@ min
                            x dup O P clip H@ - abs AG@ min
                            x dup Q R clip I@ - abs AH@ min
                            x dup S T clip J@ - abs AI@ min
                            x dup U V clip K@ - abs AJ@ min
                            x dup W X clip L@ - abs AK@ min
                            x dup Y Z clip M@ - abs AL@ min BB@

                               AL == M BB AJ == K BB AK == L BB AI == J BB AG == H BB AH == I BB AF == G BB AD == E BB AE == F BB AC == D BB AA == B BB AB == C A ? ? ? ? ? ? ? ? ? ? ? ?
                            Z@ x swap - abs {th} > x Z ?")                                                                                                          : \
                                                                                                                                                                      \
        mode == "GaussT5" ? "z a + 4 * y b x 6 * + + + 0.0625 * "+ths                                                                                               : \
                                                                                                                                                                      \
        mode == "GaussST5"?"z[0,2] z[-2,0] z[2,0] z[0,-2] a[0,2] a[-2,0] a[2,0] a[0,-2] + + + + + + + 2 *
                            x[-1,2] x[1,2] x[-2,1] x[2,1] x[-2,-1] x[2,-1] x[-1,-2] x[1,-2] z[-1,1] z[1,1] z[-1,-1] z[1,-1] y[0,1] y[-1,0] y[1,0] y[0,-1] a[-1,1] a[1,1] a[-1,-1] a[1,-1] b[0,1] b[-1,0] b[1,0] b[0,-1] + + + + + + + + + + + + + + + + + + + + + + + 4 *
                            x[0,2] x[-2,0] x[2,0] x[0,-2] z[0,1] z[-1,0] z[1,0] z[0,-1] y[0,0] a[0,1] a[-1,0] a[1,0] a[0,-1] b[0,0] + + + + + + + + + + + + + 6 *
                            x[-1,1] x[1,1] x[-1,-1] x[1,-1] + + + 16 *
                            x[0,1] x[-1,0] x[1,0] x[0,-1] a[0,0] z[0,0] + + + + + 24 *
                            x[-2,2] x[2,2] x[-2,-2] x[2,-2] z[-1,2] z[1,2] z[-1,-2] z[1,-2] z[-2,1] z[-2,-1] z[2,1] z[2,-1] y[-1,1] y[1,1] y[-1,-1]  y[1,-1] a[-1,2] a[1,2] a[-2,1] a[2,1] a[-2,-1] a[2,-1] a[-1,-2] a[1,-2] b[-1,1] b[1,1] b[-1,-1] b[1,-1]
                            x[0,0] 36 * + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + 0.002136752 *"+ths                                        : \
                                                                                                                                                                      \
        mode == "medianT" ? "y z dup1 dup1 min swap2 max swap1 x max min"+ths                                                                                       : \
                                                                                                                                                                      \
        mode == "medianT5"? "x y                   dup1 dup1 min swap2 max
                             z a                   dup1 dup1 min swap2 max
                             swap3  b              dup1 dup1 min swap2 max
                             swap2  swap1  swap3   dup1 dup1 min swap2 max
                             swap3                                     max
                             swap3                 dup1 dup1 min swap2 max
                             swap3                                     max
                             swap2                           min
                                                             min"+ths                                                                                               : \
                                                                                                                                                                      \
        mode == "medianST"?"x[-1,1] x[0,1]        dup1 dup1 min M^ max Z^
                            x[1,1]  x[-1,0]       dup1 dup1 min T^ max Y^
                            x[1,0]  x[-1,-1]      dup1 dup1 min R^ max X^
                            x[0,-1] x[1,-1]       dup1 dup1 min F^ max W^
                            y[-1,1] y[0,1]        dup1 dup1 min S^ max V^
                            y[1,1]  y[-1,0]       dup1 dup1 min D^ max U^
                            y[1,0]  y[-1,-1]      dup1 dup1 min J^ max Q^
                            y[0,-1] y[1,-1]       dup1 dup1 min K^ max P^
                            z[-1,1] z[0,1]        dup1 dup1 min L^ max O^
                            z[1,1]  z[-1,0]       dup1 dup1 min A^ max N^
                            z[1,0]  z[-1,-1]      dup1 dup1 min C^ max I^
                            z[0,-1] z[1,-1]       dup1 dup1 min E^ max H^
                            z[0,0]  y[0,0]        dup1 dup1 min B^ max G^
                            W Z                   dup1 dup1 min W^ max Z^
                            G Y                   dup1 dup1 min G^ max Y^
                            H V                   dup1 dup1 min H^ max V^
                            N U                   dup1 dup1 min N^ max U^
                            B T                   dup1 dup1 min B^ max T^
                            E S                   dup1 dup1 min E^ max S^
                            J R                   dup1 dup1 min J^ max R^
                            I Q                   dup1 dup1 min I^ max Q^
                            O P                   dup1 dup1 min O^ max P^
                            F M                   dup1 dup1 min F^ max M^
                            K L                   dup1 dup1 min K^ max L^
                            A D                   dup1 dup1 min A^ max D^
                            P Z                   dup1 dup1 min P^ max Z^
                            U Y                   dup1 dup1 min U^ max Y^
                            I X                   dup1 dup1 min I^ max X^
                            N W                   dup1 dup1 min N^ max W^
                            O T                   dup1 dup1 min O^ max T^
                            J S                   dup1 dup1 min J^ max S^
                            C R                   dup1 dup1 min C^ max R^
                            H Q                   dup1 dup1 min H^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            G L                   dup1 dup1 min G^ max L^
                            A K                   dup1 dup1 min A^ max K^
                            B F                   dup1 dup1 min B^ max F^
                            Y Z                   dup1 dup1 min Y^ max Z^
                            Q X                   dup1 dup1 min Q^ max X^
                            L W                   dup1 dup1 min L^ max W^
                            R V                   dup1 dup1 min R^ max V^
                            P U                   dup1 dup1 min P^ max U^
                            M T                   dup1 dup1 min M^ max T^
                            H S                   dup1 dup1 min H^ max S^
                            D O                   dup1 dup1 min D^ max O^
                            G N                   dup1 dup1 min G^ max N^
                            F K                   dup1 dup1 min F^ max K^
                            C J                   dup1 dup1 min C^ max J^
                            E I                   dup1 dup1 min E^ max I^
                            A B                   dup1 dup1 min A^ max B^
                            U Y                   dup1 dup1 min U^ max Y^
                            V X                   dup1 dup1 min V^ max X^
                            T W                   dup1 dup1 min T^ max W^
                            Q S                   dup1 dup1 min Q^ max S^
                            I R                   dup1 dup1 min I^ max R^
                            K P                   dup1 dup1 min K^ max P^
                            L O                   dup1 dup1 min L^ max O^
                            M N                   dup1 dup1 min M^ max N^
                            H J                   dup1 dup1 min H^ max J^
                            D G                   dup1 dup1 min D^ max G^
                            B F                   dup1 dup1 min B^ max F^
                            C E                   dup1 dup1 min C^ max E^
                            X Z                             min X^
                            W Y                   dup1 dup1 min W^ max Y^
                            S V                   dup1 dup1 min S^ max V^
                            T U                   dup1 dup1 min T^ max U^
                            P R                   dup1 dup1 min P^ max R^
                            J Q                   dup1 dup1 min J^ max Q^
                            N O                   dup1 dup1 min N^ max O^
                            L M                   dup1 dup1 min L^ max M^
                            I K                   dup1 dup1 min I^ max K^
                            E H                   dup1 dup1 min E^ max H^
                            F G                   dup1 dup1 min F^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                                    max C^
                            X Y                   dup1 dup1 min X^ max Y^
                            V W                             min V^
                            H T                   dup1 dup1 min H^ max T^
                            G S                   dup1 dup1 min G^ max S^
                            O R                             min O^
                            N Q                   dup1 dup1 min N^ max Q^
                            K P                   dup1 dup1 min K^ max P^
                            J M                   dup1 dup1 min J^ max M^
                            I L                                    max L^
                            D E                                    max E^
                            B C                   dup1 dup1 min B^ max C^
                            Q Y                             min Q^
                            O X                             min O^
                            T V                             min T^
                            S U                             min S^
                            N P                   dup1 dup1 min N^ max P^
                            K M                   dup1 dup1 min K^ max M^
                            C L                                    max L^
                            B J                                    max J^
                            F H                                    max H^
                            E G                                    max G^
                            L T                   dup1 dup1 min L^ max T^
                            G O                   dup1 dup1 min G^ max O^
                            H N max L max P Q min T min dup1 dup1 min N^ max P^
                            J K max G max M S min O min dup1 dup1 min N  max swap2 max P min
                                                  dup1 dup1 max swap2 min
                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "medianSTS"?"x[-1,-2] x[-2,-1]    dup1 dup1 min AE^ max AF^
                            x[-2,0]   x[-2,1]     dup1 dup1 min AC^ max AD^
                            x[-1,-1]  x[-1,0]     dup1 dup1 min AA^ max AB^
                            x[-1,1]   x[-1,2]     dup1 dup1 min Y^ max Z^
                            x[0,-2]   x[0,-1]     dup1 dup1 min W^ max X^
                            x[0,1]    x[0,2]      dup1 dup1 min U^ max V^
                            x[1,-2]   x[1,-1]     dup1 dup1 min S^ max T^
                            x[1,0]    x[1,1]      dup1 dup1 min Q^ max R^
                            x[2,-1]   x[2,0]      dup1 dup1 min O^ max P^
                            x[2,1]    x[1,2]      dup1 dup1 min M^ max N^
                            z[0,1]    z[0,-1]     dup1 dup1 min K^ max L^
                            z[1,0]    z[-1,0]     dup1 dup1 min I^ max J^
                            a[0,1]    a[0,-1]     dup1 dup1 min G^ max H^
                            a[1,0]    a[-1,0]     dup1 dup1 min E^ max F^
                            y         z           dup1 dup1 min C^ max D^
                            a         b           dup1 dup1 min A^ max B^
                            AD AF                 dup1 dup1 min AD^ max AF^
                            AC AE                 dup1 dup1 min AC^ max AE^
                            Z AB                  dup1 dup1 min Z^ max AB^
                            Y AA                  dup1 dup1 min Y^ max AA^
                            V X                   dup1 dup1 min V^ max X^
                            U W                   dup1 dup1 min U^ max W^
                            R T                   dup1 dup1 min R^ max T^
                            Q S                   dup1 dup1 min Q^ max S^
                            N P                   dup1 dup1 min N^ max P^
                            M O                   dup1 dup1 min M^ max O^
                            J L                   dup1 dup1 min J^ max L^
                            I K                   dup1 dup1 min I^ max K^
                            F H                   dup1 dup1 min F^ max H^
                            E G                   dup1 dup1 min E^ max G^
                            B D                   dup1 dup1 min B^ max D^
                            A C                   dup1 dup1 min A^ max C^
                            AB AF                 dup1 dup1 min AB^ max AF^
                            AA AE                 dup1 dup1 min AA^ max AE^
                            Z AD                  dup1 dup1 min Z^ max AD^
                            Y AC                  dup1 dup1 min Y^ max AC^
                            T X                   dup1 dup1 min T^ max X^
                            S W                   dup1 dup1 min S^ max W^
                            R V                   dup1 dup1 min R^ max V^
                            Q U                   dup1 dup1 min Q^ max U^
                            L P                   dup1 dup1 min L^ max P^
                            K O                   dup1 dup1 min K^ max O^
                            J N                   dup1 dup1 min J^ max N^
                            I M                   dup1 dup1 min I^ max M^
                            D H                   dup1 dup1 min D^ max H^
                            C G                   dup1 dup1 min C^ max G^
                            B F                   dup1 dup1 min B^ max F^
                            A E                   dup1 dup1 min A^ max E^
                            X AF                  dup1 dup1 min X^ max AF^
                            W AE                  dup1 dup1 min W^ max AE^
                            V AD                  dup1 dup1 min V^ max AD^
                            U AC                  dup1 dup1 min U^ max AC^
                            T AB                  dup1 dup1 min T^ max AB^
                            S AA                  dup1 dup1 min S^ max AA^
                            R Z                   dup1 dup1 min R^ max Z^
                            Q Y                   dup1 dup1 min Q^ max Y^
                            H P                   dup1 dup1 min H^ max P^
                            G O                   dup1 dup1 min G^ max O^
                            F N                   dup1 dup1 min F^ max N^
                            E M                   dup1 dup1 min E^ max M^
                            D L                   dup1 dup1 min D^ max L^
                            C K                   dup1 dup1 min C^ max K^
                            B J                   dup1 dup1 min B^ max J^
                            A I                   dup1 dup1 min A^ max I^
                            P AF                            min P^
                            X AE                  dup1 dup1 min X^ max AE^
                            AB AD                 dup1 dup1 min AB^ max AD^
                            T AC                  dup1 dup1 min T^ max AC^
                            V AA                  dup1 dup1 min V^ max AA^
                            W Z                   dup1 dup1 min W^ max Z^
                            R Y                   dup1 dup1 min R^ max Y^
                            S U                   dup1 dup1 min S^ max U^
                            A Q                                    max Q^
                            H O                   dup1 dup1 min H^ max O^
                            L N                   dup1 dup1 min L^ max N^
                            D M                   dup1 dup1 min D^ max M^
                            F K                   dup1 dup1 min F^ max K^
                            G J                   dup1 dup1 min G^ max J^
                            B I                   dup1 dup1 min B^ max I^
                            C E                   dup1 dup1 min C^ max E^
                            AD AE                 dup1 dup1 min AD^ max AE^
                            AA AC                 dup1 dup1 min AA^ max AC^
                            X AB                  dup1 dup1 min X^ max AB^
                            J Z                   dup1 dup1 min J^ max Z^
                            U Y                   dup1 dup1 min U^ max Y^
                            G W                   dup1 dup1 min G^ max W^
                            T V                   dup1 dup1 min T^ max V^
                            R S                   dup1 dup1 min R^ max S^
                            N O                   dup1 dup1 min N^ max O^
                            K M                   dup1 dup1 min K^ max M^
                            H L                   dup1 dup1 min H^ max L^
                            E I                   dup1 dup1 min E^ max I^
                            D F                   dup1 dup1 min D^ max F^
                            B C                   dup1 dup1 min B^ max C^
                            O AE                            min O^
                            N AD                            min N^
                            M AC                  dup1 dup1 min M^ max AC^
                            L AB                  dup1 dup1 min L^ max AB^
                            V AA                  dup1 dup1 min V^ max AA^
                            I Y                   dup1 dup1 min I^ max Y^
                            H X                   dup1 dup1 min H^ max X^
                            E U                   dup1 dup1 min E^ max U^
                            D T                   dup1 dup1 min D^ max T^
                            C S                                    max S^
                            B R                                    max R^
                            F K                   dup1 dup1 min F^ max K^
                            O AC                            min O^
                            P AB                            min P^
                            K AA                  dup1 dup1 min K^ max AA^
                            N Z                             min N^
                            W Y                   dup1 dup1 min W^ max Y^
                            L X                             min L^
                            F V                   dup1 dup1 min F^ max V^
                            I U                                    max U^
                            G S                                    max S^
                            D R                                    max R^
                            E Q                                    max Q^
                            H J                   dup1 dup1 min H^ max J^
                            P AA                            min P^
                            O Y                             min O^
                            K W                   dup1 dup1 min K^ max W^
                            J V                   dup1 dup1 min J^ max V^
                            M U                   dup1 dup1 min M^ max U^
                            L T                   dup1 dup1 min L^ max T^
                            H R                                    max R^
                            F Q                                    max Q^
                            N W                   dup1 dup1 min N^ max W^
                            O U                   dup1 dup1 min O^ max U^
                            J S                   dup1 dup1 min J^ max S^
                            L R                   dup1 dup1 min L^ max R^
                            O S                   dup1 dup1 min O^ max S^
                            N R                   dup1 dup1 min N^ max R^
                            P T min W min R min U V min S min min
                            K L max N max M Q max J max O max max
                                               dup1 dup1 max swap2 min

                            x swap2 clip"+ths                                                                                                                       : \
                                                                                                                                                                      \
        mode == "SixNN" ? "x[0,-1] x[0,1]        dup1 dup1 min swap2 max
                           x[-1,0] x[1,0]        dup1 dup1 min swap2 max
                           y z                   dup1 dup1 min swap2 max
                           swap1  swap2          dup1 dup1 min swap2 max
                           swap2  swap1  swap3   dup1 dup1 min swap2 max
                           swap1  swap4          dup1 dup1 min swap2 max
                           swap5  swap1  swap3   dup1 dup1 min swap2 max
                           swap2  swap1  swap5             min
                           swap2                 dup1 dup1 min swap2 max
                           swap4  swap1  swap3                       max
                           swap3                           min
                           swap2                                     max

                           x swap2 clip"+ths                                                                                                                        : \
                                                                                                                                                                      \
        mode == "ML3D" ? "x[1,1]    x[-1,-1]    dup1 dup1 min swap2 max
                          x[-1,1]   x[1,-1]     dup1 dup1 min swap2 max
                          x[0,0] X@ y[0,0] Y@   dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min A^

                          x[1,0]  x[0,-1]       dup1 dup1 min swap2 max
                          x[-1,0] x[0,1]        dup1 dup1 min swap2 max
                          X  Y                  dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min A

                          dup1 dup1 min swap2 max swap1 X max min"+ths                                                                                              : \
                                                                                                                                                                      \
        mode == "ML3Dex"?"x[1,1]    x[-1,-1]    dup1 dup1 min swap2 max
                          x[-1,1]   x[1,-1]     dup1 dup1 min swap2 max
                          x[0,0] X@ y[0,0] Y@   dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min A^

                          x[1,0]  x[0,-1]       dup1 dup1 min swap2 max
                          x[-1,0] x[0,1]        dup1 dup1 min swap2 max
                          X       Y             dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min  B^

                          y[1,1]  y[-1,-1]      dup1 dup1 min swap2 max
                          y[-1,1] y[1,-1]       dup1 dup1 min swap2 max
                          Y       X             dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min C^

                          y[1,0]  y[0,-1]       dup1 dup1 min swap2 max
                          y[-1,0] y[0,1]        dup1 dup1 min swap2 max
                          Y       X             dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min D^

                          X Y dup1 dup1 min swap2 max swap1 Z max min

                            A                   dup1 dup1 min swap2 max
                          B C                   dup1 dup1 min swap2 max
                          swap3  D              dup1 dup1 min swap2 max
                          swap2  swap1  swap3   dup1 dup1 min swap2 max
                          swap3                                     max
                          swap3                 dup1 dup1 min swap2 max
                          swap3                                     max
                          swap2                           min
                                                          min"+ths                                                                                                  : \
                                                                                                                                                                      \
        mode == "TL3D" ? "x[1,1]    x[-1,-1]    dup1 dup1 min swap2 max
                          x[-1,1]   x[1,-1]     dup1 dup1 min swap2 max
                          x[0,0] X@ y[0,0] Y@   dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min T^

                          x[1,0]  x[0,-1]       dup1 dup1 min swap2 max
                          x[-1,0] x[0,1]        dup1 dup1 min swap2 max
                          X       Y             dup1 dup1 min swap2 max
                          swap5  swap1  swap3   dup1 dup1 min swap2 max
                          swap3  Z              dup1 dup1 min swap2 max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap2  swap1  swap5                       max
                          swap3  swap1  swap5   dup1 dup1 min swap2 max
                          swap4  swap1  swap2   dup1 dup1 min swap2 max
                          swap3  swap1  swap2                       max
                          swap2  swap1  swap4             min
                          swap3                                     max
                          swap2                           min
                                                          min  U^

                          y[1,1]  y[-1,-1]      dup1 dup1 min B^ max K^
                          y[-1,1] y[1,-1]       dup1 dup1 min E^ max J^
                          z[1,1]  z[-1,-1]      dup1 dup1 min G^ max I^
                          z[-1,1] z[1,-1]       dup1 dup1 min D^ max H^
                          Y       Z             dup1 dup1 min C^ max F^
                          J K                   dup1 dup1 min J^ max K^
                          F H                   dup1 dup1 min F^ max H^
                          G       X             dup1 dup1 min A^ max G^
                          B E                   dup1 dup1 min B^ max E^
                          C D                   dup1 dup1 min C^ max D^
                          H J                   dup1 dup1 min H^ max J^
                          F I                   dup1 dup1 min F^ max I^
                          D G                   dup1 dup1 min D^ max G^
                          A C                                    max C^
                          G K                             min G^
                          I J                             min I^
                          D H                   dup1 dup1 min D^ max H^
                          B F                                    max F^
                          C E                   dup1 dup1 min C^ max E^
                          E I                   dup1 dup1 min E^ max I^
                          F G                   dup1 dup1 min F^ max G^
                          C D                                    max D^
                          G I                             min G^
                          E H                   dup1 dup1 min E^ max H^
                          D F                                    max F^
                          G H                             min G^
                          E F                                    max
                            G                             min V^

                          y[1,0]  y[0,-1]       dup1 dup1 min B^ max K^
                          y[-1,0] y[0,1]        dup1 dup1 min E^ max J^
                          z[1,0]  z[0,-1]       dup1 dup1 min G^ max I^
                          z[-1,0] z[0,1]        dup1 dup1 min D^ max H^
                          Y       Z             dup1 dup1 min C^ max F^
                          J K                   dup1 dup1 min J^ max K^
                          F H                   dup1 dup1 min F^ max H^
                          G       X             dup1 dup1 min A^ max G^
                          B E                   dup1 dup1 min B^ max E^
                          C D                   dup1 dup1 min C^ max D^
                          H J                   dup1 dup1 min H^ max J^
                          F I                   dup1 dup1 min F^ max I^
                          D G                   dup1 dup1 min D^ max G^
                          A C                                    max C^
                          G K                             min G^
                          I J                             min I^
                          D H                   dup1 dup1 min D^ max H^
                          B F                                    max F^
                          C E                   dup1 dup1 min C^ max E^
                          E I                   dup1 dup1 min E^ max I^
                          F G                   dup1 dup1 min F^ max G^
                          C D                                    max D^
                          G I                             min G^
                          E H                   dup1 dup1 min E^ max H^
                          D F                                    max F^
                          G H                             min G^
                          E F                                    max
                            G                             min W^


                           X Y dup1 dup1 min swap2 max swap1 Z max min

                            T                   dup1 dup1 min swap2 max
                          U V                   dup1 dup1 min swap2 max
                          swap3  W              dup1 dup1 min swap2 max
                          swap2  swap1  swap3   dup1 dup1 min swap2 max
                          swap3                                     max
                          swap3                 dup1 dup1 min swap2 max
                          swap3                                     max
                          swap2                           min
                                                          min"+ths                                                                                                  : \
                                                                                                                                                                      \
        mode == "BDM" ? "x[1,1]    x[-1,-1]    dup1 dup1 min swap2 max
                         x[-1,1]   x[1,-1]     dup1 dup1 min swap2 max
                         x[0,0] X@ y[0,0] Y@   dup1 dup1 min swap2 max
                         swap5  swap1  swap3   dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap2  swap1  swap5                       max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap4  swap1  swap2   dup1 dup1 min swap2 max
                         swap3  swap1  swap2                       max
                         swap2  swap1  swap4             min
                         swap3                                     max
                         swap2                           min
                                                         min T^

                         y[1,1]  y[-1,-1]      dup1 dup1 min B^ max K^
                         y[-1,1] y[1,-1]       dup1 dup1 min E^ max J^
                         z[1,1]  z[-1,-1]      dup1 dup1 min G^ max I^
                         z[-1,1] z[1,-1]       dup1 dup1 min D^ max H^
                         Y       Z             dup1 dup1 min C^ max F^
                         J K                   dup1 dup1 min J^ max K^
                         F H                   dup1 dup1 min F^ max H^
                         G       X             dup1 dup1 min A^ max G^
                         B E                   dup1 dup1 min B^ max E^
                         C D                   dup1 dup1 min C^ max D^
                         H J                   dup1 dup1 min H^ max J^
                         F I                   dup1 dup1 min F^ max I^
                         D G                   dup1 dup1 min D^ max G^
                         A C                                    max C^
                         G K                             min G^
                         I J                             min I^
                         D H                   dup1 dup1 min D^ max H^
                         B F                                    max F^
                         C E                   dup1 dup1 min C^ max E^
                         E I                   dup1 dup1 min E^ max I^
                         F G                   dup1 dup1 min F^ max G^
                         C D                                    max D^
                         G I                             min G^
                         E H                   dup1 dup1 min E^ max H^
                         D F                                    max F^
                         G H                             min G^
                         E F                                    max
                           G                             min U^

                         y[1,0]  y[0,-1]       dup1 dup1 min B^ max K^
                         y[-1,0] y[0,1]        dup1 dup1 min E^ max J^
                         z[1,0]  z[0,-1]       dup1 dup1 min G^ max I^
                         z[-1,0] z[0,1]        dup1 dup1 min D^ max H^
                         Y       Z             dup1 dup1 min C^ max F^
                         J K                   dup1 dup1 min J^ max K^
                         F H                   dup1 dup1 min F^ max H^
                         G       X             dup1 dup1 min A^ max G^
                         B E                   dup1 dup1 min B^ max E^
                         C D                   dup1 dup1 min C^ max D^
                         H J                   dup1 dup1 min H^ max J^
                         F I                   dup1 dup1 min F^ max I^
                         D G                   dup1 dup1 min D^ max G^
                         A C                                    max C^
                         G K                             min G^
                         I J                             min I^
                         D H                   dup1 dup1 min D^ max H^
                         B F                                    max F^
                         C E                   dup1 dup1 min C^ max E^
                         E I                   dup1 dup1 min E^ max I^
                         F G                   dup1 dup1 min F^ max G^
                         C D                                    max D^
                         G I                             min G^
                         E H                   dup1 dup1 min E^ max H^
                         D F                                    max F^
                         G H                             min G^
                         E F                                    max
                           G                             min V^

                         X Y dup1 dup1 min swap2 max swap1 Z max min

                         dup T min U min V min swap1 T max U max V max

                         dup1 dup1 min swap2 max swap1 X max min"+ths                                                                                               : \
                                                                                                                                                                      \
        mode == "MMF" ? "x[0,0]  X@ x[0,1] A@  dup1 dup1 min swap2 max
                         x[0,-1] B@ y[0,0] Y@  dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min J^

                         X x[1,0] D@           dup1 dup1 min swap2 max
                         x[-1,0]  E@ Y         dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min K^

                         x[1,1]   F@ X         dup1 dup1 min swap2 max
                         x[-1,-1] G@ Y         dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min L^

                         x[-1,1] H@ X          dup1 dup1 min swap2 max
                         x[1,-1] I@ Y          dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min M^

                         Y Z dup1 dup1 min swap2 max swap1 X max min N^
                         F G dup1 dup1 min swap2 max swap1 X max min O^
                         H I dup1 dup1 min swap2 max swap1 X max min P^
                         A B dup1 dup1 min swap2 max swap1 X max min Q^
                         D E dup1 dup1 min swap2 max swap1 X max min R^

                         J K max L max M max N max O max P max Q max R max
                         J K min L min M min N min O min P min Q min R min
                         dup1 dup1 min swap2 max swap1 X max min"+ths                                                                                               : \
                                                                                                                                                                      \
        mode == "Hybrid"?"x[0,-1] A@ x[0,1]  B@ dup1 dup1 min swap2 max
                         x[1,0] C@   x[-1,0] D@ dup1 dup1 min swap2 max
                         swap3  x[0,0] X@       dup1 dup1 min swap2 max
                         swap2  swap1  swap3    dup1 dup1 min swap2 max
                         swap3                                      max
                         swap3                  dup1 dup1 min swap2 max
                         swap3                                      max
                         swap2                            min
                                                          min J^

                         x[-1,-1] x[1,1]       dup1 dup1 min swap2 max
                         x[1,-1]  x[-1,1]      dup1 dup1 min swap2 max
                         swap3  X              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min K^

                         A B                   dup1 dup1 min swap2 max
                         C D                   dup1 dup1 min swap2 max
                         X y[0,0] Y@           dup1 dup1 min swap2 max
                         swap5  swap1  swap3   dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap2  swap1  swap5                       max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap4  swap1  swap2   dup1 dup1 min swap2 max
                         swap3  swap1  swap2                       max
                         swap2  swap1  swap4             min
                         swap3                                     max
                         swap2                           min
                                                         min L^

                         y[-1,0] y[1,0]        dup1 dup1 min swap2 max
                         z[-1,0] z[1,0]        dup1 dup1 min swap2 max
                         swap3  X              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min M^

                         y[0,-1] y[0,1]        dup1 dup1 min swap2 max
                         z[0,-1] z[0,1]        dup1 dup1 min swap2 max
                         swap3  X              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min N^

                         y[-1,-1] y[1,1]       dup1 dup1 min swap2 max
                         z[-1,-1] z[1,1]       dup1 dup1 min swap2 max
                         swap3  X              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min O^

                         y[1,-1] y[-1,1]       dup1 dup1 min swap2 max
                         z[1,-1] z[-1,1]       dup1 dup1 min swap2 max
                         swap3  X              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min

                           J                   dup1 dup1 min swap2 max
                         K L                   dup1 dup1 min swap2 max
                         M N                   dup1 dup1 min swap2 max
                         swap5  swap1  swap3   dup1 dup1 min swap2 max
                         swap3  O              dup1 dup1 min swap2 max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap2  swap1  swap5                       max
                         swap3  swap1  swap5   dup1 dup1 min swap2 max
                         swap4  swap1  swap2   dup1 dup1 min swap2 max
                         swap3  swap1  swap2                       max
                         swap2  swap1  swap4             min
                         swap3                                     max
                         swap2                           min
                                                         min"+ths                                                                                                   : \
                                                                                                                                                                      \
        mode == "PML" ? "x[0,0]  X@ x[0,1] A@  dup1 dup1 min swap2 max
                         x[0,-1] B@ y[0,0] Y@  dup1 dup1 min swap2 max
                         swap3  z[0,0] Z@      dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min J^

                         x[1,0]  C@ X          dup1 dup1 min swap2 max
                         x[-1,0] D@ Y          dup1 dup1 min swap2 max
                         swap3  Z              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min K^

                         A B                   dup1 dup1 min swap2 max
                         C D                   dup1 dup1 min swap2 max
                         swap3  X              dup1 dup1 min swap2 max
                         swap2  swap1  swap3   dup1 dup1 min swap2 max
                         swap3                                     max
                         swap3                 dup1 dup1 min swap2 max
                         swap3                                     max
                         swap2                           min
                                                         min

                         J dup1 dup1 min swap2 max swap1 K max min"+ths                                                                                             : \
                                                                                                                                                                      \
                         Assert (false, "ex_median: '"+mode+"'. Unsupported median mode.")


    temp5 = mode == "medianT5" || mode == "STWM" || mode == "GaussT5" || mode == "GaussST5" || mode == "medianSTS" || mode == "IQMT" || mode == "IQMST"
    temp  = mode == "medianT" || mode == "medianST" || mode == "ML3D" || mode == "ML3Dex" || mode == "BDM" || mode == "MMF" || mode == "PML" || \
            FindStr(mode,"DGM")>0 || mode == "unblob3D" || mode == "TL3D" || mode == "Hybrid" || mode == "SixNN" ||  temp5

    cstr = ex_UVexpr(str, UV, bi, rgb, !(UV!=3 && !fs))
    str  = ex_Yexpr (str, Y,  bi, rgb, true)

    if (temp) {

        b  =         rc ? a.selectevery(1,-1).ex_median(mode,thr,false,Y,UV) : a.selectevery(1,-1)
        f  =                                                                   a.selectevery(1,+1)
        b2 = temp5 ? rc ? b.selectevery(1,-1) :                                a.selectevery(1,-2) : nop()
        f2 = temp5 ?                                                           a.selectevery(1,+2) : nop()

       !temp5                                                                                  ? \
        isy     ? Expr(a, b,     f,     str,       optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, b,     f,     str, "",   optSingleMode = false                     ) : \
                  Expr(a, b,     f,     str, cstr, optSingleMode = false, scale_inputs="none") : \
        isy     ? Expr(a, b2, b, f, f2, str,       optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, b2, b, f, f2, str, "",   optSingleMode = false                     ) : \
                  Expr(a, b2, b, f, f2, str, cstr, optSingleMode = false, scale_inputs="none")

    } else {

        isy     ? Expr(a, str,       optSingleMode = mode == "PWM"                           ) : \
        UV == 1 ? Expr(a, str, "",   optSingleMode = mode == "PWM"                           ) : \
                  Expr(a, str, cstr, optSingleMode = mode == "PWM",       scale_inputs="none") } }




##############################
##
## Repair
##
## Replaces Repair() (only listed modes) and TemporalRepair() (which plugin seems broken)
##
##
## median    - repair(4)
## medianc   - repair(14)
## undot     - repair(1)
## undot1    - repair(1)
## undot2    - repair(2)
## undot3    - repair(3)
## undot4    - repair(4)
## undot4c   - repair(14)
## edgeSP    - repair(16). Edge sensitive with line pairs. Fair edge repair. (analogous to removegrain(6))
## edgeS     - repair(17)
## edgeW     - repair(18)
## cartoon   - repair(22)
## cartoonc  - repair(19)
## temp0     - TemporalRepair mode=0
## temp1     - TemporalRepair mode=1
## temp2     - TemporalRepair mode=2
## temp3     - TemporalRepair mode=3
## temp4     - TemporalRepair mode=4
##
## Function Definition:
##    (
##    clip a,
##    clip b,
##    string "mode"="undot2" ("median"/ "medianc"/ "undot"/ "undot2"/ "undot3"/ "edgeSP"/ "edgeS"/ "edgeW"/ "cartoon"/ "cartoonc"/ "temp0"/ "temp1"/ "temp2"/ "temp3"/ "temp4")
##    )

function ex_repair(clip a, clip b, string "mode", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    md  = Default(mode,  "undot2")
    md  = ReplaceStr(LCase(mode)," ","")
    UV  = Default(UV,    rgb ? 3 : 1)
    un  = Undefined()

    md = md == "undot0"    ? "undot"        : \
         md == "undot14"   ? "medianc"      : \
         md == "undot16"   ? "edgeSP"       : \
         md == "undot17"   ? "edgeS"        : \
         md == "undot18"   ? "edgeW"        : \
         md == "undot19"   ? "cartoonc"     : \
         md == "undot22"   ? "cartoon"      : md

    Assert(IsVersionOrGreater(3,7,2), "ex_repair: Update AviSynth+ version")

    str =                                                                                                                                                            \
                                                                                                                                                                     \
          md == "median5"? "y[-2,-2] y[-2,-1]     dup1 dup1 min W^ max Y^
                            y[-2,0]  y[-2,1]      dup1 dup1 min Q^ max X^
                            y[-2,2]  y[-1,-2]     dup1 dup1 min G^ max V^
                            y[-1,-1] y[-1,0]      dup1 dup1 min H^ max U^
                            y[-1,1]  y[-1,2]      dup1 dup1 min E^ max T^
                            y[0,-2]  y[0,-1]      dup1 dup1 min F^ max S^
                            y[0,0]   y[0,1]       dup1 dup1 min P^ max R^
                            y[0,2]   y[1,-2]      dup1 dup1 min N^ max O^
                            y[1,-1]  y[1,0]       dup1 dup1 min L^ max M^
                            y[1,1]   y[1,2]       dup1 dup1 min I^ max K^
                            y[2,-2]  y[2,-1]      dup1 dup1 min C^ max J^
                            y[2,0]   y[2,1]       dup1 dup1 min B^ max D^
                            V Y                   dup1 dup1 min V^ max Y^
                            J X                   dup1 dup1 min J^ max X^
                            G W                   dup1 dup1 min G^ max W^
                            M U                   dup1 dup1 min M^ max U^
                            D T                   dup1 dup1 min D^ max T^
                            O S                   dup1 dup1 min O^ max S^
                            K R                   dup1 dup1 min K^ max R^
                            C Q                   dup1 dup1 min C^ max Q^
                            I P                   dup1 dup1 min I^ max P^
                            F N                   dup1 dup1 min F^ max N^
                            H L                   dup1 dup1 min H^ max L^
                            B E                   dup1 dup1 min B^ max E^
                            U Y                   dup1 dup1 min U^ max Y^
                            R X                   dup1 dup1 min R^ max X^
                            L W                   dup1 dup1 min L^ max W^
                            M V                   dup1 dup1 min M^ max V^
                            S T                   dup1 dup1 min S^ max T^
                            K Q                   dup1 dup1 min K^ max Q^
                            J P                   dup1 dup1 min J^ max P^
                            D O                   dup1 dup1 min D^ max O^
                            E N                   dup1 dup1 min E^ max N^
                            C I                   dup1 dup1 min C^ max I^
                            G H                   dup1 dup1 min G^ max H^
                            B F                   dup1 dup1 min B^ max F^
                            T Y                             min T^
                            N W                   dup1 dup1 min N^ max W^
                            S V                   dup1 dup1 min S^ max V^
                            O U                   dup1 dup1 min O^ max U^
                            I R                   dup1 dup1 min I^ max R^
                            P Q                   dup1 dup1 min P^ max Q^
                            D M                   dup1 dup1 min D^ max M^
                            F L                   dup1 dup1 min F^ max L^
                            J K                   dup1 dup1 min J^ max K^
                            E H                   dup1 dup1 min E^ max H^
                            B G                   dup1 dup1 min B^ max G^
                            R W                   dup1 dup1 min R^ max W^
                            P S                   dup1 dup1 min P^ max S^
                            N Q                   dup1 dup1 min N^ max Q^
                            K y[2,2]              dup1 dup1 min A^ max K^
                            D G                   dup1 dup1 min D^ max G^
                            Q V                             min Q^
                            O R                   dup1 dup1 min O^ max R^
                            M N                   dup1 dup1 min M^ max N^
                            K L                   dup1 dup1 min K^ max L^
                            D J                   dup1 dup1 min D^ max J^
                            E G                   dup1 dup1 min E^ max G^
                            A C                   dup1 dup1 min A^ max C^
                            L U                   dup1 dup1 min L^ max U^
                            I O                   dup1 dup1 min I^ max O^
                            J N                   dup1 dup1 min J^ max N^
                            A G                   dup1 dup1 min A^ max G^
                            C F                   dup1 dup1 min C^ max F^
                            U X                             min U^
                            N Q                   dup1 dup1 min N^ max Q^
                            F P                   dup1 dup1 min F^ max P^
                            H L                   dup1 dup1 min H^ max L^
                            G K                   dup1 dup1 min G^ max K^
                            E I                   dup1 dup1 min E^ max I^
                            A B                                    max B^
                            T U                             min T^
                            L S                   dup1 dup1 min L^ max S^
                            K P                   dup1 dup1 min K^ max P^
                            H O                   dup1 dup1 min H^ max O^
                            I M                   dup1 dup1 min I^ max M^
                            F G                   dup1 dup1 min F^ max G^
                            D E                                    max E^
                            B C                                    max C^
                            S W                             min S^
                            L T                   dup1 dup1 min L^ max T^
                            P R                   dup1 dup1 min P^ max R^
                            G M                   dup1 dup1 min G^ max M^
                            H J                   dup1 dup1 min H^ max J^
                            F I                                    max I^
                            C E                                    max E^
                            Q T                             min Q^
                            R S                             min R^
                            O P                   dup1 dup1 min O^ max P^
                            L N                   dup1 dup1 min L^ max N^
                            J K                   dup1 dup1 min J^ max K^
                            E H                                    max H^
                            N R                             min N^
                            P Q                             min P^
                            L O                   dup1 dup1 min L^ max O^
                            K M                   dup1 dup1 min K^ max M^
                            I J                                    max J^
                            G H                                    max H^
                            M P                             min M^
                            N O                             min N^
                            K L                                    max L^
                            H J                                    max J^
                            M N                             min M^
                            J L                                    max L^
                            L M                   dup1 dup1 max swap2 min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
          md == "undot"  ||                                                                                                                                          \
          md == "undot1" ?  "y[-1,1] A@ y[0,1] B@ max y[1,1] C@ y[-1,0] D@ max max y[1,0] F@ y[-1,-1] G@ max y[0,-1] H@ y[1,-1] I@ max max max
                            A B min C D min min F G min H I min min min x swap2 clip"                                                                              : \
                                                                                                                                                                     \
          md == "undot2" ? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  y[0,0]         dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap8   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap8  swap1  swap3   dup1 dup1 min swap2 max
                            swap7  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap5                       max
                            swap5  swap1  swap6             min
                            swap3                           min
                            swap5                           min
                            swap4                           min
                            swap3  swap1  swap2                       max
                            swap2                           min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
          md == "undot3" ? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  y[0,0]         dup1 dup1 min swap2 max
                            swap5  swap1  swap8   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap8   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap8  swap1  swap3   dup1 dup1 min swap2 max
                            swap7  swap1  swap5   dup1 dup1 min swap2 max
                            swap4  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap5                       max
                            swap5  swap1  swap6   dup1 dup1 min swap2 max
                            swap2  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap7             min
                            swap3  swap1  swap6             min
                            swap5                                     max
                            swap3                           min
                            swap3                                     max
                            swap2                                     max
                            x swap2 swap1 clip"                                                                                                                    : \
                                                                                                                                                                     \
          md == "undot4" ||                                                                                                                                          \
          md == "median" ? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap4   dup1 dup1 min swap2 max
                            swap3  swap1  swap4   dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap2  y[0,0]         dup1 dup1 min swap2 max
                            swap5  swap1  swap8                       max
                            swap5                 dup1 dup1 min swap2 max
                            swap6  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap7  swap1  swap2                       max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap2  swap1  swap3   dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap5   dup1 dup1 min swap2 max
                            swap2  swap1  swap6             min
                            swap4  swap1  swap5                       max
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap3                           min
                            swap2                           min
                            x swap2 swap1 clip"                                                                                                                    : \
                                                                                                                                                                     \
          md == "undot4c" ||                                                                                                                                         \
          md == "medianc"? "y[-1,1] y[0,1]        dup1 dup1 min swap2 max
                            y[1,1]  y[-1,0]       dup1 dup1 min swap2 max
                            y[1,0]  y[-1,-1]      dup1 dup1 min swap2 max
                            y[0,-1] y[1,-1]       dup1 dup1 min swap2 max
                            swap7  swap1  swap3   dup1 dup1 min swap2 max
                            swap5  swap1  swap3   dup1 dup1 min swap2 max
                            swap6  swap1  swap2   dup1 dup1 min swap2 max
                            swap4  swap1  swap7   dup1 dup1 min swap2 max
                            swap3  swap1  swap2                       max
                            swap6                 dup1 dup1 min swap2 max
                            swap4  swap1  swap5   dup1 dup1 min swap2 max
                            swap3  swap1  swap2             min
                            swap4                 dup1 dup1 min swap2 max
                            swap3  swap1  swap2   dup1 dup1 min swap2 max
                            swap5  swap1  swap3             min
                            swap2  swap1  swap3                       max
                            swap2                           min
                            swap2                                     max
                            y max swap y min
                            x swap2 clip"                                                                                                                           : \
                                                                                                                                                                      \
          md=="edgeSP"   ? "y[1,-1] y[-1,1]  dup1 dup1 min A^ max B^
                            y[1,1]  y[-1,-1] dup1 dup1 min C^ max D^
                            y[0,1]  y[0,-1]  dup1 dup1 min E^ max F^
                            y[1,0]  y[-1,0]  dup1 dup1 min G^ max H^

                            y dup A B clip A@ - abs 2 * B A - + 0 range_max clip
                            y dup C D clip B@ - abs 2 * D C - + 0 range_max clip AA@ min
                            y dup E F clip C@ - abs 2 * F E - + 0 range_max clip AB@ min
                            y dup G H clip D@ - abs 2 * H G - + 0 range_max clip AC@ min BB@

                               AC == x y G min y H max clip
                            BB AA == x y C min y D max clip
                            BB AB == x y E min y F max clip
                                     x y A min y B max clip ? ? ?"                                                                                                  : \
                                                                                                                                                                      \
          md == "edgeS"  ? "y[-1,0] y[1,0]   dup1 dup1 min swap2 max
                            y[1,1]  y[-1,-1] dup1 dup1 min swap2 max
                            y[0,1]  y[0,-1]  dup1 dup1 min swap2 max
                            y[-1,1] y[1,-1]  dup1 dup1 min swap2 max
                            swap3                      max swap2 min
                            swap3 swap1 swap5          max swap3 min
                                                       min swap2 max
                                    dup1 dup1          min swap2 max
                            y max swap y min
                            x swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
          md == "edgeW"  ? "                                              y[0,0] I@ y[0,1]  B@ - abs I y[0,-1] G@ - abs max BB@
                            I y[1,1]  C@ - abs I y[-1,-1] F@ - abs max CC@ min   I  y[-1,0] D@ - abs I y[1,0]  E@ - abs max DD@ min
                            I y[-1,1] A@ - abs I y[1,-1] H@ - abs max      min
                            S@ DD == x D E dup1 dup1 min I min swap2 max I max clip  S BB == x B G dup1 dup1 min I min swap2 max I max clip
                            S  CC == x C F dup1 dup1 min I min swap2 max I max clip          x A H dup1 dup1 min I min swap2 max I max clip ? ? ?"                 : \
                                                                                                                                                                     \
          md == "cartoonc"? "y[0,0] Y@ y[1,1] - abs Y y[1,0] - abs min Y y[1,-1] - abs min Y y[-1,1] - abs min Y y[-1,0] - abs min Y y[-1,-1] - abs min Y y[0,1] - abs min Y y[0,-1] - abs min
                             DI@ Y + range_max min Y DI - 0 max x swap2 clip"                                                                                      : \
                                                                                                                                                                     \
          md == "cartoon" ? "x[0,0] X@ y[1,1] - abs X y[1,0] - abs min X y[1,-1] - abs min X y[-1,1] - abs min X y[-1,0] - abs min X y[-1,-1] - abs min X y[0,1] - abs min X y[0,-1] - abs min
                             DI@ X + range_max min X DI - 0 max y swap2 clip"                                                                                      : \
                                                                                                                                                                     \
          md == "temp0"  ? "y z max a max y z min a min x swap2 clip"                                                                                              : \
                                                                                                                                                                     \
          md == "temp1"  ? "y[-1,-1] z[-1,-1]      dup1 dup1 min swap2 max
                            x[-1,-1] dup swap3 - swap2 -
                            y[-1,0]  z[-1,0]       dup1 dup1 min swap2 max
                            x[-1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[-1,1]  z[-1,1]       dup1 dup1 min swap2 max
                            x[-1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,-1]  z[1,-1]       dup1 dup1 min swap2 max
                            x[1,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,0]  z[1,0]         dup1 dup1 min swap2 max
                            x[1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,1]  z[1,1]         dup1 dup1 min swap2 max
                            x[1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,-1]  z[0,-1]       dup1 dup1 min swap2 max
                            x[0,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,1]  z[0,1]         dup1 dup1 min swap2 max
                            x[0,1] dup swap3 - swap2 -
                            swap3 max swap2 max

                            x[0,0] + y[0,0] Y@ max z[0,0] Z@ max
                            swap x[0,0] swap - Y min Z min
                            a swap2 clip"                                                                                                                          : \
                                                                                                                                                                     \
          md == "temp2"  ? "y[-1,-1] z[-1,-1]      dup1 dup1 min swap2 max
                            x[-1,-1] dup swap3 - swap2 -
                            y[-1,0]  z[-1,0]       dup1 dup1 min swap2 max
                            x[-1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[-1,1]  z[-1,1]       dup1 dup1 min swap2 max
                            x[-1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,-1]  z[1,-1]       dup1 dup1 min swap2 max
                            x[1,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,0]  z[1,0]         dup1 dup1 min swap2 max
                            x[1,0] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[1,1]  z[1,1]         dup1 dup1 min swap2 max
                            x[1,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,-1]  z[0,-1]       dup1 dup1 min swap2 max
                            x[0,-1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,1]  z[0,1]         dup1 dup1 min swap2 max
                            x[0,1] dup swap3 - swap2 -
                            swap3 max swap2 max
                            y[0,0]  z[0,0]         dup1 dup1 min swap2 max
                            x[0,0] X@ dup swap3 - swap2 -
                            swap3 max swap2 max max
                            dup X + swap X swap - a swap2 clip"                                                                                                    : \
                                                                                                                                                                     \
          md == "temp3"  ? "x[-1,-1] A@   y[-1,-1] - abs
                            x[-1,0]  B@   y[-1,0]  - abs max
                            A             z[-1,-1] - abs
                            B             z[-1,0]  - abs max
                            x[-1,1] dup   y[-1,1]  - abs
                            swap          z[-1,1]  - abs
                            swap3 max swap2 max
                            x[1,-1] dup   y[1,-1]  - abs
                            swap          z[1,-1]  - abs
                            swap3 max swap2 max
                            x[1,0] dup    y[1,0]   - abs
                            swap          z[1,0]   - abs
                            swap3 max swap2 max
                            x[1,1] dup    y[1,1]   - abs
                            swap          z[1,1]   - abs
                            swap3 max swap2 max
                            x[0,-1] dup   y[0,-1]  - abs
                            swap          z[0,-1]  - abs
                            swap3 max swap2 max
                            x[0,1] dup    y[0,1]   - abs
                            swap          z[0,1]   - abs
                            swap3 max swap2 max
                            x[0,0] X@ dup y[0,0]   - abs
                            swap          z[0,0]   - abs
                            swap3 max swap2 max min
                            dup X + swap X swap - a swap2 clip"                                                                                                    : \
                                                                                                                                                                     \
          md == "temp4"  ? "a y z min N@ - 0 max dup + N + y z max M@ min O^
                            M dup a - 0 max dup + - N max P@
                              M == N O == or a x P O clip ?"                                                                                                       : \
                                                                                                                                                                     \
                            Assert (false, "ex_repair: "+  md+": Unsupported repair mode.")


    cstr = ex_UVexpr(str, UV, bi, rgb, un)
    str  = ex_dlut  (str, bi, un)

    if (FindStr(  md, "emp")>0) {

        c  = a.selectevery(1,-1)
        d  = a.selectevery(1,+1)

        isy     ? Expr(a, c, d, b, str,       optSingleMode = false                     ) : \
        UV == 1 ? Expr(a, c, d, b, str, "",   optSingleMode = false                     ) : \
                  Expr(a, c, d, b, str, cstr, optSingleMode = false, scale_inputs="none")

    } else {

        isy     ? Expr(a, b,       str                                                  ) : \
        UV == 1 ? Expr(a, b,       str, ""                                              ) : \
                  Expr(a, b,       str, cstr,                        scale_inputs="none") } }



##################
## MORPHOLOGICAL #
##################
##
## Opening: To clean small blotches in binary images
##   ex_inpand(n).ex_expand(n)
##
## Closing: To close gaps in binary images
##   ex_expand(n).ex_inpand(n)
##
## Smooth: Opening & Closing, effectively cleaning binary images
##   ex_inpand(n).ex_expand(n+n).ex_inpand(n)
##
## Outline: To reveal the outer edge of a shape
##   ex_makediff(ex_expand(n), a, dif=false)
##   or
##   ex_luts(mode="range+",pixels=ex_shape(n)) # faster
##   or
##   ex_hitormiss(mode="outline")              # binary only
##
## Inline: To reveal the inner edge of a shape
##   ex_makediff(a, ex_inpand(n), dif=false)
##   or
##   ex_luts(mode="range-",pixels=ex_shape(n)) # faster
##   or
##   ex_hitormiss(mode="inline")               # binary only
##
## Gradient Magnitude: To reveal the boundary/edges of elements
##   ex_makediff(ex_expand(n), ex_inpand(n), dif=false)
##   or
##   ex_edge("min/max")                        # faster
##   or
##   ex_luts(mode="range",pixels=ex_shape(n))  # faster for higher radii
##   or
##   ex_hitormiss(mode="boundary")             # binary only
##
## Top Hat:   (a - opening) To reveal bright elements (use kernel wisely) over dark backgrounds on a non-binary image
##   ex_makediff(a, ex_inpand(n).ex_expand(n), dif=false)
##
## Black Hat: (closing - a) To reveal dark elements (use kernel wisely) over bright backgrounds on a non-binary image
##   ex_makediff(ex_expand(n).ex_inpand(n), a, dif=false)
##
## Pseudomedian: (opening + closing)/2  Approximation to a simple median filter with morphological structuring elements
##   Merge(ex_inpand(n).ex_expand(n), ex_expand(n).ex_inpand(n))
##
## Contrast Enhancement: (a + Top Hat - Black Hat)  Contrast enhancement similar to an unsharp mask
##   ex_makeadddiff( ex_makediff(a, ex_inpand(n).ex_expand(n),    dif=false), \
##                   ex_makediff(   ex_expand(n).ex_inpand(n), a, dif=false), \
##                                                             a)
##   or
##   ex_lutxyz(a, ex_inpand(n).ex_expand(n), ex_expand(n).ex_inpand(n), "x y -  z x -  -  x +") # faster
##   ex_lutxyz(a, ex_inpand(n).ex_expand(n), ex_expand(n).ex_inpand(n), "x 3 * y z + -")        # prolly faster
##
## Limiting: ( max(min(a, expand), inpand) )  Limits the source to be within expand+inpand limits. Good for under/overshoots/ringing.
##   ex_logic(a,    a.ex_expand(n),"min")
##   ex_logic(last, a.ex_inpand(n),"max")
##   or
##   ex_clamp(last, a.mt_expand(n), a.mt_inpand(n))     # faster
##   or
##   ex_luts (last, a, mode="clamp",pixels=ex_shape(n)) # faster
##


# mt_expand() is 6% faster (6% slower when radius = 2)
# modes: square, circle, disk, ring, diamond, plus, cross, vertical, horizontal
#
# 'disk' is an antialiased 'circle', slower but looks better. Inspired by ImageMagick morphology shapes.
#
# 'square'            is like calling mode="vertical" then mode="horizontal"
# 'circle' + radius=2 is like calling mode="plus"     twice but faster
# 'disk'   + radius=2 is like calling mode="square",  then mode="plus" but faster
# 'disk'   + radius=3 is like calling mode="square",  then mode="plus" twice but faster
# 'disk'   + radius=3 is like calling mode="square",  then mode="circle" + radius=2 but faster
#
function ex_expand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV,    rgb ? 3 : 1)
    un   = Undefined()

    th   = ex_bs(thr, 8, bi, fulls=true)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    strh = ""    krn  = ""
    if (mode != "square" && mode != "vertical" && mode != "horizontal") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                skip = mode == "plus"    ?  px != 0 && py != 0                                        : \
                       mode == "circle"  ? (px*px + py*py) >  krnlrd*krnlrd                           : \
                       mode == "disk"    ? (px*px + py*py) > (krnlrd+0.3)*(krnlrd+0.3)                : \
                       mode == "diamond" ? (abs(px) != 0 && abs(py) != 0) &&                            \
                                           (abs(px) > krnlrd - abs(py) || abs(py) > krnlrd - abs(px)) : \
                       mode == "cross"   ? (px + py != 0) && (abs(px) != abs(py))                     : \
                       mode == "ring"    ? (px*px + py*py) > pow(krnlrd+0.3,   2) ||                    \
                                         !((px*px + py*py) > pow(krnlrd+0.3-1, 2))                    : \
                                            false
                krn = skip ? krn : Format(krn + "x[{px},{py}] max ")
       }      }
       } else {

            for (py  = -krnlrd, krnlrd, 1) {
                krn  = Format(krn  + "x[0,{py}] max ")
            }
            krnh = ""
            for (px  = -krnlrd, krnlrd, 1) {
                krnh = Format(krnh + "x[{px},0] max ")
            }
    strh = "x[0,0] " + ReplaceStr(krnh, "x[0,0] max ", "") + (thr != 255 ? Format("x[0,0] {th} + min") : "")
    }

    fbox = mode == "square" && rd == 1
    str  = "x[0,0] " + ReplaceStr(krn,  "x[0,0] max ", "")
    str  = !fbox ? str : "x[-1,1] x[0,1] max x[1,1] max x[-1,0] max x[0,0] max x[1,0] max x[-1,-1] max x[0,-1] max x[1,-1] max "
    str  = str + (thr != 255 ? Format("x[0,0] {th} + min") : "")


    isy     ? Expr(a, str                                                        ) : \
    UV == 1 ? Expr(a, str, ""                                                    ) : \
              Expr(a, str,  ex_UVexpr(str,  UV, bi, rgb, un), scale_inputs="none")

    v =       mode == "horizontal" ? a : last

    isy     ? Expr(v, strh                                                       ) : \
    UV == 1 ? Expr(v, strh, ""                                                   ) : \
              Expr(v, strh, ex_UVexpr(strh, UV, bi, rgb, un), scale_inputs="none")

    !fbox && (mode == "horizontal" || mode == "square") ? last : v               }


# mt_inpand() is 5% faster (4% slower when radius = 2)
# modes: square, circle, disk, ring, diamond, plus, cross, vertical, horizontal
function ex_inpand(clip a, int "radius", string "mode", int "thres", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd   = Default(radius, 1)
    mode = Default(mode, "square")
    thr  = Default(thres, 255)
    UV   = Default(UV,    rgb ? 3 : 1)
    un   = Undefined()

    th   = ex_bs(thr, 8, bi, fulls=true)

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    strh = ""    krn  = ""
    if (mode != "square" && mode != "vertical" && mode != "horizontal") {

    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrd, krnlrd, 1) {
                skip = mode == "plus"    ?  px != 0 && py != 0                                        : \
                       mode == "circle"  ? (px*px + py*py) >  krnlrd*krnlrd                           : \
                       mode == "disk"    ? (px*px + py*py) > (krnlrd+0.3)*(krnlrd+0.3)                : \
                       mode == "diamond" ? (abs(px) != 0 && abs(py) != 0) &&                            \
                                           (abs(px) > krnlrd - abs(py) || abs(py) > krnlrd - abs(px)) : \
                       mode == "cross"   ? (px + py != 0) && (abs(px) != abs(py))                     : \
                       mode == "ring"    ? (px*px + py*py) > pow(krnlrd+0.3,   2) ||                    \
                                         !((px*px + py*py) > pow(krnlrd+0.3-1, 2))                    : \
                                            false
                krn = skip ? krn : Format(krn + "x[{px},{py}] min ")
       }      }
       } else {

            for (py  = -krnlrd, krnlrd, 1) {
                krn  = Format(krn  + "x[0,{py}] min ")
            }
            krnh = ""
            for (px = -krnlrd, krnlrd, 1) {
                krnh = Format(krnh + "x[{px},0] min ")
            }
    strh = "x[0,0] " + ReplaceStr(krnh, "x[0,0] min ", "") + (thr != 255 ? Format("x[0,0] {th} - max") : "")
    }

    fbox = mode == "square" && rd == 1
    str  = "x[0,0] " + ReplaceStr(krn,  "x[0,0] min ", "")
    str  = !fbox ? str : "x[-1,1] x[0,1] min x[1,1] min x[-1,0] min x[0,0] min x[1,0] min x[-1,-1] min x[0,-1] min x[1,-1] min "
    str  = str + (thr != 255 ? Format("x[0,0] {th} - max") : "")

    isy     ? Expr(a, str                                                        ) : \
    UV == 1 ? Expr(a, str, ""                                                    ) : \
              Expr(a, str,  ex_UVexpr(str,  UV, bi, rgb, un), scale_inputs="none")

    v =       mode == "horizontal" ? a : last

    isy     ? Expr(v, strh                                                       ) : \
    UV == 1 ? Expr(v, strh, ""                                                   ) : \
              Expr(v, strh, ex_UVexpr(strh, UV, bi, rgb, un), scale_inputs="none")

    !fbox && (mode == "horizontal" || mode == "square") ? last : v               }


# mt_deflate() is 14% faster (lower gap with bigger radius)
# Same but faster than: ex_boxblur(1,mode="mean").ex_logic(a,"min")
function ex_deflate(clip a, int "radius", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd  = Default(radius, 1)
    UV  = Default(UV,    rgb ? 3 : 1)
    un  = Undefined()

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""    pls = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = Format(krn + "x[{px},{py}] ")
            pls = py < -krnlrd+2 && px == -krnlrd ? pls + "" : pls + "+ "
           }
       }

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(1./(krnlsz*krnlsz-1)) + " * x min"

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, un), scale_inputs="none") }


# mt_inflate() is 14% faster (lower gap with bigger radius)
# Same but faster than: ex_boxblur(1,mode="mean").ex_logic(a,"max")
function ex_inflate(clip a, int "radius", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd  = Default(radius, 1)
    UV  = Default(UV,    rgb ? 3 : 1)
    un  = Undefined()

    krnlsz = 2 * rd + 1
    krnlrd = krnlsz/2

    krn = ""    pls = ""
    for (px = -krnlrd, krnlrd, 1) {
        for (py = -krnlrd, krnlrd, 1) {
            krn = Format(krn + "x[{px},{py}] ")
            pls = py < -krnlrd+2 && px == -krnlrd ? pls + "" : pls + "+ "
           }
       }

    str = ReplaceStr(krn, Format("x[0,0] "), "") + pls + string(1./(krnlsz*krnlsz-1)) + " * x max"

    isy     ? Expr(a, str                                                      ) : \
    UV == 1 ? Expr(a, str, ""                                                  ) : \
              Expr(a, str, ex_UVexpr(str, UV, bi, rgb, un), scale_inputs="none") }



# Hit-or-Miss morphological transform (HMT)
#                  to use with binary masks
#
# modes:
# thin         - Like erode (inpand) but one pixel at a time without complete removal (leads to 'skeleton')
# thicken      - Like dilate (expand) but one pixel at a time without element merging (leads to 'SKIZ')
# prune        - To remove thin branches from the main binary element bodies
# pruneS       - Prune strong
# undot        - Prune stranded pixels
# boundary     - Get the boundary edge of the element bodies
# outline      - Get the outline  edge of the element bodies
# inline       - Get the inline   edge of the element bodies
# convexhull   - Minimal geometry representation of the element body (fills concave contours)
# convexhull45 - 45º convex hull approximation
# corner       - Detects right angle pixel corners (ie. jaggies) (WIP)
# cornerS      - Corner strong
# skeleton     - Minimal 1 pixel representation of element bodies in binary image                            (iterate 'thin' until stable -no more changes-)
# SKIZ         - Skeleton by zone of influence. Also known as background skeletonization or Voronoi diagram. (iterate 'thicken' or 'convexhull' until stable)
# end          - Extracts end pixels      (to be used after skeleton)
# junction     - Extracts junction pixels (to be used after skeleton). Also known as branched points
# 4-connected  - Extracts connected components by shared edges
# 8-connected  - Extracts connected components by a Chebyshev distance of 1
#*4x4          - Prunes everything under a 4x4 square kernel. Useful as a (binary) mask cleaner. Iterate for iterative cleaning (own code)
# fill         - (Boundary) fill element bodies (not implemented)
#
# Function Definition:
#    (
#    clip,
#    int iter=1 (1 to 50),
#    string "mode"="thin" ("thin"/ "thicken"/ "--"/ "prune"/ "pruneS"/ "undot"/ "4x4"/ "--"/ "inline"/ "outline"/ "boundary"/ "--"/ "convexhull"/ "convexhull45"/ "--"/ "end"/ "corner"/ "cornerS"/ "junction"/ "4-connected"/ "8-connected")
#    )
#
function ex_hitormiss(clip a, int "iter", string "mode", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    rd  = Default(iter,        1)
    md  = Default(mode,   "thin")
    UV  = Default(UV,    rgb ? 3 : 1)
    un  = Undefined()

    Assert(IsVersionOrGreater(3,7,2), "ex_hitormiss: Update AviSynth+ version")

    md == "thin"           || \
    md == "thicken"        || \
    md == "undot"          || \
    md == "prune"          || \
    md == "pruneS"         || \
    md == "inline"         || \
    md == "outline"        || \
    md == "boundary"       || \
    md == "convexhull"     || \
    md == "convexhull45"   || \
    md == "junction"       || \
    md == "4-connected"    || \
    md == "8-connected"    || \
    md == "4x4"            || \
    md == "end"            || \
    md == "corner"         || \
    md == "cornerS" ? nop() : \
    Assert(false, "ex_hitormiss: Unsupported mode")

    !(md == "thin" || md == "thicken" || md == "prune" || md == "pruneS" || md == "convexhull" || md == "convexhull45" || md == "4x4") ? \
    Assert(rd == 1, "ex_hitormiss: "+md+" mode only supports iter=1") : nop()

    if (rd > 1) {

        ex_hitormiss(a,   rd-1,  md, UV)
        ex_hitormiss(last,   1,  md, UV)

    } else {

        # 'thin', 'thicken', 'prune' and 'end'
        krn1 = "range_max x[-1,-1] A@ - O^ range_max  x[0,-1] B@ - P^ range_max x[1,-1] C@ - Q^
                range_max x[-1,0]  D@ - R^            x[0,0]  E^      range_max x[1,0]  F@ - T^
                range_max x[-1,1]  G@ - U^ range_max  x[0,1]  H@ - V^ range_max x[1,1]  I@ - W^ "

        # 'undot', 'inline', 'outline', 'boundary', 'pruneS', 'convexhull', 'convexhull45', 'corner', 'cornerS' 'junction', '4-connected' and '8-connected'
        krn2 = "x[-1,-1] A^ x[0,-1] B^ x[1,-1] C^
                x[-1,0]  D^ x[0,0]  E^ x[1,0]  F^
                x[-1,1]  G^ x[0,1]  H^ x[1,1]  I^ "

        # '4x4'
        krn3 = "x[-2,-2] A^ x[-1,-2] B^           x[0,-2]  C^ x[1,-2] D^ x[2,-2] E^
                x[-2,-1] F^ x[-1,-1] G^           x[0,-1]  H^ x[1,-1] I^ x[2,-1] J^
                x[-2,0]  K^ x[-1,0]  L^ range_max x[0,0] - M^ x[1,0]  N^ x[2,0]  O^
                x[-2,1]  P^ x[-1,1]  Q^           x[0,1]   R^ x[1,1]  S^ x[2,1]  T^
                x[-2,2]  U^ x[-1,2]  V^           x[0,2]   W^ x[1,2]  X^ x[2,2]  Y^ "


    # Structuring Elements
    str = md == "thin"       ?  krn1+                                                                               \
                               "O P min Q min E min G min H min I min
                                P Q min T min D min E min G min H min max
                                Q T min W min A min D min G min E min max
                                T V min W min A min D min B min E min max
                                U V min W min A min B min C min E min max
                                R U min V min B min E min C min F min max
                                O R min U min C min F min I min E min max
                                O P min R min E min H min F min I min max range_max swap - x *"                   : \
                                                                                                                    \
          md == "thicken"    ?  krn1+                                                                               \
                               "O P max Q max E max G max H max I max
                                P Q max T max D max E max G max H max min
                                Q T max W max A max D max G max E max min
                                T V max W max A max D max B max E max min
                                U V max W max A max B max C max E max min
                                R U max V max B max E max C max F max min
                                O R max U max C max F max I max E max min
                                O P max R max E max H max F max I max min range_max x - * range_max swap -"      : \
                                                                                                                   \
          md == "undot"      ?  krn2+                                                                              \
                                "A B max C max D max F max G max H max I max range_max E - max x *"              : \
                                                                                                                   \
          md == "prune"      ?  krn1+                                                                              \
                               "P Q min T min W min V min AA@ D min E min
                                R U min V min W min T min     B min E min max
                                O P min R min U min V min BB@ F min E min max
                                O R min P min Q min T min     H min E min max
                                                          AA  U min R min A min E min max
                                                          BB  T min W min C min E min max
                                                          BB  Q min T min I min E min max
                                                          AA  O min R min G min E min max range_max swap - x *"  : \
                                                                                                                   \
          md == "pruneS"     ?  krn2+                                                                              \
                               "C F max I max H max G max D max range_max E - E@ max
                                A B max I max H max G max D max           E      max min
                                A B max C max F max G max D max           E      max min
                                A B max C max F max I max H max           E      max min
                                F I max H max G max D max A max           E      max min
                                B C max H max G max D max A max           E      max min
                                B C max I max F max D max A max           E      max min
                                B C max I max F max G max H max           E      max min x *"                    : \
                                                                                                                   \
          md == "inline"     ?  krn2+"A B min C min D min E min F min G min H min I min range_max swap - x *"    : \
                                                                                                                   \
          md == "outline"    ?  krn2+"A B max C max D max E max F max G max H max I max range_max x - *"         : \
                                                                                                                   \
          md == "boundary"   ?  krn2+                                                                              \
                               "A B max C max D max E max F max G max H max I max
                                A B min C min D min E min F min G min H min I min - "                            : \
                                                                                                                   \
          md == "convexhull" ?  krn2+                                                                              \
                               "A D min G min range_max E - E@ min
                                A B min C min           E      min max
                                C F min I min           E      min max
                                G H min I min           E      min max
                                range_max swap - range_max x - * range_max swap -"                               : \
                                                                                                                   \
          md =="convexhull45"?  krn2+                                                                              \
                               "A D min G min B min range_max E - E@ min range_max I - O@ min
                                A B min C min F min           E      min range_max G - P@ min max
                                C F min I min H min           E      min range_max A - Q@ min max
                                I H min G min D min           E      min range_max C - R@ min max
                                B C min F min I min           E      min P min max
                                G H min I min F min           E      min Q min max
                                A D min G min H min           E      min R min max
                                A D min B min C min           E      min O min max
                                range_max swap - range_max x - * range_max swap - "                              : \
                                                                                                                   \
          md == "junction"   ?  krn2+                                                                              \
                               "A C min E min H min
                                B E min F min G min max
                                D E min C min I min max
                                A E min F min H min max
                                B E min G min I min max
                                D E min H min C min max
                                A E min G min F min max
                                D E min B min I min max
                                A E min I min G min max
                                A E min C min G min max
                                A E min C min I min max
                                G E min C min I min max"                                                         : \
                                                                                                                   \
          md == "4-connected"?  krn2+                                                                              \
                               "B E min
                                D E min max
                                F E min max
                                H E min max"                                                                     : \
                                                                                                                   \
          md == "8-connected"?  krn2+                                                                              \
                               "B E min
                                D E min max
                                F E min max
                                H E min max
                                A E min max
                                C E min max
                                G E min max
                                I E min max"                                                                     : \
                                                                                                                   \
          md == "4x4"        ?  krn3+                                                                              \
                               "G H max I max L max N max Q max R max S max M max

                                A B max C max D max E max F max K max P max U max
                                V max W max X max Y max J max O max T max M max min

                                P Q max R max S max N max I max D max range_max G - max min
                                F G max H max I max N max S max X max range_max Q - max min
                                B G max L max Q max R max S max T max range_max I - max min
                                I G max H max J max L max Q max V max range_max S - max min

                                A B max C max D max U max V max W max X max S max N max I max range_max L - max min
                                E B max C max D max Y max V max W max X max P max K max F max range_max N - max min

                                P Q max R max S max T max A max F max K max E max J max O max range_max H - max min
                                F G max H max I max J max K max P max U max O max T max Y max range_max R - max min x *": \
                                                                                                                   \
          md == "end"        ?  krn1+                                                                              \
                               "Q T min P min O min R min E min H min
                                Q T min W min V min P min E min D min max
                                U T min W min V min R min E min B min max
                                U P min O min V min R min E min F min max
                                O P min Q min U min R min E min I min max
                                O P min Q min W min T min E min G min max
                                Q T min W min V min U min E min A min max
                                O R min U min V min W min E min C min max"                                       : \
                                                                                                                   \
          md == "corner"     ?  krn2+                                                                              \
                               "H D max G max range_max E - E@ max range_max B - O@ max range_max F - P@ max
                                F I max H max           E      max           O      max range_max D - Q@ max min
                                B C max F max           E      max           Q      max range_max H - R@ max min
                                A B max D max           E      max           P      max               R  max min range_max swap -": \
                                                                                                                   \
          md == "cornerS"    ?  krn2+                                                                              \
                               "H D max G max range_max B - O@ max range_max F - P@ max
                                F I max H max           O      max range_max D - Q@ max min
                                B C max F max           Q      max range_max H - R@ max min
                                A B max D max           P      max           R      max min range_max swap -"    : ""

    cstr = ex_UVexpr(str, UV, bi, rgb, un)
    str  = ex_dlut  (str, bi, un)

    rd < 1  ?      a                                  : \
    isy     ? Expr(a, str                           ) : \
    UV == 1 ? Expr(a, str, ""                       ) : \
              Expr(a, str, cstr, scale_inputs="none") } }



# mt_edge() (488fps) is 16% faster (varies with kernel)
# "Canny" is a bit too complex (requires mt_hysteresis) so that's better used in a plugin (ie. vsTCanny)
# For a Ridge Detection filter check FlatMask() in MasksPack.
# RITE, SUSAN or Cumani are not implemented. Resizer based kernel derivatives aren't implemented either, read more here: https://en.wikipedia.org/wiki/Image_derivative#Hast_derivatives
#
# The typical computation for the output after the (partial) first order derivatives is to calculate the Euclidean distance sqrt(Dx^2 + Dy^2),
# but also a simply sum of absolutes is possible |Dx| + |Dy|, or even: max(|Dx|,|Dy|)
#
# Recommended: tritical/hotdog, qprewitt, kroon, frei-chen, and FDoG (slow)
#
# 31 modes:
# tritical  - (2d) Plain and simple orthogonal first order derivative
#*hotdog    - (2d) Plain and simple cross      first order derivative. Very fast yet high quality edge detection. (own derivative)
# prewitt   - (4d) Technically, a discrete differentiation operator, an approximation of the gradient magnitude in 45º increments. Optimized with partial derivatives like in all modes.
# hprewitt  - (2d) Half Prewitt
# qprewitt  - (2d) Quarter Prewitt. Same as 'hprewitt' but using Euclidean distance output. Very similar to 'prewitt' but much faster
# sobel     - (2d) The famous Sobel-Feldman operator tries to approximate gaussian first order derivatives for cleaner mask compared to prewitt
# sobel5    - (2d) Stronger sobel as appeared in LSharpAAF()
# mt_sobel  - (2d) masktools2 simplified version of the sobel operator
# pscharr   - (2d) Original simplified Scharr operator which attempts to achieve the perfect rotational symmetry with coefficients 3 and 10
# scharr    - (2d) Refined Scharr operator to more accurately calculate 1st derivatives for a 3x3 kernel with coeffs 47 and 162
# frei-chen - (2d) Isotropic version of the frei-chen operator. Better than Scharr for noisy sources. With coefficients 1 and sqrt(2) (also seen as 7 and 10 for integer calculations)
# farid     - (2d) Farid & Simoncelli 3x3 rotationally invariant derivative filter. Lightly worse than refined 'scharr'
# farid5    - (2d) Same as 'farid' but over a 5x5 kernel. There's also a 7x7 farid kernel which is almost rotation-invariant perfect, but it is slow even if in separable form
# kroon     - (2d) kroon operator with ideal coefficients 17 and 61. Better than 'farid' and slightly better than 'farid5' -> https://waynegm.github.io/OpendTect-Plugin-Docs/plugins/GradientAttrib.html
# roberts   - (1d) Roberts Cross 2x2 edge detector
# cartoon   - (1d) like 'roberts', but takes only negative edges into account
# kayyali   - (1d) kayyali SENW
# robinson  - (4d) Robinson compass mask
# kirsch    - (4d) or Kirsch compass kernel is a non-linear edge detector that finds the maximum edge strength in 45º increments. Coefficients 3 and 5
# TEdge     - Port of TEdgeMask plugin's kernel. Uses a 'plus' kernel with coefficients 12 and 74 so good for orthographic lines
# FDoG      - (2d) Flow-based Difference of Gaussians. Good for noisy sources
# DoG       - zero-cross (of the 2nd derivative) of a Difference of Gaussians. Good for noisy sources
# DoB       - zero-cross (of the 2nd derivative) of a Difference of Boxes. Good for noisy sources
# LoG       - zero-cross (of the 2nd derivative) of a Laplacian of Gaussian. Also called Marr-Hildreth detector
# laplace   - Laplace
# Std       - Standard Deviation
# min/max   - Gradient magnitude. zero-cross (of the 2nd derivative) of: (dilation - erosion)
# max       - MAE (Maximum Absolute Error)
# SG        - Savitzky-Golay (?) first derivative
# SGDD      - (2d) Savitzky-Golay Digital Differentiator cubic first derivative with 5x5 kernel
# SGDD7     - (2d) Savitzky-Golay Digital Differentiator cubic first derivative with 7x7 kernel
#
# Function Definition:
#    (
#    clip,
#    string "mode"="kroon" ("prewitt"/ "hprewitt"/ "qprewitt"/ "tritical"/ "hotdog"/ "kayyali"/ "mt_sobel"/ "sobel"/ "sobel5"/ "scharr"/ "pscharr"/ "kroon"/ "farid"/ "farid5"/ "frei-chen / "roberts"/ "robinson"/ "FDoG"/ "DoG"/ "DoB"/ "LoG"/ "SGDD"/ "SGDD7"/ "Std"/ "laplace"/ "cartoon"/ "TEdge"/ "min/max"/ "max"/ "SG"/ "kirsch"),
#    [int "lo"=10 (0 to 30)],
#    [int "hi"=150 (100 to 255)],
#    float "scale"=1.0 (0.0 to 25.0),
#    float "invert"=false
#    )

function ex_edge(clip a, string "mode", int "lo", int "hi", float "scale", bool "invert", bool "clamp_float", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    mode = Default(mode,     "kroon")
    in   = Default(invert,     false)
    UV   = Default(UV, rgb ? 3 : 128)
    cf   = Default(clamp_float, true) # Unless you are using it for error metrics, leave this at 'true'
    un   = Undefined()
    si   = ex_UVf(rgb, bi)

    th   = mode=="prewitt"   ?  [10, 100, 1.0] : \
           mode=="hprewitt"  ?  [10, 130, 1.0] : \
           mode=="qprewitt"  ?  [10, 105, 1.0] : \
           mode=="tritical"  ?  [10,  50, 1.0] : \
           mode=="hotdog"    ?  [ 5,  50, 1.0] : \
           mode=="kayyali"   ?  [20, 100, 6.0] : \
           mode=="mt_sobel"  ?  [ 5,  25, 0.5] : \
           mode=="sobel"     ?  [20, 150, 1.0] : \
           mode=="sobel5"    ?  [20, 200, 0.25]: \
           mode=="scharr"    ?  [20, 200, 1.0] : \
           mode=="pscharr"   ?  [20, 200, 1.0] : \
           mode=="kroon"     ?  [20, 200, 1.0] : \
           mode=="farid"     ?  [20, 200, 1.3] : \
           mode=="farid5"    ?  [10, 255, 0.4] : \
           mode=="frei-chen" ?  [10, 150, 1.0] : \
           mode=="roberts"   ?  [ 5,  15, 0.5] : \
           mode=="robinson"  ?  [20,  50, 1.0] : \
           mode=="FDoG"      ?  [20, 150, 1.0] : \
           mode=="DoG"       ?  [10, 100, 25.] : \
           mode=="DoB"       ?  [10, 155, 25.] : \
           mode=="LoG"       ?  [70, 125, 1.0] : \
           mode=="SGDD"      ?  [10, 255, 0.9] : \
           mode=="SGDD7"     ?  [10, 255, 0.8] : \
           mode=="Std"       ?  [10, 155, 8.0] : \
           mode=="laplace"   ?  [ 5,   6, 0.12]: \
           mode=="cartoon"   ?  [10,  20, 1.0] : \
           mode=="TEdge"     ?  [50, 255, 0.5] : \
           mode=="min/max"   ?  [10,  60, 1.0] : \
           mode=="max"       ?  [ 5,  45, 1.0] : \
           mode=="SG"        ?  [10, 165, 0.2] : \
           mode=="kirsch"    ?  [10, 150, 1.0] : \
                                [ 0, 255, 1.0]

    lo = ex_bs(Defined(lo)    ? lo    : th[0], 8, bi, fulls=true)
    hi = ex_bs(Defined(hi)    ? hi    : th[1], 8, bi, fulls=true)
    sc =       Defined(scale) ? scale : th[2]

    th  = (lo == 0) && (hi == ex_bs(255, 8, bi, fulls=true)) ? "" : Format(" {lo} - range_max {hi} {lo} - / *")
    th  = in       ? th + " range_max swap -" : th
    th  = sc != 1. ? Format(" {sc} *") + th   : th

    str =                                                                                                                                                                                              \
          mode=="prewitt"   ? "x[1,1] A^ x[1,0] B^ x[1,-1] C^ x[-1,1] D^ x[-1,0] E^ x[-1,-1] F^ x[0,1] G^ x[0,-1] H^ "                                                                                 \
                             +"A B C + + D - E - F - abs F H C + + D - G - A - abs max "                                                                                                               \
                             +"G A B + + F - H - E - abs B H C + + E - G - D - abs max max "+th                                                                                                      : \
                                                                                                                                                                                                       \
          mode=="hprewitt"  ? "x[1,1] A@ x[1,-1] C@ + x[-1,1] D@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 2 * + abs "                                                                                          \
                             +"F C + D - A - x[0,-1] x[0,1] - 2 * + abs max "+th                                                                                                                     : \
                                                                                                                                                                                                       \
          mode=="qprewitt"  ? "x[-1,-1] A@ x[-1,0] x[-1,1] F@ + + x[1,-1] C@ - x[1,0] - x[1,1] H@ - dup * "                                                                                            \
                             +"A C x[0,-1] + + F - H - x[0,1] - dup * + sqrt "+th                                                                                                                    : \
                                                                                                                                                                                                       \
          mode=="mt_sobel"  ? "x[1,0] x[0,1] + x[-1,0] - x[0,-1] - abs "+th                                                                                                                          : \
                                                                                                                                                                                                       \
          mode=="tritical"  ? "x[0,-1]  x[0,1] - dup * x[1,0]  x[-1,0] - dup * + sqrt "+th                                                                                                           : \
                                                                                                                                                                                                       \
          mode=="hotdog"    ? "x[-1,-1] x[1,1] - dup * x[-1,1] x[1,-1] - dup * + sqrt "+th                                                                                                           : \
                                                                                                                                                                                                       \
          mode=="kayyali"   ? "x[-1,1] x[1,-1] x[-1,-1] x[1,1] + - + "+th                                                                                                                            : \
                                                                                                                                                                                                       \
          mode=="sobel"     ? "x[1,-1] C@ x[1,1] I@ + x[-1,-1] A@ - x[-1,1] G@ - x[1,0] x[-1,0] - 2 * + dup * "                                                                                        \
                             +"G I + A - C - x[0,1] x[0,-1] - 2 * + dup * + sqrt "+th                                                                                                                : \
                                                                                                                                                                                                       \
          mode=="sobel5"    ? "x[-1,-1] 5 * A^ x[0,-1] 10 * B^ x[1,-1] 5 * C^ x[-1,0] 10 * D^ x[1,0] 10 * E^ x[-1,1] 5 * F^ x[0,1] 10 * G^ x[1,1] 5 * H^ "                                             \
                             +"A D F + + C - E - H - abs A B C + + F - G - H - abs max "+th                                                                                                          : \
                                                                                                                                                                                                       \
          mode=="pscharr"   ? "x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 3.333333333 * + dup * "                                                                              \
                             +"F H + C - A - x[0,-1] x[0,1] - 3.333333333 * + dup * + sqrt "+th                                                                                                      : \
                                                                                                                                                                                                       \
          mode=="scharr"    ? "x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 3.446808511 * + dup * "                                                                              \
                             +"F H + C - A - x[0,-1] x[0,1] - 3.446808511 * + dup * + sqrt "+th                                                                                                      : \
                                                                                                                                                                                                       \
          mode=="kroon"     ? "x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 3.588235294 * + dup * "                                                                              \
                             +"F H + C - A - x[0,-1] x[0,1] - 3.588235294 * + dup * + sqrt "+th                                                                                                      : \
                                                                                                                                                                                                       \
          mode=="frei-chen" ? "x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 1.414213562 * + dup * "                                                                              \
                             +"F H + C - A - x[0,-1] x[0,1] - 1.414213562 * + dup * + sqrt "+th                                                                                                      : \
                                                                                                                                                                                                       \
          mode=="farid"     ? "x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 2.350114638 * + dup * "                                                                              \
                             +"F H + C - A - x[0,-1] x[0,1] - 2.350114638 * + dup * + sqrt "+th                                                                                                      : \
                                                                                                                                                                                                       \
          mode=="farid5"    ? "x[-2,2] U@ x[2,2] Y@ + x[-2,-2] A@ x[2,-2] E@ + - 0.146281347 * x[-1,2] V@ x[1,2] X@ + x[-1,-2] B@ x[1,-2] D@ + - + x[0,2] W@ x[0,-2] C@ - 1.723956832 * + "            \
                             +"x[-2,1] P@ x[2,1] T@ + x[-2,-1] F@ x[2,-1] J@ + - 0.378273063 * + x[-1,1] Q@ x[1,1] S@ + x[-1,-1] G@ x[1,-1] I@ + - 2.5859245045 * + x[0,1] R@ x[0,-1] H@ - 4.458022103 * + dup * "\
                             +"x[2,0] x[-2,0] - 1.723956832 * x[1,0] x[-1,0] - 4.458022103 * + E Y + U A + - 0.146281347 * + J T + P F + - + I S + Q G + - 2.585924504 * + D X + V B + - 0.378273063 * + dup * + sqrt "+th: \
                                                                                                                                                                                                       \
          mode=="SGDD"      ? "x[0,1] x[0,-1] - 8 * x[0,-2] x[0,2] - + dup * x[1,0] x[-1,0] - 8 * x[-2,0] x[2,0] - + dup * + sqrt "+th                                                               : \
                                                                                                                                                                                                       \
          mode=="SGDD7"     ? "x[0,1] x[0,-1] - 2.636363 * x[0,2] x[0,-2] - 3.045454 * x[0,-3] x[0,3] - + + dup * "                                                                                    \
                             +"x[1,0] x[-1,0] - 2.636363 * x[2,0] x[-2,0] - 3.045454 * x[0,-3] x[0,3] - + + dup * + sqrt "+th                                                                        : \
                                                                                                                                                                                                       \
          mode=="roberts"   ? "x[0,0] 2 * x[1,0] - x[0,1] - abs "+th                                                                                                                                 : \
                                                                                                                                                                                                       \
          mode=="robinson"  ? "x[-1,1] A^ x[0,1] B^ x[1,1] C^ x[-1,0] D^ x[1,0] E^ x[-1,-1] F^ x[0,-1] G^ x[1,-1] H^ "                                                                                 \
                             +"C A - D 2 * - E 2 * + F - H + abs B C 2 * + D - E + F 2 * - G - abs max A B 2 * + C + F - G 2 * - H - abs A 2 * B + D + E - G - H 2 * - abs max max "+th              : \
                                                                                                                                                                                                       \
          mode=="FDoG"      ? "x[-2,2] A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] E^ x[-2,1] F^ x[-1,1] 2 * G^ x[0,1] H^ x[1,1] 2 * I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                                 \
                             +"x[1,0] N^ x[2,0] O^ x[-2,-1] P^ x[-1,-1] 2 * Q^ x[0,-1] R^ x[1,-1] 2 * S^ x[2,-1] T^ x[-2,-2] U^ x[-1,-2] V^ x[0,-2] W^ x[1,-2] X^ x[2,-2] Y^ "                         \
                             +"A B Q U V G + + + + + D E I S X Y + + + + + - F P + J T + - 2 * + K L + N O + - 3 * + 0.5 * dup * "                                                                     \
                             +"Y P Q U S T + + + + + F G I J A E + + + + + - X V + B D + - 2 * + R W + H C + - 3 * + 0.5 * dup * + sqrt "+th                                                         : \
                                                                                                                                                                                                       \
          mode=="DoG"       ? "x[0,0] A^ x[0,1] B^ x[-1,0] C^ x[1,0] D^ x[0,-1] E^ x[0,2] F^ x[0,-2] G^ x[2,0] H^ x[-2,0] I^ x[-1,1] J^ x[-1,-1] K^ x[1,1] L^ x[1,-1] M^ "                             \
                             +"F G H I J K L M + + + + + + + B C D E A 2 * + + + + Z@ 2 * + 0.05 * Z 0.166666666 * - "+th                                                                            : \
                                                                                                                                                                                                       \
          mode=="DoB"       ? "x[-1,1] x[0,1] x[1,1] x[-1,0] x[0,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + + Z@ "                                                                               \
                             +"x[-2,2] x[-1,2] x[0,2] x[1,2] x[2,2] x[-2,1] x[2,1] x[-2,0] x[2,0] x[-2,-1] x[2,-1] x[-2,-2] x[-1,-2] x[0,-2] x[1,-2] x[2,-2] + + + + + + + + + + + + + + + + 0.04 * "  \
                             +"Z 0.111111111 * - "+th                                                                                                                                                : \
                                                                                                                                                                                                       \
          mode=="LoG"       ? "x[0,2] x[0,-2] x[2,0] x[-2,0] x[-1,1] x[-1,-1] x[1,1] x[1,-1] + + + + + + + x[0,1] x[0,-1] x[1,0] x[-1,0] + + + 2 * + x[0,0] 16 * - "+th                              : \
                                                                                                                                                                                                       \
          mode=="laplace"   ? "x[-1,1] x[0,1] x[1,1] x[-1,0] x[1,0] x[-1,-1] x[0,-1] x[1,-1] + + + + + + + x[0,0] 8 * - abs "+th                                                                     : \
                                                                                                                                                                                                       \
          mode=="cartoon"   ? "x[1,-1] x[0,-1] 2 * - x[0,0] + "+th                                                                                                                                   : \
                                                                                                                                                                                                       \
          mode=="TEdge"     ? "x[-2,0] x[1,0] x[-1,0] - 6.166666666 * + x[2,0] - 2 * dup * x[0,-2] x[0,1] x[0,-1] - 6.166666666 * + x[0,2] - 2 * dup * + sqrt "+th                                   : \
                                                                                                                                                                                                       \
          mode=="min/max"   ? "x[1,1] A@ x[1,0] B@ max x[1,-1] C@ max x[-1,1] D@ max x[-1,0] E@ max x[-1,-1] F@ max x[0,1] G@ max x[0,-1] H@ max x[0,0] O@ max "                                       \
                             +"A B min C min G min O min H min D min E min F min - "+th                                                                                                              : \
                                                                                                                                                                                                       \
          mode=="max"       ? "x[0,0] O@ x[1,1] - abs O x[1,0] - abs max O x[1,-1] - abs max O x[-1,1] - abs max O x[-1,0] - abs max O x[-1,-1] - abs max O x[0,1] - abs max O x[0,-1] - abs max "+th: \
                                                                                                                                                                                                       \
          mode=="kirsch"    ? "x[-1,1] A@ 1.666666666 * R^ x[0,1] B@ 1.666666666 * S^ x[1,1] C@ 1.666666666 * T^ x[-1,0] D@ 1.666666666 * U^ "                                                         \
                             +"x[1,0] E@ 1.666666666 * V^ x[-1,-1] F@ 1.666666666 * X^ x[0,-1] G@ 1.666666666 * Y^ x[1,-1] H@ 1.666666666 * Z^ "                                                       \
                             +"R S T + + D - E - F - G - H -     R S U + + C - E - F - G - H - max R U X + + B - C - E - G - H - max U X Y + + A - B - C - E - H - max "                               \
                             +"X Y Z + + A - B - C - D - E - max V Y Z + + A - B - C - D - F - max T V Z + + A - B - D - F - G - max S T V + + A - D - F - G - H - max "+th                          : \
                                                                                                                                                                                                       \
          mode=="SG"        ? "x[-2,2] 2 * A^ x[-1,2] B^ x[0,2] C^ x[1,2] D^ x[2,2] 2 * E^ x[-2,1] F^ x[-1,1] G^ x[0,1] H^ x[1,1] I^ x[2,1] J^ x[-2,0] K^ x[-1,0] L^ "                                 \
                             +"x[1,0] M^ x[2,0] N^ x[-2,-1] O^ x[-1,-1] P^ x[0,-1] Q^ x[1,-1] R^ x[2,-1] S^ x[-2,-2] 2 * T^ x[-1,-2] U^ x[0,-2] V^ x[1,-2] X^ x[2,-2] 2 * Y^ "                         \
                             +"F K O + + 2 * A T B G L P U + + + + + + + D - I - M - R - X - E - Y - J N S + + 2 * - abs "                                                                             \
                             +"B C D + + 2 * A E F G H I J + + + + + + + O - P - Q - R - S - T - Y - U V X + + 2 * - abs max "+th                                                                    : \
                                                                                                                                                                                                       \
          mode=="Std"       ? "x[1,1] A@ x[1,0] B@ x[1,-1] C@ x[-1,1] D@ x[-1,0] E@ x[-1,-1] F@ x[0,1] G@ x[0,-1] H@ + + + + + + + 0.125 * J@ "                                                        \
                             +"A - dup * B J - dup * C J - dup * D J - dup * E J - dup * F J - dup * G J - dup * H J - dup * + + + + + + + 0.125 * sqrt "+th                                         : \
                                                                                                                                                                                                       \
                             mode+th

    cstr = ex_UVexpr(str, UV, bi, rgb, un, si)
    str  = ex_dlut  (str, bi, un)

    isy     ? Expr(a, str                       ,clamp_float=cf) : \
    UV == 1 ? Expr(a, str, ""                   ,clamp_float=cf) : \
              Expr(a, str, cstr, scale_inputs=si,clamp_float=cf)
              prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
              propDelete(UV<4?prop:ArrayAdd(prop,"_ChromaLocation"))
              propSet("_ColorRange", 0)                            }








###
### Performs declared expression with 'mode' mode from clip 'a' to neighbour pixels defined in 'pixels' of clip 'b' (or 'a' if 'b' is undefined)
### In other words, it's like a do-it-all powerhorse convolution filter whereas otherwise would take several calls and a performance penalty.
###
### !! Beware, don't write variables in the expressions with capital letters (ie. A@), unless you want to call X or Y in 'exprf'
###    use instead lower case preceded with underscore (ie. _var@)
###
### Some examples:
###   ex_luts(mode="med",pixels=ex_shape(3))  -> ex_median("median7")
###   ex_luts(mode="avg",pixels=ex_shape(3))  -> ex_boxblur(3,mode="mean")
###   ex_luts(mode="avg",exprf="x max")       -> ex_boxblur(1,mode="mean").ex_logic(a,"max") -> ex_inflate()
###   ex_luts(mode="avg",exprf="x min")       -> ex_boxblur(1,mode="mean").ex_logic(a,"min") -> ex_deflate()
###   ex_luts(mode="max",pixels=ex_shape(2))  -> ex_expand(2)
###   ex_luts(mode="min",pixels=ex_shape(2))  -> ex_inpand(2)
###   ex_luts(mode="rng",pixels=ex_shape(1))  -> ex_edge(mode="min/max")
###   ex_luts(a,ex_blur(),mode="clp")         -> ex_clamp(a,ex_blur().ex_expand(),ex_blur().ex_inpand())
###   px=ex_shape(3,mode="disk",type="array")
###   ex_luts(mode="avg",pixels=px[0], exprf=" X^ "+sel_med(px[1])) -> Trimmed mean with custom kernel shape
###
### For more check Morphological examples above at line: 6180
###
### Function Definition:
###    (
###    clip a,
###    clip b,
###    string "mode"="avg" ("average"/ "median"/ "--"/ "min"/ "max"/ "minmax"/ "--"/ "boundary"/ "inline"/ "outline"/ "--"/ "clamp"/ "stdev"),
###    [string "pixels"="-1 -1 0 -1 1 -1 -1 0 0 0 1 0 -1 1 0 1 1 1"]
###    )
###
### Preset:
###    ex_luts(mode="avg", pixels=ex_shape(1,mode="square",center=true))
###
function ex_luts(clip a, clip "b", string "expr", string "exprc", string "exprf", string "mode", string "pixels", int "Y", int "UV", string "scale_inputs", bool "clamp_float", bool "optSingleMode", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    isb  = Defined(b)
    isc  = Defined(exprc)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb

    str  = Default(expr,       " y ")
    exprf= Default(exprf,         "")
    px   = Default(pixels,ex_shape())
    md   = Default(mode,       "avg")
    md   = ReplaceStr(md, " ",    "")
    Y    = Default(Y,              3)
    fs   = Default(fulls,  fs)
    opt  = Default(optSingleMode,false)
    cf   = Default(clamp_float,  false)
    si   = Default(scale_inputs, ex_UVf(rgb, bi))

    md = md == "average"   ? "avg"          : \
         md == "mean"      ? "avg"          : \
         md == "maximum"   ? "max"          : \
         md == "minimum"   ? "min"          : \
         md == "clamp"     ? "clp"          : \
         md == "clip"      ? "clp"          : \
         md == "boundary"  ? "rng"          : \
         md == "range"     ? "rng"          : \
         md == "range-"    ? "rngmin"       : \
         md == "rng-"      ? "rngmin"       : \
         md == "range+"    ? "rngmax"       : \
         md == "rng+"      ? "rngmax"       : \
         md == "min/max"   ? "rng"          : \
         md == "min+max"   ? "minmax"       : \
         md == "minmax"    ? "minmax"       : \
         md == "inline"    ? "rngmin"       : \
         md == "outline"   ? "rngmax"       : \
         md == "stdev"     ? "std"          : \
         md == "standard deviation" ? "std" : \
         md == "median"    ? "med"          : md

    op = md == "avg"       ? " + "          : \
         md == "max"       ? " max "        : \
         md == "min"       ? " min "        : \
         md == "clp"       ? " max "        : \
         md == "minmax"    ? " max "        : \
         md == "rng"       ? " max "        : \
         md == "rngmin"    ? " min "        : \
         md == "rngmax"    ? " max "        : \
         md == "std"       ? " XX - dup * " : \
         md == "med"       ? ""             : \
         Assert(false, "ex_luts: '"+md+"', unsupported mode.")

    msk  = FindStr(md, "rng") > 0 || md == "std"
    UV   = Default(UV, rgb ? 3 : isc ? 3 : msk ? 128 : 1)

    nul = px == ""
    px  = FindStr(px,"[") != 0 ? px : nul ? "" : pixel_parser(px)
    px0 = FindStr(px,"x[0,0]") == 0

    in  = FindStrInstance(px, "^")
    med = md == "med" ? sel_med(in) : ""
    med = isb ? ReplaceStr(med,  "X swap2", "Y swap2") : px0 ? ReplaceStr(med, "X swap2", "x swap2") : med


    vars = "A B C D E F G H I J K L M N O P Q R S T U V W Z " \
          +"AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWYYZZ"

    px  = isb  ? ReplaceStr(" "+px+" ",  " x[", " y[")       : px
    px  = isb  ? ReplaceStr(    px,  " y[0,0] ", " x[0,0] ") : px
    px  = isb  ?       px + " y[0,0] Y^ "                    : px
    px  = isb && px0 ? px + " x[0,0] X^ "                    : px
    nex = ReplaceStr(str,  " ", "") == "y"
    str = px0  ? str : ReplaceStr(LCase(" "+str+" "),  " x ", " X ")

    V = "" expr="" exprS="X"
    len = px0 ? in : in-1
    for (i = 0, len-1, 1) {

        V     = ReplaceStr(MidStr(vars,i==0 ? 1 : i*2+1,2), " ", "")
        exprS = md == "std" ? exprS + " " + V + " " + " + " : " "
        expr  = expr + ReplaceStr(" "+str+" ",  " y ", " "+V+" ") + (md == "med" ? V+"^ " : \
                                                                     md == "std" ? i==0 ? op : op+" + " : i==0 ? " " : op)
                }

        exprY = isb  ? ReplaceStr(" "+str+" ",  " y ",     " Y ") + (md == "med" ? "Y^ "          : \
                                                                     md == "std" ? op+" + " : op) : " "
        exprX = !px0 ? ReplaceStr(" "+str+" ",  " y ",     " X ") + (md == "med" ? "X^ "          : \
                                                                     md == "std" ? op+" + " : op) : " "

        exprS = exprS + string(1./in) + " * XX^ " + expr + exprY + exprX
        exprM = nex ? " "                         : expr + exprY + exprX

    expr = md == "clp"    ? px + " x " + expr + exprY + " min " + ReplaceStr(expr      +exprY, "max", "min") + " max "    + exprf : \
           md == "minmax" ? px + expr + exprY +                   ReplaceStr(expr      +exprY, "max", "min") + " + 0.5 *" + exprf : \
           md == "rng"    ? px + expr + exprY + exprX           + ReplaceStr(expr+exprX+exprY, "max", "min") + " - "      + exprf : \
           md == "rngmin" ? px + expr + exprY + exprX + " X swap - "                                                      + exprf : \
           md == "rngmax" ? px + expr + exprY + exprX + " X  - "                                                          + exprf : \
           md == "avg"    ? px + expr + exprY + exprX + string(1./in) + " * "                                             + exprf : \
           md == "std"    ? px + exprS                + string(1./in) + " * sqrt "                                        + exprf : \
           md == "med"    ? px + exprM                + med                                                               + exprf : \
                            px + expr + exprY + exprX                                                                     + exprf

    expr = ReplaceStr(expr, "  ", " ")

    str  =                           ex_Yexpr (expr,  Y, bi, rgb, fs, si)
    cstr = rgb ? str : isc ? exprc : ex_UVexpr(expr, UV, bi, rgb, fs, si, isc)

    nul     ?       a                                                                     : \
    isb     ?                                                                               \
    isy     ?  Expr(a, b, str,      optSingleMode = opt, scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a, b, str, "",  optSingleMode = opt, scale_inputs=si, clamp_float=cf) : \
               Expr(a, b, str, cstr,optSingleMode = opt, scale_inputs=si, clamp_float=cf) : \
    isy     ?  Expr(a,    str,      optSingleMode = opt, scale_inputs=si, clamp_float=cf) : \
    UV == 1 ?  Expr(a,    str, "",  optSingleMode = opt, scale_inputs=si, clamp_float=cf) : \
               Expr(a,    str, cstr,optSingleMode = opt, scale_inputs=si, clamp_float=cf)
    if (msk) {
              prop = ["_Matrix","_Primaries","_Transfer","_PictType"]
              propDelete(UV<5?prop:ArrayAdd(prop,"_ChromaLocation"))}

    fs||msk ? propSet("_ColorRange", 0) : last  }



### Outputs a string with the kernel shape in 'mode'
###
### Maximum pixel fetches based on isotropic radius:
### Square:                           3 (49) 2 (25) 1 (9)
### Diamond:                   4 (41) 3 (25) 2 (13) 1 (5)
### Circle:                    4 (49) 3 (29) 2 (13) 1 (5)
### Disk:                             3 (37) 2 (21) 1 (5)
### Ring:        6 (32) 5 (28) 4 (24) 3 (16) 2 (16) 1 (4) (center=false)
### Cross:       8 (33)
### Plus:        8 (33)
### Horizontal: 16 (33)
### Vertical:   16 (33)
###
### Function Definition:
###    (
###    clip,
###    int rad=1 (0 to 8),
###    [int radV=1 (0 to 8)],
###    string "mode"="square" ("square"/ "diamond"/ "circle"/ "disk"/ "ring"/ "cross"/ "plus"/ "horizontal"/ "vertical"),
###    bool "center"=true
###    )
###
function ex_shape(int "rad", int "radV", string "mode", bool "center", bool "pop", string "type") {

    rd = Default(rad,             1)  # integers from 0 to 4 or 8 (see above)
    rv = Default(radV,           rd)  # integers from 0 to 4 or 8 (see above)
    md = Default(mode,     "square")
    md = ReplaceStr(md,     " ", "")
    cn = Default(center, md!="ring")
    pp = Default(pop,          true)  # Pop out the variable or keep in stack
    ou = Default(type,     "string")  # Output a "string" with kernel shape, or an "array" with the string and the pixel fetching number

    # Soft limit
    lim = md == "plus"       ? rd + rv > 16 : \
          md == "cross"      ? rd + rv > 16 : \
          md == "horizontal" ? rd>8 || rv>8 : \
          md == "vertical"   ? rd>8 || rv>8 : false

          Assert (!lim, "ex_shape: "+string(max(rd,rv))+": Maximum radius length reached for '"+md+"' mode.")

    krnlsz = ceil(2 * rd) + 1
    krnlsv = ceil(2 * rv) + 1
    krnlrd = krnlsz/2
    krnlrv = krnlsv/2

    # 49 vars (X, Y and XX reserved)
    vars = "A B C D E F G H I J K L M N O P Q R S T U V W Z " \
          +"AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWYYZZ"


    mode = md == "square"  ? """
                            skip  =  false """                                       : \
           md == "diamond" ? """
                            skip  = (abs(px)  != 0 && abs(py) != 0) &&                 \
                                    (abs(pxr) > rtm - abs(pyr) ||                      \
                                     abs(pyr) > rtm - abs(pxr)) """                  : \
           md == "circle"  ? """
                            skip  = (pxr*pxr + pyr*pyr) > rtm*rtm """                : \
           md == "disk"   ? """
                            skip  = (pxr*pxr + pyr*pyr) > pow(rtm+0.3,   2) """      : \
           md == "ring"   ? """
                            skipo = (pxr*pxr + pyr*pyr) > pow(rtm+0.3,   2)
                            skipi = (pxr*pxr + pyr*pyr) > pow(rtm+0.3-1, 2)
                            skip  = skipo || !skipi """                              : \
           md == "plus"   ? """
                            skip  =  px != 0 && py != 0 """                          : \
           md == "cross"  ? """
                            skipo = round(abs(pxr))/(round(abs(pyr))+0.001)
                            skipi = round(abs(pyr))/(round(abs(pxr))+0.001)
                            skip  = skipo != skipi  """                              : \
           md == "horizontal" ? """
                            skip  =  py != 0 """                                     : \
           md == "vertical" ?  """
                            skip  =  px != 0 """                                     : ""

    rtm =            min(krnlrd,krnlrv)
    rt  = float(rtm)/max(krnlrd,krnlrv)
    rty = krnlrd > krnlrv ? 1 : rt
    rtx = krnlrv > krnlrd ? 1 : rt
    pop = pp ? "^" : "@"

    # x[0,0] is always "X^" or "X@"
    krn = "" V = "" pos=1
    for (px = -krnlrd, krnlrd, 1) {
            for (py = -krnlrv, krnlrv, 1) {
                pxr   = px * rtx
                pyr   = py * rty
                Eval(mode)
                cnt  = abs(px) + abs(py) == 0
                skip = skip || (!cn ? cnt : false)
                pos  = skip ? pos : cnt ? max(pos,0) : pos+2
                V    = cnt ? "X " : MidStr(vars,max(pos-2,1),2)
                krn  = skip ? krn : Format(krn + "x[{px},{py}] " + V + pop+" ")
       }      }

    krn = md == "ring" && cn ? krn+" x[0,0] X"+pop+" " : krn

    # Hard limit
    pxc = FindStrInstance(krn, pop)
          Assert( pxc < 51, "ex_shape: "+string(pxc)+": Maximum pixel fetching count reached for '"+md+"' mode.")

    str = ReplaceStr(krn,  " "+pop, pop)

    return ou == "string" ? str : [str,pxc] }







######### HELPER FUNCTIONS #########


function clamp(val a, val mn, val mx) {
    Assert(isFloat(a) && isFloat(mn) && isFloat(mx), "clamp(): Not a number, revise")
    return min(max(a,mn),mx) }


function isRunTime(clip a, bool rgb) {
    try {
      iRT = rgb ? a.AverageR() : a.AverageLuma()
      iRT = true
    } catch ( error_msg ) {
      iRT = false
    }
    return iRT }


function DivideStr(string str, string separator) {

    Sep   = FindStr(str, separator)
    Left  = Sep == 0 ?  "" : LeftStr (str, Sep-1)
    Right = Sep == 0 ? str : RightStr(str, StrLen(str)-Sep)

    return [Left, Right] }


function FindStrInstance(string haystack, string needle) {

    pos = 1 in = 0
    while (pos > 0) {
        pos      = FindStr (haystack, needle)
        haystack = RightStr(haystack, StrLen(haystack)-pos)
        in       = pos != 0 ? in + 1 : in
    }
    return in }



# Parses a string of pixel pairs in masktools2/mt_luts() format to Expr() Pixel Addressing format
# ie: " 1 -1  1  0 0 0 -2 0 " -> "x[1,-1] A^ x[1,0] B^ x[-2,0] C^ x[0,0] X^ "
function pixel_parser(string str) {

    # Cleanup
    str = ReplaceStr(str, ",", "")
    str = ReplaceStr(str, " ", "")
    len = StrLen(str)

    vars = "A B C D E F G H I J K L M N O P Q R S T U V W Z " \
          +"AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSSTTUUVVWWYYZZ"

    # Extract X
    for (i = 1, len, 2) {

        sgn1 = MidStr(str,i,1) == "-"
        sgn2 = (sgn1 ? MidStr(str,i+2,1) : MidStr(str,i+1,1)) == "-"

        pos  = sgn1 ? i+1 : i
        cpx  = MidStr(str,pos,2) == "00"
        i = cpx ? len : sgn2 ? pos+1 : pos
    }

    str = cpx ? LeftStr(str, pos-1)+RightStr(str, len-pos-1) : str
    len = cpx ? len-2 : len

    # Parse
    px = ""  u = 1
    for (i = 1, len, 2) {

        sap1 =        MidStr(str,i,1)
        sgn1 = sap1 == "-"
        sap2 = sgn1 ? MidStr(str,min(len,i+2),1) : MidStr(str,min(len,i+1),1)
        sgn2 = sap2 == "-"
        val1 = sgn1 ? MidStr(str,i,2) : sap1
        val2 = sgn2 ? sgn1 ? MidStr(str,min(len,i+2),2) : MidStr(str,min(len,i+1),2) : sap2
        px   = px + " x["+val1+","+val2+"] " + MidStr(vars,clamp(u,1,len),2) + "^ "
        i    = sgn1 ? sgn2 ? i+2 : i+1 : sgn2 ? i+1 : i+0
        u    = u + 2
    }

    px = ReplaceStr(px,  " ^",  "^")
    px = cpx ? px + " x[0,0] X^ " : px

    return px }


function ex_UVexpr(string "str", int "UV", int "bits", bool "rgb", bool "fulls", string "scale_inputs", bool "defined") {

    str = Default(str, "")
    UV  = Default(UV,   1)
    bi  = Default(bits, 8)
    rgb = Default(rgb,    false)
    def = Default(defined,false)        # Whether 'cstr' is defined or not to do chroma auto-shift for 32-bit
    fs  = Default(fulls, rgb)
    si  = Default(scale_inputs, "none") # Whether expression is scaled or not (should be compared against bitdepth decorators)
    si  = LCase(si)

    if (si!="none" && si!="floatUV") {

        str5 = LeftStr(str,5)

        bc   = UV!=3                 ? -1 : \
               FindStr(str5,"f32")>0 ? 32 : \
               FindStr(str5,"i16")>0 ? 16 : \
               FindStr(str5,"i14")>0 ? 14 : \
               FindStr(str5,"i12")>0 ? 12 : \
               FindStr(str5,"i10")>0 ? 10 : \
               FindStr(str5,"i8" )>0 ?  8 : -1

        bi   = FindStr(si, "int"  )>0 && bi!=32 ? max(8,bc) : \
                       si=="float"    && bi==32 ? max(8,bc) : \
                       si=="floatf"   && bi==32 ? max(8,bc) : \
               FindStr(si, "all"  )>0           ? max(8,bc) : bi
    }

    # Shifting/Centering expression automatically when UV==3 + cstr is not defined + input bitdepth is 32-bit float
    off = bi==32 && si!="floatUV" && !rgb
    pos = off && !def && UV==3
    str = pos ? ReplaceStr(" "+str+" ", " x ", " x 0.5 + ").ReplaceStr(" y ", " y 0.5 + ").\
                ReplaceStr(             " z ", " z 0.5 + ").ReplaceStr(" a ", " a 0.5 + ") : str
    str = pos ? str+" 0.5 -" : str
    # Shifting Chroma when UV is a constant (UV=128) and input bitdepth is 32-bit float
    off = off ? -0.5 : 0

    str = rgb ? str : ReplaceStr(str, "ymax", "cmax").ReplaceStr("ygrey", "range_half")
    str = ex_dlut(str, bi, fs)

    str = UV == 1   ? ""          : \
          UV == 2   ? ""          : \
          UV == 3   ? str         : \
          UV == 4   ? "y"         : \
          UV == 6   ? "z"         : \
          UV == 128 && bi==32 ? si=="floatUV" ? "0.5" : "0" : \
          string(ex_bs(UV, 8, bi, fulls=fs)+off)

    return str }


function ex_Yexpr(string "str", int "Y", int "bits", bool "rgb", bool "fulls", string "scale_inputs") {

    str = Default(str, "")
    Y   = Default(Y,    3)
    bi  = Default(bits, 8)
    rgb = Default(rgb,   false)
    fs  = Default(fulls, rgb)
    si  = Default(scale_inputs, "none")
    si  = LCase(si)

    if (si!="none") {

        str5 = LeftStr(str,5)

        by   = Y != 3                ? -1 : \
               FindStr(str5,"f32")>0 ? 32 : \
               FindStr(str5,"i16")>0 ? 16 : \
               FindStr(str5,"i14")>0 ? 14 : \
               FindStr(str5,"i12")>0 ? 12 : \
               FindStr(str5,"i10")>0 ? 10 : \
               FindStr(str5,"i8" )>0 ?  8 : -1

        bi   = FindStr(si, "int"  )>0 && bi!=32 ? max(8,by) : \
                       si=="float"    && bi==32 ? max(8,by) : \
                       si=="floatf"   && bi==32 ? max(8,by) : \
               FindStr(si, "all"  )>0           ? max(8,by) : bi
    }

    str = ex_dlut(str, bi, fs)
    str = Y == 1   ? ""          : \
          Y == 2   ? ""          : \
          Y == 3   ? str         : \
          Y == 4   ? "y"         : \
          Y == 6   ? "z"         : \
          string(ex_bs(Y, 8, bi, fulls=fs))

    return str }


function ex_UVf(bool rgb, int bits) {

    bits == 32 && !rgb ? "floatUV" : "none" }


# Pixel Value Converter (unsigned)
# Convert values from one bitdepth to another or/and from one scale to another or/and from one (luma) range to another
function ex_bs(float var, int "ibits", int "obits", bool "fulls", bool "fulld", bool "tv_in", bool "tv_out", bool "flt", bool "clamp") {

    ibi = Default(ibits,    8)
    obi = Default(obits,   16)
    tv  = Defined(tv_in) || Defined(tv_out)
    tvi = Default(tv_in,   false)
    tvo = Default(tv_out,  false)
    clp = Default(clamp,   true)
    fs  = Default(fulls,      !tvi)      # fulls
    fd  = Default(fulld, tv ? !tvo : fs) # fulld
    fl  = Default(flt,    obi==32)       # force float output

    ibi  = clamp(ibi,8,32)  ibi = ibi-ibi%2
    obi  = clamp(obi,8,32)  obi = obi-obi%2

    ib32 = ibi == 32   ob32 = obi == 32
    ib8  = ibi == 8    ob8  = obi == 8

    fs  = 8 < ibi < 32 ? fs : false
    fd  = 8 < obi < 32 ? fd : false

    v   = float(var)*pow(2, obi-ibi)

    fsc = fs  && !fd ? -v/257.  : \
                  fd ?  v/256.  : 0

    vif = ib32 ? ob8  ? var*255.  :     var*( 255*pow(2, obi-8)+(fd ? 255*pow(2, obi-8)/256. : 0) )     : nop()
    vof = ob32 ? ib8  ? var/255.  : min(var/( 255*pow(2, ibi-8)+(fs ? 255*pow(2, ibi-8)/256. : 0) ),1.) : nop()

    out = ob32 ? ib32 ? var : vof : ib32 ? vif : v+fsc

    out = clp ? min(out,      Eval(ex_dlut(       "range_size",                                    obi, fd))) : out
    tv  = tvi != tvo  ? tvi ? Eval(ex_dlut(Format("(({out} - ymin) / (ymax - ymin)) * range_max"), obi, fd))  : \
                              Eval(ex_dlut(Format("( {out} * (ymax - ymin)) / range_max + ymin "), obi, fd))  : out
    tv  = tvi != tvo && clp ? Eval(ex_dlut(Format("min(range_max,max(0,{tv}))"),                   obi, fd))  : out
    tv  = clp ? min(tv,       Eval(ex_dlut(       "range_size",                                    obi, fd))) : tv

    ob32 || fl ? tv : round(tv) }



# HBD constants 3D look up table
#
# * YUV and RGB mid-grey is 127.5 (rounded to 128) for PC range levels,
#   this translates to a value of 125.5 in TV range levels. Chroma is always range centered, so 128 regardless.
#
# The second column depicts the constant values converted to PC range, only for the sake of (output) constancy when compared with TV range filtering

function ex_dlut(string "str", int "bits", bool "fulls") {

    str  = Default(str, "")
    bits = Default(bits, 8)
    fs   = Default(fulls, false)

    bitd =
\     (bits ==  8         ) ? 0
\   : (bits == 10         ) ? 1
\   : (bits == 12         ) ? 2
\   : (bits == 14         ) ? 3
\   : (bits == 16         ) ? 4
\   : (bits == 24         ) ? 5
\   : (bits == 32         ) ? 6
\   :  Assert (false, "ex_dlut: '"+string(bits)+"', unsupported bit depth.")


    #                            8-bit UINT    10-bit UINT     12-bit UINT     14-bit UINT       16-bit UINT       24-bit UINT             32-bit Ufloat (by default AVS+ constants are signed)
    range_min   = Select (bitd,  [  0.,  0.],  [   0.,   0.],  [   0.,   0.],  [    0.,    0.],  [    0.,    0.],  [       0.,       0.],  [       0.,       0.])
    ymin        = Select (bitd,  [ 16., 16.],  [  64.,  64.],  [ 256., 257.],  [ 1024., 1028.],  [ 4096., 4112.],  [ 1048576., 1052672.],  [  16/255.,  16/255.])
    cmin        = Select (bitd,  [ 16., 16.],  [  64.,  64.],  [ 256., 257.],  [ 1024., 1028.],  [ 4096., 4112.],  [ 1048576., 1052672.],  [  16/255.,  16/255.])
    ygrey       = Select (bitd,  [126.,126.],  [ 502., 504.],  [2008.,2016.],  [ 8032., 8063.],  [32128.,32254.],  [ 8224768., 8256896.],  [ 125.5/255,125.5/255])
    range_half  = Select (bitd,  [128.,128.],  [ 512., 514.],  [2048.,2056.],  [ 8192., 8224.],  [32768.,32896.],  [ 8388608., 8421376.],  [ 128/255., 128/255.])
    yrange      = Select (bitd,  [219.,219.],  [ 876., 879.],  [3504.,3517.],  [14016.,14070.],  [56064.,56283.],  [14352384.,14408448.],  [ 219/255., 219/255.])
    crange      = Select (bitd,  [224.,224.],  [ 896., 899.],  [3584.,3598.],  [14336.,14392.],  [57344.,57568.],  [14680064.,14737408.],  [ 224/255., 224/255.])
    ymax        = Select (bitd,  [235.,235.],  [ 940., 943.],  [3760.,3774.],  [15040.,15098.],  [60160.,60395.],  [15400960.,15461120.],  [ 235/255., 235/255.])
    cmax        = Select (bitd,  [240.,240.],  [ 960., 963.],  [3840.,3855.],  [15360.,15420.],  [61440.,61680.],  [15728640.,15790080.],  [ 240/255., 240/255.])
    range_max   = Select (bitd,  [255.,255.],  [1023.,1023.],  [4095.,4095.],  [16383.,16383.],  [65535.,65535.],  [16776960.,16776960.],  [       1.,       1.])
    range_size  = Select (bitd,  [256.,256.],  [1024.,1024.],  [4096.,4096.],  [16384.,16384.],  [65536.,65536.],  [16777216.,16777216.],  [       1.,       1.])
#   data_max    = Select (bitd,  [254.,255.],  [1019.,1023.],  [4079.,4095.],  [16319.,16383.],  [65279.,65535.],  [16711679.,16776960.],  [ 254/255.,       1.]) # Legal upper bound for video signal (luma and chroma) in [legal range, full range -not SDI broadcast-]
#   data_min    = Select (bitd,  [  1.,  0.],  [   4.,   0.],  [ 16.,    0.],  [   64.,    0.],  [  256.,    0.],  [   65536.,       0.],  [   1/255.,       0.]) # Legal lower bound for video signal (luma and chroma) in [legal range, full range -not SDI broadcast-]

    fs  = fs ? 1 : 0
    str = ReplaceStr(str, "ymax ymin - range_max /", string(yrange[fs]/range_max[fs]))
    str = ReplaceStr(str, "cmax cmin - range_max /", string(crange[fs]/range_max[fs]))
    str = ReplaceStr(str, "cmax ymin - range_max /", string(crange[fs]/range_max[fs]))
    str = ReplaceStr(str, "range_max ymax ymin - /", string(range_max[fs]/yrange[fs]))
    str = ReplaceStr(str, "range_max cmax cmin - /", string(range_max[fs]/crange[fs]))
    str = ReplaceStr(str, "range_max cmax ymin - /", string(range_max[fs]/crange[fs]))
    str = ReplaceStr(str, "ymax ymin -",             string(yrange[fs]))
    str = ReplaceStr(str, "cmax ymin -",             string(crange[fs]))
    str = ReplaceStr(str, "cmax cmin -",             string(crange[fs]))

    str = ReplaceStr(str, "ygrey",                   string(ygrey[fs]))
    str = ReplaceStr(str, "ymax",                    string(ymax[fs]))
    str = ReplaceStr(str, "cmax",                    string(cmax[fs]))
    str = ReplaceStr(str, "ymin",                    string(ymin[fs]))
    str = ReplaceStr(str, "cmin",                    string(cmin[fs]))
    str = ReplaceStr(str, "range_min",               string(range_min[fs]))
    str = ReplaceStr(str, "range_half",              string(range_half[fs]))
    str = ReplaceStr(str, "range_max",               string(range_max[fs]))
    str = ReplaceStr(str, "range_size",              string(range_size[fs]))

    return str }


# When isY or no reference clip is supplied, a good alternative is: ConverttoYUV444(chromaresample="point")
function mskY_to_YYY(clip a, clip msk, bool "luma", bool "rgb", int "UV", int "bits", string "Jab") {

    isy  = isy(a)
    bi   = BitsPerComponent(a)
    bi   = Default(bits,   bi)
    UV   = Default(UV,      3)    # Process chroma or set a constant color for >6
    luma = Default(luma,UV==3)    # Copy luma to chroma planes (if UV=3)
    rgb  = Default(rgb, isRGB(a))

    w    = width (a)    wm = width (msk)
    h    = height(a)    hm = height(msk)

    cp   = propNumElements(a,"_ChromaLocation") > 0 ? \
           propGetInt     (a,"_ChromaLocation") : 0

    Jabd = Defined(Jab)

    i11  = Jabd ? Jab=="411" : isYV411(a)
    i20  = Jabd ? Jab=="420" : is420(a)
    i22  = Jabd ? Jab=="422" : is422(a)
    i44  = Jabd ? Jab=="444" : is444(a) || isy

    # Default 0.5 because it's always halving (except for 411)
    cpc  = cp == 0 ? [-0.5, 0.0] : \
           cp == 1 ? [ 0.0, 0.0] : \
           cp == 2 ? [-0.5,-0.5] : \
           cp == 3 ? [ 0.0,-0.5] : \
           cp == 4 ? [-0.5, 0.5] : [0.0, 0.5]

    cpw  =  i44 ? 0 : i11 ? cpc[0]/2 : cpc[0]
    cph  = !i20 ? 0 : cpc[1]


    wh = wm!=w || hm!=h
    p_float = bi == 32
    clr     = UV > 6 ? ex_bs(UV, 8, bits, fulls=true) : 0

    mskYs   =  isy(msk)        ? msk        : isRGB(msk) ? msk.ExtractR() : msk.ExtractY()
    mskYt   =                                 mskYs.ConvertBits(8,dither=-1,fulls=true)
    mskYr   =  !wh             ? mskYs      : mskYt.BicubicResize(w,h,0.262015,0.368993).ConvertBits(bi,fulls=true)

    w       = (i44 || rgb) ? w : i11        ? round(w/4.0) : round(w/2.0)
    h       = (i44 || rgb) ? h : i11 || i22 ?            h : round(h/2.0)

    mskC    = (i44 || rgb)     ? mskYr                                  : \
                                 mskYt.BicubicResize(w,h,0.0,0.5,cpw,cph) # no mod2 needed for chroma

    mskC    = luma && UV==3    ? mskC.ConvertBits(bi,fulls=true)                         : \
                                 BlankClip(a,1,w,h,"Y"+string(bi),colors=[clr],channels=0)

    msk     = CombinePlanes(mskYr, mskC, isy ? mskC : Undefined(), planes=rgb ? "RGB" : "YUV", pixel_type=!isy ? PixelType(a) : "YUV"+(Jabd?Jab:"444")+"P"+(bi==32?"S":string(bi)))

    return luma && UV==3 && !(i44 || rgb) ? msk.propSet("_ChromaLocation",cp) : msk }





######### ARRAY HELPER FUNCTIONS #########


# Does a component-wise operation on flat/1D int or float arrays
# If either is a scalar, it operates on all array indices
#
# Examples:
#     ArrayOp([2,4],1,"-")            # output: [1,3]
#     ArrayOp([2.,4.],[3,5,2],"/")    # output: [0.66,0.8,2]
#     ArrayOp([5,4],[2,7],"pow(y,x)") # output: [32,2401]
#     ArrayOp([5,4],[2,7],"exp(y)")   # output: [7.39,1096.6]
#
function ArrayOp ( val arr1, \
                   val arr2, string "Op") {

    Op = Default(Op, "+")

    isUn = OP=="+" || OP=="-" || OP=="*" || OP=="/"
    Op   = isUn ? Op : ReplaceStr(Op, "max", "ma|").ReplaceStr("exp", "e|p").ReplaceStr("ex_", "e|_")

    isa1 = IsArray(arr1)
    isa2 = IsArray(arr2) # At least one operand must be an array

    arr1 = isa1 ? arr1 : [arr1]
    arr2 = isa2 ? arr2 : [arr2]

    a1size = ArraySize(arr1)
    a2size = ArraySize(arr2)

    asize = max(a1size,a2size)
    str   = ""
    for (i=0, asize, 1) {

        mx1 = !(!isa1 || a1size > i)
        mx2 = !(!isa2 || a2size > i)

        X1  = mx1 ? "" : string(arr1[min(a1size-1,i)])
        X   = ReplaceStr(op, "x", X1)
        Y1  = mx2 ? "" : string(arr2[min(a2size-1,i)])
        Y   = ReplaceStr(X,  "y", Y1).ReplaceStr("ma|", "max").ReplaceStr("e|p", "exp").ReplaceStr("e|_", "ex_")

        a1  = asize == i+1
        cm  = a1 ? "" : ","
        str = !isUn ? str + Y + cm : str + X1 + " "+(mx1||mx2 ? "" : op)+" "+ Y1 + cm
        i   = a1 ? asize : i
        }

    return Eval("["+str+"]") }



# Reverses the array
function ArrayInv( val arr1 ) {

    bs  = ArraySize(arr1)-1
    arr = []
    for (i = bs, 0, -1) {
        arr = ArrayAdd(arr,arr1[i])
      }

    return arr }


# Combines or mixes two arrays in pairs (still as flat array)
function ArrayZip( val arr1, val arr2) {

    bs  = ArraySize(arr2)-1
    arr = []
    for (i = 0, bs, 1) {
        arr = ArrayAdd(ArrayAdd(arr,arr1[i]),arr2[i])
      }
    return arr }


# Symmetrizes the array to the left, optionally removing the middle dup
function ArraySym ( val arr1, bool "center" ) {

    cn = Default(center, false) # Include (true) or exclude (false) center duplicate

    asize = ArraySize(arr1)
    inv   = ArrayInv (arr1)
    inv   = cn ? inv : ArrayDel(inv,asize-1)

    return ArrayAppend(inv,arr1) }


# Appends 'arr2' array to 'arr1' array
function ArrayAppend( val arr1, val arr2) {

    bs  = ArraySize(arr2)-1
    arr = arr1
    for (i = 0, bs, 1) {
        arr = ArrayAdd(arr,arr2[i])
      }
    return arr }


# Delete array item by value
function ArrayDelVal(val arr, val vl, bool "all") {

    Assert(isArray(arr), "ArrayDelVal: First argument should be an array")
    all  = Default(all, false) # Change to true to remove all instances of the value

    vl   = isString(vl) ? vl : float(vl)
    sz   = ArraySize(arr)-1
    arrn = []  ac = 0
    for (i = 0, sz, 1) {
        arri = arr[i]
        del  = isString(arri) ? arri : float(arri) == vl
        ac   = del  ?  ac+1 : ac
        arrn = del && (all || ac==1) ? arrn : ArrayAdd(arrn,arri)
    }
    return arrn }


# Find item in an array. Outputs [bool,index]
function ArrayFind(val arr, val vl) {

    Assert(isArray(arr), "ArrayFind: First argument should be an array")

    vl   = isString(vl) ? vl : float(vl)
    sz   = ArraySize(arr)-1
    out  = [false,-1]
    for (i = 0, sz, 1) {
        if (isString(arr[i]) ? arr[i] : float(arr[i]) == vl) {
            out = [true,i]
            i   = sz
        } }
    return out }


# Casts a flat array to a string and prints it (for debug purposes)
function ArrayPrint (clip a, val arr1, bool "string", int "x", int "y") {

    st = Default(string, false) # output a string instead of subtitled clip
    x  = Default(x, 0)
    y  = Default(y, 0)

    asize = ArraySize(arr1)
    dim   = sqrt(asize)
    LC    = Frac(dim)==0.0 ? int(dim) : 12
    str   = ""
    for (i=0, asize-1, 1) {
        cm  = asize == i+1 ? "" : ", "
        str = str + string(arr1[i]) + cm + (i>0 && i<asize-1 && (i+1)%LC==0 ? "\n " : "")
       }
    return st ? str : subtitle(a, "["+str+"]",lsp=8,x=x,y=y) }


# Opposite of ArrayPrint, converts a 'separator' delimited string into an array
function ArrayEval (string arr1, bool "brackets", string "separator") {

    br   = Default(brackets, true)  # Does array string contain brackets "[n]" ?
    sp   = Default(separator, ",")

    arr1 = !br ? "["+arr1+"]" : arr1
    arr1 = ReplaceStr(arr1,sp,",")

    return Eval(arr1) }


# Calculate the median from an array of values
function ArrayMedian (val arr, int "pos", bool "list") {

    isAr = isArray(arr)
    Assert(isAr ? isFloat(arr[0]) : false, "ArrayMedian: First argument should be an array of numbers")

    pos  = Default(pos,     50) # Default 50% for median
    lis  = Default(list, false) # Return the sorted array instead of median

    pos  = clamp(pos,0,100)
    sz   = ArraySize(arr)-1
    isin = isInt(arr[0])
    minv = pow(10,9)  reset = minv

    arro = []
    for (i = 0, sz, 1) {
        for (j = sz-i, 0, -1) {
            minv = min(minv,arr[j]) }

        arr  = ArrayDelVal(arr, minv)
        arro = ArrayAdd   (arro,isin ? int(minv) : minv) # type is inherited from index#0
        minv = reset
    }
    if (lis) { arro } else {
    md = sz*(pos*0.01)
    if (Frac(md)==0.0) {
        return arro[int(md)]
    } else {
        mi  = floor(md)   ma = ceil(md)
        mid = arro[int(mi)]
        mad = arro[int(ma)]
        med = (mad-mid)*(md-mi)+mid
        return Frac(med)==0.0 ? int(med) : med
    } } }


# Return the IQM (Inter Quartile Mean) value from an array of values
# Useful for moving windows (not as a global estimator)
function ArrayIQM(val arr, bool "sorted") {

    sz   = ArraySize(arr)
    srt  = Default(sorted, false)
    Assert((sz+1)%2==0, "ArrayIQM: Array size should be odd")

    qt   = sz*0.25
    qti  = ceil(qt)
    srtd = !srt ? ArrayMedian(arr,list=true) : arr
    trm  = srtd
    for (i = sz-1, sz-qti, -1) {
        trm = ArrayDel(trm,i) }
    for (i = qti-1,     0, -1) {
        trm = ArrayDel(trm,i) }

    Tsz = ArraySize(trm)
    IQa = 0
    for (i = 0, Tsz-1, 1) {
        IQa = IQa+trm[i] }

    if (qt==qti) {
    return IQa / float(Tsz)
    } else {
    IQR = 1 - Frac(qt)
    IQM = ((srtd[qti-1] + srtd[sz-qti]) * IQR + IQa ) / (qt * 2)
    return IQM } }



####### FUNCTION APPROXIMATIONS #######


# (LEGACY) Returns the Maclaurin series of atan(x), actually Maclaurin + polynomial + Maclaurin piecewise function for a 300% speed increase
# Use expand (Default true) to compute atan for larger values beyond -1.65 and 1.65
function atanTM(bool "expand", bool "negative") {

    ex = Default(expand,   true) # includes from x=-1.65 and x=1.65 to inf
    ng = Default(negative, true) # also approximates for negative 'x'

    # atan(x) -> Maclaurin + polynomial + Maclaurin series piecewise function from -0.8 to inf
    e8   = "swap dup dup * X2@ XX * X3@ 0.333333333 * - X2 X3 * X5@ 0.2 * + X5 X2 * X7@ 0.142857143 * - X7 X2 * 0.111111111 * +  X7 X3 * 0.0909090909 * -" # from -0.8 to 0.8
    e16  = "0.021622 XX 1.00976 * A1@ + X2 0.245982 * A2@ -"               # up to 1.65
    els  = "pi 0.5 * 1 X3 3 * / 1 XX / 1 X5 5 * / 1 X7 7 * / + + - A7@ +"  # from  1.65 onwards
    atpf = "XX@ dup 0.8 <= "+e8+" "+e16+" ?"
    atp  = "XX@ dup 0.8 <= "+e8+" XX 1.65 >= "+els+" "+e16+" ? ?"

    # for -X
    er16 = "A2 A1 + 0.021622 -"                                            # up to -1.65
    elrs = "A7 pi 0.5 * -"                                                 # from  -1.65 onwards
    atnf = "XX@ dup dup -0.8 >= swap 0.8 <= & "+e8+" XX 0.8  >  "+e16+" "+er16+" ? ?"
    atn  = "XX@ dup dup -0.8 >= swap 0.8 <= & "+e8+" XX 1.65 >= "+els+" XX -1.65 <= "+elrs+" XX 0.8 > "+e16+" "+er16+" ? ? ? ?"

    return ex ? ng ? atn : atp : ng ? atnf : atpf }


# Benchs: 402 P(4) 370 P(6)  Above: 376 P(4) 390 P(6)
# Use expand (Default true) to compute atan for larger values beyond -2.1 and +2.1
# Also compared to atanTM(), fixes a discontinuity on the negative x axis
#
# Example (atan for sigmoidal contrast):
#   ex_lut(Format("f32 x {b} - {a} * "+atanT()+" 1 {b} - + "), scale_inputs="int") # {a} is strength, {b} is pivot/bias
#
function atanT(bool "expand") {

    ex    = Default(expand, true) # includes from x=-2.1 and x=+2.1 to +-inf

    e3    = "dup dup * swap 8 * dup swap2 X2@ 16 + / swap X2 9 * 16 + / +"                                               # from -2.1 to +2.1
    els   = "X2 XX * dup 3 * 1 swap / swap  X2 * dup 5 * 1 swap / swap X2 * 7 * 1 swap / 1 XX / - + + A7@ 1.570796326 +" # from  2.1 onwards

    elrs  = "A7 1.570796326 -"                                                                                           # from -2.1 onwards
    atanE = "XX@ dup dup -2.1 >= swap 2.1 <= & swap "+e3+" XX 2.1 > "+els+" "+elrs+" ? ?"

    # Remez approximation   (-1.2 to 1.2)
#    atanE = "dup dup * ZZ@ -0.0117212 * 0.05265332 + ZZ * 0.11643287 - ZZ * 0.19354346 + ZZ * 0.33262347 - ZZ * 0.99997726 + *"
    # Another approximation (-1.0 to 1.0)
#    atanE = "dup dup * -0.220587 * 0.983758618 + *"

    return ex ? atanE : e3 }


# (LEGACY: since v3.7.1 test27) Returns the Maclaurin series of atan2(x,y) for a 500% speed increase
function atan2T(bool "expand") {

    ex    = Default(expand, true) # Enable for values beyond -2.1 and +2.1

    atan2 = "ZZ@ dup abs / SX^ YY@ dup abs / SY@ dup * YY ZZ / "+atanT(true)+" * 1 SX - 0.5 * SY dup dup * - 1 + * pi * +"

    # Remez approximation
#    atan2 = "ZZ@ dup 1.8424899 * 0.000000001 - dup ZZ * 9.9281202 - dup ZZ * 0.0000000027 + dup ZZ * 13.374235 + dup ZZ * 0.000000001210359 -"

    return atan2 }


# Returns the hyperbolic tangent function
function tanhT() {

    tanh = "XX@ exp EE@ 0 XX - exp NN@ - EE NN + /"

    return tanh }

# Returns the hyperbolic arctangent function
function atanhT() {

    tanh = "dup 1 + swap 1 swap - / log 0.5 *"

    return tanh }


# Returns an approximation of exp(x)
# Polynomial degree 11 starts to fail at value x=212 (8-bit). Degree 11 slower than Expr() 'exp' by 10%
function expT(int "degree") {

    d = Default(degree, 11)
    d = clamp(d,1,11)

    # Maclaurin series - 11th degree polynomial. -3.55 <= x <= +3.4
    exp11 = "XX@ dup dup * X2@ 0.5 * 1 + + X2 XX * X3@ 0.166666666 * + X2 dup * X4@ 0.041666666 * +
             X3 X2 * X5@ 0.008333333 * + X3 dup * 0.001388888 * + X4 X3 * 0.0001984127 * + X4 dup * 0.000024802 * +
             X5 X4 * 0.000002756 * + X5 dup * dup XX * 39916800 / swap 3628800 / + +"

    # Maclaurin series - 9th degree polynomial. -2.8 <= x <= +2.6
    exp9  = "XX@ dup dup * X2@ 0.5 * 1 + + X2 XX * X3@ 0.166666666 * + X2 dup * X4@ 0.041666666 * +
             X3 X2 * X5@ 0.008333333 * + X3 dup * 0.001388888 * + X4 X3 * 0.0001984127 * + X4 dup * 0.000024802 * +
             X5 X4 * 0.000002756 * +"

    # Maclaurin series - 7th degree polynomial. -2 <= x <= +2
    exp7  = "XX@ dup dup * X2@ 0.5 * 1 + + X2 XX * X3@ 0.166666666 * + X2 dup * X4@ 0.041666666 * +
             X3 X2 * 0.008333333 * + X3 dup * 0.001388888 * + X4 X3 * 0.0001984127 * +"

    # Maclaurin series - 5th degree polynomial. -1.3 <= x <= +1.2
    exp5  = "XX@ dup dup * X2@ 0.5 * 1 + + X2 XX * X3@ 0.166666666 * + X2 dup * 0.041666666 * +
             X3 X2 * 0.008333333 * +"

    # Maclaurin series - 3rd degree polynomial. -0.7 <= x <= +0.7
    exp3  = "dup dup dup * X2@ 0.5 * 1 + + swap X2 * 0.166666666 * +"

    # Maclaurin series - 1st degree polynomial. In some situations/expressions this is enough
    exp1  = "dup dup * 0.5 * 1 + +"

    return Eval(Format("exp{d}")) }


# (LEGACY: since v3.7.1 test19) Returns an approximation of cos(x) for -1.7 <= x <= 1.7 for near 300% speed increase (before AVS+ 3.7.1 test 19)
# For range -pi/2 <= x <= pi use expand=true (Default)
function cosT(bool "expand") {

    ex = Default(expand, true)

    # Bhaskara I
    cosT  = "dup * X2@ 4 * pi dup * dup X2 + swap2 - swap /"

    # Taylor series
    # -1.7 <= x <= 1.7
    # cosT  = "dup * X2@ 0.5 * 1 swap - X2 dup * X4@ 0.041666666 * + X4 X2 * 0.001388888 * -"
    # 0 <= x <= pi
    # cosTP = "pi 0.5 * - XX@ 0.00000367321 swap - XX dup * X2@ 0.0000018366 * + X2 XX * X3@ 0.166666666 * + X2 dup * 0.00000015305 * - X2 X3 * 0.008333333 * -"

    # -pi/2 <= x <= pi
    cosTP1  = "        XX  dup * X2@ 0.5 * 1 swap - X2 dup * X4@ 0.041574811029363 * + X4 X2 * 0.001292112506266 * -" # 0.00129... to fix discontinuity at pi/2
    cosTP2  = "pi XX -     dup * X2@ 0.5 * 1      - X2 dup * X4@ 0.041574811029363 * - X4 X2 * 0.001292112506266 * +"
    cosTP   = "XX@ pi 0.5 * < "+cosTP1+" "+cosTP2+" ?"

    return ex ? cosTP : cosT }


# (LEGACY: since v3.7.1 test19) Returns an approximation of sin(x) for 0 <= x <= pi for near 300% speed increase (before AVS+ 3.7.1 test 19)
# For range -pi/2 <= x <= pi use expand=true (Default)
function sinT(bool "expand") {

    ex = Default(expand, true)

    # Bhaskara I  ( 16x(pi-x) / 5pi^2-4x(pi-x) )
    sinT    = "XX@ pi swap - P@ XX 4 * X4@ * pi dup * 5 * swap - X4 4 * P * swap /"
    # Taylor series (14% slower than above but perfect match to sin(x) )
    # sinT  = "pi 0.5 * swap - dup * X2@ 0.5 * 1 swap - X2 dup * X4@ 0.041666666 * + X4 X2 * 0.001388888 * -"

    sinTP1  = "pi 0.5 * XX - dup * X2@ 0.5 * 1 swap - X2 dup * X4@ 0.041574811029363 * + X4 X2 * 0.001292112506266 * -" # 0.00129... to fix discontinuity at pi/2
    sinTP2  = "pi 0.5 * XX + dup * X2@ 0.5 * 1      - X2 dup * X4@ 0.041574811029363 * - X4 X2 * 0.001292112506266 * +"
    sinTP   = "XX@ 0 > "+sinTP1+" "+sinTP2+" ?"

    return ex ? sinTP : sinT }



# Select Median
# From 35 -included- onwards not optimized enough
function sel_med(int n) {

    even = n%2 == 0
    n    = even ? n+1 : n

    med =                                                      \
                                                               \
    n == 3  ?  "A B                   dup1 dup1 max swap2 min
                X swap2 clip "                               : \
                                                               \
    n == 5  ?  "A B                   dup1 dup1 min swap2 max
                C D                   dup1 dup1 min swap2 max
                swap1  swap2                    min
                swap2                                     max
                                      dup1 dup1 max swap2 min
                X swap2 clip "                               : \
                                                               \
    n == 7  ?  "A B                   dup1 dup1 min swap2 max
                C D                   dup1 dup1 min swap2 max
                E F                   dup1 dup1 min swap2 max
                swap1  swap2          dup1 dup1 min swap2 max
                swap2  swap1  swap3   dup1 dup1 min swap2 max
                swap1  swap4          dup1 dup1 min swap2 max
                swap5  swap1  swap3   dup1 dup1 min swap2 max
                swap2  swap1  swap5             min
                swap2                 dup1 dup1 min swap2 max
                swap4  swap1  swap3                       max
                swap3                           min
                swap2                                     max
                X swap2 clip "                               : \
                                                               \
    n == 9  ?  "A B                   dup1 dup1 min swap2 max
                C D                   dup1 dup1 min swap2 max
                E F                   dup1 dup1 min swap2 max
                G H                   dup1 dup1 min swap2 max
                swap2  swap1  swap6   dup1 dup1 min swap2 max
                swap2  swap1  swap4   dup1 dup1 min swap2 max
                swap3  swap1  swap7   dup1 dup1 min swap2 max
                swap6  swap1  swap5   dup1 dup1 min swap2 max
                swap3  swap1  swap2             min
                swap2  swap1  swap5   dup1 dup1 min swap2 max
                swap6  swap1  swap3   dup1 dup1 min swap2 max
                swap5  swap1  swap4                       max
                swap4  swap1  swap5             min
                swap2                                     max
                swap3                           min
                swap2                                     max
                                      dup1 dup1 max swap2 min
                X swap2 clip "                               : \
                                                               \
    n == 11  ? "B J                   dup1 dup1 min B^ max J^
                A I                   dup1 dup1 min A^ max I^
                C H                   dup1 dup1 min C^ max H^
                E G                   dup1 dup1 min E^ max G^
                D F                   dup1 dup1 min D^ max F^
                H J                   dup1 dup1 min H^ max J^
                F I                   dup1 dup1 min F^ max I^
                B E                   dup1 dup1 min B^ max E^
                A C                   dup1 dup1 min A^ max C^
                G J                   dup1 dup1 min G^ max J^
                F H                   dup1 dup1 min F^ max H^
                C E                   dup1 dup1 min C^ max E^
                A D                   dup1 dup1 min A^ max D^
                I J                             min I^
                D G                   dup1 dup1 min D^ max G^
                A B                                    max B^
                E I                   dup1 dup1 min E^ max I^
                G H                   dup1 dup1 min G^ max H^
                B F                   dup1 dup1 min B^ max F^
                C D                   dup1 dup1 min C^ max D^
                H I                             min H^
                E G                   dup1 dup1 min E^ max G^
                D F                   dup1 dup1 min D^ max F^
                B C                                    max C^
                G H                             min G^
                E F                   dup1 dup1 min E^ max F^
                C D                                    max D^
                D E                                    max
                F G                             min

                X swap2 clip "                                : \
                                                                \
    n == 13  ? "D L                   dup1 dup1 min D^ max L^
                E K                   dup1 dup1 min E^ max K^
                F J                   dup1 dup1 min F^ max J^
                A I                   dup1 dup1 min A^ max I^
                B H                   dup1 dup1 min B^ max H^
                C G                   dup1 dup1 min C^ max G^
                J L                   dup1 dup1 min J^ max L^
                H K                   dup1 dup1 min H^ max K^
                G I                   dup1 dup1 min G^ max I^
                D F                   dup1 dup1 min D^ max F^
                B E                   dup1 dup1 min B^ max E^
                A C                   dup1 dup1 min A^ max C^
                K L                             min K^
                C J                   dup1 dup1 min C^ max J^
                E H                   dup1 dup1 min E^ max H^
                F G                   dup1 dup1 min F^ max G^
                A B                                    max B^
                I K                             min I^
                E J                   dup1 dup1 min E^ max J^
                C H                   dup1 dup1 min C^ max H^
                B D                                    max D^
                I J                             min I^
                G H                             min G^
                E F                                    max F^
                C D                                    max D^
                G I                   dup1 dup1 min G^ max I^
                D F                   dup1 dup1 min D^ max F^
                F I                             min F^
                D G                                    max G^
                F G                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 15  ? "K N                   dup1 dup1 min K^ max N^
                E M                   dup1 dup1 min E^ max M^
                H L                   dup1 dup1 min H^ max L^
                B J                   dup1 dup1 min B^ max J^
                D I                   dup1 dup1 min D^ max I^
                C G                   dup1 dup1 min C^ max G^
                A F                   dup1 dup1 min A^ max F^
                L N                   dup1 dup1 min L^ max N^
                B K                   dup1 dup1 min B^ max K^
                I J                   dup1 dup1 min I^ max J^
                D H                   dup1 dup1 min D^ max H^
                F G                   dup1 dup1 min F^ max G^
                A C                   dup1 dup1 min A^ max C^
                M N                   dup1 dup1 min M^ max N^
                C L                   dup1 dup1 min C^ max L^
                H K                   dup1 dup1 min H^ max K^
                G J                   dup1 dup1 min G^ max J^
                E I                   dup1 dup1 min E^ max I^
                B D                   dup1 dup1 min B^ max D^
                J N                             min J^
                G M                   dup1 dup1 min G^ max M^
                I L                   dup1 dup1 min I^ max L^
                F K                   dup1 dup1 min F^ max K^
                A H                   dup1 dup1 min A^ max H^
                C E                   dup1 dup1 min C^ max E^
                L M                             min L^
                J K                             min J^
                G I                   dup1 dup1 min G^ max I^
                E H                   dup1 dup1 min E^ max H^
                D F                   dup1 dup1 min D^ max F^
                A B                                    max B^
                J L                             min J^
                E I                   dup1 dup1 min E^ max I^
                D H                   dup1 dup1 min D^ max H^
                F G                   dup1 dup1 min F^ max G^
                B C                                    max C^
                I J                   dup1 dup1 min I^ max J^
                G H                   dup1 dup1 min G^ max H^
                C F                                    max F^
                D E                                    max E^
                H J                             min H^
                G I                   dup1 dup1 min G^ max I^
                E F                                    max F^
                F G                                    max
                H I                             min

                X swap2 clip "                                : \
                                                                \
    n == 17  ? "K P                   dup1 dup1 min K^ max P^
                L O                   dup1 dup1 min L^ max O^
                D N                   dup1 dup1 min D^ max N^
                C M                   dup1 dup1 min C^ max M^
                I J                   dup1 dup1 min I^ max J^
                G H                   dup1 dup1 min G^ max H^
                A F                   dup1 dup1 min A^ max F^
                B E                   dup1 dup1 min B^ max E^
                N P                   dup1 dup1 min N^ max P^
                F O                   dup1 dup1 min F^ max O^
                J M                   dup1 dup1 min J^ max M^
                I L                   dup1 dup1 min I^ max L^
                B K                   dup1 dup1 min B^ max K^
                E H                   dup1 dup1 min E^ max H^
                D G                   dup1 dup1 min D^ max G^
                A C                   dup1 dup1 min A^ max C^
                H P                   dup1 dup1 min H^ max P^
                M O                   dup1 dup1 min M^ max O^
                E N                   dup1 dup1 min E^ max N^
                C L                   dup1 dup1 min C^ max L^
                G K                   dup1 dup1 min G^ max K^
                F J                   dup1 dup1 min F^ max J^
                A I                   dup1 dup1 min A^ max I^
                B D                   dup1 dup1 min B^ max D^
                O P                             min O^
                L N                   dup1 dup1 min L^ max N^
                H M                   dup1 dup1 min H^ max M^
                J K                   dup1 dup1 min J^ max K^
                D I                   dup1 dup1 min D^ max I^
                F G                   dup1 dup1 min F^ max G^
                C E                   dup1 dup1 min C^ max E^
                A B                                    max B^
                M O                             min M^
                K N                             min K^
                H L                   dup1 dup1 min H^ max L^
                G J                   dup1 dup1 min G^ max J^
                E I                   dup1 dup1 min E^ max I^
                C F                                    max F^
                B D                                    max D^
                K M                             min K^
                E L                   dup1 dup1 min E^ max L^
                H J                   dup1 dup1 min H^ max J^
                G I                   dup1 dup1 min G^ max I^
                D F                                    max F^
                K L                             min K^
                I J                             min I^
                G H                                    max H^
                E F                                    max F^
                I K                             min I^
                F H                                    max H^
                H I                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 19  ? "L R                   dup1 dup1 min L^ max R^
                H Q                   dup1 dup1 min H^ max Q^
                C P                   dup1 dup1 min C^ max P^
                M O                   dup1 dup1 min M^ max O^
                I N                   dup1 dup1 min I^ max N^
                B K                   dup1 dup1 min B^ max K^
                E J                   dup1 dup1 min E^ max J^
                A G                   dup1 dup1 min A^ max G^
                D F                   dup1 dup1 min D^ max F^
                F R                   dup1 dup1 min F^ max R^
                N Q                   dup1 dup1 min N^ max Q^
                G O                   dup1 dup1 min G^ max O^
                A M                   dup1 dup1 min A^ max M^
                D L                   dup1 dup1 min D^ max L^
                J K                   dup1 dup1 min J^ max K^
                H I                   dup1 dup1 min H^ max I^
                B E                   dup1 dup1 min B^ max E^
                E Q                   dup1 dup1 min E^ max Q^
                K P                   dup1 dup1 min K^ max P^
                B N                   dup1 dup1 min B^ max N^
                I L                   dup1 dup1 min I^ max L^
                G J                   dup1 dup1 min G^ max J^
                C H                   dup1 dup1 min C^ max H^
                Q R                   dup1 dup1 min Q^ max R^
                O P                   dup1 dup1 min O^ max P^
                F N                   dup1 dup1 min F^ max N^
                E M                   dup1 dup1 min E^ max M^
                I K                   dup1 dup1 min I^ max K^
                H J                   dup1 dup1 min H^ max J^
                C D                   dup1 dup1 min C^ max D^
                A B                   dup1 dup1 min A^ max B^
                P R                             min P^
                G Q                   dup1 dup1 min G^ max Q^
                N O                   dup1 dup1 min N^ max O^
                K M                   dup1 dup1 min K^ max M^
                B L                   dup1 dup1 min B^ max L^
                F H                   dup1 dup1 min F^ max H^
                D E                   dup1 dup1 min D^ max E^
                A C                                    max C^
                J Q                   dup1 dup1 min J^ max Q^
                H N                   dup1 dup1 min H^ max N^
                L M                   dup1 dup1 min L^ max M^
                E K                   dup1 dup1 min E^ max K^
                B I                   dup1 dup1 min B^ max I^
                F G                   dup1 dup1 min F^ max G^
                O Q                             min O^
                M P                             min M^
                K N                   dup1 dup1 min K^ max N^
                J L                   dup1 dup1 min J^ max L^
                G I                   dup1 dup1 min G^ max I^
                E H                   dup1 dup1 min E^ max H^
                C F                                    max F^
                B D                                    max D^
                M O                             min M^
                L N                             min L^
                I K                   dup1 dup1 min I^ max K^
                H J                   dup1 dup1 min H^ max J^
                E G                                    max G^
                D F                                    max F^
                J M                             min J^
                K L                             min K^
                F I                                    max I^
                G H                                    max H^
                J K                             min J^
                H I                                    max I^
                I J                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 21  ? "H T                   dup1 dup1 min H^ max T^
                G S                   dup1 dup1 min G^ max S^
                F R                   dup1 dup1 min F^ max R^
                E Q                   dup1 dup1 min E^ max Q^
                D P                   dup1 dup1 min D^ max P^
                C O                   dup1 dup1 min C^ max O^
                B N                   dup1 dup1 min B^ max N^
                A M                   dup1 dup1 min A^ max M^
                J L                   dup1 dup1 min J^ max L^
                I K                   dup1 dup1 min I^ max K^
                R T                   dup1 dup1 min R^ max T^
                Q S                   dup1 dup1 min Q^ max S^
                N P                   dup1 dup1 min N^ max P^
                M O                   dup1 dup1 min M^ max O^
                K L                   dup1 dup1 min K^ max L^
                I J                   dup1 dup1 min I^ max J^
                F H                   dup1 dup1 min F^ max H^
                E G                   dup1 dup1 min E^ max G^
                B D                   dup1 dup1 min B^ max D^
                A C                   dup1 dup1 min A^ max C^
                S T                   dup1 dup1 min S^ max T^
                Q R                   dup1 dup1 min Q^ max R^
                O P                   dup1 dup1 min O^ max P^
                M N                   dup1 dup1 min M^ max N^
                G H                   dup1 dup1 min G^ max H^
                E F                   dup1 dup1 min E^ max F^
                C D                   dup1 dup1 min C^ max D^
                A B                   dup1 dup1 min A^ max B^
                P T                             min P^
                H S                   dup1 dup1 min H^ max S^
                D R                   dup1 dup1 min D^ max R^
                C Q                   dup1 dup1 min C^ max Q^
                L O                   dup1 dup1 min L^ max O^
                K N                   dup1 dup1 min K^ max N^
                B M                   dup1 dup1 min B^ max M^
                G J                   dup1 dup1 min G^ max J^
                F I                   dup1 dup1 min F^ max I^
                A E                                    max E^
                N S                             min N^
                J Q                   dup1 dup1 min J^ max Q^
                O P                             min O^
                I M                   dup1 dup1 min I^ max M^
                H L                   dup1 dup1 min H^ max L^
                D K                   dup1 dup1 min D^ max K^
                B G                                    max G^
                E F                                    max F^
                L R                             min L^
                K Q                   dup1 dup1 min K^ max Q^
                M N                   dup1 dup1 min M^ max N^
                D J                   dup1 dup1 min D^ max J^
                C I                                    max I^
                G H                   dup1 dup1 min G^ max H^
                N Q                             min N^
                L O                             min L^
                J M                   dup1 dup1 min J^ max M^
                H K                   dup1 dup1 min H^ max K^
                F I                                    max I^
                D G                                    max G^
                L N                             min L^
                K M                             min K^
                H J                                    max J^
                G I                                    max I^
                J L                   dup1 dup1 min J^ max L^
                I K                   dup1 dup1 min I^ max K^
                K L                             min K^
                I J                                    max J^
                J K                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 23  ? "U V                   dup1 dup1 min U^ max V^
                S T                   dup1 dup1 min S^ max T^
                Q R                   dup1 dup1 min Q^ max R^
                O P                   dup1 dup1 min O^ max P^
                M N                   dup1 dup1 min M^ max N^
                K L                   dup1 dup1 min K^ max L^
                I J                   dup1 dup1 min I^ max J^
                G H                   dup1 dup1 min G^ max H^
                E F                   dup1 dup1 min E^ max F^
                C D                   dup1 dup1 min C^ max D^
                A B                   dup1 dup1 min A^ max B^
                J V                   dup1 dup1 min J^ max V^
                I U                   dup1 dup1 min I^ max U^
                P T                   dup1 dup1 min P^ max T^
                O S                   dup1 dup1 min O^ max S^
                L R                   dup1 dup1 min L^ max R^
                B N                   dup1 dup1 min B^ max N^
                A M                   dup1 dup1 min A^ max M^
                E K                   dup1 dup1 min E^ max K^
                D H                   dup1 dup1 min D^ max H^
                C G                   dup1 dup1 min C^ max G^
                T V                   dup1 dup1 min T^ max V^
                P U                   dup1 dup1 min P^ max U^
                J S                   dup1 dup1 min J^ max S^
                F R                   dup1 dup1 min F^ max R^
                E Q                   dup1 dup1 min E^ max Q^
                I O                   dup1 dup1 min I^ max O^
                H N                   dup1 dup1 min H^ max N^
                D M                   dup1 dup1 min D^ max M^
                B G                   dup1 dup1 min B^ max G^
                A C                   dup1 dup1 min A^ max C^
                N V                   dup1 dup1 min N^ max V^
                G U                   dup1 dup1 min G^ max U^
                H T                   dup1 dup1 min H^ max T^
                M S                   dup1 dup1 min M^ max S^
                K Q                   dup1 dup1 min K^ max Q^
                B P                   dup1 dup1 min B^ max P^
                C O                   dup1 dup1 min C^ max O^
                F L                   dup1 dup1 min F^ max L^
                D J                   dup1 dup1 min D^ max J^
                A I                   dup1 dup1 min A^ max I^
                R V                             min R^
                L U                   dup1 dup1 min L^ max U^
                N S                   dup1 dup1 min N^ max S^
                M Q                   dup1 dup1 min M^ max Q^
                H O                   dup1 dup1 min H^ max O^
                B K                   dup1 dup1 min B^ max K^
                F J                   dup1 dup1 min F^ max J^
                D I                   dup1 dup1 min D^ max I^
                A E                                    max E^
                S U                             min S^
                Q T                             min Q^
                N R                             min N^
                M P                   dup1 dup1 min M^ max P^
                L O                   dup1 dup1 min L^ max O^
                H K                   dup1 dup1 min H^ max K^
                G J                   dup1 dup1 min G^ max J^
                E I                                    max I^
                C F                                    max F^
                B D                                    max D^
                J S                             min J^
                N Q                   dup1 dup1 min N^ max Q^
                K P                   dup1 dup1 min K^ max P^
                D M                                    max M^
                G L                   dup1 dup1 min G^ max L^
                F I                   dup1 dup1 min F^ max I^
                O Q                             min O^
                J P                             min J^
                K N                   dup1 dup1 min K^ max N^
                G M                                    max M^
                I L                   dup1 dup1 min I^ max L^
                F H                                    max H^
                J O                             min J^
                L N                             min L^
                H M                                    max M^
                I K                                    max K^
                K M                   dup1 dup1 min K^ max M^
                J L                   dup1 dup1 min J^ max L^
                L M                             min L^
                J K                                    max K^
                K L                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 25  ? "D Z                   dup1 dup1 min D^ max Z^
                L W                   dup1 dup1 min L^ max W^
                H V                   dup1 dup1 min H^ max V^
                A U                   dup1 dup1 min A^ max U^
                R T                   dup1 dup1 min R^ max T^
                N S                   dup1 dup1 min N^ max S^
                C Q                   dup1 dup1 min C^ max Q^
                J P                   dup1 dup1 min J^ max P^
                I O                   dup1 dup1 min I^ max O^
                B M                   dup1 dup1 min B^ max M^
                F K                   dup1 dup1 min F^ max K^
                E G                   dup1 dup1 min E^ max G^
                U Z                   dup1 dup1 min U^ max Z^
                M W                   dup1 dup1 min M^ max W^
                Q V                   dup1 dup1 min Q^ max V^
                G T                   dup1 dup1 min G^ max T^
                K S                   dup1 dup1 min K^ max S^
                E R                   dup1 dup1 min E^ max R^
                O P                   dup1 dup1 min O^ max P^
                F N                   dup1 dup1 min F^ max N^
                B L                   dup1 dup1 min B^ max L^
                I J                   dup1 dup1 min I^ max J^
                C H                   dup1 dup1 min C^ max H^
                A D                   dup1 dup1 min A^ max D^
                W Z                   dup1 dup1 min W^ max Z^
                T V                   dup1 dup1 min T^ max V^
                L U                   dup1 dup1 min L^ max U^
                P S                   dup1 dup1 min P^ max S^
                O R                   dup1 dup1 min O^ max R^
                N Q                   dup1 dup1 min N^ max Q^
                D M                   dup1 dup1 min D^ max M^
                H K                   dup1 dup1 min H^ max K^
                G J                   dup1 dup1 min G^ max J^
                F I                   dup1 dup1 min F^ max I^
                C E                   dup1 dup1 min C^ max E^
                A B                   dup1 dup1 min A^ max B^
                S V                             min S^
                P T                   dup1 dup1 min P^ max T^
                M R                   dup1 dup1 min M^ max R^
                J Q                   dup1 dup1 min J^ max Q^
                H O                   dup1 dup1 min H^ max O^
                G L                   dup1 dup1 min G^ max L^
                E I                   dup1 dup1 min E^ max I^
                C F                                    max F^
                P W                   dup1 dup1 min P^ max W^
                J U                   dup1 dup1 min J^ max U^
                Q T                   dup1 dup1 min Q^ max T^
                D O                   dup1 dup1 min D^ max O^
                L N                   dup1 dup1 min L^ max N^
                K M                   dup1 dup1 min K^ max M^
                B I                   dup1 dup1 min B^ max I^
                E H                   dup1 dup1 min E^ max H^
                Q Z                             min Q^
                S W                   dup1 dup1 min S^ max W^
                T U                             min T^
                M R                   dup1 dup1 min M^ max R^
                I P                   dup1 dup1 min I^ max P^
                J O                   dup1 dup1 min J^ max O^
                K N                   dup1 dup1 min K^ max N^
                G L                   dup1 dup1 min G^ max L^
                A H                                    max H^
                B F                   dup1 dup1 min B^ max F^
                D E                                    max E^
                R W                             min R^
                Q T                   dup1 dup1 min Q^ max T^
                O S                   dup1 dup1 min O^ max S^
                N P                   dup1 dup1 min N^ max P^
                I K                   dup1 dup1 min I^ max K^
                F J                   dup1 dup1 min F^ max J^
                E H                   dup1 dup1 min E^ max H^
                B G                                    max G^
                S T                   dup1 dup1 min S^ max T^
                P R                             min P^
                O Q                   dup1 dup1 min O^ max Q^
                M N                   dup1 dup1 min M^ max N^
                K L                   dup1 dup1 min K^ max L^
                H J                   dup1 dup1 min H^ max J^
                G I                                    max I^
                E F                   dup1 dup1 min E^ max F^
                N T                             min N^
                P Q                             min P^
                M O                   dup1 dup1 min M^ max O^
                J L                   dup1 dup1 min J^ max L^
                E K                                    max K^
                H I                                    max I^
                N S                             min N^
                O P                             min O^
                F K                                    max K^
                I J                                    max J^
                L N                             min L^
                K M                                    max M^
                L O                             min L^
                J M                                    max M^
                L M                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 27  ? "M BB                  dup1 dup1 min M^ max BB^
                T AA                  dup1 dup1 min T^ max AA^
                R Z                   dup1 dup1 min R^ max Z^
                F W                   dup1 dup1 min F^ max W^
                S V                   dup1 dup1 min S^ max V^
                D U                   dup1 dup1 min D^ max U^
                J Q                   dup1 dup1 min J^ max Q^
                K P                   dup1 dup1 min K^ max P^
                L O                   dup1 dup1 min L^ max O^
                A N                   dup1 dup1 min A^ max N^
                C I                   dup1 dup1 min C^ max I^
                E H                   dup1 dup1 min E^ max H^
                B G                   dup1 dup1 min B^ max G^
                W BB                  dup1 dup1 min W^ max BB^
                G AA                  dup1 dup1 min G^ max AA^
                H V                   dup1 dup1 min H^ max V^
                N U                   dup1 dup1 min N^ max U^
                B T                   dup1 dup1 min B^ max T^
                E S                   dup1 dup1 min E^ max S^
                J R                   dup1 dup1 min J^ max R^
                I Q                   dup1 dup1 min I^ max Q^
                O P                   dup1 dup1 min O^ max P^
                F M                   dup1 dup1 min F^ max M^
                K L                   dup1 dup1 min K^ max L^
                A D                   dup1 dup1 min A^ max D^
                P BB                  dup1 dup1 min P^ max BB^
                U AA                  dup1 dup1 min U^ max AA^
                I Z                   dup1 dup1 min I^ max Z^
                N W                   dup1 dup1 min N^ max W^
                O T                   dup1 dup1 min O^ max T^
                J S                   dup1 dup1 min J^ max S^
                C R                   dup1 dup1 min C^ max R^
                H Q                   dup1 dup1 min H^ max Q^
                D M                   dup1 dup1 min D^ max M^
                G L                   dup1 dup1 min G^ max L^
                A K                   dup1 dup1 min A^ max K^
                B F                   dup1 dup1 min B^ max F^
                AA BB                 dup1 dup1 min AA^ max BB^
                Q Z                   dup1 dup1 min Q^ max Z^
                L W                   dup1 dup1 min L^ max W^
                R V                   dup1 dup1 min R^ max V^
                P U                   dup1 dup1 min P^ max U^
                M T                   dup1 dup1 min M^ max T^
                H S                   dup1 dup1 min H^ max S^
                D O                   dup1 dup1 min D^ max O^
                G N                   dup1 dup1 min G^ max N^
                F K                   dup1 dup1 min F^ max K^
                C J                   dup1 dup1 min C^ max J^
                E I                   dup1 dup1 min E^ max I^
                A B                   dup1 dup1 min A^ max B^
                U AA                  dup1 dup1 min U^ max AA^
                V Z                   dup1 dup1 min V^ max Z^
                T W                   dup1 dup1 min T^ max W^
                Q S                   dup1 dup1 min Q^ max S^
                I R                   dup1 dup1 min I^ max R^
                K P                   dup1 dup1 min K^ max P^
                L O                   dup1 dup1 min L^ max O^
                M N                   dup1 dup1 min M^ max N^
                H J                   dup1 dup1 min H^ max J^
                D G                   dup1 dup1 min D^ max G^
                B F                   dup1 dup1 min B^ max F^
                C E                   dup1 dup1 min C^ max E^
                Z BB                            min Z^
                W AA                  dup1 dup1 min W^ max AA^
                S V                   dup1 dup1 min S^ max V^
                T U                   dup1 dup1 min T^ max U^
                P R                   dup1 dup1 min P^ max R^
                J Q                   dup1 dup1 min J^ max Q^
                N O                   dup1 dup1 min N^ max O^
                L M                   dup1 dup1 min L^ max M^
                I K                   dup1 dup1 min I^ max K^
                E H                   dup1 dup1 min E^ max H^
                F G                   dup1 dup1 min F^ max G^
                B D                   dup1 dup1 min B^ max D^
                A C                                    max C^
                Z AA                  dup1 dup1 min Z^ max AA^
                V W                             min V^
                H T                   dup1 dup1 min H^ max T^
                G S                   dup1 dup1 min G^ max S^
                O R                             min O^
                N Q                   dup1 dup1 min N^ max Q^
                K P                   dup1 dup1 min K^ max P^
                J M                   dup1 dup1 min J^ max M^
                I L                                    max L^
                D E                                    max E^
                B C                   dup1 dup1 min B^ max C^
                Q AA                            min Q^
                O Z                             min O^
                T V                             min T^
                S U                             min S^
                N P                   dup1 dup1 min N^ max P^
                K M                   dup1 dup1 min K^ max M^
                C L                                    max L^
                B J                                    max J^
                F H                                    max H^
                E G                                    max G^
                L T                   dup1 dup1 min L^ max T^
                M S                             min M^
                P Q                             min P^
                G O                   dup1 dup1 min G^ max O^
                H N                                    max N^
                J K                                    max K^
                P T                             min P^
                M O                             min M^
                L N                                    max N^
                G K                                    max K^
                N P                   dup1 dup1 min N^ max P^
                K M                   dup1 dup1 min K^ max M^
                M P                             min M^
                K N                                    max N^
                M N                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 29  ? "CC DD                 dup1 dup1 min CC^ max DD^
                AA BB                 dup1 dup1 min AA^ max BB^
                W Z                   dup1 dup1 min W^  max Z^
                U V                   dup1 dup1 min U^  max V^
                S T                   dup1 dup1 min S^  max T^
                Q R                   dup1 dup1 min Q^  max R^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                K L                   dup1 dup1 min K^  max L^
                I J                   dup1 dup1 min I^  max J^
                G H                   dup1 dup1 min G^  max H^
                E F                   dup1 dup1 min E^  max F^
                C D                   dup1 dup1 min C^  max D^
                A B                   dup1 dup1 min A^  max B^
                B DD                  dup1 dup1 min B^  max DD^
                A CC                  dup1 dup1 min A^  max CC^
                D BB                  dup1 dup1 min D^  max BB^
                C AA                  dup1 dup1 min C^  max AA^
                F Z                   dup1 dup1 min F^  max Z^
                E W                   dup1 dup1 min E^  max W^
                H V                   dup1 dup1 min H^  max V^
                G U                   dup1 dup1 min G^  max U^
                J T                   dup1 dup1 min J^  max T^
                I S                   dup1 dup1 min I^  max S^
                L R                   dup1 dup1 min L^  max R^
                K Q                   dup1 dup1 min K^  max Q^
                N P                   dup1 dup1 min N^  max P^
                M O                   dup1 dup1 min M^  max O^
                V DD                  dup1 dup1 min V^  max DD^
                H CC                  dup1 dup1 min H^  max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                W AA                  dup1 dup1 min W^  max AA^
                B U                   dup1 dup1 min B^  max U^
                P R                   dup1 dup1 min P^  max R^
                N Q                   dup1 dup1 min N^  max Q^
                L O                   dup1 dup1 min L^  max O^
                K M                   dup1 dup1 min K^  max M^
                A G                   dup1 dup1 min A^  max G^
                D F                   dup1 dup1 min D^  max F^
                C E                   dup1 dup1 min C^  max E^
                J CC                  dup1 dup1 min J^  max CC^
                R BB                  dup1 dup1 min R^  max BB^
                F Z                   dup1 dup1 min F^  max Z^
                E W                   dup1 dup1 min E^  max W^
                T V                   dup1 dup1 min T^  max V^
                B S                   dup1 dup1 min B^  max S^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                C K                   dup1 dup1 min C^  max K^
                G I                   dup1 dup1 min G^  max I^
                V DD                  dup1 dup1 min V^  max DD^
                F AA                  dup1 dup1 min F^  max AA^
                P Z                   dup1 dup1 min P^  max Z^
                D W                   dup1 dup1 min D^  max W^
                S U                   dup1 dup1 min S^  max U^
                O Q                   dup1 dup1 min O^  max Q^
                L N                   dup1 dup1 min L^  max N^
                E M                   dup1 dup1 min E^  max M^
                H J                   dup1 dup1 min H^  max J^
                A G                   dup1 dup1 min A^  max G^
                BB DD                           min BB^
                Z CC                            min Z^
                Q AA                  dup1 dup1 min Q^  max AA^
                O W                   dup1 dup1 min O^  max W^
                R V                             min R^
                T U                   dup1 dup1 min T^  max U^
                F N                   dup1 dup1 min F^  max N^
                D L                   dup1 dup1 min D^  max L^
                G K                                     max K^
                H I                   dup1 dup1 min H^  max I^
                B E                                     max E^
                A C                                     max C^
                U AA                            min U^
                Q Z                   dup1 dup1 min Q^  max Z^
                R W                   dup1 dup1 min R^  max W^
                M T                   dup1 dup1 min M^  max T^
                N S                   dup1 dup1 min N^  max S^
                I P                   dup1 dup1 min I^  max P^
                J O                   dup1 dup1 min J^  max O^
                E L                   dup1 dup1 min E^  max L^
                F K                   dup1 dup1 min F^  max K^
                D H                                     max H^
                S BB                            min S^
                T Z                             min T^
                O W                             min O^
                K U                   dup1 dup1 min K^  max U^
                H R                   dup1 dup1 min H^  max R^
                M Q                   dup1 dup1 min M^  max Q^
                L P                   dup1 dup1 min L^  max P^
                F N                                     max N^
                C J                                     max J^
                E I                                     max I^
                P U                             min P^
                Q T                   dup1 dup1 min Q^  max T^
                O R                   dup1 dup1 min O^  max R^
                K N                   dup1 dup1 min K^  max N^
                H M                                     max M^
                I L                   dup1 dup1 min I^  max L^
                R T                             min R^
                P S                             min P^
                N Q                   dup1 dup1 min N^  max Q^
                L O                   dup1 dup1 min L^  max O^
                J M                                     max M^
                I K                                     max K^
                P R                             min P^
                O Q                             min O^
                L N                                     max N^
                K M                                     max M^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                N P                             min N^
                M O                                     max O^
                N O                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 31  ? "EE FF                 dup1 dup1 min EE^ max FF^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA BB                 dup1 dup1 min AA^ max BB^
                W Z                   dup1 dup1 min W^  max Z^
                U V                   dup1 dup1 min U^  max V^
                S T                   dup1 dup1 min S^  max T^
                Q R                   dup1 dup1 min Q^  max R^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                K L                   dup1 dup1 min K^  max L^
                I J                   dup1 dup1 min I^  max J^
                G H                   dup1 dup1 min G^  max H^
                E F                   dup1 dup1 min E^  max F^
                C D                   dup1 dup1 min C^  max D^
                A B                   dup1 dup1 min A^  max B^
                DD FF                 dup1 dup1 min DD^ max FF^
                CC EE                 dup1 dup1 min CC^ max EE^
                Z BB                  dup1 dup1 min Z^  max BB^
                W AA                  dup1 dup1 min W^  max AA^
                T V                   dup1 dup1 min T^  max V^
                S U                   dup1 dup1 min S^  max U^
                P R                   dup1 dup1 min P^  max R^
                O Q                   dup1 dup1 min O^  max Q^
                L N                   dup1 dup1 min L^  max N^
                K M                   dup1 dup1 min K^  max M^
                H J                   dup1 dup1 min H^  max J^
                G I                   dup1 dup1 min G^  max I^
                D F                   dup1 dup1 min D^  max F^
                C E                   dup1 dup1 min C^  max E^
                BB FF                 dup1 dup1 min BB^ max FF^
                AA EE                 dup1 dup1 min AA^ max EE^
                Z DD                  dup1 dup1 min Z^  max DD^
                W CC                  dup1 dup1 min W^  max CC^
                R V                   dup1 dup1 min R^  max V^
                Q U                   dup1 dup1 min Q^  max U^
                P T                   dup1 dup1 min P^  max T^
                O S                   dup1 dup1 min O^  max S^
                J N                   dup1 dup1 min J^  max N^
                I M                   dup1 dup1 min I^  max M^
                H L                   dup1 dup1 min H^  max L^
                G K                   dup1 dup1 min G^  max K^
                B F                   dup1 dup1 min B^  max F^
                A E                   dup1 dup1 min A^  max E^
                V FF                  dup1 dup1 min V^  max FF^
                U EE                  dup1 dup1 min U^  max EE^
                T DD                  dup1 dup1 min T^  max DD^
                S CC                  dup1 dup1 min S^  max CC^
                R BB                  dup1 dup1 min R^  max BB^
                Q AA                  dup1 dup1 min Q^  max AA^
                P Z                   dup1 dup1 min P^  max Z^
                O W                   dup1 dup1 min O^  max W^
                F N                   dup1 dup1 min F^  max N^
                E M                   dup1 dup1 min E^  max M^
                D L                   dup1 dup1 min D^  max L^
                C K                   dup1 dup1 min C^  max K^
                B J                   dup1 dup1 min B^  max J^
                A I                   dup1 dup1 min A^  max I^
                N FF                            min N^
                V EE                  dup1 dup1 min V^  max EE^
                BB DD                 dup1 dup1 min BB^ max DD^
                R CC                  dup1 dup1 min R^  max CC^
                T AA                  dup1 dup1 min T^  max AA^
                U Z                   dup1 dup1 min U^  max Z^
                P W                   dup1 dup1 min P^  max W^
                Q S                   dup1 dup1 min Q^  max S^
                F M                   dup1 dup1 min F^  max M^
                J L                   dup1 dup1 min J^  max L^
                B K                   dup1 dup1 min B^  max K^
                D I                   dup1 dup1 min D^  max I^
                E H                   dup1 dup1 min E^  max H^
                A C                   dup1 dup1 min A^  max C^
                DD EE                 dup1 dup1 min DD^ max EE^
                AA CC                 dup1 dup1 min AA^ max CC^
                V BB                  dup1 dup1 min V^  max BB^
                H Z                   dup1 dup1 min H^  max Z^
                S W                   dup1 dup1 min S^  max W^
                E U                   dup1 dup1 min E^  max U^
                R T                   dup1 dup1 min R^  max T^
                P Q                   dup1 dup1 min P^  max Q^
                L M                   dup1 dup1 min L^  max M^
                I K                   dup1 dup1 min I^  max K^
                F J                   dup1 dup1 min F^  max J^
                C G                   dup1 dup1 min C^  max G^
                B D                   dup1 dup1 min B^  max D^
                M EE                            min M^
                L DD                            min L^
                K CC                  dup1 dup1 min K^  max CC^
                J BB                  dup1 dup1 min J^  max BB^
                T AA                  dup1 dup1 min T^  max AA^
                G W                   dup1 dup1 min G^  max W^
                F V                   dup1 dup1 min F^  max V^
                C S                   dup1 dup1 min C^  max S^
                B R                   dup1 dup1 min B^  max R^
                A Q                                     max Q^
                D I                   dup1 dup1 min D^  max I^
                M CC                            min M^
                N BB                            min N^
                I AA                  dup1 dup1 min I^  max AA^
                L Z                             min L^
                U W                   dup1 dup1 min U^  max W^
                J V                             min J^
                D T                   dup1 dup1 min D^  max T^
                G S                                     max S^
                E Q                                     max Q^
                B P                                     max P^
                C O                                     max O^
                F H                   dup1 dup1 min F^  max H^
                N AA                            min N^
                M W                             min M^
                I U                   dup1 dup1 min I^  max U^
                H T                   dup1 dup1 min H^  max T^
                K S                   dup1 dup1 min K^  max S^
                J R                   dup1 dup1 min J^  max R^
                F P                                     max P^
                D O                                     max O^
                L U                   dup1 dup1 min L^  max U^
                M S                   dup1 dup1 min M^  max S^
                N R                             min N^
                H Q                   dup1 dup1 min H^  max Q^
                J P                   dup1 dup1 min J^  max P^
                K O                                     max O^
                N U                             min N^
                S T                             min S^
                M Q                   dup1 dup1 min M^  max Q^
                L P                   dup1 dup1 min L^  max P^
                H O                                     max O^
                I J                                     max J^
                Q S                   dup1 dup1 min Q^  max S^
                N P                   dup1 dup1 min N^  max P^
                M O                                     max O^
                J L                                     max L^
                P S                             min P^
                N Q                   dup1 dup1 min N^  max Q^
                L O                                     max O^
                N O                                     max
                P Q                             min

                X swap2 clip "                                : \
                                                                \
    n == 33  ? "GG HH                 dup1 dup1 min GG^ max HH^
                EE FF                 dup1 dup1 min EE^ max FF^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA BB                 dup1 dup1 min AA^ max BB^
                W Z                   dup1 dup1 min W^  max Z^
                U V                   dup1 dup1 min U^  max V^
                S T                   dup1 dup1 min S^  max T^
                Q R                   dup1 dup1 min Q^  max R^
                O P                   dup1 dup1 min O^  max P^
                M N                   dup1 dup1 min M^  max N^
                K L                   dup1 dup1 min K^  max L^
                I J                   dup1 dup1 min I^  max J^
                G H                   dup1 dup1 min G^  max H^
                E F                   dup1 dup1 min E^  max F^
                C D                   dup1 dup1 min C^  max D^
                A B                   dup1 dup1 min A^  max B^
                FF HH                 dup1 dup1 min FF^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                V Z                   dup1 dup1 min V^  max Z^
                U W                   dup1 dup1 min U^  max W^
                R T                   dup1 dup1 min R^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                N P                   dup1 dup1 min N^  max P^
                M O                   dup1 dup1 min M^  max O^
                J L                   dup1 dup1 min J^  max L^
                I K                   dup1 dup1 min I^  max K^
                F H                   dup1 dup1 min F^  max H^
                E G                   dup1 dup1 min E^  max G^
                B D                   dup1 dup1 min B^  max D^
                A C                   dup1 dup1 min A^  max C^
                DD HH                 dup1 dup1 min DD^ max HH^
                CC GG                 dup1 dup1 min CC^ max GG^
                BB FF                 dup1 dup1 min BB^ max FF^
                AA EE                 dup1 dup1 min AA^ max EE^
                T Z                   dup1 dup1 min T^  max Z^
                S W                   dup1 dup1 min S^  max W^
                R V                   dup1 dup1 min R^  max V^
                Q U                   dup1 dup1 min Q^  max U^
                L P                   dup1 dup1 min L^  max P^
                K O                   dup1 dup1 min K^  max O^
                J N                   dup1 dup1 min J^  max N^
                I M                   dup1 dup1 min I^  max M^
                D H                   dup1 dup1 min D^  max H^
                C G                   dup1 dup1 min C^  max G^
                B F                   dup1 dup1 min B^  max F^
                A E                   dup1 dup1 min A^  max E^
                Z HH                  dup1 dup1 min Z^  max HH^
                W GG                  dup1 dup1 min W^  max GG^
                V FF                  dup1 dup1 min V^  max FF^
                U EE                  dup1 dup1 min U^  max EE^
                T DD                  dup1 dup1 min T^  max DD^
                S CC                  dup1 dup1 min S^  max CC^
                R BB                  dup1 dup1 min R^  max BB^
                Q AA                  dup1 dup1 min Q^  max AA^
                H P                   dup1 dup1 min H^  max P^
                G O                   dup1 dup1 min G^  max O^
                F N                   dup1 dup1 min F^  max N^
                E M                   dup1 dup1 min E^  max M^
                D L                   dup1 dup1 min D^  max L^
                C K                   dup1 dup1 min C^  max K^
                B J                   dup1 dup1 min B^  max J^
                A I                   dup1 dup1 min A^  max I^
                P HH                            min P^
                Z GG                  dup1 dup1 min Z^  max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                T EE                  dup1 dup1 min T^  max EE^
                V CC                  dup1 dup1 min V^  max CC^
                W BB                  dup1 dup1 min W^  max BB^
                R AA                  dup1 dup1 min R^  max AA^
                S U                   dup1 dup1 min S^  max U^
                A Q                                     max Q^
                H O                   dup1 dup1 min H^  max O^
                L N                   dup1 dup1 min L^  max N^
                D M                   dup1 dup1 min D^  max M^
                F K                   dup1 dup1 min F^  max K^
                G J                   dup1 dup1 min G^  max J^
                B I                   dup1 dup1 min B^  max I^
                C E                   dup1 dup1 min C^  max E^
                FF GG                 dup1 dup1 min FF^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                Z DD                  dup1 dup1 min Z^  max DD^
                J BB                  dup1 dup1 min J^  max BB^
                U AA                  dup1 dup1 min U^  max AA^
                G W                   dup1 dup1 min G^  max W^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                N O                   dup1 dup1 min N^  max O^
                K M                   dup1 dup1 min K^  max M^
                H L                   dup1 dup1 min H^  max L^
                E I                   dup1 dup1 min E^  max I^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                O GG                            min O^
                N FF                            min N^
                M EE                  dup1 dup1 min M^  max EE^
                L DD                  dup1 dup1 min L^  max DD^
                V CC                  dup1 dup1 min V^  max CC^
                I AA                  dup1 dup1 min I^  max AA^
                H Z                   dup1 dup1 min H^  max Z^
                E U                   dup1 dup1 min E^  max U^
                D T                   dup1 dup1 min D^  max T^
                C S                                     max S^
                B R                                     max R^
                F K                   dup1 dup1 min F^  max K^
                O EE                            min O^
                P DD                            min P^
                K CC                  dup1 dup1 min K^  max CC^
                N BB                            min N^
                W AA                  dup1 dup1 min W^  max AA^
                L Z                             min L^
                F V                   dup1 dup1 min F^  max V^
                I U                                     max U^
                G S                                     max S^
                D R                                     max R^
                E Q                                     max Q^
                H J                   dup1 dup1 min H^  max J^
                P CC                            min P^
                O AA                            min O^
                K W                   dup1 dup1 min K^  max W^
                J V                   dup1 dup1 min J^  max V^
                M U                   dup1 dup1 min M^  max U^
                L T                   dup1 dup1 min L^  max T^
                H R                                     max R^
                F Q                                     max Q^
                N W                   dup1 dup1 min N^  max W^
                O U                   dup1 dup1 min O^  max U^
                P T                             min P^
                J S                   dup1 dup1 min J^  max S^
                L R                   dup1 dup1 min L^  max R^
                M Q                                     max Q^
                P W                             min P^
                U V                             min U^
                O S                   dup1 dup1 min O^  max S^
                N R                   dup1 dup1 min N^  max R^
                J Q                                     max Q^
                K L                                     max L^
                S U                             min S^
                P R                             min P^
                O Q                                     max Q^
                L N                                     max N^
                P S                             min P^
                N Q                                     max Q^
                P Q                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 35  ? "JJ A                  dup1 dup1 min JJ^ max A^
                B C                   dup1 dup1 min B^  max C^
                JJ B                  dup1 dup1 min JJ^ max B^
                A C                   dup1 dup1 min A^  max C^
                A B                   dup1 dup1 min A^  max B^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                D F                   dup1 dup1 min D^  max F^
                E G                   dup1 dup1 min E^  max G^
                E F                   dup1 dup1 min E^  max F^
                JJ D                  dup1 dup1 min JJ^ max D^
                B F                   dup1 dup1 min B^  max F^
                B D                   dup1 dup1 min B^  max D^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                H J                   dup1 dup1 min H^  max J^
                I K                   dup1 dup1 min I^  max K^
                I J                   dup1 dup1 min I^  max J^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                L N                   dup1 dup1 min L^  max N^
                M O                   dup1 dup1 min M^  max O^
                M N                   dup1 dup1 min M^  max N^
                H L                   dup1 dup1 min H^  max L^
                J N                   dup1 dup1 min J^  max N^
                J L                   dup1 dup1 min J^  max L^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                JJ H                  dup1 dup1 min JJ^ max H^
                D L                   dup1 dup1 min D^  max L^
                D H                   dup1 dup1 min D^  max H^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                P R                   dup1 dup1 min P^  max R^
                Q S                   dup1 dup1 min Q^  max S^
                Q R                   dup1 dup1 min Q^  max R^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                T V                   dup1 dup1 min T^  max V^
                U W                   dup1 dup1 min U^  max W^
                U V                   dup1 dup1 min U^  max V^
                P T                   dup1 dup1 min P^  max T^
                R V                   dup1 dup1 min R^  max V^
                R T                   dup1 dup1 min R^  max T^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                AA CC                 dup1 dup1 min AA^ max CC^
                AA BB                 dup1 dup1 min AA^ max BB^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                EE GG                 dup1 dup1 min EE^ max GG^
                EE FF                 dup1 dup1 min EE^ max FF^
                Z DD                  dup1 dup1 min Z^  max DD^
                BB FF                 dup1 dup1 min BB^ max FF^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                P Z                   dup1 dup1 min P^  max Z^
                T DD                  dup1 dup1 min T^  max DD^
                T Z                   dup1 dup1 min T^  max Z^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                 dup1 dup1 min BB^ max DD^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                JJ P                  dup1 dup1 min JJ^ max P^
                H Z                   dup1 dup1 min H^  max Z^
                H P                   dup1 dup1 min H^  max P^
                D T                   dup1 dup1 min D^  max T^
                L DD                            min L^
                L T                   dup1 dup1 min L^  max T^
                D H                   dup1 dup1 min D^  max H^
                L P                   dup1 dup1 min L^  max P^
                T Z                   dup1 dup1 min T^  max Z^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                            min V^
                B D                             min B^
                F H                                     max H^
                J L                   dup1 dup1 min J^  max L^
                N P                   dup1 dup1 min N^  max P^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                            min M^
                M U                   dup1 dup1 min M^  max U^
                E I                                     max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                                     max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                            min W^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                            min W^
                A B                             min A^
                G H                                     max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                HH II                 dup1 dup1 min HH^ max II^
                JJ HH                                   max HH^
                P HH                  dup1 dup1 min P^  max HH^
                H P                                     max P^
                Z HH                            min Z^
                L T                   dup1 dup1 min L^  max T^
                L P                                     max P^
                T Z                             min T^
                J R                                     max R^
                N V                             min N^
                N R                   dup1 dup1 min N^  max R^
                N P                                     max P^
                R T                             min R^
                A II                                    max II^
                Q II                            min Q^
                I Q                                     max Q^
                M U                             min M^
                M Q                                     max Q^
                K S                                     max S^
                O W                             min O^
                O S                             min O^
                O Q                   dup1 dup1 min O^  max Q^
                Q R                             min
                O P                                     max

                X swap2 clip "                                : \
                                                                \
    n == 37  ? "LL A                  dup1 dup1 min LL^ max A^
                B C                   dup1 dup1 min B^  max C^
                LL B                  dup1 dup1 min LL^ max B^
                A C                   dup1 dup1 min A^  max C^
                A B                   dup1 dup1 min A^  max B^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                D F                   dup1 dup1 min D^  max F^
                E G                   dup1 dup1 min E^  max G^
                E F                   dup1 dup1 min E^  max F^
                LL D                  dup1 dup1 min LL^ max D^
                B F                   dup1 dup1 min B^  max F^
                B D                   dup1 dup1 min B^  max D^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                H J                   dup1 dup1 min H^  max J^
                I K                   dup1 dup1 min I^  max K^
                I J                   dup1 dup1 min I^  max J^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                L N                   dup1 dup1 min L^  max N^
                M O                   dup1 dup1 min M^  max O^
                M N                   dup1 dup1 min M^  max N^
                H L                   dup1 dup1 min H^  max L^
                J N                   dup1 dup1 min J^  max N^
                J L                   dup1 dup1 min J^  max L^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                LL H                  dup1 dup1 min LL^ max H^
                D L                   dup1 dup1 min D^  max L^
                D H                   dup1 dup1 min D^  max H^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                P R                   dup1 dup1 min P^  max R^
                Q S                   dup1 dup1 min Q^  max S^
                Q R                   dup1 dup1 min Q^  max R^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                T V                   dup1 dup1 min T^  max V^
                U W                   dup1 dup1 min U^  max W^
                U V                   dup1 dup1 min U^  max V^
                P T                   dup1 dup1 min P^  max T^
                R V                   dup1 dup1 min R^  max V^
                R T                   dup1 dup1 min R^  max T^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                AA CC                 dup1 dup1 min AA^ max CC^
                AA BB                 dup1 dup1 min AA^ max BB^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                EE GG                 dup1 dup1 min EE^ max GG^
                EE FF                 dup1 dup1 min EE^ max FF^
                Z DD                  dup1 dup1 min Z^  max DD^
                BB FF                 dup1 dup1 min BB^ max FF^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                P Z                   dup1 dup1 min P^  max Z^
                T DD                  dup1 dup1 min T^  max DD^
                T Z                   dup1 dup1 min T^  max Z^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                 dup1 dup1 min BB^ max DD^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                LL P                  dup1 dup1 min LL^ max P^
                H Z                   dup1 dup1 min H^  max Z^
                H P                   dup1 dup1 min H^  max P^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                D H                             min D^
                L P                   dup1 dup1 min L^  max P^
                T Z                   dup1 dup1 min T^  max Z^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                                     max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                B D                   dup1 dup1 min B^  max D^
                J L                   dup1 dup1 min J^  max L^
                N P                   dup1 dup1 min N^  max P^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                           min BB^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                            min M^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                            min W^
                C E                             min C^
                G I                                     max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                A B                   dup1 dup1 min A^  max B^
                C D                             min C^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                           min AA^
                HH II                 dup1 dup1 min HH^ max II^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                HH JJ                 dup1 dup1 min HH^ max JJ^
                II KK                 dup1 dup1 min II^ max KK^
                II JJ                 dup1 dup1 min II^ max JJ^
                LL HH                                   max HH^
                P HH                                    max HH^
                Z HH                            min Z^
                L T                                     max T^
                T Z                             min T^
                B JJ                                    max JJ^
                R JJ                            min R^
                J R                                     max R^
                N V                             min N^
                N R                                     max R^
                R T                   dup1 dup1 min R^  max T^
                A II                                    max II^
                Q II                  dup1 dup1 min Q^  max II^
                I Q                                     max Q^
                AA II                           min AA^
                M U                   dup1 dup1 min M^  max U^
                M Q                             min M^
                U AA                            min U^
                C KK                                    max KK^
                S KK                            min S^
                K S                                     max S^
                O W                             min O^
                O S                   dup1 dup1 min O^  max S^
                O Q                                     max Q^
                S U                             min S^
                S T                             min
                Q R                                     max

                X swap2 clip "                                : \
                                                                \
    n == 39  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                             min G^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                           min CC^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                            min Z^
                D F                   dup1 dup1 min D^  max F^
                H J                                     max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                             min F^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                           min BB^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                II MM                 dup1 dup1 min II^ max MM^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                KK MM                 dup1 dup1 min KK^ max MM^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                KK MM                 dup1 dup1 min KK^ max MM^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                A II                                    max II^
                Q II                                    max II^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                  dup1 dup1 min U^  max MM^
                M U                                     max U^
                U AA                            min U^
                C KK                                    max KK^
                S KK                            min S^
                K S                                     max S^
                O W                             min O^
                O S                                     max S^
                S U                   dup1 dup1 min S^  max U^
                B JJ                                    max JJ^
                R JJ                  dup1 dup1 min R^  max JJ^
                J R                                     max R^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N V                   dup1 dup1 min N^  max V^
                N R                                     max R^
                V BB                            min V^
                D LL                                    max LL^
                T LL                  dup1 dup1 min T^  max LL^
                L T                                     max T^
                P Z                             min P^
                P T                   dup1 dup1 min P^  max T^
                P R                                     max R^
                T V                             min T^
                T U                             min
                R S                                     max

                X swap2 clip "                                : \
                                                                \
    n == 41  ? "PP A                  dup1 dup1 min PP^ max A^
                B C                   dup1 dup1 min B^  max C^
                PP B                  dup1 dup1 min PP^ max B^
                A C                   dup1 dup1 min A^  max C^
                A B                   dup1 dup1 min A^  max B^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                D F                   dup1 dup1 min D^  max F^
                E G                   dup1 dup1 min E^  max G^
                E F                   dup1 dup1 min E^  max F^
                PP D                  dup1 dup1 min PP^ max D^
                B F                   dup1 dup1 min B^  max F^
                B D                   dup1 dup1 min B^  max D^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                H J                   dup1 dup1 min H^  max J^
                I K                   dup1 dup1 min I^  max K^
                I J                   dup1 dup1 min I^  max J^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                L N                   dup1 dup1 min L^  max N^
                M O                   dup1 dup1 min M^  max O^
                M N                   dup1 dup1 min M^  max N^
                H L                   dup1 dup1 min H^  max L^
                J N                   dup1 dup1 min J^  max N^
                J L                   dup1 dup1 min J^  max L^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                PP H                  dup1 dup1 min PP^ max H^
                D L                   dup1 dup1 min D^  max L^
                D H                   dup1 dup1 min D^  max H^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                P R                   dup1 dup1 min P^  max R^
                Q S                   dup1 dup1 min Q^  max S^
                Q R                   dup1 dup1 min Q^  max R^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                T V                   dup1 dup1 min T^  max V^
                U W                   dup1 dup1 min U^  max W^
                U V                   dup1 dup1 min U^  max V^
                P T                   dup1 dup1 min P^  max T^
                R V                   dup1 dup1 min R^  max V^
                R T                   dup1 dup1 min R^  max T^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                Z BB                  dup1 dup1 min Z^  max BB^
                AA CC                 dup1 dup1 min AA^ max CC^
                AA BB                 dup1 dup1 min AA^ max BB^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                DD FF                 dup1 dup1 min DD^ max FF^
                EE GG                 dup1 dup1 min EE^ max GG^
                EE FF                 dup1 dup1 min EE^ max FF^
                Z DD                  dup1 dup1 min Z^  max DD^
                BB FF                 dup1 dup1 min BB^ max FF^
                BB DD                 dup1 dup1 min BB^ max DD^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                P Z                   dup1 dup1 min P^  max Z^
                T DD                  dup1 dup1 min T^  max DD^
                T Z                   dup1 dup1 min T^  max Z^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                 dup1 dup1 min BB^ max DD^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                EE FF                 dup1 dup1 min EE^ max FF^
                PP P                  dup1 dup1 min PP^ max P^
                H Z                   dup1 dup1 min H^  max Z^
                H P                   dup1 dup1 min H^  max P^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                D H                   dup1 dup1 min D^  max H^
                L P                   dup1 dup1 min L^  max P^
                T Z                   dup1 dup1 min T^  max Z^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                B D                   dup1 dup1 min B^  max D^
                F H                   dup1 dup1 min F^  max H^
                J L                   dup1 dup1 min J^  max L^
                N P                   dup1 dup1 min N^  max P^
                R T                   dup1 dup1 min R^  max T^
                V Z                   dup1 dup1 min V^  max Z^
                BB DD                           min BB^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                            min M^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                            min W^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                E F                   dup1 dup1 min E^  max F^
                G H                             min G^
                I J                                     max J^
                K L                   dup1 dup1 min K^  max L^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                AA BB                           min AA^
                HH II                 dup1 dup1 min HH^ max II^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                HH JJ                 dup1 dup1 min HH^ max JJ^
                II KK                 dup1 dup1 min II^ max KK^
                II JJ                 dup1 dup1 min II^ max JJ^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                LL NN                 dup1 dup1 min LL^ max NN^
                MM OO                 dup1 dup1 min MM^ max OO^
                MM NN                 dup1 dup1 min MM^ max NN^
                HH LL                 dup1 dup1 min HH^ max LL^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                MM NN                 dup1 dup1 min MM^ max NN^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                KK MM                 dup1 dup1 min KK^ max MM^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                MM NN                 dup1 dup1 min MM^ max NN^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                KK MM                 dup1 dup1 min KK^ max MM^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                MM NN                 dup1 dup1 min MM^ max NN^
                PP HH                                   max HH^
                P HH                                    max HH^
                Z HH                            min Z^
                D LL                                    max LL^
                T LL                            min T^
                L T                                     max T^
                T Z                             min T^
                B JJ                                    max JJ^
                R JJ                            min R^
                J R                                     max R^
                F NN                                    max NN^
                V NN                            min V^
                N V                             min N^
                N R                                     max R^
                R T                                     max T^
                A II                                    max II^
                Q II                                    max II^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M U                                     max U^
                U AA                            min U^
                C KK                                    max KK^
                S KK                            min S^
                K S                                     max S^
                G OO                                    max OO^
                W OO                            min W^
                O W                             min O^
                O S                                     max S^
                S U                             min S^
                S T                   dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 43  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                  dup1 dup1 min O^  max GG^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                           min CC^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                            min Z^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M U                                     max U^
                U AA                  dup1 dup1 min U^  max AA^
                C KK                                    max KK^
                S KK                  dup1 dup1 min S^  max KK^
                K S                                     max S^
                CC KK                           min CC^
                G OO                                    max OO^
                W OO                            min W^
                O W                   dup1 dup1 min O^  max W^
                O S                                     max S^
                W CC                            min W^
                S U                                     max U^
                W AA                            min W^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N V                                     max V^
                V BB                            min V^
                D LL                                    max LL^
                T LL                            min T^
                L T                                     max T^
                H PP                                    max PP^
                Z PP                            min Z^
                P Z                             min P^
                P T                                     max T^
                T V                   dup1 dup1 min T^  max V^
                V W                             min
                T U                                     max

                X swap2 clip "                                : \
                                                                \
    n == 45  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                           min CC^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                            min N^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                            min Z^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                SS TT                 dup1 dup1 min SS^ max TT^
                QQ SS                 dup1 dup1 min QQ^ max SS^
                RR TT                 dup1 dup1 min RR^ max TT^
                RR SS                 dup1 dup1 min RR^ max SS^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK SS                 dup1 dup1 min KK^ max SS^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL TT                 dup1 dup1 min LL^ max TT^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                NN RR                 dup1 dup1 min NN^ max RR^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M U                                     max U^
                U AA                                    max AA^
                C KK                                    max KK^
                S KK                                    max KK^
                K SS                                    max SS^
                CC SS                           min CC^
                CC KK                           min CC^
                G OO                                    max OO^
                W OO                            min W^
                O W                                     max W^
                W CC                            min W^
                W AA                            min W^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N V                                     max V^
                V BB                            min V^
                D LL                                    max LL^
                T LL                            min T^
                L TT                            min L^
                L T                                     max T^
                H PP                                    max PP^
                Z PP                            min Z^
                P Z                             min P^
                P T                                     max T^
                T V                                     max V^
                V W                 dup1 dup1 max swap2 min

                X swap2 clip "                                : \
                                                                \
    n == 47  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG                            min O^
                O W                   dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                  dup1 dup1 min N^  max FF^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH                            min P^
                P Z                   dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                  dup1 dup1 min Z^  max DD^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                           min DD^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                           min DD^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                SS TT                 dup1 dup1 min SS^ max TT^
                QQ SS                 dup1 dup1 min QQ^ max SS^
                RR TT                 dup1 dup1 min RR^ max TT^
                RR SS                 dup1 dup1 min RR^ max SS^
                UU VV                 dup1 dup1 min UU^ max VV^
                QQ UU                 dup1 dup1 min QQ^ max UU^
                SS UU                 dup1 dup1 min SS^ max UU^
                RR VV                 dup1 dup1 min RR^ max VV^
                TT VV                 dup1 dup1 min TT^ max VV^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM UU                 dup1 dup1 min MM^ max UU^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK SS                 dup1 dup1 min KK^ max SS^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN VV                 dup1 dup1 min NN^ max VV^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL TT                 dup1 dup1 min LL^ max TT^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                NN RR                 dup1 dup1 min NN^ max RR^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M UU                            min M^
                M U                                     max U^
                U AA                                    max AA^
                C KK                                    max KK^
                S KK                                    max KK^
                K SS                                    max SS^
                CC SS                           min CC^
                CC KK                 dup1 dup1 min CC^ max KK^
                G OO                                    max OO^
                W OO                            min W^
                O W                                     max W^
                W CC                            min W^
                W AA                  dup1 dup1 min W^  max AA^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N VV                            min N^
                N V                                     max V^
                V BB                  dup1 dup1 min V^  max BB^
                D LL                                    max LL^
                T LL                  dup1 dup1 min T^  max LL^
                L TT                  dup1 dup1 min L^  max TT^
                DD TT                           min DD^
                L T                                     max T^
                DD LL                           min DD^
                H PP                                    max PP^
                Z PP                            min Z^
                P Z                   dup1 dup1 min P^  max Z^
                P T                                     max T^
                Z DD                            min Z^
                T V                                     max V^
                Z BB                            min Z^
                Z AA                            min
                V W                                     max

                X swap2 clip "                                : \
                                                                \
    n == 49  ? "A B                   dup1 dup1 min A^  max B^
                C D                   dup1 dup1 min C^  max D^
                A C                   dup1 dup1 min A^  max C^
                B D                   dup1 dup1 min B^  max D^
                B C                   dup1 dup1 min B^  max C^
                E F                   dup1 dup1 min E^  max F^
                G H                   dup1 dup1 min G^  max H^
                E G                   dup1 dup1 min E^  max G^
                F H                   dup1 dup1 min F^  max H^
                F G                   dup1 dup1 min F^  max G^
                A E                   dup1 dup1 min A^  max E^
                C G                   dup1 dup1 min C^  max G^
                C E                   dup1 dup1 min C^  max E^
                B F                   dup1 dup1 min B^  max F^
                D H                   dup1 dup1 min D^  max H^
                D F                   dup1 dup1 min D^  max F^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                I J                   dup1 dup1 min I^  max J^
                K L                   dup1 dup1 min K^  max L^
                I K                   dup1 dup1 min I^  max K^
                J L                   dup1 dup1 min J^  max L^
                J K                   dup1 dup1 min J^  max K^
                M N                   dup1 dup1 min M^  max N^
                O P                   dup1 dup1 min O^  max P^
                M O                   dup1 dup1 min M^  max O^
                N P                   dup1 dup1 min N^  max P^
                N O                   dup1 dup1 min N^  max O^
                I M                   dup1 dup1 min I^  max M^
                K O                   dup1 dup1 min K^  max O^
                K M                   dup1 dup1 min K^  max M^
                J N                   dup1 dup1 min J^  max N^
                L P                   dup1 dup1 min L^  max P^
                L N                   dup1 dup1 min L^  max N^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                A I                   dup1 dup1 min A^  max I^
                E M                   dup1 dup1 min E^  max M^
                E I                   dup1 dup1 min E^  max I^
                C K                   dup1 dup1 min C^  max K^
                G O                   dup1 dup1 min G^  max O^
                G K                   dup1 dup1 min G^  max K^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                B J                   dup1 dup1 min B^  max J^
                F N                   dup1 dup1 min F^  max N^
                F J                   dup1 dup1 min F^  max J^
                D L                   dup1 dup1 min D^  max L^
                H P                   dup1 dup1 min H^  max P^
                H L                   dup1 dup1 min H^  max L^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                Q R                   dup1 dup1 min Q^  max R^
                S T                   dup1 dup1 min S^  max T^
                Q S                   dup1 dup1 min Q^  max S^
                R T                   dup1 dup1 min R^  max T^
                R S                   dup1 dup1 min R^  max S^
                U V                   dup1 dup1 min U^  max V^
                W Z                   dup1 dup1 min W^  max Z^
                U W                   dup1 dup1 min U^  max W^
                V Z                   dup1 dup1 min V^  max Z^
                V W                   dup1 dup1 min V^  max W^
                Q U                   dup1 dup1 min Q^  max U^
                S W                   dup1 dup1 min S^  max W^
                S U                   dup1 dup1 min S^  max U^
                R V                   dup1 dup1 min R^  max V^
                T Z                   dup1 dup1 min T^  max Z^
                T V                   dup1 dup1 min T^  max V^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                AA BB                 dup1 dup1 min AA^ max BB^
                CC DD                 dup1 dup1 min CC^ max DD^
                AA CC                 dup1 dup1 min AA^ max CC^
                BB DD                 dup1 dup1 min BB^ max DD^
                BB CC                 dup1 dup1 min BB^ max CC^
                EE FF                 dup1 dup1 min EE^ max FF^
                GG HH                 dup1 dup1 min GG^ max HH^
                EE GG                 dup1 dup1 min EE^ max GG^
                FF HH                 dup1 dup1 min FF^ max HH^
                FF GG                 dup1 dup1 min FF^ max GG^
                AA EE                 dup1 dup1 min AA^ max EE^
                CC GG                 dup1 dup1 min CC^ max GG^
                CC EE                 dup1 dup1 min CC^ max EE^
                BB FF                 dup1 dup1 min BB^ max FF^
                DD HH                 dup1 dup1 min DD^ max HH^
                DD FF                 dup1 dup1 min DD^ max FF^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                Q AA                  dup1 dup1 min Q^  max AA^
                U EE                  dup1 dup1 min U^  max EE^
                U AA                  dup1 dup1 min U^  max AA^
                S CC                  dup1 dup1 min S^  max CC^
                W GG                  dup1 dup1 min W^  max GG^
                W CC                  dup1 dup1 min W^  max CC^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                R BB                  dup1 dup1 min R^  max BB^
                V FF                  dup1 dup1 min V^  max FF^
                V BB                  dup1 dup1 min V^  max BB^
                T DD                  dup1 dup1 min T^  max DD^
                Z HH                  dup1 dup1 min Z^  max HH^
                Z DD                  dup1 dup1 min Z^  max DD^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                DD FF                 dup1 dup1 min DD^ max FF^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                DD EE                 dup1 dup1 min DD^ max EE^
                FF GG                 dup1 dup1 min FF^ max GG^
                A Q                   dup1 dup1 min A^  max Q^
                I AA                  dup1 dup1 min I^  max AA^
                I Q                   dup1 dup1 min I^  max Q^
                E U                   dup1 dup1 min E^  max U^
                M EE                  dup1 dup1 min M^  max EE^
                M U                   dup1 dup1 min M^  max U^
                E I                   dup1 dup1 min E^  max I^
                M Q                   dup1 dup1 min M^  max Q^
                U AA                  dup1 dup1 min U^  max AA^
                C S                   dup1 dup1 min C^  max S^
                K CC                  dup1 dup1 min K^  max CC^
                K S                   dup1 dup1 min K^  max S^
                G W                   dup1 dup1 min G^  max W^
                O GG min W            dup1 dup1 min O^  max W^
                G K                   dup1 dup1 min G^  max K^
                O S                   dup1 dup1 min O^  max S^
                W CC                  dup1 dup1 min W^  max CC^
                C E                   dup1 dup1 min C^  max E^
                G I                   dup1 dup1 min G^  max I^
                K M                   dup1 dup1 min K^  max M^
                O Q                   dup1 dup1 min O^  max Q^
                S U                   dup1 dup1 min S^  max U^
                W AA                  dup1 dup1 min W^  max AA^
                CC EE                 dup1 dup1 min CC^ max EE^
                B R                   dup1 dup1 min B^  max R^
                J BB                  dup1 dup1 min J^  max BB^
                J R                   dup1 dup1 min J^  max R^
                F V                   dup1 dup1 min F^  max V^
                N FF                  dup1 dup1 min N^  max FF^
                N V                   dup1 dup1 min N^  max V^
                F J                   dup1 dup1 min F^  max J^
                N R                   dup1 dup1 min N^  max R^
                V BB                  dup1 dup1 min V^  max BB^
                D T                   dup1 dup1 min D^  max T^
                L DD                  dup1 dup1 min L^  max DD^
                L T                   dup1 dup1 min L^  max T^
                H Z                   dup1 dup1 min H^  max Z^
                P HH min Z            dup1 dup1 min P^  max Z^
                H L                   dup1 dup1 min H^  max L^
                P T                   dup1 dup1 min P^  max T^
                Z DD                  dup1 dup1 min Z^  max DD^
                D F                   dup1 dup1 min D^  max F^
                H J                   dup1 dup1 min H^  max J^
                L N                   dup1 dup1 min L^  max N^
                P R                   dup1 dup1 min P^  max R^
                T V                   dup1 dup1 min T^  max V^
                Z BB                  dup1 dup1 min Z^  max BB^
                B C                   dup1 dup1 min B^  max C^
                D E                   dup1 dup1 min D^  max E^
                F G                   dup1 dup1 min F^  max G^
                H I                   dup1 dup1 min H^  max I^
                J K                   dup1 dup1 min J^  max K^
                L M                   dup1 dup1 min L^  max M^
                N O                   dup1 dup1 min N^  max O^
                P Q                   dup1 dup1 min P^  max Q^
                R S                   dup1 dup1 min R^  max S^
                T U                   dup1 dup1 min T^  max U^
                V W                   dup1 dup1 min V^  max W^
                Z AA                  dup1 dup1 min Z^  max AA^
                BB CC                 dup1 dup1 min BB^ max CC^
                II JJ                 dup1 dup1 min II^ max JJ^
                KK LL                 dup1 dup1 min KK^ max LL^
                II KK                 dup1 dup1 min II^ max KK^
                JJ LL                 dup1 dup1 min JJ^ max LL^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                MM NN                 dup1 dup1 min MM^ max NN^
                OO PP                 dup1 dup1 min OO^ max PP^
                MM OO                 dup1 dup1 min MM^ max OO^
                NN PP                 dup1 dup1 min NN^ max PP^
                NN OO                 dup1 dup1 min NN^ max OO^
                II MM                 dup1 dup1 min II^ max MM^
                KK OO                 dup1 dup1 min KK^ max OO^
                KK MM                 dup1 dup1 min KK^ max MM^
                JJ NN                 dup1 dup1 min JJ^ max NN^
                LL PP                 dup1 dup1 min LL^ max PP^
                LL NN                 dup1 dup1 min LL^ max NN^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                QQ RR                 dup1 dup1 min QQ^ max RR^
                SS TT                 dup1 dup1 min SS^ max TT^
                QQ SS                 dup1 dup1 min QQ^ max SS^
                RR TT                 dup1 dup1 min RR^ max TT^
                RR SS                 dup1 dup1 min RR^ max SS^
                UU VV                 dup1 dup1 min UU^ max VV^
                WW YY                 dup1 dup1 min WW^ max YY^
                UU WW                 dup1 dup1 min UU^ max WW^
                VV YY                 dup1 dup1 min VV^ max YY^
                VV WW                 dup1 dup1 min VV^ max WW^
                QQ UU                 dup1 dup1 min QQ^ max UU^
                SS WW                 dup1 dup1 min SS^ max WW^
                SS UU                 dup1 dup1 min SS^ max UU^
                RR VV                 dup1 dup1 min RR^ max VV^
                TT YY                 dup1 dup1 min TT^ max YY^
                TT VV                 dup1 dup1 min TT^ max VV^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                VV WW                 dup1 dup1 min VV^ max WW^
                II QQ                 dup1 dup1 min II^ max QQ^
                MM UU                 dup1 dup1 min MM^ max UU^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                KK SS                 dup1 dup1 min KK^ max SS^
                OO WW                 dup1 dup1 min OO^ max WW^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                JJ RR                 dup1 dup1 min JJ^ max RR^
                NN VV                 dup1 dup1 min NN^ max VV^
                NN RR                 dup1 dup1 min NN^ max RR^
                LL TT                 dup1 dup1 min LL^ max TT^
                PP YY                 dup1 dup1 min PP^ max YY^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                VV WW                 dup1 dup1 min VV^ max WW^
                MM QQ                 dup1 dup1 min MM^ max QQ^
                OO SS                 dup1 dup1 min OO^ max SS^
                KK MM                 dup1 dup1 min KK^ max MM^
                OO QQ                 dup1 dup1 min OO^ max QQ^
                SS UU                 dup1 dup1 min SS^ max UU^
                NN RR                 dup1 dup1 min NN^ max RR^
                PP TT                 dup1 dup1 min PP^ max TT^
                LL NN                 dup1 dup1 min LL^ max NN^
                PP RR                 dup1 dup1 min PP^ max RR^
                TT VV                 dup1 dup1 min TT^ max VV^
                JJ KK                 dup1 dup1 min JJ^ max KK^
                LL MM                 dup1 dup1 min LL^ max MM^
                NN OO                 dup1 dup1 min NN^ max OO^
                PP QQ                 dup1 dup1 min PP^ max QQ^
                RR SS                 dup1 dup1 min RR^ max SS^
                TT UU                 dup1 dup1 min TT^ max UU^
                VV WW                 dup1 dup1 min VV^ max WW^
                A II                                    max II^
                Q II                                    max II^
                I QQ                                    max QQ^
                AA QQ                           min AA^
                AA II                           min AA^
                E MM                                    max MM^
                U MM                            min U^
                M UU                            min M^
                M U                                     max U^
                U AA                                    max AA^
                C KK                                    max KK^
                S KK                                    max KK^
                K SS                                    max SS^
                CC SS                           min CC^
                CC KK                           min CC^
                G OO                                    max OO^
                W OO                            min W^
                O WW                            min O^
                O W                                     max W^
                W CC                            min W^
                W AA                                    max AA^
                B JJ                                    max JJ^
                R JJ                                    max JJ^
                J RR                                    max RR^
                BB RR                           min BB^
                BB JJ                           min BB^
                F NN                                    max NN^
                V NN                            min V^
                N VV                            min N^
                N V                                     max V^
                V BB                                    max BB^
                D LL                                    max LL^
                T LL                                    max LL^
                L TT                                    max TT^
                DD FF min EE min TT min LL      min DD^
                H PP                                    max PP^
                Z PP                            min Z^
                P YY                            min P^
                P Z                                     max Z^
                Z DD                            min Z^
                Z BB                            min Z^
                Z AA                  dup1 dup1 max swap2 min

                X swap2 clip "                               : \
                                                               \
                Assert (false, "sel_med: "+string(n)+": Max input number reached.")

    return med }
