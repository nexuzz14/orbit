'use client';

import React, { useEffect, useRef, useState } from 'react';
import { EditorContent, useEditor } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import {
  Bold,
  Code2,
  Heading2,
  Italic,
  List,
  ListOrdered,
  Quote,
  Strikethrough,
} from 'lucide-react';
import type { Json } from '@/types/database';
import { plainTextToTiptapDoc } from '@/lib/task-v2';
import { BlockContainer, cn } from '@/components/ui';

interface TaskRichEditorProps {
  taskId: string;
  initialBlocks: Json | null;
  initialDescription: string | null;
  onSave: (blocks: Json, plainText: string | null) => Promise<void>;
}

function resolveInitialContent(blocks: Json | null, plain: string | null): Json {
  if (blocks && typeof blocks === 'object' && !Array.isArray(blocks)) {
    const obj = blocks as Record<string, unknown>;
    if (obj.type === 'doc') return blocks;
  }
  return plainTextToTiptapDoc(plain);
}

export function TaskRichEditor({
  taskId,
  initialBlocks,
  initialDescription,
  onSave,
}: TaskRichEditorProps) {
  const [saveState, setSaveState] = useState<'idle' | 'saving' | 'saved'>('idle');
  const saveTimerRef = useRef<number | null>(null);
  const currentTaskIdRef = useRef<string>(taskId);
  const onSaveRef = useRef(onSave);
  onSaveRef.current = onSave;

  const editor = useEditor({
    extensions: [StarterKit],
    immediatelyRender: false,
    content: resolveInitialContent(initialBlocks, initialDescription) as Record<string, unknown>,
    editorProps: {
      attributes: {
        class:
          'min-h-[120px] px-3 py-2.5 text-sm text-foreground focus:outline-none [&_h2]:text-base [&_h2]:font-semibold [&_h2]:mt-2 [&_h2]:mb-1 [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5 [&_blockquote]:border-l-2 [&_blockquote]:border-border-strong [&_blockquote]:pl-3 [&_blockquote]:text-muted-foreground [&_pre]:rounded-md [&_pre]:bg-subtle [&_pre]:p-2.5 [&_pre]:font-mono [&_pre]:text-xs [&_p]:leading-relaxed [&_p+p]:mt-1.5',
      },
    },
    onUpdate: ({ editor: ed }) => {
      if (saveTimerRef.current) {
        window.clearTimeout(saveTimerRef.current);
      }
      setSaveState('saving');
      saveTimerRef.current = window.setTimeout(async () => {
        const json = ed.getJSON() as Json;
        const plain = ed.getText().trim() || null;
        await onSaveRef.current(json, plain);
        setSaveState('saved');
      }, 650);
    },
    onBlur: async ({ editor: ed }) => {
      if (saveTimerRef.current) {
        window.clearTimeout(saveTimerRef.current);
        saveTimerRef.current = null;
      }
      const json = ed.getJSON() as Json;
      const plain = ed.getText().trim() || null;
      setSaveState('saving');
      await onSaveRef.current(json, plain);
      setSaveState('saved');
    },
  });

  useEffect(() => {
    if (!editor) return;
    if (currentTaskIdRef.current !== taskId) {
      currentTaskIdRef.current = taskId;
      if (saveTimerRef.current) {
        window.clearTimeout(saveTimerRef.current);
        saveTimerRef.current = null;
      }
      const nextContent = resolveInitialContent(initialBlocks, initialDescription);
      editor.commands.setContent(nextContent as Record<string, unknown>, { emitUpdate: false });
      setSaveState('idle');
    }
  }, [editor, taskId, initialBlocks, initialDescription]);

  useEffect(() => {
    return () => {
      if (saveTimerRef.current) {
        window.clearTimeout(saveTimerRef.current);
      }
    };
  }, []);

  const toolbarButtons = editor
    ? [
        {
          label: 'Tebal',
          icon: Bold,
          active: editor.isActive('bold'),
          action: () => editor.chain().focus().toggleBold().run(),
        },
        {
          label: 'Miring',
          icon: Italic,
          active: editor.isActive('italic'),
          action: () => editor.chain().focus().toggleItalic().run(),
        },
        {
          label: 'Coret',
          icon: Strikethrough,
          active: editor.isActive('strike'),
          action: () => editor.chain().focus().toggleStrike().run(),
        },
        {
          label: 'Subjudul',
          icon: Heading2,
          active: editor.isActive('heading', { level: 2 }),
          action: () => editor.chain().focus().toggleHeading({ level: 2 }).run(),
        },
        {
          label: 'Daftar Poin',
          icon: List,
          active: editor.isActive('bulletList'),
          action: () => editor.chain().focus().toggleBulletList().run(),
        },
        {
          label: 'Daftar Bernomor',
          icon: ListOrdered,
          active: editor.isActive('orderedList'),
          action: () => editor.chain().focus().toggleOrderedList().run(),
        },
        {
          label: 'Kutipan',
          icon: Quote,
          active: editor.isActive('blockquote'),
          action: () => editor.chain().focus().toggleBlockquote().run(),
        },
        {
          label: 'Blok Kode',
          icon: Code2,
          active: editor.isActive('codeBlock'),
          action: () => editor.chain().focus().toggleCodeBlock().run(),
        },
      ]
    : [];

  return (
    <BlockContainer
      title="Deskripsi & Catatan"
      action={
        <span className="text-[11px] font-medium text-muted-foreground">
          {saveState === 'saving'
            ? 'Menyimpan...'
            : saveState === 'saved'
            ? 'Tersimpan'
            : 'Blok Editor'}
        </span>
      }
    >
      <div className="rounded-md border border-border bg-background overflow-hidden">
        <div
          role="toolbar"
          aria-label="Pemformatan blok catatan"
          className="flex flex-wrap items-center gap-0.5 border-b border-border bg-sidebar/60 p-1"
        >
          {toolbarButtons.map((btn) => {
            const Icon = btn.icon;
            return (
              <button
                key={btn.label}
                type="button"
                onClick={btn.action}
                aria-label={btn.label}
                aria-pressed={btn.active}
                title={btn.label}
                className={cn(
                  'inline-flex h-11 w-11 items-center justify-center rounded-sm transition-colors',
                  btn.active
                    ? 'bg-primary-subtle text-primary'
                    : 'text-muted-foreground hover:bg-hover hover:text-foreground'
                )}
              >
                <Icon className="h-4 w-4" />
              </button>
            );
          })}
        </div>

        <EditorContent editor={editor} />
      </div>
    </BlockContainer>
  );
}
