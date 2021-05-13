###
### Logo 11.0  (http://doom10.org/index.php?topic=2181.0)
###
###  (13-05-2021) By Dogway
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


function Logo (clip c,string path, int "x", int "y",int "start",int "end",int "I",int "O",float "Opac",
\              string "mode",float "Wstr", bool "Chr", float "blur", bool "matte",float "PAR",bool "anim_gif"){

w  = c.Width()
h  = c.Height()
Fc = FrameCount(c)-1
fps= Framerate(c)



 path     = String(path)            # Your logo PATH
 x        = Default(x, 0)           # Horizontal offset for logo placement from top,left corner
 y        = Default(y, 0)           # Vertical offset for logo placement from top,left corner
 start    = Default(start, 0)       # Define the start frame for your logo
 end      = Default(end, 0)         # Define the end frame for your logo
 I        = Default(I, int(fps))    # Length in frames for your logo FadeIn
 O        = Default(O, I)           # Length in frames for your logo FadeOut
 Opac     = Default(Opac, 1.0)      # Opacity for your logo
 mode     = Default(mode,"Over")    # Blending mode, it can be Screen, Multiply, Over and Watermark (using alpha)
 Wstr     = Default(Wstr, 1.2)      # Intensity of Watermark, over 1.0 for bright, and below for dark watermaks
 Ch       = Default(Chr,  false)    # Enables displaying chroma in Screen and Multiply mode, it is just copied not processed
 Sblur    = Default(blur, 0.0)      # Post-blur your logo for better integration
 mat      = Default(matte,false)    # Matte carving for better masking at edges of images with alpha
 PAR      = Default(PAR,1.0)        # Indicate the PAR of your source, if anamorphic output, so logo will show correct at display
 gif      = Default(anim_gif,false) # Is your logo a packed animated gif?

end > 0 ?\
Assert(start <= end,     "Invalid start frame:       " +String(start)) : nop()
Assert(start <=  Fc,     "Start frame out of bounds: " +String(start))
Assert(start >=   0,     "Start frame out of bounds: " +String(start))
Assert(end  <  Fc+1,     "End frame out of bounds:   " +String(end))
Assert(end  >=   -1,     "End frame out of bounds:   " +String(end))
Assert(c.Is420() == true, "Input is not yv12")
end2 = end == 0 || end == Fc-1 ? Fc : end


logo0 = gif ? ImmaRead(   path,start=start,end= end == -1 ? start : end2,animation=true)
\           : ImageSource(path,start=start,end= end == -1 ? start : end2,use_Devil=true, pixel_type="RGB32")


logo0 = PAR !=  1.0  ? logo0.BicubicResize(round(logo0.Width()/par),logo0.Height(),0.0,0.75).mmod2()
\                    : logo0.mmod2()
logo0 = logo0.addborders(x,abs(y),w,h).crop(0,0,-logo0.Width()-x,-logo0.Height()-abs(y),align=true).Blur(min(Sblur/par,1.58),Sblur).Blur(min(Sblur/par,1.58),Sblur)

lw = mat ? logo0.Width()  : nop()
lh = mat ? logo0.Height() : nop()

# Port mt_inpand() to Expr() syntax
msk   = mat ? ExtractA(logo0.FadeIn0(I).FadeOut0(O)).PointResize(lw*2,lh*2).mt_inpand(mode="both").mt_inpand(mode="both").BicubicResize(lw,lh,-0.5,0.25).MatchColorFormat(c)
\           : ExtractA(logo0.FadeIn0(I).FadeOut0(O)).MatchColorFormat(c)
logo0 = logo0.MatchColorFormat(c).assumefps(fps)

V         = c.trim(start,end)
screen    = Format("ymax ymin - A@ A x ymin - - A y ymin - - * A / - {Opac} * x ymin - 1 {Opac} - * + ymin + ")
multiply  = Format("x ymin - y ymin - * ymax ymin - / {Opac} * x ymin - 1 {Opac} - * + ymin + ")
watermark = Format("ymax ymin - A^ x ymin - A / 1 {Wstr} {Opac} ^ / ^ A * ymin + ")

V =
\ (mode=="Screen")   ? Expr(V,Expr(V,logo0,screen  ,ch?"y":"x")     ,msk,"x range_max z - * y z * + range_size /")
\:(mode=="Multiply") ? Expr(V,Expr(V,logo0,multiply,ch?"y":"x")     ,msk,"x range_max z - * y z * + range_size /")
\:(mode=="Over")     ? Expr(V,logo0,Expr(msk,Format(" x {Opac} * ")),    "x range_max z - * y z * + range_size /")
\:(mode=="Watermark")? Expr(V,Expr(V,watermark)                     ,msk,"x range_max z - * y z * + range_size /")
\:Assert(false, "Unsupported Blending Mode: "+string(mode))

start == 0 && (end == 0 || end == Fc) ? V :
\ (start>0 ?  (end == 0 || end == Fc || end == -1 && start == Fc ? c.trim(0,start == 1 ? -1 : start-1)+V :
 \ c.trim(0,start == 1 ? -1 : start-1)+V+c.trim(end == -1 ? start+1 : end2+1,0)) :
  \ V+c.trim(end == -1 ? start+1 : end2+1,0))}


function mmod2(clip c){
bh = 2 - ((c.Width()-1)%2 + 1)
bv = 2 - ((c.Height()-1)%2 + 1)
c.crop(bh/2,bv/2,-bh,-bv,align=true)}
