use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'AUTHOR'	=> 'Andrew Maltsev <amaltsev@xao.com>',
    'ABSTRACT'	=> 'Symphero Low Level Data Modules',
    'NAME'	=> 'Symphero::Data',
    'VERSION'	=> '0.3',
    'PREREQ_PM'	=> { Error => 0.13
                   },

);
