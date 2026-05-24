package com.studysync.domain.service;

import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    private final JavaMailSender mailSender;

    public EmailService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    public void sendOtpEmail(String to, String otpCode) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(to);
        message.setSubject("StudySync E-posta Doğrulama Kodu");
        message.setText("Merhaba,\n\nStudySync uygulamasına kayıt olmak için doğrulama kodunuz:\n\n" 
                + otpCode + "\n\nBu kod 5 dakika boyunca geçerlidir.\n\nİyi çalışmalar!");
        
        mailSender.send(message);
    }
}
