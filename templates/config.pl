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
    # Table ids are generated as 'id', uncomment the following to generate them as '<table>_id'.
    # The method receives the table name and the singular form of the table name as paramteres.
    # You can also set this key to a fixed string value.
    # id => sub { "$_[1]_id" },
}
