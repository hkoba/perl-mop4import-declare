# -*- coding: utf-8 -*-
package MOP4Import::Declare;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
our $VERSION = '0.049_002';
use Carp;
use mro qw/c3/;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

print STDERR "Using MOP4Import::VERSION = $VERSION (file '"
  . __FILE__ . "')\n"
  if DEBUG and DEBUG >= 2;

use MOP4Import::Opts
  qw/
      Opts
      m4i_args
      m4i_opts
    /;
use MOP4Import::Util;
use MOP4Import::FieldSpec;

our %FIELDS;

sub import {
  my ($myPack, @decls) = @_;

  m4i_log_start() if DEBUG;

  my Opts $opts = m4i_opts([caller]);

  @decls = $myPack->default_exports unless @decls;

  $myPack->dispatch_declare($opts, $myPack->always_exports, @decls);

  m4i_log_end($opts->{callpack}) if DEBUG;
}

sub file_line_of {
  (my $myPack, my Opts $opts) = @_;
  " at $opts->{filename} line $opts->{line}";
}

#
# This serves as @EXPORT
#
sub default_exports {
  ();
}

sub always_exports {
  qw(-strict);
}

sub dispatch_declare {
  (my $myPack, my Opts $opts, my (@decls)) = m4i_args(@_);

  foreach my $declSpec (@decls) {

    croak "Undefined pragma!" unless defined $declSpec;

    if (not ref $declSpec) {

      $myPack->dispatch_import($opts, $declSpec);

    } elsif (ref $declSpec eq 'ARRAY') {

      $myPack->dispatch_declare_pragma($opts, @$declSpec);

    } elsif (ref $declSpec eq 'CODE') {

      $declSpec->($myPack, $opts);

    } else {
      croak "Invalid pragma: ".terse_dump($declSpec);
    }
  }
}

our %SIGIL_MAP = qw(* GLOB
		    $ SCALAR
		    % HASH
		    @ ARRAY
		    & CODE);

sub dispatch_import {
  (my $myPack, my Opts $opts, my ($declSpec)) = m4i_args(@_);

  my ($name, $exported);

  if ($declSpec =~ /^-([A-Za-z]\w*)$/) {

    return $myPack->dispatch_declare_pragma($opts, $1);

  } else {

    $myPack->dispatch_import_no_pragma($opts, $declSpec);
  }
}

sub dispatch_import_no_pragma {
  (my $myPack, my Opts $opts, my (@declSpec)) = m4i_args(@_);
  foreach my $declSpec (@declSpec) {
    if ($declSpec =~ /^([\*\$\%\@\&])?([A-Za-z]\w*)$/) {
      if ($1) {
        my $kind = $SIGIL_MAP{$1};
        $myPack->can("import_$kind")
          ->($myPack, $opts, $1, $kind, $2);
      } else {
        $myPack->import_NAME($opts => $2);
      }
    } else {
      croak "Invalid import spec: $declSpec";
    }
  }
}

sub import_NAME {
  (my $myPack, my Opts $opts, my ($name)) = m4i_args(@_);

  my $exported = safe_globref($myPack, $name);

  print STDERR " Declaring $name in $opts->{destpkg} as "
    .terse_dump($exported)."\n" if DEBUG;

  *{globref($opts->{destpkg}, $name)} = $exported;
}

sub import_GLOB {
  (my $myPack, my Opts $opts, my ($sigil, $kind, $name)) = m4i_args(@_);

  my $exported = safe_globref($myPack, $name);

  print STDERR " Declaring $name in $opts->{destpkg} as "
    .terse_dump($exported)."\n" if DEBUG;

  *{globref($opts->{destpkg}, $name)} = $exported;
}

sub import_SIGIL {
  (my $myPack, my Opts $opts, my ($sigil, $kind, $name)) = m4i_args(@_);

  my $exported = *{safe_globref($myPack, $name)}{$kind};

  print STDERR " Declaring $sigil$opts->{destpkg}::$name"
    . ", import from $sigil${myPack}::$name"
    . " (=".terse_dump($exported).")\n" if DEBUG;

  *{globref($opts->{destpkg}, $name)} = $exported;
}

*import_SCALAR = *import_SIGIL; *import_SCALAR = *import_SIGIL;
*import_ARRAY = *import_SIGIL; *import_ARRAY = *import_SIGIL;
*import_HASH = *import_SIGIL; *import_HASH = *import_SIGIL;
*import_CODE = *import_SIGIL; *import_CODE = *import_SIGIL;

sub dispatch_declare_pragma {
  (my $myPack, my Opts $opts, my ($pragma, @args)) = m4i_args(@_);
  if ($pragma =~ /^[A-Za-z]/
      and my $sub = $myPack->can("declare_$pragma")) {
    $sub->($myPack, $opts, @args);
  } else {
    croak "No such pragma: \`use $myPack\ [".terse_dump($pragma)."]`"
      . $myPack->file_line_of($opts);
  }
}

# You may want to override these pragrams.
sub declare_default_pragma {
  (my $myPack, my Opts $opts) = m4i_args(@_);
  $myPack->declare_c3($opts);
}

sub declare_strict {
  (my $myPack, my Opts $opts) = m4i_args(@_);
  $_->import for qw(strict warnings); # I prefer fatalized warnings, but...
}

# Not enabled by default.
sub declare_fatal {
  (my $myPack, my Opts $opts) = m4i_args(@_);
  warnings->import(qw(FATAL all NONFATAL misc));
}

sub declare_c3 {
  (my $myPack, my Opts $opts) = m4i_args(@_);
  mro::set_mro($opts->{destpkg}, 'c3');
}

sub declare_fileless_base {
  (my $myPack, my Opts $opts, my (@base)) = m4i_args(@_);

  $myPack->declare___add_isa($opts->{objpkg}, @base);

  $myPack->declare_fields($opts);
}

*declare_base = *declare_parent; *declare_base = *declare_parent;

sub declare_parent {
  (my $myPack, my Opts $opts, my (@base)) = m4i_args(@_);

  foreach my $fn (@base) {
    (my $cp = $fn) =~ s{::|'}{/}g;
    require "$cp.pm";
  }

  $myPack->declare_fileless_base($opts, @base);
}

sub declare_as_base {
  (my $myPack, my Opts $opts, my (@fields)) = m4i_args(@_);

  print STDERR "Class $opts->{objpkg} inherits $myPack\n"
    if DEBUG;

  $myPack->declare_default_pragma($opts); # strict, mro c3...

  $myPack->declare___add_isa($opts->{objpkg}, $myPack);

  $myPack->declare_fields($opts, @fields);

  $myPack->declare_constant($opts, MY => $opts->{objpkg}, or_ignore => 1);
}

sub declare___add_isa {
  my ($myPack, $objpkg, @parents) = @_;

  print STDERR "Class $objpkg extends ".terse_dump(@parents)."\n"
    if DEBUG;

  my $isa = MOP4Import::Util::isa_array($objpkg);

  my $using_c3 = mro::get_mro($objpkg) eq 'c3';

  if (DEBUG) {
    print STDERR " $objpkg (MRO=",mro::get_mro($objpkg),") ISA "
      , terse_dump(mro::get_linear_isa($objpkg)), "\n";
    print STDERR " Adding $_ (MRO=",mro::get_mro($_),") ISA "
      , terse_dump(mro::get_linear_isa($_))
      , "\n" for @parents;
  }

  my @new = grep {
    my $parent = $_;
    $parent ne $objpkg
      and not grep {$parent eq $_} @$isa;
  } @parents;

  if ($using_c3) {
    local $@;
    foreach my $parent (@new) {
      my $cur = mro::get_linear_isa($objpkg);
      my $adding = mro::get_linear_isa($parent);
      eval {
	unshift @$isa, $parent;
	# if ($] < 5.014) {
	#   mro::method_changed_in($objpkg);
	#   mro::get_linear_isa($objpkg);
	# }
      };
      if ($@) {
        croak "Can't add base '$parent' to '$objpkg' (\n"
          .  "  $objpkg ISA ".terse_dump($cur).")\n"
          .  "  Adding $parent ISA ".terse_dump($adding)
          ."\n) because of this error: " . $@;
      }
    }
  } else {
    push @$isa, @new;
  }
}

# I'm afraid this 'as' pragma could invite ambiguous interpretation.
# But in following case, I can't find any other pragma name.
#
#   use XXX [as => 'YYY']
#
# So, let's define `declare_as` as an alias of `declare_naming`.
#
*declare_as = *declare_naming; *declare_as = *declare_naming;

sub declare_naming {
  (my $myPack, my Opts $opts, my ($name)) = m4i_args(@_);

  unless (defined $name and $name ne '') {
    croak "Usage: use ${myPack} [naming => NAME]";
  }

  $myPack->declare_constant($opts, $name => $myPack);
}

sub declare_inc {
  (my $myPack, my Opts $opts, my ($pkg)) = m4i_args(@_);
  $pkg //= $opts->{objpkg};
  $pkg =~ s{::}{/}g;
  $INC{$pkg . '.pm'} = 1;
}

sub declare_constant {
  (my $myPack, my Opts $opts, my ($name, $value, %opts)) = m4i_args(@_);

  my $my_sym = globref($opts->{objpkg}, $name);
  if (*{$my_sym}{CODE}) {
    return if $opts{or_ignore};
    croak "constant $opts->{objpkg}::$name is already defined";
  }

  *$my_sym = sub () {$value};
}

sub declare_fields {
  (my $myPack, my Opts $opts, my (@fields)) = m4i_args(@_);

  my $extended = fields_hash($opts->{objpkg});
  my $fields_array = fields_array($opts->{objpkg});

  # Import all fields from super class
  foreach my $super_class (@{*{globref($opts->{objpkg}, 'ISA')}{ARRAY}}) {
    my $super = fields_hash($super_class);
    next unless $super;
    my $super_names = fields_array($super_class);
    my @names = @$super_names ? @$super_names : keys %$super;
    foreach my $name (@names) {
      next if defined $extended->{$name};
      print STDERR "  Field $opts->{objpkg}.$name is inherited "
	. "from $super_class.\n" if DEBUG;
      $extended->{$name} = $super->{$name}; # XXX: clone?
      push @$fields_array, $name;
    }
  }

  $myPack->declare___field($opts, ref $_ ? @$_ : $_) for @fields;

  $opts->{objpkg}; # XXX:
}

sub declare___field {
  (my $myPack, my Opts $opts, my ($name, @rest)) = m4i_args(@_);
  print STDERR "  Declaring field $opts->{objpkg}.$name " if DEBUG;
  my $extended = fields_hash($opts->{objpkg});
  my $fields_array = fields_array($opts->{objpkg});

  my $field_class = $myPack->FieldSpec;
  my $spec = fields_hash($field_class);
  my (@early, @delayed);
  while (my ($k, $v) = splice @rest, 0, 2) {
    unless (defined $k) {
      croak "Undefined field spec key for $opts->{objpkg}.$name in $opts->{callpack}";
    }
    if ($k =~ /^[A-Za-z]/) {
      if (my $sub = $myPack->can("declare___field_with_$k")) {
	push @delayed, [$sub, $k, $v];
	next;
      } elsif (exists $spec->{$k}) {
	push @early, $k, $v;
	next;
      }
    }
    croak "Unknown option for $opts->{objpkg}.$name in $opts->{callpack}: "
      . ".$k";
  }

  my FieldSpec $obj = $extended->{$name}
    = $field_class->new(@early, name => $name);
  $obj->{package} = $opts->{objpkg};
  print STDERR " with $myPack $field_class => ", terse_dump($obj), "\n"
    if DEBUG;
  push @$fields_array, $name;

  # Create accessor for all public fields.
  if ($name =~ /^[a-z]/i and not $obj->{no_getter}) {
    *{globref($opts->{objpkg}, $name)} = sub { $_[0]->{$name} };
  }

  foreach my $delayed (@delayed) {
    my ($sub, $k, $v) = @$delayed;
    $sub->($myPack, $opts, $obj, $k, $v);
  }

  $obj;
}

sub declare___field_with_default {
  (my $myPack, my Opts $opts, my FieldSpec $fs, my ($k, $v)) = m4i_args(@_);

  $fs->{$k} = $v;

  if (ref $v eq 'CODE') {
    *{globref($opts->{objpkg}, "default_$fs->{name}")} = $v;
  } else {
    $myPack->declare_constant($opts, "default_$fs->{name}", $v);
  }
}

sub declare_alias {
  (my $myPack, my Opts $opts, my ($name, $alias)) = m4i_args(@_);
  print STDERR " Declaring alias $name in $opts->{destpkg} as $alias\n" if DEBUG;
  my $sym = globref($opts->{destpkg}, $name);
  if (*{$sym}{CODE}) {
    croak "Subroutine (alias) $opts->{destpkg}::$name redefined";
  }
  *$sym = sub () {$alias};
}

sub declare_map_methods {
  (my $myPack, my Opts $opts, my (@pairs)) = m4i_args(@_);

  foreach my $pair (@pairs) {
    my ($from, $to) = @$pair;
    my $sub = $opts->{objpkg}->can($to)
      or croak "Can't find method $to in (parent of) $opts->{objpkg}";
    *{globref($opts->{objpkg}, $from)} = $sub;
  }
}

sub declare_carp_not {
  (my $myPack, my Opts $opts, my (@carp_not)) = m4i_args(@_);

  unless (@carp_not) {
    push @carp_not, $myPack;
  }

  my $name = 'CARP_NOT';

  print STDERR "Declaring \@$opts->{objpkg}.$name = ".terse_dump(@carp_not)
    if DEBUG;

  *{globref($opts->{objpkg}, $name)} = \@carp_not;
}

BEGIN {
  #
  # Below does equiv of `our @CARP_NOT = qw/ MOP4Import::Util /;`
  #
  __PACKAGE__->declare_carp_not(MOP4Import::Opts::m4i_fake(__PACKAGE__),
                                qw/
                                   MOP4Import::Util
                                   /
                                 );
}

1;


