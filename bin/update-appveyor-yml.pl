#!/usr/bin/perl

use strict;
use warnings;

use App::CISetup::AppVeyor::ConfigUpdater;
App::CISetup::AppVeyor::ConfigUpdater->new_with_options->run;