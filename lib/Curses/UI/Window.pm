package Curses::UI::Window;

use strict;
use Curses;
use Curses::UI::Container;

use vars qw($VERSION @ISA);
$VERSION = '1.0.0';
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

