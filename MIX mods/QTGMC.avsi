#-------------------------------------------------------------------#
#                                                                   #
#     QTGMC 3.33        by Vit,   2012                              #
#     QTGMC 3.34d   mod by Dogway 2015                              #
#     QTGMC 3.382s  mod by A.SONY 2021, based on 3.34d              #
#     QTGMC 3.5 mix mod by Dogway 2021, based on 3.382s             #
#                                                                   #
#   A high quality deinterlacer using motion-compensated temporal   #
#  smoothing, with a range of features for quality and convenience  #
#          Originally based on TempGaussMC_beta2 by Didée           #
#                                                                   #
#-------------------------------------------------------------------#
#
# Full documentation is in the 'QTGMC' html file that may comes with this script, or even better see avisynth wiki
#
# --- LATEST CHANGES ---
#
# v3.5mx
# - Replaced masktools2 with Expr calls via ExTools pack wrappers (except mt_merge)
# - Merged redundant expressions
# - Replaced blurs and medians with ExTools equivalents
# - Replaced Vinverse_avsi() with ex_vinverse() (HBD) and vinverse() (8bit)
# - Removed Dither support
# - Formatting and small optimizations
#
# v3.382s
# - fix for n16 family
#
# v3.380s based on v3.34d (mod) by Dogway
# - Added Refinemotion Option for more accurate denoising.
#
# v3.378s
# - added tr0=-2 same as -1 but with Vinverse_avsi
# - added EdiExtPre to use Vinverse_avsi with useEdiExt
#
# v3.377s
# - added n16d (same as lsbd but use 16bit avs+ HBD)
# - added FastMA, use 8bit in Motion Analysing clip for faster Motion Analysis when using HBD Inputs
# - added ESearchP, using ErazorTT Suggestion for SearchParam for hex and umh
#
# v3.376s
# - fix keep_tv_range in avs+
#
# v3.375s
# - new EdiMode modes "BWDIF+NNEDI3" and "BWDIF+EEDI3" (need moded Vinverse_avsi)
# - fix RepYadif EdiMode for non YUY2 clip (it was same as Yadif)
#
# v3.371s
# - use sh_Bob
# - support sh_GetUserGlobalIMT (set_plugins_threads) and sh_GetUserGlobalIMTint (set_plugins_threads_int) and sh_GetUserGlobalIMTbool (set_plugins_threads_bool)
# - fix threads parameters bugs
#
# v3.368s
# - bug fix (thanks to missuse)
# - make it work with original mvtools2 (for manolito)
# - add keep_tv_range bool
# - add device_type and device_id
#
# v3.365s
# - support neo_FFT3D and neo_dfttest
#
# v3.363s
# - some changes in LUT things
#
# v3.362s
# - some changes for avs+ and avs neo, need IsAvsNeo(), IsAvsPlus() and AvsPlusVersionNumber(), they are in SMDegrain v3.1.2.101s or up
#
# v3.361s
# - update to masktools 2.2.17, use expr in avs+ (for speed up and less RAM usage)
#
# v3.358s
# - new n16 bool (avs+ faster replacement for lsb), and tr2=6
#
# v3.357s
# - high bit depth now basically work in avs+
#
# v3.354s
# - added optional chikuzen PlanarTools for YUY2 using nonyuy2clipin/nonyuy2clipout in AnimeIVTC() v2.20
#
# v3.353s
# - added ndjamena suggestion for maximum temporal radius
# - added DftDither to controle dfttest dither Parameter
#
# v3.352s
# - added useEdiExt
# - added tr0=-1 to use the EdiExt clip (if there is no EdiExt clip then it will not work)
# - rep0 now will be 0 if tr0 < 1
#
# v3.347s
# - fix SourceMatch (bug after new YUY2 method, thanks to ndjamena for report it)
#
# v3.346s
# - EEDI3+NNEDI3 bug fix by ndjamena
# - Renamed DftThreads parameter to FftThreads, to set the ncpu argument of FFT3DFilter (from VS)
# - FFT3DFilter will work now in YUY2, use it with Denoiser="fft3df" (or use NoisePreset)
#
# v3.345s
# - work with SH_KNLMeansCL now to process chroma too
#
# v3.343s
# - edit in ChromaEdi
# - others
#
# v3.34s (mod) 2016 12 18 (ravewulf idea in another way)
# - Added yadifmod2 (if you need old one use it like this EdiMode="cYadif" or EdiMode="RepcYadif")
# - fast and clean up YUY2 (will work in x64 now, no need to SSETools)
#
# v3.33s (mod) 2016 12 06
# - Add TR2=4 and TR2=5
# - add TV_range bool and dither_luma_rebuild (from SMDegrain) Str and Amp
# - for avsplus now QTGMC_Bob is ready for any 420, not only yv12
#
# v3.33s (mod) 2016 04 11
# - Add KNLMeansCL as another Denoiser to NoiseProcess
# - others
#
# v3.33s (mod) 2016 01 19
# - make QTGMC_deflate/QTGMC_inflate work with YUY2 using masktool2 for avs 2.60
#
# v3.33s (mod) 2015 10 23
# - revert to QTGMC_deflate/QTGMC_inflate quoted from Dogway
#
# v3.33s (mod) 2015 9 10
# - fix Multiple QTGMC Calls
# - others fix
#
# v3.33s (mod) 2015 8 6
# - some changes in bob to speed up
#
# v3.33s (mod) 2015 8 4
# - fix bug in YUY2 with SourceMatch
# - add slice=false to ditherpost to avoid artefacts
#
# v3.33s (mod)
# - fix bob chroma
# - work with new masktool2 for avs 2.60 in YUY2
#
# v3.33d (mod)
# - Added 32 bit precision option through the lsbd (for dfttest and knlmeanscl) and lsb (mdegrain) options.
# - optimized some mask handling a bit as originally suggested by Vit
# - others
#
# v3.33
# - Increased maximum value for Rep0, Rep1 and Rep2 to 7 (from 5). Higher values help with flicker on static detail, potential for minor motion blur
# - Bug fix for the fact that Bob always outputs a BFF clip regardless of field order of input (thanks ajp_anton)
# - Improved generation of noise (NoiseDeint="Generate") for noise bypass / EZKeepGrain
# - Minor change to denoising
#
# v3.32
# - Bugfix with shutter blur and ChromaMotion (thanks Heaud)
# - Tweaked vector recalculation for shutter motion blur
# - Changed defaults for TR2 when using source-match
# - Minor bugfix with SLMode/SLRad on pass-through settings
#
# --- REQUIREMENTS ---
#
# Input colorspaces: YV12, YUY2, others as plugins supports
#
# Core plugins:
#   MVTools2   (2.7.45 or above)
#   MaskTools2 (v2.2.26 or above)
#   NNEDI3     (0.9.4.59 or above)
#   RgTools    (1.2 or above)
#   ExTools    (4.4 or above)
#   Vinverse
#
# Core scripts:
#   Zs_RF_Shared.avsi
#
# Additional plugins and scripts:
#   NNEDI2, NNEDI, EEDI3, EEDI2, TDeInt - if selected directly or via a source-match preset
#   yadifmod2 (0.2.7 or above) - for Preset="Ultra Fast" or if selected directly
#   FFT3DFilter - if selected for noise processing
#   dfttest (1.9.6 or above) - if selected for noise processing
#       For FFT3DFilter & ddftest you also need the FFTW3 library (FFTW.org). On Windows the file needed for both is libfftw3f-3.dll. However, for FFT3DFilter
#       the file needs to be called FFTW3.dll, so you will need two copies and rename one. On Windows put the files in your System32 or SysWow64 folder
#   KNLMeansCL - if selected for noise processing
#   AddGrainC - if NoiseDeint="Generate" selected for noise bypass
#   chikuzen PlanarTools - if you work with YUY2 source (not necessarily required but may improve speed)
#   BWDIF and vinverse() or ex_vinverse() - for EdiMode modes "BWDIF+NNEDI3" and "BWDIF+EEDI3"


# --- GETTING STARTED ---
#
# Install AviSynth and ensure you have at least the core plugins listed in the requirements section above. Put them in the plugins autoload folder.
# To use QTGMC write a script like this:
#   YourSource("yourfile")   # DGDecode_mpeg2source, FFVideoSource, AviSource, whatever your source requires
#   QTGMC( Preset="Slow" )
#   SelectEven()             # Add this line to keep original frame rate, leave it out for smoother doubled frame rate
#
# Save this script with an ".avs" extension. You can now use it as an AVI source for encoding.
#
# The "Preset" used selects sensible settings for a given encoding speed. Choose a preset from:
#   "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast" & "Draft"
# The default preset is "Slower"
# Don't be obsessed with using slower settings as the differences can be small. HD material benefits little from extreme settings (and will be very slow)
# For much faster speeds read the full documentation, the section on 'Multi-threading'
#
# There are many settings for tweaking the script, full details in the main documentation. You can display settings currently being used with "ShowSettings":
#   QTGMC( Preset="Slow", ShowSettings=true )


function QTGMC( clip Input, string "Preset", int "TR0", int "TR1", int "TR2", int "Rep0", int "Rep1", int "Rep2", string "EdiMode", bool "RepChroma", \
                    int "NNSize", int "NNeurons", int "EdiQual", int "EdiMaxD", string "ChromaEdi", int "EdiThreads", clip "EdiExt", float "Sharpness", \
                    int "SMode", int "SLMode", int "SLRad", int "SOvs", float "SVThin", int "Sbb", int "SrchClipPP", int "SubPel", int "SubPelInterp", \
                    int "BlockSize", int "Overlap", int "Search", int "SearchParam", int "PelSearch", bool "ChromaMotion", bool "TrueMotion", int "Lambda", \
                    int "LSAD", int "PNew", int "PLevel", bool "GlobalMotion", int "DCT", int "ThSAD1", int "ThSAD2", int "ThSCD1", int "ThSCD2", \
                    int "SourceMatch", string "MatchPreset", string "MatchEdi", string "MatchPreset2", string "MatchEdi2", int "MatchTR2", \
                    float "MatchEnhance", int "Lossless", int "NoiseProcess", float "EZDenoise", float "EZKeepGrain", string "NoisePreset", string "Denoiser", \
                    int "FftThreads", bool "DenoiseMC", int "NoiseTR", float "Sigma", bool "ChromaNoise", val "ShowNoise", float "GrainRestore", \
                    float "NoiseRestore", string "NoiseDeint", bool "StabilizeNoise", int "InputType", float "ProgSADMask", int "FPSDivisor", \
                    int "ShutterBlur", float "ShutterAngleSrc", float "ShutterAngleOut", int "SBlurLimit", bool "Border", bool "Precise", string "Tuning", \
                    bool "ShowSettings", string "GlobalNames", string "PrevGlobals", int "ForceTR", \
                    val "BT", val "DetailRestore", val "MotionBlur", val "MBlurLimit", val "NoiseBypass", float "Str", float "Amp", bool "TV_range", bool "useEdiExt", \
                    int "DftDither", bool "lsbd", bool "lsb", bool "n16", bool "keep_tv_range", String "device_type", int "device_id", bool "n16d", bool "ESearchP", bool "EdiExtPre", bool "Refinemotion", bool "fulls" )
{
    # EdiMode="RepcYadif"/"cYadif" require the Yadif plugin, which doesn't autoload. Typically the calling script would load it.

    # Temporary Warnings
    Assert( !Defined(BT),            "QTGMC: Setting BT has been replaced by setting NoiseTR" )
    Assert( !Defined(DetailRestore), "QTGMC: Setting DetailRestore has been renamed to GrainRestore" )
    Assert( !Defined(MotionBlur),    "QTGMC: Setting MotionBlur has been renamed to ShutterBlur" )
    Assert( !Defined(MBlurLimit),    "QTGMC: Setting MBlurLimit has been renamed to SBlurLimit" )
    Assert( !Defined(NoiseBypass),   "QTGMC: Setting NoiseBypass has been renamed to NoiseProcess" )

    #---------------------------------------
    # Presets
    n16           = Default( n16,       false)
    n16d          = Default( n16d,      false)
    useEdiExt     = Default( useEdiExt, false)
    EdiExtPre     = Default( EdiExtPre, false)
    ESearchP      = Default( ESearchP,  false)
    fs            = Default( fulls,     false)
    Str           = Default( Str,        1.0 )
    Amp           = Default( Amp,     0.0625 )
    TV_range      = Default( TV_range, !(Isrgb(input)))
    keep_tv_range = Default( keep_tv_range,      false)

    # Dogways Added Defaults
    RefineMotion = Default( RefineMotion,        false)
    lsbd         = Default( lsbd, false)
    lsb          = Default( lsb,  false)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    bi      = Input.BitsPerComponent()
    bi8     = bi == 8

    # Select presets / tuning
    Preset = Default( Preset, "Slower" )
    pNum = (Preset == "Placebo"   ) ? 0 : \
           (Preset == "Very Slow" ) ? 1 : \
           (Preset == "Slower"    ) ? 2 : \
           (Preset == "Slow"      ) ? 3 : \
           (Preset == "Medium"    ) ? 4 : \
           (Preset == "Fast"      ) ? 5 : \
           (Preset == "Faster"    ) ? 6 : \
           (Preset == "Very Fast" ) ? 7 : \
           (Preset == "Super Fast") ? 8 : \
           (Preset == "Ultra Fast") ? 9 : \
           (Preset == "Draft"     ) ? 10 : 11
           Assert( pNum  < 11, "'Preset' choice is invalid" )

    mpNum1 = (!Defined(MatchPreset))       ? ((pNum + 3 <= 9) ? (pNum + 3) : 9) : \
             (MatchPreset == "Placebo"   ) ? 0 : \
             (MatchPreset == "Very Slow" ) ? 1 : \
             (MatchPreset == "Slower"    ) ? 2 : \
             (MatchPreset == "Slow"      ) ? 3 : \
             (MatchPreset == "Medium"    ) ? 4 : \
             (MatchPreset == "Fast"      ) ? 5 : \
             (MatchPreset == "Faster"    ) ? 6 : \
             (MatchPreset == "Very Fast" ) ? 7 : \
             (MatchPreset == "Super Fast") ? 8 : \
             (MatchPreset == "Ultra Fast") ? 9 : \
             (MatchPreset == "Draft"     ) ? 10 : 11
             Assert( mpNum1 < 10, "'MatchPreset' choice is invalid/unsupported" )

    MatchPreset = Select( mpNum1, "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast", "Draft" )

    mpNum2 = (!Defined(MatchPreset2))       ? ((mpNum1 + 2 <= 9) ? (mpNum1 + 2) : 9) : \
             (MatchPreset2 == "Placebo"   ) ? 0 : \
             (MatchPreset2 == "Very Slow" ) ? 1 : \
             (MatchPreset2 == "Slower"    ) ? 2 : \
             (MatchPreset2 == "Slow"      ) ? 3 : \
             (MatchPreset2 == "Medium"    ) ? 4 : \
             (MatchPreset2 == "Fast"      ) ? 5 : \
             (MatchPreset2 == "Faster"    ) ? 6 : \
             (MatchPreset2 == "Very Fast" ) ? 7 : \
             (MatchPreset2 == "Super Fast") ? 8 : \
             (MatchPreset2 == "Ultra Fast") ? 9 : \
             (MatchPreset2 == "Draft"     ) ? 10 : 11
    Assert( mpNum2 < 10, "'MatchPreset2' choice is invalid/unsupported" )
    MatchPreset2 = Select( mpNum2, "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast", "Draft" )

    NoisePreset = Default( NoisePreset, "Fast" )
    npNum = (NoisePreset == "Slower" ) ? 0 : \
            (NoisePreset == "Slow"   ) ? 1 : \
            (NoisePreset == "Medium" ) ? 2 : \
            (NoisePreset == "Fast"   ) ? 3 : \
            (NoisePreset == "Faster" ) ? 4 : 5
    Assert( npNum < 5, "'NoisePreset' choice is invalid" )

    Tuning = Default( Tuning, "None" )
    tNum = (Tuning == "None"  ) ? 0 : \
           (Tuning == "DV-SD" ) ? 1 : \
           (Tuning == "DV-HD" ) ? 2 : 3
    Assert( tNum < 3, "'Tuning' choice is invalid" )

    # Tunings only affect blocksize in this version
    bs  = Select( tNum,  16, 16, 32 )
    bs2 = (bs >= 16) ? 32 : bs * 2

    #                                                               Very                                                        Very      Super      Ultra
    # Preset groups:                                     Placebo    Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast       Fast       Draft
    TR0          = Default( TR0,          Select( pNum,  2,         2,        2,        2,        2,        2,        1,        1,        1,         1,         0          ) )
    TR1          = Default( TR1,          Select( pNum,  2,         2,        2,        1,        1,        1,        1,        1,        1,         1,         1          ) )
    TR2X         = Default( TR2,          Select( pNum,  3,         2,        1,        1,        1,        0,        0,        0,        0,         0,         0          ) )
    Rep0         = Defined(Rep0) ? Rep0 : TR0 < 1 ? 0 : undefined()
    Rep0         = Default( Rep0,         Select( pNum,  4,         4,        4,        4,        3,        3,        0,        0,        0,         0,         0          ) )
    Rep1         = Default( Rep1,         Select( pNum,  0,         0,        0,        0,        0,        0,        0,        0,        0,         0,         0          ) )
    Rep2         = Default( Rep2,         Select( pNum,  4,         4,        4,        4,        4,        4,        4,        4,        3,         3,         0          ) )
    EdiMode      = Default( EdiMode,      Select( pNum, "NNEDI3",  "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3",  "RepYadif","Bob"       ) )
    NNSize       = Default( NNSize,       Select( pNum,  1,         1,        1,        1,        5,        5,        4,        4,        4,         4,         4          ) )
    NNeurons     = Default( NNeurons,     Select( pNum,  2,         2,        1,        1,        1,        0,        0,        0,        0,         0,         0          ) )
    EdiQual      = Default( EdiQual,      Select( pNum,  1,         1,        1,        1,        1,        1,        1,        1,        1,         1,         1          ) )
    EdiMaxD      = Default( EdiMaxD,      Select( pNum,  12,        10,       8,        7,        7,        6,        6,        5,        4,         4,         4          ) )
    SMode        = Default( SMode,        Select( pNum,  2,         2,        2,        2,        2,        2,        2,        2,        2,         2,         0          ) )
    SLModeX      = Default( SLMode,       Select( pNum,  2,         2,        2,        2,        2,        2,        2,        2,        0,         0,         0          ) )
    SLRad        = Default( SLRad,        Select( pNum,  3,         1,        1,        1,        1,        1,        1,        1,        1,         1,         1          ) )
    Sbb          = Default( Sbb,          Select( pNum,  3,         1,        1,        0,        0,        0,        0,        0,        0,         0,         0          ) )
    SrchClipPP   = Default( SrchClipPP,   Select( pNum,  3,         3,        3,        3,        3,        2,        2,        2,        1,         1,         0          ) )
    SubPel       = Default( SubPel,       Select( pNum,  2,         2,        2,        2,        1,        1,        1,        1,        1,         1,         1          ) )
    Blocksize    = Default( Blocksize,    Select( pNum,  bs,        bs,       bs,       bs,       bs,       bs,       bs2,      bs2,      bs2,       bs2,       bs2        ) )
    bs = Blocksize
    Overlap      = Default( Overlap,      Select( pNum,  bs/2,      bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/4,     bs/4,      bs/4,      bs/4       ) )
    Search       = Default( Search,       Select( pNum,  5,         4,        4,        4,        4,        4,        4,        4,        0,         0,         0          ) )
    SearchParam  = Default( SearchParam,  Select( pNum,  2,         2,        2,        2,        2,        2,        2,        1,        1,         1,         1          ) )
    SearchParam  = ESearchP && (Search==4 || Search==5) ? pNum < 4 ? 24 : pNum < 8 ? 16 : SearchParam : SearchParam
    PelSearch    = Default( PelSearch,    Select( pNum,  2,         2,        2,        2,        1,        1,        1,        1,        1,         1,         1          ) )
    ChromaMotion = Default( ChromaMotion, Select( pNum,  true,      true,     true,     false,    false,    false,    false,    false,    false,     false,     false ) )
    Precise      = Default( Precise,      Select( pNum,  true,      true,     false,    false,    false,    false,    false,    false,    false,     false,     false ) )
    ProgSADMask  = Default( ProgSADMask,  Select( pNum,  10.0,      10.0,     10.0,     10.0,     10.0,     0.0,      0.0,      0.0,      0.0,       0.0,       0.0        ) )

    # Noise presets                                           Slower     Slow       Medium     Fast       Faster
    Denoiser       = Default( Denoiser,       Select( npNum, "dfttest", "dfttest", "dfttest", "fft3df",  "fft3df" ) )
    DenoiseMC      = Default( DenoiseMC,      Select( npNum,  true,      true,      false,     false,     false ) )
    NoiseTR        = Default( NoiseTR,        Select( npNum,  2,         1,         1,         1,         0       ) )
    NoiseDeint     = Default( NoiseDeint,     Select( npNum, "Generate","Bob",      "",        "",        ""      ) )
    StabilizeNoise = Default( StabilizeNoise, Select( npNum,  true,      true,      true,      false,     false ) )

    # The basic source-match step corrects and re-runs the interpolation of the input clip. So it initialy uses same interpolation settings as the main preset
    SourceMatch   = Default( SourceMatch, 0 )
    MatchNNSize   = NNSize
    MatchNNeurons = NNeurons
    MatchEdiMaxD  = EdiMaxD
    MatchEdiQual  = EdiQual

    # However, can use a faster initial interpolation when using source-match allowing the basic source-match step to "correct" it with higher quality settings
    Assert( SourceMatch == 0 || mpNum1 >= pNum, "'MatchPreset' cannot use a slower setting than 'Preset'" )
    #                                                                    Very                                                        Very      Super     Ultra
    # Basic source-match presets                                Placebo  Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast      Fast
    NNSize   = (SourceMatch == 0) ? NNSize   : Select( mpNum1,  1,       1,        1,        1,        5,        5,        4,        4,        4,        4     )
    NNeurons = (SourceMatch == 0) ? NNeurons : Select( mpNum1,  2,       2,        1,        1,        1,        0,        0,        0,        0,        0     )
    EdiMaxD  = (SourceMatch == 0) ? EdiMaxD  : Select( mpNum1,  12,      10,       8,        7,        7,        6,        6,        5,        4,        4     )
    EdiQual  = (SourceMatch == 0) ? EdiQual  : Select( mpNum1,  1,       1,        1,        1,        1,        1,        1,        1,        1,        1     )
    TempEdi  = EdiMode # Main interpolation is actually done by basic-source match step when enabled, so a little swap and wriggle is needed
    EdiMode  = (SourceMatch == 0) ? EdiMode  : Default( MatchEdi, ((mpNum1 < 9) ?  EdiMode : "Yadif") ) # Force Yadif for "Ultra Fast" basic source match
    MatchEdi = TempEdi

    #                                                          Very                                                        Very      Super     Ultra
    # Refined source-match presets                   Placebo   Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast      Fast
    MatchEdi2 = Default( MatchEdi2, Select( mpNum2, "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "TDeint",  ""    ) )
    MatchNNSize2                  = Select( mpNum2,  1,        1,        1,        1,        5,        5,        4,        4,        4,        4     )
    MatchNNeurons2                = Select( mpNum2,  2,        2,        1,        1,        1,        0,        0,        0,        0,        0     )
    MatchEdiMaxD2                 = Select( mpNum2,  12,       10,       8,        7,        7,        6,        6,        5,        4,        4     )
    MatchEdiQual2                 = Select( mpNum2,  1,        1,        1,        1,        1,        1,        1,        1,        1,        1     )


    #---------------------------------------
    # Settings

    # Core and Interpolation defaults
    TR2        = (SourceMatch > 0) ? Default(TR2, ((TR2X == 0) ? 1 : TR2X)) : TR2X  # ***TR2 defaults always at least 1 when using source-match***
    RepChroma  = Default( RepChroma,  true )
    EdiThreads = Default( EdiThreads, sh_GetUserGlobalIMTint(true)    )
    ChromaEdi  = Default( ChromaEdi,  ""   )
    NNeurons   = (EdiMode == "NNEDI2" && NNeurons > 2) ? 2 : NNeurons # Smaller range for NNeurons in NNEDI2 (which calls it nsize)
    EdiQual    = (EdiMode == "EEDI3+NNEDI3" || EdiMode == "NNEDI3" || EdiMode == "BWDIF+NNEDI3" || EdiMode == "BWDIF+EEDI3") && EdiQual > 2 ? 2 : EdiQual  # Smaller range for EdiQual in NNEDI3

    # Source-match / lossless defaults
    MatchTR1     = TR1
    MatchTR2     = Default( MatchTR2,     1   )
    MatchEnhance = Default( MatchEnhance, 0.5 )
    Lossless     = Default( Lossless,     0   )
    Assert( Lossless <= 2, "Lossless setting only supports mode 1 ('true lossless') and mode 2 ('fake lossless') - see documentation in script and consider source-match settings" )

    # Sharpness defaults. Sharpness default is always 1.0 (0.2 with source-match), but adjusted to give roughly same sharpness for all settings
    SMode      = (Defined(Sharpness) && Sharpness == 0.0) ? 0 : SMode
    SLMode     = (SourceMatch > 0) ? Default(SLMode, 0) : SLModeX  # ***Sharpness limiting disabled by default for source-match***
    SLMode     = (SLRad <= 0)      ? 0 : SLMode
    spatialSL  = (SLMode == 1 || SLMode == 3)
    temporalSL = (SLMode == 2 || SLMode == 4)
    Sharpness  = Default( Sharpness, (SMode == 0) ? 0.0 : ((SourceMatch > 0) ? 0.2 : 1.0) )      # Default sharpness is 1.0, or 0.2 if using source-match
    sharpMul   = (temporalSL) ? 2 : (spatialSL) ? 1.5 : 1                                        # Adjust sharpness based on other settings
    sharpAdj   = Sharpness * (sharpMul * (0.2 + TR1*0.15 + TR2*0.25) + ((SMode == 1) ? 0.1 : 0)) # [This needs a bit more refinement]
    Sbb        = (SMode == 0) ? 0 : Sbb
    SOvs       = Default( SOvs,   0   )
    SVThin     = Default( SVThin, 0.0 )

    # Noise processing settings
    Assert( !Defined(EZDenoise) || EZDenoise <= 0.0 || !Defined(EZKeepGrain) || EZKeepGrain <= 0.0, "QTGMC: EZDenoise and EZKeepGrain cannot be used together" )
    NoiseProcess =  Defined(NoiseProcess) ? NoiseProcess              : \
                   (Defined(EZDenoise)   && EZDenoise   > 0.0)    ? 1 : \
                   (Defined(EZKeepGrain) && EZKeepGrain > 0.0)    ? 2 : \
                   (Preset == "Placebo" || Preset == "Very Slow") ? 2 : 0
    GrainRestore =  Defined(GrainRestore) ? GrainRestore              : \
                   (Defined(EZDenoise)   && EZDenoise   > 0.0) ? 0.0  : \
                   (Defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 0.3 * sqrt(EZKeepGrain) : \
                                                                Select( NoiseProcess, 0.0, 0.7, 0.3 )
    NoiseRestore =  Defined(NoiseRestore) ? NoiseRestore              : \
                   (Defined(EZDenoise)   && EZDenoise   > 0.0) ? 0.0  : \
                   (Defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 0.1 * sqrt(EZKeepGrain) : \
                                                                Select( NoiseProcess, 0.0, 0.3, 0.1 )
    Sigma        =  Defined(Sigma)       ? Sigma                      : \
                   (Defined(EZDenoise)   && EZDenoise   > 0.0) ? EZDenoise : \
                   (Defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 4.0 * EZKeepGrain : 2.0
    FftThreads   = Default( FftThreads, EdiThreads )
    bomt         = sh_GetUserGlobalIMTbool()
    ChromaNoise  = Default( ChromaNoise, false )
    ShowNoise    = Default( ShowNoise, 0.0 )
    ShowNoise    = IsBool( ShowNoise ) ? (ShowNoise ? 10.0 : 0.0) : ShowNoise
    NoiseProcess = (ShowNoise > 0.0)   ? 2   : NoiseProcess
    NoiseRestore = (ShowNoise > 0.0)   ? 1.0 : NoiseRestore
    NoiseTR      = (NoiseProcess == 0) ? 0   : NoiseTR
    GrainRestore = (NoiseProcess == 0) ? 0.0 : GrainRestore
    NoiseRestore = (NoiseProcess == 0) ? 0.0 : NoiseRestore
    totalRestore = GrainRestore + NoiseRestore
    StabilizeNoise = (totalRestore <= 0) ? false : StabilizeNoise
    noiseTD      = Select( NoiseTR, 1, 3, 5 )
    noiseCentre  = (Denoiser == "dfttest") ? "128" : "128.5"

    # MVTools settings
    SubPelInterp = Default( SubPelInterp, 2     )
    TrueMotion   = Default( TrueMotion,   false )
    GlobalMotion = Default( GlobalMotion, true  )
    Lambda       = Default( Lambda, ((TrueMotion) ? 1000 : 100 ) * (BlockSize*BlockSize)/(8*8) )
    LSAD         = Default( LSAD,    (TrueMotion) ? 1200 : 400 )
    PNew         = Default( PNew,    (TrueMotion) ? 50   : 25  )
    PLevel       = Default( PLevel,  (TrueMotion) ? 1    : 0   )
    DCT          = Default( DCT,     0          )
    ThSAD1       = Default( ThSAD1,  10 * 8*8   )
    ThSAD2       = Default( ThSAD2,   4 * 8*8   )
    ThSCD1       = Default( ThSCD1,  180        )
    ThSCD2       = Default( ThSCD2,  98         )

    # Motion blur settings
    FPSDivisor      = Default( FPSDivisor, 1 )
    ShutterBlur     = Default( ShutterBlur, 0 )
    ShutterAngleSrc = Default( ShutterAngleSrc, 180 )
    ShutterAngleOut = Default( ShutterAngleOut, 180 )
    SBlurLimit      = Default( SBlurLimit, 4 )
    ShutterBlur     = (ShutterAngleOut * FPSDivisor == ShutterAngleSrc) ? 0 : ShutterBlur  # If motion blur output is same as input

    # Miscellaneous
    InputType      = Default( InputType,     0        )
    Border         = Default( Border,        false    )
    ShowSettings   = Default( ShowSettings,  false    )
    GlobalNames    = Default( GlobalNames,  "QTGMC"   )
    PrevGlobals    = Default( PrevGlobals,  "Replace" )
    ForceTR        = Default( ForceTR,       0        )
    ReplaceGlobals = (PrevGlobals == "Replace" || PrevGlobals == "Reuse") # If reusing existing globals put them back afterwards - simplifies logic later
    ReuseGlobals   = (PrevGlobals == "Reuse")
    ProgSADMask    = (InputType != 2 && InputType != 3) ? 0.0 : ProgSADMask

    # Dogways RefineMotion Defaults
    halfoverlap = Overlap/2
    halfblksize = BlockSize/2
    halfthSAD   = round(thSAD2/2)

    # Get maximum temporal radius needed
    maxTR = (temporalSL)       ? SLRad : 0
    maxTR = max(MatchTR2, TR1, TR2, NoiseTR, maxTR)
    maxTR = (ProgSADMask > 0.0 || StabilizeNoise || ShutterBlur > 0) ? (maxTR > 1 ? maxTR : 1) : maxTR
    maxTR = max(ForceTR, MaxTR)


    #---------------------------------------
    # Pre-Processing

    w = Input.Width()
    h = Input.Height()
    yuy2 = Input.IsYUY2()
    epsilon = 0.0001

    # Reverse "field" dominance for progressive repair mode 3 (only difference from mode 2)
    compl = (InputType == 3) ? Input.ComplementParity() : Input

    # Pad vertically during processing (to prevent artefacts at top & bottom edges)
    clip = (Border) ? compl.PointResize( w,h+8, 0,-4,0,h+8+epsilon ) : compl
    h    = (Border) ? h+8 : h

    # Calculate padding needed for MVTools super clips to avoid crashes [fixed in latest MVTools, but keeping this code for a while]
    hpad = w - (Int((w - Overlap) / (Blocksize - Overlap)) * (Blocksize - Overlap) + Overlap)
    vpad = h - (Int((h - Overlap) / (Blocksize - Overlap)) * (Blocksize - Overlap) + Overlap)
    hpad = (hpad > 8) ? hpad : 8 # But match default padding if possible
    vpad = (vpad > 8) ? vpad : 8


    #---------------------------------------
    # Motion Analysis

    # >>> Planar YUY2 for motion analysis, interleaved whilst blurring search clip
    planarClip = yuy2 ? clip.nonyuy2clipin(true) : clip

    # Bob the input as a starting point for motion search clip
    bobbed = (InputType == 0) ? useEdiExt ? isyuy2(EdiExt) ? EdiExt.nonyuy2clipin(true) : EdiExt : planarClip.sh_Bob( 0,0.5 ) : \
             (InputType == 1) ? planarClip                                                                                    : \
                                planarClip.ex_boxblur( 0, 1, "weighted", UV=3)
    bobbed = (InputType == 0) && useEdiExt && EdiExtPre ? bi8 ? bobbed.vinverse() : bobbed.ex_vinverse() : bobbed

    # If required, get any existing global clips with a matching "GlobalNames" setting. Unmatched values get NOP (= 0)
    srchClip  = QTGMC_GetUserGlobal( GlobalNames, "srchClip",  ReuseGlobals )
    srchSuper = QTGMC_GetUserGlobal( GlobalNames, "srchSuper", ReuseGlobals )
    bVec1     = QTGMC_GetUserGlobal( GlobalNames, "bVec1",     ReuseGlobals )
    fVec1     = QTGMC_GetUserGlobal( GlobalNames, "fVec1",     ReuseGlobals )
    bVec2     = QTGMC_GetUserGlobal( GlobalNames, "bVec2",     ReuseGlobals )
    fVec2     = QTGMC_GetUserGlobal( GlobalNames, "fVec2",     ReuseGlobals )
    bVec3     = QTGMC_GetUserGlobal( GlobalNames, "bVec3",     ReuseGlobals )
    fVec3     = QTGMC_GetUserGlobal( GlobalNames, "fVec3",     ReuseGlobals )
    bVec4     = QTGMC_GetUserGlobal( GlobalNames, "bVec4",     ReuseGlobals )
    fVec4     = QTGMC_GetUserGlobal( GlobalNames, "fVec4",     ReuseGlobals )
    bVec5     = QTGMC_GetUserGlobal( GlobalNames, "bVec5",     ReuseGlobals )
    fVec5     = QTGMC_GetUserGlobal( GlobalNames, "fVec5",     ReuseGlobals )
    bVec6     = QTGMC_GetUserGlobal( GlobalNames, "bVec6",     ReuseGlobals )
    fVec6     = QTGMC_GetUserGlobal( GlobalNames, "fVec6",     ReuseGlobals )
    srchcheck = IsClip(srchClip)

    CMmt = ChromaMotion ? 3   :  1
    CMts = ChromaMotion ? 255 :  0
    CMrg = ChromaMotion ? 12  : -1

    # The bobbed clip will shimmer due to being derived from alternating fields. Temporally smooth over the neighboring frames using a binomial kernel. Binomial
    # kernels give equal weight to even and odd frames and hence average away the shimmer. The two kernels used are [1 2 1] and [1 4 6 4 1] for radius 1 and 2.
    # These kernels are approximately Gaussian kernels, which work well as a prefilter before motion analysis (hence the original name for this script)
    # Create linear weightings of neighbors first                                          -2    -1     0    1     2
    ts1 = (!srchcheck && TR0 > 0) ? bobbed.TemporalSoften( 1, 255,CMts, 28, 2 ) : nop()  # 0.00  0.33  0.33  0.33  0.00
    ts2 = (!srchcheck && TR0 > 1) ? bobbed.TemporalSoften( 2, 255,CMts, 28, 2 ) : nop()  # 0.20  0.20  0.20  0.20  0.20

    # Combine linear weightings to give binomial weightings - TR0=0: (1), TR0=1: (1:2:1), TR0=2: (1:4:6:4:1)
    domtr02 = TR0 == -2 && !(InputType == 0 && useEdiExt && EdiExtPre)
    domtr01 = TR0 == -1 && !(InputType == 0 && useEdiExt && EdiExtPre)
    binomial0 = srchcheck        ? nop() : \
      domtr02 && Defined(EdiExt) ? isyuy2(EdiExt) ? bi8 ? EdiExt.nonyuy2clipin(true).vinverse() : EdiExt.nonyuy2clipin(true).ex_vinverse() : bi8 ? EdiExt.vinverse() : EdiExt.ex_vinverse() : TR0 == -2 ? bobbed : \
      domtr01 && Defined(EdiExt) ? isyuy2(EdiExt) ? EdiExt.nonyuy2clipin(true) : EdiExt : TR0 == -1 ? bobbed : \
                (TR0 == 0)       ? bobbed                                                                                                                 : \
                (TR0 == 1)       ? (ChromaMotion ? ts1.Merge( bobbed, 0.25 ) : ts1.MergeLuma( bobbed, 0.25 ))                                             : \
                                   (ChromaMotion ? ts1.Merge( ts2, 0.357 ).Merge( bobbed, 0.125 ) : ts1.MergeLuma( ts2, 0.357 ).MergeLuma( bobbed, 0.125 ))

    # Remove areas of difference between temporal blurred motion search clip and bob that are not due to bob-shimmer - removes general motion blur
    repair0 = (srchcheck || Rep0 == 0) ? binomial0 : binomial0.QTGMC_KeepOnlyBobShimmerFixes( bobbed, Rep0, (RepChroma && ChromaMotion), fs )

    # Blur image and soften edges to assist in motion matching of edge blocks. Blocks are matched by SAD (sum of absolute differences between blocks), but even
    # a slight change in an edge from frame to frame will give a high SAD due to the higher contrast of edges
    spatialBlur = (SrchClipPP == 0 || srchcheck) ? nop()                                                               : \
                  (SrchClipPP == 1) ? repair0.BilinearResize( w/2, h/2 ).RemoveGrain( 12, CMrg).BilinearResize( w, h ) : \
                                      repair0.RemoveGrain( 12, CMrg).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=2 )

    spatialBlur = (SrchClipPP > 1 && IsClip(spatialBlur)) ? (ChromaMotion ? spatialBlur.Merge( repair0, 0.1 ) : spatialBlur.MergeLuma( repair0, 0.1 ))          : spatialBlur
    tweaked     = (SrchClipPP > 1 && !srchcheck)          ? ex_lutxy( repair0, bobbed, "x 3 scalef + A@ y < A x 3 scalef - B@ y > B y ? ?", UV=CMmt, fulls=fs ) : nop()
    srchClip    = srchcheck         ? srchClip    : \
                  (SrchClipPP == 0) ? repair0     : \
                  (SrchClipPP  < 3) ? spatialBlur : \
                                      spatialBlur.ex_lutxy( tweaked, "x 7 scalef + y < x 2 scalef + x 7 scalef - y > x 2 scalef - x 0.51 * y 0.49 * + ? ?", UV=CMmt, fulls=fs )
    srchClip    = tv_range && !srchcheck ? srchClip.ex_Luma_Rebuild(S0=Str,c=Amp,uv=CMmt, fulls=fs) : srchClip
    srchClip    = bi8 ? srchClip : srchClip.ConvertBits(8,dither=-1)
    # Calculate forward and backward motion vectors from motion search clip
    srchSuper = IsClip(srchSuper) ? srchSuper                                                                                                             : \
                (maxTR > 0)       ? Defined(bomt) ? srchClip.MSuper( pel=SubPel, sharp=SubPelInterp, hpad=hpad, vpad=vpad, chroma=ChromaMotion, mt=bomt ) : \
                                                    srchClip.MSuper( pel=SubPel, sharp=SubPelInterp, hpad=hpad, vpad=vpad, chroma=ChromaMotion )          : nop()
    bVec6c = IsClip(bVec6)
    bVec6  = bVec6c ? bVec6 : \
            (maxTR > 5)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=true,  delta=6, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt )                                    \
                                          : srchSuper.MAnalyse( isb=true,  delta=6, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel,  \
                                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    bVec6 = bVec6c || !RefineMotion || !(maxTR > 5) ? bVec6 : Defined(bomt) ? srchSuper.MRecalculate(bVec6, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(bVec6, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    bVec5c = IsClip(bVec5)
    bVec5  = bVec5c ? bVec5 : \
            (maxTR > 4)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=true,  delta=5, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=true,  delta=5, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    bVec5 = bVec5c || !RefineMotion || !(maxTR > 4) ? bVec5 : Defined(bomt) ? srchSuper.MRecalculate(bVec5, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(bVec5, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    bVec4c = IsClip(bVec4)
    bVec4  = bVec4c ? bVec4 : \
            (maxTR > 3)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=true,  delta=4, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=true,  delta=4, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    bVec4 = bVec4c || !RefineMotion || !(maxTR > 3) ? bVec4 : Defined(bomt) ? srchSuper.MRecalculate(bVec4, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(bVec4, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    bVec3c = IsClip(bVec3)
    bVec3  = bVec3c ? bVec3 : \
            (maxTR > 2)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=true,  delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=true,  delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    bVec3 = bVec3c || !RefineMotion || !(maxTR > 2) ? bVec3 : Defined(bomt) ? srchSuper.MRecalculate(bVec3, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(bVec3, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    bVec2c = IsClip(bVec2)
    bVec2  = bVec2c ? bVec2 : \
            (maxTR > 1)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=true,  delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=true,  delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    bVec2 = bVec2c || !RefineMotion || !(maxTR > 1) ? bVec2 : Defined(bomt) ? srchSuper.MRecalculate(bVec2, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(bVec2, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    bVec1c = IsClip(bVec1)
    bVec1  = bVec1c ? bVec1 : \
            (maxTR > 0)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=true,  delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=true,  delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    bVec1 = bVec1c || !RefineMotion || !(maxTR > 0) ? bVec1 : Defined(bomt) ? srchSuper.MRecalculate(bVec1, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(bVec1, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    fVec1c = IsClip(fVec1)
    fVec1  = fVec1c ? fVec1 : \
            (maxTR > 0)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=false, delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=false, delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    fVec1 = fVec1c || !RefineMotion || !(maxTR > 0) ? fVec1 : Defined(bomt) ? srchSuper.MRecalculate(fVec1, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(fVec1, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    fVec2c = IsClip(fVec2)
    fVec2  = fVec2c ? fVec2 : \
            (maxTR > 1)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=false, delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=false, delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    fVec2 = fVec2c || !RefineMotion || !(maxTR > 1) ? fVec2 : Defined(bomt) ? srchSuper.MRecalculate(fVec2, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(fVec2, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    fVec3c = IsClip(fVec3)
    fVec3  = fVec3c ? fVec3 : \
            (maxTR > 2)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=false, delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=false, delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    fVec3 = fVec3c || !RefineMotion || !(maxTR > 2) ? fVec3 : Defined(bomt) ? srchSuper.MRecalculate(fVec3, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(fVec3, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    fVec4c = IsClip(fVec4)
    fVec4  = fVec4c ? fVec4 : \
            (maxTR > 3)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=false, delta=4, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=false, delta=4, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    fVec4 = fVec4c || !RefineMotion || !(maxTR > 3) ? fVec4 : Defined(bomt) ? srchSuper.MRecalculate(fVec4, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(fVec4, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    fVec5c = IsClip(fVec5)
    fVec5  = fVec5c ? fVec5 : \
            (maxTR > 4)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=false, delta=5, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=false, delta=5, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    fVec5 = fVec5c || !RefineMotion || !(maxTR > 4) ? fVec5 : Defined(bomt) ? srchSuper.MRecalculate(fVec5, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(fVec5, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)
    fVec6c = IsClip(fVec6)
    fVec6  = fVec6c ? fVec6 : \
            (maxTR > 5)   ? Defined(bomt) ? srchSuper.MAnalyse( isb=false, delta=6, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, mt=bomt ) \
                                          : srchSuper.MAnalyse( isb=false, delta=6, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
                                                global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : nop()

    fVec6 = fVec6c || !RefineMotion || !(maxTR > 5) ? fVec6 : Defined(bomt) ? srchSuper.MRecalculate(fVec6, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)             \
                                                                            : srchSuper.MRecalculate(fVec6, overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                        chroma=ChromaMotion, truemotion=TrueMotion, search=Search,              \
                                                                                                        searchparam=SearchParam, lambda=Lambda, pnew=PNew)

    # Expose search clip, motion search super clip and motion vectors to calling script through globals
    QTGMC_SetUserGlobal( GlobalNames, "srchClip",  srchClip,  ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "srchSuper", srchSuper, ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "bVec1",     bVec1,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "fVec1",     fVec1,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "bVec2",     bVec2,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "fVec2",     fVec2,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "bVec3",     bVec3,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "fVec3",     fVec3,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "bVec4",     bVec4,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "fVec4",     fVec4,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "bVec5",     bVec5,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "fVec5",     fVec5,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "bVec6",     bVec6,     ReplaceGlobals )
    QTGMC_SetUserGlobal( GlobalNames, "fVec6",     fVec6,     ReplaceGlobals )


    #---------------------------------------
    # Noise Processing

    # >>>> Interleaved YUY2 for denoising, planar whilst pre-motion compensating

    # Expand fields to full frame size before extracting noise (allows use of motion vectors which are frame-sized)
    fullClip  = (NoiseProcess == 0)   ? nop()               : \
                (InputType > 0)       ? clip                : \
                                        clip.sh_Bob( 0, 1.0 )
    fullClip  = (yuy2 && NoiseTR > 0) ? fullClip.nonyuy2clipin(true) : fullClip
    fullSuper = (NoiseTR > 0)         ? Defined(bomt) ? fullClip.MSuper( pel=SubPel, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise, mt=bomt ) : fullClip.MSuper( pel=SubPel, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise ) : nop() #TEST chroma OK?

    # Create a motion compensated temporal window around current frame and use to guide denoisers
    noiseWindow = (NoiseProcess == 0) ? nop()    : \
                  (!DenoiseMC)        ? fullClip : \
                  (NoiseTR == 0)      ? fullClip : \
                  (NoiseTR == 1)      ? Interleave( Defined(bomt) ? fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt ) : fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2 ),    \
                                                    fullClip, \
                                                    Defined(bomt) ? fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt ) : fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2 ) ) : \
                                        Interleave( Defined(bomt) ? fullClip.MCompensate( fullSuper, fVec2, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt ) : fullClip.MCompensate( fullSuper, fVec2, thSCD1=ThSCD1,thSCD2=ThSCD2 ),    \
                                                    Defined(bomt) ? fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt ) : fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2 ),    \
                                                    fullClip, \
                                                    Defined(bomt) ? fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt ) : fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2 ),    \
                                                    Defined(bomt) ? fullClip.MCompensate( fullSuper, bVec2, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt ) : fullClip.MCompensate( fullSuper, bVec2, thSCD1=ThSCD1,thSCD2=ThSCD2 ) )
    noiseWindow = yuy2 && (Denoiser == "fft3df") && NoiseTR > 0 ? noiseWindow.nonyuy2clipout(true) : noiseWindow
    noiseWindow = (NoiseProcess != 0) && n16d ? noiseWindow.ConvertBits(16) : noiseWindow
    dnWindow = (NoiseProcess == 0)      ? nop() : \
               (Denoiser == "dfttest")  ? noiseWindow.dfttest( Y=true, U=ChromaNoise, V=ChromaNoise, sigma=Sigma*4, tbsize=noiseTD, threads=FftThreads, Dither=DftDither ) : \
            (Denoiser == "KNLMeansCL")  ? noiseWindow.SH_KNLMeansCL(Chroma=ChromaNoise, a=2, d=NoiseTR, h=Sigma, device_type=device_type, device_id=device_id )  : \
                                          noiseWindow.FFT3DFilter( sigma=Sigma, bt=noiseTD, ncpu=FftThreads, plane=ChromaNoise ? 3 : 0)
    dnwindow = (Denoiser == "KNLMeansCL" || Denoiser == "dfttest") && (NoiseProcess != 0) && yuy2 ? dnWindow.nonyuy2clipout(true) : dnWindow
    dnwindow = (NoiseProcess != 0) && n16d ? dnwindow.ConvertBits(bi,dither=-1) : dnwindow

    # Rework denoised clip to match source format - various code paths here: discard the motion compensation window, discard doubled lines (from point resize)
    # Also reweave to get interlaced noise if source was interlaced (could keep the full frame of noise, but it will be poor quality from the point resize)
    denoised = (NoiseProcess == 0) ? nop()                                                                                  : \
               (!DenoiseMC)        ? ((InputType > 0) ? dnWindow : dnWindow.SeparateFields().SelectEvery( 4, 0,3 ).Weave()) : \
               (InputType > 0)     ? ((NoiseTR == 0)  ? dnWindow : dnWindow.SelectEvery( noiseTD, NoiseTR ))                : \
                                     dnWindow.SeparateFields().SelectEvery( noiseTD*4, NoiseTR*2,NoiseTR*6+3 ).Weave()

    # >>>> Switch to planar YUY2 for noise bypass

    CNmt1   = ChromaNoise ? 3 : 1
    CNmt2   = ChromaNoise ? 3 : 2
    CNmt128 = ChromaNoise ? 3 : -128

    # Get actual noise from difference. Then 'deinterlace' where we have weaved noise - create the missing lines of noise in various ways
    planarDenoised = (NoiseProcess == 0) ? nop() : yuy2 ? denoised.nonyuy2clipin(true) : denoised
    noise      = (totalRestore > 0.0) ? ex_makediff( planarClip, planarDenoised, UV=CNmt1, fulls=fs ) : nop()
    deintNoise = (NoiseProcess == 0 || totalRestore == 0.0) ? nop()                                                         : \
                 (InputType != 0)                           ? noise                                                         : \
                 (NoiseDeint == "Bob")                      ? noise.sh_Bob( 0,0.5 )                                         : \
                 (NoiseDeint == "Generate")                 ? noise.QTGMC_Generate2ndFieldNoise( denoised, ChromaNoise, fs) : \
                                                              noise.DoubleWeave()
    # Motion-compensated stabilization of generated noise
    noiseSuper = (StabilizeNoise) ? Defined(bomt) ? deintNoise.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise, mt=bomt ) : deintNoise.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise ) : nop()
    mcNoise    = (StabilizeNoise) ? Defined(bomt) ? deintNoise.MCompensate( noiseSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt ) : deintNoise.MCompensate( noiseSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2 ) : nop()
    finalNoise = (StabilizeNoise) ? ex_lutxy( deintNoise, mcNoise, "x range_half - abs y range_half - abs > x y ? 0.6 * x y + 0.2 * +", UV=CNmt1, fulls=fs ) : deintNoise

    # If NoiseProcess=1 denoise input clip. If NoiseProcess=2 leave noise in the clip and let the temporal blurs "denoise" it for a stronger effect
    innerClip = (NoiseProcess == 1) ? denoised : clip


    #---------------------------------------
    # Interpolation

    # >>>> Interleaved YUY2 for interpolation

    # Support badly deinterlaced progressive content - drop half the fields and reweave to get 1/2fps interlaced stream appropriate for QTGMC processing
    ediInput = (InputType == 2 || InputType == 3) ? innerClip.SeparateFields().SelectEvery(4,0,3).Weave() : innerClip

    # Create interpolated image as starting point for output
    edi1 = Defined(EdiExt) ? EdiExt.PointResize( w,h, 0,(EdiExt.Height()-h)/2, -0,h+epsilon )                                                   : \
                             QTGMC_Interpolate( ediInput, InputType, EdiMode, NNSize, NNeurons, EdiQual, EdiMaxD, EdiThreads, bobbed, ChromaEdi )

    # >>>> Switch to planar YUY2 during next step - remains planar until very end of script except blurring for back blending & SVThin

    # InputType=2,3: use motion mask to blend luma between original clip & reweaved clip based on ProgSADMask setting. Use chroma from original clip in any case
    inputTypeBlend = (ProgSADMask > 0.0) ? MMask( srchClip, bVec1, kind=1, ml=ProgSADMask ) : nop()
    edi = (InputType != 2 && InputType != 3) ? (!yuy2 ? edi1 : edi1.nonyuy2clipin(true))                                                   :\
          (ProgSADMask <= 0.0)               ? (!yuy2 ? edi1.MergeChroma( innerClip ) : edi1.MergeChroma( innerClip ).nonyuy2clipin(true)) : \
                                               (!yuy2 ? mt_merge( innerClip, edi1, inputTypeBlend, U=2,V=2 )                               : \
                                                        mt_merge( innerClip.nonyuy2clipin(true), edi1.nonyuy2clipin(true), inputTypeBlend, U=2,V=2 ))

    # Get the max/min value for each pixel over neighboring motion-compensated frames - used for temporal sharpness limiting
    ediSuper = (TR1 > 0 || temporalSL)   ? Defined(bomt) ? edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, mt=bomt ) : edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad ) : nop()
    bComp1   = (temporalSL)              ? Defined(bomt) ? edi.MCompensate( ediSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt              ) : edi.MCompensate( ediSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2              ) : nop()
    fComp1   = (temporalSL)              ? Defined(bomt) ? edi.MCompensate( ediSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt              ) : edi.MCompensate( ediSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2              ) : nop()
    tMax     = (temporalSL)              ? edi.Expr( fComp1, bComp1, "x y max z max" )    : nop()
    tMin     = (temporalSL)              ? edi.Expr( fComp1, bComp1, "x y min z min" )    : nop()
    bComp3   = (SLRad > 1 && temporalSL) ? Defined(bomt) ? edi.MCompensate( ediSuper, bVec3, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt              ) : edi.MCompensate( ediSuper, bVec3, thSCD1=ThSCD1,thSCD2=ThSCD2              ) : nop()
    fComp3   = (SLRad > 1 && temporalSL) ? Defined(bomt) ? edi.MCompensate( ediSuper, fVec3, thSCD1=ThSCD1,thSCD2=ThSCD2, mt=bomt              ) : edi.MCompensate( ediSuper, fVec3, thSCD1=ThSCD1,thSCD2=ThSCD2              ) : nop()
    tMax     = (SLRad > 1 && temporalSL) ? tMax.Expr( fComp3, bComp3, "x y max z max" )   : tMax
    tMin     = (SLRad > 1 && temporalSL) ? tMin.Expr( fComp3, bComp3, "x y min z min" )   : tMin
    sMDegnl  = n16 ? ", out16=n16" : ""
    sMDegnl  = Defined(bomt) ? sMDegnl + ", mt=bomt" : sMDegnl


    #---------------------------------------
    # Create basic output

    # Use motion vectors to blur interpolated image (edi) with motion-compensated previous and next frames. As above, this is done to remove shimmer from
    # alternate frames so the same binomial kernels are used. However, by using motion-compensated smoothing this time we avoid motion blur. The use of
    # MDegrain1 (motion compensated) rather than TemporalSmooth makes the weightings *look* different, but they evaluate to the same values
    # Create linear weightings of neighbors first                                                                                             -2    -1     0    1     2
    degrain1 = (TR1 > 0) ? Eval("edi.MDegrain1( ediSuper, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()  # 0.00  0.33  0.33  0.33  0.00
    degrain2 = (TR1 > 1) ? Eval("edi.MDegrain1( ediSuper, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()  # 0.33  0.00  0.33  0.00  0.33
    degrain1 = (TR1 > 0) ? n16 ? degrain1.ConvertBits(8,dither=-1) : degrain1 : degrain1
    degrain2 = (TR1 > 1) ? n16 ? degrain2.ConvertBits(8,dither=-1) : degrain2 : degrain2

    # Combine linear weightings to give binomial weightings - TR1=0: (1), TR1=1: (1:2:1), TR1=2: (1:4:6:4:1)
    binomial1 = (TR1 == 0) ? edi                                                : \
                (TR1 == 1) ? degrain1.Merge( edi, 0.25 )                        : \
                             degrain1.Merge( degrain2, 0.2 ).Merge( edi, 0.0625 )

    # Remove areas of difference between smoothed image and interpolated image that are not bob-shimmer fixes: repairs residual motion blur from temporal smooth
    repair1 = (Rep1 == 0) ? binomial1 : binomial1.QTGMC_KeepOnlyBobShimmerFixes( edi, Rep1, RepChroma, fs )

    # Apply source match - use difference between output and source to succesively refine output [extracted to function to clarify main code path]
    match = (SourceMatch == 0) ? repair1 : \
                                 repair1.QTGMC_ApplySourceMatch( InputType, ediInput, bVec1,fVec1, bVec2,fVec2, SubPel, SubPelInterp, hpad, vpad,              \
                                                                 ThSAD1, ThSCD1, ThSCD2, SourceMatch, MatchTR1, MatchEdi, MatchNNSize, MatchNNeurons,          \
                                                                 MatchEdiQual, MatchEdiMaxD, MatchTR2, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, \
                                                                 MatchEdiMaxD2, MatchEnhance, EdiThreads, lsb, n16, bomt, fs )

    # Lossless=2 - after preparing an interpolated, de-shimmered clip, restore the original source fields into it and clean up any artefacts.
    # This mode will not give a true lossless result because the resharpening and final temporal smooth are still to come, but it will add further detail.
    # However, it can introduce minor combing. This setting is best used together with source-match (it's effectively the final source-match stage).
    lossed1 = (Lossless == 2) ? QTGMC_MakeLossless( match, innerClip, InputType, fs ) : match


    #---------------------------------------
    # Resharpen / retouch output

    # Resharpen to counteract temporal blurs. Little sharpening needed for source-match mode since it has already recovered sharpness from source
    vresharp1 = (SMode == 2) ? Merge( lossed1.mt_expand( mode="vertical", U=3,V=3 ), lossed1.mt_inpand( mode="vertical", U=3,V=3 ) )   : nop()
    vresharp  = (Precise && SMode == 2) ? vresharp1.ex_lutxy( lossed1, "x y < x 1 scalef + x y > x 1 scalef - x ? ?", UV=3, fulls=fs ) : vresharp1 # Precise mode: reduce tiny overshoot
    resharp   = (SMode == 0) ? lossed1                                                                                                 : \
                (SMode == 1) ? lossed1.ex_lutxy(  lossed1.RemoveGrain( 12 ), "x x y - "+ string(sharpAdj) + " * +", UV=3, fulls=fs )   : \
                               lossed1.ex_lutxy( vresharp.RemoveGrain( 12 ), "x x y - "+ string(sharpAdj) + " * +", UV=3, fulls=fs )

    # Slightly thin down 1-pixel high horizontal edges that have been widened into neigboring field lines by the interpolator
    SVThinSc  =  SVThin * 6.0
    vertMedD  = (SVthin > 0.0) ? ex_lutxy( lossed1, lossed1.ex_median(mode="vertical", UV=1, fulls=fs), "y x - " + string(SVThinSc) + " * range_half +", clamp_float=true, UV=1, fulls=fs  ) : nop()
    vertMedD  = (SVthin > 0.0) ? (vertMedD.ex_boxblur( 1, 0, "weighted", UV=1 )) : nop()
    thin      = (SVthin > 0.0) ? ex_lutxyz( vertMedD, vertMedD.RemoveGrain( 12, -1 ), resharp, "y range_half - abs x range_half - abs > y range_half ? z + range_half -", UV=2, fulls=fs  ) : resharp

    # Back blend the blurred difference between sharpened & unsharpened clip, before (1st) sharpness limiting (Sbb == 1,3). A small fidelity improvement
    backBlend1 = (Sbb != 1 && Sbb != 3) ? thin                                                       : \
                         thin.ex_makediff( ex_makediff( thin, lossed1, UV=1, fulls=fs  ).RemoveGrain( 12, -1 ) \
                             .GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), UV=2, fulls=fs )

    # Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
    # Occurs here (before final temporal smooth) if SLMode == 1,2. This location will restrict sharpness more, but any artefacts introduced will be smoothed
    sharpLimit1 = (SLMode == 1) ? backBlend1.Repair( ((SLrad <= 1) ? edi : backBlend1.Repair( edi, 12 )), 1 ) : \
                  (SLMode == 2) ? backBlend1.ex_clamp( tMax,tMin, Sovs,Sovs, UV=3, fulls=fs )                 : \
                                  backBlend1

    # Back blend the blurred difference between sharpened & unsharpened clip, after (1st) sharpness limiting (Sbb == 2,3). A small fidelity improvement
    backBlend2 = (Sbb < 2) ? sharpLimit1                                                                               : \
                             sharpLimit1.ex_makediff( ex_makediff( sharpLimit1, lossed1, UV=1, fulls=fs  ).RemoveGrain( 12, -1 ) \
                                        .GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), UV=2, fulls=fs  )

    # Add back any extracted noise, prior to final temporal smooth - this will restore detail that was removed as "noise" without restoring the noise itself
    # Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
    addNoise1 = (GrainRestore <= 0.0) ? backBlend2 : \
                                        backBlend2.ex_adddiff( finalNoise.ex_lut( "x " + noiseCentre + " scalef - " + string(GrainRestore) + " * range_half +", UV=CNmt1, fulls=fs ), UV=CNmt2, fulls=fs )

    # Final light linear temporal smooth for denoising
    stableSuper = (TR2 > 0) ? Defined(bomt) ? addNoise1.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, mt=bomt ) : addNoise1.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad ) : nop()
    stable  = (TR2 == 0) ? addNoise1 : \
              (TR2 == 1) ? Eval("addNoise1.MDegrain1( stableSuper, bVec1,fVec1,                                                                  thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : \
              (TR2 == 2) ? Eval("addNoise1.MDegrain2( stableSuper, bVec1,fVec1, bVec2,fVec2,                                                     thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : \
              (TR2 == 3) ? Eval("addNoise1.MDegrain3( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3,                                        thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : \
              (TR2 == 4) ? Eval("addNoise1.MDegrain4( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, bVec4,fVec4,                           thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : \
              (TR2 == 5) ? Eval("addNoise1.MDegrain5( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, bVec4,fVec4, bVec5,fVec5,              thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : \
                           Eval("addNoise1.MDegrain6( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, bVec4,fVec4, bVec5,fVec5, bVec6,fVec6, thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")")
    stable  = (TR2 > 0) ? n16 ? stable.ConvertBits(8,dither=-1) : stable : stable

    # Remove areas of difference between final output & basic interpolated image that are not bob-shimmer fixes: repairs motion blur caused by temporal smooth
    repair2 = (Rep2 == 0) ? stable : stable.QTGMC_KeepOnlyBobShimmerFixes( edi, Rep2, RepChroma, fs )

    # Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
    # Occurs here (after final temporal smooth) if SLMode == 3,4. Allows more sharpening here, but more prone to introducing minor artefacts
    sharpLimit2 = (SLMode == 3) ? repair2.Repair( ((SLrad <= 1) ? edi : repair2.Repair( edi, 12 )), 1 ) : \
                  (SLMode == 4) ? repair2.ex_clamp( tMax,tMin, Sovs,Sovs, UV=3, fulls=fs )              : \
                                  repair2

    # Lossless=1 - inject source fields into result and clean up inevitable artefacts. Provided NoiseRestore=0.0 or 1.0, this mode will make the script result
    # properly lossless, but this will retain source artefacts and cause some combing (where the smoothed deinterlace doesn't quite match the source)
    lossed2 = (Lossless == 1) ? QTGMC_MakeLossless( sharpLimit2, innerClip, InputType, fs ) : sharpLimit2

    # Add back any extracted noise, after final temporal smooth. This will appear as noise/grain in the output
    # Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
    addNoise2 = (NoiseRestore <= 0.0) ? lossed2 : \
                                        lossed2.ex_adddiff( finalNoise.ex_lut( "x " + noiseCentre + " scalef - " + string(NoiseRestore) + " * range_half +", clamp_float=true,  UV=CNmt1, fulls=fs ), UV=CNmt2, fulls=fs )


    #---------------------------------------
    # Post-Processing

    # Shutter motion blur - get level of blur depending on output framerate and blur already in source
    blurLevel = (ShutterAngleOut * FPSDivisor - ShutterAngleSrc) * 100.0 / 360.0
    Assert( blurLevel >= 0, "Cannot reduce motion blur already in source: increase ShutterAngleOut or FPSDivisor" )
    Assert( blurLevel <= 200, "Exceeded maximum motion blur level: decrease ShutterAngleOut or FPSDivisor" )

    # ShutterBlur mode 2,3 - get finer resolution motion vectors to reduce blur "bleeding" into static areas
    rBlockDivide = Select( ShutterBlur, 1, 1, 2, 4 )
    rBlockSize = BlockSize / rBlockDivide
    rOverlap   = Overlap   / rBlockDivide
    rBlockSize = (rBlockSize < 4) ? 4 : rBlockSize
    rOverlap   = (rOverlap   < 2) ? 2 : rOverlap
    rBlockDivide = BlockSize / rBlockSize
    rLambda = Lambda / (rBlockDivide * rBlockDivide)
    sbBVec1 = (ShutterBlur > 1) ? srchSuper.MRecalculate( bVec1, thSAD=ThSAD1, blksize=rBlockSize, overlap=rOverlap, search=Search, searchparam=SearchParam, \
                                                          truemotion=TrueMotion, lambda=Lambda, pnew=PNew, DCT=DCT, chroma=ChromaMotion ) : bVec1
    sbFVec1 = (ShutterBlur > 1) ? srchSuper.MRecalculate( fVec1, thSAD=ThSAD1, blksize=rBlockSize, overlap=rOverlap, search=Search, searchparam=SearchParam, \
                                                          truemotion=TrueMotion, lambda=Lambda, pnew=PNew, DCT=DCT, chroma=ChromaMotion ) : fVec1

    # Shutter motion blur - use MFlowBlur to blur along motion vectors
    sblurSuper = (ShutterBlur > 0) ? Defined(bomt) ? addNoise2.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, mt=bomt ) : addNoise2.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad ) : nop()
    sblur =      (ShutterBlur > 0) ? addNoise2.MFlowBlur( sblurSuper, sbBVec1, sbFVec1, blur=blurLevel, thSCD1=ThSCD1,thSCD2=ThSCD2 ) : nop()

    # Shutter motion blur - use motion mask to reduce blurring in areas of low motion - also helps reduce blur "bleeding" into static areas, then select blur type
    sbMotionMask = (ShutterBlur > 0 && SBlurLimit > 0) ? MMask( srchClip, bVec1, kind=0, ml=SBlurLimit ) : nop()
    sblurred     = (ShutterBlur == 0) ? addNoise2                                         : \
                   (SBlurLimit == 0)  ? sblur                                             : \
                                        mt_merge( addNoise2, sblur, sbMotionMask, U=3,V=3 )
    # Reduce frame rate
    decimated = (FPSDivisor != 1) ? sblurred.SelectEvery( FPSDivisor, 0 ) : sblurred

    # Crop off temporary vertical padding
    cropped = Border ? decimated.Crop( 0, 4, -0, -4, true ) : decimated
    h = Border ? h-8 : h

    # Show output of choice + settings
    # >>>> Restore YUY2 to interleaved
    output = (ShowNoise == 0.0) ? cropped : finalNoise.ex_lut( "x range_half - " + string(ShowNoise) + " * range_half +", clamp_float=true, UV=CNmt128, fulls=fs )
    output = yuy2 ? output.nonyuy2clipout(true) : output
    output = keep_tv_range ? output.Limiter(16, 235, 16, 240, paramscale=true) : output
    return (ShowSettings == false) ? output : \
        output.Subtitle( "TR0=" + string(TR0) + " | TR1=" + string(TR1) + " | TR2=" + string(TR2) + " | Rep0=" + string(Rep0) + " | Rep1=" + string(Rep1) + \
        " | Rep2=" + string(Rep2) + " | RepChroma=" + string(RepChroma) + "\nEdiMode='" + EdiMode + "' | NNSize=" + string(NNSize) + " | NNeurons=" + \
        string(NNeurons) + " | EdiQual=" + string(EdiQual) + " | EdiMaxD=" + string(EdiMaxD) + " | ChromaEdi='" + ChromaEdi + "' | EdiThreads=" + \
        string(EdiThreads) + "\nSharpness=" + string(Sharpness, "%.2f") + " | SMode=" + string(SMode) + " | SLMode=" + string(SLMode) + " | SLRad=" + \
        string(SLRad) + " | SOvs=" + string(SOvs) + " | SVThin=" + string(SVThin, "%.2f") + " | Sbb=" + string(Sbb) + "\nSrchClipPP=" + string(SrchClipPP) + \
        " | SubPel=" + string(SubPel) + " | SubPelInterp=" + string(SubPelInterp) + " | BlockSize=" + string(BlockSize) + " | Overlap=" + string(Overlap) + \
        "\nSearch=" + string(Search) + " | SearchParam=" + string(SearchParam) + " | PelSearch=" + string(PelSearch) + " | ChromaMotion=" + \
        string(ChromaMotion) + " | TrueMotion=" + string(TrueMotion) + "\nLambda=" + string(Lambda) + " | LSAD=" + string(LSAD) + " | PNew=" + string(PNew) + \
        " | PLevel=" + string(PLevel) + " | GlobalMotion=" + string(GlobalMotion) + " | DCT=" + string(DCT) + "\nThSAD1=" + string(ThSAD1) + " | ThSAD2=" + \
        string(ThSAD2) + " | ThSCD1=" + string(ThSCD1) + " | ThSCD2=" + string(ThSCD2) + "\nSourceMatch=" + string(SourceMatch) + " | MatchPreset='" + \
        MatchPreset + "' | MatchEdi='" + MatchEdi + "'\nMatchPreset2='" + MatchPreset2 + "' | MatchEdi2='" + MatchEdi2 + "' | MatchTR2=" + string(MatchTR2) + \
        " | MatchEnhance=" + string(MatchEnhance, "%.2f") + " | Lossless=" + string(Lossless) + "\nNoiseProcess=" + string(NoiseProcess) + " | Denoiser='" + \
        Denoiser + "' | FftThreads=" + string(FftThreads) + " | DenoiseMC=" + string(DenoiseMC) + " | NoiseTR=" + string(NoiseTR) + " | Sigma=" + \
        string(Sigma, "%.2f") + "\nChromaNoise=" + string(ChromaNoise) + " | ShowNoise=" + string(ShowNoise, "%.2f") + " | GrainRestore=" + \
        string(GrainRestore, "%.2f") + " | NoiseRestore=" + string(NoiseRestore, "%.2f") + "\nNoiseDeint='" + NoiseDeint + "' | StabilizeNoise=" + \
        string(StabilizeNoise) + " | InputType=" + string(InputType) + " | ProgSADMask=" + string(ProgSADMask, "%.2f") + "\nFPSDivisor=" + \
        string(FPSDivisor) + " | ShutterBlur=" + string(ShutterBlur) + " | ShutterAngleSrc=" + string(ShutterAngleSrc, "%.2f") + " | ShutterAngleOut=" + \
        string(ShutterAngleOut, "%.2f") + " | SBlurLimit=" + string(SBlurLimit) + "\nBorder=" + string(Border) + " | Precise=" + string(Precise) + \
        "\nPreset='" + Preset + "' | Tuning='" + Tuning + "' | GlobalNames='" + GlobalNames + "' | PrevGlobals='" + PrevGlobals + "' | ForceTR=" + \
        string(ForceTR), font="Lucida Console", size=11, lsp=12 )
}


#---------------------------------------
# Helpers

# Interpolate input clip using method given in EdiMode. Use Fallback or Bob as result if mode not in list. If ChromaEdi string if set then interpolate chroma
# separately with that method (only really useful for EEDIx). The function is used as main algorithm starting point and for first two source-match stages
function QTGMC_Interpolate( clip Input, int InputType, string EdiMode, int NNSize, int NNeurons, int EdiQual, int EdiMaxD, int EdiThreads, clip "Fallback", \
                            string "ChromaEdi" )
{
    # >>>> YUY2 is interleaved here

    ChromaEdi = Default( ChromaEdi, "" )
    CEed = (ChromaEdi == "")

    NNEDI3clp = EdiMode == "NNEDI3" || EdiMode == "EEDI3+NNEDI3" || EdiMode == "BWDIF+NNEDI3" || EdiMode == "BWDIF+EEDI3" ? Input.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads, U=CEed,V=CEed ) : undefined
    EEDI3clp  = EdiMode == "BWDIF+EEDI3" ? isyuy2(Input) ? Input.nonyuy2clipin(true).EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, U=CEed,V=CEed, sclip=NNEDI3clp.nonyuy2clipin(true) ).slimit_dif2(NNEDI3clp.nonyuy2clipin(true),thr=4, U=CEed?3:2,V=CEed?3:2).nonyuy2clipout(true) : Input.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, U=CEed,V=CEed, sclip=NNEDI3clp ).slimit_dif2(NNEDI3clp,thr=4,U=CEed?3:2,V=CEed?3:2) : \
                                          EdiMode == "EEDI3" || EdiMode == "EEDI3+NNEDI3" ? Input.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, U=CEed,V=CEed, sclip=NNEDI3clp ) : nop()

    interp = (InputType == 1)            ? Input                                                                                     : \
             (EdiMode == "NNEDI3")       ? NNEDI3clp                                                                                 : \
             (EdiMode == "NNEDI2")       ? Input.NNEDI2( field=-2, nsize=NNeurons, qual=EdiQual, threads=EdiThreads, U=CEed,V=CEed ) : \
             (EdiMode == "NNEDI")        ? Input.NNEDI( field=-2, U=CEed,V=CEed )                                                    : \
             (EdiMode == "EEDI3+NNEDI3") ? EEDI3clp                                                                                  : \
             (EdiMode == "EEDI3")        ? EEDI3clp                                                                                  : \
             (EdiMode == "EEDI2")        ? isyuy2(Input) ? Input.nonyuy2clipin(true).SeparateFields().EEDI2( field=-2, maxd=EdiMaxD ).nonyuy2clipout(true) : Input.SeparateFields().EEDI2( field=-2, maxd=EdiMaxD ) : \
             (EdiMode == "Yadif")        ? isyuy2(Input) ? Input.nonyuy2clipin(true).Yadifmod2( mode=3 ).nonyuy2clipout(true) : Input.Yadifmod2( mode=3 ) : \
             (EdiMode == "cYadif")       ? Input.Yadif( mode=3 )                                                                     : \
             (EdiMode == "TDeint")       ? Input.TDeInt( mode=1 )                                                                    : \
             (EdiMode == "RepYadif")     ? isyuy2(Input) ? Repair( Input.nonyuy2clipin(true).Yadifmod2( mode=3 ), Default( Fallback, Input.sh_Bob( 0,0.5 ) ).nonyuy2clipin(true), 2, 0 ).nonyuy2clipout(true) : \
                                                           Repair( Input.Yadifmod2( mode=3 ), Default( Fallback, Input.sh_Bob( 0,0.5 ) ), 2, 0 ) : \
             (EdiMode == "RepcYadif")    ? isyuy2(Input) ? Repair( Input.Yadif( mode=3 ).nonyuy2clipin(true), Default( Fallback, Input.sh_Bob( 0,0.5 ) ).nonyuy2clipin(true), 2, 0 ).nonyuy2clipout(true) : \
                                                           Repair( Input.Yadif( mode=3 ), Default( Fallback, Input.sh_Bob( 0,0.5 ) ), 2, 0 ) : \
             (EdiMode == "BWDIF+NNEDI3") ? isyuy2(Input) ? Input.nonyuy2clipin(true).BWDIF(-2,edeint=NNEDI3clp.nonyuy2clipin(true)) : Input.BWDIF(-2,edeint=NNEDI3clp) : \
             (EdiMode == "BWDIF+EEDI3")  ? isyuy2(Input) ? Input.nonyuy2clipin(true).BWDIF(-2,edeint=EEDI3clp.nonyuy2clipin(true))  : Input.BWDIF(-2,edeint=EEDI3clp)  : \
                                           Default( Fallback, Input.sh_Bob( 0,0.5 ) )

    interp = (EdiMode == "BWDIF+NNEDI3") || \
             (EdiMode == "BWDIF+EEDI3")   ? bi8 ? isyuy2(Input) ? interp.   vinverse(custem=NNEDI3clp.nonyuy2clipin(true)).nonyuy2clipout(true) : interp.   vinverse(custem=NNEDI3clp) : \
                                                  isyuy2(Input) ? interp.ex_vinverse(custem=NNEDI3clp.nonyuy2clipin(true)).nonyuy2clipout(true) : interp.ex_vinverse(custem=NNEDI3clp) : interp

    interpuv = (InputType == 1)          ? nop()                                                                                                           : \
               (ChromaEdi == "NNEDI3")   ? Input.NNEDI3( field=-2, nsize=4, nns=0, qual=1, threads=EdiThreads, Y=false )                                  : \
               (ChromaEdi == "Yadif")    ? isyuy2(Input) ? Input.nonyuy2clipin(true).Yadifmod2( mode=3 ).nonyuy2clipout(true) : Input.Yadifmod2( mode=3 ) : \
               (ChromaEdi == "cYadif")   ? Input.Yadif( mode=3 )                                                                                           : \
               (ChromaEdi == "Bob")      ? Input.sh_Bob( 0,0.5 )                                                                                           : \
                                           nop()

    return (!IsClip(interpuv)) ? interp : interp.MergeChroma( interpuv )
}



# Helper function: Compare processed clip with reference clip: only allow thin, horizontal areas of difference, i.e. bob shimmer fixes
# Rough algorithm: Get difference, deflate vertically by a couple of pixels or so, then inflate again. Thin regions will be removed
#                  by this process. Restore remaining areas of difference back to as they were in reference clip.
function QTGMC_KeepOnlyBobShimmerFixes( clip Input, clip Ref, int Rep, bool Chroma, bool fulls )
{
    # >>>> YUY2 is planar here

    # ed is the erosion distance - how much to deflate then reflate to remove thin areas of interest: 0 = minimum to 6 = maximum
    # od is over-dilation level  - extra inflation to ensure areas to restore back are fully caught:  0 = none to 3 = one full pixel
    # If Rep < 10, then ed = Rep and od = 0, otherwise ed = 10s digit and od = 1s digit (nasty method, but kept for compatibility with original TGMC)
    fs     = Default( fulls,  false)
    Rep    = Default( Rep,    1     )
    Chroma = Default( Chroma, true )
    ed = (Rep < 10) ? Rep : Rep / 10
    od = (Rep < 10) ? 0   : Rep % 10
    RCrg  = Chroma ? 3 : 1
    RCrgo = Chroma ? 3 : 2

    bi    = Input.BitsPerComponent()
    diff  = ex_makediff(Ref, Input, UV=RCrg, fulls=fs )

    # Areas of positive difference                                                                  # ed = 0 1 2 3 4 5 6 7
    choke1 =                        diff.mt_inpand(     mode="vertical", U=RCrg,V=RCrg )            #      x x x x x x x x    1 pixel   \
    choke1 = (ed > 2)             ? diff.ex_inpand(2,   mode="vertical", UV=RCrg       ) : choke1   #      . . . x x x x x    1 pixel    |  Deflate to remove thin areas
    choke1 = (ed > 5)             ? diff.ex_inpand(3,   mode="vertical", UV=RCrg       ) : choke1   #      . . . . . . x x    1 pixel   /
    choke1 = (ed % 3 != 0)        ? choke1.mt_deflate( U=RCrg,V=RCrg )                   : choke1   #      . x x . x x . x    A bit more deflate & some horizonal effect
    choke1 = (ed == 2 || ed == 5) ? choke1.RemoveGrain(4, chroma ? 4 : -1 )              : choke1   #      . . x . . x . .    Local median

    choke0 =                        choke1.mt_expand(   mode="vertical", U=RCrg,V=RCrg )            #      x x x x x x x x    1 pixel  \
    choke0 = (ed > 1)             ? choke1.ex_expand(2, mode="vertical", UV=RCrg       ) : choke0   #      . . x x x x x x    1 pixel   | Reflate again
    choke0 = (ed > 4)             ? choke1.ex_expand(3, mode="vertical", UV=RCrg       ) : choke0   #      . . . . . x x x    1 pixel  /

    # Over-dilation - extra reflation up to about 1 pixel
    choke1 = (od == 0)            ? choke0                                                         : \
             (od == 1)            ? choke0.mt_inflate( U=RCrg,V=RCrg )                             : \
             (od == 2)            ? choke0.mt_inflate( U=RCrg,V=RCrg ).mt_inflate( U=RCrg,V=RCrg ) : \
                                    choke0.mt_expand ( U=RCrg,V=RCrg )

    # Areas of negative difference (similar to above)
    choke2 =                        diff.mt_expand(     mode="vertical", U=RCrg,V=RCrg )
    choke2 = (ed > 2)             ? diff.ex_expand(2,   mode="vertical", UV=RCrg       ) : choke2
    choke2 = (ed > 5)             ? diff.ex_expand(3,   mode="vertical", UV=RCrg       ) : choke2
    choke2 = (ed % 3 != 0)        ? choke2.mt_inflate( U=RCrg,V=RCrg )                   : choke2
    choke0 = (ed == 2 || ed == 5) ? choke2.RemoveGrain(4, chroma ? 4 : -1 )              : choke2
    choke2 =                        choke0.mt_inpand(   mode="vertical", U=RCrg,V=RCrg )
    choke2 = (ed > 1)             ? choke0.ex_inpand(2, mode="vertical", UV=RCrg       ) : choke2
    choke2 = (ed > 4)             ? choke0.ex_inpand(3, mode="vertical", UV=RCrg       ) : choke2

    choke2 = (od == 0)            ? choke2 : \
             (od == 1)            ? choke2.mt_deflate( U=RCrg,V=RCrg )                             : \
             (od == 2)            ? choke2.mt_deflate( U=RCrg,V=RCrg ).mt_deflate( U=RCrg,V=RCrg ) : \
                                    choke2.mt_inpand ( U=RCrg,V=RCrg )

    # Combine above areas to find those areas of difference to restore

    str = ex_dlut("x 129 scalef < x y range_half < range_half y ? ? A@ 127 scalef > A z range_half > range_half z ? ? a + range_half -", bi, fs)
    restore = Expr(diff, choke1, choke2, Input, str, Chroma ? str : "" )

    return restore
}


# Given noise extracted from an interlaced source (i.e. the noise is interlaced), generate "progressive" noise with a new "field" of noise injected. The new
# noise is centered on a weighted local average and uses the difference between local min & max as an estimate of local variance
# YUY2 clip input is planar, but must pass interleaved version of clip to setup noise
function QTGMC_Generate2ndFieldNoise( clip Input, clip InterleavedClip, bool "ChromaNoise", bool "fulls" )
{
    # >>>> YUY2 is planar here. Noise is generated (AddGrainC) interleaved, but immediately made planar
    ChromaNoise = Default( ChromaNoise, false )
    fs          = Default( fulls,       false )
    bi        = Input.BitsPerComponent()
    CNmt1     = ChromaNoise ? 3 : 1
    origNoise = Input.SeparateFields()
    noiseMax  = origNoise.ex_expand(2,mode="horizontal",UV=CNmt1).ex_expand(1,mode="vertical",UV=CNmt1)
    noiseMin  = origNoise.ex_inpand(2,mode="horizontal",UV=CNmt1).ex_inpand(1,mode="vertical",UV=CNmt1)
    random    = BlankClip( InterleavedClip.SeparateFields(), color_yuv=$808080 ).AddGrainC( var=1800, uvar=ChromaNoise ? 1800 : 0 )
    random    = InterleavedClip.IsYUY2() ? random.nonyuy2clipin(true) : random
    str = ex_dlut("x y - 0 max z * 1 range_size / * a +", bi, fs)
    newNoise = Expr(noiseMax, noiseMin, random, noiseMin, str, ChromaNoise ? str : "", scale_inputs="floatf")
    return Interleave( origNoise, newNoise ).Weave()
}


# Insert the source lines into the result to create a true lossless output. However, the other lines in the result have had considerable processing and won't
# exactly match source lines. There will be some slight residual combing. Use vertical medians to clean a little of this away
function QTGMC_MakeLossless( clip Input, clip Source, int InputType, bool fulls )
{
    Assert( InputType != 1, "Lossless modes are incompatible with InputType=1" )

    # >>>> YUY2: 'Input' is planar, 'Source' is interleaved (changed to planar here for processing) - returns planar result

    # Weave the source fields and the "new" fields that have generated in the input
    srcFields1 = (InputType == 0) ? Source.SeparateFields() : Source.SeparateFields().SelectEvery( 4, 0,3 )
    srcFields  = Source.IsYUY2() ? srcFields1.nonyuy2clipin(true) : srcFields1
    newFields  = Input.SeparateFields().SelectEvery( 4, 1,2 )
    processed  = Interleave( srcFields, newFields ).SelectEvery(4, 0,1,3,2 ).Weave()

    # Clean some of the artefacts caused by the above - creating a second version of the "new" fields
    vertMedian  = processed.ex_median(mode="vertical", UV=3, fulls=fulls)
    vertMedDiff = ex_makediff( processed, vertMedian, UV=3, dif=false, fulls=fulls )
    vmNewDiff1  = vertMedDiff.SeparateFields().SelectEvery( 4, 1,2 )
    vmNewDiff2  = vmNewDiff1.ex_median(mode="vertical", UV=3, fulls=fulls).ex_lutxy( vmNewDiff1, "x y * 0 < range_half x y min ?", UV=3, fulls=fulls )
    vmNewDiff3  = vmNewDiff2.Repair( vmNewDiff2.RemoveGrain( 2 ), 1 )

    # Reweave final result
    return Interleave( srcFields, newFields.ex_makediff( vmNewDiff3, UV=3, dif=false, fulls=fulls )).SelectEvery( 4, 0,1,3,2 ).Weave()
}


# Source-match, a three stage process that takes the difference between deinterlaced input and the original interlaced source, to shift the input more towards
# the source without introducing shimmer. All other arguments defined in main script
function QTGMC_ApplySourceMatch( clip Deinterlace, int InputType, val Source, val bVec1, val fVec1, val bVec2, val fVec2, \
                                 int SubPel, int SubPelInterp, int hpad, int vpad, int ThSAD1, int ThSCD1, int ThSCD2, int SourceMatch, \
                                 int MatchTR1, string MatchEdi, int MatchNNSize, int MatchNNeurons, int MatchEdiQual, int MatchEdiMaxD,\
                                 int MatchTR2, string MatchEdi2, int MatchNNSize2, int MatchNNeurons2, int MatchEdiQual2, int MatchEdiMaxD2, \
                                 float MatchEnhance, int EdiThreads, bool lsb, bool n16, bool "bomt", bool "fulls" )
{
    # >>>> YUY2: 'Deinterlace' is planar, 'Source' is interleaved (changed to planar here for all processing except interpolation) - returns planar result
    yuy2 = Source.IsYUY2()
    fs   = Default( fulls, false)
    Source = yuy2 ? Source.nonyuy2clipin(true) : Source
    sMDegnl  = n16 ? ", out16=n16" : lsb ? ", lsb=lsb" : ""
    sMDegnl  = Defined(bomt) ? sMDegnl + ", mt=bomt" : sMDegnl

    # Basic source-match. Find difference between source clip & equivalent fields in interpolated/smoothed clip (called the "error" in formula below). Ideally
    # there should be no difference, we want the fields in the output to be as close as possible to the source whilst remaining shimmer-free. So adjust the
    # *source* in such a way that smoothing it will give a result closer to the unadjusted source. Then rerun the interpolation (edi) and binomial smooth with
    # this new source. Result will still be shimmer-free and closer to the original source.
    # Formula used for correction is P0' = P0 + (P0-P1)/(k+S(1-k)), where P0 is original image, P1 is the 1st attempt at interpolation/smoothing , P0' is the
    # revised image to use as new source for interpolation/smoothing, k is the weighting given to the current frame in the smooth, and S is a factor indicating
    # "temporal similarity" of the error from frame to frame, i.e. S = average over all pixels of [neighbor frame error / current frame error] . Decreasing
    # S will make the result sharper, sensible range is about -0.25 to 1.0. Empirically, S=0.5 is effective [will do deeper analysis later]
    errorTemporalSimilarity = 0.5  # S in formula described above
    errorAdjust1   = Select( MatchTR1, 1.0, 2.0 / (1.0 + errorTemporalSimilarity), 8.0 / (3.0 + 5.0 * errorTemporalSimilarity) )
    match1Clip     = (SourceMatch < 1 || InputType == 1) ? Deinterlace : Deinterlace.SeparateFields().SelectEvery( 4, 0,3 ).Weave()
    match1Update   = (SourceMatch < 1 || MatchTR1 == 0) \
                        ? Source : mt_lutxy( Source, match1Clip, "x " + string(errorAdjust1 + 1) + " * y " + string(errorAdjust1) + " * -", clamp_float=true, use_expr=2, U=3,V=3 )
    noyv16ma1Edi   = MatchEdi =="NNEDI2" || MatchEdi =="NNEDI" || MatchEdi =="EEDI3+NNEDI3" || MatchEdi =="EEDI3" || MatchEdi =="TDeint" || MatchEdi =="cYadif" || MatchEdi =="RepcYadif"
    noyv16ma2Edi   = MatchEdi2=="NNEDI2" || MatchEdi2=="NNEDI" || MatchEdi2=="EEDI3+NNEDI3" || MatchEdi2=="EEDI3" || MatchEdi2=="TDeint" || MatchEdi2=="cYadif" || MatchEdi2=="RepcYadif"
    match1Edi      = (SourceMatch == 0) ? nop() : \
    !noyv16ma1Edi || !yuy2 ? match1Update.QTGMC_Interpolate( InputType, MatchEdi, MatchNNSize, MatchNNeurons, MatchEdiQual, MatchEdiMaxD, EdiThreads ) : \
                             match1Update.nonyuy2clipout(true)                                                                                           \
                                         .QTGMC_Interpolate( InputType, MatchEdi, MatchNNSize, MatchNNeurons, MatchEdiQual, MatchEdiMaxD, EdiThreads )   \
                                         .nonyuy2clipin(true)
    match1Super    = (SourceMatch > 0 && MatchTR1 > 0) ? Defined(bomt) ? match1Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, mt=bomt ) : match1Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad ) : nop()
    match1Degrain1 = (SourceMatch > 0 && MatchTR1 > 0) ? Eval("match1Edi.MDegrain1( match1Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()
    match1Degrain2 = (SourceMatch > 0 && MatchTR1 > 1) ? Eval("match1Edi.MDegrain1( match1Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()
    match1Degrain1 = (SourceMatch > 0 && MatchTR1 > 0) ? n16 ? match1Degrain1.ConvertBits(8,dither=-1) : match1Degrain1 : match1Degrain1
    match1Degrain2 = (SourceMatch > 0 && MatchTR1 > 1) ? n16 ? match1Degrain2.ConvertBits(8,dither=-1) : match1Degrain2 : match1Degrain2
    match1         = (SourceMatch < 1) ? Deinterlace                                                          : \
                     (MatchTR1 == 0)   ? match1Edi                                                            : \
                     (MatchTR1 == 1)   ? match1Degrain1.Merge( match1Edi, 0.25 )                              : \
                                         match1Degrain1.Merge( match1Degrain2, 0.2 ).Merge( match1Edi, 0.0625 )

    # Enhance effect of source-match stages 2 & 3 by sharpening clip prior to refinement (source-match tends to underestimate so this will leave result sharper)
    match1Shp = (SourceMatch > 1 && MatchEnhance > 0.0) ? match1.ex_lutxy( match1.RemoveGrain( 12 ), "x x y - "+ string(MatchEnhance) + " * +", clamp_float=true, UV=3, fulls=fs ) : match1

    # Source-match refinement. Find difference between source clip & equivalent fields in (updated) interpolated/smoothed clip. Interpolate & binomially smooth
    # this difference then add it back to output. Helps restore differences that the basic match missed. However, as this pass works on a difference rather than
    # the source image it can be prone to occasional artefacts (difference images are not ideal for interpolation). In fact a lower quality interpolation such
    # as a simple bob often performs nearly as well as advanced, slower methods (e.g. NNEDI3)
    match2Clip     = (SourceMatch  < 2 || InputType == 1) ? match1Shp : match1Shp.SeparateFields().SelectEvery( 4, 0,3 ).Weave()
    match2Diff     = (SourceMatch  > 1) ? ex_makediff( Source, match2Clip, UV=3, fulls=fs ) : nop()
    match2Edi      = (SourceMatch <= 1) ? nop() : \
    !noyv16ma2Edi || !yuy2 ? match2Diff.QTGMC_Interpolate( InputType, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, MatchEdiMaxD2, EdiThreads ) : \
                             match2Diff.nonyuy2clipout(true)                                                                                                \
                                       .QTGMC_Interpolate( InputType, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, MatchEdiMaxD2, EdiThreads )   \
                                       .nonyuy2clipin(true)
    match2Super    = (SourceMatch > 1 && MatchTR2 > 0) ? Defined(bomt) ? match2Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, mt=bomt ) : match2Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad ) : nop()
    match2Degrain1 = (SourceMatch > 1 && MatchTR2 > 0) ? Eval("match2Edi.MDegrain1( match2Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()
    match2Degrain2 = (SourceMatch > 1 && MatchTR2 > 1) ? Eval("match2Edi.MDegrain1( match2Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()
    match2Degrain1 = (SourceMatch > 1 && MatchTR2 > 0) ? n16 ? match2Degrain1.ConvertBits(8,dither=-1) : match2Degrain1 : match2Degrain1
    match2Degrain2 = (SourceMatch > 1 && MatchTR2 > 1) ? n16 ? match2Degrain2.ConvertBits(8,dither=-1) : match2Degrain2 : match2Degrain2
    match2         = (SourceMatch < 2) ? match1                                                               : \
                     (MatchTR2 == 0)   ? match2Edi                                                            : \
                     (MatchTR2 == 1)   ? match2Degrain1.Merge( match2Edi, 0.25 )                              : \
                                         match2Degrain1.Merge( match2Degrain2, 0.2 ).Merge( match2Edi, 0.0625 )

    # Source-match second refinement - correct error introduced in the refined difference by temporal smoothing. Similar to error correction from basic step
    errorAdjust2   = Select( MatchTR2, 1.0, 2.0 / (1.0 + errorTemporalSimilarity), 8.0 / (3.0 + 5.0 * errorTemporalSimilarity) )
    match3Update   = (SourceMatch < 3 || MatchTR2 == 0) \
                         ? match2Edi : ex_lutxy( match2Edi, match2, "x " + string(errorAdjust2 + 1) + " * y " + string(errorAdjust2) + " * -", clamp_float=true, UV=3, fulls=fs )
    match3Super    = (SourceMatch > 2 && MatchTR2 > 0) ? Defined(bomt) ? match3Update.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, mt=bomt ) : match3Update.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad ) : nop()
    match3Degrain1 = (SourceMatch > 2 && MatchTR2 > 0) ? Eval("match3Update.MDegrain1( match3Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()
    match3Degrain2 = (SourceMatch > 2 && MatchTR2 > 1) ? Eval("match3Update.MDegrain1( match3Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2" + sMDegnl + ")") : nop()
    match3Degrain1 = (SourceMatch > 2 && MatchTR2 > 0) ? n16 ? match3Degrain1.ConvertBits(8,dither=-1) : match3Degrain1 : match3Degrain1
    match3Degrain2 = (SourceMatch > 2 && MatchTR2 > 1) ? n16 ? match3Degrain2.ConvertBits(8,dither=-1) : match3Degrain2 : match3Degrain2
    match3         = (SourceMatch < 3) ? match2                                                                  : \
                     (MatchTR2 == 0)   ? match3Update                                                            : \
                     (MatchTR2 == 1)   ? match3Degrain1.Merge( match3Update, 0.25 )                              : \
                                         match3Degrain1.Merge( match3Degrain2, 0.2 ).Merge( match3Update, 0.0625 )

    # Apply difference calculated in source-match refinement
    return (SourceMatch < 2) ? match1 : match1Shp.ex_adddiff( match3, UV=3, fulls=fs )
}


# Set global variable called "Prefix_Name" to "Value". Throws exception if global already exists unless Replace=true, in which case the global is overwritten
function QTGMC_SetUserGlobal( string Prefix, string Name, val Value, bool "Replace" )
{
    Replace = Default( Replace, false )
    globalName = Prefix + "_" + Name

    # Tricky logic to check global: enter catch block if Replace=true *or* globalName doesn't exist (i.e. need to set the global), the exception is not rethrown
    # Not entering catch block means that Replace=false and global exists - so it throws an exception back to AviSynth
    try { Assert( !Replace && Defined(Eval(globalName)) ) }
    catch (e)
    {
        Eval( "global " + globalName + " = Value" )
        Replace = true
    }
    Assert( Replace, """Multiple calls to QTGMC, set PrevGlobals="Replace" or read documentation on 'Multiple QTGMC Calls'""" )
}

# Return value of global variable called "Prefix_Name". Returns nop() if it doesn't exist or Reuse is false
function QTGMC_GetUserGlobal( string Prefix, string Name, bool "Reuse" )
{
    Reuse = Default( Reuse, false )
    globalName = Prefix + "_" + Name

    try       { ret = Reuse ? Eval( globalName ) : nop() }
    catch (e) { ret = nop() }
    return ret
}