# ChromaReconstructor v4.1 HBD mod: restore 420/422 to (almost) native 444
# by feisty2
#
# just convert 420/422 to 444 with any regular resampling filter, bicubic, spline, kind of stuff
# and apply this filter, chroma planes will be reconstructed to 444 with high frequencies from luma (luma serves as the weighting reference to NLMeans both chroma planes)
#
# An old but fast alternative is:
#   ConverttoYUV444(chromaresample="spline36")
#   aWarpSharp2(thresh=128, blur=2, type=0, depth=16, chroma=6) # Luma guided chroma warp
#
#
# v3.0 major update, new parameter "hipass" allows you to manipulate the strength of the high frequency extraction, a new less aggressive (and a lot slower) method could be enabled when luma is not stable enough (set "wild" to False)
# v3.1 HBD mod and faster "faster" mod by Dogway
# v3.2 Rebasing (some copy-pasta bugfixes)
# v3.3 Rename gauss() function to avoid name conflict. Some tweaks to kernel settings
# v3.4 Reenable mode=1 for horizontally stretched chroma. "_faster", add center shift to nnedi3 and tweak taps
# v3.5 Pass 'gpuid' argument and allow CPU processing with gpuid=-1
# v4.0 Update with nnedi3wrap (passed gpuid argument). Fix 'device_type' arg assignments
#
#
# Example:
#    ConvertToYUV444()
#    ChromaReconstructor()
#
#
function ChromaReconstructor(clip src, int "radius", float "str", int "hipass", int "mode", bool "wild", int "gpuid") {

        w        = src.width()
        h        = src.height()
        bdpth    = string(src.BitsPerComponent())
        p_type   = PixelType(src)

        radius   = Default(radius, 32)
        str      = Default(str,   6.4)
        gpuid    = Default(gpuid,   0)
        hipass   = Default(hipass,  6)
        mode     = Default(mode,    0)   # set to mode=1 for only horizontally stretched chroma
        wild     = Default(wild, true)
        cpu      = gpuid < 0 ? "cpu" : "gpu"
        gpuCL    = max(0, gpuid)

        Assert (is444(src), "ChromaReconstructor: Input should be full chroma sampled (444)")

        ref      = wild ? src.ExtractY() : src.ExtractY().KNLMeansCL(0, radius, 0, pow(1.464968620512209618455732713658, str), device_type=cpu, device_id=gpuCL, dwref=1)
        srcU     = src.ExtractU()
        srcV     = src.ExtractV()
        src8     = CombinePlanes(ref, srcU, srcV, planes="YUV", pixel_type=p_type)
        up4x     = src8.nnedi3wrap(4, nns=4, qual=2, etype=1, nsize=0, gpuid=gpuid)
        Luma     = up4x.ExtractY()
        U        = up4x.ExtractU()
        V        = up4x.ExtractV()
        Unew     = wild ? KNLMeansCL(U, 0, radius, 0, str, wref=0, rclip=Luma, device_type=cpu, device_id=gpuCL) : interpolation(Luma, U, 2, str, device_id=gpuCL)
        Unew     = wild ? Unew : interpolation(Luma, Unew,  4, str, device_id=gpuCL)
        Unew     = wild ? Unew : interpolation(Luma, Unew,  8, str, device_id=gpuCL)
        Unew     = wild ? Unew : interpolation(Luma, Unew, 16, str, device_id=gpuCL)
        Unew     = wild ? Unew : interpolation(Luma, Unew, 32, str, device_id=gpuCL)
        Unew     = Unew.Spline64Resize(w, h, src_left=-1.25, src_top=-1.25)
        Vnew     = wild ? KNLMeansCL(V, 0, radius, 0, str, wref=0, rclip=Luma, device_type=cpu, device_id=gpuCL) : interpolation(Luma, V, 2, str, device_id=gpuCL)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew,  4, str, device_id=gpuCL)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew,  8, str, device_id=gpuCL)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew, 16, str, device_id=gpuCL)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew, 32, str, device_id=gpuCL)
        Vnew     = Vnew.Spline64Resize(w, h, src_left=-1.25, src_top=-1.25)
        UHi      = (mode == 1) ? ex_makeadddiff(Unew, gauss_h(Unew, hipass), srcU) : ex_makeadddiff(Unew, gauss_b(Unew, hipass), srcU)
        VHi      = (mode == 1) ? ex_makeadddiff(Vnew, gauss_h(Vnew, hipass), srcV) : ex_makeadddiff(Vnew, gauss_b(Vnew, hipass), srcV)
        return CombinePlanes(src.ExtractY(), UHi, VHi, planes="YUV")
}


function interpolation(clip luma, clip "chroma", int "radius", float "str", int "gpuid")
{
             exp_c0   = 1.060417282747435920994529352433
             exp_c1   = pow(1.070339301855046091743224243341, 32)
             weight   = pow(exp_c0, radius) / exp_c1
             ref      = Expr(chroma, luma, Format("y dup x - {weight} * -"))
             return KNLMeansCL(chroma, 0, radius, 0, str, wref=0, rclip=ref, device_type=gpuid < 0 ? "cpu" : "gpu", device_id=gpuid)
}


function gauss_b(clip src, int "p")
{
             p        = Default(p, 30)
             w        = src.width()
             h        = src.height()
             upsmp    = GaussResize(src, w * 2, h * 2, P=100)
             return GaussResize(upsmp, w, h, P=p)
}


function gauss_h(clip src, int "p")
{
             p        = Default(p, 30)
             w        = src.width()
             h        = src.height()
             upsmp    = GaussResize(src, w * 2, h, P=100)
             return GaussResize(upsmp, w, h, P=p)
}


# This one works directly with any subsampled chroma format type as input
#
# Example:
#    420_Source
#    ChromaReconstructor_faster() # 444_Output
#
# but I recommend you to use ConvertFormat() to account for chroma placement and chroma shift
#    ConvertFormat(fmt_in="420",fmt_out="444",cs_out="",UVrecon=true)

function ChromaReconstructor_faster(clip src, int "radius", float "str", int "gpuid") {

        w       = src.width()
        h       = src.height()
        bi      = BitsPerComponent(src)
        fs      = propNumElements (src,"_ColorRange")  > 0 ? \
                  propGetInt      (src,"_ColorRange") == 0 : false

        radius  = Default(radius, 12)
        str     = Default(str,   9.0)
        gpuid   = Default(gpuid,   0)
        cpu     = gpuid < 0 ? "cpu" : "gpu"
        gpuCL   = max(0, gpuid)

        Y   = ExtractY(src)
        Uor = ExtractU(src)
        Vor = ExtractV(src)

        ref     =   Y.KNLMeansCL (0, radius, 0, pow(1.464968620512209618455732713658, str), wref=1, device_type=cpu, device_id=gpuCL)
        Luma    = ref.ConvertBits(8,dither=-1,fulls=fs).nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0,                          cshift="spline16" ,gpuid=gpuid).ConvertBits(bi,fulls=fs)
        Uu      = Uor.ConvertBits(8,dither=-1,fulls=fs).nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, fwidth=w*2, fheight=h*2, cshift="blackman6",gpuid=gpuid).ConvertBits(bi,fulls=fs)
        Vu      = Vor.ConvertBits(8,dither=-1,fulls=fs).nnedi3wrap(2, nns=1, qual=1, etype=1, nsize=0, fwidth=w*2, fheight=h*2, cshift="blackman6",gpuid=gpuid).ConvertBits(bi,fulls=fs)
        Unew    = Uu.KNLMeansCL  (0, radius, 0, str, wref=0, rclip=Luma, device_type=cpu, device_id=gpuCL).BicubicResize(w, h, b=0.0, c=0.5)
        Vnew    = Vu.KNLMeansCL  (0, radius, 0, str, wref=0, rclip=Luma, device_type=cpu, device_id=gpuCL).BicubicResize(w, h, b=0.0, c=0.5)
        U       = ex_makeadddiff(Unew, Removegrain(Unew, 20), Uu.BicubicResize(w, h, b=0.0, c=0.5))  # Adding the sharpened result
        V       = ex_makeadddiff(Vnew, Removegrain(Vnew, 20), Vu.BicubicResize(w, h, b=0.0, c=0.5))  # Adding the sharpened result
        return CombinePlanes(Y, U, V, planes="YUV")
}