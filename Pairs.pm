package MOP4Import::Pairs;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;

use MOP4Import::Declare -as_base, qw/Opts/;
use MOP4Import::Util qw/terse_dump/;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

sub dispatch_pairs_as {
  (my $myPack, my $pragma, my Opts $opts, my $callpack, my (@pairs)) = @_;

  #
  # Process leading non-pair pragmas. (ARRAY and -pragma)
  #
  while (@pairs) {
    if (ref $pairs[0] eq 'CODE') {
      (shift @pairs)->($myPack, $opts, $callpack);
    } elsif ($pairs[0] =~ /^-([A-Za-z]\w*)$/) {
      shift @pairs;
      $myPack->dispatch_declare_pragma($opts, $callpack, $1);
    } else {
      last;
    }
  }

  unless (@pairs % 2 == 0) {
    croak "Odd number of arguments!: ".terse_dump(\@pairs);
  }

  my $sub = $myPack->can("declare_$pragma")
    or croak "Unknown declare pragma: $pragma";

  while (my ($name, $speclist) = splice @pairs, 0, 2) {
    print STDERR " dispatching 'declare_$pragma' for pair("
      , terse_dump($name, $speclist)
      , $myPack->file_line_of($opts), "\n" if DEBUG;

    $sub->($myPack, $opts, $callpack, $name, @$speclist);
  }
}

1;
