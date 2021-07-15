###########################################################
###                                                      ##
###                                                      ##
###           Grade Pack v2.2 (15-07-2021)               ##
###                                                      ##
###    https://forum.doom9.org/showthread.php?t=182799   ##
###    https://forum.doom9.org/showthread.php?t=182881   ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###########################################################
###
### Look transforms pack for grading and look tone adjustments.
###
### Dependencies: > AviSynth+ 3.5
###                 ExTools
###                 Transforms Pack
###                 Utils-r41.avsi
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
    fON    = !SatC ? (Sat!=1.0) : false
    SatB   =  SatC || fON
    SatB   ? Assert   (SatC || isint(Sat) || isfloat(Sat),  "'Sat' only accepts float, integers or clip inputs")                                       : nop()
    RecMod ? Assert   (Recclp,                              "'Recover Mode' requires a clip defined in the 'Rc' parameter to recover saturation from") : nop()
    fmode  = SatB  ? fON : false
             Assert   (IsVersionOrGreater(3,5,0),           "Update AviSynth+ version")

    c
    w      = Width()
    h      = Height()
    padX   = w%4 == 0 ? 0 : (4 - w%4)
    padY   = h%4 == 0 ? 0 : (4 - h%4)
    clp    = PointResize(w+padX, h+padY, 0, 0, w+padX, h+padY)

    Recclp         ? Eval("""
    Rc
    wRc    = width()
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
              Assert(false, "Wrong Saturation Mode.")
    msk    =  BicubicResize(w+padX, h+padY,0.0,0.75).crop(0,0,-padX,-padY,true).MatchColorFormat(c)""")   : nop()


    show ?  msk          :  \
    (SatB                ?  \
    ((VibMod)            ?  \
           (fmode ? Expr(last, SwapUV(),"x",Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ range_half > x "+
                                                \+" x range_half - range_half x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ - range_half / {bias} ^ {sat} 1 - * 1 + * range_half + ?")) : \
                                          Expr(c,Sat,msk,"y","x range_max z - * y z * + range_max /",optSingleMode=true))              : \
     (DulMod)            ?  \
           (fmode ? Expr(last, SwapUV(),"x",Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^  range_half > x "+
                                                \+" x range_half - x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ {sat} 1 - * {bias} / 1 + / range_half + ?"))                           : \
                                          Expr(c,Sat,msk,"y","x range_max z - * y z * + range_max /",optSingleMode=true))              : \
     (RecMod)            ?  \
           (fmode ? Expr(last, SwapUV(),"x",Format("x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ range_half > x "+
                                                \+" x range_half - range_half x range_half - 2 ^ y range_half - 2 ^ +  .5 ^ - range_half / {bias} ^ {sat} 1 - * 1 + * range_half + ?")) : \
                                          Expr(c,Sat,msk,"y","x range_max z - * y z * + range_max /",optSingleMode=true)) : nop())     : c)

    !show     &&   fmode ? crop(0,0,-padX,-padY,true) : last }



###
###                 v3.0 (19-01-2014)
### ex_contrast() - v5.0 (15-07-2021)
###
###
### Applies contrast in the "S" (sigmoidal) curve fashion.
###
###
### Dependencies: > AviSynth+ 3.5
###                 ExTools
###
### Apply over gamma encoded clip
###
### Example: ex_contrast(0.7, 0.0, 127.5, true)
###
####################################


function ex_contrast (clip c, float "cont", float "sat", float "pivot", bool "tv_range", int "UV", bool "fulls") {

    rgb   = IsRGB(c)
    isy   = isy(c)
    bi    = BitsPerComponent(c)

    cont  = Default(cont, 0.0)             # [-1.0 to +1.0] can set further though
    sat   = Default(sat,  cont/1.5)        # [-1.0 to +1.0]
    pivot = Default(pivot, 127.5)          # Pivot: 64 to 192 (roughly)
    tv    = Default(tv_range, !rgb)        # TV or PC. Luma range of your source
    UV    = Default(UV,        rgb ? 3 : 1)
    fs    = Default(fulls,     rgb)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")


    rangePC  = tv ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV  = tv ? "ymax ymin - * ymin +"   : "  range_max *"

    sat    = sat != 0. ? (1.-max(min(sat, 1.), -1.))/2. - 0.5 : 0.
    cont   = pow(cont + sign(cont), 3.)
    rcont  = 1. / cont
    pivot  = pivot / 255.
    knee   = 1. / (1. + exp(cont *  pivot))
    shldr  = 1. / (1. + exp(cont * (pivot - 1.)))
    shmkn  = shldr - knee
    rshmkn = 1. / shmkn

    ycont  = "1 1 {cont} {pivot} "+rangePC+" - * exp + / {knee} - {rshmkn} * "+rangeTV+""
    yconti = "{pivot} 1 "+rangePC+" {shmkn} * {knee} + / 1 - log {rcont} * - "+rangeTV+""
    str    = cont != 0. ? ex_dlut(Format(cont > 0. ? ycont : yconti), bi, fs) : ""

    rangePCc  = tv ? "x range_half - range_max cmax cmin - / * range_half +" : "x"
    rangeTVc  = tv ?   "range_half - cmax cmin - range_max / * range_half +" : ""

    cstr = sat != 0. ? Format(""+string(1. - sat)+" "+rangePCc+" dup swap2 * range_max swap1 swap2 - {sat} * + "+rangeTVc+"") : "x"
    cstr = rgb ? str : ex_dlut(ex_UVexpr(cstr, UV, bi, rgb, fs), bi, fs)

    isy     ? Expr(c, str                                    ) : \
    UV == 1 ? Expr(c, str, ""                                ) : \
              Expr(c, str, cstr, scale_inputs=ex_UVf(rgb, bi)) }



###
### ex_levels() - v2.0 (15-07-2021)
###
###
### Works like internal Levels() but with HBD support out of the box (using autoscaling)
###
###
### Dependencies: > AviSynth+ 3.5
###                 ExTools
###
### Example: ex_levels(23, 1.200, 255, 0, 255, tv_range=true)
###
####################################


function ex_levels (clip c, int "input_low", float "gamma", int "input_high", int "output_low", int "output_high", bool "tv_range", int "UV", bool "fulls") {

    rgb  = IsRGB(c)
    isy  = isy(c)
    bi   = BitsPerComponent(c)

    ilo  = Default(input_low,      0)
    gam  = Default(gamma,        1.0)
    ihi  = Default(input_high,   255)
    olo  = Default(output_low,     0)
    ohi  = Default(output_high,  255)
    tv   = Default(tv_range, !rgb)
    UV   = Default(UV,        rgb ? 3 : 2)
    fs   = Default(fulls,     rgb)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

    rangePC = tv ? "x ymin - range_max ymax ymin - / *" : "x"
    rangeTV = tv ? " ymax ymin - range_max / * ymin + " : ""

    ilo = ex_bs( tv ? (ilo-16)*255./219. : ilo, bi, fs)
    ihi = ex_bs( tv ? (ihi-16)*255./219. : ihi, bi, fs)
    olo = ex_bs( tv ? (olo-16)*255./219. : olo, bi, fs)
    ohi = ex_bs( tv ? (ohi-16)*255./219. : ohi, bi, fs)
    iho = ihi - ilo
    oho = ohi - olo

    gm   = (gam == 1.0)                 ? ""             : string(1. / gam)+" ^ "
    iioo = (gam == 1.0) && (iho == oho) ? gm+string(oho) : Format("1 {iho} / * "+gm+" {oho} dup swap2 *")
    str  = ex_dlut(Format(""+rangePC+" {ilo} - 0 max "+iioo+" swap1 min {olo} + "+rangeTV+""), bi, fs)

    isy     ? Expr(c, str                                                          ) : \
    UV == 1 ? Expr(c, str, ""                                                      ) : \
              Expr(c, str, ex_UVexpr(str, UV, bi,rgb), scale_inputs=ex_UVf(rgb, bi)) }





# ported from cretindesalpes':
# http://forum.doom9.org/showthread.php?p=1516096#post1516096
# Similar to "dither_bits" argument from ConvertBits() but more flexible and more options.
function ex_posterize (clip c, int "bits", int "mode", int "UV", bool "fulls") {

    rgb  = IsRGB(c)

    bits = Default(bits,  3)    # Valid range: 0 - 7
    mode = Default(mode, -1)    # Valid modes: -1, 0 and 1
    UV   = Default(UV,    rgb ? 3 : 2)
    fs   = Default(fulls, rgb)

    mul  = string(Pow (2, 8 - bits - 1))
    bits = max(min(bits,7),0)

    ConvertBits(c,16,fulls=fs)
    ex_lut ("x "+mul+" /", y=3, UV=UV,fulls=fs)
    ConvertBits(8,dither=mode,fulls=fs)
    ex_lut ("x "+mul+" *", y=3, UV=UV,fulls=fs)
    ConvertBits(BitsPerComponent(c),fulls=fs) }



###
###              v1.0 (25-04-2019)
###              v2.0 (12-05-2021)
### Vignette() - v2.2 (22-06-2021)
###
###
### Adds a vignette (darkening around the frame) to the source.
### Use show=true if you only want the mask.
###
### Dependencies: > AviSynth+ 3.5
###                 ExTools
###
####################################


function Vignette (clip c, float "Vignette", bool "show", bool "fulls") {

    bi    = BitsPerComponent(c)
    str   = Default(Vignette, 0.8)
    show  = Default(show,  false)
    fs    = Default(fulls, IsRGB(c))

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

    msk = Expr(c, ex_dlut(Format("sx width 2 /  - abs width 2 / / range_max * 1.5 {str} 2 / + ^ range_max / 0 max "+ \
                                 "sy height 2 / - abs width 2 / / range_max * 1.5 {str} 2 / + ^ range_max / 0 max "+ \
                                 "+ range_max min range_max - abs "), bi, fs), "range_half","range_half")

    show ? msk : ex_blend(msk, c, mode="multiply", UV=4, fulls=fs) }



###
###
### greyscale_rgb()
###
###
### Properly convert PC.range RGB images to greyscale
###
### Dependencies: > AviSynth+ 3.5
###                 Transforms Pack
###
####################################

function greyscale_rgb (clip rgb, string "matrix", bool "fulls") {

    Assert(isRGB(rgb) == true, "Only works on PC range RGB.")
    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

    rgb
    fs     = Default (fulls, true)
    matrix = Default (matrix, "sRGB")
    matrix = Matrix_fuzzy_search(matrix)
    s_gam  = moncurve_coef(matrix)
    coeffs = RGB_to_XYZ(matrix, list=true)

    ConvertToPlanarRGB()

    moncurve_f(s_gam[0], s_gam[1], false, false, fulls=fs)

    DotClip(last, [coeffs[1],coeffs[4],coeffs[7]])

    moncurve_r(s_gam[0], s_gam[1], false, false, fulls=fs) }



###
###
### WhitePoint()
###
###
### Accurately adjust the color temperature of the image
###
### Dependencies: > AviSynth+ 3.5
###                 Transforms Pack
###                 ExTools
###                 Utils-r41
###
####################################

function WhitePoint (clip c, int "temperature", string "matrix", bool "tv_range", bool "fulls") {

    rgb = IsRGB(c)

    temp     = Default (temperature, 6504)  # Target temperature in Kelvin units (Default: D65 == nop())
    matrix   = Default (matrix, "709")
    tv_range = Default (tv_range, !rgb )
    fs       = Default (fulls,     rgb)

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")

    matrix = Matrix_fuzzy_search (matrix)
    s_gam  = moncurve_coef(matrix)

    RGBpln = rgb ? IsPlanar(c) : false

    rgb ? RGBpln ? c : ConvertToPlanarRGB(c) : \
    YUV_to_RGB(c, matrix, tv_range_in=tv_range, tv_range_out=false, kernel="Point", cplace="", fulls=fs)

    temp3 = 1000.       /     temp
    temp6 = 1000000.    / pow(temp, 2.)
    temp9 = 1000000000. / pow(temp, 3.)

    wpx = (temp <= 7000.) ? 0.244063 + 0.09911 * temp3 + 2.9678 * temp6 - 4.6070 * temp9 : \
                            0.237040 + 0.24748 * temp3 + 1.9018 * temp6 - 2.0064 * temp9

    wpy = -3. * pow(wpx,2.) + 2.870 * wpx - 0.275
    wpz =  1. - wpx - wpy

    CAT02 = [0.7328,  0.4296, -0.1624, \
            -0.7036,  1.6975,  0.0061, \
             0.0030, -0.0136,  0.9834]

    fw1      = MatrixDot([0.950450,1.,1.088917],CAT02)
    fw2      = MatrixDot([wpx/wpy, 1.,wpz/wpy] ,CAT02)
    trans    = MatrixDiv(fw2,fw1)

    vonkries = [trans[0], 0.0000,  0.0000,  \
                0.0000, trans[1],  0.0000,  \
                0.0000,   0.0000, trans[2]]

    CAM      = MatrixDot(CAT02, MatrixDot(vonkries, MatrixInvert(CAT02)))

    moncurve_f(s_gam[0], s_gam[1], false, false, 1, fs)

    mata = RGB_to_XYZ (matrix, list=true)
    matb = XYZ_to_RGB (matrix, list=true)
    MatrixClip( MatrixDot(MatrixDot(mata, CAM), matb) )

    moncurve_r(s_gam[0], s_gam[1], false, false, 1, fs)

    rgb ? RGBpln ? last : MatchColorFormat(c) : \
    RGB_to_YUV( matrix, tv_range_in=false, tv_range_out=tv_range, kernel="Point", pixel_type=PixelType(c), cplace="", fulls=fs) }
