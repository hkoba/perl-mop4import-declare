package MOP4Import::Types;
use strict;
use warnings FATAL => qw/all/;
use Carp;

use MOP4Import::Declare -as_base, qw/lexpand/;

use constant DEBUG => $ENV{DEBUG_MOP};

sub import {
  my $mypack = shift;
  my $callpack = caller;
  $mypack->declare_types($callpack, @_);
}

sub declare_types {
  my ($mypack, $callpack, @decls) = @_;

  foreach my $decl (@decls) {
    my ($name, @spec) = @$decl;

    if (my $sub = $callpack->can($name)) {
      unshift @spec, [base => $sub->($callpack)];
    }

    my $innerClass = join("::", $callpack, $name);

    $mypack->declare_alias($callpack, $name, $innerClass);

    foreach my $spec (@spec) {
      my ($pragma, @args) = @$spec;
      print STDERR "declaring $pragma for $innerClass\n" if DEBUG;
      $mypack->dispatch_declare_pragma_in($innerClass, $pragma, @args);
    }
  }
}

1;
