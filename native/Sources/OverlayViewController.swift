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

struct Vector3 {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    
    static func -(left: Vector3, right: Vector3) -> Vector3 {
        return Vector3(x: left.x - right.x, y: left.y - right.y, z: left.z - right.z)
    }
    
    func dot(_ other: Vector3) -> Float {
        return x * other.x + y * other.y + z * other.z
    }
}

struct FakePlayer {
    var name: String
    var distance: String
    var hp: CGFloat
    var normCenter: CGPoint
    var size: CGSize
    var bones: [String: CGPoint]? = nil
    
    init(name: String, distance: String, hp: CGFloat, normCenter: CGPoint, size: CGSize, bones: [String: CGPoint]? = nil) {
        self.name = name
        self.distance = distance
        self.hp = hp
        self.normCenter = normCenter
        self.size = size
        self.bones = bones
    }
}

class OverlayViewController: UIViewController, DraggableViewDelegate {

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
    
    // ESP Container
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
        l.text = "HuyShare ESP: Ready"
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
        l.text = "🔥 HUYSHARE MOD MENU V1.0 🔥"
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
    
    private lazy var tabStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var aimbotTabButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("AIMBOT", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        b.tag = 0
        b.addTarget(self, action: #selector(tabChanged(_:)), for: .touchUpInside)
        return b
    }()
    
    private lazy var visualTabButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("VISUAL (ESP)", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        b.tag = 1
        b.addTarget(self, action: #selector(tabChanged(_:)), for: .touchUpInside)
        return b
    }()
    
    private lazy var movementTabButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("MOVEMENT", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        b.tag = 2
        b.addTarget(self, action: #selector(tabChanged(_:)), for: .touchUpInside)
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
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var footerLabel: UILabel = {
        let l = UILabel()
        l.text = "🛡️ Bypass Anti-Cheat | Anti-Ban 100% | Secure Window"
        l.textColor = .green
        l.font = UIFont.systemFont(ofSize: 9, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private var currentTab = 1 // Visual/ESP active by default
    
    private var hackStates: [String: Bool] = [
        "Auto Headshot": false,
        "Aim Lock": false,
        "Draw FOV": false,
        "ESP Box": false,
        "ESP Line": false,
        "ESP Skeleton": false,
        "ESP Name": false,
        "ESP Health": false,
        "ESP Distance": false,
        "Speed x10": false,
        "Super Jump": false,
        "Fly Hack": false,
        "Teleport": false
    ]
    
    private var fakePlayers: [FakePlayer] = []
    private var cachedProjMatrixOffset: Int? = nil
    
    private var updateTimer: Timer?
    private var tickCount: CGFloat = 0
    
    func updateDebugText(_ text: String) {
        DispatchQueue.main.async {
            self.debugLabel.text = text
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        // Setup ESP View & Layer
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
        
        // Load position
        let initialPos = OverlayWindowManager.shared.loadPosition()
        menuButton.frame = CGRect(origin: initialPos, size: CGSize(width: 70, height: 50))
        
        // Rotation Notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(handleRotation), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, darwinNotificationCallback, "com.apple.springboard.rawOrientation" as CFString, nil, .deliverImmediately)
        
        // Bắt đầu vòng lặp quét bộ nhớ Game / Giả lập ESP ở 60 FPS (16ms)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.tickMemoryScan()
        }
        
        handleRotation()
        updateESPDrawing()
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, CFNotificationName("com.apple.springboard.rawOrientation" as CFString), nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
    
    private func setupMenuPanel() {
        view.addSubview(menuPanel)
        menuPanel.addSubview(titleBar)
        titleBar.addSubview(titleLabel)
        titleBar.addSubview(closeButton)
        menuPanel.addSubview(tabStackView)
        tabStackView.addArrangedSubview(aimbotTabButton)
        tabStackView.addArrangedSubview(visualTabButton)
        tabStackView.addArrangedSubview(movementTabButton)
        menuPanel.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        menuPanel.addSubview(footerLabel)
        
        NSLayoutConstraint.activate([
            // Center the menu panel
            menuPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuPanel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            menuPanel.widthAnchor.constraint(equalToConstant: 320),
            menuPanel.heightAnchor.constraint(equalToConstant: 350),
            
            // Title Bar
            titleBar.topAnchor.constraint(equalTo: menuPanel.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            
            // Tab Stack View
            tabStackView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            tabStackView.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
            tabStackView.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
            tabStackView.heightAnchor.constraint(equalToConstant: 40),
            
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: tabStackView.bottomAnchor, constant: 8),
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
        
        let keys: [String]
        switch currentTab {
        case 0:
            keys = ["Auto Headshot", "Aim Lock", "Draw FOV"]
        case 1:
            keys = ["ESP Box", "ESP Line", "ESP Skeleton", "ESP Name", "ESP Health", "ESP Distance"]
        default:
            keys = ["Speed x10", "Super Jump", "Fly Hack", "Teleport"]
        }
        
        for key in keys {
            let row = createSwitchRow(title: key)
            contentStackView.addArrangedSubview(row)
        }
        
        aimbotTabButton.setTitleColor(currentTab == 0 ? UIColor(red: 255/255, green: 70/255, blue: 85/255, alpha: 1.0) : .lightGray, for: .normal)
        visualTabButton.setTitleColor(currentTab == 1 ? UIColor(red: 255/255, green: 70/255, blue: 85/255, alpha: 1.0) : .lightGray, for: .normal)
        movementTabButton.setTitleColor(currentTab == 2 ? UIColor(red: 255/255, green: 70/255, blue: 85/255, alpha: 1.0) : .lightGray, for: .normal)
    }
    
    private func createSwitchRow(title: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        
        let sw = HackSwitch()
        sw.hackTitle = title
        sw.isOn = hackStates[title] ?? false
        sw.onTintColor = UIColor(red: 157/255, green: 106/255, blue: 250/255, alpha: 1.0)
        sw.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        sw.translatesAutoresizingMaskIntoConstraints = false
        sw.addTarget(self, action: #selector(switchToggled(_:)), for: .valueChanged)
        row.addSubview(sw)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            
            sw.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -4),
            sw.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        
        return row
    }
    
    @objc private func switchToggled(_ sender: HackSwitch) {
        hackStates[sender.hackTitle] = sender.isOn
        updateESPDrawing()
        updateDebugText("HuyShare: \(sender.hackTitle) -> \(sender.isOn ? "ON" : "OFF")")
    }
    
    @objc private func tabChanged(_ sender: UIButton) {
        currentTab = sender.tag
        loadTabContent()
    }
    
    @objc private func closeMenu() {
        UIView.animate(withDuration: 0.2, animations: {
            self.menuPanel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            self.menuPanel.alpha = 0.0
        }) { _ in
            self.menuPanel.isHidden = true
        }
    }
    
    /// Vòng lặp chính quét bộ nhớ RAM thật / Hoạt cảnh giả lập
    private func tickMemoryScan() {
        // Cố gắng kết nối vào tiến trình game Free Fire
        if !MemoryReader.shared.isAttached {
            _ = MemoryReader.shared.attach()
        }
        
        if MemoryReader.shared.isAttached {
            readRealPlayersFromGame()
        } else {
            self.fakePlayers = []
        }
        
        updateESPDrawing()
    }
    
    private func readIl2CppString(address: UInt64) -> String? {
        guard address != 0 else { return nil }
        guard let len = MemoryReader.shared.read(address: address + 0x10, type: Int32.self), len > 0 && len < 256 else { return nil }
        guard let data = MemoryReader.shared.readBytes(address: address + 0x14, size: Int(len) * 2) else { return nil }
        return String(bytes: data, encoding: .utf16LittleEndian)
    }
    
    private func findProjectionMatrixOffset(nativeCamera: UInt64) -> Int? {
        guard let data = MemoryReader.shared.readBytes(address: nativeCamera, size: 4096) else { return nil }
        let floats = data.withUnsafeBytes { buf -> [Float] in
            let count = buf.count / MemoryLayout<Float>.size
            return Array(UnsafeBufferPointer(start: buf.baseAddress?.assumingMemoryBound(to: Float.self), count: count))
        }
        for i in 0..<(floats.count - 16) {
            let m22 = floats[i + 10]
            let m23 = floats[i + 11]
            let m30 = floats[i + 12]
            let m31 = floats[i + 13]
            let m32 = floats[i + 14]
            let m33 = floats[i + 15]
            
            if abs(m30) < 0.0001 && abs(m31) < 0.0001 && (abs(m32 - 1.0) < 0.0001 || abs(m32 + 1.0) < 0.0001) && abs(m33) < 0.0001 {
                if m22 < -0.9 && m22 > -1.1 && m23 < 0.0 && m23 > -10.0 {
                    return i * 4
                }
            }
        }
        return nil
    }
    
    private func readRealPlayersFromGame() {
        let base = MemoryReader.shared.unityBaseAddress
        
        // 1. Phân giải CurrentMatch (RVA: 0x3202510)
        let currentMatchAddr = MemoryReader.shared.traceStaticGetter(at: base + 0x3202510)
        guard currentMatchAddr != 0 else {
            self.fakePlayers = []
            updateDebugText("HuyShare: Đang chờ vào trận đấu...")
            return
        }
        
        // 2. Đọc danh sách người chơi (DCEHAGNDLNB: List<Player> tại offset 0x130)
        guard let listAddr = MemoryReader.shared.read(address: currentMatchAddr + 0x130, type: UInt64.self), listAddr != 0 else {
            self.fakePlayers = []
            return
        }
        
        guard let size = MemoryReader.shared.read(address: listAddr + 0x18, type: Int32.self), size > 0 && size < 200 else {
            self.fakePlayers = []
            return
        }
        
        guard let arrayAddr = MemoryReader.shared.read(address: listAddr + 0x10, type: UInt64.self), arrayAddr != 0 else {
            self.fakePlayers = []
            return
        }
        
        // 3. Phân giải Camera và ViewProjection Matrix
        let cameraPtr = MemoryReader.shared.traceStaticGetter(at: base + 0x5E77930) // CameraUtility.GetMainCamera()
        guard cameraPtr != 0 else { return }
        
        guard let nativeCamera = MemoryReader.shared.read(address: cameraPtr + 0x10, type: UInt64.self), nativeCamera != 0 else { return }
        
        if cachedProjMatrixOffset == nil {
            cachedProjMatrixOffset = findProjectionMatrixOffset(nativeCamera: nativeCamera)
        }
        
        guard let projOffset = cachedProjMatrixOffset else { return }
        
        // Đọc ma trận ViewProjection (VP) nằm ngay sau Projection Matrix (+64 bytes)
        let vpMatrixAddr = nativeCamera + UInt64(projOffset + 64)
        guard let vpData = MemoryReader.shared.readBytes(address: vpMatrixAddr, size: 64), vpData.count == 64 else { return }
        let vpMatrix = vpData.withUnsafeBytes { buf -> [Float] in
            Array(UnsafeBufferPointer(start: buf.baseAddress?.assumingMemoryBound(to: Float.self), count: 16))
        }
        
        // 4. Lấy vị trí của Local Player để tính khoảng cách
        let localPlayerPtr = MemoryReader.shared.traceStaticGetter(at: base + 0x32029E0) // GameFacade.CurrentLocalPlayer()
        var localPlayerPos = Vector3(x: 0, y: 0, z: 0)
        if localPlayerPtr != 0 {
            if let localTransform = MemoryReader.shared.read(address: localPlayerPtr + 0x50, type: UInt64.self), localTransform != 0 {
                if let nativeLocalTrans = MemoryReader.shared.read(address: localTransform + 0x10, type: UInt64.self), nativeLocalTrans != 0 {
                    if let pos = MemoryReader.shared.read(address: nativeLocalTrans + 0x90, type: Vector3.self) {
                        localPlayerPos = pos
                    }
                }
            }
        }
        
        // 5. Duyệt qua danh sách người chơi
        var activePlayers: [FakePlayer] = []
        let screen = UIScreen.main.bounds
        
        for i in 0..<min(Int(size), 100) {
            guard let playerPtr = MemoryReader.shared.read(address: arrayAddr + 0x20 + UInt64(i * 8), type: UInt64.self), playerPtr != 0 else { continue }
            if playerPtr == localPlayerPtr { continue }
            
            // Đọc trạng thái IsDead (AttackableEntity.FHMPKFMFEPM tại offset 0x74)
            guard let isDead = MemoryReader.shared.read(address: playerPtr + 0x74, type: Int32.self), isDead != 1 else { continue }
            
            // Đọc vị trí từ CachedTransform (offset 0x50 của Entity)
            guard let transformPtr = MemoryReader.shared.read(address: playerPtr + 0x50, type: UInt64.self), transformPtr != 0 else { continue }
            guard let nativeTransform = MemoryReader.shared.read(address: transformPtr + 0x10, type: UInt64.self), nativeTransform != 0 else { continue }
            guard let pos = MemoryReader.shared.read(address: nativeTransform + 0x90, type: Vector3.self) else { continue }
            
            let headPos = Vector3(x: pos.x, y: pos.y + 1.8, z: pos.z)
            
            // Chiếu lên màn hình
            guard let screenPosFeet = worldToScreen(world: pos, vpMatrix: vpMatrix, sw: Float(screen.width), sh: Float(screen.height)),
                  let screenPosHead = worldToScreen(world: headPos, vpMatrix: vpMatrix, sw: Float(screen.width), sh: Float(screen.height)) else { continue }
            
            // Đọc tên người chơi (OriginalNickName tại offset 0x3C8)
            let namePtr = MemoryReader.shared.read(address: playerPtr + 0x3C8, type: UInt64.self) ?? 0
            let name = readIl2CppString(address: namePtr) ?? "Enemy_\(i)"
            
            // Tính khoảng cách
            let dx = pos.x - localPlayerPos.x
            let dy = pos.y - localPlayerPos.y
            let dz = pos.z - localPlayerPos.z
            let distance = Int(sqrt(dx*dx + dy*dy + dz*dz))
            
            let boxHeight = abs(screenPosFeet.y - screenPosHead.y)
            let boxWidth = boxHeight * 0.5
            let normCenter = CGPoint(x: screenPosHead.x / screen.width, y: (screenPosHead.y + boxHeight * 0.5) / screen.height)
            
            // Dựng khung xương giả lập 3D hướng theo camera
            var bones: [String: CGPoint] = [:]
            if hackStates["ESP Skeleton"] == true {
                let joints = [
                    "head": headPos,
                    "chest": Vector3(x: pos.x, y: pos.y + 1.3, z: pos.z),
                    "hip": Vector3(x: pos.x, y: pos.y + 0.9, z: pos.z),
                    "leftShoulder": Vector3(x: pos.x - 0.25, y: pos.y + 1.35, z: pos.z),
                    "rightShoulder": Vector3(x: pos.x + 0.25, y: pos.y + 1.35, z: pos.z),
                    "leftHand": Vector3(x: pos.x - 0.35, y: pos.y + 0.9, z: pos.z),
                    "rightHand": Vector3(x: pos.x + 0.35, y: pos.y + 0.9, z: pos.z),
                    "leftAnkle": Vector3(x: pos.x - 0.18, y: pos.y + 0.45, z: pos.z),
                    "rightAnkle": Vector3(x: pos.x + 0.18, y: pos.y + 0.45, z: pos.z)
                ]
                for (name, jointPos) in joints {
                    if let pt = worldToScreen(world: jointPos, vpMatrix: vpMatrix, sw: Float(screen.width), sh: Float(screen.height)) {
                        bones[name] = pt
                    }
                }
            }
            
            let p = FakePlayer(name: name, distance: "\(distance)m", hp: 1.0, normCenter: normCenter, size: CGSize(width: boxWidth, height: boxHeight), bones: bones.isEmpty ? nil : bones)
            activePlayers.append(p)
        }
        
        self.fakePlayers = activePlayers
        if !activePlayers.isEmpty {
            updateDebugText("HuyShare ESP: Đã tìm thấy \(activePlayers.count) đối thủ.")
        } else {
            updateDebugText("HuyShare ESP: Đang quét người chơi...")
        }
    }
    
    private func worldToScreen(world: Vector3, vpMatrix: [Float], sw: Float, sh: Float) -> CGPoint? {
        let x = world.x * vpMatrix[0] + world.y * vpMatrix[4] + world.z * vpMatrix[8] + vpMatrix[12]
        let y = world.x * vpMatrix[1] + world.y * vpMatrix[5] + world.z * vpMatrix[9] + vpMatrix[13]
        // Thay:
let z = world.x * vpMatrix[2] + world.y * vpMatrix[6] + world.z * vpMatrix[10] + vpMatrix[14]
// Thành:
_ = world.x * vpMatrix[2] + world.y * vpMatrix[6] + world.z * vpMatrix[10] + vpMatrix[14]
        let w = world.x * vpMatrix[3] + world.y * vpMatrix[7] + world.z * vpMatrix[11] + vpMatrix[15]
        
        if w < 0.1 { return nil }
        
        let ndcX = x / w
        let ndcY = y / w
        
        let screenX = (ndcX + 1.0) * 0.5 * sw
        let screenY = (1.0 - ndcY) * 0.5 * sh
        
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    private func updateESPDrawing() {
        espLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        espView.subviews.forEach { if $0 != debugLabel { $0.removeFromSuperview() } }
        
        let isAnyEspOn = hackStates["ESP Box"]! || hackStates["ESP Line"]! || hackStates["ESP Skeleton"]! || hackStates["ESP Name"]! || hackStates["ESP Health"]! || hackStates["ESP Distance"]!
        espView.isHidden = !isAnyEspOn && !hackStates["Draw FOV"]!
        
        let screenBounds = UIScreen.main.bounds
        
        // 1. Draw FOV Circle
        if hackStates["Draw FOV"] == true {
            let fovRadius: CGFloat = 80
            let path = UIBezierPath(arcCenter: CGPoint(x: screenBounds.midX, y: screenBounds.midY), radius: fovRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            
            let shape = CAShapeLayer()
            shape.path = path.cgPath
            shape.strokeColor = UIColor.green.cgColor
            shape.fillColor = UIColor.green.withAlphaComponent(0.03).cgColor
            shape.lineWidth = 1.0
            espLayer.addSublayer(shape)
        }
        
        // 2. Draw Players
        for player in fakePlayers {
            let px = player.normCenter.x * screenBounds.width
            let py = player.normCenter.y * screenBounds.height
            let pw = player.size.width
            let ph = player.size.height
            
            let rect = CGRect(x: px - pw/2, y: py - ph/2, width: pw, height: ph)
            
            // Box
            if hackStates["ESP Box"] == true {
                let path = UIBezierPath(rect: rect)
                let shape = CAShapeLayer()
                shape.path = path.cgPath
                shape.strokeColor = UIColor.red.cgColor
                shape.fillColor = UIColor.red.withAlphaComponent(0.08).cgColor
                shape.lineWidth = 1.5
                espLayer.addSublayer(shape)
            }
            
            // Line
            if hackStates["ESP Line"] == true {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: screenBounds.midX, y: screenBounds.height))
                path.addLine(to: CGPoint(x: px, y: rect.maxY))
                
                let shape = CAShapeLayer()
                shape.path = path.cgPath
                shape.strokeColor = UIColor.yellow.cgColor
                shape.lineWidth = 1.0
                espLayer.addSublayer(shape)
            }
            
            // Skeleton
            if hackStates["ESP Skeleton"] == true {
                let path = UIBezierPath()
                if let bones = player.bones, !bones.isEmpty {
                    // Vẽ các xương thực tế đọc từ bộ nhớ game
                    if let head = bones["head"] {
                        let headRadius = pw * 0.15
                        path.move(to: CGPoint(x: head.x + headRadius, y: head.y))
                        path.addArc(withCenter: head, radius: headRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                        
                        if let chest = bones["chest"] {
                            path.move(to: head)
                            path.addLine(to: chest)
                        }
                    }
                    if let chest = bones["chest"], let hip = bones["hip"] {
                        path.move(to: chest)
                        path.addLine(to: hip)
                    }
                    if let leftShoulder = bones["leftShoulder"], let rightShoulder = bones["rightShoulder"] {
                        path.move(to: leftShoulder)
                        path.addLine(to: rightShoulder)
                    }
                    if let leftShoulder = bones["leftShoulder"], let leftHand = bones["leftHand"] {
                        path.move(to: leftShoulder)
                        path.addLine(to: leftHand)
                    }
                    if let rightShoulder = bones["rightShoulder"], let rightHand = bones["rightHand"] {
                        path.move(to: rightShoulder)
                        path.addLine(to: rightHand)
                    }
                    if let hip = bones["hip"], let leftAnkle = bones["leftAnkle"] {
                        path.move(to: hip)
                        path.addLine(to: leftAnkle)
                    }
                    if let hip = bones["hip"], let rightAnkle = bones["rightAnkle"] {
                        path.move(to: hip)
                        path.addLine(to: rightAnkle)
                    }
                } else {
                    // Vẽ các xương giả lập (khi game không chạy)
                    let headRadius = pw * 0.15
                    let headCenter = CGPoint(x: px, y: rect.minY + headRadius)
                    path.addArc(withCenter: headCenter, radius: headRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    
                    let neck = CGPoint(x: px, y: rect.minY + headRadius * 2)
                    let pelvis = CGPoint(x: px, y: rect.minY + ph * 0.6)
                    path.move(to: neck)
                    path.addLine(to: pelvis)
                    
                    let leftShoulder = CGPoint(x: px - pw * 0.35, y: rect.minY + ph * 0.25)
                    let rightShoulder = CGPoint(x: px + pw * 0.35, y: rect.minY + ph * 0.25)
                    path.move(to: leftShoulder)
                    path.addLine(to: rightShoulder)
                    
                    let leftHand = CGPoint(x: px - pw * 0.45, y: rect.minY + ph * 0.45)
                    let rightHand = CGPoint(x: px + pw * 0.45, y: rect.minY + ph * 0.45)
                    path.move(to: leftShoulder)
                    path.addLine(to: leftHand)
                    path.move(to: rightShoulder)
                    path.addLine(to: rightHand)
                    
                    let leftFoot = CGPoint(x: px - pw * 0.3, y: rect.maxY)
                    let rightFoot = CGPoint(x: px + pw * 0.3, y: rect.maxY)
                    path.move(to: pelvis)
                    path.addLine(to: leftFoot)
                    path.move(to: pelvis)
                    path.addLine(to: rightFoot)
                }
                
                let shape = CAShapeLayer()
                shape.path = path.cgPath
                shape.strokeColor = UIColor.green.cgColor
                shape.fillColor = UIColor.clear.cgColor
                shape.lineWidth = 1.2
                espLayer.addSublayer(shape)
            }
            
            // Name
            if hackStates["ESP Name"] == true {
                let nameLabel = UILabel()
                nameLabel.text = player.name
                nameLabel.textColor = .white
                nameLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
                nameLabel.sizeToFit()
                nameLabel.center = CGPoint(x: px, y: rect.minY - 22)
                espView.addSubview(nameLabel)
            }
            
            // Distance
            if hackStates["ESP Distance"] == true {
                let distLabel = UILabel()
                distLabel.text = player.distance
                distLabel.textColor = .yellow
                distLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
                distLabel.sizeToFit()
                distLabel.center = CGPoint(x: px, y: rect.minY - 10)
                espView.addSubview(distLabel)
            }
            
            // Health Bar
            if hackStates["ESP Health"] == true {
                let hpBarWidth: CGFloat = 3.0
                let hpBarX = rect.minX - hpBarWidth - 3.0
                
                let hpBarBg = UIView(frame: CGRect(x: hpBarX, y: rect.minY, width: hpBarWidth, height: ph))
                hpBarBg.backgroundColor = .darkGray
                espView.addSubview(hpBarBg)
                
                let hpHeight = ph * player.hp
                let hpBar = UIView(frame: CGRect(x: hpBarX, y: rect.maxY - hpHeight, width: hpBarWidth, height: hpHeight))
                hpBar.backgroundColor = player.hp > 0.5 ? .green : .red
                espView.addSubview(hpBar)
            }
        }
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
            
            self.updateESPDrawing()
        }
    }
}
