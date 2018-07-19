package Migrate::Config;

our $library_root;

BEGIN {
    use File::Spec;
    $module = File::Spec->catfile('lib','Migrate','Config.pm');
    ($library_root = __FILE__) =~ s/[\\\/:]?$module$//
}

use strict;
use warnings;

# TODO:
# 1. Support multiple environment settings (backward compatible)

use File::Spec;

my $config_hash;
my $driver;

sub library_root { $library_root || File::Spec->curdir }

sub config {
    return $config_hash = $_[0] if scalar @_;
    $config_hash // reload_config();
}

sub driver {
    $driver = (split(':', config->{dsn}))[1] if !$driver;
    return $driver;
}

sub load_config {
    my $config_file = File::Spec->catfile('db', 'config.pl');
    return do($config_file) if -e $config_file;
}

sub reload_config {
    $config_hash = load_config();
}

return 1;
