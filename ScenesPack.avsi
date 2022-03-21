######################################################
###                                                 ##
###                                                 ##
###   Scenes Pack 1.0 RC1 (21-03-2022)              ##
###                                                 ##
###                      by Dogway (Jose Linares)   ##
###                                                 ##
### https://forum.doom9.org/showthread.php?t=182881 ##
###                                                 ##
###                                                 ##
### Functions:                                      ##
###      SceneRange                                 ##
###      SceneStats                                 ##
###                                                 ##
###                                                 ##
######################################################


# SceneRange() by Dogway (20-03-2022)
# Writes current scene frame numbers (start and end) into frame properties
#
# Dependencies: ResizersPack
#
function SceneRange(clip a, float "dfactor", float "MinDif", int "lookahead", clip "dClip") {

    rgb = isRGB(a)
    FC  = FrameCount(a)
    FR  = FrameRate (a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    dfactor = Float(Default(dfactor,3.5))  # Range 2.5~4.0 ::: Change default to 4.0 to emulate ScSelect
    Mindif  = Float(Default(MinDif ,1.0))  # Range 0.5~4.0 ::: Change default to 0.0 to emulate ScSelect
    la      = Default(lookahead,      60)  # Max Scene Change lookahead in seconds
    ddClp   = Defined(dClip)

    Assert(IsVersionOrGreater(3,7,2), "SceneRange: Update AviSynth+ version")
    Assert(!rgb,                      "SceneRange: DClip YUV Only")
    Assert(1.0 <= dFactor,            "SceneRange: 1.0 <= dFactor")
    Assert(0.0 <= Mindif ,            "SceneRange: 0.0 <= MinDif")

    # Prefiltering
    dClip = ddClp ? dClip : a
    dClip = dClip.ExtractY().ConvertBits(8, dither=-1, fulls=fs, fulld=true)
    dClip = width(dClip) > 1024 ? dClip.RatioResize(720.,"adjust2w",2,"bicubic",b=-0.5,c=0.3) : dClip

        ScriptClip(a, function [dClip,dfactor,MinDif,FC,FR,la] () {

            SA  = propNumElements("_SceneRange",offset=-1) > 0 ? propGetAsArray("_SceneRange",offset=-1) : [-1,-1]
            n   = current_frame

            if (n-1>SA[1]) {

                nDf0 = 0
                nTh  = 0
                last

                # 'la' secs MAX lookahead
                lookahead = min(round(FR*la), FC-n-1)

                for (f=1, lookahead, 1) {

                        dClip = dClip.SelectEvery(1,1)
                        pDf0  = dClip.YDifferenceFromPrevious()
                        nDf0  = dClip.YDifferenceToNext()

                nTh = pDf0*dfactor+MinDif

                SE  = n+f
                f   = nDf0>nTh ? lookahead : f # stopper
                }

                propSet("_SceneRange", [n,SE])
            }
    } )

    # Set Start (and fix End)
    ScriptClip( function[] () {
    SD  = propGetAsArray("_SceneRange",offset=-1)
    SD1 = SD[1]
    n   = current_frame
    LP  = last

    # lookback
    for (lb=n, 1, -1) {
        LP = LP.SelectEvery(1,-1)
        PR = propGetAsArray(LP,"_SceneRange")
        PE = PR[1]
        lb = PE != SD1 ? 1 : lb }

    SA  = propGetAsArray("_SceneRange",offset=-(n-PE)-1)
    propSet("_SceneRange", [(n+1 > SD1 ? PE : SA[1]) + 1, SD1])
    } ) }




# SceneStats() by Dogway (21-03-2022)
# Writes current scene pixel statistics into frame properties (min, max, thresholded min, thresholded max, average and median)
#
# Dependencies: ResizersPack and "_SceneRange" frameprops
#
# Example:
#     SceneRange()
#     SceneStats()
#
function SceneStats(clip a, float "interval", float "th", string "write", bool "Y", bool "UV", bool "show") {

    FR  = FrameRate(a)
    fs  = propNumElements(a,"_ColorRange")  > 0 ? \
          propGetInt     (a,"_ColorRange") == 0 : false

    in = Default(interval, 0.5)  # interval in seconds for fetching frames
    th = Default(th,       0.1)  # 1/1000 threshold (1‰ -one per-mille-)
    Y  = Default(Y,       true)  # Currently only Luma plane is supported
    UV = Default(UV,     false)
    wr = Default(write,     "")  # Set a file path to offload SceneStats' stats to a file
    sh = Default(show,   false)  # Currently noop

    in = round(FR * in)

    Assert(IsVersionOrGreater(3,7,2), "SceneStats: Update AviSynth+ version")

    a
    dClip = ExtractY().ConvertBits(8, dither=-1, fulls=fs, fulld=fs)
    dClip = dClip.RatioResize(0.5,"%",2,"bicubic",b=-0.5,c=0.3) # 4 times faster

    ScriptClip(function [dClip, Y, UV, in, th] () {

        SA  = propNumElements("_SceneRange") > 0 ? propGetAsArray("_SceneRange") : [-1,-1]

        if (current_frame==SA[0]) {

            a = last

            rng = SA[1] - SA[0]
            stp = in

            avg   = 0    div   = 0
            stats = [0.0,0.0,0.0,0.0,0.0]

            dClip
            for (i=0, rng, stp) {
                stats = ArrayOp(stats,PlaneMinMaxStats(last, th, i, 0, false),"+")
                avg   = avg + AverageLuma(i)
                div   = div + 1
            }
            # The mean of scene's: min, max, thresholded min, thresholded max, average and median
            propSet (a,"_SceneStats", [stats[0]/div,stats[1]/div,stats[2]/div,stats[3]/div,avg/div,stats[4]/div])
    } } )

    ScriptClip(function [a] () {
        SA  = propNumElements("_SceneRange")            > 0 ? propGetAsArray("_SceneRange")            : [-1,-1]
        off = -(current_frame-SA[0])
        SB  = propNumElements("_SceneStats",offset=off) > 0 ? propGetAsArray("_SceneStats",offset=off) : [-1,-1]
        off != 0 ? propSet (a,"_SceneStats",SB) : last
        } )

    wr != "" ? WriteFile(wr, function[] () {
    stats = ArrayPrint(propGetAsArray("_SceneStats"),true)
    string(current_frame) + ": " + stats } ) : last
}
