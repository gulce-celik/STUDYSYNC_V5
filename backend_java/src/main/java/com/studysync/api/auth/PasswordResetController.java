package com.studysync.api.auth;

import com.studysync.domain.dto.ForgotPasswordRequestDto;
import com.studysync.domain.dto.ResetPasswordOtpRequestDto;
import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
@RequestMapping("/api/v1/auth")
public class PasswordResetController {

    private final AuthService authService;

    @Value("${app.baseUrl:http://localhost:8080}")
    private String appBaseUrl;

    public PasswordResetController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/forgot-password")
    @ResponseBody
    public ResponseEntity<ActionResultDto> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequestDto request) {

        authService.forgotPassword(request, appBaseUrl);

        return ResponseEntity.ok(new ActionResultDto(
            true,
            "Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.",
            null,
            null
        ));
    }

    @PostMapping("/reset-password-otp")
    @ResponseBody
    public ResponseEntity<ActionResultDto> resetPasswordOtp(
            @Valid @RequestBody ResetPasswordOtpRequestDto request) {

        authService.resetPasswordOtp(request.email(), request.otpCode(), request.newPassword());

        return ResponseEntity.ok(new ActionResultDto(
            true,
            "Şifreniz başarıyla güncellendi.",
            null,
            null
        ));
    }

    @GetMapping("/reset-password")
    @ResponseBody
    public String showResetPasswordForm(@RequestParam("token") String token) {
        try {
            // Check token validity by attempting to query it or handle inside view
            // We serve the form directly; the submit action will validate and reset
            return getResetFormHtml(token);
        } catch (Exception e) {
            return getErrorPageHtml(e.getMessage());
        }
    }

    @PostMapping("/reset-password")
    @ResponseBody
    public String handleResetPassword(
            @RequestParam("token") String token,
            @RequestParam("newPassword") String newPassword) {
        try {
            authService.resetPassword(token, newPassword);
            return getSuccessPageHtml();
        } catch (Exception e) {
            return getErrorPageHtml(e.getMessage());
        }
    }

    private String getResetFormHtml(String token) {
        return "<!DOCTYPE html>\n"
                + "<html lang=\"tr\">\n"
                + "<head>\n"
                + "    <meta charset=\"UTF-8\">\n"
                + "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
                + "    <title>StudySync - Şifre Sıfırlama</title>\n"
                + "    <link href=\"https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap\" rel=\"stylesheet\">\n"
                + "    <style>\n"
                + "        * { box-sizing: border-box; margin: 0; padding: 0; }\n"
                + "        body {\n"
                + "            font-family: 'Outfit', sans-serif;\n"
                + "            background: linear-gradient(135deg, #3B82F6 0%, #A855F7 50%, #EC4899 100%);\n"
                + "            min-height: 100vh;\n"
                + "            display: flex;\n"
                + "            align-items: center;\n"
                + "            justify-content: center;\n"
                + "            padding: 20px;\n"
                + "        }\n"
                + "        .card {\n"
                + "            background: rgba(255, 255, 255, 0.85);\n"
                + "            backdrop-filter: blur(20px);\n"
                + "            -webkit-backdrop-filter: blur(20px);\n"
                + "            border: 1px solid rgba(255, 255, 255, 0.4);\n"
                + "            border-radius: 30px;\n"
                + "            padding: 40px;\n"
                + "            width: 100%;\n"
                + "            max-width: 440px;\n"
                + "            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);\n"
                + "            text-align: center;\n"
                + "        }\n"
                + "        .logo-container {\n"
                + "            width: 76px;\n"
                + "            height: 76px;\n"
                + "            background: #FFFFFF;\n"
                + "            border-radius: 20px;\n"
                + "            margin: 0 auto 20px;\n"
                + "            display: flex;\n"
                + "            align-items: center;\n"
                + "            justify-content: center;\n"
                + "            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.08);\n"
                + "        }\n"
                + "        .logo-icon {\n"
                + "            font-size: 38px;\n"
                + "            color: #7C3AED;\n"
                + "        }\n"
                + "        h2 { font-size: 26px; font-weight: 800; color: #111827; margin-bottom: 8px; }\n"
                + "        p { font-size: 14px; color: #4B5563; margin-bottom: 28px; line-height: 1.4; }\n"
                + "        .input-group {\n"
                + "            text-align: left;\n"
                + "            margin-bottom: 20px;\n"
                + "        }\n"
                + "        label {\n"
                + "            display: block;\n"
                + "            font-size: 13px;\n"
                + "            font-weight: 700;\n"
                + "            color: #374151;\n"
                + "            margin-bottom: 8px;\n"
                + "        }\n"
                + "        input {\n"
                + "            width: 100%;\n"
                + "            padding: 14px 16px;\n"
                + "            font-size: 15px;\n"
                + "            font-family: inherit;\n"
                + "            background: #FFFFFF;\n"
                + "            border: 2px solid #E5E7EB;\n"
                + "            border-radius: 14px;\n"
                + "            outline: none;\n"
                + "            transition: all 0.25s ease;\n"
                + "        }\n"
                + "        input:focus {\n"
                + "            border-color: #3B82F6;\n"
                + "            box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.15);\n"
                + "        }\n"
                + "        .btn {\n"
                + "            width: 100%;\n"
                + "            padding: 16px;\n"
                + "            font-size: 16px;\n"
                + "            font-weight: 800;\n"
                + "            color: #FFFFFF;\n"
                + "            border: none;\n"
                + "            border-radius: 14px;\n"
                + "            cursor: pointer;\n"
                + "            background: linear-gradient(135deg, #2563EB 0%, #9333EA 100%);\n"
                + "            box-shadow: 0 10px 20px rgba(37, 99, 235, 0.3);\n"
                + "            transition: all 0.25s ease;\n"
                + "            margin-top: 10px;\n"
                + "        }\n"
                + "        .btn:hover {\n"
                + "            transform: translateY(-2px);\n"
                + "            box-shadow: 0 12px 24px rgba(37, 99, 235, 0.4);\n"
                + "        }\n"
                + "        .btn:active {\n"
                + "            transform: translateY(0);\n"
                + "        }\n"
                + "        .error {\n"
                + "            color: #DC2626;\n"
                + "            font-size: 12px;\n"
                + "            font-weight: 600;\n"
                + "            margin-top: 6px;\n"
                + "            display: none;\n"
                + "        }\n"
                + "    </style>\n"
                + "</head>\n"
                + "<body>\n"
                + "    <div class=\"card\">\n"
                + "        <div class=\"logo-container\">\n"
                + "            <span class=\"logo-icon\">&#x1f512;</span>\n"
                + "        </div>\n"
                + "        <h2>Yeni Şifre Oluştur</h2>\n"
                + "        <p>Lütfen StudySync hesabınız için en az 6 karakterden oluşan yeni bir şifre girin.</p>\n"
                + "        \n"
                + "        <form id=\"resetForm\" method=\"POST\" action=\"/api/v1/auth/reset-password\" onsubmit=\"return validateForm()\">\n"
                + "            <input type=\"hidden\" name=\"token\" value=\"" + token + "\">\n"
                + "            \n"
                + "            <div class=\"input-group\">\n"
                + "                <label for=\"password\">Yeni Şifre</label>\n"
                + "                <input type=\"password\" id=\"password\" name=\"newPassword\" placeholder=\"••••••••\" required>\n"
                + "                <div id=\"passwordError\" class=\"error\">Şifre en az 6 karakter olmalıdır.</div>\n"
                + "            </div>\n"
                + "            \n"
                + "            <div class=\"input-group\">\n"
                + "                <label for=\"confirmPassword\">Şifreyi Onayla</label>\n"
                + "                <input type=\"password\" id=\"confirmPassword\" placeholder=\"••••••••\" required>\n"
                + "                <div id=\"confirmError\" class=\"error\">Şifreler eşleşmiyor.</div>\n"
                + "            </div>\n"
                + "            \n"
                + "            <button type=\"submit\" class=\"btn\">Şifremi Güncelle</button>\n"
                + "        </form>\n"
                + "    </div>\n"
                + "    <script>\n"
                + "        function validateForm() {\n"
                + "            var pass = document.getElementById('password').value;\n"
                + "            var confirmPass = document.getElementById('confirmPassword').value;\n"
                + "            var passError = document.getElementById('passwordError');\n"
                + "            var confirmError = document.getElementById('confirmError');\n"
                + "            var isValid = true;\n"
                + "            if (pass.length < 6) {\n"
                + "                passError.style.display = 'block';\n"
                + "                isValid = false;\n"
                + "            } else {\n"
                + "                passError.style.display = 'none';\n"
                + "            }\n"
                + "            if (pass !== confirmPass) {\n"
                + "                confirmError.style.display = 'block';\n"
                + "                isValid = false;\n"
                + "            } else {\n"
                + "                confirmError.style.display = 'none';\n"
                + "            }\n"
                + "            return isValid;\n"
                + "        }\n"
                + "    </script>\n"
                + "</body>\n"
                + "</html>";
    }

    private String getSuccessPageHtml() {
        return "<!DOCTYPE html>\n"
                + "<html lang=\"tr\">\n"
                + "<head>\n"
                + "    <meta charset=\"UTF-8\">\n"
                + "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
                + "    <title>Şifreniz Güncellendi - StudySync</title>\n"
                + "    <link href=\"https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap\" rel=\"stylesheet\">\n"
                + "    <style>\n"
                + "        * { box-sizing: border-box; margin: 0; padding: 0; }\n"
                + "        body {\n"
                + "            font-family: 'Outfit', sans-serif;\n"
                + "            background: linear-gradient(135deg, #3B82F6 0%, #A855F7 50%, #EC4899 100%);\n"
                + "            min-height: 100vh;\n"
                + "            display: flex;\n"
                + "            align-items: center;\n"
                + "            justify-content: center;\n"
                + "            padding: 20px;\n"
                + "        }\n"
                + "        .card {\n"
                + "            background: rgba(255, 255, 255, 0.85);\n"
                + "            backdrop-filter: blur(20px);\n"
                + "            border: 1px solid rgba(255, 255, 255, 0.4);\n"
                + "            border-radius: 30px;\n"
                + "            padding: 50px 40px;\n"
                + "            width: 100%;\n"
                + "            max-width: 440px;\n"
                + "            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);\n"
                + "            text-align: center;\n"
                + "        }\n"
                + "        .success-icon {\n"
                + "            width: 76px;\n"
                + "            height: 76px;\n"
                + "            background: #D1FAE5;\n"
                + "            color: #10B981;\n"
                + "            border-radius: 50%;\n"
                + "            margin: 0 auto 24px;\n"
                + "            display: flex;\n"
                + "            align-items: center;\n"
                + "            justify-content: center;\n"
                + "            font-size: 38px;\n"
                + "            box-shadow: 0 10px 20px rgba(16, 185, 129, 0.15);\n"
                + "        }\n"
                + "        h2 { font-size: 26px; font-weight: 800; color: #111827; margin-bottom: 12px; }\n"
                + "        p { font-size: 15px; color: #4B5563; line-height: 1.5; margin-bottom: 30px; }\n"
                + "        .badge {\n"
                + "            display: inline-block;\n"
                + "            background: #DBEAFE;\n"
                + "            color: #1E40AF;\n"
                + "            font-size: 12px;\n"
                + "            font-weight: 800;\n"
                + "            padding: 6px 14px;\n"
                + "            border-radius: 20px;\n"
                + "            margin-top: 10px;\n"
                + "        }\n"
                + "    </style>\n"
                + "</head>\n"
                + "<body>\n"
                + "    <div class=\"card\">\n"
                + "        <div class=\"success-icon\">&checkmark;</div>\n"
                + "        <h2>Şifreniz Güncellendi!</h2>\n"
                + "        <p>StudySync şifreniz başarıyla değiştirildi. Şimdi mobil uygulamaya geri dönerek yeni şifrenizle giriş yapabilirsiniz.</p>\n"
                + "        <span class=\"badge\">StudySync Mobile</span>\n"
                + "    </div>\n"
                + "</body>\n"
                + "</html>";
    }

    private String getErrorPageHtml(String errorMessage) {
        return "<!DOCTYPE html>\n"
                + "<html lang=\"tr\">\n"
                + "<head>\n"
                + "    <meta charset=\"UTF-8\">\n"
                + "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
                + "    <title>Bağlantı Geçersiz - StudySync</title>\n"
                + "    <link href=\"https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap\" rel=\"stylesheet\">\n"
                + "    <style>\n"
                + "        * { box-sizing: border-box; margin: 0; padding: 0; }\n"
                + "        body {\n"
                + "            font-family: 'Outfit', sans-serif;\n"
                + "            background: linear-gradient(135deg, #3B82F6 0%, #A855F7 50%, #EC4899 100%);\n"
                + "            min-height: 100vh;\n"
                + "            display: flex;\n"
                + "            align-items: center;\n"
                + "            justify-content: center;\n"
                + "            padding: 20px;\n"
                + "        }\n"
                + "        .card {\n"
                + "            background: rgba(255, 255, 255, 0.85);\n"
                + "            backdrop-filter: blur(20px);\n"
                + "            border: 1px solid rgba(255, 255, 255, 0.4);\n"
                + "            border-radius: 30px;\n"
                + "            padding: 50px 40px;\n"
                + "            width: 100%;\n"
                + "            max-width: 440px;\n"
                + "            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);\n"
                + "            text-align: center;\n"
                + "        }\n"
                + "        .error-icon {\n"
                + "            width: 76px;\n"
                + "            height: 76px;\n"
                + "            background: #FEE2E2;\n"
                + "            color: #EF4444;\n"
                + "            border-radius: 50%;\n"
                + "            margin: 0 auto 24px;\n"
                + "            display: flex;\n"
                + "            align-items: center;\n"
                + "            justify-content: center;\n"
                + "            font-size: 38px;\n"
                + "            box-shadow: 0 10px 20px rgba(239, 68, 68, 0.15);\n"
                + "        }\n"
                + "        h2 { font-size: 26px; font-weight: 800; color: #111827; margin-bottom: 12px; }\n"
                + "        p { font-size: 15px; color: #4B5563; line-height: 1.5; }\n"
                + "    </style>\n"
                + "</head>\n"
                + "<body>\n"
                + "    <div class=\"card\">\n"
                + "        <div class=\"error-icon\">&times;</div>\n"
                + "        <h2>Bağlantı Geçersiz</h2>\n"
                + "        <p>" + errorMessage + "</p>\n"
                + "    </div>\n"
                + "</body>\n"
                + "</html>";
    }
}
