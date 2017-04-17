package App::CISetup::Types;

use mmperl;

use parent 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        MooseX::Types::Moose
        App::CISetup::Types::Internal::PathClass
      )
);

1;
