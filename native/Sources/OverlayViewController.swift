import UIKit
import CoreFoundation

class ESPViewController: UIViewController {
    private var espView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        
        espView = UIView(frame: UIScreen.main.bounds)
        espView.backgroundColor = .clear
        espView.isHidden = true
        view.addSubview(espView)
        
        setupFakeESP()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRotation), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, { center, observer, name, object, userInfo in
            guard let observer = observer else { return }
            let selfPtr = Unmanaged<ESPViewController>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async {
                selfPtr.handleRotation()
            }
        }, "com.apple.springboard.rawOrientation" as CFString, nil, .deliverImmediately)
        
        handleRotation()
    }
    
    func toggleESP() {
        let isVisible = !espView.isHidden
        UIView.transition(with: espView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.espView.isHidden = isVisible
        }, completion: nil)
    }
    
    var isESPVisible: Bool {
        return !espView.isHidden
    }
    
    private func setupFakeESP() {
        let screenBounds = UIScreen.main.bounds
        let fovRadius: CGFloat = 80
        let fovCircle = UIView(frame: CGRect(x: screenBounds.midX - fovRadius, y: screenBounds.midY - fovRadius, width: fovRadius * 2, height: fovRadius * 2))
        fovCircle.layer.cornerRadius = fovRadius
        fovCircle.layer.borderWidth = 1.5
        fovCircle.layer.borderColor = UIColor.green.cgColor
        fovCircle.backgroundColor = UIColor.green.withAlphaComponent(0.05)
        fovCircle.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        espView.addSubview(fovCircle)
        
        let box1 = createFakeESPBox(frame: CGRect(x: screenBounds.midX - 100, y: screenBounds.midY - 150, width: 40, height: 80), distance: "12m", health: 0.8)
        let box2 = createFakeESPBox(frame: CGRect(x: screenBounds.midX + 80, y: screenBounds.midY - 50, width: 30, height: 60), distance: "45m", health: 0.3)
        let box3 = createFakeESPBox(frame: CGRect(x: screenBounds.midX - 180, y: screenBounds.midY + 20, width: 25, height: 50), distance: "88m", health: 1.0)
        
        espView.addSubview(box1)
        espView.addSubview(box2)
        espView.addSubview(box3)
        
        UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
            box1.transform = CGAffineTransform(translationX: 15, y: -10)
            box2.transform = CGAffineTransform(translationX: -20, y: 5)
            box3.transform = CGAffineTransform(translationX: 10, y: 15)
        }, completion: nil)
    }
    
    private func createFakeESPBox(frame: CGRect, distance: String, health: CGFloat) -> UIView {
        let container = UIView(frame: frame)
        container.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        let box = UIView(frame: container.bounds)
        box.layer.borderWidth = 1.5
        box.layer.borderColor = UIColor.red.cgColor
        box.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        container.addSubview(box)
        let hpBarBg = UIView(frame: CGRect(x: -6, y: 0, width: 3, height: frame.height))
        hpBarBg.backgroundColor = .darkGray
        container.addSubview(hpBarBg)
        let hpBar = UIView(frame: CGRect(x: -6, y: frame.height * (1.0 - health), width: 3, height: frame.height * health))
        hpBar.backgroundColor = health > 0.5 ? .green : .red
        container.addSubview(hpBar)
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
    
    @objc func handleRotation() {
        let rawOrientation = globalGetDeviceOrientation?() ?? 0
        let orientation = UIDeviceOrientation(rawValue: rawOrientation) ?? .unknown
        
        var angle: CGFloat = 0
        var isLandscape = false
        switch orientation {
        case .landscapeLeft: angle = .pi / 2; isLandscape = true
        case .landscapeRight: angle = -.pi / 2; isLandscape = true
        case .portraitUpsideDown: angle = .pi; isLandscape = false
        default: angle = 0; isLandscape = false
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(rotationAngle: angle)
            let screenBounds = UIScreen.main.fixedCoordinateSpace.bounds
            let maxDim = max(screenBounds.width, screenBounds.height)
            let minDim = min(screenBounds.width, screenBounds.height)
            if isLandscape {
                self.view.bounds = CGRect(x: 0, y: 0, width: maxDim, height: minDim)
            } else {
                self.view.bounds = CGRect(x: 0, y: 0, width: minDim, height: maxDim)
            }
            self.espView.frame = self.view.bounds
            if let fov = self.espView.subviews.first {
                fov.center = CGPoint(x: self.espView.bounds.midX, y: self.espView.bounds.midY)
            }
        }
    }
}

class MenuViewController: UIViewController {
    weak var espViewController: ESPViewController?
    private var panStartLocation: CGPoint = .zero
    private var isDragging = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.85)
        view.layer.cornerRadius = 25
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor.systemBlue.cgColor
        view.layer.shadowColor = UIColor.systemBlue.cgColor
        view.layer.shadowOpacity = 0.8
        view.layer.shadowRadius = 8
        view.isUserInteractionEnabled = true
        
        let label = UILabel()
        label.text = "MENU ⚙️"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let window = view.window else { return }
        panStartLocation = touch.location(in: window)
        isDragging = false
        UIView.animate(withDuration: 0.15) {
            self.view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let window = view.window else { return }
        let currentLocation = touch.location(in: window)
        let dx = currentLocation.x - panStartLocation.x
        let dy = currentLocation.y - panStartLocation.y
        
        if !isDragging && hypot(dx, dy) > 5 {
            isDragging = true
        }
        
        if isDragging {
            var newFrame = window.frame
            newFrame.origin.x += dx
            newFrame.origin.y += dy
            window.frame = newFrame
            panStartLocation = touch.location(in: window)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.2) {
            self.view.transform = .identity
        }
        if !isDragging {
            espViewController?.toggleESP()
            let isVisible = espViewController?.isESPVisible ?? false
            UIView.animate(withDuration: 0.3) {
                self.view.layer.borderColor = isVisible ? UIColor.green.cgColor : UIColor.systemBlue.cgColor
                self.view.layer.shadowColor = isVisible ? UIColor.green.cgColor : UIColor.systemBlue.cgColor
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.2) {
            self.view.transform = .identity
        }
    }
}
