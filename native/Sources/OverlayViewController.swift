import UIKit

class OverlayViewController: UIViewController {

    private lazy var container: UIView = {
        let v = UIView()
        v.backgroundColor = .clear // Trong suốt hoàn toàn
        v.translatesAutoresizingMaskIntoConstraints = true
        return v
    }()

    private lazy var label: UILabel = {
        let l = UILabel()
        l.text = "Hà Mods"
        l.textColor = UIColor(red: 0.2, green: 1.0, blue: 0.55, alpha: 1.0)
        l.font = UIFont(name: "AvenirNext-HeavyItalic", size: 24) ?? .systemFont(ofSize: 24, weight: .heavy)
        l.textAlignment = .center
        
        // Tạo viền/shadow phát sáng đẹp mắt để dễ nhìn trên nền trắng/đen
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOffset = CGSize(width: 1, height: 1)
        l.layer.shadowOpacity = 0.8
        l.layer.shadowRadius = 3
        
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // Thêm các view
        view.addSubview(container)
        container.addSubview(label)

        // Căn giữa label trong container
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        // Đặt vị trí ban đầu cho container (ví dụ: góc trên bên trái)
        container.frame = CGRect(x: 40, y: 100, width: 150, height: 50)
        
        attachGesture()
        startColorAnimation()
        
        // Đăng ký nhận sự kiện xoay màn hình
        NotificationCenter.default.addObserver(self, selector: #selector(handleRotation), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        // Cập nhật hướng xoay ngay lần đầu
        handleRotation()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func attachGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 1
        container.addGestureRecognizer(pan)
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: view)
        let s = view.bounds.size

        switch g.state {
        case .began:
            UIView.animate(withDuration: 0.15) {
                self.container.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        case .changed:
            var c = container.center
            c.x += t.x
            c.y += t.y
            
            // Giới hạn không cho kéo container ra ngoài màn hình
            c.x = max(container.bounds.width / 2, min(c.x, s.width - container.bounds.width / 2))
            c.y = max(container.bounds.height / 2, min(c.y, s.height - container.bounds.height / 2))
            
            container.center = c
            g.setTranslation(.zero, in: view)
            
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2) {
                self.container.transform = .identity
            }
            OverlayWindowManager.shared.savePosition(container.frame.origin)
        default: break
        }
    }
    
    @objc private func handleRotation() {
        let orientation = UIDevice.current.orientation
        var angle: CGFloat = 0
        
        switch orientation {
        case .landscapeLeft:
            angle = .pi / 2
        case .landscapeRight:
            angle = -.pi / 2
        case .portraitUpsideDown:
            angle = .pi
        default:
            angle = 0
        }
        
        UIView.animate(withDuration: 0.3) {
            // Xoay toàn bộ view chính để các thành phần bên trong xoay theo
            self.view.transform = CGAffineTransform(rotationAngle: angle)
            
            // Đảm bảo container không bị văng ra khỏi màn hình sau khi xoay
            let s = UIScreen.main.bounds.size
            var c = self.container.center
            c.x = max(self.container.bounds.width / 2, min(c.x, s.width - self.container.bounds.width / 2))
            c.y = max(self.container.bounds.height / 2, min(c.y, s.height - self.container.bounds.height / 2))
            self.container.center = c
        }
    }

    private func startColorAnimation() {
        UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
            self.label.textColor = UIColor(red: 1.0, green: 0.2, blue: 0.55, alpha: 1.0)
        }, completion: nil)
    }
}
