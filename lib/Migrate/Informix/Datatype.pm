package Migrate::Informix::Datatype;

use strict;
use warnings;

use Migrate::Handler;

use parent qw(Migrate::Datatype);

sub datatypes {
    {
        string      => 'VARCHAR',
        char        => 'CHAR',
        text        => 'TEXT',
        integer     => 'INTEGER',
        bigint      => 'BIGINT',
        float       => 'FLOAT',
        decimal     => 'DECIMAL',
        numeric     => 'NUMERIC',
        date        => 'DATE',
        time        => 'DATETIME HOUR TO SECOND',
        datetime    => 'DATETIME YEAR TO SECOND',
        binary      => 'BLOB',
        boolean     => 'BOOLEAN',

        serial      => 'SERIAL',
        bson        => 'BSON',
        json        => 'JSON',
        money       => 'MONEY',
    }
}

return 1;

