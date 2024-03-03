package Promise::ES6::Event::IOAsync;

use strict;
use warnings;

#----------------------------------------------------------------------

use Scalar::Util ();

#----------------------------------------------------------------------

our $_WEAK_LOOP;

sub __postpone {
    $_WEAK_LOOP ? $_WEAK_LOOP->later( $_[0] ) : die 'IO::Async::Loop object is gone!';
}

sub get_postpone {
    my $loop = shift or die 'Need IO::Async::Loop instance!';

    Scalar::Util::weaken( $_WEAK_LOOP = $loop );

    return \&__postpone;
}

1;

