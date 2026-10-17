DROP TRIGGER IF EXISTS trg_trip_distance ON trips;
DROP TRIGGER IF EXISTS trg_fines_update  ON fines;
DROP TRIGGER IF EXISTS trg_check_mileage ON vehicles;

DROP VIEW IF EXISTS v_active_vehicles;
DROP VIEW IF EXISTS v_unpaid_fines;
DROP VIEW IF EXISTS v_active_employees;

CREATE VIEW v_active_vehicles AS
SELECT v.vehicle_id, v.license_plate, v.vin_number, vb.brand_name, vm.model_name, v.mileage
FROM vehicles v
JOIN vehicle_models vm ON v.model_id = vm.model_id
JOIN vehicle_brands vb ON vm.brand_id = vb.brand_id
WHERE v.is_deleted = FALSE;

CREATE VIEW v_unpaid_fines AS
SELECT f.fine_id, f.vehicle_id, f.fine_date, f.amount, v.license_plate, e.last_name
FROM fines f
JOIN vehicles v ON f.vehicle_id = v.vehicle_id
JOIN employees e ON f.emp_id = e.emp_id
WHERE f.is_paid = FALSE;

CREATE VIEW v_active_employees AS
SELECT e.emp_id, e.first_name, e.last_name, b.branch_name, r.role_name
FROM employees e
JOIN branches b ON e.branch_id = b.branch_id
JOIN employee_roles r ON e.role_id = r.role_id
WHERE e.is_deleted = FALSE;

CREATE OR REPLACE FUNCTION fn_total_fines(p_vehicle_id INT) RETURNS DECIMAL(10,2)
LANGUAGE plpgsql AS $$
DECLARE
    total DECIMAL(10,2);
BEGIN
    SELECT SUM(amount) INTO total FROM fines WHERE vehicle_id = p_vehicle_id;
    RETURN COALESCE(total, 0);
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_status_name(p_status_id INT) RETURNS VARCHAR
LANGUAGE plpgsql AS $$
DECLARE
    s_name VARCHAR;
BEGIN
    SELECT status_name INTO s_name FROM vehicle_statuses WHERE status_id = p_status_id;
    RETURN s_name;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_delete_vehicle(p_vehicle_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE vehicles
    SET is_deleted = TRUE
    WHERE vehicle_id = p_vehicle_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Автомобіль % не знайдено або вже списаний', p_vehicle_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_pay_fine(p_fine_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE fines SET is_paid = TRUE WHERE fine_id = p_fine_id AND is_paid = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Неоплачений штраф % не знайдено', p_fine_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_update_mileage(p_vehicle_id INT, p_new_mileage INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE vehicles
    SET mileage = p_new_mileage
    WHERE vehicle_id = p_vehicle_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Активний автомобіль % не знайдено', p_vehicle_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION trg_calc_distance() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.end_odometer IS NOT NULL THEN
        NEW.distance_km := NEW.end_odometer - NEW.start_odometer;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_trip_distance
BEFORE INSERT OR UPDATE ON trips
FOR EACH ROW EXECUTE FUNCTION trg_calc_distance();

CREATE OR REPLACE FUNCTION fn_prevent_mileage_rollback() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.mileage < OLD.mileage THEN
        RAISE EXCEPTION 'Новий пробіг (%) не може бути меншим за поточний (%)', NEW.mileage, OLD.mileage;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_mileage
BEFORE UPDATE ON vehicles
FOR EACH ROW EXECUTE FUNCTION fn_prevent_mileage_rollback();