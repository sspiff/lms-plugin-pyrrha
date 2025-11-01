package Plugins::Pyrrha::ProtocolHandler;

use strict;
use base qw(Slim::Player::Protocols::HTTPS);
use Plugins::Pyrrha::Pandora qw(getPlaylist getAdMetadata registerAd);
use Plugins::Pyrrha::Skips;
use Plugins::Pyrrha::Utils qw(trackMetadataForStreamUrl);

use Promise::ES6;

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

  return $sock;
}


sub scanUrl {
  my ($class, $url, $args) = @_;
  $args->{'cb'}->($args->{'song'}->currentTrack());
}


sub isRepeatingStream { 1 }


sub canSeek { 0 }


sub _trackOrAd {
  my $stationId = shift;
  my $track = shift;

  # just return the track if not an ad
  my $adToken = $track->{'adToken'};
  return Promise::ES6->resolve($track) if ! $adToken;

  # get ad metadata
  getAdMetadata(adToken => $adToken)->then(sub {
  my $ad = shift;

  # make this ad look like a track
  return {
    audioUrlMap         => $ad->{'audioUrlMap'},
    songIdentity        => $adToken,
    artistName          => $ad->{'companyName'},
    albumName           => 'Advertisement',
    songName            => $ad->{'title'},
    albumArtUrl         => $ad->{'imageUrl'},
    '_isAd'             => 1,
    '_stationId'        => $stationId,
    '_adTrackingTokens' => $ad->{'adTrackingTokens'},
  };

  })->catch(sub {
  my $error = shift;
  $log->error('unable to get ad metadata: ' . $error);
  die $error;
  });
}


sub _getPlaylistWithAds {
  my $stationId = shift;

  # fetch a new play list
  getPlaylist($stationId)->then(sub {
  my $playlist = shift;

  # convert any ads to "tracks"
  my @tracks = map { _trackOrAd($stationId, $_) } @$playlist;

  return Promise::ES6->all(\@tracks);
  });
}


sub _getNextStationTrack {
  my $stationId   = shift;
  my $oldPlaylist = shift;  # previously cached playlist

  # use previously cached playlist or fetch a new one
  ($oldPlaylist && @$oldPlaylist ?
      Promise::ES6->resolve($oldPlaylist)
    : _getPlaylistWithAds($stationId)
  )->catch(sub {
    die 'Unable to get play list';
  })->then(sub {
  my $playlist = shift;

  # get the next track
  my $track = shift @$playlist;

  # if it's an ad, register that we're going to play it
  if ($track->{'_isAd'}) {
    registerAd(
        stationId => $track->{'_stationId'},
        adTrackingTokens => $track->{'_adTrackingTokens'}
      )->catch(sub {
        $log->debug('registerAd failed: ' . shift);
      });
  }

  # if it doesn't have audio, go to the next one
  if (! $track->{'audioUrlMap'}) {
    return _getNextStationTrack($stationId, $playlist);
  }

  return [$track, $playlist];
  });
}


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
      #XXX how is this used?
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
    if ($urlStationId ne $station->{'stationId'}) {
      $log->info('station change ' . $urlStationId);
    }
  }
  else {
    $log->info('no previous station data');
  }

  # check for skipping
  if (   $station
      && $urlStationId eq $station->{'stationId'}
      && time() < $station->{'exSkipTime'}) {
    $log->info('skip detected');
    Plugins::Pyrrha::Skips::recordSkip($urlUsername, $urlStationId);
  }

  my $oldPlaylist = $station && $urlStationId eq $station->{'stationId'}
    ? $station->{'playlist'}
    : [];

  # get next track for station
  _getNextStationTrack($urlStationId, $oldPlaylist)->then(sub {
  my $trackAndPlaylist = shift;
  my ($track, $newPlaylist) = @$trackAndPlaylist;

  # cache new playlist
  my %station = (
    'stationId' => $urlStationId,
    'playlist'  => $newPlaylist,
  );
  $client->master->pluginData('station', \%station);

  # populate song data
  $track->{'_canSkip'} =
       !$track->{'_isAd'}
    && Plugins::Pyrrha::Skips::canSkip($urlUsername, $urlStationId);
  my $audio = $track->{'audioUrlMap'}->{'highQuality'};
  $track->{'_audio'} = $audio;
  if ($track->{'_isAd'}) {
    #XXX squeezelite fails to connect to aws cloudfront when
    #    https is used, but it will work with http:
    $audio->{'audioUrl'} =~ s/^https/http/;
  }
  $song->streamUrl($audio->{'audioUrl'});
  trackMetadataForStreamUrl($song->streamUrl(), $track);
  $log->info('next in playlist: ' . ($track->{'songIdentity'}));

  my $format = _formatForEncoding($audio->{'encoding'});
  Slim::Utils::Scanner::Remote::parseRemoteHeader(
    $song->track, $audio->{'audioUrl'}, $format,
    sub {
      # update metadata with parse results
      $song->bitrate($song->track->bitrate);
      $song->duration($song->track->secs);
      $track->{'_bitrateDescription'} =
        sprintf("%.0f" . Slim::Utils::Strings::string('KBPS'),
          $song->track->bitrate/1000);
      $track->{'_duration'} = $song->track->secs;
      # a track change before this time will be considered a skip.
      # we include some margin because LMS seems to often request
      # the next track ~10s before the end of the current one.
      $station{'exSkipTime'} = time() + $song->track->secs - 15;
      $successCb->();
    },
    sub {
      my ($self, $error) = @_;
      $log->warn( "could not find $format header $error" );
      $successCb->();
    }
  );

  })->catch(sub {

  $errorCb->('Unable to get play list');

  });
}


sub suppressPlayersMessage {
  my ($class, $master, $song, $message) = @_;
  if ($message eq 'PROBLEM_CONNECTING') {
    my $url = $song->track()->url;
    $log->error("stream error: $url PROBLEM_CONNECTING");
    # error possibly due to stale playlist
    # clear playlist cache to force fetch of new playlist
    my $client = $song->master();
    $client->master->pluginData('station', 0);
  }
  return 0;
}


sub handleDirectError {
  my ($class, $client, $url, $response, $status_line) = @_;
  $log->error("direct stream error: $url [$response] $status_line");
  # error possibly due to stale playlist
  # clear playlist cache to force fetch of new playlist
  $client->master->pluginData('station', 0);
  # notify the controller
  $client->controller()->playerStreamingFailed($client, 'PLUGIN_PYRRHA_STREAM_FAILED');
}


sub _canSkip {
  my $client = shift;

  my $meta = trackMetadataForStreamUrl($client->playingSong()->streamUrl());

  return $meta->{'_canSkip'};
}


sub canDoAction {
  my ($class, $client, $url, $action) = @_;

  # disallow rewind
  if ($action eq 'rew') {
    return 0;
  }

  # disallow skip?
  if ($action eq 'stop' && !_canSkip($client)) {
    return 0;
  }

  return 1;
}


sub trackGain {
  my ($class, $client, $url) = @_;

  # return the gain for the "streaming" song, which is the next song that
  # will start playing:
  my $meta = trackMetadataForStreamUrl($client->streamingSong()->streamUrl());
  my $gain = ($meta->{'trackGain'} || 0) + 0;

  return $gain;
}


sub getMetadataFor {
  my ($class, $client, $url, $forceCurrent) = @_;
  return {} unless $client;

  my $song = $forceCurrent ? $client->streamingSong() : $client->playingSong();
  return {} unless $song;

  my $meta = trackMetadataForStreamUrl($song->streamUrl());
  if ($meta && %$meta) {
    return {
      artist   => $meta->{artistName},
      album    => $meta->{albumName},
      title    => $meta->{songName},
      cover    => $meta->{albumArtUrl},
      duration => $meta->{'_duration'},
      bitrate  => $meta->{'_bitrateDescription'},
      buttons  => {
        rew => 0,
        fwd => _canSkip($client) ? 1 : 0,
        # use 'repeat' for thumbs up
        repeat => {
          command => $meta->{'allowFeedback'} ? ['pyrrha', 'rate', 1]
                                              : ['jivedummycommand'],
          jiveStyle => $meta->{'allowFeedback'} ? 'thumbsUp'
                                                : 'thumbsUpDisabled',
          tooltip => $client->string('PLUGIN_PYRRHA_I_LIKE'),
          icon => 'html/images/btn_thumbs_up.gif',
        },
        # use 'shuffle' for thumbs down
        shuffle => {
          command => $meta->{'allowFeedback'} ? ['pyrrha', 'rate', 0]
                                              : ['jivedummycommand'],
          jiveStyle => $meta->{'allowFeedback'} ? 'thumbsDown'
                                                : 'thumbsDownDisabled',
          tooltip => $client->string('PLUGIN_PYRRHA_I_DONT_LIKE'),
          icon => 'html/images/btn_thumbs_down.gif',
        },
      },
    };
  }
  else {
    return {};
  }
}


sub formatOverride {
  my ($class, $song) = @_;
  my $meta = trackMetadataForStreamUrl($song->streamUrl());
  my $audio = $meta->{'_audio'};
  my $encoding = $audio->{'encoding'};
  return _formatForEncoding($encoding);
}


sub _formatForEncoding {
  my $encoding = shift;
  return 'mp4' if $encoding eq 'aacplus';
  return 'mp3';
}


1;

