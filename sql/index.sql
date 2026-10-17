-- 1. Складений індекс на основі B-дерева
DROP INDEX IF EXISTS idx_trips_vehicle_emp;
CREATE INDEX idx_trips_vehicle_emp ON trips(vehicle_id, emp_id);

-- 2. Індекс з фільтром
DROP INDEX IF EXISTS idx_active_vehicles_branch;
CREATE INDEX idx_active_vehicles_branch ON vehicles(branch_id) WHERE is_deleted = FALSE;

-- 3. Індекс на значеннях функції
DROP INDEX IF EXISTS idx_emp_last_name_lower;
CREATE INDEX idx_emp_last_name_lower ON employees(LOWER(last_name));
