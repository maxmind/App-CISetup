package App::CISetup::Role::ConfigFile;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

our $VERSION = '0.01';

use App::CISetup::Types qw( File );
use Try::Tiny;
use YAML qw( Dump LoadFile );

use Moose::Role;

requires qw(
    _update_config
    _fix_up_yaml
);

has file => (
    is       => 'ro',
    isa      => File,
    coerce   => 1,
    required => 1,
);

sub update_file {
    my $self = shift;

    my $file = $self->file;
    my $orig = $file->slurp;

    my $err;
    my $content = try {
        LoadFile($file);
    }
    catch {
        $err = "YAML parsing error: $_\n";
    };

    return unless $content || $err;

    if ($err) {
        print "\n\n\n" . $file . "\n" or die $!;
        print $err or die $!;
        return;
    }

    $self->_update_config($content);

    ## no critic (TestingAndDebugging::ProhibitNoWarnings)
    no warnings 'once';

    # If Perl versions aren't quotes then Travis display 5.10 as "5.1"

    ## no critic (Variables::ProhibitPackageVars)
    local $YAML::QuoteNumericStrings = 1;
    my $yaml = Dump($content);

    $yaml = $self->_fix_up_yaml($yaml);

    return if $yaml eq $orig;

    print "Updated $file\n" or die $!;

    $file->spew($yaml);

    return;
}

## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
sub _reorder_yaml_blocks {
    my $self         = shift;
    my $yaml         = shift;
    my $blocks_order = shift;

    my $re = qr/^
                (
                    ([a-z_]+): # key:
                    (?:
                        (?:$)\n.+?
                    |
                        \ .+?\n
                    )
                )
                (?=^[a-z]|\z)
               /xms;

    my %blocks;
    while ( $yaml =~ /$re/g ) {
        $blocks{$2} = $1;
    }

    for my $name ( keys %blocks ) {
        my $method = '_reorder_' . $name . '_block';
        next unless $self->can($method);
        $blocks{$name} = $self->$method( $blocks{$name} );
    }

    my %known_blocks = map { $_ => 1 } @{$blocks_order};
    for my $block ( keys %blocks ) {
        die "Unknown block $block in " . $self->file
            unless $known_blocks{$block};
    }

    return "---\n" . join q{}, map { $blocks{$_} // () } @{$blocks_order};
}
## use critic

1;
