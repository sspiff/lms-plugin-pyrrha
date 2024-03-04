package Promise::ES6::Event::SlimServer;

use strict;
use warnings;


#----------------------------------------------------------------------

sub __postpone {
    Slim::Utils::Timers::setTimer(undef, Time::HiRes::time(), $_[0]);
}

sub get_postpone {
    return \&__postpone;
}

1;

