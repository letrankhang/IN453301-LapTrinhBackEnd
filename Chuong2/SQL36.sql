CREATE TABLE members (
id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
full_name VARCHAR(100) NOT NULL,
email VARCHAR(150) NOT NULL UNIQUE,
joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE courses (
id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
title VARCHAR(200) NOT NULL,
capacity INT NOT NULL CHECK (capacity > 0)
);

CREATE TABLE registrations (
id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
member_id INT NOT NULL REFERENCES members(id),
course_id INT NOT NULL REFERENCES courses(id),
status VARCHAR(20) NOT NULL DEFAULT 'pending',
registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
UNIQUE (member_id, course_id)
);
CREATE INDEX ix_reg_course ON registrations (course_id);


INSERT INTO members (full_name, email) VALUES
('Nguyễn An', 'an@dthu.edu.vn'),
('Trần Bình', 'binh@dthu.edu.vn'),
('Lê Chi', 'chi@dthu.edu.vn');
INSERT INTO courses (title, capacity) VALUES
('Lập trình Web', 2), ('Cơ sở dữ liệu', 40);
INSERT INTO registrations (member_id, course_id)
VALUES (1, 1), (1, 2), (2, 1);

--cau1--
SELECT c.title
FROM members m
JOIN registrations r ON m.id = r.member_id
JOIN courses c ON r.course_id = c.id
WHERE m.full_name = 'Nguyễn An';


--cau2--
SELECT
    c.id,
    c.title,
    COUNT(r.member_id) AS so_thanh_vien
FROM courses c
LEFT JOIN registrations r ON c.id = r.course_id
GROUP BY c.id, c.title
ORDER BY COUNT(r.member_id) DESC;

--cau3--
BEGIN;

INSERT INTO registrations (member_id, course_id)
SELECT m.id, c.id
FROM members m
CROSS JOIN courses c
WHERE m.full_name = 'Lê Chi'
  AND c.title = 'Cơ sở dữ liệu';

COMMIT;

SELECT
    m.full_name,
    c.title,
    r.status,
    r.registered_at
FROM registrations r
JOIN members m ON r.member_id = m.id
JOIN courses c ON r.course_id = c.id
WHERE m.full_name = 'Lê Chi'
  AND c.title = 'Cơ sở dữ liệu';