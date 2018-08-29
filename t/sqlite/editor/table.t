use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Test::Trap;
use MockStringifiedObject;

use App::DB::Migrate::SQLite::Editor::Table;

my $constraint = new Test::MockModule('App::DB::Migrate::Config');
$constraint->mock('config', { dsn => 'dbi:SQLite:sample' });

my $column = Test::MockModule->new('App::DB::Migrate::SQLite::Editor::Column');
$column->redefine('new', sub { get_column($_[1]) });

sub get_column {
    my $name = shift;
    return MockStringifiedObject
        ->new("COL<$name>")
        ->mock('name', sub { $name });
}

sub get_fk {
    my ($name, $column) = @_;
    return Test::MockObject->new
        ->mock('name', sub { $name })
        ->mock('column', sub { $column });
}

sub get_index {
    my $name = shift;
    return MockStringifiedObject
        ->new("CREATE IDX<$name>")
        ->mock('name', sub { $name });
}

subtest 'new creates a new editor table object' => sub {
    isa_ok(App::DB::Migrate::SQLite::Editor::Table->new('any'), 'App::DB::Migrate::SQLite::Editor::Table');
};

subtest 'new fails if table name is undef' => sub {
    trap { App::DB::Migrate::SQLite::Editor::Table->new() };
    like($trap->die, qr/^Table name needed/);
};

subtest 'new creates an unchanged table' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('table');
    ok(!$tb->has_changed);
};

subtest 'postfix returns the table postfix' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'post fix');
    is($tb->postfix, 'post fix');
};

subtest 'columns returns the table columns' => sub {
    my @columns = map { get_column($_) } ('col1', 'col2');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', undef, @columns);
    is(scalar @{ $tb->columns }, 2);
    is($tb->columns->[0], $columns[0]);
    is($tb->columns->[1], $columns[1]);
};

subtest 'column_names returns the table column names' => sub {
    my @columns = map { get_column($_) } ('col1', 'col"2');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', undef, @columns);
    is(scalar @{ $tb->columns }, 2);
    is_deeply([$tb->column_names], ['col1', 'col"2']);
};

subtest 'name returns the table name' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname');
    is($tb->name, 'tname');
};

subtest 'rename changes the table name' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname');
    $tb->rename('new_name');
    is($tb->name, 'new_name');
};

subtest 'set_indexes sets the indexes associated to this table' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname');
    my @indexes = map { get_index('tname') } ('col1', 'col"2');
    $tb->set_indexes(@indexes);
    is(scalar @{ $tb->indexes }, 2);
    is($tb->indexes->[0], $indexes[0]);
    is($tb->indexes->[1], $indexes[1]);
};

subtest 'to_sql returns a CREATE TABLE SQL when no changes have been made' => sub {
    my $dt = App::DB::Migrate::SQLite::Editor::Datatype->new('VARCHAR');
    my @columns = map { get_column($_) } ('col1', 'col2');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('t"name', 'options', @columns);
    is($tb->to_sql, 'CREATE TABLE "t""name" (COL<col1>,COL<col2>) options');
};

subtest 'to_sql generated SQL steps to perform change if markes as changes' => sub {
    my $column = get_column('col"2');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('t"name', 'options', $column);
    $tb->set_indexes(get_index('index_name'));
    $tb->set_changed(1);
    is_deeply(
        [$tb->to_sql],
        [
            'CREATE TABLE "_t""name(clone)" (COL<col"2>) options',
            'INSERT INTO "_t""name(clone)" ("col""2") SELECT "col""2" FROM "t""name"',
            'DROP TABLE "t""name"',
            'ALTER TABLE "_t""name(clone)" RENAME TO "t""name"',
            'CREATE IDX<index_name>'
        ]
    );
    ok($tb->has_changed);
};

subtest 'imports Parser parse_column' => sub {
    use App::DB::Migrate::SQLite::Editor::Parser;
    is(\&App::DB::Migrate::SQLite::Editor::Parser::parse_column, \&App::DB::Migrate::SQLite::Editor::Table::parse_column);
};

subtest 'add_raw_column parses and adds a column to the table' => sub {
    my $table = Test::MockModule->new('App::DB::Migrate::SQLite::Editor::Table');
    my $column = get_column('col2');
    my $sql;
    $table->redefine('parse_column' => sub { $sql = $_[0]; $column });

    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', 'col');
    my $res = $tb->add_raw_column('column SQL');

    ok($res);
    is($sql, 'column SQL');
    is($tb->columns->[1], $column);
};

subtest 'add_raw_column marks the table as changed' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', 'col');
    $tb->add_raw_column('column');
    ok($tb->has_changed);
};

subtest 'to_sql generated SQL steps to add a column and previous indexes' => sub {
    my $column = get_column('col2');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $column);
    $tb->set_indexes(get_index('index_name'));
    $tb->add_raw_column('new_column INT');
    is_deeply(
        [$tb->to_sql],
        [
            'CREATE TABLE "_tname(clone)" (COL<col2>,COL<new_column>) options',
            'INSERT INTO "_tname(clone)" ("col2") SELECT "col2" FROM "tname"',
            'DROP TABLE "tname"',
            'ALTER TABLE "_tname(clone)" RENAME TO "tname"',
            'CREATE IDX<index_name>'
        ]
    );
};

subtest 'remove_columns fails if column does not exist' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', get_column('test'));
    trap { $tb->remove_columns('c1') };
    like($trap->die, qr/^Column c1 not found in table tname/);
};

subtest 'remove_columns removes one or more columns' => sub {
    my @columns = map { get_column($_) } qw(col1 col2 col3);
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', @columns);
    my $res = $tb->remove_columns(qw(col1 col3));
    ok($res);
    is(scalar @{ $tb->columns }, 1);
    is($tb->columns->[0], $columns[1]);
};

subtest 'remove_columns removes columns from indexes' => sub {
    my @columns = map { get_column($_) } qw(col1 col2 col3);
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', @columns);
    my $removed_column;
    my $index = get_index('my_index')
        ->mock('remove_column', sub { $removed_column = $_[1] })
        ->set_true('has_columns');
    $tb->set_indexes($index);

    $tb->remove_columns(qw(col2));
    is(scalar @{ $tb->indexes }, 1);
    is($tb->indexes->[0], $index);
    is($removed_column, 'col2');
};

subtest 'remove_columns removes indexes if there are no more columns remaining in index' => sub {
    my @columns = map { get_column($_) } qw(col1 col2 col3);
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', @columns);
    my @indexes = map {
        my $idx = $_;
        get_index($idx)
            ->set_true('remove_column')
            ->mock('has_columns', sub { $idx eq 'index2' });
    } qw(index1 index2);
    $tb->set_indexes(@indexes);

    $tb->remove_columns(qw(col3));
    is(scalar @{ $tb->indexes }, 1);
    is($tb->indexes->[0], $indexes[1]);
};

subtest 'remove_columns marks the table as changed' => sub {
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', get_column('col'));
    $tb->remove_columns('col');
    ok($tb->has_changed);
};

subtest 'to_sql returns SQL sequences to remove columns' => sub {
    my @columns = map { get_column($_) } qw(col1 col2 col3 col4);
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', @columns);
    my @indexes = map {
        my $idx = $_;
        get_index($idx)
            ->set_true('remove_column')
            ->mock('has_columns', sub { $idx ne 'index2' });
    } qw(index1 index2 index3);
    $tb->set_indexes(@indexes);

    $tb->remove_columns(qw(col2 col4));

    is_deeply(
        [$tb->to_sql],
        [
            'CREATE TABLE "_tname(clone)" (COL<col1>,COL<col3>) options',
            'INSERT INTO "_tname(clone)" ("col1","col3") SELECT "col1","col3" FROM "tname"',
            'DROP TABLE "tname"',
            'ALTER TABLE "_tname(clone)" RENAME TO "tname"',
            'CREATE IDX<index1>',
            'CREATE IDX<index3>',
        ]
    );
};

subtest 'add_foreign_key changes table if column was successfully changed' => sub {
    my $col = get_column('test')
        ->mock('add_foreign_key', sub { $_[0]->{fk} = $_[1]; 1 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $fk = get_fk(undef, 'test');
    my $res = $tb->add_foreign_key($fk);
    ok($res);
    ok($tb->has_changed);
    is($col->{fk}, $fk);
};

subtest 'add_foreign_key does not change table if column was not changed' => sub {
    my $col = get_column('test')
        ->mock('add_foreign_key', sub { $_[0]->{fk} = $_[1]; 0 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $fk = get_fk(undef, 'test');
    my $res = $tb->add_foreign_key($fk);
    ok(!$res);
    ok(!$tb->has_changed);
    is($col->{fk}, $fk);
};

subtest 'add_foreign_key fails if column not found' => sub {
    my $col = get_column('test');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $fk = get_fk(undef, 'c1');
    trap { $tb->add_foreign_key($fk) };
    like($trap->die, qr/^Column c1 not found in table tname/);
};

subtest 'remove_foreign_key changes table if column was successfully changed' => sub {
    my $col = get_column('test')
        ->mock('has_constraint_named', sub { $_[0]->{name} = $_[1]; 1 })
        ->set_true('remove_foreign_key');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $fk = get_fk('fk_name', 'test');
    my $res = $tb->remove_foreign_key($fk);
    ok($res);
    ok($tb->has_changed);
    is($col->{name}, 'fk_name');
};

subtest 'remove_foreign_key does not change table if column was not changed' => sub {
    my $col = get_column('test')
        ->mock('has_constraint_named', sub { $_[0]->{name} = $_[1]; 1 })
        ->mock('remove_foreign_key', sub { 0 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $fk = get_fk('fk_name', 'test');
    my $res = $tb->remove_foreign_key($fk);
    ok(!$res);
    ok(!$tb->has_changed);
    is($col->{name}, 'fk_name');
};

subtest 'remove_foreign_key fails if column not found' => sub {
    my $col = get_column('test')
        ->mock('has_constraint_named', sub { $_[0]->{name} = $_[1]; 0 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $fk = get_fk('fk_name', 'c1');
    trap { $tb->remove_foreign_key($fk) };
    like($trap->die, qr/^Column with foreign key not found/);
    is($col->{name}, 'fk_name');
};

subtest 'rename_column changes table if column was changed' => sub {
    my $col = get_column('test')
        ->mock('rename', sub { $_[0]->{new_name} = $_[1]; 1 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->rename_column('test', 'new_col');
    ok($res);
    ok($tb->has_changed);
    is($col->{new_name}, 'new_col');
};

subtest 'rename_column renames indexes columns' => sub {
    my $col = get_column('test')->set_true('rename');
    my $index = get_index('my_index')
        ->mock('rename_column', sub { $_[0]->{params} = [ splice(@_, 1) ] });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    $tb->set_indexes($index);
    $tb->rename_column('test', 'new_col');
    is_deeply($index->{params}, ['test', 'new_col']);
};

subtest 'rename_column does not change table if column is not changed' => sub {
    my $col = get_column('test')
        ->mock('rename', sub { $_[0]->{new_name} = $_[1]; 0 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->rename_column('test', 'new_col');
    ok(!$res);
    ok(!$tb->has_changed);
    is($col->{new_name}, 'new_col');
};

subtest 'rename_column fails if column not found' => sub {
    my $col = get_column('test');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    trap { $tb->rename_column('col1', 'col2') };
    like($trap->die, qr/^Column col1 not found in table tname/);
};

subtest 'to_sql returns SQL representing column renames' => sub {
    my @columns = map { get_column($_) } qw(col1 col"2);
    $columns[1]->mock('rename',
        sub {
            my $name = $_[1];
            $_[0]->{string} = "COL<$name>";
            $_[0]->mock('name', sub { $name });
        }
    );
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', @columns);
    my @indexes = map {
        my $idx = $_;
        get_index($idx)
            ->set_true('rename_column');
    } qw(index1 index2);
    $tb->set_indexes(@indexes);
    $tb->rename_column('col"2', 'new"col');

    is_deeply(
        [$tb->to_sql],
        [
            'CREATE TABLE "_tname(clone)" (COL<col1>,COL<new"col>) options',
            'INSERT INTO "_tname(clone)" ("col1","new""col") SELECT "col1","col""2" FROM "tname"',
            'DROP TABLE "tname"',
            'ALTER TABLE "_tname(clone)" RENAME TO "tname"',
            'CREATE IDX<index1>',
            'CREATE IDX<index2>',
        ]
    );
};

subtest 'imports Factory column' => sub {
    use App::DB::Migrate::Factory;
    is(\&App::DB::Migrate::Factory::column, \&App::DB::Migrate::SQLite::Editor::Table::column);
};

subtest 'change_column changes table if column was changed' => sub {
    my $table = Test::MockModule->new('App::DB::Migrate::SQLite::Editor::Table');
    my $column = get_column('col2');
    my (@col_params, $sql);
    $table->redefine('column' => sub { @col_params = @_; 'Test SQL' });
    $table->redefine('parse_column' => sub { $sql = $_[0]; $column });

    my $col = get_column('test');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->change_column('test', 'integer', { opts => 1 });
    ok($res);
    ok($tb->has_changed);
    is($tb->columns->[0], $column);
    is($sql, 'Test SQL');
    is_deeply(\@col_params, ['test', 'integer', { opts => 1 }]);
};

subtest 'change_column changes table if column was changed (omit datatype)' => sub {
    my $table = Test::MockModule->new('App::DB::Migrate::SQLite::Editor::Table');
    my $column = get_column('col2');
    my (@col_params, $sql);
    $table->redefine('column' => sub { @col_params = @_; 'Test SQL' });
    $table->redefine('parse_column' => sub { $sql = $_[0]; $column });

    my $col = get_column('test');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->change_column('test', { opts => 1 });
    ok($res);
    ok($tb->has_changed);
    is($tb->columns->[0], $column);
    is($sql, 'Test SQL');
    is_deeply(\@col_params, ['test', 1, { opts => 1 }]);
};

subtest 'change_column fails if column not found' => sub {
    my $col = get_column('test');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    trap { $tb->change_column('col1', undef) };
    like($trap->die, qr/^Column col1 not found in table tname/);
};

subtest 'change_column_default changes table if column was changed' => sub {
    my $col = get_column('test')
        ->mock('change_default', sub { $_[0]->{default} = $_[1]; 1 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->change_column_default('test', 45);
    ok($res);
    ok($tb->has_changed);
    is($col->{default}, 45);
};

subtest 'change_column_default does not change table if column is not changed' => sub {
    my $col = get_column('test')
        ->mock('change_default', sub { $_[0]->{default} = $_[1]; 0 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->change_column_default('test', 45);
    ok(!$res);
    ok(!$tb->has_changed);
    is($col->{default}, 45);
};

subtest 'change_column_default fails if column not found' => sub {
    my $col = get_column('test');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    trap { $tb->change_column_default('col1', 45) };
    like($trap->die, qr/^Column col1 not found in table tname/);
};

subtest 'change_column_null changes table if column was changed' => sub {
    my $col = get_column('test')
        ->mock('change_null', sub { $_[0]->{null} = $_[1]; 1 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->change_column_null('test', 'any');
    ok($res);
    ok($tb->has_changed);
    is($col->{null}, 'any');
};

subtest 'change_column_null does not change table if column is not changed' => sub {
    my $col = get_column('test')
        ->mock('change_null', sub { $_[0]->{null} = $_[1]; 0 });
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    my $res = $tb->change_column_null('test', 'any');
    ok(!$res);
    ok(!$tb->has_changed);
    is($col->{null}, 'any');
};

subtest 'change_column_null fails if column not found' => sub {
    my $col = get_column('test');
    my $tb = App::DB::Migrate::SQLite::Editor::Table->new('tname', 'options', $col);
    trap { $tb->change_column_null('col1', 'any') };
    like($trap->die, qr/^Column col1 not found in table tname/);
};

subtest 'rename_sql returns a rename SQL' => sub {
    my $sql = App::DB::Migrate::SQLite::Editor::Table->rename_sql('t1', 't"2');
    is($sql, 'ALTER TABLE "t1" RENAME TO "t""2"');
};

done_testing();
