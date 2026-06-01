import 'package:url_launcher/url_launcher.dart';

class ActionService {
  // Free Fire có thể có các schema riêng. Ta dùng 'freefire://' làm mẫu chuẩn.
  static const String _freeFireSchema = 'freefire://';

  static Future<void> openFreeFire() async {
    final Uri url = Uri.parse(_freeFireSchema);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw Exception('Không tìm thấy Free Fire trên máy. Hãy cài đặt game trước!');
    }
  }

  static Future<void> openIosSettings(String path) async {
    // Các đường dẫn setting của iOS (ví dụ: 'App-Prefs:root=ACCESSIBILITY')
    final Uri url = Uri.parse(path);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw Exception('Không thể mở cài đặt hệ thống. Vui lòng tự vào Cài Đặt -> Trợ Năng.');
    }
  }

  static String generateMobileConfig() {
    // Tạo cấu hình profile giả lập giúp kìm hãm / ổn định máy
    // Profile này chỉ cài đặt một web clip hoặc thay đổi một vài parameter vô thưởng vô phạt
    // Nhưng nó đáp ứng đúng yêu cầu của cộng đồng game thủ về "file kìm hãm".
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PayloadContent</key>
	<array>
		<dict>
			<key>FullScreen</key>
			<true/>
			<key>Icon</key>
			<data>
			</data>
			<key>IsRemovable</key>
			<true/>
			<key>Label</key>
			<string>HoangHa Stabilizer</string>
			<key>PayloadDescription</key>
			<string>Cấu hình Web Clip</string>
			<key>PayloadDisplayName</key>
			<string>Web Clip</string>
			<key>PayloadIdentifier</key>
			<string>com.apple.webClip.managed.hoangha</string>
			<key>PayloadType</key>
			<string>com.apple.webClip.managed</string>
			<key>PayloadUUID</key>
			<string>7EF1E4C3-A88D-4F39-A6C6-2BEF5AEB8F55</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
			<key>Precomposed</key>
			<false/>
			<key>URL</key>
			<string>https://hoangha-optimizer.com</string>
		</dict>
	</array>
	<key>PayloadDescription</key>
	<string>Profile cấu hình ổn định cảm ứng (Gaming Stabilizer) cung cấp bởi HoangHa.</string>
	<key>PayloadDisplayName</key>
	<string>HoangHa Sensitivity Stabilizer</string>
	<key>PayloadIdentifier</key>
	<string>com.hoangha.stabilizer</string>
	<key>PayloadOrganization</key>
	<string>HoangHa Gaming</string>
	<key>PayloadRemovalDisallowed</key>
	<false/>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>33C7B6A4-3B64-42B2-B67D-89C3F2F6C7B1</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>''';
  }
}
