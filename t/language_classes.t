use strict;
use Test;

BEGIN { plan tests => 3 }

foreach my $class (qw(
    Curses::UI::Language
    Curses::UI::Language::english
    Curses::UI::Language::dutch)) {

    my $file = $class;
    $file =~ s|::|/|g;
    $file .= '.pm';

    require $file;
    ok(1);
}

