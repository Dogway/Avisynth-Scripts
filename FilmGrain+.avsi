#######################################################
###                                                 ###
###                                                 ###
###      FilmGrain+  v1.2  (06-04-2023)             ###
###                                                 ###
###                   by Dogway (Jose Linares)      ###
###                                                 ###
###                                                 ###
### https://forum.doom9.org/showthread.php?t=182881 ###
###                                                 ###
###                                                 ###
#######################################################
###
### Luma+Detail adaptive synthetic film grain filter. Y/YUV only.
###
### +-------------+
### |  CHANGELOG  |
### +-------------+
###
### v1.2 - 2023.04.06
###      - Fix 'lo', 'mid', 'hi' masks
###      - Make chroma grain behave along luma grain
###      - Move temp line after downscale for performance
###      - Fix brightening in "linear light" mode. Might remove the mode later on
###      - Add 'show' option to show the grain plate
###
### v1.1 - 2023.04.05
###      - Add presets system
###      - Autoscale params to resolution for presets system
###      - Implement additional "grainmerge" blend mode
###      - Add Path to White for Chroma Grain
###      - Replace ex_boxblur() with more performant vsTCanny()
###
### v1.0 - 2023.04.04
###      - Initial Release. Remake from the ground up of FilmGrain, and in turn of GrainFactory3modEX
###
###
### Dependencies: > ExTools
###                 ResizersPack
###                 GradePack
###                 AddGrainC
###                 vsTCanny
###                 RgTools
###
### Examples:
###
###     FilmGrainPlus(str=1.4,size=1.5)                        # Good example for digital 1080p films, ideally at 16-bit
###     FilmGrainPlus(str=2.5,size=2.0,sharpness=0.3,temp=0.1) # Example for UHD, not only size, but also strength should be raised
###
###     * Note: To speed up the filter for UHD, you can set strc=0 and temp=0.0
###
### Function Definition:
###    (
###    clip,
###    float str=1.0 (0.0 to 4.0),
###    float "size"=1.0 (0.0 to 2.0),
###    float "sharpness"=0.9 (0.0 to 1.0),
###    float "lo"=1.0 (0.0 to 2.0),
###    float "mid"=1.0 (0.0 to 2.0),
###    float "hi"=1.0 (0.0 to 2.0),
###    string "preset"="" ("--"/ "FilmGrain"/ "8mm"/ "16mm"/ "35mm"/ "5201"/ "5213"/ "5217"/ "5218"/ "5219"/ "5245"/ "5246"/ "5248"/ "5279"/ "FX214"/ "GT5274"/ "DigitalNoise"),
###    string "mode"="grain merge" ("grain merge"/ "linear light"),
###    float "temp"=0.0 (0.0 to 1.0),
###    bool "conv"=false,
###    bool "PTH"=false,
###    float "strc"=0.10 (0.00 to 0.50),
###    bool "show"=false
###    )
###
###
function FilmGrainPlus(clip a, float "str", float "size", float "sharpness", float "lo", float "mid", float "hi", string "preset", string "mode", float "temp", bool "conv", bool "PTH", float "strc", bool "tv_range", bool "show") {

    w     = width (a)
    h     = height(a)
    isy   = isy(a)
    bi    = BitsPerComponent(a)
    fs    = propNumElements (a,"_ColorRange")  > 0 ? \
            propGetInt      (a,"_ColorRange") == 0 : false
    isUHD = w > 2599 || h > 1499

    preset= Default( preset,   "" )
    pr    = preset == ""             ?  0 : \
            preset == "--"           ?  0 : \
            preset == "FilmGrain"    ?  1 : \
            preset == "8mm"          ?  2 : \
            preset == "16mm"         ?  3 : \
            preset == "35mm"         ?  4 : \
            preset == "5201"         ?  5 : \
            preset == "5213"         ?  6 : \
            preset == "5217"         ?  7 : \
            preset == "5218"         ?  8 : \
            preset == "5219"         ?  9 : \
            preset == "5245"         ? 10 : \
            preset == "5246"         ? 11 : \
            preset == "5248"         ? 12 : \
            preset == "5279"         ? 13 : \
            preset == "FX214"        ? 14 : \
            preset == "GT5274"       ? 15 : \
            preset == "GrainFactory3"? 16 : \
            preset == "DigitalNoise" ? 17 : \
            Assert( false, "FilmGrain+: 'Preset' choice is invalid" )

    strD  = Defined( str       )
    strcD = Defined( strc      )
    szD   = Defined( size      )
    shrpD = Defined( sharpness )

    # Presets at 1080p:                       Default FilmGrain 8mm    16mm   35mm  5201   5213   5217   5218   5219   5245   5246   5248   5279  FX214  GT5274    GF3   DigitalNoise
    str   = Default( str      , Select ( pr,     1.0 ,   1.4,   4.0,   4.0,   1.0,   1.0,   1.0,   1.2,   0.8,   1.0,   1.0,   1.5,   1.0,   1.0,   1.0,    1.0,   2.3,  1.0))
    sz    = Default( size     , Select ( pr,  w/1920.,   1.5,   2.0,   1.3,   1.0,   1.0,   1.0,   0.4,   0.3,   1.0,   1.0,   0.5,   1.0,   1.0,   1.0,    1.0,   1.0,  1.0))
    shrp  = Default( sharpness, Select ( pr,     0.9 ,   0.9,   0.4,   0.5,   0.9,   1.0,   1.0,   0.8,   1.0,   1.0,   1.0,   0.8,   1.0,   1.0,   1.0,    1.0,   0.5,  1.0))
    temp  = Default( temp     , Select ( pr,     0.0 ,   0.1,   0.2,   0.1,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.1,   0.0,   0.0,   0.0,    0.0,   0.1,  0.0))
    strc  = Default( strc,       str/8.) # 0.0 - 0.5
    md    = Default( mode, "grainmerge") # Blend mode. "Grain Merge" preserves tones better and might be faster
    conv  = Default( conv,       false ) # Turn to true to "break" edges
    pth   = Default( PTH,        true  ) # Path to White for chroma grain. Disable if you run out of performance
    sh    = Default( show,       false ) # Show grain plate
    tv    = Default( tv_range,      !fs)
    md    = ReplaceStr( md, " ","")
    mdll  = md=="linearlight"

    lo    = Default( lo,           1.0 ) # 0.0 - 2.0, non linear strength multiplier for dark  areas
    mi    = Default( mid,          1.0 ) # 0.0 - 2.0, non linear strength multiplier for grey  areas
    hi    = Default( hi,           1.0 ) # 0.0 - 2.0, non linear strength multiplier for light areas

    # Presets params auto-scale for sources other than 1080p (you can override them)
    mul   =  mdll ? 1 : 1.6
    str   = (pr != 0 && !strD  ?       str  * (  0.409*w*0.001 + 0.214 )      : str)  * mul
    strc  = (pr != 0 && !strcD ?       strc * (  0.409*w*0.001 + 0.214 )      : strc) * mul
    sz    =  pr != 0 && !szD   ?       sz   * (  0.173*w*0.001 + 0.667 )      : sz
    shrp  =  pr != 0 && !shrpD ? clamp(shrp * ( -0.347*w*0.001 + 1.667 ),0,1) : shrp

    Assert(IsVersionOrGreater(3,7,3), "FilmGrain+: Update AviSynth+ version")

    Chr   = strc > 0.0 && !isy
    Chr3  = Chr ? 3 : 2
    crs   = ((1- shrp)*3)+1
    shrp  =   2-(shrp *2)
    sz    = max(1.1,4-sz*1.5)

    pbl   = a.vsTCanny(isUHD?0.5:0.44,mode=-1,u=2,v=2)
    blk   = BlankClip(a, width=nmod(w*sz), height=nmod(h*sz), color_yuv=$808080, channels=0)

    gl1   = blk.AddGrainC(str*50*sz, strc*50*sz, constant=false, seed=17)
    # Anti-moiree + 'sharpness' support blur
    crs>1.0 ? gl1.vsTCanny(sqrt(crs)/2.*sqrt(2),mode=-1,u=2,v=2)                : gl1.removegrain(12,0)

    BicubicResize(w,h,b=shrp,c=(1.0-shrp)/2.)

    temp > 0.0 ? Chr ? merge    (last, TemporalSoften(1,255,255,255,2), temp/2) : \
                       mergeluma(last, TemporalSoften(1,255,  0,255,2), temp/2) : last

    if (sh) { last }
    else {
    rngmx = tv   ? "ymax ymin -" : "range_max"
    srcmx = tv   ? "ymin -"      : ""
    tvout = tv   ? "ymin +"      : ""

    # 'frei-chen' with 9 and 40 for lo and hi respectively
    clo    = ex_bs(  9, 8, bi, fulls=true, flt=true)
    chi    = ex_bs( 40, 8, bi, fulls=true, flt=true)
    th1str = ex_bs( 45, 8, bi, tv_in=true, tv_out=tv)
    th2str = ex_bs( 85, 8, bi, tv_in=true, tv_out=tv)
    th3str = ex_bs(135, 8, bi, tv_in=true, tv_out=tv)
    th4str = ex_bs(195, 8, bi, tv_in=true, tv_out=tv)
    MX     = ex_bs(255, 8, bi, fulls=true, flt=true)

    th21str = MX / (th2str - th1str)
    th43str = MX / (th3str - th4str)
    norm    = 1  / (chi    -    clo)

    op  = str/4.
    SEG = lo!=1.0 || mi!=1.0 || hi!=1.0

    lo  = (lo * op) / MX
    mi  = (mi * op) / MX
    hi  = (hi * op) / MX

    LL  = "x "+srcmx+" A@ range_half "+srcmx+" < A 2 y "+(mdll ? "ymin 0.1 * - " : "")+srcmx+" B@ * + "+rngmx+" - A 2 B range_half "+srcmx+" - * + ? 0 "+rngmx+" clip "
    GM  = "x "+srcmx+" A@  y "+srcmx+" + range_half "+srcmx+" - 0 "+rngmx+" clip "
    mde = mdll ? LL : GM

    LMH = Format(" Y@ x dup swap2 - range_max x  {th1str} - {th21str} * -   LO@ {lo} * 0 1 clip * -
                        dup     Y -           x  {th3str} - {th43str} * neg HI@ {hi} * 0 1 clip * -
                        dup     Y - range_max  HI LO max  -                     {mi} * 0 1 clip * -")

    EM  = Format(" x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 1.414213562 * + dup *
                   F H + C - A - x[0,-1] x[0,1] - 1.414213562 * + dup * + sqrt {clo} - {norm} * 0 1 clip {op} 0.8 * * * - ")

    Ych = !isy  ? mskY_to_YYY(pbl,luma=true,bits=bi)             : nop()
    CHL =  PTH  ? Format(" dup x - HI range_max / 0 1 clip * -") : ""

    COM =  conv ?  SEG ? mde+tvout+LMH+" dup Y - "+EM : mde+Format(" dup A - {op} * A + dup swap2 - ")+EM+tvout : mde+tvout+LMH
    COC = ReplaceStr(COM, " x  ", " z ")

    Chr || conv || SEG ? ex_lutxyz(pbl,last,Ych,COM,COC+CHL,UV=Chr3)                             : \
                         ex_blend (pbl,last,mode=mdll?md:"grainmerge",opacity=op,UV=2,tv_range=tv)
    } }
