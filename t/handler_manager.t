use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::Trap;
use Test::MockModule;
use Test::MockObject;
use Mocks;

use App::DB::Migrate::Handler::Manager;

subtest 'new creates a handler manager' => sub {
    my $mng = App::DB::Migrate::Handler::Manager->new();
    isa_ok($mng, 'App::DB::Migrate::Handler::Manager');
};

subtest 'imports get_dbh from App::DB::Migrate::Dbh' => sub {
    use App::DB::Migrate::Dbh;
    is(\&App::DB::Migrate::Dbh::get_dbh, \&App::DB::Migrate::Handler::Manager::get_dbh);
};

subtest 'imports handler from App::DB::Migrate::Factory' => sub {
    use App::DB::Migrate::Factory;
    is(\&App::DB::Migrate::Factory::handler, \&App::DB::Migrate::Handler::Manager::handler);
};

subtest 'imports class from App::DB::Migrate::Factory' => sub {
    use App::DB::Migrate::Factory;
    is(\&App::DB::Migrate::Factory::class, \&App::DB::Migrate::Handler::Manager::class);
};

subtest 'dbh returns the dbh given at construction' => sub {
    my $dbh = Test::MockObject->new();
    my $mng = App::DB::Migrate::Handler::Manager->new(0, undef, $dbh);
    is($mng->dbh, $dbh);
};

my $mng_mod = new Test::MockModule('App::DB::Migrate::Handler::Manager');

subtest 'dbh returns the default dbh if not given at construction' => sub {
    my $dbh = Test::MockObject->new();
    $mng_mod->redefine(get_dbh => $dbh);

    my $mng = App::DB::Migrate::Handler::Manager->new();
    is($mng->dbh, $dbh);
};

my $dbh = Test::MockObject->new;
$mng_mod->redefine(dbh => $dbh);
$dbh->{test} = 'dbh';

subtest 'startup begins a transaction' => sub {
    my $mng = App::DB::Migrate::Handler::Manager->new();
    my $began_work = 0;
    $dbh->mock(begin_work => sub { $began_work = 1 });

    $mng->startup();
    ok($began_work);
};

subtest 'shutdown commits the transaction opened by startup' => sub {
    my $mng = App::DB::Migrate::Handler::Manager->new();
    my $committed_work = 0;
    $dbh->mock(commit => sub { $committed_work = 1 });

    $mng->shutdown();
    ok($committed_work);
};

subtest 'shutdown rolls back the transaction and dies if there was an error' => sub {
    my $mng = App::DB::Migrate::Handler::Manager->new();
    my $committed_work = 0;
    my $rolled_back_work = 0;
    $dbh->mock(commit => sub { $committed_work = 1 });
    $dbh->mock(rollback => sub { $rolled_back_work = 1 });

    trap {
        $@ = 'Any error';
        $mng->shutdown();
    };

    like($trap->die, qr/^Any error/);
    ok(!$committed_work);
    ok($rolled_back_work);
};

subtest 'get_handler creates a new handler passing options' => sub {
    my @params;
    my $mock_handler = {};
    $mng_mod->redefine(handler => sub { @params = @_; $mock_handler });

    my $mng = App::DB::Migrate::Handler::Manager->new('dry', 'output');
    my $handler = $mng->get_handler;

    is($handler, $mock_handler);
    is_deeply(\@params, ['dry', 'output', $dbh]);
};

subtest 'run_function runs a function with the given argument' => sub {
    my $mng = App::DB::Migrate::Handler::Manager->new('dry', 'output');
    my @args;
    my $arg = { test => 'arg' };
    $mng->run_function(sub { @args = @_ }, $arg);

    is_deeply(\@args, [$arg]);
};

subtest 'record_migration records a migration when direction is up' => sub {
    my $class = '';
    my $migration = Test::MockObject->new;
    $migration->mock('insert_migration_sql', sub { 'INSERT SQL' });
    $mng_mod->redefine(class => sub { $class = $_[0]; $migration });

    my ($sql, $bind_val);
    my $sth = Test::MockObject->new;
    $sth->mock('execute', sub { $bind_val = $_[1] });
    $dbh->mock('prepare', sub { $sql = $_[1]; $sth });

    my $mng = App::DB::Migrate::Handler::Manager->new();
    $mng->record_migration('up', 'migration_id');

    is($class, 'migrations'); # gets migration class from factory
    is($bind_val, 'migration_id'); # inserts a migration with id
    is($sql, 'INSERT SQL'); # using this SQL
};

subtest 'record_migration removes a migration when direction is down' => sub {
    my $class = '';
    my $migration = Test::MockObject->new;
    $migration->mock('delete_migration_sql', sub { 'DELETE SQL' });
    $mng_mod->redefine(class => sub { $class = $_[0]; $migration });

    my ($sql, $bind_val);
    my $sth = Test::MockObject->new;
    $sth->mock('execute', sub { $bind_val = $_[1] });
    $dbh->mock('prepare', sub { $sql = $_[1]; $sth });

    my $mng = App::DB::Migrate::Handler::Manager->new();
    $mng->record_migration('down', 'migration_id');

    is($class, 'migrations'); # gets migration class from factory
    is($bind_val, 'migration_id'); # removes a migration with id
    is($sql, 'DELETE SQL'); # using this SQL
};

subtest 'record_migration dies if SQL fails' => sub {
    my $migration = Test::MockObject->new;
    $migration->mock('insert_migration_sql', sub { 'ANY SQL' });
    $migration->mock('remove_migration_sql', sub { 'ANY SQL' });
    $mng_mod->redefine(class => sub { $migration });
    my $sth = Test::MockObject->new;
    $sth->mock('execute', sub { undef });
    $dbh->mock('prepare', sub { $sth });

    my $mng = App::DB::Migrate::Handler::Manager->new();

    trap {
        $mng->record_migration('up', 'migration_id');
    };

    like($trap->die, qr/^Error recording migration data \(up\)/);

    trap {
        $mng->record_migration('down', 'migration_id');
    };

    like($trap->die, qr/^Error recording migration data \(down\)/);
};

subtest 'execute starts up, runs the migration function, records the migration and shuts down' => sub {
    my @steps;
    $mng_mod->redefine(startup => sub { push @steps, 'startup' });
    $mng_mod->redefine(run_function => sub { push @steps, 'run_function' });
    $mng_mod->redefine(record_migration => sub { push @steps, 'record_migration' });
    $mng_mod->redefine(shutdown => sub { push @steps, 'shutdown' });

    my $mng = App::DB::Migrate::Handler::Manager->new();
    $mng->execute(sub {}, 'mig_id', 'up');

    is_deeply(\@steps, [qw(startup run_function record_migration shutdown)]);
};

subtest 'execute passes the function and a new handler to run function' => sub {
    my @args;
    my $handler = Test::MockObject->new();
    $mng_mod->redefine(run_function => sub { @args = @_ });
    $mng_mod->redefine(get_handler => $handler);

    my $mng = App::DB::Migrate::Handler::Manager->new();
    my $code = sub {};
    $mng->execute($code, 'mig_id', 'up');

    is_deeply(\@args, [$mng, $code, $handler]);
};

subtest 'execute passes direction and migration id to record_migration' => sub {
    my @args;
    $mng_mod->redefine(record_migration => sub { @args = @_ });

    my $mng = App::DB::Migrate::Handler::Manager->new();
    $mng->execute(sub {}, 'mig_id', 'up');

    is_deeply(\@args, [$mng, 'up', 'mig_id']);
};

subtest 'execute does not records a migration in dry mode' => sub {
    my $recorded = 0;
    $mng_mod->redefine(record_migration => sub { $recorded = 1 });

    my $mng = App::DB::Migrate::Handler::Manager->new(1);
    $mng->execute(sub {}, 'mig_id', 'up');

    ok(!$recorded);
};

subtest 'execute dies if no function is provided' => sub {
    my $mng = App::DB::Migrate::Handler::Manager->new();
    trap { $mng->execute(undef, 'mig_id', 'up') };
    like($trap->die, qr/^Code needed/);
};

subtest 'execute dies if no function is provided' => sub {
    my $mng = App::DB::Migrate::Handler::Manager->new();
    trap { $mng->execute(sub {}, undef, 'up') };
    like($trap->die, qr/^Migration id needed/);
};

subtest 'execute default to up if direction is not given' => sub {
    my @args;
    my $handler = Test::MockObject->new();
    $mng_mod->redefine(record_migration => sub { @args = @_ });

    my $mng = App::DB::Migrate::Handler::Manager->new();
    $mng->execute(sub {}, 'mig_id');

    is($args[1], 'up');
};

done_testing();
