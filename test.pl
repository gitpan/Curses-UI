use strict;
use Test;


BEGIN { 
	plan tests => 4,
	onfail => sub {
		close STDERR;
		if (1 or -s "test.log") {
			print "-- STDERR output --\n";
			open L, "<test.log";
			while (<L>) {
				print "$_";
			}
			close L;
			print "-------------------\n";
		}
	}
}
open STDERR, ">test.log";

# The base classes
use Curses::UI;
use Curses::UI::Widget;
use Curses::UI::Container;
ok(1);

# The widgets
use Curses::UI::Buttonbox;
use Curses::UI::Checkbox;
use Curses::UI::Common;
use Curses::UI::Calendar;
use Curses::UI::Label;
use Curses::UI::Listbox;
use Curses::UI::Menubar;
use Curses::UI::MenuListbox;
use Curses::UI::Popupmenu;
use Curses::UI::Progressbar;
use Curses::UI::Radiobuttonbox;
use Curses::UI::SearchEntry;
use Curses::UI::Searchable;
use Curses::UI::TextEditor;
use Curses::UI::TextEntry;
use Curses::UI::TextViewer;
use Curses::UI::Window;
ok(1);

# The dialogs
use Curses::UI::Dialog::Basic;
use Curses::UI::Dialog::Error;
use Curses::UI::Dialog::Status;
use Curses::UI::Dialog::Filebrowser;
use Curses::UI::Dialog::Progress;
ok(1);

system "examples/basic_test";
ok($? == 0)

