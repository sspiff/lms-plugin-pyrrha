package Plugins::Pandora2024::Settings;

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.pandora2024');

sub name {
  return Slim::Web::HTTP::CSRF->protectName('PLUGIN_PANDORA2024_MODULE_NAME');
}

sub page {
  return 'plugins/Pandora2024/settings/basic.html';
}

sub prefs {
  return ($prefs, 'username', 'password');
}

sub handler {
  my ($class, $client, $params) = @_;
  my $ret = $class->SUPER::handler($client, $params);
  return $ret;
}


1;

