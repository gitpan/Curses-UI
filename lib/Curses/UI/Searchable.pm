# ----------------------------------------------------------------------
# Curses::UI::Searchable
#
# (c) 2001-2002 by Maurice Makaay. All rights reserved.
# This file is part of Curses::UI. Curses::UI is free software.
# You can redistribute it and/or modify it under the same terms
# as perl itself.
#
# e-mail: maurice@gitaar.net
# ----------------------------------------------------------------------

package Curses::UI::Searchable;

use strict;
use Curses;
use Curses::UI::Common;
use Curses::UI::SearchEntry;
require Exporter;

use vars qw($VERSION @ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(
	search_forward
	search_backward
	search
	search_next
);
$VERSION = '1.0.0';

sub search_forward()
{
	my $this = shift;
	$this->search("/", +1);
}

sub search_backward()
{
	my $this = shift;
	$this->search("?", -1);
}

sub search()
{
	my $this   = shift;
	my $prompt = shift || ':';
	my $direction   = shift || +1; 

	$this->change_screenheight(-1);
	$this->draw();

	my $querybox = new Curses::UI::SearchEntry(
		-parent   => $this,
		-prompt   => $prompt,
	);

	$querybox->draw;
	$querybox->focus();

	my $query = $querybox->get;
	$querybox->prompt(':');
	$querybox->draw;
	
	my $key;
	if ($query ne '')
	{
		my ($newidx, $wrapped) = 
			$this->search_next($query, $direction);

		KEY: for (;;)
		{
			unless (defined $newidx) {
				$querybox->text('Not found');
			} else {
				$querybox->text($wrapped ? 'Wrapped' : '');
			}
			$querybox->draw;

			$key = -1;
			while ($key eq '-1') 
			{
			   $key = $this->get_key(2, undef, CURSOR_VISIBLE);
			   $this->process_callback;
			   $this->draw(1);
			   $querybox->draw(1);
			   doupdate();
			}

			if ($key eq 'n') { 
				($newidx, $wrapped) = 
					$this->search_next($query, $direction);
			} elsif ($key eq 'N') {
				($newidx, $wrapped) = 
					$this->search_next($query, -$direction);
			} else {
				last KEY;
			}
		}
	}

	# Restore the screenheight.
	$this->change_screenheight(+1);

	return "DO_KEY:$key" if defined $key;
	return $this;
}

sub search_next($$;)
{
	my $this = shift;
	my $query = shift;
	my $direction = shift;
	$direction = ($direction > 0 ? +1 : -1);
	$this->search_get($query, $direction);
}

sub change_screenheight($;)
{
        my $this = shift;
        my $change = shift;

        if ($change < 0)
        {
                # Change the screenheight, so we can fit in the searchline.
                $this->{-sh}--;
                $this->{-yscrpos}++
                        if ($this->{-ypos}-$this->{-yscrpos} == $this->screenheight);
        }
        elsif ($change > 0)
        {
                # Restore the screenheight.
                $this->{-sh}++;
                my $inscreen = ($this->screenheight 
			     - ($this->number_of_lines 
			        - $this->{-yscrpos}));
                while ($this->{-yscrpos} > 0 
		       and $inscreen < $this->screenheight) 
		{
                        $this->{-yscrpos}--;
                        $inscreen = ($this->screenheight 
				  - ($this->number_of_lines 
				     - $this->{-yscrpos}));
                }
        }

	$this->{-search_highlight} = undef;
        $this->layout_content();
}

sub search_get($$;)
{
        my $this      = shift;
        my $query     = shift;
        my $direction = shift || +1;

        my $startpos = $this->{-ypos};
        my $offset = 0;
        my $wrapped = 0;
        for (;;)
        {
                # Find the line position to match.
                $offset += $direction;
                my $newpos = $this->{-ypos} + $offset;

		my $last_idx = $this->number_of_lines - 1;

                # Beyond limits?
                if ($newpos < 0) {
                        $newpos = $last_idx;
                        $offset = $newpos - $this->{-ypos};
                        $wrapped = 1;
                }
                if ($newpos > $last_idx) 
		{
                        $newpos = 0;
                        $offset = $newpos - $this->{-ypos};
                        $wrapped = 1;
                }

                # Nothing found?
                return (undef,undef) if $newpos == $startpos;

                if ($this->getline_at_ypos($newpos) =~ /\Q$query/i)
                {
                        $this->{-ypos} = $newpos;
			$this->{-search_highlight} = $newpos;
                        $startpos = $newpos;
                        $this->layout_content;
                        $this->draw(1);
                        return $newpos, $wrapped;
                        $wrapped = 0;
                }
        }

}



1;

