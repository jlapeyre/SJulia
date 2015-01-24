arithrules =
  [
   @rule( 1 * _ => _ ),
   @rule( _ * 1 => _ ),
   @rule( _ * 0 => 0 ),
   @rule( 0 * _ => 0 ),
   @rule( x_ / 1 => x_ ),
   @rule( (x_ * y_) / y_ => x_ ),   
   @rule(  x_^0 => 1),
   @rule(  _  + _ => 2 * _),
   @rule(  x_  + n_ * x_ => (n_+1) * x_),
   @rule(  n_ * x_ + x_ => (n_+1) * x_),
   @rule(  n_::Number  * (m_::Number * x_) => (n_*m_) * x_),
   @rule( n_::Number * x_ - m_::Number * x_ => (n_-m_) * x_),
   @rule(  +(x_,x_,x_) => 3 * x_),
   @rule(  x_ - x_  => 0),
   @rule(  0 + x_  => x_),
   @rule(  1/(1/x_) => x_),
   @rule(  x_ / x_ => 1),
   @rule(  x_ + -x_  => 0),
   @rule(  x_^n1_ * x_^n2_ => x_^(n1_+n2_)),
   @rule(  x_  * x_^n_ => x_^(1+n_)),
   @rule(  Log(x_^n_) => n_ * Log(x_)),
   @rule(  Log(x_ * y_) => Log(x_) + Log(y_)),
   @rule(  Log(Exp(x_)) => x_),
   @rule(  Log(1) => 0)
 ]