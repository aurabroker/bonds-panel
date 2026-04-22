// Supabase Edge Function: rate-limit
// Wdróż: supabase functions deploy rate-limit
//
// Zastosowanie: Owijaj operacje zapisu przez ten endpoint zamiast
// bezpośrednio przez supabase-js, aby egzekwować rate limiting po
// stronie serwera niezależnie od klienta.
//
// Przykład konfiguracji w Supabase Dashboard:
//   Authentication → Policies → lub Realtime → Rate limits
//   Rekomendowane limity Supabase: 100 req/s per IP (domyślnie)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.4';

const RATE_LIMIT_MS = 1000;   // min. czas między operacjami zapisu
const MAX_WRITES_PER_MIN = 30;

// In-memory store (Edge Functions są stateless — w produkcji użyj Redis/KV)
const writeLog = new Map<string, number[]>();

function isRateLimited(userId: string): boolean {
  const now = Date.now();
  const timestamps = (writeLog.get(userId) || []).filter(t => now - t < 60_000);
  if(timestamps.length >= MAX_WRITES_PER_MIN) return true;
  timestamps.push(now);
  writeLog.set(userId, timestamps);
  return false;
}

serve(async (req: Request) => {
  if(req.method === 'OPTIONS') {
    return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type' } });
  }

  const authHeader = req.headers.get('Authorization');
  if(!authHeader) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });

  const sb = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user } } = await sb.auth.getUser();
  if(!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });

  if(isRateLimited(user.id)) {
    return new Response(JSON.stringify({ error: 'Rate limit exceeded. Spróbuj za chwilę.' }), {
      status: 429,
      headers: { 'Retry-After': '60' }
    });
  }

  // Przekaż żądanie do właściwego handlera
  const body = await req.json();
  const { table, operation, payload, id } = body;

  const ALLOWED_TABLES = ['bond_bonds', 'bond_tenants', 'bond_insurers', 'bond_analytics'];
  if(!ALLOWED_TABLES.includes(table)) {
    return new Response(JSON.stringify({ error: 'Niedozwolona tabela.' }), { status: 400 });
  }

  let result;
  if(operation === 'insert') result = await sb.from(table).insert(payload).select();
  else if(operation === 'update' && id) result = await sb.from(table).update(payload).eq('bond_id', id).select();
  else if(operation === 'delete' && id) result = await sb.from(table).delete().eq('bond_id', id);
  else return new Response(JSON.stringify({ error: 'Nieprawidłowa operacja.' }), { status: 400 });

  return new Response(JSON.stringify(result), {
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
  });
});
