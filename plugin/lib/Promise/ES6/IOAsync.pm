package Promise::ES6::IOAsync;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Promise::ES6::IOAsync - L<Promises/A+-compliant|https://github.com/promises-aplus/promises-spec> promises for L<IO::Async>

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    my $loop_guard = Promise::ES6::IOAsync::SET_LOOP($loop);

    # Now use Promise::ES6::IOAsync as you would plain Promise::ES6.

=head1 DEPRECATION NOTICE

This module is deprecated and will go away eventually.
Use C<use_event()> instead, as described in L<Promise::ES6>’s documentation.

=head1 DESCRIPTION

This module exposes the same functionality as L<Promise::ES6::AnyEvent>
but for L<IO::Async> rather than L<AnyEvent>.

Whereas L<AnyEvent> assumes that an event loop is global, L<IO::Async>
allows multiple concurrent event loops. In order to accommodate this
difference in architecture, this module requires an active L<IO::Async::Loop>
object before it can be used. See C<SET_LOOP()> below.

=cut

#----------------------------------------------------------------------

use parent qw(Promise::ES6::EventLoopBase);

#----------------------------------------------------------------------

my $LOOP;

=head1 FUNCTIONS

=head2 $guard = SET_LOOP( $LOOP )

Sets this module’s active L<IO::Async::Loop> object. This is a internal
global; if you try to set a loop while one is already set, an exception
is thrown.

This returns an opaque object that, when DESTROY()ed, will clear this
module’s internal loop.

=cut

sub SET_LOOP {
    die "Loop is already set!" if $LOOP;

    if (!defined wantarray) {
        my $fn = (caller 0)[3];
        die "Void context to $fn() is useless!";
    }

    $LOOP = $_[0];

    return bless [ \$LOOP ], 'Promise::ES6::IOAsync::_GUARD';
}

sub _postpone {
    die "Need active loop … did you call SET_LOOP() first?" if !$LOOP;

    return $LOOP->later( $_[1] );
}

#----------------------------------------------------------------------

package Promise::ES6::IOAsync::_GUARD;

sub DESTROY {
    ${ $_[0][0] } = undef;
}

1;
