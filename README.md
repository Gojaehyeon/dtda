# 🎼 DTDA (듣다)

> 사진 한 장이면, 코드와 음표가 **원하는 Key로 자동 전환**되는 악보 앱

DTDA는 iOS 기반 OCR 악보 인식 앱입니다.  
사진으로 찍은 악보를 자동으로 분석하여 코드와 음표를 추출하고, 사용자가 선택한 키(Key)로 **자동 전조(Transpose)** 해줍니다.  
복잡한 악보 편집 없이, 빠르고 직관적으로 악보를 바꿔보세요.

---

## ✨ 주요 기능

- 📷 **악보 OCR 인식**
  - 코드 기호(C, Am, F7 등)와 음표 위치를 이미지에서 자동 추출
- 🔁 **Key 변경**
  - 원하는 조(Key)를 선택하면 코드와 음표를 함께 변환
- 🖨️ **결과 출력**
  - 바뀐 악보를 화면에 표시하거나 PDF로 저장 가능

---

## 📱 사용 흐름

1. 악보를 촬영하거나 불러오기
2. OCR로 코드 및 음표 자동 인식
3. 전환할 키 선택 (예: C → G)
4. 바뀐 악보 결과 확인 및 저장

---

## 🧰 기술 스택

| 항목         | 사용 기술                         |
|--------------|-----------------------------------|
| iOS 개발     | Swift, SwiftUI                    |
| OCR 기능     | VisionKit / Tesseract OCR         |
| PDF 출력     | PDFKit                            |
| 음표/코드 파싱 | Custom Music Parser or MusicXML  |

---

## 📦 설치 방법

```bash
git clone https://github.com/your-username/dtda.git
cd dtda
open DTDA.xcodeproj
