package Plugins::Pyrrha::Settings;

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.pyrrha');

sub name {
  return Slim::Web::HTTP::CSRF->protectName('PLUGIN_PYRRHA_MODULE_NAME');
}

sub page {
  return 'plugins/Pyrrha/settings/basic.html';
}

sub prefs {
  return ($prefs, 'username', 'password', 'stationSortOrder', 'disableQuickMix', 'forceNonMaterialIcon', 'showInRadioMenu');
}

sub handler {
  my ($class, $client, $params) = @_;
  my $ret = $class->SUPER::handler($client, $params);
  return $ret;
}


1;

