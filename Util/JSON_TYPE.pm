package MOP4Import::Util::JSON_TYPE;
use strict;
use warnings;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Util qw/globref define_constant/;

use Cpanel::JSON::XS::Type;

BEGIN {
  my $CLS = 'Cpanel::JSON::XS::Type';

  foreach my $origTypeName (qw(int float string bool null)) {
    foreach my $suffix ('', '_or_null') {
      # Ignore null_or_null
      next if $origTypeName eq 'null' and $suffix ne '';

      my $typeName = $origTypeName . $suffix;
      my $lowerName = "JSON_TYPE_".$typeName;
      my $upperName = "JSON_TYPE_".uc($typeName);
      define_constant(join("::", __PACKAGE__, $lowerName), $CLS->$upperName);
    }
  }

  foreach my $keyword (qw(hashof arrayof anyof null_or_anyof)) {
    my $longName = "json_type_$keyword";
    *{globref(__PACKAGE__, $keyword)} = $CLS->can($longName);
  }
}

my %JSON_TYPES;

sub lookup_json_type {
  my ($pack, $typeName) = @_;
  $JSON_TYPES{$typeName};
}

sub register_json_type {
  my ($pack, $destpkg, $json_type) = @_;
  $JSON_TYPES{$destpkg} = $json_type;
}

sub build_json_type {
  my ($pack, $typeSpec) = @_;
  if (not defined $typeSpec) {
    Carp::croak "json_type is undef!";
  }
  elsif (not ref $typeSpec) {
    if (defined (my $found = $JSON_TYPES{$typeSpec})) {
      $found;
    } elsif (my $sub = $pack->can(my $longName = "JSON_TYPE_".$typeSpec)) {
      $sub->();
    } else {
      Carp::croak "Unknown JSON_TYPE name: $typeSpec";
    }
  } elsif (ref $typeSpec eq 'ARRAY') {
    my ($keyword, @args) = @$typeSpec;
    $pack->$keyword(map {$pack->build_json_type($_)} @args);
  } elsif (ref $typeSpec eq 'HASH') {
    my %spec;
    foreach my $key (keys %$typeSpec) {
      $spec{$key} = $pack->build_json_type($typeSpec->{$key});
    }
    \%spec;
  }
}

1;
