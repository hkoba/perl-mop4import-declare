package MOP4Import::Base::Configure;
use MOP4Import::Declare -as_base, -fatal;

use Scalar::Util qw/weaken/;
use Carp;

use MOP4Import::Opts;
use MOP4Import::Types
  FieldSpec => [[fields => qw/weakref/]];

use constant DEBUG_WEAK => $ENV{DEBUG_MOP4IMPORT_WEAKREF};

our %FIELDS;

sub new {
  my MY $self = fields::new(shift);
  $self->configure(@_);
  $self->after_new;
  $self->configure_default;
  $self;
}

sub after_new {}

sub configure_default {
  (my MY $self) = @_;

  my $fields = MOP4Import::Declare::fields_hash($self);

  while ((my $name, my FieldSpec $spec) = each %$fields) {
    if (not defined $self->{$name} and defined $spec->{default}) {
      $self->{$name} = $self->can("default_$name")->($self);
    }
  }
}

sub configure {
  (my MY $self) = shift;

  my @args = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_;

  my $fields = MOP4Import::Declare::fields_hash($self);

  my @setter;
  while (my ($key, $value) = splice @args, 0, 2) {
    unless (defined $key) {
      croak "Undefined option name for class ".ref($self);
    }
    next unless $key =~ m{^[A-Za-z]\w*\z};

    if (my $sub = $self->can("onconfigure_$key")) {
      push @setter, [$sub, $value];
    } elsif (exists $fields->{$key}) {
      $self->{$key} = $value;
    } else {
      croak "Unknown option for class ".ref($self).": ".$key;
    }
  }

  $_->[0]->($self, $_->[-1]) for @setter;

  $self;
}

sub declare___field_with_weakref {
  (my $myPack, my Opts $opts, my $callpack, my FieldSpec $fs, my ($k, $v)) = @_;

  $fs->{$k} = $v;

  if ($v) {
    my $name = $fs->{name};
    my $setter = "onconfigure_$name";
    print STDERR "# Declaring weakref $setter for $opts->{objpkg}.$name\n"
      if DEBUG_WEAK;
    *{MOP4Import::Util::globref($opts->{objpkg}, $setter)} = sub {
      print STDERR "# weaken $opts->{objpkg}.$name\n" if DEBUG_WEAK;
      weaken($_[0]->{$name} = $_[1]);
    };
  }
}


1;

__END__

