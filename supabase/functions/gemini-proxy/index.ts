import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Authorization: Kullanıcı Supabase'e login olmuş olmalı
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Yetkisiz İstek - Bearer token eksik')
    }

    // 2. Gizli API anahtarını al (Flutter app'ine gömmek yerine burada Edge üzerinde)
    const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
    if (!GEMINI_API_KEY) {
      throw new Error('Sunucu Hatası: GEMINI_API_KEY yapılandırılmamış.')
    }

    const { contents, generationConfig } = await req.json()

    // 3. Gemini tarafına isteği yönlendir ("Proxying")
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`
    
    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents,
        generationConfig
      }),
    })

    const data = await response.json()

    // 4. Android/iOS uygulamasına sadece sonucu dön
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
