#############################################################################
###                                                                       ###
###        Sharpeners Pack v3.5  (16-02-2022)                             ###
###                                                                       ###
###        Collection of high quality sharpeners for AviSynth+            ###
###                                                                       ###
###                                                                       ###
###   bacondither:                                                        ###
###       Adaptive Sharpen                                                ###
###   Dogway:                                                             ###
###       UnsharpMask_HBD                                                 ###
###       ex_unsharp                                                      ###
###       ex_CAS                                                          ###
###       NVSharpen                                                       ###
###   Didée:                                                              ###
###       ex_ContraSharpening                                             ###
###       SeeSaw                                                          ###
###       SeeSawMulti                                                     ###
###       FineSharp                                                       ###
###       NonlinUSM                                                       ###
###       SlopeBend                                                       ###
###       DetailSharpen                                                   ###
###       MedianSharp                                                     ###
###       LSFmod -LaTo's mod of Didée's LSF- (external EX/MIX mods)       ###
###   *.mp4 guy:                                                          ###
###       SSSharpFaster                                                   ###
###       SSSharp                                                         ###
###       ReCon                                                           ###
###       blah                                                            ###
###       MedSharp                                                        ###
###   feisty2:                                                            ###
###       Plum                                                            ###
###       DelicateSharp                                                   ###
###       RegularSharp                                                    ###
###   Other:                                                              ###
###       DGSharpen                                                       ###
###       SharpenComplex2 (uncredited)                                    ###
###       MultiSharpen                                                    ###
###       XSharpen                                                        ###
###       pSharpen                                                        ###
###       CASm                                                            ###
###                                                                       ###
#############################################################################
###
###
### Adaptive Sharpen (2018-04-14)
###
### Copyright (c) 2015-2021, bacondither
### All rights reserved. BSD 2 license.
###
### Redistribution and use in source and binary forms, with or without
### modification, are permitted provided that the following conditions
### are met:
### 1. Redistributions of source code must retain the above copyright
###    notice, this list of conditions and the following disclaimer
###    in this position and unchanged.
### 2. Redistributions in binary form must reproduce the above copyright
###    notice, this list of conditions and the following disclaimer in the
###    documentation and/or other materials provided with the distribution.
###
### THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR
### IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
### OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
### IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
### INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
### NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
### DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
### THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
### (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
### THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###
###########################################################################
###
### The shader tries to sharpen somewhat blurry edges the most, it avoids to sharpen near-flat areas and very sharp edges.
### The outer weights of the laplace matrix is variable to mitigate ringing on relative sharp edges and to provide more sharpening on wider and blurrier edges.
###
### The final stage is a soft limiter that confines overshoots based on local near min/max values.
### Light overshoots are limited more due to it's worse appearance compared to dark undershoots in most cases.
###
###########################################################################
###
###
### Adaptive_Sharpen() - v1.7 (06-01-2022)
###
### https://forum.doom9.org/showthread.php?t=182881
###
###                        by Dogway (Jose Linares)
###
###
### AviSynth+ port of HLSL Adaptive Sharpen shader by bacondither
### Process with all threads -Prefetch(threads)- in any bitdepth ( although 32-bit is 2% faster than 16-bit).
### Internally it is partially processed in 32-bit.
### Since this is CPU based it's 7 times slower compared to the GPU shader.
###
### The premise is similar to SlopeBend() by Didée, it reads:
### "It sharpens the picture by adjusting the slope of the gradient values inbetween the local min/max interval.
###  Effectively, edges are sharpened without oversharpening (halos) (but risk to make them jaggy)."
###
### Dependencies: > AviSynth+ 3.7.1+ (https://forum.doom9.org/showthread.php?t=181351)
###                 ExTools
###
### Example: Adaptive_Sharpen(1.0)
###
###
### Function Definition:
###    (
###    clip,
###    float str=1.0 (0.3 to 2.0 by 0.1),
###    float slope=0.5 (0.0 to 2.0 by 0.01),
###    float H_over=0.765 (0.01 to 255.0 by 0.1),
###    float L_over=2.295 (0.01 to 255.0 by 0.1),
###    float H_compr_lo=0.167 (0.0 to 1.0 by 0.01),
###    float H_compr_hi=0.334 (0.0 to 1.0 by 0.01),
###    float L_compr_lo=0.250 (0.0 to 1.0 by 0.01),
###    float L_compr_hi=0.500 (0.0 to 1.0 by 0.01),
###    float scale_lim=0.1 (0.0 to 1.0 by 0.1),
###    float scale_cs=0.056 (0.0 to 1.0 by 0.01),
###    float dW_lothr=76.5 (0.0 to 255.0 by 0.5),
###    float dW_hithr=204.0 (0.0 to 255.0 by 0.5),
###    float lowthr_mxw=0.1 (0.0 to 255.0 by 0.1),
###    float pm_p=0.7 (0.0 to 1.0 by 0.1),
###    float a_offset=2.0 (0.0 to 255.0 by 0.5),
###    )
###
####################################


function Adaptive_Sharpen(clip a, float "str", float "slope", float "H_over", float "L_over", float "H_compr_lo", float "H_compr_hi", float "L_compr_lo", float "L_compr_hi", float "scale_lim", float "scale_cs", \
                                  float "dW_lothr", float "dW_hithr", float "lowthr_mxw", float "pm_p", float "a_offset", float "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    bi2 = bi
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    curve_height = Default(str,             1.0)                # Main control of sharpening strength [0.3 <-> 2.0]

    ## Defined values under this row are "optimal" DO NOT CHANGE IF YOU DO NOT KNOW WHAT YOU ARE DOING!
    curveslope   = Default(slope,         0.5  )                # Sharpening curve slope, high edge values
    L_overshoot  = Default(H_over,        0.765)                # Max light overshoot before compression [>0.001] [0-255]
    D_overshoot  = Default(L_over,        2.295)                # Max  dark overshoot before compression [>0.001] [0-255]
    L_compr_low  = Default(H_compr_lo,    0.167)                # Light compression, default (0.167=~6x)
    L_compr_high = Default(H_compr_hi,    0.334)                # Light compression, surrounded by edges (0.334=~3x)
    D_compr_low  = Default(L_compr_lo,    0.250)                # Dark compression, default (0.250=4x)
    D_compr_high = Default(L_compr_hi,    0.500)                # Dark compression, surrounded by edges (0.500=2x)
    scale_lim    = Default(scale_lim,     0.1  )                # Abs max change before compression [>0.01]
    scale_cs     = Default(scale_cs,      0.056)                # Compression slope above scale_lim
    dW_lothr     = Default(dW_lothr,      76.5 )                # Start interpolating between W1 and W2
    dW_hithr     = Default(dW_hithr,      204.0)                # When dW is equal to W2
    lowthr_mxw   = Default(lowthr_mxw,    0.1  )                # Edge value for max lowthr weight [>0.01]
    pm_p         = Default(pm_p,          0.7  )                # Power mean p-value [>0-1.0]
    a_offset     = Default(a_offset,      2.0  )                # Edge channel offset, MUST BE THE SAME IN ALL PASSES [0-255]
    UV           = Default(UV,      rgb ? 3 : 1)
    si           = ex_UVf(rgb, bi)

    r_max1   = 1. / ex_bs(255,    8, bi, fulls=fs)
    r_max    = bi == 32 ? "" : Format("{r_max1} *")
    f_max    = bi == 32 ? "" : Format("range_max *")
    a_epsb   = ex_bs(2.55,        8, bi, fulls=fs, flt=true)
    a_eps    = ex_bs(2.55,        8, 32, fulls=fs)
    a_offset = ex_bs(a_offset,    8, 32, fulls=fs)
    a_off_ep = a_offset - a_eps
    lthr_m   = ex_bs(lowthr_mxw,  8, 32, fulls=fs)
    lthr_r   = (1. / (0.1 - 0.01))   # (~10 * r_max)
    sbe_h    = ex_bs(216.75,      8, 32)
    sbe_m    = ex_bs(14.28,       8, 32, fulls=fs) - a_offset * 3
    sbe_l    = ex_bs(7.65,        8, 32)
    sd_off   = ex_bs(5.1,         8, 32, fulls=fs)
    L_over   = ex_bs(L_overshoot, 8, 32)
    D_over   = ex_bs(D_overshoot, 8, 32)
    dW_lothr = ex_bs(dW_lothr,    8, 32, fulls=fs)
    dW_hithr = ex_bs(dW_hithr,    8, 32, fulls=fs)
    dW       = 1. / (dW_hithr - dW_lothr)

    # Labels
    Transition_to_a_concave_kernel_if_the_center_edge_val_is_above_thr = ""
    Precalculated_default_squared_kernel_weights = ""
    Calc_weights__Use_lower_weights_for_pixels_in_a_more_active_area_relative_to_center_pixel_area = ""
    This_results_in_narrower_and_less_visible_overshoots_around_sharp_edges = ""
    Calculate_the_negative_part_of_the_laplace_kernel_and_the_low_threshold_weight = ""
    neg_laplace_div_weightsum___new_neg_laplace = ""
    sharpen_val__Compute_sharpening_magnitude_function = ""
    Calculate_local_near_min_n_max__partial_sort_order_0_1_2_22_23_24 = ""
    mindist__Calculate_tanh_scale_factors = ""
    Allow_for_higher_overshoot_if_the_current_edge_pixel_is_surrounded_by_similar_edge_pixels = ""
    Soft_limited_antiringing_with_tanh__wpmean_to_control_compression_slope = ""

    # Custom weighted DoG edge detection
    edge = Format("x[0,0] A@ 2 * x[0,1] B@ x[0,-1] E@ x[1,0] D@ x[-1,0] C@ + + + + 2 * x[-1,1] J@ x[-1,-1] K@ x[1,1] L@ x[1,-1] M@ + + + + 0.0625 *
                   S@ x[0,2] - abs S x[0,-2] - abs S x[2,0] - abs S x[-2,0] - abs + + + 0.23 *
                   S  J      - abs S K       - abs S L      - abs S M       - abs + + + 0.92 * +
                   S  B      - abs S E       - abs S D      - abs S C       - abs + + + 1.15 * +
                                                                  S A       - abs       1.38 * +
                   "+r_max+" 0.65 ^ 2 S {r_max1} -2.466666681 1.442695040888963 * * * ^ 0.90 * 0.266666666 + 1 min * "+f_max+" {a_epsb} +")

    cstr = ex_UVexpr(    edge, UV, bi, rgb, fs, si)
    edge = ex_dlut  (    edge,     bi,      fs)
    edge = isy ? Expr(a, edge                       , optSingleMode=false) : \
      UV == 1  ? Expr(a, edge, ""                   , optSingleMode=false) : \
                 Expr(a, edge, cstr, scale_inputs=si, optSingleMode=false)

    edge = edge.ConvertBits(32,fulls=true)
    a    =    a.ConvertBits(32,fulls=fs)
    bi   =    32


    # Similar Bound Edge (soft_if(), fast linear approx)
    sbe = Format("
           x[-1,1] A@ x[0,1]  B@ max x[1,1] C@ x[-1,0] D@ max max x[1,0] E@ x[-1,-1] F@ max x[0,-1] G@ x[1,-1] H@ max max max
           x[0,2]  I@ x[-2,0] J@ max x[2,0] K@ x[0,-2] L@ max max x[0,0] X@ max max {sbe_l} + 1 swap / M^
           x[0,3]   I        B  {sbe_m} + + + M * {sbe_h} -
           x[0,-3]  G        L  {sbe_m} + + + M * {sbe_h} - *
           x[-3,0]  J        D  {sbe_m} + + + M * {sbe_h} -
           x[3,0]   E        K  {sbe_m} + + + M * {sbe_h} - * +
           x[-1,2]  x[-2,1]  A  {sbe_m} + + + M * {sbe_h} -
           x[2,-1]  x[1,-2]  H  {sbe_m} + + + M * {sbe_h} - * +
           x[1,2]   x[2,1]   C  {sbe_m} + + + M * {sbe_h} -
           x[-2,-1] x[-1,-2] F  {sbe_m} + + + M * {sbe_h} - * +
           2 - 0.909090909 * 0 1 clip dup dup * swap 2 * 3 swap - * ")

    cstr = ex_UVexpr(       sbe, UV, 32, rgb, fs, si)
    sbe  = ex_dlut  (       sbe,     32,      fs)
    sbe  = isy ? Expr(edge, sbe                       , optSingleMode=false) : \
      UV == 1 ?  Expr(edge, sbe, ""                   , optSingleMode=false) : \
                 Expr(edge, sbe, cstr, scale_inputs=si, optSingleMode=false)


    # Sharp difference
    sharpdiff = Format("
                       x[0,0] dup dup dup dup dup dup dup
                              x[0,1]   B@ - abs
                       swap7  x[-1,0]  C@ - abs
                       swap6  x[1,0]   D@ - abs
                       swap5  x[0,-1]  E@ - abs + + +
                       swap4  x[-1,1]  J@ - abs
                       swap3  x[1,1]   L@ - abs
                       swap2  x[-1,-1] K@ - abs
                       swap   x[1,-1]  M@ - abs + + + 0.25 * + 3 * {sd_off} + A^

                  "+Transition_to_a_concave_kernel_if_the_center_edge_val_is_above_thr+"
                y {a_offset} {dW_lothr} + - {dW} * 0 1 clip
                  "+Precalculated_default_squared_kernel_weights+"
                dup dup * swap 2 * 3 swap - * Z^
                Z dup 1 swap - + dup * Y^

                  "+Calc_weights__Use_lower_weights_for_pixels_in_a_more_active_area_relative_to_center_pixel_area+"
                  "+This_results_in_narrower_and_less_visible_overshoots_around_sharp_edges+"
                       J  dup dup dup dup dup
                             x[-1,2]     - abs
                       swap5 x[-2,1] N@  - abs
                       swap4          B  - abs
                       swap3          C  - abs + + +
                       swap2 x[0,2]  F@  - abs T@
                       swap  x[-2,0] I@  - abs W@ + 0.5 * + A swap / Y min C0^

                       L  dup dup dup dup dup
                             x[1,2]  O@  - abs
                       swap5 x[2,1]  P@  - abs
                       swap4         B   - abs
                       swap3         D   - abs + + +
                       swap2         F   - abs U@
                       swap  x[2,0]  H@  - abs V@ + 0.5 * + A swap / Y min C2^

                       K  dup dup dup dup dup
                             x[-1,-2]    - abs
                       swap5 x[2,-1] Q@  - abs
                       swap4         E   - abs
                       swap3         C   - abs + + +
                       swap2 x[0,-2] G@  - abs JJ@
                       swap          I   - abs LL@ + 0.5 * + A swap / Y min C5^

                       M  dup dup dup dup dup
                             x[1,-2] R@  - abs
                       swap5         Q   - abs
                       swap4         E   - abs
                       swap3         D   - abs + + +
                       swap2         G   - abs KK@
                       swap          H   - abs MM@ + 0.5 * + A swap / Y min C7^

                Z dup 0.54772255751 * swap 1 swap - 1.41421356237 * + dup * ZZ^

                       F dup dup dup  O  - abs
                       swap3          N  - abs
                       swap2          B  - abs
                       swap  x[0,3]      - abs + + +
                                      T
                                      U + 0.5 * + A swap / ZZ min C8^

                       I dup dup dup
                             x[-2,-1] S@ - abs
                       swap3          N  - abs
                       swap2          C  - abs
                       swap  x[-3,0]     - abs + + +
                                      W
                                      LL + 0.5 * + A swap / ZZ min C10^

                       G dup dup dup  R  - abs
                       swap3          S  - abs
                       swap2          E  - abs
                       swap  x[0,-3]     - abs + + +
                                      JJ
                                      KK + 0.5 * + A swap / ZZ min C9^

                       H dup dup dup  Q - abs
                       swap3          P - abs
                       swap2          D - abs
                       swap x[3,0]      - abs + + +
                                      V
                                      MM + 0.5 * + A swap / ZZ min C11^

                C8  C9  0.25 *       + C0 max 0.25 max C0 + 0.5 * C0^
                C8  C10 0.25 *       + C2 max 0.25 max C2 + 0.5 * C2^
                C9  C11 0.25 * C11q@ + C5 max 0.25 max C5 + 0.5 * C5^
                C10 C11q             + C7 max 0.25 max C7 + 0.5 * C7^

                Z dup 0.86602540378 * swap 1 swap - 0.5 * + dup * X^

                  "+Calculate_the_negative_part_of_the_laplace_kernel_and_the_low_threshold_weight+"
                y[-1,1]  C0  * WA@ a[-1,1]  *
                y[0,1]   X   * WB@ a[0,1]   * +
                y[1,1]   C2  * WC@ a[1,1]   * +
                y[-1,0]  X   * WD@ a[-1,0]  * +
                y[1,0]   X   * WE@ a[1,0]   * +
                y[-1,-1] C5  * WF@ a[-1,-1] * +
                y[0,-1]  X   * WG@ a[0,-1]  * +
                y[1,-1]  C7  * WH@ a[1,-1]  * +
                y[0,2]   C8  * WI@ a[0,2]   * +
                y[-2,0]  C9  * WJ@ a[-2,0]  * +
                y[2,0]   C10 * WK@ a[2,0]   * +
                y[0,-2]  C11 * WL@ a[0,-2]  * +

                  "+neg_laplace_div_weightsum___new_neg_laplace+"
                WA WB WC WD WE WF WG WH WI WJ WK WL + + + + + + + + + + + / abs 0.416666666 ^ 0.06 -")


    eexp = ex_lut(edge,Format("x {a_offset} - {lthr_r} * 1 min dup dup 1.98 * 2.97 swap - * * 0.01 +"), UV=uv)
    a2   = ex_lut(a,          "x 0.06 + 2.4 ^",                                                         UV=uv)

    cstr      = ex_UVexpr(                    sharpdiff, UV, bi, rgb, fs, si)
    sharpdiff = isy ? Expr(a, eexp, edge, a2, sharpdiff                       , optSingleMode=false) : \
            UV == 1 ? Expr(a, eexp, edge, a2, sharpdiff, ""                   , optSingleMode=false) : \
                      Expr(a, eexp, edge, a2, sharpdiff, cstr, scale_inputs=si, optSingleMode=false)

    # Mean blur of eexp with 'circle' kernel
    eexp      = ex_luts(eexp, mode="avg", pixels=ex_shape(2,mode="circle",center=false), UV=uv)

    sharpen_val = Format("
                  "+sharpen_val__Compute_sharpening_magnitude_function+"
                  z {a_offset} - abs 3.5 ^ {curveslope} {curve_height} * * 0.625 + {curve_height} swap /
                  y * 0.01 + x a - * ")

    cstr      = ex_UVexpr(                           sharpen_val, UV, bi, rgb, fs, si)
    sharpdiff = isy ? Expr(a, eexp, edge, sharpdiff, sharpen_val                       , optSingleMode=false) : \
            UV == 1 ? Expr(a, eexp, edge, sharpdiff, sharpen_val, ""                   , optSingleMode=false) : \
                      Expr(a, eexp, edge, sharpdiff, sharpen_val, cstr, scale_inputs=si, optSingleMode=false)


    # Soft limiter. Anti-ringing block
    sharp = Format("
            "+Calculate_local_near_min_n_max__partial_sort_order_0_1_2_22_23_24+"
            x[0,3]   x[-1,2]      dup1 dup1 min W^ max Y^
            x[0,2]   x[1,2]       dup1 dup1 min Q^ max X^
            x[-2,1]  x[-1,1]      dup1 dup1 min G^ max V^
            x[0,1]   x[1,1]       dup1 dup1 min H^ max U^
            x[2,1]   x[-3,0]      dup1 dup1 min E^ max T^
            x[-2,0]  x[-1,0]      dup1 dup1 min F^ max S^
            x[0,0]   x[1,0]       dup1 dup1 min P^ max R^
            x[2,0]   x[3,0]       dup1 dup1 min N^ max O^
            x[-2,-1] x[-1,-1]     dup1 dup1 min L^ max M^
            x[0,-1]  x[1,-1]      dup1 dup1 min I^ max K^
            x[2,-1]  x[-1,-2]     dup1 dup1 min C^ max J^
            x[0,-2]  x[1,-2]      dup1 dup1 min B^ max D^
            V Y                   dup1 dup1 min V^ max Y^
            J X                   dup1 dup1 min J^ max X^
            G W                   dup1 dup1 min G^ max W^
            M U                   dup1 dup1 min M^ max U^
            D T                   dup1 dup1 min D^ max T^
            O S                   dup1 dup1 min O^ max S^
            K R                   dup1 dup1 min K^ max R^
            C Q                   dup1 dup1 min C^ max Q^
            I P                   dup1 dup1 min I^ max P^
            F N                   dup1 dup1 min F^ max N^
            H L                   dup1 dup1 min H^ max L^
            B E                   dup1 dup1 min B^ max E^
            U Y                   dup1 dup1 min U^ max Y^
            R X                   dup1 dup1 min R^ max X^
            L W                   dup1 dup1 min L^ max W^
            M V                   dup1 dup1 min M^ max V^
            S T                   dup1 dup1 min S^ max T^
            K Q                   dup1 dup1 min K^ max Q^
            J P                   dup1 dup1 min J^ max P^
            D O                   dup1 dup1 min D^ max O^
            E N                   dup1 dup1 min E^ max N^
            C I                   dup1 dup1 min C^ max I^
            G H                   dup1 dup1 min G^ max H^
            B F                   dup1 dup1 min B^ max F^
            T Y                   dup1 dup1 min T^ max Y^
            N W                   dup1 dup1 min N^ max W^
            S V                   dup1 dup1 min S^ max V^
            O U                   dup1 dup1 min O^ max U^
            I R                   dup1 dup1 min I^ max R^
            P Q                   dup1 dup1 min P^ max Q^
            D M                             min D^
            F L                   dup1 dup1 min F^ max L^
            J K                   dup1 dup1 min J^ max K^
            E H                   dup1 dup1 min E^ max H^
            B G                   dup1 dup1 min B^ max G^
            R W                   dup1 dup1 min R^ max W^
            P S                                    max S^
            N Q                                    max Q^
            K x[0,-3]             dup1 dup1 min A^ max K^
            D G                   dup1 dup1 min D^ max G^
            Q V                                    max V^
            O R                             min O^
            K L                                    max L^
            D J                             min D^
            E G                   dup1 dup1 min E^ max G^
            A C                   dup1 dup1 min A^ max C^
            L U                   dup1 dup1 min L^ max U^
            I O                             min I^
            A G                             min A^
            C F                             min C^
            U X                   dup1 dup1 min U^ max X^
            H L                                    max L^
            E I                             min E^
            A B                   dup1 dup1 min A^ max B^
            X Y                   dup1 dup1 min X^ max Y^
            T U                                    max U^
            L S                                    max S^
            D E                   dup1 dup1 min D^ max E^
            B C                   dup1 dup1 min B^ max C^
            S W                                    max W^
            U V                   dup1 dup1 min U^ max V^
            C E                             min C^
            B D                   dup1 dup1 min B^ max D^
            W X                   dup1 dup1 min W^ max X^
            C D                             min C^
            V X                   dup1 dup1 min V^ max X^
            V U W                              max max W^

            W X 2 * + x 3 * X3@ max Y + 0.25 * M^
            C B 2 * + X3        min A + 0.25 * N^

            "+mindist__Calculate_tanh_scale_factors+"
            M x - abs x N - abs     min D^
            1.0001 D - x - {L_over} min D + P^
            0.0001 D - x + {D_over} min D + N^

            1 {scale_cs} - {scale_lim} * P {scale_cs} * + P min P^
            1 {scale_cs} - {scale_lim} * N {scale_cs} * + N min N^

            "+Allow_for_higher_overshoot_if_the_current_edge_pixel_is_surrounded_by_similar_edge_pixels+"
            {L_compr_high} {L_compr_low} - z * {L_compr_low} + CX@ y 0 max Y@ dup {pm_p} ^ swap swap2 *
            "+Soft_limited_antiringing_with_tanh__wpmean_to_control_compression_slope+"
            swap P 24 * min 2 * P / "+expT(3)+" dup 1 - swap 1 + / P *
            abs {pm_p} ^ 1 CX - abs * + 1 {pm_p} / ^

            {D_compr_high} {D_compr_low} - z * {D_compr_low} + CY@ Y 0 min    dup {pm_p} ^ swap swap2 *
            swap N 24 * min 2 * N / "+expT(3)+" dup 1 - swap 1 + / N *
            abs {pm_p} ^ 1 CY - abs * + 1 {pm_p} / ^ -

            x + ")

            cstr    = ex_UVexpr(              sharp, UV, bi, rgb, fs, si)
            isy     ? Expr(a, sharpdiff, sbe, sharp                       , optSingleMode=false) : \
            UV == 1 ? Expr(a, sharpdiff, sbe, sharp, ""                   , optSingleMode=false) : \
                      Expr(a, sharpdiff, sbe, sharp, cstr, scale_inputs=si, optSingleMode=false)
                      bi2 != 32 ? ConvertBits(bi2, dither=1, fulls=fs)    : last               }




#######################
###                 ###
###     Dogway's    ###
###                 ###
#######################

######################################################
###
###  ex_unsharp()    by Dogway (26-10-2021)
###
### Replacement and practical match to variableblur's unsharp()...
### ...but with 20% of sharpness weight from a discreet lower frequency cutoff for structural support.
### Replaces WarpSharp's unsharpmask, UnsharpHQ, UnsharpMask_avsi and VariableBlur's Unsharp.
###
### The Fc argument allows to sharpen on a subpixel or macropixel basis.
### Good values span from 1920 for a 1080p clip, to width()*1.5 or *2.0.
###
### Benchmark:
### 100% UnsharpMask_HBD(128*n,1,0) (344 fps)
###  91% ex_unsharp(1, Fc=width())
###   8% unsharp(vary=1, varc=1, strength=1) # no HBD support, % scaled down
###
### Equivalences:
### unsharpmask(strength=str,radius=rad,threshold=0) --> ex_unsharp(str=str*0.007,                        Fc=width()/max(1,0.76*exp(0.26*rad),th=0)
### unsharp    (strength=str,vary=rad)               --> ex_unsharp(str=str/(1.489*pow(rad,-1.112)+0.51), Fc=width()*0.8,                     th=0)
### Internal Sharpen(0.75)            roughly matches    ex_unsharp(2.5,width()*1.5,0,UV=3)
###
###
### Function Definition:
###    (
###    clip,
###    float str=1.0 (-1.0 to 2.0 by 0.1),
###    float strv=1.0 (-1.0 to 2.0 by 0.1),
###    float Fc=1920.0 (0.0 to 1920.0 by 1.0),
###    float thr=0.0 (0.0 to 255.0 by 1.0),
###    )
###
function ex_unsharp(clip a, float "str", float "strv", float "Fc", float "th", int "Y", int "UV") {

    rgb   = isRGB(a)
    isy   = isy(a)
    bi    = BitsPerComponent(a)
    fulls = propNumElements (a,"_ColorRange")  > 0 ? \
            propGetInt      (a,"_ColorRange") == 0 : rgb

    w     = a.width()
    h     = a.height()
    Fs    = max(w,h)*2.

    strh  = Default(str,     1)        # Use negative values for frequency based blurring (deconvolution), works up to a certain extent (up to -0.5)
    strv  = Default(strv, strh)
    Fc    = Default(Fc,  Fs/2.)        # Frequency cutoff in Hz for sharpening, by default same to sample rate (ie 1920Hz for 1080p, or 1 pixel accuracy)

    Fc    = (Fs/Fc)
    rad   = ceil(Fc)-1

    th    = Default(th,           0)   # Good values are 1, 2 or 3
    Y     = Default( Y,           3)
    UV    = Default(UV,    rgb  ? 3 : 1)
    dcnv1 = strv < 0
    dcnv2 = strh < 0
    strv  = abs(strv)
    strh  = abs(strh)
    fs    = fulls
    th    = ex_bs(th, 8, bi, fulls=fs, flt=true)

    krnlsz = ceil(2 * max(rad,1))
    krnlrd = krnlsz/2

    krnh = ""  krnv = "" plsh = ""  plsv = ""  divx=0  divy=0

        for (px = -krnlrd, krnlrd, 1) {
            krnh = Format(krnh + "x[{px},0] ")
            plsh = px == -krnlrd ? plsh : plsh + "+ "
            divx = divx + 1
           }

        for (py = -krnlrd, krnlrd, 1) {
            krnv = Format(krnv + "x[0,{py}] ")
            plsv = py == -krnlrd ? plsv : plsv + "+ "
            divy = divy + 1
           }

    krnlsz2 = ceil(2 * (max(rad,1) + 1))
    krnlrd2 = krnlsz2/2

    krnh2 = ""  krnv2 = "" plsh2 = ""  plsv2 = ""  divx2=0  divy2=0

        for (px2 = -krnlrd2, krnlrd2, 1) {
            krnh2 = abs(px2) <= krnlrd ? krnh2 : Format(krnh2 + "x[{px2},0] ")
            plsh2 = abs(px2) <= krnlrd || px2 == -krnlrd2 ? plsh2 : plsh2 + "+ "
            divx2 = divx2 + 1
           }

        for (py2 = -krnlrd2, krnlrd2, 1) {
            krnv2 = abs(py2) <= krnlrd ? krnv2 : Format(krnv2 + "x[0,{py2}] ")
            plsv2 = abs(py2) <= krnlrd || py2 == -krnlrd2 ? plsv2 : plsv2 + "+ "
            divy2 = divy2 + 1
           }

    dcnv1 = dcnv1 ? "" : "swap"
    dcnv2 = dcnv2 ? "" : "swap"
    strd  = strh != strv
    th1   = !strd ? "" : "x "+dcnv1+" - " + (th > 0 ? Format("{strv} * A@ abs {th} > A x + x ?") : Format("{strv} * x +"))
    th2   = !strd ?      "y "+dcnv2+" - " + (th > 0 ? Format("{strh} * A@ abs {th} > A y + y ?") : Format("{strh} * y +")) : \
                         "x "+dcnv2+" - " + (th > 0 ? Format("{strh} * A@ abs {th} > A x + x ?") : Format("{strh} * x +"))
    strv1 = krnv  + plsv  + " Z@ "  + string((1./divy) *0.8) + " * "
    strh1 = krnh  + plsh  + " Z@ "  + string((1./divx) *0.8) + " * "
    strv2 = krnv2 + " Z + " + plsv2 + string((1./divy2)*0.2) + " * + "
    strh2 = krnh2 + " Z + " + plsh2 + string((1./divx2)*0.2) + " * + "

    strvf = strv1 + strv2 + th1
    strhf = strh1 + strh2 + th2

    a     = Fc < 2.0 ? a.blackmanresize(nmod(w*(2./Fc),2),nmod(h*(2./Fc),2)) : a    # replace with butterworth fractional rad (n=300 or so) for subpixel sharpening

    ystrv = ex_Yexpr (strvf, Y, bi, rgb, fs)
    ystrh = ex_Yexpr (strhf, Y, bi, rgb, fs)

    strv==0 ?      a                                                                       : \
    isy     ? Expr(a,       ystrv                                                        ) : \
    UV == 1 ? Expr(a,       ystrv, ""                                                    ) : \
              Expr(a,       ystrv, ex_UVexpr(strvf, UV, bi, rgb, fs), scale_inputs="none")
    strd    ?                                                                                \
    strh==0 ?      last                                                                    : \
    isy     ? Expr(last,    ystrh                                                        ) : \
    UV == 1 ? Expr(last,    ystrh, ""                                                    ) : \
              Expr(last,    ystrh, ex_UVexpr(strhf, UV, bi, rgb, fs), scale_inputs="none") : \
    isy     ? Expr(last, a, ystrh                                                        ) : \
    UV == 1 ? Expr(last, a, ystrh, ""                                                    ) : \
              Expr(last, a, ystrh, ex_UVexpr(strhf, UV, bi, rgb, fs), scale_inputs="none")

    Fc < 2.0 ? bicubicresize(w,h,-0.6,0.4) : last }



# Port and optimization of UnsharpMask_avsi.avsi by real.finder (84% faster with rad<3)

function UnsharpMask_HBD(clip clp, float "str", int "rad", float "thres", int "UV") {

    bi  = BitsPerComponent(clp)
    rgb = isRGB(clp)

    str    = Default(str,   128)
    rd     = Default(rad,    1)
    thres  = Default(thres,  0)
    UV     = Default(UV,    rgb ? 3 : 1)

    rd     = max(rd - 1, 1)
    str    = str/128.
    thres  = ex_bs(thres, 8, bi, fulls=rgb, flt=true)

    blurclip = rd == 1 ? clp.removegrain(20, UV == 3 ? 20 : -1) : \
                         clp.ex_boxblur(rd, mode="mean", UV=UV)

    ex_lutxy(clp, blurclip, thres > 0 ? Format("x y - A@ abs {thres} > A {str} * x + x ?") : "x dup y - +", UV=UV) }



/*
// LICENSE
// =======
// Copyright (c) 2017-2019 Advanced Micro Devices, Inc. All rights reserved.
// -------
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// -------
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
// -------
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE
*/
#
# ex_CAS - by Dogway (19-10-2021)
#
# AviSynth+ port of AMD's "CAS" (Contrast Adaptive Sharpening) sharpener: https://gpuopen.com/fidelityfx-cas/
# Performs 10% slower with Prefetch(6) than Asd-g's AVS+ port of VapourSynth plugin.
#
function ex_CAS(clip a, float "strength", int "UV") {

    rgb = a.IsRGB()
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    str = Default(strength,   0.5)  # 0: no sharpening, to 1: full sharpening. Scaled by the sharpness knob while being transformed to a negative lobe (values from -1/5 to -1/8 for A=1)
    UV  = Default(UV, rgb ? 3 : 1)

    str = max(min(str, 1), 0)
    str = 1. / (8+str*(5-8))  # reciprocal of lerp

    do  = 2. * ex_bs(255, 8, bi, fulls=fs)

    ex_lut(a, Format("x[-1,0] D@ x[0,0] E@ max x[1,0] F@ max x[0,-1] B@ max x[0,1] H@ max dup x[-1,-1] A@ max x[1,-1] C@ max x[-1,1] G@ max x[1,1] I@ max + M^
                              D         E  min        F  min         B  min        H  min dup          A  min         C  min         G  min        I  min +
                        {do} M - min M / sqrt -{str} * dup B D F H + + + * E + swap 4 * 1 + /"), UV=UV, fulls=fs) }


/*
// The MIT License(MIT)
//
// Copyright(c) 2021 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files(the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and / or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
#
# NVSharpen - by Dogway (11-12-2021)
#
# AviSynth+ port of NVidias's 'NIS Sharpen' sharpener: https://github.com/NVIDIAGameWorks/NVIDIAImageScaling/tree/main/NIS
#
function NVSharpen(clip a, float "str", float "th", float "rat", float "boost", float "start", float "end", int "UV") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    str = Default(str,        0.5)  # 0: no sharpening, to 1: full sharpening.
    UV  = Default(UV, rgb ? 3 : 1)

    sharpness = max(min(1.0, str), 0)
    sharpen_slider = sharpness - 0.5   # Map 0 to 1 to -0.5 to +0.5

    # Different range for 0 to 50% vs 50% to 100%
    # The idea is to make sure sharpness of 0% map to no-sharpening,
    # while also ensuring that sharpness of 100% doesn't cause too much over-sharpening.
    MaxScale   = (sharpen_slider >= 0.0) ? 1.25 : 1.75 # only used for HDR
    MinScale   = (sharpen_slider >= 0.0) ? 1.25 : 1.0
    LimitScale = (sharpen_slider >= 0.0) ? 1.25 : 1.0

    kDetectRatio      = Default(rat, 1127 / 1024.) # 1.0 - 2.0 (Default: 1.1)

    # Params for SDR
    kDetectThres      = Default(th, 16.)    # 0.0 - 255.0 (Default: 16.)
    kDetectThres      = ex_bs(kDetectThres, 8, 32, fs)
    kMinContrastRatio = 2
    kMaxContrastRatio = 10
    kContrastBoost    = Default(boost, 1.0)
    kRatioNorm        = 1.0 / (kMaxContrastRatio - kMinContrastRatio)

    kSharpStartY      = Default(start, 0.45)
    kSharpEndY        = Default(end,   0.9)
    kSharpStrengthMin = max(0.0, 0.4 + sharpen_slider * MinScale * 1.2)
    kSharpStrengthMax = 1.6 + sharpen_slider * 1.8
    kSharpLimitMin    = max(0.1, 0.14 + sharpen_slider * LimitScale * 0.32)
    kSharpLimitMax    = 0.5 + sharpen_slider * LimitScale * 0.6
    kSharpLimitScale  = kSharpLimitMax - kSharpLimitMin
    kSharpStrengthScale = kSharpStrengthMax - kSharpStrengthMin
    kSharpScaleY      = 1.0 / (kSharpEndY - kSharpStartY)

    KEps = 1 # 0.001 for HDR
    eps  = KEps*1/255. # 0.004 for SDR, but I see that 0.1 works better though
    con  = kMinContrastRatio

    # Labels
    Limiting1 = ""    Unsharp_mul_Limiting   = ""    Unsharp_mul_Gradient   = ""
    Limiting2 = ""    Gradient  = ""

    str = Format("f32
                  x[-1,-1] A^ x[0,-1] B^ x[1,-1] C^
                  x[-1,0]  D^ x[0,0]  X^ x[1,0]  F^
                  x[-1,1]  G^ x[0,1]  H^ x[1,1]  I^

                  "+Limiting2+"
                  x[-2,0] J@ D max X max  J D min X min -
                  X F max x[2,0]  K@ max  X F min K min -
                  dup1 dup1 max swap2 min {eps} + / {con} {kRatioNorm} * - 0 1 clip 1 swap - {kContrastBoost} * L1^


                  x[0,-2] J@ B max X max  J B min X min -
                  X H max x[0,2]  K@ max  X H min K min -
                  dup1 dup1 max swap2 min {eps} + / {con} {kRatioNorm} * - 0 1 clip 1 swap - {kContrastBoost} * L2^


                  A D B + 0.5 * DB@ max X max  A DB min X min -
                  X F H + 0.5 * FH@ max I max  X FH min I min -
                  dup1 dup1 max swap2 min {eps} + / {con} {kRatioNorm} * - 0 1 clip 1 swap - {kContrastBoost} * L3^


                  C B F + 0.5 * BF@ max X max  C BF min X min -
                  X D H + 0.5 * DH@ max G max  X DH min G min -
                  dup1 dup1 max swap2 min {eps} + / {con} {kRatioNorm} * - 0 1 clip 1 swap - {kContrastBoost} * L4^

                  "+Limiting1+"
                  1   {kSharpStartY} x - {kSharpScaleY} * 0 1 clip - dup
                      {kSharpStrengthScale} * {kSharpStrengthMin} +     STR^
                      {kSharpLimitScale}    * {kSharpLimitMin}    + x * LIM^

                  "+Unsharp_mul_Limiting+"
                  X 1.2 * X@ D F                + 0.6 * - STR * LIM neg LIM clip L1 * USM1^
                  X          B H                + 0.6 * - STR * LIM neg LIM clip L2 * USM2^
                  X          I BF DH + 0.5 * S@ + 0.6 * - STR * LIM neg LIM clip L3 * USM3^
                  X          G S                + 0.6 * - STR * LIM neg LIM clip L4 * USM4^

                  "+Gradient+"
                  A D G + + C - F - I - abs W@
                  A B C + + G - H - I - abs dup1 dup1 max M^ min N^
                  A B D + + F - H - I - abs Y@
                  B C F + + D - G - H - abs dup1 dup1 max D^ min E^

                  M D + MD@ 0 == Q@
                    0 M MD / 1 min ? e_0_90^
                  Q 0 1 e_0_90 - ? e_45_135^

                  D E {kDetectRatio} * > D {kDetectThres} > & D N > & Q^
                  D Y == T@ Q 1 0 ? 0 ? T Q 0 1 ? 0 ? e_135^ e_45^

                  M N {kDetectRatio} * > M {kDetectThres} > & M E > & Q^
                  M W == T@ Q 1 0 ? 0 ? T Q 0 1 ? 0 ? e_90@ swap e_0@

                  "+Unsharp_mul_Gradient+"
                  e_45 e_135 + + + S@ 1 >= T2^
                  S 2 >= Q^
                      e_0  1 == T@ Q e_0_90   T2 e_0   0 ? T0@ ? Q 0         T0 ? ? USM1 *
                                T  Q        0 T2 e_90  0 ? T9@ ? Q e_0_90    T9 ? ? USM2 * +
                      e_45 1 == T@ Q e_45_135 T2 e_45  0 ? T4@ ? Q 0         T4 ? ? USM3 * +
                                T  Q        0 T2 e_135 0 ? T3@ ? Q e_45_135  T3 ? ? USM4 * + x +")


    ex_lut(a, str, UV=uv, fulls=fs, scale_inputs=fs ? "intf" : "int") }






#######################
###                 ###
###     DIDÉE's     ###
###                 ###
#######################

######################################################
###
###  Contra()                   (15 Dec 2007) by Didée
###
###  https://forum.doom9.org/showthread.php?p=1076276#post1076276
###  https://forum.doom9.org/showthread.php?p=1076491#post1076491
###
###  ex_ContraSharpening() v3.5 (12 Dec 2021)
###  - Mod and port to ExTools by Dogway
###
###
### Contra(): sharpen the denoised clip, but don't add more to any pixel than what was removed previously.
### Enable 'MC' (default false) for temporal limiting sharpening versus the default spatial limiting. (Requires motion vectors globals)
###
### In final version 2.0d ContraHD() was merged, to allow proper HD sharpening.
### When using 'MC' (temporal limiting) global variables of (before denoising), source MSuper and forward and
### backward compensated motion vectors are necessary as: Super, cb1 and cf1, if used as a standalone function.
### Don't know who made (mod) it, so I can't give proper credits, sorry.

function ex_ContraSharpening(clip denoised, clip original, bool "HD", bool "MC", int "overshoot") {

    rgb = isRGB(denoised)
    bi  = BitsPerComponent(denoised)
    fs  = propNumElements (denoised,"_ColorRange")  > 0 ? \
          propGetInt      (denoised,"_ColorRange") == 0 : rgb

    HD  = Default(HD,    false)
    MC  = Default(MC,    false)  # Enable to switch from spatial to temporal limiting (output a bit sharper than original though)
    os  = Default(overshoot, 0)  # Raise to allow more sharpening (over/undershoots) when temporal limiting (MC=true). Also required if 'original' is too noisy

    os  = ex_bs(os, 8, bi, fulls=fs)

    isg = MC ? VarExist("cb1") && VarExist("cf1") : false   # if MC=true; reuse motion vector frames if created (in SMDegrain or elsewhere with same global var name)
    isc = MC ? VarExist("b1c") && VarExist("f1c") : false   # if MC=true; reuse compensated   frames if created (in SMDegrain or elsewhere with same global var name)


    s   = denoised.ex_MinBlur(HD?2:1,UV=1)                                                                    # Damp down remaining spots of the denoised clip.
    ssD = ex_makediff(s,HD?s.removegrain(12,-1).\
                             removegrain(20,-1):\
                           s.removegrain(12,-1),UV=1,fulls=fs)                                                # The difference of a simple kernel blur.


    if (!(MC && (isg || isc))) {

        allD = ex_makediff(original,denoised,UV=1,fulls=fs)                                                   # The difference achieved by the denoising.
        ssDD = ssD.repair(HD?ssD.repair(allD,1,-1):allD,1,-1)                                                 # Limit the difference to the max of what the denoising removed locally.
        ex_lutxyz (denoised,ssDD,ssD,"y range_half - Y@ abs z range_half - Z@ abs < Y Z ? x +",UV=1,fulls=fs) # abs(diff) after limiting may not be bigger than before.
                                                                                                              # Apply the limited difference " x +" (Sharpening is just inverse blurring)
    } else {

        cb1  = isc ? b1c.ConvertBits(bi, fulls=fs) : original.MCompensate(Super, cb1, mt=true).ConvertBits(bi, fulls=fs)
        cf1  = isc ? f1c.ConvertBits(bi, fulls=fs) : original.MCompensate(Super, cf1, mt=true).ConvertBits(bi, fulls=fs)

        addif = " x y + range_half - "
        pmax  = " z a max b max "
        pmin  = " z a min b min "
        Tlim0 =  addif+pmax+" min "+pmin+" max"
        Tlim1 =  Format(addif+pmax+" {os} + min "+pmin+" {os} - max")
        Expr(denoised, ssD, original, cb1, cf1, ex_dlut(os==0 ? Tlim0 : Tlim1, bi, fs), isy(denoised) ? Undefined() : "")

    } }




######################################################
###
###  SeeSaw v0.3i (02 Jan 2006) by Didée
###
###  https://forum.doom9.org/showthread.php?p=760935#post760935
###
###    0.3f (13 Dec 2006) by foxyshadis (port to masktools2)
###    0.3g (15 Dec 2015) by StainlessS (Force int call arguments to user script function float params to be explicit floats)
###    0.3h (31 Jan 2020) by real.finder (Update to avs+ and HBD)
###    0.3i (29 Jan 2022) by Dogway (Sanitize, port to ExTools -MIX mod-, optimize expressions, add HD support)
###
###  (Full Name: "Denoiser-and-Sharpener-are-riding-the-SeeSaw" )
###
###  This function provides a (simple) implementation of the "crystality sharpen" principle.
###  In conjunction with a user-specified denoised clip, the aim is to enhance
###  weak detail, hopefully without oversharpening or creating jaggies on strong
###  detail, and produce a result that is temporally stable without detail shimmering,
###  while keeping everything within reasonable bitrate requirements.
###  This is done by intermixing source, denoised source and a modified sharpening process,
###  in a seesaw-like manner.
###
###  Usage:
###
###  a = TheNoisySource
###  b = a.YourPreferredDenoising()
###  SeeSaw( a, b, [parameters] )
###
###  You're very much encouraged to feed your own custom denoised clip into SeeSaw.
###  If the "denoised" clip parameter is omitted, a simple "spatial pressdown" filter is used.
###
###
###  Fiddled together by Didée, for your pleasure.
###
# =======  Main function  =======

function SeeSaw( clip  input, clip "denoised",
 \               int   "NRlimit",int "NRlimit2",
 \               float "Sstr",   int "Slimit", float "Spower", float "SdampLo", float "SdampHi", float "Szp",
 \               float "bias",   int "Smode",    int "sootheT",  int "sootheS", float "ssx",     float "ssy") {


    isy = input.isy()
    clp = isy ? input : input.ExtractY()
    rgb = isRGB(input)
    bi  = BitsPerComponent(input)
    fs  = propNumElements (input,"_ColorRange")  > 0 ? \
          propGetInt      (input,"_ColorRange") == 0 : rgb

    ssx      = Default( ssx,           1.0 )      # supersampling factor x  /  SeeSaw doesn't require supersampling urgently.
    ssy      = Default( ssy,           ssx )      # supersampling factor y  /  if at all, small values ~1.25 seem to be enough.
    NRlimit  = Default( NRlimit,         2 )      # absolute limit for pixel change by denoising
    NRlimit2 = Default( NRlimit2, NRlimit+1)      # limit for intermediate denoising
    Sstr     = Default( Sstr,          1.5 )      # Sharpening strength (don't touch this too much)
    Slimit   = Default( Slimit,  NRlimit+2 )      # positive: absolute limit for pixel change by sharpening
                                                  # negative: pixel's sharpening difference is reduced to diff=pow(diff,1/abs(limit))
    Spower   = Default( Spower,          4 )      # exponent for modified sharpener
    Szp      = Default( Szp,          16+2 )      # zero point - below: overdrive sharpening - above: reduced sharpening
    SdampLo  = Default( SdampLo,   Spower+1)      # reduces overdrive sharpening for very small changes
    SdampHi  = Default( SdampHi,        24 )      # further reduces sharpening for big sharpening changes. Try 15~30. "0" disables.
    bias     = Default( bias,           49 )      # bias towards detail ( >= 50 ),  or towards calm result ( < 50 )
    Smode    = Default( Smode, ssx<1.35 ? 12 : 20 )
    sootheT  = Default( sootheT,        49 )      # 0=minimum, 100=maximum soothing of sharpener's temporal instableness.
                                                  # (-100 .. -1 : will chain 2 instances of temporal soothing.)
    sootheS  = Default( sootheS,         0 )      # 0=minimum, 100=maximum smoothing of sharpener's spatial effect.

    Szp     = Szp     / pow(Sstr, 0.25) / sqrt( (ssx+ssy)/2.0)
    SdampLo = SdampLo / pow(Sstr, 0.25) / sqrt( (ssx+ssy)/2.0)

    ox    = clp.Width()
    oy    = clp.Height()
    isHD  = (ox > 1099 || oy >  599)
    xss   = nmod(ox*ssx,4,16)
    yss   = nmod(oy*ssy,4,16)
    NRL   = ex_bs(NRlimit,  8, bi, fulls=fs)
    NRL2  = ex_bs(NRlimit2, 8, bi, fulls=fs)
    NRLL  = ex_bs(round(NRlimit2 * 100.0/bias - 1), 8, bi, fulls=fs)
    limit = abs(Slimit)
    SLIM  = ex_bs(limit, 8, bi, fulls=fs)
    BIAS  = bias/100.

    denoised = Defined(denoised) ? denoised.ExtractY() : ex_lutxy(clp, isHD ? clp.ex_median(mode="smart2") : clp.removegrain(4, -1), Format("y x {NRL} - x {NRL} + clip"), fulls=fs)

    NRdiff = ex_makediff(clp, denoised, fulls=fs)
    tame   = ex_lutxy(clp, denoised, Format("x {NRLL} + y < x {NRL2} + x {NRLL} - y > x {NRL2} - x y - {BIAS} * y + ? ?"), fulls=fs)
    head   = tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, 4, fs)
    head   = head.mt_merge(tame, tame.mt_edge("prewitt", 0, 255, 0, 0, U=1, V=1).mt_expand().removegrain(20, -1))

    (ssx==1.0 && ssy==1.0) ? repair(tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head, 1, -1)                                                                                : \
                             repair(tame.lanczosresize(xss, yss).ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head.bicubicresize(xss, yss, -0.2, 0.6), 1, -1).lanczosresize(ox, oy)

    soothe = ex_SootheSS2(last, tame, sootheT, sootheS, false, fs)

    (NRlimit==0) ? clp : ex_lutxy(clp, NRdiff, Format("y range_half {NRL} + > x {NRL} - y range_half {NRL} - < x {NRL} + x y range_half - - ? ?"),fulls=fs)

      Slimit>=0  ? ex_lutxyz(last, soothe, tame, Format("z y - Z@ {SLIM} > x {SLIM} - Z 0 {SLIM} - < x {SLIM} + x Z - ? ?"), fulls=fs) : \
                   ex_lutxyz(last, soothe, tame, Format("z y - Z@ 0 == x dup Z abs 1 {limit} / ^ Z sgn * - ?"),              fulls=fs)

    isy ? last : CombinePlanes(last, input, planes="YUV", sample_clip=input)
    propCopy(input) }


#
#  SeeSaw2 ( modified for standard definition DVDs. by jeremy duncan november 11, 2008 )
#
# =======  Main function  =======

function SeeSaw2( clip  input, clip "denoised",
 \               int   "NRlimit",int "NRlimit2",
 \               float "Sstr",   int "Slimit", float "Spower", float "SdampLo", float "SdampHi", float "Szp",
 \               float "bias",   int "Smode",    int "sootheT",  int "sootheS", float "ssx",     float "ssy", bool "PAL") {

    isy = input.isy()
    clp = isy ? input : input.ExtractY()
    rgb = isRGB(input)
    bi  = BitsPerComponent(input)
    fs  = propNumElements (input,"_ColorRange")  > 0 ? \
          propGetInt      (input,"_ColorRange") == 0 : rgb

    PAL      = Default( PAL,   false )
    ssx      = Default( ssx, PAL ? 1.17 : 1.24 ) # supersampling factor "x". Set this to 1.24 for NTSC supersampling. Set this to 1.17 for PAL SS. For superspeed, set ssx to 1.00
    ssy      = Default( ssy,      ssx )          # supersampling factor "y". If at all, small values ~1.25 seem to be enough.
    NRlimit  = Default( NRlimit,    0 )          # absolute limit for pixel change by denoising
    NRlimit2 = Default( NRlimit2,   5 )          # limit for intermediate denoising
    Sstr     = Default( Sstr,    1.30 )          # Sharpening strength (don't touch this too much)
    Slimit   = Default( Slimit,    40 )          # positive: absolute limit for pixel change by sharpening
                                                 # negative: pixel's sharpening difference is reduced to diff=pow(diff,1/abs(limit))
    Spower   = Default( Spower,   1.0 )          # exponent for modified sharpener
    Szp      = Default( Szp,        1 )          # zero point - below: overdrive sharpening - above: reduced sharpening
    SdampLo  = Default( SdampLo,   25 )          # reduces overdrive sharpening for very small changes
    SdampHi  = Default( SdampHi,   52 )          # further reduces sharpening for big sharpening changes. Try 15~30. "0" disables.
    bias     = Default( bias,      49 )          # bias towards detail ( >= 50 ) ,  or towards calm result ( < 50 )
    Smode    = Default( Smode, ssx<1.35 ? 12 : 20 )
    sootheT  = Default( sootheT,   55 )          # 0=minimum, 100=maximum soothing of sharpener's temporal instableness.
                                                 # (-100 .. -1 : will chain 2 instances of temporal soothing.)
    sootheS  = Default( sootheS,    0 )          # 0=minimum, 100=maximum smoothing of sharpener's spatial effect.
    fs       = Default( fulls,   false)

    Szp     = Szp     / pow(Sstr, 0.25) / sqrt( (ssx+ssy)/2.0)
    SdampLo = SdampLo / pow(Sstr, 0.25) / sqrt( (ssx+ssy)/2.0)

    ox    = clp.Width()
    oy    = clp.Height()
    xss   = PAL ? nmod(ox*ssx,4,16) : round((ox*ssx)/5.0)*12
    yss   = PAL ? nmod(oy*ssy,4,16) : round((oy*ssy)/5.0)*12
    NRL   = ex_bs(NRlimit,  8, bi, fulls=fs)
    NRL2  = ex_bs(NRlimit2, 8, bi, fulls=fs)
    NRLL  = ex_bs(NRlimit2 * 100.0/bias - 1, 8, bi, fulls=fs)
    limit = abs(Slimit)
    SLIM  = ex_bs(limit, 8, bi, fulls=fs)
    BIAS  = bias/100.

    denoised = Defined(denoised) ? denoised.ExtractY() : ex_lutxy(clp, clp.removegrain(1, -1), Format("y x {NRL} - x {NRL} + clip"),     fulls=fs)

    NRdiff = ex_makediff(clp, denoised, fulls=fs)
    tame   = ex_lutxy(clp, denoised, Format("x {NRLL} + y < x {NRL2} + x {NRLL} - y > x {NRL2} - x y - {BIAS} * y + ? ?"), fulls=fs)
    head   = tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, 4, fs)
    head   = head.mt_merge(tame, tame.mt_edge("prewitt", 0, 255, 0, 0, U=1, V=1).mt_expand().removegrain(1, -1))

    (ssx==1.0 && ssy==1.0) ? repair(tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head, 1, -1)                                                                                 : \
                             repair(tame.spline36resize(xss, yss).ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head.bicubicresize(xss, yss, 0.75, 1.0), 1, -1).lanczosresize(ox, oy)

    soothe = ex_SootheSS2(last, tame, sootheT, sootheS, true, fs)

    (NRlimit==0) ? clp : ex_lutxy(clp, NRdiff, Format("y range_half {NRL} + > x {NRL} - y range_half {NRL} - < x {NRL} + x y range_half - - ? ?"), fulls=fs)

      Slimit>=0  ? ex_lutxyz(last, soothe, tame, Format("z y - Z@ {SLIM} > x {SLIM} - Z 0 {SLIM} - < x {SLIM} + x Z - ? ?"), fulls=fs) : \
                   ex_lutxyz(last, soothe, tame, Format("z y - Z@ 0 == x dup Z abs 1 {limit} / ^ Z dup abs / * - ?"),        fulls=fs)

    isy ? last : CombinePlanes(last, input, planes="YUV", sample_clip=input)
    propCopy(input) }


# =======  Modified sharpening function  =======

function ex_sharpen22(clip clp, float strength, float power, float zp, float lodmp, float hidmp, int rgmode, bool fulls) {

    ox    = clp.Width()
    oy    = clp.Height()
    isHD  = (ox > 1099 || oy >  599)
    fs    = Default(fulls, false)
    STR   = strength
    PWR   = 1.0/power
    ZRP   = ZP
    ZRPr  = 1. / ZP
    DMP   = lodmp
    HDMPr = 1. / hidmp
    HDMP  = (hidmp==0) ? "1" : Format("A abs {HDMPr} * 4 ^ 1 + /")
    expr = Format("x dup y == swap dup dup y - A@ abs {ZRPr} * {PWR} ^ {ZRP} * {STR} * A dup * dup {DMP} + / * A sgn * "+HDMP+" + ?")

    rg = rgmode==11 || rgmode==12 || rgmode==19 || rgmode==20
    ex_lutxy( clp, isHD ? rg ? clp.ex_boxblur(2,mode="weighted") : clp.ex_median(mode="smart2") : clp.RemoveGrain(rgmode,-1), expr, UV=1, fulls=fs, scale_inputs=fs ? "allf" : "all") }



# =======  Soothe() function to stabilize sharpening  =======

function ex_SootheSS2(clip sharp, clip orig, int "sootheT", int "sootheS", bool "SootheSS2", bool "fulls") {

    sootheT  = Default(sootheT, 25 )
    sootheS  = Default(sootheS,  0 )
    SootheSS2= Default(SootheSS2, false)
    fs       = Default(fulls,     false)

    sootheT  = (sootheT > 100) ? 100 : (sootheT < -100) ? -100 : sootheT
    sootheS  = (sootheS > 100) ? 100 : (sootheS < 0)    ?    0 : sootheS
    ST       = 1 - abs(sootheT)/100.
    SSPT     = 1 - abs(sootheS)/100.

    ex_makediff(orig,sharp,UV=1,fulls=fs)

    (sootheS==0) ? last : ex_lutxy( last, last.removegrain(SootheSS2 ? 1 : 20, -1),
     \             Format("x range_half - X@ y range_half - Y@ * 0 < X {SSPT} * range_half + X abs Y abs > x y - {SSPT} * y + x ? ?"),UV=1,fulls=fs)

    (sootheT==0) ? last : ex_lutxy( last, last.temporalsoften(1,255,0,32,2),
     \             Format("x range_half - X@ y range_half - Y@ * 0 < X {ST}   * range_half + X abs Y abs > x y - {ST}   * y + x ? ?"),UV=1,fulls=fs)

    (sootheT>-1) ? last : ex_lutxy( last, last.temporalsoften(1,255,0,32,2),
     \             Format("x range_half - X@ y range_half - Y@ * 0 < X {ST}   * range_half + X abs Y abs > x y - {ST}   * y + x ? ?"),UV=1,fulls=fs)

    ex_makediff(orig,last,UV=1,fulls=fs) }




/*
    SeeSawMulti() by StainlessS (15-02-2017)
    Calls SeeSaw() multiple times. Requires SeeSaw script + SeeSaw requirements.

    https://forum.doom9.org/showthread.php?t=174309&page=2
    Inspired by InGoldie: https://forum.doom9.org/showthread.php?p=1748707#post1748707 (as usual, thread deleted)

    Times, Number of iterations.
    IG, smoother/soother, can be:-
        Undefined, uses SeeSaw builtin smoothing at every iteration.
        Denoised Clip, Used at every iteration.
        Function String, Denoise applied to source, or result of previous iteration.
    Remaining args as for SeeSaw().
*/

function SeeSawMulti(clip  c, int "Times", val "IG",
    \    int "NRlimit",int "NRlimit2",
    \    float "Sstr",   int "Slimit", float "Spower", float "SdampLo", float "SdampHi", float "Szp",
    \    float "bias",   int "Smode",    int "sootheT",  int "sootheS", float "ssx",     float "ssy",
    \    Float "BlurVal",Float "BlurMult") {

    function SeeSawMulti_LO(clip c, int Times, val "IG",
        \    int   "NRlimit",int "NRlimit2",
        \    float "Sstr",   int "Slimit", float "Spower", float "SdampLo", float "SdampHi", float "Szp",
        \    float "bias",   int "Smode",    int "sootheT",  int "sootheS", float "ssx",     float "ssy",
        \    Float "BlurVal",Float "BlurMult") {

        c

        dn = (IG.IsClip()) ? IG : (IG.IsString()) ? Eval(IG) : Undefined()

        BlurVal  = Default(BlurVal,0.0)
        BlurMult = Default(BlurMult,1.0)

        SeeSaw(dn, NRlimit, NRlimit2, Sstr, Slimit, Spower, SdampLo, SdampHi, Szp, bias, Smode, sootheT, sootheS, ssx, ssy)

        if (0<Times && Blurval>0.0) {
           ex_blur(BlurVal)
           }

        for (i = 0, times, 1) {
             i == 0 ? last : \
             SeeSawMulti_Lo(i-1, IG, NRlimit, NRlimit2, Sstr, Slimit, Spower, SdampLo, SdampHi, Szp, bias, Smode, sootheT, sootheS, ssx, ssy, BlurVal*BlurMult, BlurMult) }
        }

    Times = Default(Times, 1)
    c
    for (i = 0, times, 1) {
         i == 0 ? last : \
         SeeSawMulti_Lo(i-1, IG, NRlimit, NRlimit2, Sstr, Slimit, Spower, SdampLo, SdampHi, Szp, bias, Smode, sootheT, sootheS, ssx, ssy, BlurVal, BlurMult) }
    }



#######################################
###
### FineSharp by Didée (08-04-2012)
### (https://forum.doom9.org/showthread.php?p=1569035#post1569035)
###
### Small and relatively fast realtime-sharpening function,
### for 1080p, or after scaling 720p -> 1080p during playback (to make 720p look more like being 1080p)
### It's a generic sharpener. Only for good quality sources!
### (If the source is crap, FineSharp will happily sharpen the crap.) ;)
### Noise/grain will be enhanced, too. The method is GENERIC.
###
### Modus operandi: A basic nonlinear sharpening method is performed, then the *blurred* sharp-difference gets subtracted again.
###
### - Didée
###     mod 2020.04.12 HBD by real.finder
### mix mod 2021.08.16     by Dogway
###
###
### Function Definition:
###    (
###    clip,
###    float sstr=2.0 (0.0 to 5.0 by 0.1),
###    string mode=1 (0 to 3 by 1),
###    [float cstr=1.0 (0.5 to 1.25 by 0.1)],
###    float "xstr"=0.19 (0.0 to 0.250 by 0.01),
###    float "lstr"=1.49 (0.0 to 2.0 by 0.01),
###    float "pstr"=1.272 (0.0 to 2.0 by 0.01),
###    float "ldmp"=2.1 (0.0 to 8.0 by 0.01),
###    float "hdmp"=0.01 (0.0 to 8.0 by 0.01),
###    )
###
function FineSharp(clip c, float "sstr", int "mode", float "cstr", float "xstr", float "lstr", float "pstr", float "ldmp", float "hdmp") {

    rgb   = isRGB(c)
    bi    = BitsPerComponent(c)
    fs    = propNumElements (c,"_ColorRange")  > 0 ? \
            propGetInt      (c,"_ColorRange") == 0 : rgb

    sstr  = Default(sstr, 2.0 )     #  strength of sharpening, 0.0 up to ??
    mode  = Default(mode, 1   )     #  1 to 3, weakest to strongest. When negative -1 to -3, a broader kernel for equalisation is used.

    _cstr = spline(sstr, 0,0, 0.5,0.1, 1.0,0.6, 2.0,0.9, 2.5,1.00, 3.0,1.09, 3.5,1.15, 4.0,1.19, 8.0,1.249, 255.0,1.5)
    _cstr = (mode>0) ? _cstr : pow(_cstr,1/1.25)

    cstr  = Default(cstr, _cstr)    #  strength of equalisation (recommended 0.5 to 1.25)
    xstr  = Default(xstr, 0.19 )    #  strength of XSharpen-style final sharpening, 0.0 to 1.0 (but, better don't go beyond 0.249 ...)

    #  Viscera parameters
    lstr  = Default(lstr, 1.49 )    #  modifier for non-linear sharpening
    pstr  = Default(pstr, 1.272)    #  exponent for non-linear sharpening
    ldmp  = Default(ldmp, sstr+0.1) # "low damp", to not overenhance very small differences (noise coming out of flat areas)
    hdmp  = Default(hdmp,     0.01) # "high damp", this damping term has a larger effect than ldmp when the sharp-difference is larger than 1, vice versa.

    LSTR  = 1. / lstr
    PSTR  = 1. / pstr
    rg    = mode>0 ? 12 : 20

    b = (abs(mode)==1) ? c.removegrain(12,-1).removegrain(4, -1)
    \ : (abs(mode)==2) ? c.removegrain(4, -1).removegrain(12,-1)
    \ : (abs(mode)==3) ? c.removegrain(4, -1).removegrain(12,-1).removegrain(4,-1) : c

    shrpD = ex_lutxy(c,b,Format("x y - A@ abs B@ {LSTR} * {PSTR} ^ {SSTR} * A B {HDMP} + / * A dup * dup {LDMP} + / * 0 max 128 +"), UV=1, fulls=fs, scale_inputs=fs ? "allf" : "all")

    shrp = (sstr<0.01) ?    c : c.ex_adddiff(shrpD,UV=1,fulls=fs)

    shrp = (cstr<0.01) ? shrp : shrp.ex_makediff(shrpD.ex_lut(Format("x range_half - {CSTR} * range_half +"),fulls=fs).removegrain(rg,-1), UV=1, fulls=fs)

           (xstr<0.01) ? shrp : ex_lutxy(shrp, shrp.removegrain(20,-1),"x dup y - 9.69 * +", UV=1, fulls=fs).repair(shrp,12,0).mergeluma(shrp,1.0-xstr) }




##################################
##
## NonlinUSM: local contrast by Didée, (01-02-2012)
##
## Non-Linear Unsharp Masking
##     https://forum.doom9.org/showthread.php?p=1555234#post1555234
##
## Local Contrast Enhancement function:
## Something to play with - the "nonlinear" sharpening from SeeSaw, just with a wide-range gaussian instead of a small-range kernel.
##
## (modded Raffriff42 - lowered strength of effect if "str" < 1.0)
## following header comments by raffriff42
## https://forum.doom9.org/showthread.php?p=1821086#post1821086
## https://forum.doom9.org/showthread.php?p=1690165#post1690165
##
## mod by Dogway (06-09-2021)
## - Ported to ExTools
## - Optimized Expressions
## - Replaced with better gaussian blur
## - Copied Raffriff42 defaults, header and examples
##
## @ str   - default 0.7   (0.3 = mild;      0.7  = medium;  1 = strong;  3 = very strong;  18 = massive)
## @ z     - default 6     (3.0 = subtle;    16   = massive)
## @ pow   - default 1.6   (1.0 = oversharp; 4.0  = mild)
## @ rad   - default 9     (0.6 = sharpen;   8-20 = strong;  30-50 = medium;  60 = mild)
## @ ldmp  - default 0.001 (block overlap?   0.01 = a little smoother?)
##
## EXAMPLES:
## | NonlinUSM(pow=4)                                       ## enhance: for low bitrate sources
## | NonlinUSM(str=1,   z=3, pow=4.0, rad=6)                ## enhance less
## | NonlinUSM(str=0.5, z=3, pow=1,   rad=9)                ## enhance less+
## |
## | NonlinUSM(str=1.5, z=6,          rad=0.6).Sharpen(0.3) ## sharpen: for hi-q sources
## | NonlinUSM(str=2.5, z=3,          rad=0.6)              ## sharpen: less noise
## | NonlinUSM(str=1,   z=6, pow=1,   rad=6  )              ## unsharp
## | NonlinUSM(str=0.7, z=6, pow=1.6, rad=9  )              ## unsharp softer (Raffriff42 defaults) [DEFAULT]
## |
## | NonlinUSM(str=0.7, pow=1.0, rad=2 )                    ## smoothen: for noisy sources
## | NonlinUSM(str=0.5, pow=1.0, rad=18)                    ## smear: soft glow
## |
## | NonlinUSM(str=18,  z=16, pow=4.0, rad=6  )             ## B+W psychedelic
## | NonlinUSM(str=3,   z=16, pow=4.0, rad=6  )             ## sepia/artistic
## | NonlinUSM(str=1,   z=6,  pow=4.0, rad=36 )             ## local contrast
## | NonlinUSM(str=1,   z=6,  pow=1.0, rad=36 )             ## local contrast
## | NonlinUSM(str=0.6, z=1,  pow=1.0, rad=40 )             ## local contrast (modified original Didée's defaults)
## | NonlinUSM(str=2,   z=16, pow=2.0, rad=36 )             ## solarized
##
## Function Definition:
##    (
##    clip,
##    float str=0.7 (0.0 to 20.0 by 0.1),
##    float z=6.0 (0.0 to 20.0 by 0.1),
##    float pow=1.6 (0.0 to 5.0 by 0.1),
##    float rad=9.0 (0.0 to 60.0 by 0.1),
##    float ldmp=0.001 (0.0 to 0.5 by 0.001),
##    )
##
function NonlinUSM(clip o, float "str", float "z", float "pow", float "rad", float "ldmp", int "UV") {

    rgb = isRGB(o)
    bi  = BitsPerComponent(o)
    fs  = propNumElements (o,"_ColorRange")  > 0 ? \
          propGetInt      (o,"_ColorRange") == 0 : rgb

    str = Default(str,  0.7)   # strength
    z   = Default(z,    6.0)   # zero point
    pow = Default(pow,  1.6)   # power
    rad = Default(rad,  9.0)   # radius for "gauss"
    ldmp= Default(ldmp, 0.001) # damping for verysmall differences
    UV  = Default(UV,    rgb ? 3 : 1)

    z    = ex_bs(z,    8, bi, fulls=fs, flt=true)
    ldmp = ex_bs(ldmp, 8, bi, fulls=fs, flt=true)
    zd   = 1. / z
    pw   = 1. / pow

    w = o.width()
    h = o.height()

    g = o.ex_GaussianBlur(rad*0.83825-0.0631,pad=true)  # Parametrized to match original

    ex_lutxy(o, g, Format("x dup y - A@ abs {zd} * {pw} ^ {z} * {str} * A dup * dup {ldmp} + / * A sgn * + dup 0 > swap x ?"), UV=UV, fulls=fs)

    #interleave(o,last) # just for visualisation, you don't want the function to do this
   }



##################################
#
# SlopeBend()  (SlopeBender? SlopeTwist? SlopeTwister? SlopeSharpen?)
#
# https://forum.doom9.org/showthread.php?p=680658#post680658
#
# A sharpening experiment by Didée  (10-08-2004). Usage is NOT RECOMMENDED.
#                     mod by Dogway (16-08-2021)
#
# It sharpens the picture by adjusting the slope of the gradient values inbetween the local min/max interval.
# Effectively, edges are sharpened without oversharpening (halos) (but risk to make them jaggy).
#
# str:       Not really usable yet - leave at '75'. Bigger gives jagged artefacts, smaller gives ... an interesting effect.
# rad:       The distance to search for the current pixel's upper & lower boundary.
#            The bigger, the stronger the effect, but the slower the script runs.
#            range: 1-5 / default: 1
# overshoot: not yet implemented
# ss_x,ss_y: If needed, the filter may work supersampled. Generally it's not needed, but comes handy for
#            "uneven" sharpening like i.e. resizing 1:1 PAR --> anamorphic PAR, or for strength values > 100.
# soft:      Pre-blurring before searching local maxima & minima. Not very useful.
#
# 10.08.2004 - got the method initially working for the first time ("how to correctly implement?!"),
#              after having it in mind for several months.
#
#
# Function Definition:
#    (
#    clip,
#    int str=75 (0 to 150 by 1),
#    int rad=1 (1 to 5 by 1),
#    float ss_x=1.0 (0.0 to 2.0 by 0.1),
#    float ss_y=1.0 (0.0 to 2.0 by 0.1),
#    bool "soft"=false,
#    )
#
function SlopeBend( clip a, int "str", int "rad", float "ss_x", float "ss_y", bool "soft") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)
    fs   = propNumElements (a,"_ColorRange")  > 0 ? \
           propGetInt      (a,"_ColorRange") == 0 : rgb

    str       = Default( str,       75 )
    rad       = Default( rad,        1 )
    ss_x      = Default( ss_x,     1.0 )
    ss_y      = Default( ss_y,     1.0 )
    soft      = Default( soft,   false )

    Sstr      = str/100.0
    rad       = max(min(rad,5),1)
    ox        = a.width ()
    oy        = a.height()
    ss        = ss_x != 1.0 || ss_y != 1.0

    clp = isy ? a : a.ExtractY()

    bright_limit = soft ? clp.ex_boxblur(0.5,mode="weighted") : clp #.sharpen(1.0)#.blur(1.58)

    dark_limit   = bright_limit.ex_inpand(rad).ex_boxblur(rad+2,mode="weighted")
    dark_limit   = ss ?   dark_limit.lanczosresize(nmod(ox*ss_x,8),nmod(oy*ss_y,8)) : dark_limit

    bright_limit = bright_limit.ex_expand(rad).ex_boxblur(rad+2,mode="weighted")
    bright_limit = ss ? bright_limit.lanczosresize(nmod(ox*ss_x,8),nmod(oy*ss_y,8)) : bright_limit


    minmaxavg    = Merge(bright_limit,dark_limit)  # local neighbourhood average

    tmp          = ss ? clp.lanczosresize(nmod(ox*ss_x,8),nmod(oy*ss_y,8)) : clp

    assign_dark  = ex_lutxy (tmp, minmaxavg, "y x - 0 < 0 range_max ?", fulls=fs)

    map_to_max   = ex_lutxyz(tmp, minmaxavg, bright_limit, Format("z x - A@ dup dup * swap x y - abs B@ + C@ / A B 4 ^ * C 4 ^ / + A / {Sstr} ^ A * 0 max"), fulls=fs) # masked with outline
    map_to_min   = ex_lutxyz(tmp, minmaxavg, dark_limit,   Format("x z - A@ dup dup * swap x y - abs B@ + C@ / A B 4 ^ * C 4 ^ / + A / {Sstr} ^ A * 0 max"), fulls=fs) # masked with inline

    max_mapped   = ex_makediff(bright_limit, map_to_max, dif=false, fulls=fs)
    min_mapped   = ex_adddiff (dark_limit,   map_to_min, dif=false, fulls=fs)

    ex_merge(max_mapped, min_mapped, assign_dark, UV=1)

    #normsharp2
    !ss ? last : lanczosresize(ox,oy)
    isy ? last : CombinePlanes(last, a, planes="YUV", sample_clip=a)
    propCopy(a) }



# Didée's Median Enhancer Sharpener (12-10-2012)
# https://forum.doom9.org/showthread.php?p=1595531#post1595531
#
# ExTools port  by Dogway           (05-09-2021)
#
# Requires MedianBlur2 for str > 3: https://avisynth.nl/index.php/MedianBlur2
# Also known as DDSharp(). 'pass' concept imported from DDSharp()

function MedianSharp (clip a, int "str", float "pwr", int "UV") {

    rgb = isRGB(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : rgb

    str = Default( str,      3 )
    pwr = Default( pwr,   1.62 )
    UV  = Default( UV,       3 )

    pwr2 = 1. / pow(pwr, 2)
    pwr3 =      pow(pwr, 3)
    rpwr = 1. / pwr
    pass = round(str/1.5)
    rc   = UV == 3

    b    = str==1 ? a.removegrain(4,rc?4:-1)      : \
           str==2 ? a.ex_median("median5", UV=UV) : \
           str==3 ? a.ex_median("median7", UV=UV) : \
                    a.medianblur(str,pass,pass)

    c    = a.repair(b,1,rc?1:-1)

    for (i = 0, max(0,pass-1), 1) {
        c = c.repair(c,1,rc?1:-1) }

    ex_lutxy(a, c, Format("x dup y - A@ abs B@ {pwr2} * {rpwr} ^ {pwr3} * A B {pwr} + / * +"), UV=UV, scale_inputs=fs ? "allf" : "all") }



##################################
#
# DetailSharpen() by Didée        (24-12-2011)
#
#
#  VS port        by Wolfberry    (01-01-2019?)
#  AVS+ backport  by Dogway       (16-08-2021)
#
#  From: https://forum.doom9.org/showthread.php?t=163598
#  From: https://forum.doom9.org/showthread.php?p=1537261#post1537261
#  Didée: Wanna some sharpening that causes no haloing, without any edge masking?
#
#  Args:
#      z     (float) - zero point.
#      sstr  (float) - strength of non-linear sharpening.
#      power (float) - exponent of non-linear sharpening.
#      ldmp  (float) - "low damp", to not over-enhance very small differences.
#      mode   (int)  - 0: gaussian kernel 1: box kernel
#      med   (bool)  - When True, median is used to achieve stronger sharpening.
#
#  Examples:
#      DetailSharpen()                            # Original DetailSharpen by Didée.
#      DetailSharpen(power=1.5, mode=0, med=True) # Mini-SeeSaw...just without See, and without Saw.
#
# Function Definition:
#    (
#    clip,
#    int z=4 (0 to 20.0 by 1),
#    float sstr=1.5 (0.0 to 3.0 by 0.1),
#    int power=4 (0 to 8 by 1),
#    int ldmp=1 (0 to 5 by 1),
#    int mode=1 (0 to 1 by 1),
#    bool med=false,
#    )
#
function DetailSharpen(clip c, int "z", float "sstr", int "power", int "ldmp", int "mode", bool "med") {

    rgb  = isRGB(c)
    bi   = BitsPerComponent(c)
    fs   = propNumElements (c,"_ColorRange")  > 0 ? \
           propGetInt      (c,"_ColorRange") == 0 : rgb

    z     = Default( z,      4 )
    sstr  = Default( sstr, 1.5 )
    power = Default( power,  4 )
    ldmp  = Default( ldmp,   1 )
    mode  = Default( mode,   1 )
    med   = Default( med,   false )

    ldmp  = ex_bs(max(ldmp, 0), 8, bi, fulls=fs)
    strzi = ex_bs(sstr*z,       8, bi, fulls=fs, flt=true)
    zs    = 1. / ex_bs(z,       8, bi, fulls=fs)
    rpwr  = 1. / power

    denoised = mode == 1 ?  c.removegrain(20,-1) : c.removegrain(12,-1)
    denoised = med ? denoised.removegrain(4,-1)  : denoised

    ex_lutxy(c, denoised, Format("x dup y == swap dup dup y - A@ abs B@ {zs} * {rpwr} ^ {strzi} * A B {ldmp} + / * + ? "), UV=1, fulls=fs) }






#######################
###                 ###
###   *.mp4 guy     ###
###                 ###
#######################


### SSSharpFaster() (Super Slow Sharpen Faster)
### SSSharp's mod by LaTo (12-10-2012)
###
### https://forum.doom9.org/showthread.php?t=142682&page=4#post1218074
###
### port by Dogway (05-09-2021)
###
function SSSharpFaster(clip c, float "str", int "hthr", int "hbias") {

    str      = Default(str,    6.0)
    hthr     = Default(hthr,   256)
    hbias    = Default(hbias, -128)

    bi    = BitsPerComponent(c)
    w     = c.width()
    h     = c.height()
    hbias = ex_bs(hbias, 8, bi, fulls=true)

    s = c.blackmanresize(w*2,h*2)
    a = s.awarpsharp2(chroma=2, depth=2, blur=1, thresh=250)


    Mblur = s.removegrain(4 ,-1)
    Gblur = s.removegrain(20,-1)
    Hmask = ex_lutxy(Mblur, Gblur, Format("y x - abs {hthr} * {hbias} -"), UV=1)


    ex_lutxyza(s, Gblur, a, Hmask, Format("x dup y      - {str}     * + dup
                                           x dup z swap - {str} 3 / * + -
                                           a range_max / * -"), UV=1)
    spline36resize(w,h) }



### SSSharp() (Super Slow Sharpen)
### 0.0 by *.mp4 guy (02-12-2007)
### 0.1 by Didée     (03-12-2007)
### 0.2 by Dogway    (04-09-2021)
###
### https://forum.doom9.org/showthread.php?t=132330
###
### 'Rad' must be a multiple of 0.25 when ss=true, or 1 when ss=false. Usable range is 0.25 to ~8.
### Using a 'rad' that is not close to the radius of the bluring present in your source will
### give suboptimal results. Higher 'iter', with lower 'strength' will give more precise masking
### (less halos for same sharpening) but will be very slow.
###
### SSSharp(ssw=true, iter=1, strength=1, rad=1)
### SSSharp(ssw=true, iter=2, strength=3)
###
### Dependencies:
###     aWarpSharpMT
###     VariableBlur (for unsharp)
###     vsDeGrainMedian

function SSSharp(clip c, float "rad", bool "ssw", float "strength", int "iter", bool "ss", int "denoise"){

    rad      = Default(rad,    0.25)                     # Rad should be multiple of 0.25 when ss=true (stepping of 0.25)
    ssw      = Default(ssw,    true)
    strength = Default(strength,  4)
    iter     = Default(iter,      1)
    ss       = Default(ss,     true)
    denoise  = Default(denoise,iter)

    rad      = ss ? rad-Fmod(rad-0.125, 0.25)+0.125 : 1  #  Force stepping of 0.25

    c
    w    = width(c)
    h    = height(c)
    iter = min(iter,denoise)

    sswc = ssw ? c.SSW() : c
    for (i = 0, iter, 1) {
        mt_merge(unsharp(vary=rad, varc=1, strength=strength), sswc, spline36resize((ss ? w*4 : w), (ss ? h*4 : h)).                          \
                                                                     halomaskM(hbias=-128, hthr=256, agmrad=(ss ? round(rad*4) : round(rad))).\
                                                                     spline36resize(w, h))
        for (k = 0, denoise, 1) {
            vsDeGrainMedian(modeY=3)
    } } }


# Without dependencies except aWarpSharpMT
function SSSharpEX(clip c, float "rad", bool "ssw", float "strength", int "iter", bool "ss", int "denoise") {

    rad     = Default(rad,    0.25)                     # Rad should be multiple of 0.25 when ss=true (stepping of 0.25)
    ssw     = Default(ssw,    true)
    str     = Default(strength,  4)
    iter    = Default(iter,      1)
    ss      = Default(ss,     true)
    denoise = Default(denoise,iter)

    rad     = ss ? rad-Fmod(rad-0.125, 0.25)+0.125 : 1  #  Force stepping of 0.25
    c
    rad  = min(rad, 4.9)
    w    = Width(c)
    h    = Height(c)
    iter = min(iter,denoise)
    isHD = (w > 1099 || h >  599)
    isUHD= (w > 2599 || h > 1499)
    ss_f = !ss ? 1 : isUHD ? 2 : isHD ? 3 : 4

    SSWC = ssw ? c.SSW() : c
    for (i = 0, iter, 1) {
        us = "ex_merge(ex_unsharp(str/2.,max(w,h)/(1.01-0.2*rad), th=0, UV=1), SSWC, spline16resize(ss_f*w, ss_f*h).                         \
                                                                                     halomaskM(hbias=-128, hthr=256, agmrad=round(rad*ss_f)).\
                                                                                     bicubicresize(w, h, -0.5, 0.25), UV=1)"
        for (k = 0, denoise, 1) {
            dot = i == denoise ? "" : "."
            us = us + """.ex_median(mode="DGM3", UV=1)""" + dot
    } }
    Return Eval(us) }


function halomaskM(clip c, int "hthr", int "hbias", int "agmrad") {

    hthr   = Default(hthr,   256)
    hbias  = Default(hbias, -128)
    agmrad = Default(agmrad,   1)   # from 1 to 3 max

    bi     = BitsPerComponent(c)
    hbias  = ex_bs(hbias, 8, bi, fulls=true)

    Mblur  = (agmrad==0) ? c                  : \
             (agmrad==1) ? c.removegrain(4,0) : \
                           c.ex_median( agmrad==2 ? "median5":"median7", UV=1)
    Gblur  =               c.ex_boxblur(agmrad *2, mode="weighted",      UV=1)

    ex_lutxy(Mblur, Gblur, Format("y x - abs {hthr} * {hbias} +"),       UV=1) }


function SSW(clip c) {
    c#.unsharp()
    w = width()
    h = height()

    spline16resize(w*3, h*3)

#    awarpsharp(cm=0, depth=3, blurlevel=1, thresh=0.99) # old call
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)

    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)
    awarpsharp2(chroma=2, depth=1, blur=1, thresh=250)

    bicubicresize(w, h, -0.5, 0.25) }





###
### ReCon()   by *.mp4 guy (18-06-2010)
### ReConvolution - Makes things sharp by mixing pixels together
### https://forum.doom9.org/showthread.php?p=1409582#post1409582
###
### Optimized and ported by Dogway (04-09-2021)
###
### Rad - radius of sharpening
### str - strength
### lmode - limit mode, 0 strong limiting, 3 minimal limiting. 4 no limiting. Default 1.
###
### Also, I'm curious if rad 4 ever works better then rad 3.
### Some artifacts, similar quality than SSSharp.
###
### Function Definition:
###    (
###    clip,
###    float str=7.0 (0.0 to 20.0 by 0.1),
###    [float strV=7.0 (0.0 to 20.0 by 0.1)],
###    float "rad"=1.0 (0.0 to 20.0 by 0.1),
###    [float "radV"=1.0 (0.0 to 20.0 by 0.1)],
###    int "lmode"=1 (0 to 4 by 1),
###    int "thresh"=720 (0 to 1000 by 1),
###    )
###
function ReCon(clip C, float "str", float "strv", float "rad", float "radv", int "lmode", int "thresh") {

    rgb   = isRGB(C)
    bi    = BitsPerComponent(C)
    fs    = propNumElements (C,"_ColorRange")  > 0 ? \
            propGetInt      (C,"_ColorRange") == 0 : rgb

    strh   = Default(str,      7)
    strv   = Default(strv,  strh)
    Radh   = Default(Rad,      1)
    Radv   = Default(Radv,  Radh)
    lmode  = Default(lmode,    1)
    thresh = Default(thresh, 720)

    Rad     = Radh
    Radh    = Radh * 2
    Radv    = Radv * 2
    thr2gh8 = 1./sqrt(thresh)
    thr2gv8 = thr2gh8
    thrstrh = sqrt(thr2gh8) * strh
    thrstrv = sqrt(thr2gv8) * strv
    thres   = ex_bs(thresh >= 1 ? sqrt(thresh) : thresh, 8, bi, fulls=fs, flt=true)
    si      = fs ? "allf" : "all"

    expr = Format("x y - dup dup abs 1 + dup swap2 * swap {thres} + / - range_half +")


    Max_V = ex_luts( C, mode = "max", pixels = ex_shape(Radv, mode="vertical", center=false), expr = expr, UV=1, fulls=fs)
    Min_V = ex_luts( C, mode = "min", pixels = ex_shape(Radv, mode="vertical", center=false), expr = expr, UV=1, fulls=fs)
    Med_V = ex_luts( C, mode = "med", pixels = ex_shape(Radv, mode="vertical", center= true), expr = expr, UV=1, fulls=fs)


    minmaxmed_v   = ex_lutxyz(Max_V, Min_V, Med_V, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.0625  *
                                                                               X                     Y   min B@ 0.25    * +
                                                                    B dup A swap - - 0 max z range_half - abs + 0.34375 * +"), UV=1, fulls=fs)

    Max_H = ex_luts( C, mode = "max", pixels = ex_shape(Radh, mode="horizontal", center=false), expr = expr, UV=1, fulls=fs)
    Min_H = ex_luts( C, mode = "min", pixels = ex_shape(Radh, mode="horizontal", center=false), expr = expr, UV=1, fulls=fs)
    Med_H = ex_luts( C, mode = "med", pixels = ex_shape(Radh, mode="horizontal", center= true), expr = expr, UV=1, fulls=fs)


    minmaxmed_h   = ex_lutxyz(Max_H, Min_H, Med_H, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.0625  *
                                                                               X                     Y   min B@ 0.25    * +
                                                                    B dup A swap - - 0 max z range_half - abs + 0.34375 * +"), UV=1, fulls=fs)

    Blur_V =                C.NLLV(   1,true, fs)
    Blur_V = Rad > 1 ? Blur_V.NLLV(Radv,true, fs) : Blur_V

    Sharp_V = lmode == 0 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - z * {thr2gv8} {strv} * * 128 +"),                                                   UV=1, scale_inputs=si, fulls=fs) : C
    Sharp_V = lmode == 1 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - X@ dup abs z > swap z * {thr2gv8} {strv} * * 128 + X z sqrt * {thrstrh} * 128 + ?"),UV=1, scale_inputs=si, fulls=fs) : Sharp_V
    Sharp_V = lmode == 2 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - X@ dup abs z > swap z * {thr2gv8} {strv} * * 128 + z 0 > X {strv} * 128 + 128 ? ?"),UV=1, scale_inputs=si, fulls=fs) : Sharp_V
    Sharp_V = lmode == 3 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - X@ dup abs z > swap z * {thr2gv8} {strv} * * 128 + X {strv} * 128 + ?"),            UV=1, scale_inputs=si, fulls=fs) : Sharp_V
    Sharp_V = lmode == 4 ? ex_lutxy (C, Blur_V,              Format(" x y - {strv} * 128 +"),                                                                   UV=1, scale_inputs=si, fulls=fs) : Sharp_V

    Blur_H =                C.NLLH(   1,true, fs)
    Blur_H = Rad > 1 ? Blur_H.NLLH(Radh,true, fs) : Blur_H

    Sharp_H = lmode == 0 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - z * {thr2gh8} {strh} * * 128 +"),                                                   UV=1, scale_inputs=si, fulls=fs) : C
    Sharp_H = lmode == 1 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - X@ dup abs z > swap z * {thr2gh8} {strh} * * 128 + X z sqrt * {thrstrv} * 128 + ?"),UV=1, scale_inputs=si, fulls=fs) : Sharp_H
    Sharp_H = lmode == 2 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - X@ dup abs z > swap z * {thr2gh8} {strh} * * 128 + z 0 > X {strh} * 128 + 128 ? ?"),UV=1, scale_inputs=si, fulls=fs) : Sharp_H
    Sharp_H = lmode == 3 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - X@ dup abs z > swap z * {thr2gh8} {strh} * * 128 + X {strh} * 128 + ?"),            UV=1, scale_inputs=si, fulls=fs) : Sharp_H
    Sharp_H = lmode == 4 ? ex_lutxy (C, Blur_H,              Format(" x y - {strh} * 128 +"),                                                                   UV=1, scale_inputs=si, fulls=fs) : Sharp_H

    ex_lutxyz(C, Sharp_V, Sharp_H, "x y z + + range_half - range_half -", UV=1, fulls=fs) }





### blah()   by *.mp4 guy (09-06-2010)
### https://forum.doom9.org/showthread.php?p=1406843#post1406843
###
### Optimized and ported by Dogway (04-09-2021)
###
### "After reading this post by Didée I decided to
### take a crack at the problem of sharpening an interpolated or lowpassed image. Out of curiosity I tried the resulting function
### on a few difficult to sharpen non-interpolated sources (GITS R1 Special eddition, etc.), and it did very well (imo, of course).
### So here is a new, general sharpening function. Right now it's named "blah". Because naming things is difficult, and naming it
### after what it is actually doing would require a paragraph long function call."
###
###
### Defaults are intended for strong sharpening on 2x upscaled material. For normal sharpening, set 'de' to 0.02, 'str' to 3 and 'cstr'
### to 0.75 and go from there. The failure modes are as graceful as I can reasonably get them, considering the strength of the
### sharpening required. Also, the degree of sharpening that can be "gotten away with" varies pretty wildly by source.
###
### str  = strength of highpass sharpening default 4
### cstr = strength of contrast sharpening default 1, values above 1 will cause halos
### de   = de-emphasis strength default 0.2
### re   = re-emphasis strength defaults to 'de'/2
###
###
### Function Definition:
###    (
###    clip,
###    float str=4 (0 to 20 by 1),
###    [float strV=4 (0 to 20 by 1)],
###    float "de"=0.2 (0.0 to 1.0 by 0.1),
###    [float "deV"=0.2 (0.0 to 1.0 by 0.1)],
###    float "re"=0.1 (0.0 to 1.0 by 0.1),
###    [float "reV"=0.1 (0.0 to 1.0 by 0.1)],
###    float "cstr"=0.5 (0.0 to 1.0 by 0.1),
###    [float "cstrV"=0.5 (0.0 to 1.0 by 0.1)],
###    )
###
function blah(Clip c, int "str", int "strv", float "de", float "dev", float "re", float "rev",  float "cstr", float "cstrv") {

    rgb   = isRGB(c)
    isy   = isy(c)
    bi    = BitsPerComponent(c)
    fs    = propNumElements (c,"_ColorRange")  > 0 ? \
            propGetInt      (c,"_ColorRange") == 0 : rgb

    strh  = Default(Str,       4)
    strv  = Default(strv,   strh)
    deh   = Default(de,      0.2)
    dev   = Default(dev,     deh)
    reh   = Default(re,    deh/2)
    rev   = Default(rev,     reh)
    cstrh = Default(cstr,    0.5)
    cstrv = Default(cstrv, cstrh)

    strv  = ex_bs(strv >= 1 ? sqrt(strv) : strv, 8, bi, fulls=fs, flt=true)
    strh  = ex_bs(strh >= 1 ? sqrt(strh) : strh, 8, bi, fulls=fs, flt=true)

    un    = ex_bs(1, 8, bi, fulls=fs)

    rev  = 20./rev
    reh  = 20./reh
    dih1 = 1. / (44 + reh)
    div1 = 1. / (44 + rev)
    dih2 = 1. / (44 - reh)
    div2 = 1. / (44 - rev)

    thrc   = 72
    thr2gv = 1/sqrt(thrc)
    thr2gh = thr2gv
    thrc   = ex_bs(thrc >= 1 ? sqrt(thrc) : thrc, 8, bi, fulls=fs, flt=true)

    lp_V =    c.NLLV(1,true,fs)
    lp_H = lp_V.NLLH(1,true,fs)

    DeEmphasis = lp_H.YAHR().YAHR().ex_lut(Format("x[-2,0] x[2,0] + 6 * x[-1,0] x[1,0] + 15 * x[-3,0] x[3,0] x[0,0] {reh} * + + + + {dih1} *"), UV=1). \
                                    ex_lut(Format("x[0,-2] x[0,2] + 6 * x[0,-1] x[0,1] + 15 * x[0,-3] x[0,3] x[0,0] {reh} * + + + + {div1} *"), UV=1)

    exprv = Format("x y - dup dup abs {un} + dup swap2 * swap {strv} + / - range_half +")
    exprh = Format("x y - dup dup abs {un} + dup swap2 * swap {strh} + / - range_half +")
    exprm = Format("x y - dup dup abs {un} + dup swap2 * swap {thrc} + / - range_half +")

    Max_V = ex_luts( c, mode = "max", pixels = ex_shape(1, mode="horizontal", center=false), expr = exprv, UV=1, fulls=fs)
    Min_V = ex_luts( c, mode = "min", pixels = ex_shape(1, mode="horizontal", center=false), expr = exprv, UV=1, fulls=fs)

    minmax_G_V = ex_lutxy(Max_V, Min_V, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.1  *
                                                                    X                     Y   min B@ 0.35 * +
                                                                              B dup A swap - - 0 max 0.55 * +"), UV=1, fulls=fs)

    Max_H = ex_luts( c, mode = "max", pixels = ex_shape(1, mode="vertical", center=false), expr = exprh, UV=1, fulls=fs)
    Min_H = ex_luts( c, mode = "min", pixels = ex_shape(1, mode="vertical", center=false), expr = exprh, UV=1, fulls=fs)

    minmax_G_H = ex_lutxy(Max_H, Min_H, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.1  *
                                                                    X                     Y   min B@ 0.35 * +
                                                                              B dup A swap - - 0 max 0.55 * +"), UV=1, fulls=fs)

    HPSharp = Expr(c, lp_V, lp_H, minmax_G_V, minmax_G_H, DeEmphasis, Format("x y - X@ a {un} max * a X abs - {un} max /
                                                                              y z - X@ b {un} max * b X abs - {un} max / + c +" ), isy ? Undefined() : "", optSingleMode=true)

    ReEmphasis = HPSharp.ex_lut(Format("x[-2,0] x[2,0] + 6 * x[-1,0] x[1,0] + 15 * x[-3,0] x[3,0] + + + x[0,0] {reh} * - {dih2} *"), UV=1). \
                         ex_lut(Format("x[0,-2] x[0,2] + 6 * x[0,-1] x[0,1] + 15 * x[0,-3] x[0,3] + + + x[0,0] {rev} * - {div2} *"), UV=1)

    V = ex_luts(ReEmphasis, mode="med", pixels = ex_shape(2, mode="vertical")   , expr = exprm, exprf = " range_half - abs", UV=1, fulls=fs, optSingleMode=true)
    H = ex_luts(ReEmphasis, mode="med", pixels = ex_shape(2, mode="horizontal") , expr = exprm, exprf = " range_half - abs", UV=1, fulls=fs, optSingleMode=true)


    # Although I do prefer the " 0 max" look after each "* *"
    ex_lutxyz(ReEmphasis, V, H, Format("x[-2,0] x[2,0] + 6 * x[-1,0] x[1,0] + 15 * x[-3,0] x[3,0] x[0,0] 20 * X20@ + + + + 0.015625 * H^
                                        x[0,-2] x[0,2] + 6 * x[0,-1] x[0,1] + 15 * x[0,-3] x[0,3] X20              + + + + 0.015625 *
                                        x swap - y * {thr2gv} {cstrv} * * x H - z * {thr2gh} {cstrh} * * x + +"), UV=1, scale_inputs= fs ? "allf" : "all") }




### MedSharp v0.3 by    Dogway (20-09-2021)
###          v0.2 by *.mp4 guy (11-08-2010)
###          v0.1 by *.mp4 guy (06-03-2010)
###
### Soft thresholded median sharpening function (superseeded by ReCon) (https://forum.doom9.org/showthread.php?p=1425066#post1425066)
###
### 1. calculate difference between center pixel and median neighborhood pixels
### 2. soft-limit each difference
### 3. find median of differences
### 4. add median difference to source
###
### Function Definition:
###    (
###    clip,
###    float str=1.0 (0.0 to 2.0 by 0.1),
###    int rad=1 (0 to 8 by 1),
###    int "thresh"=255 (0 to 255 by 1),
###    int "mode"=1 (0 to 1 by 1),
###    int "kernel"=2 (1 to 2 by 1),
###    bool "lp"=false,
###    bool "hp"=false,
###    bool "nr"=false,
###    )
###
function MedSharp(Clip C, float "str", int "rad", int "thresh", int "mode", bool "lp", bool "hp", bool "nr", int "kernel") {

    rgb  = isRGB(C)
    isy  = isy(C)
    bi   = BitsPerComponent(C)
    fs   = propNumElements (C,"_ColorRange")  > 0 ? \
           propGetInt      (C,"_ColorRange") == 0 : rgb

    THR    = Default(thresh, 255)
    RAD    = Default(rad,  1)
    Mode   = Default(mode, 1)
    str    = Default(str,  1)
    lp     = Default(lp,    false)
    hp     = Default(hp,    false)
    nr     = Default(nr,    false)
    kernel = Default(kernel, 2)

    blank = BlankClip(C,color_yuv=$808080)
    THR2  = ex_bs(sqrt(THR),   8, bi, fulls=fs, flt=true)
    THR3  = ex_bs(sqrt(THR*2), 8, bi, fulls=fs, flt=true)
    THR1  = ex_bs(THR,         8, bi, fulls=fs)
    un    = ex_bs(1,           8, bi, fulls=fs)

    Lowpass1       =  C.NLLV(1,false,fs).NLLH(1,false,fs)
    Lowpass_Return = lp && RAD >= 2 ? Lowpass1 : C

    Lowpass_NR_1 = Lowpass_Return.TMed2(thresh=THR,   rad=RAD, mode=mode, Kernel=1, fulls=fs)
    Lowpass_NR_2 = Lowpass_Return.TMed2(thresh=THR/4, rad=RAD, mode=mode, Kernel=2, fulls=fs)

    Diff1 = ex_luts(C, Lowpass_NR_1, mode="med", pixels = ex_shape(RAD, mode="plus",   center=true),  \
                                                   expr = Format("x y - dup dup abs {un} + dup swap2 * swap {THR1}     {un} >= {THR2} {THR1}     ? + / - range_half +"), UV=1, fulls=fs, optSingleMode=true)
    Diff2 = ex_luts(C, Lowpass_NR_2, mode="med", pixels = ex_shape(RAD, mode="square", center=false), \
                                                   expr = Format("x y - dup dup abs {un} + dup swap2 * swap {THR1} 2 * {un} >= {THR3} {THR1} 2 * ? + / - range_half +"), UV=1, fulls=fs)

    s1  = ex_lutxyz(Diff2, blank, Diff1, Format("x dup y - z range_half - range_max * 0 range_max clip 1 range_max / * * - range_half - {str} 0.5 * *    range_half +"), UV=1, fulls=fs)
    s1b = s1.NLLV(1,false,fs).NLLH(1,false,fs)

    s2  = Diff1.ex_lut(Format("x range_half - {str} * range_half +"), UV=1, fulls=fs)
    s2b = s2.NLLV(1,false,fs).NLLH(1,false,fs)

    Expr(C, s1, s1b, s2, s2b, "y z - a b - x + +", isy ? Undefined() : "") }




################################
##                            ##
## *.mp4 guy helper functions ##
##                            ##
################################


function TMed2(Clip c, float "thresh", int "rad", int "mode", int "kernel", bool "fulls") {

    THR    = Default(thresh, 255)
    RAD    = Default(rad,      1)
    Mode   = Default(mode,     1)
    kernel = Default(kernel,   1)
    fs     = Default(fulls, false)

    bi    = BitsPerComponent(c)
    THR2  = ex_bs(sqrt(THR), 8, bi, fulls=fs, flt=true)
    THR   = ex_bs(     THR,  8, bi, fulls=fs, flt=true)
    un    = ex_bs(1,         8, bi, fulls=fs)

    expr = Format("x y - dup dup abs {un} + dup swap2 * swap {THR} {un} >= {THR2} {THR} ? + / - 0 max range_half +")

    Diff = Kernel>1 ? ex_luts(c, mode="med", pixels = Format("-{RAD} -{RAD} -{RAD} {RAD} {RAD} -{RAD} {RAD} {RAD} 0 {RAD} {RAD} 0 -{RAD} 0 0 -{RAD}"), expr = expr, exprf = " x swap - range_half +", UV=1, fulls=fs) : \
           Mode==0  ? ex_luts(c, mode="med", pixels = Format("0 {RAD} {RAD} 0 -{RAD} 0 0 -{RAD}"),                                                     expr = expr, exprf = " x swap - range_half +", UV=1, fulls=fs) : \
                      ex_luts(c, mode="med", pixels = Format("0 {RAD} {RAD} 0 -{RAD} 0 0 -{RAD} 0 0"),                                                 expr = expr, exprf = " x swap - range_half +", UV=1, fulls=fs)

    Diff }


function NLHH2(Clip C, bool "fulls") {

    isy = isy(c)
    bi  = BitsPerComponent(c)

    fs = Default(fulls, false)

    B1 = C.BlurH(1, 0.833)
    B2 = C.BlurH(2, 0.750)
    B3 = C.BlurH(3, 0.944)
    B4 = C.BlurH(4, 0.981)

    Expr(C, B1, B2, B3, B4, "x y - S@ abs X^  z x - T@ abs Y^  S T X Y * A@ 1 + * A Y 0.75 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              x a - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.25 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              b x - T@ abs Y^  S T X Y * A@ 1 + * A Y 6.75 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
    }

function NLHV2(Clip C, bool "fulls") {

    isy = isy(c)
    bi  = BitsPerComponent(c)

    fs = Default(fulls, false)

    B1 = C.BlurH(1, 0.833)
    B2 = C.BlurH(2, 0.750)
    B3 = C.BlurH(3, 0.944)
    B4 = C.BlurH(4, 0.981)

    Expr(C, B1, B2, B3, B4, "x y - S@ abs X^  z x - T@ abs Y^  S T X Y * A@ 1 + * A Y 0.75 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              x a - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.25 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              b x - T@ abs Y^  S T X Y * A@ 1 + * A Y 6.75 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
    }

function NLLH(Clip C, int "rad", bool "var4", bool "fulls") {

    isy = isy(c)
    bi  = BitsPerComponent(c)

    rad = Default(rad, 1)
    v4  = Default(var4,  false)
    fs  = Default(fulls, false)

    B1 = C.BlurH(    1   *rad, 0.439)
    B2 = C.BlurH((v4?2:3)*rad, 0.833)
    B3 = C.BlurH((v4?3:5)*rad, 0.934)
    B4 = C.BlurH((v4?4:7)*rad, 0.983)

    Expr(C, B1, B2, B3, B4, "y x - S@ abs X^  x z - T@ abs Y^  S T X Y * A@ 1 + * A Y 1.915 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              a x - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.025 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              x b - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.077 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
    }

function NLLV(Clip C, int "rad", bool "var4", bool "fulls") {

    isy = isy(c)
    bi  = BitsPerComponent(c)

    rad = Default(rad, 1)
    v4  = Default(var4,  false)
    fs  = Default(fulls, false)

    B1 = C.BlurV(    1   *rad, 0.439)
    B2 = C.BlurV((v4?2:3)*rad, 0.833)
    B3 = C.BlurV((v4?3:5)*rad, 0.934)
    B4 = C.BlurV((v4?4:7)*rad, 0.983)

    Expr(C, B1, B2, B3, B4, "y x - S@ abs X^  x z - T@ abs Y^  S T X Y * A@ 1 + * A Y 1.915 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              a x - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.025 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  S@ abs X^
                                              x b - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.077 * X - 0 max  X 0 > X -1 S / ^ 1 ? / 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
    }


function BlurH(clip c, int "rad", Float "CW") {

    rad = Default(rad,  1)
    CW  = Default(CW, 0.5)

    CWr = (1-CW)/2.
    w   = c.width()
    h   = c.height()

    Center = C
    Left   = C.PointResize(w, h, -rad, 0, w, h)
    Right  = C.PointResize(w, h,  rad, 0, w, h)

    ex_lutxyz(Center, Left, Right, Format("x {CW} * y z + {CWr} * + "), UV=1) }


function BlurV(clip c, int "rad", Float "CW") {

    rad = Default(rad,  1)
    CW  = Default(CW, 0.5)

    CWr = (1-CW)/2.
    w   = c.width()
    h   = c.height()

    Center = C
    Down   = C.PointResize(w, h, 0, -rad, w, h)
    Up     = C.PointResize(w, h, 0,  rad, w, h)

    ex_lutxyz(Center, Down, Up, Format("x {CW} * y z + {CWr} * + "), UV=1) }


# Y'et A'nother H'alo R'educing script

function YAHR(clip clp) {

    b1    = clp.ex_minblur(2,UV=1).removegrain(11,-1)
    b1D   = ex_makediff(clp,b1,UV=1)

    w1    = clp.aWarpSharp(depth=32,blurlevel=2,thresh=0.5)
    w1b1  =  w1.ex_minblur(2,UV=1).removegrain(11,-1)
    w1b1D = ex_makediff(w1,w1b1,UV=1)

    DD    = b1D.repair(w1b1D,13,-1)

    ex_lutxyz(clp, b1D, DD, "x y z - -", UV=1) }






################################
###                          ###
###        feisty2's         ###
###                          ###
################################

# Note: Most of feisty2's filters (these or Plum, Oyster, Vine, etc) are benchmarked against SD 4:3 clips (namely old music clips)
#       So keep that in mind when evaluating quality on HD or performance.

function DelicateSharp (clip src, bool "relaxed", bool "coarse", int "lowpass") {

    bi     = BitsPerComponent(src)
    fs     = propNumElements (src,"_ColorRange")  > 0 ? \
             propGetInt      (src,"_ColorRange") == 0 : false

    rlx    = Default(relaxed,   false)
    crs    = Default(coarse,    false)
    lp     = Default(lowpass,      16)

    med    = rlx ? Repair(RemoveGrain(src,4), src, 16) : RemoveGrain(src,4)
    dif    = ex_lutxy(src, med, "y x - 3 * range_half +", fulls=fs)

    rg12   = RemoveGrain (dif,   12, -1)
    rg12D  = ex_makediff (dif, rg12, fulls=fs)
    rg12DR = RemoveGrain (rg12D, 12, -1)
    dif    = ex_lutxyz(rg12D, rg12DR, dif, "x y - D@ x range_half - X@ * 0 < z D abs X abs < D range_half + x ? z swap - range_half + ?", fulls=fs)

    difrg  = RemoveGrain (dif,   12, -1)
    fdif   = ex_lutxyz(dif, difrg, src, "y range_half - Y@ abs x range_half - abs > Y z + z ? ", fulls=fs)
    crs || rlx ? fdif : hipass (src, fdif, p=lp)
    return MergeChroma(src) }



function RegularSharp (clip src, bool "median", int "lowpass", int "a", float "h", float "thr", float "elast") {

    w      = src.width ()
    h      = src.height()
    isHD   = (w > 1099 || h >  599)
    bi     = BitsPerComponent(src)
    fs     = propNumElements (src,"_ColorRange")  > 0 ? \
             propGetInt      (src,"_ColorRange") == 0 : false

    med    = Default(median,   false)
    lp     = Default(lowpass,     16)
    a      = Default(a,           32)
    h      = Default(h,         12.8)
    thr    = Default(thr,         1.)
    ela    = Default(elast, thr / 6.)

    u2x             = med ? nop() : genpelclip (src, pel=2)
    mul             = isHD ? 4 : 8 # original was 8, reduced for sanity on HD
    for (i=4, 0, -1) {
        clp         = u2x
        blur        = BicubicResize(clp, w*mul, h*mul, b= 1, c=0)
        sharp       = BicubicResize(clp, w*mul, h*mul, b=-1, c=0)
        dif         = ex_makediff (blur, sharp, fulls=fs)
        dif         = BicubicResize(dif, w*2, h*2, b=-1, c=0)
        clp         = ex_adddiff (clp, dif, fulls=fs)
        ublur       = clp  }

    cdif            =  med ? nop() : BicubicResize(ex_makediff (u2x, ublur, fulls=fs), w, h, -4, -2, -0.5, -0.5)
    csharp          =  med ? nop() : halonr (hipass (src, ex_adddiff (src, cdif, fulls=fs), lp), a, h, thr, ela, lp/2, UV=1)
    msharp          = !med ? nop() : ex_makeadddiff (src, RemoveGrain(src,4,-1))
    clp             =  med ? msharp : csharp
    return MergeChroma(clp,src) }




# Called 'SharpFinal' but actually is a temporal limiter
#
# soft:  Soft clip previous to being sharpened
# dif:   Difference from sharpened clip to soft clip
# limit: Local neighbourhood average clip (?)
#
# Example:
#     soft = last
#     RegularSharp()
#     dif = ex_makediff(soft, dif=true)
#     lcl = Merge(ex_expand(soft), ex_inpand(soft))
#     SharpFinal(last,soft,lcl)

function SharpFinal (clip soft, clip dif, clip limit, clip "peldif", clip "pellimit", int "pel", int "tr", int "thsad", int "thscd1", int "thscd2", float "str", int "lowpass", int "a", float "h", float "thr", float "elast") {

    w         = soft.width ()
    h         = soft.height()

    bi        = BitsPerComponent(soft)
    fs        = propNumElements (soft,"_ColorRange")  > 0 ? \
                propGetInt      (soft,"_ColorRange") == 0 : false

    pdif      = Default(peldif,   Undefined())
    plim      = Default(pellimit, Undefined())

    pel       = Default(pel,          4)
    tr        = Default(tr,           6)
    thsad     = Default(thsad,      400)
    thscd1    = Default(thscd1,    1000)
    thscd2    = Default(thscd2,     255)
    lp        = Default(lowpass,      8)
    a         = Default(a,           32)
    h         = Default(h,          6.4)
    thr       = Default(thr,         1.)
    str       = Default(str,         1.)
    ela       = Default(elast, thr / 6.)

    blankd    = ex_lut(dif, "range_half", fulls=fs)
    superdif  = MSuper (dif,   pelclip=peldif,   rfilter=2, pel=pel)
    supercmp  = MSuper (limit, pelclip=pellimit, rfilter=2, pel=pel)
    vmulti    = getvectors(dif, pel=pel, tr=tr, thsad=thsad) # clip is best guess, actually it was an argument input
    coarse    = MDegrainN (blankd, superdif, vmulti, tr, thsad=10000, thscd1=thscd1, thscd2=thscd2, plane=0, limit=1.0)
    fine      = MDegrainN (blankd, superdif, vmulti, tr, thsad=thsad, thscd1=thscd1, thscd2=thscd2, plane=0, limit=1.0)
    averaged  = Expr(dif, coarse, blankd, fine, soft, ex_dlut("y z - abs x z - abs > a y ? b + range_half -", bi, fs),"")
    comp      = MCompensate (soft, supercmp, vmulti, tr=tr, thsad=thsad, thscd1=thscd1, thscd2=thscd2)
    bright    = ex_logic (maxmulti (comp, tr=tr), ex_inpand (limit), "min")
    dark      = ex_logic (minmulti (comp, tr=tr), ex_inpand (limit), "max")
    clamped   = ex_clamp (averaged, bright, dark, overshoot=0, undershoot=0)
    amplified = ex_lutxy(soft, clamped, Format("y x - A@ abs 0.25 * 0.25 pow {str} 1.6 4 * * * A sgn * x +"), scale_inputs=fs?"allf":"all")
    clp       = hipass  (soft, Repair (amplified, halonr (amplified, a, h, thr, elast, lowpass, 1), 16,0), lowpass)

    return clp }



function HaloNR (clip src, int "a", float "h", float "thr", float "elast", int "lowpass", int "UV") {

    bi      = BitsPerComponent(src)
    fs      = propNumElements (src,"_ColorRange")  > 0 ? \
              propGetInt      (src,"_ColorRange") == 0 : false

    lp      = Default(lowpass,      8)
    a       = Default(a,           32)
    h       = Default(h,          6.4)
    thr     = Default(thr,         1.)
    ela     = Default(elast, thr / 6.)
    UV      = Default(UV,           3)

    off     = ex_bs(0.24, 32, bi, fs, flt=true)
    pad     = PadBorders(src, a, a, a, a, "Dilate")
    Clean   = hipass (pad, ex_KNLMeansCL (pad, d=0, a=a, s=0, h=h, rclip=pad), p=lp)
    Blurred = ex_KNLMeansCL (Clean, d=0, a=a, s=0, h=64)
    EMask   = vsTCanny (Blurred, sigmaY=1.5, mode=1, op=0)
    EMask   = ex_lut(EMask, Format("x {off} - 6.4 * 0 range_max clip"), UV=UV, fulls=fs)
    EMask   = ex_expand(EMask).ex_inflate().ex_expand()
    MRG     = ex_merge  (pad, Clean, EMask, luma=UV==3, UV=UV)
    Final   = thrmerge  (pad, MRG, thr=thr, elast=ela)
    clp     = Crop (Final, a, a, -a, -a)
    return clp }



##
## Plum by feisty2
##
## Initial VapourSynth release (12-08-2016)
## AviSynth+ port    by Dogway (21-09-2021) (WIP)
##
## Input: YUV/RGB at any bitdepth
##
##   - A
##       ref = plum_Basic(clp, strength=6.4, cutoff=32)
##       clp = plum_Final(clp, ref, plum_Super(clp), plum_Super(ref), strength=1.8, freq_margin=12)
##   - B
##       ref = plum_Basic(clp)
##       clp = plum_Final(clp, ref, plum_Super(clp), plum_Super(ref), cutoff=8, freq_margin=12)
##   - C
##       ref = plum_Basic(clp)
##       clp = plum_Final(clp, ref, plum_Super(clp, pel=2), plum_Super(ref, pel=2), pel=2)
##
##
##    Dependencies:
##                  ExTools
##                  MVTools
##                  RgTools
##                  nnedi3
##                  ResizersPack
##                  manyPlus
##                  KNLMeansCL
##                  SysInfo
##



function plum_Super(clip src, int "pel") {

    pel = Default(pel, 2)
    rgb = isRGB(src)
    bi  = BitsPerComponent(src)
    fs  = propNumElements (src, "_ColorRange")  > 0 ? \
          propGetInt      (src, "_ColorRange") == 0 : rgb

    Assert(isclip(src),          "plum_Super: src has to be a video clip!")
    Assert(bi == 32,             "plum_Super: the sample type of src has to be single precision!")
    Assert(isint(pel),           "plum_Super: pel has to be an integer!")
    Assert(pel == 2 || pel == 4, "plum_Super: pel has to be 2 or 4!")

    cores   = SI_PhysicalCores()
    threads = SI_LogicalCores()

    src.ConvertBits(8, dither=-1, fulls=fs)
    AssumeFrameBased()
    rgb ? RGB_to_OPP() : isy() ? last : ExtractY()

    PadBorders(64, 64, 64, 64, "Dilate")
    nnedi3_rpow2(rfactor=pel,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)

    return last }


function plum_Basic(clip src, float "strength", int "a", float "h1", float "h2", int "radius", float "wn", float "scale", int "cutoff") {

    strength   = Default(strength, 3.2)
    a          = Default(a,         32)
    h1         = Default(h1,       6.4)
    h2         = Default(h2,      64.0)
    radius     = Default(radius,     1)
    wn         = Default(wn,      0.48)
    scale      = Default(scale,   0.28)
    cutoff     = Default(cutoff,    24)

    rgb   = isRGB(src)
    bi    = BitsPerComponent(src)
    fs    = propNumElements (src, "_ColorRange")  > 0 ? \
            propGetInt      (src, "_ColorRange") == 0 : rgb

    Assert(isclip(src),              "plum_Basic: src has to be a video clip!")
    Assert(bi == 32,                 "plum_Super: the sample type of src has to be single precision!")
    Assert(isfloat(strength),        "plum_Basic: strength has to be a real number!")
    Assert(strength>1,               "plum_Basic: strength has to be greater than 0!")
    Assert(isint(a),                 "plum_Basic: a has to be an integer!")
    Assert(isfloat(h1),              "plum_Basic: h1 has to be a real number!")
    Assert(isfloat(h2),              "plum_Basic: h2 has to be a real number!")
    Assert(h1>0,                     "plum_Basic: h1 has to be greater than 0!")
    Assert(h2>0,                     "plum_Basic: h2 has to be greater than 0!")
    Assert(isint(radius),            "plum_Basic: radius has to be an integer!")
    Assert(radius>0,                 "plum_Basic: radius has to be greater than 0!")
    Assert(isfloat(wn),              "plum_Basic: wn has to be a real number!")
    Assert(isfloat(scale),           "plum_Basic: scale has to be a real number!")
    Assert(isint(cutoff),            "plum_Basic: radius has to be an integer!")
    Assert(cutoff>0 && cutoff<=100,  "plum_Basic: cutoff must fall in (0, 100]!")

    src32 = rgb ? src.RGB_to_OPP() : src.isy() ? src : src.ExtractY()
    src   = src32.ConvertBits(8, dither=-1, fulls=fs)
    src   = AssumeFrameBased(src)

    c1                  = 0.0980468750214585389567894354907
    c2                  = 0.0124360171036224062543798508968
    h3                  = c1 * h2 * strength * (1.0 - exp(-1.0 / (c1 * strength)))
    cutoff_1            = cutoff
    cutoff_2            = int(max(1.0, c2 * pow(cutoff, 2.0) * log(1.0 + 1.0 / (c2 * cutoff))) + 0.5)
    strength_floor      = floor(strength)
    strength_ceil       = ceil (strength)

    function inline(clip src, int a, float h1, float h2, int radius, float wn, int cutoff_1, float scale, bool fs) {
        cores           = SI_PhysicalCores()
        threads         = SI_LogicalCores()
        sharp           = Deconvolution(src, radius, wn, int(a / 2. + 0.5), scale)
#        sharp           = nnedi3_rpow2(sharp,rfactor=2,nns=4,nsize=0,qual=2,threads=8/2,prefetch=8,SetAffinity=true,MaxPhysCore=false)
        sharp           = nnedi3_rpow2(sharp,rfactor=2,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)
        ref             = nnedi3_rpow2(src,  rfactor=2,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)
        sharp           = NLErrors(ref, a, h1, sharp).ConvertBits(32, fulls=fs)
        dif             = ex_makediff(sharp, ref, fulls=fs)
#        dif             = GaussResize(dif, src.width(), src.height(), src_left=-0.5, src_top=-0.5, p=100) # like PointResize but with centered chroma
        dif             = GaussResize(dif, src.width(), src.height(), p=100) # like PointResize but with centered chroma
        sharp           = ex_adddiff(src, dif, fulls=fs).ConvertBits(32, fulls=fs)
        src32           = src.ConvertBits(32, fulls=fs)
        sharp           = CutOff(src32, sharp, cutoff_1, 0)
        local_error     = NLErrors(src32, radius, h2, src32)
#        local_limit     = ex_makeadddiff(src, local_error)
#        limited         = ex_lutxyz(sharp, local_limit, src, "x z - abs y z - abs > y x ?")
        limited         = ex_lutxyz(sharp, src32, local_error, "x y - abs y z - Y@ abs > Y x ?")
        clp             = Shrink(limited)
        return clp }

    for (i = 0, strength_floor, 1) {
        src             = inline(src, a, h1, h2, radius, wn, cutoff_1, scale, fs )
    }
    if (strength_floor != strength_ceil) {
        sharp_ceil      = inline(src, a, h1, h2, radius, wn, cutoff_1, scale, fs )
        src             = Merge(src, sharp_ceil, strength - strength_floor)
    }
    sharp_nr            = NLErrors(src, a, h3, src)
    clp                 = CutOff(src, sharp_nr, cutoff_2, 0)
    return clp }


function plum_Final(clip src, clip ref, clip "super", clip "superf", int "radius", int "pel", int "sad", float "flexibility", int "strength", float "lstr", float "pstr", int "ldmp", int "cutoff", float "freq_margin") {

    strength    = Default(strength,     3.2)
    radius      = Default(radius,         6)
    pel         = Default(pel,            2)
    sad         = Default(sad,          400)
    flexibility = Default(flexibility, 0.64)
    lstr        = Default(lstr,        1.49)
    pstr        = Default(pstr,       1.272)
    ldmp        = Default(ldmp,           0)
    freq_margin = Default(freq_margin,   20)
    cutoff      = Default(cutoff,        12)

    clr = src
    isy = isy(src)
    rgb = isRGB(src)
    bi  = BitsPerComponent(src)
    fs  = propNumElements (src, "_ColorRange")  > 0 ? \
          propGetInt      (src, "_ColorRange") == 0 : rgb

    isS = Defined(super)
    isF = Defined(superf)

    Assert(isclip(src),          "plum_Final: src has to be a video clip!")
    Assert(bi == 32,             "plum_Final: the sample type of src has to be single precision!")
    Assert(isy(ref),             "plum_Final: corrupted basic estimation!")
    isS ? \
    Assert(isclip(super),        "plum_Final: super has to be a video clip or None!") : nop()
    isS ? \
    Assert(isy(super),           "plum_Final: corrupted super clip!") : nop()
    isF ? \
    Assert(isy(super),           "plum_Final: corrupted superf clip!") : nop()
    Assert(pel == 1 || pel == 2 || pel == 4, "plum_Final: pel has to be 1, 2 or 4!")
    Assert(isint(radius),        "plum_Final: radius has to be an integer!")
    Assert(radius>0,             "plum_Final: radius has to be greater than 0!")
    Assert(isint(pel),           "plum_Final: pel has to be an integer!")
    Assert(isfloat(sad),         "plum_Final: sad has to be a real number!")
    Assert(sad>0,                "plum_Final: sad has to be greater than 0!")
    Assert(isfloat(strength),    "plum_Final: strength has to be a real number!")
    Assert(strength>0,           "plum_Final: radius has to be greater than 0!")
    Assert(isfloat(flexibility), "plum_Final: flexibility has to be a real number!")
    Assert(flexibility>0 || 1.0 >= flexibility, "plum_Final: flexibility has to fall in [0.0, 1.0]!")
    Assert(isint(cutoff),        "plum_Final: cutoff has to be an integer!")
    Assert(cutoff>0 || 100 >= cutoff, "plum_Final: cutoff has to fall in [0, 100]!")
    Assert(isint(freq_margin),   "plum_Final: freq_margin has to be an integer!")
    Assert(freq_margin>0 || 100-cutoff >= freq_margin, "plum_Final: freq_margin must fall in [0, 100-cutoff]!")

    ldmp               = ldmp==0 ? strength + 0.1 : ldmp
    src                = AssumeFrameBased(src.ConvertBits(8, dither=-1, fulls=fs)) # 32-bit is broken in MVTools. So do in 8-bit, also for speed.
    ref                = AssumeFrameBased(ref.ConvertBits(8, dither=-1, fulls=fs))
    super              = isS ? AssumeFrameBased(super)  : Undefined()
    superf             = isF ? AssumeFrameBased(superf) : Undefined()
    src                = rgb ? src.RGB_to_OPP() : isy ? src : src.ExtractY()


    constant           = 0.0009948813682897925944723492342
    me_sad             = round(constant * pow(sad, 2.0) * log(1.0 + 1.0 / (constant * sad)))
    src                = PadBorders(src, 64, 64, 64, 64, "Dilate")
    ref                = PadBorders(ref, 64, 64, 64, 64, "Dilate")
    src3               = Merge(src, ref, flexibility)
    ref                = ex_makediff(ref, src, fulls=fs)
    super3             = isS && isF ? Merge(super, superf, flexibility)    : Undefined()
    superf             = isS && isF ? ex_makediff(superf, super, fulls=fs) : Undefined()
    blankdif           = ex_lut(src, "0")
    supersearch        = MSuper(src,  pelclip=super,  rfilter=4, pel=pel, hpad=0, vpad=0, sharp=2, levels=0, chroma=False, mt=true)
    superdif           = MSuper(ref,  pelclip=superf, rfilter=2, pel=pel, hpad=0, vpad=0, sharp=2, levels=0, chroma=False, mt=true)
    superflex          = MSuper(src3, pelclip=super3, rfilter=2, pel=pel, hpad=0, vpad=0, sharp=2, levels=0, chroma=False, mt=true)
#   vmulti             = MAnalyse(supersearch, radius=radius, overlap=64, blksize=128, search=3, truemotion=False, trymany=True, levels=0, badrange=-24, divide=0, dct=0, chroma=False, mt=true)
    vmulti             = MAnalyse(supersearch, delta=radius, overlap=32, blksize=64, search=3, truemotion=False, trymany=True, levels=0, badrange=-24, divide=0, dct=0, chroma=False, mt=true)
#   vmulti             = MRecalculate(supersearch, vmulti, overlap=32, blksize=64, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, chroma=False, mt=true)
    vmulti             = MRecalculate(supersearch, vmulti, tr=radius, overlap=16, blksize=32, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, chroma=False, mt=true)
    vmulti             = MRecalculate(supersearch, vmulti, tr=radius, overlap= 8, blksize=16, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, chroma=False, mt=true)
    vmulti             = MRecalculate(supersearch, vmulti, tr=radius, overlap= 4, blksize= 8, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, chroma=False, mt=true)
    vmulti             = MRecalculate(supersearch, vmulti, tr=radius, overlap= 2, blksize= 4, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, chroma=False, mt=true)
    vmulti             = MRecalculate(supersearch, vmulti, tr=radius, overlap= 1, blksize= 2, thsad=me_sad, truemotion=False, search=3, smooth=1, divide=0, dct=0, chroma=False, mt=true)
    averaged_dif       = blankdif.MDegrainN(superdif, vmulti, radius, thsad=10000, plane=0, thscd1=8*8*255, thscd2=255, mt=true)
#   averaged_dif       = XYClosest(averaged_dif, ref, blankdif)
    averaged_dif       = ex_lutxy(averaged_dif, ref, blankdif, "x z - abs y z - abs > y x ?")
#    averaged_dif       = ex_lutxy(averaged_dif, ref, "x y min") # blankdif is 0, so actually XYClosest() computes "x y min"
    compensated        = MCompensate(src, superflex, vmulti, thsad=sad, thscd1=8*8*255, thscd2=255).ConvertBits(32, fulls=fs)
    src                = Crop(src,          64, 64, -64, -64)
    averaged_dif       = Crop(averaged_dif, 64, 64, -64, -64)
    compensated        = Crop(compensated,  64, 64, -64, -64)
    bright_limit       = TemporalExtremum(compensated, radius, "max")
    dark_limit         = TemporalExtremum(compensated, radius, "min")
    averaged           = ex_adddiff(src, averaged_dif, fulls=fs)
    clamped            = ex_clamp(averaged, bright_limit, dark_limit, 0, 0, UV=1)
    src                = src.ConvertBits(32, fulls=fs)
    amplified          = ex_lutxy(clamped.ConvertBits(32, fulls=fs), src, Format("x y - A@ abs {lstr} / 1 {pstr} / ^ {strength} * A sgn * A dup * dup {ldmp} + / * y +"), scale_inputs=fs?"allf":"all")
    clp                = CutOff(src, amplified, cutoff, freq_margin)

    clp                = rgb ? OPP_to_RGB(clp) : !isy ? CombinePlanes(clp, clr, planes="YUV", pixel_type=PixelType(clr)) : clp

    return clp }





#####################################
#                                   #
#   HELPER FUNCTIONS for feisty2's  #
#                                   #
#####################################



    function genpelclip (clip src, clip "src2", int "pel") {

        bi      = BitsPerComponent(src)
        fs      = propNumElements (src,"_ColorRange")  > 0 ? \
                  propGetInt      (src,"_ColorRange") == 0 : false

        pel     = Default(pel, 4)
        src2d   = Defined(src2)

        cores   = SI_PhysicalCores()
        threads = SI_LogicalCores()

        u2x     =                   nnedi3_rpow2(src, rfactor=2,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)
        u2x2    = !src2d ? nop() :  nnedi3_rpow2(src2,rfactor=2,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)
        u4x     =                   nnedi3_rpow2(src, rfactor=4,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)
        u4x2    = !src2d ? nop() :  nnedi3_rpow2(src2,rfactor=4,nns=1,nsize=0,qual=1,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)
        dif     = !src2d ? nop() : (pel==2 ? ex_makediff (u2x, u2x2, fulls=fs) : ex_makediff (u4x, u4x2, fulls=fs))
        clp     =  src2d ? dif   : (pel==2 ? u2x : u4x)
        return clp }


    function getvectors (clip src, int "pel", int "tr", int "thsad") {

        pel        = Default(pel,          4)
        tr         = Default(tr,           6)
        thsad      = Default(thsad,      400)

        supersoft  = MSuper (src, rfilter=4, pel=pel, chroma=False, hpad=32, vpad=32, sharp=2, levels=0)
        supersharp = MSuper (src, rfilter=2, pel=pel, chroma=False, hpad=32, vpad=32, sharp=2, levels=0)
        vmulti     = MAnalyse (supersoft, badrange=-24,overlap=16, blksize=32, divide=2, delta=tr, search=3,   dct=7, chroma=False, truemotion=True, trymany=True, levels=0, multi=true)
        vmulti     = MRecalculate (supersoft,  vmulti, overlap=8,  blksize=16, divide=2, tr=tr, thsad=thsad/2, dct=8, chroma=False, truemotion=True, search=3, smooth=1)
        vmulti     = MRecalculate (supersharp, vmulti, overlap=4,  blksize=8,  divide=2, tr=tr, thsad=thsad/2, dct=6, chroma=False, truemotion=True, search=3, smooth=1)
        vmulti     = MRecalculate (supersharp, vmulti, overlap=2,  blksize=4,  divide=0, tr=tr, thsad=thsad/2, dct=5, chroma=False, truemotion=True, search=3, smooth=1)
        return vmulti }


    function gauss (clip src, int "p") {

        p     = Default(p, 30)

        upsmp = GaussResize(src,   src.width() * 2, src.height() * 2, p=100)
        clp   = GaussResize(upsmp, src.width(),     src.height(),     p=p)
        return clp }


    # Hipass recovery (recovers sharp range from 'sharp' clip to 'src' clip)
    function hipass (clip src, clip sharp, int "p") {

        lp            = Default(p, 16)

        clp1          = gauss (sharp, p=lp)
        clp2          = gauss (src,   p=lp)

        clp           = ex_makeadddiff (sharp, clp1, clp2)

        return clp }

    # Strange filter, blurs mid-freqs of 'low' and replace its hi-freqs with those of 'hi'
    function CutOff(clip low, clip hi, int p, int margin) {

        clp1          = gauss(hi,  p+margin)
        clp2          = gauss(low, p)

        clp           = ex_makeadddiff(hi, clp1, clp2)

        return clp }


    function Deconvolution(clip src, int radius, float wn, int fr, float scale) {
        pad4               = nmod(radius+fr,4)
        src                = PadBorders(src, pad4, pad4, pad4, pad4, "Dilate")
#       sharp              = FQSharp(src, x=radius, y=radius, wn=wn, fr=fr, scale=scale, line=0)
        sharp              = F2QSharp(src.SeparateFields(), x=radius, y=radius, wn=wn, frad=round(fr), scale=scale, psf="line").Weave()
        sharp              = CutOff(src, sharp, 1, 0)
        clp                = Crop(sharp, pad4, pad4, -pad4, -pad4)
        return clp }


    function Shrink(clip src) {
        med                = src.removegrain(4)
        dif                = ex_makediff(med, src)
        convD              = dif.removegrain(12)
        DD                 = ex_makediff(dif, convD)
        convDD             = DD.removegrain(12)
        dif                = ex_lutxyz(DD, convDD, dif, "x y - A@ x * 0 < z A abs x abs < A x ? z swap - ?")
        convD              = dif.removegrain(12)
        clp                = ex_lutxyz(dif, convD, src, "y abs x abs > y z + z ? ")
        return clp }


    function NLErrors(clip src, int a, float h, clip rclip) {
        pad                = AddBorders(src, a, a, a, a)
        rclip              = Defined(rclip) ? AddBorders(rclip, a, a, a, a) : Undefined()
        nlm                = KNLMeansCL(pad, d=0, a=a, s=0, h=h, rclip=rclip)
        clp                = Crop(nlm, a, a, -a, -a)
        return clp }


    function TemporalExtremum(clip src, int radius, string mode) {

        src
        var = "yzabcdefghijk" clpr = "" expr = " x "
        for (i = 1, radius * 2, 1) {
            clpr = clpr + Format("SelectEvery(radius * 2 + 1, {i}),")
            expr = expr + MidStr(var,i,1) + " " + mode + " "
        }
        clp = "Expr(SelectEvery(radius * 2 + 1, 0)," + clpr + """ " """ + expr + """ " )"""
    return Eval(clp) }


    function maxmulti (clip src, clip "start", int "a", int "tr") {
        std             = Defined(start)
        a               = Default(a, 0)
        tr              = Default(tr,6)
        start           = !std ? ex_lut(  SelectEvery (src, tr*2+1, 0), "0") : start
        max             = ex_logic(start, SelectEvery (src, tr*2+1, a), "max")
        a               = a+1
        clp             = a == tr*2+1 ? max : maxmulti (src, start=max, tr=tr, a=a)
        return clp }

    function minmulti (clip src, clip "start", int "a", int "tr") {
        std             = Defined(start)
        a               = Default(a, 0)
        tr              = Default(tr,6)
        start           = !std ? ex_lut(  SelectEvery (src, tr*2+1, 0), "range_max") : start
        min             = ex_logic(start, SelectEvery (src, tr*2+1, a), "min")
        a               = a+1
        clp             = a == tr*2+1 ? min : minmulti (src, start=min, tr=tr, a=a)
        return clp }


    function ThrMerge(clip flt, clip src, clip "ref", float "thr", float "elast") {

        bi    = BitsPerComponent(flt)
        rgb   = isRGB(flt)
        fs    = propNumElements (flt,"_ColorRange")  > 0 ? \
                propGetInt      (flt,"_ColorRange") == 0 : rgb

        thr   = Default(thr, 0.0009765625)
        ref   = Defined(ref)   ? ref   : src
        elast = Defined(elast) ? elast : thr / 2.

        elast = ex_bs(elast, 32, bi, fs, flt=true)
        thr   = ex_bs(thr,   32, bi, fs, flt=true)

        BDif  = ex_lut(src, "0", scale_inputs="none")
        PBLD  = ex_lutxyza(src, BDif, flt, ref, Format("z x - 0 max {thr} {elast} + a z - 0 max Z@ - 2 {elast} * / * y {elast} Z + {thr} - 2 {elast} * / * +"), scale_inputs="none")
        NBLD  = ex_lutxyza(src, BDif, flt, ref, Format("x z - 0 max {thr} {elast} + a z - 0 max Z@ - 2 {elast} * / * y {elast} Z + {thr} - 2 {elast} * / * +"), scale_inputs="none")
        BLD   = ex_makeadddiff(PBLD, NBLD, src)
        clp   = ex_lutxyza(flt, ref, BLD, src, Format("x y - abs X@ {thr} {elast} + < X {thr} {elast} - > z x ? a ?"), scale_inputs="none")

        return clp }



#   function XYClosest(clip src1, clip src2, clip ref) {
#       clp               = ex_lutxyz(src1, src2, ref, "x z - abs y z - abs > y x ?")
#       return clp }





#######################
###                 ###
###      OTHER      ###
###                 ###
#######################





## ex_DGSharpen() - Wrapper for DGSharpen by Donald A. Graft
##
## DGSharpen() is a fast stand-alone CUDA filter that implements limited sharpening like the well-known filter LimitedSharpenFaster().
## Supports YUV format in any bitdepth
##
function ex_DGSharpen(clip a, float "str") {

    w   = width (a)
    h   = height(a)
    is42= is420(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : false

    str = Default(str,      1.0)
    Assert(!isRGB(a), "ex_DGSharpen: clip has to be in YUV format")

    a
    !is42 ? ConverttoYUV420(chromaresample="point")       : last
    bi>8 && bi!= 16 ? ConvertBits(16, fulls=fs, fulld=fs) : last

    DGSharpen(str)

    ConvertBits(bi, dither=bi==32?-1:1, fulls=fs, fulld=fs)
    !is42 ? MergeChroma(a) : last }






### SharpenComplex2() by ??? (??-11-2011)
### port of MPC-HC's Sharpen Complex 2 to AviSynth+
###
### https://www.avisynth.nl/index.php/SharpenComplex2_source
### https://forum.doom9.org/showthread.php?t=158385
###
### ExTools port by Dogway (04-09-2021)
###
### str0 is the non-edge unsharp amount, default 2.0
### str1 is the edge unsharp amount, default 1.125
### k0 is the non-edge blur kernel, default "3 14 3"
### k1 is the edge blur kernel, default "1 1 1"
### edgethr is the threshold for an edge on an arbitrary scale, default 0.2
### if debug is true, then the edge mask is returned instead
###
### Recommendation: just use a regular unsharp filter, don't bother with this
### unless you're going to set the unsharp amount/kernels (in which case this
### script actually becomes useful; the default edge/non-edge filters are
### sufficiently similar to be pointless).
###
### Function Definition:
###    (
###    clip,
###    float str0=2.0 (0.0 to 4.0 by 0.1),
###    float str1=1.125 (0.0 to 4.0 by 0.1),
###    float k0=0.5 (0.0 to 4.0 by 0.1),
###    int k1=1 (0 to 4 by 1),
###    float "edgethr"=0.2 (0.0 to 1.0 by 0.1),
###    bool "debug"=false,
###    )
###
function SharpenComplex2(clip src, float "str0", float "str1", float "k0", int "k1", float "edgethr", bool "debug") {

    str0 = Default(str0,   2.0) # corresponds to CoefFlou
    str1 = Default(str1, 1.125) # corresponds to Sharpen_val1 * 9

    k0   = Default(k0,     0.5) # "3 14 3" ~ Gaussian blur with sigma^2=0.3
    k1   = Default(k1,       1) # "1 1 1"  ~ Gaussian blur with sigma^2=1/3=0.333...
                                # the 3 14 3 kernel is derived from assuming linear interpolation in the original code
                                # you can set it to other kernels based on other interpolators, but bear in
                                # mind that blurrier interpolators lead to more sharpening
    dg   = Default(debug, false)
    thr  = Default(edgethr,0.2) # corresponds to SharpenEdge

    thr  = round(255.*thr)

    src

    unsharp0=ex_lutxy(src,ex_boxblur(k0, mode="weighted"), Format("x dup y - {str0} * +"), UV=1)
    unsharp1=ex_lutxy(src,ex_boxblur(k1, mode="mean"),     Format("x dup y - {str1} * +"), UV=1)

    msk = ex_edge(mode="sobel", lo=thr-5, hi=thr, UV=1)

    dg ? msk.grayscale() : ex_merge(unsharp0, unsharp1, msk, UV=1) }



##################################
## subtle sharpening effect by raffriff42
## based on an idea by videofred
##
## @ multi   - suggested range 1 to 5; no effect if multi<=0
## @ sharpen - strength of each Sharpen operation; default 0.6
## @ blur    - strength of each Blur    operation; default 0.3
##
## Simple sharpening without limiting
function ex_MultiSharpen(clip C, int multi, float "sharpen", float "blur") {

    shrp = Min(Max(0.0, Default(sharpen, 0.6)), 1.0)
    blr  = Min(Max(0.0, Default(blur,    0.3)), 1.0)

    C
    for (i=multi, 1, -1) {
        Sharpen(shrp).ex_blur(blr)
    }

    return last }



##  pSharpen() by ilpippo80 (02-07-2005)
##  Performs two-point sharpening to avoid overshoot.
##
##  https://forum.doom9.org/showthread.php?p=681194#post681194
##
##  ported to MaskTools2 by colours     (02-08-2015)
##  ss_x and ss_y fix    by colours     (16-03-2016)
##  HBD mod              by real.finder (31-10-2020)
##  Optimized            by Dogway      (19-10-2021)
##
## Function Definition:
##    (
##    clip,
##    int strength=25 (0 to 100 by 1),
##    int threshold=75 (0 to 100 by 1),
##    float ss_x=1.0 (0.0 to 2.0 by 0.1),
##    float ss_y=1.0 (0.0 to 2.0 by 0.1),
##    float dest_x=1.0 (0.0 to 2.0 by 0.1),
##    float dest_y=1.0 (0.0 to 2.0 by 0.1),
##    )
##
function pSharpen (clip clp, int "strength", int "threshold", float "ss_x", float "ss_y", int "dest_x", int "dest_y") {

    ox  = clp.width ()
    oy  = clp.height()
    rgb = isRGB(clp)
    bi  = BitsPerComponent(clp)
    fs  = propNumElements (clp,"_ColorRange")  > 0 ? \
          propGetInt      (clp,"_ColorRange") == 0 : rgb

    strength  = Default(strength,  25)    # 0 to 100. Strength of the sharpening (up until the overshoot correction threshold, see below). Value of 100 will set all pixels to either their local min or max; value of 0 will make the filter do nothing.
    threshold = Default(threshold, 75)    # 0 to 100. How close to the min/max a pixel can be sharpened before the overshoot correction (compression) kicks in. Higher values make the overshoot correction more of a hard limiting, while lower values soften the compression. Value of 0 makes the filter do nothing.
    ss_x      = Float(Default(ss_x, 1.0)) # The horizontal and vertical supersampling factors, respectively. Higher values will reduce aliasing, at the expense of speed.
    ss_y      = Float(Default(ss_y, 1.0))
    dest_x    = Default(dest_x, ox)       # Final image size; defaults to the dimensions of the input clip.
    dest_y    = Default(dest_y, oy)

    strength  = min(100,max(0,strength))
    threshold = min(100,max(0,threshold))
    ss_x      = max(1.0, ss_x)
    ss_y      = max(1.0, ss_y)

    # oversampling
    ss  = ss_x!=1.0 || ss_y!=1.0 ? clp.lanczosresize(nmod(ox*ss_x,8),nmod(oy*ss_y,8)) : clp
    clp = ss

    # calculating the max and min in every 3x3 square
    # and normalizing max and val to values from 0 to (max-min)
    nmax = ss.ex_luts(mode="range" ,UV=1)
    nval = ss.ex_luts(mode="range-",UV=1)

    # initializing the strings used to obtain the output luma value
    s    = strength  / 100.
    t    = threshold / 100.
    x0   = t*(1.0-s)/(1.0-(1.0-t)*(1.0-s))
    expr = Format("z 0.5 * Z^ y z / 2 * 1 - abs Y@ {x0} < {s} 1 = y Z = 0 Z ? Y 1 {s} - / ? Y 1 {t} - * {t} + ? y Z - sgn * 1 + Z * 0 max x +")

    # calculates the new luma value pushing it towards min or max
    # and "z +" normalizing val to values from min to max
    clp = ex_lutxyz(ss.mt_inpand(U=2,V=2),nval,nmax,expr,UV=1,scale_inputs=fs?"allf":"all")

    # resizing the image to the output values
    clp = ss_x!=1.0 || ss_y!=1.0 || dest_x!=ox || dest_y!=oy ? clp.lanczosresize(dest_x,dest_y) : clp

    return clp }




# XSharpen - by real.finder (01-05-2021)
# Optimized  by Dogway      (19-10-2021)
#
# AviSynth+ port of the VirtualDub XSharpen filter
#
function ex_XSharpen(clip clp, float "strength", float "threshold", int "UV") {

    rgb = clp.IsRGB()
    bi  = BitsPerComponent(clp)

    str = Default(strength, 128)
    thr = Default(threshold,  8)
    UV  = Default(UV,  rgb ? 3 : 1)

    thr  = ex_bs(thr, 8, bi, fulls=true, flt=true)
    str  = str / 256.

    ex_edge(clp, Format("x[-1,1] A@ x[0,1] B@ max x[1,1] C@ max x[-1,0] D@ max x[0,0] E@ max x[1,0] F@ max x[-1,-1] G@ max x[0,-1] H@ max x[1,-1] I@ max M@
                         x - Y@ x A B min C min D min E min F min G min H min I min N@ - X@ min {thr} < X Y < N M ? x - {str} * x + x ?"), UV=UV) }



# CASm
#
# An improved sharpening script based on CAS and aWarpSharp2
#
# Original work      by Atak_Snajpera for RipBot264
# Renamed and modded by JKyle  2021-04-22 for StaxRip
# Optimization       by Dogway 2021-09-17
#
# ---Requirements---
#
#    CAS
#    ExTools
#    GradePack
#
# ---Parameters---
#
# float "strength" (Default: 1.0)
# ----------------------------
# Same as CAS's parameter.
# Must be between 0.0 and 1.0.
#
function CASm(clip a, float "strength") {

    str = Default(strength, 1.0)

    IntenMsk = a.ExtractY().ex_levels(0,2,255,0,255,tv_range=false)
    EdgeMsk  = IntenMsk.ex_edge("sobel",0,80,invert=true).ex_levels(0,2,255,0,255,tv_range=false).ex_boxblur(1,mode="weighted")
    ShrpMsk  = ex_blend(IntenMsk, EdgeMsk, mode="Multiply", opacity=1.0, tv_range=false)
    Shrp     = CAS(a, str)
    video    = ex_merge(a, Shrp, ShrpMsk, UV=2)

    return video }

