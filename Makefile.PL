use inc::Module::Install;

# Define metadata
name           'Outthentic-DSL';

abstract       'outthentic DSL';

all_from       'lib/Outthentic/DSL.pm';

# Specific dependencies
requires    'Test::More';
requires    'Test::Harness';
license     'perl';
repository  'https://github.com/melezhik/outthentic-dsl';

WriteAll;


