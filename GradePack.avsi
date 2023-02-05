###########################################################
###                                                      ##
###                                                      ##
###           Grade Pack v8.2 (04-02-2023)               ##
###                                                      ##
###    https://forum.doom9.org/showthread.php?t=182881   ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
###                                                      ##
### Functions:                                           ##
###     ex_vibrance                                      ##
###     ex_contrast                                      ##
###     ex_levels                                        ##
###     ex_autolevels                                    ##
###     ex_blend                                         ##
###     ex_glow                                          ##
###     ex_posterize                                     ##
###     Skin_Qualifier                                   ##
###     HSVxHSV                                          ##
###     GamutWarning                                     ##
###     PseudoColor                                      ##
###     Vignette                                         ##
###     greyscale_rgb                                    ##
###     FindTemp                                         ##
###     GreyWorld                                        ##
###     WhitePoint                                       ##
###     Curve Fitting Evaluator                          ##
###                                                      ##
###                                                      ##
###########################################################
###
###
### Pack of artistic look transform functions for grading and look tone adjustments.
###
###
####################################


###
### ex_vibrance() v4.0 (31-03-2022)
###
### Inspired by Motenai Yoda's script (20-11-2011): (https://forum.doom9.org/showthread.php?t=162882)
###
### This function allows to recreate the effect on some programs called "Vibrance".
### That is to enhance saturation where is low.
### There is another mode called "Dullness" which does the opposite, lower saturation where is high.
### Finally a "Recover" mode, to enhance saturation where is lost (ie. after filtering) when a 'Rc' clip is given for reference.
###
### Use 'bias' to weight the internal mask and 'show' for visual feedback.
###
### Dependencies: > ExTools
###                 ResizersPack   (for show=1)
###                 TransformsPack (for show=1)
###                 MasksPack      (for show=1)
###
### modes:
###     Saturation: Simple saturation operator without any masks
###     Vibrance:   Masks high saturation so you can lower or raise saturation where is low (Default)
###     Dullness:   Masks low  saturation so you can lower or raise saturation where is high
###     Recover:    Recover lost saturation (full or partial) between source and reference clip.
###
###
### Examples:
###     ex_vibrance(1.2, mode="Saturation")    # Increase saturation
###
###     ex_vibrance(1.5)                       # Increase vibrance (increase saturation where is low)
###
###     ex_vibrance(0.5)                       # Lower saturation where is low
###
###     ex_vibrance(2.0, mode="Dullness")      # Lower saturation where is high (could help for out-of-gamut cases)
###
###     ex_vibrance(1.0, mode="Recover", Rc=b) # Recover saturation from clip 'b'
###
###     ex_vibrance(0.5, mode="Recover", Rc=b) # Recover half the saturation from clip 'b'
###
### Function Definition:
###    (
###    clip yuv,
###    float sat=1.00 (0.00 to 2.00),
###    string "mode"="Vibrance" ("Vibrance"/ "Dullness"/ "Saturation"/ "Recover"),
###    [clip "Rc"],
###    float "bias"=5.0 (0.0 to 10.0 by 0.5),
###    int "show"=0 (0 to 2)
###    )
###
###########################

function ex_vibrance (clip a, float "sat", string "mode", float "bias", clip "Rc", bool "tv_range", int "show") {

    bi    = BitsPerComponent(a)
    fs    = propNumElements (a,"_ColorRange")  > 0 ? \
            propGetInt      (a,"_ColorRange") == 0 : false
    bi32  = bi==32

    sat   = Default(Sat,  1)          # From 0 to inf. Default 1 (no-op)
    bias  = Default(bias, 5)          # Adjust saturation mask
    md    = Default(mode, "Vibrance")
    tv    = Default(tv_range,    !fs)
    sh    = Default(show,          0) # 0: disabled, 1: show histogram and gamut warning, 2: show mask (resized to luma dimensions) 3: show mask at original size
    sat   = max(sat, 0)
    Rec   = FindStr(LCase(md),"recover") > 0

          Assert(IsVersionOrGreater(3,7,2), "ex_vibrance: Update AviSynth+ version")
          Assert(!isRGB(a),                 "ex_vibrance: RGB format not supported")
    Rec ? Assert(Defined(Rc),               "ex_vibrance: 'Recover' mode requires a clip defined in the 'Rc' parameter to recover saturation from") : nop()

    rangePCc = tv ? "range_max cmax cmin - / *"              : ""
    rangeTVc = tv ? "cmax cmin - range_max / * range_half +" : "range_half +"

    rhlf = bi32 ? "2 *" : bi > 12 ? "range_half /" : string(1. / ex_bs(128,8,bi,!tv)) + " *"
    msk  = Format("range_half x range_half - XC@ dup * y range_half - dup * + sqrt - "+rhlf+" {bias} ^ M^ ")

    mode = md == "Vibrance"   ? Format(       msk+" XC "+rangePCc+" dup dup   {sat}   * swap -   M   * + "   +rangeTVc) : \
           md == "Dullness"   ? Format(       msk+" XC "+rangePCc+" dup dup 1 {sat} / * swap - 1 M - * + "   +rangeTVc) : \
           md == "Saturation" ? Format("x range_half - "+rangePCc+"           {sat}                  *   "   +rangeTVc) : \
           md == "Recover"    ? " XC "+rangePCc+Format(sat==1 ? " * " : " dup dup swap3 * swap - {sat} * + ")+rangeTVc  : \
           md == "Recover2"   ? " XC "+rangePCc+Format(sat==1 ? " * " : " dup dup swap3 * swap - {sat} * + ")+rangeTVc  : \
          Assert (false, "ex_vibrance: '"+md+"', unsupported mode")

    # 'Recover' mode masks
    msk1  = "x range_half - XC@ abs y range_half - abs + 0.000001 + "
    msk2  = "z range_half -     abs a range_half - abs + "
    # 'Saturation' blend mode masks
    msk21 = "x range_half - XC@ abs y range_half - abs + M max"
    msk22 = "z range_half -     abs a range_half - abs + ymin 0.5 * M@ max "
    msk1  = md == "Recover2" ? msk21 : msk1
    msk2  = md == "Recover2" ? msk22 : msk2

    if (md == "Saturation" && sh==0) {

        sat == 1 ? a   :                  \
        ex_lut    (a, "", mode, fulls=!tv )

    } else \
    if (Rec                && sh==0) {

        ex_lutxyza(a, a.SwapUV(), Rc, Rc.SwapUV(), "", fulls=!tv, cstr=msk2+msk1+" / "+mode)

    } else {

        if (sat==1         && sh==0) { a } else {

        rangePCc = tv      ?        "range_max cmax cmin - / *"   : ""
        offset   = !bi32   ?        " 0.5 - "                     : ""
        bias     = bias!=1 ? Format("1 swap - {bias} ^ 1 swap -") : ""

        Rec ? \
        ex_lutxyza(a, a.SwapUV(), Rc, Rc.SwapUV(), "", fulls=!tv, cstr=msk2+msk1+" / "+mode) : \
        ex_lutxy  (a, a.SwapUV(),                  "", fulls=!tv, cstr= sh != 2 ?      mode  : \
        Format("f32 x "+rangePCc+" dup * y "+rangePCc+" dup * + sqrt "+bias+offset+" "), scale_inputs=bi32 ? "floatUV" : tv ? "int" : "intf")

        w  = a.width()
        h  = a.height()

        if (sh==1) {

            bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
            lvl = Histogram(mode="levels",keepsource=false)
            lvl = StackVertical(lvl,Vectorscope()).RatioResize(h/512.,"%",kernel="gauss",p=100)
            lvl = tv?lvl.SMPTE_Legal(false):lvl
            StackHorizontal(GamutWarning(),lvl)

        } else if (sh>1) {
            ExtractU()
            propDelete(["_Matrix","_Primaries","_Transfer","_PictType"])
            propSet("_ColorRange", 0)
            sh==2 ? BicubicResize(w,h,0.679623,0.160189) : last } } } }




###
###
### ex_contrast() - v7.2 (29-10-2022)
###
###
### Applies contrast in the "S" (sigmoidal) curve fashion.
###
###
### Dependencies: > ExTools
###                 ResizersPack   (for show=true)
###                 MasksPack      (for show=true)
###
### Apply over gamma encoded clip
###
### Examples:
###     ex_contrast(0.7)             # Default pivot=125.5 is mid-grey for TV range sources (Color range read from frameprops)
###     ex_contrast(0.786,pivot=83)  # DCP Tone Curve - Adobe Camera Raw's default fallback film curve
###
### Function Definition:
###    (
###    clip,
###    float cont=0.00 (-1.00 to 1.00),
###    float "sat"=1.00 (0.00 to 3.00),
###    float "pivot"=125.5 (64.0 to 192.0 by 0.5),
###    [int "UV"=3 (1 / 2 / 3)],
###    bool "show"=false
###    )
###
####################################

function ex_contrast (clip c, float "cont", float "sat", float "pivot", bool "tv_range", int "UV", bool "show") {

    rgb   = isRGB(c)
    isy   = isy(c)
    bi    = BitsPerComponent(c)
    fs    = propNumElements (c,"_ColorRange")  > 0 ? \
            propGetInt      (c,"_ColorRange") == 0 : rgb
    lut   = isRunTime(c,rgb) || bi == 32 ? 0 : 1

    UV    = Default(UV, Defined(sat) && sat!=1 || rgb ? 3 : 1)
    cont  = Default(cont, 0.0)                     # [-1.0 to +1.0] can set further though
    sat   = Default(sat,  (cont+3)/3)              # [ 0.0 to +inf] 1.0 is noop. By default can't be disabled in RGB
    sh    = Default(show,      false)              # Show the contrast curve
    tv    = Default(tv_range, !fs)                 # TV or PC. Color range of your source
    pivot = Default(pivot,    !tv ? 127.5 : 125.5) # Pivot: 64 to 192 (roughly)
    si    = bi == 32 || tv ? ex_UVf(rgb, bi) : "intf"

    # Pointer for 'show'
    sc = cont
    ss = sat
    sp = pivot
    ep = 0.000001

    pivot = ex_bs(pivot, 8, 32, tv_in=tv || tv && 125.4 < pivot <= 126, tv_out=false) # Pivot to float PC levels

    Assert(IsVersionOrGreater(3,7,2), "ex_contrast: Update AviSynth+ version")

    rangePC  = tv ? "x ymin - ymax ymin - /"                   : "x "
    rangeTV  = tv ? "ymax ymin - * ymin +"                     : ""
    rangePCc = tv ? "x range_half - range_max cmax cmin - / *" : "x range_half -"
    rangeTVc = tv ? "cmax cmin - range_max / * range_half  +"  : "  range_half +"

    cont   = pow(cont + sign(cont), 3.)
    rcont  = 1. / (cont + ep)

    knee   = 1. / (1. + exp(cont *  pivot))
    shldr  = 1. / (1. + exp(cont * (pivot - 1.)))
    shmkn  = shldr - knee
    rshmkn = 1. / shmkn

    ycont  = "f32 1 1 {cont} {pivot} "+rangePC+" - * exp + / {knee} - {rshmkn} * "+rangeTV
    yconti = "f32 {pivot} 1 "+rangePC+" {shmkn} * {knee} + 0.01 max / 1 - log {rcont} * - "+rangeTV
    str    = cont != 0. ? ex_dlut(Format(cont > 0. ? ycont : yconti), bi, !tv) : ""

    cstr = sat != 1. ? Format(rangePCc+" {sat} * "+rangeTVc) : ""
    cstr = rgb ? str : sat==1 ? "" : ex_UVexpr(cstr, UV, bi, rgb, !tv, si)

    isy     ? Expr(c, str      , lut=lut, scale_inputs=si) : \
    UV == 1 ? Expr(c, str, ""  , lut=lut, scale_inputs=si) : \
              Expr(c, str, cstr, lut=lut, scale_inputs=si)

    if (sh) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
        w   = c.width()
        h   = c.height()
        sw  = nmod(w/5.)   sh = min(h,sw)
        plt = GradientLinear(last,zoom=1, precision=2, positive=true, smooth=true, tv_range=tv)
        plt = ex_contrast (plt,sc,ss,sp,tv,128)
        plt = HistoCurve(plt,size=2,gradient=false).BicubicResize(sw,sh,-0.5,0.25)
        plt = rgb ? plt.ConvertToPlanarRGB() : plt
        plt = Merge(PadBorders(plt,w-sw,0,0,h-sh))
        ex_merge(plt,BoxMask(w-sw,w,0,sh),UV=3)
    } }




###
###
### ex_levels() - v4.2 (14-04-2022)
###
###
### Works like internal Levels() but with HBD support out of the box (using autoscaling)
### ...and proper handling of tv range levels. Includes also a 'show' mode.
###
### Dependencies: > ExTools
###                 ResizersPack   (for show=true)
###                 TransformsPack (for show=true)
###                 MasksPack      (for show=true)
###
### Example: ex_levels(23, 1.200, 255, 0, 255, tv_range=true)
###
### Formula = ((input - input_low) / (input_high - input_low)) ^ (1/gamma) * (output_high - output_low) + output_low
###
### Function Definition:
###    (
###    clip,
###    float input_low=0.0 (0.0 to 255.0 by 1),
###    float gamma=1.00 (0.00 to 3.00),
###    float input_high=255.0 (0.0 to 255.0 by 1),
###    float output_low=0.0 (0.0 to 255.0 by 1),
###    float output_high=255.0 (0.0 to 255.0 by 1),
###    int "UV"=3 (1 / 2 / 3),
###    [bool "show"=false]
###    )
###
### Benchmark:
### 100.0% Levels       (10*256, 1.40, 245*256, 10*256, 255*256, false, false) (495fps)
###  93.7% ex_levels    (10,     1.40, 245,     10,     255,     false, 1)
###  16.0% oSmoothLevels(10,     1.40, 245,     10,     255,         0, 0)
###
####################################

function ex_levels (clip c, float "input_low", float "gamma", float "input_high", float "output_low", float "output_high", bool "tv_range", int "UV", bool "show", bool "clamp_float") {

    rgb  = isRGB(c)
    isy  = isy(c)
    bi   = BitsPerComponent(c)
    fs   = propNumElements (c,"_ColorRange")  > 0 ? \
           propGetInt      (c,"_ColorRange") == 0 : rgb
    bi32 = bi == 32
    lut  = isRunTime(c,rgb) || bi32 ? 0 : 1

    ilo  = Default(input_low,      0)
    gam  = Default(gamma,        1.0)
    ihi  = Default(input_high,   255)
    olo  = Default(output_low,     0)
    ohi  = Default(output_high,  255)
    tv   = Default(tv_range,     !fs)
    sh   = Default(show,       false)
    cf   = Default(clamp_float, bi32)
    UV   = Default(UV,   rgb ? 3 : 2)
    si   = ex_UVf(rgb, bi)

    # Storing for 'show'
    silo = ilo
    sgam = gam
    sihi = ihi
    solo = olo
    sohi = ohi
    ep   = 0.000001

    Assert(IsVersionOrGreater(3,7,2), "ex_levels: Update AviSynth+ version")

    rangePC  = tv ? "x ymin - range_max ymax ymin - / * "        : "x "
    rangeTV  = tv ? " ymax ymin - range_max / * ymin + "         : ""
    rangePCc = tv ? "x range_half - range_max cmax cmin - / * "  : "x range_half - "
    rangeTVc = tv ? " cmax cmin - range_max / * range_half + "   : "  range_half + "

    ilo = ex_bs( ilo, 8, bi, tv_in=tv, tv_out=false, flt=true)
    ihi = ex_bs( ihi, 8, bi, tv_in=tv, tv_out=false, flt=true)
    olo = ex_bs( olo, 8, bi, tv_in=tv, tv_out=false, flt=true)
    ohi = ex_bs( ohi, 8, bi, tv_in=tv, tv_out=false, flt=true)
    iho = ihi - ilo
    oho = ohi - olo
    ilo = ilo == 0 ? "" : Format(" {ilo} - ")
    olo = olo == 0 ? "" : Format(" {olo} + ")

    gm   = (gam == 1.0)                 ? ""             : string(1. / gam)+" ^ "
    iioo = (gam == 1.0) && (iho == oho) ? gm+string(oho) : Format(" 1 {iho} / * "+gm+" {oho} dup swap2 *")
    str  = ex_dlut("" + rangePC + ilo + " 0 max " + iioo + " swap1 min " + olo + rangeTV, bi, !tv)

    crg  = ex_bs( tv ? 224 : 255, 8, bi, fulls=!tv)
    oho  = oho / (crg + ep)
    iho  = crg / (iho + ep)
    rt   = oho * iho
    cstr = rgb ? str : ex_UVexpr(Format(rangePCc + " {rt} * " + rangeTVc), UV, bi, rgb, !tv, si)

    isy     ? Expr(c, str      ,                  lut=lut, clamp_float=bi32) : \
    UV == 1 ? Expr(c, str, ""  ,                  lut=lut, clamp_float=bi32) : \
              Expr(c, str, cstr, scale_inputs=si, lut=lut, clamp_float=bi32)

    if (sh) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
        w   = c.width()
        h   = c.height()
        lvl = Histogram(mode="levels",keepsource=false)
        plt = GradientLinear(last,zoom=1, positive=true, precision=2, smooth=true, tv_range=tv)
        plt = ex_levels (plt,silo,sgam,sihi,solo,sohi,tv,128)
        plt = HistoCurve(plt,size=1,gradient=false)
        pls = StackVertical(rgb ? plt.ConverttoPlanarRGB() : plt,lvl).RatioResize(h/512.,"%",b=-0.5,c=0.25)
        plt = PadBorders(tv?pls.SMPTE_Legal(false):pls,w-width(pls),0,0,0)
        plt = Merge(plt)
        ex_merge(last,plt,BoxMask(w-width(pls),w,0,h),UV=3) } }


###
### ex_autolevels()
###
### Wrapper for ex_levels() with SceneStats().
### Performs auto-levels on a per-scene basis.
###
function ex_autolevels (clip c, float "interval", float "th", bool "tv_range", bool "gamma") {

    c
    rgb  = isRGB()
    bi   = BitsPerComponent()
    rn   = propNumElements ("_SceneRange")  > 0
    st   = propNumElements ("_SceneStats")  > 0
    fs   = propNumElements ("_ColorRange")  > 0 ? \
           propGetInt      ("_ColorRange") == 0 : rgb

    in   = Default(interval,  0.5)      # Interval in seconds for fetching frames
    th   = Default(th,        0.1)      # 1/1000 threshold (0.1% or 1‰ -one per-mille-)
    tv   = Default(tv_range,  !fs)
    gm   = Default(gamma,    true)

    Assert(IsVersionOrGreater(3,7,3), "ex_autolevels: Update AviSynth+ version")
    Assert(rn,                        "ex_autolevels: '_SceneRange' frame properties are required")
    !st ? SceneStats("Stats",in,th) : last

    ScriptClip(function [tv,rgb,th,gm] () {

        sts  = propGetAsArray("_SceneStats")
        cst  = PlaneMinMaxStats(last,th,0,0,false)
        pmin = sts[2]
        pmax = sts[1]
        scn  = (sts[6] -   pmin) / (pmax   - pmin)          # New scene average after normalization
        cur  = (cst[5] - cst[2]) / (cst[1] - cst[2])        # New frame average after normalization
        pavg = scn/cur                                      # Divide to keep gamma to scene's IQM average

        ex_levels(pmin,gm?pavg:1.,pmax,0,255,tv,rgb?3:1)
    } ) }



###
###
### ex_blend() - v4.4 (09-11-2022)
###
###
### Works like Overlay() but supports more modes (55 in total), better handling of TV range and performs much faster in either 8-bit or HBD (YUV or RGB).
###
###
### Dependencies: > ExTools
###                 TransformsPack (for mode='hue')
###
### Example: ex_blend(a, mode="multiply", opacity=1.0, tv_range=true, UV=2)
###
### Function Definition:
###    (
###    clip a,
###    clip b,
###    string "mode"="multiply" ("normal"/ "blend"/ "interpolation"/ "harmonic"/ "geometric"/ "watermark"/ "--"/ "darker"/ "darken"/ "darkenS"/ "multiply"/ "multiply128"/ "softburn"/ "colorburn"/ "linearburn"/ "--"/ "lighter"/ "lighten"/ "lightenS"/ "screen"/ "softdodge"/ "colordodge"/ "lineardodge"/ "linearadd"/ "--"/ "overlay"/ "softoverlay"/ "hardoverlay"/ "softlight"/ "hardlight"/ "vividlight"/ "linearlight"/ "stamp"/ "pinlight"/ "hardmix"/ "reflect"/ "glow"/ "freeze"/ "heat"/ "--"/ "grainextract"/ "grainmerge"/ "--"/ "difference"/ "softdifference"/ "negation"/ "exclusion"/ "subtract"/ "linearsubtract"/ "from"/ "divide"/ "andn"/ "bleach"/ "extremity"/ "stain"/ "phoenix"/ "--"/ "hue"/ "saturation"/ "color"/ "value"),
###    float "opacity"=1.00 (0.00 to 1.00),
###    [float "watermark"=1.0 (0.0 to 2.0)],
###    [int "UV"=3 (1 / 2 / 3)]
###    )
###
####################################
###
### 100% ex_blend   (a, mode="multiply")
###  99% OverlayPlus(a, mode="multiply",chroma=false) # only in PC range
###  92% Overlay_MTools(mode="multiply")              # only in PC range
###  56% Overlay       (mode="multiply")              # only in PC range
###
### MODES:
### SYMMETRIC
### normal         - Simply returns the Top layer
### blend          - Linear interpolation of Base and Top layer by opacity setting
### interpolation  - Cosine interpolation. Output is similar to 'blend' mode but more contrasty ('S' shaped) interpolation
### harmonic       -
### geometric      -
### watermark      -
###
### DARK
### darker         - (RGB only) Returns the RGB values from the Base or Top layers with the lowest absolute summed R+G+B value
### darken         - Keep only the darkest colors from either Base or Top layers
### darkenS        - Keep only the darkest colors from either Base or Top layers using a "smooth min" polynomial (from Iñigo Quilez articles)
### multiply       - Multiply Base with Top layer (a * b)
### multiply128    -
### softburn       - A softer ColorBurn, actually a combination of ColorBurn and the inverse of ColorDodge.
### colorburn      - Like an inverted 'screen', but instead of multiplying it by the complementary of Top layer, it's divided directly by it. 1 - ( 1 - a) / b
### linearburn     -
###
### LIGHT
### lighter        - (RGB only) Returns the RGB values from the Base or Top layers with the highest absolute summed R+G+B value
### lighten        - Keep only the lightest colors from either Base or Top layers
### lightenS       - Keep only the lightest colors from either Base or Top layers using a "smooth max" polynomial (from Iñigo Quilez articles)
### screen         - Multiply the complement (invert) of Base and Top layers and invert back the result.  1 - (1 - a) * (1 - b)
### softdodge      - A softer ColorDodge, actually a combination of ColorDodge and the inverse of ColorBurn.
### colordodge     - Opposite of Multiply, actually it's a divide with the complementary of the Top layer. a / (1 - b)
### lineardodge    -
### linearadd      - Resembles 'lineardodge' and 'screen'. The result is not as bright as 'lineardodge', but brighter than 'screen'. Good for reflection on compositing
###
### CONTRAST
### overlay        - A combination of Multiply (when Base < 128) and Screen (when Base > 128)
### softoverlay    - A combination of Multiply and Screen. Same as Overlay but with half weight
### hardoverlay    - A combination of Multiply and Screen. Same as Overlay but with double weight
### hardlight      - A combination of Multiply and Screen. Same as Overlay but commuted (Multiply when Top < 128 and Screen when Top > 128)
### softlight      - A combination of Multiply and Screen. Same as Hard Light but with half weight (or a commuted softoverlay)
### vividlight     - A combination of ColorBurn and ColorDodge
### linearlight    - A combination of LinearBurn and LinearDodge
### stamp          - Very similar to LinearLight, but more optimized
### pinlight       - A combination of Darken and Lighten
### hardmix        - Sum of Base and Top layers and thresholded at range max
###
### NON-SYMMETRIC or QUADRATIC
### reflect        - A darker version of ColorDodge, looks like a contrasty SoftLight. a^2 / (1 - b)
### glow           - Same as Reflect but with Base and Top layers swapped, looks like a contrasty HardLight.  b^2 / (1 - a)
### freeze         - Same as ColorBurn but with less weight for Base layer, hence the output is brighter. 1 - (1 - a)^2 / b
### heat           - Like Freeze but with Base and Top layers swapped, output is very contrasty. 1 - (1 - b)^2 / a
###
### ANTISYMMETRIC or INVERSION
### grainextract   -
### grainmerge     -
###
### difference     - Absolute difference of Base and Top layers
### softdifference -
### negation       - The "opposite" of difference mode, calculated with the complements of both layers. 1 - abs(1-(a-b))
### exclusion      - A 50% mix of Difference and Negation
### subtract       - Difference of Base and Top layers (clamped)
### linearsubtract -
### from           - Subtract mode commuted
### divide         - Divide Base by Top layer. Opposite of Multiply (can be used to undo it)
### andn           - Base and Top layers are combined with a logical (binary) ANDN (and not)
### extremity      -
### bleach         -
### stain          -
### phoenix        -
###
### HSL COMPONENT
### hue            - Keep BRIGHTNESS and SATURATION of the Base layer and inherit HUE                 of the Top  layer
### saturation     - Keep BRIGHTNESS and HUE        of the Base layer and inherit SATURATION          of the Top  layer
### color          - Keep BRIGHTNESS                of the Base layer and mix with HUE and SATURATION of the Top  layer
### value          - Keep BRIGHTNESS                of the Top  layer and mix with HUE and SATURATION of the Base layer
###

function ex_blend(clip a, clip b, string "mode", float "opacity", float "watermark", bool "tv_range", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    lut  = isRunTime       (a,rgb) || bi > 12 ? 0 : 2

    md   = Default(mode, "multiply")
    op   = Default(opacity, md == "blend" ? 0.5 : 1.0)
    wm   = Default(watermark,   1.0)  # 0.0 to 2.0. At default 1.0 behaves like 'blend'
    tv   = Default(tv_range,    !fs)  # TV or PC. Color range of your source
    UV   = Default(UV,  rgb ? 3 : md == "normal" ? 4 : 1)
    si   = ex_UVf(rgb, bi)

    op  = clamp(op,0,1)
    iso = op == 1.0

    md = md == "add"          ? "lineardodge"  : \
         md == "addition"     ? "lineardodge"  : \
         md == "plus"         ? "lineardodge"  : \
         md == "or"           ? "lineardodge"  : \
         md == "xor"          ? "difference"   : \
         md == "addition128"  ? "grainmerge"   : \
         md == "difference128"? "grainextract" : \
         md == "dodge"        ? "colordodge"   : \
         md == "burn"         ? "colorburn"    : \
         md == "smoothmin"    ? "darkenS"      : \
         md == "smoothmax"    ? "lightenS"     : \
         md == "average"      ? "blend"        : \
         md == "colour"       ? "color"        : \
         md == "luminosity"   ? "value"        : \
         md == "brightness"   ? "value"        : \
         md == "lightness"    ? "value"        : \
         md == "hypot"        ? "linearadd"    : \
         md == "diagonal "    ? "linearadd"    : \
         md == "minus"        ? "subtract"     : \
         md == "and"          ? "multiply"     : md

                                           Assert(IsVersionOrGreater(3,7,2), "ex_blend: Update AviSynth+ version")
    md == "darker" || md == "lighter"    ? Assert(rgb && UV == 3,            "ex_blend: 'darker' and 'lighter' modes require RGB inputs and UV = 3") : nop()
    md == "color"  || md == "value"      || \
    md == "hue"    || md == "saturation" ? Assert(!rgb && !isy,              "ex_blend: 'hue', 'saturation', 'color' and 'value' modes require YUV inputs") : nop()

    rngmx = tv   ? "ymax ymin -" : "range_max"
    srcmx = tv   ? "ymin -"      : ""
    V     = !iso ? "A@"          : ""

    # Half the modes ported from HAvsFunc, rest from Overlay_MTools(), Blend_MT_alpha3, ffmpeg, Nuke docs and web
    # 'softlight' uses Pegtop's improved formula. Actually many of the more esoteric modes were created by him (Jens Gruschel)
    # 'hue' mode is YUV (not RGB) based so it differs from Photoshop's
    # 'bleach' and 'stain' modes look the same in ffmpeg (bug?) ('stain' alike here)
    # 'hardoverlay' is close but not math exact to original, revise later
    # Some modes still need clamping for overflow values, revise later
    str = Format(                                                                                                                                                                  \
                                                                                                                                                                                   \
        md == "--"            ? "x"                                                                                                                                              : \
        md == "normal"        ? "y"                                                                                                                                              : \
        md == "blend"         ? iso ? "y" : "x "+srcmx+" dup y "+srcmx+" swap - {op} * + "                                                                                       : \
        md == "interpolation" ? "x "+srcmx+" "+V+" "+rngmx+" / pi * cos 0.25 * 0.5 swap - y "+srcmx+" "+rngmx+" / pi * cos 0.25 * - "+rngmx+" * "                                : \
        md == "harmonic"      ? "x "+srcmx+" "+V+" dup y "+srcmx+" dup swap2 * 2 * swap2 + / "                                                                                   : \
        md == "geometric"     ? "x "+srcmx+" "+V+"     y "+srcmx+"           *     sqrt      "                                                                                   : \
        md == "watermark"     ? "x "+srcmx+" A^ y "+srcmx+" "+rngmx+" B@ / 0 max 1 {wm} {op} ^ / ^ B * "                                                                         : \
                              \
        md == "darker"        ? "see footer"                                                                                                                                     : \
        md == "darken"        ? "x "+V+" y min "                                                                                                                                 : \
        md == "darkenS"       ? "0.2 x "+srcmx+" A@ y "+srcmx+" B@ - abs "+rngmx+" / - 0 max 5 * 3 ^ 0.166666 0.2 "+rngmx+" * * * A B min swap - 0 max "                         : \
        md == "multiply"      ? "x "+srcmx+" "+V+" y "+srcmx+" * "+rngmx+" / "                                                                                                   : \
        md == "multiply128"   ? "x "+srcmx+" "+V+" range_half "+srcmx+" - y "+srcmx+" ymin 2 * / * range_half "+srcmx+" + 0 "+rngmx+" clip "                                     : \
        md == "softburn"      ? "y "+srcmx+" B@ x "+srcmx+" A@ + "+rngmx+" < B range_half "+srcmx+" * "+rngmx+" A - 0 max C@ / "+rngmx+" C range_half "+srcmx+" * B / - ? "      : \
        md == "colorburn"     ? ""+rngmx+" dup x "+srcmx+" "+V+" - "+rngmx+" * 0 max y "+srcmx+" 0 max / - 0 max "                                                               : \
        md == "linearburn"    ? "x "+srcmx+" "+V+" y "+srcmx+" + B@ "+rngmx+" < 0 B "+rngmx+" - ? "                                                                              : \
                              \
        md == "lighter"       ? "see footer"                                                                                                                                     : \
        md == "lighten"       ? "x "+V+" y max "                                                                                                                                 : \
        md == "lightenS"      ? "0.2 x "+srcmx+" A@ y "+srcmx+" B@ - abs "+rngmx+" / - 0 max 5 * 3 ^ 0.166666 0.2 "+rngmx+" * * * A B max + "                                    : \
        md == "screen"        ? ""+rngmx+" C@ dup x "+srcmx+" "+V+" - C y "+srcmx+" - * C / - "                                                                                  : \
        md == "softdodge"     ? "x "+srcmx+" A@ y "+srcmx+" B@ + "+rngmx+" < A range_half "+srcmx+" * "+rngmx+" B - C@ / "+rngmx+" C range_half "+srcmx+" * A / - ? "            : \
        md == "colordodge"    ? "x "+srcmx+" "+V+" "+rngmx+" * "+rngmx+" y "+srcmx+" 0 max - / "+rngmx+" min "                                                                   : \
        md == "lineardodge"   ? "x "+srcmx+" "+V+" y "+srcmx+" + "+rngmx+" min "                                                                                                 : \
        md == "linearadd"     ? "x "+srcmx+" "+V+" dup * y "+srcmx+" dup * + sqrt "+rngmx+" min "                                                                                : \
                              \
        md == "overlay"       ? "x "+srcmx+" A@ range_half "+srcmx+" < 2 A y "+srcmx+" B@ * "+rngmx+" / * "+rngmx+" 2 "+rngmx+" A - "+rngmx+" B - * "+rngmx+" / * - ? "          : \
        md == "softoverlay"   ? ""+rngmx+" C@ x "+srcmx+" A@ - A y "+srcmx+" B@ * C / * A C dup A - C B - * C / - * + C / "                                                      : \
        md == "hardoverlay"   ? "x "+srcmx+" A@ "+rngmx+" == "+rngmx+" y "+srcmx+" B@ "+rngmx+" * "+rngmx+" 2 * A 2 * - / 0.3333 * A B * 3 * "+rngmx+" 2 * / + "+rngmx+" min ? " : \
        md == "softlight"     ? ""+rngmx+" C@ y "+srcmx+" B@ - B x "+srcmx+" A@ * C / * B C dup B - C A - * C / - * + C / "                                                      : \
        md == "hardlight"     ? "y "+srcmx+" B@ range_half "+srcmx+" < 2 B x "+srcmx+" A@ * "+rngmx+" / * "+rngmx+" 2 "+rngmx+" B - "+rngmx+" A - * "+rngmx+" / * - ? "          : \
        md == "vividlight"    ? "y "+srcmx+" B@ range_half "+srcmx+" C@ < B 0 <= 2 B * "+rngmx+" dup x "+srcmx+" A@ - "+rngmx+" * 2 B * / - ? 2 B C - * "+rngmx+" >= 2 B C - * A "+rngmx+" * "+rngmx+" 2 B C - * - / ? ? 0 "+rngmx+" clip ": \
        md == "linearlight"   ? "x "+srcmx+" A@ range_half "+srcmx+" < A 2 y "+srcmx+" B@ * + "+rngmx+" - A 2 B range_half "+srcmx+" - * + ? 0 "+rngmx+" clip "                  : \
        md == "stamp"         ? "x "+srcmx+" "+V+"     y "+srcmx+"         2 * + "+rngmx+"  - 0 "+rngmx+" clip "                                                                 : \
        md == "pinlight"      ? "y "+srcmx+" B@ range_half "+srcmx+" < x "+srcmx+" A@ 2 B * min A 2 B range_half "+srcmx+" - * max ? "                                           : \
        md == "hardmix"       ? "x "+srcmx+" "+V+" y "+srcmx+" + "+rngmx+" < 0 "+rngmx+" ? "                                                                                     : \
                              \
        md == "reflect"       ? "x "+srcmx+" "+V+" dup * "+rngmx+" y "+srcmx+" 0 max - / "+rngmx+" min "                                                                         : \
        md == "glow"          ? "y "+srcmx+" dup * "+rngmx+" x "+srcmx+" "+V+" 0 max - / "+rngmx+" min "                                                                         : \
        md == "freeze"        ? ""+rngmx+" dup x "+srcmx+" "+V+" - dup * y "+srcmx+" 0 max / "+rngmx+" min - "                                                                   : \
        md == "heat"          ? ""+rngmx+" dup y "+srcmx+" - dup * x "+srcmx+" 0 max "+V+" / "+rngmx+" min - "                                                                   : \
                              \
        md == "grainextract"  ? "x "+srcmx+" "+V+"  y "+srcmx+" - range_half "+srcmx+" + 0 "+rngmx+" clip "                                                                      : \
        md == "grainmerge"    ? "x "+srcmx+" "+V+"  y "+srcmx+" + range_half "+srcmx+" - 0 "+rngmx+" clip "                                                                      : \
                              \
        md == "difference"    ? "x "+srcmx+" "+V+"  y "+srcmx+"                    - abs   "                                                                                     : \
        md == "softdifference"? "x "+srcmx+" A@     y "+srcmx+" B@ > B "+rngmx+" == 0 A B - "+rngmx+" * "+rngmx+" B - / 0 max ? B 0 == 0 B A - "+rngmx+" * B / 0 max ? ? "       : \
        md == "negation"      ? ""+rngmx+" dup    x "+srcmx+" "+V+" - y "+srcmx+" - abs - "                                                                                      : \
        md == "exclusion"     ? "x "+srcmx+" A@ dup y "+srcmx+" B@ + A B * 2 * + + "+rngmx+" / "+rngmx+" min "                                                                   : \
        md == "subtract"      ? "x "+srcmx+" "+V+"  y "+srcmx+"                    - 0 max "                                                                                     : \
        md == "linearsubtract"? "x "+srcmx+" "+V+" dup * y "+srcmx+" dup * - sqrt "                                                                                              : \
        md == "from"          ? "x "+srcmx+" "+V+"  y "+srcmx+" swap               - 0 max "                                                                                     : \
        md == "divide"        ? ""+rngmx+" x "+srcmx+" "+V+" * y "+srcmx+" 0 max / "+rngmx+" min "                                                                               : \
        md == "andn"          ? ""+rngmx+"        x "+srcmx+" "+V+" - y "+srcmx+" * "+rngmx+" / "                                                                                : \
        md == "extremity"     ? ""+rngmx+"        x "+srcmx+" "+V+" - y "+srcmx+" - abs   "                                                                                      : \
        md == "bleach"        ? ""+rngmx+" 2 *    x "+srcmx+" "+V+"   y "+srcmx+" + - "+rngmx+" - 0 max "                                                                        : \
        md == "stain"         ? ""+rngmx+" 2 *    x "+srcmx+" "+V+"   y "+srcmx+" + - "+rngmx+" %     "                                                                          : \
        md == "phoenix"       ? "x "+srcmx+" "+V+" y "+srcmx+" dup1 dup1 min swap2 max - "+rngmx+" + "                                                                           : \
                              \
        md == "hue"           ? "see footer "                                                                                                                                    : \
        md == "saturation"    ? "see footer "                                                                                                                                    : \
        md == "color"         ? "see footer "                                                                                                                                    : \
        md == "value"         ? "see footer "                                                                                                                                    : \
                              \
                                Assert (false, "ex_blend: '"+md+"', unsupported blend mode") )


    off = !tv || md == "--" || md == "normal" || md == "lighten" || md == "darken" ? "" : " ymin +"
    str = iso || md == "--" || md == "normal" || md == "blend" ? str+off : \
                                                                 str+Format(" A - {op} * A + ")+off

    if (md == "darker" || md == "lighter") {

        Ra = a.ExtractR()  Rb = b.ExtractR()
        Ga = a.ExtractG()  Gb = b.ExtractG()
        Ba = a.ExtractB()  Bb = b.ExtractB()

        sym  = md == "darker" ? "<" : ">"
        msk  = Expr(Ra, Ga, Ba, Rb, Gb, Bb, ex_dlut("x y z + + a b c + + "+sym+" 0 range_max ?", bi, !tv), lut=0, format=PixelType(a))

        ex_merge(a, b, msk, luma=false, UV=3)

    } else if (md == "hue" || md == "saturation" || md == "color" || md == "value") {

        md == "color"      ? CombinePlanes(a, b, planes="YUV").propCopy(b,true,props=["_Matrix","_Primaries","_ChromaLocation"]) : \
        md == "value"      ? CombinePlanes(b, a, planes="YUV").propCopy(a,true,props=["_Matrix","_Primaries","_ChromaLocation"]) : \
        md == "saturation" ? ex_vibrance  (a, 1.0, mode="Recover2", Rc=b,    tv_range=tv) : \
                             HSVxHSV(b, 1.0, "HUE", "VAL", 0.0,   1.00, 1.0, tv_range=tv, show=3)

        Ch = md == "hue"   ? ex_vibrance(a,bias=1,show=3).ex_lut("x range_half - abs") : nop()
             md == "hue"   ? Expr(last,ch,"","f32 x cos y *","f32 x sin y *",scale_inputs="intf",lut=lut,Format="YUV444P"+string(bi==32?"S":bi)) : last
             md == "hue"   ? CombinePlanes(a, last, planes="YUV") : last

    } else {

    cstr = ex_UVexpr(str, UV, bi, rgb, !tv, si)
    str  = ex_dlut  (str,     bi,      !tv)

    isy     ? Expr(a, b, str,                        optSingleMode=true, lut=lut) : \
    UV == 1 ? Expr(a, b, str, "",                    optSingleMode=true, lut=lut) : \
              Expr(a, b, str, cstr, scale_inputs=si, optSingleMode=true, lut=lut) } }



###
### ex_glow()
###
### Makes highlights glow into darker areas in a realistic exponential fashion, also known as "light wrap".
###
### modes:
### fib  - fibonacci  multipass: 1,1,2,3,5,8...
### trib - tribonacci multipass: 1,1,2,4,7,13...
###
function ex_glow(clip a, int "radius", int "thres", float "opacity", bool "tv_range", string "mode", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(radius,    8)          # from 0 to ~10 (Expr hard limit). Spread
    th = Default(thres,   164)          # from 64 to 192 (roughly)
    op = Default(opacity, rd/50.+0.1)   # from 0.0 to 1.0. Strength
    md = Default(mode, "trib")
    tv = Default(tv_range, !rgb)
    UV = Default(UV,        rgb ? 3 : 1)
    fs = Default(fulls,     rgb)

    b = ex_binarize(a, th, smooth=false, UV=UV, fulls=fs).ex_kawase(2,"trib",uv).ex_boxblur(1,1,"weighted",uv)
    str = ""
    for (i = 1, rd, 1) {
        c   = i == 1  ? "b," : ""
        dot = i == rd ? ""   : "."
        bop = md == "fib" ? floor(pow((1+sqrt(5))/2,i)/sqrt(5)+0.5)             :\
                            floor(0.618033988749895*pow(1.839286755214161,i)+0.5)
        bop = min((1./ bop) * 10, 1)
        str = str + Format("""ex_blend("""+c+"""ex_kawase(b,{i},md,{uv}),"screen",{bop},1,false,{uv})""")+dot
           }

    Eval(str)
    d = ex_makediff(last,b,dif=false,UV=uv,fulls=fs).moncurve_r(2.22,0.0,false,tv,uv)
    rd != 0 ? ex_blend(a,d,"screen",op,1,tv,uv) : a }




###
###
### ex_posterize() - ported from cretindesalpes':
### https://forum.doom9.org/showthread.php?p=1516096#post1516096
###
### Dependencies: > ExTools
###                 fmtconv
###
### Similar to "dither_bits" argument from ConvertBits() but more flexible and more options.
###
###
### Function Definition:
###    (
###    clip,
###    int "bits"=3 (0 to 7),
###    int "mode"=-1 (-1 to 7)
###    #hint Note: -1: round  0: Bayer OD  1: Floyd-Steinberg ED  2: Sierra-2-4A ED  3: Stucki ED  4: Atkinson ED  5: Ostromoukhov ED  6: Void & Cluster OD  7: Quasirandom OD
###    )
###
function ex_posterize (clip c, int "bits", int "mode", int "UV") {

    rgb  = isRGB(c)
    bi   = BitsPerComponent(c)
    fs   = propNumElements (c,"_ColorRange")  > 0 ? \
           propGetInt      (c,"_ColorRange") == 0 : rgb

    UV   = Default(UV, rgb ? 3 : 2)
    bits = Default(bits,     3)    # Valid range: 0 - 7
    mul  = string(Pow (2, 8 - bits - 1))
    bits = clamp(bits,0,7)
    md   = Default(mode,    -1)    # Valid modes: -1: Round (quantization)
                                   #               0: Bayer OD
                                   #               1: Floyd-Steinberg ED
                                   #               2: Sierra-2-4A ED
                                   #               3: Stucki ED
                                   #               4: Atkinson ED
                                   #               5: Ostromoukhov ED
                                   #               6: Void & Cluster OD
                                   #               7: Quasirandom OD
    ConvertBits(c,16, fulls=fs, fulld=fs)

    ex_lut ("x "+mul+" /", y=3, UV=UV, fulls=fs)

    md < 2 ? ConvertBits  (bits=8, dither=md,   fulls=fs, fulld=fs) : \
    md > 4 ? fmtc_bitdepth(bits=8, dmode =md+2, fulls=fs, fulld=fs) : \
             fmtc_bitdepth(bits=8, dmode =md+1, fulls=fs, fulld=fs)

    ex_lut ("x "+mul+" *", y=3, UV=UV, fulls=fs)

    ConvertBits(bi, fulls=fs, fulld=fs) }




###
###
### Skin_Qualifier() - (28-12-2021)
###
### Dependencies: > ExTools
###                 TransformsPack
###
### Segmentation of skin tones. Extracts a skin mask to use elsewhere.
### It does so in OkLab Jch space which is perceptually uniform (UCS).
###
### Function Definition:
###    (
###    clip,
###    float str=0.80 (0.10 to 2.00),
###    float "Delta"=43.0 (0.0 to 360.0 by 1),
###    float "Q"=0.70 (0.00 to 1.00),
###    float "blur"=3.0 (0.0 to 6.0 by 0.5),
###    bool "invert"=false
###    )
###
function Skin_Qualifier (clip c, float "str", float "Delta", float "Q", float "blur", bool "invert") {

    rgb = IsRGB(c)
    ID  = color_propGet(c)
    bi  = ID[7]

    str = Default (str,         0.8)   # Strength of mask
    dg  = Default (Delta,        43)   # Degrees in IPT HUE
    bw  = Default (Q,           0.7)   # 0.0 to 1.0. Bandwidth of mask
    bl  = Default (blur,          3)   # Post-blur
    in  = Default (invert,    false)   # invert mask
    fs  = !ID[6]

    Assert(IsVersionOrGreater(3,7,2), "Skin_Qualifier: Update AviSynth+ version")

    dg  = (-1 * dg) * (pi / 180)       # IPT HUE goes reverse so "-1 *"
    LO  = 1-bw
    HI  = 1-bw/(3.01-min(str,1))
    mat = Color_fuzzy_search(ID[2])

    rgb ? IsPlanar(c) ? c : ConvertToPlanarRGB(c) : c

    bi < 14 ? ConvertBits(14, fulls=fs)                                   : last
    !rgb    ? ConvertToPlanarRGB(matrix=mat[0],chromaresample="spline36") : last
              CCTF(mat[2], true, !rgb ? false : !fs, false)

    RGB_to_Oklab(matrix=mat[0], Jch=true, fulls=true)

    C     = ExtractG()
    H     = ExtractB()
    Cnorm = "x 0.28 - abs 1 swap - 0 swap 0.706 - -3.4 * -" # Centered at skin saturation and normalized
    in    = in ? "1 swap -" : ""

    ex_lutxy(C, H, Format("f32 y 6.283185 * pi - {dg} + cos "+Cnorm+" * 0 swap {LO} - 1 {LO} {HI} - / * - "+in), scale_inputs="intf", fulls=true, clamp_float=true)

    ConvertBits(bi, dither= bi==32 ? -1 : 1, fulls=true)
    bl > 0 ? ex_gaussianblur(bl, pad=false, UV=3) : last
    propDelete(["_Matrix","_Primaries","_Transfer","_PictType"]) }




###
###
### HSVxHSV() - (11-01-2022)
###
### 3x3 operator matrix. Adjust Hue, Saturation or Value (modeB) based on Hue, Saturation or Value (modeA).
### This is similar to internal Tweak(), but double the speed, easier to use and more modes (+5 modes involving 'VAL')
### RGB not supported.
###
### Dependencies: > ExTools
###                 TransformsPack
###                 ResizersPack  (for show=1)
###                 MasksPack     (for show=1)
###
### This includes the following 9 operators (modeA x modeB):
###   HUExHUE
###   HUExSAT
###   HUExVAL
###   SATxHUE
###   SATxSAT (This is similar to ex_vibrance() )
###   SATxVAL
###   VALxHUE
###   VALxSAT
###   VALxVAL
###
### Note:
###     Include the following function definition in AvsPmod to enable sliders.
###     (
###     clip yuv,
###     float str=1.0 (0.0 to 360.0),
###     string "modeA"="HUE" ("HUE"/ "SAT"/ "VAL"),
###     string "modeB"="SAT" ("HUE"/ "SAT"/ "VAL"),
###     float "Delta"=180.0 (0.0 to 360.0 by 1),
###     float "Q"=0.20 (0.01 to 1.00),
###     float "Opacity"=1.0 (0.0 to 1.0),
###     int "show"=1 (0 to 2)
###     )
###
function HSVxHSV (clip c, float "str", string "modeA", string "modeB", float "Delta", float "Q", float "Opacity", bool "tv_range", int "show") {

    rgb = IsRGB(c)
    isy = isy(c)
    ID  = color_propGet(c)
    bi  = ID[7]
    bi32= bi==32

    str = Default (str,     1.0)   # Strength of 'modeB' operator. 0-360 for 'V' and 'H' and 0.0-4.0 for 'S'
    mA  = Default (modeA, "HUE")   # 'modeA' (HUE or H, SAT or S, VAL or L or V). Mask of the operator.
    mB  = Default (modeB, "SAT")   # 'modeB' (HUE or H, SAT or S, VAL or L or V). Mode of the operator.
    dA  = Default (Delta, 180.0)   # Degrees of 'modeA' (isolate this area. 0-255 for 'L', 0-360 for for 'H' and 0.0-100.0 for 'S')
    bA  = Default (Q,       0.2)   # Q-factor (Bandwidth) of 'modeA'. Spread of the isolated area. 0.0-1.0
    sA  = Default (opacity, 1.0)   # Scale   of 'modeA'. Scale of the isolated area (typically to scale down since by default it's white). 0.0-1.0
    tv  = Default (tv_range, ID[6])
    sh  = Default (show,      0)   # 0: disabled, 1: show histogram, 2: show mask (resized to luma dimensions) 3: show mask at original size
    sm  = sh > 1
    si  = tv ? "int" : "intf"

    Assert(IsVersionOrGreater(3,7,2), "HSVxHSV: Update AviSynth+ version")
    Assert(!isy && !rgb,              "HSVxHSV: Only YUV format is supported")

    U   = ExtractU(c)
    V   = ExtractV(c)
    Yf  = ExtractY(c)
    Ys  = is444(c) ? Yf : Yf.BicubicResize(U.width(),U.height(),-0.5,0.25)
    c4  = is444(c) ?  c : c.ConverttoYUV444(matrix=ID[2],chromaresample="spline36")
    c4U = ExtractU(c4)
    c4V = ExtractV(c4)
    Uc  = YtoUV(U,U,c4U)
    Vc  = YtoUV(V,V,c4V)
    Y   = YtoUV(Ys,Ys,Yf)

    mA  = mA=="H"   ? "HUE" : \
          mA=="S"   ? "SAT" : \
          mA=="V"   ? "VAL" : \
          mA=="L"   ? "VAL" : \
          mA=="LUM" ? "VAL" : mA
    mB  = mB=="H"   ? "HUE" : \
          mB=="S"   ? "SAT" : \
          mB=="V"   ? "VAL" : \
          mB=="L"   ? "VAL" : \
          mB=="LUM" ? "VAL" : mB
    nul = mB=="SAT" ? str==1.0 : mB=="VAL" ? str==180. : str==0.0 || str==360.0

    dA  = mA=="HUE" ? clamp(dA,0,360)/360. : \
          mA=="VAL" ? clamp(dA,0,255)/255. : \
          mA=="SAT" ? clamp(dA,0,100)/100. : dA

    sc  = 0.32*atan(0.32*tan((dA+0.507)/0.32))+0.5 # less granularity to extremes and more to center
    dA  = mA=="SAT" ? min(1,sc) : dA

    str = mB=="HUE" ? str * ( pi /180.)                        :          \
          mB=="VAL" ? 1./((str/360.) * (0.5 + str/360.) + 0.5) : min(6,str)
    sA  = sA < 1.0  ? string(sA)+" * "    : ""

    bA  = 1. / (mA=="SAT" ? dA < 0.5 ? bA/2 : bA/(2-4*pow(dA-0.5,2)) : bA)

    rangePC  = tv ? "ymin - ymax ymin - /"      : ""
    rangeTV  = tv ? "ymax ymin - * ymin +"      : ""
    rangePCc = tv ? "range_max cmax cmin - / *" : ""
    rangeTVc = tv ? "cmax cmin - range_max / *" : ""

    offS = bi32 || (mB=="SAT" && !sm) ? "" : " 0.5 - "
    varX = mB=="HUE" ? " X@" : mA=="HUE" && mB=="SAT" ? " X@"      : ""
    varY = mB=="HUE" ? " Y@" : mA=="HUE" && mB=="SAT" ? " Y@"      : ""
    varM = mB!="HUE" ?    "" : mA=="SAT" ? "S@" : mA=="HUE" ? "H@" : ""

    clpB = mA=="VAL" && mB=="VAL" ? " X"           : \
           mB=="VAL"              ? " x "+rangePC  : \
           mA=="VAL" && mB!="HUE" ? " y "+rangePCc : \
           mA=="HUE" ?  mB=="SAT" ? " X" :    " H" : \
           mB!="HUE"              ? " x "+rangePCc : mA=="SAT" ? " X Y atan2" : " y "+offS+rangePCc+varX+" z "+offS+rangePCc+varY+" atan2 "

    msk  = mA=="VAL" ? Format("f32 x "     +rangePC+" X@                                                                  {dA} - abs 1 swap - {bA} ^       0 1 clip "+sA) : \
           mA=="SAT" ? Format("f32 x "+offS+rangePCc+varX+" dup * y "+offS+rangePCc+varY+" dup * + sqrt 0.5 + "+varM+"    {dA} - abs 1 swap - {bA} ^ 0.5 - 0 1 clip "+sA) : \
                       Format("f32 x "+offS+rangePCc+varX+"       y "+offS+rangePCc+varY+" atan2 "+varM+" pi + 0.159155 * {dA} + 1 % {bA} ^ "+sA) # "0.159155 *" = "pi 2 * /"
    op   = mB=="VAL" ? Format(clpB+" dup dup dup dup 0.005 > swap {str} ^ swap ? 0 1 clip    swap - swap swap2 * + "+rangeTV)  : \
           mB=="SAT" ? Format(clpB+" dup dup                      {str} *                    swap - swap swap2 * + "+rangeTVc) : \
                       Format(clpB+" dup dup                      {str} pi + + pi 2 * % pi - swap - swap swap2 * + " )


    if (sm) {

        msk = ReplaceStr(msk, "X@", "").ReplaceStr("Y@", "").ReplaceStr("^ 0.5 -", "^")

        mA=="VAL" ? ex_lut  (c,   msk, UV=128, scale_inputs=si) : \
                    ex_lutxy(U,V, msk, UV=1,   scale_inputs=si)
                    propDelete(["_Matrix","_Primaries","_Transfer","_PictType"])
                    propSet("_ColorRange", 0)
                    sh==2 ? BicubicResize(c.width(),c.height(),0.679623,0.160189) : last

    } else if (nul) {

        c

    } else if (mB!="VAL" && (mA=="HUE" || mB=="HUE")) {

        if (mB=="HUE") {

            # modeAxHUE
            bi32H = bi32 ? "" : " 0.5695 + "
            clpS  = mA=="SAT" ? "S" : "X dup * Y dup * + sqrt "
            msk   = mA=="SAT" ? ReplaceStr(msk, "0.5 + S@", "S@ 0.5 +") : msk
            mBU   = msk+op+" sin "+clpS+" * "+bi32H+rangeTVc
            mBV   = msk+op+" cos "+clpS+" * "+bi32H+rangeTVc

            U = mA=="VAL" ? ex_lutxyz(Ys,U,V,mBU,scale_inputs=si) : ex_lutxy(U,V,mBU,scale_inputs=si)
            V = mA=="VAL" ? ex_lutxyz(Ys,U,V,mBV,scale_inputs=si) : ex_lutxy(U,V,mBV,scale_inputs=si)
            CombinePlanes(Yf, U, V, planes="YUV",Pixel_Type=PixelType(c))

        } else if (mA=="HUE") {

            # HUExSAT
            mskV  = ReplaceStr(msk, " x ", " z ").ReplaceStr(" y ", " x ").ReplaceStr(" z ", " y ")
            opV   = ReplaceStr(op,  " X ", " Y ")

            U  = ex_dlut(msk +op,  32, !tv)
            V  = ex_dlut(mskV+opV, 32, !tv)
            Expr(c,c.SwapUV(),"",U,V,scale_inputs=si,Format=PixelType(c),lut=isRunTime(c,rgb) || bi > 12 ? 0 : 2)

        }

    } else {

    msk = mA=="VAL" && mB!="VAL" && !bi32 ? ReplaceStr(msk," x ", " x 0.5 + ")                    : \
          mA!="VAL" && mB=="VAL"          ? ReplaceStr(msk," y ", " z ").ReplaceStr(" x ", " y ") : msk

    # In order: VALxVAL, VALxSAT, SATxVAL, HUExVAL, SATxSAT
    mA=="VAL"   ? mB=="VAL" ? ex_lut   (c,                 msk+op,UV=2,   scale_inputs=si) : \
                              ex_lutxyz(Y,c,c.SwapUV(),"", msk+op,UV=3,   scale_inputs=si) : \
                  mB=="VAL" ? ex_lutxyz(c,Uc,Vc,           msk+op,UV=2,   scale_inputs=si) : \
                              ex_lutxy (  c,c.SwapUV(),"", msk+op,UV=3,   scale_inputs=si) }

    if (sh==1) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
        w   = c.width()
        h   = c.height()
        lvl = Histogram(mode="levels",keepsource=false)
        lvl = StackVertical(lvl,Vectorscope()).RatioResize(h/512.,"%",kernel="gauss",p=100)
        lvl = tv ? lvl.SMPTE_Legal(false) : lvl
        StackHorizontal(last,lvl) } }





###
###
### GamutWarning() - (01-03-2022)
###
###
### Shows pixels that would fall out-of-gamut when converting YUV to RGB PC range (ie. for display presentation)
### Supported color spaces are "Rec709", "170M", "470M", "470BG/Rec601" and "2020NCL".
### Enable 'EBUR103' for relaxed thresholds based on the normative and write to '_OutGamut' frameprops.
###
### Legend:
###     Blue: U     plane   is out of gamut
###     Red:  V     plane   is out of gamut
###     Fux:  U & V planes are out of gamut
###
###
### Dependencies: > ExTools
###                 TransformsPack
###
###
### Example for fixing out-of-gamut:
###
###     msk=GamutWarning(show=2)
###     ex_merge(last,ex_vibrance(0.4,"vibrance",4),msk,luma=true,Y=2,UV=3) # There's yet to add chroma induced luma recovery
###   # GamutWarning(show=1) # to show improvement
###
###
### Function Definition:
###    (
###    clip yuv,
###    string "matrix"="Rec709" ("470M"/ "470BG"/ "170M"/ "Rec709"/ "Rec2020CL"/ "Rec2020NCL"/ "Display-P3"/ "ACEScg"),
###    [bool "tv_range"=true],
###    bool "EBUR103"=false,
###    int "show"=0 (0 to 2)
###    )
###
####################################

/*
# Tolerances on colour gamut (https://tech.ebu.ch/docs/r/r103.pdf)
    The EBU recommends that the colour gamut in television programme material can be accepted if
    both the following conditions are met:

    •LUMINANCE:   The luminance signal should lie inside the range -1% to 103% (ie. 14-242 for 8-bit legal, not implemented, use SoftLimiter() instead)
    •CHROMINANCE: When matrixed to RGB, all of the R, G or B signals should lie inside the range -5% and 105% -EBU103 v1.1- (ie. -12.75-267.75 when converted to 8-bit full range RGB - 5-246 for Studio RGB)
    •Measuring equipment should indicate an “Out-of-Gamut” occurrence only after the error exceeds 1% of the image histogram for either luminance or chrominance within the preferred ranges described above

# Horizontal Signal Filtering
    In order to remove transient over and under-excursions of the signals, and to minimise the effect of
    high frequency noise on the colour gamut measurements, the use of appropriate filters in all measurement channels are recommended
    A quarter band filter applied horizontally and a half band filter applied vertically is recommended.
*/

function GamutWarning(clip yuv, string "matrix", bool "tv_range", bool "EBUR103", int "show") {

    propIDs = color_propGet(yuv)
    bi      =  propIDs[7]
    fs      = !propIDs[6]

    mat     = Default (matrix, propIDs[2])
    tv      = Default (tv_range,      !fs)
    ebu     = Default (EBUR103,     false)  # Enable for EBU R103 ("_OutGamut" frameprops and less strict thresholds)
    sh      = Default (show,            0)  # 0: Show out-of-gamut overlay   1: Also show metric   2: Show mask so you can filter out those areas

    Assert(IsVersionOrGreater(3,7,2), "GamutWarning: Update AviSynth+ version")
    Assert(!isRGB(yuv),               "GamutWarning: Only YUV format supported")

    mat     = Color_Fuzzy_search (mat)
    coef    = color_coef(mat[0])


    clp = ExtractClip(!ebu ? yuv : yuv.ex_boxblur(5,1,mode="weighted",UV=3)) # EBU R103 standard lowpass (very similar to V: 1/4, 1/2, 1/4, and H: 1/16, 2/16, 3/16, 4/16, 3/16, 2/16, 1/16)
    U   =              clp[1]
    V   =              clp[2]
    Y   =              clp[0]
    Ys  = is444(yuv) ? Y : Y.BicubicResize(U.width(),U.height(),-0.5,0.25)
    Y   = YtoUV(Ys,Ys,Y)


    scale_y  = tv ? (255 / 219.) : 1.0
    scale_uv = tv ? (255 / 112.) : 2.0

    Kr = 1. - coef[0]
    Kb = 1. - coef[2]

    m0 = scale_y     m1 = 0.0                                   m2 = scale_uv * Kr
    m3 = scale_y     m4 = scale_uv * ( -Kb * coef[2] / coef[1]) m5 = scale_uv * ( -Kr * coef[0] / coef[1])
    m6 = scale_y     m7 = scale_uv * Kb                         m8 = 0.0

    rangeY = tv      ? "ymin - 0 max" : ""
    UVf    = bi < 32 ? "range_half -" : ""
    pm     = ex_bs(255, 8, bi, !tv)
    pn     = !ebu ?  0 : -0.05*pm
    pm     = !ebu ? pm :  1.05*pm

    expr = ex_dlut(Format("x "+rangeY+" X@ "+string(m0)+" * z "+UVf+" Z@ "+string(m2)+" * +                      dup {pn} < swap {pm} > or
                           X               "+string(m6)+" * y "+UVf+" Y@ "+string(m7)+" * +                      dup {pn} < swap {pm} > or or
                           X               "+string(m3)+" * Y            "+string(m4)+" * + Z "+string(m5)+" * + dup {pn} < swap {pm} > or or range_max y ?"), bi, !tv)


    sh<2 ? Expr(Y,yuv,yuv.SwapUV(),"", expr, Format=PixelType(yuv)) : \
           Expr(Ys, U,  V,             expr.ReplaceStr("y ?", "0 ?") ).ex_expand(mode="plus").ex_boxblur(4,mode="weighted")
    sh>1 ? mskY_to_YYY(yuv, last, true, false, 3, bi).\
           propDelete(["_Matrix","_Primaries","_Transfer","_PictType"]) : last

    # EBUR103 tag
    sh==2 || !ebu ? last : \
    ScriptClip( function[bi,tv] () {

        # Evaluate also Luminance (Y) stats?
        U  = PlaneMinMaxStats(last, 99, 0, 1, false)
        V  = PlaneMinMaxStats(last, 99, 0, 2, false)
        U  = ex_bs(U[2], bi, 8, !tv,       flt=true)    U = bi==32 ? 2 * U + 1 : U
        V  = ex_bs(V[2], bi, 8, !tv,       flt=true)    V = bi==32 ? 2 * V + 1 : V

        U >= 255 || V >= 255 ? propSet("_OutGamut", 1) : \
                               propSet("_OutGamut", 0) } )
    # Stats Overlay
    if (sh==1) {

        bin = ex_lut("x range_size 1 - < 0 x ?",Y=1,UV=3)
        div = (ex_bs(256, 8, bi, !tv)-1)*(2/100.)

        ebu ? CombinePlanes(yuv, last, planes="YUV") : last
        ScriptClip( function[bin,div] () {
            U = bin.AverageChromaU()
            V = bin.AverageChromaV()
            Subtitle("Out of Gamut: "+string((U+V)/div,"%1.3f")+"%") # In percentage
        } ) } }



###
###
### PseudoColor() - v1.2 (15-03-2022)
###
### Rainbow color coded "heat map" based on clip's luma (gamma encoded luminosity).
### Useful for segmentation and augment luma ranges with color coded isoparams.
### Also serves for debugging purposes in algorithms such as blend modes or gradient magnitudes.
### Cool colors represent low luminosity while warm colors represent high luminosity, green stands for neutral.
### 32-bit support is work in progress.
###
### Version 1.2 implements 'isoparam' mode, similar to "rainbow" but more granular and in black/white.
### Somewhat similar to Histogram("luma") but not as extreme.
### I recommend using ex_luma_rebuild() prior to this mode.
###
###
### Dependencies: > ExTools
###
###
### Function Definition:
###     (
###     clip yuv,
###     string "mode"="Rainbow" ("Rainbow"/ "Isoparam"),
###     float "iso"=1.0 (0.0 to 5.0),
###     [bool "tv_range"=true]
###     )
###
###
### Benchmark:
### 100.0% PseudoColor("rainbow") (290fps)
###  32.8% RGB().Cube("lutfile.cube").YV12()
###
####################################

function PseudoColor(clip a, string "mode", float "iso", bool "tv_range") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    bi32 = bi == 32
    lut  = isRunTime(a,rgb) || bi32 ? 0 : 1

    tv   = Default(tv_range, !fs)   # TV or PC. Color range of your source
    md   = Default(mode, "rainbow") # "rainbow" or "isoparam"
    iso  = Default(iso,   1.0)      # strength for "isoparam"

    Assert(IsVersionOrGreater(3,7,2),            "PseudoColor: Update AviSynth+ version")
    Assert((md=="rainbow" ? !isy : true) && !rgb,"PseudoColor: 'rainbow', only YUV format supported")

    if (md == "rainbow") {

        Y    = mskY_to_YYY(a, a, true, false, 3, bi)

        rangemx = !bi32 ? ex_dlut("range_max", bi, !tv) : ""
        rangePC = tv    ? ex_dlut("ymin - ymax ymin -", bi, !tv)+" /" : bi32 ? "" : rangemx+" /"
        rangemx = !bi32 ? rangemx+" *" : "0.5 -"

        Expr(Y,"x "+rangePC+" X@ dup * XX@ -9.88 *   X  10.23 * + 2.13  - 0.12 max
                                       XX -68.54 *   X  115.1 * + 47.46 - 0 1 clip
                      XX X * -201.77 * XX  84.23 * + X  -9.21 * + 1     + 0.06 max + + 1.176 swap - "+(bi32 ? "" : rangemx), \
               "x "+rangePC+" 1 swap -               X@ -1.91 * 0.642   + 0 0.5 clip
                              X dup  * XX@ -80.9 *   X  81.86 * + 20.16 - 0 max
                                       XX -17.11 *   X  28.18 * + 10.57 - 0 max + + "+rangemx,                 \
               "x "+rangePC+" 1 swap - X@ 0.15 - 2 ^ 25.510204082 * neg "+expT(5)+" 1.225322718 * 0.22 - 0 1 clip
                              X dup  *     -41.6 *   X   44.4 * + 11.6  - 0 max
                  X 0.874 - 2 ^ 37.65117896 * neg "+expT(5)+" 1.149644624 * 0.13 - 0 1 clip + + "+rangemx,lut=lut,Format=PixelType(a))

    } else if (md == "isoparam") {

        iso = iso / 10.
        ex_lut(a,Format("f32 x dup -50 * sin {iso} * +"),scale_inputs="int",UV=128)

    } else { Assert(false,  "PseudoColor: Wrong mode") }

    propSet("_ColorRange", 0) }



###
###
### Vignette() - v4.1 (31-03-2022)
###
###
### Adds a vignette (darkening around the frame) to the source.
### Use show=true if you only want the mask.
###
### Dependencies: > ExTools
###
####################################


function Vignette (clip c, float "Vignette", bool "show", bool "tv_range") {

    str   = Default(Vignette, 0.5)
    show  = Default(show,    false)
    tv    = Default(tv_range, !show)
    str   = pow((clamp(str,0,1) + 0.5) / 1.5, 0.5)

    Assert(IsVersionOrGreater(3,7,2), "Vignette: Update AviSynth+ version")

    msk = ex_lutspa(c, Format("x  width 0.5 * - abs width 0.5 * / range_max * 1.5 {str} 0.5 * + ^ range_max / 0 max "+ \
                              "y height 0.5 * - abs width 0.5 * / range_max * 1.5 {str} 0.5 * + ^ range_max / 0 max "+ \
                              "+ range_max min range_max - abs")+(tv ? " ymax ymin - range_max / * ymin +" : ""), UV=128, fulld=!tv)

    show ? msk : ex_blend(c, msk, mode="multiply", UV=2, tv_range=tv) }




###
###
### greyscale_rgb()
###
###
### Properly convert R'G'B' to luminance (in PC range linear space, then gamma reencoded)
###
### Dependencies: > ExTools
###                 TransformsPack
###
####################################

function greyscale_rgb (clip rgb, string "matrix", bool "tv_range") {

    ID     = color_propGet(rgb)

    tv     = Default (tv_range, ID[6])
    matrix = Default (matrix,   ID[2])

    Assert(IsVersionOrGreater(3,7,2), "greyscale_rgb: Update AviSynth+ version")
    Assert(isRGB(rgb),                "greyscale_rgb: Only works on RGB format")

    rgb
    matrix = Color_fuzzy_search(matrix)
    coeffs = RGB_to_XYZ        (matrix[0], list=true, adaptXYZ=false) # non-conformant illuminants not supported

    ConvertToPlanarRGB()

    CCTF(matrix[2], true,      tv, false)

    DotClip(last, [coeffs[1],coeffs[4],coeffs[7]])

    CCTF(matrix[2], false, false, false) }



###
###
### FindTemp() - v1.0 (29-04-2022)
###
###
### Find the correlated color temperature (CCT) in Kelvins of your YUV source clip.
### It won't work for graded pictures but for natural acquired images.
###
### If '_SceneStatsU' frameprops is present it will use that for calculating temperature in a scene basis.
###
### Dependencies: > ExTools
###                 TransformsPack
###
####################################

function FindTemp (clip c, string "matrix", bool "show") {

    ID   = color_propGet  (c)
    st   = propNumElements(c,"_SceneStatsU") > 0

    mat  = Default(matrix,   ID[2] )
    sh   = Default(show,      true )
    bi   = ID[7]   bi32 = bi==32

    Assert(IsVersionOrGreater(3,7,2), "FindTemp: Update AviSynth+ version")

    matrix = color_Fuzzy_Search (mat)[0]
    coef   = color_coef(matrix)
    toXYZ  = MatrixTranspose(RGB_to_XYZ(c,string(matrix), list=true))
    Kr     = 1. - coef[0]
    Kb     = 1. - coef[2]

    RGB    = [1.0000000, 0.00000000000000000000,         2 *    Kr,                      \
              1.0000000, 2 * ( -Kb * coef[2] / coef[1]), 2 * ( -Kr * coef[0] / coef[1]), \
              1.0000000, 2 * Kb,                         0.00000000000000000000 ]


    ScriptClip(c,function[bi,bi32,RGB,toXYZ,st,sh] () {

        U  = st   ? propGetFloat("_SceneStatsU")[5] : nop()
        V  = st   ? propGetFloat("_SceneStatsV")[5] : nop()
        U  = bi32 ? st ? U : UPlaneMedian() : ex_bs(st ? U : UPlaneMedian(),  bi, 32, true, flt=true)-0.5
        V  = bi32 ? st ? V : VPlaneMedian() : ex_bs(st ? V : VPlaneMedian(),  bi, 32, true, flt=true)-0.5

        RGB = MatrixDot([1./3,U,V], RGB)
        RGB = ArrayOp(RGB,2.222,"pow(x,y)")  # linearize (assumes 2.40 gamma)
        XYZ = MatrixDot(RGB,toXYZ)

        LMS = XYZ_to_LMS("CAT02",true)

        XYZ = MatrixDot([XYZ[0]/XYZ[1],1.,XYZ[2]/XYZ[1]], LMS)
        XYZ = ArrayOp(XYZ,0.333333,"*")

        xe  = 0.3366
        ye  = 0.1735
        n   = (XYZ[0] - xe)/(XYZ[1] - ye)

        CCT = -949.86315 + 6253.80338 * exp(-n/0.92159) + 28.70599 * exp(-n/0.20039) + 0.00004 * exp(-n/0.07125)

        CCT = 1.1105*pow(CCT,0.989339)-70.9976 # CCT fix

        sh ? Subtitle(string(round(CCT))) : round(CCT) } ) }





###
###
### GreyWorld() - v2.0 (31-03-2022)
###
###
### Remove color cast, including extreme cases like underwater shots.
### If "stats=true" it will compute scene stats given "_SceneRange" frameprops are present.
### HBD processing is recommended (32-bit float not supported yet. RGB not supported)
###
### fast: When 'false' hue/colors don't get skewed nor clipped. Enable for speed ('fast=false' is Work in Progress)
###
### Dependencies: > ExTools
###                 TransformsPack (for fast=false or show=true)
###
### Benchmark:
### 100.0% greyworld (fast=true) (260fps)
###  33.5% greyworld (fast=false)
###  25.4% rgb().ConvertBits(32).grayworld()
###
####################################

function GreyWorld(clip a, bool "fast", bool "Rc", bool "stats", bool "show") {

    rgb  = isRGB(a)
    isy  = isy(a)
    px   = PixelType(a)
    bi   = BitsPerComponent(a)
    rng  = propNumElements (a,"_SceneRange")  > 0
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : false
    bi32 = bi == 32
    fast = Default(fast,  true)
    rc   = Default(Rc,   false) # Recover saturation (WIP)
    sts  = Default(stats,  rng) # Use scene stats to compute color deviation
    sh   = Default(show, false)

    Assert(IsVersionOrGreater(3,7,2), "GreyWorld: Update AviSynth+ version")
    Assert(!rgb && !isy,              "GreyWorld: Only works on YUV formats")
    Assert(sts ? rng : true,          "GreyWorld: 'stats=true' requires '_SceneRange' frame properties")

    HUE = fast ? a : HSVxHSV(a.ConvertBits(8,dither=bi32?-1:1,fulls=fs, fulld=true), 1.0, "HUE", "SAT", 180.0, 1.00, 1.0, show=3).removegrain(12)

    UV  = sts  ? SceneStats(a,"Stats",Y=false,UV=true) : Undefined()

    ScriptClip(a,function[bi,bi32,px,HUE,fast,sts,UV] () {

        Hu = PlaneMinMaxStats(HUE, 1, 0, 0, false)
        Hu = 180 - ((Hu[4] / 224.) * 360 )
        Tw = fast ? last : Tweak(hue=Hu,sat=0.5)
        Ts = fast ? last : Tw.removegrain(-1,12)

        U  = sts ? UV.PropGetAsArray("_SceneStatsU") : PlaneMinMaxStats(Ts, 1, 0, 1, false)
        V  = sts ? UV.PropGetAsArray("_SceneStatsV") : PlaneMinMaxStats(Ts, 1, 0, 2, false)
        U0 = sts ? U[0] : U[0]  U1 =  sts ? U[1] : U[1]  Um = sts ? U[5] : U[4]
        V0 = sts ? V[0] : V[0]  V1 =  sts ? V[1] : V[1]  Vm = sts ? V[5] : V[4]

        H  = bi32 ? 0 : ex_bs(128,  8, bi, true, flt=true)
        Ux = H - Um
        Vy = H - Vm

        Un = U0 - Um   Um = U1 - Um   Ud = min(abs(Un), abs(Um))
        Vn = V0 - Vm   Vm = V1 - Vm   Vd = min(abs(Vn), abs(Vm))

        Us = Ud > Vd ? bi32 ? string(Vd / Ud)+" *" : "range_half - "+string(Vd / Ud)+" * range_half +" : ""
        Vs = Ud < Vd ? bi32 ? string(Ud / Vd)+" *" : "range_half - "+string(Ud / Vd)+" * range_half +" : ""

        Expr(Tw,Tw.SwapUV(),"",Format("x {Ux} + "+Us),Format("x {Vy} + "+Vs), Format=px) # for runtime, LUT calcs make no sense
        fast ? last : Tweak(hue=-Hu,sat=2.0) } )

        rc ? ex_vibrance(0.5,mode="Recover", Rc=a) : last

    if (sh) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=fs) : last
        w   = a.width()
        h   = a.height()
        lvl = StackVertical(a.ConvertBits(8,dither=1,fulls=fs).Vectorscope().subtitle("before",text_color=$FFFFFF,size=12,x=15),\
                                                               Vectorscope().subtitle("after" ,text_color=$FFFFFF,size=12,x=15)).RatioResize(h/512.,"%",kernel="gauss",p=100)
        lvl = !fs ? lvl.SMPTE_Legal(false) : lvl
        StackHorizontal(last,lvl) } }




###
###
### WhitePoint()
###
###
### Accurately adjust the color temperature of the image. Assumes input matrix primaries are D65 based.
### YUV or RGB and HBD recommended.
###
### Dependencies: > ExTools
###                 TransformsPack
###
### Function Definition:
###    (
###    clip,
###    float temperature=6504 (1704 to 14016 by 24),
###    [string "matrix"="709" ("470M"/ "470BG"/ "170M"/ "709"/ "2020CL"/ "2020NCL"/ "Display-P3"/ "ACEScg")],
###    [int "observer"=1931 (1931/ 1964)],
###    [string "locus"="Daylight" ("Daylight"/ "Planckian")],
###    [bool "tv_range"=true]
###    )
###
####################################

function WhitePoint (clip c, float "temperature", string "matrix", string "locus", int "observer", bool "list", bool "tv_range") {

    rgb  = isRGB(c)
    rgbp = rgb ? isPlanar(c) : false
    ID   = color_propGet (c)

    temp = Default(temperature, 6504)  # 1900K ('Rec709' limit) to 25000K. Target temperature in Kelvin units (Default: D65 == nop())
    mat  = Default(matrix,   ID[2] )
    loc  = Default(locus, temp<5000?"Planckian":"Daylight")
    ob   = Default(observer,  1931 )   # Standard Observer 1931 or 2 for 2º Standard Observer. 1964 or 10 for 10º Standard Observer
    tv   = Default(tv_range, ID[6] )
    lis  = Default(list,     false )   # Set to True to output [x,y,z] coordinates of the CCT (correlated color temperature)

    Assert(IsVersionOrGreater(3,7,2), "WhitePoint: Update AviSynth+ version")

    mat  = Color_fuzzy_search(mat)

    rgb ? rgbp ? c : ConvertToPlanarRGB(c) : \
    YUV_to_RGB(c, mat[0], tv_in=tv, tv_out=false, kernel="lanczos", b=3)


    temp3 = 1000.       /     temp
    temp6 = 1000000.    / pow(temp, 2)
    temp9 = 1000000000. / pow(temp, 3)

    # CIE 1931 2º Standard Observer
    if (ob==1931||ob==2) {

        if (loc=="Planckian"||loc=="Blackbody") {

            wpx = temp <= 2900 ? 0.142148 + 1.16453   * temp3 - 0.926236  * temp6 + 0.267565  * temp9 : \
                  temp <= 4000 ? 0.17991  + 0.8776956 * temp3 - 0.2343589 * temp6 - 0.2661239 * temp9 : \
                                 0.24039  + 0.2226347 * temp3 + 2.1070379 * temp6 - 3.0258469 * temp9

            wpx2 = pow(wpx, 2)
            wpx3 = pow(wpx, 3)

            wpy = temp <= 2222 ? -1.1063814 * wpx3 - 1.34811020 * wpx2 + 2.18555832 * wpx - 0.20219683 : \
                  temp <= 2900 ? -2.7749800 * wpx3 + 1.10334000 * wpx2 + 0.97248300 * wpx              : \
                  temp <= 4000 ? -0.9549476 * wpx3 - 1.37418593 * wpx2 + 2.09137015 * wpx - 0.16748867 : \
                                 +3.0817580 * wpx3 - 5.87338670 * wpx2 + 3.75112997 * wpx - 0.37001483

        } else {

            # Valid in the range [0.250, 0.380] (>=4000K) (3000K-3200K range also works as it coincides with Planckian)
            wpx = temp < 5500 ? 0.244058 + 0.0989971 * temp3 + 2.96545 * temp6 - 4.59673 * temp9 : \
                  temp < 8000 ? 0.200033 + 0.9545630 * temp3 - 2.53169 * temp6 + 7.08578 * temp9 : \
                                0.237045 + 0.2437440 * temp3 + 1.94062 * temp6 - 2.11004 * temp9 # there's a dip around 7000K though

            wpy = -0.275275 + 2.87396 * wpx - 3.02034 * pow(wpx,2) + 0.0297408 * pow(wpx,3)

    # CIE 1964 10º Standard Observer
    } } else {

        if (loc=="Planckian"||loc=="Blackbody") {

        wpx = temp <= 4000 ? 0.132123 + 1.245000 * temp3 - 1.06779 * temp6 + 0.335515 * temp9 : \
                             0.240094 + 0.199403 * temp3 + 2.36932 * temp6 - 3.541520 * temp9

        wpx2 = pow(wpx, 2)
        wpx3 = pow(wpx, 3)

        wpy = temp <= 2900 ? -2.885940 * wpx3 + 1.55652 * wpx2 + 0.640988 * wpx + 0.0649384 : \
              temp <= 4000 ? -0.813915 * wpx3 - 1.23629 * wpx2 + 1.89435  * wpx - 0.122346  : \
                              3.482430 * wpx3 - 5.92925 * wpx2 + 3.60717  * wpx - 0.331274

        } else {

            # Should not be used for < 4000K but technically it might be fine down to 2855.496K (Illuminant A)
            wpx = -3.14504 * temp9 + 2.27982 * temp6 + 0.226414 * temp3 + 0.236388

            wpy = -0.176938 + 2.22673 * wpx - 1.67187 * pow(wpx,2) - 0.848624 * pow(wpx, 3)
    } }

    wpz =  1 - wpx - wpy


    if (lis) {

        [wpx,wpy,wpz]

    } else {

        LMS      = XYZ_to_LMS("CAT16",true)

                  # CIE 1931 or 1964 Daylight D65 Daylight Reference White
        RFW      = ob==1931 || ob==2 ? [0.950457,1.,1.089436] : [0.948112,1.,1.073046]
        fw1      = MatrixDot(RFW,LMS)
        fw2      = MatrixDot([wpx/wpy, 1.,wpz/wpy], LMS)
        vonKries = Broadcast(ArrayOp(fw2,fw1,"/"), "vonKries")

        CAM      = MatrixDot(LMS, MatrixDot(vonKries, MatrixInvert(LMS)))

        CCTF(mat[2],  true, false, false)

        mata = RGB_to_XYZ (mat[0], list=true, adaptXYZ=false)
        matb = XYZ_to_RGB (mat[0], list=true, adaptXYZ=false)

        MatrixClip( MatrixDot(MatrixDot(mata, CAM), matb) )

        CCTF(mat[2], false, false, false)

        2850 <= temp <= 2860 ? propSet("_Illuminant", 13) : \
        5000 <= temp <= 5005 ? propSet("_Illuminant",  0) : \
        5450 <= temp <= 5460 ? propSet("_Illuminant",  8) : \
        5500 <= temp <= 5505 ? propSet("_Illuminant",  1) : \
        6000 <= temp <= 6005 ? propSet("_Illuminant",  2) : \
        6300 <= temp <= 6305 ? propSet("_Illuminant",  3) : \
        6500 <= temp <= 6505 ? propSet("_Illuminant",  4) : \
        6755 <= temp <= 6760 ? propSet("_Illuminant",  5) : \
        7500 <= temp <= 7505 ? propSet("_Illuminant",  6) : \
        5095 <= temp <= 5105 ? propSet("_Illuminant", 15) : \
        6600 <= temp <= 6610 ? propSet("_Illuminant", 16) : \
        8940 <= temp <= 8950 ? propSet("_Illuminant",  7) : last

        rgb ? rgbp ? last : MatchClip(c,internal=true) : \
        RGB_to_YUV( mat[0], tv_in=false, tv_out=tv, kernel="bicubic", b=-0.5, c=0.25, Jab=PixelType(c))
    } }





###
### Curve Fitting Evaluator
###
### Dependencies: > ExTools
###                 ResizersPack
###
### Example:
###    GradientLinear(zoom=1,positive=true,precision=4)
###    # ex_contrast(cont=1,tv_range=false)  # Here the 32-bit aware curve expression (for not 32-bit aware expressions, you can use scale_inputs="float" to evaluate expression at 8-bit)
###    HistoCurve(size=2,gradient=true)
###
### Function Definition:
###    (
###    clip,
###    int "zoom"=1 (1 to 6),
###    int "x"=0 (-50 to 50),
###    int "y"=0 (-50 to 50),
###    int "precision"=1 (1 to 4),
###    bool "positive"=false,
###    bool "smooth"=true
###    )
###
######################

function GradientLinear(clip "a", int "zoom", int "x", int "y", bool "positive", int "precision", bool "smooth", bool "tv_range") {

    Da  = Defined (a)
    isy = Da ? isy(a)     : false
    sm  = Default(smooth,   true)            # Enabled for most filters. Disable if you want to test 'blur' filters.
    tv  = Default(tv_range, false)
    global bt = Da ? BitsPerComponent(a) : 0
    global zm = Default(zoom, 2)             # Zoom out factor of the graph
    global xo = Default(x,    0)/(zm*10.)    # shift on x axis
    global yo = Default(y,    0)/(zm*10.)    # shift on x axis
    global ps = Default(positive, false)     # Disable to also show -x and -y axis
    global pc = Default(precision, 1)        # Increase sampling precision

    px = Da ? a.is420() ? "YUV420" : \
              a.is422() ? "YUV422" : \
              a.is444() ? "YUV444" : "YUV420" : "YUV420" # Histogram() only supports YUV formats

    of = zm
    zm = zm * 2.
    BlankClip(Eval(Da ? "a" : "length=100"), width=256*pc, height=256, pixel_type=isy?"Y32":px+"PS")

    !tv ? ex_lutspa(mode="relative", expr=sm?"x":"x 0.5 + 2 % 1 < 0 1 ?",                            UV=128, fulld=true) : \
          ex_lutspa(mode="relative", expr=sm?"x ymax ymin - * ymin +":"x 0.5 + 2 % 1 < ymin ymax ?", UV=128, fulld=false)
     ps ? ex_lut(Format("x {xo} - {of} *        "),"")  : \
          ex_lut(Format("x {xo} - {zm} * {of}  -"),"")  }


# Output is dithered 8-bit
function HistoCurve(clip a, float "size", bool "gradient") {

    sz = Default(size,2.)
    gr = Default(gradient, true)

    of = zm
    zm = zm * 2.
    px = 256 * pc
    py = pc > 1 ? 1024 : 256
    ps ? ex_lut(a,Format("x {of} /         {yo} -"),"") : \
         ex_lut(a,Format("x {of}  + {zm} / {yo} -"),"")

    TurnRight()
    Histogram(mode="classic",keepsource=gr,markers=false,bits=pc>1?10:8)
    TurnLeft()

    zm    = zm * (ps ? 1. : 2.)
    clean = SMPTE_legal(gr ? crop(0,0,0,-256) : last, false)
    clean = pc > 1   ? clean.ex_luts  (mode="max",pixels=pc==2?ex_shape(0,1):ex_shape(1,mode="disk")).ex_smooth(pc==2?0:2) : clean
    grd   =            clean.ex_lutspa(mode="mix",expr=Format("sx {xo} neg {px} * + round X@ {px} {zm} 2 * / round % 0 ==
                                                               sy {yo} neg {py} * + round Y@ {py} {zm} 2 * / round % 0 == or
                                                               X 4 {pc} * % 0 != Y 0 != Y 4 {pc} * % 0 != and or 0.25 0 ? x max x ?"+ ( pc>1 ?" {pc} * " : "")), UV=128)
    axis  = ps ? grd : grd.ex_lutspa(mode="mix",expr=Format("sx {px} 0.5 * {xo} {px} * + round abs ==
                                                     sy 0 != sy {py} 0.5 * {yo} {py} * + round abs == and or 0.35 x max sy {py} 1 - == 0 x ? ?"),       UV=128)
    grad  = gr ? crop(0,py,0,0) : last
            gr ? StackHorizontal(PadResize(grad,px,py,mode="Dilate"),axis) : axis

    pc == 1 ? RatioResize(sz,"%",kernel="Point") : \
    BicubicResize(round(256*sz*(gr?2:1)),round(256*sz),0.378216,0.310892)

    ConvertBits(bt>0?bt:8,dither=bt>0?bt==32?-1:1:-1,fulls=true) }



function Vectorscope(clip a) {
    a
    Histogram(mode="color2",keepsource=false)
    ex_lutspa("sx 128 == sy 128 == or range_max x - 0.5 * x ?",UV=2) # axis
    subtitle("U+\n0º"  ,lsp=1,align=6,text_color=$FFFFFF,size=12)
    subtitle("V+\n90º" ,lsp=1,align=2,text_color=$FFFFFF,size=12,x=128+3,y=256-20)
    subtitle("U-\n180º",lsp=1,align=4,text_color=$FFFFFF,size=12)
    subtitle("V-\n270º",lsp=1,align=8,text_color=$FFFFFF,size=12,x=128+3,y=+6)
    }