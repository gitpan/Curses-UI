package Curses::UI::SearchEntry;

use Curses;
use Curses::UI::Frame; # For height_by_windowscrheight()
use Curses::UI::Container;
use vars qw($VERSION @ISA);
$VERSION = "1.0.0";
@ISA = qw(Curses::UI::Container);

sub new()
{
	my $class = shift;
	my %args = (
		-prompt => '/',
		-x => 0, -y => -1,
		-width => undef,
		-border => 0,
		-sbborder => 0,
		-showlines => 0,	
		@_,
	);
	
        # The windowscr height should be 1.
        $args{-height} = height_by_windowscrheight(1,%args);

	my $this = $class->SUPER::new(%args);

	$this->add('prompt', 'Curses::UI::Label',
		-x => 0, -y => 0, 
		-height => 1, -width => 2,
		-border => 0,
		-text => $this->{-prompt},
	);

	$this->add('entry', 'Curses::UI::TextEntry',
		-x => 1, -y => 0, 
		-height => 1, 
		-border => 0,
		-sbborder => 0,
		-showlines => 0,
		-width => undef,
	)->set_routine('return','LEAVE_CONTAINER');

	$this->layout;
	return $this;
}

sub get()
{
	my $this = shift;
	$this->getobj('entry')->get;
}

sub text()
{
	my $this = shift;
	my $text = shift;
	$this->getobj('entry')->text($text);
}

sub prompt() 
{ 
	my $this = shift;
	my $prompt = shift;
	if (defined $prompt) 
	{
		$prompt = substr($prompt, 0, 1);
		$this->{-prompt} = $prompt;
		$this->getobj('prompt')->text($prompt);
		$this->getobj('prompt')->draw;
		return $this;
	} else {
		return $this->{-prompt};
	}
}

1;

