package MockStringifiedObject;

use parent 'Test::MockObject';

use overload
    fallback => 1,
    '""' => sub { $_[0]->{string} };

sub new {
    my $class = shift;
    my $object = $class->SUPER::new();
    $object->{string} = shift // '';
    return bless($object, $class);
};

return 1;
