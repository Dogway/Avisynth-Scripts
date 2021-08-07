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
###                                v2.7 mix - 07 August 2021                                 ###
###                                                                                          ###
################################################################################################
###
### +-----------+
### | CHANGELOG |
### +-----------+
###
### v2.7mx : - Revert to removegrain(20) (mathematically correct)
###          - Add internal HD mode
###          - Rebase to latest ExTools
###
### v2.6ex : - Expressions cleanup
###          - Rebase to latest ExTools
###
### v2.5ex : - Expressions optimizations
###
### v2.4ex : - Expressions fix and optimizations
###
### v2.3ex : - Expression optimizations
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
### -> Masktools    (v2.2.26 or up)
### -> RgTools      (v1.2 or up)
### -> Zs_RF_Shared (v1.154)
### -> ExTools      (v4.6)
### -> Variableblur (v0.70 or up)      [for Smode=2]
### -> CAS                             [for Smode=6]
### -> if you use avs+ then make sure it's the last one
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
###         Lmode, overshoot, undershoot, overshoot2, undershoot2,
###         soft, soothe, keep,
###         edgemode, edgemaskHQ,
###         ss_x, ss_y, dest_x, dest_y,
###         show, screenW, screenH,
###         defaults )
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
### Lmode [int: ...,0,1,2,3,4]
### --------------------------
### Limit mode:
###    <0 : Limit with repair (ex: Lmode=-1 --> repair(1), Lmode=-5 --> repair(5)...)
###    =0 : No limit
###    =1 : Limit to over/undershoot
###    =2 : Limit to over/undershoot on edges and no limit on not-edges
###    =3 : Limit to zero on edges and to over/undershoot on not-edges
###    =4 : Limit to over/undershoot on edges and to over/undershoot2 on not-edges
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
### defaults [string: "old" or "slow" or "fast"]
### --------------------------------------------
###    = "old"  : Reset settings to original version (output will be THE SAME AS LSF)
###    = "slow" : Enable SLOW modded version settings
###    = "fast" : Enable FAST modded version settings
###  --> /!\ [default:"fast"]
###
###
### defaults="old" :  - strength    = 100
### ----------------  - Smode       = 3
###                   - Smethod     = Smode==3?2:1
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
###                   - ss_x        = Smode==3?1.50:1.25
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1280
###                   - screenH     = 1024
###
###
### defaults="slow" : - strength    = 100
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
###                   - ss_x        = 1.50
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1280
###                   - screenH     = 1024
###
###
### defaults="fast" : - strength    = 100
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
###                   - ss_x        = 1.25
###                   - ss_y        = ss_x
###                   - dest_x      = ox
###                   - dest_y      = oy
###
###                   - show        = false
###                   - screenW     = 1280
###                   - screenH     = 1024
###
################################################################################################

function LSFmod( clip inclip, float "strength", int "Smode", int "Smethod",
\                string "preblur", bool "secure", clip "source",
\                int "Szrp", float "Spwr", float "SdmpLo", float "SdmpHi",
\                int "Lmode", float "overshoot", float "undershoot", float "overshoot2", float "undershoot2",
\                int "soft", bool "soothe", int "keep",
\                int "edgemode", bool "edgemaskHQ",
\                float "ss_x", float "ss_y", int "dest_x", int "dest_y",
\                bool "show", int "screenW", int "screenH",
\                string "defaults", bool "fulls" ) {


    ### DEFAULTS
    version  = "v2.7ex"
    defaults = Default(defaults,"slow")
    num      = defaults=="old" ? 0 : defaults=="slow" ? 1 : defaults=="fast" ? 2 : 3

    ox   = inclip.width()
    oy   = inclip.height()
    isHD = (ox > 1099 ||  oy > 599)
    bi   = BitsPerComponent(inclip)
    fs   = Default(fulls, false)

    Assert(IsVersionOrGreater(3,7,1), "Update AviSynth+ version")
    Assert(num         != 3      ? true : false, chr(10) + """Defaults must be "old" or "slow" or "fast" !""" + chr(10))

    strength    = Default( strength,    Select(num,                              100 ,                100 ,                100 ) )
    Smode       = Default( Smode,       Select(num,                                3 ,                  5 ,                  3 ) )
    Smethod     = Default( Smethod,     Select(num,                     Smode==3?2:1 ,                  3 ,                  2 ) )

    preblur     = Default( preblur,     Select(num,                            "OFF" ,              "OFF" ,              "OFF" ) )
    secure      = Default( secure,      Select(num,                            false ,               true ,               true ) )

    Szrp        = Default( Szrp,        Select(num,                               16 ,                 16 ,                 16 ) )
    Spwr        = Default( Spwr,        Select(num,                                2 ,                  4 ,                  4 ) )
    SdmpLo      = Default( SdmpLo,      Select(num,                      strength/25 ,                  4 ,                  4 ) )
    SdmpHi      = Default( SdmpHi,      Select(num,                                0 ,                 48 ,                 48 ) )

    Lmode       = Default( Lmode,       Select(num,                                1 ,                  4 ,                  1 ) )
    overshoot   = Default( overshoot,   Select(num,                                1 ,       strength/100 ,       strength/100 ) )
    undershoot  = Default( undershoot,  Select(num,                        overshoot ,          overshoot ,          overshoot ) )
    overshoot2  = Default( overshoot2,  Select(num,                      overshoot*2 ,        overshoot*2 ,        overshoot*2 ) )
    undershoot2 = Default( undershoot2, Select(num,                       overshoot2 ,         overshoot2 ,         overshoot2 ) )

    soft        = Default( soft,        Select(num,                  0 ,                 -2 ,                  0 ) )
    soothe      = Default( soothe,      Select(num,                            false ,               true ,               true ) )
    keep        = Default( keep,        Select(num,                               25 ,                 20 ,                 20 ) )

    edgemode    = Default( edgemode,    Select(num,                                0 ,                  0 ,                  0 ) )
    edgemaskHQ  = Default( edgemaskHQ,  Select(num,                             true ,               true ,              false ) )

    ss_x        = Default( ss_x,        Select(num, Smode==6?1.00:Smode==3?1.50:1.25 ,               1.50 ,               1.25 ) )
    ss_y        = Default( ss_y,        Select(num,                             ss_x ,               ss_x ,               ss_x ) )
    dest_x      = Default( dest_x,      Select(num,                               ox ,                 ox ,                 ox ) )
    dest_y      = Default( dest_y,      Select(num,                               oy ,                 oy ,                 oy ) )

    show        = Default( show,        Select(num,                            false ,              false ,              false ) )
    screenW     = Default( screenW,     Select(num,                             1280 ,               1280 ,               1280 ) )
    screenH     = Default( screenH,     Select(num,                             1024 ,               1024 ,               1024 ) )

    Assert(!isYUY2(inclip), chr(10) + "LSFmod: Unsupported format: YUY2" + chr(10))
    Assert(!isRGB(inclip),  chr(10) + "LSFmod: Unsupported format: RGB"  + chr(10))
    Assert( ( strength >= 0 )                                                ? true : false, chr(10) + "'strength' have not a correct value! [>=0]" + chr(10))
    Assert( ( Smode >= 1 && Smode <= 6 )                                     ? true : false, chr(10) + "'Smode' have not a correct value! [1,2,3,4,5]" + chr(10))
    Assert( ( Smethod >= 1 && Smethod <= 4 )                                 ? true : false, chr(10) + "'Smethod' have not a correct value! [1,2,3,4]" + chr(10))
    Assert( ( Szrp >= 1 && Szrp <= 255 )                                     ? true : false, chr(10) + "'Szrp' have not a correct value! [1...255]" + chr(10))
    Assert( ( Spwr >= 1 )                                                    ? true : false, chr(10) + "'Spwr' have not a correct value! [>=1]" + chr(10))
    Assert( ( SdmpLo >= 0 && SdmpLo <= 255 )                                 ? true : false, chr(10) + "'SdmpLo' have not a correct value! [0...255]" + chr(10))
    Assert( ( SdmpHi >= 0 && SdmpHi <= 255 )                                 ? true : false, chr(10) + "'SdmpHi' have not a correct value! [0...255]" + chr(10))
    Assert( ( Lmode <= 4 )                                                   ? true : false, chr(10) + "'Lmode' have not a correct value! [...-1,0,1,2,3,4]" + chr(10))
    Assert( ( overshoot >= 0 && overshoot <= 255 )                           ? true : false, chr(10) + "'overshoot' have not a correct value! [0...255]" + chr(10))
    Assert( ( undershoot >= 0 && undershoot <= 255 )                         ? true : false, chr(10) + "'undershoot' have not a correct value! [0...255]" + chr(10))
    Assert( ( overshoot2 >= 0 && overshoot2 <= 255 )                         ? true : false, chr(10) + "'overshoot2' have not a correct value! [0...255]" + chr(10))
    Assert( ( undershoot2 >= 0 && undershoot2 <= 255 )                       ? true : false, chr(10) + "'undershoot2' have not a correct value! [0...255]" + chr(10))
    Assert( ( soft >= -2 && soft <= 100 )                                    ? true : false, chr(10) + "'soft' have not a correct value! [-2,-1,0,1...100]" + chr(10))
    Assert( ( keep >= 0 && keep <= 100 )                                     ? true : false, chr(10) + "'keep' have not a correct value! [0...100]" + chr(10))
    Assert( ( edgemode >= -1 && edgemode <= 2 )                              ? true : false, chr(10) + "'edgemode' have not a correct value! [-1,0,1,2]" + chr(10))
    Assert( ( ss_x >= 1.0 )                                                  ? true : false, chr(10) + "'ss_x' have not a correct value! [>=1.0]" + chr(10))
    Assert( ( ss_y >= 1.0 )                                                  ? true : false, chr(10) + "'ss_y' have not a correct value! [>=1.0]" + chr(10))

    soft = soft!=-1  ? soft : sqrt( (((ss_x+ss_y)/2.0-1.0)*100.0) ) * 10
    soft = soft!=-2  ? soft : int( (1.0+(2.0/(ss_x+ss_y))) * sqrt(strength) )
    soft = soft<=100 ? soft : 100

    xxs  = round(ox*ss_x/8)*8
    yys  = round(oy*ss_y/8)*8

    str  = float(strength)/100.0

    sisupscale = (dest_x != ox || dest_y != oy)

    sislumaonly = inclip.isy()

    input = sisupscale || sislumaonly ? inclip : inclip.converttoy()

    sode  = Defined(source)

    source = sode ? sisupscale || sislumaonly ? source : source.converttoy() : source


    ### SHARP
    tmp  = ss_x > 1.0 || ss_y > 1.0 ? input.spline36resize(xxs,yys) : input
    pre  = preblur=="OFF" ? tmp
    \    : preblur=="ON"  ? tmp.ex_makediff(ex_lutxy(ex_makediff(tmp,tmp.ex_boxblur(1,mode="weighted",UV=1),fulls=fs)
    \                                               ,ex_makediff(tmp,tmp.ex_median("median",UV=1),fulls=fs),"x range_half - A@ y range_half - B@ * 0 < range_half A abs B abs < x y ? ?",fulls=fs) \
                                           ,fulls=fs)
    \    : Eval("tmp."+preblur)

    dark_limit   = pre.ex_inpand()
    bright_limit = pre.ex_expand()
    minmaxavg    = Merge(dark_limit,bright_limit,0.5)

    method = Smethod==1   ? isHD ? pre.ex_blur(3,UV=1) : pre.ex_boxblur(1,mode="weighted",UV=1)
    \      : Smethod==2   ? minmaxavg
    \      :                isHD ? minmaxavg.ex_blur(3,UV=1) : minmaxavg.ex_boxblur(1,mode="weighted",UV=1)

    sec    = ex_bs(0.51, bi, fs)
    secstr = Format("x y < x {sec} + x y > x {sec} - x ? ?")
    method = secure==true ? method.ex_lutxy(pre,secstr)
    \      :                method

    method = preblur=="OFF" ? method : tmp.ex_makediff(ex_makediff(pre,method,fulls=fs),fulls=fs)

     Szrp      = ex_bs(Szrp,   bi, fs)
     Spwr      = ex_bs(Spwr,   bi, fs)
     SdmpLo    = ex_bs(SdmpLo, bi, fs)
     SdmpHi    = ex_bs(SdmpHi, bi, fs)

    normsharp = Smode==1 ? tmp.UnsharpMask_HBD(strength=str*150,radius=round(1.0+((ss_x+ss_y)/2.0)),threshold=0,UV=1,fulls=fs)
    \         : Smode==2 ? tmp.UnsharpMask_HBD(strength=str*150,radius=round(1.0+((ss_x+ss_y)/2.0)),threshold=0,UV=1,fulls=fs)
    \         : Smode==3 ? ex_lutxy(tmp, method, Format("x y - {str} * x +"))
    \         : Smode==4 ? ex_lutxy(tmp, method, Format("x y == x x x y - A@ abs 1 {Szrp} / * {rSpwr} ^ {Szrp} * {str} * A dup * dup "
    \                                                  +"{SdmpLo} + / * A dup abs / * 1 {SdmpHi} 0 == 0 A abs 1 {SdmpHi} / * 4 ^ ? + / + ?"))
    \         : Smode==5 ? ex_lutxy(tmp, method, Format("x y == x x x y - A@ abs 1 {Szrp} / * 1 {Spwr} / ^ {Szrp} * {str} * A A abs / * A A * "
    \                                                  +"{Szrp} dup * {SdmpLo} + * A A * {SdmpLo} + {Szrp} dup * * / * 1 "
    \                                                  +"{SdmpHi} 0 == 0 {Szrp} 1 {SdmpHi} / * 4 ^ ? + 1 {SdmpHi} 0 == 0 A abs 1 {SdmpHi} / * 4 ^ ? + / * + ?"), scale_inputs="allf")
    \         : preblur!="OFF" && secure ? tmp.ex_makediff(ex_makediff(pre,pre.cas(min(Str, 1)).ex_lutxy(pre,secstr), fulls=fs), fulls=fs)
    \         : preblur!="OFF"           ? tmp.ex_makediff(ex_makediff(pre,pre.cas(min(Str, 1)), fulls=fs), fulls=fs) : secure ? pre.cas(min(Str, 1)).ex_lutxy(pre,secstr) : pre.cas(min(Str, 1))


    ### LIMIT
    normal = ex_clamp(normsharp, bright_limit, dark_limit, round(overshoot),  round(undershoot),  UV=1, fulls=fs)
    second = ex_clamp(normsharp, bright_limit, dark_limit, round(overshoot2), round(undershoot2), UV=1, fulls=fs)
    zero   = ex_clamp(normsharp, bright_limit, dark_limit,                 0,                  0, UV=1, fulls=fs)


    edge  = edgemaskHQ ? tmp.ex_edge(mode="x[-1,1] A@ x[0,1] 2 * B@ x[1,1] C@ + + x[-1,-1] F@ - x[0,-1] 2 * G@ - x[1,-1] H@ - F G H + + A - B - C - max " \
                                         +"A C - x[-1,0] 2 * D@ + x[1,0] 2 * E@ - F + H - C A - D - E + F - H + max max 2 *", lo=0, hi=255, UV=1, fulls=fs)
    \     :              tmp.ex_edge(mode="min/max",lo=0,hi=255,UV=1,fulls=fs)

    rhlf  = ex_bs(128, bi, fs)
    emHQn = ex_bs(32,  bi, fs)
    edge  = edgemaskHQ ?  edge.ex_lut(Format("x 1 {rhlf}  / * 0.86 ^ range_max *"), scale_inputs="floatf", clamp_float=true, fulls=fs)
    \     :               edge.ex_lut(Format("x 1 {emHQn} / * 0.86 ^ range_max *"), scale_inputs="floatf", clamp_float=true, fulls=fs)

    limit1 = Lmode<0  ? normsharp.repair(tmp,abs(Lmode),-1)
    \      : Lmode==0 ? normsharp
    \      : Lmode==1 ? normal
    \      : Lmode==2 ? ex_merge(normsharp, normal, edge.ex_inflate(), fulls=fs)
    \      : Lmode==3 ? ex_merge(normal,    zero,   edge.ex_inflate(), fulls=fs)
    \      :            ex_merge(second,    normal, edge.ex_inflate(), fulls=fs)

    limit2 = edgemode==0 ? limit1
    \      : edgemode==1 ? ex_merge(tmp,limit1,edge.ex_inflate().ex_inflate().ex_boxblur(1,mode="weighted",UV=1), fulls=fs)
    \      :               ex_merge(limit1,tmp,edge.ex_inflate().ex_inflate().ex_boxblur(1,mode="weighted",UV=1), fulls=fs)


    ### SOFT
    sharpdiff = ex_makediff(tmp,limit2,fulls=fs)
    sharpdiff = ex_lutxy(sharpdiff,sharpdiff.ex_boxblur(1,mode="mean",UV=1), Format("x range_half - abs y range_half - abs > y {soft} * x 100 {soft} - * + 1 100 / * x ?"),fulls=fs)

    PP1 = soft==0 ? limit2 : ex_makediff(tmp,sharpdiff,fulls=fs)


    ### SOOTHE
    diff  = ex_makediff(tmp,PP1,fulls=fs)
    diff2 = diff.temporalsoften(1,255,0,32,2)
    diff3 = ex_lutxy(diff,diff2,Format("x range_half - A@ y range_half - B@ * 0 < A {keep} 100 / * range_half + A abs B abs > x {keep} * y 100 {keep} - * + 1 100 / * x ? ?"),fulls=fs)

    PP2 = soothe ? ex_makediff(tmp,diff3,fulls=fs) : PP1


    ### OUTPUT
    out = sisupscale ?  tmp.mergeluma(PP2).spline36resize(dest_x,dest_y)
    \   : (ss_x > 1.0 || ss_y > 1.0)? PP2. spline36resize(dest_x,dest_y)
    \   :                             PP2

    src = !sode      ? nop()
    \   : sisupscale ? source.spline36resize(dest_x,dest_y)
    \   :                                   source
    in  = sisupscale ?  input.spline36resize(dest_x,dest_y)
    \   :                                   input

    shrpD  = ex_makediff(in,out,fulls=fs)
    shrpL  = sode ? shrpD.sh_Padding(4,4,4,4).repair(ex_makediff(in,src,fulls=fs).sh_Padding(4,4,4,4),1,-1,-1).crop(4,4,-4,-4,true).ex_lutxy(shrpD,"x range_half - abs y range_half - abs < x y ?",fulls=fs) : nop()
    output = sode ? ex_makediff(in,shrpL,fulls=fs) : out

    output = edgemode!=-1 ? output : !sisupscale ? edge.spline36resize(dest_x,dest_y) : edge.spline36resize(dest_x,dest_y).greyscale()


    ### SHOW
       function LSFM_Show(clip input, clip output, string "version", string "defaults",
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
       outW  = round( resoW / 4 ) * 4
       outH  = round( (outW * inH) / (4 * inW) ) * 4
       scale = resoH - ( 2 * outH )

       i = input.spline36resize(outW,outH)
       i = scale > 0 ? i.addborders(0,scale/4,0,scale/4) : i
       i = scale < 0 ? i.crop(0,-scale/4,0,scale/4,true) : i

       o = output.spline36resize(outW,outH)
       o = scale > 0 ? o.addborders(0,scale/4,0,scale/4) : o
       o = scale < 0 ? o.crop(0,-scale/4,0,scale/4,true) : o

       e = blankclip(input, width=384, height=resoH)
       e = e.SubTitle("LSFmod " + string(version)                ,text_color=$FFFFFF,font="COURIER NEW",size=24,x=40,y=40)
       e = e.SubTitle("DEFAULTS      = " + string(defaults)      ,text_color=$FFFFFF,font="COURIER NEW",size=12,x=40,y=100)

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
    \                    : LSFM_Show(inclip, output, version, defaults,
    \                                strength, Smode, Smethod,
    \                                preblur, secure, sode?"defined":"undefined",
    \                                Szrp, Spwr, SdmpLo, SdmpHi,
    \                                Lmode, overshoot, undershoot, overshoot2, undershoot2,
    \                                soft, soothe, keep,
    \                                edgemode, edgemaskHQ,
    \                                ss_x, ss_y, dest_x, dest_y,
    \                                show, screenW, screenH)

    output = output

    return output
}


function UnsharpMask_HBD(clip clp, float "strength", int "radius", float "threshold", int "UV", bool "fulls") {

  bi  = BitsPerComponent(clp)
  rgb = isRGB(clp)

  str      = Default(strength, 64)
  radius   = Default(radius,    3)
  thres    = Default(threshold, 8)
  UV       = Default(UV, rgb ?  3 : 1)
  fs       = Default(fulls, false)

  rd    = radius - 1
  str   = str/128.
  thres = ex_bs(thres,bi,fs)

  blurclip = ex_boxblur(clp, rd, mode="mean", UV=UV)

  e = Format("x y - A@ abs {thres} > A {str} * x + x ?")
  ex_lutxy(clp, blurclip, e, rgb?e:"", UV=UV) }

