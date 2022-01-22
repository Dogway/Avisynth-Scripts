# SPresso() by Didée (2005.11.28)
# https://forum.doom9.org/showthread.php?p=867316#post867316
#
#                Didée      in 2006.09.04 for "Corrected a BIG bug"
#                r.f    mod in 2020.05.07 for HBD
#                Dogway mod in 2021.07.16 Optimization + Cleanup
#                Dogway mod in 2021.12.11 Use old minblur() code path, update for HD and optimize with 'sgn' -faster and bugfix(?)-
#                Dogway mod in 2022.01.22 Decoupled limiter from SPresso and Defaults for RGB inputs
#
# SPresso (Spatial Pressdown) is a purely spatial script designed to achieve better compressibility without doing too much harm to the original detail.
# SPresso was not designed for 1080p processing/encoding; due to its 3x3 kernel it works better on standard definition (SD) content like DVDs and possibly on 720p.
# On noisy DVD/SD sources, compression gain usually is from 2% to 3% (light settings -> changes almost invisible) up to 10 to 12% (stronger settings -> slight, gentle softening, not very obvious).
#
# Dependencies:
#     ExTools
#     RgTools
#     SMDegrain (for HD inputs)
#
#
# Function Definition:
#    (
#    clip,
#    float limit=2.0 (0.0 to 100.0 by 0.5),
#    float bias=25.0 (0.0 to 200.0 by 0.5),
#    int RGmode=4 (1 to 27 by 1),
#    float limitC=4.0 (0.0 to 100.0 by 0.5),
#    float biasC=50.0 (0.0 to 200.0 by 0.5),
#    int RGmodeC=-1 (-1 to 27 by 1),
#    [int radius=4 (1 to 9 by 1)],
#    )
#
function SPresso(clip clp, float "limit", float "bias", int "RGmode", float "limitC", float "biasC", int "RGmodeC", int "radius") {

    rgb = clp.isRGB()
    w   = clp.width()
    h   = clp.height()

    limit   = Default( limit,   2 )
    limitC  = Default( limitC,  rgb?limit:limit*2 )
    bias    = Default( bias,   25 )
    biasC   = Default( biasC,   rgb?bias : bias*2 )
    RGmode  = Default( RGmode,  4 )
    RGmodeC = Default( RGmodeC,rgb?RGmode:-1 )
    radius  = Default( radius,  round(h/540.0) )

    Assert(IsVersionOrGreater(3,7,1), "SPresso: Update AviSynth+ version")

    yy    =           (RGmode  < 1) ? 2 : 3
    uv    = rgb ? 3 : (RGmodeC < 1) ? 2 : 3

    isHD   = (w  > 1099 ||  h  > 599) && radius > 1
    RGmode = isHD ? yy == 3 ? RGmode : RGmodeC : RGmode
    bmode  = (10 < RGmode  < 13) || (18 < RGmode  < 21)
    # For HD, RGmode and RGmodeC can't be >0 and distinct (falls back to RGmode when both luma and chroma are processed)
    RGmode = RGmode == 1  ? isHD ? "unblob3" : 1  : \
             RGmode == 2  ? isHD ? "unblob3" : 2  : \
             RGmode == 3  ? isHD ? "unblob3" : 3  : \
             RGmode == 4  ? isHD ? "median5" : 4  : \
             RGmode == 5  ? isHD ? "DGM5"    : 5  : \
             RGmode == 6  ? isHD ? "DGM4"    : 6  : \
             RGmode == 7  ? isHD ? "DGM3"    : 7  : \
             RGmode == 8  ? isHD ? "DGM1"    : 8  : \
             RGmode == 9  ? isHD ? "DGM0"    : 9  : \
             RGmode == 11 ? isHD ? "weighted": 11 : \
             RGmode == 12 ? isHD ? "weighted": 12 : \
             RGmode == 19 ? isHD ? "rg19"    : 19 : \
             RGmode == 20 ? isHD ? "mean"    : 20 : \
             RGmode == 17 ? isHD ? "smart2"  : 17 : \
             RGmode == 18 ? isHD ? "smart2"  : 18 : \
             RGmode == 22 ? isHD ? "smart2"  : 22 : \
             RGmode == 26 ? isHD ? "smart2"  : 26 : \
             RGmode == 27 ? isHD ? "smart2"  : 27 : isHD ? "median5" : RGmode

    b = isHD ? bmode ? clp.ex_boxblur(radius, mode=RGmode,y=yy,uv=uv)                                                                 : \
                       clp.ex_MinBlur(radius,old=true,mode=Format("""ex_median(" """+RGmode+""" ",thres=th,Y=y,UV=uv)"""),y=yy,uv=uv) : \
                       clp.removegrain(RGmode,RGmodeC)

    ex_limitchange( clp, b, limit, bias, limitC, biasC, yy, uv) }


# SPresso limiter as a standalone function
function ex_limitchange(clip a, clip b, float "limit", float "bias", float "limitC", float "biasC", int "Y", int "UV") {

    rgb = a.isRGB()
    w   = a.width()
    h   = a.height()
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    limit   = Default( limit,   2 )
    limitC  = Default( limitC,  rgb?limit:limit*2 )
    bias    = Default( bias,   25 )
    biasC   = Default( biasC,   rgb?bias : bias*2 )
    Y       = Default( Y,       3 )
    UV      = Default( UV,      rgb?3:2 )

    Assert(IsVersionOrGreater(3,7,1), "ex_limitchange: Update AviSynth+ version")

    LIM1  = ex_bs(limit >0 ? round(limit *(100.0/bias) -1.0) : round(100.0/bias),  8, bi, fulls=fs)
    LIM1c = ex_bs(limitC>0 ? round(limitC*(100.0/biasC)-1.0) : round(100.0/biasC), 8, bi, fulls=fs)
    LIM2  = ex_bs(limit <0 ? 1 : limit,  8, bi, fulls=fs)
    LIM2c = ex_bs(limitC<0 ? 1 : limitC, 8, bi, fulls=fs)
    BIA   = ex_bs(bias,                  8, bi, fulls=fs)
    BIAc  = ex_bs(biasc,                 8, bi, fulls=fs)
    CTH   = ex_bs(100,                   8, bi, fulls=fs)
    un    = ex_bs(1,                     8, bi, fulls=fs)

    expr  = Format(limit<0 ? "x y - A@ abs {LIM1} < x dup A sgn {un} * - ?"                                                          : \
                             "x y - abs 0 <= x dup {LIM1}  + y < x {LIM2}  + x {LIM1}  - y > x {LIM2}  - x {CTH} {BIA}  - * y {BIA}  * + 1 {CTH} / * ? ? ?" )

    exprC = Format(limit<0 ? "x y - A@ abs {LIM1c} < x dup A sgn {un} * - ?"                                                         : \
                             "x y - abs 0 <= x dup {LIM1c} + y < x {LIM2c} + x {LIM1c} - y > x {LIM2c} - x {CTH} {BIAc} - * y {BIAc} * + 1 {CTH} / * ? ? ?" )


    ex_lutxy( a, b, expr, exprC, Y=y, UV=uv, fulls=fs) }

# TODO: Do ex_limitdif() (port of Dither Tools Dither_limit_dif16 and vs LimitFilter)