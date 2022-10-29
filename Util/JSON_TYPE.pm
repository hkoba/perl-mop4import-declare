package MOP4Import::Util::JSON_TYPE;
use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Util qw/globref define_constant terse_dump/;

use MOP4Import::Opts qw/Opts/;

use Cpanel::JSON::XS::Type;

our %JSON_TYPES; # It is too early to hide this.

BEGIN {
  my $CLS = 'Cpanel::JSON::XS::Type';

  foreach my $origTypeName (qw(int float string bool null)) {
    foreach my $suffix ('', '_or_null') {
      # Ignore null_or_null
      next if $origTypeName eq 'null' and $suffix ne '';

      my $typeName = $origTypeName . $suffix;
      my $lowerName = "JSON_TYPE_".$typeName;
      my $upperName = "JSON_TYPE_".uc($typeName);
      my $value = $CLS->$upperName;
      define_constant(join("::", __PACKAGE__, $lowerName), $value);

      # Make sure underlying typecode 1, 2, 3... can be resolved too.
      $JSON_TYPES{$value} = $value;
    }
  }

  foreach my $keyword (qw(hashof arrayof anyof null_or_anyof)) {
    my $longName = "json_type_$keyword";
    my $sub = $CLS->can($longName);
    *{globref(__PACKAGE__, $keyword)} = sub {
      shift; $sub->(@_);
    }
  }
}

sub intern_json_type {
  (my $pack, my Opts $opts, my $typeName) = @_;
  $JSON_TYPES{$typeName} //= $pack->build_json_type($opts, $typeName);
}

sub lookup_json_type {
  my ($pack, $typeName) = @_;
  $JSON_TYPES{$typeName};
}

sub declare_json_type_record {
  my ($pack, $typeName) = @_;
  $JSON_TYPES{$typeName} //= +{};
}

sub inherit_json_type {
  my ($pack, $typeName, $superType) = @_;
  my $superSpec = $pack->lookup_json_type($superType)
    or return;

  my $thisSpec = $pack->declare_json_type_record($typeName);
  print STDERR "  json_type $typeName inherits following items from $superType: "
    , join(", ", sort keys %$superSpec), "\n" if DEBUG;

  foreach my $key (keys %$superSpec) {
    $thisSpec->{$key} = $superSpec->{$key};
  }
}

sub resolve_json_type_in_context {
  (my $pack, my Opts $opts, my $typeName) = @_;
  Carp::confess "typename is undef!" unless defined $typeName;
  if ($typeName =~ /^[A-Z]/ and $typeName !~ /::/
      and my $sub = $opts->{destpkg}->can($typeName)) {
    my $value = $sub->();
    print STDERR ", $typeName is resolved to $value in $opts->{destpkg}"
      if DEBUG;
    $value;
  } else {
    print STDERR ", $typeName is used as-is in $opts->{destpkg}"
      if DEBUG;
    undef;
  }
}

sub register_json_type_of_field {
  (my $pack, my Opts $opts, my ($destpkg, $fieldName, $jsonType)) = @_;
  my $typeRec = $JSON_TYPES{$destpkg} //= +{};
  unless (ref $typeRec eq 'HASH') {
    Carp::croak "Can't set json_type for $destpkg\->{$fieldName} because it was already declared as type: @{[$typeRec // '']}"
  }

  push @{$opts->{delayed_tasks}}, sub {
    print STDERR "  $fieldName json_type: spec=", terse_dump($jsonType)
      if DEBUG;

    my $typeName;
    if (not ref $jsonType and $typeName = ($JSON_TYPES{$jsonType} || $pack->resolve_json_type_in_context($opts, $jsonType) || $jsonType) and my $found = $JSON_TYPES{$typeName}) {
      $typeRec->{$fieldName} = $found;
    } else {
      $typeRec->{$fieldName} = $pack->intern_json_type($opts, $jsonType);
    }
    Scalar::Util::weaken($typeRec->{$fieldName}) if ref $typeRec->{$fieldName};

    print STDERR "\n" if DEBUG;
  };
}


sub build_json_type {
  (my $pack, my Opts $opts, my $typeSpec) = @_;
  if (not defined $typeSpec) {
    Carp::croak "json_type is undef!";
  }
  elsif (not ref $typeSpec) {
    my $typeName = $pack->resolve_json_type_in_context($opts, $typeSpec) || $typeSpec;
    if (defined (my $found = $JSON_TYPES{$typeName})) {
      # Note: weakening here does not take effect.
      return $found;
    } elsif (my $sub = $pack->can(my $longName = "JSON_TYPE_".$typeSpec)) {
      return $sub->();
    } else {
      Carp::croak "Unknown JSON_TYPE name: $typeSpec";
    }
  }
  elsif (ref $typeSpec eq 'ARRAY') {
    my ($keyword, @args) = @$typeSpec;
    print STDERR "  build_json_type(", terse_dump($keyword, @args), ") => "
      if DEBUG;
    my @actual = map {$pack->build_json_type($opts, $_)} @args;
    print STDERR " >> (", terse_dump($keyword, @actual), ")"
      if DEBUG;
    $pack->$keyword(@actual);
  }
  elsif (ref $typeSpec eq 'HASH') {
    my %spec;
    foreach my $key (keys %$typeSpec) {
      $spec{$key} = $pack->build_json_type($opts, $typeSpec->{$key});
    }
    \%spec;
  }
}

1;
