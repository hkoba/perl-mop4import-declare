package MOP4Import::Base::CLI;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use mro qw/c3/;

use File::Basename ();
use Data::Dumper ();

use MOP4Import::Base::Configure -as_base;
use MOP4Import::Util qw/parse_opts terse_dump fields_hash/;
use MOP4Import::Util::FindMethods;

#========================================

sub run {
  my ($class, $arglist, $opt_alias) = @_;
  my MY $self = $class->new($class->parse_opts($arglist, undef, $opt_alias));
  unless (@$arglist) {
    $self->cmd_help
  }
  my $cmd = shift @$arglist;
  if (my $sub = $self->can("cmd_$cmd")) {
    $self->configure($class->parse_opts($arglist, undef, $opt_alias));
    $sub->($self, @$arglist);
  } elsif ($sub = $self->can($cmd)) {
    $self->configure($class->parse_opts($arglist, undef, $opt_alias));
    if ($cmd =~ /^is/) {
      exit($sub->($self, @$arglist) ? 0 : 1);
    } else {
      my @res = $sub->($self, @$arglist);
      print join("\n", map {terse_dump($_)} @res), "\n" if @res;
    }
  } else {
    die "$0: No such command $cmd\n";
  }
}

sub run_with_context {
  my ($class, $arglist, $opt_alias) = @_;
  my MY $self = $class->new($class->parse_opts($arglist, undef, $opt_alias));
  unless (@$arglist) {
    $self->cmd_help
  }
  my $cmd = shift @$arglist;
  if (my $sub = $self->can("cmd_$cmd")) {
    $sub->($self, $self->parse_opts($arglist, +{}), @$arglist);
  } elsif ($sub = $self->can($cmd)) {
    if ($cmd =~ /^is/) {
      exit($sub->($self, $self->parse_opts($arglist, +{}), @$arglist) ? 0 : 1);
    } else {
      my @res = $sub->($self, $self->parse_opts($arglist, +{}), @$arglist);
      print join("\n", map {terse_dump($_)} @res), "\n" if @res;
    }
  } else {
    die "$0: No such command $cmd\n";
  }
}

sub cmd_help {
  my $self = shift;
  my $pack = ref $self || $self;
  my $fields = fields_hash($self);
  my @methods = FindMethods($pack, sub {s/^cmd_//});
  die join("\n", @_, <<END);
Usage: @{[File::Basename::basename($0)]} [--opt-value].. <command> [--opt-value].. ARGS...

Commands:
  @{[join("\n  ", @methods)]}

Options:
  --@{[join "\n  --", sort grep {/^[a-z]/} keys %$fields]}
END
}

1;
