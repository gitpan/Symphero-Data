##
# Database support for Symphero::MultiValueHash class. Each accessing
# and mutating method of SimpleHash and MultiValueHash actually goes
# into underlying SQL database. No caching is performed (though database
# may cache data itself).
# 
# Database has the following structure (all fields may be BLOBS or have
# different sizes, no checks of size limitations performed):
#  CREATE TABLE ShoppingCarts (
#    id char(20) DEFAULT '' NOT NULL,
#    name char(40) DEFAULT '' NOT NULL,
#    subname char(40) DEFAULT '' NOT NULL,
#    value char(200),
#    PRIMARY KEY (id,name,subname),
#    KEY idname (id,name)
#  );
#
# See design document for more details.
#
# Implementation is not based on SimpleHash at all, it only has the
# same API.
#
package Symphero::MultiValueDB;
use strict;
use Carp;
use Symphero::Utils;
use Error;

##
# Inheritance to get Java style API.
#
use Symphero::MultiValueHash;
use vars qw(@ISA);
@ISA=qw(Symphero::MultiValueHash);

##
# Version info for those who care.
#
use vars qw($VERSION);
($VERSION)=('$Id: MultiValueDB.pm,v 1.3 2001/03/07 23:16:12 amaltsev Exp $' =~ /(\d+\.\d+)/);

##
# Method prototypes.
#
sub listids ($$$);
sub new ($@);
sub setid ($$);
sub id ($);
sub valid ($);
sub create ($%);
sub delete_all ($);
sub allow_changes ($$);
sub disallow_changes ($$);
#
# Symphero::MultiValueHash compatible
#
sub delsub ($$@);
sub getsub ($$$);
sub getsubref ($@);
sub putsub ($$@);
#
# Symphero::SimpleHash compatible
#
sub contains ($$);
sub defined ($$);
sub delete ($$);
sub exists ($$);
sub get ($$);
sub getref ($@);
sub keys ($);
sub put ($$$);
sub update ($$$);
sub values ($);

##
# Creates instance of DB. Arguments are:
#
#  dbh   => DBI handler to SQL database.
#  table => Name of the table in that database
#  id    => ID of data block inside the table - shopping cart ID, session ID,
#           user ID or something similar.
#
# Id parameter is optional in new() method, but required to store and
# retrieve data. Must be set with setid() if was not set in new().
#
sub new ($@)
{ my $class=shift;
  my $args=get_args(\@_);

  ##
  # Getting and checking parameters
  #
  my $dbh=$args->{dbh} || (ref($class) ? $class->dbh : undef);
  my $table=$args->{table} || (ref($class) ? $class->table : undef);
  my $id=$args->{id} || (ref($class) ? $class->id : undef);
  my $clname=ref($class) || $class;
  $dbh ||
   throw Symphero::Errors::MultiValueDB "${clname}::new - no dbh given";
  $table ||
   throw Symphero::Errors::MultiValueDB "${clname}::new - no table name given";

  ##
  # Constructing our object
  #
  my $self=\ { dbh => $dbh
             , table => $table
             , id => $id
             , changes_ok => 1
             };

  ##
  # Creating get and put sth's here.
  #
  $$self->{sth_get}=$dbh->prepare("SELECT subname,value FROM $table WHERE id=? AND name=?");
  if($dbh->{Driver}->{Name} eq 'mysql')
   { $$self->{sth_insert}=$dbh->prepare("INSERT DELAYED INTO $table (id,name,subname,value) VALUES (?,?,?,?)");
   }
  else
   { $$self->{sth_insert}=$dbh->prepare("INSERT INTO $table (id,name,subname,value) VALUES (?,?,?,?)");
   }
  $$self->{sth_delete}=$dbh->prepare("DELETE FROM $table WHERE id=? AND name=?");
  $$self->{sth_delsub}=$dbh->prepare("DELETE FROM $table WHERE id=? AND name=? AND subname=?");
  $$self->{sth_update}=$dbh->prepare("UPDATE $table SET value=? WHERE id=? AND name=? AND subname=?");
  $$self->{sth_getsub}=$dbh->prepare("SELECT value FROM $table WHERE id=? AND name=? AND subname=?");

  ##
  # Done
  #
  bless $self, ref($class) || $class;
}

##
# Destroying handlers on object descruction
#
sub DESTROY ()
{ my $self=shift;
  foreach my $n (qw(sth_delete sth_delsub sth_update sth_getsub))
   { if($$self->{$n})
      { $$self->{$n}->finish;
        $$self->{$n}=undef;
      }
   }
}

##
# Creates new ID and stores crtime into. You can supply key-generation
# subroutine in 'generator' argument. Default is
# Symphero::Utils::generate_key - 8 characters random key.
#
sub create ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  while(1)
   { $$self->{id}=$args->{generator} ? &{$args->{generator}}()
                                     : generate_key($$self->{table});
     last unless $self->get("crtime");
   }
  $self->put(crtime => time);
  $self->id;
}

##
# Sets new data block ID.
#
sub setid ($$)
{ my $self=shift;
  $$self->{id}=shift;
}

##
# Returns current ID
#
sub id ($)
{ my $self=shift;
  $$self->{id};
}

##
# Checks does such user exist or not.
#
sub valid ($)
{ my $self=shift;
  $self->id && $self->get("crtime");
}

##
# Lists relevant data block ID for given criterions.
#
sub listids ($$$)
{ my ($self,$name,$value)=@_;
  my $sth;
  if(defined($name) && defined($value))
   { $sth=$$self->{dbh}->prepare("SELECT DISTINCT id" .
                             " FROM ${$self}->{table}" .
                            " WHERE name=? AND value=?");
     if(!$sth || !$sth->execute("".$name,"".$value))
      { eprint "SQL error: ",($sth || $$self->{dbh})->errstr;
        return undef;
      }
   }
  else
   { $sth=$$self->{dbh}->prepare("SELECT DISTINCT id FROM ${$self}->{table}");
     if(!$sth || !$sth->execute)
      { eprint "SQL error: ",($sth || $$self->{dbh})->errstr;
        return undef;
      }
   }
  my @ids;
  while(my @row=$sth->fetchrow_array)
   { push(@ids,$row[0]);
   }
  @ids;
}

##
# Deletes entire content! Dangerous!
#
sub delete_all ($)
{ my $self=shift;
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }
  return unless $self->can_change("delete_all");
  my $sth=$$self->{dbh}->prepare("DELETE FROM $$self->{table} WHERE id=?");
  if(!$sth)
   { eprint "SQL error: ",$$self->{dbh}->errstr;
     return undef;
   }
  if(!$sth->execute("".$$self->{id}))
   { eprint "SQL error: ",$sth->errstr;
     return undef;
   }
}

##
# Returns value by given key. For multi-valued parameters returns hash
# reference. Parameter, that has anything in subname field is considered
# "multi-valued" even if it actually contains only one value.
#
sub get ($$)
{ my $self=shift;
  my $name=shift;
  return undef unless defined($name);
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }

  ##
  # Preparing SQL query
  #
  my $sth=$$self->{sth_get};
  if(!$sth || !$sth->execute("".$$self->{id},"".$name))
   { eprint ref($self),"::get - SQL error - ",$$self->{dbh}->errstr;
     return undef;
   }

  ##
  # Retrieving data.
  #
  my $result;
  while(my $row=$sth->fetchrow_arrayref)
   { if($result || defined($row->[0]) && $row->[0] ne '')
      { $result->{$row->[0]}=$row->[1];
      }
     else
      { $result=$row->[1];
        last;
      }
   }
  $result;
}

##
# Part of SimpleHash API, disabled.
#
sub getref ($@)
{ my $self=shift;
  carp ref($self),"::getref - not valid in DB context";
  undef;
}

##
# Returns specific value of multi-valued parameter
#
sub getsub ($$$)
{ my ($self,$name,$subname)=@_;
  return $self->get($name) unless defined $subname && $subname ne '';
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }

  ##
  # Preparing SQL query
  #
  my $sth=$$self->{sth_getsub};
  if(!$sth || !$sth->execute("".$$self->{id},"".$name,"".$subname))
   { eprint ref($self),"::get - SQL error - ",$$self->{dbh}->errstr;
     return undef;
   }

  ##
  # Retrieving data.
  #
  my $row=$sth->fetchrow_arrayref;
  $row ? $row->[0] : undef;
}

##
# Part of MultiValueHash API, disabled.
#
sub getsubref ($@)
{ my $self=shift;
  carp ref($self),"::getsubref - not valid in DB context";
  undef;
}

##
# Storing new value. If value is hash reference or SimpleHash object
# - it is stored as multi-valued parameter. No attempts is made to
# determine deeper data structure and no encoding is done.
#
# Old value is replaced by new totally, even for multi-valued
# parameters. Use putsub for merging new parameters in.
#
sub put ($$$)
{ my $self=shift;
  return $self->putsub(@_) if @_ == 3;
  my ($name,$value)=@_;
  return unless defined($name) && $name ne "";
  if(! $self->id)
   { carp ref($self),"::put - no data block ID set";
     return undef;
   }
  return unless $self->can_change("put");

  ##
  # There should be atomic transaction here! In case of MySQL we use
  # REPLACE, but for all other databases it is delete/insert pair.
  #
  my $sth=$$self->{sth_delete};
  if(!$sth || !$sth->execute("".$self->id,"".$name))
   { eprint ref($self),"::put - SQL error - ",$sth->errstr;
     return undef;
   }
  $sth=$$self->{sth_insert};
  if(ref($value) eq "HASH")
   { foreach my $subname (keys %{$value})
      { if(!$sth->execute("".$self->id,"".$name,"".$subname,"".$value->{$subname}))
         { eprint ref($self),"::put - SQL error - ",$sth->errstr;
           return undef;
         }
      }
   }
  elsif(! ref($value))
   { if(!$sth->execute("".$self->id,"".$name,"","".$value))
      { eprint ref($self),"::put - SQL error - ",$sth->errstr;
        return undef;
      }
   }
  elsif($value->isa("Symphero::SimpleHash"))
   { foreach my $subname ($value->keys)
      { if(!$sth->execute("".$self->id,"".$name,"".$subname,"".$value->get($subname)))
         { eprint ref($self),"::put - SQL error - ",$sth->errstr;
           return undef;
         }
      }
   } 
  else
   { carp ref($self),"::put - wrong argument, do not know how to store it";
   }
  $value;
}

##
# Updating value. No attempt is made to create value, it only gets
# updated if it already exists. In theory this method is not required,
# but it comes handy to avoid DELETE/INSERT when we know for sure that
# this value already exists.
#
sub update ($$$)
{ my ($self,$name,$value)=@_;
  return unless defined($name) && $name ne "";
  if(! $self->id)
   { carp ref($self),"::update - no data block ID set";
     return undef;
   }
  return unless $self->can_change("update");
  my $sth=$$self->{sth_update};
  if(ref($value) eq "HASH")
   { foreach my $subname (keys %{$value})
      { if(!$sth->execute("".$value->{$subname},"".$self->id,"".$name,"".$subname))
         { eprint ref($self),"::update - SQL error - ",$sth->errstr;
           return undef;
         }
      }
   }
  elsif(! ref($value))
   { if(!$sth->execute("".$value,"".$self->id,"".$name,""))
      { eprint ref($self),"::update - SQL error - ",$sth->errstr;
        return undef;
      }
   }
  elsif($value->isa("Symphero::SimpleHash"))
   { foreach my $subname ($value->keys)
      { if(!$sth->execute("".$value->get($subname),"".$self->id,"".$name,"".$subname))
         { eprint ref($self),"::update - SQL error - ",$sth->errstr;
           return undef;
         }
      }
   } 
  else
   { carp ref($self),"::update - wrong argument, do not know how to store it";
   }
  $value;
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
sub fill ($@)
{ my $self = shift;
  return unless @_;
  my $args;

  ##
  # We have hash reference?
  #
  if(@_ == 1 && ref($_[0]))
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
   { my %a=@_ ;
     $args=\%a;
   }

  ##
  # Something we do not understand.. yet :)
  #
  else
   { carp ref($self)."::fill - syntax error in argument passing";
     return undef;
   }

  ##
  # Putting the data in.
  #
  foreach my $name (keys %{$args})
   { $self->put($name, $args->{$name});
   }
}

##
# Storing exact sub-parameters of multi-valued parameter. Parameters are
# merged into the list, not replace it.
#
# First argument is main key and all the rest are the same as in fill()
# method:
#
#  $hash->putsub("a", a1 => 111, a2 => 222, a3 => 333);
#
#  $hash->putsub(a => { a1 => 111, a2 => 222, a3 => 333);
#
#  $hash->putsub("a", [ a1 => 111 ], [ a2 => 222 ], [ a3 => 333 ]);
#
#  my $values=Symphero::SimpleHash(a1 => 111, a2 => 222, a3 => 333);
#  $hash->putsub(a => $values);
#
sub putsub ($$@)
{ my $self=shift;
  my $name=shift;
  return unless defined($name) && $name ne '' && @_;
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }
  return unless $self->can_change("putsub");

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
  # SimpleHash reference?
  #
  elsif(@_ == 1 && ref($_[0]) && $_[0]->isa("Symphero::SimpleHash"))
   { $args={};
     @{$args}{$_[0]->keys}=$_[0]->values;
   }

  ##
  # Something we do not understand.. yet :)
  #
  else
   { carp ref($self)."::putsub - syntax error in argument passing";
     return undef;
   }

  ##
  # There should be atomic transaction here! In MySQL we use REPLACE -
  # mysql extension to SQL.
  #
  my $sth_del=$$self->{sth_delsub};
  my $sth_ins=$$self->{sth_insert};
  my $id="".$self->id;
  foreach my $subname (keys %{$args})
   { if($sth_del && !$sth_del->execute($id,"".$name,"".$subname))
      { eprint ref($self),"::putsub - SQL error - ",$sth_del->errstr;
        return undef;
      }
     if(!$sth_ins->execute($id,"".$name,"".$subname,"".$args->{$subname}))
      { eprint ref($self),"::putsub - SQL error - ",$sth_ins->errstr;
        return undef;
      }
   }
  $args;
}

##
# Deleting some specific parts of multi-valued parameter
#
sub delsub ($$@)
{ my $self=shift;
  my $name=shift;
  return unless defined($name) && $name ne '' && @_;
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }
  return unless $self->can_change("delsub");

  ##
  # Getting the list
  #
  my $list;
  if(@_==1 && ref($_[0]) eq 'ARRAY')
   { $list=shift;
   }
  else
   { $list=\@_;
   }

  ##
  # Deleting
  #
  my $sth=$$self->{sth_delsub};
  foreach my $subname (@{$list})
   { if(!$sth->execute("".$self->id,"".$name,"".$subname))
      { eprint ref($self),"::delsub - SQL error - ",$sth->errstr;
        return undef;
      }
   }
  1;
}

##
# Returns the list of keys in the data block.
#
sub keys ($)
{ my $self=shift;
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }
  my $dbh=$$self->{dbh};
  my $sth=$dbh->prepare("SELECT DISTINCT name FROM $$self->{table} WHERE id=?");
  if(!$sth || !$sth->execute("".$self->id))
   { eprint ref($self),"::delsub - SQL error - ",$dbh->errstr;
     return undef;
   }
  my @list;
  while(my $row=$sth->fetchrow_arrayref)
   { push(@list,$row->[0]);
   }
  @list;
}

##
# Returns the list of values in the data block, not supported because
# we cannot guarantee the same order as in keys.
#
sub values ($)
{ my $self=shift;
  carp ref($self),"::values - not supported";
  undef;
}

##
# Deleting parameter.
#
sub delete ($$)
{ my $self=shift;
  my $name=shift;
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }
  return unless $self->can_change("delete");
  return unless defined($name) && $name ne '';

  ##
  # Deleting
  #
  my $sth=$$self->{sth_delete};
  if(!$sth || !$sth->execute("".$self->id,"".$name))
   { eprint ref($self),"::delete - SQL error - ",$sth->errstr;
     return undef;
   }
  1;
}

##
# Checking is given parameter defined or not.
#
sub defined ($$)
{ my $self=shift;
  defined($self->get($_[0]));
}

##
# Actually it only checks value, not existence.
#
sub exists ($$)
{ my $self=shift;
  defined($self->get($_[0]));
}

##
# Looks for key that refers to the given value.
#
sub contains ($$)
{ my $self=shift;
  my $value=shift;
  if(! $self->id)
   { carp ref($self),"::get - no data block ID set";
     return undef;
   }
  return undef unless defined($value);

  ##
  # Preparing SQL query
  #
  my $sth=$$self->{dbh}->prepare("SELECT name FROM $$self->{table} WHERE id=? AND value=? LIMIT 1");
  if(!$sth || !$sth->execute("".$self->id,"".$value))
   { eprint ref($self),"::contains - SQL error - ",$$self->{dbh}->errstr;
     return undef;
   }
  my $row=$sth->fetchrow_arrayref;
  $row ? $row->[0] : undef;
}

##
# Allowing data modification (default)
#
sub allow_changes ($$)
{ my $self=shift;
  my $old=$$self->{changes_ok};
  $$self->{changes_ok}=defined($_[0]) ? $_[0] : 1;
  $old;
}

##
# Disallowing data modification
#
sub disallow_changes ($$)
{ my $self=shift;
  my $old=$$self->{changes_ok};
  $$self->{changes_ok}=defined($_[0]) ? $_[0] : 0;
  $old;
}

##
# Checking if we can change data
#
sub can_change ($$)
{ my ($self,$funcname)=@_;
  return 1 if $$self->{changes_ok};
  eprint ref($self),"::$funcname - changes disabled, call allow_changes() first";
  0;
}

##
# These methods are for convenience of creating copy objects:
#  my $a=Symphero::MultiValueDB(dbh => $dbh, table => 'FooBar', id => 123);
#  my $b=$a->new(id => 234);  # same dbh & table
#
sub dbh ($) { my $self=shift; $$self->{dbh} }
sub table ($) { my $self=shift; $$self->{table} }

##
# Error package for MultiValueDB.
#
package Symphero::Errors::MultiValueDB;
use Error;
use vars qw(@ISA);
@ISA=qw(Error::Simple);

##
# That's it
#
1;
__END__

=head1 NAME

Symphero::MultiValueDB - 3D database storage

=head1 SYNOPSIS

  use Symphero::MultiValueDB;

  my $db=Symphero::MultiValueDB->new(dbh => $dbh, table => 'Users');

  $db->setid('username');

  my $password=$db->get('password');

  $db->put(a => 123, b => 234);

=head1 DESCRIPTION

Database support for Symphero::MultiValueHash class. Each accessing
and mutating method of SimpleHash and MultiValueHash actually goes
into underlying SQL database. No caching is performed (though database
may cache data itself).
   
Database has the following structure (all fields may be BLOBS or have
different sizes, no checks of size limitations performed):

=over

=item *

id
       
Data hash ID (customer ID, shopping cart ID or something similar).

=item *

name
       
Parameter name.

=item *

subname
       
Parameter subname, used for multi-value parameters. Will be empty, but
not NULL for single value parameters.

=item *

value
       
Parameter value.

=back

It is recommended to make index on `id' and `name' fields together and
make primary key of `id', `name' and `subname' together. An example of
SQL clause to create table might look like:
   
 CREATE TABLE ShoppingCarts (
   id char(20) DEFAULT '' NOT NULL,
   name char(40) DEFAULT '' NOT NULL,
   subname char(40) DEFAULT '' NOT NULL,
   value char(200),
   PRIMARY KEY (id,name,subname),
   KEY idname (id,name)
 );

=head1 METHODS

All methods of L<Symphero::MultiValueHash> are available with the
following changes and additions:

=over

=item *

new ($@)
       
Instead of accepting default values for the hash itself it requires
the following parameters:

=over

=item -

dbh
       
DBI handler to SQL database.

=item -

table
       
Name of the table in that database

=item -

id (optional)

ID of data block inside the table - shopping cart ID, session ID, user
ID or something similar.
   
This parameter is optional in new() method, but required to store and
retrieve data.

=back

=item *

getref ($$), getsubref ($$)
       
Disabled - always produce warning and return undef. We cannot easily
trace if the values reference to which we return would be modified.

=item *

setid ($$)
       
Switches the object to use new data block ID. Must be called if you did
not pass "id" into new() method.

=item *

listids ($$$)
       
Return a list of data block IDs for which condition is met. Condition
is represented by name-value pair. The following example will return
the list of shopping cart IDs for given user:
   
  use Symphero::MultiValueDB;
   
  my $sdb = Symphero::MultiValueDB->new(...);
   
  my @ids = $sdb->listids(logname => "testuser");
   
  print join(",",@ids),"\n";

=head1 EXPORTS

Nothing.

=head1 AUTHOR

Andrew Maltsev, <am@xao.com>

=head1 SEE ALSO

=cut
