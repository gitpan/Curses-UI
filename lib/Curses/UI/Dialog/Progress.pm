# ----------------------------------------------------------------------
# Curses::UI::Dialog::Progress
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Dialog::Progress;

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
		-nomessage 	 => 0,
		-message 	 => '',   # The message to show
		-ipad            => 1,
		-border 	 => 1,
		-width           => 60,
		-height          => undef,
		@_,
		-centered        => 1,
	);

	my $this = $class->SUPER::new(%args);

	unless ($args{-nomessage})
	{
		$this->add(
			'label', 'Label',
			-width => -1,
			-text  => $this->{-message},
		);
	}

	# Create the progress bar arguments.
	my %pb_args = ();
	foreach my $var (qw(-min -max -pos -showpercentage -showcenterline))
	{
		if (defined $this->{$var}) {
			$pb_args{$var} = $this->{$var};
		}
	}

	$this->add(
		'progress', 'ProgressBar',
		-y => 2 - ($this->{-nomessage} ? 2 : 0),
		-width => -1,
		%pb_args,
	);

	$this->layout();

	bless $this, $class;
}

sub layout()
{
	my $this = shift;

	# Compute the height the dialog needs.
	my $need = ($this->{-nomessage} ? 0 : 2) + # label
		   3;                              # progress bar
	my $height = $this->height_by_windowscrheight($need, %$this);
	$this->{-height} = $height;

	$this->SUPER::layout;

	return $this;
}

sub pos($;)
{
	my $this = shift;
	my $pos = shift;
	$this->getobj('progress')->pos($pos);
	return $this;
}

sub message()
{
	my $this = shift;
	return $this if $this->{-nomessage};
	my $msg = shift;
	$this->getobj('label')->text($msg);
	return $this;
}

sub focus()
{
        my $this = shift;
        return $this;
}

1;
