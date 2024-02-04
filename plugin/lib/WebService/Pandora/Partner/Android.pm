package WebService::Pandora::Partner::Android;

use strict;
use warnings;

use base 'WebService::Pandora::Partner';

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = $class->SUPER::new( username => 'android',
				   password => 'AC7IBG09A3DTSYM4R41UJWL07VLN8JI7',
				   deviceModel => 'android-generic',
				   decryption_key => 'R=U!LH$O2B#',
				   encryption_key => '6#26FRL$ZWD',
				   host => 'tuner.pandora.com' );
    
    return $self;
}

1;
