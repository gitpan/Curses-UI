# ----------------------------------------------------------------------
# Curses::UI::Buttonbox
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Buttonbox;

use strict;
use Curses;
use Carp qw(confess);
use Curses::UI::Widget;
use Curses::UI::Common;

use vars qw($VERSION @ISA @EXPORT);
$VERSION = '1.01';

require Exporter;
@ISA = qw(Curses::UI::Widget Exporter Curses::UI::Common);
@EXPORT = qw(compute_buttonwidth);

# Definition of the most common buttons.
my %buttondef = (
	'ok'	=> {
			-label    => '< OK >',
			-value    => 1,
			-onpress  => undef,
			-shortcut => 'o',
		   },
	'cancel'=> {
			-label    => '< Cancel >',
			-value    => 0,
			-onpress  => undef,
			-shortcut => 'c',
		   }, 
	'yes'	=> {
			-label    => '< yes >',
			-value    => 1,
			-onpress  => undef,
			-shortcut => 'y',
		   },
	'no'    => {
			-label    => '< No >',
			-value    => 0,
			-onpress  => undef,
			-shortcut => 'n',
		   }, 
	
);

# The default button to use if no buttons were defined.
my $default_btn = [ 'ok' ];

my %routines = (
	'press-button'  => \&press_button,
	'return' 	=> 'LEAVE_CONTAINER',
	'loose-focus'	=> 'LOOSE_FOCUS',
	'next'		=> \&next_button,
	'previous'	=> \&previous_button,
	'shortcut'	=> \&shortcut,  
);

my %bindings = (
	KEY_ENTER()	=> 'press-button',
	KEY_SPACE()	=> 'press-button',
	KEY_LEFT()	=> 'previous',
	'h'		=> 'previous',
	KEY_RIGHT()	=> 'next',
	'l'		=> 'next',
	''		=> 'shortcut',
	
);

sub new ()
{
	my $class = shift;

	my %userargs = @_;
	keys_to_lowercase(\%userargs);
	
	my %args = (
		-parent		 => undef,	  # the parent window
		-buttons 	 => $default_btn, # buttons (arrayref)
		-buttonalignment => undef,  	  # left / middle / right
		-selected 	 => 0,		  # which selected
		-width		 => undef,	  # the width of the buttons widget
		-x		 => 0,		  # the horizontal position rel. to parent
		-y		 => 0,		  # the vertical position rel. to parent

		-mayloosefocus	 => 1,		  # Enable TAB to loose focus?
		-routines	 => {%routines},
		-bindings	 => {%bindings},

		%userargs,

		-focus		 => 0,
	);

	# The windowscr height should be 1.
	$args{-height} = height_by_windowscrheight(1,%args);

	# Process button definitions.
	$args{-buttons} = process_buttondefs($args{-buttons});

	# Create the widget.
	my $this = $class->SUPER::new( %args );

	$this->layout();

	return bless $this, $class;
}


sub process_buttondefs($;)
{
	my $buttons = shift;

	# Process button types.
	my @buttons = ();
	foreach my $button (@$buttons)
	{
		if (ref $button eq 'HASH') {
			# noop
		}
		elsif (not ref $button) {
			my $realbutton = $buttondef{$button};
			unless (defined $realbutton) {
				confess "Invalid button type: $button";
			}
			$button = $realbutton;
		} else {
			confess "Invalid button definition (it should " 
			      . "be a hash reference, but is a "
			      . (ref $button) . " reference."; 
		}

		keys_to_lowercase($button);
		push @buttons, $button;
	}

	return \@buttons;
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
	foreach my $button (@{$this->{-buttons}}) {
		if (defined $button->{-shortcut}) {
			$button->{-shortcut} = uc $button->{-shortcut};
		}
	}

	return $this;
}

sub get_selected_button()
{
	my $this = shift;
	my $selected = $this->{-selected}; 
	my $button = $this->{-buttons}->[$selected];
	return $button;
}

sub get()
{
	my $this = shift;
	my $button = $this->get_selected_button;
	if (defined $button->{-value}) {
		return $button->{-value};
	} else {
		return $this->{-selected};
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

sub press_button()
{
	my $this = shift;
	my $button = $this->get_selected_button;
	my $command = $button->{-onpress};
	if (defined $command and ref $command eq 'CODE') {
		$command->($this);
	}	

	return $this->do_routine('return', undef);
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
	foreach my $button (@{$this->{-buttons}})
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
			$button->{-label}
		);	

		
		# Draw shortcut if available.
		my $sc = $button->{-shortcut};
		if (defined $sc)
		{
			my $pos = index(uc $button->{-label}, $sc);
			if ($pos >= 0)
			{
				my $letter = substr($button->{-label}, $pos, 1); 
				$this->{-windowscr}->attron(A_UNDERLINE);
				$this->{-windowscr}->addch(
					0,
					$this->{-xpos} + $x + $pos,
					$letter
				);
				$this->{-windowscr}->attroff(A_UNDERLINE);
			}
		}

		$x += 1 + length($button->{-label});
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
	$buttons = process_buttondefs($buttons);

        # Spaces
        my $width = @$buttons - 1;

        # Buttons
        foreach my $button (@$buttons) {
                $width += length($button->{-label});
        }

        return $width;
}

sub shortcut()
{
	my $this = shift;
	my $key = uc shift;
	
	# Walk through shortcuts to see if the pressed key
	# is in the list of -shortcuts.
	my $idx = 0;
	my $found_idx;
	SHORTCUT: foreach my $button (@{$this->{-buttons}})
	{
		my $sc = $button->{-shortcut};
		if (defined $sc and $sc eq $key)
		{
			$found_idx = $idx;
			last SHORTCUT;
		}
		$idx++;
	}

	# Shortcut found?
	if (defined $found_idx) 
	{
		$this->{-selected} = $found_idx;
		return $this->process_bindings(KEY_ENTER());
	}

	return $this;
}

1;


=pod

=head1 NAME

Curses::UI::Buttonbox - Create and manipulate button widgets

=head1 CLASS HIERARCHY

 Curses::UI::Widget
    |
    +----Curses::UI::Buttonbox  


=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $buttons = $win->add(
        'mybuttons', 'Buttonbox',
        -buttons   => [
            { 
              -label => '< Button 1 >',
              -value => 1,
              -shortcut => 1 
            },{ 
              -label => '< Button 2 >',
              -value => 2,
              -shortcut => 2 
            }
        ]
    );

    $buttons->focus();
    my $value = $buttons->get();


=head1 DESCRIPTION

Curses::UI::Buttonbox is a widget that can be used to create an
array of buttons (or, of course, only one button). 

See exampes/demo-Curses::UI::Buttonbox in the distribution
for a short demo.



=head1 STANDARD OPTIONS

B<-parent>, B<-x>, B<-y>, B<-width>, B<-height>, 
B<-pad>, B<-padleft>, B<-padright>, B<-padtop>, B<-padbottom>,
B<-ipad>, B<-ipadleft>, B<-ipadright>, B<-ipadtop>, B<-ipadbottom>,
B<-title>, B<-titlefullwidth>, B<-titlereverse>, B<-onfocus>, 
B<-onblur>

For an explanation of these standard options, see 
L<Curses::UI::Widget|Curses::UI::Widget>.




=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item * B<-buttons> < ARRAYREF >

This option takes a reference to a list of buttons.
The list may contain both predefined button types and  
complete button definitions of your own.

* B<Your own button definition>

  A button definition is a reference to a hash. This
  hash can have the following key-value pairs:

  obligatory:
  -----------

  -label      This determines what text should be drawn
              on the button.

  optional:
  ---------

  -value      This determines the returnvalue for the
              get() method. If the value is not defined,
              the get() method will return the index
              of the button.
 
  -shortcut   The button will act as if it was pressed
              if the key defined by -shortcut is pressed 

  -onpress    If the value for -onpress is a CODE reference,
              this code will be executes if the button
              is pressed, before the buttons widget loses
              focus and returns.

* B<Predefined button type>

  This module has a predefined list of frequently used button
  types. Using these in B<-buttons> makes things a lot
  easier. The predefined button types are:

  ok          -label    => '< OK >'
              -shortcut => 'o'
              -value    => 1
              -onpress  => undef

  cancel      -label    => '< Cancel >'
              -shortcut => 'c'
              -value    => 0
              -onpress  => undef
  
  yes         -label    => '< Yes >'
              -shortcut => 'y'
              -value    => 1
              -onpress  => undef

  no          -label    => '< No >'
              -shortcut => 'n'
              -value    => 0
              -onpress  => undef

Example:

  ....
  -buttons => [
      { -label => '< My own button >',
        -value => 'mine!',
        -shortcut => 'm' },

      'ok',

      'cancel',

      { -label => '< My second button >',
        -value => 'another one',
        -shortcut => 's',
        -onpress => sub { die "Do not press this button!\n" } }
  ]
  ....
    

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

=item * B<onFocus> ( CODEREF )

=item * B<onBlur> ( CODEREF )

=item * B<draw_if_visible> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget> 
for an explanation of these.

=item * B<get> ( )

This method will return the index of the currently active
button. If a value is given for that index (using the
B<-value> option, see B<-buttons> above), that value will be 
returned.

=back




=head1 DEFAULT BINDINGS

=over 4

=item * <B<tab>>

TODO: fix docs on this...
Call the 'loose-focus' routine. This will have the widget 
loose its focus. If you do not want the widget to loose 
its focus, you can disable this binding by using the
B<-mayloosefocus> option (see above).
END TODO

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

