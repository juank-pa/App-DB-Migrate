package Migrate::SQLite::Datatype;

use strict;
use warnings;

use Migrate::Handler;

use parent qw(Migrate::Datatype);

sub datatypes {
    {
        string      => 'VARCHAR',
        char        => 'CHARACTER',
        text        => 'TEXT',
        integer     => 'INTEGER',
        bigint      => 'BIGINT',
        float       => 'FLOAT',
        decimal     => 'DECIMAL',
        numeric     => 'NUMERIC',
        date        => 'DATE',
        time        => 'TIME',
        datetime    => 'DATETIME',
        binary      => 'BLOB',
        boolean     => 'BOOLEAN',
    }
}

return 1;
