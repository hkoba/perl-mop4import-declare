package MOP4Import::Base::CLI_JSON;
use MOP4Import::Base::CLI -as_base
  , [fields =>
     , ['scalar' => doc => "evaluate subcommand in scalar context"]
     , ['output' => default => 'json']
     , ['undef-as' => default => 'null']
     , ['no-exit-code']
   ];
use MOP4Import::Opts;
use MOP4Import::Util qw/parse_json_opts
                        lexpand
                       /;

use JSON;

# Rewrite field names from kebab-case to snake_case.
sub declare_options {
    (my $myPack, my Opts $opts, my (@decls)) = m4i_args(@_);
    $myPack->declare_fields($opts, map {
        if (ref $_ and (my $name = $_->[0]) =~ s/-/_/g) {
            [$name, @{$_}[1..$#$_]];
        } elsif (not ref $_ and ($name = $_) =~ s/-/_/g) {
            $name;
        } else {
            $_;
        }
    } @decls);
}

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

    my $output = $self->can("output_as_".$primary_opts->{'output'})
      or Carp::croak("Unknown output format: $primary_opts->{'output'}");

    my @res;
    if ($primary_opts->{scalar}) {
      $res[0] = $sub->($self, @$arglist);
    } else {
      @res = $sub->($self, @$arglist);
    }

    if (not $primary_opts->{quiet}
        and ($primary_opts->{scalar} ? $res[0] : @res)) {

      $output->($self, \@res);
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

#----------------------------------------

sub output_as_json {
  (my MY $self, my $list) = @_;
  print JSON->new->utf8->canonical->encode($list), "\n";
}

sub output_as_tsv {
  (my MY $self, my $list) = @_;
  foreach my $item (lexpand($list)) {
    print join("\t", map {
      if (not defined $_) {
        $self->{'undef-as'}
      } elsif (ref $_) {
        JSON->new->utf8->canonical->encode($_)
      } else {
        $_
      }
    } lexpand($item)), "\n";
  }
}

sub output_as_dump {
  (my MY $self, my $list) = @_;
  foreach my $item (lexpand($list)) {
    print join("\t", map {
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
