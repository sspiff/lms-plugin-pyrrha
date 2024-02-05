package Plugins::Pandora2024::Utils;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(getPandoraWebService getPandoraStationList);

use Slim::Utils::Prefs;
use JSON;
use WebService::Pandora;
use WebService::Pandora::Partner::AIR;

my $prefs = preferences( 'plugin.pandora2024' );


sub getPandoraWebService {
  my ($client, $successCb, $errorCb) = @_;

  my $websvc = $client->pluginData('pandoraWebService');
  if (defined $websvc) {
    $successCb->($websvc);
    return;
  }

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

  my $stationList = $client->pluginData('pandoraStationList');
  if (defined $stationList) {
    $successCb->($stationList);
    return;
  }

  my $withWebsvc = sub {
    my ($websvc) = @_;
    my $result = $websvc->getStationList(includeStationArtUrl => JSON::true());
    if ($result) {
      my $stationList = $result->{'stations'};
      $client->pluginData('pandoraStationList', $stationList);
      $successCb->($stationList);
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

