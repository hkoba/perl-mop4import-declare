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

describe "MOP4Import::Base::CLI_JSON", sub {
  describe "package MyApp1 {use ... -as_base;...}", sub {

    it "should have no error"
      , no_error q{
package MyApp1;
use MOP4Import::Base::CLI_JSON -as_base, -inc, [fields => qw/foo/];

sub cmd_cmd {
  (my MY $self, my @args) = @_;
  print join(" ", $self->{foo}, @args), "\n";
}

sub meth_scalar {
  (my MY $self, my @args) = @_;
  [$self->{foo} => @args];
}

sub meth_list {
  (my MY $self, my @args) = @_;
  ($self->{foo} => @args);
}

1;
};

    describe "MyApp1->run([--foo,cmd])", sub {
      expect(capture {MyApp1->run(['--foo','cmd','baz'])})->to_be("1 baz\n");
    };

    describe "MyApp1->run([--foo={x:3},meth_scalar,{y:8},undef,[a,b,c]])", sub {
      describe "--output=json", sub {
        expect(capture {MyApp1->run(['--no-exit-code','--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]'])})->to_be(qq|[[{"x":3},{"y":8},null,[1,"foo",2,3]]]\n|);
      };

      describe "--output=json --scalar", sub {
        expect(capture {MyApp1->run(['--scalar','--no-exit-code','--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]'])})->to_be(qq|[{"x":3},{"y":8},null,[1,"foo",2,3]]\n|);
      };

      describe "--output=dump", sub {
        expect(capture {MyApp1->run(['--no-exit-code','--output=dump','--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]'])})->to_be(qq|{'x' => 3}\t{'y' => 8}\tnull\t[1,'foo',2,3]\n|);
      };

      describe "--output=tsv", sub {
        expect(capture {MyApp1->run(['--no-exit-code','--output=tsv','--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]'])})->to_be(qq|{"x":3}\t{"y":8}\tnull\t[1,"foo",2,3]\n|);
      };
    };

  };
};

done_testing();
