//
//  KYVideoRangeSlider.swift
//  Pods
//
//  Created by Kyle on 2017/9/5.
//
//

import UIKit
import AVFoundation


internal class KYVideoRangeSliderThumbView : UIImageView{
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


internal class KYVideoRangeSliderTrackLayer: CAShapeLayer {

    weak var rangeSlider : KYVideoRangeSlider?

    override func draw(in ctx: CGContext) {
        if let slider = rangeSlider {
            let lowerValuePosition = slider.leftThumbPositionX+slider.thumbWidth
            let upperValuePosition = slider.frame.width + slider.rightThumbPositionX - slider.thumbWidth
            let rect = CGRect(x: lowerValuePosition, y: 0.0, width: upperValuePosition - lowerValuePosition, height: bounds.height)
            ctx.setFillColor(slider.trackColor.cgColor)
            ctx.fill(rect)
        }
    }

}

internal class KYVideoRangeSliderUnTrackLayer: CAShapeLayer {

    weak var rangeSlider : KYVideoRangeSlider?

    var isLeftSide : Bool = true

    override func draw(in ctx: CGContext) {
        if let slider = rangeSlider {
            let leftPosition : CGFloat
            let width : CGFloat
            if isLeftSide {
                leftPosition = slider.thumbWidth
                width =  max((slider.leftThumbPositionX - slider.thumbWidth),0)
            }else{
                leftPosition = slider.frame.width + slider.rightThumbPositionX
                width =  max(abs(slider.rightThumbPositionX)-slider.thumbWidth,0)
            }

            let rect = CGRect(x: leftPosition, y: 1.0, width: width, height: bounds.height-2)
            ctx.setFillColor(slider.unTrackColor.cgColor)
            ctx.fill(rect)
        }
    }
    
}




@objc public protocol KYVideoRangeSliderDelegate : NSObjectProtocol{

    @objc optional func videoRangeSliderBeginDragging(_ slider:KYVideoRangeSlider)
    @objc optional func videoRangeSlider(_ slider:KYVideoRangeSlider, lowerValue : Double,upperValue:Double)
}



open class KYVideoRangeSlider: UIView {


    public weak var delegate :KYVideoRangeSliderDelegate?

    //MARK: property

    public var maxTrackTime : Double = 10.0
    public var minTrackTime : Double = 3.0
    public var trackedDuration : Double{
        get{
            return self.upperValue - self.lowerValue
        }
    }
    public var lowerValue: Double{
        get{
            return self.mapperLeftPositonToTime(self.leftThumbPositionX)
        }
    }
    public var upperValue: Double{
        get{
            return self.mapperRightPositonToTime(self.rightThumbPositionX)
        }
    }

    public var leftThumbPositionX : CGFloat = 0{
        didSet{
            self.leftThumbViewLeadingContraint.constant = leftThumbPositionX
            self.updateLayerFrames()
        }
    }
    public var rightThumbPositionX : CGFloat = 0{
        didSet{
            self.rightThumbViewTrailingContraint.constant = rightThumbPositionX
            self.updateLayerFrames()
        }
    }

    public var selecteTimeLength : CGFloat  {
       return self.sliderWidth - self.leftThumbPositionX + self.rightThumbPositionX
    }

    public fileprivate(set) var rangeStartTime : Double = 0
    public fileprivate(set) var rangeEndTime : Double = 1
    fileprivate var keyframeWidth : CGFloat = 40
    fileprivate var videoTrackLength : CGFloat {
        let trackLength = self.keyframeWidth * CGFloat(self.videoKeyframes.count)
        if trackLength == 0 {
            return 1
        }
        return trackLength
    }

    public var displayDuration : Double{
        get{
            return Double(self.sliderWidth/self.videoTrackLength)*self.duration
        }
    }
    public private(set) var duration : Double = 0{
        didSet{
            if (duration > maxTrackTime){
                rangeStartTime = 0
                rangeEndTime = maxTrackTime
            }else{
                rangeStartTime = 0
                rangeEndTime = duration
            }
            self.updateInitState()

        }
    }
    public private(set) var videoAsset : AVAsset?{
        didSet{
            if let asset = videoAsset {
                duration = Double(CMTimeGetSeconds(asset.duration))
            }
        }
    }
    public private(set) var videoKeyframes : [KYVideoKeyframe] = []{
        didSet{

            var count = 0
            if (self.duration > self.maxTrackTime){
                let percent = self.maxTrackTime/self.duration
                let percentCount = Double(self.videoKeyframes.count) * percent
                self.keyframeWidth = self.sliderWidth / CGFloat(percentCount)
            }else if(duration <= 3.0){
                count = videoKeyframes.count
                self.keyframeWidth = 40
                var contraintsValue =  CGFloat(count) * self.keyframeWidth - self.frame.width
                if contraintsValue > 0 {
                    contraintsValue = 0
                    self.keyframeWidth = self.frame.width/CGFloat(count)
                }
                self.collectionViewTraingContraint.constant = contraintsValue

            }else{
                count = videoKeyframes.count
                self.keyframeWidth = self.sliderWidth / CGFloat(count)
            }
            self.collectionView.reloadData()
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }
    }

    open var trackColor : UIColor = UIColor.red {
        didSet{
            self.updateLayerFrames()
        }
    }

    open var unTrackColor : UIColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5){
        didSet{
            self.updateLayerFrames()
        }
    }

    open var thumbWidth : CGFloat = 10{
        didSet{
            self.leftThumbViewWidthContraint.constant = self.thumbWidth
            self.rightThumbViewWidthContraint.constant = self.thumbWidth
            self.collectionViewLeadingContraint.constant = self.thumbWidth
            self.collectionViewTraingContraint.constant = -self.thumbWidth
        }
    }
    fileprivate var sliderWidth : CGFloat{
        get{
            return self.frame.width - self.thumbWidth*2
        }
    }

    open var leftThumbImage : UIImage?{
        didSet{
            self.leftThumbView.image = self.leftThumbImage
        }
    }

    open var rightThumbImage : UIImage? {
        didSet{
            self.rightThumbView.image = self.rightThumbImage
        }
    }

    //MARK: subviews
    internal var collectionView : UICollectionView!
    internal lazy var collectionFlowLayout : UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        return layout
    }()

    internal let leftThumbView : KYVideoRangeSliderThumbView = KYVideoRangeSliderThumbView(frame: .zero)
    internal let rightThumbView : KYVideoRangeSliderThumbView = KYVideoRangeSliderThumbView(frame: .zero)
    internal var leftThumbViewLeadingContraint : NSLayoutConstraint!
    internal var leftThumbViewWidthContraint : NSLayoutConstraint!
    internal var rightThumbViewTrailingContraint : NSLayoutConstraint!
    internal var rightThumbViewWidthContraint : NSLayoutConstraint!
    internal var collectionViewLeadingContraint : NSLayoutConstraint!
    internal var collectionViewTraingContraint : NSLayoutConstraint!
    internal var trackLayer = KYVideoRangeSliderTrackLayer()
    internal var leftUntrackLayer = KYVideoRangeSliderUnTrackLayer()
    internal var rightUnTrackLayer = KYVideoRangeSliderUnTrackLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()

    }

    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateAsset(_ asset : AVAsset?,keyframes : [KYVideoKeyframe]){
        guard let _ = asset , keyframes.count != 0 else{
            fatalError("update the video asset can not be nil")
        }
        self.videoAsset = asset
        self.videoKeyframes = keyframes
    }

    //MARK: private method
    private func setup(){
        
        self.trackLayer.rangeSlider = self
        self.layer.addSublayer(self.trackLayer)
        self.trackLayer.contentsScale = UIScreen.main.scale

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.collectionFlowLayout)
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.clipsToBounds = true
        self.addSubview(self.collectionView)
        self.collectionView.register(KYVideoRangeCollectionCell.self, forCellWithReuseIdentifier: "rangecell")

        self.leftThumbView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.leftThumbView)

        self.rightThumbView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.rightThumbView)


        self.leftUntrackLayer.rangeSlider = self
        self.leftUntrackLayer.isLeftSide = true
        self.layer.addSublayer(self.leftUntrackLayer)
        self.leftUntrackLayer.contentsScale = UIScreen.main.scale

        self.rightUnTrackLayer.rangeSlider = self
        self.rightUnTrackLayer.isLeftSide = false
        self.layer.addSublayer(self.rightUnTrackLayer)
        self.rightUnTrackLayer.contentsScale = UIScreen.main.scale


        var constraints : [NSLayoutConstraint] = []

        let views = ["leftThumbView":self.leftThumbView,"rightThumbView":self.rightThumbView,"collectionView":self.collectionView] as [String:Any]

        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[leftThumbView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[rightThumbView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)

        self.leftThumbViewLeadingContraint = NSLayoutConstraint(item: self.leftThumbView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0)
        self.leftThumbViewWidthContraint =  NSLayoutConstraint(item: self.leftThumbView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 0.0, constant: self.thumbWidth)
        self.rightThumbViewTrailingContraint = NSLayoutConstraint(item: self.rightThumbView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0)
        self.rightThumbViewWidthContraint =  NSLayoutConstraint(item: self.rightThumbView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 0.0, constant: self.thumbWidth)

        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-1-[collectionView]-1-|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        self.collectionViewLeadingContraint = NSLayoutConstraint(item: self.collectionView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: self.thumbWidth)
        self.collectionViewTraingContraint =  NSLayoutConstraint(item: self.collectionView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: -self.thumbWidth)

        constraints.append(self.collectionViewLeadingContraint)
        constraints.append(self.collectionViewTraingContraint)
        constraints.append(self.leftThumbViewLeadingContraint)
        constraints.append(self.leftThumbViewWidthContraint)
        constraints.append(self.rightThumbViewTrailingContraint)
        constraints.append(self.rightThumbViewWidthContraint)

        self.addConstraints(constraints)


        let leftThumbPan : UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(KYVideoRangeSlider.leftPanAction(_:)))
        self.leftThumbView.addGestureRecognizer(leftThumbPan)

        let rightThumbPan : UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(KYVideoRangeSlider.rightPanAction(_:)))
        self.rightThumbView.addGestureRecognizer(rightThumbPan)

    }

    private func updateInitState(){
        self.leftThumbPositionX = 0
        self.rightThumbPositionX = 0
    }

    open override func layoutSubviews() {
        self.updateLayerFrames()
    }

    fileprivate func updateLayerFrames(){
        self.trackLayer.frame = self.bounds
        self.leftUntrackLayer.frame = self.bounds
        self.rightUnTrackLayer.frame = self.bounds
        self.trackLayer.setNeedsDisplay()
        self.leftUntrackLayer.setNeedsDisplay()
        self.rightUnTrackLayer.setNeedsDisplay()
    }

    //mapper the position to time
    fileprivate func mapperLeftPositonToTime(_ postionX : CGFloat) -> Double{
        return Double(postionX/self.sliderWidth)*self.displayDuration + self.rangeStartTime
    }

    fileprivate func mapperRightPositonToTime(_ postionX : CGFloat) -> Double{
        return Double((self.sliderWidth+postionX)/self.sliderWidth)*self.displayDuration + self.rangeStartTime
    }
    //mapper the time to position
    fileprivate func mapperTimeToLeftPosition(_ time : Double) -> CGFloat{
        return CGFloat((time - rangeStartTime)/self.displayDuration) * self.sliderWidth
    }
    fileprivate func mapperTimeToRightPosition(_ time : Double) -> CGFloat{
        return  CGFloat((time - self.rangeStartTime)/self.displayDuration) * self.sliderWidth - self.sliderWidth
    }

    //mapper double value to CMTime
    public func mapperToCMTime(_ value : Double) ->CMTime{
        guard let asset = videoAsset else {
            return CMTime()
        }
        let time = CMTimeMakeWithSeconds(value, asset.duration.timescale)
        return time
    }

    private func calucateLeftThumbPostion(_ postionX : CGFloat) -> CGFloat{
        var postion = postionX
        if postion < 0 {
            postion = 0
        }

        var positionTime = self.mapperLeftPositonToTime(postion)
        let selecteDuration = self.upperValue - positionTime
        if selecteDuration > self.maxTrackTime {
            positionTime = self.upperValue - self.maxTrackTime
        }else if selecteDuration < self.minTrackTime {
            positionTime = self.upperValue - self.minTrackTime
        }
        return self.mapperTimeToLeftPosition(positionTime)
    }

    private func calucateRightThumbPostion(_ postionX : CGFloat) -> CGFloat{
        var postion = postionX
        if postion < -self.sliderWidth {
            postion = -self.sliderWidth
        }else if postion > 0 {
            postion = 0
        }

        var positionTime = self.mapperRightPositonToTime(postion)
        let selecteDuration = positionTime - self.lowerValue
        if selecteDuration > self.maxTrackTime {
            positionTime = self.lowerValue + self.maxTrackTime
        }else if selecteDuration < minTrackTime {
            positionTime = self.lowerValue + self.minTrackTime
        }
        return self.mapperTimeToRightPosition(positionTime)
    }



    //MARK: action
    @objc func leftPanAction(_ gesture : UIPanGestureRecognizer){
       if gesture.state == .began||gesture.state == .changed{
            let translation = gesture.translation(in: self)
            let postionMoved = self.leftThumbPositionX + translation.x
            self.leftThumbPositionX = self.calucateLeftThumbPostion(postionMoved)
            gesture.setTranslation(.zero, in: self)
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }else if gesture.state == .ended{
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }
    }

    @objc func rightPanAction(_ gesture : UIPanGestureRecognizer){
         if gesture.state == .began||gesture.state == .changed {
            let translation = gesture.translation(in: self)
            let postionMoved = self.rightThumbPositionX + translation.x
            self.rightThumbPositionX = self.calucateRightThumbPostion(postionMoved)
            gesture.setTranslation(.zero, in: self)
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }else if gesture.state == .ended{
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }
    }


}



extension KYVideoRangeSlider :  UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.videoKeyframes.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "rangecell", for: indexPath) as! KYVideoRangeCollectionCell
        cell.keyframe = self.videoKeyframes[indexPath.row]
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.keyframeWidth, height: self.frame.height-2)
    }


    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //_asset is nil or videoPlayer not readyForDisplay
        guard  let _ = videoAsset else {
            return
        }

        let videoTrackLength = self.keyframeWidth * CGFloat(self.videoKeyframes.count)
        //current position
        var position = scrollView.contentOffset.x
        position = max(position, 0)
        position = min(position,videoTrackLength)
        let percent = position / CGFloat(videoTrackLength)

        var currentSecond = self.duration * Double(percent)
        currentSecond = max(currentSecond, 0)
        currentSecond = min(currentSecond, self.duration)
        self.rangeStartTime = currentSecond

        let selecteTime = Double(self.selecteTimeLength/CGFloat(videoTrackLength))*self.duration

        self.rangeEndTime = self.rangeStartTime+selecteTime

        self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
    }
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.delegate?.videoRangeSliderBeginDragging?(self)
    }
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {

    }


}



internal class KYVideoRangeCollectionCell : UICollectionViewCell{

    internal var imageView: UIImageView!
    internal var keyframe: KYVideoKeyframe?{
        didSet{
            self.imageView.image = keyframe?.image
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.imageView = UIImageView(frame: .zero)
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.imageView)

        var constraints : [NSLayoutConstraint] = []

        let views = ["imageView":self.imageView] as [String:Any]

        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[imageView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        self.contentView.addConstraints(constraints)

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}