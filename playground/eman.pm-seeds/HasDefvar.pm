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
      if (exists $options{trigger}) {
          die "defvars cannot have custom trigger";
          #$options{attrs}='';
      }
      if (exists $options{attrs}) {
          die "attrs is old style ; was ".$options{arttrs};
          #$options{attrs}='';
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
          $options{eman_default} = $options{default};
          delete $options{default};
          #die "Don't define default variable in has_defvar; define it in attrs if needed. Moose default is used for loading from ENV";
      }
      use 5.010;
      $meta->add_attribute(
          $name,
          trigger => sub {
            my ($seed, $new, $old) = @_;
            #0 => do nothing
            if ($seed->__has_fully_loaded_defvars==1) {
                #eman has to announce the defvar change
                $seed->_emanSaveDefvar($name);
            }
            if ($seed->__has_fully_loaded_defvars==2) {
                $seed->myDie("Cannot change defvar $name in run phase.");
            }
          }, 
          default=>sub{return $ENV{$name}//""},
          %options,
      );
}

1;

