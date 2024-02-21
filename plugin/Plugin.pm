package Plugins::Pyrrha::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::OPMLBased);

use Digest::MD5 qw(md5_hex);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::Pyrrha::Utils qw(getStationList getStationArtUrl);

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
    my $stationSortKey = $prefs->get('stationSortOrder');
    my $stationSortMethod;
    if ($stationSortKey eq 'name') {
      $stationSortMethod = sub {
        (exists $a->{$stationSortKey} && $a->{$stationSortKey} || '') cmp (exists $b->{$stationSortKey} && $b->{$stationSortKey} || '');
      };
    }
    elsif ($stationSortKey eq 'dateCreated') {
      $stationSortMethod = sub {
        (exists $b->{$stationSortKey} && $b->{$stationSortKey} || '') cmp (exists $a->{$stationSortKey} && $a->{$stationSortKey} || '')
      };
    }
    elsif ($stationSortKey eq 'lastPlayed') {
      $stationSortMethod = sub {
        (exists $b->{$stationSortKey} && $b->{$stationSortKey} || '') cmp (exists $a->{$stationSortKey} && $a->{$stationSortKey} || '')
      };
    }
    elsif ($stationSortKey eq 'totalPlayTime') {
      $stationSortMethod = sub {
        (exists $b->{$stationSortKey} && $b->{$stationSortKey} || 0) <=> (exists $a->{$stationSortKey} && $a->{$stationSortKey} || 0)
      };
    }
    else {
      $log->error("Invalid stationSortOrder ${stationSortKey}");
      $callback->();
    }
    $log->debug("Sorting stations by $stationSortKey");
    my @quickmix;
    my @sorted_stations = @$stations;
    # Temporarily exclude quickmix station from sort to keep at top
    unless ($prefs->get('disableQuickMix')) {
      push(@quickmix, shift @sorted_stations);
    }
    @sorted_stations = sort $stationSortMethod @sorted_stations;
    unshift @sorted_stations, @quickmix;
    foreach my $station ( @sorted_stations ) {
      my $stationId = $station->{'stationId'};
      my $artUrl = getStationArtUrl($station);
      push @$items, {
        'name'  => $station->{'name'},
        'type'  => 'audio',
        'url'   => "pyrrha://$usernameDigest/$stationId.mp3",
        'image' => $artUrl ? $artUrl : 'plugins/Pyrrha/images/icon_svg.png',
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

  $prefs->init({
    stationSortOrder => 'lastPlayed',
  });

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

