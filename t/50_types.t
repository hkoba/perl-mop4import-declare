#!/usr/bin/env perl
# -*- mode: perl; coding: utf-8 -*-
#----------------------------------------
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;
use FindBin; BEGIN { do "$FindBin::Bin/t_lib.pl" }

use Test::Kantan;

use rlib qw!../..!;

use MOP4Import::t::t_lib qw/no_error expect_script_error/;

describe "MOP4Import::Types", sub {

  describe "require MOP4Import::Types", sub {
    it "should loaded correctly", sub {
      ok { require MOP4Import::Types };
      # This will help debugging.
    };
  };

  describe "Error detection for odd number of args", sub {
    it "should raise error", expect_script_error q{
package TestErr1;
use MOP4Import::Types qw/Foo/;
}
      , to_match => qr/^Odd number of arguments!/;
  };

  describe "use ... type => []", sub {
    it "should have no error", no_error q{
package Test0; use MOP4Import::Types Foo => [], Bar => [];
};

    it "should define inner classes Foo, Bar in Test0", sub {
      ok {Test0->Foo eq "Test0::Foo"};
      ok {Test0->Bar eq "Test0::Bar"};
    };
  };

  describe "use ... type => [[fields => ...]]", sub {

    it "should have no error", no_error <<'END';
package Test1;
use MOP4Import::Types
   Foo => [[fields => qw/foo bar baz/]]
  ,Bar => [[fields =>
             [fst => doc => "first field", default => '1st']
           , [snd => doc => "second field", default => '2nd']]];
1;
END

    it "should define inner classes Foo, Bar in Test1", sub {
      ok {Test1->Foo eq "Test1::Foo"};
      ok {Test1->Bar eq "Test1::Bar"};
    };

    it "should define inner classes Foo, Bar as constant sub", no_error q{
package Test1;
sub test1 { (my Foo $foo) = @_; }
sub test_bar1 { (my Bar $bar) = @_; }
};

    it "should define field Foo->{foo,bar,baz}, Bar->{fst,snd}", no_error q{
package Test1; sub test2 {
  (my Foo $foo) = @_;
  $foo->{foo} + $foo->{bar} + $foo->{baz};
}
sub test_bar2 {
  (my Bar $bar) = @_;
  $bar->{fst} + $bar->{snd};
}
};

    it "should generate accessors", sub {
      my $foo = bless(+{foo => 1, bar => 2, baz => 3}, Test1->Foo);
      ok {$foo->foo eq 1};
      ok {$foo->foo + $foo->bar == $foo->baz};
      my $bar = bless(+{fst => "foo", snd => "bar"}, Test1->Bar);
      ok {$bar->fst eq "foo"};
      ok {$bar->snd eq "bar"};
    };

    it "should define Bar->default_fst, default_snd methods", sub {
      ok {Test1->Bar->default_fst eq '1st'};
      ok {Test1->Bar->default_snd eq '2nd'};
    };

    it "should detect spell miss for Foo->{foooo}"
      , expect_script_error q{
package Test1; sub test3 {
  (my Foo $foo) = @_;
  $foo->{foooo}
}
}
	, to_match =>
	  qr/^No such class field "foooo" in variable \$foo of type Test1::Foo/
	    ;
  };

  describe "subtypes", sub {
    it "should have no error", no_error q{
package Test2;
use MOP4Import::Types
   Base => [
     [fields => qw/name/]
    ,[subtypes =>
       Foo => [[fields => qw/foo/]
               , [subtypes =>
                    Bar => [[fields => qw/bar/]]
                 ]
              ]
     , Baz => [[fields => qw/baz/]]
     ]
   ];
1;
};

    describe "class hierarchy", sub {
      it "should define correct class hierarchy", no_error q{
package Test2;
sub test1 {
  (my $pkg, my Foo $foo, my Bar $bar, my Baz $baz) = @_;
$foo->{foo} = $foo->{name};
$baz->{baz} = $baz->{name};

$bar->{foo} = $foo->{name};
$bar->{bar} = $baz->{name};
  [$foo, $bar, $baz]
}
};

      it "works as expected", sub {
	expect(Test2->test1(+{name => 'foo'}, +{name => 'bar'}, +{name => 'baz'}))
	  ->to_be([{name => 'foo', foo => 'foo'}
		   , {name => 'bar', foo => 'foo', bar => 'baz'}
		   , {name => 'baz', baz => 'baz'}]);
      };
    };
  };
};

done_testing();
