package _{PACKAGE_NAME};

sub up
{
    my $mh = shift;
    $mh->create_table('{DBTABLENAME}', sub {
        my $th = shift;
{DBADDCOLUMNS}    });
{DBADDREFERENCES}}

sub down
{
    my $mh = shift;
    $mh->drop_table('{DBTABLENAME}');
}

return 1;
