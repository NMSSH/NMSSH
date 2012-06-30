# NMSSH

This is a complete rewrite of the previous NMSSH library. The goal is to
create a clean, easy-to-use, test driven Cocoa framework that wraps libssh2.

NMSSH was initially built for usage in [Kleio](http://9muses.se/kleio) - a Mac OSX application that simplifies continuous deployment.

**Using libssh2 version:** `1.4.2`

Are you using NMSSH for something cool? [Let me know](http://twitter.com/Lejdborg).

## Usage

### Install the framework

* Build the framework and add it to your project
* Add `#include <NMSSH/NMSSH.h>` to your source file.

### Connect to a server

#### 1. Create a new session

    NMSSHSession *session = [NMSSHSession connectToHost:@"127.0.0.1:22"
                                           withUsername:@"user"];

    if ([session isConnected]) {
        NSLog(@"Successfully created a new session");
    }

#### 2.1. Authenticate by password

    [session authenticateByPassword:@"pass"];

#### 2.2. Or by public key

    // Explicitly set the public key that should be used...
    // Pass nil as password parameter for unprotected keys
    [session authenticateByPublicKey:@"~/.ssh/id_rsa.pub"
                         andPassword:@"pass"];

#### 2.3. Or connect to a SSH agent

    [session connectToAgent];

#### 3. Check if authentication was successful

    if ([session isAuthorized]) {
        NSLog(@"Authentication succeeded");
    }

#### 4. Don't forget to disconnect

    [session disconnect];
    session = nil;

### Using Channels (not yet implemented)

#### Executing shell commands

    NSError *error = nil;
    NSString *response = [[session channel] execute:@"echo foo" error:&error];
    NSLog(@"Response: %@", response);

#### SCP file transfer

The SCP API provides a simple way to upload or download files.

The `to:` parameter is flexible in that if you provide a directory, it will keep the same filename as in the from-parameter. But if you provide a complete file name you may name the transferred file anything you want.

#### Uploading files from your local computer

    BOOL success = [[session channel] uploadFile:@"~/my-local-file.txt" to:@"/var/www/"];

#### Downloading files from a server

    BOOL success = [[session channel] downloadFile:@"/var/www/my-remote-file.txt" to:@"~/"];

## Compatibility

NMSSH contains a pre-built libssh2 for Mac OSX. The framework should work just fine with iOS as well if you compile libssh2 yourself and switch the included `libssh2.dylib`.

## License

Copyright (c) 2012 Nine Muses AB

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
