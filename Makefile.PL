use 5.008;
use ExtUtils::MakeMaker;
WriteMakefile(
              'NAME'	=> 'WWW::Search::EbayUK',
              'VERSION' => '2.01',
              'PREREQ_PM' => {
                              'WWW::Search' => 2.27,
			      'WWW::Search::Test' => 2.12,
                              'HTML::TreeBuilder' => 2.27,
                             },
             );