# ----------------------------------------------------------------------
# Curses::UI::Checkbox
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# Currently maintained by Marcus Thiesen
# e-mail: marcus@cpan.thiesenweb.de
# ----------------------------------------------------------------------

# TODO: update docs

package Curses::UI::Checkbox;

use strict;
use Curses;
use Curses::UI::Label;
use Curses::UI::Widget;
use Curses::UI::Common;

use vars qw(
    $VERSION 
    @ISA
);

$VERSION = '1.10';

@ISA = qw(
    Curses::UI::ContainerWidget 
);

my %routines = (
    'loose-focus'       => \&loose_focus,
    'uncheck'           => \&uncheck,
    'check'             => \&check,
    'toggle'            => \&toggle,
    'mouse-button1'	=> \&mouse_button1,
);

my %bindings = (
    KEY_ENTER()         => 'loose-focus',
    CUI_TAB()           => 'loose-focus',
    KEY_BTAB()          => 'loose-focus',
    CUI_SPACE()         => 'toggle',
    '0'                 => 'uncheck',
    'n'                 => 'uncheck',
    '1'                 => 'check',
    'y'                 => 'check',
);

sub new ()
{
    my $class = shift;

    my %userargs = @_;
    keys_to_lowercase(\%userargs);

    my %args = (
        -parent         => undef,    # the parent window
        -width          => undef,    # the width of the checkbox
        -x              => 0,        # the horizontal pos. rel. to parent
        -y              => 0,        # the vertical pos. rel. to parent
        -checked        => 0,        # checked or not?
        -label          => '',       # the label text
        -onchange       => undef,    # event handler

        %userargs,
    
        -bindings       => {%bindings},
        -routines       => {%routines},

        -focus          => 0,        # value init
        -nocursor       => 0,        # this widget uses a cursor
    );

    # The windowscr height should be 1.
    $args{-height} = height_by_windowscrheight(1,%args);
    
    # No width given? Then make the width the same size
    # as the label + checkbox.
    $args{-width} = width_by_windowscrwidth(4 + length($args{-label}),%args)
        unless defined $args{-width};
    
    my $this = $class->SUPER::new( %args );
    
    # Create the label on the widget.
    $this->add(
        'label', 'Label',
        -text           => $this->{-label},
        -x              => 4,
        -y              => 0,
        -intellidraw    => 0,
    );

    $this->layout;

    if ($Curses::UI::ncurses_mouse) {
        $this->set_mouse_binding('mouse-button1', BUTTON1_CLICKED());
    }

    return $this;
}

sub onChange(;$)  { shift()->set_event('-onchange',  shift()) }

sub layout()
{
    my $this = shift;

    my $label = $this->getobj('label');
    if (defined $label)
    {
        my $lh = $label->{-height};
        $lh = 1 if $lh <= 0;    
        $this->{-height} = $lh;
    }

    $this->SUPER::layout or return;
    return $this;
}

sub draw(;$)
{
    my $this = shift;
    my $no_doupdate = shift || 0;
        
    # Draw the widget.
    $this->SUPER::draw(1) or return $this;

    # Draw the checkbox.
    $this->{-canvasscr}->attron(A_BOLD) if $this->{-focus};    
    $this->{-canvasscr}->addstr(0, 0, '[ ]');
    $this->{-canvasscr}->addstr(0, 1, 'X') if $this->{-checked};
    $this->{-canvasscr}->attroff(A_BOLD) if $this->{-focus};    

    $this->{-canvasscr}->move(0,1);
    $this->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;

    return $this;
}

sub uncheck()
{
    my $this = shift;
    my $changed = ($this->{-checked} ? 1 : 0);
    $this->{-checked} = 0;
    if ($changed) 
    {
        $this->run_event('-onchange');
        $this->schedule_draw(1);
    }
    return $this;
}

sub check()
{
    my $this = shift;
    my $changed = ($this->{-checked} ? 0 : 1);
    $this->{-checked} = 1;
    if ($changed) 
    {
        $this->run_event('-onchange');
        $this->schedule_draw(1);
    }
    return $this;
}

sub toggle()
{
    my $this = shift;
    $this->{-checked} = !$this->{-checked};
    $this->run_event('-onchange');
    $this->schedule_draw(1);
}

sub mouse_button1($$$$;)
{
    my $this  = shift;
    my $event = shift;
    my $x     = shift;
    my $y     = shift;

    $this->focus();
    $this->toggle();

    return $this;
}

sub get()
{
    my $this = shift;
    return $this->{-checked};
}

1;


=pod

=head1 NAME

Curses::UI::Checkbox - Create and manipulate checkbox widgets


=head1 CLASS HIERARCHY

 Curses::UI::Widget
    |
    +----Curses::UI::Container
            |
            +----Curses::UI::Buttonbox



=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $checkbox = $win->add(
        'mycheckbox', 'Checkbox',
        -label     => 'Say hello to the world',
        -checked   => 1,
    );

    $checkbox->focus();
    my $checked = $checkbox->get();


=head1 DESCRIPTION

Curses::UI::Checkbox is a widget that can be used to create 
a checkbox. A checkbox has a label which says what the 
checkbox is about and in front of the label there is a
box which can have an "X" in it. If the "X" is there, the
checkbox is checked (B<get> will return a true value). If
the box is empty, the checkbox is not checked (B<get> will
return a false value). A checkbox looks like this:

    [X] Say hello to the world

See exampes/demo-Curses::UI::Checkbox in the distribution
for a short demo.



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

=item * B<-label> < TEXT >

This will set the text label for the checkbox widget 
to TEXT.

=item * B<-checked> < BOOLEAN >

This option determines if at creation time the checkbox
should be checked or not. By default this option is
set to false, so the checkbox is not checked.

=item * B<-onchange> < CODEREF >

This sets the onChange event handler for the checkbox widget.
If the checkbox is toggled, the code in CODEREF will be executed.
It will get the widget reference as its argument.

=back




=head1 METHODS

=over 4

=item * B<new> ( OPTIONS )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<intellidraw> ( )

=item * B<focus> ( )

=item * B<onFocus> ( CODEREF )

=item * B<onBlur> ( CODEREF )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget> 
for an explanation of these.

=item * B<get> ( )

This method will return the current state of the checkbox
(0 = not checked, 1 = checked).

=item * B<check> ( )

This method can be used to set the checkbox to its checked state.

=item * B<uncheck> ( )

This method can be used to set the checkbox to its unchecked state.

=item * B<toggle> ( )

This method will set the checkbox in "the other state". This means
that the checkbox will get checked if it is not and vice versa.

=item * B<onChange> ( CODEREF )

This method can be used to set the B<-onchange> event handler
(see above) after initialization of the checkbox.


=back




=head1 DEFAULT BINDINGS

=over 4

=item * <B<tab>>, <B<enter>>

Call the 'loose-focus' routine. This will have the widget 
loose its focus.

=item * <B<space>>

Call the 'toggle' routine (see the B<toggle> method). 

=item * <B<0>>, <B<n>>

Call the 'uncheck' routine (see the B<uncheck> method).

=item * <B<1>>, <B<y>>

Call the 'check' routine (see the B<check> method).

=back 





=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::Widget|Curses::UI::Widget>, 
L<Curses::UI::Common|Curses::UI::Common>




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

Maintained by Marcus Thiesen (marcus@cpan.thiesenweb.de)


This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

