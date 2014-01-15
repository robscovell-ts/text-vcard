package vCard;
use Moo;

use Path::Class;
use Text::vCard;
use vCard::AddressBook;

=head1 SYNOPSIS

    use vCard;

    # create the object
    my $vcard = vCard->new;

    # there are 3 ways to load vcard data in one fell swoop 
    # (see method documentation for details)
    $vcard->load_file($filename); 
    $vcard->load_string($string); 
    $vcard->load_hashref($hashref); 

    # there are 3 ways to output data in vcard format
    my $file   = $vcard->as_file($filename); # writes to $filename
    my $string = $vcard->as_string;          # returns a string
    print "$vcard";                          # overloaded as a string

    # simple getters/setters
    $vcard->fullname('Bruce Banner, PhD');
    $vcard->first_name('Bruce');
    $vcard->family_name('Banner');
    $vcard->title('Research Scientist');
    $vcard->photo('http://example.com/bbanner.gif');

    # complex getters/setters
    $vcard->phones({
        { type => ['work', 'text'], number => '651-290-1234', preferred => 1 },
        { type => ['home'],         number => '651-290-1111' }
    });
    $vcard->addresses({
        { type => ['work'], street => 'Main St' },
        { type => ['home'], street => 'Army St' },
    });
    $vcard->email_addresses({
        { type => ['work'], address => 'bbanner@ssh.secret.army.mil' },
        { type => ['home'], address => 'bbanner@timewarner.com'      },
    });


=head1 DESCRIPTION

A vCard is a digital business card.  vCard and vCard::AddressBook provide an
API for parsing, editing, and creating vCards.

This module is built on top of Text::vCard.  It provides a more intuitive user
interface.  

To handle an address book with several vCard entries in it, start with
L<vCard::AddressBook> and then come back to this module.


=head1 ENCODING ISSUES

TODO


=head1 METHODS

=cut

has _data => ( is => 'rw', default => sub { {} } );

=head2 load_hashref($hashref)

$hashref looks like this:

    fullname    => 'Bruce Banner, PhD',
    first_name  => 'Bruce',
    family_name => 'Banner',
    title       => 'Research Scientist',
    photo       => 'http://example.com/bbanner.gif',
    phones      => [
        { type => ['work'], number => '651-290-1234', preferred => 1 },
        { type => ['cell'], number => '651-290-1111' },
    },
    addresses => [
        { type => ['work'], ... },
        { type => ['home'], ... },
    ],
    email_addresses => [
        { type => ['work'], address => 'bbanner@shh.secret.army.mil' },
        { type => ['home'], address => 'bbanner@timewarner.com' },
    ],

Returns $self in case you feel like chaining.

=cut

sub load_hashref {
    my ( $self, $hashref ) = @_;
    $self->_data($hashref);
    return $self;
}

=head2 load_file($filename)

Returns $self in case you feel like chaining.

=cut

sub load_file {
    my ( $self, $filename ) = @_;
    my $address_book = vCard::AddressBook->new->load_file($filename);
    return $address_book->vcards->[0];
}

=head2 load_string($string)

Returns $self in case you feel like chaining.

=cut

sub load_string {
    my ( $self, $string ) = @_;
    my $address_book = vCard::AddressBook->new->load_string($string);
    return $address_book->vcards->[0];
}

=head2 as_string()

Returns the vCard as a string.

=cut

sub as_string {
    my ($self) = @_;
    my $vcard = Text::vCard->new;

    my $phones          = $self->_data->{phones};
    my $addresses       = $self->_data->{addresses};
    my $email_addresses = $self->_data->{email_addresses};

    $self->_build_simple_nodes( $vcard, $self->_data );
    $self->_build_phone_nodes( $vcard, $phones ) if $phones;
    $self->_build_address_nodes( $vcard, $addresses ) if $addresses;
    $self->_build_email_address_nodes( $vcard, $email_addresses )
        if $email_addresses;

    return $vcard->as_string;
}

sub _simple_node_types {
    qw/fullname title photo birthday timezone/;
}

sub _build_simple_nodes {
    my ( $self, $vcard, $data ) = @_;

    foreach my $node_type ( $self->_simple_node_types ) {
        next unless $data->{$node_type};
        $vcard->$node_type( $data->{$node_type} );
    }
}

sub _build_phone_nodes {
    my ( $self, $vcard, $phones ) = @_;

    foreach my $phone (@$phones) {

        # TODO: better error handling
        die "'number' attr missing from 'phones'" unless $phone->{number};

        my $type      = $phone->{type} || [];
        my $preferred = $phone->{preferred};
        my $number    = $phone->{number};

        my $params = [];
        push @$params, { type => $_ } foreach @$type;
        push @$params, { pref => $preferred } if $preferred;

        $vcard->add_node(
            {   node_type => 'TEL',
                data      => [ { params => $params, value => $number } ],
            }
        );
    }
}

sub _build_address_nodes {
    my ( $self, $vcard, $addresses ) = @_;

    foreach my $address (@$addresses) {

        my $type = $address->{type} || [];
        my $preferred = $address->{preferred};

        my $params = [];
        push @$params, { type => $_ } foreach @$type;
        push @$params, { pref => $preferred } if $preferred;

        my $value = join ';',
            $address->{pobox}     || '',
            $address->{extended}  || '',
            $address->{street}    || '',
            $address->{city}      || '',
            $address->{region}    || '',
            $address->{post_code} || '',
            $address->{country}   || '';

        $vcard->add_node(
            {   node_type => 'ADR',
                data      => [ { params => $params, value => $value } ],
            }
        );
    }
}

sub _build_email_address_nodes {
    my ( $self, $vcard, $email_addresses ) = @_;

    foreach my $email_address (@$email_addresses) {

        # TODO: better error handling
        die "'address' attr missing from 'email_addresses'"
            unless $email_address->{address};

        my $type = $email_address->{type} || [];
        my $preferred = $email_address->{preferred};

        my $params = [];
        push @$params, { type => $_ } foreach @$type;
        push @$params, { pref => $preferred } if $preferred;

        # TODO: better error handling
        my $value = $email_address->{address};

        $vcard->add_node(
            {   node_type => 'EMAIL',
                data      => [ { params => $params, value => $value } ],
            }
        );
    }
}

=head2 as_file($filename)

Write data in vCard format to $filename.

Returns a Path::Class::File if successful.  Dies if not successful.

=cut

sub as_file {
    my ( $self, $filename ) = @_;

    my $file = ref $filename eq 'Path::Class::File'    #
        ? $filename
        : file($filename);

    $file->spew( $self->as_string );

    return $file;
}

sub fullname        { shift->setget( 'fullname',        @_ ) }
sub title           { shift->setget( 'title',           @_ ) }
sub photo           { shift->setget( 'photo',           @_ ) }
sub birthday        { shift->setget( 'birthday',        @_ ) }
sub timezone        { shift->setget( 'timezone',        @_ ) }
sub phones          { shift->setget( 'phones',          @_ ) }
sub addresses       { shift->setget( 'addresses',       @_ ) }
sub email_addresses { shift->setget( 'email_addresses', @_ ) }

sub setget {
    my ( $self, $attr, $value ) = @_;
    $self->_data->{$attr} = $value if $value;
    return $self->_data->{$attr};
}

1;
