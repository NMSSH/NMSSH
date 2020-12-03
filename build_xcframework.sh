#!/bin/sh

# Abort if any command fails
set -e

WORKSPACE="NMSSH.xcodeproj"
PROJECT_IOS="NMSSH-iOS.xcodeproj"
OUTPUT_FOLDER="output"

DEVICE_ARCHIVE="$OUTPUT_FOLDER/NMSSH.framework-iphoneos.xcarchive"
SIMULATOR_ARCHIVE="$OUTPUT_FOLDER/NMSSH.framework-iphonesimulator.xcarchive"
CATALYST_ARCHIVE="$OUTPUT_FOLDER/NMSSH.framework-catalyst.xcarchive"
MAC_ARCHIVE="$OUTPUT_FOLDER/NMSSH.framework-mac.xcarchive"

XCFRAMEWORK_NAME="NMSSH.xcframework"
XCFRAMEWORK_PATH="$OUTPUT_FOLDER/$XCFRAMEWORK_NAME"

FRAMEWORK_SUBPATH="Products/Library/Frameworks/NMSSH.framework"
DSYM_SUBPATH="dSYMs/NMSSH.framework.dSYM"


rm -rf "$OUTPUT_FOLDER"
mkdir "$OUTPUT_FOLDER"



# Device slice.
xcodebuild archive -project "$PROJECT_IOS" -scheme 'NMSSH' -configuration Release -destination 'generic/platform=iOS' -archivePath "$DEVICE_ARCHIVE" SKIP_INSTALL=NO

# Simulator slice.
xcodebuild archive -project "$PROJECT_IOS" -scheme 'NMSSH' -configuration Release -destination 'generic/platform=iOS Simulator' -archivePath "$SIMULATOR_ARCHIVE" SKIP_INSTALL=NO

# Mac Catalyst slice.
#xcodebuild archive -project "$PROJECT_IOS" -scheme 'NMSSH' -configuration Release -destination 'generic/platform=macOS,arch=x86_64h' -archivePath "$CATALYST_ARCHIVE" SKIP_INSTALL=NO

# Mac slice.
#xcodebuild archive -project "$WORKSPACE" -scheme 'NMSSH' -configuration Release -destination 'platform=macOS' -archivePath "$MAC_ARCHIVE" SKIP_INSTALL=NO


# Create the XCFramework
xcodebuild -create-xcframework \
	-framework "$DEVICE_ARCHIVE/$FRAMEWORK_SUBPATH" \
	-debug-symbols "$PWD/$DEVICE_ARCHIVE/$DSYM_SUBPATH" \
	-output "$XCFRAMEWORK_PATH"



# Zip
pushd "$OUTPUT_FOLDER"
zip -vr "$XCFRAMEWORK_NAME.zip" "$XCFRAMEWORK_NAME" -x "*.DS_Store"
popd


CHECKSUM=`swift package compute-checksum "$XCFRAMEWORK_PATH.zip"`

echo "Checksum: $CHECKSUM"