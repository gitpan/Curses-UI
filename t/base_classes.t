use strict;
use Test;

BEGIN { plan tests => 5 }

foreach my $class (qw(
    Curses::UI
    Curses::UI::Common
    Curses::UI::Container
    Curses::UI::Widget
    Curses::UI::Searchable )) {

    my $file = $class;
    $file =~ s|::|/|g;
    $file .= '.pm';

    require $file;
    ok(1);
}

