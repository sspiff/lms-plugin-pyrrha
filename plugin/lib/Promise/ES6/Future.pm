package Promise::ES6::Future;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Promise::ES6::Future - Translation to/from L<Future>

=head1 DESCRIPTION

This module provides logic to convert between
promises and L<Future> instances.

=head1 FUNCTIONS

=head1 $promise = from_future( $FUTURE )

Returns a L<Promise:ES6> instance from the given $FUTURE.
(If $FUTURE is not a L<Future> instance, $FUTURE is returned.)

=cut

sub from_future {
    my ($whatsit) = @_;

    return $whatsit if !$whatsit->isa('Future');

    local ($@, $!);
    require Promise::ES6;

    return Promise::ES6->new( sub { () = $whatsit->then(@_) } );
}

=head1 $future = to_future( $PROMISE )

Returns a L<Future> instance from the given $PROMISE.
(If $PROMISE is a Future instance, $PROMISE is returned.)

Note that this function can work with promise objects that aren’t
L<Promise::ES6> instances. In fact, anything that I<isn’t> a Future
instance will cause this function to create a new Future.

=cut

sub to_future {
    my ($whatsit) = @_;

    return $whatsit if $whatsit->isa('Future');

    local ($@, $!);
    require Future;

    my $future = Future->new();

    $whatsit->then(
        sub {
            $future->done( $_[0] );
        },
        sub { $future->fail( $_[0] ) },
    );

    return $future;
}

1;
