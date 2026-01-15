// =====================================================================
// Nova - Share Redirect Edge Function
// =====================================================================
// Purpose: Generate landing pages with Open Graph meta tags for rich
//          link previews in WhatsApp, Telegram, and other messaging apps
// Routes:
//   - /share-redirect/events/{event_id}
//   - /share-redirect/profiles/{user_id}
// =====================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =====================================================================
// Type Definitions
// =====================================================================

interface EventData {
  id: string
  title: string
  description: string | null
  image_url: string | null
  event_date: string
  location: string | null
}

interface ProfileData {
  user_id: string
  full_name: string | null
  username: string
  avatar_url: string | null
  bio: string | null
}

// =====================================================================
// Utility Functions
// =====================================================================

/**
 * Escape HTML special characters to prevent XSS
 */
function escapeHtml(text: string): string {
  const escapeMap: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }
  return text.replace(/[&<>"']/g, char => escapeMap[char] || char)
}

/**
 * Format date in Italian locale
 */
function formatDateIT(dateString: string): string {
  try {
    const date = new Date(dateString)
    return date.toLocaleDateString('it-IT', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric'
    })
  } catch {
    return dateString
  }
}

/**
 * Generate HTML page with Open Graph meta tags
 *
 * Strategy:
 * - WhatsApp/Telegram bots read the OG meta tags for preview (they don't execute JS)
 * - When a real user clicks, shows a beautiful landing page
 * - User can tap "Apri nell'app" to try the deep link
 * - Or download from App Store / Play Store if app not installed
 */
function generateHtmlPage(
  title: string,
  description: string,
  imageUrl: string | null,
  appDeepLink: string,
  type: 'events' | 'profiles'
): string {
  const safeTitle = escapeHtml(title)
  const safeDescription = escapeHtml(description.substring(0, 200))
  const typeLabel = type === 'events' ? 'evento' : 'profilo'

  const html = [
    '<!DOCTYPE html>',
    '<html lang="it">',
    '<head>',
    '<meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    '<meta property="og:type" content="website">',
    '<meta property="og:title" content="' + safeTitle + '">',
    '<meta property="og:description" content="' + safeDescription + '">',
    imageUrl ? '<meta property="og:image" content="' + imageUrl + '">' : '',
    '<meta property="og:site_name" content="Nova">',
    '<meta property="og:locale" content="it_IT">',
    '<meta name="twitter:card" content="' + (imageUrl ? 'summary_large_image' : 'summary') + '">',
    '<meta name="twitter:title" content="' + safeTitle + '">',
    '<meta name="twitter:description" content="' + safeDescription + '">',
    imageUrl ? '<meta name="twitter:image" content="' + imageUrl + '">' : '',
    '<title>' + safeTitle + ' - Nova</title>',
    '<style>',
    '*{margin:0;padding:0;box-sizing:border-box}',
    'body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}',
    '.card{background:#fff;border-radius:24px;padding:32px;max-width:380px;width:100%;text-align:center;box-shadow:0 20px 60px rgba(0,0,0,0.3)}',
    '.logo{width:80px;height:80px;background:linear-gradient(135deg,#667eea,#764ba2);border-radius:20px;margin:0 auto 20px;display:flex;align-items:center;justify-content:center;font-size:36px;color:#fff}',
    'h1{font-size:22px;color:#1a1a2e;margin-bottom:8px}',
    '.subtitle{color:#666;font-size:14px;margin-bottom:24px}',
    '.event-info{background:#f8f9fa;border-radius:16px;padding:16px;margin-bottom:24px;text-align:left}',
    '.event-title{font-size:18px;font-weight:600;color:#1a1a2e;margin-bottom:8px}',
    '.event-desc{font-size:14px;color:#666;line-height:1.5}',
    '.btn{display:block;padding:16px 24px;border-radius:14px;text-decoration:none;font-weight:600;font-size:16px;margin-bottom:12px;text-align:center}',
    '.btn-primary{background:linear-gradient(135deg,#667eea,#764ba2);color:#fff}',
    '.btn-secondary{background:#f0f0f0;color:#333}',
    '.store-buttons{display:flex;gap:12px;margin-top:8px}',
    '.store-btn{flex:1;padding:12px;border-radius:12px;background:#000;color:#fff;text-decoration:none;font-size:12px;display:flex;align-items:center;justify-content:center;gap:8px}',
    '.store-btn img{height:20px}',
    '.divider{color:#999;font-size:12px;margin:16px 0}',
    '</style>',
    '</head>',
    '<body>',
    '<div class="card">',
    '<div class="logo">N</div>',
    '<h1>Apri in Nova</h1>',
    '<p class="subtitle">Questo ' + typeLabel + ' è disponibile nell\'app Nova</p>',
    '<div class="event-info">',
    '<div class="event-title">' + safeTitle + '</div>',
    '<div class="event-desc">' + safeDescription + '</div>',
    '</div>',
    '<a class="btn btn-primary" href="' + appDeepLink + '" id="openApp">Apri nell\'app</a>',
    '<p class="divider">Non hai l\'app? Scaricala gratis</p>',
    '<div class="store-buttons">',
    '<a class="store-btn" href="https://apps.apple.com/app/nova/id000000000" id="ios-btn">',
    '<span>App Store</span>',
    '</a>',
    '<a class="store-btn" href="https://play.google.com/store/apps/details?id=com.galileimoro.nova" id="android-btn">',
    '<span>Play Store</span>',
    '</a>',
    '</div>',
    '</div>',
    '</body>',
    '</html>'
  ].filter(Boolean).join('')

  return html
}

// =====================================================================
// Main Handler
// =====================================================================

Deno.serve(async (req) => {
  try {
    // ---------------------------------------------------------------
    // 1. Parse URL and extract type/id
    // ---------------------------------------------------------------
    const url = new URL(req.url)
    const pathParts = url.pathname.split('/').filter(Boolean)

    // Expected paths:
    // /share-redirect/events/{id}
    // /share-redirect/profiles/{id}
    // OR direct paths when using custom domain:
    // /events/{id}
    // /profiles/{id}

    let type: 'events' | 'profiles' | null = null
    let id: string | null = null

    // Find the type and id in the path
    for (let i = 0; i < pathParts.length; i++) {
      if (pathParts[i] === 'events' || pathParts[i] === 'profiles') {
        type = pathParts[i] as 'events' | 'profiles'
        id = pathParts[i + 1] || null
        break
      }
    }

    if (!type || !id) {
      console.log('Invalid path:', url.pathname)
      return new Response('Not found', {
        status: 404,
        headers: { 'Content-Type': 'text/plain' }
      })
    }

    console.log(`📥 Share redirect request: ${type}/${id}`)

    // ---------------------------------------------------------------
    // 2. Initialize Supabase Client
    // ---------------------------------------------------------------
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Missing Supabase environment variables')
      throw new Error('Server configuration error')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    // ---------------------------------------------------------------
    // 3. Fetch Data Based on Type
    // ---------------------------------------------------------------
    let title = 'Nova'
    let description = 'Scopri questo contenuto su Nova'
    let imageUrl: string | null = null
    const appDeepLink = `nova://${type}/${id}`

    if (type === 'events') {
      const { data, error } = await supabase
        .from('events')
        .select('id, title, description, image_url, event_date, location')
        .eq('id', id)
        .single()

      if (error) {
        console.error('Error fetching event:', error)
      }

      if (data) {
        const event = data as EventData
        title = event.title
        description = event.description || ''
        imageUrl = event.image_url

        // Build rich description with date and location
        const parts: string[] = []
        if (event.event_date) {
          parts.push(formatDateIT(event.event_date))
        }
        if (event.location) {
          parts.push(event.location)
        }
        if (parts.length > 0) {
          description = parts.join(' • ') + (event.description ? `\n\n${event.description}` : '')
        }

        console.log(`✅ Found event: ${event.title}`)
      } else {
        console.log(`⚠️ Event not found: ${id}`)
        title = 'Evento non trovato'
        description = 'Questo evento potrebbe essere stato rimosso o non esiste.'
      }
    }
    else if (type === 'profiles') {
      const { data, error } = await supabase
        .from('profiles')
        .select('user_id, full_name, username, avatar_url, bio')
        .eq('user_id', id)
        .single()

      if (error) {
        console.error('Error fetching profile:', error)
      }

      if (data) {
        const profile = data as ProfileData
        title = profile.full_name || profile.username
        description = profile.bio || `Profilo di ${profile.full_name || profile.username} su Nova`
        imageUrl = profile.avatar_url

        console.log(`✅ Found profile: ${title}`)
      } else {
        console.log(`⚠️ Profile not found: ${id}`)
        title = 'Profilo non trovato'
        description = 'Questo profilo potrebbe essere stato rimosso o non esiste.'
      }
    }

    // ---------------------------------------------------------------
    // 4. Return HTML with OG tags + redirect
    // ---------------------------------------------------------------
    // Strategy:
    // - Return HTML with OG meta tags (bots read these even as text/plain)
    // - Include meta refresh to redirect browsers to landing page
    // - Bots don't execute JS/redirects, so they see the OG tags
    // - Browsers follow the redirect to the proper landing page

    const safeTitle = escapeHtml(title)
    const safeDescription = escapeHtml(description.substring(0, 200))

    // Build query params for landing page
    const params = new URLSearchParams({
      title: title,
      desc: description.substring(0, 200),
      type: type,
      deeplink: appDeepLink,
    })

    // Landing page URL in Supabase Storage
    const landingUrl = `${supabaseUrl}/storage/v1/object/public/static/landing.html?${params.toString()}`

    // HTML with OG tags and redirect
    const html = `<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="0;url=${landingUrl}">
<meta property="og:type" content="website">
<meta property="og:title" content="${safeTitle}">
<meta property="og:description" content="${safeDescription}">
${imageUrl ? `<meta property="og:image" content="${imageUrl}">` : ''}
<meta property="og:site_name" content="Nova">
<meta property="og:locale" content="it_IT">
<meta name="twitter:card" content="${imageUrl ? 'summary_large_image' : 'summary'}">
<meta name="twitter:title" content="${safeTitle}">
<meta name="twitter:description" content="${safeDescription}">
${imageUrl ? `<meta name="twitter:image" content="${imageUrl}">` : ''}
<title>${safeTitle} - Nova</title>
</head>
<body>
<p>Reindirizzamento in corso...</p>
<script>window.location.href="${landingUrl}";</script>
</body>
</html>`

    console.log(`✅ Serving OG tags for: ${title}`)

    return new Response(html, {
      status: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=300',
      }
    })

  } catch (error) {
    console.error('❌ Edge Function error:', error)

    // Return a simple error page
    const errorHtml = `<!DOCTYPE html>
<html><head><title>Errore - Nova</title></head>
<body style="font-family:system-ui;text-align:center;padding:50px">
  <h1>Oops!</h1>
  <p>Si e verificato un errore. Riprova più tardi.</p>
  <a href="nova://">Apri Nova</a>
</body></html>`

    return new Response(errorHtml, {
      status: 500,
      headers: { 'Content-Type': 'text/html; charset=utf-8' }
    })
  }
})

// =====================================================================
// Deployment Instructions:
// 1. Deploy: npx supabase functions deploy share-redirect
// 2. Test: https://YOUR_PROJECT.supabase.co/functions/v1/share-redirect/events/EVENT_ID
// 3. With custom domain (Supabase Pro): https://nova.galileimoro.edu.it/events/EVENT_ID
// =====================================================================
