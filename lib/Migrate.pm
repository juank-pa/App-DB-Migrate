package Migrate;

use strict;
use warnings;
use feature 'say';

use Getopt::Long qw{:config posix_default bundling auto_version};

use Migrate::Generate;
use Migrate::Status;
use Migrate::Run;
use Migrate::Setup;

use constant ACTION_OPTIONS => {
    generate => ['name|n:s', 'column|c:s@', 'ref|r:s@', 'tstamps|t'],
    status => ['file|f'],
    run => ['dry|d'],
    rollback => ['steps|s:i'],
    setup => [],
};

use constant ACTION_CODE => {
    generate => \&Migrate::Generate::execute,
    status => \&Migrate::Status::execute,
    run => \&Migrate::Run::run,
    rollback => \&Migrate::Run::rollback,
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

    check_help($action);
    check_valid_action($action);
    check_needs_setup($action);

    $action = is_action_option($action)? '' : shift(@ARGV);

    # Check again for specific action help
    check_help($ARGV[0], $action) if $action;

    return $action
}

sub get_options {
    my $opts = {};
    return $opts if GetOptions($opts, action_options(shift));
}

sub is_action_option { shift =~ qr/^-/ }
sub is_valid_action { my $action = shift; grep(/^$action$/, &actions) }

sub action_options { @{ACTION_OPTIONS->{$_[0] // ''} // []} }
sub actions { keys %{(ACTION_OPTIONS)} }

sub is_help_option { my $opt = shift; $opt && $opt =~ /^(?:--help|-h)$/ }

sub show_general_help { my ($opt, $act) = @_; !$act && (!$opt || is_help_option $opt) }
sub show_action_help { my ($opt, $act) = @_; $act && is_help_option $opt }

sub check_help {
    my (undef, $action) = @_;
    if (show_general_help(@_) || show_action_help(@_)) {
        Migrate::Help::execute($action);
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
    my $action = shift;
    if ($action ne 'setup' && !Migrate::Setup::is_migration_setup) {
        say('Migrations are not yet setup. Run: migrate setup');
        exit(0);
    }
}

return 1;
