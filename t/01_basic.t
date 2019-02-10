#!/usr/bin/env perl6

use lib 't/lib';
use lib 'lib';
use starter;
use HTTP::Server::Async::Plugins::Router::Simple;
use Test;
plan 7;

my $host = host;
my $port = port;
my $rest = HTTP::Server::Async::Plugins::Router::Simple.new;
my $serv = srv;
my $ord  = 0;

$rest.put(
  / ^ '/' $ / => sub ($q, $s) {
    $ord = 100; # this will never get called
    True;
  }
);

$rest.all(
  / ^ '/' $ / => sub ($req, $res) {
    ok True, 'Matched first in chain' if $ord++ == 0;
    True;
  },
  '/' => sub ($req, $res) {
    ok True, 'Matched second in chain' if $ord++ == 1;
    my $x = Promise.new;
    start {
      sleep 3;
      ok True, 'Waited for sleep before matching next' if $ord++ == 2;
      $x.keep(True);
    };
    $x;
  },
  '/' => sub ($req, $res) {
    ok True, 'Waited for sleep before matching next (2)' if $ord++ == 3;
    $res.close("Hi world\n");
    False;
  },
  '/' => sub ($req, $res) {
    ok False, 'This should never be called';
    False;
  },
);

$rest.hook($serv);

$serv.handler(sub ($req, $res) {
  ok True, 'this should be called only if req<uri> == \'/404\'' if $req.uri eq '/404'; 
  $res.close('done');
  False;
});

$serv.listen;
my $client = req;
$client.write("GET / HTTP/1.0\r\n\r\n".encode);
my $ret;
while (my $str = $client.recv) {
  $ret ~= $str;
}
$client.close;
ok $ret.match(/^^ 'Hi world' $$/), 'Got to the end';
ok $ord == 4, 'Never called last sub';

$client = req;
$client.write("GET /404 HTTP/1.0\r\n\r\n".encode);
$ret = '';
while ($str = $client.recv) {
  $ret ~= $str;
}
$client.close;
