#!perl
use strict;
use warnings;

use Acme::ExtUtils::DynPreqFile;
use Path::Tiny qw(path);
use Data::Dump qw(pp);

my $config            = Acme::ExtUtils::DynPreqFile->new( path(__FILE__)->sibling('dynpreqfile') );

warn "\n\n#### AUTHOR TIME ####\n";
warn "---------------------\n\n";
{
  my %WriteMakefileArgs = ();

  warn "This is the metadata that would be injected in META.json and shipped\n\n";
  pp( $config->metadata );

  warn "\nAugmented WriteMakefileArgs:\n\n";
  $config->eumm_merge_metadata( \%WriteMakefileArgs );
  pp( \%WriteMakefileArgs );
}

warn "\n\n#### INSTALL TIME ####\n";
warn "----------------------\n\n";

{
  my %WriteMakefileArgs = ();

  my $result = $config->configure;

  warn "\nComputed install-time requirements are:\n\n";
  pp( $result->configured_requirements );

  warn "\nAugmented MakefileArgs:\n\n";
  $result->eumm_merge_config( \%WriteMakefileArgs );
  pp( \%WriteMakefileArgs );

}

__END__



#### AUTHOR TIME ####
---------------------

This is the metadata that would be injected in META.json and shipped

{
  "Perl 4 Support" => {
                        condition => "Perl is not at least version 5",
                        prereqs   => {
                                       build   => { suggests => { "Fake::Module::Perl4::Suggested" => 4 } },
                                       runtime => { requires => { "Fake::Module::Perl4" => 0 } },
                                     },
                      },
  "Perl 5 Support" => {
                        condition => "Perl is at least version 5",
                        prereqs   => { runtime => { requires => { "Fake::Module::Perl5" => 0 } } },
                      },
}

Augmented WriteMakefileArgs:

{
  META_ADD => {
    "meta-spec" => { version => 2 },
    "x_dynamic_prereqs" => {
      "Perl 4 Support" => {
                            condition => "Perl is not at least version 5",
                            prereqs   => {
                                           build   => { suggests => { "Fake::Module::Perl4::Suggested" => 4 } },
                                           runtime => { requires => { "Fake::Module::Perl4" => 0 } },
                                         },
                          },
      "Perl 5 Support" => {
                            condition => "Perl is at least version 5",
                            prereqs   => { runtime => { requires => { "Fake::Module::Perl5" => 0 } } },
                          },
    },
  },
}


#### INSTALL TIME ####
----------------------

- Perl 4 Support
  * Perl is not at least version 5? [N]
- Perl 5 Support
  * Perl is at least version 5? [Y]

Computed install-time requirements are:

{ runtime => { requires => { "Fake::Module::Perl5" => 0 } } }

Augmented MakefileArgs:

{
  META_ADD  => {
                 prereqs => { runtime => { requires => { "Fake::Module::Perl5" => 0 } } },
               },
  PREREQ_PM => { "Fake::Module::Perl5" => 0 },
}
