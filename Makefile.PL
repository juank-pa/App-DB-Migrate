use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Migrate',
    VERSION_FROM => 'lib/Migrate.pm',
    test => { TESTS => 't/*.t t/*/*.t' },
    TEST_REQUIRES => {
        'Test::MockObject' => '0',
        'Test::MockModule' => '0',
        'Test::Trap' => '0',
    },
    PREREQ_PM => {
        'Lingua::EN::Inflexion' => '0',
    },
);
