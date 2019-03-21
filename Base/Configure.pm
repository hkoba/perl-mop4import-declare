package MOP4Import::Base::Configure;
use MOP4Import::Declare -as_base, -fatal;

use Scalar::Util qw/weaken/;
use Carp;

use MOP4Import::Opts;
use MOP4Import::Types::Extend
  FieldSpec => [[fields => qw/weakref/]];

use constant DEBUG_WEAK => $ENV{DEBUG_MOP4IMPORT_WEAKREF};

our %FIELDS;

#---------

sub new {
  my MY $self = fields::new(shift);
  $self->configure(@_);
  $self->after_new;
  $self->configure_default;
  $self->after_after_new;
  $self;
}

sub after_new {}
sub after_after_new {}

sub configure_default {
  (my MY $self, my $target) = @_;

  $target //= $self;

  my $fields = MOP4Import::Declare::fields_hash($self);

  while ((my $name, my FieldSpec $spec) = each %$fields) {
    if (not defined $target->{$name} and defined $spec->{default}) {
      $target->{$name} = $self->can("default_$name")->($self);
    }
  }

  $target;
}

sub configure {
  (my MY $self) = shift;

  my @args = do {
    if (@_ != 1) {
      @_;
    } elsif (ref $_[0] eq 'HASH') {
      %{$_[0]}
    } elsif (my $sub = UNIVERSAL::can($_[0], "cf_configs")) {
      # Shallow copy via cf_configs()
      $sub->($_[0]);
    } else {
      Carp::croak "Unknown argument! ".MOP4Import::Util::terse_dump($_[0]);
    }
  };

  my $fields = MOP4Import::Declare::fields_hash($self);

  my @setter;
  while (my ($key, $value) = splice @args, 0, 2) {
    unless (defined $key) {
      croak "Undefined option name for class ".ref($self);
    }
    next unless $key =~ m{^[A-Za-z][-\w]*\z};

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

sub cget {
  my ($self, $key, $default) = @_;
  $key =~ s/^--//;
  my $fields = MOP4Import::Declare::fields_hash($self);
  if (not exists $fields->{$key}) {
    confess "No such option: $key"
  }
  $self->{$key} // $default;
}

sub declare___field_with_weakref {
  (my $myPack, my Opts $opts, my FieldSpec $fs, my ($k, $v)) = m4i_args(@_);

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

sub cf_configs {
  (my MY $self, my (%opts)) = @_;
  my $all = delete $opts{all};
  if (keys %opts) {
    Carp::croak "Unknown option for cf_configs: ".join(", ", sort keys %opts);
  }
  my $fields = MOP4Import::Util::fields_hash($self);
  my @result;
  foreach my $key ($self->cf_public_fields) {
    defined (my $val = $self->{$key})
      or next;
    my FieldSpec $spec = $fields->{$key};
    if (not $all
          and defined $spec->{default} and $val eq $spec->{default}) {
      next;
    }
    push @result, $key, MOP4Import::Util::shallow_copy($val);
  }
  @result;
}

sub cf_public_fields {
  my $obj_or_class = shift;
  my $fields = MOP4Import::Util::fields_hash($obj_or_class);
  sort grep {/^[a-z]/i} keys %$fields;
}

1;

__END__

=head1 NAME

MOP4Import::Base::Configure - OO Base class (based on MOP4Import)

=head1 SYNOPSIS

  package MyPSGIMiddlewareSample {
    use MOP4Import::Base::Configure -as_base
      , [fields =>

         , [app =>
             , doc => 'For Plack::Middleware standard conformance.']

         , [dbname =>
             , doc => 'Name of SQLite dbfile']
        ];

    use parent qw( Plack::Middleware );

    use DBI;

    sub call {
      (my MY $self, my $env) = @_;

      $env->{'myapp.dbh'} = DBI->connect("dbi:SQLite:dbname=$self->{dbname}");

      return $self->app->($env);
    }
  };

=head1 DESCRIPTION

MOP4Import::Base::Configure is a
L<MOP4Import|MOP4Import::Declare> family
and is my latest implementation of
L<Tk-like configure based object|MOP4Import::whyfields>
base classs. This class also inherits L<MOP4Import::Declare>,
so you can define your own C<declare_..> pragmas too.

=head1 METHODS

=head2 new (%opts | \%opts)
X<new>

Usual constructor. This passes given C<%opts> to L</configure>.

=head2 configure (%opts | \%opts)
X<configure>

General setter interface for public fields.
See also L<Tk style configure method|MOP4Import::whyfields/Tk-style-configure>.

=head2 configure_default ()
X<configure_default>

This fills undefined public fields with their default values.
Default values are obtained via C<default_FIELD> hook.
They are normally defined by
L<default|MOP4Import::Declare/declare___field_with_default> field spec.

=head1 HOOK METHODS

=head2 after_new
X<after_new>

This hook is called just after call of C<configure> in C<new>.

=head1 FIELD SPECs

For L<field spec|MOP4Import::Declare/FieldSpec>, you can also have
hook for field spec.

=head2 default => VALUE

This defines C<default_FIELDNAME> method with given VALUE.

=head2 weakref => 1

This generates set hook (onconfigure_FIELDNAME) wrapped with
L<Scalar::Util/weaken>.

=head1 SEE ALSO

L<MOP4Import::Declare>

=head1 AUTHOR

Kobayashi, Hiroaki E<lt>hkoba@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
