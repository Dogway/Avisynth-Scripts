#######################################################
###                                                 ###
###                                                 ###
###      FilmGrain+  v2.4  (18-04-2023)             ###
###                                                 ###
###                   by Dogway (Jose Linares)      ###
###                                                 ###
###                                                 ###
### https://forum.doom9.org/showthread.php?t=182881 ###
###                                                 ###
###                                                 ###
#######################################################
###
### Accurate and performant synthetic film grain filter. Y/YUV at any bitdepth.
###
### This is a grain restoration filter therefore film and lens aberrations like;
### vignette, veiling, lens blur, light wrap, bokeh, halation, dilation, dust & scratches, etc, aren't emulated.
###
### For convenience 'preblur' is included but if you need a superior preblur
### or any other effect, set 'preblur=0.0' and apply them prior to this filter.
###
###
### Dependencies: > ExTools
###                 ResizersPack
###                 GradePack
###                 AddGrainC
###                 vsTCanny
###                 GradePack      (for emulsion>0 or show=2)
###                 TransformsPack (for fast=false)
###
### Examples:
###
###     FilmGrainPlus(str=0.2,size=1.5)                        # Good example for digital 1080p films, ideally at 16-bit
###     FilmGrainPlus(str=0.8,size=2.0,sharpness=0.3,temp=0.1) # Example for UHD, not only size, but also strength should be raised
###
###     * Note: To speed up the filter for UHD, you can set strc=0, temp=0.0 and mode="gamma"
###
###
### Function Definition:
###    (
###    clip,
###    float str=1.0 (0.0 to 5.0),
###    float "size"=1.0 (0.0 to 2.0),
###    float "sharpness"=0.9 (0.0 to 1.0),
###    float "temp"=0.0 (0.0 to 1.0),
###    float "lo"=1.0 (0.0 to 2.0),
###    float "mid"=1.0 (0.0 to 2.0),
###    float "hi"=1.0 (0.0 to 2.0),
###    string "preset"="--" ("--"/ "8mm"/ "16mm"/ "35mm"/ "--"/ "EXR     5245  50D"/ "EXR     5248 100T"/ "EXR     5293 200T"/ "EXR     5298 500T"/ "Vision  5274 200T"/ "Vision  5246 250D"/ "Vision  5277 320T"/ "Vision  5279 500T"/ "Vision2 5201  50D"/ "Vision2 5212 100T"/ "Vision2 5217 200T"/ "Vision2 5218 500T"/ "Vision3 5203  50D"/ "Vision3 5213 200T"/ "Vision3 5207 250D"/ "Vision3 5219 500T"/ "FX       214 480D"/ "--"/ "Fuji    8510  64T"/ "Fuji    8520  64D"/ "Fuji    8530 125T"/ "Fuji    8550 250T"/ "Fuji    8560 250D"/ "Fuji    8570 500T"/ "Super F 8522  64D"/ "Super F 8532 125T"/ "Super F 8552 250T"/ "Super F 8562 250D"/ "Super F 8582 400T"/ "Super F 8572 500T"/ "EternaV 8543 160T"/ "Eterna  8563 250D"/ "Eterna  8583 400T"/ "Eterna  8573 500T"/ "Reala   8592 500D"/ "--"/ "FilmGrain"/ "GrainFactory3"/ "DigitalNoise"),
###    string "mode"="gamma" ("gamma"/ "linear"/ "log"),
###    float "bump"=0.0 (0.0 to 1.0),
###    float "emulsion"=0.0 (0.0 to 1.0),
###    float "skin"=1.0 (0.0 to 1.0),
###    float "preblur"=1.0 (0.0 to 2.0),
###    float "conv"=0.0 (0.0 to 1.0),
###    bool "s16mm"=false,
###    bool "PTH"=true,
###    bool "deterministic"=true,
###    bool "fast"=true,
###    float "strc"=0.1 (0.0 to 1.0),
###    int "show"=0 (0 to 2)
###    )
###
###
function FilmGrainPlus(clip a,                                                                    \
                       float  "str",    float  "size",     float "sharpness",    float "temp",    \
                       float  "lo",     float  "mid",      float "hi",                            \
                       string "preset", string "mode",                                            \
                       float  "bump",   float  "emulsion", float "skin",         float "preblur", \
                       bool   "s16mm",  bool   "PTH",      bool  "deterministic",bool  "fast",    \
                       val    "conv",   float  "strc",     bool   "tv_range",    int   "show") {

    w     = width (a)
    h     = height(a)
    isy   = isy(a)
    is44  = is444(a)
    bi    = BitsPerComponent(a)
    fs    = propNumElements (a,"_ColorRange")  > 0 ? \
            propGetInt      (a,"_ColorRange") == 0 : false
    isUHD = w > 2599 || h > 1499

    # The naming convention follows; Series, Film Stock number, ASA/ISO, White Point balance (Daylight -5500- / Tungsten -3200K-)
    # 'FX214' is a special Kodak film stock aimed at bluescreens for VFX composition, hence grain is low but at the cost of loss of sharpness
    # Many of the Kodak film stocks have 16mm counterparts, they are labelled in the 7000 series, so for example 7248 is the 16mm version of 5248
    # Sometimes 'clean' stocks like 5248 or 5219 are "pushed" one or more stops making the look more grainy and contrasty.
    preset= Default( preset,   "--" )
    pr    = preset == ""                                              ?  0 : \
            preset == "--"                                            ?  0 : \
            preset == "8mm"                                           ?  1 : \
            preset == "16mm"                                          ?  2 : \
            preset == "35mm"                                          ?  3 : \
            preset == "--"                                            ?  0 : \
            preset == "EXR     5245  50D" || FindStr(preset,"5245")>0 ?  4 : \
            preset == "EXR     5248 100T" || FindStr(preset,"5248")>0 ?  5 : \
            preset == "EXR     5293 200T" || FindStr(preset,"5293")>0 ?  6 : \
            preset == "EXR     5298 500T" || FindStr(preset,"5298")>0 ?  7 : \
            preset == "Vision  5274 200T" || FindStr(preset,"5274")>0 ?  8 : \
            preset == "Vision  5246 250D" || FindStr(preset,"5246")>0 ?  9 : \
            preset == "Vision  5277 320T" || FindStr(preset,"5277")>0 ? 10 : \
            preset == "Vision  5279 500T" || FindStr(preset,"5279")>0 ? 11 : \
            preset == "Vision2 5201  50D" || FindStr(preset,"5201")>0 ? 12 : \
            preset == "Vision2 5212 100T" || FindStr(preset,"5212")>0 ? 13 : \
            preset == "Vision2 5217 200T" || FindStr(preset,"5217")>0 ? 14 : \
            preset == "Vision2 5218 500T" || FindStr(preset,"5218")>0 ? 15 : \
            preset == "Vision3 5203  50D" || FindStr(preset,"5203")>0 ? 16 : \
            preset == "Vision3 5213 200T" || FindStr(preset,"5213")>0 ? 17 : \
            preset == "Vision3 5207 250D" || FindStr(preset,"5207")>0 ? 18 : \
            preset == "Vision3 5219 500T" || FindStr(preset,"5219")>0 ? 19 : \
            preset == "FX       214 480D" || FindStr(preset, "214")>0 ? 20 : \
            preset == "--"                                            ?  0 : \
            preset == "Fuji    8510  64T" || FindStr(preset,"8510")>0 ? 21 : \
            preset == "Fuji    8520  64D" || FindStr(preset,"8520")>0 ? 22 : \
            preset == "Fuji    8530 125T" || FindStr(preset,"8530")>0 ? 23 : \
            preset == "Fuji    8550 250T" || FindStr(preset,"8550")>0 ? 24 : \
            preset == "Fuji    8560 250D" || FindStr(preset,"8560")>0 ? 25 : \
            preset == "Fuji    8570 500T" || FindStr(preset,"8570")>0 ? 26 : \
            preset == "Super F 8522  64D" || FindStr(preset,"8522")>0 ? 27 : \
            preset == "Super F 8532 125T" || FindStr(preset,"8532")>0 ? 28 : \
            preset == "Super F 8552 250T" || FindStr(preset,"8552")>0 ? 29 : \
            preset == "Super F 8562 250D" || FindStr(preset,"8562")>0 ? 30 : \
            preset == "Super F 8582 400T" || FindStr(preset,"8582")>0 ? 31 : \
            preset == "Super F 8572 500T" || FindStr(preset,"8572")>0 ? 32 : \
            preset == "EternaV 8543 160T" || FindStr(preset,"8543")>0 ? 33 : \
            preset == "Eterna  8563 250D" || FindStr(preset,"8563")>0 ? 34 : \
            preset == "Eterna  8583 400T" || FindStr(preset,"8583")>0 ? 35 : \
            preset == "Eterna  8573 500T" || FindStr(preset,"8573")>0 ? 36 : \
            preset == "Reala   8592 500D" || FindStr(preset,"8592")>0 ? 37 : \
            preset == "--"                                            ?  0 : \
            preset == "FilmGrain"                                     ? 38 : \
            preset == "GrainFactory3"                                 ? 39 : \
            preset == "DigitalNoise"                                  ? 40 : \
            Assert( false, "FilmGrain+: 'Preset' choice is invalid" )

    strD  = Defined( str       )
    strcD = Defined( strc      )
    szD   = Defined( size      )
    shrpD = Defined( sharpness )

    # Presets at 1080p:                        Default                     8mm  16mm  35mm | 5245  5248  5293  5298 | 5274  5246  5277  5279 | 5201  5212  5217  5218 | 5203  5213  5207  5219 FX214 | 8510  8520  8530  8550  8560  8570 | 8522  8532  8552  8562  8582  8572 | 8543  8563  8583  8573  8592 | FilmGrain  GF3   DigitalNoise
    str   = Default( str      , Select ( pr,      0.2 ,                    7.0,  2.0,  0.8,   0.1,  1.0,  1.0,  1.0,   0.4,  0.9,  1.0,  1.4,   1.0,  1.0,  0.2,  0.1,   1.0,  1.0,  1.0,  0.1,  0.3,   1.0,  1.0,  1.0,  1.0,  1.0,  1.0,   1.0,  1.0,  1.0,  1.0,  1.0,  1.0,   1.0,  1.0,  1.0,  1.0,  1.0,     0.4,    1.0,   1.0))
    sz    = Default( size     , Select ( pr,   w/1920.,                    2.0,  1.7,  1.0,   0.8,  1.8,  1.0,  1.0,   0.4,  0.2,  1.0,  1.9,   1.0,  1.0,  1.4,  1.3,   1.0,  1.0,  1.0,  0.5,  0.8,   1.0,  1.0,  1.0,  1.0,  1.0,  1.0,   1.0,  1.0,  1.0,  1.0,  1.0,  1.0,   1.0,  1.0,  1.0,  1.0,  1.0,     1.5,    1.0,   1.0))
    shrp  = Default( sharpness, Select ( pr,szD?-0.87*sz+2:0.93-0.244*str, 0.6,  0.8,  0.8,   0.8,  0.9,  1.0,  1.0,   1.0,  1.0,  1.0,  1.0,   1.0,  1.0,  0.9,  1.0,   1.0,  1.0,  1.0,  1.0,  0.8,   1.0,  1.0,  1.0,  1.0,  1.0,  1.0,   1.0,  1.0,  1.0,  1.0,  1.0,  1.0,   1.0,  1.0,  1.0,  1.0,  1.0,     0.9,    0.5,   1.0))
    temp  = Default( temp     , Select ( pr,max((0.147*str-0.073),0)+0.06, 0.2,  0.1,  0.0,   0.0,  0.0,  0.0,  0.0,   0.0,  0.1,  0.0,  0.0,   0.0,  0.0,  0.0,  0.0,   0.0,  0.0,  0.0,  0.0,  0.0,   0.0,  0.0,  0.0,  0.0,  0.0,  0.0,   0.0,  0.0,  0.0,  0.0,  0.0,  0.0,   0.0,  0.0,  0.0,  0.0,  0.0,     0.1,    0.1,   0.0))
    strc  = Default( strc     , Select ( pr,   str*0.5,                    0.6,  0.1,  0.1,   0.0,  1.0, -1.0, -1.0,   0.0,  1.0, -1.0,  0.6,  -1.0, -1.0, -1.0, -1.0,  -1.0, -1.0, -1.0, -1.0,  0.3,  -1.0, -1.0, -1.0, -1.0, -1.0, -1.0,  -1.0, -1.0, -1.0, -1.0, -1.0, -1.0,  -1.0, -1.0, -1.0, -1.0, -1.0,    -1.0,   -1.0,  -1.0))
    conv  = Default( conv,       false ) # 0.0 - 1.0. Set to true or set strength for the convolution to "break" edges
    bmp   = Default( bump,        0.0  ) # 0.0 - 1.0. Raise to make the grain have a 3D volumetric effect
    skin  = Default( skin,        1.0  ) # 0.0 - 1.0. Lower to reduce the effect of grain on faces. Assumes source is YCbCr format in Rec709 space
    eml   = Default( emulsion,    0.0  ) # 0.0 - 1.0. Raise to mimic the emulsion artifacts common in old film stocks
    pbl   = Default( preblur,     1.0  ) # 0.0 - 2.0. Multiplier for internal blur. Lower or disable by setting it to 0.0 if coming from an upscale for example
    sxmm  = Default( s16mm,       false) # Enable to choose the 16mm version of the film stock in the Kodak 7000 series
    pth   = Default( PTH,          true) # Path to White for chroma grain. Disable if you run out of performance
    det   = Default( deterministic,true) # Set to false when rendering/encoding. This is to have a fixed preview of the look when modelling the grain
    fast  = Default( fast,         true) # Generally with 'true' an overlay is applied which is faster. With 'false' you do get some natural convolution from AddGrainC. Use it when high 'str' or 'size' to blend in grain better
    md    = Default( mode,      "gamma") # Add grain in "log", "linear" or "gamma" space
    sh    = Default( show,           0 ) # 1. Show grain matte centered at 126 if tv_range=true or 128 otherwise, 2. Show output with settings overlay
    tv    = Default( tv_range,      !fs)
    ls    = md=="log"
    ln    = md=="linear"
    bmp   = bmp+1
    skn   = 1-skin
    strc  = strc==-1.0 ? str*0.5 : strc
    ygrey = tv     ? 126 : 128
    rnghlf= ex_bs( ygrey,    8, bi, fulls=false, flt=true)
    MX    = ex_bs(   255,    8, bi, fulls=true,  flt=true)
    rmax  = bi==32 ? "" : bi > 12 ? "range_max /" : string(1./MX)+" *"

    lo    = Default( lo, ls ? 1.5 : ln ? 0.5 : 0.8) # 0.0 - 2.0, non linear strength multiplier for dark  areas
    mi    = Default( mid,ls ? 1.0 : ln ? 1.0 : 1.0) # 0.0 - 2.0, non linear strength multiplier for grey  areas
    hi    = Default( hi, ls ? 0.7 : ln ? 1.2 : 1.0) # 0.0 - 2.0, non linear strength multiplier for light areas

    # Presets params auto-scale for sources other than 1080p (you can override them)
    istr  = str    str  = (pr != 0 && !strD  ?       str  * (  0.409*w*0.001 + 0.214 )      : str ) * (sxmm ? 1.25 : 1) / (bmp>1.0 ? sqrt(bmp) : 1.0)
    istrc = strc   strc = (pr != 0 && !strcD ?       strc * (  0.409*w*0.001 + 0.214 )      : strc) * (sxmm ? 1.25 : 1) / (bmp>1.0 ? sqrt(bmp) : 1.0)
    ishrp = shrp   shrp = (pr != 0 && !shrpD ? clamp(shrp * ( -0.347*w*0.001 + 1.667 ),0,1) : shrp) * (sxmm ? 0.90 : 1)
    isz   = sz     sz   = (pr != 0 && !szD   ?       sz   * (  0.173*w*0.001 + 0.667 )      : sz  )
    sz    = sxmm ? 1.5*sz+0.5 : sz

    Assert(IsVersionOrGreater(3,7,3), "FilmGrain+: Update AviSynth+ version")

    Chr   = strc > 0.0 && !isy
    Chr32 = Chr ? 3 : 2
    crs   =   ((1-  shrp)     *3)+1
    shrpL =     2-( shrp      *2)
    shrpC = max(2-((shrp-0.3) *2),0)
    sz    = max(1.0,4-sz*1.5)
    binom = sqrt(crs)/2.*sqrt(2)

    if (!fast) {
        blk = a.  ConvertBits(8,dither=-1)
        blk = blk.ConvertFormat(sz,fmt_out="YCbCr444",cs_out="",EOTFi="",kernel="Bilinear",tv_in=tv,gpuid=-1)
    } else {
        blk = a.  BlankClip(width=nmod(w*sz),height=nmod(h*sz),pixel_type=isy||!Chr?Undefined():"YUV444P"+string(bi>16?"S":bi),color_yuv=Eval(ColortoHex(Format("[{ygrey},128,128]"))),channels=0)
    }

    blk.AddGrainC(str*100*sz, strc*100*sz, constant=false, seed=det?17:-1)
    !fast      ? ex_makediff(blk,last,UV=Chr32)                  : nop()
    # Anti-moiree + 'sharpness' support blur
    crs != 1.0 ? vsTCanny(binom,mode=-1,u=2,v=2)                 : removegrain(12,0)
    # Volumetric grain
    bmp  > 1.0 ? ex_lut(Format("x[-1,1] x - {bmp} * x +"), UV=2) : last

    if (Chr && !is44) {

        is22 = is422(a) ? 1 : 2
        Y    = ExtractY().BicubicResize(w,  h,     b=shrpL,c=(1.0-shrpL)/2.)
        Y    = temp > 0.0 ? Merge(Y,Y.TemporalSoften(1,255,0,255,2),temp/2 ) : Y
        U    = ExtractU().BicubicResize(w/2,h/is22,b=shrpL,c=(1.0-shrpL)/2.)
        V    = ExtractV().BicubicResize(w/2,h/is22,b=shrpC,c=(1.0-shrpC)/2.) # Red channel is typically blurrier
        eml>0 && sh==1 ? last : CombinePlanes(Y,U,V, planes="YUV", sample_clip=a)

    } else {
                          BicubicResize(w,  h,     b=shrpL,c=(1.0-shrpL)/2.)
        temp > 0.0 ? last.MergeLuma(  TemporalSoften(1,255,0,255,2),temp/2 ) : last
    }

        fast || sh==1  ? last : ConvertBits(bi)



    if (sh==1) {

        if (eml>0 && !isy) {

            HSS    = is422(a) || is44 ? 2 : 4
            WSS    = is44             ? 2 : 4
            Y      = VarExist("Y") ? Y : ExtractY()
            U      = VarExist("U") ? U : ExtractU()
            V      = VarExist("V") ? V : ExtractV()
            sample = PadResize(Y,w/16,h/16).TemporalSoften(1,255,0,255,2)
            UP     = BilinearResize(sample, w/WSS, h/HSS)

            stains = ex_blend(UP,UP.FlipHorizontal(),mode="subtract",tv_range=false).ex_inpand()
            UVer   = StackVertical  (stains,stains)
            UHor   = StackHorizontal(UVer,    UVer)
            Unew   = ex_lutxy(U,UHor,Format("x y {eml} * -"))
            CombinePlanes(Y,Unew,V, planes="YUV", sample_clip=a)
        }

    fast ? last : ConvertBits(bi)

    } else {


    expr   = binom*(pow(str,0.318)-0.61)*(pow(w/1920.-0.46,0.4)+0.2)*pbl
    pbl    = expr>0.35 ? a.vsTCanny(expr,mode=-1,u=Chr32,v=Chr32) : a


    # 'frei-chen' with 9 and 'conv' for lo and hi respectively
    cn     = isBool(conv) ? conv ? 1-str*0.1 : 1.0 : clamp(1-conv*0.8,0.2,1.0)
    cop    = -0.625*cn + 1.125
    clo    = ex_bs(     9, 8, bi, fulls=true, flt=true)
    chi    = ex_bs(cn*100, 8, bi, fulls=true, flt=true)
    norm   = 1. / (chi    -    clo)

    th1st  = ex_bs(   45,  8, bi, tv_in=true, tv_out=tv)
    th2st  = ex_bs(   85,  8, bi, tv_in=true, tv_out=tv)
    th3st  = ex_bs(  140,  8, bi, tv_in=true, tv_out=tv)
    th4st  = ex_bs(  200,  8, bi, tv_in=true, tv_out=tv)

    th21st = MX / (th2st - th1st)
    th43st = MX / (th3st - th4st)

    SEG    = lo!=1.0 || mi!=1.0 || hi!=1.0

    lop    = bi > 12 ? Format("{lo} * range_max /") : string(lo / MX)+" *"
    mip    = bi > 12 ? Format("{mi} * range_max /") : string(mi / MX)+" *"
    hip    = bi > 12 ? Format("{hi} * range_max /") : string(hi / MX)+" *"
    rh     = string(sqrt((0.501960785-(tv?0.062745098:0))*0.3))

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
    LMH = Format(" Y@ x dup swap2 - range_max x  {th1st} - {th21st} * -   LO@ "+lop+" 0 1 clip * -
                        dup     Y -           x  {th3st} - {th43st} * neg HI@ "+hip+" 0 1 clip * -
                        dup     Y - range_max  HI LO max  -                   "+mip+" 0 1 clip * -")

    # 'conv' with frei-chen gradient
    EM  = Format(" x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 1.414213562 * + dup *
                   F H + C - A - x[0,-1] x[0,1] - 1.414213562 * + dup * + sqrt {clo} - {norm} * 0 1 clip {cop} * * - ")

    # Construct expression
    COM = cn<1. ? SEG ? GM+tvout+LMH+" dup Y - "+EM : GM+Format(" dup swap2 - ")+EM+tvout : \
                  SEG ? GM+tvout+LMH                : GM+tvout

    # Expression fit for Chroma
    COC = ReplaceStr(COM," x  "," z ").ReplaceStr("x[", "z[").ReplaceStr(GM,GMC)
    PTW = PTH   ? " dup x - "+(SEG ? "HI" : Format("z {th3st} - {th43st} * neg"))+" "+rmax+" 0 1 clip * -" : ""
    GL  = last

    !Chr ? ex_lutxy (pbl,last,                                   COM,        UV=2) : \
           ex_lutxyz(pbl,last,mskY_to_YYY(pbl,luma=true,bits=bi),COM,COC+PTW,UV=3)


    if (skn>0 && !isy) {

        U   = ExtractU(a)
        V   = ExtractV(a)
        rh1 = bi==32 ? "range_half 0.430 - + " : rmax+" 0.430 -"
        rh2 = bi==32 ? "range_half 0.588 - + " : rmax+" 0.588 -"
        rhm = bi==32 ? "range_half         - " : ""
        msk = ex_lutxy(U,V,Format("x "+rh1+" 4 ^ -40000 * 1 + 0 max
                                   y "+rh2+" 4 ^ -40000 * 1 + 0 max * range_max {skn} * * "+rhm)).ex_inpand().ex_expand()
        ex_merge(pbl,msk,luma=true,UV=Chr32)
    }

    if (eml>0 && !isy) {

        is22   = is422(a) ? 1 : 2
        sample = padresize(GL.ExtractY(),w/16,h/16).TemporalSoften(1,255,0,255,2)
        UP     = BilinearResize(sample,  w/4, h/is22/2)
        Y      = ExtractY()
        U      = ExtractU()
        V      = ExtractV()

        stains = ex_blend(UP,UP.FlipHorizontal(),mode="subtract",tv_range=false).ex_inpand()
        UVer   = StackVertical  (stains,stains)
        UHor   = StackHorizontal(UVer,    UVer)
        Unew   = ex_lutxy(U,UHor,Format("x y {eml} * -"))
        CombinePlanes(Y,Unew,V, planes="YUV", sample_clip=last)
    }

    if (sh==2) {
        msize  = min(w,h)
        bg     = BoxMask(0,round(msize/(preset=="--"?2.6:1.8)),0,round(msize/1.3), invert=true, tv_out=tv)
        ex_blend(bg,"multiply",opacity=0.5,tv_range=tv)

        Subtitle(" FilmGrain+",                        size=msize/16,lsp=4,text_color=$ff5050,font="Segoe UI")
        Subtitle("\n\n SETTINGS:",                     size=msize/25,lsp=4,text_color=$ffcc99)
        Subtitle("\n\n\n\n "                           \
                       +"Preset:\n "                   \
                       +"Mode:\n\n "                   \
                       +"strength:\n "                 \
                       +"strengthC:\n "                \
                       +"size:\n "                     \
                       +"sharpness:\n "                \
                       +"temp:\n\n "                   \
                       +"bump:\n "                     \
                       +"emulsion:\n "                 \
                       +"skin:\n "                     \
                       +"conv:\n "                     \
                       +"PTH:\n ",                     size=msize/25,lsp=4,text_color=$ffcc99)
        Subtitle(Format("\n\n\n\n "                    \
                       +"'"+ReplaceStr(preset,"  "," ").ReplaceStr("  "," ").ReplaceStr(" 52",sxmm?" 72":" 52")+"'"+"\n "\
                       +"'"+md+"'"+"\n\n "             \
                       +string(istr, "%1.2f")+" \n "   \
                       +string(istrc,"%1.2f")+" \n "   \
                       +string(isz,  "%1.2f")+" \n "   \
                       +string(ishrp,"%1.2f")+" \n "   \
                       +string(temp, "%1.2f")+" \n\n " \
                       +string(bump, "%1.2f")+" \n "   \
                       +string(eml,  "%1.2f")+" \n "   \
                       +string(skin, "%1.2f")+" \n "   \
                       +string(isBool(conv) ? conv ? str*0.1 : 0 : (1-cn)*1.25,"%1.2f")+"\n "\
                       +"{pth} \n "),     x=msize/4.5, size=msize/25,lsp=4,text_color=$ffcc99)
    } } }
