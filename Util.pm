package MOP4Import::Util;
use strict;
use warnings FATAL => qw/all/;
use Carp;
use Data::Dumper;

use Exporter qw/import/;

sub globref {
  my $pack_or_obj = shift;
  my $pack = ref $pack_or_obj || $pack_or_obj;
  my $symname = join("::", $pack, @_);
  no strict 'refs';
  \*{$symname};
}

sub fields_hash {
  my $sym = fields_symbol(@_);
  # XXX: return \%{*$sym}; # If we use this, we get "used only once" warning.
  unless (*{$sym}{HASH}) {
    *$sym = {};
  }
  *{$sym}{HASH};
}

sub fields_symbol {
  globref($_[0], 'FIELDS');
}

sub lexpand {
  ref $_[0] ? @{$_[0]} : $_[0];
}

sub terse_dump {
  join ", ", map {
    Data::Dumper->new([$_])->Terse(1)->Indent(0)->Dump;
  } @_;
}

sub function_names {
  my (%opts) = @_;
  my $packname = delete $opts{from}     // caller;
  my $pattern  = delete $opts{matching} || qr{^[A-Za-z]\w+$};
  my $except   = delete $opts{except}   // qr{^import$};
  if (keys %opts) {
    croak "Unknown arguments: ".join(", ", keys %opts);
  }
  my $symtab = *{globref($packname, '')}{HASH};
  my @result;
  foreach my $name (sort keys %$symtab) {
    next unless *{$symtab->{$name}}{CODE};
    next unless $name =~ $pattern;
    next if $except and $name =~ $except;
    push @result, $name;
  }
  @result;
}

our @EXPORT = our @EXPORT_OK
  = function_names(from => __PACKAGE__
		   , except => qr/^(import|c\w*)$/
		 );

1;
