#!/usr/bin/env perl
package MOP4Import::Base::CLI;
use strict;
use warnings qw(FATAL all NONFATAL misc);
use mro qw/c3/;

use File::Basename ();
use Data::Dumper ();

use attributes ();

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Base::Configure -as_base, qw/FieldSpec/;

use MOP4Import::Util qw/terse_dump fields_hash fields_array
			take_hash_opts_maybe/;
use MOP4Import::Util::FindMethods;

use List::Util ();

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

  } elsif ($self->can($cmd)) {
    # Invoke unofficial internal methods. Development aid.

    $self->cli_invoke($cmd, @$arglist);

  } else {
    # Last resort. You can implement your own subcommand interpretations here.

    $self->cli_unknown_subcommand($cmd, $arglist);
  }
}

#========================================
# Hooks and default implementations
#========================================

#
# Each class can override parse_opts method.
#
sub parse_opts {
  my ($pack, $list, $result, $opt_alias) = @_;

  MOP4Import::Util::parse_opts($pack, $list, $result, $opt_alias);
}

sub cli_precmd {} # hook called just before cmd_zzz

sub cli_invoke {
  (my MY $self, my ($method, @args)) = @_;

  $self->cli_precmd($method);

  my @res = $self->$method(@args);
  $self->cli_output(\@res) if @res;

  if ($method =~ /^has_/) {
    # If method name starts with 'has_' and result is empty,
    # exit with 1.
    exit(@res ? 0 : 1);

  } elsif ($method =~ /^is_/) {
    # If method name starts with 'is_' and first result is false,
    # exit with 1.
    exit($res[0] ? 0 : 1);
  }
}

sub cli_output {
  (my MY $self, my $res) = @_;
  print join("\n", map {terse_dump($_)} @$res), "\n";
}

sub cli_unknown_subcommand {
  (my MY $self, my ($cmd, $arglist)) = @_;

  $self->cmd_help("Error: No such subcommand '$cmd'\n");
}

#========================================

sub onconfigure_help {
  (my MY $self, my $val) = @_;
  $self->cmd_help;
  exit;
}

sub cmd_help {
  my $self = shift;
  my $pack = ref $self || $self;

  # Invoke precmd (mainly for binmode handling)
  $self->cli_precmd();

  my @msg = (join("\n", @_, <<END));
Usage: @{[File::Basename::basename($0)]} [--opt=value].. <Command> ARGS...

Commands:
END

  push @msg, map {$self->cli_format_command($_)} $self->cli_list_commands;

  my @options = $self->cli_group_options;
  my $maxlen = $self->cli_max_option_length;

  foreach my $group (@options) {
    my ($pkg, @fields) = @$group;
    push @msg, <<END;

Options from $pkg:
END
    foreach my FieldSpec $fs (@fields) {
      push @msg, $self->cli_format_option($fs, $maxlen);
    }
  }

  die join("", @msg);
}

sub cli_list_commands {
  my $self = shift;
  my $pack = ref $self || $self;
  FindMethods($pack, sub {s/^cmd_//});
}

sub cli_format_command {
  my ($self, $name) = @_;
  "  ".join("        ", $name, $self->cli_info_command_doc($name))."\n";
}

sub cli_group_options {
  my $self = shift;
  my $fields = fields_hash($self);
  my %package;
  foreach my $name (@{fields_array($self)}) {
    next unless $name =~ /^[a-z]/;
    my FieldSpec $spec = $fields->{$name};
    push @{$package{$spec->{package}}}, $spec;
  }

  my $isa = mro::get_linear_isa(ref $self);

  map {
    $package{$_} ? [$_, @{$package{$_}}] : ();
  } @$isa;
}

sub cli_max_option_length {
  my $self = shift;
  my $fields = fields_hash($self);
  my @name = grep {/^[a-z]/} @{fields_array($self)};
  List::Util::max(map {length} @name);
}

sub cli_format_option {
  (my MY $self, my FieldSpec $fs, my $maxlen) = @_;
  my $len = ($maxlen // 16);
  sprintf "  --%-${len}s  %s\n", $fs->{name}, $fs->{doc} // "";
}

# Poorman's code attribute handler, only for Doc().
{
  my %cmd_doc;

  sub MODIFY_CODE_ATTRIBUTES {
    my ($pack, $sub, @attrs) = @_;
    print "Got attrs: @attrs\n" if DEBUG;
    map {
      my $cp = $_;
      if ($cp =~ s/^Doc\(//i) {
        $cp =~ s/\)$//;
        $cp =~ s/^\"(.*?)\"$/$1/s;
        $cp =~ s/^\'(.*?)\'$/$1/s;
        $cmd_doc{$sub} = $cp;
        ();
      } else {
        $_;
      }
    } @attrs;
  }

  sub cli_info_command_doc {
    my ($self, $name) = @_;
    my $sub = $self->can("cmd_$name")
      or Carp::croak "No such command: $name";
    my $doc = $cmd_doc{$sub};
    return unless defined $doc;
    $doc;
  }

  #
  # Since I'm not sure what can be returned from FETCH_CODE_ATTRIBUTES,
  # I don't provide it at least for now.
  #
  # sub FETCH_CODE_ATTRIBUTES {
  #   my ($pack, $sub) = @_;
  #   my @attr;
  #   if (my $doc = $cmd_doc{$sub}) {
  #     (Doc => $doc);
  #   }
  # }
}

MY->run(\@ARGV) unless caller;

1;
