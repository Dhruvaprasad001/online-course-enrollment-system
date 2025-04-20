CREATE DATABASE online_course_enrolement_system;
USE  online_course_enrolement_system;

CREATE TABLE students (
	student_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    age INT CHECK(age>=13),
    registration_date DATETIME DEFAULT CURRENT_TIMESTAMP  
);

CREATE TABLE courses (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL,
    price DECIMAL NOT NULL,
    rating FLOAT CHECK (rating BETWEEN 0 AND 5),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    student_count INT DEFAULT 0
);

CREATE TABLE instructors  (
	instructor_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL ,
    email VARCHAR(100) NOT NULL UNIQUE,
    expertise VARCHAR(100) ,
    assigned_course_id INT ,
    FOREIGN KEY (assigned_course_id) REFERENCES courses(course_id)
);

CREATE TABLE enrollments (
	student_id INT ,
    course_id INT ,
    enrolled_on DATETIME DEFAULT CURRENT_TIMESTAMP ,
    progress INT CHECK (progress BETWEEN 0 AND 10),
    PRIMARY KEY (student_id , course_id),
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id) REFERENCES courses(course_id)
);

#So this helps with incrementing the value of the number of students enrolled into the course once added 
DELIMITER //
	CREATE TRIGGER increment_student_count 
	AFTER INSERT ON enrollments
    FOR EACH ROW 
    BEGIN 
		UPDATE courses
        SET student_count = student_count + 1
        WHERE course_id = NEW.course_id; 
	END;
// DELIMITER ;

#So this helps with decrementing the number of students when the record is deleted 
DELIMITER //
	CREATE TRIGGER decrement_student_count
    AFTER DELETE ON enrollments
    FOR EACH ROW 
    BEGIN 
		UPDATE courses
        SET student_count = student_count - 1 
        WHERE course_id = OLD.course_id;
    END;
// DELIMITER ;

#This is to throw an alter when ever the user tries to delete the course when there is still students enrolled to the course
DELIMITER //
	CREATE TRIGGER prevent_course_deletion_with_students
    BEFORE DELETE ON courses
    FOR EACH ROW 
    BEGIN
		IF OLD.student_count > 0 THEN 
         SIGNAL SQLSTATE '45000'
         SET MESSAGE_TEXT = 'Cannot delete the course when there is still a student registered in the course';
		END IF;
    END;
// DELIMITER ;
 

INSERT INTO students (name, email, age)
VALUES
('Chirag', 'chirag@example.com', 21),
('Dhruva', 'dhruva@example.com', 20),
('Disha', 'disha@example.com', 19),
('Diya', 'diya@example.com', 18),
('Shashi' , 'shashi@gmail.com' , 25 ),
('Rohan', 'rohan@example.com', 22),
('Daksh', 'daksh@example.com', 23),
('Akshath', 'akshath@example.com', 20),
('Chakresh', 'chakresh@example.com', 21),
('Bhaskar', 'bhaskar@example.com', 22),
('Alok', 'alok@example.com', 19),
('Aaditya', 'aaditya@example.com', 20),
('Eshwar', 'eshwar@example.com', 18),
('Vaibhavi', 'vaibhavi@example.com', 19);

INSERT INTO courses (title, category, price, rating)
VALUES
('Introduction to Python', 'Programming', 1499.00, 4.5),
('Web Development with React', 'Programming', 1999.00, 4.7),
('Digital Marketing Basics', 'Marketing', 999.00, 4.3),
('UI/UX Design Fundamentals', 'Design', 1299.00, 4.2),
('Data Structures in C++', 'Programming', 1599.00, 4.6),
('Photography Masterclass', 'Creative Arts', 1099.00, 4.4),
('Financial Literacy 101', 'Finance', 899.00, 4.1),
('Public Speaking Essentials', 'Communication', 799.00, 4.0);

INSERT INTO instructors (name, email, expertise, assigned_course_id)
VALUES
('Amit Sharma', 'amit.sharma@example.com', 'Python & Automation', 1),
('Neha Rao', 'neha.rao@example.com', 'Frontend Development', 2),
('Suresh Kumar', 'suresh.k@example.com', 'Digital Marketing', 3),
('Priya Nair', 'priya.nair@example.com', 'UX Design', 4),
('Rahul Verma', 'rahul.verma@example.com', 'Algorithms & C++', 5),
('Kavita Joshi', 'kavita.joshi@example.com', 'Photography', 6),
('Anil Mehta', 'anil.mehta@example.com', 'Finance & Budgeting', 7),
('Sneha Iyer', 'sneha.iyer@example.com', 'Soft Skills', 8);

INSERT INTO enrollments (student_id, course_id, progress)
VALUES
(1, 1, 5),
(2, 2, 7),
(3, 1, 3),
(4, 3, 6),
(5, 4, 2),
(6, 5, 8),
(7, 6, 9),
(8, 7, 4),
(9, 8, 6),
(10, 2, 10),
(11, 4, 7),
(12, 3, 1),
(13, 5, 5);

SELECT * FROM students;
SELECT * FROM courses;
SELECT * FROM instructors;
SELECT * FROM enrollments;

#on views
CREATE VIEW student_course_progress AS
SELECT s.name AS student_name, c.title AS course_title, e.progress
FROM enrollments e
JOIN students s ON e.student_id = s.student_id
JOIN courses c ON e.course_id = c.course_id;

SELECT * FROM student_course_progress;

# to get what instructor is teaching what course and how many students have enrolled in it
CREATE VIEW instructor_course_student_mapping AS
SELECT 
    i.name AS instructor_name,
    c.title AS course_title,
    COUNT(e.student_id) AS enrolled_students
FROM instructors i
JOIN courses c ON i.assigned_course_id = c.course_id
LEFT JOIN enrollments e ON c.course_id = e.course_id
GROUP BY i.name, c.title;

SELECT * FROM instructor_course_student_mapping;

#using window functions here 
WITH ranked_enrollments AS (
  SELECT 
    e.student_id,
    e.course_id,
    e.progress,
    DENSE_RANK() OVER (ORDER BY e.progress DESC) AS course_rank
  FROM enrollments e
)
SELECT 
  s.name AS student_name, 
  c.title AS course_title, 
  r.progress, 
  r.course_rank
FROM ranked_enrollments r
JOIN students s ON r.student_id = s.student_id
JOIN courses c ON r.course_id = c.course_id;

/*
Stored procedures to automatically add a students record into enrolment 
sets progress to 0 , uses the increment_student_count  trigger	automatically , inputs are student_id and couse_id
*/
DELIMITER //
	CREATE PROCEDURE EnrollStudents (
		IN s_id INT ,
        IN c_id INT
    )
    BEGIN 
		IF EXISTS (
			SELECT 1 FROM enrollments
            WHERE student_id = s_id AND course_id = c_id
        )THEN 
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = "student already exists here";
		ELSE 
			INSERT INTO enrollments (student_id , course_id ,progress)
            VALUES (s_id, c_id , 0); 
		END IF;	
    END;
// DELIMITER ;

INSERT INTO students (name, email, age)
VALUES ("Madhav" , "madhav@gmal.com" , 24);

#Calling the stored procedures with student id and course id
CALL EnrollStudents(15, 4);

#Creating a stored procedure to get all the courses a student is enrolled into , wrapping select into a procedure ..
DELIMITER //
	CREATE PROCEDURE CoursesEnrolled(
		IN s_id INT 
    )
    BEGIN
		SELECT c.title, c.category, c.rating , e.progress
        FROM enrollments e
        JOIN courses c ON e.course_id = c.course_id
        WHERE e.student_id = s_id;
	END;
// DELIMITER ;

#Calling the stored procedures with student id
CALL CoursesEnrolled(1);

#Using CTEs to get average  progress per course 
WITH progress_avg AS (
	SELECT course_id , AVG(progress) AS avg_progress
    FROM enrollments
    GROUP BY course_id 
)
SELECT c.title , p.avg_progress
FROM courses AS c 
JOIN progress_avg AS p ON c.course_id = p.course_id ;

#Creating indexes on email in students for faster retreival 
CREATE INDEX idx_email ON students(email);

EXPLAIN SELECT 1 FROM students 
WHERE email = "dhruva@example.com";