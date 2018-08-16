use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Test::Trap;
use MockStringifiedObject;
use Migrate::Dbh qw(get_dbh);

use Migrate::SQLite::Editor;

my $constraint = new Test::MockModule('Migrate::Config');
$constraint->redefine('config', { dsn => 'dbi:SQLite:sample' });

sub get_table {
    return Test::MockObject->new;
}

my $table_sql = 'CREATE TABLE test (id INTEGER PRIMARY KEY AUTOINCREMENT, col, col2)';
my $index_sql = 'CREATE INDEX idx_test_col ON test(col)';

get_dbh->do('DROP TABLE IF EXISTS test') // die('Could not drop sample table');
get_dbh->do($table_sql) // die('Could not create test table');
get_dbh->do($index_sql) // die('Could not create test index');

get_dbh->do('CREATE TABLE IF NOT EXISTS test2(id)') // die('Could not create test2 table');
get_dbh->do('CREATE INDEX IF NOT EXISTS test_index ON test2(id)') // die('Could not create test2 index');

subtest 'imports parse_table and parse_index from Parser' => sub {
    use Migrate::SQLite::Editor::Parser;
    is(\&Migrate::SQLite::Editor::Parser::parse_table, \&Migrate::SQLite::Editor::parse_table);
    is(\&Migrate::SQLite::Editor::Parser::parse_index, \&Migrate::SQLite::Editor::parse_index);
};

subtest 'edit_table finds and parses a table by name' => sub {
    my $mock_table = Test::MockObject->new->set_false('set_indexes');
    my $parsed_sql;
    my $editor = Test::MockModule->new('Migrate::SQLite::Editor');
    $editor->redefine('parse_table', sub { $parsed_sql = shift; $mock_table });

    my $table = Migrate::SQLite::Editor::edit_table('test');
    is($table, $mock_table);
    is($parsed_sql, $table_sql);
};

subtest 'edit_table finds and parses the table indexes' => sub {
    my $mock_index = Test::MockObject->new;
    my $parsed_sql;
    my $editor = Test::MockModule->new('Migrate::SQLite::Editor');
    $editor->redefine('parse_index', sub { $parsed_sql = shift; $mock_index });

    my $table = Migrate::SQLite::Editor::edit_table('test');
    is(scalar @{ $table->{indexes} }, 1);
    is($table->{indexes}->[0], $mock_index);
    is($parsed_sql, $index_sql);
};

subtest 'edit_table uses given dbh' => sub {
    my @sql;
    my $first = 1;
    my $dbh = Test::MockObject->new
        ->mock('selectall_arrayref', sub {
            push(@sql, splice(@_, 1));
            $first--? [[$table_sql]] : [[$index_sql]]
        });

    my $table = Migrate::SQLite::Editor::edit_table('testx', $dbh);
    is_deeply(\@sql, [
        "SELECT sql FROM sqlite_master WHERE type='table' AND tbl_name=?", undef, 'testx',
        "SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=?", undef, 'testx'
    ]);
};

subtest 'edit_table fails if there is no table with that name' => sub {
    trap { Migrate::SQLite::Editor::edit_table('testx') };
    like($trap->die, qr/^Could not find table testx/);
};

subtest 'edit_table fails if dbh fails' => sub {
    my $dbh = Test::MockObject->new
        ->mock('selectall_arrayref', sub { eval { die 'Custom error' }; undef });
    trap { Migrate::SQLite::Editor::edit_table('testx', $dbh) };
    like($trap->die, qr/^Error querying for table testx\nCustom error/);
};

subtest 'index_by_name finds and parses a table index by name' => sub {
    my $mock_index = Test::MockObject->new;
    my $parsed_sql;
    my $editor = Test::MockModule->new('Migrate::SQLite::Editor');
    $editor->redefine('parse_index', sub { $parsed_sql = shift; $mock_index });

    my $index = Migrate::SQLite::Editor::index_by_name('test_index');
    is($index, $mock_index);
    is($parsed_sql, 'CREATE INDEX test_index ON test2(id)');
};

subtest 'index_by_name uses given dbh' => sub {
    my @sql;
    my $first = 1;
    my $dbh = Test::MockObject->new
        ->mock('selectall_arrayref', sub {
            push(@sql, splice(@_, 1));
            [[$index_sql]];
        });

    my $table = Migrate::SQLite::Editor::index_by_name('test_idx', $dbh);
    is_deeply(\@sql, [
        "SELECT sql FROM sqlite_master WHERE type='index' AND name=?", undef, 'test_idx',
    ]);
};

subtest 'index_by_name fails if there is no index with that name' => sub {
    trap { Migrate::SQLite::Editor::index_by_name('any') };
    like($trap->die, qr/^Could not find index any/);
};

subtest 'index_by_name fails if dbh fails' => sub {
    my $dbh = Test::MockObject->new
        ->mock('selectall_arrayref', sub { eval { die 'Custom error' }; undef });
    trap { Migrate::SQLite::Editor::index_by_name('test_idx', $dbh) };
    like($trap->die, qr/^Error querying for index test_idx\nCustom error/);
};

subtest 'rename_index returns the required SQL to rename an index' => sub {
    my @sql = Migrate::SQLite::Editor::rename_index('test_index', 'foo');
    is_deeply(\@sql, [
        'DROP INDEX "test_index"',
        'CREATE INDEX "foo" ON "test2" ("id")',
    ]);
};

subtest 'rename_index fails if there is no index with that name' => sub {
    trap { Migrate::SQLite::Editor::rename_index('any', 'foo') };
    like($trap->die, qr/^Could not find index any/);
};

subtest 'rename_index fails if dbh fails' => sub {
    my $dbh = Test::MockObject->new
        ->mock('selectall_arrayref', sub { eval { die 'Custom error' }; undef });
    trap { Migrate::SQLite::Editor::rename_index('test_idx', 'foo', $dbh) };
    like($trap->die, qr/^Error querying for index test_idx\nCustom error/);
};

done_testing();
