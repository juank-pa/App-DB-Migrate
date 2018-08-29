use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use App::DB::Migrate::SQLite::Datatype;

my $datatypes = {
    string      => 'VARCHAR',
    char        => 'CHARACTER',
    text        => 'TEXT',
    integer     => 'INTEGER',
    bigint      => 'BIGINT',
    float       => 'FLOAT',
    decimal     => 'DECIMAL',
    numeric     => 'NUMERIC',
    date        => 'DATE',
    time        => 'TIME',
    datetime    => 'DATETIME',
    binary      => 'BLOB',
    boolean     => 'BOOLEAN',
};

subtest 'new creates a Datatype' => sub {
    my $def = App::DB::Migrate::SQLite::Datatype->new('string');
    isa_ok($def, 'App::DB::Migrate::SQLite::Datatype');
    isa_ok($def, 'App::DB::Migrate::Datatype');
};

subtest 'datatypes returns SQLite datatype mappings' => sub {
    is_deeply(App::DB::Migrate::SQLite::Datatype->datatypes, $datatypes);
};

done_testing();
