package MOP4Import::Opts;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;
use Exporter qw/import/;
use overload '""' => 'as_string';

use MOP4Import::Util qw/globref/;

use fields
  (
   # caller() of import in usual case.
    'callpack'

   # Where to export. Always defined.
   , 'destpkg'

   # What to define. Optional.
   , 'objpkg'

   # What to inherit. Optional.
   , 'basepkg'

   # Used in MOP4Import::Types::Extend and MOP4Import::Declare::Type
   , 'extending'

   # original caller info. This may be empty for faked m4i_opts()
   , 'caller'

   , qw/filename line/
 );

use MOP4Import::Util;

#========================================

sub Opts () {__PACKAGE__}

sub new {
  my ($pack, %opts) = @_;

  my Opts $opts = fields::new($pack);

  if (my $caller = delete $opts{caller}) {
    $opts->{caller} = $caller;
    ($opts->{callpack}, $opts->{filename}, $opts->{line})
      = ref $caller ? @$caller : ($caller, '', '');
  }

  $opts->{$_} = $opts{$_} for keys %opts;

  $opts->{objpkg} = $opts->{destpkg} = $opts->{callpack};

  $opts;
}

sub take_hash_maybe {
  (my Opts $opts, my $list) = @_;

  return $opts unless @$list and ref $list->[0] eq 'HASH';

  my $o = shift @$list;

  $opts->{$_} = $o->{$_} for keys %$o;

  $opts;
}

# Should I use Clone::clone?
sub clone {
  (my Opts $old) = @_;
  my Opts $new = fields::new(ref $old);
  %$new = %$old;
  $new;
}

sub with_destpkg { my Opts $new = clone($_[0]); $new->{destpkg} = $_[1]; $new }
sub with_objpkg  { my Opts $new = clone($_[0]); $new->{objpkg}  = $_[1]; $new }
sub with_basepkg { my Opts $new = clone($_[0]); $new->{basepkg} = $_[1]; $new }

# XXX: Not extensible. but how?
sub m4i_opts {
  my ($arg) = @_;
  if (not ref $arg) {
    # Fake Opts from string.
    Opts->new(destpkg => $arg);

  } elsif (UNIVERSAL::isa($arg, Opts)) {
    # Pass through.
    $arg

  } elsif (ref $arg eq 'ARRAY') {
    # Shorthand of MOP4Import::Opts->new(caller => [caller]).
    Opts->new(caller => $arg);

  } else {
    Carp::croak("Unknown argument!");
  }
}

sub m4i_args {
  ($_[0], m4i_opts($_[1]), @_[2..$#_]);
}

sub as_string {
  (my Opts $opts) = @_;
  $opts->{callpack};
}

# Provide field getters.
foreach my $field (keys our %FIELDS) {
  *{globref(Opts, $field)} = sub {shift->$field()};
}

our @EXPORT = qw/
                  Opts
                  m4i_args
                /;
our @EXPORT_OK = (@EXPORT, MOP4Import::Util::function_names
		  (matching => qr/^(with_|m4i_)/));

1;
