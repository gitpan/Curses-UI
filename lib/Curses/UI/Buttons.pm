package Curses::UI::Buttons;

use strict;
use Carp qw(confess);
use Curses;
use Curses::UI::Frame;
use Curses::UI::Common;

use vars qw($VERSION @ISA @EXPORT);
$VERSION = '1.0.1';

require Exporter;
@ISA = qw(Curses::UI::Frame Exporter Curses::UI::Common);
@EXPORT = qw(compute_buttonwidth);

my $default_btn = [ '< OK >' ];

my %routines = (
	'return' 	=> 'RETURN',
	'loose-focus'	=> 'LOOSE-FOCUS',
	'next'		=> \&next_button,
	'previous'	=> \&previous_button,
	'shortcut'	=> \&shortcut,  
);

my %bindings = (
	KEY_ENTER()	=> 'return',
	"\n"		=> 'return',
	' '		=> 'return',
	KEY_LEFT()	=> 'previous',
	'h'		=> 'previous',
	KEY_RIGHT()	=> 'next',
	'l'		=> 'next',
	''		=> 'shortcut',
	
);

sub new ()
{
	my $class = shift;
	
	my %myroutines = %routines;
	my %mybindings = %bindings;

	my %args = (
		-parent		 => undef,	  # the parent window
		-buttons 	 => $default_btn, # buttons (arrayref)
		-values		 => undef,	  # values for buttons (arrayref)
		-shortcuts	 => undef,	  # shortcut keys
		-buttonalignment => undef,  	  # left / middle / right
		-selected 	 => 0,		  # which selected
		-width		 => undef,	  # the width of the buttonframe
		-x		 => 0,		  # the horizontal position rel. to parent
		-y		 => 0,		  # the vertical position rel. to parent

		-mayloosefocus	 => 0,		  # Enable TAB to loose focus?
		-routines	 => \%myroutines,
		-bindings	 => \%mybindings,

		@_,

		-focus		 => 0,
	);

	# The windowscr height should be 1.
	$args{-height} = height_by_windowscrheight(1,%args);

	# Create the frame.
	my $this = $class->SUPER::new( %args );

	$this->layout();

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;

	$this->SUPER::layout();

	# Compute the space that is needed for the buttons.
	my $xneed = compute_buttonwidth($this->{-buttons});
	
	if ( $xneed > $this->screenwidth ) {	
# TODO unfit detection
#		confess "Not enough room for the buttons "
#		  . "in the $this object";
	}

	# Compute the x location of the buttons.
	my $xpos = 0;
	if (defined $this->{-buttonalignment})
	{
	    if ($this->{-buttonalignment} eq 'right') {
		$xpos = $this->screenwidth - $xneed;
	    } elsif ($this->{-buttonalignment} eq 'middle') {
		$xpos = int (($this->screenwidth-$xneed)/2);
	    }
	}
	$this->{-xpos} = $xpos;

	$this->{-max_selected} = @{$this->{-buttons}} - 1;

	# May loose focus? Create bindings.
	$this->set_binding('loose-focus', KEY_STAB(), KEY_BTAB(), "\t")
		if $this->{-mayloosefocus};

	# Make shortcuts all upper-case.	
	if (defined $this->{-shortcuts}) {
		foreach (@{$this->{-shortcuts}}) {
			$_ = uc $_;
		}
	}

	return $this;
}

sub get()
{
	my $this = shift;
	my $s = $this->{-selected}; 
	if (defined $this->{-values}) {
		return $this->{-values}->[$s];
	} else {
		return $s;
	}
}

sub focus()
{
	my $this = shift;
	return $this->generic_focus(
		undef,
		NO_CONTROLKEYS,
		CURSOR_INVISIBLE
	);
}

sub next_button()
{
	my $this = shift;
	$this->{-selected}++;
	return $this;
}

sub previous_button()
{
	my $this = shift;
	$this->{-selected}--;
	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;
		
        # Return immediately if this object is hidden.
        return $this if $this->hidden;

	# Check if active element isn't out of bounds.
	$this->{-selected} = 0 unless defined $this->{-selected};
	$this->{-selected} = 0 if $this->{-selected} < 0; 
	$this->{-selected} = $this->{-max_selected} 
		if $this->{-selected} > $this->{-max_selected};

	# Draw the frame.
	$this->SUPER::draw(1);
	
	# Draw the buttons.
	my $id = 0;
	my $x  = 0;
	my $cursor_x = 0;
	foreach (@{$this->{-buttons}})
	{
		# Make the focused button reverse.
		if ($this->{-focus} and defined $this->{-selected} 
		     and $id == $this->{-selected}) {
			$this->{-windowscr}->attron(A_REVERSE);
		}

		# Draw the button.
		$this->{-windowscr}->addstr(
			0,
			$this->{-xpos} + $x,
			$_
		);	

		
		# Draw shortcut if available.
		my $sc = $this->{-shortcuts}->[$id];
		if (defined $sc)
		{
			my $pos = index(uc $_, $sc);
			if ($pos >= 0)
			{
				my $letter = substr($_, $pos, 1); 
				$this->{-windowscr}->attron(A_UNDERLINE);
				$this->{-windowscr}->addch(
					0,
					$this->{-xpos} + $x + $pos,
					$letter
				);
				$this->{-windowscr}->attroff(A_UNDERLINE);
			}
		}

		$x += 1 + length($_);
		$this->{-windowscr}->attroff(A_REVERSE) if $this->{-focus};
		
		$id++;
	}
	$this->{-windowscr}->move(0,0);
	$this->{-windowscr}->noutrefresh;
	doupdate() unless $no_doupdate;

	return $this;
}

sub compute_buttonwidth($;)
{
        my $buttons = shift;
        $buttons = $default_btn unless defined $buttons;

        # Spaces
        my $width = @$buttons - 1;

        # Buttons
        foreach (@$buttons) {
                $width += length($_);
        };

        return $width;
}

sub shortcut()
{
	my $this = shift;
	my $key = uc shift;
	
	# Walk through shortcuts to see if the pressed key
	# is in the list of -shortcuts.
	my $idx = -1;
	SHORTCUT: for (my $i=0; $i<@{$this->{-shortcuts}}; $i++) 
	{
		my $sc = $this->{-shortcuts}->[$i];
		if (defined $sc and $sc eq $key)
		{
			$idx = $i;
			last SHORTCUT;
		}
	}

	# Shortcut found?
	if ($idx > -1) 
	{
		$this->{-selected} = $idx;
		return $this->process_bindings(KEY_ENTER());
	}

	return $this;
}

1;

