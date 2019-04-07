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

use MOP4Import::Util::CallTester [as => 'CallTester'];

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

    my $CT = CallTester->make_tester('MyApp1');

    subtest "MyApp1->run([--foo,cmd])", sub {
      $CT->captures([run => ['--foo','cmd','baz']], "1 baz\n");
    };

    subtest "MyApp1->run([--foo={x:3},meth_scalar,{y:8},undef,[a,b,c]])", sub {
      my @args = ('--foo={"x":3}'
                  , 'meth_scalar'
                  , '{"y":8}', undef, '[1,"foo",2,3]');
      subtest "default (--output=json)", sub {
        $CT->captures([run => ['--no-exit-code', @args]]
                      , qq|[[{"x":3},{"y":8},null,[1,"foo",2,3]]]\n|);
      };

      subtest "--output=json --scalar", sub {
        $CT->captures([run => ['--no-exit-code', '--scalar', @args]]
                      , qq|[{"x":3},{"y":8},null,[1,"foo",2,3]]\n|);
      };

      subtest "--output=dump", sub {
        $CT->captures([run => ['--no-exit-code', '--output=dump', @args]]
                      , qq|{'x' => 3}\t{'y' => 8}\tnull\t[1,'foo',2,3]\n|);
      };

      subtest "--output=tsv", sub {
        $CT->captures([run => ['--no-exit-code', '--output=tsv', @args]]
                      , qq|{"x":3}\t{"y":8}\tnull\t[1,"foo",2,3]\n|);
      };
    };

    subtest "cli_... APIs", sub {
      my $test = CallTester->make_tester(MyApp1->new);

      $test->returns_in_list([cli_array => qw(a b 1 2)], [qw(a b 1 2)]);
      $test->returns_in_scalar([cli_object => qw(a b 1 2)], +{a => 'b', 1 => '2'});
    };

  };
};

done_testing();
