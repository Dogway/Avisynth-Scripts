#############################################################################
###                                                                       ###
###        Sharpeners Pack (17-08-2021)                                   ###
###                                                                       ###
###        Collection of high quality sharpeners for AviSynth+            ###
###                                                                       ###
###                                                                       ###
###   bacondither:                                                        ###
###       Adaptive Sharpen                                                ###
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
### Adaptive_Sharpen() - v1.3 (12-08-2021)
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
### Dependencies: > AviSynth+ 3.7.1
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
                 +"B E D C + + + 2 * J K L M + + + A 4 * + + 1 16 / * S@ F - abs S G - abs S H - abs S I - abs + + + 0.23 * S J - abs S K - abs S L - abs S M - abs + + + 0.92 * S B - abs S E - abs S D - abs S C - abs + + + 1.15 * S A - abs 1.38 * + + +
                   {r_max} * 0.65 ^ 2 S {r_max} -2.466666681 1.442695040888963 * * * ^ 0.9 * 0.266666667 + 0 1 clip * range_max * {a_offset} +")

    edge = isy ? Expr(a, edge                                                                , optSingleMode=false) : \
      UV == 1  ? Expr(a, edge, ""                                                            , optSingleMode=false) : \
                 Expr(a, edge, ex_UVexpr(edge, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi), optSingleMode=false)


    # Similar Bound Edge (soft_if(), fast linear approx)
    sbe = ex_dlut(Format("
           x[-1,1] A@ x[0,1]  B@ max x[1,1] C@ x[-1,0] D@ max max x[1,0] E@ x[-1,-1] F@ max x[0,-1] G@ x[1,-1] H@ max max max
           x[0,2]  I@ x[-2,0] J@ max x[2,0] K@ x[0,-2] L@ max max x[0,0] X@ max max {r_max} * {sbe_l} + M^
           x[0,3]  I B          {sbe_m} + + + {r_max} * M / {sbe_h} -
           x[0,-3] G L          {sbe_m} + + + {r_max} * M / {sbe_h} - *
           x[-3,0] J D          {sbe_m} + + + {r_max} * M / {sbe_h} -
           x[3,0]  E K          {sbe_m} + + + {r_max} * M / {sbe_h} - * +
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

                Z dup 0.86602540378 * swap 1 swap - 0.5 * + dup * X^
                1 Z - Z + dup * Y^
                Z dup 0.54772255751 * swap 1 swap - 1.41421356237 * + dup * Z^

                x[0,0] T@ x[0,1]   B@ - abs
                       T  x[-1,0]  C@ - abs
                       T  x[1,0]   D@ - abs
                       T  x[0,-1]  E@ - abs + + +
                       T  x[-1,1]  J@ - abs
                       T  x[1,1]   L@ - abs
                       T  x[-1,-1] K@ - abs
                       T  x[1,-1]  M@ - abs + + + 0.25 * + 3 * {sd_off} + {r_max} * A^

                       J  x[-1,2]     - abs
                       J  x[-2,1] N@  - abs
                       J          B   - abs
                       J          C   - abs + + +
                       J  x[0,2]  F@  - abs T^
                       J  x[-2,0] I@  - abs W^
               T W + 0.5 * + {r_max} * A swap / Y min C0^

                       L  x[1,2]  O@  - abs
                       L  x[2,1]  P@  - abs
                       L          B   - abs
                       L          D   - abs + + +
                       L          F   - abs U^
                       L  x[2,0]  H@  - abs V^
               U V + 0.5 * + {r_max} * A swap / Y min C2^

                       K  x[-1,-2]    - abs
                       K  x[2,-1] Q@  - abs
                       K          E   - abs
                       K          C   - abs + + +
                       K  x[0,-2] G@  - abs JJ^
                       K          I   - abs LL^
               JJ LL + 0.5 * + {r_max} * A swap / Y min C5^

                       M  x[1,-2] R@  - abs
                       M          Q   - abs
                       M          E   - abs
                       M          D   - abs + + +
                       M          G   - abs KK^
                       M          H   - abs MM^
               KK MM + 0.5 * + {r_max} * A swap / Y min C7^

                       F          O   - abs
                       F          N   - abs
                       F          B   - abs
                       F x[0,3]       - abs + + +
                                        T
                                        U + 0.5 * + {r_max} * A swap / Z min C8^

                       G          R   - abs
                       G x[-2,-1] S@  - abs
                       G          E   - abs
                       G x[0,-3]      - abs + + +
                                        JJ
                                        KK + 0.5 * + {r_max} * A swap / Z min C9^

                       I          S   - abs
                       I          N   - abs
                       I          C   - abs
                       I x[-3,0]      - abs + + +
                                        W
                                        LL + 0.5 * + {r_max} * A swap / Z min C10^

                       H          Q   - abs
                       H          P   - abs
                       H          D   - abs
                       H x[3,0]       - abs + + +
                                        V
                                        MM + 0.5 * + {r_max} * A swap / Z min C11^

                C8  C9  0.25 * + C0 max 0.25 max C0 + 0.5 * C0^
                C8  C10 0.25 * + C2 max 0.25 max C2 + 0.5 * C2^
                C9  C11 0.25 * + C5 max 0.25 max C5 + 0.5 * C5^
                C10 C11 0.25 * + C7 max 0.25 max C7 + 0.5 * C7^

                y[-1,1]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LA^
                y[0,1]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LB^
                y[1,1]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LC^
                y[-1,0]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LD^
                y[1,0]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LE^
                y[-1,-1] {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LF^
                y[0,-1]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LG^
                y[1,-1]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LH^
                y[0,2]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LI^
                y[-2,0]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LJ^
                y[2,0]   {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LK^
                y[0,-2]  {a_offset} - {lthr_r} * 0 1 clip   dup dup 1.98 * 2.97 swap - * * 0.01 + LL^

                LA C0  * WA^
                LB X   * WB^
                LC C2  * WC^
                LD X   * WD^
                LE X   * WE^
                LF C5  * WF^
                LG X   * WG^
                LH C7  * WH^
                LI C8  * WI^
                LJ C9  * WJ^
                LK C10 * WK^
                LL C11 * WL^

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

                WA WB WC WD WE WF WG WH WI WJ WK WL + + + + + + + + + + + / abs 0.416666667 ^ 0.06 - L^
                LA LB LC LD LE LF LG LH LI LJ LK LL + + + + + + + + + + + 0.083333333 *  T^

                y {a_offset} - abs {r_max} * 3.5 ^ {curveslope} * {curve_height} * 0.625 + {curve_height} swap / V^

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

            W X 2 * + x 3 * max Y + 0.25 * {r_max} * M^
            C B 2 * + x 3 * min A + 0.25 * {r_max} * N^

            M x {r_max} * X@ - abs X N - abs min D^
            1.0001 D - X - {L_over} min D + P^
            0.0001 D - X + {D_over} min D + N^

            1 {scale_cs} - {scale_lim} * P {scale_cs} * + P min P^
            1 {scale_cs} - {scale_lim} * N {scale_cs} * + N min N^

            y range_half - {r_max} * 0 1 clip Y@ 0 max U@ P 24 * min 2 * P / 2.718281828 swap ^ E@ 1 - E 1 + / P * SP^
            Y                                    0 min V@ N 24 * min 2 * N / 2.718281828 swap ^ E@ 1 - E 1 + / N * SN^

            {L_compr_high} {L_compr_low} - z {r_max} * Z@ * {L_compr_low} + CX^
            {D_compr_high} {D_compr_low} - Z              * {D_compr_low} + CY^

            U {pm_p} ^ CX *  SP abs {pm_p} ^ 1 CX - abs * + 1 {pm_p} / ^
            V {pm_p} ^ CY *  SN abs {pm_p} ^ 1 CY - abs * + 1 {pm_p} / ^ -

            X + range_max *
            "), bi, fs)

            isy     ? Expr(a, sharpdiff, sbe, sharp                                                                 , optSingleMode=false) : \
            UV == 1 ? Expr(a, sharpdiff, sbe, sharp, ""                                                             , optSingleMode=false) : \
                      Expr(a, sharpdiff, sbe, sharp, ex_UVexpr(sharp, UV, bi, rgb, fs), scale_inputs=ex_UVf(rgb, bi), optSingleMode=false) }





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
###  ex_ContraSharpening() v3.0 (12 Augu 2021)
###  - Mod and port to ExTools by Dogway
###
###
### Contra(): sharpen the denoised clip, but don't add more to any pixel than what was removed previously.
### Enable 'MC' (default false) for temporal limiting sharpening versus the default spatial limiting
###
### In final version 2.0d ContraHD() was merged, to allow proper HD sharpening.
### When using 'MC' (temporal limiting) global variables of (before denoising), source MSuper and forward and
### backward compensated motion vectors are necessary as: Super, cb1 and cf1, if used as a standalone function.
### Don't know who made (mod) it, so I can't give proper credits, sorry.

function ex_ContraSharpening(clip denoised, clip original, bool "HD", bool "MC", int "overshoot", bool "fulls") {

    HD        = Default(HD,    false)
    MC        = Default(MC,    false)  # Enable to switch from spatial to temporal limiting
    overshoot = Default(overshoot, 0)
    fs        = Default(fulls, false)

    MC ? Eval("""
    cb1  = original.MCompensate(Super, cb1)
    cf1  = original.MCompensate(Super, cf1)
    pmax = Expr(original, cb1, cf1, "x y max z max")
    pmin = Expr(original, cb1, cf1, "x y min z min")""") : nop()

    s    = denoised.ex_MinBlur(HD?2:1,1,fulls=fs)                                       # Damp down remaining spots of the denoised clip.

    allD = ex_makediff(original,denoised,fulls=fs)                                      # The difference achieved by the denoising.
    ssD  = ex_makediff(s,HD?s.removegrain(12,-1).\
                              removegrain(20,-1):\
                            s.removegrain(12,-1),fulls=fs)                              # The difference of a simple kernel blur.
    ssDD = ssD.repair(HD?ssD.repair(allD,1):allD,1)                                     # Limit the difference to the max of what the denoising removed locally.

    ssDD = SSDD.ex_lutxy(ssD,"x range_half - abs y range_half - abs < x y ?",fulls=fs)  # abs(diff) after limiting may not be bigger than before.

    denoised.ex_adddiff(MC?ssD:ssDD,UV=2,fulls=fs)                                      # Apply the limited difference. (Sharpening is just inverse blurring)
    MC ? ex_clamp(last,pmax,pmin,overshoot,overshoot,UV=2,fulls=fs) : last }



######################################################
###
###  SeeSaw v0.3i (02 Jan 2006) by Didée
###
###  https://forum.doom9.org/showthread.php?p=760935#post760935
###
###    0.3f (13 Dec 2006) by foxyshadis (port to masktools2)
###    0.3g (15 Dec 2015) by StainlessS (Force int call arguments to user script function float params to be explicit floats)
###    0.3h (31 Jan 2020) by real.finder (Update to avs+ and HBD)
###    0.3i (04 Aug 2021) by Dogway (Sanitize, port to ExTools -mix mod- and optimize expressions)
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
    clp = isy ? input : input.converttoy()
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

    ox    = clp.width
    oy    = clp.height
    xss   = m4_sh(ox*ssx)
    yss   = m4_sh(oy*ssy)
    NRL   = ex_bs(NRlimit,  8, bi, fulls=fs)
    NRL2  = ex_bs(NRlimit2, 8, bi, fulls=fs)
    NRLL  = ex_bs(NRlimit2 * 100.0/bias - 1, 8, bi, fulls=fs)
    limit = abs(Slimit)
    SLIM  = ex_bs(limit, 8, bi, fulls=fs)
    BIAS1 = bias
    BIAS2 = 100-bias

    denoised = Defined(denoised) ? denoised.converttoy() : ex_lutxy(clp, clp.removegrain(4, -1), Format("x {NRL} + dup y < swap x {NRL} - dup y > swap y ? ?"), fulls=fs)

    NRdiff = ex_makediff(clp, denoised, fulls=fs)
    tame   = ex_lutxy(clp, denoised, Format("x {NRLL} + y < x {NRL2} + x {NRLL} - y > x {NRL2} - x {BIAS1} * y {BIAS2} * + 0.01 * ? ?"), fulls=fs)
    head   = tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, 4, fs)
    head   = head.mt_merge(tame, tame.mt_edge("prewitt", 0, 255, 0, 0, U=1, V=1).mt_expand().removegrain(20, -1))

    (ssx==1.0 && ssy==1.0) ? repair(tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head, 1, -1, -1)                                                                               : \
                             repair(tame.lanczosresize(xss, yss).ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head.bicubicresize(xss, yss, -.2, .6), 1, -1, -1).lanczosresize(ox, oy)

    ex_SootheSS2(last, tame, sootheT, sootheS, false, 2, fs)
    sharpdiff = ex_makediff(tame, last, fulls=fs)

    (NRlimit==0) ? clp : ex_lutxy(clp, NRdiff, ex_dlut(Format("y range_half {NRL} + > x {NRL} - y range_half {NRL} - < x {NRL} + x y range_half - - ? ?"),   bi, fs), fulls=fs)

     Slimit>=0   ? ex_lutxy(last, sharpdiff, ex_dlut(Format("y range_half {SLIM} + > x {SLIM} - y range_half {SLIM} - < x {SLIM} + x y range_half - - ? ?"), bi, fs), fulls=fs) : \
                   ex_lutxy(last, sharpdiff, ex_dlut(Format("y range_half == x dup y range_half - Y@ abs 1 {limit} / ^ Y dup abs / * - ?"),                  bi, fs), fulls=fs)

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
    clp = isy ? input : input.converttoy()
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

    ox    = clp.width
    oy    = clp.height
    xss   = m4_sh(ox*ssx, PAL ? 2 : 1)
    yss   = m4_sh(oy*ssy, PAL ? 2 : 1)
    NRL   = ex_bs(NRlimit,  8, bi, fulls=fs)
    NRL2  = ex_bs(NRlimit2, 8, bi, fulls=fs)
    NRLL  = ex_bs(NRlimit2 * 100.0/bias - 1, 8, bi, fulls=fs)
    limit = abs(Slimit)
    SLIM  = ex_bs(limit, 8, bi, fulls=fs)
    BIAS1 = bias
    BIAS2 = 100-bias

    denoised = Defined(denoised) ? denoised.converttoy() : ex_lutxy(clp, clp.removegrain(1, -1), Format("x {NRL} + dup y < swap x {NRL} - dup y > swap y ? ?"), fulls=fs)

    NRdiff = ex_makediff(clp, denoised, fulls=fs)
    tame   = ex_lutxy(clp, denoised, Format("x {NRLL} + y < x {NRL2} + x {NRLL} - y > x {NRL2} - x {BIAS1} * y {BIAS2} * + 0.01 * ? ?"), fulls=fs)
    head   = tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, 4, fs)
    head   = head.mt_merge(tame, tame.mt_edge("prewitt", 0, 255, 0, 0, U=1, V=1).mt_expand().removegrain(1, -1))

    (ssx==1.0 && ssy==1.0) ? repair(tame.ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head, 1, -1, -1)                                                                                  : \
                             repair(tame.spline36resize(xss, yss).ex_sharpen22(Sstr, Spower, Szp, SdampLo, SdampHi, Smode, fs), head.bicubicresize(xss, yss, 0.75, 1.0), 1, -1, -1).lanczosresize(ox, oy)

    ex_SootheSS2(last, tame, sootheT, sootheS, true, 2, fs)
    sharpdiff = ex_makediff(tame, last, fulls=fs)

    (NRlimit==0) ? clp : ex_lutxy(clp, NRdiff, ex_dlut(Format("y range_half {NRL} + > x {NRL} - y range_half {NRL} - < x {NRL} + x y range_half - - ? ?"),   bi, fs), fulls=fs)

     Slimit>=0   ? ex_lutxy(last, sharpdiff, ex_dlut(Format("y range_half {SLIM} + > x {SLIM} - y range_half {SLIM} - < x {SLIM} + x y range_half - - ? ?"), bi, fs), fulls=fs) : \
                   ex_lutxy(last, sharpdiff, ex_dlut(Format("y range_half == x dup y range_half - Y@ abs 1 {limit} / ^ Y dup abs / * - ?"),                  bi, fs), fulls=fs)

    isy ? last : CombinePlanes(last, input, planes="YUV", sample_clip=input) }


# =======  Modified sharpening function  =======

function ex_sharpen22(clip clp, float strength, float power, float zp, float lodmp, float hidmp, int rgmode, bool fulls) {

    bi    = BitsPerComponent(clp)
    STR   = strength
    PWR   = 1.0/power
    ZRP   = ZP
    ZRPr  = 1. / ZP
    DMP   = lodmp
    HDMPr = 1. / hidmp
    HDMP  = (hidmp==0) ? "" : Format("A abs {HDMPr} * dup dup dup * * * 1 + /")

    ex_lutxy( clp, clp.RemoveGrain(rgmode,-1,-1), Format("x dup y == swap dup dup y - A@ abs {ZRPr} * {PWR} ^ {ZRP} * {STR} * A dup * dup {DMP} + / * A dup abs / * "+HDMP+" + ?"), UV=2, fulls=fulls, scale_inputs="allf") }



# =======  Soothe() function to stabilize sharpening  =======

function ex_SootheSS2(clip sharp, clip orig, int "sootheT", int "sootheS", bool "SootheSS2", int "UV", bool "fulls") {

    bi       = BitsPerComponent(sharp)
    sootheT  = Default(sootheT, 25 )
    sootheS  = Default(sootheS,  0 )
    sootheT  = (sootheT > 100) ? 100 : (sootheT < -100) ? -100 : sootheT
    sootheS  = (sootheS > 100) ? 100 : (sootheS < 0)    ?    0 : sootheS
    ST       = 100 - abs(sootheT)
    SSPT     = 100 - abs(sootheS)
    SootheSS2= Default(SootheSS2, false)
    fs       = Default(fulls,     false)

    ex_makediff(orig,sharp,fulls=fs)

    (sootheS==0) ? last : ex_lutxy( last, last.removegrain(SootheSS2 ? 1 : 20, -1,-1),
     \             ex_dlut(Format("x range_half - X@ y range_half - Y@ * 0 < X 0.01 * {SSPT} * range_half + X abs Y abs > x {SSPT} * y 100 {SSPT} - * + 0.01 * x ? ?"), bi, fs),UV=1,fulls=fs)

    (sootheT==0) ? last : ex_lutxy( last, last.temporalsoften(1,255,0,32,2),
     \             ex_dlut(Format("x range_half - X@ y range_half - Y@ * 0 < X 0.01 * {ST}   * range_half + X abs Y abs > x {ST}   * y 100 {ST}   - * + 0.01 * x ? ?"), bi, fs),UV=1,fulls=fs)

    (sootheT>-1) ? last : ex_lutxy( last, last.temporalsoften(1,255,0,32,2),
     \             ex_dlut(Format("x range_half - X@ y range_half - Y@ * 0 < X 0.01 * {ST}   * range_half + X abs Y abs > x {ST}   * y 100 {ST}   - * + 0.01 * x ? ?"), bi, fs),UV=1,fulls=fs)

    ex_makediff(orig,last,UV=uv,fulls=fs) }




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

    shrpD = ex_lutxy(c,b,Format("x y - A@ abs {LSTR} * {PSTR} ^ {SSTR} * A dup abs {HDMP} + / * A dup * dup {LDMP} + / * 0 max 128 +"), UV=2, fulls=fs, scale_inputs="allf")

    shrp = (sstr<0.01) ? c : c.ex_adddiff(shrpD,UV=2,fulls=fs)

    shrp = (cstr<0.01) ? shrp : shrp.ex_makediff(shrpD.ex_lut(ex_dlut(Format("x range_half - {CSTR} * range_half +"), bi, fs),fulls=fs).removegrain(rg,-1),UV=2,fulls=fs)

           (xstr<0.01) ? shrp : ex_lutxy(shrp,shrp.removegrain(20,-1),"x dup y - 9.69 * +",UV=2,fulls=fs).repair(shrp,12,0).mergeluma(shrp,1.0-xstr) }




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
## mod by Dogway (16-08-2021)
## - Ported to ExTools
## - Optimized Expressions
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
## | NonlinUSM(str=0.7, z=6, pow=1.6, rad=9  )              ## unsharp softer (Raffriff42 defaults)
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

    str = default(str,  0.7)   # strength
    z   = default(z,    6.0)   # zero point
    pow = default(pow,  1.6)   # power
    rad = default(rad,  9.0)   # radius for "gauss"
    ldmp= default(ldmp, 0.001) # damping for verysmall differences
    UV  = Default(UV,    rgb ? 3 : 1)
    fs  = Default(fulls, rgb)

    bi   = BitsPerComponent(o)
    z    = ex_bs(z,    8, bi, fulls=fs)
    zd   = 1. / z
    ldmp = ex_bs(ldmp, 8, bi, fulls=fs)
    pw   = 1. / pow

    w = o.width()
    h = o.height()

    g = o.bicubicresize(round(w/rad/4)*4,round(h/rad/4)*4).bicubicresize(w,h,1,0)

    ex_lutxy(o, g, Format("x dup y - A@ abs {zd} * {pw} ^ {z} * {str} * A dup * dup {ldmp} + / * A dup abs 0.001 + / * + dup 0 > swap1 x ?"), UV=UV, fulls=fs)

    #interleave(o,last) # just for visualisation, you don't want the function to do this
   }



##################################
#
# SlopeBend()  (SlopeBender? SlopeTwist? SlopeTwister? SlopeSharpen?)
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

    edge = Expr(clp,"x[-1,1] 5 * A^  x[0,1] B^ x[1,1] 5 * C^ x[-1,-1] 5 * D^ x[0,-1] E^ x[1,-1] 5 * F^ x[-1,0] G^ x[1,0] H^
                     D E 10 * F + + A - B 10 * - C -
                     A G 10 * D + + C - H 10 * - F - max 0 max 0.80 ^ 2 *")

    bright_limit = soft==true ? clp.ex_boxblur(0.5,mode="weighted") : clp #.sharpen(1.0)#.blur(1.58)

    dark_limit   = bright_limit.ex_inpand(rad).ex_boxblur(rad,mode="weighted").mt_inflate().mt_deflate()
    dark_limit   = ss ?   dark_limit.lanczosresize(round(ox*ss_x/8)*8,round(oy*ss_y/8)*8) : dark_limit

    bright_limit = bright_limit.ex_expand(rad).ex_boxblur(rad,mode="weighted").mt_deflate().mt_inflate()
    bright_limit = ss ? bright_limit.lanczosresize(round(ox*ss_x/8)*8,round(oy*ss_y/8)*8) : bright_limit


    minmaxdiff   = ex_makediff(bright_limit,dark_limit,dif=false,fulls=fs)
    minmaxavg    = Merge(bright_limit,dark_limit)

    tmp          = ss ? clp.lanczosresize(round(ox*ss_x/8)*8,round(oy*ss_y/8)*8) : clp

    assign_dark  = ex_lutxy(tmp, minmaxavg, "y x - 0 < 0 range_max ?", fulls=fs)

    diff_pix2avg = ex_logic(tmp, minmaxavg, "xor", fulls=fs)
    diff_pix2max = ex_makediff(bright_limit, tmp, dif=false, fulls=fs)
    diff_pix2min = ex_makediff(tmp, dark_limit,   dif=false, fulls=fs)

    map_to_max   = ex_lutxy(diff_pix2avg, diff_pix2max, Format("y dup dup * swap x + A@ / y x 4 ^ * A 4 ^ / + y / {Sstr} ^ y * 0 max"), fulls=fs)
    map_to_min   = ex_lutxy(diff_pix2avg, diff_pix2min, Format("y dup dup * swap x + A@ / y x 4 ^ * A 4 ^ / + y / {Sstr} ^ y * 0 max"), fulls=fs)

    max_mapped   = ex_makediff(bright_limit, map_to_max, dif=false, fulls=fs)
    min_mapped   = ex_adddiff(dark_limit, map_to_min,    dif=false, fulls=fs)

    mt_merge(max_mapped, min_mapped, assign_dark, Y=3, U=1, V=1)

    #normsharp2
    ss ? lanczosresize(ox,oy) : last
    CombinePlanes(last, a, planes="YUV", sample_clip=a) }



# Didée's Median Enhancer Sharpener (12-10-2012)
# http://forum.doom9.org/showthread.php?p=1595531#post1595531
#
# ExTools port  by Dogway           (16-08-2021)
#
# Requires MedianBlur2: http://avisynth.nl/index.php/MedianBlur2

function MedianSharp (clip a, int "str", float "pwr") {

    str = Default( str, 4   )
    pwr = Default( pwr, 1.62 )

    bi   = BitsPerComponent(a)
    pwr2 = 1. / pow(pwr, 2)
    pwr3 =      pow(pwr, 3)
    rpwr = 1. / pwr

    b    = bi > 8 ? str==1 ? a.removegrain(4) : a.ex_median("median5") : a.medianblur(str,str-4,str-4)
    c    = a.repair(a.repair(a.repair(a.repair(a.repair(a.repair(a.repair(a.repair(b,1),1),1),1),1),1),1),1)

    ex_lutxy(a, c, Format("x dup y - A@ abs {pwr2} * {rpwr} ^ {pwr3} * A dup abs {pwr} + / * +"), UV=3, scale_inputs="allf") }



##################################
#
# DetailSharpen() by Didée        (24-12-2011)
#
#
#  VS port        by Wolfberry    (01-01-2019?)
#  AVS+ backport  by Dogway       (16-08-2021)
#
#  From: https://forum.doom9.org/showthread.php?t=163598
#  Didée: Wanna some sharpening that causes no haloing, without any edge masking?

#  Args:
#      z     (float) - zero point.
#      sstr  (float) - strength of non-linear sharpening.
#      power (float) - exponent of non-linear sharpening.
#      ldmp  (float) - "low damp", to not over-enhance very small differences.
#      mode   (int)  - 0: gaussian kernel 1: box kernel
#      med   (bool)  - When True, median is used to achieve stronger sharpening.

#  Examples:
#      DetailSharpen() # Original DetailSharpen by Didée.
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

    denoised = mode == 1 ? c.removegrain(20,-1) : c.removegrain(12,-1)
    denoised = med ? denoised.removegrain(4,-1) : denoised

    ex_lutxy(c, denoised, Format("x y == x dup dup y - A@ abs 1 {zs} / * {rpwr} ^ {strzi} * A dup abs {ldmp} + / * + ? "), UV=2, fulls=fs) }






#######################
###                 ###
###   *.mp4 guy     ###
###                 ###
#######################


### SSSharpFaster (Super Slow Sharpen Faster)
### SSSharp's mod by LaTo (12-10-2012)
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
#   a = s.awarpsharp(cm=0, depth=3, blurlevel=1, thresh=0.99)
    a = s.awarpsharp2(chroma=2, depth=2, blur=1, thresh=250)


    Mblur = s.removegrain(4 ,-1)
    Gblur = s.removegrain(20,-1)
    Hmask = ex_lutxy(Mblur, Gblur, Format("y x - abs {hthr} * {hbias} -"), UV=1, fulls=fs)

    ex_merge(ex_lutxy(s, Gblur, Format("x x y - {str}     * +"), UV=1, fulls=fs),
      \      ex_lutxy(s,     a, Format("x y x - {str} 3 / * +"), UV=1, fulls=fs),
      \      Hmask, UV=1, fulls=fs)

    spline36resize(w,h).mergechroma(c) }
