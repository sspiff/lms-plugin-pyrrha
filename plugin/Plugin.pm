package Plugins::Pyrrha::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::OPMLBased);

use Digest::MD5 qw(md5_hex);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::Pyrrha::Pandora qw(getStationList getStationArtUrl addFeedback getStationDetail);
use Plugins::Pyrrha::Utils qw(trackMetadataForStreamUrl);

sub getDisplayName () {
  return 'PLUGIN_PYRRHA_MODULE_NAME';
}

my $log = Slim::Utils::Log->addLogCategory({
  'category'     => 'plugin.pyrrha',
  'defaultLevel' => 'INFO',
  'description'  => getDisplayName(),
});

my $prefs = preferences( 'plugin.pyrrha' );
my $defaultStationArtUrl;


sub _makeStationDescription {
  my $detail = shift;
  my $music = $detail->{'music'};
  my $feedback = $detail->{'feedback'};

  my $d = [];

  # seeding
  push @$d, "Seeds:";
  push @$d, "  Artists:";
  foreach my $s ( @{$music->{'artists'}} ) {
    push @$d, '    ' . $s->{'artistName'};
  }
  push @$d, "  Songs:";
  foreach my $s ( @{$music->{'songs'}} ) {
    push @$d, '    ' . $s->{'artistName'} . ', ' . $s->{'songName'};
  }
  push @$d, "  Genres:";
  foreach my $s ( @{$music->{'genres'}} ) {
    push @$d, '    ' . $s->{'genreName'};
  }

  # feedback
  push @$d, "Feedback:";
  push @$d, "  Thumbs Up:";
  foreach my $t ( @{$feedback->{'thumbsUp'}} ) {
    push @$d, '    ' . $t->{'artistName'} . ', ' . $t->{'songName'};
  }
  push @$d, "  Thumbs Down:";
  foreach my $t ( @{$feedback->{'thumbsDown'}} ) {
    push @$d, '    ' . $t->{'artistName'} . ', ' . $t->{'songName'};
  }

  return '<pre>' . join('<br>', @$d) . '</pre>';
}


sub _makeStationItem {
  my ($query, $usernameDigest, $station, $detail) = @_;

  my $stationId = $station->{'stationId'};
  my $playUrl = "pyrrha://$usernameDigest/$stationId.mp3";
  my $artUrl = getStationArtUrl($station);
  my $item = {
    'name'  => $station->{'name'},
    'type'  => 'audio',
    'url'   => $playUrl,
    'image' => $artUrl ? $artUrl : $defaultStationArtUrl,
    'itemActions' => {
      # we define our own play action so that we can embed the station
      # url into the request parameters.  this allows us to respond with
      # the exact station the user selected even if the station list
      # has changed.
      'play' => {
        'command' => [$query, 'playlist', 'play'],
        'fixedParams' => {
          '_stationId' => $stationId,
          'isContextMenu' => 1,
          'menu' => $query,
        },
      },
      'info' => {
        'command' => [$query, 'items'],
        'fixedParams' => {
          '_stationId' => $stationId,
          'isContextMenu' => 1,
          'menu' => $query,
          'item_id' => '00000000.0',
        },
      },
    },
  };
  if ($detail) {
    $item->{'description'} = _makeStationDescription($detail);
  }
  return $item;
}

sub handleFeed {
  my ($client, $callback, $args) = @_;
  my $query = $args->{'params'}->{'menu'};

  my $items = [];
  my %opml = (
    'type'  => 'opml',
    'title' => 'Pyrrha',   #XXX
    'items' => $items,
    # we cache ourselves, tell lms not to:
    'nocache' => 1,
    'cachetime' => 0,
  );

  my $username = $prefs->get('username');
  my $usernameDigest = md5_hex($username);

  # fetch the station list
  getStationList()->then(sub {
  my $stations = shift;

  if (!(scalar @$stations)) {
    # no stations
    $callback->(\%opml);
    return;
  }

  # handle request for a single station
  my $requestStationId = $args->{'params'}->{'_stationId'};
  if ($requestStationId) {
    my ($station) = grep { $requestStationId eq $_->{'stationId'} } @$stations;
    if ($station) {
      getStationDetail($requestStationId)->then(sub {
      my $detail = shift;
      push @$items,
        _makeStationItem($query, $usernameDigest, $station, $detail);
      $callback->(\%opml);
      })->catch(sub {
      my $error = shift;
      $log->error('unable to get station details: ' . $error);
      push @$items,
        _makeStationItem($query, $usernameDigest, $station);
      $callback->(\%opml);
      });
    }
    else {
      $callback->(\%opml);
    }
    return;
  }

  # return all stations
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
    die "Invalid stationSortOrder ${stationSortKey}";
  }
  $log->debug("Sorting stations by $stationSortKey");
  if (scalar @$stations) {
    my @quickmix;
    my @sorted_stations = @$stations;
    # Temporarily exclude quickmix station from sort to keep at top
    if ($stations->[0]->{'isShuffle'}) {
      push(@quickmix, shift @sorted_stations);
    }
    @sorted_stations = sort $stationSortMethod @sorted_stations;
    unshift @sorted_stations, @quickmix;
    foreach my $station ( @sorted_stations ) {
      push @$items, _makeStationItem($query, $usernameDigest, $station);
    }
  }

  $callback->(\%opml);

  })->catch(sub {
  my $error = shift;

  push @$items, {
    'name' => $error,
    'type' => 'textarea',
  };
  $callback->(\%opml);

  });
}


sub initPlugin {
  my $class = shift;

  Slim::Player::ProtocolHandlers->registerHandler(
    pyrrha => 'Plugins::Pyrrha::ProtocolHandler'
  );

  $prefs->init({
    stationSortOrder => 'lastPlayed',
  });

  # register handlers for our custom commands
  Slim::Control::Request::addDispatch(['pyrrha', 'rate', '_rating'],
    [0, 1, 1, \&rateTrack]);

  if ( main::WEBUI ) {
    require Plugins::Pyrrha::Settings;
    Plugins::Pyrrha::Settings->new;
  }

  $class->SUPER::initPlugin(
    feed   => \&handleFeed,
    tag    => 'pyrrha',
    menu   => 'radios',
    weight => 10,
    is_app => $prefs->get('showInRadioMenu') ? 0 : 1,
  );

  $defaultStationArtUrl = $class->SUPER::_pluginDataFor('icon');
}


sub _pluginDataFor {
  my ($class, $key) = @_;

  my $data = $class->SUPER::_pluginDataFor($key);

  # material doesn't seem to like our png-only icon in the
  # radio menu
  if (
         $key eq 'icon'
      && $prefs->get('forceNonMaterialIcon')
      && !$prefs->get('showInRadioMenu')) {
    $data =~ s/_svg\.png$/.png/;
  }

  return $data;
}


sub rateTrack {
  my $request = shift;
  my $client = $request->client();
  return unless defined $client;

  my $song = $client->playingSong() || return;
  my $meta = trackMetadataForStreamUrl($song->streamUrl()) || return;

  my $rating = $request->getParam('_rating');

  # we need: stationToken (stationId?) and trackToken to rate
  addFeedback(
    stationToken => $meta->{'stationId'},
    trackToken => $meta->{'trackToken'},
    isPositive => $rating
  )->then(sub {

  $log->info('feedback:'
    . ' thumbs ' . $rating ? 'up' : 'down'
    . ' \'' . $meta->{'songName'} . '\'');

  # if thumbs down, then skip this track if we can
  if (!$rating && $meta->{'_canSkip'}) {
    $client->execute(['playlist', 'jump', '+1']);
  }

  $request->setStatusDone();

  })->catch(sub {
  my $error = shift;

  $log->error('unable to add feedback: ' . $error);

  # the original pandora plugin did this:
  $request->setStatusBadParams();

  });
}


1;

