//
//  GIFRefreshControl.swift
//  GIFRefreshControl
//
//  Created by Kevin DELANNOY on 16/05/15.
//  Copyright (c) 2015 Kevin Delannoy. All rights reserved.
//

import UIKit
import ImageIO

// MARK: - AnimatedImage
////////////////////////////////////////////////////////////////////////////

@objc public protocol AnimatedImage {
    var size: CGSize { get }
    var frameCount: UInt { get }

    func frameDurationForImageAtIndex(index: UInt) -> NSTimeInterval

    subscript(index: UInt) -> UIImage { get }
}

////////////////////////////////////////////////////////////////////////////


// MARK: - GIFAnimatedImage
////////////////////////////////////////////////////////////////////////////

public class GIFAnimatedImage: NSObject, AnimatedImage {
    private typealias ImageInfo = (image: UIImage, duration: NSTimeInterval)
    private let images: [ImageInfo]

    public let size: CGSize

    public var frameCount: UInt {
        return UInt(images.count)
    }

    public init?(data: NSData) {
        if let source = CGImageSourceCreateWithData(data, nil) {
            let count = CGImageSourceGetCount(source)

            images = (0..<count).map { i -> ImageInfo in
                if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    let duration: NSTimeInterval = {
                        let info = CGImageSourceCopyPropertiesAtIndex(source, i, nil)
                        let gifInfo = unsafeBitCast(CFDictionaryGetValue(info, unsafeAddressOf(kCGImagePropertyGIFDictionary)), CFDictionary.self)

                        var delay = unsafeBitCast(CFDictionaryGetValue(gifInfo, unsafeAddressOf(kCGImagePropertyGIFUnclampedDelayTime)), NSNumber.self)
                        if delay.doubleValue <= 0 {
                            delay = unsafeBitCast(CFDictionaryGetValue(gifInfo, unsafeAddressOf(kCGImagePropertyGIFDelayTime)), NSNumber.self)
                        }

                        return delay.doubleValue
                    }()
                    return (UIImage(CGImage: image), duration)
                }
                return (UIImage(), 0)
            }

            if let image = images.first {
                size = image.image.size
            }
            else {
                size = CGSize(width: 0, height: 100)
            }
            super.init()
        }
        else {
            images = []
            size = .zero
            super.init()
            return nil
        }
    }

    public func frameDurationForImageAtIndex(index: UInt) -> NSTimeInterval {
        return images[Int(index)].duration
    }

    public subscript(index: UInt) -> UIImage {
        return images[Int(index)].image
    }
}

////////////////////////////////////////////////////////////////////////////


// MARK: - GIFAnimatedImageView
////////////////////////////////////////////////////////////////////////////

private class GIFAnimatedImageView: UIImageView {
    var animatedImage: AnimatedImage? {
        didSet {
            image = animatedImage?[0]
        }
    }
    var animating = false
    var lastTimestampChange = CFTimeInterval(0)

    lazy var displayLink: CADisplayLink = {
        let dl = CADisplayLink(target: self, selector: "refreshDisplay")
        dl.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        dl.paused = true
        return dl
    }()

    var index = UInt(0) {
        didSet {
            if index != oldValue {
                image = animatedImage?[index]
            }
        }
    }

    override func startAnimating() {
        if !animating {
            displayLink.paused = false
            animating = true
        }
    }

    @objc func refreshDisplay() {
        if animating {
            if let animatedImage = animatedImage {
                let currentFrameDuration = animatedImage.frameDurationForImageAtIndex(index)
                let delta = displayLink.timestamp - lastTimestampChange

                if delta >= currentFrameDuration {
                    index = (index + 1) % animatedImage.frameCount
                    lastTimestampChange = displayLink.timestamp
                }
            }
        }
    }

    override func stopAnimating() {
        if animating {
            displayLink.paused = true
            animating = false
        }
    }
}

////////////////////////////////////////////////////////////////////////////


// MARK: - GIFRefreshControl
////////////////////////////////////////////////////////////////////////////

public class GIFRefreshControl: UIControl {
    private var imageView = GIFAnimatedImageView()

    private var forbidsOffsetChanges = false
    private var forbidsInsetChanges = false
    private var changingInset = false
    private var refreshing = false
    private var contentInset: UIEdgeInsets?

    // MARK: Initialization
    ////////////////////////////////////////////////////////////////////////////

    public convenience init() {
        self.init(frame: .zero)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    private func commonInit() {
        imageView.frame = bounds
        imageView.clipsToBounds = true
        imageView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        addSubview(imageView)
    }

    deinit {
        imageView.stopAnimating()
        if let superview = superview as? UIScrollView {
            superview.removeObserver(self, forKeyPath: "contentOffset")
        }
    }

    ////////////////////////////////////////////////////////////////////////////


    // MARK: Superview handling
    ////////////////////////////////////////////////////////////////////////////

    public override func willMoveToSuperview(newSuperview: UIView?) {
        if let superview = superview as? UIScrollView {
            superview.removeObserver(self, forKeyPath: "contentOffset")
        }
        super.willMoveToSuperview(newSuperview)
    }

    public override func didMoveToSuperview() {
        if let superview = superview as? UIScrollView {
            superview.addObserver(self, forKeyPath: "contentOffset", options: [.New, .Old], context: nil)
        }
        super.didMoveToSuperview()
    }

    ////////////////////////////////////////////////////////////////////////////


    // MARK: Configuration
    ////////////////////////////////////////////////////////////////////////////

    public var animatedImage: AnimatedImage? {
        get {
            return imageView.animatedImage
        }
        set {
            imageView.animatedImage = newValue
        }
    }

    public override var contentMode: UIViewContentMode {
        get {
            return imageView.contentMode
        }
        set {
            imageView.contentMode = newValue
        }
    }

    public var animateOnScroll = true

    public var animationDuration = NSTimeInterval(0.33)

    public var animationDamping = CGFloat(0.4)

    public var animationVelocity = CGFloat(0.8)

    ////////////////////////////////////////////////////////////////////////////


    // MARK: Refresh methods
    ////////////////////////////////////////////////////////////////////////////

    public func beginRefreshing() {
        if let superview = superview as? UIScrollView where !refreshing {
            refreshing = true

            //Saving inset
            contentInset = superview.contentInset
            let currentOffset = superview.contentOffset

            //Setting new inset
            changingInset = true
            var inset = superview.contentInset
            inset.top = inset.top + expandedHeight
            superview.contentInset = inset
            changingInset = false

            //Aaaaand scrolling
            superview.setContentOffset(currentOffset, animated: false)
            superview.setContentOffset(CGPoint(x: 0, y: -inset.top), animated: true)
            forbidsOffsetChanges = true
        }
    }

    public func endRefreshing() {
        if let superview = superview as? UIScrollView where refreshing {
            forbidsOffsetChanges = false
            refreshing = false

            UIView.animateWithDuration(animationDuration,
                delay: 0,
                usingSpringWithDamping: animationDamping,
                initialSpringVelocity: animationVelocity,
                options: UIViewAnimationOptions.CurveLinear,
                animations: { () -> Void in

                    if let contentInset = self.contentInset {
                        superview.contentInset = contentInset
                        self.contentInset = nil
                    }

                }) { (finished) -> Void in

                    self.imageView.stopAnimating()
                    self.imageView.index = 0

            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////


    // MARK: KVO
    ////////////////////////////////////////////////////////////////////////////

    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if !changingInset {
            adaptShift()
        }
    }

    ////////////////////////////////////////////////////////////////////////////


    // MARK: Shift
    ////////////////////////////////////////////////////////////////////////////

    private var expandedHeight: CGFloat {
        let maxHeight = UIScreen.mainScreen().bounds.height / 5
        let height = imageView.animatedImage?.size.height
        return min(maxHeight, height ?? maxHeight)
    }

    private func adaptShift() {
        if let superview = superview as? UIScrollView {
            //Updating frame
            let topInset = (contentInset ?? superview.contentInset).top
            let originY = superview.contentOffset.y + topInset
            let height = originY

            frame = CGRect(origin: CGPoint(x: 0, y: originY),
                size: CGSize(width: superview.frame.width, height: -height))

            //Detecting refresh gesture
            if superview.contentOffset.y + topInset <= -expandedHeight {
                forbidsInsetChanges = true
            }
            else {
                if !refreshing {
                    forbidsInsetChanges = false
                }
            }

            //We cannot do this in the previous if/else because then some frames
            //might not be drawn
            if animateOnScroll && !refreshing && superview.contentOffset.y + topInset < 0 {
                let percentage = min(1, fabs(height) / expandedHeight)
                let count = CGFloat(imageView.animatedImage?.frameCount ?? 1) - 1
                let index = UInt(count * percentage)
                imageView.index = index
            }

            if !superview.dragging && superview.decelerating && !forbidsOffsetChanges && forbidsInsetChanges {
                imageView.startAnimating()
                sendActionsForControlEvents(.ValueChanged)

                beginRefreshing()
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////
}

////////////////////////////////////////////////////////////////////////////
