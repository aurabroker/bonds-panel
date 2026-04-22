-- ==========================================================================
-- bonds-panel: Audit Log
-- Wklej i uruchom w: Supabase Dashboard → SQL Editor
-- WAŻNE: Uruchom po rls_policies.sql (wymaga funkcji bp_get_role)
-- ==========================================================================

BEGIN;

-- ──────────────────────────────────────────────────────────────────────────
-- 1. TABELA AUDIT LOG
-- ──────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS bond_audit_log (
  id            BIGSERIAL PRIMARY KEY,
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id      UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_role    TEXT,
  operation     TEXT        NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  table_name    TEXT        NOT NULL,
  record_id     UUID,
  old_data      JSONB,
  new_data      JSONB
);

-- Indeks na czas (do stronicowania historii)
CREATE INDEX IF NOT EXISTS idx_audit_log_time ON bond_audit_log (occurred_at DESC);
-- Indeks na rekord (do historii konkretnej gwarancji/klienta)
CREATE INDEX IF NOT EXISTS idx_audit_log_record ON bond_audit_log (table_name, record_id);
-- Indeks na aktora (do audytu per użytkownik)
CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON bond_audit_log (actor_id);

-- RLS: tylko admin może czytać logi; nikt nie może ich modyfikować przez API
ALTER TABLE bond_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_log_select" ON bond_audit_log;
CREATE POLICY "audit_log_select" ON bond_audit_log
  FOR SELECT TO authenticated
  USING (bp_get_role() = 'admin');

-- INSERT jest wykonywany przez trigger (SECURITY DEFINER) — brak potrzeby polityki INSERT

-- ──────────────────────────────────────────────────────────────────────────
-- 2. FUNKCJA TRIGGERA
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_record_id UUID;
  v_old       JSONB;
  v_new       JSONB;
BEGIN
  -- Wyciągnij bond_id jako UUID rekordu (wspólny PK we wszystkich tabelach)
  IF TG_OP = 'DELETE' THEN
    v_record_id := (OLD.bond_id)::UUID;
    v_old       := to_jsonb(OLD);
    v_new       := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    v_record_id := (NEW.bond_id)::UUID;
    v_old       := NULL;
    v_new       := to_jsonb(NEW);
  ELSE -- UPDATE
    v_record_id := (NEW.bond_id)::UUID;
    v_old       := to_jsonb(OLD);
    v_new       := to_jsonb(NEW);
  END IF;

  INSERT INTO bond_audit_log (actor_id, actor_role, operation, table_name, record_id, old_data, new_data)
  VALUES (
    auth.uid(),
    (SELECT bond_rola FROM bond_profiles WHERE bond_id = auth.uid()),
    TG_OP,
    TG_TABLE_NAME,
    v_record_id,
    v_old,
    v_new
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- 3. TRIGGERY NA KLUCZOWYCH TABELACH
-- ──────────────────────────────────────────────────────────────────────────

-- bond_bonds
DROP TRIGGER IF EXISTS trg_audit_bond_bonds ON bond_bonds;
CREATE TRIGGER trg_audit_bond_bonds
  AFTER INSERT OR UPDATE OR DELETE ON bond_bonds
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- bond_tenants
DROP TRIGGER IF EXISTS trg_audit_bond_tenants ON bond_tenants;
CREATE TRIGGER trg_audit_bond_tenants
  AFTER INSERT OR UPDATE OR DELETE ON bond_tenants
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- bond_insurers
DROP TRIGGER IF EXISTS trg_audit_bond_insurers ON bond_insurers;
CREATE TRIGGER trg_audit_bond_insurers
  AFTER INSERT OR UPDATE OR DELETE ON bond_insurers
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- bond_profiles (zmiany ról i przypisań tenantów)
DROP TRIGGER IF EXISTS trg_audit_bond_profiles ON bond_profiles;
CREATE TRIGGER trg_audit_bond_profiles
  AFTER INSERT OR UPDATE OR DELETE ON bond_profiles
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

COMMIT;

-- ==========================================================================
-- WERYFIKACJA
-- ==========================================================================
/*
-- Sprawdź strukturę tabeli
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'bond_audit_log' ORDER BY ordinal_position;

-- Sprawdź triggery
SELECT trigger_name, event_object_table, event_manipulation
FROM information_schema.triggers
WHERE trigger_name LIKE 'trg_audit_%'
ORDER BY event_object_table;

-- Przykładowy odczyt logów (jako admin)
SELECT occurred_at, actor_role, operation, table_name, record_id
FROM bond_audit_log
ORDER BY occurred_at DESC
LIMIT 20;
*/
