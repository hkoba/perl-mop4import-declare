package MOP4Import::Base::CLI_Opts;
use strict;
use warnings;
use MOP4Import::Base::CLI -as_base
#  , [extend => FieldSpec => qw/type alias/]
  , [fields => qw/__cmd/]
;
use MOP4Import::Opts;
use Carp ();
use Data::Dumper;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Types::Extend
      FieldSpec => [[fields => qw/type alias command/]];

print STDERR "FieldSpec = ", FieldSpec, "\n" if DEBUG;


sub default_exports {
    my ($myPack) = @_;
    return (
      $myPack->SUPER::default_exports, [
            options =>
                ['help|h', 'command', 'help'],
                ['version', 'command', 'version'],
        ]
    );
}

sub default_options {
    return (
        help    => ['command' => 'help', 'type' => 'flag', 'alias' => 'h'],
        version => ['command' => 'version', 'type' => 'flag'],
        h       => ['command' => 'help', 'type' => 'flag'],
    );
}


sub _default_opt {
    my ( $myPack, $decls ) = @_;
    my %auto      = $myPack->default_options;
    my %rev_alias = map { # aliasの逆リンクをつくる
        my %pair = @{ $auto{$_} };
        defined $pair{alias} ? ($pair{alias} => $_) : ();
    } keys %auto;

    for my $dec (@$decls) {
        if ( $dec->[0] =~ /^([-a-zA-Z0-9]+)(?:\|([a-zA-Z0-9]))?(?:=[is]@?)?$/ ) {
            my $optname = $1;
            my $alias   = $2 // '';
            for my $k ( $optname, $alias ) {
                my $rev_alias = $rev_alias{$k};
                my %opt = @{$auto{$k} || []};
                if ( exists $opt{alias} ) { # オプションがユーザー定義されているならaliasも不要
                    delete $auto{$opt{alias}};
                }
                if ( $rev_alias ) {
                   my %pair = @{ $auto{$rev_alias} || [] };
                   delete $pair{alias};
                   $auto{$rev_alias} = [%pair] if exists $auto{$rev_alias};
                }
                delete $auto{$k};
            }
        }
    }

    for my $k ( sort keys %auto ) {
        push @$decls, [$k, @{$auto{$k}}];
    }
    #print "decls:", Dumper($decls);
}

sub declare_options {
    (my $myPack, my Opts $opts, my (@decls)) = m4i_args(@_);

    $myPack->_default_opt(\@decls);

    $myPack->declare_fields($opts, map {
        my $o = ref $_ ? $_ : [$_];

        unless ( $o->[0] =~ /([-\w]+)(?:\|([-\w]+))?(?:=([is]@?))?/ ) {
            Carp::croak("Invalid option format - " . $o->[0]);
        }

        my ($name, $alias, $type) = ($1, $2, $3);
        $type ||= 'flag';
        if (DEBUG) {
            print STDERR $name;
            if (defined $alias) {print " - $alias"}
            print STDERR " = $type";
            print "\n";
        }
        $name =~ s/-/_/g;
        $o->[0] = $name;
        push @$o, alias => $alias if defined $alias;
        push @$o, type => $type;
        $o;
    } @decls);
}

sub parse_opts {
    my ($class, $list, $result, @rest) = @_;
    my $fields = MOP4Import::Declare::fields_hash($class);
    print STDERR "fields for $class : ", Data::Dumper->new([$fields])->Dump, "\n" if DEBUG;

    my %alias;
    my $form = {};
    {
        foreach my $name (keys %$fields) {
            my FieldSpec $spec = $fields->{$name};
            if ( UNIVERSAL::isa($spec, FieldSpec) ) {
                $form->{ $name } = $spec if $spec->{type};
                if ( $spec->{alias} ) {
                    $alias{$spec->{alias}} = $name;
                    $form->{ $spec->{alias} } = $form->{ $name };
                }
            }
        }
    }
    print STDERR "option format: ", Data::Dumper->new([$form])->Dump, "\n" if DEBUG;
    my $key = 1;
    my @stack;
    my $cmd;
    for my $arg ( @$list ) {
        if ( $key ) {
            if ( $arg =~ /^-([^=]+)=(.+)$/ ) { # -f=foo
                push @stack, $arg;
            }
            elsif ( $arg =~ /^--([^=]+)=(.+)$/ ) { # --foo=baz
                push @stack, $arg;
            }
            elsif ( !$cmd && $arg =~ /^-([^-=]+)/ ) { # -fb( value)
                my $myaby_opts = $1;
                for my $s (split//, $myaby_opts) {
                    if ( not defined $form->{$s} ) {
                        Carp::croak("Invalid option format - " . $arg);
                    }
                    if ( $form->{$s}->{type} ne 'flag' ) {
                        push @stack, '-' . $s;
                        $key = 0;
                    }
                    else {
                        push @stack, '-' . $s;
                    }
                }
            }
            elsif ( !$cmd && $arg =~ /^--([^=]+)/ ) { # --bar( value)
                if ( not defined $form->{_hyphen2underscore($1)} ) {
                    Carp::croak("Invalid option format - " . $arg);
                }
                if ( $form->{_hyphen2underscore($1)}->{type} ne 'flag' ) {
                    push @stack, $arg;
                    $key = 0;
                }
                else {
                    push @stack, $arg;
                }
            }
            else { # perhaps this is command!
                $cmd = $arg;
                push @stack, $arg;
            }
        }
        else { # change to Base::CLI aware format
            $stack[-1] .= '=' . $arg;
            $key = 1;
        }
    }
    #print Dumper($list);
    #print Dumper(\@stack);
    @$list = @stack;

    $class->SUPER::parse_opts($list, $result, \%alias, @rest);
}


sub configure {
    my ( $self, @args ) = @_;
    my $fields = MOP4Import::Declare::fields_hash($self);
    my @res;
    my %map;
    my $command;
    while ( defined(my $name = shift @args) ) {
        my $type = $fields->{$name}->{type};
        my $val  = shift(@args);

        if ( $type =~ /(.)@/ ) {
            if ( $1 eq 'i' ) {
                if ( $val !~ /^[0-9]+$/ ) {
                    Carp::croak("option `$name` takes integer.");
                }
            }

            if (not exists $map{$name}) {
                push @res, $name;
                push @res, [$val];
                $map{$name} = $#res;
            }
            else {
                push @{ $res[ $map{$name} ] }, $val;
            }
            next;
        }
        elsif ( $type eq 'i' ) {
            if ( $val !~ /^[0-9]+$/ ) {
                Carp::croak("option `$name` takes integer.");
            }
        }

        if ( $fields->{$name}->{command} ) {
            if ( defined $command ) {
                Carp::croak("command invoking option was already called before `$name`.");
            }
            $command = $fields->{$name}->{command};
            $self->{__cmd} = [$command, $val];
            next;
        }

        push @res, $name;
        push @res, $val;
    }
    #print Dumper([@res]);
    $self->SUPER::configure(@res);
}


sub cmd_default { }

sub cmd_version {
    my $v = shift->VERSION // '0.0';
    print "$v\n";
}

sub cmd_help { # From  MOP4Import::Base::CLI, original cmd_help do 'die'
  my $self   = shift;
  my $pack   = ref $self || $self;
  my $fields = MOP4Import::Declare::fields_hash($self);
  my $names  = MOP4Import::Declare::fields_array($self);

  require MOP4Import::Util::FindMethods;

  my @methods = MOP4Import::Util::FindMethods::FindMethods($pack, sub {s/^cmd_//});
  print join("\n", <<END);
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
    exit();
}

sub run {
    my ($class, $arglist) = @_;
    my $default_cmd = 'default';
    my $fields = MOP4Import::Declare::fields_hash($class);
    # $arglist を parse し、 $class->new 用のパラメータリストを作る
    my @opts = $class->parse_opts($arglist);
    # $class->new する
    my $obj = $class->new(@opts);
    # 次の引数を取り出して、サブコマンドとして解釈を試みる
    my $cmd = shift @$arglist || _set_cmd_by_option($obj, $arglist) || $default_cmd;
    # サブコマンド毎の処理を行う
    # 結果を何らかの形式で出力する
    # 望ましい終了コードを返す（差し当たり、必要ならば各メソッド内で指定する）
    if (my $sub = $obj->can("cmd_$cmd")) {
        $sub->($obj, @$arglist);
    } else {
        print STDERR "Cmd `$cmd` is not implemented.\n";
        exit(1);
    }
}

sub _hyphen2underscore {
    my ($v) = @_;
    $v =~ tr/-/_/;
    return $v;
}

sub _set_cmd_by_option {
    my ($obj, $arglist) = @_;
    return unless $obj->{__cmd};
    push @$arglist, $obj->{__cmd}->[1];
    return $obj->{__cmd}->[0];
}

1;
