# ----------------------------------------------------------------------
# Curses::UI
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI;

# If we do not know a terminal type, then imply VT100.
BEGIN { $ENV{TERM} = 'vt100' unless defined $ENV{TERM} }

use Carp qw(confess);
use Curses;
use Curses::UI::Container;
use Term::ReadKey;

use vars qw($VERSION @ISA);
$VERSION = "0.61";
@ISA = qw(Curses::UI::Container);

$Curses::UI::resizing = 0; 
$Curses::UI::resizetime = undef; 
$Curses::UI::screen_too_small = 0; 

$SIG{'WINCH'} = \&resize_window;
sub resize_window()
{
	$Curses::UI::resizing++;
	$Curses::UI::resizetime = time();
	$SIG{'WINCH'} = \&resize_window;
}

sub check_for_resize()
{
	my $this = shift;

        # The last resize signal should be received more than a
        # second ago. This mechanism is used to catch window
        # managers that send a whole bunch of signals to the
        # application if the screen resizes. Only the last one
        # will count.

        if ($Curses::UI::resizing and
            ($Curses::UI::resizetime <= (time()-1)))
        {
                $Curses::UI::resizing = 0;
                $Curses::UI::screen_too_small = 0;
                $this->root->layout_from_scratch;
                $this->root->rebuild_from_scratch;
        }
	
	return $this;
}

sub new()
{
	my $class = shift;
	my %args = (
		-compat        => 0,
		-clear_on_exit => 0,
		@_,
	);
	my $this = bless { %args }, $class;
	$this->layout();	
	return $this;
}

sub layout()
{
	my $this = shift;
	return $this if $Curses::UI::screen_too_small;
	
	if (defined $this->{-scr})
	{
		delwin($this->{-windowscr});
		delete $this->{-windowscr};
		delete $this->{-scr};

		endwin();
	}

	my ($cols,$lines) = GetTerminalSize;
	$ENV{COLS} = $cols;
	$ENV{LINES} = $lines;

	initscr();
	my $root = newwin($lines, $cols, 0, 0);

	$this->{-width}  = $this->{-w} = $this->{-bw} = $cols;
	$this->{-height} = $this->{-h} = $this->{-bh} = $lines;
	$this->{-x} = $this->{-y} = 0;
	$this->{-scr} = $root;
	$this->{-windowscr} = $root;

	$this->layout_contained_objects;
	
	return $this;	
}

sub compat(;$)
{
	my $this = shift;
	my $val = shift;
	if (defined $val) {
		$this->{-compat} = $val
	}
	return $this->{-compat};
}

sub check_for_too_small_screen()
{
	my $this = shift;
	
	if ($Curses::UI::screen_too_small) 
	{
		my $s = $this->rootscr;
		$s->clear;
		$s->addstr(0,0,"Your screen is currently too small "
			     . "for this application.");
		$s->addstr(1,0,"Resize the screen or press "
                             . "<CTRL+C> to exit");
		$s->move(2,0);
		$s->noutrefresh();
		doupdate();

		for (;;) 
		{
			$this->check_for_resize;
			last unless $Curses::UI::screen_too_small;
			sleep 1;
		}
	
	}

	return $this;
}

sub rebuild()
{
	my $this = shift;
	$this->check_for_too_small_screen();
	$this->SUPER::rebuild();
	return $this;
}

sub draw()
{
	my $this = shift;
	$this->check_for_too_small_screen();
	$this->SUPER::draw();
	return $this;
}

sub add()
{
	my $this = shift;
	my $id = shift;
	my $class = shift;
	my %args = @_;
	
        # Make it possible to specify WidgetType instead of
        # Curses::UI::WidgetType.
        $class = "Curses::UI::$class" 
		if $class !~ /\:\:/ 
		or $class =~ /^Dialog\:\:[^\:]+$/;

	$this->SUPER::usemodule($class);

	confess "You may only add Curses::UI::Window objects to "
	  . "Curses::UI and no $class objects"
		unless $class->isa('Curses::UI::Window');
	
	$this->SUPER::add($id, $class, %args);

}

sub tempscreen()
{
	my $this = shift;
	my $id = shift;
	my $class = shift;
	my %args = @_;

	my $tmp = $this->add($id, $class, %args, -parent => $this);
	$this->focus_to_object($id);
	$this->focus_object;
	$return = $tmp->get;
	$this->delete($id);
	$this->rebuild;
	return $return;
}

sub error()
{
	my $this = shift;

	# make ->error("message") possible.
	if (@_ == 1) { @_ = (-message => $_[0]) } 
	my %args = @_;

	$this->tempscreen(
		'_error',
		'Dialog::Error',
		%args
        );
}

sub dialog()
{
	my $this = shift;
	
	# make ->error("message") possible.
	if (@_ == 1) { @_ = (-message => $_[0]) } 
	my %args = @_;

	$this->tempscreen(
		'_dialog',
		'Dialog::Basic',
		%args
        );
}

sub filebrowser()
{
	my $this = shift;
	my %args = @_;
	$this->tempscreen(
		'_filebrowser',
		'Dialog::FileBrowser',
		%args
        );
}

sub savefilebrowser()
{
	my $this = shift;
	my %args = @_;

	# Select a file to save to.
	my $file = $this->filebrowser(
		-editfilename 	=> 1,
		%args,
	);

	return unless defined $file;
	
	# Check if the file exists. Ask for overwrite
	# permission if it does.
	if (-e $file)
	{
		my $overwrite = $this->dialog(
			-title     => "Confirm overwrite",
			-buttons   => ['< Yes >', '< No >'],
			-values    => [1        , 0       ],
			-shortcuts => ['y'      , 'n'     ],
			-message   => "Do you really want to overwrite\n"
                                    . "the file \"$file\"?"
		);
		return unless $overwrite;
	}
	
	return $file;
}

sub loadfilebrowser()
{
	my $this = shift;
	my %args = @_;

	# Select a file to load from.
	my $file = $this->filebrowser(
		-editfilename 	=> 0,
		%args,
	);
}

sub status($;)
{
	my $this = shift;

	# make ->error("message") possible.
	if (@_ == 1) { @_ = (-message => $_[0]) } 
	my %args = @_;

	$this->delete('_status');
	$this->add(
		'_status', 'Dialog::Status',
		%args,
	);

	$this->draw;
	return $this;	
}

sub nostatus()
{
	my $this = shift;
	$this->delete('_status');
	$this->draw;
	return $this;
}

sub progress()
{
	my $this = shift;
	my %args = @_;

	$this->add(
		'_progress', 'Dialog::Progress',
		%args,
	);
	$this->draw;

	return $this;
}

sub setprogress($;$)
{
	my $this = shift;
	my $pos  = shift;
	my $message = shift;

	my $p = $this->getobj('_progress');
	return unless defined $p;
	$p->pos($pos) if defined $pos;
	$p->message($message) if defined $message;
	$p->draw;	

	return $this;
}

sub noprogress()
{
	my $this = shift;
	$this->delete('_progress');
	$this->draw;
	return $this;
}

DESTROY 
{ 
	my $this = shift;
	endwin();
		
	if ($this->{-clear_on_exit})
	{
		my $save_path = $ENV{PATH};
		$ENV{PATH} = "/bin:/usr/bin";
		system "clear";
		$ENV{PATH} = $save_path;
	}
}

1;


=pod

=head1 NAME

Curses::UI - A curses based user user interface framework




=head1 SYNOPSIS

Here's the obligatory "Hello, world!" example.

    use Curses::UI;
    my $cui = new Curses::UI;
    $cui->dialog("Hello, world!");




=head1 DESCRIPTION

Curses::UI can be used for the development of curses
based user interfaces. Currently, it contains the 
following classes:

Base elements

  Curses::UI::Widget
  Curses::UI::Container

Widgets

  Curses::UI::Window
  Curses::UI::Label
  Curses::UI::TextEditor
  Curses::UI::TextEntry
  Curses::UI::TextViewer
  Curses::UI::Buttons
  Curses::UI::CheckBox
  Curses::UI::ListBox
  Curses::UI::RadioButtonBox
  Curses::UI::PopupBox
  Curses::UI::MenuBar
  Curses::UI::MenuListBox (used by Curses::UI::MenuBar)
  Curses::UI::ProgressBar

Dialogs

  Curses::UI::Dialog::Basic
  Curses::UI::Dialog::Error
  Curses::UI::Dialog::FileBrowser
  Curses::UI::Dialog::Status

Support classes

  Curses::UI::Common
  Curses::UI::SearchEntry
  Curses::UI::Searchable




=head1 OPTIONS

=over 4

=item B<-compat> < BOOLEAN >

If the B<-compat> option is set to a true value, the Curses::UI
program will run in compatibility mode. This means that only
very simple characters will be used for creating the widgets.
By default this option is set to false.

=item B<-clear_on_exit> < BOOLEAN >

If the B<-clear_on_exit> option is set to a true value,
a Curses::UI program will call the "clear" program on exit
(through the DESTROY method of Curses::UI). By default
this option is set to false.

=back




=head1 METHODS

The UI is a descendant of Curses::UI::Container, so you can use the
Container methods. Here's an overview of the methods that are specific
for Curses::UI.

=over 4

=item B<new> ( OPTIONS )

Create a new Curses::UI instance. See the OPTIONS section above 
to find out what options can be used.

=item B<add> ( ID, CLASS, OPTIONS )

The B<add> method of Curses::UI is almost the same as the B<add>
method of Curses::UI::Container. The difference is that Curses::UI
will only accept classes that are (descendants) of the
Curses::UI::Window class. For the rest of the information
see L<Curses::UI::Container|Curses::UI::Container>.

=item B<layout> ( )

The layout method of Curses::UI will try to find out the size of the
screen. After that it will call the B<layout> routine of every 
contained object. So running B<layout> on a Curses::UI object will
effectively layout the complete application. Normally you will not 
have to call this method directly.

=item B<compat> ( [BOOLEAN] )

The B<-compat> option will be set to the BOOLEAN value. If the
argument is omitted, this method will only return the current
value for B<-compat>.

=item B<dialog> ( MESSAGE or OPTIONS )

Use the B<dialog> method to show a dialog window. If you only
provide a single argument, this argument will be used as the 
message to show. Example:

    $cui->dialog("Hello, world!"); 

If you want to have some more control over the dialog window, you
will have to provide more arguments (for an explanation of the 
arguments that can be used, see 
L<Curses::UI::Dialog::Basic|Curses::UI::Dialog::Basic>. 
Example:

    my $yes = $cui->dialog(
        -message => "Hello, world?");
        -buttons => ['< Yes >','< No >']
        -values  => [1,0],
        -title   => 'Question',
    );

    if ($yes) {
        # whatever
    }
       

=item B<error> ( MESSAGE or OPTIONS )

The B<error> method will create an error dialog. This is 
basically a Curses::UI::Dialog::Basic, but it has an ASCII-art
exclamation sign drawn left to the message. For the rest 
it's just like B<dialog>. Example:

    $cui->error("It's the end of the\n"
               ."world as we know it!");

=item B<filebrowser> ( OPTIONS )

The B<filebrowser> method will create a file browser
dialog. For an explanation of the arguments that can be 
used, see L<Curses::UI::FileBrowser|Curses::UI::FileBrowser>.
Example:

    my $file = $cui->filebrowser(
        -path => "/tmp",
        -show_hidden => 1,
    );

    # Filebrowser will return undef
    # if no file was selected.
    if (defined $file) { 
        unless (open F, ">$file") {
            print F "Hello, world!\n";
            close F;
	} else {
            $cui->error("Error on writing to "
                       ."\"$file\":\n$!");
	}
    } 

=item B<loadfilebrowser>( OPTIONS )

=item B<savefilebrowser>( OPTIONS )

These two methods will create file browser dialogs as well.
The difference is that these will have the dialogs set up
correctly for loading and saving files. Moreover, the save
dialog will check if the selected file exists or not. If it
does exist, it will show an overwrite confirmation to check
if the user really wants to overwrite the selected file.

=item B<status> ( MESSAGE )

=item B<nostatus> ( )

Using these methods it's easy to provide status information for
the user of your program. The status dialog is a dialog with 
only a label on it. The status dialog doesn't really get the
focus. It's only used to display some information. If you need
more than one status, you can call B<status> subsequently.
Any existing status dialog will be cleaned up and a new one
will be created.

If you are finished, you can delete the status dialog by calling
the B<nostatus> method. Example:

    $cui->status("Saying hello to the world...");
    # code for saying "Hello, world!"

    $cui->status("Saying goodbye to the world...");
    # code for saying "Goodbye, world!"

    $cui->nostatus;

=item B<progress> ( OPTIONS )

=item B<setprogress> ( POSITION, MESSAGE )

=item B<noprogress> ( )

Using these methods it's easy to provide progress information
to the user. The progress dialog is a dialog with an optional
label on it and a progress bar. Similar to the status dialog,
this dialog does not get the focus. 

Using the B<progress> method, a new progress dialog can be 
created (see also 
L<Curses::IU::Dialog::Progress|Curses::UI::Dialog::Progress>). 
This method takes the same arguments as the Curses::IU::Dialog::Progress 
class.

After that the progress can be set using B<setprogress>. This 
method takes one or two arguments. The first argument is the current
position of the progressbar. The second argument is the message
to show in the label. If one of these arguments is undefined,
the current value will be kept. 

If you are finished, you can delete the progress dialog by calling
the B<noprogress> method. 

Example:

    $cui->progress(
        -max => 10,
	-message => "Counting 10 seconds...",
    );

    for my $second (0..10) {
	$cui->setprogress($second)
	sleep 1;
    }

    $cui->noprogress;

=back



=head1 SEE ALSO

L<Curses>
L<Curses::UI::Container|Curse::UI::Container>,




=head1 BASIC TUTORIAL

=head1 First requirements

Any perl program that uses Curses::UI needs to include
"use Curses::UI". A program should also use "use strict"
and the B<-w> switch to ensure the program is working
without common errors (but of course Curses::UI will work
without them). After that an instance of Curses::UI must
be created. From now on, this instance will be called
"the UI".

    #!/usr/bin/perl -w

    use strict;
    use Curses::UI;
    my $cui = new Curses::UI;

=head1 Create windows

After the initialization has been done, windows can be
added to the UI. You will always have to do this. It is not
possible to add widgets to the UI directly. Here is an
example that creates a window with a title and a border,
which has a padding of 2 (For the explanation of $cui->add, 
see the Curses::UI::Container manual page).

    my $win1 = $cui->add(
        'win1', 'Window',
        -border => 1,
        -title => 'My first Curses::UI window!',
        -pad => 2,
    );

Well... that's fun! Let's add another window! And let's
give it more padding, so that the window is smaller than
the previous one.
    
    my $win2 = $cui->add(
        'win2', 'Window',
        -border => 1,
        -title => 'My second Curses::UI window!',
        -pad => 6,
    );

=head1 Add some widgets

Now that we have a couple of windows, we can add widgets
to them. We'll add a popupbox and some buttons to 
the first window.

    my $popup = $win1->add(
        'popup', 'PopupBox',
        -x => 2,
        -y => 2,
        -sbborder => 1, 
        -values => [ 1, 2, 3, 4, 5 ],
        -labels => {
            1 => 'One', 
            2 => 'Two', 
            3 => 'Three', 
            4 => 'Four', 
            5 => 'Five', 
        },
    );

    my $but1 = $win1->add(
        'buttons', 'Buttons',
        -x => 2,
        -y => 4,
        -buttons => ['< goto window 2 >', '< Quit >'],
    ); 

We'll add a texteditor and some buttons to the second window. Look how
we can use padding to do some basic layouting. We do not specifiy the
with and height of the TextEditor widget, so the widget will stretch
out itself as far as possible. But because of the -padbottom option,
it will leave some space to put the buttons. By specifying a negative
-y offset for the buttons, we have a scalable application. Resize the
screen and the widgets will follow!
    
    my $editor = $win2->add(
        'editor', 'TextEditor',
        -border => 1,
        -vscrollbar => 1,
        -wrapping => 1,
        -x => 2,
        -y => 1,
        -padright => 2,
        -padbottom => 3,
    );

    my $but2 = $win2->add(
        'buttons', 'Buttons',
        -x => 2,
        -y => -2,
        -buttons => ['< goto window 1 >', '< Quit >'],
    );

=head1 Specify when the windows will loose their focus

We have a couple of Buttons on each window. As soon as a 
button is pressed, it will have the window loose its
focus (Buttons will have any kind of Container object
loose its focus). You will only have to do something
if this is not the desired behaviour. 

If you want the buttons themselves to loose focus if 
pressed, then change its routine for the "return" 
binding from "LEAVE_CONTAINER" to "RETURN". Example:

    $but1->set_routine('return', 'RETURN');

To make things a bit more snappy, we want to add some
shortcut keys to the appliction:

    CTRL+Q : Quit the application
    CTRL+N : Go to the next window

This can be done by assigning "returnkeys" to a window.
Each widget in the window will get extra keybindings to
have the window loose its focus if one of the returnkeys
is pressed. For our application we can set the desired
shortcut keys like this:

    $win1->returnkeys("\cN", "\cQ");
    $win2->returnkeys("\cN", "\cQ");

From now on both windows will loose focus if either CTRL+Q
or CTRL+N is pressed. Important: make sure that returnkeys 
are assigned to a window _after_ all windgets have been 
added. 

=head1 The main loop

Now that we have constructed the windows and some widgets
on them, we will have to make things work like they should.

    MAINLOOP: for(;;) {
        WINDOW: foreach my $win_id ('win1','win2') {
            # Bring the current window on top
            $cui->ontop($win_id);

            # Get the window object.
            my $win = $cui->getobj($win_id);

            # Bring the focus to this window. Focus routines
            # will return a returnvalue (which is always
            # "LEAVE_CONTAINER" for a Container object) and
            # the last key that was pressed.
            my ($returnvalue, $lastkey) = $win->focus;

            # First check if the $lastkey is one of the
            # shortcut keys we created using returnkeys().
            if ($lastkey eq "\cN") {
                next WINDOW;
	    } elsif ($lastkey eq "\cQ") {
                last MAINLOOP;
            }

            # Nope. Then we can assume that a button
            # was pressed. Check which button it was.

            # First get the button object of the focused window.
            my $btn = $win->getobj('buttons');

            # Get the index of the pressed button.
            my $button_id = $btn->get;

            # If the $button_id == 1, the Quit button was pressed.
            last MAINLOOP if $button_id == 1;
        }
    }

=head1 Add a good-bye dialog

Curses::UI has a couple of methods that are easy for showing dialogs 
(see the METHODS section below). We'll use a dialogbox to say goodbye
to the user of our program. After the mainloop we add:

    $cui->dialog("Bye bye!");

=head1 You're done!

We have built a genuine Curses::UI application! Not that it is a
very useful one, but who cares? Now try out if it works like you 
think it should. The complete source code of this application can 
be found in the examples directory of the distribution 
(examples/demo-Curses::UI).




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

