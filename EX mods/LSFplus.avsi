################################################################################################
###                                                                                          ###
###                       LimitedSharpenFaster+ : function LSFplus()                         ###
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
###                                v6.0 ex - 24 February 2023                                ###
###                                                                                          ###
################################################################################################
###
###
### LSFplus features and changes (compared to LSFmod v2.193):
###     - Frame properties support
###     - Increased performance (+50~75%)
###     - HD support
###     - PC range aware
###     - Better edge detection algorithm
###     - Better preblur algorithm
###     - Better supersampling kernels
###     - Higher kernel support (5x5)
###     - More limiting modes
###     - More and optimized defaults/presets
###
###
### +-----------+
### | CHANGELOG |
### +-----------+
###
### v6.0ex : - Revert 5.6ex as handling of interlaced content is better dealt as stacked fields
###          - Promote to 6.0ex and wrap up
###
### v5.6ex : - Support for globals of interlaced clips on temporal limiting
###
### v5.5ex : - Some cleanup in repair modes
###
### v5.4ex : - Typo in Secure expression
###          - Fix 'super' clip in Lmode=6 for single plane sources
###          - Convert 'pre' to 8-bit in Lmode=6 for optimization
###
### v5.3ex : - Update Temporal Limiting settings
###          - Fix 'super' in Lmode=6 format when reading from Globals
###
### v5.2ex : - Update resizer kernels
###
### v5.1ex : - Optimize 'secure' expression
###          - Update propCopy() call to AVS+ v3.7.2 test8
###          - Changed downscaling kernels
###          - Add function definitions
###          - Change name from LSFmod to LSFplus
###
### v5.0ex : - Remove 'smode=5' (old 'smode=4') as it was flawed
###          - Add 'smode=3' (plain ex_unsharp() sharpener) and pass supersampling to its 'Fc' arg. Shift up index for all other modes
###          - Reenable 'secure' for HBD (still had issues)
###          - Expression optimization when 'preblur' or 'secure' is used in 'smode' 4 or 5
###          - Replace resizers with more suited ones to reduce ringing (upscale) or minimize blurring (downscale)
###          - Replace 'old' preset with 'LSF' and tweak defaults to mimic LimitedSharpenFaster (more suited for images or HD inputs)
###          - Improve edge mask by using the 'kroon' operator
###          - Fix frame properties being lost
###          - Fix ex_luts() (missing inputs)
###          - Increased font size in Debug panel
###          - Tweak Defaults
###
### v4.2ex : - Replace internal preblur syntax with ex_minblur(sharp=true) (function included in SMDegrain())
###          - Exclude 'secure' for HBD inputs (it was originally an 8-bit lack-of-precision fix)
###          - Remove 'Lrad' argument
###          - Expand 'Smethod' to 4, 5 and 6 for a 5x5 minmax average for HD or supersampling (as originally devised by Didée)
###          - Removed 'edgemaskHQ' argument and internally replaced with a similar but faster alternative
###          - Fix 'Lmode' for HD inputs
###          - Tweak Defaults
###
### v4.1ex : - Update/Optimize expressions
###          - Refine 'Smode' 1 and 2 to mimic original
###          - Rebase to latest ExTools
###          - Cosmetics
###
### v4.0ex : - Drop 'fulls' argument, now read from frameprops
###          - Cosmetics
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
###          - ...and repair() its motion compensated vectors
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
### -> ExTools        (v10.2   or up)
### -> ResizersPack   (v11.8   or up)
### -> SMDegrain      (v4.3.0  or up)  [for preblur="ON"]
### -> MVTools        (v2.7.45 or up)  [for preblur="ON" or Lmode=6]
### -> SharpenersPack (v5.1    or up)  [for Smode=1, Smode=2, Smode=3 and Smode=6]
###
###
###
###
### +-------+
### | USAGE |
### +-------+
###
### LSFplus( strength, Smode, Smethod,
###         preblur, secure, source,
###         Szrp, Spwr, SdmpLo, SdmpHi,
###         Lmode, overshoot, undershoot, overshoot2, undershoot2,
###         soft, soothe, keep, edgemode,
###         ss_x, ss_y, dest_x, dest_y,
###         show, screenW, screenH,
###         preset, tv_range )
###
###
###
### +---------+
### | GENERAL |
### +---------+
###
### strength [float]
### --------------
### Strength of the sharpening
###
### Smode [int: 1,2,3,4,5,6]
### ----------------------
### Sharpen mode:
###    =1 : Unsharp masking (from warpsharp)     (now parametrized ex_unsharp())
###    =2 : Unsharp masking (from variableblur)  (now parametrized ex_unsharp())
###    =3 : Unsharp masking (from ex_unsharp())
###    =4 : Range sharpening
###    =5 : Nonlinear sharpening (corrected version)
###    =6 : Contrast Adaptive Sharpening (from CAS)
###
### Smethod [int: 1,2,3,4,5,6]
### --------------------
### Sharpen method: (only used in Smode=3,4,5)
###    =1 : 3x3 kernel
###    =2 : Min/Max
###    =3 : Min/Max + 3x3 kernel
###    =4 : 5x5 kernel
###    =5 : Min/Max (radius 2)
###    =6 : Min/Max + 5x5 kernel
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
###    Usage:   LSFplus(preblur="YourFavoriteDenoiser()")
###    Example: LSFplus(preblur="FFT3Dfilter(sigma=4,plane=0)")
###
### secure [bool]
### -------------
### Mode to avoid banding & oil painting (or face wax) effect of sharpening
### (only used in Smode=3,4,5,6)
###
### source [clip]
### -------------
### If source is defined, LSFplus doesn't sharp more a denoised clip than this source clip
### In this mode, you can safely set Lmode=0 & PP=off
###    Usage:   denoised.LSFplus(source=source)
###    Example: last.FFT3Dfilter().LSFplus(source=last,Lmode=0,soft=0)
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
### Spwr [float]
### ----------
### Power: exponent for sharpener
###
### SdmpLo [float]
### ------------
### Damp Low: reduce sharpening for small changes [0:disable]
###
### SdmpHi [float]
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
###    =1 : 3x3 or 5x5 spatial limit to over/undershoot
###    =2 : 3x3 or 5x5 spatial limit to over/undershoot on edges and no limit on not-edges
###    =3 : 3x3 or 5x5 spatial limit to zero on edges and to over/undershoot on not-edges
###    =4 : 3x3 or 5x5 spatial limit to over/undershoot on edges and to over/undershoot2 on not-edges
###    =5 : 3x3 or 5x5 spatial limit to over/undershoot on edges and to zero             on not-edges
###    =6 : Temporal           limit to over/undershoot on edges and to zero             on not-edges
###
### overshoot [float]
### ---------------
### Limit for pixels that get brighter during sharpening
###
### undershoot [float]
### ----------------
### Limit for pixels that get darker during sharpening
###
### overshoot2 [float]
### ----------------
### Same as overshoot, only for Lmode=4
###
### undershoot2 [float]
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
### preset [string: "LSF" or "slow" or "mid" or "fast"]
### --------------------------------------------
###    = "LSF"  : Mimic original LimitedSharpenFaster settings (Default for HD otherwise "mid")
###    = "slow" : Enable SLOW   modded version settings
###    = "mid"  : Enable MEDIUM modded version settings
###    = "fast" : Enable FAST   modded version settings
###
###
### preset="LSF"   :  - strength    = 50
### ----------------  - Smode       = 4
###                   - Smethod     = Smode==3 ? 2 : 1
###
###                   - preblur     = "OFF"
###                   - secure      = true
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
###
###                   - ss_x        = isHD ? 1 : Smode==3 ? 1.50 : 1.25
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1920
###                   - screenH     = 1080
###
###
### preset="slow"   : - strength    = 50
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
###
###                   - ss_x        = 1.50
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1920
###                   - screenH     = 1080
###
###
### preset="medium" : - strength    = 50
### ----------------- - Smode       = 5
###                   - Smethod     = 3
###
###                   - preblur     = "OFF"
###                   - secure      = true
###                   - source      = undefined
###
###                   - Szrp        = 16
###                   - Spwr        = 3
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
###
###                   - ss_x        = 1.25
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1920
###                   - screenH     = 1080
###
###
### preset="fast"   : - strength    = 50
### ----------------- - Smode       = 4
###                   - Smethod     = 2
###
###                   - preblur     = "OFF"
###                   - secure      = true
###                   - source      = undefined
###
###                   - Szrp        = 16
###                   - Spwr        = 3
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
###
###                   - ss_x        = 1.25
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1920
###                   - screenH     = 1080
###
###
###
### Function Definitions:
###     (
###     clip,
###     float "strength"=50.0 (1.0 to 300.0 by 1),
###     string "preset"="LSF" ("LSF"/ "fast"/ "medium"/ "slow"),
###     [int "Smode"=4 (1 / 2 / 3 / 4 / 5 / 6)],
###     [int "Smethod"=2 (1 / 2 / 3 / 4 / 5 / 6)],
###     string "preblur"="OFF" ("OFF"/ "ON"),
###     [int "Szrp"=16 (1 to 255)],
###     [float "Spwr"=3.0 (1.0 to 10.0 by 1)],
###     [float "SdmpLo"=2.0 (0.0 to 255.0 by 1)],
###     [float "SdmpHi"=0.0 (0.0 to 255.0 by 1)],
###     [int "Lmode"=1 (-1 to 6)],
###     [float "overshoot"=1.0 (0.0 to 255.0 by 1)],
###     [float "undershoot"=1.0 (0.0 to 255.0 by 1)],
###     [float "overshoot2"=2.0 (0.0 to 255.0 by 1)],
###     [float "undershoot2"=2.0 (0.0 to 255.0 by 1)],
###     int "soft"=0 (-2 to 100),
###     bool "soothe"=false,
###     [int "keep"=25 (0 to 100)],
###     [int "edgemode"=0 (-1 to 2)],
###     bool "show"=false
###     )
###
###
################################################################################################

function LSFplus(clip inclip, float "strength", int "Smode", int "Smethod",
\                string "preblur", bool "secure", clip "source",
\                int "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
\                int "Lmode", float "overshoot", float "undershoot", float "overshoot2", float "undershoot2",
\                int "soft", bool "soothe", int "keep", int "edgemode",
\                float "ss_x", float "ss_y", int "dest_x", int "dest_y",
\                bool "show", int "screenW", int "screenH",
\                string "preset", bool "tv_range") {


    ### PRESETS
    version = "v6.0ex"

    rgb    = isRGB(inclip)
    ox     = inclip.width()
    oy     = inclip.height()
    bi     = BitsPerComponent(inclip)
    fs     = propNumElements (inclip,"_ColorRange")  > 0 ? \
             propGetInt      (inclip,"_ColorRange") == 0 : rgb

    isHD   = (ox > 1099 || oy > 599)

    tv     = Default(tv_range, !fs)
    preset = Default(preset,isHD?"LSF":"mid")

    num    = preset=="LSF"    ? 0 : \
             preset=="slow"   ? 1 : \
             preset=="mid" || \
             preset=="medium" ? 2 : \
             preset=="fast"   ? 3 : 4

    Assert(IsVersionOrGreater(3,7,3), "LSFplus: Update AviSynth+ version")
    Assert(num != 4,      chr(10) + """LSFplus: Preset must be "LSF", "slow", "mid" or "fast" !""" + chr(10))

    #                                                                         LSF                  SLOW                 MEDIUM                  FAST

    Smode       = Default( Smode,       Select(num,                             4 ,                  5 ,                  5 ,                  4 ) )
    ss_x        = Default( ss_x,        Select(num,     isHD?1.:Smode==4?1.5:1.25 ,                1.5 ,               1.25 ,               1.25 ) )
    ss_y        = Default( ss_y,        Select(num,                          ss_x ,               ss_x ,               ss_x ,               ss_x ) )
    dest_x      = Default( dest_x,      Select(num,                            ox ,                 ox ,                 ox ,                 ox ) )
    dest_y      = Default( dest_y,      Select(num,                            oy ,                 oy ,                 oy ,                 oy ) )
    SS          = (ss_x > 1.0 || ss_y > 1.0) && Smode!=3

    strength    = Default( strength,    Select(num,                            50.,                 50.,                 50.,                 50.) )
    Smethod     = Default( Smethod,     Select(num,Smode==4?2:(SS||isHD?3:0)+Smode==3?2:1,            3,                  3 ,                  2 ) )

    preblur     = Default( preblur,     Select(num,                         "OFF" ,              "OFF" ,              "OFF" ,              "OFF" ) )
    secure      = Default( secure,      Select(num,                          true ,               true ,               true ,               true ) )

    Szrp        = Default( Szrp,        Select(num,                            16 ,                 16 ,                 16 ,                 16 ) )
    Spwr        = Default( Spwr,        Select(num,                      4*ss_x-2 ,           4*ss_x-2 ,           4*ss_x-2 ,           4*ss_x-2 ) )
    SdmpLo      = Default( SdmpLo,      Select(num,                   strength/25 ,                  4 ,                  4 ,                  4 ) )
    SdmpHi      = Default( SdmpHi,      Select(num,                             0 ,                 48 ,                 48 ,                 48 ) )

    Lmode       = Default( Lmode,       Select(num,                             1 ,                  4 ,                  4 ,                  1 ) )
    overshoot   = Default( overshoot,   Select(num,                             1 ,      strength/100. ,      strength/100. ,      strength/100. ) )
    undershoot  = Default( undershoot,  Select(num,                     overshoot ,          overshoot ,          overshoot ,          overshoot ) )
    overshoot2  = Default( overshoot2,  Select(num,                   overshoot*2 ,        overshoot*2 ,        overshoot*2 ,        overshoot*2 ) )
    undershoot2 = Default( undershoot2, Select(num,                    overshoot2 ,         overshoot2 ,         overshoot2 ,         overshoot2 ) )

    soft        = Default( soft,        Select(num,                             0 ,                 -2 ,                  0 ,                  0 ) )
    soothe      = Default( soothe,      Select(num,                         false ,               true ,               true ,               true ) )
    keep        = Default( keep,        Select(num,                            25 ,                 20 ,                 20 ,                 20 ) )

    edgemode    = Default( edgemode,    Select(num,                             0 ,                  0 ,                  0 ,                  0 ) )

    show        = Default( show,        Select(num,                         false ,              false ,              false ,              false ) )
    screenW     = Default( screenW,     Select(num,                          1920 ,               1920 ,               1920 ,               1920 ) )
    screenH     = Default( screenH,     Select(num,                          1080 ,               1080 ,               1080 ,               1080 ) )

    Assert(  !isYUY2(inclip)                           , chr(10) + "LSFplus: Unsupported format: YUY2"                        + chr(10))
    Assert(  !rgb                                      , chr(10) + "LSFplus: Unsupported format: RGB"                         + chr(10))
    Assert( ( strength >= 0 )                          , chr(10) + "LSFplus: 'strength', incorrect value! [>=0]"              + chr(10))
    Assert( ( Smode >= 1 && Smode <= 6 )               , chr(10) + "LSFplus: 'Smode', incorrect value! [1,2,3,4,5,6]"         + chr(10))
    Assert( ( Smethod >= 1 && Smethod <= 6 )           , chr(10) + "LSFplus: 'Smethod', incorrect value! [1,2,3,4,5,6]"       + chr(10))
    Assert( ( Szrp >= 1 && Szrp <= 255 )               , chr(10) + "LSFplus: 'Szrp', incorrect value! [1...255]"              + chr(10))
    Assert( ( Spwr >= 1 )                              , chr(10) + "LSFplus: 'Spwr', incorrect value! [>=1]"                  + chr(10))
    Assert( ( SdmpLo >= 0 && SdmpLo <= 255 )           , chr(10) + "LSFplus: 'SdmpLo', incorrect value! [0...255]"            + chr(10))
    Assert( ( SdmpHi >= 0 && SdmpHi <= 255 )           , chr(10) + "LSFplus: 'SdmpHi', incorrect value! [0...255]"            + chr(10))
    Assert( ( Lmode <= 6 )                             , chr(10) + "LSFplus: 'Lmode', incorrect value! [...-1,0,1,2,3,4,5,6]" + chr(10))
    Assert( ( overshoot >= 0 && overshoot <= 255 )     , chr(10) + "LSFplus: 'overshoot', incorrect value! [0...255]"         + chr(10))
    Assert( ( undershoot >= 0 && undershoot <= 255 )   , chr(10) + "LSFplus: 'undershoot', incorrect value! [0...255]"        + chr(10))
    Assert( ( overshoot2 >= 0 && overshoot2 <= 255 )   , chr(10) + "LSFplus: 'overshoot2', incorrect value! [0...255]"        + chr(10))
    Assert( ( undershoot2 >= 0 && undershoot2 <= 255 ) , chr(10) + "LSFplus: 'undershoot2', incorrect value! [0...255]"       + chr(10))
    Assert( ( soft >= -2 && soft <= 100 )              , chr(10) + "LSFplus: 'soft', incorrect value! [-2,-1,0,1...100]"      + chr(10))
    Assert( ( keep >= 0 && keep <= 100 )               , chr(10) + "LSFplus: 'keep', incorrect value! [0...100]"              + chr(10))
    Assert( ( edgemode >= -1 && edgemode <= 2 )        , chr(10) + "LSFplus: 'edgemode', incorrect value! [-1,0,1,2]"         + chr(10))
    Assert( ( ss_x >= 1.0 )                            , chr(10) + "LSFplus: 'ss_x', incorrect value! [>=1.0]"                + chr(10))
    Assert( ( ss_y >= 1.0 )                            , chr(10) + "LSFplus: 'ss_y', incorrect value! [>=1.0]"                + chr(10))

    xxs   = nmod(ox*ss_x,8)
    yys   = nmod(oy*ss_y,8)

    bi32m = bi != 32 ? "range_half -" : ""
    bi32p = bi != 32 ? "range_half +" : ""

    str   = (Smethod < 4 ? strength + 30 : strength) / 100.

    sisupscale  = dest_x != ox || dest_y != oy
    sislumaonly = inclip.isy()

    sode        = Defined(source)
    source      = sode ? sisupscale || sislumaonly ? source : source.ExtractY() : source
    input       =        sisupscale || sislumaonly ? inclip : inclip.ExtractY()


    ### PRE
    tmp  = SS ? input.blackmanresize(xxs,yys,taps=6) : input # blackman6 is a tiny bit better than lanczos4 ringing wise, blackman5 would be akin spline64
    pre  = preblur=="OFF" ? tmp
    \    : preblur=="ON"  ? tmp.ex_minblur(SS || isHD ? 2 : 1, sharp=true)
    \    : Eval("tmp."+preblur)

    edge  = tmp.ex_edge("kroon",12,110)
    edgei = edge.ex_inflate()

    dark_limit    = pre.ex_inpand()                                                                                          # for 3x3 local neighbourhood min/max avg for SD
    dark_limit2   = num==1  ?   dark_limit.ex_boxblur(1,mode="mean").ex_inpand() : pre.ex_inpand(2,mode="disk").ex_inflate() # for 5x5 local neighbourhood min/max avg for HD or ss_x/y > 1.0 ('slow' softens inbetween)
    bright_limit  = pre.ex_expand()
    bright_limit2 = num==1  ? bright_limit.ex_boxblur(1,mode="mean").ex_expand() : pre.ex_expand(2,mode="disk").ex_deflate()
    minmaxavg     = Lmode<1 ? Smethod > 3 ? ex_luts(pre,mode="minmax", pixels = ex_shape(2,mode="disk")) : \
                                            ex_luts(pre,mode="minmax")                                   : \
                              Smethod > 3 ? Merge(dark_limit2, bright_limit2)                            : \
                                            Merge(dark_limit,  bright_limit)

    method = Smethod==1   ?       pre.ex_boxblur(1,mode="weighted")
    \      : Smethod==2   ? minmaxavg
    \      : Smethod==3   ? minmaxavg.ex_boxblur(1,mode="weighted")
    \      : Smethod==4   ?                   pre.ex_boxblur(2,  mode="weighted")
    \      : Smethod==5   ? Lmode < 1 ? minmaxavg.ex_boxblur(0.5,mode="weighted") : minmaxavg
    \      :                            minmaxavg.ex_boxblur(2,  mode="weighted")

    sec    = ex_bs(0.51, 8, bi, fulls=true, flt=true)
    secstr = Format("x dup y == swap dup y x - sgn {sec} * + ?") # "shift-back-by-one" trick; "whatever change you calculated, reduce that change by 1". Trick to fix banding and "face wax" effect. https://forum.doom9.org/showthread.php?p=1539241
    method = Smode>3 ? method : secure ? method.ex_lutxy(pre,secstr, UV=1, fulls=!tv)
    \      :                             method
    method = Smode>3 || preblur=="OFF" ? method : tmp.ex_lutxyz(pre,method,"x y z - "+bi32p+" - "+bi32p, UV=1, fulls=!tv)

    secur  = secure ? Format("y dup z == swap dup z y - sgn 0.51 * + ?") : "y"
    prebl  = preblur=="ON" ? "x z "+secur+" - - " : secur


    ### SHARP
    # Smode==1 Parametrized to original WarpSharp's    unsharpmask()
    # Smode==2 Parametrized to original VariableBlur's unsharp()
    Szrp2     = Szrp*Szrp
    SdmpHiv   = SdmpHi == 0 ?  0 : 1. / SdmpHi
    SdmpHr    = SdmpHi == 0 ? "" : Format("{Szrp} {SdmpHiv} * 4 ^ 1 +    ")
    SdmpHs    = SdmpHi == 0 ? "" : Format("     B {SdmpHiv} * 4 ^ 1 + / *")
    Szrpr     = 1. / Szrp          Spwrr = 1. / Spwr
    rad2      = (ss_x+ss_y)/2.0    rad   = round(rad2)


    normsharp = Smode==1 ? tmp.  ex_unsharp(str=str*0.7,                           Fc=max(ox,oy)/max(1,0.76*exp(0.26*round(1+rad2))),th=0,UV=1)
    \         : Smode==2 ? tmp.  ex_unsharp(str=str/(1.489*pow(rad2,-1.112)+0.51), Fc=max(ox,oy)*0.8,                                th=0,UV=1)
    \         : Smode==3 ? input.ex_unsharp(str=str*max(1.*xxs/ox,1.*yys/oy),      Fc=max(xxs,yys),                                  th=0,UV=1)
    \         : Smode==4 ? preblur=="ON" || secure ? ex_lutxyz(tmp, method, pre, Format(prebl+" x swap - {str} * x +"), UV=1, fulls=!tv, scale_inputs=!tv ? "allf" : "all")
    \         :                                      ex_lutxy (tmp, method,      Format(          "x y - {str} * x +"), UV=1, fulls=!tv)
    \         : Smode==5 ? preblur=="ON" || secure ? ex_lutxyz(tmp, method, pre, Format(prebl+" Y@ x dup swap2 == swap dup Y - A@ abs B@ {Szrpr} * {Spwrr} ^ {Szrp} {str} * * A sgn * A dup * C@ "
    \                                                  +"{Szrp2} {SdmpLo} + * C {SdmpLo} + {Szrp2} * / * "+SdmpHr+" "+SdmpHs+" x + ?"), UV=1, fulls=!tv, scale_inputs=!tv ? "allf" : "all")
    \         :                                      ex_lutxy (tmp, method,      Format(      "    x dup     y == swap dup y - A@ abs B@ {Szrpr} * {Spwrr} ^ {Szrp} {str} * * A sgn * A dup * C@ "
    \                                                  +"{Szrp2} {SdmpLo} + * C {SdmpLo} + {Szrp2} * / * "+SdmpHr+" "+SdmpHs+" x + ?"), UV=1, fulls=!tv, scale_inputs=!tv ? "allf" : "all")
    \         :            preblur!="OFF" ? secure ? tmp.ex_lutxyz(pre,pre.ex_CAS(min(Str, 1)).ex_lutxy(pre,secstr, UV=1, fulls=!tv), "x y z - "+bi32p+" - "+bi32p, UV=1, fulls=!tv)
    \         :                                      tmp.ex_lutxyz(pre,pre.ex_CAS(min(Str, 1)), "x y z - "+bi32p+" - "+bi32p, UV=1, fulls=!tv)
    \         :                             secure ? pre.ex_CAS(min(Str, 1)).ex_lutxy(pre,secstr, UV=1, fulls=!tv)
    \         :                                      pre.ex_CAS(min(Str, 1))


    ### Temporal limiting
    if (Lmode==6) {

        isg   = VarExist("cb1") && VarExist("cf1") # if Lmode=6; reuse MAnalyze'd global vectors if exist (and SS is not used) otherwise create them below
        super = isg && VarExist("super") ? isy(super) ? super : super.ExtractY() : nop()

        if (!isg || SS) {

            blksize   = (ox > 2599 || oy > 1499) ? 32 : isHD ? 16 : 8
            pre       = pre.ConvertBits(8, dither=-1, fulls=!tv)

            superfilt = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, sharp=2, rfilter=3, chroma=false, mt=true)
            super     = MSuper(pre, pel=isHD?1:2, hpad = 0, vpad = 0, sharp=2, rfilter=3, chroma=false, mt=true, levels=1)

            cb1 = superfilt.MAnalyse(isb = false, chroma=false, blksize = blksize,   overlap=blksize/2, delta = 1, truemotion=true, mt=true, dct=0, search=4, pglobal=13, temporal=true, global=true, plevel=0)
            cf1 = superfilt.MAnalyse(isb = true,  chroma=false, blksize = blksize,   overlap=blksize/2, delta = 1, truemotion=true, mt=true, dct=0, search=4, pglobal=13, temporal=true, global=true, plevel=0)
            cb1 =     super.Mrecalculate(cb1,     chroma=false, blksize = blksize/2, overlap=blksize/4, thSAD=190, truemotion=true, mt=true, dct=5, search=0)
            cf1 =     super.Mrecalculate(cf1,     chroma=false, blksize = blksize/2, overlap=blksize/4, thSAD=190, truemotion=true, mt=true, dct=5, search=0)
            }

        cb1     = ex_repair(pre.MCompensate(super, cb1, thSAD=220, thSCD1=round(6.25*8*8), thSCD2=round(2.03*8*8), mt=true), pre, "undot3", UV=1).ConvertBits(bi, fulls=!tv)
        cf1     = ex_repair(pre.MCompensate(super, cf1, thSAD=220, thSCD1=round(6.25*8*8), thSCD2=round(2.03*8*8), mt=true), pre, "undot3", UV=1).ConvertBits(bi, fulls=!tv)
        os      = ex_bs(overshoot, 8, bi, fulls=!tv, flt=true)   us = ex_bs(undershoot, 8, bi, fulls=!tv, flt=true)
        os      = os  == 0 ? "" : Format("{os}  +")              us = us  == 0 ? "" : Format("{us}  -")
        normalT = ex_lutxyza(tmp,normsharp,cb1,cf1,Format("y x z max a max "+os+" min x z min a min "+us+" max"),UV=1)
        }

    ### LIMIT
    os10    = overshoot  == 0 && undershoot  == 0
    os20    = overshoot2 == 0 && undershoot2 == 0
    zero    =                ex_clamp(normsharp, bright_limit,  dark_limit,                  0,                  0, UV=1)
    zero2   =                ex_clamp(normsharp, bright_limit2, dark_limit2,                 0,                  0, UV=1)
    second  = os20 ? zero  : ex_clamp(normsharp, bright_limit,  dark_limit,  round(overshoot2), round(undershoot2), UV=1)
#   second2 = os20 ? zero2 : ex_clamp(normsharp, bright_limit2, dark_limit2, round(overshoot2), round(undershoot2), UV=1)
    normal  = os10 ? zero  : ex_clamp(normsharp, bright_limit,  dark_limit,  round(overshoot),  round(undershoot),  UV=1)
    normal2 = os10 ? zero2 : ex_clamp(normsharp, bright_limit2, dark_limit2, round(overshoot),  round(undershoot),  UV=1)


    Lm     = max(1,abs(Lmode))
    Lm     = string(4 < Lm < 16 ? 4 : 19 < Lm < 22 ? 19 : Lm )
    limit1 = Lmode <0 ? normsharp.ex_repair(Smethod > 3 ? normsharp.ex_repair(tmp,"undot"+Lm, UV=1) : tmp, "undot"+Lm, UV=1)
    \      : Lmode==0 ? normsharp
    \      : Lmode==1 ?                                             Smethod < 4 ? normal : normal2
    \      : Lmode==2 ?                                             Smethod < 4 ? ex_merge(normsharp, normal,  edgei) : ex_merge(normsharp, normal2,  edgei)
    \      : Lmode==3 ? os10         ? Smethod < 4 ? zero : zero2 : Smethod < 4 ? ex_merge(normal,    zero,    edgei) : ex_merge(normal,    zero2,    edgei)
    \      : Lmode==4 ? os10 && os20 ? Smethod < 4 ? zero : zero2 : Smethod < 4 ? ex_merge(second,    normal,  edgei) : ex_merge(second,    normal2,  edgei)
    \      : Lmode==5 ? os10         ? Smethod < 4 ? zero : zero2 : Smethod < 4 ? ex_merge(zero,      normal,  edgei) : ex_merge(zero,      normal2,  edgei)
    \      :                                                        Smethod < 4 ? ex_merge(zero,      normalT, edgei) : ex_merge(zero2,     normalT,  edgei)


    limit2 = edgemode==0 ? limit1
    \      : edgemode==1 ? ex_merge(tmp,limit1,edgei.ex_inflate().ex_boxblur(1,mode="weighted",UV=1))
    \      :               ex_merge(limit1,tmp,edgei.ex_inflate().ex_boxblur(1,mode="weighted",UV=1))


    ### SOFT
    soft = soft!=-1 ? soft : sqrt( ((rad2-1.0)*100.0) ) * 10
    soft = soft!=-2 ? soft : int( (1.0+(2.0/(ss_x+ss_y))) * sqrt(strength) )
    soft = min(soft,100)
    sharpdiff = ex_makediff(tmp, limit2, UV=1, fulls=!tv)
    sharpdiff = ex_lutxyz(tmp, sharpdiff, sharpdiff.ex_boxblur(1,mode="mean",UV=1), Format("y "+bi32m+" abs z "+bi32m+" abs > z {soft} * y 100 {soft} - * + 0.01 * y ? x swap - "+bi32p), UV=1, fulls=!tv)

    PP1 = soft==0 ? limit2 : sharpdiff


    ### SOOTHE
    diff  = ex_makediff(tmp, PP1, UV=1, fulls=!tv)
    diff2 = diff.temporalsoften(1,255,0,32,2)
    diff3 = ex_lutxyz(tmp,diff,diff2,Format( "y "+bi32m+" A@ z "+bi32m+" B@ * 0 < A {keep} 0.01 * * "+bi32p+"  A abs B abs > y {keep} * z 100 {keep} - * + 0.01 * y ? ? x swap - "+bi32p), UV=1, fulls=!tv)

    PP2 = soothe ? diff3 : PP1


    ### OUTPUT
    out = sisupscale ?        PP2.blackmanresize(dest_x, dest_y, taps=6)    : \
                  SS ?        PP2.bicubicresize (dest_x, dest_y, -0.5,0.25) : PP2

    ### CONTRA
    if (sode) {

        in  = sisupscale ?  input.blackmanresize(dest_x, dest_y, taps=6)    : input
        no  =           normsharp.bicubicresize (dest_x, dest_y, -0.5,0.25)
        src = sisupscale ? source.blackmanresize(dest_x, dest_y, taps=6)    : source

        srcD   = ex_makediff(in, src, UV=1, fulls=!tv)
        shrpD  = ex_makediff(in, no,  UV=1, fulls=!tv)
        srcDP  =  srcD.PadBorders(4,4,4,4,"Dilate")
        shrpDP = shrpD.PadBorders(4,4,4,4,"Dilate")
        shrpL  = shrpDP.ex_repair(Smethod>3?shrpDP.ex_repair(srcDP,"undot"+Lm,UV=1):srcDP,"undot"+Lm,UV=1).crop(4,4,-4,-4,true)
        out    = ex_lutxyz(in,shrpL,shrpD, "y "+bi32m+" X@ abs z "+bi32m+" Y@ abs < X Y ? x swap -", UV=1, fulls=!tv)
    }

    output = edgemode!=-1 ? out : !sisupscale ? edge.bicubicresize(dest_x,dest_y,-0.5,0.25) : edge.blackmanresize(dest_x,dest_y,taps=6).greyscale()


    ### SHOW
       function LSFP_Show(clip input, clip output, string "version", string "preset",
       \                  float "strength", int "Smode", int "Smethod",
       \                  string "preblur", bool "secure", string "source",
       \                  float "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
       \                  int "Lmode", float "overshoot", float "undershoot", float "overshoot2", float "undershoot2",
       \                  int "soft", bool "soothe", int "keep", int "edgemode",
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

       e =   blankclip(input, width=384, height=resoH)
       e = e.SubTitle("LSF+ "            + string(version)             ,text_color=$FFFFFF,font="Verdana"    ,size=34,x=40,y=40 )
       e = e.SubTitle("PRESET        = " + string(preset)              ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=100)

       e = e.SubTitle("GENERAL:"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=150)
       e = e.SubTitle("--------"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=160)
       e = e.SubTitle("strength      = " + string(int(strength))       ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=180)
       e = e.SubTitle("Smode         = " + string(Smode)               ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=195)
       e = e.SubTitle("Smethod       = " + string(Smethod)             ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=210)

       e = e.SubTitle("SPECIAL:"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=250)
       e = e.SubTitle("--------"                                       ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=260)
       e = e.SubTitle("preblur       = " + string(preblur)             ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=280)
       e = e.SubTitle("secure        = " + string(secure)              ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=295)
       e = e.SubTitle("source        = " + string(source)              ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=310)

       e = e.SubTitle("NONLINEAR SHARPENING:"                          ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=350)
       e = e.SubTitle("---------------------"                          ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=360)
       e = e.SubTitle("Szrp          = " + string(Szrp,  "%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=380)
       e = e.SubTitle("Spwr          = " + string(Spwr,  "%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=395)
       e = e.SubTitle("SdmpLo        = " + string(SdmpLo,"%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=410)
       e = e.SubTitle("SdmpHi        = " + string(SdmpHi,"%3.1f")      ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=425)

       e = e.SubTitle("LIMITING:"                                      ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=460)
       e = e.SubTitle("---------"                                      ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=470)
       e = e.SubTitle("Lmode         = " + string(Lmode)               ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=490)
       e = e.SubTitle("overshoot     = " + string(overshoot,  "%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=505)
       e = e.SubTitle("undershoot    = " + string(undershoot, "%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=520)
       e = e.SubTitle("overshoot2    = " + string(overshoot2, "%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=535)
       e = e.SubTitle("undershoot2   = " + string(undershoot2,"%3.3f") ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=550)

       e = e.SubTitle("POST-PROCESSING:"                               ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=590)
       e = e.SubTitle("----------------"                               ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=600)
       e = e.SubTitle("soft          = " + string(soft)                ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=620)
       e = e.SubTitle("soothe        = " + string(soothe)              ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=635)
       e = e.SubTitle("keep          = " + string(keep)                ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=650)

       e = e.SubTitle("EDGES:"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=680)
       e = e.SubTitle("------"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=690)
       e = e.SubTitle("edgemode      = " + string(edgemode)            ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=710)

       e = e.SubTitle("UPSAMPLING:"                                    ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=760)
       e = e.SubTitle("-----------"                                    ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=770)
       e = e.SubTitle("ss_x          = " + string(ss_x,"%3.3f")        ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=790)
       e = e.SubTitle("ss_y          = " + string(ss_y,"%3.3f")        ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=805)
       e = e.SubTitle("dest_x        = " + string(dest_x)              ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=820)
       e = e.SubTitle("dest_y        = " + string(dest_y)              ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=835)

       e = e.SubTitle("DEBUG:"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=880)
       e = e.SubTitle("------"                                         ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=890)
       e = e.SubTitle("show          = " + string(show)                ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=910)
       e = e.SubTitle("screenW       = " + string(screenW)             ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=925)
       e = e.SubTitle("screenH       = " + string(screenH)             ,text_color=$FFFFFF,font="COURIER NEW",size=20,x=40,y=940)

       debug = stackhorizontal( e ,
       \                        stackvertical( i.subtitle("Input" ,text_color=$FFFFFF,size=36,x=40,y=20) ,
       \                                       o.subtitle("Output",text_color=$FFFFFF,size=36,x=40,y=20) ) )

       return debug
       }

    output = sisupscale || sislumaonly ? output : CombinePlanes(output,inclip,planes="YUV",sample_clip=inclip)

    output = !show ? output.propCopy(inclip,true,props="_ChromaLocation")
    \              : LSFP_Show(inclip, output, version, preset,
    \                          strength, Smode, Smethod,
    \                          preblur, secure, sode?"defined":"undefined",
    \                          Szrp, Spwr, SdmpLo, SdmpHi,
    \                          Lmode, overshoot, undershoot, overshoot2, undershoot2,
    \                          soft, soothe, keep, edgemode,
    \                          ss_x, ss_y, dest_x, dest_y,
    \                          show, screenW, screenH)

    return output }