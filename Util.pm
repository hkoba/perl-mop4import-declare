package MOP4Import::Util;
use strict;
use warnings qw(FATAL all NONFATAL misc);
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

sub symtab {
  *{globref(shift, '')}{HASH}
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

sub parse_opts {
  my ($pack, $list, $result, $alias) = @_;
  my $wantarray = wantarray;
  unless (defined $result) {
    $result = $wantarray ? [] : {};
  }
  while (@$list and my ($n, $v) = $list->[0]
	 =~ m{^--$ | ^(?:--? ([\w:\-\.]+) (?: =(.*))?)$}xs) {
    shift @$list;
    last unless defined $n;
    $n = $alias->{$n} if $alias and $alias->{$n};
    $v = 1 unless defined $v;
    if (ref $result eq 'HASH') {
      $result->{$n} = $v;
    } else {
      push @$result, $n, $v;
    }
  }
  $wantarray && ref $result ne 'HASH' ? @$result : $result;
}

sub parse_pairlist {
  my ($pack, $aref, $do_box) = @_;
  my @res;
  while (@$aref) {
    my $item = shift @$aref;
    if ($item =~ /^(\w+)=(.*)/) {
      push @res, $do_box ? [$1, $2] : ($1, $2);
    } elsif ($item =~ /^(\w+):?$/) {
      my $val = shift @$aref;
      push @res, $do_box ? [$1, $val] : ($1, $val);
    } else {
      die "Invalid parameter!: $item\n"; # XXX: Too much? should push back?
    }
  }
  @res;
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

our @EXPORT = qw/globref fields_hash fields_symbol lexpand terse_dump/;
our @EXPORT_OK = function_names(from => __PACKAGE__
		   , except => qr/^(import|c\w*)$/
		 );

1;
