package Curses::UI::ProgressBar;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Frame;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::Frame Curses::UI::Common);
$VERSION = '1.0.0';

sub new ()
{
	my $class = shift;

	my %args = ( 
		-min        => 0,	# minimal value	
		-max        => 100,	# maximum value	
		-pos	    => 0,	# the current position
		-showpercentage => 1,	# show the percentage or not?
		-showcenterline => 1,	# show the center line or not?
		-border	    => 1,
		@_
	);

	# Check that the lowest value comes first.
	if ($args{-min} > $args{-max}) {
		my $tmp = $args{-min};
		$args{-min} = $args{-max};	
		$args{-max} = $tmp;
	}

	my $height = height_by_windowscrheight(1, %args);
	$args{-height} = $height;

	my $this = $class->SUPER::new( %args );	
	bless $this, $class;
}

sub get()
{
	my $this = shift;
	return $this->{-pos};
}

sub setpos(;$)
{
	my $this = shift;
	my $pos = shift || 0;
	$this->{-pos} = $pos;	
	$this->draw;
	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;
	
	eval { curs_set(0) }; # not available on every system.
	
        # Return immediately if this object is hidden.
        return $this if $this->hidden;

	# Draw the frame
	$this->SUPER::draw(1);

	# Check bounds for the position.
	$this->{-pos} = $this->{-max} if $this->{-pos} > $this->{-max};
	$this->{-pos} = $this->{-min} if $this->{-pos} < $this->{-min};

	# Compute percentage
	my $perc = ($this->{-pos}-$this->{-min})
		   /($this->{-max}-$this->{-min})*100;

	# Compute the number of blocks to draw. Only draw
	# no blocks or all blocks if resp. the min. or the
	# max. value is set.
	my $blocks = int($perc * $this->screenwidth / 100);
	if ($blocks == 0 
	    and $this->{-pos} != $this->{-min}) { $blocks++ }
	if ($blocks == $this->screenwidth 
	    and $this->{-pos} != $this->{-max}) { $blocks-- }
	
	# Draw center line
	$this->{-windowscr}->addstr(0, 0, "-"x$this->screenwidth)
		if $this->{-showcenterline};

	# Draw blocks.
	$this->{-windowscr}->attron(A_REVERSE);
	$this->{-windowscr}->addstr(0, 0, " "x$blocks);
	$this->{-windowscr}->attroff(A_REVERSE);

	# Draw percentage
	if ($this->{-showpercentage})
	{
		$perc = int($perc); 
		my $str = " $perc% ";
		my $len = length($str);
		my $xpos = int(($this->screenwidth - $len)/2);
		my $revlen = $blocks - $xpos;
		$revlen = 0 if $revlen < 0;
		$revlen = $len if $revlen > $len; 
		my $rev = substr($str, 0, $revlen);
		my $norev = substr($str, $revlen, $len-$revlen);
		$this->{-windowscr}->attron(A_REVERSE);
		$this->{-windowscr}->addstr(0, $xpos, $rev);
		$this->{-windowscr}->attroff(A_REVERSE);
		$this->{-windowscr}->addstr(0, $xpos+$revlen, $norev);
	}

	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;

	return $this;
}


1;

