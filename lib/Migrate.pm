package Migrate;

use strict;
use warnings;
use feature 'say';

use Getopt::Std;

use Migrate::Generate;
use Migrate::Status;
use Migrate::Run;
use Migrate::Setup;

use constant ACTION_OPTIONS => {
    generate => 'tr:c:n:',
    status => 'f',
    run => '',
    rollback => '',
    setup => '',
};

use constant ACTION_CODE => {
    generate => \&Migrate::Generate::execute,
    status => \&Migrate::Status::execute,
    run => \&Migrate::Run::execute_up,
    rollback => \&Migrate::Run::execute_down,
    setup => \&Migrate::Setup::execute,
};

sub execute {
    my $action = check_action($ARGV[0]);
    my $options = get_options($action);
    execute_action($action, $options) if $options;
}

sub execute_action {
    my $action = shift;
    my $options = shift;
    ACTION_CODE->{$action}->($options);
}

sub check_action {
    my $action = shift;

    check_empty_action($action);
    check_valid_action($action);
    check_needs_setup($action);

    return is_action_option($action)? '' : shift(@ARGV);
}

sub get_options { my %opts; return \%opts if getopts(&action_options(shift), \%opts); }

sub is_action_option { shift =~ qr/^-/ }
sub is_valid_action { my $actions = join('|', &actions); shift =~ qr/$actions/ }

sub action_options { $_[0] && ACTION_OPTIONS->{$_[0]} // '' }
sub actions { keys %{(ACTION_OPTIONS)} }

sub check_empty_action {
    if (!shift) {
        Migrate::Help::execute();
        exit 0;
    }
}

sub check_valid_action {
    my $action = shift;
    if (!is_valid_action($action) && !is_action_option($action)) {
        say("Invalid action: $action");
        exit 0;
    }
}

sub check_needs_setup {
    if (shift ne 'setup' && !Migrate::Setup::is_migration_setup) {
        say('Migrations are not yet setup. Run: migrate setup');
        exit(0);
    }
}

return 1;
