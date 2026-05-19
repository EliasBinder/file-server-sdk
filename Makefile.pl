use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'FileServerSdk',
    VERSION_FROM  => 'lib/FileServerSdk/Client.pm',
    ABSTRACT_FROM => 'README.md',
    AUTHOR        => 'Elias Binder <elias.binder@hs-coburg.de>',
    LICENSE       => 'perl',

    # Minimum Perl version
    MIN_PERL_VERSION => '5.014',

    # Build requirements
    BUILD_REQUIRES => {
        'Test::More' => '0.98',
    },

    # Runtime requirements (the important part for dependencies!)
    PREREQ_PM => {
        'Net::Amazon::S3' => '0.98',
        'JSON'            => '2.90',
        'HTTP::Tiny'      => '0.070',
        'CGI'             => '4.38',
        'Digest::SHA'     => '6.04',
    },

    # Recommended for modern Perl
    META_MERGE => {
        resources => {
            repository => 'https://github.com/yourusername/file-server-sdk',
        },
    },
);
