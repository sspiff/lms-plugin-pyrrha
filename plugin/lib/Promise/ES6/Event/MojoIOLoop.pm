package Promise::ES6::Event::MojoIOLoop;

use strict;
use warnings;

#----------------------------------------------------------------------

use Mojo::IOLoop ();

BEGIN {
    if (!Mojo::IOLoop->can('next_tick')) {
        die( __PACKAGE__ . " requires Mojo::IOLoop::next_tick(). Upgrade to a newer Mojolicious version.$/" );
    }
}

#----------------------------------------------------------------------

sub __postpone {
    Mojo::IOLoop->next_tick($_[0]);
}

use constant get_postpone => \&__postpone;

1;
