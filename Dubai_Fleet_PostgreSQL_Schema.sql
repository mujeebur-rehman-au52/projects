-- ============================================================
-- DUBAI FLEET MANAGEMENT SYSTEM — PostgreSQL Schema
-- 100 Vehicles | UAE Routes | Salik Toll Integration
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 1. DUBAI ZONES
-- ============================================================
CREATE TABLE zones (
    zone_id      SERIAL PRIMARY KEY,
    zone_name    VARCHAR(100) UNIQUE NOT NULL,
    zone_type    VARCHAR(50),  -- Residential, Commercial, Industrial, Free Zone
    area_sqkm    NUMERIC(8,2),
    rta_district VARCHAR(50)
);

INSERT INTO zones (zone_name, zone_type, rta_district) VALUES
('Dubai Marina', 'Residential/Commercial', 'West'),
('Downtown Dubai', 'Commercial/Tourism', 'Central'),
('Deira', 'Commercial/Residential', 'North'),
('Bur Dubai', 'Commercial/Residential', 'Central'),
('Jumeirah', 'Residential', 'South'),
('Al Quoz (Industrial)', 'Industrial', 'Central'),
('DIFC', 'Financial/Commercial', 'Central'),
('JLT (Jumeirah Lake Towers)', 'Mixed', 'West'),
('Dubai South (DWC)', 'Logistics/Aviation', 'South'),
('Jebel Ali Free Zone (JAFZA)', 'Free Zone/Industrial', 'South'),
('Al Rashidiya', 'Residential', 'East'),
('Business Bay', 'Commercial', 'Central'),
('Dubai Airport (DXB)', 'Aviation/Logistics', 'East');

-- ============================================================
-- 2. SALIK TOLL GATES
-- ============================================================
CREATE TABLE salik_gates (
    gate_id      SERIAL PRIMARY KEY,
    gate_name    VARCHAR(100),
    location     VARCHAR(200),
    road         VARCHAR(100),
    toll_aed     NUMERIC(4,2) DEFAULT 4.00,
    active       BOOLEAN DEFAULT TRUE
);

INSERT INTO salik_gates (gate_name, location, road) VALUES
('Al Safa Gate 1', 'Sheikh Zayed Road, Al Safa', 'E11'),
('Al Safa Gate 2', 'Sheikh Zayed Road, Al Safa', 'E11'),
('Al Barsha Gate', 'Sheikh Zayed Road, Al Barsha', 'E11'),
('Al Garhoud Gate', 'Al Garhoud Bridge', 'Al Garhoud'),
('Al Maktoum Gate', 'Al Maktoum Bridge', 'Al Maktoum'),
('Business Bay Gate', 'Business Bay Crossing', 'D73'),
('Airport Tunnel Gate', 'Airport Tunnel', 'E311'),
('Rebound Gate', 'Rebound Underpass', 'Sheikh Zayed Road');

-- ============================================================
-- 3. DRIVERS
-- ============================================================
CREATE TABLE drivers (
    driver_id          CHAR(7) PRIMARY KEY,
    full_name          VARCHAR(100) NOT NULL,
    nationality        VARCHAR(50),
    emirates_id        VARCHAR(18) UNIQUE,
    uae_license_no     VARCHAR(20) UNIQUE NOT NULL,
    license_expiry     DATE NOT NULL,
    license_class      VARCHAR(10),  -- LTV, HTV, etc.
    experience_years   INT,
    phone_uae          VARCHAR(15),
    whatsapp           VARCHAR(15),
    accommodation      VARCHAR(200),  -- Company accommodation address
    salary_aed         NUMERIC(10,2),
    status             VARCHAR(20) DEFAULT 'Active'
                           CHECK (status IN ('Active','On Leave','Sick','Suspended','Terminated')),
    visa_expiry        DATE,
    joining_date       DATE DEFAULT CURRENT_DATE,
    zone_id            INT REFERENCES zones(zone_id),
    created_at         TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 4. VEHICLES
-- ============================================================
CREATE TABLE vehicles (
    vehicle_id         CHAR(6) PRIMARY KEY,
    dubai_plate_no     VARCHAR(20) UNIQUE NOT NULL,
    plate_category     VARCHAR(20),  -- Dubai, Sharjah, Abu Dhabi
    vehicle_type       VARCHAR(30) CHECK (vehicle_type IN (
                           'Heavy Truck','Box Van','Pickup Truck','Flatbed Truck',
                           'Refrigerated Van','Tanker','Mini Truck')),
    brand_model        VARCHAR(100),
    manufacture_year   INT CHECK (manufacture_year BETWEEN 2015 AND 2030),
    capacity_tons      NUMERIC(5,2),
    fuel_type          VARCHAR(30),
    engine_cc          INT,
    color              VARCHAR(30),
    status             VARCHAR(20) DEFAULT 'Active'
                           CHECK (status IN ('Active','Maintenance','Idle','Out of Service')),
    current_driver_id  CHAR(7) REFERENCES drivers(driver_id),
    zone_id            INT REFERENCES zones(zone_id),
    odometer_km        INT DEFAULT 0,
    condition_score    NUMERIC(3,1) CHECK (condition_score BETWEEN 0 AND 10),
    
    -- UAE-specific fields
    mulkiya_expiry     DATE,          -- UAE vehicle registration
    salik_account_id   VARCHAR(20),   -- Salik toll account
    rta_permit_no      VARCHAR(30),   -- RTA heavy vehicle permit
    insurance_provider VARCHAR(100),
    insurance_expiry   DATE,
    insurance_type     VARCHAR(50),   -- Comprehensive, Third Party
    
    purchase_date      DATE,
    purchase_cost_aed  NUMERIC(12,2),
    gps_device_id      VARCHAR(50),
    created_at         TIMESTAMP DEFAULT NOW(),
    updated_at         TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 5. ROUTES
-- ============================================================
CREATE TABLE routes (
    route_id             CHAR(7) PRIMARY KEY,
    vehicle_id           CHAR(6) REFERENCES vehicles(vehicle_id),
    driver_id            CHAR(7) REFERENCES drivers(driver_id),
    
    -- Origin/Destination
    origin_zone_id       INT REFERENCES zones(zone_id),
    destination_zone_id  INT REFERENCES zones(zone_id),
    origin_address       VARCHAR(300),
    destination_address  VARCHAR(300),
    origin_lat           NUMERIC(10,7),
    origin_lng           NUMERIC(10,7),
    dest_lat             NUMERIC(10,7),
    dest_lng             NUMERIC(10,7),
    
    -- Route details
    distance_km          NUMERIC(8,2),
    planned_stops        INT DEFAULT 0,
    cargo_type           VARCHAR(50),
    load_percent         INT CHECK (load_percent BETWEEN 0 AND 100),
    cargo_weight_tons    NUMERIC(6,2),
    
    -- Timing
    scheduled_departure  TIMESTAMP,
    actual_departure     TIMESTAMP,
    estimated_arrival    TIMESTAMP,
    actual_arrival       TIMESTAMP,
    estimated_hours      NUMERIC(5,2),
    actual_hours         NUMERIC(5,2),
    
    -- Costs (AED)
    fuel_estimated_l     NUMERIC(8,2),
    fuel_actual_l        NUMERIC(8,2),
    salik_toll_aed       NUMERIC(8,2) DEFAULT 0,
    salik_gates_count    INT DEFAULT 0,
    
    -- Status
    status               VARCHAR(20) DEFAULT 'Scheduled'
                             CHECK (status IN ('Scheduled','In Transit','Completed','Delayed','Cancelled')),
    delay_reason         VARCHAR(200),
    notes                TEXT,
    
    created_at           TIMESTAMP DEFAULT NOW(),
    updated_at           TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 6. SALIK TRANSACTIONS
-- ============================================================
CREATE TABLE salik_transactions (
    transaction_id    BIGSERIAL PRIMARY KEY,
    vehicle_id        CHAR(6) REFERENCES vehicles(vehicle_id),
    route_id          CHAR(7) REFERENCES routes(route_id),
    gate_id           INT REFERENCES salik_gates(gate_id),
    transaction_time  TIMESTAMP NOT NULL,
    toll_aed          NUMERIC(4,2) DEFAULT 4.00,
    balance_after_aed NUMERIC(10,2),
    created_at        TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_salik_vehicle ON salik_transactions(vehicle_id, transaction_time);

-- ============================================================
-- 7. FUEL LOGS
-- ============================================================
CREATE TABLE fuel_logs (
    transaction_id    CHAR(10) PRIMARY KEY,
    vehicle_id        CHAR(6) REFERENCES vehicles(vehicle_id),
    driver_id         CHAR(7) REFERENCES drivers(driver_id),
    transaction_date  DATE NOT NULL,
    fuel_station      VARCHAR(100),
    fuel_station_brand VARCHAR(20),  -- ENOC, ADNOC, EPPCO
    fuel_type         VARCHAR(30),
    quantity_l        NUMERIC(8,2),
    rate_per_l_aed    NUMERIC(5,3),
    amount_aed        NUMERIC(10,2) GENERATED ALWAYS AS 
                          (quantity_l * rate_per_l_aed) STORED,
    odometer_km       INT,
    kml               NUMERIC(5,2),
    zone_id           INT REFERENCES zones(zone_id),
    created_at        TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 8. MAINTENANCE RECORDS
-- ============================================================
CREATE TABLE maintenance_records (
    record_id          CHAR(8) PRIMARY KEY,
    vehicle_id         CHAR(6) REFERENCES vehicles(vehicle_id),
    service_type       VARCHAR(60),
    description        TEXT,
    workshop_name      VARCHAR(100),
    workshop_location  VARCHAR(200),
    
    date_scheduled     DATE NOT NULL,
    date_started       TIMESTAMP,
    date_completed     TIMESTAMP,
    downtime_hours     NUMERIC(5,2),
    
    parts_cost_aed     NUMERIC(10,2) DEFAULT 0,
    labour_cost_aed    NUMERIC(10,2) DEFAULT 0,
    total_cost_aed     NUMERIC(10,2) GENERATED ALWAYS AS 
                           (parts_cost_aed + labour_cost_aed) STORED,
    
    -- UAE-specific
    rta_inspection     BOOLEAN DEFAULT FALSE,  -- Was RTA inspection required?
    mulkiya_renewed    BOOLEAN DEFAULT FALSE,
    odometer_at_service INT,
    next_service_km    INT,
    
    status             VARCHAR(20) DEFAULT 'Scheduled'
                           CHECK (status IN ('Scheduled','In Progress','Completed','Overdue','Cancelled')),
    priority           VARCHAR(10) DEFAULT 'Normal'
                           CHECK (priority IN ('Low','Normal','High','Urgent')),
    created_at         TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 9. GPS TRACKING
-- ============================================================
CREATE TABLE gps_tracking (
    tracking_id    BIGSERIAL PRIMARY KEY,
    vehicle_id     CHAR(6) REFERENCES vehicles(vehicle_id),
    route_id       CHAR(7) REFERENCES routes(route_id),
    recorded_at    TIMESTAMP NOT NULL,
    latitude       NUMERIC(10,7),
    longitude      NUMERIC(10,7),
    speed_kmh      NUMERIC(5,1),
    heading_deg    INT,
    altitude_m     NUMERIC(8,2),
    ignition_on    BOOLEAN DEFAULT TRUE,
    near_zone_id   INT REFERENCES zones(zone_id),
    created_at     TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_gps_vehicle_time ON gps_tracking(vehicle_id, recorded_at DESC);

-- ============================================================
-- 10. DRIVER PERFORMANCE (Monthly)
-- ============================================================
CREATE TABLE driver_performance (
    perf_id              SERIAL PRIMARY KEY,
    driver_id            CHAR(7) REFERENCES drivers(driver_id),
    month_year           CHAR(7),
    routes_completed     INT DEFAULT 0,
    on_time_count        INT DEFAULT 0,
    on_time_percent      NUMERIC(5,2) GENERATED ALWAYS AS (
                             CASE WHEN routes_completed > 0 
                             THEN (on_time_count::NUMERIC/routes_completed)*100 
                             ELSE 0 END) STORED,
    fuel_efficiency_avg  NUMERIC(5,2),
    safety_score         NUMERIC(4,2),
    customer_rating      NUMERIC(3,1),
    salik_violations     INT DEFAULT 0,
    overtime_hours       NUMERIC(5,1),
    total_distance_km    NUMERIC(10,2),
    overall_score        NUMERIC(5,2),
    grade                CHAR(2),
    created_at           TIMESTAMP DEFAULT NOW(),
    UNIQUE(driver_id, month_year)
);

-- ============================================================
-- VIEWS
-- ============================================================

-- Fleet Overview
CREATE OR REPLACE VIEW vw_fleet_overview AS
SELECT
    v.vehicle_id, v.dubai_plate_no, v.vehicle_type, v.brand_model,
    v.status, v.condition_score, v.odometer_km,
    v.mulkiya_expiry,
    CASE WHEN v.mulkiya_expiry < CURRENT_DATE THEN 'EXPIRED'
         WHEN v.mulkiya_expiry < CURRENT_DATE + 30 THEN 'EXPIRING SOON'
         ELSE 'Valid' END AS mulkiya_status,
    v.insurance_expiry,
    d.full_name AS driver_name, d.nationality,
    z.zone_name
FROM vehicles v
LEFT JOIN drivers d ON v.current_driver_id = d.driver_id
LEFT JOIN zones z ON v.zone_id = z.zone_id;

-- Route Performance with Salik
CREATE OR REPLACE VIEW vw_route_performance AS
SELECT
    r.route_id,
    oz.zone_name AS origin_zone, dz.zone_name AS dest_zone,
    r.distance_km, r.estimated_hours, r.actual_hours,
    ROUND((r.actual_hours - r.estimated_hours), 2) AS delay_hrs,
    r.salik_toll_aed, r.salik_gates_count,
    CASE WHEN r.actual_hours <= r.estimated_hours * 1.05 THEN 'On Time'
         WHEN r.actual_hours <= r.estimated_hours * 1.20 THEN 'Slight Delay'
         ELSE 'Delayed' END AS time_status,
    r.cargo_type, r.load_percent, r.status,
    d.full_name AS driver_name
FROM routes r
LEFT JOIN zones oz ON r.origin_zone_id = oz.zone_id
LEFT JOIN zones dz ON r.destination_zone_id = dz.zone_id
LEFT JOIN drivers d ON r.driver_id = d.driver_id;

-- Monthly Cost Per Vehicle
CREATE OR REPLACE VIEW vw_monthly_vehicle_cost AS
SELECT
    v.vehicle_id, v.dubai_plate_no, z.zone_name,
    COALESCE(f.fuel_cost, 0) AS fuel_cost_aed,
    COALESCE(s.salik_cost, 0) AS salik_cost_aed,
    COALESCE(m.maint_cost, 0) AS maintenance_cost_aed,
    COALESCE(d.salary_aed, 0) AS driver_salary_aed,
    COALESCE(f.fuel_cost,0) + COALESCE(s.salik_cost,0) + 
    COALESCE(m.maint_cost,0) + COALESCE(d.salary_aed,0) AS total_monthly_aed
FROM vehicles v
LEFT JOIN zones z ON v.zone_id = z.zone_id
LEFT JOIN drivers d ON v.current_driver_id = d.driver_id
LEFT JOIN (
    SELECT vehicle_id, SUM(amount_aed) AS fuel_cost
    FROM fuel_logs
    WHERE transaction_date >= DATE_TRUNC('month', NOW())
    GROUP BY vehicle_id
) f ON v.vehicle_id = f.vehicle_id
LEFT JOIN (
    SELECT vehicle_id, SUM(toll_aed) AS salik_cost
    FROM salik_transactions
    WHERE transaction_time >= DATE_TRUNC('month', NOW())
    GROUP BY vehicle_id
) s ON v.vehicle_id = s.vehicle_id
LEFT JOIN (
    SELECT vehicle_id, SUM(total_cost_aed) AS maint_cost
    FROM maintenance_records
    WHERE date_scheduled >= DATE_TRUNC('month', NOW())
    GROUP BY vehicle_id
) m ON v.vehicle_id = m.vehicle_id;

-- ============================================================
-- USEFUL OPTIMIZATION QUERIES
-- ============================================================

-- Q1: Peak hour routes (Dubai traffic pattern analysis)
-- SELECT EXTRACT(HOUR FROM actual_departure) AS hour_of_day,
--        COUNT(*) AS routes,
--        AVG(actual_hours - estimated_hours) AS avg_delay_hrs
-- FROM routes
-- WHERE status IN ('Completed','Delayed')
-- GROUP BY hour_of_day ORDER BY avg_delay_hrs DESC;

-- Q2: Salik cost by zone pair
-- SELECT oz.zone_name AS origin, dz.zone_name AS destination,
--        COUNT(*) AS routes, AVG(salik_toll_aed) AS avg_salik_aed,
--        SUM(salik_toll_aed) AS total_salik_aed
-- FROM routes r
-- JOIN zones oz ON r.origin_zone_id = oz.zone_id
-- JOIN zones dz ON r.destination_zone_id = dz.zone_id
-- GROUP BY oz.zone_name, dz.zone_name
-- ORDER BY total_salik_aed DESC;

-- Q3: Vehicles with Mulkiya expiring in 30 days
-- SELECT vehicle_id, dubai_plate_no, mulkiya_expiry,
--        mulkiya_expiry - CURRENT_DATE AS days_remaining
-- FROM vehicles
-- WHERE mulkiya_expiry BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
-- ORDER BY mulkiya_expiry;

-- Q4: Top delayed routes in Dubai
-- SELECT origin_zone_id, destination_zone_id,
--        COUNT(*) AS total_routes,
--        AVG(actual_hours - estimated_hours) AS avg_delay,
--        MAX(salik_toll_aed) AS max_salik
-- FROM routes WHERE status = 'Delayed'
-- GROUP BY origin_zone_id, destination_zone_id
-- ORDER BY avg_delay DESC LIMIT 10;

COMMIT;
