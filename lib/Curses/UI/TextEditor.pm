# ----------------------------------------------------------------------
# Curses::UI::TextEditor
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::TextEditor;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::Widget;
use Curses::UI::Searchable;

use vars qw($VERSION @ISA);
@ISA = qw(Curses::UI::Widget Curses::UI::Common Curses::UI::Searchable);
$VERSION = '1.12';
	
# Configuration: routine name to subroutine mapping.
my %routines = (
	'return'			=> 'RETURN',
	'undo' 				=> \&undo,
	'paste'				=> \&paste,
	'delete-till-eol'		=> \&delete_till_eol,
	'delete-line'			=> \&delete_line,
	'delete-character'		=> \&delete_character,
	'add-string'			=> \&add_string,
	'clear-line'			=> \&clear_line,
	'backspace'			=> \&backspace,
	'newline'			=> \&newline,
	'toggle-showhardreturns' 	=> \&toggle_showhardreturns,
	'toggle-showoverflow' 		=> \&toggle_showoverflow,
	'toggle-wrapping' 		=> \&toggle_wrapping,
        'cursor-right'                  => \&cursor_right,
        'cursor-left'                   => \&cursor_left,
        'cursor-up'                     => \&cursor_up,
        'cursor-down'                   => \&cursor_down,
        'cursor-pageup'                 => \&cursor_pageup,
        'cursor-pagedown'               => \&cursor_pagedown,
        'cursor-scrlinestart'           => \&cursor_to_scrlinestart,
        'cursor-scrlineend'             => \&cursor_to_scrlineend,
        'cursor-home'                   => \&cursor_to_home,
        'cursor-end'                    => \&cursor_to_end,
        'search-forward'        	=> \&search_forward,
        'search-backward'       	=> \&search_backward,
);

# Configuration: binding to routine name mapping.

my %basebindings = (
	KEY_TAB()			=> 'return',
        KEY_LEFT()                      => 'cursor-left',
        "\cB"                           => 'cursor-left',
        KEY_RIGHT()                     => 'cursor-right',
        "\cF"                           => 'cursor-right',
        KEY_DOWN()                      => 'cursor-down',
        "\cN"                           => 'cursor-down',
        KEY_UP()                        => 'cursor-up',
        "\cP"                           => 'cursor-up',
        KEY_PPAGE()                     => 'cursor-pageup',
        KEY_NPAGE()                     => 'cursor-pagedown',
        KEY_HOME()                      => 'cursor-home',
        KEY_END()                       => 'cursor-end',
        "\cA"                           => 'cursor-scrlinestart',
        "\cE"                           => 'cursor-scrlineend',
	"\cW"				=> 'toggle-wrapping',
	"\cR"				=> 'toggle-showhardreturns',
	"\cT"				=> 'toggle-showoverflow',
);

my %viewbindings = (
        "/"                     	=> 'search-forward',
        "?"                     	=> 'search-backward',
        KEY_SPACE()                     => 'cursor-pagedown',
        "-"                             => 'cursor-pageup',
        "]"                             => 'cursor-pagedown',
        "["                             => 'cursor-pageup',
);

my %editbindings = (
	''				=> 'add-string',
	"\cZ"				=> 'undo',
	KEY_DL()			=> 'delete-line',
	"\cY"				=> 'delete-line',
	"\cX"				=> 'delete-line',
	"\cK"				=> 'delete-till-eol',			
	KEY_DC()			=> 'delete-character',
	"\cV"				=> 'paste',
	"\cU"				=> 'clear-line',
	KEY_BACKSPACE()			=> 'backspace',
	KEY_ENTER()			=> 'newline',
);

# Some viewbindings that should not be available in %bindings;
$viewbindings{'h'} = 'cursor-left';
$viewbindings{'j'} = 'cursor-down';
$viewbindings{'k'} = 'cursor-up';
$viewbindings{'l'} = 'cursor-right';
	

sub new ()
{
	my $class = shift;

	my %args = ( 
		# Parent info
		-parent		=> undef,	  # the parent object
		-callback	=> undef,	  # callback on parent object

		# Position and size
		-x		=> 0,		  # horizontal position (rel. to -window)
		-y		=> 0,		  # vertical position (rel. to -window)
		-width		=> undef,	  # horizontal editsize, undef = stretch
		-height		=> undef,	  # vertical editsize, undef = stretch
		-singleline	=> 0,		  # single line mode or not?

		# Initial state
		-text 		=> '',		  # data
		-pos 		=> 0,		  # cursor position

		# General options
		-border		=> undef,	  # use border?
		-showlines	=> undef,	  # underline lines? (default 1 if border = 0)
		-sbborder	=> undef,	  # square bracket border?
		-undolevels	=> 10,		  # number of undolevels. 0 = infinite
		-maxlength	=> 0,	  	  # the maximum length. 0 = infinite
		-showoverflow	=> 1,		  # show overflow characters.
		-regexp		=> undef,	  # regexp to match the text against
		-toupper	=> 0,		  # convert text to uppercase?
		-tolower	=> 0,		  # convert text to lowercase?
		-homeonreturn   => 0,		  # cursor to homepos on return?
		-vscrollbar	=> 0,		  # show vertical scrollbar
		-hscrollbar	=> 0,		  # show horizontal scrollbar
		-readonly	=> 0,		  # only used as viewer?

		# Single line options
		-password	=> undef,	  # masquerade chars with given char

		# Multiple line options
		-showhardreturns => 0,		  # show hard returns with diamond char?
		-wrapping	 => 0,		  # do wrap?
		-maxlines	 => undef,	  # max lines. undef = infinite
		
		# Bindings
		-routines 	 => {%routines},  # binding routines
		-bindings 	 => {},		  # these are set by readonly()
		
		@_,

		# These need some value for initial layout.
		-scr_lines	 => [],
		-yscrpos	 => 0,
		-xscrpos	 => 0,
		-ypos		 => 0,
		-xpos		 => 0,
	);

	# If initially wrapping is on, then we do not use
	# overflow chars.
	$args{-showoverflow} = 0 if $args{-wrapping};

	# Single line mode? Compute the needed height and set it.
	if ($args{-singleline})
	{
	    my $height = height_by_windowscrheight(1,%args);
	    $args{-height} = $height;
	}
	
	# Create the Widget.
	my $this = $class->SUPER::new( %args );
	bless $this, $class;

	# Check if we should wrap or not.
	$this->{-wrapping} = 0 if $this->{-singleline};

	$this->{-undotext} = [$this->{-text}];
	$this->{-undopos}  = [$this->{-pos}];
	$this->{-xscrpos}  = 0;	# X position for cursor on screen
	$this->{-yscrpos}  = 0; # Y position for cursor on screen
	$this->{-xpos}     = 0;	# X position for cursor in the document
	$this->{-ypos}     = 0; # Y position for cursor in the document

	# Restrict the password character to a single character.
	$this->{-password} = substr($this->{-password}, 0, 1)
		if defined $this->{-password};

	# Single line? Then initial text may only be singleline.
	if ($this->{-singleline} and $this->{-text} =~ /\n/)
	{
		my $lines = $this->split_to_lines($this->{-text});
		$this->{-text} = $lines->[0];
	}

	$this->readonly($this->{-readonly});
	$this->layout_content;

	return $this;
}

sub getrealxpos()
{
	my $this = shift;

	my $offset = $this->{-xscrpos};
	my $length = $this->{-xpos} - $this->{-xscrpos};
	return 0 if $length <= 0;

	my $current_line = $this->{-scr_lines}->[$this->{-ypos}];
	my $before_cursor = substr(
		$current_line,
		$this->{-xscrpos}, 			# Screen's x position
		$this->{-xpos} - $this->{-xscrpos}	# Space up to the cursor
	);

	my $realxpos = scrlength($before_cursor);

	return $realxpos;
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
        
	# Scroll left if we can and the number of visible columns
	# is smaller than the number of available columns in the screen.
	$inscreen = ($this->screenwidth
                     - ($this->number_of_columns - $this->{-xscrpos}));
        while ($this->{-xscrpos} > 0 and $inscreen < $this->screenwidth)
        {
                $this->{-xscrpos}--;
                $inscreen = ($this->screenwidth
                          - ($this->number_of_columns - $this->{-xscrpos}));
        }

	$this->layout_content();
	return $this;
}

sub layout_content()
{
	my $this = shift;
				
	# ----------------------------------------------------------------------
	# Build an array of lines to display and determine the cursor position
	# ----------------------------------------------------------------------

	my $lines_src = $this->split_to_lines($this->{-text});
	foreach (@$lines_src) {$_ .= "\n"}
	$lines_src->[-1] =~ s/\n$/ /;
	
	# No lines available? Then create an array.
	$lines_src = [""] unless @$lines_src;

	# No out of bound values for -pos.
	$this->{-pos} = 0 unless defined $this->{-pos};
	$this->{-pos} = 0 if $this->{-pos} < 0;
	$this->{-pos} = length($this->{-text}) 
		if $this->{-pos} >= length($this->{-text});

	# Do line wrapping if needed and store the lines
	# to display in -scr_lines. Compute the x- and
	# y-position of the cursor in the text.
	my $lines = [];
	my ($xpos, $ypos, $trackpos) = (undef, 0, 0);
	foreach my $line (@$lines_src) 
	{
  	    my $add = [];
	    if ($this->{-wrapping}) {
		$add = $this->text_wrap($line, $this->screenwidth, WORDWRAP);
	    } else {
		$add = [$line];
	    }
	    push @$lines, @$add;
		
	    unless (defined $xpos) 
	    {
	    	foreach (@$add)
	    	{
		    my $newtrackpos = $trackpos + length($_);
		    if ( $this->{-pos} < $newtrackpos )
		    {
			$xpos = length(substr($_, 0, ($this->{-pos}-$trackpos)));	
		    }
		    $trackpos = $newtrackpos;
		    last if defined $xpos;
		    $ypos++;
	    	}
	    }
        }
	
	$this->{-scr_lines} 	= $lines;
	unless ($this->{-readonly})
	{
		$this->{-xpos}		= $xpos;
		$this->{-ypos}		= $ypos;
	}

	# ----------------------------------------------------------------------
	# Handle vertical scrolling of the screen
	# ----------------------------------------------------------------------

	# Scroll down if needed.
	if ( ($this->{-ypos}-$this->{-yscrpos}) >= $this->screenheight ) {
	    $this->{-yscrpos} = $this->{-ypos} - $this->screenheight + 1;
	}

	# Scroll up if needed.
	elsif ( $this->{-ypos} < $this->{-yscrpos} ) {
	    $this->{-yscrpos} = $this->{-ypos};
	}

	# Check bounds.
	$this->{-yscrpos} = 0 if $this->{-yscrpos} < 0;
	$this->{-yscrpos} = @$lines if $this->{-yscrpos} > @$lines;


	# ----------------------------------------------------------------------
	# Handle horizontal scrolling of the screen
	# ----------------------------------------------------------------------

	# If wrapping is enabled, then check for horizontal scrolling.
	# Else make the -xscrpos fixed to 0.
	unless ($this->{-readonly})
	{
	    unless ($this->{-wrapping})
	    {
		my $realxpos = $this->getrealxpos;
		
		# If overflows have to be shown, the cursor may not
		# be set to the first or the last position of the
		# screen.
		my $wrapborder = 
			(not $this->{-wrapping} and $this->{-showoverflow})
			? 1 : 0;
		
		# Scroll left if needed.
		if ($realxpos < $wrapborder) {
			while ($realxpos < ($wrapborder + int($this->screenwidth/3)) 
			       and $this->{-xscrpos} > 0) {
				$this->{-xscrpos}--;
				$realxpos = $this->getrealxpos;
			}
		}
		
		# Scroll right if needed.
		if ($realxpos > ($this->screenwidth - 1 - $wrapborder)) {
			while ($realxpos > 2*int($this->screenwidth/3) ) {
				$this->{-xscrpos}++;
				$realxpos = $this->getrealxpos;
			}
		}
	    }
	    else 
	    {
		$this->{-xscrpos} = 0;
	    }
	} 
			
	# Check bounds.
	$this->{-xscrpos} = 0 if $this->{-xscrpos} < 0;
	$this->{-xscrpos} = $this->{-xpos} if $this->{-xscrpos} > $this->{-xpos};

	# ----------------------------------------------------------------------
	# Layout horizontal scrollbar.
	# ----------------------------------------------------------------------

	if (($this->{-hscrollbar} and not $this->{-wrapping}) or $this->{-readonly})
	{
		my $longest_line = $this->number_of_columns;
		$this->{-hscrolllen} = $longest_line + 1;
		$this->{-hscrollpos} = $this->{-xscrpos};
	} else {
		$this->{-hscrolllen} = 0;
		$this->{-hscrollpos} = 0;
	
	}

	
	# ----------------------------------------------------------------------
	# Layout vertical scrollbar
	# ----------------------------------------------------------------------

	if ($this->{-vscrollbar} or $this->{-readonly})	
	{
		$this->{-vscrolllen} = @{$this->{-scr_lines}};
		$this->{-vscrollpos} = $this->{-yscrpos};
	} else {
		$this->{-vscrolllen} = 0;
		$this->{-vscrollpos} = 0;
	}

	return $this;
}

sub draw_text(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

        # Return immediately if this object is hidden.
        return $this if $this->hidden;

	# Turn on underlines and fill the screen with lines
	# if neccessary.
	if ($this->{-showlines})
	{
		$this->{-windowscr}->attron(A_UNDERLINE);
		for my $y (0..$this->screenheight-1) {
			$this->{-windowscr}->addstr($y, 0, " "x($this->screenwidth));
		}
	}

	# Draw the text.
	for my $id (0 .. $this->screenheight - 1)
	{	
		if (defined $this->{-search_highlight} 
		    and $this->{-search_highlight} == ($id+$this->{-yscrpos})) {
			$this->{-windowscr}->attron(A_REVERSE);
		} else {
			$this->{-windowscr}->attroff(A_REVERSE);
		}

		my $l = $this->{-scr_lines}->[$id + $this->{-yscrpos}];
		if (defined $l)
		{
			# Get the part of the line that is in view.
			my $inscreen = '';
			my $fromxscr = '';
			if ($this->{-xscrpos} < length($l))
			{
				$fromxscr = substr($l, $this->{-xscrpos}, length($l));
				$inscreen = ($this->text_wrap($fromxscr, $this->screenwidth, NO_WORDWRAP))->[0];
			}

			# Masquerading of password fields.
			if ($this->{-singleline} and defined $this->{-password}) {
				# Don't masq the endspace which we
				# added ourselves.
				$inscreen =~ s/\s$//; 
	
				# Substitute characters.
				$inscreen =~ s/[^\n]/$this->{-password}/g;
			}

			# Clear line.
			$this->{-windowscr}->addstr(
				$id, 0, " "x$this->screenwidth);

			# Strip newline and replace by diamond character
			# if the showhardreturns option is on.
			if ($inscreen =~ /\n/)
			{
				$inscreen =~ s/\n//;
				$this->{-windowscr}->addstr($id, 0, $inscreen);
				if ($this->{-showhardreturns})
				{
				    if ($this->root->compat)
				    {
					$this->{-windowscr}->addch($id, scrlength($inscreen),'@');
				    } else {
					$this->{-windowscr}->attron(A_ALTCHARSET);
					$this->{-windowscr}->addch($id, scrlength($inscreen),'`');
					$this->{-windowscr}->attroff(A_ALTCHARSET);
				    }
				}
			} else {
				$this->{-windowscr}->addstr($id, 0, $inscreen);
			}
			
			# Draw overflow characters.
			if (not $this->{-wrapping} and $this->{-showoverflow})
			{
			    $this->{-windowscr}->addch($id, $this->screenwidth-1, '$')
			        if $this->screenwidth < scrlength($fromxscr);
			    $this->{-windowscr}->addch($id, 0, '$')
			        if $this->{-xscrpos} > 0;
			}

		} else {
			last;
		}
	}

	# Move the cursor.
	# Take care of TAB's	
	if ($this->{-readonly}) 
	{
		$this->{-windowscr}->move(
			$this->screenheight-1,
			$this->screenwidth-1
		);
	} else {
		my $l = $this->{-scr_lines}->[$this->{-ypos}];
		my $precursor = substr(
			$l, 
			$this->{-xscrpos},
			$this->{-xpos} - $this->{-xscrpos}
		);

		my $realxpos = scrlength($precursor);
		$this->{-windowscr}->move(
			$this->{-ypos} - $this->{-yscrpos}, 
			$realxpos
		);
	}
	
	$this->{-windowscr}->attroff(A_UNDERLINE) if $this->{-showlines};
	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;
	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

	$this->layout_content;
	$this->SUPER::draw(1);
	$this->draw_text(1);
	doupdate() unless $no_doupdate;

	return $this;
}

sub focus()
{
	my $this = shift;

	$this->show;
	$this->{-focus} = 1;
	$this->draw;

	my ($key, $do_key);
	KEYSTROKE: for(;;)
	{
		$key = defined $do_key 
		     ? $do_key
		     : $this->get_key(
			5, NO_CONTROLKEYS, 
			($this->{-readonly} ? CURSOR_INVISIBLE : CURSOR_VISIBLE)
		       );
		undef $do_key;

		$this->process_callback;
		next if $key eq "-1"; 
		
		# Reset the field that tracks if undoinfo has already
		# been saved or not.
		$this->resetsetundo();

		# Pasting more than one char/line is possible. As long
		# as you do it at once (no other actions in between are
		# allowed).
		if (defined $this->{-prevkey} and $this->{-prevkey} ne $key) {
			$this->do_new_pastebuffer(1); 
		} else {
			$this->do_new_pastebuffer(0); 
		}

		# Backup, in case illegal input is done.
		my %backup = %{$this};

		# Process bindings. 
		my $ret = $this->process_bindings($key);
		unless (ref $ret)
		{
			if ($ret =~ /^DO_KEY:(.*)$/)
			{
				$do_key = $1;
				next KEYSTROKE;
			}

			# Return to the parent widget. Set the cursor position
			# to the startposition if -homeonreturn and 
			# release focus.
			if ($this->{-homeonreturn}) 
			{
				$this->cursor_to_home;
				$this->layout_content;
			}
			
			$this->{-focus} = 0;
			$this->draw;
			return ($ret, $key);
		}
	
		# To upper or to lower?
		if ($this->{-toupper}) {
			$this->{-text} = uc $this->{-text};
		} elsif ($this->{-tolower}) {
			$this->{-text} = lc $this->{-text};
		}

		# Check for illegal input.
		my $is_illegal = 0;
		if ($this->{-maxlength}) {
		    $is_illegal = 1 if length($this->{-text}) > $this->{-maxlength};
		}	
		if (not $is_illegal and defined $this->{-maxlines}) {
		    my $lines = $this->split_to_lines($this->{-text});
		    $is_illegal = 1 if @$lines > $this->{-maxlines};
		}
		if (not $is_illegal and defined $this->{-regexp}) {
		    my $e = '$is_illegal = (not $this->{-text} =~ ' . $this->{-regexp} . ')';
		    eval $e; 
		}
		
		if ($is_illegal)	# Illegal input? Then restore and bail out.
		{
			while (my ($k,$v) = each %backup) {
				$this->{$k} = $v;
			}
			$this->dobeep();
		} else {		# Legal input? Redraw the text.
			$this->draw;
		}
	
		# Save the current key.
		$this->{-prevkey} = $key;
	}
}

sub add_string($;)
{
	my $this = shift;
	my $ch = shift;

	$this->set_undoinfo;

	PASTED: for (;;)
	{
		my $binding = $this->{-bindings}->{$ch};	
		$binding = 'add-string' unless defined $binding;

		if ($ch eq "-1") {
			last PASTED;
		} elsif ( $binding eq 'add-string' ) {
			substr($this->{-text}, $this->{-pos}, 0) = $ch;
			$this->{-pos}++;
		} elsif ( $binding eq 'newline' ) {
			$this->process_bindings($ch);
		}

		# Multiple characters at input? This is probably a
		# pasted string. Get it and process it. Don't do
		# special bindings, but only add-string and newline.
		$ch = $this->get_key(0, NO_CONTROLKEYS, CURSOR_VISIBLE);
	}

	$this->layout_content;
	$this->set_curxpos;
	return $this;
}

sub toggle_showoverflow()
{
	my $this = shift;
	$this->{-showoverflow} = ! $this->{-showoverflow};
	return $this;
}

sub toggle_wrapping()
{
	my $this = shift;
	return $this->dobeep if $this->{-singleline};
	$this->{-wrapping} = ! $this->{-wrapping};
	$this->layout;
	return $this;
}

sub toggle_showhardreturns()
{
	my $this = shift;
	return $this->dobeep if $this->{-singleline};
	$this->{-showhardreturns} = ! $this->{-showhardreturns};
	return $this;
}

sub cursor_right()
{
	my $this = shift;
	
	# Handle cursor_right for read only mode. 
	if ($this->{-readonly})
	{
		return $this->dobeep
			unless defined $this->{-hscrolllen};

		return $this->dobeep 
		    if $this->{-xscrpos} 
			>= $this->{-hscrolllen} - $this->screenwidth;

		$this->{-xscrpos} += 1;
		$this->{-hscrollpos} = $this->{-xscrpos};
		$this->{-xpos} = $this->{-xscrpos};

		return $this;
	}

	if ($this->{-pos} == length($this->{-text})) {
		$this->dobeep;
	} else {
		$this->{-pos}++;
	}
	$this->layout_content;
	$this->set_curxpos;
	return $this;
}

sub cursor_left()
{
	my $this = shift;
	
	# Handle cursor_left for read only mode. 
	if ($this->{-readonly})
	{
		return $this->dobeep if $this->{-xscrpos} <= 0;
		$this->{-xscrpos} -= 1;
		$this->{-xpos} = $this->{-xscrpos};
		return $this;
	}

	if ($this->{-pos} <= 0) {
		$this->dobeep;
	} else {
		$this->{-pos}--;
	}
	$this->layout_content;
	$this->set_curxpos;
	return $this;
}
			
sub set_curxpos()
{
	my $this = shift;
	$this->{-curxpos} = $this->{-xpos};
	return $this;
}
			
sub cursor_up(;$)
{
	my $this = shift;
	shift; # stub for bindings handling.
	my $amount = shift || 1;
	
	return $this->dobeep if $this->{-singleline};
	
	# Handle cursor_up for read only mode. 
	if ($this->{-readonly})
	{
		return $this->dobeep if $this->{-yscrpos} <= 0;
		$this->{-yscrpos} -= $amount;		
		$this->{-yscrpos} = 0 if $this->{-yscrpos} < 0;
		$this->{-ypos} = $this->{-yscrpos};
		return $this;
	}


	my $maymove = $this->{-ypos};
	return $this->dobeep unless $maymove;
	$amount = $maymove if $amount > $maymove;

	my $l = $this->{-scr_lines};
	$this->cursor_to_scrlinestart;
	$this->{-ypos} -= $amount;
	while ($amount)
	{
		my $idx = $this->{-ypos} + $amount - 1;
		my $line = $l->[$idx];
		my $line_length = length($line);
		$this->{-pos} -= $line_length;
		$amount--;
	}
	$this->cursor_to_curxpos;

	return $this;
}

sub cursor_pageup()
{
	my $this = shift;

	return $this->dobeep if $this->{-singleline};
	$this->cursor_up(undef, $this->screenheight - 1);

	return $this;
}
			
sub cursor_down($;)
{
	my $this = shift;
	shift; # stub for bindings handling.
	my $amount = shift || 1;
	
	return $this->dobeep if $this->{-singleline};
	
	# Handle cursor_down for read only mode. 
	if ($this->{-readonly})
	{
		my $max = @{$this->{-scr_lines}} - $this->screenheight;
		return $this->dobeep 
		    if $this->{-yscrpos} >= $max;

		$this->{-yscrpos} += $amount;		
		$this->{-yscrpos} = $max if $this->{-yscrpos} > $max;
		$this->{-ypos} = $this->{-yscrpos};
		return $this;
	}
	
	my $l = $this->{-scr_lines};
	my $maymove = (@$l-1) - $this->{-ypos};
	return $this->dobeep unless $maymove;
	$amount = $maymove if $amount > $maymove;
	
	$this->cursor_to_scrlinestart;
	$this->{-ypos} += $amount;
	while ($amount)
	{	
		my $idx = $this->{-ypos} - $amount;
		my $line = $l->[$idx];
		my $line_length = length($line);
		$this->{-pos} += $line_length;
		$amount--;
	}
	$this->cursor_to_curxpos;

	return $this;
}

sub cursor_pagedown()
{
	my $this = shift;
	return $this->dobeep if $this->{-singleline};
	
	$this->cursor_down(undef, $this->screenheight - 1); 

	return $this;
}

sub cursor_to_home()
{
	my $this = shift;
		
	if ($this->{-readonly})
	{
		$this->{-xscrpos} = $this->{-xpos} = 0;
		$this->{-yscrpos} = $this->{-ypos} = 0;
		return $this;
	}
	
	$this->{-pos} = 0;
	$this->set_curxpos;
	return $this;
}

sub cursor_to_end()
{
	my $this = shift;

	if ($this->{-readonly})
	{
		$this->{-xscrpos} = $this->{-xpos} = 0;
		$this->{-yscrpos} = $this->{-ypos} =
			$this->{-vscrolllen}-$this->screenheight;
		return $this;
	}
	
	$this->{-pos} = length($this->{-text});
	$this->set_curxpos;
	return $this;
}

sub cursor_to_scrlinestart()
{
	my $this = shift;
	# Key argument is set if called from binding.
	my $from_binding = shift; 
	
	if ($this->{-readonly})
	{
		$this->{-xscrpos} = $this->{-xpos} = 0;
		return $this;
	}

	$this->{-pos} -= $this->{-xpos};
	$this->{-xpos} = 0;
	$this->set_curxpos if defined $from_binding;
	return $this;
}
			
sub cursor_to_scrlineend()
{
	my $this = shift;
	my $from_binding = shift;
	
	if ($this->{-readonly})
	{
		$this->{-xscrpos} = $this->{-xpos} = 
			$this->{-hscrolllen} - $this->screenwidth ;
		return $this;
	}

	my $newpos = $this->{-pos};
	my $l = $this->{-scr_lines};
	my $len = length($l->[$this->{-ypos}]) - 1;
	$newpos += $len - $this->{-xpos};
	$this->{-pos} = $newpos;
	$this->layout_content;
	$this->set_curxpos if defined $from_binding;
	return $this;
}

sub cursor_to_linestart()
{
	my $this = shift;

	# Move cursor back, until \n is found. That is
	# the previous line. Then go one position to the
	# right to find the start of the line.
	my $newpos = $this->{-pos};
	for(;;)	{
		last if $newpos <= 0;
		$newpos--;
		last if substr($this->{-text}, $newpos, 1) eq "\n";
	}	
	$newpos++ unless $newpos == 0;	
	$newpos = length($this->{-text}) if $newpos > length($this->{-text});
	$this->{-pos} = $newpos;
	$this->layout_content;
	return $this;
}

sub cursor_to_curxpos()
{
	my $this = shift;
	my $right = $this->{-curxpos};
	$right = 0 unless defined $right;
	my $len = length($this->{-scr_lines}->[$this->{-ypos}]) - 1;
	if ($right > $len) { $right = $len }
	$this->{-pos} += $right;
	$this->layout_content;
	return $this;
}

sub clear_line()
{
	my $this = shift;
	$this->cursor_to_linestart;
        $this->delete_till_eol;
	return $this;
}

sub delete_line()
{
	my $this = shift;
	return $this->dobeep if $this->{-singleline};

	my $len = length($this->{-text});
	if ($len == 0)
	{
		$this->dobeep;
		return $this;
	}

	$this->beep_off
	     ->cursor_to_linestart
	     ->delete_till_eol
	     ->cursor_left
	     ->delete_character
	     ->cursor_right
	     ->cursor_to_linestart
	     ->set_curxpos
	     ->beep_on;
	return $this;
}

sub delete_till_eol()
{
	my $this = shift;
			
	$this->set_undoinfo;
	
	# Cursor is at newline. No action needed.
	return $this if substr($this->{-text}, $this->{-pos}, 1) eq "\n";

	# Find the next newline. Delete the content up to that newline.
	my $pos = $this->{-pos};
	for(;;)
	{
		$pos++;	
		last if $pos >= length($this->{-text});
		last if substr($this->{-text}, $pos, 1) eq "\n";
	}

	$this->add_to_pastebuffer(
		substr($this->{-text}, $this->{-pos}, $pos - $this->{-pos})
	);
	substr($this->{-text}, $this->{-pos}, $pos - $this->{-pos}, '');
	return $this;
}
			
sub delete_character()
{
	my $this = shift;
	shift(); # stub for bindings handling.
	my $is_backward = shift;
	
	if ($this->{-pos} >= length($this->{-text})) {
		$this->dobeep;	
	} else {
		$this->set_undoinfo;
		$this->add_to_pastebuffer(
			substr($this->{-text}, $this->{-pos}, 1),
			$is_backward	
		);
		substr($this->{-text}, $this->{-pos}, 1, ''),
	}
	return $this;
}

sub backspace()
{
	my $this = shift;
		
	if ($this->{-pos} <= 0) {
		$this->dobeep;
	} else {
		$this->set_undoinfo;
		$this->{-pos}--;
		$this->delete_character(undef,1);
		$this->layout_content;
		$this->set_curxpos;
	}
	return $this;
}

sub newline()
{
	my $this = shift;
	return $this->dobeep if $this->{-singleline};
	$this->add_string("\n");
}

sub resetsetundo() { shift()->{-didsetundo} = 0}
sub didsetundo()   { shift()->{-didsetundo} }

sub set_undoinfo()
{
	my $this = shift;

	return $this if $this->didsetundo;

	push @{$this->{-undotext}}, $this->{-text};
	push @{$this->{-undopos}}, $this->{-pos};

	my $l = $this->{-undolevels};
	if ($l and @{$this->{-undotext}} > $l) {
		splice(@{$this->{-undotext}}, 0, @{$this->{-undotext}}-$l, ());
		splice(@{$this->{-undopos}}, 0, @{$this->{-undopos}}-$l, ());
	}

	$this->{-didsetundo} = 1;
	return $this;
}

sub undo()
{
	my $this = shift;

	if (@{$this->{-undotext}})
	{
		my $text = pop @{$this->{-undotext}};
		my $pos = pop @{$this->{-undopos}};
		$this->{-text} = $text;
		$this->{-pos} = $pos;
	}
	return $this;
}

sub do_new_pastebuffer(;$)
{
	my $this = shift;
	my $value = shift;
	$this->{-do_new_pastebuffer} = $value 	
		if defined $value;
	return $this->{-do_new_pastebuffer};
}

sub clear_pastebuffer()
{
	my $this = shift;
	$this->{-pastebuffer} = '';
	return $this;
}

sub add_to_pastebuffer($;)
{
	my $this = shift;
	my $add = shift;
	my $is_backward = shift || 0;

	$this->clear_pastebuffer if $this->do_new_pastebuffer;
	if ($is_backward) {
		$this->{-pastebuffer} = $add . $this->{-pastebuffer};
	} else {		
		$this->{-pastebuffer} .= $add;
	}
	$this->do_new_pastebuffer(0);
	return $this;
}

sub paste()
{
	my $this = shift;
	
	if ($this->{-pastebuffer} ne '') {
		$this->add_string($this->{-pastebuffer});
	}	
	return $this;
}

sub readonly($;)
{
	my $this = shift;
	my $readonly = shift;

	$this->{-readonly} = $readonly;
	
	if ($readonly)
	{
		my %mybindings = (
			%basebindings,
			%viewbindings
		);
		$this->{-bindings} = \%mybindings;
	} else {
		my %mybindings = (
			%basebindings,
			%editbindings
		);
		$this->{-bindings} = \%mybindings;
	} 

	return $this;
}

sub get() {shift()->text}
sub text()
{
	my $this = shift;
	my $text = shift;
	if (defined $text) 
	{
		$this->{-text} = $text;
		$this->layout_content;
		$this->draw(1);
		return $this;
	}
	return $this->{-text};
}

# ----------------------------------------------------------------------
# Routines for search support
# ----------------------------------------------------------------------

sub number_of_lines()   { @{shift()->{-scr_lines}} }
sub number_of_columns()   
{ 
	my $this = shift;
	my $columns = 0;
	foreach (@{$this->{-scr_lines}}) {
		$columns = length($_) 
			if length($_) > $columns;
	}
	return $columns;
}
sub getline_at_ypos($;) { shift()->{-scr_lines}->[shift()] }

1;

__END__


=pod

=head1 NAME

Curses::UI::TextEditor - Create and manipulate texteditor widgets

=head1 SYNOPSIS

    use Curses::UI;
    my $cui = new Curses::UI;
    my $win = $cui->add('window_id', 'Window');

    my $editor = $win->add(
        'myeditor', 'Editor',
        -vscrollbar => 1,
        -wrapping   => 1,
    );

    $editor->focus();
    my $text = $editor->get();


=head1 DESCRIPTION

Curses::UI::TextEditor is a widget that can be used to create 
a couple of different kinds of texteditors. These are:

=over 4

=item * B<multi-line texteditor>

This is a multi-line text editor with features like word-wrapping,
maximum textlength and undo.

=item * B<single-line texteditor>

The texteditor can be created as a single-line editor. 
Most of the features of the default texteditor will remain.
Only the multi-line specific options will not be
available (like moving up and down in the text).

=item * B<read only texteditor>

The texteditor can also be used in read only mode.
In this mode, the texteditor will function as a text
viewer. The user can walk through the text and 
search trough it.

=back

See exampes/demo-Curses::UI::TextEditor in the distribution
for a short demo of these.



=head1 STANDARD OPTIONS

B<-parent>, B<-x>, B<-y>, B<-width>, B<-height>, 
B<-pad>, B<-padleft>, B<-padright>, B<-padtop>, B<-padbottom>,
B<-ipad>, B<-ipadleft>, B<-ipadright>, B<-ipadtop>, B<-ipadbottom>,
B<-title>, B<-titlefullwidth>, B<-titlereverse>

For an explanation of these standard options, see 
L<Curses::UI::Widget|Curses::UI::Widget>.




=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item * B<-text> < SCALAR>

This sets the initial text for the widget to SCALAR.

=item * B<-pos> < SCALAR >

This sets the initial cursor position for the widget
to SCALAR. BB<-pos> represents the character index within
B<-text>. By default this option is set to 0.

=item * B<-readonly> < BOOLEAN >

The texteditor widget will be created as a read only 
texteditor (which is also called a textviewer) if 
BOOLEAN is true. By default BOOLEAN is false.

=item * B<-singleline> < BOOLEAN >

The texteditor widget will be created as a single line
texteditor (which is also called a textentry) if 
BOOLEAN is true. By default BOOLEAN is false.

=item * B<-wrapping> < BOOLEAN >

If BOOLEAN is true, the texteditor will have text wrapping
enabled. By default BOOLEAN is false.

=item * B<-showlines> < BOOLEAN >

If BOOLEAN is set to a true value, each editable line
in the editor will show a line to type on. By default
BOOLEAN is set to false.

=item * B<-maxlength> < SCALAR >

This sets the maximum allowed length of the text to SCALAR.
By default SCALAR is set to 0, which means that the text
may be infinitely long.

=item * B<-maxlines> < SCALAR >

This sets the maximum allowed number of lines for the text 
to SCALAR. By default SCALAR is set to 0, which means that 
the text may contain an infinite number of lines.

=item * B<-password> < CHARACTER >

Instead of showing the real text in the widget, every
character of the text will (on the screen) be replaced
by CHARACTER. So creating a standard password field
can be done by setting:

    -password => '*'

=item * B<-maxlength> < SCALAR >

This sets the maximum allowed length of the text to SCALAR.
By default SCALAR is set to 0, which means that the text
may be infinitely long.

=item * B<-regexp> < REGEXP >

If characters are added to the texteditor, the new text
will be matched against REGEXP. If the text does not match,
the change will be denied. This can for example be used to
force digit-only input on the texteditor:

    -regexp => '/^\d*$/'

=item * B<-undolevels> < SCALAR >

This option determines how many undolevels should be kept
in memory for the texteditor widget. By default 10 levels
are kept. If this value is set to 0, the number of levels
is infinite.

=item * B<-showoverflow> < BOOLEAN >

If BOOLEAN is true, the text in the texteditor will be
padded by an overflow character ($) if there is text
outside the screen (like 'pico' does). By default 
BOOLEAN is true.

=item * B<-showhardreturns> < BOOLEAN >

If BOOLEAN is true, hard returns will be made visible
by a diamond character. By default BOOLEAN is false.

=item * B<-homeonreturn> < BOOLEAN >

If BOOLEAN is set to a true value, the cursor will move
to the start of the text if the widget loses focus.

=item * B<-toupper> < BOOLEAN >

If BOOLEAN is true, all entered text will be converted
to uppercase. By default BOOLEAN is false.

=item * B<-tolower> < BOOLEAN >

If BOOLEAN is true, all entered text will be converted
to lowercase. By default BOOLEAN is false.

=back




=head1 METHODS

=over 4

=item * B<new> ( HASH )

=item * B<layout> ( )

=item * B<draw> ( BOOLEAN )

=item * B<focus> ( )

These are standard methods. See L<Curses::UI::Widget|Curses::UI::Widget> 
for an explanation of these.

=item * B<text> ( [SCALAR] )

If SCALAR is defined, this will set the text of the widget to SCALAR.
To see the change, the widget needs to be redrawn by the B<draw> method.
If SCALAR is not defined, this method will return the current contents
of the texteditor.

=item * B<get> ( )

This method will call B<text> without any arguments, so it
will return the contents of the texteditor.

=back




=head1 DEFAULT BINDINGS

There are different sets of bindings for each mode in which
this widget can be used. 



=head2 All modes (editor, single line and read only)



=over 4

=item * <B<tab>>

Call the 'return' routine. This will have the widget 
loose its focus.

=item * <B<cursor-left>, <B<CTRL+B>>

Call the 'cursor-left' routine: move the
cursor one position to the left.

=item * <B<cursor-right>, <B<CTRL+F>>

Call the 'cursor-right' routine: move the
cursor one position to the right.

=item * <B<cursor-down>, <B<CTRL+N>>

Call the 'cursor-down' routine: move the
cursor one line down.

=item * <B<cursor-up>, <B<CTRL+P>>

Call the 'cursor-up' routine: move the
cursor one line up.

=item * <B<page-up>>

Call the 'cursor-pageup' routine: move the
cursor to the previous page.

=item * <B<page-down>>

Call the 'cursor-pagedown' routine: move
the cursor to the next page.

=item * <B<home>>

Call the 'cursor-home' routine: go to the
start of the text. 

=item * <B<end>>

Call the 'cursor-end' routine: go to the
end of the text. 

=item * <B<CTRL+A>>

Call the 'cursor-scrlinestart' routine: move the
cursor to the start of the current line.

=item * <B<CTRL+E>>

Call the 'cursor-scrlineend' routine: move the
cursor to the end of the current line.

=item * <B<CTRL+W>>

Call the 'toggle-wrapping' routine: toggle the
-wrapping option of the texteditor.

=item * <B<CTRL+R>>

Call the 'toggle-showhardreturns' routine: toggle the
-showhardreturns option of the texteditor.

=item * <B<CTRL+T>>

Call the 'toggle-showoverflow' routine: toggle the
-showoverflow option of the texteditor.

=back 



=head2 All edit modes (all but read only mode)



=over 4

=item * <B<CTRL+Y>>, <B<CTRL+X>>

Call the 'delete-line' routine: Delete the current
line.

=item * <B<CTRL+K>>

Call the 'delete-till-eol' routine: delete the text
from the current cursor position up to the end of
the current line.

=item * <B<CTRL+U>>

Call the 'clear-line' routine: clear the 
current line and move the cursor to the
start of this line.

=item * <B<CTRL+D>>

Call the 'delete-character' routine: delete the 
character that currently is under the cursor.

=item * <B<backspace>>

Call the 'backspace' routine: delete the character
this is before the current cursor position.

=item * <B<CTRL+Z>>

Call the 'undo' routine: undo the last change to
the text, up to B<-undolevels> levels.

=item * <B<CTRL+V>>

Call the 'paste' routine: this will paste the 
last deleted text at the current cursor position.

=item * <B<any other key>>

Call the 'add-string' routine: the character
will be inserted in the text at the current
cursor position.

=back



=head2 Only for the read only mode



=over 4

=item * <B<h>> 

Call the 'cursor-left' routine: move the
cursor one position to the left.

=item * <B<l>> 

Call the 'cursor-right' routine: move the
cursor one position to the right.

=item * b<<k>> 

Call the 'cursor-up' routine: move the
cursor one line up.

=item * b<<j>> 

Call the 'cursor-down' routine: move the
cursor one line down.

=item * <B<space>>, <B<]>> 

Call the 'cursor-pagedown' routine: move
the cursor to the next page.

=item * <B<->>, <B<[>>

Call the 'cursor-pageup' routine: move the
cursor to the previous page.

=item * <B</>>

Call the 'search-forward' routine. This will make a 'less'-like
search system appear in the textviewer. A searchstring can be
entered. After that the user can search for the next occurance
using the 'n' key or the previous occurance using the 'N' key.

=item * <B<?>>

Call the 'search-backward' routine. This will do the same as
the 'search-forward' routine, only it will search in the
opposite direction.

=back




=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 
L<Curses::UI::TextViewer|Curses::UI:TextViewer>
L<Curses::UI::TextEntry|Curses::UI:TextEntry>
L<Curses::UI::Widget|Curses::UI::Widget>, 
L<Curses::UI::Common|Curses::UI:Common>




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

=end

