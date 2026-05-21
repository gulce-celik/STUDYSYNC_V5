# E-posta Doğrulama (Email Verification) Planı (Efe)

Şu anda uygulamadaki kayıt olma adımlarında e-posta doğrulama kodu (6 haneli) Flutter uygulamasının içinde rastgele üretilip ekranda gösteriliyor. Bunu Supabase'de olduğu gibi gerçekten kullanıcının e-posta adresine gidecek şekilde (Spring Boot ve SMTP kullanarak) değiştirmemiz gerekiyor.

## Ön Hazırlık Gereksinimleri

**E-Posta Sağlayıcısı (SMTP):** 
Spring Boot üzerinden mail gönderebilmek için bir SMTP sunucusuna ihtiyacımız var. Öğrenci projelerinde en kolay ve ücretsiz yöntem **Gmail SMTP** kullanmaktır. 

Bunun için proje ekibinden birinin Gmail hesabından **"Uygulama Şifresi" (App Password)** oluşturması gerekecek. (Kendi şifresini değil, Google'ın verdiği 16 haneli özel şifreyi kullanacağız).

## Yapılacak Geliştirmeler

### Backend (Java / Spring Boot)

1. **Bağımlılıklar (Dependencies):**
   - `pom.xml` dosyasına `spring-boot-starter-mail` eklenecek.
2. **Konfigürasyon:**
   - `application.yml` dosyasına SMTP ayarları (host: smtp.gmail.com, port: 587, username/password) eklenecek.
3. **Veritabanı (Entity & Repo):**
   - `VerificationCodeEntity` oluşturulacak. Bu tabloda `email`, `code` (6 haneli şifre), `expiresAt` (son kullanma tarihi) ve `verified` (doğrulandı mı?) alanları tutulacak.
   - `VerificationCodeRepository` eklenecek.
4. **Mail Servisi (EmailService):**
   - `JavaMailSender` kullanılarak HTML formatında veya düz metin olarak 6 haneli kodu içeren maili gönderen servis yazılacak.
5. **Yeni API Uç Noktaları (Auth Controller):**
   - `POST /api/v1/auth/send-verification`: E-posta adresini alır, veritabanına 6 haneli kod kaydeder ve kullanıcıya mail atar. (Aynı maile arka arkaya atılırsa eski kod geçersiz kılınır veya güncellenir).
   - `POST /api/v1/auth/verify-code`: E-posta ve kodu alır, eşleşiyorsa veritabanındaki kaydı `verified = true` yapar.
6. **Kayıt (Register) Güvenliği:**
   - Mevcut `POST /api/v1/auth/register` ucunda, kullanıcının e-postasının gerçekten doğrulanıp doğrulanmadığı kontrol edilecek.

### Frontend (Flutter)

1. **API Katmanı:**
   - `auth_api.dart` içerisine `sendVerificationCode` ve `verifyCode` HTTP çağrıları eklenecek.
2. **Kayıt Ekranı (RegisterScreen):**
   - **Step 1:** Kullanıcı "Send Verification Code" butonuna bastığında artık rastgele kod üretilmeyecek, backend'e istek atılacak. (Yükleniyor animasyonu eklenecek).
   - **Step 2:** Ekranda gösterilen "Demo mode" yazıları kaldırılacak. Kullanıcı kodu girip "Verify" dediğinde backend'deki `verify-code` ucuna istek atılacak. Sadece API "başarılı" dönerse 3. adıma geçilecek.
