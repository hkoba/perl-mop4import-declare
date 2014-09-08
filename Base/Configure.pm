package MOP4Import::Base::Configure; sub MY () {__PACKAGE__}
use strict;
use warnings FATAL => qw/all/;
use Carp;
use fields ();

use MOP4Import::Declare -as_base;

our %FIELDS;

sub new {
  my MY $self = fields::new(shift);
  $self->configure(@_);
  $self->after_new;
  $self;
}

sub after_new {} # XXX: Sholud we call next::method?

sub configure {
  (my MY $self) = shift;

  my @args = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_;

  my $fields = MOP4Import::Declare::fields_hash($self);

  my @setter;
  while (my ($key, $value) = splice @args, 0, 2) {
    unless (defined $key) {
      croak "Undefined option name for class ".ref($self);
    }
    next unless $key =~ m{^[A-Za-z]\w+\z};
    unless (exists $fields->{$key}) {
      croak "Unknown option for class ".ref($self).": ".$key;
    }

    if (my $sub = $self->can("onconfigure_$key")) {
      push @setter, [$sub, $value];
    } else {
      $self->{$key} = $value;
    }
  }

  $_->[0]->($self, $_->[-1]) for @setter;

  $self;
}

1;

__END__

