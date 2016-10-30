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

    func frameDurationForImage(at index: UInt) -> TimeInterval

    subscript(index: UInt) -> UIImage { get }
}

////////////////////////////////////////////////////////////////////////////


// MARK: - GIFAnimatedImage
////////////////////////////////////////////////////////////////////////////

public class GIFAnimatedImage: NSObject, AnimatedImage {
    fileprivate typealias ImageInfo = (image: UIImage, duration: TimeInterval)
    fileprivate let images: [ImageInfo]

    public let size: CGSize

    public var frameCount: UInt {
        return UInt(images.count)
    }

    public init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            images = []
            size = .zero
            super.init()
            return nil
        }

        let count = CGImageSourceGetCount(source)

        images = (0..<count).map { i -> ImageInfo in
            guard let image = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                return (UIImage(), 0)
            }

            let duration: TimeInterval = {
                let info = CGImageSourceCopyPropertiesAtIndex(source, i, nil)
                let gifInfo = unsafeBitCast(CFDictionaryGetValue(info, Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()), to: CFDictionary.self)

                var delay = unsafeBitCast(CFDictionaryGetValue(gifInfo, Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()), to: NSNumber.self)
                if delay.doubleValue <= 0 {
                    delay = unsafeBitCast(CFDictionaryGetValue(gifInfo, Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: NSNumber.self)
                }
                return delay.doubleValue
            }()
            return (UIImage(cgImage: image), duration)
        }

        if let image = images.first {
            size = image.image.size
        } else {
            size = CGSize(width: 0, height: 100)
        }
        super.init()
    }

    public func frameDurationForImage(at index: UInt) -> TimeInterval {
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
    var animated = false
    var lastTimestampChange = CFTimeInterval(0)

    lazy var displayLink: CADisplayLink = {
        let dl = CADisplayLink(target: self, selector: #selector(GIFAnimatedImageView.refreshDisplay))
        dl.add(to: .main, forMode: .commonModes)
        dl.isPaused = true
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
        if !animated {
            displayLink.isPaused = false
            animated = true
        }
    }

    @objc func refreshDisplay() {
        if animated {
            if let animatedImage = animatedImage {
                let currentFrameDuration = animatedImage.frameDurationForImage(at: index)
                let delta = displayLink.timestamp - lastTimestampChange

                if delta >= currentFrameDuration {
                    index = (index + 1) % animatedImage.frameCount
                    lastTimestampChange = displayLink.timestamp
                }
            }
        }
    }

    override func stopAnimating() {
        if animated {
            displayLink.isPaused = true
            animated = false
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
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
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

    public override func willMove(toSuperview newSuperview: UIView?) {
        if let superview = superview as? UIScrollView {
            superview.removeObserver(self, forKeyPath: "contentOffset")
        }
        super.willMove(toSuperview: newSuperview)
    }

    public override func didMoveToSuperview() {
        if let superview = superview as? UIScrollView {
            superview.addObserver(self, forKeyPath: "contentOffset", options: [.new, .old], context: nil)
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

    public var animationDuration = TimeInterval(0.33)

    public var animationDamping = CGFloat(0.4)

    public var animationVelocity = CGFloat(0.8)

    ////////////////////////////////////////////////////////////////////////////


    // MARK: Refresh methods
    ////////////////////////////////////////////////////////////////////////////

    public func beginRefreshing() {
        if let superview = superview as? UIScrollView, !refreshing {
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
        if let superview = superview as? UIScrollView, refreshing {
            forbidsOffsetChanges = false
            refreshing = false

            UIView.animate(withDuration: animationDuration,
                delay: 0,
                usingSpringWithDamping: animationDamping,
                initialSpringVelocity: animationVelocity,
                options: UIViewAnimationOptions.curveLinear,
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

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if !changingInset {
            adaptShift()
        }
    }

    ////////////////////////////////////////////////////////////////////////////


    // MARK: Shift
    ////////////////////////////////////////////////////////////////////////////

    private var expandedHeight: CGFloat {
        let maxHeight = UIScreen.main.bounds.height / 5
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

            if !superview.isDragging && superview.isDecelerating && !forbidsOffsetChanges && forbidsInsetChanges {
                imageView.startAnimating()
                sendActions(for: .valueChanged)

                beginRefreshing()
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////
}

////////////////////////////////////////////////////////////////////////////
