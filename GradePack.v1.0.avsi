###########################################################
###                                                      ##
###                                                      ##
###           Grade Pack v1.0  (12-05-2021)              ##
###    https://forum.doom9.org/showthread.php?t=182799   ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###########################################################
###
### Pack of tools for grading and look tone adjustments.
###
### No Dependencies.
###
###
####################################
###
### SatMask() v2.0 (12-05-2021)
###
### 20-11-2011
### by Motenai Yoda:  (http://forum.doom9.org/showthread.php?t=162882)
### and Gavino's help
###
### Saturation Mask
### This function allows to recreate the effect on some programs called "Vibrance".
### That is to enhance saturation where it is low.
### There is another mode called "Dullness" which does the opposite, lowers saturation where is high.
### Finally a "Recover" mode, to enhance saturation where is lost (after filtering) when a Rc clip is given for reference.
###
### Use 'bias' to weight the internal mask and 'show' for visual feedback.
### You can use a (de)saturated clip as input for the "Sat" parameter as its replacement, or use a float number for around a 3x speed gain.
### The downside for using a number instead is less control compared to your preferred 'saturator'
### Input must be at least mod 4. Working values are assumed to be above 1.0. Values < 1.0 can create some artifacts.
###
### Use like this (recommended):
###
### sat=Tweak(1.5)
### satmask(sat)   # Mandatory to write parameter "sat=" when using a clip
###
### or like this (more speed):
###
### satmask(1.5)
###
###########################
### TODO
### Dullness not correctly ported over
### "Recover" in fast mode not yet implemented

function SatMask (clip c, val Sat, float "bias", string "mode", clip "Rc", bool "show") {

    bias  = Default(bias, 5)
    mode  = Default(mode,  "Vibrance")
    show  = Default(show, false)

    VibMod = mode=="Vibrance"
    DulMod = mode=="Dullness"
    RecMod = mode=="Recover"
    Recclp = Defined(Rc)
    SatC   = isclip(Sat)
    fON    = !SatC ? (Sat!=1.0 ? true : false) : false
    SatB   =  SatC || fON
    SatB   ? Assert   (SatC || isint(Sat) || isfloat(Sat),  "'Sat' only accepts float, integers or clip inputs")                                       : nop()
    RecMod ? Assert   (Recclp,                              "'Recover Mode' requires a clip defined in the 'Rc' parameter to recover saturation from") : nop()
    fmode  = SatB  ? fON : false


    c
    w      = Width ()
    h      = Height()
    padX   = w%4 == 0 ? 0 : (4 - w%4)
    padY   = h%4 == 0 ? 0 : (4 - h%4)
    clp    = PointResize(w+padX, h+padY, 0, 0, w+padX, h+padY)

Recclp         ? Eval("""
Rc
wRc    =  width()
hRc    = height()
padXRc = wRc%4 == 0 ? 0 : (4 - wRc%4)
padYRc = hRc%4 == 0 ? 0 : (4 - hRc%4)
Rc     = PointResize(wRc+padXRc, hRc+padYRc, 0, 0, wRc+padXRc, hRc+padYRc)


a      =  RecMod                    ? Expr(ExtractV(Rc),ExtractU(Rc), Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ range_half > range_max x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ {bias} * ?"))  : nop()"""  ) : nop()


clp

!fmode || show ? Eval("""
b      =  DulMod || RecMod          ? Expr(ExtractV(),  ExtractU(), Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ range_half > range_max x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ {bias} * ?"))    : nop()


msk    = (VibMod)                   ? Expr(ExtractV(),  ExtractU(), Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ range_half > range_min range_half x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ - range_half / {bias} ^ range_max * ? ")) : \
         (DulMod)                   ? b                                                          : \
         (RecMod)                   ? Expr(a,b,"x y - abs 2 *")                                  : \
          Assert(false, "Wrong Saturation Mode")
msk    =  BicubicResize(w+padX, h+padY,0.0,0.75).crop(0,0,-padX,-padY).MatchColorFormat(c)""")   : nop()


show ?  msk          :  \
(SatB                ?  \
((VibMod)            ?  \
       (fmode ? Expr(last, SwapUV(),"x",Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ range_half > x "+
                                            \+" x range_half - range_half x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ - range_half / {bias} ^ {sat} 1 - * 1 + * range_half + ?")) : \
                                      Expr(c,Sat,msk,"y","x range_max z - * y z * + range_max /"))              : \
 (DulMod)            ?  \
       (fmode ? Expr(last, SwapUV(),"x",Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^  range_half > x "+
                                            \+" x range_half - x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ {sat} 1 - * {bias} / 1 + / range_half + ?"))                           : \
                                      Expr(c,Sat,msk,"y","x range_max z - * y z * + range_max /"))              : \
 (RecMod)            ?  \
       (fmode ? Expr(last, SwapUV(),"x",Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ range_half > x "+
                                            \+" x range_half - range_half x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ - range_half / {bias} ^ {sat} 1 - * 1 + * range_half + ?")) : \
                                      Expr(c,Sat,msk,"y","x range_max z - * y z * + range_max /")) : nop())     : c)

!show     &&   fmode ? crop(0,0,-padX,-padY) : last }



###
###                    v3.0 (19-01-2014)
### SmoothContrast() - v4.1 (12-05-2021)
###
###
### Applies contrast in the "S" (sigmoidal) curve fashion.
###
###
### Dependencies: Avisynth+ r2420 and above
###
### Performs better in gamma encoded space
###
### Example: SmoothContrast(0.7, 128, 0.0, true)
###
####################################


function SmoothContrast (clip c, float "cont", int "pivot", float "sat", bool "tv_range") {


    cont    = Default(cont, 0.0)             # [-1.0 to +1.0] can set further though
    sat     = Default(sat,  cont/1.5)        # [-1.0 to +1.0]

    ptype  = IsRGB(c)
    range   = Default(tv_range, !ptype)      # TV or PC. Luma range of your source
                                             # Pivot: 64 to 192 (roughly)
    pivot   = Defined(pivot) ? range ? (pivot-16.)/219. : pivot/255. : range ? 0.50913 : 0.5

    Assert(AvsPlusVersionNumber > 2294, "Update Avisynth+ version")
    contoy   = !isy(c)

    cont    = pow(cont + sign(cont), 3.)
    sat     = sat != 0. ? (1.-max(min(sat, 1.), -1.))/2. - 0.5 : 0.

    rangePC  = range ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV  = range ? "ymax ymin - * range_max / ymin +" : ""
    str    = "1 1 {cont} {pivot}"
    knee   = str + " * exp + /"
    shldr  = str + " 1 - * exp + /"
    ycont  = ""+knee+" A^ "+str+" "+rangePC+" - * exp + / A - "+shldr+" A - / range_max * "+rangeTV+""
    yconti = ""+knee+" A^ {pivot} 1 "+rangePC+" "+shldr+" A - * A + / 1 - log {cont} / - range_max * "+rangeTV+""
    cntrst = cont != 0. ? cont > 0. ? Format(ycont) : Format(yconti) : ""

    rangePCc  = range ? "x range_half - cmax cmin - / range_max * range_half +" : "x"
    rangeTVc  = range ?   "range_half - cmax cmin - * range_max / range_half +" : ""

    strtn  = contoy ? ptype ? cntrst : sat != 0. ? Format(""+rangePCc+" A^ 1 {sat} - A * {sat} range_max A - * + "+rangeTVc+"") : "" : Undefined

    Expr(c, cntrst, strtn, strtn) }


###
### SmoothLevels() - v1.0 (12-05-2021)
###
###
### Works like internal Levels() but works with HBD out of the box (using autoscaling)
###
###
### Dependencies: Avisynth+ r2420 and above
###
### Example: SmoothLevels(16, 1.200, 255, 0, 255)
###
####################################


function SmoothLevels (clip c, int "input_low", float "gamma", int "input_high", int "output_low", int "output_high", bool "tv_range") {


    ilo    = Default(input_low,     0)
    gam    = Default(gamma,       1.0)
    ihi    = Default(input_high,  255)
    olo    = Default(output_low,    0)
    ohi    = Default(output_high, 255)

    ptype  = IsRGB(c)
    range   = Default(tv_range,!ptype)

    Assert(AvsPlusVersionNumber > 2294, "Update Avisynth+ version")
    contoy   = !isy(c)

    rangePC  = range ? "x ymin - ymax ymin - / range_max *" : "x"
    rangeTV  = range ? "ymax ymin - * range_max / ymin +" : ""
    gam = 1.0 - gam
    lvl  = Format("range_max range_min "+rangePC+" {ilo} scaleb - {ihi} scaleb {ilo} scaleb - / max min {gam} abs 1 + {gam} ^ ^ {ohi} scaleb {olo} scaleb - * {olo} scaleb + "+rangeTV+"")

    lvlgb  = contoy ? ptype ? lvl : "" : Undefined

    Expr(c, lvl, lvlgb, lvlgb) }


###
###              v1.0 (25-04-2019)
### Vignette() - v2.0 (12-05-2021)
###
###
### Adds a vignette (darkening around the frame) to the source.
### Use show=true if you only want the mask.
###
###
####################################

function Vignette (clip c, float "Vignette", bool "show") {

    str   = Default(Vignette, 0.7)
    show  = Default(show, false)

    msk = Expr(c, Format("sx width 2 /  - abs width 2 / / range_max * 1.5 {str} 2 / + ^ range_max / 0 max "+ \
                         "sy height 2 / - abs width 2 / / range_max * 1.5 {str} 2 / + ^ range_max / 0 max "+ \
                         "+ range_max - abs"), "range_half","range_half")

    # this is multiply blend mode
    show ? msk : Expr(msk,c,"x y * range_max / ", "y", "y")

}
