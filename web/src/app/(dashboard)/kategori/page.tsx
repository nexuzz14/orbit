'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import type { Database, CategoryType } from '@/types/database';
import { Plus, Edit2, Archive, CheckCircle2, CornerDownRight, X, ShieldAlert } from 'lucide-react';

type CategoryRow = Database['public']['Tables']['categories']['Row'];

export default function KategoriPage() {
  const supabase = createClient();
  const [categories, setCategories] = useState<CategoryRow[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Modal / Form state
  const [showModal, setShowModal] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [editingId, setEditingId] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [type, setType] = useState<CategoryType>('expense');
  const [parentId, setParentId] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const loadCategories = useCallback(async () => {
    setLoading(true);

    const { data: memberData } = await supabase
      .from('workspace_members')
      .select('workspace_id')
      .limit(1)
      .single();

    if (!memberData) {
      setLoading(false);
      return;
    }

    setWorkspaceId(memberData.workspace_id);

    const { data } = await supabase
      .from('categories')
      .select('*')
      .eq('workspace_id', memberData.workspace_id)
      .is('deleted_at', null)
      .order('sort_order');

    if (data) {
      setCategories(data);
    }
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadCategories();
  }, [loadCategories]);

  const openCreateModal = (targetType: CategoryType, defaultParentId: string | null = null) => {
    setName('');
    setType(targetType);
    setParentId(defaultParentId);
    setFormError(null);
    setFormMode('create');
    setEditingId(null);
    setShowModal(true);
  };

  const openEditModal = (cat: CategoryRow) => {
    setName(cat.name);
    setType(cat.type);
    setParentId(cat.parent_id);
    setFormError(null);
    setFormMode('edit');
    setEditingId(cat.id);
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    setSubmitting(true);
    setFormError(null);

    if (formMode === 'create') {
      const { error } = await supabase.from('categories').insert({
        workspace_id: workspaceId,
        name: name.trim(),
        type,
        parent_id: parentId || null,
      });

      if (error) {
        setFormError(error.message);
        setSubmitting(false);
        return;
      }
    } else if (formMode === 'edit' && editingId) {
      const { error } = await supabase
        .from('categories')
        .update({
          name: name.trim(),
          type,
          parent_id: parentId || null,
        })
        .eq('id', editingId);

      if (error) {
        setFormError(error.message);
        setSubmitting(false);
        return;
      }
    }

    setSubmitting(false);
    setShowModal(false);
    loadCategories();
  };

  const toggleArchive = async (id: string, currentArchived: boolean) => {
    const { error } = await supabase
      .from('categories')
      .update({ archived: !currentArchived })
      .eq('id', id);

    if (error) {
      alert(`Gagal mengubah status arsip: ${error.message}`);
    } else {
      loadCategories();
    }
  };

  const renderCategoryList = (targetType: CategoryType) => {
    const rootCategories = categories.filter((c) => c.type === targetType && !c.parent_id);

    return (
      <div className="border border-border bg-card rounded-lg divide-y divide-border">
        {rootCategories.length === 0 ? (
          <div className="p-6 text-center text-xs text-muted-foreground">
            Belum ada kategori
          </div>
        ) : (
          rootCategories.map((parent) => {
            const subcategories = categories.filter((c) => c.parent_id === parent.id);

            return (
              <div key={parent.id} className="p-4 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-sm">{parent.name}</span>
                    {parent.system_key && (
                      <span className="inline-flex items-center gap-1 text-[10px] font-semibold uppercase tracking-wider px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                        <ShieldAlert className="w-3 h-3" />
                        Sistem
                      </span>
                    )}
                    {parent.archived && (
                      <span className="text-[10px] font-semibold uppercase tracking-wider px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                        Diarsipkan
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => openCreateModal(targetType, parent.id)}
                      type="button"
                      title="Tambah Subkategori"
                      className="p-1 text-muted-foreground hover:text-foreground transition-colors"
                    >
                      <Plus className="w-4 h-4" />
                    </button>
                    {!parent.system_key && (
                      <>
                        <button
                          onClick={() => openEditModal(parent)}
                          type="button"
                          title="Edit Kategori"
                          className="p-1 text-muted-foreground hover:text-foreground transition-colors"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => toggleArchive(parent.id, parent.archived)}
                          type="button"
                          title={parent.archived ? 'Buka Arsip' : 'Arsipkan'}
                          className="p-1 text-muted-foreground hover:text-foreground transition-colors"
                        >
                          {parent.archived ? (
                            <CheckCircle2 className="w-4 h-4 text-income" />
                          ) : (
                            <Archive className="w-4 h-4" />
                          )}
                        </button>
                      </>
                    )}
                  </div>
                </div>

                {/* Subkategori list */}
                {subcategories.length > 0 && (
                  <div className="pl-6 space-y-1.5 pt-1">
                    {subcategories.map((sub) => (
                      <div
                        key={sub.id}
                        className="flex items-center justify-between text-xs text-muted-foreground hover:text-foreground py-1 px-2 rounded hover:bg-muted/40 transition-colors"
                      >
                        <div className="flex items-center gap-2">
                          <CornerDownRight className="w-3.5 h-3.5 text-muted-foreground/60" />
                          <span>{sub.name}</span>
                          {sub.archived && (
                            <span className="text-[9px] uppercase px-1 py-0.2 rounded bg-muted">
                              Diarsipkan
                            </span>
                          )}
                        </div>

                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => openEditModal(sub)}
                            type="button"
                            title="Edit Subkategori"
                            className="p-1 hover:text-foreground"
                          >
                            <Edit2 className="w-3.5 h-3.5" />
                          </button>
                          <button
                            onClick={() => toggleArchive(sub.id, sub.archived)}
                            type="button"
                            title={sub.archived ? 'Buka Arsip' : 'Arsipkan'}
                            className="p-1 hover:text-foreground"
                          >
                            {sub.archived ? (
                              <CheckCircle2 className="w-3.5 h-3.5 text-income" />
                            ) : (
                              <Archive className="w-3.5 h-3.5" />
                            )}
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    );
  };

  // Kategori induk yang valid untuk pilihan parent (hanya root, bukan sub)
  const availableParents = categories.filter(
    (c) => c.type === type && !c.parent_id && (!editingId || c.id !== editingId)
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Kategori</h1>
          <p className="text-sm text-muted-foreground">
            Struktur klasifikasi pengeluaran dan pemasukan (hierarki maksimal 2 tingkat)
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => openCreateModal('expense')}
            type="button"
            className="inline-flex items-center gap-2 px-3 py-2 bg-foreground text-background text-sm font-medium rounded-md hover:opacity-90 transition-opacity"
          >
            <Plus className="w-4 h-4" />
            <span>Tambah Kategori</span>
          </button>
        </div>
      </div>

      {loading ? (
        <div className="p-8 text-center text-sm text-muted-foreground">Memuat data kategori...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-semibold">Pengeluaran</h2>
              <span className="text-xs text-muted-foreground">
                {categories.filter((c) => c.type === 'expense').length} kategori
              </span>
            </div>
            {renderCategoryList('expense')}
          </div>

          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-semibold">Pemasukan</h2>
              <span className="text-xs text-muted-foreground">
                {categories.filter((c) => c.type === 'income').length} kategori
              </span>
            </div>
            {renderCategoryList('income')}
          </div>
        </div>
      )}

      {/* Modal Form Kategori */}
      {showModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md border border-border bg-card rounded-lg shadow-lg p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <h2 className="text-lg font-semibold">
                {formMode === 'create'
                  ? parentId
                    ? 'Tambah Subkategori'
                    : 'Tambah Kategori Baru'
                  : 'Edit Kategori'}
              </h2>
              <button
                onClick={() => setShowModal(false)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {formError && (
              <div className="p-3 text-sm rounded bg-expense/10 text-expense border border-expense/20">
                {formError}
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-medium mb-1">Nama Kategori</label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Contoh: Makan Siang, Kursus, Langganan Musik"
                  className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium mb-1">Jenis</label>
                  <select
                    value={type}
                    disabled={!!parentId}
                    onChange={(e) => setType(e.target.value as CategoryType)}
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none disabled:opacity-60"
                  >
                    <option value="expense">Pengeluaran</option>
                    <option value="income">Pemasukan</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-medium mb-1">Kategori Induk</label>
                  <select
                    value={parentId || ''}
                    onChange={(e) => setParentId(e.target.value || null)}
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                  >
                    <option value="">Tanpa Induk (Kategori Utama)</option>
                    {availableParents.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="px-4 py-2 text-sm font-medium border border-border rounded hover:bg-muted transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 text-sm font-medium bg-foreground text-background rounded hover:opacity-90 transition-opacity disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Kategori'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
