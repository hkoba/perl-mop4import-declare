package MOP4Import::Base::JSON;
use strict;
use warnings;
use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Base::Configure -as_base;

use JSON::MaybeXS;
use constant USING_CPANEL_JSON_XS => JSON()->isa("Cpanel::JSON::XS");

# Only works with Cpanel::JSON::XS. JSON::XS prohibits use of restricted hash.
sub TO_JSON {
  my ($self) = @_;
  +{map(($_ => $self->{$_}), grep {!/^_/} keys %$self)}
}

sub cli_json_type {
  (my MY $self) = @_;
  $self->cli_json_type_of($self);
}

sub cli_json_type_of {
  (my MY $self, my $objOrTypeName) = @_;
  $self->JSON_TYPE_HANDLER->lookup_json_type(ref $objOrTypeName || $objOrTypeName);
}

sub cli_json_encoder {
  (my MY $self) = @_;
  my $js = JSON()->new->canonical->allow_nonref;
  if (USING_CPANEL_JSON_XS) {
    $js->convert_blessed;
  }
  $js;
}

sub cli_encode_json {
  (my MY $self, my ($obj, $json_type)) = @_;
  my $json = $self->cli_encode_json_as_bytes($obj, $json_type);
  $json;
}

sub cli_encode_json_as_bytes {
  (my MY $self, my ($obj, $json_type)) = @_;
  my $codec = $self->cli_json_encoder;
  my @opts;
  my $json = do {
    if (not USING_CPANEL_JSON_XS) {
      $codec->encode($obj);
    } else {
      push @opts, do {
        if (defined $json_type) {
          $self->cli_json_type_of($json_type) // $json_type;
        } elsif (ref $obj) {
          $self->cli_json_type_of(ref $obj);
        } else {
          ();
        }
      };
      if (not (my $sub = UNIVERSAL::can($obj, 'TO_JSON'))) {
        $codec->encode($obj, @opts);
      } elsif (ref (my $conv = $sub->($obj))) {
        $codec->encode($conv, @opts);
      } else {
        $conv;
      }
    }
  };
  $json;
}

1;
