use Test;

open STDERR, ">/tmp/r";

BEGIN { plan tests => 25 };

# The base classes
use Curses::UI;
ok(1);
use Curses::UI::Widget;
ok(1);
use Curses::UI::Container;
ok(1);

# The widgets
use Curses::UI::Buttons;
ok(1);
use Curses::UI::CheckBox;
ok(1);
use Curses::UI::Common;
ok(1);
use Curses::UI::Label;
ok(1);
use Curses::UI::ListBox;
ok(1);
use Curses::UI::MenuBar;
ok(1);
use Curses::UI::MenuListBox;
ok(1);
use Curses::UI::PopupBox;
ok(1);
use Curses::UI::ProgressBar;
ok(1);
use Curses::UI::RadioButtonBox;
ok(1);
use Curses::UI::SearchEntry;
ok(1);
use Curses::UI::Searchable;
ok(1);
use Curses::UI::TextEditor;
ok(1);
use Curses::UI::TextEntry;
ok(1);
use Curses::UI::TextViewer;
ok(1);
use Curses::UI::Window;
ok(1);

# The dialogs
use Curses::UI::Dialog::Basic;
ok(1);
use Curses::UI::Dialog::Error;
ok(1);
use Curses::UI::Dialog::Status;
ok(1);
use Curses::UI::Dialog::FileBrowser;
ok(1);
use Curses::UI::Dialog::Progress;
ok(1);

system "examples/basic_test";
ok($? == 0)

