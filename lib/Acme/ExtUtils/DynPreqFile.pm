use 5.006;    # our
use strict;
use warnings;

package Acme::ExtUtils::DynPreqFile;

sub _clean_eval {
  ## no critic (ProhibitStringyEval, RequireCheckingReturnValueOfEval, Lax::ProhibitStringyEval::ExceptForRequire)
  eval $_[0];
}

our $VERSION = '0.001000';
use constant EUMM_VERSION => do { require ExtUtils::MakeMaker; $ExtUtils::MakeMaker::VERSION };

# ABSTRACT: Structured Dynamic Prerequisites and Metadata extraction.

# AUTHORITY

sub new {
  my ( $class, $file ) = @_;
  return bless { file => $file }, $class;
}

sub metadata {
  my $meta = $_[0]->_metadata;
  my $out  = {};
  for my $feature ( sort keys %{$meta} ) {
    $out->{$feature} = {
      condition => $meta->{$feature}->{condition}->{description},
      prereqs   => { %{ $meta->{$feature}->{prereqs} } }
    };
  }
  return $out;
}

sub _autoflush_fh {
  my ( $filehandle, $new_value ) = @_;
  ## no critic (ProhibitOneArgSelect, RequireLocalizedPunctuationVars)
  my $old_filehandle = select $filehandle;
  my $old_value      = $|;
  $| = $new_value;
  select $old_filehandle;
  return $old_value;
}

sub configure {
  my ($self) = @_;
  my $meta   = $self->_metadata;
  my $rs     = Acme::ExtUtils::DynPreqFile::Result->new();

  my $old_autoflush = _autoflush_fh( *STDERR, 1 );
  for my $provide ( sort keys %{$meta} ) {
    ## no critic (RequireCheckedSyscalls)
    print {*STDERR} q[- ] . $provide . qq[\n];
    print {*STDERR} q[  * ] . $meta->{$provide}->{condition}->{description} . q[? ];
    my $result = $meta->{$provide}->{condition}->{code}->();
    if ($result) {
      print {*STDERR} "[Y]\n";
    }
    else {
      print {*STDERR} "[N]\n";
    }
    $rs->add_result( $result, $provide, $meta->{$provide}->{prereqs} );
  }
  _autoflush_fh( *STDERR, $old_autoflush );
  return $rs;
}

sub _eumm_version {
  my ($v) = @_;
  require ExtUtils::MakeMaker;
  return eval { ExtUtils::MakeMaker->VERSION($v) };
}

sub eumm_merge_metadata {
  my ( $self, $wma ) = @_;
  $wma->{META_ADD} = {} unless exists $wma->{META_ADD};
  $wma->{META_ADD}->{'meta-spec'} = { version => 2 } unless exists $wma->{META_ADD}->{'meta-spec'};
  $wma->{META_ADD}->{'x_dynamic_prereqs'} = $self->metadata;
}

sub _metadata {
  return $_[0]->{metadata} if exists $_[0]->{metadata};
  return $_[0]->{metadata} = $_[0]->_load_metadata;
}

my $_SERIAL = 1;

sub _load_metadata {
  my $file    = $_[0]->{file};
  my $content = do {
    ## no critic (RequireBriefOpen)
    open my $fh, '<', $file or die "Can't open $file, $?";
    local $/ = undef;
    scalar <$fh>;
  };
  my $package = __PACKAGE__ . '::_ANON_::Instance' . $_SERIAL++;
  my $prelude = $_[0]->_prelude( $package, 1, $file );
  local $@ = undef;
  _clean_eval( $prelude . $content );
  die $@ if $@;
  return $package->_meta_;
}

sub _prelude {
  my ( undef, $package, $line, $file ) = @_;
  return <<"EOF";
#file "${\__FILE__}"
#line ${\(__LINE__+1)} "${\__FILE__}"
use strict;
use warnings;
package $package;
our \$META;
our \$PROVIDING;
our \$ON_PHASE;
our %LEGAL_PHASES = (
  build => 1,
  runtime => 1,
  test => 1,
  develop => 1,
);
BEGIN { \$META      = Acme::ExtUtils::DynPreqFile::Config->new() }
BEGIN { \$ON_PHASE  = 'runtime' }
sub _meta_ { \$META }
sub condition(\$\$) {
  if ( not defined \$PROVIDING ) {
    die "on invalid outside <providing>";
  }
  \$META->add_condition( \$PROVIDING, \@_ );
}
sub provides(\$\$) {
  local \$PROVIDING = \$_[0];
  \$META->add_provide( \$PROVIDING );
  \$_[1]->();
  \$META->finalize_provide( \$PROVIDING );
}
sub on(\$\$) {
  local \$ON_PHASE = \$_[0];
  if ( not defined \$PROVIDING ) {
    die "on invalid outside PROVIDING";
  }
  if ( not exists \$LEGAL_PHASES{\$ON_PHASE} ) {
    die "\$ON_PHASE is not a valid phase";
  }
  \$_[1]->();
}
sub requires(\$;\$) {
  \$META->add_requirement(\$PROVIDING, \$ON_PHASE, 'requires', \@_ );
}
sub recommends(\$;\$) {
  \$META->add_requirement(\$PROVIDING, \$ON_PHASE, 'recommends', \@_ );
}
sub suggests(\$;\$) {
  \$META->add_requirement(\$PROVIDING, \$ON_PHASE, 'suggests', \@_ );
}
sub conflicts(\$;\$) {
  \$META->add_requirement(\$PROVIDING, \$ON_PHASE, 'conflicts', \@_ );
}
#file "$file"
#line $line "$file"
EOF
}

package    # Hide from PAUSE
  Acme::ExtUtils::DynPreqFile::Config;

sub new { bless {}, $_[0] }

sub add_provide {
  if ( exists $_[0]->{ $_[1] } ) {
    die "provide target $_[1] already defined";
  }
  $_[0]->{ $_[1] } = {};
}

sub finalize_provide {
  if ( not exists $_[0]->{ $_[1] } ) {
    die "provide target $_[1] not defined, can't finalize";
  }
  if ( not exists $_[0]->{ $_[1] }->{condition} ) {
    die "provide target $_[1] has no condition defined, can't finalize";
  }
  if ( not exists $_[0]->{ $_[1] }->{prereqs} ) {
    die "provide target $_[1] has no prereqs defined, can't finalize";
  }
}

sub add_condition {
  if ( not exists $_[0]->{ $_[1] } ) {
    die "provide target $_[1] not defined, can't add condition";
  }
  if ( exists $_[0]->{ $_[1] }->{condition} ) {
    die "provide target $_[1] already has a condition";
  }
  $_[0]->{ $_[1] }->{condition} = {
    description => $_[2],
    code        => $_[3],
  };
}

sub add_requirement {
  if ( not exists $_[0]->{ $_[1] } ) {
    die "provide target $_[1] not defined, can't add requirement";
  }
  $_[0]->{ $_[1] }->{prereqs} = {} unless exists $_[0]->{ $_[1] }->{prereqs};
  my $prereqs = $_[0]->{ $_[1] }->{prereqs};
  $prereqs->{ $_[2] } = {} unless exists $prereqs->{ $_[2] };
  $prereqs->{ $_[2] }->{ $_[3] } = {} unless exists $prereqs->{ $_[2] }->{ $_[3] };
  my $version = defined $_[5] ? $_[5] : 0;
  if ( not exists $prereqs->{ $_[2] }->{ $_[3] }->{ $_[4] } ) {
    $prereqs->{ $_[2] }->{ $_[3] }->{ $_[4] } = $version;
  }
  else {
    warn "Clobbering $_[1]/prereqs/$_[2].$_[3]'s $_[4] = $version";
    $prereqs->{ $_[2] }->{ $_[3] }->{ $_[4] } = $version;
  }
}

package    # Hide from PAUSE
  Acme::ExtUtils::DynPreqFile::Result;

sub new { bless { results => {} }, $_[0] }

sub add_result {
  my ( $self, $state, $name, $prereqs ) = @_;
  $self->{results}->{$name} = {
    state   => $state,
    prereqs => $prereqs,
  };
}

sub configured_requirements {
  my ($self) = @_;
  my $prereqs = {};
  for my $result ( sort keys %{ $self->{results} } ) {
    next unless $self->{results}->{$result}->{state};
    ## TODO: Proper merging
    for my $phase ( sort keys %{ $self->{results}->{$result}->{prereqs} } ) {
      for my $rel ( sort keys %{ $self->{results}->{$result}->{prereqs}->{$phase} } ) {
        for my $module ( sort keys %{ $self->{results}->{$result}->{prereqs}->{$phase}->{$rel} } ) {
          $prereqs->{$phase}->{$rel}->{$module} = $self->{results}->{$result}->{prereqs}->{$phase}->{$rel}->{$module};
        }
      }
    }
  }
  return $prereqs;
}

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
