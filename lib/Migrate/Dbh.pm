package Migrate::Dbh;

use strict;
use warnings;

BEGIN {
    use Exporter;
    our (@ISA, @EXPORT_OK);

    @ISA = qw(Exporter);
    @EXPORT_OK = qw(get_dbh);
}

use DBI;
use Migrate::Config;

our $_DBH;
our $DefaultOptions = { PrintError => 0, RaiseError => 0, AutoCommit => 1, ChopBlanks => 1 };

sub dbh_attr {
    my $attr  = Migrate::Config::config->{attr};
    return { %$DefaultOptions, %$attr };
}

sub get_dbh
{
    return $_DBH if ref $_DBH;

    my $dbh = undef;
    my $config = Migrate::Config::config;
    my $attr  = dbh_attr;

    eval {
        $dbh = DBI->connect($config->{dsn}, $config->{username}, $config->{password}, $attr)
            or die("Could not connect to database: $!\n");
    };
    if($@) {
        warn("Error trying to connect to database : ($DBI::errstr) : \$\@ : $@");
    }

    $dbh and ref $dbh or die("Could not connect to database ($config->{dsn})");

    $attr->{on_connect}->($dbh) if $attr->{on_connect};

    return $_DBH = $dbh;
}

return 1;
