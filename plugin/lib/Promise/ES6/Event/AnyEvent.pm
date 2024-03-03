package Promise::ES6::Event::AnyEvent;

use strict;
use warnings;

#----------------------------------------------------------------------

use AnyEvent ();

#----------------------------------------------------------------------

use constant get_postpone => \&AnyEvent::postpone;

1;
