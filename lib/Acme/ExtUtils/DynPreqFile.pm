use 5.006;  # our
use strict;
use warnings;

package Acme::ExtUtils::DynPreqFile;

our $VERSION = '0.001000';

# ABSTRACT: Structured Dynamic Prerequisites and Metadata extraction.

# AUTHORITY

1;

=head1 SYNOPSIS

=head2 In C<Makefile.PL>

  my %WriteMakefileArgs = (
    ...
  );

  require Acme::ExtUtils::DynPreqFile;
  my $dynpreq = Acme::ExtUtils::DynPreqFile->new('dynpreqfile');

  ## Author Mode
  if ( ! -e 'META.json' ) {
    # Injects x_dynamic_prereqs
    $dynpreq->eumm_merge_metadata(\%WriteMakefileArgs);
  } else {
    my $config = $dynpreq->configure;
    # executes configure blocks
    # and merges prereqs into relevant EUMM Prereq stashes
    $config->eumm_merge_configure(\%WriteMakefileArgs);
  }

  WriteMakefileArgs(%WriteMakefileArgs);

=head2 C<dynpreqfile>

  use lib 'inc'; # Load helpers for implementing conditions
  use ExtUtils::DynPrereqs::Utils qw( has_compiler );

  # Label to use in META.* and diagnostics
  providing "Win32 Extensions" => sub {

    # Description of condition for META.* for Vendors
    condition "OS is Windows and has a C Compiler" => sub {
      # Implementation of condition for ->configure call
      $^O eq q[Win32] and has_compiler();
    };

    # Prereq augmentation when condition is true
    # used in published META.* and used in MYMETA.*
    # under satisfactory ->configure
    requires "Some::Module";

    # NOTE: on configure is banned because it must be satisfied
    #       before calling Makefile.PL anyway, making configure-time
    #       configure requirements a stupid time machine.

    on "test" => sub {
      requires "Some::Test::Requrirement" => 0;
    };
    on "build" => sub {
      requires "Some::Build" => 0;
    };

  };

=head1 DESCRIPTION

This is a prototype example of the idea I floated on L<< CPAN::Meta::Spec issue|https://github.com/Perl-Toolchain-Gang/CPAN-Meta/issues/112#issuecomment-229314326 >>
regarding the need for vendor-friendly metadata in C<META.json>.

This approach makes solving that without reams of redundancy mostly straight-forward,
creating a simple language that Perl can use to both

=over 4

=item * Generate static metadata for exposing to vendors

=item * Provide executable code that performs what the static metadata describes

=back

The ideas here-in are stolen from C<CPANFile> and C<Dist::Zilla::Plugin::DynamicPrereqs>

The C<dynpreqfile> stated in synopsis would result in the following content in C<META.json>
( Taking careful note there is B<NO> executable logic in it )

  "x_dynamic_prereqs" : {
    "Win32 Extensions" : {
      "condition": "OS is Windows and has a C Compiler",
      "prereqs": {
        "build": {
          "requires": {
            "Some::Module": 0
          }
        },
        "runtime": {
          "requires": {
            "Some::Module": 0
          }
        },
        "test": {
          "requires": {
            "Some::Test::Requirement": 0
          }
        }
      }
    }
  }

After calling C<< $instance->configure->eumm_merge_config( \%WriteMakefileArgs ) >>
during install-time configure, assuming the code block containing C<< $^O >> returned true,
C<x_dynamic_prereqs.Win32 Extensions.prereqs> would be merged into C<preqreqs>

=head1 METHODS

=head2 new

  # Path to file mandatory, because this is a prototype, the name is not
  # decided on, and may conflict with other future naming choices as this is
  # nowhere near concrete.
  #
  # Lack of a default is easier to solve backwards compatibily than a bad default.
  my $instance = Acme::ExtUtils::DynPreqFile->new( 'dynpreqfile' );

This creates an instance, and sets up the glue to lazily load and decode a C<dynpreqfile>

=head2 eumm_merge_metadata

Merge loaded static data into C<CPAN::Meta> structures
suitable for generating C<META.json> via C<ExtUtils::MakeMaker>.

Presently injects into C<x_dynamic_prereqs>

  $instance->eumm_merge_metadata( \%WriteMakefileArgs );

This method should be called only in "author" mode, which can be
implemented carefully by ensuring C<META.json> is not in your source
tree repository, and by defining the absence of that file as "Author" mode,
assuming that the relevant file will be generated during the standard
C<perl Makefile.PL && make manifest && make dist> invocation.

  if ( ! -e 'META.json' ) {
    # Injects x_dynamic_prereqs
    $dynpreq->eumm_merge_metadata(\%WriteMakefileArgs);
  }

=head2 configure

Execute the codified conditional logic in the active parts of C<dynpreqfile>
and return an object representing the "configured" result.

  my $result = $instance->configure();

The result object can then be queried ( See: L<Acme::ExtUtils::DynPreqFile::Result> )
but it can be used to automatically update C<WriteMakefileArgs> to communicate
the decided post-configure prerequisites.

  $instance->configure()->eumm_merge_config(\%WriteMakefileArgs);

=head1 C<DynPreqFile> Specification

C<DynPreqFile>'s syntax is heavily borrowed from L<cpanfile>'s syntax.

It however has notable distinctions:

=over 4

=item * B<Conditional> I<Configuration> Feature Groups

=item * Static Human descriptions of conditions

=item * Executable code blocks that return true/false for feature group inclusion

=back

.

  providing $name => sub {
    condition $description => \&boolean_test;

    requires $module_name  => $version;
    on $phase => sub {
      requires $module_name  => $version;
    };
  };

=head2 C<providing>

Define a feature group for conditional inclusion ( Note this is B<DIFFERENT>
to C<cpanfile>'s C<feature> with special note of L<< C<condition>|/condition >>).

  providing $name, \&coderef

C<&coderef> will be called and all method calls inside it will
define a specification for a group named C<$name>

Valid only at global scope.

=head2 C<condition>

  condition $desc => \&test_code

Define a 2-part condition as a property of the current feature group ( C<providing> )

C<$desc> is used in exported metadata for humans to read, and it should describe in
a system agnostic way what condition the C<&test_code> is testing for in human terms.

C<&test_code> is attached to the feature group and is used during C<configure> to determine
which features to include.

This is valid only inside a C<providing> section.

=head2 C<requires>, C<recommends>, C<suggests>, C<conflicts>

These are the same as per L<< C<cpanfile>|cpanfile/SYNTAX >>'s definition of the same.

All are valid inside a C<providing> section and inside an C<on> section, but B<not>
inside C<condition>'s C<&test_code>.

=head2 C<on>

These are the same as per L<< C<cpanfile>|cpanfile/SYNTAX >>'s definition of the same,
B<EXCEPT> for phase C<configure>, which is B<Banned>:

All configure requirements must be satisfied I<Before> using C<DynPreqFile>
because there is no "second configure phase" after C<Makefile.PL> is run, so
stipulating extra configure requirements inside configure just cannot work.

All are valid inside a C<providing> section and inside an C<on> section, but B<not>
inside C<condition>'s C<&test_code>.

=head2 C<feature>, C<*_requires>

These features are B<NOT> available as C<feature> and C<providing> are presently
considered to have no usable feature overlaps.

( And you can probably implement C<feature> with C<providing> in some regards )
