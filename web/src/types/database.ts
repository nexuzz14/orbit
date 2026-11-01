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
      accounts: {
        Row: {
          archived: boolean
          color: string | null
          created_at: string
          created_by: string | null
          currency: string
          deleted_at: string | null
          icon: string | null
          id: string
          initial_balance: number
          is_liquid: boolean
          match_hints: string[]
          name: string
          sort_order: number
          type: Database["public"]["Enums"]["account_type"]
          updated_at: string
          visibility: Database["public"]["Enums"]["account_visibility"]
          workspace_id: string
        }
        Insert: {
          archived?: boolean
          color?: string | null
          created_at?: string
          created_by?: string | null
          currency: string
          deleted_at?: string | null
          icon?: string | null
          id?: string
          initial_balance?: number
          is_liquid?: boolean
          match_hints?: string[]
          name: string
          sort_order?: number
          type: Database["public"]["Enums"]["account_type"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["account_visibility"]
          workspace_id: string
        }
        Update: {
          archived?: boolean
          color?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          deleted_at?: string | null
          icon?: string | null
          id?: string
          initial_balance?: number
          is_liquid?: boolean
          match_hints?: string[]
          name?: string
          sort_order?: number
          type?: Database["public"]["Enums"]["account_type"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["account_visibility"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "accounts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      attachments: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          mime: string
          owner_id: string
          owner_table: string
          size: number
          storage_path: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          mime: string
          owner_id: string
          owner_table: string
          size: number
          storage_path: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          mime?: string
          owner_id?: string
          owner_table?: string
          size?: number
          storage_path?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attachments_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: Database["public"]["Enums"]["audit_action"]
          actor_id: string | null
          at: string
          diff: Json
          id: string
          row_id: string | null
          table_name: string
          workspace_id: string
        }
        Insert: {
          action: Database["public"]["Enums"]["audit_action"]
          actor_id?: string | null
          at?: string
          diff?: Json
          id?: string
          row_id?: string | null
          table_name: string
          workspace_id: string
        }
        Update: {
          action?: Database["public"]["Enums"]["audit_action"]
          actor_id?: string | null
          at?: string
          diff?: Json
          id?: string
          row_id?: string | null
          table_name?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_log_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      budgets: {
        Row: {
          amount: number
          category_id: string
          created_at: string
          currency: string
          deleted_at: string | null
          id: string
          notify_at_percent: number
          period: string
          rollover: boolean
          updated_at: string
          workspace_id: string
        }
        Insert: {
          amount: number
          category_id: string
          created_at?: string
          currency?: string
          deleted_at?: string | null
          id?: string
          notify_at_percent?: number
          period?: string
          rollover?: boolean
          updated_at?: string
          workspace_id: string
        }
        Update: {
          amount?: number
          category_id?: string
          created_at?: string
          currency?: string
          deleted_at?: string | null
          id?: string
          notify_at_percent?: number
          period?: string
          rollover?: boolean
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "budgets_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budgets_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          archived: boolean
          color: string | null
          created_at: string
          deleted_at: string | null
          icon: string | null
          id: string
          name: string
          parent_id: string | null
          sort_order: number
          system_key: string | null
          type: Database["public"]["Enums"]["category_type"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          archived?: boolean
          color?: string | null
          created_at?: string
          deleted_at?: string | null
          icon?: string | null
          id?: string
          name: string
          parent_id?: string | null
          sort_order?: number
          system_key?: string | null
          type: Database["public"]["Enums"]["category_type"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          archived?: boolean
          color?: string | null
          created_at?: string
          deleted_at?: string | null
          icon?: string | null
          id?: string
          name?: string
          parent_id?: string | null
          sort_order?: number
          system_key?: string | null
          type?: Database["public"]["Enums"]["category_type"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "categories_parent_id_workspace_id_fkey"
            columns: ["parent_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "categories_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      category_rules: {
        Row: {
          account_id: string | null
          amount_max: number | null
          amount_min: number | null
          auto_apply: boolean
          category_id: string
          confirm_count: number
          created_at: string
          created_by: string | null
          day_of_month: number | null
          deleted_at: string | null
          enabled: boolean
          hour_from: number | null
          hour_to: number | null
          id: string
          match_field: Database["public"]["Enums"]["rule_match_field"]
          match_type: Database["public"]["Enums"]["rule_match_type"]
          pattern: string | null
          priority: number
          project_id: string | null
          source: Database["public"]["Enums"]["transaction_source"] | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          account_id?: string | null
          amount_max?: number | null
          amount_min?: number | null
          auto_apply?: boolean
          category_id: string
          confirm_count?: number
          created_at?: string
          created_by?: string | null
          day_of_month?: number | null
          deleted_at?: string | null
          enabled?: boolean
          hour_from?: number | null
          hour_to?: number | null
          id?: string
          match_field: Database["public"]["Enums"]["rule_match_field"]
          match_type?: Database["public"]["Enums"]["rule_match_type"]
          pattern?: string | null
          priority?: number
          project_id?: string | null
          source?: Database["public"]["Enums"]["transaction_source"] | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          account_id?: string | null
          amount_max?: number | null
          amount_min?: number | null
          auto_apply?: boolean
          category_id?: string
          confirm_count?: number
          created_at?: string
          created_by?: string | null
          day_of_month?: number | null
          deleted_at?: string | null
          enabled?: boolean
          hour_from?: number | null
          hour_to?: number | null
          id?: string
          match_field?: Database["public"]["Enums"]["rule_match_field"]
          match_type?: Database["public"]["Enums"]["rule_match_type"]
          pattern?: string | null
          priority?: number
          project_id?: string | null
          source?: Database["public"]["Enums"]["transaction_source"] | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "category_rules_account_id_workspace_id_fkey"
            columns: ["account_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "category_rules_account_id_workspace_id_fkey"
            columns: ["account_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_account_balances"
            referencedColumns: ["account_id", "workspace_id"]
          },
          {
            foreignKeyName: "category_rules_category_id_workspace_id_fkey"
            columns: ["category_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "category_rules_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "category_rules_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_project_profit"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "category_rules_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "category_rules_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      event_exceptions: {
        Row: {
          action: Database["public"]["Enums"]["exception_action"]
          created_at: string
          event_id: string
          id: string
          original_date: string
          override_ends_at: string | null
          override_location: string | null
          override_starts_at: string | null
          override_title: string | null
          updated_at: string
        }
        Insert: {
          action: Database["public"]["Enums"]["exception_action"]
          created_at?: string
          event_id: string
          id?: string
          original_date: string
          override_ends_at?: string | null
          override_location?: string | null
          override_starts_at?: string | null
          override_title?: string | null
          updated_at?: string
        }
        Update: {
          action?: Database["public"]["Enums"]["exception_action"]
          created_at?: string
          event_id?: string
          id?: string
          original_date?: string
          override_ends_at?: string | null
          override_location?: string | null
          override_starts_at?: string | null
          override_title?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_exceptions_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          all_day: boolean
          created_at: string
          created_by: string | null
          deleted_at: string | null
          description: string | null
          ends_at: string
          id: string
          kind: Database["public"]["Enums"]["activity_kind"]
          location: string | null
          project_id: string | null
          recurrence: Json | null
          reminder_minutes: number[]
          starts_at: string
          timezone: string
          title: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          all_day?: boolean
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          ends_at: string
          id?: string
          kind: Database["public"]["Enums"]["activity_kind"]
          location?: string | null
          project_id?: string | null
          recurrence?: Json | null
          reminder_minutes?: number[]
          starts_at: string
          timezone?: string
          title: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          all_day?: boolean
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          ends_at?: string
          id?: string
          kind?: Database["public"]["Enums"]["activity_kind"]
          location?: string | null
          project_id?: string | null
          recurrence?: Json | null
          reminder_minutes?: number[]
          starts_at?: string
          timezone?: string
          title?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "events_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "events_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_project_profit"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "events_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "events_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      exchange_rates: {
        Row: {
          created_at: string
          date: string
          from_currency: string
          rate: number
          source: string
          to_currency: string
        }
        Insert: {
          created_at?: string
          date: string
          from_currency: string
          rate: number
          source?: string
          to_currency: string
        }
        Update: {
          created_at?: string
          date?: string
          from_currency?: string
          rate?: number
          source?: string
          to_currency?: string
        }
        Relationships: []
      }
      expected_incomes: {
        Row: {
          amount: number
          created_at: string
          date_window_days: number
          deleted_at: string | null
          expected_date: string
          id: string
          label: string
          matched_transaction_id: string | null
          project_id: string | null
          project_payment_id: string | null
          recurrence: Json | null
          source: Database["public"]["Enums"]["transaction_source"]
          status: string
          tolerance: number
          updated_at: string
          workspace_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          date_window_days?: number
          deleted_at?: string | null
          expected_date: string
          id?: string
          label: string
          matched_transaction_id?: string | null
          project_id?: string | null
          project_payment_id?: string | null
          recurrence?: Json | null
          source: Database["public"]["Enums"]["transaction_source"]
          status?: string
          tolerance?: number
          updated_at?: string
          workspace_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          date_window_days?: number
          deleted_at?: string | null
          expected_date?: string
          id?: string
          label?: string
          matched_transaction_id?: string | null
          project_id?: string | null
          project_payment_id?: string | null
          recurrence?: Json | null
          source?: Database["public"]["Enums"]["transaction_source"]
          status?: string
          tolerance?: number
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "expected_incomes_matched_transaction_id_fkey"
            columns: ["matched_transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expected_incomes_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expected_incomes_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "v_project_profit"
            referencedColumns: ["project_id"]
          },
          {
            foreignKeyName: "expected_incomes_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["project_id"]
          },
          {
            foreignKeyName: "expected_incomes_project_payment_id_fkey"
            columns: ["project_payment_id"]
            isOneToOne: false
            referencedRelation: "project_payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expected_incomes_project_payment_id_fkey"
            columns: ["project_payment_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["payment_id"]
          },
          {
            foreignKeyName: "expected_incomes_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      income_split_rules: {
        Row: {
          active: boolean
          created_at: string
          deleted_at: string | null
          goal_id: string
          id: string
          priority: number
          source: Database["public"]["Enums"]["transaction_source"]
          split_type: string
          split_value: number
          updated_at: string
          workspace_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          deleted_at?: string | null
          goal_id: string
          id?: string
          priority?: number
          source: Database["public"]["Enums"]["transaction_source"]
          split_type: string
          split_value: number
          updated_at?: string
          workspace_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          deleted_at?: string | null
          goal_id?: string
          id?: string
          priority?: number
          source?: Database["public"]["Enums"]["transaction_source"]
          split_type?: string
          split_value?: number
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "income_split_rules_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "savings_goals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "income_split_rules_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_settings: {
        Row: {
          bills_reminder_enabled: boolean
          budget_exceeded_enabled: boolean
          budget_warning_enabled: boolean
          daily_summary_time: string
          receivables_reminder_enabled: boolean
          updated_at: string
          workspace_id: string
        }
        Insert: {
          bills_reminder_enabled?: boolean
          budget_exceeded_enabled?: boolean
          budget_warning_enabled?: boolean
          daily_summary_time?: string
          receivables_reminder_enabled?: boolean
          updated_at?: string
          workspace_id: string
        }
        Update: {
          bills_reminder_enabled?: boolean
          budget_exceeded_enabled?: boolean
          budget_warning_enabled?: boolean
          daily_summary_time?: string
          receivables_reminder_enabled?: boolean
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_settings_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: true
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          base_currency: string
          created_at: string
          display_name: string
          id: string
          month_start_day: number
          timezone: string
          updated_at: string
        }
        Insert: {
          base_currency?: string
          created_at?: string
          display_name?: string
          id: string
          month_start_day?: number
          timezone?: string
          updated_at?: string
        }
        Update: {
          base_currency?: string
          created_at?: string
          display_name?: string
          id?: string
          month_start_day?: number
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      project_payments: {
        Row: {
          account_id: string | null
          amount: number
          created_at: string
          created_by: string | null
          deleted_at: string | null
          due_date: string | null
          fee_transaction_id: string | null
          id: string
          label: string
          paid_amount: number
          paid_at: string | null
          project_id: string
          status: string
          transaction_id: string | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          account_id?: string | null
          amount: number
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          due_date?: string | null
          fee_transaction_id?: string | null
          id?: string
          label: string
          paid_amount?: number
          paid_at?: string | null
          project_id: string
          status?: string
          transaction_id?: string | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          account_id?: string | null
          amount?: number
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          due_date?: string | null
          fee_transaction_id?: string | null
          id?: string
          label?: string
          paid_amount?: number
          paid_at?: string | null
          project_id?: string
          status?: string
          transaction_id?: string | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_payments_account_id_workspace_id_fkey"
            columns: ["account_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "project_payments_account_id_workspace_id_fkey"
            columns: ["account_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_account_balances"
            referencedColumns: ["account_id", "workspace_id"]
          },
          {
            foreignKeyName: "project_payments_fee_transaction_id_workspace_id_fkey"
            columns: ["fee_transaction_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "project_payments_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "project_payments_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_project_profit"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "project_payments_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "project_payments_transaction_id_workspace_id_fkey"
            columns: ["transaction_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "project_payments_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          archived: boolean
          client_name: string | null
          color: string | null
          contract_value: number | null
          course_code: string | null
          created_at: string
          created_by: string | null
          credits: number | null
          currency: string | null
          deadline: string | null
          deleted_at: string | null
          description: string | null
          fee_mode: Database["public"]["Enums"]["fee_mode"] | null
          id: string
          kind: Database["public"]["Enums"]["activity_kind"]
          name: string
          platform_fee_percent: number | null
          semester: number | null
          started_on: string | null
          status: Database["public"]["Enums"]["project_status"]
          stipend_amount: number | null
          stipend_day: number | null
          tags: string[]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          archived?: boolean
          client_name?: string | null
          color?: string | null
          contract_value?: number | null
          course_code?: string | null
          created_at?: string
          created_by?: string | null
          credits?: number | null
          currency?: string | null
          deadline?: string | null
          deleted_at?: string | null
          description?: string | null
          fee_mode?: Database["public"]["Enums"]["fee_mode"] | null
          id?: string
          kind: Database["public"]["Enums"]["activity_kind"]
          name: string
          platform_fee_percent?: number | null
          semester?: number | null
          started_on?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          stipend_amount?: number | null
          stipend_day?: number | null
          tags?: string[]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          archived?: boolean
          client_name?: string | null
          color?: string | null
          contract_value?: number | null
          course_code?: string | null
          created_at?: string
          created_by?: string | null
          credits?: number | null
          currency?: string | null
          deadline?: string | null
          deleted_at?: string | null
          description?: string | null
          fee_mode?: Database["public"]["Enums"]["fee_mode"] | null
          id?: string
          kind?: Database["public"]["Enums"]["activity_kind"]
          name?: string
          platform_fee_percent?: number | null
          semester?: number | null
          started_on?: string | null
          status?: Database["public"]["Enums"]["project_status"]
          stipend_amount?: number | null
          stipend_day?: number | null
          tags?: string[]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "projects_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      recurring_bill_instances: {
        Row: {
          bill_id: string
          created_at: string
          due_date: string
          id: string
          transaction_id: string | null
          workspace_id: string
        }
        Insert: {
          bill_id: string
          created_at?: string
          due_date: string
          id?: string
          transaction_id?: string | null
          workspace_id: string
        }
        Update: {
          bill_id?: string
          created_at?: string
          due_date?: string
          id?: string
          transaction_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recurring_bill_instances_bill_id_fkey"
            columns: ["bill_id"]
            isOneToOne: false
            referencedRelation: "recurring_bills"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recurring_bill_instances_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recurring_bill_instances_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      recurring_bills: {
        Row: {
          account_id: string
          active: boolean
          amount: number
          auto_create_draft: boolean
          category_id: string
          created_at: string
          currency: string
          deleted_at: string | null
          id: string
          name: string
          remind_days_before: number[]
          schedule_type: string
          schedule_value: number
          updated_at: string
          workspace_id: string
        }
        Insert: {
          account_id: string
          active?: boolean
          amount: number
          auto_create_draft?: boolean
          category_id: string
          created_at?: string
          currency?: string
          deleted_at?: string | null
          id?: string
          name: string
          remind_days_before?: number[]
          schedule_type: string
          schedule_value: number
          updated_at?: string
          workspace_id: string
        }
        Update: {
          account_id?: string
          active?: boolean
          amount?: number
          auto_create_draft?: boolean
          category_id?: string
          created_at?: string
          currency?: string
          deleted_at?: string | null
          id?: string
          name?: string
          remind_days_before?: number[]
          schedule_type?: string
          schedule_value?: number
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recurring_bills_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recurring_bills_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "v_account_balances"
            referencedColumns: ["account_id"]
          },
          {
            foreignKeyName: "recurring_bills_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recurring_bills_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_allocations: {
        Row: {
          amount: number
          created_at: string
          deleted_at: string | null
          goal_id: string
          id: string
          note: string | null
          rule_id: string | null
          transaction_id: string
          workspace_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          deleted_at?: string | null
          goal_id: string
          id?: string
          note?: string | null
          rule_id?: string | null
          transaction_id: string
          workspace_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          deleted_at?: string | null
          goal_id?: string
          id?: string
          note?: string | null
          rule_id?: string | null
          transaction_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "savings_allocations_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "savings_goals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "savings_allocations_rule_id_fkey"
            columns: ["rule_id"]
            isOneToOne: false
            referencedRelation: "income_split_rules"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "savings_allocations_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "savings_allocations_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_goals: {
        Row: {
          account_id: string | null
          created_at: string
          currency: string
          current_amount: number
          deleted_at: string | null
          icon: string | null
          id: string
          is_completed: boolean
          name: string
          notes: string | null
          target_amount: number
          target_date: string | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          account_id?: string | null
          created_at?: string
          currency?: string
          current_amount?: number
          deleted_at?: string | null
          icon?: string | null
          id?: string
          is_completed?: boolean
          name: string
          notes?: string | null
          target_amount: number
          target_date?: string | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          account_id?: string | null
          created_at?: string
          currency?: string
          current_amount?: number
          deleted_at?: string | null
          icon?: string | null
          id?: string
          is_completed?: boolean
          name?: string
          notes?: string | null
          target_amount?: number
          target_date?: string | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "savings_goals_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "savings_goals_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "v_account_balances"
            referencedColumns: ["account_id"]
          },
          {
            foreignKeyName: "savings_goals_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      security_events: {
        Row: {
          at: string
          id: string
          ip_hash: string | null
          type: Database["public"]["Enums"]["security_event_type"]
          user_agent: string | null
          user_id: string
        }
        Insert: {
          at?: string
          id?: string
          ip_hash?: string | null
          type: Database["public"]["Enums"]["security_event_type"]
          user_agent?: string | null
          user_id: string
        }
        Update: {
          at?: string
          id?: string
          ip_hash?: string | null
          type?: Database["public"]["Enums"]["security_event_type"]
          user_agent?: string | null
          user_id?: string
        }
        Relationships: []
      }
      task_checklist_items: {
        Row: {
          created_at: string
          done: boolean
          id: string
          sort_order: number
          task_id: string
          text: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          done?: boolean
          id?: string
          sort_order?: number
          task_id: string
          text: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          done?: boolean
          id?: string
          sort_order?: number
          task_id?: string
          text?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_checklist_items_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          completed_at: string | null
          created_at: string
          created_by: string | null
          deleted_at: string | null
          description: string | null
          due_at: string | null
          due_is_date_only: boolean
          estimate_minutes: number | null
          id: string
          kind: Database["public"]["Enums"]["activity_kind"]
          milestone_payment_id: string | null
          priority: Database["public"]["Enums"]["task_priority"]
          project_id: string | null
          sort_order: number
          status: Database["public"]["Enums"]["task_status"]
          tags: string[]
          title: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          due_at?: string | null
          due_is_date_only?: boolean
          estimate_minutes?: number | null
          id?: string
          kind: Database["public"]["Enums"]["activity_kind"]
          milestone_payment_id?: string | null
          priority?: Database["public"]["Enums"]["task_priority"]
          project_id?: string | null
          sort_order?: number
          status?: Database["public"]["Enums"]["task_status"]
          tags?: string[]
          title: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          description?: string | null
          due_at?: string | null
          due_is_date_only?: boolean
          estimate_minutes?: number | null
          id?: string
          kind?: Database["public"]["Enums"]["activity_kind"]
          milestone_payment_id?: string | null
          priority?: Database["public"]["Enums"]["task_priority"]
          project_id?: string | null
          sort_order?: number
          status?: Database["public"]["Enums"]["task_status"]
          tags?: string[]
          title?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tasks_milestone_payment_id_fkey"
            columns: ["milestone_payment_id"]
            isOneToOne: false
            referencedRelation: "project_payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_milestone_payment_id_fkey"
            columns: ["milestone_payment_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["payment_id"]
          },
          {
            foreignKeyName: "tasks_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "tasks_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_project_profit"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "tasks_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "tasks_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      transaction_items: {
        Row: {
          category_id: string | null
          created_at: string
          id: string
          name: string
          project_id: string | null
          qty: number
          transaction_id: string
          unit_price: number
          updated_at: string
        }
        Insert: {
          category_id?: string | null
          created_at?: string
          id?: string
          name: string
          project_id?: string | null
          qty?: number
          transaction_id: string
          unit_price: number
          updated_at?: string
        }
        Update: {
          category_id?: string | null
          created_at?: string
          id?: string
          name?: string
          project_id?: string | null
          qty?: number
          transaction_id?: string
          unit_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "transaction_items_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transaction_items_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transaction_items_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "v_project_profit"
            referencedColumns: ["project_id"]
          },
          {
            foreignKeyName: "transaction_items_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["project_id"]
          },
          {
            foreignKeyName: "transaction_items_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      transactions: {
        Row: {
          account_id: string
          amount: number
          amount_base: number
          bank_category: string | null
          category_id: string | null
          counterparty: string | null
          counterparty_bank: string | null
          created_at: string
          created_by: string | null
          currency: string
          dedupe_hash: string | null
          deleted_at: string | null
          draft_state: Database["public"]["Enums"]["draft_state"] | null
          external_id_hash: string | null
          fx_rate: number
          id: string
          import_batch_id: string | null
          location_hint: string | null
          merchant: string | null
          merchant_normalized: string | null
          note: string | null
          occurred_at: string
          origin: Database["public"]["Enums"]["transaction_origin"]
          product_name: string | null
          project_id: string | null
          source: Database["public"]["Enums"]["transaction_source"] | null
          source_package: string | null
          status: Database["public"]["Enums"]["transaction_status"]
          tags: string[]
          transfer_direction:
            | Database["public"]["Enums"]["transfer_direction"]
            | null
          transfer_group_id: string | null
          txn_kind: string | null
          type: Database["public"]["Enums"]["transaction_type"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          account_id: string
          amount: number
          amount_base: number
          bank_category?: string | null
          category_id?: string | null
          counterparty?: string | null
          counterparty_bank?: string | null
          created_at?: string
          created_by?: string | null
          currency: string
          dedupe_hash?: string | null
          deleted_at?: string | null
          draft_state?: Database["public"]["Enums"]["draft_state"] | null
          external_id_hash?: string | null
          fx_rate?: number
          id?: string
          import_batch_id?: string | null
          location_hint?: string | null
          merchant?: string | null
          merchant_normalized?: string | null
          note?: string | null
          occurred_at?: string
          origin?: Database["public"]["Enums"]["transaction_origin"]
          product_name?: string | null
          project_id?: string | null
          source?: Database["public"]["Enums"]["transaction_source"] | null
          source_package?: string | null
          status?: Database["public"]["Enums"]["transaction_status"]
          tags?: string[]
          transfer_direction?:
            | Database["public"]["Enums"]["transfer_direction"]
            | null
          transfer_group_id?: string | null
          txn_kind?: string | null
          type: Database["public"]["Enums"]["transaction_type"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          account_id?: string
          amount?: number
          amount_base?: number
          bank_category?: string | null
          category_id?: string | null
          counterparty?: string | null
          counterparty_bank?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          dedupe_hash?: string | null
          deleted_at?: string | null
          draft_state?: Database["public"]["Enums"]["draft_state"] | null
          external_id_hash?: string | null
          fx_rate?: number
          id?: string
          import_batch_id?: string | null
          location_hint?: string | null
          merchant?: string | null
          merchant_normalized?: string | null
          note?: string | null
          occurred_at?: string
          origin?: Database["public"]["Enums"]["transaction_origin"]
          product_name?: string | null
          project_id?: string | null
          source?: Database["public"]["Enums"]["transaction_source"] | null
          source_package?: string | null
          status?: Database["public"]["Enums"]["transaction_status"]
          tags?: string[]
          transfer_direction?:
            | Database["public"]["Enums"]["transfer_direction"]
            | null
          transfer_group_id?: string | null
          txn_kind?: string | null
          type?: Database["public"]["Enums"]["transaction_type"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "transactions_account_id_workspace_id_fkey"
            columns: ["account_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "accounts"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "transactions_account_id_workspace_id_fkey"
            columns: ["account_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_account_balances"
            referencedColumns: ["account_id", "workspace_id"]
          },
          {
            foreignKeyName: "transactions_category_id_workspace_id_fkey"
            columns: ["category_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "transactions_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "transactions_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_project_profit"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "transactions_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "v_receivables"
            referencedColumns: ["project_id", "workspace_id"]
          },
          {
            foreignKeyName: "transactions_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspace_invites: {
        Row: {
          accepted_at: string | null
          created_at: string
          created_by: string | null
          email: string
          expires_at: string
          id: string
          revoked_at: string | null
          role: Database["public"]["Enums"]["user_role"]
          token_hash: string
          updated_at: string
          workspace_id: string
        }
        Insert: {
          accepted_at?: string | null
          created_at?: string
          created_by?: string | null
          email: string
          expires_at: string
          id?: string
          revoked_at?: string | null
          role: Database["public"]["Enums"]["user_role"]
          token_hash: string
          updated_at?: string
          workspace_id: string
        }
        Update: {
          accepted_at?: string | null
          created_at?: string
          created_by?: string | null
          email?: string
          expires_at?: string
          id?: string
          revoked_at?: string | null
          role?: Database["public"]["Enums"]["user_role"]
          token_hash?: string
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspace_invites_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspace_members: {
        Row: {
          created_at: string
          role: Database["public"]["Enums"]["user_role"]
          updated_at: string
          user_id: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          role: Database["public"]["Enums"]["user_role"]
          updated_at?: string
          user_id: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
          user_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspace_members_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspaces: {
        Row: {
          base_currency: string
          created_at: string
          id: string
          name: string
          owner_id: string
          type: Database["public"]["Enums"]["workspace_type"]
          updated_at: string
        }
        Insert: {
          base_currency?: string
          created_at?: string
          id?: string
          name: string
          owner_id: string
          type?: Database["public"]["Enums"]["workspace_type"]
          updated_at?: string
        }
        Update: {
          base_currency?: string
          created_at?: string
          id?: string
          name?: string
          owner_id?: string
          type?: Database["public"]["Enums"]["workspace_type"]
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      v_account_balances: {
        Row: {
          account_id: string | null
          archived: boolean | null
          balance: number | null
          confirmed_txn_count: number | null
          currency: string | null
          initial_balance: number | null
          is_liquid: boolean | null
          last_txn_at: string | null
          name: string | null
          sort_order: number | null
          type: Database["public"]["Enums"]["account_type"] | null
          visibility: Database["public"]["Enums"]["account_visibility"] | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "accounts_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_budget_progress: {
        Row: {
          base_budget_amount: number | null
          budget_id: string | null
          category_id: string | null
          category_name: string | null
          currency: string | null
          effective_budget_amount: number | null
          is_over_budget: boolean | null
          is_warning: boolean | null
          notify_at_percent: number | null
          percentage_spent: number | null
          period_end: string | null
          period_start: string | null
          remaining_amount: number | null
          rollover: boolean | null
          rollover_amount: number | null
          spent_amount: number | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "budgets_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budgets_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_monthly_category_summary: {
        Row: {
          category_id: string | null
          category_name: string | null
          month_start: string | null
          total: number | null
          txn_count: number | null
          type: Database["public"]["Enums"]["transaction_type"] | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "transactions_category_id_workspace_id_fkey"
            columns: ["category_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id", "workspace_id"]
          },
          {
            foreignKeyName: "transactions_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_monthly_summary: {
        Row: {
          currency: string | null
          expense: number | null
          income: number | null
          is_total: boolean | null
          month_end: string | null
          month_start: string | null
          net: number | null
          source: Database["public"]["Enums"]["transaction_source"] | null
          txn_count: number | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "transactions_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_project_profit: {
        Row: {
          client_name: string | null
          contract_value: number | null
          currency: string | null
          kind: Database["public"]["Enums"]["activity_kind"] | null
          margin_percent: number | null
          net_profit: number | null
          platform_fee_deducted: number | null
          project_id: string | null
          project_name: string | null
          remaining_invoiced: number | null
          status: Database["public"]["Enums"]["project_status"] | null
          total_expense: number | null
          total_invoiced: number | null
          total_paid: number | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "projects_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      v_receivables: {
        Row: {
          amount: number | null
          client_name: string | null
          days_overdue: number | null
          due_date: string | null
          is_overdue: boolean | null
          label: string | null
          paid_amount: number | null
          payment_id: string | null
          project_id: string | null
          project_name: string | null
          remaining_amount: number | null
          status: string | null
          workspace_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "projects_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      fn_agenda: {
        Args: {
          p_end_date?: string
          p_kind?: string
          p_start_date: string
          p_workspace_id: string
        }
        Returns: {
          all_day: boolean
          checklist_done: number
          checklist_total: number
          description: string
          due_at: string
          due_is_date_only: boolean
          ends_at: string
          event_id: string
          id: string
          is_overdue: boolean
          is_recurring: boolean
          item_type: string
          kind: Database["public"]["Enums"]["activity_kind"]
          location: string
          milestone_payment_id: string
          priority: string
          project_color: string
          project_id: string
          project_name: string
          starts_at: string
          status: string
          title: string
        }[]
      }
      fn_apply_income_split: {
        Args: { p_transaction_id: string }
        Returns: number
      }
      fn_complete_task: {
        Args: { p_task_id: string }
        Returns: {
          completed_at: string | null
          created_at: string
          created_by: string | null
          deleted_at: string | null
          description: string | null
          due_at: string | null
          due_is_date_only: boolean
          estimate_minutes: number | null
          id: string
          kind: Database["public"]["Enums"]["activity_kind"]
          milestone_payment_id: string | null
          priority: Database["public"]["Enums"]["task_priority"]
          project_id: string | null
          sort_order: number
          status: Database["public"]["Enums"]["task_status"]
          tags: string[]
          title: string
          updated_at: string
          workspace_id: string
        }
        SetofOptions: {
          from: "*"
          to: "tasks"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      fn_confirm_draft: {
        Args: {
          p_account_id?: string
          p_category_id?: string
          p_project_id?: string
          p_source?: Database["public"]["Enums"]["transaction_source"]
          p_transaction_id: string
        }
        Returns: {
          account_id: string
          amount: number
          amount_base: number
          bank_category: string | null
          category_id: string | null
          counterparty: string | null
          counterparty_bank: string | null
          created_at: string
          created_by: string | null
          currency: string
          dedupe_hash: string | null
          deleted_at: string | null
          draft_state: Database["public"]["Enums"]["draft_state"] | null
          external_id_hash: string | null
          fx_rate: number
          id: string
          import_batch_id: string | null
          location_hint: string | null
          merchant: string | null
          merchant_normalized: string | null
          note: string | null
          occurred_at: string
          origin: Database["public"]["Enums"]["transaction_origin"]
          product_name: string | null
          project_id: string | null
          source: Database["public"]["Enums"]["transaction_source"] | null
          source_package: string | null
          status: Database["public"]["Enums"]["transaction_status"]
          tags: string[]
          transfer_direction:
            | Database["public"]["Enums"]["transfer_direction"]
            | null
          transfer_group_id: string | null
          txn_kind: string | null
          type: Database["public"]["Enums"]["transaction_type"]
          updated_at: string
          workspace_id: string
        }
        SetofOptions: {
          from: "*"
          to: "transactions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      fn_confirm_expected_income: {
        Args: {
          p_account_id?: string
          p_draft_id: string
          p_expected_income_id: string
        }
        Returns: string
      }
      fn_create_transfer: {
        Args: {
          p_amount_in?: number
          p_amount_out: number
          p_fee?: number
          p_from_account_id: string
          p_group_id?: string
          p_note?: string
          p_occurred_at?: string
          p_to_account_id: string
          p_workspace_id: string
        }
        Returns: string
      }
      fn_delete_transaction: {
        Args: { p_transaction_id: string }
        Returns: undefined
      }
      fn_detect_conflicts: {
        Args: {
          p_end_date?: string
          p_start_date: string
          p_workspace_id: string
        }
        Returns: {
          conflict_date: string
          event1_ends_at: string
          event1_id: string
          event1_starts_at: string
          event1_title: string
          event2_ends_at: string
          event2_id: string
          event2_starts_at: string
          event2_title: string
          is_heavy_day: boolean
        }[]
      }
      fn_generate_due_bill_drafts: {
        Args: { p_target_date?: string }
        Returns: number
      }
      fn_log_sync_conflict: {
        Args: {
          p_payload: Json
          p_row_id: string
          p_table_name: string
          p_workspace_id: string
        }
        Returns: undefined
      }
      fn_mark_payment_paid: {
        Args: {
          p_account_id?: string
          p_fee?: number
          p_paid_at?: string
          p_payment_id: string
        }
        Returns: string
      }
      fn_match_expected_income: {
        Args: { p_draft_id: string }
        Returns: {
          amount_diff: number
          days_diff: number
          draft_amount: number
          draft_date: string
          expected_amount: number
          expected_date: string
          expected_income_id: string
          label: string
          match_confidence: string
          project_id: string
          project_payment_id: string
          source: Database["public"]["Enums"]["transaction_source"]
        }[]
      }
      fn_my_sessions: {
        Args: never
        Returns: {
          aal: string
          created_at: string
          id: string
          is_current: boolean
          updated_at: string
          user_agent: string
        }[]
      }
      fn_normalize_merchant: { Args: { p_merchant: string }; Returns: string }
      fn_purge_expired: { Args: never; Returns: undefined }
      fn_restore_transaction: {
        Args: { p_transaction_id: string }
        Returns: undefined
      }
      fn_revoke_session: { Args: { p_session_id: string }; Returns: boolean }
      fn_seed_workspace_defaults: {
        Args: { p_user_id: string; p_workspace_id: string }
        Returns: undefined
      }
      fn_storage_workspace: { Args: { p_name: string }; Returns: string }
      has_role: {
        Args: {
          p_role: Database["public"]["Enums"]["user_role"]
          p_workspace_id: string
        }
        Returns: boolean
      }
      is_member: { Args: { p_workspace_id: string }; Returns: boolean }
    }
    Enums: {
      account_type: "cash" | "bank" | "e_wallet" | "credit_card" | "savings"
      account_visibility: "shared" | "private"
      activity_kind: "intern" | "freelance" | "kuliah" | "pribadi"
      audit_action: "insert" | "update" | "delete" | "conflict"
      category_type: "income" | "expense"
      draft_state: "baru" | "perlu_dilengkapi" | "perlu_dicek"
      exception_action: "skip" | "override"
      fee_mode: "expense_transaction" | "profit_deduction"
      project_status: "draft" | "berjalan" | "selesai" | "dibatalkan"
      rule_match_field:
        | "merchant"
        | "product"
        | "counterparty"
        | "amount"
        | "time"
        | "bank_category"
      rule_match_type: "exact" | "contains" | "prefix"
      security_event_type:
        | "login"
        | "login_failed"
        | "logout_all"
        | "session_revoked"
        | "password_changed"
        | "password_reset_requested"
        | "mfa_enrolled"
        | "mfa_removed"
        | "mfa_verified"
        | "email_changed"
        | "data_export"
        | "account_deleted"
      task_priority: "rendah" | "sedang" | "tinggi"
      task_status: "todo" | "doing" | "done"
      transaction_origin:
        | "manual"
        | "sentence"
        | "notification"
        | "proof_image"
        | "statement"
        | "receipt"
        | "recurring"
      transaction_source: "intern" | "freelance" | "kuliah" | "personal"
      transaction_status: "draft" | "confirmed"
      transaction_type: "income" | "expense" | "transfer"
      transfer_direction: "out" | "in"
      user_role: "owner" | "editor" | "viewer"
      workspace_type: "personal" | "shared"
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
      account_type: ["cash", "bank", "e_wallet", "credit_card", "savings"],
      account_visibility: ["shared", "private"],
      activity_kind: ["intern", "freelance", "kuliah", "pribadi"],
      audit_action: ["insert", "update", "delete", "conflict"],
      category_type: ["income", "expense"],
      draft_state: ["baru", "perlu_dilengkapi", "perlu_dicek"],
      exception_action: ["skip", "override"],
      fee_mode: ["expense_transaction", "profit_deduction"],
      project_status: ["draft", "berjalan", "selesai", "dibatalkan"],
      rule_match_field: [
        "merchant",
        "product",
        "counterparty",
        "amount",
        "time",
        "bank_category",
      ],
      rule_match_type: ["exact", "contains", "prefix"],
      security_event_type: [
        "login",
        "login_failed",
        "logout_all",
        "session_revoked",
        "password_changed",
        "password_reset_requested",
        "mfa_enrolled",
        "mfa_removed",
        "mfa_verified",
        "email_changed",
        "data_export",
        "account_deleted",
      ],
      task_priority: ["rendah", "sedang", "tinggi"],
      task_status: ["todo", "doing", "done"],
      transaction_origin: [
        "manual",
        "sentence",
        "notification",
        "proof_image",
        "statement",
        "receipt",
        "recurring",
      ],
      transaction_source: ["intern", "freelance", "kuliah", "personal"],
      transaction_status: ["draft", "confirmed"],
      transaction_type: ["income", "expense", "transfer"],
      transfer_direction: ["out", "in"],
      user_role: ["owner", "editor", "viewer"],
      workspace_type: ["personal", "shared"],
    },
  },
} as const


// Helper Type Aliases for Orbit v5.1
export type Views<T extends keyof Database['public']['Views']> = Database['public']['Views'][T]['Row'];

// Common Enum Aliases
export type AccountType = Enums<'account_type'>;
export type AccountVisibility = Enums<'account_visibility'>;
export type ActivityKind = Enums<'activity_kind'>;
export type AuditAction = Enums<'audit_action'>;
export type CategoryType = Enums<'category_type'>;
export type DraftState = Enums<'draft_state'>;
export type ExceptionAction = Enums<'exception_action'>;
export type FeeMode = Enums<'fee_mode'>;
export type ProjectStatus = Enums<'project_status'>;
export type RuleMatchField = Enums<'rule_match_field'>;
export type RuleMatchType = Enums<'rule_match_type'>;
export type TaskPriority = Enums<'task_priority'>;
export type TaskStatus = Enums<'task_status'>;
export type TransactionOrigin = Enums<'transaction_origin'>;
export type TransactionSource = Enums<'transaction_source'>;
export type TransactionStatus = Enums<'transaction_status'>;
export type TransactionType = Enums<'transaction_type'>;
export type TransferDirection = Enums<'transfer_direction'>;
export type UserRole = Enums<'user_role'>;
export type WorkspaceType = Enums<'workspace_type'>;

// Table Row Aliases
export type Profile = Tables<'profiles'>;
export type Workspace = Tables<'workspaces'>;
export type WorkspaceMember = Tables<'workspace_members'>;
export type Account = Tables<'accounts'>;
export type Category = Tables<'categories'>;
export type CategoryRule = Tables<'category_rules'>;
export type Transaction = Tables<'transactions'>;
export type TransactionItem = Tables<'transaction_items'>;
export type Project = Tables<'projects'>;
export type Task = Tables<'tasks'>;
export type TaskChecklistItem = Tables<'task_checklist_items'>;
export type Event = Tables<'events'>;
export type EventException = Tables<'event_exceptions'>;

// Phase 3 Table Row Aliases
export type Budget = Tables<'budgets'>;
export type RecurringBill = Tables<'recurring_bills'>;
export type RecurringBillInstance = Tables<'recurring_bill_instances'>;
export type SavingsGoal = Tables<'savings_goals'>;
export type IncomeSplitRule = Tables<'income_split_rules'>;
export type SavingsAllocation = Tables<'savings_allocations'>;
export type ExpectedIncome = Tables<'expected_incomes'>;
export type NotificationSettings = Tables<'notification_settings'>;

// View Row Aliases
export type AccountBalance = Views<'v_account_balances'>;
export type MonthlySummary = Views<'v_monthly_summary'>;
export type BudgetProgress = Views<'v_budget_progress'>;

