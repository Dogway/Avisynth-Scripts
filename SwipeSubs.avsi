# SwipeSubs 1.0 by Dogway (05/01/2015)
#
# Displays the subtitles from left to right
#

# start: Frame for subs start
# fadeLenght: Range of frames to perform the fade
# SubLength: Length in frames for displaying subs
# h: Whether you want local fade or absolute resolution fade (mask)
# shadow: shadowed subs or not.
# color: set the color, format is: $TTRRGGBB
function ShowText(clip c, int "start", int "end", int "fadeLenght", string "text", string "font", int "x", int "y", bool "h", int "size", int "color", bool "shadow", bool "anim") {
start       = default( start,  0 )
end         = default( end,    15 )
fadeLenght  = default( fadeLenght,  100 )
text        = default( text,  "hola" )
font        = default( font,  "Verdana" )
x           = default( x,    15 )
y           = default( y,    15 )
h           = default( h,  false )
size        = default( size,    14 )
color       = default( color,  $00FFFFFF )
shadow      = default( shadow,   true )
anim        = default( anim,   true )

anim ? \
animate(c, start,start+fadeLenght,"ShowTextInter", text, font, x, y, start+end, size, color, h, 0.0, shadow, text, font, x, y, start+SubLength, size, color, h, 2.0, shadow) : \
ShowTextInter(c, text, font, x, y, start+end, size, color, h, 0.0, shadow)
}

# Helper function for ShowText()

function ShowTextInter(clip c, string text, string font, int x, int y, int end, int size, int color, bool h, float anim, bool shadow) {

x       = default( x,    15 )
y       = default( y,    15 )
anim    = default( anim,  0.0 )
text    = default( text,  "hola" )


mask = h ? mt_lutspa( c, mode = "relative", expr = "x 256 *", chroma = "128" ) : \
           mt_lutspa( c, mode = "relative", expr = "x "+string(anim)+" y - < 255 0 ?", chroma = "128" )
mask = mask.removegrain(20)

#LineSeparation=0
#subs=subtitle(c,text,font="Verdana",lsp=LineSeparation,size=size,text_color=$ffffff,align=7,x=x,y=y,last_frame=end)
shadow ? \
SubtitleEx(            c,text,x=x+2,y=y+2,firstframe=0, lastframe=end,font=font,effects="bsss,f(30,30)", size = size, textcolor = $20000000, halocolor = $60000000) : nop()
SubtitleEx(shadow?last:c,text,x=x,y=y,    firstframe=0, lastframe=end,font=font,effects="b,f(30,30)"   , size = size, textcolor = color    , halocolor = $FF000000)

mt_merge(c,last,mask,true) }
