# ----------------------------------------------------------------------
# Curses::UI::TextEntry
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::TextEntry;

use strict;
use Curses;
use Curses::UI::TextEditor;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::TextEditor);
$VERSION = '1.0.0';
	
sub new ()
{
	my $class = shift;

	my %args = ( 
		-undolevels	 => 20,	# number of undolevels. 0 = infinite
		-homeonreturn    => 1,	# cursor to homepos on return?
		@_,
		-singleline	 => 1,	# single line mode or not?
		-showhardreturns => 0,	# show hard returns with diamond char?
	);

	# Create the entry.
	my $this = $class->SUPER::new( %args);

	# There is no reason to show overflow symbols if no
	# more characters than the available width can be
	# added (the screen would wrap and after that
	# typing would be impossible).
	if ($this->{-maxlength} and $this->screenwidth > $this->{-maxlength}) {
		$this->{-showoverflow} = 0;
	}

	# Setup bindings.
        $this->clear_binding('return');
        $this->set_binding('return', KEY_ENTER(), "\n", "\t" );

	return bless $this, $class;
}

1;

