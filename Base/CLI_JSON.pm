package MOP4Import::Base::CLI_JSON;
use MOP4Import::Base::CLI -as_base
  , [fields =>
     , ['scalar' => doc => "evaluate subcommand in scalar context"]
     , ['json-output' => default => 1]
     , ['no-exit-code']
   ];

use MOP4Import::Util qw/parse_json_opts/;

use JSON;

sub run {
  my ($class, $arglist, $opt_alias) = @_;

  my @opts = $class->parse_json_opts($arglist, undef, $opt_alias);
  my MY $primary_opts = $class->configure_default(+{@opts});

  unless (@$arglist) {
    # Invoke help command if no arguments are given.
    $class->cmd_help;
    exit;
  }

  my $cmd = shift @$arglist;

  my ($actual_class, $actual_cmd) = do {
    if ($cmd =~ m{^\w+$}) {
      ($class, $cmd);
    } else {
      my ($mod, $modcmd) = $cmd =~ m{^(.*?)::(\w+)$}
        or Carp::croak("Syntax error in subcommand name! $cmd");
      require Module::Runtime;
      Module::Runtime::require_module($mod);
      ($mod, $modcmd);
    }
  };

  my $self = $actual_class->new(@opts);

  if (my $sub = $self->can("cmd_$cmd")) {
    # Invoke official command.

    $sub->($self, @$arglist);

  } elsif ($sub = $self->can($cmd)) {
    # Invoke internal methods. Development aid.

    my @res;
    if ($primary_opts->{scalar}) {
      $res[0] = $sub->($self, @$arglist);
    } else {
      @res = $sub->($self, @$arglist);
    }

    if (not $primary_opts->{quiet}
        and ($primary_opts->{scalar} ? $res[0] : @res)) {
      if ($primary_opts->{'json-output'}) {
        print JSON->new->utf8->canonical->encode(\@res), "\n";
      } else {
        print join("\n", map {MOP4Import::Util::terse_dump($_)} @res), "\n";
      }
    }

    if ($primary_opts->{'no-exit-code'}) {
      exit 0;
    } elsif ($primary_opts->{scalar}) {
      exit($res[0] ? 0 : 1);
    } else {
      exit(@res ? 0 : 1);
    }

  } else {
    $self->cmd_help("Error: No such command '$cmd'\n");
  }
}

1;
