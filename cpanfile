# -*- mode: perl; coding: utf-8 -*-

requires perl => '>= 5.010';

requires 'rlib'; # XXX:

requires 'JSON::MaybeXS';

recommends 'Module::Runtime';
recommends 'YAML::Syck';
recommends 'Cpanel::JSON::XS', '>= 4.0';

on configure => sub {
  requires 'rlib';
  requires 'Module::Build::Pluggable';
  requires 'Module::CPANfile';
};

on build => sub {
  requires 'rlib'; # XXX:
};

on test => sub {
  requires 'Test::Kantan';
  requires 'Capture::Tiny';
  requires 'Test::Output';
  requires 'Test::Exit';
  requires 'YAML::Syck';
  requires 'Cpanel::JSON::XS', '>= 4.0';
};
