# -*- coding: utf-8 -*-
package MOP4Import::Declare;
use 5.010;
use strict;
use warnings FATAL => qw/all/;
our $VERSION = '0.01';
use Carp;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Util;

our %FIELDS; # To kill warning.

sub import {
  my ($myPack, @decls) = @_;

  my $callpack = caller;

  @decls = $myPack->default_exports unless @decls;

  $myPack->dispatch_declare_in($callpack, @decls);
}

#
# This serves as @EXPORT
#
sub default_exports {
  qw/-as_base/;
}

sub dispatch_declare_in {
  my ($myPack, $callpack, @decls) = @_;

  foreach my $declSpec (@decls) {
    if (not ref $declSpec) {

      $myPack->declare_import_in($callpack, $declSpec);

    } elsif (ref $declSpec eq 'ARRAY') {

      $myPack->dispatch_declare_pragma_in($callpack, @$declSpec);

    } elsif (ref $declSpec eq 'CODE') {

      $declSpec->($myPack, $callpack);

    } else {
      croak "Invalid declaration spec: $declSpec";
    }
  }
}

sub declare_import_in {
  my ($myPack, $callpack, $declSpec) = @_;

  my ($name, $exported);

  if ($declSpec =~ /^-(\w+)$/) {

    return $myPack->dispatch_declare_pragma_in($callpack, $1);

  } elsif ($declSpec =~ /^\*(\w+)$/) {
    ($name, $exported) = ($1, globref($myPack, $1));
  } elsif ($declSpec =~ /^\$(\w+)$/) {
    ($name, $exported) = ($1, *{globref($myPack, $1)}{SCALAR});
  } elsif ($declSpec =~ /^\%(\w+)$/) {
    ($name, $exported) = ($1, *{globref($myPack, $1)}{HASH});
  } elsif ($declSpec =~ /^\@(\w+)$/) {
    ($name, $exported) = ($1, *{globref($myPack, $1)}{ARRAY});
  } elsif ($declSpec =~ /^\&(\w+)$/) {
    ($name, $exported) = ($1, *{globref($myPack, $1)}{CODE});
  } elsif ($declSpec =~ /^(\w+)$/) {
    ($name, $exported) = ($1, globref($myPack, $1));
  } else {
    croak "Invalid import spec: $declSpec";
  }

  *{globref($callpack, $name)} = $exported;
}

sub dispatch_declare_pragma_in {
  my ($myPack, $callpack, $pragma, @args) = @_;
  if (my $sub = $myPack->can("declare_$pragma")) {
    $sub->($myPack, $callpack, @args);
  } else {
    croak "Unknown pragma '$pragma' in $callpack";
  }
}

sub declare_base {
  my ($myPack, $callpack, @base) = @_;

  push @{*{globref($callpack, 'ISA')}}, @base;

  $myPack->declare_fields($callpack);
}

sub declare_as_base {
  my ($myPack, $callpack, @fields) = @_;

  push @{*{globref($callpack, 'ISA')}}, $myPack;

  $myPack->declare_fields($callpack, @fields) if @fields;

  _declare_constant_in($callpack, MY => $callpack, 1);
}

sub declare_inc {
  my ($myPack, $callpack) = @_;
  $callpack =~ s{::}{/}g;
  $INC{$callpack . '.pm'} = 1;
}

sub _declare_constant_in {
  my ($callpack, $name, $value, $or_ignore) = @_;

  my $my_sym = globref($callpack, $name);
  if (*{$my_sym}{CODE}) {
    return if $or_ignore;
    croak "constant ${callpack}::$name is already defined";
  }

  *$my_sym = sub () {$value};
}

sub declare_fields {
  my ($mypack, $callpack, @fields) = @_;

  my $extended = fields_hash($callpack);

  # Import all fields from super class
  foreach my $super_class (@{*{globref($callpack, 'ISA')}{ARRAY}}) {
    my $super = *{globref($super_class, 'FIELDS')}{HASH};
    next unless $super;
    foreach my $name (keys %$super) {
      next if defined $extended->{$name};
      print STDERR "Field $callpack.$name is inherited from $super_class.\n"
	if DEBUG;
      $extended->{$name} = $super->{$name}; # XXX: clone?
    }
  }

  foreach my $spec (@fields) {
    my ($name, @rest) = ref $spec ? @$spec : $spec;
    my $has_getter = $name =~ s/^\^//;
    print STDERR "Field $callpack.$name is declared.\n" if DEBUG;
    $extended->{$name} = \@rest; # XXX: should have better object.
    if ($has_getter) {
      *{globref($callpack, $name)} = sub { $_[0]->{$name} };
    }
  }

  $callpack; # XXX:
}

sub declare_alias {
  my ($myPack, $callpack, $name, $alias) = @_;
  *{globref($callpack, $name)} = sub () {$alias};
}


1;
__END__

=head1 NAME

MOP4Import::Declare - map import args to declare_... method calls.

=head1 SYNOPSIS

  #-------------------
  # To implement MOP4Import, just use this like:

  package YourModule;
  use MOP4Import::Declare -as_base;

  # and define what you want as "declare_..." method.
  sub declare_foo {
    my ($myPack, $callpack) = @_;
  }

  sub declare_bar {
    my ($myPack, $callpack, $x, $y, @z) = @_;
  }

  #-------------------
  # Then in user's code:

  package MyApp;
  use YourModule -foo, [bar => 1,2,3,4];

  # Above will be mapped to:
  #
  #   YourMoudle->declare_foo('MyApp');
  #   YourMoudle->declare_bar('MyApp', 1,2,3,4);


=head1 DESCRIPTION

MOP4Import::Declare is

=head1 AUTHOR

KOBAYASHI, Hiroaki E<lt>hkoba@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
