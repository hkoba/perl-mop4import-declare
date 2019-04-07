package MOP4Import::Util::CallTester;
use strict;
use warnings;

use Test::More;
use Capture::Tiny ();
use Test::Exit;

use MOP4Import::Base::Configure -as_base, [fields => qw/target_object/];
use MOP4Import::Util qw/terse_dump shallow_copy/;

sub make_tester {
  my ($pack, $app) = @_;
  my MY $self = $pack->new;
  $self->{target_object} = $app;
  $self;
}

sub returns_in_scalar {
  (my MY $self, my ($call, $expect)) = @_;
  my ($method, @args) = @$call;
  my @savedArgs = map {shallow_copy($_)} @args;
  is_deeply(scalar($self->{target_object}->$method(@args)), $expect
            , sprintf("scalar call:%s(%s) expect:%s"
                      , $method
                      , join(", ", map(terse_dump($_), @savedArgs))
                      , terse_dump($expect)));
}

sub returns_in_list {
  (my MY $self, my ($call, $expect)) = @_;
  my ($method, @args) = @$call;
  my @savedArgs = map {shallow_copy($_)} @args;
  is_deeply([$self->{target_object}->$method(@args)], $expect
            , sprintf("list call:%s(%s) expect:%s"
                      , $method
                      , join(", ", map(terse_dump($_), @savedArgs))
                      , terse_dump($expect)));
}

sub captures {
  (my MY $self, my ($call, $expect)) = @_;
  my ($method, @args) = @$call;
  my @savedArgs = map {shallow_copy($_)} @args;
  is(Capture::Tiny::capture {
    $self->{target_object}->$method(@args);
  }, $expect, sprintf("call:%s(%s) expect:%s"
                      , $method
                      , join(", ", map(terse_dump($_), @savedArgs))
                      , terse_dump($expect)));
}

sub exits {
  (my MY $self, my ($call, $expectSpec)) = @_;
  my ($method, @args) = @$call;
  my @savedArgs = map {shallow_copy($_)} @args;
  my ($stdout, $stderr, @return);
  my $exit = Test::Exit::exit_code {
    ($stdout, $stderr, @return) = Capture::Tiny::capture {
      $self->{target_object}->$method(@args);
    };
  };

  if (ref $expectSpec) {
    is([$exit, $stdout, $stderr, @return], $expectSpec
       , sprintf("call:%s(%s) expect:%s"
                 , $method
                 , join(", ", map(terse_dump($_), @savedArgs))
                 , terse_dump($expectSpec)));
  } else {
    is($exit, $expectSpec
       , sprintf("call:%s(%s) expect:%s"
                 , $method
                 , join(", ", map(terse_dump($_), @savedArgs))
                 , terse_dump($expectSpec)));
  }
}

1;
