package MOP4Import::Types;
use strict;
use warnings FATAL => qw/all/;
use Carp;

use MOP4Import::Declare -as_base, qw/lexpand/;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

sub import {
  my $mypack = shift;
  my $callpack = caller;
  $mypack->declare_types($callpack, @_);
}

sub declare_types {
  my ($mypack, $callpack, @pairs) = @_;

  unless (@pairs % 2 == 0) {
    croak "Odd number of arguments!";
  }

  while (my ($name, $speclist) = splice @pairs, 0, 2) {
    my @spec = @$speclist;

    if (my $sub = $callpack->can($name)) {
      unshift @spec, [base => $sub->($callpack)];
    }

    my $innerClass = join("::", $callpack, $name);

    print STDERR "declaring type $name as $innerClass\n" if DEBUG;

    $mypack->declare_alias($callpack, $name, $innerClass);

    $mypack->dispatch_declare_in($innerClass, @spec);
  }
}

sub declare_subtypes {
  shift->declare_types(@_);
}

1;
