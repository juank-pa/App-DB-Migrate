use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Migrate',
    VERSION_FROM => 'lib/Migrate.pm',
    test => { TESTS => 't/*.t t/*/*.t' },
);
