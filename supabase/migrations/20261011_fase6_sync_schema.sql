-- ==============================================================================
-- SKEMA SINKRONISASI SUPABASE POSTGRESQL "ANAK KOST" (Fase 6)
-- Sesuai PRD GAMINI.md Bagian 6.8, 6.9, dan 7.5
-- Kompatibel penuh antara Client Android (S24+) dan Client macOS (MacBook M2)
-- ==============================================================================

-- 1. Buat Schema Privat (Tidak diekspos langsung ke PostgREST Data API)
CREATE SCHEMA IF NOT EXISTS private;

-- Aktifkan ekstensi UUID dan Kriptografi jika belum aktif
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. TABEL INFRASTRUKTUR SINKRONISASI SERVER
-- ==============================================================================

-- State Sinkronisasi Pengguna (Lock per-user saat commit perubahan)
CREATE TABLE IF NOT EXISTS private.sync_user_state (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    last_seq BIGINT NOT NULL DEFAULT 0,
    dataset_generation BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pendaftaran Perangkat Multi-Device (Android S24+ & MacBook Air M2)
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY, -- UUID instalasi perangkat
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'macos', 'web')),
    device_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    device_generation BIGINT NOT NULL DEFAULT 1,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- Binding Sesi Perangkat dari JWT Token Server
CREATE TABLE IF NOT EXISTS private.device_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    auth_session_id UUID,
    device_generation BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);

-- Catatan Operasi Idempotent (Gate Test T05: Mencegah efek ganda pada retry push)
CREATE TABLE IF NOT EXISTS private.sync_operations (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    operation_id UUID NOT NULL,
    aggregate_type TEXT NOT NULL,
    aggregate_id TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    response_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, operation_id)
);

-- Change Feed Immutable (Gate Test T07: Tarik perubahan dan tombstone)
CREATE TABLE IF NOT EXISTS private.sync_changes (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    change_seq BIGINT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    row_version INT NOT NULL DEFAULT 1,
    is_tombstone BOOLEAN NOT NULL DEFAULT FALSE,
    operation_id UUID NOT NULL,
    row_snapshot JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, change_seq)
);

-- ==============================================================================
-- 3. TABEL DOMAIN UTAMA (Schema Public)
-- ==============================================================================

-- Profil Pengguna
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    crypto_context_id UUID NOT NULL,
    display_name TEXT,
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    currency TEXT NOT NULL DEFAULT 'IDR',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    version INT NOT NULL DEFAULT 1
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Dompet Keuangan
CREATE TABLE IF NOT EXISTS public.wallets (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    wallet_type TEXT NOT NULL, -- cash, bank, ewallet, other
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_wallets_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

-- Kategori Keuangan
CREATE TABLE IF NOT EXISTS public.categories (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
    icon_key TEXT NOT NULL DEFAULT 'category',
    color_key TEXT NOT NULL DEFAULT 'indigo',
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_categories_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- Transaksi Keuangan
CREATE TABLE IF NOT EXISTS public.transactions (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kind TEXT NOT NULL, -- income, expense, transfer, opening, adjustment, void
    status TEXT NOT NULL DEFAULT 'posted',
    amount_rp BIGINT NOT NULL CHECK (amount_rp > 0),
    category_id TEXT,
    occurred_at BIGINT NOT NULL,
    local_date TEXT NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    merchant TEXT,
    note TEXT,
    source TEXT NOT NULL DEFAULT 'manual',
    refund_of_id TEXT,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_transactions_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Mutasi Ledger Dompet
CREATE TABLE IF NOT EXISTS public.wallet_entries (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_id TEXT NOT NULL,
    wallet_id TEXT NOT NULL,
    amount_rp BIGINT NOT NULL, -- Positif untuk masuk/debit, Negatif untuk keluar/kredit
    entry_role TEXT NOT NULL, -- main, source, destination, fee
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_wallet_entries_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.wallet_entries ENABLE ROW LEVEL SECURITY;

-- Barang Inventaris Kost
CREATE TABLE IF NOT EXISTS public.inventory_items (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    stock_category TEXT,
    base_unit TEXT NOT NULL DEFAULT 'pcs',
    minimum_qty_milli INT NOT NULL DEFAULT 0,
    location_label TEXT,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_inventory_items_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;

-- Mutasi Stok Inventaris (Append-only)
CREATE TABLE IF NOT EXISTS public.inventory_movements (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    inventory_item_id TEXT NOT NULL,
    movement_type TEXT NOT NULL, -- opening, add, use, adjust, reversal
    quantity_delta_milli INT NOT NULL,
    occurred_at BIGINT NOT NULL,
    reason TEXT,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_inventory_movements_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

-- Agenda & Kegiatan
CREATE TABLE IF NOT EXISTS public.activity_events (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    calendar_id TEXT,
    title TEXT NOT NULL,
    notes TEXT,
    location_text TEXT,
    start_local TEXT NOT NULL,
    end_local TEXT NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    recurrence_kind TEXT NOT NULL DEFAULT 'none',
    interval_count INT NOT NULL DEFAULT 1,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_activity_events_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;

-- Tugas & Deadline
CREATE TABLE IF NOT EXISTS public.tasks (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    calendar_id TEXT,
    event_id TEXT,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'todo',
    priority TEXT NOT NULL DEFAULT 'normal',
    due_local_date TEXT,
    completed_at BIGINT,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_tasks_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Template Tagihan
CREATE TABLE IF NOT EXISTS public.bill_templates (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category_id TEXT NOT NULL,
    estimated_amount_rp BIGINT,
    frequency TEXT NOT NULL DEFAULT 'monthly',
    interval_count INT NOT NULL DEFAULT 1,
    anchor_date TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_bill_templates_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.bill_templates ENABLE ROW LEVEL SECURITY;

-- Occurrence Tagihan
CREATE TABLE IF NOT EXISTS public.bill_occurrences (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    template_id TEXT NOT NULL,
    period_key TEXT NOT NULL,
    due_date TEXT NOT NULL,
    amount_due_rp BIGINT,
    amount_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_bill_occurrences_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.bill_occurrences ENABLE ROW LEVEL SECURITY;

-- Dokumen Brankas Terenkripsi
CREATE TABLE IF NOT EXISTS public.documents (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    encrypted_metadata BYTEA NOT NULL,
    nonce BYTEA NOT NULL,
    crypto_context_id TEXT NOT NULL,
    crypto_version INT NOT NULL DEFAULT 1,
    key_version INT NOT NULL DEFAULT 1,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_documents_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- Lampiran Fisik Terenkripsi
CREATE TABLE IF NOT EXISTS public.attachments (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    media_kind TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    storage_bucket TEXT NOT NULL DEFAULT 'personal-media',
    storage_path TEXT NOT NULL,
    ciphertext_sha256 TEXT NOT NULL,
    byte_size BIGINT NOT NULL,
    crypto_context_id TEXT NOT NULL,
    crypto_version INT NOT NULL DEFAULT 1,
    key_version INT NOT NULL DEFAULT 1,
    wrapped_file_key BYTEA NOT NULL,
    wrap_nonce BYTEA NOT NULL,
    file_nonce BYTEA NOT NULL,
    remote_state TEXT NOT NULL DEFAULT 'pending',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_attachments_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

-- Tautan Lampiran ke Transaksi / Dokumen
CREATE TABLE IF NOT EXISTS public.attachment_links (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    attachment_id TEXT NOT NULL,
    transaction_id TEXT,
    inventory_item_id TEXT,
    document_id TEXT,
    bill_occurrence_id TEXT,
    link_role TEXT NOT NULL DEFAULT 'evidence',
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL,
    deleted_at BIGINT,
    version INT NOT NULL DEFAULT 1,
    last_operation_id TEXT NOT NULL,
    origin_device_id TEXT NOT NULL,
    CONSTRAINT uq_attachment_links_user_id UNIQUE (user_id, id)
);
ALTER TABLE public.attachment_links ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- 4. KEBIJAKAN ROW LEVEL SECURITY (RLS)
-- ==============================================================================

-- Helper function memeriksa keabsahan session
CREATE OR REPLACE FUNCTION private.is_registered_session()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, private
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.devices d
        WHERE d.user_id = auth.uid()
          AND d.status = 'active'
    );
$$;

-- Terapkan RLS Owner pada seluruh tabel domain
DO $$
DECLARE
    tbl text;
    col_name text;
BEGIN
    FOR tbl IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name IN (
            'devices', 'profiles', 'wallets', 'categories', 'transactions',
            'wallet_entries', 'inventory_items', 'inventory_movements',
            'activity_events', 'tasks', 'bill_templates', 'bill_occurrences',
            'documents', 'attachments', 'attachment_links'
          )
    LOOP
        IF tbl = 'profiles' THEN
            col_name := 'id';
        ELSE
            col_name := 'user_id';
        END IF;

        EXECUTE format('
            DROP POLICY IF EXISTS %I_owner_policy ON public.%I;
            CREATE POLICY %I_owner_policy ON public.%I
                FOR ALL TO authenticated
                USING (%I = auth.uid())
                WITH CHECK (%I = auth.uid());
        ', tbl, tbl, tbl, tbl, col_name, col_name);
    END LOOP;
END $$;

-- ==============================================================================
-- 5. RPC PROCEDURES (register_device, apply_operation, pull_changes, revoke_device)
-- ==============================================================================

-- A. Registrasi Perangkat Baru (RPC `register_device`)
CREATE OR REPLACE FUNCTION public.register_device(
    p_device_id UUID,
    p_device_name TEXT,
    p_platform TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna tidak terautentikasi';
    END IF;

    -- Pastikan sync_user_state ada untuk pengguna ini
    INSERT INTO private.sync_user_state (user_id, last_seq, dataset_generation)
    VALUES (v_user_id, 0, 1)
    ON CONFLICT (user_id) DO NOTHING;

    -- Daftarkan atau aktifkan kembali perangkat
    INSERT INTO public.devices (
        id, user_id, platform, device_name, status, registered_at, last_seen_at
    )
    VALUES (
        p_device_id, v_user_id, p_platform, p_device_name, 'active', NOW(), NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        device_name = EXCLUDED.device_name,
        status = 'active',
        last_seen_at = NOW(),
        revoked_at = NULL;

    -- Catat sesi perangkat
    INSERT INTO private.device_sessions (user_id, device_id)
    VALUES (v_user_id, p_device_id);

    RETURN jsonb_build_object('status', 'ok', 'device_id', p_device_id);
END;
$$;

-- B. Pengiriman Operasi Atomik & Idempotent (RPC `apply_operation`)
CREATE OR REPLACE FUNCTION public.apply_operation(
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_op_id UUID := (p_payload->>'operation_id')::UUID;
    v_agg_type TEXT := p_payload->>'aggregate_type';
    v_agg_id TEXT := p_payload->>'aggregate_id';
    v_cmd JSONB := (p_payload->'commands')->0;
    v_request_hash TEXT := md5(p_payload::TEXT);
    v_existing_op RECORD;
    v_new_seq BIGINT;
    v_new_version INT := 1;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna tidak terautentikasi';
    END IF;

    -- 1. Kunci User State agar sequence konsisten per-pemilik
    SELECT last_seq INTO v_new_seq
    FROM private.sync_user_state
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF v_new_seq IS NULL THEN
        INSERT INTO private.sync_user_state (user_id, last_seq, dataset_generation)
        VALUES (v_user_id, 1, 1)
        RETURNING last_seq INTO v_new_seq;
    ELSE
        v_new_seq := v_new_seq + 1;
        UPDATE private.sync_user_state
        SET last_seq = v_new_seq, updated_at = NOW()
        WHERE user_id = v_user_id;
    END IF;

    -- 2. GATE TEST T05: Cek Idempotensi (Apakah operation_id sudah pernah diproses)
    SELECT * INTO v_existing_op
    FROM private.sync_operations
    WHERE user_id = v_user_id AND operation_id = v_op_id;

    IF FOUND THEN
        -- Kembalikan respons yang sama persis tanpa menduplikasi data
        RETURN v_existing_op.response_json;
    END IF;

    -- 3. Terapkan Perubahan Domain Berdasarkan Aggregate Type
    IF v_agg_type = 'transaction' THEN
        INSERT INTO public.transactions (
            id, user_id, kind, amount_rp, local_date, occurred_at, merchant, note,
            created_at, updated_at, last_operation_id, origin_device_id, version
        )
        VALUES (
            v_agg_id, v_user_id,
            COALESCE(v_cmd->>'kind', 'expense'),
            (v_cmd->>'amount_rp')::BIGINT,
            COALESCE(v_cmd->>'local_date', CURRENT_DATE::TEXT),
            COALESCE((v_cmd->>'occurred_at')::BIGINT, (extract(epoch from now())*1000)::BIGINT),
            v_cmd->>'merchant',
            v_cmd->>'note',
            (extract(epoch from now())*1000)::BIGINT,
            (extract(epoch from now())*1000)::BIGINT,
            v_op_id::TEXT,
            COALESCE(p_payload->>'device_id', 'unknown'),
            1
        )
        ON CONFLICT (id) DO UPDATE SET
            amount_rp = EXCLUDED.amount_rp,
            merchant = EXCLUDED.merchant,
            note = EXCLUDED.note,
            version = transactions.version + 1,
            updated_at = (extract(epoch from now())*1000)::BIGINT
        RETURNING version INTO v_new_version;

    ELSIF v_agg_type = 'inventory_item' THEN
        INSERT INTO public.inventory_items (
            id, user_id, name, base_unit, minimum_qty_milli, stock_category,
            created_at, updated_at, last_operation_id, origin_device_id, version
        )
        VALUES (
            v_agg_id, v_user_id,
            v_cmd->>'name',
            COALESCE(v_cmd->>'base_unit', 'pcs'),
            COALESCE((v_cmd->>'minimum_qty_milli')::INT, 0),
            v_cmd->>'stock_category',
            (extract(epoch from now())*1000)::BIGINT,
            (extract(epoch from now())*1000)::BIGINT,
            v_op_id::TEXT,
            COALESCE(p_payload->>'device_id', 'unknown'),
            1
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            version = inventory_items.version + 1,
            updated_at = (extract(epoch from now())*1000)::BIGINT
        RETURNING version INTO v_new_version;

    ELSIF v_agg_type = 'inventory_movement' THEN
        INSERT INTO public.inventory_movements (
            id, user_id, inventory_item_id, movement_type, quantity_delta_milli, occurred_at, reason,
            created_at, updated_at, last_operation_id, origin_device_id, version
        )
        VALUES (
            v_agg_id, v_user_id,
            v_cmd->>'inventory_item_id',
            COALESCE(v_cmd->>'movement_type', 'add'),
            (v_cmd->>'quantity_delta_milli')::INT,
            COALESCE((v_cmd->>'occurred_at')::BIGINT, (extract(epoch from now())*1000)::BIGINT),
            v_cmd->>'reason',
            (extract(epoch from now())*1000)::BIGINT,
            (extract(epoch from now())*1000)::BIGINT,
            v_op_id::TEXT,
            COALESCE(p_payload->>'device_id', 'unknown'),
            1
        );
    END IF;

    -- 4. Catat ke Change Feed untuk Perangkat Lain (MacBook Air / S24+)
    INSERT INTO private.sync_changes (
        user_id, change_seq, entity_type, entity_id, row_version, is_tombstone, operation_id, row_snapshot
    )
    VALUES (
        v_user_id, v_new_seq, v_agg_type, v_agg_id, v_new_version, FALSE, v_op_id, v_cmd
    );

    -- 5. Susun Respons Acknowledgement & Simpan di sync_operations
    DECLARE
        v_resp JSONB := jsonb_build_object(
            'operation_id', v_op_id,
            'status', 'acknowledged',
            'server_version', v_new_version,
            'change_seq', v_new_seq
        );
    BEGIN
        INSERT INTO private.sync_operations (
            user_id, operation_id, aggregate_type, aggregate_id, request_hash, response_json
        )
        VALUES (
            v_user_id, v_op_id, v_agg_type, v_agg_id, v_request_hash, v_resp
        );

        RETURN v_resp;
    END;
END;
$$;

-- C. Pengambilan Feed Perubahan (RPC `pull_changes`)
CREATE OR REPLACE FUNCTION public.pull_changes(
    p_after_seq BIGINT,
    p_limit INT DEFAULT 200
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_rows JSONB;
    v_max_seq BIGINT := p_after_seq;
    v_has_more BOOLEAN := FALSE;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna tidak terautentikasi';
    END IF;

    SELECT jsonb_agg(to_jsonb(t)), MAX(t.change_seq), COUNT(*) >= p_limit
    INTO v_rows, v_max_seq, v_has_more
    FROM (
        SELECT change_seq, entity_type, entity_id, row_version, is_tombstone, operation_id, row_snapshot
        FROM private.sync_changes
        WHERE user_id = v_user_id
          AND change_seq > p_after_seq
        ORDER BY change_seq ASC
        LIMIT p_limit
    ) t;

    RETURN jsonb_build_object(
        'changes', COALESCE(v_rows, '[]'::jsonb),
        'next_seq', COALESCE(v_max_seq, p_after_seq),
        'has_more', COALESCE(v_has_more, FALSE)
    );
END;
$$;

-- D. Pencabutan Perangkat (RPC `revoke_device`)
CREATE OR REPLACE FUNCTION public.revoke_device(
    p_device_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    UPDATE public.devices
    SET status = 'revoked', revoked_at = NOW()
    WHERE id = p_device_id AND user_id = auth.uid();

    UPDATE private.device_sessions
    SET revoked_at = NOW()
    WHERE device_id = p_device_id AND user_id = auth.uid();
END;
$$;

-- ==============================================================================
-- 6. SETUP STORAGE BUCKETS (personal-media & document-vault)
-- ==============================================================================

-- Buat bucket privat di storage.buckets jika belum ada
INSERT INTO storage.buckets (id, name, public)
VALUES ('personal-media', 'personal-media', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('document-vault', 'document-vault', false)
ON CONFLICT (id) DO NOTHING;

-- RLS Storage Objects: Hanya izinkan pemilik mengakses berkas miliknya
DROP POLICY IF EXISTS storage_owner_policy ON storage.objects;
CREATE POLICY storage_owner_policy ON storage.objects
    FOR ALL TO authenticated
    USING (
        bucket_id IN ('personal-media', 'document-vault') AND
        (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id IN ('personal-media', 'document-vault') AND
        (storage.foldername(name))[1] = auth.uid()::text
    );
