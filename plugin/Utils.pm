package Plugins::Pyrrha::Utils;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(fetch);

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


1;
