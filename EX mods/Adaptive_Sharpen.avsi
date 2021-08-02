### Copyright (c) 2015-2021, bacondither
### All rights reserved.
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
###
### Adaptive_Sharpen() - v1.0 (02-08-2021)
###
### https://forum.doom9.org/showthread.php?t=182881
###
###                        by Dogway (Jose Linares)
###
###
### AviSynth+ port of HLSL Adaptive Sharpen shader by bacondither
### Applies sharpening on a smart way (only to blurred lines)
###
### Dependencies: > AviSynth+ 3.7.1
###                 ExTools
###                 Transforms Pack
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
    tv_range     = Default(tv_range,       !rgb)                # True to preserve BTB & WTW (minor summation error)
    UV           = Default(UV,              rgb ? 3 : 1)
    fs           = Default(fulls,           rgb)

    tv_range = tv_range ? "ymax ymin - * ymin +" : "range_max *"
    r_max    = 1./ex_bs(255,      bi, fs)
    a_eps    = ex_bs(2.55,        bi, fs)
    a_offset = ex_bs(a_offset,    bi, fs)
    a_off_ep = a_offset - a_eps
    lthr_m   = ex_bs(lowthr_mxw,  bi, fs)
    lthr_r   = 1. / (lthr_m - a_eps)
    sbe_h    = ex_bs(216.75,      32, fs)
    sbe_m    = ex_bs(14.28,       bi, fs)
    sbe_l    = ex_bs(7.65,        32, fs)
    sd_off   = ex_bs(5.1,         bi, fs)
    L_over   = ex_bs(L_overshoot, 32, fs)
    D_over   = ex_bs(D_overshoot, 32, fs)
    dW_lothr = ex_bs(dW_lothr,    bi, fs)
    dW_hithr = ex_bs(dW_hithr,    bi, fs)

    # Custom weighted DoG edge detection
    edge = Format("x[0,0] A^ x[0,1] B^ x[-1,0] C^ x[1,0] D^ x[0,-1] E^ x[0,2] F^ x[0,-2] G^ x[2,0] H^ x[-2,0] I^ x[-1,1] J^ x[-1,-1] K^ x[1,1] L^ x[1,-1] M^ " \
                 +"B E D C + + + 2 * J K L M + + + A 4 * + + 1 16 / * S^ S F - abs S G - abs S H - abs S I - abs  + + + 0.23 * S J - abs S K - abs S L - abs S M - abs + + + 0.92 * S B - abs S E - abs S D - abs S C - abs + + + 1.15 * S A - abs 1.38 * + + +
                   {r_max} * 2 S -2.466666681 {r_max} * * ^ 0.9 * 0.266666667 + 0 1 clip * range_max * {a_offset} +")

    edge = isy ? Expr(a, edge                                    ) : \
                 Expr(a, edge, "",   scale_inputs=ex_UVf(rgb, bi))


    oh = bi == 32 ? 1 : ex_bs(82, bi, fs)
    os = bi == 32 ? 0 : ex_bs(20, bi, fs)

    # Similar Bound Edge (Soft if, fast linear approx)
    sbe = ex_dlut(Format("
           x[-1,1] A@ x[0,1] B@ max  x[1,1] C@ x[-1,0] D@ max max     x[1,0] E@ x[-1,-1] F@ max x[0,-1] G@ x[1,-1] H@ max max  max  x[0,2] I@ x[-2,0] J@ max x[2,0] K@ x[0,-2] L@ max max x[0,0] X@ max max {r_max} * M^
           x[0,3]   I   B       {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} -
           G  L  x[0,-3]        {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} - *
           x[-3,0]  J D         {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} -
           E  K   x[3,0]        {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} - * +
           x[-1,2]  x[-2,1]  A  {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} -
           H x[2,-1]  x[1,-2]   {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} - * +
           x[1,2]   C x[2,1]    {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} -
           x[-2,-1] F x[-1,-2]  {sbe_m} + + + {a_offset} 3 * - {r_max} * M {sbe_l} + / {sbe_h} - * + {oh} {os} - *"), bi, fs)

    sbe = isy ? Expr(edge, sbe                                    ) : \
                Expr(edge, sbe, "",   scale_inputs=ex_UVf(rgb, bi))


    luma = a.SMPTE_legal(false,UV=1,fulls=fs)

    sharpdiff = ex_dlut(Format("
                y {a_offset} - {dW_lothr} - 1 {dW_hithr} {dW_lothr} - / * 0 1 clip
                dup dup * swap 2 * 3 swap - * Z^

                Z dup 0.86602540378 * swap 1 swap - 0.5 * + 2 ^ X^
                Z dup 0.54772255751 * swap 1 swap - 1.41421356237 * + 2 ^ Z^

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
                       J  x[0,2]  F@  - abs
                       J  x[-2,0] I@  - abs + 0.5 * + {r_max} * A swap / 1 min C0^

                       L  x[1,2]  O@  - abs
                       L  x[2,1]  P@  - abs
                       L          B   - abs
                       L          D   - abs + + +
                       L          F   - abs
                       L  x[2,0]  H@  - abs + 0.5 * + {r_max} * A swap / 1 min C2^

                       K  x[-1,-2]    - abs
                       K  x[2,-1] Q@  - abs
                       K          E   - abs
                       K          C   - abs + + +
                       K  x[0,-2] G@  - abs
                       K          I   - abs + 0.5 * + {r_max} * A swap / 1 min C5^

                       M  x[1,-2] R@  - abs
                       M          Q   - abs
                       M          E   - abs
                       M          D   - abs + + +
                       M          G   - abs
                       M          H   - abs + 0.5 * + {r_max} * A swap / 1 min C7^

                       F          O   - abs
                       F          N   - abs
                       F          B   - abs
                       F x[0,3]       - abs + + +
                       F          J   - abs
                       F          L   - abs + 0.5 * + {r_max} * A swap / Z min C8^

                       G          R   - abs
                       G x[-2,-1] S@  - abs
                       G          E   - abs
                       G x[0,-3]      - abs + + +
                       G          K   - abs
                       G          M   - abs + 0.5 * + {r_max} * A swap / Z min C9^

                       I          S   - abs
                       I          N   - abs
                       I          C   - abs
                       I x[-3,0]      - abs + + +
                       I          J   - abs
                       I          K   - abs + 0.5 * + {r_max} * A swap / Z min C10^

                       H          Q   - abs
                       H          P   - abs
                       H          D   - abs
                       H x[3,0]       - abs + + +
                       H          L   - abs
                       H          M   - abs + 0.5 * + {r_max} * A swap / Z min C11^

                C8  C9  0.25 * + C0 max 0.25 max C0 + 0.5 * C0^
                C8  C10 0.25 * + C2 max 0.25 max C2 + 0.5 * C2^
                C9  C11 0.25 * + C5 max 0.25 max C5 + 0.5 * C5^
                C10 C11 0.25 * + C7 max 0.25 max C7 + 0.5 * C7^

                y[-1,1]  {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LA^
                y[0,1]   {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LB^
                y[1,1]   {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LC^
                y[-1,0]  {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LD^
                y[1,0]   {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LE^
                y[-1,-1] {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LF^
                y[0,-1]  {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LG^
                y[1,-1]  {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LH^
                y[0,2]   {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LI^
                y[-2,0]  {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LJ^
                y[2,0]   {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LK^
                y[0,-2]  {a_off_ep} - {lthr_r} * 255 /   dup dup 1.98 * 2.97 swap - * * 0.01 +  LL^

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

                WA J {r_max} * 0.06 + 2.222222 ^ *
                WB B {r_max} * 0.06 + 2.222222 ^ * +
                WC L {r_max} * 0.06 + 2.222222 ^ * +
                WD C {r_max} * 0.06 + 2.222222 ^ * +
                WE D {r_max} * 0.06 + 2.222222 ^ * +
                WF K {r_max} * 0.06 + 2.222222 ^ * +
                WG E {r_max} * 0.06 + 2.222222 ^ * +
                WH M {r_max} * 0.06 + 2.222222 ^ * +
                WI F {r_max} * 0.06 + 2.222222 ^ * +
                WJ I {r_max} * 0.06 + 2.222222 ^ * +
                WK H {r_max} * 0.06 + 2.222222 ^ * +
                WL G {r_max} * 0.06 + 2.222222 ^ * +

                WA WB WC WD WE WF WG WH WI WJ WK WL + + + + + + + + + + + / abs 0.416666667 ^ 0.06 - L^
                LA LB LC LD LE LF LG LH LI LJ LK LL + + + + + + + + + + + 0.083333333 *  T^

                y {a_offset} - abs {r_max} * 3.5 ^ {curveslope} * {curve_height} * 0.625 + {curve_height} swap / V^

                T V * 0.01 + x {r_max} * L - *  range_max * range_half +"), bi, fs)

    sharpdiff = isy ? Expr(luma, edge, sharpdiff                                    ) : \
                      Expr(luma, edge, sharpdiff, "",   scale_inputs=ex_UVf(rgb, bi))



    sharp = ex_dlut(Format("
            x[0,3] x[-1,2]    dup1 dup1 min A^ max N^
            x[0,2] x[1,2]     dup1 dup1 min B^ max G^
            x[-2,1] x[-1,1]   dup1 dup1 min C^ max I^
            x[0,1] x[1,1]     dup1 dup1 min D^ max U^
            x[2,1] x[-3,0]    dup1 dup1 min E^ max H^
            x[-2,0] x[-1,0]   dup1 dup1 min F^ max X^
            x[0,0] x[1,0]     dup1 dup1 min J^ max Q^
            x[2,0] x[3,0]     dup1 dup1 min K^ max P^
            x[-2,-1] x[-1,-1] dup1 dup1 min L^ max O^
            x[0,-1] x[1,-1]   dup1 dup1 min R^ max Y^
            x[2,-1] x[-1,-2]  dup1 dup1 min S^ max V^
            x[0,-2] x[1,-2]   dup1 dup1 min T^ max Z^
            A D               dup1 dup1 min A^ max D^
            B T               dup1 dup1 min B^ max T^
            E S               dup1 dup1 min E^ max S^
            F x[0,-3]         dup1 dup1 min F^ max M^
            G Z               dup1 dup1 min G^ max Z^
            H V               dup1 dup1 min H^ max V^
            I Q               dup1 dup1 min I^ max Q^
            J R               dup1 dup1 min J^ max R^
            K L               dup1 dup1 min K^ max L^
            N U               dup1 dup1 min N^ max U^
            O P               dup1 dup1 min O^ max P^
            A K               dup1 dup1 min A^ max K^
            B F               dup1 dup1 min B^ max F^
            C R               dup1 dup1 min C^ max R^
            D M               dup1 dup1 min D^ max M^
            G L               dup1 dup1 min G^ max L^
            H Q               dup1 dup1 min H^ max Q^
            I Y               dup1 dup1 min I^ max Y^
            J S               dup1 dup1 min J^ max S^
            N X               dup1 dup1 min N^ max X^
            O T               dup1 dup1 min O^ max T^
            U Z               dup1 dup1 min U^ max Z^
            A B               dup1 dup1 min A^ max B^
            C J               dup1 dup1 min C^ max J^
            D O               dup1 dup1 min D^ max O^
            E I               dup1 dup1 min E^ max I^
            F K               dup1 dup1 min F^ max K^
            G N               dup1 dup1 min G^ max N^
            H S               dup1 dup1 min H^ max S^
            L X               dup1 dup1 min L^ max X^
            M T               dup1 dup1 min M^ max T^
            P U               dup1 dup1 min P^ max U^
            Q Y               dup1 dup1 min Q^ max Y^
            R V               dup1 dup1 min R^ max V^
            B F               dup1 dup1 min B^ max F^
            C E               dup1 dup1 min C^ max E^
            D G               dup1 dup1 min D^ max G^
            H J               dup1 dup1 min H^ max J^
            I R               dup1 dup1 min I^ max R^
            K P               dup1 dup1 min K^ max P^
            L O               dup1 dup1 min L^ max O^
            M N               dup1 dup1 min M^ max N^
            Q S               dup1 dup1 min Q^ max S^
            T X               dup1 dup1 min T^ max X^
            U Z               dup1 dup1 min U^ max Z^
            V Y               dup1 dup1 min V^ max Y^
            A C               dup1 dup1 min A^ max C^
            B D               dup1 dup1 min B^ max D^
            E H               dup1 dup1 min E^ max H^
            F G               dup1 dup1 min F^ max G^
            I K                         min I^
            J Q                         min J^
            L M               dup1 dup1 min L^ max M^
            N O                                max O^
            P R                                max R^
            S V               dup1 dup1 min S^ max V^
            T U               dup1 dup1 min T^ max U^
            X Z               dup1 dup1 min X^ max Z^
            B C               dup1 dup1 min B^ max C^
            D E                         min D^
            G S                                max S^
            H T                         min H^
            I L               dup1 dup1 min I^ max L^
            J M                         min J^
            O R               dup1 dup1 min O^ max R^
            V X                                max X^
            Y Z               dup1 dup1 min Y^ max Z^
            B J                         min B^
            C L                         min C^
            F H                         min F^
            O Y                                max Y^
            S U                                max U^
            B D               dup1 dup1 min B^ max D^
            C I                         min C^
            R Y                                max Y^
            U X               dup1 dup1 min U^ max X^
            C F               dup1 dup1 min C^ max F^
            U Y                                max Y^
            D F                         min D^
            X Y               dup1 dup1 min X^ max Y^
            C D                         min C^

            X Y 2 * + x 3 * max Z + 0.25 * {r_max} * M^
            C B 2 * + x 3 * min A + 0.25 * {r_max} * N^

            M x {r_max} * X@ - abs X N - abs min D^
            1.0001 D - X - {L_over} min   D + P^
            0.0001 D - X + {D_over} min   D + N^

            1 {scale_cs} - {scale_lim} *  P {scale_cs} *  + P min   P^
            1 {scale_cs} - {scale_lim} *  N {scale_cs} *  + N min   N^

            y range_half - {r_max} * abs Y@ 0 max U@ P 24 * min 2 * P / 2.718281828 swap ^ E@ 1 - E 1 + / P * SP^
            Y                               0 min V@ N 24 * min 2 * N / 2.718281828 swap ^ E@ 1 - E 1 + / N * SN^

            z {oh} / 2 - 0.909090909 * 0 1 clip
            dup dup * swap 2 * 3 swap - * C^
            C dup {D_compr_high} * swap 1 swap - {D_compr_low} * + CH^
            C dup {L_compr_high} * swap 1 swap - {L_compr_low} * + CL^

            U {pm_p} ^ CL *  SP abs {pm_p} ^ 1 CL - abs * + 1 {pm_p} / ^
            V {pm_p} ^ CH *  SN abs {pm_p} ^ 1 CH - abs * + 1 {pm_p} / ^ - R^

            X R + 0 1 clip X -
            3 * R + 0.25 * X + "+tv_range+"
            "), bi, fs)

            isy ? Expr(luma, sharpdiff, sbe, sharp                                    ) : \
                  Expr(luma, sharpdiff, sbe, sharp, "",   scale_inputs=ex_UVf(rgb, bi))


}
