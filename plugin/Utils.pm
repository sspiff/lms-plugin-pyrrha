package Plugins::Pandora2024::Utils;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(getPandoraWebService getPandoraStationList getPandoraPlaylist);

use Slim::Utils::Prefs;
use JSON;
use WebService::Pandora;
use WebService::Pandora::Partner::AIR;

my $log = Slim::Utils::Log->addLogCategory({
  category     => 'plugin.pandora2024',
  defaultLevel => 'INFO',
  description  => 'PLUGIN_PANDORA2024_MODULE_NAME',
});

my $prefs = preferences( 'plugin.pandora2024' );


sub getPandoraWebService {
  my ($client, $successCb, $errorCb) = @_;

  my $websvc = $client->pluginData('pandoraWebService');
  if (defined $websvc) {
    $log->info('using cached websvc');
    $successCb->($websvc);
    return;
  }

  $log->info('creating new websvc');
  $websvc = WebService::Pandora->new(
              username => $prefs->get('username'),
              password => $prefs->get('password'),
              partner  => WebService::Pandora::Partner::AIR->new()
            );
  if (!$websvc->login()) {
    $errorCb->($websvc->error());
    return;
  }

  $client->pluginData('pandoraWebService', $websvc);

  $successCb->($websvc);
  return;
}


sub getPandoraStationList {
  my ($client, $successCb, $errorCb) = @_;

  my $websvc = $client->pluginData('pandoraWebService');
  my $stationList = $client->pluginData('pandoraStationList');
  if (defined $stationList) {
    $log->info('using cached station list');
    $successCb->($stationList, $websvc);
    return;
  }

  my $withWebsvc = sub {
    my ($websvc) = @_;
    $log->info('fetching station list');
    my $result = $websvc->getStationList(includeStationArtUrl => JSON::true());
    if ($result) {
      my $stationList = $result->{'stations'};
      $client->pluginData('pandoraStationList', $stationList);
      $successCb->($stationList, $websvc);
    }
    else {
      my $e = $websvc->error();
      $errorCb->("Error getting station list ($e)");
    }
  };

  my $withoutWebsvc = sub {
    $errorCb->('Unable to connect/login to Pandora');
  };

  getPandoraWebService($client, $withWebsvc, $withoutWebsvc);
}


sub getPandoraStationToken {
  my ($client, $stationId, $successCb, $errorCb) = @_;

  my $withStationList = sub {
    my ($stationList, $websvc) = @_;
    my ($station) = grep { $stationId == $_->{stationId} } @$stationList;
    if ($station) {
      $successCb->($station->{stationToken}, $websvc);
    }
    else {
      $errorCb->('Station not found');
    }
  };

  my $withoutStationList = sub {
    $errorCb->(@_);
  };

  getPandoraStationList($client, $withStationList, $withoutStationList);
}


sub getPandoraPlaylist {
  my ($client, $stationId, $successCb, $errorCb) = @_;

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
      $errorCb->("Error getting play list ($e)");
    }

  };

  getPandoraStationToken($client, $stationId, $withStationToken, $onError);
}

