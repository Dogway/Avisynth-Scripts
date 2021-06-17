# Vinverse: a small, but effective Function against (residual) combing, by Didée
# 			Ported to EX mod from real.finder's HBD mod. by Dogway (17-06-2021)
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
    STR  = string(sstr)
    AMN  = string(amnt)

    vblur  = clp.ex_blur(0, 1, UV=uv)
    vblurD = ex_makediff(clp, vblur, UV=uv2, dif=false)
    Vshrp  = dcus ? clp : ex_lutxy(vblur, vblur.ex_blur(0, 2, UV=uv2), "x x y - "+STR+" * +", UV=uv2)
    VshrpD = ex_makediff(Vshrp, dcus ? custem : vblur, UV=uv2, dif=false)
    VlimD  = ex_lutxy(VshrpD, VblurD, "x y * 0 < x abs y abs < x y ? 0.25 * range_half + x abs y abs < x y ? ?", UV=uv2)

    ex_adddiff(dcus ? custem : Vblur, VlimD, UV=uv, dif=false)

    (amnt>254) ? last : \
    (amnt==0)  ? clp  : \
    ex_lutxy(clp, last, "x "+AMN+" yscalef + y < x "+AMN+" yscalef + x "+AMN+" yscalef - y > x "+AMN+" yscalef - y ? ?", UV=uv) }