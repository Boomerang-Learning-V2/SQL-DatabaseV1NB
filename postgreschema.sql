-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop tables in order (due to FK dependencies)
DROP TABLE IF EXISTS ChatMemoryLog CASCADE;
DROP TABLE IF EXISTS ProgressTracking CASCADE;
DROP TABLE IF EXISTS Content CASCADE;
DROP TABLE IF EXISTS Students CASCADE;
DROP TABLE IF EXISTS Users CASCADE;

-- Users: basic login info (email, username, pass, first/last, role)
CREATE TABLE Users (
    UserId SERIAL PRIMARY KEY,
    Email VARCHAR(255) NOT NULL UNIQUE,
    Username VARCHAR(100) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    FirstName VARCHAR(100) NOT NULL,
    LastName VARCHAR(100) NOT NULL,
    Role VARCHAR(50) NOT NULL, -- Teacher, Parent, Tutor, Student
    CreatedAt TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Students: student-specific properties; FK to Users
CREATE TABLE Students (
    StudentId SERIAL PRIMARY KEY,
    UserId INT NOT NULL UNIQUE REFERENCES Users(UserId) ON DELETE CASCADE,
    Grade VARCHAR(10), -- e.g., '5', '6', etc.
    DateOfBirth DATE
);

-- Content: assignments, vids, etc.
CREATE TABLE Content (
    ContentId SERIAL PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    Description TEXT,
    ContentUrl VARCHAR(500),
    CreatedBy INT NOT NULL REFERENCES Users(UserId),
    CreatedAt TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Progress: logs user progress on content
CREATE TABLE ProgressTracking (
    ProgressId SERIAL PRIMARY KEY,
    UserId INT NOT NULL REFERENCES Users(UserId),
    ContentId INT NOT NULL REFERENCES Content(ContentId),
    Status VARCHAR(50) NOT NULL, -- 'Not Started','In Progress','Completed'
    LastUpdated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- ChatMemoryLog: for AI convo logs
CREATE TABLE ChatMemoryLog (
    LogId SERIAL PRIMARY KEY,
    UserId INT NOT NULL REFERENCES Users(UserId),
    ConversationId UUID DEFAULT uuid_generate_v4() NOT NULL,
    MemoryLog TEXT NOT NULL,
    CreatedAt TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Trigger func: limit logs per convo to 30 entries (oldest auto-delete)
CREATE OR REPLACE FUNCTION limit_memory_log_fn() 
RETURNS trigger AS $$
DECLARE
    total_count INT;
BEGIN
    SELECT COUNT(*) INTO total_count FROM ChatMemoryLog 
      WHERE ConversationId = NEW.ConversationId;
    IF total_count > 30 THEN
        DELETE FROM ChatMemoryLog
         WHERE LogId IN (
             SELECT LogId FROM ChatMemoryLog
             WHERE ConversationId = NEW.ConversationId
             ORDER BY CreatedAt ASC
             LIMIT (total_count - 30)
         );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER limit_memory_log_trigger
AFTER INSERT ON ChatMemoryLog
FOR EACH ROW EXECUTE FUNCTION limit_memory_log_fn();

-- Sample Users
-- Teachers
INSERT INTO Users (Email, Username, PasswordHash, FirstName, LastName, Role)
VALUES
('teacher1@example.com','teacher1','hashed123','Alice','Johnson','Teacher'),
('teacher2@example.com','teacher2','hashed234','David','King','Teacher'),
('teacher3@example.com','teacher3','hashed345','Emma','Williams','Teacher');

-- Parents
INSERT INTO Users (Email, Username, PasswordHash, FirstName, LastName, Role)
VALUES
('parent1@example.com','parent1','hashed456','Bob','Smith','Parent'),
('parent2@example.com','parent2','hashed567','Sarah','Miller','Parent'),
('parent3@example.com','parent3','hashed678','Michael','Brown','Parent');

-- Tutors
INSERT INTO Users (Email, Username, PasswordHash, FirstName, LastName, Role)
VALUES
('tutor1@example.com','tutor1','hashed789','Carol','Davis','Tutor'),
('tutor2@example.com','tutor2','hashed890','James','Wilson','Tutor');

-- Students (insert Users first, then add student-specific data)
INSERT INTO Users (Email, Username, PasswordHash, FirstName, LastName, Role)
VALUES
('student1@example.com','student1','hashedabc','Lucy','Thompson','Student'),
('student2@example.com','student2','hashedbcd','Mark','Johnson','Student'),
('student3@example.com','student3','hashedcde','Emily','Davis','Student'),
('student4@example.com','student4','hasheddef','Oliver','Martinez','Student');

-- Link student records (assume UserIds 10-13 for students in order of insertion)
INSERT INTO Students (UserId, Grade, DateOfBirth) VALUES
(10, '5', '2010-03-15'),
(11, '6', '2009-07-22'),
(12, '5', '2010-11-05'),
(13, '7', '2008-09-30');

-- Sample Content (created by Teacher Alice, assumed UserId = 1)
INSERT INTO Content (Title, Description, ContentUrl, CreatedBy)
VALUES
('Math Homework - Fractions','Practice fractions for grade 5.','https://example.com/math-fractions',1),
('Science Video: Solar System','Intro video on planets.','https://example.com/solar-system',1);

-- Sample Progress (for Parent Bob [UserId=4] & Student Lucy [UserId=10])
INSERT INTO ProgressTracking (UserId, ContentId, Status)
VALUES
(4, 1, 'Completed'),
(10, 1, 'In Progress'),
(10, 2, 'Not Started');

-- Sample AI Memory Logs with realistic convo snippets.
-- Teacher convo
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog)
VALUES
(1, uuid_generate_v4(), 'Alice: "Summarize assignment submissions." | AI: "Class average is 87%."');
-- Parent convo
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog)
VALUES
(4, uuid_generate_v4(), 'Bob: "How is Lucy doing in math?" | AI: "Lucy has 70% completion on fractions."');
-- Tutor convo
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog)
VALUES
(7, uuid_generate_v4(), 'Carol: "Need extra practice ideas for Lucy." | AI: "Recommend worksheets and video tutorials."');
-- Student convo
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog)
VALUES
(10, uuid_generate_v4(), 'Lucy: "I don''t understand fractions. Help!" | AI: "Let''s work through an example step-by-step."');

SELECT 'PostgreSQL DB setup complete with sample data.' AS Message;
