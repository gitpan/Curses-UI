use strict;
use Test::More qw(no_plan);
use FindBin;
use lib "$FindBin::RealBin/fakelib";
use lib "$FindBin::RealBin/../lib";

#### REMOVE ####
exit 1;

BEGIN { use_ok( "Curses::UI"); }

my $cui = new Curses::UI("-clear_on_exit" => 0);

$cui->leave_curses();

isa_ok($cui, "Curses::UI");

my $mainw = $cui->add("testw","Window");

isa_ok($mainw, "Curses::UI::Window");

my $wid = $mainw->add("testwidget","<:WIDGET:>");

isa_ok($wid, "<:CLASS:>");
