package App::DB::Migrate::Constraint::Null;

use strict;
use warnings;

use parent qw(App::DB::Migrate::SQLizable);

sub new {
    my ($class, $null) = @_;
    return bless({ null => $null // 1 }, $class);
}

sub is_null { $_[0]->{null} }

sub null { 'NULL' }
sub not_null { 'NOT NULL' }

sub to_sql { $_[0]->is_null? $_[0]->null : $_[0]->not_null }

return 1;
