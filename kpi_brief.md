# KPI Brief — Levant Tech Solutions


## KPI 1: Average Salary per Employee by Department

**Definition:**  
Total department salary expenditure divided by employee count per department. Derived from Q2 (Department Salary Analysis) using the `employees` and `departments` tables with `SUM(salary)` and `COUNT(*)`.

**Current value:**  
Departments exceeding $150,000 total payroll are identified in Q2. For example, Engineering: ~$80,000/employee, Sales: ~$68,000/employee.

**Interpretation:**  
Engineering commands the highest per-employee cost, reflecting the premium on technical talent and signaling where retention efforts and budget planning should focus.

## KPI 2: Percentage of Employees Assigned to at Least One Project

**Definition:**  
Uses Q7 (Unassigned Employees) via `LEFT JOIN` on `employees` and `project_assignments`, counting rows where `pa.employee_id IS NULL`.

**Current value:**  
If 3 out of 20 employees are unassigned: **(20 - 3) / 20 × 100 = 85%**

**Interpretation:**  
An 85% utilization rate means most staff are actively contributing to projects, while the 15% bench provides capacity for new initiatives or training without overloading current teams.

## KPI 3: Average Employees per Project

**Definition:**  
Total assigned employees divided by total number of projects. Calculated from Q4 (Project Staffing Overview) using `LEFT JOIN` between `projects` and `project_assignments` with `COUNT(pa.employee_id)`. 

**Current Value:**
Example: 15 total assignments across 5 projects = **3.0 employees per project**


**Interpretation:**  
An average of 3 employees per project suggests lean team sizes; projects with 0 or 1 assignments flagged in Q4 may be at risk and need additional resource allocation.
