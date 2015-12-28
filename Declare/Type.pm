package MOP4Import::Declare::Type;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;

use MOP4Import::Declare -as_base, qw/Opts/;
use MOP4Import::Pairs -as_base;

sub declare_type {
  (my $myPack, my Opts $opts, my $callpack, my ($name, @spec)) = @_;

  if ($opts->{extending}) {
    my $sub = $opts->{destpkg}->can($name)
      or croak "Can't find base class $name in parents of $opts->{destpkg}";
    unshift @spec, [base => $sub->($opts->{destpkg})];
  } elsif ($opts->{basepkg}) {
    unshift @spec, [base => $opts->{basepkg}];
  }

  $myPack->declare___inner_class_in($opts, $callpack
				    , $opts->{destpkg}, $name, @spec);
}

#
# Create a new class $extended, deriving from $callpack->SUPER::$extended,
# in $callpack.
#
sub declare_extend {
  (my $myPack, my Opts $opts, my $callpack, my ($extended, @spec)) = @_;

  my $sub = $opts->{destpkg}->can($extended)
    or croak "Can't find base class $extended in parents of $opts->{destpkg}";

  $myPack->declare___inner_class_in($opts, $callpack
				    , $opts->{destpkg}, $extended
				    , [base => $sub->($opts->{destpkg})]
				    , @spec);
}

sub declare___inner_class_in {
  (my $myPack, my Opts $opts, my $callpack, my ($destpkg, $name, @spec)) = @_;

  my $innerClass = join("::", $destpkg, $name);

  $myPack->declare_alias($opts, $callpack, $name, $innerClass);

  if (@spec) {
    $myPack->dispatch_declare($opts->with_objpkg($innerClass)
			      , $callpack
			      , @spec);
  } else {
    # Note: To make sure %FIELDS is defined. Without this we get:
    #   No such class Foo at (eval 45) line 1, near "(my Foo"
    #
    $myPack->declare_fields($opts->with_objpkg($innerClass), $callpack);
  }
}

sub declare_subtypes {
  (my $myPack, my Opts $opts, my $callpack, my @specs) = @_;

  $myPack->dispatch_pairs_as(type => $opts->with_basepkg($opts->{objpkg})
			     , $callpack, @specs);
}

1;
