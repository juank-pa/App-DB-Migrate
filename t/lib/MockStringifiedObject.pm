package MockStringifiedObject;

use parent 'Test::MockObject';

use overload
    fallback => 1,
    '""' => sub {
        return $_[0]->{string}->(@{ $_[0]->{params} }) if ref($_[0]->{string});
        $_[0]->{string};
    };

sub new {
    my $class = shift;
    my $string = shift;
    my $object = $class->SUPER::new();
    $object->{string} = $string // '';
    return bless($object, $class);
}

return 1;
