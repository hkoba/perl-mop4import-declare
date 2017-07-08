package MOP4Import::Types::Extend;
use 5.010;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;

use MOP4Import::Opts qw/Opts m4i_opts/;
use MOP4Import::Types -as_base;

sub import {
  my $myPack = shift;

  my Opts $opts = m4i_opts([caller])->take_hash_maybe(\@_);

  $opts->{extending} = 1;

  $myPack->dispatch_pairs_as(type => $opts, @_);
}

1;
