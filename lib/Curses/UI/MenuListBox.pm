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
	
	# Clear 'return' binding.
	$this->clear_binding('return');

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

__END__

=pod

=head1 NAME

Curses::UI::MenuListBox - Create and manipulate menulistbox widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;

    my $menulistbox = $cui->add(
        'mymenulistbox', 'MenuListBox',
        -values    => [1, 2, 3],
        -labels    => { 1 => 'One', 
                        2 => 'Two', 
                        3 => 'Three' },
    );

    $menulistbox->focus();


=head1 DESCRIPTION

This class is a descendant of both the 
L<Curses::UI::Window|Curses::UI::Window> and the
L<Curses::UI::ListBox|Curses::UI::ListBox> class. This means 
that it implements a listbox which can be added as a separate 
window to the L<Curses::UI|Curses::UI> root window. It has
special bindings for behaving nicely within a menu system.

This class is internally used by the 
L<Curses::UI::MenuBar|Curses::UI::MenuBar> class. Normally
you would not want to use this class directly.

=head1 STANDARD OPTIONS

B<-x> and B<-y>. These are the only standard options that 
L<Curses::UI::MenuBar|Curses::UI::MenuBar> uses. 
For an explanation of these standard options, see
L<Curses::UI::Widget|Curses::UI::Widget>.


=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item * B<-is_topmenu> < BOOLEAN >

This option determines if the widget should act as 
a topmenu or not. The bindings for a topmenu are
a bit different from those of a submenu. The default
for BOOLEAN is false.

=item * B<-menu> < ARRAYREF >

The menu items are defined by the ARRAYREF. Each item
of the ARRAYREF contains the definition for a menu item. 
Each item is a reference to a hash. This hash always
contains the key B<-label>. The value of this key
determines the label of the menu item. Next to this
key, the hash should also contain one of the 
following keys:

* B<-callback>

  The value should be a CODE reference. If this menu
  item is selected, the CODE reference will be returned.

* B<-return>

  The value should be a SCALAR value. If this menu
  item is selected, the SCALAR value will be returned.

* B<-submenu>

  The value should be an array reference. This array
  reference has the same structure as the array reference
  for the B<-menu> option.

Example data structure:

    my $submenu = [
        { -label => 'option 1',
          -callback => \&callback1 },

        { -label => 'option 2',
          -callback => \&callback2 },

        { -label => 'option 3',
          -return => 'whatever' },
    ];

    my $menu = [
        { -label => 'Do callback', 
          -callback => \&first_callback },

        { -label => 'Another callback',
          -callback => \&second_callback },

        { -label => 'Simple returnvalue',
          -return => 'some returnvalue' },

        { -label => 'Open submenu',
          -submenu => $submenu },

        { -label => 'Exit',
          -return => sub { exit(0) }}
    ]; 


=back



=head1 METHODS

=over 4

=item * B<new> ( HASH )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget>
for an explanation of these.

=back




=head1 DEFAULT BINDINGS

The bindings for for this class are the same as those for the
L<Curses::UI::ListBox|Curses::UI::ListBox>, except for the 
following points:

=over 4

=item * <B<escape>>

Call the 'escape' routine. The widget will loose its 
focus and return the value 'ESCAPE' to the calling 
routine.

=item * <B<tab>>

This key is in this class not bound to any routine.

=item * <B<cursor-left>>, <B<h>>

Call the 'cursor-left' routine. This routine will 
return the value 'CURSOR_LEFT'. This will make
the widget loose its focus and return 'CURSOR_LEFT'
to the calling routine. 

=item * <B<cursor-right>>, <B<l>>

Call the 'cursor-right' routine. The exact action
for this routine depends upon the fact if the 
current menuitem has a submenu or not:

The current menuitem has no submenu
===================================

If the current menuitem has no submenu and this
widget is not a submenu (so B<-is_topmenu> is set
to a true value), this widget will loose focus
and return the value 'CURSOR_RIGHT' to the calling
routine. This value can be caught by the 
L<Curses::UI::MenuBar|Curses::UI::MenuBar> to select 
the next menu.

The current menuitem has a submenu
==================================

If the current menuitem points to a submenu,
a new menulistbox instance will be created for this
submenu. After that, this menulistbox will get the
focus. The created menulistbox will return a value
if it looses focus. After that the created menulistbox
will be deleted. 

This widget will act differently upon the value that
was returned by the created menulistbox:

* The value 'CURSOR_LEFT'

  This means that in the menulistbox that was created,
  the last called routine was 'cursor-left'. So all
  that is needed is this menulistbox instance to get
  focus (and since it already has focus, actually
  nothing is done at all). 

* Any other SCALAR or CODEREF value

  If a scalar or a coderef is returned by B<focus>,
  this widget will loose its focus and return
  the value to the calling routine.


=item * <B<cursor-right>, <B<l>>, <B<enter>>, <B<space>>

Call the 'option-select' routine. 

If the current menuitem has a submenu, this routine 
will invoke the 'cursor-right' routine.

If it has a -callback or a -return value, the widget
will loose its focus and the value will be returned 
to the calling routine.

=back 





=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::MenuBar|Curses::UI::MenuBar>, 
L<Curses::UI::ListBox|Curses::UI:ListBox>




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

=end

