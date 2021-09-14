#############################################################################
###                                                                       ###
###        Sharpeners Pack v1.2  (14-09-2021)                             ###
###                                                                       ###
###        Collection of high quality sharpeners for AviSynth+            ###
###                                                                       ###
###                                                                       ###
###   bacondither:                                                        ###
###       Adaptive Sharpen                                                ###
###   Dogway:                                                             ###
###       ex_unsharp                                                      ###
###       SharpenComplex2                                                 ###
###       UnsharpMask_HBD                                                 ###
###   Didée:                                                              ###
###       ex_ContraSharpening                                             ###
###       SeeSaw                                                          ###
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
### Adaptive_Sharpen() - v1.4 (12-09-2021)
###
### https://forum.doom9.org/showthread.php?t=182881
###
###                        by Dogway (Jose Linares)
###
###
### AviSynth+ port of HLSL Adaptive Sharpen shader by bacondither
### Process in 32-bit or 8-bit (4% slower). Avoid 12-16-bit as it loses precision.
### Since this is CPU based it's 10 times slower compared to the GPU shader.
###
### The premise is similar to SlopeBend() by Didée, it reads:
### "It sharpens the picture by adjusting the slope of the gradient values inbetween the local min/max interval.
###  Effectively, edges are sharpened without oversharpening (halos) (but risk to make them jaggy)."
###
### Dependencies: > AviSynth+ 3.7.1 test12 (https://forum.doom9.org/showthread.php?t=181351)
###                 ExTools
###
### Example: Adaptive_Sharpen(1.0)
###
####################################

function Adaptive_Sharpen(clip a, float "str", float "slope", float "H_over", float "L_over", float "H_compr_lo", float "H_compr_hi", float "L_compr_lo", float "L_compr_hi", float "scale_lim", float "scale_cs", \
                                  float "dW_lothr", float "dW_hithr", float "lowthr_mxw", float "pm_p", float "a_offset", float "tv_range", float "UV", float "fulls") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

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
    UV           = Default(UV,              rgb ? 3 : 1)
    fs           = Default(fulls,           rgb)

    r_max    = 1./ex_bs(255,      8, bi, fulls=fs)
    a_eps    = ex_bs(2.55,        8, bi, fulls=fs)
    a_offset = ex_bs(a_offset,    8, bi, fulls=fs)
    a_off_ep = a_offset - a_eps
    lthr_m   = ex_bs(lowthr_mxw,  8, bi, fulls=fs)
    lthr_r   = (1. / (0.1 - 0.01)) * r_max
    sbe_h    = ex_bs(216.75,      8, 32)
    sbe_m    = ex_bs(14.28,       8, bi, fulls=fs) - a_offset * 3
    sbe_l    = ex_bs(7.65,        8, 32)
    sd_off   = ex_bs(5.1,         8, bi, fulls=fs)
    L_over   = ex_bs(L_overshoot, 8, 32)
    D_over   = ex_bs(D_overshoot, 8, 32)
    dW_lothr = ex_bs(dW_lothr,    8, bi, fulls=fs)
    dW_hithr = ex_bs(dW_hithr,    8, bi, fulls=fs)
    dW       = 1. / (dW_hithr - dW_lothr)

    # Custom weighted DoG edge detection
    edge = Format("x[0,0] A^ x[0,1] B^ x[-1,0] C^ x[1,0] D^ x[0,-1] E^ x[0,2] F^ x[0,-2] G^ x[2,0] H^ x[-2,0] I^ x[-1,1] J^ x[-1,-1] K^ x[1,1] L^ x[1,-1] M^ " \
                 +"B E D C + + + 2 * J K L M + + + A 4 * + + 0.062501 * S@ F - abs S G - abs S H - abs S I - abs + + + 0.230001 * S J - abs S K - abs S L - abs S M - abs + + + 0.920001 * S B - abs S E - abs S D - abs S C - abs + + + 1.150001 * S A - abs 1.380001 * + + +
                   {r_max} * 0.650001 ^ 2 S {r_max} -2.466666681 1.442695040888963 * * * ^ 0.900001 * 0.266666666 + 0 1 clip * range_max * {a_offset} +")

    edge = isy ? Expr(a, edge                                                                , optSingleMode=false) : \
      UV == 1  ? Expr(a, edge, ""                                                            , optSingleMode=false) : \
                 Expr(a, edge, ex_UVexpr(edge, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi), optSingleMode=false)


    # Similar Bound Edge (soft_if(), fast linear approx)
    sbe = ex_dlut(Format("
           x[-1,1] A@ x[0,1]  B@ max x[1,1] C@ x[-1,0] D@ max max x[1,0] E@ x[-1,-1] F@ max x[0,-1] G@ x[1,-1] H@ max max max
           x[0,2]  I@ x[-2,0] J@ max x[2,0] K@ x[0,-2] L@ max max x[0,0] X@ max max {r_max} * {sbe_l} + M^
           x[0,3]   I        B  {sbe_m} + + + {r_max} * M / {sbe_h} -
           x[0,-3]  G        L  {sbe_m} + + + {r_max} * M / {sbe_h} - *
           x[-3,0]  J        D  {sbe_m} + + + {r_max} * M / {sbe_h} -
           x[3,0]   E        K  {sbe_m} + + + {r_max} * M / {sbe_h} - * +
           x[-1,2]  x[-2,1]  A  {sbe_m} + + + {r_max} * M / {sbe_h} -
           x[2,-1]  x[1,-2]  H  {sbe_m} + + + {r_max} * M / {sbe_h} - * +
           x[1,2]   x[2,1]   C  {sbe_m} + + + {r_max} * M / {sbe_h} -
           x[-2,-1] x[-1,-2] F  {sbe_m} + + + {r_max} * M / {sbe_h} - * +
           2 - 0.909090909 * 0 1 clip dup dup * swap 2 * 3 swap - * range_max *"), bi, fs)

    sbe = isy ? Expr(edge, sbe                                                               , optSingleMode=false) : \
      UV == 1 ? Expr(edge, sbe, ""                                                           , optSingleMode=false) : \
                Expr(edge, sbe, ex_UVexpr(sbe, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi), optSingleMode=false)


    # Sharp difference
    sharpdiff = ex_dlut(Format("
                y {a_offset} - {dW_lothr} - {dW} * 0 1 clip
                dup dup * swap 2 * 3 swap - * Z^

                Z dup 0.86602540378 * swap 1 swap - 0.500001 * + dup * X^
                1 Z - Z + dup * Y^
                Z dup 0.54772255751 * swap 1 swap - 1.41421356237 * + dup * Z^

                x[0,0] T@ x[0,1]   B@ - abs
                       T  x[-1,0]  C@ - abs
                       T  x[1,0]   D@ - abs
                       T  x[0,-1]  E@ - abs + + +
                       T  x[-1,1]  J@ - abs
                       T  x[1,1]   L@ - abs
                       T  x[-1,-1] K@ - abs
                       T  x[1,-1]  M@ - abs + + + 0.250001 * + 3 * {sd_off} + {r_max} * A^

                       J  x[-1,2]     - abs
                       J  x[-2,1] N@  - abs
                       J          B   - abs
                       J          C   - abs + + +
                       J  x[0,2]  F@  - abs T@
                       J  x[-2,0] I@  - abs W@ + 0.500001 * + {r_max} * A swap / Y min C0^

                       L  x[1,2]  O@  - abs
                       L  x[2,1]  P@  - abs
                       L          B   - abs
                       L          D   - abs + + +
                       L          F   - abs U@
                       L  x[2,0]  H@  - abs V@ + 0.500001 * + {r_max} * A swap / Y min C2^

                       K  x[-1,-2]    - abs
                       K  x[2,-1] Q@  - abs
                       K          E   - abs
                       K          C   - abs + + +
                       K  x[0,-2] G@  - abs JJ@
                       K          I   - abs LL@ + 0.500001 * + {r_max} * A swap / Y min C5^

                       M  x[1,-2] R@  - abs
                       M          Q   - abs
                       M          E   - abs
                       M          D   - abs + + +
                       M          G   - abs KK@
                       M          H   - abs MM@ + 0.500001 * + {r_max} * A swap / Y min C7^

                       F          O   - abs
                       F          N   - abs
                       F          B   - abs
                       F x[0,3]       - abs + + +
                                        T
                                        U + 0.500001 * + {r_max} * A swap / Z min C8^

                       G          R   - abs
                       G x[-2,-1] S@  - abs
                       G          E   - abs
                       G x[0,-3]      - abs + + +
                                        JJ
                                        KK + 0.500001 * + {r_max} * A swap / Z min C9^

                       I          S   - abs
                       I          N   - abs
                       I          C   - abs
                       I x[-3,0]      - abs + + +
                                        W
                                        LL + 0.500001 * + {r_max} * A swap / Z min C10^

                       H          Q   - abs
                       H          P   - abs
                       H          D   - abs
                       H x[3,0]       - abs + + +
                                        V
                                        MM + 0.500001 * + {r_max} * A swap / Z min C11^

                C8  C9  0.250001 * + C0 max 0.250001 max C0 + 0.500001 * C0^
                C8  C10 0.250001 * + C2 max 0.250001 max C2 + 0.500001 * C2^
                C9  C11 0.250001 * + C5 max 0.250001 max C5 + 0.500001 * C5^
                C10 C11 0.250001 * + C7 max 0.250001 max C7 + 0.500001 * C7^

                y[-1,1]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LA@ C0  * WA^
                y[0,1]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LB@ X   * WB^
                y[1,1]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LC@ C2  * WC^
                y[-1,0]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LD@ X   * WD^
                y[1,0]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LE@ X   * WE^
                y[-1,-1] {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LF@ C5  * WF^
                y[0,-1]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LG@ X   * WG^
                y[1,-1]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LH@ C7  * WH^
                y[0,2]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LI@ C8  * WI^
                y[-2,0]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LJ@ C9  * WJ^
                y[2,0]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LK@ C10 * WK^
                y[0,-2]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.980001 * 2.97 swap - * * 0.01 + LL@ C11 * WL^

                J {r_max} * 0.06 + 2.4 ^ WA *
                B {r_max} * 0.06 + 2.4 ^ WB * +
                L {r_max} * 0.06 + 2.4 ^ WC * +
                C {r_max} * 0.06 + 2.4 ^ WD * +
                D {r_max} * 0.06 + 2.4 ^ WE * +
                K {r_max} * 0.06 + 2.4 ^ WF * +
                E {r_max} * 0.06 + 2.4 ^ WG * +
                M {r_max} * 0.06 + 2.4 ^ WH * +
                F {r_max} * 0.06 + 2.4 ^ WI * +
                I {r_max} * 0.06 + 2.4 ^ WJ * +
                H {r_max} * 0.06 + 2.4 ^ WK * +
                G {r_max} * 0.06 + 2.4 ^ WL * +

                WA WB WC WD WE WF WG WH WI WJ WK WL + + + + + + + + + + + / abs 0.416666666 ^ 0.06 - L^
                LA LB LC LD LE LF LG LH LI LJ LK LL + + + + + + + + + + + 0.083333333 *  T^

                y {a_offset} - abs {r_max} * 3.5 ^ {curveslope} * {curve_height} * 0.625001 + {curve_height} swap / V^

                T V * 0.01 + x {r_max} * L - * range_max * range_half +"), bi, fs)

    sharpdiff = isy ? Expr(a, edge, sharpdiff                                                                     , optSingleMode=false) : \
            UV == 1 ? Expr(a, edge, sharpdiff, ""                                                                 , optSingleMode=false) : \
                      Expr(a, edge, sharpdiff, ex_UVexpr(sharpdiff, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi), optSingleMode=false)

    # Soft limiter. Anti-ringing block
    sharp = ex_dlut(Format("
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
            U W                                    max W^
            V W                                    max W^

            W X 2 * + x 3 * max Y + 0.250001 * {r_max} * M^
            C B 2 * + x 3 * min A + 0.250001 * {r_max} * N^

            M x {r_max} * X@ - abs X N - abs min D^
            1.0001 D - X - {L_over} min D + P^
            0.0001 D - X + {D_over} min D + N^

            1 {scale_cs} - {scale_lim} * P {scale_cs} * + P min P^
            1 {scale_cs} - {scale_lim} * N {scale_cs} * + N min N^

            {L_compr_high} {L_compr_low} - z {r_max} * Z@ * {L_compr_low} + CX@ y range_half - {r_max} * 0 1 clip Y@ 0 max dup {pm_p} ^ swap swap2 *
            swap P 24 * min 2 * P / 2.718281828 swap ^ dup 1 - swap 1 + / P *
            abs {pm_p} ^ 1 CX - abs * + 1 {pm_p} / ^

            {D_compr_high} {D_compr_low} - Z              * {D_compr_low} + CY@ Y 0 min dup {pm_p} ^ swap swap2 *
            swap N 24 * min 2 * N / 2.718281828 swap ^ dup 1 - swap 1 + / N *
            abs {pm_p} ^ 1 CY - abs * + 1 {pm_p} / ^ -

            X + range_max *
            "), bi, fs)

            isy     ? Expr(a, sharpdiff, sbe, sharp                                                                 , optSingleMode=false) : \
            UV == 1 ? Expr(a, sharpdiff, sbe, sharp, ""                                                             , optSingleMode=false) : \
                      Expr(a, sharpdiff, sbe, sharp, ex_UVexpr(sharp, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi), optSingleMode=false) }





######################################################
###
###  ex_unsharp()    by Dogway (04-09-2021)
###
### Simple and fast unsharp mask filter for a (not matching) replacement of ASharp, UnsharpHQ, UnsharpMask_avsi and VariableBlur's Unsharp.
### "ex_unsharp(1,str=4,th=0)" is equivalent to "unsharp(vary=1, varc=1, strength=4)", although less haloing...
### ...due to using binomial blur instead of box blur, same with UnsharpMask_avsi(512,1,0)

function ex_unsharp(clip a, float "rad", float "radV", float "str", int "th", int "UV", bool "fulls") {

    rgb  = isRGB(a)
    isy  = isy(a)
    bi   = BitsPerComponent(a)

    rd = Default(rad,  3)            # integers from 0 to inf (also 0.15, 0.3, 0.5 and integers up to 14 -single float AVSValue limit-)
    rv = Default(radV, rd)           # integers from 0 to inf (also 0.15, 0.3, 0.5 and integers up to 14 -single float AVSValue limit-)

    fbox  = rd == 1    && rv == 1
    fbox2 = rd == 0.5  && rv == 0.5
    fbox3 = rd == 0.3  && rv == 0.3
    fbox4 = rd == 0.15 && rv == 0.15

    str = Default(str,  0.5)
    th  = Default(th,     8)
    UV  = Default(UV,    rgb  ? 3 : 1)
    fs  = Default(fulls, rgb)

    rd  = max(rd>1?round(rd):rd, 0)
    rv  = max(rv>1?round(rv):rv, 0)
    th  = ex_bs(th, 8, bi, fulls=fs)

    Assert (rd < 15 || rv < 15, "Maximum radius reached")

    krnh = ""  krnv = ""  plsh = ""  plsv = ""  divx=0  divy=0
    if (!fbox || !(rd<1 || rv<1)) {

            krnlsz = ceil(2 * rd)
            krnlrd = krnlsz/2
            wgc    = binom_coeffs(krnlsz, krnlrd)

        for (px  = -krnlrd, krnlrd, 1) {
            wg   = binom_coeffs(krnlsz, krnlsz-(abs(px)+krnlrd))
            krnh = px  > 0 ? px == krnlrd ? Format(krnh + "x[{px},0] x[-{px},0] x[0,0] {wgc} * ") : \
                                            Format(krnh + "x[{px},0] x[-{px},0] + {wg} * ")       : krnh
            plsh = px ==  -krnlrd || px < 0 ? plsh : plsh + "+ "
            divx = wg + divx
           }

            krnlsz = ceil(2 * rv)
            krnlrv = krnlsz/2
            wgc    = binom_coeffs(krnlsz, krnlrv)

        for (py  = -krnlrv, krnlrv, 1) {
            wg   = binom_coeffs(krnlsz, krnlsz-(abs(py)+krnlrv))
            krnv = py  > 0 ? py == krnlrv ? Format(krnv + "x[0,{py}] x[0,-{py}] x[0,0] {wgc} * ") : \
                                            Format(krnv + "x[0,{py}] x[0,-{py}] + {wg} * ")       : krnv
            plsv = py ==  -krnlrv || py < 0 ? plsv : plsv + "+ "
            divy = wg + divy
           }   }


    strv =       fbox             ? "x[-1,1] x[1,1] x[-1,-1] x[1,-1] + + + 0.500001 * x[0,1] x[-1,0] x[1,0] x[0,-1] x[0,0] 2 * + + + + + 0.125001 *"               : \
                 fbox2            ? "x[0,1] x[-1,0] x[0,0] 3  * x[1,0] x[0,-1] + + + + 0.142857143 *"                                                              : \
                 fbox3            ? "x[0,1] x[-1,0] x[0,0] 6  * x[1,0] x[0,-1] + + + + 0.100001    *"                                                              : \
                 fbox4            ? "x[0,1] x[-1,0] x[0,0] 12 * x[1,0] x[0,-1] + + + + 0.062501    *"                                                              : \
                 rv == 0.5        ? "x[0,1]  x[0,0] 5  * x[0,-1] + + 0.142857143 *"                                                                                : \
                 rv == 0.3        ? "x[0,1]  x[0,0] 8  * x[0,-1] + + 0.100001    *"                                                                                : \
                 rv == 0.15       ? "x[0,1]  x[0,0] 16 * x[0,-1] + + 0.055555555 *"                                                                                : \
                                    krnv + plsv + (rv > 7 ? string(divy)+" /" : string(1./divy)+" *")

    strh =       rd == 0.5        ? "x[-1,0] x[0,0] 5  * x[1,0]  + + 0.142857143 *"                                                                                : \
                 rd == 0.3        ? "x[-1,0] x[0,0] 8  * x[1,0]  + + 0.100001    *"                                                                                : \
                 rd == 0.15       ? "x[-1,0] x[0,0] 16 * x[1,0]  + + 0.055555555 *"                                                                                : \
                                    krnh + plsh + (rd > 7 ? string(divx)+" /" : string(1./divx)+" *")


    strv = strv + (th > 0 ? Format(" x swap - Y@ abs {th} > Y {str} * x + x ?") : Format(" x swap - {str} * x +") )
    strh = strh + (th > 0 ? Format(" x swap - Y@ abs {th} > Y {str} * x + x ?") : Format(" x swap - {str} * x +") )

    rv == 0 ?      a                                                                  : \
    isy     ? Expr(a,    strv                                                       ) : \
    UV == 1 ? Expr(a,    strv, ""                                                   ) : \
              Expr(a,    strv, ex_UVexpr(strv, UV, bi, rgb, fs), scale_inputs="none")
    rd == 0 || fbox || fbox2 || fbox3 || fbox4  ? last                                : \
    isy     ? Expr(last, strh                                                       ) : \
    UV == 1 ? Expr(last, strh, ""                                                   ) : \
              Expr(last, strh, ex_UVexpr(strh, UV, bi, rgb, fs), scale_inputs="none") }



# Port of UnsharpMask_avsi.avsi by real.finder

function UnsharpMask_HBD(clip clp, float "str", int "rad", float "thres", int "UV", bool "fulls") {

    bi  = BitsPerComponent(clp)
    rgb = isRGB(clp)

    str    = Default(str,   64)
    rd     = Default(rad,    3)
    thres  = Default(thres,  8)
    UV     = Default(UV,    rgb ? 3 : 1)
    fs     = Default(fulls, rgb)

    rd    = rd - 1
    str   = str/128.
    thres = ex_bs(thres, 8, bi, fulls=fs)

    blurclip = clp.ex_boxblur(rd, mode="mean", UV=UV)

    ex_lutxy(clp, blurclip, Format("x y - A@ abs {thres} > A {str} * x + x ?"), UV=UV) }






### SharpenComplex2() by ??? (??-11-2011)
### port of MPC-HC's Sharpen Complex 2 to AviSynth+
###
### http://www.avisynth.nl/index.php/SharpenComplex2_source
### http://forum.doom9.org/showthread.php?t=158385
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

function SharpenComplex2(clip src, float "str0", float "str1", float "k0", int "k1", float "edgethr", bool "debug", bool "fulls") {

    str0 = Default(str0, 2.0)   # corresponds to CoefFlou
    str1 = Default(str1, 1.125) # corresponds to Sharpen_val1 * 9

    k0 = Default(k0, 0.5)  # "3 14 3" ~ Gaussian blur with sigma^2=0.3
    k1 = Default(k1,   1)  # "1 1 1" ~ Gaussian blur with sigma^2=1/3=0.333...
    #the 3 14 3 kernel is derived from assuming linear interpolation in the original
    #code; you can set it to other kernels based on other interpolators, but bear in
    #mind that blurrier interpolators lead to more sharpening

    dg  = Default(debug,false)
    thr = Default(edgethr,0.2)  # corresponds to SharpenEdge
    fs  = Default(fulls,  false)

    thr=round(255*thr)

    src

    unsharp0=ex_lutxy(src,ex_boxblur(k0, mode="weighted"), Format("x dup y - {str0} * +"), UV=1, fulls=fs)
    unsharp1=ex_lutxy(src,ex_boxblur(k1, mode="mean"),     Format("x dup y - {str1} * +"), UV=1, fulls=fs)

    msk = ex_edge(mode="sobel", lo=thr-5, hi=thr, UV=1, fulls=fs)

    dg? msk.grayscale() : ex_merge(unsharp0, unsharp1, msk, UV=1, fulls=fs) }




#######################
###                 ###
###     DIDÉE's     ###
###                 ###
#######################

######################################################
###
###  Contra()                   (15 Dec 2007) by Didée
###
###  (https://forum.doom9.org/showthread.php?p=1076276#post1076276)
###  (https://forum.doom9.org/showthread.php?p=1076491#post1076491)
###
###  ex_ContraSharpening() v3.2 (14 Sept 2021)
###  - Mod and port to ExTools by Dogway
###
###
### Contra(): sharpen the denoised clip, but don't add more to any pixel than what was removed previously.
### Enable 'MC' (default false) for temporal limiting sharpening versus the default spatial limiting.
###
### In final version 2.0d ContraHD() was merged, to allow proper HD sharpening.
### When using 'MC' (temporal limiting) global variables of (before denoising), source MSuper and forward and
### backward compensated motion vectors are necessary as: Super, cb1 and cf1, if used as a standalone function.
### Don't know who made (mod) it, so I can't give proper credits, sorry.

function ex_ContraSharpening(clip denoised, clip original, bool "HD", bool "MC", int "overshoot", bool "fulls") {

    HD        = Default(HD,    false)
    MC        = Default(MC,    false)  # Enable to switch from spatial to temporal limiting (output a bit sharper than original though)
    os        = Default(overshoot, 0)  # Raise to allow more sharpening when temporal limiting (MC=true)
    fs        = Default(fulls, false)

    MC ? Eval("""
    cb1  = original.MCompensate(Super, cb1, mt=true)
    cf1  = original.MCompensate(Super, cf1, mt=true)
    pmax = ex_lutxyz(original, cb1, cf1, "x y max z max",UV=1)
    pmin = ex_lutxyz(original, cb1, cf1, "x y min z min",UV=1)""") : nop()

    s    = denoised.ex_MinBlur(HD?2:1,UV=1,fulls=fs)                                                          # Damp down remaining spots of the denoised clip.

    allD = ex_makediff(original,denoised,UV=1,fulls=fs)                                                       # The difference achieved by the denoising.
    ssD  = ex_makediff(s,HD?s.removegrain(12,-1).\
                              removegrain(20,-1):\
                            s.removegrain(12,-1),UV=1,fulls=fs)                                               # The difference of a simple kernel blur.
    ssDD = ssD.repair(HD?ssD.repair(allD,1,-1):allD,1,-1)                                                     # Limit the difference to the max of what the denoising removed locally.

    dif  = "x y + range_half - "
    MC ? ex_lutxyza(denoised,ssD,pmax,pmin,os==0?dif+"z min a max":Format(dif+"z {os} + min a {os} - max"),UV=1,fulls=fs) : \
         ex_lutxyz (denoised,ssDD,ssD,"y range_half - X@ abs z range_half - Y@ abs < X Y ? x +",UV=1,fulls=fs) # abs(diff) after limiting may not be bigger than before.
                                                                                                               # Apply the limited difference " x +" (Sharpening is just inverse blurring)
    }



######################################################
###
###  SeeSaw v0.3i (02 Jan 2006) by Didée
###
###  https://forum.doom9.org/showthread.php?p=760935#post760935
###
###    0.3f (13 Dec 2006) by foxyshadis (port to masktools2)
###    0.3g (15 Dec 2015) by StainlessS (Force int call arguments to user script function float params to be explicit floats)
###    0.3h (31 Jan 2020) by real.finder (Update to avs+ and HBD)
###    0.3i (05 Sep 2021) by Dogway (Sanitize, port to ExTools -mix mod- and optimize expressions)
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
 \               float "bias",   int "Smode",    int "sootheT",  int "sootheS", float "ssx",     float "ssy", bool "fulls") {


    isy = input.isy()
    clp = isy ? input : input.ExtractY()
    bi  = BitsPerComponent(input)

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
    fs       = Default( fulls,        false)

    Szp     = Szp     / pow(Sstr, 1.0/4.0) / pow( (ssx+ssy)/2.0, 1.0/2.0 )
    SdampLo = SdampLo / pow(Sstr, 1.0/4.0) / pow( (ssx+ssy)/2.0, 1.0/2.0 )

    ox    = clp.Width()
    oy    = clp.Height()
    xss   = m4_sh(ox*ssx)
    yss   = m4_sh(oy*ssy)
    NRL   = ex_bs(NRlimit,  8, bi, fulls=fs)
    NRL2  = ex_bs(NRlimit2, 8, bi, fulls=fs)
    NRLL  = ex_bs(NRlimit2 * 100.0/bias - 1, 8, bi, fulls=fs)
    limit = abs(Slimit)
    SLIM  = ex_bs(limit, 8, bi, fulls=fs)
    BIAS1 = bias
    BIAS2 = 100-bias

    denoised = Defined(denoised) ? denoised.ExtractY() : ex_lutxy(clp, clp.removegrain(4, -1), Format("y x {NRL} - x {NRL} + clip"),     fulls=fs)

    NRdiff = ex_makediff(clp, denoised, fulls=fs)
    tame   = ex_lutxy(clp, denoised, Format("x {NRLL} + y < x {NRL2} + x {NRLL} - y > x {NRL2} - x {BIAS1} * y {BIAS2} * + 0.01 * ? ?"), fulls=fs)
    head   = tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, 4, fs)
    head   = head.mt_merge(tame, tame.mt_edge("prewitt", 0, 255, 0, 0, U=1, V=1).mt_expand().removegrain(20, -1))

    (ssx==1.0 && ssy==1.0) ? repair(tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head, 1, -1)                                                                              : \
                             repair(tame.lanczosresize(xss, yss).ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head.bicubicresize(xss, yss, -.2, .6), 1, -1).lanczosresize(ox, oy)

    ex_SootheSS2(last, tame, sootheT, sootheS, false, fs)
    sharpdiff = ex_makediff(tame, last, fulls=fs)

    (NRlimit==0) ? clp : ex_lutxy(clp, NRdiff, Format("y range_half {NRL} + > x {NRL} - y range_half {NRL} - < x {NRL} + x y range_half - - ? ?"),     fulls=fs)

      Slimit>=0  ? ex_lutxy(last, sharpdiff,   Format("y range_half {SLIM} + > x {SLIM} - y range_half {SLIM} - < x {SLIM} + x y range_half - - ? ?"), fulls=fs) : \
                   ex_lutxy(last, sharpdiff,   Format("y range_half == x dup y range_half - Y@ abs 1 {limit} / ^ Y dup abs / * - ?"),                  fulls=fs)

    isy ? last : CombinePlanes(last, input, planes="YUV", sample_clip=input) }


#
#  SeeSaw2 ( modified for standard definition dvds. by jeremy duncan november 11, 2008 )
#
# - If you use a different resolution than standard definition dvd. Disable supersampling ssx by setting it to 1.0
#
# =======  Main function  =======

function SeeSaw2( clip  input, clip "denoised",
 \               int   "NRlimit",int "NRlimit2",
 \               float "Sstr",   int "Slimit", float "Spower", float "SdampLo", float "SdampHi", float "Szp",
 \               float "bias",   int "Smode",    int "sootheT",  int "sootheS", float "ssx",     float "ssy", bool "PAL", bool "fulls") {

    isy = input.isy()
    clp = isy ? input : input.ExtractY()
    bi  = BitsPerComponent(input)

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

    Szp     = Szp     / pow(Sstr, 1.0/4.0) / pow( (ssx+ssy)/2.0, 1.0/2.0 )
    SdampLo = SdampLo / pow(Sstr, 1.0/4.0) / pow( (ssx+ssy)/2.0, 1.0/2.0 )

    ox    = clp.Width()
    oy    = clp.Height()
    xss   = m4_sh(ox*ssx, PAL ? 2 : 1)
    yss   = m4_sh(oy*ssy, PAL ? 2 : 1)
    NRL   = ex_bs(NRlimit,  8, bi, fulls=fs)
    NRL2  = ex_bs(NRlimit2, 8, bi, fulls=fs)
    NRLL  = ex_bs(NRlimit2 * 100.0/bias - 1, 8, bi, fulls=fs)
    limit = abs(Slimit)
    SLIM  = ex_bs(limit, 8, bi, fulls=fs)
    BIAS1 = bias
    BIAS2 = 100-bias

    denoised = Defined(denoised) ? denoised.ExtractY() : ex_lutxy(clp, clp.removegrain(1, -1), Format("y x {NRL} - x {NRL} + clip"), fulls=fs)

    NRdiff = ex_makediff(clp, denoised, fulls=fs)
    tame   = ex_lutxy(clp, denoised, Format("x {NRLL} + y < x {NRL2} + x {NRLL} - y > x {NRL2} - x {BIAS1} * y {BIAS2} * + 0.010001 * ? ?"), fulls=fs)
    head   = tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, 4, fs)
    head   = head.mt_merge(tame, tame.mt_edge("prewitt", 0, 255, 0, 0, U=1, V=1).mt_expand().removegrain(1, -1))

    (ssx==1.0 && ssy==1.0) ? repair(tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head, 1, -1)                                                                                 : \
                             repair(tame.spline36resize(xss, yss).ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head.bicubicresize(xss, yss, 0.75, 1.0), 1, -1).lanczosresize(ox, oy)

    ex_SootheSS2(last, tame, sootheT, sootheS, true, fs)
    sharpdiff = ex_makediff(tame, last, fulls=fs)

    (NRlimit==0) ? clp : ex_lutxy(clp, NRdiff, Format("y range_half {NRL} + > x {NRL} - y range_half {NRL} - < x {NRL} + x y range_half - - ? ?")    , fulls=fs)

      Slimit>=0  ? ex_lutxy(last, sharpdiff,   Format("y range_half {SLIM} + > x {SLIM} - y range_half {SLIM} - < x {SLIM} + x y range_half - - ? ?"), fulls=fs) : \
                   ex_lutxy(last, sharpdiff,   Format("y range_half == x dup y range_half - Y@ abs 1 {limit} / ^ Y dup abs / * - ?")                 , fulls=fs)

    isy ? last : CombinePlanes(last, input, planes="YUV", sample_clip=input) }


# =======  Modified sharpening function  =======

function ex_sharpen22(clip clp, float strength, float power, float zp, float lodmp, float hidmp, int rgmode, bool fulls) {

    bi    = BitsPerComponent(clp)
    fs    = Default(fulls, false)
    STR   = strength
    PWR   = 1.0/power
    ZRP   = ZP
    ZRPr  = 1. / ZP
    DMP   = lodmp
    HDMPr = 1. / hidmp
    HDMP  = (hidmp==0) ? "" : Format("A abs {HDMPr} * dup dup dup * * * 1 + /")

    ex_lutxy( clp, clp.RemoveGrain(rgmode,-1), Format("x dup y == swap dup dup y - A@ abs {ZRPr} * {PWR} ^ {ZRP} * {STR} * A dup * dup {DMP} + / * A dup abs / * "+HDMP+" + ?"), UV=1, fulls=fs, scale_inputs=fs ? "allf" : "all") }



# =======  Soothe() function to stabilize sharpening  =======

function ex_SootheSS2(clip sharp, clip orig, int "sootheT", int "sootheS", bool "SootheSS2", bool "fulls") {

    bi       = BitsPerComponent(sharp)
    sootheT  = Default(sootheT, 25 )
    sootheS  = Default(sootheS,  0 )
    sootheT  = (sootheT > 100) ? 100 : (sootheT < -100) ? -100 : sootheT
    sootheS  = (sootheS > 100) ? 100 : (sootheS < 0)    ?    0 : sootheS
    ST       = 100 - abs(sootheT)
    SSPT     = 100 - abs(sootheS)
    SootheSS2= Default(SootheSS2, false)
    fs       = Default(fulls,     false)

    ex_makediff(orig,sharp,UV=1,fulls=fs)

    (sootheS==0) ? last : ex_lutxy( last, last.removegrain(SootheSS2 ? 1 : 20, -1),
     \             Format("x range_half - X@ y range_half - Y@ * 0 < X 0.010001 * {SSPT} * range_half + X abs Y abs > x {SSPT} * y 100 {SSPT} - * + 0.010001 * x ? ?"),UV=1,fulls=fs)

    (sootheT==0) ? last : ex_lutxy( last, last.temporalsoften(1,255,0,32,2),
     \             Format("x range_half - X@ y range_half - Y@ * 0 < X 0.010001 * {ST}   * range_half + X abs Y abs > x {ST}   * y 100 {ST}   - * + 0.010001 * x ? ?"),UV=1,fulls=fs)

    (sootheT>-1) ? last : ex_lutxy( last, last.temporalsoften(1,255,0,32,2),
     \             Format("x range_half - X@ y range_half - Y@ * 0 < X 0.010001 * {ST}   * range_half + X abs Y abs > x {ST}   * y 100 {ST}   - * + 0.010001 * x ? ?"),UV=1,fulls=fs)

    ex_makediff(orig,last,UV=1,fulls=fs) }




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
function FineSharp(clip c, float "sstr", int "mode", float "cstr", float "xstr", float "lstr", float "pstr", float "ldmp", float "hdmp", bool "fulls")
{
    bi    = BitsPerComponent(c)
    sstr  = Default(sstr, 2.0 )     #  strength of sharpening, 0.0 up to ??
    mode  = Default(mode, 1   )     #  1 to 3, weakest to strongest. When negative -1 to -3, a broader kernel for equalisation is used.

    _cstr = spline(sstr, 0,0, 0.5,0.1, 1.0,0.6, 2.0,0.9, 2.5,1.00, 3.0,1.09, 3.5,1.15, 4.0,1.19, 8.0,1.249, 255.0,1.5)
    _cstr = (mode>0) ? _cstr : pow(_cstr,1./1.25)

    cstr  = Default(cstr, _cstr)    #  strength of equalisation (recommended 0.5 to 1.25)
    xstr  = Default(xstr, 0.19 )    #  strength of XSharpen-style final sharpening, 0.0 to 1.0 (but, better don't go beyond 0.249 ...)

    #  Viscera parameters
    lstr  = Default(lstr, 1.49 )    #  modifier for non-linear sharpening
    pstr  = Default(pstr, 1.272)    #  exponent for non-linear sharpening
    ldmp  = Default(ldmp, sstr+0.1) # "low damp", to not overenhance very small differences (noise coming out of flat areas)
    hdmp  = Default(hdmp,     0.01) # "high damp", this damping term has a larger effect than ldmp when the sharp-difference is larger than 1, vice versa.
    fs    = Default(fulls, false)

    LSTR  = 1. / lstr
    PSTR  = 1. / pstr
    rg    = mode>0 ? 12 : 20

    b = (abs(mode)==1) ? c.removegrain(12,-1).removegrain(4, -1)
    \ : (abs(mode)==2) ? c.removegrain(4, -1).removegrain(12,-1)
    \ : (abs(mode)==3) ? c.removegrain(4, -1).removegrain(12,-1).removegrain(4,-1) : c

    shrpD = ex_lutxy(c,b,Format("x y - A@ abs {LSTR} * {PSTR} ^ {SSTR} * A dup abs {HDMP} + / * A dup * dup {LDMP} + / * 0 max 128 +"), UV=1, fulls=fs, scale_inputs=fs ? "allf" : "all")

    shrp = (sstr<0.01) ?    c : c.ex_adddiff(shrpD,UV=1,fulls=fs)

    shrp = (cstr<0.01) ? shrp : shrp.ex_makediff(shrpD.ex_lut(Format("x range_half - {CSTR} * range_half +"),fulls=fs).removegrain(rg,-1), UV=1, fulls=fs)

           (xstr<0.01) ? shrp : ex_lutxy(shrp, shrp.removegrain(20,-1),"x dup y - 9.690001 * +", UV=1, fulls=fs).repair(shrp,12,0).mergeluma(shrp,1.0-xstr) }




##################################
##
## NonlinUSM: local contrast by Didée, (01-02-2012)
##
## Non-Linear Unsharp Masking
##     http://forum.doom9.org/showthread.php?p=1555234#post1555234
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
## @ str   - default 0.7   (0.3 = mild;  0.7 = medium;  1 = strong;  3 = very strong;  18 = massive)
## @ z     - default 6     (3.0 = subtle;    16  = massive)
## @ pow   - default 1.6   (1.0 = oversharp; 4.0 = mild)
## @ rad   - default 9     (0.6 = sharpen;   8-20 = strong;  30-50 = medium;  60 = mild)
## @ ldmp  - default 0.001 (block overlap? 0.01 = a little smoother?)
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

function NonlinUSM(clip o, float "str", float "z", float "pow", float "rad", float "ldmp", int "UV", bool "fulls") {

    rgb  = isRGB(o)
    bi   = BitsPerComponent(o)

    str = default(str,  0.7)   # strength
    z   = default(z,    6.0)   # zero point
    pow = default(pow,  1.6)   # power
    rad = default(rad,  9.0)   # radius for "gauss"
    ldmp= default(ldmp, 0.001) # damping for verysmall differences
    UV  = Default(UV,    rgb ? 3 : 1)
    fs  = Default(fulls, rgb)

    z    = ex_bs(z,    8, bi, fulls=fs)
    zd   = 1. / z
    ldmp = ex_bs(ldmp, 8, bi, fulls=fs)
    pw   = 1. / pow

    w = o.width()
    h = o.height()

    g = o.ex_GaussianBlur(rad*0.725-0.125)  # Parametrized to match original

    ex_lutxy(o, g, Format("x dup y - A@ abs {zd} * {pw} ^ {z} * {str} * A dup * dup {ldmp} + / * A dup abs 0.001 + / * + dup 0 > swap1 x ?"), UV=UV, fulls=fs)

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
# str:       Not really usable yet - leave at '100'. Bigger gives jagged artefacts, smaller gives ... an interesting effect.
# rad:       The distance to search for the current pixel's upper & lower boundary.
#            The bigger, the stronger the effect, but the slower the script runs.
#            range: 1-5 / default: 2
# overshoot: not yet implemented
# ss_x,ss_y: If needed, the filter may work supersampled. Generally it's not needed, but comes handy for
#            "uneven" sharpening like i.e. resizing 1:1 PAR --> anamorphic PAR, or for strength values > 100.
# soft:      Pre-blurring before searching local maxima & minima. Not very useful.
#
# 10.08.2004 - got the method initially working for the first time ("how to correctly implement?!"),
#              after having it in mind for several months.
#

function SlopeBend( clip a, int "str", int "rad", int "overshoot", float "ss_x", float "ss_y", bool "soft", bool "fulls") {

    str       = Default( str,       75 )
    rad       = Default( rad,        1 )
    overshoot = Default( overshoot,  1 )
    ss_x      = Default( ss_x,     1.0 )
    ss_y      = Default( ss_y,     1.0 )
    soft      = Default( soft,   false )
    fs        = Default( fulls,  false )

    Sstr      = str/100.0
    rad       = max(min(rad,5),1)
    overshoot = max(overshoot,0)
    ox        = a.width()
    oy        = a.height()
    ss        = ss_x != 1.0 || ss_y != 1.0

    clp = isy(a) ? a : a.ExtractY()

    bright_limit = soft ? clp.ex_boxblur(0.5,mode="weighted") : clp #.sharpen(1.0)#.blur(1.58)

    dark_limit   = bright_limit.ex_inpand(rad).ex_boxblur(rad,mode="weighted").mt_inflate().mt_deflate()
    dark_limit   = ss ?   dark_limit.lanczosresize(round(ox*ss_x/8)*8,round(oy*ss_y/8)*8) : dark_limit

    bright_limit = bright_limit.ex_expand(rad).ex_boxblur(rad,mode="weighted").mt_deflate().mt_inflate()
    bright_limit = ss ? bright_limit.lanczosresize(round(ox*ss_x/8)*8,round(oy*ss_y/8)*8) : bright_limit


    minmaxavg    = Merge(bright_limit,dark_limit)  # Pseudomedian

    tmp          = ss ? clp.lanczosresize(round(ox*ss_x/8)*8,round(oy*ss_y/8)*8) : clp

    assign_dark  = ex_lutxy (tmp, minmaxavg, "y x - 0 < 0 range_max ?", fulls=fs)

    map_to_max   = ex_lutxyz(tmp, minmaxavg, bright_limit, Format("z x - A@ dup dup * swap x y - abs B@ + C@ / A B 4 ^ * C 4 ^ / + A / {Sstr} ^ A * 0 max"), fulls=fs) # masked with outline
    map_to_min   = ex_lutxyz(tmp, minmaxavg, dark_limit,   Format("x z - A@ dup dup * swap x y - abs B@ + C@ / A B 4 ^ * C 4 ^ / + A / {Sstr} ^ A * 0 max"), fulls=fs) # masked with inline

    max_mapped   = ex_makediff(bright_limit, map_to_max, dif=false, fulls=fs)
    min_mapped   = ex_adddiff (dark_limit,   map_to_min, dif=false, fulls=fs)

    ex_merge(max_mapped, min_mapped, assign_dark, UV=1, fulls=fs)

    #normsharp2
    ss ? lanczosresize(ox,oy) : last
    isy(a) ? last : CombinePlanes(last, a, planes="YUV", sample_clip=a) }



# Didée's Median Enhancer Sharpener (12-10-2012)
# http://forum.doom9.org/showthread.php?p=1595531#post1595531
#
# ExTools port  by Dogway           (05-09-2021)
#
# Requires MedianBlur2 for str > 3: http://avisynth.nl/index.php/MedianBlur2
# Also known as DDSharp(). 'pass' concept imported from DDSharp()

function MedianSharp (clip a, int "str", float "pwr", int "UV", bool "fulls") {

    str = Default( str,      3 )
    pwr = Default( pwr,   1.62 )
    UV  = Default( UV,       3 )
    fs  = Default( fulls, false)

    bi   = BitsPerComponent(a)
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

    ex_lutxy(a, c, Format("x dup y - A@ abs {pwr2} * {rpwr} ^ {pwr3} * A dup abs {pwr} + / * +"), UV=UV, scale_inputs=fs ? "allf" : "all") }



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

function DetailSharpen(clip c, int "z", float "sstr", int "power", int "ldmp", int "mode", bool "med", bool "fulls") {

    z     = Default( z,      4 )
    sstr  = Default( sstr, 1.5 )
    power = Default( power,  4 )
    ldmp  = Default( ldmp,   1 )
    mode  = Default( mode,   1 )
    med   = Default( med,   false )
    fs    = Default( fulls, false )

    bi    = BitsPerComponent(c)
    ldmp  = ex_bs(max(ldmp, 0), 8, bi, fulls=fs)
    zs    = ex_bs(z,            8, bi, fulls=fs)
    strzi = ex_bs(sstr*z,       8, bi, fulls=fs)
    rpwr  = 1. / power

    denoised = mode == 1 ?  c.removegrain(20,-1) : c.removegrain(12,-1)
    denoised = med ? denoised.removegrain(4,-1)  : denoised

    ex_lutxy(c, denoised, Format("x y == x dup dup y - A@ abs 1 {zs} / * {rpwr} ^ {strzi} * A dup abs {ldmp} + / * + ? "), UV=1, fulls=fs) }






#######################
###                 ###
###   *.mp4 guy     ###
###                 ###
#######################


### SSSharpFaster() (Super Slow Sharpen Faster)
### SSSharp's mod by LaTo (12-10-2012)
###
### http://forum.doom9.org/showthread.php?t=142682&page=4#post1218074
###
### port by Dogway (05-09-2021)
###
function SSSharpFaster(clip c, float "str", int "hthr", int "hbias", bool "fulls") {

    str      = Default(str,    6.0)
    hthr     = Default(hthr,   256)
    hbias    = Default(hbias, -128)
    fs       = Default(fulls,  false)

    bi    = BitsPerComponent(c)
    w     = c.width()
    h     = c.height()
    hbias = ex_bs(hbias, 8, bi, fulls=fs)

    s = c.spline36resize(w*2,h*2)
    a = s.awarpsharp2(chroma=2, depth=2, blur=1, thresh=250)


    Mblur = s.removegrain(4 ,-1)
    Gblur = s.removegrain(20,-1)
    Hmask = ex_lutxy(Mblur, Gblur, Format("y x - abs {hthr} * {hbias} -"), UV=1, fulls=fs)


    ex_lutxyza(s, Gblur, a, Hmask, Format("x dup y      - {str}     * + X@
                                           x dup z swap - {str} 3 / * + -
                                           a range_max / * X swap -"), UV=1, fulls=fs)
    spline36resize(w,h) }



### SSSharp() (Super Slow Sharpen)
### 0.0 by *.mp4 guy (02-12-2007)
### 0.1 by Didée     (03-12-2007)
### 0.2 by Dogway    (04-09-2021)
###
### https://forum.doom9.org/showthread.php?t=132330
###
### Rad must be a multiple of 0.25 when ss=true, or 1 when ss=false. usable range is 0.25 to ~8,
### using a rad that is not close to the radius of the bluring present in your source will
### give suboptimal results. Higher iter, with lower strength will give more precise masking
### (less halos for same sharpening) but will be very slow.
###
### SSSharp(ssw=true, iter=1, strength=1, rad=1)
### SSSharp(ssw=true, iter=2, strength=3)
###
### Dependencies:
###     aWarpSharpMT
###     VariableBlur.dll (unsharp)
###     vsDeGrainMedian

function SSSharp(clip c, float "rad", bool "ssw", float "strength", int "iter", bool "ss", int "denoise"){

    rad      = Default(rad, 0.25)
    ssw      = Default(ssw, true)
    strength = Default(strength, 4)
    iter     = Default(iter, 1)
    ss       = Default(ss, true)
    denoise  = Default(denoise, iter)

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


# Without dependencies except ExTools
function SSSharpEX(clip c, float "rad", bool "ssw", float "strength", int "iter", bool "ss", int "denoise", bool "fulls") {

    rad     = Default(rad, 0.25)               # 0.15, 0.25, 0.50, 1, 2, 3...
    ssw     = Default(ssw, true)
    str     = Default(strength, 4)
    iter    = Default(iter, 1)
    ss      = Default(ss, true)
    denoise = Default(denoise, iter)
    fs      = Default(fulls,  false)

    c
    w    = Width(c)
    h    = Height(c)
    iter = min(iter,denoise)

    rad = rad < 0.25 ? 0.30 : \
          rad < 0.50 ? 0.50 : \
          rad < 1.00 ? 1.00 : round(rad)

    sswc = ssw ? c.SSW() : c
    for (i = 0, iter, 1) {
        us = "ex_merge(ex_unsharp(rad, str=str-1, th=0, UV=1, fulls=fs), sswc, spline16resize((ss ? w*4 : w), (ss ? h*4 : h)).                          \
                                                                               halomaskM(hbias=-128, hthr=256, agmrad=(ss ? round(rad) : round(rad/2.))).\
                                                                               spline16resize(w, h), UV=1, fulls=fs)"
        for (k = 0, denoise, 1) {
            dot = i == denoise ? "" : "."
            us = us + """.ex_median(mode="DGM3", UV=1, fulls=fs)""" + dot
    } }
    return Eval(us) }


function halomaskM(clip c, int "hthr", int "hbias", int "agmrad", bool "fulls") {

    hthr   = Default(hthr,   256)
    hbias  = Default(hbias, -128)
    agmrad = Default(agmrad, 1)   # from 1 to 3 max
    fs     = Default(fulls,  false)

    bi    = BitsPerComponent(c)
    hbias = ex_bs(hbias, 8, bi, fulls=fs)

    Mblur = (agmrad==1) ? c.removegrain(4,-1) : c.ex_median(agmrad==2 ? "median5" : "median7", UV=1, fulls=fs)
    Gblur =               c.ex_boxblur(agmrad*2, mode="weighted", UV=1, fulls=fs)

    ex_lutxy(Mblur, Gblur, Format("y x - abs {hthr} * {hbias} +"), UV=1, fulls=fs) }


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

    spline16resize(w, h) }





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
### some artifacts, similar quality than SSSharp.

Function ReCon(clip c, float "str", float "strv", float "rad", float "radv", int "lmode", int "thresh", bool "fulls") {

    strh   = Default(str,      7)
    strv   = Default(strv,  strh)
    Radh   = Default(Rad,      1)
    Radv   = Default(Radv,  Radh)
    lmode  = Default(lmode,    1)
    thresh = Default(thresh, 720)
    fs     = Default(fulls,  false)

    bi      = BitsPerComponent(c)
    Rad     = Radh
    Radh    = Radh * 2
    Radv    = Radv * 2
    thres   = ex_bs(    thresh,      8, bi, fulls=fs)
    thres2  = ex_bs(pow(thresh,0.5), 8, bi, fulls=fs)
    thr2gh8 = 1./sqrt(thresh)
    thr2gv8 = thr2gh8
    strh8   = strh
    strv8   = strv
    thrstrh = pow(thr2gh8,0.5) * strh8
    thrstrv = pow(thr2gv8,0.5) * strv8
    un      = ex_bs(1, 8, bi, fulls=fs)
    si      = fs ? "allf" : "all"

    expr = Format("x y - dup dup abs {un} + dup swap2 * swap {thres} {un} >= {thres2} {thres} ? + / - range_half +")


    Max_V = ex_luts( C, mode = "max", pixels = ex_shape(Radv, mode="vertical", center=false), expr = expr, UV=1, fulls=fs)
    Min_V = ex_luts( C, mode = "min", pixels = ex_shape(Radv, mode="vertical", center=false), expr = expr, UV=1, fulls=fs)
    Med_V = ex_luts( C, mode = "med", pixels = ex_shape(Radv, mode="vertical", center= true), expr = expr, UV=1, fulls=fs)


    minmaxmed_v   = ex_lutxyz(Max_V, Min_V, Med_V, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.062501 *
                                                                               X                     Y   min B@ 0.250001 * +
                                                                           B A B - - 0 max z range_half - abs + 0.343750 * + "), UV=1, fulls=fs)

    Max_H = ex_luts( C, mode = "max", pixels = ex_shape(Radh, mode="horizontal", center=false), expr = expr, UV=1, fulls=fs)
    Min_H = ex_luts( C, mode = "min", pixels = ex_shape(Radh, mode="horizontal", center=false), expr = expr, UV=1, fulls=fs)
    Med_H = ex_luts( C, mode = "med", pixels = ex_shape(Radh, mode="horizontal", center= true), expr = expr, UV=1, fulls=fs)


    minmaxmed_h   = ex_lutxyz(Max_H, Min_H, Med_H, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.062501 *
                                                                               X                     Y   min B@ 0.250001 * +
                                                                           B A B - - 0 max z range_half - abs + 0.343750 * + "), UV=1, fulls=fs)

    Blur_V =                C.NLLV(   1,true, fs)
    Blur_V = Rad > 1 ? Blur_V.NLLV(Radv,true, fs) : Blur_V

    Sharp_V = lmode == 0 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - z * {thr2gv8} {strv8} * * 128 + "),                                              UV=1, scale_inputs=si, fulls=fs) : C
    Sharp_V = lmode == 1 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - X@ abs z > X z * {thr2gv8} {strv8} * * 128 + X z 0.5 ^ * {thrstrh} * 128 + ? "), UV=1, scale_inputs=si, fulls=fs) : Sharp_V
    Sharp_V = lmode == 2 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - X@ abs z > X z * {thr2gv8} {strv8} * * 128 + z 0 > X {strv8} * 128 + 128 ? ? "), UV=1, scale_inputs=si, fulls=fs) : Sharp_V
    Sharp_V = lmode == 3 ? ex_lutxyz(C, Blur_V, minmaxmed_v, Format(" x y - X@ abs z > X z * {thr2gv8} {strv8} * * 128 + X {strv8} * 128 + ? "),             UV=1, scale_inputs=si, fulls=fs) : Sharp_V
    Sharp_V = lmode == 4 ? ex_lutxy (C, Blur_V,              Format(" x y - {strv8} * 128 + "),                                                              UV=1, scale_inputs=si, fulls=fs) : Sharp_V

    Blur_H =                C.NLLH(   1,true, fs)
    Blur_H = Rad > 1 ? Blur_H.NLLH(Radh,true, fs) : Blur_H

    Sharp_H = lmode == 0 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - z * {thr2gh8} {strh8} * * 128 + "),                                              UV=1, scale_inputs=si, fulls=fs) : C
    Sharp_H = lmode == 1 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - X@ abs z > X z * {thr2gh8} {strh8} * * 128 + X z 0.5 ^ * {thrstrv} * 128 + ? "), UV=1, scale_inputs=si, fulls=fs) : Sharp_H
    Sharp_H = lmode == 2 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - X@ abs z > X z * {thr2gh8} {strh8} * * 128 + z 0 > X {strh8} * 128 + 128 ? ? "), UV=1, scale_inputs=si, fulls=fs) : Sharp_H
    Sharp_H = lmode == 3 ? ex_lutxyz(C, Blur_H, minmaxmed_h, Format(" x y - X@ abs z > X z * {thr2gh8} {strh8} * * 128 + X {strh8} * 128 + ? "),             UV=1, scale_inputs=si, fulls=fs) : Sharp_H
    Sharp_H = lmode == 4 ? ex_lutxy (C, Blur_H,              Format(" x y - {strh8} * 128 + "),                                                              UV=1, scale_inputs=si, fulls=fs) : Sharp_H

    ex_lutxyz(C, Sharp_V, Sharp_H, "x y z + + range_half - range_half -", UV=1, fulls=fs) }





### blah()   by *.mp4 guy (09-06-2010)
### https://forum.doom9.org/showthread.php?p=1406843#post1406843
###
### Optimized and ported by Dogway (04-09-2021)
###
### After reading this post by Didée I decided to
### take a crack at the problem of sharpening an interpolated or lowpassed image. Out of curiosity I tried the resulting function
### on a few difficult to sharpen non-interpolated sources (GITS R1 Special eddition, etc.), and it did very well (imo, of course).
### So here is a new, general sharpening function. Right now its named "blah". Because naming things is difficult, and naming it
### after what it is actually doing would require a paragraph long function call.
###
###
### Defaults are intended for strong sharpening on 2x upscaled material. For normal sharpening, set de to 0.02, str to 3 and cstr
### to 0.75 and go from there. The failure modes are as graceful as I can reasonably get them, considering the strength of the
### sharpening required. Also, the degree of sharpening that can be "gotten away with" varies pretty wildly by source.
###
### str = strength of highpass sharpening default 4
### cstr = strength of contrast sharpening default 1, values above 1 will cause halos
### de = de-emphasis strength default 0.2
### re = re-emphasis strength defaults to de/2
###

function blah(Clip c, Int "str", int "strv", float "de", float "dev", float "re", float "rev",  float "cstr", float "cstrv", bool "fulls") {

    strh  = Default(Str, 4)
    strv  = Default(strv, strh)
    deh   = Default(de, 0.2)
    dev   = Default(dev, deh)
    reh   = Default(re, deh/2)
    rev   = Default(rev, reh)
    cstrh = Default(cstr, 0.5)
    cstrv = Default(cstrv, cstrh)
    fs    = Default(fulls,  false)

    isy     = isy(c)
    bi      = BitsPerComponent(c)

    strv2   = ex_bs(pow(strv,0.5), 8, bi, fulls=fs)
    strh2   = ex_bs(pow(strh,0.5), 8, bi, fulls=fs)
    strv    = ex_bs(strv,          8, bi, fulls=fs)
    strh    = ex_bs(strh,          8, bi, fulls=fs)

    un      = ex_bs(1, 8, bi, fulls=fs)

    rev = 20./rev
    reh = 20./reh
    dih1 = 1. / (44 + reh)
    div1 = 1. / (44 + rev)
    dih2 = 1. / (44 - reh)
    div2 = 1. / (44 - rev)

    thrc   = 72
    thr2gv = 1/sqrt(thrc)
    thr2gh = 1/sqrt(thrc)
    thrc2  = ex_bs(pow(thrc,0.5), 8, bi, fulls=fs)
    thrc   = ex_bs(    thrc,      8, bi, fulls=fs)

    lp_V =    C.NLLV(1,true,fs)
    lp_H = lp_V.NLLH(1,true,fs)

    DeEmphasis = lp_H.YAHR(fs).YAHR(fs).ex_lut(Format("x[-2,0] x[2,0] + 6 * x[-1,0] x[1,0] + 15 * x[-3,0] x[3,0] x[0,0] {reh} * + + + + {dih1} * "), UV=1, fulls=fs). \
                                        ex_lut(Format("x[0,-2] x[0,2] + 6 * x[0,-1] x[0,1] + 15 * x[0,-3] x[0,3] x[0,0] {reh} * + + + + {div1} * "), UV=1, fulls=fs)

    exprv = Format("x y - dup dup abs {un} + dup swap2 * swap {strv} {un} >= {strv2} {strv} ? + / - range_half +")
    exprh = Format("x y - dup dup abs {un} + dup swap2 * swap {strh} {un} >= {strh2} {strh} ? + / - range_half +")
    exprm = Format("x y - dup dup abs {un} + dup swap2 * swap {thrc} {un} >= {thrc2} {thrc} ? + / - range_half +")

    Max_V = ex_luts( C, mode = "max", pixels = ex_shape(1, mode="horizontal", center=false), expr = exprv, UV=1, fulls=fs)
    Min_V = ex_luts( C, mode = "min", pixels = ex_shape(1, mode="horizontal", center=false), expr = exprv, UV=1, fulls=fs)

    minmax_G_V   = ex_lutxy(Max_V, Min_V, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.100001 *
                                                                      X                     Y   min B@ 0.350001 * +
                                                                                       B A B - - 0 max 0.550001 * + "), UV=1, fulls=fs)

    Max_H = ex_luts( C, mode = "max", pixels = ex_shape(1, mode="vertical", center=false), expr = exprh, UV=1, fulls=fs)
    Min_H = ex_luts( C, mode = "min", pixels = ex_shape(1, mode="vertical", center=false), expr = exprh, UV=1, fulls=fs)

    minmax_G_H   = ex_lutxy(Max_H, Min_H, Format(" x range_half - abs X@ y range_half - abs Y@  max A@ 0.100001 *
                                                                      X                     Y   min B@ 0.350001 * +
                                                                                       B A B - - 0 max 0.550001 * + "), UV=1, fulls=fs)

    HPSharp = Expr(C, lp_V, lp_H, minmax_G_V, minmax_G_H, DeEmphasis, Format("x y - X@ a {un} max * a X abs - {un} max /
                                                                              y z - X@ b {un} max * b X abs - {un} max / + c +" ), isy ? Undefined() : "")

    ReEmphasis = HPSharp.ex_lut(Format("x[-2,0] x[2,0] + 6 * x[-1,0] x[1,0] + 15 * x[-3,0] x[3,0] + + + x[0,0] {reh} * - {dih2} * "), UV=1, fulls=fs). \
                         ex_lut(Format("x[0,-2] x[0,2] + 6 * x[0,-1] x[0,1] + 15 * x[0,-3] x[0,3] + + + x[0,0] {rev} * - {div2} * "), UV=1, fulls=fs)

    V = ex_luts(ReEmphasis, mode="med", pixels = ex_shape(2, mode="vertical")   , expr = exprm, exprf = " range_half - abs", UV=1, fulls=fs)
    H = ex_luts(ReEmphasis, mode="med", pixels = ex_shape(2, mode="horizontal") , expr = exprm, exprf = " range_half - abs", UV=1, fulls=fs)


    Gauss_V = ReEmphasis.ex_boxblur(0,3,mode="weighted")
    Gauss_H = ReEmphasis.ex_boxblur(3,0,mode="weighted")

    # Although I do prefer the " 0 max" look after each "* *"
    Expr(ReEmphasis, Gauss_V, V, Gauss_H, H, Format("x y - z * {thr2gv} {cstrv} * * x a - b * {thr2gh} {cstrh} * * x + +"), isy ? Undefined() : "", scale_inputs= fs ? "allf" : "all") }




### MedSharp v0.3 by    Dogway (04-09-2021)
###          v0.2 by *.mp4 guy (11-08-2010)
###          v0.1 by *.mp4 guy (06-03-2010)
###
### Soft thresholded median sharpening function (superseeded by ReCon) (https://forum.doom9.org/showthread.php?p=1425066#post1425066)
###
### 1. calculate difference between center pixel and median neighborhood pixels
### 2. soft-limit each difference
### 3. find median of differences
### 4. add median difference to source

Function MedSharp(Clip C, int "thresh", int "rad", int "mode", bool "lp", bool "hp", bool "nr", float "str", int "kernel", bool "fulls") {

    THR    = Default(thresh, 255)
    RAD    = Default(rad,  1)
    Mode   = Default(mode, 1)
    str    = Default(str,  1)
    lp     = Default(lp,    false)
    hp     = Default(hp,    false)
    nr     = Default(nr,    false)
    fs     = Default(fulls, false)
    kernel = Default(kernel, 2)

    blank = BlankClip(C,color=$828282)
    isy   = isy(c)
    bi    = BitsPerComponent(c)
    THR2  = ex_bs(pow(THR,0.5),   8, bi, fulls=fs)
    THR3  = ex_bs(pow(THR*2,0.5), 8, bi, fulls=fs)
    THR1  = ex_bs(THR, 8, bi, fulls=fs)
    un    = ex_bs(1,   8, bi, fulls=fs)

    Lowpass1       =  C.NLLV(1,false,fs).NLLH(1,false,fs)
    Lowpass_Return = lp && RAD >= 2 ? Lowpass1 : C

    Lowpass_NR_1 = Lowpass_Return.TMed2(thresh=THR,   rad=RAD, Kernel=1, fulls=fs)
    Lowpass_NR_2 = Lowpass_Return.TMed2(thresh=THR/4, rad=RAD, Kernel=2, fulls=fs)

    Diff1 = ex_luts(C, Lowpass_NR_1, mode="med", pixels = ex_shape(RAD, mode="plus",   center=true),  \
                                                   expr = Format("x y - dup dup abs {un} + dup swap2 * swap {THR1}     {un} >= {THR2} {THR1}     ? + / - range_half +"), UV=1, fulls=fs)
    Diff2 = ex_luts(C, Lowpass_NR_2, mode="med", pixels = ex_shape(RAD, mode="square", center=false), \
                                                   expr = Format("x y - dup dup abs {un} + dup swap2 * swap {THR1} 2 * {un} >= {THR3} {THR1} 2 * ? + / - range_half +"), UV=1, fulls=fs)

    mask1 = ex_lut(Diff1, "x range_half - range_max * ", UV=1, fulls=fs)

    s1  = ex_merge(Diff2, blank, mask1, UV=1, fulls=fs).ex_lut(Format("x range_half - {str} 0.500001 * * range_half +"), UV=1, fulls=fs)
    s1b = s1.NLLV(1,false,fs).NLLH(1,false,fs)

    s2  = Diff1.ex_lut(Format("x range_half - {str} * range_half +"), UV=1, fulls=fs)
    s2b = s1.NLLV(1,false,fs).NLLH(1,false,fs)  # is s1. a bug?

    Expr(C, s1, s1b, s2, s2b, "y z - a b - x + +", isy ? Undefined() : "") }




################################
##                            ##
## *.mp4 guy helper functions ##
##                            ##
################################


function TMed2(Clip c, float "thresh", int "rad", int "mode", int "kernel", bool "fulls") {

    THR    = Default(thresh, 255)
    RAD    = Default(rad, 1)
    Mode   = Default(mode, 1)
    kernel = Default(kernel, 1)
    fs     = Default(fulls, false)

    bi    = BitsPerComponent(c)
    THR2  = ex_bs(pow(THR,0.5),   8, bi, fulls=fs)
    THR   = ex_bs(THR, 8, bi, fulls=fs)
    un    = ex_bs(1,   8, bi, fulls=fs)

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

    Expr(C, B1, B2, B3, B4, "x y - S@ abs X^  z x - T@ abs Y^  S T X Y * A@ 1 + * A Y 0.75 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              x a - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.25 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              b x - T@ abs Y^  S T X Y * A@ 1 + * A Y 6.75 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
      }

function NLHV2(Clip C, bool "fulls") {

    isy = isy(c)
    bi  = BitsPerComponent(c)

    fs = Default(fulls, false)

    B1 = C.BlurH(1, 0.833)
    B2 = C.BlurH(2, 0.750)
    B3 = C.BlurH(3, 0.944)
    B4 = C.BlurH(4, 0.981)

    Expr(C, B1, B2, B3, B4, "x y - S@ abs X^  z x - T@ abs Y^  S T X Y * A@ 1 + * A Y 0.75 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              x a - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.25 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              b x - T@ abs Y^  S T X Y * A@ 1 + * A Y 6.75 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
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

    Expr(C, B1, B2, B3, B4, "y x - S@ abs X^  x z - T@ abs Y^  S T X Y * A@ 1 + * A Y 1.915 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              a x - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.025 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              x b - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.077 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
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

    Expr(C, B1, B2, B3, B4, "y x - S@ abs X^  x z - T@ abs Y^  S T X Y * A@ 1 + * A Y 1.915 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              a x - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.025 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  S@ abs X^
                                              x b - T@ abs Y^  S T X Y * A@ 1 + * A Y 2.077 * X - 0 max  X 0 > X -1 X 0 > S 1 ? / ^ 1 ? / 1 * 0 max + 1 + / +  x +", isy ? Undefined() : "", scale_inputs = fs ? "allf" : "all")
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

function YAHR(clip clp, bool "fulls") {

    fs    = Default(fulls, false)

    b1    = clp.ex_minblur(2,1,fulls=fs).removegrain(11,-1)
    b1D   = ex_makediff(clp,b1,UV=1,fulls=fs)

    w1    = clp.aWarpSharp(depth=32,blurlevel=2,thresh=0.5)
    w1b1  =  w1.ex_minblur(2,UV=1,fulls=fs).removegrain(11,-1)
    w1b1D = ex_makediff(w1,w1b1,UV=1,fulls=fs)

    DD    = b1D.repair(w1b1D,13,-1)

    ex_lutxyz(clp, b1D, DD, "x y range_half + z range_half + - -", UV=1, fulls=fs) }
