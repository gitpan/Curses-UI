# ----------------------------------------------------------------------
# Curses::UI::Menubar
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Menubar;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Container;
use Curses::UI::Window;

use vars qw($VERSION @ISA);
$VERSION = '1.01';
@ISA = qw(Curses::UI::Window Curses::UI::Common);

my %routines = (
        'return'   	=> 'RETURN',
        'escape'   	=> 'ESCAPE',
	'pulldown'	=> \&pulldown,
	'cursor-left'	=> \&cursor_left,
	'cursor-right'	=> \&cursor_right,
);

my %bindings = (
	KEY_TAB()	=> 'return',
	KEY_DOWN()	=> 'pulldown',
	'j'		=> 'pulldown',
	KEY_ENTER()	=> 'pulldown',
        KEY_LEFT()      => 'cursor-left',
        'h'             => 'cursor-left',
        KEY_RIGHT()     => 'cursor-right',
        'l'             => 'cursor-right',
	KEY_ESCAPE()	=> 'escape',

);

sub new ()
{
	my $class = shift;

        my %userargs = @_;
        keys_to_lowercase(\%userargs);

	my %args = (
		-parent		 => undef,	# the parent window
		-bindings	 => {%bindings},
		-routines	 => {%routines},
		-menu		 => [],

		%userargs,

		-width		 => undef,
		-height		 => 1,
		-focus		 => 0,
		-x		 => 0,
		-y		 => 0,
		-border	 	 => 0,
		-focus		 => 0,
		-selected	 => undef,
	);

	my $this = $class->SUPER::new( %args );
	$this->layout;

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;

	$this->delallwin;
	$this->SUPER::layout;
	return $this if $Curses::UI::screen_too_small;

	return $this;
} 

sub draw()
{
	my $this = shift;
        my $no_doupdate = shift || 0;
	return if $this->hidden;

	$this->SUPER::draw(1);

	# Create full reverse menubar.
	$this->{-windowscr}->attron(A_REVERSE);
	$this->{-windowscr}->addstr(0, 0, " "x$this->screenwidth);

	# Create menu-items.
	my $x = 1;
	my $idx = 0;
	foreach my $item (@{$this->{-menu}})
	{
		# By default the bar is drawn in reverse.
		$this->{-windowscr}->attron(A_REVERSE);

		# If the bar has focus, the selected item is
		# show without reverse.
		if ($this->{-focus} and $idx == $this->{-selected}) {
		    $this->{-windowscr}->attroff(A_REVERSE);
		}
				

		my $label = $item->{-label};
		$this->{-windowscr}->addstr(0, $x, " " . $item->{-label} . " ");
		$x += length($label) + 2;
		
		$idx++;
	}
	$this->{-windowscr}->attroff(A_REVERSE);
	$this->{-windowscr}->move(0,0);

	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;
	return $this;
}

sub focus()
{
	my $this = shift;
	
	$this->{-focus} = 1;
	$this->{-selected} = 0;
	$this->draw;

        my ($return,$key) = $this->generic_focus(
                undef,
                NO_CONTROLKEYS,
                CURSOR_INVISIBLE
        );

	# Execute code?
	if (ref $return eq 'CODE') {
		$return->($this);
	# Return plain value?
	} elsif (not ref $return) {

		# Control values? Make $return undef.
		undef $return 
			if $return eq 'RETURN' 
                    	or $return eq 'ESCAPE';

		return $return
	# Return standard value.
	} else {
		return $this;
	}
}

sub pulldown() 
{
	my $this = shift;

	# Find the x position of the selected menu.
	my $x = 1;
	for my $idx (1 .. $this->{-selected})
	{
		$x += length($this->{-menu}->[$idx]->{-label});
		$x += 2;
	}

	my $id = "_submenu_$this";
	$this->root->add(
		$id, 'MenuListbox',
		-x		=> $x,
		-y		=> 1,
		-is_topmenu	=> 1,
                -menu           => $this->{-menu}->[$this->{-selected}]->{-submenu},
	);

	# The new created window might not fit.
	$this->root->check_for_too_small_screen();

	# Focus the new window.
	my ($return,$key) = $this->root->getobj($id)->focus;

	# Delete it after it returns.
	$this->root->delete($id);
	$this->root->rebuild;

	if ($return eq 'CURSOR_LEFT') 
	{ 
		$this->cursor_left;
		$this->draw;
		# Open pulldown menu.
		return "DO_KEY:" . KEY_DOWN();
	} 
	elsif ($return eq 'CURSOR_RIGHT') 
	{ 
		$this->cursor_right;
		$this->draw;
		# Open pulldown menu.
		return "DO_KEY:" . KEY_DOWN();
	}
	elsif ($return eq 'RETURN') 
	{
		return $this;
	}
	else 
	{
		return $return;
	}
}

sub cursor_left()
{
	my $this = shift;
	$this->{-selected}--;
	$this->{-selected} = @{$this->{-menu}}-1 
		if $this->{-selected} < 0;
	return $this;
}

sub cursor_right()
{
	my $this = shift;
	$this->{-selected}++;
	$this->{-selected} = 0
		if $this->{-selected} > (@{$this->{-menu}}-1);
	return $this;
}

1;


=pod

=head1 NAME

Curses::UI::Menubar - Create and manipulate menubar widgets


=head1 CLASS HIERARCHY

 Curses::UI::Widget
    |
    +----Curses::UI::Container
            |
            +----Curses::UI::Window
                    |
                    +----Curses::UI::Menubar


=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;

    # define the menu datastructure.
    my $menu_data = [....]; 

    my $menu = $cui->add( 
        'menu', 'Menubar',
        -menu => $menu_data
    );

    $menu->focus();


=head1 DESCRIPTION

This class can be used to add a menubar to Curses::UI. This
menubar can contain a complete submenu hierarchy. It looks
(remotely :-) like this:

 -------------------------------------
 menu1 | menu2 | menu3 | ....
 -------------------------------------
       +-------------+ 
       |menuitem 1   |
       |menuitem 2   |+--------------+
       |menuitem 3 >>||submenuitem 1 |
       |menuitem 4   ||submenuitem 2 |
       +-------------+|submenuitem 3 | 
                      |submenuitem 4 | 
                      |submenuitem 5 |
                      +--------------+


See exampes/demo-Curses::UI::Menubar in the distribution
for a short demo.



=head1 STANDARD OPTIONS

This class does not use any of the standard options that
are provided by L<Curses::UI::Widget>.


=head1 WIDGET-SPECIFIC OPTIONS

There is only one option: B<-menu>. The value for this
option is an ARRAYREF. This ARRAYREF behaves exactly
like the one that is described in
L<Curses::UI::MenuListbox|Curses::UI::MenuListbox>.
The difference is that for the top-level menu, you 
will only use -submenu's. Example data structure:

    my $menu1 = [
        { -label => 'option 1', -return => '1-1' },
        { -label => 'option 2', -return => '1-2' },
        { -label => 'option 3', -return => '1-3' },
    ];
   
    my $menu2 = [
        { -label => 'option 1', -callback => \&sel1 },
        { -label => 'option 2', -callback => \&sel2 },
        { -label => 'option 3', -callback => \&sel3 },
    ];

    my $submenu = [
        { -label => 'suboption 1', -return => '3-3-1' },
        { -label => 'suboption 2', -callback=> \&do_it },
    ];
    
    my $menu3 = [
        { -label => 'option 1', -callback => \&sel2 },
        { -label => 'option 2', -callback => \&sel3 },
        { -label => 'submenu 1', -submenu => $submenu },
    ];

    my $menu = [
        { -label => 'menu 1', -submenu => $menu1 },
        { -label => 'menu 2', -submenu => $menu2 }
        { -label => 'menu 3', -submenu => $menu3 }
    ]; 




=head1 METHODS

=over 4

=item * B<new> ( OPTIONS )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget>
for an explanation of these.

=back




=head1 DEFAULT BINDINGS

=over 4

=item * <B<escape>>

Call the 'escape' routine. This will have the menubar
loose its focus and return the value 'ESCAPE' to the
calling routine.

=item * <B<tab>>

Call the 'return' routine. This will have the menubar
loose its focus and return the value 'RETURN' to
the calling routine.

=item * <B<cursor-down>>, <B<j>>, <B<enter>>

Call the 'pulldown' routine. This will open the 
menulistbox for the current menu and give that
menulistbox the focus. What happens after the
menulistbox loses its focus, depends upon the
returnvalue of it:

* the value 'CURSOR_LEFT' 
  
  Call the 'cursor-left' routine and after that
  call the 'pulldown' routine. So this will open
  the menulistbox for the previous menu.

* the value 'CURSOR_RIGHT'
  
  Call the 'cursor-right' routine and after that
  call the 'pulldown' routine. So this will open
  the menulistbox for the next menu.

* the value 'RETURN'

  The menubar will keep the focus, but no
  menulistbox will be open. 

* the value 'ESCAPE'

  The menubar will loose its focus and return the
  value 'ESCAPE' to the calling routine.

* A CODE reference

  The code will be excuted, the menubar will loose its
  focus and the returnvalue of the CODE will be 
  returned to the calling routine.

* Any other value

  The menubar will loose its focus and the value will
  be returned to the calling routine.

=item * <B<cursor-left>>, <B<h>>

Call the 'cursor-left' routine. This will select
the previous menu. If the first menu is already
selected, the last menu will be selected.

=item * <B<cursor-right>>, <B<l>>

Call the 'cursor-right' routine. This will select
the next menu. If the last menu is already selected,
the first menu will be selected.

=back 





=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::MenuListbox|Curses::UI::MenuListbox>, 
L<Curses::UI::Listbox|Curses::UI:Listbox>




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

