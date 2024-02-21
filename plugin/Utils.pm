package Plugins::Pyrrha::Utils;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(getWebService getStationList getPlaylist);

use Slim::Utils::Prefs;
use Slim::Networking::SimpleAsyncHTTP;
use Slim::Networking::Async::HTTP;
use URI;
use JSON;
use WebService::Pandora;
use WebService::Pandora::Partner::AIR;
use Data::Dumper;

my $log = Slim::Utils::Log->addLogCategory({
  category     => 'plugin.pyrrha',
  defaultLevel => 'INFO',
  description  => 'PLUGIN_PYRRHA_MODULE_NAME',
});

my $prefs = preferences( 'plugin.pyrrha' );


my %cache = ();
my $json = JSON->new->utf8;


my $WEBSVC_LIFETIME = (60 * 60 * 4) - (60 * 2);  # 4 hrs - 2 min grace
my $STATIONLIST_LIFETIME = 60 * 20;              # 20 min
my $STATIONLIST_PAGESIZE = 250;                  # How many stations to retrieve at a time

sub getWebService {
  my ($successCb, $errorCb) = @_;

  my $websvc = $cache{'webService'};
  if (defined $websvc && time() < $websvc->{'expiresAt'}) {
    $log->info('using cached websvc');
    $successCb->($websvc);
    return;
  }

  $log->info('creating new websvc');
  $websvc = WebService::Pandora->new(
              username => $prefs->get('username'),
              password => $prefs->get('password'),
              partner  => WebService::Pandora::Partner::AIR->new(),
              expiresAt => time() + $WEBSVC_LIFETIME,
            );

  $websvc->login(sub {
    my (%r) = @_;
    my ($result, $error) = @r{'result', 'error'};
    if ($error) {
      if (ref $error eq 'HASH') {
        $error = $error->{'message'};
      }
      $log->error($error);
      $errorCb->($error);
    }
    else {
      $log->info('login successful');
      $cache{'webService'} = $websvc;
      $successCb->($websvc);
    }
  });
}

sub getStationList {
  my ($successCb, $errorCb, %args) = @_;
  my $noRefresh = $args{'noRefresh'};
  my @stations;

  my $websvc = $cache{'webService'};
  my $stationList = $cache{'stationList'};
  my $now = time();
  if (defined $websvc &&
      $now < $websvc->{'expiresAt'} &&
      defined $stationList &&
      ($noRefresh || $now < $stationList->{'expiresAt'})) {
    $log->info('using cached station list');
    $successCb->($stationList->{'stations'}, $websvc);
    return;
  }

  # Skip fetching QuickMix/Shuffle station if desired
  if ($prefs->get('disableQuickMix')) {
    getRestStationList({
      stations  => \@stations,
      successCb => $successCb,
      errorCb   => $errorCb,
    });
  }
  else {
    getRestQuickMix({
      stations  => \@stations,
      successCb => $successCb,
      errorCb   => $errorCb,
    });
  }
}

sub getRestStationList {
  _rest(
    'v1/station/getStations',
    {
      pageSize => $STATIONLIST_PAGESIZE,
    },
    \&restStationCallback,
    \&restErrorCallback,
    @_,
  );
}

sub restStationCallback {
  my (%response) = @_;
  my $stations = $response{'passthrough'}->{'stations'};
  my $totalStationsRetrieved = $response{'passthrough'}->{'totalStationsRetrieved'} || 0;
  my $stationsRetrieved = scalar(@{$response{'result'}->{'stations'}});
  $log->debug("Retrieved ${stationsRetrieved} stations");
  $log->debug("Station IDs: " . join(', ', map { $_->{'stationId'} } @{$response{'result'}->{'stations'}}));
  my $total_stations = $response{'result'}->{'totalStations'};
  $log->debug("Total stations: ${total_stations}");
  $log->debug(Dumper($response{'result'}->{'stations'}->[0]));
  push(@$stations, @{$response{'result'}->{'stations'}});
  $totalStationsRetrieved += $stationsRetrieved;
  $log->debug("Total retrieved stations: ${totalStationsRetrieved}");
  if ($totalStationsRetrieved < $total_stations) {
    _rest(
      'v1/station/getStations',
      {
        pageSize   => $STATIONLIST_PAGESIZE,
        startIndex => $totalStationsRetrieved,
      },
      \&restStationCallback,
      \&restErrorCallback,
      {
        %{$response{'passthrough'}},
        totalStationsRetrieved => $totalStationsRetrieved,
      }
    );
  }
  else {
    $log->debug("Retrieved all ${total_stations} stations");
    $cache{'stationList'} = {
      expiresAt => time() + $STATIONLIST_LIFETIME,
      stations  => $stations,
    };
    $response{'passthrough'}->{'successCb'}->($stations);
  }
}

sub getRestQuickMix {
  _rest(
    'v1/station/shuffle',
    {},
    \&restQuickMixCallback,
    \&restErrorCallback,
    @_,
  );
}

sub restQuickMixCallback {
  my (%response) = @_;
  $log->debug("shuffle response: " . Dumper(\%response));
  my $stations = $response{'passthrough'}->{'stations'};
  push(@$stations, $response{'result'});
  getRestStationList({
    stations  => $stations,
    successCb => $response{'passthrough'}->{'successCb'},
    errorCb   => $response{'passthrough'}->{'errorCb'},
  });
}

sub restErrorCallback {
  my ($error, $passthrough) = @_;
  $log->error($error);
  $passthrough->{'errorCb'}->($error);
}

sub getPlaylist {
  my ($stationId, $successCb, $errorCb) = @_;

  my $onError = sub {
    $errorCb->(@_);
  };

  my $withWebsvc = sub {
    my ($websvc) = @_;
    $websvc->getPlaylist(sub {
      my (%r) = @_;
      my ($result, $error) = @r{'result', 'error'};
      if ($result) {
        my $playlist = $result->{'items'};
        $successCb->($playlist);
      }
      else {
        if (ref $error eq 'HASH') {
          if ($error->{'apiCode'} == 1001) {
            # auth token expired, clear our cached credentials
            $log->info('auth token expired, clearing cache');
            %cache = ();
          }
          $error = $error->{'message'}
        }
        $log->error($error);
        $errorCb->("Error getting play list ($error)");
      }
    },
      stationToken => $stationId
    );
  };

  getWebService($withWebsvc, $onError);
}

sub _rest {
  my ($endpoint, $args, $successCb, $errorCb, $passthrough) = @_;

  # Fetch CSRF cookie from www.pandora.com
  my $uri = URI->new('https://www.pandora.com');
  my $http = Slim::Networking::SimpleAsyncHTTP->new(
    sub {
      _restCsrfCallback->($endpoint, $args, $successCb, $errorCb, $passthrough);
    },
    sub {
      my ($req, $error) = @_;
      $log->error($error);
      $errorCb->($error, $passthrough);
    },
    {
      $args,
    }
  );
  $http->head($uri);
}

sub _restCsrfCallback {
  my ($endpoint, $args, $successCb, $errorCb, $passthrough) = @_;
  my $csrftoken = Slim::Networking::Async::HTTP->cookie_jar->get_cookies('.pandora.com', 'csrftoken');
  unless ($csrftoken) {
    $errorCb->(result => undef, error => 'Failed to retrieve CSRF token from www.pandora.com');
    return;
  }
  my $uri = URI->new("https://www.pandora.com/api/${endpoint}");
  my $withWebsvc = sub {
    my ($websvc) = @_;
    my $http = Slim::Networking::SimpleAsyncHTTP->new(
      sub {
        my $response = shift;
        my $json = $json->decode($response->content);
        $successCb->(result => $json, passthrough => $passthrough);
      },
      sub {
        my ($req, $error) = @_;
        $log->error($error);
        $errorCb->($error, $passthrough);
      }
    );
    $http->post(
      $uri,
      'X-CsrfToken' => $csrftoken,
      'X-AuthToken' => $websvc->{'userAuthToken'},
      'Content-Type' => 'application/json;charset=utf-8',
      $json->encode($args),
    );
  };
  getWebService($withWebsvc, sub { $errorCb->(shift, $passthrough); });
}

1;
