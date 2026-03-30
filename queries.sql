-- queries.sql — SQL Analytics Lab
-- Module 3: SQL & Relational Data
--
-- Instructions:
--   Write your SQL query beneath each comment block.
--   Do NOT modify the comment markers (-- Q1, -- Q2, etc.) — the autograder uses them.
--   Test each query locally: psql -h localhost -U postgres -d testdb -f queries.sql
--
-- ============================================================

-- Q1: Employee Directory with Departments
-- List all employees with their department name, sorted by department (asc) then salary (desc).
-- Expected columns: first_name, last_name, title, salary, department_name
-- SQL concepts: JOIN, ORDER BY

SELECT e.email, e.salary, d.name AS department_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
ORDER BY d.name ASC, e.salary DESC;


-- Q2: Department Salary Analysis
-- Total salary expenditure by department. Only departments with total > 150,000.
-- Expected columns: department_name, total_salary
-- SQL concepts: GROUP BY, HAVING, SUM


SELECT d.name AS department_name, SUM(e.salary) AS total_salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.name
HAVING SUM(e.salary) > 150000;


-- Q3: Highest-Paid Employee per Department
-- For each department, find the employee with the highest salary.
-- Expected columns: department_name, first_name, last_name, salary
-- SQL concepts: Window function (ROW_NUMBER or RANK), CTE


SELECT email, department_name, salary
FROM (
    SELECT e.email, d.name AS department_name, e.salary,
           ROW_NUMBER() OVER (PARTITION BY d.department_id ORDER BY e.salary DESC) AS rn
    FROM employees e
    JOIN departments d ON e.department_id = d.department_id
) sub
WHERE rn = 1;


-- Q4: Project Staffing Overview
-- All projects with employee count and total hours. Include projects with 0 assignments.
-- Expected columns: project_name, employee_count, total_hours
-- SQL concepts: LEFT JOIN, GROUP BY, COALESCE
-- Q4: Project Staffing Overview
-- All projects with employee count and total hours. Include projects with 0 assignments

SELECT p.name AS project_name,
       COUNT(pa.employee_id) AS employee_count,
       COALESCE(SUM(pa.hours_allocated), 0) AS total_hours
FROM projects p
LEFT JOIN project_assignments pa ON p.project_id = pa.project_id
GROUP BY p.name;

-- Q5: Above-Average Departments
-- Departments where average salary exceeds the company-wide average salary.
-- Expected columns: department_name, avg_salary
-- SQL concepts: CTE

WITH company_avg AS (
    SELECT AVG(salary) AS avg_salary FROM employees
)
SELECT d.name AS department_name,
       AVG(e.salary) AS dept_avg,
       (SELECT avg_salary FROM company_avg) AS company_avg
FROM employees e
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.name
HAVING AVG(e.salary) > (SELECT avg_salary FROM company_avg);


-- Q6: Running Salary Total
-- Each employee's salary and running total within their department, ordered by hire date.
-- Expected columns: department_name, first_name, last_name, hire_date, salary, running_total
-- SQL concepts: Window function (SUM OVER)

SELECT e.email,
       e.salary,
       SUM(e.salary) OVER (
           PARTITION BY e.department_id
           ORDER BY e.hire_date
       ) AS running_total
FROM employees e;


-- Q7: Unassigned Employees
-- Employees not assigned to any project.
-- Expected columns: first_name, last_name, department_name
-- SQL concepts: LEFT JOIN + NULL check (or NOT EXISTS)

SELECT e.email
FROM employees e
LEFT JOIN project_assignments pa ON e.employee_id = pa.employee_id
WHERE pa.employee_id IS NULL;


-- Q8: Hiring Trends
-- Month-over-month hire count.
-- Expected columns: hire_year, hire_month, hires
-- SQL concepts: EXTRACT, GROUP BY, ORDER BY


SELECT
    EXTRACT(YEAR FROM hire_date) AS hire_year,
    EXTRACT(MONTH FROM hire_date) AS hire_month,
    COUNT(*) AS hires
FROM employees
GROUP BY hire_year, hire_month
ORDER BY hire_year, hire_month;


-- Q9: Schema Design — Employee Certifications
-- Design and implement a certifications tracking system.
--
-- Tasks:
-- 1. CREATE TABLE certifications (certification_id SERIAL PK, name VARCHAR NOT NULL, issuing_org VARCHAR, level VARCHAR)
-- 2. CREATE TABLE employee_certifications (id SERIAL PK, employee_id FK->employees, certification_id FK->certifications, certification_date DATE NOT NULL)
-- 3. INSERT at least 3 certifications and 5 employee_certification records
-- 4. Write a query listing employees with their certifications (JOIN across 3 tables)
--    Expected columns: first_name, last_name, certification_name, issuing_org, certification_date


CREATE TABLE IF NOT EXISTS certifications (
    certification_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    issuing_org VARCHAR(100),
    level VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS employee_certifications (
    id SERIAL PRIMARY KEY,
    emp_id INT REFERENCES employees(employee_id),
    certification_id INT REFERENCES certifications(certification_id),
    certification_date DATE NOT NULL
);


INSERT INTO certifications (name, issuing_org, level) VALUES
('AWS Cloud Practitioner', 'Amazon', 'Beginner'),
('Data Analyst', 'Google', 'Intermediate'),
('Cyber Security', 'Cisco', 'Advanced');

INSERT INTO employee_certifications (employee_id, certification_id, certification_date) VALUES
(1, 1, '2023-05-10'),
(2, 2, '2023-06-15'),
(3, 3, '2023-07-20'),
(1, 2, '2024-01-10'),
(4, 1, '2024-02-18');

SELECT e.email,
       c.name AS certification,
       c.issuing_org,
       ec.certification_date
FROM employees e
JOIN employee_certifications ec ON e.employee_id = ec.employee_id
JOIN certifications c ON ec.certification_id = c.certification_id;
