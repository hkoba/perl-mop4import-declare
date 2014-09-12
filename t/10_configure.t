use strict;
use Test::Kantan;

use rlib qw!../..!;

use MOP4Import::t::t_lib qw/no_error expect_script_error/;

describe "MOP4Import::Base::Configure", sub {
  describe "use ... -as_base, [fields => qw/aquarius scorpio gemini/]", sub {

    it "should have no error", no_error <<'END';
package Zodiac1;
use MOP4Import::Base::Configure -as_base, -inc
    , [fields => qw/aquarius scorpio _scorpio_cnt gemini _gemini_cnt/];

sub onconfigure_scorpio {
  (my __PACKAGE__ $self, my $value) = @_;
  $self->{_scorpio_cnt}++;
  $self->{scorpio} = $value;
}

sub onconfigure_twins {
  (my __PACKAGE__ $self, my $value) = @_;
  $self->{_gemini_cnt}++;
  $self->{gemini} = $value;
}

1;
END

    it "should make Zodiac1 as a subclass of ..Configure", sub {
      ok {Zodiac1->isa('MOP4Import::Base::Configure')};
    };

    it "should make define MY alias in Zodiac1", sub {
      ok {Zodiac1->MY eq 'Zodiac1'};
    };

    it "should define MY as constant sub", no_error <<'END';
package Zodiac1; sub test { (my MY $foo) = @_; }
END

    it "should define field Zodiac1->{aquarius,scorpio,gemini}"
      , no_error <<'END';
package Zodiac1; sub test2 {
  (my MY $foo) = @_;
  $foo->{aquarius} + $foo->{scorpio}  + $foo->{gemini};
}
END

    it "should detect spell miss for Zodiac1->{aquariusss}"
      , expect_script_error <<'END'
package Zodiac1; sub test3 {
  (my MY $foo) = @_;
  $foo->{aquariusss}
}
END
	, to_match =>
	  qr/^No such class field "aquariusss" in variable \$foo of type Zodiac1/;

    it "should accept new(key => value...)", sub {
       my $obj = Zodiac1->new
           (aquarius => "foo", scorpio => "bar", gemini => "baz");
       ok {$obj->aquarius eq "foo"};
       ok {$obj->scorpio  eq "bar"};
       ok {$obj->gemini   eq "baz"};
    };

    it "should accept configure(key => value...)", sub {
       my $obj = Zodiac1->new->configure
           (aquarius => "foo", scorpio => "bar", gemini => "baz");
       ok {$obj->aquarius eq "foo"};
       ok {$obj->scorpio  eq "bar"};
       ok {$obj->gemini   eq "baz"};
    };

    it "should call onconfigure_zzz hook ", sub {
       my $obj = Zodiac1->new(scorpio => "foo", twins => "bar")->configure
           (scorpio => "baz", twins => "qux");
       ok {$obj->scorpio  eq "baz"};
       ok {$obj->{_scorpio_cnt} == 2};
       ok {$obj->gemini   eq "qux"};
       ok {$obj->{_gemini_cnt} == 2};
    };
  };

  describe "package MyZodiac {use Zodiac1 -as_base}", sub {
    it "should have no error", no_error <<'END';
package MyZodiac; use Zodiac1 -as_base;
END

    it "should inherit Zodiac1", sub {
      ok {MyZodiac->isa('Zodiac1')};
    };
  };
};

done_testing();
