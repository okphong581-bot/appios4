import UIKit

/// OverlayViewController — Giao diện cửa sổ nổi "Hà Nhạy VIP".
/// Hỗ trợ kéo thả bằng ngón tay và hiệu ứng nhấn.
class OverlayViewController: UIViewController {

    // MARK: - UI Elements

    private let containerView: UIView = {
        let v = UIView()
        // Nền tối bán trong suốt (glassmorphism style)
        v.backgroundColor = UIColor(red: 0.08, green: 0.06, blue: 0.18, alpha: 0.92)
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 0.9).cgColor
        // Neon glow tím
        v.layer.shadowColor  = UIColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 0.7).cgColor
        v.layer.shadowOpacity = 0.8
        v.layer.shadowRadius  = 10
        v.layer.shadowOffset  = .zero
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let dotView: UIView = {
        // Chấm xanh nhấp nháy — chỉ báo overlay đang active
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.2, green: 1.0, blue: 0.5, alpha: 1.0)
        v.layer.cornerRadius = 4
        v.layer.shadowColor  = UIColor(red: 0.2, green: 1.0, blue: 0.5, alpha: 1.0).cgColor
        v.layer.shadowOpacity = 1.0
        v.layer.shadowRadius  = 4
        v.layer.shadowOffset  = .zero
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        // Gradient text effect với attributed string
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.white,
            .kern: 0.8
        ]
        lbl.attributedText = NSAttributedString(string: "Hà Nhạy VIP", attributes: attrs)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupLayout()
        setupGestures()
        startPulseAnimation()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(containerView)
        containerView.addSubview(dotView)
        containerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),

            // Chấm xanh bên trái
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),
            dotView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            dotView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),

            // Text ở giữa
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
        ])
    }

    // MARK: - Gestures

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        containerView.addGestureRecognizer(pan)
        containerView.isUserInteractionEnabled = true
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let window = view.window else { return }
        let translation = gesture.translation(in: view)
        let screen = UIScreen.main.bounds

        if gesture.state == .changed {
            var origin = window.frame.origin
            origin.x += translation.x
            origin.y += translation.y

            // Giới hạn trong màn hình
            origin.x = max(0, min(origin.x, screen.width  - window.frame.width))
            origin.y = max(60, min(origin.y, screen.height - window.frame.height))

            window.frame.origin = origin
            gesture.setTranslation(.zero, in: view)

        } else if gesture.state == .ended || gesture.state == .cancelled {
            OverlayWindowManager.shared.savePosition(window.frame.origin)
        }
    }

    // MARK: - Animations

    private func startPulseAnimation() {
        // Nhấp nháy chấm xanh liên tục để biết overlay đang active
        UIView.animate(withDuration: 1.0,
                       delay: 0,
                       options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.dotView.alpha = 0.2
        }
    }
}
