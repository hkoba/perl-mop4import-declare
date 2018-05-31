package MOP4Import::Base::CLI;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use mro qw/c3/;

use File::Basename ();
use Data::Dumper ();

use MOP4Import::Base::Configure -as_base, qw/FieldSpec/
  , [fields =>
     [quiet => doc => 'to be (somewhat) quiet']
   ];
use MOP4Import::Util qw/parse_opts terse_dump fields_hash fields_array
			take_hash_opts_maybe/;
use MOP4Import::Util::FindMethods;

#========================================

sub run {
  my ($class, $arglist, $opt_alias) = @_;

  my MY $self = $class->new($class->parse_opts($arglist, undef, $opt_alias));

  unless (@$arglist) {
    # Invoke help command if no arguments are given.
    $self->cmd_help;
    return;
  }

  my $cmd = shift @$arglist;
  if (my $sub = $self->can("cmd_$cmd")) {
    # Invoke official command.

    $self->cli_precmd($cmd);

    $sub->($self, @$arglist);

  } elsif ($sub = $self->can($cmd)) {
    # Invoke internal methods.

    $self->cli_invoke_sub_for_cmd($cmd, $sub, $self, @$arglist);

  } else {
    $self->cmd_help("Error: No such subcommand '$cmd'\n");
  }
}

sub cli_precmd {} # hook called just before cmd_zzz

sub cli_invoke_sub_for_cmd {
  (my MY $self, my ($cmd, $sub, @args)) = @_;

  $self->cli_precmd($cmd);

  my @res = $sub->(@args);
  print join("\n", map {terse_dump($_)} @res), "\n"
    if not $self->{quiet} and @res;

  if ($cmd =~ /^has_/) {
    # If method name starts with 'has_' and result is empty,
    # exit with 1.
    exit(@res ? 0 : 1);

  } elsif ($cmd =~ /^is_/) {
    # If method name starts with 'is_' and first result is false,
    # exit with 1.
    exit($res[0] ? 0 : 1);
  }
}

sub cmd_help {
  my $self = shift;
  my $pack = ref $self || $self;
  my $fields = fields_hash($self);
  my $names = fields_array($self);
  my @methods = FindMethods($pack, sub {s/^cmd_//});
  die join("\n", @_, <<END);
Usage: @{[File::Basename::basename($0)]} [--opt=value].. <command> [--opt=value].. ARGS...

Commands:
  @{[join("\n  ", @methods)]}

Options: 
  --@{[join "\n  --", map {
  if (ref (my FieldSpec $fs = $fields->{$_})) {
    join("\t  ", $_, ($fs->{doc} ? $fs->{doc} : ()));
  } else {
    $_
  }
} grep {/^[a-z]/} @$names]}
END
}

1;
