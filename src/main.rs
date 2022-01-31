extern crate coreaudio;

use coreaudio::sys::*;
use std::ffi::{c_void, CString};
use std::mem;
use std::os::raw::c_char;
use std::ptr;

fn main() {
    let devices = get_audio_devices();

    match devices {
        Ok(devices) => {
            for device_id in devices {
                let device_name = get_audio_device_name(device_id).unwrap();
                println!("{}", device_name);
            }
        }
        Err(e) => {
            println!("Error: {}", e);
        }
    };
}

fn get_audio_devices() -> Result<Vec<AudioDeviceID>, OSStatus> {
    let property_address = AudioObjectPropertyAddress {
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster,
    };

    let mut property_size: u32 = 0;
    let audio_object_id = kAudioObjectSystemObject;

    let mut err_code = unsafe {
        AudioObjectGetPropertyDataSize(
            audio_object_id,
            &property_address,
            0,
            ptr::null(),
            &mut property_size,
        )
    };

    if err_code != kAudioHardwareNoError as i32 {
        return Err(err_code);
    }

    let num_devices = property_size / mem::size_of::<AudioObjectID>() as u32;

    let mut device_ids: Vec<AudioDeviceID> = Vec::with_capacity(num_devices.try_into().unwrap());

    unsafe {
        err_code = AudioObjectGetPropertyData(
            kAudioObjectSystemObject,
            &property_address,
            0,
            ptr::null(),
            &mut property_size,
            device_ids.as_mut_ptr() as *mut c_void,
        );

        if err_code != kAudioHardwareNoError as i32 {
            return Err(err_code);
        }

        device_ids.set_len(num_devices as usize);
    };

    return Ok(device_ids);
}

fn get_audio_device_name(device_id: AudioDeviceID) -> Result<String, OSStatus> {
    let property_address = AudioObjectPropertyAddress {
        mSelector: kAudioDevicePropertyDeviceName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMaster,
    };

    let mut property_size: u32 = mem::size_of::<[c_char; 64]>().try_into().unwrap();
    let mut device_name: Vec<u8> = Vec::with_capacity(64);

    let cstring = unsafe {
        let err_code = AudioObjectGetPropertyData(
            device_id,
            &property_address,
            0,
            ptr::null(),
            &mut property_size,
            device_name.as_mut_ptr() as *mut c_void,
        );

        if err_code != kAudioHardwareNoError as i32 {
            return Err(err_code);
        }

        device_name.set_len(property_size as usize);

        CString::from_vec_unchecked(device_name)
    };

    return Ok(cstring.into_string().unwrap());
}
