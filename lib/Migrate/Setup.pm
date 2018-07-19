package Migrate::Setup;

use strict;
use warnings;
use feature 'say';

our $script_dir;

use Migrate::Config;
use Migrate::Factory;
use Migrate::Dbh qw(get_dbh);
use Module::Load;

use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Spec;

use Migrate::Factory qw(create class);

my $db_path = 'db';
my $migrations_path = File::Spec->catfile($db_path, 'migrations');
my $config_file_name = 'config.pl';

my $source_templates_path = File::Spec->catfile(Migrate::Config::library_root, 'templates');
my $source_config_path = File::Spec->catfile($source_templates_path, $config_file_name);
my $target_config_path = File::Spec->catfile($db_path, $config_file_name);
my $target_config_sample_path = "$target_config_path.example";

sub migrations_folder_exists ();

# TODO:
# 1. Add .gitignore for config files if inside a github repo.
# 2. Add svn:ignore if we are in an svn repo.

sub execute {
    if (is_migration_setup()) {
        say('Migrations have already been setup.');
        return;
    }

    _print_results(setup());
}

sub _print_results {
    say('Created items:');
    foreach(@_) {
        say("  $_");
    }
    say("\nEdit $target_config_path with the right DB credentials.");
}

sub _push_file {
    my $files = shift;
    my $file = shift;
    my $success = shift;
    chomp(my $error = shift);
    push(@$files, $error? "Could not create file:$file $error" : $file) if $success || $error;
    $@ = undef;
}

sub migrations_path { $migrations_path }

sub is_migration_setup () { -e $migrations_path && -e $target_config_path && -e $target_config_sample_path }

sub create_migrations_folder {
    make_path($migrations_path);
}

sub create_migration_config_file {
    create_migrations_folder();
    return 0 if -e $target_config_path;

    my $source_path = -e $target_config_sample_path? $target_config_sample_path : $source_config_path;
    copy($source_path, $target_config_path);
    return 1;
}

sub create_migration_config_sample_file {
    create_migrations_folder();
    return 0 if -e $target_config_sample_path;

    copy($source_config_path, $target_config_sample_path);
    return 1;
}

sub setup {
    my @files;

    my $db_exists = -e $db_path;
    my $migration_exists = -e $migrations_path;

    eval { create_migrations_folder() };

    _push_file(\@files, $migrations_path, !$migration_exists, $@);

    my $success = eval { create_migration_config_sample_file() };
    _push_file(\@files, $target_config_sample_path, $success, $@);

    $success = eval { create_migration_config_file() };
    _push_file(\@files, $target_config_path, $success, $@);

    return @files;
}

sub setup_migrations_table {
    get_dbh()->do(class('migrations')->create_migrations_table_sql);
}

return 1;
