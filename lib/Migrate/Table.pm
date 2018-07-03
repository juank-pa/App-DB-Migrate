package Migrate::Table;

use Migrate::Handler;

sub new {
    my $class = shift;
    my $name = shift;
    my $handler = shift;
    return bless { handler => $handler, name => $name, columns => [] }, $class;
}

sub name { my $self; $self->{name} }

sub string {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->string_datatype, @_);
}

sub char {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->char_datatype, @_);
}

sub text {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->text_datatype, @_);
}

sub integer {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->integer_datatype, @_);
}

sub float {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->float_datatype, @_);
}

sub decimal {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->decimal_datatype, @_);
}

sub date {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->date_datatype, @_);
}

sub datetime {
    my $self = shift;
    $self->add_column(shift, $self->{handler}->datetime_datatype, @_);
}

sub add_column {
    my $self = shift;
    my $handler = $self->{handler};
    my $name = shift // die('Column name is needed');

    $options->{name} = $name;
    $options->{str} = $self->get_column($name, @_);
    push(@{$self->{columns}}, $options);
}

sub get_column {
    my $self = shift;
    my $handler = $self->{handler};

    my $name = shift // die('Column name is needed');
    my $datatype = shift;
    my $options = shift // {};
    $datatype = $handler->build_datatype($datatype, $options->{limit}, $options->{precision}, $options->{scale});

    my $null = $options->{null} || !defined($options->{null})? $handler->null : $handler->not_null;
    my $current_datetime = exists($options->{default_datetime})? $handler->default.' '.$handler->current_timestamp : undef;
    my $default = $handler->default.' '.$handler->quote($options->{default}, $datatype) if $options->{default};

    return $self->column_str($name, $datatype, $null, $current_datetime // $default);
}

sub add_pk_column { }

sub timestamps {
    my $self = shift;
    my $handler = $self->{handler};
    $self->add_column('updated_at', $handler->datetime_datatype, { null => 0, default_datetime => 1 });
    $self->add_column('created_at', $handler->datetime_datatype, { null => 0, default_datetime => 1 });
}

sub column_str { shift; join ' ', grep { defined } (shift, shift, shift, shift); }

sub references {
    my $self = shift;
    my $name = shift;
    my $options = shift // {};
    my $handler = $self->{handler};
    my $target_table = $handler->plural($name);
    $options->{name} = $name;
    $options->{str} = $self->get_column("${name}_id", $handler->integer_datatype, $options)." CONSTRAINT fk_$self->{name}_$name REFERENCES $target_table(${name}_id)";
    push(@{$self->{columns}}, $options);
}

return 1;
