package com.studysync.domain.service;

import org.springframework.stereotype.Service;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

@Service
public class EmailService {

    @org.springframework.beans.factory.annotation.Value("${brevo.api.key}")
    private String brevoApiKey;
    private static final String BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";

    public void sendOtpEmail(String to, String otpCode) {
        try {
            String jsonBody = "{"
                    + "\"sender\":{\"name\":\"StudySync\",\"email\":\"studysyncapp1@gmail.com\"},"
                    + "\"to\":[{\"email\":\"" + to + "\"}],"
                    + "\"subject\":\"StudySync Email Verification Code\","
                    + "\"htmlContent\":\"<html><body>Hello,<br><br>Your verification code to register on StudySync:<br><br><h2>" + otpCode + "</h2><br>This code is valid for 5 minutes.<br><br>Best regards!</body></html>\""
                    + "}";

            HttpClient client = HttpClient.newHttpClient();
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(BREVO_API_URL))
                    .header("accept", "application/json")
                    .header("api-key", brevoApiKey)
                    .header("content-type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                    .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() >= 400) {
                System.err.println("E-posta gonderilemedi! Brevo API Hatasi: " + response.body());
            } else {
                System.out.println("E-posta basariyla gonderildi (Brevo HTTP API üzerinden).");
            }

        } catch (Exception e) {
            e.printStackTrace();
            System.err.println("E-posta gonderimi sirasinda istisna olustu: " + e.getMessage());
        }
    }

    public void sendPasswordResetEmail(String to, String otpCode) {
        try {
            String htmlContent = "<html>"
                    + "<body style='margin:0;padding:0;background-color:#F3F4F6;font-family:\\\"Segoe UI\\\",Tahoma,Geneva,Verdana,sans-serif;'>"
                    + "  <div style='max-width:600px;margin:40px auto;background-color:#FFFFFF;border-radius:24px;overflow:hidden;box-shadow:0 10px 30px rgba(0,0,0,0.05);'>"
                    + "    <div style='background:linear-gradient(135deg, #3B82F6 0%, #A855F7 50%, #EC4899 100%);padding:40px 20px;text-align:center;'>"
                    + "      <h1 style='color:#FFFFFF;margin:0;font-size:28px;font-weight:800;letter-spacing:-0.5px;'>StudySync</h1>"
                    + "      <p style='color:rgba(255,255,255,0.9);margin:10px 0 0 0;font-size:14px;'>Password Reset Request</p>"
                    + "    </div>"
                    + "    <div style='padding:40px 30px;color:#1F2937;line-height:1.6;'>"
                    + "      <p style='font-size:16px;margin:0 0 20px 0;'>Hello,</p>"
                    + "      <p style='font-size:15px;margin:0 0 30px 0;'>You have requested a password reset for your StudySync account. Use the following code to reset your password:</p>"
                    + "      <div style='text-align:center;margin:35px 0;'>"
                    + "        <div style='display:inline-block;padding:16px 36px;font-size:32px;font-weight:bold;letter-spacing:6px;color:#7C3AED;background:#F3E8FF;border-radius:14px;border:2px dashed #A855F7;'>" + otpCode + "</div>"
                    + "      </div>"
                    + "      <p style='font-size:14px;color:#6B7280;margin:0 0 20px 0;'>This code is valid for 15 minutes. If you did not request this, you can safely ignore this email.</p>"
                    + "      <hr style='border:0;border-top:1px solid #E5E7EB;margin:30px 0;'/>"
                    + "      <p style='font-size:12px;color:#9CA3AF;margin:0;'>This email was sent automatically. Please do not reply.</p>"
                    + "    </div>"
                    + "    <div style='background-color:#F9FAFB;padding:20px 30px;text-align:center;border-top:1px solid #F3F4F6;'>"
                    + "      <p style='color:#9CA3AF;font-size:12px;margin:0;'>StudySync &copy; 2026 Yeditepe University</p>"
                    + "    </div>"
                    + "  </div>"
                    + "</body>"
                    + "</html>";

            String jsonBody = "{"
                    + "\"sender\":{\"name\":\"StudySync\",\"email\":\"studysyncapp1@gmail.com\"},"
                    + "\"to\":[{\"email\":\"" + to + "\"}],"
                    + "\"subject\":\"StudySync Password Reset Request\","
                    + "\"htmlContent\":\"" + htmlContent + "\""
                    + "}";

            HttpClient client = HttpClient.newHttpClient();
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(BREVO_API_URL))
                    .header("accept", "application/json")
                    .header("api-key", brevoApiKey)
                    .header("content-type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                    .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() >= 400) {
                System.err.println("Sifre sifirlama e-postasi gonderilemedi! Brevo API Hatasi: " + response.body());
            } else {
                System.out.println("Sifre sifirlama e-postasi basariyla gonderildi.");
            }

        } catch (Exception e) {
            e.printStackTrace();
            System.err.println("Sifre sifirlama e-postasi gonderimi sirasinda istisna olustu: " + e.getMessage());
        }
    }
}
