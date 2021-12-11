# SwipeSubs 2.2 by Dogway (11/12/2021)
#
# Display the subtitles from left to right
#

# start: Frame for subs start
# end: Frame for subs end
# fadeLenght: Range of frames to perform the fade
# h: Whether you want local fade or absolute resolution fade (mask)
# shadow: shadowed subs or not.
# color: set the color, format is: $TTRRGGBB
function ShowText(clip c, int "start", int "end", int "fadeLenght", string "text", string "font", int "x", int "y", bool "h", int "size", int "color", bool "shadow", bool "anim") {

    start       = Default( start,         0 )
    end         = Default( end,          15 )
    fadeLenght  = Default( fadeLenght,  100 )
    text        = Default( text,     "hola" )
    font        = Default( font,  "Verdana" )
    x           = Default( x,       15 )
    y           = Default( y,       15 )
    h           = Default( h,    false )
    size        = Default( size,    14 )
    color       = Default( color,  $00FFFFFF )
    shadow      = Default( shadow, true )
    anim        = Default( anim,   true )

    anim ? \
    animate(c, start,start+fadeLenght,"ShowTextInter", text, font, x, y, start+end, size, color, h, 0.0, shadow, text, font, x, y, start+SubLength, size, color, h, 2.0, shadow) : \
    ShowTextInter(c, text, font, x, y, start+end, size, color, h, 0.0, shadow) }



# Helper function for ShowText()

function ShowTextInter(clip c, string text, string font, int x, int y, int end, int size, int color, bool h, float anim, bool shadow) {

    x       = Default( x,    15 )
    y       = Default( y,    15 )
    anim    = Default( anim,  0.0 )
    text    = Default( text,  "hola" )
    fs      = propNumElements (c,"_ColorRange")  > 0 ? \
              propGetInt      (c,"_ColorRange") == 0 : isRGB(c)


    msk = h ? ex_lutspa( c, mode = "relative", expr = "x range_size *", UV=128)                                : \
              ex_lutspa( c, mode = "relative", expr = "x "+string(anim)+" y - < range_max range_min ?", UV=128 )
    msk = msk.removegrain(12)

    #LineSeparation=0
    #subs=subtitle(c,text,font="Verdana",lsp=LineSeparation,size=size,text_color=$ffffff,align=7,x=x,y=y,last_frame=end)
    shadow ? \
    SubtitleEx(            c,text,x=x+2,y=y+2,firstframe=0, lastframe=end,font=font,effects="bsss,f(30,30)", size = size, textcolor = $20000000, halocolor = $60000000) : nop()
    SubtitleEx(shadow?last:c,text,x=x,y=y,    firstframe=0, lastframe=end,font=font,effects="b,f(30,30)"   , size = size, textcolor = color    , halocolor = $FF000000)

    mt_merge(c,last,mask) }
