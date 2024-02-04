package WebService::Pandora::Partner::WindowsMobile;

use strict;
use warnings;

use base 'WebService::Pandora::Partner';

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = $class->SUPER::new( username => 'winmo',
				   password => 'ED227E10a628EB0E8Pm825Dw7114AC39',
				   deviceModel => 'VERIZON_MOTOQ9C',
				   decryption_key => '7D671jt0C5E5d251',
				   encryption_key => 'v93C8C2s12E0EBD',
				   host => 'tuner.pandora.com' );
    
    return $self;
}

1;
