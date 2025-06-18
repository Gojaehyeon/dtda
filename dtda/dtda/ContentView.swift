//
//  ContentView.swift
//  dtda
//
//  Created by Gojaehyun on 6/18/25.
//

import SwiftUI
import PhotosUI
import Vision

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var chordPositions: [ChordPosition] = []
    @State private var transpositionSteps: Int = 0
    @State private var showingImagePicker = false
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = selectedImage {
                    ScrollView {
                        let aspectRatio = image.size.height / image.size.width
                        
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            let height = width * aspectRatio
                            
                            ZStack {
                                // 악보 이미지
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: width, height: height)
                                    .background(Color.white)
                                    .onAppear {
                                        print("Image displayed with size: \(width) x \(height)")
                                        imageSize = CGSize(width: width, height: height)
                                    }
                                
                                // 코드 오버레이
                                ForEach(chordPositions) { position in
                                    let transposedChord = ChordRecognizer.transposeChord(position.chord, by: transpositionSteps)
                                    Text(transposedChord)
                                        .font(.system(size: position.fontSize))
                                        .foregroundColor(.blue)
                                        .background(Color.white.opacity(0.7))
                                        .position(
                                            x: position.bounds.midX,
                                            y: position.bounds.midY
                                        )
                                }
                            }
                            .frame(width: width, height: height)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Divider()
                    
                    // 전조 컨트롤
                    HStack {
                        Button(action: { 
                            transpositionSteps = (transpositionSteps - 1 + 12) % 12
                            print("Transposition steps changed to: \(transpositionSteps)")
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                        }
                        
                        Text("\(transpositionSteps >= 0 ? "+" : "")\(transpositionSteps)")
                            .font(.title2)
                            .frame(width: 60)
                        
                        Button(action: { 
                            transpositionSteps = (transpositionSteps + 1) % 12
                            print("Transposition steps changed to: \(transpositionSteps)")
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                        }
                    }
                    .padding()
                } else {
                    Spacer()
                    Text("악보를 선택해주세요")
                        .font(.title)
                    Spacer()
                }
                
                Button(action: { 
                    print("Opening image picker...")
                    showingImagePicker = true 
                }) {
                    Text("악보 선택")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("코드 전조")
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage) { image in
                    print("Image selected, size: \(image.size)")
                    processImage(image)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        print("Starting image processing...")
        Task {
            do {
                print("Recognizing chords...")
                let chords = try await ChordRecognizer.recognizeChords(in: image, displaySize: imageSize)
                print("Recognition completed. Found \(chords.count) chords")
                
                await MainActor.run {
                    print("Updating UI with recognized chords")
                    self.chordPositions = chords
                }
            } catch {
                print("Error processing image: \(error)")
            }
        }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        print("Creating image picker...")
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
            super.init()
            print("ImagePicker coordinator initialized")
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("Image picker did finish picking media")
            if let image = info[.originalImage] as? UIImage {
                print("Image selected successfully")
                parent.image = image
                parent.onImagePicked(image)
            } else {
                print("Failed to get image from picker")
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("Image picker cancelled")
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ContentView()
}

// Text 크기 측정을 위한 extension
extension View {
    func measureSize() -> CGSize {
        let hostingController = UIHostingController(rootView: self)
        hostingController.view.layoutIfNeeded()
        return hostingController.sizeThatFits(in: UIView.layoutFittingExpandedSize)
    }
}
