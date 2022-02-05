#############################################################
###                                                       ###
###  GradFun3 MIX mod by Dogway    (05-02-2022)           ###
###                                                       ###
###                                                       ###
###  A simple port of:                                    ###
###  GradFun3    by cretindesalpes (24-09-2010)           ###
###  http://avisynth.nl/index.php/Dither_tools#GradFun3   ###
###                                                       ###
#############################################################
###
### This function is equivalent to prunedtree's GradFun2DB and helps removing the existing color banding from a source, dithered or not.
### To keep all the advantages of the gradient smoothing and dithering, you should make GradFun3 the very last filter of your encoding chain.
### You should run this on a clip with bitdepth higher than 8-bit for the debanding to come to effect
### and dither it down to an ordered dithering type like Bayer dithering or Void & Cluster, more resilient to lossy codec quantification than other patterns.
###
###
### Dependencies:
###   ExTools
###   RgTools
###   MaskTools2
###   ResizersPack (for smode=0 or smode=3)
###   MasksPack    (for smode>0)
###   DFTTest      (for smode=1)
###
###
### Benchmarks:
###
###     100.0% 69.6 fps
###     Convertbits(16)
###     ex_GradFun3()
###     Convertbits(8,dither=1)
###
###     56.6% 39.4 fps
###     Dither_convert_8_to_16()
###     GradFun3()
###     DitherPost(stacked=true,prot=false,mode=6)
###
###
### Arguments (from Dither Tools docs):
###
### thr, thrc:
### Filter threshold. Below this value, the changes made by the banding filter on pixel values are not attenuated.
### The higher, the more effective the filter will be, but details will be smoothed and artifacts will appear near the edges between two flat areas.
### thrc is the parameter for the chroma planes. Keep it below 1.0. Range: 0.1-10.0.
###
### radius, radiusc:
### Filter radius, in pixels. Basically, this is the extent of artifical gradient introduced on the band edges. radiusc is the parameter for the chroma planes.
### The default value is tuned automatically on clip dimensions, 9 for SD video and 17 for 1080p video. Range: 1-156 for smode=0, 1-128 for smode=1 and 3-13 for smode=2.
###
### elast, elastc:
### Elasticity of the filter attenuation. It’s a multiplier on the threshold. A pixel difference above thr * elast won’t have any effect.
### elastc is the parameter for the chroma planes. Good values are in the range 1.25-4.
###
### mask:
### Depth in pixels of the detail/edge masking. In the range 0-3.
###
### thr_det:
### Local contrast threshold for detail detection and masking. The lower, the better the details will be protected, but the lower the smoothing efficiency.
### Must be > 0, and above the height of a color-banding step. When kept unspecified, it more or less follows the main debanding threshold thr.
###
###
### smode:
### Indicates which filter to use for gradient smoothing.
### 0   Gauss filter. Very fast, whatever the radius. Drawback: can introduce slight but large halos, especially with high thresholds.
### 1   dfttest. Much slower, but less prone to artefacts and halos than the gauss filter.
### 2   Bilateral filter. VERY slow, and slower for bigger radius, but much less prone to artefacts than the gauss filter. Almost haloless, even for high thresholds.
### 3   Undocumented mode.
###
### show:
### 0   Normal output, without debugging information.
### 1   Shows the detail/edge mask.
###
### ref:
### Reference clip used to limit changes. Allows cascading multiple GradFun3 calls (for example by combining small and large radius settings) without going too far from the original picture.
### ref must have the same format as the input clip. When not specified, the reference clip is the input.
###
###
function ex_GradFun3 (clip src, float "thr", int "radius", float "elast", int "mask", int "smode", float "thr_det", int "show", float "thrc", int "radiusc", float "elastc", int "Y", int "UV", clip "ref") {

    w     = src.width ()
    h     = src.height()
    is42  = src.is420()
    bi    = BitsPerComponent(src)
    fs    = propNumElements (src,"_ColorRange")  > 0 ? \
            propGetInt      (src,"_ColorRange") == 0 : false

    thr     = Default (thr,       0.35)
    thrc    = Default (thrc,       thr)
    radius  = Default (radius, round(w/1.51>h?0.0077*w+2.42:0.014*h+1.8))
    radiusc = Default (radiusc, is42?round(radius/2.):radius)
    elast   = Default (elast,      3.0)
    elastc  = Default (elastc,   elast)
    mask    = Default (mask,         2)
    smode   = Default (smode,        0)
    thr_det = Default (thr_det, 2 + round(max(thr - 0.35, 0) / 0.3))
    debug   = Default (show,        0)
    refd    = Defined (ref)
    mask    = min(mask, 3) # 'disk' shape max radius

#    Radius auto-adjust: 480p  ->  9
#                        720p  -> 12
#                        810p  -> 13
#                        900p  -> 14
#                        1080p -> 17
#                        2160p -> 32

    # Input range check.
    Assert (IsVersionOrGreater(3,7,1), "ex_GradFun3: Update AviSynth+ version")
    Assert (radius  > 0,               "ex_GradFun3: "+chr(34)+"radius" +chr(34)+" must be strictly positive.")
    Assert (radiusc > 0,               "ex_GradFun3: "+chr(34)+"radiusc"+chr(34)+" must be strictly positive.")
    Assert (thr     > 0,               "ex_GradFun3: "+chr(34)+"thr"    +chr(34)+" must be strictly positive.")
    Assert (thrc    > 0,               "ex_GradFun3: "+chr(34)+"thrc"   +chr(34)+" must be strictly positive.")
    Assert (thr_det > 0,               "ex_GradFun3: "+chr(34)+"thr_det"+chr(34)+" must be strictly positive.")
    Assert (elast  >= 1,               "ex_GradFun3: "+chr(34)+"elast"  +chr(34)+" must be greater or equal to 1.")
    Assert (elastc >= 1,               "ex_GradFun3: "+chr(34)+"elastc" +chr(34)+" must be greater or equal to 1.")

    ref = refd ? ref : src
    yv411_flag = src.isYV411()

    # Main debanding

    yp      = (!Defined (y)  || (y  == 3)) ? 3 : 1
    uvp     = (!Defined (uv) || (uv == 3)) ? 3 : 1

    c_flag1 = thrc != thr || elastc != elast
    c_flag2 = yp == 3 && uvp == 3 && (is42 && 0 < smode < 3 ? c_flag1 || radiusc != radius : c_flag1)

    src
    flt_y   =             gf3_grad_smooth (last, src, ref, smode, radius,  thr,  elast,  yp, c_flag2 ? 1 : uvp, refd)
    flt_c   = (c_flag2) ? gf3_grad_smooth (last, src, ref, smode, radiusc, thrc, elastc,  1,               uvp, refd) : flt_y
    flt     = (c_flag2) ? flt_y.MergeChroma (flt_c) : flt_y

    # Edge/detail mask

    td_lo  = ex_bs(max(thr_det * 0.75, 1), 8, bi, fs, flt=true) - 0.0001
    td_hi  = ex_bs(max(thr_det,        1), 8, bi, fs, flt=true) + 0.0001

    dmask  = (mask > 0 && yv411_flag) ? src.ExtractY()          : src
    dmask  = (mask > 0) ? dmask.ex_luts(mode="rng", pixels=ex_shape(mask,mode="disk"), exprf=Format(" {td_lo} - {td_hi} {td_lo} - / 0 1 clip range_max *")) : dmask
    dmask  = (mask > 0) ? dmask.removegrain(22, -1)             : dmask # "cartoon" median blur
    dmask  = (mask > 1) ? dmask.removegrain(12, -1)             : dmask
    dmask  = (mask > 2) ? dmask.removegrain(20, -1)             : dmask
    dmask  = (mask > 0 && yv411_flag) ? dmask.ConvertToYV411 () : dmask

    result = (mask > 0) ? mt_merge(flt, src, dmask, luma=true, y=yp, u=uvp, v=uvp) : flt

    (debug == 1       ) ? dmask.GreyScale () : result }



### SmoothGrad() by Dogway (04-02-2022)
###     Port from cretindesalpes' Dither Tools plugin to AviSynth+ wrapper
###     http://avisynth.nl/index.php/Dither_tools#SmoothGrad
###
### "SmoothGrad smooths the low gradients or flat areas of a 16-bit clip. It proceeds by applying a huge blur filter and comparing the result with the input data for each pixel.
### If the difference is below the specified threshold, the filtered version is taken into account, otherwise the input pixel remains unchanged."
###
###
### Dependencies:
###   ExTools
###   ResizersPack
###
###
### Benchmarks:
###
###     100.0% 196 fps
###     Convertbits(16)
###     ex_SmoothGrad()
###     Convertbits(8,dither=1)
###
###     93.9% 184 fps
###     Dither_convert_8_to_16()
###     SmoothGrad()
###     DitherPost(stacked=true,prot=false,mode=6)
###
###
### Arguments (from Dither Tools docs):
###
### radius:
### Radius in pixels of the smoothing filter. > 0
###
### thr:
### Threshold between reference data and filtered data, on an 8-bit scale. > 0.
###
### elast:
### To avoid artifacts, the threshold has some kind of elasticity.
### Value differences falling over this thershold are gradually attenuated, up to thr * elast. > 1.
###
### ref:
### Reference clip for the filter output comparison. Specify here the input clip when you cascade several SmoothGrad calls.
### When undefined, the input clip is taken as reference.
###
###
function ex_SmoothGrad(clip a, int "radius", float "thr", float "elast", clip "ref", int "Y", int "UV") {

    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")  > 0 ? \
          propGetInt      (a,"_ColorRange") == 0 : false

    rfd = Defined(ref)
    rad = Default(radius, 16)
    thr = Default(thr,  0.25)
    el  = Default(elast, 3.0)
    Y   = Default(Y,       3)
    UV  = Default(UV,      3)

    Assert(IsVersionOrGreater(3,7,1), "ex_SmoothGrad: Update AviSynth+ version")
    Assert(rad <=  156,               "ex_SmoothGrad: max "+chr(34)+"radius" +chr(34)+" value is 156.")

    rad   = max(rad, 2)
    th2   = min(max(thr,    0.1 ), 10.0)
    el2   = min(max(el,     1.01), 10.0)
    thr_1 = int(th2       * 128.0 + 0.5)
    thr_2 = int(th2 * el2 * 128.0 + 0.5)

    min_thr_dif = 2
    thr_dif     = max    (thr_2 - thr_1,     min_thr_dif)
    thr_1       = min(max(thr_1, 0), 32767 - min_thr_dif)
    thr_2       = min    (thr_1 + thr_dif, 32767)

    thr_slope   = 32768. / (thr_2 - thr_1)
    thr_offset  = thr_1 * thr_slope + 32768
              
    thr_offset  = ex_bs(thr_offset,   16, bi, fs, flt=true)
    thr_1       = ex_bs(thr_1,        16, bi, fs, flt=true)
    thr_2       = ex_bs(thr_2,        16, bi, fs, flt=true)
    hhr         = 1 / ex_bs(32768/2., 16, bi, fs, flt=true)

    val_filt    = ex_GaussianBlur(a, 0.635*(rad-1)+0.6,Y=Y, UV=UV) # Reparametrized to roughly mimic Dither_box_filter16()

    rfd ? ex_lutxyz(a,val_filt,ref,Format("y z - 0.5 *     abs D@ {thr_1} < y D {thr_2} > x D {thr_slope} * {thr_offset} - y x - 0.5 {hhr} * * * x swap - ? ? "),Y=Y,UV=UV) : \
          ex_lutxy (a,val_filt,    Format("y x - 0.5 * D1@ abs D@ {thr_1} < y D {thr_2} > x D {thr_slope} * {thr_offset} - D1      * {hhr} *     x swap - ? ? "),Y=Y,UV=UV) }








#### HELPER FUNCTIONS ###



function gf3_grad_smooth (clip src_16, clip src_8, clip ref_16, int smode, int radius, float thr, float elast, int y, int uv, bool isref) {

    src_16
      (smode == 0) ? gf3_smoothgrad_multi   (ref_16,        radius, thr, elast, y, uv, isref)
\   : (smode == 1) ? gf3_dfttest            (src_8, ref_16, radius, thr, elast, y, uv, isref)
\   : (smode == 2) ? gf3_bilateral_multi    (ref_16,        radius, thr, elast, y, uv, isref)
\   : (smode == 3) ? gf3_smoothgrad_multi_3 (               radius, thr, elast, y, uv)
\   :                Assert (false, "ex_GradFun3: wrong smode value.") }



function gf3_smoothgrad_multi (clip src, clip ref, int radius, float thr, float elast, int y, int uv, bool isref) {

    Assert (radius <=  156, "ex_GradFun3: max "+chr(34)+"radius" +chr(34)+" value is 156 when smode = 0.")

    ref   = isref ? ref : Undefined()
    ela_2 = max (elast * 0.83, 1)
    ela_3 = max (elast * 0.67, 1)
    r2    = radius * 2 / 3
    r3    = radius * 3 / 3
    r4    = radius * 4 / 3

    src
    (r2 >= 1) ? ex_SmoothGrad (radius=r2, thr=thr,      elast=elast, ref=ref, y=y, uv=uv) : last
    (r3 >= 1) ? ex_SmoothGrad (radius=r3, thr=thr*0.7,  elast=ela_2, ref=ref, y=y, uv=uv) : last
    (r4 >= 1) ? ex_SmoothGrad (radius=r4, thr=thr*0.46, elast=ela_3, ref=ref, y=y, uv=uv) : last }



function gf3_smoothgrad_multi_3 (clip src, int radius, float thr, float elast, int y, int uv) {

    src
    rad = max(radius, 2)
    uvr = uv == 3 ? 20 : -1
    ref = ex_SmoothGrad (radius=radius/3, thr=thr*0.8, elast=elast)

    radius == 2 ? removegrain(20, uvr) : ex_GaussianBlur(0.635*(rad-1)+0.6, Y=y, UV=uv)
    radius == 2 ? removegrain(20, uvr) : ex_GaussianBlur(0.635*(rad-1)+0.6, Y=y, UV=uv)

    ex_limitdif (last, src, thr=thr*0.6, elast=elast, ref=ref, y=y, uv=uv).propCopy(src) }



function gf3_dfttest (clip src, clip ref, int radius, float thr, float elast, int y, int uv, bool isref) {

    Assert (radius <= 128, "ex_GradFun3: max "+chr(34)+"radius" +chr(34)+" value is 128 when smode = 1.")

    hrad = max (radius * 3 / 4, 1)

    dfttest (src, sigma=hrad*thr*thr*32, tbsize=1, sbsize=hrad*4, sosize=hrad*3, Y=y==3, U=uv==3, V=uv==3)

    ex_limitdif (last, src, isref?ref:Undefined(), thr, elast, y=y, uv=uv).propCopy(src) }



function gf3_bilateral_multi (clip src, clip ref, int radius, float thr, float elast, int y, int uv, bool isref) {

    thr_1    = max (thr  * 4.5,  1.25)
    thr_2    = max (thr  * 9.0,   5.0)
    r4       = max (radius * 4 / 3, 4)
    r4       = min (r4,            13)
    r2       = max (radius * 2 / 3, 3)
    r2       = min (r2,            13)
    r1       = max (radius * 1 / 3, 2)

    src
    (r4 >= 2) ? ex_bilateral (radius=r4, sthres=7, ithres=0.631*thr_1-0.568, UV=uv, dejaggie=false) : last
    (r2 >= 2) ? ex_bilateral (radius=r2, sthres=7, ithres=0.631*thr_2-0.568, UV=uv, dejaggie=false) : last
    (r1 >= 2) ? ex_bilateral (radius=r1, sthres=7, ithres=0.631*thr_2-0.568, UV=uv, dejaggie=false) : last

    ex_limitdif (last, src, isref?ref:Undefined(), thr, elast, y=y, uv=uv).propCopy(src) }

