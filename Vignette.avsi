# by Dogway 26/04/2019

function Vignette(clip c, float "Vignette", bool "show") {

strength = string(Default(Vignette, 0.7))
show = Default(show, false)

a=expr( c, " sx width 2 /  - abs width 2 / / range_max * 1.5 "+strength+" 2 / + ^ range_max / 0 max ", "","", scale_inputs = "none" )
b=expr( c, " sy height 2 / - abs width 2 / / range_max * 1.5 "+strength+" 2 / + ^ range_max / 0 max ", "","", scale_inputs = "none" )

msk=expr(a,b,"x y + range_max - abs", "range_half","range_half", scale_inputs = "none" )

# this is multiply blend mode
show ? msk : expr(msk,c,"x y * range_max / ", "y", "y", scale_inputs = "none" )

}