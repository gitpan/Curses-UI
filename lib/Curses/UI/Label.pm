# ----------------------------------------------------------------------
# Curses::UI::Label
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Label;
use strict;
use Curses;
use Curses::UI::Widget;

use vars qw($VERSION @ISA);
$VERSION = '1.00';
@ISA = qw(Curses::UI::Widget);

sub new ()
{
	my $class = shift;
	my %args = (
		-parent		 => undef,	# the parent window
		-width		 => undef,	# the width of the label
		-x		 => 0,		# the horizontal position,
                                                # relative to the parent
		-y		 => 0,		# the vertical position,
                                                # relative to the parent
		-text		 => undef,	# the text to show
		-textalignment   => undef,  	# left / middle / right
		-bold            => 0,		# Special attributes
		-reverse         => 0,
		-underline       => 0,	
		-dim	         => 0,
		-blink	         => 0,
                -paddingspaces   => 0,          # Pad text with spaces?
		@_,
	);

	# The windowscr height should be 1.
	$args{-height} = height_by_windowscrheight(1,%args);
	
	# No width given? Then make the width the same size
	# as the text. No initial text? Then let
	# Curses::UI::Widget figure it out.
	$args{-width} = width_by_windowscrwidth(length($args{-text}), %args)
		unless defined $args{-width} or not defined $args{-text};
	$args{-text} = '' unless defined $args{-text};

	# Create the widget.
	my $this = $class->SUPER::new( %args );

	$this->layout();

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;
	$this->SUPER::layout;
	return $this if $Curses::UI::screen_too_small;
	$this->compute_xpos;
	return $this;
}


sub bold ($;) { shift()->set_attribute('-bold', shift()) }
sub reverse ($;) { shift()->set_attribute('-reverse', shift()) }
sub underline ($;) { shift()->set_attribute('-underline', shift()) }
sub dim ($;) { shift()->set_attribute('-dim', shift()) }
sub blink ($;) { shift()->set_attribute('-blink', shift()) }
sub set_attribute($$;)
{
	my $this = shift;
	my $attribute = shift;
	my $value = shift || 0;

	$this->{$attribute} = $value;
	$this->draw(1);

	return $this;
}

sub text($;)
{
	my $this = shift;

	my $text = shift;
	if (defined $text) 
	{
		$this->{-text} = $text;
		$this->compute_xpos;
		$this->draw(1);
		return $this;
	} else {
		return $this->{-text};
	}
}

sub get() { shift()->text }

sub textalignment($;)
{
	my $this = shift;
	my $value = shift;
	$this->{-textalignment} = $value;
	$this->compute_xpos;
	$this->draw(1);
	return $this;
}

sub compute_xpos()
{
	my $this = shift;

	# Compute the x location of the text.
	my $xpos = 0;
	if (defined $this->{-textalignment})
	{
	    if ($this->{-textalignment} eq 'right') {
		$xpos = $this->screenwidth - length($this->{-text});
	    } elsif ($this->{-textalignment} eq 'middle') {
		$xpos = int (($this->screenwidth-length($this->{-text}))/2);
	    }
	}
	$xpos = 0 if $xpos < 0;
	$this->{-xpos} = $xpos;

	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

        # Return immediately if this object is hidden.
        return $this if $this->hidden;
		
	# Clear all attributes.
	$this->{-windowscr}->attroff(A_REVERSE);
	$this->{-windowscr}->attroff(A_BOLD);
	$this->{-windowscr}->attroff(A_UNDERLINE);
	$this->{-windowscr}->attroff(A_BLINK);
	$this->{-windowscr}->attroff(A_DIM);
	
	# Draw the widget.
	$this->SUPER::draw(1);
	
	# Set wanted attributes.
	$this->{-windowscr}->attron(A_REVERSE) 	 if $this->{-reverse};
	$this->{-windowscr}->attron(A_BOLD) 	 if $this->{-bold};
	$this->{-windowscr}->attron(A_UNDERLINE) if $this->{-underline};
	$this->{-windowscr}->attron(A_BLINK)	 if $this->{-blink};
	$this->{-windowscr}->attron(A_DIM)	 if $this->{-dim};


	# Draw the text. Clip it if it is too long.
	my $show = $this->{-text};
	if (length($show) > $this->screenwidth) {
		# Break text
		$show = substr($show, 0, $this->screenwidth);
		$show =~ s/...$/.../;
	} elsif ($this->{-paddingspaces}) {
		$this->{-windowscr}->addstr(0, 0, " "x$this->screenwidth);	
	}

	$this->{-windowscr}->addstr(0, $this->{-xpos}, $show);

	$this->{-windowscr}->noutrefresh;
	doupdate() unless $no_doupdate;

	return $this;
}

1;

__END__


=pod

=head1 NAME

Curses::UI::Label - Create and manipulate label widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $label = $win->add(
        'mylabel', 'Label',
        -label     => 'Hello, world!',
        -bold      => 1,
    );

    $label->draw;



=head1 DESCRIPTION

Curses::UI::Label is a widget that shows a textstring.
This textstring can be drawn using these special
features: bold, dimmed, reverse, underlined, and blinking.

See exampes/demo-Curses::UI::Label in the distribution
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

=item * B<-text> < SCALAR >

This will set the text on the label to SCALAR.

=item * B<-textalignment> < SCALAR >

This option controls how the text should be aligned inside
the label. SCALAR can be 'left', 'middle' and 'right'. The 
default value for this option is 'left'. 

=item * B<-paddingspaces> < BOOLEAN >

This option controls if padding spaces should be added
to the text if the text does not fill the complete width
of the widget. The default value for BOOLEAN is false.
An example use of this option is:

    $win->add(
        'label', 'Label', 
        -width         => -1, 
        -paddingspaces => 1,
        -text          => 'A bit of text', 
    );

This will create a label that fills the complete width of 
your screen and which will be completely in reverse font
(also the part that has no text on it). See the demo
in the distribution (examples/demo-Curses::UI::Label)
for a clear example of this)

=item * B<-bold> < BOOLEAN >

If BOOLEAN is true, text on the label will be drawn in 
a bold font.

=item * B<-dim> < BOOLEAN >

If BOOLEAN is true, text on the label will be drawn in 
a dim font.

=item * B<-reverse> < BOOLEAN >

If BOOLEAN is true, text on the label will be drawn in
a reverse font.

=item * B<-underline> < BOOLEAN >

If BOOLEAN is true, text on the label will be drawn in
an underlined font.

=item * B<-blink> < BOOLEAN >

If BOOLEAN is option is true, text on the label will be 
drawn in a blinking font.

=back




=head1 METHODS

=over 4

=item * B<new> ( HASH )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget> 
for an explanation of these.

=item * B<bold> ( BOOLEAN )

=item * B<dim> ( BOOLEAN )

=item * B<reverse> ( BOOLEAN )

=item * B<unlderline> ( BOOLEAN )

=item * B<blink> ( BOOLEAN )

These methods can be used to control the font in which the text on
the label is drawn, after creating the widget. The font option
will be turned on for a true value of BOOLEAN.

=item * B<textalignment> ( SCALAR )

Set the textalignment. SCALAR can be 'left',
'middle' or 'right'. You will have to call the B<draw> 
method of the widget to see the change.

=item * B<text> ( [SCALAR] )

Without the SCALAR argument, this method will return the current 
text of the widget. With a SCALAR argument, the text on the widget
will be set to SCALAR. You will have to call the B<draw> method of
the widget to see the change.

=item * B<get> ( )

This will call the B<text> method without any argument and thus
it will return the current text of the label.

=back




=head1 DEFAULT BINDINGS

Since a Label is a non-interacting widget, it does not have
any bindings.




=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::Widget|Curses::UI::Widget>, 




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

=end





