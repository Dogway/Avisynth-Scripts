######################################################
###                                                 ##
###                                                 ##
###   Scenes Pack v1.0   (24-03-2022)               ##
###                                                 ##
###                      by Dogway (Jose Linares)   ##
###                                                 ##
### https://forum.doom9.org/showthread.php?t=182881 ##
###                                                 ##
###                                                 ##
###  Functions:                                     ##
###       SceneStats                                ##
###       ReadStats                                 ##
###                                                 ##
######################################################
###
###
### SceneStats() by Dogway (24-03-2022)
###
### Writes scene pixel statistics into frame properties (or offloads to a file), to choose from:
###    "_SceneRange": [SceneStart, SceneEnd]
###    "_SceneStats": [min, max, th_min, th_max, average, median]
###    "_SceneStatsStdErr": [min, max, th_min, th_max, average, median]
###    "_SceneMotion": float
###
###
###    dFactor,    Default 3.5. (1.0 <= dFactor) Detection factor, a multiplier applied to frame difference
###                    metrics to decide if a scene change.
###    Mindif,     Default 1.0. (0.0 <= Mindif, Supply MinDif as if in 8 bit range, 0.0 -> 255.0)
###                  An additional component part of scene change detection.
###
###
### Dependencies: ExTools
###               ResizersPack
###
### Function Definition:
###    (
###    clip,
###    string "mode"="ALL" ("ALL" / "Stats" / "Motion" / "Stats+StdErr"),
###    float "interval"=0.5 (0.1 to 2.0 by 0.1),
###    float "th"=0.1 (0.0 to 5.0 by 0.1),
###    float "dfactor"=3.5 (2.5 to 4.0 by 0.1),
###    float "MinDif"=1.0 (0.5 to 4.0 by 0.1),
###    int "lookahead"=60 (10 to 120 by 1),
###    [int "Y"=3 (1 to 3 by 1)],
###    [int "UV"=1 (1 to 3 by 1)],
###    [bool "show"=false],
###    )
###
function SceneStats(clip a, string "mode", float "interval", float "th", float "dfactor", float "MinDif", int "lookahead", clip "dClip", string "path", bool "Y", bool "UV", bool "show") {

    rgb = isRGB(a)
    FC  = FrameCount(a)
    FR  = FrameRate (a)
    fs  = propNumElements(a,"_ColorRange")  > 0 ? \
          propGetInt     (a,"_ColorRange") == 0 : rgb

    in      = Default(interval, 0.5)       # interval in seconds for fetching frames
    th      = Default(th,       0.1)       # 1/1000 threshold (1‰ -one per-mille-)
    dfactor = Float(Default(dfactor,3.5))  # Range 2.5~4.0 ::: Change default to 4.0 to emulate ScSelect
    Mindif  = Float(Default(MinDif ,1.0))  # Range 0.5~4.0 ::: Change default to 0.0 to emulate ScSelect
    md      = Default(mode, "Stats")       # Stats to write to frame properties: "ALL", "Stats", "Motion", "Stats+StdErr"
    la      = Default(lookahead, 60)       # Max Scene Change lookahead in seconds
    wr      = Default(path,      "")       # Set a file path to offload SceneStats' stats to a file. Doesn't pair well with multithreading, so wisely use RequestLinear() and Prefetch(1)
    Y       = Default(Y,       true)       # Currently only Luma plane is supported
    UV      = Default(UV,     false)       # Currently noop
    sh      = Default(show,   false)

    stp = round(FR * in)
    la  = round(FR * la)

    mo  = md == "ALL" || md == "Stats+Motion" || md == "Motion"
    st  = md == "ALL" || md == "Stats+Motion" || md == "Stats" || md == "Stats+StdErr"
    std = md == "ALL" || md == "Stats+StdErr"

    Assert(!rgb,          "SceneStats: DClip YUV Only")
    Assert(dFactor >= 1.0,"SceneStats: dFactor should be 1.0 or above")
    Assert(Mindif  >= 0.0,"SceneStats: MinDif should be 0.0 or above")

    # Prefiltering
    dClip = Defined(dClip) ? dClip : a
    dClip = dClip.ExtractY().ConvertBits(8, dither=-1, fulls=fs, fulld=fs)
    sClip =                       dClip.RatioResize(0.5,"%"        ,2,"bicubic",b=-0.5,c=0.3)
    dClip = width(dClip) > 1024 ? dClip.RatioResize(720.,"adjust2w",2,"bicubic",b=-0.5,c=0.3) : dClip


    ScriptClip(a, function [dClip,sClip,dfactor,MinDif,FC,la,stp,th,mo,st,std] () {

        SA  = propNumElements("_SceneRange",offset=-1) > 0 ? \
              propGetAsArray ("_SceneRange",offset=-1) : [-1,-1]
        n   = current_frame

        if (n-1>SA[1]) {

            nDf0  = 0    nTh   = 0   nDf   = 0
            avg   = 0    div   = 0
            stats = [0.0,0.0,0.0,0.0,0.0]

            # SCENE CHANGE + SCENE MOTION
            lookahead = min(la, FC-n-1)

            for (f=1, lookahead, 1) {

                fm    = f-1

                dClip = dClip.SelectEvery(1,1)
                pDf0  = dClip.YDifferenceFromPrevious()
                nDf0  = dClip.YDifferenceToNext()

                nDf   = mo ? nDf + dClip.YDifferenceToNext() : nop()
                nTh   = pDf0*dfactor+MinDif
                SE    = n+f

            # SCENE STATS

                if (st && fm%stp==0) {

                    stats = ArrayOp(stats,PlaneMinMaxStats(sClip, th, fm, 0, false),"+")
                    avg   = avg + sClip.AverageLuma(fm)
                    div   = div + 1

                    }

                divm = f
                f    = nDf0>nTh ? lookahead : f # stopper

            }

                       propSet("_SceneRange" , [n,SE])
            st ? std ? propSet("_SceneStats" , [stats[0]/div,stats[1]/div,stats[2]/div,stats[3]/div,avg/div,stats[4]/div,div]) : \
                       propSet("_SceneStats" , [stats[0]/div,stats[1]/div,stats[2]/div,stats[3]/div,avg/div,stats[4]/div])     : last
            mo ?       propSet("_SceneMotion", (nDf/divm)/255) : last # Motion in a scale of 0.0 - 1.0 (0.15 is considered very high motion)
        }
    } )

    # Sets Start (and fixes End)
    # Also sets every "frame property" to "scene property" by lookback and adds per-frame Standard Error

    sh = sh ? width()/10 : 0
    sh != 0 ? AddBorders(0,0,sh,0, $108080) : last

    ScriptClip( function[th,mo,st,std,sh] () {

        n   = current_frame
        np  = n+1

        SD  = propGetAsArray("_SceneRange",offset=-1)
        SD1 = SD[1]

        for (lb=n, 1, -1) {
            PR = propGetAsArray("_SceneRange",offset=-(np-lb))
            PE = PR[1]
            of = lb
            lb = PE != SD1 ? 1 : lb }

        of  = -(n-of)+1
        SA  = propGetAsArray("_SceneRange" ,offset=-(np-PE))
        SS  = (n+1 > SD1 ? PE : SA[1]) + 1
              propSet("_SceneRange" , [SS, SD1])

        if (mo) {
        PM  = propGetFloat  ("_SceneMotion",offset=of)
              propSet("_SceneMotion", PM) }

        if (st)  {
        PS  = propGetAsArray("_SceneStats" ,offset=of)
        if (std) {
        PS0 = PS[0]  PS1 = PS[1]  PS2 = PS[2]  PS3 = PS[3]  PS4 = PS[4]  PS5 = PS[5]  div = PS[6]  sdiv = sqrt(div)
              propSet("_SceneStats" , [PS0,PS1,PS2,PS3,PS4,PS5])
        } else {
              propSet("_SceneStats" , PS) } }

        if (std) {
        fst = PlaneMinMaxStats(th, 0, 0, false)
        avg = AverageLuma()

        # Standard Error of the Mean; 0~1 Accurate, 1~2 Good, 2~3 Bad, 3~4 Very Bad
        propSet("_SceneStatsStdErr", [sqrt(pow(fst[0]-PS0,2)/div)/sdiv, \
                                      sqrt(pow(fst[1]-PS1,2)/div)/sdiv, \
                                      sqrt(pow(fst[2]-PS2,2)/div)/sdiv, \
                                      sqrt(pow(fst[3]-PS3,2)/div)/sdiv, \
                                      sqrt(pow(avg   -PS4,2)/div)/sdiv, \
                                      sqrt(pow(fst[4]-PS5,2)/div)/sdiv]) }

        sh!=0 ? AddBorders(crop(0,0,-sh,0),0,0,sh,0, color_yuv = n==SS ? $EB8080 : $108080) : last
    } )


    wr != "" ? WriteFile(wr, function[mo,st] () {
    range  =      " Range: "  + ArrayPrint(propGetAsArray("_SceneRange"),true)
    stats  = st ? " Stats: "  + ArrayPrint(propGetAsArray("_SceneStats"),true) : ""
    motion = mo ? " Motion: " + string(propGetFloat("_SceneMotion"))           : ""
    string(current_frame) + ":" + range + stats + motion } ) : last

 }



###
### ReadStats() by Dogway (24-03-2022)
###
### Reads scene statistics from a file created by SceneStats() and writes them into frame properties:
###    "_SceneRange": [SceneStart, SceneEnd]
###    "_SceneStats": [min, max, th_min, th_max, average, median]
###    "_SceneMotion": float
###
###
function ReadStats(clip a, string "path") {

    ScriptClip(a, function [] () {

        mo    = FindStr(text, " Motion") > 0
        st    = FindStr(text, " Stats" ) > 0
        lines = DivideStr(text,    ":")
        range = DivideStr(lines[1],":")
        stats = DivideStr(range[1],":")

        motio = stats[1]
        range = !mo && !st ? lines[1] : ReplaceStr(range[0], st ? " Stats" : " Motion","")
        stats =  mo        ?            ReplaceStr(stats[0],      " Motion","") : stats[1]

             propSet("_SceneRange" , ArrayEval(range,false))
        st ? propSet("_SceneStats" , ArrayEval(stats,false)) : last
        mo ? propSet("_SceneMotion", Eval(motio))            : last

    } )

    ConditionalReader(path, "text", false)
}