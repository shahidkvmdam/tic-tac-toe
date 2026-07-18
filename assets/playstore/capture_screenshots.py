import subprocess
import time
import os

DEVICE = "9645851777000CO"
ADB = r"C:\Users\DD\AppData\Local\Android\sdk\platform-tools\adb.exe"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

for i in range(1, 11):
    print(f"Screenshot {i}/10 will be taken in 5 seconds...")
    time.sleep(5)
    file_name = f"phone_shot_{i:02d}.png"
    local_path = os.path.join(OUT_DIR, file_name)
    subprocess.run([ADB, "-s", DEVICE, "shell", "screencap", "-p", f"/sdcard/{file_name}"], check=True)
    subprocess.run([ADB, "-s", DEVICE, "pull", f"/sdcard/{file_name}", local_path], check=True)
    print(f"Saved {local_path}")

print("All 10 screenshots captured.")
