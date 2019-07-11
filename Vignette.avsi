# by Dogway 25/04/2019

function Vignette(clip c, float "Vignette") {

strength = string(default(Vignette, 0.7))

w=string(width(c))
h=string(height(c))

a=mt_lutspa( c, mode = "absolute", expr = " x "+w+" 2 / - abs "+w+" 2 / / 255 * 1.5 "+strength+" 2 / + ^ 255 / 0 max", chroma = "-128" )
b=mt_lutspa( c, mode = "absolute", expr = " y "+h+" 2 / - abs "+w+" 2 / / 255 * 1.5 "+strength+" 2 / + ^ 255 / 0 max", chroma = "-128" )

c=mt_lutxy(a,b,"x y + 255 - abs")
c

}



function Vignette2(clip c, float "Vignette", bool "show") {

strength = string(Default(Vignette, 0.7))
show = Default(show, false)

a=expr( c, " sx width 2 /  - abs width 2 / / 255 * 1.5 "+strength+" 2 / + ^ 255 / 0 max", "","", scale_inputs = "allf" )
b=expr( c, " sy height 2 / - abs width 2 / / 255 * 1.5 "+strength+" 2 / + ^ 255 / 0 max", "","", scale_inputs = "allf" )

msk=expr(a,b,"x y + 255 - abs", "128","128", scale_inputs = "allf" )
msktv=msk.expr("x 128 - 224 * 255 / 128 +", scale_inputs = "allf" )

show ? msk : expr(msktv,c,"x 16 - y 16 - * 220 / 1 * x 16 - 1 1 - * + 16 + ", "y", "y", scale_inputs = "all" )

}