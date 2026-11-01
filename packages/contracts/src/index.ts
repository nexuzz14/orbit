// Orbit Shared Contracts (Fase 1)

export type ActivityKind = 'intern' | 'freelance' | 'kuliah' | 'pribadi';
export type TransactionSource = 'intern' | 'freelance' | 'kuliah' | 'personal';
export type TransactionType = 'income' | 'expense' | 'transfer';
export type TransactionStatus = 'draft' | 'confirmed';
export type DraftState = 'baru' | 'perlu_dilengkapi' | 'perlu_dicek';
export type UserRole = 'owner' | 'editor' | 'viewer';
export type AccountType = 'cash' | 'bank' | 'e_wallet' | 'credit_card' | 'savings';
export type AccountVisibility = 'shared' | 'private';
export type CategoryType = 'income' | 'expense';

export interface Profile {
  id: string;
  display_name: string;
  base_currency: string;
  timezone: string;
  month_start_day: number;
  created_at: string;
  updated_at: string;
}

export interface Workspace {
  id: string;
  name: string;
  type: 'personal' | 'shared';
  base_currency: string;
  owner_id: string;
  created_at: string;
  updated_at: string;
}

export interface Account {
  id: string;
  workspace_id: string;
  name: string;
  type: AccountType;
  currency: string;
  initial_balance: string;
  is_liquid: boolean;
  visibility: AccountVisibility;
  color?: string | null;
  icon?: string | null;
  sort_order: number;
  archived: boolean;
  created_by?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface Category {
  id: string;
  workspace_id: string;
  name: string;
  type: CategoryType;
  icon?: string | null;
  color?: string | null;
  parent_id?: string | null;
  system_key?: string | null;
  sort_order: number;
  archived: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface Transaction {
  id: string;
  workspace_id: string;
  account_id: string;
  category_id?: string | null;
  project_id?: string | null;
  type: TransactionType;
  status: TransactionStatus;
  draft_state?: DraftState | null;
  amount: string;
  currency: string;
  fx_rate: string;
  amount_base: string;
  source?: TransactionSource | null;
  merchant?: string | null;
  merchant_normalized?: string | null;
  location_hint?: string | null;
  counterparty?: string | null;
  counterparty_bank?: string | null;
  product_name?: string | null;
  txn_kind?: string | null;
  note?: string | null;
  occurred_at: string;
  transfer_group_id?: string | null;
  transfer_direction?: 'out' | 'in' | null;
  origin: string;
  created_by?: string | null;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface AccountBalance {
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
  last_txn_at?: string | null;
}

export interface MonthlySummary {
  workspace_id: string;
  month_start: string;
  month_end: string;
  source?: TransactionSource | null;
  is_total: boolean;
  currency: string;
  income: number;
  expense: number;
  net: number;
  txn_count: number;
}
