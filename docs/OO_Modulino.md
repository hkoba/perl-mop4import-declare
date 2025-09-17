# The OO Modulino Pattern

## Overview

OO Modulino (Object-Oriented Modulino) is a pattern where a single Perl file functions as both a "class module" and a "CLI executable". This pattern allows you to test and execute any method of a module directly from the CLI without writing external scripts.

## What is a Modulino?

A Modulino is a Perl file that can act as both a module and an executable ([reference](https://www.masteringperl.org/category/chapters/modulinos/)).

In a regular Modulino, which functions are accessible from CLI depends on the implementation. To use arbitrary functions, you often still need to write scripts.

## OO Modulino Characteristics

OO Modulino extends Modulino by standardizing CLI behavior:

1. **Object-oriented**: Creates instances and invokes methods
2. **Standardized CLI**: Git-like subcommand format
3. **Flexible parameters**: Separation of constructor options and method arguments

## Basic Implementation Examples

### Simple Example

```perl
package Greetings;
use strict;
use warnings;

sub new  { my $class = shift; bless +{@_}, $class }

sub hello { my $self = shift; join " ", "Hello", $self->{name} }

sub goodnight { my $self = shift; join(" ", "Good night" => $self->{name}, @_) }

1;
```

To use this module from CLI normally:

```bash
$ perl -I. -MGreetings -le 'print Greetings->new(name => "world")->hello'
```

### Minimal OO Modulino

```perl
#!/usr/bin/env perl
package Greetings_oo_modulino;
use strict;
use warnings;

unless (caller) {
    my $self = __PACKAGE__;

    my $cmd = shift
      or die "Usage: $0 COMMAND ARGS...\n";

    print $self->new(name => "world")->$cmd(@ARGV), "\n";
}

sub new  { my $class = shift; bless +{@_}, $class }

sub hello { my $self = shift; join " ", "Hello", $self->{name} }

sub goodnight { my $self = shift; join(" ", "Good night" => $self->{name}, @_) }

1;
```

Usage:

```bash
$ ./Greetings_oo_modulino.pm hello
Hello world
```

### With Constructor Options

```perl
#!/usr/bin/env perl
package Greetings_with_options;
use strict;
use warnings;
use fields qw/name/;

sub MY () {__PACKAGE__}

unless (caller) {
    my $self = MY->new(name => 'world', MY->_parse_posix_opts(\@ARGV));

    my $cmd = shift @ARGV
      or die "Usage: $0 [OPTIONS] COMMAND ARGS...\n";

    print $self->$cmd(@ARGV), "\n";
}

sub _parse_posix_opts {
    my ($class, $list) = @_;
    my @opts;
    while (@$list and $list->[0] =~ /^--(?:(\w+)(?:=(.*))?)?\z/s) {
        shift @$list;
        last unless defined $1;
        push @opts, $1, $2 // 1;
    }
    @opts;
}

sub new  { my MY $self = fields::new(shift); %$self = @_; $self }

sub hello { my MY $self = shift; join " ", "Hello", $self->{name} }

sub goodnight { my MY $self = shift; join " ", "Good night" => $self->{name}, @_ }

1;
```

Usage:

```bash
$ ./Greetings_with_options.pm --name=Universe hello
Hello Universe

$ ./Greetings_with_options.pm --name=World goodnight everyone
Good night World everyone
```

## CLI Standardization

OO Modulino standardizes CLI with the following conventions:

### Command Line Format

```
program [GLOBAL_OPTIONS] COMMAND [COMMAND_ARGS]
```

- `GLOBAL_OPTIONS`: Passed to constructor (`--key=value` format)
- `COMMAND`: Method name to invoke
- `COMMAND_ARGS`: Arguments to the method

### Similarity to Git Commands

This design is inspired by git commands:

- `git --git-dir=/path commit -m "message"`
  - `--git-dir=/path`: Global option (git object configuration)
  - `commit`: Subcommand (method)
  - `-m "message"`: Command arguments

Similarly in OO Modulino:

- `./MyScript.pm --config=prod query "SELECT * FROM users"`
  - `--config=prod`: Constructor option
  - `query`: Method name
  - `"SELECT * FROM users"`: Method argument

## Type Safety with fields

Using the `fields` pragma provides:

1. **Compile-time type checking**: Prevents field name typos
2. **Invalid field rejection**: Errors on undefined field access

```perl
use fields qw/name age/;

sub new {
    my MY $self = fields::new(shift);
    %$self = @_;
    $self;
}

sub greet {
    my MY $self = shift;
    # $self->{nama} would be a compile-time error (typo detection)
    return "I'm $self->{name}, $self->{age} years old";
}
```

## Extensions with MOP4Import::Base::CLI_JSON

CLI_JSON extends the OO Modulino pattern with:

1. **JSON arguments/returns**: Complex data structure handling
2. **Auto-serialization**: Automatic JSON output of return values
3. **Rich output formats**: ndjson, json, yaml, tsv, dump
4. **Help functionality**: Automatic help message generation
5. **Automatic method exposure**: All public methods available without special configuration

## Summary

The OO Modulino pattern provides these benefits for Perl module development:

- **Immediate feedback**: Test methods as soon as you write them
- **Unified interface**: Consistent CLI conventions
- **Improved testability**: Easy testing in small units
- **Debugging ease**: Standard tools work out of the box

This enables consistent module handling from early development through production deployment.

## References

- [Modulino: both script and module](https://perlmaven.com/modulino-both-script-and-module)
- [Mastering Perl: Modulinos](https://www.masteringperl.org/category/chapters/modulinos/)
- [MOP4Import::Base::CLI_JSON](../Base/CLI_JSON.pod)