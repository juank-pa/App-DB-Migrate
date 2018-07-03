package Migrate::Help;

use strict;
use warnings;
use Migrate;

sub execute { ::HELP_MESSAGE(*STDOUT); }

sub show {
    my $fh = shift;
    my $action = $Migrate::action;

    global_help($fh);

    return unless $action;

    my $action_sub = \&{$action.'_help'};
    $action_sub->($fh);
}

sub generate_help {
    my $fh = shift;
    print($fh <<EOF);
    -n [name]  The name of the migration (allowed characters [_A-Za-z0-9])
EOF
}

sub status_help {
}

sub run_help {
}

sub rollback_help {
}

sub global_help {
    my $fh = shift;
    my $action = $Migrate::action;
    my $printed_action = $action || 'ACTION';
    my $actions = $action || join('|', &Migrate::actions);

    print($fh <<EOF);
Usage: migrate.pl $printed_action [-OPTIONS]

EOF
    print($fh <<EOF) unless $action;
ACTION: ($actions)

EOF

    print($fh <<EOF);
The following options are accepted:
    --help     Prints the help for every particular action
    --version  Prints the version
EOF
}

return 1;
