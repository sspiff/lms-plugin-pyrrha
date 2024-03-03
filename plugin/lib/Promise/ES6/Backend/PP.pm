package Promise::ES6;

#----------------------------------------------------------------------
# This module iS NOT a defined interface. Nothing to see here …
#----------------------------------------------------------------------

use strict;
use warnings;

use Carp ();

use constant {

    # These aren’t actually defined.
    _RESOLUTION_CLASS => 'Promise::ES6::_RESOLUTION',
    _REJECTION_CLASS  => 'Promise::ES6::_REJECTION',
    _PENDING_CLASS    => 'Promise::ES6::_PENDING',

    _DEBUG => 0,
};

use constant {
    _PROMISE_ID_IDX  => 0,
    _PID_IDX         => _DEBUG + 0,
    _CHILDREN_IDX    => _DEBUG + 1,
    _VALUE_SR_IDX    => _DEBUG + 2,
    _DETECT_LEAK_IDX => _DEBUG + 3,
    _ON_RESOLVE_IDX  => _DEBUG + 4,
    _ON_REJECT_IDX   => _DEBUG + 5,
    _IS_FINALLY_IDX  => _DEBUG + 6,

    # For async/await:
    _ON_READY_IMMEDIATE_IDX => _DEBUG + 7,
    _SELF_REF_IDX => _DEBUG + 8,
};

# "$value_sr" => $value_sr
our %_UNHANDLED_REJECTIONS;

my $_debug_promise_id = 0;
sub _create_promise_id { return $_debug_promise_id++ . "-$_[0]" }

sub new {
    my ( $class, $cr ) = @_;

    die 'Need callback!' if !$cr;

    my $value;
    my $value_sr = bless \$value, _PENDING_CLASS();

    my @children;

    my $self = bless [
        ( _DEBUG ? undef : () ),
        $$,
        \@children,
        $value_sr,
        $Promise::ES6::DETECT_MEMORY_LEAKS,
    ], $class;

    $self->[_PROMISE_ID_IDX] = _create_promise_id($self) if _DEBUG;

    # NB: These MUST NOT refer to $self, or else we can get memory leaks
    # depending on how $resolver and $rejector are used.
    my $resolver = sub {
        $$value_sr = $_[0];

        # NB: UNIVERSAL::can() is used in order to avoid an eval {}.
        # It is acknowledged that many Perl experts strongly discourage
        # use of this technique.
        if ( UNIVERSAL::can( $$value_sr, 'then' ) ) {
            return _repromise( $value_sr, \@children, $value_sr );
        }

        bless $value_sr, _RESOLUTION_CLASS();

        $self->[_ON_READY_IMMEDIATE_IDX]->() if $self->[_ON_READY_IMMEDIATE_IDX];

        undef $self->[_SELF_REF_IDX];

        if (@children) {
            $_->_settle($value_sr) for splice @children;
        }
    };

    my $rejecter = sub {
        if (!defined $_[0]) {
            my $msg;

            if (@_) {
                $msg = "$class: Uninitialized rejection value given";
            }
            else {
                $msg = "$class: No rejection value given";
            }

            Carp::carp($msg);
        }

        $$value_sr = $_[0];
        bless $value_sr, _REJECTION_CLASS();

        $_UNHANDLED_REJECTIONS{$value_sr} = $value_sr;

        $self->[_ON_READY_IMMEDIATE_IDX]->() if $self->[_ON_READY_IMMEDIATE_IDX];

        undef $self->[_SELF_REF_IDX];

        # We do not repromise rejections. Whatever is in $$value_sr
        # is literally what rejection callbacks receive.
        if (@children) {
            $_->_settle($value_sr) for splice @children;
        }
    };

    local $@;
    if ( !eval { $cr->( $resolver, $rejecter ); 1 } ) {
        $$value_sr = $@;
        bless $value_sr, _REJECTION_CLASS();

        $_UNHANDLED_REJECTIONS{$value_sr} = $value_sr;
    }

    return $self;
}

sub then {
    return $_[0]->_then_or_finally(@_[1, 2]);
}

sub finally {

    # There’s no reason to call finally() without a callback
    # since it would just be a no-op.
    die 'finally() requires a callback!' if !$_[1];

    return $_[0]->_then_or_finally($_[1], undef, 1);
}

sub _then_or_finally {
    my ($self, $on_resolve_or_finish, $on_reject, $is_finally) = @_;

    my $value_sr = bless( \do { my $v }, _PENDING_CLASS() );

    my $new = bless [
        ( _DEBUG ? undef : () ),
        $$,
        [],
        $value_sr,
        $Promise::ES6::DETECT_MEMORY_LEAKS,
        $on_resolve_or_finish,
        $on_reject,
        $is_finally,
      ],
      ref($self);

    $new->[_PROMISE_ID_IDX] = _create_promise_id($new) if _DEBUG;

    if ( _PENDING_CLASS eq ref $self->[_VALUE_SR_IDX] ) {
        push @{ $self->[_CHILDREN_IDX] }, $new;
    }
    else {

        # $self might already be settled, in which case we immediately
        # settle the $new promise as well.

        $new->_settle( $self->[_VALUE_SR_IDX] );
    }

    return $new;
}

sub _repromise {
    my ( $value_sr, $children_ar, $repromise_value_sr, $orig_finally_sr ) = @_;
    $$repromise_value_sr->then(
        sub {
            if (ref $orig_finally_sr) {
                $$value_sr = $$orig_finally_sr;
            }
            else {
                $$value_sr = $_[0];
            }

            bless $value_sr, _RESOLUTION_CLASS;
            $_->_settle($value_sr) for splice @$children_ar;
        },
        sub {
            $$value_sr = $_[0];
            bless $value_sr, _REJECTION_CLASS;
            $_UNHANDLED_REJECTIONS{$value_sr} = $value_sr;
            $_->_settle($value_sr) for splice @$children_ar;
        },
    );
    return;

}

# It’s gainfully faster to inline this:
#sub _is_completed {
#    return (_PENDING_CLASS ne ref $_[0][ _VALUE_SR_IDX ]);
#}

# This method *only* runs to “settle” a promise.
sub _settle {
    my ( $self, $final_value_sr ) = @_;

    die "$self already settled!" if _PENDING_CLASS ne ref $self->[_VALUE_SR_IDX];

    my $settle_is_rejection = _REJECTION_CLASS eq ref $final_value_sr;

    # This has to happen up-front or else we can get spurious
    # unhandled-rejection warnings in asynchronous mode.
    delete $_UNHANDLED_REJECTIONS{$final_value_sr} if $settle_is_rejection;

    if ($Promise::ES6::_EVENT) {
        _postpone( sub {
            $self->_settle_now($final_value_sr, $settle_is_rejection);
        } );
    }
    else {
        $self->_settle_now($final_value_sr, $settle_is_rejection);
    }
}

sub _settle_now {
    my ( $self, $final_value_sr, $settle_is_rejection ) = @_;

    my $self_is_finally = $self->[_IS_FINALLY_IDX];

    # A promise that new() created won’t have on-settle callbacks,
    # but a promise that came from then/catch/finally will.
    # It’s a good idea to delete the callbacks in order to trigger garbage
    # collection as soon and as reliably as possible. It’s safe to do so
    # because _settle() is only called once.
    my $callback = $self->[ ($settle_is_rejection && !$self_is_finally) ? _ON_REJECT_IDX : _ON_RESOLVE_IDX ];

    @{$self}[ _ON_RESOLVE_IDX, _ON_REJECT_IDX ] = ();

    # In some contexts this function runs quite a lot,
    # so caching the is-promise lookup is useful.
    my $value_sr_contents_is_promise = 1;

    if ($callback) {

        # This is the block that runs for promises that were created by a
        # call to then() that assigned a handler for the state that
        # $final_value_sr indicates (i.e., resolved or rejected).

        my ($new_value, $callback_failed);

        local $@;

        if ( eval { $new_value = $callback->($self_is_finally ? () : $$final_value_sr); 1 } ) {

            # The callback succeeded. If $new_value is not itself a promise,
            # then $self is now resolved. (Yay!) Note that this is true
            # even if $final_value_sr indicates a rejection: in this case, we’ve
            # just run a successful “catch” block, so resolution is correct.

            # If $new_value IS a promise, though, then we have to wait.
            if ( !UNIVERSAL::can( $new_value, 'then' ) ) {
                $value_sr_contents_is_promise = 0;

                if ($self_is_finally) {

                    # finally() is a bit weird. Assuming its callback succeeds,
                    # it takes its parent’s resolution state. It’s important
                    # that we make a *new* reference to the resolution value,
                    # though, rather than merely using $final_value_sr itself,
                    # because we need $self to have its own entry in
                    # %_UNHANDLED_REJECTIONS.
                    ${ $self->[_VALUE_SR_IDX] } = $$final_value_sr;
                    bless $self->[_VALUE_SR_IDX], ref $final_value_sr;

                    $_UNHANDLED_REJECTIONS{ $self->[_VALUE_SR_IDX] } = $self->[_VALUE_SR_IDX] if $settle_is_rejection;
                }
                else {
                    bless $self->[_VALUE_SR_IDX], _RESOLUTION_CLASS;
                }
            }
        }
        else {
            $callback_failed = 1;

            # The callback errored, which means $self is now rejected.

            $new_value                    = $@;
            $value_sr_contents_is_promise = 0;

            bless $self->[_VALUE_SR_IDX], _REJECTION_CLASS();
            $_UNHANDLED_REJECTIONS{ $self->[_VALUE_SR_IDX] } = $self->[_VALUE_SR_IDX];
        }

        if (!$self_is_finally || $value_sr_contents_is_promise || ($self_is_finally && $callback_failed)) {
            ${ $self->[_VALUE_SR_IDX] } = $new_value;
        }
    }
    else {

        # There was no handler from then(), so whatever state $final_value_sr
        # indicates # (i.e., resolution or rejection) is now $self’s state
        # as well.

        # NB: We should NEVER be here if the promise is from finally().

        bless $self->[_VALUE_SR_IDX], ref($final_value_sr);
        ${ $self->[_VALUE_SR_IDX] } = $$final_value_sr;
        $value_sr_contents_is_promise = UNIVERSAL::can( $$final_value_sr, 'then' );

        if ($settle_is_rejection) {
            $_UNHANDLED_REJECTIONS{ $self->[_VALUE_SR_IDX] } = $self->[_VALUE_SR_IDX];
        }
    }

    if ($value_sr_contents_is_promise) {

        # Stash the given concrete value. If the $value_sr promise
        # rejects, then we’ll accept that, but if it resolves, then
        # we’ll look at this to know to discard that resolution.
        if ($self_is_finally) {
            $self->[_IS_FINALLY_IDX] = $final_value_sr;
        }

        return _repromise( @{$self}[ _VALUE_SR_IDX, _CHILDREN_IDX, _VALUE_SR_IDX, _IS_FINALLY_IDX ] );
    }
    elsif ( @{ $self->[_CHILDREN_IDX] } ) {
        $_->_settle( $self->[_VALUE_SR_IDX] ) for splice @{ $self->[_CHILDREN_IDX] };
    }

    $self->[_ON_READY_IMMEDIATE_IDX]->() if $self->[_ON_READY_IMMEDIATE_IDX];

    undef $self->[_SELF_REF_IDX];

    return;
}

sub DESTROY {

    # The PID should always be there, but this accommodates mocks.
    return unless $_[0][_PID_IDX] && $$ == $_[0][_PID_IDX];

    if ( $_[0][_DETECT_LEAK_IDX] && ${^GLOBAL_PHASE} && ${^GLOBAL_PHASE} eq 'DESTRUCT' ) {
        warn( ( '=' x 70 ) . "\n" . 'XXXXXX - ' . ref( $_[0] ) . " survived until global destruction; memory leak likely!\n" . ( "=" x 70 ) . "\n" );
    }

    if ( defined $_[0][_VALUE_SR_IDX] ) {
        my $promise_value_sr = $_[0][_VALUE_SR_IDX];
        if ( my $value_sr = delete $_UNHANDLED_REJECTIONS{$promise_value_sr} ) {
            warn "$_[0]: Unhandled rejection: $$value_sr";
        }
    }
}

#----------------------------------------------------------------------

# Future::AsyncAwait::Awaitable interface:

# Future::AsyncAwait doesn’t retain a strong reference to its created
# promises, as a result of which we need to create a self-reference
# inside the promise. We’ll clear that self-reference once the promise
# is finished, which avoids memory leaks.
#
sub _immortalize {
    my $method = $_[0];

    my $new = $_[1]->$method(@_[2 .. $#_]);

    $new->[_SELF_REF_IDX] = $new;
}

sub AWAIT_NEW_DONE {
    _immortalize('resolve', (ref($_[0]) || $_[0]), $_[1]);
}

sub AWAIT_NEW_FAIL {
    _immortalize('reject', (ref($_[0]) || $_[0]), $_[1]);
}

sub AWAIT_CLONE {
    _immortalize('new', ref($_[0]), \&_noop);
}

sub AWAIT_DONE {
    my $copy = $_[1];

    $_[0]->_settle_now(bless \$copy, _RESOLUTION_CLASS);
}

sub AWAIT_FAIL {
    my $copy = $_[1];

    $_[0]->_settle_now(bless(\$copy, _REJECTION_CLASS), 1);
}

sub AWAIT_IS_READY {
    !UNIVERSAL::isa( $_[0]->[_VALUE_SR_IDX], _PENDING_CLASS );
}

use constant AWAIT_IS_CANCELLED => 0;

sub AWAIT_GET {
    delete $_UNHANDLED_REJECTIONS{$_[0]->[_VALUE_SR_IDX]};

    return ${ $_[0]->[_VALUE_SR_IDX] } if UNIVERSAL::isa( $_[0]->[_VALUE_SR_IDX], _RESOLUTION_CLASS );

    my $err = ${ $_[0]->[_VALUE_SR_IDX] };
    die $err if substr($err, -1) eq "\n";
    Carp::croak $err;
}

use constant _noop => ();

sub AWAIT_ON_READY {
    $_[0][_ON_READY_IMMEDIATE_IDX] = $_[1];
}

*AWAIT_CHAIN_CANCEL = *_noop;
*AWAIT_ON_CANCEL = *_noop;

1;
