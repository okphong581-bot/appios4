import UIKit

/// OverlayViewController — Quản lý giao diện và cử chỉ kéo thả của overlay.
///
/// Trách nhiệm:
/// 1. Tạo view chứa dòng chữ "Hà Nhạy VIP" với phong cách hiện đại (dark theme, viền neon, bóng đổ).
/// 2. Lắng nghe cử chỉ pan (kéo thả) để di chuyển toàn bộ UIWindow chứa nó trên màn hình.
/// 3. Lưu vị trí mới sau khi kéo thả xong để ghi nhớ trạng thái.
class OverlayViewController: UIViewController {
    
    // ──────────────────────────────────────────────────────────────
    // UI Elements
    // ──────────────────────────────────────────────────────────────
    
    private let containerView: UIView = {
        let view = UIView()
        // Thiết lập nền màu tối bán trong suốt (Glassmorphism style)
        view.backgroundColor = UIColor(red: 26/255, green: 23/255, blue: 48/255, alpha: 0.9)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1.5
        // Viền màu neon tím hồng giống Flutter UI
        view.layer.borderColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 0.8).cgColor
        
        // Bóng đổ neon tím phát sáng nhẹ
        view.layer.shadowColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 0.5).cgColor
        view.layer.shadowOpacity = 0.6
        view.layer.shadowOffset = .zero
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Hà Nhạy VIP"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Tạo khoảng cách chữ rộng hơn nhìn cao cấp
        let attributedString = NSMutableAttributedString(string: "Hà Nhạy VIP")
        attributedString.addAttribute(
            .kern,
            value: 0.5,
            range: NSRange(location: 0, length: attributedString.length)
        )
        label.attributedText = attributedString
        return label
    }()
    
    // ──────────────────────────────────────────────────────────────
    // Lifecycle
    // ──────────────────────────────────────────────────────────────
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // View controller nền trong suốt hoàn toàn
        self.view.backgroundColor = .clear
        
        setupLayout()
        setupGestures()
    }
    
    // ──────────────────────────────────────────────────────────────
    // Setup Methods
    // ──────────────────────────────────────────────────────────────
    
    private func setupLayout() {
        self.view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            // Container view bo sát lề ngoài của ViewController/Window
            containerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -4),
            containerView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 4),
            containerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -4),
            
            // Label nằm ở trung tâm của container view
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
        ])
    }
    
    private func setupGestures() {
        // Sử dụng PanGesture để di chuyển vị trí
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(panGesture)
    }
    
    // ──────────────────────────────────────────────────────────────
    // Gesture Handler
    // ──────────────────────────────────────────────────────────────
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let window = self.view.window else { return }
        let translation = gesture.translation(in: self.view)
        
        if gesture.state == .changed {
            var newCenter = window.center
            newCenter.x += translation.x
            newCenter.y += translation.y
            
            // Ràng buộc trong vùng an toàn của màn hình
            let screenBounds = UIScreen.main.bounds
            let halfWidth = window.frame.width / 2
            let halfHeight = window.frame.height / 2
            
            // Giới hạn không cho kéo ra ngoài viền màn hình
            newCenter.x = max(halfWidth, min(newCenter.x, screenBounds.width - halfWidth))
            newCenter.y = max(halfHeight, min(newCenter.y, screenBounds.height - halfHeight))
            
            window.center = newCenter
            gesture.setTranslation(.zero, in: self.view)
        } else if gesture.state == .ended || gesture.state == .cancelled {
            // Khi người dùng thả tay ra, lưu lại toạ độ x, y mới
            OverlayWindowManager.shared.savePosition(window.frame.origin)
            print("[HaFloating] Đã lưu toạ độ mới: \(window.frame.origin)")
        }
    }
}
