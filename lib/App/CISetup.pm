package App::CISetup;

use v5.12;
use strict;
use warnings;

our $VERSION = '0.01';

1;

# ABSTRACT: Command line tools to generate and update Travis and AppVeyor configs for Perl libraries

__END__

=pod

=head1 DESCRIPTION

This distro includes two command-line tools, L<update-travis-yml.pl> and
L<update-appveyor-yml.pl>. They update Travis and AppVeyor YAML config files
with some opinionated defaults. See the docs for the respective scripts for
more details.

