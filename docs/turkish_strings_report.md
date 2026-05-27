# Project Turkish Strings Analysis Report

This report lists all the user-visible strings (labels, messages, dialog text, error screens) or source configurations containing Turkish characters/keywords.

## 1. Flutter Mobile Client (`mobile_flutter`)

### File: [admin_mock_data.dart](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/mobile_flutter/lib/features/admin/data/admin_mock_data.dart)

| Line | Content | Detected String |
|---|---|---|
| 147 | `name: 'Merve Yılmaz',` | `'Merve Yılmaz'` |
| 212 | `studentName: 'Merve Yılmaz',` | `'Merve Yılmaz'` |
| 257 | `reportedName: 'Merve Yılmaz',` | `'Merve Yılmaz'` |
| 258 | `reporterLabel: 'Gülce K.',` | `'Gülce K.'` |

### File: [register_screen.dart](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/mobile_flutter/lib/features/auth/presentation/register_screen.dart)

| Line | Content | Detected String |
|---|---|---|
| 485 | `decoration: _fieldDec(hint: 'Yılmaz'),` | `'Yılmaz'` |

### File: [home_mock_data.dart](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/mobile_flutter/lib/features/home/data/home_mock_data.dart)

| Line | Content | Detected String |
|---|---|---|
| 36 | `memberPreview: 'Gülce, Efe',` | `'Gülce, Efe'` |

### File: [reservation_map_screen.dart](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/mobile_flutter/lib/features/reservation/presentation/reservation_map_screen.dart)

| Line | Content | Detected String |
|---|---|---|
| 167 | `return 'Masa düzeni ve doluluk sunucudan • Kayıp işaretler raporlardan';` | `'Masa düzeni ve doluluk sunucudan • Kayıp işaretler raporlardan'` |
| 169 | `return 'Masa düzeni admin panelinden (bu oturum) • Doluluk örnek veya sunucudan';` | `'Masa düzeni admin panelinden (bu oturum) • Doluluk örnek veya sunucudan'` |

### File: [study_buddy_mock_data.dart](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/mobile_flutter/lib/features/study_buddy/data/study_buddy_mock_data.dart)

| Line | Content | Detected String |
|---|---|---|
| 61 | `name: 'Gülce K.',` | `'Gülce K.'` |

## 2. Spring Boot Backend (`backend_java`)

### File: [PasswordResetController.java](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/backend_java/src/main/java/com/studysync/api/auth/PasswordResetController.java)

| Line | Content | Detected String |
|---|---|---|
| 40 | `"Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.",` | `"Şifre sıfırlama bağlantısı e-posta adresinize gönderildi."` |
| 55 | `"Şifreniz başarıyla güncellendi.",` | `"Şifreniz başarıyla güncellendi."` |
| 92 | `+ "    <title>StudySync - Şifre Sıfırlama</title>\n"` | `"    <title>StudySync - Şifre Sıfırlama</title>\n"` |
| 195 | `+ "        <h2>Yeni Şifre Oluştur</h2>\n"` | `"        <h2>Yeni Şifre Oluştur</h2>\n"` |
| 196 | `+ "        <p>Lütfen StudySync hesabınız için en az 6 karakterden oluşan yeni bir şifre girin.</p>\n"` | `"        <p>Lütfen StudySync hesabınız için en az 6 karakterden oluşan yeni bir şifre girin.</p>\n"` |
| 202 | `+ "                <label for=\"password\">Yeni Şifre</label>\n"` | `"                <label for=\"password\">Yeni Şifre</label>\n"` |
| 204 | `+ "                <div id=\"passwordError\" class=\"error\">Şifre en az 6 karakter olmalıdır.</div>\n"` | `"                <div id=\"passwordError\" class=\"error\">Şifre en az 6 karakter olmalıdır.</div>\n"` |
| 208 | `+ "                <label for=\"confirmPassword\">Şifreyi Onayla</label>\n"` | `"                <label for=\"confirmPassword\">Şifreyi Onayla</label>\n"` |
| 210 | `+ "                <div id=\"confirmError\" class=\"error\">Şifreler eşleşmiyor.</div>\n"` | `"                <div id=\"confirmError\" class=\"error\">Şifreler eşleşmiyor.</div>\n"` |
| 213 | `+ "            <button type=\"submit\" class=\"btn\">Şifremi Güncelle</button>\n"` | `"            <button type=\"submit\" class=\"btn\">Şifremi Güncelle</button>\n"` |
| 248 | `+ "    <title>Şifreniz Güncellendi - StudySync</title>\n"` | `"    <title>Şifreniz Güncellendi - StudySync</title>\n"` |
| 302 | `+ "        <h2>Şifreniz Güncellendi!</h2>\n"` | `"        <h2>Şifreniz Güncellendi!</h2>\n"` |
| 303 | `+ "        <p>StudySync şifreniz başarıyla değiştirildi. Şimdi mobil uygulamaya geri dönerek yeni şifrenizle giriş yapabilirsiniz.</p>\n"` | `"        <p>StudySync şifreniz başarıyla değiştirildi. Şimdi mobil uygulamaya geri dönerek yeni şifrenizle giriş yapabilirsiniz.</p>\n"` |
| 316 | `+ "    <title>Bağlantı Geçersiz - StudySync</title>\n"` | `"    <title>Bağlantı Geçersiz - StudySync</title>\n"` |
| 360 | `+ "        <h2>Bağlantı Geçersiz</h2>\n"` | `"        <h2>Bağlantı Geçersiz</h2>\n"` |

### File: [ForgotPasswordRequestDto.java](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/backend_java/src/main/java/com/studysync/domain/dto/ForgotPasswordRequestDto.java)

| Line | Content | Detected String |
|---|---|---|
| 7 | `@NotBlank(message = "E-posta alanı boş olamaz")` | `"E-posta alanı boş olamaz"` |
| 8 | `@Email(message = "Geçersiz e-posta formatı")` | `"Geçersiz e-posta formatı"` |

### File: [UpdateCoursesRequestDto.java](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/backend_java/src/main/java/com/studysync/domain/dto/UpdateCoursesRequestDto.java)

| Line | Content | Detected String |
|---|---|---|
| 12 | `@NotNull(message = "courses alanı null olamaz; boş liste gönderilebilir.")` | `"courses alanı null olamaz; boş liste gönderilebilir."` |

### File: [AuthService.java](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/backend_java/src/main/java/com/studysync/domain/service/AuthService.java)

| Line | Content | Detected String |
|---|---|---|
| 125 | `throw new RuntimeException("Lütfen yeni kod istemeden önce 60 saniye bekleyin."); // 429 logic handled` | `"Lütfen yeni kod istemeden önce 60 saniye bekleyin."` |
| 156 | `return new ActionResultDto(true, "Doğrulama kodu e-posta adresinize gönderildi.", null, null);` | `"Doğrulama kodu e-posta adresinize gönderildi."` |
| 163 | `.orElseThrow(() -> new RuntimeException("Bekleyen kayıt bulunamadı."));` | `"Bekleyen kayıt bulunamadı."` |
| 168 | `throw new RuntimeException("Çok fazla hatalı deneme yaptınız. Lütfen yeni kod isteyin.");` | `"Çok fazla hatalı deneme yaptınız. Lütfen yeni kod isteyin."` |
| 172 | `throw new RuntimeException("Doğrulama kodunun süresi dolmuş. Lütfen yeni kod isteyin.");` | `"Doğrulama kodunun süresi dolmuş. Lütfen yeni kod isteyin."` |
| 178 | `throw new RuntimeException("Geçersiz doğrulama kodu.");` | `"Geçersiz doğrulama kodu."` |
| 184 | `return new ActionResultDto(true, "E-posta doğrulandı.", null, null);` | `"E-posta doğrulandı."` |
| 191 | `.orElseThrow(() -> new RuntimeException("Bekleyen kayıt bulunamadı."));` | `"Bekleyen kayıt bulunamadı."` |
| 194 | `throw new RuntimeException("Lütfen önce e-posta adresinizi doğrulayın.");` | `"Lütfen önce e-posta adresinizi doğrulayın."` |
| 283 | `.orElseThrow(() -> new UserNotFoundException("Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı."));` | `"Bu e-posta adresiyle kayıtlı bir kullanıcı bulunamadı."` |
| 304 | `.orElseThrow(() -> new RuntimeException("Geçersiz veya süresi dolmuş şifre sıfırlama bağlantısı."));` | `"Geçersiz veya süresi dolmuş şifre sıfırlama bağlantısı."` |
| 308 | `throw new RuntimeException("Şifre sıfırlama bağlantısının süresi dolmuş.");` | `"Şifre sıfırlama bağlantısının süresi dolmuş."` |
| 312 | `.orElseThrow(() -> new RuntimeException("Kullanıcı bulunamadı."));` | `"Kullanıcı bulunamadı."` |
| 326 | `.orElseThrow(() -> new RuntimeException("Geçersiz veya süresi dolmuş doğrulama kodu."));` | `"Geçersiz veya süresi dolmuş doğrulama kodu."` |
| 330 | `throw new RuntimeException("Doğrulama kodunun süresi dolmuş. Lütfen yeni bir kod isteyin.");` | `"Doğrulama kodunun süresi dolmuş. Lütfen yeni bir kod isteyin."` |
| 334 | `throw new RuntimeException("Geçersiz doğrulama kodu.");` | `"Geçersiz doğrulama kodu."` |
| 338 | `.orElseThrow(() -> new RuntimeException("Kullanıcı bulunamadı."));` | `"Kullanıcı bulunamadı."` |

### File: [EmailService.java](file:///c:\Users\Emre\Documents\GitHub\STUDYSYNC_V5/backend_java/src/main/java/com/studysync/domain/service/EmailService.java)

| Line | Content | Detected String |
|---|---|---|
| 21 | `+ "\"subject\":\"StudySync E-posta Doğrulama Kodu\","` | `"\"subject\":\"StudySync E-posta Doğrulama Kodu\","` |
| 22 | `+ "\"htmlContent\":\"<html><body>Merhaba,<br><br>StudySync uygulamasina kayit olmak icin dogrulama kodunuz:<br><br><h2>" + otpCode + "</h2><br>Bu kod 5 dakika boyunca gecerlidir.<br><br>Iyi calismalar!</body></html>\""` | `"\"htmlContent\":\"<html><body>Merhaba,<br><br>StudySync uygulamasina kayit olmak icin dogrulama kodunuz:<br><br><h2>"` |
| 39 | `System.out.println("E-posta basariyla gonderildi (Brevo HTTP API üzerinden).");` | `"E-posta basariyla gonderildi (Brevo HTTP API üzerinden)."` |
| 55 | `+ "      <p style='color:rgba(255,255,255,0.9);margin:10px 0 0 0;font-size:14px;'>Şifre Sıfırlama Talebi</p>"` | `"      <p style='color:rgba(255,255,255,0.9);margin:10px 0 0 0;font-size:14px;'>Şifre Sıfırlama Talebi</p>"` |
| 59 | `+ "      <p style='font-size:15px;margin:0 0 30px 0;'>StudySync hesabınız için bir şifre sıfırlama talebinde bulundunuz. Şifrenizi sıfırlamak için kullanacağınız doğrulama kodunuz:</p>"` | `"      <p style='font-size:15px;margin:0 0 30px 0;'>StudySync hesabınız için bir şifre sıfırlama talebinde bulundunuz. Şifrenizi sıfırlamak için kullanacağınız doğrulama kodunuz:</p>"` |
| 63 | `+ "      <p style='font-size:14px;color:#6B7280;margin:0 0 20px 0;'>Bu kod 15 dakika boyunca geçerlidir. Eğer bu talebi siz gerçekleştirmediyseniz, bu e-postayı güvenle yok sayabilirsiniz.</p>"` | `"      <p style='font-size:14px;color:#6B7280;margin:0 0 20px 0;'>Bu kod 15 dakika boyunca geçerlidir. Eğer bu talebi siz gerçekleştirmediyseniz, bu e-postayı güvenle yok sayabilirsiniz.</p>"` |
| 65 | `+ "      <p style='font-size:12px;color:#9CA3AF;margin:0;'>Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayınız.</p>"` | `"      <p style='font-size:12px;color:#9CA3AF;margin:0;'>Bu e-posta otomatik olarak gönderilmiştir. Lütfen yanıtlamayınız.</p>"` |
| 77 | `+ "\"subject\":\"StudySync Şifre Sıfırlama Talebi\","` | `"\"subject\":\"StudySync Şifre Sıfırlama Talebi\","` |

