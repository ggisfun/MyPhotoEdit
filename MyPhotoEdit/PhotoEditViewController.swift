//
//  PhotoEditViewController.swift
//  MyPhotoEdit
//
//  Created by Adam Chen on 2024/10/11.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

class PhotoEditViewController: UIViewController {

    @IBOutlet weak var baseView: UIView!
    @IBOutlet var modeButtons: [UIButton]!
    @IBOutlet var modeViews: [UIView]!
    @IBOutlet var filterButtons: [UIButton]!
    @IBOutlet var adjustSliders: [UISlider]!
    @IBOutlet var scaleButtons: [UIButton]!
    @IBOutlet weak var addPicButton: UIButton!
    
    enum Mode {
        case adjust
        case filter
        case crop
    }
    var currentMode: Mode = .adjust
    var originalImage: UIImage?
    var currentImage: UIImage?
    
    var startPoint: CGPoint?
    let cropOverlayView = CropOverlayView()// 用來顯示選擇的裁剪範圍
    
    let imageView: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFit
        imgView.isUserInteractionEnabled = true
        return imgView
    }()
    
    let context = CIContext()
    let filterArray = [
        "",
        "CIPhotoEffectChrome",
        "CIPhotoEffectFade",
        "CIPhotoEffectInstant",
        "CIPhotoEffectProcess",
        "CIPhotoEffectTransfer",
        "CIPhotoEffectTonal",
        "CIPhotoEffectMono",
        "CIPhotoEffectNoir"
    ]
    
    var rotationCount: Int = 0
    var xValue: CGFloat = 1
    var yValue: CGFloat = 1
    let oneDegree = CGFloat.pi / 180
    
    let messageTextView: UITextView = {
        let textView = UITextView()
        textView.text = "輸入文字"
        textView.font = .systemFont(ofSize: 20)
        textView.textColor = .darkGray
        textView.backgroundColor = .clear
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.link.cgColor
        textView.sizeToFit()
        textView.isScrollEnabled = false
        textView.isUserInteractionEnabled = true
        return textView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        messageTextView.delegate = self
        for button in scaleButtons {
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 10
            button.layer.borderColor = UIColor.white.cgColor
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        messageTextView.addGestureRecognizer(pan)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchGesture))
        baseView.addGestureRecognizer(pinch)
    }
    
    @objc func dismissKeyboard() {
        messageTextView.layer.borderColor = UIColor.clear.cgColor
        view.endEditing(true)
    }
    
    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self.baseView)
        messageTextView.center = point
    }
    
    @objc func pinchGesture(_ gesture: UIPinchGestureRecognizer) {
        
        let initialCenter: CGPoint = imageView.center
        var scale = gesture.scale
        let newTransform = imageView.transform.scaledBy(x: scale, y: scale)
        let newWidth = imageView.frame.width * scale
        let newHeight = imageView.frame.height * scale
        let minScale:CGFloat = 0.5
        let maxScale:CGFloat = 2
        
        if gesture.state == .changed{
            if newWidth >= imageView.bounds.width * minScale  && newWidth <= imageView.bounds.width * maxScale && newHeight >= imageView.bounds.height * minScale && newHeight <= imageView.bounds.height * maxScale{
                imageView.transform = newTransform
            }
            
            imageView.center = initialCenter
            
            scale = 1
            
        }
        
    }

    @IBAction func selectPhoto(_ sender: Any) {
        let controller = UIImagePickerController()
        controller.sourceType = .photoLibrary
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    @IBAction func selectMode(_ sender: UIButton) {
        guard currentImage != nil else { return }
        switch sender.tag {
        case 0:
            currentMode = .adjust
            print("Adjust mode activated")
        case 1:
            currentMode = .filter
            updateFilterButton()
            print("Filter mode activated")
        case 2:
            currentMode = .crop
            print("Crop mode activated")
        default:
            break
        }
        
        for view in self.modeViews {
            view.isHidden = (view.tag != sender.tag)
        }
        
    }
    
    @IBAction func changeViewScale(_ sender: UIButton) {
        guard let image = currentImage else { return }
        
        var cropRect = CGRect.zero
        
        switch sender.tag {
        case 0:
            // 原圖裁剪，保持不變
            cropRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        case 1:
            // 正方形裁剪
            let sideLength = min(image.size.width, image.size.height)
            cropRect = CGRect(x: (image.size.width - sideLength) / 2, y: (image.size.height - sideLength) / 2, width: sideLength, height: sideLength)
        case 2:
            // 9:16 比例裁剪
            let height = image.size.height
            let width = min(height * (9.0 / 16.0), image.size.width)  // 確保不超出範圍
            cropRect = CGRect(x: (image.size.width - width) / 2, y: 0, width: width, height: height)
        case 3:
            // 4:5 比例裁剪
            let height = image.size.height
            let width = min(height * (4.0 / 5.0), image.size.width)  // 確保不超出範圍
            cropRect = CGRect(x: (image.size.width - width) / 2, y: 0, width: width, height: height)
        case 4:
            // 3:4 比例裁剪
            let height = image.size.height
            let width = min(height * (3.0 / 4.0), image.size.width)  // 確保不超出範圍
            cropRect = CGRect(x: (image.size.width - width) / 2, y: 0, width: width, height: height)
        default:
            return
        }
        
        // 裁剪圖片
        if let croppedImage = cropImage(to: cropRect, image: image) {
            imageView.image = croppedImage
        }
    }
    
    // 裁剪圖片的輔助函數
    func cropImage(to rect: CGRect, image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        if let croppedCgImage = cgImage.cropping(to: rect) {
            return UIImage(cgImage: croppedCgImage)
        }
        return nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard currentMode == .crop else { return }
        guard let touch = touches.first else { return }
        let point = touch.location(in: imageView)
        
        // 確保觸控點在 imageView 內
        if imageView.bounds.contains(point) {
            startPoint = point
            cropOverlayView.frame = CGRect(x: point.x, y: point.y, width: 0, height: 0)
            cropOverlayView.layer.borderWidth = 1
            cropOverlayView.layer.borderColor = UIColor.white.cgColor
            cropOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)  // 背景設為透明，僅顯示網格
            imageView.addSubview(cropOverlayView)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let startPoint = startPoint, let touch = touches.first else { return }
        let currentPoint = touch.location(in: imageView)
        
        let width = currentPoint.x - startPoint.x
        let height = currentPoint.y - startPoint.y
        
        // 更新裁剪區域和網格顯示
        cropOverlayView.frame = CGRect(x: startPoint.x, y: startPoint.y, width: width, height: height)
        cropOverlayView.setNeedsDisplay()  // 重新繪製網格
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let startPoint = startPoint, let touch = touches.first else { return }
        let endPoint = touch.location(in: imageView)
        
        // 確定最終的裁剪矩形
        let cropRect = CGRect(x: min(startPoint.x, endPoint.x),
                              y: min(startPoint.y, endPoint.y),
                              width: abs(endPoint.x - startPoint.x),
                              height: abs(endPoint.y - startPoint.y))
        
        // 更新圖片
        if let croppedImage = cropImage(to: cropRect, imageView: imageView) {
            imageView.image = croppedImage
        }
        
        // 清理和重置狀態
        cropOverlayView.removeFromSuperview()
        self.startPoint = nil
    }

    // 裁剪圖片的輔助函數
    func cropImage(to rect: CGRect, imageView: UIImageView) -> UIImage? {
        guard let image = imageView.image else { return nil }
        
        // 計算 imageView 的實際顯示範圍
        let imageSize = image.size
        let imageViewSize = imageView.bounds.size
        let scaleX = imageSize.width / imageViewSize.width
        let scaleY = imageSize.height / imageViewSize.height
        
        // 將 cropRect 從 imageView 的坐標轉換為圖片的實際像素坐標
        let scaledCropRect = CGRect(x: rect.origin.x * scaleX,
                                    y: rect.origin.y * scaleY,
                                    width: rect.width * scaleX,
                                    height: rect.height * scaleY)
        
        // 裁剪圖片
        if let cgImage = image.cgImage?.cropping(to: scaledCropRect) {
            return UIImage(cgImage: cgImage)
        }
        
        return nil
    }
    
    func updateFilterButton(){
        currentImage = imageView.image
        for button in filterButtons {
            button.configuration?.title = ""
            button.configuration?.background.imageContentMode = .scaleAspectFill
            
            let ciImage = CIImage(image: currentImage!)
            
            if button.tag == 0{
                button.configuration?.background.image = currentImage
            }else if button.tag >= 1{
                if let filter = CIFilter(name: filterArray[button.tag]){
                    filter.setValue(ciImage, forKey: kCIInputImageKey)
                    if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent){
                        let filterImage = UIImage(cgImage: cgImage)
                        button.configuration?.background.image = filterImage
                    }
                }
            }
            
        }
    }
    
    @IBAction func filterAdopt(_ sender: UIButton) {
        let ciImage = CIImage(image: currentImage!)
        if sender.tag == 0{
            imageView.image = currentImage
            //選擇第2~8個按鈕，根據tag編號套用對應濾鏡
        }else if sender.tag >= 1{
            //判斷使用的濾鏡是哪一個
            if let filter = CIFilter(name: filterArray[sender.tag]){
                //指定ciImage為輸入filter的對象
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                //輸出套用濾鏡後的圖片，格式為CIImage，再產生正確大小的CGImage
                if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent){
                    //把圖片轉回UIImage，放入imageView中
                    let filterImage = UIImage(cgImage: cgImage)
                    imageView.image = filterImage
                }
            }
        }
    }
    
    @IBAction func adjustSlider(_ sender: UISlider) {
        guard let image = currentImage else { return }
        let ciImage = CIImage(image: image)
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(adjustSliders[0].value, forKey: kCIInputBrightnessKey)
        filter?.setValue(adjustSliders[1].value / 100, forKey: kCIInputContrastKey)
        filter?.setValue(adjustSliders[2].value, forKey: kCIInputSaturationKey)
        
        if let outputImage = filter?.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent){
            //把圖片轉回UIImage，放入imageView中
            let updateImage = UIImage(cgImage: cgImage)
            imageView.image = updateImage
        }
    }
    
    @IBAction func save(_ sender: Any) {
        guard let saveImage = imageView.image else { return }
        
        let saveView = UIView(frame: CGRect(x: 0, y: 0, width: saveImage.size.width, height: saveImage.size.height))
        let saveImageView = UIImageView(frame: saveView.bounds)
        saveImageView.image = imageView.image
        saveView.addSubview(saveImageView)
        
        if self.rotationCount == 1 || self.rotationCount == 3 {
            if (self.xValue * self.yValue) == -1 {
                saveImageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * 90 * CGFloat(self.rotationCount))
            }else {
                saveImageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * -90 * CGFloat(self.rotationCount))
            }
        }else {
            if (self.xValue * self.yValue) == -1 {
                saveImageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * -90 * CGFloat(self.rotationCount))
            }else {
                saveImageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * 90 * CGFloat(self.rotationCount))
            }
        }
        
        let renderer = UIGraphicsImageRenderer(size: saveView.bounds.size)
        let image = renderer.image { context in
            saveView.drawHierarchy(in: saveView.bounds, afterScreenUpdates: true)
        }
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        present(activityViewController, animated: true)
    }
    
    @IBAction func rotation(_ sender: Any) {
        guard imageView.image != nil else { return }
        rotationCount += 1
        if rotationCount > 3 {
            rotationCount = 0
        }
        setTransform()
    }
    
    @IBAction func mirrorFlip(_ sender: Any) {
        guard imageView.image != nil else { return }
        if rotationCount == 1 || rotationCount == 3 {
            yValue *= -1
        }else {
            xValue *= -1
        }
        setTransform()
    }
    
    func setTransform() {
        UIView.animate(withDuration: 0.3) {
            if self.rotationCount == 1 || self.rotationCount == 3 {
                if (self.xValue * self.yValue) == -1 {
                    self.imageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * 90 * CGFloat(self.rotationCount))
                }else {
                    self.imageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * -90 * CGFloat(self.rotationCount))
                }
            }else {
                if (self.xValue * self.yValue) == -1 {
                    self.imageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * -90 * CGFloat(self.rotationCount))
                }else {
                    self.imageView.transform = CGAffineTransform(scaleX: self.xValue, y: self.yValue).rotated(by: self.oneDegree * 90 * CGFloat(self.rotationCount))
                }
            }
        }
    }
    
    @IBAction func reset(_ sender: Any) {
        if imageView.subviews.contains(messageTextView) == true {
            messageTextView.removeFromSuperview()
        }
        messageTextView.text = "輸入文字"
        messageTextView.textColor = .darkGray
        imageView.image = originalImage
        currentImage = originalImage
        rotationCount = 0
        xValue = 1
        yValue = 1
        setTransform()
    }
    
    @IBAction func addFont(_ sender: Any) {
        guard imageView.image != nil else { return }
        messageTextView.center = imageView.center
        imageView.addSubview(messageTextView)
    }
    
    @IBAction func selectTextColor(_ sender: Any) {
        let controller = UIColorPickerViewController()
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    
}

extension PhotoEditViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else { return }
        
        imageView.image = image
        imageView.frame = baseView.bounds
        baseView.backgroundColor = .clear
        baseView.insertSubview(imageView, at: 0)
        //baseView.addSubview(imageView)
        
        originalImage = image
        currentImage = image
        addPicButton.isHidden = true
        
        dismiss(animated: true)
        
    }
}

extension PhotoEditViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "輸入文字" {
            textView.text = ""
            textView.textColor = .black
        }
        textView.layer.borderColor = UIColor.link.cgColor
    }
    
    func textViewDidChange(_ textView: UITextView) {
        //依照文字的內容自動調整textview的高度
        autoAdjustTextHeight()
    }
    
    func autoAdjustTextHeight(){
        let fixedWidth = messageTextView.frame.width
        let newSize = messageTextView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        messageTextView.frame.size = CGSize(width: max(fixedWidth,newSize.width), height: newSize.height)
    }
}

extension PhotoEditViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        messageTextView.textColor = viewController.selectedColor
    }
}

