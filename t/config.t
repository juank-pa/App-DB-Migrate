use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Trap;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);

use Migrate::Config;
use Cwd;

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
        attr => {}
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

sub prepare {
    my $hash = shift;
    Migrate::Config::config($hash || undef);
    remove_tree('db');
    make_path('db');
    copy('templates/config.pl', 'db');
}

done_testing;