package Curses::UI::RadioButtonBox;

use strict;
use Curses;
use Curses::UI::ListBox;
use Curses::UI::Frame;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::ListBox);
$VERSION = '1.0.0';
	
sub new ()
{
	my $class = shift;

	my %args = ( 
		@_,
		-radio => 1,
	);

	# Compute the needed with if -width is undefined.
	# The extra 4 positions are for the radiobutton drawing. 
	$args{-width} = 4 + width_by_windowscrwidth(maxlabelwidth(%args), %args)
		unless defined $args{-width};

	# Compute the needed height if -height is undefined.
	$args{-height} = height_by_windowscrheight(@{$args{-values}}, %args)
		unless defined $args{-height};

	# Create the entry.
	my $this = $class->SUPER::new( %args);

	return bless $this, $class;
}

1;

