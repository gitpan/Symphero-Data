
# This is Symphero::SimpleHash derived class add functionality of multiple
# values per parameter. Mutliple values should be hashes, not arrays so,
# that each value has its own ID.
# 
# Supports all the methods of Syphero::SimpleHash with some changes and
# additions. See design document for more info.
# 
package Symphero::MultiValueHash;
use strict;
use Carp;

##
# Inheritance from Symphero::SimpleHash;
#
use Symphero::SimpleHash;
use vars qw(@ISA);
@ISA=qw(Symphero::SimpleHash);

##
# Returns value of of sub-parameter. Here is an example:
#
#  my $hash=Symphero::MultiValueHash->new();
#
#  $hash->fill(a => { a1 => 111, a2 => 222, a3 => 333 });
#
#  my $a1=$hash->getsub(a => "a1");
#
#  # $a1 is equal to 111 here.
#
sub getsub ($$$)
{ my ($self,$name,$subname)=@_;
  my $hval=$self->get($name);
  if(ref($hval) ne "HASH")
   { carp ref($self),"::getsub($name,$subname) - not a hash reference accessed";
     return undef;
   }
  $hval->{$subname};
}

##
# The same as getsub, but returns reference to the value instead of
# value itself.
#
sub getsubref($$$)
{ my ($self,$name,$subname)=@_;
  my $hval=$self->get($name);
  if(ref($hval) ne "HASH")
   { carp ref($self),"::getsubref($name,$subname) - not a hash referred (",ref($hval),")";
     return undef;
   }
  \$hval->{$subname};
}

##
# Puts new sub-parameter. First argument is main key and all the rest
# are the same as in fill() method:
#
#  $hash->putsub("a", a1 => 111, a2 => 222, a3 => 333);
#
#  $hash->putsub(a => { a1 => 111, a2 => 222, a3 => 333);
#
#  $hash->putsub("a", [ a1 => 111 ], [ a2 => 222 ], [ a3 => 333 ]);
#
# Joins given arguments with already existing ones for key "a",
# not replaces them. In order to replace "a" entirely issue
# $hash->delete("a") first or use put() method instead.
#
sub putsub ($$@)
{ my $self=shift;
  my $name=shift;
  return unless @_;
  my $hash=$self->get($name);
  if(!defined($hash))
   { $hash={};
     $self->put($name => $hash);
   }
  elsif(ref($hash) ne "HASH")
   { carp ref($self),"::putsub($name,...) - not a hash referred (",ref($hash),")";
     return undef;
   }

  ##
  # We have hash reference?
  #
  my $args;
  if(@_ == 1 && ref($_[0]) eq 'HASH')
   { $args = $_[0];
   }

  ##
  # @_ = ['NAME', 'PHONE'], ['John Smith', '(626)555-1212']
  #
  elsif(ref($_[0]) eq 'ARRAY')
  { my %a=map { ($_->[0], $_->[1]) } @_;
    $args=\%a;
  }

  ##
  # @_ = 'NAME' => 'John Smith', 'PHONE' => '(626)555-1212'
  #
  elsif(int(@_) % 2 == 0)
   { my %a=@_;
     $args=\%a;
   }

  ##
  # Something we do not understand.. yet :)
  #
  else
   { carp ref($self)."::putsub - syntax error in argument passing";
     return undef;
   }

  ##
  # Putting data in in pretty efficient but hard to read way :)
  #
  @{$hash}{CORE::keys %{$args}}=CORE::values %{$args};
}

##
# Deleting some specific parts of multi-valued parameter
#
sub delsub ($$@)
{ my $self=shift;
  my $name=shift;
  return unless @_;
  my $hash=$self->get($name);
  if(!defined($hash))
   { $hash={};
     $self->put($name => $hash);
   }
  elsif(ref($hash) ne "HASH")
   { carp ref($self),"::delsub($name,...) - not a hash referred (",ref($hash),")";
     return undef;
   }

  ##
  # Getting the list and deleting.
  #
  my $list;
  if(@_==1 && ref($_[0]) eq 'ARRAY')
   { $list=shift;
   }
  else
   { $list=\@_;
   }
  delete @{$hash}{@{$list}};
}


##
# That's it
#
use vars qw($VERSION);
($VERSION)=('$Id: MultiValueHash.pm,v 1.2 2001/03/02 00:32:55 amaltsev Exp $' =~ /(\d+\.\d+)/);
1;
__END__

=head1 NAME

Symphero::MultiValueHash - 3D extension of Symphero::SimpleHash

=head1 SYNOPSIS

  use Symphero::MultiValueHash;

=head1 DESCRIPTION

Provides API for manipulating data in a 3D hash. 3D means that any
element in such a hash can be accessed using three `coordinates' - `id',
`name' and `subname'.

Based on Symphero::SimpleHash and adds the following methods:

=item getsub ($$)

=item getsubref ($$)

=item putsub ($$)

=item delsub ($$)

=head1 EXPORTS

Nothing.

=head1 AUTHOR

Andrew Maltsev, <am@xao.com>

=head1 SEE ALSO

=cut
