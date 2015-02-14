# We just put this here because there was some problem with load order.

unprotect(:ExpToTrig)

@ex ( ExpToTrig(ex_) := ReplaceRepeated( ex , E^(x_) => Cosh(x) + Sinh(x)) )

protect(:ExpToTrig)

@sjdoc ExpToTrig "
ExpToTrig(expr) replaces exponentials with trigonometric functions in expr.
But, the transformation from Cosh to Cos is not implemented.
"

# No numerical yet.
unprotect(:Log)
@ex Log(1) := 0
protect(:Log)

@sjdoc Log "
Log(x) gives the natural logarithm of x.
"
