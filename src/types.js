/**
 * @fileoverview JSDoc typy dla bonds-panel.
 * Importuj w plikach JS za pomocą: @param {import('./types.js').Bond} bond
 */

/**
 * @typedef {Object} Bond
 * @property {string}  bond_id
 * @property {string}  bond_nr
 * @property {string}  bond_rodzaj        - 'wadialna'|'nalezyte_wykonanie'|'usunięcie_wad'|'zwrot_zaliczki'|'mieszana'
 * @property {string}  bond_kontrakt
 * @property {string|null} bond_beneficjent
 * @property {string|null} bond_inwestor
 * @property {string|null} bond_insurer_id
 * @property {string|null} bond_tenant_id
 * @property {string|null} bond_data_od   - ISO date YYYY-MM-DD
 * @property {string}  bond_data_do       - ISO date YYYY-MM-DD
 * @property {number|null} bond_suma
 * @property {number|null} bond_skladka
 * @property {boolean} bond_bez_limitu
 * @property {number|null} bond_stawka
 * @property {boolean} bond_stawka_override
 * @property {string}  created_at
 * @property {Insurer|null} [bond_insurers]  - join
 * @property {Tenant|null}  [bond_tenants]   - join
 */

/**
 * @typedef {Object} Tenant
 * @property {string}      bond_id
 * @property {string}      bond_nazwa
 * @property {string}      bond_slug
 * @property {string|null} bond_nip
 * @property {string|null} bond_regon
 * @property {string|null} bond_krs
 */

/**
 * @typedef {Object} Insurer
 * @property {string}      bond_id
 * @property {string|null} bond_tenant_id
 * @property {string}      bond_nazwa
 * @property {string|null} bond_ul_nr
 * @property {number|null} bond_limit
 * @property {string|null} bond_ul_data_od
 * @property {string|null} bond_ul_data_do
 * @property {number|null} bond_stawka_bazowa
 * @property {number|null} bond_skladka_min
 * @property {Tenant|null} [bond_tenants]  - join
 */

/**
 * @typedef {Object} Profile
 * @property {string}      bond_id          - UUID (FK auth.users)
 * @property {string|null} bond_email
 * @property {string|null} bond_tenant_id
 * @property {boolean}     bond_is_admin
 * @property {'admin'|'klient'} bond_rola
 * @property {Tenant|null} [bond_tenants]   - join
 */

/**
 * @typedef {Object} TuDict
 * @property {string}  id
 * @property {string}  name
 * @property {boolean} is_active
 */

/**
 * @typedef {Object} Analytics
 * @property {string}      bond_id
 * @property {string|null} bond_tenant_id
 * @property {string}      score_grade
 * @property {string}      score_desc
 * @property {Object|null} financial_data
 * @property {string}      created_at
 */

/**
 * @typedef {'expired'|'expiring'|'active'} BondStatusType
 */

/**
 * @typedef {'info'|'success'|'warn'|'error'} ToastType
 */
