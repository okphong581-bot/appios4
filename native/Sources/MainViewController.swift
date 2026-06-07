import UIKit

class MainViewController: UIViewController {
    
    private var isOn = false
    
    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Hà Nhạy VIP"
        l.textColor = .white
        l.font = .systemFont(ofSize: 32, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "TrollStore Global Overlay (Pure Swift)"
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private lazy var toggleButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("START MOD", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        b.backgroundColor = UIColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 1.0)
        b.layer.cornerRadius = 20
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        return b
    }()

    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.text = "Trạng thái: CHƯA BẬT"
        l.textColor = .systemRed
        l.font = .systemFont(ofSize: 16, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.05, alpha: 1.0)
        
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(statusLabel)
        view.addSubview(toggleButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            
            toggleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            toggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            toggleButton.heightAnchor.constraint(equalToConstant: 60),
            toggleButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 40)
        ])
        
        // Cập nhật trạng thái thật
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
            toggleButton.setTitle("STOP MOD", for: .normal)
            toggleButton.backgroundColor = .systemRed
            statusLabel.text = "Trạng thái: ĐANG HOẠT ĐỘNG"
            statusLabel.textColor = .systemGreen
        } else {
            toggleButton.setTitle("START MOD", for: .normal)
            toggleButton.backgroundColor = UIColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 1.0)
            statusLabel.text = "Trạng thái: CHƯA BẬT"
            statusLabel.textColor = .systemRed
        }
    }
}
