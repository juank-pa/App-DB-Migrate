package Migrate::Table;

use Migrate::Handler;

sub new
{
    my $class = shift;
    my $handler = shift;
    return bless { handler => $handler, columns => [], defaults => [] }, $class;
}

sub string
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->string_datatype, @_);
}

sub char
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->char_datatype, @_);
}

sub text
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->text_datatype, @_);
}

sub integer
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->integer_datatype, @_);
}

sub float
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->float_datatype, @_);
}

sub decimal
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->decimal_datatype, @_);
}

sub date
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->date_datatype, @_);
}

sub datetime
{
    my $self = shift;
    $self->add_column(shift, $self->{handler}->datetime_datatype, @_);
}

sub add_column
{
    my $self = shift;
    my $handler = $self->{handler};

    my $name = shift // die('Column name is needed');
    my $datatype = shift;
    my $options = shift // {};
    $datatype = $handler->build_datatype($datatype, $options->{limit}, $options->{precision}, $options->{scale});
    my $null = $options->{null} || !defined($options->{null})? $handler->null : $handler->not_null;
    my $current_datetime = exists($options->{default_datetime})? $handler->default.' '.$handler->current_timestamp : undef;
    my $default = exists($options->{default})? $handler->default.' ?' : undef;

    push(@{$self->{defaults}}, $options->{default}) if defined $default;

    $options->{name} = $name;
    $options->{str} = $self->column_str($name, $datatype, $null, $current_datetime // $default);
    push(@{$self->{columns}}, $options);
}

sub timestamps
{
    my $self = shift;
    my $handler = $self->{handler};
    $self->add_column('updated_at', $handler->datetime_datatype, { null => 0, default_datetime => 1 });
    $self->add_column('created_at', $handler->datetime_datatype, { null => 0, default_datetime => 1 });
}

sub column_str { shift; join ' ', grep { defined } (shift, shift, shift, shift); }

sub references
{
    my $self = shift;
    my $name = shift;
    $self->add_column($name."_id", $self->{handler}->integer_datatype, @_);
}

return 1;
