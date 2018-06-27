package _{PACKAGE_NAME};

sub up
{
    my $ms = shift;
    $ms->do <<EOF;
-- UP SQL HERE
EOF
}

sub down
{
    my $ms = shift;
    $ms->do <<EOF;
-- DOWN SQL HERE
EOF
}

return 1;
