//
//  ViewController.swift
//  ARBrush
//

import UIKit
import SceneKit
import ARKit
import simd



func getRoundyButton(size: CGFloat = 100,
                     imageName : String,
                     _ colorTop : UIColor ,
                     _ colorBottom : UIColor ) -> UIButton {
    
    let button = UIButton(frame: CGRect.init(x: 0, y: 0, width: size, height: size))
    button.clipsToBounds = true
    button.layer.cornerRadius = size / 2
    
    let gradient: CAGradientLayer = CAGradientLayer()
    
    gradient.colors = [colorTop.cgColor, colorBottom.cgColor]
    gradient.startPoint = CGPoint(x: 1.0, y: 1.0)
    gradient.endPoint = CGPoint(x: 0.0, y: 0.0)
    gradient.frame = button.bounds
    gradient.cornerRadius = size / 2
    
    button.layer.insertSublayer(gradient, at: 0)
    
    let image = UIImage.init(named: imageName )
    let imgView = UIImageView.init(image: image)
    imgView.center = CGPoint.init(x: button.bounds.size.width / 2.0, y: button.bounds.size.height / 2.0 )
    button.addSubview(imgView)
    
    return button
    
}

extension URL {
    
    static func documentsDirectory() -> URL {
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
        
    }
}

extension String {

    // Python-y formatting:  "blah %i".format(4)
    func format(_ args: CVarArg...) -> String {
        return NSString(format: self, arguments: getVaList(args)) as String
    }
    
}



class ViewController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    let vertBrush = VertBrush()
    var buttonDown = false
    
    var clearDrawingButton : UIButton!
    var toggleModeButton : UIButton!
    var recordButton : UIButton!
    
    var frameIdx = 0
    var splitLine = false
    var lineRadius : Float = 0.001
    
    var metalLayer: CAMetalLayer! = nil
    var hasSetupPipeline = false
    
    var videoRecorder : MetalVideoRecorder? = nil
    
    enum ColorMode : Int {
        case color
        case normal
        case rainbow
    }
    
    var currentColor : SCNVector3 = SCNVector3(1,0.5,0)
    var colorMode : ColorMode = .rainbow
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        // This tends to conflict with the rendering
        //sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/world.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        metalLayer = self.sceneView.layer as? CAMetalLayer
        
        metalLayer.framebufferOnly = false
        
        addButtons()
        
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(tapHandler))
        tap.minimumPressDuration = 0
        tap.cancelsTouchesInView = false
        tap.delegate = self
        self.sceneView.addGestureRecognizer(tap)
        
        
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == gestureRecognizer.view
    }
    
    var touchLocation : CGPoint = .zero
    
    // called by gesture recognizer
    @objc func tapHandler(gesture: UITapGestureRecognizer) {
        
        // handle touch down and touch up events separately
        if gesture.state == .began {
            
            self.touchLocation = self.sceneView.center
            buttonTouchDown()
            
        } else if gesture.state == .ended { // optional for touch up event catching
            
            buttonTouchUp()
            
        } else if gesture.state == .changed {
            
            if buttonDown {
                // You can use this to draw with touch location rather than
                // center screen
                //self.touchLocation = gesture.location(in: self.sceneView)
            }
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func addButtons() {
        
        let c1 = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.4)
        let c2 = UIColor(red: 0.6, green: 0.0, blue: 0.0, alpha: 0.4)
        let c3 = UIColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 0.4)
        
        clearDrawingButton = getRoundyButton(size: 55, imageName: "stop", c1, c2)
        clearDrawingButton.addTarget(self, action:#selector(self.clearDrawing), for: .touchUpInside)
        self.view.addSubview(clearDrawingButton)
        
        toggleModeButton = getRoundyButton(size: 55, imageName: "plus", c1, c3)
        toggleModeButton.addTarget(self, action:#selector(self.toggleColorMode), for: .touchUpInside)
        self.view.addSubview(toggleModeButton)
        
        recordButton = getRoundyButton(size: 55, imageName: "", UIColor.red.withAlphaComponent(0.5), UIColor.red.withAlphaComponent(0.5))
        recordButton.addTarget(self, action:#selector(self.recordTapped), for: .touchUpInside)
        recordButton.alpha = 0.5
        self.view.addSubview(recordButton)
        
    }
    
    override func viewDidLayoutSubviews() {
        let sw = self.view.bounds.size.width
        let sh = self.view.bounds.size.height
        
        let off : CGFloat = 50
        clearDrawingButton.center = CGPoint(x: sw - off, y: sh - off )
        
        
        toggleModeButton.center = CGPoint(x: off, y: sh - off)
        
        
        recordButton.center = CGPoint(x: sw/2.0, y: sh - off)
    }
    
    // MARK: - Buttons
    
    @objc func toggleColorMode() {
        
        Haptics.strongBoom()
        self.colorMode = ColorMode(rawValue: (self.colorMode.rawValue + 1) % 3)!
        
    }
    
    @objc func clearDrawing() {
        
        Haptics.threeWeakBooms()
        vertBrush.clear()
    }
    
    
    @objc func recordTapped() {
        
        if let rec = self.videoRecorder, rec.isRecording {
            
            rec.endRecording {
                print("Recording done!")
                Haptics.strongBoom()
                DispatchQueue.main.async {
                    self.recordButton.alpha = 0.5
                    //self.recordButton.backgroundColor = UIColor.black.withAlphaComponent(0.2)
                }
            }
            
        } else {
            
            var videoOutUrl : URL! = nil
            
            for i in 0...1000 {
                videoOutUrl = URL.documentsDirectory().appendingPathComponent("video_%i.mp4".format(i))
                if !FileManager.default.fileExists(atPath: videoOutUrl.path) {
                    break
                }
            }
            
            assert(videoOutUrl != nil )
            
            //let tex = renderer.renderDestination.currentDrawable!.texture
            //let size = CGSize(width: tex.width, height: tex.height)
            
            //let size = (self.view as! MTKView).drawableSize
            let size = self.metalLayer.drawableSize
            
            
            
            print(" >> Init video with size: ", size )
            Haptics.strongBoom()
            
            let rec = MetalVideoRecorder(outputURL: videoOutUrl, size: size)
            rec?.startRecording()
            
            self.videoRecorder = rec
            
            self.recordButton.alpha = 1.0
            
        }
        
    }
    
    
    // MARK: - Touch
    @objc func buttonTouchDown() {
        splitLine = true
        buttonDown = true
        avgPos = nil
        
//        let pointer = getPointerPosition()
//        if pointer.valid {
//            self.addBall(pointer.pos)
//        }
        
    }
    @objc func buttonTouchUp() {
        buttonDown = false
    }
    
    // MARK: - ARSCNViewDelegate
    
    // Test mixing with scenekit content
    func addBall( _ pos : SCNVector3 ) {
        let b = SCNSphere(radius: 0.01)
        b.firstMaterial?.diffuse.contents = UIColor.red
        let n = SCNNode(geometry: b)
        n.worldPosition = pos
        self.sceneView.scene.rootNode.addChildNode(n)
    }
    
    var avgPos : SCNVector3! = nil
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        let pointer = getPointerPosition()
        
        if avgPos == nil {
            avgPos = pointer.pos
        }
        
        avgPos = avgPos - (avgPos - pointer.pos) * 0.4;
        
        if ( buttonDown ) {
            
            if ( pointer.valid ) {
                
                if ( vertBrush.points.count == 0 || (vertBrush.points.last! - pointer.pos).length() > 0.001 ) {
                    
                    var radius : Float = 0.001
                    
                    if ( splitLine || vertBrush.points.count < 2 ) {
                        lineRadius = 0.001
                    } else {
                        
                        let i = vertBrush.points.count-1
                        let p1 = vertBrush.points[i]
                        let p2 = vertBrush.points[i-1]
                        
                        radius = 0.001 + min(0.015, 0.005 * pow( ( p2-p1 ).length() / 0.005, 2))
                        
                    }
                    
                    lineRadius = lineRadius - (lineRadius - radius)*0.075
                    
                    var color : SCNVector3
                    
                    switch colorMode {
                        
                        case .rainbow:
                            
                            let hue : CGFloat = CGFloat(fmodf(Float(vertBrush.points.count) / 30.0, 1.0))
                            let c = UIColor.init(hue: hue, saturation: 0.95, brightness: 0.95, alpha: 1.0)
                            var red : CGFloat = 0.0; var green : CGFloat = 0.0; var blue : CGFloat = 0.0;
                            c.getRed(&red, green: &green, blue: &blue, alpha: nil)
                            color = SCNVector3(red, green, blue)
                            
                        case .normal:
                            // Hack: if the color is negative, use the normal as the color
                            color = SCNVector3(-1, -1, -1)
                            
                        case .color:
                            color = self.currentColor
                    
                    }
                    
                    vertBrush.addPoint(avgPos,
                                       radius: lineRadius,
                                       color: color,
                                       splitLine:splitLine)
                    
                    if ( splitLine ) { splitLine = false }
                    
                }
                
            }
            
        }
        
        if ( frameIdx % 100 == 0 ) {
            print(vertBrush.points.count, " points")
        }
        
        frameIdx = frameIdx + 1
        
    }
    
    
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        

        if ( !hasSetupPipeline ) {
            // pixelFormat is different if called at viewWillAppear
            hasSetupPipeline = true
            
            vertBrush.setupPipeline(device: sceneView.device!, renderDestination: self.sceneView! )
        }
        
        guard let frame = self.sceneView.session.currentFrame else {
            return
        }
        
        if let commandQueue = self.sceneView?.commandQueue {
            if let encoder = self.sceneView.currentRenderCommandEncoder {
                
                let projMat = float4x4.init((self.sceneView.pointOfView?.camera?.projectionTransform)!)
                let modelViewMat = float4x4.init((self.sceneView.pointOfView?.worldTransform)!).inverse
                
                vertBrush.updateSharedUniforms(frame: frame)
                vertBrush.render(commandQueue, encoder, parentModelViewMatrix: modelViewMat, projectionMatrix: projMat)
                
                
            }
        }
        
        
        
        // This is not the right way to do this ..
        // seems to work though
        DispatchQueue.global(qos: .userInteractive).async {

            if let recorder = self.videoRecorder,
                recorder.isRecording {

                if let tex = self.metalLayer.nextDrawable()?.texture {
                    recorder.writeFrame(forTexture: tex)
                }
            }
        }
        
    }
    

    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    // MARK: -
    
    func getPointerPosition() -> (pos : SCNVector3, valid: Bool, camPos : SCNVector3 ) {
        
        // Un-project a 2d screen location into ARKit world space using the 'unproject'
        // function. 
        
        guard let pointOfView = sceneView.pointOfView else { return (SCNVector3Zero, false, SCNVector3Zero) }
        guard let currentFrame = sceneView.session.currentFrame else { return (SCNVector3Zero, false, SCNVector3Zero) }
        
        let cameraPos = SCNVector3(currentFrame.camera.transform.translation)
        
        let touchLocationVec = SCNVector3(x: Float(touchLocation.x), y: Float(touchLocation.y), z: 0.01)
        
        let screenPosOnFarClippingPlane = self.sceneView.unprojectPoint(touchLocationVec)
        
        let dir = (screenPosOnFarClippingPlane - cameraPos).normalized()
        
        let worldTouchPos = cameraPos + dir * 0.12

        return (worldTouchPos, true, pointOfView.position)
        
    }
    
}
