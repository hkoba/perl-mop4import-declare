# -*- mode: perl; coding: utf-8 -*-

requires perl => '>= 5.010';
configure_requires 'Module::CPANfile';
configure_requires 'Module::Build';

on test => sub {
  requires 'rlib';
  requires 'Test::Kantan';
};
