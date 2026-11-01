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
            foreignKeyName: "tasks_project_id_workspace_id_fkey"
            columns: ["project_id", "workspace_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id", "workspace_id"]
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
    }
    Functions: {
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
      fn_log_sync_conflict: {
        Args: {
          p_payload: Json
          p_row_id: string
          p_table_name: string
          p_workspace_id: string
        }
        Returns: undefined
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
} as const;

export type AccountType = Database["public"]["Enums"]["account_type"];
export type AccountVisibility = Database["public"]["Enums"]["account_visibility"];
export type TransactionSource = Database["public"]["Enums"]["transaction_source"];
export type CategoryType = Database["public"]["Enums"]["category_type"];
export type TransactionType = Database["public"]["Enums"]["transaction_type"];
export type ActivityKind = Database["public"]["Enums"]["activity_kind"];
export type TaskPriority = Database["public"]["Enums"]["task_priority"];
export type TaskStatus = Database["public"]["Enums"]["task_status"];
export type ProjectStatus = Database["public"]["Enums"]["project_status"];

