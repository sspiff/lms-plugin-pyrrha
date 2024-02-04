package WebService::Pandora::Partner::AIR;

use strict;
use warnings;

use base 'WebService::Pandora::Partner';

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = $class->SUPER::new( username => 'pandora one',
				   password => 'TVCKIBGS9AO9TSYLNNFUML0743LH82D',
				   deviceModel => 'D01',
				   decryption_key => 'U#IO$RZPAB%VX2',
				   encryption_key => '2%3WCL*JU$MP]4',
				   host => 'internal-tuner.pandora.com' );
    
    return $self;
}

1;
