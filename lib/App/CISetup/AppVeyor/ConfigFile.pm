package App::CISetup::AppVeyor::ConfigFile;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

our $VERSION = '0.01';

use App::CISetup::Types qw( Str );

use Moose;

has email_address => (
    is        => 'ro',
    isa       => Str,                   # todo, better type
    predicate => 'has_email_address',
);

has encrypted_slack_key => (
    is        => 'ro',
    isa       => Str,
    predicate => 'has_encrypted_slack_key',
);

with 'App::CISetup::Role::ConfigFile';

## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
sub _update_config {
    my $self     = shift;
    my $appveyor = shift;

    $self->_update_notifications($appveyor);

    return;
}
## use critic

sub _update_notifications {
    my $self     = shift;
    my $appveyor = shift;

    my @notifications;
    $appveyor->{notifications} = \@notifications;

    push @notifications, {
        provider   => 'Slack',
        auth_token => {
            secure => $self->encrypted_slack_key,
        },
        channel                 => 'ci',
        on_build_failure        => 'true',
        on_build_status_changed => 'true',
        on_build_success        => 'true',
    } if $self->has_encrypted_slack_key;

    push @notifications, {
        provider                => 'Email',
        subject                 => 'AppVeyor build {{status}}',
        to                      => [ $self->email_address ],
        on_build_failure        => 'true',
        on_build_status_changed => 'true',
        on_build_success        => 'false',
    } if $self->has_email_address;

    return;
}

my @BlocksOrder = qw(
    version
    os
    before_build
    install
    build
    build_script
    test_script
    notifications
);

## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
sub _fix_up_yaml {
    my $self = shift;
    my $yaml = shift;

    return $self->_reorder_yaml_blocks( $yaml, \@BlocksOrder );
}
## use critic

__PACKAGE__->meta->make_immutable;

1;
