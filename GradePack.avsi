###########################################################
###                                                      ##
###                                                      ##
###           Grade Pack v5.2 (08-01-2022)               ##
###                                                      ##
###    https://forum.doom9.org/showthread.php?t=182881   ##
###                                                      ##
###                             by Dogway (Jose Linares) ##
###                                                      ##
###########################################################
###
### Look transforms pack for grading and look tone adjustments.
###
###
####################################
###
### ex_vibrance() v3.2 (07-01-2022)
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
### Dependencies:
###     ExTools
###     ResizersPack   (for show=1)
###     TransformsPack (for show=1)
###     MasksPack      (for show=1)
###
### modes:
###     Saturation: Simple saturation operator without any masks
###     Vibrance:   Masks high saturation so you can lower or raise saturation where is low (Default)
###     Dullness:   Masks low  saturation so you can lower or raise saturation where is high
###     Recover:    Recover lost saturation between source and reference clip
###
###
### Examples:
###     ex_vibrance(1.2, mode="Saturation")    # Increase saturation
###
###     ex_vibrance(1.5)                       # Increase vibrance
###
###     ex_vibrance(0.5)                       # Lower saturation where is low
###
###     ex_vibrance(2.0, mode="Dullness")      # Lower saturation where is high
###
###     ex_vibrance(1.0, mode="Recover", Rc=b) # Recover saturation from clip 'b'
###
### Function Definition:
###    (
###    clip,
###    float sat=1.0 (0.0 to 2.0 by 0.01),
###    string mode="Vibrance" ("Vibrance" / "Dullness" / "Saturation" / "Recover"),
###    float bias=5.0 (0.0 to 10.0 by 0.5),
###    bool "show"=false,
###    )
###
###########################

function ex_vibrance (clip a, float "sat", string "mode", float "bias", clip "Rc", bool "tv_range", int "show") {

    bi    = BitsPerComponent(a)
    fs    = propNumElements (a,"_ColorRange")  > 0 ? \
            propGetInt      (a,"_ColorRange") == 0 : false

    sat   = Default(Sat,  1)          # From 0 to inf. Default 1 (no-op)
    bias  = Default(bias, 5)          # Adjust saturation mask
    md    = Default(mode, "Vibrance")
    tv    = Default(tv_range,    !fs)
    sh    = Default(show,          0) # 0: disabled, 1: show histogram and gamut warning, 2: show mask
    sat   = max(sat, 0)

                    Assert(IsVersionOrGreater(3,7,1), "ex_vibrance: Update AviSynth+ version")
                    Assert(!isRGB(a),                 "ex_vibrance: RGB format not supported")
    md=="Recover" ? Assert(Defined(Rc),               "ex_vibrance: 'Recover' mode requires a clip defined in the 'Rc' parameter to recover saturation from") : nop()

    rangePCc = tv ? "range_max cmax cmin - / *"              : ""
    rangeTVc = tv ? "cmax cmin - range_max / * range_half +" : "range_half +"

    rhlf = bi==32 ? "2 *" : bi > 12 ? "range_half /" : string(1. / ex_bs(128,8,bi,!tv)) + " *"
    msk  = Format("range_half x range_half - XC@ dup * y range_half - dup * + sqrt - "+rhlf+" {bias} ^ M^ ")

    mode = md == "Vibrance"   ? Format(       msk+" XC "+rangePCc+" dup dup   {sat}   * swap -   M   * + "+rangeTVc) : \
           md == "Dullness"   ? Format(       msk+" XC "+rangePCc+" dup dup 1 {sat} / * swap - 1 M - * + "+rangeTVc) : \
           md == "Saturation" ? Format("x range_half - "+rangePCc+"           {sat}                  *   "+rangeTVc) : \
           md == "Recover"    ?                   " XC "+rangePCc+"                                  *   "+rangeTVc  : \
          Assert (false, "ex_vibrance: '"+md+"', unsupported mode")


    if (md == "Saturation" && sh==0) {

        sat == 1 ? a   :                  \
        ex_lut    (a, "", mode, fulls=!tv )

    } else \
    if (md == "Recover"    && sh==0) {

        msk1 = "x range_half - XC@ abs y range_half - abs + "
        msk2 = "z range_half -     abs a range_half - abs + "
        ex_lutxyza(a, a.SwapUV(), Rc, Rc.SwapUV(), "", msk2+msk1+" / 0 max "+mode, fulls=!tv)

    } else {

        if (sh==0 && sat==1) { last } else {

        ex_lutxy  (a, a.SwapUV(), "", fulls=!tv, cstr=sh==2 ? msk+" M 1 swap - range_max *"       : mode )

        w  = a.width()
        h  = a.height()
        if (sh==1) {
            bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
            sw = nmod(w/3.75)
            sh = nmod(w/2.10)
            lvl = Histogram(mode="levels").crop(w,0,0,-h+226)
            lvl = StackVertical(lvl,Histogram(mode="color2").crop(w,0,0,-h+256)).GaussResize(sw,sh,p=100)
            lvl = PadBorders(tv?lvl.SMPTE_Legal(false):lvl,0,0,0,h-sh,mode="[0,128,128]")
            StackHorizontal(GamutWarning(),lvl)

        } else if (sh==2) {
            ExtractU().PropSet("_ColorRange", 0).BicubicResize(w, h, 0, 0.5) } } } }




###
### ex_contrast() - v7.1 (07-01-2022)
###
###
### Applies contrast in the "S" (sigmoidal) curve fashion.
###
###
### Dependencies: > AviSynth+ 3.7.1
###                 ExTools
###                 ResizersPack   (for show=true)
###                 TransformsPack (for show=true)
###                 MasksPack      (for show=true)
###
### Apply over gamma encoded clip
###
### Example: ex_contrast(0.7, 1.0, 125.5, true)  # 125.5 is mid-grey for TV range sources
###
### Function Definition:
###    (
###    clip,
###    float cont=0.0 (-1.0 to 1.0 by 0.1),
###    float sat=1.0 (0.0 to 3.0 by 0.01),
###    float pivot=125.5 (64.0 to 192.0 by 1.0),
###    bool "show"=false,
###    )
###
####################################

function ex_contrast (clip c, float "cont", float "sat", float "pivot", bool "tv_range", int "UV", bool "show") {

    rgb   = isRGB(c)
    isy   = isy(c)
    bi    = BitsPerComponent(c)
    fs    = propNumElements (c,"_ColorRange")  > 0 ? \
            propGetInt      (c,"_ColorRange") == 0 : rgb
    lut   = bi == 32 ? 0 : 1

    # Storing for 'show'
    sc = cont
    ss = sat
    sp = pivot

    UV    = Default(UV, (Defined(sat) ? sat!=1 : Defined(sat)) || rgb ? 3 : 1)
    cont  = Default(cont, 0.0)                     # [-1.0 to +1.0] can set further though
    sat   = Default(sat,  (cont+3)/3)              # [ 0.0 to +inf] By default can't be disabled in RGB
    sh    = Default(show,      false)              # Show the contrast curve
    tv    = Default(tv_range, !fs)                 # TV or PC. Luma range of your source
    pivot = Default(pivot,    !tv ? 127.5 : 125.5) # Pivot: 64 to 192 (roughly)
    si    = bi == 32 || tv ? "none" : "intf"

    pivot = ex_bs(pivot, 8, 32, tv_in=tv || tv && 125.4 < pivot <= 126, tv_out=false) # Pivot to float PC levels

    Assert(IsVersionOrGreater(3,7,1), "ex_contrast: Update AviSynth+ version")

    rangePC  = tv ? "ymin - ymax ymin - /"                     : ""
    rangeTV  = tv ? "ymax ymin - * ymin +"                     : ""
    rangePCc = tv ? "x range_half - range_max cmax cmin - / *" : "x"
    rangeTVc = tv ? "cmax cmin - range_max / * range_half +"   : ""

    cont   = pow(cont + sign(cont), 3.)
    rcont  = 1. / cont

    knee   = 1. / (1. + exp(cont *  pivot))
    shldr  = 1. / (1. + exp(cont * (pivot - 1.)))
    shmkn  = shldr - knee
    rshmkn = 1. / shmkn

    ycont  = "f32 1 1 {cont} {pivot} x "+rangePC+" - * exp + / {knee} - {rshmkn} * "+rangeTV
    yconti = "f32 {pivot} 1 x "+rangePC+" {shmkn} * {knee} + / 1 - log {rcont} * - "+rangeTV
    str    = cont != 0. ? ex_dlut(Format(cont > 0. ? ycont : yconti), bi, !tv) : ""

    cstr = sat != 1. ? Format(rangePCc+" {sat} * "+rangeTVc) : ""
    cstr = rgb ? str : sat==1 ? "" : ex_UVexpr(cstr, UV, bi, rgb, !tv)

    isy     ? Expr(c, str      , lut=lut, scale_inputs=si) : \
    UV == 1 ? Expr(c, str, ""  , lut=lut, scale_inputs=si) : \
              Expr(c, str, cstr, lut=lut, scale_inputs=si)

    if (sh) {

        out = ConvertBits(8,dither=1,fulls=!tv)
        w   = c.width()
        h   = c.height()
        sw  = nmod(w/5.)
        sh  = nmod(w/5.)
        GradientLinear(zoom=1, positive=true, smooth=true, tv_range=tv)
        ex_contrast (sc,ss,sp,tv,128)
        HistoCurve(size=1,gradient=false)
        plt = BicubicResize(sw,sh,-0.5,0.25)
        plt = PadBorders(plt,w-sw,0,0,h-sh)
        plt = Merge(out,plt)
        ex_merge(out,plt,BoxMask(out,w-sw,w,0,sh),UV=3)
    } }



###
### ex_levels() - v4.1 (07-01-2022)
###
###
### Works like internal Levels() but with HBD support out of the box (using autoscaling)
### ...and proper handling of tv range levels
###
### Dependencies: > AviSynth+ 3.7.1
###                 ExTools
###                 ResizersPack   (for show=true)
###                 TransformsPack (for show=true)
###                 MasksPack      (for show=true)
###
### Example: ex_levels(23, 1.200, 255, 0, 255, tv_range=true)
###
### Formula = (input - input_low) / (input_high - input_low)] ^ (1/gamma) * (output_high - output_low) + output_low
###
### Function Definition:
###    (
###    clip,
###    float input_low=0.0 (0.0 to 255.0 by 1.0),
###    float gamma=1.0 (0.0 to 3.0 by 0.01),
###    float input_high=255.0 (0.0 to 255.0 by 1.0),
###    float output_low=0.0 (0.0 to 255.0 by 1.0),
###    float output_high=255.0 (0.0 to 255.0 by 1.0),
###    bool "show"=false,
###    )
###
####################################

# 100.0% Levels       (10*256, 1.40, 245*256, 10*256, 255*256, false, false) (495fps)
#  93.7% ex_levels    (10,     1.40, 245,     10,     255,     false, 1)
#  16.0% oSmoothLevels(10,     1.40, 245,     10,     255,         0, 0)
#
function ex_levels (clip c, float "input_low", float "gamma", float "input_high", float "output_low", float "output_high", bool "tv_range", int "UV", bool "show", bool "clamp_float") {

    rgb  = isRGB(c)
    isy  = isy(c)
    bi   = BitsPerComponent(c)
    fs   = propNumElements (c,"_ColorRange")  > 0 ? \
           propGetInt      (c,"_ColorRange") == 0 : rgb
    bi32 = bi == 32
    lut  = bi32 ? 0 : 1

    # Storing for 'show'
    silo = input_low
    sgam = gamma
    sihi = input_high
    solo = output_low
    sohi = output_high

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

    Assert(IsVersionOrGreater(3,7,1), "ex_levels: Update AviSynth+ version")

    rangePC  = tv ? "x ymin - range_max ymax ymin - / * "        : "x "
    rangeTV  = tv ? " ymax ymin - range_max / * ymin + "         : ""
    rangePCc = tv ? "x range_half - range_max cmax cmin - / * "  : "x range_half - "
    rangeTVc = tv ? " cmax cmin - range_max / * range_half + "   : "  range_half + "

    ilo = ex_bs( ilo, 8, bi, tv_in=tv, tv_out=false)
    ihi = ex_bs( ihi, 8, bi, tv_in=tv, tv_out=false)
    olo = ex_bs( olo, 8, bi, tv_in=tv, tv_out=false)
    ohi = ex_bs( ohi, 8, bi, tv_in=tv, tv_out=false)
    iho = ihi - ilo
    oho = ohi - olo
    ilo = ilo == 0 ? "" : Format(" {ilo} - ")
    olo = olo == 0 ? "" : Format(" {olo} + ")

    gm   = (gam == 1.0)                 ? ""             : string(1. / gam)+" ^ "
    iioo = (gam == 1.0) && (iho == oho) ? gm+string(oho) : Format(" 1 {iho} / * "+gm+" {oho} dup swap2 *")
    str  = ex_dlut(Format(""+rangePC+ilo+" 0 max "+iioo+" swap1 min "+olo+rangeTV), bi, !tv)

    crg  = ex_bs( tv ? 224 : 255, 8, bi, fulls=!tv)
    oho  = oho / float(crg)
    iho  = crg / float(iho)
    rt   = oho * iho
    cstr = ex_UVexpr(Format(rangePCc+" {rt} * "+rangeTVc), UV, bi, rgb, !tv, si)

    isy     ? Expr(c, str      ,                  lut=lut, clamp_float=bi32) : \
    UV == 1 ? Expr(c, str, ""  ,                  lut=lut, clamp_float=bi32) : \
              Expr(c, str, cstr, scale_inputs=si, lut=lut, clamp_float=bi32)

    if (sh) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
        w   = c.width()
        h   = c.height()
        sw  = nmod(w/4.00)
        sh  = nmod(w/2.10)
        lvl = Histogram(mode="levels").crop(w,0,0,-h+226)
        plt = GradientLinear(zoom=1, positive=true, smooth=true, tv_range=tv)
        plt = ex_levels (plt,silo,sgam,sihi,solo,sohi,tv,128)
        plt = HistoCurve(plt,size=1,gradient=false)
        plt = StackVertical(plt,lvl).BicubicResize(sw,sh,-0.5,0.25)
        plt = PadBorders(tv?plt.SMPTE_Legal(false):plt,w-sw,0,0,h-sh)
        plt = Merge(plt)
        ex_merge(last,plt,BoxMask(w-sw,w,0,sh),UV=3) } }


###
### ex_blend() - v3.2 (07-01-2022)
###
###
### Works like Overlay() but supports more modes, better handling of TV range and performs much faster in either 8-bit or HBD.
###
###
### Dependencies: > AviSynth+ 3.7.1
###                 ExTools
###                 TransformsPack (for 'darker'/'lighter')
###
### Example: ex_blend(a, mode="multiply", opacity=1.0, tv_range=true, UV=2)
###
### Function Definition:
###    (
###    clip,
###    string mode="multiply" ("blend" / "interpolation" / "watermark" / "lighter" / "lighten" / "screen" / "softdodge" / "colordodge" / "lineardodge" / "darker" / "darken" / "multiply" / "softburn" / "colorburn" / "linearburn" / "overlay" / "softlight" / "hardlight" / "vividlight" / "linearlight" / "pinlight" / "hardmix" / "glow" / "reflect" / "heat" / "freeze" / "grainextract" / "grainmerge" / "difference" / "exclusion" / "subtract" / "divide" / "extremity" / "negation" / "phoenix"),
###    float opacity=1.0 (0.0 to 1.0 by 0.1),
###    float watermark=1.0 (0.0 to 2.0 by 0.1),
###    )
###
####################################

# 100% ex_blend   (a, mode="multiply")
#  99% OverlayPlus(a, mode="multiply",chroma=false) # only in PC range
#  92% Overlay_MTools(mode="multiply")              # only in PC range
#  56% Overlay       (mode="multiply")              # only in PC range

function ex_blend(clip a, clip b, string "mode", float "opacity", float "watermark", bool "tv_range", int "UV") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb
    lut  = bi < 16 ? 2 : 0

    md   = Default(mode, "multiply")
    op   = Default(opacity,     1.0)
    wm   = Default(watermark,   1.0)  # 0.0 to 2.0. At default 1.0 behaves like 'blend'
    tv   = Default(tv_range,    !fs)  # TV or PC. Luma range of your source
    UV   = Default(UV,  rgb ? 3 : 1)
    si   = ex_UVf(rgb, bi)

                                        Assert(IsVersionOrGreater(3,7,1), "ex_blend: Update AviSynth+ version")
    md == "darker" || md == "lighter" ? Assert(rgb && UV == 3,            "ex_blend: 'darker' and 'lighter' modes require RGB inputs and UV = 3.") : nop()
    op  = min(max(op,0.),1.)
    iso = op == 1.0

    md = md == "add"   ? "lineardodge" : \
         md == "burn"  ? "colorburn"   : \
         md == "dodge" ? "colordodge"  : md

    rngmx = tv   ? "ymax ymin -" : "range_max"
    srcmx = tv   ? "ymin -"      : ""
    V     = !iso ? "A@"          : ""

    # "softlight" uses Pegtop's improved formula
    # Half the modes ported from HAvsFunc, some from Overlay_MTools(), some from Blend_MT_alpha3 and rest from web
    str = Format(                                                                                                                                                                 \
                                                                                                                                                                                  \
        md == "blend"        ? iso ? "y" : "x "+srcmx+" dup y "+srcmx+" swap - {op} * + "                                                                                       : \
        md == "interpolation"? "x "+srcmx+" "+V+" "+rngmx+" / pi * cos 0.25 * 0.5 swap - y "+srcmx+" "+rngmx+" / pi * cos 0.25 * - "+rngmx+" * "                                : \
        md == "watermark"    ? "x "+srcmx+" A^ y "+srcmx+" "+rngmx+" B@ / 0 max 1 {wm} {op} ^ / ^  B * "                                                                        : \
                             \
        md == "lighter"      ? "see footer"                                                                                                                                     : \
        md == "lighten"      ? "x "+V+" y max "                                                                                                                                 : \
        md == "screen"       ? ""+rngmx+" C@ dup x "+srcmx+" "+V+" - C y "+srcmx+" - * C / - "                                                                                  : \
        md == "softdodge"    ? "x "+srcmx+" A@ y "+srcmx+" B@ + "+rngmx+" < A range_half "+srcmx+" * "+rngmx+" B - C@ / "+rngmx+" C range_half "+srcmx+" * A / - ? "            : \
        md == "colordodge"   ? "x "+srcmx+" "+V+" "+rngmx+" * "+rngmx+" y "+srcmx+" 0 max - / "                                                                                 : \
        md == "lineardodge"  ? "x "+srcmx+" "+V+" y "+srcmx+" + "                                                                                                               : \
                             \
        md == "darker"       ? "see footer"                                                                                                                                     : \
        md == "darken"       ? "x "+V+" y min "                                                                                                                                 : \
        md == "multiply"     ? "x "+srcmx+" "+V+" y "+srcmx+" * "+rngmx+" / "                                                                                                   : \
        md == "softburn"     ? "y "+srcmx+" B@ x "+srcmx+" A@ + "+rngmx+" < B range_half "+srcmx+" * "+rngmx+" A - C@ / "+rngmx+" C range_half "+srcmx+" * B / - ? "            : \
        md == "colorburn"    ? ""+rngmx+" dup x "+srcmx+" "+V+" - "+rngmx+" * y "+srcmx+" 0 max / - "                                                                           : \
        md == "linearburn"   ? "x "+srcmx+" "+V+" y "+srcmx+" + B@ "+rngmx+" < 0 B "+rngmx+" - ? "                                                                              : \
                             \
        md == "overlay"      ? "x "+srcmx+" A@ range_half "+srcmx+" < 2 A y "+srcmx+" B@ * "+rngmx+" / * "+rngmx+" 2 "+rngmx+" A - "+rngmx+" B - * "+rngmx+" / * - ? "          : \
        md == "softlight"    ? ""+rngmx+" C@ x "+srcmx+" A@ - A y "+srcmx+" B@ * C / * A C dup A - C B - * C / - * + C / "                                                      : \
        md == "hardlight"    ? "y "+srcmx+" B@ range_half "+srcmx+" < 2 B x "+srcmx+" A@ * "+rngmx+" / * "+rngmx+" 2 "+rngmx+" B - "+rngmx+" A - * "+rngmx+" / * - ? "          : \
        md == "vividlight"   ? "y "+srcmx+" B@ range_half "+srcmx+" C@ < B 0 <= 2 B * "+rngmx+" dup x "+srcmx+" A@ - "+rngmx+" * 2 B * / - ? 2 B C - * "+rngmx+" >= 2 B C - * A "+rngmx+" * "+rngmx+" 2 B C - * - / ? ? ": \
        md == "linearlight"  ? "x "+srcmx+" A@ range_half "+srcmx+" < A 2 y "+srcmx+" B@ * + "+rngmx+" - A 2 B range_half "+srcmx+" - * + ? "                                   : \
        md == "pinlight"     ? "y "+srcmx+" B@ range_half "+srcmx+" < x "+srcmx+" A@ 2 B * min A 2 B range_half "+srcmx+" - * max ? "                                           : \
        md == "hardmix"      ? "x "+srcmx+" "+V+" "+rngmx+" y "+srcmx+" - < 0 "+rngmx+" ? "                                                                                     : \
                             \
        md == "glow"         ? "y "+srcmx+" dup * "+rngmx+" x "+srcmx+" "+V+" 0 max - / "                                                                                       : \
        md == "reflect"      ? "x "+srcmx+" "+V+" dup * "+rngmx+" y "+srcmx+" 0 max - /  "                                                                                      : \
        md == "heat"         ? ""+rngmx+" dup y "+srcmx+" - dup * x "+srcmx+" 0 max "+V+" / "+rngmx+" min - "                                                                   : \
        md == "freeze"       ? ""+rngmx+" dup x "+srcmx+" "+V+" - dup * y "+srcmx+" 0 max / "+rngmx+" min - "                                                                   : \
                             \
        md == "grainextract" ? "x "+srcmx+" "+V+" y "+srcmx+" - range_half "+srcmx+" + "                                                                                        : \
        md == "grainmerge"   ? "x "+srcmx+" "+V+" y "+srcmx+" + range_half "+srcmx+" - "                                                                                        : \
                             \
        md == "difference"   ? "x "+srcmx+" "+V+" y "+srcmx+"                    - abs   "                                                                                      : \
        md == "exclusion"    ? "x "+srcmx+" A@ dup y "+srcmx+" B@ + 2 A * B * + + "+rngmx+" / "                                                                                 : \
        md == "subtract"     ? "x "+srcmx+" "+V+" y "+srcmx+" - "                                                                                                               : \
        md == "divide"       ? ""+rngmx+" x "+srcmx+" "+V+" * y "+srcmx+" 0 max / "                                                                                             : \
        md == "extremity"    ? ""+rngmx+"        x "+srcmx+" "+V+" - y "+srcmx+" - abs   "                                                                                      : \
        md == "negation"     ? ""+rngmx+" dup    x "+srcmx+" "+V+" - y "+srcmx+" - abs - "                                                                                      : \
        md == "phoenix"      ? "x "+srcmx+" "+V+" y "+srcmx+" dup1 dup1 min swap2 max - "+rngmx+" + "                                                                           : \
                             \
                               Assert (false, "ex_blend: '"+md+"', unsupported blend mode") )


    off = !tv || md == "lighten" || md == "darken" ? "" : " ymin + "
    str = iso || md == "blend" ? str+off : \
                                 str+Format(" A - {op} * A + ")+off

    if (md == "darker" || md == "lighter") {

        Ra = a.ExtractR()  Rb = b.ExtractR()
        Ga = a.ExtractG()  Gb = b.ExtractG()
        Ba = a.ExtractB()  Bb = b.ExtractB()

        sym  = md == "darker" ? "<" : ">"
        msk  = Expr(Ra, Ga, Ba, Rb, Gb, Bb, ex_dlut("x y z + + a b c + + "+sym+" 0 range_max ?", bi, !tv), format=PixelType(a))

        ex_merge(a, b, msk, luma=false, UV=3)

    } else {

    cstr = ex_UVexpr(str, UV, bi, rgb, !tv, si)
    str  = ex_dlut  (str, bi, !tv)

    isy     ? Expr(a, b, str,                        optSingleMode=true, lut=lut) : \
    UV == 1 ? Expr(a, b, str, "",                    optSingleMode=true, lut=lut) : \
              Expr(a, b, str, cstr, scale_inputs=si, optSingleMode=true, lut=lut) } }



###
### ex_glow()
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
        bop = md == "fib" ? floor(pow((1+sqrt(5))/2,i)/sqrt(5)+0.5)               :\
                            floor(0.618033988749895*pow(1.839286755214161,i)+0.5)
        bop = min((1./ bop) * 10, 1)
        str = str + Format("""ex_blend("""+c+"""ex_kawase(b,{i},md,{uv}),"screen",{bop},1,false,{uv})""")+dot
           }

    Eval(str)
    d = ex_makediff(last,b,dif=false,UV=uv,fulls=fs).moncurve_r(2.222222,0.0,false,tv,uv)
    rd != 0 ? ex_blend(a,d,"screen",op,1,tv,uv) : a }



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
###    int bits=3 (0 to 7 by 1),
###    int mode=-1 (-1 to 7 by 1), ;-1: round  0: Bayer ordered  1: Floyd-Steinberg ED  2: Sierra-2-4A ED  3: Stucki ED  4: Atkinson ED  5: Ostromoukhov ED  6: Void & cluster ordered  7: Quasirandom
###    )
###
function ex_posterize (clip c, int "bits", int "mode", int "UV") {

    rgb  = isRGB(c)
    bi   = BitsPerComponent(c)
    fs   = propNumElements (c,"_ColorRange")  > 0 ? \
           propGetInt      (c,"_ColorRange") == 0 : rgb

    bits = Default(bits,     3)    # Valid range: 0 - 7
    md   = Default(mode,    -1)    # Valid modes: -1: round  0: Bayer ordered  1: Floyd-Steinberg ED  2: Sierra-2-4A ED  3: Stucki ED  4: Atkinson ED  5: Ostromoukhov ED  6: Void & cluster ordered  7: Quasirandom
    UV   = Default(UV, rgb ? 3 : 2)

    mul  = string(Pow (2, 8 - bits - 1))
    bits = max(min(bits,7),0)

    ConvertBits(c,16, fulls=fs, fulld=fs)

    ex_lut ("x "+mul+" /", y=3, UV=UV, fulls=fs)

    md < 2 ? ConvertBits  (bits=8, dither=md,   fulls=fs, fulld=fs) : \
    md > 4 ? fmtc_bitdepth(bits=8, dmode =md+2, fulls=fs, fulld=fs) : \
             fmtc_bitdepth(bits=8, dmode =md+1, fulls=fs, fulld=fs)

    ex_lut ("x "+mul+" *", y=3, UV=UV, fulls=fs)

    ConvertBits(bi, fulls=fs, fulld=fs) }




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
###    float str=0.8 (0.1 to 2.0 by 0.01),
###    float Delta=43.0 (0.0 to 360.0 by 1.0),
###    float Q=0.7 (0.0 to 1.0 by 0.01),
###    float blur=3.0 (0.0 to 6.0 by 0.5),
###    bool invert=false,
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

    Assert(IsVersionOrGreater(3,7,1), "Skin_Qualifier: Update AviSynth+ version")

    dg  = (-1 * dg) * (pi / 180)        # IPT HUE goes reverse so "-1 *"
    LO  = 1-bw
    HI  = 1-bw/(3.01-min(str,1))
    mat = Color_fuzzy_search(ID[2])
    gm  = moncurve_coef(mat[0])

    rgb ? IsPlanar(c) ? c : ConvertToPlanarRGB(c) : c

    bi < 14 ? ConvertBits(14, fulls=fs)                                : last
    !rgb    ? ConvertToPlanarRGB(matrix=mat[0])                        : last
              moncurve_f(gm[0], gm[1], !rgb ? false : !fs, false, UV=3)

    RGB_to_Oklab(matrix=mat[0], Jch=true, fulls=true)

    C     = ExtractG()
    H     = ExtractB()
    Cnorm = "x 0.28 - abs 1 swap - 0 swap 0.706 - -3.4 * -" # Centered at skin saturation and normalized
    in    = in ? "1 swap -" : ""

    ex_lutxy(C, H, Format("f32 y 6.283185 * pi - {dg} + cos "+Cnorm+" * 0 swap {LO} - 1 {LO} {HI} - / * - "+in), scale_inputs="intf", fulls=true, clamp_float=true)

    ConvertBits(bi, dither= bi==32 ? -1 : 1, fulls=true)
    ex_gaussianblur(bl, pad=false, UV=3)               }




### HSVxHSV() - (07-01-2022)
###
### 3x3 operator matrix. Adjust Hue, Saturation or Luminance based on Hue, Saturation or Luminance.
### This is similar to internal Tweak(), but double the speed, easier to use and more modes (+5 modes involving 'LUM')
###
### Dependencies:
###     ExTools 7.1+
###     TransformsPack
###     ResizersPack  (for show=1)
###     MasksPack     (for show=1)
###
### This includes the following 9 operators (modeA x modeB):
###   HUExHUE
###   HUExSAT
###   HUExLUM
###   SATxHUE
###   SATxSAT (This is similar to ex_vibrance() )
###   SATxLUM
###   LUMxHUE
###   LUMxSAT
###   LUMxLUM
###
### Note:
###     To add as a function definition to enable sliders, include the following in AvsPmod.
###     (
###     clip,
###     float str=1.0 (0.0 to 360.0 by 0.1),
###     string modeA="HUE" ("HUE"/ "SAT"/ "LUM"),
###     string modeB="LUM" ("HUE"/ "SAT"/ "LUM"),
###     float Delta=1.0 (0.0 to 360.0 by 1.0),
###     float Q=1.0 (0.0 to 1.0 by 0.01),
###     float Opacity=1.0 (0.0 to 1.0 by 0.1),
###     int "show"=1 (0 to 2),
###     )
###
function HSVxHSV (clip c, float "str", string "modeA", string "modeB", float "Delta", float "Q", float "Opacity", float "tv_range", int "show") {

    rgb = IsRGB(c)
    isy = isy(c)
    ID  = color_propGet(c)
    bi  = ID[7]
    bi32= bi==32

    str = Default (str,     0.1)   # Strength of 'modeB' operator. 0-360 for 'L' and 'H' and 0.0-4.0 for 'S'
    mA  = Default (modeA, "HUE")   # 'modeA' (HUE or H, SAT or S, LUM or L or V)
    mB  = Default (modeB, "SAT")   # 'modeB' (HUE or H, SAT or S, LUM or L or V)
    dA  = Default (Delta,   0.5)   # Degrees of 'modeA' (isolate this area. 0-255 for 'L', 0-360 for for 'H' and 0.0-100.0 for 'S')
    bA  = Default (Q,       0.2)   # Q-factor (Bandwidth) of 'modeA' Spread of the isolated area. 0.0-1.0
    sA  = Default (opacity, 1.0)   # Scale   of 'modeA' Scale  of the isolated area (typical to scale down since by default it's white). 0.0-1.0
    tv  = Default (tv_range, ID[6])
    sh  = Default (show,      0)   # 0: disabled, 1: show histogram, 2: show mask
    sh2 = sh == 2
    si  = tv ? "int" : "intf"

    Assert(IsVersionOrGreater(3,7,1), "HSVxHSV: Update AviSynth+ version")
    Assert(!isy && !rgb,              "HSVxHSV: Only YUV format is supported")

    U   = ExtractU(c)
    V   = ExtractV(c)
    Yf  = ExtractY(c)
    Ys  = is444(c) ? Yf : Yf.BicubicResize(U.width(),U.height(),-0.5,0.25)
    c4  = is444(c) ? c : c.ConverttoYUV444(matrix=ID[2],chromaresample="spline16")
    c4U = ExtractU(c4)
    c4V = ExtractV(c4)
    Uc  = YtoUV(U,U,c4U)
    Vc  = YtoUV(V,V,c4V)
    Y   = YtoUV(Ys,Ys,Yf)

    mA  = mA=="H" ? "HUE" : \
          mA=="S" ? "SAT" : \
          mA=="V" ? "LUM" : \
          mA=="L" ? "LUM" : mA
    mB  = mB=="H" ? "HUE" : \
          mB=="S" ? "SAT" : \
          mB=="V" ? "LUM" : \
          mB=="L" ? "LUM" : mB
    nul = mB=="SAT" ? str==1.0 : mB=="LUM" ? str==180. : str==0.0 || str==360.0

    dA  = mA=="HUE" ? min(360,max(0,dA))/360. : \
          mA=="LUM" ? min(255,max(0,dA))/255. : \
          mA=="SAT" ? min(100,max(0,dA))/100. : dA

    sc  = 0.32*atan(0.32*tan((dA+0.507)/0.32))+0.5 # less granularity to extremes and more to center
    dA  = mA=="SAT" ? min(1,sc) : dA

    str = mB=="HUE" ? str * ( pi /180.)                        :          \
          mB=="LUM" ? 1./((str/360.) * (0.5 + str/360.) + 0.5) : min(6,str)
    sA  = sA < 1.0  ? string(sA)+" * "    : ""

    bA  = 1. / (mA=="SAT" ? dA < 0.5 ? bA/2 : bA/(2-4*pow(dA-0.5,2)) : bA)

    rangePC  = tv ? "ymin - ymax ymin - /"      : ""
    rangeTV  = tv ? "ymax ymin - * ymin +"      : ""
    rangePCc = tv ? "range_max cmax cmin - / *" : ""
    rangeTVc = tv ? "cmax cmin - range_max / *" : ""

    offS     = bi32 || (mB=="SAT" && !sh2) ? "" : " 0.5 - "
    varX     = mB=="HUE" ? " X@" : mA=="HUE" && mB=="SAT" ? " X@" : ""
    varY     = mB=="HUE" ? " Y@" : mA=="HUE" && mB=="SAT" ? " Y@" : ""
    varM     = mB!="HUE" ?    "" : mA=="SAT" ? "S@" : mA=="HUE" ? "H@" : ""

    clpB = mA=="LUM" && mB=="LUM" ? " X"           : \
           mB=="LUM"              ? " x "+rangePC  : \
           mA=="LUM" && mB!="HUE" ? " y "+rangePCc : \
           mA=="HUE" ? mB=="SAT"  ? " X" :    " H" : \
           mB!="HUE"              ? " x "+rangePCc : mA=="SAT" ? " X Y atan2" : " y "+offS+rangePCc+varX+" z "+offS+rangePCc+varY+" atan2 "

    msk = mA=="LUM" ? Format("f32 x "     +rangePC+" X@                                                                  {dA} - abs 1 swap - {bA} ^       0 1 clip "+sA) : \
          mA=="SAT" ? Format("f32 x "+offS+rangePCc+varX+" dup * y "+offS+rangePCc+varY+" dup * + sqrt 0.5 + "+varM+"    {dA} - abs 1 swap - {bA} ^ 0.5 - 0 1 clip "+sA) : \
                      Format("f32 x "+offS+rangePCc+varX+"       y "+offS+rangePCc+varY+" atan2 "+varM+" pi + 0.159155 * {dA} + 1 % {bA} ^ "+sA) # "0.159155 *" = "pi 2 * /"
    op  = mB=="LUM" ? Format(clpB+" dup dup dup dup 0.005 > swap {str} ^ swap ? 0 1 clip    swap - swap swap2 * + "+rangeTV)  : \
          mB=="SAT" ? Format(clpB+" dup dup                      {str} *                    swap - swap swap2 * + "+rangeTVc) : \
                      Format(clpB+" dup dup                      {str} pi + + pi 2 * % pi - swap - swap swap2 * + " )


    if (sh2) {

        msk  = ReplaceStr(msk, "X@", "").ReplaceStr("Y@", "").ReplaceStr("^ 0.5 -", "^")

        mA=="LUM" ? ex_lut  (c,       msk, UV=128, scale_inputs=si) : \
                    ex_lutxy(c4U,c4V, msk, UV=1,   scale_inputs=si)
                    PropSet("_OutGamut", 0)

    } else if (nul) {

        c

    } else if (mB!="LUM" && (mA=="HUE" || mB=="HUE")) {

        if (mB=="HUE") {

            # modeAxHUE
            bi32H = bi32 ? "" : " 0.5695 + "
            clpS  = mA=="SAT" ? "S" : "X dup * Y dup * + sqrt "
            msk   = mA=="SAT" ? ReplaceStr(msk, "0.5 + S@", "S@ 0.5 +") : msk
            mBU   = msk+op+" sin "+clpS+" * "+bi32H+rangeTVc
            mBV   = msk+op+" cos "+clpS+" * "+bi32H+rangeTVc

            U = mA=="LUM" ? ex_lutxyz(Ys,U,V,mBU,scale_inputs=si) : ex_lutxy(U,V,mBU,scale_inputs=si)
            V = mA=="LUM" ? ex_lutxyz(Ys,U,V,mBV,scale_inputs=si) : ex_lutxy(U,V,mBV,scale_inputs=si)
            CombinePlanes(Yf, U, V, planes="YUV",Pixel_Type=PixelType(c))

        } else if (mA=="HUE") {

            # HUExSAT
            mskV  = ReplaceStr(msk, " x ", " z ").ReplaceStr(" y ", " x ").ReplaceStr(" z ", " y ")
            opV   = ReplaceStr(op,  " X ", " Y ")

            U  = ex_dlut(msk +op,  32, !tv)
            V  = ex_dlut(mskV+opV, 32, !tv)
            Expr(c,c.SwapUV(),"",U,V,scale_inputs=si,Format=PixelType(c))

        }

    } else {

    msk = mA=="LUM" && mB!="LUM" && !bi32 ? ReplaceStr(msk," x ",  " x 0.5 + ")                   : \
          mA!="LUM" && mB=="LUM"          ? ReplaceStr(msk," y ", " z ").ReplaceStr(" x ", " y ") : msk

    # In order: LUMxLUM, LUMxSAT, SATxLUM, HUExLUM, SATxSAT
    mA=="LUM"   ? mB=="LUM" ? ex_lut   (c,                 msk+op,UV=2,   scale_inputs=si) : \
                              ex_lutxyz(Y,c,c.SwapUV(),"", msk+op,UV=3,   scale_inputs=si) : \
                  mB=="LUM" ? ex_lutxyz(c,Uc,Vc,           msk+op,UV=2,   scale_inputs=si) : \
                              ex_lutxy (  c,c.SwapUV(),"", msk+op,UV=3,   scale_inputs=si) }

    if (sh==1) {
        bi > 8 ? ConvertBits(8,dither=1,fulls=!tv) : last
        w   = c.width()
        h   = c.height()
        sw  = nmod(w/3.85)
        sh  = nmod(w/2.10)
        lvl = Histogram(mode="levels").crop(w,0,0,-h+226)
        lvl = StackVertical(lvl,Histogram(mode="color2").crop(w,0,0,-h+256)).GaussResize(sw,sh,p=100)
        lvl = PadBorders(tv?lvl.SMPTE_Legal(false):lvl,0,0,0,h-sh,mode="[0,128,128]")
        StackHorizontal(last,lvl) } }





###
###
### GamutWarning() - (30-12-2021)
###
###
### Shows pixels that fall out-of-gamut when converting YUV to RGB PC range.
### Supported color spaces are "Rec709", "170M", "470M", "470BG/Rec601" and "2020NCL".
### Enable 'EBUR103' for relaxed thresholds based on the normative and write to '_OutGamut' frameprops.
###
### Legend:
###     Blue: U     plane   is out of gamut
###     Red:  V     plane   is out of gamut
###     Fux:  U & V planes are out of gamut
###
###
### Dependencies: > AviSynth+ 3.7.1
###                 ExTools
###                 TransformsPack
###
####################################

/*
# Tolerances on colour gamut (https://tech.ebu.ch/docs/r/r103.pdf)
    The EBU recommends that the colour gamut in television programme material can be accepted if
    both the following conditions are met:

    •LUMINANCE:   The luminance signal should lie inside the range -1% to 103% (ie. 14-242 for 8-bit legal)
    •CHROMINANCE: When matrixed to RGB, all of the R, G or B signals should lie inside the range -5% and 105% (ie. 5-246 for legal and -12.75-267.75 for 8-bit full range)
    •Measuring equipment should indicate an “Out-of-Gamut” occurrence only after the error exceeds 1% of the image histogram for either luminance or chrominance within the preferred ranges described above

# Horizontal Signal Filtering
    In order to remove transient over and under-excursions of the signals, and to minimise the effect of
    high frequency noise on the colour gamut measurements, the use of appropriate filters in all measurement channels are recommended
    A quarter band filter applied horizontally and a half band filter applied vertically is recommended.
*/

function GamutWarning(clip yuv, string "matrix", bool "tv_in", bool "EBUR103", bool "show") {

    propIDs = color_propGet(yuv)
    bi      =  propIDs[7]
    fs      = !propIDs[6]

    mat     = Default (matrix, propIDs[2])
    tv      = Default (tv_in,         !fs)
    ebu     = Default (EBUR103,     false)  # Enable for EBU R103 (frameprops and less strict thresholds)
    sh      = Default (show,        false)

    Assert(IsVersionOrGreater(3,7,1), "GamutWarning: Update AviSynth+ version")
    Assert(!isRGB(yuv),               "GamutWarning: Only YUV format supported")

    mat     = Color_Fuzzy_search (mat)
    coef    = Matrix_coef(mat[0])


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

    Expr(Y,yuv,yuv.SwapUV(),"",ex_dlut(Format("x "+rangeY+" X@ "+string(m0)+" * z "+UVf+" Z@ "+string(m2)+" * +                      dup {pn} < swap {pm} > or
                                               X               "+string(m6)+" * y "+UVf+" Y@ "+string(m7)+" * +                      dup {pn} < swap {pm} > or or
                                               X               "+string(m3)+" * Y            "+string(m4)+" * + Z "+string(m5)+" * + dup {pn} < swap {pm} > or or range_max y ?"), bi, !tv), format=PixelType(yuv))

    if (sh) {

        bin = ex_lut("x range_size 1 - < 0 x ?",Y=1,UV=3)
        div = (ex_bs(256, 8, bi, !tv)-1)*(2/100.)

        ScriptClip( function[bin,div] () {

            U = bin.ExtractU().AverageLuma()
            V = bin.ExtractV().AverageLuma()
            Subtitle("Out of Gamut: "+string((U+V)/div,"%1.3f")+"%") # In percentage
        } )

    }

    !ebu ? last : \
    ScriptClip( function[bi,tv] () {

        # Evaluate also Luminance (Y) stats?
        U  = PlaneMinMaxStats(last, 99, 0, 1, false)
        V  = PlaneMinMaxStats(last, 99, 0, 2, false)
        U  = ex_bs(U[2], bi, 8, !tv,     float=true)    U = bi==32 ? 2 * U + 1 : U
        V  = ex_bs(V[2], bi, 8, !tv,     float=true)    V = bi==32 ? 2 * V + 1 : V

        U >= 255 || V >= 255 ? PropSet("_OutGamut", 1) : \
                               PropSet("_OutGamut", 0) } ) }



###
###
### Vignette() - v4.0 (06-01-2022)
###
###
### Adds a vignette (darkening around the frame) to the source.
### Use show=true if you only want the mask.
###
### Dependencies: > AviSynth+ 3.7.1
###                 ExTools
###
####################################


function Vignette (clip c, float "Vignette", bool "show", bool "tv_range") {

    str   = Default(Vignette, 0.5)
    show  = Default(show,    false)
    tv    = Default(tv_range, true)
    str   = pow((min(1,max(0,str)) + 0.5) / 1.5, 0.5)

    Assert(IsVersionOrGreater(3,7,1), "Vignette: Update AviSynth+ version")

    msk = ex_lutspa(c, Format("x  width 0.5 * - abs width 0.5 * / range_max * 1.5 {str} 0.5 * + ^ range_max / 0 max "+ \
                              "y height 0.5 * - abs width 0.5 * / range_max * 1.5 {str} 0.5 * + ^ range_max / 0 max "+ \
                              "+ range_max min range_max - abs")+(tv ? " ymax ymin - range_max / * ymin +" : ""), UV=128, fulld=!tv)

    show ? msk : ex_blend(msk, c, mode="multiply", UV=4, tv_range=tv) }



###
###
### greyscale_rgb()
###
###
### Properly convert RGB to luminance (gamma encoded)
###
### Dependencies: > AviSynth+ 3.7.1
###                 TransformsPack
###
####################################

function greyscale_rgb (clip rgb, string "matrix", bool "tv_range") {

    ID     = color_propGet(rgb)

    tv     = Default (tv_range, ID[6])
    matrix = Default (matrix,   ID[2])

    Assert(IsVersionOrGreater(3,7,1), "greyscale_rgb: Update AviSynth+ version")
    Assert(isRGB(rgb),                "greyscale_rgb: Only works on RGB format")

    rgb
    matrix = Color_fuzzy_search(matrix)
    s_gam  = moncurve_coef(matrix[0])
    coeffs = RGB_to_XYZ   (matrix[0], list=true)

    ConvertToPlanarRGB()

    moncurve_f(s_gam[0], s_gam[1], tv, false)

    DotClip(last, [coeffs[1],coeffs[4],coeffs[7]])

    moncurve_r(s_gam[0], s_gam[1], false, false) }



###
###
### WhitePoint()
###
###
### Accurately adjust the color temperature of the image
###
### Dependencies: > AviSynth+ 3.7.1
###                 TransformsPack
###                 ExTools
###
### Function Definition:
###    (
###    clip,
###    int temperature=6504 (4004 to 12004 by 1),
###    string matrix="Rec709" ("470M" / "470BG" / "Rec601" / "Rec709" / "Rec2020" / "Rec2020" / "Display-P3" / "ACEScg"),
###    )
###
####################################

function WhitePoint (clip c, int "temperature", string "matrix", bool "tv_range") {

    rgb  = isRGB(c)
    rgbp = rgb ? isPlanar (c) : false
    ID   = color_propGet(c)

    temp = Default(temperature, 6504)  # Target temperature in Kelvin units (Default: D65 == nop())
    mat  = Default(matrix,   ID[2] )
    tv   = Default(tv_range, ID[6] )

    Assert(IsVersionOrGreater(3,7,1), "WhitePoint: Update AviSynth+ version")

    mat   = Color_fuzzy_search(mat)
    s_gam = moncurve_coef(mat[0])

    rgb ? rgbp ? c : ConvertToPlanarRGB(c) : \
    YUV_to_RGB(c, mat[0], tv_range_in=tv, tv_range_out=false, kernel="Point", cplace="")

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

    moncurve_f(s_gam[0], s_gam[1], false, false, 1)

    mata = RGB_to_XYZ (mat[0], list=true)
    matb = XYZ_to_RGB (mat[0], list=true)
    MatrixClip( MatrixDot(MatrixDot(mata, CAM), matb) )

    moncurve_r(s_gam[0], s_gam[1], false, false, 1)

    rgb ? rgbp ? last : MatchClip(c) : \
    RGB_to_YUV( mat[0], tv_range_in=false, tv_range_out=tv, kernel="Point", pixel_type=PixelType(c), cplace="") }





###
### Curve Fitting Evaluator
###
### Dependencies:
###            ExTools
###            ResizersPack
###
### Example:
###    GradientLinear()
###    # ex_contrast(cont=1,tv_range=false)  # Here the 32-bit aware curve expression (for not 32-bit aware expressions, you can use scale_inputs="int" with 'f32' decorator to scale to 32-bit)
###    HistoCurve()
###
### Function Definition:
###    (
###    clip,
###    int "zoom"=1 (1 to 6 by 1),
###    int "x"=0 (-50 to 50 by 1),
###    int "y"=0 (-50 to 50 by 1),
###    bool "positive"=false,
###    bool "smooth"=true,
###    )
###
######################

function GradientLinear(clip "a", int "zoom", int "x", int "y", bool "positive", bool "smooth", bool "tv_range") {

    sm = Default(smooth,   true)             # Enabled for most filters. Disable is you want to test 'blur' filters.
    tv = Default(tv_range, false)
    global zm = Default(zoom, 2)             # Zoom out factor of the graph
    global xo = Default(x,    0)/(zm*10.)    # shift on x axis
    global yo = Default(y,    0)/(zm*10.)    # shift on x axis
    global ps = Default(positive, false)     # Disable to also show -x and -y axis

    of = zm
    zm = zm * 2.
    BlankClip(Eval(Defined(a) ? "a" : "length=100"), width=256, height=256, pixel_type="YUV420PS")

    !tv ? ex_lutspa(mode="relative", expr=sm?"x":"x 0.5 + 2 % 1 < 0 1 ?",                            UV=128, fulld=true) : \
          ex_lutspa(mode="relative", expr=sm?"x ymax ymin - * ymin +":"x 0.5 + 2 % 1 < ymin ymax ?", UV=128, fulld=false)
     ps ? ex_lut(Format("x {xo} - {of} *        "),"")  : \
          ex_lut(Format("x {xo} - {zm} * {of}  -"),"")  }



function HistoCurve(clip a, float "size", bool "gradient") {

    sz = Default(size,2.)
    gr = Default(gradient, true)

    of = zm
    zm = zm * 2.
    ps ? ex_lut(a,Format("x {of} /         {yo} -"),"") : \
         ex_lut(a,Format("x {of}  + {zm} / {yo} -"),"")
    TurnRight()
    Histogram(mode="classic")
    TurnLeft()
    zm = zm * (ps ? 1. : 2.)
    clean = crop(0,0,0,-256)
    grid  =            clean.ex_lutspa(mode="mix",expr=Format("sx {xo} neg 256 * + round X@ 256 {zm} 2 * / round % 0 ==
                                                               sy {yo} neg 256 * + round Y@ 256 {zm} 2 * / round % 0 == or
                                                               X 4 % 0 != Y 0 != Y 4 % 0 != and or 0.25 0 ? x 0.5 < 0 x ? B@ max B ?"), UV=128)
    axis  = ps ? grid : grid.ex_lutspa(mode="mix",expr=Format("sx 128 {xo} 256 * + round abs ==
                                                       sy 0 != sy 128 {yo} 256 * + round abs == and or 0.35 x max sy 255 == 0 x ? ?"),  UV=128)
    grad = crop(0,256,0,0)
    gr ? StackHorizontal(grad,axis) : axis

    RatioResize(sz,"%",kernel="Point")
    ConvertBits(8,dither=1,fulls=true) }