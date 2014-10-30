package MOP4Import::Opts;
use strict;
use warnings FATAL => qw/all/;
use Carp;
use Exporter qw/import/;

use fields
  (
   # Where to export. Always defined.
   'destpkg'

   # What to define. Optional.
   , 'objpkg'

   # What to inherit. Optional.
   , 'basepkg'
 );

use MOP4Import::Util;

#========================================

sub Opts () {__PACKAGE__}

sub new {
  my ($pack, $callpack, @toomany) = @_;
  if (@toomany) {
    croak "Too many arguments! You may need to write Opts->new(scalar caller)";
  }
  my Opts $opts = fields::new($pack);
  $opts->{destpkg} = $opts->{objpkg} = $callpack;
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

our @EXPORT = qw/Opts/;
our @EXPORT_OK = (@EXPORT, MOP4Import::Util::function_names
		  (matching => qr/^with_/));

1;
