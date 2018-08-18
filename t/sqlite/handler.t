use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use Migrate::SQLite::Handler;

my $constraint = new Test::MockModule('Migrate::Config');
$constraint->redefine('config', { dsn => 'dbi:SQLite:sample' });

subtest 'new creates a SQLite Handler' => sub {
    my $def = Migrate::SQLite::Handler->new;
    isa_ok($def, 'Migrate::SQLite::Handler');
    isa_ok($def, 'Migrate::Handler');
};

my $editor_changed = 0;
my $editor = Test::MockModule->new('Migrate::SQLite::Editor');
my $last_editor;
$editor->redefine('edit_table', sub {
    my $name = shift;
    my $table = Test::MockObject->new
        ->mock('name', sub { $name })
        ->mock('to_sql', sub { 'TEST SQL' })
        ->mock('has_changed', sub { $editor_changed });
    $table->{table} = $name;
    $last_editor = $table;
    return $table;
});

subtest 'flush does not execute SQL if there is no editor' => sub {
    my $sql;
    my $handler = Test::MockModule->new('Migrate::SQLite::Handler');
    $handler->redefine('execute', sub { $sql = $_[1] });

    Migrate::SQLite::Handler->new->flush;
    ok(!$sql);
};

subtest 'flush does not execute SQL if editor is not changed' => sub {
    my $sql;
    my $handler = Test::MockModule->new('Migrate::SQLite::Handler');
    $handler->{editor} = Test::MockObject->new->mock('has_changed', sub { 0 });
    $handler->redefine('execute', sub { $sql = $_[1] });

    Migrate::SQLite::Handler->new->flush;
    ok(!$sql);
};

subtest 'flush executes SQL if editor has changed' => sub {
    my $sql;
    my $handler = Test::MockModule->new('Migrate::SQLite::Handler');
    $handler->redefine('execute', sub { $sql = $_[1] });

    my $mh = Migrate::SQLite::Handler->new;
    $mh->{editor} = Test::MockObject->new
        ->mock('has_changed', sub { 1 })
        ->mock('to_sql', sub { 'any' });
    $mh->flush;
    is($sql, 'any');
};

subtest 'editor returns the current editor' => sub {
    my $editor = Test::MockObject->new;

    my $mh = Migrate::SQLite::Handler->new;
    $mh->{editor} = $editor;
    is($mh->editor, $editor);
};

subtest 'has_editor_for returns false if there is no editor' => sub {
    my $mh = Migrate::SQLite::Handler->new;
    ok(!$mh->has_editor_for('table'));
};

subtest 'has_editor_for returns false if there is a editor for another table' => sub {
    my $mh = Migrate::SQLite::Handler->new;
    $mh->{editor} = Test::MockObject->new->mock('name', sub { 'table2' });
    ok(!$mh->has_editor_for('table'));
};

subtest 'has_editor_for returns true if there is a editor for the table' => sub {
    my $mh = Migrate::SQLite::Handler->new;
    $mh->{editor} = Test::MockObject->new->mock('name', sub { 'table' });
    ok($mh->has_editor_for('table'));
};

subtest 'editor_for creates a new editor if no previous editor existed' => sub {
    my $mh = Migrate::SQLite::Handler->new;
    ok(!$mh->editor);
    is(my $e = $mh->editor_for('table'), $last_editor);
    is($e, $mh->editor);
    is($e->name, 'table');
};

subtest 'editor_for creates a new editor if an editor existed with another name' => sub {
    my $mh = Migrate::SQLite::Handler->new;
    my $prev = $mh->{editor} = Test::MockObject->new
        ->mock('name', sub { 'table2' })
        ->set_false('has_changed');

    isnt(my $e = $mh->editor_for('table'), $prev);
    is($e, $mh->editor);
    is($e->name, 'table');
};

subtest 'editor_for flushes the previous editor with another name' => sub {
    my $mh = Migrate::SQLite::Handler->new;
    my $prev_editor = $mh->{editor} = Test::MockObject->new
        ->mock('name', sub { 'table2' })
        ->set_false('has_changed');
    my $handler = Test::MockModule->new('Migrate::SQLite::Handler');
    my ($flushed, $e);
    $handler->redefine('flush', sub { $e = $_[0]->editor; $flushed = 1 });

    $mh->editor_for('table');
    ok($flushed);
    is($e, $prev_editor);
};

subtest 'editor_for just returns the editor without flushing if it has the same name' => sub {
    my $mh = Migrate::SQLite::Handler->new;
    my $prev_editor = $mh->{editor} = Test::MockObject->new
        ->mock('name', sub { 'table' })
        ->set_false('has_changed');
    my $handler = Test::MockModule->new('Migrate::SQLite::Handler');
    my $flushed;
    $handler->redefine('flush', sub { $flushed = 1 });

    my $e = $mh->editor_for('table');
    ok(!$flushed);
    is($e, $prev_editor);
    is($mh->editor, $prev_editor);
};

sub test_base_redirect {
    my $name = shift;
    my $handler = Test::MockModule->new('Migrate::SQLite::Handler');
    $handler->redefine('flush', sub { $_[0]->{flushed} = 1; $_[0] });
    my $handler_base = Test::MockModule->new('Migrate::Handler');
    $handler_base->redefine($name, sub { $_[0]->{params} = [my @params = @_] });

    my $mh = Migrate::SQLite::Handler->new;
    $mh->$name('my', 'params');
    ok($mh->{flushed});
    is_deeply($mh->{params}, [$mh, 'my', 'params']);
}

subtest 'create_table flushes and calls base' => sub {
    test_base_redirect('create_table');
};

subtest 'drop_table flushes and calls base' => sub {
    test_base_redirect('drop_table');
};

subtest 'add_index flushes and calls base' => sub {
    test_base_redirect('add_index');
};

subtest 'remove_index flushes and calls base' => sub {
    test_base_redirect('remove_index');
};

subtest 'add_raw_column flushes and calls base if there is no editor' => sub {
    test_base_redirect('add_raw_column');
};

sub test_editor_redirect {
    my $name = shift;
    my $editor_name = shift // $name;
    my $num_params = shift // 2;
    my $has_editor = shift;
    my $editor = Test::MockObject->new
        ->mock($editor_name, sub { $_[0]->{params} = [my @params = @_] });
    my $handler = Test::MockModule->new('Migrate::SQLite::Handler');
    $handler->redefine('editor_for', sub { $_[0]->{etable} = $_[1]; $editor });
    $handler->redefine('has_editor_for', sub { $_[0]->{etable_for} = $_[1]; $has_editor });

    my $mh = Migrate::SQLite::Handler->new;
    my @params = ('my', 'handler', 'test', 'test4');
    my @real_params = splice(@params, 0, $num_params);
    $mh->$name(@real_params);
    is($mh->{etable}, 'my');
    is($mh->{etable_for}, 'my') if $has_editor;
    is_deeply($editor->{params}, [$editor, splice(@real_params, 1)]);
};

subtest 'add_raw_column delegates to editor if it exists' => sub {
    test_editor_redirect('add_raw_column', undef, 2, 1);
};

subtest 'remove_column delegates to editor' => sub {
    test_editor_redirect('remove_column', 'remove_columns', 2);
};

subtest 'remove_column delegates to editor' => sub {
    test_editor_redirect('rename_column', 'rename_column', 3);
};

subtest '_add_foreign_key delegates to editor' => sub {
    test_editor_redirect('_add_foreign_key', 'add_foreign_key', 2);
};

subtest '_remove_foreign_key delegates to editor' => sub {
    test_editor_redirect('_remove_foreign_key', 'remove_foreign_key', 2);
};

subtest 'change_column delegates to editor' => sub {
    test_editor_redirect('change_column', undef, 4);
};

subtest 'change_column_default delegates to editor' => sub {
    test_editor_redirect('change_column_default', undef, 3);
};

subtest 'change_column_null delegates to editor' => sub {
    test_editor_redirect('change_column_null', undef, 3);
};

done_testing();
