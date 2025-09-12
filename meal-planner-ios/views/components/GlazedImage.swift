//
//  GlazedImage.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 12/09/2025.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct GlazedImage: View {
    var image: UIImage
    
    init(named: String) {
        let inputImage = CIImage(image: UIImage(named: named)!)!
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
        dimFilter.power = 1.6
        
        let glassFilter = CIFilter.glassDistortion()
        glassFilter.inputImage = dimFilter.outputImage!
        glassFilter.textureImage = resizeFilter.outputImage!
        glassFilter.center = CGPoint(x: 0.5, y: 0.5)
        glassFilter.scale = 300
        
        let context = CIContext()

        guard
            let outputCIImage = glassFilter.outputImage,
            let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent)
        else {
            self.image = UIImage()
            return
        }
        
        self.image = UIImage(cgImage: cgImage)
    }
    
    var body: some View {
        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
    }
}
