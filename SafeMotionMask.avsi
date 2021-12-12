# 14-01-2014
# SafeMotionMask(mv=1,mt=false,EM=false,LM=2, gam=0.3, motion=80, line=255, darkb=40, darkw=80)

# MV=mvtools vector mask. Use 1, 2 or 3 for temporal radius
# MT=masktools motion mask
# LM=masktools luma mask. 0=disabled, 1=enabled without lineart, 2=enabled full
# EM=masktools edge mask

# gam   = MV. Gamma
# motion= MT. Strength
# darkb = LM. Dark thr
# darkw = LM. Bright thr
# line  = EM. strength

function SafeMotionMask(clip source, int "MV", bool "MT", int "LM", bool "EM", float "gam", int "motion", int "line", int "darkb", int "darkw") {

    source

    MV     = Default(MV, 1)
    MT     = Default(MT, true)
    LM     = Default(LM, 2)
    EM     = Default(EM, true)

    gam    = Default(gam, 0.3)
    motion = Default(motion, 70)
    darkb  = Default(darkb, 40)
    darkw  = Default(darkw, 80)
    line   = Default(line, 255)

    isHD = (width() > 1099 ||  height() > 599)


    kind=0
    blksize=8
    overlap=4
    SCD1=500
    SCD2=150
    asuper=MSuper(pel=isHD?1:2,sharp=2,hpad=0, vpad=0,chroma=true)
    psuper=asuper
    b3v = MAnalyse(psuper, isb=true, delta=3, blksize=blksize, overlap=overlap,chroma=true)
    b2v = MAnalyse(psuper, isb=true, delta=2, blksize=blksize, overlap=overlap,chroma=true)
    b1v = MAnalyse(psuper, isb=true, delta=1, blksize=blksize, overlap=overlap,chroma=true)
    f1v = MAnalyse(psuper, delta=1, blksize=blksize, overlap=overlap,chroma=true)
    f2v = MAnalyse(psuper, delta=2, blksize=blksize, overlap=overlap,chroma=true)
    f3v = MAnalyse(psuper, delta=3, blksize=blksize, overlap=overlap,chroma=true)
    b3v = MRecalculate(psuper, b3v,overlap=overlap/2,blksize=blksize/2, thSAD=250,chroma=true)
    b2v = MRecalculate(psuper, b2v,overlap=overlap/2,blksize=blksize/2, thSAD=250,chroma=true)
    b1v = MRecalculate(psuper, b1v,overlap=overlap/2,blksize=blksize/2, thSAD=250,chroma=true)
    f1v = MRecalculate(psuper, f1v,overlap=overlap/2,blksize=blksize/2, thSAD=250,chroma=true)
    f2v = MRecalculate(psuper, f2v,overlap=overlap/2,blksize=blksize/2, thSAD=250,chroma=true)
    f3v = MRecalculate(psuper, f3v,overlap=overlap/2,blksize=blksize/2, thSAD=250,chroma=true)
    SADbv3 = MMask(b3v,kind=kind,gamma=gam,thSCD1=SCD1,thSCD2=SCD2)
    SADbv2 = MMask(b2v,kind=kind,gamma=gam,thSCD1=SCD1,thSCD2=SCD2)
    SADbv1 = MMask(b1v,kind=kind,gamma=gam,thSCD1=SCD1,thSCD2=SCD2)
    SADfv1 = MMask(f1v,kind=kind,gamma=gam,thSCD1=SCD1,thSCD2=SCD2)
    SADfv2 = MMask(f2v,kind=kind,gamma=gam,thSCD1=SCD1,thSCD2=SCD2)
    SADfv3 = MMask(f3v,kind=kind,gamma=gam,thSCD1=SCD1,thSCD2=SCD2)

    ### Average Mask ###
    MVMask =  (MV > 2) ? average(SADbv3,1./6,SADbv2,1./6,SADbv1,1./6,SADfv1,1./6,SADfv2,1./6,SADfv3,1./6) : \
              (MV > 1) ? average(SADbv2,1./4,SADbv1,1./4,SADfv1,1./4,SADfv2,1./4) : \
              (MV > 0) ? average(SADbv1,1./2,SADfv1,1./2) : nop()
    MV = MV > 0
    # mask tuning
    #MVMask=LumaMask(MVMask, b=35, w=90, invert=false)


    ### Luma Mask ###
        Luma = LumaMask(source, b=darkb, w=darkw, invert=true)


    ### Motion Mask ###
    ts=3
    temp       = source.TemporalSoften(ts,255,255,25,2)
    inter      = Interleave(temp.Repair(source.TemporalSoften(1,255,255,25,2)),source)
    MotionMask = mt_motion(inter, thy1=0,thy2=motion,tht=255,U=-128,V=-128).selectevery(2,1)

    ### Line Mask ###
    LineMask = mt_edge("prewitt",thY1=0,thY2=line)
    # mask tuning
    #white=100
    #black=80
    #noline2=noline2.ex_expand(2).ex_lut("x "+string(white)+" > 255 x "+string(black)+" < 0 x ? ?").ex_invert()



    # merge 2 motion masks
    MMask = (MT && MV) ? ex_lutxy(MotionMask, MVMask,"y x +",UV=1).mtcv() : \
            (MT) ? MotionMask : \
            (MV) ? MVMask : nop()

    # and clean and expand
    Motion = (MT || MV)
    Dark1  = LM==1
    Motion ? eval("""MMask.mtcv()
    w=width()
    h=height()
    BicubicResize(round(w/4.),round(h/4.),2,0).mtcv().mt_expand().TemporalSoften(4,255,255,0,2)
    GaussResize(w,h)
    LumaMask(last, b=15, w=80, invert=false)""") : nop()

    # plus line mask
    MMask = EM ? (Motion ? ex_logic(LineMask, mode="max").mtcv() : \
                           Linemask.mtcv())                      : last

    # plus luma mask
    LinedLuma  = ex_logic(LineMask, Luma, mode="max").mtcv()
    LinedLuma2 = Dark1 ? ex_lutxy(LineMask.mtcv(),Luma,"y x -",UV=1).mtcv() : Luma.mtcv()

    # Output Logic
    (Dark1 || LM==2) ? (EM ? (!Motion                                  ? \
                               LinedLuma                               : \
                               ex_logic(last, LinedLuma,  mode="max")) : \
                               ( Motion                                ? \
                               ex_logic(last, LinedLuma2, mode="max")  : \
                                              LinedLuma2)) : MMask
    greyscale}


function mtcv(clip source) {
    source
    ex_expand().ex_boxblur(1,mode="mean")}