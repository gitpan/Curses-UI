use ExtUtils::MakeMaker;

WriteMakefile(
        NAME        => 'Curses::UI',
        VERSION     => '0.53',
        DISTNAME    => "Curses-UI",
        dist        => {COMPRESS => 'gzip', SUFFIX => 'gz'},
        test        => {TEST_TYPE => './test.pl'},
);

