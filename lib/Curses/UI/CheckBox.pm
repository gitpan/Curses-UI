package Curses::UI::CheckBox;

use strict;
use Curses;
use Curses::UI::Label;
use Curses::UI::Common;
use Curses::UI::Frame;

use vars qw($VERSION @ISA);
$VERSION = '1.0.0';
@ISA = qw(Curses::UI::Frame Curses::UI::Common);

my %routines = (
        'return'   	=> 'RETURN',
        'uncheck'       => \&uncheck,
        'check'      	=> \&check,
        'toggle'      	=> \&toggle,
);

my %bindings = (
        KEY_ENTER()     => 'return',
        "\n"            => 'return',
	KEY_STAB()	=> 'return',
	KEY_BTAB()	=> 'return',
	"\t"		=> 'return',
        ' '             => 'toggle',
        '0'             => 'uncheck',
        'n'             => 'uncheck',
        '1'             => 'check',
        'y'             => 'check',
);

sub new ()
{
	my $class = shift;

	my %myroutines = %routines;
	my %mybindings = %bindings;

	my %args = (
		-parent		 => undef,	# the parent window
		-width		 => undef,	# the width of the checkbox
		-x		 => 0,		# the horizontal position rel. to parent
		-y		 => 0,		# the vertical position rel. to parent
		-checked	 => 0,		# checked or not?
		-label		 => '',		# the label text

		-bindings	 => \%mybindings,
		-routines	 => \%myroutines,

		@_,
	
		-focus		 => 0,
	);

	# The windowscr height should be 1.
	$args{-height} = height_by_windowscrheight(1,%args);
	
	# No width given? Then make the width the same size
	# as the label + checkbox.
	$args{-width} = width_by_windowscrwidth(4 + length($args{-label}),%args)
		unless defined $args{-width};
	
	my $this = $class->SUPER::new( %args );
	$this->layout;

	return bless $this, $class;
}

sub layout()
{
	my $this = shift;

	$this->delallwin;

	$this->SUPER::layout;

	# Create the label on the frame.
	my $label = new Curses::UI::Label(
		-parent   => $this,
		-text     => $this->{-label},
		-x        => 4,
		-y        => 0
	);
	$this->{-labelobject} = $label;

	return $this;
}

sub draw(;$)
{
	my $this = shift;
	my $no_doupdate = shift || 0;

        # Return immediately if this object is hidden.
        return $this if $this->hidden;
		
	# Draw the frame.
	$this->SUPER::draw(1);

	# Draw the label
	$this->{-labelobject}->draw(1);
	
	# Draw the checkbox.
	$this->{-windowscr}->attron(A_BOLD) if $this->{-focus};	
	$this->{-windowscr}->addstr(0, 0, '[ ]');
	$this->{-windowscr}->addstr(0, 1, 'X') if $this->{-checked};
	$this->{-windowscr}->attroff(A_BOLD) if $this->{-focus};	

	$this->{-windowscr}->move(0,1);
	$this->{-windowscr}->noutrefresh();
	doupdate() unless $no_doupdate;

	return $this;
}

sub focus()
{
	my $this = shift;
	$this->generic_focus(
		undef,
		NO_CONTROLKEYS,
		CURSOR_VISIBLE
	);
}

sub uncheck()
{
	my $this = shift;
	$this->{-checked} = 0;
	$this->draw;
}

sub check()
{
	my $this = shift;
	$this->{-checked} = 1;
	$this->draw;
}

sub toggle()
{
	my $this = shift;
	$this->{-checked} = ! $this->{-checked};
	$this->draw;
}

1;

