Created : 03/03/2021
Updated : 07/03/2021

This zip file contains all files and folders to compile and create with 'MINIGUI' :
    Otis.exe
    Otis.lib

There is already a Otis folder in the \minigui\sample\advanced\Otis folder created by Grigory Filatov 
in a previous release of minigui.

Replace the folder by this zip file.

You find following files :

    makelib.bat             to create Otis.lib file
                            Otis.lib is also copied to the subfolder \test
                            and copied to the lib folder of harbour in minigui.
                  
    compile.bat             to create Otis.exe
    
    folder \test            Contains a small test program with Otis.lib in plugin mode.
                            This is the folder that Grigory created before in a previous release of minigui.
                  
    folder \Letodbf         Contains a full working LetoDbf server and a subfolder with a test Dbf.
                            Used by the \Test_LetoDbf folder.
                            
    folder \Test_LetoDbf    Contains a small test program. 
                            The same as in the \test folder but modified to test Otis with the LetDbf server.

    changelog.txt The same as in the root of github.
    
    ... others files necessary to compile and link Otis.
                  
Enjoy.
Hans
