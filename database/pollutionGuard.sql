CREATE DATABASE IF NOT EXISTS pollutionguard 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pollutionguard;

-- Enhanced Reference Tables
CREATE TABLE wards (
  ward_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  city VARCHAR(80) NOT NULL DEFAULT 'Dhaka',
  zone VARCHAR(80) NOT NULL,
  thana VARCHAR(120) NOT NULL,
  centroid_lat DECIMAL(9,6) NOT NULL,
  centroid_lng DECIMAL(9,6) NOT NULL,
  boundary_polygon TEXT COMMENT 'GeoJSON polygon coordinates',
  population INT,
  area_sqkm DECIMAL(10,2),
  INDEX idx_wards_location (city, zone, thana)
) ENGINE=InnoDB;

CREATE TABLE report_types (
  report_type_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name ENUM('air','water','noise','garbage','traffic','industrial','other') NOT NULL,
  description VARCHAR(255),
  icon_url VARCHAR(255),
  severity_weight DECIMAL(3,2) DEFAULT 1.0 COMMENT 'For impact calculations'
) ENGINE=InnoDB;

CREATE TABLE agencies (
  agency_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(160) NOT NULL,
  type ENUM('DNCC','DSCC','WASA','DOE','BRTA','DPHE','RAJUK','Other') NOT NULL DEFAULT 'Other',
  contact_email VARCHAR(190),
  phone VARCHAR(30),
  jurisdiction TEXT COMMENT 'GeoJSON of operational areas',
  response_time_avg_hours INT,
  is_active BOOLEAN DEFAULT TRUE,
  INDEX idx_agencies_type (type)
) ENGINE=InnoDB;

-- Enhanced User System with Verification
CREATE TABLE users (
  user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) UNIQUE,
  phone VARCHAR(30) UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('citizen','admin','agency_staff','ngo','researcher','moderator') NOT NULL DEFAULT 'citizen',
  ward_id BIGINT NULL,
  is_verified BOOLEAN DEFAULT FALSE,
  verification_token VARCHAR(64),
  verification_expiry DATETIME,
  profile_pic_url VARCHAR(255),
  last_active DATETIME,
  account_status ENUM('active','suspended','banned') DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_ward FOREIGN KEY (ward_id) REFERENCES wards(ward_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX idx_users_phone (phone),
  INDEX idx_users_status (account_status)
) ENGINE=InnoDB;

-- Core Reporting System with Enhanced Features
CREATE TABLE reports (
  report_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  report_type_id BIGINT NOT NULL,
  ward_id BIGINT NULL,
  title VARCHAR(140) NOT NULL,
  description TEXT,
  latitude DECIMAL(10,7) NOT NULL COMMENT 'Higher precision for Dhaka',
  longitude DECIMAL(10,7) NOT NULL,
  location_accuracy DECIMAL(5,2) COMMENT 'Meters accuracy',
  severity TINYINT NOT NULL DEFAULT 5,
  status ENUM('Pending','In_Review','Assigned','In_Progress','Resolved','Rejected') NOT NULL DEFAULT 'Pending',
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  verification_score DECIMAL(3,2) DEFAULT 0.0,
  verified_by_user_id BIGINT NULL,
  verified_at DATETIME NULL,
  anonymous BOOLEAN DEFAULT FALSE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_reports_ward_status (ward_id, status),
  INDEX idx_reports_user_created (user_id, created_at),
  INDEX idx_reports_type_verified (report_type_id, is_verified),
  CONSTRAINT fk_reports_user FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_reports_type FOREIGN KEY (report_type_id) REFERENCES report_types(report_type_id),
  CONSTRAINT fk_reports_ward FOREIGN KEY (ward_id) REFERENCES wards(ward_id),
  CONSTRAINT fk_reports_verifier FOREIGN KEY (verified_by_user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- Enhanced Media System
CREATE TABLE report_media (
  media_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_id BIGINT NOT NULL,
  media_type ENUM('photo','video','audio','document') NOT NULL,
  media_url VARCHAR(255) NOT NULL,
  thumbnail_url VARCHAR(255),
  file_size INT COMMENT 'Size in bytes',
  width SMALLINT COMMENT 'For images/videos',
  height SMALLINT COMMENT 'For images/videos',
  duration_seconds INT COMMENT 'For videos/audio',
  uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_primary BOOLEAN DEFAULT FALSE,
  CONSTRAINT fk_media_report FOREIGN KEY (report_id) REFERENCES reports(report_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  INDEX idx_media_report (report_id)
) ENGINE=InnoDB;

-- Comprehensive Status History
CREATE TABLE report_status_history (
  history_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_id BIGINT NOT NULL,
  status ENUM('Pending','In_Review','Assigned','In_Progress','Resolved','Rejected') NOT NULL,
  changed_by_user_id BIGINT NOT NULL,
  note TEXT,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_hist_report FOREIGN KEY (report_id) REFERENCES reports(report_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_hist_user FOREIGN KEY (changed_by_user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- Enhanced Workflow System
CREATE TABLE assignments (
  assignment_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_id BIGINT NOT NULL,
  agency_id BIGINT NOT NULL,
  assigned_by_user_id BIGINT NOT NULL,
  assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_date DATETIME,
  priority ENUM('Low','Medium','High','Urgent') NOT NULL DEFAULT 'Medium',
  status ENUM('Pending','Accepted','In_Progress','Completed','Rejected') DEFAULT 'Pending',
  completion_notes TEXT,
  completed_at DATETIME NULL,
  CONSTRAINT fk_assign_report FOREIGN KEY (report_id) REFERENCES reports(report_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_assign_agency FOREIGN KEY (agency_id) REFERENCES agencies(agency_id),
  CONSTRAINT fk_assign_user FOREIGN KEY (assigned_by_user_id) REFERENCES users(user_id),
  INDEX idx_assignments_agency_status (agency_id, status),
  INDEX idx_assignments_due_date (due_date)
) ENGINE=InnoDB;

CREATE TABLE actions (
  action_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  assignment_id BIGINT NOT NULL,
  action_type ENUM('Inspection','Cleanup','Fine','Warning','Other') NOT NULL,
  action_taken TEXT NOT NULL,
  action_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  proof_media_url VARCHAR(255),
  logged_by_user_id BIGINT NOT NULL,
  effectiveness_rating TINYINT COMMENT '1-5 scale',
  CONSTRAINT fk_actions_assignment FOREIGN KEY (assignment_id) REFERENCES assignments(assignment_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_actions_user FOREIGN KEY (logged_by_user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- Enhanced Offender Tracking
CREATE TABLE offenders (
  offender_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(140),
  type ENUM('vehicle','shop','factory','individual','construction','other') NOT NULL,
  identifier VARCHAR(160) COMMENT 'License plate, trade license etc.',
  address VARCHAR(255),
  ward_id BIGINT,
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  is_repeat_offender BOOLEAN DEFAULT FALSE,
  last_reported DATETIME,
  CONSTRAINT fk_offenders_ward FOREIGN KEY (ward_id) REFERENCES wards(ward_id),
  INDEX idx_offenders_type (type),
  INDEX idx_offenders_repeat (is_repeat_offender)
) ENGINE=InnoDB;

CREATE TABLE report_offenders (
  report_offender_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_id BIGINT NOT NULL,
  offender_id BIGINT NOT NULL,
  violation_details TEXT,
  UNIQUE KEY uq_report_offender(report_id, offender_id),
  CONSTRAINT fk_ro_report FOREIGN KEY (report_id) REFERENCES reports(report_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_ro_offender FOREIGN KEY (offender_id) REFERENCES offenders(offender_id)
) ENGINE=InnoDB;

-- Comprehensive AQI/Weather System
CREATE TABLE aqi_readings (
  aqi_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  ward_id BIGINT NOT NULL,
  source ENUM('government','sensor','manual','api') NOT NULL,
  aqi INT NOT NULL,
  aqi_category ENUM('Good','Moderate','Unhealthy','Very_Unhealthy','Hazardous'),
  main_pollutant VARCHAR(40),
  temperature_c DECIMAL(5,2),
  humidity_pct DECIMAL(5,2),
  pm25 DECIMAL(6,2),
  pm10 DECIMAL(6,2),
  no2 DECIMAL(6,2),
  so2 DECIMAL(6,2),
  co DECIMAL(6,2),
  recorded_at DATETIME NOT NULL,
  CONSTRAINT fk_aqi_ward FOREIGN KEY (ward_id) REFERENCES wards(ward_id),
  INDEX idx_aqi_ward_time (ward_id, recorded_at),
  INDEX idx_aqi_category (aqi_category)
) ENGINE=InnoDB;

-- Enhanced Notification System
CREATE TABLE notifications (
  notification_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  title VARCHAR(120) NOT NULL,
  body TEXT NOT NULL,
  notification_type ENUM('report_update','alert','system','reward') NOT NULL,
  related_report_id BIGINT NULL,
  lat DECIMAL(10,7),
  lng DECIMAL(10,7),
  is_read BOOLEAN DEFAULT FALSE,
  sent_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME NULL,
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_notifications_report FOREIGN KEY (related_report_id) REFERENCES reports(report_id)
    ON DELETE SET NULL,
  INDEX idx_notifications_user_unread (user_id, is_read)
) ENGINE=InnoDB;

-- Gamification & Rewards System
CREATE TABLE reward_points (
  user_id BIGINT PRIMARY KEY,
  total_points INT NOT NULL DEFAULT 0,
  current_streak INT DEFAULT 0 COMMENT 'Consecutive days with reports',
  highest_streak INT DEFAULT 0,
  last_report_date DATE,
  level TINYINT DEFAULT 1,
  CONSTRAINT fk_rewardpoints_user FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE TABLE reward_transactions (
  transaction_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  points INT NOT NULL,
  balance_after INT NOT NULL,
  reason ENUM('report_submitted','report_verified','streak_bonus','moderation','other') NOT NULL,
  related_report_id BIGINT NULL,
  awarded_by_user_id BIGINT NULL COMMENT 'For manually awarded points',
  awarded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expiry_date DATE NULL,
  CONSTRAINT fk_rewardtx_user FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_rewardtx_report FOREIGN KEY (related_report_id) REFERENCES reports(report_id),
  CONSTRAINT fk_rewardtx_awarder FOREIGN KEY (awarded_by_user_id) REFERENCES users(user_id),
  INDEX idx_rewardtx_user_date (user_id, awarded_at)
) ENGINE=InnoDB;

-- Advanced Moderation System
CREATE TABLE report_flags (
  flag_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_id BIGINT NOT NULL,
  flagged_by_user_id BIGINT NOT NULL,
  reason ENUM('spam','fake','duplicate','inappropriate','other') NOT NULL,
  details TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_by_user_id BIGINT NULL,
  resolution ENUM('confirmed','rejected','pending') DEFAULT 'pending',
  resolution_note TEXT,
  resolved_at DATETIME NULL,
  CONSTRAINT fk_flags_report FOREIGN KEY (report_id) REFERENCES reports(report_id),
  CONSTRAINT fk_flags_flagger FOREIGN KEY (flagged_by_user_id) REFERENCES users(user_id),
  CONSTRAINT fk_flags_resolver FOREIGN KEY (resolved_by_user_id) REFERENCES users(user_id),
  INDEX idx_flags_status (resolution, created_at)
) ENGINE=InnoDB;

-- Citizen Verification System
CREATE TABLE report_verifications (
  verification_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  report_id BIGINT NOT NULL,
  verifying_user_id BIGINT NOT NULL,
  vote ENUM('confirm','deny') NOT NULL,
  confidence_level TINYINT DEFAULT 3 COMMENT '1-5 scale',
  notes TEXT,
  verified_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_report_verifier (report_id, verifying_user_id),
  CONSTRAINT fk_verifications_report FOREIGN KEY (report_id) REFERENCES reports(report_id),
  CONSTRAINT fk_verifications_user FOREIGN KEY (verifying_user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- API Management
CREATE TABLE api_keys (
  key_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  api_key VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(80) NOT NULL,
  scopes TEXT NOT NULL COMMENT 'Array of permissions',
  is_active BOOLEAN DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used_at DATETIME NULL,
  rate_limit INT DEFAULT 1000 COMMENT 'Requests per hour',
  CONSTRAINT fk_apikeys_user FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- Analytics Events
CREATE TABLE analytics_events (
  event_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NULL,
  event_type VARCHAR(80) NOT NULL,
  event_data TEXT,
  device_info TEXT,
  ip_address VARCHAR(45),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_analytics_type_time (event_type, created_at),
  INDEX idx_analytics_user (user_id)
) ENGINE=InnoDB;

-- Scheduled Tasks
CREATE TABLE scheduled_tasks (
  task_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  task_name VARCHAR(80) NOT NULL,
  task_data TEXT,
  status ENUM('pending','running','completed','failed') DEFAULT 'pending',
  scheduled_at DATETIME NOT NULL,
  started_at DATETIME NULL,
  completed_at DATETIME NULL,
  attempts TINYINT DEFAULT 0,
  last_error TEXT,
  INDEX idx_scheduled_tasks (status, scheduled_at)
) ENGINE=InnoDB;

-- Monitoring API Usage
CREATE TABLE api_logs (
  log_id INT AUTO_INCREMENT PRIMARY KEY,
  api_name VARCHAR(30) NOT NULL,
  endpoint VARCHAR(100) NOT NULL,
  status_code SMALLINT,
  response_time_ms INT,
  called_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX (api_name, called_at)
) ENGINE=InnoDB;

-- Insert sample data for report_types
INSERT INTO report_types (name, description, icon_url, severity_weight) VALUES
('air', 'Air pollution reports', 'air_icon.png', 1.0),
('water', 'Water pollution reports', 'water_icon.png', 1.0),
('noise', 'Noise pollution reports', 'noise_icon.png', 0.8),
('garbage', 'Garbage and waste issues', 'garbage_icon.png', 0.9),
('traffic', 'Traffic congestion and pollution', 'traffic_icon.png', 0.7),
('industrial', 'Industrial pollution', 'industrial_icon.png', 1.2),
('other', 'Other types of pollution', 'other_icon.png', 1.0);

-- Insert sample data for agencies
INSERT INTO agencies (name, type, contact_email, phone, response_time_avg_hours) VALUES
('Dhaka North City Corporation', 'DNCC', 'contact@dncc.gov.bd', '+880XXXXXXX', 48),
('Dhaka South City Corporation', 'DSCC', 'contact@dscc.gov.bd', '+880XXXXXXX', 48),
('Water Supply and Sewerage Authority', 'WASA', 'info@dhakawasa.gov.bd', '+880XXXXXXX', 72),
('Department of Environment', 'DOE', 'doe@doe.gov.bd', '+880XXXXXXX', 96);