# ----------------------------------------------------------------------
# Curses::UI::Container
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Container;

use Curses;
use Carp qw(confess);
use Curses::UI::Widget;
use Curses::UI::Common;

use vars qw(@ISA $VERSION);
@ISA = qw(Curses::UI::Widget Curses::UI::Common);
$VERSION = "1.01";

# ----------------------------------------------------------------------
# Public interface
# ----------------------------------------------------------------------

# Create a new Container object.
sub new()
{
	my $class = shift;

	my $this = $class->SUPER::new(@_);

	# Setup internal data storage.
	$this->{-use}         	= {};	   # which modules are "use"d
	$this->{-container}	= undef;   # container of objects
	$this->{-focusorder} 	= [];  	   # focus order
	$this->{-focusidx} 	= 0;   	   # focus index
	$this->{-windoworder} 	= [];	   # window stacking order
	$this->{-draworder} 	= [];  	   # draw order

	return $this;
}

sub usemodule($;)
{
	my $this = shift;
	my $class = shift;
	
	# Automatically load the required class.
	if (not defined $this->{-use}->{$class})
	{
		my $cmd = "use $class";
		eval $cmd;
		confess "Error in loading $class module: $@" if $@;
		$this->{-use}->{$class} = 1;
	}

	return $this;
}

# Add an object to the container.
sub add($@;)
{
	my $this = shift;
	my $id = shift;
	my $class = shift;
	my %args = @_;

	confess "The object id \"$id\" is already in use!"
		if (defined $this->{-container}->{$id});

	# Make it possible to specify WidgetType instead of
	# Curses::UI::WidgetType.
        $class = "Curses::UI::$class" 
                if $class !~ /\:\:/ 
                or $class =~ /^Dialog\:\:[^\:]+$/;

	# Create a new object of the wanted class.
	$this->usemodule($class);
	my $object = $class->new(
		%args,
		-parent => $this
	);

	# Store the object in this object.
	$this->{-container}->{$id} = $object;

	# Automatically create a focus- and draworder (last added = 
	# last focus/draw). This can be overriden by the 
	# set_focusorder() and set_draworder() functions.
	push @{$this->{-focusorder}}, $id;
	push @{$this->{-draworder}}, $id;

	# If the added object is a (derived) Curses::UI::Window, 
	# then remember it's order in the windoworder stack.
	push @{$this->{-windoworder}}, $id 
		if $object->isa('Curses::UI::Window'); 

	# Return the created object.
	return $object;
}

# Delete the contained object with id=$id 
# from the Container.
sub delete(;$)
{
	my $this = shift;
	my $id = shift;
	
	# Destroy object.
	undef $this->{-container}->{$id};
	delete $this->{-container}->{$id};

	foreach my $param (qw(-focusorder -draworder -windoworder))
	{
		my $idx = $this->base_id2idx($param, $id);
		splice(@{$this->{$param}}, $idx, 1)
			if defined $idx;
	}

	return $this;
}

# Draw the container and it's contained objects.
sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

        # Return immediately if this object is hidden.
        return $this if $this->hidden;
	
	$this->root->check_for_too_small_screen();
	
	# Draw the Widget.
	$this->SUPER::draw(1);

	# Draw all contained object.
	foreach my $id (@{$this->{-draworder}})
	{
		my $obj = $this->{-container}->{$id};
		$obj->draw(1);
	}

	# Update the screen unless suppressed.
	doupdate() unless $no_doupdate;

	return $this;
}

# Create leave-container bindings for all contained objects, so we
# have an easy way of creating global keys for leaving the
# container.
sub returnkeys(@;)
{
	my $this = shift;

	# Get list of keys on which to return.
	my @keys = @_; 

	# Return immediately if this Container has no contained objects.
	return $this unless defined $this->{-container};

	foreach my $key (@keys) {
		while (my ($id, $obj) = each %{$this->{-container}}) {
			$obj->{-routines}->{'leave-container'} = 'LEAVE_CONTAINER';
			$obj->set_binding('leave-container', @keys);
		}
	}

	return $this;
}

sub layout_from_scratch()
{
	my $this = shift;
	$this->root->layout;
}

sub layout()
{
	my $this = shift;
	$this->SUPER::layout();
	return $this if $Curses::UI::screen_too_small;
	$this->layout_contained_objects();
	return $this;	
}

sub layout_contained_objects()
{
	my $this = shift;

	# Layout all contained objects.
	foreach my $id (@{$this->{-draworder}})
	{
		last if $Curses::screen_too_small;
		my $obj = $this->{-container}->{$id};
		$obj->{-parent} = $this;
		$obj->layout();
	}

	return $this;
}

# Look if there are objects of a certain kind in the container.
sub hasa($;)
{
	my $this = shift;
	my $class = shift;

	my $count = 0;
	while (my ($id,$obj) = each %{$this->{-container}}) {
		$count++ if ref $obj eq $class;
	}
	return $count;
}

# Recursive rebuild from the root up.
sub rebuild_from_scratch()
{
	my $this = shift;
	$this->rootscr->clear;
	$this->rootscr->noutrefresh;
	$this->root->rebuild;
}

# Recursive rebuild of the Container.
sub rebuild()
{
	my $this = shift;
	$this->ontop(undef, 1);
}

# Move a Window on top in the Container. Arguments:
# - id    => the id of the window. To identify the current
#            top Window an undefined value may be given
# - force => force refreshing of the screen, even if there
#            was no change in the window order.
#
# So: 
# ontop(undef,1)
#   basically a screen refresh command.
# ontop('screen1')
#   brings screen1 on top and doesn't do
#   a redraw if screen1 is already on top. 
#
sub ontop($;$)
{
	my $this = shift;
	my $id = shift;
	my $force = shift || 0;
	
	# If we have a stack of no windows, return immediately.
	return $this if @{$this->{-windoworder}} == 0;

	# If we have a stack of only 1 window, the -windoworder
	# will therefor never change. We'll make sure here that
	# the window is drawn.
	$force = 1 if @{$this->{-windoworder}} == 1;

	# No id given? Then take the current frontwindow.
	$id = $this->{-windoworder}->[-1]
		unless defined $id;

	# Find the object to move up front.
	my $win = $this->getobj($id) or return;

	# Window already up front or not?
	my $has_moved = 0;
	unless ($this->{-windoworder}->[-1] eq $id)
	{
		# No? Then first find the current index of 
		# the window that has to be up front.
		my $idx = $this->windoworder_id2idx($id);
		confess "ontop(): $id: no such window" 
			unless defined $idx;
	
		# Now re-arrange the windoworder.
		splice(@{$this->{-windoworder}}, $idx, 1);
		push @{$this->{-windoworder}}, $id;
	
		$has_moved = 1;
	}

	if ($force or $has_moved) {
		$this->rootscr->erase;
		$this->rootscr->noutrefresh;
		foreach my $id (@{$this->{-windoworder}}) {
			$this->getobj($id)->draw(1);
		}
		doupdate();
	}

	return $this;	
}

sub focus()
{
	my $this = shift;
	$this->show;
	$this->draw;
	
	# If the container contains no objects, then return
	# without focusing.
	return ('LEAVE_CONTAINER', undef) unless $this->{-container};
	
	for (;;)
	{
		# Set the focus to the current focused 
		# subobject of the container.
		my ($ret, $key) = $this->focus_object;

		# Leave focus for the container in place if 
		# the subobject returned 'LEAVE_CONTAINER'. Also return 
		# the last key that was pressed.
		return ($ret,$key) if $ret eq 'LEAVE_CONTAINER';

		# Set the focus to the next subobject of the container,
		# unless the subobject told the container not to do so.
		$this->focus_to_next unless $ret eq 'STAY_AT_FOCUSPOSITION';
	}
}

sub set_focusorder(@;)
{
	my $this = shift;
	my @order = @_;
	$this->{-focusorder} = \@order;
	return $this;
}

sub set_draworder(@;)
{
	my $this = shift;
	my @order = @_;
	$this->{-draworder} = \@order;
	return $this;
}

sub getobj($;)
{
	my $this = shift;
	my $id = shift;
	return $this->{-container}->{$id};
}

sub getfocusobj()
{
	my $this = shift;
	$this->{-focusidx} = 0 unless defined $this->{-focusidx};
	my $id = $this->{-focusorder}->[$this->{-focusidx}];
	return (defined $id ? $this->getobj($id) : undef); 
}

sub focus_to_object(;$)
{
	my $this = shift;
	my $id = shift;
	
	if (defined $id)
	{
		my $idx = $this->focusorder_id2idx($id);
		$this->{-focusidx} = $idx;
	}

	$this->{-focusidx} = 0 
		unless defined $this->{-focusidx};

	return $this;
}

sub focus_object()
{
	my $this = shift;
	$this->getfocusobj->focus;
}

# ----------------------------------------------------------------------
# Private functions
# ----------------------------------------------------------------------

sub draworder_id2idx($;)   {shift()->base_id2idx('-draworder' , shift())}
sub windoworder_id2idx($;) {shift()->base_id2idx('-windoworder', shift())}
sub focusorder_id2idx($;)  {shift()->base_id2idx('-focusorder', shift())}

sub base_id2idx($;)
{
	my $this = shift;
	my $param = shift;
	my $id = shift;
	
	my $idx;
	my $i = 0;
	foreach my $win_id (@{$this->{$param}}) 
	{
		if ($win_id eq $id) { 
			$idx = $i; 
			last;
		}
		$i++;
	}
	return $idx;
}

sub focus_shift($;)
{
	my $this = shift;
	my $direction = shift; 

	$direction = ($direction > 0 ? +1 : -1);

	# Save to prevent looping.
	my $start_idx = $this->{-focusidx};

	my $idx = $this->{-focusidx};
	do {
		$idx += $direction;
		if ($idx > (@{$this->{-focusorder}}-1)) {
			$idx = 0;
		} elsif ($idx < 0) {
			$idx = @{$this->{-focusorder}}-1;
		}
	} while(
		$this->getobj($this->{-focusorder}->[$idx])->hidden
		and not
		$start_idx == $idx		
	);

	$this->{-focusidx} = $idx;
	return $this;		
}

sub focus_to_next() { shift()->focus_shift(+1) }
sub focus_to_prev() { shift()->focus_shift(-1) }


=pod

=head1 NAME

Curses::UI::Container - Create and manipulate container widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $container = $win->add(
        'mycontainer', 'Container'
    );

    $container->add(
        'contained', 'SomeWidget',
        .....
    );

    $container->focus();


=head1 DESCRIPTION

A container provides an easy way of managing multiple widgets
in a single "form". A lot of Curses::UI functionality is
built around containers. The main class L<Curses::UI|Curses::UI> 
itself is a container. A L<Curses::UI::Window|Curses::UI::Window>
is a container. Some of the widgets are implemented as 
containers.



=head1 STANDARD OPTIONS

B<-parent>, B<-x>, B<-y>, B<-width>, B<-height>, 
B<-pad>, B<-padleft>, B<-padright>, B<-padtop>, B<-padbottom>,
B<-ipad>, B<-ipadleft>, B<-ipadright>, B<-ipadtop>, B<-ipadbottom>,
B<-title>, B<-titlefullwidth>, B<-titlereverse>

For an explanation of these standard options, see 
L<Curses::UI::Widget|Curses::UI::Widget>.




=head1 WIDGET-SPECIFIC OPTIONS

Currently this class does not have any specific options.





=head1 METHODS

=over 4

=item * B<new> ( )

Create a new instance of the Curses::UI::Container class.

=item * B<add> ( ID, CLASS, OPTIONS )

This is the main method for this class. Using this method
it is easy to add widgets to the container. 

The ID is an identifier that you want to use for the
added widget. This may be any string you want.

The CLASS is the class which you want to add to the
container. If CLASS does not contain '::' or CLASS
matches 'Dialog::...' then 'Curses::UI' will be prepended
to it. This way you do not have to specifiy the full
class name for widgets that are in the Curses::UI 
hierarchy. It is not neccessary to call "use CLASS" 
yourself. The B<add> method will call the B<usemodule>
method (see below) to automatically load the module.

The hash OPTIONS contains the options that you want to pass
on to the new instance of CLASS.

Example:
  
    $container->add(
        'myid',                   # ID 
        'Label',                  # CLASS
        -text => 'Hello, world!', # OPTIONS
        -x    => 10,
        -y    => 5,
    );

=item * B<delete> ( ID )

This method deletes the contained widget with the given ID
from the container.

=item * B<hasa> ( CLASS )

This method returns true if the container contains one or
more widgets of the class CLASS.

=item * B<layout> ( )

Layout the Container and all its contained widgets.

=item * B<layout_from_scratch> ( )

This will find the topmost container and call its 
B<layout> method. This will recursively layout all
nested containers.

=item * B<draw> ( BOOLEAN )

Draw the Container and all its contained widgets.
 If BOOLEAN is true, the screen will not update after 
drawing. By default this argument is false, so the 
screen will update after drawing the container.

=item * B<focus> ( )

If the container contains no widgets, this routine will
return immediately. Else the container will get focus.

If the container gets focus, on of the contained widgets
will get the focus. The returnvalue of this widget determines
what has to be done next. Here are the possible cases:

* The returnvalue is B<LEAVE_CONTAINER>

  As soon as a widget returns this value, the container
  will loose its focus and return the returnvalue and the
  last pressed key to the caller. 

* The returnvalue is B<STAY_AT_FOCUSPOSITION>

  The container will not loose focus and the focus will stay
  at the same widget of the container.

* Any other returnvalue

  The focus will go to the next widget in the container.

=item * B<getobj> ( ID )

This method returns the object reference of the contained
widget with the given ID.

=item * B<getfocusobj> ( )

This method returns the object reference of the contained
widget which currently has the focus.

=item * B<focus_to_object> ( ID )

This method sets the focuspointer to the object with the
given ID.

=item * B<set_focusorder> ( IDLIST )

Normally the order in which widgets get focused in a 
container is determined by the order in which they
are added to the container. Use B<set_focusorder> if you
want a different focus order. IDLIST contains a list
of id's.

=item * B<set_draworder> ( IDLIST )

Normally the order in which widgets are drawn in a 
container is determined by the order in which they
are added to the container. Use B<set_draworder> if you
want a different draw order. IDLIST contains a list
of id's.

=item * B<rebuild> ( )

This will redraw the Curses::UI::Window widgets
(and descendants) that are in the container (internally
this method calls B<ontop> (undef, 1)).

=item * B<rebuild_from_scratch> ( )

This will find the topmost container and call its 
B<rebuild> method. This will recursively rebuild all
nested containers.

=item * B<ontop> ( ID, BOOLEAN )

If a container contains a number of Curses::UI::Window
widgets (or descendants), the window stack order is 
remembered. Using the B<ontop> method, the window with 
the given ID can be brought on top of the stack. If
ID is undefined, the id of the window that is currently
on top will be used.

If BOOLEAN is true the screen will always be redrawn.
If BOOLEAN is false, the screen will only be redrawn if
the ID differs from the id of the window that is currently
on top.

=item * B<returnkeys> ( KEYLIST )

After you have added all the wanted widgets to the 
container, you can add keybindings to each widget
to have the container loose its focus. This is done
by the B<returnkeys> method. KEYLIST is a list of
keys on which the container must loose focus (see 
also L<Curses::UI|Curses::UI>). 

=item * B<loadmodule> ( CLASS )

This will load the module for the CLASS. If loading
fails, the program will die. 

=back




=head1 DEFAULT BINDINGS

Since interacting is not handled by the container itself, but 
by the contained widgets, this class does not have any key
bindings.




=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 



=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

