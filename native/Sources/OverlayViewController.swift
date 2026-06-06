import UIKit
import CoreFoundation

private func darwinNotificationCallback(center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) {
    guard let observer = observer else { return }
    let mySelf = Unmanaged<OverlayViewController>.fromOpaque(observer).takeUnretainedValue()
    DispatchQueue.main.async {
        mySelf.handleRotation()
    }
}

// MARK: - DraggableView
class DraggableView: UIView {
    var onTapAction: (() -> Void)?
    var onDragAction: (() -> Void)?
    
    private var startLocation: CGPoint = .zero
    private var isDragging = false
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        startLocation = touch.location(in: self.superview)
        isDragging = false
        
        UIView.animate(withDuration: 0.15) {
            self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let superview = self.superview else { return }
        let currentLocation = touch.location(in: superview)
        
        let dx = currentLocation.x - startLocation.x
        let dy = currentLocation.y - startLocation.y
        
        // Nếu di chuyển đủ xa, tính là drag
        if !isDragging && hypot(dx, dy) > 5 {
            isDragging = true
        }
        
        if isDragging {
            var c = self.center
            c.x += dx
            c.y += dy
            
            let s = superview.bounds.size
            c.x = max(self.bounds.width / 2, min(c.x, s.width - self.bounds.width / 2))
            c.y = max(self.bounds.height / 2, min(c.y, s.height - self.bounds.height / 2))
            
            self.center = c
            startLocation = currentLocation
            
            onDragAction?()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
        
        if !isDragging {
            onTapAction?()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
    }
}

class OverlayViewController: UIViewController {

    private lazy var menuButton: DraggableView = {
        let v = DraggableView()
        v.backgroundColor = UIColor(white: 0.1, alpha: 0.85)
        v.layer.cornerRadius = 25
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor.systemBlue.cgColor
        v.layer.shadowColor = UIColor.systemBlue.cgColor
        v.layer.shadowOpacity = 0.8
        v.layer.shadowRadius = 8
        v.isUserInteractionEnabled = true
        return v
    }()

    private lazy var menuLabel: UILabel = {
        let l = UILabel()
        l.text = "MENU ⚙️"
        l.textColor = .white
        l.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    // ESP Container
    private lazy var espView: UIView = {
        let v = UIView(frame: UIScreen.main.bounds)
        v.backgroundColor = .clear
        v.isHidden = true
        v.isUserInteractionEnabled = false
        return v
    }()
    
    private var isEspVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // Setup ESP View
        view.addSubview(espView)
        setupFakeESP()
        
        // Setup Menu Button
        view.addSubview(menuButton)
        menuButton.addSubview(menuLabel)
        
        // Căn giữa text trong menu
        NSLayoutConstraint.activate([
            menuLabel.centerXAnchor.constraint(equalTo: menuButton.centerXAnchor),
            menuLabel.centerYAnchor.constraint(equalTo: menuButton.centerYAnchor)
        ])
        
        // Kích thước và vị trí ban đầu của menu
        menuButton.frame = CGRect(x: 40, y: 100, width: 70, height: 50)
        
        menuButton.onTapAction = { [weak self] in
            self?.onTap()
        }
        
        menuButton.onDragAction = { [weak self] in
            guard let self = self else { return }
            OverlayWindowManager.shared.savePosition(self.menuButton.frame.origin)
        }
        
        // Bắt đầu nhận diện hướng xoay màn hình (dự phòng)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(handleRotation), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        // Đăng ký Darwin Notification cho SpringBoard Orientation (đáng tin cậy hơn cho daemon)
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, darwinNotificationCallback, "com.apple.springboard.rawOrientation" as CFString, nil, .deliverImmediately)
        
        // Cập nhật hướng xoay ngay lần đầu
        handleRotation()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, CFNotificationName("com.apple.springboard.rawOrientation" as CFString), nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func setupFakeESP() {
        let screenBounds = UIScreen.main.bounds
        
        // 1. FOV Circle (Aimbot FOV)
        let fovRadius: CGFloat = 80
        let fovCircle = UIView(frame: CGRect(x: screenBounds.midX - fovRadius, y: screenBounds.midY - fovRadius, width: fovRadius * 2, height: fovRadius * 2))
        fovCircle.layer.cornerRadius = fovRadius
        fovCircle.layer.borderWidth = 1.5
        fovCircle.layer.borderColor = UIColor.green.cgColor
        fovCircle.backgroundColor = UIColor.green.withAlphaComponent(0.05)
        fovCircle.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        espView.addSubview(fovCircle)
        
        // 2. Fake ESP Boxes
        let box1 = createFakeESPBox(frame: CGRect(x: screenBounds.midX - 100, y: screenBounds.midY - 150, width: 40, height: 80), distance: "12m", health: 0.8)
        let box2 = createFakeESPBox(frame: CGRect(x: screenBounds.midX + 80, y: screenBounds.midY - 50, width: 30, height: 60), distance: "45m", health: 0.3)
        let box3 = createFakeESPBox(frame: CGRect(x: screenBounds.midX - 180, y: screenBounds.midY + 20, width: 25, height: 50), distance: "88m", health: 1.0)
        
        espView.addSubview(box1)
        espView.addSubview(box2)
        espView.addSubview(box3)
        
        // Animate fake ESP slightly
        UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
            box1.transform = CGAffineTransform(translationX: 15, y: -10)
            box2.transform = CGAffineTransform(translationX: -20, y: 5)
            box3.transform = CGAffineTransform(translationX: 10, y: 15)
        }, completion: nil)
    }
    
    private func createFakeESPBox(frame: CGRect, distance: String, health: CGFloat) -> UIView {
        let container = UIView(frame: frame)
        container.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        
        // Red Box
        let box = UIView(frame: container.bounds)
        box.layer.borderWidth = 1.5
        box.layer.borderColor = UIColor.red.cgColor
        box.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        container.addSubview(box)
        
        // Health Bar
        let hpBarBg = UIView(frame: CGRect(x: -6, y: 0, width: 3, height: frame.height))
        hpBarBg.backgroundColor = .darkGray
        container.addSubview(hpBarBg)
        
        let hpBar = UIView(frame: CGRect(x: -6, y: frame.height * (1.0 - health), width: 3, height: frame.height * health))
        hpBar.backgroundColor = health > 0.5 ? .green : .red
        container.addSubview(hpBar)
        
        // Distance Text
        let distLabel = UILabel(frame: CGRect(x: 0, y: -16, width: 50, height: 14))
        distLabel.text = distance
        distLabel.textColor = .yellow
        distLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        distLabel.layer.shadowColor = UIColor.black.cgColor
        distLabel.layer.shadowOffset = CGSize(width: 1, height: 1)
        distLabel.layer.shadowOpacity = 0.8
        container.addSubview(distLabel)
        
        return container
    }

    @objc private func onTap() {
        isEspVisible.toggle()
        UIView.transition(with: espView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.espView.isHidden = !self.isEspVisible
        }, completion: nil)
        
        // Đổi màu viền menu để biết đang bật hay tắt
        UIView.animate(withDuration: 0.3) {
            self.menuButton.layer.borderColor = self.isEspVisible ? UIColor.green.cgColor : UIColor.systemBlue.cgColor
            self.menuButton.layer.shadowColor = self.isEspVisible ? UIColor.green.cgColor : UIColor.systemBlue.cgColor
        }
    }
    
    @objc func handleRotation() {
        // UIDevice.current.orientation đôi khi bị lỗi trong daemon.
        // Sử dụng private API của BackBoardServices để lấy góc quay thật của phần cứng.
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
            // Xoay toàn bộ view chính
            self.view.transform = CGAffineTransform(rotationAngle: angle)
            
            // QUAN TRỌNG: Phải cập nhật bounds để touch (hitTest) không bị liệt khi xoay
            let screenBounds = UIScreen.main.fixedCoordinateSpace.bounds
            let maxDim = max(screenBounds.width, screenBounds.height)
            let minDim = min(screenBounds.width, screenBounds.height)
            
            if isLandscape {
                self.view.bounds = CGRect(x: 0, y: 0, width: maxDim, height: minDim)
            } else {
                self.view.bounds = CGRect(x: 0, y: 0, width: minDim, height: maxDim)
            }
            
            let s = self.view.bounds.size
            
            // Căn chỉnh lại menuButton để không văng ra ngoài sau khi bounds thay đổi
            var c = self.menuButton.center
            c.x = max(self.menuButton.bounds.width / 2, min(c.x, s.width - self.menuButton.bounds.width / 2))
            c.y = max(self.menuButton.bounds.height / 2, min(c.y, s.height - self.menuButton.bounds.height / 2))
            self.menuButton.center = c
            
            // Đặt lại frame của ESP view để cover toàn bộ màn hình
            self.espView.frame = self.view.bounds
            
            // Căn giữa lại FOV
            if let fov = self.espView.subviews.first {
                fov.center = CGPoint(x: self.espView.bounds.midX, y: self.espView.bounds.midY)
            }
        }
    }
}
