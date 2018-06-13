package Dbh;

use Log;
use DBI;

our $_DBH = {};
our $_DBHLockMode = 'wait';

our $DBSchema = $ENV{MS_DBSchema};
our $DbName = $ENV{MS_DBName};
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
            #return the first one that matches.. If there are more than one,
            #the later ones will not be found.
            push @retval, $row;
        }
        return @retval;
    }

    #still here?  Then just return the first one we find
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

###
# DO NOT CALL THIS DIRECTLY
# You should be using _getDBH or other wrapper functions
# Get a db connection or die trying.
###
sub _getDBHWithRetries
{
    Log::enter_trace();

    my $dbname      = shift or error_die("No db name");
    my $datasource  = shift or error_die("No data source");
    my $username    = shift or error_die("No username");
    my $password    = shift or error_die("No password");
    my $is_informix = shift || 0;

    my $lock_attr = 'private_ww_lockmode';
    my $found_cached = 0;

    # This will be the dbh we return, assuming everything is copacetic.
    my $dbh = undef;

    # _DBH is a hash of db handles, keyed off of the db name argument, for
    # caching. Make sure the hash exists.
    if( !ref($_DBH) )
    {
        $_DBH = {};
    }

    # Different ways of checking, because MySQL got mad when I tried to mess with
    # lock mode.
    if( $is_informix )
    {
        if( ref $_DBH->{$dbname} && ($_DBH->{$dbname}->{$lock_attr} eq $_DBHLockMode) )
        {
            $dbh = $_DBH->{$dbname};
            $found_cached = 1;
            #debug("Found cached dbh object for $datasource");
        }
    }
    else
    {
        if( ref($_DBH->{$dbname}) && ( ref($_DBH->{$dbname}) ) =~ /dbi:/i && ( ref($_DBH->{$dbname}) ) !~ /apache::dbi/i )
        {
            $dbh = $_DBH->{$dbname};
            $found_cached = 1;
            #debug("Found cached dbh object for $datasource");
        }
    }

    # Starting at 0 means that the first one doesn't count as a retry and you get
    # 5 retries.
    my $tries = 0;

    # Try (several times, if necessary) to connect to the desired database,
    # making sure the db connection is still up and running if we're using
    # the cache. Only ping if not informix because keeping that in for ifx
    # means the connect succeeds, but the subsequent ping fails and the
    # loop continues.
    while( $tries <= $maxDBHAttempts &&
           #( !$dbh || !ref($dbh) || ($dbh->ping != 1) ) )
           ( !$dbh || !ref($dbh) || (!$is_informix && $dbh->ping != 1) ) )
    {
        #debug("Making new db connection to " . $datasource . "...");

        # If we are looping through, throw in a sleep
        if( $tries++ > 0 )
        {
            # Sleep for 1 second
            #debug("Sleeping again $tries and $dbhRetryDelay");
            select(undef, undef, undef, $dbhRetryDelay);
        }

        # Try to connect
        eval
        {
            $dbh = DBI->connect($datasource, $username, $password, $DBOptions)
                      or error_die("WWBaseObj.pm could not connect to database: $!\n");
        };
        if( $@ )
        {
            warn("Error trying to connect to $dbname database : ($DBI::errstr) : \$\@ : $@");
        }
        else
        {
            Log::debug("Connected to $dbname on try $tries");
        }
    }

    # If we have still failed to connect to the db, well, that's pretty bad.
    if( !$dbh || !ref($dbh) )
    {
        error_die("Could not connect to $dbname database ($datasource) after $tries tries");
    }

    ##################################################################
    # Set lock mode.  This should really go into Apache::DBI when it
    # opens a new connection, but for now, here's a quick fix
    ##################################################################
    if( $is_informix && !$found_cached )
    {
        eval
        {
            $dbh->do("set lock mode to " . $_DBHLockMode);
            $dbh->{$lock_attr} = $_DBHLockMode;
        };
        if($@)
        {
            my $err = $DBI::errstr;
            warn("Could not set lock mode to wait: " . $err);

            #   If Apache::DBI has lost login info, destroy db handle and explicitly reconnect.
            if($err =~ /SQL: -951:/i || $err =~ /Incorrect password or user/i)
            {
                warn("DBI connect failed: $err");

                # Disconnect and try again
                if(ref $dbh =~ /Apache::DBI/i || ref $dbh =~ /Lobby::DBI/i)
                {
                    $dbh->SUPER::disconnect();
                }
                else
                {
                    $dbh->disconnect();
                }

                undef $dbh;
                $dbh = DBI->connect($datasource, $username, $password, $DBOptions)
                     or error_die("WWBaseObj.pm could not re-connect to database: $!\n");
                $dbh->do("set lock mode to " . $_DBHLockMode ) || error_die("Reconnect: Could not set lock mode to wait: " . $DBI::errstr);
                $dbh->{$lock_attr} = $_DBHLockMode;
                info("Re-connected db handle to $datasource to set the lock mode");
            }
        }
    }

    $_DBH->{$dbname} = $dbh;
    $_DBHLastUpdated = time;

    Log::debug("Exiting with dbh") if Log::is_debug();
    Log::exit_trace();
    return $dbh;
}
# END _getDBHWithRetries

 return 1;
