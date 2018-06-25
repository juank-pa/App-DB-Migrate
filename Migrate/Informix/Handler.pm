package Migrate::Informix::Handler;

use Migrate::Informix::Table;

our @ISA = qw(Migrate::Handler);

sub pk_datatype { 'serial' }

sub string_datatype { 'VARCHAR' }

sub char_datatype { 'CHAR' }

sub text_datatype { 'TEXT' }

sub integer_datatype { 'INTEGER' }

sub float_datatype { 'FLOAT' }

sub decimal_datatype { 'DECIMAL' }

sub date_datatype { 'DATE' }

sub datetime_datatype { 'DATETIME YEAR TO SECOND' }

sub not_null { 'NOT NULL' }

sub null { 'NULL' }

sub default_datatype { shift->string_datatype }

sub default { 'DEFAULT' }

sub current_timestamp { 'CURRENT YEAR TO SECOND' }

sub quotation { '"' }

sub escape
{
    my ($self, $text) = (shift, shift);
    my $quotation = $self->quotation;
    $text =~ s/(\'|\"|\\)/\\$1/g;
    return $text;
}

return 1;
