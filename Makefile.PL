use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'DB-Migrate',
    VERSION_FROM => 'lib/App/DB/Migrate.pm',
    test => { TESTS => 't/*.t t/*/*.t t/*/*/*.t' },
    MIN_PERL_VERSION => '5.10.1',
    TEST_REQUIRES => {
        'Test::MockObject' => '0',
        'Test::MockModule' => '0',
        'Test::Trap' => '0',
        'DBD::SQLite' => '0',
    },
	EXE_FILES => [
		'bin/migrate',
		'script/add.tl',
		'script/config.pl',
		'script/create.tl',
		'script/drop.tl',
		'script/remove.tl',
	],
    PREREQ_PM => {
        'Lingua::EN::Inflexion' => '0',
        'DBI' => '1.641',
    },
);
