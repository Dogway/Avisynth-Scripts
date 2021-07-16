# SPresso by Didée, r.f mod in 2020.05.07 for HBD
#                Dogway mod in 2021.07.16 for optimization+cleanup
function SPresso(clip clp, float "limit", float "bias", int "RGmode", float "limitC", float "biasC", int "RGmodeC", bool "HD", int "radius", bool "fulls") {

    rgb = isRGB(clp)
    bi  = BitsPerComponent(clp)
    h   = clp.height()

    limit   = Default( limit,   2 )
    limitC  = Default( limitC,  4 )
    bias    = Default( bias,   25 )
    biasC   = Default( biasC,  50 )
    RGmode  = Default( RGmode,  4 )
    RGmodeC = Default( RGmodeC, 0 )
    HD      = Default( HD,  h > 720 )
    radius  = Default( radius,  round(h/540.0) )
    fs      = Default( fulls, rgb )

    yy = (RGmode ==0) ? 2 : 3
    uv = (RGmodeC==0) ? 2 : 3
    LIM1  = ex_bs(limit>0 ? round(limit*100.0/bias-1.0) : round(100.0/bias), bi, fs)
    LIM2  = ex_bs(limit<0 ? 1 : limit, bi, fs)
    BIA   = ex_bs(bias, bi, fs)
    LIM1c = ex_bs(limitC>0 ? round(limitC*100.0/biasC-1.0) : round(100.0/biasC), bi, fs)
    LIM2c = ex_bs(limitC<0 ? 1 : limitC, bi, fs)
    BIAc  = ex_bs(biasc, bi, fs)
    CTH   = ex_bs(100, bi, fs)

    expr  = Format(limit<0 ? "x y - A@ abs B@ {LIM1} < x dup 1 A B / * - ?"                                                          : \
                             "x y - abs 0 <= x dup {LIM1} + y < x {LIM2} + x {LIM1} - y > x {LIM2} - x {CTH} {BIA} - * y {BIA} * + 1 {CTH} / * ? ? ?" )

    exprC = Format(limit<0 ? "x y - A@ abs B@ {LIM1c} < x dup 1 A B / * - ?"                                                         : \
                             "x y - abs 0 <= x dup {LIM1c} + y < x {LIM2c} + x {LIM1c} - y > x {LIM2c} - x {CTH} {BIAc} - * y {BIAc} * + 1 {CTH} / * ? ? ?" )


    ex_lutxy( clp, HD ? clp.ex_MinBlur(radius,uv=uv) : clp.removegrain(RGmode,RGmodeC), expr, exprC, scale_inputs=limit<0 ? "floatf" : "none", Y=yy, UV=uv, fulls=fs)

}