package App::CISetup::Wrapper::OurMooseX::Role::Parameterized;

use App::CISetup::Wrapper::Ourperl;

use Import::Into;
use Moose::Exporter;
use Moose::Util qw( find_meta );
use MooseX::Role::Parameterized                                           ();
use MooseX::SemiAffordanceAccessor                                        ();
use App::CISetup::Wrapper::OurMooseX::Role::Parameterized::Meta::Trait::Parameterizable::Strict ();
use namespace::autoclean                                                  ();

my ($import) = Moose::Exporter->setup_import_methods(
    install        => [ 'unimport', 'init_meta' ],
    also           => ['MooseX::Role::Parameterized'],
    role_metaroles => {
        role => [
            'App::CISetup::Wrapper::OurMooseX::Role::Parameterized::Meta::Trait::Parameterizable::Strict'
        ],
    },
);

sub import {
    my $for_role = caller();

    $import->( undef, { into => $for_role } );
    MooseX::SemiAffordanceAccessor->import( { into => $for_role } );

    my $caller_level = 1;
    App::CISetup::Wrapper::Ourperl->import::into($caller_level);
    namespace::autoclean->import::into($caller_level);
}

1;
