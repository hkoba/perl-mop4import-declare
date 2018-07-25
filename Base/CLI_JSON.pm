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
use MOP4Import::Util qw/parse_json_opts
                        lexpand
                       /;

use JSON;
use open ();

sub cli_precmd {
  (my MY $self) = @_;
  unless ($self->{binary}) {
    'open'->import(qw/:locale :std/);
  }
}

sub onconfigure_help {
  (my MY $self, my $val) = @_;
  $self->cmd_help;
  exit;
}

sub run {
  my ($class, $arglist, $opt_alias) = @_;

  my MY $self = $class->new($class->parse_json_opts($arglist, undef, $opt_alias));

  unless (@$arglist) {
    # Invoke help command if no arguments are given.
    $class->cmd_help;
    return;
  }

  my $cmd = shift @$arglist;

  if (my $sub = $self->can("cmd_$cmd")) {
    # Invoke official command.

    $self->cli_precmd($cmd);

    $sub->($self, @$arglist);

  } elsif ($self->can($cmd)) {
    # Invoke internal methods. Development aid.

    $self->cli_invoke($cmd, @$arglist);

  } else {
    $self->cmd_help("Error: No such subcommand '$cmd'\n");
  }
}

sub cli_invoke {
  (my MY $self, my ($method, @args)) = @_;

  $self->cli_precmd($method);

  my @res;
  if ($self->{scalar}) {
    $res[0] = $self->$method(@args);
  } else {
    @res = $self->$method(@args);
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
