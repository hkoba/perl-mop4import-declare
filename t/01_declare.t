use strict;
use Test::Kantan;

use rlib qw!../..!;

# Tcl style [catch {code}]
sub catch (&) {
  my ($code) = @_;
  local $@;
  eval {$code->()};
  $@;
};

sub no_error ($) {
  my ($script) = @_;
  sub {
    expect(catch { eval $script })->to_be('');
  };
}

describe "MOP4Import::Declare", sub {
  describe "use ... -as_base", sub {

    it "should have no error", no_error <<'END';
package Tarot1;
use MOP4Import::Declare -as_base, [fields => qw/pentacle chariot tower/];
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
package Test1; sub test2 {
  (my MY $foo) = @_;
  $foo->{pentacle} + $foo->{chariot} + $foo->{tower};
}
END

    it "should detect spell miss for Tarot1->{towerrr}", sub {
      expect(do {eval <<'END'; $@})
package Tarot1; sub test3 {
  (my MY $foo) = @_;
  $foo->{towerrr}
}
END
	->to_match
	  (qr/^No such class field "towerrr" in variable \$foo of type Tarot1/);
    };
  };
};

done_testing();
