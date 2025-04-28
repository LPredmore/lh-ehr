-- Valorwell Mental Health EHR - Simplified Supabase Schema
-- Created for Valorwell

-- =============================================================================
-- EXTENSIONS
-- =============================================================================

-- Enable necessary extensions in public schema first
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- ROLE DEFINITIONS
-- =============================================================================

-- Create application roles
CREATE TYPE user_role AS ENUM ('admin', 'provider', 'staff', 'patient');

-- =============================================================================
-- CORE TABLES
-- =============================================================================

-- -----------------------------------------------------
-- Table: users
-- Description: Stores all system users including providers, staff, and admins
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID UNIQUE,
  username VARCHAR(255) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  role user_role NOT NULL DEFAULT 'staff',
  first_name VARCHAR(255) NOT NULL,
  middle_name VARCHAR(255),
  last_name VARCHAR(255) NOT NULL,
  phone VARCHAR(30),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Provider-specific fields
  npi VARCHAR(15),
  specialty VARCHAR(255),
  license_number VARCHAR(50),
  taxonomy VARCHAR(30),
  provider_bio TEXT,
  provider_photo_url VARCHAR(2000),
  
  -- Address fields
  address_line1 VARCHAR(255),
  address_line2 VARCHAR(255),
  city VARCHAR(255),
  state VARCHAR(35),
  postal_code VARCHAR(10),
  country VARCHAR(255) DEFAULT 'USA'
);

-- -----------------------------------------------------
-- Table: patients
-- Description: Stores patient demographic information
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID UNIQUE,
  external_id VARCHAR(50),
  first_name VARCHAR(255) NOT NULL,
  middle_name VARCHAR(255),
  last_name VARCHAR(255) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender VARCHAR(50) NOT NULL,
  email VARCHAR(255),
  phone_home VARCHAR(30),
  phone_cell VARCHAR(30),
  phone_work VARCHAR(30),
  address_line1 VARCHAR(255),
  address_line2 VARCHAR(255),
  city VARCHAR(255),
  state VARCHAR(35),
  postal_code VARCHAR(10),
  country VARCHAR(255) DEFAULT 'USA',
  emergency_contact_name VARCHAR(255),
  emergency_contact_phone VARCHAR(30),
  emergency_contact_relationship VARCHAR(50),
  primary_provider_id UUID REFERENCES users(id) ON DELETE SET NULL,
  insurance_provider VARCHAR(255),
  insurance_id VARCHAR(255),
  insurance_group VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Mental health specific fields
  referral_source VARCHAR(255),
  presenting_problem TEXT,
  previous_treatment BOOLEAN DEFAULT FALSE,
  previous_treatment_details TEXT,
  current_medications TEXT,
  medication_allergies TEXT,
  safety_risk_assessment TEXT,
  
  -- Portal access
  portal_access_enabled BOOLEAN DEFAULT TRUE,
  portal_terms_accepted BOOLEAN DEFAULT FALSE,
  portal_terms_accepted_at TIMESTAMPTZ
);

-- -----------------------------------------------------
-- Table: appointments
-- Description: Stores appointment/session information
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  appointment_type VARCHAR(50) NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  duration INT NOT NULL, -- Duration in minutes
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled', -- scheduled, confirmed, completed, cancelled, no-show
  cancellation_reason TEXT,
  cancellation_time TIMESTAMPTZ,
  cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
  location VARCHAR(255),
  room VARCHAR(50),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Telehealth specific fields
  is_telehealth BOOLEAN DEFAULT FALSE,
  telehealth_url VARCHAR(2000),
  telehealth_provider VARCHAR(50), -- e.g., 'zoom', 'teams', 'internal'
  telehealth_meeting_id VARCHAR(255),
  telehealth_password VARCHAR(255),
  
  -- Billing fields
  billing_status VARCHAR(20) DEFAULT 'unbilled', -- unbilled, billed, paid, denied
  billing_code VARCHAR(20),
  billing_amount DECIMAL(10,2),
  copay_amount DECIMAL(10,2),
  insurance_claim_id VARCHAR(255)
);

-- -----------------------------------------------------
-- Table: clinical_notes
-- Description: Stores SOAP and other clinical documentation
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS clinical_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
  provider_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  note_type VARCHAR(50) NOT NULL, -- soap, progress, intake, discharge, etc.
  subjective TEXT,
  objective TEXT,
  assessment TEXT,
  plan TEXT,
  diagnosis_codes TEXT[], -- Array of diagnosis codes
  treatment_goals TEXT,
  interventions TEXT,
  mental_status TEXT,
  risk_assessment TEXT,
  signature TEXT,
  signed_at TIMESTAMPTZ,
  is_signed BOOLEAN DEFAULT FALSE,
  is_locked BOOLEAN DEFAULT FALSE,
  locked_at TIMESTAMPTZ,
  locked_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- Table: care_plans
-- Description: Stores patient care plans
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS care_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, completed, discontinued
  presenting_problems TEXT,
  goals TEXT[],
  interventions TEXT[],
  progress_measures TEXT,
  review_frequency VARCHAR(50),
  next_review_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- Table: medications
-- Description: Stores patient medications
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS medications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  medication_name VARCHAR(255) NOT NULL,
  dosage VARCHAR(100) NOT NULL,
  frequency VARCHAR(100) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, discontinued, completed
  reason TEXT,
  instructions TEXT,
  side_effects TEXT,
  pharmacy_name VARCHAR(255),
  pharmacy_phone VARCHAR(30),
  is_prescribed BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- Table: assessments
-- Description: Stores mental health assessments and screening tools
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assessment_type VARCHAR(100) NOT NULL, -- PHQ-9, GAD-7, etc.
  assessment_date DATE NOT NULL,
  score INT,
  interpretation TEXT,
  responses JSONB, -- Stores the actual responses to assessment questions
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- Users indexes
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_name ON users(last_name, first_name);
CREATE INDEX idx_users_auth_id ON users(auth_id);

-- Patients indexes
CREATE INDEX idx_patients_name ON patients(last_name, first_name);
CREATE INDEX idx_patients_dob ON patients(date_of_birth);
CREATE INDEX idx_patients_provider ON patients(primary_provider_id);
CREATE INDEX idx_patients_auth_id ON patients(auth_id);

-- Appointments indexes
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_provider ON appointments(provider_id);
CREATE INDEX idx_appointments_date ON appointments(start_time);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_appointments_telehealth ON appointments(is_telehealth) WHERE is_telehealth = TRUE;

-- Clinical notes indexes
CREATE INDEX idx_clinical_notes_patient ON clinical_notes(patient_id);
CREATE INDEX idx_clinical_notes_provider ON clinical_notes(provider_id);
CREATE INDEX idx_clinical_notes_appointment ON clinical_notes(appointment_id);
CREATE INDEX idx_clinical_notes_type ON clinical_notes(note_type);
CREATE INDEX idx_clinical_notes_signed ON clinical_notes(is_signed);

-- Care plans indexes
CREATE INDEX idx_care_plans_patient ON care_plans(patient_id);
CREATE INDEX idx_care_plans_provider ON care_plans(provider_id);
CREATE INDEX idx_care_plans_status ON care_plans(status);

-- Medications indexes
CREATE INDEX idx_medications_patient ON medications(patient_id);
CREATE INDEX idx_medications_provider ON medications(provider_id);
CREATE INDEX idx_medications_status ON medications(status);

-- Assessments indexes
CREATE INDEX idx_assessments_patient ON assessments(patient_id);
CREATE INDEX idx_assessments_provider ON assessments(provider_id);
CREATE INDEX idx_assessments_type ON assessments(assessment_type);
CREATE INDEX idx_assessments_date ON assessments(assessment_date);