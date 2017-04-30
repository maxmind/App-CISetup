package App::CISetup::Travis::ConfigUpdater;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

our $VERSION = '0.01';

use App::CISetup::Travis::ConfigFile;
use App::CISetup::Types qw( Bool Str );

use Moose;

has email_address => (
    is        => 'ro',
    isa       => Str,                   # todo, better type
    predicate => 'has_email_address',
);

has force_threaded_perls => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has github_user => (
    is        => 'ro',
    isa       => Str,
    predicate => 'has_github_user',
);

has slack_key => (
    is        => 'ro',
    isa       => Str,
    predicate => 'has_slack_key',
);

with(
    'App::CISetup::Role::ConfigFileFinder' => {
        filename => '.travis.yml',
    },
    'MooseX::Getopt::Dashes',
);

sub run {
    my $self = shift;

    my $iter = $self->_config_file_iterator;

    my $count = 0;
    while ( my $file = $iter->() ) {
        $count++;
        App::CISetup::Travis::ConfigFile->new(
            file                 => $file,
            force_threaded_perls => $self->force_threaded_perls,
            (
                $self->has_email_address
                ? ( email_address => $self->email_address )
                : ()
            ),
            (
                $self->has_github_user
                ? ( github_user => $self->github_user )
                : ()
            ),
            ( $self->has_slack_key ? ( slack_key => $self->slack_key ) : () ),
        )->update_file;
    }

    warn "WARNING: No .travis.yml files found\n"
        unless $count;

    return 0;
}

__PACKAGE__->meta->make_immutable;
1;
