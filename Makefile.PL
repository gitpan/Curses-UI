use ExtUtils::MakeMaker;

WriteMakefile(
        NAME        => 'Curses::UI',
        VERSION     => '0.54',
        DISTNAME    => "Curses-UI",
	PREREQ_PM   => { 'Curses' => 0, 'Term::ReadKey' => 0},
        dist        => {COMPRESS => 'gzip', SUFFIX => 'gz'},
        test        => {TEST_TYPE => './test.pl'},
);

