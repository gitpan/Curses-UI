package Curses::UI::TextViewer;

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
		@_,
		-viewmode	 => 1,
	);
	return $class->SUPER::new( %args);
}

1;

