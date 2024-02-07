package Plugins::Pyrrha::ProtocolHandler;

use strict;
use base qw(Slim::Player::Protocols::HTTP);
use Plugins::Pyrrha::Utils qw(getPlaylist);

my $log = Slim::Utils::Log->addLogCategory({
  category     => 'plugin.pyrrha',
  defaultLevel => 'INFO',
  description  => 'PLUGIN_PYRRHA_MODULE_NAME',
});


# max time player can be idle before stopping playback (8 hours)
my $MAX_IDLE_TIME = 60 * 60 * 8;


sub new {
  my $class = shift;
  my $args  = shift;

  my $client = $args->{client};

  my $song = $args->{'song'};
  my $streamUrl = $song->streamUrl() || return;

  $log->info( 'PH:new(): ' . $streamUrl );

  my $sock = $class->SUPER::new( {
    url     => $streamUrl,
    song    => $args->{'song'},
    client  => $client,
    bitrate => $song->bitrate() || 128_000,
  } ) || return;

  ${*$sock}{contentType} = 'audio/mpeg';

  return $sock;
}


sub scanUrl {
  my ($class, $url, $args) = @_;
  $args->{'cb'}->($args->{'song'}->currentTrack());
}


sub isRepeatingStream { 1 }


sub getNextTrack {
  my ($class, $song, $successCb, $errorCb) = @_;

  my $client = $song->master();
  my $url    = $song->track()->url;
  my ($urlUsername, $urlStationId) = $url =~ m{^pyrrha://([^/]+)/([^.]+)\.mp3};

  $log->info( $url );

  # idle time check
  if ($client->isPlaying()) {
    # get last activity time from this player and any synced players
    my $lastActivity = $client->lastActivityTime();
    if ($client->isSynced(1)) {
      for my $c ($client->syncGroupActiveMembers()) {
        my $otherActivity = $c->lastActivityTime();
        if ($otherActivity > $lastActivity) {
          $lastActivity = $otherActivity;
        }
      }
    }
    # idle too long?
    if (time() - $lastActivity >= $MAX_IDLE_TIME) {
      $log->info('idle time reached, stopping playback');
      $client->playingSong()->pluginData({
        songName => $client->string('PLUGIN_PYRRHA_IDLE_STOPPING'),
      });
      $errorCb->('PLUGIN_PYRRHA_IDLE_STOPPING');
      return;
    }
  }

  my $station = $client->master->pluginData('station');
  if ($station) {
    $log->info('found cached station data ' . ($station->{'stationId'}));
    $log->info('playlist length: ' . (scalar @{$station->{'playlist'}}));
  }
  else {
    $log->info('no previous station data');
  }

  my $nextFromPlaylist = sub {
    my ($playlist) = @_;
    my $track = shift @$playlist;
    my $audio = $track->{'audioUrlMap'}->{'highQuality'};
    $song->bitrate($audio->{'bitrate'} * 1000);
    $song->duration($track->{'trackLength'} * 1);
    $song->streamUrl($audio->{'audioUrl'});
    $song->pluginData('track', $track);
    $log->info('next in playlist: ' . ($track->{'songIdentity'}));
    $successCb->();
  };

  my $withNewPlaylist = sub {
    my ($playlist) = @_;
    my %station = (
      'stationId' => $urlStationId,
      'playlist'  => $playlist
    );
    $client->master->pluginData('station', \%station);
    $nextFromPlaylist->($playlist);
  };

  my $withoutPlaylist = sub {
    $errorCb->('Unable to get play list');
  };

  if ($station &&
      $station->{'stationId'} eq $urlStationId &&
      @{$station->{'playlist'}}[0]) {
    $log->info('using next from cached playlist');
    $nextFromPlaylist->($station->{'playlist'});
  }
  else {
    $log->info('fetching new playlist');
    getPlaylist($urlStationId, $withNewPlaylist, $withoutPlaylist);
  }
}


sub trackGain {
  my ($class, $client, $url) = @_;

  my $track = $client->streamingSong()->pluginData('track');
  my $gain = $track->{'trackGain'} || 0;

  return $gain * 1;
}


sub getMetadataFor {
  my ($class, $client, $url, $forceCurrent) = @_;

  my $song = $forceCurrent ? $client->streamingSong() : $client->playingSong();
  return {} unless $song;

  my $track = $song->pluginData('track');
  if ($track && %$track) {
    return {
      artist  => $track->{artistName},
      album   => $track->{albumName},
      title   => $track->{songName},
      cover   => $track->{albumArtUrl},
      bitrate => $song->bitrate ? ($song->bitrate/1000) . 'k' : '',
      buttons => {
        rew => 0,
        fwd => 0,
      },
    };
  }
  else {
    return {};
  }
}

