// Generated from the live database. Do not edit; regenerate with scripts/gen-types.sh.
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      academic_years: {
        Row: {
          created_at: string
          created_by: string | null
          ec_year: number
          end_date: string
          id: string
          is_current: boolean
          name: string
          school_id: string
          start_date: string
          status: Database["public"]["Enums"]["academic_year_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          ec_year: number
          end_date: string
          id?: string
          is_current?: boolean
          name: string
          school_id: string
          start_date: string
          status?: Database["public"]["Enums"]["academic_year_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          ec_year?: number
          end_date?: string
          id?: string
          is_current?: boolean
          name?: string
          school_id?: string
          start_date?: string
          status?: Database["public"]["Enums"]["academic_year_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "academic_years_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_years_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          changed_at: string
          changed_by: string | null
          id: number
          new_data: Json | null
          old_data: Json | null
          record_id: string | null
          school_id: string
          table_name: string
        }
        Insert: {
          action: string
          changed_at?: string
          changed_by?: string | null
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          record_id?: string | null
          school_id: string
          table_name: string
        }
        Update: {
          action?: string
          changed_at?: string
          changed_by?: string | null
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          record_id?: string | null
          school_id?: string
          table_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_log_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      enrollments: {
        Row: {
          academic_year_id: string
          created_at: string
          created_by: string | null
          enrolled_on: string
          grade_id: string
          id: string
          left_on: string | null
          promotion_run_id: string | null
          roll_no: number | null
          school_id: string
          section_id: string | null
          status: Database["public"]["Enums"]["enrollment_status"]
          stream: Database["public"]["Enums"]["stream"] | null
          student_id: string
          updated_at: string
          year_result: Database["public"]["Enums"]["year_result"] | null
        }
        Insert: {
          academic_year_id: string
          created_at?: string
          created_by?: string | null
          enrolled_on?: string
          grade_id: string
          id?: string
          left_on?: string | null
          promotion_run_id?: string | null
          roll_no?: number | null
          school_id: string
          section_id?: string | null
          status?: Database["public"]["Enums"]["enrollment_status"]
          stream?: Database["public"]["Enums"]["stream"] | null
          student_id: string
          updated_at?: string
          year_result?: Database["public"]["Enums"]["year_result"] | null
        }
        Update: {
          academic_year_id?: string
          created_at?: string
          created_by?: string | null
          enrolled_on?: string
          grade_id?: string
          id?: string
          left_on?: string | null
          promotion_run_id?: string | null
          roll_no?: number | null
          school_id?: string
          section_id?: string | null
          status?: Database["public"]["Enums"]["enrollment_status"]
          stream?: Database["public"]["Enums"]["stream"] | null
          student_id?: string
          updated_at?: string
          year_result?: Database["public"]["Enums"]["year_result"] | null
        }
        Relationships: [
          {
            foreignKeyName: "enrollments_academic_year_fkey"
            columns: ["school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "enrollments_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_grade_fkey"
            columns: ["school_id", "grade_id"]
            isOneToOne: false
            referencedRelation: "grades"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "enrollments_promotion_run_fkey"
            columns: ["school_id", "promotion_run_id"]
            isOneToOne: false
            referencedRelation: "promotion_runs"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "enrollments_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_section_fkey"
            columns: ["school_id", "section_id"]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "enrollments_section_fkey"
            columns: ["school_id", "section_id"]
            isOneToOne: false
            referencedRelation: "v_section_occupancy"
            referencedColumns: ["school_id", "section_id"]
          },
          {
            foreignKeyName: "enrollments_student_fkey"
            columns: ["school_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "enrollments_student_fkey"
            columns: ["school_id", "student_id"]
            isOneToOne: false
            referencedRelation: "v_students_current"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      grade_subjects: {
        Row: {
          counts_in_average: boolean
          created_at: string
          created_by: string | null
          grade_id: string
          id: string
          periods_per_week: number
          school_id: string
          sort_order: number
          stream: Database["public"]["Enums"]["stream"] | null
          subject_id: string
          updated_at: string
        }
        Insert: {
          counts_in_average?: boolean
          created_at?: string
          created_by?: string | null
          grade_id: string
          id?: string
          periods_per_week?: number
          school_id: string
          sort_order?: number
          stream?: Database["public"]["Enums"]["stream"] | null
          subject_id: string
          updated_at?: string
        }
        Update: {
          counts_in_average?: boolean
          created_at?: string
          created_by?: string | null
          grade_id?: string
          id?: string
          periods_per_week?: number
          school_id?: string
          sort_order?: number
          stream?: Database["public"]["Enums"]["stream"] | null
          subject_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "grade_subjects_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grade_subjects_grade_fkey"
            columns: ["school_id", "grade_id"]
            isOneToOne: false
            referencedRelation: "grades"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "grade_subjects_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grade_subjects_subject_fkey"
            columns: ["school_id", "subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      grades: {
        Row: {
          created_at: string
          created_by: string | null
          has_streams: boolean | null
          id: string
          level: number
          name: string
          name_am: string | null
          school_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          has_streams?: boolean | null
          id?: string
          level: number
          name: string
          name_am?: string | null
          school_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          has_streams?: boolean | null
          id?: string
          level?: number
          name?: string
          name_am?: string | null
          school_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "grades_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grades_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      guardians: {
        Row: {
          alt_phone: string | null
          created_at: string
          created_by: string | null
          deleted_at: string | null
          deleted_by: string | null
          full_name: string
          full_name_am: string | null
          id: string
          occupation: string | null
          phone: string
          profile_id: string | null
          school_id: string
          updated_at: string
        }
        Insert: {
          alt_phone?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          full_name: string
          full_name_am?: string | null
          id?: string
          occupation?: string | null
          phone: string
          profile_id?: string | null
          school_id: string
          updated_at?: string
        }
        Update: {
          alt_phone?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          full_name?: string
          full_name_am?: string | null
          id?: string
          occupation?: string | null
          phone?: string
          profile_id?: string | null
          school_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "guardians_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guardians_deleted_by_fkey"
            columns: ["deleted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guardians_profile_fkey"
            columns: ["school_id", "profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "guardians_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      import_jobs: {
        Row: {
          created_at: string
          created_by: string | null
          error_rows: number
          errors: Json
          file_path: string | null
          id: string
          ok_rows: number
          school_id: string
          status: Database["public"]["Enums"]["import_status"]
          total_rows: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          error_rows?: number
          errors?: Json
          file_path?: string | null
          id?: string
          ok_rows?: number
          school_id: string
          status?: Database["public"]["Enums"]["import_status"]
          total_rows?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          error_rows?: number
          errors?: Json
          file_path?: string | null
          id?: string
          ok_rows?: number
          school_id?: string
          status?: Database["public"]["Enums"]["import_status"]
          total_rows?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "import_jobs_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "import_jobs_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      number_sequences: {
        Row: {
          last_value: number
          name: string
          school_id: string
          updated_at: string
          year: number
        }
        Insert: {
          last_value?: number
          name: string
          school_id: string
          updated_at?: string
          year: number
        }
        Update: {
          last_value?: number
          name?: string
          school_id?: string
          updated_at?: string
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "number_sequences_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      platform_admins: {
        Row: {
          created_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          created_by: string | null
          date_display: Database["public"]["Enums"]["date_display"]
          full_name: string
          full_name_am: string | null
          id: string
          is_active: boolean
          last_login_at: string | null
          locale: string
          login_id: string
          phone: string | null
          school_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          date_display?: Database["public"]["Enums"]["date_display"]
          full_name: string
          full_name_am?: string | null
          id: string
          is_active?: boolean
          last_login_at?: string | null
          locale?: string
          login_id: string
          phone?: string | null
          school_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          date_display?: Database["public"]["Enums"]["date_display"]
          full_name?: string
          full_name_am?: string | null
          id?: string
          is_active?: boolean
          last_login_at?: string | null
          locale?: string
          login_id?: string
          phone?: string | null
          school_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      promotion_runs: {
        Row: {
          created_at: string
          created_by: string | null
          from_year_id: string
          graduated: number
          id: string
          promoted: number
          repeated: number
          school_id: string
          status: Database["public"]["Enums"]["promotion_status"]
          to_year_id: string
          undecided: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          from_year_id: string
          graduated?: number
          id?: string
          promoted?: number
          repeated?: number
          school_id: string
          status?: Database["public"]["Enums"]["promotion_status"]
          to_year_id: string
          undecided?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          from_year_id?: string
          graduated?: number
          id?: string
          promoted?: number
          repeated?: number
          school_id?: string
          status?: Database["public"]["Enums"]["promotion_status"]
          to_year_id?: string
          undecided?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "promotion_runs_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promotion_runs_from_year_fkey"
            columns: ["school_id", "from_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "promotion_runs_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promotion_runs_to_year_fkey"
            columns: ["school_id", "to_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      schools: {
        Row: {
          address: string | null
          code: string
          created_at: string
          created_by: string | null
          default_locale: string
          id: string
          is_active: boolean
          logo_path: string | null
          max_section_size: number
          name: string
          name_am: string | null
          pass_mark: number
          phone: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          default_locale?: string
          id?: string
          is_active?: boolean
          logo_path?: string | null
          max_section_size?: number
          name: string
          name_am?: string | null
          pass_mark?: number
          phone?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          default_locale?: string
          id?: string
          is_active?: boolean
          logo_path?: string | null
          max_section_size?: number
          name?: string
          name_am?: string | null
          pass_mark?: number
          phone?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "schools_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      section_changes: {
        Row: {
          changed_at: string
          created_at: string
          created_by: string | null
          enrollment_id: string
          from_section_id: string
          id: string
          reason: string | null
          school_id: string
          to_section_id: string | null
          updated_at: string
        }
        Insert: {
          changed_at?: string
          created_at?: string
          created_by?: string | null
          enrollment_id: string
          from_section_id: string
          id?: string
          reason?: string | null
          school_id: string
          to_section_id?: string | null
          updated_at?: string
        }
        Update: {
          changed_at?: string
          created_at?: string
          created_by?: string | null
          enrollment_id?: string
          from_section_id?: string
          id?: string
          reason?: string | null
          school_id?: string
          to_section_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "section_changes_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "section_changes_enrollment_fkey"
            columns: ["school_id", "enrollment_id"]
            isOneToOne: false
            referencedRelation: "enrollments"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "section_changes_from_section_fkey"
            columns: ["school_id", "from_section_id"]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "section_changes_from_section_fkey"
            columns: ["school_id", "from_section_id"]
            isOneToOne: false
            referencedRelation: "v_section_occupancy"
            referencedColumns: ["school_id", "section_id"]
          },
          {
            foreignKeyName: "section_changes_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "section_changes_to_section_fkey"
            columns: ["school_id", "to_section_id"]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "section_changes_to_section_fkey"
            columns: ["school_id", "to_section_id"]
            isOneToOne: false
            referencedRelation: "v_section_occupancy"
            referencedColumns: ["school_id", "section_id"]
          },
        ]
      }
      sections: {
        Row: {
          academic_year_id: string
          capacity: number
          created_at: string
          created_by: string | null
          grade_id: string
          homeroom_teacher_id: string | null
          id: string
          name: string
          room: string | null
          school_id: string
          stream: Database["public"]["Enums"]["stream"] | null
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          capacity: number
          created_at?: string
          created_by?: string | null
          grade_id: string
          homeroom_teacher_id?: string | null
          id?: string
          name: string
          room?: string | null
          school_id: string
          stream?: Database["public"]["Enums"]["stream"] | null
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          capacity?: number
          created_at?: string
          created_by?: string | null
          grade_id?: string
          homeroom_teacher_id?: string | null
          id?: string
          name?: string
          room?: string | null
          school_id?: string
          stream?: Database["public"]["Enums"]["stream"] | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "sections_academic_year_fkey"
            columns: ["school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "sections_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sections_grade_fkey"
            columns: ["school_id", "grade_id"]
            isOneToOne: false
            referencedRelation: "grades"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "sections_homeroom_teacher_fkey"
            columns: ["school_id", "homeroom_teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "sections_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      semesters: {
        Row: {
          academic_year_id: string
          created_at: string
          created_by: string | null
          end_date: string
          id: string
          is_current: boolean
          number: number
          school_id: string
          start_date: string
          status: Database["public"]["Enums"]["semester_status"]
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          created_at?: string
          created_by?: string | null
          end_date: string
          id?: string
          is_current?: boolean
          number: number
          school_id: string
          start_date: string
          status?: Database["public"]["Enums"]["semester_status"]
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          created_at?: string
          created_by?: string | null
          end_date?: string
          id?: string
          is_current?: boolean
          number?: number
          school_id?: string
          start_date?: string
          status?: Database["public"]["Enums"]["semester_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "semesters_academic_year_fkey"
            columns: ["school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "semesters_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "semesters_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      staff: {
        Row: {
          created_at: string
          created_by: string | null
          deleted_at: string | null
          deleted_by: string | null
          father_name: string
          first_name: string
          gender: Database["public"]["Enums"]["gender"]
          grandfather_name: string | null
          hire_date: string | null
          id: string
          phone: string | null
          photo_path: string | null
          position: Database["public"]["Enums"]["staff_position"]
          profile_id: string | null
          school_id: string
          staff_code: string
          status: Database["public"]["Enums"]["staff_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          father_name: string
          first_name: string
          gender: Database["public"]["Enums"]["gender"]
          grandfather_name?: string | null
          hire_date?: string | null
          id?: string
          phone?: string | null
          photo_path?: string | null
          position?: Database["public"]["Enums"]["staff_position"]
          profile_id?: string | null
          school_id: string
          staff_code: string
          status?: Database["public"]["Enums"]["staff_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          father_name?: string
          first_name?: string
          gender?: Database["public"]["Enums"]["gender"]
          grandfather_name?: string | null
          hire_date?: string | null
          id?: string
          phone?: string | null
          photo_path?: string | null
          position?: Database["public"]["Enums"]["staff_position"]
          profile_id?: string | null
          school_id?: string
          staff_code?: string
          status?: Database["public"]["Enums"]["staff_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_deleted_by_fkey"
            columns: ["deleted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_profile_fkey"
            columns: ["school_id", "profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "staff_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      student_guardians: {
        Row: {
          created_at: string
          created_by: string | null
          guardian_id: string
          is_primary: boolean
          relationship: Database["public"]["Enums"]["guardian_relationship"]
          school_id: string
          student_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          guardian_id: string
          is_primary?: boolean
          relationship: Database["public"]["Enums"]["guardian_relationship"]
          school_id: string
          student_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          guardian_id?: string
          is_primary?: boolean
          relationship?: Database["public"]["Enums"]["guardian_relationship"]
          school_id?: string
          student_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_guardians_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_guardians_guardian_fkey"
            columns: ["school_id", "guardian_id"]
            isOneToOne: false
            referencedRelation: "guardians"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "student_guardians_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_guardians_student_fkey"
            columns: ["school_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "student_guardians_student_fkey"
            columns: ["school_id", "student_id"]
            isOneToOne: false
            referencedRelation: "v_students_current"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      student_transfers: {
        Row: {
          created_at: string
          created_by: string | null
          direction: Database["public"]["Enums"]["transfer_direction"]
          document_path: string | null
          id: string
          other_school: string
          reason: string | null
          school_id: string
          student_id: string
          transfer_date: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          direction: Database["public"]["Enums"]["transfer_direction"]
          document_path?: string | null
          id?: string
          other_school: string
          reason?: string | null
          school_id: string
          student_id: string
          transfer_date: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          direction?: Database["public"]["Enums"]["transfer_direction"]
          document_path?: string | null
          id?: string
          other_school?: string
          reason?: string | null
          school_id?: string
          student_id?: string
          transfer_date?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_transfers_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_transfers_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_transfers_student_fkey"
            columns: ["school_id", "student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "student_transfers_student_fkey"
            columns: ["school_id", "student_id"]
            isOneToOne: false
            referencedRelation: "v_students_current"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      students: {
        Row: {
          admission_date: string
          birth_date: string | null
          created_at: string
          created_by: string | null
          deleted_at: string | null
          deleted_by: string | null
          father_name: string
          father_name_am: string | null
          first_name: string
          first_name_am: string | null
          gender: Database["public"]["Enums"]["gender"]
          grandfather_name: string | null
          grandfather_name_am: string | null
          id: string
          kebele: string | null
          phone: string | null
          photo_path: string | null
          previous_school: string | null
          profile_id: string | null
          school_id: string
          status: Database["public"]["Enums"]["student_status"]
          student_code: string
          sub_city: string | null
          updated_at: string
          woreda: string | null
        }
        Insert: {
          admission_date?: string
          birth_date?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          father_name: string
          father_name_am?: string | null
          first_name: string
          first_name_am?: string | null
          gender: Database["public"]["Enums"]["gender"]
          grandfather_name?: string | null
          grandfather_name_am?: string | null
          id?: string
          kebele?: string | null
          phone?: string | null
          photo_path?: string | null
          previous_school?: string | null
          profile_id?: string | null
          school_id: string
          status?: Database["public"]["Enums"]["student_status"]
          student_code: string
          sub_city?: string | null
          updated_at?: string
          woreda?: string | null
        }
        Update: {
          admission_date?: string
          birth_date?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          deleted_by?: string | null
          father_name?: string
          father_name_am?: string | null
          first_name?: string
          first_name_am?: string | null
          gender?: Database["public"]["Enums"]["gender"]
          grandfather_name?: string | null
          grandfather_name_am?: string | null
          id?: string
          kebele?: string | null
          phone?: string | null
          photo_path?: string | null
          previous_school?: string | null
          profile_id?: string | null
          school_id?: string
          status?: Database["public"]["Enums"]["student_status"]
          student_code?: string
          sub_city?: string | null
          updated_at?: string
          woreda?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "students_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_deleted_by_fkey"
            columns: ["deleted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_profile_fkey"
            columns: ["school_id", "profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "students_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      subjects: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          name: string
          name_am: string | null
          school_id: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name: string
          name_am?: string | null
          school_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name?: string
          name_am?: string | null
          school_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "subjects_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subjects_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          created_by: string | null
          role: Database["public"]["Enums"]["app_role"]
          school_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          role: Database["public"]["Enums"]["app_role"]
          school_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          school_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_roles_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_roles_user_fkey"
            columns: ["school_id", "user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
    }
    Views: {
      v_section_occupancy: {
        Row: {
          academic_year_id: string | null
          active_count: number | null
          capacity: number | null
          free_seats: number | null
          grade_id: string | null
          grade_level: number | null
          homeroom_teacher_id: string | null
          name: string | null
          school_id: string | null
          section_id: string | null
          stream: Database["public"]["Enums"]["stream"] | null
        }
        Relationships: [
          {
            foreignKeyName: "sections_academic_year_fkey"
            columns: ["school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "sections_grade_fkey"
            columns: ["school_id", "grade_id"]
            isOneToOne: false
            referencedRelation: "grades"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "sections_homeroom_teacher_fkey"
            columns: ["school_id", "homeroom_teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "sections_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      v_students_current: {
        Row: {
          academic_year_id: string | null
          deleted_at: string | null
          enrollment_id: string | null
          enrollment_status:
            | Database["public"]["Enums"]["enrollment_status"]
            | null
          father_name: string | null
          first_name: string | null
          full_name: string | null
          full_name_am: string | null
          gender: Database["public"]["Enums"]["gender"] | null
          grade_id: string | null
          grade_level: number | null
          grandfather_name: string | null
          id: string | null
          phone: string | null
          photo_path: string | null
          roll_no: number | null
          school_id: string | null
          section_id: string | null
          section_name: string | null
          status: Database["public"]["Enums"]["student_status"] | null
          stream: Database["public"]["Enums"]["stream"] | null
          student_code: string | null
        }
        Relationships: [
          {
            foreignKeyName: "students_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      current_guardian_id: { Args: never; Returns: string }
      current_school_id: { Args: never; Returns: string }
      current_staff_id: { Args: never; Returns: string }
      current_student_id: { Args: never; Returns: string }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      guardian_student_ids: { Args: never; Returns: string[] }
      has_any_role: {
        Args: { p_roles: Database["public"]["Enums"]["app_role"][] }
        Returns: boolean
      }
      has_role: {
        Args: { p_role: Database["public"]["Enums"]["app_role"] }
        Returns: boolean
      }
      import_students: {
        Args: { p_dry_run?: boolean; p_job_id: string; p_rows: Json }
        Returns: Json
      }
      is_platform_admin: { Args: never; Returns: boolean }
      move_student_section: {
        Args: {
          p_enrollment_id: string
          p_reason?: string
          p_to_section_id: string
        }
        Returns: {
          academic_year_id: string
          created_at: string
          created_by: string | null
          enrolled_on: string
          grade_id: string
          id: string
          left_on: string | null
          promotion_run_id: string | null
          roll_no: number | null
          school_id: string
          section_id: string | null
          status: Database["public"]["Enums"]["enrollment_status"]
          stream: Database["public"]["Enums"]["stream"] | null
          student_id: string
          updated_at: string
          year_result: Database["public"]["Enums"]["year_result"] | null
        }
        SetofOptions: {
          from: "*"
          to: "enrollments"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      promote_students: {
        Args: {
          p_apply?: boolean
          p_from_year_id: string
          p_to_year_id: string
        }
        Returns: {
          created_at: string
          created_by: string | null
          from_year_id: string
          graduated: number
          id: string
          promoted: number
          repeated: number
          school_id: string
          status: Database["public"]["Enums"]["promotion_status"]
          to_year_id: string
          undecided: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "promotion_runs"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      restore: { Args: { p_id: string; p_table: string }; Returns: undefined }
      set_current_academic_year: {
        Args: { p_academic_year_id: string }
        Returns: undefined
      }
      set_current_semester: {
        Args: { p_semester_id: string }
        Returns: undefined
      }
      soft_delete: {
        Args: { p_id: string; p_table: string }
        Returns: undefined
      }
      teacher_section_ids: { Args: never; Returns: string[] }
      teacher_student_ids: { Args: never; Returns: string[] }
      undo_promotion: {
        Args: { p_run_id: string }
        Returns: {
          created_at: string
          created_by: string | null
          from_year_id: string
          graduated: number
          id: string
          promoted: number
          repeated: number
          school_id: string
          status: Database["public"]["Enums"]["promotion_status"]
          to_year_id: string
          undecided: number
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "promotion_runs"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      academic_year_status: "planning" | "active" | "closed"
      app_role:
        | "super_admin"
        | "director"
        | "registrar"
        | "teacher"
        | "finance"
        | "student"
        | "parent"
      date_display: "ec" | "gc"
      enrollment_status: "active" | "transferred_out" | "dropped" | "completed"
      gender: "M" | "F"
      guardian_relationship: "father" | "mother" | "guardian" | "other"
      import_status: "checking" | "ready" | "done" | "failed"
      promotion_status: "preview" | "done" | "undone"
      semester_status: "open" | "closed"
      staff_position:
        | "teacher"
        | "director"
        | "registrar"
        | "cashier"
        | "librarian"
        | "other"
      staff_status: "active" | "left"
      stream: "natural" | "social"
      student_status: "active" | "transferred_out" | "graduated" | "dropped"
      transfer_direction: "in" | "out"
      year_result: "promoted" | "repeat" | "graduated"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      academic_year_status: ["planning", "active", "closed"],
      app_role: [
        "super_admin",
        "director",
        "registrar",
        "teacher",
        "finance",
        "student",
        "parent",
      ],
      date_display: ["ec", "gc"],
      enrollment_status: ["active", "transferred_out", "dropped", "completed"],
      gender: ["M", "F"],
      guardian_relationship: ["father", "mother", "guardian", "other"],
      import_status: ["checking", "ready", "done", "failed"],
      promotion_status: ["preview", "done", "undone"],
      semester_status: ["open", "closed"],
      staff_position: [
        "teacher",
        "director",
        "registrar",
        "cashier",
        "librarian",
        "other",
      ],
      staff_status: ["active", "left"],
      stream: ["natural", "social"],
      student_status: ["active", "transferred_out", "graduated", "dropped"],
      transfer_direction: ["in", "out"],
      year_result: ["promoted", "repeat", "graduated"],
    },
  },
} as const
