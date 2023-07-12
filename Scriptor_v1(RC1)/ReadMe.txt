Scriptor & DeScriptor v0.73
---------------------------

Changes from 0.70
-Lots of small but important bug fixes that should smooth
 everything out.
 (Thanks go to Switeck for finding some critical bugs and letting me know about them)
-Rewrote half of DeScriptor. It doesn't go crazy with parentheses now.
-Implemented same options for TA as there was for TA:K in DeScriptor

Changes from 0.65
4/07/00  Wow, its been awile
-The compiler is completely new.
-Removed awkwerd goto commands in favor of if/else
-Now mandatory to put a get or set in front of unit values
-Integrated text editor
-Double click errors or warnings to take you to the line
-Fixed most the old bugs :)
-Created new ones :(
-Added include directory for standard libraries (exptype.h, smokeunit.h ...)
-Made a few libraries TAK compatible
-New exe contains both Scriptor and DeScriptor
-Descriptor decompiles the TAK map cobs
-Descriptor is nicer to cobbler made cobs
-Descriptor finally decompiles if/else blocks
-Probably more I can't remember

Changes from 0.61
DeScriptor Only
-Descriptor now guesses most static-vars and signals for TA:K cobs

Changes from 0.60

11/10/99
-Command Line support. Check instructions below.

Changes from 0.50:

11/8/99
-Added dont-shade command. Oversight on my part.
-PreProcessor is in. :)
-Fixed various bugs caused by typos in source.
-Improved Error reporting. Now tells line number. Ya.
-Settings are now saved. About time. 


Credit:

First off I would like to thank all those who 
provided info on .cob format and other TA Related stuff.

Dan Melchione
Ted Burg
Tim Burton
JoeD
Kinboat
Authors of Cobbler
Switeck
And anyone else I forgot to mention.

I would also like to thank Cavedog for their awsome games-TA,TA:K
I might of had a social life without them.


Disclaimer:

I assume no responsibility if your coputer explodes into flaming piles
of wreckage as a result of using my programs. That said, enjoy Scriptor
and DeScriptor. You can sell, distribute, pawn, mock, delete, claim
authorship, or do anything else with the programs that strikes your 
fancy.


Insatallation:

Umm... Unzip exe's and the .ini somewhere and execute em.
The Compiler.ini must be in the same dir as Scriptor.exe
Scriptor.exe and DeScriptor.exe are independent of each other so
you can put them in separate dirs.


Program Notes:

Scriptor:
Be sure to check what kind of .bos file you are compiling. TA or TAK
It does matter.
If there is a #define TA or #define TAK in your bos, it will override
the setting in the compiler.

DeScriptor:
There are a few options to consider.
 DeScripting Options
  Make Guesses: This lets DeScriptor try and guess on the statics and signals
  Show Inrement: Whenever DeScriptor finds something like a = a+1;
                 It will be replaced by ++a; Same for decrement.
  Large Numbers: DeScriptor will convert very large values found into
                 a Linear Value ie 163840 -> [1]
  Print returns: DeScriptor will print every return found in the cob

 Library Options
  Standard Libs: DeScriptor will replace a few standard scripts with 
                 it corresponding #include
  Animation Scripts: DeScriptor will separate these scripts into their
                     own file and replace them with an #include

 Debug Options
  Header Info:  Prints the .cob header at the beginning of the .bos
  Show Offsts:  Prints the script offset before each item in .bos
  Extra Info :  Prints pushes, jumps, operators etc...


----------
Known bugs
----------

Scriptor:

Still having some problems with post compilling cleanup. If you get an
error when compilling and then fix it, but another strange error or 
warning pops up, recompile again and it should work fine. When all else
fails, restart Scriptor and try again.

I've basicaly thrown nothing but valid code at the compiler so I
don't know how it react under other circumstances. Be warned.

Comments? Questions? Flames? Other?
email me at KhalvKalash@hotmail.com