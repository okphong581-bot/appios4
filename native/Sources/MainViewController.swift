import UIKit

class MainViewController: UIViewController {

    private var isOn = false

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "⚡ AutoTouch VIP"
        l.textColor = .white
        l.font = .systemFont(ofSize: 32, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Tự động nhấn theo trình tự — TrollStore"
        l.textColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.8)
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var infoBox: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.18, alpha: 1)
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.4).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var infoLabel: UILabel = {
        let l = UILabel()
        l.text = "1️⃣  Nhấn START để mở overlay\n2️⃣  Nhấn ⚡ trên màn hình để mở menu\n3️⃣  Nhấn ➕ rồi chạm vào các điểm muốn tự nhấn\n4️⃣  Nhấn ▶️ để chạy theo trình tự"
        l.textColor = UIColor.white.withAlphaComponent(0.85)
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.numberOfLines = 0
        l.textAlignment = .left
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.text = "Trạng thái: ĐANG TẮT"
        l.textColor = .systemRed
        l.font = .systemFont(ofSize: 15, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var toggleButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("▶  START AUTO TOUCH", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        b.backgroundColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1)
        b.layer.cornerRadius = 18
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        b.layer.shadowColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1).cgColor
        b.layer.shadowOpacity = 0.7
        b.layer.shadowRadius = 12
        b.layer.shadowOffset = .zero
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.04, alpha: 1.0)

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(infoBox)
        infoBox.addSubview(infoLabel)
        view.addSubview(statusLabel)
        view.addSubview(toggleButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),

            infoBox.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            infoBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            infoBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            infoLabel.topAnchor.constraint(equalTo: infoBox.topAnchor, constant: 16),
            infoLabel.leadingAnchor.constraint(equalTo: infoBox.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: infoBox.trailingAnchor, constant: -16),
            infoLabel.bottomAnchor.constraint(equalTo: infoBox.bottomAnchor, constant: -16),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: infoBox.bottomAnchor, constant: 30),

            toggleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            toggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            toggleButton.heightAnchor.constraint(equalToConstant: 58),
            toggleButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20)
        ])

        isOn = OverlayWindowManager.shared.isOverlayVisible
        updateUI()
    }

    @objc private func toggleTapped() {
        if isOn {
            OverlayWindowManager.shared.hideOverlay { [weak self] success, _ in
                if success {
                    DispatchQueue.main.async {
                        self?.isOn = false
                        self?.updateUI()
                    }
                }
            }
        } else {
            OverlayWindowManager.shared.showOverlay { [weak self] success, _ in
                if success {
                    DispatchQueue.main.async {
                        self?.isOn = true
                        self?.updateUI()
                    }
                }
            }
        }
    }

    private func updateUI() {
        if isOn {
            toggleButton.setTitle("⏹  STOP AUTO TOUCH", for: .normal)
            toggleButton.backgroundColor = UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 1)
            toggleButton.layer.shadowColor = UIColor.red.cgColor
            statusLabel.text = "Trạng thái: ĐANG BẬT ✅"
            statusLabel.textColor = .systemGreen
        } else {
            toggleButton.setTitle("▶  START AUTO TOUCH", for: .normal)
            toggleButton.backgroundColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1)
            toggleButton.layer.shadowColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1).cgColor
            statusLabel.text = "Trạng thái: ĐANG TẮT"
            statusLabel.textColor = .systemRed
        }
    }
}
