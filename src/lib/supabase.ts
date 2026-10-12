import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Database } from './supabase.types'

const url = import.meta.env.VITE_SUPABASE_URL?.trim()
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim()
export const allowedEmail = import.meta.env.VITE_ALLOWED_EMAIL?.trim().toLowerCase()

export const isSupabaseConfigured = Boolean(url && anonKey && allowedEmail)

export const supabase: SupabaseClient<Database> | null = isSupabaseConfigured
  ? createClient<Database>(url as string, anonKey as string, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null

export function requireSupabase(): SupabaseClient<Database> {
  if (!supabase) {
    throw new Error(
      'Supabase não configurado. Preencha VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY no arquivo .env.local.',
    )
  }

  return supabase
}

export function isAllowedEmail(email: string | null | undefined) {
  return Boolean(allowedEmail && email && email.trim().toLowerCase() === allowedEmail)
}
