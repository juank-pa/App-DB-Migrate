use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use Migrate::SQLite::Editor::Util qw(unquote);

use Migrate::SQLite::Index;

my $constraint = new Test::MockModule('Migrate::Config');
$constraint->mock('config', { dsn => 'dbi:SQLite:sample' });

subtest 'new creates a new Index object' => sub {
    my $idx = Migrate::SQLite::Index->new('table', 'col1');
    isa_ok($idx, 'Migrate::SQLite::Index');
    isa_ok($idx, 'Migrate::Index');
};

subtest 'rename renames the index' => sub {
    my $idx = Migrate::SQLite::Index->new('table_name', ['col1']);
    is($idx->name, 'idx_table_name_col1');
    $idx->rename('new_name');
    is($idx->name, 'new_name');
};

subtest 'remove_column removes a column from the column list' => sub {
    my $idx = Migrate::SQLite::Index->new('table_name', ['col1', 'col2']);
    $idx->remove_column('col1');
    is_deeply($idx->columns, ['col2']);
};

subtest 'remove_column does nothing if columns does not exist' => sub {
    my $idx = Migrate::SQLite::Index->new('table_name', ['col1', 'col2']);
    $idx->remove_column('col3');
    is_deeply($idx->columns, ['col1', 'col2']);
};

subtest 'rename_column does a column if it exists' => sub {
    my $idx = Migrate::SQLite::Index->new('table_name', ['col1', 'col2']);
    $idx->rename_column('col2', 'colx');
    is_deeply($idx->columns, ['col1', 'colx']);
};

subtest 'has_column returns true if an index has column' => sub {
    my $idx = Migrate::SQLite::Index->new('table_name', ['col1', 'col2']);
    ok($idx->has_columns);
};

subtest 'has_column returns false if an index does not have any column' => sub {
    my $idx = Migrate::SQLite::Index->new('table_name', ['col1']);
    $idx->remove_column('col1');
    ok(!$idx->has_columns);
};

done_testing();
