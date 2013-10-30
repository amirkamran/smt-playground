package Defvar;
use Moose::Role;
use Moose::Util::TypeConstraints;

has help => (
      is        => 'rw',
      isa       => 'Str',
      required=>1
);

subtype 'TypeDescription',
as 'Str',
where { $_ eq "reqstep" or $_ eq "optstep" or  $_ eq "steplist" },
    message { "$_ is not reqstep, optstep or steplist " };

has type => (
      is        => 'rw',
      isa       => 'TypeDescription',
      predicate => 'has_type'
);

has firstinherit => (
    is => 'rw',
    isa => 'Str',
    predicate=>'has_firstinherit'
);

has inherit => (
    is => 'rw',
    isa => 'Str',
    predicate=>'has_inherit'
);

has same_as => (
    is => 'rw',
    isa => 'Str',
    predicate=>'has_same_as'
);

#in order to not confuse it with moose "Default"
has eman_default => (
    is => 'rw',
    isa => 'Str',
    predicate=>'has_eman_default'
);

sub is_inherited {
    my $self = shift;
    return ($self->has_inherit or $self->has_firstinherit);
}

#has attrs => (
#    is => 'rw',
#    isa=>'Str',
#    required=>1
#);

1;
