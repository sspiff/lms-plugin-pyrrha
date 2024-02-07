package Plugins::Pandora2024::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::Pandora2024::Utils qw(getPandoraStationList);

sub getDisplayName () {
  return 'PLUGIN_PANDORA2024_MODULE_NAME';
}

my $log = Slim::Utils::Log->addLogCategory({
  'category'     => 'plugin.pandora2024',
  'defaultLevel' => 'INFO',
  'description'  => getDisplayName(),
});

my $prefs = preferences( 'plugin.pandora2024' );


sub handleFeed {
  my ($client, $callback) = @_;

  my $items = [];
  my %opml = (
    'type'  => 'opml',
    'title' => 'Pandora 2024',   #XXX
    'items' => $items,
  );

  my $withStations = sub {
    my ($stations) = @_;
    my $username = $prefs->get('username');
    foreach my $station ( @$stations ) {
      my $stationId = $station->{'stationId'};
      push @$items, {
        'name'  => $station->{'stationName'},
        'type'  => 'audio',
        'url'   => "pandora2024://$username/$stationId.mp3",
        'image' => $station->{'artUrl'},
      };
    }
    $callback->(\%opml);
  };

  my $withoutStations = sub {
    my ($error) = @_;
    push @$items, {
      'name' => $error,
      'type' => 'textarea',
    };
    $callback->(\%opml);
  };

  getPandoraStationList($withStations, $withoutStations);
}


sub initPlugin {
  my $class = shift;

  Slim::Player::ProtocolHandlers->registerHandler(
    pandora2024 => 'Plugins::Pandora2024::ProtocolHandler'
  );

  if ( main::WEBUI ) {
    require Plugins::Pandora2024::Settings;
    Plugins::Pandora2024::Settings->new;
  }

  $class->SUPER::initPlugin(
    feed   => \&handleFeed,
    tag    => 'pandora2024',
    menu   => 'music_services',
    weight => 10,
    is_app => 1,
  );
}

1;

