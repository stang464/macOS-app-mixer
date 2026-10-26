# AppMixer 0.4.2 — native macOS prototype

แอปบนแถบเมนูสำหรับปรับระดับเสียงและ mute แยกแต่ละแอป เขียนด้วย SwiftUI, AppKit และ Core Audio Process Taps โดยไม่ติดตั้งไดรเวอร์เพิ่มเติม

รุ่น 0.4.2 ซ่อน WebThumbnailExtension และตัวช่วยสร้างภาพตัวอย่างของ Quick Look จากรายการแอป รวมถึงรายการที่เคยตั้งระดับเสียงไว้แล้ว โดยตรวจชื่อ process, bundle ID และตำแหน่งส่วนขยายของระบบ ไม่ซ่อน WebKit ทุกตัว เพื่อให้เสียงของ Safari และแอปอื่นยังแสดงตามเดิม

## เริ่มใช้งาน

1. เปิด `AppMixer.app` ที่ให้มาคู่กับโฟลเดอร์นี้ แล้วคลิกไอคอนรูปตัวปรับเสียงบนแถบเมนูด้านบน
2. เปิดเพลงหรือวิดีโอในแอปที่ต้องการ แอปที่ส่งเสียงจะปรากฏอัตโนมัติ
3. เปิดสวิตช์ของ AppMixer แล้วเลื่อนระดับเสียง หรือกดปุ่มลำโพงเพื่อ mute
4. อนุญาตการเข้าถึงเสียงระบบเมื่อ macOS ถาม หากไม่สำเร็จ ตรวจที่ System Settings → Privacy & Security → Screen & System Audio Recording แล้วปิดเปิด AppMixer อีกครั้ง

ค่าระดับเสียงและ mute จำแยกตาม bundle ID ของแอป แต่ทุกครั้งที่เปิด AppMixer ใหม่จะพักการควบคุมไว้ก่อน ให้เปิดสวิตช์เองเพื่อใช้ค่าที่บันทึกไว้ ที่ 100% และไม่ได้ mute จะใช้เสียงต้นฉบับโดยตรง

ปิดสวิตช์เพื่อคืนเสียงต้นฉบับของทุกแอปทันที หรือเลือก “ออกจาก AppMixer” เมนูรูปเฟืองมีคำสั่งคืนค่าทั้งหมดเป็น 100% และลองเชื่อมต่อใหม่

## เลือกอุปกรณ์เสียงออกและไมโครโฟน

เมื่อเปิดสวิตช์แยกแอป ด้านบนมีเมนู “เสียงออก / Output” และ “ไมโครโฟน / Microphone” เลือกจากอุปกรณ์ที่เชื่อมต่อและรองรับการเป็นอุปกรณ์หลัก เช่น ลำโพงในเครื่อง หูฟัง Bluetooth, USB หรือ HDMI พร้อมเครื่องหมายถูกหน้าอุปกรณ์ปัจจุบัน

การเลือกเปลี่ยนอุปกรณ์หลักของ macOS แอปที่ตั้งให้ตามอุปกรณ์ระบบจะใช้ตัวที่เลือก แอปประชุมหรือโปรแกรมที่ตั้งอุปกรณ์เองอาจต้องเลือกใหม่ในแอปนั้นด้วย การเปลี่ยนไมโครโฟนเป็นเพียงการเลือกอุปกรณ์หลัก AppMixer ไม่รับหรือบันทึกเสียงจากไมโครโฟน

รายการและสถานะปัจจุบันซิงก์ทุก 1 วินาที รวมถึงเมื่อเสียบ/ถอดอุปกรณ์หรือเปลี่ยนจาก System Settings หากอุปกรณ์หายไปก่อนกดเลือก จะแสดงข้อผิดพลาดโดยไม่ตั้งค่าตัวอื่นแทน เมื่อเปลี่ยนอุปกรณ์เสียงออก ระบบจะสร้างช่องควบคุมเสียงแยกแอปใหม่และอ่าน Master จากอุปกรณ์ใหม่ ค่าระดับเสียงแยกแอปยังคงเดิม การเลือกไมโครโฟน Bluetooth อาจเปลี่ยนคุณภาพหรือรูปแบบเสียงออกตามข้อจำกัดของอุปกรณ์

ค่าของอุปกรณ์ที่เลือกเป็นค่าของ macOS จึงยังคงอยู่หลังปิด AppMixer เมื่อเปิดแอปจะอ่านค่าปัจจุบันของระบบ ไม่บังคับเปลี่ยนกลับไปเป็นอุปกรณ์ที่เลือกครั้งก่อน

## ไทย / English

กดเมนูรูปเฟือง → ภาษา / Language → ไทย หรือ English เปลี่ยนได้ทันทีโดยไม่ปิดเปิดแอป มีคำแปลทั้งป้าย เมนู สถานะ ข้อความผิดพลาด และข้อความสำหรับการช่วยการเข้าถึง ชื่อแอปและอุปกรณ์ยังใช้ชื่อตามจริง รุ่นนี้เริ่มที่ภาษาไทยและจำภาษาที่เลือกไว้สำหรับครั้งถัดไป

## Master — เสียงรวมของระบบ

แถบ Master อยู่เหนือรายการแอป ปรับ 0–100% และ mute เสียงรวมของอุปกรณ์เสียงออกปัจจุบัน โดยไม่เปลี่ยนค่าที่ตั้งแยกแต่ละแอป Master ไม่ต้องใช้สิทธิ์รับเสียงระบบ แต่ตัวควบคุมจะถูกซ่อนไปพร้อมส่วนอื่นเมื่อปิดสวิตช์แยกแอป ระดับเสียงรวมของระบบยังคงค่าเดิม

ค่าของ Master อ่านจาก macOS โดยตรงและซิงก์ทุก 1 วินาทีเมื่อปรับจากปุ่มเสียงบนคีย์บอร์ดหรือ Control Center เมื่อสลับอุปกรณ์จะอ่านค่าของอุปกรณ์ใหม่ การปิด AppMixer หรือคืนค่าระดับเสียงแยกแอปจะคงระดับเสียงระบบไว้

ใช้ปุ่ม mute ของอุปกรณ์เมื่อรองรับ หากมีเฉพาะตัวปรับระดับเสียง จะตั้งระดับเป็นศูนย์และจำค่าก่อนปิดเสียงไว้ระหว่างเปิด AppMixer เพื่อคืนค่าเมื่อกดอีกครั้ง หากเปิดแอปมาในขณะที่เสียงเป็นศูนย์และไม่มีค่าก่อนหน้า จะคืนเสียงที่ 25%

อุปกรณ์ที่ไม่มีตัวปรับระดับเสียงผ่าน macOS เช่น HDMI/DisplayPort หรือ DAC บางรุ่น จะแสดง Master ที่ปรับไม่ได้พร้อมคำอธิบาย ต้องปรับระดับที่ตัวอุปกรณ์

## ชื่อและโลโก้แอป

ดึงชื่อและโลโก้จากแอปที่ติดตั้งอยู่จริง ไม่ใช้รูปตัวอย่างหรือรายชื่อ Chrome/Discord/Teams แบบตายตัว รวม helper ภายใน app bundle เดียวกัน และพยายามหาแอปต้นทางจากตำแหน่ง executable หรือ bundle ID เมื่อ process ย่อยไม่มีข้อมูลจาก NSRunningApplication

ชื่อที่แสดงใช้ชื่อสำหรับผู้ใช้จากข้อมูลแอปหรือชื่อที่ Finder แสดง โดยค่าระดับเสียงยังผูกกับ bundle ID เดิม หากไม่พบแอปต้นทางจะใช้ชื่อ process และไอคอนสำรอง จะไม่เดาว่า WebKit ทุกตัวเป็น Safari เพราะแอปอื่นก็ใช้ WebKit ได้

## เปิดแก้ใน Xcode

เปิด `AppMixer.xcodeproj` เลือก scheme AppMixer และปลายทาง My Mac แล้วกด Run ไม่ต้องติดตั้ง package เพิ่ม โครงการตั้งค่า ad-hoc signing สำหรับทดสอบบนเครื่องนี้ไว้แล้ว แอปที่ให้มายังไม่ได้ notarize หรือเซ็นด้วย Developer ID สำหรับแจกจ่ายสาธารณะ

บิลด์ผ่าน Terminal ได้ด้วย `./build.command` ผลลัพธ์อยู่ใน `.build/Build/Products/Release/AppMixer.app`

## สถานะการตรวจสอบ

- บิลด์ Release ผ่านด้วย Xcode 27.1 บน macOS 27.0.1 (Apple Silicon)
- ตรวจลายเซ็นแอปด้วย codesign ผ่าน
- ทดสอบการรวม nested helper, การแยกแอปที่ bundle ID คล้ายกัน และอ่านชื่อพร้อมไอคอนของ Google Chrome ที่ติดตั้งจริงผ่าน
- รุ่น 0.4 ตรวจความครบของคำแปลไทย–อังกฤษและการปฏิเสธ device ID ที่ไม่ถูกต้องก่อนเขียนค่าระบบผ่าน การสลับอุปกรณ์จริงยังไม่ได้ทดสอบ
- Master volume และ mute ของอุปกรณ์เสียงออกยังต้องทดสอบการปรับอุปกรณ์จริง
- ทดสอบส่วนประมวลผลด้วย AddressSanitizer และ UndefinedBehaviorSanitizer ผ่าน: ลดเสียง, mute แบบ ramp, stereo ทั้ง planar/interleaved, ข้ามช่อง hardware input, mono และข้อมูลเสียงที่หายไป
- ยังไม่ได้ยืนยันหน้าตาผ่านหน้าจอจริงหรือการควบคุมเสียงจากแอปจริง: ระบบควบคุมหน้าจอในเซสชันนี้ไม่ได้รับสิทธิ์ และยังไม่ได้ให้สิทธิ์รับเสียงระบบแก่ AppMixer

## ขอบเขตต้นแบบ

- ต้องใช้ macOS 14.2 ขึ้นไป โดยสร้างและคอมไพล์บนเครื่องผู้ใช้ที่ใช้ 27.0.1
- รองรับสัญญาณ Float32 mono/stereo ที่ stream แรกของอุปกรณ์เสียงออกตามระบบ ยังไม่รองรับ surround, เลือก output แยกแอป หรือปรับเกิน 100%
- ตรวจรายการแอปและอุปกรณ์เสียงทุก 1 วินาที การสลับอุปกรณ์จึงอาจมีเสียงต้นฉบับกลับมาชั่วครู่
- รวม helper ของ Chrome/Electron ที่อยู่ภายใน app bundle เดียวกันเป็นแถวเดียว helper แบบแยก bundle โดยเฉพาะ WebKit อาจแสดงแยก จึงยังไม่รับประกันการรวมทุกแอปหรือเสียงที่มี DRM
- การคืนเสียงเมื่อปิด/หยุดใช้ `.mutedWhenTapped` ของ Core Audio และล้าง tap/aggregate เมื่อหยุด route ยังต้องทดสอบกับเสียงจริง รวมถึง Bluetooth, การ sleep/wake และแอปประชุม
- ประมวลผลเสียงในหน่วยความจำภายในเครื่อง ไม่มีการบันทึกหรืออัปโหลดเสียง

## ทดสอบชื่อและโลโก้

รันจากโฟลเดอร์โครงการ:

```sh
mkdir -p .build
xcrun clang -std=c11 -c AppMixer/AudioKernel.c -o .build/IdentityKernel.o
xcrun swiftc -module-cache-path .build/ModuleCache -import-objc-header AppMixer/BridgingHeader.h AppMixer/Localization.swift AppMixer/AudioSystem.swift Tests/ProcessIdentityTests.swift .build/IdentityKernel.o -framework AppKit -framework CoreAudio -framework AudioToolbox -o .build/ProcessIdentityTests
.build/ProcessIdentityTests
```

## ทดสอบภาษาและการตรวจอุปกรณ์

หลังสร้าง `.build/IdentityKernel.o` จากคำสั่งข้างต้น:

```sh
xcrun swiftc -module-cache-path .build/ModuleCache -import-objc-header AppMixer/BridgingHeader.h AppMixer/Localization.swift AppMixer/AudioSystem.swift Tests/LanguageAndDeviceTests.swift .build/IdentityKernel.o -framework AppKit -framework CoreAudio -framework AudioToolbox -o .build/LanguageAndDeviceTests
.build/LanguageAndDeviceTests
```

การทดสอบนี้ไม่เปลี่ยนอุปกรณ์หรือระดับเสียงจริงของเครื่อง

## ทดสอบส่วนประมวลผล

```sh
xcrun clang -std=c11 -fsanitize=address,undefined -g Tests/AudioKernelTests.c AppMixer/AudioKernel.c -framework CoreAudio -o /tmp/AppMixerAudioTests
/tmp/AppMixerAudioTests
```

อ้างอิง API: [Apple — Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/CoreAudio/capturing-system-audio-with-core-audio-taps)
