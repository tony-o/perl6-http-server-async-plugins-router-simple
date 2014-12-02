#!/usr/bin/env perl6

use lib 'lib';
use HTTP::Server::Async::Plugins::Router::Simple;
use HTTP::Server::Async;
use Test;
plan 6;

my $host = '127.0.0.1';
my $port = (6000..8000).pick;
my $rest = HTTP::Server::Async::Plugins::Router::Simple.new;
my $serv = HTTP::Server::Async.new(:$host, :$port);
my $ord  = 0;

$rest.put(
  / ^ '/' $ / => sub ($q, $s, $c) {
    $ord = 100; # this will never get called
    $c(False);
  }
);

$rest.all(
  / ^ '/' $ / => sub ($req, $res, $cb) {
    ok True, 'Matched first in chain' if $ord++ == 0;
    $cb(True);
  },
  '/' => sub ($req, $res, $cb) {
    ok True, 'Matched second in chain' if $ord++ == 1;
    start {
      sleep 2;
      ok True, 'Waited for sleep before matching next' if $ord++ == 2;
      $cb(True);
    };
  },
  '/' => sub ($req, $res, $cb) {
    ok True, 'Waited for sleep before matching next' if $ord++ == 3;
    $res.close("Hi world\n");
    $cb(False);
  },
  '/' => sub ($req, $res, $cb) {
    ok False, 'This should never be called';
  },
);

$rest.hook($serv);

$serv.listen;
my $client = IO::Socket::INET.new(:$host, :$port) or die 'couldn\'t connect';
$client.send("GET / HTTP/1.0\r\n\r\n");
my $ret;
while (my $str = $client.recv) {
  $ret ~= $str;
}
$client.close;
ok $ret.match(/ ^^ 'Hi world' $$/), 'Got to the end';
ok $ord == 4, 'Never called last sub';
