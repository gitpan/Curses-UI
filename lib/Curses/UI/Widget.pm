# ----------------------------------------------------------------------
# Curses::UI::Widget
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Widget;

use strict;
use Carp qw(confess);
use Term::ReadKey;
use Curses;
use Curses::UI::Common;
require Exporter;

use vars qw($VERSION @ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(
	height_by_windowscrheight
	width_by_windowscrwidth
	process_padding
);
$VERSION = '1.0.0';

sub new ()
{
	my $class = shift;

	my %args = ( 
		-parent		=> undef, 	# the parent object
		-assubwin	=> 1,		# 0 = no, 1 = yes, create as subwindow? 
		-x		=> 0,		# horizontal position (rel. to -parent)
		-y		=> 0,		# vertical position (rel. to -parent)
		-width		=> undef,	# horizontal size 
		-height		=> undef,	# vertical size
		-border		=> 0,		# add a border?
		-sbborder	=> 0,		# add square bracket border?

		-titlefullwidth => 0,		# full width for title?
		-titlereverse   => 1,		# reverse chars for title? 
		-title		=> undef,	# A title to add to the widget (only for 
						# -border = 1)

						# padding outside widget
		-pad		=> undef,	# all over padding
		-padright	=> undef,	# free space on the right side
		-padleft	=> undef,	# free space on the left side
		-padtop		=> undef,	# free space above
		-padbottom	=> undef,	# free space below

						# padding inside widget
		-ipad		=> undef,	# all over padding
		-ipadright	=> undef,	# free space on the right side
		-ipadleft	=> undef,	# free space on the left side
		-ipadtop	=> undef,	# free space above
		-ipadbottom	=> undef,	# free space below

		-vscrollbar	=> 0,    	# vert. scrollbar (top/bottom)
		-vscrolllen     => 0,		# total number of rows
		-vscrollpos     => 0,		# current row position

		-hscrollbar	=> 0,    	# hor. scrollbar (left/right)
		-hscrolllen     => 0,		# total number of columns
		-hscrollpos     => 0,		# current column position 

		@_,
	
		-scr		=> undef,	# generic window handler
		-focus		=> 0,	  	# has the widget focus?	
	);

	# Allow the value -1 for using the full width and/or
	# height for the widget.
	$args{-width} = undef 
		if defined $args{-width} and $args{-width} == -1;
	$args{-height} = undef 
		if defined $args{-height} and $args{-height} == -1;

	confess "Missing parameter: -parent" 
		if $args{-assubwin} and not defined $args{-parent};
	
	# Allow a square bracket border only if 
	# a normal border (-border) is disabled.
	$args{-sbborder} = 0 if $args{-sbborder} and $args{-border};
	
	# Bless you! (so we can call the layout function).
	my $this = bless \%args, $class;

	$this->layout;

	return $this;
}

sub layout()
{
	my $this = shift;

	$this->process_padding;
	
	# -------------------------------------------------------
	# Delete windows 
	# -------------------------------------------------------

	foreach (qw(-windowscr -borderscr)) 
	{
	    if (defined $this->{$_})
  	    {	
		$this->{$_}->delwin;
		delete $this->{$_};
	    }
	}
	delete $this->{-scr};
        
	# -------------------------------------------------------
	# Compute the space that we have for the widget.
	# -------------------------------------------------------

	if ($this->{-assubwin} and defined $this->{-parent}
	    and not $this->isa('Curses::UI::MenuBar')) 
	{
		$this->{-parentdata} = $this->{-parent}->windowparameters;
	} else {
		$this->{-parentdata} = {
			'-w' => $ENV{COLS},
			'-h' => $ENV{LINES},
			'-x' => 0,
			'-y' => 0,
		};
	}

	foreach (qw(x y)) {
   	    if (not defined $this->{"-$_"}) {$this->{"-$_"} = 0} 
	    if ($this->{"-$_"} >= 0) {
		$this->{"-real$_"} = $this->{"-$_"};
	    } else {
		my $pv = ($_ eq 'x' ? '-w' : '-h');
		$this->{"-real$_"} = $this->{-parentdata}->{$pv} 
		 		   + $this->{"-$_"} + 1;
	    }
	}

	my $w = $this->{-parentdata}->{-w};
	my $h = $this->{-parentdata}->{-h};
	my $avail_h = $h - abs($this->{-y});
	my $avail_w = $w - abs($this->{-x});
	
	# Compute horizontal widget size and adjust if neccessary.
	my $min_w = ($this->{-border} ? 2 : 0) 
	          + ($this->{-sbborder} ? 2 : 0) 
	          + (defined $this->{-vscrollbar} ? 1 : 0) 
		  + $this->{-padleft} + $this->{-padright}; 
	my $width = (defined $this->{-width} ? $this->{-width} : $avail_w);
	$width = $min_w if $width < $min_w; 
	$width = $avail_w if $width > $avail_w; 

	# Compute vertical widget size and adjust if neccessary.
	my $min_h = ($this->{-border} ? 2 : 0)
	          + ($this->{-hscrollbar} ? 1 : 0) 
	          + (defined $this->{-hscrollbar} ? 1 : 0) 
		  + $this->{-padtop} + $this->{-padbottom};
	my $height = (defined $this->{-height} ? $this->{-height} : $avail_h);
	$height = $min_h   if $height < $min_h;
	$height = $avail_h if $height > $avail_h;

	# Check if the widget fits in the window.
	if ($width > $avail_w or $height > $avail_h 
	    or $width == 0 or $height == 0) {
		# TODO?: no fit error
		confess "There is not enough space for the $this object "
		  . "(width=$width, avail width=$avail_w, "
		  . "height=$height, avail height=$avail_h)";
	}

	$this->{-w}  = $width;
	$this->{-h}  = $height;

	if ($this->{-x} < 0) { $this->{-realx} -= $width }
	if ($this->{-y} < 0) { $this->{-realy} -= $height }
	
	# Take care of padding for the border.
	$this->{-bw} = $width - $this->{-padleft} - $this->{-padright};
	$this->{-bh} = $height - $this->{-padtop} - $this->{-padbottom};
	$this->{-bx} = $this->{-realx} + $this->{-padleft};
	$this->{-by} = $this->{-realy} + $this->{-padtop};

	# -------------------------------------------------------
	# Create a window for the widget border, if a border 
	# and/or scrollbars are wanted.
	# -------------------------------------------------------

	if ($this->{-border} or $this->{-sbborder} 
	    or $this->{-vscrollbar} or $this->{-hscrollbar}) 
	{
		my @args = ($this->{-bh}, $this->{-bw},
			    $this->{-parentdata}->{-y} + $this->{-by},
			    $this->{-parentdata}->{-x} + $this->{-bx});

		if ($this->{-assubwin}) {
			$this->{-borderscr} = 
				$this->{-parent}->{-windowscr}->subwin(@args);
		} else {
			$this->{-borderscr} = newwin(@args);
		}
		# TODO?: no fit error
		confess "Could not create border screen (args = @args)\n" 
			unless defined $this->{-borderscr};

		$this->{-scr} = $this->{-borderscr};
	}

	# -------------------------------------------------------
	# Create screen region
	# -------------------------------------------------------

	$this->{-sh}  = $this->{-bh} - $this->{-ipadtop} 
		        - $this->{-ipadbottom} - ($this->{-border}? 2 : 0)
			- (not $this->{-border} and $this->{-hscrollbar} ? 1 : 0);
	$this->{-sw}  = $this->{-bw} - $this->{-ipadleft} 
		        - $this->{-ipadright} - ($this->{-border}? 2 : 0)
		        - ($this->{-sbborder}? 2 : 0)
			- (not $this->{-border}
			   and $this->{-vscrollbar} ? 1 : 0);
	$this->{-sy}  = $this->{-by} + $this->{-ipadtop} + ($this->{-border}?1:0)
			+ (not $this->{-border} 
                           and $this->{-hscrollbar} eq 'top' ? 1 : 0);
	$this->{-sx}  = $this->{-bx} + $this->{-ipadleft} 
			+ ($this->{-border}?1:0)
			+ ($this->{-sbborder}?1:0)
			+ (not $this->{-border} 
                           and $this->{-vscrollbar} eq 'left' ? 1 : 0);

	# Check if there is room left for the screen.
	if ($this->{-sw} <= 0 or $this->{-sh} <= 0) {
		# TODO?: no fit error
		confess "There is not enough space for the " 
		  . $this . " widget (screenwidth=$this->{-sw}, "
                  . "screenheight=$this->{-sh})";
	}

	# Create a window for the data.
	my @args = ($this->{-sh}, $this->{-sw},
	   	    $this->{-parentdata}->{-y} + $this->{-sy},
		    $this->{-parentdata}->{-x} + $this->{-sx});
	if ($this->{-assubwin}) {
		$this->{-windowscr} = 
			$this->{-parent}->{-windowscr}->subwin(@args);
	} else {
		$this->{-windowscr} = newwin(@args);
	}
	# TODO?: no fit error
	confess "Could not create window screen (args = @args)\n" 
		unless defined $this->{-windowscr};

	if (not defined $this->{-borderscr})
	{
		$this->{-scr} = $this->{-windowscr};
		$this->{-bw} = $this->{-sw};
		$this->{-bh} = $this->{-sh};
	}
		
	# TODO?: no fit error
	confess "Could not create border window" 
		unless defined $this->{-windowscr};

	return $this;
}

sub process_padding($;)
{
	my $this = shift;

	# Process the padding arguments.
	foreach my $type ('-pad','-ipad') {
		if (defined $this->{$type}) {
			foreach my $side ('right','left','top','bottom') {
				$this->{$type . $side} = $this->{$type}
					unless defined $this->{$type . $side};
			}
		}
	}
	foreach my $type ('-pad','-ipad') {
		foreach my $side ('right','left','top','bottom') 
		{
			$this->{$type . $side} = 0
				unless defined $this->{$type . $side};
		}
	}
}

sub width_by_windowscrwidth($@;)
{
        my $width = shift || 0;
	my %args = @_;
	
	$width += 2 if $args{-border};  # border
	$width += 2 if $args{-sbborder};  # sbborder
	$width += 1 if (not $args{-border} and not $args{-sbborder}
			and $args{-vscrollbar});
	foreach my $t ("-ipad", "-pad")     # internal + external padding
	{
		if ($args{$t})
		{
                    $width += 2*$args{$t};
                } else {
                    $width += $args{$t . "left"} 
			if defined $args{$t . "left"};
                    $width += $args{$t . "right"} 
			if defined $args{$t . "right"};
                }
	}
	return $width;	
}

sub height_by_windowscrheight($@;)
{
        my $height = shift || 0;
	my %args = @_;
	
	$height += 2 if $args{-border};  # border
	$height += 1 if (not $args{-border} and $args{-hscrollbar});
	foreach my $t ("-ipad", "-pad")     # internal + external padding
	{
		if ($args{$t})
		{
                    $height += 2*$args{$t};
                } else {
                    $height += $args{$t . "top"} 
			if defined $args{$t . "top"};
                    $height += $args{$t . "bottom"} 
			if defined $args{$t . "bottom"};
                }
	}
	return $height;	
}

sub width 		{ shift->{-w} }
sub height 		{ shift->{-h} }
sub borderwidth 	{ shift->{-bw} }
sub borderheight 	{ shift->{-bh} }
sub screenwidth 	{ shift->{-sw} }
sub screenheight 	{ shift->{-sh} }

sub title ($;)		
{ 
	my $this = shift;
	$this->{-title} = shift;
}

sub windowparameters		
{ 
	my $this = shift;
	my $s = $this->{-windowscr};
	my ($x,$y,$w,$h);

	$s->getbegyx($y, $x);
	$s->getmaxyx($h, $w); 

	my $cor_h = 0;
	my $cor_y = 0;
	if ($this->isa('Curses::UI::Container') and
	    $this->hasa('Curses::UI::MenuBar')) {
		$cor_h -= 1;
		$cor_y += 1;
	}
	
	return {
		-w => $w,
		-h => $h + $cor_h, 
		-x => $x,
		-y => $y + $cor_y,
	};
}

# Must be overridden in child class, to make
# the widget focusable.
sub focus { shift()->show; return ('RETURN',''); }

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

        # Return immediately if this object is hidden.
        return $this if $this->hidden;

	eval { curs_set(0) }; # not available on every system.

	# Clear the contents of the window.
	for my $y (0..$this->borderheight-1) {
		$this->{-scr}->addstr($y, 1, " "x($this->borderwidth));
	}
	$this->{-scr}->noutrefresh();

	# Do borderstuff?
	if (defined $this->{-borderscr})
	{
	    # Draw a border if needed.
	    if ($this->{-sbborder})  # Square bracket ([,]) border
	    {
		$this->{-borderscr}->attron(A_BOLD) if $this->{-focus};
		my $offset = 1;
		$offset++ if $this->{-vscrollbar};
		for my $y (0 .. $this->{-sh}-1)
		{
		    my $rel_y = $y + $this->{-sy} - $this->{-by};
		    $this->{-borderscr}->addstr($rel_y, 0, '[');
		    $this->{-borderscr}->addstr($rel_y, $this->{-bw}-$offset, ']');
		}
		$this->{-borderscr}->attroff(A_BOLD) if $this->{-focus};
	    }
	    elsif ($this->{-border}) # Normal border
	    {
		$this->{-borderscr}->attron(A_BOLD) if $this->{-focus};
		$this->{-borderscr}->box(ACS_VLINE, ACS_HLINE);
		$this->{-borderscr}->attroff(A_BOLD) if $this->{-focus};
		
		# Draw a title if needed.
		if (defined $this->{-title})
		{
			$this->{-borderscr}->attron(A_REVERSE) 
				if $this->{-titlereverse};
			if ($this->{-titlefullwidth} 
			    and $this->{-titlereverse}) {
				$this->{-borderscr}->addstr(0, 1, " "x($this->{-bw}-2));
			}
			my $t = $this->{-title};
			my $l = $this->{-bw}-4;
			if ($l < length($t))
			{
				$t = substr($t, 0, $l) if $l < length($t);
				$t =~ s/...$/\.\.\./;
			}
			$this->{-borderscr}->addstr(0, 1, " $t ");
			$this->{-borderscr}->attroff(A_REVERSE);
		}
	    }
        
	    $this->draw_scrollbars();
	    $this->{-borderscr}->noutrefresh();
	}

	doupdate() unless $no_doupdate;
	return $this;
}

sub draw_scrollbars()
{	
	my $this = shift;

	return $this unless defined $this->{-borderscr};

	if ($this->{-vscrollbar} and defined $this->{-vscrolllen}) 
	{

		# Compute the drawing range for the scrollbar.
		my $xpos = $this->{-vscrollbar} eq 'left' 
                         ? 0 : $this->borderwidth-1; 

		my $ypos_min = $this->{-sy}-$this->{-by};
		my $ypos_max = $ypos_min + $this->screenheight - 1;
		my $scrlen = $ypos_max - $ypos_min + 1;
		my $actlen = $this->{-vscrolllen}
			   ? int($scrlen * ($scrlen/($this->{-vscrolllen}))+0.5)
			   : 0;
		$actlen = 1 if not $actlen and $this->{-vscrolllen};
		my $actpos = ($this->{-vscrolllen} and $this->{-vscrollpos})
			   ? int($scrlen*($this->{-vscrollpos}/$this->{-vscrolllen})) + $ypos_min + 1 
			   : $ypos_min;

		# Only let the marker be at the end if the
		# scrollpos is too.
		if ($this->{-vscrollpos}+$scrlen >= $this->{-vscrolllen}) {
			$actpos = $scrlen - $actlen + $ypos_min;
		} else {
			if ($actpos + $actlen >= $scrlen) {
				$actpos--;
			}
		}
		
		# Only let the marker be at the beginning if the
		# scrollpos is too.
		if ($this->{-vscrollpos} == 0) {
			$actpos = $ypos_min;
		} else {
			if ($this->{-vscrollpos} and $actpos <= 0) {
				$actpos = $ypos_min+1;
			}
		}
		
		# Draw the base of the scrollbar, in case
		# there is no border.
		$this->{-borderscr}->attron(A_BOLD) if $this->{-focus};
		$this->{-borderscr}->move($ypos_min, $xpos);
		$this->{-borderscr}->vline(ACS_VLINE,$scrlen);
		$this->{-borderscr}->attroff(A_BOLD) if $this->{-focus};

		# Should an active region be drawn?
		my $scroll_active = ($this->{-vscrolllen} > $scrlen);
		# Draw scrollbar base, in case there is
		# Draw active region.
		if ($scroll_active) 
		{
			$this->{-borderscr}->attron(A_REVERSE);
			for my $i (0 .. $actlen-1) {
				$this->{-borderscr}->addch($i+$actpos,$xpos," ");
			}
			$this->{-borderscr}->attroff(A_REVERSE);
		}
	}
	
	if ($this->{-hscrollbar} and defined $this->{-hscrolllen})
	{
		# Compute the drawing range for the scrollbar.
		my $ypos = $this->{-hscrollbar} eq 'top' 
                       	? 0 : $this->borderheight-1; 

		my $xpos_min = $this->{-sx}-$this->{-bx};
		my $xpos_max = $xpos_min + $this->screenwidth - 1;
		my $scrlen = $xpos_max - $xpos_min + 1;
		my $actlen = $this->{-hscrolllen}
			   ? int($scrlen * ($scrlen/($this->{-hscrolllen}))+0.5)
			   : 0;
		$actlen = 1 if not $actlen and $this->{-hscrolllen};
		my $actpos = ($this->{-hscrolllen} and $this->{-hscrollpos})
			   ? int($scrlen*($this->{-hscrollpos}/$this->{-hscrolllen})) + $xpos_min + 1 
			   : $xpos_min;

		# Only let the marker be at the end if the
		# scrollpos is too.
		if ($this->{-hscrollpos}+$scrlen >= $this->{-hscrolllen}) {
			$actpos = $scrlen - $actlen + $xpos_min;
		} else {
			if ($actpos + $actlen >= $scrlen) {
				$actpos--;
			}
		}
		
		# Only let the marker be at the beginning if the
		# scrollpos is too.
		if ($this->{-hscrollpos} == 0) {
			$actpos = $xpos_min;
		} else {
			if ($this->{-hscrollpos} and $actpos <= 0) {
				$actpos = $xpos_min+1;
			}
		}
	
		# Draw the base of the scrollbar, in case
		# there is no border.
		$this->{-borderscr}->attron(A_BOLD) if $this->{-focus};
		$this->{-borderscr}->move($ypos, $xpos_min);
		$this->{-borderscr}->hline(ACS_HLINE,$scrlen);
		$this->{-borderscr}->attroff(A_BOLD) if $this->{-focus};

		# Should an active region be drawn?
		my $scroll_active = ($this->{-hscrolllen} > $scrlen);
		# Draw active region.
		if ($scroll_active) 
		{
			$this->{-borderscr}->attron(A_REVERSE);
			for my $i (0 .. $actlen-1) {
				$this->{-borderscr}->addch($ypos, $i+$actpos," ");
			}
			$this->{-borderscr}->attroff(A_REVERSE);
		}
	}
	
	return $this;
}

1;

__END__

=pod

=head1 NAME

Curses::UI::Widget - The base class for all widgets


=head1 SYNOPSIS

This class is not used directly by somebody who is building an application
using Curses::UI. It's a base class that is expanded by the Curses::UI widgets.
Here's an example of how to start out creating a new widget:

    package Curses::UI::YourWidget
    
    use Curses;
    use Curses::UI::Widget;  
    use Curses::UI::Common; # some common widget routines

    use vars qw($VERSION @ISA);
    $VERSION = '1.0.0';
    @ISA = qw(Curses::UI::Widget Curses::UI::Common);

    # For a widget that can get focus, you should define
    # the routines that are used to control the widget.
    # Each routine has a name. This name is used in 
    # the definition of the bindings. 
    # The value can be a string or a subroutine reference. 
    # A string will make the widget return from focus.
    #
    my %routines = (
        'return'    => 'RETURN',
        'key-a'     => \&key_a,
        'key-other' => \&other_key
    );

    # Using the bindings, the routines can be binded to key-
    # presses. If the keypress is an empty string, this means
    # that this is the default binding. If the key is not 
    # handled by any other binding, it's handled by this
    # default binding.
    #
    my %bindings = (
        KEY_DOWN()  => 'return',   # down arrow will make the 
                                   # widget loose it's focus
        'a'         => 'key-a',    # a-key will trigger key_a()
        ''          => 'key-other' # any other key will trigger other_key()
    );

    # The creation of the widget. When doing it this way,
    # it's easy to make optional and forced arguments 
    # possible. A forced argument could for example be 
    # -border => 1, which would mean that the widget
    # always has a border, which can't be disabled by the
    # programmer. The arguments can of course be used 
    # for storing the current state of the widget.
    #
    sub new () {
        my $class = shift;
        my %args = (
            -optional_argument_1 => "default value 1",
            -optional_argument_2 => "default value 2",
            ....etc....
            @_,
            -forced_argument_1   => "forced value 1", 
            -forced_argument_2   => "forced value 2", 
            ....etc....
            -bindings            => {%bindings},
            -routines            => {%routines},
        );

        # Create the widget and do the layout of it.
        my $this = $class->SUPER::new( %args );
	$this->layout;

	return $this;
    }

    # Each widget should have a layout() routine. Here,
    # the widget itself and it's contents can be layouted.
    # In case of a very simple widget, this will only mean
    # that the Widget has to be layouted (in which case the
    # routine could be left out, since it's in the base
    # class already). In other cases you will have to add
    # your own layout code. This routine is very important,
    # since it will enable the resizeability of the widget!
    #
    sub layout () {
        my $this = shift;
        $this->SUPER::layout;

        ....your own layout stuff....

        return $this;
    }

    # The widget is drawn by the draw() routine. The
    # $no_update part is used to disable screen flickering
    # if a lot of widgets have to be drawn at once (for
    # example on resizing or redrawing). The curses window
    # which you can use for drawing is $this->{-windowscr}.
    #
    sub draw(;$) {
        my $this = shift;
        my $no_doupdate = shift || 0;
        return $this if $this->hidden;
        $this->SUPER::draw(1);

        ....your own draw stuff....

        $this->{-windowscr}->noutrefresh;
        doupdate() unless $no_doupdate;
	return $this;
    }

    # Focus the widget. If you do not override this routine
    # from Curses::UI::Widget, the widget will not be 
    # focusable. Mostly you will use generic_focus() from
    # Curses::UI::Common. 
    #
    sub focus()
    {
        my $this = shift;
        $this->show;
        return $this->generic_focus(
            undef,             # delaytime, default = 2 (1/10 second).
            NO_CONTROLKEYS,    # disable controlkeys like CTRL+C. To enable
                               # them use CONTROLKEYS instead.
            CURSOR_INVISIBLE,  # do not show the cursor (if supported). To
                               # show the cursor use CURSOR_VISIBLE.
            \&pre_key_routine, # optional callback routine to execute
                               # before a key is read. Mostly unused.
        );
    }  
    
    ....your own widget handling routines....


=head1 STANDARD OPTIONS

The standard options for (most) widgets are the options that are enabled
by this class. So this class doesn't really have standard options.


=head1 WIDGET-SPECIFIC OPTIONS

GENERAL:

-parent         The parent of the object 
-border         0 = no border, 1 = show border
-sbborder       Square bracket border (using [ and ] symbols)
                instead of normal border (especially useful for
                single line widgets)

POSITIONING:

-x              The x-position of the widget, relative to the parent
-y              The y-position of the widget, relative to the parent

-width          The width of the widget. Undef or -1 mean "full width"
-height         The height of the widget. Undef or -1 mean "full height"

-pad            Overall padding outside the widget
-padtop         Specific padding for each side of the widget. If 
-padbottom      one of these four is defined, it will override the
-padleft        basic -pad setting.
-padright

-ipad           Overall padding inside the widget
-ipadtop        See -padtop, -padbottom, -padleft, -padright
-ipadbottom
-ipadleft
-ipadright

TITLE:

(titles will only be visible if border = 1)

-title          The text for the title
-titlereverse   0 = normal title, 1 = title in reverse font
-titlefullwidth 0 = titlewidth is textwidth, 1 = title is full width

SCROLLBARS:

-vscrollbar     0 = no vertical scrollbar
                1 = show vertical scrollbar (on the right side)
                'right' = show scrollbar on the right side of the widget
                'left'  = show scrollbar on the right side of the widget
-hscrollbar     0 = no horizontal scrollbar
                1 = show horizontal scrollbar (at the bottom)
                'top' = show scrollbar at the top of the widget
                'bottom' = show scrollbar at the bottom of the widget


=head1 SEE ALSO

L<Curses|Curses>


=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty.  It may be used, redistributed and/or modified
under the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)

=end





