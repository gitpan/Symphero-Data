##
# Base of all hash-like objects.
#
package Symphero::SimpleHash;
use strict;
use Carp;

##
# Methods
#
sub new ($;@);
sub fill ($@);
#
# Perl-style API
#
sub put ($$$);
sub get ($$);
sub getref ($$);
sub delete ($$);
sub defined ($$);
sub exists ($$);
sub keys ($);
sub values ($);
sub contains ($$);
sub value ($);		# Pure virtual
#
# Java style API
#
sub isSet ($$);
sub containsKey ($);
sub containsValue ($$);
sub remove ($$);
sub elements ($);

##
# Creating object instance and loading initial data.
#
sub new ($;@) { 

    my $classname = shift ;
    my $this = {} ;
    my $class = bless $this, $classname ;

#    print "SH->new(): ", $class, "\n" ;

    $class->fill(@_) if @_;
    $class ;

}

##
# Filling with values. Values may be given in any of the following
# formats:
#  { key1 => value1,
#    key2 => value2
#  }
# or
#  key1 => value1,
#  key2 => value2
# or
#  [ key1 => value1 ],		(deprecated)
#  [ key2 => value2 ]
#
sub fill ($@) { 

    my $self = shift;
    return unless @_;
    my $args;

#    print "FILL: ", $self, "\n" ;

    ##
    # We have hash reference?
    #
    if(@_ == 1 && ref($_[0])) { 
	$args = $_[0];
    }
    
    ##
    # @_ = ['NAME', 'PHONE'], ['John Smith', '(626)555-1212']
    #
    elsif(ref($_[0]) eq 'ARRAY'){ 
	my %a=map { ($_->[0], $_->[1]) } @_;
	$args=\%a;
    }

    ##
    # @_ = 'NAME' => 'John Smith', 'PHONE' => '(626)555-1212'
    #
    elsif(int(@_) % 2 == 0) { 
	my %a=@_ ;
	$args=\%a;
    }

    ##
    # Something we do not understand.. yet :)
    #
    else { 
	carp ref($self)."::fill - syntax error in argument passing";
	return undef;
    }

    ##
    # Putting data in in pretty efficient but hard to read way :)
    #
    # @{self}{keys %{$args}} =CORE::values %{$args};

    foreach (keys %{$args}) {
	$self->{$_} = $args->{$_} ;
    }
}

##
# Checks does given key contains anything or not.
#
sub defined ($$)
{ 
    my ($self, $name) = @_;
    defined $self->{$name};
}

##
# The same as defined(), method name compatibility with Java hash.
#
sub isSet ($$)
{ 
    my $self=shift;
    $self->defined(@_);
}

##
# Putting new value. Fill optimized for name-value pair.
#
sub put ($$$)
{ 
    my ($self, $name, $value) = @_;
    $self->{$name} = $value;
    $value;
}

##
# Getting value by name
#
sub get ($$)
{ 
    my ($self, $name) = @_ ;
    $self->{$name} ;
}

##
# Returns reference to the value. Suitable for really big or complex
# values and to be used on left side of expression.
#
sub getref ($$)
{ my ($self, $name) = @_;
  return undef unless exists $self->{$name};
  \$self->{$name};
}

##
# Checks whether we contain given key or not.
#
sub exists ($$)
{ 
    my ($self, $name) = @_;
    exists $self->{$name};
}

##
# The same as exists(), method name compatibility with Java hash.
#
sub containsKey ($)
{ 
    my $self=shift;
    $self->exists(@_);
}

##
# List of elements in the `hash'.
#
sub values ($) { 
    my $self = shift;
    CORE::values %{$self};
}

##
# The same as values(), method name compatibility with Java hash.
#
sub elements ($)
{ 
    my $self=shift;
    $self->values;
}

##
# Keys in the `hash'. In the same order as `elements'.
#
sub keys ($) {

    my $self = shift;

#    print "Keys called with: $self\n" ;
#
#    use Devel::CallerItem ;
#
#    my $caller_item = Devel::CallerItem->from_depth(0) ;
#    print $caller_item->as_string(0) ;
#    print "\n" ;
#
#    keys %{$$self};
#

    keys %{$self} ;
}

##
# Deleting given key from the `hash'.
#
sub delete ($$)
{ 
    my ($self, $key) = @_;
    delete $self->{$key};
}

##
# The same as delete(), method name compatibility with Java hash.
#
sub remove ($$)
{ 
    my $self=shift;
    $self->delete(@_);
}

##
# Checks if our `hash' contains specific value and return key or undef.
# Case is insignificant.
#
sub contains ($$)
{ 
    my ($self, $value) = @_ ;
    while(my ($key, $tvalue) = each %{$self}) { 
       return $key if (uc($tvalue) eq uc($value));
   }
    undef;
}

##
# The same as contains, method name compatibility with Java hash.
#
sub containsValue ($$)
{ 
    my $self=shift;
    $self->contains(@_);
}

##
# Returns the value of the object as a whole. Supposed to be overriden
# in derived objects and has no meaning here.
#
sub value ($)
{ 
    my $self = shift;
    carp ref($self)."::value - pure virtual method called";
    undef;
}

##
# That's it
#
use vars qw($VERSION);
($VERSION)=('$Id: SimpleHash.pm,v 1.3 2001/03/08 00:41:05 amaltsev Exp $' =~ /(\d+\.\d+)/);
1;
__END__

=head1 NAME

Symphero::SimpleHash - Simple 2D hash manipulations

=head1 SYNOPSIS

  use Symphero::SimpleHash;

  my $h=new Symphero::SimpleHash a => 11, b => 12, c => 13;

  $h->put(d => 14);

  $h->fill(\%config);

  my @keys=$h->keys;

=head1 DESCRIPTION

Base object from which various hash-like containers are derived.
 
Methods are (alphabetical order, PERL API):

=over

=item *

sub contains ($$)
       
Returns key of the element, containing given text. Case is
insignificant in comparision.
   
If no value found `undef' is returned.

=item *

sub defined ($$)
       
Boolean method to check if element with given key defined or not.
Exactly the same as `defined ($hash->get($key))'.

=item *

sub delete ($$)
       
Deletes given key from the hash.

=item *

sub exists ($$)
       
Checks if given key exists in the hash or not (regardless of value,
which can be undef).

=item *

sub fill ($@)
       
Allows to fill hash with multiple values. Supports variety of argument
formats:
   
   $hash->fill(key1 => value1, key2 => value2, ...);
   
   $hash->fill({ key1 => value1, key2 => value2, ... });
   
   $hash->fill([ key1 => value1 ], [ key2 => value2 ], ...);

=item *

sub get ($$)
       
Returns element by given key.

=item *

sub getref ($$)
       
Return reference to the element by given key or `undef' if such
element does not exist.

=item *

sub keys ($)
       
Returns array of keys.

=item *

sub new ($;@)
       
Creates new hash and pre-fills it with given values. Values are in the
same format as in fill().

=item *

sub put ($$$)
       
Puts single key-value pair into hash. Usually called as:
   
$hash->put(key => value);

=item *

sub value ($)
       
Pure virtual method which is supposed to be overriden in all derived
classes. Should return the value an object as a whole.

=item *

sub values ($)
       
Returns array of values in the same order as $hash->keys returns keys
(on non-modified hash).

=head1 JAVA STYLE API

In addition to normal Perl style API outlined above Symphero::SimpleHash
allows developer to use Java style API. Here is the mapping between Perl
API and Java API:

  isSet          --  defined
  containsKey    --  exists
  elements       --  values
  remove         --  delete
  containsValue  --  contains

=head1 EXPORTS

Nothing.

=head1 AUTHORS

Brave New Worlds: Bil Drury <bild@xao.com>, Andrew Maltsev <am@xao.com>.

=head1 SEE ALSO
