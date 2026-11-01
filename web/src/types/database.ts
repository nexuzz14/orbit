export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type ActivityKind = 'intern' | 'freelance' | 'kuliah' | 'pribadi';
export type TransactionSource = 'intern' | 'freelance' | 'kuliah' | 'personal';
export type TransactionType = 'income' | 'expense' | 'transfer';
export type TransactionStatus = 'draft' | 'confirmed';
export type DraftState = 'baru' | 'perlu_dilengkapi' | 'perlu_dicek';
export type UserRole = 'owner' | 'editor' | 'viewer';
export type AccountType = 'cash' | 'bank' | 'e_wallet' | 'credit_card' | 'savings';
export type AccountVisibility = 'shared' | 'private';
export type CategoryType = 'income' | 'expense';

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          display_name: string;
          base_currency: string;
          timezone: string;
          month_start_day: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          display_name?: string;
          base_currency?: string;
          timezone?: string;
          month_start_day?: number;
        };
        Update: {
          display_name?: string;
          base_currency?: string;
          timezone?: string;
          month_start_day?: number;
        };
      };
      workspaces: {
        Row: {
          id: string;
          name: string;
          type: 'personal' | 'shared';
          base_currency: string;
          owner_id: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          type?: 'personal' | 'shared';
          base_currency?: string;
          owner_id: string;
        };
        Update: {
          name?: string;
        };
      };
      workspace_members: {
        Row: {
          workspace_id: string;
          user_id: string;
          role: UserRole;
          created_at: string;
          updated_at: string;
        };
      };
      accounts: {
        Row: {
          id: string;
          workspace_id: string;
          name: string;
          type: AccountType;
          currency: string;
          initial_balance: number;
          is_liquid: boolean;
          visibility: AccountVisibility;
          color: string | null;
          icon: string | null;
          sort_order: number;
          archived: boolean;
          created_by: string | null;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
        Insert: {
          id?: string;
          workspace_id: string;
          name: string;
          type: AccountType;
          currency: string;
          initial_balance?: number;
          is_liquid?: boolean;
          visibility?: AccountVisibility;
          color?: string | null;
          icon?: string | null;
          sort_order?: number;
          archived?: boolean;
        };
        Update: {
          name?: string;
          type?: AccountType;
          currency?: string;
          initial_balance?: number;
          is_liquid?: boolean;
          visibility?: AccountVisibility;
          color?: string | null;
          icon?: string | null;
          sort_order?: number;
          archived?: boolean;
          deleted_at?: string | null;
        };
      };
      categories: {
        Row: {
          id: string;
          workspace_id: string;
          name: string;
          type: CategoryType;
          icon: string | null;
          color: string | null;
          parent_id: string | null;
          system_key: string | null;
          sort_order: number;
          archived: boolean;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
        Insert: {
          id?: string;
          workspace_id: string;
          name: string;
          type: CategoryType;
          icon?: string | null;
          color?: string | null;
          parent_id?: string | null;
          system_key?: string | null;
          sort_order?: number;
          archived?: boolean;
        };
        Update: {
          name?: string;
          type?: CategoryType;
          icon?: string | null;
          color?: string | null;
          parent_id?: string | null;
          sort_order?: number;
          archived?: boolean;
          deleted_at?: string | null;
        };
      };
      transactions: {
        Row: {
          id: string;
          workspace_id: string;
          account_id: string;
          category_id: string | null;
          project_id: string | null;
          type: TransactionType;
          status: TransactionStatus;
          draft_state: DraftState | null;
          amount: number;
          currency: string;
          fx_rate: number;
          amount_base: number;
          source: TransactionSource | null;
          merchant: string | null;
          merchant_normalized: string | null;
          location_hint: string | null;
          counterparty: string | null;
          counterparty_bank: string | null;
          product_name: string | null;
          txn_kind: string | null;
          note: string | null;
          occurred_at: string;
          transfer_group_id: string | null;
          transfer_direction: 'out' | 'in' | null;
          origin: string;
          source_package: string | null;
          import_batch_id: string | null;
          external_id_hash: string | null;
          dedupe_hash: string | null;
          tags: string[];
          created_by: string | null;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
        Insert: {
          id?: string;
          workspace_id: string;
          account_id: string;
          category_id?: string | null;
          project_id?: string | null;
          type: TransactionType;
          status?: TransactionStatus;
          draft_state?: DraftState | null;
          amount: number;
          currency: string;
          fx_rate?: number;
          source?: TransactionSource | null;
          merchant?: string | null;
          location_hint?: string | null;
          counterparty?: string | null;
          counterparty_bank?: string | null;
          product_name?: string | null;
          txn_kind?: string | null;
          note?: string | null;
          occurred_at?: string;
          origin?: string;
          tags?: string[];
        };
        Update: {
          account_id?: string;
          category_id?: string | null;
          project_id?: string | null;
          type?: TransactionType;
          status?: TransactionStatus;
          draft_state?: DraftState | null;
          amount?: number;
          currency?: string;
          fx_rate?: number;
          source?: TransactionSource | null;
          merchant?: string | null;
          note?: string | null;
          occurred_at?: string;
          tags?: string[];
          deleted_at?: string | null;
        };
      };
    };
    Views: {
      v_account_balances: {
        Row: {
          account_id: string;
          workspace_id: string;
          name: string;
          type: AccountType;
          currency: string;
          is_liquid: boolean;
          archived: boolean;
          visibility: AccountVisibility;
          sort_order: number;
          initial_balance: number;
          balance: number;
          confirmed_txn_count: number;
          last_txn_at: string | null;
        };
      };
      v_monthly_summary: {
        Row: {
          workspace_id: string;
          month_start: string;
          month_end: string;
          source: TransactionSource | null;
          is_total: boolean;
          currency: string;
          income: number;
          expense: number;
          net: number;
          txn_count: number;
        };
      };
    };
    Functions: {
      fn_confirm_draft: {
        Args: {
          p_transaction_id: string;
          p_category_id?: string;
          p_account_id?: string;
          p_source?: TransactionSource;
          p_project_id?: string;
        };
        Returns: unknown;
      };
      fn_create_transfer: {
        Args: {
          p_workspace_id: string;
          p_from_account_id: string;
          p_to_account_id: string;
          p_amount_out: number;
          p_occurred_at?: string;
          p_note?: string;
          p_amount_in?: number;
          p_fee?: number;
          p_group_id?: string;
        };
        Returns: string;
      };
      fn_delete_transaction: {
        Args: {
          p_transaction_id: string;
        };
        Returns: void;
      };
      fn_restore_transaction: {
        Args: {
          p_transaction_id: string;
        };
        Returns: void;
      };
      fn_my_sessions: {
        Args: Record<PropertyKey, never>;
        Returns: {
          id: string;
          created_at: string;
          updated_at: string;
          user_agent: string | null;
          aal: string;
          is_current: boolean;
        }[];
      };
      fn_revoke_session: {
        Args: {
          p_session_id: string;
        };
        Returns: boolean;
      };
    };
  };
}
