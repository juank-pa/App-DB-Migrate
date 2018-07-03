{
    dsn => 'dbi:Driver:DSN',
    schema => 'SCHEMA',
    username => 'USERNAME',
    password => 'PASSWORD',
    attr => {},
    on_connect => sub {
        my $dbh = shift;
        # Configure the DBI $dbh object after a successful connection
    },
}
