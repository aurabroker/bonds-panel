import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { dateDiff, bondStatus, calcSkladkaValue, fmt, throttle } from '../../src/utils.js';

// escapeHTML wymaga DOM — testujemy w jsdom
import { escapeHTML } from '../../src/utils.js';

// ── dateDiff ──────────────────────────────────────────────────────────────
describe('dateDiff', () => {
  it('zwraca 0 dla tej samej daty', () => {
    expect(dateDiff('2025-01-01', '2025-01-01')).toBe(0);
  });

  it('zwraca 1 dla dnia następnego', () => {
    expect(dateDiff('2025-01-01', '2025-01-02')).toBe(1);
  });

  it('zwraca ujemną wartość gdy b < a', () => {
    expect(dateDiff('2025-01-10', '2025-01-05')).toBe(-5);
  });

  it('liczy lata przestępne poprawnie', () => {
    // 2024 to rok przestępny → 366 dni
    expect(dateDiff('2024-01-01', '2025-01-01')).toBe(366);
  });
});

// ── bondStatus ────────────────────────────────────────────────────────────
describe('bondStatus', () => {
  let now;
  beforeEach(() => { now = new Date('2025-06-01'); vi.setSystemTime(now); });
  afterEach(() => { vi.useRealTimers(); });

  it('expired — gdy data_do < dziś', () => {
    expect(bondStatus({ bond_data_do: '2025-05-31' })).toBe('expired');
  });

  it('expiring — gdy data_do ≤ 30 dni', () => {
    expect(bondStatus({ bond_data_do: '2025-06-30' })).toBe('expiring');
  });

  it('expiring — dokładnie na granicy 30 dni', () => {
    expect(bondStatus({ bond_data_do: '2025-07-01' })).toBe('expiring');
  });

  it('active — gdy data_do > 30 dni', () => {
    expect(bondStatus({ bond_data_do: '2025-08-01' })).toBe('active');
  });
});

// ── calcSkladkaValue ──────────────────────────────────────────────────────
describe('calcSkladkaValue', () => {
  it('liczy składkę proporcjonalnie do okresu', () => {
    // 100 000 PLN × 1% × (365/365) = 1000 PLN
    expect(calcSkladkaValue(100_000, 1, '2025-01-01', '2026-01-01')).toBeCloseTo(1000, 1);
  });

  it('stosuje minimalną składkę', () => {
    // wynik byłby 10 PLN, ale min to 100 PLN
    expect(calcSkladkaValue(1_000, 1, '2025-01-01', '2025-04-11', 100)).toBe(100);
  });

  it('zwraca 0 gdy dni <= 0', () => {
    expect(calcSkladkaValue(100_000, 1, '2025-01-10', '2025-01-05')).toBe(0);
  });

  it('zwraca 0 gdy suma = 0', () => {
    expect(calcSkladkaValue(0, 1, '2025-01-01', '2026-01-01')).toBe(0);
  });

  it('zwraca 0 gdy stawka NaN', () => {
    expect(calcSkladkaValue(100_000, NaN, '2025-01-01', '2026-01-01')).toBe(0);
  });
});

// ── fmt ───────────────────────────────────────────────────────────────────
describe('fmt', () => {
  it('formatuje 0', () => {
    expect(fmt(0)).toBe('0,00');
  });

  it('formatuje null jako —', () => {
    expect(fmt(null)).toBe('—');
  });

  it('formatuje undefined jako —', () => {
    expect(fmt(undefined)).toBe('—');
  });

  it('formatuje liczbę z separatorem tysięcy', () => {
    expect(fmt(1_000_000)).toContain('1');
    expect(fmt(1_000_000)).toContain('00');
  });

  it('zaokrągla do 2 miejsc po przecinku', () => {
    expect(fmt(1.005)).toMatch(/1,0[01]/);
  });
});

// ── escapeHTML ────────────────────────────────────────────────────────────
describe('escapeHTML', () => {
  it('enkoduje < i >', () => {
    expect(escapeHTML('<script>')).toBe('&lt;script&gt;');
  });

  it('enkoduje cudzysłów', () => {
    expect(escapeHTML('"test"')).toContain('&quot;');
  });

  it('enkoduje ampersand', () => {
    expect(escapeHTML('a&b')).toBe('a&amp;b');
  });

  it('zwraca pusty string dla null', () => {
    expect(escapeHTML(null)).toBe('');
  });

  it('zwraca pusty string dla undefined', () => {
    expect(escapeHTML(undefined)).toBe('');
  });

  it('przepuszcza bezpieczny tekst bez zmian', () => {
    expect(escapeHTML('Cześć świecie')).toBe('Cześć świecie');
  });
});

// ── throttle ─────────────────────────────────────────────────────────────
describe('throttle', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('wywołuje funkcję przy pierwszym wywołaniu', () => {
    const fn = vi.fn(() => 'ok');
    const t = throttle(fn, 1000);
    expect(t()).toBe('ok');
    expect(fn).toHaveBeenCalledOnce();
  });

  it('blokuje kolejne wywołanie w oknie czasowym', () => {
    const fn = vi.fn(() => 'ok');
    const t = throttle(fn, 1000);
    t();
    expect(t()).toBe(false);
    expect(fn).toHaveBeenCalledOnce();
  });

  it('przepuszcza wywołanie po upływie okna', () => {
    const fn = vi.fn(() => 'ok');
    const t = throttle(fn, 1000);
    t();
    vi.advanceTimersByTime(1001);
    expect(t()).toBe('ok');
    expect(fn).toHaveBeenCalledTimes(2);
  });
});
