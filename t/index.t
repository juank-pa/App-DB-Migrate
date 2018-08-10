use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Test::Trap;
use Migrate::Config;
use Mocks;

use Migrate::Index;

our $using = 'USING';
my $index = new Test::MockModule('Migrate::Index');
$index->mock(using => sub { $using });

our $show_options = 1;
my $config = Test::MockModule->new('Migrate::Config');
$config->mock('config', sub { { add_options => $show_options } });

subtest 'new' => sub {
    my $idx = Migrate::Index->new('my_table', 'column');
    isa_ok($idx, 'Migrate::Index');
};

subtest 'new dies if no table name is provided' => sub {
    trap { Migrate::Index->new('') };
    like($trap->die, qr/^Table name is needed/);
};

subtest 'new dies if no column is given' => sub {
    trap { Migrate::Index->new('my_table', '') };
    like($trap->die, qr/^Column is needed/);
};

subtest 'is SQLizable' => sub {
    my $col = Migrate::Index->new('table', 'column');
    isa_ok($col, "Migrate::SQLizable");
};

subtest 'table returns the table name' => sub {
    my $idx = Migrate::Index->new('my_table', 'my_column');
    is($idx->table, 'my_table');
};

subtest 'columns returns the single item array with the given column' => sub {
    my $idx = Migrate::Index->new('my_table', 'my_column');
    is_deeply($idx->columns, ['my_column']);
};

subtest 'columns returns a column array with the given columns' => sub {
    my $idx = Migrate::Index->new('my_table', ['my_column', 'other_column']);
    is_deeply($idx->columns, ['my_column', 'other_column']);
};

subtest 'order returns the order option' => sub {
    my $order = { my_column => 'asc' };
    my $idx = Migrate::Index->new('my_table', 'my_column', { order => $order });
    is_deeply($idx->order, $order);
};

subtest 'length returns the length option' => sub {
    my $length = { my_column => 10 };
    my $idx = Migrate::Index->new('my_table', 'my_column', { length => $length });
    is_deeply($idx->length, $length);
};

subtest 'uses returns the using option' => sub {
    my $idx = Migrate::Index->new('my_table', 'my_column', { using => 'btree' });
    is($idx->uses, 'btree');
};

subtest 'is_unique returns whether the index is unique' => sub {
    my $idx = Migrate::Index->new('my_table', 'my_column', { unique => 1 });
    ok($idx->is_unique);

    $idx = Migrate::Index->new('my_table', 'my_column');
    ok(!$idx->is_unique);
};

subtest 'options returns the index options' => sub {
    my $idx = Migrate::Index->new('my_table', 'my_column', { options => '<OPTIONS>' });
    is($idx->options, '<OPTIONS>');
};

subtest 'to_sql returns a SQL representation of an index' => sub {
    my $idx = Migrate::Index->new('my_table', ['col1', 'col2']);
    is($idx->to_sql, 'CREATE INDEX idx_my_table_col1_col2 ON my_table (col1,col2)');

    $idx = Migrate::Index->new('my_table', 'column');
    is($idx->to_sql, 'CREATE INDEX idx_my_table_column ON my_table (column)');
};

subtest 'to_sql returns a SQL representation of a unique index' => sub {
    my $idx = Migrate::Index->new('my_table', 'column', { unique => 1 });
    is($idx->to_sql, 'CREATE UNIQUE INDEX idx_my_table_column ON my_table (column)');
};

subtest 'to_sql returns a SQL representation of an ordered index' => sub {
    my $idx = Migrate::Index->new('my_table', ['c1', 'c2', 'c3'], { order => 'asc' });
    is($idx->to_sql, 'CREATE INDEX idx_my_table_c1_c2_c3 ON my_table (c1 ASC,c2 ASC,c3 ASC)');

    $idx = Migrate::Index->new('my_table', ['c1', 'c2'], { order => 'desc' });
    is($idx->to_sql, 'CREATE INDEX idx_my_table_c1_c2 ON my_table (c1 DESC,c2 DESC)');
};

subtest 'to_sql returns a SQL representation of an ordered index per column' => sub {
    my $idx = Migrate::Index->new('my_table', ['c1', 'c2', 'c3'], { order => { c1 => 'asc', c3 => 'desc' } });
    is($idx->to_sql, 'CREATE INDEX idx_my_table_c1_c2_c3 ON my_table (c1 ASC,c2,c3 DESC)');
};

subtest 'to_sql returns a SQL representation of an index with length (does nothing)' => sub {
    TODO: {
        local $TODO = 'implement index length';
        my $idx = Migrate::Index->new('my_table', 'column', { length => { column => 10 } });
        is($idx->to_sql, 'CREATE INDEX idx_my_table_column ON my_table (column)');
    }
};

subtest 'to_sql returns a SQL representation of an index with options' => sub {
    my $idx = Migrate::Index->new('my_table', 'column', { options => '<OPTIONS>' });
    is($idx->to_sql, 'CREATE INDEX idx_my_table_column ON my_table (column) <OPTIONS>');
};

subtest 'to_sql returns a SQL representation without options if config specified' => sub {
    local $show_options = 0;
    my $idx = Migrate::Index->new('my_table', 'column', { options => '<OPTIONS>' });
    is($idx->to_sql, 'CREATE INDEX idx_my_table_column ON my_table (column)');
};

subtest 'to_sql returns a SQL representation of an index with custom name' => sub {
    my $idx = Migrate::Index->new('my_table', 'column', { name => 'custom_name' });
    is($idx->to_sql, 'CREATE INDEX custom_name ON my_table (column)');
};

subtest 'to_sql returns a SQL representation of an index with a using clause if implemented' => sub {
    my $idx = Migrate::Index->new('my_table', 'column', { using => 'btree' });
    is($idx->to_sql, 'CREATE INDEX idx_my_table_column ON my_table (column) USING btree');
};

subtest 'to_sql returns a SQL representation of an index with a using clause if not implemented' => sub {
    local $using;
    my $idx = Migrate::Index->new('my_table', 'column', { using => 'btree' });
    is($idx->to_sql, 'CREATE INDEX idx_my_table_column ON my_table (column)');
};

subtest 'to_sql returns a SQL representation of an index' => sub {
    my $idx = Migrate::Index->new('my_table', ['c1', 'c2'], { unique => 1, order => { c2 => 'desc' }, options => 'OPTS', name => 'custom_name' });
    is($idx->to_sql, 'CREATE UNIQUE INDEX custom_name ON my_table (c1,c2 DESC) OPTS');
};

done_testing();
