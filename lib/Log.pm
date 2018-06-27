package Log;

sub enter_trace
{
}

sub exit_trace
{
}

sub info
{
    print(scalar(shift) . "\n");
}

sub warn
{
    print(scalar(shift) . "\n");
}

sub debug
{
    print(scalar(shift) . "\n");
}

sub is_debug { 1 }

sub error_die
{
    die(shift);
}

sub print_hash
{
    my $hash = shift;
    print "  $_ => $hash->{$_}\n" for (sort keys %$hash);
}

return 1;
