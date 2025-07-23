#!/usr/bin/env perl
# -*- mode: perl; coding: utf-8 -*-
#----------------------------------------
use strict;
use warnings qw(FATAL all NONFATAL misc);
use Carp;
use FindBin; BEGIN { do "$FindBin::Bin/t_lib.pl" }

use Test::More;
use Test2::Tools::Command;

my $prog = "$FindBin::Bin/../Base/CLI_JSON.pm";

command {
  args => [$prog, qw(cli_xargs_json cli_array)]
    , stdin => qq{{}},
    , stdout => qq{[{}]\n}
};

done_testing();
