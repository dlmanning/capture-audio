#include <CoreFoundation/CoreFoundation.h>
#include <CoreAudio/CoreAudio.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <memory.h>

char *osStatusIntoCString(OSStatus errCode, char *msg)
{
  long *code = (long *)msg;
  *code = CFSwapInt32HostToBig(errCode);

  msg[5] = '\0';

  return msg;
}

int main()
{
  AudioObjectPropertyAddress property_address;

  property_address.mSelector = kAudioHardwarePropertyDevices;
  property_address.mScope = kAudioObjectPropertyScopeGlobal;
  property_address.mElement = kAudioObjectPropertyElementMaster;

  uint32_t property_size = 0;
  AudioObjectID audio_object_id = kAudioObjectSystemObject;

  OSStatus errCode = AudioObjectGetPropertyDataSize(audio_object_id, &property_address, 0, NULL, &property_size);

  if (errCode == noErr)
  {
    int num_devices = (int)property_size / sizeof(AudioDeviceID);

    AudioDeviceID *device_ids = malloc(sizeof(AudioDeviceID) * num_devices);

    errCode = AudioObjectGetPropertyData((AudioObjectID)kAudioObjectSystemObject, &property_address, 0, NULL, &property_size, device_ids);
    if (errCode == noErr)
    {
      AudioObjectPropertyAddress device_address;
      char device_name[128];
      CFURLRef model_uid;

      for (int idx = 0; idx < num_devices; idx++)
      {
        property_size = sizeof(device_name);

        device_address.mSelector = kAudioDevicePropertyDeviceName;
        device_address.mScope = kAudioObjectPropertyScopeGlobal;
        device_address.mElement = kAudioObjectPropertyElementMaster;

        errCode = AudioObjectGetPropertyData(device_ids[idx], &device_address, 0, NULL, &property_size, &device_name);
        if (errCode == noErr)
        {
          property_size = sizeof(model_uid);
          char buf[2048];
          printf("%i\n", property_size);

          device_address.mSelector = kAudioDevicePropertyIcon;
          device_address.mScope = kAudioObjectPropertyScopeGlobal;
          device_address.mElement = kAudioObjectPropertyElementMaster;

          errCode = AudioObjectGetPropertyData(device_ids[idx], &device_address, 0, NULL, &property_size, &model_uid);
          if (errCode != noErr)
          {
            // char err_msg[5];
            osStatusIntoCString(errCode, buf);
            printf("%i\n", property_size);
          }

          // CFStringRef url_string = CFURLCopyPath(model_uid);
          // CFStringGetCString(url_string, buf, sizeof(buf), kCFStringEncodingASCII);
          printf("Device [%i]:\n  name: %s, \n  device_uid: %s\n", device_ids[idx], device_name, buf);
          // CFRelease(url_string);
        }
      }

      if (errCode == noErr)
      {
        return 0;
      }
    }
  }
  else
  {
    char msg[5];
    printf("Error %s\n", osStatusIntoCString(errCode, msg));
  }

  return 0;
}
