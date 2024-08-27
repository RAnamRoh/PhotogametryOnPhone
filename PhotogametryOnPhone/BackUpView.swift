//import SwiftUI
//import PhotosUI
//import RealityKit
//
//struct BackUpView: View {
//    @State private var selectedImages: [UIImage] = []
//    @State private var isProcessing: Bool = false
//    @State private var progressValue: Double = 0.0
//    @State private var modelURL: URL?
//    @State private var showAlert: Bool = false
//    @State private var showingPhotoPicker = false
//
//    var body: some View {
//        VStack {
//            Button("Select Photos") {
//                showingPhotoPicker = true
//            }
//            .sheet(isPresented: $showingPhotoPicker) {
//                PhotoPicker(selectedImages: $selectedImages)
//            }
//
//            if isProcessing {
//                ProgressView(value: progressValue, total: 1.0)
//                    .padding()
//                Text("Processing \(Int(progressValue * 100))%")
//            }
//
//            Button("Generate 3D Model") {
//                saveImagesToDirectoryAndProcess()
//            }
//            .disabled(selectedImages.count < 20 || isProcessing)
//
//            if let modelURL = modelURL {
//                Text("Model saved at: \(modelURL)")
//            }
//        }
//        .padding()
//        .alert(isPresented: $showAlert) {
//            Alert(
//                title: Text("Success!"),
//                message: Text("Your 3D model has been created and saved."),
//                dismissButton: .default(Text("OK"))
//            )
//        }
//    }
//
//    private func saveImagesToDirectoryAndProcess() {
//        isProcessing = true
//        progressValue = 0.0
//
//        // Get the app's documents directory
//        let fileManager = FileManager.default
//        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            print("Could not find documents directory.")
//            isProcessing = false
//            return
//        }
//
//        // Create the 'selected3Dimage' directory and clear it if it already exists
//        let imagesDirectoryURL = documentsURL.appendingPathComponent("selected3Dimage")
//        do {
//            if fileManager.fileExists(atPath: imagesDirectoryURL.path) {
//                try fileManager.removeItem(at: imagesDirectoryURL)  // Clear the directory
//            }
//            try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
//        } catch {
//            print("Error creating or clearing directory: \(error)")
//            isProcessing = false
//            return
//        }
//
//        // Save images to the directory
//        for (index, image) in selectedImages.enumerated() {
//            let imageURL = imagesDirectoryURL.appendingPathComponent("image_\(index).jpg")
//            if let imageData = image.jpegData(compressionQuality: 1.0) {
//                do {
//                    try imageData.write(to: imageURL)
//                } catch {
//                    print("Error saving image: \(error)")
//                    isProcessing = false
//                    return
//                }
//            }
//        }
//
//        // Start photogrammetry process with the saved images directory
//        processImagesTo3DModel(directoryURL: imagesDirectoryURL)
//    }
//
//    private func processImagesTo3DModel(directoryURL: URL) {
//        let fileManager = FileManager.default
//        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            print("Could not find documents directory.")
//            isProcessing = false
//            return
//        }
//
//        do {
//            let session = try PhotogrammetrySession(input: directoryURL, configuration: .init())
//            
//            // Create or clear the output directory
//            let outputDirectoryURL = documentsURL.appendingPathComponent("output3D")
//            if fileManager.fileExists(atPath: outputDirectoryURL.path) {
//                try fileManager.removeItem(at: outputDirectoryURL)  // Clear the old model
//            }
//            try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true, attributes: nil)
//            
//            // Output URL for the new 3D model
//            let outputURL = outputDirectoryURL.appendingPathComponent("model.usdz")
//            
//            // Create the request
//            let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)
//
//            Task {
//                for try await output in session.outputs {
//                    switch output {
//                    case .processingComplete:
//                        DispatchQueue.main.async {
//                            self.isProcessing = false
//                            self.modelURL = outputURL
//                            self.showAlert = true
//                        }
//                    case .requestComplete(let request, let result):
//                        handleRequestComplete(request: request, result: result)
//                    case .requestProgress(_, let fractionComplete):
//                        DispatchQueue.main.async {
//                            self.progressValue = fractionComplete
//                        }
//                    default:
//                        break
//                    }
//                }
//            }
//
//            try session.process(requests: [request])
//
//        } catch {
//            print("Error creating photogrammetry session: \(error)")
//            self.isProcessing = false
//        }
//    }
//
//    private func handleRequestComplete(request: PhotogrammetrySession.Request, result: PhotogrammetrySession.Result) {
//        switch result {
//        case .modelFile(let url):
//            print("Model file available at: \(url)")
//            self.modelURL = url
//        default:
//            break
//        }
//    }
//}
//
//// MARK: - PHPicker for Image Selection
//
//struct PhotoPicker: UIViewControllerRepresentable {
//    @Binding var selectedImages: [UIImage]
//
//    func makeUIViewController(context: Context) -> PHPickerViewController {
//        var config = PHPickerConfiguration()
//        config.selectionLimit = 30
//        config.filter = .images
//
//        let picker = PHPickerViewController(configuration: config)
//        picker.delegate = context.coordinator
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, PHPickerViewControllerDelegate {
//        let parent: PhotoPicker
//
//        init(_ parent: PhotoPicker) {
//            self.parent = parent
//        }
//
//        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
//            picker.dismiss(animated: true)
//
//            parent.selectedImages = []
//            for result in results {
//                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
//                    result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
//                        if let image = image as? UIImage {
//                            DispatchQueue.main.async {
//                                self.parent.selectedImages.append(image)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
//}
