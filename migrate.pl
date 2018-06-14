#!/usr/bin/perl -w

use strict;

use lib ("$ENV{HOME}/perl");

use Log;
use Migrate::Common;
use Migrate::Help;

$Getopt::Std::STANDARD_HELP_VERSION = 1;
our $VERSION = '0.0.1';

main();

sub main
{
    my $dbh = Dbh::getDBH();
    Migrate::Common::initMigrations($dbh);

    Migrate::Common::execute();
}

sub HELP_MESSAGE
{
    my $fh = shift;
    Migrate::Help::show($fh);
}

sub VERSION_MESSAGE
{
    my $fh = shift;
    print($fh "Migrate v$VERSION\n");
}
