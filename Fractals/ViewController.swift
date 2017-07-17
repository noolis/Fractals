//
//  ViewController.swift
//  Fractals
//
//  Created by Tomasz Kopycki on 14/07/2017.
//  Copyright © 2017 Noolis. All rights reserved.
//

import UIKit
import Metal

class ViewController: UIViewController {
    
    var device: MTLDevice!
    var metalLayer: CAMetalLayer!
    
    var juliaBuffer: MTLBuffer!
    
    var mandelbrotPipelineState: MTLComputePipelineState!
    var juliaPipelineState: MTLComputePipelineState!
    
    var threadgroupSizes = ThreadgroupSizes.zeros
    
    var commandQueue: MTLCommandQueue!
    var drawingQueue: DispatchQueue!
    
    var timer: CADisplayLink!
    
    var fakeTouchPoint = CGPoint.zero
    var panTimer: Timer?
    
    var extraWidth: CGFloat = 600
    var extraHeight: CGFloat = 400

    override func viewDidLoad() {
        super.viewDidLoad()
        
        device = MTLCreateSystemDefaultDevice()
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.framebufferOnly = false
        self.metalLayer.frame = CGRect(x: -0.5 * self.extraWidth, y: -0.5 * self.extraHeight, width: self.view.frame.width + self.extraWidth, height: self.view.frame.height + self.extraHeight)
        self.metalLayer.drawableSize = CGSize(width: metalLayer.frame.width * 2, height: metalLayer.frame.height * 2)

        view.layer.addSublayer(metalLayer)
        
        juliaBuffer = device.makeBuffer(length: 2 * MemoryLayout<Float32>.size, options: [])
        
        let library = device.newDefaultLibrary()!
        let mandelbrotFunction = library.makeFunction(name: "mandelbrotShader")!
        let juliaFunction = library.makeFunction(name: "juliaShader")!
        
        mandelbrotPipelineState = try! device.makeComputePipelineState(function: mandelbrotFunction)
        juliaPipelineState = try! device.makeComputePipelineState(function: juliaFunction)
        
        commandQueue = device.makeCommandQueue()
        
        drawingQueue = DispatchQueue(label: "drawingQueue", qos: .userInteractive)
        
        threadgroupSizes = mandelbrotPipelineState.threadgroupSizesForDrawableSize(metalLayer.drawableSize)
        drawMandelbrotSet()
        
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(gestureRecognizer:))))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        panTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { (timer) in
//            let addX: CGFloat = arc4random_uniform(1) % 1 == 0 ? 0.5 : -0.5
//            let addY: CGFloat = arc4random_uniform(1) % 1 == 0 ? 0.5 : -0.5
//            self.fakeTouchPoint.x += addX
//            self.fakeTouchPoint.y += addY
//            
//            self.extraWidth += addX/4
//            self.extraHeight += addY/4
//            
//            self.metalLayer.frame = CGRect(x: -0.5 * self.extraWidth, y: -0.5 * self.extraHeight, width: self.view.frame.width + self.extraWidth, height: self.view.frame.height + self.extraHeight)
//            self.metalLayer.drawableSize = self.metalLayer.frame.size
//            self.threadgroupSizes = self.mandelbrotPipelineState.threadgroupSizesForDrawableSize(self.metalLayer.drawableSize)
//            
//            self.drawJuliaSet(self.fakeTouchPoint)
//        })
    }
    
    func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            drawJuliaSet(gestureRecognizer.translation(in: self.view))
        }
    }
    
    func drawMandelbrotSet()
    {
        drawingQueue.async {
            self.commandQueue.computeAndDraw(into: self.metalLayer.nextDrawable(), with: self.threadgroupSizes) {
                $0.setComputePipelineState(self.mandelbrotPipelineState)
            }
        }
    }
    
    func drawJuliaSet(_ point: CGPoint)
    {
        print(point)
        let thePoint = CGPoint(x: point.x * 2300 / view.frame.width + 2300, y: point.y * 1800 / view.frame.height + 1800)
        
        drawingQueue.async {
            self.commandQueue.computeAndDraw(into: self.metalLayer.nextDrawable(), with: self.threadgroupSizes) {
                $0.setComputePipelineState(self.juliaPipelineState)
                
                // Pass the (x,y) coordinates of the clicked point via the buffer we allocated ahead of time.
                $0.setBuffer(self.juliaBuffer, offset: 0, at: 0)
                let buf = self.juliaBuffer.contents().bindMemory(to: Float32.self, capacity: 2)
                buf[0] = Float32(thePoint.x)
                buf[1] = Float32(thePoint.y)
            }
        }
    }


}

