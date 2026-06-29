import UIKit
import CoreFoundation

private func darwinNotificationCallback(center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) {
    guard let observer = observer else { return }
    let mySelf = Unmanaged<OverlayViewController>.fromOpaque(observer).takeUnretainedValue()
    DispatchQueue.main.async {
        mySelf.handleRotation()
    }
}

protocol DraggableViewDelegate: AnyObject {
    func didTap(view: DraggableView)
    func didDrag(view: DraggableView, to center: CGPoint)
    func didEndDrag(view: DraggableView)
}

class DraggableView: UIView {
    weak var delegate: DraggableViewDelegate?
    private var startLocation: CGPoint = .zero
    private var startCenter: CGPoint = .zero
    private var isDragging = false
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        startLocation = touch.location(in: self.superview)
        startCenter = self.center
        isDragging = false
        
        UIView.animate(withDuration: 0.15) {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self.superview)
        
        let dx = location.x - startLocation.x
        let dy = location.y - startLocation.y
        let distance = hypot(dx, dy)
        
        if distance > 5 {
            isDragging = true
            let newCenter = CGPoint(x: startCenter.x + dx, y: startCenter.y + dy)
            self.center = newCenter
            delegate?.didDrag(view: self, to: newCenter)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
        if !isDragging {
            delegate?.didTap(view: self)
        } else {
            delegate?.didEndDrag(view: self)
        }
        isDragging = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}

class HackSwitch: UISwitch {
    var hackTitle: String = ""
}

class OverlayViewController: UIViewController, DraggableViewDelegate {

    // MARK: - State Variables
    private var crosshairEnabled: Bool = true
    private var crosshairStyle: Int = 1 // 0: Dot, 1: Cross, 2: Circle, 3: T-Shape, 4: Combine
    private var crosshairColorIndex: Int = 0 // 0: Green, 1: Red, 2: Cyan, 3: Yellow, 4: White
    private var crosshairSize: CGFloat = 12
    private var crosshairGap: CGFloat = 5
    private var crosshairThickness: CGFloat = 1.5
    private var crosshairDotSize: CGFloat = 2.0

    // MARK: - UI Views
    private lazy var menuButton: DraggableView = {
        let v = DraggableView()
        v.backgroundColor = UIColor(red: 26/255, green: 23/255, blue: 48/255, alpha: 0.9)
        v.layer.cornerRadius = 25
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 0.8).cgColor
        v.layer.shadowColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 0.8).cgColor
        v.layer.shadowOpacity = 0.8
        v.layer.shadowRadius = 8
        v.isUserInteractionEnabled = true
        return v
    }()

    private lazy var menuLabel: UILabel = {
        let l = UILabel()
        l.text = "MENU ⚙️"
        l.textColor = .white
        l.font = UIFont.systemFont(ofSize: 10, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    // Crosshair Container
    private lazy var espView: UIView = {
        let v = UIView(frame: UIScreen.main.bounds)
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }()
    
    private let espLayer = CAShapeLayer()

    private lazy var debugLabel: UILabel = {
        let l = UILabel(frame: CGRect(x: 10, y: 50, width: 300, height: 60))
        l.textColor = .green
        l.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        l.numberOfLines = 0
        l.font = UIFont.systemFont(ofSize: 12)
        l.text = "HoangHa Crosshair: Sẵn sàng"
        l.isHidden = true
        return l
    }()
    
    // Mod Menu Panel
    private lazy var menuPanel: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 15/255, green: 15/255, blue: 27/255, alpha: 0.95)
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 0.9).cgColor
        v.layer.shadowColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 0.6).cgColor
        v.layer.shadowOpacity = 0.8
        v.layer.shadowRadius = 12
        v.layer.shadowOffset = .zero
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()
    
    private lazy var titleBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 10/255, green: 10/255, blue: 18/255, alpha: 1.0)
        v.layer.cornerRadius = 16
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "🔥 HOANGHA CROSSHAIR 🔥"
        l.textColor = UIColor(red: 255/255, green: 70/255, blue: 85/255, alpha: 1.0)
        l.font = UIFont.systemFont(ofSize: 13, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private lazy var closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✕", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(closeMenu), for: .touchUpInside)
        return b
    }()
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var contentStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 10
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var footerLabel: UILabel = {
        let l = UILabel()
        l.text = "🎯 Virtual Crosshair | Pure Overlay | Secure Window"
        l.textColor = .green
        l.font = UIFont.systemFont(ofSize: 9, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    func updateDebugText(_ text: String) {
        DispatchQueue.main.async {
            self.debugLabel.text = text
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        loadSettings()
        
        // Setup Crosshair View & Layer
        view.addSubview(espView)
        espView.layer.addSublayer(espLayer)
        
        // Setup Menu Button
        menuButton.delegate = self
        view.addSubview(menuButton)
        menuButton.addSubview(menuLabel)
        
        // Setup Debug Label
        view.addSubview(debugLabel)
        
        // Setup Menu Panel
        setupMenuPanel()
        
        // Align constraints for menu label
        NSLayoutConstraint.activate([
            menuLabel.centerXAnchor.constraint(equalTo: menuButton.centerXAnchor),
            menuLabel.centerYAnchor.constraint(equalTo: menuButton.centerYAnchor)
        ])
        
        // Load button position
        let initialPos = OverlayWindowManager.shared.loadPosition()
        menuButton.frame = CGRect(origin: initialPos, size: CGSize(width: 70, height: 50))
        
        // Rotation Notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(handleRotation), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, darwinNotificationCallback, "com.apple.springboard.rawOrientation" as CFString, nil, .deliverImmediately)
        
        handleRotation()
        updateCrosshairDrawing()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, CFNotificationName("com.apple.springboard.rawOrientation" as CFString), nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCrosshairDrawing()
    }
    
    private func setupMenuPanel() {
        view.addSubview(menuPanel)
        menuPanel.addSubview(titleBar)
        titleBar.addSubview(titleLabel)
        titleBar.addSubview(closeButton)
        menuPanel.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        menuPanel.addSubview(footerLabel)
        
        NSLayoutConstraint.activate([
            // Center the menu panel
            menuPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuPanel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            menuPanel.widthAnchor.constraint(equalToConstant: 300),
            menuPanel.heightAnchor.constraint(equalToConstant: 330),
            
            // Title Bar
            titleBar.topAnchor.constraint(equalTo: menuPanel.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: titleBar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),
            
            // Content Stack View
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Footer Label
            footerLabel.bottomAnchor.constraint(equalTo: menuPanel.bottomAnchor, constant: -8),
            footerLabel.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
            footerLabel.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
            footerLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func loadTabContent() {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 1. Switch Row (Enable/Disable)
        let enableRow = createSwitchRow(title: "Bật tâm ảo")
        contentStackView.addArrangedSubview(enableRow)
        
        // 2. Segmented Row for Style (Dot, Cross, Circle, T-Shape, All)
        let styleRow = createSegmentedRow(title: "Kiểu dáng", items: ["Dot", "Cross", "Circle", "T-Shape", "All"], selectedIndex: crosshairStyle, tag: 10)
        contentStackView.addArrangedSubview(styleRow)
        
        // 3. Segmented Row for Color (Green, Red, Cyan, Yellow, White)
        let colorRow = createSegmentedRow(title: "Màu sắc", items: ["Xanh", "Đỏ", "Lam", "Vàng", "Trắng"], selectedIndex: crosshairColorIndex, tag: 11)
        contentStackView.addArrangedSubview(colorRow)
        
        // 4. Slider Row for Size
        let sizeRow = createSliderRow(title: "Kích thước (Size)", minVal: 5, maxVal: 30, currentVal: Float(crosshairSize), tag: 1)
        contentStackView.addArrangedSubview(sizeRow)
        
        // 5. Slider Row for Gap
        let gapRow = createSliderRow(title: "Khoảng mở (Gap)", minVal: 0, maxVal: 25, currentVal: Float(crosshairGap), tag: 2)
        contentStackView.addArrangedSubview(gapRow)
        
        // 6. Slider Row for Thickness
        let thicknessRow = createSliderRow(title: "Độ dày (Thickness)", minVal: 1, maxVal: 6, currentVal: Float(crosshairThickness), tag: 3)
        contentStackView.addArrangedSubview(thicknessRow)
        
        // 7. Slider Row for Dot Size
        let dotSizeRow = createSliderRow(title: "Cỡ chấm (Dot Size)", minVal: 1, maxVal: 10, currentVal: Float(crosshairDotSize), tag: 4)
        contentStackView.addArrangedSubview(dotSizeRow)
    }
    
    private func createSwitchRow(title: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        
        let sw = HackSwitch()
        sw.hackTitle = title
        sw.isOn = crosshairEnabled
        sw.onTintColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 1.0)
        sw.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.addTarget(self, action: #selector(switchToggled(_:)), for: .valueChanged)
        row.addSubview(sw)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            
            sw.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            sw.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        
        return row
    }
    
    private func createSegmentedRow(title: String, items: [String], selectedIndex: Int, tag: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 55).isActive = true
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        
        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentIndex = selectedIndex
        seg.tag = tag
        seg.selectedSegmentTintColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 1.0)
        
        let normalTitleAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        let selectedTitleAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        seg.setTitleTextAttributes(normalTitleAttributes, for: .normal)
        seg.setTitleTextAttributes(selectedTitleAttributes, for: .selected)
        seg.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        seg.translatesAutoresizingMaskIntoConstraints = false
        seg.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        row.addSubview(seg)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            label.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            
            seg.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            seg.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            seg.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4)
        ])
        
        return row
    }
    
    private func createSliderRow(title: String, minVal: Float, maxVal: Float, currentVal: Float, tag: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        
        let slider = UISlider()
        slider.minimumValue = minVal
        slider.maximumValue = maxVal
        slider.value = currentVal
        slider.tag = tag
        slider.minimumTrackTintColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 1.0)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        row.addSubview(slider)
        
        let valLabel = UILabel()
        valLabel.text = String(format: "%.1f", Double(currentVal))
        valLabel.textColor = .lightGray
        valLabel.font = UIFont.systemFont(ofSize: 11)
        valLabel.textAlignment = .right
        valLabel.translatesAutoresizingMaskIntoConstraints = false
        valLabel.tag = tag + 100
        row.addSubview(valLabel)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            label.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            
            valLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            valLabel.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            valLabel.widthAnchor.constraint(equalToConstant: 40),
            
            slider.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            slider.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4)
        ])
        
        return row
    }

    // MARK: - Actions
    @objc private func switchToggled(_ sender: HackSwitch) {
        crosshairEnabled = sender.isOn
        saveSettings()
        updateCrosshairDrawing()
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        if sender.tag == 10 {
            crosshairStyle = sender.selectedSegmentIndex
        } else if sender.tag == 11 {
            crosshairColorIndex = sender.selectedSegmentIndex
        }
        saveSettings()
        updateCrosshairDrawing()
    }
    
    @objc private func sliderChanged(_ sender: UISlider) {
        let val = CGFloat(sender.value)
        if sender.tag == 1 {
            crosshairSize = val
        } else if sender.tag == 2 {
            crosshairGap = val
        } else if sender.tag == 3 {
            crosshairThickness = val
        } else if sender.tag == 4 {
            crosshairDotSize = val
        }
        
        if let valLabel = contentStackView.viewWithTag(sender.tag + 100) as? UILabel {
            valLabel.text = String(format: "%.1f", Double(val))
        }
        
        saveSettings()
        updateCrosshairDrawing()
    }
    
    @objc private func closeMenu() {
        UIView.animate(withDuration: 0.2, animations: {
            self.menuPanel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.menuPanel.alpha = 0.0
        }) { _ in
            self.menuPanel.isHidden = true
        }
    }

    // MARK: - Drawing Logic
    private func updateCrosshairDrawing() {
        espLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        guard crosshairEnabled else { return }
        
        let center = CGPoint(x: espView.bounds.midX, y: espView.bounds.midY)
        let path = UIBezierPath()
        let color = getCrosshairColor()
        
        let size = crosshairSize
        let gap = crosshairGap
        let thickness = crosshairThickness
        let dotSize = crosshairDotSize
        
        // 1. Draw Dot (Styles: Dot=0, Combine/All=4, T-Shape=3)
        if crosshairStyle == 0 || crosshairStyle == 4 || crosshairStyle == 3 {
            let dotPath = UIBezierPath(arcCenter: center, radius: dotSize, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            let dotLayer = CAShapeLayer()
            dotLayer.path = dotPath.cgPath
            dotLayer.fillColor = color.cgColor
            espLayer.addSublayer(dotLayer)
        }
        
        // 2. Draw Classic Cross Lines (Styles: Cross=1, Combine/All=4)
        if crosshairStyle == 1 || crosshairStyle == 4 {
            // North
            path.move(to: CGPoint(x: center.x, y: center.y - gap - size))
            path.addLine(to: CGPoint(x: center.x, y: center.y - gap))
            
            // South
            path.move(to: CGPoint(x: center.x, y: center.y + gap))
            path.addLine(to: CGPoint(x: center.x, y: center.y + gap + size))
            
            // West
            path.move(to: CGPoint(x: center.x - gap - size, y: center.y))
            path.addLine(to: CGPoint(x: center.x - gap, y: center.y))
            
            // East
            path.move(to: CGPoint(x: center.x + gap, y: center.y))
            path.addLine(to: CGPoint(x: center.x + gap + size, y: center.y))
        }
        
        // 3. Draw Circle (Styles: Circle=2, Combine/All=4)
        if crosshairStyle == 2 || crosshairStyle == 4 {
            let circlePath = UIBezierPath(arcCenter: center, radius: gap + (size / 2.0), startAngle: 0, endAngle: .pi * 2, clockwise: true)
            let circleLayer = CAShapeLayer()
            circleLayer.path = circlePath.cgPath
            circleLayer.strokeColor = color.cgColor
            circleLayer.fillColor = UIColor.clear.cgColor
            circleLayer.lineWidth = thickness
            espLayer.addSublayer(circleLayer)
        }
        
        // 4. Draw T-Shape Lines (Style: T-Shape=3)
        if crosshairStyle == 3 {
            // South
            path.move(to: CGPoint(x: center.x, y: center.y + gap))
            path.addLine(to: CGPoint(x: center.x, y: center.y + gap + size))
            
            // West
            path.move(to: CGPoint(x: center.x - gap - size, y: center.y))
            path.addLine(to: CGPoint(x: center.x - gap, y: center.y))
            
            // East
            path.move(to: CGPoint(x: center.x + gap, y: center.y))
            path.addLine(to: CGPoint(x: center.x + gap + size, y: center.y))
        }
        
        if !path.isEmpty {
            let shape = CAShapeLayer()
            shape.path = path.cgPath
            shape.strokeColor = color.cgColor
            shape.fillColor = UIColor.clear.cgColor
            shape.lineWidth = thickness
            shape.lineCap = .round
            espLayer.addSublayer(shape)
        }
    }
    
    private func getCrosshairColor() -> UIColor {
        switch crosshairColorIndex {
        case 0: return .green
        case 1: return .red
        case 2: return .cyan
        case 3: return .yellow
        case 4: return .white
        default: return .green
        }
    }

    // MARK: - Settings Persistence
    private func loadSettings() {
        crosshairEnabled = UserDefaults.standard.object(forKey: "cross_enabled") as? Bool ?? true
        crosshairStyle = UserDefaults.standard.integer(forKey: "cross_style")
        crosshairColorIndex = UserDefaults.standard.integer(forKey: "cross_color_index")
        
        if let savedSize = UserDefaults.standard.object(forKey: "cross_size") as? Double {
            crosshairSize = CGFloat(savedSize)
        } else {
            crosshairSize = 12
        }
        
        if let savedGap = UserDefaults.standard.object(forKey: "cross_gap") as? Double {
            crosshairGap = CGFloat(savedGap)
        } else {
            crosshairGap = 5
        }
        
        if let savedThickness = UserDefaults.standard.object(forKey: "cross_thickness") as? Double {
            crosshairThickness = CGFloat(savedThickness)
        } else {
            crosshairThickness = 1.5
        }
        
        if let savedDotSize = UserDefaults.standard.object(forKey: "cross_dot_size") as? Double {
            crosshairDotSize = CGFloat(savedDotSize)
        } else {
            crosshairDotSize = 2.0
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(crosshairEnabled, forKey: "cross_enabled")
        UserDefaults.standard.set(crosshairStyle, forKey: "cross_style")
        UserDefaults.standard.set(crosshairColorIndex, forKey: "cross_color_index")
        UserDefaults.standard.set(Double(crosshairSize), forKey: "cross_size")
        UserDefaults.standard.set(Double(crosshairGap), forKey: "cross_gap")
        UserDefaults.standard.set(Double(crosshairThickness), forKey: "cross_thickness")
        UserDefaults.standard.set(Double(crosshairDotSize), forKey: "cross_dot_size")
        UserDefaults.standard.synchronize()
    }

    // MARK: - DraggableViewDelegate
    func didTap(view: DraggableView) {
        let isOpen = !menuPanel.isHidden
        if isOpen {
            closeMenu()
        } else {
            self.menuPanel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.menuPanel.alpha = 0.0
            self.menuPanel.isHidden = false
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                self.menuPanel.transform = .identity
                self.menuPanel.alpha = 1.0
            }, completion: nil)
            loadTabContent()
        }
    }
    
    func didDrag(view: DraggableView, to center: CGPoint) {
        let s = self.view.bounds.size
        var c = center
        c.x = max(menuButton.bounds.width / 2, min(c.x, s.width - menuButton.bounds.width / 2))
        c.y = max(menuButton.bounds.height / 2, min(c.y, s.height - menuButton.bounds.height / 2))
        menuButton.center = c
    }
    
    func didEndDrag(view: DraggableView) {
        OverlayWindowManager.shared.savePosition(menuButton.frame.origin)
    }
    
    @objc func handleRotation() {
        let rawOrientation = globalGetDeviceOrientation?() ?? 0
        let orientation = UIDeviceOrientation(rawValue: rawOrientation) ?? .unknown
        
        var angle: CGFloat = 0
        var isLandscape = false
        
        switch orientation {
        case .landscapeLeft:
            angle = .pi / 2
            isLandscape = true
        case .landscapeRight:
            angle = -.pi / 2
            isLandscape = true
        case .portraitUpsideDown:
            angle = .pi
            isLandscape = false
        default:
            angle = 0
            isLandscape = false
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(rotationAngle: angle)
            
            let s = UIScreen.main.bounds.size
            var c = self.menuButton.center
            c.x = max(self.menuButton.bounds.width / 2, min(c.x, s.width - self.menuButton.bounds.width / 2))
            c.y = max(self.menuButton.bounds.height / 2, min(c.y, s.height - self.menuButton.bounds.height / 2))
            self.menuButton.center = c
            
            if isLandscape {
                self.espView.frame = CGRect(x: 0, y: 0, width: s.height, height: s.width)
            } else {
                self.espView.frame = CGRect(x: 0, y: 0, width: s.width, height: s.height)
            }
            
            self.updateCrosshairDrawing()
        }
    }
}
