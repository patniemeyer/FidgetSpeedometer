
import UIKit
import AVFoundation
import ImageIO
import MSSimpleGauge
import iCarousel

class ViewController: UIViewController
{
    @IBOutlet weak var imageView : UIImageView!
    @IBOutlet weak var imageViewOverlay: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var gaugeContainer: UIView!
    @IBOutlet weak var gridViewOverlay: UIImageView!
    
    var gauge: MSRangeGauge!
    
    var displayMode: DisplayMode = .threeLobe
    
    // One of these overlays will be used
    var overlayCells : [[UIView]]!
    var overlayCircle : UIView!
    
    var handleTime : UInt64 = 0
    var session : AVCaptureSession = AVCaptureSession()
    
    let reportAvgFilterTime = false
    let reportAvgHandleTime = false
    
    // Size of grid cell
    // MUST BE evenly divisible into 1280 screen width? (check cpu usage)
    //static let gridScale = 64 // 80 = 16x9, 64 = 20x11.25
    //static let periodsQuorum = 12 // 10 for 80 was good...
    static let gridScale = 80 // 80 = 16x9, 64 = 20x11.25
    static let periodsQuorum = 10 // 10 for 80 was good...
    
    static var format : Int = 720 // 1280x720
    static var fps : Int = 240 // frames per second
    static let samplePeriod = 0.5 // seconds
    static let samplesPerPeriod = Int(samplePeriod * Double(fps))
    
    // Given a min samples req calc the max frequency (inclusive)
    static let minSamplesForValidFrequency = 4
    static let maxFrequency = Float(ViewController.fps / minSamplesForValidFrequency)
    
    var absoluteFrame = 0 // current frame counter
    // The relative frame number within the period (0..<samplesPerPeriod)
    var sampleFrame : Int {
        return absoluteFrame % ViewController.samplesPerPeriod
    }
    var samples: [[Sample]]! // careful if making this optional, don't copy
    
    var centerPoint: CGPoint?
    var boundingBox: CGRect?
    
    
    var frequency: Float = 0 { // Found frequency
        didSet {
            gauge.value = frequency
        }
    }
    
    static func frequency(forPeriod period: Float) -> Float {
        guard period > 0 else { return 0 } // return 0 for no period found
        return Float(ViewController.fps)/period
    }
    static func period(forFrequency hz: Float) -> Float {
        guard hz > 0 else { return 0 } // return 0 for no period found
        return Float(ViewController.fps)/Float(hz)
    }
    
    struct Sample
    {
        var x: Int = 0, y: Int = 0
        var values = Array<Int>(repeating: 0, count: ViewController.samplesPerPeriod)
        
        //  The period in frames found by autocorrelationk.  Period of 0 is not found / undefined.
        private var period: Int = 0, lastPeriod: Int = 0
        var min = 0, max = 0
        
        var periodStable: Float {
            if period == 0 || lastPeriod == 0 || period < ViewController.minSamplesForValidFrequency || lastPeriod < ViewController.minSamplesForValidFrequency { return 0 }
            return Float(period + lastPeriod)/2.0
        }
        
        // Frequency identified in Hz. 
        // 240fps at 10 full rps would give 240/30 lobes per sec = 8 frames.
        // 240fps is 4ms window
        var frequency: Float { return ViewController.frequency(forPeriod: periodStable) }
        
        // Add a new sample, evaluating the frequency on new period start
        mutating func add(value: Int, atFrame frame: Int)
        {
            if frame == 0 {
                //for v in values { print(v) }
                findPeriod()
                min = value; max = value
            }
            values[frame] = value
            if value < min { min = value }
            if value > max { max = value }
        }
        
        mutating func findPeriod()
        {
            //print("max-min=", max-min)
            // Do we have a reasonable signal to test?
            let threshold = 255/10
            if max - min < threshold {
                period = 0; lastPeriod = 0; return
            }
            
            // Partial normalization. Just subtract the min floor.
            // I don't think this is strictly necessary, but original was assuming 0-255 and
            // subtracted 128. The algo below uses a threshold of half peak value for peak
            // detection. So if we were way offset that would matter.
            for i in 0..<samplesPerPeriod { values[i] = values[i]-min }
            
            // Autocorrelation
            var foundPeriod = 0;
            var thresh = 0.0;
            var peakState = 0;
            var sum : Int = 0
            for i in 0..<samplesPerPeriod
            {
                let sum_old = sum;
                sum = 0;
                for k in 0..<(samplesPerPeriod-i) {
                    //sum += (values[k]-128)*(values[k+i]-128)/256; // org
                    sum += (values[k])*(values[k+i])/256;
                }
                //print(values[i],sum)
                
                // Peak Detect State Machine
                // after 3/4 cycle find first drop as peak
                if (peakState == 2 && (sum-sum_old) <= 0) {
                    foundPeriod = i-1;
                    break;
                }
                // After first sample, if sum is increasing and exceeds threshold then state 2
                if (peakState == 1 && (Double(sum) > thresh) && (sum-sum_old) > 0) {
                    peakState = 2;
                }
                // Set threshold on first sample, state 1
                if (i==0) {
                    thresh = Double(sum) * 0.5;
                    peakState = 1;
                }
            }
            
            if foundPeriod == 0 {
                period = 0; lastPeriod = 0
            } else {
                lastPeriod = period; period = foundPeriod
            }
            //print("freq = ",frequency)
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.imageView.backgroundColor = .gray
        self.imageView.layer.magnificationFilter = kCAFilterNearest
        
        if self.setupCamera() {
            self.session.startRunning()
        } else {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Alert", message: "No suitable camera found.", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        //label.layer.cornerRadius = label.bounds.size.height / 2.0
        //label.layer.borderColor = UIColor.white.cgColor
        //label.layer.borderWidth = 2.5
        //label.clipsToBounds = true
        //label.backgroundColor = UIColor(white: 0.5, alpha: 0.5)
        label.textColor = UIColor.black
        
        initGauge()
        initCarousel()
    }
    
    var sumFilterTimes:Float = 0
    var sumHandleTimes:Float = 0
    func handleImage(sampleBuffer: CMSampleBuffer)
    {
        let handleImageStart = now()
        // pixel buffer <-> CIImage
        /*
        let pb: CVPixelBuffer?
        let ciImage = CIImage(cvPixelBuffer: pb!)
        let pb2 = ciImage.pixelBuffer
        ciImage.cgImage?
        CGImageDestinationCreateWithData()
        */
        
        var time = now(); let interval = time-handleTime; handleTime = time
        if interval > UInt64(1000/ViewController.fps * 2) { print("2x slow frame: ", absoluteFrame) }
        //if absoluteFrame % 10 == 0 { print("handle time = \(interval)") }
        
        // Filter the image
        time = now()
        let filteredImage = OpenCVSampleFilter.processSampleBuffer(sampleBuffer, scale: Int32(ViewController.gridScale))
        if sampleFrame == 0 {
            if reportAvgFilterTime {
                print("avg time to filter = ", sumFilterTimes/Float(ViewController.samplesPerPeriod))
            }
            sumFilterTimes = 0
        } else {
            sumFilterTimes += Float(now()-time)
        }
        
        /*
        let cvImage: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let ciImage: CIImage = CIImage(cvPixelBuffer: cvImage)
        let filteredImage = processWithCoreImage(image: ciImage, scale: ViewController.gridScale)
        print("time to process = ", (now()-filterTime))
        */
        
        guard let img = filteredImage else { return }
        
        time = now()
        captureSamples(image: img)
        //print("time to capture samples = ", (now()-time))
        
        // If new period evaluate the found frequencies
        if sampleFrame == 0 && absoluteFrame > 0 {
            evaluateSamples(image: img)
            if Settings.shared.colorFrequency {
                drawOverlayGrid(image: img)
                if overlayCircle != nil { overlayCircle.isHidden = true }
            } else {
                drawOverlayShape(image: img)
                if gridViewOverlay != nil { gridViewOverlay.isHidden = true }
            }
        }
        
        showImageAtFrequency(sampleBuffer: sampleBuffer)
        absoluteFrame += 1
        
        if sampleFrame == 0 {
            if reportAvgHandleTime {
                print("avg handle time = ", sumHandleTimes/Float(ViewController.samplesPerPeriod))
            }
            sumHandleTimes = 0
        } else {
            sumHandleTimes += Float(now()-handleImageStart)
        }
    }
    
    func showImageAtFrequency(sampleBuffer: CMSampleBuffer)
    {
        // if we have a freq show a frame from the sample period for it, else default rate
        let targetFrequency = (Settings.shared.syncFrames && frequency > 0) ? frequency : 30 /*fps*/
        let framesPerPeriod = Int(rint(ViewController.period(forFrequency: targetFrequency)))
        if sampleFrame % framesPerPeriod == 0 {
            imageView.image = imageFromSampleBuffer(sampleBuffer)
        }
    }
    
    func initOverlayGridIfNeeded(image img: UIImage) {
        if overlayCells == nil {
            let samplesX = Int(img.size.width)
            let samplesY = Int(img.size.height)
            initOverlayGridView(width: samplesX, height: samplesY)
        }
    }
    func initOverlayGridView(width: Int, height: Int)
    {
        let size = Int(view.bounds.width) / width + 1
        overlayCells = Array(repeating: Array(repeating: UIView(), count: width), count: height)
        for y in 0..<height{
            for x in 0..<width{
                let cell = UIView()
                cell.backgroundColor = .clear
                cell.frame = CGRect(x:x*size, y:y*size, width: size, height: size)
                overlayCells[y][x] = cell
                gridViewOverlay.addSubview(cell)
            }
        }
    }
    
    func initOverlayCircleIfNeeded() {
        if overlayCircle == nil {
            overlayCircle = UIView()
            overlayCircle.backgroundColor = .clear
            overlayCircle.layer.borderColor = UIColor.white.cgColor
            overlayCircle.layer.borderWidth = 10.0
            imageViewOverlay.addSubview(overlayCircle)
        }
    }
    
    // draw overlay circle based on the last evaluation
    func drawOverlayShape(image img: UIImage)
    {
        initOverlayCircleIfNeeded()
        guard let centerPoint = centerPoint, let boundingBox = boundingBox else {
            overlayCircle.isHidden = true
            return
        }
        
        let samplesX = Int(img.size.width)-1
        let samplesY = Int(img.size.height)-1
        let scale = (CGFloat(imageViewOverlay.bounds.width / CGFloat(samplesX))
            + CGFloat(imageViewOverlay.bounds.height / CGFloat(samplesY))) / 2.0
        
        //overlayCircle.bounds = boundingBox * scale
        //overlayCircle.center = centerPoint * scale
        
        let width = boundingBox.width*scale
        let height = boundingBox.height*scale
        
        if displayMode == .frequency
        {
            let center = centerPoint * scale
            overlayCircle.frame = CGRect(x: center.x-width/2.0, y: center.y-height/2.0, width: width, height: height)
            overlayCircle.layer.cornerRadius = 5
        } else {
            let size = min(width,height)
            let center = centerPoint * scale
            overlayCircle.frame = CGRect(x: center.x-size/2.0, y: center.y-size/2.0, width: size, height: size)
            overlayCircle.layer.cornerRadius = overlayCircle.bounds.height / 2.0
        }
        
        overlayCircle.isHidden = false
    }
    
    func drawOverlayGrid(image img: UIImage) // todo: get rid of image here
    {
        initOverlayGridIfNeeded(image: img)
        
        let samplesX = Int(img.size.width) // todo: move this to instance with overlay
        let samplesY = Int(img.size.height)
        for y in 0..<samplesY {
            for x in 0..<samplesX {
                /*
                if let boundingBox = boundingBox {
                    if boundingBox.contains(CGPoint(x: x, y: y)) {
                        overlayCells[y][x].backgroundColor = .clear
                    } else {
                        overlayCells[y][x].backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                    }
                    continue
                }*/
                
                // clear the whole screen when nothing
                if frequency == 0 {
                    overlayCells[y][x].backgroundColor = .clear
                    continue
                }
                
                let sample = samples[y][x];
                //print("x:\(x), y:\(y), freq = \(sample.frequency)")
                let minFreq: Float = 10.0
                let maxFreq: Float = 30.0
                if sample.frequency < 5.0 {
                    overlayCells[y][x].backgroundColor = .clear
                } else {
                    let freq = min(max(sample.frequency, minFreq), maxFreq) - minFreq // clip
                    let frac = CGFloat(freq) / CGFloat(maxFreq)
                    let color = UIColor(hue: frac, saturation: 0.7, brightness: 0.7, alpha: 0.7)
                    overlayCells[y][x].backgroundColor = color
                }
            }
        }
        
//        if let centerPoint = centerPoint {
//            self.overlayCells[Int(rint(centerPoint.y))][Int(rint(centerPoint.x))].backgroundColor = .white
//        }
        gridViewOverlay.isHidden = false
    }
    
    func evaluateSamples(image img: UIImage)
    {
        let samplesX = Int(img.size.width)
        let samplesY = Int(img.size.height)
        
        // Gather all of the found periods
        var periods = [Sample]()
        for y in 0..<samplesY {
            for x in 0..<samplesX {
                let sample = samples[y][x]
                if sample.periodStable == 0 { continue }
                periods.append(sample)
            }
        }
        
        let noFreqFound = {
            self.frequency = 0
            self.centerPoint = nil
            self.boundingBox = nil
            self.setDisplayFrequency()
        }
        // If we have a quorum (raw and within range of median)
        //print("found periods: ", periods.count)
        if periods.count >= ViewController.periodsQuorum
        {
            periods.sort { $0.periodStable < $1.periodStable }
            //print("periods found = \(periods)")
            let medianPeriod = periods[periods.count/2].periodStable
            //print("median period: ", medianPeriod)
            
            // Set period range (plus/minus allowed for selecting periods) based on min samples 
            // and expand for longer periods proportionally
            // let periodRange = 1 // Allow +/1 this range on found periods
            // Base period range on +/1 one sample at minimum sample period
            // e.g. for min samples of 4 we allow 3-5, for 8 we allow 6-10
            //   for 120 we allow 90-150?  Seem too much? Let's try half that
            let periodRange = max(1,medianPeriod / Float(ViewController.minSamplesForValidFrequency) / 2)
            //print("period range: \(periodRange)")
            
            // Average all of the found periods within periodRange
            let samplesInRange = periods.filter{ abs($0.periodStable-medianPeriod) <= periodRange }
            if samplesInRange.count >= ViewController.periodsQuorum
            {
                let averagePeriod = Float(samplesInRange.reduce(0, {$0+$1.periodStable})) / Float(samplesInRange.count)
                //print("periods in range: \(samplesInRange), average: \(averagePeriod)")
                frequency = ViewController.frequency(forPeriod: averagePeriod)
                setDisplayFrequency()
                findBoundingBoxAvg(samplesInRange: samplesInRange, samplesX: samplesX, samplesY: samplesY)
            } else {
                noFreqFound()
            }
        } else {
            noFreqFound()
        }
    }
    
    func setDisplayFrequency() {
        if frequency == 0 {
            self.label.text = ""
        } else {
            // todo: make an enum
            let display = Settings.shared.display
            let mul: Float = display == "RPM" ? 60.0 : 1
            switch(displayMode) {
                case .threeLobe:
                    label.text = String(format:"%.1f \(display)", frequency/3.0*mul)
                case .twoLobe:
                    label.text = String(format:"%.1f \(display)", frequency/2.0*mul)
                case .frequency, .about:
                    label.text = String(format:"%.1f HZ", frequency)
            }
        }
    }
    
    func findBoundingBoxAvg(samplesInRange: [Sample], samplesX: Int, samplesY: Int) {
        // Find center by averaging and bounding box inclusive
        centerPoint = samplesInRange.map { CGPoint(x:$0.x, y:$0.y) }.reduce(CGPoint(x:0, y:0), {$0+CGPoint(x:$1.x, y:$1.y)} ) / Float(samplesInRange.count)
        guard let center = centerPoint else {
            boundingBox = nil
            return
        }
        let left = samplesInRange.filter{ CGFloat($0.x) <= center.x }.map { $0.x }
        let bottom = samplesInRange.filter{ CGFloat($0.y) <= center.y }.map { $0.y }
        let right = samplesInRange.filter{ CGFloat($0.x) >= center.x }.map { $0.x }
        let top = samplesInRange.filter{ CGFloat($0.y) >= center.y }.map { $0.y }
        
        let factor: CGFloat = 2.0 * 0.8 // avg extension above center
        let minX = CGFloat(left.reduce(0,+)) / CGFloat(left.count) * factor
        let maxX = CGFloat(right.reduce(0,+)) / CGFloat(right.count) * factor
        let minY = CGFloat(bottom.reduce(0,+)) / CGFloat(bottom.count) * factor
        let maxY = CGFloat(top.reduce(0,+)) / CGFloat(top.count) * factor
        
        boundingBox = CGRect(x: minX, y: minY, width: maxX-minX, height: maxY-minY)
        //print("center = \(centerPoint)")
    }
    
    func findBoundingBox(samplesInRange: [Sample], samplesX: Int, samplesY: Int) {
        // Find center by averaging and bounding box inclusive
        centerPoint = samplesInRange.map { CGPoint(x:$0.x, y:$0.y) }.reduce(CGPoint(x:0, y:0), {$0+CGPoint(x:$1.x, y:$1.y)} ) / Float(samplesInRange.count)
        let minX = samplesInRange.map { $0.x }.min() ?? 0
        let minY = samplesInRange.map { $0.y }.min() ?? 0
        let maxX = samplesInRange.map { $0.x }.max() ?? samplesX
        let maxY = samplesInRange.map { $0.y }.max() ?? samplesY
        boundingBox = CGRect(x: minX, y: minY, width: maxX-minX, height: maxY-minY)
        //print("center = \(centerPoint)")
    }
    
    func captureSamples(image img: UIImage)
    {
        let samplesX = Int(img.size.width)
        let samplesY = Int(img.size.height)
        
        // Capture samples
        if samples == nil {
            samples = Array(repeating: Array(repeating: Sample(), count: samplesX), count: samplesY)
        }
        // x,y from origin at top left of screen
        for y in 0..<samplesY {
            for x in 0..<samplesX {
                //if x > 0 || y > 0 { continue }
                let value = img.getPixelValueGrayscale(x:x, y:y)
                //print("\(absoluteFrame),\(value)")
                var sample = samples[y][x];
                sample.x = x; sample.y = y
                sample.add(value: Int(value), atFrame: sampleFrame)
                samples[y][x] = sample;
           }
        }
    }
    
    let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
    func processWithCoreImage(image: CIImage, scale: Int) -> UIImage?
    {
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputBrightnessKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        filter.setValue(1.1, forKey: kCIInputContrastKey)
        
        var intermediateImage = filter.outputImage
        
        let filter1 = CIFilter(name:"CIExposureAdjust")!
        filter1.setValue(intermediateImage, forKey: kCIInputImageKey)
        filter1.setValue(0.7, forKey: kCIInputEVKey)
        intermediateImage = filter1.outputImage
    
        let filter2 = CIFilter(name: "CILanczosScaleTransform")!
        filter2.setValue(intermediateImage, forKey: "inputImage")
        filter2.setValue(1.0/Double(scale), forKey: "inputScale")
        filter2.setValue(1.0, forKey: "inputAspectRatio")
        let outputImage = filter2.value(forKey: "outputImage") as! CIImage
        
//        let scaledImage = UIImage(CGImage: self.context.createCGImage(outputImage, fromRect: outputImage.extent)!)
        let scaledImage = UIImage(ciImage: outputImage)
        return scaledImage
    }

    func initGauge()
    {
        let maxFreq = ViewController.maxFrequency
        self.gauge = MSRangeGauge(frame: CGRect(x:0, y:0, width:self.gaugeContainer.bounds.width, height:self.gaugeContainer.bounds.height))
//        self.gauge = MSAnnotatedGauge(frame: CGRect(x:170, y:250, width:250, height:250))
        self.gauge.minValue = 0;
        self.gauge.maxValue = maxFreq
        self.gauge.upperRangeValue = 0.80 * maxFreq;
        self.gauge.lowerRangeValue = 0.20 * maxFreq;
//        self.gauge.titleLabel.text = "\(frequency) Hz"
//        self.gauge.startRangeLabel.text = "0"
//        self.gauge.endRangeLabel.text = "\(maxFreq)"
        self.gauge.value = 0;
        self.gauge.backgroundArcFillColor = UIColor(red:0.41, green:0.76, blue:0.73, alpha:1)
        self.gauge.backgroundArcStrokeColor = UIColor(red:0.41, green:0.76, blue:0.73, alpha:1)
//        self.gauge.fillArcFillColor = UIColor(red:0.41, green:0.76, blue:0.73, alpha:1)
//        self.gauge.fillArcStrokeColor = UIColor(red:0.41, green:0.76, blue:0.73, alpha:1)
        self.gauge.rangeFillColor = UIColor(red:0.82, green:0.82, blue:0.82, alpha:1)
        self.gauge.backgroundColor = .clear
        self.gaugeContainer.addSubview(self.gauge)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

