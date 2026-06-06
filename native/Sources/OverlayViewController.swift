import UIKit

class OverlayViewController: UIViewController {

    private lazy var container: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.07, green: 0.05, blue: 0.17, alpha: 0.93)
        v.layer.cornerRadius = 18
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 0.85).cgColor
        v.layer.shadowColor   = UIColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 0.9).cgColor
        v.layer.shadowOpacity = 0.9
        v.layer.shadowRadius  = 12
        v.layer.shadowOffset  = .zero
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var dot: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.2, green: 1.0, blue: 0.55, alpha: 1.0)
        v.layer.cornerRadius = 4.5
        v.layer.shadowColor   = UIColor(red: 0.2, green: 1.0, blue: 0.55, alpha: 1.0).cgColor
        v.layer.shadowOpacity = 1.0
        v.layer.shadowRadius  = 5
        v.layer.shadowOffset  = .zero
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var label: UILabel = {
        let l = UILabel()
        l.text = "Hà Nhạy VIP"
        l.textColor = .white
        l.font      = .systemFont(ofSize: 14, weight: .heavy)
        l.textAlignment = .left
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var dragIcon: UILabel = {
        let l = UILabel()
        l.text      = "⠿"
        l.textColor = UIColor.white.withAlphaComponent(0.35)
        l.font      = .systemFont(ofSize: 16)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildLayout()
        attachGesture()
        animateDot()
    }

    private func buildLayout() {
        view.addSubview(container)
        [dot, label, dragIcon].forEach { container.addSubview($0) }

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),

            dot.widthAnchor.constraint(equalToConstant: 9),
            dot.heightAnchor.constraint(equalToConstant: 9),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 9),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            dragIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dragIcon.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            dragIcon.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
        ])
    }

    private func attachGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 1
        container.addGestureRecognizer(pan)
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        guard let w = view.window else { return }
        let t = g.translation(in: view)
        let s = UIScreen.main.bounds

        switch g.state {
        case .began:
            UIView.animate(withDuration: 0.15) {
                self.container.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        case .changed:
            var o = w.frame.origin
            o.x = max(0, min(o.x + t.x, s.width  - w.frame.width))
            o.y = max(60, min(o.y + t.y, s.height - w.frame.height))
            w.frame.origin = o
            g.setTranslation(.zero, in: view)
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2) {
                self.container.transform = .identity
            }
            OverlayWindowManager.shared.savePosition(w.frame.origin)
        default: break
        }
    }

    private func animateDot() {
        UIView.animate(withDuration: 0.9, delay: 0,
                       options: [.repeat, .autoreverse, .allowUserInteraction,
                                 .curveEaseInOut]) {
            self.dot.alpha = 0.15
        }
    }
}
