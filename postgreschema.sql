-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop tables (order matters)
DROP TABLE IF EXISTS ChatMemoryLog CASCADE;
DROP TABLE IF EXISTS ProgressTracking CASCADE;
DROP TABLE IF EXISTS Content CASCADE;
DROP TABLE IF EXISTS Users CASCADE;

-- Users: basic login (email, pass, name, role)
CREATE TABLE Users (
    UserId SERIAL PRIMARY KEY,
    Email VARCHAR(255) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    FullName VARCHAR(255) NOT NULL,
    Role VARCHAR(50) NOT NULL, -- Teacher, Parent, Tutor, Student
    CreatedAt TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Content: assignments, videos, etc.
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
    Status VARCHAR(50) NOT NULL, -- 'Not Started', 'In Progress', 'Completed'
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

-- Trigger function: keep each convo's logs <= 30 entries
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

-- Trigger on ChatMemoryLog AFTER INSERT
CREATE TRIGGER limit_memory_log_trigger
AFTER INSERT ON ChatMemoryLog
FOR EACH ROW EXECUTE FUNCTION limit_memory_log_fn();

-- Sample Users
-- Teachers
INSERT INTO Users (Email, PasswordHash, FullName, Role) VALUES
('teacher1@example.com','hashed123','Alice Johnson','Teacher'),
('teacher2@example.com','hashed234','David King','Teacher'),
('teacher3@example.com','hashed345','Emma Williams','Teacher');
-- Parents
INSERT INTO Users (Email, PasswordHash, FullName, Role) VALUES
('parent1@example.com','hashed456','Bob Smith','Parent'),
('parent2@example.com','hashed567','Sarah Miller','Parent'),
('parent3@example.com','hashed678','Michael Brown','Parent');
-- Tutors
INSERT INTO Users (Email, PasswordHash, FullName, Role) VALUES
('tutor1@example.com','hashed789','Carol Davis','Tutor'),
('tutor2@example.com','hashed890','James Wilson','Tutor');
-- Students
INSERT INTO Users (Email, PasswordHash, FullName, Role) VALUES
('student1@example.com','hashedabc','Lucy Thompson','Student'),
('student2@example.com','hashedbcd','Mark Johnson','Student'),
('student3@example.com','hashedcde','Emily Davis','Student'),
('student4@example.com','hasheddef','Oliver Martinez','Student');

-- Sample Content (created by Teacher Alice, assumed UserId = 1)
INSERT INTO Content (Title, Description, ContentUrl, CreatedBy) VALUES
('Math Homework - Fractions','Practice fractions for grade 5.','https://example.com/math-fractions',1),
('Science Video: Solar System','Intro video on planets.','https://example.com/solar-system',1);

-- Sample Progress Tracking (using Parent Bob [UserId=4] & Student Lucy [UserId=9])
INSERT INTO ProgressTracking (UserId, ContentId, Status) VALUES
(4, 1, 'Completed'),
(9, 1, 'In Progress'),
(9, 2, 'Not Started');

-- Sample AI Memory Logs with realistic convo snippets.
-- Each INSERT uses a new ConversationId (for demo, you can set these explicitly if needed)
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog) VALUES
(1, uuid_generate_v4(), 'Alice: "Summarize assignment submissions." | AI: "Class average is 87%."');
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog) VALUES
(4, uuid_generate_v4(), 'Bob: "How is Lucy doing in math?" | AI: "Lucy has 70% completion on fractions."');
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog) VALUES
(7, uuid_generate_v4(), 'Carol: "Need extra practice ideas for Lucy." | AI: "Recommend worksheets and video tutorials."');
INSERT INTO ChatMemoryLog (UserId, ConversationId, MemoryLog) VALUES
(9, uuid_generate_v4(), 'Lucy: "I don''t understand fractions. Help!" | AI: "Let''s work through an example step-by-step."');

SELECT 'PostgreSQL DB setup complete with sample data.' AS Message;
