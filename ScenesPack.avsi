######################################################
###                                                 ##
###                                                 ##
###   Scenes Pack v2.1   (09-04-2022)               ##
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
### SceneStats() by Dogway (09-04-2022)
###
### SceneStats allows to work/filter in a per-scene ("per-shot" in film terms) basis,
### therefore making better decisions than going per-frame or constant through the clip.
###
### It writes scene pixel statistics into frame properties (or offloads to a file), to choose from:
###    "_SceneRange": [SceneStart, SceneEnd]
###    "_SceneStats": [min, max, th_min, th_max, average, median, (Pearson's Skewness)]
###    "_SceneStatsStdErr": [min, max, th_min, th_max, average, median, StDev]
###    "_SceneMotion": float
###
###
### Stats arguments:
### mode:      Set the frame properties to write, combinations are possible (ie. "Range+Stats"): '_SceneRange' / '_SceneStats' / '_SceneMotion' / '_SceneStatsStdErr'
### interval:  Interval of frames to calculate statistics from. The lower the more precise but slower. A value of 0.0 will only look into 'I' frames (aside start and end scene frames).
### th:        Threshold in percentage of pixels to ignore for 'min' and 'max' stats.
###
### Scene Change arguments:
### dFactor:   Detection factor, a multiplier applied to frame difference metrics to decide if a scene changes.
### Mindif:    Supply MinDif as if in 8 bit range, 0.0 -> 255.0). An additional component part (a bias) of scene change detection.
### iFactor:   If true (Default) it will give half weights to dFactor for 'I' type frames. This increases succesful detection rates for scene changes.
### lookahead: Lookahead search for the scene-end frame. Defaulted to 60 seconds to make processing manageable.
###
### Other:
### path:      Define a path (anything other than "") to write stats to a file.
### dClip:     You can supply an external clip to compute scene change and stats from. For SC the clip should be grain free, if not supply a 'dClip' prefiltered with ex_minblur() or some kind of median.
### show:      Enable to output frame properties, Prev frame diff factor, next frame diff factor and a scene change vertical bar.
###
###
### Dependencies: ExTools
###               ResizersPack
###
### Function Definition:
###    (
###    clip,
###    string "mode"="ALL" ("ALL" / "none" / "Range" / "Stats" / "Motion" / "Stats+StdErr"),
###    float "interval"=0.5 (0.0 to 2.0 by 0.1),
###    float "th"=0.1 (0.0 to 5.0 by 0.1),
###    float "dfactor"=3.7 (2.5 to 4.0 by 0.1),
###    float "MinDif"=1.0 (0.5 to 4.0 by 0.1),
###    [bool "iFactor"=true],
###    int "lookahead"=60 (10 to 120 by 1),
###    [bool "Y"=true],
###    [bool "UV"=false],
###    [bool "show"=false],
###    )
###
### Pearson's Skewness: Pearson's nonparametric skew of the scene's histogram distribution: (3*(average - median))/stdev = 0 (uniform distribution), +n (gamma distribution -> tilted to dark), -n (beta distribution -> tilted to bright)
### Tip1: To find if a scene is dark, neutral or bright you need to account for average, median and Pearson's Skewness.
### Tip2: A big difference between average and median depicts an asymmetric contrasty scene (bright frames + dark frames) or set of asymmetric contrasty frames (bright pixels + dark pixels)
###
function SceneStats(clip a, string "mode", float "interval", float "th", float "dfactor", float "MinDif", bool "iFactor", int "lookahead", clip "dClip", string "path", bool "Y", bool "UV", bool "show") {

    rgb = isRGB(a)
    isy = isy(a)
    FC  = FrameCount(a)-1
    FR  = FrameRate (a)
    bi  = BitsPerComponent(a)
    sr  = propNumElements (a,"_SceneRange")  > 0
    pt  = propNumElements (a,"_PictType"  )  > 0
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    in      = Default(interval, 0.5)       # Interval in seconds for fetching frames
    th      = Default(th,       0.1)       # 1/1000 threshold (0.1% or 1‰ -one per-mille-)
    dfactor = Float(Default(dfactor,3.7))  # Range 2.5~4.0 ::: Change default to 4.0 to emulate ScSelect
    Mindif  = Float(Default(MinDif ,1.0))  # Range 0.5~4.0 ::: Change default to 0.0 to emulate ScSelect (disabled for 'I' frames when iFactor=true)
    md      = Default(mode,"Range+Stats")  # Stats to write to frame properties: "ALL", "none", "Range", "", "Stats", "Motion", "Stats+StdErr"
    lh      = Default(lookahead, 60)       # Max Scene Change lookahead in seconds
    wr      = Default(path,      "")       # Set a file path to offload SceneStats' stats to a file. Doesn't pair well with multithreading, so wisely use RequestLinear() and Prefetch(1)
    sh      = Default(show,   false)
    Y       = Default(Y,       true)       # Enable to output Luma   plane stats
    UV      = Default(UV,     false)       # Enable to output Chroma plane stats
    UV      = isy ? false : UV
    ib      = Default(iFactor, true)       # Halves dFactor multiplier for 'I' frames
    ib      = pt ? ib : false
    Ifactor = dfactor*0.5

    la  = round(FR * lh)
    stp = round(FR * in)
    stp0= stp==0

    md  =        LCase  (md)
    all =        FindSTr(md, "all"   ) > 0
    rn  = all || FindSTr(md, "range" ) > 0
    mo  = all || FindSTr(md, "motion") > 0
    st  = all || FindSTr(md, "stats" ) > 0 || FindSTr(md, "stderr") > 0
    std = all || FindSTr(md, "stderr") > 0
    sr  = sr && !rn

          Assert(IsVersionOrGreater(3,7,2), "SceneStats: Update AviSynth+ version")
    !rn ? Assert(sr,                        "SceneStats: '_SceneRange' frameprops required when 'Range' mode is not enabled") : nop()
          Assert(!rgb,                      "SceneStats: Only YUV formats supported")
          Assert(dFactor >= 1.0,            "SceneStats: dFactor should be 1.0 or above")
          Assert(Mindif  >= 0.0,            "SceneStats: MinDif should be 0.0 or above")

    # Prefiltering (PseudoColor("isoparam") or MotionMask() could help detection but runs slow with SceneStats lookahead )
    dClip = Defined(dClip) ? dClip : a
    uClip =  UV ? dClip.ExtractU().ConvertBits(8, dither=-1, fulls=fs, fulld=fs) : nop()
    vClip =  UV ? dClip.ExtractV().ConvertBits(8, dither=-1, fulls=fs, fulld=fs) : nop()
    dClip = !UV ? dClip.ExtractY().ConvertBits(8, dither=-1, fulls=fs, fulld=st ? fs : true) : dClip.ConvertBits(8, dither=-1, fulls=fs, fulld=fs)
    sClip =!Y && UV  ?       uClip     :     dClip.RatioResize(0.5,       "%"       ,2,"bicubic",b=-0.5,c=0.3)
    dClip = rn || mo ? width(dClip) > 1024 ? dClip.RatioResize(-3*lh+900.,"adjust2w",2,"bicubic",b=-0.5,c=0.3) : dClip : nop()
    uClip = Y && UV ? sClip.ExtractU() : uClip
    vClip = Y && UV ? sClip.ExtractV() : vClip


    ScriptClip(a, function [dClip,sClip,Y,UV,uClip,vClip,dfactor,iFactor,MinDif,FC,sh,la,stp,stp0,th,mo,rn,st,std,ib,sr] () {

        if (sr) {
            srn = propGetAsArray("_SceneRange")
            sr1 = srn[1]
        }

        n     = current_frame
        clp   = sh ? dClip : nop()
        pDfp  = rn || mo ? dClip.SelectEvery(1,1).YDifferenceFromPrevious() : 0

        nDf0  = 0    nTh  = 0      nDf  = 0        avga  = []   sum = 0
        avg   = 0    SE   = FC     div  = 0.000001 divm  = div
        pDf1  = n > 2 ? pDfp : 255
        stats = [0.0,0.0,0.0,0.0,0.0]

        if (UV) {
        statsu = stats  statsv = stats  divu = div
        avgu   = 0      avgv   = 0    }


        # SCENE CHANGE + SCENE MOTION
        lookahead = sr ? sr1-n : min(la, FC-n)

        for (f=1, lookahead, 1) {

            if (rn || mo) {
            dClip = dClip.SelectEvery(1,1)
            nDf0  = dClip.YDifferenceToNext()
            pDf0  = pDf1
            pDf1  = nDf0

            Ifr   = ib || st && stp0 ? dClip.propGetString("_PictType",offset=  1)=="I" : false
            nTh   = ib ? Ifr ? pDf0*iFactor : pDf0*dfactor+MinDif : pDf0*dfactor+MinDif
            } else {
            Ifr   = ib || st && stp0 ? sClip.propGetString("_PictType",offset=f+1)=="I" : false
            }
            SC    = sr ? n==sr1 : nDf0>nTh || f==lookahead

        # SCENE STATS
            if (st) {

                fe1 = f==1
                blk = """stats  = ArrayOp(stats  ,PlaneMinMaxStats(sClip, th, f1, 0, false),"+")
                         avg    = avg + sClip.AverageLuma(f1)
                         avga   = std ? ArrayAdd(avga,avg) : []
                         div    = div + 1"""
                # if computing all 3 planes, switch to "f1, plane#" (when pinterf adds avg to PlaneMinMaxStats)
                blku= """statsu = ArrayOp(statsu, PlaneMinMaxStats(uClip, th, f1, 0, false),"+")
                         avgu   = avgu + uClip.AverageLuma(f1)
                         statsv = ArrayOp(statsv, PlaneMinMaxStats(vClip, th, f1, 0, false),"+")
                         avgv   = avgv + vClip.AverageLuma(f1)
                         divu   = divu + 1"""

                if (!stp0 && (fe1 || f%stp==0)) {

                    f1  = fe1 ? 0   : f
                    Y  ? Eval(blk)  : last
                    UV ? Eval(blku) : last

                } else if (stp0 && (fe1 || Ifr)) {

                    f1  = fe1 ? 0   : SC ? f : f+1
                    Y  ? Eval(blk)  : last
                    UV ? Eval(blku) : last
                } }

            divm  = f
            SE    = n+f
            nDf   = mo ? !SC ? nDf + nDf0 : nDf : nop()
            f     = SC ? lookahead : f
        }

        if (sh && rn) {

            pDf0  = clp.YDifferenceFromPrevious()
            nDf0  = clp.YDifferenceToNext()

            nTh   = ib ? clp.propGetString("_PictType",offset=1)=="I" ? pDf0*iFactor : pDf0*dfactor+MinDif : pDf0*dfactor+MinDif
            Subtitle(Format("Prev: {nTh}  Next: {nDf0}"), align=9)
        }

        # Scene's avg standard deviation
        if (std && Y) {
            avgi  = avg/div
            for (i=0, ArraySize(avga)-1, 1)     {
                sum = sum + pow(avga[i]-avgi,2) }
            stdev = sqrt(sum/div)
        }

        rn ?       propSet("_SceneRange" , [0,SE]) : last
        mo ?       propSet("_SceneMotion", (nDf/max(1,divm-1))/32.0) : last # Motion in a scale of 0.0 - 1.0 (0-0.2 calm, 0.2-0.4 busy, >0.4 high motion)
        if (st) {
        Y  ? std ? propSet("_SceneStats" , [stats[0] /div, stats[1] /div, stats[2] /div, stats[3] /div, avgi,     stats[4] /div,stdev,div]) : \
                   propSet("_SceneStats" , [stats[0] /div, stats[1] /div, stats[2] /div, stats[3] /div, avg /div, stats[4] /div])           : last
        UV ?       propSet("_SceneStatsU", [statsu[0]/divu,statsu[1]/divu,statsu[2]/divu,statsu[3]/divu,avgu/divu,statsu[4]/divu])          : last
        UV ?       propSet("_SceneStatsV", [statsv[0]/divu,statsv[1]/divu,statsv[2]/divu,statsv[3]/divu,avgv/divu,statsv[4]/divu])          : last }

    } )

    # Sets Start (and fixes End)
    # Also sets every "frame property" to "scene property" by lookback and adds per-frame Standard Error

    sh = sh ? width()/10 : 0
    sh != 0 ? AddBorders(0,0,sh,0, color_yuv = $108080) : last

    ScriptClip( function[th,bi,mo,la,st,std,sh,sr,Y,UV] () {

        n   = current_frame

        if (!sr) {

            SD1 = propGetAsArray("_SceneRange",offset=-1)
            SD1 = SD1[1]

                for (lb=-2, -la, -1) {
                    PR = propGetAsArray("_SceneRange",offset=lb)
                    PE = PR[1]
                    of = lb
                    lb = PE != SD1 ? -la : lb }

            SA  = propGetAsArray("_SceneRange",offset=of)
            SS  = n+of < 1 ? 0 : (n+1 > SD1 ? PE : SA[1]) + 1
                  propSet("_SceneRange" , [SS, SD1])

            of  = of+2

        } else {

            srn = propGetAsArray("_SceneRange")
            SS  = srn[0]
            of  = SS-n
        }

        if (mo) {
        PM  = propGetFloat("_SceneMotion", offset=of)
              propSet     ("_SceneMotion", PM) }

        if (st)  {

            PS  = Y  ? propGetAsArray("_SceneStats" ,offset=of) : nop()
            PSU = UV ? propGetAsArray("_SceneStatsU",offset=of) : nop()
            PSV = UV ? propGetAsArray("_SceneStatsV",offset=of) : nop()

            for (i=0, 5, 1) {
                Y ? Eval(Format("PS{i}  = nmod(ex_bs(PS[{i}],  8, {bi}, true, flt=true),dec=3)")) : nop()
                if (UV) {
                    Eval(Format("PSU{i} = nmod(ex_bs(PSU[{i}], 8, {bi}, true, flt=true),dec=3)"))
                    Eval(Format("PSV{i} = nmod(ex_bs(PSV[{i}], 8, {bi}, true, flt=true),dec=3)"))
                    propSet("_SceneStatsU", [PSU0,PSU1,PSU2,PSU3,PSU4,PSU5])
                    propSet("_SceneStatsV", [PSV0,PSV1,PSV2,PSV3,PSV4,PSV5]) } }

            if (Y) {

            if (std) {
                    stdev = PS[6]  div = PS[7]  sdiv = sqrt(div)
                    propSet("_SceneStats" , [PS0,PS1,PS2,PS3,PS4,PS5,3*(PS4-PS5)/stdev])
            } else {
                    propSet("_SceneStats" , [PS0,PS1,PS2,PS3,PS4,PS5]) }

            if (std) {
            fst = PlaneMinMaxStats(th, 0, 0, false)
            avg = AverageLuma()

            # Standard Error of the Mean; 0~1 Accurate, 1~2 Good, 2~3 Bad, 3~4 Very Bad
            propSet("_SceneStatsStdErr", [sqrt(pow(fst[0]-PS0,2)/div)/sdiv, \
                                          sqrt(pow(fst[1]-PS1,2)/div)/sdiv, \
                                          sqrt(pow(fst[2]-PS2,2)/div)/sdiv, \
                                          sqrt(pow(fst[3]-PS3,2)/div)/sdiv, \
                                          sqrt(pow(avg   -PS4,2)/div)/sdiv, \
                                          sqrt(pow(fst[4]-PS5,2)/div)/sdiv,stdev]) } } }

        sh!=0 ? AddBorders(crop(0,0,-sh,0),0,0,sh,0, color_yuv = n==SS ? $EB8080 : $108080) : last
    } )


    wr != "" ? WriteFile(wr, function[mo,st,Y,UV] () {
    motion = mo ? " Motion: " + string(    propGetFloat  ("_SceneMotion"))      : ""
    range  =      " Range: "  + ArrayPrint(propGetAsArray("_SceneRange" ),true)
    if (st) {
    stats  = y  ? " Stats: "  + ArrayPrint(propGetAsArray("_SceneStats" ),true) : ""
    statsu = uv ? " StatsU: " + ArrayPrint(propGetAsArray("_SceneStatsU"),true) : ""
    statsv = uv ? " StatsV: " + ArrayPrint(propGetAsArray("_SceneStatsV"),true) : ""
    } else {
    stats  = ""
    statsu = ""
    statsv = "" }
    str = string(current_frame) + ":" + range + motion + stats + statsu + statsv
    current_frame == 0 ? "Type string"+Chr(10)+str : str } ) : last

    sh!=0 ? propShow() : last
 }



###
### ReadStats() by Dogway (01-04-2022)
###
### Reads scene statistics from a file created by SceneStats() and writes them into frame properties:
###    "_SceneRange": [SceneStart, SceneEnd]
###    "_SceneStats": [min, max, th_min, th_max, average, median, (Pearson's Skewness)]
###    "_SceneMotion": float
###
###
function ReadStats(clip a, string "path") {

    ScriptClip(a, function [] () {

        text  = LCase  (text)
        rn    = FindStr(text, "range"  )
        mo    = FindStr(text, "motion" )
        st    = FindStr(text, "stats:" )
        stu   = FindStr(text, "statsu" )
        stv   = FindStr(text, "statsv" )
        sts   = FindStr(text, "stat"   )

        range = MidStr(text, rn +7, (mo>0?mo:sts>0?sts:StrLen(text))-(rn+7))
        motio = MidStr(text, mo +8, 8)
        stats = MidStr(text, st +7, 76)
        statu = MidStr(text, stu+8, 69)
        statv = MidStr(text, stv+8, 69)

                  propSet("_SceneRange" , ArrayEval(range,false))
        st  > 0 ? propSet("_SceneStats" , ArrayEval(stats,false)) : last
        stu > 0 ? propSet("_SceneStatsU", ArrayEval(statu,false)) : last
        stv > 0 ? propSet("_SceneStatsV", ArrayEval(statv,false)) : last
        mo  > 0 ? propSet("_SceneMotion", Eval(motio))            : last
    } )

    ConditionalReader(path, "text", false)
 }