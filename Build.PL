use strict;
use warnings;
use Module::Build::Pluggable 'CPANfile';
use rlib '..', '../..';
use FindBin;

my $builder = Module::Build::Pluggable->new
  (dist_name           => 'MOP4Import'
   , dist_author       => q{KOBAYASHI, Hiroaki <hkoba@cpan.org>},
   , dist_version_from => 'Declare.pm'
   , dist_abstract     => 'Thin Meta-Object Protocol For Import'
   , license           => 'perl'
 );

$builder->create_build_script();
