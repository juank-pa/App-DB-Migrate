package Dbh;

use strict;
use warnings;

use Log;
use DBI;

our $_DBH = {};
our $_DBHLockMode = 'wait';

our $DBSchema = $ENV{MS_DBSchema};
our $DBName = $ENV{MS_DBName};
our $DBUserName = $ENV{MS_DBUserName};
our $DBPassword = $ENV{MS_DBPassword};
our $DBDataSource = $ENV{MS_DBDataSource};

our $maxDBHAttempts = 5;
our $DBOptions = { RaiseError => 1, AutoCommit => 1, ChopBlanks => 1 };
our $dbhRetryDelay = 1;
our $_DBHLastUpdated = undef;

sub getDBH
{
    return _getDBHWithRetries($DBName, $DBDataSource, $DBUserName, $DBPassword, 1);
}

sub doSQL
{
    my $query = shift;
    my $field_hash = shift;
    my $dbh = shift;

    return $dbh->do($query);
}

sub runSQL
{
    my $query = shift;
    my $field_hash = shift;
    my $dbh = shift;
    my $sth = $dbh->prepare($query);

    if (!$sth->execute(values %$field_hash))
    {
        return $dbh->errstr;
    }

    if(wantarray)
    {
        my @retval;
        while (my $row = $sth->fetchrow_hashref)
        {
            push @retval, $row;
        }
        return @retval;
    }

    return $sth->fetchrow_hashref;
}

# PRIVATE METHODS ------------

sub query
{
    my $table_name = shift;
    my $field_hash = shift;
    my $query = "select * from " . $table_name;

    if( ref($field_hash) )
    {
        $query = "select * from $table_name where ";
        $query .= join " and ", map("$_ = ?", keys %$field_hash);
    }

    return $query;
}

sub _getDBHWithRetries
{
    Log::enter_trace();

    my $dbname      = shift or Log::error_die("No db name");
    my $datasource  = shift or Log::error_die("No data source");
    my $username    = shift or Log::error_die("No username");
    my $password    = shift or Log::error_die("No password");

    my $lock_attr = 'private_lockmode';
    my $found_cached = 0;

    # This will be the dbh we return, assuming everything is copacetic.
    my $dbh = undef;

    if( ref $_DBH->{$dbname} && ($_DBH->{$dbname}->{$lock_attr} eq $_DBHLockMode) )
    {
        $dbh = $_DBH->{$dbname};
        $found_cached = 1;
    }

    # Try to connect
    eval
    {
        $dbh = DBI->connect($datasource, $username, $password, $DBOptions)
            or Log::error_die("Could not connect to database: $!\n");
    };
    if( $@ )
    {
        warn("Error trying to connect to $dbname database : ($DBI::errstr) : \$\@ : $@");
    }

    # If we have still failed to connect to the db, well, that's pretty bad.
    if( !$dbh || !ref($dbh) )
    {
        Log::error_die("Could not connect to $dbname database ($datasource)");
    }

    if( !$found_cached )
    {
        eval
        {
            $dbh->do("set lock mode to " . $_DBHLockMode);
            $dbh->{$lock_attr} = $_DBHLockMode;
        };
        if($@)
        {
            my $err = $DBI::errstr;
            Log::warn("Could not set lock mode to wait: " . $err);
        }
    }

    $_DBH->{$dbname} = $dbh;
    $_DBHLastUpdated = time;

    Log::exit_trace();
    return $dbh;
}

 return 1;
