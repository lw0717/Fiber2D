//
//  Transition.swift
//
//  Created by Andrey Volodin on 22.07.16.
//  Copyright © 2016. All rights reserved.
//

import Foundation

/**
 A transition animates the presesntation of a new scene while moving the current scene out of view.
 A transition is optionally played when calling one of the presentScene:withTransition: methods of CCDirector.
 
 @note Since both scenes remain in memory and are being rendered, a transition may raise performance issues or
 memory warnings. If two complex scenes can not be reliably transitioned from/to it is best to not use transitions
 or to introduce an in-between scene that is presented only for a short period of time (ie a loading scene or merely
 a "fade to black" scene).
 */
class Transition: Scene {
    /**
     *  Creates a blank transition from outgoing to incoming scene.
     *
     *  @param duration The duration of the transition in seconds.
     *
     *  @return The CCTransition Object.
     *  @note Use this initializer only for implementing custom transitions.
     */
    init(duration: TimeInterval) {
        self.duration = duration
        super.init()
        self.userInteractionEnabled = false
    }
    
    private let duration: Double
    private var incomingScene: Scene!
    private var outgoingScene: Scene!
    var incomingPauseState = false
    /// -----------------------------------------------------------------------
    /// @name Transition Performance Settings
    /// -----------------------------------------------------------------------
    /**
     *  Will downscale outgoing scene.
     *  Can be used as an effect, or to decrease render time on complex scenes.
     *  Default 1.0.
     */
    var outgoingDownScale: Float = 1.0 {
        willSet {
            assert((newValue >= 1.0) && (newValue <= 4.0), "Invalid down scale")
        }
    }
    /**
     *  Will downscale incoming scene.
     *  Can be used as an effect, or to decrease render time on complex scenes.
     *  Default 1.0.
     */
    var incomingDownScale: Float = 1.0 {
        willSet {
            assert((newValue >= 1.0) && (newValue <= 4.0), "Invalid down scale")
        }
    }
    /**
     *  Depth/stencil format used for transition.
     *  Default `GL_DEPTH24_STENCIL8_OES`.
     */
    var transitionDepthStencilFormat: MTLPixelFormat = .depth32Float_Stencil8
    /// -----------------------------------------------------------------------
    /// @name Controlling Scene Animation during Transition
    /// -----------------------------------------------------------------------
    /**
     *  Defines whether outgoing scene will be animated during transition.
     *  Default NO.
     */
    var outgoingSceneAnimated: Bool = false
    /**
     *  Defines whether incoming scene will be animated during transition.
     *  Default NO.
     */
    var incomingSceneAnimated: Bool = false
    /**
     *  Defines whether incoming scene will be animated during transition.
     *  Default NO.
     */
    var outgoingOverIncoming: Bool = false
    /// -----------------------------------------------------------------------
    /// @name For use with Custom Transitions
    /// -----------------------------------------------------------------------
    /**
     *  CCRenderTexture, holding the incoming scene as a texture
     *  Only valid after StartTransition has been called.
     */
    var incomingTexture: RenderTexture!
    
    /**
     *  CCRenderTexture, holding the outgoing scene as a texture
     *  Only valid after StartTransition has been called.
     */
    var outgoingTexture: RenderTexture!
    
    /// -----------------------------------------------------------------------
    /// @name Transition Running Time and Progress
    /// -----------------------------------------------------------------------
    /** The actual transition runtime in seconds. */
    var runTime: Double = 0.0
    /** Normalized (percentage) transition progress in the range 0.0 to 1.0. */
    var progress: Float = 0.0
    
    func update(_ delta: CCTime) {
        // update progress
        self.runTime += delta
        self.progress = clampf(Float(runTime / duration), 0.0, 1.0)
        // check for runtime expired
        if progress >= 1.0 {
            // Exit out scene
            outgoingScene.onExit()
            if Director.currentDirector()!.sendCleanupToScene {
                outgoingScene.cleanup()
            }
            self.outgoingScene = nil
            // Start incoming scene
            Director.currentDirector()!.presentScene(incomingScene)
            incomingScene.onEnterTransitionDidFinish()
            incomingScene.paused = false
            self.incomingScene = nil
            return
        }
        // render the scenes
        if incomingSceneAnimated {
            self.renderIncoming(progress)
        }
        if outgoingSceneAnimated {
            self.renderOutgoing(progress)
        }

    }
    
    func renderOutgoing(_ progress: Float) {
        let color: GLKVector4 = outgoingScene.colorRGBA.glkVector4
        outgoingTexture.beginWithClear(color.r, g: color.g, b: color.b, a: color.a)
        outgoingScene.visit()
        outgoingTexture.end()
    }
    
    func renderIncoming(_ progress: Float) {
        let color: GLKVector4 = incomingScene.colorRGBA.glkVector4
        incomingTexture.beginWithClear(color.r, g: color.g, b: color.b, a: color.a)
        incomingScene.visit()
        incomingTexture.end()
    }
    
    func startTransition(_ scene: Scene, withDirector director: Director) {
        scene.director = director
        self.director = director
        
        self.incomingScene = scene
        incomingScene.onEnter()
        self.incomingPauseState = incomingScene.paused
        self.incomingScene.paused = incomingScene.paused || !incomingSceneAnimated
        self.outgoingScene = director.runningScene
        outgoingScene.onExitTransitionDidStart()
        self.outgoingScene.paused = outgoingScene.paused || !outgoingSceneAnimated
        // create render textures
        // get viewport size
        let rect: CGRect = director.viewportRect()
        var size: CGSize = rect.size
        // Make sure we aren't rounding down.
        size.width = ceil(rect.size.width)
        size.height = ceil(rect.size.height)
        // create texture for outgoing scene
        self.outgoingTexture = RenderTexture(width: Int(size.width), height: Int(size.height))
        self.outgoingTexture.position = CGPoint(x: size.width * 0.5 + rect.origin.x, y: size.height * 0.5 + rect.origin.y)
        self.outgoingTexture.contentScale /= outgoingDownScale
        self.outgoingTexture.projection = incomingScene.projection
        self.addChild(outgoingTexture, z: outgoingOverIncoming ? 1 : 0)
        // create texture for incoming scene
        self.incomingTexture = RenderTexture(width: Int(size.width), height: Int(size.height))
        self.incomingTexture.position = CGPoint(x: size.width * 0.5 + rect.origin.x, y: size.height * 0.5 + rect.origin.y)
        self.incomingTexture.contentScale /= incomingDownScale
        self.incomingTexture.projection = incomingScene.projection
        self.addChild(incomingTexture)
        // make sure scene is rendered at least once at progress 0.0
        self.renderOutgoing(0)
        self.renderIncoming(0)
        // switch to transition scene
        director.startTransition(self)

    }
}
