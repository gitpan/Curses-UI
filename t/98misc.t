# -*- perl -*-
use strict;
use Test::More tests => 2;
use FindBin;
use lib "$FindBin::RealBin/../lib";

$ENV{LINES} = 25;
$ENV{COLUMNS} = 80;

BEGIN { use_ok( "Curses::UI"); }

ok (!$Curses::UI::debug, "Debugging flag");
