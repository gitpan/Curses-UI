# Testing Plain old Documentation for Curses::UI
# 2003 (c) by Marcus Thiesen
# marcus@cpan.org

use strict;
use FindBin;
use Test::Pod (tests => 20);

my $dir = "$FindBin::RealBin/../lib/Curses";

pod_file_ok( "$dir/UI.pm", "Curses::UI POD" );
pod_file_ok( "$dir/UI/Buttonbox.pm", "Curses::UI::Buttonbox POD");
pod_file_ok( "$dir/UI/Calendar.pm" , "Curses::UI::Calendar POD");
pod_file_ok( "$dir/UI/Checkbox.pm", "Curses::UI::Checkbox POD");
pod_file_ok( "$dir/UI/Color.pm", "Curses::UI::Color POD");
pod_file_ok( "$dir/UI/Common.pm", "Curses::UI::Common POD");
pod_file_ok( "$dir/UI/Container.pm", "Curses::UI::Container POD");
pod_file_ok( "$dir/UI/Label.pm", "Curses::UI::Label POD");
pod_file_ok( "$dir/UI/Listbox.pm", "Curses::UI::Listbox POD");
pod_file_ok( "$dir/UI/Menubar.pm", "Curses::UI::Menubar POD");
pod_file_ok( "$dir/UI/PasswordEntry.pm", "Curses::UI::PasswordEntry POD");
pod_file_ok( "$dir/UI/Popupmenu.pm", "Curses::UI::Popupmenu POD");
pod_file_ok( "$dir/UI/Progressbar.pm", "Curses::UI::Progressbar POD");
pod_file_ok( "$dir/UI/Radiobuttonbox.pm", "Curses::UI::Radiobuttonbox POD");
pod_file_ok( "$dir/UI/Searchable.pm", "Curses::UI::Searchable POD");
pod_file_ok( "$dir/UI/TextEditor.pm", "Curses::UI::TextEditor POD");
pod_file_ok( "$dir/UI/TextEntry.pm", "Curses::UI::TextEntry POD");
pod_file_ok( "$dir/UI/TextViewer.pm", "Curses::UI::TextViewer POD");
pod_file_ok( "$dir/UI/Widget.pm", "Curses::UI::Widget POD");
pod_file_ok( "$dir/UI/Window.pm", "Curses::UI::Window POD");
