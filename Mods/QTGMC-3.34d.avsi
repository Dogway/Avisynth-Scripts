#-------------------------------------------------------------------#
#                                                                   #
#                    QTGMC 3.35, by Vit, 2015                       #
#                                                                   #
#   A high quality deinterlacer using motion-compensated temporal   #
#  smoothing, with a range of features for quality and convenience  #
#          Originally based on TempGaussMC_beta2 by Didée           #
#                                                                   #
#-------------------------------------------------------------------#
#
# Full documentation is in the 'QTGMC' html file that comes with this script
#
# --- LATEST CHANGES ---
#
# v3.35d (mod)
# - Added fixed QTGMC_Bob() for proper YV12 chroma center (by real.finder based on a Gavino find)
#
#
# v3.34d (mod)
# - Added Refinemotion Option for more accurate denoising.
#
#
# v3.33d (mod)
# - Added 32 bit precision option through the lsbd (for dfttest) and lsb (mdegrain) options.
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
# Input colorspaces: YV12, YUY2
#
# Core plugins:
#	MVTools2 (2.5.11.3 or above)
#	MaskTools v2 (recommend 2.0a48 or above. Must use the 2.5 version with YUY2)
#	NNEDI3 (recommend 0.9.4 or above for speed)
#	RemoveGrain + Repair (several versions of this plugin, use the SSE2 dlls from the file called "RemoveGrain-1.0.rar". Don't use the SSE3 versions )
#   SSE2Tools for YUY2 support (from the earlier 0.9 version of RemoveGrain, use only SSE2Tools.dll from this version. Don't use the SSE3 version)
#
# Additional plugins:
#	NNEDI2, NNEDI, EEDI3, EEDI2, TDeInt - if selected directly or via a source-match preset
#	Yadif - for Preset="Ultra Fast" or if selected directly (cannot be autoloaded, must be loaded in the calling script)
#	VerticalCleaner - for SVThin or Lossless modes
#	FFT3DFilter - if selected for noise processing
#	dfttest - if selected for noise processing
#		For FFT3DFilter & ddftest you also need the FFTW3 library (FFTW.org). On Windows the file needed for both is libfftw3f-3.dll. However, for FFT3DFilter
#		the file needs to be called FFTW3.dll, so you will need two copies and rename one. On Windows put the files in your System32 or SysWow64 folder
#	AddGrainC - if NoiseDeint="Generate" selected for noise bypass


# --- GETTING STARTED ---
#
# Install AviSynth and ensure you have at least the core plugins listed in the requirements section above. Put them in the plugins autoload folder.
# To use QTGMC write a script like this:
#	YourSource("yourfile")   # DGDecode_mpeg2source, FFVideoSource, AviSource, whatever your source requires
#	QTGMC( Preset="Slow" )
#	SelectEven()             # Add this line to keep original frame rate, leave it out for smoother doubled frame rate
#
# Save this script with an ".avs" extension. You can now use it as an AVI source for encoding.
#
# The "Preset" used selects sensible settings for a given encoding speed. Choose a preset from:
#	"Placebo", "Very Slow", "Slower", "Slow", "Medium", "Fast", "Faster", "Very Fast", "Super Fast", "Ultra Fast" & "Draft"
# The default preset is "Slower"
# Don't be obsessed with using slower settings as the differences can be small. HD material benefits little from extreme settings (and will be very slow)
# For much faster speeds read the full documentation, the section on 'Multi-threading'
#
# There are many settings for tweaking the script, full details in the main documentation. You can display settings currently being used with "ShowSettings":
#	QTGMC( Preset="Slow", ShowSettings=true )


function QTGMC( clip Input, string "Preset", int "TR0", int "TR1", int "TR2", int "Rep0", int "Rep1", int "Rep2", string "EdiMode", bool "RepChroma", \
                    int "NNSize", int "NNeurons", int "EdiQual", int "EdiMaxD", string "ChromaEdi", int "EdiThreads", clip "EdiExt", float "Sharpness", \
                    int "SMode", int "SLMode", int "SLRad", int "SOvs", float "SVThin", int "Sbb", int "SrchClipPP", int "SubPel", int "SubPelInterp", \
                    int "BlockSize", int "Overlap", int "Search", int "SearchParam", int "PelSearch", bool "ChromaMotion", bool "TrueMotion", int "Lambda", \
                    int "LSAD", int "PNew", int "PLevel", bool "GlobalMotion", int "DCT", int "ThSAD1", int "ThSAD2", int "ThSCD1", int "ThSCD2", \
                    int "SourceMatch", string "MatchPreset", string "MatchEdi", string "MatchPreset2", string "MatchEdi2", int "MatchTR2", \
                    float "MatchEnhance", int "Lossless", int "NoiseProcess", float "EZDenoise", float "EZKeepGrain", string "NoisePreset", string "Denoiser", \
                    int "DftThreads", bool "DenoiseMC", int "NoiseTR", float "Sigma", bool "ChromaNoise", val "ShowNoise", float "GrainRestore", \
                    float "NoiseRestore", string "NoiseDeint", bool "StabilizeNoise", int "InputType", float "ProgSADMask", int "FPSDivisor", \
                    int "ShutterBlur", float "ShutterAngleSrc", float "ShutterAngleOut", int "SBlurLimit", bool "Border", bool "Precise", string "Tuning", \
                    bool "ShowSettings", string "GlobalNames", string "PrevGlobals", int "ForceTR", \
                    val "BT", val "DetailRestore", val "MotionBlur", val "MBlurLimit", val "NoiseBypass", bool "lsbd", bool "lsb", bool "Refinemotion" )
{
	# The preset "Ultra Fast" & EdiMode="RepYadif"/"Yadif" require the Yadif plugin, which doesn't autoload. Typically the calling script would load it.
	# To have this script load Yadif put it's full path in string below (e.g. "C:\Plugins\Yadif.dll"). Use empty string ("") if calling script will load Yadif
	YadifPath = "" # Or just enter "yadif.dll" if Yadif is placed in the system path (e.g. windows\system32)

	# Temporary Warnings
	Assert( !defined(BT),            "QTGMC: Setting BT has been replaced by setting NoiseTR" )
	Assert( !defined(DetailRestore), "QTGMC: Setting DetailRestore has been renamed to GrainRestore" )
	Assert( !defined(MotionBlur),    "QTGMC: Setting MotionBlur has been renamed to ShutterBlur" )
	Assert( !defined(MBlurLimit),    "QTGMC: Setting MBlurLimit has been renamed to SBlurLimit" )
	Assert( !defined(NoiseBypass),   "QTGMC: Setting NoiseBypass has been renamed to NoiseProcess" )

	#---------------------------------------
	# Presets

	# Select presets / tuning
	Preset = default( Preset, "Slower" )
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

	mpNum1 = (!defined(MatchPreset))       ? ((pNum + 3 <= 9) ? (pNum + 3) : 9) : \
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

	mpNum2 = (!defined(MatchPreset2))       ? ((mpNum1 + 2 <= 9) ? (mpNum1 + 2) : 9) : \
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

	NoisePreset = default( NoisePreset, "Fast" )
	npNum = (NoisePreset == "Slower" ) ? 0 : \
	        (NoisePreset == "Slow"   ) ? 1 : \
	        (NoisePreset == "Medium" ) ? 2 : \
	        (NoisePreset == "Fast"   ) ? 3 : \
	        (NoisePreset == "Faster" ) ? 4 : 5
	Assert( npNum < 5, "'NoisePreset' choice is invalid" )

	Tuning = default( Tuning, "None" )
	tNum = (Tuning == "None"  ) ? 0 : \
	       (Tuning == "DV-SD" ) ? 1 : \
	       (Tuning == "DV-HD" ) ? 2 : 3
	Assert( tNum < 3, "'Tuning' choice is invalid" )

	# Tunings only affect blocksize in this version
	bs = Select( tNum,  16, 16, 32 )
	bs2 = (bs >= 16) ? 32 : bs * 2

	#                                                               Very                                                        Very      Super      Ultra
	# Preset groups:                                     Placebo    Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast       Fast       Draft
	TR0          = default( TR0,          Select( pNum,  2,         2,        2,        2,        2,        2,        1,        1,        1,         1,         1      ) )
	TR1          = default( TR1,          Select( pNum,  2,         2,        2,        1,        1,        1,        1,        1,        1,         1,         1      ) )
	TR2X         = default( TR2,          Select( pNum,  3,         2,        1,        1,        1,        0,        0,        0,        0,         0,         0      ) )
	Rep0         = default( Rep0,         Select( pNum,  4,         4,        4,        4,        3,        3,        0,        0,        0,         0,         0      ) )
	Rep1         = default( Rep1,         Select( pNum,  0,         0,        0,        0,        0,        0,        0,        0,        0,         0,         0      ) )
	Rep2         = default( Rep2,         Select( pNum,  4,         4,        4,        4,        4,        4,        4,        4,        3,         3,         0      ) )
	EdiMode      = default( EdiMode,      Select( pNum, "NNEDI3",  "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3",  "RepYadif","Bob"   ) )
	NNSize       = default( NNSize,       Select( pNum,  1,         1,        1,        1,        5,        5,        4,        4,        4,         4,         4      ) )
	NNeurons     = default( NNeurons,     Select( pNum,  2,         2,        1,        1,        1,        0,        0,        0,        0,         0,         0      ) )
	EdiQual      = default( EdiQual,      Select( pNum,  1,         1,        1,        1,        1,        1,        1,        1,        1,         1,         1      ) )
	EdiMaxD      = default( EdiMaxD,      Select( pNum,  12,        10,       8,        7,        7,        6,        6,        5,        4,         4,         4      ) )
	SMode        = default( SMode,        Select( pNum,  2,         2,        2,        2,        2,        2,        2,        2,        2,         2,         0      ) )
	SLModeX      = default( SLMode,       Select( pNum,  2,         2,        2,        2,        2,        2,        2,        2,        0,         0,         0      ) )
	SLRad        = default( SLRad,        Select( pNum,  3,         1,        1,        1,        1,        1,        1,        1,        1,         1,         1      ) )
	Sbb          = default( Sbb,          Select( pNum,  3,         1,        1,        0,        0,        0,        0,        0,        0,         0,         0      ) )
	SrchClipPP   = default( SrchClipPP,   Select( pNum,  3,         3,        3,        3,        3,        2,        2,        2,        1,         1,         0      ) )
	SubPel       = default( SubPel,       Select( pNum,  2,         2,        2,        2,        1,        1,        1,        1,        1,         1,         1      ) )
	Blocksize    = default( Blocksize,    Select( pNum,  bs,        bs,       bs,       bs,       bs,       bs,       bs2,      bs2,      bs2,       bs2,       bs2    ) )
	bs = Blocksize
	Overlap      = default( Overlap,      Select( pNum,  bs/2,      bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/2,     bs/4,     bs/4,      bs/4,      bs/4   ) )
	Search       = default( Search,       Select( pNum,  5,         4,        4,        4,        4,        4,        4,        4,        0,         0,         0      ) )
	SearchParam  = default( SearchParam,  Select( pNum,  2,         2,        2,        2,        2,        2,        2,        1,        1,         1,         1      ) )
	PelSearch    = default( PelSearch,    Select( pNum,  2,         2,        2,        2,        1,        1,        1,        1,        1,         1,         1      ) )
	ChromaMotion = default( ChromaMotion, Select( pNum,  true,      true,     true,     false,    false,    false,    false,    false,    false,     false,     false  ) )
	Precise      = default( Precise,      Select( pNum,  true,      true,     false,    false,    false,    false,    false,    false,    false,     false,     false  ) )
	ProgSADMask  = default( ProgSADMask,  Select( pNum,  10.0,      10.0,     10.0,     10.0,     10.0,     0.0,      0.0,      0.0,      0.0,       0.0,       0.0    ) )

	# Noise presets                                           Slower     Slow       Medium     Fast       Faster
	Denoiser       = default( Denoiser,       Select( npNum, "dfttest", "dfttest", "dfttest", "fft3df",  "fft3df" ) )
	DenoiseMC      = default( DenoiseMC,      Select( npNum,  true,      true,      false,     false,     false   ) )
	NoiseTR        = default( NoiseTR,        Select( npNum,  2,         1,         1,         1,         0       ) )
	NoiseDeint     = default( NoiseDeint,     Select( npNum, "Generate","Bob",      "",        "",        ""      ) )
	StabilizeNoise = default( StabilizeNoise, Select( npNum,  true,      true,      true,      false,     false   ) )

	# The basic source-match step corrects and re-runs the interpolation of the input clip. So it initialy uses same interpolation settings as the main preset
	SourceMatch   = default( SourceMatch, 0 )
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
	EdiMode  = (SourceMatch == 0) ? EdiMode  : default( MatchEdi, ((mpNum1 < 9) ?  EdiMode : "Yadif") ) # Force Yadif for "Ultra Fast" basic source match
	MatchEdi = TempEdi

	#                                                          Very                                                        Very      Super     Ultra
	# Refined source-match presets                   Placebo   Slow      Slower    Slow      Medium    Fast      Faster    Fast      Fast      Fast
	MatchEdi2 = default( MatchEdi2, Select( mpNum2, "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "NNEDI3", "TDeint",  ""    ) )
	MatchNNSize2                  = Select( mpNum2,  1,        1,        1,        1,        5,        5,        4,        4,        4,        4     )
	MatchNNeurons2                = Select( mpNum2,  2,        2,        1,        1,        1,        0,        0,        0,        0,        0     )
	MatchEdiMaxD2                 = Select( mpNum2,  12,       10,       8,        7,        7,        6,        6,        5,        4,        4     )
	MatchEdiQual2                 = Select( mpNum2,  1,        1,        1,        1,        1,        1,        1,        1,        1,        1     )


	#---------------------------------------
	# Settings

	# Core and Interpolation defaults
	TR2        = (SourceMatch > 0) ? default(TR2, ((TR2X == 0) ? 1 : TR2X)) : TR2X  # ***TR2 defaults always at least 1 when using source-match***
	RepChroma  = default( RepChroma,  true )
	EdiThreads = default( EdiThreads, 0    )
	ChromaEdi  = default( ChromaEdi,  ""   )
	NNeurons   = (EdiMode == "NNEDI2" && NNeurons > 2) ? 2 : NNeurons # Smaller range for NNeurons in NNEDI2 (which calls it nsize)
	EdiQual    = (EdiMode == "NNEDI3" && EdiQual > 2 ) ? 2 : EdiQual  # Smaller range for EdiQual in NNEDI3
	((FindStr( EdiMode, "Yadif" ) != 0 || FindStr( MatchEdi, "Yadif" ) != 0 || FindStr( MatchEdi2, "Yadif" ) != 0  ) && YadifPath != "") ? \
		Load_Stdcall_Plugin( YadifPath ) : NOP() # Load Yadif as required

	# Source-match / lossless defaults
	MatchTR1     = TR1
	MatchTR2     = default( MatchTR2,     1   )
	MatchEnhance = default( MatchEnhance, 0.5 )
	Lossless     = default( Lossless,     0   )
	Assert( Lossless <= 2, "Lossless setting only supports mode 1 ('true lossless') and mode 2 ('fake lossless') - see documentation in script and consider source-match settings" )

	# Sharpness defaults. Sharpness default is always 1.0 (0.2 with source-match), but adjusted to give roughly same sharpness for all settings
	SMode      = (defined(Sharpness) && Sharpness == 0.0) ? 0 : SMode
	SLMode     = (SourceMatch > 0) ? default(SLMode, 0) : SLModeX  # ***Sharpness limiting disabled by default for source-match***
	SLMode     = (SLRad <= 0)      ? 0 : SLMode
	spatialSL  = (SLMode == 1 || SLMode == 3)
	temporalSL = (SLMode == 2 || SLMode == 4)
	Sharpness  = default( Sharpness, (SMode == 0) ? 0.0 : ((SourceMatch > 0) ? 0.2 : 1.0) )      # Default sharpness is 1.0, or 0.2 if using source-match
	sharpMul   = (temporalSL) ? 2 : (spatialSL) ? 1.5 : 1                                        # Adjust sharpness based on other settings
	sharpAdj   = Sharpness * (sharpMul * (0.2 + TR1*0.15 + TR2*0.25) + ((SMode == 1) ? 0.1 : 0)) # [This needs a bit more refinement]
	Sbb        = (SMode == 0) ? 0 : Sbb
	SOvs       = default( SOvs,   0   )
	SVThin     = default( SVThin, 0.0 )

	# Noise processing settings
	Assert( !defined(EZDenoise) || EZDenoise <= 0.0 || !defined(EZKeepGrain) || EZKeepGrain <= 0.0, "QTGMC: EZDenoise and EZKeepGrain cannot be used together" )
	NoiseProcess = defined(NoiseProcess) ? NoiseProcess : \
	               (defined(EZDenoise)   && EZDenoise   > 0.0)    ? 1 : \
	               (defined(EZKeepGrain) && EZKeepGrain > 0.0)    ? 2 : \
				   (Preset == "Placebo" || Preset == "Very Slow") ? 2 : 0
	GrainRestore = defined(GrainRestore) ? GrainRestore : \
	               (defined(EZDenoise)   && EZDenoise   > 0.0) ? 0.0 : \
	               (defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 0.3 * sqrt(EZKeepGrain) : \
				                                                Select( NoiseProcess, 0.0, 0.7, 0.3 )
	NoiseRestore = defined(NoiseRestore) ? NoiseRestore : \
	               (defined(EZDenoise)   && EZDenoise   > 0.0) ? 0.0 : \
	               (defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 0.1 * sqrt(EZKeepGrain) : \
				                                                Select( NoiseProcess, 0.0, 0.3, 0.1 )
	Sigma        = defined(Sigma)       ? Sigma : \
	               (defined(EZDenoise)   && EZDenoise   > 0.0) ? EZDenoise : \
	               (defined(EZKeepGrain) && EZKeepGrain > 0.0) ? 4.0 * EZKeepGrain : 2.0
	DftThreads   = default( DftThreads, EdiThreads )
	ChromaNoise  = default( ChromaNoise, false )
	ShowNoise    = default( ShowNoise, 0.0 )
	ShowNoise    = IsBool( ShowNoise ) ? (ShowNoise ? 10.0 : 0.0) : ShowNoise
	NoiseProcess = (ShowNoise > 0.0)   ? 2   : NoiseProcess
	NoiseRestore = (ShowNoise > 0.0)   ? 1.0 : NoiseRestore
	NoiseTR      = (NoiseProcess == 0) ? 0   : NoiseTR
	GrainRestore = (NoiseProcess == 0) ? 0.0 : GrainRestore
	NoiseRestore = (NoiseProcess == 0) ? 0.0 : NoiseRestore
	totalRestore = GrainRestore + NoiseRestore
	StabilizeNoise = (totalRestore <= 0) ? false : StabilizeNoise
	noiseTD  = Select( NoiseTR, 1, 3, 5 )
	noiseCentre = (Denoiser == "dfttest") ? "128" : "128.5"

	# MVTools settings
	SubPelInterp = default( SubPelInterp, 2     )
	TrueMotion   = default( TrueMotion,   false )
	GlobalMotion = default( GlobalMotion, true  )
	Lambda       = default( Lambda, ((TrueMotion) ? 1000 : 100 ) * (BlockSize*BlockSize)/(8*8) )
	LSAD         = default( LSAD,    (TrueMotion) ? 1200 : 400 )
	PNew         = default( PNew,    (TrueMotion) ? 50   : 25  )
	PLevel       = default( PLevel,  (TrueMotion) ? 1    : 0   )
	DCT          = default( DCT,     0          )
	ThSAD1       = default( ThSAD1,  10 * 8*8   )
	ThSAD2       = default( ThSAD2,   4 * 8*8   )
	ThSCD1       = default( ThSCD1,  180        )
	ThSCD2       = default( ThSCD2,  98         )

	# Motion blur settings
	FPSDivisor  = default( FPSDivisor, 1 )
	ShutterBlur = default( ShutterBlur, 0 )
	ShutterAngleSrc = default( ShutterAngleSrc, 180 )
	ShutterAngleOut = default( ShutterAngleOut, 180 )
	SBlurLimit  = default( SBlurLimit, 4 )
	ShutterBlur = (ShutterAngleOut * FPSDivisor == ShutterAngleSrc) ? 0 : ShutterBlur  # If motion blur output is same as input

	# Miscellaneous
	InputType      = default( InputType,     0        )
	Border         = default( Border,        false    )
	ShowSettings   = default( ShowSettings,  false    )
	GlobalNames    = default( GlobalNames,  "QTGMC"   )
	PrevGlobals    = default( PrevGlobals,  "Replace" )
	ForceTR        = default( ForceTR,       0        )
	ReplaceGlobals = (PrevGlobals == "Replace" || PrevGlobals == "Reuse") # If reusing existing globals put them back afterwards - simplifies logic later
	ReuseGlobals   = (PrevGlobals == "Reuse")
	ProgSADMask    = (InputType != 2 && InputType != 3) ? 0.0 : ProgSADMask
	rgBlur         = (Precise) ? 11 : 12

	# Dogways Added Defaults
	RefineMotion = default( RefineMotion,        false    )
	lsbd         = default(lsbd, false)
	lsb          = default(lsb, false)
	halfoverlap=Overlap/2
	halfblksize=BlockSize/2
	halfthSAD=round(thSAD2/2)

	# Get maximum temporal radius needed
	maxTR = (temporalSL)       ? SLRad : 0
	maxTR = (MatchTR2 > maxTR) ? MatchTR2 : maxTR
	maxTR = (TR1 > maxTR)      ? TR1 : maxTR
   	maxTR = (TR2 > maxTR)      ? TR2 : maxTR
   	maxTR = (NoiseTR > maxTR)  ? NoiseTR : maxTR
	maxTR = (ProgSADMask > 0.0 || StabilizeNoise || ShutterBlur > 0) ? (maxTR > 1 ? maxTR : 1) : maxTR
	maxTR = (ForceTR > MaxTR)  ? ForceTR : maxTR


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
	h = (Border) ? h+8 : h

	# Calculate padding needed for MVTools super clips to avoid crashes [fixed in latest MVTools, but keeping this code for a while]
	hpad = w - (Int((w - Overlap) / (Blocksize - Overlap)) * (Blocksize - Overlap) + Overlap)
	vpad = h - (Int((h - Overlap) / (Blocksize - Overlap)) * (Blocksize - Overlap) + Overlap)
	hpad = (hpad > 8) ? hpad : 8 # But match default padding if possible
	vpad = (vpad > 8) ? vpad : 8


	#---------------------------------------
	# Motion Analysis

	# >>> Planar YUY2 for motion analysis, interleaved whilst blurring search clip
	planarClip = yuy2 ? clip.Interleaved2Planar() : clip

	# Bob the input as a starting point for motion search clip
	bobbed = (InputType == 0) ? planarClip.QTGMC_Bob( 0,0.5 ) : \
	         (InputType == 1) ? planarClip : \
	                            planarClip.Blur( 0,1 )

	# If required, get any existing global clips with a matching "GlobalNames" setting. Unmatched values get NOP (= 0)
	srchClip  = QTGMC_GetUserGlobal( GlobalNames, "srchClip",  ReuseGlobals )
	srchSuper = QTGMC_GetUserGlobal( GlobalNames, "srchSuper", ReuseGlobals )
	bVec1     = QTGMC_GetUserGlobal( GlobalNames, "bVec1",     ReuseGlobals )
	fVec1     = QTGMC_GetUserGlobal( GlobalNames, "fVec1",     ReuseGlobals )
	bVec2     = QTGMC_GetUserGlobal( GlobalNames, "bVec2",     ReuseGlobals )
	fVec2     = QTGMC_GetUserGlobal( GlobalNames, "fVec2",     ReuseGlobals )
	bVec3     = QTGMC_GetUserGlobal( GlobalNames, "bVec3",     ReuseGlobals )
	fVec3     = QTGMC_GetUserGlobal( GlobalNames, "fVec3",     ReuseGlobals )

	CMmt = ChromaMotion ? 3   :  1
	CMts = ChromaMotion ? 255 :  0
	CMrg = ChromaMotion ? 12  : -1

	# The bobbed clip will shimmer due to being derived from alternating fields. Temporally smooth over the neighboring frames using a binomial kernel. Binomial
	# kernels give equal weight to even and odd frames and hence average away the shimmer. The two kernels used are [1 2 1] and [1 4 6 4 1] for radius 1 and 2.
	# These kernels are approximately Gaussian kernels, which work well as a prefilter before motion analysis (hence the original name for this script)
	# Create linear weightings of neighbors first                                                 -2    -1     0    1     2
	ts1 = (!IsClip(srchClip) && TR0 > 0) ? bobbed.TemporalSoften( 1, 255,CMts, 28, 2 ) : NOP()  # 0.00  0.33  0.33  0.33  0.00
	ts2 = (!IsClip(srchClip) && TR0 > 1) ? bobbed.TemporalSoften( 2, 255,CMts, 28, 2 ) : NOP()  # 0.20  0.20  0.20  0.20  0.20

	# Combine linear weightings to give binomial weightings - TR0=0: (1), TR0=1: (1:2:1), TR0=2: (1:4:6:4:1)
	binomial0 = IsClip(srchClip) ? NOP() : \
	            (TR0 == 0)       ? bobbed : \
	            (TR0 == 1)       ? (ChromaMotion ? ts1.Merge( bobbed, 0.25 ) : ts1.MergeLuma( bobbed, 0.25 )): \
	                               (ChromaMotion ? ts1.Merge( ts2, 0.357 ).Merge( bobbed, 0.125 ) : ts1.MergeLuma( ts2, 0.357 ).MergeLuma( bobbed, 0.125 ))

	# Remove areas of difference between temporal blurred motion search clip and bob that are not due to bob-shimmer - removes general motion blur
	repair0 = (IsClip(srchClip) || Rep0 == 0) ? binomial0 : binomial0.QTGMC_KeepOnlyBobShimmerFixes( bobbed, Rep0, (RepChroma && ChromaMotion) )

	# Blur image and soften edges to assist in motion matching of edge blocks. Blocks are matched by SAD (sum of absolute differences between blocks), but even
	# a slight change in an edge from frame to frame will give a high SAD due to the higher contrast of edges
	spatialBlur = (IsClip(srchClip) || SrchClipPP == 0) ? NOP() : \
	              (!yuy2 && SrchClipPP == 1) ? repair0.BilinearResize( w/2, h/2 ).RemoveGrain( 12,CMrg, planar=true ).BilinearResize( w, h ) : \
	              (!yuy2)                    ? repair0.RemoveGrain( 12,CMrg, planar=true ).GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=2 ) : \
	                                           repair0.RemoveGrain( 12,CMrg, planar=true ).Planar2Interleaved().GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=2 ).Interleaved2Planar()
	spatialBlur = (IsClip(spatialBlur) && SrchClipPP > 1) ? (ChromaMotion ? spatialBlur.Merge( repair0, 0.1 ) : spatialBlur.MergeLuma( repair0, 0.1 )) : spatialBlur
	tweaked     = (!IsClip(srchClip) && SrchClipPP > 1) ? mt_lutxy( repair0, bobbed, "x 3 + y < x 3 + x 3 - y > x 3 - y ? ?", U=CMmt,V=CMmt ) : NOP()
	srchClip    = IsClip(srchClip)  ? srchClip : \
	              (SrchClipPP == 0) ? repair0 : \
	              (SrchClipPP < 3)  ? spatialBlur : \
	                                  spatialBlur.mt_lutxy( tweaked, "x 7 + y < x 2 + x 7 - y > x 2 - x 51 * y 49 * + 100 / ? ?", U=CMmt,V=CMmt )
	# Calculate forward and backward motion vectors from motion search clip
	srchSuper = IsClip(srchSuper) ? srchSuper : \
	            (maxTR > 0)       ? srchClip.MSuper( pel=SubPel, sharp=SubPelInterp, hpad=hpad, vpad=vpad, chroma=ChromaMotion, planar=true ) : NOP()
	bVec3 = IsClip(bVec3) ? bVec3 : \
	        (maxTR > 2)   ? srchSuper.MAnalyse( isb=true,  delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
	                                            pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
	                                            global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : NOP()

	bVec3 = !RefineMotion ? bVec3 : srchSuper.MRecalculate(bVec3, overlap=halfoverlap,blksize=halfblksize,thSAD=halfthSAD,DCT=DCT, \
                                                           chroma=ChromaMotion,truemotion=TrueMotion,search=Search,                \
                                                           searchparam=SearchParam,lambda=Lambda,pnew=PNew)
 
	bVec2 = IsClip(bVec2) ? bVec2 : \
	        (maxTR > 1)   ? srchSuper.MAnalyse( isb=true,  delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
	                                            pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
	                                            global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : NOP()

	bVec2 = !RefineMotion ? bVec2 : srchSuper.MRecalculate(bVec2, overlap=halfoverlap,blksize=halfblksize,thSAD=halfthSAD,DCT=DCT, \
                                                           chroma=ChromaMotion,truemotion=TrueMotion,search=Search,                \
                                                           searchparam=SearchParam,lambda=Lambda,pnew=PNew)

	bVec1 = IsClip(bVec1) ? bVec1 : \
	        (maxTR > 0)   ? srchSuper.MAnalyse( isb=true,  delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
	                                            pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
	                                            global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : NOP()

	bVec1 = !RefineMotion ? bVec1 : srchSuper.MRecalculate(bVec1, overlap=halfoverlap,blksize=halfblksize,thSAD=halfthSAD,DCT=DCT, \
                                                           chroma=ChromaMotion,truemotion=TrueMotion,search=Search,                \
                                                           searchparam=SearchParam,lambda=Lambda,pnew=PNew)
	fVec1 = IsClip(fVec1) ? fVec1 : \
	        (maxTR > 0)   ? srchSuper.MAnalyse( isb=false, delta=1, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
	                                            pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
	                                            global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : NOP()

	fVec1 = !RefineMotion ? fVec1 : srchSuper.MRecalculate(fVec1, overlap=halfoverlap,blksize=halfblksize,thSAD=halfthSAD,DCT=DCT, \
                                                           chroma=ChromaMotion,truemotion=TrueMotion,search=Search,                \
                                                           searchparam=SearchParam,lambda=Lambda,pnew=PNew)
	fVec2 = IsClip(fVec2) ? fVec2 : \
	        (maxTR > 1)   ? srchSuper.MAnalyse( isb=false, delta=2, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
	                                            pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
	                                            global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : NOP()

	fVec2 = !RefineMotion ? fVec2 : srchSuper.MRecalculate(fVec2, overlap=halfoverlap,blksize=halfblksize,thSAD=halfthSAD,DCT=DCT, \
                                                           chroma=ChromaMotion,truemotion=TrueMotion,search=Search,                \
                                                           searchparam=SearchParam,lambda=Lambda,pnew=PNew)
	fVec3 = IsClip(fVec3) ? fVec3 : \
	        (maxTR > 2)   ? srchSuper.MAnalyse( isb=false, delta=3, blksize=BlockSize, overlap=Overlap, search=Search, searchparam=SearchParam, \
	                                            pelsearch=PelSearch, truemotion=TrueMotion, lambda=Lambda, lsad=LSAD, pnew=PNew, plevel=PLevel, \
	                                            global=GlobalMotion, DCT=DCT, chroma=ChromaMotion ) : NOP()

	fVec3 = !RefineMotion ? fVec3 : srchSuper.MRecalculate(fVec3, overlap=halfoverlap,blksize=halfblksize,thSAD=halfthSAD,DCT=DCT, \
                                                           chroma=ChromaMotion,truemotion=TrueMotion,search=Search,                \
                                                           searchparam=SearchParam,lambda=Lambda,pnew=PNew)


	# Expose search clip, motion search super clip and motion vectors to calling script through globals
	QTGMC_SetUserGlobal( GlobalNames, "srchClip",  srchClip,  ReplaceGlobals )
	QTGMC_SetUserGlobal( GlobalNames, "srchSuper", srchSuper, ReplaceGlobals )
	QTGMC_SetUserGlobal( GlobalNames, "bVec1",     bVec1,     ReplaceGlobals )
	QTGMC_SetUserGlobal( GlobalNames, "fVec1",     fVec1,     ReplaceGlobals )
	QTGMC_SetUserGlobal( GlobalNames, "bVec2",     bVec2,     ReplaceGlobals )
	QTGMC_SetUserGlobal( GlobalNames, "fVec2",     fVec2,     ReplaceGlobals )
	QTGMC_SetUserGlobal( GlobalNames, "bVec3",     bVec3,     ReplaceGlobals )
	QTGMC_SetUserGlobal( GlobalNames, "fVec3",     fVec3,     ReplaceGlobals )


	#---------------------------------------
	# Noise Processing

	# >>>> Interleaved YUY2 for denoising, planar whilst pre-motion compensating

	# Expand fields to full frame size before extracting noise (allows use of motion vectors which are frame-sized)
	fullClip  = (NoiseProcess == 0) ? NOP() : \
	            (InputType > 0)     ? clip : \
	                                  clip.QTGMC_Bob( 0,1.0 )
	fullClip  = (yuy2 && NoiseTR > 0) ? fullClip.Interleaved2Planar() : fullClip
	fullSuper = (NoiseTR > 0)         ? fullClip.MSuper( pel=SubPel, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise, planar=true ) : NOP() #TEST chroma OK?

	# Create a motion compensated temporal window around current frame and use to guide denoisers
	noiseWindow = (NoiseProcess == 0) ? NOP() : \
	              (!DenoiseMC)        ? fullClip : \
	              (NoiseTR == 0)      ? fullClip : \
	              (NoiseTR == 1)      ? Interleave( fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ), \
	                                                fullClip, \
	                                                fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) ) : \
	                                    Interleave( fullClip.MCompensate( fullSuper, fVec2, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ), \
	                                                fullClip.MCompensate( fullSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ), \
	                                                fullClip, \
	                                                fullClip.MCompensate( fullSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ), \
	                                                fullClip.MCompensate( fullSuper, bVec2, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) )
	noiseWindow = (yuy2 && NoiseTR > 0) ? noiseWindow.Planar2Interleaved() : noiseWindow
	dnWindow = (NoiseProcess == 0)      ? NOP() : \
	           (Denoiser == "dfttest")  ? noiseWindow.dfttest( Y=true, U=ChromaNoise, V=ChromaNoise, sigma=Sigma*4, tbsize=noiseTD, threads=DftThreads, lsb=lsbd ) : \
	                                      noiseWindow.FFT3DFilter( plane=(ChromaNoise ? 4 : 0), sigma=Sigma, bt=noiseTD )
	dnwindow = (Denoiser == "dfttest") && lsbd ? dnWindow.ditherpost(mode=6, U=ChromaNoise?3:2, V=ChromaNoise?3:2) : dnWindow

	# Rework denoised clip to match source format - various code paths here: discard the motion compensation window, discard doubled lines (from point resize)
	# Also reweave to get interlaced noise if source was interlaced (could keep the full frame of noise, but it will be poor quality from the point resize)
	denoised = (NoiseProcess == 0) ? NOP() : \
	           (!DenoiseMC)        ? ((InputType > 0) ? dnWindow : dnWindow.SeparateFields().SelectEvery( 4, 0,3 ).Weave()) : \
	           (InputType > 0)     ? ((NoiseTR == 0)  ? dnWindow : dnWindow.SelectEvery( noiseTD, NoiseTR )) : \
	                                 dnWindow.SeparateFields().SelectEvery( noiseTD*4, NoiseTR*2,NoiseTR*6+3 ).Weave()

	# >>>> Switch to planar YUY2 for noise bypass

	CNmt1   = ChromaNoise ? 3 : 1
	CNmt2   = ChromaNoise ? 3 : 2
	CNmt128 = ChromaNoise ? 3 : -128

	# Get actual noise from difference. Then 'deinterlace' where we have weaved noise - create the missing lines of noise in various ways
	planarDenoised = (NoiseProcess == 0) ? NOP() : yuy2 ? denoised.Interleaved2Planar() : denoised
	noise = (totalRestore > 0.0)  ? mt_makediff( planarClip, planarDenoised, U=CNmt1,V=CNmt1 ) : NOP()
	deintNoise = (NoiseProcess == 0 || totalRestore == 0.0) ? NOP() : \
	             (InputType != 0)                           ? noise : \
	             (NoiseDeint == "Bob")                      ? noise.QTGMC_Bob( 0,0.5 ) : \
	             (NoiseDeint == "Generate")                 ? noise.QTGMC_Generate2ndFieldNoise( denoised, ChromaNoise ) : \
	                                                          noise.DoubleWeave()
	# Motion-compensated stabilization of generated noise
	noiseSuper = (StabilizeNoise) ? deintNoise.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, chroma=ChromaNoise, planar=true ) : NOP()
	mcNoise    = (StabilizeNoise) ? deintNoise.MCompensate( noiseSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) : NOP()
	finalNoise = (StabilizeNoise) ? mt_lutxy( deintNoise, mcNoise, "x 128 - abs y 128 - abs > x y ? 0.6 * x y + 0.2 * +", U=CNmt1,V=CNmt1 ) : deintNoise

	# If NoiseProcess=1 denoise input clip. If NoiseProcess=2 leave noise in the clip and let the temporal blurs "denoise" it for a stronger effect
	innerClip = (NoiseProcess == 1) ? denoised : clip


	#---------------------------------------
	# Interpolation

	# >>>> Interleaved YUY2 for interpolation

	# Support badly deinterlaced progressive content - drop half the fields and reweave to get 1/2fps interlaced stream appropriate for QTGMC processing
	ediInput = (InputType == 2 || InputType == 3) ? innerClip.SeparateFields().SelectEvery(4,0,3).Weave() : innerClip

	# Create interpolated image as starting point for output
	edi1 = defined(EdiExt) ? EdiExt.PointResize( w,h, 0,(EdiExt.Height()-h)/2, -0,h+epsilon ) : \
	                         QTGMC_Interpolate( ediInput, InputType, EdiMode, NNSize, NNeurons, EdiQual, EdiMaxD, EdiThreads, \
	                                            yuy2 ? clip.QTGMC_Bob( 0,0.5 ) : bobbed, ChromaEdi )

	# >>>> Switch to planar YUY2 during next step - remains planar until very end of script except blurring for back blending & SVThin

	# InputType=2,3: use motion mask to blend luma between original clip & reweaved clip based on ProgSADMask setting. Use chroma from original clip in any case
	inputTypeBlend = (ProgSADMask > 0.0) ? MMask( srchClip, bVec1, kind=1, ml=ProgSADMask, planar=true ) : NOP()
	edi = (InputType != 2 && InputType != 3) ? (!yuy2 ? edi1 : edi1.Interleaved2Planar()) :\
	      (ProgSADMask <= 0.0)               ? (!yuy2 ? edi1.MergeChroma( innerClip ) : edi1.MergeChroma( innerClip ).Interleaved2Planar()) : \
	                                           (!yuy2 ? mt_merge( innerClip, edi1, inputTypeBlend, U=2,V=2 ) : \
											            mt_merge( innerClip.Interleaved2Planar(), edi1.Interleaved2Planar(), inputTypeBlend, U=2,V=2 ))

	# Get the max/min value for each pixel over neighboring motion-compensated frames - used for temporal sharpness limiting
	ediSuper = (TR1 > 0 || temporalSL)   ? edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, planar=true ) : NOP()
	bComp1   = (temporalSL)              ? edi.MCompensate( ediSuper, bVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) : NOP()
	fComp1   = (temporalSL)              ? edi.MCompensate( ediSuper, fVec1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) : NOP()
	tMax     = (temporalSL)              ? edi.mt_logic( fComp1, "max", U=3,V=3 ).mt_logic( bComp1, "max", U=3,V=3 )    : NOP()
	tMin     = (temporalSL)              ? edi.mt_logic( fComp1, "min", U=3,V=3 ).mt_logic( bComp1, "min", U=3,V=3 )    : NOP()
	bComp3   = (SLRad > 1 && temporalSL) ? edi.MCompensate( ediSuper, bVec3, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) : NOP()
	fComp3   = (SLRad > 1 && temporalSL) ? edi.MCompensate( ediSuper, fVec3, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) : NOP()
	tMax     = (SLRad > 1 && temporalSL) ? tMax.mt_logic( fComp3, "max", U=3,V=3 ).mt_logic( bComp3, "max", U=3,V=3 )   : tMax
	tMin     = (SLRad > 1 && temporalSL) ? tMin.mt_logic( fComp3, "min", U=3,V=3 ).mt_logic( bComp3, "min", U=3,V=3 )   : tMin


	#---------------------------------------
	# Create basic output

	# Use motion vectors to blur interpolated image (edi) with motion-compensated previous and next frames. As above, this is done to remove shimmer from
	# alternate frames so the same binomial kernels are used. However, by using motion-compensated smoothing this time we avoid motion blur. The use of
	# MDegrain1 (motion compensated) rather than TemporalSmooth makes the weightings *look* different, but they evaluate to the same values
	# Create linear weightings of neighbors first                                                                                             -2    -1     0    1     2
	degrain1 = (TR1 > 0) ? edi.MDegrain1( ediSuper, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb) : NOP()  # 0.00  0.33  0.33  0.33  0.00
	degrain2 = (TR1 > 1) ? edi.MDegrain1( ediSuper, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb) : NOP()  # 0.33  0.00  0.33  0.00  0.33
	degrain1 = (TR1 > 0) && lsb ? degrain1.ditherpost(mode=6)  : degrain1
	degrain2 = (TR1 > 1) && lsb ? degrain2.ditherpost(mode=6)  : degrain2

	# Combine linear weightings to give binomial weightings - TR1=0: (1), TR1=1: (1:2:1), TR1=2: (1:4:6:4:1)
	binomial1 = (TR1 == 0) ? edi : \
	            (TR1 == 1) ? degrain1.Merge( edi, 0.25 ) : \
	                         degrain1.Merge( degrain2, 0.2 ).Merge( edi, 0.0625 )

	# Remove areas of difference between smoothed image and interpolated image that are not bob-shimmer fixes: repairs residual motion blur from temporal smooth
	repair1 = (Rep1 == 0) ? binomial1 : binomial1.QTGMC_KeepOnlyBobShimmerFixes( edi, Rep1, RepChroma )

	# Apply source match - use difference between output and source to succesively refine output [extracted to function to clarify main code path]
	match = (SourceMatch == 0) ? repair1 : \
	                             repair1.QTGMC_ApplySourceMatch( InputType, ediInput, bVec1,fVec1, bVec2,fVec2, SubPel, SubPelInterp, hpad, vpad, \
	                                                             ThSAD1, ThSCD1, ThSCD2, SourceMatch, MatchTR1, MatchEdi, MatchNNSize, MatchNNeurons, \
	                                                             MatchEdiQual, MatchEdiMaxD, MatchTR2, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, \
	                                                             MatchEdiMaxD2, MatchEnhance, EdiThreads, lsb )

	# Lossless=2 - after preparing an interpolated, de-shimmered clip, restore the original source fields into it and clean up any artefacts.
	# This mode will not give a true lossless result because the resharpening and final temporal smooth are still to come, but it will add further detail.
	# However, it can introduce minor combing. This setting is best used together with source-match (it's effectively the final source-match stage).
	lossed1 = (Lossless == 2) ? QTGMC_MakeLossless( match, innerClip, InputType ) : match


	#---------------------------------------
	# Resharpen / retouch output

	# Resharpen to counteract temporal blurs. Little sharpening needed for source-match mode since it has already recovered sharpness from source
	vresharp1 = (SMode == 2) ? Merge( lossed1.mt_expand( mode="vertical", U=3,V=3 ), lossed1.mt_inpand( mode="vertical", U=3,V=3 ) ) : NOP()
	vresharp  = (Precise && SMode == 2) ? vresharp1.mt_lutxy( lossed1, "x y < x 1 + x y > x 1 - x ? ?", U=3,V=3 ) : vresharp1 # Precise mode: reduce tiny overshoot
	resharp   = (SMode == 0) ? lossed1 : \
	            (SMode == 1) ? lossed1.mt_lutxy( lossed1.RemoveGrain( rgBlur, planar=true ),  "x x y - "+ string(sharpAdj) + " * +", U=3,V=3 ) : \
	                           lossed1.mt_lutxy( vresharp.RemoveGrain( rgBlur, planar=true ), "x x y - "+ string(sharpAdj) + " * +", U=3,V=3 )

	# Slightly thin down 1-pixel high horizontal edges that have been widened into neigboring field lines by the interpolator
	SVThinSc = SVThin * 6.0
	vertMedD = (SVthin > 0.0) ? mt_lutxy( lossed1, lossed1.VerticalCleaner( mode=1, modeU=-1, modeV=-1, planar=true ), "y x - " + string(SVThinSc) + " * 128 +", U=1,V=1 ) : NOP()
	vertMedD = (SVthin > 0.0) ? (!yuy2 ? vertMedD.Blur( 1,0 ) : vertMedD.Planar2Interleaved().Blur( 1,0 ).Interleaved2Planar()) : NOP()
	neighborD = (SVthin > 0.0) ? mt_lutxy( vertMedD, vertMedD.RemoveGrain( rgBlur,-1, planar=true ), "y 128 - abs x 128 - abs > y 128 ?" ) : NOP()
	thin      = (SVthin > 0.0) ? resharp.mt_adddiff( neighborD, U=2,V=2 ) : resharp

	# Back blend the blurred difference between sharpened & unsharpened clip, before (1st) sharpness limiting (Sbb == 1,3). A small fidelity improvement
	backBlend1 = (Sbb != 1 && Sbb != 3) ? thin : \
		         !yuy2 ? thin.mt_makediff( mt_makediff( thin, lossed1, U=1,V=1 ).RemoveGrain( 12, -1, planar=true ) \
	                         .GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), U=2,V=2 ) : \
		                 thin.mt_makediff( mt_makediff( thin, lossed1, U=1,V=1 ).RemoveGrain( 12, -1, planar=true ) \
		                     .Planar2Interleaved().GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ).Interleaved2Planar(), U=2,V=2 )

	# Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
	# Occurs here (before final temporal smooth) if SLMode == 1,2. This location will restrict sharpness more, but any artefacts introduced will be smoothed
	sharpLimit1 = (SLMode == 1) ? backBlend1.Repair( ((SLrad <= 1) ? edi : backBlend1.Repair( edi, 12, planar=true )), 1, planar=true ) : \
	              (SLMode == 2) ? backBlend1.mt_clamp( tMax,tMin, Sovs,Sovs, U=3,V=3 ) : \
	                              backBlend1

	# Back blend the blurred difference between sharpened & unsharpened clip, after (1st) sharpness limiting (Sbb == 2,3). A small fidelity improvement
	backBlend2 = (Sbb < 2) ? sharpLimit1 : \
		         !yuy2     ? sharpLimit1.mt_makediff( mt_makediff( sharpLimit1, lossed1, U=1,V=1 ).RemoveGrain( 12, -1, planar=true ) \
	                                    .GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ), U=2,V=2 ) : \
		                     sharpLimit1.mt_makediff( mt_makediff( sharpLimit1, lossed1, U=1,V=1 ).RemoveGrain( 12, -1, planar=true ) \
	                                    .Planar2Interleaved().GaussResize( w,h, 0,0, w+epsilon,h+epsilon, p=5 ).Interleaved2Planar(), U=2,V=2 )

	# Add back any extracted noise, prior to final temporal smooth - this will restore detail that was removed as "noise" without restoring the noise itself
	# Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
	addNoise1 = (GrainRestore <= 0.0) ? backBlend2 : \
		backBlend2.mt_adddiff( finalNoise.mt_lut( "x " + noiseCentre + " - " + string(GrainRestore) + " * 128 +", U=CNmt1,V=CNmt1 ), U=CNmt2,V=CNmt2 )

	# Final light linear temporal smooth for denoising
	stableSuper = (TR2 > 0) ? addNoise1.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, planar=true ) : NOP()
	stable  = (TR2 == 0) ? addNoise1 : \
	          (TR2 == 1) ? addNoise1.MDegrain1( stableSuper, bVec1,fVec1,                           thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : \
	          (TR2 == 2) ? addNoise1.MDegrain2( stableSuper, bVec1,fVec1, bVec2,fVec2,              thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : \
 	                       addNoise1.MDegrain3( stableSuper, bVec1,fVec1, bVec2,fVec2, bVec3,fVec3, thSAD=ThSAD2, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb )
	stable  = (TR2 > 0) && lsb ? stable.ditherpost(mode=6) : stable

	# Remove areas of difference between final output & basic interpolated image that are not bob-shimmer fixes: repairs motion blur caused by temporal smooth
	repair2 = (Rep2 == 0) ? stable : stable.QTGMC_KeepOnlyBobShimmerFixes( edi, Rep2, RepChroma )

	# Limit over-sharpening by clamping to neighboring (spatial or temporal) min/max values in original
	# Occurs here (after final temporal smooth) if SLMode == 3,4. Allows more sharpening here, but more prone to introducing minor artefacts
	sharpLimit2 = (SLMode == 3) ? repair2.Repair( ((SLrad <= 1) ? edi : repair2.Repair( edi, 12, planar=true )), 1, planar=true ) : \
	              (SLMode == 4) ? repair2.mt_clamp( tMax,tMin, Sovs,Sovs, U=3,V=3 ) : \
	                              repair2

	# Lossless=1 - inject source fields into result and clean up inevitable artefacts. Provided NoiseRestore=0.0 or 1.0, this mode will make the script result 
	# properly lossless, but this will retain source artefacts and cause some combing (where the smoothed deinterlace doesn't quite match the source)
	lossed2 = (Lossless == 1) ? QTGMC_MakeLossless( sharpLimit2, innerClip, InputType ) : sharpLimit2

	# Add back any extracted noise, after final temporal smooth. This will appear as noise/grain in the output
	# Average luma of FFT3DFilter extracted noise is 128.5, so deal with that too
	addNoise2 = (NoiseRestore <= 0.0) ? lossed2 : \
		lossed2.mt_adddiff( finalNoise.mt_lut( "x " + noiseCentre + " - " + string(NoiseRestore) + " * 128 +", U=CNmt1,V=CNmt1 ), U=CNmt2,V=CNmt2 )


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
	sblurSuper = (ShutterBlur > 0) ? addNoise2.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, planar=true ) : NOP()
	sblur =      (ShutterBlur > 0) ? addNoise2.MFlowBlur( sblurSuper, sbBVec1, sbFVec1, blur=blurLevel, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true ) : NOP()

	# Shutter motion blur - use motion mask to reduce blurring in areas of low motion - also helps reduce blur "bleeding" into static areas, then select blur type
	sbMotionMask = (ShutterBlur > 0 && SBlurLimit > 0) ? MMask( srchClip, bVec1, kind=0, ml=SBlurLimit, planar=true ) : NOP()
	sblurred     = (ShutterBlur == 0) ? addNoise2 : \
	               (SBlurLimit == 0)  ? sblur : \
	                                    mt_merge( addNoise2, sblur, sbMotionMask, U=3,V=3 )
	# Reduce frame rate
	decimated = (FPSDivisor != 1) ? sblurred.SelectEvery( FPSDivisor, 0 ) : sblurred

	# Crop off temporary vertical padding
	cropped = Border ? decimated.Crop( 0, 4, -0, -4 ) : decimated
	h = Border ? h-8 : h

	# Show output of choice + settings
	# >>>> Restore YUY2 to interleaved
	output = (ShowNoise == 0.0) ? cropped : finalNoise.mt_lut( "x 128 - " + string(ShowNoise) + " * 128 +", U=CNmt128,V=CNmt128 )
	output = yuy2 ? output.Planar2Interleaved() : output
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
		Denoiser + "' | DftThreads=" + string(DftThreads) + " | DenoiseMC=" + string(DenoiseMC) + " | NoiseTR=" + string(NoiseTR) + " | Sigma=" + \
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

# Same as Bob, but keeps the field order the same. Also fix for YV12 chroma center.
function QTGMC_Bob(clip clip, float "b", float "c", float "height" )
{
  h = Default(Height, Height(clip))
  w = clip.Width
 
  oiFields=clip.AssumeTFF().SeparateFields()
  Ec = oiFields.SelectEven().BicubicResize(w, h, b, c,  src_top=0.5).AssumeFrameBased()
  Oc = oiFields.SelectOdd( ).BicubicResize(w, h, b, c, src_top=-0.5).AssumeFrameBased()
  crchroma=GetParity(clip) ? Interleave(Ec, Oc).AssumeTFF() : Interleave(Oc, Ec).AssumeBFF()
        (clip.GetParity()) ? clip.Bob( b,c, height ).AssumeTFF() : \
                             clip.Bob( b,c, height ).AssumeBFF()
        IsYV12(clip) ? MergeChroma(crchroma) : last
}


# Interpolate input clip using method given in EdiMode. Use Fallback or Bob as result if mode not in list. If ChromaEdi string if set then interpolate chroma
# separately with that method (only really useful for EEDIx). The function is used as main algorithm starting point and for first two source-match stages
function QTGMC_Interpolate( clip Input, int InputType, string EdiMode, int NNSize, int NNeurons, int EdiQual, int EdiMaxD, int EdiThreads, clip "Fallback", \
                            string "ChromaEdi" )
{
	# >>>> YUY2 is interleaved here

	ChromaEdi = default( ChromaEdi, "" )
	CEed = (ChromaEdi == "")

	interp = (InputType == 1)            ? Input : \
	         (EdiMode == "NNEDI3")       ? Input.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads, U=CEed,V=CEed ) : \
	         (EdiMode == "NNEDI2")       ? Input.NNEDI2( field=-2, nsize=NNeurons, qual=EdiQual, threads=EdiThreads, U=CEed,V=CEed ) : \
	         (EdiMode == "NNEDI")        ? Input.NNEDI( field=-2, U=CEed,V=CEed ) : \
	         (EdiMode == "EEDI3+NNEDI3") ? Input.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, U=CEed,V=CEed, \
		                                                sclip=Input.NNEDI3( field=-2, nsize=NNSize, nns=NNeurons, qual=EdiQual, threads=EdiThreads, U=CEed,V=CEed ) ) : \
	         (EdiMode == "EEDI3")        ? Input.EEDI3( field=-2, mdis=EdiMaxD, threads=EdiThreads, U=CEed,V=CEed ) : \
	         (EdiMode == "EEDI2")        ? Input.SeparateFields().EEDI2( field=-2, maxd=EdiMaxD ) : \
	         (EdiMode == "Yadif")        ? Input.Yadif( mode=3 ) : \
	         (EdiMode == "TDeint")       ? Input.TDeInt( mode=1 ) : \
	         (EdiMode == "RepYadif")     ? Repair( Input.Yadif( mode=3 ), default( Fallback, Input.QTGMC_Bob( 0,0.5 ) ), 2, 0 ) : \
	                                       default( Fallback, Input.QTGMC_Bob( 0,0.5 ) )

	interpuv = (InputType == 1)        ? NOP() : \
	           (ChromaEdi == "NNEDI3") ? Input.NNEDI3( field=-2, nsize=4, nns=0, qual=1, threads=EdiThreads, Y=false ) : \
	           (ChromaEdi == "Yadif")  ? Input.Yadif( mode=3 ) : \
	           (ChromaEdi == "Bob")    ? Input.QTGMC_Bob( 0,0.5 ) : \
			                             NOP()

	return (!IsClip(interpuv)) ? interp : interp.MergeChroma( interpuv )
}

# Helper function: Compare processed clip with reference clip: only allow thin, horizontal areas of difference, i.e. bob shimmer fixes
# Rough algorithm: Get difference, deflate vertically by a couple of pixels or so, then inflate again. Thin regions will be removed
#                  by this process. Restore remaining areas of difference back to as they were in reference clip.
function QTGMC_KeepOnlyBobShimmerFixes( clip Input, clip Ref, int Rep, bool Chroma )
{
	# >>>> YUY2 is planar here

	# ed is the erosion distance - how much to deflate then reflate to remove thin areas of interest: 0 = minimum to 5 = maximum
	# od is over-dilation level  - extra inflation to ensure areas to restore back are fully caught:  0 = none to 3 = one full pixel
	# If Rep < 10, then ed = Rep and od = 0, otherwise ed = 10s digit and od = 1s digit (nasty method, but kept for compatibility with original TGMC)
	Rep    = default( Rep,    1    )
	Chroma = default( Chroma, true )
	ed = (Rep < 10) ? Rep : Rep / 10
	od = (Rep < 10) ? 0   : Rep % 10
	RCrg  = Chroma ? 3 : 1
	RCrgo = Chroma ? 3 : 2

	diff = mt_makediff( Ref, Input, U=3,V=3 )

	# Areas of positive difference                                                                # ed = 0 1 2 3 4 5 6 7
	choke1 =                        diff.  mt_inpand( mode="vertical", U=RCrg,V=RCrg )            #      x x x x x x x x    1 pixel   \
	choke1 = (ed > 2)             ? choke1.mt_inpand( mode="vertical", U=RCrg,V=RCrg ) : choke1   #      . . . x x x x x    1 pixel    |  Deflate to remove thin areas
	choke1 = (ed > 5)             ? choke1.mt_inpand( mode="vertical", U=RCrg,V=RCrg ) : choke1   #      . . . . . . x x    1 pixel   /
	choke1 = (ed % 3 != 0)        ? choke1.mt_deflate( U=RCrg,V=RCrg )                 : choke1   #      . x x . x x . x    A bit more deflate & some horizonal effect
	choke1 = (ed == 2 || ed == 5) ? choke1.RemoveGrain( 4, planar=true )               : choke1   #      . . x . . x . .    Local median
                                                                                                                      
	choke1 =                        choke1.mt_expand( mode="vertical", U=RCrg,V=RCrg )            #      x x x x x x x x    1 pixel  \
	choke1 = (ed > 1)             ? choke1.mt_expand( mode="vertical", U=RCrg,V=RCrg ) : choke1   #      . . x x x x x x    1 pixel   | Reflate again
	choke1 = (ed > 4)             ? choke1.mt_expand( mode="vertical", U=RCrg,V=RCrg ) : choke1   #      . . . . . x x x    1 pixel  /

	# Over-dilation - extra reflation up to about 1 pixel
	choke1 = (od == 0)            ? choke1 : \
	         (od == 1)            ? choke1.mt_inflate( U=RCrg,V=RCrg ) : \
	         (od == 2)            ? choke1.mt_inflate( U=RCrg,V=RCrg ).mt_inflate( U=RCrg,V=RCrg ) : \
	                                choke1.mt_expand ( U=RCrg,V=RCrg )

	# Areas of negative difference (similar to above)
	choke2 =                        diff.  mt_expand( mode="vertical", U=RCrg,V=RCrg )         
	choke2 = (ed > 2)             ? choke2.mt_expand( mode="vertical", U=RCrg,V=RCrg ) : choke2
	choke2 = (ed > 5)             ? choke2.mt_expand( mode="vertical", U=RCrg,V=RCrg ) : choke2
	choke2 = (ed % 3 != 0)        ? choke2.mt_inflate( U=RCrg,V=RCrg )                 : choke2
	choke2 = (ed == 2 || ed == 5) ? choke2.RemoveGrain( 4, planar=true )               : choke2
	choke2 =                        choke2.mt_inpand( mode="vertical", U=RCrg,V=RCrg )
	choke2 = (ed > 1)             ? choke2.mt_inpand( mode="vertical", U=RCrg,V=RCrg ) : choke2
	choke2 = (ed > 4)             ? choke2.mt_inpand( mode="vertical", U=RCrg,V=RCrg ) : choke2
	choke2 = (od == 0)            ? choke2 : \
	         (od == 1)            ? choke2.mt_deflate( U=RCrg,V=RCrg )  : \
	         (od == 2)            ? choke2.mt_deflate( U=RCrg,V=RCrg ).mt_deflate( U=RCrg,V=RCrg ) : \
	                                choke2.mt_inpand ( U=RCrg,V=RCrg )

	# Combine above areas to find those areas of difference to restore
	restore = diff.mt_lutxy( choke1, "x 129 < x y 128 < 128 y ? ?", U=RCrg,V=RCrg ).mt_lutxy( choke2, "x 127 > x y 128 > 128 y ? ?", U=RCrg,V=RCrg )

	return Input.mt_adddiff( restore, U=RCrgo,V=RCrgo )
}


# Given noise extracted from an interlaced source (i.e. the noise is interlaced), generate "progressive" noise with a new "field" of noise injected. The new
# noise is centered on a weighted local average and uses the difference between local min & max as an estimate of local variance
# YUY2 clip input is planar, but must pass interleaved version of clip to setup noise
function QTGMC_Generate2ndFieldNoise( clip Input, clip InterleavedClip, bool "ChromaNoise" )
{
	# >>>> YUY2 is planar here. Noise is generated (AddGrainC) interleaved, but immediately made planar
	ChromaNoise = default( ChromaNoise, false )
	CNmt1 = ChromaNoise ? 3 : 1
	origNoise = Input.SeparateFields()
	noiseMax  = origNoise.mt_expand( mode="square", U=CNmt1,V=CNmt1 ).mt_expand( mode="horizontal", U=CNmt1,V=CNmt1 )
	noiseMin  = origNoise.mt_inpand( mode="square", U=CNmt1,V=CNmt1 ).mt_inpand( mode="horizontal", U=CNmt1,V=CNmt1 )
	random    = BlankClip( InterleavedClip.SeparateFields(), color_yuv=$808080 ).AddGrainC( var=1800, uvar=ChromaNoise ? 1800 : 0 )
	random    = InterleavedClip.IsYUY2() ? random.Interleaved2Planar() : random
	varRandom = mt_makediff( noiseMax, noiseMin, U=CNmt1,V=CNmt1 ).mt_lutxy( random, "x 128 - y * 256 / 128 +", U=CNmt1,V=CNmt1)
	newNoise  = noiseMin.mt_adddiff( varRandom, U=CNmt1,V=CNmt1 )
	return Interleave( origNoise, newNoise ).Weave()
}


# Insert the source lines into the result to create a true lossless output. However, the other lines in the result have had considerable processing and won't
# exactly match source lines. There will be some slight residual combing. Use vertical medians to clean a little of this away
function QTGMC_MakeLossless( clip Input, clip Source, int InputType )
{
	Assert( InputType != 1, "Lossless modes are incompatible with InputType=1" )

	# >>>> YUY2: 'Input' is planar, 'Source' is interleaved (changed to planar here for processing) - returns planar result

	# Weave the source fields and the "new" fields that have generated in the input
	srcFields1 = (InputType == 0) ? Source.SeparateFields() : Source.SeparateFields().SelectEvery( 4, 0,3 )
	srcFields  = Source.IsYUY2() ? srcFields1.Interleaved2Planar() : srcFields1
	newFields  = Input.SeparateFields().SelectEvery( 4, 1,2 )
	processed  = Interleave( srcFields, newFields ).SelectEvery(4, 0,1,3,2 ).Weave()

	# Clean some of the artefacts caused by the above - creating a second version of the "new" fields
	vertMedian  = processed.VerticalCleaner( mode=1, planar=true )
	vertMedDiff = mt_makediff( processed, vertMedian, U=3,V=3 )
	vmNewDiff1  = vertMedDiff.SeparateFields().SelectEvery( 4, 1,2 )
	vmNewDiff2  = vmNewDiff1.VerticalCleaner( mode=1, planar=true ).mt_lutxy( vmNewDiff1, "x 128 - y 128 - * 0 < 128 x 128 - abs y 128 - abs < x y ? ?", U=3,V=3 )
	vmNewDiff3  = vmNewDiff2.Repair( vmNewDiff2.RemoveGrain( 2, planar=true ), 1, planar=true )

	# Reweave final result
	return Interleave( srcFields, newFields.mt_makediff( vmNewDiff3, U=3,V=3 )).SelectEvery( 4, 0,1,3,2 ).Weave()
}


# Source-match, a three stage process that takes the difference between deinterlaced input and the original interlaced source, to shift the input more towards
# the source without introducing shimmer. All other arguments defined in main script
function QTGMC_ApplySourceMatch( clip Deinterlace, int InputType, val Source, val bVec1, val fVec1, val bVec2, val fVec2, \
                                 int SubPel, int SubPelInterp, int hpad, int vpad, int ThSAD1, int ThSCD1, int ThSCD2, int SourceMatch, \
                                 int MatchTR1, string MatchEdi, int MatchNNSize, int MatchNNeurons, int MatchEdiQual, int MatchEdiMaxD,\
                                 int MatchTR2, string MatchEdi2, int MatchNNSize2, int MatchNNeurons2, int MatchEdiQual2, int MatchEdiMaxD2, \
                                 float MatchEnhance, int EdiThreads, bool lsb )
{
	# >>>> YUY2: 'Deinterlace' is planar, 'Source' is interleaved (changed to planar here for all processing except interpolation) - returns planar result
	yuy2 = Source.IsYUY2()
	Source = yuy2 ? Source.Interleaved2Planar() : Source

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
						? Source : mt_lutxy( Source, match1Clip, "x " + string(errorAdjust1 + 1) + " * y " + string(errorAdjust1) + " * -", U=3,V=3 )
	match1Edi      = (SourceMatch == 0) ? NOP() : \
	                 !yuy2 ? match1Update.QTGMC_Interpolate( InputType, MatchEdi, MatchNNSize, MatchNNeurons, MatchEdiQual, MatchEdiMaxD, EdiThreads ) : \
	                         match1Update.Planar2Interleaved() \
	                                     .QTGMC_Interpolate( InputType, MatchEdi, MatchNNSize, MatchNNeurons, MatchEdiQual, MatchEdiMaxD, EdiThreads ) \
	                                     .Interleaved2Planar()
	match1Super    = (SourceMatch > 0 && MatchTR1 > 0) ? match1Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, planar=true ) : NOP()
	match1Degrain1 = (SourceMatch > 0 && MatchTR1 > 0) ? match1Edi.MDegrain1( match1Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : NOP()
	match1Degrain2 = (SourceMatch > 0 && MatchTR1 > 1) ? match1Edi.MDegrain1( match1Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : NOP()
	match1Degrain1 = (SourceMatch > 0 && MatchTR1 > 0) && lsb ? match1Degrain1.ditherpost(mode=6) : match1Degrain1
	match1Degrain2 = (SourceMatch > 0 && MatchTR1 > 1) && lsb ? match1Degrain2.ditherpost(mode=6) : match1Degrain2
	match1         = (SourceMatch < 1) ? Deinterlace : \
	                 (MatchTR1 == 0)   ? match1Edi : \
	                 (MatchTR1 == 1)   ? match1Degrain1.Merge( match1Edi, 0.25 ) : \
	                                     match1Degrain1.Merge( match1Degrain2, 0.2 ).Merge( match1Edi, 0.0625 )

	# Enhance effect of source-match stages 2 & 3 by sharpening clip prior to refinement (source-match tends to underestimate so this will leave result sharper)
	match1Shp = (SourceMatch > 1 && MatchEnhance > 0.0) ? match1.mt_lutxy( match1.RemoveGrain( 12, planar=true ), "x x y - "+ string(MatchEnhance) + " * +", U=3,V=3 ) : match1

	# Source-match refinement. Find difference between source clip & equivalent fields in (updated) interpolated/smoothed clip. Interpolate & binomially smooth
	# this difference then add it back to output. Helps restore differences that the basic match missed. However, as this pass works on a difference rather than
	# the source image it can be prone to occasional artefacts (difference images are not ideal for interpolation). In fact a lower quality interpolation such
	# as a simple bob often performs nearly as well as advanced, slower methods (e.g. NNEDI3)
	match2Clip     = (SourceMatch < 2 || InputType == 1) ? match1Shp : match1Shp.SeparateFields().SelectEvery( 4, 0,3 ).Weave()
	match2Diff     = (SourceMatch > 1) ? mt_makediff( Source, match2Clip, U=3,V=3 ) : NOP()
	match2Edi      = (SourceMatch <= 1) ? NOP() : \
	                 !yuy2 ? match2Diff.QTGMC_Interpolate( InputType, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, MatchEdiMaxD2, EdiThreads ) : \
	                         match2Diff.Planar2Interleaved() \
	                                   .QTGMC_Interpolate( InputType, MatchEdi2, MatchNNSize2, MatchNNeurons2, MatchEdiQual2, MatchEdiMaxD2, EdiThreads ) \
	                                   .Interleaved2Planar()
	match2Super    = (SourceMatch > 1 && MatchTR2 > 0) ? match2Edi.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, planar=true ) : NOP()
	match2Degrain1 = (SourceMatch > 1 && MatchTR2 > 0) ? match2Edi.MDegrain1( match2Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : NOP()
	match2Degrain2 = (SourceMatch > 1 && MatchTR2 > 1) ? match2Edi.MDegrain1( match2Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : NOP()
	match2Degrain1 = (SourceMatch > 1 && MatchTR2 > 0) && lsb ? match2Degrain1.ditherpost(mode=6) : match2Degrain1
	match2Degrain2 = (SourceMatch > 1 && MatchTR2 > 1) && lsb ? match2Degrain2.ditherpost(mode=6) : match2Degrain2
	match2         = (SourceMatch < 2) ? match1 : \
	                 (MatchTR2 == 0)   ? match2Edi : \
	                 (MatchTR2 == 1)   ? match2Degrain1.Merge( match2Edi, 0.25 ) : \
	                                     match2Degrain1.Merge( match2Degrain2, 0.2 ).Merge( match2Edi, 0.0625 )

	# Source-match second refinement - correct error introduced in the refined difference by temporal smoothing. Similar to error correction from basic step
	errorAdjust2   = Select( MatchTR2, 1.0, 2.0 / (1.0 + errorTemporalSimilarity), 8.0 / (3.0 + 5.0 * errorTemporalSimilarity) )
	match3Update   = (SourceMatch < 3 || MatchTR2 == 0) \
	                     ? match2Edi : mt_lutxy( match2Edi, match2, "x " + string(errorAdjust2 + 1) + " * y " + string(errorAdjust2) + " * -", U=3,V=3 )
	match3Super    = (SourceMatch > 2 && MatchTR2 > 0) ? match3Update.MSuper( pel=SubPel, sharp=SubPelInterp, levels=1, hpad=hpad, vpad=vpad, planar=true ) : NOP()
	match3Degrain1 = (SourceMatch > 2 && MatchTR2 > 0) ? match3Update.MDegrain1( match3Super, bVec1,fVec1, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : NOP()
	match3Degrain2 = (SourceMatch > 2 && MatchTR2 > 1) ? match3Update.MDegrain1( match3Super, bVec2,fVec2, thSAD=ThSAD1, thSCD1=ThSCD1,thSCD2=ThSCD2, planar=true, lsb=lsb ) : NOP()
	match3Degrain1 = (SourceMatch > 2 && MatchTR2 > 0) && lsb ? match3Degrain1.ditherpost(mode=6) : match3Degrain1
	match3Degrain2 = (SourceMatch > 2 && MatchTR2 > 1) && lsb ? match3Degrain2.ditherpost(mode=6) : match3Degrain2
	match3         = (SourceMatch < 3) ? match2 : \
	                 (MatchTR2 == 0)   ? match3Update : \
	                 (MatchTR2 == 1)   ? match3Degrain1.Merge( match3Update, 0.25 ) : \
	                                     match3Degrain1.Merge( match3Degrain2, 0.2 ).Merge( match3Update, 0.0625 )

	# Apply difference calculated in source-match refinement
	return (SourceMatch < 2) ? match1 : match1Shp.mt_adddiff( match3, U=3,V=3 )
}


# Set global variable called "Prefix_Name" to "Value". Throws exception if global already exists unless Replace=true, in which case the global is overwritten
function QTGMC_SetUserGlobal( string Prefix, string Name, val Value, bool "Replace" )
{
	Replace = default( Replace, false )
	globalName = Prefix + "_" + Name

	# Tricky logic to check global: enter catch block if Replace=true *or* globalName doesn't exist (i.e. need to set the global), the exception is not rethrown
	# Not entering catch block means that Replace=false and global exists - so it throws an exception back to AviSynth
	try { Assert( !Replace && defined(Eval(globalName)) ) }
	catch (e)
	{
		Eval( "global " + globalName + " = Value" )
		Replace = true
	}
	Assert( Replace, """Multiple calls to QTGMC, set PrevGlobals="Replace" or read documentation on 'Multiple QTGMC Calls'""" )
}

# Return value of global variable called "Prefix_Name". Returns NOP() if it doesn't exist or Reuse is false
function QTGMC_GetUserGlobal( string Prefix, string Name, bool "Reuse" )
{
	Reuse = default( Reuse, false )
	globalName = Prefix + "_" + Name

	try       { ret = Reuse ? Eval( globalName ) : NOP() }
	catch (e) { ret = NOP() }
	return ret
}
