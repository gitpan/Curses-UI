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
use Curses::UI::Common;

use vars qw($VERSION @ISA);
$VERSION = '1.00';
@ISA = qw(Curses::UI::Widget Curses::UI::Common);

sub new ()
{
	my $class = shift;
	my %args = (
		-parent		 => undef,	# the parent window
		-width		 => undef,	# the width of the label
		-x		 => 0,		# the horizontal position rel. to parent
		-y		 => 0,		# the vertical position rel. to parent
		-text		 => undef,	# the text to show
		-textalignment   => undef,  	# left / middle / right
		-bold            => 0,		# Special attributes
		-reverse         => 0,
		-underline       => 0,	
		-dim	         => 0,
		-blink	         => 0,
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
		
	# Draw the widget.
	$this->SUPER::draw(1);
	
	# Set attributes
	$this->{-windowscr}->attroff(A_REVERSE);
	$this->{-windowscr}->attroff(A_BOLD);
	$this->{-windowscr}->attroff(A_UNDERLINE);
	$this->{-windowscr}->attroff(A_BLINK);
	$this->{-windowscr}->attroff(A_DIM);
	$this->{-windowscr}->attron(A_REVERSE) 	 if $this->{-reverse};
	$this->{-windowscr}->attron(A_BOLD) 	 if $this->{-bold};
	$this->{-windowscr}->attron(A_UNDERLINE) if $this->{-underline};
	$this->{-windowscr}->attron(A_BLINK)	 if $this->{-blink};
	$this->{-windowscr}->attron(A_DIM)	 if $this->{-dim};

	# Draw the text.
	my $show = $this->{-text};
	if (length($show) > $this->screenwidth) {
		# Break text
		$show = substr($show, 0, $this->screenwidth);
		$show =~ s/...$/.../;
	} else {
		# Add padding spaces
		$show .= " "x($this->screenwidth-length($show)-$this->{-xpos});
	}
	$this->{-windowscr}->addstr(0, $this->{-xpos}, $show);

	$this->{-windowscr}->noutrefresh;
	doupdate() unless $no_doupdate;

	return $this;
}

1;

