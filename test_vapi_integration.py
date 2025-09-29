#!/usr/bin/env python3
"""
Test script for Vapi.ai integration with XTTS API Server
"""
import requests
import json
import time
import wave
import struct

# Configuration
API_BASE = "http://35.80.239.175:8020"  # Your AWS server
VAPI_ENDPOINT = f"{API_BASE}/vapi/tts"
HEALTH_ENDPOINT = f"{API_BASE}/vapi/health"

def test_health_check():
    """Test the health check endpoint"""
    print("🔍 Testing health check endpoint...")
    try:
        response = requests.get(HEALTH_ENDPOINT)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Health check passed:")
            print(f"   Status: {data.get('status')}")
            print(f"   GPU Available: {data.get('gpu_available')}")
            print(f"   Default Speaker: {data.get('default_speaker')}")
            print(f"   Default Language: {data.get('default_language')}")
            print(f"   Supported Sample Rates: {data.get('supported_sample_rates')}")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health check error: {e}")
        return False

def test_vapi_tts(text="Hello from Vapi.ai integration!", sample_rate=22050):
    """Test the Vapi.ai TTS endpoint"""
    print(f"🎤 Testing Vapi.ai TTS endpoint...")
    print(f"   Text: {text}")
    print(f"   Sample Rate: {sample_rate}")

    # Prepare Vapi.ai format request
    request_data = {
        "type": "voice-request",
        "text": text,
        "sampleRate": sample_rate,
        "timestamp": int(time.time())
    }

    try:
        start_time = time.time()
        response = requests.post(
            VAPI_ENDPOINT,
            json=request_data,
            headers={"Content-Type": "application/json"}
        )
        end_time = time.time()

        if response.status_code == 200:
            # Check response headers
            content_type = response.headers.get('content-type', '')
            content_length = response.headers.get('content-length', 0)

            print(f"✅ TTS request successful:")
            print(f"   Response time: {end_time - start_time:.2f}s")
            print(f"   Content-Type: {content_type}")
            print(f"   Content-Length: {content_length} bytes")
            print(f"   Data size: {len(response.content)} bytes")

            # Save PCM data for verification
            if response.content:
                pcm_filename = f"test_output_{sample_rate}hz.pcm"
                with open(pcm_filename, 'wb') as f:
                    f.write(response.content)
                print(f"   Saved PCM data to: {pcm_filename}")

                # Convert PCM to WAV for testing
                wav_filename = f"test_output_{sample_rate}hz.wav"
                convert_pcm_to_wav(response.content, wav_filename, sample_rate)
                print(f"   Converted to WAV: {wav_filename}")

                return True
            else:
                print("❌ No audio data received")
                return False
        else:
            print(f"❌ TTS request failed: {response.status_code}")
            try:
                error_data = response.json()
                print(f"   Error: {error_data.get('detail', 'Unknown error')}")
            except:
                print(f"   Raw response: {response.text}")
            return False

    except Exception as e:
        print(f"❌ TTS request error: {e}")
        return False

def convert_pcm_to_wav(pcm_data, wav_filename, sample_rate):
    """Convert raw PCM data to WAV file for testing"""
    try:
        # PCM data is 16-bit signed integers, mono
        num_samples = len(pcm_data) // 2

        with wave.open(wav_filename, 'wb') as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 16-bit (2 bytes)
            wav_file.setframerate(sample_rate)
            wav_file.writeframes(pcm_data)

        print(f"   WAV file created: {num_samples} samples, {sample_rate}Hz")

    except Exception as e:
        print(f"   ⚠️  WAV conversion error: {e}")

def test_multiple_sample_rates():
    """Test multiple sample rates supported by Vapi.ai"""
    sample_rates = [8000, 16000, 22050, 24000]

    for rate in sample_rates:
        print(f"\n📊 Testing sample rate: {rate}Hz")
        success = test_vapi_tts(
            text=f"Testing audio generation at {rate} Hz sample rate.",
            sample_rate=rate
        )
        if not success:
            print(f"❌ Failed at {rate}Hz")
        else:
            print(f"✅ Success at {rate}Hz")

def test_error_cases():
    """Test error handling"""
    print("\n🚨 Testing error cases...")

    # Test invalid request type
    print("   Testing invalid request type...")
    response = requests.post(VAPI_ENDPOINT, json={
        "type": "invalid-type",
        "text": "test",
        "sampleRate": 22050,
        "timestamp": int(time.time())
    })
    print(f"   Invalid type: {response.status_code} (expected 400)")

    # Test invalid sample rate
    print("   Testing invalid sample rate...")
    response = requests.post(VAPI_ENDPOINT, json={
        "type": "voice-request",
        "text": "test",
        "sampleRate": 12000,  # Not supported
        "timestamp": int(time.time())
    })
    print(f"   Invalid sample rate: {response.status_code} (expected 400)")

    # Test empty text
    print("   Testing empty text...")
    response = requests.post(VAPI_ENDPOINT, json={
        "type": "voice-request",
        "text": "",
        "sampleRate": 22050,
        "timestamp": int(time.time())
    })
    print(f"   Empty text: {response.status_code} (expected 400)")

def main():
    print("🧪 XTTS API Server - Vapi.ai Integration Test")
    print("=" * 50)

    # Test health check
    if not test_health_check():
        print("❌ Health check failed, aborting tests")
        return

    print("\n" + "=" * 50)

    # Test basic TTS
    success = test_vapi_tts()
    if not success:
        print("❌ Basic TTS test failed")
        return

    # Test multiple sample rates
    test_multiple_sample_rates()

    # Test error cases
    test_error_cases()

    print("\n" + "=" * 50)
    print("🎉 Vapi.ai integration tests completed!")
    print("\n📋 Next steps:")
    print("1. Check generated audio files for quality")
    print("2. Configure Vapi.ai to use your TTS endpoint")
    print("3. Set up authentication if needed")

if __name__ == "__main__":
    main()