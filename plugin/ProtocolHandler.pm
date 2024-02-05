package Plugins::Pandora2024::ProtocolHandler;

use strict;
use base qw(Slim::Player::Protocols::HTTP);
use Plugins::Pandora2024::Utils qw(getPandoraPlaylist);

my $log = Slim::Utils::Log->addLogCategory({
  category     => 'plugin.pandora2024',
  defaultLevel => 'INFO',
  description  => 'PLUGIN_PANDORA2024_MODULE_NAME',
});

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
  my ($urlUsername, $urlStationId) = $url =~ m{^pandora2024://([^/]+)/([^.]+)\.mp3};

  $log->info( $url );

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
    getPandoraPlaylist($client, $urlStationId, $withNewPlaylist, $withoutPlaylist);
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

