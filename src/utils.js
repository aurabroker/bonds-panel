/**
 * Ekranuje HTML — zapobiega XSS przy wstawianiu danych do innerHTML.
 * @param {string|null|undefined} s
 * @returns {string}
 */
export const escapeHTML = s => {
  if (!s) return '';
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
};

/**
 * Formatuje liczbę jako polską walutę (2 miejsca po przecinku).
 * @param {number|null|undefined} n
 * @returns {string}
 */
export const fmt = n =>
  n == null
    ? '—'
    : Number(n).toLocaleString('pl-PL', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/**
 * Różnica dni między datami ISO (b - a).
 * @param {string} a - data ISO (YYYY-MM-DD)
 * @param {string} b - data ISO (YYYY-MM-DD)
 * @returns {number}
 */
export const dateDiff = (a, b) => Math.round((new Date(b) - new Date(a)) / (1000 * 60 * 60 * 24));

/**
 * Dzisiejsza data ISO.
 * @returns {string}
 */
export const today = () => new Date().toISOString().slice(0, 10);

/**
 * Status gwarancji na podstawie daty ważności.
 * @param {{ bond_data_do: string }} bond
 * @returns {'expired'|'expiring'|'active'}
 */
export const bondStatus = bond => {
  const d = dateDiff(today(), bond.bond_data_do);
  if (d < 0) return 'expired';
  if (d <= 30) return 'expiring';
  return 'active';
};

/**
 * Składka ubezpieczeniowa na podstawie parametrów.
 * @param {number} suma - suma gwarancji PLN
 * @param {number} stawka - stawka procentowa
 * @param {string} dataOd - data od (ISO)
 * @param {string} dataDo - data do (ISO)
 * @param {number|null} skladkaMin - minimalna składka lub null
 * @returns {number}
 */
export const calcSkladkaValue = (suma, stawka, dataOd, dataDo, skladkaMin = null) => {
  const dni = dateDiff(dataOd, dataDo);
  if (dni <= 0 || suma <= 0 || isNaN(stawka)) return 0;
  let sk = suma * (stawka / 100) * (dni / 365);
  if (skladkaMin != null && sk < skladkaMin) sk = skladkaMin;
  return Math.round(sk * 100) / 100;
};

/**
 * Ogranicza wywołania funkcji do max 1 razu w oknie czasowym (throttle).
 * @param {Function} fn
 * @param {number} ms
 * @returns {Function}
 */
export const throttle = (fn, ms) => {
  let last = 0;
  return (...args) => {
    const now = Date.now();
    if (now - last < ms) return false;
    last = now;
    return fn(...args);
  };
};
