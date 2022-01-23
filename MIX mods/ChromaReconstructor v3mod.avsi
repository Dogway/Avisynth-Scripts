# ChromaReconstructor v3.2 HBD mod: restore 420/422 to (almost) native 444
# by feisty2
#
# just convert 420/422 to 444 with any regular resampling filter, bicubic, spline, kind of stuff
# and apply this filter, chroma planes will be reconstructed to 444 with high frequencies from luma (luma serves as the weighting reference to NLMeans both chroma planes)
#

# v3.0 major update, new parameter "hipass" allows you to manipulate the strength of the high frequency extraction, a new less aggressive (and a lot slower) method could be enabled when luma is not stable enough (set "wild" to False)
# v3.1 HBD mod and faster "faster" mod by Dogway
# v3.2 Rebasing (some copy-pasta bugfixes)
#
# Example:
#
# converttoyv24()
# ChromaReconstructor()
#
function ChromaReconstructor(clip src, int "radius", float "str", int "hipass", int "mode", bool "wild") {

        radius   = Default(radius, 32)
        str      = Default(str, 6.4)
        hipass   = Default(hipass, 6)
        mode     = Default(mode, 0)
        wild     = Default(wild, True)

        cores    = SI_PhysicalCores()
        threads  = SI_LogicalCores()
        w        = src.width()
        h        = src.height()
        bdpth    = string(src.BitsPerComponent())
        p_type   = PixelType(src)

        ref      = wild ? src.ExtractY() : src.ExtractY().KNLMeansCL(0, radius, 0, pow(1.464968620512209618455732713658, str), "auto", wref=1)
        srcU     = src.ExtractU()
        srcV     = src.ExtractV()
        src8     = CombinePlanes(ref, srcU, srcV, planes="YUV", pixel_type=p_type)
        up2x     = src8.nnedi3(field=1, dh=True, nns=4, qual=2, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2).TurnRight().nnedi3(field=1, dh=True, nns=4, qual=2, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2).TurnLeft()
        up4x     = up2x.nnedi3(field=1, dh=True, nns=4, qual=2, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2).TurnRight().nnedi3(field=1, dh=True, nns=4, qual=2, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2).TurnLeft()
        Luma     = up4x.ExtractY()
        U        = up4x.ExtractU()
        V        = up4x.ExtractV()
        Unew     = wild ? KNLMeansCL(U, 0, radius, 0, str, "auto", wref=0, rclip=Luma) : interpolation(Luma, U, 2, str)
        Unew     = wild ? Unew : interpolation(Luma, Unew,  4, str)
        Unew     = wild ? Unew : interpolation(Luma, Unew,  8, str)
        Unew     = wild ? Unew : interpolation(Luma, Unew, 16, str)
        Unew     = wild ? Unew : interpolation(Luma, Unew, 32, str)
        Unew     = Unew.Spline64Resize(w, h, src_left=-1.25, src_top=-1.25)
        Vnew     = wild ? KNLMeansCL(V, 0, radius, 0, str, "auto", wref=0, rclip=Luma) : interpolation(Luma, V, 2, str)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew,  4, str)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew,  8, str)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew, 16, str)
        Vnew     = wild ? Vnew : interpolation(Luma, Vnew, 32, str)
        Vnew     = Vnew.Spline64Resize(w, h, src_left=-1.25, src_top=-1.25)
        UHi      = ex_makeadddiff(Unew, gauss(Unew, hipass), srcU) # mode==1 seems to be broken (comparing different dimension) ex_makeadddiff(Unew, gauss_h(Unew, hipass), srcU)
        VHi      = ex_makeadddiff(Vnew, gauss(Vnew, hipass), srcV)
        return CombinePlanes(src.ExtractY(), UHi, VHi, planes="YUV")
}


function interpolation(clip luma, clip "chroma", int "radius", float "str")
{
             exp_c0   = 1.060417282747435920994529352433
             exp_c1   = pow(1.070339301855046091743224243341, 32)
             weight   = pow(exp_c0, radius) / exp_c1
             ref      = Expr(chroma, luma, Format("y dup x - {weight} * -"))
             return KNLMeansCL(chroma, 0, radius, 0, str, "auto", wref=0, rclip=ref)
}


function gauss(clip src, int "p")
{
             p        = Default(p, 30)
             w        = src.width()
             h        = src.height() / 2
             upsmp    = GaussResize(src, w * 2, h * 2, P=100)
             return GaussResize(upsmp, w, h, P=p)
}


function gauss_h(clip src, int "p")
{
             p        = Default(p, 30)
             w        = src.width()
             h        = src.height() / 2
             upsmp    = GaussResize(src, w * 2, h, P=100)
             return GaussResize(upsmp, w, h, P=p)
}


# This one works directly with any subsampled chroma format type as input
#
# Example:
#    420_Source
#    ChromaReconstructor_faster() # 444_Output
#
function ChromaReconstructor_faster(clip src, int "radius", float "str", int "threads") {

        bi      = BitsPerComponent(src)
        fs      = propNumElements (src,"_ColorRange")  > 0 ? \
                  propGetInt      (src,"_ColorRange") == 0 : false

        radius  = Default(radius, 16)
        str     = Default(str,   6.4)
        threads = Default(threads, 4)

        cores   = SI_PhysicalCores()
        threads = SI_LogicalCores()

        w   = src.width()
        h   = src.height()
        bi  = src.BitsPerComponent()

        Y   = ExtractY(src)
        Uor = ExtractU(src)
        Vor = ExtractV(src)

        ref     =   Y.KNLMeansCL(0, radius, 0, pow(1.464968620512209618455732713658, str), "auto", wref=1).ConvertBits(bi,fulls=fs)
        Luma    = ref.ConvertBits(8,dither=-1,fulls=fs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2)
        Uu      = Uor.ConvertBits(8,dither=-1,fulls=fs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=0.0, ep1=0.75, cshift="bicubicresize", mpeg2=false).ConvertBits(bi,fulls=fs)
        Vu      = Vor.ConvertBits(8,dither=-1,fulls=fs).nnedi3_rpow2(rfactor=2, nns=1, qual=1, etype=1, nsize=0, threads=cores, prefetch=(threads+cores)/2, fwidth=w*2, fheight=h*2, ep0=0.0, ep1=0.75, cshift="bicubicresize", mpeg2=false).ConvertBits(bi,fulls=fs)
        Unew    = Uu.KNLMeansCL(0, radius, 0, str, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=-0.5, c=0.25)
        Vnew    = Vu.KNLMeansCL(0, radius, 0, str, "auto", wref=0, rclip=Luma).BicubicResize(w, h, b=-0.5, c=0.25)
        U       = ex_makeadddiff(Unew, Removegrain(Unew, 20), Uu.BicubicResize(w, h, b=-0.5, c=0.25))  # Sharpening
        V       = ex_makeadddiff(Vnew, Removegrain(Vnew, 20), Vu.BicubicResize(w, h, b=-0.5, c=0.25))  # Sharpening
        return CombinePlanes(Y, U, V, planes="YUV")
}