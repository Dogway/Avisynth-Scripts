##
## DeStripeX()     by *.mp4 guy (14-06-2010)
##
## Port to ExTools by Dogway    (29-08-2021)
##
## Easy-to-use "low frequency" stripes/bands removal filter
## https://forum.doom9.org/showthread.php?p=1408276
##
## "thr is strength, rad is "how big are the (whatevers)" offset is "how far apart are they" rad goes from 1 to 4, offset from 1 to 4, thr from 1 to bignumber"
##
## Function Definition:
##    (
##    clip,
##    int "rad"=1 (1 to 4 by 1),
##    int "offset"=1 (1 to 4 by 1),
##    int "thr"=255 (1 to 255 by 1),
##    )
##

function DeStripeH(Clip C, int "rad", int "offset", int "thr", int "UV") {

    rgb  = isRGB(C)
    bi   = BitsPerComponent(C)
    fs   = propNumElements (C,"_ColorRange")  > 0 ? \
           propGetInt      (C,"_ColorRange") == 0 : rgb

    rad    = Default(rad,     2)
    offset = Default(offset,  0)
    UV     = Default(UV,    rgb ? 3 : 1)
    thr_   = Default(thr,   255)
    thr    = ex_bs(     thr_,  8, bi, fulls=fs, flt=true)
    sthr   = ex_bs(sqrt(thr_), 8, bi, fulls=fs, flt=true)


    Blurred = Rad == 1 ?               C.ex_boxblur(0,1,"mean",UV=uv)                                               : C
    Blurred = Rad == 2 ? offset == 0 ? C.ex_boxblur(0,2,"mean",UV=uv)                                               : \
                                       C.ex_luts(mode="avg",pixels="          0 -2     0 0     0 2        ", UV=uv) : Blurred
    Blurred = Rad == 3 ? offset == 0 ? C.ex_boxblur(0,3,"mean",UV=uv)                                               : \
                         offset == 1 ? C.ex_luts(mode="avg",pixels="     0 -3 0 -2     0 0     0 2 0 3    ", UV=uv) : \
                                       C.ex_luts(mode="avg",pixels="     0 -3          0 0         0 3    ", UV=uv) : Blurred
    Blurred = Rad == 4 ? offset == 0 ? C.ex_boxblur(0,4,"mean",UV=uv)                                               : \
                         offset == 1 ? C.ex_luts(mode="avg",pixels="0 -4 0 -3 0 -2     0 0     0 2 0 3 0 4", UV=uv) : \
                         offset == 2 ? C.ex_luts(mode="avg",pixels="0 -4 0 -3          0 0         0 3 0 4", UV=uv) : \
                                       C.ex_luts(mode="avg",pixels="0 -4               0 0             0 4", UV=uv) : Blurred

    Diff = ex_makediff(C, Blurred, UV=uv, fulls=fs)
    expr = Format(" x y - dup dup abs 1 + dup swap2 * swap {thr} 1 >= {sthr} {thr} ? + / - range_half +")

    MedianDiff = Rad == 1 ?               ex_luts(Diff, mode="med", pixels = ex_shape(1, mode="vertical"),             expr = expr, UV=uv, fulls=fs) : Diff
    MedianDiff = Rad == 2 ? offset == 0 ? ex_luts(Diff, mode="med", pixels = ex_shape(2, mode="vertical"),             expr = expr, UV=uv, fulls=fs) : \
                                          ex_luts(Diff, mode="med", pixels = "          0 -2     0 0     0 2        ", expr = expr, UV=uv, fulls=fs) : MedianDiff
    MedianDiff = Rad == 3 ? offset == 0 ? ex_luts(Diff, mode="med", pixels = ex_shape(3, mode="vertical"),             expr = expr, UV=uv, fulls=fs) : \
                            offset == 1 ? ex_luts(Diff, mode="med", pixels = "     0 -3 0 -2     0 0     0 2 0 3    ", expr = expr, UV=uv, fulls=fs) : \
                                          ex_luts(Diff, mode="med", pixels = "     0 -3          0 0         0 3    ", expr = expr, UV=uv, fulls=fs) : MedianDiff
    MedianDiff = Rad == 4 ? offset == 0 ? ex_luts(Diff, mode="med", pixels = ex_shape(4, mode="vertical"),             expr = expr, UV=uv, fulls=fs) : \
                            offset == 1 ? ex_luts(Diff, mode="med", pixels = "0 -4 0 -3 0 -2     0 0     0 2 0 3 0 4", expr = expr, UV=uv, fulls=fs) : \
                            offset == 2 ? ex_luts(Diff, mode="med", pixels = "0 -4 0 -3          0 0         0 3 0 4", expr = expr, UV=uv, fulls=fs) : \
                                          ex_luts(Diff, mode="med", pixels = "0 -4               0 0             0 4", expr = expr, UV=uv, fulls=fs) : MedianDiff

    ex_makeadddiff(Diff, MedianDiff, Blurred, UV=uv).propCopy(C) }



function DeStripeV(Clip C, int "rad", int "offset", int "thr", int "UV") {

    rgb  = isRGB(C)
    bi   = BitsPerComponent(C)
    fs   = propNumElements (C,"_ColorRange")  > 0 ? \
           propGetInt      (C,"_ColorRange") == 0 : rgb

    rad    = Default(rad,     2)
    offset = Default(offset,  0)
    UV     = Default(UV,    rgb ? 3 : 1)
    thr_   = Default(thr,   255)
    thr    = ex_bs(     thr_,  8, bi, fulls=fs, flt=true)
    sthr   = ex_bs(sqrt(thr_), 8, bi, fulls=fs, flt=true)


    Blurred = Rad == 1 ?               C.ex_boxblur(1,0,"mean",UV=uv)                                               : C
    Blurred = Rad == 2 ? offset == 0 ? C.ex_boxblur(2,0,"mean",UV=uv)                                               : \
                                       C.ex_luts(mode="avg",pixels="          -2 0     0 0     2 0        ", UV=uv) : Blurred
    Blurred = Rad == 3 ? offset == 0 ? C.ex_boxblur(3,0,"mean",UV=uv)                                               : \
                         offset == 1 ? C.ex_luts(mode="avg",pixels="     -3 0 -2 0     0 0     2 0 3 0    ", UV=uv) : \
                                       C.ex_luts(mode="avg",pixels="     -3 0          0 0         3 0    ", UV=uv) : Blurred
    Blurred = Rad == 4 ? offset == 0 ? C.ex_boxblur(4,0,"mean",UV=uv)                                               : \
                         offset == 1 ? C.ex_luts(mode="avg",pixels="-4 0 -3 0 -2 0     0 0     2 0 3 0 4 0", UV=uv) : \
                         offset == 2 ? C.ex_luts(mode="avg",pixels="-4 0 -3 0          0 0         3 0 4 0", UV=uv) : \
                                       C.ex_luts(mode="avg",pixels="-4 0               0 0             4 0", UV=uv) : Blurred

    Diff = ex_makediff(C, Blurred, UV=uv, fulls=fs)
    expr = Format(" x y - dup dup abs 1 + dup swap2 * swap {thr} 1 >= {sthr} {thr} ? + / - range_half +")

    MedianDiff = Rad == 1 ?               ex_luts(Diff, mode="med", pixels = ex_shape(1, mode="horizontal"),           expr = expr, UV=uv, fulls=fs) : Diff
    MedianDiff = Rad == 2 ? offset == 0 ? ex_luts(Diff, mode="med", pixels = ex_shape(2, mode="horizontal"),           expr = expr, UV=uv, fulls=fs) : \
                                          ex_luts(Diff, mode="med", pixels = "          -2 0     0 0     2 0        ", expr = expr, UV=uv, fulls=fs) : MedianDiff
    MedianDiff = Rad == 3 ? offset == 0 ? ex_luts(Diff, mode="med", pixels = ex_shape(3, mode="horizontal"),           expr = expr, UV=uv, fulls=fs) : \
                            offset == 1 ? ex_luts(Diff, mode="med", pixels = "     -3 0 -2 0     0 0     2 0 3 0    ", expr = expr, UV=uv, fulls=fs) : \
                                          ex_luts(Diff, mode="med", pixels = "     -3 0          0 0         3 0    ", expr = expr, UV=uv, fulls=fs) : MedianDiff
    MedianDiff = Rad == 4 ? offset == 0 ? ex_luts(Diff, mode="med", pixels = ex_shape(4, mode="horizontal"),           expr = expr, UV=uv, fulls=fs) : \
                            offset == 1 ? ex_luts(Diff, mode="med", pixels = "-4 0 -3 0 -2 0     0 0     2 0 3 0 4 0", expr = expr, UV=uv, fulls=fs) : \
                            offset == 2 ? ex_luts(Diff, mode="med", pixels = "-4 0 -3 0          0 0         3 0 4 0", expr = expr, UV=uv, fulls=fs) : \
                                          ex_luts(Diff, mode="med", pixels = "-4 0               0 0             4 0", expr = expr, UV=uv, fulls=fs) : MedianDiff

    ex_makeadddiff(Diff, MedianDiff, Blurred, UV=uv).propCopy(C) }
