######################################################
###                                                 ##
###                                                 ##
###   Scenes Pack v1.3   (29-03-2022)               ##
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
### SceneStats() by Dogway (29-03-2022)
###
### Writes scene pixel statistics into frame properties (or offloads to a file), to choose from:
###    "_SceneRange": [SceneStart, SceneEnd]
###    "_SceneStats": [min, max, th_min, th_max, average, median, (Pearson's Skewness)]
###    "_SceneStatsStdErr": [min, max, th_min, th_max, average, median, StDev]
###    "_SceneMotion": float
###
###
### mode:      Set the frame properties to write along '_SceneRange': '_SceneStats' / '_SceneMotion' / '_SceneStatsStdErr'
### interval:  Interval of frames to calculate statistics from. The lower the more precise but slower. A value of 0.0 will only look into 'I' frames (aside start and end scene frames).
### th:        Threshold in percentage of pixels to ignore for 'min' and 'max' stats.
### dFactor:   Detection factor, a multiplier applied to frame difference metrics to decide if a scene changes.
### Mindif:    Supply MinDif as if in 8 bit range, 0.0 -> 255.0). An additional component part (a bias) of scene change detection.
### iFactor:   If true (Default) it will give half weights to dFactor for 'I' type frames. This increases succesful detection rates for scene changes.
### lookahead: Lookahead search for the scene-end frame. Limited to 60 seconds to make processing manageable.
### path:      Define a path (anything other than "") to write stats to a file.
### dClip:     You can supply an external clip to compute scene change and stats from.
### show:      Enable to output frame properties, Prev frame diff factor, next frame diff factor and a scene change vertical bar.
###
###
### Dependencies: ExTools
###               ResizersPack
###
### Function Definition:
###    (
###    clip,
###    string "mode"="ALL" ("ALL" / "none" / "Stats" / "Motion" / "Stats+StdErr"),
###    float "interval"=0.5 (0.0 to 2.0 by 0.1),
###    float "th"=0.1 (0.0 to 5.0 by 0.1),
###    float "dfactor"=3.7 (2.5 to 4.0 by 0.1),
###    float "MinDif"=1.0 (0.5 to 4.0 by 0.1),
###    [bool "iFactor"=true],
###    int "lookahead"=60 (10 to 120 by 1),
###    [int "Y"=3 (1 to 3 by 1)],
###    [int "UV"=1 (1 to 3 by 1)],
###    [bool "show"=false],
###    )
###
### Pearson's Skewness: Pearson's nonparametric skew of the scene's histogram distribution: (3*(average - median))/stdev = 0 (uniform distribution), +n (gamma distribution -> tilted to dark), -n (beta distribution -> tilted to bright)
### Tip1: To find if a scene is dark, neutral or bright you need to account for average, median and Pearson's Skewness.
### Tip2: A big difference between average and median depicts a contrasty scene (bright frames + dark frames) or a set of contrasty frames (bright pixels + dark pixels)
function SceneStats(clip a, string "mode", float "interval", float "th", float "dfactor", float "MinDif", bool "iFactor", int "lookahead", clip "dClip", string "path", bool "Y", bool "UV", bool "show") {

    rgb = isRGB(a)
    FC  = FrameCount(a)
    FR  = FrameRate (a)
    pt  = propNumElements(a,"_PictType"  )  > 0
    fs  = propNumElements(a,"_ColorRange")  > 0 ? \
          propGetInt     (a,"_ColorRange") == 0 : rgb

    in      = Default(interval, 0.5)       # Interval in seconds for fetching frames
    th      = Default(th,       0.1)       # 1/1000 threshold (1‰ -one per-mille-)
    dfactor = Float(Default(dfactor,3.7))  # Range 2.5~4.0 ::: Change default to 4.0 to emulate ScSelect
    Mindif  = Float(Default(MinDif ,1.0))  # Range 0.5~4.0 ::: Change default to 0.0 to emulate ScSelect
    md      = Default(mode, "Stats")       # Stats to write to frame properties: "ALL", "none", "Range", "", "Stats", "Motion", "Stats+StdErr"
    la      = Default(lookahead, 60)       # Max Scene Change lookahead in seconds
    wr      = Default(path,      "")       # Set a file path to offload SceneStats' stats to a file. Doesn't pair well with multithreading, so wisely use RequestLinear() and Prefetch(1)
    Y       = Default(Y,       true)       # Currently only Luma plane is supported
    UV      = Default(UV,     false)       # Currently noop
    sh      = Default(show,   false)
    ib      = Default(iFactor, true)       # Halves dFactor multiplier for 'I' frames
    ib      = pt ? ib : false
    Ifactor = dfactor*0.5

    stp = round(FR * in)
    la  = round(FR * la)

    mo  = md == "ALL" || md == "Stats+Motion" || md == "Motion"
    st  = md == "ALL" || md == "Stats+Motion" || md == "Stats" || md == "Stats+StdErr"
    std = md == "ALL" || md == "Stats+StdErr"

    Assert(IsVersionOrGreater(3,7,2), "SceneStats: Update AviSynth+ version")
    Assert(!rgb,                      "SceneStats: Only YUV formats supported")
    Assert(dFactor >= 1.0,            "SceneStats: dFactor should be 1.0 or above")
    Assert(Mindif  >= 0.0,            "SceneStats: MinDif should be 0.0 or above")

    # Prefiltering
    dClip = Defined(dClip) ? dClip : a
    dClip = dClip.ExtractY().ConvertBits(8, dither=-1, fulls=fs, fulld=fs)
    sClip =                       dClip.RatioResize(0.5,"%"        ,2,"bicubic",b=-0.5,c=0.3)
    dClip = width(dClip) > 1024 ? dClip.RatioResize(720.,"adjust2w",2,"bicubic",b=-0.5,c=0.3) : dClip


    ScriptClip(a, function [dClip,sClip,dfactor,iFactor,MinDif,FC,sh,la,stp,th,mo,st,std,ib] () {

        n     = current_frame
        clp   = sh ? dClip : nop()
        pDfp  = dClip.YDifferenceFromPrevious()

        nDf0  = 0    nTh  = 0     nDf  = 0        avga  = []   sum = 0
        avg   = 0    SE   = FC-1  div  = 0.000001 divm  = div
        pDf1  = n > 2 ? pDfp : 255
        stats = [0.0,0.0,0.0,0.0,0.0]

        # SCENE CHANGE + SCENE MOTION
        lookahead = min(la, FC-n-1)

        for (f=1, lookahead, 1) {

            dClip = dClip.SelectEvery(1,1)
            nDf0  = dClip.YDifferenceToNext()
            pDf0  = pDf1
            pDf1  = nDf0

            Ifr   = ib || st && stp==0 ? dClip.propGetString("_PictType",offset=1)=="I" : false
            nTh   = ib ? Ifr ? pDf0*iFactor+MinDif : pDf0*dfactor+MinDif : pDf0*dfactor+MinDif
            SC    = nDf0>nTh

        # SCENE STATS
            if (st) {

                fe1 = f==1
                blk = """stats = ArrayOp(stats,PlaneMinMaxStats(sClip, th, f1, 0, false),"+")
                         avg   = avg + sClip.AverageLuma(f1)
                         avga  = std ? ArrayAdd(avga,avg) : []
                         div   = div + 1"""

                if (stp>0 && (fe1 || f%stp==0)) {

                    f1    = fe1 ? 0 : f
                    Eval(blk)

                } else if (stp==0 && (fe1 || Ifr)) {

                    f1    = fe1 ? 0 : SC ? f : f+1
                    Eval(blk)

                } }

            SE    = n+f
            nDf   = mo ? !SC ? nDf + nDf0 : nDf : nop()
            divm  = f
            f     = SC ? lookahead : f

        }

        if (sh) {

            pDf0  = pDfp
            nDf0  = clp.YDifferenceToNext()

            nTh   = ib ? clp.propGetString("_PictType",offset=1)=="I" ? pDf0*iFactor+MinDif : pDf0*dfactor+MinDif : pDf0*dfactor+MinDif
            Subtitle(Format("Prev: {nTh}  Next: {nDf0}"), align=9)
        }

        if (std) {
            avgi  = avg/div
            for (i=0, ArraySize(avga)-1, 1)     {
                sum = sum + pow(avga[i]-avgi,2) }
            stdev = sqrt(sum/div)
        }

                   propSet("_SceneRange" , [0,SE])
        st ? std ? propSet("_SceneStats" , [stats[0]/div,stats[1]/div,stats[2]/div,stats[3]/div,avgi,   stats[4]/div,stdev,div]) : \
                   propSet("_SceneStats" , [stats[0]/div,stats[1]/div,stats[2]/div,stats[3]/div,avg/div,stats[4]/div])           : last
        mo ?       propSet("_SceneMotion", (nDf/max(1,divm-1))/25.5) : last # Motion in a scale of 0.0 - 1.0

    } )

    # Sets Start (and fixes End)
    # Also sets every "frame property" to "scene property" by lookback and adds per-frame Standard Error

    sh = sh ? width()/10 : 0
    sh != 0 ? AddBorders(0,0,sh,0, color_yuv = $108080) : last

    ScriptClip( function[th,mo,la,st,std,sh] () {

        n   = current_frame
        SD1 = propGetAsArray("_SceneRange",offset=-1)
        SD1 = SD1[1]

        for (lb=-2, -la, -1) {
            PR = propGetAsArray("_SceneRange",offset=lb)
            PE = PR[1]
            of = lb
            lb = PE != SD1 ? -la : lb }

        SA  = propGetAsArray("_SceneRange" ,offset=of)
        SS  = n+of < 1 ? 0 : (n+1 > SD1 ? PE : SA[1]) + 1
              propSet("_SceneRange" , [SS, SD1])

        of  = of+2
        if (mo) {
        PM  = propGetFloat  ("_SceneMotion",offset=of)
              propSet("_SceneMotion", PM) }

        if (st)  {
        PS  = propGetAsArray("_SceneStats" ,offset=of)
        if (std) {
        PS0 = PS[0]  PS1 = PS[1]  PS2 = PS[2]  PS3 = PS[3]  PS4 = PS[4]  PS5 = PS[5]  stdev = PS[6]  div = PS[7]  sdiv = sqrt(div)
              propSet("_SceneStats" , [nmod(PS0,dec=3),nmod(PS1,dec=3),nmod(PS2,dec=3),nmod(PS3,dec=3),nmod(PS4,dec=3),nmod(PS5,dec=3),3*(PS4-PS5)/stdev])
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
                                      sqrt(pow(fst[4]-PS5,2)/div)/sdiv,stdev]) }

        sh!=0 ? AddBorders(crop(0,0,-sh,0),0,0,sh,0, color_yuv = n==SS ? $EB8080 : $108080) : last
    } )


    wr != "" ? WriteFile(wr, function[mo,st] () {
    range  =      " Range: "  + ArrayPrint(propGetAsArray("_SceneRange"),true)
    stats  = st ? " Stats: "  + ArrayPrint(propGetAsArray("_SceneStats"),true) : ""
    motion = mo ? " Motion: " + string(propGetFloat("_SceneMotion"))           : ""
    string(current_frame) + ":" + range + stats + motion } ) : last

    sh!=0 ? propShow() : last
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