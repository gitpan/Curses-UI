package Curses::UI::RootWindow;

# If we do not know a terminal type, then imply VT100.
BEGIN { $ENV{TERM} = 'vt100' unless defined $ENV{TERM} }

use Carp qw(confess);
use Curses;
use Curses::UI::Container;
use Term::ReadKey;

use vars qw($VERSION @ISA);
$VERSION = "1.0.0";
@ISA = qw(Curses::UI::Container);

$::mws_resizing = 0; 
$::mws_resizetime = undef; 

$SIG{'WINCH'} = \&resize_window;
sub resize_window()
{
	$::mws_resizing++;
	$::mws_resizetime = time();
	$SIG{'WINCH'} = \&resize_window;
}

sub new()
{
	my $class = shift;
	my $this = bless {}, $class;
	$this->layout();	
	return $this;
}

sub layout()
{
	my $this = shift;
	
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

sub add()
{
	my $this = shift;
	my $id = shift;
	my $class = shift;
	my %args = @_;
	
	$this->SUPER::usemodule($class);

	confess "You may only add Curses::UI::Window objects to a "
	  . "Curses::UI::RootWindow and no $class objects"
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
	my %args = @_;
	$this->tempscreen(
		'_error',
		'Curses::UI::ErrorDialog',
		%args
        );
}

sub dialog()
{
	my $this = shift;
	my %args = @_;
	$this->tempscreen(
		'_dialog',
		'Curses::UI::Dialog',
		%args
        );
}

sub filebrowser()
{
	my $this = shift;
	my %args = @_;
	$this->tempscreen(
		'_filebrowser',
		'Curses::UI::FileBrowser',
		%args
        );
}

DESTROY 
{ 
	endwin();

	my $save_path = $ENV{PATH};
	$ENV{PATH} = "/bin:/usr/bin";
	$ENV{PATH} = $save_path;
}

1;
