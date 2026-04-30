package com.studysync.config;

import com.studysync.domain.entity.CourseCatalogEntity;
import com.studysync.domain.entity.ReservationRecord;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.repository.CourseCatalogRepository;
import com.studysync.domain.repository.ReservationRecordRepository;
import com.studysync.domain.repository.UserAccountRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;

@Configuration
public class DevDataInitializer {

    @Bean
    public CommandLineRunner initDevData(UserAccountRepository userRepository,
            ReservationRecordRepository reservationRepository,
            CourseCatalogRepository courseRepository,
            PasswordEncoder passwordEncoder) {
        return args -> {
            if (courseRepository.count() == 0) {
                CourseCatalogEntity c1 = new CourseCatalogEntity();
                c1.setCode("CSE101");
                c1.setName("Computer Engineering Concepts and Algorithms");
                c1.setDifficultyRating(4.0);
                c1.setRatingCount(100);

                CourseCatalogEntity c2 = new CourseCatalogEntity();
                c2.setCode("GBE113");
                c2.setName("Fundamental Biology");
                c2.setDifficultyRating(4.0);
                c2.setRatingCount(100);

                CourseCatalogEntity c3 = new CourseCatalogEntity();
                c3.setCode("MATH131");
                c3.setName("Calculus I");
                c3.setDifficultyRating(4.0);
                c3.setRatingCount(100);

                CourseCatalogEntity c4 = new CourseCatalogEntity();
                c4.setCode("PHYS101");
                c4.setName("Physics I");
                c4.setDifficultyRating(4.0);
                c4.setRatingCount(100);

                CourseCatalogEntity c5 = new CourseCatalogEntity();
                c5.setCode("CSE114");
                c5.setName("Fundamentals Of Computer Programming");
                c5.setDifficultyRating(4.0);
                c5.setRatingCount(100);

                CourseCatalogEntity c6 = new CourseCatalogEntity();
                c6.setCode("MATH132");
                c6.setName("Calculus II");
                c6.setDifficultyRating(4.0);
                c6.setRatingCount(100);

                CourseCatalogEntity c7 = new CourseCatalogEntity();
                c7.setCode("MATH154");
                c7.setName("Discrete Mathematics");
                c7.setDifficultyRating(4.0);
                c7.setRatingCount(100);

                CourseCatalogEntity c8 = new CourseCatalogEntity();
                c8.setCode("PHYS102");
                c8.setName("Physics II");
                c8.setDifficultyRating(4.0);
                c8.setRatingCount(100);

                CourseCatalogEntity c9 = new CourseCatalogEntity();
                c9.setCode("CSE211");
                c9.setName("Data Structures");
                c9.setDifficultyRating(4.0);
                c9.setRatingCount(100);

                CourseCatalogEntity c10 = new CourseCatalogEntity();
                c10.setCode("CSE221");
                c10.setName("Principles of Logic Design");
                c10.setDifficultyRating(4.0);
                c10.setRatingCount(100);

                CourseCatalogEntity c11 = new CourseCatalogEntity();
                c11.setCode("EE211");
                c11.setName("Electrical Circuits");
                c11.setDifficultyRating(4.0);
                c11.setRatingCount(100);

                CourseCatalogEntity c12 = new CourseCatalogEntity();
                c12.setCode("HUM103");
                c12.setName("Humanities");
                c12.setDifficultyRating(4.0);
                c12.setRatingCount(100);

                CourseCatalogEntity c13 = new CourseCatalogEntity();
                c13.setCode("MATH221");
                c13.setName("Linear Algebra");
                c13.setDifficultyRating(4.0);
                c13.setRatingCount(100);

                CourseCatalogEntity c14 = new CourseCatalogEntity();
                c14.setCode("CSE212");
                c14.setName("Software Development Methodologies");
                c14.setDifficultyRating(4.0);
                c14.setRatingCount(100);

                CourseCatalogEntity c15 = new CourseCatalogEntity();
                c15.setCode("CSE224");
                c15.setName("Introduction to Digital Systems");
                c15.setDifficultyRating(4.0);
                c15.setRatingCount(100);

                CourseCatalogEntity c16 = new CourseCatalogEntity();
                c16.setCode("CSE232");
                c16.setName("Systems Programming");
                c16.setDifficultyRating(4.0);
                c16.setRatingCount(100);

                CourseCatalogEntity c17 = new CourseCatalogEntity();
                c17.setCode("MATH241");
                c17.setName("Differential Equations");
                c17.setDifficultyRating(4.0);
                c17.setRatingCount(100);

                CourseCatalogEntity c18 = new CourseCatalogEntity();
                c18.setCode("MATH281");
                c18.setName("Probability");
                c18.setDifficultyRating(4.0);
                c18.setRatingCount(100);

                CourseCatalogEntity c19 = new CourseCatalogEntity();
                c19.setCode("CSE311");
                c19.setName("Analysis Of Algorithms");
                c19.setDifficultyRating(4.0);
                c19.setRatingCount(100);

                CourseCatalogEntity c20 = new CourseCatalogEntity();
                c20.setCode("CSE323");
                c20.setName("Computer Organization");
                c20.setDifficultyRating(4.0);
                c20.setRatingCount(100);

                CourseCatalogEntity c21 = new CourseCatalogEntity();
                c21.setCode("ES224");
                c21.setName("File Organization");
                c21.setDifficultyRating(4.0);
                c21.setRatingCount(100);

                CourseCatalogEntity c22 = new CourseCatalogEntity();
                c22.setCode("CSE351");
                c22.setName("Programming Languages");
                c22.setDifficultyRating(4.0);
                c22.setRatingCount(100);

                CourseCatalogEntity c23 = new CourseCatalogEntity();
                c23.setCode("ES224");
                c23.setName("Signals and Systems");
                c23.setDifficultyRating(4.0);
                c23.setRatingCount(100);

                CourseCatalogEntity c24 = new CourseCatalogEntity();
                c24.setCode("HTR301");
                c24.setName("History of Turkish Revolution I");
                c24.setDifficultyRating(4.0);
                c24.setRatingCount(100);

                CourseCatalogEntity c25 = new CourseCatalogEntity();
                c25.setCode("CSE331");
                c25.setName("Operating Systems Design");
                c25.setDifficultyRating(4.0);
                c25.setRatingCount(100);

                CourseCatalogEntity c26 = new CourseCatalogEntity();
                c26.setCode("CSE344");
                c26.setName("Software Engineering");
                c26.setDifficultyRating(4.0);
                c26.setRatingCount(100);

                CourseCatalogEntity c27 = new CourseCatalogEntity();
                c27.setCode("CSE348");
                c27.setName("Database Management Systems");
                c27.setDifficultyRating(4.0);
                c27.setRatingCount(100);

                CourseCatalogEntity c28 = new CourseCatalogEntity();
                c28.setCode("CSE354");
                c28.setName("Automata Theory & Formal Languages");
                c28.setDifficultyRating(4.0);
                c28.setRatingCount(100);

                CourseCatalogEntity c29 = new CourseCatalogEntity();
                c29.setCode("HTR302");
                c29.setName("History of Turkish Revolution II");
                c29.setDifficultyRating(4.0);
                c29.setRatingCount(100);

                CourseCatalogEntity c30 = new CourseCatalogEntity();
                c30.setCode("CSE400");
                c30.setName("Summer Practice");
                c30.setDifficultyRating(4.0);
                c30.setRatingCount(100);

                CourseCatalogEntity c31 = new CourseCatalogEntity();
                c31.setCode("CSE471");
                c31.setName("Data Communications & Computer Networks");
                c31.setDifficultyRating(4.0);
                c31.setRatingCount(100);

                CourseCatalogEntity c32 = new CourseCatalogEntity();
                c32.setCode("CSE492");
                c32.setName("Engineering Project");
                c32.setDifficultyRating(4.0);
                c32.setRatingCount(100);

                courseRepository.saveAll(List.of(c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31, c32));
            }

            if (userRepository.count() == 0) {
                // 1. Create Fake Users
                UserAccount alice = new UserAccount();
                alice.setName("Alice Smith");
                alice.setNickname("Alice");
                alice.setEmail("alice.student@std.yeditepe.edu.tr");
                alice.setPasswordHash(passwordEncoder.encode("Password123!"));
                alice.setDepartmentId("cse");
                alice.setYear(3);
                alice.setResponsibilityScore(95);
                alice.setEnrolledCourses(new java.util.ArrayList<>(List.of("CSE344", "CSE331", "CSE312", "MATH301")));

                UserAccount bob = new UserAccount();
                bob.setName("Bob Jones");
                bob.setNickname("Bobby");
                bob.setEmail("bob.student@std.yeditepe.edu.tr");
                bob.setPasswordHash(passwordEncoder.encode("Password123!"));
                bob.setDepartmentId("ie");
                bob.setYear(2);
                bob.setResponsibilityScore(88);
                bob.setEnrolledCourses(new java.util.ArrayList<>(List.of("GBE113", "MATH131", "PHYS101")));

                UserAccount charlie = new UserAccount();
                charlie.setName("Charlie Brown");
                charlie.setNickname("Chuck");
                charlie.setEmail("charlie.student@std.yeditepe.edu.tr");
                charlie.setPasswordHash(passwordEncoder.encode("Password123!"));
                charlie.setDepartmentId("math");
                charlie.setYear(4);
                charlie.setResponsibilityScore(72);
                charlie.setEnrolledCourses(new java.util.ArrayList<>(List.of("MATH221", "MATH241", "MATH281")));

                userRepository.saveAll(List.of(alice, bob, charlie));

            }
        };
    }
}
