/*
    ScSelect_HBD(), v0.01. by StainlessS (13 Feb 2021) @ Doom9. : https://forum.doom9.org/showthread.php?t=182392
        Requires Grunt (c) Gavino. If S_Frames or E_Frames != "" then also requires RT_Stats.

    # v0.01 - Initial Release
    # v0.02 - by Dogway. Use function objects (GrunT not needed). Make all clips optional. Tag SC to frame properties.

    SCSelect_HBD(clip dClip,clip Start,clip End,clip Motion,
        float "dfactor"=3.5,Float "MinDif"=1.0,
        bool "show"=False,String "S_Frames"="",String "E_Frames"="")

    ScSelect_HBD(), Mod of ScSelect_Like():- https://forum.doom9.org/showthread.php?p=1644023#post1644023
    Named with "_HDB" extender as should work ok with HBD in AVS+.
    ScSelect_Like() emulated ScSelect() from RemoveDirt.
        RemoveDirt's SCSelect(clip input, clip scene_begin, clip scene_end, clip global_motion, float dfactor, bool debug, bool planar)
        To emulate original ScSelect results, use ScSelect_HBD(dFactor=4.0,MinDif=0.0).

    Args:
        dClip,      Detection clip. May be different size and colorspace to Start, End and Motion clips. YUV only.
                    If High Bit Depth (greater than 8 bits per channel) then will be converted to 8 bit for scene change
                    detection stage. For larger source clips, you may want to downsize the dClip to speed up detection .

        Start,      Clip of frames that will replace frames from Motion clip when Start-Of-Scene detected.
        End,        Clip of frames that will replace frames from Motion clip when End-Of-Scene detected.
        Motion,     Clip the will be used where neither start nor end of scene detected.
                    Start, End, and Motion, clips can be different colorspace and size compared to dClip (unlike ScSelect),
                    but must all be same colorspace and size as each other, also can be high-bit-depth or RGB.

        dFactor,    Default 3.5. (1.0 <= dFactor) Detection factor, a multiplier applied to frame difference
                        metrics to decide if a scene change.
        Mindif,     Default 1.0. (0.0 <= Mindif, Supply MinDif as if in 8 bit range, 0.0 -> 255.0)
                      An additional component part of scene change detection.
                      Where difference measurements,
                        pDf = Average per pixel Luma difference, between dClip current frame and previous frame (0.0->255.0).
                        nDf = Average per pixel Luma difference, between dClip current frame and next frame (0.0->255.0).
                        pTh = dFactor * nDf + MinDif : If pDf greater than this then is SOS, Start-Of-Scene.
                        nTh = dFactor * pDf + MinDif : If nDf greater than this then is EOS, End-Of-Scene.
                        Detect method,
                          SOS = pDf > pTh : SOS = pDf > dFactor * nDf + MinDif,    Also,
                          EOS = nDf > nTh : EOS = nDf > dFactor * pDf + MinDif.
                          (If pDf > pTh, then pDf is also greater than nDf as dFactor is at least 1.0 and MinDif at least 0.0)
                      Original ScSelect, used default dFactor=4.0, and equivalent of MinDif=0.0 (It had no MinDif arg).
                      Using only dFactor, and no Mindif (ie 0.0), is not too good as a detector, especially where
                      scene of low motion or near static scene, eg when nDf=0.0 then pDf value of anything above 0.0
                      would detect a scene change, not exactly as desired for near static scene, additinal component is needed.
                      In same situation where MinDif=1.0 and  nDf=0.0, so SOS = pDf > pTh : SOS = pDf > 4.0 * 0.0 + 1.0
                      so, to detect Start of scene then pDf has to be greater than 1.0 for a start of scene detect.
                      In near static scene, we are most reliant upon Mindif being of sufficient magnitude to avoid a false
                      detection. In scene with plenty of motion, then value of dFactor becomes more important to prevent false
                      detection. In a very jerky or anime scene, then probably a high dFactor and high Mindif are required.
                      In this crazy mixed up world, you have to find a good compromise for dFactor and MinDif
                      so as to detect scene changes without producing false detections.
                      Our default of dFactor=3.5 and Mindif=1.0, is just one combination, you might prefer bigger Mindif
                      and smaller dFactor,(whatever you choose, some clips will require an alternative set).
                      I suggest dFactor usually no less than about 2.5 and no more than 4.0, and Mindif no less than 0.5, and
                      maybe no more than about 4.0. As you lower dFactor, you might want to raise Mindif, and vise versa.
                      Anime is likely to have different requirments with bigger MinDif (maybe 4 or more but depends upon the clip).

        Show,       Default False. In original ScSelect, this arg is called Debug, and output some info to DebugView (google),
                    we show info on frame and so have changed arg name to Show but of roughly same functionality.

                    Metrics when Show=True (metrics provided as if in 8 bit range):
                      >>>>>>>>>>>>>>>>>
                      20531 ] S {SOS: dFact= 19.7365:MinD=54.6495}
                      SOS: P{ 66.214} > pTh{ 12.565}<==
                      EOS: N{  3.304} > nTh{232.750}
                      <<<<<<<<<<<<<<<<<

                      20071,                              Is current Frame Number
                          S,                              Is flagging a detected Start-Of-Scene (Also 'E'=End-Of-Scene, and 'G' = Global motion.
                      SOS: P{ 66.214} > pTh{ 12.565} <==  The arrow "<==" at the end denotes a SOS (Start Of Scene) detection.
                                                          'P' (short for pDf, screen space saving) is difference to previous frame.
                                                          pTh = dFactor * nDf + MinDif
                      EOS: N{  3.304} > nTh{232.750}      Much as Above, but no EOS (End Of Scene) detection.
                                                          'N' (short for nDf), is difference to next frame.
                                                          nTh = dFactor * pDf + MinDif

                      {SOS: dFact= 19.7365:MinD=54.6495}, NOT ALWAYS SHOWN.
                                                          The Scene change Arg, matching estimate info, in this case for SOS estimate.
                                                          Shown only if pDf, nDF, and arg limits on dFactor and MinDif could
                                                          produce either SOS or EOS. This indicator only makes any sense on frames
                                                          that YOU have decided should be a scene change frame, otherwise ignore.
                                                          dFact is the dFactor that will produce an EXACT match of the threshold
                                                          (SOS pTh or EOS nTh) to the higher difference {SOS pDf or EOS nDf), when
                                                          MinDif unchanged.
                                                          As this example shows SOS, so the threshold is pTh and higher difference is pDf,
                                                          so it balances this line,
                                                              P{ 66.214} == pTh{66.214}, or
                                                              P{ 66.214} == {dfact   * nDf + MinDif)
                                                              P{ 66.214} == {19.7365 * nDf + MinDif)
                                                          So in this particular instance it shows that the maximum value for dFactor arg
                                                          that could produce SOS on this frame with current Mindif is LESS THAN 19.7365.
                                                          It shows that lowest value of dFactor that would fail to produce a SOS, so the maxium
                                                          value of dFactor that would succeed to detect SOS for current frame is just below this
                                                          value. (pDf has to be greater than pTh so when equal will fail SOS detect).
                                                          Similar can be deduced when EOS estimator is shown.
                                                          MinD is similar estimator (in this case again for SOS) which shows where MinDif
                                                          will balance (with current dFactor unchanged)
                                                              P{ 66.214} == pTh{66.214}, or
                                                              P{ 66.214} == {dfactor * nDf + MinD)
                                                              P{ 66.214} == {dfactor * nDf + 54.641195)
                                                          Similar can be deduced when EOS estimator is shown.
                                                          Hope some of that made at least a little sense, is intended to give you some
                                                          idea about how much you can raise (or lower) dFactor or Mindif to get
                                                          a successful detection on current frame.

        S_Frames,   Default "". Name of Start-Of-Scene Frames text file. Req RT_Stats if non "".
        E_Frames,   Default "". Name of End-Of-Scene Frames text file. Req RT_Stats if non "".

*/

Function SCSelect_HBD(clip dClip,clip "Start",clip "End",clip "Motion", float "dfactor",Float "MinDif",bool "show",String "S_Frames",String "E_Frames") {

    dfactor = Float(Default(dfactor,3.5))  # Suggest 2.5 -> 4.0 ::: Change default to 4.0 to emulate ScSelect
    Mindif  = Float(Default(MinDif ,1.0))  # Suggest 0.5 -> 4.0 ::: Change default to 0.0 to emulate ScSelect
    Show    = Default(show,false)
    S_Frames= Default(S_Frames,"")
    E_Frames= Default(E_Frames,"")
    Start   = Default(Start, Undefined())
    End     = Default(End, Undefined())
    Motion  = Default(Motion, dClip)
    StartD  = Defined(Start)
    EndD    = Defined(End)

    Assert(!DClip.IsRGB(),"SCSelect_HBD: DClip YUV Only")
    Assert(1.0 <= dFactor,"SCSelect_HBD: 1.0 <= dFactor")
    Assert(0.0 <= Mindif ,"SCSelect_HBD: 0.0 <= MinDif")

    try { bpc = DClip.BitsPerComponent() } catch(err_msg) { bpc = 8 }
    DClip = (bpc!=8) ? DClip.ConvertBits(8) : DClip
    Sz    = Max(Round(Motion.Height()*0.05),14)

    S_Frames = (S_Frames!="") ? S_Frames.RT_GetFullPathName() : ""
    E_Frames = (E_Frames!="") ? E_Frames.RT_GetFullPathName() : ""

    (S_Frames !="") ? RT_FileDelete(S_Frames) : nop()
    (E_Frames !="") ? RT_FileDelete(E_Frames) : nop()

    ScriptClip(Motion, function [dfactor,Start,StartD,End,EndD,Dclip,MinDif,show,S_Frames,E_Frames,Sz] () {

        n   = current_frame
        pDf = Dclip.YDifferenceFromPrevious()
        nDf = Dclip.YDifferenceToNext()
        pTh = nDf*dfactor+MinDif
        nTh = pDf*dfactor+MinDif
        SC  = 2                    # Default To SC = MOTION (Last is MOTION clip)
        if      (n==0)             { SC = 0 StartD ? Start : last   S_Frames!="" ? RT_WriteFile(S_Frames,"%d",n,Append=true) : nop() } # SOS
        else if (n==FrameCount()-1){ SC = 1 EndD   ? End   : last   E_Frames!="" ? RT_WriteFile(E_Frames,"%d",n,Append=true) : nop() } # EOS, Fixes ScSelect SOS detect on Last frame
        else if (pDf>pTh)          { SC = 0 StartD ? Start : last   S_Frames!="" ? RT_WriteFile(S_Frames,"%d",n,Append=true) : nop() } # SOS
        else if (nDf>nTh)          { SC = 1 EndD   ? End   : last   E_Frames!="" ? RT_WriteFile(E_Frames,"%d",n,Append=true) : nop() } # EOS

        propSet("_SceneChangePrev", SC==0?1:0, 0) # Start of a scene
        propSet("_SceneChangeNext", SC==1?1:0, 0) # End   of a scene

        n ==0 ? propSet("_SceneChangePrevLast",             0, 0). \
                propSet("_SceneChangeNextLast",             0, 0) : nop() # Start of clip
        SC==0 ? propSet("_SceneChangePrevLast", current_frame, 0) : nop() # Last detected Start frame
        SC==1 ? propSet("_SceneChangeNextLast", current_frame, 0) : nop() # Last detected End   frame

        if (show) {

            mx = Max(pDf,nDf)
            mn = Min(pDf,nDf)
            Can_dF = (mx > mn + Mindif)    # Can any values of dfactor(1.0 and aove) cause scene detect ?
            Can_Md = (mx > dFactor * mn)   # Can any values of MinDif(0.0 and above) cause scene detect ?

            if (Can_dF || Can_Md) {

                E_dF = (Can_dF) ? String(Min((mx - Mindif) / max(mn,0.00001),99.9999),"dFact=%7.4f") : ""
                E_Md = (Can_Md) ? String(mx - dFactor * mn,"MinD=%7.4f") : ""
                EdfS = E_dF + ((Can_dF && Can_Md) ? ":" : "") + E_Md + "}"
                EdfS = ((pDf==mx) ? "{SOS:" :"{EOS:") + EdfS

            } else { EdfS = "" }

            Subtitle(
            \ String(n,"%.0f] ") + MidStr("SEG",SC+1,1) + " " + EdfS + "\n" +
            \ String(pDf,"SOS: P{%7.3f} > ") + String(pTh,"pTh{%7.3f}") + (SC==0 ? " <==":"") + "\n" +
            \ String(nDf,"EOS: N{%7.3f} > ") + String(nTh,"nTh{%7.3f}") + (SC==1 ? " <==":"")
            \ ,Font="Courier New",Size=Sz,lsp=0)
        }

        return last

        } )

    return last
}
