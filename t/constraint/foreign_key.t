use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockModule;
use Test::Trap;
use Mocks;

use App::DB::Migrate::Constraint::ForeignKey;

subtest 'new creates a foreign key' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'dept');
    isa_ok($fk, 'App::DB::Migrate::Constraint::ForeignKey');
    isa_ok($fk, 'App::DB::Migrate::Constraint');
};

subtest 'new is invalid if from_table is not sent' => sub {
    trap { App::DB::Migrate::Constraint::ForeignKey->new() };
    like($trap->die, qr/^From table needed/);
};

subtest 'new is invalid if to_table is not sent' => sub {
    trap { App::DB::Migrate::Constraint::ForeignKey->new('users') };
    like($trap->die, qr/^To table needed/);
};

subtest 'new is not invalid if to_table is not sent but used for removal process' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', undef, { remove => 1 });
    ok(ref($fk));
};

subtest 'is SQLizable' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('from', 'to');
    isa_ok($fk, "App::DB::Migrate::SQLizable");
};

subtest 'from_table returns the constraint source table', => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->from_table, 'users');
};

subtest 'to_table returns the constraint source table', => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->to_table, 'departments');
};

subtest 'column returns the singularized to_table name plus _id' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->column, 'department_id');

    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'event_instances');
    is($fk->column, 'event_instance_id');
};

subtest 'column returns the overridden column name' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { column => 'other_column' });
    is($fk->column, 'other_column');
};

subtest 'primary_key returns id' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->primary_key, 'id');
};

subtest 'primary_key default name depends on config' => sub {
    my $config = new Test::MockModule('App::DB::Migrate::Config');
    $config->mock(id => 'any_id');

    my $pk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($pk->primary_key, 'any_id');
};

subtest 'primary_key returns the overridden primary_key' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { primary_key => 'other_column' });
    is($fk->primary_key, 'other_column');
};

subtest 'name returns a constructed constraint name' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->name, 'fk_users_department_id');
};

subtest 'name returns a constructed constraint name with overridden column' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { column => 'other_column' });
    is($fk->name, 'fk_users_other_column');
};

subtest 'name returns a constructed constraint name with overridden name' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { name => 'my_new_fk_name' });
    is($fk->name, 'my_new_fk_name');
};

subtest 'on_delete returns the on delete rule' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'cascade' });
    is($fk->on_delete, 'cascade');
};

subtest 'on_update returns the on update rule' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'cascade' });
    is($fk->on_delete, 'cascade');
};

subtest 'to_sql returns SQL representation of foreign key' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with overridden column' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { column => 'my_column' });
    is($fk->to_sql, 'CONSTRAINT fk_users_my_column REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with overridden primary_key' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { primary_key => 'new_id' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (new_id)');
};

subtest 'to_sql returns SQL representation of foreign key with config overridden primary_key' => sub {
    my $config = new Test::MockModule('App::DB::Migrate::Config');
    $config->mock(id => 'any_id');
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments');
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (any_id)');
};

subtest 'to_sql returns SQL representation of foreign key with overridden name' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { name => 'my_cool_fk_name' });
    is($fk->to_sql, 'CONSTRAINT my_cool_fk_name REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with delete rule' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'cascade' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id) ON DELETE CASCADE');

    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'nullify' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id) ON DELETE SET NULL');

    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'restrict' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id) ON DELETE RESTRICT');

    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_delete => 'other' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id)');
};

subtest 'to_sql returns SQL representation of foreign key with update rule' => sub {
    my $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'cascade' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id) ON UPDATE CASCADE');

    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'nullify' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id) ON UPDATE SET NULL');

    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'restrict' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id) ON UPDATE RESTRICT');

    $fk = App::DB::Migrate::Constraint::ForeignKey->new('users', 'departments', { on_update => 'other' });
    is($fk->to_sql, 'CONSTRAINT fk_users_department_id REFERENCES departments (id)');
};

done_testing();
