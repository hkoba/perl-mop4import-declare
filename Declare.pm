# -*- coding: utf-8 -*-
package MOP4Import::Declare;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
our $VERSION = '0.049_001';
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

  } elsif ($declSpec =~ /^([\*\$\%\@\&])?([A-Za-z]\w*)$/) {

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
    croak "Unknown pragma ".terse_dump($pragma)." in $opts->{destpkg}"
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

sub declare_base {
  (my $myPack, my Opts $opts, my (@base)) = m4i_args(@_);

  $myPack->declare___add_isa($opts->{objpkg}, @base);

  $myPack->declare_fields($opts);
}

sub declare_parent {
  (my $myPack, my Opts $opts, my (@base)) = m4i_args(@_);

  foreach my $fn (@base) {
    (my $cp = $fn) =~ s{::|'}{/}g;
    require "$cp.pm";
  }

  $myPack->declare_base($opts, @base);
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

# XXX: previously was [as].
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

1;
__END__

=head1 NAME

MOP4Import::Declare - map import args to C<< $meta->declare_...() >> pragma methods.

=head1 SYNOPSIS

  package YourExporter {
  
    use MOP4Import::Declare -as_base; # "use strict" is turned on too.
    
    use MOP4Import::Opts;             # import a type 'Opts' and m4i_args()
    
    use MOP4Import::Util qw/globref/; # encapsulates "no strict 'refs'".
    
    use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};
    
    # This method implements '-foo' pragma,
    # and adds method named 'foo()' in $callpack.
    sub declare_foo {
      my ($myPack, $callpack) = @_;
      
      my $glob = globref("$callpack", 'foo'); # Note: "" to stringify.
  
      *$glob = sub (@) { join("! ", "FOOOOOO", @_) };
    }
    
    # This method implements [bar => $x, $y, @z] pragma,
    # and adds variables $bar, %bar and @bar in $callpack.
    sub declare_bar {
      (my $myPack, my Opts $callpack, my ($x, $y, @z)) = m4i_args(@_);
      
      print STDERR "callpack = $callpack->{callpack}\n" if DEBUG;
  
      my $glob = globref($callpack->{callpack}, 'bar');
      *$glob = \ $x;
      *$glob = +{bar => $y};
      *$glob = \@z;
    }
  };
  
  1

  #-------------------
  # Then you can use above from command line like:

  % perl -MYourExporter=-foo -le 'print foo bar => 3'
  FOOOOOO! bar! 3
  %

  #-------------------
  # Or in another file:

  package MyApp;
  use YourExporter -foo, [bar => "A", "x", 1..3];
  
  # Above means you called:
  #   use strict;
  #   use warnings;
  #   BEGIN {
  #     YourExporter->declare_foo('MyApp');
  #     YourExporter->declare_bar('MyApp', "A", "x", 1..3);
  #   }
  
  print "scalar=$bar\t", "hash=$bar{bar}\t", "array=@bar\n";

  # So, you will get:
  #   scalar=A        hash=x  array=1 2 3

=head1 DESCRIPTION

MOP4Import::Declare is one protocol implementation
of L<MOP4Import> family.
You can use this module to implement your own exporter
in an extensible way.

With MOP4Import::Declare, arguments of L<import()>
are mapped into method calls starting with C<declare_...()>.

=head2 "MetaObject Protocol for Import" in this module

C<import()> method of MOP4Import::Declare briefly does following:

  sub import {
    my ($myPack, @pragma) = @_;
    
    my Opts $opts = m4i_opts([caller]);
    
    $myPack->dispatch_declare($opts, -strict, @pragma);
  }

An object of type L<MOP4Import::Opts>,
which is instanciated via L<m4i_opts()|MOP4Import::Opts/m4i_opts>,
carries L<caller|perlfunc/caller> information to each pragmas.

L<dispatch_declare()|MOP4Import::Declare/dispatch_declare> dispatches
C<declare_PRAGMA()> pragma handlers for each pragma, based on argument types
(string, arrayref or coderef).

=over 4

=item -PRAGMA

  use YourExporter -PRAGMA;

C<-Identifier>, word starting with C<->, is dispatched as:

  $myPack->declare_PRAGMA($opts);

Note: You don't need to quote this pragma because perl has special support
for this kind of syntax (bareword lead by C<->).

=item [PRAGMA => ARGS...]

  use YourExporter [PRAGMA => @ARGS];

ARRAY ref is dispatched as:

  $myPack->declare_PRAGMA($opts, @ARGS);

=item NAME, *NAME, $NAME, %NAME, @NAME, &NAME

  use YourExporter qw/NAME *NAME $NAME %NAME @NAME &NAME/;

These kind of words (optionally starting with sigil) just behaves
as ordinally export/import.

=item sub {...}

  use YourExporter sub { ... };

You can pass callback too.

  sub {
    my ($yourExporterPackage, $opts) = @_;
    # do rest of job
  }

=back

=head2 Simplified case API
X<simpler-m4i-api>

If you just want to implement ordinal exporter
and feel L<MOP4Import::Opts> is overkill,
you can just use C<scalar caller> as a MOP4Import option.
L<m4i_args(@_)|MOP4Import::Opts/m4i_args> will convert
given package name to C<MOP4Import::Opts> hash object for you.

  sub import {
    my ($myPack, @pragma) = @_;
    
    my $callpack = caller;
    
    $myPack->dispatch_declare($callpack, -strict, @pragma);
  }

=head2 DEBUG_MOP4IMPORT environment variable
X<DEBUG_MOP4IMPORT>

To inspect what MOP4Import::Declare does, set environment variable
C<DEBUG_MOP4IMPORT> to positive integer. Logs are emitted to STDERR.

=for code sh

  DEBUG_MOP4IMPORT=1 perl YourExporter.pm

=for code perl

=head1 PRAGMAS

All pragmas below are actually implemented as "declare_PRAGMA" method,
so you can override them in your subclass, as you like.

=head2 -strict
X<strict> X<declare_strict>

This pragma turns on C<use strict; use warnings;>.

=head2 -fatal
X<fatal> X<declare_fatal>

This pragma turns on C<use warnings qw(FATAL all NONFATAL misc);>.

=head2 C<< [base => CLASS...] >>
X<base> X<declare_base>

Establish an ISA relationship with base classes at compile time.
Like L<base>, this imports C<%FIELDS> from base classes too.

Note: when target module uses L<c3 mro|mro/"The C3 MRO">,
this pragma adds given classes in front of C<@ISA>.

=head2 C<< [parent => CLASS...] >>
X<parent> X<declare_parent>

Establish an ISA relationship with base classes at compile time.
In addition to L</base>,
this loads requested classes at compile time, like L<parent>.

=head2 -as_base,  C<< [as_base => FIELD_SPECs...] >>
X<as_base> X<declare_as_base>

This pragma sets YourExporter as base class of target module.
Optional arguments are passed to L<fields pragma/fields>.

Note: as noted in L</base>, this pragma cares mro of target module.
You can simply inherit classes with "generic" to "specific" order.

=head2 C<< [fields => SPEC...] >>
X<fields> X<declare_fields>

This pragma adds C<%FIELDS> definitions to target module, based on
given field specs. Each fields specs are either single string
or array ref like C<< [FIELD_NAME => SPEC => value, ...] >>.

  use MOP4Import::Declare
     [fields =>
        qw/
          foo bar baz
        /
      ];

  use MOP4Import::Declare
     [fields =>
        [debug   => doc => 'debug level'],
        [dbi_dsn => doc => 'DBI connection string'],
        qw/dbi_user dbi_password/
     ];

For more about fields, see L<whyfields|MOP4Import::whyfields>.

=head3 field spec hooks.
X<field_hook> X<declare___field_with>

You can define special hook for field spec.
That should named starting with C<declare___field_with_...>.

 sub declare___field_with_foo {
   (my $myPack, my $opts, my FieldSpec $fs, my ($k, $v)) = @_;

   $fs->{$k} = $v;

   # Do other jobs...
 }

=head4 default
X<declare___field_with_default>

When field C<bar> in class C<Foo> has spec C<< default => $VALUE >>,
method C<Foo::default_bar> is defined with $VALUE.

  sub Foo::default_bar { $VALUE }

If VALUE is CODE ref, it is directly assigned to method symbol.

Note: This spec only cares about defining above C<default_...> method.
To make default value assignment really work,
you must have constructor which cooperate well with this.
You can use L<MOP4Import::Base::Configure> for that purpose
but are not restricted to it.
Anyway MOP4Import::Declare itself will be kept constructor agnostic.


=head2 C<< [constant => NAME => VALUE] >>
X<constant> X<declare_constant>

  use YourExporter [constant => FOO => 'BAR', or_ignore => 1];

This pragma adds constant sub C<NAME> to target module.

=over 4

=item C<< or_ignore => BOOL >>

If this option is given and given NAME already defined in target module,
skip adding.

=back

=head2 -inc
X<inc> X<declare_inc>

This pragma adds target module to C<%INC>
so that make the module C<require> safe.

=head2 C<< [map_methods => [FROM => TO]...] >>
X<map_methods> X<declare_map_methods>

This pragma looks up actual sub of C<TO> and set it to target module
with name C<FROM>. For example:

  package MyStore {
    use MOP4Import::Declare
         [parent => qw/Plack::Session::Store::File/]
       , [map_methods => [get => 'fetch'], [set => 'store']];
  }

  use Plack::Builder;
  builder {
    enable 'Session::Simple', store => MyStore->new(dir => $sess_dir);
    $app
  };

=head1 METHODS

=head2 dispatch_declare($opts, PRAGMA...)
X<dispatch_declare>

This implements C<MOP4Import::Declare> style type-based pragma dispatching.

  YourExporter->dispatch_declare($opts, -foo, [bar => 'baz'], '*FOO');

is same as

  YourExporter->declare_foo($opts);
  YourExporter->declare_bar($opts, 'baz');
  YourExporter->dispatch_import($opts, '*FOO');

=head2 dispatch_import($opts, $STRING)
X<dispatch_import>

This mimics L<Exporter> like sigil based import.
Actually this dispatches C<import_...> method with respect to leading sigil.
(This means you can override each cases in your subclass).
If C<$STRING> has no sigil, L</import_NAME> will be called.

  use YourExporter qw/*FOO $BAR @BAZ %QUX &QUUX/;

is same as

  BEGIN {
    YourExporter->import_GLOB($callpack,   GLOB   => 'FOO');
    YourExporter->import_SCALAR($callpack, SCALAR => 'BAR');
    YourExporter->import_ARRAY($callpack,  ARRAY  => 'BAZ');
    YourExporter->import_HASH($callpack,   HASH   => 'QUX');
    YourExporter->import_CODE($callpack,   CODE   => 'QUUX');
  }

Note: some complex features like export list C<@EXPORT>, C<@EXPORT_OK>
and C<:TAG> based import are not implemented.

If you really want to implement those features, you can inherit this module and
simply override C<dispatch_import>. It will be called for all non reference
pragmas.

=head2 import_NAME($opts, $name)
X<import_NAME>

This method (hook) is called when simple word (matches C</^\w+$/>) is given
as import list.

  use YourExporter qw/FOO/;

is same as:

  BEGIN {
    YourExporter->import_NAME(__PACKAGE__, 'Foo');
  }

=head2 import_SIGIL($opts, $type, $name)
X<import_SIGIL>

Actual implementation of C<import_GLOB>, C<import_SCALAR>, C<import_ARRAY>, C<import_CODE>.


=head1 TYPES

=head2 Opts

This type of object is always given as a second argument of
each invocation of C<declare_PRAGMA>. For more details, see L<MOP4Import::Opts>.

=head2 FieldSpec

L<fields pragma|/fields> in this module creates this type of object for
each field specs. Currently, only C<name>, C<doc> and C<default> are declared.
But you can extend FieldSpec in your exporter like following:

  use YourBaseObject {
    use MOP4Import::Declare -as_base;
    use MOP4Import::Types::Extend
      FieldSpec => [[fields => qw/readonly required validator/]];
  }
  
  package MyApp {
    use YourBaseObject -as_base,
        [fields => [app_name =>
                      readonly => 1,
                      required => 1]]
  }

=head1 SEE ALSO

L<MOP4Import::Types>

=head1 AUTHOR

Kobayashi, Hiroaki E<lt>hkoba@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
