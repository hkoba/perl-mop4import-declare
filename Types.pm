package MOP4Import::Types;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;

use MOP4Import::Declare -as_base, qw/Opts/;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

sub import {
  my $myPack = shift;
  my Opts $opts = Opts->new([caller]);
  if (@_ and ref $_[0] eq 'HASH') {
    my $o = shift;
    $opts->{$_} = $o->{$_} for keys %$o;
  }
  $myPack->declare_types($opts, $opts->{destpkg}, @_);
}

sub declare_types {
  (my $myPack, my Opts $opts, my $callpack, my (@pairs)) = @_;

  unless (@pairs % 2 == 0) {
    croak "Odd number of arguments!";
  }

  while (my ($name, $speclist) = splice @pairs, 0, 2) {
    my @spec = @$speclist;

    if ($opts->{basepkg}) {
      unshift @spec, [base => $opts->{basepkg}];
    } elsif (my $sub = $opts->{destpkg}->can($name)) {
      unshift @spec, [base => $sub->($opts->{destpkg})];
    }

    my $innerClass = join("::", $opts->{destpkg}, $name);

    # Note: if $innerClass has no actual definitions, you will get errors like:
    #   No such class Foo at (eval 45) line 1, near "(my Foo"
    #
    $myPack->declare_alias($opts, $callpack, $name, $innerClass);

    $myPack->dispatch_declare($opts->with_objpkg($innerClass)
			      , $callpack
			      , @spec);
  }
}

sub declare_subtypes {
  (my $myPack, my Opts $opts, my $callpack, my @specs) = @_;
  $myPack->declare_types($opts->with_basepkg($opts->{objpkg})
			 , $callpack
			 , @specs);
}

1;
