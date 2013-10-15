package Defvar;
use Moose::Role;
has help => (
      is        => 'rw',
      isa       => 'Str',
      predicate => 'has_help',
      required=>1
);

has attrs => (
    is => 'rw',
    isa=>'Str',
    predicate => 'has_attrs',
    required=>1
);

1;
