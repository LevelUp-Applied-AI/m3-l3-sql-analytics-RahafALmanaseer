-- challenges.sql — SQL Analytics Lab Challenge Extensions
-- Module 3: SQL & Relational Data
--
-- ============================================================
-- TIER 1 — Complex Analytics Queries
-- ============================================================

-- T1.1: At-Risk Projects
-- Projects where total allocated hours exceed 80% of the project budget
-- (treating budget as available hours for simplicity)

SELECT p.name AS project_name,
       p.budget,
       COALESCE(SUM(pa.hours_allocated), 0) AS total_hours_allocated,
       ROUND((COALESCE(SUM(pa.hours_allocated), 0) / p.budget) * 100, 2) AS utilization_pct,
       CASE
           WHEN COALESCE(SUM(pa.hours_allocated), 0) > p.budget * 0.8
           THEN 'AT RISK'
           ELSE 'OK'
       END AS risk_status
FROM projects p
LEFT JOIN project_assignments pa ON p.project_id = pa.project_id
WHERE p.budget > 0
GROUP BY p.project_id, p.name, p.budget
HAVING COALESCE(SUM(pa.hours_allocated), 0) > p.budget * 0.8
ORDER BY utilization_pct DESC;


-- T1.2: Cross-Department Assignments
-- Employees assigned to projects belonging to a different department than their own

SELECT e.first_name,
       e.last_name,
       d_emp.name AS employee_department,
       p.name AS project_name,
       d_proj.name AS project_department,
       pa.hours_allocated
FROM employees e
JOIN project_assignments pa ON e.employee_id = pa.employee_id
JOIN projects p ON pa.project_id = p.project_id
JOIN departments d_emp ON e.department_id = d_emp.department_id
JOIN departments d_proj ON p.department_id = d_proj.department_id
WHERE e.department_id != p.department_id
ORDER BY e.last_name, e.first_name;


-- ============================================================
-- TIER 2 — Dynamic Reporting with Views and Functions
-- ============================================================

-- T2.1a: Department Summary View

DROP VIEW IF EXISTS department_summary;

CREATE VIEW department_summary AS
SELECT d.name AS department_name,
       COUNT(e.employee_id) AS employee_count,
       SUM(e.salary) AS total_salary,
       ROUND(AVG(e.salary), 2) AS avg_salary,
       MIN(e.salary) AS min_salary,
       MAX(e.salary) AS max_salary,
       MIN(e.hire_date) AS earliest_hire,
       MAX(e.hire_date) AS latest_hire
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.name
ORDER BY d.name;

-- Usage: SELECT * FROM department_summary;


-- T2.1b: Project Status View

DROP VIEW IF EXISTS project_status;

CREATE VIEW project_status AS
SELECT p.name AS project_name,
       d.name AS department_name,
       p.budget,
       p.start_date,
       p.end_date,
       COUNT(pa.employee_id) AS assigned_employees,
       COALESCE(SUM(pa.hours_allocated), 0) AS total_hours,
       CASE
           WHEN p.budget > 0
           THEN ROUND((COALESCE(SUM(pa.hours_allocated), 0) / p.budget) * 100, 2)
           ELSE 0
       END AS budget_utilization_pct,
       CASE
           WHEN p.end_date < CURRENT_DATE THEN 'Completed'
           WHEN p.start_date > CURRENT_DATE THEN 'Not Started'
           ELSE 'Active'
       END AS status
FROM projects p
JOIN departments d ON p.department_id = d.department_id
LEFT JOIN project_assignments pa ON p.project_id = pa.project_id
GROUP BY p.project_id, p.name, d.name, p.budget, p.start_date, p.end_date
ORDER BY p.name;

-- Usage: SELECT * FROM project_status;


-- T2.1c: Materialized View for Department Summary
-- Materialized views store results physically for faster reads
-- Must be refreshed manually: REFRESH MATERIALIZED VIEW mat_department_summary;

DROP MATERIALIZED VIEW IF EXISTS mat_department_summary;

CREATE MATERIALIZED VIEW mat_department_summary AS
SELECT d.name AS department_name,
       COUNT(e.employee_id) AS employee_count,
       SUM(e.salary) AS total_salary,
       ROUND(AVG(e.salary), 2) AS avg_salary
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.name
ORDER BY d.name;

-- Usage:
-- SELECT * FROM mat_department_summary;
-- REFRESH MATERIALIZED VIEW mat_department_summary;

-- NOTE: Standard VIEW always returns live data (re-runs query each time).
--       MATERIALIZED VIEW stores a snapshot — faster reads but requires
--       manual REFRESH to pick up changes. Best for expensive queries
--       where real-time accuracy is not critical.


-- T2.2: PL/pgSQL Function — Department Report as JSON

DROP FUNCTION IF EXISTS get_department_report(VARCHAR);

CREATE OR REPLACE FUNCTION get_department_report(dept_name VARCHAR)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'department_name', dept_name,
        'employee_count', COUNT(e.employee_id),
        'total_salary', COALESCE(SUM(e.salary), 0),
        'active_projects', (
            SELECT COUNT(DISTINCT p.project_id)
            FROM projects p
            WHERE p.department_id = d.department_id
              AND p.start_date <= CURRENT_DATE
              AND (p.end_date >= CURRENT_DATE OR p.end_date IS NULL)
        )
    ) INTO result
    FROM departments d
    LEFT JOIN employees e ON d.department_id = e.department_id
    WHERE d.name = dept_name
    GROUP BY d.department_id, d.name;

    IF result IS NULL THEN
        RETURN json_build_object(
            'error', 'Department not found',
            'department_name', dept_name
        );
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Usage from psql:
-- SELECT get_department_report('Engineering');
-- SELECT get_department_report('Sales');

-- Usage from Python:
-- import psycopg2, json
-- conn = psycopg2.connect(dbname="testdb", user="postgres", host="localhost")
-- cur = conn.cursor()
-- cur.execute("SELECT get_department_report(%s)", ("Engineering",))
-- result = cur.fetchone()[0]
-- print(json.dumps(result, indent=2))
-- cur.close()
-- conn.close()


-- ============================================================
-- TIER 3 — Schema Evolution and Migration
-- ============================================================

-- T3.1: Salary History Table — DDL

DROP TABLE IF EXISTS salary_history CASCADE;

CREATE TABLE salary_history (
    history_id SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
    old_salary NUMERIC(12, 2),
    new_salary NUMERIC(12, 2) NOT NULL,
    change_date DATE NOT NULL,
    change_reason VARCHAR(100),
    changed_by VARCHAR(100) DEFAULT 'system'
);

CREATE INDEX idx_salary_history_emp ON salary_history(employee_id);
CREATE INDEX idx_salary_history_date ON salary_history(change_date);


-- T3.2: Migration Script — Populate from Existing Employees
-- Creates one initial record per employee at their current salary

INSERT INTO salary_history (employee_id, old_salary, new_salary, change_date, change_reason)
SELECT employee_id,
       NULL,
       salary,
       hire_date,
       'Initial hire salary'
FROM employees;


-- T3.3: Seed Realistic Historical Data (2-3 records per employee over 3 years)

INSERT INTO salary_history (employee_id, old_salary, new_salary, change_date, change_reason)
SELECT e.employee_id,
       e.salary * 0.85,
       e.salary * 0.92,
       e.hire_date + INTERVAL '1 year',
       'Annual review - Year 1'
FROM employees e
WHERE e.hire_date + INTERVAL '1 year' < CURRENT_DATE;

INSERT INTO salary_history (employee_id, old_salary, new_salary, change_date, change_reason)
SELECT e.employee_id,
       e.salary * 0.92,
       e.salary,
       e.hire_date + INTERVAL '2 years',
       'Annual review - Year 2'
FROM employees e
WHERE e.hire_date + INTERVAL '2 years' < CURRENT_DATE;

INSERT INTO salary_history (employee_id, old_salary, new_salary, change_date, change_reason)
SELECT e.employee_id,
       e.salary * 0.80,
       e.salary * 0.85,
       e.hire_date + INTERVAL '6 months',
       'Probation completion raise'
FROM employees e
WHERE e.hire_date + INTERVAL '6 months' < CURRENT_DATE;


-- T3.4: Query — Salary Growth Rate by Department Over Time

WITH salary_changes AS (
    SELECT sh.employee_id,
           e.department_id,
           d.name AS department_name,
           sh.old_salary,
           sh.new_salary,
           sh.change_date,
           EXTRACT(YEAR FROM sh.change_date) AS change_year,
           CASE
               WHEN sh.old_salary IS NOT NULL AND sh.old_salary > 0
               THEN ROUND(((sh.new_salary - sh.old_salary) / sh.old_salary) * 100, 2)
               ELSE NULL
           END AS growth_pct
    FROM salary_history sh
    JOIN employees e ON sh.employee_id = e.employee_id
    JOIN departments d ON e.department_id = d.department_id
    WHERE sh.old_salary IS NOT NULL
)
SELECT department_name,
       change_year,
       COUNT(*) AS num_changes,
       ROUND(AVG(growth_pct), 2) AS avg_growth_pct,
       ROUND(MIN(growth_pct), 2) AS min_growth_pct,
       ROUND(MAX(growth_pct), 2) AS max_growth_pct
FROM salary_changes
GROUP BY department_name, change_year
ORDER BY department_name, change_year;


-- T3.5: Query — Employees Due for Salary Review (No change in 12+ months)

SELECT e.first_name,
       e.last_name,
       d.name AS department_name,
       e.salary AS current_salary,
       latest.last_change_date,
       (CURRENT_DATE - latest.last_change_date) AS days_since_last_change
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN (
    SELECT employee_id,
           MAX(change_date) AS last_change_date
    FROM salary_history
    GROUP BY employee_id
) latest ON e.employee_id = latest.employee_id
WHERE latest.last_change_date < CURRENT_DATE - INTERVAL '12 months'
ORDER BY days_since_last_change DESC;

