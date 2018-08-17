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
    #
    # By default migrate generate do not add foreign keys to column references.
    # Uncomment this line to make it add the foreign_key => 1 property.
    # foreign_keys => 1,
    #
    # Uncomment the following line if you want to show the options at the end of
    # the CREATE TABLE statements. Options are added using the options key in create_table.
    add_options => 1,
    #
    # Some DBAs support a dbspace after the table/index definition.
    # Uncomment this line if this is the case.
    # dbspace => 'nsname',
    #
    # Use this key to change the name of the migrations maintainance table
    # migrations_table => '_migrations',
}
