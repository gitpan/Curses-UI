# ----------------------------------------------------------------------
# Curses::UI::MenuListBox
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::MenuListBox;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Container;
use Curses::UI::Window;
use Curses::UI::ListBox;
use Curses::UI::Widget;

use vars qw($VERSION @ISA);
$VERSION = '1.00';
@ISA = qw(Curses::UI::ListBox Curses::UI::Common Curses::UI::Window);

sub new()
{
        my $class = shift;

	my %args = (
		-menu 		=> {},		# The menu contents
		-is_topmenu	=> 0,		# First pulldown or not?
		@_,
		-vscrollbar 	=> 1,
		-assubwin 	=> 0,
		-border 	=> 1,
		-wraparound     => 1,
	);

        # First determine the longest label.
        my $longest = 0;
        foreach my $item (@{$args{-menu}})
        {
                my $l = $item->{-label};
                die "Missing argument: -label for the MenuListBox"
                        unless defined $l;
                $longest = length($l) if length($l) > $longest;
        }

	# Increase $longest for some whitespace on the
	# right side of the labels.
	$longest++;

        # Now create the values for the listbox.
        my @values = ();
        my $has_submenu = 0;
        foreach my $item (@{$args{-menu}})
        {
                my $l = $item->{-label};
                if (defined($item->{-submenu})) {
                        $l = sprintf("%-${longest}s  >>", $l);
                        $has_submenu++;
                }
                push @values, $l;
        }

        # If there are submenu's, make the $longest variable higher.
        $longest += 4 if $has_submenu;
	$args{-values} = \@values;

	# Determine the needed width and hight for the listbox.
	my $w = width_by_windowscrwidth($longest, %args);
	my $h = height_by_windowscrheight(@values, %args);
	$args{-width} = $w;
	$args{-height} = $h;

	# Check if the menu does fit on the right. If not, try to
	# shift it to the left as far as needed. 
	if ($args{-x} + $w > $ENV{COLS}) {
		$args{-x} = $ENV{COLS} - $w;
		$args{-x} = 0 if $args{-x} < 0;
	}
	
        my $this = $class->SUPER::new(%args);

	# Create binding routines.
	$this->set_routine('cursor-left',  \&cursor_left);
	$this->set_routine('cursor-right', \&cursor_right);
	$this->set_routine('option-select',\&option_select);
	$this->set_routine('escape',       'ESCAPE');

	# Create bindings.
	$this->set_binding('escape',  	   KEY_ESCAPE);
	$this->set_binding('cursor-left',  KEY_LEFT(), 'h'); 
	$this->set_binding('cursor-right', KEY_RIGHT(), 'l'); 

        return bless $this, $class;
}

sub current_item()
{
	my $this = shift;
	$this->{-menu}->[$this->{-ypos}];
}

sub cursor_left()
{
	my $this = shift;
	return 'CURSOR_LEFT';
	return $this;
}

sub cursor_right()
{
	my $this = shift;

	# Get the current menu-item.
	my $item = $this->current_item;

	# This item has a submenu. Open it.
	if (defined $item->{-submenu}) 
	{
				
		# Compute the (x,y)-position of the new menu.
		my $x = $this->{-x} + $this->borderwidth;
		my $y = $this->{-y} + $this->{-ypos};

		# Create the submenu.
		my ($return, $key) = $this->root->add(
			"_submenu_$this", 'MenuListBox',
			-x      => $x,
			-y      => $y,
			-menu   => $this->{-menu}->[$this->{-ypos}]->{-submenu},
		)->draw->focus;

		$this->root->delete("_submenu_$this");
		$this->root->rebuild;

		if (not ref $return) {
			# Cursor left? Stay in this submenu.
			if ($return ne 'CURSOR_LEFT') {
				return $return;
			}
		}
		elsif (ref $return eq 'CODE') {
			return $return;
		}

	# This item has no submenu. Return CURSOR_RIGHT
	# if this is a topmenu.
	} else {
		return 'CURSOR_RIGHT' if $this->{-is_topmenu};
	}

	return $this;
}

sub option_select()
{
	my $this = shift;
	
	# Get the current menu-item.
	my $item = $this->current_item;

	if (defined $item->{-submenu}) { 
		return $this->cursor_right;
	} 
	elsif (ref $item->{-callback} eq 'CODE') {
		return $item->{-callback};
	}
	elsif (defined $item->{-return}) {
		return $item->{-return};
	}

	return $this;
}

1;


