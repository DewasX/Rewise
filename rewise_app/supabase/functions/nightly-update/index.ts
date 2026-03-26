import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Optional MVP Nightly Job: Trigger any bulk recalculations needed globally
        // E.g., re-flagging overdue topics to "Urgent" status based on math models
        // Since our app dynamically calculates score, we can use this just to cleanup old data logs

        // Example: Delete review_history older than 365 days to save storage
        const oneYearAgo = new Date();
        oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);

        const { error: deletionError } = await supabase
            .from('review_history')
            .delete()
            .lte('review_date', oneYearAgo.toISOString());

        if (deletionError) throw deletionError;

        // Optional: Re-run a SQL RPC if you wanted to sync stability across a billion rows
        // const { error: rpcError } = await supabase.rpc('recalculate_memory_scores');

        return new Response(JSON.stringify({ message: "Nightly cron job completed successfully." }), {
            headers: { 'Content-Type': 'application/json' },
        })
    } catch (err) {
        return new Response(String(err?.message ?? err), { status: 500 })
    }
})
