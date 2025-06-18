import Vision
import UIKit

struct ChordPosition: Identifiable {
    let id = UUID()
    let chord: String
    let bounds: CGRect
    let fontSize: CGFloat
}

struct ChordRecognizer {
    // 이미지 전처리 함수 개선
    private static func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // 이미지 크기 정규화 (너비 기준)
        let targetWidth: CGFloat = 1200.0  // 목표 너비
        let aspectRatio = image.size.height / image.size.width
        let targetHeight = targetWidth * aspectRatio
        
        // 스케일링이 필요한 경우에만 수행
        var finalImage = image
        let shouldScale = abs(image.size.width - targetWidth) > 50  // 50px 이상 차이나면 스케일링
        
        if shouldScale {
            let newSize = CGSize(width: targetWidth, height: targetHeight)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let scaledImage = UIGraphicsGetImageFromCurrentImageContext() {
                finalImage = scaledImage
            }
            UIGraphicsEndImageContext()
            print("Image scaled from \(image.size) to \(finalImage.size)")
        }
        
        // 이미지 대비 향상
        let ciImage = CIImage(cgImage: finalImage.cgImage!)
        
        // 대비 향상을 위한 필터 체인
        let filters: [(String, [String: Any])] = [
            ("CIColorControls", [
                kCIInputContrastKey: 1.1,
                kCIInputBrightnessKey: 0.1
            ]),
            ("CIPhotoEffectNoir", [:])  // 흑백 변환
        ]
        
        var processedImage = ciImage
        for (filterName, params) in filters {
            guard let filter = CIFilter(name: filterName) else { continue }
            filter.setValue(processedImage, forKey: kCIInputImageKey)
            
            // 필터 파라미터 설정
            for (key, value) in params {
                filter.setValue(value, forKey: key)
            }
            
            if let outputImage = filter.outputImage {
                processedImage = outputImage
            }
        }
        
        // 최종 이미지 생성
        if let outputCGImage = CIContext().createCGImage(processedImage, from: processedImage.extent) {
            return UIImage(cgImage: outputCGImage)
        }
        
        return finalImage
    }

    private static func createTextRequest(
        level: VNRequestTextRecognitionLevel,
        height: Float,
        words: [String]
    ) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.minimumTextHeight = height
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "en-GB"]
        request.customWords = words
        
        // 추가 최적화 설정
        request.revision = VNRecognizeTextRequestRevision3
        return request
    }

    private static func convertToImageCoordinates(_ boundingBox: CGRect, originalSize: CGSize, processedSize: CGSize, displaySize: CGSize?) -> CGRect {
        // 1. Vision 좌표계(0,0 왼쪽 하단)에서 UIKit 좌표계(0,0 왼쪽 상단)로 변환
        let x = boundingBox.minX
        let y = 1.0 - boundingBox.maxY  // y축 반전
        let width = boundingBox.width
        let height = boundingBox.height

        // 2. 정규화된 좌표를 처리된 이미지 크기로 변환
        var rect = CGRect(
            x: x * processedSize.width,
            y: y * processedSize.height,
            width: width * processedSize.width,
            height: height * processedSize.height
        )
        
        // 3. 처리된 이미지에서 원본 이미지 크기로 스케일링
        let scaleX = originalSize.width / processedSize.width
        let scaleY = originalSize.height / processedSize.height
        rect = CGRect(
            x: rect.minX * scaleX,
            y: rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        // 4. 디스플레이 크기로 조정 (필요한 경우)
        if let displaySize = displaySize {
            let displayScaleX = displaySize.width / originalSize.width
            let displayScaleY = displaySize.height / originalSize.height
            rect = CGRect(
                x: rect.minX * displayScaleX,
                y: rect.minY * displayScaleY,
                width: rect.width * displayScaleX,
                height: rect.height * displayScaleY
            )
        }
        
        return rect
    }

    static func recognizeChords(in image: UIImage, displaySize: CGSize? = nil) async throws -> [ChordPosition] {
        print("\n=== ChordRecognizer: Starting chord recognition ===")
        print("Input image size: \(image.size)")
        
        // 이미지 전처리
        guard let processedImage = preprocessImage(image),
              let cgImage = processedImage.cgImage else {
            throw NSError(domain: "ChordRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
        }
        print("Processed image size: \(processedImage.size)")
        
        if let displaySize = displaySize {
            print("Target display size: \(displaySize)")
        }
        
        // 공통 커스텀 단어 설정 - 더 많은 변형 추가
        let customWords = [
            // 기본 코드
            "A", "B", "C", "D", "E", "F", "G",
            "A.", "B.", "C.", "D.", "E.", "F.", "G.",
            // 단조 (소문자 변형 포함)
            "Am", "Bm", "Cm", "Dm", "Em", "Fm", "Gm",
            "am", "bm", "cm", "dm", "em", "fm", "gm",
            // 7th 코드 (소문자 변형 포함)
            "A7", "B7", "C7", "D7", "E7", "F7", "G7",
            "a7", "b7", "c7", "d7", "e7", "f7", "g7",
            // 변화음 (다양한 표기법)
            "A#", "C#", "D#", "F#", "G#",
            "Ab", "Bb", "Cb", "Db", "Eb", "Fb", "Gb",
            "A♯", "C♯", "D♯", "F♯", "G♯",
            "A♭", "B♭", "C♭", "D♭", "E♭", "F♭", "G♭",
            // 변화음 단조 (다양한 표기법)
            "C#m", "D#m", "F#m", "G#m",
            "Bbm", "Ebm", "Abm",
            "c#m", "d#m", "f#m", "g#m",
            "bbm", "ebm", "abm",
            // 슬래시 코드 (다양한 표기법)
            "G/A", "A/C#", "D/F#", "E/G#", "D/E", "E/D",
            "g/a", "a/c#", "d/f#", "e/g#", "d/e", "e/d",
            // 기타 일반적인 코드
            "Amaj7", "Dmaj7", "Gmaj7", "amaj7", "dmaj7", "gmaj7",
            "Asus4", "Dsus4", "Esus4", "asus4", "dsus4", "esus4",
            "Cadd9", "Dadd9", "Gadd9", "cadd9", "dadd9", "gadd9",
            // 반복 기호
            "1.", "2.", "3.", "4.", "D.C.", "D.S.", "Fine", "Coda",
            // 개별 문자 및 기호
            "m", "7", "maj", "dim", "sus", "add", "aug",
            "b", "#", "9", "♯", "♭",
            // 추가: 자주 혼동되는 패턴과 변형
            "A/c#", "a/c#", "A/C#", "a/C#",
            "D/e", "d/e", "D/E", "d/E",
            "G/a", "g/a", "G/A", "g/A"
        ]
        
        // 이미지 크기에 따른 동적 텍스트 높이 계산
        let baseHeight: Float = 0.01
        let scaleFactor = Float(processedImage.size.width / 1200.0)
        
        // 더 다양한 높이로 시도
        let heightMultipliers: [Float] = [0.05, 0.1, 0.2, 0.3, 0.5, 1.0]
        var requests: [VNRecognizeTextRequest] = []
        
        for multiplier in heightMultipliers {
            let request = createTextRequest(
                level: .accurate,
                height: baseHeight * multiplier * scaleFactor,
                words: customWords
            )
            requests.append(request)
        }
        
        // 빠른 인식 요청도 추가
        requests.append(createTextRequest(
            level: .fast,
            height: baseHeight * 0.3 * scaleFactor,
            words: customWords
        ))
        
        print("Created \(requests.count) recognition requests with different heights")
        
        // 모든 요청 실행
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try await requestHandler.perform(requests)
        
        // 모든 결과 수집 및 신뢰도 출력
        var allObservations: [(observation: VNRecognizedTextObservation, confidence: Float)] = []
        for (index, request) in requests.enumerated() {
            if let observations = request.results {
                for obs in observations {
                    if let candidate = try? obs.topCandidates(1).first {
                        allObservations.append((obs, candidate.confidence))
                        print("Request \(index) found text '\(candidate.string)' with confidence \(candidate.confidence)")
                    }
                }
            }
        }
        
        // 중복 제거 (더 관대한 기준 적용)
        var uniqueObservations: [VNRecognizedTextObservation] = []
        var processedIndices = Set<Int>()
        
        // 신뢰도 순으로 정렬
        let sortedObservations = allObservations.sorted { $0.confidence > $1.confidence }
        
        for (index, (obs, confidence)) in sortedObservations.enumerated() {
            if processedIndices.contains(index) { continue }
            
            // 현재 관찰과 겹치는 다른 관찰들 찾기
            var overlappingIndices: [Int] = []
            for (otherIndex, (otherObs, _)) in sortedObservations.enumerated() {
                if index != otherIndex && !processedIndices.contains(otherIndex) {
                    let intersection = obs.boundingBox.intersection(otherObs.boundingBox)
                    let area = intersection.width * intersection.height
                    let minArea = min(
                        obs.boundingBox.width * obs.boundingBox.height,
                        otherObs.boundingBox.width * otherObs.boundingBox.height
                    )
                    // 더 관대한 중복 기준 (20% 이상 겹치면 중복)
                    if area > minArea * 0.2 {
                        overlappingIndices.append(otherIndex)
                    }
                }
            }
            
            // 가장 높은 신뢰도를 가진 관찰 선택
            uniqueObservations.append(obs)
            processedIndices.insert(index)
            processedIndices.formUnion(overlappingIndices)
        }
        
        print("\nFound \(uniqueObservations.count) unique observations after duplicate removal")
        
        var chordPositions: [ChordPosition] = []
        
        // 모든 관찰 결과를 처리
        for obs in uniqueObservations {
            let candidates = (try? obs.topCandidates(10)) ?? []
            var foundValidChord = false
            
            for candidate in candidates {
                let text = candidate.string.trimmingCharacters(in: .whitespaces)
                if text.isEmpty { continue }
                
                let cleanedText = cleanupChordText(text)
                if isValidChord(cleanedText) {
                    let confidence = candidate.confidence
                    if confidence > 0.3 {
                        // 좌표 변환 로직 교체
                        let scaledBox = convertToImageCoordinates(
                            obs.boundingBox,
                            originalSize: image.size,
                            processedSize: processedImage.size,
                            displaySize: displaySize
                        )
                        
                        // 좌표 디버깅 정보
                        print("\nChord '\(cleanedText)' coordinates:")
                        print("Original bbox: \(obs.boundingBox)")
                        print("Scaled box: \(scaledBox)")
                        
                        let fontSize = calculateFontSize(for: scaledBox, in: image.size)
                        chordPositions.append(ChordPosition(
                            chord: cleanedText,
                            bounds: scaledBox,
                            fontSize: fontSize
                        ))
                        foundValidChord = true
                        break
                    }
                }
            }
            
            if !foundValidChord {
                let nearbyObservations = uniqueObservations.filter { other in
                    guard other != obs else { return false }
                    let distance = abs(other.boundingBox.midX - obs.boundingBox.midX)
                    let verticalOverlap = abs(other.boundingBox.midY - obs.boundingBox.midY)
                    return distance < 0.2 && verticalOverlap < 0.05
                }.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                
                for nearby in nearbyObservations {
                    if let text1 = try? obs.topCandidates(1).first?.string,
                       let text2 = try? nearby.topCandidates(1).first?.string {
                        let mergedText = text1 + text2
                        let cleanedText = cleanupChordText(mergedText)
                        
                        if isValidChord(cleanedText) {
                            let mergedBox = obs.boundingBox.union(nearby.boundingBox)
                            // 병합된 박스에도 새로운 좌표 변환 적용
                            let scaledBox = convertToImageCoordinates(
                                mergedBox,
                                originalSize: image.size,
                                processedSize: processedImage.size,
                                displaySize: displaySize
                            )
                            
                            // 병합된 좌표 디버깅 정보
                            print("\nMerged chord '\(cleanedText)' coordinates:")
                            print("Original merged bbox: \(mergedBox)")
                            print("Scaled merged box: \(scaledBox)")
                            
                            let fontSize = calculateFontSize(for: scaledBox, in: image.size)
                            chordPositions.append(ChordPosition(
                                chord: cleanedText,
                                bounds: scaledBox,
                                fontSize: fontSize
                            ))
                            break
                        }
                    }
                }
            }
        }
        
        // 결과 정렬 및 로깅
        let sortedChords = chordPositions.sorted { $0.bounds.minY < $1.bounds.minY }
        
        print("\n=== 최종 인식된 코드 (\(sortedChords.count)개) ===")
        for chord in sortedChords {
            print("코드: '\(chord.chord)'")
            print("위치: (\(Int(chord.bounds.minX)), \(Int(chord.bounds.minY)))")
            print("크기: \(Int(chord.bounds.width))x\(Int(chord.bounds.height))")
            print("폰트 크기: \(Int(chord.fontSize))")
            print("---")
        }
        print("=====================================\n")
        
        return sortedChords
    }
    
    private static func removeDuplicateChords(from chords: [ChordPosition]) -> [ChordPosition] {
        var uniqueChords: [ChordPosition] = []
        var processedPositions: Set<String> = []
        
        for chord in chords {
            // 위치를 정수로 반올림하여 근접한 위치의 중복을 방지
            let positionKey = "\(Int(chord.bounds.midX * 1000)),\(Int(chord.bounds.midY * 1000))"
            if !processedPositions.contains(positionKey) {
                uniqueChords.append(chord)
                processedPositions.insert(positionKey)
            }
        }
        
        return uniqueChords
    }
    
    private static func cleanupChordText(_ text: String) -> String {
        // 코드 텍스트 정리
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        
        // 일반적인 OCR 오류 수정
        let commonMistakes: [String: String] = [
            "0": "C",
            "O": "C",
            "l": "I",
            "1": "I",
            "|": "/",  // 슬래시 대신 세로 막대를 썼을 때
            "S": "5",
            "Z": "2",
            "n": "m"   // 소문자 m이 n으로 인식되는 경우
        ]
        
        for (mistake, correction) in commonMistakes {
            cleaned = cleaned.replacingOccurrences(of: mistake, with: correction)
        }
        
        // 루트 음은 대문자로, 나머지는 원래 대소문자 유지
        if let firstChar = cleaned.first {
            cleaned = String(firstChar).uppercased() + cleaned.dropFirst()
        }
        
        // minor 표기는 소문자 m으로 통일
        if cleaned.hasSuffix("M") && cleaned.count > 1 {
            let previous = cleaned.index(before: cleaned.endIndex)
            if !cleaned[previous].isNumber {  // maj7 같은 경우는 제외
                cleaned = cleaned.dropLast() + "m"
            }
        }
        
        return cleaned
    }
    
    private static func isValidChord(_ text: String) -> Bool {
        // 루트 음만 대문자로 변환하여 검사
        let firstChar = text.prefix(1).uppercased()
        let restOfText = text.dropFirst()
        let processedText = firstChar + restOfText
        
        // 기본 코드 (A-G)
        if processedText.count == 1 && "ABCDEFG".contains(processedText) {
            return true
        }
        
        // 기본 코드에 마침표가 붙은 경우 (예: "A.", "B.")
        if processedText.count == 2 && "ABCDEFG".contains(processedText.first!) && processedText.last == "." {
            return true
        }
        
        // 매우 관대한 코드 패턴 (대소문자 구분)
        let validChordPattern = "^[A-Ga-g][#b]?(maj7|M7|maj|min|dim|sus|sus4|add|aug|m)?[0-9]*((/[A-Ga-g][#b]?)?)?$"
        let regex = try? NSRegularExpression(pattern: validChordPattern, options: [])  // 대소문자 구분을 위해 options 제거
        if let regex = regex {
            let range = NSRange(location: 0, length: text.utf16.count)
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }
        
        return false
    }
    
    // 폰트 크기 계산 함수 개선
    private static func calculateFontSize(for bounds: CGRect, in imageSize: CGSize) -> CGFloat {
        // 이미지 크기에 따른 기본 폰트 크기 조정
        let baseFontSize: CGFloat = 12.0
        let scaleFactor = imageSize.width / 1200.0  // 기준 너비 대비 스케일
        
        // 바운딩 박스 높이 기반 폰트 크기 계산
        let heightBasedSize = bounds.height * 0.8  // 바운딩 박스 높이의 80%
        
        // 스케일된 기본 크기와 높이 기반 크기 중 적절한 값 선택
        return min(max(baseFontSize * scaleFactor, heightBasedSize), 24.0)  // 최대 24pt
    }
    
    static func transposeChord(_ chord: String, by steps: Int) -> String {
        print("ChordRecognizer: Transposing chord '\(chord)' by \(steps) steps")
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // 코드의 루트음과 나머지 부분 분리
        guard let firstChar = chord.first else { return chord }
        var root = String(firstChar)
        var remainder = String(chord.dropFirst())
        
        // #/b 처리
        if remainder.starts(with: "#") || remainder.starts(with: "b") {
            root += String(remainder.first!)
            remainder = String(remainder.dropFirst())
        }
        
        // 베이스음이 있는 경우 처리
        var bass = ""
        if let bassIndex = remainder.firstIndex(of: "/") {
            bass = String(remainder[bassIndex...])
            remainder = String(remainder[..<bassIndex])
        }
        
        // 루트음 전조
        if let currentIndex = notes.firstIndex(of: normalizeNote(root)) {
            let newIndex = (currentIndex + steps + 12) % 12
            let transposedRoot = notes[newIndex]
            let transposedChord = transposedRoot + remainder
            
            // 베이스음도 전조
            if !bass.isEmpty {
                let bassNote = String(bass.dropFirst()) // "/"를 제거
                if let bassCurrentIndex = notes.firstIndex(of: normalizeNote(bassNote)) {
                    let newBassIndex = (bassCurrentIndex + steps + 12) % 12
                    let transposedBass = "/" + notes[newBassIndex]
                    print("ChordRecognizer: Transposed '\(chord)' to '\(transposedChord + transposedBass)'")
                    return transposedChord + transposedBass
                }
            }
            
            print("ChordRecognizer: Transposed '\(chord)' to '\(transposedChord)'")
            return transposedChord
        }
        
        print("ChordRecognizer: Could not transpose chord '\(chord)'")
        return chord
    }
    
    private static func normalizeNote(_ note: String) -> String {
        // b를 #로 변환 (예: Db -> C#)
        let flatToSharp = [
            "Db": "C#",
            "Eb": "D#",
            "Gb": "F#",
            "Ab": "G#",
            "Bb": "A#"
        ]
        return flatToSharp[note] ?? note
    }
}

