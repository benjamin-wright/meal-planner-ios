//
//  GlazedImage.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 12/09/2025.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

private let glazedImageContext = CIContext()

func updateImage(name: String, darkMode: Bool) -> UIImage {
    guard let sourceImage = UIImage(named: name),
          let texture = UIImage(named: "Texture"),
          let inputImage = CIImage(image: sourceImage),
          let textureImage = CIImage(image: texture) else {
        return UIImage()
    }
    
    let texHeight = textureImage.extent.height
    let texWidth = textureImage.extent.width
    let inputHeight = inputImage.extent.height
    let inputWidth = inputImage.extent.width
    
    let scaleFactor = max(inputHeight / texHeight, inputWidth / texWidth)
    
    let resizeFilter = CIFilter.lanczosScaleTransform()
    resizeFilter.inputImage = textureImage
    resizeFilter.scale = Float(scaleFactor)
    
    let blurFilter = CIFilter.gaussianBlur()
    blurFilter.inputImage = inputImage
    blurFilter.radius = 3
    
    let dimFilter = CIFilter.gammaAdjust()
    dimFilter.inputImage = blurFilter.outputImage?.cropped(to: inputImage.extent)
    dimFilter.power = darkMode ? 1.6 : 0.6
    
    let glassFilter = CIFilter.glassDistortion()
    glassFilter.inputImage = dimFilter.outputImage
    glassFilter.textureImage = resizeFilter.outputImage
    glassFilter.center = CGPoint(x: 0.5, y: 0.5)
    glassFilter.scale = 500

    guard
        let outputCIImage = glassFilter.outputImage?.cropped(to: inputImage.extent),
        let cgImage = glazedImageContext.createCGImage(outputCIImage, from: inputImage.extent)
    else {
        return sourceImage
    }

    return UIImage(cgImage: cgImage)
}

struct GlazedImage: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private let imageName: String
    @State private var image: UIImage
    
    init(named: String) {
        self.imageName = named
        _image = State(initialValue: updateImage(name: named, darkMode: false))
    }
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .task(id: colorScheme) {
                image = updateImage(name: imageName, darkMode: colorScheme == .dark)
            }
    }
}

#Preview {
    GlazedImage(named: "Background")
}
