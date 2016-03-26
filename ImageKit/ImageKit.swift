//
//  ImageKit.swift
//
//
//  Created by Ikuo Kudo on 5/March/2016/
//  Copyright © 2016 Aquaware. All rights reserved.
//

import UIKit

public struct Point {
    var width: Int
    var height: Int
    var value: Int16
}

public struct PIXEL {
    var value: UInt32
    var red: UInt8 {
        get { return UInt8(value  & 0xff) }
        set { value = UInt32(newValue) | value & 0xffffff00 }
    }
    
    var green: UInt8 {
        get { return (UInt8(value >> 8) & 0xff) }
        set { value = UInt32(newValue) << 8 | value & 0xffff00ff }
    }
    
    var blue: UInt8 {
        get { return (UInt8(value >> 16) & 0xff) }
        set { value = UInt32(newValue) << 16 | value & 0xff00ffff }
    }
    
    var alpha: UInt8 {
        get { return (UInt8(value >> 24) & 0xff) }
        set { value = UInt32(newValue) << 24 | value & 0x00ffffff }
    }
}

public class KERNEL {
    var width: Int
    var height: Int
    var data: [Int16]!
    var gain: Int16 = 0
    
    init (width: Int, height: Int, data: [Int16]) {
        self.width = width
        self.height = height
        let size = width * height
        var sum: Int16 = 0
        if size > 0 {
            self.data = Array(count: size, repeatedValue: 0)
            for var i = 0; i < size; i++ {
                self.data[i] = data[i]
                sum += data[i]
            }
            gain = sum
        }
    }
    
    public func get(x: Int, y: Int) -> Int16 {
        if x > 0 && x < self.width && y > 0 && y < self.height {
            return self.data[x + y * self.width]
        }
        else {
            return 0
        }
    }
}

public class IMAGE {
    var width: Int
    var height: Int
    var nbits: Int
    var gain: Double = 1.0
    var pixels: UnsafeMutablePointer<Int16>!
    
    init? (width: Int, height: Int, nbits: Int) {
        self.width = width
        self.height = height
        self.nbits = nbits
        self.gain = 1.0
        if width * height > 0 {
            self.pixels = UnsafeMutablePointer<Int16>.alloc(width * height)
        }
    }
    
    deinit {
        self.free()
    }
    
    private func free () {
        let size = self.width * self.height
        if size > 0 {
            self.pixels.dealloc(size)
            self.width = 0
            self.height = 0
        }
    }

    public func set(x: Int, y: Int, value: Int16) {
        let index = x + y * self.width
        if index >= 0 && index < self.width * self.height {
            self.pixels[index] = value
        }
    }
    
    public func get(x: Int, y: Int) -> Int16 {
        let index = x + y * self.width
        if index >= 0 && index < self.width * self.height {
            return self.pixels[index]
        }
        else {
            return -1
        }
    }
    
    public func fill(value: Int16) {
        if self.pixels != nil {
            for var index = 0; index < self.width * self.height; index++ {
                self.pixels[index] = value
            }
        }
    }
    
    public func convolution(kernel: KERNEL, degain: Bool) -> IMAGE {
        let tx = kernel.width / 2
        let ty = kernel.height / 2
        let image = IMAGE(width: self.width, height: self.height, nbits: self.nbits)
        
        // clear out of bounds
        for var y = 0; y < self.height; y++ {
            for var x = 0; x < self.width; x++ {
                if y < ty || y > self.height - ty || x < tx || x > self.width - tx {
                    image!.set(x, y: y, value: 0)
                }
            }
        }
        
        for var y = ty; y < self.height - ty; y++ {
            for var x = tx; x < self.width - tx; x++ {
                var sum: Int = 0
                for var yy = -ty; yy <= ty; yy++ {
                    for var xx = -tx; xx <= tx; xx++ {
                        sum += Int(get(x, y: y) * kernel.get(xx, y: yy))
                    }
                }
                var value: Int16 = 0
                if degain && self.gain > 0 {
                    value = Int16(sum / Int(self.gain))
                }
                else {
                    value = Int16(sum)
                }
                set(x, y: y, value: value)
            }
        }
        
        return image!
    }
    
    public func diff(sub: IMAGE) ->IMAGE {
        assert(self.width == sub.width && self.height == sub.height)
        let image = IMAGE(width: self.width, height: self.height, nbits: self.nbits)
        
        for var y = 0; y < height; y++ {
            for var x = 0; x < width; x++ {
                let index = x + y * width;
                var value: Int32 = Int32(self.pixels[index])
                if value > INT_MAX {
                    value = INT_MAX
                }
                else if value < -INT_MAX {
                    value = -INT_MAX
                }
                image!.set(x, y: y, value: Int16(value))
            }
        }
        
        return image!
    }
    
    public func scaleDown(scale: Int) ->IMAGE {
        assert(scale > 1)
        let w = self.width / scale
        let h = self.height / scale
        let image = IMAGE(width: w, height: h, nbits: self.nbits)
        
        for var y = 0; y < height; y++ {
            for var x = 0; x < width; x++ {
                var sum: Int = 0
                for var yy = 0; yy < scale; yy++ {
                    for var xx = 0; xx < scale; xx++ {
                        sum += Int(self.get(x * scale + xx, y: (y * scale + yy) * width))
                    }
                }
                image!.set(x, y: y, value: Int16(sum / scale / scale))
            }
        }
        return image!
    }
    
    public class RGBA {
        var width: Int
        var height: Int
        var red: IMAGE!
        var green: IMAGE!
        var blue: IMAGE!
        var alpha: IMAGE!
        
        init? (image: UIImage) {
            self.width = Int(image.size.width)
            self.height = Int(image.size.height)
            
            if width * height > 0 {
                self.red = IMAGE(width: width, height: height, nbits: 8)
                self.green = IMAGE(width: width, height: height, nbits: 8)
                self.blue = IMAGE(width: width, height: height, nbits: 8)
                self.alpha = IMAGE(width: width, height: height, nbits: 8)
            }
            
            let imageData = UnsafeMutablePointer<PIXEL>.alloc(self.width * self.height)
            let bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Big.rawValue & CGBitmapInfo.AlphaInfoMask.rawValue
            guard let imageContext = CGBitmapContextCreate(     imageData,
                                                                width,
                                                                height,
                                                                8,
                                                                4 * width,
                                                                CGColorSpaceCreateDeviceRGB(),
                                                                bitmapInfo)
            else {
                    return
            }
            
            guard let cgImage = image.CGImage else {
                return
            }

            
            CGContextDrawImage(imageContext, CGRect(origin: CGPointZero, size: image.size), cgImage)
            for var i = 0; i < self.width * self.height; i++ {
                let data = imageData[i]
                self.red.pixels[i] = Int16(data.red)
                self.green.pixels[i] = Int16(data.green)
                self.blue.pixels[i] = Int16(data.blue)
            }
        }
    
        public func toUIImage() ->UIImage? {
            let bitsPerComponent = 8
            let bytesPerPixel = 4
            let bytesPerRow = width * bytesPerPixel
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            let pixels = UnsafeMutablePointer<PIXEL>.alloc(self.width * self.height)
            for var i = 0; i < self.width * self.height; i++ {
                var red: Int32 = Int32(self.red.pixels[i])
                if red < 0 {
                    red = 0
                }
                var green: Int32 = Int32(self.green.pixels[i])
                if green < 0 {
                    green = 0
                }
                var blue: Int32 = Int32(self.blue.pixels[i])
                if blue < 0 {
                    blue = 0
                }
                var alpha: Int32 = Int32(self.alpha.pixels[i])
                if alpha < 0 {
                    alpha = 0
                }
                
                pixels[i].value = UInt32(red & 0xff)
                                    + UInt32((green & 0xff) << 8)
                                    + UInt32((blue & 0xff) << 16)
                                    + UInt32((alpha & 0xff) << 24)
            }
            
            var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Big.rawValue & CGBitmapInfo.AlphaInfoMask.rawValue
            //bitmapInfo |= CGImageAlphaInfo
            guard let cgImage = CGBitmapContextCreateImage(imageContext) else {
                return nil
            }
            
            return UIImage(CGImage: cgImage)
        }
        
        public func saveToPng(filePath: String) {
            let uiImage = self.ToUIImage()
            let data = UIImagePNGRepresentation(UIImage: uiImage)
            data.writeToFile(filePath)
        }
        
        deinit {
            free()
        }
        
        private func free() {
            if width * height > 0 {
                self.red.free()
                self.green.free()
                self.blue.free()
                self.alpha.free()
                self.width = 0
                self.height = 0
            }
        }
        
    }
    
    
    
    
}
