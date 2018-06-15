package _{PACKAGE_NAME};

sub up
{
    my $ms = shift;
    $ms->do <<EOF;
DROP INDEX "{DBSCHEMA}".ui_{DBTABLENAME}_{DBTABLEPK};
DROP TABLE "{DBSCHEMA}".{DBTABLENAME};
EOF
}

sub down
{
    my $ms = shift;
    $ms->irreversible();
}
