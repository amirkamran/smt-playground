There are two shell scripts one is "index" and the other is "score" and a default configuration file.

To index a corpus:
./index inputfile=<filename>

To query:
./score inputfile=<filename>

if the inputfile parameter is not provided the script  will expect the input from console, an empty line will terminate the input.

the scripts will run with the default configuration specified in the config.properties file.
to override the configuration variables, it can be passed through command line ... use the same name as in the configuration file e.g. to specify the directory for indexes:

./index inputfile=<filename> lucene.index.directory=/some/location

make sure that the path you provide for index directory is empty because the script will remove all the files in the directory before proceeding.

similarly to specify the output format:

./score inputfile=<filename> output.format="ID|SCORE|TEXT"

if fulltext output is not required ... output.format="ID|SCORE" ... any combination of these three columns for output format can be used delimited by pipe sign.
