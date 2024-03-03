package Promise::ES6::AnyEvent;

use strict;
use warnings;

use parent qw(Promise::ES6::EventLoopBase);

=encoding utf-8

=head1 NAME

Promise::ES6::AnyEvent - L<Promises/A+-compliant|https://github.com/promises-aplus/promises-spec> promises

=head1 DEPRECATION NOTICE

This module is deprecated and will go away eventually.
Use C<use_event()> instead, as described in L<Promise::ES6>’s documentation.

=head1 DESCRIPTION

This subclass of L<Promise::ES6> incorporates L<AnyEvent> in order to
implement full Promises/A+ compliance. Specifically, this class defers
execution of resolve and reject callbacks to the end of the current event
loop iteration.

=head1 SEE ALSO

This distribution includes L<Promise::ES6::IOAsync> for those who
prefer L<IO::Async>.

CPAN’s L<Promises>, L<AnyEvent::Promises>, and L<AnyEvent::XSPromises>
all provide functionality similar to this class’s.

=cut

#----------------------------------------------------------------------

use AnyEvent ();

#----------------------------------------------------------------------

sub _postpone {

    # postpone()’s prototype needlessly rejects a plain scalar.
    return &AnyEvent::postpone( $_[1] );
}

1;
