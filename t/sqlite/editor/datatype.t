use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Trap;

use Migrate::SQLite::Editor::Datatype;

our %datatypes = (
    INT                 => 'integer',
    INTEGER             => 'integer',
    TINYINT             => 'integer',
    SMALLINT            => 'integer',
    BIGINT              => 'bigint',
    'UNSIGNED BIG INT'  => 'bigint',
    INT2                => 'integer',
    INT8                => 'integer',
    CHARACTER           => 'char',
    VARCHAR             => 'string',
    'VARYING CHARACTER' => 'string',
    NCHAR               => 'char',
    'NATIVE CHARACTER'  => 'char',
    NVARCHAR            => 'string',
    TEXT                => 'text',
    CLOB                => 'text',
    BLOB                => 'binary',
    REAL                => 'float',
    DOUBLE              => 'float',
    'DOUBLE PRECISION'  => 'float',
    NUMERIC             => 'numeric',
    DECIMAL             => 'decimal',
    BOOLEAN             => 'boolean',
    DATE                => 'date',
    DATETIME            => 'datetime',
);

subtest 'new creates a new datatype' => sub {
    isa_ok(Migrate::SQLite::Editor::Datatype->new('INT'), 'Migrate::SQLite::Editor::Datatype');
};

subtest 'new creates a new datatype as long as datatype is valid' => sub {
    for my $type (keys %datatypes) {
        ok(Migrate::SQLite::Editor::Datatype->new($type));
        ok(Migrate::SQLite::Editor::Datatype->new(uc($type)));
    }
};

subtest 'new fails if datatype is invalid' => sub {
    trap { Migrate::SQLite::Editor::Datatype->new('any') };
    like($trap->die, qr/^Invalid datatype: any/);
};

subtest 'new supports undef datatypes' => sub {
    ok(ref(Migrate::SQLite::Editor::Datatype->new));
};

subtest 'new creates a new datatype as long as datatype is valid' => sub {
    for my $type (keys %datatypes) {
        ok(Migrate::SQLite::Editor::Datatype->new($type));
        ok(Migrate::SQLite::Editor::Datatype->new(uc($type)));
    }
};

subtest 'is SQLizable' => sub {
    isa_ok(Migrate::SQLite::Editor::Datatype->new('INT'), 'Migrate::SQLizable');
};

subtest 'native_name returns the construction time name' => sub {
    for my $type (keys %datatypes) {
        is(Migrate::SQLite::Editor::Datatype->new($type)->native_name, $type);
    }
};

subtest 'native_name returns empty string for undef datatypes' => sub {
    is(Migrate::SQLite::Editor::Datatype->new->native_name, '');
};

subtest 'name returns a mapped datatype name' => sub {
    for my $type (keys %datatypes) {
        is(Migrate::SQLite::Editor::Datatype->new($type)->name, $datatypes{$type});
    }
};

subtest 'name returns "string" for undef datatypes' => sub {
    is(Migrate::SQLite::Editor::Datatype->new->name, 'string');
};

subtest 'to_sql returns the datatype SQL' => sub {
    for my $type (keys %datatypes) {
        is(Migrate::SQLite::Editor::Datatype->new($type)->to_sql, $type);
        is(Migrate::SQLite::Editor::Datatype->new(uc($type))->to_sql, uc($type));
    }
};

subtest 'to_sql returns the datatype SQL with attributes' => sub {
    for my $type (keys %datatypes) {
        is(Migrate::SQLite::Editor::Datatype->new($type, 12, 34)->to_sql, "$type(12,34)");
        is(Migrate::SQLite::Editor::Datatype->new(uc($type), 3, 45)->to_sql, uc($type).'(3,45)');
    }
};

subtest 'to_sql an empty string for undef datatypes' => sub {
    is(Migrate::SQLite::Editor::Datatype->new(undef)->to_sql, '');
    is(Migrate::SQLite::Editor::Datatype->new('', 6)->to_sql, '');
    is(Migrate::SQLite::Editor::Datatype->new(undef, 12, 34)->to_sql, '');
};

done_testing();
