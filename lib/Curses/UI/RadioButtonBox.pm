# ----------------------------------------------------------------------
# Curses::UI::RadioButtonBox
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::RadioButtonBox;

use strict;
use Curses;
use Curses::UI::ListBox;
use Curses::UI::Widget;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::ListBox);
$VERSION = '1.00';
	
sub new ()
{
	my $class = shift;

	my %args = ( 
		@_,
		-radio => 1,
		-multi => 0,
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


=pod

=head1 NAME

Curses::UI::RadioButtonBox - Create and manipulate radiobuttonbox widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $radiobuttonbox = $win->add(
        'myradiobuttonbox', 'RadioButtonBox',
        -values    => [1, 2, 3],
        -labels    => { 1 => 'One', 
                        2 => 'Two', 
                        3 => 'Three' },
    );

    $radiobuttonbox->focus();
    my $selected = $radiobuttonbox->get();


=head1 DESCRIPTION

Curses::UI::RadioButtonBox is a widget that can be used 
to create a radiobutton listbox. Only one value can be
selected at a time. This kind of listbox looks somewhat 
like this:

 +----------+
 |< > One   |
 |<o> Two   |
 |< > Three |
 +----------+

A RadioButtonBox is derived from Curses::UI::ListBox. The
only special thing about this class is that the 
B<-radio> option is forced to a true value. So for the
usage of Curses::UI::RadioButtonBox see
L<Curses::UI::ListBox|Curses::UI::ListBox>).




=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::ListBox|Curses::UI::ListBox>, 




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

