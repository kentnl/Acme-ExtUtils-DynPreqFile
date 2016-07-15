#!perl
use strict;
use warnings;

use Acme::ExtUtils::DynPreqFile;
use Path::Tiny qw(path);
use Data::Dump qw(pp);

my $config = Acme::ExtUtils::DynPreqFile->new( path(__FILE__)->sibling('dynpreqfile') );
my $result = $config->configure;
pp( $result->configured_requirements );

__END__
- Perl 4 Support
  * Perl is not at least version 5? [N]
- Perl 5 Support
  * Perl is at least version 5? [Y]
{ runtime => { requires => { "Fake::Module::Perl5" => 0 } } }
