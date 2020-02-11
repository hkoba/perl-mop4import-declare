#!/usr/bin/env perl
package MOP4Import::CLI::Completer;
use strict;
use warnings;

use MOP4Import::Base::CLI_JSON -as_base
  , [fields => [separator => default => "\n"]]
  ;

use MOP4Import::FieldSpec;
use MOP4Import::Util qw/fields_hash fields_array/;
use MOP4Import::Util::FindMethods;

use Module::Runtime ();

use MOP4Import::Util::ResolveSymlinks;

use MOP4Import::Types
  ZshParams => [[fields => qw/pmfile words CURRENT BUFFER CURSOR/]]
  ;

sub onconfigure_zero {
  (my MY $self) = @_;
  $self->{separator} = "\0";
}

sub cmd_zsh_arguments {
  (my MY $self, my @args) = @_;
  my @completion = $self->zsh_arguments(@args);
  print join($self->{separator}, @completion);
}

sub zsh_arguments {
  (my MY $self, my %opts) = @_;

  my ZshParams $opts = \%opts;

  my (@args) = @{$opts->{words}};

  my ($targetClass, $has_shbang) = $self->load_module_from_pm($opts->{pmfile})
    or Carp::croak "Can't extract class name from $opts->{pmfile}";

  # my @opts = $self->cli_parse_opts(\@args);

  # if (($opts->{CURRENT} - 1) <= @opts/2) {

  my @opts = map {
      my ($implClass, @specs) = @$_;
      map {
        my FieldSpec $spec = $_;
        "--$spec->{name}=-". ($spec->{doc} ? "[$spec->{doc}]" : "");
      } @specs;
    } MOP4Import::Base::CLI::cli_group_options($targetClass);

  my @methods = FindMethods($targetClass, sub {s/^(?:cmd_)?//});

  (@opts, "*:argument:(".join(" ", @methods).")");
}

sub load_module_from_pm {
  (my MY $self, my $pmFile) = @_;

  my ($modname, $libpath, $has_shbang) = $self->find_package_from_pm($pmFile)
    or Carp::croak "Can't find module name and library root from $pmFile'";

  {
    local @INC = ($libpath, @INC);
    Module::Runtime::require_module($modname);
  }

  wantarray ? ($modname, $has_shbang) : $modname;
}

sub find_package_from_pm {
  (my MY $self, my $pmFile) = @_;

  my $realFn = MOP4Import::Util::ResolveSymlinks::normalize($pmFile);
  $realFn =~ s/\.\w+\z//;

  my @dir = $self->splitdir($realFn);

  local $_ = $self->cli_read_file__($pmFile);

  my $has_shbang = m{^\#!};

  while (/(?:^|\n) [\ \t]*     (?# line beginning + space)
	  package  [\n\ \t]+   (?# newline is allowed here)
	  ([\w:]+)             (?# module name)
	  \s* [;\{]            (?# statement or block)
	 /xsg) {
    my ($modname) = $1;

    # Tail of $modname should be equal to it's rootname.
    if (my $libprefix = $self->test_modname_with_path($modname, \@dir)) {
      return wantarray ? ($modname, $libprefix, $has_shbang) : $modname;
    }
  }
  return;
}

sub test_modname_with_path {
  (my MY $self, my ($modname, $pathlist)) = @_;
  my @modpath = split /::/, $modname;
  shift @modpath while @modpath and $modpath[0] eq '';
  my @copy = @$pathlist;
  do {
    if (pop(@copy) ne pop(@modpath)) {
      return;
    }
  } while (@copy and @modpath);
  if (@modpath) {
    return;
  }
  elsif (@copy) {
    File::Spec->catdir(@copy)
  }
}

sub splitdir {
  (my MY $self, my $fn) = @_;
  File::Spec->splitdir($fn);
}

MY->cli_run(\@ARGV, {0 => 'zero'}) unless caller;

1;
