package MOP4Import::Base::CLI_Opts;
use strict;
use warnings;
use MOP4Import::Base::CLI -as_base
#  , [extend => FieldSpec => qw/type alias/]
  , [fields => qw/_cmd __cmd/]
;
use MOP4Import::Opts;
use Carp ();
use Data::Dumper;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Types::Extend
      FieldSpec => [[fields => qw/type alias command real_name required for_subcmd/]];

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
        push @$o, real_name => $name;
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
    my $preserve = (ref($result) && scalar(@$result) && $result->[0]) ? shift(@$result) : {};
    unshift @{ $result }, { %$preserve, without_value => {} }; # SUPER::parse_optsで失われると困る情報を保持

    {
        foreach my $name (keys %$fields) {
            my FieldSpec $spec = $fields->{$name};
            if ( UNIVERSAL::isa($spec, FieldSpec) ) {
                if ($preserve->{for_subcmd} and not $spec->{for_subcmd}) {
                    next;
                }
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
    my $req_value;
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
                        if (not $req_value) {
                            $req_value = $myaby_opts;
                        }
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
                    if (not $req_value) {
                        $req_value = _hyphen2underscore($1);
                    }
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
            $req_value = '';
        }
    }
    #print Dumper($list);
    #print Dumper(\@stack);
    @$list = @stack;

    if ($req_value) {
        $result->[0]->{without_value}->{ $req_value } = 1;
    }

    $class->SUPER::parse_opts($list, $result, \%alias, @rest);
}


sub configure {
    my ( $self, @args ) = @_;
    my $fields = MOP4Import::Declare::fields_hash($self);
    my @res;
    my %map;
    my $command;

    my $preserved = shift @args;

    my (%required, %default);
    for my $spec ( values %$fields ) {
        next unless UNIVERSAL::isa($spec, FieldSpec);
        next if ( $preserved->{for_subcmd} && !$spec->{for_subcmd} );
        $required{ $spec->{name} } = $spec->{required} if exists $spec->{required};
        $default{ $spec->{name} }  = $spec->{default}  if exists $spec->{default};
        if ( $spec->{alias} && exists $preserved->{without_value}->{ $spec->{alias} } ) {
            $preserved->{without_value}->{ $spec->{name} } = $preserved->{without_value}->{ $spec->{alias} };
            delete $preserved->{without_value}->{ $spec->{alias} };
        }
    }

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

        delete $required{$name} if not exists $preserved->{without_value}->{ $name };
        delete $default{$name};

        push @res, $name;
        push @res, $val;
    }

    for my $key (keys %default) {
        push @res, $key, $default{$key};
        delete $required{$key};
    }
    if (%required) {
        my $opt = (sort keys %required)[0];
        Carp::croak("$opt is required.");
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
END

    my $max_len  = 0;
    my @opts = map {
        my FieldSpec $fs = $fields->{$_};
        my $str = do {
            if (ref $fs) {
                (do{ '  --' . (UNIVERSAL::isa($fs, FieldSpec) ? $fs->{real_name} : $_) } .
                    do{ UNIVERSAL::isa($fs, FieldSpec) and $fs->{ alias } ? ', -' . $fs->{ alias } : ''  },
                );
            }
            else {
                $_
            }
        };
        $max_len = length $str if length $str > $max_len;
        [ $str, $fs->{doc} ? $fs->{doc} : '' ];
    } grep {/^[a-z]/} @$names;

    $max_len += 2;

    print join("\n", <<END);

Options:
END

    for my $opt ( @opts ) {
        printf( "%-${max_len}s%s\n", @$opt );
    }

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
    $obj->{_cmd} = $cmd;
    my $result = [ { for_subcmd => 1 } ];
    $obj->configure(@{ $obj->parse_opts($arglist, $result) });
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
