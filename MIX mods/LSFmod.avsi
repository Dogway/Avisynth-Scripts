################################################################################################
###                                                                                          ###
###                       LimitedSharpenFaster MOD : function LSFmod()                       ###
###                                                                                          ###
###                                Modded Version by LaTo INV.                               ###
###                                                                                          ###
###                                  v1.9 - 05 October 2009                                  ###
###                                                                                          ###
###                            another Modded Version by A.SONY.                             ###
###                                                                                          ###
###                                v2.193 - 17 May 2021                                      ###
###                                                                                          ###
###                             HBD Performance mod by Dogway                                ###
###                                                                                          ###
###                                v3.7 mix - 18 October 2021                                ###
###                                                                                          ###
################################################################################################
###
### +-----------+
### | CHANGELOG |
### +-----------+
###
### v3.7ex : - Rebase to latest ResizersPack
###
### v3.6mx : - Add thSAD for MCompensate
###          - Cosmetics
###
### v3.5mx : - Additional checker for creation of motion vectors if SS is used
###          - and repair its motion compensated vectors
###          - Cosmetics
###
### v3.4mx : - Lmode=5 for zero limiting on not-edges
###          - Lmode=6 is now temporal limiting
###          - Improved temporal limiting
###          - Improved 'source' contrasharpening (was mostly noop before)
###          - Lrad arg, for better edge sharpening, specially on HD (Default 1 -off-)
###          - Optimized limiting logic when overshoot and undershoot are 0
###
### v3.3mx : - Lmode=5 for temporal limiting
###          - Optimization for mt_inflate()
###
### v3.2mx : - Expressions optimizations
###          - New preset 'mid'
###
### v3.1mx : - Rebase to latest ExTools for ex_bs()
###
### v3.0mx : - Optimizations
###
### v2.9mx : - Bugfix for HBD
###
### v2.8mx : - Rebase to latest ExTools for ex_bs()
###
### v2.7mx : - Revert to removegrain(20) (mathematically correct)
###          - Add internal HD mode
###
### v2.6mx : - Expressions cleanup
###
### v2.5mx : - Expressions optimizations
###
### v2.4mx : - Expressions fix and optimizations
###
### v2.3mx : - Expression optimizations
###
### v2.2mx : - "fulls" argument
###          - Rebasing with latest ExTools
###          - Removed old checks (YUY2 and old AVS support)
###          - Expression optimizations
###          - Default is now "slow"
###
### v2.193mx:- Removed < AviSynth+ 3.5 support
###          - Replaced with internal Expr() wrappers.
###          - Replaced UnsharpMask_avsi with faster UnsharpMask_HBD
###
### v2.193 : - replace UnsharpMask of Warpsharp to use UnsharpMask_avsi for HBD
###
### v2.192 : - added smode=6 (CAS) from vs port
###
### v2.191 : - optimise lut/expr with some ideas of VS port
###
### v2.190 : - fix and add new float parameters
###
### v2.189 : - remove unnecessary float clip clamp
###
### v2.188 : - fix (at least make it better) HBD when using high strength
###
### v2.187 : - fix bug in show=true
###
### v2.185 : - new avs26_optimize (bool) true by default, you can set it to false for smode=1 and smode=2 since not all filter updated to avs 2.6 colors
###
### v2.184 : - some fix when using soruce and make sure it will not work with RGB
###
### v2.183 : - fix bugs when show=true cases
###
### v2.18 : - fix upscale, i.e. dest_x or dest_y are larger than the input clip
###
### v2.12 : - HBD in avs+
###         - some fixes
###
### v1.9 : - tweaked settings
###        - default preset is now defaults="fast" /!\
###
### v1.8 : - changed preblur to allow more tweaking (bool->string)
###        - tweaked settings
###        - cleaned the code
###        - updated documentation
###
### v1.7 : - changed Smethod=4 to "source"
###
### v1.6 : - added preblur option
###        - added new Smethod=4
###
### v1.5 : - fixed LUT expression (thanks to Didée)
###        - changed Smethod to Smethod+secure
###
### v1.4 : - changed defaults="new" to defaults="slow" & defaults="fast"
###        - added show parameter
###        - cleaned a little the code
###
### v1.3 : - changed a little Smethod=3&5 (same effect, but more precise)
###        - added new calculation for soft (soft=-2) [default on]
###        - added warning about bad settings (no more silent)
###        - updated the documentation
###
### v1.2 : - added new Lmode<0 (limit with repair)
###        - added 2 new Smode (unsharp masking)
###        - changed Smode order: now old Smode3-4 is new Smode3-4 to avoid mistake
###
### v1.1 : - fixed a bug with dest_x!=ox or dest_y!=oy
###        - replaced Lfactor by over/undershoot2
###
### v1.0 : - deleted old Smode(1-4), added new Smode(1-3) & Smethod(1-5)
###        - added parameters for nonlinear sharpening (S2zp,S2pwr,S2dmpLo,S2dmpHi)
###        - corrected the nonlinear formula
###        - added new Lmode 2 & 4 + fixed Lmode 0
###        - added faster edgemask
###        - added soothe temporal stabilization, 2 parameters: soothe & keep
###        - replaced lanczosresize by spline36resize
###        - moved "strength" parameter (first place)
###        - deleted wide, special and exborder
###        - changed some code (cosmetic)
###        - added "defaults" parameter (to switch between original and modded version)
###        - added documentation
###
###
###
### +--------------+
### | DEPENDENCIES |
### +--------------+
###
### -> Masktools2   (v2.2.28 or up)
### -> RgTools      (v1.2 or up)
### -> ExTools      (v6.1 or up)
### -> SharpenersPack                  [for Smode=2]
### -> CAS                             [for Smode=6]
### -> if you use AviSynth+ then make sure it's the last one
###
###
###
###
### +-------+
### | USAGE |
### +-------+
###
### LSFmod( strength, Smode, Smethod,
###         preblur, secure, source,
###         Szrp, Spwr, SdmpLo, SdmpHi,
###         Lmode, Lrad, overshoot, undershoot, overshoot2, undershoot2,
###         soft, soothe, keep,
###         edgemode, edgemaskHQ,
###         ss_x, ss_y, dest_x, dest_y,
###         show, screenW, screenH,
###         preset, tv_range, fulls )
###
###
###
### +---------+
### | GENERAL |
### +---------+
###
### strength [int]
### --------------
### Strength of the sharpening
###
### Smode [int: 1,2,3,4,5,6]
### ----------------------
### Sharpen mode:
###    =1 : Unsharp masking (from warpsharp)     (now UnsharpMask_HBD)
###    =2 : Unsharp masking (from variableblur)  (now UnsharpMask_HBD)
###    =3 : Range sharpening
###    =4 : Nonlinear sharpening (original  version)
###    =5 : Nonlinear sharpening (corrected version)
###    =6 : Contrast Adaptive Sharpening (from CAS)
###
### Smethod [int: 1,2,3]
### --------------------
### Sharpen method: (only used in Smode=3,4,5)
###    =1 : 3x3 kernel
###    =2 : Min/Max
###    =3 : Min/Max + 3x3 kernel
###
###
###
### +---------+
### | SPECIAL |
### +---------+
###
### preblur [string: "ON","OFF",...]
### --------------------------------
### Mode to avoid noise sharpening & ringing (only used in Smode=3,4,5,6)
### "ON" is sufficient to prevent ringing, but to prevent noise sharpening you should set your own denoiser
###    Usage:   LSFmod(preblur="YourFavoriteDenoiser()")
###    Example: LSFmod(preblur="FFT3Dfilter(sigma=4,plane=0)")
###
###
### secure [bool]
### -------------
### Mode to avoid banding & oil painting (or face wax) effect of sharpening
### (only used in Smode=3,4,5,6)
###
### source [clip]
### -------------
### If source is defined, LSFmod doesn't sharp more a denoised clip than this source clip
### In this mode, you can safely set Lmode=0 & PP=off
###    Usage:   denoised.LSFmod(source=source)
###    Example: last.FFT3Dfilter().LSFmod(source=last,Lmode=0,soft=0)
###
###
###
### +----------------------+
### | NONLINEAR SHARPENING |
### +----------------------+
###
### Szrp [int]
### ----------
### Zero Point:
###    - differences below Szrp are amplified (overdrive sharpening)
###    - differences above Szrp are reduced   (reduced sharpening)
###
### Spwr [int]
### ----------
### Power: exponent for sharpener
###
### SdmpLo [int]
### ------------
### Damp Low: reduce sharpening for small changes [0:disable]
###
### SdmpHi [int]
### ------------
### Damp High: reduce sharpening for big changes [0:disable]
###
###
###
### +----------+
### | LIMITING |
### +----------+
###
### Lmode [int: ...,0,1,2,3,4,5,6]
### --------------------------
### Limit mode:
###    <0 : Limit with repair (ex: Lmode=-1 --> repair(1), Lmode=-5 --> repair(5)...)
###    =0 : No limit
###    =1 : 3x3 spatial limit to over/undershoot
###    =2 : 3x3 spatial limit to over/undershoot on edges and no limit on not-edges
###    =3 : 3x3 spatial limit to zero on edges and to over/undershoot on not-edges
###    =4 : 3x3 spatial limit to over/undershoot on edges and to over/undershoot2 on not-edges
###    =5 : 3x3 spatial limit to over/undershoot on edges and to zero             on not-edges
###    =6 : Temporal    limit to over/undershoot on edges and to zero             on not-edges
###
### overshoot [int]
### ---------------
### Limit for pixels that get brighter during sharpening
###
### undershoot [int]
### ----------------
### Limit for pixels that get darker during sharpening
###
### overshoot2 [int]
### ----------------
### Same as overshoot, only for Lmode=4
###
### undershoot2 [int]
### -----------------
### Same as undershoot, only for Lmode=4
###
###
###
### +-----------------+
### | POST-PROCESSING |
### +-----------------+
###
### soft [int: -2,-1,0...100]
### -------------------------
### Soft the sharpening effect (-1 = old autocalculate, -2 = new autocalculate)
###
### soothe [bool]
### -------------
###    =true  : Enable soothe temporal stabilization
###    =false : Disable soothe temporal stabilization
###
### keep [int: 0...100]
### -------------------
### Minimum percent of the original sharpening to keep (only with soothe=true)
###
###
###
### +-------+
### | EDGES |
### +-------+
###
### edgemode [int: -1,0,1,2]
### ------------------------
###    =-1 : Show edgemask
###    = 0 : Sharpening all
###    = 1 : Sharpening only edges
###    = 2 : Sharpening only not-edges
###
### edgemaskHQ [bool]
### -----------------
###    =true  : Original edgemask
###    =false : Faster edgemask
###
###
###
### +------------+
### | UPSAMPLING |
### +------------+
###
### ss_x ; ss_y [float]
### -------------------
### Supersampling factor (reduce aliasing on edges)
###
### dest_x ; dest_y [int]
### ---------------------
### Output resolution after sharpening (avoid a resizing step)
###
###
###
### +-------+
### | DEBUG |
### +-------+
###
### show [bool]
### -----------
### Show debug clip & informations
###
### screenW ; screenH [int]
### -----------------------
### Screen resolution (for show clip)
###
###
###
### +----------+
### | SETTINGS |
### +----------+
###
### preset [string: "old" or "slow" or "mid" or "fast"]
### --------------------------------------------
###    = "old"  : Reset settings to original version (output will be THE SAME AS LSF)
###    = "slow" : Enable SLOW   modded version settings
###    = "mid"  : Enable MEDIUM modded version settings
###    = "fast" : Enable FAST   modded version settings
###  --> /!\ [preset:"mid"]
###
###
### preset="old"   :  - strength    = 100
### ----------------  - Smode       = 3
###                   - Smethod     = Smode==3 ? 2 : 1
###
###                   - preblur     = "OFF"
###                   - secure      = false
###                   - source      = undefined
###
###                   - Szrp        = 16
###                   - Spwr        = 2
###                   - SdmpLo      = strength/25
###                   - SdmpHi      = 0
###
###                   - Lmode       = 1
###                   - overshoot   = 1
###                   - undershoot  = overshoot
###                   - overshoot2  = overshoot*2
###                   - undershoot2 = overshoot2
###
###                   - soft        = 0
###                   - soothe      = false
###                   - keep        = 25
###
###                   - edgemode    = 0
###                   - edgemaskHQ  = true
###
###                   - ss_x        = Smode==3 ? 1.50 : 1.25
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1920
###                   - screenH     = 1080
###
###
### preset="slow"   : - strength    = 100
### ----------------- - Smode       = 5
###                   - Smethod     = 3
###
###                   - preblur     = "OFF"
###                   - secure      = true
###                   - source      = undefined
###
###                   - Szrp        = 16
###                   - Spwr        = 4
###                   - SdmpLo      = 4
###                   - SdmpHi      = 48
###
###                   - Lmode       = 4
###                   - overshoot   = strength/100
###                   - undershoot  = overshoot
###                   - overshoot2  = overshoot*2
###                   - undershoot2 = overshoot2
###
###                   - soft        = -2
###                   - soothe      = true
###                   - keep        = 20
###
###                   - edgemode    = 0
###                   - edgemaskHQ  = true
###
###                   - ss_x        = Smode==3 ? 1.00 : 1.50
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1920
###                   - screenH     = 1080
###
###
### preset="fast"   : - strength    = 100
### ----------------- - Smode       = 3
###                   - Smethod     = 2
###
###                   - preblur     = "OFF"
###                   - secure      = true
###                   - source      = undefined
###
###                   - Szrp        = 16
###                   - Spwr        = 4
###                   - SdmpLo      = 4
###                   - SdmpHi      = 48
###
###                   - Lmode       = 1
###                   - overshoot   = strength/100
###                   - undershoot  = overshoot
###                   - overshoot2  = overshoot*2
###                   - undershoot2 = overshoot2
###
###                   - soft        = 0
###                   - soothe      = true
###                   - keep        = 20
###
###                   - edgemode    = 0
###                   - edgemaskHQ  = false
###
###                   - ss_x        = Smode==3 ? 1.00 : 1.25
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1920
###                   - screenH     = 1080
###
################################################################################################

function LSFmod( clip inclip, float "strength", int "Smode", int "Smethod",
\                string "preblur", bool "secure", clip "source",
\                int "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
\                int "Lmode", int "Lrad", float "overshoot", float "undershoot", float "overshoot2", float "undershoot2",
\                int "soft", bool "soothe", int "keep",
\                int "edgemode", bool "edgemaskHQ",
\                float "ss_x", float "ss_y", int "dest_x", int "dest_y",
\                bool "show", int "screenW", int "screenH",
\                string "preset", string "tv_range", bool "fulls" ) {


    ### PRESETS
    version = "v3.7mix"
    preset  = Default(preset,"mid")
    num     = preset=="old" ? 0 : preset=="slow" ? 1 : preset=="mid" || preset=="medium" ? 2 : preset=="fast" ? 3 : 4

    ox   = inclip.width()
    oy   = inclip.height()
    isHD = (ox > 1099 ||  oy > 599)
    bi   = BitsPerComponent(inclip)
    fs   = Default(fulls,   false)
    tv   = Default(tv_range, true)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    Assert(num != 4, chr(10) + """Preset must be "old", "slow", "mid" or "fast" !""" + chr(10))

    #                                                                           OLD                  SLOW                 MEDIUM                  FAST
    strength    = Default( strength,    Select(num,                              100.,                100.,                100.,                100.) )
    Smode       = Default( Smode,       Select(num,                                3 ,                  5 ,                  4 ,                  3 ) )
    Smethod     = Default( Smethod,     Select(num,                     Smode==3?2:1 ,                  3 ,                  3 ,                  2 ) )

    preblur     = Default( preblur,     Select(num,                            "OFF" ,              "OFF" ,              "OFF" ,              "OFF" ) )
    secure      = Default( secure,      Select(num,                            false ,               true ,               true ,                true ) )

    Szrp        = Default( Szrp,        Select(num,                               16 ,                 16 ,                 16 ,                 16 ) )
    Spwr        = Default( Spwr,        Select(num,                                2 ,                  4 ,                  4 ,                  4 ) )
    SdmpLo      = Default( SdmpLo,      Select(num,                      strength/25 ,                  4 ,                  4 ,                  4 ) )
    SdmpHi      = Default( SdmpHi,      Select(num,                                0 ,                 48 ,                 48 ,                 48 ) )

    Lmode       = Default( Lmode,       Select(num,                                1 ,                  4 ,                  4 ,                  1 ) )
    Lrad        = Default( Lrad,        Select(num,                                1 ,                  1 ,                  1 ,                  1 ) )
    overshoot   = Default( overshoot,   Select(num,                                1 ,       strength/100 ,       strength/100 ,       strength/100 ) )
    undershoot  = Default( undershoot,  Select(num,                        overshoot ,          overshoot ,          overshoot ,          overshoot ) )
    overshoot2  = Default( overshoot2,  Select(num,                      overshoot*2 ,        overshoot*2 ,        overshoot*2 ,        overshoot*2 ) )
    undershoot2 = Default( undershoot2, Select(num,                       overshoot2 ,         overshoot2 ,         overshoot2 ,         overshoot2 ) )

    soft        = Default( soft,        Select(num,                                0 ,                 -2 ,                 -2 ,                  0 ) )
    soothe      = Default( soothe,      Select(num,                            false ,               true ,               true ,                true ) )
    keep        = Default( keep,        Select(num,                               25 ,                 20 ,                 20 ,                 20 ) )

    edgemode    = Default( edgemode,    Select(num,                                0 ,                  0 ,                  0 ,                  0 ) )
    edgemaskHQ  = Default( edgemaskHQ,  Select(num,                             true ,               true ,               true ,               false ) )

    ss_x        = Default( ss_x,        Select(num, Smode==6?1.00:Smode==3?1.50:1.25 , Smode==3?1.00:1.50 , Smode==3?1.00:1.25 , Smode==3?1.00:1.25 ) )
    ss_y        = Default( ss_y,        Select(num,                             ss_x ,               ss_x ,               ss_x ,               ss_x ) )
    dest_x      = Default( dest_x,      Select(num,                               ox ,                 ox ,                 ox ,                 ox ) )
    dest_y      = Default( dest_y,      Select(num,                               oy ,                 oy ,                 oy ,                 oy ) )

    show        = Default( show,        Select(num,                            false ,              false ,              false ,               false ) )
    screenW     = Default( screenW,     Select(num,                             1920 ,               1920 ,               1920 ,               1920 ) )
    screenH     = Default( screenH,     Select(num,                             1080 ,               1080 ,               1080 ,               1080 ) )

    Assert(!isYUY2(inclip), chr(10) + "LSFmod: Unsupported format: YUY2" + chr(10))
    Assert(!isRGB(inclip),  chr(10) + "LSFmod: Unsupported format: RGB"  + chr(10))
    Assert( ( strength >= 0 )                                            , chr(10) + "'strength' have not a correct value! [>=0]"              + chr(10))
    Assert( ( Smode >= 1 && Smode <= 6 )                                 , chr(10) + "'Smode' have not a correct value! [1,2,3,4,5,6]"         + chr(10))
    Assert( ( Smethod >= 1 && Smethod <= 4 )                             , chr(10) + "'Smethod' have not a correct value! [1,2,3,4]"           + chr(10))
    Assert( ( Szrp >= 1 && Szrp <= 255 )                                 , chr(10) + "'Szrp' have not a correct value! [1...255]"              + chr(10))
    Assert( ( Spwr >= 1 )                                                , chr(10) + "'Spwr' have not a correct value! [>=1]"                  + chr(10))
    Assert( ( SdmpLo >= 0 && SdmpLo <= 255 )                             , chr(10) + "'SdmpLo' have not a correct value! [0...255]"            + chr(10))
    Assert( ( SdmpHi >= 0 && SdmpHi <= 255 )                             , chr(10) + "'SdmpHi' have not a correct value! [0...255]"            + chr(10))
    Assert( ( Lmode <= 6 )                                               , chr(10) + "'Lmode' have not a correct value! [...-1,0,1,2,3,4,5,6]" + chr(10))
    Assert( ( overshoot >= 0 && overshoot <= 255 )                       , chr(10) + "'overshoot' have not a correct value! [0...255]"         + chr(10))
    Assert( ( undershoot >= 0 && undershoot <= 255 )                     , chr(10) + "'undershoot' have not a correct value! [0...255]"        + chr(10))
    Assert( ( overshoot2 >= 0 && overshoot2 <= 255 )                     , chr(10) + "'overshoot2' have not a correct value! [0...255]"        + chr(10))
    Assert( ( undershoot2 >= 0 && undershoot2 <= 255 )                   , chr(10) + "'undershoot2' have not a correct value! [0...255]"       + chr(10))
    Assert( ( soft >= -2 && soft <= 100 )                                , chr(10) + "'soft' have not a correct value! [-2,-1,0,1...100]"      + chr(10))
    Assert( ( keep >= 0 && keep <= 100 )                                 , chr(10) + "'keep' have not a correct value! [0...100]"              + chr(10))
    Assert( ( edgemode >= -1 && edgemode <= 2 )                          , chr(10) + "'edgemode' have not a correct value! [-1,0,1,2]"         + chr(10))
    Assert( ( ss_x >= 1.0 )                                              , chr(10) + "'ss_x' have not a correct value! [>=1.0]"                + chr(10))
    Assert( ( ss_y >= 1.0 )                                              , chr(10) + "'ss_y' have not a correct value! [>=1.0]"                + chr(10))

    soft = soft!=-1  ? soft : sqrt( (((ss_x+ss_y)/2.0-1.0)*100.0) ) * 10
    soft = soft!=-2  ? soft : int( (1.0+(2.0/(ss_x+ss_y))) * sqrt(strength) )
    soft = soft<=100 ? soft : 100

    xxs  = nmod(ox*ss_x,8)
    yys  = nmod(oy*ss_y,8)

    str  = strength / 100.

    sisupscale  = (dest_x != ox || dest_y != oy)

    sislumaonly = inclip.isy()

    input = sisupscale || sislumaonly ? inclip : inclip.ExtractY()

    sode  = Defined(source)

    source = sode ? sisupscale || sislumaonly ? source : source.ExtractY() : source


    ### SHARP (preblur="ON" looks like a mini MinBlur() )
    tmp  = ss_x > 1.0 || ss_y > 1.0 ? input.spline36resize(xxs,yys) : input
    pre  = preblur=="OFF" ? tmp
    \    : preblur=="ON"  ? tmp.ex_lutxyz(ex_makediff(tmp,tmp.removegrain(12,-1), UV=1, fulls=fs)
    \                                    ,ex_makediff(tmp,tmp.removegrain(4, -1), UV=1, fulls=fs),"y range_half - A@ z range_half - B@ * 0 < x A abs B abs < A B ? x swap - ?", UV=1, fulls=fs)
    \    : Eval("tmp."+preblur)


    # Top is a 4-way sobel, Bottom a min/max
    rhlf  = ex_bs(128, 8, bi, fulls=fs)
    emHQn = ex_bs(32,  8, bi, fulls=fs)
    edge  = edgemaskHQ ? tmp.ex_edge(mode=Format("x[-1,1] A@ x[0,1] 2 * B@ x[1,1] C@ + + x[-1,-1] F@ - x[0,-1] 2 * G@ - x[1,-1] H@ - F G H + + A - B - C - max "                    \
                                                +"A C - x[-1,0] 2 * D@ + x[1,0] 2 * E@ - F + H - C A - D - E + F - H + max max 2 * 1 {rhlf} / * 0.86 ^ 0 max range_max *"),  lo=0, hi=255, UV=1, fulls=fs)
    \     :              tmp.ex_edge(mode=Format("x[1,1] A@ x[1,0] B@ max x[1,-1] C@ max x[-1,1] D@ max x[-1,0] E@ max x[-1,-1] F@ max x[0,1] G@ max x[0,-1] H@ max x[0,0] O@ max " \
                                                +"A B min C min G min O min H min D min E min F min - 1 {emHQn} / * 0.86 ^ 0 max range_max *"),                              lo=0, hi=255, UV=1, fulls=fs)

    edgei = edge.mt_inflate()

    dark_limit    = pre.mt_inpand()
    dark_limit2   = pre.ex_inpand(2,mode="circle")   # for HD or ss_x >= 1.5 (Optional)
    bright_limit  = pre.mt_expand()
    bright_limit2 = pre.ex_expand(2,mode="circle")   # for HD or ss_x >= 1.5 (Optional)
    minmaxavg     = Merge(dark_limit, bright_limit, 0.5)
    minmaxavg2    = Merge(dark_limit2,bright_limit2,0.5)
    minmaxavg     = Lrad == 1 ? minmaxavg : mt_merge(minmaxavg,minmaxavg2,edgei)

    method = Smethod==1   ? isHD ?       pre.removegrain(12,-1).removegrain(20,-1) :       pre.removegrain(12,-1)
    \      : Smethod==2   ? minmaxavg
    \      :                isHD ? minmaxavg.removegrain(12,-1).removegrain(20,-1) : minmaxavg.removegrain(12,-1)

    sec    = ex_bs(tv ? 0.51 : 0.594, 8, bi, fulls=fs)
    secstr = Format("x y < x {sec} + x y > x {sec} - x ? ?")  # "x y x 2 + min y x 2 - max clip" or "y x 2 + min x 2 - max " # faster but 95% not 100% match (replicates ex_clamp() )
    method = secure ? method.ex_lutxy(pre,secstr, UV=1, fulls=fs)
    \      :          method

    method = preblur=="OFF" ? method : tmp.ex_lutxyz(pre,method,"x y z - range_half + - range_half +", UV=1, fulls=fs)

    Szrp      = ex_bs(Szrp,   8, bi, tv_in=true, tv_out=tv,  fulls=fs)
    SdmpLo    = ex_bs(SdmpLo, 8, bi, tv_in=true, tv_out=tv,  fulls=fs)
    SdmpHi    = ex_bs(SdmpHi, 8, bi, tv_in=true, tv_out=tv,  fulls=fs)
    SdmpHs    = SdmpHi == 0 ? "0" : Format("     B 1 {SdmpHi} / * 4 ^")
    SdmpHr    = SdmpHi == 0 ? "0" : Format("{Szrp} 1 {SdmpHi} / * 4 ^")

    normsharp = Smode==1 ? tmp.UnsharpMask_HBD(strength=str*150,radius=round(1.0+((ss_x+ss_y)/2.0)),threshold=0,UV=1,fulls=fs)
    \         : Smode==2 ? tmp.UnsharpMask_HBD(strength=str*150,radius=round(1.0+((ss_x+ss_y)/2.0)),threshold=0,UV=1,fulls=fs)
    \         : Smode==3 ? ex_lutxy(tmp, method, Format("x y - {str} * x +"), UV=1, fulls=fs)
    \         : Smode==4 ? ex_lutxy(tmp, method, Format("x y == x dup y - A@ abs B@ 1 {Szrp} / * 1 {Spwr} / ^ {Szrp} {str} * * A dup * dup "
    \                                                  +"{SdmpLo} scalef + / * A B / * 1 "+SdmpHs+" + / x + ?"), UV=1, fulls=fs)
    \         : Smode==5 ? ex_lutxy(tmp, method, Format("x y == x dup y - A@ abs B@ 1 {Szrp} / * 1 {Spwr} / ^ {Szrp} {str} * * A B / * A dup * C@ "
    \                                                  +"{Szrp} dup * {SdmpLo} scalef + * C {SdmpLo} scalef + {Szrp} dup * * / * 1 "+SdmpHr+" + 1 "+SdmpHs+" + / * x + ?"), UV=1, fulls=fs)
    \         : preblur!="OFF" && secure ? tmp.ex_lutxyz(pre,pre.CAS(min(Str, 1)).ex_lutxy(pre,secstr, UV=1, fulls=fs), "x y z - range_half + - range_half +", UV=1, fulls=fs)
    \         : preblur!="OFF"           ? tmp.ex_lutxyz(pre,pre.CAS(min(Str, 1)), "x y z - range_half + - range_half +", UV=1, fulls=fs) : secure ? pre.CAS(min(Str, 1)).ex_lutxy(pre,secstr, UV=1, fulls=fs) : pre.CAS(min(Str, 1))

    # Temporal limiting
    if (Lmode==6) {

        isg = Eval("try { cb1.isclip() && cf1.isclip() } catch(error_msg) { false }") # if Lmode=6; reuse MAnalyze'd global vectors if exist (and SS is not used) otherwise create them ourselves.

        if (!isg || (ss_x > 1.0 || ss_y > 1.0)) {

            blcksze   = (ox > 2599 ||  oy > 1499) ? 32 : isHD ? 16 : 8
            scaleCSAD = isHD ?   1 : 0

            pre       = pre.ConvertBits(8, dither=-1, fulls=fs)
            superfilt = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, chroma=true, mt=true)   # bug can't disable chroma otherwise luma isn't processed
            super     = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, chroma=true, mt=true, levels=1)

            cb1 = superfilt.MAnalyse(isb = false, chroma=true, blksize = blcksze,  overlap=blcksze/2, delta = 1, temporal=true,       truemotion=true, mt=true)
            cf1 = superfilt.MAnalyse(isb = true,  chroma=true, blksize = blcksze,  overlap=blcksze/2, delta = 1, temporal=true,       truemotion=true, mt=true)
            cb1 =     super.Mrecalculate(cb1,     chroma=true, blksize = blcksze/2, overlap=blcksze/4, thSAD=110, scaleCSAD=scaleCSAD, truemotion=true, mt=true)
            cf1 =     super.Mrecalculate(cf1,     chroma=true, blksize = blcksze/2, overlap=blcksze/4, thSAD=110, scaleCSAD=scaleCSAD, truemotion=true, mt=true)
        }

        cb1     = repair(pre.MCompensate(super, cb1, thSAD=220, mt=true), pre, 3, -1).ConvertBits(bi, fulls=fs)
        cf1     = repair(pre.MCompensate(super, cf1, thSAD=220, mt=true), pre, 3, -1).ConvertBits(bi, fulls=fs)
        os      = ex_bs(overshoot,   8, bi, fulls=fs)      us     = ex_bs(undershoot,  8, bi, fulls=fs)
        os      = os  == 0 ? "" : Format("{os}  +")        us     = us  == 0 ? "" : Format("{us}  -")
        normalT = ex_lutxyza(tmp,normsharp,cb1,cf1,Format("y x z max a max "+os+" min x z min a min "+us+" max"),UV=1)
    }

    ### LIMIT
    os10    = overshoot  == 0 && undershoot  == 0
    os20    = overshoot2 == 0 && undershoot2 == 0
    zero    =                ex_clamp(normsharp, bright_limit,  dark_limit,                  0,                  0, UV=1, fulls=fs)
    zero2   =                ex_clamp(normsharp, bright_limit2, dark_limit2,                 0,                  0, UV=1, fulls=fs)
    second  = os20 ? zero  : ex_clamp(normsharp, bright_limit,  dark_limit,  round(overshoot2), round(undershoot2), UV=1, fulls=fs)
    second2 = os20 ? zero2 : ex_clamp(normsharp, bright_limit2, dark_limit2, round(overshoot2), round(undershoot2), UV=1, fulls=fs)
    normal  = os10 ? zero  : ex_clamp(normsharp, bright_limit,  dark_limit,  round(overshoot),  round(undershoot),  UV=1, fulls=fs)
    normal2 = os10 ? zero2 : ex_clamp(normsharp, bright_limit2, dark_limit2, round(overshoot),  round(undershoot),  UV=1, fulls=fs)


    # really like Lmode=5 and 6
    limit1 = Lmode <0 ? normsharp.repair(isHD ? normsharp.repair(tmp,abs(Lmode),-1) : tmp, abs(Lmode),-1)
    \      : Lmode==0 ? normsharp
    \      : Lmode==1 ? normal
    \      : Lmode==2 ?                          Lrad ==1 ? mt_merge(normsharp, normal,  edgei) : mt_merge(normsharp, normal2,  edgei)
    \      : Lmode==3 ? os10         ? zero    : Lrad ==1 ? mt_merge(normal,    zero,    edgei) : mt_merge(normal,    zero2,    edgei)
    \      : Lmode==4 ? os10 && os20 ? zero    : Lrad ==1 ? mt_merge(second,    normal,  edgei) : mt_merge(second,    normal2,  edgei)
    \      : Lmode==5 ? os10         ? zero    : Lrad ==1 ? mt_merge(zero,      normal,  edgei) : mt_merge(zero,      normal2,  edgei)
    \      :                                                mt_merge(zero,      normalT, edgei)


    limit2 = edgemode==0 ? limit1
    \      : edgemode==1 ? mt_merge(tmp,limit1,edgei.mt_inflate().removegrain(12,-1))
    \      :               mt_merge(limit1,tmp,edgei.mt_inflate().removegrain(12,-1))


    ### SOFT
    sharpdiff = ex_makediff(tmp,limit2, UV=1, fulls=fs)
    sharpdiff = ex_lutxy(sharpdiff,sharpdiff.removegrain(20,-1), Format("x range_half - abs y range_half - abs > y {soft} * x 100 {soft} - * + 0.01 * x ?"), UV=1, fulls=fs)

    PP1 = soft==0 ? limit2 : ex_makediff(tmp,sharpdiff, UV=1, fulls=fs)


    ### SOOTHE
    diff  = ex_makediff(tmp, PP1, UV=1, fulls=fs)
    diff2 = diff.temporalsoften(1,255,0,32,2)
    diff3 = ex_lutxy(diff,diff2,Format("x range_half - A@ y range_half - B@ * 0 < A {keep} 0.01 * * range_half + A abs B abs > x {keep} * y 100 {keep} - * + 0.01 * x ? ?"), UV=1, fulls=fs)

    PP2 = soothe ? ex_makediff(tmp, diff3, UV=1, fulls=fs) : PP1


    ### OUTPUT
    out = sisupscale ?                PP2.spline36resize(dest_x, dest_y)
    \   : (ss_x > 1.0 || ss_y > 1.0)? PP2.spline36resize(dest_x, dest_y)
    \   :                             PP2

    ### CONTRA
    if (sode) {

        in  = sisupscale ?     input.spline36resize(dest_x, dest_y) : input
        no  =              normsharp.spline36resize(dest_x, dest_y)
        src = sisupscale ?    source.spline36resize(dest_x, dest_y) : source

        srcD   = ex_makediff(in, src, UV=1, fulls=fs)
        shrpD  = ex_makediff(in, no,  UV=1, fulls=fs)
        srcDP  =  srcD.PadBorders(4,4,4,4)
        shrpDP = shrpD.PadBorders(4,4,4,4)
        shrpL  = shrpDP.repair(isHD?shrpDP.repair(srcDP,max(abs(Lmode),1),-1):srcDP,max(abs(Lmode),1),-1).crop(4,4,-4,-4,true)
        out    = ex_lutxyz(in,shrpL,shrpD, "y range_half - X@ abs z range_half - Y@ abs < X Y ? x swap -", UV=1, fulls=fs)
    }

    output = edgemode!=-1 ? out : !sisupscale ? edge.spline36resize(dest_x,dest_y) : edge.spline36resize(dest_x,dest_y).greyscale()


    ### SHOW
       function LSFM_Show(clip input, clip output, string "version", string "preset",
       \                  float "strength", int "Smode", int "Smethod",
       \                  string "preblur", bool "secure", string "source",
       \                  float "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
       \                  int "Lmode", float "overshoot", float "undershoot", float "overshoot2", int "undershoot2",
       \                  int "soft", bool "soothe", int "keep",
       \                  int "edgemode", bool "edgemaskHQ",
       \                  float "ss_x", float "ss_y", int "dest_x", int "dest_y",
       \                  bool "show", int "screenW", int "screenH")
       {
       resoW = screenW - 384
       resoH = screenH

       inW   = input.width()
       inH   = input.height()
       outW  = nmod( resoW , 4)
       outH  = round( (outW * inH) / (4 * inW) ) * 4
       scale = resoH - ( 2 * outH )

       i = input.spline36resize(outW,outH)
       i = scale > 0 ? i.addborders(0,scale/4,0,scale/4) : i
       i = scale < 0 ? i.crop(0,-scale/4,0,scale/4,true) : i

       o = output.spline36resize(outW,outH)
       o = scale > 0 ? o.addborders(0,scale/4,0,scale/4) : o
       o = scale < 0 ? o.crop(0,-scale/4,0,scale/4,true) : o

       e =  blankclip(input, width=384, height=resoH)
       e = e.SubTitle("LSFmod " + string(version)                ,text_color=$FFFFFF,font="COURIER NEW",size=24,x=40,y=40)
       e = e.SubTitle("PRESET        = " + string(preset)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=100)

       e = e.SubTitle("GENERAL:"                                 ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=150)
       e = e.SubTitle("--------"                                 ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=160)
       e = e.SubTitle("strength      = " + string(strength)      ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=180)
       e = e.SubTitle("Smode         = " + string(Smode)         ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=190)
       e = e.SubTitle("Smethod       = " + string(Smethod)       ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=200)

       e = e.SubTitle("SPECIAL:"                                 ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=250)
       e = e.SubTitle("--------"                                 ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=260)
       e = e.SubTitle("preblur       = " + string(preblur)       ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=280)
       e = e.SubTitle("secure        = " + string(secure)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=290)
       e = e.SubTitle("source        = " + string(source)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=300)

       e = e.SubTitle("NONLINEAR SHARPENING:"                    ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=340)
       e = e.SubTitle("---------------------"                    ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=350)
       e = e.SubTitle("Szrp          = " + string(Szrp)          ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=370)
       e = e.SubTitle("Spwr          = " + string(Spwr)          ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=380)
       e = e.SubTitle("SdmpLo        = " + string(SdmpLo)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=390)
       e = e.SubTitle("SdmpHi        = " + string(SdmpHi)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=400)

       e = e.SubTitle("LIMITING:"                                ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=440)
       e = e.SubTitle("---------"                                ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=450)
       e = e.SubTitle("Lmode         = " + string(Lmode)         ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=470)
       e = e.SubTitle("overshoot     = " + string(overshoot)     ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=480)
       e = e.SubTitle("undershoot    = " + string(undershoot)    ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=490)
       e = e.SubTitle("overshoot2    = " + string(overshoot2)    ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=500)
       e = e.SubTitle("undershoot2   = " + string(undershoot2)   ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=510)

       e = e.SubTitle("POST-PROCESSING:"                         ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=550)
       e = e.SubTitle("----------------"                         ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=560)
       e = e.SubTitle("soft          = " + string(soft)          ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=580)
       e = e.SubTitle("soothe        = " + string(soothe)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=590)
       e = e.SubTitle("keep          = " + string(keep)          ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=600)

       e = e.SubTitle("EDGES:"                                   ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=640)
       e = e.SubTitle("------"                                   ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=650)
       e = e.SubTitle("edgemode      = " + string(edgemode)      ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=670)
       e = e.SubTitle("edgemaskHQ    = " + string(edgemaskHQ)    ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=680)

       e = e.SubTitle("UPSAMPLING:"                              ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=720)
       e = e.SubTitle("-----------"                              ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=730)
       e = e.SubTitle("ss_x          = " + string(ss_x)          ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=750)
       e = e.SubTitle("ss_y          = " + string(ss_y)          ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=760)
       e = e.SubTitle("dest_x        = " + string(dest_x)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=770)
       e = e.SubTitle("dest_y        = " + string(dest_y)        ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=780)

       e = e.SubTitle("DEBUG:"                                   ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=820)
       e = e.SubTitle("------"                                   ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=830)
       e = e.SubTitle("show          = " + string(show)          ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=850)
       e = e.SubTitle("screenW       = " + string(screenW)       ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=860)
       e = e.SubTitle("screenH       = " + string(screenH)       ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=870)

       debug = stackhorizontal( e ,
       \                        stackvertical( i.subtitle("Input" ,text_color=$FFFFFF,size=20,x=40,y=20) ,
       \                                       o.subtitle("Output",text_color=$FFFFFF,size=20,x=40,y=20) )
       \                      )

       return debug
       }

    output = sisupscale || sislumaonly ? output : CombinePlanes(output,inclip,planes="YUV",sample_clip=inclip)

    output = show==false ? output
    \                    : LSFM_Show(inclip, output, version, preset,
    \                                strength, Smode, Smethod,
    \                                preblur, secure, sode?"defined":"undefined",
    \                                Szrp, Spwr, SdmpLo, SdmpHi,
    \                                Lmode, overshoot, undershoot, overshoot2, undershoot2,
    \                                soft, soothe, keep,
    \                                edgemode, edgemaskHQ,
    \                                ss_x, ss_y, dest_x, dest_y,
    \                                show, screenW, screenH)

    return output }