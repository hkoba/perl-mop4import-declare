package MOP4Import::Base::CLI_Opts;
use MOP4Import::Base::CLI -as_base
#  , [extend => FieldSpec => qw/type alias/]
;
use MOP4Import::Opts;
use Data::Dumper;

use constant DEBUG => $ENV{DEBUG_MOP4IMPORT};

use MOP4Import::Types::Extend
      FieldSpec => [[fields => qw/type alias/]];

print STDERR "FieldSpec = ", FieldSpec, "\n" if DEBUG;

sub declare_options {
    (my $myPack, my Opts $opts, my (@decls)) = m4i_args(@_);
    $myPack->declare_fields($opts, map {
        my $o = ref $_ ? $_ : [$_];

        unless ( $o->[0] =~ /([-\w]+)(?:\|([-\w]+))?(?:=([is]@?))?/ ) {
            require Carp;
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

    my $key = 1;
    my @stack;
    my $cmd;
    for my $arg ( @$list ) {
        print "`$arg`\n";
        if ( $key ) {
            if ( $arg =~ /^--?([^=]+)=(.+)$/ ) {
                push @stack, $arg;
            }
            elsif ( !$cmd && $arg =~ /^--?([^=]+)/ ) {
                if ( not defined $form->{$1} ) {
                    ...
                }
                elsif ( $form->{$1}->{type} ne 'flag' ) {
                    push @stack, $arg;
                    $key = 0;
                }
                else {
                    push @stack, $arg;
                }
            }
            else {
                $cmd = $arg;
                push @stack, $arg;
            }
        }
        else {
            $stack[-1] .= '=' . $arg;
            $key = 1;
        }
    }
#    print Dumper($list);
#    print Dumper(\@stack);

    @$list = @stack;

    $class->SUPER::parse_opts($list, $result, \%alias, @rest);
}

sub run {
    my ($class, $arglist) = @_;
    # $arglist を parse し、 $class->new 用のパラメータリストを作る
    my @opts = $class->parse_opts($arglist);
    # $class->new する
    my $obj = $class->new(@opts);
    # 次の引数を取り出して、サブコマンドとして解釈を試みる
    my $cmd = shift @$arglist || "help";
    # サブコマンド毎の処理を行う
    if (my $sub = $obj->can("cmd_$cmd")) {
        $sub->($obj, @$arglist);
    } else {
        print STDERR "Cmd `$cmd` is not implemented.\n";
        exit(1);
    }
    # 結果を何らかの形式で出力する
    # 望ましい終了コードを返す
}

1;
