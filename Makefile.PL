use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Curses::UI',
    VERSION_FROM => 'lib/Curses/UI.pm',
    DISTNAME     => 'Curses-UI',
    PREREQ_PM    => { 
        'Curses'           => 0,
	'Term::ReadKey'    => 0,
    },

    dist         => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    clean        => { FILES => 'MANIFEST.bak' },
);

