import UIKit
import CoreFoundation

// MARK: - Darwin notification bridge
private func darwinNotificationCallback(center: CFNotificationCenter?, observer: UnsafeMutableRawPointer?, name: CFNotificationName?, object: UnsafeRawPointer?, userInfo: CFDictionary?) {
    guard let observer = observer else { return }
    let vc = Unmanaged<OverlayViewController>.fromOpaque(observer).takeUnretainedValue()
    DispatchQueue.main.async { vc.handleRotation() }
}

// MARK: - Models
struct TouchPoint {
    var position: CGPoint
    var order: Int
}

// MARK: - DraggableView
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
        startLocation = touch.location(in: superview)
        startCenter = center
        isDragging = false
        UIView.animate(withDuration: 0.12) { self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: superview)
        let dx = loc.x - startLocation.x
        let dy = loc.y - startLocation.y
        if hypot(dx, dy) > 5 {
            isDragging = true
            center = CGPoint(x: startCenter.x + dx, y: startCenter.y + dy)
            delegate?.didDrag(view: self, to: center)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        UIView.animate(withDuration: 0.18) { self.transform = .identity }
        isDragging ? delegate?.didEndDrag(view: self) : delegate?.didTap(view: self)
        isDragging = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}

// MARK: - Point Marker View
class PointMarkerView: UIView {
    let index: Int
    private let label = UILabel()
    private let pulse = UIView()

    init(at point: CGPoint, index: Int) {
        self.index = index
        super.init(frame: CGRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44))
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = 22
        backgroundColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.85)
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor
        layer.shadowColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1).cgColor
        layer.shadowOpacity = 0.8
        layer.shadowRadius = 8

        label.text = "\(index)"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .black)
        label.textAlignment = .center
        label.frame = bounds
        addSubview(label)
    }

    func animateActive() {
        UIView.animate(withDuration: 0.15, animations: {
            self.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            self.backgroundColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.95)
            self.layer.shadowColor = UIColor.red.cgColor
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
                self.backgroundColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.85)
                self.layer.shadowColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1).cgColor
            }
        }
    }
}

// MARK: - OverlayViewController
class OverlayViewController: UIViewController, DraggableViewDelegate {

    // MARK: - State
    private var touchPoints: [TouchPoint] = []
    private var markerViews: [PointMarkerView] = []
    private var isRecording = false
    /// Expose cho HUDWindow để biết có cần bắt touches hay không
    var isRecordingMode: Bool { return isRecording }
    private var isPlaying = false
    private var playTimer: Timer?
    private var currentPlayIndex = 0
    private var repeatCount = 0       // 0 = vô tận
    private var currentRepeat = 0
    private var delayMs: Double = 300 // mỗi bước cách nhau bao nhiêu ms
    private var isMenuOpen = false

    // MARK: - UI
    private lazy var menuButton: DraggableView = {
        let v = DraggableView()
        v.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 0.92)
        v.layer.cornerRadius = 26
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.9).cgColor
        v.layer.shadowColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1).cgColor
        v.layer.shadowOpacity = 0.7
        v.layer.shadowRadius = 10
        v.isUserInteractionEnabled = true
        return v
    }()

    private lazy var menuIcon: UILabel = {
        let l = UILabel()
        l.text = "⚡"
        l.font = UIFont.systemFont(ofSize: 22)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Main control panel
    private lazy var panel: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 0.97)
        v.layer.cornerRadius = 18
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.8).cgColor
        v.layer.shadowColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.5).cgColor
        v.layer.shadowOpacity = 0.9
        v.layer.shadowRadius = 15
        v.layer.shadowOffset = .zero
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private lazy var panelTitle: UILabel = {
        let l = UILabel()
        l.text = "⚡ AUTO TOUCH"
        l.textColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1)
        l.font = UIFont.systemFont(ofSize: 14, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var closeBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✕", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(closePanel), for: .touchUpInside)
        return b
    }()

    // Status label
    private lazy var statusLabel: UILabel = {
        let l = UILabel()
        l.text = "📍 Thêm điểm để bắt đầu"
        l.textColor = .lightGray
        l.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        l.textAlignment = .center
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Point count display
    private lazy var pointCountLabel: UILabel = {
        let l = UILabel()
        l.text = "0 điểm"
        l.textColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1)
        l.font = UIFont.systemFont(ofSize: 28, weight: .black)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Add point button
    private lazy var addPointBtn: UIButton = makeActionButton(title: "➕  Thêm Điểm", color: UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1))
    private lazy var playBtn: UIButton = makeActionButton(title: "▶️  Chạy", color: UIColor(red: 0.1, green: 0.75, blue: 0.3, alpha: 1))
    private lazy var stopBtn: UIButton = makeActionButton(title: "⏹  Dừng", color: UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 1))
    private lazy var clearBtn: UIButton = makeActionButton(title: "🗑  Xóa Tất Cả", color: UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1))

    // Delay slider
    private lazy var delayLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        updateDelayLabel(l)
        return l
    }()

    private lazy var delaySlider: UISlider = {
        let s = UISlider()
        s.minimumValue = 50
        s.maximumValue = 3000
        s.value = Float(delayMs)
        s.minimumTrackTintColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1)
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(delaySliderChanged(_:)), for: .valueChanged)
        return s
    }()

    // Repeat count
    private lazy var repeatLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        updateRepeatLabel(l)
        return l
    }()

    private lazy var repeatStepper: UIStepper = {
        let s = UIStepper()
        s.minimumValue = 0
        s.maximumValue = 999
        s.value = 0
        s.stepValue = 1
        s.tintColor = UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1)
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(repeatStepperChanged(_:)), for: .valueChanged)
        return s
    }()

    // Add-mode overlay instruction
    private lazy var addModeOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        v.isHidden = true
        v.isUserInteractionEnabled = false
        return v
    }()

    private lazy var addModeLabel: UILabel = {
        let l = UILabel()
        l.text = "✋ Nhấn vào màn hình để thêm điểm\nNhấn ➕ lần nữa để kết thúc"
        l.textColor = .white
        l.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        l.textAlignment = .center
        l.numberOfLines = 2
        l.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        l.layer.cornerRadius = 12
        l.layer.masksToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    func updateDebugText(_ text: String) {}

    // MARK: - Helper
    private func makeActionButton(title: String, color: UIColor) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        b.backgroundColor = color
        b.layer.cornerRadius = 10
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    private func updateDelayLabel(_ label: UILabel? = nil) {
        let l = label ?? delayLabel
        l.text = "⏱ Delay: \(Int(delayMs))ms"
    }

    private func updateRepeatLabel(_ label: UILabel? = nil) {
        let l = label ?? repeatLabel
        l.text = repeatCount == 0 ? "🔁 Lặp: Vô tận" : "🔁 Lặp: \(repeatCount) lần"
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        setupAddModeOverlay()
        setupMenuButton()
        setupPanel()

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(handleRotation), name: UIDevice.orientationDidChangeNotification, object: nil)

        let obs = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), obs, darwinNotificationCallback, "com.apple.springboard.rawOrientation" as CFString, nil, .deliverImmediately)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        let obs = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), obs, CFNotificationName("com.apple.springboard.rawOrientation" as CFString), nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func setupAddModeOverlay() {
        addModeOverlay.frame = view.bounds
        addModeOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Mặc định isUserInteractionEnabled = false để không chặn touches khi không record
        addModeOverlay.isUserInteractionEnabled = false
        view.addSubview(addModeOverlay)

        view.addSubview(addModeLabel)
        NSLayoutConstraint.activate([
            addModeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addModeLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            addModeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            addModeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            addModeLabel.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func setupMenuButton() {
        menuButton.delegate = self
        view.addSubview(menuButton)
        menuButton.addSubview(menuIcon)

        NSLayoutConstraint.activate([
            menuIcon.centerXAnchor.constraint(equalTo: menuButton.centerXAnchor),
            menuIcon.centerYAnchor.constraint(equalTo: menuButton.centerYAnchor)
        ])

        let pos = OverlayWindowManager.shared.loadPosition()
        menuButton.frame = CGRect(x: pos.x, y: pos.y, width: 52, height: 52)
    }

    private func setupPanel() {
        view.addSubview(panel)

        let titleBar = UIView()
        titleBar.backgroundColor = UIColor(red: 0.03, green: 0.03, blue: 0.1, alpha: 1)
        titleBar.layer.cornerRadius = 18
        titleBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleBar)

        titleBar.addSubview(panelTitle)
        titleBar.addSubview(closeBtn)

        panel.addSubview(pointCountLabel)
        panel.addSubview(statusLabel)

        addPointBtn.addTarget(self, action: #selector(addPointTapped), for: .touchUpInside)
        playBtn.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        stopBtn.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        clearBtn.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        let topRow = makeHStack([addPointBtn, playBtn])
        let bottomRow = makeHStack([stopBtn, clearBtn])
        panel.addSubview(topRow)
        panel.addSubview(bottomRow)

        // Delay row
        let delayRow = makeHStack([delayLabel, delaySlider])
        panel.addSubview(delayRow)

        // Repeat row
        let repeatRow = makeHStack([repeatLabel, repeatStepper])
        panel.addSubview(repeatRow)

        let footerLabel = UILabel()
        footerLabel.text = "⚡ AutoTouch VIP — TrollStore"
        footerLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.7)
        footerLabel.font = UIFont.systemFont(ofSize: 9, weight: .semibold)
        footerLabel.textAlignment = .center
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 300),

            titleBar.topAnchor.constraint(equalTo: panel.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 44),

            panelTitle.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),
            panelTitle.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            closeBtn.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -12),
            closeBtn.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            pointCountLabel.topAnchor.constraint(equalTo: titleBar.bottomAnchor, constant: 10),
            pointCountLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: pointCountLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),

            topRow.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            topRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            topRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            topRow.heightAnchor.constraint(equalToConstant: 40),

            bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            bottomRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            bottomRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            bottomRow.heightAnchor.constraint(equalToConstant: 40),

            delayRow.topAnchor.constraint(equalTo: bottomRow.bottomAnchor, constant: 12),
            delayRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            delayRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            delayRow.heightAnchor.constraint(equalToConstant: 30),

            repeatRow.topAnchor.constraint(equalTo: delayRow.bottomAnchor, constant: 10),
            repeatRow.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            repeatRow.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            repeatRow.heightAnchor.constraint(equalToConstant: 36),

            footerLabel.topAnchor.constraint(equalTo: repeatRow.bottomAnchor, constant: 10),
            footerLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            footerLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10)
        ])
    }

    private func makeHStack(_ views: [UIView]) -> UIStackView {
        let sv = UIStackView(arrangedSubviews: views)
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }

    // MARK: - Touch interception for add-point mode
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRecording, let touch = touches.first else { return }
        let point = touch.location(in: view)

        // Bỏ qua nếu chạm vào menu button
        if menuButton.frame.contains(point) { return }
        // Bỏ qua nếu panel đang mở và chạm vào panel
        if !panel.isHidden && panel.frame.contains(point) { return }
        // Bỏ qua nếu chạm vào nhãn hướng dẫn ở đáy
        if addModeLabel.frame.contains(point) { return }

        addTouchPoint(at: point)
    }

    // MARK: - Add point
    private func addTouchPoint(at point: CGPoint) {
        let idx = touchPoints.count + 1
        let tp = TouchPoint(position: point, order: idx)
        touchPoints.append(tp)

        let marker = PointMarkerView(at: point, index: idx)
        markerViews.append(marker)
        view.insertSubview(marker, belowSubview: menuButton)

        // Animate in
        marker.alpha = 0
        marker.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            marker.alpha = 1
            marker.transform = .identity
        }

        updateUI()
    }

    // MARK: - Actions
    @objc private func addPointTapped() {
        isRecording.toggle()
        if isRecording {
            // Enter add mode — đóng panel để tránh nhầm lẫn
            closePanel()
            addModeOverlay.isHidden = false
            addModeLabel.isHidden = false
            view.bringSubviewToFront(addModeLabel)
            view.bringSubviewToFront(menuButton)
            // HUDWindow sẽ tự nhận isRecordingMode = true và route touches về view này
        } else {
            // Exit add mode
            addModeOverlay.isHidden = true
            addModeLabel.isHidden = true
        }
        updateUI()
    }

    @objc private func playTapped() {
        guard !touchPoints.isEmpty else {
            statusLabel.text = "⚠️ Chưa có điểm nào!"
            return
        }
        guard !isPlaying else { return }
        stopPlaying()
        isPlaying = true
        currentPlayIndex = 0
        currentRepeat = 0
        closePanel()
        startPlayback()
        updateUI()
    }

    @objc private func stopTapped() {
        stopPlaying()
        updateUI()
    }

    @objc private func clearTapped() {
        stopPlaying()
        touchPoints.removeAll()
        markerViews.forEach { $0.removeFromSuperview() }
        markerViews.removeAll()
        updateUI()
    }

    @objc private func closePanel() {
        guard !panel.isHidden else { return }
        UIView.animate(withDuration: 0.2, animations: {
            self.panel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.panel.alpha = 0
        }) { _ in
            self.panel.isHidden = true
            self.panel.transform = .identity
        }
    }

    @objc private func delaySliderChanged(_ sender: UISlider) {
        delayMs = Double(sender.value)
        updateDelayLabel()
    }

    @objc private func repeatStepperChanged(_ sender: UIStepper) {
        repeatCount = Int(sender.value)
        updateRepeatLabel()
    }

    // MARK: - Playback
    private func startPlayback() {
        guard isPlaying, currentPlayIndex < touchPoints.count else {
            // End of sequence
            currentRepeat += 1
            if repeatCount == 0 || currentRepeat < repeatCount {
                // Loop
                currentPlayIndex = 0
                scheduleNextTap()
            } else {
                stopPlaying()
                updateUI()
            }
            return
        }

        let tp = touchPoints[currentPlayIndex]
        let marker = currentPlayIndex < markerViews.count ? markerViews[currentPlayIndex] : nil

        // Animate marker
        marker?.animateActive()

        // Inject touch
        TouchInjector.shared.sendTap(at: tp.position)

        currentPlayIndex += 1

        scheduleNextTap()
    }

    private func scheduleNextTap() {
        guard isPlaying else { return }
        let delay = delayMs / 1000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startPlayback()
        }
    }

    private func stopPlaying() {
        isPlaying = false
        playTimer?.invalidate()
        playTimer = nil
    }

    // MARK: - UI Update
    private func updateUI() {
        let count = touchPoints.count
        pointCountLabel.text = "\(count) điểm"

        if isPlaying {
            statusLabel.text = "⚡ Đang chạy... [\(currentPlayIndex)/\(count)]"
            addPointBtn.isEnabled = false
            playBtn.isEnabled = false
            stopBtn.isEnabled = true
        } else if isRecording {
            statusLabel.text = "📍 Nhấn vào màn hình để thêm điểm \(count + 1)"
            addPointBtn.setTitle("✅  Xong", for: .normal)
            addPointBtn.backgroundColor = UIColor(red: 0.1, green: 0.75, blue: 0.3, alpha: 1)
        } else {
            addPointBtn.setTitle("➕  Thêm Điểm", for: .normal)
            addPointBtn.backgroundColor = UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1)
            addPointBtn.isEnabled = true
            playBtn.isEnabled = count > 0
            stopBtn.isEnabled = false

            if count == 0 {
                statusLabel.text = "📍 Nhấn ➕ để thêm điểm chạm"
            } else {
                statusLabel.text = "✅ \(count) điểm • Nhấn ▶️ để chạy"
            }
        }
    }

    // MARK: - DraggableViewDelegate
    func didTap(view: DraggableView) {
        if isRecording {
            // Exit record mode first
            addPointTapped()
            return
        }
        if panel.isHidden {
            panel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            panel.alpha = 0
            panel.isHidden = false
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8) {
                self.panel.transform = .identity
                self.panel.alpha = 1
            }
            updateUI()
        } else {
            closePanel()
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

    // MARK: - Rotation
    @objc func handleRotation() {
        let rawOrientation = globalGetDeviceOrientation?() ?? 0
        let orientation = UIDeviceOrientation(rawValue: rawOrientation) ?? .unknown
        var angle: CGFloat = 0
        switch orientation {
        case .landscapeLeft:  angle = .pi / 2
        case .landscapeRight: angle = -.pi / 2
        case .portraitUpsideDown: angle = .pi
        default: angle = 0
        }
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(rotationAngle: angle)
        }
    }
}
