import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

console.log("Push Dispatcher (Native Fetch) initialized")

// 1. Config
const TEAM_ID = Deno.env.get("APNS_TEAM_ID")!
const KEY_ID = Deno.env.get("APNS_KEY_ID")!
const BUNDLE_ID = "com.suprawee.W-Reminder" // Your App Bundle ID
// P8 KEY CONTENT - Ensure this includes -----BEGIN PRIVATE KEY----- ...
const P8_KEY = Deno.env.get("APNS_P8_KEY")!
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

// 2. Helper to import P8 Key
async function importP8Key(pem: string): Promise<CryptoKey> {
    // 1. Clean the PEM string to get just the base64 body
    const pemHeader = "-----BEGIN PRIVATE KEY-----"
    const pemFooter = "-----END PRIVATE KEY-----"

    let pemContents = pem.trim()
    if (pemContents.startsWith(pemHeader)) {
        pemContents = pemContents.replace(pemHeader, "").replace(pemFooter, "")
    }
    // Remove all whitespace/newlines
    const binaryDerString = atob(pemContents.replace(/\s/g, ""))

    // 2. Convert to ArrayBuffer
    const binaryDer = new Uint8Array(binaryDerString.length)
    for (let i = 0; i < binaryDerString.length; i++) {
        binaryDer[i] = binaryDerString.charCodeAt(i)
    }

    // 3. Import Key
    return await crypto.subtle.importKey(
        "pkcs8",
        binaryDer,
        {
            name: "ECDSA",
            namedCurve: "P-256", // APNs uses ES256 which is P-256 curve
        },
        false,
        ["sign"]
    )
}

// 3. Generate JWT for APNs
async function generateApnsJwt(teamId: string, keyId: string, p8Key: string): Promise<string> {
    const privateKey = await importP8Key(p8Key)

    const jwt = await create(
        { alg: "ES256", kid: keyId },
        { iss: teamId, iat: Math.floor(Date.now() / 1000) },
        privateKey
    )
    return jwt
}

serve(async (req) => {
    try {
        const { record, type, table } = await req.json()

        // validate logic: Only notify on NEW inserts for now
        if (type !== 'INSERT') {
            return new Response("Skipped: Not an INSERT", { status: 200 })
        }

        // Determine Message & User
        let title = "W Reminder"
        let body = "You have a new item."
        let targetUserId = record.user_id

        const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

        if (table === "simple_checklists") {
            title = "New Task"
            body = record.title || "Check your list"
        } else if (table === "milestones") {
            title = "New Milestone"
            body = record.title || "A new milestone set"
        } else if (table === "milestone_items") {
            // Subtask logic: Fetch parent to get User ID
            const milestoneId = record.milestone_id
            const { data: milestone, error: mError } = await supabase
                .from("milestones")
                .select("user_id, title")
                .eq("id", milestoneId)
                .single()

            if (mError || !milestone) {
                return new Response("Parent milestone not found", { status: 200 })
            }

            targetUserId = milestone.user_id
            title = `New Subtask in ${milestone.title}`
            body = record.text || "New action item added"
        }

        if (!targetUserId) {
            return new Response("Skipped: No user_id resolved", { status: 200 })
        }

        // Fetch Tokens
        const { data: tokens, error } = await supabase
            .from("device_tokens")
            .select("token")
            .eq("user_id", targetUserId)

        if (error || !tokens || tokens.length === 0) {
            return new Response("No devices found", { status: 200 })
        }

        // Generate Token
        const jwt = await generateApnsJwt(TEAM_ID, KEY_ID, P8_KEY)

        // Send to Apple (Production Endpoint)
        // Use "https://api.sandbox.push.apple.com" for Development/Debug Builds
        // Use "https://api.push.apple.com" for TestFlight/AppStore
        const host = "https://api.push.apple.com"

        const results = await Promise.all(tokens.map(async (t) => {
            const url = `${host}/3/device/${t.token}`

            const payload = {
                aps: {
                    alert: { title, body },
                    sound: "default",
                    badge: 1
                }
            }

            const res = await fetch(url, {
                method: "POST",
                headers: {
                    "authorization": `bearer ${jwt}`,
                    "apns-topic": BUNDLE_ID,
                    "apns-push-type": "alert",
                    "apns-expiration": "0",
                    "apns-priority": "10"
                },
                body: JSON.stringify(payload)
            })

            // Log failures
            if (!res.ok) {
                console.error(`APNs Error ${res.status}: ${await res.text()}`)
            }

            return res.status
        }))

        return new Response(JSON.stringify({ sent: results.length }), {
            headers: { "Content-Type": "application/json" }
        })

    } catch (err) {
        console.error(err)
        return new Response(String(err), { status: 500 })
    }
})
