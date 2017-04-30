package App::CISetup::Types::Internal::PathClass;

# ABSTRACT: Exports PathClassDir and PathClassFile

use strict;
use warnings;

our $VERSION = '0.01';

use MooseX::Getopt::OptionTypeMap ();
use MooseX::Types::Moose qw( ArrayRef Str );
use MooseX::Types::Path::Class qw( Dir File );

use MooseX::Types -declare => [
    qw(
        PathClassDir
        PathClassFile
        )
];

subtype( PathClassDir, as Dir );

subtype( PathClassFile, as File );

for my $from ( ArrayRef, Str ) {
    coerce PathClassDir,  from $from, via { to_Dir($_) };
    coerce PathClassFile, from $from, via { to_File($_) };
}

MooseX::Getopt::OptionTypeMap->add_option_type_to_map( $_ => '=s' )
    for ( PathClassFile, PathClassDir, );

1;
