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
use Migrate::Constraint::ForeignKey;

my $util = Test::MockModule->new('Migrate::Util');
$util->mock('identifier_name', sub { 'schema.'.$_[0] });

subtest 'new creates a foreign key' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'dept');
    isa_ok($fk, 'Migrate::Constraint::ForeignKey');
    isa_ok($fk, 'Migrate::Constraint');
};

subtest 'new is invalid if from_table is not sent' => sub {
    trap { Migrate::Constraint::ForeignKey->new() };
    is($trap->die, "From table needed\n");
};

subtest 'new is invalid if to_table is not sent' => sub {
    trap { Migrate::Constraint::ForeignKey->new('users') };
    is($trap->die, "To table needed\n");
};

subtest 'column returns the singularized to_table name plus _id' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->column, 'department_id');

    $fk = Migrate::Constraint::ForeignKey->new('users', 'event_instances');
    is($fk->column, 'event_instance_id');
};

subtest 'column returns the overridden column name' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { column => 'other_column' });
    is($fk->column, 'other_column');
};

subtest 'primary_key returns id' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->primary_key, 'id');
};

subtest 'primary_key returns the overridden primary_key' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { primary_key => 'other_column' });
    is($fk->primary_key, 'other_column');
};

subtest 'name returns a constructed constraint name' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->name, 'schema.fk_users_department_id');
};

subtest 'name returns a constructed constraint name with overridden column' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { column => 'other_column' });
    is($fk->name, 'schema.fk_users_other_column');
};

subtest 'name returns a constructed constraint name with overridden name' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { name => 'my_new_fk_name' });
    is($fk->name, 'schema.my_new_fk_name');
};

subtest 'to_sql returns SQL representation of foreign key' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with overridden column' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { column => 'my_column' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_my_column REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with overridden primary_key' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { primary_key => 'new_id' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (new_id)');
};

subtest 'to_sql returns SQL representation of foreign key with overridden name' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { name => 'my_cool_fk_name' });
    is($fk->to_sql, 'CONSTRAINT schema.my_cool_fk_name REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with overridden primary_key' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { primary_key => 'new_id' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (new_id)');
};

subtest 'to_sql returns SQL representation of foreign key with delete rule' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'cascade' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id) ON DELETE CASCADE');

    $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'nullify' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id) ON DELETE SET NULL');

    $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'restrict' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id) ON DELETE RESTRICT');

    $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'other' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with update rule' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'cascade' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id) ON UPDATE CASCADE');

    $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'nullify' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id) ON UPDATE SET NULL');

    $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'restrict' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id) ON UPDATE RESTRICT');

    $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'other' });
    is($fk->to_sql, 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id)');
};

subtest 'ForeignKey stringifies to SQL representation of foreign key' => sub {
    my $fk = Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'cascade', on_delete => 'nullify' });
    is("$fk", 'CONSTRAINT schema.fk_users_department_id REFERENCES departments (id) ON DELETE SET NULL ON UPDATE CASCADE');
};

done_testing();
