package _{PACKAGE_NAME};

sub up
{
    my $ms = shift;
    $ms->do <<EOF;
{DBADDCOLUMNS}
{DBADDREFERENCES}
EOF
}

sub down
{
    my $ms = shift;
    $ms->do <<EOF;
{DBDROPCOLUMNS}
{DBDROPREFERENCES}
EOF
}
