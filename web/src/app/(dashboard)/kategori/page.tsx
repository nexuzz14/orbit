'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import type { Database, CategoryType } from '@/types/database';
import { Plus, Edit2, Archive, CheckCircle2, CornerDownRight, ShieldAlert, Tags } from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
  Button,
  Input,
  Select,
  Dialog,
  StatusBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  LainnyaSubNav,
} from '@/components/ui';

type CategoryRow = Database['public']['Tables']['categories']['Row'];

export default function KategoriPage() {
  const supabase = createClient();
  const [categories, setCategories] = useState<CategoryRow[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

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
    setLoadError(null);

    try {
      const { data: memberData, error: memberErr } = await supabase
        .from('workspace_members')
        .select('workspace_id')
        .limit(1)
        .single();

      if (memberErr) throw memberErr;
      if (!memberData) {
        setLoading(false);
        return;
      }

      setWorkspaceId(memberData.workspace_id);

      const { data, error } = await supabase
        .from('categories')
        .select('*')
        .eq('workspace_id', memberData.workspace_id)
        .is('deleted_at', null)
        .order('sort_order');

      if (error) throw error;
      if (data) {
        setCategories(data);
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat daftar kategori.');
    } finally {
      setLoading(false);
    }
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
      <Card className="overflow-hidden">
        <CardHeader>
          <CardTitle>
            {targetType === 'expense' ? 'Kategori Pengeluaran' : 'Kategori Pemasukan'}
          </CardTitle>
          <span className="text-xs text-muted-foreground tabular-nums">
            {categories.filter((c) => c.type === targetType).length} kategori
          </span>
        </CardHeader>

        <div className="divide-y divide-border">
          {rootCategories.length === 0 ? (
            <div className="p-6 text-center text-xs text-muted-foreground">
              Belum ada kategori
            </div>
          ) : (
            rootCategories.map((parent) => {
              const subcategories = categories.filter((c) => c.parent_id === parent.id);

              return (
                <div key={parent.id} className="p-4 space-y-2">
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-sm text-foreground">{parent.name}</span>
                      {parent.system_key && (
                        <StatusBadge variant="neutral">
                          <ShieldAlert className="w-3 h-3" />
                          <span>Sistem</span>
                        </StatusBadge>
                      )}
                      {parent.archived && (
                        <StatusBadge variant="warning">Diarsipkan</StatusBadge>
                      )}
                    </div>

                    <div className="flex items-center gap-1">
                      <Button
                        onClick={() => openCreateModal(targetType, parent.id)}
                        type="button"
                        variant="ghost"
                        size="icon"
                        aria-label={`Tambah subkategori di ${parent.name}`}
                      >
                        <Plus className="w-4 h-4" />
                      </Button>
                      {!parent.system_key && (
                        <>
                          <Button
                            onClick={() => openEditModal(parent)}
                            type="button"
                            variant="ghost"
                            size="icon"
                            aria-label={`Ubah ${parent.name}`}
                          >
                            <Edit2 className="w-4 h-4" />
                          </Button>
                          <Button
                            onClick={() => toggleArchive(parent.id, parent.archived)}
                            type="button"
                            variant="ghost"
                            size="icon"
                            aria-label={parent.archived ? `Buka arsip ${parent.name}` : `Arsipkan ${parent.name}`}
                          >
                            {parent.archived ? (
                              <CheckCircle2 className="w-4 h-4 text-income" />
                            ) : (
                              <Archive className="w-4 h-4" />
                            )}
                          </Button>
                        </>
                      )}
                    </div>
                  </div>

                  {subcategories.length > 0 && (
                    <div className="pl-5 space-y-1 pt-1">
                      {subcategories.map((sub) => (
                        <div
                          key={sub.id}
                          className="flex items-center justify-between text-xs text-muted-foreground hover:text-foreground py-1 px-2 rounded-lg hover:bg-muted/40 transition-colors"
                        >
                          <div className="flex items-center gap-2">
                            <CornerDownRight className="w-3.5 h-3.5 text-muted-foreground/60" />
                            <span className="font-medium text-foreground">{sub.name}</span>
                            {sub.archived && (
                              <StatusBadge variant="warning">Diarsipkan</StatusBadge>
                            )}
                          </div>

                          <div className="flex items-center gap-1">
                            <Button
                              onClick={() => openEditModal(sub)}
                              type="button"
                              variant="ghost"
                              size="icon"
                              aria-label={`Ubah ${sub.name}`}
                            >
                              <Edit2 className="w-3.5 h-3.5" />
                            </Button>
                            <Button
                              onClick={() => toggleArchive(sub.id, sub.archived)}
                              type="button"
                              variant="ghost"
                              size="icon"
                              aria-label={sub.archived ? `Buka arsip ${sub.name}` : `Arsipkan ${sub.name}`}
                            >
                              {sub.archived ? (
                                <CheckCircle2 className="w-3.5 h-3.5 text-income" />
                              ) : (
                                <Archive className="w-3.5 h-3.5" />
                              )}
                            </Button>
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
      </Card>
    );
  };

  const availableParents = categories.filter(
    (c) => c.type === type && !c.parent_id && (!editingId || c.id !== editingId)
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Lainnya</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Struktur klasifikasi pengeluaran dan pemasukan (hierarki maksimal 2 tingkat)
          </p>
        </div>

        <Button onClick={() => openCreateModal('expense')} type="button">
          <Plus className="w-4 h-4" />
          <span>Tambah Kategori</span>
        </Button>
      </div>

      <LainnyaSubNav />

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadCategories} />
      ) : loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6" aria-busy="true">
          <Skeleton className="h-64 w-full" />
          <Skeleton className="h-64 w-full" />
        </div>
      ) : categories.length === 0 ? (
        <EmptyState
          icon={<Tags className="w-5 h-5" />}
          title="Belum ada kategori terdaftar"
          description="Buat kategori pengeluaran atau pemasukan untuk mengelompokkan transaksi Anda."
          actionLabel="Tambah Kategori"
          onAction={() => openCreateModal('expense')}
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {renderCategoryList('expense')}
          {renderCategoryList('income')}
        </div>
      )}

      {/* Modal Form Kategori */}
      <Dialog
        open={showModal}
        onClose={() => setShowModal(false)}
        title={
          formMode === 'create'
            ? parentId
              ? 'Tambah Subkategori'
              : 'Tambah Kategori Baru'
            : 'Ubah Kategori'
        }
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          {formError && (
            <div className="p-3 text-xs rounded-lg bg-expense/10 text-expense border border-expense/20">
              {formError}
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-foreground mb-1.5">
              Nama Kategori
            </label>
            <Input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Contoh: Makan Siang, Kursus, Langganan Musik"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">Jenis</label>
              <Select
                value={type}
                disabled={!!parentId}
                onChange={(e) => setType(e.target.value as CategoryType)}
              >
                <option value="expense">Pengeluaran</option>
                <option value="income">Pemasukan</option>
              </Select>
            </div>

            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">
                Kategori Induk
              </label>
              <Select
                value={parentId || ''}
                onChange={(e) => setParentId(e.target.value || null)}
              >
                <option value="">Tanpa Induk (Kategori Utama)</option>
                {availableParents.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </Select>
            </div>
          </div>

          <div className="flex items-center justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Menyimpan...' : 'Simpan Kategori'}
            </Button>
          </div>
        </form>
      </Dialog>
    </div>
  );
}
