# ----------------------------------------------------------------------
# Curses::UI::ListBox
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::ListBox;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Widget;
use Curses::UI::TextEntry;
use Curses::UI::TextViewer;
use Curses::UI::Searchable;

use vars qw($VERSION @ISA @EXPORT);
require Exporter;
@ISA = qw(
	Curses::UI::Widget Curses::UI::Common 
	Curses::UI::Searchable Exporter
);
$VERSION = '1.00';
@EXPORT = qw(
	maxlabelwidth
);

my %routines = (
	'return'		=> 'RETURN',
	'option-select'		=> \&option_select,
	'option-check'		=> \&option_check,
	'option-uncheck'	=> \&option_uncheck,
	'option-next'		=> \&option_next,
	'option-prev'		=> \&option_prev,
	'option-nextpage'	=> \&option_nextpage,
	'option-prevpage'	=> \&option_prevpage,
	'option-first'		=> \&option_first,
	'option-last'		=> \&option_last,
	'search-forward'	=> \&search_forward,
	'search-backward'	=> \&search_backward,
);

my %bindings = (
        KEY_LEFT()      	=> 'return',
        "h"             	=> 'return',
        KEY_TAB()            	=> 'return',
	KEY_ENTER()		=> 'option-select',
        KEY_RIGHT()     	=> 'option-select',
        "l"             	=> 'option-select',
        KEY_SPACE()            	=> 'option-select',
        "1"             	=> 'option-check',
        "y"             	=> 'option-check',
        "0"             	=> 'option-uncheck',
        "n"             	=> 'option-uncheck',
        KEY_DOWN()      	=> 'option-next',
	"j"			=> 'option-next',
        KEY_NPAGE()     	=> 'option-nextpage',
        KEY_UP()        	=> 'option-prev',
        "k"             	=> 'option-prev',
        KEY_PPAGE()     	=> 'option-prevpage',
        KEY_HOME()      	=> 'option-first',
        "\cA"           	=> 'option-first',
        KEY_END()       	=> 'option-last',
        "\cE"           	=> 'option-last',
	"/"			=> 'search-forward',
	"?"			=> 'search-backward',
);

sub new ()
{
	my $class = shift;

	my %args = ( 
		-values     => [],	# values to show
		-labels     => {},	# optional labels for the values 
		-active     => 0,	# the activated value
		-width      => undef,	# the width of the listbox
		-height     => undef,	# the height of the listbox
		-x          => 0,	# the hor. pos. rel. to parent
		-y          => 0,	# the vert. pos. rel. to parent
		-multi	    => 0,	# multiselection possible?
		-radio      => 0,	# show radio buttons? Only for ! -multi
		-selected   => undef,	# the selected item
		-wraparound => 0,	# wraparound on first/last item
		@_,
		-yscrpos    => 0,
		-routines   => {%routines},
		-bindings   => {%bindings},
	);

	if ($args{-multi})
	{
		$args{-radio} = 0;
		$args{-selected} = {} 
			unless ref $args{-selected} eq 'HASH';
		$args{-ypos} = 0;
	} else {
		$args{-ypos} = defined $args{-selected} 
			     ? $args{-selected}
			     : 0;
	}

	my $this = $class->SUPER::new( %args );	
	$this->layout_content();
	bless $this, $class;
}

sub maxlabelwidth(@;)
{
	my %args = @_;
	
	my $maxwidth = 0;
	foreach	my $value (@{$args{-values}})
	{
		my $label = $value;
		$label = $args{-labels}->{$value}
			if defined $args{-labels}->{$value};
		$maxwidth = length($label) 
			if length($label) > $maxwidth;
	}
	return $maxwidth;
}

sub layout()
{
	my $this = shift;
	$this->SUPER::layout();	
	return $this if $Curses::UI::screen_too_small;

        # Scroll up if we can and the number of visible lines
        # is smaller than the number of available lines in the screen.
        my $inscreen = ($this->screenheight
                     - ($this->number_of_lines - $this->{-yscrpos}));
        while ($this->{-yscrpos} > 0 and $inscreen < $this->screenheight)
        {
                $this->{-yscrpos}--;
                $inscreen = ($this->screenheight
                          - ($this->number_of_lines - $this->{-yscrpos}));
        }

	$this->layout_content;

	return $this;
}

sub layout_content()
{
	my $this = shift;
	
	# Check bounds for -ypos index.
	$this->{-max_selected} = @{$this->{-values}} - 1;
	$this->{-ypos} = $this->{-max_selected}
		if $this->{-ypos} > $this->{-max_selected};
	$this->{-ypos} = 0 if $this->{-ypos} < 0;

	# Scroll down if needed.
	my $ycur = $this->{-ypos} - $this->{-yscrpos};
	if ( $ycur > ($this->screenheight-1)) {
		$this->{-yscrpos} = $this->{-ypos} - $this->screenheight + 1;
	}
	# Scroll up if needed.
	elsif ( $ycur < 0 ) {
		$this->{-yscrpos} = $this->{-ypos};
	}


	$this->{-vscrolllen} = @{$this->{-values}};
	$this->{-vscrollpos} = $this->{-yscrpos};
	if ( @{$this->{-values}} <= $this->screenheight) {
		undef $this->{-vscrolllen};
	}

	return $this;
}

sub getlabel($;)
{
	my $this = shift;
	my $idx = shift || 0;

	my $value = $this->{-values}->[$idx];
	my $label = $value;
	$label = $this->{-labels}->{$label} 
		if defined $this->{-labels}->{$label};
	$label =~ s/\t/ /g; # do not show TABs

	return $label;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

        # Return immediately if this object is hidden.
        return $this if $this->hidden;
	
	# Draw the widget
	$this->SUPER::draw(1);

	# No values? 
	if (not @{$this->{-values}})
	{
		$this->{-windowscr}->attron(A_DIM);	
		$this->{-windowscr}->addstr(0,0,'- no values -');
		$this->{-windowscr}->attroff(A_DIM);	

	# There are values. Show them!
	} else {
		my $start_idx = $this->{-yscrpos};
		my $end_idx = $this->{-yscrpos} + $this->screenheight - 1;
		$end_idx = $this->{-max_selected} 
			if $end_idx > $this->{-max_selected};

		my $y = 0;
		my $cursor_y = 0;
		my $cursor_x = 0;
		for my $i ($start_idx .. $end_idx)
		{
			# The label to print.
			my $label = $this->getlabel($i);

			# Clear up label.
			$label =~ s/\n|\r//g;

			# Needed space for prefix.
			my $prefix_len = 
				(($this->{-multi} or $this->{-radio}) ? 4 : 0);

			# Chop length if needed.
			if (($prefix_len + length($label)) > $this->screenwidth) {	
				$label = substr($label, 0, ($this->screenwidth-$prefix_len));
				$label =~ s/.$/\$/;
			}

			# Show current entry in reverse mode and 
			# save cursor position.
			if ($this->{-ypos} == $i and $this->{-focus})
			{
				$this->{-windowscr}->attron(A_REVERSE);
				$cursor_y = $y;	
				$cursor_x = $this->screenwidth-1;
			}

			# Show selected element bold. 
			if (not $this->{-multi}
			    and not $this->{-radio}
			    and defined $this->{-selected}
                            and $this->{-selected} == $i) {
				$this->{-windowscr}->attron(A_BOLD);
			}
			
			# Make full line reverse or blank
			$this->{-windowscr}->addstr(
				$y, 
				$prefix_len, 
				" "x($this->screenwidth-$prefix_len)
			);
			# Show label
			$this->{-windowscr}->addstr(
				$y,
				$prefix_len,
				$label
			);

			$this->{-windowscr}->attroff(A_REVERSE);
			$this->{-windowscr}->attroff(A_BOLD);

			# Place a [X] for selected value in multi mode.
			$this->{-windowscr}->attron(A_BOLD) if $this->{-focus};
			if ($this->{-multi}) {
				if (defined $this->{-selected} and    
				    $this->{-selected}->{$i}) {
					$this->{-windowscr}->addstr($y, 0, '[X]');
				} else {
					$this->{-windowscr}->addstr($y, 0, '[ ]');
				}
			}

			# Place a <o> for selected value in radio mode.
			elsif ($this->{-radio}) {
				if (defined $this->{-selected} 
				    and $i == $this->{-selected}) {
					$this->{-windowscr}->addstr($y, 0, '<o>');
				} else {
					$this->{-windowscr}->addstr($y, 0, '< >');
				}
			}
			$this->{-windowscr}->attroff(A_BOLD) if $this->{-focus};

			$y++;
		}

		$cursor_x = 1 if $this->{-multi} or $this->{-radio};
		$this->{-windowscr}->move($cursor_y, $cursor_x);
	}

	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;

	return $this;
}

sub focus()
{
	my $this = shift;

	$this->show;
	
	# No values? Then do not focus.
	return 'RETURN' unless @{$this->{-values}};

	return $this->generic_focus(
		undef,
		NO_CONTROLKEYS,
		CURSOR_INVISIBLE,
		\&layout_content,
	);
}

sub option_last()
{
	my $this = shift;
	$this->{-ypos} = @{$this->{-values}} - 1;
	return $this;
}

sub option_nextpage()
{
	my $this = shift;
	if ($this->{-ypos} >= $this->{-max_selected}) { 
		$this->dobeep;
		return $this;
	}
	$this->{-ypos} += $this->screenheight - 1;
	return $this;
}

sub option_prevpage()
{
	my $this = shift;
	if ($this->{-ypos} <= 0) {
		$this->dobeep;
		return $this;
	}
	$this->{-ypos} -= $this->screenheight - 1;
	return $this;
}

sub option_next()
{
	my $this = shift;
	if ($this->{-ypos} >= $this->{-max_selected}) { 
		if ($this->{-wraparound}) {
			$this->{-ypos} = 0;
		} else {
			$this->dobeep;
		}
	} else {
		$this->{-ypos}++;
	}
	return $this;
}

sub option_prev()
{
	my $this = shift;
	if ($this->{-ypos} <= 0) {
		if ($this->{-wraparound}) {
			$this->{-ypos} = $this->{-max_selected};
		} else {
			$this->dobeep;
		}
	} else {
		$this->{-ypos}--;
	}
	return $this;
}

sub option_select()
{
	my $this = shift;

	if ($this->{-multi})
	{
		$this->{-selected}->{$this->{-ypos}} = 
		   !$this->{-selected}->{$this->{-ypos}};
		return $this;
	} else {
		$this->{-selected} = $this->{-ypos};
		return ($this->{-radio} ? $this : 'RETURN');
	}
}

sub option_first()
{
	my $this = shift;
	$this->{-ypos} = 0;
	return $this;
}

sub option_check()
{
	my $this = shift;
	if ($this->{-multi})
	{
		$this->{-selected}->{$this->{-ypos}} = 1;
		$this->{-ypos}++;
		return $this;
	} else {
		$this->{-selected} = $this->{-ypos};
		return ($this->{-radio} ? $this : undef);
	}
}

sub option_uncheck()
{
	my $this = shift;
	if ($this->{-multi})
	{
		$this->{-selected}->{$this->{-ypos}} = 0;
		$this->{-ypos}++;
	} else {
		$this->dobeep;
	}
	return $this;
}

sub get()
{
	my $this = shift;
	return unless defined $this->{-selected};
	if ($this->{-multi}) {
		my @values = ();
		while (my ($id, $val) = each %{$this->{-selected}}) {
			next unless $val;
			push @values, $this->{-values}->[$id];
		}
		return @values;
	} else {
		return $this->{-values}->[$this->{-selected}];
	}
}

sub get_selectedlabel()
{
	my $this = shift;
	my $value = $this->get;
	return unless defined $value;
	my $label = $this->{-labels}->{$value};
	return (defined $label ? $label : $value); 
}

# ----------------------------------------------------------------------
# Routines for search support
# ----------------------------------------------------------------------

sub number_of_lines()   { @{shift()->{-values}} }
sub getline_at_ypos($;) { shift()->getlabel(shift()) }

1;


=pod

=head1 NAME

Curses::UI::ListBox - Create and manipulate listbox widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $listbox = $win->add(
        'mylistbox', 'Listbox',
        -values    => [1, 2, 3],
        -labels    => { 1 => 'One', 
                        2 => 'Two', 
                        3 => 'Three' },
        -radio     => 1,
    );

    $listbox->focus();
    my $selected = $listbox->get();


=head1 DESCRIPTION

Curses::UI::Listbox is a widget that can be used to create 
a couple of different kinds of listboxes. These are:

=over 4

=item * B<default listbox>

A list of values through which can be browsed. One of these
values can be selected. The selected value will be 
highlighted. This kind of listbox looks somewhat like this:

 +------+
 |One   |
 |Two   |
 |Three |
 +------+

=item * B<multi-select listbox>

This is also a list of values, but now more than one 
value can be selected at once. This kind of listbox 
looks somewhat like this:
  
 +----------+
 |[X] One   |
 |[ ] Two   |
 |[X] Three |
 +----------+

=item * B<radiobutton listbox>

This looks a lot like the default listbox (only one
value can be selected), but now there is clear 
visual feedback on which value is selected. Before
each value "< >" is printed. If a value is selected,
"<o>" is printed instead. This kind of listbox 
looks somewhat like this:

 +----------+
 |< > One   |
 |<o> Two   |
 |< > Three |
 +----------+

=back

See exampes/demo-Curses::UI::Listbox in the distribution
for a short demo.



=head1 STANDARD OPTIONS

B<-parent>, B<-x>, B<-y>, B<-width>, B<-height>, 
B<-pad>, B<-padleft>, B<-padright>, B<-padtop>, B<-padbottom>,
B<-ipad>, B<-ipadleft>, B<-ipadright>, B<-ipadtop>, B<-ipadbottom>,
B<-title>, B<-titlefullwidth>, B<-titlereverse>

For an explanation of these standard options, see 
L<Curses::UI::Widget|Curses::UI::Widget>.




=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item * B<-values> < LIST >

This option sets the values to use. 
Unless a label is set for the value (see B<-labels>), 
this value will be shown in the list.

=item * B<-labels> < HASHREF >

The keys of this hash reference correspond to the values of 
the listbox (see B<-values>). The values of the hash are the 
labels to show in the listbox. It's not obligatory to have 
a label defined for each value. You may even omit -labels 
completely.

=item * B<-selected> < INDEX >

In case the B<-multi> option is not set, INDEX is the index
of the value that should be selected.

In case the B<-multi> option is set, INDEX is a hash reference
in which the keys are the indices of the B<-values> which are 
selected and the values are any true value.

=item * B<-multi> < BOOLEAN >

If BOOLEAN has a true value, the listbox will be a multi-select
listbox (see DESCRIPTION).

=item * B<-radio> < BOOLEAN >

If BOOLEAN has a true value, the listbox will be a radiobutton
listbox (see DESCRIPTION).

=item * B<-wraparound> < BOOLEAN >

If BOOLEAN has a true value, wraparound is enabled. This means
that if the listbox is on its last value and a key is pressed
to go to the next value, the first value will be selected.
Also the last value will be selected if this first value is
selected and "goto previous value" is pressed.



=back




=head1 METHODS

=over 4

=item * B<new> ( OPTIONS )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget> 
for an explanation of these.

=item * B<get> ( )

This method will return the values of the currently selected items 
in the list. If the listbox is not a multi-select listbox only one
value will be returned of course.


=back




=head1 DEFAULT BINDINGS

=over 4

=item * <B<cursor-left>>, <B<h>>, <B<tab>>

Call the 'return' routine. This will have the widget 
loose its focus.

=item * <B<cursor-right>, <B<l>>, <B<enter>>, <B<space>>

Call the 'option-select' routine. This will select the
active item in the listbox.

=item * <B<1>>, <B<y>>

Call the 'option-check' routine. If the listbox is a 
multi-select listbox, the active item will become checked
and the next item will become active.

=item * <B<0>>, <B<n>>

Call the 'option-uncheck' routine. If the listbox is a 
multi-select listbox, the active item will become unchecked
and the next item will become active.

=item * <B<cursor-down>>, <B<j>>

Call the 'option-next' routine. This will make the next
item of the list active.

=item * <B<cursor-up>>, <B<k>>

Call the 'option-prev' routine. This will make the previous
item of the list active.

=item * <B<page-up>>

Call the 'option-prevpage' routine. This will make the item
on the previous page active.

=item * <B<page-down>>

Call the 'option-nextpage' routine. This will make the item
on the next page active.

=item * <B<home>>, <B<CTRL+A>>

Call the 'option-first' routine. This will make the first
item of the list active.

=item * <B<end>>, <B<CTRL+E>>

Call the 'option-last' routine. This will make the last
item of the list active.

=item * <B</>>

Call the 'search-forward' routine. This will make a 'less'-like
search system appear in the listbox. A searchstring can be
entered. After that the user can search for the next occurance
using the 'n' key or the previous occurance using the 'N' key.

=item * <B<?>>

Call the 'search-backward' routine. This will do the same as
the 'search-forward' routine, only it will search in the 
opposite direction.

=back 





=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::Widget|Curses::UI::Widget>, 
L<Curses::UI::Common|Curses::UI::Common>




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

