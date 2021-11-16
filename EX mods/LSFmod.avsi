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
###                                v3.9 ex - 01 November 2021                                ###
###                                                                                          ###
################################################################################################
###
### +-----------+
### | CHANGELOG |
### +-----------+
###
### v3.9ex : - Add workaround for 32-bit float support since Expr() scaling is broken for this bitdepth
###          - Optimize Smode=4 and 5
###          - Disable Chroma for Lmode=6 (Temporal Limiting)
###          - Fix 'Show'
###
### v3.8ex : - Update Unsharp_HBD() with ex_unsharp() and reparametrize to original LSFmod unsharp's output
###          - Optimize Soft and Soothe expressions
###          - Optimize Sobel edgemask
###          - Replace CAS plugin dependency with ex_CAS()
###
### v3.7ex : - Rebase to latest ResizersPack
###          - Rebase "undot1" repair mode to latest ExTools
###          - Replace try+catch with VarExist()
###
### v3.6ex : - Add thSAD for MCompensate
###          - Fix ex_repair() calls
###          - Cosmetics
###
### v3.5ex : - Additional checker for creation of motion vectors if SS is used
###          - and repair its motion compensated vectors
###          - Cosmetics
###
### v3.4ex : - Lmode=5 for zero limiting on not-edges
###          - Lmode=6 is now temporal limiting
###          - Improved temporal limiting
###          - Improved 'source' contrasharpening (was mostly noop before)
###          - Lrad arg, for better edge sharpening, specially on HD (Default 1 -off-)
###          - Optimized limiting logic when overshoot and undershoot are 0
###
### v3.3ex : - Lmode=5 for temporal limiting
###          - Optimization for mt_inflate()
###
### v3.2ex : - Expressions optimizations
###          - New preset 'mid'
###          - Make 'mid' the new default preset
###
### v3.1ex : - Rebase to latest ExTools for ex_bs()
###
### v3.0ex : - Optimizations
###
### v2.9ex : - Bugfix for HBD
###
### v2.8ex : - Rebase to latest ExTools for ex_bs()
###
### v2.7ex : - Revert to removegrain(20) (mathematically correct)
###          - Add internal HD mode
###          - Rebase to latest ExTools
###
### v2.6ex : - Expressions cleanup
###          - Rebase to latest ExTools
###
### v2.5ex : - Expressions optimizations
### v2.4ex : - Expressions fixes and optimizations
### v2.3ex : - Expressions optimizations
###
### v2.2ex : - "fulls" argument
###          - Rebasing with latest ExTools
###          - Removed old checks (YUY2 and old AVS support)
###          - Expression optimizations
###          - Default is now "slow"
###
### v2.193ex:- Removed < AviSynth+ 3.5 support
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
### -> ExTools        (v6.7 or up)
### -> ResizersPack   (v6.1 or up)
### -> SharpenersPack (v2.4 or up)     [for Smode=1, Smode=2 and Smode=6]
### -> if you use AviSynth+ then make sure it's the latest one
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
###    =true  : Enable  soothe temporal stabilization
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
### preset="medium" : - strength    = 100
### ----------------- - Smode       = 4
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
###                   - soft        = 0
###                   - soothe      = true
###                   - keep        = 20
###
###                   - edgemode    = 0
###                   - edgemaskHQ  = true
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
    version = "v3.9ex"
    preset  = Default(preset,"mid")
    num     = preset=="old" ? 0 : preset=="slow" ? 1 : preset=="mid" || preset=="medium" ? 2 : preset=="fast" ? 3 : 4

    ox   = inclip.width()
    oy   = inclip.height()
    isHD = (ox > 1099 ||  oy > 599)
    bi   = BitsPerComponent(inclip)
    fs   = Default(fulls,   false)
    tv   = Default(tv_range, true)

    Assert(IsVersionOrGreater(3,7,1), "Update AviSynth+ version")
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

    soft        = Default( soft,        Select(num,                                0 ,                 -2 ,                  0 ,                  0 ) )
    soothe      = Default( soothe,      Select(num,                            false ,               true ,               true ,                true ) )
    keep        = Default( keep,        Select(num,                               25 ,                 20 ,                 20 ,                 20 ) )

    edgemode    = Default( edgemode,    Select(num,                                0 ,                  0 ,                  0 ,                  0 ) )
    edgemaskHQ  = Default( edgemaskHQ,  Select(num,                             true ,               true ,               true ,               false ) )

    ss_x        = Default( ss_x,        Select(num,    Smode==6?1.:Smode==3?1.5:1.25 ,    Smode==3?1.:1.5 ,   Smode==3?1.:1.25 ,   Smode==3?1.:1.25 ) )
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

    xxs  = nmod(ox*ss_x,8)
    yys  = nmod(oy*ss_y,8)

    bi32m = bi != 32 ? "range_half -" : ""  # due to float scaling not being supported in Expr() (https://forum.doom9.org/showthread.php?p=1954164#post1954164)
    bi32p = bi != 32 ? "range_half +" : ""  # due to float scaling not being supported in Expr() (https://forum.doom9.org/showthread.php?p=1954164#post1954164)

    str  = strength / 100.

    sisupscale  = (dest_x != ox || dest_y != oy)

    sislumaonly = inclip.isy()

    input = sisupscale || sislumaonly ? inclip : inclip.ExtractY()

    sode  = Defined(source)

    source = sode ? sisupscale || sislumaonly ? source : source.ExtractY() : source


    ### PRE (preblur="ON" looks like a mini MinBlur() )
    tmp  = ss_x > 1.0 || ss_y > 1.0 ? input.spline36resize(xxs,yys) : input
    pre  = preblur=="OFF" ? tmp
    \    : preblur=="ON"  ? tmp.ex_lutxyz(ex_makediff(tmp,tmp.ex_boxblur(1,mode="weighted",UV=1), UV=1, fulls=fs)
    \                                    ,ex_makediff(tmp,tmp.ex_median("median",UV=1), UV=1, fulls=fs),"y "+bi32m+" A@ z "+bi32m+" B@ * 0 < x A abs B abs < A B ? x swap - ?", UV=1, fulls=fs)
    \    : Eval("tmp."+preblur)


    # Top is a 4-way sobel, Bottom a min/max
    rhlf  = Eval(ex_dlut("range_half", bi, fs))
    rhlf  = bi == 14 || bi == 16 ? Format("{rhlf} /") : string(1./rhlf)+" *"
    emHQn = 1. / ex_bs(32,  8, bi, fulls=fs)
    edge  = edgemaskHQ ? tmp.ex_edge(mode=Format("x[1,-1] C@ x[1,1] I@ + x[-1,-1] A@ - x[-1,1] G@ - x[1,0] x[-1,0] - 2 * + abs "                                                    \
                                                +"G I + A - C - x[0,1] x[0,-1] - 2 * + abs max 2 *     "+rhlf+" 0.86 ^ 0 max range_max *"), lo=0, hi=255, UV=1, fulls=fs)
    \     :              tmp.ex_edge(mode=Format("x[1,1] A@ x[1,0] B@ max x[1,-1] C@ max x[-1,1] D@ max x[-1,0] E@ max x[-1,-1] F@ max x[0,1] G@ max x[0,-1] H@ max x[0,0] O@ max " \
                                                +"A B min C min G min O min H min D min E min F min - {emHQn} * 0.86 ^ 0 max range_max *"), lo=0, hi=255, UV=1, fulls=fs)

    edgei  = edge.ex_inflate()

    dark_limit    = pre.ex_inpand()
    dark_limit2   = pre.ex_inpand(2,mode="circle")   # for HD or ss_x/y >= 1.5 (Optional)
    bright_limit  = pre.ex_expand()
    bright_limit2 = pre.ex_expand(2,mode="circle")   # for HD or ss_x/y >= 1.5 (Optional)
    minmaxavg     = Merge(dark_limit, bright_limit, 0.5)
    minmaxavg2    = Merge(dark_limit2,bright_limit2,0.5)
    minmaxavg     = Lrad == 1 ? minmaxavg : ex_merge(minmaxavg,minmaxavg2,edgei)

    method = Smethod==1   ? isHD ?       pre.ex_boxblur(3,mode="weighted",UV=1) :       pre.ex_boxblur(1,mode="weighted",UV=1)
    \      : Smethod==2   ? minmaxavg
    \      :                isHD ? minmaxavg.ex_boxblur(3,mode="weighted",UV=1) : minmaxavg.ex_boxblur(1,mode="weighted",UV=1)

    sec    = ex_bs(tv ? 0.51 : 0.594, 8, bi, fulls=fs)
    secstr = Format("x y < x {sec} + x y > x {sec} - x ? ?")  # "x y x 2 + min y x 2 - max clip" or "y x 2 + min x 2 - max " # faster but 95% not 100% match (replicates ex_clamp() )
    method = secure ? method.ex_lutxy(pre,secstr, UV=1, fulls=fs)
    \      :          method

    method = preblur=="OFF" ? method : tmp.ex_lutxyz(pre,method,"x y z - "+bi32p+" - "+bi32p, UV=1, fulls=fs)


    ### SHARP
    # Smode==1 Parametrized to original WarpSharp's    unsharpmask()
    # Smode==2 Parametrized to original VariableBlur's unsharp()
    Szrpv     =                         ex_bs(Szrp,    8, bi, tv_in=true, tv_out=tv,  fulls=fs)
    SdmpLov   =                         ex_bs(SdmpLo,  8, bi, tv_in=true, tv_out=tv,  fulls=fs)
    SdmpLov   =                         ex_bs(SdmpLoV, 8, bi, tv_in=true, tv_out=tv,  fulls=fs) # Yes, again
    SdmpHiv   = SdmpHi == 0 ?  0 : 1. / ex_bs(SdmpHi,  8, bi, tv_in=true, tv_out=tv,  fulls=fs)
    SdmpHr    = SdmpHi == 0 ? "" : Format("{Szrpv} {SdmpHiv} * 4 ^ 1 +  ")
    SdmpHs    = SdmpHi == 0 ? "" : Format("      B {SdmpHiv} * 4 ^ 1 + /")+(Smode==5 ? " *" : "")
    Szrpv2    = pow( Szrpv,2)
    Szrpr     = 1. / Szrpv
    Spwrr     = 1. / Spwr
    rad       = round((ss_x+ss_y)/2.)

    normsharp = Smode==1 ? tmp.ex_unsharp(str= 0.1+0.65*str-(rad/10.),Fc=max(ox,oy)*(1.2-0.2*(1+rad)),th=0,UV=1,fulls=fs)
    \         : Smode==2 ? tmp.ex_unsharp(str=          str/2.,       Fc=max(ox,oy)*(1.0-0.2*   rad), th=0,UV=1,fulls=fs)
    \         : Smode==3 ? ex_lutxy(tmp, method, Format("x y - {str} * x +"), UV=1, fulls=fs)
    \         : Smode==4 ? ex_lutxy(tmp, method, Format("x dup y == swap dup y - A@ dup 0 < -1 1 ? S^ abs B@ {Szrpr} * {Spwrr} ^ {Szrpv} {str} * * A dup * dup "
    \                                                  +"{SdmpLov} + / * S * "+SdmpHs+" x + ?"), UV=1, fulls=fs)
    \         : Smode==5 ? ex_lutxy(tmp, method, Format("x dup y == swap dup y - A@ dup 0 < -1 1 ? S^ abs B@ {Szrpr} * {Spwrr} ^ {Szrpv} {str} * * S * A dup * C@ "
    \                                                  +"{Szrpv2} {SdmpLov} + * C {SdmpLov} + {Szrpv2} * / * "+SdmpHr+" "+SdmpHs+" x + ?"), UV=1, fulls=fs)
    \         : preblur!="OFF" && secure ? tmp.ex_lutxyz(pre,pre.ex_CAS(min(Str, 1)).ex_lutxy(pre,secstr, UV=1, fulls=fs), "x y z - "+bi32p+" - "+bi32p, UV=1, fulls=fs)
    \         : preblur!="OFF"           ? tmp.ex_lutxyz(pre,pre.ex_CAS(min(Str, 1)), "x y z - "+bi32p+" - "+bi32p, UV=1, fulls=fs) : secure ? pre.ex_CAS(min(Str, 1)).ex_lutxy(pre,secstr, UV=1, fulls=fs) : pre.ex_CAS(min(Str, 1))


    # Temporal limiting
    if (Lmode==6) {

        isg = VarExist("cb1") && VarExist("cf1") # if Lmode=6; reuse MAnalyze'd global vectors if exist (and SS is not used) otherwise create them below

        if (!isg || (ss_x > 1.0 || ss_y > 1.0)) {

            blcksze   = (ox > 2599 ||  oy > 1499) ? 32 : isHD ? 16 : 8

            pre       = pre.ConvertBits(8, dither=-1, fulls=fs)
            superfilt = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, chroma=false, mt=true)
            super     = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, chroma=false, mt=true, levels=1)

            cb1 = superfilt.MAnalyse(isb = false, chroma=false, blksize = blcksze,   overlap=blcksze/2, delta = 1, temporal=true, truemotion=true, mt=true)
            cf1 = superfilt.MAnalyse(isb = true,  chroma=false, blksize = blcksze,   overlap=blcksze/2, delta = 1, temporal=true, truemotion=true, mt=true)
            cb1 =     super.Mrecalculate(cb1,     chroma=false, blksize = blcksze/2, overlap=blcksze/4, thSAD=110,                 truemotion=true, mt=true)
            cf1 =     super.Mrecalculate(cf1,     chroma=false, blksize = blcksze/2, overlap=blcksze/4, thSAD=110,                 truemotion=true, mt=true)
            }

        cb1     = ex_repair(pre.MCompensate(super, cb1, thSAD=220, mt=true), pre, "undot3", UV=1).ConvertBits(bi, fulls=fs)
        cf1     = ex_repair(pre.MCompensate(super, cf1, thSAD=220, mt=true), pre, "undot3", UV=1).ConvertBits(bi, fulls=fs)
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
    Lm     = string(abs(Lmode))
    limit1 = Lmode <0 ? normsharp.ex_repair(isHD ? normsharp.ex_repair(tmp,"undot"+Lm, UV=1) : tmp, "undot"+Lm, UV=1)
    \      : Lmode==0 ? normsharp
    \      : Lmode==1 ? normal
    \      : Lmode==2 ?                          Lrad ==1 ? ex_merge(normsharp, normal,  edgei) : ex_merge(normsharp, normal2,  edgei)
    \      : Lmode==3 ? os10         ? zero    : Lrad ==1 ? ex_merge(normal,    zero,    edgei) : ex_merge(normal,    zero2,    edgei)
    \      : Lmode==4 ? os10 && os20 ? zero    : Lrad ==1 ? ex_merge(second,    normal,  edgei) : ex_merge(second,    normal2,  edgei)
    \      : Lmode==5 ? os10         ? zero    : Lrad ==1 ? ex_merge(zero,      normal,  edgei) : ex_merge(zero,      normal2,  edgei)
    \      :                                                ex_merge(zero,      normalT, edgei)


    limit2 = edgemode==0 ? limit1
    \      : edgemode==1 ? ex_merge(tmp,limit1,edgei.ex_inflate().ex_boxblur(1,mode="weighted",UV=1), fulls=fs)
    \      :               ex_merge(limit1,tmp,edgei.ex_inflate().ex_boxblur(1,mode="weighted",UV=1), fulls=fs)


    ### SOFT
    soft = soft!=-1  ? soft : sqrt( (((ss_x+ss_y)/2.0-1.0)*100.0) ) * 10
    soft = soft!=-2  ? soft : int( (1.0+(2.0/(ss_x+ss_y))) * sqrt(strength) )
    soft = min(soft,100)
    sharpdiff = ex_makediff(tmp, limit2, UV=1, fulls=fs)
    sharpdiff = ex_lutxyz(tmp, sharpdiff, sharpdiff.removegrain(20,-1), Format("y "+bi32m+" abs z "+bi32m+" abs > z {soft} * y 100 {soft} - * + 0.01 * y ? x swap - "+bi32p), UV=1, fulls=fs)

    PP1 = soft==0 ? limit2 : sharpdiff


    ### SOOTHE
    diff  = ex_makediff(tmp, PP1, UV=1, fulls=fs)
    diff2 = diff.temporalsoften(1,255,0,32,2)
    diff3 = ex_lutxyz(tmp,diff,diff2,Format("y "+bi32m+" A@ z "+bi32m+" B@ * 0 < A {keep} 0.01 * * "+bi32p+" A abs B abs > y {keep} * z 100 {keep} - * + 0.01 * y ? ? x swap - "+bi32p), UV=1, fulls=fs)

    PP2 = soothe ? diff3 : PP1


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
        shrpL  = shrpDP.ex_repair(isHD?shrpDP.ex_repair(srcDP,"undot"+Lm,UV=1):srcDP,"undot"+Lm,UV=1).crop(4,4,-4,-4,true)
        out    = ex_lutxyz(in,shrpL,shrpD, "y "+bi32m+" X@ abs z "+bi32m+" Y@ abs < X Y ? x swap -", UV=1, fulls=fs)
    }

    output = edgemode!=-1 ? out : !sisupscale ? edge.spline36resize(dest_x,dest_y) : edge.spline36resize(dest_x,dest_y).greyscale()


    ### SHOW
       function LSFM_Show(clip input, clip output, string "version", string "preset",
       \                  float "strength", int "Smode", int "Smethod",
       \                  string "preblur", bool "secure", string "source",
       \                  float "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
       \                  int "Lmode", float "overshoot", float "undershoot", float "overshoot2", float "undershoot2",
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

       i =  input.spline36resize(outW,outH)
       i = scale > 0 ? i.addborders(0,scale/4,0,scale/4) : i
       i = scale < 0 ? i.crop(0,-scale/4,0,scale/4,true) : i

       o = output.spline36resize(outW,outH)
       o = scale > 0 ? o.addborders(0,scale/4,0,scale/4) : o
       o = scale < 0 ? o.crop(0,-scale/4,0,scale/4,true) : o

       e =  blankclip(input, width=384, height=resoH)
       e = e.SubTitle("LSFmod "          + string(version)             ,text_color=$FFFFFF,font="Verdana"    ,size=32,x=40,y=40 )
       e = e.SubTitle("PRESET        = " + string(preset)              ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=100)

       e = e.SubTitle("GENERAL:"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=150)
       e = e.SubTitle("--------"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=160)
       e = e.SubTitle("strength      = " + string(int(strength))       ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=180)
       e = e.SubTitle("Smode         = " + string(Smode)               ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=190)
       e = e.SubTitle("Smethod       = " + string(Smethod)             ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=200)

       e = e.SubTitle("SPECIAL:"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=250)
       e = e.SubTitle("--------"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=260)
       e = e.SubTitle("preblur       = " + string(preblur)             ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=280)
       e = e.SubTitle("secure        = " + string(secure)              ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=290)
       e = e.SubTitle("source        = " + string(source)              ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=300)

       e = e.SubTitle("NONLINEAR SHARPENING:"                          ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=340)
       e = e.SubTitle("---------------------"                          ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=350)
       e = e.SubTitle("Szrp          = " + string(Szrp,  "%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=370)
       e = e.SubTitle("Spwr          = " + string(Spwr,  "%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=380)
       e = e.SubTitle("SdmpLo        = " + string(SdmpLo,"%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=390)
       e = e.SubTitle("SdmpHi        = " + string(SdmpHi,"%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=400)

       e = e.SubTitle("LIMITING:"                                      ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=440)
       e = e.SubTitle("---------"                                      ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=450)
       e = e.SubTitle("Lmode         = " + string(Lmode)               ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=470)
       e = e.SubTitle("overshoot     = " + string(overshoot,  "%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=480)
       e = e.SubTitle("undershoot    = " + string(undershoot, "%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=490)
       e = e.SubTitle("overshoot2    = " + string(overshoot2, "%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=500)
       e = e.SubTitle("undershoot2   = " + string(undershoot2,"%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=510)

       e = e.SubTitle("POST-PROCESSING:"                               ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=550)
       e = e.SubTitle("----------------"                               ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=560)
       e = e.SubTitle("soft          = " + string(soft)                ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=580)
       e = e.SubTitle("soothe        = " + string(soothe)              ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=590)
       e = e.SubTitle("keep          = " + string(keep)                ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=600)

       e = e.SubTitle("EDGES:"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=640)
       e = e.SubTitle("------"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=650)
       e = e.SubTitle("edgemode      = " + string(edgemode)            ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=670)
       e = e.SubTitle("edgemaskHQ    = " + string(edgemaskHQ)          ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=680)

       e = e.SubTitle("UPSAMPLING:"                                    ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=720)
       e = e.SubTitle("-----------"                                    ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=730)
       e = e.SubTitle("ss_x          = " + string(ss_x,"%3.3f")        ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=750)
       e = e.SubTitle("ss_y          = " + string(ss_y,"%3.3f")        ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=760)
       e = e.SubTitle("dest_x        = " + string(dest_x)              ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=770)
       e = e.SubTitle("dest_y        = " + string(dest_y)              ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=780)

       e = e.SubTitle("DEBUG:"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=820)
       e = e.SubTitle("------"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=830)
       e = e.SubTitle("show          = " + string(show)                ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=850)
       e = e.SubTitle("screenW       = " + string(screenW)             ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=860)
       e = e.SubTitle("screenH       = " + string(screenH)             ,text_color=$FFFFFF,font="COURIER NEW",size=16,x=40,y=870)

       debug = stackhorizontal( e ,
       \                        stackvertical( i.subtitle("Input" ,text_color=$FFFFFF,size=20,x=40,y=20) ,
       \                                       o.subtitle("Output",text_color=$FFFFFF,size=20,x=40,y=20) ) )

       return debug
       }

    output = sisupscale || sislumaonly ? output : CombinePlanes(output,inclip,planes="YUV",sample_clip=inclip)

    output = !show ? output
    \              : LSFM_Show(inclip, output, version, preset,
    \                          strength, Smode, Smethod,
    \                          preblur, secure, sode?"defined":"undefined",
    \                          Szrp, Spwr, SdmpLo, SdmpHi,
    \                          Lmode, overshoot, undershoot, overshoot2, undershoot2,
    \                          soft, soothe, keep,
    \                          edgemode, edgemaskHQ,
    \                          ss_x, ss_y, dest_x, dest_y,
    \                          show, screenW, screenH)

    return output }