##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA, or visit
## https:#www.gnu.org/copyleft/gpl.html.
##
##############################################################
##
## Frame Rate Converter By Etienne Charland
##      https://forum.doom9.org/showthread.php?t=174793
##
## Based on Oleg Yushko's YFRC artifact masking,
## johnmeyer's frame interpolation code, and
## raffriff42's "weak mask" and output options.
##
## Pinterf is the one who spent the most time working on the core libraries, adding features and fixing bugs
##
#############################################################
##
## Frame Rate Converter     by Etienne Charland - v2.0.0 b11 (19-09-2021)
## Frame Rate Converter MIX by Dogway           - v2.3.3     (10-10-2022)
##     https://forum.doom9.org/showthread.php?t=182881
##
## Increases the frame rate with interpolation and fine artifact removal.
## MIX Mod for performance optimizations, HBD support, frame properties support and RIFE support.
##
## Dependencies: > FrameRateConverter.dll
##                 ExTools
##                 MVTools2
##                 MaskTools2
##                 RgTools
##                 GradePack
##                 RIFE              (for preset="RIFE")
##                    TransformsPack (for preset="RIFE")
##
##
## Example: ConvertBits(16).FrameRateConverterMIX(Preset="RIFE",FrameDouble=true)
##
##
## Function Definition:
##    (
##    clip,
##    [int "NewNum"=0 (10000 to 60000)],
##    [int "NewDen"=0 (1000 to 2000)],
##     string "Preset"="RIFE" ("Faster"/ "Fast"/ "Normal"/ "Slow"/ "Slower"/ "Slowest"/ "Anime"/ "RIFE"/ "RIFE-HQ"/ "RIFEanime"),
##    [int "BlkSize"=16 (6/ 8/ 12/ 16/ 24/ 32/ 48/ 64)],
##     bool "FrameDouble"=true,
##    [string "Output"="auto" ("auto"/ "flow"/ "over"/ "none"/ "raw"/ "mask"/ "skip"/ "diff"/ "stripe")],
##    [int "MaskThr"=120 (0 to 255)],
##    [int "MaskOcc"=105 (0 to 255)],
##    [int "SkipThr"=55 (0 to 255)],
##    [int "BlendOver"=70 (0 to 255)],
##    [int "SkipOver"=210 (0 to 255)],
##    [bool "Stp"=true],
##    [int "Dct"=1 (0 to 10)],
##    [int "DctRe"=4 (0 to 10)],
##    [int "RIFE"=1 (0 to 2)],
##    [int "rifeModel"=6 (0 to 9)],
##    [int "BlendRatio"=40 (0 to 100)],
##    [bool "tv_range"=true],
##    [bool "luma_rebuild"=true],
##    [bool "Debug"=false],
##     int "gpuid"=0
##    )
##
##
## SETTINGS:
##
## @ Input       - YV12/YV24/Y8 over any bitdepth
##
## @ NewNum      - The new framerate numerator (if FrameDouble = false, default = 60)
##
## @ NewDen      - The new framerate denominator (if FrameDouble = false, default = 1)
##
## @ Preset      - The speed/quality preset [slowest|slower|slow|normal|fast|faster|anime|rife|rifeHQ|rifeanime]. (default="normal")
##                    Faster:  Basic interpolation
##                    Fast:    MRecalculate
##                    Normal:  MRecalculate with DCT=4
##                    Slow:    MAnalyse + MRecalculate with DCT=4
##                    Slower:  Calculate diff between DCT=4 and DCT=0 to take the best from both
##                    Slowest: Calculate diff between DCT=1 and DCT=0 to take the best from both
##                    Anime:   'Slow'    with BlendOver=40, SkipOver=140
##                    RIFE:    'Slow'    with rife=1, maskThr=80 and DctRe=4
##                    RIFE-HQ: 'Slowest' with rife=1, maskThr=80 and DctRe=4
##                    RIFEanime: Both 'Anime' and 'RIFE' presets
##
## @ BlkSize     - The block size. Latest MvTools2.dll version from Pinterf supports 6, 8, 12, 16, 24, 32, 48 and 64.
##                    Defaults for 4/3 video of height:
##                    0-359:  8
##                    360-749: 12
##                    750-1199: 16
##                    1200-1699: 24
##                    1600-2160: 32
##
## @ BlkSizeV    - The vertical block size. (default = BlkSize)
##
## @ FrameDouble - Whether to double the frame rate and preserve original frames (default = true)
##
## @ Output      - Output mode [auto|flow|over|none|raw|mask|skip|diff|stripe] (default = "auto")
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
##                 Other values provide a result in-between to eliminate ghost effects. (Default = 40)
##
## @ RIFE        - Uses RIFE to double the framerate of the frame blending clip used to mask artifacts, reducing the need for frame blending.
##                 0 disables RIFE and uses only frame blending. 1 runs RIFE once but you will still notice frame blending. 2 runs RIFE twice for better quality.
##                 You can lower MaskThr to see more of the RIFE clip.
##                 More about the RIFE implementation: https://forum.doom9.org/showthread.php?t=174793&page=25
##
## @ tv_range    - True if source is Limited/TV range, False if source is Full/PC range. (Default = true)
##
## @ luma_rebuild- True to improve detail in dark areas for motion analysis
##
##
function FrameRateConverterMIX (clip C, int "NewNum", int "NewDen", string "Preset", int "BlkSize", int "BlkSizeV", bool "FrameDouble", string "Output",
\ clip "Prefilter", int "MaskThr", int "MaskOcc", int "SkipThr", int "BlendOver", int "SkipOver", bool "Stp", int "Dct", int "DctRe", int "RIFE", int "rifeModel", int "BlendRatio", bool "tv_range", bool "luma_rebuild", bool "Debug", int "gpuid")
{
    Preset = Default(Preset, "normal")

    num = Preset == "slowest"  ? 5 : \
          Preset == "slower"   ? 4 : \
          Preset == "slow"     ? 3 : \
          Preset == "normal"   ? 2 : \
          Preset == "fast"     ? 1 : \
          Preset == "faster"   ? 0 : \
          Preset == "anime"    ? 6 : \
          Preset == "RIFE"     ? 7 : \
          Preset == "RIFE-HQ"  ? 8 : \
          Preset == "RIFEanime"? 9 : \
          Assert(false, "FrameRateConverterMIX: 'Preset' must be slowest, slower, slow, normal, fast, faster, anime, RIFE, RIFE-HQ or RIFEanime {'" + Preset + "'}")

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
           Assert(false, "FrameRateConverterMIX: 'Output' not one of (auto|flow|none|mask|skip|raw|diff|over) {'" + Output + "'}")

    fs            = propNumElements(C,"_ColorRange")  > 0 ? \
                    propGetInt     (C,"_ColorRange") == 0 : false
    bi            = C.BitsPerComponent()
    w             = C.width()
    h             = C.height()
    frn           = C.FrameRateNumerator()
    frd           = C.FrameRateDenominator()
    isUHD         = (w > 2599 || h > 1499)
    isHD          = (w > 1099 || h >  599)
    Stp           = Default(Stp, true)
    FrameDouble   = Default(FrameDouble,   !Defined(NewNum))
    NewNum        = FrameDouble ? frn * 2 : Default(NewNum, 60)
    NewDen        = FrameDouble ? frd     : Default(NewDen, 1)
    FrameDouble   = FrameDouble || (NewNum == frn * 2 && NewDen == frd)
    DefH          = Max(h, w/4*3)
    BlkSize       = Default(BlkSize, DefH<360  ?  8 : \
                                     DefH<750  ? 12 : \
                                     DefH<1200 ? 16 : \
                                     DefH<1600 ? 24 : 32)
    BlkSizeV      = Default(BlkSizeV, BlkSize)
    MaskThr       = Default(MaskThr,  num>6 ? 80 : 120)
    SkipThr       = Default(SkipThr,  min(55,MaskThr-1))
    MaskOcc       = MaskThr > 0 ? Default(MaskOcc, 105) : 0
    CalcPrefilter = Defined(Prefilter)
    Prefilter     = Default(Prefilter, C)
    Debug         = Default(Debug,    false)
    tv            = Default(tv_range,   !fs)
    lr            = Default(luma_rebuild, true)
    BlendRatio    = Default(BlendRatio, 40)
    gpuid         = Default(gpuid, 0)
    rifeI         = Default(rife,  0)
    rife          = rifeI>0 || num>6
    rifeModel     = Default(rifeModel, rife ? num>8 ? 3 : num>7 ? 22 : 23 : 0)  # model=5 distorts more than 6 which does more blending (though pleasant)
/*  https://github.com/nihui/rife-ncnn-vulkan/issues/50#issuecomment-1229203013
    The rife architecture has two parameters called ensembling and fastmode integrated.
    You can't just export rife into one single model without such parameters.
    Nihui always just exports the fastest model (ensemble False, Fast True), while the other ones can result in a better image.
    Ensembling combines the flow of two different interpolations within the model and if fastmode is false it calls contextnet */

    OutFps        = OPut < 4  # Whether output has altered frame rate
    wb            = w/BlkSize
    wb4           = round(wb/4.0)*4
    hb            = h/BlkSizeV
    hb4           = round(hb/4.0)*4

    #                           Faster     Fast    Normal    Slow    Slower    Slowest   Anime     RIFE   RIFE-HQ  RIFEanime ('RIFEanime' matches 'Slow' defaults)
    Dctn        = Select (num,      0,        0,       0,       4,       4,         1,       4,       4,       1,        4)  # DCT=4 helps over hight motion or panning compared to DCT=1
    DctRe       = Select (num,      0,        0,       4,       4,       4,         1,       4,       4,       4,        4)
    BlendOvern  = Select (num,     70,       70,      70,      70,      70,        70,      40,      70,      70,       70)
    SkipOvern   = Select (num,    210,      210,     210,     210,     210,       210,     140,     210,     210,      210)
    Recalculate = Select (num,  false,     true,    true,    true,    true,      true,    true,    true,    true,     true)
    CalcDiff    = Select (num,  false,    false,   false,   false,    true,      true,    true,    true,    true,    false)

    # Overrides
    Dctre       = Default(Dct, DctRe)
    Dct         = Default(Dct, Dctn)
    BlendOver   = Default(BlendOver, BlendOvern)
    SkipOver    = Default(SkipOver,  SkipOvern)

    RIFE ? \
    Assert(IsVersionOrGreater(3,7,3),                            "FrameRateConverterMIX: RIFE requires AviSynth+ v3.7.3 or above") : nop()
    Assert(IsVersionOrGreater(3,7,2),                            "FrameRateConverterMIX: Update AviSynth+ version")
    Assert(MaskThr   >= 0 && MaskThr   <= 255, String(MaskThr,   "FrameRateConverterMIX: MaskThr must be between 0 and 255 {%.f}"))
    Assert(MaskOcc   >= 0 && MaskOcc   <= 255, String(MaskOcc,   "FrameRateConverterMIX: MaskOcc must be between 0 and 255 {%.f}"))
    Assert(BlendOver >= 0 && BlendOver <= 255, String(BlendOver, "FrameRateConverterMIX: BlendOver must be between 0 and 255 {%.f}"))
    Assert(SkipOver  >= 0 && SkipOver  <= 255, String(SkipOver,  "FrameRateConverterMIX: SkipOver must be between 0 and 255 {%.f}"))
    Assert(SkipThr < MaskThr,                                    "FrameRateConverterMIX: SkipThr must be lower (stronger) than MaskThr")
    Assert(BlendOver==0 || SkipOver==0 || SkipOver > BlendOver,  "FrameRateConverterMIX: SkipOver must be greater than BlendOver")
    Assert(CalcDiff || OPut!=7,                                  "FrameRateConverterMIX: You can only use Output='Diff' when using Preset=slower or slowest")

    # "BSoft" - Blending, "BHard" - No blending, "B" = RIFE + Blending
    B     = C.ConvertFpsLimit(NewNum, NewDen, ratio=BlendRatio)
    BSoft = B

    if (RIFE) {
        matA = (isUHD ? "2020" : isHD ? "709" : "170m") + (tv ? ":l" : ":f")
        B = is444(C) ? C.ConvertToPlanarRGB(matrix=matA) : C.ConvertToPlanarRGB(matrix=matA,chromaresample="spline16")
        B = B.ConvertBits(32,fulls=true)
        for (i=1, frameDouble ? 1 : min(rifeI,2), 1) {
            B = B.RIFE(uhd=isUHD, model=rifeModel, tta=false, gpu_id=gpuid)
        }
        B = MatchClip(B,C,matrix=matA,Size=false)
        B = B.ConvertFpsLimit(NewNum, NewDen, ratio=BlendRatio)
    }
    BHard  = C.ChangeFps (NewNum, NewDen)
    C_luma = C.ExtractY()
    Blank  = BlankClip(C_luma, color_yuv=$000000, pixel_type=PixelType(C), channels=0)

    # Adjust parameters for different BlkSize (block sizes), causing stronger or weaker masks
    blk      = Max(BlkSize, BlkSizeV)
    MaskThr  = MaskThr + (-90.4/pow(exp(blk),0.066)+30.9)
    MaskThr  = clamp(MaskThr, 0, 255)
    SkipThr  = SkipThr + (-75.4/pow(exp(blk),0.065)+25.7)
    SkipThr  = clamp(SkipThr, 0, 255)
    gam      =            -0.0078*blk+0.63
    dct_pow  =       !Recalculate ? 1.00 : 0 < DctRe < 5 ? 1.069+0.102*pow(DctRe-2.56,2) : 1.0
    dct_mult =       !Recalculate ? 0.90 : \
                         DctRe==1 ? 1.90 : \
                         DctRe==2 ? 1.30 : \
                         DctRe==3 ? 1.20 : \
                         DctRe==4 ? 1.09 : 1


    # For some reason feeding PC range and increasing chroma weight for good sources doesn't improve motion interpolation. Prolly the filter is very tuned to tv range
    # Hard-coded ex_luma_rebuild(S0=3) with tv range output (didn't scale up tv range as an optimization trick)
    rangePC = tv ? "ymin - 0 max A@" : ""  callX = tv ? "A" : "x"
    rangeTV = tv ? " ymin +"         : ""
    pre = prefilter.ConvertBits(8,dither=-1,fulls=!tv)
    Cp  =         C.ConvertBits(8,dither=-1,fulls=!tv)
    pre = lr ? pre.ex_lut("f32 0.125 1.0625 0.0664 x "+rangePC+" 0.0625 + / - * "+callX+" 0.875 * +"+rangeTV, scale_inputs=tv?"int":"intf",fulls=!tv) : pre
    Cp  = lr ?  Cp.ex_lut("f32 0.125 1.0625 0.0664 x "+rangePC+" 0.0625 + / - * "+callX+" 0.875 * +"+rangeTV, scale_inputs=tv?"int":"intf",fulls=!tv) : Cp


    # jm_fps interpolation
    superfilt =                 MSuper(pre, hpad=16, vpad=16,           sharp=1, rfilter=isHD?1:4)             # all levels for MAnalyse
    super     = CalcPrefilter ? MSuper(Cp,  hpad=16, vpad=16, levels=1, sharp=1, rfilter=isHD?1:4) : superfilt # one level is enough for MRecalculate
    superR    =                 MSuper(C,   hpad=16, vpad=16, levels=1, sharp=1, rfilter=isHD?1:4)
    bak       =         MAnalyse(superfilt, isb=true,  blksize=BlkSize,   blksizev=BlkSizeV,   overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3,  dct=Dct,   mt=true)
    fwd       =         MAnalyse(superfilt, isb=false, blksize=BlkSize,   blksizev=BlkSizeV,   overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3,  dct=Dct,   mt=true)
    fwd       = Recalculate ? MRecalculate(super, fwd, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100, dct=DctRe, mt=true) : fwd
    bak       = Recalculate ? MRecalculate(super, bak, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100, dct=DctRe, mt=true) : bak
    Flow      = MFlowFps(C, superR, bak, fwd, num=NewNum, den=NewDen, blend=false, ml=200, mask=2, thSCD2=255)

    # "EM" - error or artifact mask
    # Mask: SAD
    EM     = MaskThr > 0 ? C_luma.MMask(bak, ml=255, kind=1, gamma=1/gam, ysc=255, thSCD2=SkipOver)  : Blank
    # Mask: Temporal blending
    EMfwd  = MaskThr > 0 ? C_luma.MMask(fwd, ml=255, kind=1, gamma=1/gam,          thSCD2=SkipOver)  : EM
    EM     = MaskThr > 0 ? ex_blend(EM, EMfwd,"lighten",0.6,UV=1,tv_range=false)                     : EM


    # Mask: Occlusion
    EMocc  = MaskOcc > 0 ? C_luma.MMask(bak, ml=MaskOcc, kind=2, gamma=1/gam, ysc=255, thSCD2=SkipOver).mt_inpand()       : Blank
    EM     = MaskOcc > 0 ? ex_blend(EM, EMocc,"lighten",0.4,UV=1,tv_range=false)                                          : EM
    EM     = dct_mult!=1 || dct_pow!=1 ? ex_lut(EM,Format("x {dct_mult} * {dct_pow} ^"), scale_inputs="allf", fulls=true) : EM

    ## For CalcDiff, calculate a 2nd version and create mask to restore from 2nd version the areas that look better
    bak2   = CalcDiff ?          MAnalyse(superfilt, isb=true,  blksize=BlkSize,   blksizev=BlkSizeV,   overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3,  dct=0, mt=true) : nop()
    fwd2   = CalcDiff ?          MAnalyse(superfilt, isb=false, blksize=BlkSize,   blksizev=BlkSizeV,   overlap = BlkSize  >4?(BlkSize/4+1)/2*2:0, overlapv = BlkSizeV  >4?(BlkSizeV/4+1)/2*2:0, search=3,  dct=0, mt=true) : nop()
    fwd2   = CalcDiff ? Recalculate ? MRecalculate(super, fwd2, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100, dct=num==8 ? 4 : 0, mt=true) : fwd : nop()
    bak2   = CalcDiff ? Recalculate ? MRecalculate(super, bak2, blksize=BlkSize/2, blksizev=BlkSizeV/2, overlap = BlkSize/2>4?(BlkSize/8+1)/2*2:0, overlapv = BlkSizeV/2>4?(BlkSizeV/8+1)/2*2:0, thSAD=100, dct=num==8 ? 4 : 0, mt=true) : bak : nop()
    Flow2  = CalcDiff ? MFlowFps(C, superR, bak2, fwd2, num=NewNum, den=NewDen, blend=false, ml=200, mask=2, thSCD2=255) : nop()

    # Get raw mask again
    EM2    = CalcDiff ? MaskThr > 0 ? C_luma.MMask(bak2, ml=255,     kind=1, gamma=1/gam, ysc=255, thSCD2=SkipOver) : Blank : nop()
    EMfwd2 = CalcDiff ? MaskThr > 0 ? C_luma.MMask(fwd2, ml=255,     kind=1, gamma=1/gam,          thSCD2=SkipOver) : EM2   : nop()
    EM2    = CalcDiff ? MaskThr > 0 ? ex_blend(EM2,EMfwd2,"lighten",0.6,UV=1,tv_range=false)                        : EM2   : nop()
    EMocc2 = CalcDiff ? MaskOcc > 0 ? C_luma.MMask(bak2, ml=MaskOcc, kind=2, gamma=1/gam, ysc=255, thSCD2=SkipOver).mt_inpand() : Blank : nop()
    EM2    = CalcDiff ? MaskOcc > 0 ? ex_blend(EM2,EMocc2,"lighten",0.4,UV=1,tv_range=false)                        : EM2   : nop()

    # Get difference mask between two versions
    thb    = ex_bs(60,8,bi,fulls=true)
    EMdiff = CalcDiff ? ex_makediff(EM, EM2, dif=false, fulls=true)
    \       .BicubicResize(round(wb)*4, round(hb)*4)
    \       .ex_lut(Format("x[0,-2] x[-1,-1] max x[0,-1] max x[1,-1] max x[-2,0] max x[-1,0] max x[1,0] max x[2,0] max x[-1,1] max x[0,1] max x[1,1] max x[0,2] max x max {thb} > range_max 0 ?"), fulls=true)
    \       .GaussResize(w, h, p=3.5) : nop()

    # Apply mask to Flow / EM
    EMdiff = CalcDiff ? OutFps ? EMdiff.ChangeFPS(NewNum, NewDen)         : EMdiff : nop()
    Flow   = CalcDiff ? mt_merge(Flow, Flow2, EMdiff, luma=true, U=3,V=3) : Flow
    EM     = CalcDiff ? mt_merge(EM,     EM2, EMdiff, luma=true, U=3,V=3) : EM


    # Last mask frame is white. Replace with previous frame.
    LF     = EM.Framecount()-1
    EM     = EM.DeleteFrame(LF).Loop(2, LF)

    # Create skip mask
    SkipThrb = ex_bs(SkipThr,8,bi,fulls=true,flt=true)
    EMs      = EM.BicubicResize(wb4, hb4)
    EMskip   = EMs.ex_lut(Format("x[-1,0] x[0,-1] max x[0,1] max x[1,0] max x max {SkipThrb} > range_max 0 ?"), fulls=true)
    OutSkip  = EMskip.BicubicResize(w, h)

    # Create artifact correction mask
    OutRaw   = EM
    MaskThrb = ex_bs(MaskThr,8,bi,fulls=true,flt=true)
    EM       = EMs.ex_lut(Format("x[-1,0] x[0,-1] max x[0,1] max x[1,0] max x max {MaskThrb} > range_max 0 ?"), fulls=true)
    EM       = RIFE ? EM.mt_expand() : EM
    EM       = EM.GaussResize(w, h, p=15)

    # Mask: Stripes
    thb   = ex_bs(82,8,bi,fulls=true)
    EMstp = C.ex_StripeMask(blksize=BlkSize, blksizev=BlkSizeV, str=round(min(SkipThr*2+20, 255)), strf=round(min(SkipThr+10, 255)), fullRange=!tv)
    \      .BicubicResize(round(wb)*4, round(hb)*4)
    \      .ContinuousMask(22)
    EMstp = EMstp.BicubicResize(EMstp.Width()/2, EMstp.Height()/2)
    \      .ex_lut(Format("x[-1,-1] x[0,-1] min x[1,-1] min x[-1,0] min x[1,0] min x[-1,1] min x[0,1] min x[1,1] min x min {thb} > range_max 0 ?"), fulls=true)
    \      .ex_expand (3,mode="circle").ex_expand(5,mode="ring")
    \      .ex_boxblur(2,mode="mean")
    \      .GaussResize(w, h, p=4)

    ## "M" - Apply artifact removal
    EM     = OutFps ?     EM.ChangeFPS(NewNum, NewDen) : EM
    EMskip = OutFps ? EMskip.ChangeFPS(NewNum, NewDen) : EMskip
    EMstp  = OutFps ?  EMstp.ChangeFPS(NewNum, NewDen) : EMstp
    EMm    = mskY_to_YYY(Flow, EM,    true, false, 3, bi)
    EMstpm = mskY_to_YYY(Flow, EMstp, true, false, 3, bi)
    M      = OutFps && Stp ? ex_lutxyza(Flow, B, EMm, EMstpm, "x dup y - z range_max / * - dup y - a range_max / * -", UV=3, fulls=!tv) : \
             OutFps        ? mt_merge  (Flow, B, EM, luma=true, U=3,V=3) : Flow

    ## Apply BlendOver and SkipOver
    SO = ex_bs(SkipOver ,8,bi,fulls=true)
    BO = ex_bs(BlendOver,8,bi,fulls=true)
    M2 =  SkipOver > 0 ? ConditionalFilter(EMskip, BSoft, BHard, "AverageLuma", "<", string(SO)) : B
    M  = BlendOver > 0 ? ConditionalFilter(EMskip, M,     M2,    "AverageLuma", "<", string(BO)) : M

    # Prepare Output=Over: Mask(cyan), Stripes(yellow)
    FlowOver =       ex_blend(Flow.ConverttoPlanarRGB(), CombinePlanes(Blank, EM,    EM,    source_planes="YYY", planes="RGB", pixel_type="RGBP"+string(bi==32?"S":bi)), "add", 0.4, UV=3, tv_range=false)
    FlowOver = Stp ? ex_blend(FlowOver,                  CombinePlanes(EMstp, EMstp, Blank, source_planes="YYY", planes="RGB", pixel_type="RGBP"+string(bi==32?"S":bi)), "add", 0.4, UV=3, tv_range=false) : FlowOver

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
    \     ? OutRaw
    \ : (Oput==5)                              [** mask: mask only            *]
    \     ? EM
    \ : (Oput==6)                              [** skip: skip mask            *]
    \     ? OutSkip
    \ : (Oput==7)                              [** diff: diff mask            *]
    \     ? EMdiff
    \ : (Oput==8)                              [** stripe: stripes mask       *]
    \     ? EMstp
    \ : Assert(false, "FrameRateConverterMIX: 'Output' INTERNAL ERROR")

    # Debug: display AverageLuma values of Skip, Mask and Raw
    ShowRaw = OutFps ? OutRaw.ChangeFPS(NewNum, NewDen) : OutRaw
    R       = Debug  ? R.ScriptClip(function [EM,EMskip,EMstp,EMdiff,ShowRaw,BlkSize,SkipOver,BlendOver,CalcDiff,Stp,bi] () {

                Skip    = EMskip. AverageLuma()    Skip    = ex_bs(Skip    ,bi,8,fulls=true,flt=true)
                EMdiff  = EMdiff. AverageLuma()    EMdiff  = ex_bs(EMdiff  ,bi,8,fulls=true,flt=true)
                EMstp   = EMstp.  AverageLuma()    EMstp   = ex_bs(EMstp   ,bi,8,fulls=true,flt=true)
                EM      = EM.     AverageLuma()    EM      = ex_bs(EM      ,bi,8,fulls=true,flt=true)
                ShowRaw = ShowRaw.AverageLuma()    ShowRaw = ex_bs(ShowRaw ,bi,8,fulls=true,flt=true)

                SkipSoft = BlendOver > 0 && Skip >= BlendOver && (Skip < SkipOver || SkipOver == 0)

                Subtitle("BlkSize: " + string(BlkSize) +
    \           (SkipSoft ? " - Blend" : "") +
    \           (SkipOver > 0 && Skip >= SkipOver ? " - Skip" : "")         +
    \                       "\nSkip:  "   + string(Skip,   "   %.4f")       +
    \                       "\nRaw:  "    + string(ShowRaw,"   %.4f")       +
    \                       "\nMask: "    + string(EM,     "   %.4f")       +
    \           (CalcDiff ? "\nDiff:    " + string(EMdiff, "   %.4f") : "") +
    \           (Stp      ? "\nStripes: " + string(EMstp,     "%.4f") : "")
    \           , lsp=0) } ) : R

    return R }



#######################################################################################
##
## InterpolateDoubles
## Replace double frames with interpolated frames using FrameRateConverter
##
## @ Thr         - Frames will be replaced when Luma difference with previous frame is greater than threshold (default=0.1)
##
## @ Show        - If true, "FRAME FIXED" will be written on replaced frames (default=false)
##
## @ All other parameters are the same as FrameRateConverter.
##
function ex_InterpolateDoubles(clip C, float "Thr", bool "Show", string "Preset", int "BlkSize", int "BlkSizeV", int "MaskThr", int "MaskOcc", int "SkipThr", int "BlendOver", int "SkipOver", bool "Stp", int "Dct", int "DctRe", bool "tv_range") {

    bi     = BitsPerComponent(C)
    fs     = propNumElements (C,"_ColorRange")  > 0 ? \
             propGetInt      (C,"_ColorRange") == 0 : false
    thr    = Default(thr, 0.1)
    tv     = Default(tv_range, !fs)
    Show   = Default(Show,  false)

    thr = bi > 8 ? ex_bs(thr,8, bi, fulls=!tv, flt=true) : thr
    PrevC  = C.DeleteFrame(c.FrameCount()-1).DuplicateFrame(0)
    #NextC  = C.DuplicateFrame(C.FrameCount-1).DeleteFrame(0)
    Flow = FrameRateConverterMIX(C, FrameDouble=true, Preset=preset, BlkSize=BlkSize, BlkSizeV=BlkSizeV, MaskThr=MaskThr, MaskOcc=MaskOcc, SkipThr=SkipThr, BlendOver=BlendOver, SkipOver=SkipOver, Stp=Stp, Dct=Dct, DctRe=DctRe, tv_range=tv).SelectOdd()
    Flow = Show ? Flow.Subtitle("FRAME FIXED",size=30,text_color=$0000FF,align=5) : Flow

    return ConditionalFilter(PrevC, Flow, C, "YDifferenceToNext", "lessthan", string(thr)) }


#######################################################################################
##
## StripeMask
## Create a mask detecting horizontal and vertical stripes.
##
## @ blkSize     - The processing block size.
##
## @ blkSizeV    - The vertical block size. (default = blkSize)
##
## @ str         - The grey color of the masked areas.
##
## @ strf        - The grey color of the masked areas from the next frame.
##
function ex_StripeMask(clip C, int "blksize", int "blksizev", int "str", int "strf", bool "fullRange") {

    bi        = C.BitsPerComponent()
    blksize   = Default(blksize, 16)
    blksizev  = Default(blksizev, blksize)
    str       = Default(str, 200)
    strf      = Default(strf, 0)
    fullRange = Default(fullRange, false)

    mask1    = C.StripeMaskPass(blksize=blkSize, blksizev=blkSizeV, overlap=16/2+1, overlapV=16/2+1, thr=29, range=241, gamma=2.222, str=str, fullRange=fullRange)
    blksize  = int(float(blksize)  * 1.25)
    blksizev = int(float(blksizev) * 1.25)
    mask2    = C.StripeMaskPass(blksize=blkSize, blksizev=blkSizeV, overlap=16/2+1, overlapV=16/2+1, thr=42, range=214, gamma=2.222, str=str, fullRange=fullRange, comp=5)

    mask1f = mask1.DeleteFrame(0).DuplicateFrame(C.FrameCount() - 2)
    mask2f = mask2.DeleteFrame(0).DuplicateFrame(C.FrameCount() - 2)

    strf   = ex_bs(strf,8,bi,fulls=false)
    return strf > 0 ?
    \    ex_lutxyza(mask1, mask2, mask1f, mask2f, Format("x dup y dup z {strf} a {strf} 0 ? ? ? ?"), UV=1) :
    \    ex_lutxy  (mask1, mask2,                        "x dup y dup 0 ? ?",                        UV=1) }
