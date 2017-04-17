package App::CISetup::Role::ConfigFileFinder;

use App::CISetup::Wrapper::OurMooseX::Role::Parameterized;

use File::pushd qw( pushd );
use Git::Sub qw( remote );
use App::CISetup::Travis::ConfigFile;
use App::CISetup::Types qw( CodeRef PathClassDir Str );
use Path::Class::Rule;

with 'MooseX::Getopt::Dashes';

has dir => (
    is       => 'ro',
    isa      => PathClassDir,
    required => 1,
    coerce   => 1,
);

has _config_file_iterator => (
    is      => 'ro',
    isa     => CodeRef,
    lazy    => 1,
    builder => '_build_config_file_iterator',
);

parameter filename => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

role {
    my $p = shift;
    method( _filename => sub { $p->filename } );
};

sub _build_config_file_iterator ($self) {
    my $rule = Path::Class::Rule->new;
    $rule->file->name( $self->_filename );
    $rule->and(
        sub ( $path, $, $ ) {
            return unless -e $path->parent->subdir('.git');
            my $pushed = pushd( $path->parent );
            ## no critic (Modules::RequireExplicitInclusion, Subroutines::ProhibitCallsToUnexportedSubs)
            my @origin = git::remote(qw( show -n origin ));
            return unless grep { m{Push +URL: .+(:|/)maxmind/} } @origin;
            return 1;
        }
    );

    return $rule->iter( $self->dir );
}

1;
