# -*- mode: perl; coding: utf-8 -*-

requires perl => '5.10';

on test => sub {
  requires rlib => 0;
  requires 'Test::Kantan' => 0;
};
