use 5.008;
use ExtUtils::MakeMaker;
WriteMakefile(
              'NAME'	=> 'WWW::Search::EbayUK',
              'VERSION' => '2.00',
              'PREREQ_PM' => {
                              # The module's version, not the
                              # distribution's version:
                              # 'WWW::Search' => 2.27,
                              'WWW::Search::Test' => 2.12,
                             },
             );
