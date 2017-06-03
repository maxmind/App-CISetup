package T::Travis;

use strict;
use warnings;

use Test::Class::Moose bare => 1;
use Test2::Bundle::Extended '!meta';
use Test2::Plugin::NoWarnings;

use App::CISetup::Travis::ConfigFile;
use Path::Tiny qw( tempdir );
use YAML qw( DumpFile Load LoadFile );

sub test_create_and_update {
    my $dir  = tempdir();
    my $file = $dir->child('.travis.yml');

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
    )->create_file;

    my $yaml = $file->slurp;

    for my $v (qw( 5.14 5.16 5.18 5.20 5.22 5.24 )) {
        like(
            $yaml,
            qr/^ +- \Q'$v'\E$/ms,
            "created file includes Perl $v"
        );
    }

    for my $v (qw( 5.8 5.10 5.12 )) {
        unlike(
            $yaml,
            qr/^ +- \Q'$v'\E$/ms,
            "created file does not include Perl $v"
        );
    }

    like(
        $yaml,
        qr/
              ^sudo:.+\n
              ^addons:.+\n
              ^language:.+\n
              ^perl:.+\n
              ^matrix:.+\n
              ^env:.+\n
          before_install:.+\n
         /msx,
        'yaml blocks are in the right oder'
    );

    my $travis = Load($yaml);
    is(
        $travis,
        {
            sudo   => 'false',
            addons => {
                apt => {
                    packages => [ 'aspell', 'aspell-en' ],
                },
            },
            language => 'perl',
            perl     => [
                qw(
                    blead
                    dev
                    5.24
                    5.22
                    5.20
                    5.18
                    5.16
                    5.14
                    )
            ],
            matrix => {
                allow_failures => [ { perl => 'blead' } ],
                include        => [
                    {
                        env  => 'COVERAGE=1',
                        perl => '5.24'
                    }
                ],
            },
            env => { global => [ 'AUTHOR_TESTING=1', 'RELEASE_TESTING=1' ] },
            before_install =>
                ['eval $(curl https://travis-perl.github.io/init) --auto'],
        },
        'travis config contains expected content'
    );

    my $flags_block = <<'EOF';
### __app_cisetup__
# {force_threaded_perls => 0}
### __app_cisetup__
EOF
    _test_flags_block( $file, $flags_block );

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
    )->update_file;

    my $updated = LoadFile($file);
    is( $travis, $updated, 'file was not changed by update' );
}

sub test_force_threaded_perls {
    my $dir  = tempdir();
    my $file = $dir->child('.travis.yml');

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 1,
    )->create_file;

    my $yaml = $file->slurp;

    for my $v (qw( 5.14.4 5.16.3 5.18.3 5.20.3 5.22.3 5.24.1 )) {
        for my $t ( $v, "$v-thr" ) {
            like(
                $yaml,
                qr/^ +- \Q$t\E$/ms,
                "created file includes Perl $t"
            );
        }
    }

    my $flags_block = <<'EOF';
### __app_cisetup__
# {force_threaded_perls => 1}
### __app_cisetup__
EOF
    _test_flags_block( $file, $flags_block );
}

sub test_distro_has_xs {
    my $dir = tempdir();
    $dir->child('Foo.xs')->touch;
    my $file = $dir->child('.travis.yml');

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
    )->create_file;

    my $yaml = $file->slurp;

    for my $v (qw( 5.14.4 5.16.3 5.18.3 5.20.3 5.22.3 5.24.1 )) {
        for my $t ( $v, "$v-thr" ) {
            like(
                $yaml,
                qr/^ +- \Q$t\E$/ms,
                "created file includes Perl $t"
            );
        }
    }
}

sub test_update_helpers_usage {
    my $dir  = tempdir();
    my $file = $dir->child('.travis.yml');

    DumpFile(
        $file, {
            language       => 'perl',
            before_install => [
                '$(curl git://github.com/haarg/perl-travis-helper) --auto'
            ],
            perl => ['5.24'],
        }
    );

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
    )->update_file;

    my $travis = LoadFile($file);
    is(
        $travis->{before_install},
        ['eval $(curl https://travis-perl.github.io/init) --auto'],
        'old travis-perl URL is replaced'
    );

    my $flags_block = <<'EOF';
### __app_cisetup__
# {force_threaded_perls => 0}
### __app_cisetup__
EOF
    _test_flags_block( $file, $flags_block );
}

sub test_maybe_disable_sudo {
    my $dir  = tempdir();
    my $file = $dir->child('.travis.yml');

    DumpFile(
        $file, {
            sudo     => 'true',
            language => 'perl',
            before_install =>
                ['eval $(curl https://travis-perl.github.io/init) --auto'],
            perl => ['5.24'],
        }
    );

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
    )->update_file;

    is(
        LoadFile($file)->{sudo},
        'false',
        'sudo is disabled when it is not being used',
    );
    DumpFile(
        $file, {
            sudo     => 'true',
            language => 'perl',
            before_install =>
                ['eval $(curl https://travis-perl.github.io/init) --auto'],
            install => ['sudo foo'],
            perl    => ['5.24'],
        }
    );

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
    )->update_file;

    is(
        LoadFile($file)->{sudo},
        'true',
        'sudo is not disabled when it is being used',
    );
}

sub test_coverity_email {
    my $dir  = tempdir();
    my $file = $dir->child('.travis.yml');

    DumpFile(
        $file, {
            sudo     => 'true',
            language => 'perl',
            addons   => {
                coverity_scan => { notification_email => 'foo@example.com' }
            },
            before_install =>
                ['eval $(curl https://travis-perl.github.io/init) --auto'],
            perl => ['5.24'],
        }
    );

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
        email_address        => 'bar@example.com',
    )->update_file;

    is(
        LoadFile($file)->{addons}{coverity_scan},
        { notification_email => 'bar@example.com' },
        'email address for coverity_scan is updated',
    );

    my $flags_block = <<'EOF';
### __app_cisetup__
# {email_address => "bar\@example.com",force_threaded_perls => 0}
### __app_cisetup__
EOF
    _test_flags_block( $file, $flags_block );
}

sub test_email_notifications {
    my $dir  = tempdir();
    my $file = $dir->child('.travis.yml');

    DumpFile(
        $file, {
            sudo     => 'true',
            language => 'perl',
            before_install =>
                ['eval $(curl https://travis-perl.github.io/init) --auto'],
            perl => ['5.24'],
        }
    );

    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
        email_address        => 'bar@example.com',
    )->update_file;

    is(
        LoadFile($file)->{notifications},
        {
            email => {
                recipients => ['bar@example.com'],
                on_success => 'change',
                on_failure => 'always',
            },
        },
        'email address for notifications is added when email is provided',
    );
}

sub test_slack_notifications {
    my $dir  = tempdir();
    my $file = $dir->child('.travis.yml');

    DumpFile(
        $file, {
            sudo     => 'true',
            language => 'perl',
            before_install =>
                ['eval $(curl https://travis-perl.github.io/init) --auto'],
            perl => ['5.24'],
        }
    );

    my @run3;
    no warnings 'redefine';
    ## no critic (Variables::ProtectPrivateVars)
    local *App::CISetup::Travis::ConfigFile::_run3 = sub {
        shift;
        push @run3, @_;
        ${ $_[2] } = q{"encrypted"};
    };

    my $slack_key = 'slack key';
    App::CISetup::Travis::ConfigFile->new(
        file                 => $file,
        force_threaded_perls => 0,
        slack_key            => $slack_key,
        github_user          => 'autarch',
    )->update_file;

    is(
        LoadFile($file)->{notifications},
        {
            slack => { rooms => { secure => 'encrypted' } },
        },
        'slack notification is added when slack key and github user is provided',
    );
    is(
        $run3[0],
        [
            qw( travis encrypt --no-interactive -R ),
            'autarch/' . $dir->basename, $slack_key
        ],
        'travis CLI command is run to encrypt slack key'
    );

    my $flags_block = <<'EOF';
### __app_cisetup__
# {force_threaded_perls => 0,github_user => "autarch"}
### __app_cisetup__
EOF
    _test_flags_block( $file, $flags_block );
}

sub _test_flags_block {
    my $file   = shift;
    my $expect = shift;

    my $last_lines = join q{}, ( $file->lines )[ -3, -2, -1 ];

    is(
        $last_lines,
        $expect,
        'expected config is stored as a comment at the end of the file'
    );
}

__PACKAGE__->meta->make_immutable;

1;
