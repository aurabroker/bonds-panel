-- ==========================================================================
-- bonds-panel: Row Level Security (RLS)
-- Wklej i uruchom w: Supabase Dashboard → SQL Editor
-- ==========================================================================
-- Założenia:
--   • bond_rola = 'admin'  → widzi i modyfikuje wszystko
--   • bond_rola = 'klient' → widzi/modyfikuje tylko dane swojego tenanta
--   • Klienci NIE mogą usuwać żadnych rekordów (DELETE = admin only)
-- ==========================================================================

BEGIN;

-- ──────────────────────────────────────────────────────────────────────────
-- 1. FUNKCJE POMOCNICZE (SECURITY DEFINER omija RLS przy czytaniu profilu,
--    co zapobiega nieskończonej rekurencji)
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.bp_get_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT bond_rola FROM bond_profiles WHERE bond_id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.bp_get_tenant()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT bond_tenant_id FROM bond_profiles WHERE bond_id = auth.uid()
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- 2. WŁĄCZ RLS NA WSZYSTKICH TABELACH
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE bond_profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE bond_tenants   ENABLE ROW LEVEL SECURITY;
ALTER TABLE bond_bonds     ENABLE ROW LEVEL SECURITY;
ALTER TABLE bond_insurers  ENABLE ROW LEVEL SECURITY;
ALTER TABLE bond_tu_dict   ENABLE ROW LEVEL SECURITY;
ALTER TABLE bond_analytics ENABLE ROW LEVEL SECURITY;

-- ──────────────────────────────────────────────────────────────────────────
-- 3. USUŃ STARE POLITYKI (idempotentność — bezpieczne wielokrotne uruchomienie)
-- ──────────────────────────────────────────────────────────────────────────

DO $$ DECLARE pol RECORD;
BEGIN
  FOR pol IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public'
               AND tablename IN ('bond_profiles','bond_tenants','bond_bonds',
                                 'bond_insurers','bond_tu_dict','bond_analytics')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol.policyname, pol.tablename);
  END LOOP;
END $$;

-- ==========================================================================
-- bond_profiles
-- SELECT: każdy widzi tylko swój profil; admin widzi wszystkie
-- INSERT/UPDATE: tylko admin (przypisywanie ról i tenantów)
-- DELETE: tylko admin
-- ==========================================================================

CREATE POLICY "profiles_select" ON bond_profiles
  FOR SELECT TO authenticated
  USING (bond_id = auth.uid() OR bp_get_role() = 'admin');

CREATE POLICY "profiles_insert" ON bond_profiles
  FOR INSERT TO authenticated
  WITH CHECK (bp_get_role() = 'admin');

CREATE POLICY "profiles_update" ON bond_profiles
  FOR UPDATE TO authenticated
  USING  (bp_get_role() = 'admin')
  WITH CHECK (bp_get_role() = 'admin');

CREATE POLICY "profiles_delete" ON bond_profiles
  FOR DELETE TO authenticated
  USING (bp_get_role() = 'admin');

-- ==========================================================================
-- bond_tenants
-- SELECT: klient widzi tylko swój rekord (potrzebne też do joinów z bond_bonds
--         i bond_insurers — Supabase stosuje RLS na każdej tabeli oddzielnie)
-- INSERT/UPDATE/DELETE: tylko admin
-- ==========================================================================

CREATE POLICY "tenants_select" ON bond_tenants
  FOR SELECT TO authenticated
  USING (bond_id = bp_get_tenant() OR bp_get_role() = 'admin');

CREATE POLICY "tenants_insert" ON bond_tenants
  FOR INSERT TO authenticated
  WITH CHECK (bp_get_role() = 'admin');

CREATE POLICY "tenants_update" ON bond_tenants
  FOR UPDATE TO authenticated
  USING  (bp_get_role() = 'admin')
  WITH CHECK (bp_get_role() = 'admin');

CREATE POLICY "tenants_delete" ON bond_tenants
  FOR DELETE TO authenticated
  USING (bp_get_role() = 'admin');

-- ==========================================================================
-- bond_bonds
-- SELECT: klient widzi tylko gwarancje swojego tenanta
-- INSERT: klient może dodawać tylko do swojego tenanta
-- UPDATE: klient może edytować tylko swoje gwarancje (nie może zmienić tenant_id)
-- DELETE: tylko admin (blokada też w JS)
-- ==========================================================================

CREATE POLICY "bonds_select" ON bond_bonds
  FOR SELECT TO authenticated
  USING (bond_tenant_id = bp_get_tenant() OR bp_get_role() = 'admin');

CREATE POLICY "bonds_insert" ON bond_bonds
  FOR INSERT TO authenticated
  WITH CHECK (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant());

CREATE POLICY "bonds_update" ON bond_bonds
  FOR UPDATE TO authenticated
  USING  (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant())
  WITH CHECK (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant());

CREATE POLICY "bonds_delete" ON bond_bonds
  FOR DELETE TO authenticated
  USING (bp_get_role() = 'admin');

-- ==========================================================================
-- bond_insurers
-- Takie same zasady jak bond_bonds
-- ==========================================================================

CREATE POLICY "insurers_select" ON bond_insurers
  FOR SELECT TO authenticated
  USING (bond_tenant_id = bp_get_tenant() OR bp_get_role() = 'admin');

CREATE POLICY "insurers_insert" ON bond_insurers
  FOR INSERT TO authenticated
  WITH CHECK (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant());

CREATE POLICY "insurers_update" ON bond_insurers
  FOR UPDATE TO authenticated
  USING  (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant())
  WITH CHECK (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant());

CREATE POLICY "insurers_delete" ON bond_insurers
  FOR DELETE TO authenticated
  USING (bp_get_role() = 'admin');

-- ==========================================================================
-- bond_tu_dict  (słownik TU — tylko odczyt dla klientów)
-- SELECT: wszyscy zalogowani
-- INSERT/UPDATE/DELETE: tylko admin
-- ==========================================================================

CREATE POLICY "tu_dict_select" ON bond_tu_dict
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "tu_dict_insert" ON bond_tu_dict
  FOR INSERT TO authenticated
  WITH CHECK (bp_get_role() = 'admin');

CREATE POLICY "tu_dict_update" ON bond_tu_dict
  FOR UPDATE TO authenticated
  USING  (bp_get_role() = 'admin')
  WITH CHECK (bp_get_role() = 'admin');

CREATE POLICY "tu_dict_delete" ON bond_tu_dict
  FOR DELETE TO authenticated
  USING (bp_get_role() = 'admin');

-- ==========================================================================
-- bond_analytics
-- SELECT: klient widzi tylko analizy swojego tenanta
-- INSERT: klient może zapisywać tylko dla swojego tenanta
-- UPDATE: j.w.
-- DELETE: tylko admin
-- ==========================================================================

CREATE POLICY "analytics_select" ON bond_analytics
  FOR SELECT TO authenticated
  USING (bond_tenant_id = bp_get_tenant() OR bp_get_role() = 'admin');

CREATE POLICY "analytics_insert" ON bond_analytics
  FOR INSERT TO authenticated
  WITH CHECK (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant());

CREATE POLICY "analytics_update" ON bond_analytics
  FOR UPDATE TO authenticated
  USING  (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant())
  WITH CHECK (bp_get_role() = 'admin' OR bond_tenant_id = bp_get_tenant());

CREATE POLICY "analytics_delete" ON bond_analytics
  FOR DELETE TO authenticated
  USING (bp_get_role() = 'admin');

COMMIT;

-- ==========================================================================
-- WERYFIKACJA — uruchom po COMMIT, aby sprawdzić poprawność
-- ==========================================================================
/*
SELECT
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('bond_profiles','bond_tenants','bond_bonds',
                    'bond_insurers','bond_tu_dict','bond_analytics')
ORDER BY tablename, cmd, policyname;
*/

-- ==========================================================================
-- TEST MANUALNY (uruchom jako zalogowany klient, nie admin):
--
-- 1. Dane cudzego tenanta powinny zwrócić pustą tablicę:
--    SELECT * FROM bond_bonds WHERE bond_tenant_id != bp_get_tenant();
--    → oczekiwany wynik: 0 wierszy
--
-- 2. Próba usunięcia gwarancji przez klienta powinna się nie udać:
--    DELETE FROM bond_bonds WHERE bond_id = '<uuid>';
--    → oczekiwany wynik: ERROR 42501 (insufficient_privilege) lub 0 rows affected
--
-- 3. Próba odczytu profilu innego użytkownika:
--    SELECT * FROM bond_profiles WHERE bond_id != auth.uid();
--    → oczekiwany wynik: 0 wierszy
-- ==========================================================================
