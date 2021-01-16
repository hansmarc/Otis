## What is OTIS

Version 2021.01

Otis stands for '**O**pen **T**able **I**n**S**pector' and is a
database table inspection tool for Dbase, Clipper, Harbour,
xHarbour, FoxPro, ..., files.

Otis has a integrated **DATASET** **manager**. This need some
explanations.

A **DATASET** is a set of ONE or MORE tables and index files. You can save
this SET of files with a name and load it back again later on with only
one click. You can anytime you want add or delete tables and index files
to a existing dataset and save it again with the same or another name.

The dataset manager permits you to inspect tables when you are developing and testing a program without cycling through the classic operations like :

- open table, open index file, inspect, modify, update, close
- open another table, open index file, inspect, close
- ...etc.

Create simply a **dataset** with tables and index files that you want to
inspect on a regular base, save it, and reload all tables and index
files with only one click. I can assure you, you will save a lot of
time and many mouse clicks.

## Why did i create this tool (or rather rewrote)

This is in reality a implementation of a old clipper tool that i wrote,
i think, more than 20 years ago. But with far fewer possibilities as
this new tool that i called Otis. We integrated this module (the old
tool) in all our programs and protect it, if necessary, with a password.

Otis() helped me a lot of times for many many years already because it
permits me, on site, to inspect, modify or repair data in a table at
runtime on the fly in a simple and fast way. This without the necessity
to install other external dbf viewer programs.

In 'Plugin mode', you can use it also for runtime debugging  inspection
of a table. Thus see \'almost\' life updates from the running program.
No \'modal\' windows are used. By using this method, it permits you to
switch between the running program and this tool when you want. You can
even open multiple tables at the same time. Each table has its own
dbfviewer, called 'Inspector' and all tools. Special precautions are
taken for this mode to prevent data corruption when you try to modify a
table at the same time as the running program. More details for the
'Plugin mode' in another chapter.

You ask me \"Why rewrite yet another dbfviewer\" ?\
My answer, i found that there was always a thing missing in all other,
very known, existing programs like dbu, dba, dbfview, mgdbu, \...etc. So
i had to use one or more of them to view and or manipulate a dbf file. I
don't want to say that those programs were bad, rather the contrary. I
used them often, but i tried to regroup and integrate all possibilities
of all those separated tools in a single program. It is certainly
not perfect for everybody but i am open for suggestions.

I borrowed some code from other dbfviewer programs that are in the
sample folders of hmgextended. All concerned parts of the program
contains a remark and reference to the original source and author.

Another reason.\
I wanted to update / upgrade the visual design to a new level, like the
win10 flat design. I don\'t like toolbars with a lot of pull-down menus.
You have to click, click and click endless everywhere to discover what
is possible. My opinion is that a userinterface should be clear and
eye-catching. At first look all \"bells and whistles\" should be visible
and my experience ( \>30 years ) showed me that the first user
experience is very important for a program to be succesfull.

And not to forget, i could always count on the clipper harbour community
if i had a question.

So this is my way to contribute. It would be a pleasure if you do give
me some feedback.

**ENJOY**, i hope OTIS is of any use for you. Let me know ...

## What can you do with Otis :

>Support all Codepages known in Harbour.

>Support for the following RDD drivers :\

    DBFCDX
    DBFNTX
    DBFNSX
    SIXCDX
    LETODBF

    You can use a mix of rdd drivers in the same dataset.

>**Dataset manager (main screen) :**

- Open tables, multiselect with index AutoOpen (cdx) support.
- Attach index files to a table, multiselect support.
- Save multiple tables and index files in a Dataset.
- Load a Dataset.

>**Table viewer tool called the 'Inspector' :**
- Select a index / order.  ( Other options see index manager below. )
- Set a filter.
- Show / Hide deleted() records.
- Set / Clear a filelock.
 - Lock (freeze) columns on screen.
- Show / Hide columns.
- Search and replace data, file wide or fields only, with **SCOPE**, **FOR** and
**WHILE** expressions.
- Seek wizard :\
Presents a form with all fields used in the index KEY expression and autofills the seek expression.\
Seek first, Seek last and Set Exact on/off.\
Copy the 'seek expression' to the 'filter expression' textbox so that you can use the same expression to filter a table. Example, seek the first record and then show only records with the same field contents.
- Copy / paste a record :\
Paste a record to another record in the same table or\
Paste to another table.\
All fields or only a selection of fields in function of there visibility.
- Clear a record.
- Duplicate a record.\
Otis keeps into account the visibility of the columns/fields.
- Add / Insert records, one or more records at once.
- Up / Down, moves a record physically.
- Delete / Recall records with **SCOPE**, **FOR** and **WHILE** expressions.
- Pack / Zap a table.
- Append a file.
- Save a table to another table with the possibility to create a sub table.\
When a table is saved Otis takes into account active filters, index/orders and saves only visible fields. This permits to create a sub table with only the fields and data that you want.

>**Index manager :**

- Create a new index, single or compound index files.
- Delete a index, tag.
- Reindex all orders.
- View detailed index info with the possibility to copy this info to the clipboard.

>**Table and index properties viewer :**

- Export structure to a .csv file.
- Export structure to a .prg file. This prg can be used to create a table and all order index files.
- Export structure to the clipboard.
- View table info : filename, date, reccount, used rdd, used codepage, ...etc.
- View index info : list of all index files, tags, filenames, **KEY**, **FOR** and **WHILE** expressions.

>**Table structure editor :**
- Create a new structure.
- Modify a existing structure.
- Import a existing table structure to create a new table.
