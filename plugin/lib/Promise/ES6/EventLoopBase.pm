package Promise::ES6::EventLoopBase;

use strict;
use warnings;

use parent qw(Promise::ES6);

sub new {
    my ($class, $cr) = @_;

    return $class->SUPER::new( sub {
        my ($res, $rej) = @_;

        local $@;

        my $rej_pp = $class->_create_postpone_cb($rej);

        my $ok = eval {
            $cr->(
                $class->_create_postpone_cb($res),
                $rej_pp,
            );

            1;
        };

        if (!$ok) {
            $rej_pp->( my $err = $@ );
        }
    } );
}

sub _create_postpone_cb {
    my ($class, $cr) = @_;

    return sub {
        my ($arg) = @_;
        $class->_postpone( sub { $cr->($arg) } );
    },
}

sub then {
    my ($self, $on_res, $on_rej) = @_;

    my $class = ref $self;

    return $class->new( sub {
        my ($y, $n) = @_;

        $class->_postpone( sub {
            $self->SUPER::then($on_res, $on_rej)->SUPER::then($y, $n);
        } );
    } );
}

sub finally {
    my ($self, $on_finish) = @_;

    my $class = ref $self;

    return $class->new( sub {
        my ($y, $n) = @_;

        $class->_postpone( sub {
            $self->SUPER::finally($on_finish)->SUPER::then($y, $n);
        } );
    } );
}

1;
