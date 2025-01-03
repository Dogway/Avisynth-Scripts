#---------------------------------------------------------------------#
#                                                                     #
#   QTGMC 3.33       by Vit,   2012                                   #
#   QTGMC 3.34d  mod by Dogway 2015                                   #
#   QTGMC 3.382s mod by A.SONY 2021, based on 3.34d                   #
#   QTGMC 4.6  + mod by Dogway 2025, based on 3.382s                  #
#                                                                     #
#   https://forum.doom9.org/showthread.php?t=182881                   #
#                                                                     #
#   Original Thread and AviSynth docs:                                #
#      https://forum.doom9.org/showthread.php?t=156028                #
#      https://avisynth.nl/index.php/QTGMC                            #
#                                                                     #
#   Quasi Temporal Gauss Motion Compensation Plus:                    #
#     Originally based on TempGaussMC_beta2 by Didée                  #
#     A high quality deinterlacer using motion-compensated temporal   #
#     smoothing, with a range of features for quality and convenience #
#                                                                     #
#---------------------------------------------------------------------#
#
# Acknowledgements by Vit:
#   "Thanks go to Didée for the script from where this began.
#   Also thanks to the plugin coders: Manao, Fizick, Tritical, Kassandro, Tsp, SEt, Tom Barry, Foxyshadis, TSchniede, Kurosu, mg262 and any others..
#   And to the many people who have given feedback, reported bugs and offered suggestions to help improve the script"
#
#
# QTGMC+ features and changes (since v3.382s):
#     - Frame properties support
#     - Increased performance for HBD (+40%)
#     - PC range aware
#     - Pruned noop or redundant arguments
#     - Sanitized + adapted code and expressions to align to AVS+ features
#     - More features and bug fixes (read the changelog at the bottom)
#
#
# --- DEPENDENCIES ---
#
# Input formats: YUV, YUY2, between 8-bit and 16-bit
#
# Core plugins:
#   MVTools2     (2.7.45 or above)
#   MaskTools2   (2.2.30 or above)
#   RgTools      (1.2    or above)
#   vsTCanny     (1.1.8  or above) (for gaussian blur)
#   NNEDI3CL     (1.0.7  or above) (for gpuid=0)
#   BWDIF        (1.2.5  or above)
#   Vinverse     (0.9.4  or above)
#
# Core scripts:
#   ExTools      (10.5   or above)
#   ResizersPack (12.1   or above) (for nnedi3wrap() or EEDI3wrap() )
#   SMDegrain    (4.7.0  or above) (for ex_luma_rebuild() or KNLMeansCL/BM3D denoiser types)
#
# Optional:
#   TDeInt, NNEDI, NNEDI2, EEDI3/EEDI3CL, EEDI2/EEDI2CUDA (requires recent drivers) - if selected directly via EdiMode or a source-match preset
#   yadifmod2    (0.2.7  or above) - if selected for EdiMode
#   KNLMeansCL   (1.1.1e or above) - if selected for noise processing
#   DFTTest      (1.9.6  or above) - if selected for noise processing
#   BM3D         (test10 or above) - if selected for noise processing
#   neo_FFT3D    (r11    or above) - if selected for noise processing
#       For neo_FFT3D & DFTTest you also need the FFTW3 library (FFTW.org). On Windows the file needed for both is libfftw3f-3.dll and placed in your System32 or SysWow64 folder
#   AddGrainC    (1.8.4  or above) - if NoiseDeint="Generate" selected for NoiseProcess


# --- GETTING STARTED ---
#
# Install AviSynth and ensure you have at least the core plugins listed in the requirements section above. Put them in the plugins autoload folder.
#
# To use QTGMC+ write a script like this:
#   SourceLoader("yourfile")               # Mainly DGSource() or FFVideoSource()
#   QTGMCp( Preset="Slow", FPSDivisor=1 )  # FPSDivisor=1 for double (frame)rate, =2 for half-rate
#   Prefetch(8)                            # Add SourceMatch>0 to QTGMCp() if dealing with Anime to avoid ghosting artifacts
#
# Save this script with an ".avs" extension. You can now use it as a placeholder of an AVI file for encoding.
#
# The "Preset" used selects sensible settings for a given encoding speed. Choose a preset from:
#   "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast" & "Draft"
# The default preset is "Slower"
#
# Don't be obsessed with using slower settings as the differences can be small.
# HD material benefits little from extreme settings (and will be very slow)
#
# There are many settings for tweaking the script, full details in the main documentation:
# https://raw.githack.com/Dogway/Avisynth-Scripts/master/MIX%20mods/QTGMC%20Docs%20(v3.33).html
#
# You can display settings currently being used with 'Show':
#   QTGMCp( Preset="Slow", Show=true )
#
#
# Function Definition:
#     (
#     clip yuv,
#     string "Preset"="Slower" ("Placebo"/ "Very Slow"/ "Slower"/ "Slow"/ "Medium"/ "Fast"/ "Faster"/ "Very Fast"/ "Super Fast"/ "Ultra Fast"/ "Draft"),
#     [int "TR0"=2 (0 to 4)],
#     [int "TR1"=2 (0 to 4)],
#     [int "TR2"=1 (0 to 4)],
#     [float "Sharpness"=1.0 (0.0 to 1.0)],
#     [float "SVThin"=0.0 (0.0 to 0.5 by 0.05)],
#     int "thSAD1"=640 (100 to 1000),
#     int "thSAD2"=256 (100 to 1000),
#     int "SourceMatch"=0 (0 to 3),
#     string "EdiMode"="NNEDI3" ("Bob"/ "Yadif"/ "RepYadif"/ "TDeint"/ "BWDIF"/ "NNEDI"/ "NNEDI2"/ "NNEDI3"/ "EEDI2"/ "EEDI3"/ "EEDI3+NNEDI3"/ "BWDIF+NNEDI3"/ "BWDIF+EEDI3"/ "Yadif+NNEDI3"/ "BOB+NNEDI3"/ "BWDIF+BOB"/ "BWDIF+BOB+NNEDI3"),
#     string "MatchPreset"="Slow" ("Placebo"/ "Very Slow"/ "Slower"/ "Slow"/ "Medium"/ "Fast"/ "Faster"/ "Very Fast"/ "Super Fast"/ "Ultra Fast"/ "Draft"),
#     string "MatchPreset2"="Slow" ("Placebo"/ "Very Slow"/ "Slower"/ "Slow"/ "Medium"/ "Fast"/ "Faster"/ "Very Fast"/ "Super Fast"/ "Ultra Fast"/ "Draft"),
#     [int "MatchTR2"=1 (0 to 2)],
#     float "MatchEnhance"=0.5 (0.0 to 1.0 by 0.05),
#     int "Lossless"=0 (0 to 2),
#     float "EZDenoise"=0.0 (0.0 to 3.0),
#     float "EZKeepGrain"=1.0 (0.0 to 1.0),
#     string "NoisePreset"="Faster" ("Slower"/ "Slow"/ "Medium"/ "Fast"/ "Faster"),
#     [int "InputType"=0 (0 to 3)],
#     [int "ShutterBlur"=0 (0 to 3)],
#     [int "FPSDivisor"=1 (1 to 2)],
#     [bool "moiree"=false],
#     [bool "Precise"=false],
#     [string "Tuning"="None" ("None"/ "DV-SD"/ "DV-HD")],
#     bool "show"=false,
#     [bool "tv_range"=true],
#     int "threads"=4 (2 to 16 by 2)
#     )
#
# Preset call:
#     QTGMCp(thSAD1=640, thSAD2=256, Preset="slower", SourceMatch=0, MatchPreset="slow", MatchPreset2="slow", MatchEnhance=0.5, Lossless=0, EZDenoise=0.0, EZKeepGrain=1.0, NoisePreset="Faster", FPSDivisor=1, threads=4, show=false)
#
function QTGMCp( clip Input, string "Preset", int "TR0", int "TR1", int "TR2", int "Rep0", int "Rep1", int "Rep2", string "EdiMode", bool "RepChroma", \
                 int "NNSize", int "NNeurons", int "EdiQual", int "EdiMaxD", string "ChromaEdi", clip "EdiExt", float "Sharpness", \
                 int "SMode", int "SLMode", int "SLRad", int "SOvs", float "SVThin", int "Sbb", int "SrchClipPP", int "SubPel", int "SubPelInterp", \
                 int "BlockSize", int "Overlap", int "Search", int "SearchParam", int "PelSearch", bool "ChromaMotion", bool "TrueMotion", int "Lambda", \
                 int "LSAD", int "PNew", int "PLevel", bool "GlobalMotion", int "DCT", int "ThSAD1", int "ThSAD2", int "ThSCD1", int "ThSCD2", \
                 bool "moiree", int "SourceMatch", string "MatchPreset", string "MatchEdi", string "MatchPreset2", string "MatchEdi2", int "MatchTR2", \
                 float "MatchEnhance", int "Lossless", int "NoiseProcess", float "EZDenoise", float "EZKeepGrain", string "NoisePreset", string "Denoiser", \
                 bool "DenoiseMC", int "NoiseTR", float "Sigma", bool "ChromaNoise", val "ShowNoise", float "GrainRestore", \
                 float "NoiseRestore", string "NoiseDeint", bool "StabilizeNoise", int "InputType", float "ProgSADMask", int "FPSDivisor", \
                 int "ShutterBlur", float "ShutterAngleSrc", float "ShutterAngleOut", int "SBlurLimit", bool "Border", bool "Precise", string "Tuning", \
                 bool "Show", string "GlobalNames", string "PrevGlobals", int "ForceTR", int "UseEdiExt", \
                 float "Str", float "Amp", bool "tv_range", bool "n16", bool "n16d", int "gpuid", int "Threads", bool "Refinemotion" )
{

    rgb       = Input.isRGB()
    yuy2      = Input.isYUY2()
    bi        = Input.BitsPerComponent()
    bi8       = bi == 8
    bi32m     = bi == 32 ? "" : "range_half -"  # Scale Inputs in Expr() is broken for 32-bit float. Anyway 32-bit is currently (2023) unsupported for MVTools.
    bi32p     = bi == 32 ? "" : "range_half +"
    fb        = GetParity(Input) ? 2 : 1
    fb        = propNumElements(Input, "_FieldBased")  > 0 ?     \
                propGetInt     (Input, "_FieldBased")  : IsFrameBased(Input) ? 0 : fb
    fs        = propNumElements(Input, "_ColorRange")  > 0 ? \
                propGetInt     (Input, "_ColorRange") == 0 : rgb
    input     = propNumElements(Input, "_DurationNum") > 0 ? input : \
                propSet        (Input, "_DurationNum", FrameRateDenominator(input))
    input     = propNumElements(Input, "_DurationDen") > 0 ? input : \
                propSet        (Input, "_DurationDen", FrameRateNumerator  (input))

    #---------------------------------------
    # Presets
    n16       = Default( n16,       false)
    n16d      = Default( n16d,      false)
    moiree    = Default( moiree,    false)
    UseEdiExt = Default( useEdiExt,    0 )
    St        = Default( Str,        5.0 )
    Amp       = Default( Amp,     0.0312 )
    tv        = Default( TV_range,    !fs)

    Assert(IsVersionOrGreater(3,7,3),            "QTGMC+: Update AviSynth+ version")
    Assert(!(!Defined(EdiExt) && UseEdiExt > 0), "QTGMC+: UseEdiExt>0 requires 'EdiExt' to be defined")

    # Select presets / tuning
    Preset = Default( Preset, "Slower" )

    pNum =   (Preset       == "Placebo"   ) ?  0 : \
             (Preset       == "Very Slow" ) ?  1 : \
             (Preset       == "Slower"    ) ?  2 : \
             (Preset       == "Slow"      ) ?  3 : \
             (Preset       == "Medium"    ) ?  4 : \
             (Preset       == "Fast"      ) ?  5 : \
             (Preset       == "Faster"    ) ?  6 : \
             (Preset       == "Very Fast" ) ?  7 : \
             (Preset       == "Super Fast") ?  8 : \
             (Preset       == "Ultra Fast") ?  9 : \
             (Preset       == "Draft"     ) ? 10 : \
             Assert( false, "QTGMC+: 'Preset' choice is invalid" )

    mpNum1 = (!Defined(MatchPreset))        ? min(pNum+2,9) : \
             (MatchPreset  == "Placebo"   ) ?  0 : \
             (MatchPreset  == "Very Slow" ) ?  1 : \
             (MatchPreset  == "Slower"    ) ?  2 : \
             (MatchPreset  == "Slow"      ) ?  3 : \
             (MatchPreset  == "Medium"    ) ?  4 : \
             (MatchPreset  == "Fast"      ) ?  5 : \
             (MatchPreset  == "Faster"    ) ?  6 : \
             (MatchPreset  == "Very Fast" ) ?  7 : \
             (MatchPreset  == "Super Fast") ?  8 : \
             (MatchPreset  == "Ultra Fast") ?  9 : \
             (MatchPreset  == "Draft"     ) ? 10 : \
             Assert( false, "QTGMC+: 'MatchPreset' choice is invalid" )

    MatchPreset = Select( mpNum1, "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast", "Draft" )

    mpNum2 = (!Defined(MatchPreset2))       ? mpNum1 : \
             (MatchPreset2 == "Placebo"   ) ?  0 : \
             (MatchPreset2 == "Very Slow" ) ?  1 : \
             (MatchPreset2 == "Slower"    ) ?  2 : \
             (MatchPreset2 == "Slow"      ) ?  3 : \
             (MatchPreset2 == "Medium"    ) ?  4 : \
             (MatchPreset2 == "Fast"      ) ?  5 : \
             (MatchPreset2 == "Faster"    ) ?  6 : \
             (MatchPreset2 == "Very Fast" ) ?  7 : \
             (MatchPreset2 == "Super Fast") ?  8 : \
             (MatchPreset2 == "Ultra Fast") ?  9 : \
             (MatchPreset2 == "Draft"     ) ? 10 : \
             Assert( false, "QTGMC+: 'MatchPreset2' choice is invalid" )
    MatchPreset2 = Select( mpNum2, "Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast", "Draft" )

    NoisePreset = Default( NoisePreset, "Fast" )
    npNum =  (NoisePreset  == "Slower"    ) ?  0 : \
             (NoisePreset  == "Slow"      ) ?  1 : \
             (NoisePreset  == "Medium"    ) ?  2 : \
             (NoisePreset  == "Fast"      ) ?  3 : \
             (NoisePreset  == "Faster"    ) ?  4 : \
             Assert( false, "QTGMC+: 'NoisePreset' choice is invalid" )

    Tuning = Default( Tuning, "None" )
    tNum =   (Tuning       == "None"      ) ?  0 : \
             (Tuning       == "DV-SD"     ) ?  1 : \
             (Tuning       == "DV-HD"     ) ?  2 : \
             Assert( false, "QTGMC+: 'Tuning' choice is invalid" )

    # Tunings only affect blocksize in this version
    bs  = Select( tNum, 16, 16, 32 )
    bs2 = min(bs * 2, 32)
    DEM = Defined(EdiMode)

    # EdiMode: moiree=false defaults to "NNEDI3", otherwise: BWDIF+BOB+NNEDI3       BWDIF+BOB          BWDIF+NNEDI3      NNEDI3    NNEDI3    BWDIF      BWDIF     BWDIF
    #                                                                 Very                                                        Very      Super      Ultra
    # Preset groups:                                       Placebo    Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast       Fast       Draft
    TR0          = Default( TR0,          Select( pNum,    2,         2,        2,        2,        2,        2,        1,        1,        1,         1,         0        ) )
    TR1          = Default( TR1,          Select( pNum,    2,         2,        2,        1,        1,        1,        1,        1,        1,         1,         1        ) )
    TR2X         = Default( TR2,          Select( pNum,    3,         2,        1,        1,        1,        0,        0,        0,        0,         0,         0        ) )
    Rep0         = Defined(Rep0) ? Rep0 : TR0 < 1 ? 0 :   Undefined()
    Rep0         = Default( Rep0,         Select( pNum,    4,         4,        4,        4,        3,        3,        0,        0,        0,         0,         0        ) )
    Rep1         = Default( Rep1,         Select( pNum,    0,         0,        0,        0,        0,        0,        0,        0,        0,         0,         0        ) )
    Rep2         = Default( Rep2,         Select( pNum,    4,         4,        4,        4,        4,        4,        4,        4,        3,         3,         0        ) )
    EdiMode      = Default( EdiMode,      Select( pNum,"BWDIF+BOB+NNEDI3","BWDIF+BOB+NNEDI3","BWDIF+BOB","BWDIF+BOB","BWDIF+NNEDI3","BWDIF+NNEDI3","NNEDI3","NNEDI3","BWDIF","BWDIF","BWDIF"))
    EdiMode      = DEM ? EdiMode : !moiree && pnum < 7 ? "NNEDI3" : EdiMode
    NNSize       = Default( NNSize,       Select( pNum,    1,         1,        1,        1,        5,        5,        4,        4,        4,         4,         4        ) )
    NNeurons     = Default( NNeurons,     Select( pNum,    2,         2,        1,        1,        1,        0,        0,        0,        0,         0,         0        ) )
    EdiQual      = Default( EdiQual,      Select( pNum,    2,         1,        1,        1,        1,        1,        1,        1,        1,         1,         1        ) )
    EdiMaxD      = Default( EdiMaxD,      Select( pNum,   12,        10,        8,        7,        7,        6,        6,        5,        4,         4,         4        ) )
    SMode        = Default( SMode,        Select( pNum,    2,         2,        2,        2,        2,        2,        2,        2,        2,         2,         0        ) )
    SLModeX      = Default( SLMode,       Select( pNum,    2,         2,        2,        2,        2,        2,        2,        2,        0,         0,         0        ) )
    SLRad        = Default( SLRad,        Select( pNum,    3,         1,        1,        1,        1,        1,        1,        1,        1,         1,         1        ) )
    Sbb          = Default( Sbb,          Select( pNum,    3,         1,        1,        0,        0,        0,        0,        0,        0,         0,         0        ) )
    SrchClipPP   = Default( SrchClipPP,   Select( pNum,    3,         3,        3,        3,        3,        2,        2,        2,        1,         1,         0        ) )
    SubPel       = Default( SubPel,       Select( pNum,    2,         2,        2,        2,        1,        1,        1,        1,        1,         1,         1        ) )
    Blocksize    = Default( Blocksize,    Select( pNum,   bs,        bs,       bs,       bs,       bs,       bs,      bs2,      bs2,      bs2,       bs2,       bs2        ) )
    bs = Blocksize
    sr = max(1,bs / 8)
    Overlap      = Default( Overlap,      Select( pNum,  bs/2,      bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/4,     bs/4,      bs/4,      bs/4       ) )
    Search       = Default( Search,       Select( pNum,     4,         4,        4,        4,        2,        2,        2,        2,        0,         0,         0       ) )
    SearchR      = Default( Search,       Select( pNum,     4,         0,        0,        0,        0,        0,        0,        0,        0,         0,         0       ) )
    SearchParam  = Default( SearchParam,  Select( pNum,    sr,        sr,       sr,       sr,       sr,       sr,       sr,       sr,       sr,        sr,        sr       ) )
    PelSearch    = Default( PelSearch,    Select( pNum,     1,         1,        1,        2,        2,        2,        2,        2,        2,         2,         2       ) )
    ChromaMotion = Default( ChromaMotion, Select( pNum,  true,      true,     true,     false,    false,    false,    false,    false,    false,     false,     false      ) )
    Precise      = Default( Precise,      Select( pNum,  true,      true,    false,     false,    false,    false,    false,    false,    false,     false,     false      ) )
    ProgSADMask  = Default( ProgSADMask,  Select( pNum,  10.0,      10.0,     10.0,      10.0,     10.0,      0.0,      0.0,      0.0,      0.0,       0.0,       0.0      ) )
#   Refinemotion = Default( Refinemotion, Select( pNum,  true,      true,    false,     false,    false,    false,    false,    false,    false,     false,     false      ) )
    Refinemotion = Default( Refinemotion, false) #https://github.com/Dogway/Avisynth-Scripts/pull/23#issuecomment-918586163

    # Noise presets                                                               Slower     Slow       Medium     Fast       Faster
    Denoiser       = Default( Denoiser,                           Select( npNum,  "DFTTest", "DFTTest", "DFTTest",  "FFT3D",   "FFT3D" ) )
    DenoiseMC      = Default( DenoiseMC,                          Select( npNum,       true,      true,     false,    false,     false ) )
    NoiseTR        = Default( NoiseTR,                            Select( npNum,          2,         1,         1,        1,         0 ) )
    NoiseDeint     = Default( NoiseDeint,                         Select( npNum, "Generate",     "Bob",        "",       "",        "" ) )
    StabilizeNoise = Default( StabilizeNoise,                     Select( npNum,       true,      true,      true,    false,     false ) )

    # The basic source-match step corrects and re-runs the interpolation of the input clip. So it initially uses same interpolation settings as the main preset
    SourceMatch    = Default( SourceMatch, 0 )
    MatchNNSize    = NNSize
    MatchNNeurons  = NNeurons
    MatchEdiMaxD   = EdiMaxD
    MatchEdiQual   = EdiQual

    # However, can use a faster initial interpolation when using source-match allowing the basic source-match step to "correct" it with higher quality settings
    Assert( SourceMatch == 0 || mpNum1 >= pNum, "QTGMC+: 'MatchPreset' cannot use a slower setting than 'Preset'" )
    #                                                                    Very                                                         Very      Super     Ultra
    # Basic source-match presets                                Placebo  Slow       Slower    Slow      Medium    Fast      Faster    Fast      Fast      Fast
    NNSize   = (SourceMatch == 0) ? NNSize   : Select( mpNum1,  1,       1,         1,        1,        5,        5,        4,        4,        4,        4     )
    NNeurons = (SourceMatch == 0) ? NNeurons : Select( mpNum1,  2,       2,         1,        1,        1,        0,        0,        0,        0,        0     )
    EdiMaxD  = (SourceMatch == 0) ? EdiMaxD  : Select( mpNum1,  12,      10,        8,        7,        7,        6,        6,        5,        4,        4     )
    EdiQual  = (SourceMatch == 0) ? EdiQual  : Select( mpNum1,  2,       1,         1,        1,        1,        1,        1,        1,        1,        1     )
    TempEdi  = EdiMode # Main interpolation is actually done by basic-source match step when enabled, so a little swap and wriggle is needed
    EdiMode  = (SourceMatch == 0) ? EdiMode  : Default( MatchEdi, ((mpNum1 < 9) ?  EdiMode : "BWDIF") ) # Force BWDIF for "Ultra Fast" basic source match
    MatchEdi = TempEdi

    #                                                                     Very                                                        Very      Super     Ultra
    # Refined source-match presets                              Placebo   Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast      Fast
    MatchNNSize2                             = Select( mpNum2,  1,        1,        1,        1,        5,        5,        4,        4,        4,        4     )
    MatchNNeurons2                           = Select( mpNum2,  2,        2,        1,        1,        1,        0,        0,        0,        0,        0     )
    MatchEdiMaxD2                            = Select( mpNum2, 12,       10,        8,        7,        7,        6,        6,        5,        4,        4     )
    MatchEdiQual2                            = Select( mpNum2,  2,        1,        1,        1,        1,        1,        1,        1,        1,        1     )
    MatchEdi2 = Default( MatchEdi2, ((mpNum2 < 9) ?  MatchEdi : "BWDIF"))


    #---------------------------------------
    # Settings

    # Core and Interpolation defaults
    TR2          = (SourceMatch > 0) ? Default(TR2, ((TR2X == 0) ? 1 : TR2X)) : TR2X  # ***TR2 defaults always at least 1 when using source-match***
    RepChroma    = Default( RepChroma,  true )
    Threads      = Default( Threads,       8 )
    gpuid        = Default( gpuid,         0 )
    bomt         = Threads != 1
    ChromaEdi    = Default( ChromaEdi,  ""   )
    NNeurons     = (EdiMode == "NNEDI2" && NNeurons > 2) ? 2 : NNeurons # Smaller range for NNeurons in NNEDI2 (which calls it nsize)
    EdiQual      = (EdiMode == "NNEDI3" || FindStr(UCase(EdiMode),"+NNEDI3")>0 || FindStr(UCase(EdiMode),"+EEDI3")>0) && EdiQual > 2 ? 2 : EdiQual  # Capping to 2 max

    # Source-match / lossless defaults
    MatchTR1     = TR1
    MatchTR2     = Default( MatchTR2,     1   )
    MatchEnhance = Default( MatchEnhance, 0.5 )
    Lossless     = Default( Lossless,     0   )
    Assert( Lossless <= 2, "QTGMC+: Lossless setting only supports mode 1 ('true lossless') and mode 2 ('fake lossless') - see documentation in script and consider source-match settings" )

    # Sharpness defaults. Sharpness default is always 1.0 (0.2 with source-match), but adjusted to give roughly same sharpness for all settings
    SMode        = (Defined(Sharpness) && Sharpness == 0.0) ? 0 : SMode
    SLMode       = (SourceMatch > 0) ? Default(SLMode, 0)       : SLModeX  # ***Sharpness limiting disabled by default for source-match***
    SLMode       = (SLRad      <= 0) ? 0 : SLMode
    spatialSL    = (SLMode%2   != 0)
    temporalSL   = (SLMode%2   == 0) && SLMode > 0
    Sharpness    = Default( Sharpness, (SMode == 0) ? 0.0 : ((SourceMatch > 0) ? 0.2 : 1.0) )      # Default sharpness is 1.0, or 0.2 if using source-match
    sharpMul     = (temporalSL) ? 2 : (spatialSL) ? 1.5 : 1                                        # Adjust sharpness based on other settings
    sharpAdj     = Sharpness * (sharpMul * (0.2 + TR1*0.15 + TR2*0.25) + ((SMode == 1) ? 0.1 : 0)) # [This needs a bit more refinement]
    Sbb          = (SMode == 0) ? 0 : Sbb
    SOvs         = Default( SOvs,   0   )
    SVThin       = Default( SVThin, 0.0 )

    # Noise processing settings
    Assert( !Defined(EZDenoise) || EZDenoise <= 0.0 || !Defined(EZKeepGrain) || EZKeepGrain <= 0.0, "QTGMC+: EZDenoise and EZKeepGrain cannot be used together" )
    ChromaNoise     =  Default( ChromaNoise, false )
    NoiseProcess    =  Defined(NoiseProcess) ? NoiseProcess              : \
                      (Defined(EZDenoise)   && EZDenoise   > 0.0)    ? 1 : \
                      (Defined(EZKeepGrain) && EZKeepGrain > 0.0)    ? 2 : \
                      (Preset == "Placebo" || Preset == "Very Slow") ? 2 : ChromaNoise ? 1 : 0
    GrainRestore    =  Defined(GrainRestore) ? GrainRestore              : \
                      (Defined(EZDenoise)   && EZDenoise   > 0.0) ? 0.0  : \
                      (Defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 0.3 * sqrt(EZKeepGrain) : \
                                                                   Select( NoiseProcess, 0.0, 0.7, 0.3 )
    NoiseRestore    =  Defined(NoiseRestore) ? NoiseRestore              : \
                      (Defined(EZDenoise)   && EZDenoise   > 0.0) ? 0.0  : \
                      (Defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 0.1 * sqrt(EZKeepGrain) : \
                                                                   Select( NoiseProcess, 0.0, 0.3, 0.1 )
    Sigma           =  Defined(Sigma)        ? Sigma                     : \
                      (Defined(EZDenoise)   && EZDenoise   > 0.0) ?       EZDenoise   : \
                      (Defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 4.0 * EZKeepGrain : 2.0
    ShowNoise       = Default( ShowNoise,   0.0 )
    ShowNoise       = IsBool(  ShowNoise) ? (ShowNoise ? 10.0 : 0.0) : ShowNoise
    NoiseProcess    = (ShowNoise   > 0.0) ? 2   : NoiseProcess
    NoiseRestore    = (ShowNoise   > 0.0) ? 1.0 : NoiseRestore
    NoiseTR         = (NoiseProcess == 0) ? 0   : NoiseTR
    GrainRestore    = (NoiseProcess == 0) ? 0.0 : GrainRestore
    NoiseRestore    = (NoiseProcess == 0) ? 0.0 : NoiseRestore
    totalRestore    = GrainRestore + NoiseRestore
    StabilizeNoise  = (totalRestore <= 0) ? false : StabilizeNoise
    noiseTD         = Select( NoiseTR, 1, 3, 5 )
    noiseCentre     = ex_bs((Denoiser == "DFTTest") ? 128 : 128.5, 8, bi, fulls=!tv, flt=true)

    # MVTools settings
    SubPelInterp    = Default( SubPelInterp, 2     )
    TrueMotion      = Default( TrueMotion,   false )
    GlobalMotion    = Default( GlobalMotion, true  )
    Lambda          = Default( Lambda, (TrueMotion ? 1000 : 100 ) * (BlockSize*BlockSize)/(8*8) )
    LSAD            = Default( LSAD,    TrueMotion ? 1200 : 400 )
    PNew            = Default( PNew,    TrueMotion ? 50   : 25  )
    PLevel          = Default( PLevel,  TrueMotion ? 1    : 0   )
    DCT             = Default( DCT,                         0   )
    ThSAD1          = Default( ThSAD1,               10 * 8*8   )
    ThSAD2          = Default( ThSAD2,                4 * 8*8   )
    ThSCD1          = Default( ThSCD1,      round(  2.8 * 8*8)  )
    ThSCD2          = Default( ThSCD2,      round( 1.53 * 8*8)  )

    # Motion blur settings
    FPSDivisor      = Default( FPSDivisor,          1 )
    ShutterBlur     = Default( ShutterBlur,         0 )
    ShutterAngleSrc = Default( ShutterAngleSrc,   180 )
    ShutterAngleOut = Default( ShutterAngleOut,   180 )
    SBlurLimit      = Default( SBlurLimit,          4 )
    ShutterBlur     = (ShutterAngleOut * FPSDivisor == ShutterAngleSrc) ? 0 : ShutterBlur  # If motion blur output is same as input

    # Miscellaneous
    InputType       = Default( InputType,     0        )
    Border          = Default( Border,        false    )
    ShowSettings    = Default( Show,          false    )
    GlobalNames     = Default( GlobalNames,  "QTGMCp"  )
    PrevGlobals     = Default( PrevGlobals,  "Replace" )
    ForceTR         = Default( ForceTR,       0        )
    ReplaceGlobals  = (PrevGlobals == "Replace" || PrevGlobals == "Reuse") # If reusing existing globals put them back afterwards - simplifies logic later
    ReuseGlobals    = (PrevGlobals == "Reuse")
    ProgSADMask     = (InputType < 2) ? 0.0 : ProgSADMask
    input           =                            yuy2  ? ConvertToYUV422(input,interlaced=InputType>0) : input
    EdiExt          = Defined(EdiExt) ? isYUY2(EdiExt) ? ConvertToYUV422(EdiExt)                       : EdiExt : Undefined()


    # RefineMotion Defaults (Beware 8x8 blocks blur out output in QTGMC+)
    halfoverlap = Overlap  /2
    halfblksize = BlockSize/2
    halfthSAD   = round(thSAD2/2.)

    # Get maximum temporal radius needed
    maxTR = (temporalSL)       ?  SLRad : 0
    maxTR = max(MatchTR2, TR1, TR2, NoiseTR, maxTR)
    maxTR = (ProgSADMask > 0.0 || StabilizeNoise || ShutterBlur > 0) ? max(maxTR,1) : maxTR
    maxTR = max(ForceTR, MaxTR)


    #---------------------------------------
    # Pre-Processing

    w    = Input.Width()
    h    = Input.Height()
    isHD = (w > 1099 || h > 599)
    eps  = 0.0001
    scUV = isHD ? 2 : 0

    # Reverse "field" dominance for progressive repair mode 3 (only difference from mode 2)
    compl = InputType == 2 ? Input.                   propSet("_Field", GetParity(Input) ? 1 : 0) : \
            InputType == 3 ? Input.ComplementParity().propSet("_Field", GetParity(Input) ? 0 : 1) : Input

    # Pad vertically during processing (to prevent artefacts at top & bottom edges)
    clip = (Border) ? compl.PointResize( w,h+8, 0,-4,0,h+8+eps ) : compl  # Same as PadBorders(0,4,0,4,"Dilate")
    h    = (Border) ? h+8 : h

    # Calculate padding needed for MVTools super clips to avoid crashes [fixed in latest MVTools, but keeping this code for a while]
    hpad = w - (Int((w - Overlap) / (Blocksize - Overlap)) * (Blocksize - Overlap) + Overlap)
    vpad = h - (Int((h - Overlap) / (Blocksize - Overlap)) * (Blocksize - Overlap) + Overlap)
    hpad = max(hpad,8) # But match default padding if possible
    vpad = max(vpad,8)


    #---------------------------------------
    # Motion Analysis

    CMmt = ChromaMotion ? 3   :  2
    CMts = ChromaMotion ? 255 :  0
    CMrg = ChromaMotion ? 12  : -1

    # Bob the input as a starting point for motion search clip
    bobbed = (InputType == 0) ? UseEdiExt > 0 ? EdiExt : clip.BWDIF(field=fb+1, thr=0, pass=true) : \
             (InputType == 1) ? clip                                                              : \
                                clip.ex_boxblur( 0, 1, "weighted", UV=CMmt)
    bobbed = (InputType == 0) && (UseEdiExt > 1 || moiree) ? bobbed.vinverse(amnt=moiree?ex_bs(1,8,bi,fs):Undefined(),UV=CMmt) : bobbed

    # If required, get any existing global clips with a matching "GlobalNames" setting. Unmatched values get NOP (= 0)
    srchClip  = QTGMCp_GetUserGlobal( GlobalNames, "srchClip",  ReuseGlobals )
    srchSuper = QTGMCp_GetUserGlobal( GlobalNames, "srchSuper", ReuseGlobals )

    bVec2 = Undefined()
    fVec2 = Undefined()
    for (i=1, maxTR, 1) {

        Eval(Format("""bVec{i} = QTGMCp_GetUserGlobal( GlobalNames, "bVec{i}", ReuseGlobals )"""))
        Eval(Format("""fVec{i} = QTGMCp_GetUserGlobal( GlobalNames, "fVec{i}", ReuseGlobals )"""))
    }

    srchcheck = IsClip(srchClip)

    # The bobbed clip will shimmer due to being derived from alternating fields. Temporally smooth over the neighboring frames using a binomial kernel. Binomial
    # kernels give equal weight to even and odd frames and hence average away the shimmer. The two kernels used are [1 2 1] and [1 4 6 4 1] for radius 1 and 2.
    # These kernels are approximately Gaussian kernels, which work well as a prefilter before motion analysis (hence the original name for this script)
    # Create linear weightings of neighbors first                                             -2    -1     0    1     2
    ts1 = (!srchcheck && TR0 > 0) ? bobbed.TemporalSoften( 1, 255, CMts, 28, 2 ) : nop()  # 0.00  0.33  0.33  0.33  0.00
    ts2 = (!srchcheck && TR0 > 1) ? bobbed.TemporalSoften( 2, 255, CMts, 28, 2 ) : nop()  # 0.20  0.20  0.20  0.20  0.20

    # Combine linear weightings to give binomial weightings - TR0=0: (1), TR0=1: (1:2:1), TR0=2: (1:4:6:4:1)
      domtr02 = TR0 == -2 && !(InputType == 0 && UseEdiExt > 1)
      domtr01 = TR0 == -1 && !(InputType == 0 && UseEdiExt > 1)
    binomial0 = srchcheck        ? nop() : \
      domtr02 && Defined(EdiExt) ? EdiExt.vinverse(uv=CMmt) : TR0 == -2 ? bobbed                              : \
      domtr01 && Defined(EdiExt) ? EdiExt                   : TR0 == -1 ? bobbed                              : \
                (TR0 == 0)       ? bobbed                                                                     : \
                (TR0 == 1)       ? (ChromaMotion ? ts1.Merge( bobbed, 0.25 ) : ts1.MergeLuma( bobbed, 0.25 )) : \
                                                   ex_lutxyz(ts1,ts2,bobbed,"x 0.5625 * y 0.3125 * z 0.125 * + +", UV=CMmt) # Kinda would like to optimize using ex_blur3D(0,z=1) but has no SC

    # Remove areas of difference between temporal blurred motion search clip and bob that are not due to bob-shimmer - removes general motion blur
    repair0 = (srchcheck || Rep0 == 0) ? binomial0 : binomial0.QTGMCp_KeepOnlyBobShimmerFixes( bobbed, Rep0, (RepChroma && ChromaMotion), !tv )

    # Blur image and soften edges to assist in motion matching of edge blocks. Blocks are matched by SAD (sum of absolute differences between blocks), but even
    # a slight change in an edge from frame to frame will give a high SAD due to the higher contrast of edges
    # Originally call in SrchClipPP == 1 was blurring by resizing (with Bilinear) which strength is dependant of input size
    spatialBlur = (SrchClipPP == 0 || srchcheck) ? nop()                           : \
                  (SrchClipPP == 1) ? repair0.vsTCanny(1.90,mode=-1,u=CMmt,v=CMmt) : \
                                      repair0.vsTCanny(1.96,mode=-1,u=CMmt,v=CMmt)  # vsTcanny is chroma subsampling aware

    spatialBlur = (SrchClipPP > 1 && IsClip(spatialBlur)) ? (ChromaMotion ? spatialBlur.Merge( repair0, 0.1 ) : spatialBlur.MergeLuma( repair0, 0.1 )) : spatialBlur

    srchClip    =  srchcheck        ? srchClip            : \
                  (SrchClipPP == 0) ? repair0             : \
                  (SrchClipPP  < 3) ? spatialBlur         : \
                  (SrchClipPP  > 2) ? spatialBlur.ex_lutxyz( repair0, bobbed, "x 7 scalef + z y 3 scalef - y 3 scalef + clip Y@ < x 2 scalef + x 7 scalef - Y > x 2 scalef - Y x - 0.49 * x + ? ?", UV=CMmt, fulls=!tv ) : nop()
    srchClip    = !srchcheck        ? srchClip.ex_Luma_Rebuild(S0=St, c=Amp, tv_in=tv, tv_out=false, uv=CMmt, bits=8) : srchClip.ConvertBits(8,dither=-1)

    # Calculate forward and backward motion vectors from motion search clip
    srchSuper = IsClip(srchSuper) ? srchSuper                                                                                                        : \
                (maxTR > 0)       ? srchClip.MSuper( pel=SubPel, sharp=SubPelInterp, hpad=hpad, vpad=vpad, chroma=ChromaMotion, rfilter=3, mt=bomt ) : nop()


    for (i=-maxTR, maxTR, 1) {

        if (i!=0) {

            ia  = abs(i)
            str = i < 0 ? Format("bVec{ia}") : Format("fVec{ia}")

            Eval(Format(str+"c = IsClip("+str+")
            "+str+" = "+str+"c ? "+str+" : (maxTR > {ia}-1) ? srchSuper.MAnalyse( isb={i}<0,  delta={ia}, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
                                                                                  pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel,     \
                                                                                  global=GlobalMotion, DCT=DCT, chroma=ChromaMotion, badSAD=3200, mt=bomt, scaleCSAD=scUV ) : nop()

            "+str+" = "+str+"c || !RefineMotion || !(maxTR > {ia}-1) ? "+str+" : srchSuper.MRecalculate("+str+", overlap=halfoverlap, blksize=halfblksize, thSAD=halfthSAD, DCT=DCT, \
                                                                                                         chroma=ChromaMotion, truemotion=TrueMotion, search=Search, scaleCSAD=scUV,  \
                                                                                                         searchparam=SearchParam, lambda=Lambda, pnew=PNew, mt=bomt)"))
    } }

    # Expose search clip, motion search super clip and motion vectors to calling script through globals
    QTGMCp_SetUserGlobal( GlobalNames, "srchClip",  srchClip,  ReplaceGlobals )
    QTGMCp_SetUserGlobal( GlobalNames, "srchSuper", srchSuper, ReplaceGlobals )

    for (i=1, maxTR, 1) {

        QTGMCp_SetUserGlobal( GlobalNames, Format("bVec{i}"), Eval(Format("bVec{i}")), ReplaceGlobals )
        QTGMCp_SetUserGlobal( GlobalNames, Format("fVec{i}"), Eval(Format("fVec{i}")), ReplaceGlobals )
    }



    #---------------------------------------
    # Noise Processing

    # Expand fields to full frame size before extracting noise (allows use of motion vectors which are frame-sized)
    fullClip  = (NoiseProcess == 0)   ? nop()                        : \
                (InputType > 0)       ? clip                         : \
                                        clip.ex_bob( 0,1.0,props=1)
    fullSuper = (NoiseTR   > 0)       ? fullClip.MSuper( pel=SubPel, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise, rfilter=3, mt=bomt ) : nop() #TEST chroma OK?

    # Create a motion compensated temporal window around current frame and use to guide denoisers
    noiseWindow = (NoiseProcess == 0) ? nop()    : \
                  (!DenoiseMC)        ? fullClip : \
                  (NoiseTR == 0)      ? fullClip : \
                  (NoiseTR == 1)      ? Interleave( fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt ),    \
                                                    fullClip, \
                                                    fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt ) ) : \
                                        Interleave( fullClip.MCompensate( fullSuper, fVec2, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt ),    \
                                                    fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt ),    \
                                                    fullClip, \
                                                    fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt ),    \
                                                    fullClip.MCompensate( fullSuper, bVec2, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt ) )
    noiseWindow = (NoiseProcess != 0) && n16d ? noiseWindow.ConvertBits(16,fulls=!tv)        : noiseWindow
    dnWindow    = (NoiseProcess == 0)         ? nop() : \
                  (Denoiser == "DFTTest")     ? noiseWindow.DFTTest( Y=true, U=ChromaNoise, V=ChromaNoise, sigma=Sigma*4, tbsize=noiseTD, threads=1, Dither=1 ) : \
                  (Denoiser == "KNLMeansCL")  ? noiseWindow.ex_KNLMeansCL(Chroma=ChromaNoise, a=2, d=NoiseTR, h=Sigma, gpuid=gpuid )                            : \
                  (Denoiser == "BM3D")        ? noiseWindow.ex_BM3D(sigma=Sigma,radius=NoiseTR,preset="Normal",UV=3  , gpuid=gpuid )                            : \
                  (Denoiser == "FFT3D")       ? noiseWindow.neo_fft3d( sigma=Sigma, bt=noiseTD, mt=bomt, ncpu=min(4,Threads), u=max(2,CMmt), v=max(2,CMmt))     : \
                                                Assert( false, "QTGMC+: Couldn't find a matching 'Denoiser' type" )
    dnwindow    = (NoiseProcess != 0) && n16d ? dnwindow.ConvertBits(bi,dither=-1,fulls=!tv) : dnwindow

    # Rework denoised clip to match source format - various code paths here: discard the motion compensation window, discard doubled lines (from point resize)
    # Also reweave to get interlaced noise if source was interlaced (could keep the full frame of noise, but it will be poor quality from the point resize)
    denoised = (NoiseProcess == 0) ? nop()                                                                                  : \
               (!DenoiseMC)        ? ((InputType > 0) ? dnWindow : dnWindow.SeparateFields().SelectEvery( 4, 0,3 ).Weave()) : \
               (InputType     > 0) ? ((NoiseTR  == 0) ? dnWindow : dnWindow.SelectEvery( noiseTD, NoiseTR ))                : \
                                     dnWindow.SeparateFields().SelectEvery( noiseTD*4, NoiseTR*2,NoiseTR*6+3 ).Weave()

    CNmt1   = ChromaNoise ? 3 : 2
    CNmt128 = ChromaNoise ? 3 : 128

    # Get actual noise from difference. Then 'deinterlace' where we have weaved noise - create the missing lines of noise in various ways
    planarDenoised = (NoiseProcess == 0) ? nop()                                                                                  : denoised
    noise          = (totalRestore >  0) ? ex_makediff( clip, planarDenoised, UV=CNmt1, fulls=!tv )                               : nop()
    deintNoise     = (NoiseProcess == 0 || totalRestore == 0.0) ? nop()                                                           : \
                     (InputType    != 0)                        ? noise                                                           : \
                     (NoiseDeint   == "Bob")                    ? noise.ex_bob( 0,0.5,props=1)                                    : \
                     (NoiseDeint   == "Generate")               ? noise.QTGMCp_Generate2ndFieldNoise( denoised, ChromaNoise, !tv) : \
                                                                  noise.DoubleWeave()
    # Motion-compensated stabilization of generated noise
    noiseSuper = (StabilizeNoise) ? deintNoise.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise, rfilter=3, mt=bomt ) : nop()
    mcNoise    = (StabilizeNoise) ? deintNoise.MCompensate( noiseSuper, bVec1, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt )                                          : nop()
    finalNoise = (StabilizeNoise) ? ex_lutxy( deintNoise, mcNoise, "x "+bi32m+" abs y "+bi32m+" abs > x y ? 0.6 * x y + 0.2 * +", UV=CNmt1, fulls=!tv )         : deintNoise

    # If NoiseProcess=1 denoise input clip. If NoiseProcess=2 leave noise in the clip and let the temporal blurs "denoise" it for a stronger effect
    innerClip = (NoiseProcess == 1) ? denoised : clip


    #---------------------------------------
    # Interpolation

    # Support badly deinterlaced progressive content - drop half the fields and reweave to get 1/2fps interlaced stream appropriate for QTGMC+ processing
    ediInput = (InputType > 1) ? innerClip.SeparateFields().SelectEvery(4,0,3).Weave() : innerClip

    # Create interpolated image as starting point for output. Below same as but in one step: PadBorders(0,0,0,(EdiExt.Height()-h)/2,"Dilate").crop(0,(EdiExt.Height()-h)/2,0,0)
    edi1 = Defined(EdiExt) ? EdiExt.PointResize( w,h, 0,(EdiExt.Height()-h)/2, -0,h+eps )                                                               : \
                             QTGMCp_Interpolate( ediInput.ConvertBits(8,dither=-1,fulls=!tv), InputType, EdiMode, NNSize, NNeurons, EdiQual, EdiMaxD, Threads, bobbed, ChromaEdi, fulls=!tv, gpuid=gpuid ).ConvertBits(bi,fulls=!tv)

    # InputType=2,3: use motion mask to blend luma between original clip & reweaved clip based on ProgSADMask setting. Use chroma from original clip in any case
    inputTypeBlend = (ProgSADMask  > 0.0) ? MMask( srchClip, bVec1, kind=1, ml=ProgSADMask ).ConvertBits(bi,fulls=true) : nop()
    edi            = (InputType    < 2  ) ? edi1                                               : \
                     (ProgSADMask <= 0.0) ? edi1.MergeChroma( innerClip )                      : \
                                            mt_merge( innerClip, edi1, inputTypeBlend, U=2,V=2 )

    # Get the max/min value for each pixel over neighboring motion-compensated frames - used for temporal sharpness limiting
    ediSuper = (TR1 > 0 || temporalSL)    ? edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, rfilter=3, mt=bomt ) : nop()
    bComp1   = (temporalSL)               ? edi.MCompensate( ediSuper, bVec1, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt                        ) : nop()
    fComp1   = (temporalSL)               ? edi.MCompensate( ediSuper, fVec1, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt                        ) : nop()
    tMax     = (temporalSL)               ? edi.ex_lutxyz  ( fComp1, bComp1, "x y max z max", UV=3, fulls=!tv                              ) : nop()
    tMin     = (temporalSL)               ? edi.ex_lutxyz  ( fComp1, bComp1, "x y min z min", UV=3, fulls=!tv                              ) : nop()
    bComp3   = (SLRad > 1 && temporalSL)  ? edi.MCompensate( ediSuper, bVec3, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt                        ) : nop()
    fComp3   = (SLRad > 1 && temporalSL)  ? edi.MCompensate( ediSuper, fVec3, thSCD1=ThSCD1, thSCD2=ThSCD2, mt=bomt                        ) : nop()
    tMax     = (SLRad > 1 && temporalSL)  ? tMax.ex_lutxyz ( fComp3, bComp3, "x y max z max", UV=3, fulls=!tv                              ) : tMax
    tMin     = (SLRad > 1 && temporalSL)  ? tMin.ex_lutxyz ( fComp3, bComp3, "x y min z min", UV=3, fulls=!tv                              ) : tMin
    sMDegnl  = n16 ? ", out16=n16" : ""


    #---------------------------------------
    # Create basic output

    # Use motion vectors to blur interpolated image (edi) with motion-compensated previous and next frames. As above, this is done to remove shimmer from
    # alternate frames so the same binomial kernels are used. However, by using motion-compensated smoothing this time we avoid motion blur. The use of
    # MDegrain1 (motion compensated) rather than TemporalSoften makes the weightings *look* different, but they evaluate to the same values
    # Create linear weightings of neighbors first                                                                                                       -2    -1     0    1     2
    degrain1  = (TR1  > 0) ? Eval("edi.MDegrain1( ediSuper, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()  # 0.00  0.33  0.33  0.33  0.00
    degrain2  = (TR1  > 1) ? Eval("edi.MDegrain1( ediSuper, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()  # 0.33  0.00  0.33  0.00  0.33
    degrain1  = (TR1  > 1) ? degrain1 : (TR1 > 0) ? n16 ? degrain1.ConvertBits(8,dither=-1,fulls=!tv)    : degrain1 : degrain1
    # Combine linear weightings to give binomial weightings - TR1=0: (1), TR1=1: (1:2:1), TR1=2: (1:4:6:4:1)
    degrain2  = (TR1  > 1) ? ex_lutxyz(degrain1,degrain2,edi,"x 0.75 * y 0.1875 * z 0.0625 * + +", UV=3) : degrain2

    binomial1 = (TR1 == 0) ? edi                          : \
                (TR1 == 1) ? degrain1.Merge( edi, 0.25 )  : \
                       n16 ? degrain2.ConvertBits(8,dither=-1,fulls=!tv) : degrain2

    # Remove areas of difference between smoothed image and interpolated image that are not bob-shimmer fixes: repairs residual motion blur from temporal smooth
    repair1 =  (Rep1 == 0) ? binomial1 : binomial1.QTGMCp_KeepOnlyBobShimmerFixes( edi, Rep1, RepChroma, !tv )

    # Apply source match - use difference between output and source to succesively refine output [extracted to function to clarify main code path]
    match = (SourceMatch == 0) ? repair1 : \
                                 repair1.QTGMCp_ApplySourceMatch( InputType, ediInput, bVec1,fVec1, bVec2,fVec2, SubPel, SubPelInterp, hpad, vpad,              \
                                                                  ThSAD1, ThSCD1, ThSCD2, SourceMatch, MatchTR1, MatchEdi, MatchNNSize, MatchNNeurons,           \
                                                                  MatchEdiQual, MatchEdiMaxD, MatchTR2, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2,  \
                                                                  MatchEdiMaxD2, MatchEnhance, Threads, n16, bomt, !tv, gpuid )

    # Lossless=2 - after preparing an interpolated, de-shimmered clip, restore the original source fields into it and clean up any artefacts.
    # This mode will not give a true lossless result because the resharpening and final temporal smooth are still to come, but it will add further detail.
    # However, it can introduce minor combing. This setting is best used together with source-match (it's effectively the final source-match stage).
    lossed1 = (Lossless == 2) ? QTGMCp_MakeLossless( match, innerClip, InputType, !tv ) : match


    #---------------------------------------
    # Resharpen / retouch output (rework resharp and sharpLimit1 and 2 to skip chroma and add a final chroma recovery option?)

    # Resharpen to counteract temporal blurs. Little sharpening needed for source-match mode since it has already recovered sharpness from source
    vresharp1 = (SMode == 2) ? lossed1.ex_lut("x[0,-1] A@ x[0,0] B@ max x[0,1] C@ max A B min C min + 0.5 *",    UV=3)             : nop()
    vresharp  = (Precise && SMode == 2) ? vresharp1.ex_lutxy( lossed1, "y x 1 scalef - x 1 scalef + clip",       UV=3, fulls=!tv ) : vresharp1 # Precise mode: reduce tiny overshoot
    resharp   = (SMode == 0) ? lossed1                                                                                             : \
                (SMode == 1) ? lossed1.ex_lutxy(  lossed1.RemoveGrain( 12 ), Format("x dup y - {sharpAdj} * +"), UV=3, fulls=!tv ) : \
                               lossed1.ex_lutxy( vresharp.RemoveGrain( 12 ), Format("x dup y - {sharpAdj} * +"), UV=3, fulls=!tv )

    # Slightly thin down 1-pixel high horizontal edges that have been widened into neighboring field lines by the interpolator
    SVThinSc  =  SVThin * 6.0

    if (SVthin > 0.0) {
        vertMedD  = ex_lut( lossed1, Format("x[0,-1] x[0,1] dup1 dup1 max swap2 min x swap2 clip x - {SVThinSc} * "+bi32p), clamp_float=true, UV=1, fulls=!tv ) # vertical median - x
        vertMedD  = vertMedD.ex_boxblur( 1, 0, "weighted", UV=1 )
        thin      = ex_lutxyz( vertMedD, vertMedD.RemoveGrain( 12, -1 ), resharp, "y "+bi32m+" Y@ abs x "+bi32m+" abs > Y z + z ?", UV=2, fulls=!tv  )
    } else {
        thin      = resharp
    }

    # Back blend the blurred difference between sharpened & unsharpened clip, before (1st) sharpness limiting (Sbb == 1,3). A small fidelity improvement
    backBlend1 = (Sbb%2 != 0)  ? thin : \
                                 thin.ex_makediff( ex_makediff( thin, lossed1, UV=1, fulls=!tv  ).vsTCanny(1.4,mode=-1,u=1,v=1), UV=2, fulls=!tv )

    # Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
    # Occurs here (before final temporal smooth) if SLMode == 1,2. This location will restrict sharpness more, but any artefacts introduced will be smoothed
    sharpLimit1 = (SLMode == 1) ? backBlend1.Repair( ((SLrad <= 1) ? edi : backBlend1.Repair( edi, 12, 12 )), 1, 1 ) : \
                  (SLMode == 2) ? backBlend1.ex_clamp( tMax, tMin, Sovs,Sovs, UV=3 )                                 : \
                                  backBlend1

    # Back blend the blurred difference between sharpened & unsharpened clip, after (1st) sharpness limiting (Sbb == 2,3). A small fidelity improvement
    backBlend2 = (Sbb < 2) ? sharpLimit1 : \
                             sharpLimit1.ex_makediff( ex_makediff( sharpLimit1, lossed1, UV=1, fulls=!tv ).vsTCanny(1.4,mode=-1,u=1,v=1), UV=2, fulls=!tv )

    # Add back any extracted noise, prior to final temporal smooth - this will restore detail that was removed as "noise" without restoring the noise itself
    # Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
    addNoise1 = (GrainRestore  > 0.0) && (Sbb > 1) ? sharpLimit1.ex_lutxyz(ex_makediff( sharpLimit1, lossed1, UV=1, fulls=!tv ).vsTCanny(1.4,mode=-1,u=2,v=2), finalNoise,              \
                                                                         Format("z {noiseCentre} - {GrainRestore} * {noiseCentre} + 0 range_max clip x y - +"), UV=CNmt1, fulls=!tv ) : \
                (GrainRestore <= 0.0) ? backBlend2                                                                                                                                    : \
                                        backBlend2.ex_lutxy( finalNoise, Format("y {noiseCentre} - {GrainRestore} * range_half neg range_half   clip x     +"), UV=CNmt1, fulls=!tv )

    # Final light linear temporal smooth for denoising
    stableSuper = (TR2  > 0) ? addNoise1.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, rfilter=3, mt=bomt ) : nop()
    stable      = (TR2 == 0) ? addNoise1 : \
                  (TR2 == 1) ? Eval("addNoise1.MDegrain1( stableSuper, bVec1,fVec1,                                                                  thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : \
                  (TR2 == 2) ? Eval("addNoise1.MDegrain2( stableSuper, bVec1,fVec1, bVec2,fVec2,                                                     thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : \
                  (TR2 == 3) ? Eval("addNoise1.MDegrain3( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3,                                        thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : \
                  (TR2 == 4) ? Eval("addNoise1.MDegrain4( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, bVec4,fVec4,                           thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : \
                  (TR2 == 5) ? Eval("addNoise1.MDegrain5( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, bVec4,fVec4, bVec5,fVec5,              thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : \
                               Eval("addNoise1.MDegrain6( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, bVec4,fVec4, bVec5,fVec5, bVec6,fVec6, thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")")
    stable      =  TR2  > 0 && n16 ? stable.ConvertBits(8,dither=-1,fulls=!tv) : stable

    # Remove areas of difference between final output & basic interpolated image that are not bob-shimmer fixes: repairs motion blur caused by temporal smooth
    repair2 = (Rep2 == 0) ? stable : stable.QTGMCp_KeepOnlyBobShimmerFixes( edi, Rep2, RepChroma, !tv )
    repair2 = repair2.propCopy(bobbed)

    # Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
    # Occurs here (after final temporal smooth) if SLMode == 3,4. Allows more sharpening here, but more prone to introducing minor artefacts
    sharpLimit2 = (SLMode == 3) ? repair2.Repair( ((SLrad <= 1) ? edi : repair2.Repair( edi, 12, 12 )), 1, 1 ) : \
                  (SLMode == 4) ? repair2.ex_clamp( tMax,tMin, Sovs,Sovs, UV=3 )                               : \
                                  repair2

    # Lossless=1 - inject source fields into result and clean up inevitable artefacts. Provided NoiseRestore=0.0 or 1.0, this mode will make the script result
    # properly lossless, but this will retain source artefacts and cause some combing (where the smoothed deinterlace doesn't quite match the source)
    lossed2 = (Lossless == 1) ? QTGMCp_MakeLossless( sharpLimit2, innerClip, InputType, !tv ) : sharpLimit2

    # Add back any extracted noise, after final temporal smooth. This will appear as noise/grain in the output
    # Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
    addNoise2 = (NoiseRestore <= 0.0) ? lossed2 : \
                                        lossed2.ex_lutxy( finalNoise, Format("y {noiseCentre} - {NoiseRestore} * range_half neg range_half clip x +"), UV=CNmt1, fulls=!tv )


    #---------------------------------------
    # Post-Processing

    # Shutter motion blur - get level of blur depending on output framerate and blur already in source
    blurLevel = (ShutterAngleOut * FPSDivisor - ShutterAngleSrc) * 100.0 / 360.0
    Assert( blurLevel >=   0, "QTGMC+: Cannot reduce motion blur already in source: increase ShutterAngleOut or FPSDivisor" )
    Assert( blurLevel <= 200, "QTGMC+: Exceeded maximum motion blur level: decrease ShutterAngleOut or FPSDivisor" )

    # ShutterBlur mode 2,3 - get finer resolution motion vectors to reduce blur "bleeding" into static areas
    rBlockDivide = Select( ShutterBlur, 1, 1, 2, 4 )
    rBlockSize   = max(BlockSize / rBlockDivide, 4 )
    rOverlap     = max(  Overlap / rBlockDivide, 2 )
    rBlockDivide =     BlockSize / rBlockSize
    rLambda      =        Lambda /(rBlockDivide * rBlockDivide)
    sbBVec1 = (ShutterBlur > 1) ? srchSuper.MRecalculate( bVec1, thSAD=ThSAD1, blksize=rBlockSize, overlap=rOverlap, search=Search, searchparam=SearchParam, \
                                                          truemotion=TrueMotion, lambda=Lambda, pnew=PNew, DCT=DCT, chroma=ChromaMotion, scaleCSAD=scUV, mt=bomt  ) : bVec1
    sbFVec1 = (ShutterBlur > 1) ? srchSuper.MRecalculate( fVec1, thSAD=ThSAD1, blksize=rBlockSize, overlap=rOverlap, search=Search, searchparam=SearchParam, \
                                                          truemotion=TrueMotion, lambda=Lambda, pnew=PNew, DCT=DCT, chroma=ChromaMotion, scaleCSAD=scUV, mt=bomt  ) : fVec1

    # Shutter motion blur - use MFlowBlur to blur along motion vectors
    sblurSuper   = (ShutterBlur >  0) ? addNoise2.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, rfilter=3, mt=bomt ) : nop()
    sblur        = (ShutterBlur >  0) ? addNoise2.MFlowBlur( sblurSuper, sbBVec1, sbFVec1, blur=blurLevel, thSCD1=ThSCD1, thSCD2=ThSCD2 )      : nop()

    # Shutter motion blur - use motion mask to reduce blurring in areas of low motion - also helps reduce blur "bleeding" into static areas, then select blur type
    sbMotionMask = (ShutterBlur  > 0 && SBlurLimit > 0) ? MMask( srchClip, bVec1, kind=0, ml=SBlurLimit ).ConvertBits(bi,fulls=true)           : nop()
    sblurred     = (ShutterBlur == 0) ? addNoise2                                         : \
                   (SBlurLimit  == 0) ? sblur                                             : \
                                        mt_merge( addNoise2, sblur, sbMotionMask, U=3,V=3 )
    # Reduce frame rate
    decimated    = (FPSDivisor  != 1) ? sblurred.SelectEvery( FPSDivisor, 0 ) : sblurred
    decimated    = (FPSDivisor  != 1) ? ScriptClip(decimated,function[FPSDivisor]() {
                                        propSet("_DurationDen",propGetInt("_DurationDen")/FPSDivisor)
                                        } ) : sblurred
    # Crop off temporary vertical padding
    cropped = Border ? decimated.Crop( 0, 4, -0, -4, true ) : decimated
    h       = Border ? h-8 : h

    # Show output of choice + settings
    # >>>> Restore YUY2 to interleaved
    output = (ShowNoise == 0.0) ? cropped : finalNoise.ex_lut(Format("x "+bi32m+" {ShowNoise} * "+bi32p), clamp_float=true, UV=CNmt128, fulls=!tv )
    output = yuy2 ? ConvertToYUY2(output,interlaced=false) : output
    output = output.propSet("_Combed", InputType==0 && (Lossless > 0 || pNum > 7) ? 1 : 0 )

    return !ShowSettings ? output : \
        output.Subtitle( "TR0=" + string(TR0) + " | TR1=" + string(TR1) + " | TR2=" + string(TR2) + " | Rep0=" + string(Rep0) + " | Rep1=" + string(Rep1) + \
        " | Rep2=" + string(Rep2) + " | RepChroma=" + string(RepChroma) + "\nEdiMode='" + EdiMode + "' | NNSize=" + string(NNSize) + " | NNeurons=" + \
        string(NNeurons) + " | EdiQual=" + string(EdiQual) + " | EdiMaxD=" + string(EdiMaxD) + " | ChromaEdi='" + ChromaEdi + "' | Threads=" + \
        string(Threads) + "\nSharpness=" + string(Sharpness, "%.2f") + " | SMode=" + string(SMode) + " | SLMode=" + string(SLMode) + " | SLRad=" + \
        string(SLRad) + " | SOvs=" + string(SOvs) + " | SVThin=" + string(SVThin, "%.2f") + " | Sbb=" + string(Sbb) + "\nSrchClipPP=" + string(SrchClipPP) + \
        " | SubPel=" + string(SubPel) + " | SubPelInterp=" + string(SubPelInterp) + " | BlockSize=" + string(BlockSize) + " | Overlap=" + string(Overlap) + \
        "\nSearch=" + string(Search) + " | SearchParam=" + string(SearchParam) + " | PelSearch=" + string(PelSearch) + " | ChromaMotion=" + \
        string(ChromaMotion) + " | TrueMotion=" + string(TrueMotion) + "\nLambda=" + string(Lambda) + " | LSAD=" + string(LSAD) + " | PNew=" + string(PNew) + \
        " | PLevel=" + string(PLevel) + " | GlobalMotion=" + string(GlobalMotion) + " | DCT=" + string(DCT) + "\nThSAD1=" + string(ThSAD1) + " | ThSAD2=" + \
        string(ThSAD2) + " | ThSCD1=" + string(ThSCD1) + " | ThSCD2=" + string(ThSCD2) + "\nSourceMatch=" + string(SourceMatch) + " | MatchPreset='" + \
        MatchPreset + "' | MatchEdi='" + MatchEdi + "'\nMatchPreset2='" + MatchPreset2 + "' | MatchEdi2='" + MatchEdi2 + "' | MatchTR2=" + string(MatchTR2) + \
        " | MatchEnhance=" + string(MatchEnhance, "%.2f") + " | Lossless=" + string(Lossless) + "\nNoiseProcess=" + string(NoiseProcess) + " | Denoiser='" + \
        Denoiser + "' | DenoiseMC=" + string(DenoiseMC) + " | NoiseTR=" + string(NoiseTR) + " | Sigma=" + \
        string(Sigma, "%.2f") + "\nChromaNoise=" + string(ChromaNoise) + " | ShowNoise=" + string(ShowNoise, "%.2f") + " | GrainRestore=" + \
        string(GrainRestore, "%.2f") + " | NoiseRestore=" + string(NoiseRestore, "%.2f") + "\nNoiseDeint='" + NoiseDeint + "' | StabilizeNoise=" + \
        string(StabilizeNoise) + " | InputType=" + string(InputType) + " | ProgSADMask=" + string(ProgSADMask, "%.2f") + "\nFPSDivisor=" + \
        string(FPSDivisor) + " | ShutterBlur=" + string(ShutterBlur) + " | ShutterAngleSrc=" + string(ShutterAngleSrc, "%.2f") + " | ShutterAngleOut=" + \
        string(ShutterAngleOut, "%.2f") + " | SBlurLimit=" + string(SBlurLimit) + "\nBorder=" + string(Border) + " | Precise=" + string(Precise) + \
        "\nPreset='" + Preset + "' | Tuning='" + Tuning + "' | GlobalNames='" + GlobalNames + "' | PrevGlobals='" + PrevGlobals + "' | ForceTR=" + string(ForceTR) + \
        "\nStr='" + string(St, "%.1f") + "' | Amp='" + string(Amp, "%.3f") + "' | tv_range='" + string(tv) + "' | gpuid='" + string(gpuid) + "' | Threads=" + string(Threads) + "' | RefineMotion=" + string(RefineMotion), \
        font="Lucida Console", size=0.014*w+1.84, lsp=12 )
}


#---------------------------------------
# Helpers

# Interpolate input clip using method given in EdiMode. Use Fallback or Bob as result if mode not in list. If ChromaEdi string if set then interpolate chroma
# separately with that method (only really useful for EEDIx). The function is used as main algorithm starting point and for first two source-match stages
function QTGMCp_Interpolate( clip Input, int InputType, string EdiMode, int NNSize, int NNeurons, int EdiQual, int EdiMaxD, int "Threads", clip "Fallback", string "ChromaEdi", bool "fulls", int "gpuid" ) {

    ChromaEdi = Default( ChromaEdi,  "" )
    CEed      =        ( ChromaEdi == "")
    id        = Default(gpuid,         0)
    threads   = Default(threads,       8)

    fb        = propNumElements  (Input,"_FieldBased") > 0 ? \
                propGetInt       (Input,"_FieldBased")     : 0
    fb        = fb==0 ? GetParity(Input) ? 3 : 2 : fb + 1

    NNEDI3clp = EdiMode == "NNEDI3"       || EdiMode == "EEDI3+NNEDI3" || EdiMode == "Yadif+NNEDI3" || \
                EdiMode == "BWDIF+NNEDI3" || EdiMode == "BWDIF+EEDI3" ? Input.nnedi3wrap( field=fb, nsize=NNSize, planes=CEed ? [0,1,2] : [0], gpuid=id, props=false, qual=EdiQual, nns=NNeurons, threads=threads) : Undefined()
    EEDI3clp  = EdiMode == "BWDIF+EEDI3" ?                              Input. EEDI3wrap( field=fb, mdis=EdiMaxD, planes=CEed ? [0,1,2] : [0], gpuid=id, props=false, sclip=NNEDI3clp ).QTGMCp_slimit_dif2(NNEDI3clp,thr=4,UV=CEed?3:2) : \
                EdiMode == "EEDI3" || EdiMode == "EEDI3+NNEDI3"       ? Input. EEDI3wrap( field=fb, mdis=EdiMaxD, planes=CEed ? [0,1,2] : [0], gpuid=id, props=false, sclip=NNEDI3clp )                            : nop()

    interp    = InputType == 1            ? Input                                                                                                    : \
                EdiMode == "NNEDI3"       ? NNEDI3clp                                                                                                : \
                EdiMode == "NNEDI2"       ? Input.NNEDI2( field=fb, U=CEed,V=CEed, nsize=NNeurons, qual=EdiQual, threads=Threads )                   : \
                EdiMode == "NNEDI"        ? Input.NNEDI ( field=fb, U=CEed,V=CEed )                                                                  : \
                EdiMode == "EEDI3+NNEDI3" ? EEDI3clp                                                                                                 : \
                EdiMode == "EEDI3"        ? EEDI3clp                                                                                                 : \
                EdiMode == "EEDI2"&&id>-1 ? Input.SeparateFields().EEDI2_CUDA( fb, maxd=EdiMaxD, device_id=id, num_streams=8)                        : \
                EdiMode == "EEDI2"        ? Input.SeparateFields().EEDI2(field=fb, maxd=EdiMaxD )                                                    : \
                EdiMode == "TDeint"       ? Input.TDeInt(   mode=1 )                                                                                 : \
                EdiMode == "Yadif"        ? Input.yadifmod2(mode=3,order=fb-1)                                                                       : \
                EdiMode == "Yadif+NNEDI3" ? Input.yadifmod2(mode=3,edeint=NNEDI3clp)                                                                 : \
                EdiMode == "RepYadif"     ? Repair( Input.yadifmod2(mode=3,order=fb-1),Default(Fallback, Input.ex_bob(0,0.5,props=1)),2,0)           : \
                EdiMode == "BWDIF+NNEDI3" ? Input.BWDIF(fb,edeint=NNEDI3clp)                                                                         : \
                EdiMode == "BWDIF+EEDI3"  ? Input.BWDIF(fb,edeint=EEDI3clp)                                                                          : \
                EdiMode == "BOB"          ? Input.ex_bob(0,1,props=1)                                                                                : \
                EdiMode == "BOB+NNEDI3"   ? Input.ex_bob(0,1,props=1,nnedi3=true,qual=EdiQual)                                                       : \
                EdiMode == "BWDIF+BOB"    ? Input.   BWDIF(fb,edeint=ex_bob(Input,0,1,  props=1))                                                    : \
                EdiMode == "BWDIF+BOB+NNEDI3"? Input.BWDIF(fb,edeint=ex_bob(Input,0,1,  props=1,nnedi3=true,qual=EdiQual))                           : \
                                            Default(Fallback,        ex_bob(Input,0,0.5,props=1) )

    interp    = InputType == 1            ? Input                                                                                                    : \
                EdiMode   =="BWDIF+NNEDI3"||EdiMode == "Yadif+NNEDI3" || \
                EdiMode   =="BWDIF+EEDI3" ? interp.vinverse(clip2=NNEDI3clp,UV=CEed?3:2)                                                             : \
                                            interp

    interpuv  = InputType == 1            ? nop()                                                                                                    : \
                ChromaEdi == "NNEDI3"     ? Input.nnedi3wrap(field=fb, nsize=4, nns=0, qual=1, planes=[1,2], props=false, gpuid=id, threads=threads) : \
                ChromaEdi == "Yadif"      ? Input.yadifmod2(mode=3,order=fb-1)                                                                       : \
                ChromaEdi == "Bob"        ? Input.ex_bob( 0,0.5,props=1)                                                                             : \
                                            nop()

    !IsClip(interpuv) ? interp : interp.MergeChroma( interpuv )
    return propSet("_FieldBased",0).propSet("_Field",fb%2) }



# Helper function: Compare processed clip with reference clip: only allow thin, horizontal areas of difference, i.e. bob shimmer fixes
# Rough algorithm: Get difference, deflate vertically by a couple of pixels or so, then inflate again. Thin regions will be removed
#                  by this process. Restore remaining areas of difference back to as they were in reference clip.
function QTGMCp_KeepOnlyBobShimmerFixes( clip Input, clip Ref, int Rep, bool Chroma, bool fulls ) {

    # 'ed' is the erosion distance - how much to deflate then reflate to remove thin areas of interest: 0 = minimum to 6 = maximum
    # 'od' is over-dilation level  - extra inflation to ensure areas to restore back are fully caught:  0 = none to 3 = one full pixel
    # If Rep < 10, then ed = Rep and od = 0, otherwise ed = 10s digit and od = 1s digit (nasty method, but kept for compatibility with original TGMC)
    fs     = Default( fulls,  false)
    Rep    = Default( Rep,    1     )
    Chroma = Default( Chroma, true )
    ed     = (Rep < 10) ? Rep : Rep / 10
    od     = (Rep < 10) ? 0   : Rep % 10
    RCrg   = Chroma ? 3 : 1

    bi     = Input.BitsPerComponent()
    diff   = ex_makediff(Ref, Input, UV=RCrg, fulls=fs )

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
    choke2 = (ed == 2 || ed == 5) ? choke2.RemoveGrain(4, chroma ? 4 : -1 )              : choke2

    choke0 =                        choke2.mt_inpand(   mode="vertical", U=RCrg,V=RCrg )
    choke0 = (ed > 1)             ? choke2.ex_inpand(2, mode="vertical", UV=RCrg       ) : choke0
    choke0 = (ed > 4)             ? choke2.ex_inpand(3, mode="vertical", UV=RCrg       ) : choke0

    # Over-erosion - extra deflation up to about 1 pixel
    choke2 = (od == 0)            ? choke0                                                         : \
             (od == 1)            ? choke0.mt_deflate( U=RCrg,V=RCrg )                             : \
             (od == 2)            ? choke0.mt_deflate( U=RCrg,V=RCrg ).mt_deflate( U=RCrg,V=RCrg ) : \
                                    choke0.mt_inpand ( U=RCrg,V=RCrg )

    # Combine above areas to find those areas of difference to restore
    ex_lutxyza(diff, choke1, choke2, Input, "x 129 scalef < x y range_half max ? A@ 127 scalef > A z range_half min ? a + range_half -", UV=Chroma ? 3 : 1, fulls=fs )
    }


# Given noise extracted from an interlaced source (i.e. the noise is interlaced), generate "progressive" noise with a new "field" of noise injected. The new
# noise is centered on a weighted local average and uses the difference between local min & max as an estimate of local variance
function QTGMCp_Generate2ndFieldNoise( clip Input, clip InterleavedClip, bool "ChromaNoise", bool "fulls" ) {

    ChromaNoise = Default( ChromaNoise, false )
    fs          = Default( fulls,       false )

    bi        = Input.BitsPerComponent()
    CNmt1     = ChromaNoise ? 3 : 1

    origNoise = Input.SeparateFields()
    noiseMax  = bi != 16 ? origNoise.ex_luts(mode="max",pixels=ex_shape(2,1),UV=CNmt1)                            : \
                           origNoise.ex_expand(2,mode="horizontal",UV=CNmt1).ex_expand(1,mode="vertical",UV=CNmt1) # ex_luts(...) is faster in all terms except in 16-bit P(8) (within QTGMC+ scope, not standalone)
    noiseMin  = bi != 16 ? origNoise.ex_luts(mode="min",pixels=ex_shape(2,1),UV=CNmt1)                            : \
                           origNoise.ex_inpand(2,mode="horizontal",UV=CNmt1).ex_inpand(1,mode="vertical",UV=CNmt1)
    random    = BlankClip( InterleavedClip.SeparateFields(), color_yuv=$808080 ).AddGrainC( var=1800, uvar=ChromaNoise ? 1800 : 0 )
    rsize     = bi==32 ? "" : bi > 12 ? "range_size /" : string(1. / ex_bs(256,8,bi,fs)) + " *"
    newNoise  = ex_lutxyz(noiseMax, noiseMin, random, "x y - 0 max z * "+rsize+" y +", UV=CNmt1, fulls=fs)

    return Interleave( origNoise, newNoise ).Weave()
}


# Insert the source lines into the result to create a true lossless output. However, the other lines in the result have had considerable processing and won't
# exactly match source lines. There will be some slight residual combing. Use vertical medians to clean a little of this away
function QTGMCp_MakeLossless( clip Input, clip Source, int InputType, bool fulls ) {

    Assert( InputType != 1, "QTGMC+: Lossless modes are incompatible with InputType=1" )

    # Weave the source fields and the "new" fields that have generated in the input
    srcFields  = (InputType == 0) ? Source.SeparateFields() : \
                                    Source.SeparateFields().SelectEvery( 4, 0,3 )
    newFields  = Input.SeparateFields().SelectEvery( 4, 1,2 )
    processed  = Interleave( srcFields, newFields ).SelectEvery(4, 0,1,3,2 ).Weave()

    # Clean some of the artefacts caused by the above - creating a second version of the "new" fields
    vertMedDiff = ex_lut( processed,  "x[0,-1] x[0,1] dup1 dup1 max swap2 min x swap2 clip x swap -", UV=3 ) # x - vertical median
    vmNewDiff1  = vertMedDiff.SeparateFields().SelectEvery( 4, 1,2 )
    vmNewDiff2  = ex_lut( vmNewDiff1, "x[0,-1] x[0,1] dup1 dup1 max swap2 min x swap2 clip M@ x * 0 < range_half M x min ?", UV=3, fulls=fulls )
    vmNewDiff3  = vmNewDiff2.Repair( vmNewDiff2.RemoveGrain( 2 ), 1 )

    # Re-weave final result
    return Interleave( srcFields, newFields.ex_makediff( vmNewDiff3, UV=3, dif=false )).SelectEvery( 4, 0,1,3,2 ).Weave()
}


# Source-match, a three stage process that takes the difference between deinterlaced input and the original interlaced source, to shift the input more towards
# the source without introducing shimmer. All other arguments defined in main script
function QTGMCp_ApplySourceMatch(clip Deinterlace, int InputType, val Source, val bVec1, val fVec1, val bVec2, val fVec2, \
                                 int SubPel, int SubPelInterp, int hpad, int vpad, int ThSAD1, int ThSCD1, int ThSCD2, int SourceMatch, \
                                 int MatchTR1, string MatchEdi, int MatchNNSize, int MatchNNeurons, int MatchEdiQual, int MatchEdiMaxD,\
                                 int MatchTR2, string MatchEdi2, int MatchNNSize2, int MatchNNeurons2, int MatchEdiQual2, int MatchEdiMaxD2, \
                                 float MatchEnhance, int Threads, bool n16, bool "bomt", bool "fulls", int "gpuid" ) {

    fs      = Default( fulls, false)
    id      = Default( gpuid,     0)
    sMDegnl = n16 ? ", out16=n16" : ""
    bi      = Source.BitsPerComponent()

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
                        ? Source : ex_lutxy( Source, match1Clip, Format("x dup y - {errorAdjust1} * +"), clamp_float=true, UV=3 )
    match1Edi      = (SourceMatch == 0) ? nop() : match1Update.ConvertBits(8,dither=-1,fulls=fs).QTGMCp_Interpolate( InputType, MatchEdi, MatchNNSize, MatchNNeurons, MatchEdiQual, MatchEdiMaxD, Threads, fulls=fs, gpuid=id ).ConvertBits(bi,fulls=fs)
    match1Super    = (SourceMatch > 0 && MatchTR1 > 0) ? match1Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, rfilter=3,   mt=bomt )                 : nop()
    match1Degrain1 = (SourceMatch > 0 && MatchTR1 > 0) ? Eval("match1Edi.MDegrain1( match1Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()
    match1Degrain2 = (SourceMatch > 0 && MatchTR1 > 1) ? Eval("match1Edi.MDegrain1( match1Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()
    match1Degrain1 = (SourceMatch > 0 && MatchTR1 > 0) ? n16 ? match1Degrain1.ConvertBits(8,dither=-1,fulls=fs) : match1Degrain1 : match1Degrain1
    match1Degrain2 = (SourceMatch > 0 && MatchTR1 > 1) ? n16 ? match1Degrain2.ConvertBits(8,dither=-1,fulls=fs) : match1Degrain2 : match1Degrain2
    match1         = (SourceMatch < 1) ? Deinterlace                                                            : \
                     (MatchTR1 == 0)   ? match1Edi                                                              : \
                     (MatchTR1 == 1)   ? match1Degrain1.Merge( match1Edi, 0.25 )                                : \
                                         ex_lutxyz(match1Degrain1,match1Degrain2,match1Edi, "x 0.75 * y 0.1875 * z 0.0625 * + +", UV=3)

    # Enhance effect of source-match stages 2 & 3 by sharpening clip prior to refinement (source-match tends to underestimate so this will leave result sharper)
    match1Shp = (SourceMatch > 1 && MatchEnhance > 0.0) ? match1.ex_lutxy( match1.RemoveGrain( 12 ), Format("x dup y - {MatchEnhance} * +"), clamp_float=true, UV=3, fulls=fs ) : match1

    # Source-match refinement. Find difference between source clip & equivalent fields in (updated) interpolated/smoothed clip. Interpolate & binomially smooth
    # this difference then add it back to output. Helps restore differences that the basic match missed. However, as this pass works on a difference rather than
    # the source image it can be prone to occasional artefacts (difference images are not ideal for interpolation). In fact a lower quality interpolation such
    # as a simple bob often performs nearly as well as advanced, slower methods (e.g. NNEDI3)
    match2Clip     = (SourceMatch  < 2 || InputType == 1) ? match1Shp : match1Shp.SeparateFields().SelectEvery( 4, 0,3 ).Weave()
    match2Diff     = (SourceMatch  > 1) ? ex_makediff( Source, match2Clip, UV=3, fulls=fs ) : nop()
    match2Edi      = (SourceMatch <= 1) ? nop() : match2Diff.ConvertBits(8,dither=-1,fulls=fs).QTGMCp_Interpolate( InputType, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, MatchEdiMaxD2, Threads, fulls=fs, gpuid=id ).ConvertBits(bi,fulls=fs)
    match2Super    = (SourceMatch > 1 && MatchTR2 > 0) ? match2Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, rfilter=3,   mt=bomt )                 : nop()
    match2Degrain1 = (SourceMatch > 1 && MatchTR2 > 0) ? Eval("match2Edi.MDegrain1( match2Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()
    match2Degrain2 = (SourceMatch > 1 && MatchTR2 > 1) ? Eval("match2Edi.MDegrain1( match2Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()
    match2Degrain1 = (SourceMatch > 1 && MatchTR2 > 0) ? n16 ? match2Degrain1.ConvertBits(8,dither=-1,fulls=fs) : match2Degrain1 : match2Degrain1
    match2Degrain2 = (SourceMatch > 1 && MatchTR2 > 1) ? n16 ? match2Degrain2.ConvertBits(8,dither=-1,fulls=fs) : match2Degrain2 : match2Degrain2
    match2         = (SourceMatch < 2) ? match1                                                                 : \
                     (MatchTR2 == 0)   ? (SourceMatch < 3) ? match1Shp.ex_adddiff(     match2Edi, UV=3, fulls=fs )                                                            : match2Edi         : \
                     (MatchTR2 == 1)   ? (SourceMatch < 3) ? match2Degrain1.ex_lutxyz( match2Edi,match1Shp,"x dup y - 0.25 * - z + range_half -", UV=3) : match2Degrain1.Merge( match2Edi, 0.25 ) : \
                                         (SourceMatch < 3) ? ex_lutxyza(match2Degrain1,match2Degrain2,match2Edi,match1Shp,"x 0.75 * y 0.1875 * z 0.0625 * a + + + range_half -", UV=3)            : \
					                     ex_lutxyz (match2Degrain1,match2Degrain2,match2Edi,          "x 0.75 * y 0.1875 * z 0.0625 * + +"      , UV=3)

    # Source-match second refinement - correct error introduced in the refined difference by temporal smoothing. Similar to error correction from basic step
    errorAdjust2   = Select( MatchTR2, 1.0, 2.0 / (1.0 + errorTemporalSimilarity), 8.0 / (3.0 + 5.0 * errorTemporalSimilarity) )
    match3Update   = (SourceMatch < 3 || MatchTR2 == 0) \
                         ? match2Edi : ex_lutxy( match2Edi, match2, Format("x dup y - {errorAdjust2} * +"), clamp_float=true, UV=3, fulls=fs )
    match3Super    = (SourceMatch > 2 && MatchTR2 > 0) ? match3Update.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, rfilter=3,   mt=bomt )                 : nop()
    match3Degrain1 = (SourceMatch > 2 && MatchTR2 > 0) ? Eval("match3Update.MDegrain1( match3Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()
    match3Degrain2 = (SourceMatch > 2 && MatchTR2 > 1) ? Eval("match3Update.MDegrain1( match3Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2,mt=bomt" + sMDegnl + ")") : nop()
    match3Degrain1 = (SourceMatch > 2 && MatchTR2 > 0) ? n16 ? match3Degrain1.ConvertBits(8,dither=-1,fulls=fs) : match3Degrain1 : match3Degrain1
    match3Degrain2 = (SourceMatch > 2 && MatchTR2 > 1) ? n16 ? match3Degrain2.ConvertBits(8,dither=-1,fulls=fs) : match3Degrain2 : match3Degrain2
    match3         = (SourceMatch < 3) ? match2                                                                 : \
                     (MatchTR2 == 0)   ? match1Shp.ex_adddiff( match3Update, UV=3, fulls=fs )                   : \
                     (MatchTR2 == 1)   ? match3Degrain1.ex_lutxyz( match3Update,match1Shp,"x dup y - 0.25 * - z + range_half -", UV=3) : \
                                                        ex_lutxyza(match3Degrain1,match3Degrain2,match3Update,match1Shp,"x 0.75 * y 0.1875 * z 0.0625 * a + + + range_half -", UV=3)

    # Apply difference calculated in source-match refinement
    return match3
}


# Set global variable called "Prefix_Name" to "Value". Throws exception if global already exists unless Replace=true, in which case the global is overwritten
function QTGMCp_SetUserGlobal( string Prefix, string Name, val Value, bool "Replace" )
{
    Replace = Default( Replace, false )
    globalName = Prefix + "_" + Name

    if (Replace || !VarExist( globalName ) )
    {
        Eval( "global " + globalName + " = Value" )

    } else { Assert( false, """QTGMC+: Multiple calls to QTGMC+, set PrevGlobals="Replace" or read documentation on 'Multiple QTGMC+ Calls'""" ) }
}

# Return value of global variable called "Prefix_Name". Returns nop() if it doesn't exist or Reuse is false
function QTGMCp_GetUserGlobal( string Prefix, string Name, bool "Reuse" )
{
    Reuse      = Default( Reuse, false )
    globalName = Prefix + "_" + Name

    Reuse && VarExist(globalName) ? Eval( globalName ) : nop()
}

# from Zs_RF_Shared v1.159, required for EdiMode=="BWDIF+EEDI3"
# "based on Dither_limit_dif16 idea (not 100% same output)"
function QTGMCp_slimit_dif2(clip "flt", clip "src", clip "ref", float "thr", float "elast", int "UV", bool "elastinfl") {

    thr     = Default(thr,  0.25)
    elast   = Default(elast, 3.0)
    elast2  = elast > 1.0 ? elast * thr : elast
    UV      = Default(UV,      3)
    elastin = Default(elastinfl, false)
    UVe     = UV==3 ? Undefined() : ""

    dref = Defined(ref)

    Assert(elast > 1,                      "QTGMCp_slimit_dif2: elast must be more than 1")
    Assert((Defined(flt) && Defined(src)), "QTGMCp_slimit_dif2: both flt clip and src clip are needed")

    ldmask = elast!=1 ? Expr(dref ? ref : src, flt, Format("x y - abs D@ {thr} yscalef <= yrange_max D {elast2} yscalef <= ? yrange_max yrange_max {elast2} yscalef / D * - 0 ?"), UVe) :
             \   dref ? ref.Expr(flt,Format("x y - abs {thr} yscalef <= yrange_max 0 ?"), UVe, clamp_float_UV=true) : nop()

    elast!=1  || dref ? mt_merge(src,flt, elastin ? ldmask.mt_inflate(155,U=UV,V=UV) : ldmask, U=UV,V=UV)           : \
                        src.Expr(flt,Format("x y - abs {thr} yscalef <= y x ?"), UVe, clamp_float_UV=false)
    }




# (LEGACY for 8-16-bit since vinverse v0.9.2)
# Vinverse: a small, but effective function against (residual) combing, by Didée (24-10-2006)
# https://forum.doom9.org/showthread.php?p=891788
#
# Optimization and port to EX mod from real.finder's HBD mod. by Dogway (15-09-2021)

# Vinverse_avsi() is 70% slower with Prefetch(physical cores) and 60% slower with Prefetch(logical cores)
function ex_vinverse (clip clp, float "sstr", int "amnt", int "UV", clip "clip2", bool "fulls") {

    rgb  = isRGB(clp)
    bi   = BitsPerComponent(clp)

    sstr = Default(sstr, 2.7)       # strength of contra sharpening
    amnt = Default(amnt, 255)       # change no pixel by more than this (8-bit scale) (Default=255: unrestricted)
    dcus = Defined(clip2)           # clip for the contrasharpening
    UV   = Default(UV,    rgb ? 3 : 1)
    fs   = Default(fulls, rgb)

    mxm    = ex_bs(255,  8, bi, fulls=fs)-1
    amntb  = ex_bs(amnt, 8, bi, fulls=fs)

    bi32m  = bi == 32 ? "" : "range_half -"
    bi32p  = bi == 32 ? "" : "range_half +"

    vblur  =  clp.ex_lut("x[0,-1] x[0,1] x 1.98 * + + 0.251256281 *", UV=uv) # Custom weighted blur, like ex_boxblur(0,1,"weighted") but not quite
    vblurD =  dcus ? ex_makediff(clp, vblur, UV=uv, fulls=fs) : nop()

    VshrpD = !dcus ? ex_lutxy(vblur, vblur.ex_boxblur(0, 2, "weighted", UV=uv), Format("x y - {sstr} * "+bi32p), UV=uv, fulls=fs) : nop()

    # Take the less sharp variant and if they're same sharpness reduce its strength 1/4
    sl     = (amnt > mxm) ? "" : Format(" x {amntb} - x {amntb} + clip")
    VlimD  =  dcus ? ex_lutxyz(clp, VblurD, clip2,  "x z -          A@ y "+bi32m+" B@ * 0 < A abs B abs < A B ? dup 0.25 * swap ? z +" + sl, UV=uv, fulls=fs) : \
                     ex_lutxyz(clp, VshrpD, Vblur,  "y "+bi32m+" A@ x z -          B@ * 0 < A abs B abs < A B ? dup 0.25 * swap ? z +" + sl, UV=uv, fulls=fs)

             (amnt ==  0) ?    clp : VlimD.propSet("_Combed",0) }


# ex_bob() - port of sh_bob() by real.finder (original QTGMC_Bob() by Vit)
# Same as Bob, but keeps the field order the same.
# Modded for frame properties and NNEDI3CL support.
#
# Core plugins:
#   ResizersPack  (for nnedi3=true)
#   NNEDI3CL      (for nnedi3=true and gpuid=0) (requires at least AVS+ v3.7.3)
#   nnedi3        (for nnedi3=true and gpuid=-1)
#
# Function Definition:
#     (
#     clip clp,
#     float "b"=0.0 (-1.0 to 1.0),
#     float "c"=0.0 (0.0 to 1.0),
#     [int "height"=1080 (360 to 2160)],
#     bool "nnedi3"=false
#     )
#
function ex_bob(clip cp, float "b", float "c", int "height", bool "nnedi3", int "qual", int "props", int "threads", int "cores", int "gpuid") {

    fs    = propNumElements(cp, "_ColorRange")  > 0 ? \
            propGetInt     (cp, "_ColorRange")      : 1
    fb    = propNumElements(cp, "_FieldBased")  > 0 ? \
            propGetInt     (cp, "_FieldBased")      : 0
    cp    = propNumElements(cp, "_DurationNum") > 0 ? cp : \
            propSet        (cp, "_DurationNum", FrameRateDenominator(cp))
    cp    = propNumElements(cp, "_DurationDen") > 0 ? cp : \
            propSet        (cp, "_DurationDen", FrameRateNumerator  (cp))
    fb    = fb==0 ? GetParity(cp) ? 2 : 1 : fb

    yv12  = cp.is420()
    w     = cp.Width()
    h     = cp.Height()
    h     = Default(height, h)
    b     = Default(b,    0.0)            # cubic coefficient 'b'
    c     = Default(c,    1.0)            # cubic coefficient 'c'. Bob(0.0, 1.0) preserves the original fields for RGB and YUY2, and preserves the Luma but not the Chroma for YV12.
    pp    = Default(props,      2)        # 0: Skip writting frameprops. 1: Write only clip frameprops. 2: Write clip and frame -runtime- frameprops.
    nn    = Default(nnedi3, false)        # Use nnedi3 instead of cubic interpolation
    ql    = Default(qual,       2)        # 'qual' arg for nnedi3
    gp    = Default(gpuid,      0)        # Only for nnedi3=true
    th    = Default(threads,    8)        # Only for nnedi3=true and gpuid=-1 ("cpu" nnedi3)
    co    = Default(cores,nmod(th/2,2,4)) # Only for nnedi3=true and gpuid=-1 ("cpu" nnedi3)

    par   = fb==2

    if (yv12) {

        shift = par ? 0.25 : -0.25

        cp.SeparateFields()
        w2    = w/2
        fh    = Height()
        eY    = ExtractY()
        eU    = ExtractU()
        eV    = ExtractV()
        Yeven = eY.SelectEven()  Ueven = eU.SelectEven()  Veven = eV.SelectEven()
        Yodd  = eY.SelectOdd()   Uodd  = eU.SelectOdd()   Vodd  = eV.SelectOdd()

        yeven = !nn ? Yeven.BicubicResize(w, h, b, c, 0,  shift, w, fh) : \
                      Yeven.nnedi3wrap(1,2, par ? 1 : 0,nsize=3,nns=3,qual=ql,cshift="none",threads=th,cores=co,gpuid=gp)
        yodd  = !nn ?  Yodd.BicubicResize(w, h, b, c, 0, -shift, w, fh) : \
                       Yodd.nnedi3wrap(1,2, par ? 0 : 1,nsize=3,nns=3,qual=ql,cshift="none",threads=th,cores=co,gpuid=gp)

        ceven = Interleave( Ueven, Veven).BicubicResize(w2, h/2, b, c, 0,  shift, w2, fh/2)
        codd  = Interleave(  Uodd, Vodd ).BicubicResize(w2, h/2, b, c, 0, -shift, w2, fh/2)

        YToUV(Interleave(ceven.SelectEven(), codd.SelectEven()),\
              Interleave(ceven.SelectOdd (), codd.SelectOdd ()),\
              Interleave(yeven,              yodd            )).AssumeFrameBased()

    } else {

        !nn ? Bob(cp, b, c, h ) : \
              nnedi3wrap(cp, field=fb+1,nsize=3,nns=3,qual=ql,props=true,threads=th,cores=co,gpuid=gp)
    }

    par ? AssumeTFF() : AssumeBFF()

    if (pp>0 && (yv12 || (!yv12 && !nn))) {
    propCopy(cp,true,props=["_DurationNum","_FieldBased","_PictType","_AbsoluteTime"],exclude=true)

    pp>1 ? ScriptClip(function[cp]() {
    propSet("_DurationDen",propGetInt(cp,"_DurationDen")*2)
    propSet("_DurationNum",propGetInt(cp,"_DurationNum")  )
    } ) : last

    propSet("_FieldBased",0).propSet("_Field",fb-1).propSet("_Combed",0) } }



# ReduceFlicker by Kassandro (15-09-2005)
# https://web.archive.org/web/20160702125433/http://videoprocessing.fr.yuku.com/topic/24/ReduceFlicker-05
#
# Port of ReduceFlicker plugin to internal Expr() wrappers by Dogway (18-02-2022)
#
# "ReduceFlicker performs controlled averaging of a frame with its two adjacent temporal neighbors.
# Controlled means that averaging only takes place in the presence of oscillations. Without such a restraint the filter would create massive ghosts.
#
# ReduceFlicker is purely a temporal filter that can be used for all kinds of material, but it is particularly useful for interlaced footage or
# progressive videos from digicams like my 'Canon Powershot S1 IS'. It should be applied before deinterlacing.
# If done so, the motion detection of the deinterlacer is fooled less by flicker, whence more detail is preserved.
#
# The type of flicker, which can be removed or at least reduced with ReduceFlicker, is more prevalent in camcorder material and the chroma of analog clips,
# especially clips captured from VHS tapes. In other words ReduceFlicker is suited for removing or reducing certain kinds of electronic noise,
# but it has virtually no effect on dust and film grain."
#
# Benchmarks:
#     100% ex_ReduceFlicker(strength=1) (357fps)
#      94% ReduceFlicker   (strength=1) (335fps, AVS+ port by Asd-g)
#
function ex_ReduceFlicker(clip a, int "strength", bool "aggressive", int "UV") {

    str = max(1,Default(strength, 2)) # 1, 2, or 3
    agg = Default(aggressive, false)  # Avoid with strength=3
    UV  = Default(UV,             3)
    UV2 = !isy(a) && UV==3 ? Undefined() : ""

    b3  = str > 2  ? a.selectevery(1,-3) : nop()
    b2  =            a.selectevery(1,-2)
    b   =            a.selectevery(1,-1)
    f   =            a.selectevery(1,+1)
    f2  = str == 2 ? a.selectevery(1,+2) : nop()
    f3  = str >  2 ? a.selectevery(1,+3) : nop()

    !agg     ?                                                                                                                                                                                                 \
    str == 1 ? ex_lutxyza(a,   b2,b,f,   "z a dup1 dup1 max swap2 min x y - abs D@                             - x max swap D + x min z a x 2 * + + 0.25 * swap2 clip",                               UV=uv) : \
    str == 2 ? Expr      (a,   b2,b,f,f2,"z a dup1 dup1 max swap2 min x y - abs x b - abs min D@               - x max swap D + x min z a x 2 * + + 0.25 * swap2 clip",                               UV2)   : \
               Expr      (a,b3,b2,b,f,f3,"a b dup1 dup1 max swap2 min x z - abs x y - abs min x c - abs min D@ - x max swap D + x min a b x 2 * + + 0.25 * swap2 clip",                               UV2)   : \
    str == 1 ? ex_lutxyza(a,   b2,b,f,   "z a dup1 dup1 max swap2 min y x -                     0 max          - x max swap x y -                     0 max + x min z a x 2 * + + 0.25 * swap2 clip", UV=uv) : \
    str == 2 ? Expr      (a,   b2,b,f,f2,"z a dup1 dup1 max swap2 min y x - b x - min           0 max          - x max swap x y - x b - min           0 max + x min z a x 2 * + + 0.25 * swap2 clip", UV2)   : \
               Expr      (a,b3,b2,b,f,f3,"a b dup1 dup1 max swap2 min z x - y x - min c x - min 0 max          - x max swap x z - x y - min x c - min 0 max + x min a b x 2 * + + 0.25 * swap2 clip", UV2)   }



# --- CHANGELOG ---
#
# v4.6p (03-01-2025)
# - Fixed ChromaNoise due to vsTCanny outputting garbage chroma -mode 1-
# - ChromaNoise now activates NoiseProcess
#
# v4.5p (25-07-2023)
# - ex_vinverse() - small fix for HBD
# - Fix 'moiree' option (10-09-2023 update)
# - Cosmetics
#
# v4.4p (07-07-2023)
# - Add 'Yadif+NNEDI3' mode
# - Cosmetics
#
# v4.3p (28-05-2023)
# - Add 'moiree' argument
# - Revert new default EdiModes and treat them as 'moiree' special modes
# - Tweak default base BWDIF bob
#
# v4.2p (22-03-2023)
# - Pass 'EdiQual' to "BOB+NNEDI3" EdiMode
# - Logic beautify and cosmetics
#
# v4.1p (14-03-2023) (breaks output parity with original QTGMC)
# - Add more EdiModes
# - Change default base bob to BWDIF for better quality (and avoid moiree)
# - Change all EdiMode presets to more detail preserving alternatives
# - Fix typo on sourcematch modes, missing "range_half -"
# - Fix ChromaMotion internal from garbage to copy
#
# v4.0p (02-03-2023)
# - Fix SrchClipPP=3
# - Fix SourceMatch=2
# - Optimize SourceMatch=3
# - Optimize when GrainRestore > 0 and Sbb > 1
# - Improve Temporal weightings for MDegrain2 match
# - Disable internal runtime frameprop assignments (AVS+ memory leak bug)
# - Add BM3D as optional Denoiser type
# - Remove SysInfo dependency as it's broken for Win11, newer CPUs and unmaintained
# - Uploaded v3.33 documentation (should work for 95% of v4.0.0 settings)
#
# BENCHMARKS v4.0 (8-bit @ 1080p with a i7-4790K@Stock, so probably your numbers will be higher):
#   Medium 15 fps  SourceMatch=1, MatchPreset="medium" 13.5fps
#   Slow   14 fps  SourceMatch=1, MatchPreset="medium" 12.2fps
#   Slower 9.4fps  SourceMatch=1, MatchPreset="slow"    7.5fps
#
# v3.99p
# - Add empty vars 'bVec2' and 'fVec2' as exception handlers
#
# v3.98p
# - Direct YUY2 support via global internal conversion
# - Port slimit_dif2() from Zs_RF_Shared and remove its dependency
#
# v3.97p
# - Change a few defaults on the slower presets for increased quality
# - Set rfilter=3 for all MSuper instances for extra accuracy
# - Enable for HD sources scaled chroma for MV sampling
# - Disable ex_bob() frameprops assignment when using nnedi3 which already does it
#
# v3.96p
# - Add support for EEDI2CUDA
#
# v3.95p
# - Fix typo on KNLMeansCL call for 'gpuid'
# - Update dependencies versions
# - Update show panel
# - Make '_Durationxxx' dynamic, also in ex_bob()
#
# v3.94p
# - Populate with "_Field" frameprop where appropiate
# - Fix "_AbsoluteTime" frameprop
#
# v3.93p
# - Fix for missing "_Durationxxx" frameprops
#
# v3.92p
# - Typo on neo_fft3d() chroma index
#
# v3.91p
# - Remove 'device_type'
# - Replace 'device_id' with 'gpuid' and update ex_KNLMeansCL() call
# - Revert back to neo_FFT3D() after benchmarks
#
# v3.90p
# - Refine '_Combed' property
# - Add EEDI3wrap for EEDI3CL compatibility
# - Update for latest nnedi3wrap()
#
# v3.89p
# - Removed old "cYadif" and "RepcYadif" Edimodes
# - Fixed InputType=1 for progressive inputs
# - Now all deinterlacers inherit field order from frame properties preferably
# - Better frame properties workflow in the pipeline
#
# v3.88p
# - Fix HBD for 'ShutterBlur'
#
# v3.87p
# - Update ex_bob() for latest NNEDI3CL version
#
# v3.86p
# - Replace NNEDI3CL with nnedi3wrap
#
# v3.85p
# - Replace nnedi3 with NNEDI3CL
#
# v3.84p
# - Update with latest ex_luma_rebuild() version
# - Update function definition
#
# v3.83p
# - Update with latest Asd-g's vinverse plugin, deprecates ex_vinverse() -now semi-legacy- (v3.82 & v3.83)
#
# v3.81p
# - Update calls for latest vsTCanny
# - Fix HBD for 'InputType' 2 and 3
#
# v3.80p
# - Add dumb nnedi3 interpolation to ex_bob()
# - Update propCopy calls to v3.7.2 test8
# - Rename ex_vinverse() 'custem' arg to 'clip2'
# - Rename filter to QTGMC+ and function to QTGMCp()
#
# v3.79p
# - Fix a memory leak with propCopy() (v3.78)
# - Add ex_bob(), a port of sh_bob() for frameprops support (v3.78)
# - Add propNumElements to ex_blob() to check first if frameprops exist
#
# v3.77p
# - Add ex_ReduceFlicker()
# - Fix addnoiseN clamp
#
# v3.76p
# - Frameprops passthrough
# - Add function definitions
# - Tweak 'Str' and 'Amp' defaults
#
# v3.75p
# - Fix ex_vinverse() vertical blur
# - Optimize ex_vinverse() VshrpD expression
# - Add float output for 'noiseCentre' variable
#
# v3.74p
# - Optimize expressions with lerp
# - Optimize convolutions fetching first pixels first
# - Add 'range' arg to nnedi3 calls
#
# v3.73p
# - Increase EdiQual Defaults for Placebo
# - Rename 'Showsettings' to 'Show' and parametrize font size
# - Update call for latest vsTCanny
#
# v3.72p
# - More expression optimizations (v3.71p & v3.72p)
# - Some 'fs' fixes (v3.70p)
#
# v3.69p
# - Optimize code structure with loops
# - Override 'fs' with 'tv' if defined
# - Cosmetics
#
# v3.68p
# - Read bitdepth scale from frameprops, and remove 'fulls' arg
# - Process NNEDI3 (and other deinterlacers) in 8-bit for HBD inputs (NNEDI3 is not optimized enough for HBD)
#
# v3.67p
# - Tweak again NNEDI3 thread settings
# - Adjust chroma blur radius for chroma subsampling
#
# v3.66p
# - Replace sh_GetUserGlobalIMT with SysInfo's SI_LogicalCores()
# - Update nnedi3 calls for more performance on given threads
# - Readjusted gaussian blur sigmas
# - Preliminar 32-bit float support (MDegrain is broken for 32-bit)
#
# v3.65p
# - Update QTGMC_Set/GetUserGlobal() functions
# - Replace ex_gaussianblur() with vsTCanny(), faster
# - Update dependencies list
# - Revert Bankers' rounding workaround
#
# v3.64p
# - Optimize thin var expression
# - Attach optimized ex_vinverse()
#
# v3.63p
# - re-add bomt var
# - add Refinemotion to presets
#
# v3.62p
# - Revised chroma processing for vinverses and blurs
# - Filled missing 'fulls'
# - Cut redundant args (thanks real.finder)
# - Tweaked some defaults based on zorr's zopti findings (more on this coming)
#
# v3.61p
# - EdiExtPre removed, UseEdiExt become int parameter, 0=false, 1=true, 2=same as old UseEdiExt+EdiExtPre
#
# v3.60p
# - Update to latest ExTools
# - Added 'fulls' to ConvertBits()
# - Replaced blurs with ex_GaussianBlur()
# - Some Expr optimizations
# - Add back deleted Precise arg
# - Add back UV=3 to tmax and tmin
# - Removed bomt var
# - Remove keep_tv_range limiter
# - 32-bit support is Work In Progress
#
# v3.51p
# - Replaced vinverse() with ex_vinverse() for custem (now clip2) arg
# - Removed Dither tools related arguments
#
# v3.50p (27-07-2021)
# - Replaced MaskTools2 with Expr calls via ExTools pack wrappers (except mt_merge)
# - Merged redundant expressions
# - Replaced blurs and medians with ExTools equivalents
# - Replaced Vinverse_avsi() with ex_vinverse() (HBD) and vinverse() (8bit)
# - Removed Dither support
# - Reverted from neo_ to vanilla fft3d and dfttest (sameish or faster)
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
# - added EdiExtPre to use Vinverse_avsi with UseEdiExt
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
# - added UseEdiExt
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
# v3.34s (mod) (18-12-2016) (ravewulf idea in another way)
# - Added yadifmod2 (if you need old one use it like this EdiMode="cYadif" or EdiMode="RepcYadif")
# - fast and clean up YUY2 (will work in x64 now, no need to SSETools)
#
# v3.33s (mod) (06-12-2016)
# - Add TR2=4 and TR2=5
# - add TV_range bool and dither_luma_rebuild (from SMDegrain) Str and Amp
# - for avsplus now QTGMC_Bob is ready for any 420, not only yv12
#
# v3.33s (mod) (11-04-2016)
# - Add KNLMeansCL as another Denoiser to NoiseProcess
# - others
#
# v3.33s (mod) (19-01-2016)
# - make QTGMC_deflate/QTGMC_inflate work with YUY2 using masktool2 for avs 2.60
#
# v3.33s (mod) (23-10-2015)
# - revert to QTGMC_deflate/QTGMC_inflate quoted from Dogway
#
# v3.33s (mod) (10-09-2015)
# - fix Multiple QTGMC Calls
# - others fix
#
# v3.33s (mod) (06-08-2015)
# - some changes in bob to speed up
#
# v3.33s (mod) (04-08-2015)
# - fix bug in YUY2 with SourceMatch
# - add slice=false to ditherpost to avoid artefacts
#
# v3.33s (mod)
# - fix bob chroma
# - work with new masktool2 for avs 2.60 in YUY2
#
# v3.35d (mod)
# - Added fixed QTGMC_Bob() for proper YV12 chroma center (by real.finder based on a Gavino find)
#
# v3.34d (mod)
# - Added Refinemotion Option for more accurate denoising.
#
# v3.33d (mod) (10-05-2012)
# - Added 32 bit precision option through the lsbd (for dfttest and knlmeanscl) and lsb (mdegrain) options.
# - optimized some mask handling a bit as originally suggested by Vit
# - others
#
# v3.33 (10-05-2012)
# - Increased maximum value for Rep0, Rep1 and Rep2 to 7 (from 5). Higher values help with flicker on static detail, potential for minor motion blur
# - Bug fix for the fact that Bob always outputs a BFF clip regardless of field order of input (thanks ajp_anton)
# - Improved generation of noise (NoiseDeint="Generate") for noise bypass / EZKeepGrain
# - Minor change to denoising
#
# v3.32 (05-05-2011)
# - Bugfix with shutter blur and ChromaMotion (thanks Heaud)
# - Tweaked vector recalculation for shutter motion blur
# - Changed defaults for TR2 when using source-match
# - Minor bugfix with SLMode/SLRad on pass-through settings
#
# v3.31
# - Small bug-fix with new ChromaMotion setting
#
# v3.30
# - Added ChromaMotion setting - can ignore chroma when analyzing motion (a speed-up with few ill-effects)
# - Added ChromaEdi setting - allow faster interpolation for chroma than luma (mainly useful for EEDI2/3)
# - New fast pre-filter (SrchClipPP) mode 1, previous modes 1 & 2 are now modes 2 & 3. Presets all updated with new modes
# - EdiMode "TDIYadif" changed to "RepYadif" = Yadif+Repair giving less artefacts & more speed. Is default mode for "Ultra Fast"
# - Preset is now the first setting, allowing a simpler form: QTGMC("Slow"). Old TGMC style will no longer work
# - Workaround for padding bug in MVTools that crashed faster modes. Removes need for SafeMode setting, which has been removed
#
# v3.25 (14-03-2011)
# - Added YUY2 support
# - NoiseBypass renamed to NoiseProcess
# - PrevGlobals now defaults to "Replace" for simplicity
# - Tweaked "Very Fast" preset for quality and consistency with other preset speeds
#
# v3.20 (07-03-2011)
# - Motion vectors made available to calling script (see External Linkage section in documentation), added related GlobalNames, PrevGlobals & ForceTR settings
# - Added simplified noise processing settings: EZDenoise, EZKeepGrain and NoisePreset
# - Support for dfttest as denoiser for noise processing - added settings Denoiser and DftThreads
# - Added ChromaNoise setting to optionally enable chroma noise processing
# - Added DenoiseMC setting to use motion-compensated clip for denoising, improves detection of noise vs detail
# - Replaced fft3dfilter-specific BT setting with NoiseTR setting to set temporal radius for denoiser.
# - Added StabilizeNoise setting to "stabilize" & "deshimmer" noise restored in noise bypass (was part of "Generate" mode)
# - Dropped NoiseRemove setting, now always removes all noise specified by given Sigma (enough controls already!)
# - MotionBlur renamed to ShutterBlur, MBlurLimit renamed to SBlurLimit, DetailRestore renamed to GrainRestore (old names gave wrong impression)
# - Bug fixes: stabilization of "Generate" noise mode, manually enabling SLMode with SourceMatch
# - Documentation converted to HTML
#
# v3.11
# - Exposed ThSAD1, ThSAD2, ThSCD1 and ThSCD2 to allow tweaks to temporal smoothing and scene change detection
# - Fixed bug introduced in v3.05, which skipped part of core algorithm(!)
#
# v3.10
# - Explicit conditions to ensure unused filters are not constructed to reduce memory use
# - FPSDivisor works even if not using motion blur
#
# v3.05
# - Motion blur support, added settings FPSDivisor, MotionBlur, ShutterAngleSrc, ShutterAngleOut, SBlurLimit
# - Bug fixes: Some Sbb modes with source match, MatchEdi setting (again)
#
# v3.01
# - Support for lossless modes on InputType=2,3 - improves detail retention
# - Enabling ShowNoise automatically switches on NoiseBypass
# - Bug fixes: "Draft" mode, noise extraction with InputType=1, MatchEdi setting
#
# v3.0 (23-01-2011)
# - Introduced source-match modes and settings for higher fidelity output - supported for interlaced and progressive input
# - Most lossless settings removed - superseded by source-match, only Lossless integer remains
# - Added ProgSADMask setting for progressive repair modes (InputType=2,3) to help recover stable detail
# - Added RepChroma setting to allow disabling of chroma processing in repair stages (rep0,1,2)
# - Added DetailRestore setting for NoiseBypass - allowing denoising with some fine detail retention
# - Noise bypass with NoiseDeint="Generate" is now motion-compensated for better grain/detail restoral, NoiseDeint="Copy" removed
# - Corrected minor luma shift when using NoiseBypass (FFT3DFilter noise center is 128.5 not 128)
# - Added ShowNoise setting to display extracted noise, helps in determining Sigma
# - TDeint added as interpolator (suitable for source-match)
# - YadifPath no longer global
# - EdiMode for "Ultra Fast" changed from "TDIYadif" to "Yadif" (otherwise slower than "Super Fast" for non-threaded)
# - Bug fixes in Sbb and InputType=3
# - Complete rewrite of documentation and some script tidying
#
# v2.51 (26-10-2010)
# - Changed default interpolator to "NNEDI3" for presets up to "Super Fast" and (new) lossless presets up to "Faster"
# - Range of preset tweaks including higher quality output from "Super Fast" & "Ultra Fast" but with a little speed loss
# - Support for EdiMode="EEDI3+NNEDI3": EEDI3 with sclip taken from NNEDI3
# - Added LosslessPreset and EdiThreads parameters
# - Tidied up output from ShowSettings and small bug fix
# - Fixed serious bug when using lossless modes on the higher speed presets
#
# v2.47
# - Fixed bug with default overlap when an explicit blocksize was given
#
# v2.46
# - Replaced mt_average with merge - was causing exceptions in certain MT situations
#
# v2.45
# - Tweaked use of Yadif: explicit loading is now optional, see YadifPath variable
#
# v2.41
# - Removed explicit Yadif plugin load
#
# v2.40
# - Support for lossless output with added parameters: Lossless, LosslessTR, LosslessEdi
# - Support for EdiMode("NNEDI3", "EEDI3")
# - Paramters NNeurons added & NNSize reworked for new -EDI3 versions
# - Minor preset tweaks for better quality/speed spread
#
# v2.30
# - Added EdiExt (edeint in original TGMC)
# - Improved progressive input modes
#
# v2.20
# - All rep values, SVThin and motion search settings supported
# - Better matching of Sbb
# - "Draft" preset. Default preset changed from "Slow" to "Slower"
# - Support for progressive input (InputType)
# - Sharpness values/defaults normalized
#
# v2.10
# - Supported most of the remaining core TGMC features: EdiMode("NNEDI", "Yadif"), TR2(3), SLmode(3,4), SLRad, Sbb(2,3)
# - Added noise bypass (removal / restoration)
# - Added ShowSettings
#
# v2.00
# - First fully featured version
# - Supported majority of core TGMC features
# - Additional speed tweaks: NNSize, SrchClipPP, SubPel, Precise
# - Added Presets system and beginnings of Tunings
#
# v1.00 (05-08-2010)
# - First draft - high speed basic TGMC algorithm only (based on TempGaussMC_beta2 (27-02-2010 https://forum.doom9.org/showthread.php?p=1378526) by Didée and Terranigma's MVTools2 update)
#
# v0.00 (16-05-2008)
# - Original TempGaussMC by Didée (https://forum.doom9.org/showthread.php?p=1138514)
#