##################################################
###                                            ###
###                  FilmGrain+                ###
###                                            ###
###            04.04.2023    by Dogway         ###
###                                            ###
##################################################
###
### Luma+Detail adaptive artificial film grain filter. Y/YUV only.
###
### +-------------+
### |  CHANGELOG  |
### +-------------+
###
### v1.0 - 2023.04.04
###      - Initial Release. Remake from the ground up of FilmGrain, and in turn of GrainFactory3modEX
###
###
### Dependencies: > ExTools
###                 ResizersPack
###                 AddGrainC
###                 vsTCanny
###                 RgTools
###
### Examples:
###
###     FilmGrainPlus(str=1.4,size=1.5)                        # Good example for digital 1080p films, ideally at 16-bit
###     FilmGrainPlus(str=2.5,size=2.0,sharpness=0.3,temp=0.1) # Example for UHD, not only size, but also strength should be raised
###
###
### Function Definition:
###    (
###    clip,
###    float str=1.0 (0.0 to 4.0),
###    float "size"=1.0 (0.0 to 2.0),
###    float "sharpness"=0.9 (0.0 to 1.0),
###    float "strc"=0.10 (0.00 to 0.50),
###    float "lo"=1.0 (0.0 to 2.0),
###    float "mid"=1.0 (0.0 to 2.0),
###    float "hi"=1.0 (0.0 to 2.0),
###    string "preset"="" ("--"/ "8mm"/ "16mm"/ "35mm"/ "5217"/ "5218"/ "5246"/ "FilmGrain"),
###    float "temp"=0.0 (0.0 to 1.0),
###    bool "conv"=false
###    )
###
###
function FilmGrainPlus(clip a, float "str", float "size", float "sharpness", float "strc", float "lo", float "mid", float "hi", string "preset", float "temp", bool "conv", bool "tv_range") {
    /*
    Kodak 5217                Kodak 5218
    str  = 0.5                str  = 0.2
    sz   = 0.4                sz   = 0.3
    shrp = 0.8                shrp = 1.0
    temp = 0.0                temp = 0.0

    Kodak 5246                8mm 1080p
    str  = 1.7                str  = 4.0
    sz   = 0.5                sz   = 2.0
    shrp = 0.8                shrp = 0.4
    temp = 0.1                temp = 0.0

    16mm 1080p                35mm 1080p
    str  = 4.0                str  = 1.0
    sz   = 1.3                sz   = 1.0
    shrp = 0.5                shrp = 0.9
    temp = 0.0                temp = 0.0

    35mm 1080p Dogway
    str  = 1.4
    sz   = 1.5
    shrp = 0.9
    temp = 0.1

    */
    w    = width (a)
    h    = height(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : false
    isUHD= w > 2599 || h > 1499

    str  = Default( str,       1.0 ) # 0.0 - 4.0
    sz   = Default( size,   w/1920.) # 0.0 - 2.0
    shrp = Default( sharpness, 0.9 ) # 0.0 - 1.0
    strc = Default( strc,    str/8.) # 0.0 - 0.5
    temp = Default( temp,      0.0 ) # 0.0 - 1.0, increase for temporal coherence
    conv = Default( conv,    false ) # Turn to true to "break" edges
    tv   = Default( tv_range,   !fs)

    pr   = Default( preset,     "" ) # 8mm / 16mm / 35mm / 5217 / 5218 / 5246 / FilmGrain
    lo   = Default( lo,        1.0 ) # 0.0 - 2.0, non linear strength multiplier for dark  areas
    mi   = Default( mid,       1.0 ) # 0.0 - 2.0, non linear strength multiplier for grey  areas
    hi   = Default( hi,        1.0 ) # 0.0 - 2.0, non linear strength multiplier for light areas

    Chr  = strc > 0.0
    Chr3 = Chr ? 3 : 2
    crs  = ((1- shrp)*3)+1
    shrp =   2-(shrp *2)
    sz   = max(1.1,4-sz*1.5)

    pbl  = a.ex_boxblur(isUHD?0.3:0.15,mode="weighted",UV=1)
    blk  = BlankClip(a, width=nmod(w*sz), height=nmod(h*sz), color_yuv=$808080, channels=0)

    gl1  = blk.AddGrainC(str*50*sz, strc*50*sz, constant=false, seed=17)
    gl1  = crs!=1.0 ? gl1.vsTCanny(sqrt(crs)/2.*sqrt(2),mode=-1,u=Chr3,v=Chr3)     : gl1.removegrain(12,Chr?12:0)

    temp > 0.0 ? Chr ? merge    (gl1, gl1.TemporalSoften(1,255,255,255,2), temp/2) : \
                       mergeluma(gl1, gl1.TemporalSoften(1,255,  0,255,2), temp/2) : gl1

    BicubicResize(w,h,b=shrp,c=(1.0-shrp)/2.)

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

    th21str = MX / (th1str - th2str)
    th21str = MX / (th1str - th2str)
    th43str = MX / (th3str - th4str)
    norm    = 1  / (chi    -    clo)

    op  = str/4.
    SEG = lo!=1.0   ||  mi!=1.0   ||  hi!=1.0
          lo = lo * op  mi = mi * op  hi = hi * op

    LL  = "x "+srcmx+" A@ range_half "+srcmx+" < A 2 y "+srcmx+" B@ * + "+rngmx+" - A 2 B range_half "+srcmx+" - * + ? 0 "+rngmx+" clip "

    LMH = Format(" Y@ x dup swap2 - x {th1str} - {th21str} * LO@ {lo} range_max / *     0 1 clip * -
                        dup     Y - x {th3str} - {th43str} * HI@ {hi} range_max / * neg 0 1 clip * -
                        dup     Y - range_max HI neg LO max -    {mi} range_max / *     0 1 clip * -")

    EM  = Format(" x[1,1] C@ x[1,-1] H@ + x[-1,1] A@ - x[-1,-1] F@ - x[1,0] x[-1,0] - 1.414213562 * + dup *
                   F H + C - A - x[0,-1] x[0,1] - 1.414213562 * + dup * + sqrt {clo} - {norm} * 0 1 clip {op} 0.6 * * * - ")

    !SEG && !conv ? ex_blend(pbl,last,mode="linear light",opacity=op,UV=Chr3,tv_range=tv) : \
                    ex_lutxy(pbl,last,conv ? SEG ? LL+tvout+LMH+" dup Y - "+EM : LL+Format(" dup A - {op} * A + dup swap2 - ")+EM+tvout : LL+tvout+LMH, UV=Chr3)
    }
