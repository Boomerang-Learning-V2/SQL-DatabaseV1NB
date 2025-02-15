-- DROP existing objects (order matters)
IF OBJECT_ID('dbo.ChatMemoryLog', 'U') IS NOT NULL DROP TABLE dbo.ChatMemoryLog;
IF OBJECT_ID('dbo.ProgressTracking', 'U') IS NOT NULL DROP TABLE dbo.ProgressTracking;
IF OBJECT_ID('dbo.Content', 'U') IS NOT NULL DROP TABLE dbo.Content;
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DROP TABLE dbo.Users;

-- Users: basic login (email, hashed pass, full name, role)
CREATE TABLE dbo.Users (
    UserId INT IDENTITY(1,1) PRIMARY KEY,
    Email NVARCHAR(255) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    FullName NVARCHAR(255) NOT NULL,
    Role NVARCHAR(50) NOT NULL, -- Teacher, Parent, Tutor, Student
    CreatedAt DATETIME2 DEFAULT GETUTCDATE() NOT NULL
);

-- Content: assignments, vids, etc.
CREATE TABLE dbo.Content (
    ContentId INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(255) NOT NULL,
    Description NVARCHAR(MAX),
    ContentUrl NVARCHAR(500),
    CreatedBy INT NOT NULL, -- FK to Users
    CreatedAt DATETIME2 DEFAULT GETUTCDATE() NOT NULL,
    CONSTRAINT FK_Content_User FOREIGN KEY (CreatedBy) REFERENCES dbo.Users(UserId)
);

-- Progress: logs user progress on content
CREATE TABLE dbo.ProgressTracking (
    ProgressId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,   -- FK to Users
    ContentId INT NOT NULL, -- FK to Content
    Status NVARCHAR(50) NOT NULL, -- Not Started, In Progress, Completed
    LastUpdated DATETIME2 DEFAULT GETUTCDATE() NOT NULL,
    CONSTRAINT FK_Progress_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_Progress_Content FOREIGN KEY (ContentId) REFERENCES dbo.Content(ContentId)
);

-- ChatMemoryLog: for AI convo logs; each convo is grouped by ConversationId
CREATE TABLE dbo.ChatMemoryLog (
    LogId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL, -- FK to Users
    ConversationId UNIQUEIDENTIFIER DEFAULT NEWID() NOT NULL,
    MemoryLog NVARCHAR(MAX) NOT NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE() NOT NULL,
    CONSTRAINT FK_ChatMemory_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
);

-- Trigger: Keep each convo's logs <= 30 entries (oldest auto-delete)
CREATE TRIGGER trg_LimitMemoryLog ON dbo.ChatMemoryLog
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ConvId UNIQUEIDENTIFIER;
    
    -- Process each distinct conversation from inserted rows
    DECLARE conv_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT ConversationId FROM inserted;
    OPEN conv_cursor;
    FETCH NEXT FROM conv_cursor INTO @ConvId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        ;WITH CTE AS (
            SELECT LogId,
                   ROW_NUMBER() OVER (ORDER BY CreatedAt ASC) AS RN,
                   COUNT(*) OVER () AS TotalCount
            FROM dbo.ChatMemoryLog
            WHERE ConversationId = @ConvId
        )
        DELETE FROM dbo.ChatMemoryLog
        WHERE LogId IN (
            SELECT LogId FROM CTE WHERE TotalCount > 30 AND RN <= (TotalCount - 30)
        );
        FETCH NEXT FROM conv_cursor INTO @ConvId;
    END;
    CLOSE conv_cursor;
    DEALLOCATE conv_cursor;
END;
GO

-- Insert sample users (hashed pass are dummy strings)
-- Teachers
INSERT INTO dbo.Users (Email, PasswordHash, FullName, Role)
VALUES
('teacher1@example.com','hashed123','Alice Johnson','Teacher'),
('teacher2@example.com','hashed234','David King','Teacher'),
('teacher3@example.com','hashed345','Emma Williams','Teacher');

-- Parents
INSERT INTO dbo.Users (Email, PasswordHash, FullName, Role)
VALUES
('parent1@example.com','hashed456','Bob Smith','Parent'),
('parent2@example.com','hashed567','Sarah Miller','Parent'),
('parent3@example.com','hashed678','Michael Brown','Parent');

-- Tutors
INSERT INTO dbo.Users (Email, PasswordHash, FullName, Role)
VALUES
('tutor1@example.com','hashed789','Carol Davis','Tutor'),
('tutor2@example.com','hashed890','James Wilson','Tutor');

-- Students
INSERT INTO dbo.Users (Email, PasswordHash, FullName, Role)
VALUES
('student1@example.com','hashedabc','Lucy Thompson','Student'),
('student2@example.com','hashedbcd','Mark Johnson','Student'),
('student3@example.com','hashedcde','Emily Davis','Student'),
('student4@example.com','hasheddef','Oliver Martinez','Student');

-- Insert sample content (assume created by Teacher Alice, UserId = 1)
INSERT INTO dbo.Content (Title, Description, ContentUrl, CreatedBy)
VALUES
('Math Homework - Fractions','Practice fractions problems for grade 5.','https://example.com/math-fractions',1),
('Science Video: Solar System','Intro video on planets and orbits.','https://example.com/solar-system',1);

-- Insert sample progress (for Parent Bob (UserId=4) and Student Lucy (UserId=7))
INSERT INTO dbo.ProgressTracking (UserId, ContentId, Status)
VALUES
(4, 1, 'Completed'),
(7, 1, 'In Progress'),
(7, 2, 'Not Started');

-- Insert sample AI memory logs with realistic convo snippets
-- Teacher convo
INSERT INTO dbo.ChatMemoryLog (UserId, MemoryLog, ConversationId)
VALUES
(1, 'Alice: "Need a summary of assignment submissions." | AI: "Class average is 87%."', NEWID());
-- Parent convo
INSERT INTO dbo.ChatMemoryLog (UserId, MemoryLog, ConversationId)
VALUES
(4, 'Bob: "How is Lucy doing in math?" | AI: "Lucy is progressing; 70% on fractions."', NEWID());
-- Tutor convo
INSERT INTO dbo.ChatMemoryLog (UserId, MemoryLog, ConversationId)
VALUES
(7, 'Carol: "Suggest extra practice for Lucy." | AI: "Recommend worksheets and video tutorials."', NEWID());
-- Student convo
INSERT INTO dbo.ChatMemoryLog (UserId, MemoryLog, ConversationId)
VALUES
(7, 'Lucy: "I don''t get fractions. Help?" | AI: "Let''s break it down step-by-step."', NEWID());

SELECT 'DB setup complete with sample data.' AS Message;
