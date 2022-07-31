######################################################
###                                                 ##
###                                                 ##
###   Resizers Functions Pack 9.5 (30-07-2022)      ##
###                                                 ##
###                   by Dogway (Jose Linares)      ##
###                                                 ##
### https://forum.doom9.org/showthread.php?t=182881 ##
###                                                 ##
###                                                 ##
###                                                 ##
### Functions:                                      ##
###      deep_resize                                ##
###      nnedi3resize                               ##
###      nnedi3wrap                                 ##
###      RatioResize                                ##
###      PadResize                                  ##
###      PadBorders                                 ##
###      nmod                                       ##
###      mmod                                       ##
###      ColortoHex                                 ##
###      MatteCrop                                  ##
###                                                 ##
###                                                 ##
######################################################



##############################
###
### deep_resize() - by Dogway (30-07-2022)
###
### Convenient and high performance function to resize natural images in high quality (different kernel for edge/flat areas).
### Defaults work pretty nice out-of-the-box so you don't need to spend time tweaking settings.
### If you want more control (ColorSpaces, UVRecon, nomoiree, etc) use directly ConvertFormat().
### Supports all YUV formats in any given bitdepth (not RGB).
###
### deconv: An option to undo the oversharpening or blur of the original downscaling kernel.
###         Following suggested values for 'deconv':
###
###         -10 "SoftCubic100"
###         -7  "Robidoux Soft"
###         -6  "SoftCubic75"
###         -6  "Bilinear"
###         -6  "BilcubicD"
###         -6  "BilcubicU"
###         -6  "Hermite"
###         -5  "Robidoux"
###         -5  "Centroid"
###         -5  "Mitchell-Netravali"
###         -4  "Robidoux Sharp"
###         -5  "SoftCubic50"
###         -0  "Cub-grange"
###         -0  "Catmull-Rom"
###         +1  "Didee"
###         +4  "Zopti"
###         +4  "ZoptiN"
###         +2  "Precise Bicubic"
###         +2  "Sharp"
###         +0  "Spline16"
###         +0  "Spline36"
###         +2  "DPID"
###         +0  "SSIM2"
###         +0  "SincLin"
###         +15 "SinPow"
###
###
### Dependencies:
###   ExTools
###   MasksPack
###   TransformsPack
###   GrainFactory3mod   (for grain > 0)
###   GradePack          (for show=true)
###   Resizer of choice
###       NNEDI3CL          (for default "nnedi3" upscale)
###       LSFplus           (for default "nnedi3" upscale) (and its dependencies)
###       SharpenersPack    (for default "nnedi3" upscale)
###       SimilarityMetrics (for 'SSIM2' downscaling)
###           vsTCanny
###           fmtconv
###
###
### Benchmark (1080p to 2160p):
###   100.0% deep_resize()      (22.0fps)
###    16.8% nnedi3_resize16()  (3.7fps)
###
### General guidelines:
### -Avoid bicubics for highly compressed images as it will amplify DCT blocks
### -For downscaling use a 2-lobes sinc function (aka not bicubics)
### -For downscaling while preventing moiree use a 4-lobes sinc filter (ie. Lanczos4)
### -For sharp images (upscaling) use 3-lobes, for blurry ones 4 or more
### -More tappered (rolled-off) kernel bell shapes require higher taps (4 or above; Hann, Bohman, Blackman, Parzen, etc)
### -Use even number of taps (taps=lobes in AviSynth) to avoid a final positive lobe ("ringing") before cutoff of the window support. Negative lobes "ringing" are rarely created in gamma light resizing.
###
### More info: https://avisynth.nl/index.php/Resampling
###
### Function Definition:
###    (
###    clip,
###    float width=1920.00 (0.00 to 3840.00),
###    float height=1080.00 (0.00 to 2160.00),
###    string "edge"="nnedi3" ("nnedi3"/ "FCBI"/ "SuperResXBR"/ "Krig"/ "FSRCC"/ "DPID"/ "SSIM"/ "SSIM2"/ "--"/ "Nearest"/ "Box"/ "Bilinear"/ "Bicubic"/ "Quadratic"/ "Gauss"/ "--"/ "Wiener"/ "Spline"/ "Spline16"/ "Spline36"/ "Spline64"/ "Spline100"/ "Spline144"/ "Spline196"/ "Spline256"/ "--"/ "Jinc"/ "Jinc16"/ "Jinc36"/ "Jinc64"/ "Jinc100"/ "Jinc144"/ "Jinc196"/ "Jinc256"/ "EWASharp"/ "EWASharp2"/ "EWASharp4"/ "EWASharper"/ "EWASharper2"/ "EWASharper4"/ "EWASharpest"/ "EWASoft"/ "--"/ "Sinc"/ "SincLin"/ "SinPow"/ "--"/ "Welch"/ "Cosine"/ "Bessel"/ "Wiener"/ "Hamming"/ "Hann"/ "Kaiser"/ "Blackman"/ "Black-Harris"/ "Black-Nuttall"/ "Nuttall"/ "Bohman"/ "Parzen"/ "Lanczos"/ "Ginseng"/ "Flat-Top"/ "MinSide"/ "--"/ "SoftCubic100"/ "Robidoux Soft"/ "SoftCubic75"/ "BilcubicD"/ "BilcubicU"/ "Hermite"/ "Robidoux"/ "Centroid"/ "Mitchell-Netravali"/ "Robidoux Sharp"/ "SoftCubic50"/ "CatMule-Dog"/ "Cub-grange"/ "Catmull-Rom"/ "Didee"/ "Zopti"/ "ZoptiN"/ "ZoptiH"/ "Zopti720"/ "Zopti720U"/ "Zopti1080"/ "Precise"/ "Sharp"/ "Hatch"),
###    string "flat"="Lanczos" ("nnedi3"/ "FCBI"/ "SuperResXBR"/ "Krig"/ "FSRCC"/ "DPID"/ "SSIM"/ "SSIM2"/ "--"/ "Nearest"/ "Box"/ "Bilinear"/ "Bicubic"/ "Quadratic"/ "Gauss"/ "--"/ "Wiener"/ "Spline"/ "Spline16"/ "Spline36"/ "Spline64"/ "Spline100"/ "Spline144"/ "Spline196"/ "Spline256"/ "--"/ "Jinc"/ "Jinc16"/ "Jinc36"/ "Jinc64"/ "Jinc100"/ "Jinc144"/ "Jinc196"/ "Jinc256"/ "EWASharp"/ "EWASharp2"/ "EWASharp4"/ "EWASharper"/ "EWASharper2"/ "EWASharper4"/ "EWASharpest"/ "EWASoft"/ "--"/ "Sinc"/ "SincLin"/ "SinPow"/ "--"/ "Welch"/ "Cosine"/ "Bessel"/ "Wiener"/ "Hamming"/ "Hann"/ "Kaiser"/ "Blackman"/ "Black-Harris"/ "Black-Nuttall"/ "Nuttall"/ "Bohman"/ "Parzen"/ "Lanczos"/ "Ginseng"/ "Flat-Top"/ "MinSide"/ "--"/ "SoftCubic100"/ "Robidoux Soft"/ "SoftCubic75"/ "BilcubicD"/ "BilcubicU"/ "Hermite"/ "Robidoux"/ "Centroid"/ "Mitchell-Netravali"/ "Robidoux Sharp"/ "SoftCubic50"/ "CatMule-Dog"/ "Cub-grange"/ "Catmull-Rom"/ "Didee"/ "Zopti"/ "ZoptiN"/ "ZoptiH"/ "Zopti720"/ "Zopti720U"/ "Zopti1080"/ "Precise"/ "Sharp"/ "Hatch"),
###    string "chroma"="Blackman" ("nnedi3"/ "FCBI"/ "SuperResXBR"/ "Krig"/ "FSRCC"/ "DPID"/ "SSIM"/ "SSIM2"/ "--"/ "Nearest"/ "Box"/ "Bilinear"/ "Bicubic"/ "Quadratic"/ "Gauss"/ "--"/ "Wiener"/ "Spline"/ "Spline16"/ "Spline36"/ "Spline64"/ "Spline100"/ "Spline144"/ "Spline196"/ "Spline256"/ "--"/ "Jinc"/ "Jinc16"/ "Jinc36"/ "Jinc64"/ "Jinc100"/ "Jinc144"/ "Jinc196"/ "Jinc256"/ "EWASharp"/ "EWASharp2"/ "EWASharp4"/ "EWASharper"/ "EWASharper2"/ "EWASharper4"/ "EWASharpest"/ "EWASoft"/ "--"/ "Sinc"/ "SincLin"/ "SinPow"/ "--"/ "Welch"/ "Cosine"/ "Bessel"/ "Wiener"/ "Hamming"/ "Hann"/ "Kaiser"/ "Blackman"/ "Black-Harris"/ "Black-Nuttall"/ "Nuttall"/ "Bohman"/ "Parzen"/ "Lanczos"/ "Ginseng"/ "Flat-Top"/ "MinSide"/ "--"/ "SoftCubic100"/ "Robidoux Soft"/ "SoftCubic75"/ "BilcubicD"/ "BilcubicU"/ "Hermite"/ "Robidoux"/ "Centroid"/ "Mitchell-Netravali"/ "Robidoux Sharp"/ "SoftCubic50"/ "CatMule-Dog"/ "Cub-grange"/ "Catmull-Rom"/ "Didee"/ "Zopti"/ "ZoptiN"/ "ZoptiH"/ "Zopti720"/ "Zopti720U"/ "Zopti1080"/ "Precise"/ "Sharp"/ "Hatch"),
###    int "e_taps"=6 (2 to 20),
###    int "f_taps"=8 (2 to 20),
###    int "c_taps"=6 (2 to 20),
###    int "deconv"=0 (-10 to 15),
###    [float "grain"=0.0 (0.0 to 2.0)],
###    float "th_rat"=1.25 (1.00 to 2.00 by 0.05),
###    float "th"=1.0 (0.0 to 5.0),
###    float "elast"=4.0 (1.0 to 10.0),
###    int "qual"=1 (1 to 2),
###    [bool "show"=false]
###    )
###
###
### Examples:
###     # 720p to 1080p (for anime)
###     deep_resize(1920,flat="nnedi3",grain=0,qual=2)
###
###     # 720p to 1080p
###     deep_resize(1920) or deep_resize(1920,grain=0) for no grain
###
###     # 1080p to 2160p
###     deep_resize(3840) or deep_resize(3840,grain=0) for no grain
###
###     # 2160p to 1080p
###     deep_resize(1920,edge="Zopti1080") # for UHD sources "Zopti1080" is the default so can be omitted
###
###     # 1080p to 720p
###     deep_resize(1280,edge="SSIM2") # SSIM2 is the default so can be omitted
###
###     # 2160p to 720p
###     deep_resize(1920) or deep_resize(1920,edge="Zopti1080",flat="Zopti1080") # for dw flat=edge so flat="Zopti1080" can be omitted, dw to 1080p defaults to "Zopti1080" so can also be skipped
###     deep_resize(1280)
###
###
function deep_resize(clip a, val "width", val "height", string "edge", string "flat", string "chroma", int "e_taps", int "f_taps", int "c_taps", int "deconv", float "grain", float "th_rat", float "th", float "elast", int "qual", int "gpuid", bool "show") {

    wu  = !Defined(width)
    hu  = !Defined(height)
    w   = width (a)
    h   = height(a)
    rgb = isRGB (a)
    is4 = is444 (a)
    isy = isy   (a)
    mod = rgb || is4 || isy ? 1 : 2
    FC  = FrameCount(a)>1
    bi  = BitsPerComponent(a)
    fs  = propNumElements (a,"_ColorRange")     > 0 ? \
          propGetInt      (a,"_ColorRange")    == 0 : rgb
    cpl = propNumElements (a,"_ChromaLocation") > 0 ? \
          propGetInt      (a,"_ChromaLocation") : 0

    w2     = Default(width,  w)
    h2     = Default(height, h)

    Assert(IsVersionOrGreater(3,7,2),  "deep_resize: Update AviSynth+ version")
    Assert(isFloat(w2) || isFloat(h2), "deep_resize: Width/Height type not supported")

    w2     = isInt(w2) && w2<=10 ? float(w2) : isFloat(w2) && w2>10. ? int(w2) : w2
    h2     = isInt(h2) && h2<=10 ? float(h2) : isFloat(h2) && h2>10. ? int(h2) : h2
    w2     =  w2<=10. ? w*w2 : w2        w2 = round(w2/mod)*mod
    h2     =  h2<=10. ? h*h2 : h2        h2 = round(h2/mod)*mod
    w2     =  w2 == 0 || wu  ? round((w*(h2/float(h)))/mod)*mod : w2
    h2     =  h2 == 0 || hu  ? round((h*(w2/float(w)))/mod)*mod : h2

    isHD   = (w  > 1099 || h  >  599)
    isHD2  = (w2 > 1099 || h2 >  599)
    isUHD  = (w  > 2599 || h  > 1499)
    isUHD2 = (w2 > 2599 || h2 > 1499)

    rw     = w2/float(w)
    rh     = h2/float(h)
    factor =     max(rw,rh) < 3 ? 2 : 4
    rat    = abs(max(rw,rh)-1)+1

    rth    = Default(th_rat, 1.25)                                                          # threshold for mix mode. Lower than this (target_size/source_size) will use only 'kernel1' kernel
    krn1   = Default(edge, rat<=rth*0.95 ?                       "Didee" :               /* # Resize kernel for the edge area. AI upscalers recommended here: nnedi3, FSRCNN, FCBI, SuperResXBR... or for downscaling: DPID, SSIM2, Zopti */
           \                rw<1 && rh<1 ? isUHD ? "Zopti1080" : "SSIM2" :               /* # By default, for small upscales   -> "blackman" (define *small* with 'th_rat' value) */
           \               rat<=rth      ?         "Blackman"  : "nnedi3")               /* # By default, for big   upscales   -> "nnedi3"
                                                                                            # By default, for small downscales -> "Didée"
                                                                                            # By default, for big   downscales -> "Zopti1080"
                                                                                            # By default, for mid   downscales -> "SSIM2" (DPID also fine for down to 720p) (Beware!! for UHD to HD against all logic I recommend going with Zopti1080 (b=-0.99,c=0.06) )  */
    krn1c  = Default(chroma,rw<1 && rh<1 ? "Zopti"  : "Blackman")                           # Chroma resizing kernel (no edge/flat discretion) *Remember you can directly call "kernel + taps". ie. Blackman6, Lanczos4
    krn2   = Default(flat,  rw<1 && rh<1 ? krn1     : isHD && isUHD2 ? "Sinc" : "Lanczos" ) # Resize kernel for the flat area (noop when downscaling). Ringing kernels are ok here (specially when up ratio is <1.7) like SincLin, Blackman, Lanczos, Sinc... ('Sinc' low taps -ie. 4- is worth testing, creates some faints halos specially for SD to HD so see whether it's faint enough for you)
    etp    = Default(e_taps, krn1 =="Blackman" ? 6  : krn1 =="Lanczos" ? 4 : 0)             # taps for edge   kernel (0 for undefined)
    ftp    = Default(f_taps, krn2 =="Blackman" ? 16 : krn2 =="Lanczos" ? 8 : 0)             # taps for flat   kernel (0 for undefined)
    ctp    = Default(c_taps, krn1c=="Blackman" ? 6  : krn1c=="Lanczos" ? 4 : 0)             # taps for chroma kernel (0 for undefined)
    thr    = Default(th,      1.0)                                                          # 0-255 (normally up to 10)
    ela    = Default(elast,   4.0)                                                          # 1-255 (normally up to 10)
    qual   = Default(qual,      1)
    sh     = Default(show, false)
    gpuid  = Default(gpuid,     0)                                                          # Set to -1 for "cpu" nnedi3
    ddec   = Defined(deconv)
    dec    = Default(deconv,    0)                                                          # 0~10 (0 is disabled, raise to apply deconvolution when upscaling a very sharpened downscale -anything sharper than Catmull-Rom-)
    gr     = Default(grain, rw>1 && rh>1 && rat>rth ? 0.6 : 0 )                             # Grain strength. >0 Add grain to big upscales as a mean of cheap hallucination
    decs   = FindStr(LCase(krn2),"sinc")>0 && StrLen(krn2) < 7 ? dec+2 : dec
    dec    = ddec && dec == 0 ? 0 : abs(0.00135*decs*(w*0.5*rat)-0.095)                     # higher deconvolution the higher the upscale
    dec    = dec == 0.095 ? 0 : dec
    nns    = 3
    nns3   = 1 # for one dimensional scale
    nsize  = 0
    nsize3 = 6 # for one dimensional scale
    etype  = 0
    pscrn  = 2
    und    = Undefined()

    Assert(IsVersionOrGreater(3,7,2), "deep_resize: Update AviSynth+ version")

    if (rw==1 && rh==1) {

        a

    } else if (krn1 == krn2 && etp == ftp) {

        # Downscale/upscale with same edge/flat kernel
        ConvertFormat(a, w2,h2,cs_out="",EOTF="",kernel=krn1,kernel_c=krn1c,taps=[etp,ctp],tv_in=!fs,src_left=[0.0,0.0],src_top=[0.0,0.0])

    } else {


        if (krn1 == "nnedi3") {

            rfactor = rw<factor || rh<factor
            krnn    = rfactor ? "Bicubic" : "Blackman" # hard coded nnedi3 final edge resize: 'Didée' for down 'Blackman6' for up
        }

            # Y8 for nnedi3
            oned    = krn1 == "nnedi3" && (h == h2 || w == w2)
            an      = oned && !isy ? a.ExtractY() : a
            a8      = ConvertBits(an, 8, dither=-1, fulls=fs, fulld=fs)

            # nnedi3 one dimensional resize case

            edge1   = krn1 == "nnedi3" ? oned ? nnedi3wrap(a8,w!=w2?factor:1,h!=h2?factor:1,nns=nns3,nsize=nsize3,qual=qual,etype=etype,pscrn=pscrn,cshift="none",HBD=true,gpuid=gpuid) : \
                                                nnedi3wrap(a8,factor                       ,nns=nns ,nsize=nsize ,qual=qual,etype=etype,pscrn=pscrn,cshift="none",HBD=true,gpuid=gpuid) : \
                                                ConvertFormat(an,w2,h2,cs_out="",EOTF="",kernel=krn1,taps=etp,tv_in=!fs,src_left=[0.0,0.0],src_top=[0.0,0.0])

        if (rat <= rth) {

                      krn1 == "nnedi3" ? oned ? nnedi3resize(a,w2,h2,qual=qual,nns=nns3,nsize=nsize3,qual=qual,etype=etype,pscrn=pscrn,gpuid=gpuid) : edge1.propCopy(a) : edge1  # up/downscaling below ratio threshold

        } else {
            # resizing to target when nnedi3 is used
            edge1   = krn1 == "nnedi3" ? oned ? Eval(krnn+"resize(edge1,w2,h2,"+(rfactor ? "-0.5,0.25" : "taps=6")+(h==h2 ? ",src_left=cpl!=1 ? -float(w)/w2" : ",src_top=cpl!=1 ? -float(h)/h2")+" : 0)") : \
                                                Eval(krnn+"resize(edge1,w2,h2,"+(rfactor ? "-0.5,0.25" : "taps=6")+(        ",src_left=cpl!=1 ? -float(w)/w2 : 0 ,src_top=cpl!=1 ? -float(h)/h2     : 0)")) : edge1


            # don't sharpen nnedi3 when one dimensional resize case
            edge    = krn1 == "nnedi3" ? oned ? ConvertBits(edge1, bi, fulls=fs, fulld=fs) : \
                                                LSFplus(edge1,preset="LSF",strength=FC?2*rat:2,Smode=4,Lmode=2,edgemode=0,soothe=FC,overshoot=0,soft=-2,keep=0,tv_range=!fs).ConvertBits(bi, fulls=fs, fulld=fs) : edge1

            # resizing flat area
            flat    =                           ConvertFormat(a,w2,h2,cs_out="",EOTF="",kernel=krn2,kernel_c=krn1c,taps=[ftp,ctp],tv_in=!fs,src_left=[0.0,0.0],src_top=[0.0,0.0])

            # edge/flat limiting
            ex_limitdif(         !isy && oned ? flat.ExtractY() : flat, edge, thr=thr, elast=ela, UV=1)

            # combine planes when oned + nnedi3 case
                                 !isy && oned ? CombinePlanes(last, flat, planes="YUV", source_planes="YUV", pixel_type=PixelType(a)) : last
            # deconvolution from source downscaling
            dec == 0     ? last : ex_unsharp(w!=w2?-dec/100.:0,h!=h2?-dec/100.:0, Fc=max(w2,h2)/(rat*2)) } }

    size = w2/2134.
    gr > 0 ? GrainFactory3mod(g1str=6*gr,g2str=8*gr,g3str=5*gr,g1size=1.2*size,g2size=1.5*size,g3size=1.4*size,g1cstr=1.5*gr,g2cstr=1.5*gr,g3cstr=1.5*gr,temp_avg=0,tv_range=!fs) : last


    if (sh) {
            taps = """ krn1 == "Blackman" || krn1 == "Lanczos" || krn1 == "Sinc" || krn1 == "SincLin" || krn1 == "Jinc" """
            etp = etp == 0 ? "" : Eval(taps)                            ? Format("[{etp}]") : ""
            ftp = ftp == 0 ? "" : Eval(ReplaceStr(taps,"krn1","krn2" )) ? Format("[{ftp}]") : ""
            ctp = ctp == 0 ? "" : Eval(ReplaceStr(taps,"krn1","krn1c")) ? Format("[{ctp}]") : ""
            ecb = bicubic_coeffs(krn1)
            fcb = bicubic_coeffs(krn2)
            ccb = bicubic_coeffs(krn1c)   nul = "-2.000000, -2.000000"
            ecb = ArrayPrint(ecb,true) != nul ? "["+string(ecb[0],"%1.2f")+","+string(ecb[1],"%1.2f")+"]" : ""
            fcb = ArrayPrint(fcb,true) != nul ? "["+string(fcb[0],"%1.2f")+","+string(fcb[1],"%1.2f")+"]" : ""
            ccb = ArrayPrint(ccb,true) != nul ? "["+string(ccb[0],"%1.2f")+","+string(ccb[1],"%1.2f")+"]" : ""

            msize  = min(w2,h2)
            bg     = BoxMask(0,round(msize/1.55),0,round(msize/1.65), invert=true, tv_out=!fs)
            ex_blend(bg,"multiply",opacity=0.5,tv_range=!fs)

            Subtitle(" deep_resize()",                       size=msize/16,lsp=4,text_color=$ff5050,font="Segoe UI")
            Subtitle("\n\n SETTINGS:",                       size=msize/25,lsp=4,text_color=$ffcc99)
            Subtitle("\n\n\n\n "                \
                           +"size IN:\n "       \
                           +"size OUT:\n "      \
                           +"edge:\n "          \
                           +"flat:\n "          \
                           +"chroma:\n "        \
                           +"deconv:\n "        \
                           +"grain:\n "         \
                           +"th_rat:\n "        \
                           +"th:\n "            \
                           +"elast:",                        size=msize/25,lsp=4,text_color=$ffcc99)
            Subtitle(Format("\n\n\n\n "         \
                           +"{w}x{h} \n "       \
                           +"{w2}x{h2} \n "     \
                           +"{krn1} "   + etp + ecb + " \n " \
                           +"{krn2} "   + ftp + fcb + " \n " \
                           +"{krn1c} "  + ctp + ccb + " \n " \
                           +string(dec,"%1.3f")+" \n " \
                           +string(gr, "%1.3f")+" \n " \
                           +string(rth,"%1.3f")+" \n " \
                           +string(thr,"%1.3f")+" \n " \
                           +string(ela,"%1.3f")), x=msize/4, size=msize/25,lsp=4,text_color=$ffcc99)
 } }




#
# nnedi3resize()
#
# Simple upscaler that uses nnedi3wrap() at its core, recommended for graphics or textureless images.
# It accepts arbitrary dimension values, not only limited to powers of 2
#
# Dependencies:
#       ExTools
#       NNEDI3CL or nnedi3
#
function nnedi3resize(clip a, val "width", val "height", bool "HBD", int "qual", int "nns", int "nsize", int "etype", int "pscrn", int "gpuid") {

    wu      = !Defined(width)
    hu      = !Defined(height)
    w       = width (a)
    h       = height(a)
    rgb     = isRGB (a)
    is4     = is444 (a)
    isy     = isy   (a)
    mod     = rgb || is4 || isy ? 1 : 2

    w2     = Default(width,  w)
    h2     = Default(height, h)

    Assert(IsVersionOrGreater(3,7,2),  "nnedi3resize: Update AviSynth+ version")
    Assert(isFloat(w2) || isFloat(h2), "nnedi3resize: Width/Height type not supported")

    w2     = isInt(w2) && w2<=10 ? float(w2) : isFloat(w2) && w2>10. ? int(w2) : w2
    h2     = isInt(h2) && h2<=10 ? float(h2) : isFloat(h2) && h2>10. ? int(h2) : h2
    w2     =  w2<=10. ? w*w2 : w2        w2 = round(w2/mod)*mod
    h2     =  h2<=10. ? h*h2 : h2        h2 = round(h2/mod)*mod
    w2     =  w2 == 0 || wu  ? round((w*(h2/float(h)))/mod)*mod : w2
    h2     =  h2 == 0 || hu  ? round((h*(w2/float(w)))/mod)*mod : h2

    hs      = h == h2
    ws      = w == w2
    oned    = hs || ws
    HBD     = Default(HBD,    false)  # Force source HBD (slower)
    qual    = Default(qual,       1)
    gpuid   = Default(gpuid,      0)  # Set to -1 for "cpu" nnedi3
    nns     = Default(nns,   oned ? 1 : 3)
    nsize   = Default(nsize, oned ? 6 : 0)
    etype   = Default(etype,      0)
    pscrn   = Default(pscrn,      2)

    Assert(IsVersionOrGreater(3,7,2), "nnedi3resize: Update AviSynth+ version")

    rw      = w2/float(w)
    rh      = h2/float(h)
    factor  = max(rw,rh) < 3 ? 2 : 4
    rfactor = rw<factor && rh<factor
    krnn    = rfactor ? "Bicubic" : "Blackman" # hard coded nnedi3 final resize: 'Didée' for down 'Blackman6' for up

    nnedi3wrap(a,ws?1:factor,hs?1:factor,nns=nns,nsize=nsize,qual=qual,etype=etype,pscrn=pscrn,fwidth=w2,fheight=h2,ep0=rfactor?-0.5:6,ep1=0.25,cshift=krnn,HBD=HBD,gpuid=gpuid)

    }



#
# nnedi3wrap()
#
# Replacement wrapper for nnedi3_rpow2() and NNEDI3CL() based on 'gpuid' value (default 0 is for NNEDI3CL)
# Adds "_rpow2" functionality and its arguments to NNEDI3CL().
# Also decouples 'rfactor' into 'xfactor' and 'yfactor' and sets new reasonable defaults.
# Finally it automatically fixes center shift for both plugins, set cshift="none" to disable.
#
# Dependencies:
#       ExTools
#       NNEDI3CL
#       nnedi3
#         SysInfo
#
function nnedi3wrap(clip a, int "xfactor", int "yfactor", bool "HBD", int "qual", int "nns", int "nsize", int "etype", int "pscrn", int "fwidth", int "fheight", string "cshift", float "ep0", float "ep1", int "gpuid") {

    gpuid   = Default(gpuid,     0)  # Set to -1 for "cpu" nnedi3
    a       = gpuid>-1 ? propSet(a,"_FieldBased",0) : a
    w       = width (a)
    h       = height(a)
    rgb     = isRGB (a)
    is4     = is444 (a)
    isy     = isy   (a)
    bi      = BitsPerComponent(a)
    fs      = propNumElements (a,"_ColorRange")     > 0 ? \
              propGetInt      (a,"_ColorRange")    == 0 : rgb
    cpl     = propNumElements (a,"_ChromaLocation") > 0 ? \
              propGetInt      (a,"_ChromaLocation")     : 0

    Assert(IsVersionOrGreater(3,7,2), "nnedi3wrap: Update AviSynth+ version")

    xf      = Default(xfactor,    2)
    yf      = Default(yfactor,   xf)
    ws      = xf == 1
    hs      = yf == 1
    oned    = ws || hs
    xyf     = max(xf,yf)
    HBD     = Default(HBD,    false)  # Force source HBD (slower)
    qual    = Default(qual,       1)

    w1      = w*xf
    h1      = h*yf
    nns     = Default(nns,   oned ? 1 : 3)
    nsize   = Default(nsize, oned ? 6 : 0)
    etype   = Default(etype,      0)
    pscrn   = Default(pscrn,      2)
    dfw     = Defined(fwidth)
    dfh     = Defined(fheight)
    w2      = Default(fwidth,     w1)
    h2      = Default(fheight,    h1)

    sm      = w2 == w1 && h1 == h1
    rw      = w2/float(w1)
    rh      = h2/float(h1)
    factor  = max(rw,rh) < 3 ? 2 : 4
    rfactor = rw<factor && rh<factor

    krnn    = Default(cshift, sm ? "spline16" : rfactor ? "Bicubic" : "Blackman") # kernel used for fwidth or fheight, otherwise only for pixel shift (set to "none" to disable shift fix)
    ep0     = Default(ep0,                      rfactor ? -0.5 : 6)
    ep1     = Default(ep1,                                 0.25)

    # 8-bit for nnedi3
    a8  = !HBD ? ConvertBits(a, 8, dither=-1, fulls=fs, fulld=fs) : a

    if (gpuid<0) {

        cores   = SI_PhysicalCores()
        threads = SI_LogicalCores()
        if (!oned) {
            nnedi3_rpow2(a8,rfactor=xyf,nns=nns,nsize=nsize,qual=qual,etype=etype,pscrn=pscrn,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2,mpeg2=cpl!=1,fwidth=w2,fheight=h2,cshift=krnn=="none"?Undefined():krnn+"resize",ep0=ep0,ep1=ep1)

        } else {

            hs          ? TurnRight(a8) : a8
            for (i = 1, xyf/2, 1) {
                nnedi3(field=1,dh=True, nns=nns,nsize=nsize,qual=qual,etype=etype,pscrn=pscrn,threads=cores,prefetch=(threads+cores)/2,range=fs?1:2)
            }
            hs          ? TurnLeft()    : last
        }

    } else {
        a8
        for (i = 1, xyf/2, 1) {
            NNEDI3CL(1, dh=!hs, dw=!ws, nns=nns,nsize=nsize,qual=qual,etype=etype,pscrn=pscrn,device=gpuid)
            }
    }

    # Fix for pixel center shift or for final scaling
    if (krnn!="none" && (((dfw||dfh) && !sm) || (oned || gpuid>-1))) {
        cs  = cpl!=1 ? -0.5 * (xyf-1) : 0
        krn = LCase(krnn)
        krn = FindStr(krn, "bicubic") >0 ? 0 : FindStr( krn, "spline")>0 ? 1 : 2
        Eval(krnn+"resize(w2,h2"+(krn==0 ? ",ep0,ep1" : krn==2 ? ",taps=round(ep0)" : "")+(hs ? ",src_left=cs)" : ws ? ",src_top=cs)" : ",src_left=cs,src_top=cs)"))
    }

    !HBD ? ConvertBits(bi, fulls=fs, fulld=fs) : last
    propCopy(a) }




##############################
###
### RatioResize()
###
### Resizer based on different ratios, like DAR, PAR, percentage, etc.
### More like a useful resize calculator than a resizer per se.
### The Mode parameter accepts the next ones (in quotes):
###
### "DAR"         Convert source to a target DAR (display aspect ratio).
### "DARConform"  You can also "conform" DAR:
###               i.e. resize it in such way that when your media player apply DAR of 4/3, 16/9, etc
###               to your video, image is geometry correct. Useful for anamorphic encodes.
### "%"           I added a percentage mode too, for example use 0.5 to resize to half.
###               You actually can read it as "how many times the original size"
### "PAR"         Find out what PAR your source is and input here.
###               If you are thinking in crop + resize (anamorphic) and want to know what your PAR
###               changed to, then apply the formula below* and input it along your target dimensions (PreW,PreH)
### "adjust2w"    Or "w" for short. This new mode resizes height according to input width. So you input your target width size
###               as the ratio value, and target height will resize automatically according keeping image proportions.
### "adjust2h"    Or "h" for short. Same as above, but here you constrain to the target height instead.
###
### PreW,PreH  Substitutes resizing previously.
###
### Mod        Defines what mod you want to conform to for output (calculated values); mod2, mod4, mod8...  (input stays the same if defined)
###
### Kernel     Define the kernel (resizer algo) you want to use: nnedi3, spline36, spline64, bicubic, lanczos, etc
###
### b, c       These are the supplementary parameters for BicubicResize, so you can do Catmull-Rom, Robidoux, etc
###
### NOTE:      ALWAYS USE FLOAT VALUES 0.9, 1.33, 4/3.0, 16/9.0, etc
###
###
### *NOTE for "PAR":
###
### ((source.croppedRes)*(source.taggedPAR))/(target.Res)=new par
### i.e.
### ((706/478)*(4320/4739))/(720/480)=0.8975
###
### Example:
###     RatioResize(0.8975,"PAR",prew=720,preh=480)
###
### Function Definition:
###    (
###    clip,
###    float ratio=1.0 (0.0 to 2.0),
###    string mode="%" ("adjust2w"/ "adjust2h"/ "DAR"/ "DARconform"/ "PAR"/ "%"),
###    int mod=2 (1 to 16),
###    string kernel="bicubic" ("spline16"/ "spline36"/ "spline64"/ "lanczos"/ "lanczos4"/ "blackman"/ "Sinc"/ "Point"/ "bilinear"/ "bicubic"/ "deep"/ "nnedi3"),
###    float b=0.00 (-1.00 to 1.00),
###    float c=0.50 (0.00 to 1.00)
###    )
###
###############################################################################


function RatioResize(clip s, float "ratio", string "mode", int "mod", string "kernel", float "b", float "c", float "p", float "src_left", float "src_top", int "PreW", int "PreH") {

    rgb   = isRGB(s)
    r     = Default(ratio,      0.5)
    md    = Default(mode,       "%")
    mod   = Default(mod, rgb ? 1 : 2)
    w     = Default(PreW,  s.width ())
    h     = Default(PreH,  s.height())
    b     = Default(b,       0.0)
    c     = Default(c,       0.5)
    src_l = Default(src_left,  0)
    src_t = Default(src_top,   0)
    kernel= Default(kernel,"bicubic")

    r  = float(r)

    v  = md=="adjust2w" || md=="w" ? h/(w/r)
    \  : md=="adjust2h" || md=="h" ? w/(h/r)
    \  : md=="DAR"                 ? w/(w/(h*r))
    \  : md=="DARconform"          ? w*(w/(h*r))
    \  : md=="PAR"                 \
      || md=="%"                   ? w*r : nop()
    h1 = md=="%"                   ? h*r : nop()

    Vmod= nmod(v,mod)
    rmod= nmod(r,mod)

    op = md=="DAR"
    \ || md=="DARconform"
    \ || md=="PAR"                 ? "Vmod,h"
    \  : md=="%"                   ? "Vmod,nmod(h1,mod)"
    \  : md=="adjust2w" || md=="w" ? "rmod,Vmod"
    \  : md=="adjust2h" || md=="h" ? "Vmod,rmod"
    \  :  Assert(false, "RatioResize: Wrong Ratio mode")


    kernel == "deep"   ? Eval(    "deep_resize(s," + String(op) + ")"                                 ) : \
    kernel == "nnedi3" ? Eval(   "nnedi3resize(s," + String(op) + ")"                                 ) : \
    kernel == "gauss"  ? Eval(    "GaussResize(s," + String(op) + ",p=p,src_left=src_l,src_top=src_t)") : \
    kernel == "bicubic"? Eval(  "BicubicResize(s," + String(op) + ",b,c,src_left=src_l,src_top=src_t)") : \
                         Eval(kernel + "Resize(s," + String(op) + ",    src_left=src_l,src_top=src_t)") }



##############################
###
### PadResize()
###
### Write target size and image will crop or pad...
### depending on source dimensions by adding black borders, mirroring borders or extending them depending on 'mode'.
###
### bias:  From -width() or -height() to +width() or height(), to slide the frame within the resolution (ie. an asymmetrical matte)
###
### *Color mode has two ways for inputs, the classical PC range based hexadecimal (see link below) or an alternative more intuitive way
###  by using an int array as string. For example for YUV TV Black you can input "$108080" or "[16,128,128]". Both modes are valid.
###
### Function Definition:
###    (
###    clip,
###    int width=1920 (0 to 3840),
###    int height=1080 (0 to 2160),
###    int "mod"=2 (1 to 16),
###    string "mode"="$108080" ("Dilate"/ "Mirror"/ "Fill"/ "[16,128,128]"/ "[0,128,128]"),
###    int "biasW"=0 (-1920 to 1920),
###    int "biasH"=0 (-1080 to 1080)
###    )
###
function PadResize(clip c, int "width", int "height", int "mod", string "mode", int "biasW", int "biasH") {

    c
    rgb = isRGB()
    w   = width()
    h   = height()
    fch = isy() || rgb || is444()

    wt     = Default(width,  w)
    ht     = Default(height, h)
    mod    = Default(mod,    fch ? 1 : 2)
    bw     = Default(biasW,  0)
    bh     = Default(biasH,  0)
    # mode: 'Dilate', 'Mirror', 'Fill' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)

    wn  = nmod(wt,mod)  wa = wn-w
    hn  = nmod(ht,mod)  ha = hn-h

    wh  = abs(wa)/2.
    hh  = abs(ha)/2.
    wf  = floor(wh)      wd = Frac (wh)
    hf  = floor(hh)      hd = Frac (hh)
    w1  = ceil (wd)+wf   w2 = floor(wd)+wf
    h1  = ceil (hd)+hf   h2 = floor(hd)+hf

    bw1 = fch ? bw : bw+bw%2
    bh1 = fch ? bh : bh+bh%2
    sgw = sign(wa)
    sgh = sign(ha)

    PadBorders(sgw*w1+bw1,sgh*h1+bh1,\
               sgw*w2-bw1,sgh*h2-bh1,mode) }



##############################
###
### PadBorders()
###
### Superseeds AddBorders(), Crop(), old PadMirror() and Didée's Padding() (21-10-2012) (https://forum.doom9.org/showthread.php?p=1596804#post1596804)
### in one single filter.
### In other words, with "mode" option you can dilate (extend), mirror, or add colored borders (https://avisynth.nl/index.php/Color_presets).
###
### 'Dilate' is slightly faster than 'Mirror' (and probably filtering friendlier)
### 'Fill' requires FillBorders plugin, and mostly works at low units (1 or 2 pixels max)
###  Old PadMirror() itself was inspired by Didée's BorderMirror() (30-06-2004) (https://forum.doom9.org/showthread.php?p=518131#post518131)
###
### You can also crop at the same time, let's say crop sides, pad vertically:
###     PadBorders(-10,20,-10,20,"Dilate")
###
### *Color mode has two ways for inputs, the classical PC range based hexadecimal (see link above) or an alternative more intuitive way
###  by using an int array as string. For example for YUV TV Black you can input "$108080" or "[16,128,128]". Both modes are valid.
###
### Function Definition:
###    (
###    clip,
###    int left=0 (-1000 to 1000 by 2),
###    int top=0 (-1000 to 1000 by 2),
###    int right=0 (-1000 to 1000 by 2),
###    int bottom=0 (-1000 to 1000 by 2),
###    string "mode"="$108080" ("Dilate"/ "Mirror"/ "Fill"/ "[16,128,128]"/ "[0,128,128]")
###    )
###
function PadBorders(clip src, int "left", int "top", int "right", int "bottom", string "mode") {

    src
    w   = width()
    h   = height()
    rgb = isRGB()
    isy = isy()
    fch = isy || rgb || is444()
    mod = fch ? 1 : 2
    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : rgb

    l  = Default( left,   0 )
    t  = Default( top,    0 )
    r  = Default( right,  0 )
    b  = Default( bottom, 0 )
    md = Default( mode, !rgb ? fs ? "$008080" : "$108080" : \
                               fs ? "$000000" : "$101010" )  # 'Dilate', 'Mirror', 'Fill' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)

    md = LeftStr(md,1)=="[" ? ColortoHex(md) : md

    lc  = nmod(min(l,0),mod)    l  = nmod(max(l,0),mod)
    tc  = nmod(min(t,0),mod)    t  = nmod(max(t,0),mod)
    rc  = nmod(min(r,0),mod)    r  = nmod(max(r,0),mod)
    bc  = nmod(min(b,0),mod)    b  = nmod(max(b,0),mod)


    if (max(l,t,r,b)==0) {

        Crop(-lc,-tc,rc,bc)

    } else if (md=="mirror") {

        top=(t  > 0) ? crop(0,0,0,-h+t,      true).flipvertical()   : last
            (t  > 0) ? stackvertical( top,src )                : last
        bot=(b  > 0) ? crop(0,height()-b,0,0,true).flipvertical()   : last
            (b  > 0) ? stackvertical( last,bot )               : last
        lft=(l  > 0) ? crop(0,0,-width()+l,0,true).fliphorizontal() : last
            (l  > 0) ? stackhorizontal(lft,last)               : last
        rgh=(r  > 0) ? crop(width()-r,0,0,0, true).fliphorizontal() : last
            (r  > 0) ? stackhorizontal(last,rgh)               : last
                       crop(-lc,-tc,rc,bc)

    } else if (md=="dilate"||md=="fill") {

        PointResize(w+l+r+lc+rc, h+t+b+tc+bc, -l-lc, -t-tc, w+l+r+lc+rc, h+t+b+tc+bc)
        md=="fill" ? FillBorders(l,t,r,b,mode=6) : last

    } else if (LeftStr(md,1)=="$") {

        rgb ? AddBorders(l,t,r,b,             Eval(md)) : \
              AddBorders(l,t,r,b, color_yuv = Eval(md))
              Crop      (-lc,-tc,rc,bc)

    } else {

        Assert(false, "PadBorders: Wrong mode")

    } }




###
#
#  nmod() - Rounding numbers by Dogway (28-11-2021)
#
#  Description from SmoothD2c:
#
# "mod-4"   see "Crop restrictions" in https://avisynth.nl/index.php/Crop
#           nmod(n,4) is used in many scripts that do resizing.
# "mod-8"   is used so that cropping will occur on luma block (8x8) boundaries
#           and that resizing will produce an integer number of luma blocks.
# "mod-16"  is used so that cropping will occur on YV12 chroma block (16x16) boundaries
#           and that resizing will produce an integer number of chroma blocks.
# "mod-m32" is used so that the zw1 mask can be resized to the size of the u and v planes.
#
# mod:     Rounding to defined 'mod' value
# min:     Rounding never goes below the 'min' value. Usually you want to set this to mod*2
# dec:     Rounding to defined decimal number. Also works for mod > 1 (rounding is done prior to mod)
# bankers: By default 2.5 rounds to 3. With 'bankers=true' half float values round towards 0, so 2 in this case
#
# Examples:
#   nmod(3)                    -> 4
#   nmod(2,4)                  -> 4
#   nmod(2,4,    bankers=true) -> 0
#   nmod(2,4,1,  bankers=true) -> 4
#   nmod(2,4,4.1,bankers=true) -> 4.1
#   nmod(pi, dec=2)            -> 3.14
#
function nmod(val n, int "mod", val "min", int "dec", bool "bankers") {

    dm  = Defined(min)               # Set 'min' to 16 for at-least n=16
    dc  = Defined(dec)
    mod = Default(mod, dc ? 1 : 2)
    mod = max(mod, 1)
    bnk = Default(bankers, false)    # Use bankers' rounding. Requires SimilarityMetrics
    und = Undefined()
    dec = dc ? "%0."+string(dec)+"f"  : und
    n   = dc ? Eval(String(n,   dec)) : float(n)
    mnf = dc ? Eval(String(min, dec)) : min
    mnf = dm ? mnf : und

         Assert(isFloat(n),   "nmod: 'n' is not a number")
    dm ? Assert(isFloat(min), "nmod: 'min' is not a number") : nop()

    return (  dc && mod == 1                       ? Eval(String(dm ? max(min,n) : n, dec)) : \
             !dc && dm && nmod(n,mod,und,dec,bnk)  < max(mod,min)   ? max(mod,mnf)          : \
              bnk                                  ? RoundHalfToEven_mod(n, mod)            : \
                                                     round( n / mod ) * mod )               }



##############################
### Adjust source to mod(n) size by adding or cropping borders.
### It's a simpler, more straight-forward alternative than PadResize()
###
### modes:
###     "auto" - will crop or pad depending on minimal transform (Default)
###     "crop" - will force cropping to mod
###     "pad"  - will force padding  to mod
###
function mmod(clip c, int "modH", int "modV", string "mode", string "borders") {

    c
    w   = width()
    h   = height()

    mdh = Default(modH,         2)
    mdv = Default(modV,       mdh)
    md  = Default(mode,    "auto")
    bd  = Default(borders, max(mdh,mdv)<3?"Fill":"Dilate")
    # borders: 'Dilate', 'Mirror', 'Fill' or color code (ie. "$108080" for YUV TV black or "$008080" for YUV PC black)

    # Ground truth for 'auto'
    wn  = nmod(w,mdh)  wa = abs(wn-w)
    hn  = nmod(h,mdv)  ha = abs(hn-h)

    # Ground truth for 'crop'
    wc  = w%mdh
    hc  = h%mdv

    # Ground truth for 'pad'
    wp  = wc != 0 ? abs(wc-mdh) : 0
    hp  = hc != 0 ? abs(hc-mdv) : 0

    # Crop or Pad
    wc  = md=="crop" ? wc : md=="pad" ? wp : wa
    hc  = md=="crop" ? hc : md=="pad" ? hp : ha

    # Rounding
    wh  = wc/2.
    hh  = hc/2.
    wf  = floor(wh)    wd = Frac (wh)
    hf  = floor(hh)    hd = Frac (hh)
    w1  = ceil (wd)+wf w2 = floor(wd)+wf
    h1  = ceil (hd)+hf h2 = floor(hd)+hf

    # Assignment
    wc1 = md=="auto" ? wn >= w ? w1 : -w1 : md=="crop" ?  -w1 : w1
    wc2 = md=="auto" ? wn >= w ? w2 : -w2 : md=="crop" ?  -w2 : w2
    hc1 = md=="auto" ? hn >= h ? h1 : -h1 : md=="crop" ?  -h1 : h1
    hc2 = md=="auto" ? hn >= h ? h2 : -h2 : md=="crop" ?  -h2 : h2

    PadBorders(wc1,hc1,wc2,hc2,bd) }



# Converts a 'string' type color array into an hexadecimal string
# "[16,128,128]" -> "$108080"
function ColortoHex(string color) {
    cl = Eval(Color)
    Y  = clamp(cl[0],0,255)
    U  = clamp(cl[1],0,255)
    V  = clamp(cl[2],0,255)
    Return "$"+string(Hex(Y,2))+string(Hex(U,2))+string(Hex(V,2)) }





##############################
###
### MatteCrop() - by Dogway (15-10-2021)
###
### https://forum.doom9.org/showthread.php?t=182678
###
### Automatic cropping and/or centering function.
### It works more like a recentering function when borders are asymmetrical or varying between shots.
###
###
### "Width/Height"     Destination width/height
### "thr"              Threshold, pixel values above this will be considered borders
### "CropMore"         In case of odd cropping, either crop 1 pixel out or leave 1 pixel of the border
### "ScanW/ScanH"      Range of pixels for scanning borders, set this to minimum to enhance performance
### "Moving"           If the matte is moving (sliding) it defaults to 1 pixel accuracy, among other settings (check defaults)
### "mode"             Mode of the function. 0: centers the frame within borders
###                                          1: crops to minimum found borders (Work in Progress)
###                                          2: resize bordered shots to destination width/height (Default)
###                                          3: hybrid, automatic method between method 0 and 2
### "Kernel"           Kernel to use for resizing
###
###
### Dependencies:
### ------------
###   ExTools
###   ClipBoard          (https://avisynth.nl/index.php/ClipBoard)
###   SCSelect_HBD v0.02 (https://github.com/Dogway/Avisynth-Scripts/tree/master/EX%20mods)
###   MasksPack          (https://github.com/Dogway/Avisynth-Scripts)
###   EdgeFixer          (https://avisynth.nl/index.php/EdgeFixer)
###
###
### i.e.
### MatteCrop(1920,1080,thr=16.0,cropmore=true,ScanW=90,ScanH=0,mode=2)
###
###############################################################################

function MatteCrop(clip s, int "width", int "height", float "thr", bool "CropMore", bool "Moving", int "ScanW", int "ScanH", int "mode", float "SC_thr", string "kernel", float "b", float "c", float "p") {

    s
    rgb    = isRGB()
    isy    = isy()
    fch    = isy || rgb || is444()
    bi     = BitsPerComponent(s)
    w      = width()
    h      = height()


    nw     = Default(width, w)
    nh     = Default(height,h)
    addw   = Default(ScanW,round((w/8.)))
    addh   = Default(ScanH,round((h/4.)))
    Mot    = Default(Moving, False)                # If the matte is moving (sliding) this enables pixel level accuracy.
    CM     = Default(CropMore, Mot || fch)         # In case of odd cropping, either crop 1 pixel out or leave 1 pixel of the border
    thr    = Default(thr, Mot ? 16.3 : 16.0)       # Threshold, pixel values same or below this will be considered borders
    mode   = Default(mode, 2)                      # 0: center+pad 1: crop to minimum (WIP) 2: resize to maximum 3: hybrid 0-2 (auto)
    SC_thr = Default(SC_thr, 3.5)                  # Scene Change detection threshold
    kernel = Default(kernel, "bicubic")            # Kernel to use when resizing (mode=2)
    b      = Default(b, 0.0)
    c      = Default(c, 0.75)                      # Precise Bicubic by default (fast and HQ)
    p      = Default(p, 100.0)
    fs     = rgb

    addw==0 ? Assert( addh>0, "MatteCrop: You need to scan borders for at least one of the dimension") : nop()
    addh==0 ? Assert( addw>0, "MatteCrop: You need to scan borders for at least one of the dimension") : nop()

    thr    = ex_bs(thr, 8, bi, fulls=fs, flt=true)
    addwz  = addw > 0
    addhz  = addh > 0

    avgY = !isy ? ExtractY().ConvertBits(8,dither=-1,fulls=fs) : ConvertBits(8,dither=-1,fulls=fs)
    avg  = avgY.RatioResize(320.0,  "adjust2w",kernel="bilinear")
    avg  = avg.TemporalSoften(10,255,255,10,2)
    avg  = avg.TemporalSoften(10,255,255,10,2)
    avg  = avg.RatioResize(float(w),"adjust2w",kernel="bicubic")

    avgc = ex_merge(avgY, avg, BoxMask(avg,addw,w-addw,addh,h-addh)).ConvertBits(bi,dither=-1,fulls=fs)

    SC   = SCSelect_HBD(avg,dfactor=SC_thr,mindif=1.0)

    # Add detection of credits and bumpers
    ScriptClip(s, function [s,SC,avgc,addw,addh,addwz,addhz,w,h,thr,CM,Mot,fch,kernel,b,c,p,mode] () {

        step  = Mot ? 1 : 2

        mode==3 ? Eval("
        LBox = YPlaneMax(crop( addhz ? width()-16 : 0,0,0, addwz ? -height()+16 : 0, true)) <= float(thr)
        CM   = LBox
        ") : nop()

    if (propGetInt(SC,"_SceneChangePrev") == 1) {

        x1=0 x2=0
        y1=0 y2=0

        trim(avgc, current_frame+10, -1)

        addwz ? Eval("
        for (li=step, addw, step) {
          if (AverageLuma(crop(li-step,0,-w+li,0,true))>thr) {
            x1= CM ? li : li-step
            li=addw
           }
        }

        for (ri=step, addw, step) {
          if (AverageLuma(crop(w-ri,0,-ri+step,0,true))>thr) {
            x2= CM ? ri : ri-step
            ri=addw
          }
        }") : nop()


        addhz ? Eval("
        for (ti=step, addh, step) {
          if (AverageLuma(crop(0,ti-step,0,-h+ti,true))>thr) {
            y1= CM ? ti : ti-step
            ti=addh
          }
        }

        for (bi=step, addh, step) {
          if (AverageLuma(crop(0,h-bi,0 ,-bi+step,true))>thr) {
            y2= CM ? bi : bi-step
            bi=addh
          }
        }") : nop()

        ClipBoard_PutText(String(Format("x1={x1}  x2={x2}  y1={y1}  y2={y2}  ")))
        }


        cbs = ClipBoard_GetText()
        x1  = Eval(MidStr(cbs,FindStr(cbs,"x1=")+3,3))
        x2  = Eval(MidStr(cbs,FindStr(cbs,"x2=")+3,3))
        y1  = Eval(MidStr(cbs,FindStr(cbs,"y1=")+3,3))
        y2  = Eval(MidStr(cbs,FindStr(cbs,"y2=")+3,3))

        MotW = Mot ? round(w-x1-x2) : nop()
        MotH = Mot ? round(h-y1-y2) : nop()
        Mot ? spline36resize(s,fch?MotW:nmod(MotW,2),fch?MotH:nmod(MotH,2),src_left=x1,src_width=-x2,src_top=y1,src_height=-y2) : \
              crop(s,x1,y1,-x2,-y2,true)

        mode == 0 ? PadResize(w,h) : \
        mode == 1 ? PadResize(w,h) : \
        mode == 2 ? RatioResize(float(w),"adjust2w", kernel=kernel, b=b, c=c, p=p).PadResize(w,h) : \
                    LBox ? \
                    RatioResize(float(w),"adjust2w", kernel=kernel, b=b, c=c, p=p).PadResize(w,h) : PadResize(w,h)
    } )

    mode == 0 ? PadResize(nw,nh) : \
    mode == 1 ? PadResize(nw,nh) : \
                kernel == "deep"   ? Eval(     "deep_resize(" + String(nw) + "," + String(nh) + ")")     : \
                kernel == "gauss"  ? Eval(     "GaussResize(" + String(nw) + "," + String(nh) + ",p=p)") : \
                kernel == "bicubic"? Eval(   "BicubicResize(" + String(nw) + "," + String(nh) + ",b,c)") : \
                                     Eval( kernel + "Resize(" + String(nw) + "," + String(nh) + ")")


    (!CM || Mot) && mode>1 ? ContinuityFixer(left=addwz?2:0, top=addhz?2:0, right=addwz?2:0, bottom=addhz?2:0, radius=CM && w>720?0:1) : last }
