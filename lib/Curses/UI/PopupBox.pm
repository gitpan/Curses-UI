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
	KEY_TAB()	=> 'return',
        KEY_ENTER()     => 'open-popup',
	KEY_RIGHT()	=> 'open-popup',
	"l"		=> 'open-popup',
	KEY_SPACE()	=> 'open-popup',
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
		-wraparound      => undef,      # wraparound? 
		-sbborder	 => 1,		# square bracket border

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

	my %listbox_options = ();
	foreach my $option (qw(-values -labels -selected -wraparound)) {	
		$listbox_options{$option} = $this->{$option}
			if defined $this->{$option};
	}

	my $listbox = new Curses::UI::ListBox(
		-parent		=> $this,
		-assubwin 	=> 0,
		-border   	=> 1,
		-vscrollbar 	=> 1,
		%listbox_options
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
	return $this if $Curses::UI::screen_too_small;

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

__END__

=pod

=head1 NAME

Curses::UI::PopupBox - Create and manipulate popupbox widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $popupbox = $win->add(
        'mypopupbox', 'PopupBox',
        -values    => [1, 2, 3],
        -labels    => { 1 => 'One', 
                        2 => 'Two', 
                        3 => 'Three' },
    );

    $popupbox->focus();
    my $value = $popupbox->get();


=head1 DESCRIPTION

Curses::UI::Popupbox is a widget that can be used to create 
something very similar to a basic L<Curses::UI::ListBox|Curses::UI::ListBox>.
The difference is that the widget will show only the
currently selected value (or "-------" if no value is yet
selected). The list of possible values will be shown as a 
separate popup window if requested. 

Normally the widget will look something like this:

 [Current value ]

If the popup window is opened, it looks something like this:
 

 [Current value ]
 +--------------+
 |Other value   |
 |Current value | 
 |Third value   |
 +--------------+


See exampes/demo-Curses::UI::PopupBox in the distribution
for a short demo.



=head1 STANDARD OPTIONS

B<-parent>, B<-x>, B<-y>, B<-width>, B<-height>, 
B<-pad>, B<-padleft>, B<-padright>, B<-padtop>, B<-padbottom>,
B<-ipad>, B<-ipadleft>, B<-ipadright>, B<-ipadtop>, B<-ipadbottom>,
B<-title>, B<-titlefullwidth>, B<-titlereverse>

For an explanation of these standard options, see 
L<Curses::UI::Widget|Curses::UI::Widget>.




=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item * B<-values> < LIST >

=item * B<-labels> < HASHREF >

=item * B<-selected> < VALUE >

=item * B<-wraparound> < BOOLEAN >

These options are exactly the same as the options for
the ListBox widget. So for an explanation of these,
take a look at L<Curses::UI::ListBox|Curses::UI::ListBox>.

=back




=head1 METHODS

=over 4

=item * B<new> ( HASH )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget> 
for an explanation of these.

=item * B<get> ( )

This method will return the currently selected value.

=back




=head1 DEFAULT BINDINGS

There are bindings for the widget itself and bindings
for the popup listbox that can be opened by this widget.

=head2 The widget itself

=over 4

=item * <B<tab>>

Call the 'return' routine. This will have the widget 
loose its focus.

=item * <B<enter>>, <B<cursor-right>, <B<l>>, <B<space>>

Call the 'open-popup' routine. This will show the 
popup listbox and bring the focus to this listbox. See
B<The popup listbox> below for a description of the bindings 
for this listbox.

=item * <B<cursor-down>>, <B<j>>

Call the 'select-next' routine. This will select the 
item in the list that is after the currently selected
item (unless the last item is already selected). If 
no item is selected, the first item in the list will
get selected. 

=item * <B<cursor-up>>, <B<k>>

Call the 'select-prev' routine. This will select the 
item in the list that is before the currently selected
item (unless the first item is already selected). If 
no item is selected, the first item in the list will
get selected. 

=back 

=head2 The popup listbox

The bindings for the popup listbox are the same as the bindings
for the ListBox widget. So take a look at 
L<Curses::UI::ListBox|Curses::UI::Listbox> for a description
of these. The difference is that the 'return' and 'option-select'
routine will have the popup listbox to close. If the routine
'option-select' is called, the active item will get selected.


=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::ListBox|Curses::UI:ListBox>
L<Curses::UI::Widget|Curses::UI::Widget>, 
L<Curses::UI::Common|Curses::UI:Common>




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

=end


