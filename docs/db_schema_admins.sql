-- PostgreSQL Schema for StudySync Admin Accounts
-- Neon DB: studysync_db
-- Active Host: neon-postgres-prod.gcp.neon.tech

-- Drop table if exists (optional, safely recreate)
-- DROP TABLE IF EXISTS admins CASCADE;

-- 1. Create admins table
CREATE TABLE IF NOT EXISTS admins (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL, -- Stored as clear-text or BCrypt hash depending on the backend integration setup.
    display_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) DEFAULT 'STAFF_ADMIN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookup on login email
CREATE INDEX IF NOT EXISTS idx_admins_email ON admins(email);

-- 2. Populate the table with the active study team admin accounts
-- Note: Display names are capitalized local parts of the emails to match the mobile client's formatting logic.
INSERT INTO admins (email, password_hash, display_name, role) VALUES
('oykuaksungur@yeditepe.edu.tr', 'Admin123!oa', 'Oykuaksungur', 'STAFF_ADMIN'),
('emreunuvar@yeditepe.edu.tr', 'Admin123!eu', 'Emreunuvar', 'STAFF_ADMIN'),
('efekasapoglu@yeditepe.edu.tr', 'Admin123!ek', 'Efekasapoglu', 'STAFF_ADMIN'),
('emrebardak@yeditepe.edu.tr', 'Admin123!eb', 'Emrebardak', 'STAFF_ADMIN'),
('nazyunusoglu@yeditepe.edu.tr', 'Admin123!ny', 'Nazyunusoglu', 'STAFF_ADMIN'),
('gulcecelik@yeditepe.edu.tr', 'Admin123!gc', 'Gulcecelik', 'STAFF_ADMIN'),
('melisatokatli@yeditepe.edu.tr', 'Admin123!mt', 'Melisatokatli', 'STAFF_ADMIN'),
('admin@yeditepe.edu.tr', 'Admin123!', 'Admin', 'SUPER_ADMIN')
ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    display_name = EXCLUDED.display_name,
    updated_at = CURRENT_TIMESTAMP;

-- Verification query
-- SELECT * FROM admins;
