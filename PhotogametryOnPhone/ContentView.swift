import SwiftUI
import PhotosUI
import RealityKit
import UIKit
import QuickLook

// Extend URL to conform to Identifiable
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct ContentView: View {
    @State private var selectedImages: [UIImage] = []
    @State private var isProcessing: Bool = false
    @State private var progressValue: Double = 0.0
    @State private var modelFiles: [URL] = []
    @State private var showingPhotoPicker = false
    @State private var showAlert: Bool = false

    @StateObject private var documentOpener = DocumentOpener()

    var body: some View {
        NavigationView {
            VStack {
                if !modelFiles.isEmpty {
                    List(modelFiles, id: \.self) { file in
                        HStack {
                            Text(file.lastPathComponent)
                                .font(.headline)
                            Spacer()
                            Button("Open") {
                                documentOpener.openDocument(url: file)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .navigationTitle("Generated 3D Models")
                } else {
                    Text("No models generated yet")
                        .padding()
                }

                Spacer()

                Button("Select Photos") {
                    showingPhotoPicker = true
                }
                .sheet(isPresented: $showingPhotoPicker) {
                    PhotoPicker(selectedImages: $selectedImages)
                }

                if isProcessing {
                    ProgressView(value: progressValue, total: 1.0)
                        .padding()
                    Text("Processing \(Int(progressValue * 100))%")
                }

                Button("Generate 3D Model") {
                    saveImagesToDirectoryAndProcess()
                }
                .disabled(selectedImages.count < 20 || isProcessing)
                .padding()

                Spacer()
            }
            .onAppear {
                loadModelFiles()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Success!"),
                    message: Text("Your 3D model has been created and saved."),
                    dismissButton: .default(Text("OK")) {
                        loadModelFiles()
                    }
                )
            }
        }
    }

    // Method to load previously created model files
    private func loadModelFiles() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not find documents directory.")
            return
        }

        let outputDirectoryURL = documentsURL.appendingPathComponent("output3D")
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: outputDirectoryURL, includingPropertiesForKeys: nil)
            modelFiles = fileURLs.filter { $0.pathExtension == "usdz" }
        } catch {
            print("Error loading files: \(error)")
        }
    }

    private func saveImagesToDirectoryAndProcess() {
        isProcessing = true
        progressValue = 0.0

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not find documents directory.")
            return
        }

        let imagesDirectoryURL = documentsURL.appendingPathComponent("selected3Dimage")
        let outputDirectoryURL = documentsURL.appendingPathComponent("output3D")

        // Clear old images and create directories if they don't exist
        do {
            try fileManager.removeItem(at: imagesDirectoryURL)
            //try fileManager.removeItem(at: outputDirectoryURL)
        } catch {
            // Ignore errors if directories don't exist
        }

        do {
            try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating directories: \(error)")
            isProcessing = false
            return
        }

        // Save images to the 'selected3Dimage' directory
        for (index, image) in selectedImages.enumerated() {
            let imageURL = imagesDirectoryURL.appendingPathComponent("image_\(index).jpg")
            if let imageData = image.jpegData(compressionQuality: 1.0) {
                do {
                    try imageData.write(to: imageURL)
                } catch {
                    print("Error saving image: \(error)")
                    isProcessing = false
                    return
                }
            }
        }

        // Start photogrammetry process with the saved images
        processImagesTo3DModel(directoryURL: imagesDirectoryURL, outputDirectoryURL: outputDirectoryURL)
    }

    private func processImagesTo3DModel(directoryURL: URL, outputDirectoryURL: URL) {
        
        let index = modelFiles.count + 1
        
        do {
            let session = try PhotogrammetrySession(input: directoryURL, configuration: .init())
            let outputURL = outputDirectoryURL.appendingPathComponent("model \(index).usdz")

            let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)

            Task {
                for try await output in session.outputs {
                    switch output {
                    case .processingComplete:
                        DispatchQueue.main.async {
                            self.isProcessing = false
                            self.modelFiles.append(outputURL)
                            self.showAlert = true
                        }
                    case .requestComplete(let request, let result):
                        handleRequestComplete(request: request, result: result)
                    case .requestProgress(_, let fractionComplete):
                        DispatchQueue.main.async {
                            self.progressValue = fractionComplete
                        }
                    default:
                        break
                    }
                }
            }

            try session.process(requests: [request])

        } catch {
            print("Error creating photogrammetry session: \(error)")
            self.isProcessing = false
        }
    }

    private func handleRequestComplete(request: PhotogrammetrySession.Request, result: PhotogrammetrySession.Result) {
        switch result {
        case .modelFile(let url):
            print("Model file available at: \(url)")
            self.modelFiles.append(url)
        default:
            break
        }
    }
}

// MARK: - PHPicker for Image Selection

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 50
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            parent.selectedImages = []
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.selectedImages.append(image)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - DocumentOpener for Opening 3D Models

class DocumentOpener: NSObject, ObservableObject, QLPreviewControllerDataSource {
    private var fileURL: URL?
    
    func openDocument(url: URL) {
        self.fileURL = url
        DispatchQueue.main.async {
            let previewController = QLPreviewController()
            previewController.dataSource = self
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(previewController, animated: true, completion: nil)
            } else {
                print("Failed to present Quick Look preview")
            }
        }
    }
    
    // MARK: - QLPreviewControllerDataSource
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let url = fileURL else {
            fatalError("No file URL set")
        }
        return url as QLPreviewItem
    }
}

// Extension to use DocumentOpener in SwiftUI
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}
