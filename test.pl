use Test;

BEGIN { plan tests => 2 };

# Curses::UI
use Curses::UI;

# The base classes
use Curses::UI::Widget;
use Curses::UI::Container;

# The widget classes
use Curses::UI::Buttons;
use Curses::UI::CheckBox;
use Curses::UI::Common;
use Curses::UI::Label;
use Curses::UI::ListBox;
use Curses::UI::MenuBar;
use Curses::UI::MenuListBox;
use Curses::UI::PopupBox;
use Curses::UI::ProgressBar;
use Curses::UI::RadioButtonBox;
use Curses::UI::SearchEntry;
use Curses::UI::Searchable;
use Curses::UI::TextEditor;
use Curses::UI::TextEntry;
use Curses::UI::TextViewer;
use Curses::UI::Window;

# The dialogs
use Curses::UI::Dialog::Basic;
use Curses::UI::Dialog::Error;
use Curses::UI::Dialog::Status;
use Curses::UI::Dialog::FileBrowser;
use Curses::UI::Dialog::Progress;

ok(1);

system "examples/basic_test";
ok($? == 0)

