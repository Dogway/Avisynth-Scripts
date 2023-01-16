###
###
###  MCaWarpSharp4() - (24-11-2011)
###                 :fix halo, chroma bleeding & blurry edges (Sharpener/Line Enhancer)
###
### Line enhancer: define (sharpen) blurry edges, or remove ringing.
###
### By z. ndmn.(zee944) with Didée guidance.
### v4.0 Optimized by Dogway (18-10-2021)
### https://forum.doom9.org/showthread.php?t=159248
###
###
### Dependencies:
###             MVTools2
###             ExTools
###             ResizersPack
###             LSFplus
###             aWarpSharp
###
###
###
### supsamp [default: 4]
### -------------------
### Interpolation strength. Recommended 4 for
### encoding, 2 for testing. 1 disables it [1...4]
###
###
### post [default: 4]
### -------------------
### Post processing of the sharpened areas for better blending/integration [1...4]
### 1 = no post
### 2 = a little blurring on the sharp new edges...
### 3 = ...or sharpening everywhere else to make the image consistent.
### 4 = or a mix of both
###
###
### PPstr [default: 1.0]
### -------------------
### Strength of the postprocessing
###
###
### fast [default: true]
### -------------------
### Independent to supsamp, this can give a small speed boost to the function.
###
###
### w,h [default: input size]
### -------------------
### Target resize. Internally a clip super sampling is performed. Due to the function being naturally
### slow, if you had plans to resize afterwards it would be a good idea to do it now in this step.
###
###
### Usage:
###
###      MCaWarpSharp4(4,4)
###
###
########################################################################


function MCaWarpSharp4(clip source, int "supsamp",int "post", float "PPstr", bool "fast", int "w", int "h"){

    source
    w1  = width()
    h1  = height()
    def = Defined(w) || Defined(h)

    supsamp = Default(supsamp, 4)   # supsamp=2 recommended for testing, supsamp=4 for encoding.
    post    = Default(post, 4)      # mix the warpsharped edges with original footage thru blur and sharpen post processing
    str     = Default(PPstr,1.0)    # post processing strength of whatever option you chose
    fast    = Default(fast,true)    # enables fast mode, which gives some boost.
    w       = Default(w,w1)         # I exposed the size parameters because internally a resize is performed, \
    h       = Default(h,h1)         # so if you had a plan on resizing, this is a good chance to do.


    Assert((post >= 1 && post <= 4 ), chr(10) + "MCaWarpSharp4: 'post' have not a correct value! [1,2,3,4]" + chr(10))
    # if no supersampling (supsamp=1) -> (thresh=255,blur=3,type=1,depth=8,chroma=4)
    # if 4x supersampling (supsamp=4) -> (thresh=192,blur=36,type=1,depth=96,chroma=4)


    var  = -0.06875*pow(supsamp,2)+0.925*supsamp-0.15625  # Parametrized to original
    taps = fast ? 3 : 4
    w1   = w1*supsamp
    h1   = h1*supsamp


    sourceSup=LanczosResize(w1,h1,taps=taps)

    WarpedEdges = sourceSup.aWarpSharp2(
    \ thresh =           int(pow(supsamp,-0.207)*255),
    \ blur   = 3*        int(pow(supsamp,1.7925)),
    \ type   = 1,depth=8*int(pow(supsamp,1.7925)),chroma=4)

    # Getting back to the original shapes with motion compensation to have good and undeformed edges, although still cartoonish look
    Interleave(sourceSup, WarpedEdges)

    super           = MSuper  (ex_blur(var,mode="gaussian"), levels=1, pel=fast?1:2, sharp=fast?0:2)
    super2          = MSuper  (                              levels=1, pel=fast?1:2, sharp=fast?0:2)
    forward_vectors = MAnalyse(super, blksize=4,             levels=1, search=3, searchparam=5, isb=true)
                      MFlow   (super2,forward_vectors)

    SelectEven()
    LanczosResize(w, h, taps=taps)

    # Replacing 'bad' edges with 'good' edges on the original image
    source = def ? source.LanczosResize(w, h, taps=taps) : source
    edgmsk = source.ex_edge("min/max",7,13).BicubicResize (nmod(w/2.,2), nmod(h/2.,2), 1, 0).TemporalSoften(5,30,0,15,2).BicubicResize(w, h, 1, 0)
    ntrl   = last
    blr    = ex_blur(str*0.5)
    shrp   = LSFplus(source, preset=fast?"fast":"mid", strength=int(str*20), edgemode=post==4?2:0, soothe=true)

    post   = (post==1) ? ex_merge(source, ntrl, edgmsk, luma=true)
        \  : (post==2) ? ex_merge(source, blr,  edgmsk, luma=true)
        \  : (post==3) ? ex_merge(shrp,   ntrl, edgmsk, luma=true)
        \  : (post==4) ? ex_merge(shrp,   blr,  edgmsk, luma=true)
        \  :  BlankClip(source, width=width(), height=120).SubTitle("post = " + string(post), text_color=$FFFFFF,font="COURIER NEW",size=12,x=320,y=90)

    return post}