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


=pod

=head1 NAME

Curses::UI::Dialog::Status - Create and manipulate status dialogs 

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    # The hard way.
    # -------------
    my $dialog = $win->add(
        'mydialog', 'Dialog::Status',
	-message   => 'Hello, world!',
    );

    $dialog->draw();

    $win->delete('mydialog');
    
    # The easy way (see Curses::UI documentation).
    # --------------------------------------------
    $cui->status( -message => 'Some message' );

    # or even:
    $cui->status( 'Some message' );

    $cui->nostatus;
    



=head1 DESCRIPTION

Curses::UI::Dialog::Status is not really a dialog, since
the user has no way of interacting with it. It is merely
a way of presenting status information to the user of 
your program.


See exampes/demo-Curses::UI::Dialog::Status in the 
distribution for a short demo.



=head1 OPTIONS

=over 4

=item * B<-title> < TEXT >

Set the title of the dialog window to TEXT.

=item * B<-message> < TEXT >

This option sets the initial message to show to TEXT.
This message is displayed using a L<Curses::UI::Label|Curses::UI::Label>,
so it can not contain any newline (\n) characters.

=back




=head1 METHODS

=over 4

=item * B<new> ( OPTIONS )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

These are standard methods. See L<Curses::UI::Container|Curses::UI::Container> 
for an explanation of these.

=item * B<message> ( TEXT )

This method will update the message of the status dialog 
to TEXT. For this update to show, you will have to call the
B<draw> method of the progress dialog.

=back




=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::Container|Curses::UI::Container>, 




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

