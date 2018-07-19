sub up {
    my ($mh, $dbh) = @_;
    $dbh->do(<<EOF);
-- UP SQL HERE
EOF
}

sub down {
    my ($mh, $dbh) = @_;
    $dbh->do(<<EOF);
-- DOWN SQL HERE
EOF
}
