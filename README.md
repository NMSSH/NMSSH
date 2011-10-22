# The Objective-C wrapper for libssh2

ObjSSH aims to be a full Objective-C wrapper for libssh2, with an API that is easy to understand and fun to work with.

To achieve that goal, the library will assume conventions but still make it easy to override them without writing ugly code.

Let's begin with some samples...

## Install the library

Drag and drop the project directory and all it's files in to your Xcode project. Then add the following header where you want to use the library.

    #include "ObjSSH.h"

## Connect to a server

    NSError *error;
    ObjSSH *ssh = [ObjSSH connectToHost:@"127.0.0.1" withUsername:@"user" password:@"ssh, secret!" error:&error];

It's that simple. Need to use another port? Set `connectToHost:@"127.0.0.1:456"`. No password? `password:nil`. Now, wasn't that nice and tidy?

ObjSSH also supports public/private key pairs. Connect using the flowing method:

    NSError *error;
    ObjSSH *ssh = [ObjSSH connectToHost:@"127.0.0.1" withUsername:@"user" publicKey:@"/home/user/.ssh/id_rsa.pub" privateKey:@"/home/user/.ssh/id_rsa" error:&error];

To disconnect just run:

    [ssh disconnect];
    [ssh release];

## Executing command

Executing a command is as simple as:

    NSError *error;
    NSString *response = [ssh execute:@"ls -la" error:&error];

The response from the command is conveniently returned as a `NSString`.

## Using SCP

Sending and fetching files is just as simple:

__Sending files__

    NSError *error;
    [ssh uploadFile:@"/local/file.txt" to:@"/remote/file.txt" error:&error];

__Fetching files__

    NSError *error;
    [ssh downloadFile:@"/remote/file.txt" to:@"/local/file.txt" error:&error];


## Licence

Copyright (c) 2011 Christoffer Lejdborg

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
