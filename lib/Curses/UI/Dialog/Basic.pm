# ----------------------------------------------------------------------
# Curses::UI::Dialog::Basic
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Dialog::Basic;

use strict;
use Carp qw(confess);
use Curses;
use Curses::UI::Common;
use Curses::UI::Window;
use Curses::UI::Buttons; # for compute_buttonwidth()

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::Window Curses::UI::Common);
$VERSION = '1.04';

sub new ()
{
	my $class = shift;
	my %args = ( 
		-border		=> 1,
		-message	=> '',		# The message to show
		-ipad		=> 1, 
		@_,
		-titleinverse	=> 1,
		-centered	=> 1,
	);
	
	my $this = $class->SUPER::new(%args);
	
	$this->add('message', 'TextViewer',
		-border 	=> 1,
		-vscrollbar 	=> 1,
		-wrapping 	=> 1,
		-padbottom 	=> 2,
		-text   	=> $this->{-message},
	);	

	# Create a hash with arguments that may be passed to 	
	# the Buttons class.
	my %buttonargs = (
		-buttonalignment => 'right',
	);
	foreach my $arg (qw(-buttons -values -shortcuts 
		-selected -buttonalignment)) { 
		$buttonargs{$arg} = $this->{$arg} 
			if exists $this->{$arg}; 
	}
	my $b = $this->add('buttons', 'Buttons',
		-y    => -1,
		%buttonargs
	);
	
	$this->layout;
	return bless $this, $class;
}

sub layout()
{
	my $this = shift;

	# The maximum available space on the screen.
	my $avail_width = $ENV{COLS};
	my $avail_height = $ENV{LINES};

	# Compute the maximum available space for the message.

	$this->process_padding;

	my $avail_textwidth  = $avail_width;
	$avail_textwidth  -= 2; # border for the textviewer
	$avail_textwidth  -= 2 if $this->{-border};
	$avail_textwidth  -= $this->{-ipadleft} - $this->{-ipadright};

	my $avail_textheight = $avail_height;
	$avail_textheight -= 2; # border for the textviewer
	$avail_textheight -= 2; # empty line and line of buttons
	$avail_textheight -= 2 if $this->{-border};
	$avail_textheight -= $this->{-ipadtop} - $this->{-ipadbottom};

	# Break up the message in separate lines if neccessary.
	my @lines = ();
	foreach (split (/\n/,  $this->{-message})) {
		push @lines, @{text_wrap($_, $avail_textwidth)};
	}

	# Compute the longest line in the message / buttons.
	my $longest_line = 0;
	foreach (@lines) { 
		$longest_line = length($_) 
			if (length($_) > $longest_line);
	}
	my $button_width = compute_buttonwidth($this->{-buttons});
	$longest_line = $button_width if $longest_line < $button_width;

	# Check if there is enough space to show the widget.
	if ($avail_textheight < 1 or $avail_textwidth < $longest_line) {
# TODO unfit detection
#		confess "Not enough room for the $this object";
	}

	# Compute the size of the widget.

	my $w = $longest_line;
	$w += 2; # border of textviewer
	$w += 2; # extra width for preventing wrapping of text
	$w += 2 if $this->{-border};
	$w += $this->{-ipadleft} + $this->{-ipadright}; 

	my $h = @lines;
	$h += 2; # empty line + line of buttons
	$h += 2; # border of textviewer
	$h += 2 if $this->{-border};
	$h += $this->{-ipadtop} + $this->{-ipadbottom}; 

	$this->{-width} = $w;
	$this->{-height} = $h;

	$this->SUPER::layout;
	
	return $this;
}

sub focus()
{
	my $this = shift;
	$this->show;
        $this->draw;
	$this->focus_to_object('buttons');
        $this->SUPER::focus;
	return 'LEAVE_CONTAINER';
}

sub get()
{
	my $this = shift;
	$this->getobj('buttons')->get;
}

1;
