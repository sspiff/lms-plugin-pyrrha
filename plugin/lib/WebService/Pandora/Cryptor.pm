package WebService::Pandora::Cryptor;

use strict;
use warnings;

use Crypt::ECB;
use Data::Dumper;

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = {'encryption_key' => undef,
                'decryption_key' => undef,
                @_};

    bless( $self, $class );

    my $crypt = Crypt::ECB->new();

    $crypt->padding( 'standard' );
    $crypt->cipher( 'Blowfish' );

    $self->{'crypt'} = $crypt;

    return $self;
}

### getters/setters ###

sub error {

    my ( $self, $error ) = @_;

    $self->{'error'} = $error if ( defined( $error ) );

    return $self->{'error'};
}

### public methods ###

sub encrypt {

    my ( $self, $data ) = @_;

    # make sure encryption_key defined
    if ( !defined( $self->{'encryption_key'} ) ) {

        $self->error( 'An encryption_key must be provided to the constructor.' );
        return;
    }

    # make sure data to encrypt was given
    if ( !defined( $data ) ) {

        $self->error( 'A string of data to encrypt must be given.' );
        return;
    }

    # give the crypt object the encryption key
    $self->{'crypt'}->key( $self->{'encryption_key'} );

    # return the hex-encrypted form
    return $self->{'crypt'}->encrypt_hex( $data );
}

sub decrypt {

    my ( $self, $data ) = @_;

    # make sure decryption_key defined
    if ( !defined( $self->{'decryption_key'} ) ) {

        $self->error( 'A decryption_key must be provided to the constructor.' );
        return;
    }

    # make sure data to decrypt was given
    if ( !defined( $data ) ) {

        $self->error( 'A string of data to decrypt must be given.' );
        return;
    }

    # give the crypt object the decryption key
    $self->{'crypt'}->key( $self->{'decryption_key'} );

    # return the hex-encrypted form
    return $self->{'crypt'}->decrypt_hex( $data );
}

1;
