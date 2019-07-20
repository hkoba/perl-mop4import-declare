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

sub should_compile ($$) {
  my ($title, $script) = @_;
  local $@;
  eval "use strict; use warnings; $script";
  is($@, '', $title);
};

should_compile "package MyApp1 {use ... -as_base;...}", q{
package MyApp1;
use MOP4Import::Base::CLI_JSON -as_base, -inc, [fields => qw/foo/]
, [output_format => ltsv => sub {
  my ($self, $outFH, @args) = @_;
    foreach my $dict ($self->cli_flatten_if_not_yet(@args)) {
      print $outFH join("\t", map {
        my $val = $dict->{$_};
        _strip_tab($_).":"._strip_tab(defined $val && ref $val ? $self->cli_encode_json($val) : $val);
      } sort keys %$dict), "\n";
    }
}
]
;

sub cmd_cmd {
  (my MY $self, my @args) = @_;
  print join(" ", $self->{foo}, @args), "\n";
}

sub contextual {
  (my MY $self, my @args) = @_;
  wantarray
   ? (+{result => $self->{foo}}, +{result => \@args})
   : [$self->{foo} => \@args]
}

sub _strip_tab { my ($str) = @_; $str =~ s/\t//g; $str }

1;
};

subtest "cli_json", sub {
  is MyApp1->cli_json, JSON::MaybeXS::JSON(), "cli_json";
};

subtest "cli_array and cli_object", sub {
  my $test = CallTester->make_tester(MyApp1->new);

  $test->returns_in_list([cli_array => qw(a b 1 2)], [qw(a b 1 2)]);
  $test->returns_in_scalar([cli_object => qw(a b 1 2)], +{a => 'b', 1 => '2'});
};

subtest "exit code", sub {
  SKIP: {
    skip "requires 5.24", 4 unless $] >= 5.024;
    my $test = CallTester->make_tester('MyApp1');

    $test->exits([run => [cli_array =>  1]], 0);
    $test->exits([run => [cli_array => ()]], 1);

    $test->exits([run => [qw/--scalar cli_identity/,  1]], 0);
    $test->exits([run => [qw/--scalar cli_identity/, '']], 1);
  }
};

my $CT = CallTester->make_tester('MyApp1');

subtest "MyApp1->run([--foo,cmd])", sub {
  $CT->captures([run => ['--foo','cmd','baz']], "1 baz\n");
};

subtest "MyApp1->run([--foo={x:3},contextual,{y:8},undef,[a,b,c]])", sub {
  my @args = ('--no-exit-code', '--foo={"x":3}'
              , contextual => '{"y":8}', undef, '[1,"foo",2,3]');
  subtest "default (--output=json)", sub {

    $CT->captures([run => [@args]]
                  , qq|[{"result":{"x":3}},{"result":[{"y":8},null,[1,"foo",2,3]]}]\n|);

    subtest "--flatten", sub {
      $CT->captures([run => ['--flatten', @args]]
                    , qq|{"result":{"x":3}}\n{"result":[{"y":8},null,[1,"foo",2,3]]}\n|);
    };

    subtest "--scalar", sub {
      $CT->captures([run => ['--scalar', @args]]
                    , qq|[{"x":3},[{"y":8},null,[1,"foo",2,3]]]\n|);
    };

    subtest "--scalar --flatten", sub {
      $CT->captures([run => ['--scalar', '--flatten', @args]]
                    , qq|{"x":3}\n[{"y":8},null,[1,"foo",2,3]]\n|);
    };
  };

  subtest "--output=dump", sub {
    $CT->captures([run => ['--output=dump', @args]]
                  , qq|[{'result' => {'x' => 3}},{'result' => [{'y' => 8},undef,[1,'foo',2,3]]}]\n|);

    subtest "--flatten", sub {
      $CT->captures([run => ['--flatten', '--output=dump', @args]]
                    , qq|{'result' => {'x' => 3}}\n{'result' => [{'y' => 8},undef,[1,'foo',2,3]]}\n|);
    };

    subtest "--scalar", sub {
      $CT->captures([run => ['--scalar', '--output=dump', @args]]
                    , qq|[{'x' => 3},[{'y' => 8},undef,[1,'foo',2,3]]]\n|);
    };

    subtest "--scalar --flatten", sub {
      $CT->captures([run => ['--scalar', '--flatten', '--output=dump', @args]]
                    , qq|{'x' => 3}\n[{'y' => 8},undef,[1,'foo',2,3]]\n|);
    };

  };

  subtest "--output=yaml", sub {
    $CT->captures([run => ['--output=yaml', @args]], <<'END');
--- 
- 
  result: 
    x: 3
- 
  result: 
    - 
      "y": 8
    - ~
    - 
      - 1
      - foo
      - 2
      - 3
END

  };

  subtest "--output=tsv", sub {
    $CT->captures([run => ['--output=tsv', @args]]
                  , qq|{"result":{"x":3}}\t{"result":[{"y":8},null,[1,"foo",2,3]]}\n|);
  };

  subtest "--output=raw", sub {
    require Math::BigInt;
    $CT->captures([run => ['--output=raw', '--no-exit-code'
                           , cli_eval => 'Math::BigInt->new(30)']]
                  , 30);
  };
};

subtest "cli_write_fh_as_... APIs", sub {

  $CT->captures([run => [qw/--no-exit-code --output=ltsv cli_array/
                         , qq|{"a":{"foo":"bar"},"b":[1,"baz"]}|
                         , qq|{"c":3,"d":8}|
                       ]]
                , qq|a:{"foo":"bar"}\tb:[1,"baz"]\nc:3\td:8\n|);

};

subtest "cli_read_file APIs", sub {
  my $test = CallTester->make_tester(MyApp1->new);

  $test->returns_in_list(
    [cli_read_file => "$FindBin::Bin/cli_json_input.d/input.txt"]
    , ["foo bar baz", "xx yy zz  ", "a b c"]);

  $test->returns_in_scalar(
    [cli_read_file => "$FindBin::Bin/cli_json_input.d/input.txt"]
    , ["foo bar baz", "xx yy zz  ", "a b c"]);

  $test->returns_in_list(
    [cli_read_file => "$FindBin::Bin/cli_json_input.d/no_extension"]
    , ["foo\nbar\nbaz"]);

  $test->returns_in_list(
    [cli_read_file => "$FindBin::Bin/cli_json_input.d/input.yml"]
    , [[{foo => "bar", "baz" => 3}, {x => 8}]]);

  $test->returns_in_list(
    [cli_read_file => "$FindBin::Bin/cli_json_input.d/input.yaml"]
    , [{foo => "bar", "baz" => 3}, {x => 8, y => 3}]);


  $test->returns_in_list(
    [cli_read_file => "$FindBin::Bin/cli_json_input.d/keybindings.json"]
    , [[{'when' => 'editorTextFocus','key' => 'ctrl+b','command' => 'cursorLeft'},{'key' => 'ctrl+f','command' => 'cursorRight','when' => 'editorTextFocus'},{'command' => 'cursorDown','key' => 'ctrl+n','when' => 'editorTextFocus'},{'when' => 'editorTextFocus && !inQuickOpen','key' => 'ctrl+p','command' => 'cursorUp'},{'when' => 'editorTextFocus','command' => 'cursorHome','key' => 'ctrl+a'},{'when' => 'editorTextFocus','command' => 'cursorEnd','key' => 'ctrl+e'},{'command' => 'deleteLeft','key' => 'ctrl+h'},{'command' => 'deleteRight','key' => 'ctrl+d','when' => 'editorTextFocus'},{'key' => 'ctrl+q','command' => 'cursorWordLeft','when' => 'editorTextFocus'},{'when' => 'editorTextFocus','key' => 'ctrl+t','command' => 'cursorWordRight'},{'when' => 'editorFocus && !findWidgetVisible && editorLangId == \'fsharp\'','key' => 'ctrl+alt+enter','command' => 'fsi.SendFile'}]]);

    $test->returns_in_list(
      [cli_read_file => "$FindBin::Bin/cli_json_input.d/basic-js.json"]
      , [{url => "http://localhost", key2 => [0..4]
          , "key3" => {a => "foo/*bar baz*/", b => 2}}]
    );
};

done_testing();
