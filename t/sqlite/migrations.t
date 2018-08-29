use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;

use App::DB::Migrate::SQLite::Migrations;

my $constraint = new Test::MockModule('App::DB::Migrate::Config');
$constraint->redefine('config', { dsn => 'dbi:SQLite:sample' });

subtest 'is a SQLite::Migrations' => sub {
    is($App::DB::Migrate::SQLite::Migrations::ISA[0], 'App::DB::Migrate::Migrations');
};

subtest 'create_migrations_table_sql returns migrations create SQL using inherited value' => sub {
    my $mig = Test::MockModule->new('App::DB::Migrate::Migrations');
    $mig->redefine('migrations_table_name', 'test');
    is(
        App::DB::Migrate::SQLite::Migrations->create_migrations_table_sql,
        'CREATE TABLE IF NOT EXISTS test (id VARCHAR(128) NOT NULL PRIMARY KEY)'
    );
};

subtest 'select_migrations_sql returns migrations select SQL using inherited value' => sub {
    my $mig = Test::MockModule->new('App::DB::Migrate::Migrations');
    $mig->redefine('migrations_table_name', 'test');
    is(
        App::DB::Migrate::SQLite::Migrations->select_migrations_sql,
        'SELECT * FROM test ORDER BY id'
    );
};

subtest 'insert_migration_sql returns migrations insert SQL using inherited value' => sub {
    my $mig = Test::MockModule->new('App::DB::Migrate::Migrations');
    $mig->redefine('migrations_table_name', 'test');
    is(
        App::DB::Migrate::SQLite::Migrations->insert_migration_sql,
        'INSERT INTO test (id) VALUES (?)'
    );
};

subtest 'delete_migration_sql returns migrations delete SQL using inherited value' => sub {
    my $mig = Test::MockModule->new('App::DB::Migrate::Migrations');
    $mig->redefine('migrations_table_name', 'test');
    is(
        App::DB::Migrate::SQLite::Migrations->delete_migration_sql,
        'DELETE FROM test WHERE id = ?'
    );
};

done_testing();
