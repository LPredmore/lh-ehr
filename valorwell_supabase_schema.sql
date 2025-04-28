-- Valorwell Mental Health EHR - Initial Supabase Schema
-- Based on LibreHealth EHR, adapted for PostgreSQL and Supabase
-- Created for Valorwell

-- =============================================================================
-- SCHEMA SETUP
-- =============================================================================

-- Create schema for application
CREATE SCHEMA IF NOT EXISTS valorwell;

-- Enable necessary extensions in public schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA public;

-- Set search path
SET search_path TO valorwell, public;

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
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
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
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
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
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
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
-- Table: appointment_reminders
-- Description: Stores appointment reminder settings and status
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS appointment_reminders (
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  reminder_type VARCHAR(20) NOT NULL, -- email, sms, both
  reminder_time TIMESTAMPTZ NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, sent, failed
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- -----------------------------------------------------
-- Table: clinical_notes
-- Description: Stores SOAP and other clinical documentation
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS clinical_notes (
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
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
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
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
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
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
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
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
-- -----------------------------------------------------
-- Table: documents
-- Description: Stores patient documents
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  document_type VARCHAR(100) NOT NULL, -- consent, assessment, report, etc.
  filename VARCHAR(255) NOT NULL,
  file_path VARCHAR(2000) NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  file_size INT NOT NULL,
  description TEXT,
  is_signed BOOLEAN DEFAULT FALSE,
  signed_at TIMESTAMPTZ,
  signed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- Table: messages
-- Description: Stores secure messages between patients and providers
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  thread_id UUID NOT NULL,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES patients(id) ON DELETE CASCADE,
  subject VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- Table: telehealth_sessions
-- Description: Stores telehealth session details
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS telehealth_sessions (
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  provider_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_url VARCHAR(2000) NOT NULL,
  provider_joined_at TIMESTAMPTZ,
  patient_joined_at TIMESTAMPTZ,
  session_started_at TIMESTAMPTZ,
  session_ended_at TIMESTAMPTZ,
  duration INT, -- Duration in minutes
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled', -- scheduled, in-progress, completed, failed, cancelled
  technical_issues TEXT,
  recording_url VARCHAR(2000),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------
-- Table: audit_log
-- Description: Stores system audit logs
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(50) NOT NULL, -- create, read, update, delete, login, logout, etc.
  table_name VARCHAR(100) NOT NULL,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address VARCHAR(45),
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
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

-- Documents indexes
CREATE INDEX idx_documents_patient ON documents(patient_id);
CREATE INDEX idx_documents_type ON documents(document_type);

-- Messages indexes
CREATE INDEX idx_messages_thread ON messages(thread_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_recipient ON messages(recipient_id);
CREATE INDEX idx_messages_patient ON messages(patient_id);
CREATE INDEX idx_messages_read ON messages(is_read);

-- Telehealth sessions indexes
CREATE INDEX idx_telehealth_appointment ON telehealth_sessions(appointment_id);
CREATE INDEX idx_telehealth_patient ON telehealth_sessions(patient_id);
CREATE INDEX idx_telehealth_provider ON telehealth_sessions(provider_id);
CREATE INDEX idx_telehealth_status ON telehealth_sessions(status);

-- Audit log indexes
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_table ON audit_log(table_name);
CREATE INDEX idx_audit_log_record ON audit_log(record_id);
CREATE INDEX idx_audit_log_created ON audit_log(created_at);
-- =============================================================================
-- FUNCTIONS AND TRIGGERS
-- =============================================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the updated_at trigger to all tables with updated_at column
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE column_name = 'updated_at' 
        AND table_schema = 'valorwell'
    LOOP
        EXECUTE format('CREATE TRIGGER set_updated_at
                        BEFORE UPDATE ON valorwell.%I
                        FOR EACH ROW
                        EXECUTE FUNCTION update_updated_at_column()', t);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to log audit events
CREATE OR REPLACE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    record_id UUID;
    action_type VARCHAR(50);
BEGIN
    -- Determine the action type
    IF (TG_OP = 'DELETE') THEN
        record_id = OLD.id;
        action_type = 'delete';
    ELSIF (TG_OP = 'UPDATE') THEN
        record_id = NEW.id;
        action_type = 'update';
    ELSIF (TG_OP = 'INSERT') THEN
        record_id = NEW.id;
        action_type = 'create';
    END IF;

    -- Insert audit log
    INSERT INTO valorwell.audit_log (
        user_id,
        action,
        table_name,
        record_id,
        old_data,
        new_data,
        ip_address
    ) VALUES (
        NULLIF(current_setting('request.jwt.claims', true)::json->>'sub', '')::UUID,
        action_type,
        TG_TABLE_NAME,
        record_id,
        CASE WHEN TG_OP = 'DELETE' OR TG_OP = 'UPDATE' 
             THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' 
             THEN to_jsonb(NEW) ELSE NULL END,
        NULLIF(current_setting('request.headers', true)::json->>'x-forwarded-for', '')
    );

    -- Return the appropriate record based on operation
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Apply audit logging to important tables
CREATE TRIGGER audit_patients_trigger
AFTER INSERT OR UPDATE OR DELETE ON patients
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

CREATE TRIGGER audit_clinical_notes_trigger
AFTER INSERT OR UPDATE OR DELETE ON clinical_notes
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

CREATE TRIGGER audit_care_plans_trigger
AFTER INSERT OR UPDATE OR DELETE ON care_plans
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

CREATE TRIGGER audit_medications_trigger
AFTER INSERT OR UPDATE OR DELETE ON medications
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

CREATE TRIGGER audit_appointments_trigger
AFTER INSERT OR UPDATE OR DELETE ON appointments
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

-- Function to handle appointment status changes
CREATE OR REPLACE FUNCTION handle_appointment_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- If appointment is marked as completed, create an empty clinical note
    IF (NEW.status = 'completed' AND (OLD.status != 'completed' OR OLD.status IS NULL)) THEN
        INSERT INTO valorwell.clinical_notes (
            patient_id,
            appointment_id,
            provider_id,
            note_type
        ) VALUES (
            NEW.patient_id,
            NEW.id,
            NEW.provider_id,
            CASE 
                WHEN NEW.is_telehealth THEN 'telehealth'
                ELSE 'in-person'
            END
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply appointment status change trigger
CREATE TRIGGER appointment_status_change_trigger
AFTER UPDATE ON appointments
FOR EACH ROW
WHEN (NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION handle_appointment_status_change();
-- =============================================================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE care_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE telehealth_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Create policies for users table
CREATE POLICY users_admin_all ON users
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY users_self ON users
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY users_provider_read ON users
    TO authenticated
    USING (
        (auth.jwt() ->> 'role' IN ('provider', 'staff')) AND
        (role != 'admin')
    );

-- Create policies for patients table
CREATE POLICY patients_admin_all ON patients
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY patients_provider_all ON patients
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        (primary_provider_id = auth.uid() OR EXISTS (
            SELECT 1 FROM appointments 
            WHERE appointments.patient_id = patients.id 
            AND appointments.provider_id = auth.uid()
        ))
    );

CREATE POLICY patients_staff_read ON patients
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'staff');

CREATE POLICY patients_self ON patients
    TO authenticated
    USING (auth_id = auth.uid());

-- Create policies for appointments table
CREATE POLICY appointments_admin_all ON appointments
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY appointments_provider ON appointments
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        provider_id = auth.uid()
    );

CREATE POLICY appointments_staff ON appointments
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'staff');

CREATE POLICY appointments_patient ON appointments
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'patient' AND
        EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = appointments.patient_id 
            AND patients.auth_id = auth.uid()
        )
    );

-- Create policies for clinical_notes table
CREATE POLICY clinical_notes_admin_all ON clinical_notes
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY clinical_notes_provider ON clinical_notes
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        (provider_id = auth.uid() OR EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = clinical_notes.patient_id 
            AND patients.primary_provider_id = auth.uid()
        ))
    );

CREATE POLICY clinical_notes_staff_read ON clinical_notes
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'staff' AND
        is_signed = true
    );

-- Create policies for care_plans table
CREATE POLICY care_plans_admin_all ON care_plans
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY care_plans_provider ON care_plans
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        (provider_id = auth.uid() OR EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = care_plans.patient_id 
            AND patients.primary_provider_id = auth.uid()
        ))
    );

CREATE POLICY care_plans_staff_read ON care_plans
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'staff');

CREATE POLICY care_plans_patient ON care_plans
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'patient' AND
        EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = care_plans.patient_id 
            AND patients.auth_id = auth.uid()
        )
    );

-- Create policies for medications table
CREATE POLICY medications_admin_all ON medications
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY medications_provider ON medications
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        (provider_id = auth.uid() OR EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = medications.patient_id 
            AND patients.primary_provider_id = auth.uid()
        ))
    );

CREATE POLICY medications_staff_read ON medications
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'staff');

CREATE POLICY medications_patient ON medications
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'patient' AND
        EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = medications.patient_id 
            AND patients.auth_id = auth.uid()
        )
    );

-- Create policies for assessments table
CREATE POLICY assessments_admin_all ON assessments
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY assessments_provider ON assessments
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        (provider_id = auth.uid() OR EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = assessments.patient_id 
            AND patients.primary_provider_id = auth.uid()
        ))
    );

CREATE POLICY assessments_staff_read ON assessments
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'staff');

CREATE POLICY assessments_patient ON assessments
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'patient' AND
        EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = assessments.patient_id 
            AND patients.auth_id = auth.uid()
        )
    );

-- Create policies for documents table
CREATE POLICY documents_admin_all ON documents
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY documents_provider ON documents
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        (uploaded_by = auth.uid() OR EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = documents.patient_id 
            AND patients.primary_provider_id = auth.uid()
        ))
    );

CREATE POLICY documents_staff_read ON documents
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'staff');

CREATE POLICY documents_patient ON documents
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'patient' AND
        EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = documents.patient_id 
            AND patients.auth_id = auth.uid()
        )
    );

-- Create policies for messages table
CREATE POLICY messages_admin_all ON messages
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY messages_sender ON messages
    TO authenticated
    USING (sender_id = auth.uid());

CREATE POLICY messages_recipient ON messages
    TO authenticated
    USING (recipient_id = auth.uid());

-- Create policies for telehealth_sessions table
CREATE POLICY telehealth_admin_all ON telehealth_sessions
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY telehealth_provider ON telehealth_sessions
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'provider' AND
        provider_id = auth.uid()
    );

CREATE POLICY telehealth_staff_read ON telehealth_sessions
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'staff');

CREATE POLICY telehealth_patient ON telehealth_sessions
    TO authenticated
    USING (
        auth.jwt() ->> 'role' = 'patient' AND
        EXISTS (
            SELECT 1 FROM patients 
            WHERE patients.id = telehealth_sessions.patient_id 
            AND patients.auth_id = auth.uid()
        )
    );

-- Create policies for audit_log table
CREATE POLICY audit_log_admin_all ON audit_log
    TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin');

CREATE POLICY audit_log_user ON audit_log
    TO authenticated
    USING (user_id = auth.uid());
-- =============================================================================
-- INITIAL DATA
-- =============================================================================

-- Insert initial admin user (password will be set through Supabase Auth)
INSERT INTO users (
    username,
    email,
    role,
    first_name,
    last_name,
    is_active
) VALUES (
    'admin',
    'admin@valorwell.com',
    'admin',
    'System',
    'Administrator',
    TRUE
);

-- =============================================================================
-- VIEWS
-- =============================================================================

-- View for upcoming appointments
CREATE OR REPLACE VIEW upcoming_appointments AS
SELECT 
    a.id,
    a.start_time,
    a.end_time,
    a.appointment_type,
    a.is_telehealth,
    a.status,
    p.id AS patient_id,
    p.first_name AS patient_first_name,
    p.last_name AS patient_last_name,
    u.id AS provider_id,
    u.first_name AS provider_first_name,
    u.last_name AS provider_last_name
FROM 
    appointments a
JOIN 
    patients p ON a.patient_id = p.id
JOIN 
    users u ON a.provider_id = u.id
WHERE 
    a.start_time > NOW()
    AND a.status IN ('scheduled', 'confirmed')
ORDER BY 
    a.start_time ASC;

-- View for patient summary
CREATE OR REPLACE VIEW patient_summary AS
SELECT 
    p.id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.gender,
    p.email,
    p.phone_cell,
    u.first_name AS provider_first_name,
    u.last_name AS provider_last_name,
    (
        SELECT COUNT(*) 
        FROM appointments 
        WHERE patient_id = p.id
    ) AS appointment_count,
    (
        SELECT COUNT(*) 
        FROM clinical_notes 
        WHERE patient_id = p.id
    ) AS note_count,
    (
        SELECT COUNT(*) 
        FROM medications 
        WHERE patient_id = p.id AND status = 'active'
    ) AS active_medications_count,
    (
        SELECT MAX(assessment_date) 
        FROM assessments 
        WHERE patient_id = p.id
    ) AS last_assessment_date
FROM 
    patients p
LEFT JOIN 
    users u ON p.primary_provider_id = u.id;

-- View for provider caseload
CREATE OR REPLACE VIEW provider_caseload AS
SELECT 
    u.id AS provider_id,
    u.first_name,
    u.last_name,
    COUNT(DISTINCT p.id) AS patient_count,
    COUNT(DISTINCT a.id) AS upcoming_appointment_count,
    COUNT(DISTINCT CASE WHEN a.start_time::date = CURRENT_DATE THEN a.id END) AS today_appointment_count
FROM 
    users u
LEFT JOIN 
    patients p ON u.id = p.primary_provider_id
LEFT JOIN 
    appointments a ON u.id = a.provider_id AND a.start_time > NOW() AND a.status IN ('scheduled', 'confirmed')
WHERE 
    u.role = 'provider'
GROUP BY 
    u.id, u.first_name, u.last_name;

-- View for telehealth dashboard
CREATE OR REPLACE VIEW telehealth_dashboard AS
SELECT 
    a.id AS appointment_id,
    a.start_time,
    a.end_time,
    p.id AS patient_id,
    p.first_name AS patient_first_name,
    p.last_name AS patient_last_name,
    u.id AS provider_id,
    u.first_name AS provider_first_name,
    u.last_name AS provider_last_name,
    ts.id AS telehealth_session_id,
    ts.status AS telehealth_status,
    ts.session_url
FROM 
    appointments a
JOIN 
    patients p ON a.patient_id = p.id
JOIN 
    users u ON a.provider_id = u.id
LEFT JOIN 
    telehealth_sessions ts ON a.id = ts.appointment_id
WHERE 
    a.is_telehealth = TRUE
    AND a.start_time > NOW() - INTERVAL '1 day'
    AND a.start_time < NOW() + INTERVAL '7 days'
ORDER BY 
    a.start_time ASC;