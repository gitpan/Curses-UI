# ----------------------------------------------------------------------
# Curses::UI::Buttons
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Buttons;

use strict;
use Curses;
use Curses::UI::Widget;
use Curses::UI::Common;

use vars qw($VERSION @ISA @EXPORT);
$VERSION = '1.01';

require Exporter;
@ISA = qw(Curses::UI::Widget Exporter Curses::UI::Common);
@EXPORT = qw(compute_buttonwidth);

my $default_btn = [ '< OK >' ];

my %routines = (
	'return' 	=> 'LEAVE_CONTAINER',
	'loose-focus'	=> 'LOOSE_FOCUS',
	'next'		=> \&next_button,
	'previous'	=> \&previous_button,
	'shortcut'	=> \&shortcut,  
);

my %bindings = (
	KEY_ENTER()	=> 'return',
	KEY_SPACE()	=> 'return',
	KEY_LEFT()	=> 'previous',
	'h'		=> 'previous',
	KEY_RIGHT()	=> 'next',
	'l'		=> 'next',
	''		=> 'shortcut',
	
);

sub new ()
{
	my $class = shift;
	
	my %args = (
		-parent		 => undef,	  # the parent window
		-buttons 	 => $default_btn, # buttons (arrayref)
		-values		 => undef,	  # values for buttons (arrayref)
		-shortcuts	 => undef,	  # shortcut keys
		-buttonalignment => undef,  	  # left / middle / right
		-selected 	 => 0,		  # which selected
		-width		 => undef,	  # the width of the buttonwidget
		-x		 => 0,		  # the horizontal position rel. to parent
		-y		 => 0,		  # the vertical position rel. to parent

		-mayloosefocus	 => 1,		  # Enable TAB to loose focus?
		-routines	 => {%routines},
		-bindings	 => {%bindings},

		@_,

		-focus		 => 0,
	);

	# The windowscr height should be 1.
	$args{-height} = height_by_windowscrheight(1,%args);

	# Create the widget.
	my $this = $class->SUPER::new( %args );

	$this->layout();

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;

	$this->SUPER::layout();
	return $this if $Curses::UI::screen_too_small;

	# Compute the space that is needed for the buttons.
	my $xneed = compute_buttonwidth($this->{-buttons});
	
	if ( $xneed > $this->screenwidth ) {	
		$Curses::UI::screen_too_small++;
		return $this;
	}

	# Compute the x location of the buttons.
	my $xpos = 0;
	if (defined $this->{-buttonalignment})
	{
	    if ($this->{-buttonalignment} eq 'right') {
		$xpos = $this->screenwidth - $xneed;
	    } elsif ($this->{-buttonalignment} eq 'middle') {
		$xpos = int (($this->screenwidth-$xneed)/2);
	    }
	}
	$this->{-xpos} = $xpos;

	$this->{-max_selected} = @{$this->{-buttons}} - 1;

	# May loose focus? Create bindings.
	$this->set_binding('loose-focus', "\t")
		if $this->{-mayloosefocus};

	# Make shortcuts all upper-case.	
	if (defined $this->{-shortcuts}) {
		foreach (@{$this->{-shortcuts}}) {
			$_ = uc $_;
		}
	}

	return $this;
}

sub get()
{
	my $this = shift;
	my $s = $this->{-selected}; 
	if (defined $this->{-values}) {
		return $this->{-values}->[$s];
	} else {
		return $s;
	}
}

sub focus()
{
	my $this = shift;
	return $this->generic_focus(
		undef,
		NO_CONTROLKEYS,
		CURSOR_INVISIBLE
	);
}

sub next_button()
{
	my $this = shift;
	$this->{-selected}++;
	return $this;
}

sub previous_button()
{
	my $this = shift;
	$this->{-selected}--;
	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;
		
        # Return immediately if this object is hidden.
        return $this if $this->hidden;

	# Check if active element isn't out of bounds.
	$this->{-selected} = 0 unless defined $this->{-selected};
	$this->{-selected} = 0 if $this->{-selected} < 0; 
	$this->{-selected} = $this->{-max_selected} 
		if $this->{-selected} > $this->{-max_selected};

	# Draw the widget.
	$this->SUPER::draw(1);
	
	# Draw the buttons.
	my $id = 0;
	my $x  = 0;
	my $cursor_x = 0;
	foreach (@{$this->{-buttons}})
	{
		# Make the focused button reverse.
		if ($this->{-focus} and defined $this->{-selected} 
		     and $id == $this->{-selected}) {
			$this->{-windowscr}->attron(A_REVERSE);
		}

		# Draw the button.
		$this->{-windowscr}->addstr(
			0,
			$this->{-xpos} + $x,
			$_
		);	

		
		# Draw shortcut if available.
		my $sc = $this->{-shortcuts}->[$id];
		if (defined $sc)
		{
			my $pos = index(uc $_, $sc);
			if ($pos >= 0)
			{
				my $letter = substr($_, $pos, 1); 
				$this->{-windowscr}->attron(A_UNDERLINE);
				$this->{-windowscr}->addch(
					0,
					$this->{-xpos} + $x + $pos,
					$letter
				);
				$this->{-windowscr}->attroff(A_UNDERLINE);
			}
		}

		$x += 1 + length($_);
		$this->{-windowscr}->attroff(A_REVERSE) if $this->{-focus};
		
		$id++;
	}
	$this->{-windowscr}->move(0,0);
	$this->{-windowscr}->noutrefresh;
	doupdate() unless $no_doupdate;

	return $this;
}

sub compute_buttonwidth($;)
{
        my $buttons = shift;
        $buttons = $default_btn unless defined $buttons;

        # Spaces
        my $width = @$buttons - 1;

        # Buttons
        foreach (@$buttons) {
                $width += length($_);
        };

        return $width;
}

sub shortcut()
{
	my $this = shift;
	my $key = uc shift;
	
	# Walk through shortcuts to see if the pressed key
	# is in the list of -shortcuts.
	my $idx = -1;
	SHORTCUT: for (my $i=0; $i<@{$this->{-shortcuts}}; $i++) 
	{
		my $sc = $this->{-shortcuts}->[$i];
		if (defined $sc and $sc eq $key)
		{
			$idx = $i;
			last SHORTCUT;
		}
	}

	# Shortcut found?
	if ($idx > -1) 
	{
		$this->{-selected} = $idx;
		return $this->process_bindings(KEY_ENTER());
	}

	return $this;
}

1;


=pod

=head1 NAME

Curses::UI::Buttons - Create and manipulate button widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $buttons = $win->add(
        'mybuttons', 'Buttons',
        -buttons   => ['< Button 1 >', '< Button 2>']
        -values    => [1,2] 
        -shortcuts => ['1','2'],
    );

    $buttons->focus();
    my $value = $buttons->get();


=head1 DESCRIPTION

Curses::UI::Buttons is a widget that can be used to create an
array of buttons. 

See exampes/demo-Curses::UI::Buttons in the distribution
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

=item * B<-buttons> < ARRAYREF >

This option takes a reference to a list of buttonlabels
as its argument. 

=item * B<-values> < ARRAYREF >

This option takes a reference to a list of values as its
argument. The order of the values in the list corresponds
to the order of the buttons.

=item * B<-shortcuts> < ARRAYREF >

This option takes a reference to a list of shortcut
keys as its argument. The order of the keys in the list 
corresponds to the order of the buttons.

=item * B<-selected> < INDEX >

By default the first button (index = 0) is active. If you
want another button to be active at creation time, 
add this option. The INDEX is the index of the button you
want to make active.

=item * B<-buttonalignment> < VALUE >

You can specify how the buttons should be aligned in the 
widget. Available values for VALUE are 'left', 'middle' 
and 'right'.

=item * B<-mayloosefocus> < BOOLEAN >

By default a buttons widget may loose its focus using the
<tab> key. By setting BOOLEAN to a false value,
this binding can be disabled.

=back




=head1 METHODS

=over 4

=item * B<new> ( OPTIONS )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget> 
for an explanation of these.

=item * B<get> ( )

This method will return the index of the currently active
button. If a value is given for that index (using the
B<-values> option, see above), that value will be returned.

=back




=head1 DEFAULT BINDINGS

=over 4

=item * <B<tab>>

Call the 'loose-focus' routine. This will have the widget 
loose its focus. If you do not want the widget to loose 
its focus, you can disable this binding by using the
B<-mayloosefocus> option (see below).

=item * <B<enter>>, <B<space>> 

Call the 'return' routine. By default this routine will have the
container in which the widget is loose its focus. If you do
not like this behaviour, then you can have it loose focus itself
by calling:

    $buttonswidget->set_routine('return', 'RETURN');

For an explanation of B<set_routine>, see 
L<Curses::UI::Widget|Curses::UI::Widget>.


=item * <B<cursor left>>, <B<h>>

Call the 'previous' routine. This will make the previous
button the active button. If the active button already is
the first button, nothing will be done.

=item * <B<cursor right>>, <B<l>

Call the 'next' routine. This will make the next button the
active button. If the next button already is the last button,
nothing will be done.

=item * <B<any other key>>

This will call the 'shortcut' routine. This routine will 
handle the shortcuts that are set by the B<-shortcuts> option.

=back 





=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::Widget|Curses::UI::Widget>, 
L<Curses::UI::Common|Curses::UI::Common>




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

