package WebService::Pandora::Partner;

use strict;
use warnings;

use WebService::Pandora::Method;
use Data::Dumper;

use constant WEBSERVICE_VERSION => '5';

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = {'username' => undef,
                'password' => undef,
                'deviceModel' => undef,
                'decryption_key' => undef,
                'encryption_key' => undef,
                'host' => undef,
                @_};

    bless( $self, $class );

    return $self;
}

### getters/setters ###

sub error {

    my ( $self, $error ) = @_;

    $self->{'error'} = $error if ( defined( $error ) );

    return $self->{'error'};
}

### public methods ###

sub login {

    my ( $self, $cb ) = @_;

    # make sure all arguments are given
    if ( !defined( $self->{'username'} ) ||
         !defined( $self->{'password'} ) ||
         !defined( $self->{'deviceModel'} ) ||
         !defined( $self->{'encryption_key'} ) ||
         !defined( $self->{'decryption_key'} ) ||
         !defined( $self->{'host'} ) ) {

        $self->error( 'The username, password, deviceModel, encryption_key, decryption_key, and host must all be provided to the constructor.' );
        $cb->(error => $self->error());
        return;
    }

    # create the auth.partnerLogin method
    my $method = WebService::Pandora::Method->new( name => 'auth.partnerLogin',
                                                   encrypt => 0,
                                                   ssl => 1,
                                                   host => $self->{'host'},
                                                   params => {'username' => $self->{'username'},
                                                              'password' => $self->{'password'},
                                                              'deviceModel' => $self->{'deviceModel'},
                                                              'version' => "5"} );

    $method->execute(
        sub {
            my (%res) = @_;
            if (defined $res{'error'}) {
                $self->error( $res{'error'} )
            }
            $cb->(@_);
        }
    );
}

1;
