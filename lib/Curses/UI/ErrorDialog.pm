package Curses::UI::ErrorDialog;

use strict;
use Carp qw(confess);
use Curses;
use Curses::UI::Buttons;
use Curses::UI::Common;
use Curses::UI::Dialog;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::Dialog Curses::UI::Common);
$VERSION = '1.0.0';

sub new ()
{
	my $class = shift;
	my %args = ( 
		-message 	 => '',		# The message to show
		@_,
		-ipadleft	 => 10,		# Space for sign
	);
	$args{-title} = 'error message' unless defined $args{-title};

	my $this = $class->SUPER::new(%args);

	bless $this, $class;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;
	
	# Draw frame
	$this->SUPER::draw(1);

	# Draw sign
	$this->{-borderscr}->addstr(2, 1, "    _"); 
	$this->{-borderscr}->addstr(3, 1, "   / \\"); 
	$this->{-borderscr}->addstr(4, 1, "  / ! \\"); 
	$this->{-borderscr}->addstr(5, 1, " /_____\\"); 
	$this->{-borderscr}->noutrefresh();

	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;

	return $this;
}

1;
