use strict;
use warnings;

use Test::More;
use Test::MockModule;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);
use Cwd;

use Migrate::Config;

subtest 'libary_root returns the library root' => sub {
    my $pwd = Cwd::cwd;
    (my $comp_root = $0) =~ s/(\/)?t\/config\.t//;

    (my $lib_root = Migrate::Config::library_root) =~ s/$pwd//;

    is($lib_root || '.', $comp_root || '.');
};

subtest 'load_config read config.pl and returns its values' => sub {
    prepare({ schema => 'prev value' });

    my $config = Migrate::Config::load_config;
    my $callback = delete $config->{on_connect};

    is_deeply($config, {
        dsn => 'dbi:Driver:DSN',
        schema => 'SCHEMA',
        username => 'USERNAME',
        password => 'PASSWORD',
        attr => {},
        add_options => 1,
    });
    is(ref $callback, 'CODE');
    is(Migrate::Config::config->{schema}, 'prev value');
};

subtest 'config read config.pl and returns its values' => sub {
    prepare();

    my $module = new Test::MockModule('Migrate::Config');
    $module->mock('reload_config', { test => 'Hello' });

    my $config = Migrate::Config::config;

    is_deeply($config, { test => 'Hello' });
};

subtest 'config memoizes its value' => sub {
    Migrate::Config::config(undef);

    my $count;
    my $module = new Test::MockModule('Migrate::Config');
    $module->mock('load_config', sub { $count++; { test => 'Hello' } });

    Migrate::Config::config;
    my $config = Migrate::Config::config;

    is($count, 1);
    is($config->{test}, 'Hello');
};

subtest 'reload_config reloads and returns config.pl memoizing config' => sub {
    Migrate::Config::config({ test => 'prev value' });

    my $count;
    my $module = new Test::MockModule('Migrate::Config');
    $module->mock('load_config', sub { $count++; { test => 'Hello' } });

    my $config = Migrate::Config::reload_config;
    is($count, 1);
    is($config->{test}, 'Hello');

    $config = Migrate::Config::config;

    is($count, 1);
    is($config->{test}, 'Hello');
};

subtest 'driver exracts the driner name from the dsn', => sub {
    Migrate::Config::config({ dsn => 'dbi:MyDriver:etc' });
    is(Migrate::Config::driver, 'MyDriver');
};

subtest 'driver returns driver is dsn is not specified', => sub {
    Migrate::Config::config({ });
    is(Migrate::Config::driver, 'Driver');
};

subtest 'id returns id if configuration does not define the id key' => sub {
    Migrate::Config::config({});
    is(Migrate::Config::id(), 'id');
};

subtest 'id returns a custom id if configuration defines id as a string' => sub {
    Migrate::Config::config({ id => 'my_id'});
    is(Migrate::Config::id(), 'my_id');
};

subtest 'id returns a custom id if configuration defines id as a sub' => sub {
    Migrate::Config::config({ id => sub { 'my_id' }});
    is(Migrate::Config::id(), 'my_id');
};

subtest 'id returns a custom id if configuration defines id as a sub passing table name' => sub {
    Migrate::Config::config({ id => sub { "$_[0] - $_[1]" }});
    is(Migrate::Config::id('people'), 'people - person');
    is(Migrate::Config::id('departments'), 'departments - department');
};

sub prepare {
    my $hash = shift;
    Migrate::Config::config($hash || undef);
    remove_tree('db');
    make_path('db');
    copy('templates/config.pl', 'db');
}

done_testing;
