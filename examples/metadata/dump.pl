#!perl
use strict;
use warnings;

use Acme::ExtUtils::DynPreqFile;
use Path::Tiny qw(path);
use Data::Dump qw(pp);

my $config = Acme::ExtUtils::DynPreqFile->new( path(__FILE__)->sibling('dynpreqfile') );
pp($config->metadata);

__END__
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
