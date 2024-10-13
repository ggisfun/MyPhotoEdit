//
//  CropOverlayView.swift
//  MyPhotoEdit
//
//  Created by Adam Chen on 2024/10/11.
//
import UIKit

class CropOverlayView: UIView {
    
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        let numberOfLines = 2 // 每個方向的網格線數量
        
        // 繪製垂直線
        for i in 1...numberOfLines {
            let x = rect.width / CGFloat(numberOfLines + 1) * CGFloat(i)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // 繪製水平線
        for i in 1...numberOfLines {
            let y = rect.height / CGFloat(numberOfLines + 1) * CGFloat(i)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        UIColor.white.setStroke() // 網格線的顏色
        path.lineWidth = 1
        path.stroke()
    }
}

