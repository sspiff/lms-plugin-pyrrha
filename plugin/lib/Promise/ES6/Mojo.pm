package Promise::ES6::Mojo;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Promise::ES6::Mojo - L<Promises/A+-compliant|https://github.com/promises-aplus/promises-spec> promises for L<Mojolicious>

=head1 DEPRECATION NOTICE

This module is deprecated and will go away eventually.
Use C<use_event()> instead, as described in L<Promise::ES6>’s documentation.

=head1 DESCRIPTION

This module exposes the same functionality as L<Promise::ES6::AnyEvent>
but for L<Mojo::IOLoop> rather than L<AnyEvent>.

Its interface is almost compatible with the ES6-derived portions of
L<Mojo::Promise>, but note that Mojo::Promise’s C<all()> and
C<race()> methods accept a list of promises rather than an array reference.

B<NOTE:> This module requires Mojolicious version 4.85 or higher.

=cut

#----------------------------------------------------------------------

use parent qw( Promise::ES6::EventLoopBase );

use Mojo::IOLoop ();

BEGIN {
    if (!Mojo::IOLoop->can('next_tick')) {
        die( __PACKAGE__ . " requires Mojo::IOLoop::next_tick(). Upgrade to a newer Mojolicious version.$/" );
    }
}

#----------------------------------------------------------------------

sub _postpone {
    (undef, my $cb) = @_;

    Mojo::IOLoop->next_tick($cb);
}

1;
