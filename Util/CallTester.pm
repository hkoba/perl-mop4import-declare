package MOP4Import::Util::CallTester;
use strict;
use warnings;

use Test::More;

use MOP4Import::Base::Configure -as_base, [fields => qw/target_object/];

use MOP4Import::Util qw/terse_dump/;

sub make_tester {
  my ($pack, $app) = @_;
  my MY $self = $pack->new;
  $self->{target_object} = $app;
  $self;
}

sub returns_in_scalar {
  (my MY $self, my ($call, $expect)) = @_;
  my ($method, @args) = @$call;
  is_deeply(scalar($self->{target_object}->$method(@args)), $expect
            , sprintf("scalar call:%s expect:%s", map {terse_dump($_)}
                      [$method, @args], $expect));
}

sub returns_in_list {
  (my MY $self, my ($call, $expect)) = @_;
  my ($method, @args) = @$call;
  is_deeply([$self->{target_object}->$method(@args)], $expect
            , sprintf("list call:%s expect:%s", map {terse_dump($_)}
                      [$method, @args], $expect));
}

1;
