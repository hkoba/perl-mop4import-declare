package MOP4Import::Types;
use 5.010;
use strict;
use warnings FATAL => qw/all/;
use Carp;

use MOP4Import::Declare -as_base;
use MOP4Import::Opts qw/Opts with_objpkg with_basepkg/;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

sub import {
  my $myPack = shift;
  $myPack->declare_types(Opts->new(scalar(caller))
			 , @_);
}

sub declare_types {
  (my $myPack, my Opts $opts, my (@pairs)) = @_;

  unless (@pairs % 2 == 0) {
    croak "Odd number of arguments!";
  }

  while (my ($name, $speclist) = splice @pairs, 0, 2) {
    my @spec = @$speclist;

    if (my $sub = $opts->{destpkg}->can($name)) {
      unshift @spec, [base => $sub->($opts->{destpkg})];
    } elsif ($opts->{basepkg}) {
      unshift @spec, [base => $opts->{basepkg}];
    }

    my $innerClass = join("::", $opts->{destpkg}, $name);

    # Note: if $innerClass has no actual definitions, you will get errors like:
    #   No such class Foo at (eval 45) line 1, near "(my Foo"
    #
    $myPack->declare_alias($opts, $name, $innerClass);

    $myPack->dispatch_declare($opts->with_objpkg($innerClass)
			      , @spec);
  }
}

sub declare_subtypes {
  (my $myPack, my Opts $opts, my @specs) = @_;
  $myPack->declare_types($opts->with_basepkg($opts->{objpkg})
			 , @specs);
}

1;
