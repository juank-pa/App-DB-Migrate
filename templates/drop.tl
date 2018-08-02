sub up {
    my ($mh, $dbh) = @_;
    $mh->drop_table('{DBTABLENAME}');
}

sub down {
    my ($mh, $dbh) = @_;
    $mh->create_table('{DBTABLENAME}', sub {
        my $th = shift;
        # Add columns here
    });
    # You could also declare the migration irreversible:
    # $mh->irreversible;
}
