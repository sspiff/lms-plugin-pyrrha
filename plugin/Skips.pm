package Plugins::Pyrrha::Skips;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(canSkip, recordSkip, setSkipAllowance);

use JSON;


# Plugins::Pyrrha::Skips
#
# This module implements our skip bookkeeping to ensure that we honor
# the service's skip allowances.
#
# The service imposes two skip limits: a per-station-per-hour skip limit
# (a rolling 60-minute interval) and a per-account-per-day limit (which
# resets at local midnight).  Both are always in force.
#
# Each time a track is skipped (or thumbed down), we record the skip as a
# tuple: (time, accountid, stationid).  These tuples are persisted as a
# JSON-encoded array in our preferences.
#
# To check if a skip is within the allowance, we count the number of
# skips for the station in the last hour and the number skips for the
# account since local midnight.  These counts are compared against the
# account's skip allowance.
#
# Currently, skip records that are no longer relevant (prior to midnight
# and at least an hour old) are pruned from the in-memory list in canSkip(),
# but are not purged from persistent storage until a subsequent recordSkip().
#


sub canSkip {
  my ($accountId, $stationId) = @_;
  my $r = _getSkips();

  my $now = _time();
  my $lastHour = $now - (60 * 60);
  my $lastMidnight = $now - _timeSinceMidnight();

  my $pruneCount = 0;
  my $totalSkips = 0;
  my $stationSkips = 0;

  foreach (@$r) {
    my ($t, $a, $s) = @$_;
    if (($t < $lastHour) && ($t < $lastMidnight)) {
      $pruneCount++;
      next;
    }
    next if $a ne $accountId;
    $totalSkips++ if $t >= $lastMidnight;
    $stationSkips++ if $t >= $lastHour and $s eq $stationId;
  }
  splice @$r, 0, $pruneCount if $pruneCount > 0;

  my ($stationSkipLimit, $dailyLimit) = _allowanceFor($accountId);

  return ($stationSkips < $stationSkipLimit) && ($totalSkips < $dailyLimit);
}


sub recordSkip {
  my ($accountId, $stationId) = @_;
  my $r = _getSkips();

  my @skip = (_time(), $accountId, $stationId);
  push(@$r, \@skip);

  _saveSkips();
}


my %_allowances = ();
sub setSkipAllowance {
  my ($accountId, $stationSkipLimit, $dailySkipLimit) = @_;
  $_allowances{$accountId} = [$stationSkipLimit, $dailySkipLimit];
}


my @_defaultAllowance = (6, 12);  # per-station-per-hour, total daily
sub _allowanceFor {
  my ($accountId) = @_;
  return $_allowances{$accountId} ? @{$_allowances{$accountId}}
                                  : @_defaultAllowance;
}


my $_theSkips;
sub _getSkips {
  $_theSkips = decode_json(_loadSkips()) unless $_theSkips;
  return $_theSkips;
}


sub _saveSkips {
  _storeSkips(encode_json(_getSkips()));
}


sub _timeSinceMidnight {
  my @time = localtime(_time());
  return ($time[2] * 3600) + ($time[1] * 60) + $time[0];
}


# these are dynamically defined below
#
#sub _loadSkips
#sub _storeSkips
#sub _time
my $_fluxCapacitor = undef;
if (caller()) {
  # presumably running under LMS
  require Slim::Utils::Prefs;
  my $prefs = Slim::Utils::Prefs::preferences( 'plugin.pyrrha' );
  *_loadSkips = sub { $prefs->get('skips') || '[]' };
  *_storeSkips = sub { $prefs->set('skips', shift) };
  *_time = sub { time() };
}
else {
  # running standalone, so set up for testing
  *_loadSkips = sub { '[]' };
  *_storeSkips = sub { undef };
  *_time = sub { $_fluxCapacitor || time() };
}


## tests
#

sub _runTests {

  require Data::Dumper;

  # go back to midnight
  $_fluxCapacitor  = time();
  $_fluxCapacitor -= _timeSinceMidnight();

  setSkipAllowance('a1', 2, 4);

  canSkip('a1', 's11') || die 'bad canSkip';
  recordSkip('a1', 's11'); $_fluxCapacitor += 600;
  canSkip('a1', 's11') || die 'bad canSkip';
  recordSkip('a1', 's11'); $_fluxCapacitor += 600;
  canSkip('a1', 's11') && die 'bad canSkip';

  canSkip('a1', 's12') || die 'bad canSkip';
  recordSkip('a1', 's12'); $_fluxCapacitor += 600;
  canSkip('a1', 's12') || die 'bad canSkip';
  recordSkip('a1', 's12'); $_fluxCapacitor += 600;
  canSkip('a1', 's12') && die 'bad canSkip';
  (scalar @$_theSkips) == 4 || die 'bad skip count';

  canSkip('a1', 's13') && die 'bad canSkip';
  canSkip('a2', 's21') || die 'bad canSkip';

  # we're 40 min into the hour at this point; jump into the next hour
  $_fluxCapacitor += 60 * 25;
  # a1/s11 now has just 1 skip in the last hour,
  # but we're still at 4 for the day, so:
  (scalar @$_theSkips) == 4 || die 'bad skip count';
  canSkip('a1', 's11') && die 'bad canSkip';
  canSkip('a1', 's12') && die 'bad canSkip';
  canSkip('a1', 's13') && die 'bad canSkip';

  # jump to just after midnight
  $_fluxCapacitor += (24 * 60 * 60) - _timeSinceMidnight() + (10 * 60);
  canSkip('a1', 's11') || die 'bad canSkip';
  canSkip('a1', 's12') || die 'bad canSkip';
  # all entries should have been purged
  (scalar @$_theSkips) == 0 || die 'bad skip count';

  # jump to 15 min before midnight
  $_fluxCapacitor += (24 * 60 * 60) - _timeSinceMidnight() - (15 * 60);

  canSkip('a1', 's11') || die 'bad canSkip';
  recordSkip('a1', 's11'); $_fluxCapacitor += 600;
  canSkip('a1', 's11') || die 'bad canSkip';
  recordSkip('a1', 's11'); $_fluxCapacitor += 600;
  canSkip('a1', 's11') && die 'bad canSkip';

  canSkip('a1', 's12') || die 'bad canSkip';
  recordSkip('a1', 's12'); $_fluxCapacitor += 600;
  canSkip('a1', 's12') || die 'bad canSkip';
  recordSkip('a1', 's12'); $_fluxCapacitor += 600;
  canSkip('a1', 's12') && die 'bad canSkip';

  # while we've got 4 skips in the last hour,
  # we've only got 2 since midnight, so:
  canSkip('a1', 's13') || die 'bad canSkip';
  # but:
  canSkip('a1', 's11') && die 'bad canSkip';
  (scalar @$_theSkips) == 4 || die 'bad skip count';


  print Data::Dumper::Dumper($_theSkips);

  print encode_json($_theSkips) . "\n";

  print _timeSinceMidnight() . "\n";
}

_runTests() unless caller();


1;

