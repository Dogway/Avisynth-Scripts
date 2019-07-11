###
###
###  MCaWarpSharp3()
###                 :fix halo, chroma bleeding & blurry edges (Sharpener/line enhacer)
###
###  (24-11-2011)
###
### By z. ndmn.(zee944) with Didée guidance.
### Optimized by Dogway
### http://forum.doom9.org/showthread.php?t=159248
###
### line enhacer: define (sharpen) blurry edges, or remove ringing.
###
### dependencies: MVTools2, masktools, aWarpSharp[20090619]
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
###      MCaWarpSharp3(4,4)
###
###
########################################################################


function MCaWarpSharp3(clip source, int "supsamp",int "post", float "PPstr", bool "fast", int "w", int "h"){

w1=source.width()
h1=source.height()

supsamp = default(supsamp, 4)	# supsamp=2 recommended for testing, supsamp=4 for encoding.
post    = default(post, 4)      # mix the warpsharped edges with original footage thru blur and sharpen post processing
str     = default(PPstr,1.0)    # post processing strength of whatever option you chose
fast    = default(fast,true)    # enables fast mode, which gives some boost.
w       = default(w,w1)         # I exposed the size parameters because internally a resize is performed, \
h       = default(h,h1)         # so if you had a plan on resizing, this is a good chance to do.


# if no supersampling (supsamp=1) -> (thresh=255,blur=3,type=1,depth=8,chroma=4)
# if 4x supersampling (supsamp=4) -> (thresh=192,blur=36,type=1,depth=96,chroma=4)


var=32*pow(supsamp,-2)
w1=w1*supsamp
h1=h1*supsamp

source
sourceSup=LanczosResize(w1,h1,taps=fast?3:4)

WarpedEdges=sourceSup.aWarpSharp2(
\ thresh =           int(pow(supsamp,-0.207)*255),
\ blur   = 3*        int(pow(supsamp,1.7925)),
\ type   = 1,depth=8*int(pow(supsamp,1.7925)),chroma=4)

# Getting back to the original shapes with motion compensation to have good and undeformed edges, although still cartoonish look
Interleave(sourceSup,WarpedEdges)

blurredclip=GaussResize(w1*2,h1*2,p=var).GaussResize(w1,h1,p=var)

super           = MSuper  (blurredclip,      levels=1, pel=fast?1:2, sharp=fast?0:2)
super2          = MSuper  (                  levels=1, pel=fast?1:2, sharp=fast?0:2)
forward_vectors = MAnalyse(super, blksize=4, levels=1, search=3, searchparam=5, isb=true)
MFlow(super2,forward_vectors)

SelectEvery(2,0)
LanczosResize(w,h,taps=fast?3:4)

# Replacing 'bad' edges with 'good' edges on the original image
w4=w/2
h4=h/2
source    = Defined(w) || Defined(h) ? source.LanczosResize(w,h,taps=fast?3:4) : source
edgemask  = source.mt_edge("min/max",U=-128,V=-128).BicubicResize (w4%2+w4,h4%2+h4, 1, 0).TemporalSoften(5,30,0,15,2).BicubicResize (w,h, 1, 0)

Assert  ((post >= 1 && post <= 4 )  ? true : false, chr(10) + "'post' have not a correct value! [1,2,3,4]" + chr(10))
post =   (post==1) ? mt_merge(source,last,edgemask,luma=true)
    \  : (post==2) ? mt_merge(source,Blur(min(str*0.5,1.58)),edgemask,luma=true)
    \  : (post==3) ? mt_merge(LSFmod(source,defaults=fast?"fast":"slow",strength=int(str*20),edgemode=0,soothe=true,ss_x=1.0,ss_y=1.0),last,edgemask,luma=true)
    \  : (post==4) ? mt_merge(LSFmod(source,defaults=fast?"fast":"slow",strength=int(str*20),edgemode=2,soothe=true,ss_x=1.0,ss_y=1.0),Blur(min(str*0.5,1.58)),edgemask,luma=true)
    \  :  blankclip(source, width=width, height=120).SubTitle("post = " + string(post),text_color=$FFFFFF,font="COURIER NEW",size=12,x=320,y=90)

return post}