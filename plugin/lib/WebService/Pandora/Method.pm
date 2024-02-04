package WebService::Pandora::Method;

use strict;
use warnings;

use WebService::Pandora::Cryptor;

use URI;
use JSON;
use HTTP::Request;
use LWP::UserAgent;
use Data::Dumper;

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = {'name' => undef,
                'partnerAuthToken' => undef,
                'userAuthToken' => undef,
                'partnerId' => undef,
                'userId' => undef,
                'syncTime' => undef,
                'host' => undef,
                'ssl' => 0,
                'encrypt' => 1,
                'cryptor' => undef,
                'timeout' => 10,
                'params' => {},
                @_};

    bless( $self, $class );

    # create and store user agent object
    $self->{'ua'} = LWP::UserAgent->new( timeout => $self->{'timeout'} );

    # create and store json object
    $self->{'json'} = JSON->new();

    return $self;
}

### getters/setters ###

sub error {

    my ( $self, $error ) = @_;

    $self->{'error'} = $error if ( defined( $error ) );

    return $self->{'error'};
}

### public methods ###

sub execute {

    my ( $self ) = @_;

    # make sure both name and host were given
    if ( !defined( $self->{'name'} ) || !defined( $self->{'host'} ) ) {

        $self->error( 'Both the name and host must be provided to the constructor.' );
        return;
    }

    # craft the json data accordingly
    my $json_data = {};

    if ( defined( $self->{'userAuthToken'} ) ) {

        $json_data->{'userAuthToken'} = $self->{'userAuthToken'};
    }

    if ( defined( $self->{'syncTime'} ) ) {

        $json_data->{'syncTime'} = int( $self->{'syncTime'} );
    }

    # merge the two required params with the additional user-supplied args
    $json_data = {%$json_data, %{$self->{'params'}}};

    # encode it to json
    $json_data = $self->{'json'}->encode( $json_data );

    # encrypt it, if needed
    if ( $self->{'encrypt'} ) {

        $json_data = $self->{'cryptor'}->encrypt( $json_data );

        # detect error decrypting
        if ( !defined( $json_data ) ) {

            $self->error( 'An error occurred encrypting our JSON data: ' . $self->{'cryptor'}->error() );
            return;
        }
    }

    # http or https?
    my $protocol = ( $self->{'ssl'} ) ? 'https://' : 'http://';

    # craft the full URL, protocol + host + path
    my $url = $protocol . $self->{'host'} . '/services/json/';

    # create URI object
    my $uri = URI->new( $url );

    # create all url params for POST request
    my $url_params = ['method' => $self->{'name'}];

    # set user_auth_token if provided
    if ( defined( $self->{'userAuthToken'} ) ) {

        push( @$url_params, 'auth_token' => $self->{'userAuthToken'} );
    }

    # set partner_auth_token if provided and user_auth_token was not
    elsif ( defined( $self->{'partnerAuthToken'} ) ) {

        push( @$url_params, 'auth_token' => $self->{'partnerAuthToken'} );
    }

    # set partner_id if provided
    if ( defined( $self->{'partnerId'} ) ) {

        push( @$url_params, 'partner_id' => $self->{'partnerId'} );
    }

    # set user_id if provided
    if ( defined( $self->{'userId'} ) ) {

        push( @$url_params, 'user_id' => $self->{'userId'} );
    }

    # add the params to the URI
    $uri->query_form( $url_params );

    # create and store the POST request accordingly
    my $request = HTTP::Request->new( 'POST', $uri );

    # json data is the POST content
    $request->content( $json_data );

    # issue the HTTP request
    my $response = $self->{'ua'}->request( $request );

    # handle request error
    if ( !$response->is_success() ) {

        $self->error( $response->status_line() );
        return;
    }

    # decode the raw content of the response
    my $content = $response->decoded_content();

    # decode the JSON content
    $json_data = $self->{'json'}->decode( $content );

    # handle pandora error
    if ( $json_data->{'stat'} ne 'ok' ) {

        $self->error( "$self->{'name'} error $json_data->{'code'}: $json_data->{'message'}" );
        return;
    }

    # return all result data, if any exists
    return $json_data->{'result'} if ( defined( $json_data->{'result'} ) );

    # otherwise just return a true value to indicate success
    return 1;
}

1;
