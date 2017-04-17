## no critic (Moose::RequireMakeImmutable)

package App::CISetup::Wrapper::OurMoose;

use App::CISetup::Wrapper::Ourperl;

use Import::Into;
use Moose ();
use Moose::Exporter;
use MooseX::SemiAffordanceAccessor ();
use MooseX::StrictConstructor      ();
use namespace::autoclean           ();

# We do this a second time to re-establish our custom warnings
use App::CISetup::Wrapper::Ourperl;

my ($import) = Moose::Exporter->setup_import_methods(
    install => [ 'unimport', 'init_meta' ],
    also    => ['Moose'],
);

sub import ( $class, @ ) {
    my $for_class = caller();

    $import->( undef, { into => $for_class } );
    $class->import_extras( $for_class, 2 );

    return;
}

sub import_extras ( $class, $for_class, $level ) {

    MooseX::SemiAffordanceAccessor->import( { into => $for_class } );
    MooseX::StrictConstructor->import( { into => $for_class } );

    # note that we need to use a level here rather than a classname
    # so that importing autodie works
    App::CISetup::Wrapper::Ourperl->import::into($level);
    namespace::autoclean->import::into($level);

    return;
}

1;
