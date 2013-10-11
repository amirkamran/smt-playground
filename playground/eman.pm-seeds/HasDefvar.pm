package HasDefvar;
use Moose ();

use Moose::Exporter;

Moose::Exporter->setup_import_methods(
        with_meta => ['has_defvar']);

sub has_defvar {
     
      my ( $meta, $name, %options ) = @_;
      if (!exists $options{is}) {
          $options{is}='rw';
      }
      if (!exists $options{attrs}) {
          $options{attrs}='';
      }
      if (exists $options{traits}) {
          unshift @{$options{traits}}, 'Defvar';
      } else {
          $options{traits} = ['Defvar'];
      }
      if (!exists $options{isa}) {
          $options{isa}='Str';
      }
      if (exists $options{default}) {
          die "Don't define default variable in has_defvar; define it in attrs if needed. Moose default is used for loading from ENV";
      }
      use 5.010;
      $meta->add_attribute(
          $name,
          default=>sub{return $ENV{$name}||""},
          %options,
      );
}

1;

