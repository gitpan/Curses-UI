# ----------------------------------------------------------------------
# Curses::UI::MenuBar
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::MenuBar;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Container;
use Curses::UI::Window;

use vars qw($VERSION @ISA);
$VERSION = '1.01';
@ISA = qw(Curses::UI::Window Curses::UI::Common);

my %routines = (
        'return'   	=> 'RETURN',
        'escape'   	=> 'ESCAPE',
	'pulldown'	=> \&pulldown,
	'left'		=> \&cursor_left,
	'right'		=> \&cursor_right,
);

my %bindings = (
	KEY_STAB()	=> 'return',
	KEY_BTAB()	=> 'return',
	"\t"		=> 'return',
	KEY_DOWN()	=> 'pulldown',
	'j'		=> 'pulldown',
	KEY_ENTER()	=> 'pulldown',
	"\n"		=> 'pulldown',
        KEY_LEFT()      => 'left',
        'h'             => 'left',
        KEY_RIGHT()     => 'right',
        'l'             => 'right',
	KEY_ESCAPE()	=> 'escape',

);

sub new ()
{
	my $class = shift;

	my %args = (
		-parent		 => undef,	# the parent window
		-bindings	 => {%bindings},
		-routines	 => {%routines},
		-menu		 => [],
		@_,
		-width		 => undef,
		-height		 => 1,
		-focus		 => 0,
		-x		 => 0,
		-y		 => 0,
		-border	 	 => 0,
		-focus		 => 0,
		-selected	 => undef,
	);

	my $this = $class->SUPER::new( %args );
	$this->layout;

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;

	$this->delallwin;
	$this->SUPER::layout;

	return $this;
} 

sub draw()
{
	my $this = shift;
        my $no_doupdate = shift || 0;
	return if $this->hidden;

	$this->SUPER::draw(1);

	# Create full reverse menubar.
	$this->{-windowscr}->attron(A_REVERSE);
	$this->{-windowscr}->addstr(0, 0, " "x$this->screenwidth);

	# Create menu-items.
	my $x = 1;
	my $idx = 0;
	foreach my $item (@{$this->{-menu}})
	{
		# By default the bar is drawn in reverse.
		$this->{-windowscr}->attron(A_REVERSE);

		# If the bar has focus, the selected item is
		# show without reverse.
		if ($this->{-focus} and $idx == $this->{-selected}) {
		    $this->{-windowscr}->attroff(A_REVERSE);
		}
				

		my $label = $item->{-label};
		$this->{-windowscr}->addstr(0, $x, " " . $item->{-label} . " ");
		$x += length($label) + 2;
		
		$idx++;
	}
	$this->{-windowscr}->attroff(A_REVERSE);
	$this->{-windowscr}->move(0,0);

	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;
	return $this;
}

sub focus()
{
	my $this = shift;
	$this->{-focus} = 1;
	$this->{-selected} = 0;
	$this->draw;

        my ($return,$key) = $this->generic_focus(
                undef,
                NO_CONTROLKEYS,
                CURSOR_INVISIBLE
        );

	# Execute code?
	if (ref $return eq 'CODE') {
		$return->();
	# Return plain value?
	} elsif (not ref $return) {
		return $return
	# Return standard.
	} else {
		return $this;
	}
}

sub pulldown() 
{
	my $this = shift;

	# Find the x position of the selected menu.
	my $x = 1;
	for my $idx (1 .. $this->{-selected})
	{
		$x += length($this->{-menu}->[$idx]->{-label});
		$x += 2;
	}

	my $id = "_submenu_$this";
	my ($return,$key) = $this->root->add(
		$id, 'MenuListBox',
		-x		=> $x,
		-y		=> 1,
		-is_topmenu	=> 1,
                -menu           => $this->{-menu}->[$this->{-selected}]->{-submenu},
	)->draw->focus;
	$this->root->delete($id);
	$this->root->rebuild;

	if ($return eq 'CURSOR_LEFT') 
	{ 
		$this->cursor_left;
		$this->draw;
		# Open pulldown menu.
		return "DO_KEY:" . KEY_DOWN();
	} 
	elsif ($return eq 'CURSOR_RIGHT') 
	{ 
		$this->cursor_right;
		$this->draw;
		# Open pulldown menu.
		return "DO_KEY:" . KEY_DOWN();
	}
	elsif ($return eq 'RETURN') 
	{
		return $this;
	}
	else 
	{
		return $return;
	}
}

sub cursor_left()
{
	my $this = shift;
	$this->{-selected}--;
	$this->{-selected} = @{$this->{-menu}}-1 
		if $this->{-selected} < 0;
	return $this;
}

sub cursor_right()
{
	my $this = shift;
	$this->{-selected}++;
	$this->{-selected} = 0
		if $this->{-selected} > (@{$this->{-menu}}-1);
	return $this;
}

1;

