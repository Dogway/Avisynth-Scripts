# Frame Rate Converter mix mod
# Version: 1.4.0  (22-06-2021)
#
# By Etienne Charland
# Based on Oleg Yushko's YFRC artifact masking,
# johnmeyer's frame interpolation code, and
# raffriff42's "weak mask" and output options.
# Pinterf is the one who spent the most time working on the core libraries, adding features and fixing bugs
# Dogway (1.4.0) (22-06-2021) replaced masktools2 with internal HBD aware Expr() wrappers, + cosmetics. (Requires ExTools.avsi, Utils-r41.avsi and AviSynth+ 3.5+)
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA, or visit
# http:#www.gnu.org/copyleft/gpl.html.

#######################################################################################
### Frame Rate Converter
### Increases the frame rate with interpolation and fine artifact removal.
##
## YV12/YV24/Y8/YUY2
## Requires: FrameRateConverter.dll, MaskTools2, MvTools2 (pinterf), GRunT (for debug only), ExTools, and Utils-r41
##
## @ NewNum      - The new framerate numerator (if FrameDouble = false, default = 60)
##
## @ NewDen      - The new framerate denominator (if FrameDouble = false, default = 1)
##
## @ Preset      - The speed/quality preset [slowest|slower|slow|normal|fast|faster|anime]. (default=normal)
##
## @ BlkSize     - The block size. Latest MvTools2.dll version from Pinterf supports 6, 8, 12, 16, 24, 32, 48 and 64.
##                 Defaults for 4/3 video of height:
##                 0-359:  8
##                 360-749: 12
##                 750-1199: 16
##                 1200-1699: 24
##                 1600-2160: 32
##
## @ BlkSizeV    - The vertical block size. (default = BlkSize)
##
## @ FrameDouble - Whether to double the frame rate and preserve original frames (default = true)
##
## @ Output      - Output mode [auto|flow|over|none|raw|mask|skip|diff|stripe] (default = auto)
##                    auto   = normal artifact masking
##                    flow   = interpolation only
##                    over   = mask as cyan overlay, stripes mask as yellow
##                    none   = ConvertFPS only
##                    raw    = raw mask
##                    mask   = mask only
##                    skip   = mask used to Skip
##                    diff   = mask where alternate interpolation is better
##                    stripe = mask used to cover stripes
##
## @ Debug       - Whether to display AverageLuma values of Skip, Mask and Raw. (Default = false)
##
## @ Prefilter   - Specifies a prefilter such as RgTools' RemoveGrain(21). Recommended only when not using a denoiser (Default=none)
##
## @ MaskThr     - The threshold where a block is considered bad, between 0 and 255. Smaller = stronger.
##                 0 to disable artifact masking. (Default = 120)
##
## @ MaskOcc     - Occlusion mask threshold, between 0 and 255. 0 to disable occlusion masking. (Default = 105)
##
## @ SkipThr     - The threshold where a block is counted for the skip mask, between 0 and 255. Smaller = stronger.
##                 Must be smaller (stronger) than MaskThr. (Default = 55)
##
## @ BlendOver   - Try fallback block size when artifacts cover more than specified threshold, or 0 to disable.
##                 If it fails again, it will revert to frame blending. (default = 70)
##
## @ SkipOver    - Skip interpolation of frames when artifacts cover more than specified threshold,
##                 or 0 to disable. (Default = 210)
##
## @ Stp         - Whether to detect and blend stripes (default=true)
##
## @ Dct         - Overrides DCT parameter for MAnalyse (default: Normal=0, Slow=4, Slowest=1)
##
## @ DctRe       - Overrides DCT parameter for MRecalculate (default: Fast=0, Normal=4, Slowest=1)
##
## @ BlendRatio  - Changes the blend ratio used to fill artifact zones. 0 = frame copy and 100 = full blend.
##                 Other values provide a result in-between to eliminate ghost effects. Default = 40.
##
##
## Presets
## Faster:  Basic interpolation
## Fast:    MRecalculate
## Normal:  MRecalculate with DCT=4
## Slow:    MAnalyze + MRecalculate with DCT=4
## Slower:  Calculate diff between DCT=4 and DCT=0 to take the best from both
## Slowest: Calculate diff between DCT=1 and DCT=0 to take the best from both
## Anime:   Slow with BlendOver=40, SkipOver=140
##
function FrameRateConverter (clip C, int "NewNum", int "NewDen", string "Preset", int "BlkSize", int "BlkSizeV", bool "FrameDouble", string "Output", bool "Debug",
\ clip "Prefilter", int "MaskThr", int "MaskOcc", int "SkipThr", int "BlendOver", int "SkipOver", bool "Stp", int "Dct", int "DctRe", int "BlendRatio", bool "fulls")
{
    Preset = Default(Preset, "normal")

    num = Preset == "slowest" ? 5 : \
          Preset == "slower"  ? 4 : \
          Preset == "slow"    ? 3 : \
          Preset == "normal"  ? 2 : \
          Preset == "fast"    ? 1 : \
          Preset == "faster"  ? 0 : \
          Preset == "anime"   ? 6 : \
          Assert(false, "FrameRateConverter: 'Preset' must be slowest, slower, slow, normal, fast, faster or anime {'" + Preset + "'}")

    Output = Default(Output, "auto")

    OPut = Output == "auto"   ? 0 : \
           Output == "flow"   ? 1 : \
           Output == "over"   ? 2 : \
           Output == "none"   ? 3 : \
           Output == "raw"    ? 4 : \
           Output == "mask"   ? 5 : \
           Output == "skip"   ? 6 : \
           Output == "diff"   ? 7 : \
           Output == "stripe" ? 8 : \
           Assert(false, "FrameRateConverter: 'Output' not one of (auto|flow|none|mask|skip|raw|diff|over) {'" + Output + "'}")

    Stp           = Default(Stp, true)
    FrameDouble   = Default(FrameDouble, !Defined(NewNum))
    NewNum        = FrameDouble ? C.FrameRateNumerator() * 2 : Default(NewNum, 60)
    NewDen        = FrameDouble ? C.FrameRateDenominator()   : Default(NewDen, 1)
    FrameDouble   = FrameDouble || (NewNum == C.FrameRateNumerator() * 2 && NewDen == C.FrameRateDenominator())
    DefH          = Max(C.Height(), C.Width()/4*3)
    BlkSize       = Default(BlkSize, DefH<360 ? 8 : DefH<750 ? 12 : DefH<1200 ? 16 : DefH<1600 ? 24 : 32)
    BlkSizeV      = Default(BlkSizeV, BlkSize)
    MaskThr       = Default(MaskThr, 120)
    SkipThr       = Default(SkipThr, 55)
    MaskOcc       = MaskThr > 0 ? Default(MaskOcc, 105) : 0
    CalcPrefilter = Defined(Prefilter)
    Prefilter     = Default(Prefilter, C)
    Debug         = Default(Debug, false)
    fs            = Default(fulls, false)
    BlendRatio    = Default(BlendRatio, 40)
    OutFps        = OPut > 3  # Whether output has altered frame rate

    #                           Faster     Fast    Normal    Slow    Slower    Slowest   Anime
    PSET        = Select (num,      5,        4,       3,       2,       1,         0,       2)
    Dctn        = Select (num,      0,        0,       0,       4,       4,         1,       4)
    DctRe       = Select (num,      0,        0,       4,       4,       4,         1,       4)
    BlendOvern  = Select (num,     70,       70,      70,      70,      70,        70,      40)
    SkipOvern   = Select (num,    210,      210,     210,     210,     210,       210,     140)
    Recalculate = Select (num,  false,    true,    true,    true,   true,      true,    true)
    CalcDiff    = Select (num,  false,   false,   false,   false,   true,      true,   false)

    Dctre     = PSET<3 ? Defined(Dct)       ? Dct : DctRe : 0
    Dct       =          Defined(Dct)       ? Dct : Dctn
    BlendOver =          Defined(BlendOver) ? BlendOver : BlendOvern
    SkipOver  =          Defined(SkipOver)  ? SkipOver  : SkipOvern

    Assert(IsVersionOrGreater(3,5,0), "Update AviSynth+ version")
    Assert(MaskThr >= 0 && MaskThr <= 255, String(MaskThr, "FrameRateConverter: MaskThr must be between 0 and 255 {%.f}"))
    Assert(MaskOcc >= 0 && MaskOcc <= 255, String(MaskOcc, "FrameRateConverter: MaskOcc must be between 0 and 255 {%.f}"))
    Assert(SkipThr < MaskThr, "FrameRateConverter: SkipThr must be lower (stronger) than MaskThr")
    Assert(BlendOver >= 0 && BlendOver <= 255, String(BlendOver, "FrameRateConverter: BlendOver must be between 0 and 255 {%.f}"))
    Assert(SkipOver >= 0 && SkipOver <= 255, String(SkipOver, "FrameRateConverter: SkipOver must be between 0 and 255 {%.f}"))
    Assert(BlendOver==0 || SkipOver==0 || SkipOver > BlendOver, "FrameRateConverter: SkipOver must be greater than BlendOver")
    Assert(CalcDiff || OPut!=7, "FrameRateConverter: You can only use Output='Diff' when using Preset=slower or slowest")

    ## "B" - Blending, "BHard" - No blending
    B = C.ConvertFpsLimit(NewNum, NewDen, ratio=BlendRatio)
    BHard  = C.ChangeFps(NewNum, NewDen)
    C_luma = C.ConvertToY()
    Blank  = BlankClip(C_luma, color_yuv=$000000)

    ## Adjust parameters for different block sizes, causing stronger or weaker masks
    blk     = Max(BlkSize, BlkSizeV)
    MaskThr = MaskThr + (blk<=4 ? -40 : blk<=6 ? -30 : blk<=8 ? -20  : blk<=12 ? -10 : blk<=16 ? 0   : blk<=24 ? 10  : blk<=32 ? 20 : blk<=48 ? 28 : 35)
    SkipThr = SkipThr + (blk<=4 ? -33 : blk<=6 ? -26 : blk<=8 ? -18  : blk<=12 ? -9  : blk<=16 ? 0   : blk<=24 ?  8  : blk<=32 ? 16 : blk<=48 ? 23 : 30)
    MaskThr = Max(Min(MaskThr, 255), 0)
    SkipThr = Max(Min(SkipThr, 255), 0)
    gam = blk<=4 ? .60 : blk<=6 ? .58 : blk<=8 ? .56 : blk<=12 ? .54 : blk<=16 ? .50 : blk<=24 ? .44 : blk<=32 ? .36 : blk<=48 ? .26 : .14
    dct_mult = !Recalculate ? .9 : DctRe==3 ? 1.2  : DctRe==2 ? 1.3  : DctRe==4 ? 1.09 : DctRe==1 ? 1.90 : 1
    dct_pow  = !Recalculate ?  1 : DctRe==3 ? 1.09 : DctRe==2 ? 1.10 : DctRe==4 ? 1.28 : DctRe==1 ? 1.32 : 1

    ## jm_fps interpolation
    superfilt =                 MSuper(prefilter.ConvertBits(8,dither=-1,fulls=fs), hpad=16, vpad=16,           sharp=1, rfilter=4)             # all levels for MAnalyse
    super     = CalcPrefilter ? MSuper(        C.ConvertBits(8,dither=-1,fulls=fs), hpad=16, vpad=16, levels=1, sharp=1, rfilter=4) : superfilt # one level is enough for MRecalculate
    superR    =                 MSuper(        C,                                   hpad=16, vpad=16, levels=1, sharp=1, rfilter=4)
    bak =         MAnalyse(superfilt, isb=true,  mt=true, blksize=BlkSize,  blksizev=BlkSizeV,   overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3,  dct=Dct)
    fwd =         MAnalyse(superfilt, isb=false, mt=true, blksize=BlkSize,  blksizev=BlkSizeV,   overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3,  dct=Dct)
    fwd = Recalculate ? MRecalculate(super, fwd, mt=true, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100, dct=DctRe) : fwd
    bak = Recalculate ? MRecalculate(super, bak, mt=true, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100, dct=DctRe) : bak
    Flow = MFlowFps(C, superR, bak, fwd, num=NewNum, den=NewDen, blend=false, ml=200, mask=2, thSCD2=255)

    ## "EM" - error or artifact mask
    # Mask: SAD
    EM    = MaskThr > 0 ? C_luma.MMask(bak, ml=255, kind=1, gamma=1/gam, ysc=255, thSCD2=SkipOver) : Blank
    # Mask: Temporal blending
    EMfwd = MaskThr > 0 ? C_luma.MMask(fwd, ml=255, kind=1, gamma=1/gam, thSCD2=SkipOver) : EM
    EM    = MaskThr > 0 ? ex_blend(EM,EMfwd,"lighten",0.6,UV=1,tv_range=false,fulls=fs) : EM


    # Mask: Occlusion
    EMocc = MaskOcc > 0 ? C_luma.MMask(bak, ml=MaskOcc, kind=2, gamma=1/gam, ysc=255, thSCD2=SkipOver).mt_inpand() : Blank
    EM    = MaskOcc > 0 ? ex_blend(EM,EMocc,"lighten",0.4,UV=1,tv_range=false,fulls=fs)          : EM
    EM    = dct_mult!=1 || dct_pow!=1 ? ex_lut(EM,Format("x {dct_mult} * {dct_pow} ^"),fulls=fs) : EM

    ## For CalcDiff, calculate a 2nd version and create mask to restore from 2nd version the areas that look better
    bak2  = CalcDiff ?          MAnalyse(superfilt, isb=true,  mt=true, blksize=BlkSize,   blksizev=BlkSizeV,  overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3, dct=0) : nop()
    fwd2  = CalcDiff ?          MAnalyse(superfilt, isb=false, mt=true, blksize=BlkSize,   blksizev=BlkSizeV,  overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3, dct=0) : nop()
    fwd2  = CalcDiff ? Recalculate ? MRecalculate(super, fwd2, mt=true, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100) : fwd : nop()
    bak2  = CalcDiff ? Recalculate ? MRecalculate(super, bak2, mt=true, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100) : bak : nop()
    Flow2 = CalcDiff ? MFlowFps(C, superR, bak2, fwd2, num=NewNum, den=NewDen, blend=false, ml=200, mask=2, thSCD2=255) : nop()
    # Get raw mask again
    EM2    = CalcDiff ? MaskThr > 0 ? C_luma.MMask(bak2, ml=255, kind=1, gamma=1/gam, ysc=255, thSCD2=SkipOver) : Blank : nop()
    EMfwd2 = CalcDiff ? MaskThr > 0 ? C_luma.MMask(fwd2, ml=255, kind=1, gamma=1/gam, thSCD2=SkipOver) : EM2 : nop()
    EM2    = CalcDiff ? MaskThr > 0 ? ex_blend(EM, EMfwd2,"lighten",0.6,UV=1,tv_range=false,fulls=fs)  : EM2 : nop()
    EMocc2 = CalcDiff ? MaskOcc > 0 ? C_luma.MMask(bak2, ml=MaskOcc, kind=2, gamma=1/gam, ysc=255, thSCD2=SkipOver).mt_inpand() : Blank : nop()
    EM2    = CalcDiff ? MaskOcc > 0 ? ex_blend(EM2,EMocc2,"lighten",0.4,UV=1,tv_range=false,fulls=fs)  : EM2 : nop()
    # Get difference mask between two versions
    EMdiff = CalcDiff ? ex_makediff(EM, EM2, dif=false, fulls=fs)
    \       .BicubicResize(Round(C.Width()/BlkSize)*4, Round(C.Height()/BlkSizeV)*4)
    \       .ex_expand(2,mode="circle")
    \       .ex_binarize(60,fulls=fs)
    \       .ex_blur(3)
    \       .BicubicResize(C.Width(), C.Height()) : nop()
    # Apply mask to Flow / EM
    EMdiff = CalcDiff ? OutFps ? EMdiff.ChangeFPS(NewNum, NewDen) : EMdiff : nop()
    Flow   = CalcDiff ? mt_merge(Flow, Flow2, EMdiff.MatchColorFormat(Flow,"PC.601"), luma=true, U=3,V=3) : Flow
    EM     = CalcDiff ? mt_merge(EM, EM2, EMdiff, luma=true, U=3,V=3)                                     : EM


    # Last mask frame is white. Replace with previous frame.
    EM = EM.DeleteFrame(EM.Framecount()-1).Loop(2, EM.Framecount()-1)

    # Create skip mask
    EMskip = EM.BicubicResize(Round(C.Width()/BlkSize/4.0)*4, Round(C.Height()/BlkSizeV/4.0)*4)
    \       .ex_expand(1,mode="circle")
    \       .ex_binarize(SkipThr,fulls=fs)
    OutSkip = EMskip.BicubicResize(C.Width(), C.Height())

    ## Create artifact correction mask
    OutRaw = EM
    EM = EM.BicubicResize(Round(C.Width()/BlkSize/4.0)*4, Round(C.Height()/BlkSizeV/4.0)*4)
    \       .ex_expand(1,mode="circle")
    \       .ex_binarize(MaskThr,fulls=fs)
    \       .removegrain(12)
    \       .BicubicResize(C.Width(), C.Height())

    # Mask: Stripes
    EMstp = C.StripeMask(blksize=BlkSize, blksizev=BlkSizeV, str=min(SkipThr*2+20, 255), strf=min(SkipThr+10, 255), thr=23)
    \      .BicubicResize(Round(C.Width()/BlkSize)*4, Round(C.Height()/BlkSizeV)*4)
    \      .ContinuousMask(22)
    EMstp = EMstp.BicubicResize(EMstp.Width()/2, EMstp.Height()/2)
    \      .ex_binarize(82,fulls=fs)
    \      .mt_inpand()
    \      .ex_expand(2,mode="circle").ex_expand(2,mode="square").ex_expand(2,mode="circle").mt_expand()
    \      .FRC_GaussianBlur42(2.8)
    \      .BicubicResize(C.Width(), C.Height())

    ## "M" - Apply artifact removal
    EM     =   OutFps ?     EM.ChangeFPS(NewNum, NewDen) : EM
    EMskip =   OutFps ? EMskip.ChangeFPS(NewNum, NewDen) : EMskip
    EMstp  =   OutFps ?  EMstp.ChangeFPS(NewNum, NewDen) : EMstp
    M =        OutFps ? mt_merge(Flow, B, EM.MatchColorFormat(Flow,"PC.601"), luma=true, U=3,V=3) : Flow
    M = Stp && OutFps ? mt_merge(M, B, EMstp.MatchColorFormat(Flow,"PC.601"), luma=true, U=3,V=3) : M

    ## Apply BlendOver and SkipOver
    M2 =  SkipOver > 0 ? ConditionalFilter(EMskip, B, BHard, "AverageLuma", "<", string(SkipOver))  : B
    M  = BlendOver > 0 ? ConditionalFilter(EMskip, M, M2,    "AverageLuma", "<", string(BlendOver)) : M

    # Prepare Output=Over: Mask(cyan), Stripes(yellow)
    FlowOver =       ex_blend(Flow,    CombinePlanes(Blank, EM, EM,       planes="RGB").MatchColorFormat(Flow,    "PC.601"), "add",0.4,UV=1,tv_range=false,fulls=fs)
    FlowOver = Stp ? ex_blend(FlowOver,CombinePlanes(EMstp, EMstp, Blank, planes="RGB").MatchColorFormat(FlowOver,"PC.601"), "add",0.4,UV=1,tv_range=false,fulls=fs) : FlowOver

    # Output modes
    R=  (Oput==0)                              [** auto: artifact masking     *]
    \     ? (FrameDouble ? Interleave(C, SelectOdd(M)) : M)
    \ : (Oput==1)                              [** flow: interpolation only   *]
    \     ? Flow
    \ : (Oput==2)                              [** over: mask as cyan overlay *]
    \     ? FlowOver
    \ : (Oput==3)                              [** none: ConvertFPS only      *]
    \     ? B
    \ : (Oput==4)                              [** raw:  raw mask             *]
    \     ? OutRaw.SMPTE_legal(fulls=fs)
    \ : (Oput==5)                              [** mask: mask only            *]
    \     ? EM
    \ : (Oput==6)                              [** skip: skip mask            *]
    \     ? OutSkip
    \ : (Oput==7)                              [** diff: diff mask            *]
    \     ? EMdiff
    \ : (Oput==8)                              [** stripe: stripes mask       *]
    \     ? EMstp
    \ : Assert(false, "FrameRateConverter: 'Output' INTERNAL ERROR")

    # Debug: display AverageLuma values of Skip, Mask and Raw
    ShowRaw = OutFps ? OutRaw.ChangeFPS(NewNum, NewDen) : OutRaw
    R = Debug ? R.ScriptClip("""Skip = EMskip.AverageLuma()
    \           SkipSoft = BlendOver > 0 && Skip >= BlendOver && (Skip < SkipOver || SkipOver == 0)
    \           Subtitle("BlkSize: " + string(BlkSize) +
    \           (SkipSoft ? " - Blend" : "") +
    \           (SkipOver > 0 && Skip >= SkipOver ? " - Skip" : "") +
    \           "\nSkip:  " + string(Skip, "%.4f") +
    \           "\nRaw:  " + string(ShowRaw.AverageLuma, "%.4f") +
    \           "\nMask: " + string(EM.AverageLuma, "%.4f") +
    \           (CalcDiff ? "\nDiff:    " + string(EMdiff.AverageLuma, "%.4f") : "") +
    \           (Stp ? "\nStripes: " + string(EMstp.AverageLuma, "%.4f") : "")
    \           , lsp=0)""", args = "EM,EMskip,EMstp,EMdiff,ShowRaw,BlkSize,SkipOver,BlendOver,CalcDiff,Stp", Local=true) : R
    return R
}



#######################################################################################
### InterpolateDoubles
### Replace double frames with interpolated frames using FrameRateConverter
##
## @ Thr         - Frames will be replaced when Luma difference with previous frame is greater than threshold (default=.1)
##
## @ Show        - If true, "FRAME FIXED" will be written on replaced frames (default=false)
##
## @ All other parameters are the same as FrameRateConverter
##
function InterpolateDoubles(clip C, float "Thr", bool "Show", string "Preset", int "BlkSize", int "BlkSizeV", int "MaskThr", int "MaskOcc", int "SkipThr", int "BlendOver", int "SkipOver", bool "Stp", int "Dct", int "DctRe")
{
    Thr    = Default(thr, .1)
    Show   = Default(Show, false)

    PrevC  = C.DeleteFrame(c.FrameCount()-1).DuplicateFrame(0)
    #NextC  = C.DuplicateFrame(C.FrameCount-1).DeleteFrame(0)
    Flow = FrameRateConverter(C, FrameDouble=true, Preset=preset, BlkSize=BlkSize, BlkSizeV=BlkSizeV, MaskThr=MaskThr, MaskOcc=MaskOcc, SkipThr=SkipThr, BlendOver=BlendOver, SkipOver=SkipOver, Stp=Stp, Dct=Dct, DctRe=DctRe).SelectOdd()
    Flow = (Show) ? Flow.Subtitle("FRAME FIXED",size=30,text_color=$0000FF,align=5) : Flow

    return ConditionalFilter(PrevC, Flow, C, "YDifferenceToNext", "lessthan", string(thr))
}




#######################################################################
### Emulate [[VariableBlur/GaussianBlur]]
##  For YUV, effective chroma blur varies depending on source
##  color subsampling - YUV444 has *more* chroma blur, others less.
##
## @ var - works like GaussianBlur's varY
## @ rad - blur radius (<var> squared); overrides <var>
## @ vvar, vrad - vertical var & rad; default same as horizontal
## @ p  - final [[GaussResize]] sharpness. Default 19
##        (if > 25, blockiness; if < 15, loss of contrast)
##
## version 2013-10-23 raffriff42
## version 2014-05-31 discrete hor. and vert. args
## version 2017-05-21 bugfix: blockiness
##
function FRC_GaussianBlur42(clip C,
\               float "var", float "rad",
\               float "vvar", float "vrad", float "p")
{
    var = Max(0.0, Float(Default(var, 1.0)))
    rad = Max(1.0, Float(Default(rad, Pow(var, 0.5))))
    var = Pow(Min(Max(0.0, rad), 60.0), 1.9) ## arbitrary max radius = 60

    vvar = Max(0.0, Float(Default(vvar, var)))
    vrad = Max(1.0, Float(Default(vrad, Pow(vvar, 0.5))))
    vvar = Pow(Min(Max(0.0, vrad), 60.0), 1.9)
    p    = Default(p, 19)

    w0 = C.Width()
    h0 = C.Height()
    w1 = Round(w0/rad)
    h1 = Round(h0/vrad)

    B = C.BilinearResize(
    \         Min(Max(4, w1 + (w1 % 2)), w0),
    \         Min(Max(4, h1 + (h1 % 2)), h0))

    B = B.removegrain(12).removegrain(12)

    return (var<0.01 && vvar<0.01)       ? C
    \    : (B.Width()>8 && B.Height()>8) ? B.GaussResize(w0, h0, p=p)
    \                                    : B.BilinearResize(w0, h0)
}