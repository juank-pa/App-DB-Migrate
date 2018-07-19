use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use File::Path qw(remove_tree make_path);
use File::Spec;

use lib 't/lib';
use MockStringifiedObject;
use Migrate::Factory;
use Migrate::Column::References;

our $params = {};
our $test_die;
our $mocks = {
    datatype => MockStringifiedObject->new('<DATATYPE>'),
    null => MockStringifiedObject->new('<NULL>'),
    default => MockStringifiedObject->new('<DEFAULT>'),
    foreignkey => MockStringifiedObject->new('<FK>'),
};

no warnings 'redefine';
local *Migrate::Column::create = sub {
    my $type = lc((split('::', $_[0]))[-1]);
    $params->{$type} = \@_; $mocks->{$type}
};
local *Migrate::Column::References::create = *Migrate::Column::create;
use warnings 'redefine';

subtest 'new fails is ref_name is not provided' => sub {
    trap { Migrate::Column::References->new('table', '') };
    is($trap->die, "Reference name is needed\n");
};

subtest 'new fails is table is not provided' => sub {
    trap { Migrate::Column::References->new('', 'column') };
    is($trap->die, "Table name is needed\n");
};

subtest 'new passes arguments to base class' => sub {
    no warnings 'redefine';
    local *Migrate::Column::new = sub { { name => $_[1], datatype => $_[2], options => $_[3] } };
    use warnings 'redefine';

    my $ref = Migrate::Column::References->new('table', 'column', {
        any => 'ANY',
    });

    is($ref->{name}, 'column_id');
    is($ref->{datatype}, 'integer');
    is_deeply($ref->{options}, { any => 'ANY' });
};

subtest 'new can override datatype' => sub {
    no warnings 'redefine';
    local *Migrate::Column::new = sub { { name => $_[1], datatype => $_[2], options => $_[3] } };
    use warnings 'redefine';

    my $ref = Migrate::Column::References->new('table', 'column', {
        type => 'string',
    });

    is($ref->{datatype}, 'string');
};

subtest 'new passes foreign_key data to ForeignKey factory' => sub {
    my $ref = Migrate::Column::References->new('my_table', 'column', {
        foreign_key => 1,
    });
    is_deeply($params->{foreignkey}, ['Constraint::ForeignKey', 'my_table', 'columns', {}]);
};

subtest 'new passes foreign_key data to ForeignKey factory overridding to_table' => sub {
    my $ref = Migrate::Column::References->new('my_table', 'column', {
        foreign_key => { to_table => 'new_table' },
    });
    is_deeply($params->{foreignkey}, ['Constraint::ForeignKey', 'my_table', 'new_table', {}]);
};

subtest 'new passes foreign_key data to ForeignKey factory with data' => sub {
    my $ref = Migrate::Column::References->new('old_table', 'column', {
        foreign_key => { to_table => 'new_table', on_delete => 'cascade' },
    });
    is_deeply($params->{foreignkey}, ['Constraint::ForeignKey', 'old_table', 'new_table', { on_delete => 'cascade' }]);
};

subtest 'table returns the reference table name' => sub {
    my $ref = Migrate::Column::References->new('my_table', 'column');
    is($ref->table, 'my_table');
};

subtest 'name returns the column name' => sub {
    my $ref = Migrate::Column::References->new('my_table', 'column');
    is($ref->name, 'column_id');
};

subtest 'raw_name returns the column name without adding id' => sub {
    my $ref = Migrate::Column::References->new('my_table', 'column');
    is($ref->raw_name, 'column');
};

subtest 'to_sql returns the column SQL representation' => sub {
    my $col = Migrate::Column::References->new('my_table', 'column');
    is($col->to_sql, 'column_id <DATATYPE>');
};

subtest 'to_sql returns the column SQL representation with foreign key' => sub {
    my $col = Migrate::Column::References->new('my_table', 'column', { foreign_key => 1 });
    is($col->to_sql, 'column_id <DATATYPE> <FK>');
};

subtest 'Column stringifies as the column SQL representation' => sub {
    my $col = Migrate::Column::References->new('table', 'test_column', { null => 0, foreign_key => 1 });
    is("$col", 'test_column_id <DATATYPE> <NULL> <FK>');
};

done_testing();
