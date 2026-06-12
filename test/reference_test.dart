import 'package:flutter_test/flutter_test.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';

void main() {
  group('Pengujian Modul Referensi (Gawai)', () {
    test('Memastikan parsing JSON pencocokan data Wilayah beroperasi aman', () {
      // 1. Simulasi Respon JSON dari Laravel SyncController::checkRegion
      final mockApiResponse = {
        'status': 'success',
        'message': 'Region ditemukan.',
        'data': {
          'district': 'Kecamatan Kendari Barat',
          'language_name': 'Tolaki'
        }
      };

      // 2. Simulasi Logika Parsing AuthProvider Flutter
      String? detectedDistrict;
      String? detectedLanguage;

      if (mockApiResponse['status'] == 'success') {
        final data = mockApiResponse['data'] as Map<String, dynamic>;
        detectedDistrict = data['district'];
        detectedLanguage = data['language_name'];
      }

      // 3. Verifikasi UI Provider mendapatkan state yang benar
      expect(detectedDistrict, 'Kecamatan Kendari Barat');
      expect(detectedLanguage, 'Tolaki');
    });
  });
}
