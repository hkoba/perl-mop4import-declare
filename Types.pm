package MOP4Import::Types;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;

use MOP4Import::Pairs -as_base, qw/Opts m4i_opts/;
use MOP4Import::Declare::Type -as_base;
use MOP4Import::Util;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

sub import {
  my $myPack = shift;

  m4i_log_start() if DEBUG;

  my Opts $opts = m4i_opts([caller])->take_hash_maybe(\@_);

  $myPack->dispatch_pairs_as(type => $opts, @_);

  m4i_log_end($opts->{callpack}) if DEBUG;
}

1;

__END__

=head1 NAME

MOP4Import::Types - create multiple inner-classes at once.

=head1 SYNOPSIS

Create inner-classes C<MyApp::Artist> and C<MyApp::CD>
using L<MOP4Import::Types>.

  # Define subtype Artist and CD with their fields.
  package MyApp;
  use MOP4Import::Types
    (Artist => [[fields => qw/artistid name/]]
     , CD   => [[fields => qw/cdid artistid title year/]]);

Above is an equivalent of following:

  package MyApp;
  sub Artist () {'MyApp::Artist'}
  package MyApp::Artist {
     use MOP4Import::Declare [fields => qw/artistid name/];
  }
  sub CD () {'MyApp::CD'}
  package MyApp::CD {
     use MOP4Import::Declare [fields => qw/cdid artistid title year/];
  }

You can use above types like following with compile-time field name
typos detection of L<fields>.

  sub print_artist_cds {
    (my $self, my Artist $artist) = @_;
    my @cds = $self->DB->select(CD => {artistid => $artist->{artistid}});
    foreach my CD $cd (@cds) {
      print tsv($cd->{title}, $cd->{year}), "\n";
    }
  }

=head1 DESCRIPTION

MOP4Import::Types is yet another protocol implementation
of L<MOP4Import|MOP4Import::Intro> family.

In contrast to MOP4Import::Declare, which is designed to
modify target module itself,
this module is designed to add new inner-classes to target module.

With "inner-class", I mean class declared in some module
and not directly exposed as "require" able module.

=head2 "MetaObject Protocol for Import" in this module

C<import()> method of MOP4Import::Types briefly does following:

  sub import {
    my ($myPack, @pairs) = @_;
  
    my $callpack = caller;
    my $opts = +{};
  
    while (my ($typename, $pragma_list) = splice @pairs, 0, 2) {
  
      my $innerClass = join("::", $callpack, $typename);
  
      $myPack->declare___type($opts, $callpack, $typename, $innerClass);
  
    }
  }
