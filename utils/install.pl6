bash "perl Makefile.PL";
bash "make clean";
bash "perl Makefile.PL";
bash "make";
bash "make test";
bash "make install";
