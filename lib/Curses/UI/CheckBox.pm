# ----------------------------------------------------------------------
# Curses::UI::CheckBox
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::CheckBox;

use strict;
use Curses;
use Curses::UI::Label;
use Curses::UI::Common;
use Curses::UI::Widget;

use vars qw($VERSION @ISA);
$VERSION = '1.00';
@ISA = qw(Curses::UI::Container Curses::UI::Common);

my %routines = (
        'return'   	=> 'RETURN',
        'uncheck'       => \&uncheck,
        'check'      	=> \&check,
        'toggle'      	=> \&toggle,
);

my %bindings = (
        KEY_ENTER()     => 'return',
	KEY_TAB()	=> 'return',
        KEY_SPACE()     => 'toggle',
        '0'             => 'uncheck',
        'n'             => 'uncheck',
        '1'             => 'check',
        'y'             => 'check',
);

sub new ()
{
	my $class = shift;

	my %args = (
		-parent		 => undef,	# the parent window
		-width		 => undef,	# the width of the checkbox
		-x		 => 0,		# the horizontal position rel. to parent
		-y		 => 0,		# the vertical position rel. to parent
		-checked	 => 0,		# checked or not?
		-label		 => '',		# the label text

		-bindings	 => {%bindings},
		-routines	 => {%routines},

		@_,
	
		-focus		 => 0,
	);

	# The windowscr height should be 1.
	$args{-height} = height_by_windowscrheight(1,%args);
	
	# No width given? Then make the width the same size
	# as the label + checkbox.
	$args{-width} = width_by_windowscrwidth(4 + length($args{-label}),%args)
		unless defined $args{-width};
	
	my $this = $class->SUPER::new( %args );
	
	# Create the label on the widget.
	$this->add(
		'label', 'Label',
		-text     => $this->{-label},
		-x        => 4,
		-y        => 0
	);

	$this->layout;

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;
	return $this if $Curses::UI::screen_too_small;

	my $label = $this->getobj('label');
	if (defined $label)
	{
		my $lh = $label->{-height};
		$lh = 1 if $lh <= 0;	
		$this->{-height} = $lh;
	}

	$this->SUPER::layout;
	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

        # Return immediately if this object is hidden.
        return $this if $this->hidden;
		
	# Draw the widget.
	$this->SUPER::draw(1);

	# Draw the checkbox.
	$this->{-windowscr}->attron(A_BOLD) if $this->{-focus};	
	$this->{-windowscr}->addstr(0, 0, '[ ]');
	$this->{-windowscr}->addstr(0, 1, 'X') if $this->{-checked};
	$this->{-windowscr}->attroff(A_BOLD) if $this->{-focus};	

	$this->{-windowscr}->move(0,1);
	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;

	return $this;
}

sub focus()
{
	my $this = shift;
	$this->generic_focus(
		undef,
		NO_CONTROLKEYS,
		CURSOR_VISIBLE
	);
}

sub uncheck()
{
	my $this = shift;
	$this->{-checked} = 0;
	$this->draw;
}

sub check()
{
	my $this = shift;
	$this->{-checked} = 1;
	$this->draw;
}

sub toggle()
{
	my $this = shift;
	$this->{-checked} = ! $this->{-checked};
	$this->draw;
}

sub get()
{
	my $this = shift;
	return $this->{-checked};
}

1;


=pod

=head1 NAME

Curses::UI::CheckBox - Create and manipulate checkbox widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $checkbox = $win->add(
        'mycheckbox', 'Checkbox',
        -label     => 'Say hello to the world',
        -checked   => 1,
    );

    $checkbox->focus();
    my $checked = $checkbox->get();


=head1 DESCRIPTION

Curses::UI::CheckBox is a widget that can be used to create 
a checkbox. A checkbox has a label which says what the 
checkbox is about and in front of the label there is a
box which can have an "X" in it. If the "X" is there, the
checkbox is checked (B<get> will return a true value). If
the box is empty, the checkbox is not checked (B<get> will
return a false value). A checkbox looks like this:

    [X] Say hello to the world

See exampes/demo-Curses::UI::CheckBox in the distribution
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

=item * B<-label> < TEXT >

This will set the text label for the checkbox widget 
to TEXT.

=item * B<-checked> < BOOLEAN >

This option determines if at creation time the checkbox
should be checked or not. By default this option is
set to false, so the checkbox is not checked.

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

This method will return the current state of the checkbox
(0 = not checked, 1 = checked).

=item * B<check> ( )

This method can be used to set the checkbox to its checked state.

=item * B<uncheck> ( )

This method can be used to set the checkbox to its unchecked state.

=item * B<toggle> ( )

This method will set the checkbox in "the other state". This means
that the checkbox will get checked if it is not and vice versa.


=back




=head1 DEFAULT BINDINGS

=over 4

=item * <B<tab>>, <B<enter>>

Call the 'return' routine. This will have the widget 
loose its focus.

=item * <B<space>>

Call the 'toggle' routine (see the B<toggle> method). 

=item * <B<0>>, <B<n>>

Call the 'uncheck' routine (see the B<uncheck> method).

=item * <B<1>>, <B<y>>

Call the 'check' routine (see the B<check> method).

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

