# Vinverse: a small, but effective Function against (residual) combing, by Didée
#           Ported to EX mod from real.finder's HBD mod. by Dogway (18-06-2021)
# HBD update and adding custem clip
# sstr: strength of contra sharpening
# amnt: change no pixel by more than this (Default=255: unrestricted)
# UV  : chroma mode, as in MaskTools: 1=trash chroma, 2=pass chroma through, 3=process chroma

function ex_vinverse (clip clp, float "sstr", int "amnt", int "UV", clip "custem") {

    uv   = Default(uv,3)
    dcus = Defined(custem)
    sstr = Default(sstr,2.7)
    amnt = Default(amnt,255)
    uv2  = (uv==2) ? 1 : uv

    vblur  = clp.ex_blur(0, 1, UV=uv)
    vblurD = ex_makediff(clp, vblur, UV=uv2)
    Vshrp  = dcus ? clp : ex_lutxy(vblur, vblur.ex_blur(0, 2, UV=uv2), Format("x x y - {sstr} * +"), UV=uv2)
    VshrpD = ex_makediff(Vshrp, dcus ? custem : vblur, UV=uv2)
    VlimD  = ex_lutxy(VshrpD, VblurD, "x range_half - A@ y range_half - B@ * 0 < A abs B abs < x y ? range_half - 0.25 * range_half + A abs B abs < x y ? ?", UV=uv2)

    ex_adddiff(dcus ? custem : Vblur, VlimD, UV=uv)

    (amnt>254) ? last : \
    (amnt==0)  ? clp  : \
    ex_lutxy(clp, last, Format("x {amnt} yscalef + y < x {amnt} yscalef + x {amnt} yscalef - y > x {amnt} yscalef - y ? ?"), UV=uv) }