package App::DB::Migrate::Help;

use strict;
use warnings;
use feature 'say';

use App::DB::Migrate::Config;
use Pod::Usage;
use Pod::Find qw(pod_where pod_find);

sub execute {
    my $pod = pod_where({ -inc => 1 }, __PACKAGE__);
    pod2usage({
        -input => $pod
    });
}

return 1;

__END__

=head1 NAME

migrate

=head1 SYNOPSIS

migrate.pl [action] [options]

 Action: (setup|status|generate|run|rollback)

 Boolean options:
  -h, --help     Prints the help for every particular action
      --version  Prints the version

=head1 DESCRIPTION

To be writen.

=cut
