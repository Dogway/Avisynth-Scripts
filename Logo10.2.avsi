###
### Logo 10.2  (http://doom10.org/index.php?topic=2181.0)
###
###  (09-09-2020) By Dogway
###
### Check Readme.txt for:
###                       Reference credits
###                       Dependencies
###                       Todo
###                       Changelog
###
### Usage:
###
###      Logo("C:\MyLogo.png",x=30,y=30,start=200,end=300)
###      Logo("C:\MyAnimatedLogo00%02d.png",30,30,1510,2000,30,30,Opac=0.8,blur=0.2,mode="Screen",chr=true,PAR=0.911)
###
###
########################################################################


function Logo(clip c,string path, int "x", int "y",int "start",int "end",int "I",int "O",float "Opac",
\              string "mode",float "Wstr", bool "Chr", float "blur", bool "matte",float "PAR",bool "anim_gif", int "threads"){

w=c.width()
h=c.height()
Fc=FrameCount(c)-1
fps=Framerate(c)



 path     =string(path)            # Your logo PATH
 x        =default(x, 0)           # Horizontal offset for logo placement from top,left corner
 y        =default(y, 0)           # Vertical offset for logo placement from top,left corner
 start    =default(start, 0)       # Define the start frame for your logo
 end      =default(end, 0)         # Define the end frame for your logo
 I        =default(I, int(fps))    # Length in frames for your logo FadeIn
 O        =default(O, I)           # Length in frames for your logo FadeOut
 Opac     =default(Opac, 1.0)      # Opacity for your logo
 mode     =default(mode,"Over")    # Blending mode, it can be Screen, Multiply, Over and Watermark (using alpha)
 Wstr     =default(Wstr, 1.2)      # Intensity of Watermark, over 1.0 for bright, and below for dark watermaks
 Ch       =default(Chr,  false)    # Enables displaying chroma in Screen and Multiply mode, it is just copied not processed
 Sblur    =default(blur, 0.0)      # Post-blur your logo for better integration
 mat      =default(matte,false)    # Matte carving for better masking at edges of images with alpha
 PAR      =default(PAR,1.0)        # Indicate the PAR of your source, if anamorphic output, so logo will show correct at display
 gif      =default(anim_gif,false) # Is your logo a packed animated gif?
 mt       = Defined(threads)       ? true : false  # By default it will use all accessible system threads but you can custom input other count

end > 0 ?\
Assert(start <= end,     "Invalid start frame:       " +String(start)) : nop()
Assert(start <=  Fc,     "Start frame out of bounds: " +String(start))
Assert(start >=   0,     "Start frame out of bounds: " +String(start))
Assert(end  <  Fc+1,     "End frame out of bounds:   " +String(end))
Assert(end  >=   -1,     "End frame out of bounds:   " +String(end))
Assert(c.isyv12() == true, "Input is not yv12")
end2 = end == 0 || end == Fc-1 ? Fc : end


logo0 = gif ? ImmaRead(path,start=start,end= end == -1 ? start : end2,animation=true)
\           : ImageSource(path,start=start,end= end == -1 ? start : end2,use_Devil=true, pixel_type="RGB32")


logo0 = PAR !=  1.0  ? logo0.spline36resize(round(logo0.width()/par),logo0.height()).mmod2()
\                    : logo0.mmod2()
logo0 = logo0.addborders(x,abs(y),w,h).crop(0,0,-logo0.width()-x,-logo0.height()-abs(y)).blur(min(Sblur/par,1.58),Sblur).blur(min(Sblur/par,1.58),Sblur)

lw = mat ? logo0.width()  : nop()
lh = mat ? logo0.height() : nop()
msk   = mat ? ShowAlpha(logo0.FadeIn0(I).FadeOut0(O),"YV12").pointresize(lw*2,lh*2).mt_inpand(mode="both").mt_inpand(mode="both").LanczosResize(lw,lh)
\           : ShowAlpha(logo0.FadeIn0(I).FadeOut0(O),"YV12")
logo0 = logo0.converttoyv12().assumefps(fps)

V         = c.trim(start,end)
screen    ="220 220 x 16 - - 220 y 16 - - * 220 / - "+String(Opac)+" * x 16 - 1 "+String(Opac)+" - * + 16 + "
multiply  ="x 16 - y 16 - * 220 / "+String(Opac)+" * x 16 - 1 "+String(Opac)+" - * + 16 + "
watermark ="x 16 - 220 / 1 "+string(Wstr)+" "+String(Opac)+" ^ / ^ 220 * 16 + "

V =
\ (mode=="Screen")   ? mt_merge(V,mt_lutxy(V,logo0,Y=3, U=ch?4:2, V=ch?4:2,screen)  ,msk,luma=true)
\:(mode=="Multiply") ? mt_merge(V,mt_lutxy(V,logo0,Y=3, U=ch?4:2, V=ch?4:2,multiply),msk,luma=true)
\:(mode=="Over")     ? mt_merge(V,logo0,mt_lut(msk," x "+String(Opac)+" * ")            ,luma=true)
\:(mode=="Watermark")? mt_merge(V,mt_lut(V,watermark)                               ,msk,luma=true)
\:Assert(false, "Unsupported Blending Mode: "+string(mode))

start == 0 && (end == 0 || end == Fc) ? V :
\ (start>0 ?  (end == 0 || end == Fc || end == -1 && start == Fc ? c.trim(0,start == 1 ? -1 : start-1)+V :
 \ c.trim(0,start == 1 ? -1 : start-1)+V+c.trim(end == -1 ? start+1 : end2+1,0)) :
  \ V+c.trim(end == -1 ? start+1 : end2+1,0))}


function mmod2(clip c){
bh = 2 - ((c.Width()-1)%2 + 1)
bv = 2 - ((c.Height()-1)%2 + 1)
c.crop(bh/2,bv/2,-bh,-bv)}