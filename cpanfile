# -*- mode: perl; coding: utf-8 -*-

requires perl => '>= 5.010';

on configure => sub {
  requires 'rlib';
  requires 'Module::Build::Pluggable';
  requires 'Module::CPANfile';
};

on test => sub {
  requires 'Test::Kantan';
};
