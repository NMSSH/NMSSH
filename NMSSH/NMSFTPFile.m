//
//  NMSFTPFile.m
//  NMSSH
//
//  Created by Sebastian Hunkeler on 16/01/14.
//
//

#import "NMSFTPFile.h"
#import "libssh2_sftp.h"

@interface NMSFTPFile ()
@property (nonatomic, readwrite, strong) NSString* filename;
@property (nonatomic, readwrite) BOOL isDirectory;
@property (nonatomic, readwrite ,strong) NSDate* modificationDate;
@property (nonatomic, readwrite ,strong) NSDate* lastAccess;
@property (nonatomic, readwrite, strong) NSNumber* fileSize;
@property (nonatomic, readwrite) uid_t ownerUserID;
@property (nonatomic, readwrite) gid_t ownerGroupID;
@property (nonatomic, readwrite, strong) NSString* permissions;
@property (nonatomic, readwrite) NSUInteger flags;
@end

@implementation NMSFTPFile

- (id)initWithFilename:(NSString*)filename
{
    self = [super init];
    if (self) {
        self.filename = filename;
    }
    return self;
}

-(void)populateValuesFromSFTPAttributes:(LIBSSH2_SFTP_ATTRIBUTES)fileAttributes
{
    self.modificationDate = [NSDate dateWithTimeIntervalSince1970:fileAttributes.mtime];
    self.lastAccess = [NSDate dateWithTimeIntervalSinceNow:fileAttributes.atime];
    self.fileSize = @(fileAttributes.filesize);
    self.ownerUserID = fileAttributes.uid;
    self.ownerGroupID = fileAttributes.gid;
    self.permissions = [self convertPermissionToSymbolicNotation:fileAttributes.permissions];
    self.isDirectory = LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions);
    self.flags = fileAttributes.flags;
}

/**
 Ensures that the sorting of the files is according to their filenames.
 
 @param aFile The other file that it should be compared to.
 @return The comparison result that determins the order of the two files.
 */
-(NSComparisonResult)compare:(NMSFTPFile*)aFile
{
    return [self.filename compare:aFile.filename options:NSCaseInsensitiveSearch];
}

/**
 Convert a mode field into "ls -l" type perms field. By courtesy of Jonathan Leffler
 http://stackoverflow.com/questions/10323060/printing-file-permissions-like-ls-l-using-stat2-in-c
 
 @param mode The numeric mode that is returned by the 'stat' function
 @return A string containing the symbolic representation of the file permissions.
 */
-(NSString*) convertPermissionToSymbolicNotation:(int)mode
{
    static char *rwx[] = {"---", "--x", "-w-", "-wx", "r--", "r-x", "rw-", "rwx"};
    char bits[11];
    
    bits[0] = [self filetypeletter:mode];
    strcpy(&bits[1], rwx[(mode >> 6)& 7]);
    strcpy(&bits[4], rwx[(mode >> 3)& 7]);
    strcpy(&bits[7], rwx[(mode & 7)]);
    if (mode & S_ISUID)
        bits[3] = (mode & 0100) ? 's' : 'S';
    if (mode & S_ISGID)
        bits[6] = (mode & 0010) ? 's' : 'l';
    if (mode & S_ISVTX)
        bits[9] = (mode & 0100) ? 't' : 'T';
    bits[10] = '\0';
    return [NSString stringWithCString:bits encoding:NSUTF8StringEncoding];
}

/**
 Extracts the unix letter for the file type of the given permission value.
 
 @param mode The numeric mode that is returned by the 'stat' function
 @return A character that represents the given file type.
 */
-(char)filetypeletter:(int) mode
{
    char    c;
    
    if (S_ISREG(mode))
        c = '-';
    else if (S_ISDIR(mode))
        c = 'd';
    else if (S_ISBLK(mode))
        c = 'b';
    else if (S_ISCHR(mode))
        c = 'c';
#ifdef S_ISFIFO
    else if (S_ISFIFO(mode))
        c = 'p';
#endif  /* S_ISFIFO */
#ifdef S_ISLNK
    else if (S_ISLNK(mode))
        c = 'l';
#endif  /* S_ISLNK */
#ifdef S_ISSOCK
    else if (S_ISSOCK(mode))
        c = 's';
#endif  /* S_ISSOCK */
#ifdef S_ISDOOR
    /* Solaris 2.6, etc. */
    else if (S_ISDOOR(mode))
        c = 'D';
#endif  /* S_ISDOOR */
    else
    {
        /* Unknown type -- possibly a regular file? */
        c = '?';
    }
    return c;
}

@end
