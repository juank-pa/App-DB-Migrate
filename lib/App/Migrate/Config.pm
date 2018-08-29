package Migrate::Config;

our $library_root;

BEGIN {
    use File::Spec;
    $module = 'lib/Migrate/Config.pm';
    ($library_root = __FILE__) =~ s/\/?$module$//
}

use strict;
use warnings;

use Lingua::EN::Inflexion qw(noun);

# TODO:
# * Support multiple environment settings (backward compatible)

use File::Spec;

my $config_hash;

sub library_root { $library_root || File::Spec->curdir }

sub config {
    return $config_hash = $_[0] if scalar @_;
    $config_hash // reload_config() // {};
}

sub load_config {
    my $config_file = File::Spec->catfile('db', 'config.pl');
    return do($config_file) if -e $config_file;
}

sub reload_config {
    $config_hash = load_config();
}

sub driver {
    config->{dsn}? (split(':', config->{dsn}))[1] : 'Driver';
}

sub id {
    my $table = shift;
    my $id_gen = config->{id};
    ref($id_gen) eq 'CODE'? $id_gen->($table, $table && noun($table)->singular) : ($id_gen || 'id');
}

return 1;
