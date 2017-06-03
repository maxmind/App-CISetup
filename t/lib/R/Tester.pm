package R::Tester;

use strict;
use warnings;

use Moose::Role;

use Test2::Bundle::Extended '!meta';

use YAML qw( Load );

sub _test_cisetup_flags_comment {
    my $self   = shift;
    my $file   = shift;
    my $expect = shift;

    my ($comment)
        = $file->slurp_utf8 =~ /### __app_cisetup__\n(.+)### __app_cisetup__/s;
    $comment =~ s/^# //mg;
    my $got = Load($comment);

    is(
        $got,
        $expect,
        'expected config is stored as a comment at the end of the file'
    );
}

1;
