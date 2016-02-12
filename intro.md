
# Outthentic DSL - informal introduction

[Outthentic DSL](https://github.com/melezhik/outthentic-dsl) is a language to parse 
and validate any unstructured text. 

Two clients are based on this engine to get job done:

* [swat](https://github.com/melezhik/swat) - web application testing tool.

* [outthentic](https://github.com/melezhik/outthentic) - generic purposes testing.

Creating a new outthentic clients - programs using Outthentic DSL API - is quite easy 
and everybody welcome to get involved. 

In this post I am trying to highlight some essential DSL features  
helping in automation text parsing, verification tasks, which are plenty of in our daily jobs, huh?

So, lets meet - outthentic DSL ...

# Basic check expressions

Check expressions are search patterns to validate original text input. 

Original text is parsed line by line and every line is matched against check expression.

If at least one line successfuly matches then check succeeds, 
if none of lines matches check fails. 

This procedure is repeated for all check expressions in the list.

There are two type of check expressions: 

* plain text expressions

* regular expressions patterns

Let see a simple example of DSL code:

     # two checks here     
     Hello # plain text expression 
     regexp: My name is outthentic\W # regular expression

This code will successfuly verifies this text input:

    Hello
    My name is outthentic!
   
And won't verify this one:

    hello
    My name is outthenticz


Well quite easy so far. Good.

# Greedy expressions

Outthentic check expressions

This is what I mean when I call them greedy. 

Consider this trivial example:


Text input:

    1
    2
    3

DSL code:

    regexp: (\d+)
    code: print "# ", scalar @{match_lines()}


match_line() function returns array of lines successfuly matched by _latest_ check,
we would talk about useful dsl function later, but what should be important for us
at the moment is the _length_ of array returned.
 
So the question is what it should be? Not too many variants for answer.

* 1 - nine greedy behavior 
* 3 - greedy behavior

And, yes, it will return 3! As outthentic parser is greedy one. It it tries to find 
matched lines as much as possible. In other words if parser successfuly find a line
matched check expression it won't stop and try to find others, as much as possible. 

That is why the match_lines array will hold 3 lines:

    1
    2
    3

Please take this behaviour into account when deal with outhentic dsl, sometimes
it is good, but sometimes it could be a problem, we will see how this could 
however changed in some cases. 


# Group check expressions

## Text blocks and ranges

Often we need to verify not only a single line occurrence but 
_sequence_ of lines or _set_ of  lines inside some range. This is where
outthentic group check expressions could be usefull.
 

Text blocks and range expressions abstraction for group check expressions. 

They could be treated as _containers_ for basic check expressions - plain text strings or regular expressions.

Let's first consider a text blocks.


## Text blocks. 

Text blocks expressions insists that a sequence of lines should be found at original text input.

Consider this imaginary text output with 3 text blocks:

    
    <triples>
        1
        2    
        3
    </triples>     

    <triples>
        10
        20    
        30
    </triples>     

    <triples>
        foo
        bar    
        baz
    </triples>     

Now we need to ensure that triples blocks are here. 

Let's write up outthentic dsl code:


    begin:
        <triples>
            regexp \S+
            regexp \S+
            regexp \S+
        </triples>
    end:

Quite self-explanatory so far. Let's add some debugging info here:

    begin:
        <triples>

            regexp \S+
            code: print "@{match_lines}\n";

            regexp \S+
            code: print "@{match_lines}\n";

            regexp \S+
            code: print "@{match_lines}\n";

        </triples>
    end:
  
When run this code we get:

    1 10 foo
    2 20 bar
    3 30 baz

As we learned match_lines() function return array of all successfuly matched lines,
so the result is quite obvious.

If we want to be more specific and see pieces of lines get captured with regular expression check
we could use captures() function, which is very similar to match_lines() function but only deals
with regular expressions checks. Lets find only triples blocks with 2 digits numbers inside and then
print out _second_ digit of every number:

     begin:
        <triples>

            regexp (\d)(\d)
            code: print "@{map {$_->[1]} @{captures()}}"

            regexp (\d)(\d)
            code: print "@{map {$_->[1]} @{captures()}}"


            regexp (\d)(\d)
            code: print "@{map {$_->[1]} @{captures()}}"

        </triples>
     end:

Ok, what is wrong with both match_lines() and captures() is what they _bind_ to the latest check expressions,
so if we need _accumulate_ data for all the text block we stuck and probably need something better.

Here we gave to use stream() function.

Let's rewrite our latest code
 
     begin:
        <triples>
            regexp: \S+
            regexp: \S+
            regexp: \S+
            code:                                           \
                for my $s (@{stream()}) {                   \
                    print " ",( join ' ', @{$s} ),"\n";    \
                }                                           \
                print "next block\n";                     
        </triples>
     end:

Much better! At least code became more concise and clear, no need to add this code:  ... cpature ...
line after every regexp check.


Streams are alternative for captures. While capture relates to latest regular expression checks
and get lost with the next expression check, stream instead _accumulate_ all matching lines and
_group them per blocks_, so  code above will print:


    1 10 foo
    next block
    2 20 bar
    next block
    3 30 baz

Pretty convenient now, because this is exactly the logical groups we have in original text input stream.

Now let look at the ranges, the look like text blocks but they are not the ones :-) !

## Ranges

Range expressions looks like text blocks, but only for the first glance, they are very effective
but a bit tricky to use for the beginners.

Let's reshape our solution for triples task. Verify that we have triples blocks with numbers inside:


     between: <triples> <\/triples> 
         regexp: \S+

That's it! More laconic than text blocks solution. A few comments here:

* between expression sets new search context for DSL parser, so that instead of looking
through all original input it narrows it search to area _between_ lines matching <triples>
and <\/triples> regular expression. It is very similar to what happen when one use 
[Perl range operator](http://perldoc.perl.org/perlop.html#Range-Operators) when selecting
subsets of lines out of stdin stream:

    while (<STDOUT>){
        if /<triples>/ ... /<\/triples>/
    }


Let's add some debug code to show what happening in more details:


     between: <triples> <\/triples> 
         regexp: (\S+)
         code: print # "", ( join ' ', map { $_->[0] } @{captures()} ), "\n"
    
We see then:

    # 1 10 foo 2 20 bar 3 30 baz

This mean that check expressions inside range block remain "greedy" in comparison with text block,
where they are none greedy.

Check expression inside range block "eat up" all matched lines 

Check expressions inside text block none greedy as line but such a line should be followed by certain other - a sequence
behavior. 

Other differences between text blocks and ranges.

* ranges do not preserve sort order for lines in original input

Consider this code snippet:

    # input data

    foo
        1
        2
        1
        2
    bar 

     between: foo bar 
         regexp: (1)
         code: print "# ", ( join ' ', map { $_->[0] } @{captures()} ), "\n"
         regexp: (2)
         code: print "# ", ( join ' ', map { $_->[0] } @{captures()} ), "\n"
 
A natural assumption that we get something like that:

    # 1 2
    # 1 2

But as check expression inside range blocks are greedy every expression "eat up" all the matching lines, 
so we will get this:

    # 1 1
    # 2 2

Compare with text block solution:

     begin: 
        foo 
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
            regexp: (\d+)
            code: print "# ", capture()->[0], "\n"
        bar    
     end:

    # 1 
    # 2 
    # 1 
    # 2 

Summary.

So when you want test a sequences ( continuous sets ) you need a text blocks. When you don't
care about ordering and just want to pick up some data included  in a given range you need a range
expressions. 
 
