class CreateRecallCandidatesView < ActiveRecord::Migration[7.2]
  def up
    execute <<-SQL
      CREATE MATERIALIZED VIEW recall_candidates AS
      SELECT 
        p.id as patient_id,
        p.patient_number,
        p.name,
        p.name_kana,
        p.phone_number,
        p.email,
        p.line_user_id,
        p.birth_date,
        MAX(a.appointment_date) as last_appointment_date,
        COUNT(a.id) as total_appointments,
        COUNT(CASE WHEN a.status = 'visited' THEN 1 END) as visited_appointments,
        COUNT(CASE WHEN a.status = 'no_show' THEN 1 END) as no_show_count,
        EXTRACT(days FROM NOW() - MAX(a.appointment_date)) as days_since_last_visit,
        CASE 
          WHEN MAX(a.appointment_date) < NOW() - INTERVAL '6 months' THEN 'high'
          WHEN MAX(a.appointment_date) < NOW() - INTERVAL '4 months' THEN 'medium'
          WHEN MAX(a.appointment_date) < NOW() - INTERVAL '3 months' THEN 'low'
          ELSE 'none'
        END as recall_priority,
        CASE
          WHEN COUNT(CASE WHEN a.status = 'no_show' THEN 1 END) >= 3 THEN 'high_risk'
          WHEN COUNT(CASE WHEN a.status = 'no_show' THEN 1 END) >= 1 THEN 'medium_risk'
          ELSE 'low_risk'
        END as patient_risk_level,
        p.preferred_contact_method,
        p.notes,
        p.created_at as patient_created_at,
        p.updated_at as patient_updated_at
      FROM patients p
      LEFT JOIN appointments a ON p.id = a.patient_id 
        AND a.status IN ('visited', 'completed', 'paid')
        AND a.discarded_at IS NULL
      WHERE p.discarded_at IS NULL
        AND p.status = 'active'
      GROUP BY 
        p.id, p.patient_number, p.name, p.name_kana, p.phone_number, 
        p.email, p.line_user_id, p.birth_date, p.preferred_contact_method,
        p.notes, p.created_at, p.updated_at
      HAVING MAX(a.appointment_date) IS NOT NULL
        AND MAX(a.appointment_date) < NOW() - INTERVAL '3 months'
      ORDER BY 
        CASE 
          WHEN MAX(a.appointment_date) < NOW() - INTERVAL '6 months' THEN 1
          WHEN MAX(a.appointment_date) < NOW() - INTERVAL '4 months' THEN 2
          WHEN MAX(a.appointment_date) < NOW() - INTERVAL '3 months' THEN 3
          ELSE 4
        END,
        MAX(a.appointment_date) ASC
    SQL

    # インデックスを追加
    add_index :recall_candidates, :patient_id, unique: true
    add_index :recall_candidates, :recall_priority
    add_index :recall_candidates, :patient_risk_level
    add_index :recall_candidates, :last_appointment_date
    add_index :recall_candidates, :days_since_last_visit
  end

  def down
    drop_table :recall_candidates, force: :cascade
  end
end