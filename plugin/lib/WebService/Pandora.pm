package WebService::Pandora;

use strict;
use warnings;

use WebService::Pandora::Method;
use WebService::Pandora::Cryptor;
use WebService::Pandora::Partner::iOS;

use JSON;
use Data::Dumper;

our $VERSION = '0.4';

### constructor ###

sub new {

    my $caller = shift;

    my $class = ref( $caller );
    $class = $caller if ( !$class );

    my $self = {'username' => undef,
                'password' => undef,
                'timeout' => 10,
                'partner' => undef,
                @_};

    # be nice and default to iOS partner if one wasn't given..
    if ( !defined( $self->{'partner'} ) ) {

        $self->{'partner'} = WebService::Pandora::Partner::iOS->new();
    }

    # create and store cryptor object, using the partner's encryption keys
    my $cryptor = WebService::Pandora::Cryptor->new( decryption_key => $self->{'partner'}{'decryption_key'},
                                                     encryption_key => $self->{'partner'}{'encryption_key'} );

    $self->{'cryptor'} = $cryptor;

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

    my ( $self ) = @_;

    # make sure both username and password were given
    if ( !defined( $self->{'username'} ) || !defined( $self->{'password'} ) ) {

        $self->error( 'Both username and password must be given in the constructor.' );
        return;
    }

    # first, do the partner login
    my $ret = $self->{'partner'}->login();

    # detect error
    if ( !$ret ) {

        # return the error message from the partner
        $self->error( $self->{'partner'}->error() );
        return;
    }

    # store the important attributes we got back as we'll need them later
    $self->{'partnerAuthToken'} = $ret->{'partnerAuthToken'};
    $self->{'partnerId'} = $ret->{'partnerId'};
    $self->{'syncTime'} = $ret->{'syncTime'};

    # throw an error if for some reason we didn't get them
    if ( !defined( $self->{'partnerAuthToken'} ) ||
         !defined( $self->{'partnerId'} ) ||
         !defined( $self->{'syncTime'} ) ) {

        $self->error( 'Either partnerAuthToken, partnerId, or syncTime was not returned!' );
        return;
    }

    # handle special case of decrypting the sync time
    $self->{'syncTime'} = $self->{'cryptor'}->decrypt( $self->{'syncTime'} );

    # detect error decrypting
    if ( !defined( $self->{'syncTime'} ) ) {

        $self->error( "An error occurred decrypting the syncTime: " . $self->{'cryptor'}->error() );
        return;
    }

    $self->{'syncTime'} = substr( $self->{'syncTime'}, 4 );

    # now create and execute the method for the user login request
    my $method = WebService::Pandora::Method->new( name => 'auth.userLogin',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 1,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'loginType' => 'user',
                                                              'username' => $self->{'username'},
                                                              'password' => $self->{'password'},
                                                              'partnerAuthToken' => $self->{'partnerAuthToken'}} );

    $ret = $method->execute();

    # detect error
    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    # store even more attributes we'll need later
    $self->{'userId'} = $ret->{'userId'};
    $self->{'userAuthToken'} = $ret->{'userAuthToken'};

    # make sure we actually got them
    if ( !defined( $self->{'userId'} ) || !defined( $self->{'userAuthToken'} ) ) {

        $self->error( 'Either userId or userAuthToken was not returned!' );
        return;
    }

    # success
    return 1;
}

sub getBookmarks {

    my ( $self ) = @_;

    # create the user.getBookmarks method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'user.getBookmarks',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub getStationList {

    my ( $self ) = @_;

    # create the user.getStationList method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'user.getStationList',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub getStationListChecksum {

    my ( $self ) = @_;

    # create the user.getStationListChecksum method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'user.getStationListChecksum',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub getStation {

    my ( $self, %args ) = @_;

    my $stationToken = $args{'stationToken'};
    my $includeExtendedAttributes = $args{'includeExtendedAttributes'};

    $includeExtendedAttributes = ( $includeExtendedAttributes ) ? JSON::true() : JSON::false();

    # make sure they provided a stationToken argument
    if ( !defined( $stationToken ) ) {

        $self->error( 'A stationToken must be specified.' );
        return;
    }

    # create the user.getStation method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.getStation',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'stationToken' => $stationToken,
                                                              'includeExtendedAttributes' => $includeExtendedAttributes} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub search {

    my ( $self, %args ) = @_;

    my $searchText = $args{'searchText'};

    # make sure they provided a searchText argument
    if ( !defined( $searchText ) ) {

        $self->error( 'A searchText must be specified.' );
        return;
    }

    # create the music.search method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'music.search',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'searchText' => $searchText} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub getPlaylist {

    my ( $self, %args ) = @_;

    my $stationToken = $args{'stationToken'};

    # make sure they provided a stationToken argument
    if ( !defined( $stationToken ) ) {

        $self->error( 'A stationToken must be specified.' );
        return;
    }

    # create the station.getPlaylist method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.getPlaylist',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'stationToken' => $stationToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub explainTrack {

    my ( $self, %args ) = @_;

    my $trackToken = $args{'trackToken'};

    # make sure they provided a trackToken argument
    if ( !defined( $trackToken ) ) {

        $self->error( 'A trackToken must be specified.' );
        return;
    }

    # create the track.explainTrack method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'track.explainTrack',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'trackToken' => $trackToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub addArtistBookmark {

    my ( $self, %args ) = @_;

    my $trackToken = $args{'trackToken'};

    # make sure they provided a trackToken argument
    if ( !defined( $trackToken ) ) {

        $self->error( 'A trackToken must be specified.' );
        return;
    }

    # create the bookmark.addArtistBookmark method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'bookmark.addArtistBookmark',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'trackToken' => $trackToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub addSongBookmark {

    my ( $self, %args ) = @_;

    my $trackToken = $args{'trackToken'};

    # make sure they provided a trackToken argument
    if ( !defined( $trackToken ) ) {

        $self->error( 'A trackToken must be specified.' );
        return;
    }

    # create the bookmark.addSongBookmark method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'bookmark.addSongBookmark',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'trackToken' => $trackToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub addFeedback {

    my ( $self, %args ) = @_;

    my $trackToken = $args{'trackToken'};
    my $isPositive = $args{'isPositive'};

    # make sure both the trackToken and isPositive arguments are provided
    if ( !defined( $trackToken ) || !defined( $isPositive ) ) {

        $self->error( 'Both trackToken and isPositive must be specified.' );
        return;
    }

    $isPositive = ( $isPositive ) ? JSON::true() : JSON::false();

    # create the station.addFeedback method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.addFeedback',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'trackToken' => $trackToken,
                                                              'isPositive' => $isPositive} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub deleteFeedback {

    my ( $self, %args ) = @_;

    my $feedbackId = $args{'feedbackId'};

    # make sure they provided a feedbackId argument
    if ( !defined( $feedbackId ) ) {

        $self->error( 'A feedbackId must be specified.' );
        return;
    }

    # create the station.deleteFeedback method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.deleteFeedback',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'feedbackId' => $feedbackId} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub addMusic {

    my ( $self, %args ) = @_;

    my $musicToken = $args{'musicToken'};
    my $stationToken = $args{'stationToken'};

    # make sure both the musicToken and stationToken arguments are provided
    if ( !defined( $musicToken ) || !defined( $stationToken ) ) {

        $self->error( 'Both musicToken and stationToken must be specified.' );
        return;
    }

    # create the station.addMusic method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.addMusic',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'musicToken' => $musicToken,
                                                              'stationToken' => $stationToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub deleteMusic {

    my ( $self, %args ) = @_;

    my $seedId = $args{'seedId'};

    # make sure they provided a seedId argument
    if ( !defined( $seedId ) ) {

        $self->error( 'A seedId must be specified.' );
        return;
    }

    # create the station.deleteMusic method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.deleteMusic',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'seedId' => $seedId} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub createStation {

    my ( $self, %args ) = @_;

    my $musicToken = $args{'musicToken'};
    my $trackToken = $args{'trackToken'};
    my $musicType = $args{'musicType'};

    my $params = {};

    # did they specify a music token, obtained via search?
    if ( defined( $musicToken ) ) {

        $params->{'musicToken'} = $musicToken;
    }

    # did they specify a track token, provided from a playlist?
    elsif ( defined( $trackToken ) ) {

        # make sure they also specific either song or artist type
        if ( !defined( $musicType ) ) {

            $self->error( "A musicType must be specified (either 'song' or 'artist') when supplying a track token." );
            return;
        }

        $params->{'trackToken'} = $trackToken;
        $params->{'musicType'} = $musicType;
    }

    # they didn't specify either
    else {

        $self->error( "Either musicToken or trackToken must be specified." );
        return;
    }

    # create the station.createStation method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.createStation',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => $params );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub renameStation {

    my ( $self, %args ) = @_;

    my $stationToken = $args{'stationToken'};
    my $stationName = $args{'stationName'};

    # make sure both the stationToken and stationName arguments are provided
    if ( !defined( $stationToken ) || !defined( $stationName ) ) {

        $self->error( 'Both stationToken and stationName must be specified.' );
        return;
    }

    # create the station.renameStation method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.renameStation',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'stationToken' => $stationToken,
                                                              'stationName' => $stationName} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub shareStation {

    my ( $self, %args ) = @_;

    my $stationId = $args{'stationId'};
    my $stationToken = $args{'stationToken'};
    my $emails = $args{'emails'};

    # make sure both the stationId, stationToken, and emails arguments are provided
    if ( !defined( $stationId ) || !defined( $stationToken ) || !defined( $emails ) ) {

        $self->error( 'The stationId, stationToken, and emails must be specified.' );
        return;
    }

    # create the station.shareStation method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.shareStation',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'stationId' => $stationId,
                                                              'stationToken' => $stationToken,
                                                              'emails' => $emails} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub transformSharedStation {

    my ( $self, %args ) = @_;

    my $stationToken = $args{'stationToken'};

    # make sure they provided a stationToken argument
    if ( !defined( $stationToken ) ) {

        $self->error( 'A stationToken must be specified.' );
        return;
    }

    # create the station.transformSharedStation method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.transformSharedStation',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'stationToken' => $stationToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub deleteStation {

    my ( $self, %args ) = @_;

    my $stationToken = $args{'stationToken'};

    # make sure they provided a stationToken argument
    if ( !defined( $stationToken ) ) {

        $self->error( 'A stationToken must be specified.' );
        return;
    }

    # create the station.deleteStation method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.deleteStation',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'stationToken' => $stationToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub sleepSong {

    my ( $self, %args ) = @_;

    my $trackToken = $args{'trackToken'};

    # make sure they provided a trackToken argument
    if ( !defined( $trackToken ) ) {

        $self->error( 'A trackToken must be specified.' );
        return;
    }

    # create the user.sleepSong method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'user.sleepSong',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'trackToken' => $trackToken} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub getGenreStations {

    my ( $self ) = @_;

    # create the station.getGenreStations method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.getGenreStations',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub getGenreStationsChecksum {

    my ( $self ) = @_;

    # create the station.getGenreStationsChecksum method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'station.getGenreStationsChecksum',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub setQuickMix {

    my ( $self, %args ) = @_;

    my $stationIds = $args{'stationIds'};

    # also allow quickMixStationIds alias since thats what its called in the JSON API
    $stationIds = $args{'quickMixStationIds'} if ( !defined( $stationIds ) );

    # make sure they provided a stationIds argument
    if ( !defined( $stationIds ) ) {

        $self->error( 'stationIds must be specified.' );
        return;
    }

    # create the user.setQuickMix method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'user.setQuickMix',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 0,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {'quickMixStationIds' => $stationIds} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

sub canSubscribe {

    my ( $self ) = @_;

    # create the user.canSubscribe method w/ appropriate params
    my $method = WebService::Pandora::Method->new( name => 'user.canSubscribe',
                                                   partnerAuthToken => $self->{'partnerAuthToken'},
                                                   userAuthToken => $self->{'userAuthToken'},
                                                   partnerId => $self->{'partnerId'},
                                                   userId => $self->{'userId'},
                                                   syncTime => $self->{'syncTime'},
                                                   host => $self->{'partner'}{'host'},
                                                   ssl => 1,
                                                   encrypt => 1,
                                                   cryptor => $self->{'cryptor'},
                                                   timeout => $self->{'timeout'},
                                                   params => {} );

    my $ret = $method->execute();

    if ( !$ret ) {

        $self->error( $method->error() );
        return;
    }

    return $ret;
}

1;
