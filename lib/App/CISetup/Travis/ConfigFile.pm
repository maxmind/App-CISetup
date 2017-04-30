package App::CISetup::Travis::ConfigFile;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

our $VERSION = '0.01';

use File::pushd;
use IPC::Run3 qw( run3 );
use List::AllUtils qw( first_index uniq );
use App::CISetup::Types qw( Bool File Str );
use Try::Tiny;
use YAML qw( Dump LoadFile );

use Moose;

has email_address => (
    is        => 'ro',
    isa       => Str,                   # todo, better type
    predicate => 'has_email_address',
);

has file => (
    is       => 'ro',
    isa      => File,
    required => 1,
);

has force_threaded_perls => (
    is  => 'ro',
    isa => Bool,
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

with 'App::CISetup::Role::ConfigFile';

## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
sub _update_config {
    my $self   = shift;
    my $travis = shift;

    $self->_maybe_update_travis_perl_usage($travis);
    $self->_maybe_disable_sudo($travis);
    $self->_update_coverity_email($travis);
    $self->_update_notifications($travis);

    return;
}
## use critic

sub _maybe_update_travis_perl_usage {
    my $self   = shift;
    my $travis = shift;

    return
        unless $travis->{before_install}
        && grep {/perl-travis-helper|travis-perl/}
        $travis->{before_install}->@*;

    $self->_fixup_helpers_usage($travis);
    $self->_rewrite_perl_block($travis);
    $self->_update_perl_matrix($travis);

    return;
}

sub _fixup_helpers_usage {
    my $self   = shift;
    my $travis = shift;

    if (
        ( $travis->{script} && $travis->{script}->@* > 3 )
        || (
            $travis->{install}
            && ( grep { !/cpan-install/ } $travis->{install}->@*
                || $travis->{install}->@* > 2 )
        )
        ) {

        my $i = (
            first_index {/travis-perl|haarg/}
            $travis->{before_install}->@*
        ) // 0;
        $travis->{before_install}->[$i]
            = 'git clone git://github.com/travis-perl/helpers ~/travis-perl-helpers';
        $travis->{before_install}->[ $i + 1 ]
            = 'source ~/travis-perl-helpers/init';
    }
    else {
        delete $travis->{install};
        delete $travis->{script};

        my $i = (
            first_index {/travis-perl|haarg/}
            $travis->{before_install}->@*
        ) // 0;
        $travis->{before_install}[$i]
            = 'eval $(curl https://travis-perl.github.io/init) --auto';
        splice( $travis->{before_install}->@*, $i + 1, 0 );
    }

    return;
}

# XXX - if a build is intentionally excluding Perls besides 5.8 this will add
# those Perls back. Not sure how best to deal with this. We want to test on
# all Perls for most modules, and any manually generated file might forget to
# include some of them.
sub _rewrite_perl_block {
    my $self   = shift;
    my $travis = shift;

    my @perls = qw(
        blead
        dev
        5.24.0
        5.22.1
        5.20.3
        5.18.3
        5.16.3
        5.14.4
        5.12.5
        5.10.1
        5.8.8
    );

    for my $perl (qw( 5.8 5.10 5.12 )) {
        pop @perls
            unless grep {/\Q$perl/} $travis->{perl}->@*;
    }

    my $has_xs
        = defined Path::Iterator::Rule->new->file->name(qr/\.xs/)
        ->iter( $self->file->parent )->();

    if ( $self->force_threaded_perls || $has_xs ) {
        $travis->{perl} = [ map { ( $_, $_ . '-thr' ) } @perls ];
    }
    else {
        # If we don't need threads we can just ask for 5.x and the
        # travis-helpers will find the latest patch version that it has
        # pre-built and give that to us.
        $travis->{perl} = [ map { $_ =~ s/\.\d+$//r } @perls ];
    }

    return;
}

sub _update_perl_matrix {
    my $self   = shift;
    my $travis = shift;

    my @bleads = 'blead';
    push @bleads, 'blead-thr'
        if grep { $_ eq 'blead-thr' } @{ $travis->{perl} };

    $travis->{matrix} = {
        include => [
            {
                perl => '5.24',
                env  => 'COVERAGE=1',
            }
        ],
        allow_failures => [ map { { perl => $_ } } @bleads ],
    };

    return;
}

sub _maybe_disable_sudo {
    my $self   = shift;
    my $travis = shift;

    return
        if grep {/sudo/}
        map { ref $travis->{$_} ? $travis->{$_}->@* : $travis->{$_} }
        grep { exists $travis->{$_} } qw( before_install install );

    $travis->{sudo} = 0;

    my @addons
        = $travis->{addons}
        && $travis->{addons}{apt} && $travis->{addons}{apt}{packages}
        ? $travis->{addons}{apt}{packages}->@*
        : ();
    push @addons, qw( aspell aspell-en )
        if $travis->{perl};
    $travis->{addons}{apt}{packages} = [ sort { $a cmp $b } uniq(@addons) ]
        if @addons;

    return;
}

sub _update_coverity_email {
    my $self   = shift;
    my $travis = shift;

    return unless $self->has_email_address;
    return unless $travis->{addons} && $travis->{addons}{coverity_scan};
    $travis->{addons}{coverity_scan}{notification_email}
        = $self->email_address;
}

sub _update_notifications {
    my $self   = shift;
    my $travis = shift;

    if ( $self->has_email_address ) {
        $travis->{notifications}{email} = {
            recipients => [ $self->email_address ],
            on_success => 'change',
            on_failure => 'always',
        };
    }

    if ( $self->has_slack_key && $self->has_github_user ) {
        my $slack = $travis->{notifications}{slack}{rooms}{secure};

        # travis encrypt will make a new encrypted version every time it's given
        # the same input so we don't want to run it unless we have to, otherwise
        # we end up with pointless updates.
        unless ($slack) {
            my $pushed = pushd( $self->file->dir );
            my $stdout;
            my $stderr;
            run3(
                [
                    'travis', 'encrypt', '--no-interactive',
                    '-R',
                    $self->github_user . '/' . $self->file->parent->basename,
                    $self->slack_key
                ],
                \undef,
                \$stdout,
                \$stderr,
            );
            die $stderr if $stderr;
            $slack = $stdout =~ s/^\"|\"$//gr;
        }

        $travis->{notifications}{slack} = {
            rooms => { secure => $slack },
        };
    }

    return;
}

my @BlocksOrder = qw(
    sudo
    addons
    language
    compiler
    go
    jdk
    perl
    php
    python
    solution
    matrix
    env
    services
    before_install
    install
    before_script
    script
    after_script
    after_success
    after_failure
    notifications
);

my %KnownBlocks = map { $_ => 1 } @BlocksOrder;

## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
sub _fix_up_yaml {
    my $self = shift;
    my $yaml = shift;

    $yaml =~ s/sudo: 0/sudo: false/g;

    return $self->_reorder_yaml_blocks( $yaml, \@BlocksOrder );
}

sub _reorder_addons_block {
    my $self  = shift;
    my $block = shift;

    return $block unless $block =~ /coverity_scan:\n(.+)(?=\S|\z)/ms;

    my %chunks;
    for my $line ( split /\n/, $1 ) {
        my ($name) = $line =~ / +([^:]+):/;
        $chunks{$name} = $line;
    }

    my $reordered = join q{}, map {"$chunks{$_}\n"}
        grep { $chunks{$_} }
        qw(
        project
        description
        name
        notification_email
        build_command_prepend
        build_command
        branch_pattern
    );

    return $block
        =~ s/coverity_scan:\n.+(?=\S|\z)/coverity_scan:\n$reordered/msr;
}
## use critic

__PACKAGE__->meta->make_immutable;

1;
