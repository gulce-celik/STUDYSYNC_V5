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
                    + "\"subject\":\"StudySync E-posta Doğrulama Kodu\","
                    + "\"htmlContent\":\"<html><body>Merhaba,<br><br>StudySync uygulamasina kayit olmak icin dogrulama kodunuz:<br><br><h2>" + otpCode + "</h2><br>Bu kod 5 dakika boyunca gecerlidir.<br><br>Iyi calismalar!</body></html>\""
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
}
