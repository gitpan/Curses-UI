# ----------------------------------------------------------------------
# Curses::UI::Window
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Window;

use strict;
use Curses;
use Curses::UI::Container;

use vars qw($VERSION @ISA);
$VERSION = '1.00';
@ISA = qw(Curses::UI::Container);

sub new ()
{
	my $class = shift;
	my %args  = @_;

	# Create the window.
	my $this = $class->SUPER::new( 
		-width => undef,
		-height => undef,
		-x => 0, -y => 0,
		%args,
		-assubwin => 1,
	);

	return bless $this, $class;
}

1;

