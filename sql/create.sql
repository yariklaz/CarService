CREATE TYPE fuel_type_enum   AS ENUM ('petrol', 'diesel', 'lpg', 'electric');
CREATE TYPE policy_type_enum AS ENUM ('osago', 'kasko');

CREATE TABLE vehicle_brands (
    brand_id   SERIAL PRIMARY KEY,
    brand_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE vehicle_statuses (
    status_id   SERIAL PRIMARY KEY,
    status_name VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE branches (
    branch_id   SERIAL PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    city        VARCHAR(50)  NOT NULL,
    address     VARCHAR(150) NOT NULL
);

CREATE TABLE employee_roles (
    role_id   SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE maintenance_types (
    maint_type_id SERIAL PRIMARY KEY,
    type_name     VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE spare_parts (
    part_id        SERIAL PRIMARY KEY,
    part_name      VARCHAR(100) NOT NULL,
    part_number    VARCHAR(50)  NOT NULL UNIQUE,
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0)          
);

CREATE TABLE insurance_companies (
    company_id    SERIAL PRIMARY KEY,
    company_name  VARCHAR(100) NOT NULL UNIQUE,
    contact_phone VARCHAR(20)
);

CREATE TABLE vehicle_models (
    model_id    SERIAL PRIMARY KEY,
    brand_id    INT NOT NULL REFERENCES vehicle_brands(brand_id),
    model_name  VARCHAR(50) NOT NULL,
    engine_type VARCHAR(30)
);

CREATE TABLE employees (
    emp_id                SERIAL PRIMARY KEY,
    branch_id             INT NOT NULL REFERENCES branches(branch_id),
    role_id               INT NOT NULL REFERENCES employee_roles(role_id),
    first_name            VARCHAR(50) NOT NULL,
    last_name             VARCHAR(50) NOT NULL,
    phone                 VARCHAR(20),
    email                 VARCHAR(100),          
    driver_license_number VARCHAR(30),           
    license_expiry_date   DATE,
    hire_date             DATE NOT NULL,
    is_deleted            BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at            TIMESTAMP,
    CONSTRAINT chk_emp_soft_delete CHECK (
        (is_deleted = FALSE AND deleted_at IS NULL) OR
        (is_deleted = TRUE  AND deleted_at IS NOT NULL)
    )
);

CREATE TABLE vehicles (
    vehicle_id       SERIAL PRIMARY KEY,
    model_id         INT NOT NULL REFERENCES vehicle_models(model_id),
    branch_id        INT NOT NULL REFERENCES branches(branch_id),
    status_id        INT NOT NULL REFERENCES vehicle_statuses(status_id),
    license_plate    VARCHAR(15) NOT NULL,     
    vin_number       VARCHAR(17) NOT NULL,       
    manufacture_year INT NOT NULL CHECK (manufacture_year BETWEEN 1950 AND 2100),  
    mileage          INT NOT NULL DEFAULT 0 CHECK (mileage >= 0),                  
    is_deleted       BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    updated_by       VARCHAR(50),
    CONSTRAINT chk_veh_soft_delete CHECK (
        (is_deleted = FALSE AND deleted_at IS NULL) OR
        (is_deleted = TRUE  AND deleted_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX uq_emp_email    ON employees(email)                 WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX uq_emp_license  ON employees(driver_license_number) WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX uq_veh_plate    ON vehicles(license_plate)          WHERE is_deleted = FALSE;
CREATE UNIQUE INDEX uq_veh_vin      ON vehicles(vin_number)             WHERE is_deleted = FALSE;

CREATE TABLE vehicle_assignments (
    assignment_id SERIAL PRIMARY KEY,
    vehicle_id    INT  NOT NULL REFERENCES vehicles(vehicle_id),
    emp_id        INT  NOT NULL REFERENCES employees(emp_id),
    start_date    DATE NOT NULL,
    end_date      DATE,
    CONSTRAINT chk_assign_dates CHECK (end_date IS NULL OR end_date >= start_date)  
);
CREATE UNIQUE INDEX uq_assign_open ON vehicle_assignments(vehicle_id) WHERE end_date IS NULL;

CREATE TABLE trips (
    trip_id        SERIAL PRIMARY KEY,
    vehicle_id     INT NOT NULL REFERENCES vehicles(vehicle_id),
    emp_id         INT NOT NULL REFERENCES employees(emp_id),
    start_time     TIMESTAMP NOT NULL,
    end_time       TIMESTAMP,
    start_location VARCHAR(150) NOT NULL,
    end_location   VARCHAR(150),
    start_odometer INT NOT NULL CHECK (start_odometer >= 0),
    end_odometer   INT,
    distance_km    DECIMAL(8,2) CHECK (distance_km >= 0),
    purpose        VARCHAR(150),
    CONSTRAINT chk_trip_time CHECK (end_time IS NULL OR end_time >= start_time),                  
    CONSTRAINT chk_trip_odo  CHECK (end_odometer IS NULL OR end_odometer >= start_odometer)       
);

CREATE TABLE fines (
    fine_id           SERIAL PRIMARY KEY,
    vehicle_id        INT NOT NULL REFERENCES vehicles(vehicle_id),
    emp_id            INT NOT NULL REFERENCES employees(emp_id),
    fine_type         VARCHAR(100),
    resolution_number VARCHAR(50) UNIQUE,
    fine_date         TIMESTAMP NOT NULL,
    amount            DECIMAL(10,2) NOT NULL CHECK (amount > 0),   
    description       TEXT,
    is_paid           BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at        TIMESTAMP,
    updated_by        VARCHAR(50)
);

CREATE TABLE fuel_cards (
    card_id     SERIAL PRIMARY KEY,
    vehicle_id  INT NOT NULL REFERENCES vehicles(vehicle_id),
    card_number VARCHAR(30) NOT NULL UNIQUE,
    provider    VARCHAR(50) NOT NULL,
    issue_date  DATE,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE fueling_transactions (
    transaction_id   SERIAL PRIMARY KEY,
    card_id          INT NOT NULL REFERENCES fuel_cards(card_id),
    emp_id           INT NOT NULL REFERENCES employees(emp_id),
    transaction_date TIMESTAMP NOT NULL,
    fuel_type        fuel_type_enum NOT NULL,
    fuel_volume      DECIMAL(8,2) NOT NULL CHECK (fuel_volume > 0),      
    price_per_liter  DECIMAL(8,2) NOT NULL CHECK (price_per_liter > 0),  
    cost             DECIMAL(10,2) NOT NULL CHECK (cost >= 0),           
    updated_at       TIMESTAMP,
    updated_by       VARCHAR(50)
);

CREATE TABLE maintenance_records (
    record_id                SERIAL PRIMARY KEY,
    vehicle_id               INT NOT NULL REFERENCES vehicles(vehicle_id),
    maint_type_id            INT NOT NULL REFERENCES maintenance_types(maint_type_id),
    emp_id                   INT NOT NULL REFERENCES employees(emp_id),
    maint_date               DATE NOT NULL,
    labor_cost               DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (labor_cost >= 0),  
    total_cost               DECIMAL(10,2) NOT NULL CHECK (total_cost >= 0),           
    next_maintenance_date    DATE,
    next_maintenance_mileage INT,
    description              TEXT,
    updated_at               TIMESTAMP,
    updated_by               VARCHAR(50),
    CONSTRAINT chk_maint_total CHECK (total_cost >= labor_cost)                         
);

CREATE TABLE maintenance_parts (
    maint_part_id SERIAL PRIMARY KEY,
    record_id     INT NOT NULL REFERENCES maintenance_records(record_id) ON DELETE CASCADE, 
    part_id       INT NOT NULL REFERENCES spare_parts(part_id),
    quantity      INT NOT NULL CHECK (quantity > 0),             
    price_applied DECIMAL(10,2) NOT NULL CHECK (price_applied >= 0)  
);
CREATE UNIQUE INDEX idx_maint_parts_unique ON maintenance_parts(record_id, part_id);

CREATE TABLE insurance_policies (
    policy_id     SERIAL PRIMARY KEY,
    vehicle_id    INT NOT NULL REFERENCES vehicles(vehicle_id),
    company_id    INT NOT NULL REFERENCES insurance_companies(company_id),
    policy_number VARCHAR(50) NOT NULL UNIQUE,
    policy_type   policy_type_enum NOT NULL,
    cost          DECIMAL(10,2) NOT NULL CHECK (cost >= 0),     
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    updated_at    TIMESTAMP,
    updated_by    VARCHAR(50),
    CONSTRAINT chk_policy_dates CHECK (end_date > start_date)    
);

CREATE INDEX idx_models_brand        ON vehicle_models(brand_id);
CREATE INDEX idx_emp_branch          ON employees(branch_id);
CREATE INDEX idx_emp_role            ON employees(role_id);
CREATE INDEX idx_veh_model           ON vehicles(model_id);
CREATE INDEX idx_veh_branch          ON vehicles(branch_id);
CREATE INDEX idx_veh_status          ON vehicles(status_id);
CREATE INDEX idx_assign_vehicle      ON vehicle_assignments(vehicle_id);
CREATE INDEX idx_assign_emp          ON vehicle_assignments(emp_id);
CREATE INDEX idx_trips_vehicle       ON trips(vehicle_id);
CREATE INDEX idx_trips_emp           ON trips(emp_id);
CREATE INDEX idx_fines_vehicle       ON fines(vehicle_id);
CREATE INDEX idx_fines_emp           ON fines(emp_id);
CREATE INDEX idx_fuelcards_vehicle   ON fuel_cards(vehicle_id);
CREATE INDEX idx_fueltx_card         ON fueling_transactions(card_id);
CREATE INDEX idx_fueltx_emp          ON fueling_transactions(emp_id);
CREATE INDEX idx_maint_vehicle       ON maintenance_records(vehicle_id);
CREATE INDEX idx_maint_type          ON maintenance_records(maint_type_id);
CREATE INDEX idx_maint_emp           ON maintenance_records(emp_id);
CREATE INDEX idx_maintparts_part     ON maintenance_parts(part_id);
CREATE INDEX idx_policies_vehicle    ON insurance_policies(vehicle_id);
CREATE INDEX idx_policies_company    ON insurance_policies(company_id);

CREATE OR REPLACE FUNCTION set_audit_fields() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    NEW.updated_by := COALESCE(NULLIF(current_setting('app.user_name', true), ''), current_user);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_vehicles      BEFORE UPDATE ON vehicles              FOR EACH ROW EXECUTE FUNCTION set_audit_fields();
CREATE TRIGGER trg_audit_fines         BEFORE UPDATE ON fines                 FOR EACH ROW EXECUTE FUNCTION set_audit_fields();
CREATE TRIGGER trg_audit_fueltx        BEFORE UPDATE ON fueling_transactions FOR EACH ROW EXECUTE FUNCTION set_audit_fields();
CREATE TRIGGER trg_audit_maintenance   BEFORE UPDATE ON maintenance_records  FOR EACH ROW EXECUTE FUNCTION set_audit_fields();
CREATE TRIGGER trg_audit_policies      BEFORE UPDATE ON insurance_policies   FOR EACH ROW EXECUTE FUNCTION set_audit_fields();

CREATE OR REPLACE FUNCTION set_deleted_at() RETURNS trigger AS $$
BEGIN
    IF NEW.is_deleted AND NOT OLD.is_deleted THEN
        NEW.deleted_at := now();
    ELSIF NOT NEW.is_deleted THEN
        NEW.deleted_at := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_softdel_employees BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION set_deleted_at();
CREATE TRIGGER trg_softdel_vehicles  BEFORE UPDATE ON vehicles  FOR EACH ROW EXECUTE FUNCTION set_deleted_at();
