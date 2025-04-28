-- =============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES FOR VALORWELL EHR
-- =============================================================================
-- This script implements comprehensive Row Level Security policies for the
-- Valorwell Mental Health EHR system in Supabase.
--
-- Access patterns:
-- - Admins: Full access to all records
-- - Providers: Access to their own records and records of their patients
-- - Staff: View most records with limited edit capabilities
-- - Patients: Access only to their own records
-- =============================================================================

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Function to check if current user is an admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT role = 'admin'
    FROM users
    WHERE auth_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is a provider
CREATE OR REPLACE FUNCTION is_provider()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT role = 'provider'
    FROM users
    WHERE auth_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is staff
CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT role = 'staff'
    FROM users
    WHERE auth_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is a patient
CREATE OR REPLACE FUNCTION is_patient()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM patients
    WHERE auth_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get the current user's ID from the users table
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
BEGIN
  RETURN (
    SELECT id
    FROM users
    WHERE auth_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get the current patient's ID
CREATE OR REPLACE FUNCTION current_patient_id()
RETURNS UUID AS $$
BEGIN
  RETURN (
    SELECT id
    FROM patients
    WHERE auth_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a patient belongs to a provider
CREATE OR REPLACE FUNCTION is_provider_patient(patient_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM patients
    WHERE id = patient_uuid
    AND primary_provider_id = current_user_id()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- =============================================================================

-- Enable RLS on users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Enable RLS on patients table
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

-- Enable RLS on appointments table
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- Enable RLS on clinical_notes table
ALTER TABLE clinical_notes ENABLE ROW LEVEL SECURITY;

-- Enable RLS on care_plans table
ALTER TABLE care_plans ENABLE ROW LEVEL SECURITY;

-- Enable RLS on medications table
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;

-- Enable RLS on assessments table
ALTER TABLE assessments ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- USERS TABLE POLICIES
-- =============================================================================

-- Admin can view all users
CREATE POLICY users_view_admin ON users
  FOR SELECT
  USING (is_admin());

-- Admin can insert new users
CREATE POLICY users_insert_admin ON users
  FOR INSERT
  WITH CHECK (is_admin());

-- Admin can update any user
CREATE POLICY users_update_admin ON users
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can delete any user
CREATE POLICY users_delete_admin ON users
  FOR DELETE
  USING (is_admin());

-- Providers can view their own record and basic info of other providers/staff
CREATE POLICY users_view_provider ON users
  FOR SELECT
  USING (
    is_provider() AND (
      auth_id = auth.uid() OR
      role = 'provider' OR
      role = 'staff'
    )
  );

-- Providers can update their own record
CREATE POLICY users_update_provider ON users
  FOR UPDATE
  USING (is_provider() AND auth_id = auth.uid())
  WITH CHECK (is_provider() AND auth_id = auth.uid());

-- Staff can view their own record and basic info of providers
CREATE POLICY users_view_staff ON users
  FOR SELECT
  USING (
    is_staff() AND (
      auth_id = auth.uid() OR
      role = 'provider'
    )
  );

-- Staff can update their own record
CREATE POLICY users_update_staff ON users
  FOR UPDATE
  USING (is_staff() AND auth_id = auth.uid())
  WITH CHECK (is_staff() AND auth_id = auth.uid());

-- Patients can view basic provider information
CREATE POLICY users_view_patient ON users
  FOR SELECT
  USING (
    is_patient() AND
    role = 'provider'
  );

-- =============================================================================
-- PATIENTS TABLE POLICIES
-- =============================================================================

-- Admin can view all patients
CREATE POLICY patients_view_admin ON patients
  FOR SELECT
  USING (is_admin());

-- Admin can insert new patients
CREATE POLICY patients_insert_admin ON patients
  FOR INSERT
  WITH CHECK (is_admin());

-- Admin can update any patient
CREATE POLICY patients_update_admin ON patients
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can delete any patient
CREATE POLICY patients_delete_admin ON patients
  FOR DELETE
  USING (is_admin());

-- Providers can view their own patients
CREATE POLICY patients_view_provider ON patients
  FOR SELECT
  USING (
    is_provider() AND (
      primary_provider_id = current_user_id()
    )
  );

-- Providers can insert new patients assigned to themselves
CREATE POLICY patients_insert_provider ON patients
  FOR INSERT
  WITH CHECK (
    is_provider() AND
    primary_provider_id = current_user_id()
  );

-- Providers can update their own patients
CREATE POLICY patients_update_provider ON patients
  FOR UPDATE
  USING (
    is_provider() AND
    primary_provider_id = current_user_id()
  )
  WITH CHECK (
    is_provider() AND
    primary_provider_id = current_user_id()
  );

-- Staff can view all patients
CREATE POLICY patients_view_staff ON patients
  FOR SELECT
  USING (is_staff());

-- Staff can insert new patients
CREATE POLICY patients_insert_staff ON patients
  FOR INSERT
  WITH CHECK (is_staff());

-- Staff can update patient demographic information
CREATE POLICY patients_update_staff ON patients
  FOR UPDATE
  USING (is_staff())
  WITH CHECK (is_staff());

-- Patients can view their own record
CREATE POLICY patients_view_patient ON patients
  FOR SELECT
  USING (
    is_patient() AND
    auth_id = auth.uid()
  );

-- Patients can update limited fields of their own record
CREATE POLICY patients_update_patient ON patients
  FOR UPDATE
  USING (
    is_patient() AND
    auth_id = auth.uid()
  )
  WITH CHECK (
    is_patient() AND
    auth_id = auth.uid()
  );

-- =============================================================================
-- APPOINTMENTS TABLE POLICIES
-- =============================================================================

-- Admin can view all appointments
CREATE POLICY appointments_view_admin ON appointments
  FOR SELECT
  USING (is_admin());

-- Admin can insert new appointments
CREATE POLICY appointments_insert_admin ON appointments
  FOR INSERT
  WITH CHECK (is_admin());

-- Admin can update any appointment
CREATE POLICY appointments_update_admin ON appointments
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can delete any appointment
CREATE POLICY appointments_delete_admin ON appointments
  FOR DELETE
  USING (is_admin());

-- Providers can view their own appointments
CREATE POLICY appointments_view_provider ON appointments
  FOR SELECT
  USING (
    is_provider() AND (
      provider_id = current_user_id() OR
      is_provider_patient(patient_id)
    )
  );

-- Providers can insert appointments for themselves and their patients
CREATE POLICY appointments_insert_provider ON appointments
  FOR INSERT
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can update their own appointments
CREATE POLICY appointments_update_provider ON appointments
  FOR UPDATE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  )
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can delete their own appointments
CREATE POLICY appointments_delete_provider ON appointments
  FOR DELETE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Staff can view all appointments
CREATE POLICY appointments_view_staff ON appointments
  FOR SELECT
  USING (is_staff());

-- Staff can insert new appointments
CREATE POLICY appointments_insert_staff ON appointments
  FOR INSERT
  WITH CHECK (is_staff());

-- Staff can update appointment details
CREATE POLICY appointments_update_staff ON appointments
  FOR UPDATE
  USING (is_staff())
  WITH CHECK (is_staff());

-- Staff can delete appointments
CREATE POLICY appointments_delete_staff ON appointments
  FOR DELETE
  USING (is_staff());

-- Patients can view their own appointments
CREATE POLICY appointments_view_patient ON appointments
  FOR SELECT
  USING (
    is_patient() AND
    patient_id = current_patient_id()
  );

-- =============================================================================
-- CLINICAL_NOTES TABLE POLICIES
-- =============================================================================

-- Admin can view all clinical notes
CREATE POLICY clinical_notes_view_admin ON clinical_notes
  FOR SELECT
  USING (is_admin());

-- Admin can insert new clinical notes
CREATE POLICY clinical_notes_insert_admin ON clinical_notes
  FOR INSERT
  WITH CHECK (is_admin());

-- Admin can update any clinical note
CREATE POLICY clinical_notes_update_admin ON clinical_notes
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can delete any clinical note
CREATE POLICY clinical_notes_delete_admin ON clinical_notes
  FOR DELETE
  USING (is_admin());

-- Providers can view clinical notes for their patients
CREATE POLICY clinical_notes_view_provider ON clinical_notes
  FOR SELECT
  USING (
    is_provider() AND (
      provider_id = current_user_id() OR
      is_provider_patient(patient_id)
    )
  );

-- Providers can insert clinical notes for their patients
CREATE POLICY clinical_notes_insert_provider ON clinical_notes
  FOR INSERT
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can update their own clinical notes that aren't locked
CREATE POLICY clinical_notes_update_provider ON clinical_notes
  FOR UPDATE
  USING (
    is_provider() AND
    provider_id = current_user_id() AND
    is_locked = FALSE
  )
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id() AND
    is_locked = FALSE
  );

-- Staff can view clinical notes
CREATE POLICY clinical_notes_view_staff ON clinical_notes
  FOR SELECT
  USING (is_staff());

-- Patients can view limited clinical notes for themselves
CREATE POLICY clinical_notes_view_patient ON clinical_notes
  FOR SELECT
  USING (
    is_patient() AND
    patient_id = current_patient_id() AND
    is_signed = TRUE
  );

-- =============================================================================
-- CARE_PLANS TABLE POLICIES
-- =============================================================================

-- Admin can view all care plans
CREATE POLICY care_plans_view_admin ON care_plans
  FOR SELECT
  USING (is_admin());

-- Admin can insert new care plans
CREATE POLICY care_plans_insert_admin ON care_plans
  FOR INSERT
  WITH CHECK (is_admin());

-- Admin can update any care plan
CREATE POLICY care_plans_update_admin ON care_plans
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can delete any care plan
CREATE POLICY care_plans_delete_admin ON care_plans
  FOR DELETE
  USING (is_admin());

-- Providers can view care plans for their patients
CREATE POLICY care_plans_view_provider ON care_plans
  FOR SELECT
  USING (
    is_provider() AND (
      provider_id = current_user_id() OR
      is_provider_patient(patient_id)
    )
  );

-- Providers can insert care plans for their patients
CREATE POLICY care_plans_insert_provider ON care_plans
  FOR INSERT
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can update care plans they created
CREATE POLICY care_plans_update_provider ON care_plans
  FOR UPDATE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  )
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can delete care plans they created
CREATE POLICY care_plans_delete_provider ON care_plans
  FOR DELETE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Staff can view all care plans
CREATE POLICY care_plans_view_staff ON care_plans
  FOR SELECT
  USING (is_staff());

-- Patients can view their own care plans
CREATE POLICY care_plans_view_patient ON care_plans
  FOR SELECT
  USING (
    is_patient() AND
    patient_id = current_patient_id()
  );

-- =============================================================================
-- MEDICATIONS TABLE POLICIES
-- =============================================================================

-- Admin can view all medications
CREATE POLICY medications_view_admin ON medications
  FOR SELECT
  USING (is_admin());

-- Admin can insert new medications
CREATE POLICY medications_insert_admin ON medications
  FOR INSERT
  WITH CHECK (is_admin());

-- Admin can update any medication
CREATE POLICY medications_update_admin ON medications
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can delete any medication
CREATE POLICY medications_delete_admin ON medications
  FOR DELETE
  USING (is_admin());

-- Providers can view medications for their patients
CREATE POLICY medications_view_provider ON medications
  FOR SELECT
  USING (
    is_provider() AND (
      provider_id = current_user_id() OR
      is_provider_patient(patient_id)
    )
  );

-- Providers can insert medications for their patients
CREATE POLICY medications_insert_provider ON medications
  FOR INSERT
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can update medications they prescribed
CREATE POLICY medications_update_provider ON medications
  FOR UPDATE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  )
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can delete medications they prescribed
CREATE POLICY medications_delete_provider ON medications
  FOR DELETE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Staff can view all medications
CREATE POLICY medications_view_staff ON medications
  FOR SELECT
  USING (is_staff());

-- Patients can view their own medications
CREATE POLICY medications_view_patient ON medications
  FOR SELECT
  USING (
    is_patient() AND
    patient_id = current_patient_id()
  );

-- =============================================================================
-- ASSESSMENTS TABLE POLICIES
-- =============================================================================

-- Admin can view all assessments
CREATE POLICY assessments_view_admin ON assessments
  FOR SELECT
  USING (is_admin());

-- Admin can insert new assessments
CREATE POLICY assessments_insert_admin ON assessments
  FOR INSERT
  WITH CHECK (is_admin());

-- Admin can update any assessment
CREATE POLICY assessments_update_admin ON assessments
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Admin can delete any assessment
CREATE POLICY assessments_delete_admin ON assessments
  FOR DELETE
  USING (is_admin());

-- Providers can view assessments for their patients
CREATE POLICY assessments_view_provider ON assessments
  FOR SELECT
  USING (
    is_provider() AND (
      provider_id = current_user_id() OR
      is_provider_patient(patient_id)
    )
  );

-- Providers can insert assessments for their patients
CREATE POLICY assessments_insert_provider ON assessments
  FOR INSERT
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can update assessments they created
CREATE POLICY assessments_update_provider ON assessments
  FOR UPDATE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  )
  WITH CHECK (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Providers can delete assessments they created
CREATE POLICY assessments_delete_provider ON assessments
  FOR DELETE
  USING (
    is_provider() AND
    provider_id = current_user_id()
  );

-- Staff can view all assessments
CREATE POLICY assessments_view_staff ON assessments
  FOR SELECT
  USING (is_staff());

-- Staff can insert new assessments
CREATE POLICY assessments_insert_staff ON assessments
  FOR INSERT
  WITH CHECK (is_staff());

-- Patients can view their own assessments
CREATE POLICY assessments_view_patient ON assessments
  FOR SELECT
  USING (
    is_patient() AND
    patient_id = current_patient_id()
  );

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================