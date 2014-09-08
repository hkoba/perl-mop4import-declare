use strict;
use Test::Kantan;

use rlib qw!../..!;

use MOP4Import::t::t_lib qw/no_error expect_script_error/;

describe "MOP4Import::Types", sub {
  describe "use ... type => [[fields => ...]]", sub {

    it "should have no error", no_error <<'END';
package Test1;
use MOP4Import::Types
   (Foo => [[fields => qw/foo bar baz/]]);
1;
END

    it "should define subtype Foo in Test1", sub {
      ok {Test1->Foo eq "Test1::Foo"};
    };

    it "should define subtype Foo as constant sub", no_error <<'END';
package Test1; sub test { (my Foo $foo) = @_; }
END

    it "should define field Foo->{foo,bar,baz}", no_error <<'END';
package Test1; sub test2 {
  (my Foo $foo) = @_;
  $foo->{foo} + $foo->{bar} + $foo->{baz};
}
END

    it "should detect spell miss for Foo->{foooo}"
      , expect_script_error <<'END'
package Test1; sub test3 {
  (my Foo $foo) = @_;
  $foo->{foooo}
}
END
	, to_match =>
	  qr/^No such class field "foooo" in variable \$foo of type Test1::Foo/
	    ;
  };
};

done_testing();
