# ----------------------------------------------------------------------
# Curses::UI::PopupBox
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::PopupBox;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Widget;
use Curses::UI::ListBox;
use Curses::UI::Label;

use vars qw($VERSION @ISA);
$VERSION = '1.05';
@ISA = qw(Curses::UI::Widget Curses::UI::Common);

my %routines = (
        'return'   	=> 'RETURN',
        'open-popup'    => \&open_popup,
	'select-next'	=> \&select_next,
	'select-prev'	=> \&select_prev,
);

my %bindings = (
	KEY_STAB()	=> 'return',
	KEY_BTAB()	=> 'return',
	"\t"		=> 'return',
        KEY_ENTER()     => 'open-popup',
        "\n"            => 'open-popup',
	KEY_RIGHT()	=> 'open-popup',
	"l"		=> 'open-popup',
	" "		=> 'open-popup',
	KEY_DOWN()	=> 'select-next',
	"j"		=> 'select-next',
	KEY_UP()	=> 'select-prev',
	"k"		=> 'select-prev',
);

sub new ()
{
	my $class = shift;

	my %args = (
		-parent		 => undef,	# the parent window
		-width		 => undef,	# the width of the checkbox
		-x		 => 0,		# the horizontal position rel. to parent
		-y		 => 0,		# the vertical position rel. to parent
		-values		 => [],		# values
		-labels		 => {},		# labels for the values
		-selected	 => undef,	# the current selected value

		-bindings	 => {%bindings},
		-routines	 => {%routines},

		@_,
	
		-focus		 => 0,
	);

	# The windowscr height should be 1.
	$args{-height} = height_by_windowscrheight(1,%args);
	
	# No width given? Then make the width large
	# enough to contain the longest label.
	$args{-width} = width_by_windowscrwidth(
		maxlabelwidth(%args) + 1, 
		-border => 1) unless defined $args{-width};

	my $this = $class->SUPER::new( %args );

	# Create the ListBox. Layouting will be done
	# in the layout routine.
	my $listbox = new Curses::UI::ListBox(
		-parent		=> $this,
		-assubwin 	=> 0,
		-border   	=> 1,
		-values	   	=> $this->{-values},
		-labels 	=> $this->{-labels},
		-selected	=> $this->{-selected},
		-vscrollbar 	=> 1,
	);
	$this->{-listboxobject} = $listbox;
	
	$this->layout;

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;

	$this->delallwin();

	$this->SUPER::layout();

	# Create the label on the widget.
	my $label = new Curses::UI::Label(
		-parent   => $this,
		-x        => 0,
		-y        => 0,
	);
	$this->{-labelobject} = $label;

	# Compute the location and length of the listbox.
	my $ll = height_by_windowscrheight(@{$this->{-values}}, -border=>1);
	my $lx = $this->{-x} + $this->{-parent}->{-sx};
	my $ly = $this->{-y} + $this->{-parent}->{-sy} + 1;

	# Don't let the listbox grow out of the screen.
	if ($this->{-y}+$ll > $ENV{LINES}) {
		$ll = $ENV{LINES} - $this->{-y};
	}

	# It's a bit small :-( Can we place it up-side-down?
	my $lim = int($ENV{LINES}/2);
	if ($ll < $lim and ($this->{-sy}+$this->{-y}) > $lim) {
		$ll = height_by_windowscrheight(
			@{$this->{-values}}, 
			-border=>1
		);
		my $y = $this->{-y};
		$y -= $ll - 1;
		if ($y<0)
		{
			$y = 1;
			$ll = $this->{-y};
		}	
		$ly = $y + $this->{-parent}->{-sy} - 1;
	}
		
	# At the time the listbox is created, we do not
	# yet have the listbox, but layout is already 
	# called. So only layout the listbox if it exists.
	#
	if (defined $this->{-listboxobject}) {
		my $lb = $this->{-listboxobject};
		$lb->{-x}	= $lx;
		$lb->{-y} 	= $ly;
		$lb->{-width} 	= $this->width;
		$lb->{-height}	= $ll;
		$lb->layout;
	}

	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;
		
	# Draw the widget.
	$this->SUPER::draw(1);

	# Get the selected label.
	my $sellabel = $this->{-listboxobject}->get_selectedlabel;
	if (defined $sellabel) {
		$this->{-labelobject}->reverse($this->{-focus});
		$this->{-labelobject}->text($sellabel);
	} else {
		$this->{-labelobject}->reverse($this->{-focus});
		$this->{-labelobject}->dim(not $this->{-focus});
		$this->{-labelobject}->text("-"x($this->{-labelobject}->screenwidth));
	}

	# Draw the label
	$this->{-labelobject}->draw(1);
	
	$this->{-windowscr}->move(0,$this->screenwidth-1);
	$this->{-windowscr}->noutrefresh;
	doupdate() unless $no_doupdate;;

	return $this;
}

sub focus()
{
	my $this = shift;
	$this->generic_focus(
		2,
		NO_CONTROLKEYS,
		CURSOR_INVISIBLE
	);
}

sub open_popup()
{
	my $this = shift;
        $this->{-listboxobject}->draw;
        $this->{-listboxobject}->focus;
	$this->root->rebuild;
	return $this;
}

sub get()
{
	my $this = shift;
	$this->{-listboxobject}->get;
}

sub select_next()
{
	my $this = shift;
	unless (defined $this->{-listboxobject}->{-selected}) 
	{
		$this->{-listboxobject}->{-selected} = 0;
	} else {
		$this->{-listboxobject}->option_next;
		$this->{-listboxobject}->option_select;
	}
	return $this;
}

sub select_prev()
{
	my $this = shift;
	$this->{-listboxobject}->option_prev;
	$this->{-listboxobject}->option_select;
	return $this;
}

sub set_routine()
{
	my $this = shift;
	my $binding = shift;
	my $routine = shift;

	# Delegate set_binding to listboxobject if needed.
	if (not defined $this->{-routines}->{$binding}) {
		$this->{-listboxobject}->set_routine($binding, $routine);
	} else {
		$this->SUPER::set_routine($binding, $routine);
	}
}

1;

