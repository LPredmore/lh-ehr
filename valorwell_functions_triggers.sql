-- =============================================================================
-- VALORWELL EHR SYSTEM - FUNCTIONS AND TRIGGERS
-- =============================================================================
-- This script implements essential functions and triggers for the Valorwell
-- Mental Health EHR system in Supabase, including:
--   1. Updated timestamp triggers
--   2. Appointment status change triggers
--   3. Audit logging functionality
--   4. Additional useful functions and triggers
-- =============================================================================

-- =============================================================================
-- PART 1: UPDATED TIMESTAMP TRIGGERS
-- =============================================================================
-- These triggers automatically update the updated_at column whenever a record
-- is modified in any table that has this column.

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the timestamp update trigger to all relevant tables
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patients_updated_at
    BEFORE UPDATE ON patients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_appointments_updated_at
    BEFORE UPDATE ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clinical_notes_updated_at
    BEFORE UPDATE ON clinical_notes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_care_plans_updated_at
    BEFORE UPDATE ON care_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_medications_updated_at
    BEFORE UPDATE ON medications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assessments_updated_at
    BEFORE UPDATE ON assessments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PART 2: APPOINTMENT STATUS CHANGE TRIGGER
-- =============================================================================
-- This trigger automatically creates a clinical note when an appointment is
-- marked as completed.

-- Function to create a clinical note when appointment status changes to 'completed'
CREATE OR REPLACE FUNCTION create_clinical_note_on_appointment_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- Only proceed if status changed to 'completed'
    IF NEW.status = 'completed' AND (OLD.status != 'completed' OR OLD.status IS NULL) THEN
        -- Insert a new clinical note
        INSERT INTO clinical_notes (
            patient_id,
            appointment_id,
            provider_id,
            note_type,
            subjective,
            created_at,
            updated_at
        ) VALUES (
            NEW.patient_id,
            NEW.id,
            NEW.provider_id,
            'soap',
            'Auto-generated note for completed appointment. Please update with session details.',
            NOW(),
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger on the appointments table
CREATE TRIGGER appointment_completion_trigger
    AFTER UPDATE ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION create_clinical_note_on_appointment_completion();

-- =============================================================================
-- PART 3: AUDIT LOGGING FUNCTIONALITY
-- =============================================================================
-- This section implements audit logging to track changes to sensitive data.

-- Create audit_logs table to store audit records
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action TEXT NOT NULL, -- INSERT, UPDATE, DELETE
    changed_data JSONB,
    previous_data JSONB,
    changed_by UUID, -- User who made the change
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for the audit_logs table
CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_record_id ON audit_logs(record_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_changed_by ON audit_logs(changed_by);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- Function to record audit logs
CREATE OR REPLACE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    changed_fields JSONB := '{}'::JSONB;
    previous_fields JSONB := '{}'::JSONB;
    excluded_fields TEXT[] := ARRAY['created_at', 'updated_at']; -- Fields to exclude from audit
    current_user_id UUID;
BEGIN
    -- Get current user ID if available
    BEGIN
        current_user_id := (SELECT id FROM users WHERE auth_id = auth.uid());
    EXCEPTION WHEN OTHERS THEN
        current_user_id := NULL;
    END;
    
    -- Handle different operations
    IF (TG_OP = 'UPDATE') THEN
        -- For each field, check if it changed and add to changed_fields
        FOR i IN 0..jsonb_object_agg(NEW)::JSONB ? '*' LOOP
            IF NOT (TG_ARGV[0]::TEXT[] @> ARRAY[i::TEXT]) AND OLD->>i IS DISTINCT FROM NEW->>i THEN
                changed_fields := changed_fields || jsonb_build_object(i, NEW->>i);
                previous_fields := previous_fields || jsonb_build_object(i, OLD->>i);
            END IF;
        END LOOP;
        
        -- Only log if there are actual changes (excluding excluded fields)
        IF changed_fields != '{}'::JSONB THEN
            INSERT INTO audit_logs (
                table_name,
                record_id,
                action,
                changed_data,
                previous_data,
                changed_by,
                ip_address,
                user_agent,
                created_at
            ) VALUES (
                TG_TABLE_NAME,
                (NEW.id)::UUID,
                TG_OP,
                changed_fields,
                previous_fields,
                current_user_id,
                current_setting('request.headers', true)::jsonb->>'x-forwarded-for',
                current_setting('request.headers', true)::jsonb->>'user-agent',
                NOW()
            );
        END IF;
        
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        -- For inserts, log all fields except excluded ones
        FOR i IN 0..jsonb_object_agg(NEW)::JSONB ? '*' LOOP
            IF NOT (excluded_fields @> ARRAY[i::TEXT]) THEN
                changed_fields := changed_fields || jsonb_build_object(i, NEW->>i);
            END IF;
        END LOOP;
        
        INSERT INTO audit_logs (
            table_name,
            record_id,
            action,
            changed_data,
            previous_data,
            changed_by,
            ip_address,
            user_agent,
            created_at
        ) VALUES (
            TG_TABLE_NAME,
            (NEW.id)::UUID,
            TG_OP,
            changed_fields,
            NULL,
            current_user_id,
            current_setting('request.headers', true)::jsonb->>'x-forwarded-for',
            current_setting('request.headers', true)::jsonb->>'user-agent',
            NOW()
        );
        
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- For deletes, log all fields as previous data
        FOR i IN 0..jsonb_object_agg(OLD)::JSONB ? '*' LOOP
            IF NOT (excluded_fields @> ARRAY[i::TEXT]) THEN
                previous_fields := previous_fields || jsonb_build_object(i, OLD->>i);
            END IF;
        END LOOP;
        
        INSERT INTO audit_logs (
            table_name,
            record_id,
            action,
            changed_data,
            previous_data,
            changed_by,
            ip_address,
            user_agent,
            created_at
        ) VALUES (
            TG_TABLE_NAME,
            (OLD.id)::UUID,
            TG_OP,
            NULL,
            previous_fields,
            current_user_id,
            current_setting('request.headers', true)::jsonb->>'x-forwarded-for',
            current_setting('request.headers', true)::jsonb->>'user-agent',
            NOW()
        );
        
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit logging triggers to sensitive tables

-- Clinical notes audit
CREATE TRIGGER clinical_notes_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON clinical_notes
    FOR EACH ROW
    EXECUTE FUNCTION log_audit_event();

-- Medications audit
CREATE TRIGGER medications_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON medications
    FOR EACH ROW
    EXECUTE FUNCTION log_audit_event();

-- Care plans audit
CREATE TRIGGER care_plans_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON care_plans
    FOR EACH ROW
    EXECUTE FUNCTION log_audit_event();

-- Assessments audit
CREATE TRIGGER assessments_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON assessments
    FOR EACH ROW
    EXECUTE FUNCTION log_audit_event();

-- Patient data audit (for sensitive fields)
CREATE TRIGGER patients_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON patients
    FOR EACH ROW
    EXECUTE FUNCTION log_audit_event();

-- =============================================================================
-- PART 4: ADDITIONAL USEFUL FUNCTIONS AND TRIGGERS
-- =============================================================================
-- This section implements additional useful functions and triggers specific to
-- mental health EHR systems.

-- 1. Function to check if a patient has upcoming appointments
CREATE OR REPLACE FUNCTION patient_has_upcoming_appointments(patient_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM appointments
        WHERE patient_id = patient_uuid
        AND start_time > NOW()
        AND status IN ('scheduled', 'confirmed')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function to get a patient's most recent assessment of a specific type
CREATE OR REPLACE FUNCTION get_latest_assessment(patient_uuid UUID, assessment_type_param VARCHAR)
RETURNS TABLE (
    id UUID,
    assessment_date DATE,
    score INT,
    interpretation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.assessment_date, a.score, a.interpretation
    FROM assessments a
    WHERE a.patient_id = patient_uuid
    AND a.assessment_type = assessment_type_param
    ORDER BY a.assessment_date DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Function to calculate days since last appointment
CREATE OR REPLACE FUNCTION days_since_last_appointment(patient_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    last_appt_date TIMESTAMPTZ;
BEGIN
    SELECT MAX(end_time) INTO last_appt_date
    FROM appointments
    WHERE patient_id = patient_uuid
    AND status = 'completed';
    
    IF last_appt_date IS NULL THEN
        RETURN NULL;
    ELSE
        RETURN EXTRACT(DAY FROM NOW() - last_appt_date)::INTEGER;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger to automatically lock clinical notes after a certain period
CREATE OR REPLACE FUNCTION auto_lock_clinical_notes()
RETURNS TRIGGER AS $$
BEGIN
    -- If note is signed and not locked, and was signed more than 7 days ago, lock it
    IF NEW.is_signed = TRUE AND NEW.is_locked = FALSE AND 
       NEW.signed_at < (NOW() - INTERVAL '7 days') THEN
        NEW.is_locked := TRUE;
        NEW.locked_at := NOW();
        NEW.locked_by := NEW.provider_id; -- Lock by the provider who signed it
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger on clinical_notes
CREATE TRIGGER auto_lock_clinical_notes_trigger
    BEFORE UPDATE ON clinical_notes
    FOR EACH ROW
    EXECUTE FUNCTION auto_lock_clinical_notes();

-- 5. Function to automatically create a follow-up appointment
CREATE OR REPLACE FUNCTION create_followup_appointment(
    appointment_id UUID,
    days_until_followup INTEGER DEFAULT 14
)
RETURNS UUID AS $$
DECLARE
    current_appt appointments%ROWTYPE;
    followup_id UUID;
    followup_start TIMESTAMPTZ;
    followup_end TIMESTAMPTZ;
BEGIN
    -- Get the current appointment details
    SELECT * INTO current_appt
    FROM appointments
    WHERE id = appointment_id;
    
    -- Calculate the follow-up appointment time (same day of week, same time)
    followup_start := current_appt.start_time + (days_until_followup * INTERVAL '1 day');
    followup_end := current_appt.end_time + (days_until_followup * INTERVAL '1 day');
    
    -- Insert the follow-up appointment
    INSERT INTO appointments (
        patient_id,
        provider_id,
        appointment_type,
        start_time,
        end_time,
        duration,
        status,
        location,
        room,
        notes,
        is_telehealth,
        telehealth_url,
        telehealth_provider,
        created_at,
        updated_at
    ) VALUES (
        current_appt.patient_id,
        current_appt.provider_id,
        current_appt.appointment_type,
        followup_start,
        followup_end,
        current_appt.duration,
        'scheduled',
        current_appt.location,
        current_appt.room,
        'Follow-up appointment automatically scheduled',
        current_appt.is_telehealth,
        current_appt.telehealth_url,
        current_appt.telehealth_provider,
        NOW(),
        NOW()
    )
    RETURNING id INTO followup_id;
    
    RETURN followup_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Function to check for medication interactions
CREATE OR REPLACE FUNCTION check_medication_interactions(patient_uuid UUID, new_medication VARCHAR)
RETURNS TABLE (
    medication_name VARCHAR,
    potential_interaction TEXT
) AS $$
BEGIN
    -- This is a simplified placeholder function
    -- In a real implementation, this would check against a medication interaction database
    RETURN QUERY
    SELECT 
        m.medication_name,
        'Potential interaction with ' || new_medication || '. Please review.' AS potential_interaction
    FROM medications m
    WHERE m.patient_id = patient_uuid
    AND m.status = 'active'
    -- In a real implementation, you would have logic here to determine actual interactions
    -- This is just returning all active medications as potential interactions for demonstration
    AND m.medication_name != new_medication;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Trigger to notify providers of high-risk assessment scores
CREATE OR REPLACE FUNCTION notify_on_high_risk_assessment()
RETURNS TRIGGER AS $$
DECLARE
    high_risk_threshold INTEGER;
    provider_email TEXT;
BEGIN
    -- Set threshold based on assessment type
    IF NEW.assessment_type = 'PHQ-9' THEN
        high_risk_threshold := 15; -- Moderately severe depression
    ELSIF NEW.assessment_type = 'GAD-7' THEN
        high_risk_threshold := 15; -- Severe anxiety
    ELSE
        high_risk_threshold := NULL; -- No threshold for other types
    END IF;
    
    -- Check if score exceeds threshold
    IF high_risk_threshold IS NOT NULL AND NEW.score >= high_risk_threshold THEN
        -- Get provider email
        SELECT email INTO provider_email
        FROM users
        WHERE id = NEW.provider_id;
        
        -- In Supabase, you would typically use pg_notify or a similar mechanism
        -- This is a placeholder for demonstration
        PERFORM pg_notify(
            'high_risk_assessment',
            json_build_object(
                'patient_id', NEW.patient_id,
                'assessment_type', NEW.assessment_type,
                'score', NEW.score,
                'provider_email', provider_email
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger on assessments
CREATE TRIGGER high_risk_assessment_notification_trigger
    AFTER INSERT ON assessments
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_high_risk_assessment();

-- 8. Function to generate a summary of patient activity
CREATE OR REPLACE FUNCTION generate_patient_summary(patient_uuid UUID)
RETURNS JSONB AS $$
DECLARE
    summary JSONB;
BEGIN
    SELECT
        jsonb_build_object(
            'patient_id', p.id,
            'patient_name', p.first_name || ' ' || p.last_name,
            'date_of_birth', p.date_of_birth,
            'age', EXTRACT(YEAR FROM age(p.date_of_birth)),
            'primary_provider', u.first_name || ' ' || u.last_name,
            'last_appointment', (
                SELECT to_char(MAX(end_time), 'YYYY-MM-DD')
                FROM appointments
                WHERE patient_id = p.id
                AND status = 'completed'
            ),
            'next_appointment', (
                SELECT to_char(MIN(start_time), 'YYYY-MM-DD HH:MI AM')
                FROM appointments
                WHERE patient_id = p.id
                AND start_time > NOW()
                AND status IN ('scheduled', 'confirmed')
            ),
            'active_medications', (
                SELECT jsonb_agg(jsonb_build_object('name', medication_name, 'dosage', dosage, 'frequency', frequency))
                FROM medications
                WHERE patient_id = p.id
                AND status = 'active'
            ),
            'recent_assessments', (
                SELECT jsonb_agg(jsonb_build_object('type', assessment_type, 'date', assessment_date, 'score', score))
                FROM assessments
                WHERE patient_id = p.id
                ORDER BY assessment_date DESC
                LIMIT 5
            ),
            'care_plan_status', (
                SELECT status
                FROM care_plans
                WHERE patient_id = p.id
                ORDER BY updated_at DESC
                LIMIT 1
            )
        ) INTO summary
    FROM patients p
    LEFT JOIN users u ON p.primary_provider_id = u.id
    WHERE p.id = patient_uuid;
    
    RETURN summary;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PART 5: RLS POLICIES FOR AUDIT LOGS
-- =============================================================================
-- This section implements RLS policies for the audit_logs table.

-- Enable RLS on audit_logs table
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Admin can view all audit logs
CREATE POLICY audit_logs_view_admin ON audit_logs
  FOR SELECT
  USING (is_admin());

-- Providers can view audit logs for their patients
CREATE POLICY audit_logs_view_provider ON audit_logs
  FOR SELECT
  USING (
    is_provider() AND EXISTS (
      SELECT 1
      FROM patients p
      WHERE p.primary_provider_id = current_user_id()
      AND audit_logs.table_name = 'patients'
      AND audit_logs.record_id = p.id
    )
  );

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================