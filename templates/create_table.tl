sub up {
    my ($mh, $dbh) = @_;
    $mh->create_table('{DBTABLENAME}', sub {
        my $th = shift;
{DBADDCOLUMNS}    });
{DBADDREFERENCES}}

sub down {
    my ($mh, $dbh) = @_;
    $mh->drop_table('{DBTABLENAME}');
}
