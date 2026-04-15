# Lumoria - Bağlamsal Metin İşleme ve Arşivleme (Context PDF AI)

Lumoria, PDF dökümanları ile etkileşime girerken Google Generative AI (Gemini) teknolojisini kullanarak bağlamsal analiz ve metin işleme yetenekleri sunan, kapsamlı bir mobil uygulamadır. Gelişmiş arşivleme altyapısıyla kullanıcı belgelerini ve notlarını güvende tutar, cihazlar arası eşzamanlama (sync) sağlar.

## 🚀 Temel Özellikler

* **📖 Gelişmiş PDF Görüntüleyici:** `syncfusion_flutter_pdfviewer` tabanlı hızlı ve kesintisiz PDF okuma deneyimi. Metin seçimi, vurgulama ve çizim araçları.
* **🤖 Yapay Zeka Destekli Analiz:** Google Gemini Entegrasyonu ile seçilen metinleri açıklama, özetleme ve çevirme (Bağlamsal Metin İşleme).
* **☁️ Bulut Senkronizasyonu & Arşivleme:** Supabase ile güçlü kimlik doğrulama, kullanıcı verilerini yedekleme ve cihazlar arası bulut tabanlı pürüzsüz veri senkronizasyonu.
* **🔐 Güvenli Yerel Depolama:** Hassas veriler için `flutter_secure_storage` ve lokal veritabanı ihtiyaçları için `sqflite` çözümleri.
* **🌐 Çoklu Dil Desteği:** `easy_localization` ile Türkçe ve İngilizce başta olmak üzere tam yerelleştirme (Localization) desteği.
* **💎 Abonelik Yönetimi (In-App Purchases):** `purchases_flutter` (RevenueCat) entegrasyonu ile deneme sürümleri ve premium abonelik yönetimi.
* **🎨 Modern Kullanıcı Arayüzü:** Kapsamlı tema yönetimi (Koyu/Açık mod), dinamik renkler ve cihaz platformunda optimize edilmiş (Material & Cupertino) modern arayüz tasarımı.

## 🛠 Teknoloji Yığını (Tech Stack)

* **Framework:** Flutter (Dart)
* **Backend & Veritabanı:** Supabase (Auth & Cloud Database)
* **Yapay Zeka (AI):** Google Generative AI (Gemini)
* **Yerel Veritabanı:** sqflite & sqflite_common_ffi (Masaüstü optimizasyonu için)
* **Durum Yönetimi & Config:** Envied (Güvenli Çevre Değişkenleri), SharedPreferences
* **Gelir Yönetimi:** RevenueCat (purchases_flutter)
* **Medya ve Doküman İşleme:** Syncfusion PDF

## ⚙️ Kurulum ve Çalıştırma

### Gereksinimler
- Flutter SDK (>=3.2.0 <4.0.0)
- Dart SDK
- Android Studio / Xcode / Visual Studio (Kullanılacak hedef platforma göre)
- Supabase Hesabı ve Gemini API Anahtarı

### Adımlar

1. **Depoyu Klonlayın:**
   ```bash
   git clone <repo_url>
   cd "mobil pdf ai"
   ```

2. **Bağımlılıkları Yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Çevre Değişkenlerini Ayarlayın:**
   Proje ana dizininde bir `.env` dosyası oluşturun ve içerisine aşağıdaki değişkenleri tanımlayın:
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   GEMINI_API_KEY=your_gemini_api_key
   # Diğer gerekli çevre değişkenleri...
   ```
   *Not: `.env` dosyası git üzerinde takip edilmez. Değişiklikler sonrası `envied` builder sınıflarını yenilemek için:*
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Uygulamayı Çalıştırın:**
   Desteklenen cihazlar arasından hedefinizi seçip (örneğin Web, Windows, Android veya iOS) uygulamayı başlatın:
   ```bash
   flutter run
   ```

## 📂 Proje Mimarisi (lib/)

* **`core/`**: Temel konfigürasyon, güvenlik (CORS/ENV), API yardımcıları ve servisler (`auth_service.dart`, `gemini_service.dart`, `sync_service.dart` vb.)
* **`ui/`**: Arayüz elementleri.
  * `screens/`: Ana ekranlar (Home, Onboarding, Auth)
  * `widgets/`: Tekrar kullanılabilir arayüz bileşenleri (Building Blocks)
  * `theme/`: Uygulama içi tema ve renk ayarları sınıfları

## 📜 Lisans

Bu projenin kullanım hakları "Bağlamsal Metin İşleme ve Arşivleme" geliştiricilerine aittir. Kapalı kaynak olarak saklanabilir veya belirtilen lisansa göre açılabilir. Detaylar için şirket/geliştirici politikalarına başvurun.
