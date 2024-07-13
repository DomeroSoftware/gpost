use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'gpost',
    VERSION_FROM  => 'lib/gpost.pm',
    PREREQ_PM     => {
        'JSON'       => 0,
        'XML::Simple' => 0,
        'gfio'       => 0,
        'gerr'       => 0,
    },
    AUTHOR        => 'Domero Software <domerosoftware@gmail.com>',
    ABSTRACT      => 'Gideon CGI GET POST Engine',
    LICENSE       => 'perl',
    PL_FILES      => {},
    MIN_PERL_VERSION => '5.10.0',
);

