package MOP4Import::Base::CLI_JSON;
use MOP4Import::Base::CLI -as_base
  , [constant => parse_opts__preserve_hyphen => 1]
  , [fields =>
     , ['help' => doc => "show this help message"]
     , ['scalar' => doc => "evaluate subcommand in scalar context"]
     , ['output' => default => 'json'
        , doc => "choose output serializer (json/tsv/dump)"
      ]
     , ['flatten' => doc => "output each result separately (instead of single json array)"]
     , ['undef-as' => default => 'null'
        , doc => "serialize undef as this value. used in tsv output"
      ]
     , ['no-exit-code'
        , doc => "exit with 0(EXIT_SUCCESS) even when result was falsy/empty"
      ]
     , ['binary' => default => 0, doc => "keep STDIN/OUT/ERR binary friendly"]
     , '_cli_json'
   ];
use MOP4Import::Opts;
use MOP4Import::Util qw/lexpand/;

use JSON;
use open ();

sub cli_precmd {
  (my MY $self) = @_;
  #
  # cli_precmd() may called from $class->cmd_help.
  #
  unless (ref $self and $self->{binary}) {
    'open'->import(qw/:locale :std/);
  }
}

sub onconfigure_help {
  (my MY $self, my $val) = @_;
  $self->cmd_help;
  exit;
}

#
# Replace parse_opts to use parse_json_opts
#
sub parse_opts {
  my ($pack, $list, $result, $opt_alias, $converter, %opts) = @_;

  MOP4Import::Util::parse_json_opts($pack, $list, $result, $opt_alias);
}

sub cli_invoke {
  (my MY $self, my ($method, @args)) = @_;

  $self->cli_precmd($method);

  my $sub = $self->can($method)
    or Carp::croak "No such method: $method";

  $self->cli_invoke_sub($sub, $self, @args);
}

sub cli_invoke_sub {
  (my MY $self, my ($sub, $receiver, @args)) = @_;

  my @res;
  if ($self->{scalar}) {
    $res[0] = $sub->($receiver, @args);
  } else {
    @res = $sub->($receiver, @args);
  }

  if (not $self->{quiet}
        and ($self->{scalar} ? $res[0] : @res)) {

    if ($self->{flatten}) {
      $self->cli_output($_) for @res;
    } else {
      $self->cli_output(\@res);
    }
  }

  if ($self->{'no-exit-code'}) {
    return;
  } elsif ($self->{scalar}) {
    exit($res[0] ? 0 : 1);
  } else {
    exit(@res ? 0 : 1);
  }
}

#----------------------------------------

sub cli_encode_json {
  (my MY $self, my $obj) = @_;
  my $codec = $self->{_cli_json} //= do {
    my $js = JSON->new->canonical;
    $js->utf8 unless $self->{binary};
    $js;
  };
  my $json = $codec->encode($obj);
  Encode::_utf8_on($json) unless $self->{binary};
  $json;
}

sub cli_output {
  (my MY $self, my ($list, $outFH)) = @_;

  my $output = $self->can("cli_output_as_".$self->{'output'})
    or Carp::croak("Unknown output format: $self->{'output'}");

  $output->($self, $list, $outFH);
}

sub cli_output_as_json {
  (my MY $self, my ($list, $outFH)) = @_;
  $outFH //= \*STDOUT;
  print $outFH $self->cli_encode_json($list), "\n";
}

sub cli_output_as_tsv {
  (my MY $self, my ($list, $outFH)) = @_;
  $outFH //= \*STDOUT;
  foreach my $item (lexpand($list)) {
    print $outFH join("\t", map {
      if (not defined $_) {
        $self->{'undef-as'}
      } elsif (ref $_) {
        $self->cli_encode_json($_)
      } else {
        $_
      }
    } lexpand($item)), "\n";
  }
}

sub cli_output_as_dump {
  (my MY $self, my ($list, $outFH)) = @_;
  $outFH //= \*STDOUT;
  foreach my $item (lexpand($list)) {
    print $outFH join("\t", map {
      if (not defined $_) {
        $self->{'undef-as'}
      } elsif (ref $_) {
        MOP4Import::Util::terse_dump($_)
      } else {
        $_
      }
    } lexpand($item)), "\n";
  }
}

1;
