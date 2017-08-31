# -*- mode: perl; coding: utf-8 -*-

requires perl => '>= 5.010';

requires 'rlib'; # XXX:

requires 'JSON';

recommends 'Module::Runtime';

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
};
