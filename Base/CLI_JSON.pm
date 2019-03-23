#!/usr/bin/env perl
package MOP4Import::Base::CLI_JSON;
use MOP4Import::Base::CLI -as_base
  , [constant => parse_opts__preserve_hyphen => 1]
  , [fields =>
     , ['help' => doc => "show this help message"]
     , ['quiet' => doc => 'to be (somewhat) quiet']
     , ['scalar' => doc => "evaluate methods in scalar context"]
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
use MOP4Import::Util qw/lexpand globref/;

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

    if ($self->{scalar} or $self->{flatten}) {
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

#========================================

sub cli_array {
  (my MY $self, my @args) = @_;
  wantarray ? @args : \@args;
}

sub cli_object {
  (my MY $self, my %args) = @_;
  \%args;
}

sub cli_map_apply {
  (my MY $self, my ($subOrArray, @args)) = @_;
  map {
    $self->cli_apply($subOrArray, $_);
  } @args;
}

sub cli_grep_apply {
  (my MY $self, my ($subOrArray, @args)) = @_;
  grep {
    $self->cli_apply($subOrArray, $_);
  } @args;
}

# XXX: How about cli_reduce_apply?

sub cli_apply {
  (my MY $self, my ($subOrArrayOrString, @args)) = @_;
  if (not defined $subOrArrayOrString) {
    Carp::croak "undefined sub for cli_apply";
  } elsif (ref $subOrArrayOrString eq 'CODE') {
    $subOrArrayOrString->(@args);
  } elsif (not ref $subOrArrayOrString or ref $subOrArrayOrString eq 'ARRAY') {
    my ($meth, @opts) = lexpand($subOrArrayOrString);
    $self->$meth(@opts, @args);
  } else {
    Carp::croak "Invalid argument for cli_apply: "
      . MOP4Import::Util::terse_dump($subOrArrayOrString);
  }
}

#========================================

sub declare_output_format {
  (my $myPack, my Opts $opts, my ($formatName, $sub)) = m4i_args(@_);
  my $writeFuncName = "cli_write_fh_as_$formatName";
  my $outputFuncName = "cli_output_as_$formatName";
  if (ref $sub eq 'CODE') {
    *{globref($opts->{destpkg}, $writeFuncName)} = $sub;
    *{globref($opts->{destpkg}, $outputFuncName)} = sub {
      shift->$writeFuncName(\*STDOUT, $_[0]);
    };
  } elsif (not defined $sub) {
    unless ($opts->{destpkg}->can($writeFuncName)) {
      Carp::croak "output_format $formatName doesn't have method '$writeFuncName'";
    }
    *{globref($opts->{destpkg}, $outputFuncName)} = sub {
      shift->$writeFuncName(\*STDOUT, $_[0]);
    };
  } else {
    Carp::croak "Invalid argument for output_format: "
      . MOP4Import::Util::terse_dump($sub);
  }
}

sub cli_output {
  (my MY $self, my ($list)) = @_;

  $self->cli_write_fh(\*STDOUT, $list);
}

sub cli_write_fh {
  (my MY $self, my ($outFH, @args)) = @_;
  my $output = $self->can("cli_write_fh_as_".$self->{'output'})
    or Carp::croak("Unknown output format: $self->{'output'}");

  $output->($self, $outFH, @args);
}

sub cli_encode_json {
  (my MY $self, my $obj) = @_;
  my $codec = $self->{_cli_json} //= do {
    my $js = JSON->new->canonical->allow_nonref;
    $js->utf8 unless $self->{binary};
    $js;
  };
  my $json = $codec->encode($obj);
  Encode::_utf8_on($json) unless $self->{binary};
  $json;
}

#----------------------------------------

MY->declare_output_format(MY, 'json');
sub cli_write_fh_as_json {
  (my MY $self, my ($outFH, @args)) = @_;
  foreach my $list (@args) {
    print $outFH $self->cli_encode_json($list), "\n";
  }
}

MY->declare_output_format(MY, 'tsv');
sub cli_write_fh_as_tsv {
  (my MY $self, my ($outFH, @args)) = @_;
  foreach my $list (@args) {
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
}

MY->declare_output_format(MY, 'dump');
sub cli_write_fh_as_dump {
  (my MY $self, my ($outFH, @args)) = @_;
  foreach my $list (@args) {
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
}

MY->declare_output_format(MY, 'raw');
sub cli_write_fh_as_raw {
  (my MY $self, my ($outFH, @args)) = @_;
  foreach my $list (@args) {
    print $outFH $list;
  }
}

#========================================

sub cli_create_from_file {
  my ($class, $configFn, @moreOpts) = @_;
  my $realConfigFn = File::Spec->rel2abs($configFn);
  my $oldcwd = $ENV{PWD} || do {require Cwd; Cwd::getcwd()};
  my $realDir = File::Basename::dirname($realConfigFn);
  chdir($realDir)
    or Carp::croak "Can't chdir to $realDir: $!";

  # Read $configFn with scalar context.
  my $opts = $class->cli_read_file($realConfigFn);

  my $object = $class->new(
    ref $opts eq 'HASH' ? %$opts : @$opts,
    @moreOpts
  );
  chdir($oldcwd)
    or Carp::croak "Can't chdir back to $oldcwd: $!";
  $object;
}

sub cli_read_file {
  my ($classOrObj, $fileName) = @_;
  my ($ftype) = $fileName =~ m{\.(\w+)$};
  $ftype //= "";

  my $sub = $classOrObj->can("cli_read_file__$ftype")
    or Carp::croak "Unsupported file type '$ftype': $fileName";

  $sub->($classOrObj, $fileName);
}

# No filename extension => read entire content except last \n.
sub cli_read_file__ {
  my ($classOrObj, $fileName) = @_;
  open my $fh, '<:utf8', $fileName
    or Carp::croak "Can't open $fileName: $!";
  my $all = do {local $/; <$fh>};
  chomp($all);
  $all;
}

# .txt => array of lines
sub cli_read_file__txt {
  my ($classOrObj, $fileName) = @_;
  my $all = $classOrObj->cli_read_file__($fileName);
  my @list = split "\n", $all;
  wantarray ? @list : \@list;
}

# .yml
sub cli_read_file__yml {
  my ($classOrObj, $fileName) = @_;
  require YAML::Syck;
  YAML::Syck::LoadFile($fileName);
}

# .json
sub cli_read_file__json {
  my ($classOrObj, $fileName) = @_;
  open my $fh, '<', $fileName
    or Carp::croak "Can't open $fileName: $!";
  JSON::decode_json(do {local $/; <$fh>});
}

MY->run(\@ARGV) unless caller;

1;
