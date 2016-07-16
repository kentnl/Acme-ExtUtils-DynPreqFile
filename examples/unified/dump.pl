#!perl
use strict;
use warnings;

use Acme::ExtUtils::DynPreqFile;
use Path::Tiny qw(path);
use Data::Dump qw(pp);

my $config = Acme::ExtUtils::DynPreqFile->new( path(__FILE__)->sibling('dynpreqfile') );
my %WriteMakefileArgs = ();

warn "Start of AuthorTime Only Logic\n";
warn "This is the metadata that would be injected in META.json and shipped\n\n";
pp( $config->metadata );
warn "\nAugmented WriteMakefileArgs:\n\n";
$config->eumm_merge_metadata(\%WriteMakefileArgs);
pp( \%WriteMakefileArgs );
warn "\nEnd Of AuthorTime Logic\n\n";

warn "Start of install-time only logic\n\n";
my $result = $config->configure;
warn "\nComputed install-time requirements are:\n\n";
pp( $result->configured_requirements );
warn "\nEnd of install-time logic\n";

__END__
Start of AuthorTime Only Logic
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

End Of AuthorTime Logic

Start of install-time only logic

- Perl 4 Support
  * Perl is not at least version 5? [N]
- Perl 5 Support
  * Perl is at least version 5? [Y]

Computed install-time requirements are:

{ runtime => { requires => { "Fake::Module::Perl5" => 0 } } }

End of install-time logic
