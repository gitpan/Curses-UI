# ----------------------------------------------------------------------
# Curses::UI::TextViewer
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::TextViewer;

use strict;
use Curses;
use Curses::UI::TextEditor;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::TextEditor);
$VERSION = '1.01';
	
sub new ()
{
	my $class = shift;

	my %args = ( 
		@_,
		-viewmode	 => 1,
	);
	return $class->SUPER::new( %args);
}

1;

