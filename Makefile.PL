use inc::Module::Install;
name 'MOP4Import-Declare';
all_from 'lib/MOP4Import/Declare.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
