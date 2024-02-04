package WebService::Pandora::Partner::Palm;

use strict;
use warnings;

use base 'WebService::Pandora::Partner';

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = $class->SUPER::new( username => 'palm',
				   password => 'IUC7IBG09A3JTSYM4N11UJWL07VLH8JP0',
				   deviceModel => 'pre',
				   decryption_key => 'E#U$MY$O2B=',
				   encryption_key => '%526CBL$ZU3',
				   host => 'tuner.pandora.com' );
    
    return $self;
}

1;
