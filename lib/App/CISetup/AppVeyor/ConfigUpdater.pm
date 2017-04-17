package App::CISetup::AppVeyor::ConfigUpdater;

use App::CISetup::Wrapper::OurMoose;

use App::CISetup::AppVeyor::ConfigFile;
use App::CISetup::Types qw( Bool Str );

has email_address => (
    is        => 'ro',
    isa       => Str,  # todo, better type
    predicate => 'has_email_address',
);

has encrypted_slack_key => (
    is      => 'ro',
    isa     => Str,
    predicate => 'has_encrypted_slack_key',
);

with(
    'App::CISetup::Role::ConfigFileFinder' => {
        filename => 'appveyor.yml',
    },
    'MooseX::Getopt::Dashes',
);

sub run ($self) {
    my $iter = $self->_config_file_iterator;

    my $count = 0;
    while ( my $file = $iter->() ) {
        $count++;
        App::CISetup::AppVeyor::ConfigFile->new(
            file => $file,
            ($self->has_email_address       ? (email_address       => $self->email_address)       : () ),
            ($self->has_encrypted_slack_key ? (encrypted_slack_key => $self->encrypted_slack_key) : () ),
        )->update_file;
    }


    print STDERR "WARNING: No appveyor.yml file found"
        unless $count;
}

__PACKAGE__->meta->make_immutable;

1;
