#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>


static void logMessage(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSMutableString *formattedString = [[NSMutableString alloc] initWithFormat:format
                                                                     arguments:args];
    va_end(args);

    if (![formattedString hasSuffix:@"\n"]) {
        [formattedString appendString:@"\n"];
    }

    NSData *formattedData = [formattedString dataUsingEncoding:NSUTF8StringEncoding];
    [NSFileHandle.fileHandleWithStandardOutput writeData:formattedData];
}

/*
 * Format a 32-bit code (for instance OSStatus) into a string.
 */
static char *codeToString(UInt32 code)
{
    static char str[5] = { '\0' };
    UInt32 swapped = CFSwapInt32HostToBig(code);
    memcpy(str, &swapped, sizeof(swapped));
    return str;
}

static NSString *formatStatusError(OSStatus status)
{
    if (status == noErr) {
        return [NSString stringWithFormat:@"No error (%d)", status];
    }

    return [NSString stringWithFormat:@"Error \"%s\" (%d)",
            codeToString(status),
            status];
}

static void assertStatusSuccess(OSStatus status)
{
    if (status != noErr)
    {
        logMessage(@"Got error %u: '%s'\n", status, codeToString(status));
        abort();
    }

}

static inline AudioObjectPropertyAddress makeGlobalPropertyAddress(AudioObjectPropertySelector selector)
{
    AudioObjectPropertyAddress address = {
        selector,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster,

    };
    return address;
}

static NSString *getStringProperty(AudioDeviceID deviceID,
                                   AudioObjectPropertySelector selector)
{
    AudioObjectPropertyAddress address = makeGlobalPropertyAddress(selector);
    CFStringRef prop;
    UInt32 propSize = sizeof(prop);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &prop);
    if (status != noErr) {
        return formatStatusError(status);
    }
    return (__bridge_transfer NSString *)prop;
}

static NSString *getURLProperty(AudioDeviceID deviceID,
                                AudioObjectPropertySelector selector)
{
    AudioObjectPropertyAddress address = makeGlobalPropertyAddress(selector);
    CFURLRef prop;
    UInt32 propSize = sizeof(prop);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &prop);
    if (status != noErr) {
        return formatStatusError(status);
    }

    NSURL *url = (__bridge_transfer NSURL *)prop;
    return url.absoluteString;
}

static NSString *getCodeProperty(AudioDeviceID deviceID,
                                 AudioObjectPropertySelector selector)
{
    AudioObjectPropertyAddress address = makeGlobalPropertyAddress(selector);
    UInt32 prop;
    UInt32 propSize = sizeof(prop);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &prop);
    if (status != noErr) {
        return formatStatusError(status);
    }

    return [NSString stringWithFormat:@"%s (%d)",
            codeToString(prop),
            prop];
}


static NSUInteger getChannelCount(AudioDeviceID deviceID,
                                  AudioObjectPropertyScope scope)
{
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyStreamConfiguration,
        scope,
        kAudioObjectPropertyElementMaster,
    };

    AudioBufferList streamConfiguration;
    UInt32 propSize = sizeof(streamConfiguration);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &streamConfiguration);
    assertStatusSuccess(status);

    NSUInteger channelCount = 0;
    for (NSUInteger i = 0; i < streamConfiguration.mNumberBuffers; i++)
    {
        channelCount += streamConfiguration.mBuffers[i].mNumberChannels;
    }

    return channelCount;
}

static NSString *getSourceName(AudioDeviceID deviceID,
                               AudioObjectPropertyScope scope)
{
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyDataSource,
        scope,
        kAudioObjectPropertyElementMaster,
    };

    UInt32 sourceCode;
    UInt32 propSize = sizeof(sourceCode);

    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &sourceCode);
    if (status != noErr) {
        return formatStatusError(status);
    }

    return [NSString stringWithFormat:@"%s (%d)",
            codeToString(sourceCode),
            sourceCode];
}

static void inspectDevice(AudioDeviceID deviceID)
{
    logMessage(@"Device %d", deviceID);
    logMessage(@" - UID:             %@", getStringProperty(deviceID, kAudioDevicePropertyDeviceUID));
    logMessage(@" - Model UID:       %@", getStringProperty(deviceID, kAudioDevicePropertyModelUID));
    logMessage(@" - Name:            %@", getStringProperty(deviceID, kAudioDevicePropertyDeviceNameCFString));
    logMessage(@" - Manufacturer:    %@", getStringProperty(deviceID, kAudioDevicePropertyDeviceManufacturerCFString));
    logMessage(@" - Input channels:  %@", @(getChannelCount(deviceID, kAudioObjectPropertyScopeInput)));
    logMessage(@" - Output channels: %@", @(getChannelCount(deviceID, kAudioObjectPropertyScopeOutput)));
    logMessage(@" - Input source:    %@", getSourceName(deviceID, kAudioObjectPropertyScopeInput));
    logMessage(@" - Output source:   %@", getSourceName(deviceID, kAudioObjectPropertyScopeOutput));
    logMessage(@" - Transport type:  %@", getCodeProperty(deviceID, kAudioDevicePropertyTransportType));
    logMessage(@" - Icon:            %@", getURLProperty(deviceID, kAudioDevicePropertyIcon));
}

static void inspectDeviceForSelector(AudioObjectPropertySelector selector)
{
    AudioDeviceID deviceID;
    UInt32 propSize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress address = makeGlobalPropertyAddress(selector);
    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &deviceID);
    assertStatusSuccess(status);
    inspectDevice(deviceID);
}

static void inspectAllDevices()
{
    // Check the number of devices.
    AudioObjectPropertyAddress address = makeGlobalPropertyAddress(kAudioHardwarePropertyDevices);
    UInt32 devicesDataSize;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                                     &address,
                                                     0,
                                                     NULL,
                                                     &devicesDataSize);
    assertStatusSuccess(status);

    // Get the devices.
    int count = devicesDataSize / sizeof(AudioDeviceID);
    AudioDeviceID deviceIDs[count];
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                        &address,
                                        0,
                                        NULL,
                                        &devicesDataSize,
                                        deviceIDs);
    assertStatusSuccess(status);

    // Inspect them.
    for (UInt32 i = 0; i < count; i++) {
        inspectDevice(deviceIDs[i]);
    }
}

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        logMessage(@"==== ALL DEVICES ====");
        inspectAllDevices();
        logMessage(@"");

        logMessage(@"==== DEFAULT INPUT DEVICE ====");
        inspectDeviceForSelector(kAudioHardwarePropertyDefaultInputDevice);
        logMessage(@"");

        logMessage(@"==== DEFAULT OUTPUT DEVICE ====");
        inspectDeviceForSelector(kAudioHardwarePropertyDefaultOutputDevice);
        logMessage(@"");
    }

    return 0;
}