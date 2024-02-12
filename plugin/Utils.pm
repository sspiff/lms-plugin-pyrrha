package Plugins::Pyrrha::Utils;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(getWebService getStationList getPlaylist);

use Slim::Utils::Prefs;
use JSON;
use WebService::Pandora;
use WebService::Pandora::Partner::AIR;

my $log = Slim::Utils::Log->addLogCategory({
  category     => 'plugin.pyrrha',
  defaultLevel => 'INFO',
  description  => 'PLUGIN_PYRRHA_MODULE_NAME',
});

my $prefs = preferences( 'plugin.pyrrha' );


my %cache = ();


my $WEBSVC_LIFETIME = (60 * 60 * 4) - (60 * 2);  # 4 hrs - 2 min grace
my $STATIONLIST_LIFETIME = 60 * 20;              # 20 min


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
  if (!$websvc->login()) {
    my $e = $websvc->error();
    if (ref $e eq 'HASH') {
      $e = $e->{'message'}
    }
    $log->error($e);
    $errorCb->($e);
    return;
  }
  $log->info('login successful');

  $cache{'webService'} = $websvc;

  $successCb->($websvc);
  return;
}


sub getStationList {
  my ($successCb, $errorCb, %args) = @_;
  my $noRefresh = $args{'noRefresh'};

  my $websvc = $cache{'webService'};
  my $stationList = $cache{'stationList'};
  if (defined $stationList &&
      ($noRefresh || time() < $stationList->{'expiresAt'})) {
    $log->info('using cached station list');
    $successCb->($stationList->{'stations'}, $websvc);
    return;
  }

  my $withWebsvc = sub {
    my ($websvc) = @_;
    $log->info('fetching station list');
    my $result = $websvc->getStationList(includeStationArtUrl => JSON::true());
    if ($result) {
      my $stationList = {
        expiresAt => time() + $STATIONLIST_LIFETIME,
        stations  => $result->{'stations'},
      };
      $cache{'stationList'} = $stationList;
      $successCb->($stationList->{'stations'}, $websvc);
    }
    else {
      my $e = $websvc->error();
      if (ref $e eq 'HASH') {
        if ($e->{'apiCode'} == 1001) {
          # auth token expired, clear our cached credentials
          $log->info('auth token expired, clearing cache');
          %cache = ();
        }
        $e = $e->{'message'}
      }
      $log->error($e);
      $errorCb->("Error getting station list ($e)");
    }
  };

  my $withoutWebsvc = sub {
    $log->error(@_);
    $errorCb->('Unable to connect/login to Pandora');
  };

  getWebService($withWebsvc, $withoutWebsvc);
}


sub getStationToken {
  my ($stationId, $successCb, $errorCb) = @_;

  my $withStationList = sub {
    my ($stationList, $websvc) = @_;
    my ($station) = grep { $stationId == $_->{stationId} } @$stationList;
    if ($station) {
      $successCb->($station->{stationToken}, $websvc);
    }
    else {
      $log->error('stationId not found in station list');
      $errorCb->('Station not found');
    }
  };

  my $withoutStationList = sub {
    $errorCb->(@_);
  };

  getStationList($withStationList, $withoutStationList, noRefresh => 1);
}


sub getPlaylist {
  my ($stationId, $successCb, $errorCb) = @_;

  my $onError = sub {
    $errorCb->(@_);
  };

  my $withStationToken = sub {
    my ($stationToken, $websvc) = @_;
    my $result = $websvc->getPlaylist(stationToken => $stationToken);
    if ($result) {
      my $playlist = $result->{'items'};
      $successCb->($playlist);
    }
    else {
      my $e = $websvc->error();
      if (ref $e eq 'HASH') {
        if ($e->{'apiCode'} == 1001) {
          # auth token expired, clear our cached credentials
          $log->info('auth token expired, clearing cache');
          %cache = ();
        }
        $e = $e->{'message'}
      }
      $log->error($e);
      $errorCb->("Error getting play list ($e)");
    }

  };

  getStationToken($stationId, $withStationToken, $onError);
}


1;

