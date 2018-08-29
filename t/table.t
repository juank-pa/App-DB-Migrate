use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use Mocks;

use App::DB::Migrate::Table;

subtest 'new creates a Table' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    isa_ok($th, 'App::DB::Migrate::Table');
};

subtest 'new dies if no table name is provided' => sub {
    trap { App::DB::Migrate::Table->new('') };
    like($trap->die, qr/^Table name is needed/);
};

subtest 'new creates a table with a primary key' => sub {
    clear_factories();
    my $th = App::DB::Migrate::Table->new('my_table');
    is(scalar(@{$th->columns}), 1);
    is($th->columns->[0], get_mock(ID_COL));
    ok_factory(ID_COL, ['my_table', undef, { type => undef, autoincrement => 1 }]);
};

subtest 'new creates a table with a primary key and custom column' => sub {
    clear_factories();
    my $th = App::DB::Migrate::Table->new('my_table', { primary_key => 'my_id' });
    is(scalar(@{$th->columns}), 1);
    is($th->columns->[0], get_mock(ID_COL));
    ok_factory(ID_COL, ['my_table', 'my_id', { type => undef, autoincrement => 1 }]);
};

subtest 'new creates a table with a primary key and custom datatype' => sub {
    clear_factories();
    my $th = App::DB::Migrate::Table->new('my_table', { id => 'string' });
    is(scalar(@{$th->columns}), 1);
    is($th->columns->[0], get_mock(ID_COL));
    ok_factory(ID_COL, ['my_table', undef, { type => 'string', autoincrement => 1 }]);
};

subtest 'new creates a table without a primary key' => sub {
    clear_factories();
    my $th = App::DB::Migrate::Table->new('my_table', { id => 0 });
    is(scalar(@{$th->columns}), 0);
    ok_factory(PK, undef);
};

subtest 'is SQLizable' => sub {
    my $th = App::DB::Migrate::Table->new('table');
    isa_ok($th, "App::DB::Migrate::SQLizable");
};

subtest 'can reports true for generates datatype methods' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    can_ok($th, 'string');
};

subtest 'generates methods for handler valid datatypes' => sub {
    my $module = new Test::MockModule('App::DB::Migrate::Table');
    my @args;
    $module->mock(column => sub { @args = @_ } );

    foreach (qw{string integer}) {
        my $th = App::DB::Migrate::Table->new('my_table');
        $th->$_('field_name', { opts => 'values' });
        is_deeply(\@args, [$th, 'field_name', $_, { opts => 'values' }]);
    }
};

subtest 'does not generate methods if datatype is not valid in handler' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    trap { $th->other('field_name', { opts => 'values' }) };
    like($trap->die, qr/Invalid function: other/);
};

subtest 'name returns the table name' => sub {
    my $th = App::DB::Migrate::Table->new('my_table', { id => 0 });
    is($th->name, 'my_table');
};

subtest 'type methods support many column names without options' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    clear_factories();
    start_agregate();

    $th->string('first_name', 'last_name');

    is(scalar @{ $th->columns }, $col_count + 2);
    ok_factory(COL, ['first_name', 'string', undef, 'last_name', 'string', undef]);
    end_agregate();
};

subtest 'type methods support many column names with options' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    my $options = { any => 'Hello', null => 0 };
    clear_factories();
    start_agregate();

    $th->integer('age', 'count', $options);

    is(scalar @{ $th->columns }, $col_count + 2);
    ok_factory(COL, ['age', 'integer', $options, 'count', 'integer', $options]);
    end_agregate();
};

subtest 'column creates a column receiving a name and a datatype' => sub {
    my $th = App::DB::Migrate::Table->new('my_table', { id => 0 });
    my $col_count = scalar @{ $th->columns };
    my $options = {};
    $th->column('my_col', 'integer', $options);

    is(scalar @{ $th->columns }, $col_count + 1);
    is_deeply($th->columns->[-1], get_mock(COL));
    ok_factory(COL, ['my_col', 'integer', $options]);
};

subtest 'column dies if column fails' => sub {
    my $th = App::DB::Migrate::Table->new('my_table', { id => 0 });
    fail_factory();
    trap { $th->column('anything', 'string') };
    is($trap->die, "Test issue\n");
};

subtest 'timestamps creates timestamps columns' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    my $options = { any => 'Hello', null => 0 };

    clear_factories();
    start_agregate();
    $th->timestamps($options);

    is(scalar @{ $th->columns }, $col_count + 2);
    is_deeply($th->columns->[-1], get_mock(TS));
    is_deeply($th->columns->[-2], get_mock(TS));
    ok_factory(TS, ['updated_at', $options, 'created_at', $options]);

    end_agregate();
};

subtest 'references creates and pushes a reference column' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    my $col_count = scalar @{ $th->columns };
    my $options = { };
    $th->references('my_column', $options);

    is(scalar @{ $th->columns }, $col_count + 1);
    is_deeply($th->columns->[-1], get_mock(REF));
    ok_factory(REF, ['my_table', 'my_column', $options]);
};

subtest 'to_sql returns a SQL representation of a create table without primary key' => sub {
    my $th = App::DB::Migrate::Table->new('my_table', { id => 0 });
    $th->column('my_column', 'string');
    is($th->to_sql, 'CREATE TABLE my_table (<COLUMN>)');
};

subtest 'to_sql returns a SQL representation of a create table statement' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    $th->column('my_column', 'string');
    is($th->to_sql, 'CREATE TABLE my_table (<ID_COL>,<COLUMN>)');
};

subtest 'to_sql returns a SQL representation of a table with options' => sub {
    my $config = new Test::MockModule('App::DB::Migrate::Config');
    $config->mock('config', { add_options => 1 });

    my $th = App::DB::Migrate::Table->new('my_table', { options => 'my options' });
    $th->column('my_column', 'string');
    $th->column('my_column', 'integer');
    is($th->to_sql, 'CREATE TABLE my_table (<ID_COL>,<COLUMN>,<COLUMN>) my options');
};

subtest 'to_sql returns a SQL representation of a table without options if configured' => sub {
    my $config = new Test::MockModule('App::DB::Migrate::Config');
    $config->mock('config', { add_options => 0 });

    my $th = App::DB::Migrate::Table->new('my_table', { options => 'my options' });
    $th->column('my_column', 'string');
    $th->column('my_column', 'integer');
    is($th->to_sql, 'CREATE TABLE my_table (<ID_COL>,<COLUMN>,<COLUMN>)');
};

subtest 'to_sql returns a SQL representation of a table with timestamps' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    $th->column('my_column', 'string');
    $th->timestamps;
    is($th->to_sql, 'CREATE TABLE my_table (<ID_COL>,<COLUMN>,<TIMESTAMP>,<TIMESTAMP>)');
};

subtest 'to_sql returns a SQL representation of a table with references' => sub {
    my $th = App::DB::Migrate::Table->new('my_table');
    $th->column('my_column', 'string');
    $th->references('dept');
    is($th->to_sql, 'CREATE TABLE my_table (<ID_COL>,<COLUMN>,<REF>)');
};

subtest 'to_sql returns a SQL representation of a temporary table' => sub {
    my $th = App::DB::Migrate::Table->new('my_table', { temporary => 1 });
    my $table = new Test::MockModule('App::DB::Migrate::Table');
    $table->mock('temporary', 'TEMP');

    $th->column('my_column', 'string');
    is($th->to_sql, 'CREATE TEMP TABLE my_table (<ID_COL>,<COLUMN>)');
};

subtest 'to_sql returns a SQL representation of a tebla using as syntax' => sub {
    my $th = App::DB::Migrate::Table->new('my_table', { as => 'SELECT * FROM other_table' });
    is($th->to_sql, 'CREATE TABLE my_table AS SELECT * FROM other_table');
};

done_testing();
