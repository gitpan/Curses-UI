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
$VERSION = "1.00";

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
	$this->layout_contained_objects();
	return $this;	
}

sub layout_contained_objects()
{
	my $this = shift;

	# Layout all contained objects.
	foreach my $id (@{$this->{-draworder}})
	{
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

