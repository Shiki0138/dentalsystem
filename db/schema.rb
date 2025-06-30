# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_06_30_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.datetime "appointment_date", null: false
    t.string "status", default: "booked", null: false
    t.text "notes"
    t.string "treatment_type", null: false
    t.decimal "duration_minutes", precision: 5, scale: 2, default: "60.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["appointment_date", "status"], name: "idx_appointments_schedule"
    t.index ["appointment_date"], name: "idx_appointments_date_range"
    t.index ["appointment_date"], name: "index_appointments_on_appointment_date"
    t.index ["discarded_at"], name: "index_appointments_on_discarded_at"
    t.index ["patient_id", "appointment_date"], name: "idx_unique_appointment_check", unique: true, where: "((status)::text <> ALL ((ARRAY['cancelled'::character varying, 'no_show'::character varying])::text[]))"
    t.index ["patient_id", "appointment_date"], name: "index_appointments_on_patient_id_and_appointment_date", unique: true
    t.index ["patient_id", "status", "appointment_date"], name: "idx_appointments_patient_status_time"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
    t.index ["status", "appointment_date"], name: "idx_appointments_status_time"
    t.index ["status"], name: "index_appointments_on_status"
    t.check_constraint "status::text = ANY (ARRAY['booked'::character varying, 'visited'::character varying, 'cancelled'::character varying, 'no_show'::character varying, 'done'::character varying, 'paid'::character varying]::text[])", name: "appointments_status_check"
  end

  create_table "clockings", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.datetime "clocked_at", null: false
    t.string "clock_type", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "location_accuracy"
    t.string "device_type"
    t.string "ip_address"
    t.text "notes"
    t.boolean "manual_entry", default: false
    t.bigint "edited_by_id"
    t.datetime "edited_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clock_type"], name: "index_clockings_on_clock_type"
    t.index ["clocked_at"], name: "index_clockings_on_clocked_at"
    t.index ["edited_by_id"], name: "index_clockings_on_edited_by_id"
    t.index ["employee_id", "clocked_at"], name: "index_clockings_on_employee_id_and_clocked_at"
    t.index ["employee_id"], name: "index_clockings_on_employee_id"
    t.index ["latitude", "longitude"], name: "index_clockings_on_latitude_and_longitude"
  end

  create_table "deliveries", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.bigint "appointment_id"
    t.string "delivery_type", null: false
    t.string "status", default: "pending", null: false
    t.string "subject"
    t.text "content", null: false
    t.datetime "sent_at"
    t.datetime "opened_at"
    t.datetime "read_at"
    t.text "error_message"
    t.integer "retry_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "scheduled_at"
    t.index ["appointment_id", "status", "delivery_type"], name: "idx_deliveries_appointment_status_type"
    t.index ["appointment_id"], name: "index_deliveries_on_appointment_id"
    t.index ["delivery_type", "status"], name: "index_deliveries_on_delivery_type_and_status"
    t.index ["delivery_type"], name: "index_deliveries_on_delivery_type"
    t.index ["patient_id"], name: "index_deliveries_on_patient_id"
    t.index ["scheduled_at", "status"], name: "index_deliveries_on_scheduled_at_and_status"
    t.index ["scheduled_at"], name: "index_deliveries_on_scheduled_at"
    t.index ["sent_at"], name: "idx_deliveries_sent"
    t.index ["sent_at"], name: "index_deliveries_on_sent_at"
    t.index ["status", "created_at"], name: "index_deliveries_on_status_and_created_at"
    t.index ["status"], name: "index_deliveries_on_status"
    t.check_constraint "delivery_type::text = ANY (ARRAY['line'::character varying, 'email'::character varying, 'sms'::character varying]::text[])", name: "deliveries_type_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'sent'::character varying, 'failed'::character varying, 'opened'::character varying, 'read'::character varying]::text[])", name: "deliveries_status_check"
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_code", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "first_name_kana"
    t.string "last_name_kana"
    t.string "email", null: false
    t.string "phone"
    t.string "employment_type", null: false
    t.date "hire_date", null: false
    t.date "resignation_date"
    t.string "position"
    t.decimal "base_salary", precision: 10, scale: 2
    t.decimal "hourly_rate", precision: 8, scale: 2
    t.boolean "active", default: true, null: false
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_employees_on_active"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["employee_code"], name: "index_employees_on_employee_code", unique: true
    t.index ["employment_type"], name: "index_employees_on_employment_type"
  end

  create_table "error_logs", force: :cascade do |t|
    t.string "error_class", limit: 255, null: false
    t.text "message", null: false
    t.text "backtrace"
    t.string "request_path", limit: 500
    t.string "request_method", limit: 10
    t.string "user_agent", limit: 1000
    t.inet "ip_address"
    t.text "params"
    t.bigint "user_id"
    t.string "session_id", limit: 255
    t.string "severity", limit: 20, default: "medium", null: false
    t.datetime "occurred_at", null: false
    t.datetime "resolved_at"
    t.string "resolved_by", limit: 255
    t.text "resolution_notes"
    t.boolean "notified", default: false
    t.boolean "investigated", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["error_class", "occurred_at"], name: "index_error_logs_on_error_class_and_occurred_at"
    t.index ["error_class"], name: "index_error_logs_on_error_class"
    t.index ["occurred_at"], name: "index_error_logs_on_occurred_at"
    t.index ["occurred_at"], name: "index_error_logs_on_occurred_at_high_priority", where: "((severity)::text = ANY ((ARRAY['high'::character varying, 'critical'::character varying])::text[]))"
    t.index ["occurred_at"], name: "index_error_logs_on_occurred_at_unresolved", where: "(resolved_at IS NULL)"
    t.index ["request_path", "occurred_at"], name: "index_error_logs_on_request_path_and_occurred_at"
    t.index ["request_path"], name: "index_error_logs_on_request_path"
    t.index ["resolved_at"], name: "index_error_logs_on_resolved_at"
    t.index ["session_id"], name: "index_error_logs_on_session_id"
    t.index ["severity", "occurred_at"], name: "index_error_logs_on_severity_and_occurred_at"
    t.index ["severity"], name: "index_error_logs_on_severity"
    t.index ["user_id", "occurred_at"], name: "index_error_logs_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_error_logs_on_user_id"
    t.check_constraint "occurred_at <= now()", name: "error_logs_occurred_at_check"
    t.check_constraint "request_method IS NULL OR (request_method::text = ANY (ARRAY['GET'::character varying, 'POST'::character varying, 'PUT'::character varying, 'PATCH'::character varying, 'DELETE'::character varying, 'HEAD'::character varying, 'OPTIONS'::character varying]::text[]))", name: "error_logs_request_method_check"
    t.check_constraint "resolved_at IS NULL OR resolved_at >= occurred_at", name: "error_logs_resolution_time_check"
    t.check_constraint "severity::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'critical'::character varying]::text[])", name: "error_logs_severity_check"
  end

  create_table "parse_errors", force: :cascade do |t|
    t.string "source_type", null: false
    t.string "source_id", null: false
    t.string "error_type", null: false
    t.text "error_message", null: false
    t.text "raw_content"
    t.jsonb "metadata", default: {}
    t.datetime "resolved_at"
    t.string "resolved_by"
    t.text "resolution_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_parse_errors_on_created_at"
    t.index ["error_type"], name: "index_parse_errors_on_error_type"
    t.index ["resolved_at"], name: "index_parse_errors_on_resolved_at"
    t.index ["source_id"], name: "index_parse_errors_on_source_id"
    t.index ["source_type", "resolved_at"], name: "index_parse_errors_on_source_type_and_resolved_at"
    t.index ["source_type"], name: "index_parse_errors_on_source_type"
  end

  create_table "patients", force: :cascade do |t|
    t.string "patient_number", null: false
    t.string "name", null: false
    t.string "name_kana"
    t.string "email"
    t.string "phone", null: false
    t.date "birth_date", null: false
    t.text "address"
    t.text "insurance_info"
    t.text "notes"
    t.string "line_user_id"
    t.bigint "merged_to_id"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "preferred_contact_method"
    t.string "status", default: "active", null: false
    t.index ["created_at", "id"], name: "idx_patients_timeline"
    t.index ["discarded_at"], name: "idx_patients_active", where: "(discarded_at IS NULL)"
    t.index ["discarded_at"], name: "index_patients_on_discarded_at"
    t.index ["email"], name: "index_patients_on_email"
    t.index ["line_user_id"], name: "index_patients_on_line_user_id", unique: true
    t.index ["merged_to_id"], name: "index_patients_on_merged_to_id"
    t.index ["name", "phone"], name: "idx_patients_search"
    t.index ["patient_number"], name: "index_patients_on_patient_number", unique: true
    t.index ["phone"], name: "idx_patients_phone"
    t.index ["phone"], name: "index_patients_on_phone", unique: true
  end

  create_table "payrolls", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "pay_period_start", null: false
    t.date "pay_period_end", null: false
    t.decimal "total_hours", precision: 8, scale: 2, default: "0.0"
    t.decimal "regular_hours", precision: 8, scale: 2, default: "0.0"
    t.decimal "overtime_hours", precision: 8, scale: 2, default: "0.0"
    t.decimal "holiday_hours", precision: 8, scale: 2, default: "0.0"
    t.decimal "base_pay", precision: 10, scale: 2, default: "0.0"
    t.decimal "overtime_pay", precision: 10, scale: 2, default: "0.0"
    t.decimal "holiday_pay", precision: 10, scale: 2, default: "0.0"
    t.decimal "allowances", precision: 10, scale: 2, default: "0.0"
    t.decimal "deductions", precision: 10, scale: 2, default: "0.0"
    t.decimal "gross_pay", precision: 10, scale: 2, default: "0.0"
    t.decimal "net_pay", precision: 10, scale: 2, default: "0.0"
    t.string "status", default: "draft"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "paid_at"
    t.jsonb "calculation_details", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_payrolls_on_approved_by_id"
    t.index ["employee_id", "pay_period_start", "pay_period_end"], name: "idx_payrolls_employee_period", unique: true
    t.index ["employee_id"], name: "index_payrolls_on_employee_id"
    t.index ["pay_period_start", "pay_period_end"], name: "index_payrolls_on_pay_period_start_and_pay_period_end"
    t.index ["status"], name: "index_payrolls_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.string "role"
    t.string "phone"
    t.boolean "otp_required_for_login", default: false
    t.string "otp_secret"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email", "discarded_at"], name: "idx_users_email_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "idx_users_role"
  end

  add_foreign_key "appointments", "patients"
  add_foreign_key "clockings", "employees"
  add_foreign_key "clockings", "employees", column: "edited_by_id"
  add_foreign_key "deliveries", "appointments"
  add_foreign_key "deliveries", "patients"
  add_foreign_key "error_logs", "users"
  add_foreign_key "patients", "patients", column: "merged_to_id"
  add_foreign_key "payrolls", "employees"
  add_foreign_key "payrolls", "employees", column: "approved_by_id"
end
