use strict;
use Test::More tests => 9;
use FindBin;
use lib "$FindBin::RealBin/fakelib";
use lib "$FindBin::RealBin/../lib";

$ENV{LINES} = 25;
$ENV{COLUMNS} = 80;

BEGIN { use_ok( "Curses::UI");
	use_ok( "Curses::UI::Common"); }

my $cui = new Curses::UI("-clear_on_exit" => 0);

$cui->leave_curses();

isa_ok($cui, "Curses::UI");

my $mainw = $cui->add("testw","Window");

isa_ok($mainw, "Curses::UI::Window");

# Various methods
ok($mainw->root eq $cui, "root()");

my $data = { KEY => "value", FOO => "bar"  };
Curses::UI::Common::keys_to_lowercase($data);
ok($data->{key}, "keys_to_lowercase 1");
ok($data->{foo}, "keys_to_lowercase 2");

ok(Curses::UI::Common::scrlength("foo bar") == length("foo bar"),
	"scrlength() 1");
 
ok(Curses::UI::Common::scrlength("foo\tbar") != length("foo bar"),
	"scrlength() 2");

## TODO:
## split_to_lines
## text_dimension
## wrap stuff
