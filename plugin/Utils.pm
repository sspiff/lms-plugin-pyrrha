package Plugins::Pyrrha::Utils;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(fetch trackMetadataForStreamUrl);

use Slim::Networking::SimpleAsyncHTTP;
use Promise::ES6;


# promise-based wrapper around Slim::Networking::SimpleAsyncHTTP
Promise::ES6::use_event('SlimServer') unless $Promise::ES6::_EVENT;
sub fetch {
  my ($resource, %options) = @_;
  my $method  = $options{'method'} || 'GET'; delete $options{'method'};
  my $headers = $options{'headers'} || {};   delete $options{'headers'};
  my $body    = $options{'body'};            delete $options{'body'};
  return Promise::ES6->new(sub {
      my ($resolve, $reject) = @_;
      my $http = Slim::Networking::SimpleAsyncHTTP->new(
          $resolve,
          sub {
            $reject->({'request' => shift, 'error' => shift});
          },
          \%options
        );
      $http->_createHTTPRequest($method => ($resource, %$headers, $body));
    });
}


# our track metadata cache
#
my @_trackMetadataCache = ();
sub trackMetadataForStreamUrl {
  my $keyUrl = shift;
  my $newValue = shift;

  # find an existing entry
  if (! $newValue) {
    foreach (@_trackMetadataCache) {
      my ($u, $m, $e) = @$_;       # (url, metadata, expiration)
      return $m if $u eq $keyUrl;
    }
    return undef;
  }

  # add a new entry
  #
  # entries are tuples: (key, data, expiration)
  #
  # we put new entries at the beginning of the list so our search
  # above is brief, and we'll expire entries after 1 hour, which
  # is about how long the audioUrls are good for
  #
  unshift @_trackMetadataCache, [$keyUrl, $newValue, time() + (60 * 60)];

  # prune expired entries
  my $now = time();
  for (0 .. $#_trackMetadataCache) {
    my ($u, $m, $e) = @{$_trackMetadataCache[$_]};
    next if $e > $now;
    # this and all following entries are expired
    splice @_trackMetadataCache, $_;
    last;
  }

  return;
}


1;
