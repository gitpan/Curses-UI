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
use Term::ReadKey;
use Curses;

use vars qw(
	@ISA 
	@EXPORT_OK 	
	@EXPORT 
	$VERSION 
	$DEBUG
); 

$VERSION = '1.05';
$DEBUG = 0;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	text_wrap
	scrlength
	split_to_lines
	KEY_ESCAPE	 KEY_SPACE	KEY_TAB
	WORDWRAP	 NO_WORDWRAP
	CONTROLKEYS	 NO_CONTROLKEYS
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
	
	return \@lines;
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

# Contstants for text_wrap()
sub NO_WORDWRAP() { return 1 }
sub WORDWRAP() { return 0 }

sub text_wrap($$;)
{
        # Make $this->text_wrap() possible.
        shift if ref $_[0];
        my ($line, $maxlen, $wordwrap) = @_;
	$wordwrap = WORDWRAP unless defined $wordwrap;
	
	return [""] if $line eq '';

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
		return [$line] if length($line) < $maxlen;
		return ["internal wrap error: wraplength undefined"] 
			unless defined $maxlen;

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
		
	return \@wrapped;
}

# ----------------------------------------------------------------------
# Keyboard input
# ----------------------------------------------------------------------

# Constants:

# Keys that are not defined in curses.h, but which might come in handy.
sub KEY_ESCAPE() { return "\x1b" }
sub KEY_TAB()    { return "\t" }
sub KEY_SPACE()  { return " " }

# Settings for get_key().
sub NO_CONTROLKEYS() { return 0 }
sub CONTROLKEYS() { return 1 }
sub CURSOR_INVISIBLE() { return 0 }
sub CURSOR_VISIBLE() { return 1 }

sub get_key(;$$)
{
	my $this            = shift;
	my $blocktime       = shift || 0;              
	my $controlkeystype = shift || NO_CONTROLKEYS;
	my $cursormode      = shift || CURSOR_INVISIBLE;

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
	my $ESC = KEY_ESCAPE();
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
		# My Sun Solaris box needs this. I have no idea
		# of the portability of this stuff...
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

1;


=pod

=head1 NAME

Curses::UI::Common - Common methods for Curse::UI

=head1 SYNOPSIS

    package MyPackage;

    use Curses::UI::Common;
    use vars qw(@ISA);
    @ISA = qw(Curses::UI::Common);
 

=head1 DESCRIPTION

Curses::UI::Common is a collection of methods that is
shared between Curses::UI classes.




=head1 METHODS

=head2 Various methods

=over 4

=item * B<parent> ( )

Returns the B<-parent> data member.

=item * B<root> ( )

Returns the topmost B<-parent> (the Curses::UI instance).

=item * B<rootscr> ( )

Returns the topmost curses window (the B<-scr> data member
of the Curses::UI instance). 

=item * B<delallwin> ( )

This method will walk through all the data members of the
class intance. Each data member that is a Curses::Window
descendant will be removed. This method is mostly used
in the B<layout> method of widgets to remove all contained
subwidgets before adding them again.

=back


=head2 Text processing

=over 4

=item B<split_to_lines> ( TEXT )

This method will split TEXT into a list of separate lines.
It returns a reference to this list.

=item B<scrlength> ( LINE )

Returns the screenlength of the string LINE. The difference
with the perl function length() is that this method will
expand TAB characters. It is exported by this class and it may
be called as a stand-alone routine.


=item B<text_wrap> ( LINE, LENGTH, WORDWRAP ) 

=item B<WORDWRAP> ( )

=item B<NO_WORDWRAP> ( )

This method will wrap a line of text (LINE) to a 
given length (LENGTH). If the WORDWRAP argument is
true, wordwrap will be enabled (this is the default
for WORDWRAP). It will return a reference to a list
of wrapped lines. It is exported by this class and it may
be called as a stand-alone routine.

The B<WORDWRAP> and B<NO_WORDWRAP> routines will
return the correct value vor the WORDWRAP argument.
These routines are exported by this class.

Example:

    $this->text_wrap($line, 50, NO_WORDWRAP);

=back



=head2 Reading key input

=over 4

=item B<KEY_ESCAPE> ( )

=item B<KEY_TAB> ( )

=item B<KEY_SPACE> ( )

These are a couple of routines that are not defined by the
L<Curses|Curses> module, but which might be useful anyway. 
These routines are exported by this class.

=item B<get_key> ( BLOCKTIME, CONTROLKEYS, CURSOR )

=item B<NO_CONTROLKEYS> ( )

=item B<CONTROLKEYS> ( )

=item B<CURSOR_VISIBLE> ( )

=item B<CURSOR_INVISIBLE> ( )

This method will try to read a key from the keyboard.
It will return the key pressed or -1 if no key was 
pressed. It is exported by this class and it may
be called as a stand-alone routine.

The BLOCKTIME argument can be used to set
the curses halfdelay (the time to wait before the
routine decides that no key was pressed). BLOCKTIME is
given in tenths of seconds. The default is 0 (non-blocking
key read).

If CONTROLKEYS has a true value, the control-keys will 
be handled in the normal way. So a <CTRL+C> will try to
interrupt the program. If it has a false value, the
normal control-keys will be disabled (the terminal will
be set in raw mode).

If CURSOR has a true value, the cursor will be visible
during the key read (only if the terminal supports this
through the curses curs_set call).

The B<CONTROLKEYS> and B<NO_CONTROLKEYS> routines will
return the correct value vor the CONTROLKEYS argument.
The B<CURSOR_VISIBLE> and B<CURSOR_INVISIBLE> routines will
return the correct value vor the CURSOR argument.
These routines are exported by this class.

Example:

    my $key = $this->get_key(
        5, 
        NO_CONTROLKEYS,
        CURSOR_INVISIBLE
    );

=back



=head2 Beep control

=over 4

=item B<beep_on> ( )

This sets the B<-nobeep> data member of the class instance
to a false value.

=item B<beep_off> ( )

This sets the B<-nobeep> data member of the class instance
to a true value.

=item B<dobeep> ( )

This will call the curses beep() routine, but only if
B<-nobeep> is false.

=back




=head1 SEE ALSO

L<Curses::UI|Curses::UI>, 




=head1 AUTHOR

Copyright (c) 2001-2002 Maurice Makaay. All rights reserved.

This package is free software and is provided "as is" without express
or implied warranty. It may be used, redistributed and/or modified
under the same terms as perl itself.

