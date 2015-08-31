# -*- coding: utf-8 -*-
package MOP4Import::Declare;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
our $VERSION = '0.01';
use Carp;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Opts;
use MOP4Import::Util;
use MOP4Import::FieldSpec;

our %FIELDS;

sub import {
  my ($myPack, @decls) = @_;

  @decls = $myPack->default_exports unless @decls;

  $myPack->dispatch_declare(Opts->new(scalar caller), @decls);
}

#
# This serves as @EXPORT
#
sub default_exports {
  ();
}

sub dispatch_declare {
  (my $myPack, my Opts $opts, my (@decls)) = @_;

  foreach my $declSpec (@decls) {
    if (not ref $declSpec) {

      $myPack->declare_import($opts, $declSpec);

    } elsif (ref $declSpec eq 'ARRAY') {

      $myPack->dispatch_declare_pragma($opts, @$declSpec);

    } elsif (ref $declSpec eq 'CODE') {

      $declSpec->($myPack, $opts);

    } else {
      croak "Invalid declaration spec: $declSpec";
    }
  }
}

sub declare_import {
  (my $myPack, my Opts $opts, my ($declSpec)) = @_;

  my ($name, $exported);

  if ($declSpec =~ /^-(\w+)$/) {

    return $myPack->dispatch_declare_pragma($opts, $1);

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

  print STDERR "Declaring $name in $opts->{destpkg} as "
    .terse_dump($exported)."\n" if DEBUG;

  *{globref($opts->{destpkg}, $name)} = $exported;
}

sub dispatch_declare_pragma {
  (my $myPack, my Opts $opts, my ($pragma, @args)) = @_;
  if (my $sub = $myPack->can("declare_$pragma")) {
    $sub->($myPack, $opts, @args);
  } else {
    croak "Unknown pragma '$pragma' in $opts->{destpkg}";
  }
}

sub declare_base {
  (my $myPack, my Opts $opts, my (@base)) = @_;

  print STDERR "Inheriting ".terse_dump(@base)." from $opts->{objpkg}\n"
    if DEBUG;

  push @{*{globref($opts->{objpkg}, 'ISA')}}, @base;

  $myPack->declare_fields($opts);
}

sub declare_as_base {
  (my $myPack, my Opts $opts, my (@fields)) = @_;

  print STDERR "Inheriting $myPack from $opts->{objpkg}\n"
    if DEBUG;

  push @{*{globref($opts->{objpkg}, 'ISA')}}, $myPack;

  $myPack->declare_fields($opts, @fields);

  $myPack->declare_constant($opts, MY => $opts->{objpkg}, or_ignore => 1);
}

sub declare_as {
  (my $myPack, my Opts $opts, my ($name)) = @_;

  unless (defined $name and $name ne '') {
    croak "Usage: use ${myPack} [as => NAME]";
  }

  $myPack->declare_constant($opts, $name => $myPack);
}

sub declare_inc {
  (my $myPack, my Opts $opts, my ($pkg)) = @_;
  $pkg //= $opts->{objpkg};
  $pkg =~ s{::}{/}g;
  $INC{$pkg . '.pm'} = 1;
}

sub declare_constant {
  (my $myPack, my Opts $opts, my ($name, $value, %opts)) = @_;

  my $my_sym = globref($opts->{objpkg}, $name);
  if (*{$my_sym}{CODE}) {
    return if $opts{or_ignore};
    croak "constant $opts->{objpkg}::$name is already defined";
  }

  *$my_sym = sub () {$value};
}

sub declare_fields {
  (my $myPack, my Opts $opts, my (@fields)) = @_;

  my $extended = fields_hash($opts->{objpkg});
  my $fields_array = fields_array($opts->{objpkg});

  # Import all fields from super class
  foreach my $super_class (@{*{globref($opts->{objpkg}, 'ISA')}{ARRAY}}) {
    my $super = *{globref($super_class, 'FIELDS')}{HASH};
    next unless $super;
    foreach my $name (keys %$super) {
      next if defined $extended->{$name};
      print STDERR "Field $opts->{objpkg}.$name is inherited "
	. "from $super_class.\n" if DEBUG;
      $extended->{$name} = $super->{$name}; # XXX: clone?
      push @$fields_array, $name;
    }
  }

  foreach my $spec (@fields) {
    my ($name, @rest) = ref $spec ? @$spec : $spec;
    print STDERR "Field $opts->{objpkg}.$name is declared.\n" if DEBUG;
    $extended->{$name} = $myPack->FieldSpec->new(@rest);
    push @$fields_array, $name;
    if ($name =~ /^[a-z]/i) {
      *{globref($opts->{objpkg}, $name)} = sub { $_[0]->{$name} };
    }
  }

  $opts->{objpkg}; # XXX:
}

sub declare_alias {
  (my $myPack, my Opts $opts, my ($name, $alias)) = @_;
  print STDERR "Declaring alias $name in $opts->{destpkg} as $alias\n" if DEBUG;
  my $sym = globref($opts->{destpkg}, $name);
  if (*{$sym}{CODE}) {
    croak "Subroutine (alias) $opts->{destpkg}::$name redefined";
  }
  *$sym = sub () {$alias};
}


1;
__END__

=head1 NAME

MOP4Import::Declare - map import args to declare_... method calls.

=head1 SYNOPSIS

  #-------------------
  # To implement MOP4Import, just use this like:

  package YourModule;
  use MOP4Import::Declare -as_base, qw/Opts/;

  # and define what you want as "declare_..." method.
  sub declare_foo {
    (my $myPack, my Opts $opts) = @_;
  }

  sub declare_bar {
    (my $myPack, my Opts $opts, my ($x, $y, @z)) = @_;
  }

  #-------------------
  # Then in user's code:

  package MyApp;
  use YourModule -foo, [bar => 1,2,3,4];

  # Above will be mapped to:
  #
  #   YourMoudle->declare_foo($opts, 'MyApp');
  #   YourMoudle->declare_bar($opts, 'MyApp', 1,2,3,4);


=head1 DESCRIPTION

MOP4Import::Declare is...

=head1 AUTHOR

KOBAYASHI, Hiroaki E<lt>hkoba@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
