#!/usr/bin/env perl
# -*- mode: perl; coding: utf-8 -*-
#----------------------------------------
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;
use FindBin; BEGIN { do "$FindBin::Bin/t_lib.pl" }

#use Test::Kantan;
use Test::More;
use Test::Exit;
use Capture::Tiny qw(capture);

use Scalar::Util qw/isweak/;

use rlib qw!../..!;

use MOP4Import::Util qw/terse_dump/;

# use MOP4Import::t::t_lib qw/no_error expect_script_error/;

sub no_error {
  my ($script) = @_;
  local $@;
  eval "use strict; use warnings; $script";
  is($@, '');
};

subtest "MOP4Import::Base::CLI_JSON", sub {
  subtest "package MyApp1 {use ... -as_base;...}", sub {

    subtest "should have no error", sub {
      no_error q{
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
}};

    subtest "MyApp1->run([--foo,cmd])", sub {
      is(capture {MyApp1->run(['--foo','cmd','baz'])}, "1 baz\n");
    };

    subtest "MyApp1->run([--foo={x:3},meth_scalar,{y:8},undef,[a,b,c]])", sub {
      subtest "--output=json", sub {
        my (@args, $got, $expect);
        is(capture {MyApp1->run(['--no-exit-code', @args = ('--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]')])}, $expect = qq|[[{"x":3},{"y":8},null,[1,"foo",2,3]]]\n|);
        subtest "exit code", sub {
          is(exit_code {capture {MyApp1->run([@args])}}, 0);
        };
      };

      subtest "--output=json --scalar", sub {
        is(capture {MyApp1->run(['--scalar','--no-exit-code','--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]'])}, qq|[{"x":3},{"y":8},null,[1,"foo",2,3]]\n|);
      };

      subtest "--output=dump", sub {
        is(capture {MyApp1->run(['--no-exit-code','--output=dump','--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]'])}, qq|{'x' => 3}\t{'y' => 8}\tnull\t[1,'foo',2,3]\n|);
      };

      subtest "--output=tsv", sub {
        is(capture {MyApp1->run(['--no-exit-code','--output=tsv','--foo={"x":3}','meth_scalar','{"y":8}',undef,'[1,"foo",2,3]'])}, qq|{"x":3}\t{"y":8}\tnull\t[1,"foo",2,3]\n|);
      };
    };


    sub app_returns_scalar {
      my ($app, $req, $exp) = @_;
      my ($method, @args) = @$req;
      is_deeply(scalar($app->$method(@args)), $exp
                , sprintf("API:%s EXPECT:%s", map {terse_dump($_)}
                          [$method, @args], $exp));
    }

    sub app_returns_list {
      my ($app, $req, $exp) = @_;
      my ($method, @args) = @$req;
      is_deeply([$app->$method(@args)], $exp
                , sprintf("API:%s EXPECT:%s", map {terse_dump($_)}
                          [$method, @args], $exp));
    }

    subtest "cli_... APIs", sub {
      my $app = MyApp1->new;
      app_returns_list($app, [cli_array => qw(a b 1 2)], [qw(a b 1 3)]);
      app_returns_scalar($app, [cli_object => qw(a b 1 2)], +{a => 'b', 1 => '2'});
    };

  };
};

done_testing();
