package Plugins::Pyrrha::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::OPMLBased);

use Digest::MD5 qw(md5_hex);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::Pyrrha::Utils qw(getStationList);

sub getDisplayName () {
  return 'PLUGIN_PYRRHA_MODULE_NAME';
}

my $log = Slim::Utils::Log->addLogCategory({
  'category'     => 'plugin.pyrrha',
  'defaultLevel' => 'INFO',
  'description'  => getDisplayName(),
});

my $prefs = preferences( 'plugin.pyrrha' );


sub handleFeed {
  my ($client, $callback) = @_;

  my $items = [];
  my %opml = (
    'type'  => 'opml',
    'title' => 'Pyrrha',   #XXX
    'items' => $items,
  );

  my $withStations = sub {
    my ($stations) = @_;
    my $username = $prefs->get('username');
    my $usernameDigest = md5_hex($username);
    foreach my $station ( @$stations ) {
      my $stationId = $station->{'stationId'};
      my $artUrl = $station->{'artUrl'};
      push @$items, {
        'name'  => $station->{'stationName'},
        'type'  => 'audio',
        'url'   => "pyrrha://$usernameDigest/$stationId.mp3",
        'image' => $artUrl ? $artUrl : 'html/images/radio.png',
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

  getStationList($withStations, $withoutStations);
}


sub initPlugin {
  my $class = shift;

  Slim::Player::ProtocolHandlers->registerHandler(
    pyrrha => 'Plugins::Pyrrha::ProtocolHandler'
  );

  if ( main::WEBUI ) {
    require Plugins::Pyrrha::Settings;
    Plugins::Pyrrha::Settings->new;
  }

  $class->SUPER::initPlugin(
    feed   => \&handleFeed,
    tag    => 'pyrrha',
    menu   => 'music_services',
    weight => 10,
    is_app => 1,
  );
}


sub _pluginDataFor {
  my ($class, $key) = @_;

  my $data = $class->SUPER::_pluginDataFor($key);

  if ($key eq 'icon' && $prefs->get('forceNonMaterialIcon')) {
    $data =~ s/_svg\.png$/.png/;
  }

  return $data;
}


1;

