package MyException;

use overload ('""' => 'stringify');

sub new {
    my ($class, $errMsg) = @_;

    my $self = { _errMsg => $errMsg };
    
    bless $self, $class;
    return $self;
}

sub errMsg {
    my ($self, $errMsg) = @_;

    $self->{_errMsg} = $errMsg if defined($errMsg);
    return $self->{_errMsg};
}

sub stringify {
    my ($self) = @_;

    my $class = ref($self) || $self;    
    return $self->errMsg();
}

return 1;
