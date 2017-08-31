#!/usr/bin/env perl
# -*- mode: perl; coding: utf-8 -*-
#----------------------------------------
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;
use FindBin; BEGIN { do "$FindBin::Bin/t_lib.pl" }

use Test::Kantan;
use Scalar::Util qw/isweak/;

use rlib qw!../..!;

use MOP4Import::t::t_lib qw/no_error expect_script_error/;

use Capture::Tiny qw(capture);

describe "MOP4Import::Base::CLI", sub {
  describe "package MyApp1 {use ... -as_base;...}", sub {

    it "should have no error"
      , no_error q{
package MyApp1;
use MOP4Import::Base::CLI -as_base, -inc, [fields => qw/foo/];

sub cmd_bar {
  (my MY $self, my @args) = @_;
  print join(" ", $self->{foo}, @args), "\n";
}

sub bar {
  Carp::croak("Not reached!");
}

sub qux {
  (my MY $self, my @args) = @_;
  [$self->{foo} => [@args]];
}

1;
};

    describe "MyApp1->run([--foo,bar])", sub {
      expect(capture {MyApp1->run(['--foo','bar','baz'])})->to_be("1 baz\n");
    };

    describe "MyApp1->run([--foo=ok,qux,quux])", sub {
      expect(capture {MyApp1->run(['--foo=ok','qux','quux'])})->to_be("['ok',['quux']]\n");
    };

  };
};

done_testing();
