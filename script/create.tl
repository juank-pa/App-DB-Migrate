sub up {
    my ($mh, $dbh) = @_;
    $mh->create_table('{DBTABLENAME}', sub {
        my $th = shift;
{DBADDCOLUMNS}    });
}

sub down {
    my ($mh, $dbh) = @_;
    $mh->drop_table('{DBTABLENAME}');
}
