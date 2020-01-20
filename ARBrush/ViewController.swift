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



class ViewController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    let vertBrush = VertBrush()
    var buttonDown = false
    var addPointButton : UIButton!
    var frameIdx = 0
    var splitLine = false
    var lineRadius : Float = 0.001
    
    var metalLayer: CAMetalLayer! = nil
    var hasSetupPipeline = false
    
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
        
        metalLayer = self.sceneView.layer as! CAMetalLayer
        
        
        //addButton()
        
        //self.view.addGestureRecognizer(UIGestureRecognizer.)
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(tapHandler))
        tap.minimumPressDuration = 0
        tap.cancelsTouchesInView = false
        tap.delegate = self
        self.sceneView.addGestureRecognizer(tap)
        
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == gestureRecognizer.view
    }
    
    // called by gesture recognizer
    @objc func tapHandler(gesture: UITapGestureRecognizer) {
        
        // handle touch down and touch up events separately
        if gesture.state == .began {
            // do something...
            buttonTouchDown()
        } else if gesture.state == .ended { // optional for touch up event catching
            // do something else...
            buttonTouchUp()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        // Create a session configuration
      let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        //vertBrush.setupPipeline(device: sceneView.device!, pixelFormat: self.metalLayer.pixelFormat )
        
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
    
    func addButton() {
        
        let sw = self.view.bounds.size.width
        let sh = self.view.bounds.size.height
        
        // red
        let c1 = UIColor(red: 246.0/255.0, green: 205.0/255.0, blue: 73.0/255.0, alpha: 1.0)
        let c2 = UIColor(red: 230.0/255.0, green: 98.0/255.0, blue: 87.0/255.0, alpha: 1.0)
        
        // greenish
        //let c1 = UIColor(red: 112.0/255.0, green: 219.0/255.0, blue: 155.0/255.0, alpha: 1.0)
        //let c2 = UIColor(red: 86.0/255.0, green: 197.0/255.0, blue: 238.0/255.0, alpha: 1.0)
        
        addPointButton = getRoundyButton(size: 60, imageName: "stop", c1, c2)
        //addPointButton.setTitle("+", for: UIControlState.normal)
        
        self.view.addSubview(addPointButton)
        addPointButton.center = CGPoint.init(x: sw / 2.0, y: 120 )
        //addPointButton.addTarget(self, action:#selector(self.buttonTouchDown), for: .touchDown)
        addPointButton.addTarget(self, action:#selector(self.clearDrawing), for: .touchUpInside)
        //addPointButton.addTarget(self, action:#selector(self.buttonTouchUp), for: .touchUpOutside)
        
    }
    
    
    
    @objc func clearDrawing() {
        vertBrush.clear()
    }
    
    @objc func buttonTouchDown() {
        splitLine = true
        buttonDown = true
    }
    @objc func buttonTouchUp() {
        buttonDown = false
    }
    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    //var prevTime : TimeInterval = -1
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        if ( buttonDown ) {
            
            let pointer = getPointerPosition()
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
                    vertBrush.addPoint(pointer.pos, radius: lineRadius, splitLine:splitLine)
                    
                    if ( splitLine ) { splitLine = false }
                    
                }
                
            }
            
        }
        
        if ( frameIdx % 100 == 0 ) {
            print(vertBrush.points.count, " points")
        }
        
        frameIdx = frameIdx + 1
        
        //if ( frameIdx % 2 == 0 ) {
            vertBrush.updateBuffers()
        //}
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
        if ( !hasSetupPipeline ) {
            // pixelFormat is different if called at viewWillAppear
            hasSetupPipeline = true
            vertBrush.setupPipeline(device: sceneView.device!, pixelFormat: self.metalLayer.pixelFormat )
        }
        
        if let commandQueue = self.sceneView?.commandQueue {
            if let encoder = self.sceneView.currentRenderCommandEncoder {
                
                let projMat = float4x4.init((self.sceneView.pointOfView?.camera?.projectionTransform)!)
                let modelViewMat = float4x4.init((self.sceneView.pointOfView?.worldTransform)!).inverse
                
                vertBrush.render(commandQueue, encoder, parentModelViewMatrix: modelViewMat, projectionMatrix: projMat)
                
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
    
    // MARK: stuff
    
    func getPointerPosition() -> (pos : SCNVector3, valid: Bool, camPos : SCNVector3 ) {
        
        guard let pointOfView = sceneView.pointOfView else { return (SCNVector3Zero, false, SCNVector3Zero) }
        guard let currentFrame = sceneView.session.currentFrame else { return (SCNVector3Zero, false, SCNVector3Zero) }
        
        let mat = SCNMatrix4.init(currentFrame.camera.transform)
        let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
        
        let currentPosition = pointOfView.position + (dir * 0.12)
        
        return (currentPosition, true, pointOfView.position)
        
    }
    
}
