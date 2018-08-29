package App::DB::Migrate::SQLite::Editor::Datatype;

use strict;
use warnings;

use App::DB::Migrate::SQLizable;
use parent qw(App::DB::Migrate::SQLizable);

our %datatypes = (
    INT                 => 'integer',
    INTEGER             => 'integer',
    TINYINT             => 'integer',
    SMALLINT            => 'integer',
    BIGINT              => 'bigint',
    'UNSIGNED BIG INT'  => 'bigint',
    INT2                => 'integer',
    INT8                => 'integer',
    CHARACTER           => 'char',
    VARCHAR             => 'string',
    'VARYING CHARACTER' => 'string',
    NCHAR               => 'char',
    'NATIVE CHARACTER'  => 'char',
    NVARCHAR            => 'string',
    TEXT                => 'text',
    CLOB                => 'text',
    BLOB                => 'binary',
    REAL                => 'float',
    DOUBLE              => 'float',
    'DOUBLE PRECISION'  => 'float',
    NUMERIC             => 'numeric',
    DECIMAL             => 'decimal',
    BOOLEAN             => 'boolean',
    DATE                => 'date',
    DATETIME            => 'datetime',
);

sub new {
    my ($class, $name, @attrs) = @_;
    die ("Invalid datatype: $name") if $name && !exists($datatypes{uc($name)});
    @attrs = grep { defined($_) } @attrs;
    return bless { name => uc($name // ''), attrs => [@attrs] }, $class;
}

sub native_name { $_[0]->{name} }
sub name { $datatypes{$_[0]->{name}} // 'string' }
sub attrs_sql { join(',', @{ $_[0]->{attrs} }) }

sub to_sql {
    my $self = shift;
    return '' unless $self->native_name;
    my $attrs = $self->attrs_sql;
    return $self->native_name.(length($attrs)? "($attrs)" : '');
}

return 1;
