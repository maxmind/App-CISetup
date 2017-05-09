#!/usr/bin/perl

use strict;
use warnings;

use App::CISetup::AppVeyor::ConfigUpdater;

exit App::CISetup::AppVeyor::ConfigUpdater->new_with_options->run;

__END__

=pod

=head1 NAME - setup-appveyor-yml.pl

=head1 DESCRIPTION

This script updates existing appveyor.yml files with various settings from the
command line. Currently all this does is update the notifications block for
Slack and email notifications.  It also reorders the top-level keys in the
YAML file and does some other minor cleanups.

B<This script needs more work before it's really useful. Patches are welcome.>

=cut
