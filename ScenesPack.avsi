######################################################
###                                                 ##
###                                                 ##
###   Scenes Pack v3.9   (17-04-2022)               ##
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
### SceneStats() by Dogway (17-04-2022)
###
### SceneStats does robust Scene Change Detection and calculates scene's statistics.
### Therefore it allows to work or apply filters on a per-scene ("per-shot" in film terms) basis,
### making better decisions than going per-frame or constant through the clip.
###
### It writes defined scene pixel statistics into frame properties for on-the-go drafting or offloads them to a file for speed:
###    "_SceneRange": [SceneStart, SceneEnd]
###    "_SceneStats": [min, max, th_min, th_max, average, median, (Pearson's Skewness)]
###    "_SceneStatsStdErr": [min, max, th_min, th_max, average, median, StDev]
###    "_SceneMotion": float
###    "_SceneExposure": int
###    "_SceneChangePrev": int
###    "_SceneComplex": int (WIP)
###
### _SceneExposure: 0: Very Dark, 1: Dark, 2: Balanced, 3: Bright, 4: Very Bright
### Pearson's Skewness: Pearson's nonparametric skew of the scene's histogram distribution: (3*(average - median))/stdev = 0 (uniform distribution), +n (gamma distribution -> tilted to dark), -n (beta distribution -> tilted to bright)
### Tip1: A big difference between average and median depicts an asymmetric contrasty scene (bright frames + dark frames) or set of asymmetric contrasty frames (bright pixels + dark pixels)
###
###
### Dependencies: ExTools
###               ResizersPack
###
###
### Stats arguments:
### mode:      Set the frame properties to write, almost* any combinations is possible (ie. "Range+Stats"): "Range" / "Stats" / "Motion" / "EV" / "Stats+StdErr"
###            *'Range' is mandatory if no '_SceneRange' frameprops exist. 'StdErr' requires 'Stats' and 'Y=true'
### interval:  Interval of frames to calculate statistics from. The lower the more precise but slower.
###            A value of 0.0 will only look into 'I' frames (aside start and end scene frames). Good for long shots in old movies.
### th:        Threshold in percentage of pixels to ignore for 'th_min' and 'th_max' stats.
###
### Scene Change arguments:
### dFactor:   Detection factor, a multiplier applied to frame difference metrics to decide if a scene changes.
### Mindif:    Supply MinDif as if in 8 bit range, 0.0 -> 255.0). An additional component part (a bias) of scene change detection. Not very important when iFactor=true
### iFactor:   If true (Default) it will give half weights to dFactor for 'I' type frames. This increases succesful detection rates for scene changes.
###
### Other:
### path:      Define a path (anything other than "") to write stats to a file.
### dClip:     You can supply an external clip to compute scene change and stats from. For SC the clip should be grain free, if not supply a 'dClip' prefiltered with ex_minblur() or some kind of median.
### show:      Enable to output frame properties, Prev frame diff factor, next frame diff factor and a scene change vertical bar.
###
###
### Function Definition:
###    (
###    clip,
###    string "mode"="ALL" ("ALL" / "none" / "Range" / "Stats" / "Motion" / "Stats+EV" / "Stats+StdErr"),
###    float "interval"=0.5 (0.0 to 2.0 by 0.1),
###    float "th"=0.1 (0.0 to 5.0 by 0.1),
###    float "dFactor"=3.7 (2.5 to 4.0 by 0.1),
###    [float "MinDif"=1.0 (0.5 to 4.0 by 0.1)],
###    [bool "iFactor"=true],
###    [bool "Y"=true],
###    [bool "UV"=false],
###    [bool "show"=false],
###    )
###
###
### Example for online filtering:
###     setmemorymax(2048)   # Higher recommended though
###     ffvideoSource("source.mkv")
###     SceneStats(mode="Range+Stats",Y=true,UV=false)
###     prefetch(n)
###
### Example file output:
###     setmemorymax(2048*3) # I wouldn't go any lower than 3 (6Gb)
###     ffvideoSource("source.mkv")
###     SceneStats("Range+Stats+Motion+EV",path="E:\source_stats.log")
###     prefetch(1)          # linear access
###
###     ### and load the stats ###
###
###     ReadStats("E:\source_stats.log")
###
function SceneStats(clip a, string "mode", float "interval", float "th", float "dFactor", float "MinDif", bool "iFactor", bool "anime", clip "dClip", string "path", bool "Y", bool "UV", bool "show") {

    rgb = isRGB(a)
    isy = isy(a)
    FC  = FrameCount(a)-1
    FR  = FrameRate (a)
    w   = width     (a)
    bi  = BitsPerComponent(a)
    sr  = propNumElements (a,"_SceneRange")  > 0
    pt  = propNumElements (a,"_PictType"  )  > 0
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    in      = Default(interval, 0.5)       # Interval in seconds for fetching frames
    th      = Default(th,       0.1)       # 1/1000 threshold (0.1% or 1‰ -one per-mille-)
    dFactor = Float(Default(dFactor,3.7))  # Range 2.5~4.0 ::: Change default to 4.0 to emulate SCSelect. Raise for noisy sources
    Mindif  = Float(Default(MinDif ,1.0))  # Range 0.5~4.0 ::: Change default to 0.0 to emulate SCSelect (disabled for 'I' frames when iFactor=true)
    md      = Default(mode,"Range+Stats")  # Stats to write to frame properties: "ALL", "none", "Range", "", "Stats", "Motion", "EV" or "Exposure", "Stats+StdErr"
    wr      = Default(path,      "")       # Set a file path to offload SceneStats' stats to a file. Doesn't pair well with multithreading, so wisely use RequestLinear() and Prefetch(1)
    sh      = Default(show,   false)
    Y       = Default(Y,       true)       # Enable to output Luma   plane stats
    UV      = Default(UV,     false)       # Enable to output Chroma plane stats
    UV      = isy ? false : UV
    ib      = Default(iFactor, true)       # Halves dFactor multiplier for 'I' frames
    an      = Default(anime,  false)       # Anime SC
    ib      =  pt ?   ib :    false
    Ifactor = (an ? 0.35 : 0.5) * dfactor  # For anime, SC algo is practically an 'I' frames reader (with some conditions)
    dfactor = (an ? 15.0 : 1.0) * dfactor

    la  = round(FR * 600)                  # Hard-coded 10mins max look-ahead
    stp = round(FR * in)
    stp0= stp==0

    ZN  = (fs ? 0.01961 : 0.02283)
    PSA = (fs ? 0       : 16     )

    md  =         LCase  (md)
    all =         FindSTr(md, "all"   ) > 0
    rn  =  all || FindSTr(md, "range" ) > 0
    mo  =  all || FindSTr(md, "motion") > 0
    ev  =  all || FindSTr(md, "ev"    ) > 0  || FindSTr(md, "exposure") > 0
    st  =  all || FindSTr(md, "stats" ) > 0  || FindSTr(md, "stderr")   > 0
    std = (all || FindSTr(md, "stderr") > 0) && wr==""  # stderr are not written to log
    sr  = sr && !rn

          ver = VersionString()
          Assert(MidStr(ver,FindStr(ver,"(r")+2,4)=="3661", "SceneStats: Update AviSynth+ version")
    !rn ? Assert(sr,                                        "SceneStats: '_SceneRange' frameprops required when 'Range' mode is not enabled") : nop()
          Assert(!rgb,                                      "SceneStats: Only YUV formats supported")
          Assert(dFactor >= 1.0,                            "SceneStats: dFactor should be 1.0 or above")
          Assert(Mindif  >= 0.0,                            "SceneStats: MinDif should be 0.0 or above")

    dClip = Defined(dClip) ? dClip : a
    uClip =  UV ? dClip.ExtractU().ConvertBits(8, dither=-1, fulls=fs, fulld=fs) : nop()
    vClip =  UV ? dClip.ExtractV().ConvertBits(8, dither=-1, fulls=fs, fulld=fs) : nop()
    dClip = !UV ? dClip.ExtractY().ConvertBits(8, dither=-1, fulls=fs, fulld=st ? fs : true) : dClip.ConvertBits(8, dither=-1, fulls=fs, fulld=fs)
    sClip =!Y && UV  ?       uClip     :     dClip.RatioResize(0.5, "%"       ,2,"bicubic",b=-0.5,c=0.3)
    dClip = rn || mo ? width(dClip) > 1024 ? dClip.RatioResize(480, "adjust2w",2,"bicubic",b=-0.5,c=0.3) : dClip : nop()
    uClip = Y && UV ? sClip.ExtractU() : uClip
    vClip = Y && UV ? sClip.ExtractV() : vClip
    dClip = an ? dClip.Limiter(0,100)  : dClip  # AntiFlash & Anti-BiModal
    oClip =      dClip.SelectEvery(1,-1)
    dClip =      dClip.SelectEvery(1, 1)

    ScriptClip(a, function [oClip,dClip,sClip,Y,UV,uClip,vClip,dfactor,iFactor,MinDif,FC,sh,la,stp,stp0,th,an,mo,ev,rn,st,std,ib,sr,ZN,PSA] () {

        n     = current_frame

        # SCENE CHANGE
        # Can be improved with an antiflashes (by Limiter(0,100) ) or by exclusion on "movement in bimodal dark scenes" (specially anime)
        # Also considered computing VDifferenceToNext(), but it doesn't infer different data than YDifferenceToNext()
        # Also for anime, I can limit scene changes to no less than 4 frames apart
        if (!sr || sh && rn) {
            pDf0  = !an ? oClip.YDifferenceFromPrevious() : oClip.YDifferenceToNext(-2)
            nDf0  = !an ? oClip.YDifferenceToNext()       : oClip.YDifferenceToNext(1)

            nTh   = ib ? oClip.propGetString("_PictType",offset=1)=="I" ? pDf0*iFactor : pDf0*dfactor+MinDif : pDf0*dfactor+MinDif
            SC    = !an ? n!=1 && (nDf0>nTh || n==0) : n==0 ? true : \
                          n!=1 && min(27.3375,nDf0)>-0.461*(nDf0-nTh)+27.3375        # 2nd factor pass for "anime=true". Kind of a "nTh2" based on 'nDf0-nTh' instead of 'pDf0'. 'nDf0>nTh' check is implicit in the expression

            sh ? Subtitle(Format("Prev: {nTh}  Next: {nDf0}"), align=9) : nop()
        } else {
            srn1  = propGetAsArray("_SceneRange")
            sr1   = srn1[1]
            SC    = propGetInt("_SceneChangePrev")==1
        }

        # Evaluate Scene End only when Scene Start
        if (SC) {
        pDfp  = rn || mo ? !an ? dClip.YDifferenceFromPrevious() : dClip.YDifferenceToNext(-2) : 0

        nDf0  = 0    nTh  = 0      nDf  = 0        avga  = []   sum = 0
        avg   = 0    SE   = FC     divy = 0.000001 divm  = divy
        pDf1  = n > 2 ? pDfp : 255
        stats = [0.0,0.0,0.0,0.0,0.0]
      # EVsts = 0.0
        EVsts = stats

        if (UV) {
        statsu = stats  statsv = stats  divu = divy
        avgu   = 0      avgv   = 0    }


        # SCENE STATS
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
            SC    = sr ? n==sr1 : !an ?       nDf0>nTh          || f==lookahead : \
                    min(27.3375,nDf0)>-0.461*(nDf0-nTh)+27.3375 || f>=lookahead

        # SCENE STATS
            if (st) {

                fe1 = f==1
                blk = """stats  =      ArrayOp(stats  ,PlaneMinMaxStats(sClip, th, f1, 0, false),"+")
                         EVsts  = EV ? ArrayOp(EVsts  ,PlaneMinMaxStats(sClip,  1, f1, 0, false),"+") : EVsts
                       # EVsts  = EV ? EVsts + YPlaneMinMaxDifference(sClip, 1) : EVsts
                         avg    = avg + sClip.AverageLuma(f1)
                         avga   = std ? ArrayAdd(avga,avg) : []
                         divy   = divy + 1"""
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

            if (mo) {
            divm  = f
            nDf   =!SC ? nDf + nDf0 : nDf
            }

            SE    = n+f
            f     = SC ? lookahead : f
        }

        if (st) {
        div  = Y  ? 1. / divy : 0.000001
        divu = UV ? 1. / divu : 0.000001

        # Scene's avg standard deviation
        if (std && Y) {
            avgi  = avg*div
            for (i=0, ArraySize(avga)-1, 1)     {
                sum = sum + pow(avga[i]-avgi,2) }
            stdev = sqrt(sum*div)
        } }

        rn ?       propSet("_SceneChangePrev",   1 ) : last
        rn ?       propSet("_SceneRange" , [n,SE+1]) : last
        mo ?       propSet("_SceneMotion", (nDf/max(1,divm-1))/32.0) : last # Motion in a scale of 0.0 - 1.0 (0-0.2 calm, 0.2-0.4 busy, >0.4 high motion)
        if (st) {
        ev ?       propSet("_SceneExposure", min(4, round( max(0,        (stats[4] *div - PSA) * ZN - 1) + max(0,(EVsts[3] - EVsts[2]) * div * ZN - 2)))) : last
        Y  ? std ? propSet("_SceneStats" , [stats[0] *div, stats[1] *div, stats[2] *div, stats[3] *div, avgi,     stats[4] *div, stdev, divy])  : \
                   propSet("_SceneStats" , [stats[0] *div, stats[1] *div, stats[2] *div, stats[3] *div, avg *div, stats[4] *div])               : last
        UV ?       propSet("_SceneStatsU", [statsu[0]*divu,statsu[1]*divu,statsu[2]*divu,statsu[3]*divu,avgu*divu,statsu[4]*divu])              : last
        UV ?       propSet("_SceneStatsV", [statsv[0]*divu,statsv[1]*divu,statsv[2]*divu,statsv[3]*divu,avgv*divu,statsv[4]*divu])              : last }

    } else {rn ?   propSet("_SceneRange" ,  [-1,-1]) : last
            rn ?   propSet("_SceneChangePrev",   0 ) : last
            mo ?   propSet("_SceneMotion",     0.0 ) : last
        if (st) {
            ev ?   propSet("_SceneExposure",     0 ) : last
      Y  ? std ?   propSet("_SceneStats" ,  [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.000001] ) : \
                   propSet("_SceneStats" ,  [0.0,0.0,0.0,0.0,0.0,0.0] )              : last
            UV ?   propSet("_SceneStatsU",  [0.0,0.0,0.0,0.0,0.0] )                  : last
            UV ?   propSet("_SceneStatsV",  [0.0,0.0,0.0,0.0,0.0] )                  : last } } } )

    # Propagates Scene Stats to each scene's frame (by means of lookback)
    sClip  = std && Y ? sClip : nop()
    lvl    = Histogram(mode="levels").crop(w,0,0,0)
    th!=0 && sh && st ? ex_lutspa(mode="mix", expr=Format("sx width 100 {th} / sqrt A@ / round % 1 < sy height A / % 1 < or x ymin + x ?"), UV=2) : last
    sh                ? stackhorizontal(last,lvl) : last


    ScriptClip( function[sClip,th,bi,mo,ev,la,st,std,sh,sr,Y,UV] () {

        n   = current_frame

        if (!sr) {

            for (lb=0, -la, -1) {
                PR = propGetAsArray("_SceneRange",offset=lb)
                of = lb
                lb = PR[1] != -1 ? -la : lb }

             propSet("_SceneRange" , propGetAsArray("_SceneRange",offset=of))

        } else {

            srn = propGetAsArray("_SceneRange")
            SS  = srn[0]
            of  = SS-n
        }

        mo ? propSet("_SceneMotion",  propGetFloat("_SceneMotion", offset=of)) : last
        ev ? propSet("_SceneExposure",propGetInt("_SceneExposure", offset=of)) : last

        if (st)  {

            PS  = Y  ? propGetAsArray("_SceneStats" ,offset=of) : nop()
            PSU = UV ? propGetAsArray("_SceneStatsU",offset=of) : nop()
            PSV = UV ? propGetAsArray("_SceneStatsV",offset=of) : nop()

            for (i=0, 5, 1) {
                Y ? Eval(Format("PS{i}  = nmod(ex_bs(PS[{i}],  8, {bi}, true, flt=true),dec=3)")) : nop()
                if (UV) {
                    Eval(Format("PSU{i} = nmod(ex_bs(PSU[{i}], 8, {bi}, true, flt=true),dec=3)"))
                    Eval(Format("PSV{i} = nmod(ex_bs(PSV[{i}], 8, {bi}, true, flt=true),dec=3)")) } }
                if (UV) {
                    propSet("_SceneStatsU", [PSU0,PSU1,PSU2,PSU3,PSU4,PSU5])
                    propSet("_SceneStatsV", [PSV0,PSV1,PSV2,PSV3,PSV4,PSV5]) }

            if (Y) {

            if (std) {
                    stdev = PS[6]  divy = PS[7]  sdiv = 1./sqrt(divy)  div = 1./divy
                    propSet("_SceneStats" , [PS0,PS1,PS2,PS3,PS4,PS5,3*(PS4-PS5)/stdev])
            } else {
                    propSet("_SceneStats" , [PS0,PS1,PS2,PS3,PS4,PS5]) }

            if (std) {
            fst   = PlaneMinMaxStats(sClip, th, 0, 0, false)
            for (i=0, 4, 1) {
                Eval(Format("fst{i} = nmod(ex_bs(fst[{i}], 8, {bi}, true, flt=true),dec=3)")) }
            avg   =  nmod( ex_bs( AverageLuma(sClip),      8,  bi,  true, flt=true),dec=3)

            # Standard Error of the Mean; 0~1 Accurate, 1~2 Good, 2~3 Bad, 3~4 Very Bad
            propSet("_SceneStatsStdErr", [sqrt(pow(fst[0]-PS0,2)*div)*sdiv, \
                                          sqrt(pow(fst[1]-PS1,2)*div)*sdiv, \
                                          sqrt(pow(fst[2]-PS2,2)*div)*sdiv, \
                                          sqrt(pow(fst[3]-PS3,2)*div)*sdiv, \
                                          sqrt(pow(avg   -PS4,2)*div)*sdiv, \
                                          sqrt(pow(fst[4]-PS5,2)*div)*sdiv,stdev]) } } }

        sh ? propGetInt("_SceneChangePrev")==1 ? Crop(0,0,-256,0).AddBorders(0,0,256,0, color_yuv = $EB8080) : last : last
    } )


    wr    != "" ? WriteFile(wr, function[mo,ev,st,Y,UV] () {
    range  =      " Range: "    + ArrayPrint(propGetAsArray("_SceneRange" ),true)
    motion = mo ? " Motion: "   + string(    propGetFloat  ("_SceneMotion"))      : ""
    if (st) {
    expos  = ev ? " Exposure: " + string(    propGetInt    ("_SceneExposure"))    : ""
    stats  = y  ? " Stats: "    + ArrayPrint(propGetAsArray("_SceneStats" ),true) : ""
    statsu = uv ? " StatsU: "   + ArrayPrint(propGetAsArray("_SceneStatsU"),true) : ""
    statsv = uv ? " StatsV: "   + ArrayPrint(propGetAsArray("_SceneStatsV"),true) : ""
    } else {
    expos  = ""
    stats  = ""
    statsu = ""
    statsv = "" }
    str = string(current_frame) + ":" + range + motion + expos + stats + statsu + statsv
    current_frame == 0 ? "Type string"+Chr(10)+str : str } ) : last

    sh ? propShow() : last
 }




###
### ReadStats() by Dogway (14-04-2022)
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
        rn    = FindStr(text, "range"   )
        mo    = FindStr(text, "motion"  )
        ev    = FindStr(text, "exposure")
        st    = FindStr(text, "stats:"  )
        stu   = FindStr(text, "statsu"  )
        stv   = FindStr(text, "statsv"  )
        sts   = FindStr(text, "stat"    )

        range = MidStr(text, rn +7, (mo>0?mo:sts>0?sts:StrLen(text))-(rn+7))
        motio = MidStr(text, mo +8,  8)
        expos = MidStr(text, ev +10, 2)
        stats = MidStr(text, st +7, 76)
        statu = MidStr(text, stu+8, 69)
        statv = MidStr(text, stv+8, 69)

        rng   = ArrayEval(range,false)
                  propSet("_SceneRange" , rng)
                  propSet("_SceneChangePrev", current_frame==rng[0]?1:0)
        st  > 0 ? propSet("_SceneStats" , ArrayEval(stats,false)) : last
        stu > 0 ? propSet("_SceneStatsU", ArrayEval(statu,false)) : last
        stv > 0 ? propSet("_SceneStatsV", ArrayEval(statv,false)) : last
        mo  > 0 ? propSet("_SceneMotion",   Eval(motio))          : last
        ev  > 0 ? propSet("_SceneExposure", Eval(expos))          : last

    } )

    ConditionalReader(path, "text", false)
 }