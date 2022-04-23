# FTP Client
**by Oleksandr Litus**

### High level approach
I have two files: 3700ftp and ftp.rb.
I decided to seperate ftp client functionality into a seperate 
class called FTP. There I implemented all the required commands 
for the FTP client/connection. I also added number of  wrapper 
functions, that make working with FTP connection more pleasant.
Commands that I implemented are devided into three groups:
send, request, and transfer. Send commands only send a message
using control channel and give back the answer. Request commands
send a message, open a data channel, and return both answer
from control channel and data from data channel. Transfer
commands send message through control channel, open data channel
and send given to them data over the data channel, then return
answer from control channel. I placed FTP class into ftp.rb.
My 3700ftp ended up being a cli specification of the app.
In 3700ftp I parse the commands, open FTP connection,
and call apropriate FTP commands from my class.

Note: my list command will not throw error, when given
directory does not exist on the FTP server. I decided 
to follow what FTP request does, that is return empty.
There was no specs about this in teh assignment,
I tried to search through RFC, but did not find anything.

### Challenges
- I did not have any major challenges
- I enjoed learning more about Ruby lanaguage
- I had some small troubles with listing the directory,
  as I used `gets()`, which only reads one line. I changed
  it to `read()` and fixed the problem
- It was kidna hard to parse the answers, but not that hard
- Overall, I liked the assignemnt and did not have probelems
  with emplementing the FTP protocol.

### Test Overview
I tested all of the commands by calling them from the cli,
and opening FTP conenction in Firefo, so I can see the
real content of the server.
For `ls` I tested root directory, empty nested directory,
multiple levels of nesting non empty directory, 
directory that does not exist.
For `mkdir` I tried creating directory in root,
in multiple nested directories.
For `rm` I tried removing file,
file that does not exist, file from multiple nested dirs.
For `rmdir` I tried removing empty directory,
directory with files, directory with directories,
empty directory nested in directories.
For `cp` I checked copying from local to the root server,
from local to multiple nested dirs on the server,
from root server to local,
from multiple nested dirs on server to local.
For `mv` I checked moving from local to the root server,
from local to multiple nested dirs on the server,
from root server to local,
from multiple nested dirs on server to local.
