use strict;
use warnings;
use FindBin; BEGIN { do "$FindBin::Bin/t_lib.pl" }
use Test::More;
use Test::Output;

my $cli;

{
    package CLI_Opts::Test;
    use MOP4Import::Base::CLI_Opts
        [options =>
            [
                'foo|f=s' => doc => "Foo!", required => 1, default => "abc",
            ],
            [
                'bar|b=i' => doc => "bar!", required => 1,
            ],
            [
                'baz|z=i' => doc => "baz!", default => 123, for_subcmd => 1,
            ],
            [
                'huga|h' => doc => "huga!", for_subcmd => 1,
            ],
            [
                'hoge|H=i' => doc => "huga!", for_subcmd => 1,
            ],
        ],
    ;
    sub cmd_default {
        my ( $c, @args ) = @_;
        $cli = $c;
    }
    sub cmd_hello {
        my ( $c, @args ) = @_;
        $cli = $c;
        print "Hello ", @args;
    }
}

eval { CLI_Opts::Test->run([qw//]) };
like($@, qr/bar is required./, 'bar is required');

stdout_is( sub { CLI_Opts::Test->run([qw/--bar 123 hello/]); }, 'Hello ' );
is_deeply( $cli, default_state(bar => 123) );

stdout_is( sub { CLI_Opts::Test->run([qw/--bar 123 hello --baz 123/]); }, 'Hello ' );
is_deeply( $cli, default_state(bar => 123) );

stdout_is( sub { CLI_Opts::Test->run([qw/--bar 123 hello -h blah/]); }, 'Hello blah' );
is_deeply( $cli, default_state(bar => 123, huga => 1) );

stdout_is( sub { CLI_Opts::Test->run([qw/--bar 321 hello -z 456 "--foo"/]); }, 'Hello "--foo"' );
is_deeply( $cli, default_state(bar => 321, baz => 456) );


done_testing;

sub default_state {
    my (%args) = @_;
    return {
        'foo' => 'abc',
        'baz' => 123,
        '_cmd' => ($cli->{_cmd} // 'default'),
        %args,
    };
}
