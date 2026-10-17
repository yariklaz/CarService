TRUNCATE TABLE vehicle_brands, vehicle_models, vehicle_statuses, branches, employee_roles, employees, vehicles, fines, fuel_cards, fueling_transactions, maintenance_types, maintenance_records, spare_parts, maintenance_parts, insurance_companies, insurance_policies, vehicle_assignments, trips RESTART IDENTITY CASCADE;
INSERT INTO vehicle_brands (brand_name) VALUES ('Skoda'), ('Volkswagen'), ('Nissan'), ('Mercedes-Benz');

INSERT INTO vehicle_models (brand_id, model_name, engine_type) VALUES 
(1, 'Octavia', 'Petrol'),
(1, 'Fabia', 'LPG'),
(2, 'Passat', 'Diesel'),
(3, 'Leaf', 'Electric'),
(4, 'Sprinter', 'Diesel');

INSERT INTO vehicle_statuses (status_name) VALUES ('Активний'), ('На ТО'), ('Резерв'), ('Списано');

INSERT INTO branches (branch_name, city, address) VALUES 
('Центральний офіс', 'Київ', 'вул. Хрещатик, 1'),
('Східний філіал', 'Харків', 'вул. Сумська, 10');

INSERT INTO employee_roles (role_name) VALUES ('Водій'), ('Механік'), ('Диспетчер');

INSERT INTO employees (branch_id, role_id, first_name, last_name, phone, hire_date, is_deleted, deleted_at) VALUES 
(1, 1, 'Іван', 'Іваненко', '+380501112233', '2023-01-10', FALSE, NULL),
(1, 1, 'Петро', 'Петренко', '+380672223344', '2023-05-15', FALSE, NULL),
(2, 1, 'Василь', 'Василенко', '+380633334455', '2022-11-20', FALSE, NULL),
(1, 2, 'Олексій', 'Коваленко', '+380994445566', '2021-08-01', FALSE, NULL),
(2, 1, 'Микола', 'Звільнений', '+380990000000', '2020-01-01', TRUE, NOW());

INSERT INTO vehicles (model_id, branch_id, status_id, license_plate, vin_number, manufacture_year, mileage, is_deleted, deleted_at) VALUES 
(1, 1, 1, 'AA1111AA', 'VIN1111111111SKOD', 2018, 120000, FALSE, NULL),  -- Активний
(3, 1, 2, 'AA2222BB', 'VIN2222222222VOLK', 2020, 85000, FALSE, NULL),   -- На ТО
(4, 2, 1, 'AX3333CC', 'VIN3333333333NISS', 2021, 45000, FALSE, NULL),   -- Активний
(5, 1, 3, 'AA4444DD', 'VIN4444444444MERC', 2016, 320000, FALSE, NULL),  -- Резерв
(2, 1, 4, 'AA0000XX', 'VIN0000000000SKOD', 2005, 450000, TRUE, NOW());

INSERT INTO fines (vehicle_id, emp_id, fine_date, amount, description, is_paid) VALUES 
(1, 1, '2026-10-15 14:30:00', 340.00, 'Перевищення швидкості', FALSE),
(3, 3, '2026-10-10 09:15:00', 680.00, 'Проїзд на червоне світло', FALSE),
(4, 1, '2026-09-01 11:00:00', 510.00, 'Порушення правил паркування', TRUE), 
(1, 2, '2026-10-17 08:20:00', 1700.00, 'Створення аварійної ситуації', FALSE);

INSERT INTO maintenance_types (type_name) VALUES ('Планове ТО'), ('Заміна фільтрів'), ('Ремонт ходової');
INSERT INTO maintenance_records (vehicle_id, maint_type_id, emp_id, maint_date, labor_cost, total_cost, description) VALUES
(2, 3, 4, '2026-10-16', 2000.00, 5000.00, 'Заміна гальмівних колодок');