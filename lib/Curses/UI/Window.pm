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
use Curses::UI::Common;

use vars qw($VERSION @ISA);
$VERSION = '1.00';
@ISA = qw(Curses::UI::Container);

sub new ()
{
	my $class = shift;

        my %userargs = @_;
        keys_to_lowercase(\%userargs);

	# Create the window.
	my $this = $class->SUPER::new( 
		-width => undef,
		-height => undef,
		-x => 0, -y => 0,
		-centered => 0,

		%userargs,

		-assubwin => 1,
	);

	return bless $this, $class;
}

sub layout ()
{
	my $this = shift;

	return $this if $Curses::UI::screen_too_small;

	# Compute the coordinates of the Window if
	# it has to be centered.
	if ($this->{-centered})
	{
		# The maximum available space on the screen.
		my $avail_width = $ENV{COLS};
		my $avail_height = $ENV{LINES};

		# Compute the coordinates for the widget.
		my $w = $this->{-width} || 1;
		my $h = $this->{-height} || 1;
		my $x = int(($avail_width - $w) / 2);
		my $y = int(($avail_height - $h) / 2);
		$x = 0 if $x < 0;
		$y = 0 if $y < 0;
		$this->{-x} = $x; 
		$this->{-y} = $y; 
	}

        $this->SUPER::layout;

	return $this;
}

sub raise() { shift()->ontop() }
sub ontop()
{
	my $this = shift;
	$this->root->ontop($this, 1);
}

sub is_ontop()
{
	my $this = shift;
	$this->root->window_is_ontop($this);
}

1;


=pod

=head1 NAME

Curses::UI::Window - Create and manipulate Window widgets


=head1 CLASS HIERARCHY

 Curses::UI::Widget
    |
    +----Curses::UI::Container   
            |
            +----Curses::UI::Window


=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add(
        'window_id', 'Window',
        %options,
    );


=head1 DESCRIPTION

Curses::UI::Window is a window widget. It can be added to
a Curses::UI instance. After that the window can be filled
with other widgets to create an application window. For
information on how to fill the window with widgets, see
L<Curses::UI::Container|Curses::UI::Container>.



=head1 STANDARD OPTIONS

B<-parent>, B<-x>, B<-y>, B<-width>, B<-height>, 
B<-pad>, B<-padleft>, B<-padright>, B<-padtop>, B<-padbottom>,
B<-ipad>, B<-ipadleft>, B<-ipadright>, B<-ipadtop>, B<-ipadbottom>,
B<-title>, B<-titlefullwidth>, B<-titlereverse>, B<-onfocus>,
B<-onblur>

For an explanation of these standard options, see 
L<Curses::UI::Widget|Curses::UI::Widget>.



=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item * B<-centered> < BOOLEAN >

A window can automatically be drawn in the center of the screen.
To enable this option use a true value and to disable it use a
false value. The default is not to center a window. Example:

    $cui->add('mywindow', 'Window', -centered => 1);
 

=back


=head1 METHODS

=over 4

=item * B<new> ( OPTIONS )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

=item * B<onFocus> ( CODEREF )

=item * B<onBlur> ( CODEREF )

=item * B<intellidraw> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget>
for an explanation of these.

=item * B<ontop> ( ) / B<raise> ( )

This method brings the window on top of the other 
windows.

=item * B<is_ontop> ( )

This method will return a true value if the window is
currently on top.

=back


=head1 SEE ALSO

L<Curses::UI|Curses::UI>,
L<Curses::UI::Container|Curses::UI::Container>,
L<Curses::UI::Widget|Curses::UI::Widget>



=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

