# ----------------------------------------------------------------------
# Curses::UI::Dialog::Status
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Dialog::Status;

use strict;
use Carp qw(confess);
use Curses;
use Curses::UI::Common;
use Curses::UI::Window;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::Window Curses::UI::Common);
$VERSION = '1.01';

sub new ()
{
	my $class = shift;
	my %args = ( 
		-message 	 => undef,   # The message to show
		-ipad            => 1,
		-border 	 => 1,
		-width           => undef,
		-height          => undef,
		@_,
		-centered        => 1,
	);

	my $this = $class->SUPER::new(%args);
	$args{-message} = 'no message' unless defined $args{-message};

	$this->add(
		'label', 'Label',
		-width => -1,
		-text  => $this->{-message},
	);

	$this->layout();

	bless $this, $class;
}

sub layout()
{
	my $this = shift;

	# Compute the width the dialog needs.
	if (not defined $this->{-width})
	{
		my $msg = $this->{-message};
		my $needwidth = length($msg);
		my $width = $this->width_by_windowscrwidth($needwidth, %$this);
		$this->{-width}  = $width;
	}

	# Compute the height the dialog needs.
	if (not defined $this->{-height})
	{
		my $height = $this->height_by_windowscrheight(1, %$this);
		$this->{-height} = $height;
	}

	$this->SUPER::layout;

	return $this;
}
	
sub message($;)
{
	my $this = shift;
	my $message = shift;
	$message = 'no message' unless defined $message;
	$this->getobj('label')->text($message);
	return $this;
}

sub focus()
{
	my $this = shift;
	return $this;
}

1;
