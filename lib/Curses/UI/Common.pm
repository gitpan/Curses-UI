# ----------------------------------------------------------------------
# Curses::UI::Common
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Common;

use strict;
use Carp qw(confess);
use Term::ReadKey;
use Curses;

use vars qw(
	@ISA 
	@EXPORT_OK 	
	@EXPORT 
	$VERSION 
	$DEBUG
); 

$VERSION = '1.0.4';
$DEBUG = 0;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	mws_wrap
	scrlength
	split_to_lines
	KEY_ESCAPE
	WORDWRAP	NO_WORDWRAP
	CONTROLKEYS	NO_CONTROLKEYS
	CURSOR_INVISIBLE CURSOR_VISIBLE
);

# ----------------------------------------------------------------------
# Misc. routines
# ----------------------------------------------------------------------

sub parent()
{
	my $this = shift;
	$this->{-parent};
}

sub root()
{
	my $this = shift;
	my $root = $this;
        while (defined $root->{-parent}->{-scr}) {
                $root = $root->{-parent};
        }
	return $root;
}

sub rootscr()
{
	my $this = shift;
	return $this->root->{-scr};
}

sub beep_on()  { my $this = shift; $this->{-nobeep} = 0; return $this }
sub beep_off() { my $this = shift; $this->{-nobeep} = 1; return $this }
sub dobeep()
{
	my $this = shift;
	beep() unless $this->{-nobeep};
	return $this;
}

sub process_callback()
{
	my $this = shift;
	if (ref $this->{-callback} eq 'CODE') {
		$this->{-callback}->($this);
	}
	return $this;
}

# Delete all Curses::Window objects from $this.
# This is used in the layout routines to easily
# get rid of all created windows.
#
sub delallwin()
{
        my $this = shift;

	my @delete = ();
	my %didit  = ();
        while (my ($id,$val) = each %{$this}) 
	{
            next unless ref $val;
            eval { # in case $val is no object
                if ($val->isa('Curses::Window')) 
		{
			if (not defined $didit{$val}) 
			{
				delwin($val);
				$didit{$val} = 1;
			}
                        push @delete, $id;
                }
            };
        }

	foreach my $id (@delete) 
	{ 
		delete $this->{$id} 
	}

        return $this;
}

# ----------------------------------------------------------------------
# "Constants"
# ----------------------------------------------------------------------

sub NO_WORDWRAP() { return 1 }
sub WORDWRAP() { return 0 }
sub NO_CONTROLKEYS() { return 0 }
sub CONTROLKEYS() { return 1 }
sub CURSOR_INVISIBLE() { return 0 }
sub CURSOR_VISIBLE() { return 1 }

sub KEY_ESCAPE() { return "\x1b" }

# ----------------------------------------------------------------------
# Text processing
# ----------------------------------------------------------------------

sub split_to_lines($;)
{
	# Make $this->split_to_lines() possible.
	shift if ref $_[0];
	my $text = shift;

        # Break up the text in lines. IHATEBUGS is
        # because a split with /\n/ on "\n\n\n" would
        # return zero result :-(
        my @lines = split /\n/, $text . "IHATEBUGS";
        $lines[-1] =~ s/IHATEBUGS$//g;
	
	return @lines;
}

sub scrlength($;)
{
        # Make $this->scrlength() possible.
        shift if ref $_[0];
	my $line = shift;

	return 0 unless defined $line; 

	my $scrlength = 0;
	for (my $i=0; $i < length($line); $i++)	
	{
		my $chr = substr($line, $i, 1);
		$scrlength++;
		if ($chr eq "\t") {
			while ($scrlength%8) {
				$scrlength++;
			}
		}
	}
	return $scrlength;	
}

sub mws_wrap($$;)
{
        # Make $this->mws_wrap() possible.
        shift if ref $_[0];
        my ($line, $maxlen, $wordwrap) = @_;
	$wordwrap = WORDWRAP unless defined $wordwrap;
	
	return ("") if $line eq '';

	my @wrapped = ();
	my $len = 0;
	my $wrap = '';

	# Special wrapping is needed if the line contains tab
	# characters. These should be expanded to the TAB-stops.
	if ($line =~ /\t/)
	{
		CHAR: for (my $i = 0; $i <= length($line); $i++)
		{
			my $nextchar = substr($line, $i, 1);
			### last CHAR unless defined $nextchar and $nextchar ne '';

			# Find the length of the string in case the
			# next character is added.
			my $newlen = $len + 1;
			if ($nextchar eq "\t") { while($newlen%8) { $newlen++ } }

			# Would that go beyond the end of the available width?
			if ($newlen > $maxlen)
			{
				if ($wordwrap == WORDWRAP 
				    and $wrap =~ /^(.*)([\s])(\S+)$/)
				{
					push @wrapped, $1 . $2;
					$wrap = $3;
					$len = scrlength($wrap) + 1;
				} else {
					$len = 1;
					push @wrapped, $wrap;
					$wrap = '';
				}
			} else {
				$len = $newlen;
			}
			$wrap .= $nextchar;
		}
		push @wrapped, $wrap if defined $wrap;

	# No tab characters in the line? Then life gets a bit easier. We can 
	# process large chunks at once.
	} else {
		my $idx = 0;

		# Line shorter than allowed? Then return immediately.
		return ($line) if length($line) < $maxlen;

		CHUNK: while ($idx < length($line))
		{
			my $next = substr($line, $idx, $maxlen);
			if (length($next) < $maxlen)
			{
				push @wrapped, $next;
				last CHUNK;
			}
			elsif ($wordwrap == WORDWRAP)
			{
				my $space_idx = rindex($next, " ");
				if ($space_idx == -1 or $space_idx == 0)
				{
					push @wrapped, $next;
					$idx += $maxlen;
				} else {
					push @wrapped, substr($next, 0, $space_idx + 1);
					$idx += $space_idx + 1;
				}
			} else {
				push @wrapped, $next;
				$idx += $maxlen;
			}	
		}
	}
		
	return @wrapped;
}

# ----------------------------------------------------------------------
# Keyboard input
# ----------------------------------------------------------------------

sub get_key(;$$)
{
	my $this = shift;
	my $blocktime = shift || 0;
	my $controlkeystype = shift || 0;
	my $cursormode = shift || 0;

	# Set terminal mode.
	$controlkeystype ? cbreak() : raw(); 
	noecho();

	# eval, because not every system might have
	# this function available.
	eval { curs_set($cursormode) };

	my $key;
	if (defined $this->{-windowscr})
	{
		$blocktime 
		    ? halfdelay($blocktime) 
		    : $this->{-windowscr}->nodelay(1);
		$this->{-windowscr}->keypad(1);
		$key = $this->{-windowscr}->getch();
	} else {
		$blocktime 
		    ? halfdelay($blocktime) 
		    : nodelay(1);
		keypad(1);
		getch();
	}

	# ------------------------------------ #
	# Did the screen resize?               #
	# ------------------------------------ #

	# The last resize signal should be received more than a
	# second ago. This mechanism is used to catch window 
	# managers that send a whole bunch of signals to the
	# application if the screen resizes. Only the last one
	# will count.
	
	if ($::mws_resizing and ($::mws_resizetime <= (time()-1)))
	{
		$::mws_resizing = 0;
		$this->root->layout_from_scratch;
		$this->root->rebuild_from_scratch;
		$this->draw;
	}
	
        # ------------------------------------ #
        #  Hacks for broken termcaps / curses  #
        # ------------------------------------ #

        $key = KEY_BACKSPACE if (
                ord($key) == 127
                or $key eq "\cH"
        );

        $key = KEY_DC if (
                $key eq "\c?"
		or $key eq "\cD"
        );

	$key = KEY_ENTER if (
		$key eq "\n" 
		or $key eq "\cM"
	);

	# Catch ESCape sequences.  
	my $ESC = "\x1b";
	if ($key eq $ESC) 
	{ 
		$key .= $this->{-windowscr}->getch();

		# Only ESC pressed?
		$key = $ESC if $key eq "${ESC}-1" 
			    or $key eq "${ESC}${ESC}";
		return $key if $key eq $ESC;
		
		# Not only a single ESC? 
		# Then get extra keypresses.
		$key .= $this->{-windowscr}->getch();
		while ($key =~ /\[\d+$/) {
			$key .= $this->{-windowscr}->getch() 
		}

		# Function keys.
		# My Sun Solaris box needs this.
		if ($key =~ /\[(\d+)\~/)
		{
			my $digit = $1;
			if ($digit >= 11 and $digit <= 15) {
				$key = KEY_F($digit-10);
			} elsif ($digit >= 17 and $digit <= 21) {
				$key = KEY_F($digit-11);
			}
		}
		
		$key = KEY_HOME if (
			$key eq $ESC . "OH" 
			or $key eq $ESC . "[7~"
			or $key eq $ESC . "[1~"
		);
	
		$key = KEY_DL if (
			$key eq $ESC . "[2K"
		);

		$key = KEY_END if (
			$key eq $ESC . "OF" 
			or $key eq $ESC . "[4~"
		);

		$key = KEY_PPAGE if (
			$key eq $ESC . "[5~"
		);

		$key = KEY_NPAGE if (
			$key eq $ESC . "[6~"
		);
	}

	# ----------#
	# Debugging #
	# ----------#

	if ($DEBUG and $key ne "-1")
	{
		my $k = $key;
		my @k = split //, $k;
		foreach (@k) { $_ = ord($_) }
		$k =~ s/$ESC/<esc>/g;
		$k =~ s/\c/<ctrl>/g;
		print STDERR "GRAB KEY DEBUGGER:\n"
			   . "--------------------------\n"
			   . "KEY: $k " . KEY_F(10) . " OCT: "
			   . ($k =~ /^\d\d\d$/ ? sprintf("%o", $k) : "")
			   . "\n"
			   . "ORD: @k\n"
			   . "--------------------------\n";
	}

        return $key;
}

# ----------------------------------------------------------------------
# Bindings
# ----------------------------------------------------------------------

sub clear_binding($;)
{
        my $this = shift;
        my $binding = shift;
        my @delete = ();
        while (my ($k,$v) = each %{$this->{-bindings}}) {
                push @delete, $k if $v eq $binding;
        }
        foreach (@delete) {
                delete $this->{-bindings}->{$_};
        }
        return $this;
}

sub set_routine($$;)
{
	my $this = shift;
	my $binding = shift;
	my $routine = shift;
	$this->{-routines}->{$binding} = $routine;
	return $this;
}

sub set_binding($@;)
{
        my $this = shift;
        my $routine = shift;
        my @keys = @_;

	confess "$routine: no such routine"
		unless defined $this->{-routines}->{$routine};
        foreach my $key (@keys) {
                $this->{-bindings}->{$key} = $routine;
        }

        return $this;
}

sub process_bindings($;)
{
	my $this = shift;
	my $key = shift;
	
	# Find the binding to use.
	my $binding = $this->{-bindings}->{$key};
	if (not defined $binding) {
		# Check for default routine.
		$binding = $this->{-bindings}->{''}; 
	}
	
	if (defined $binding)
	{
		# Find the routine to call.
		my $routine = $this->{-routines}->{$binding};
		if (defined $routine) 
		{
			if (ref $routine eq 'CODE')
			{
				my $return = $routine->($this, $key);
				return $return;
			} else {
				return $routine;
			}
		} else {
			confess "No routine defined for "
			  . "keybinding \"$binding\"!";
		}

	# No binding?
	} else {
		return $this;
	}
}

# ----------------------------------------------------------------------
# Generic focus and draw
# ----------------------------------------------------------------------

sub generic_focus($$;)
{
	my $this 	 	= shift;
	my $callback_time	= shift;
	my $control_keys 	= shift;
	my $cursor_visible 	= shift;
	my $pre_key_callback	= shift;

	$this->show;
	$callback_time = 5 
		unless defined $callback_time;

	# The callback routine to call before a key
	# is grabbed (e.g. for layouting the screen).
	$pre_key_callback = sub {} 
		unless defined $pre_key_callback
		   and ref $pre_key_callback eq 'CODE';

	my $do_key;
        for (;;)
        {
		$pre_key_callback->($this);

                $this->{-focus} = 1;
                $this->draw();

                # Grab a key or use the predefined key.
                my $key = defined $do_key 
		        ? $do_key
			: $this->get_key(
				$callback_time,
				$control_keys,
				$cursor_visible
			  );
		undef $do_key;

		# Do callback if wanted.
                $this->process_callback;

		# No key pressed? Then retry grabbing one.
                next if $key eq '-1';

		# Process keybinding.
                my $return = $this->process_bindings($key);

		# If $return is something like DO_KEY:<...>, then
		# execute this key as if it was read from the
		# keyboard.
		if (defined $return and $return =~ /^DO_KEY\:(.*)$/)
		{
			$do_key = $1; 
			next;
		}
	
		# Return if keybinding returned a non-reference
		# value or a CODE reference. Else the next
		# key will be grabbed.
                elsif (not ref $return or ref $return eq 'CODE') 
		{
                        $this->{-focus} = 0;
                        $this->draw;
                        return (wantarray ? ($return, $key) : $return);
                } 
        }
}

sub hidden() { shift()->{-hidden} }
sub hide()   { shift()->{-hidden} = 1 }
sub show()   { shift()->{-hidden} = 0 }

1;
