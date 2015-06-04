use strict;
use Test::Kantan;

use rlib qw!../..!;

use MOP4Import::t::t_lib qw/no_error expect_script_error catch/;

describe "MOP4Import::Declare", sub {
  describe "use ... -as_base", sub {

    it "should have no error", no_error <<'END';
package Tarot1;
use MOP4Import::Declare -as_base, [fields => qw/pentacle chariot tower
                                                _hermit/];
$INC{'Tarot1.pm'} = 1;
1;
END

    it "should make Tarot1 as a subclass of MOP4Import::Declare", sub {
      ok {Tarot1->isa('MOP4Import::Declare')};
    };

    it "should make define MY alias in Tarot1", sub {
      ok {Tarot1->MY eq 'Tarot1'};
    };

    it "should define MY as constant sub", no_error <<'END';
package Tarot1; sub test { (my MY $foo) = @_; }
END

    it "should define field Tarot1->{pentacle,chariot,tower}", no_error <<'END';
package Tarot1; sub test2 {
  (my MY $foo) = @_;
  $foo->{pentacle} + $foo->{chariot} + $foo->{tower} + $foo->{_hermit};
}
END

    it "should detect spell miss for Tarot1->{towerrr}"
      , expect_script_error <<'END'
package Tarot1; sub test3 {
  (my MY $foo) = @_;
  $foo->{towerrr}
}
END
	, to_match =>
	  qr/^No such class field "towerrr" in variable \$foo of type Tarot1/;

    it "should create getters automatically", sub {
      my $obj = bless {pentacle => "coin", chariot => "VII", tower => "XVI"}
	, 'Tarot1';
      ok {$obj->pentacle eq "coin"};
      ok {$obj->chariot eq "VII"};
      ok {$obj->tower eq "XVI"};
    };

    it "should not create getters for _private fields", sub {
      my $obj = bless {}, 'Tarot1';
      expect(catch {$obj->_hermit})->to_match(qr/^Can't locate object method "_hermit" via package "Tarot1"/);
    };
  };

  describe "use YOUR_CLASS", sub {
    it "should be used without error", no_error <<'END';
package TarotUser; use Tarot1;
END

    it "should *not* inherit YOUR_CLASS by default", sub {
      ok {@TarotUser::ISA == 0};
    };
  };

  describe "use YOUR_CLASS -as_base", sub {
    it "should have no error", no_error <<'END';
package Tarot2; use Tarot1 -as_base;
END

    it "should make Tarot2 as a subclass of Tarot1", sub {
      ok {Tarot2->isa('Tarot1')};
    };

    it "should make Tarot2 as a subclass of MOP4Import::Declare", sub {
      ok {Tarot2->isa('MOP4Import::Declare')};
    };

    it "should make define MY alias in Tarot2", sub {
      ok {Tarot2->MY eq 'Tarot2'};
    };

    it "should inherit fields from Tarot1", no_error <<'END';
package Tarot2; sub test2 {
  (my MY $foo) = @_;
  $foo->{pentacle} + $foo->{chariot} + $foo->{tower} + $foo->{_hermit};
}
END

    it "should detect spell miss for Tarot2->{towerrr}"
      , expect_script_error <<'END'
package Tarot2; sub test3 {
  (my MY $foo) = @_;
  $foo->{towerrr}
}
END
	, to_match =>
	  qr/^No such class field "towerrr" in variable \$foo of type Tarot2/;


  };
};

done_testing();
