package App::CISetup::Types;

use strict;
use warnings;

our $VERSION = '0.01';

use parent 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        MooseX::Types::Moose
        App::CISetup::Types::Internal::PathClass
        )
);

1;
