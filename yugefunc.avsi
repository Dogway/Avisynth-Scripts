/*

IMPLEMENT:
getnative: https://github.com/Infiziert90/getnative
CheckMatrix: https://github.com/HomeOfVapourSynthEvolution/mvsfunc/blob/7948c8be129bc9cb282cf24e25b3c4b77328a9e0/mvsfunc.py#L1999
detail_enhancement https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/Collections/muvsfunc_misc.py#L107
Defilter (https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L1945)
firniture https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L1688
soothe_mod (add to Sharpeners Pack) https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L1301
LocalStatisticsMatching https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L3771
GuidedFilterColor https://github.com/WolframRhodium/muvsfunc/blob/f524942ac6cacd937f9479a417eb308a335dfc1d/muvsfunc.py#L3246
LLSURE    https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L4143
BMAFilter https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L4022
MaskedLimitFilter https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L4759
S_BoxFilter https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/muvsfunc.py#L5443
Wiener2 https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/Collections/muvsfunc_misc.py#L170
tv https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/Collections/muvsfunc_misc.py#L229
BernsteinFilter https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/Collections/muvsfunc_misc.py#L282
GPA https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/Collections/muvsfunc_misc.py#L315
sbr_detail https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/Collections/muvsfunc_misc.py#L453
chroma_reconstruct https://github.com/Irrational-Encoding-Wizardry/lvsfunc/blob/bffb6fa6b9f78f2e02e309b6e8fb606b471b0958/lvsfunc/recon.py#L22

*/




#######################################################################
###                                                                 ###
###    yugefunc  v1.1 (19-02-2023)                                  ###
###                                                                 ###
###    Collection of VapourSynth functions ported to AviSynth+      ###
###                                                                 ###
#######################################################################






##    ex_guidedblur() port from WolframRhodium's VapourSynth function in muvsfunc.py
##    (https://github.com/WolframRhodium/muvsfunc/blob/master/muvsfunc.py#L2983)
##
##    Guided Filter - fast edge-preserving smoothing algorithm
##    Author: Kaiming He et al. (https://kaiminghe.com/eccv10/)
##
##    The guided filter computes the filtering output by considering the content of a guidance image.
##    It can be used as an edge-preserving smoothing operator like the popular bilateral filter,
##        but it has better behaviors near edges.
##    The guided filter is also a more generic concept beyond smoothing:
##    It can transfer the structures of the guidance image to the filtering output,
##        enabling new filtering applications like detail enhancement, HDR compression,
##        image matting/feathering, dehazing, joint upsampling, etc.
##    All the internal calculations are done at 32-bit float.
##
##
##    Args:
##
##        radius: (int) Box / Gaussian filter's radius.
##            If box filter is used, the range of radius is 1 ~ 12(fast=False) or 1 ~ 12*subsampling_ratio in VapourSynth R38 or older
##                because of the limitation of std.Convolution().
##            For gaussian filter, the radius can be much larger, even reaching the width/height of the clip.
##            Default is 2.
##        guidance: (clip) Guidance clip used to compute the coefficient of the linear translation on 'input'.
##            It must has the same clip properties as 'input'.
##            If it is None, it will be set to input, with duplicate calculations being omitted.
##            Default is None.
##        regulation: (float) A criterion for judging whether a patch has high variance and should be preserved, or is flat and should be smoothed.
##            Similar to the range variance in the bilateral filter.
##            Use negative to revert the effect (blur edges, else keep intact)
##            Default is 0.01.
##        regulation_mode: (int) Tweak on regulation.
##            It was mentioned in [1] that the local filters such as the Bilateral Filter (BF) or Guided Image Filter (GIF)
##            would concentrate the blurring near these edges and introduce halos.
##            The author of Weighted Guided Image Filter (WGIF) [3] argued that,
##            the Lagrangian factor (regulation) in the GIF is fixed could be another major reason that the GIF produces halo artifacts.
##            In [3], a WGIF was proposed to reduce the halo artifacts of the GIF.
##            An edge aware factor was introduced to the constraint term of the GIF,
##            the factor makes the edges preserved better in the result images and thus reduces the halo artifacts.
##            In [4], a gradient domain guided image filter is proposed by incorporating an explicit first-order edge-aware constraint.
##            The proposed filter is based on local optimization
##            and the cost function is composed of a zeroth order data fidelity term and a first order regularization term.
##            So the factors in the new local linear model can represent the images more accurately near edges.
##            In addition, the edge-aware factor is multi-scale, which can separate edges of an image from fine details of the image better.
##            0: Guided Filter [1]
##            1: Weighted Guided Image Filter [3]
##            2: Gradient Domain Guided Image Filter [4]
##            Default is 0.
##        use_gauss: (bool) Whether to use gaussian guided filter [1]. This replaces mean filter with gaussian filter.
##            Guided filter is rotationally asymmetric and slightly biases to the x/y-axis because a box window is used in the filter design.
##            The problem can be solved by using a gaussian weighted window instead. The resulting kernels are rotationally symmetric.
##            The authors of [1] suggest that in practice the original guided filter is always good enough.
##            Gaussian is performed by core.tcanny.TCanny(mode=-1).
##            The sigma is set to r/sqrt(2).
##            Default is True.
##        fast: (bool) Whether to use fast guided filter [2].
##            This method subsamples the filtering input image and the guidance image,
##            computes the local linear coefficients, and upsamples these coefficients.
##            The upsampled coefficients are adopted on the original guidance image to produce the output.
##            This method reduces the time complexity from O(N) to O(N/s^2) for a subsampling ratio s.
##            Default is False.
##        subsampling_ratio: (float) Only works when fast=True.
##            Generally should be no less than 'radius'.
##            Default is 4.
##        show: (bool) to show the mask, instead of filtering.
##            Default is false.
##        kernel1, kernel2: (string) Subsampling/upsampling kernels.
##            Default is 'point'and 'bilinear'.
##
##    Ref:
##        [1] He, K., Sun, J., & Tang, X. (2013). Guided image filtering.
##            IEEE transactions on pattern analysis and machine intelligence, 35(6), 1397-1409.
##        [2] He, K., & Sun, J. (2015). Fast guided filter. arXiv preprint arXiv:1505.00996.
##        [3] http://kaiminghe.com/eccv10/index.html
##        [4] Li, Z., Zheng, J., Zhu, Z., Yao, W., & Wu, S. (2015). Weighted guided image filtering.
##            IEEE Transactions on Image Processing, 24(1), 120-129.
##        [5] Kou, F., Chen, W., Wen, C., & Li, Z. (2015). Gradient domain guided image filtering.
##            IEEE Transactions on Image Processing, 24(11), 4528-4539.
##        [6] http://koufei.weebly.com/

# * ex_guidedblur(radius=r) is the slow (10% fps) but edge preserving equivalent of ex_blur(r-2) (with Defaults)

function ex_guidedblur(clip a, float "radius", clip "guidance", float "regulation", int "regulation_mode", bool "use_gauss", bool "fast", \
                               int "subsampling_ratio", string "kernel1", string "kernel2", bool "show", int "UV") {
    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)
    fs  = propNumElements(a, "_ColorRange")  > 0 ? \
          propGetInt     (a, "_ColorRange") == 0 : rgb

    fa  = Default(fast,          false)     # Might need to readjust 'radius' to match when fast=false
    s   = Default(subsampling_ratio, 2)
    r   = Default(radius,            2)
    gd  = Default(guidance, Undefined())    # Optional: use a gradient magnitude clip here (ie. frei-chen edge mask, etc)
    eps = Default(regulation,     0.01)
    rm  = Default(regulation_mode,   0)     # 0: Original Guided Filter, 1: Weighted Guided Image Filter, 2: Gradient Domain Guided Image Filter
    ga  = Default(use_gauss,      true)     # 'use_gauss = false' stepping is in integer increments
    sh  = Default(show,          false)
    kn1 = Default(kernel1,   "Precise")
    kn2 = Default(kernel2,   "Precise")
    UV  = Default(UV,    rgb ? 3 : 2)
    r   = fa ? r/float(s) : r

    epr = eps < 0 ? "range_max swap -" : ""
    eps = abs(eps)
    isg = Defined(gd)
    w   = a.width()
    h   = a.height()
    p   =        a
    I   = isg ? gd : p

    # Back up guidance image
    I_src = I.ConvertBits(32, fulls=fs, fulld=true)

    # Fast guided filter's subsampling
    r = fa ?        float(r) /s                   : r
    p = fa ? p.RatioResize(1./s, "%", kernel=kn1) : p
    I = fa ? I.RatioResize(1./s, "%", kernel=kn1) : I
    p =      p.ConvertBits(32, fulls=fs, fulld=true)
    I =      I.ConvertBits(32, fulls=fs, fulld=true)

    function Filter(clip clp, float r, bool use_gauss, int UV) {
        sigY  = r/2.*sqrt(2)
        use_gauss ? clp.vsTCanny(sigY,mode=-1,u=uv,v=uv) : clp.ex_boxblur(floor(r),mode="mean", UV=uv) }

    function Filter_r1(clip clp,       bool use_gauss, int UV) {
        use_gauss ? clp.removegrain(12,uv==3?12:-1)      : clp.ex_boxblur(1       ,mode="mean", UV=uv) }


    # Compute local linear coefficients.
    mean_p   =       Filter(p,r,ga,uv)
    mean_I   = isg ? Filter(I,r,ga,uv) : mean_p
    I_square = ex_lut(I, "x dup *", UV=uv, scale_inputs="none")
    corr_I   =       Filter(I_square,r,ga,uv)
    corr_Ip  = isg ? Filter(ex_lutxy(I, p, "x y *", UV=uv, scale_inputs="none"),r,ga,uv) : corr_I

    var_I    =       ex_lutxy (corr_I,  mean_I,         "x y dup * -", UV=uv, scale_inputs="none")
    cov_Ip   = isg ? ex_lutxyz(corr_Ip, mean_I, mean_p, "x y z   * -", UV=uv, scale_inputs="none") : var_I


    if (rm>0) {

        if (r != 1) {

            mean_I_1 = Filter_r1(I,       ga,uv)
            corr_I_1 = Filter_r1(I_square,ga,uv)
            var_I_1  = ex_lutxyz(corr_I_1, mean_I_1, var_I, "x y dup * - z * sqrt", UV=uv, scale_inputs="none")
        } else { var_I_1  = var_I }

        weight_in = var_I_1


            if (rm == 1) {

                a = ScriptClip(weight_in, function [weight_in, cov_Ip, var_I, eps, epr, uv] () {
                    # Edge-Aware Weighting, equation (5) in [3], or equation (9) in [4].
                    avg = 1. / AverageLuma(weight_in)

                    ex_lutxyz(cov_Ip, var_I, weight_in, Format("x y {eps} z 0.000001 + {avg} * / + / "+epr), UV=uv, scale_inputs="none")
                } )

            } else {

                a = ScriptClip(weight_in, function [weight_in, cov_Ip, var_I, eps, epr, uv] () {
                    # Edge-Aware Weighting, equation (5) in [3], or equation (9) in [4].
                    Denominator = ex_lutxy(var_I, weight_in, Format("1 x y * sqrt {eps} + /"), UV=uv, scale_inputs="none")
                    avg = AverageLuma(Denominator)

                    weight = ex_lut(weight_in, Format("x {eps} + {avg} *"), UV=uv, scale_inputs="none")

                    # Compute the optimal value of a of Gradient Domain Guided Image Filter, equation (12) in [4]
                    frameMean = AverageLuma(weight)
                    frameMin  = YPlaneMin(weight)

                    alpha = frameMean
                    kk = -4 / (frameMin - alpha - 0.000001) # Add a small num to prevent divided by 0

                    ex_lutxyza(cov_Ip, weight_in, weight, var_I, Format("x {eps} 1 1 1 {kk} y {alpha} - * exp + / - * z / + a {eps} z / + / 0 max "+epr), UV=uv, scale_inputs="none")

             } ) }

    } else {
        a = ex_lutxy(cov_Ip, var_I, Format("x y {eps} + / "+epr), UV=uv, scale_inputs="none")   # regulation_mode = 0, Original Guided Filter
    }

    b = ex_lutxyz(mean_p, a, mean_I, "x y z * -", scale_inputs="none")

    mean_a = Filter(a,r,ga,uv)
    mean_b = Filter(b,r,ga,uv)

    # Fast guided filter's upsampling
    ratio  = float(w)/round(float(w)/s)
    mean_a = fa ? mean_a.RatioResize(ratio, "%", kernel=kn2) : mean_a
    mean_b = fa ? mean_b.RatioResize(ratio, "%", kernel=kn2) : mean_b

    # Linear translation
    q = !sh ? ex_lutxyz(mean_a, I_src, mean_b, "x y * z +", UV=uv, scale_inputs="none") : a

    # Final bitdepth conversion
    bi != 32 ? ConvertBits(q, bi, dither=1, fulls=true, fulld=fs) : \
               ConvertBits(q, bi,           fulls=true, fulld=fs) }



##    ex_ANguidedblur() port from WolframRhodium's VapourSynth function in muvs
##    (https://github.com/WolframRhodium/muvsfunc/wiki/muvs-tutorial#anisotropic-guided-filtering)
##
##    Anisotropic Guided Filtering
##
##    The guided filter and its subsequent derivatives have been widely employed in many image processing and computer vision applications
##        primarily brought about by their low complexity and good edge-preservation properties. Despite this success, the different variants of
##        the guided filter are unable to handle more aggressive filtering strengths leading to the manifestation of “detail halos”.
##    At the same time, these existing filters perform poorly when the input and guide images have structural inconsistencies. In this paper,
##        we demonstrate that these limitations are due to the guided filter operating as a variable-strength locally-isotropic filter that, in effect,
##        acts as a weak anisotropic filter on the image. Our analysis shows that this behaviour stems from the use of unweighted averaging in the final steps
##        of guided filter variants including the adaptive guided filter (AGF), weighted guided image filter (WGIF), and gradient-domain guided image filter (GGIF).
##    We propose a novel filter, the Anisotropic Guided Filter (AnisGF), that utilises weighted averaging to achieve maximum diffusion while preserving strong edges in the image.
##    The proposed weights are optimised based on the local neighbourhood variances to achieve strong anisotropic filtering
##
##
##    Args:
##
##        radius: (float) Box / Gaussian filter's radius.
##            Default is 2.
##
##        guidance: (clip) Guidance clip used to compute the coefficient of the linear translation on 'clip'.
##            It must has the same clip properties as 'clip'.
##            Default is Undefined.
##
##        gamma: (float) Positive scalar value that controls the smoothness of the guided filter.
##            A small value preserves more detail while a large value promotes smoothing.
##            Use negative to revert the effect (blur edges, else keep intact)
##            Default is 0.01.
##
##        epsilon: (float) Positive scalar value that regularizes the anisotropic weights.
##            A large value will promote more isotropy
##            while a small value will emphasize the anisotropic behavior.
##            Default is 2^(-8).
##
##        use_gauss: (bool) Whether to use gaussian guided filter.
##            Default is True.
##
##        sigma: (bool) Scaled noise variance of the image.
##            If it is None, it is estimated from the image.
##            Default is False.
##
##        adaptive: (bool) Boolean flag that controls the behavior of the guided filter.
##            It enables the adaptation of the guided filter regularizer (gamma)
##            to better preserve details in the image.
##            Default is True.
##
##        show: (bool) Show the mask.
##            Default is False.
##
##    Ref:
##        [1] C. N. Ochotorena and Y. Yamashita, "Anisotropic Guided Filtering,"
##            in IEEE Transactions on Image Processing, vol. 29, pp. 1397-1412, 2020,
##            doi: 10.1109/TIP.2019.2941326.

function ex_ANguidedblur(clip clp, float "radius", clip "guidance", float "gamma", bool "alpha", float "epsilon", bool "use_gauss", bool "sigma", bool "adaptive", bool "show", int "UV") {

    rgb = isRGB(clp)
    isy = isy(clp)
    bi  = BitsPerComponent(clp)

    fs  = propNumElements(clp, "_ColorRange")  > 0 ? \
          propGetInt     (clp, "_ColorRange") == 0 : rgb

    gd  = Default(guidance, Undefined())  # Optional: use a gradient magnitude clip here (ie. frei-chen edge mask, etc)
    r   = Default(radius,       2)
    gm  = Default(gamma,     0.01)
    al  = Default(alpha,    false)
    ga  = Default(use_gauss, true)
    eps = Default(epsilon, 0.003906250)
    sm  = Default(sigma,    false)
    ad  = Default(adaptive,  true)
    sh  = Default(show,     false)
    UV  = Default(UV,    rgb ? 3 : 2)
    fr  = floor(r)

    isg = Defined(gd)
    clp =      clp.ConvertBits(32, fulls=fs, fulld=true)
    gd  = isg ? gd.ConvertBits(32, fulls=fs, fulld=true) : clp

    gmn   = gm < 0 ? "range_max swap -" : ""
    gm    = abs(gm)
    alpha = !al ? max(log10(gm) + 3, 0) : 1


    if (!isg) {

        X1 =                                                         clp.ex_boxblur(fr,mode="mean",UV=uv)
        X2 = ex_lut  (clp,      "x dup *"  , UV=uv, scale_inputs="none").ex_boxblur(fr,mode="mean",UV=uv)
        W  = ex_lutxy(X1, X2, "y x dup * -", UV=uv, scale_inputs="none")

    } else {

        G1  =                                                   guidance.ex_boxblur(fr,mode="mean",UV=uv)
        G2  =     ex_lut(guidance,"x dup *" ,UV=uv, scale_inputs="none").ex_boxblur(fr,mode="mean",UV=uv)
        X1  =                                                        clp.ex_boxblur(fr,mode="mean",UV=uv)
        XG  = ex_lutxy(clp,guidance,"x y *" ,UV=uv, scale_inputs="none").ex_boxblur(fr,mode="mean",UV=uv)
        W   = ex_lutxy(G1, G2, "y x dup * -",UV=uv, scale_inputs="none")
    }

    coeff = 0.0002 * (2 * r + 1) * gm
    gamma = ad ? Format("dup {coeff} swap 0.000001 + /") : Format("{gm}")

    A = !isg ? ex_lut(W,             "x dup "+gamma+" + / "+gmn      ,UV=uv, scale_inputs="none") : \
               ex_lutxyza(W,XG,X1,G1,"y z a * - x "+gamma+" + / "+gmn,UV=uv, scale_inputs="none")
    B = !isg ? ex_lutxy  (A,X1,      "1 x - y *"                     ,UV=uv, scale_inputs="none") : \
               ex_lutxyz (A,X1,G1,   "y x z * -"                     ,UV=uv, scale_inputs="none")

    # unsharp mask with ad hoc divisor
    div   = sqrt(pi/2) / 6
    sigma = !sm ? ex_lut(gd,Format("x[-1,1] x[1,1] x[-1,-1] x[1,-1] x[0,0] 4 * + + + + x[0,1] x[-1,0] x[1,0] x[0,-1] + + + 2 * - {div} *"),UV=uv, scale_inputs="none") : nop()

    coeff = pow(2 * r + 1, 2)
    W = Scriptclip(W, function [W,coeff,alpha,eps,sm,sigma,uv] () {
        avg = !sm ? string(min(-eps,pow(sigma.AverageLuma(),2)))+" -" : ""  # This line is causing NaN blocks, fix (originally without min())
        ex_lut(W,Format("{eps} {coeff} x "+avg+" * {alpha} ^ {eps} + / range_max swap -"), UV=uv, scale_inputs="none") } )

    WA = ex_lutxy(W,A,"x y *",UV=uv, scale_inputs="none")
    WB = ex_lutxy(W,B,"x y *",UV=uv, scale_inputs="none")
    sigY  = r/2.+0.25
    A = ga ? WA.vsTCanny(sigY,mode=-1,u=uv,v=uv) : WA.ex_boxblur(fr,mode="mean",UV=uv)
    B = ga ? WB.vsTCanny(sigY,mode=-1,u=uv,v=uv) : WB.ex_boxblur(fr,mode="mean",UV=uv)
    W = ga ?  W.vsTCanny(sigY,mode=-1,u=uv,v=uv) :  W.ex_boxblur(fr,mode="mean",UV=uv)

    res = !sh ? ex_lutxyza(gd,A,B,W,"y x * z + a /",UV=uv, scale_inputs="none") : A

    bi != 32 ? ConvertBits(res, bi, dither=1, fulls=true, fulld=fs) : \
               ConvertBits(res, bi,           fulls=true, fulld=fs) }




/*
    XDoG - An eXtended difference-of-Gaussian filter (WIP)

    https://github.com/WolframRhodium/muvsfunc/blob/80e99100c78b96b1c925a5989259ef22c1bc6173/Collections/muvsfunc_misc.py#L417
    Args:
        clip: Input clip.
        sigma: (float) Strength of gaussian filter.
            Default is 1.
        k: (float) Amplifier of "sigma" for second gaussian filtering.
            Default is 1.6.
        p: (float) Amplifier of difference of gaussian.
            Default is 20.
        epsilon: (float, 0~1) Threshold of DoG response. Scaled automatically.
            Default is 0.7.
        lamda: (float) Multiplier in the thresholding function.
            Default is 0.01.
    Ref:
        [1] Winnemöller, H., Kyprianidis, J. E., & Olsen, S. C. (2012). XDoG: an extended difference-of-Gaussians compendium including advanced image stylization. Computers & Graphics, 36(6), 740-753.
*/

function XDoG(clip a, float "sigma", float "k", int "p", float "epsilon", float "lamda") {

    rgb = isRGB(a)
    isy = isy(a)
    bi  = BitsPerComponent(a)

    sm  = Default(sigma,    1.0) # Strength of gaussian filter
    k   = Default(k,        1.6) # Amplifier of "sigma" for second gaussian filtering
    p   = Default(p,         20) # Amplifier of difference of gaussian
    eps = Default(epsilon,  0.7) # Threshold of DoG response. Scaled automatically
    lam = Default(lamda,   0.01) # Multiplier in the thresholding function

    eps = ex_bs(eps, 32, bi, true, flt=true)
#    eps = ex_bs(eps, 8, bi, true)
#    eps = eps

    f1  = vsTCanny(a, sigmaY=sm,     mode=-1)
    f2  = vsTCanny(a, sigmaY=sm * k, mode=-1)

    ex_lutxy(f1, f2, Format("x y - {p} * x + A@ {eps} >= range_max 2 2 A {eps} - {lam} * 2 * exp 1 + / - range_max * ? ")) }
#    return core.std.Expr([f1, f2], f'x y - {p} * x + {epsilon} >= 1 2 2 2 x y - {p} * x + {epsilon} - {lamda} * * exp 1 + / - ? {peak} *')

