#######################################################
###                                                 ###
###                                                 ###
###      FilmGrain+  v1.5  (11-04-2023)             ###
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
###     * Note: To speed up the filter for UHD, you can set strc=0, temp=0.0 and mode="gamma"
###
### Function Definition:
###    (
###    clip,
###    float str=1.0 (0.0 to 5.0),
###    float "size"=1.0 (0.0 to 2.0),
###    float "sharpness"=0.9 (0.0 to 1.0),
###    float "lo"=1.0 (0.0 to 2.0),
###    float "mid"=1.0 (0.0 to 2.0),
###    float "hi"=1.0 (0.0 to 2.0),
###    string "preset"="--" ("--"/ "FilmGrain"/ "8mm"/ "16mm"/ "35mm"/ "5201"/ "5213"/ "5217"/ "5218"/ "5219"/ "5245"/ "5246"/ "5248"/ "5279"/ "FX214"/ "GT5274"/ "GrainFactory3"/ "DigitalNoise"),
###    string "mode"="gamma" ("gamma"/ "linear"/ "log"),
###    float "temp"=0.0 (0.0 to 1.0),
###    int "conv"=0.0 (0.0 to 1.0),
###    bool "PTH"=true,
###    bool "preblur"=true,
###    float "strc"=0.1 (0.0 to 1.0),
###    int "show"=0 (0 to 3)
###    )
###
###
function FilmGrainPlus(clip a, float "str", float "size", float "sharpness", float "lo", float "mid", float "hi", string "preset", string "mode", float "temp", val "conv", bool "PTH", bool "preblur", float "strc", bool "tv_range", int "show") {

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

    # Presets at 1080p:                        Default   FilmGrain  8mm   16mm   35mm   5201   5213   5217   5218   5219   5245   5246   5248   5279  FX214  GT5274    GF3   DigitalNoise
    str   = Default( str      , Select ( pr,      1.3 ,      1.8,   5.0,   5.0,   1.3,   1.0,   1.0,   1.5,   1.0,   1.0,   1.0,   1.9,   1.0,   1.0,   1.0,    1.0,   2.9,  1.0))
    sz    = Default( size     , Select ( pr,   w/1920.,      1.5,   2.0,   1.3,   1.0,   1.0,   1.0,   0.4,   0.3,   1.0,   1.0,   0.5,   1.0,   1.0,   1.0,    1.0,   1.0,  1.0))
    shrp  = Default( sharpness, Select ( pr, (8-str)/7.5,    0.9,   0.4,   0.5,   0.9,   1.0,   1.0,   0.8,   1.0,   1.0,   1.0,   0.8,   1.0,   1.0,   1.0,    1.0,   0.5,  1.0))
    temp  = Default( temp     , Select ( pr, (str-1.25)*0.08,0.1,   0.2,   0.1,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.0,   0.1,   0.0,   0.0,   0.0,    0.0,   0.1,  0.0))
    strc  = Default( strc,      str*0.2) # 0.0 - 1.0
    conv  = Default( conv,       false ) # 0.0 - 1.0. Set to true or set strength for the convolution to "break" edges
    pth   = Default( PTH,        true  ) # Path to White for chroma grain. Disable if you run out of performance
    pbl   = Default( preblur,    true  ) # Turn to false if coming from an upscale for example
    md    = Default( mode,      "gamma") # Add grain in "log", "linear" or "gamma" space
    sh    = Default( show,           0 ) # 1. Show grain plate centered at 128, 2. Show grain plate centered at round(125.5), 3. Show output with settings overlay
    tv    = Default( tv_range,      !fs)
    ls    = md=="log"
    ln    = md=="linear"

    # "log" like weights by default in "gamma" mode
    lo    = Default( lo, ls ? 2.0 : ln ? 0.5 : 0.8) # 0.0 - 2.0, non linear strength multiplier for dark  areas
    mi    = Default( mid,ls ? 1.0 : ln ? 1.0 : 0.9) # 0.0 - 2.0, non linear strength multiplier for grey  areas
    hi    = Default( hi, ls ? 1.0 : ln ? 1.5 : 1.2) # 0.0 - 2.0, non linear strength multiplier for light areas

    # Presets params auto-scale for sources other than 1080p (you can override them)
    istr  = str    str  = pr != 0 && !strD  ?       str  * (  0.409*w*0.001 + 0.214 )      : str
    istrc = strc   strc = pr != 0 && !strcD ?       strc * (  0.409*w*0.001 + 0.214 )      : strc
    isz   = sz     sz   = pr != 0 && !szD   ?       sz   * (  0.173*w*0.001 + 0.667 )      : sz
    ishrp = shrp   shrp = pr != 0 && !shrpD ? clamp(shrp * ( -0.347*w*0.001 + 1.667 ),0,1) : shrp

    Assert(IsVersionOrGreater(3,7,3), "FilmGrain+: Update AviSynth+ version")

    Chr   = strc > 0.0 && !isy
    crs   =   ((1-  shrp)     *3)+1
    shrpL =     2-( shrp      *2)
    shrpC = max(2-((shrp+0.3) *2),0)
    sz    = max(1.1,4-sz*1.5)

    blk   = BlankClip(a,width=nmod(w*sz),height=nmod(h*sz),pixel_type=isy||!Chr?Undefined():"YUV444P"+string(bi>16?"S":bi),color_yuv=Eval(ColortoHex(tv?"[126,128,128]":"[128,128,128]")),channels=0)
    gl1   = blk.AddGrainC(str*100*sz, strc*100*sz, constant=false, seed=17)
    # Anti-moiree + 'sharpness' support blur
    crs>1.0 ? gl1.vsTCanny(sqrt(crs)/2.*sqrt(2),mode=-1,u=2,v=2) : gl1.removegrain(12,0)

    if (Chr && !is444(a)) {

        is22 = is422(a) ? 1 : 2
        Y    = ExtractY().BicubicResize(w,  h,     b=shrpL,c=(1.0-shrpL)/2.)
        Y    = temp > 0.0 ? Merge(Y,Y.TemporalSoften(1,255,0,255,2),temp/2 ) : Y
        U    = ExtractU().BicubicResize(w/2,h/is22,b=shrpC,c=(1.0-shrpC)/2.)
        V    = ExtractV().BicubicResize(w/2,h/is22,b=shrpC,c=(1.0-shrpC)/2.)
        CombinePlanes(Y,U,V, planes="YUV", sample_clip=a)

    } else {

        BicubicResize(w,h,b=shrpL,c=(1.0-shrpL)/2.)
        temp > 0.0 ? MergeLuma(last, TemporalSoften(1,255,0,255,2), temp/2) : last
    }

    if (0<sh<3) { last } else {

    pbl    = pbl ? a.vsTCanny(isUHD?0.5:0.44,mode=-1,u=2,v=2) : a

    # 'frei-chen' with 9 and 'conv' for lo and hi respectively
    cn     = isBool(conv) ? conv ? ls ? 0.9 : 0.4 : 1.0 : clamp(1-conv*0.8,0.2,1.0)
    cop    = -0.5*cn + 1.1
    clo    = ex_bs(  9, 8, bi, fulls=true, flt=true)
    chi    = ex_bs( cn, 8, bi, fulls=true, flt=true)
    norm   = 1. / (chi    -    clo)

    th1str = ex_bs( 45, 8, bi, tv_in=true, tv_out=tv)
    th2str = ex_bs( 85, 8, bi, tv_in=true, tv_out=tv)
    th3str = ex_bs(140, 8, bi, tv_in=true, tv_out=tv)
    th4str = ex_bs(200, 8, bi, tv_in=true, tv_out=tv)
    rnghlf = ex_bs(tv?126:128, 8, bi, fulls=false, flt=true)
    MX     = ex_bs(255, 8, bi, fulls=true, flt=true)

    th21str = MX / (th2str - th1str)
    th43str = MX / (th3str - th4str)

    op  = str/5.
    SEG = lo!=1.0 || mi!=1.0 || hi!=1.0

    lop = (lo * op) / MX
    mip = (mi * op) / MX
    hip = (hi * op) / MX
    rh  = string(sqrt((0.501960785-(tv?0.062745098:0))*0.3))

    rngmx  = tv ? "ymax ymin -"  : "range_max"
    srcmx  = tv ? "ymin - "      : ""
    tvout  = tv ? "ymin + "      : ""
    lgnor  = tv ? "2.57 * 1.105" : "2.791 * 1.045"
    linor  = tv ? "0.5023"       : string(0.501960785)

    # Merge 'mode'
    GML = "x "+srcmx+" A@ "+rngmx+" 3 * / sqrt y "+srcmx+rngmx+" 3 * / sqrt + "+rh+" - dup * "+lgnor+" ^ 0 1 clip "+rngmx+" * "
    GMI = "x "+srcmx+" A@ "+rngmx+" / 0 1 clip 2.4 ^ y "+srcmx+rngmx+" / + "+linor+" - 0 1 clip 0.416666667 ^     "+rngmx+" * "
    GMC = "x "+srcmx+" A@ y "+srcmx+" + range_half "+srcmx+" - 0 "+rngmx+" clip "
    GM  = ls ? GML : ln ? GMI : ReplaceStr(GMC,"range_half",Format("{rnghlf}"))

    # 'lo', 'mid' and 'hi' mix
    LMH = Format(" Y@ x dup swap2 - range_max x  {th1str} - {th21str} * -   LO@ {lop} * 0 1 clip * -
                        dup     Y -           x  {th3str} - {th43str} * neg HI@ {hip} * 0 1 clip * -
                        dup     Y - range_max  HI LO max  -                     {mip} * 0 1 clip * -")

    # 'conv' with frei-chen gradient
    EM  = Format(" x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 1.414213562 * + dup *
                   F H + C - A - x[0,-1] x[0,1] - 1.414213562 * + dup * + sqrt {clo} - {norm} * 0 1 clip {cop} * * - ")

    # Construct expression
    COM = cn<1. ? SEG ? GM+tvout+LMH+" dup Y - "+EM : GM+Format(" dup A - {op} * A + dup swap2 - ")+EM+tvout  : \
                  SEG ? GM+tvout+LMH                : GM+Format("     A - {op} * A + ")+tvout

    # Expression fit for Chroma
    COC = ReplaceStr(COM," x  "," z ").ReplaceStr("x[", "z[").ReplaceStr(GM,GMC)
    PTW = PTH ? " dup x - "+(SEG ? "HI" : Format("z {th3str} - {th43str} * neg"))+" range_max / 0 1 clip * -" : ""

    !Chr ? ex_lutxy (pbl,last,                                   COM,        UV=2) : \
           ex_lutxyz(pbl,last,mskY_to_YYY(pbl,luma=true,bits=bi),COM,COC+PTW,UV=3)

    if (sh==3) {
        msize  = min(w,h)
        bg     = BoxMask(0,round(msize/2.4),0,round(msize/1.8), invert=true, tv_out=tv)
        ex_blend(bg,"multiply",opacity=0.5,tv_range=tv)

        Subtitle(" FilmGrain+",                        size=msize/16,lsp=4,text_color=$ff5050,font="Segoe UI")
        Subtitle("\n\n SETTINGS:",                     size=msize/25,lsp=4,text_color=$ffcc99)
        Subtitle("\n\n\n\n "                         \
                       +"Preset:\n "                 \
                       +"Mode:\n "                   \
                       +"strength:\n "               \
                       +"strengthC:\n "              \
                       +"size:\n "                   \
                       +"sharpness:\n "              \
                       +"temp:\n "                   \
                       +"conv:\n "                   \
                       +"PTH:\n ",                     size=msize/25,lsp=4,text_color=$ffcc99)
        Subtitle(Format("\n\n\n\n "                  \
                       +"'"+preset+"'"+"\n "         \
                       +"'"+md+"'"+"\n "             \
                       +string(istr, "%1.2f")+" \n " \
                       +string(istrc,"%1.2f")+" \n " \
                       +string(isz,  "%1.2f")+" \n " \
                       +string(ishrp,"%1.2f")+" \n " \
                       +string(temp, "%1.2f")+" \n " \
                       +string(isBool(conv) ? conv ? 40 : 0 : (100-cn)*1.25,"%1.0f")+"\n "\
                       +"{pth} \n "),       x=msize/4, size=msize/25,lsp=4,text_color=$ffcc99)
    } } }
