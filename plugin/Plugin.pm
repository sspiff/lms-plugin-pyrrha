package Plugins::Pandora2024::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

sub getDisplayName () {
  return 'PLUGIN_PANDORA2024_MODULE_NAME';
}

my $log = Slim::Utils::Log->addLogCategory({
  'category'     => 'plugin.pandora2024',
  'defaultLevel' => 'INFO',
  'description'  => getDisplayName(),
});

my $prefs = preferences( 'plugin.pandora2024' );

sub stationFeed {
  my ( $client, $callback ) = @_;
  my $items = [];
  push @$items, {
    'name'  => "Gin Blossoms Radio",
    'type'  => 'link',
    'url'   => 'foo://',
    'image' => 'https://content-images.p-cdn.com/images/46/c1/2f/83/eafa4884a3d65002a388d28a/_500W_500H.jpg',
  };
  my %opml = (
    'type'  => 'opml',
    'title' => 'Pandora 2024',   #XXX
    'items' => $items,
  );
  $callback->(\%opml);
}

sub initPlugin {
  my $class = shift;

  if ( main::WEBUI ) {
    require Plugins::Pandora2024::Settings;
    Plugins::Pandora2024::Settings->new;
  }

  $class->SUPER::initPlugin(
    feed   => \&stationFeed,
    tag    => 'pandora2024',
    menu   => 'music_services',
    weight => 10,
    is_app => 1,
  );
}


1;

