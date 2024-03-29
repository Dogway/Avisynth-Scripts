######################################################
###                                                 ##
###                                                 ##
###   Scenes Pack v4.5   (19-02-2023)               ##
###                                                 ##
###                      by Dogway (Jose Linares)   ##
###                                                 ##
### https://forum.doom9.org/showthread.php?t=182881 ##
###                                                 ##
###                                                 ##
###  Functions:                                     ##
###       SceneStats                                ##
###       ReadStats                                 ##
###       ClipStats                                 ##
###                                                 ##
######################################################
###
###
### SceneStats() by Dogway (19-02-2023)
###
### SceneStats does a robust Scene Change Detection and calculates scene's statistics.
### Therefore it allows to work or apply filters on a per-scene ("per-shot" in film terms) basis,
### making better decisions than going per-frame or constant through the clip.
###
### It writes defined scene pixel statistics into frame properties for on-the-go drafting or offloads them to a file for speed:
###    "_SceneRange":       [SceneStart, SceneEnd]
###    "_SceneStats":       [min, max, th_min, th_max, average, median, IQM, (Pearson's Skewness)]
###    "_SceneStatsStdErr": [min, max, th_min, th_max, average, median, StDev]
###    "_SceneMotion":      float
###    "_SceneDetail":      float
###    "_SceneExposure":    int
###    "_SceneChangePrev":  int
###
### _SceneExposure: 0: Very Dark, 1: Dark, 2: Balanced, 3: Bright, 4: Very Bright
### Pearson's Skewness: Pearson's nonparametric skew of the scene's histogram distribution: (3*(average - median))/stdev = 0 (uniform distribution), +n (gamma distribution -> tilted to dark), -n (beta distribution -> tilted to bright)
### Tip1: A big difference between average and median depicts an asymmetric contrasty scene (bright frames + dark frames) or set of asymmetric contrasty frames (bright pixels + dark pixels)
### * IQM is like a interframe thresholded average, removing outliers at both sides discarding strong frame average biases. Probably more representative than average or median.
###
###
### Dependencies: > AviSynth v3.7.3 test9+
###                 ExTools
###                 ResizersPack
###
###
### Stats arguments:
###   mode:      Set the frame properties to write, almost* any combinations is possible (ie. "Range+Stats"): "Range" / "Stats" / "Motion" / "Detail" / "EV" / "Stats+StdErr"
###              *'Range' is mandatory if no '_SceneRange' frameprops exist. 'StdErr' requires 'Stats' and 'Y=true', also "Detail" and "EV" require 'Y=true'
###   interval:  Interval of frames to calculate statistics from. The lower the more precise but slower.
###              A value of 0.0 will only look into 'I' frames (aside start and end scene frames). Good for long shots in old movies.
###   th:        Threshold in percentage of pixels to ignore for 'th_min' and 'th_max' stats.
###
### Scene Change arguments:
###   dFactor:   Detection factor, a multiplier applied to frame difference metrics to decide if a scene changes.
###   Mindif:    Supply MinDif as if in 8 bit range (0.0 - 255.0). An additional component part (a bias) of scene change detection. Not very important when iFactor=true
###   iFactor:   If true (Default) it will give half weights to dFactor for 'I' type frames. This increases succesful detection rates for scene changes. Disable if clip is only I-frames.
###   Anime:     Scene Change Detection for anime should be handled differently, therefore this bool arg. Hard-codes 'iFactor=true' internally.
###
### Other:
###   path:      Define a path (anything other than "") to write stats to a file.
###   dClip:     You can supply an external clip to compute scene change and stats from. It can be a cropped version but for SC the clip should be grain free, if not supply a 'dClip' prefiltered with ex_minblur() or some kind of lightweight median or temporal denoiser.
###   show:      Enable to output frame properties, Prev frame diff factor, next frame diff factor and a scene change vertical bar.
###
###
### Function Definition:
###    (
###     clip,
###     string "mode"="ALL" ("ALL"/ "none"/ "Range"/ "Stats"/ "Motion"/ "Detail"/ "EV"/ "Stats+StdErr"/ "Range+Stats"/ "Range+Stats+Motion"/ "Range+Stats+Motion+Detail"/ "Range+Stats+Motion+Detail+EV"),
###     float "interval"=0.5 (0.0 to 2.0),
###     float "th"=0.5 (0.0 to 5.0),
###     float "dFactor"=3.7 (2.5 to 4.0),
###    [float "MinDif"=1.0 (0.5 to 4.0)],
###    [bool "iFactor"=true],
###    [bool "Y"=true],
###    [bool "UV"=false],
###     bool "show"=false
###    )
###
###
### Example for online filtering:
###     setmemorymax(2048)          # Higher recommended though
###     ffvideoSource("source.mkv") # CPU loader recommended as apposed to ie. DGSource()
###     SceneStats(mode="Range+Stats",Y=true,UV=false)
###     prefetch(n)
###
### Example file output (run over analysis pass):
###     setmemorymax(2048*3) # I wouldn't go any lower than 3 (6Gb)
###     ffvideoSource("source.mkv")
###     SceneStats("Range+Stats+Motion+EV",path="E:\source_stats.log")
###     prefetch(1)          # linear access
###
###     ### and load the stats ###
###
###     ReadStats("E:\source_stats.log")
###     or
###     ClipStats("E:\source_stats.log") # Slow initialization
###
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
    th      = Default(th,       0.454)     # Pixel ignore % threshold
    dFactor = Float(Default(dFactor,3.7))  # Range 2.5~4.0 ::: Change default to 4.0 to emulate SCSelect. Raise for noisy sources
    Mindif  = Float(Default(MinDif ,1.0))  # Range 0.5~4.0 ::: Change default to 0.0 to emulate SCSelect (disabled for 'I' frames when iFactor=true)
    md      = Default(mode,"Range+Stats")  # Stats to write to frame properties: "ALL", "none", "Range", "", "Stats", "Motion", "Detail", "EV" or "Exposure", "Stats+StdErr"
    wr      = Default(path,      "")       # Set a file path to offload SceneStats' stats to a file. Doesn't pair well with multithreading, so wisely use RequestLinear() and Prefetch(1)
    sh      = Default(show,   false)
    Y       = Default(Y,       true)       # Enable to output Luma   plane stats
    UV      = Default(UV,     false)       # Enable to output Chroma plane stats
    UV      = isy ? false : UV
    ib      = Default(iFactor, true)       # Halves dFactor multiplier for 'I' frames
    an      = Default(anime,  false)       # Anime SC
    ib      =  pt ? an ? true : ib : false
    Ifactor = (an ? 0.35 : 0.5) * dfactor  # For anime, SC algo is practically an 'I' frames reader (with some conditions)
    dfactor = (an ? 15.0 : 1.0) * dfactor
    YUV     = Y && UV

    la  = round(FR * 600)                  # Hard-coded 10 mins max look-ahead
    stp = round(FR * in)
    stp0= stp==0

    ZN  = (fs ? 0.01961 : 0.02283)
    PSA = (fs ? 0       : 16     )

    md  =         LCase  (md)
    all =         FindSTr(md, "all"   ) > 0
    rn  =  all || FindSTr(md, "range" ) > 0
    mo  =  all || FindSTr(md, "motion") > 0
    dt  =  all || FindSTr(md, "detail") > 0
    ev  =  all || FindSTr(md, "ev"    ) > 0  || FindSTr(md, "exposure") > 0
    st  =  all || FindSTr(md, "stats" ) > 0  || FindSTr(md, "stderr")   > 0
    std = (all || FindSTr(md, "stderr") > 0) && wr==""  # stderr are not written to log
    sr  = sr && !rn

          Assert(IsVersionOrGreater(3,7,3), "SceneStats: Update AviSynth+ version")
    !rn ? Assert(sr,                        "SceneStats: '_SceneRange' frameprops required when 'Range' mode is not enabled") : nop()
          Assert(!rgb,                      "SceneStats: Only YUV formats supported")
          Assert(dFactor >= 1.0,            "SceneStats: dFactor should be 1.0 or above")
          Assert(Mindif  >= 0.0,            "SceneStats: MinDif should be 0.0 or above")

    dClip = Defined(dClip) ? dClip : a
    uClip =  UV ? dClip.ExtractU().ConvertBits(8, dither=-1, fulls=fs, fulld=fs) : nop()
    vClip =  UV ? dClip.ExtractV().ConvertBits(8, dither=-1, fulls=fs, fulld=fs) : nop()
    dClip = !UV ? dClip.ExtractY().ConvertBits(8, dither=-1, fulls=fs, fulld=st ? fs : true) : dClip.ConvertBits(8, dither=-1, fulls=fs, fulld=fs)
    sClip =  UV && !Y  ?     vClip       :   dClip.RatioResize(0.5, "%"       ,2,"bicubic",b=-0.5,c=0.3)
    dClip = rn || mo ? width(dClip) > 1024 ? dClip.RatioResize(480, "adjust2w",2,"bicubic",b=-0.5,c=0.3) : dClip : dClip
    uClip = YUV ? sClip.ExtractU()       :   uClip
    vClip = YUV ? sClip.ExtractV()       :   vClip
    dClip =  an ? dClip.Limiter(0,100)   :   dClip     # AntiFlash & Anti-BiModal for Anime
    oClip =       dClip.SelectEvery(1,-1)
    dClip =       dClip.SelectEvery(1, 1)
    tClip =  dt ? sClip.ex_edge("tritical",0) : nop()  # Sub with SVM()? Should be lightweight though since we're looking back+ahead

    ScriptClip(a, function [oClip,dClip,sClip,tClip,uClip,vClip,Y,UV,stp,stp0,la,th,dfactor,ib,iFactor,MinDif,FC,an,rn,mo,ev,dt,st,std,sr,ZN,PSA,sh] () {

        n     = current_frame

        # SCENE CHANGE
        if (!sr || sh && rn) {
            pDf0  = !an ? oClip.YDifferenceFromPrevious() : oClip.YDifferenceToNext(-2)
            nDf0  = !an ? oClip.YDifferenceToNext()       : oClip.YDifferenceToNext( 1)

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

        nDf0  = 0    nTh  = 0      nDf  = 0        avga  = []   sum  = 0
        avg   = 0    SE   = FC     divy = 0.000001 aarr  = []   divm = divy
        avgt  = 0    pDf1 = n > 2 ? pDfp : 255
        arrz  = [0.0,0.0,0.0,0.0,0.0]
        stats = ArrayAdd(arrz,0.0)
        EVr   = 0    EVm = 0

        if (UV) {
        statsu = arrz   statsv = arrz  divu = divy
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
            ED = """EVr  = EV ? EVr  + YPlaneMinMaxDifference(sClip, 1) : EVr
                    EVm  = EV ? EVm  + YPlaneMedian(sClip)              : EVm
                    avgt = DT ? avgt + tClip.AverageLuma(f1)            : avgt"""
            DI = """divy = divy + 1"""

            if (!st && Y && (EV || DT)) {
                fe1 = f==1

                if (!stp0 && (fe1 || f%stp==0)) {

                    f1 = fe1 ? 0 : f
                    Eval(ED+Chr(10)+DI)

                } else if (stp0 && (fe1 || Ifr)) {

                    f1 = fe1 ? 0 : SC ? f : f+1
                    Eval(ED+Chr(10)+DI)

            } } else if (st) {

                fe1 = f==1
                blk = """pmms   =       PlaneMinMaxStats(sClip, th, f1, 0, false)
                         aarr   =       ArrayAdd(aarr,pmms[5])
                         stats  =       ArrayOp(stats,pmms,"+")"""+Chr(10)+ED+Chr(10)+DI

                blku= """statsu = Y   ? ArrayOp(statsu, PlaneMinMaxStats(sClip, th, f1, 1, false),"+") : \
                                        ArrayOp(statsu, PlaneMinMaxStats(uClip, th, f1, 0, false),"+")
                         statsv = Y   ? ArrayOp(statsv, PlaneMinMaxStats(sClip, th, f1, 2, false),"+") : \
                                        ArrayOp(statsv, PlaneMinMaxStats(vClip, th, f1, 0, false),"+")
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

        div  = Y  && (st || EV || DT) ? 1. / divy : 0.000001
        divu = UV &&  st              ? 1. / divu : 0.000001

        # Scene's IQM & avg standard deviation
        if (st && Y) {
            sze = int(divy)-1
            mea = stats[5]  *div
            med = stats[4]  *div

            if (std) {
                for (i=0, sze, 1)     {
                    sum = sum + pow(aarr[i]-mea,2) }
                stdev = sqrt(sum*div)
            }

            if (sze>5) {
            if (sze%2==1) {
                srt   = ArrayMedian(aarr,list=true)
                vl    = abs(srt[0]-med) >= abs(srt[sze]-med) ? 0 : sze
                aarr  = ArrayDel(srt,vl) # remove highest outlier to make it odd sized
                IQM   = ArrayIQM(aarr, true)
            } else {
                IQM   = ArrayIQM(aarr, false)
            } } else {
                IQM   = mea
            } }

        rn ?       propSet("_SceneChangePrev",   1 )                          : last
        rn ?       propSet("_SceneRange" , [n,min(SE+1,FC)])                  : last
        mo ?       propSet("_SceneMotion", (nDf/max(1,divm-1)) *0.03125)      : last  # Motion in a scale of 0.0 - 1.0 (0-0.2 calm, 0.2-0.4 busy, >0.4 high motion)
        dt && Y ?  propSet("_SceneDetail",   min(100,(avgt*div)*0.784313725)) : last  # Detail in a scale of 0.0 - 100.0
        ev && Y ?  propSet("_SceneExposure", min(4, round( max(0, (EVm * div - PSA) * ZN - 1) + max(0, EVr * div * ZN - 2))))                         : last
        if (st) {
        Y  ? std ? propSet("_SceneStats" , [stats[0] *div, stats[1] *div, stats[2] *div, stats[3] *div,             mea,           med, stdev, divy]) : \
                   propSet("_SceneStats" , [stats[0] *div, stats[1] *div, stats[2] *div, stats[3] *div,             mea,           med, IQM])         : last
        UV ?       propSet("_SceneStatsU", [statsu[0]*divu,statsu[1]*divu,statsu[2]*divu,statsu[3]*divu,statsu[5] *divu,statsu[4]*divu])              : last
        UV ?       propSet("_SceneStatsV", [statsv[0]*divu,statsv[1]*divu,statsv[2]*divu,statsv[3]*divu,statsv[5] *divu,statsv[4]*divu])              : last }

    } else {rn ?   propSet("_SceneRange" ,  [-1,-1]) : last
            rn ?   propSet("_SceneChangePrev",   0 ) : last
            mo ?   propSet("_SceneMotion",     0.0 ) : last
      Y &&  dt ?   propSet("_SceneDetail",     0.0 ) : last
      Y &&  ev ?   propSet("_SceneExposure",     0 ) : last
        if (st) {
      Y  ? std ?   propSet("_SceneStats" , [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.000001] ) : \
                   propSet("_SceneStats" , [0.0,0.0,0.0,0.0,0.0,0.0,0.0] )          : last
            UV ?   propSet("_SceneStatsU", [0.0,0.0,0.0,0.0,0.0] )                  : last
            UV ?   propSet("_SceneStatsV", [0.0,0.0,0.0,0.0,0.0] )                  : last } } } )

    # Propagates Scene Stats to each scene's frame (by means of lookback)
    sClip  = std && Y ? sClip : nop()
    lvl    = Histogram(mode="levels").crop(w,0,0,0)
    th!=0 && sh && st ? ex_lutspa(mode="mix", expr=Format("sx width 100 {th} / sqrt A@ / round % 1 < sy height A / % 1 < or x ymin + x ?"), UV=2) : last
    sh                ? stackhorizontal(last,lvl) : last


    ScriptClip( function[sClip,th,bi,mo,ev,dt,la,st,std,sh,sr,Y,UV] () {

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
        if (Y)  {
        ev ? propSet("_SceneExposure",propGetInt("_SceneExposure", offset=of)) : last
        dt ? propSet("_SceneDetail",  propGetFloat("_SceneDetail", offset=of)) : last }

        if (st)  {

            PS  = Y  ? propGetAsArray("_SceneStats" ,offset=of) : nop()
            PSU = UV ? propGetAsArray("_SceneStatsU",offset=of) : nop()
            PSV = UV ? propGetAsArray("_SceneStatsV",offset=of) : nop()

                Y ? Eval(Format("PS6    = nmod(ex_bs(PS[6],    8, {bi}, true, flt=true),dec=3)")) : nop()
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
                    propSet("_SceneStats" , [PS0,PS1,PS2,PS3,PS4,PS5,PS6]) }

            if (std) {
            fst   = PlaneMinMaxStats(sClip, th, 0, 0, false)
            for (i=0, 5, 1) {
                Eval(Format("fst{i} = nmod(ex_bs(fst[{i}], 8, {bi}, true, flt=true),dec=3)")) }

            # Standard Error of the Mean; 0~1 Accurate, 1~2 Good, 2~3 Bad, 3~4 Very Bad
            propSet("_SceneStatsStdErr", [sqrt(pow(fst[0]-PS0,2)*div)*sdiv, \
                                          sqrt(pow(fst[1]-PS1,2)*div)*sdiv, \
                                          sqrt(pow(fst[2]-PS2,2)*div)*sdiv, \
                                          sqrt(pow(fst[3]-PS3,2)*div)*sdiv, \
                                          sqrt(pow(fst[5]-PS4,2)*div)*sdiv, \
                                          sqrt(pow(fst[4]-PS5,2)*div)*sdiv,stdev]) } } }

        sh ? propGetInt("_SceneChangePrev")==1 ? Crop(0,0,-256,0).AddBorders(0,0,256,0, color_yuv = $EB8080) : last : last
    } )


    wr    != "" ?   WriteFile(wr, function[mo,ev,dt,st,Y,UV] () {
    range  =      " Range: "    + ArrayPrint(propGetAsArray("_SceneRange" ),true)
    motion = mo ? " Motion: "   + string(    propGetFloat  ("_SceneMotion"))      : ""
    if (Y)  {
    detail = dt ? " Detail: "   + string(    propGetFloat  ("_SceneDetail"))      : ""
    expos  = ev ? " Exposure: " + string(    propGetInt    ("_SceneExposure"))    : ""
    } else {
    detail = ""
    expos  = "" }
    if (st) {
    stats  = y  ? " Stats: "    + ArrayPrint(propGetAsArray("_SceneStats" ),true) : ""
    statsu = uv ? " StatsU: "   + ArrayPrint(propGetAsArray("_SceneStatsU"),true) : ""
    statsv = uv ? " StatsV: "   + ArrayPrint(propGetAsArray("_SceneStatsV"),true) : ""
    } else {
    stats  = ""
    statsu = ""
    statsv = "" }
    str = string(current_frame) + ":" + range + motion + detail + expos + stats + statsu + statsv
    current_frame == 0 ? "Type string"+Chr(10)+str : str } ) : last

    sh ? propShow() : last
 }




###
### ReadStats() by Dogway (04-02-2023)
###
### Reads scene statistics from a file created by SceneStats() and writes them into frame properties:
###    "_SceneRange":       [SceneStart, SceneEnd]
###    "_SceneStats":       [min, max, th_min, th_max, average, median, IQM, (Pearson's Skewness)]
###    "_SceneMotion":      float
###    "_SceneDetail":      float
###    "_SceneExposure":    int
###    "_SceneChangePrev":  int
###
### BEWARE!! For some reason in the exported log (from AvspMod) the first scene has repeated stats so manually remove those lines before loading the file.
###
function ReadStats(clip a, string "path") {

    Assert(Exist(path), "ReadStats: Defined file path doesn't exist.")

    ScriptClip(a, function [] () {

        text  = LCase(ReplaceStr(text,", ",","))+" "
        rn    = FindStr(text, "range"   )
        mo    = FindStr(text, "motion"  )  mo0 = mo  > 0
        dt    = FindStr(text, "detail"  )  dt0 = dt  > 0
        ev    = FindStr(text, "exposure")  ev0 = ev  > 0
        st    = FindStr(text, "stats:"  )  st0 = st  > 0
        stu   = FindStr(text, "statsu"  )  stu0= stu > 0
        stv   = FindStr(text, "statsv"  )  stv0= stv > 0
        sts   = FindStr(text, "stat"    )
        rn7   = rn+7
        rnp   = FindStr(MidStr(text, rn7)," ")

        range = MidStr(text, rn7,  rnp)
        motio = MidStr(text, mo +8,  8)
        detai = MidStr(text, dt +8,  9)
        expos = MidStr(text, ev +10, 2)
        stats = MidStr(text, st +7, 81)
        statu = MidStr(text, stu+8, 64)
        statv = MidStr(text, stv+8, 64)

        rng   = ArrayEval(range,false)
                propSet("_SceneRange" , rng)
                propSet("_SceneChangePrev", current_frame==rng[0]?1:0)
        stu0  ? propSet("_SceneStatsU", ArrayEval(statu,false)) : last
        stv0  ? propSet("_SceneStatsV", ArrayEval(statv,false)) : last
        st0   ? propSet("_SceneStats" , ArrayEval(stats,false)) : last
        mo0   ? propSet("_SceneMotion",      Eval(motio))       : last
        dt0   ? propSet("_SceneDetail",      Eval(detai))       : last
        ev0   ? propSet("_SceneExposure",    Eval(expos))       : last

    } )

    ConditionalReader(path, "text", false)
 }


###
### ClipStats() by Dogway (24-09-2022)
###
### Dependencies:
###              ExTools
###              RT_Stats
###
### Returns Global clip stats. Good for infering better global settings for clip-wide filtering.
### Simply point to the SceneStats output log and frame properties will be written for the whole clip.
###
function ClipStats(clip a, string "path") {

    Assert(Exist(path), "ClipStats: Defined file path doesn't exist.")
    a
    text  = LCase(ReplaceStr(RT_ReadTxtFromFile(path),", ",","))
    count = min(  RT_TxtQueryLines (text), FrameCount())-1

    ScriptClip(function [text,count] () {

        motio = 0.0
        detai = 0.0
        expos = 0
        stats = [0.0,0.0,0.0,0.0,0.0,0.0,0.0]
        statu = [0.0,0.0,0.0,0.0,0.0,0.0]
        statv = [0.0,0.0,0.0,0.0,0.0,0.0]

    if (current_frame==0) {

        for (i = 1, count, 1) {

            line  = RT_TxtGetLine(text,i)+" "
            rn    = FindStr(line, "range"   )
            mo    = FindStr(line, "motion"  )  mo0 = mo  > 0
            dt    = FindStr(line, "detail"  )  dt0 = dt  > 0
            ev    = FindStr(line, "exposure")  ev0 = ev  > 0
            st    = FindStr(line, "stats:"  )  st0 = st  > 0
            stu   = FindStr(line, "statsu"  )  stu0= stu > 0
            stv   = FindStr(line, "statsv"  )  stv0= stv > 0
            sts   = FindStr(line, "stat"    )
            rn7   = rn+7
            rnp   = FindStr(  MidStr(line, rn7)," ")

            range = ArrayEval(MidStr(line, rn7, rnp),false)
            rn0   = range[0]
            sc    = i==rn0+1

            if (sc) {
                rng   = range[1]-rn0+1
                motio = mo0  ? motio  +                       Eval(MidStr(line, mo +8,  8))*rng             : motio
                detai = dt0  ? detai  +                       Eval(MidStr(line, dt +8,  9))*rng             : detai
                expos = ev0  ? expos  +                       Eval(MidStr(line, ev +10, 2))*rng             : expos
                stats = st0  ? ArrayOp(stats,ArrayOp(rng,ArrayEval(MidStr(line, st +7, 81),false),"*"),"+") : stats
                statu = stu0 ? ArrayOp(statu,ArrayOp(rng,ArrayEval(MidStr(line, stu+8, 64),false),"*"),"+") : statu
                statv = stv0 ? ArrayOp(statv,ArrayOp(rng,ArrayEval(MidStr(line, stv+8, 64),false),"*"),"+") : statv
            }

    }
            count = float(count)
            stu0 ? propSet("_SceneStatsU",  ArrayOp(statsu,count,"/")) : last
            stv0 ? propSet("_SceneStatsV",  ArrayOp(statsv,count,"/")) : last
            st0  ? propSet("_SceneStats" ,  ArrayOp(stats, count,"/")) : last
            mo0  ? propSet("_SceneMotion",           motio/count)      : last
            dt0  ? propSet("_SceneDetail",           detai/count)      : last
            ev0  ? propSet("_SceneExposure",   round(expos/count))     : last
    } } )

    # Copying frame#0 properties to index#0 (clip wide) properties
    propNumElements("_SceneStats")    > 0 ? propSet("_SceneStats"   ,propGetAsArray("_SceneStats"   ,0)) : nop()
    propNumElements("_SceneStatsU")   > 0 ? propSet("_SceneStatsU"  ,propGetAsArray("_SceneStatsU"  ,0)) : nop()
    propNumElements("_SceneStatsV")   > 0 ? propSet("_SceneStatsV"  ,propGetAsArray("_SceneStatsV"  ,0)) : nop()
    propNumElements("_SceneMotion")   > 0 ? propSet("_SceneMotion"  ,propGetFloat  ("_SceneMotion"  ,0)) : nop()
    propNumElements("_SceneDetail")   > 0 ? propSet("_SceneDetail"  ,propGetFloat  ("_SceneDetail"  ,0)) : nop()
    propNumElements("_SceneExposure") > 0 ? propSet("_SceneExposure",propGetInt    ("_SceneExposure",0)) : nop()
 }