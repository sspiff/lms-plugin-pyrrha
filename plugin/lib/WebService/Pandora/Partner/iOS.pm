package WebService::Pandora::Partner::iOS;

use strict;
use warnings;

use base 'WebService::Pandora::Partner';

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = $class->SUPER::new( username => 'iphone',
				   password => 'P2E4FC0EAD3*878N92B2CDp34I0B1@388137C',
				   deviceModel => 'IP01',
				   decryption_key => '20zE1E47BE57$51',
				   encryption_key => '721^26xE22776',
				   host => 'tuner.pandora.com' );
    
    return $self;
}

1;
