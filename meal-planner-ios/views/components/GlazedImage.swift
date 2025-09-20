//
//  GlazedImage.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 12/09/2025.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins


func updateImage(name: String, darkMode: Bool) -> UIImage {
    let inputImage = CIImage(image: UIImage(named: name)!)!
    let textureImage = CIImage(image: UIImage(named: "Texture")!)!
    
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
    dimFilter.inputImage = blurFilter.outputImage!
    dimFilter.power = darkMode ? 1.6 : 0.6
    
    let glassFilter = CIFilter.glassDistortion()
    glassFilter.inputImage = dimFilter.outputImage!
    glassFilter.textureImage = resizeFilter.outputImage!
    glassFilter.center = CGPoint(x: 0.5, y: 0.5)
    glassFilter.scale = 500
    
    let context = CIContext()

    guard
        let outputCIImage = glassFilter.outputImage,
        let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent)
    else {
        return UIImage()
    }

    return UIImage(cgImage: cgImage)
}

struct GlazedImage: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var imageName: String
    @State var image: UIImage
    
    init(named: String) {
        imageName = named
        image = updateImage(name: named, darkMode: false)
    }
    
    var body: some View {
        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .edgesIgnoringSafeArea(.all)
            .onChange(of: colorScheme) {
                print("updating image")
                image = updateImage(name: imageName, darkMode: colorScheme == .dark)
                print("updated image")
            }
            .task {
                if colorScheme == .dark {
                    print("running task")
                    image = updateImage(name: imageName, darkMode: true)
                }
            }
    }
}

#Preview {
    GlazedImage(named: "Background")
}
